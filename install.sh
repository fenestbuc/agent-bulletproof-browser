#!/bin/bash
set -euo pipefail

echo "Installing Universal Agent Bulletproof Browser Automation Kit..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

echo "Deploying universal wrapper scripts to $BIN_DIR..."
cp "$SCRIPT_DIR/scripts/run-agent-headless.sh" "$BIN_DIR/run-agent-headless"
cp "$SCRIPT_DIR/scripts/start-agent-browser.sh" "$BIN_DIR/start-agent-browser"
cp "$SCRIPT_DIR/scripts/agent-cookie-sync.sh" "$BIN_DIR/agent-cookie-sync"
chmod +x "$BIN_DIR/run-agent-headless" "$BIN_DIR/start-agent-browser" "$BIN_DIR/agent-cookie-sync"

# Ensure ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo "Adding $BIN_DIR to PATH in ~/.bashrc..."
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    export PATH="$HOME/.local/bin:$PATH"
fi

# Create dedicated profiles for foreground (login) and background (automation)
PROFILES=(
    "$HOME/.config/chromium/agent-automation-fg"
    "$HOME/.config/chromium/agent-automation-bg"
)
for p in "${PROFILES[@]}"; do
    mkdir -p "$p/Default"
done

# Create workspace directory for downloads
mkdir -p "$HOME/agent-workspace/downloads"

# Detect and deploy skills to respective agents
HERMES_DIR="$HOME/.hermes"
OPENCLAW_DIR="$HOME/.openclaw"
CLAUDE_DIR="$HOME/.claude"
SKILL_INSTALLED=0

if [ -d "$HERMES_DIR" ]; then
    echo "Found Hermes environment. Deploying skill..."
    mkdir -p "$HERMES_DIR/skills/devops/browser-harness"
    cp -r "$SCRIPT_DIR/skills/browser-harness/"* "$HERMES_DIR/skills/devops/browser-harness/"
    SKILL_INSTALLED=1
fi

if [ -d "$OPENCLAW_DIR" ]; then
    echo "Found OpenClaw environment. Deploying skill..."
    mkdir -p "$OPENCLAW_DIR/skills/browser-harness"
    cp -r "$SCRIPT_DIR/skills/browser-harness/"* "$OPENCLAW_DIR/skills/browser-harness/"
    SKILL_INSTALLED=1
fi

if [ -d "$CLAUDE_DIR" ]; then
    echo "Found Claude environment. Deploying skill..."
    mkdir -p "$CLAUDE_DIR/skills/browser-harness"
    cp -r "$SCRIPT_DIR/skills/browser-harness/"* "$CLAUDE_DIR/skills/browser-harness/"
    SKILL_INSTALLED=1
fi

if [ $SKILL_INSTALLED -eq 0 ]; then
    echo "Warning: No supported agent directories (Hermes/OpenClaw/Claude) found."
    echo "Skills were not deployed, but universal CLI commands are available in ~/.local/bin."
fi

echo ""
echo "Installation Complete!"
echo "Foreground login:    start-agent-browser"
echo "Cookie sync:         agent-cookie-sync"
echo "Background wrapper:  run-agent-headless '<script>'"
