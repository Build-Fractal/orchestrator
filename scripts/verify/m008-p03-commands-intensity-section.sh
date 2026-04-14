#!/usr/bin/env bash
# Verifies each pipeline command doc contains the Intensity Behavior
# section and references scripts/engine/intensity-gate.sh.
set -u

cmds="commands/discuss.md commands/plan-phase.md commands/dispatch.md commands/verify.md commands/auto.md"

for c in $cmds; do
  test -f "$c" || { echo "FAIL: $c missing"; exit 1; }
  grep -q '^## Intensity Behavior' "$c" || { echo "FAIL: $c missing '## Intensity Behavior' section"; exit 1; }
  grep -q 'scripts/engine/intensity-gate.sh' "$c" || { echo "FAIL: $c missing reference to intensity-gate.sh"; exit 1; }
  grep -q 'execute_substeps' "$c" || { echo "FAIL: $c does not document execute_substeps semantics"; exit 1; }
done

# Per-stage name check: each doc should reference --stage <its-own-name>
grep -q -- '--stage discuss'    commands/discuss.md    || { echo "FAIL: discuss.md missing --stage discuss"; exit 1; }
grep -q -- '--stage plan-phase' commands/plan-phase.md || { echo "FAIL: plan-phase.md missing --stage plan-phase"; exit 1; }
grep -q -- '--stage dispatch'   commands/dispatch.md   || { echo "FAIL: dispatch.md missing --stage dispatch"; exit 1; }
grep -q -- '--stage verify'     commands/verify.md     || { echo "FAIL: verify.md missing --stage verify"; exit 1; }
grep -q -- '--stage auto'       commands/auto.md       || { echo "FAIL: auto.md missing --stage auto"; exit 1; }

echo "PASS: all 5 pipeline commands contain Intensity Behavior sections referencing intensity-gate.sh"
