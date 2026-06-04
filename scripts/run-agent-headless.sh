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

# --- Structured Logging -------------------------------------------------------

AGENT_JSON_LOG="${AGENT_JSON_LOG:-0}"
AGENT_LOG_LEVEL="${AGENT_LOG_LEVEL:-info}"
_LOG_LEVEL_NUM=2  # 0=error, 1=warn, 2=info

case "$AGENT_LOG_LEVEL" in
    error) _LOG_LEVEL_NUM=0 ;;
    warn)  _LOG_LEVEL_NUM=1 ;;
    info)  _LOG_LEVEL_NUM=2 ;;
esac

agent_json_escape() {
    python3 -c "import json,sys; print(json.dumps(sys.argv[1]), end='')" "$1"
}

agent_log() {
    local level="$1" event="$2" message="${3:-}" detail="${4:-}"
    local lvl_num=2
    case "$level" in
        error) lvl_num=0 ;;
        warn)  lvl_num=1 ;;
        info)  lvl_num=2 ;;
    esac
    [ "$lvl_num" -gt "$_LOG_LEVEL_NUM" ] && return 0

    if [ "$AGENT_JSON_LOG" = "1" ]; then
        local ts; ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        local msg_escaped; msg_escaped=$(agent_json_escape "$message")
        local det_escaped; det_escaped=$(agent_json_escape "$detail")
        local detail_field=""
        [ -n "$detail" ] && detail_field=", \"detail\": $det_escaped"
        echo "{\"ts\": \"$ts\", \"event\": \"$event\", \"level\": \"$level\", \"message\": $msg_escaped$detail_field}"
    else
        case "$event" in
            check_ok|check_fail) echo "  [$level] $message" ;;
            *) echo "[Process $$] $message" ;;
        esac
    fi
}

# --- Cross-Platform Compatibility Helpers -------------------------------------

agent_timeout() {
    local t="$1"; shift
    if command -v timeout >/dev/null 2>&1; then
        timeout "$t" "$@"
    elif command -v gtimeout >/dev/null 2>&1; then
        gtimeout "$t" "$@"
    else
        perl -e 'alarm shift; exec @ARGV' "$t" "$@"
    fi
}

agent_flock_acquire() {
    local lockfile="$1" wait_sec="${2:-120}"
    if command -v flock >/dev/null 2>&1; then
        exec 999>"$lockfile"
        flock -w "$wait_sec" 999 || return 1
    else
        # macOS / BSD fallback: mkdir is atomic on local filesystems
        local end=$((SECONDS + wait_sec))
        while ! mkdir "$lockfile" 2>/dev/null; do
            if [ $SECONDS -ge $end ]; then return 1; fi
            sleep 1
        done
        AGENT_LOCK_DIR="$lockfile"
    fi
}

agent_flock_release() {
    if [ -n "${AGENT_LOCK_DIR:-}" ]; then
        rmdir "$AGENT_LOCK_DIR" 2>/dev/null || true
        AGENT_LOCK_DIR=""
    fi
}

port_in_use() {
    local port="$1"
    if command -v lsof >/dev/null 2>&1; then
        lsof -i:"$port" -t >/dev/null 2>&1
    elif command -v ss >/dev/null 2>&1; then
        ss -lnt | grep -q ":$port "
    elif command -v netstat >/dev/null 2>&1; then
        netstat -an | grep -q "LISTEN.*\.$port "
    else
        python3 -c "import socket; s=socket.socket(); s.bind(('127.0.0.1',$port)); s.close()" 2>/dev/null && return 1 || return 0
    fi
}

find_free_port() {
    python3 -c "import socket; s=socket.socket(); s.bind(('',0)); print(s.getsockname()[1]); s.close()"
}

# --- Preflight Checks ---------------------------------------------------------

CHROME_BIN=$(command -v chromium-browser || command -v chromium || command -v google-chrome || command -v google-chrome-stable || true)
if [ -z "$CHROME_BIN" ]; then
    agent_log error "error" "No Chromium or Google Chrome executable found in PATH." ""
    exit 1
fi

# --- Check Mode ---------------------------------------------------------------
if [ "${1:-}" = "--check" ]; then
    agent_log info "check_start" "Checking environment..." ""
    ok=0; fail=0
    if command -v browser-harness >/dev/null 2>&1; then
        agent_log info "check_ok" "browser-harness" ""
        ok=$((ok+1))
    else
        agent_log error "check_fail" "browser-harness not found" ""
        fail=$((fail+1))
    fi
    if [ -n "$CHROME_BIN" ]; then
        agent_log info "check_ok" "Chromium binary: $CHROME_BIN" ""
        ok=$((ok+1))
    else
        agent_log error "check_fail" "No Chromium binary found" ""
        fail=$((fail+1))
    fi
    if command -v curl >/dev/null 2>&1; then
        agent_log info "check_ok" "curl" ""
        ok=$((ok+1))
    else
        agent_log error "check_fail" "curl not found" ""
        fail=$((fail+1))
    fi
    if command -v flock >/dev/null 2>&1; then
        agent_log info "check_ok" "flock (Linux)" ""
        ok=$((ok+1))
    else
        agent_log warn "check_warn" "flock not found (macOS fallback will use mkdir locks)" ""
    fi
    if command -v timeout >/dev/null 2>&1 || command -v gtimeout >/dev/null 2>&1; then
        agent_log info "check_ok" "timeout/gtimeout" ""
        ok=$((ok+1))
    else
        agent_log warn "check_warn" "timeout/gtimeout not found (perl fallback will be used)" ""
    fi
    mkdir -p "$HOME/agent-workspace/downloads" 2>/dev/null && ok=$((ok+1)) || fail=$((fail+1))
    agent_log info "check_ok" "Workspace directories" ""
    agent_log info "check_summary" "Environment OK." "ok=$ok fail=$fail"
    exit 0
fi

# --- Defaults & Argument Parsing ----------------------------------------------

PROFILE_DIR="$HOME/.config/chromium/agent-automation-bg"
mkdir -p "$PROFILE_DIR/Default"
DOWNLOAD_DIR="$HOME/agent-workspace/downloads/run_$$"
mkdir -p "$DOWNLOAD_DIR"
export AGENT_DOWNLOAD_DIR="$DOWNLOAD_DIR"
export AGENT_CHILD_PID_FILE="/tmp/agent-browser-child-$$.pid"

EXEC_TIMEOUT=${BH_TIMEOUT:-300}
CDP_PORT=${BH_CDP_PORT:-9222}
SKIP_IF_LOCKED="${AGENT_SKIP_IF_LOCKED:-0}"

if [ -z "${1:-}" ]; then
    agent_log error "usage" "Usage: $0 '<browser-harness python script>'" ""
    exit 1
fi

TASK_SCRIPT="$1"

# --- Adaptive Health Pulse Interval -------------------------------------------
HEALTH_INTERVAL=$(( EXEC_TIMEOUT / 10 ))
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
if ! agent_flock_acquire "$LOCKFILE" 0; then
    if [ "$SKIP_IF_LOCKED" = "1" ]; then
        agent_log warn "skip_locked" "Another background task is running. (--skip-if-locked set, exiting)" ""
        exit 3
    fi
    LOCK_HOLDER=$(fuser "$LOCKFILE" 2>/dev/null | awk '{print $1}' || true)
    if [ -n "$LOCK_HOLDER" ]; then
        agent_log info "lock_queued" "Queue busy. Waiting for Process $LOCK_HOLDER (max 120s)..." ""
    else
        agent_log info "lock_queued" "Queue busy. Waiting for lock (max 120s)..." ""
    fi
    agent_flock_acquire "$LOCKFILE" 120 || { agent_log error "lock_timeout" "Timeout waiting for browser lock." ""; exit 1; }
fi
agent_log info "lock_acquired" "Lock acquired." "lockfile=$LOCKFILE"

# --- State & Cleanup ----------------------------------------------------------
CHROME_PID=""
CLEANUP_DONE=0
WE_STARTED_BROWSER="0"
EXIT_CODE=0

cleanup() {
    set +e
    if [ $CLEANUP_DONE -eq 1 ]; then return; fi
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

    rm -f "$PROFILE_DIR/SingletonLock" "$PROFILE_DIR/SingletonCookie" "$PROFILE_DIR/SingletonSocket"
    rm -rf "$PROFILE_DIR/Default/Cache" "$PROFILE_DIR/Default/Code Cache" "$PROFILE_DIR/Default/GPUCache" 2>/dev/null || true
    rmdir "$DOWNLOAD_DIR" 2>/dev/null || true
    find "$HOME/agent-workspace/downloads/" -maxdepth 1 -name "run_*" -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
    agent_flock_release

    agent_log info "cleanup_done" "Cleanup complete." ""
}

trap cleanup EXIT INT TERM HUP QUIT

# --- Pre-Flight Disk Check ----------------------------------------------------
AVAILABLE_KB=$(df -k "$HOME" | awk 'NR==2 {print $4}')
AVAILABLE_MB=$((AVAILABLE_KB / 1024))
if [ "$AVAILABLE_MB" -lt 500 ]; then
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
    rm -f "$PROFILE_DIR/SingletonLock" "$PROFILE_DIR/SingletonCookie" "$PROFILE_DIR/SingletonSocket"

    RAW_VER=$($CHROME_BIN --version 2>/dev/null || echo "")
    CLEAN_VER=$(echo "$RAW_VER" | sed -n 's/.*[^0-9]\([0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}\).*/\1/p')
    [ -z "$CLEAN_VER" ] && CLEAN_VER="148.0.0.0"
    STEALTH_UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$CLEAN_VER Safari/537.36"

    SANDBOX_FLAG=""
    if [ "$(id -u)" = "0" ]; then
        SANDBOX_FLAG="--no-sandbox"
    fi

    python3 -c "
import ctypes, subprocess, sys, os, time, signal

def set_pdeathsig():
    try:
        libc = ctypes.CDLL('libc.so.6')
        libc.prctl(1, 9)
    except Exception:
        pass

def write_pid(pid):
    f = os.environ.get('AGENT_CHILD_PID_FILE', '')
    if f:
        try:
            with open(f, 'w') as fh:
                fh.write(str(pid))
        except Exception:
            pass

def run_with_prctl():
    set_pdeathsig()
    proc = subprocess.Popen(sys.argv[1:], preexec_fn=set_pdeathsig)
    write_pid(proc.pid)
    def on_term(signum, frame):
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except Exception:
            proc.kill()
        sys.exit(0)
    signal.signal(signal.SIGTERM, on_term)
    sys.exit(proc.wait())

def run_with_ppid_watch():
    proc = subprocess.Popen(sys.argv[1:])
    write_pid(proc.pid)
    original_ppid = os.getppid()
    def on_term(signum, frame):
        proc.terminate()
        time.sleep(2)
        try:
            os.kill(proc.pid, signal.SIGKILL)
        except OSError:
            pass
        sys.exit(0)
    signal.signal(signal.SIGTERM, on_term)
    while proc.poll() is None:
        if os.getppid() != original_ppid:
            proc.terminate()
            time.sleep(2)
            try:
                os.kill(proc.pid, signal.SIGKILL)
            except OSError:
                pass
            break
        time.sleep(1)
    sys.exit(proc.returncode or 0)

try:
    run_with_prctl()
except Exception:
    run_with_ppid_watch()
" "$CHROME_BIN" \
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
      --mute-audio \
      --no-first-run \
      --no-default-browser-check \
      --disable-sync \
      --disable-crash-reporter \
      --disable-breakpad \
      --disk-cache-dir=/dev/null \
      --disk-cache-size=1 \
      --user-agent="$STEALTH_UA" \
      --ignore-certificate-errors >> "$PROFILE_DIR/headless-chromium.log" 2>&1 &

    CHROME_PID=$!

    if ! agent_timeout 10 bash -c "until curl -s http://127.0.0.1:$CDP_PORT/json/version >/dev/null 2>&1; do sleep 0.5; done"; then
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
    # If either threshold is crossed, it SIGTERMs browser-harness so the
    # main wait returns early instead of burning the full EXEC_TIMEOUT.
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
                    msg_escaped=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]), end='')" "$msg")
                    echo "{\"ts\": \"$ts\", \"event\": \"timeout\", \"level\": \"error\", \"message\": $msg_escaped, \"detail\": \"killing browser-harness to release lock\"}"
                else
                    echo "[Process $$] Task exceeded ${EXEC_TIMEOUT}s timeout. Killing browser-harness."
                fi
                kill -TERM "$BH_PID" 2>/dev/null || true
                break
            fi

            # CDP health check
            if kill -0 "$BH_PID" 2>/dev/null; then
                if ! curl -s "$BU_CDP_URL/json/version" >/dev/null 2>&1; then
                    if [ "$AGENT_JSON_LOG" = "1" ]; then
                        ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
                        msg="Chromium CDP health check failed"
                        msg_escaped=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]), end='')" "$msg")
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
