#!/usr/bin/env bats

setup() {
    source "$BATS_TEST_DIRNAME/../../lib/constants.sh"
    source "$BATS_TEST_DIRNAME/../../lib/log.sh"
}

@test "log: plain output format is correct" {
    run agent_log info "test_event" "hello world"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[Process "* ]]
    [[ "$output" == *"hello world"* ]]
}

@test "log: check events use indented format" {
    run agent_log info "check_ok" "curl"
    [ "$status" -eq 0 ]
    [[ "$output" == *"  [info] curl"* ]]
}

@test "log: JSON output is valid" {
    AGENT_JSON_LOG=1 run agent_log info "json_test" "test message" "test detail"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -m json.tool >/dev/null 2>&1
}

@test "log: JSON contains all fields" {
    AGENT_JSON_LOG=1 run agent_log warn "my_event" "my msg" "my detail"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"event": "my_event"'* ]]
    [[ "$output" == *'"level": "warn"'* ]]
    [[ "$output" == *'"message": "my msg"'* ]]
    [[ "$output" == *'"detail": "my detail"'* ]]
}

@test "log: JSON omits detail when empty" {
    AGENT_JSON_LOG=1 run agent_log info "no_detail" "msg only"
    [ "$status" -eq 0 ]
    [[ ! "$output" == *'"detail":'* ]]
}

@test "log: error level suppresses info" {
    AGENT_LOG_LEVEL=error
    _LOG_LEVEL_NUM=0
    run agent_log info "hidden" "should not appear"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "log: warn level allows warn and error" {
    AGENT_LOG_LEVEL=warn
    _LOG_LEVEL_NUM=1
    run agent_log warn "visible_warn" "this should show"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "log: warn level suppresses info" {
    AGENT_LOG_LEVEL=warn
    _LOG_LEVEL_NUM=1
    run agent_log info "hidden_info" "this should not"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "log: json_escape handles quotes" {
    result=$(agent_json_escape 'say "hello"')
    [ "$result" = '"say \"hello\""' ]
}

@test "log: json_escape handles newlines" {
    result=$(agent_json_escape $'line1\nline2')
    [ "$result" = '"line1\nline2"' ]
}
