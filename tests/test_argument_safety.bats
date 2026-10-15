#!/usr/bin/env bats

# Every missing-value case here used to abort with "$2: unbound variable"
# under `set -u`, which dropped the whole argument list and fell through to
# the interactive menu.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../unleash"
}

@test "--log-file without a path reports usage" {
  run bash -u "$SCRIPT" --log-file </dev/null
  [ "$status" -ne 0 ]
  [[ "$output" == *"--log-file requires a path"* ]]
  [[ "$output" != *"unbound variable"* ]]
}

@test "monitor --webhook without a URL reports usage" {
  run bash -u "$SCRIPT" monitor --webhook </dev/null
  [ "$status" -ne 0 ]
  [[ "$output" == *"--webhook requires a URL"* ]]
  [[ "$output" != *"unbound variable"* ]]
}

@test "config set without values reports usage" {
  run bash -u "$SCRIPT" config set </dev/null
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage: ./unleash config set KEY VALUE"* ]]
  [[ "$output" != *"unbound variable"* ]]
}

@test "no arguments does not fail on an empty argument array" {
  # "${arr[@]}" on an empty array is an unbound-variable error before bash
  # 4.4, and macOS ships bash 3.2.
  run bash -u "$SCRIPT" </dev/null
  [[ "$output" != *"unbound variable"* ]]
}

@test "arguments with spaces survive the option parser" {
  local tmp
  tmp=$(mktemp -d)
  run env HOME="$tmp" bash -u "$SCRIPT" config set LOG_FILE "/tmp/dir with space/log" </dev/null
  [[ "$output" != *"unbound variable"* ]]
  run cat "$tmp/.unleash.conf"
  [[ "$output" == *"/tmp/dir with space/log"* ]]
  rm -rf "$tmp"
}
