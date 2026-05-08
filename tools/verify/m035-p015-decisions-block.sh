#!/usr/bin/env bash
# tools/verify/m035-p015-decisions-block.sh
#
# M035/P01.5/T01 verifier — asserts the D-RN-1..D-RN-7 block landed in
# `.orchestrator/DECISIONS.md` with the canonical
# `### D-RN-N — <title> { #dr-code-NNN }` heading shape (per the
# M037/P01/T04 decisions-shape-lint contract).
#
# Single-script-file shape per AD-19. No compound chains (CON-3 / AP-009).

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DECISIONS="$REPO_ROOT/.orchestrator/DECISIONS.md"
fail=0

if [ ! -f "$DECISIONS" ]; then
  echo "FAIL: DECISIONS.md missing at $DECISIONS" >&2
  exit 1
fi

for n in 1 2 3 4 5 6 7; do
  if ! grep -qE "^### D-RN-${n} — " "$DECISIONS"; then
    echo "FAIL: D-RN-${n} heading missing from DECISIONS.md" >&2
    fail=1
  fi
done

anchor_count=$(grep -cE '^### D-RN-[1-7] — .*\{ #dr-code-[0-9]+ \}' "$DECISIONS" || true)
if [ "$anchor_count" != "7" ]; then
  echo "FAIL: expected 7 D-RN headings with #dr-code anchors, got $anchor_count" >&2
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "PASS: m035-p015-decisions-block"
  exit 0
fi
exit 1
