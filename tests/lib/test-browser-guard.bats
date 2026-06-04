#!/usr/bin/env bats

setup() {
    GUARD="$BATS_TEST_DIRNAME/../../lib/browser_guard.py"
}

@test "guard: script parses as valid Python" {
    python3 -m py_compile "$GUARD"
}

@test "guard: write_pid creates pid file" {
    tmp_pidfile="$(mktemp)"
    python3 -c "
import sys
sys.path.insert(0, '$(dirname "$GUARD")')
from browser_guard import write_pid
write_pid(12345, '$tmp_pidfile')
"
    [ "$(cat "$tmp_pidfile")" = "12345" ]
    rm -f "$tmp_pidfile"
}

@test "guard: ppid_watcher detects parent death" {
    python3 -c "
import sys
sys.path.insert(0, '$(dirname "$GUARD")')
import browser_guard
assert callable(browser_guard.run_with_prctl)
assert callable(browser_guard.run_with_ppid_watch)
"
}
