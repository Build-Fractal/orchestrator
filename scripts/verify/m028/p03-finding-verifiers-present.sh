#!/usr/bin/env bash
# scripts/verify/m028/p03-finding-verifiers-present.sh -- M028/P03/T05 plan-level
# verifier asserting the per-finding verifier suite is present and the
# roll-up runs clean.
#
# Asserts:
#   1. Each per-finding verifier T05 owns or inherits exists on disk:
#        finding-A-verifier.sh        (P02 inherited)
#        finding-B-verifier.sh        (T05)
#        finding-C-verifier.sh        (T05)
#        finding-F-verifier.sh        (P02 inherited)
#        finding-G-classifier-verifier.sh   (T05)
#        finding-G-self-conformance.sh      (T05; SC-9 axis, separate from SC-4 roll-up)
#      run-all.sh                     (T05; the SC-4 roll-up)
#   2. Findings D and E are SKIP-acknowledged (not yet authored; P04 deliverables).
#   3. run-all.sh exits 0 and emits a final-line summary of either
#      "M028: 5/7 findings verified (skipped: 2, failed: 0)" (current P03 state)
#      or "M028: 7/7 findings verified (skipped: 0, failed: 0)" (post-P04).
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# ---- Required verifiers (must exist) ----
REQUIRED="finding-A-verifier.sh finding-B-verifier.sh finding-C-verifier.sh finding-F-verifier.sh finding-G-classifier-verifier.sh finding-G-self-conformance.sh run-all.sh"

for v in $REQUIRED; do
  vpath="${SCRIPT_DIR}/${v}"
  if [ -f "$vpath" ]; then
    pass "$v present"
  else
    fail "$v present" "missing at $vpath"
  fi
done

# ---- P04 deliverables (acknowledge SKIP without failing) ----
DEFERRED="finding-D-verifier.sh finding-E-verifier.sh"
for v in $DEFERRED; do
  vpath="${SCRIPT_DIR}/${v}"
  if [ -f "$vpath" ]; then
    pass "$v present (P04 landed)"
  else
    pass "$v deferred to P04 (acknowledged SKIP)"
  fi
done

# ---- run-all.sh end-to-end ----
RUNALL="${SCRIPT_DIR}/run-all.sh"
if [ ! -f "$RUNALL" ]; then
  echo "FAIL: $fail_count check(s) failed in p03-finding-verifiers-present.sh"
  exit 1
fi

_out="$(mktemp)"
bash "$RUNALL" > "$_out" 2>&1
_rc=$?

if [ "$_rc" -eq 0 ]; then
  pass "run-all.sh exits 0"
else
  _tail="$(tail -5 "$_out")"
  fail "run-all.sh exits 0" "rc=$_rc tail=[$_tail]"
fi

# Final-line shape: "M028: <pass>/7 findings verified (skipped: N, failed: 0)"
if grep -Eq '^M028: (5|7)/7 findings verified \(skipped: [0-9]+, failed: 0\)$' "$_out"; then
  _summary="$(grep '^M028: ' "$_out" | head -1)"
  pass "run-all.sh summary line shape: $_summary"
else
  _summary="$(grep '^M028: ' "$_out" | head -1)"
  fail "run-all.sh summary line shape" "saw [$_summary]"
fi

rm -f "$_out"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: p03-finding-verifiers-present.sh"
  exit 0
fi
echo "FAIL: $fail_count check(s) failed in p03-finding-verifiers-present.sh"
exit 1
