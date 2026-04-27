#!/usr/bin/env bash
# scripts/verify/m027-p03-doctor-md-shape.sh -- M027/P03 Truth #3.
#
# Asserts commands/doctor.md integration shape:
#   - file present, >= 60 lines
#   - "## Anomaly Detection" + "## Config Drift" sections present
#   - both helper script paths referenced
#   - 5 suppression-matrix tokens documented
#   - #Q-10 disclaimer text present (verbatim substrings)
#   - canonical pre-edit section order preserved (## What It Checks <
#     ## Runtime Instruction Drift < ## Anomaly Detection < ## Config Drift
#     < ## Usage < ## Output < ## When to Run < ## Referenced Scripts)
#
# Bash 3.2 compatible. MEM004 carve-out -- pipes / grep used internally.

set -u

NAME="m027-p03-doctor-md-shape.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

DOC="commands/doctor.md"

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

if [ ! -f "$DOC" ]; then
  fail "$DOC missing"
fi

lines="$(wc -l < "$DOC" | tr -d ' ')"
if [ "$lines" -lt 60 ]; then
  fail "$DOC too short ($lines lines, expected >= 60)"
fi

grep -q "## Anomaly Detection" "$DOC" \
  || fail "$DOC missing '## Anomaly Detection' section"
grep -q "## Config Drift" "$DOC" \
  || fail "$DOC missing '## Config Drift' section"
grep -q "scripts/diagnostics/check-anomalies.sh" "$DOC" \
  || fail "$DOC missing scripts/diagnostics/check-anomalies.sh path"
grep -q "scripts/diagnostics/check-config-drift.sh" "$DOC" \
  || fail "$DOC missing scripts/diagnostics/check-config-drift.sh path"

# 5 suppression-matrix tokens.
for tok in "--no-anomaly" "ORCHESTRATOR_AUTO" "anomaly_check_enabled" "--yes" "insufficient sample"; do
  if ! grep -q -- "$tok" "$DOC"; then
    fail "$DOC missing suppression-matrix token [$tok]"
  fi
done

# #Q-10 disclaimer verbatim substrings.
grep -q "fallback=duration" "$DOC" \
  || fail "$DOC missing '#Q-10' disclaimer substring 'fallback=duration'"
grep -q "Corruption-recovery" "$DOC" \
  || fail "$DOC missing '#Q-10' disclaimer substring 'Corruption-recovery'"

# Canonical section order check. Extract first match line number for each
# header; assert strict-increasing sequence.
SECTIONS="
## What It Checks
## Runtime Instruction Drift
## Anomaly Detection
## Config Drift
## Usage
## Output
## When to Run
## Referenced Scripts
"

prev_n=0
prev_label=""
printf '%s\n' "$SECTIONS" | while IFS= read -r section; do
  if [ -z "$section" ]; then continue; fi
  n="$(grep -n -F "$section" "$DOC" | head -1 | cut -d: -f1)"
  if [ -z "$n" ]; then
    echo "MISSING: $section" >&2
    exit 7
  fi
  if [ "$n" -le "$prev_n" ]; then
    echo "ORDER: '$section' line=$n not after '$prev_label' line=$prev_n" >&2
    exit 8
  fi
  prev_n="$n"
  prev_label="$section"
done
order_rc=$?
if [ "$order_rc" -ne 0 ]; then
  fail "canonical section order violated (rc=$order_rc)"
fi

echo "PASS: $NAME"
exit 0
