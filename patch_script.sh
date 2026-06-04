#!/bin/bash
CHROME_BIN=$(command -v chromium-browser || command -v chromium || command -v google-chrome)
if [ -z "$CHROME_BIN" ]; then
    echo "Error: No Chromium/Chrome executable found."
    exit 1
fi
echo "Found Chrome at $CHROME_BIN"
CHROME_VER=$($CHROME_BIN --version | awk '{print $2}')
echo "Chrome Version: $CHROME_VER"
