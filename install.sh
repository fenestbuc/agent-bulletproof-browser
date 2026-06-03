#!/bin/bash

echo "Installing Hermes Bulletproof Browser Automation Kit..."

# Create necessary directories
mkdir -p ~/.hermes/scripts
mkdir -p ~/.hermes/skills/devops

# Install scripts
echo "Deploying wrapper scripts..."
cp scripts/run-hermes-headless.sh ~/.hermes/scripts/
cp scripts/start-hermes-browser.sh ~/.hermes/scripts/
chmod +x ~/.hermes/scripts/*.sh

# Install the agent skill
echo "Deploying AI skill documentation..."
cp -r skills/browser-harness ~/.hermes/skills/devops/

echo ""
echo "✅ Installation Complete!"
echo "Foreground login: ~/.hermes/scripts/start-hermes-browser.sh"
echo "Background wrapper: ~/.hermes/scripts/run-hermes-headless.sh '<script>'"