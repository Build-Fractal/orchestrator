#!/usr/bin/env bash
# scripts/verify/m027-p02-t02-shape-precheck.sh
# M027/P02/T02-scoped precheck verifier for the commands/status.md
# integration + status-quiet baseline fixture.
#
# Asserts the nine T02 must-haves in a single script per AD-19 (single-script
# Check shape). The phase-level canonical verifiers
# m027-p02-status-md-shape.sh + m027-p02-status-quiet-byte-identity.sh ship
# in T04 and subsume this precheck; T04 may delete this file once the
# canonical verifiers land (mirrors the M027/P01/T03 + T04 pattern).
#
# Bash 3.2 compatible. MEM004 carve-out -- pipes/$()/grep permitted in the
# verifier body since AD-19 binds Check: invocations, not script internals.

set -u

NAME="m027-p02-t02-shape-precheck.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATUS_MD="$PROJECT_ROOT/commands/status.md"
FIXTURE="$PROJECT_ROOT/tests/fixtures/m027-p02/status-quiet-baseline.txt"
FIXTURE_README="$PROJECT_ROOT/tests/fixtures/m027-p02/README.md"

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

# 1. commands/status.md exists, >= 170 lines.
if [ ! -r "$STATUS_MD" ]; then
  fail "commands/status.md missing"
fi
lines=$(awk 'END { print NR }' "$STATUS_MD")
if [ "$lines" -lt 170 ]; then
  fail "commands/status.md too short ($lines lines, need >= 170)"
fi

# 2. Contains the literal string 'efficiency-footer' (helper reference).
if ! grep -qF 'efficiency-footer' "$STATUS_MD"; then
  fail "commands/status.md missing 'efficiency-footer' literal reference"
fi

# 3. Contains a '## Efficiency Footer' heading.
if ! grep -qE '^## Efficiency Footer[[:space:]]*$' "$STATUS_MD"; then
  fail "commands/status.md missing '## Efficiency Footer' heading"
fi

# 4. Contains a reference to the --quiet suppression flag.
if ! grep -qF -- '--quiet' "$STATUS_MD"; then
  fail "commands/status.md missing '--quiet' suppression flag reference"
fi

# 5. Contains a reference to the efficiency_footer config knob.
if ! grep -qF 'efficiency_footer' "$STATUS_MD"; then
  fail "commands/status.md missing 'efficiency_footer' config knob reference"
fi

# 6. References scripts/diagnostics/efficiency-footer.sh in ## Reference Files.
ref_section_line=$(grep -nE '^## Reference Files[[:space:]]*$' "$STATUS_MD" | head -n 1 | cut -d: -f1)
if [ -z "$ref_section_line" ]; then
  fail "commands/status.md missing '## Reference Files' section"
fi
ref_tail=$(awk -v start="$ref_section_line" 'NR >= start' "$STATUS_MD")
if ! printf '%s\n' "$ref_tail" | grep -qF 'scripts/diagnostics/efficiency-footer.sh'; then
  fail "commands/status.md missing scripts/diagnostics/efficiency-footer.sh in ## Reference Files"
fi

# 7. Pre-edit canonical sections preserved in pre-edit order, with the new
#    '## Efficiency Footer' inserted between '## Telemetry Metrics' and
#    '## Next Action'. Verified by line-number ordering of grep -n hits.
sections="State Derivation|Progress Overview|Blockers|Execution History|Telemetry Metrics|Efficiency Footer|Next Action|Concurrent Safety|Idempotency|Error Handling|Gotchas|Reference Files"
prev_line=0
prev_name=""
IFS='|'
for section in $sections; do
  unset IFS
  hit_line=$(grep -nE "^## ${section}[[:space:]]*$" "$STATUS_MD" | head -n 1 | cut -d: -f1)
  if [ -z "$hit_line" ]; then
    fail "commands/status.md missing '## ${section}' section heading"
  fi
  if [ "$hit_line" -le "$prev_line" ]; then
    fail "commands/status.md section order broken: '## ${section}' (line $hit_line) appears at or before previous '## ${prev_name}' (line $prev_line)"
  fi
  prev_line="$hit_line"
  prev_name="$section"
  IFS='|'
done
unset IFS

# 8. Fixture file exists, >= 1 line, contains 'Next Action'.
if [ ! -r "$FIXTURE" ]; then
  fail "tests/fixtures/m027-p02/status-quiet-baseline.txt missing"
fi
fixture_lines=$(awk 'END { print NR }' "$FIXTURE")
if [ "$fixture_lines" -lt 1 ]; then
  fail "status-quiet-baseline.txt empty (need >= 1 line)"
fi
if ! grep -qF 'Next Action' "$FIXTURE"; then
  fail "status-quiet-baseline.txt missing 'Next Action' literal"
fi

# 9. Fixture README exists.
if [ ! -r "$FIXTURE_README" ]; then
  fail "tests/fixtures/m027-p02/README.md missing"
fi

printf 'PASS: %s all 9 assertions hold\n' "$NAME"
exit 0
