#!/bin/bash
set -euo pipefail

# =============================================================================
# Agent Bulletproof Browser — Foreground Login Helper
# =============================================================================
# Launches a visible Chromium instance for one-time interactive logins.
# Uses a dedicated *foreground* profile so background tasks never collide.
# =============================================================================

if [ -n "${AGENT_BROWSER_LIB:-}" ]; then
    _LIB_DIR="$AGENT_BROWSER_LIB"
else
    _SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    _LIB_DIR="$_SCRIPT_DIR/../lib"
fi
source "$_LIB_DIR/config.sh"
source "$_LIB_DIR/detect.sh"
source "$_LIB_DIR/net.sh"
source "$_LIB_DIR/chromium-flags.sh"

CHROME_BIN=$(detect_chrome)
if [ -z "$CHROME_BIN" ]; then
    echo "Error: No Chromium or Google Chrome executable found in PATH."
    exit 1
fi

PROFILE_DIR=$(agent_profile_dir "agent-automation-fg")
CDP_PORT=${BH_CDP_PORT:-$AGENT_CDP_PORT}

# Detect display (X11 or Wayland)
if ! detect_display; then
    echo "Error: No X11 or Wayland display detected. Use run-agent-headless for background tasks."
    exit 1
fi

SANDBOX_FLAG=""
if [ "$(id -u)" = "0" ]; then
    SANDBOX_FLAG="--no-sandbox"
    echo "Warning: Running as root. Injecting --no-sandbox."
fi

echo "Cleaning up stale locks..."
agent_cleanup_singletons() {
    local profile_dir="$1"
    rm -f "$profile_dir/SingletonLock" "$profile_dir/SingletonCookie" "$profile_dir/SingletonSocket"
}
agent_cleanup_singletons "$PROFILE_DIR"
trap 'agent_cleanup_singletons "$PROFILE_DIR"' EXIT INT TERM HUP QUIT

echo "Starting Agent Automation Browser (foreground login profile)..."

# Port collision check
PORT_IN_USE=0
if port_in_use "$CDP_PORT"; then
    PORT_IN_USE=1
fi

if [ "$PORT_IN_USE" -eq 1 ]; then
    if ! pgrep -f "(chromium|chrome).*agent-automation-fg" >/dev/null 2>&1; then
        echo "Error: Port $CDP_PORT is in use by a different process. Please close it first to prevent profile collision."
        exit 1
    fi
fi

RAW_VER=$($CHROME_BIN --version 2>/dev/null || echo "")
CLEAN_VER=$(extract_ver "$RAW_VER")
[ -z "$CLEAN_VER" ] && CLEAN_VER="$AGENT_DEFAULT_UA_VERSION"
STEALTH_UA=$(build_stealth_ua "$CLEAN_VER")

# shellcheck disable=SC2046
$CHROME_BIN \
    $SANDBOX_FLAG \
    --remote-debugging-port="$CDP_PORT" \
    --user-data-dir="$PROFILE_DIR" \
    --remote-allow-origins='*' \
    --password-store=basic \
    $(foreground_flags) \
    --user-agent="$STEALTH_UA"
