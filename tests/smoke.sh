#!/bin/bash
# tests/smoke.sh — portable end-to-end checks for unleash.
#
# Runs on Linux or macOS without bats and without any macOS-only tool, so CI
# can catch the regressions that `bash -n` and shellcheck cannot see: a
# documented command with no dispatch branch, a stale standalone artifact, a
# diagnostic leaking into a captured value, an argument parser that dies on a
# missing option value.
#
# Usage: bash tests/smoke.sh

set -uo pipefail

_src="${BASH_SOURCE[0]:-$0}"
_dir="${_src%/*}"
if [ "$_dir" = "$_src" ]; then
  _dir="."
fi
ROOT="$(cd "$_dir/.." && pwd)"
UNLEASH="$ROOT/unleash"
STANDALONE="$ROOT/unleash-standalone.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fails=0
pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }

check() { # description, command...
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    pass "$desc"
  else
    fail "$desc"
  fi
}

check_output() { # description, expected substring, command...
  local desc="$1" want="$2" out
  shift 2
  out=$("$@" 2>&1) || true
  case "$out" in
    *"$want"*) pass "$desc" ;;
    *) fail "$desc (expected \"$want\")"; printf '%s\n' "$out" | head -5 ;;
  esac
}

echo "== syntax =="
for f in "$UNLEASH" "$ROOT"/lib/*.sh "$ROOT"/examples/*.sh "$STANDALONE"; do
  [ -f "$f" ] || continue
  check "syntax: ${f#$ROOT/}" bash -n "$f"
done
check "syntax: tests/smoke.sh" bash -n "$0"

echo "== portability (minimal bash 3.2 / Recovery) =="
# dirname and friends are not guaranteed to exist in a Recovery environment.
if grep -vE '^[[:space:]]*#' "$UNLEASH" "$ROOT"/lib/*.sh "$ROOT"/examples/*.sh 2>/dev/null |
    grep -nE '(^|[^[:alnum:]_])(dirname|basename|readlink|realpath)([^[:alnum:]_]|$)' \
      > "$TMP_DIR/tools.txt" 2>/dev/null; then
  fail "no dirname/basename/readlink/realpath in the scripts"
  cat "$TMP_DIR/tools.txt"
else
  pass "no dirname/basename/readlink/realpath in the scripts"
fi

# Bash 4+ syntax does not run on the /bin/bash shipped with macOS.
if grep -nE 'declare -A|local -A|typeset -A|mapfile|readarray|&>>|local -n|wait -n|\$\{[A-Za-z_]+(,,|\^\^\}' \
    "$UNLEASH" "$ROOT"/lib/*.sh > "$TMP_DIR/bash4.txt" 2>/dev/null; then
  fail "no bash 4+ syntax in the scripts"
  cat "$TMP_DIR/bash4.txt"
else
  pass "no bash 4+ syntax in the scripts"
fi

# "${empty_array[@]}" is an error under `set -u` before bash 4.4, so it must
# be written with the ${arr[@]+"${arr[@]}"} guard.
if grep -nE 'set -- "\$\{[A-Za-z_]+\[@\]\}"' "$UNLEASH" > "$TMP_DIR/emptyarr.txt" 2>/dev/null; then
  fail "no unguarded \"\${array[@]}\" expansion under set -u"
  cat "$TMP_DIR/emptyarr.txt"
else
  pass "no unguarded \"\${array[@]}\" expansion under set -u"
fi

echo "== standalone artifact =="
if bash "$ROOT/examples/build-standalone.sh" "$TMP_DIR/standalone.sh" >/dev/null 2>&1 &&
   cmp -s "$TMP_DIR/standalone.sh" "$STANDALONE"; then
  pass "unleash-standalone.sh matches a fresh build"
else
  fail "unleash-standalone.sh is stale — run: make build"
fi

echo "== command surface =="
check_output "version prints" "unleash v" "$UNLEASH" version
check_output "standalone version prints" "unleash v" "$STANDALONE" version

# `doctor` was documented everywhere but had no dispatch branch.
check_output "doctor is dispatched" "Pre-Flight" "$UNLEASH" doctor
check_output "doctor works in the standalone" "Pre-Flight" "$STANDALONE" doctor

# The standalone shipped without init/suggest/predict/telemetry. `remediate`
# is deliberately absent: it mutates the host when run for real.
for cmd in init suggest predict telemetry config; do
  check_output "standalone has: $cmd" "" bash -c "'$STANDALONE' $cmd </dev/null"
done
if bash -c "'$STANDALONE' init </dev/null" 2>&1 | grep -q "command not found"; then
  fail "no 'command not found' for standalone commands"
else
  pass "no 'command not found' for standalone commands"
fi

echo "== captured values stay clean =="
# Helpers log to stderr; anything on stdout is captured by the caller. A log
# line on stdout used to corrupt data_mount.
out=$(bash -c "
  set -euo pipefail
  source '$ROOT/lib/colors.sh'
  source '$ROOT/lib/suppress.sh'
  f() { step 'working'; printf '%s' '/fake/mount'; }
  capture=\$(f)
  printf '%s' \"\$capture\"
" 2>/dev/null) || true
if [ "$out" = "/fake/mount" ]; then
  pass "helper stdout is not polluted by diagnostics"
else
  fail "helper stdout is polluted: [$out]"
fi

echo "== argument parsing =="
check "config with no arguments exits cleanly" bash -c "'$UNLEASH' config </dev/null"
for argv in "--log-file" "heal --log-file" "monitor --webhook"; do
  out=$(bash -c "'$UNLEASH' $argv </dev/null" 2>&1) || true
  case "$out" in
    *"unbound variable"*) fail "no unbound variable for: unleash $argv" ;;
    *"Auto-heal"*) fail "unleash $argv fell through to the menu" ;;
    *) pass "unleash $argv fails cleanly" ;;
  esac
done

echo "== dry run =="
check_output "test firewall simulates" "[DRY RUN]" "$UNLEASH" test firewall
check_output "test harden simulates" "[DRY RUN]" "$UNLEASH" test harden
check_output "test persist simulates" "[DRY RUN]" "$UNLEASH" test persist

echo "== json output =="
if command -v python3 >/dev/null 2>&1; then
  for cmd in report; do
    if "$UNLEASH" "$cmd" --json 2>/dev/null | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
      pass "unleash $cmd --json is valid JSON"
    else
      fail "unleash $cmd --json is not valid JSON"
    fi
  done
else
  printf 'skip python3 not available, JSON not validated\n'
fi

echo ""
if [ "$fails" -eq 0 ]; then
  echo "smoke: all checks passed"
  exit 0
fi
echo "smoke: $fails check(s) failed"
exit 1
