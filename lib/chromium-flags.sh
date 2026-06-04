#!/bin/bash
# lib/chromium-flags.sh — Shared Chromium flag builders.
# Sourced after lib/constants.sh and lib/detect.sh.

shared_flags() {
    cat <<'EOF'
--password-store=basic
--disable-backgrounding-occluded-windows
--disable-renderer-backgrounding
--disable-background-timer-throttling
--disable-blink-features=AutomationControlled
--disable-dev-shm-usage
--disable-gpu
--mute-audio
--no-first-run
--no-default-browser-check
--disable-sync
--disable-crash-reporter
--disable-breakpad
--disk-cache-dir=/dev/null
--disk-cache-size=1
--disable-popup-blocking
--disable-extensions
EOF
}

background_flags() {
    echo "--headless=new"
    shared_flags
}

foreground_flags() {
    shared_flags
}

build_command() {
    local mode="$1" profile_dir="$2" port="$3" ua="$4" sandbox_flag="$5"
    local flags
    if [ "$mode" = "bg" ]; then
        flags=$(background_flags)
    else
        flags=$(foreground_flags)
    fi
    echo "--remote-debugging-port=$port --user-data-dir=$profile_dir --remote-allow-origins='*' --user-agent=$ua $sandbox_flag $flags"
}
