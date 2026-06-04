#!/usr/bin/env bats

setup() {
    TMP_HOME="$(mktemp -d)"
    export HOME="$TMP_HOME"
    mkdir -p "$TMP_HOME/.config/chromium/agent-automation-bg/Default"
    mkdir -p "$TMP_HOME/agent-workspace/downloads"
    source "$BATS_TEST_DIRNAME/../../lib/constants.sh"
    source "$BATS_TEST_DIRNAME/../../lib/log.sh"
    source "$BATS_TEST_DIRNAME/../../lib/cleanup.sh"
}

teardown() {
    rm -rf "$TMP_HOME"
}

@test "cleanup: removes Singleton files" {
    touch "$TMP_HOME/.config/chromium/agent-automation-bg/SingletonLock"
    touch "$TMP_HOME/.config/chromium/agent-automation-bg/SingletonCookie"
    touch "$TMP_HOME/.config/chromium/agent-automation-bg/SingletonSocket"
    agent_cleanup_singletons "$TMP_HOME/.config/chromium/agent-automation-bg"
    [ ! -f "$TMP_HOME/.config/chromium/agent-automation-bg/SingletonLock" ]
    [ ! -f "$TMP_HOME/.config/chromium/agent-automation-bg/SingletonCookie" ]
    [ ! -f "$TMP_HOME/.config/chromium/agent-automation-bg/SingletonSocket" ]
}

@test "cleanup: removes cache directories" {
    mkdir -p "$TMP_HOME/.config/chromium/agent-automation-bg/Default/Cache"
    mkdir -p "$TMP_HOME/.config/chromium/agent-automation-bg/Default/Code Cache"
    mkdir -p "$TMP_HOME/.config/chromium/agent-automation-bg/Default/GPUCache"
    touch "$TMP_HOME/.config/chromium/agent-automation-bg/Default/Cache/data_1"
    agent_cleanup_caches "$TMP_HOME/.config/chromium/agent-automation-bg"
    [ ! -d "$TMP_HOME/.config/chromium/agent-automation-bg/Default/Cache" ]
    [ ! -d "$TMP_HOME/.config/chromium/agent-automation-bg/Default/Code Cache" ]
    [ ! -d "$TMP_HOME/.config/chromium/agent-automation-bg/Default/GPUCache" ]
}

@test "cleanup: gc removes old download dirs" {
    mkdir -p "$TMP_HOME/agent-workspace/downloads/run_old1"
    mkdir -p "$TMP_HOME/agent-workspace/downloads/run_old2"
    mkdir -p "$TMP_HOME/agent-workspace/downloads/run_recent"
    # Touch backdates
    touch -d "10 days ago" "$TMP_HOME/agent-workspace/downloads/run_old1"
    touch -d "10 days ago" "$TMP_HOME/agent-workspace/downloads/run_old2"
    touch -d "1 day ago" "$TMP_HOME/agent-workspace/downloads/run_recent"
    agent_gc_downloads "$TMP_HOME/agent-workspace/downloads"
    [ ! -d "$TMP_HOME/agent-workspace/downloads/run_old1" ]
    [ ! -d "$TMP_HOME/agent-workspace/downloads/run_old2" ]
    [ -d "$TMP_HOME/agent-workspace/downloads/run_recent" ]
}
