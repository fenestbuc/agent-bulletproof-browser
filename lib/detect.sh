#!/bin/bash
# lib/detect.sh — Cross-platform detection helpers.

extract_ver() {
    echo "$1" | sed -n 's/.*[^0-9]\([0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}\).*/\1/p'
}

build_stealth_ua() {
    local ver="${1:-148.0.0.0}"
    echo "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$ver Safari/537.36"
}

detect_chrome() {
    command -v chromium-browser || command -v chromium || command -v google-chrome || command -v google-chrome-stable || true
}

platform_profile_root() {
    local root
    if [ -n "${XDG_CONFIG_HOME:-}" ]; then
        root="$XDG_CONFIG_HOME/chromium"
    else
        case "$(uname)" in
            Darwin)
                root="$HOME/Library/Application Support/Chromium"
                ;;
            *)
                root="$HOME/.config/chromium"
                ;;
        esac
    fi
    echo "$root"
}

agent_profile_dir() {
    local name="$1"
    echo "$(platform_profile_root)/$name"
}

detect_display() {
    case "$(uname)" in
        Darwin)
            # macOS always has a WindowServer if GUI is available.
            # Quick check via osascript is expensive; just check env.
            if [ -z "${DISPLAY:-}" ]; then
                # On macOS, DISPLAY may not be set but GUI still exists
                return 0
            fi
            ;;
    esac
    if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
        return 1
    fi
    return 0
}
