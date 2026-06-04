#!/usr/bin/env bats

setup() {
    source "$BATS_TEST_DIRNAME/../../lib/constants.sh"
    source "$BATS_TEST_DIRNAME/../../lib/detect.sh"
    source "$BATS_TEST_DIRNAME/../../lib/chromium-flags.sh"
}

@test "flags: shared_flags contains anti-detection flags" {
    result=$(shared_flags)
    [[ "$result" =~ "--disable-blink-features=AutomationControlled" ]]
    [[ "$result" =~ "--disable-dev-shm-usage" ]]
    [[ "$result" =~ "--disable-gpu" ]]
    [[ "$result" =~ "--mute-audio" ]]
    [[ "$result" =~ "--no-first-run" ]]
}

@test "flags: shared_flags contains cache disable" {
    result=$(shared_flags)
    [[ "$result" =~ "--disk-cache-dir=/dev/null" ]]
    [[ "$result" =~ "--disk-cache-size=1" ]]
}

@test "flags: background_flags includes headless" {
    result=$(background_flags)
    [[ "$result" =~ "--headless=new" ]]
}

@test "flags: background_flags includes shared flags" {
    result=$(background_flags)
    [[ "$result" =~ "--disable-blink-features=AutomationControlled" ]]
}

@test "flags: foreground_flags excludes headless" {
    result=$(foreground_flags)
    [[ ! "$result" =~ "--headless" ]]
}

@test "flags: foreground_flags includes shared flags" {
    result=$(foreground_flags)
    [[ "$result" =~ "--disable-blink-features=AutomationControlled" ]]
}

@test "flags: build_command assembles background command" {
    result=$(build_command "bg" "/tmp/profile" "9222" "Mozilla/5.0" "")
    [[ "$result" =~ "--headless=new" ]]
    [[ "$result" =~ "--user-data-dir=/tmp/profile" ]]
    [[ "$result" =~ "--remote-debugging-port=9222" ]]
    [[ "$result" =~ "--user-agent=Mozilla/5.0" ]]
}

@test "flags: build_command includes no-sandbox for root" {
    result=$(build_command "bg" "/tmp/profile" "9222" "UA" "--no-sandbox")
    [[ "$result" =~ "--no-sandbox" ]]
}
