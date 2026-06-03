#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: $0 '<browser-harness python script>'"
    exit 1
fi

PROFILE_DIR="$HOME/.config/chromium/hermes-automation"
DOWNLOAD_DIR="$HOME/hermes-workspace/downloads"
mkdir -p "$DOWNLOAD_DIR"

# Allow overriding timeout for testing, default to 5 minutes (300s)
EXEC_TIMEOUT=${BH_TIMEOUT:-300}

# Pre-inject the CDP download behavior command before the user script
TASK_SCRIPT="cdp('Browser.setDownloadBehavior', behavior='allow', downloadPath='$DOWNLOAD_DIR', eventsEnabled=True)
$1"

LOCKFILE="/tmp/hermes-browser-execution.lock"
exec 200>"$LOCKFILE"
echo "[Process $$] Waiting for exclusive browser lock (max 120s)..."
flock -w 120 200 || { echo "[Process $$] Timeout waiting for browser lock. Another task is hung."; exit 1; }
echo "[Process $$] Lock acquired. Executing task."

CHROME_PID=""
CLEANUP_DONE=0

cleanup() {
    if [ $CLEANUP_DONE -eq 1 ]; then
        return
    fi
    CLEANUP_DONE=1
    
    echo "[Process $$] Running cleanup routine..."
    
    if [ -n "$CHROME_PID" ]; then
        if kill -0 $CHROME_PID 2>/dev/null; then
            echo "[Process $$] Tearing down Chromium (PID $CHROME_PID)..."
            kill -15 $CHROME_PID 2>/dev/null
            sleep 1
            kill -9 $CHROME_PID 2>/dev/null 
            wait $CHROME_PID 2>/dev/null
        fi
    fi
    
    # Absolute aggressive teardown to prevent ANY orphan Chromium instances 
    # matching our hermes-automation profile from persisting.
    # Note: kill the main process and all child processes specifically matching the dir
    pkill -9 -f "chromium-browser.*hermes-automation" 2>/dev/null || true
    
    # Force clean stale Chromium lockfiles
    rm -f "$PROFILE_DIR/SingletonLock" "$PROFILE_DIR/SingletonCookie" "$PROFILE_DIR/SingletonSocket"
    echo "[Process $$] Cleanup complete. Releasing lock."
}

# Trap unexpected exits, interrupts, and terminations
trap cleanup EXIT INT TERM

# Avoid matching this script itself
if ps aux | grep "[c]hromium-browser" | grep -q "hermes-automation"; then
    echo "[Process $$] Reusing existing Chromium instance..."
    export BU_CDP_URL=http://127.0.0.1:9222
    timeout $EXEC_TIMEOUT browser-harness -c "$TASK_SCRIPT"
    EXIT_CODE=$?
else
    echo "[Process $$] Starting temporary headless Chromium..."
    rm -f "$PROFILE_DIR/SingletonLock" "$PROFILE_DIR/SingletonCookie" "$PROFILE_DIR/SingletonSocket"
    
    # "Chain of Death" python wrapper: guarantees Chromium dies if this bash script is kill -9'd
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
      --remote-debugging-port=9222 \
      --user-data-dir="$PROFILE_DIR" \
      --remote-allow-origins='*' \
      --disable-backgrounding-occluded-windows \
      --disable-renderer-backgrounding \
      --disable-background-timer-throttling > /dev/null 2>&1 &
      
    CHROME_PID=$!
    
    # Wait for CDP endpoint to be ready
    timeout 10 bash -c 'until curl -s http://127.0.0.1:9222/json/version >/dev/null 2>&1; do sleep 0.5; done'
    
    export BU_CDP_URL=http://127.0.0.1:9222
    
    # Run the task with a strict timeout to prevent infinite queue deadlocks
    timeout $EXEC_TIMEOUT browser-harness -c "$TASK_SCRIPT"
    EXIT_CODE=$?
fi

exit $EXIT_CODE