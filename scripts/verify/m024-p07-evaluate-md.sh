#!/usr/bin/env bash
# scripts/verify/m024-p07-evaluate-md.sh
# Asserts commands/evaluate.md's pre-M023 section names "wired in P07".

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EV="$ROOT/commands/evaluate.md"

[ -f "$EV" ] || { echo "FAIL: $EV not found"; exit 1; }

grep -qF 'wired in P07' "$EV" || { echo "FAIL: 'wired in P07' marker missing from evaluate.md"; exit 1; }
grep -qF 'design walkthrough lands in M023; author DESIGN.md manually or skip' "$EV" \
  || { echo "FAIL: FR-7 pinned message missing from evaluate.md"; exit 1; }
grep -qE '^\| `manual`' "$EV" || grep -qE '`manual`.*halts|halts.*`manual`' "$EV" \
  || { echo "FAIL: manual verb row missing from evaluate.md verb table"; exit 1; }
grep -qE '^\| `skip`' "$EV" || grep -qE '`skip`.*proceeds|proceeds.*`skip`' "$EV" \
  || { echo "FAIL: skip verb row missing from evaluate.md verb table"; exit 1; }
grep -qF 'scripts/intake/design-gate-degradation.sh' "$EV" \
  || { echo "FAIL: degradation script reference missing from evaluate.md"; exit 1; }

echo "PASS: evaluate-md — wired in P07 marker + FR-7 pinned message + manual/skip rows + script reference"
exit 0
