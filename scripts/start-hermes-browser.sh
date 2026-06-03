#!/bin/bash
PROFILE_DIR="$HOME/.config/chromium/hermes-automation"

echo "Cleaning up stale locks..."
rm -f "$PROFILE_DIR/SingletonLock"
rm -f "$PROFILE_DIR/SingletonCookie"
rm -f "$PROFILE_DIR/SingletonSocket"

echo "Starting Hermes Automation Browser..."
# We launch without nohup so it can be managed cleanly by the user or background task
chromium-browser \
  --remote-debugging-port=9222 \
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
  --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36"
