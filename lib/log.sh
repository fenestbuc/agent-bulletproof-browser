#!/bin/bash
# lib/log.sh — Structured logging with JSON and plain-text backends.
# Sourced after lib/constants.sh.

AGENT_JSON_LOG="${AGENT_JSON_LOG:-0}"
AGENT_LOG_LEVEL="${AGENT_LOG_LEVEL:-info}"
_LOG_LEVEL_NUM=2 # 0=error, 1=warn, 2=info

case "$AGENT_LOG_LEVEL" in
    error) _LOG_LEVEL_NUM=0 ;;
    warn) _LOG_LEVEL_NUM=1 ;;
    info) _LOG_LEVEL_NUM=2 ;;
esac

agent_json_escape() {
    python3 -c "import json,sys; print(json.dumps(sys.argv[1]), end='')" "$1"
}

agent_log() {
    local level="$1" event="$2" message="${3:-}" detail="${4:-}"
    local lvl_num=2
    case "$level" in
        error) lvl_num=0 ;;
        warn) lvl_num=1 ;;
        info) lvl_num=2 ;;
    esac
    [ "$lvl_num" -gt "$_LOG_LEVEL_NUM" ] && return 0

    if [ "$AGENT_JSON_LOG" = "1" ]; then
        local ts
        ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        local msg_escaped
        msg_escaped=$(agent_json_escape "$message")
        local detail_field=""
        if [ -n "$detail" ]; then
            local det_escaped
            det_escaped=$(agent_json_escape "$detail")
            detail_field=", \"detail\": $det_escaped"
        fi
        echo "{\"ts\": \"$ts\", \"event\": \"$event\", \"level\": \"$level\", \"message\": $msg_escaped$detail_field}"
    else
        case "$event" in
            check_ok | check_fail)
                echo "  [$level] $message"
                ;;
            *)
                echo "[Process $$] $message"
                ;;
        esac
    fi
}
