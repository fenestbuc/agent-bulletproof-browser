#!/bin/bash
# lib/constants.sh — Backwards-compatible shim that loads lib/config.sh.
# All defaults and precedence logic live in config.sh.

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_LIB_DIR/config.sh"
