#!/bin/bash
set -euo pipefail

echo "Uninstalling Agent Bulletproof Browser Automation Kit..."

INSTALL_DIR="$HOME/.local/share/agent-browser"
BIN_DIR="$HOME/.local/bin"

# Remove wrapper scripts
for cmd in run-agent-headless start-agent-browser agent-cookie-sync; do
    if [ -f "$BIN_DIR/$cmd" ]; then
        rm -f "$BIN_DIR/$cmd"
        echo "Removed $BIN_DIR/$cmd"
    fi
done

# Remove install directory
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo "Removed $INSTALL_DIR"
fi

# Optionally remove profiles (ask user)
read -r -p "Remove browser profiles (agent-automation-fg and agent-automation-bg)? [y/N] " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    FG_PROFILE="$HOME/.config/chromium/agent-automation-fg"
    BG_PROFILE="$HOME/.config/chromium/agent-automation-bg"
    rm -rf "$FG_PROFILE" "$BG_PROFILE"
    echo "Removed profiles."
fi

# Remove config
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/agent-browser"
if [ -d "$CONFIG_DIR" ]; then
    rm -rf "$CONFIG_DIR"
    echo "Removed $CONFIG_DIR"
fi

echo "Uninstall complete."
