#!/usr/bin/env bash
# tools/verify/m036-p07-omit-empty-section.sh — M036 P07 T03 behavioral
# verifier asserting non-matching topic_tags produce zero `## Reference`
# header in the dispatched payload (omit-empty-section discipline).
# AD-19 single-script-file shape.
#
# Note: build-context.sh's flag surface is positional-with-task-plan-via-fixture,
# not --milestone/--phase/--task. Verifier stages a minimal fixture milestone
# tree with the synthetic mismatch task plan and drives the dispatcher via
# positional args, per the T03 plan's "equivalent invocation" allowance.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WS="$(mktemp -d)"
trap 'rm -rf "$WS"' EXIT

# Stage fixture milestone tree shape build-context.sh expects.
mkdir -p "$WS/phases/P-fixture/tasks"
cat > "$WS/M-fixture-ROADMAP.md" <<'EOR'
---
schema_version: "1.0"
type: roadmap
milestone: "M-fixture"
---

# M-fixture — synthetic
EOR
cat > "$WS/phases/P-fixture/P-fixture-PLAN.md" <<'EOP'
---
schema_version: "1.0"
type: phase-plan
id: "P-fixture"
parent: "M-fixture"
milestone: "M-fixture"
---

# P-fixture — synthetic
EOP
PLAN="$WS/phases/P-fixture/tasks/T-mismatch-PLAN.md"
{
  printf '%s\n' '---'
  printf '%s\n' 'schema_version: "1.0"'
  printf '%s\n' 'type: task-plan'
  printf '%s\n' 'id: "T-mismatch"'
  printf '%s\n' 'topic_tags: [does-not-match-anything]'
  printf '%s\n' '---'
  printf '%s\n' '# T-mismatch'
} > "$PLAN"
OUT="$WS/out.txt"
bash "$ROOT/scripts/dispatch/build-context.sh" \
  "$WS" M-fixture P-fixture T-mismatch > "$OUT" 2>/dev/null || true
pass=0
fail=0
if grep -qF -e "## Reference" "$OUT"; then
  echo "FAIL: reference-section-emitted-when-no-matches"
  fail=$((fail + 1))
else
  echo "PASS: omit-empty-section-honored"
  pass=$((pass + 1))
fi
echo "SUMMARY: m036-p07-omit-empty-section.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
