#!/usr/bin/env bash
# scripts/verify/m027-p02-dispatch-md-shape.sh -- M027/P02 Truth #6.
#
# Asserts commands/dispatch.md integration shape:
#   - file present, >= 160 lines
#   - "## Predictive Surface" section present
#   - predictive-surface reference present
#   - scripts/dispatch/predictive-surface.sh path referenced
#   - all 5 suppression-matrix tokens documented
#   - canonical pre-edit section order preserved
#   - --yes invocation produces empty stdout / exit 0 (live contract)
#
# Bash 3.2 compatible. MEM004 carve-out.

set -u

NAME="m027-p02-dispatch-md-shape.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

DOC="commands/dispatch.md"

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

if [ ! -f "$DOC" ]; then
  fail "$DOC missing"
fi

lines="$(wc -l < "$DOC" | tr -d ' ')"
if [ "$lines" -lt 160 ]; then
  fail "$DOC too short ($lines lines, expected >= 160)"
fi

if ! grep -q "## Predictive Surface" "$DOC"; then
  fail "$DOC missing '## Predictive Surface' section"
fi

if ! grep -q "predictive-surface" "$DOC"; then
  fail "$DOC missing predictive-surface reference"
fi

if ! grep -q "scripts/dispatch/predictive-surface.sh" "$DOC"; then
  fail "$DOC missing scripts/dispatch/predictive-surface.sh path"
fi

# Five suppression-matrix tokens
if ! grep -q -- "--yes" "$DOC"; then
  fail "$DOC missing --yes documentation"
fi
if ! grep -q "ORCHESTRATOR_AUTO" "$DOC"; then
  fail "$DOC missing ORCHESTRATOR_AUTO documentation"
fi
if ! grep -q -- "--no-predict" "$DOC"; then
  fail "$DOC missing --no-predict documentation"
fi
if ! grep -q "predictive_cost_surface" "$DOC"; then
  fail "$DOC missing predictive_cost_surface documentation"
fi
if ! grep -qE "intensity.*quick|quick.*intensity" "$DOC"; then
  fail "$DOC missing quick-intensity suppression documentation"
fi

# Canonical section order check.
SECTIONS="
## Intensity Behavior
## Prerequisites
## Context Construction
## Dispatch Strategy
## Predictive Surface
## Execution Recording
## Post-Dispatch
## Idempotency
## Error Handling
## Claude Code Appendix
## Gotchas
## Referenced Scripts
## Referenced Templates
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

# Live --yes suppressed-mode contract
out="$(bash scripts/dispatch/predictive-surface.sh --description "test" --intensity standard --yes 2>/dev/null)"
rc=$?
if [ "$rc" -ne 0 ]; then
  fail "--yes invocation exited non-zero ($rc)"
fi
if [ -n "$out" ]; then
  fail "--yes invocation produced non-empty stdout"
fi

echo "PASS: $NAME"
exit 0
