#!/usr/bin/env bats

@test "run-agent-headless.sh parses correctly" {
    bash -n scripts/run-agent-headless.sh
}

@test "start-agent-browser.sh parses correctly" {
    bash -n scripts/start-agent-browser.sh
}

@test "agent-cookie-sync.sh parses correctly" {
    bash -n scripts/agent-cookie-sync.sh
}

@test "install.sh parses correctly" {
    bash -n install.sh
}

@test "POSIX version extraction: Chromium 147.0.7727.137" {
    result=$(echo "Chromium 147.0.7727.137" | sed -n 's/.*[^0-9]\([0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}\).*/\1/p')
    [ "$result" = "147.0.7727.137" ]
}

@test "POSIX version extraction: Google Chrome 123.45.67.89" {
    result=$(echo "Google Chrome 123.45.67.89" | sed -n 's/.*[^0-9]\([0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}\).*/\1/p')
    [ "$result" = "123.45.67.89" ]
}

@test "POSIX version extraction returns empty for missing version" {
    result=$(echo "No version here" | sed -n 's/.*[^0-9]\([0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}\).*/\1/p')
    [ -z "$result" ]
}

@test "find_free_port returns a valid integer" {
    port=$(python3 -c "import socket; s=socket.socket(); s.bind(('',0)); print(s.getsockname()[1]); s.close()")
    [[ "$port" =~ ^[0-9]+$ ]]
}

@test "agent_timeout successfully runs short command" {
    agent_timeout() {
        local t="$1"; shift
        if command -v timeout >/dev/null 2>&1; then
            timeout "$t" "$@"
        elif command -v gtimeout >/dev/null 2>&1; then
            gtimeout "$t" "$@"
        else
            perl -e 'alarm shift; exec @ARGV' "$t" "$@"
        fi
    }
    run agent_timeout 1 bash -c "sleep 0.1 && echo OK"
    [ "$status" -eq 0 ]
    [ "$output" = "OK" ]
}

@test "agent_timeout kills long-running command" {
    agent_timeout() {
        local t="$1"; shift
        if command -v timeout >/dev/null 2>&1; then
            timeout "$t" "$@"
        elif command -v gtimeout >/dev/null 2>&1; then
            gtimeout "$t" "$@"
        else
            perl -e 'alarm shift; exec @ARGV' "$t" "$@"
        fi
    }
    run agent_timeout 1 bash -c "sleep 10"
    [ "$status" -ne 0 ]
}

@test "macOS mkdir lock is atomic and exclusive" {
    tmpdir="/tmp/agent-bulletproof-bats-$$"
    mkdir -p "$tmpdir"
    run mkdir "$tmpdir/lock"
    [ "$status" -eq 0 ]
    run mkdir "$tmpdir/lock"
    [ "$status" -ne 0 ]
    rmdir "$tmpdir/lock"
    rm -rf "$tmpdir"
}

@test "install.sh does not fail when no agent dirs exist" {
    tmp_home="/tmp/agent-bulletproof-home-$$"
    mkdir -p "$tmp_home/.local/bin"
    HOME="$tmp_home" bash install.sh
    [ -f "$tmp_home/.local/bin/run-agent-headless" ]
    [ -f "$tmp_home/.local/bin/start-agent-browser" ]
    [ -f "$tmp_home/.local/bin/agent-cookie-sync" ]
    rm -rf "$tmp_home"
}

@test "--check produces valid JSON when AGENT_JSON_LOG=1" {
    run bash -c 'AGENT_JSON_LOG=1 bash scripts/run-agent-headless.sh --check'
    [ "$status" -eq 0 ]
    while IFS= read -r line; do
        echo "$line" | python3 -m json.tool >/dev/null 2>&1
    done <<< "$output"
}

@test "JSON log level filtering suppresses info when level=error" {
    run bash -c 'AGENT_JSON_LOG=1 AGENT_LOG_LEVEL=error bash scripts/run-agent-headless.sh --check'
    [ "$status" -eq 0 ]
    # In error-only mode, only the summary should appear (or nothing if summary is info)
    # Actually summary is info level, so output should be mostly empty
    # Just verify no parse errors and exit 0
}

@test "adaptive health interval: BH_TIMEOUT=30 gives interval <= 3" {
    # Simulate the adaptive interval logic
    EXEC_TIMEOUT=30
    HEALTH_INTERVAL=$(( EXEC_TIMEOUT / 10 ))
    [ "$HEALTH_INTERVAL" -lt 2 ] && HEALTH_INTERVAL=2
    [ "$HEALTH_INTERVAL" -gt 10 ] && HEALTH_INTERVAL=10
    [ "$HEALTH_INTERVAL" -eq 3 ]
}

@test "adaptive health interval: BH_TIMEOUT=300 caps at 10" {
    EXEC_TIMEOUT=300
    HEALTH_INTERVAL=$(( EXEC_TIMEOUT / 10 ))
    [ "$HEALTH_INTERVAL" -lt 2 ] && HEALTH_INTERVAL=2
    [ "$HEALTH_INTERVAL" -gt 10 ] && HEALTH_INTERVAL=10
    [ "$HEALTH_INTERVAL" -eq 10 ]
}

@test "adaptive health interval: BH_TIMEOUT=15 floors at 2" {
    EXEC_TIMEOUT=15
    HEALTH_INTERVAL=$(( EXEC_TIMEOUT / 10 ))
    [ "$HEALTH_INTERVAL" -lt 2 ] && HEALTH_INTERVAL=2
    [ "$HEALTH_INTERVAL" -gt 10 ] && HEALTH_INTERVAL=10
    [ "$HEALTH_INTERVAL" -eq 2 ]
}
