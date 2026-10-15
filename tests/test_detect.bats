#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/detect.sh'
}

@test "is_root reflects EUID" {
  run is_root
  if [ "$EUID" -eq 0 ]; then
    [ "$status" -eq 0 ]
  else
    [ "$status" -ne 0 ]
  fi
}

@test "is_recovery returns false in normal environment" {
  run is_recovery
  # Only assert where the classic Recovery marker is absent.
  if [ ! -d "/System/Installation" ]; then
    [ "$status" -ne 0 ]
  fi
}

@test "detect_system_volume prints a name or nothing" {
  run detect_system_volume "/nonexistent-data-mount"
  [ "$status" -eq 0 ]
}

@test "resolve_data_volume fails without a tty and without diskutil" {
  # Non-interactive and stubbed: it must exit with an error, not hang, and it
  # must not leave anything on stdout for the caller to capture.
  command -v diskutil >/dev/null 2>&1 && skip "real diskutil present"
  run bash -c "
    set -euo pipefail
    source '$BATS_TEST_DIRNAME/../lib/colors.sh'
    source '$BATS_TEST_DIRNAME/../lib/detect.sh'
    resolve_data_volume
  " 2>/dev/null
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

@test "resolve_data_volume logs to stderr only" {
  # The caller does data_mount=$(resolve_data_volume); anything the helper
  # prints on stdout is captured as part of the value.
  command -v diskutil >/dev/null 2>&1 && skip "real diskutil present"
  run bash -c "
    source '$BATS_TEST_DIRNAME/../lib/colors.sh'
    source '$BATS_TEST_DIRNAME/../lib/detect.sh'
    resolve_data_volume 2>/dev/null || true
  "
  [ -z "$output" ]
}
