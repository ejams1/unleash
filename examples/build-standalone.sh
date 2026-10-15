#!/bin/bash
# Builds unleash-standalone.sh: the same tool with every library inlined.
# This is the artifact the Homebrew tap and the curl-based Recovery install
# use, so it must be regenerated (and committed) whenever a lib changes.
set -euo pipefail

# Repo root, located without dirname/basename (not guaranteed in a minimal
# shell environment). cd/pwd are shell builtins.
_src="${BASH_SOURCE[0]:-$0}"
_dir="${_src%/*}"
if [ "$_dir" = "$_src" ]; then
  _dir="."
fi
ROOT="$(cd "$_dir/.." && pwd)"
OUT="${1:-$ROOT/unleash-standalone.sh}"

VERSION="$(grep '^VERSION=' "$ROOT/unleash" | head -1 | cut -d'"' -f2)"
[ -n "$VERSION" ] || { echo "ERROR: cannot read VERSION from $ROOT/unleash" >&2; exit 1; }

# Read the module list out of `unleash` instead of keeping a second copy here:
# the hardcoded list in this file is how the standalone shipped without
# init, suggest, remediate, predict, telemetry and discord (4 commands died
# with "command not found").
LIBS="$(sed -n 's/^UNLEASH_LIBS="\(.*\)"$/\1/p' "$ROOT/unleash" | head -1)"
[ -n "$LIBS" ] || { echo "ERROR: UNLEASH_LIBS not found in $ROOT/unleash" >&2; exit 1; }

lib_count=0
for lib in $LIBS; do
  lib_count=$((lib_count + 1))
  [ -f "$ROOT/lib/$lib.sh" ] || { echo "ERROR: lib/$lib.sh missing" >&2; exit 1; }
done

cat > "$OUT" << HEADER
#!/bin/bash
set -euo pipefail
VERSION="$VERSION"
UNLEASH_LIBS="$LIBS"

# Locate this script without dirname (a minimal Recovery environment is not
# guaranteed to ship it). cd/pwd are shell builtins. SCRIPT_DIR/SCRIPT_PATH
# are referenced by the LaunchDaemon installers; LIB_DIR is only used for
# display here, the modules below are inlined.
_unleash_src="\${BASH_SOURCE[0]:-\$0}"
_unleash_dir="\${_unleash_src%/*}"
if [ "\$_unleash_dir" = "\$_unleash_src" ]; then
	_unleash_dir="."
fi
SCRIPT_DIR="\$(cd "\$_unleash_dir" && pwd)"
SCRIPT_PATH="\$SCRIPT_DIR/\${_unleash_src##*/}"
LIB_DIR="\$SCRIPT_DIR/lib"
unset _unleash_src _unleash_dir
HEADER

for lib in $LIBS; do
  tail -n +1 "$ROOT/lib/$lib.sh" >> "$OUT"
  echo "" >> "$OUT"
done

# Take everything from the main script except the shebang, the option block
# and the module-sourcing loop (the modules are inlined above).
sed -e '1,/_lib in /d' -e '/^done$/,$!d' -e '/^done$/d' "$ROOT/unleash" >> "$OUT"

chmod +x "$OUT"
echo "Created: $OUT (v$VERSION, $lib_count modules, $(wc -c < "$OUT") bytes, $(wc -l < "$OUT") lines)"
