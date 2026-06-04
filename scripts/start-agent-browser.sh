#!/bin/bash
set -euo pipefail

# =============================================================================
# Agent Bulletproof Browser — Foreground Login Helper
# =============================================================================
# Launches a visible Chromium instance for one-time interactive logins.
# Uses a dedicated *foreground* profile so background tasks never collide.
# =============================================================================

CHROME_BIN=$(command -v chromium-browser || command -v chromium || command -v google-chrome || command -v google-chrome-stable || true)
if [ -z "$CHROME_BIN" ]; then
    echo "Error: No Chromium or Google Chrome executable found in PATH."
    exit 1
fi

PROFILE_DIR="$HOME/.config/chromium/agent-automation-fg"
CDP_PORT=${BH_CDP_PORT:-9222}

# Detect display (X11 or Wayland)
if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
    echo "Error: No X11 or Wayland display detected. Use run-agent-headless for background tasks."
    exit 1
fi

SANDBOX_FLAG=""
if [ "$(id -u)" = "0" ]; then
    SANDBOX_FLAG="--no-sandbox"
    echo "Warning: Running as root. Injecting --no-sandbox."
fi

echo "Cleaning up stale locks..."
cleanup_stale() {
    rm -f "$PROFILE_DIR/SingletonLock" "$PROFILE_DIR/SingletonCookie" "$PROFILE_DIR/SingletonSocket"
}
cleanup_stale
trap cleanup_stale EXIT INT TERM HUP QUIT

echo "Starting Agent Automation Browser (foreground login profile)..."

# Port collision check
PORT_IN_USE=0
if command -v lsof >/dev/null 2>&1; then
    lsof -i:$CDP_PORT -t >/dev/null 2>&1 && PORT_IN_USE=1
elif command -v ss >/dev/null 2>&1; then
    ss -lnt | grep -q ":$CDP_PORT " && PORT_IN_USE=1
elif command -v netstat >/dev/null 2>&1; then
    netstat -an | grep -q "LISTEN.*\.$CDP_PORT " && PORT_IN_USE=1
fi

if [ $PORT_IN_USE -eq 1 ]; then
    if ! pgrep -f "(chromium|chrome).*agent-automation-fg" >/dev/null 2>&1; then
        echo "Error: Port $CDP_PORT is in use by a different process. Please close it first to prevent profile collision."
        exit 1
    fi
fi

# Dynamic stealth User-Agent (POSIX-compliant extraction)
RAW_VER=$($CHROME_BIN --version 2>/dev/null || echo "")
CLEAN_VER=$(echo "$RAW_VER" | sed -n 's/.*[^0-9]\([0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}\).*/\1/p')
[ -z "$CLEAN_VER" ] && CLEAN_VER="148.0.0.0"
STEALTH_UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$CLEAN_VER Safari/537.36"

$CHROME_BIN \
  $SANDBOX_FLAG \
  --remote-debugging-port=$CDP_PORT \
  --user-data-dir="$PROFILE_DIR" \
  --remote-allow-origins='*' \
  --password-store=basic \
  --disable-backgrounding-occluded-windows \
  --disable-renderer-backgrounding \
  --disable-background-timer-throttling \
  --disable-blink-features=AutomationControlled \
  --disable-dev-shm-usage \
  --mute-audio \
  --no-first-run \
  --no-default-browser-check \
  --disable-sync \
  --disable-crash-reporter \
  --disable-breakpad \
  --disk-cache-dir=/dev/null \
  --disk-cache-size=1 \
  --user-agent="$STEALTH_UA"
