#!/usr/bin/env bash
# scripts/verify/m027-p02-t03-shape-precheck.sh
# M027/P02/T03-scoped precheck verifier for the dispatch-time predictive
# surface helper + commands/dispatch.md integration.
#
# Asserts T03's must-haves in a single script per AD-19 (single-script
# Check shape). The phase-level canonical verifiers
# m027-p02-predictive-surface-shape.sh, m027-p02-suppression-matrix.sh,
# and m027-p02-dispatch-md-shape.sh ship in T04 and subsume slices of
# this precheck; T04 may delete this file once the canonical verifiers
# land (mirrors the M027/P01/T03 + T04 pattern).
#
# Bash 3.2 compatible. MEM004 carve-out -- pipes/$()/grep permitted in
# the verifier body since AD-19 binds Check: invocations, not script
# internals.

set -u

NAME="m027-p02-t03-shape-precheck.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HELPER="$PROJECT_ROOT/scripts/dispatch/predictive-surface.sh"
DISPATCH_MD="$PROJECT_ROOT/commands/dispatch.md"

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

# 1. Helper exists, >= 80 lines, executable.
if [ ! -r "$HELPER" ]; then
  fail "scripts/dispatch/predictive-surface.sh missing"
fi
if [ ! -x "$HELPER" ]; then
  fail "scripts/dispatch/predictive-surface.sh not executable"
fi
helper_lines=$(awk 'END { print NR }' "$HELPER")
if [ "$helper_lines" -lt 80 ]; then
  fail "predictive-surface.sh too short ($helper_lines lines, need >= 80)"
fi

# 2. Contains the literal string 'predictive_cost_surface'.
if ! grep -qF 'predictive_cost_surface' "$HELPER"; then
  fail "predictive-surface.sh missing 'predictive_cost_surface' literal"
fi

# 3. Contains a function definition predictive_surface_render.
if ! grep -qE '^predictive_surface_render\(\)' "$HELPER"; then
  fail "predictive-surface.sh missing 'predictive_surface_render()' function definition"
fi

# 4. Contains a CLI entry-point guard (BASH_SOURCE / $0 comparison).
if ! grep -qE 'BASH_SOURCE.*=.*\$0|BASH_SOURCE\[0\]' "$HELPER"; then
  fail "predictive-surface.sh missing BASH_SOURCE/\$0 entry-point guard"
fi

# 5. Honors --no-predict flag.
if ! grep -qF -- '--no-predict' "$HELPER"; then
  fail "predictive-surface.sh missing --no-predict flag handling"
fi

# 6. Honors --yes flag.
if ! grep -qF -- '--yes' "$HELPER"; then
  fail "predictive-surface.sh missing --yes flag handling"
fi

# 7. Honors ORCHESTRATOR_AUTO env var.
if ! grep -qF 'ORCHESTRATOR_AUTO' "$HELPER"; then
  fail "predictive-surface.sh missing ORCHESTRATOR_AUTO env var handling"
fi

# 8. Honors predictive_cost_surface config knob (env or read-config).
if ! grep -qE 'ORCH_PREDICTIVE_COST_SURFACE|read-config\.sh predictive_cost_surface' "$HELPER"; then
  fail "predictive-surface.sh missing predictive_cost_surface config-knob resolution"
fi

# 9. Invokes scripts/engine/intensity-recommend.sh (delegation to P01 hook).
if ! grep -qF 'scripts/engine/intensity-recommend.sh' "$HELPER"; then
  fail "predictive-surface.sh missing scripts/engine/intensity-recommend.sh invocation"
fi

# 10. Pre-sets INTENSITY_RECOMMEND_FAST_PATH=1 and _CE_RECOMMENDED.
if ! grep -qF 'INTENSITY_RECOMMEND_FAST_PATH=1' "$HELPER"; then
  fail "predictive-surface.sh missing INTENSITY_RECOMMEND_FAST_PATH=1 pre-set"
fi
if ! grep -qF '_CE_RECOMMENDED' "$HELPER"; then
  fail "predictive-surface.sh missing _CE_RECOMMENDED pre-set"
fi

# 11. Contains the override prompt literal.
if ! grep -qF 'override: press 1=quick 2=standard 3=full' "$HELPER"; then
  fail "predictive-surface.sh missing one-line override prompt literal"
fi

# 12. commands/dispatch.md has '## Predictive Surface' heading.
if [ ! -r "$DISPATCH_MD" ]; then
  fail "commands/dispatch.md missing"
fi
if ! grep -qE '^## Predictive Surface' "$DISPATCH_MD"; then
  fail "commands/dispatch.md missing '## Predictive Surface' heading"
fi

# 13. References scripts/dispatch/predictive-surface.sh in '## Referenced Scripts'.
ref_section_line=$(grep -nE '^## Referenced Scripts[[:space:]]*$' "$DISPATCH_MD" | head -n 1 | cut -d: -f1)
if [ -z "$ref_section_line" ]; then
  fail "commands/dispatch.md missing '## Referenced Scripts' section"
fi
ref_tail=$(awk -v start="$ref_section_line" 'NR >= start' "$DISPATCH_MD")
if ! printf '%s\n' "$ref_tail" | grep -qF 'scripts/dispatch/predictive-surface.sh'; then
  fail "commands/dispatch.md missing scripts/dispatch/predictive-surface.sh in '## Referenced Scripts'"
fi

# 14. 5-condition suppression matrix documented in dispatch.md.
for needle in '--yes' 'ORCHESTRATOR_AUTO' '--no-predict' 'predictive_cost_surface' 'quick'; do
  if ! grep -qF -e "$needle" "$DISPATCH_MD"; then
    fail "commands/dispatch.md missing suppression-matrix condition '$needle'"
  fi
done

# 15. Pre-edit canonical sections preserved in pre-edit order, with the new
#     '## Predictive Surface (M027/P02)' inserted between '## Dispatch Strategy'
#     and '## Execution Recording'.
sections="Intensity Behavior|Prerequisites|Context Construction|Dispatch Strategy|Predictive Surface|Execution Recording|Post-Dispatch|Idempotency|Error Handling|Claude Code Appendix|Gotchas|Referenced Scripts|Referenced Templates"
prev_line=0
prev_name=""
IFS='|'
for section in $sections; do
  unset IFS
  hit_line=$(grep -nE "^## ${section}" "$DISPATCH_MD" | head -n 1 | cut -d: -f1)
  if [ -z "$hit_line" ]; then
    fail "commands/dispatch.md missing '## ${section}' section heading"
  fi
  if [ "$hit_line" -le "$prev_line" ]; then
    fail "commands/dispatch.md section order broken: '## ${section}' (line $hit_line) appears at or before previous '## ${prev_name}' (line $prev_line)"
  fi
  prev_line="$hit_line"
  prev_name="$section"
  IFS='|'
done
unset IFS

# 16. Behavioral check 1: --yes suppresses output (zero stdout, exit 0).
out_yes=$(bash "$HELPER" --description "test" --intensity standard --yes 2>/dev/null)
rc_yes=$?
if [ "$rc_yes" -ne 0 ]; then
  fail "predictive-surface.sh --yes exit non-zero ($rc_yes)"
fi
if [ -n "$out_yes" ]; then
  fail "predictive-surface.sh --yes produced non-empty stdout"
fi

# 17. Behavioral check 2: intensity=quick suppresses output (zero stdout, exit 0).
out_quick=$(bash "$HELPER" --description "test" --intensity quick 2>/dev/null)
rc_quick=$?
if [ "$rc_quick" -ne 0 ]; then
  fail "predictive-surface.sh --intensity quick exit non-zero ($rc_quick)"
fi
if [ -n "$out_quick" ]; then
  fail "predictive-surface.sh --intensity quick produced non-empty stdout"
fi

printf 'PASS: %s all 17 assertions hold\n' "$NAME"
exit 0
