#!/usr/bin/env bash
# scripts/verify/m027-p02-status-md-shape.sh -- M027/P02 Truth #2.
#
# Asserts commands/status.md integration shape:
#   - file present, >= 170 lines
#   - "## Efficiency Footer" section present
#   - efficiency-footer reference present
#   - scripts/diagnostics/efficiency-footer.sh path referenced
#   - --quiet suppression flag documented
#   - efficiency_footer config knob documented
#   - canonical pre-edit section order preserved (see plan)
#
# Bash 3.2 compatible. MEM004 carve-out.

set -u

NAME="m027-p02-status-md-shape.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

DOC="commands/status.md"

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

if [ ! -f "$DOC" ]; then
  fail "$DOC missing"
fi

lines="$(wc -l < "$DOC" | tr -d ' ')"
if [ "$lines" -lt 170 ]; then
  fail "$DOC too short ($lines lines, expected >= 170)"
fi

if ! grep -q "## Efficiency Footer" "$DOC"; then
  fail "$DOC missing '## Efficiency Footer' section"
fi

if ! grep -q "efficiency-footer" "$DOC"; then
  fail "$DOC missing efficiency-footer reference"
fi

if ! grep -q "scripts/diagnostics/efficiency-footer.sh" "$DOC"; then
  fail "$DOC missing scripts/diagnostics/efficiency-footer.sh path"
fi

if ! grep -q -- "--quiet" "$DOC"; then
  fail "$DOC missing --quiet flag documentation"
fi

if ! grep -q "efficiency_footer" "$DOC"; then
  fail "$DOC missing efficiency_footer config knob documentation"
fi

# Canonical section order check. Extract first match line number for each
# header; assert strict-increasing sequence.
SECTIONS="
## State Derivation
## Progress Overview
## Blockers
## Execution History
## Telemetry Metrics
## Efficiency Footer
## Next Action
## Concurrent Safety
## Idempotency
## Error Handling
## Gotchas
## Reference Files
"

prev_n=0
prev_label=""
# Iterate one section header per loop. Use a simple read loop so we can
# tolerate spaces in section names ("## Next Action").
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
