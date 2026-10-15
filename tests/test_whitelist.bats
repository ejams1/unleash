#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/whitelist.sh'
  TEST_DIR=$(mktemp -d)
  mkdir -p "$TEST_DIR/etc/pf.anchors"
  # Stub the resolver: the test must not depend on DNS or on `host` being
  # installed (it is not available in CI).
  STUB_BIN="$TEST_DIR/bin"
  mkdir -p "$STUB_BIN"
  cat > "$STUB_BIN/host" <<'STUB'
#!/bin/bash
echo "$2 has address 10.0.0.1"
STUB
  chmod +x "$STUB_BIN/host"
  PATH="$STUB_BIN:$PATH"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "install_selective_block creates anchor" {
  run install_selective_block "$TEST_DIR" 2>/dev/null || true
  [ -f "$TEST_DIR/etc/pf.anchors/com.unleash.selective" ]
}

@test "install_selective_block creates pf.conf" {
  run install_selective_block "$TEST_DIR" 2>/dev/null || true
  [ -f "$TEST_DIR/etc/pf.conf" ]
}

@test "install_selective_block writes the boot-time anchor path" {
  run install_selective_block "$TEST_DIR" 2>/dev/null || true
  run grep -c 'load anchor "com.unleash.selective" from "/etc/pf.anchors/com.unleash.selective"' \
    "$TEST_DIR/etc/pf.conf"
  [ "$output" -eq 1 ]
}

@test "install_selective_block refuses to install an empty anchor" {
  # Without a resolver the anchor would be empty; that used to be reported as
  # a success while nothing was actually blocked.
  run bash -c "
    PATH='/usr/bin:/bin'
    source '$BATS_TEST_DIRNAME/../lib/colors.sh'
    source '$BATS_TEST_DIRNAME/../lib/whitelist.sh'
    install_selective_block '$TEST_DIR'
  "
  [ "$status" -ne 0 ]
  [ ! -f "$TEST_DIR/etc/pf.anchors/com.unleash.selective" ]
}
