#!/usr/bin/env bash
# tools/verify/m044-p01-t04-consolidated-doctor.sh
# M044/P01/T04 (FR-15/FR-9/SC-11/CON-5): ONE consolidated knowledge-activation
# doctor surface; fails on 0-mem-on-mature; ok on a healthy project; registered
# in run-doctor.sh + documented; papercut reconciled.
# Bash 3.2. Emits PASS:/FAIL:; exit 0 on PASS, 1 on FAIL.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

fail=0
CHECK="scripts/diagnostics/check-knowledge-activation.sh"

if [ ! -f "$CHECK" ]; then
  echo "FAIL: $CHECK not found"
  exit 1
fi

# 1. Exactly one knowledge-activation doctor surface (CON-5).
surfaces="$(grep -rlE 'DOCTOR:KNOWLEDGE_ACTIVATION' scripts/diagnostics/ 2>/dev/null | sort)"
surf_count="$(printf '%s\n' "$surfaces" | grep -c . )"
if [ "$surf_count" -ne 1 ] || [ "$surfaces" != "$CHECK" ]; then
  echo "FAIL: expected exactly one DOCTOR:KNOWLEDGE_ACTIVATION surface (= $CHECK), found $surf_count:"
  printf '  %s\n' $surfaces
  fail=1
fi
# No second/overlapping DOCTOR:KNOWLEDGE_* surface.
other="$(grep -rlE 'DOCTOR:KNOWLEDGE_[A-Z]' scripts/diagnostics/ 2>/dev/null | grep -v "$CHECK" || true)"
if [ -n "$other" ]; then
  echo "FAIL: a second DOCTOR:KNOWLEDGE_* surface exists: $other"
  fail=1
fi

# 2. mature-empty fixture -> status=fail, symptoms include 0-mem-on-mature.
MAT="$(mktemp -d)"
trap 'rm -rf "$MAT" "$OK"' EXIT
mkdir -p "$MAT/.orchestrator/milestones/M001"
printf '# M001 Summary\n' > "$MAT/.orchestrator/milestones/M001/M001-SUMMARY.md"
printf '# Knowledge Index\n' > "$MAT/KNOWLEDGE-INDEX.md"   # header only, 0 MEM rows
out_mat="$(bash "$CHECK" --root "$MAT" 2>/dev/null || true)"
if ! printf '%s' "$out_mat" | grep -q 'status=fail'; then
  echo "FAIL: mature-empty fixture did not report status=fail. Got: $out_mat"
  fail=1
fi
if ! printf '%s' "$out_mat" | grep -q '0-mem-on-mature'; then
  echo "FAIL: mature-empty fixture symptoms missing 0-mem-on-mature. Got: $out_mat"
  fail=1
fi

# 3. healthy fixture -> status=ok.
OK="$(mktemp -d)"
mkdir -p "$OK/.orchestrator"
printf '# Knowledge Index\nMEM001 | [project] | patterns | 0.9 | 2026-06-07 | verified:2026-06-07 | hits:1 | seed\n' > "$OK/KNOWLEDGE-INDEX.md"
printf '| D001 | Decision | Choice | arch | M001/P01 | Rationale |\n' > "$OK/.orchestrator/DECISIONS.md"
out_ok="$(bash "$CHECK" --root "$OK" 2>/dev/null || true)"
if ! printf '%s' "$out_ok" | grep -q 'status=ok'; then
  echo "FAIL: healthy fixture did not report status=ok. Got: $out_ok"
  fail=1
fi

# 4. registered in run-doctor.sh + documented + papercut reconciled.
if ! grep -q 'check-knowledge-activation.sh' scripts/diagnostics/run-doctor.sh; then
  echo "FAIL: check not registered in run-doctor.sh"
  fail=1
fi
if ! grep -q 'KNOWLEDGE_ACTIVATION\|Knowledge Activation' commands/doctor.md; then
  echo "FAIL: check not documented in commands/doctor.md"
  fail=1
fi
if ! grep -q 'Reconciled into M044/FR-15' .orchestrator/proposals/papercut-doctor-knowledge-gap-surface.md; then
  echo "FAIL: papercut not annotated as reconciled"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "PASS: single consolidated knowledge-activation doctor check; fail-on-mature-empty; reconciled"
  exit 0
fi
exit 1
