#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: $0 '<browser-harness python script>'"
    exit 1
fi

PROFILE_DIR="$HOME/.config/chromium/agent-automation"
DOWNLOAD_DIR="$HOME/hermes-workspace/downloads"
mkdir -p "$DOWNLOAD_DIR"

# Allow overriding timeout for testing, default to 5 minutes (300s)
EXEC_TIMEOUT=${BH_TIMEOUT:-300}

# Pre-inject the CDP download behavior command before the user script
TASK_SCRIPT="cdp('Browser.setDownloadBehavior', behavior='allow', downloadPath='$DOWNLOAD_DIR', eventsEnabled=True)
$1"

LOCKFILE="/tmp/agent-browser-execution.lock"
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
    fi
    
    # Clean stale Chromium lockfiles and explicitly clear caching directories to prevent long-term bloat
    rm -f "$PROFILE_DIR/SingletonLock" "$PROFILE_DIR/SingletonCookie" "$PROFILE_DIR/SingletonSocket"
    rm -rf "$PROFILE_DIR/Default/Cache" "$PROFILE_DIR/Default/Code Cache" "$PROFILE_DIR/Default/GPUCache" 2>/dev/null
    echo "[Process $$] Cleanup complete. Releasing lock."
}

trap cleanup EXIT INT TERM

if ps aux | grep "[c]hromium-browser" | grep -q "agent-automation"; then
    echo "[Process $$] Reusing existing Chromium instance..."
    export BU_CDP_URL=http://127.0.0.1:9222
    timeout $EXEC_TIMEOUT browser-harness -c "$TASK_SCRIPT"
    EXIT_CODE=$?
else
    if lsof -i:9222 -t >/dev/null 2>&1; then
        echo "Error: Port 9222 is in use by an unrecognized process. Aborting to prevent collision."
        exit 1
    fi

    echo "[Process $$] Starting temporary headless Chromium with Chain-of-Death..."
    WE_STARTED_BROWSER="1"
    rm -f "$PROFILE_DIR/SingletonLock" "$PROFILE_DIR/SingletonCookie" "$PROFILE_DIR/SingletonSocket"
    
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
      --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36" \
      --ignore-certificate-errors > /dev/null 2>&1 &
      
    CHROME_PID=$!
    
    timeout 10 bash -c 'until curl -s http://127.0.0.1:9222/json/version >/dev/null 2>&1; do sleep 0.5; done'
    
    export BU_CDP_URL=http://127.0.0.1:9222
    
    timeout $EXEC_TIMEOUT browser-harness -c "$TASK_SCRIPT"
    EXIT_CODE=$?
fi

exit $EXIT_CODE