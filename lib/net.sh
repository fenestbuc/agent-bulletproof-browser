#!/bin/bash
# lib/net.sh — Network helpers for CDP port and health checks.

find_free_port() {
    python3 -c "import socket; s=socket.socket(); s.bind(('',0)); print(s.getsockname()[1]); s.close()"
}

port_in_use() {
    local port="$1"
    if command -v lsof >/dev/null 2>&1; then
        lsof -i:"$port" -t >/dev/null 2>&1
    elif command -v ss >/dev/null 2>&1; then
        ss -lnt | grep -q ":$port "
    elif command -v netstat >/dev/null 2>&1; then
        netstat -an | grep -q "LISTEN.*\.$port "
    else
        if python3 -c "import socket; s=socket.socket(); s.bind(('127.0.0.1',$port)); s.close()" 2>/dev/null; then
            return 1
        else
            return 0
        fi
    fi
}

wait_for_cdp() {
    local url="$1" max_wait="${2:-10}"
    local waited=0
    while [ "$waited" -lt "$max_wait" ]; do
        if curl -s "$url" >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.5
        waited=$((waited + 1))
    done
    return 1
}

cdp_health_check() {
    local url="$1"
    curl -s "$url/json/version" >/dev/null 2>&1
}
