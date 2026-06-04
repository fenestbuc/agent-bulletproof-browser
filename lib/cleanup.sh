#!/bin/bash
# lib/cleanup.sh — Cleanup routines for browser lifecycle.
# Sourced after lib/constants.sh and lib/log.sh.

agent_cleanup_singletons() {
    local profile_dir="$1"
    rm -f "$profile_dir/SingletonLock" "$profile_dir/SingletonCookie" "$profile_dir/SingletonSocket"
}

agent_cleanup_caches() {
    local profile_dir="$1"
    rm -rf "$profile_dir/Default/Cache" "$profile_dir/Default/Code Cache" "$profile_dir/Default/GPUCache" 2>/dev/null || true
}

agent_gc_downloads() {
    local downloads_dir="$1"
    find "$downloads_dir" -maxdepth 1 -name "run_*" -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
}

agent_cleanup_download_dir() {
    local dir="$1"
    rmdir "$dir" 2>/dev/null || true
}
