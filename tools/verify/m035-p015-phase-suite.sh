#!/usr/bin/env bash
# tools/verify/m035-p015-phase-suite.sh -- M035 P01.5 phase-grain aggregator.
#
# AD-19-prefixed phase-suite that runs every per-task verifier in
# sequence and emits 'BATTERY: pass=N fail=N'. Naming mirrors the
# M035/P00 + tools/verify/m035-p01-phase-suite.sh convention from P01.
#
# Single-script-file shape per AD-19. No compound chains (CON-3 / AP-009).

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0
fail=0

# Folded check from T08 step 5: operator runbook artifact must be on disk.
if [ ! -f "$REPO_ROOT/.orchestrator/milestones/M035/phases/P01.5/operator-runbook.md" ]; then
  echo "FAIL: operator-runbook.md missing -- T08 step 4 incomplete" >&2
  fail=$((fail + 1))
fi

for v in \
  "m035-p015-allowlist-shape.sh" \
  "m035-p015-decisions-block.sh" \
  "m035-p015-pre-rename-tag.sh" \
  "m035-p015-spec-dir-rename.sh" \
  "m035-p015-operator-paths.sh" \
  "m035-p015-c1-sweep.sh" \
  "m035-p015-c2-c3-prose.sh" \
  "m035-p015-c5-cohort-finish.sh" \
  "m035-p015-c4-classification.sh" \
  "m035-p015-sc7.sh" \
  "m035-p015-sc7b.sh"; do
  if [ ! -x "$REPO_ROOT/tools/verify/$v" ]; then
    if [ -f "$REPO_ROOT/tools/verify/$v" ]; then
      chmod +x "$REPO_ROOT/tools/verify/$v"
    else
      echo "FAIL: missing verifier $v" >&2
      fail=$((fail + 1))
      continue
    fi
  fi
  if bash "$REPO_ROOT/tools/verify/$v"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
  fi
done

echo "BATTERY: pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
