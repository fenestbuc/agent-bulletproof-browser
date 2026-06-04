#!/bin/bash
set -euo pipefail

echo "Installing Universal Agent Bulletproof Browser Automation Kit..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.local/share/agent-browser"
BIN_DIR="$HOME/.local/bin"

mkdir -p "$BIN_DIR"
mkdir -p "$INSTALL_DIR"

echo "Deploying kit to $INSTALL_DIR..."
cp -r "$SCRIPT_DIR/scripts" "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/lib" "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/skills" "$INSTALL_DIR/"

echo "Deploying universal wrapper scripts to $BIN_DIR..."
for cmd in run-agent-headless start-agent-browser agent-cookie-sync; do
    cat >"$BIN_DIR/$cmd" <<EOF
#!/bin/bash
export AGENT_BROWSER_LIB="$INSTALL_DIR/lib"
exec "$INSTALL_DIR/scripts/${cmd}.sh" "\$@"
EOF
    chmod +x "$BIN_DIR/$cmd"
done

# Ensure ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    if ! grep -q 'export PATH="\$HOME/.local/bin:\$PATH"' "$HOME/.bashrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >>"$HOME/.bashrc"
        export PATH="$BIN_DIR:$PATH"
    fi
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

# Create default config file if absent
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/agent-browser"
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_DIR/config" ]; then
    cat >"$CONFIG_DIR/config" <<'EOF'
# Agent Browser Configuration
# Precedence: defaults < this file < environment variables
#
# AGENT_TIMEOUT=300
# AGENT_CDP_PORT=9222
# AGENT_LOCK_TIMEOUT=120
# AGENT_DISK_THRESHOLD_MB=500
# AGENT_SKIP_IF_LOCKED=0
# AGENT_JSON_LOG=0
# AGENT_LOG_LEVEL=info
EOF
fi

# Detect and deploy skills to respective agents
HERMES_DIR="$HOME/.hermes"
OPENCLAW_DIR="$HOME/.openclaw"
CLAUDE_DIR="$HOME/.claude"
SKILL_INSTALLED=0

if [ -d "$HERMES_DIR" ]; then
    echo "Found Hermes environment. Deploying skill..."
    mkdir -p "$HERMES_DIR/skills/devops/browser-harness"
    cp -r "$INSTALL_DIR/skills/browser-harness/"* "$HERMES_DIR/skills/devops/browser-harness/"
    SKILL_INSTALLED=1
fi

if [ -d "$OPENCLAW_DIR" ]; then
    echo "Found OpenClaw environment. Deploying skill..."
    mkdir -p "$OPENCLAW_DIR/skills/browser-harness"
    cp -r "$INSTALL_DIR/skills/browser-harness/"* "$OPENCLAW_DIR/skills/browser-harness/"
    SKILL_INSTALLED=1
fi

if [ -d "$CLAUDE_DIR" ]; then
    echo "Found Claude environment. Deploying skill..."
    mkdir -p "$CLAUDE_DIR/skills/browser-harness"
    cp -r "$INSTALL_DIR/skills/browser-harness/"* "$CLAUDE_DIR/skills/browser-harness/"
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
