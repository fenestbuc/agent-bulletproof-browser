#!/bin/bash
set -euo pipefail

CHROME_BIN=$(command -v chromium-browser || command -v chromium || command -v google-chrome || command -v google-chrome-stable || true)
if [ -z "$CHROME_BIN" ]; then
    echo "Error: No Chromium or Google Chrome executable found in PATH."
    exit 1
fi

PROFILE_DIR="$HOME/.config/chromium/agent-automation"
CDP_PORT=${BH_CDP_PORT:-9222}

echo "Cleaning up stale locks..."
rm -f "$PROFILE_DIR/SingletonLock"
rm -f "$PROFILE_DIR/SingletonCookie"
rm -f "$PROFILE_DIR/SingletonSocket"

echo "Starting Agent Automation Browser..."
# We launch without nohup so it can be managed cleanly by the user or background task

# Check if port is in use by another instance not managed by us
if lsof -i:$CDP_PORT -t >/dev/null 2>&1; then
    if ! ps aux | grep -E "(chromium|chrome).*agent-automation" >/dev/null 2>&1; then
        echo "Error: Port $CDP_PORT is in use by a different process. Please close it first to prevent profile collision."
        exit 1
    fi
fi

# Dynamically construct a stealth User-Agent based on the actual installed binary version
# This prevents WAF bans (like Cloudflare) that flag outdated browser versions over time
RAW_VER=$($CHROME_BIN --version | awk '{print $2}')
# Some distributions might return "Chromium 148.0..." instead of just the number, so we strip non-numerics if necessary
CLEAN_VER=$(echo "$RAW_VER" | grep -oP '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' || echo "148.0.0.0")
STEALTH_UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$CLEAN_VER Safari/537.36"

$CHROME_BIN \
  --remote-debugging-port=$CDP_PORT \
  --user-data-dir="$PROFILE_DIR" \
  --remote-allow-origins='*' \
  --password-store=basic \
  --disable-backgrounding-occluded-windows \
  --disable-renderer-backgrounding \
  --disable-background-timer-throttling \
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
