#!/bin/bash
set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "Usage: $0 '<browser-harness python script>'"
    exit 1
fi

CHROME_BIN=$(command -v chromium-browser || command -v chromium || command -v google-chrome || command -v google-chrome-stable || true)
if [ -z "$CHROME_BIN" ]; then
    echo "Error: No Chromium or Google Chrome executable found in PATH."
    exit 1
fi

PROFILE_DIR="$HOME/.config/chromium/agent-automation"
DOWNLOAD_DIR="$HOME/hermes-workspace/downloads/run_$$"
mkdir -p "$DOWNLOAD_DIR"
# Export so the python script can discover where it is downloading things to
export AGENT_DOWNLOAD_DIR="$DOWNLOAD_DIR"

# Allow overriding timeout for testing, default to 5 minutes (300s)
EXEC_TIMEOUT=${BH_TIMEOUT:-300}

# Allow overriding CDP port, default to 9222
CDP_PORT=${BH_CDP_PORT:-9222}

# Pre-inject the CDP download behavior command before the user script
TASK_SCRIPT="cdp('Browser.setDownloadBehavior', behavior='allow', downloadPath='$DOWNLOAD_DIR', eventsEnabled=True)
$1"

LOCKFILE="/tmp/agent-browser-execution.lock"
exec 200>"$LOCKFILE"
# Check if lock is held by another process to provide intelligent feedback
if ! flock -n 200; then
    LOCK_HOLDER=$(fuser "$LOCKFILE" 2>/dev/null | awk '{print $1}' || true)
    if [ -n "$LOCK_HOLDER" ]; then
        echo "[Process $$] Queue is busy. Waiting for Process $LOCK_HOLDER to finish its browser task (max 120s)..."
    else
        echo "[Process $$] Queue is busy. Waiting for exclusive browser lock (max 120s)..."
    fi
    flock -w 120 200 || { echo "[Process $$] Timeout waiting for browser lock. Another task is hung."; exit 1; }
fi
echo "[Process $$] Lock acquired. Executing task."

CHROME_PID=""
CLEANUP_DONE=0

cleanup() {
    if [ $CLEANUP_DONE -eq 1 ]; then
        return
    fi
    CLEANUP_DONE=1
    
    echo "[Process $$] Running cleanup routine..."
    
    if [ "$WE_STARTED_BROWSER" = "1" ]; then
        if [ -n "$CHROME_PID" ]; then
            if kill -0 $CHROME_PID 2>/dev/null; then
                echo "[Process $$] Tearing down Chromium (PID $CHROME_PID)..."
                kill -15 $CHROME_PID 2>/dev/null
                sleep 1
                kill -9 $CHROME_PID 2>/dev/null 
                wait $CHROME_PID 2>/dev/null
            fi
        fi
        
        pkill -9 -f "chromium-browser.*agent-automation" 2>/dev/null || true
        
        # Kill any stale browser-harness daemon that might be holding a dead CDP connection
        pkill -9 -f "browser_harness.daemon" 2>/dev/null || true
        rm -f /tmp/bu-*.sock /tmp/bu-*.pid 2>/dev/null
    fi
    
    # Clean stale Chromium lockfiles and explicitly clear caching directories to prevent long-term bloat
    rm -f "$PROFILE_DIR/SingletonLock" "$PROFILE_DIR/SingletonCookie" "$PROFILE_DIR/SingletonSocket"
    rm -rf "$PROFILE_DIR/Default/Cache" "$PROFILE_DIR/Default/Code Cache" "$PROFILE_DIR/Default/GPUCache" 2>/dev/null
    echo "[Process $$] Cleanup complete. Releasing lock."
}

trap cleanup EXIT INT TERM HUP QUIT

if ps aux | grep -E "(chromium|chrome).*agent-automation" >/dev/null 2>&1; then
    echo "[Process $$] Reusing existing Chromium instance..."
    export BU_CDP_URL=http://127.0.0.1:$CDP_PORT
    timeout $EXEC_TIMEOUT browser-harness -c "$TASK_SCRIPT"
    EXIT_CODE=$?
else
    if lsof -i:$CDP_PORT -t >/dev/null 2>&1; then
        echo "Error: Port $CDP_PORT is in use by an unrecognized process. Aborting to prevent collision."
        exit 1
    fi

    echo "[Process $$] Starting temporary headless Chromium with Chain-of-Death..."
    WE_STARTED_BROWSER="1"
    rm -f "$PROFILE_DIR/SingletonLock" "$PROFILE_DIR/SingletonCookie" "$PROFILE_DIR/SingletonSocket"
    
    # Dynamically construct a stealth User-Agent based on the actual installed binary version
    RAW_VER=$($CHROME_BIN --version | awk '{print $2}')
    CLEAN_VER=$(echo "$RAW_VER" | grep -oP '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' || echo "148.0.0.0")
    STEALTH_UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$CLEAN_VER Safari/537.36"

    python3 -c "
import ctypes, subprocess, sys
try:
    libc = ctypes.CDLL('libc.so.6')
    libc.prctl(1, 9)
    def set_pdeathsig(): libc.prctl(1, 9)
    sys.exit(subprocess.Popen(sys.argv[1:], preexec_fn=set_pdeathsig).wait())
except Exception:
    sys.exit(subprocess.call(sys.argv[1:]))
" chromium-browser \
      --headless=new \
      --password-store=basic \
      --remote-debugging-port=$CDP_PORT \
      --user-data-dir="$PROFILE_DIR" \
      --remote-allow-origins='*' \
      --window-size=1920,1080 \
      --disable-popup-blocking \
      --disable-extensions \
      --disable-backgrounding-occluded-windows \
      --disable-renderer-backgrounding \
      --disable-background-timer-throttling \
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
      --ignore-certificate-errors > "$PROFILE_DIR/headless-chromium.log" 2>&1 &
      
    CHROME_PID=$!
    # Wait for CDP endpoint to be ready
    if ! timeout 10 bash -c "until curl -s http://127.0.0.1:$CDP_PORT/json/version >/dev/null 2>&1; do sleep 0.5; done"; then
        echo "[Process $$] Error: Chromium failed to bind to port $CDP_PORT within 10 seconds."
        echo "Last 20 lines of Chromium crash log ($PROFILE_DIR/headless-chromium.log):"
        tail -n 20 "$PROFILE_DIR/headless-chromium.log"
        exit 1
    fi
    
    export BU_CDP_URL=http://127.0.0.1:$CDP_PORT
    
    timeout $EXEC_TIMEOUT browser-harness -c "$TASK_SCRIPT"
    EXIT_CODE=$?
fi

exit $EXIT_CODE