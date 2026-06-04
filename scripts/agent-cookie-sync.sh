#!/bin/bash
set -euo pipefail

# =============================================================================
# Agent Cookie Sync — Copy auth state from foreground to background profile
# =============================================================================
# After logging into platforms (X, LinkedIn, etc.) via start-agent-browser,
# run this script to copy cookies and decrypted session state to the
# background profile so headless automation can reuse them.
#
# Usage: agent-cookie-sync
# =============================================================================

FG_PROFILE="$HOME/.config/chromium/agent-automation-fg"
BG_PROFILE="$HOME/.config/chromium/agent-automation-bg"

if [ ! -d "$FG_PROFILE" ]; then
    echo "Error: Foreground profile not found at $FG_PROFILE"
    echo "Run 'start-agent-browser' first to create it and log into your platforms."
    exit 1
fi

echo "Syncing auth state from foreground to background profile..."
mkdir -p "$BG_PROFILE"

# Files that carry decrypted login state when --password-store=basic is used
AUTH_FILES=(
    "Local State"
    "Default/Cookies"
    "Default/Login Data"
    "Default/Web Data"
    "Default/Network Persistent State"
    "Default/Preferences"
    "Default/Secure Preferences"
)

copied=0
skipped=0
for rel in "${AUTH_FILES[@]}"; do
    src="$FG_PROFILE/$rel"
    dst="$BG_PROFILE/$rel"
    if [ -f "$src" ]; then
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        echo "  [OK] $rel"
        ((copied++)) || true
    else
        echo "  [SKIP] $rel (not present in foreground)"
        ((skipped++)) || true
    fi
done

echo ""
echo "Sync complete. ${copied} file(s) copied, ${skipped} skipped."
echo "Background automation can now use the same logged-in sessions."
