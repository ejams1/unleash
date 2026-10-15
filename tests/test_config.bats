#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/config.sh'
  CONFIG_FILE=$(mktemp)
  rm -f "$CONFIG_FILE"
}

teardown() {
  rm -f "$CONFIG_FILE"
}

@test "load_config handles missing file" {
  CONFIG_FILE="/nonexistent/config"
  run load_config
  [ "$status" -eq 0 ]
}

@test "save_config writes key=value" {
  save_config "WEBHOOK" "https://example.com" 2>/dev/null || true
  run grep "WEBHOOK=https://example.com" "$CONFIG_FILE"
  [ "$status" -eq 0 ]
}

@test "save_config accepts a value containing slashes" {
  # A "/" in the value used to break the sed replacement expression, and
  # `set -e` then killed the whole script.
  run bash -c "
    set -euo pipefail
    source '$BATS_TEST_DIRNAME/../lib/colors.sh'
    source '$BATS_TEST_DIRNAME/../lib/config.sh'
    CONFIG_FILE='$CONFIG_FILE'
    save_config WEBHOOK 'https://discord.com/api/webhooks/123/abc'
  "
  [ "$status" -eq 0 ]
  run grep "https://discord.com/api/webhooks/123/abc" "$CONFIG_FILE"
  [ "$status" -eq 0 ]
}

@test "save_config rejects an unknown key" {
  run save_config "NOT_A_SETTING" "x"
  [ "$status" -ne 0 ]
}

@test "load_config reads saved values" {
  save_config "LOG_LEVEL" "verbose" 2>/dev/null || true
  VERBOSE=false
  load_config
  [ "$VERBOSE" = true ]
}

@test "load_config reads a final line without a trailing newline" {
  printf 'LOG_LEVEL=verbose' > "$CONFIG_FILE"
  VERBOSE=false
  load_config
  [ "$VERBOSE" = true ]
}

@test "save_config updates existing key" {
  save_config "LOG_FILE" "old" 2>/dev/null || true
  save_config "LOG_FILE" "new" 2>/dev/null || true
  run grep -c "LOG_FILE=new" "$CONFIG_FILE"
  [ "$output" -eq 1 ]
}
