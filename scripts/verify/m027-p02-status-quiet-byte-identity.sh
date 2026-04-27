#!/usr/bin/env bash
# scripts/verify/m027-p02-status-quiet-byte-identity.sh -- M027/P02 Truth #3.
#
# Asserts CON-3/SC-17 byte-identity contract: the live commands/status.md
# tail starting at "## Next Action" diffs cleanly against the T02 fixture
# tests/fixtures/m027-p02/status-quiet-baseline.txt. This is the
# orchestrator:status --quiet load-bearing back-compat surface -- when the
# efficiency footer is suppressed, the post-Telemetry tail must match the
# pre-M027 baseline byte-for-byte.
#
# Bash 3.2 compatible. MEM004 carve-out -- awk used internally.

set -u

NAME="m027-p02-status-quiet-byte-identity.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

DOC="commands/status.md"
FIXTURE="tests/fixtures/m027-p02/status-quiet-baseline.txt"

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
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
  fail "$FIXTURE empty"
fi

TMP="${TMPDIR:-/tmp}/m027-p02-live-tail.$$.txt"
trap 'rm -f "$TMP"' EXIT

awk '/^## Next Action/,EOF' "$DOC" > "$TMP"

if ! diff -u "$TMP" "$FIXTURE" >/dev/null 2>&1; then
  printf 'DIFF: %s vs %s\n' "$TMP" "$FIXTURE" >&2
  diff -u "$TMP" "$FIXTURE" >&2 || true
  fail "live tail diverges from fixture"
fi

echo "PASS: $NAME"
exit 0
