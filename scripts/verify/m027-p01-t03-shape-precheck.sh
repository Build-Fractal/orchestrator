#!/usr/bin/env bash
# scripts/verify/m027-p01-t03-shape-precheck.sh — M027/P01/T03 task-scoped precheck.
#
# T03 ships commands/cost.md, packaging/bundle/skills/orchestrator-cost.md,
# and a manifest entry. The canonical phase-level verifier
# (m027-p01-cost-command-shape.sh) ships in T04. This precheck mirrors the
# six must-haves the T03 agent verified manually so that auto-loop --step=V
# has a runnable, single-script command pointing at T03's own deliverables
# (per the P00 parser-shape lesson: task-level Verification must reference
# only what the task itself produces).
#
# Bash 3.2 compatible.

set -u

NAME="m027-p01-t03-shape-precheck.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CMD="$PROJECT_ROOT/commands/cost.md"
SKILL="$PROJECT_ROOT/packaging/bundle/skills/orchestrator-cost.md"
MANIFEST="$PROJECT_ROOT/packaging/bundle/manifest.yml"

DISCLAIMER='Estimates use M019 char-quartile token approximation and pricing.yml rates; actual cost typically lands within +/-20%. Runtime-actuals calibration is Tier 3 (deferred).'

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

# 1. commands/cost.md exists and is non-trivial
if [ ! -r "$CMD" ]; then
  fail "commands/cost.md missing"
fi
lines=$(awk 'END { print NR }' "$CMD")
if [ "$lines" -lt 80 ]; then
  fail "commands/cost.md too short ($lines lines)"
fi

# 2. orchestrator:cost mentioned
if ! grep -qF 'orchestrator:cost' "$CMD"; then
  fail "commands/cost.md missing 'orchestrator:cost' literal"
fi

# 3. Verbatim D027 disclaimer present
if ! grep -qF "$DISCLAIMER" "$CMD"; then
  fail "commands/cost.md missing verbatim D027 disclaimer"
fi

# 4. ## Accuracy heading present
if ! grep -qE '^## Accuracy' "$CMD"; then
  fail "commands/cost.md missing '## Accuracy' heading"
fi

# 5. All four script paths referenced
for ref in metrics-rollup.sh cost-estimate.sh intensity-recommend.sh pricing.sh; do
  if ! grep -qF "$ref" "$CMD"; then
    fail "commands/cost.md missing reference to $ref"
  fi
done

# 6. Skill stub exists with required frontmatter
if [ ! -r "$SKILL" ]; then
  fail "orchestrator-cost.md skill stub missing"
fi
if ! grep -qF 'orchestrator:cost' "$SKILL"; then
  fail "skill stub missing 'orchestrator:cost' name"
fi
if ! grep -qF 'commands/cost.md' "$SKILL"; then
  fail "skill stub missing command_file pointer"
fi

# 7. Manifest registers the skill
if [ ! -r "$MANIFEST" ]; then
  fail "manifest.yml missing"
fi
if ! grep -qF 'orchestrator-cost.md' "$MANIFEST"; then
  fail "manifest.yml missing orchestrator-cost.md entry"
fi

printf 'PASS: %s commands/cost.md + skill stub + manifest entry verified\n' "$NAME"
exit 0
