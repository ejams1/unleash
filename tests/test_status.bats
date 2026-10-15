#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/status.sh'
  TEST_DIR=$(mktemp -d)
  mkdir -p "$TEST_DIR/private/etc"
  mkdir -p "$TEST_DIR/private/var/db/ConfigurationProfiles/Settings"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "check_mdm_status exits cleanly" {
  run check_mdm_status "$TEST_DIR" 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "deep_status exits cleanly" {
  run deep_status 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "deep_status_json contains braces" {
  run deep_status_json 2>/dev/null || true
  echo "$output" | grep -q "}"
}

@test "deep_status survives nounset with no profiles and no data mount" {
  # Regression: the overall-assessment block referenced a local from another
  # function ($cfg), which aborted the audit under `set -u`, and the profile
  # counter produced "0\n0" when grep found nothing.
  run bash -c "
    set -euo pipefail
    source '$BATS_TEST_DIRNAME/../lib/colors.sh'
    source '$BATS_TEST_DIRNAME/../lib/status.sh'
    pf_status() { :; }
    deep_status
  "
  [ "$status" -eq 0 ]
  [[ "$output" != *"unbound variable"* ]]
  [[ "$output" != *"integer expression expected"* ]]
}

@test "deep_status reports CRITICAL when a DEP record is present" {
  touch "$TEST_DIR/private/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound"
  run bash -c "
    set -euo pipefail
    source '$BATS_TEST_DIRNAME/../lib/colors.sh'
    source '$BATS_TEST_DIRNAME/../lib/status.sh'
    pf_status() { :; }
    deep_status '$TEST_DIR'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"CRITICAL"* ]]
}

@test "count_lines returns 0 for a file with no matches" {
  printf 'nothing here\n' > "$TEST_DIR/private/etc/hosts"
  run count_lines '^0\.0\.0\.0 ' "$TEST_DIR/private/etc/hosts"
  [ "$output" = "0" ]
}
