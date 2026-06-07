#!/usr/bin/env bash
# tools/verify/m044-p01-t03-zeromem-warning.sh
# M044/P01/T03 (FR-15/SC-10): inject-size surface always present; 0-MEM warning
# fires on a mature project but NOT on a greenfield one.
# Bash 3.2. Emits PASS:/FAIL:; exit 0 on PASS, 1 on FAIL.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

fail=0
LIB="scripts/dispatch/lib/knowledge-provenance.sh"
# shellcheck source=/dev/null
. "$LIB"

# --- mature fixture: milestone SUMMARY on disk -> mature ---
MAT="$(mktemp -d)"
trap 'rm -rf "$MAT" "$FRESH"' EXIT
mkdir -p "$MAT/.orchestrator/milestones/M001"
printf '# M001 Summary\n' > "$MAT/.orchestrator/milestones/M001/M001-SUMMARY.md"
m_mat="$(kp_is_mature "$MAT")"
if [ "$m_mat" != "1" ]; then
  echo "FAIL: kp_is_mature on a project with a milestone SUMMARY = '$m_mat' (expected 1)"
  fail=1
fi

# --- mature via decisions row ---
MAT2="$(mktemp -d)"
mkdir -p "$MAT2/.orchestrator"
printf '| D001 | Decision | Choice | arch | M001/P01 | Rationale |\n' > "$MAT2/.orchestrator/DECISIONS.md"
m_mat2="$(kp_is_mature "$MAT2")"
if [ "$m_mat2" != "1" ]; then
  echo "FAIL: kp_is_mature on a project with a decisions row = '$m_mat2' (expected 1)"
  fail=1
fi
rm -rf "$MAT2"

# --- greenfield fixture: nothing on disk -> NOT mature ---
FRESH="$(mktemp -d)"
mkdir -p "$FRESH/.orchestrator"
m_fresh="$(kp_is_mature "$FRESH")"
if [ "$m_fresh" != "0" ]; then
  echo "FAIL: kp_is_mature on a greenfield project = '$m_fresh' (expected 0)"
  fail=1
fi

# --- integration wiring: inject-size + 0-MEM warning + maturity gate ---
BC="scripts/dispatch/build-context.sh"
if ! grep -q 'kp_is_mature' "$BC"; then
  echo "FAIL: build-context.sh does not call kp_is_mature"
  fail=1
fi
if ! grep -q 'knowledge: ' "$BC"; then
  echo "FAIL: build-context.sh does not emit the inject-size surface"
  fail=1
fi
if ! grep -q '0-MEM inject on a project with prior milestones' "$BC"; then
  echo "FAIL: build-context.sh does not carry the 0-MEM warning string"
  fail=1
fi
# The 0-MEM warning must be gated on maturity (no false alarm on greenfield).
if ! grep -q '_M044_IS_MATURE' "$BC"; then
  echo "FAIL: 0-MEM warning is not gated on the maturity probe"
  fail=1
fi

# --- live payload always carries the inject-size line ---
OUT="$(mktemp)"
bash "$BC" --task-plan "$BC" --profile quick --out "$OUT" >/dev/null 2>&1 || true
if ! grep -qE '^knowledge: [0-9]+ MEMs / [0-9]+ tokens' "$OUT"; then
  echo "FAIL: live payload missing inject-size surface 'knowledge: N MEMs / X tokens'"
  fail=1
fi
rm -f "$OUT"

if [ "$fail" -eq 0 ]; then
  echo "PASS: inject-size always present; 0-MEM warning gated on maturity"
  exit 0
fi
exit 1
