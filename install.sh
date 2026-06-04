#!/bin/bash
echo "Installing Universal Agent Bulletproof Browser Automation Kit..."

# Resolve absolute directory of this script to allow execution from anywhere
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Target universal script directory
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

echo "Deploying universal wrapper scripts to $BIN_DIR..."
cp "$SCRIPT_DIR/scripts/run-agent-headless.sh" "$BIN_DIR/run-agent-headless"
cp "$SCRIPT_DIR/scripts/start-agent-browser.sh" "$BIN_DIR/start-agent-browser"
chmod +x "$BIN_DIR/run-agent-headless" "$BIN_DIR/start-agent-browser"

# Ensure ~/.local/bin is in PATH for the current session and future sessions
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo "Adding $BIN_DIR to PATH in ~/.bashrc..."
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    export PATH="$HOME/.local/bin:$PATH"
fi

# Detect and deploy skills to respective agents
HERMES_DIR="$HOME/.hermes"
OPENCLAW_DIR="$HOME/.openclaw"
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

if [ $SKILL_INSTALLED -eq 0 ]; then
    echo "Warning: Neither Hermes nor OpenClaw directories found."
    echo "Skills were not deployed, but universal CLI commands are available in ~/.local/bin."
fi

echo ""
echo "✅ Installation Complete!"
echo "Foreground login: run 'start-agent-browser' in terminal."
echo "Background wrapper: run 'run-agent-headless \"<script>\"' in terminal."
