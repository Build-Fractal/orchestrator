#!/usr/bin/env bash
# scripts/verify/m027-p03-doctor-byte-identity.sh -- M027/P03 Truth #4.
#
# Asserts the post-`## Referenced Scripts` tail of commands/doctor.md is
# byte-identical to the captured T02 baseline fixture
# tests/fixtures/m027-p03/doctor-suppressed-baseline.txt.
#
# Mirrors the P02/T02 + T04 document-shaped phase-task byte-identity
# pattern: the new sections should be the only structural additions plus
# one bullet under ## Referenced Scripts; the post-attach-point tail must
# remain stable.
#
# Bash 3.2 compatible. MEM004 carve-out -- awk / diff used internally.

set -u

NAME="m027-p03-doctor-byte-identity.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

DOC="commands/doctor.md"
FIXTURE="tests/fixtures/m027-p03/doctor-suppressed-baseline.txt"

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  [ -n "${live_tail:-}" ] && [ -f "$live_tail" ] && rm -f "$live_tail"
  exit 1
}

if [ ! -f "$DOC" ]; then
  fail "$DOC missing"
fi
if [ ! -f "$FIXTURE" ]; then
  fail "$FIXTURE missing"
fi
fixture_lines="$(wc -l < "$FIXTURE" | tr -d ' ')"
if [ "$fixture_lines" -lt 1 ]; then
  fail "$FIXTURE too short ($fixture_lines lines, expected >= 1)"
fi

# Extract the post-## Referenced Scripts tail.
live_tail="$(mktemp -t m027-p03-live-tail.XXXXXXXX)"
awk '/^## Referenced Scripts/,EOF' "$DOC" > "$live_tail"

if ! diff "$live_tail" "$FIXTURE" >/dev/null 2>&1; then
  printf 'DIFF:\n' >&2
  diff "$live_tail" "$FIXTURE" >&2 || true
  fail "post-## Referenced Scripts tail diverged from fixture"
fi

rm -f "$live_tail"
echo "PASS: $NAME"
exit 0
