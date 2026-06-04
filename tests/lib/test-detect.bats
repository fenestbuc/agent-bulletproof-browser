#!/usr/bin/env bats

setup() {
    source "$BATS_TEST_DIRNAME/../../lib/detect.sh"
}

@test "detect: extract_ver extracts Chromium version" {
    result=$(extract_ver "Chromium 147.0.7727.137")
    [ "$result" = "147.0.7727.137" ]
}

@test "detect: extract_ver extracts Chrome version" {
    result=$(extract_ver "Google Chrome 123.45.67.89")
    [ "$result" = "123.45.67.89" ]
}

@test "detect: extract_ver returns empty for no version" {
    result=$(extract_ver "No version here")
    [ -z "$result" ]
}

@test "detect: extract_ver handles single-digit segments" {
    result=$(extract_ver "Chromium 9.0.0.1")
    [ "$result" = "9.0.0.1" ]
}

@test "detect: build_stealth_ua uses provided version" {
    result=$(build_stealth_ua "150.1.2.3")
    [[ "$result" =~ "Chrome/150.1.2.3" ]]
    [[ "$result" =~ "Mozilla/5.0" ]]
}

@test "detect: platform_profile_root respects XDG_CONFIG_HOME" {
    XDG_CONFIG_HOME="/tmp/fake-config" run platform_profile_root
    [ "$status" -eq 0 ]
    [ "$output" = "/tmp/fake-config/chromium" ]
}

@test "detect: platform_profile_root falls back to HOME on Linux" {
    [ "$(uname)" = "Linux" ] || skip "Linux-only test"
    unset XDG_CONFIG_HOME
    run platform_profile_root
    [ "$status" -eq 0 ]
    [ "$output" = "$HOME/.config/chromium" ]
}

@test "detect: agent_profile_dir builds correct path" {
    XDG_CONFIG_HOME="/tmp/fc"
    result=$(agent_profile_dir "my-profile")
    [ "$result" = "/tmp/fc/chromium/my-profile" ]
}
