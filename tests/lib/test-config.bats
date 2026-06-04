#!/usr/bin/env bats

setup() {
    TMP_HOME="$(mktemp -d)"
    export HOME="$TMP_HOME"
    mkdir -p "$TMP_HOME/.config/agent-browser"
}

teardown() {
    rm -rf "$TMP_HOME"
}

@test "config: loads from file when present" {
    cat > "$TMP_HOME/.config/agent-browser/config" <<'EOF'
AGENT_TIMEOUT=600
AGENT_LOG_LEVEL=error
EOF
    source "$BATS_TEST_DIRNAME/../../lib/config.sh"
    [ "$AGENT_TIMEOUT" = "600" ]
    [ "$AGENT_LOG_LEVEL" = "error" ]
}

@test "config: environment overrides file" {
    cat > "$TMP_HOME/.config/agent-browser/config" <<'EOF'
AGENT_TIMEOUT=600
EOF
    AGENT_TIMEOUT=900 source "$BATS_TEST_DIRNAME/../../lib/config.sh"
    [ "$AGENT_TIMEOUT" = "900" ]
}

@test "config: missing file keeps defaults" {
    rm -f "$TMP_HOME/.config/agent-browser/config"
    source "$BATS_TEST_DIRNAME/../../lib/config.sh"
    [ "$AGENT_TIMEOUT" = "300" ]
    [ "$AGENT_LOG_LEVEL" = "info" ]
}

@test "config: unknown keys are ignored" {
    cat > "$TMP_HOME/.config/agent-browser/config" <<'EOF'
SOME_RANDOM_KEY=foo
AGENT_TIMEOUT=400
EOF
    source "$BATS_TEST_DIRNAME/../../lib/config.sh"
    [ -z "${SOME_RANDOM_KEY:-}" ]
    [ "$AGENT_TIMEOUT" = "400" ]
}
