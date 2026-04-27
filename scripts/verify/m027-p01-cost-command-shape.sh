#!/usr/bin/env bash
# scripts/verify/m027-p01-cost-command-shape.sh — M027/P01 Truth #1 (FR-5).
#
# Asserts commands/cost.md exists and follows the canonical command-file
# structure (MEM012): frontmatter description, orchestrator:cost name,
# Accuracy section with verbatim D027 disclaimer, and the four expected
# script references (metrics-rollup.sh, cost-estimate.sh,
# intensity-recommend.sh, pricing.sh).
#
# Bash 3.2 compatible. MEM004 carve-out — pipes/$()/awk permitted.

set -u

NAME="m027-p01-cost-command-shape.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CMD="$PROJECT_ROOT/commands/cost.md"

# D027 verbatim disclaimer — checked with grep -qF to keep the literal
# string match exact (no regex escaping concerns).
DISCLAIMER='Estimates use M019 char-quartile token approximation and pricing.yml rates; actual cost typically lands within +/-20%. Runtime-actuals calibration is Tier 3 (deferred).'

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

# 1. File present and non-empty.
if [ ! -r "$CMD" ]; then
  fail "commands/cost.md missing"
fi
lines=$(awk 'END { print NR }' "$CMD")
if [ "$lines" -lt 80 ]; then
  fail "commands/cost.md too short ($lines lines, need >= 80)"
fi

# 2. Frontmatter description field present.
if ! grep -qE '^description:' "$CMD"; then
  fail "commands/cost.md missing frontmatter 'description:' field"
fi

# 3. Command name literal.
if ! grep -qF 'orchestrator:cost' "$CMD"; then
  fail "commands/cost.md missing 'orchestrator:cost' literal"
fi

# 4. ## Accuracy heading.
if ! grep -qE '^## Accuracy' "$CMD"; then
  fail "commands/cost.md missing '## Accuracy' heading"
fi

# 5. Verbatim D027 disclaimer (grep -qF for exact string).
if ! grep -qF "$DISCLAIMER" "$CMD"; then
  fail "commands/cost.md missing verbatim D027 disclaimer"
fi

# 6. Predictive surface flag documented.
if ! grep -qF -- '--estimate' "$CMD"; then
  fail "commands/cost.md missing '--estimate' predictive surface mention"
fi

# 7. All four expected script references present (the Referenced
#    Scripts contract per MEM012).
for ref in metrics-rollup.sh cost-estimate.sh intensity-recommend.sh pricing.sh; do
  if ! grep -qF "$ref" "$CMD"; then
    fail "commands/cost.md missing reference to $ref"
  fi
done

printf 'PASS: %s commands/cost.md shape + D027 disclaimer verified (%d lines)\n' "$NAME" "$lines"
exit 0
