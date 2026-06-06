#!/bin/bash
set -euo pipefail

# =============================================================================
# Agent Bulletproof Browser — Background Headless Runner
# =============================================================================
# Cross-platform (Linux/macOS) wrapper for safe, queue-backed headless
# browser automation via browser-harness.
#
# Environment variables:
#   BH_TIMEOUT             - Max seconds per task (default: 300)
#   BH_CDP_PORT            - DevTools port (default: 9222, ephemeral fallback)
#   AGENT_SKIP_IF_LOCKED   - If 1, exit immediately when another task holds lock
#   AGENT_JSON_LOG         - If 1, emit newline-delimited JSON events to stdout
#   AGENT_LOG_LEVEL        - info | warn | error (default: info)
# =============================================================================

if [ -n "${AGENT_BROWSER_LIB:-}" ]; then
    _LIB_DIR="$AGENT_BROWSER_LIB"
else
    _SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    _LIB_DIR="$_SCRIPT_DIR/../lib"
fi
source "$_LIB_DIR/config.sh"
source "$_LIB_DIR/log.sh"
source "$_LIB_DIR/detect.sh"
source "$_LIB_DIR/net.sh"
source "$_LIB_DIR/lock.sh"
source "$_LIB_DIR/cleanup.sh"
source "$_LIB_DIR/chromium-flags.sh"

# --- Cross-Platform Timeout Wrapper -------------------------------------------
agent_timeout() {
    local t="$1"
    shift
    if command -v timeout >/dev/null 2>&1; then
        timeout "$t" "$@"
    elif command -v gtimeout >/dev/null 2>&1; then
        gtimeout "$t" "$@"
    else
        perl -e 'alarm shift; exec @ARGV' "$t" "$@"
    fi
}

# --- Preflight Checks ---------------------------------------------------------
CHROME_BIN=$(detect_chrome)
if [ -z "$CHROME_BIN" ]; then
    agent_log error "error" "No Chromium or Google Chrome executable found in PATH." ""
    exit 1
fi

# --- Check Mode ---------------------------------------------------------------
if [ "${1:-}" = "--check" ]; then
    agent_log info "check_start" "Checking environment..." ""
    ok=0
    fail=0
    if command -v browser-harness >/dev/null 2>&1; then
        agent_log info "check_ok" "browser-harness" ""
        ok=$((ok + 1))
    else
        agent_log error "check_fail" "browser-harness not found" ""
        fail=$((fail + 1))
    fi
    if [ -n "$CHROME_BIN" ]; then
        agent_log info "check_ok" "Chromium binary: $CHROME_BIN" ""
        ok=$((ok + 1))
    else
        agent_log error "check_fail" "No Chromium binary found" ""
        fail=$((fail + 1))
    fi
    if command -v curl >/dev/null 2>&1; then
        agent_log info "check_ok" "curl" ""
        ok=$((ok + 1))
    else
        agent_log error "check_fail" "curl not found" ""
        fail=$((fail + 1))
    fi
    if command -v flock >/dev/null 2>&1; then
        agent_log info "check_ok" "flock (Linux)" ""
        ok=$((ok + 1))
    else
        agent_log warn "check_warn" "flock not found (macOS fallback will use mkdir locks)" ""
    fi
    if command -v timeout >/dev/null 2>&1 || command -v gtimeout >/dev/null 2>&1; then
        agent_log info "check_ok" "timeout/gtimeout" ""
        ok=$((ok + 1))
    else
        agent_log warn "check_warn" "timeout/gtimeout not found (perl fallback will be used)" ""
    fi
    mkdir -p "$HOME/agent-workspace/downloads" 2>/dev/null && ok=$((ok + 1)) || fail=$((fail + 1))
    agent_log info "check_ok" "Workspace directories" ""
    agent_log info "check_summary" "Environment OK." "ok=$ok fail=$fail"
    exit 0
fi

# --- Defaults & Argument Parsing ----------------------------------------------
PROFILE_DIR=$(agent_profile_dir "agent-automation-bg")
mkdir -p "$PROFILE_DIR/Default"
DOWNLOAD_DIR="$HOME/agent-workspace/downloads/run_$$"
mkdir -p "$DOWNLOAD_DIR"
export AGENT_DOWNLOAD_DIR="$DOWNLOAD_DIR"
export AGENT_CHILD_PID_FILE="/tmp/agent-browser-child-$$.pid"

EXEC_TIMEOUT=${BH_TIMEOUT:-$AGENT_TIMEOUT}
CDP_PORT=${BH_CDP_PORT:-$AGENT_CDP_PORT}
SKIP_IF_LOCKED="${AGENT_SKIP_IF_LOCKED:-0}"

if [ -z "${1:-}" ]; then
    agent_log error "usage" "Usage: $0 '<browser-harness python script>'" ""
    exit 1
fi

TASK_SCRIPT="$1"

# --- Adaptive Health Pulse Interval -------------------------------------------
HEALTH_INTERVAL=$((EXEC_TIMEOUT / 10))
[ "$HEALTH_INTERVAL" -lt 2 ] && HEALTH_INTERVAL=2
[ "$HEALTH_INTERVAL" -gt 10 ] && HEALTH_INTERVAL=10

# --- CDP Port Resolution ------------------------------------------------------
if port_in_use "$CDP_PORT"; then
    if ! pgrep -f "(chromium|chrome).*agent-automation-bg" >/dev/null 2>&1; then
        agent_log info "port_busy" "Port $CDP_PORT in use by other process. Finding ephemeral port..." ""
        CDP_PORT=$(find_free_port)
        agent_log info "port_selected" "Using ephemeral port $CDP_PORT" ""
    fi
fi

# --- Safe Python Injection ----------------------------------------------------
DOWNLOAD_DIR_ESCAPED=$(python3 -c "import sys,json; print(json.dumps(sys.argv[1]))" "$DOWNLOAD_DIR")
TASK_SCRIPT="cdp('Browser.setDownloadBehavior', behavior='allow', downloadPath=$DOWNLOAD_DIR_ESCAPED, eventsEnabled=True)
$TASK_SCRIPT"

# --- Concurrency Lock ---------------------------------------------------------
LOCKFILE="/tmp/agent-browser-bg-$(id -u).lock"
if ! acquire_lock "$LOCKFILE" 0; then
    if [ "$SKIP_IF_LOCKED" = "1" ]; then
        agent_log warn "skip_locked" "Another background task is running. (--skip-if-locked set, exiting)" ""
        exit 3
    fi
    LOCK_HOLDER=$(fuser "$LOCKFILE" 2>/dev/null | awk '{print $1}' || true)
    if [ -n "$LOCK_HOLDER" ]; then
        agent_log info "lock_queued" "Queue busy. Waiting for Process $LOCK_HOLDER (max ${AGENT_LOCK_TIMEOUT}s)..." ""
    else
        agent_log info "lock_queued" "Queue busy. Waiting for lock (max ${AGENT_LOCK_TIMEOUT}s)..." ""
    fi
    acquire_lock "$LOCKFILE" "$AGENT_LOCK_TIMEOUT" || {
        agent_log error "lock_timeout" "Timeout waiting for browser lock." ""
        exit 1
    }
fi
agent_log info "lock_acquired" "Lock acquired." "lockfile=$LOCKFILE"

# --- State & Cleanup ----------------------------------------------------------
CHROME_PID=""
CLEANUP_DONE=0
WE_STARTED_BROWSER="0"
EXIT_CODE=0

cleanup() {
    set +e
    if [ "$CLEANUP_DONE" -eq 1 ]; then return; fi
    CLEANUP_DONE=1

    agent_log info "cleanup_start" "Running cleanup routine..." ""

    if [ "$WE_STARTED_BROWSER" = "1" ]; then
        if [ -n "$CHROME_PID" ] && kill -0 "$CHROME_PID" 2>/dev/null; then
            agent_log info "cleanup_kill_wrapper" "Stopping Chromium wrapper (PID $CHROME_PID)..." ""
            kill -15 "$CHROME_PID" 2>/dev/null
            sleep 2
            if kill -0 "$CHROME_PID" 2>/dev/null; then
                kill -9 "$CHROME_PID" 2>/dev/null
                wait "$CHROME_PID" 2>/dev/null
            fi
        fi
        if [ -f "$AGENT_CHILD_PID_FILE" ]; then
            local child_pid
            child_pid=$(cat "$AGENT_CHILD_PID_FILE" 2>/dev/null || true)
            if [ -n "$child_pid" ] && kill -0 "$child_pid" 2>/dev/null; then
                agent_log info "cleanup_kill_child" "Stopping orphaned Chromium child (PID $child_pid)..." ""
                kill -15 "$child_pid" 2>/dev/null
                sleep 1
                kill -9 "$child_pid" 2>/dev/null || true
            fi
            rm -f "$AGENT_CHILD_PID_FILE"
        fi
    fi

    agent_cleanup_singletons "$PROFILE_DIR"
    agent_cleanup_caches "$PROFILE_DIR"
    agent_cleanup_download_dir "$DOWNLOAD_DIR"
    agent_gc_downloads "$HOME/agent-workspace/downloads"
    release_lock

    agent_log info "cleanup_done" "Cleanup complete." ""
}

trap cleanup EXIT INT TERM HUP QUIT

# --- Pre-Flight Disk Check ----------------------------------------------------
AVAILABLE_KB=$(df -k "$HOME" | awk 'NR==2 {print $4}')
AVAILABLE_MB=$((AVAILABLE_KB / 1024))
if [ "$AVAILABLE_MB" -lt "$AGENT_DISK_THRESHOLD_MB" ]; then
    agent_log warn "disk_low" "Only ${AVAILABLE_MB}MB disk space available. Chromium may crash." ""
fi

# --- Execution ----------------------------------------------------------------

if pgrep -f "(chromium|chrome).*agent-automation-bg" >/dev/null 2>&1; then
    agent_log info "reuse_existing" "Reusing existing Chromium instance..." ""
    export BU_CDP_URL=http://127.0.0.1:$CDP_PORT
    set +e
    agent_timeout "$EXEC_TIMEOUT" browser-harness -c "$TASK_SCRIPT"
    EXIT_CODE=$?
    set -e
else
    if port_in_use "$CDP_PORT"; then
        agent_log error "port_collision" "Port $CDP_PORT still occupied after resolution. Aborting." ""
        exit 1
    fi

    agent_log info "chromium_starting" "Starting temporary headless Chromium with Chain-of-Death..." "port=$CDP_PORT profile=$PROFILE_DIR"
    WE_STARTED_BROWSER="1"
    agent_cleanup_singletons "$PROFILE_DIR"

    RAW_VER=$($CHROME_BIN --version 2>/dev/null || echo "")
    CLEAN_VER=$(extract_ver "$RAW_VER")
    [ -z "$CLEAN_VER" ] && CLEAN_VER="$AGENT_DEFAULT_UA_VERSION"
    STEALTH_UA=$(build_stealth_ua "$CLEAN_VER")

    SANDBOX_FLAG=""
    if [ "$(id -u)" = "0" ]; then
        SANDBOX_FLAG="--no-sandbox"
    fi

    python3 "$_SCRIPT_DIR/../lib/browser_guard.py" "$CHROME_BIN" \
        --headless=new \
        $SANDBOX_FLAG \
        --password-store=basic \
        --remote-debugging-port="$CDP_PORT" \
        --user-data-dir="$PROFILE_DIR" \
        --remote-allow-origins='*' \
        --window-size=1920,1080 \
        --disable-popup-blocking \
        --disable-extensions \
        --disable-backgrounding-occluded-windows \
        --disable-renderer-backgrounding \
        --disable-background-timer-throttling \
        --disable-blink-features=AutomationControlled \
        --disable-dev-shm-usage \
        --disable-gpu \
        --lang=en-US,en \
        --mute-audio \
        --no-first-run \
        --no-default-browser-check \
        --disable-sync \
        --disable-crash-reporter \
        --disable-breakpad \
        --disk-cache-dir=/dev/null \
        --disk-cache-size=1 \
        --user-agent="$STEALTH_UA" \
        --ignore-certificate-errors >>"$PROFILE_DIR/headless-chromium.log" 2>&1 &

    CHROME_PID=$!

    if ! wait_for_cdp "http://127.0.0.1:$CDP_PORT/json/version" 10; then
        agent_log error "chromium_start_timeout" "Chromium failed to bind to port $CDP_PORT within 10 seconds." ""
        if [ "$AGENT_JSON_LOG" != "1" ]; then
            echo "Last 20 lines of Chromium crash log ($PROFILE_DIR/headless-chromium.log):"
            tail -n 20 "$PROFILE_DIR/headless-chromium.log"
        fi
        exit 1
    fi

    export BU_CDP_URL=http://127.0.0.1:$CDP_PORT
    agent_log info "chromium_ready" "Chromium CDP endpoint is ready." "port=$CDP_PORT pid=$CHROME_PID"

    set +e

    # --- Run browser-harness with health pulse --------------------------------
    agent_log info "task_starting" "Starting browser-harness task." "timeout=${EXEC_TIMEOUT}s health_interval=${HEALTH_INTERVAL}s"
    browser-harness -c "$TASK_SCRIPT" &
    BH_PID=$!

    # Background monitor: enforces overall timeout AND polls CDP health.
    (
        ELAPSED=0
        while kill -0 "$BH_PID" 2>/dev/null; do
            sleep "$HEALTH_INTERVAL"
            ELAPSED=$((ELAPSED + HEALTH_INTERVAL))

            # Overall task timeout
            if [ "$ELAPSED" -ge "$EXEC_TIMEOUT" ]; then
                if [ "$AGENT_JSON_LOG" = "1" ]; then
                    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
                    msg="Task exceeded ${EXEC_TIMEOUT}s timeout"
                    msg_escaped=$(agent_json_escape "$msg")
                    echo "{\"ts\": \"$ts\", \"event\": \"timeout\", \"level\": \"error\", \"message\": $msg_escaped, \"detail\": \"killing browser-harness to release lock\"}"
                else
                    echo "[Process $$] Task exceeded ${EXEC_TIMEOUT}s timeout. Killing browser-harness."
                fi
                kill -TERM "$BH_PID" 2>/dev/null || true
                break
            fi

            # CDP health check
            if kill -0 "$BH_PID" 2>/dev/null; then
                if ! cdp_health_check "$BU_CDP_URL"; then
                    if [ "$AGENT_JSON_LOG" = "1" ]; then
                        ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
                        msg="Chromium CDP health check failed"
                        msg_escaped=$(agent_json_escape "$msg")
                        echo "{\"ts\": \"$ts\", \"event\": \"health_fail\", \"level\": \"error\", \"message\": $msg_escaped, \"detail\": \"killing browser-harness early to avoid burning full timeout\"}"
                    else
                        echo "[Process $$] Health check: Chromium CDP is dead. Killing browser-harness early (avoiding ${EXEC_TIMEOUT}s timeout)."
                    fi
                    kill -TERM "$BH_PID" 2>/dev/null || true
                    break
                fi
            fi
        done
    ) &
    HEALTH_PID=$!

    wait "$BH_PID"
    EXIT_CODE=$?

    kill "$HEALTH_PID" 2>/dev/null || true
    wait "$HEALTH_PID" 2>/dev/null || true

    set -e
fi

agent_log info "task_complete" "browser-harness exited." "exit_code=$EXIT_CODE"
exit $EXIT_CODE
