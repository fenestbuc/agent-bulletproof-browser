#!/bin/bash
set -euo pipefail

cleanup() {
    echo "Cleanup ran"
}
trap cleanup EXIT

EXIT_CODE=0
false
EXIT_CODE=$?
echo "Exit code was $EXIT_CODE"
