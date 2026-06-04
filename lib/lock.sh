#!/bin/bash
# lib/lock.sh — Cross-platform locking with stale lock recovery.
# Sourced after lib/log.sh.

AGENT_LOCK_DIR=""

acquire_lock() {
    local lockfile="$1" wait_sec="${2:-120}"
    if command -v flock >/dev/null 2>&1; then
        exec 999>"$lockfile"
        if ! flock -w "$wait_sec" 999; then
            return 1
        fi
    else
        # macOS / BSD fallback: mkdir is atomic on local filesystems
        local end=$((SECONDS + wait_sec))
        while true; do
            if mkdir "$lockfile" 2>/dev/null; then
                AGENT_LOCK_DIR="$lockfile"
                echo "$$" >"$lockfile/.owner_pid"
                return 0
            fi
            # Stale lock detection
            if [ -f "$lockfile/.owner_pid" ]; then
                local owner
                owner=$(cat "$lockfile/.owner_pid" 2>/dev/null || true)
                if [ -n "$owner" ] && ! kill -0 "$owner" 2>/dev/null; then
                    agent_log warn "stale_lock" "Removing stale lock from dead PID $owner" ""
                    rm -rf "$lockfile"
                    if mkdir "$lockfile" 2>/dev/null; then
                        AGENT_LOCK_DIR="$lockfile"
                        echo "$$" >"$lockfile/.owner_pid"
                        return 0
                    fi
                fi
            fi
            if [ $SECONDS -ge $end ]; then
                return 1
            fi
            sleep 1
        done
    fi
}

release_lock() {
    if [ -n "${AGENT_LOCK_DIR:-}" ]; then
        rm -f "$AGENT_LOCK_DIR/.owner_pid" 2>/dev/null || true
        rmdir "$AGENT_LOCK_DIR" 2>/dev/null || true
        AGENT_LOCK_DIR=""
    fi
}
