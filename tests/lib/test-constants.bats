#!/usr/bin/env bats

setup() {
    # Source constants from repo root
    source "$BATS_TEST_DIRNAME/../../lib/constants.sh"
}

@test "constants: AGENT_TIMEOUT defaults to 300" {
    [ "$AGENT_TIMEOUT" = "300" ]
}

@test "constants: AGENT_CDP_PORT defaults to 9222" {
    [ "$AGENT_CDP_PORT" = "9222" ]
}

@test "constants: AGENT_LOCK_TIMEOUT defaults to 120" {
    [ "$AGENT_LOCK_TIMEOUT" = "120" ]
}

@test "constants: AGENT_DISK_THRESHOLD_MB defaults to 500" {
    [ "$AGENT_DISK_THRESHOLD_MB" = "500" ]
}

@test "constants: AGENT_SKIP_IF_LOCKED defaults to 0" {
    [ "$AGENT_SKIP_IF_LOCKED" = "0" ]
}

@test "constants: AGENT_JSON_LOG defaults to 0" {
    [ "$AGENT_JSON_LOG" = "0" ]
}

@test "constants: AGENT_LOG_LEVEL defaults to info" {
    [ "$AGENT_LOG_LEVEL" = "info" ]
}

@test "constants: default UA fallback version is 148.0.0.0" {
    [ "$AGENT_DEFAULT_UA_VERSION" = "148.0.0.0" ]
}
