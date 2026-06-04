#!/usr/bin/env bats

setup() {
    source "$BATS_TEST_DIRNAME/../../lib/log.sh"
    source "$BATS_TEST_DIRNAME/../../lib/lock.sh"
    TMP_LOCK_DIR="$(mktemp -d)"
}

teardown() {
    rm -rf "$TMP_LOCK_DIR"
}

@test "lock: flock acquire and release (Linux)" {
    if ! command -v flock >/dev/null 2>&1; then
        skip "flock not available"
    fi
    lock="$TMP_LOCK_DIR/flock_test.lock"
    # Hold lock in a background bash process (subshells may leak fds in bats)
    bash -c 'exec 999>"$1"; flock -w 1 999; sleep 5' _ "$lock" &
    BG_PID=$!
    sleep 0.3
    run acquire_lock "$lock" 1
    [ "$status" -eq 1 ]
    kill "$BG_PID" 2>/dev/null || true
    wait "$BG_PID" 2>/dev/null || true
    sleep 0.2
    # After holder exits (fd closed), lock should be free
    run acquire_lock "$lock" 1
    [ "$status" -eq 0 ]
    release_lock
}

@test "lock: flock stale file lock recovery" {
    if ! command -v flock >/dev/null 2>&1; then
        skip "flock not available"
    fi
    lock="$TMP_LOCK_DIR/stale_flock.lock"
    touch "$lock"
    run acquire_lock "$lock" 1
    [ "$status" -eq 0 ]
    release_lock
}

@test "lock: mkdir fallback acquire and release" {
    if command -v flock >/dev/null 2>&1; then
        skip "flock is available; mkdir fallback not used"
    fi
    lock="$TMP_LOCK_DIR/mkdir_test"
    # Hold lock in background bash process
    bash -c 'mkdir -p "$1"; echo "$$" > "$1/.owner_pid"; sleep 5' _ "$lock" &
    BG_PID=$!
    sleep 0.3
    run acquire_lock "$lock" 1
    [ "$status" -eq 1 ]
    kill "$BG_PID" 2>/dev/null || true
    wait "$BG_PID" 2>/dev/null || true
    sleep 0.2
    # After holder exits, stale recovery should steal it
    run acquire_lock "$lock" 1
    [ "$status" -eq 0 ]
    release_lock
}

@test "lock: mkdir stale lock recovery" {
    if command -v flock >/dev/null 2>&1; then
        skip "flock is available; mkdir fallback not used"
    fi
    lock="$TMP_LOCK_DIR/stale_test"
    mkdir -p "$lock"
    echo "999999" > "$lock/.owner_pid"
    run acquire_lock "$lock" 1
    [ "$status" -eq 0 ]
    release_lock
}

@test "lock: mkdir does not steal live lock" {
    if command -v flock >/dev/null 2>&1; then
        skip "flock is available; mkdir fallback not used"
    fi
    lock="$TMP_LOCK_DIR/live_test"
    mkdir -p "$lock"
    echo "$$" > "$lock/.owner_pid"
    run acquire_lock "$lock" 1
    [ "$status" -eq 1 ]
}
