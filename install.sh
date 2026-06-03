#!/bin/bash
echo "Installing Universal Agent Bulletproof Browser Automation Kit..."

# Target universal script directory
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

echo "Deploying universal wrapper scripts to $BIN_DIR..."
cp scripts/run-agent-headless.sh "$BIN_DIR/run-agent-headless"
cp scripts/start-agent-browser.sh "$BIN_DIR/start-agent-browser"
chmod +x "$BIN_DIR/run-agent-headless" "$BIN_DIR/start-agent-browser"

# Detect and deploy skills to respective agents
HERMES_DIR="$HOME/.hermes"
OPENCLAW_DIR="$HOME/.openclaw"
SKILL_INSTALLED=0

if [ -d "$HERMES_DIR" ]; then
    echo "Found Hermes environment. Deploying skill..."
    mkdir -p "$HERMES_DIR/skills/devops/browser-harness"
    cp -r skills/browser-harness/* "$HERMES_DIR/skills/devops/browser-harness/"
    SKILL_INSTALLED=1
fi

if [ -d "$OPENCLAW_DIR" ]; then
    echo "Found OpenClaw environment. Deploying skill..."
    mkdir -p "$OPENCLAW_DIR/skills/browser-harness"
    cp -r skills/browser-harness/* "$OPENCLAW_DIR/skills/browser-harness/"
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
