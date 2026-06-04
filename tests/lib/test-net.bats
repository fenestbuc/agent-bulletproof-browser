#!/usr/bin/env bats

setup() {
    source "$BATS_TEST_DIRNAME/../../lib/net.sh"
    _MOCK_PIDS=""
}

teardown() {
    for pid in $_MOCK_PIDS; do
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    done
}

@test "net: find_free_port returns a valid integer" {
    port=$(find_free_port)
    [[ "$port" =~ ^[0-9]+$ ]]
    [ "$port" -gt 0 ]
    [ "$port" -lt 65536 ]
}

@test "net: port_in_use detects bound port" {
    python3 -c "
import socket, time, os
s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('127.0.0.1', 0))
port = s.getsockname()[1]
with open('/tmp/agent-bp-test-port-$$', 'w') as f:
    f.write(str(port))
s.listen(1)
time.sleep(2)
" &
    _MOCK_PIDS="$_MOCK_PIDS $!"
    sleep 0.5
    TEST_PORT=$(cat /tmp/agent-bp-test-port-$$ 2>/dev/null || true)
    rm -f /tmp/agent-bp-test-port-$$
    if [ -n "$TEST_PORT" ]; then
        run port_in_use "$TEST_PORT"
        [ "$status" -eq 0 ]
    else
        skip "Could not determine test port"
    fi
}

@test "net: port_in_use returns false for free port" {
    port=$(find_free_port)
    run port_in_use "$port"
    [ "$status" -eq 1 ]
}

@test "net: wait_for_cdp succeeds on mock endpoint" {
    python3 -c "
import socket, time
s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('127.0.0.1', 0))
port = s.getsockname()[1]
with open('/tmp/agent-bp-cdp-port-$$', 'w') as f:
    f.write(str(port))
s.listen(1)
conn, _ = s.accept()
conn.recv(1024)
conn.sendall(b'HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok')
conn.close()
time.sleep(1)
" &
    _MOCK_PIDS="$_MOCK_PIDS $!"
    sleep 0.3
    TEST_PORT=$(cat /tmp/agent-bp-cdp-port-$$ 2>/dev/null || true)
    rm -f /tmp/agent-bp-cdp-port-$$
    if [ -n "$TEST_PORT" ]; then
        run wait_for_cdp "http://127.0.0.1:$TEST_PORT/json/version" 2
        [ "$status" -eq 0 ]
    else
        skip "Could not start mock CDP endpoint"
    fi
}

@test "net: wait_for_cdp times out on dead port" {
    port=$(find_free_port)
    run wait_for_cdp "http://127.0.0.1:$port/json/version" 1
    [ "$status" -eq 1 ]
}

@test "net: cdp_health_check returns true for responsive endpoint" {
    python3 -c "
import socket, time
s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('127.0.0.1', 0))
port = s.getsockname()[1]
with open('/tmp/agent-bp-health-port-$$', 'w') as f:
    f.write(str(port))
s.listen(1)
conn, _ = s.accept()
conn.recv(1024)
conn.sendall(b'HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok')
conn.close()
time.sleep(1)
" &
    _MOCK_PIDS="$_MOCK_PIDS $!"
    sleep 0.3
    TEST_PORT=$(cat /tmp/agent-bp-health-port-$$ 2>/dev/null || true)
    rm -f /tmp/agent-bp-health-port-$$
    if [ -n "$TEST_PORT" ]; then
        run cdp_health_check "http://127.0.0.1:$TEST_PORT"
        [ "$status" -eq 0 ]
    else
        skip "Could not start mock health endpoint"
    fi
}

@test "net: cdp_health_check returns false for dead endpoint" {
    port=$(find_free_port)
    run cdp_health_check "http://127.0.0.1:$port"
    [ "$status" -ne 0 ]
}
