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
  --disable-background-timer-throttling