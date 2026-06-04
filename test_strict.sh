#!/bin/bash
set -euo pipefail

cleanup() {
    echo "Running cleanup"
    if [ "$WE_STARTED_BROWSER" = "1" ]; then
        echo "We started it"
    fi
}
trap cleanup EXIT

echo "Starting..."
exit 1
