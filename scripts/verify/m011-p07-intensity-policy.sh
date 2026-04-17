#!/usr/bin/env bash
# scripts/verify/m011-p07-intensity-policy.sh
# Contract anchor asserting the documented user-facing overrides in
# commands/ingest.md are reachable and that the three intensity levels
# resolve the expected substeps.
#
# Assertions:
#   1. Quick intensity -> execute_substeps contains normalize, not fidelity-gate.
#   2. Standard intensity -> execute_substeps contains normalize AND fidelity-gate.
#   3. Full intensity -> execute_substeps contains normalize AND fidelity-gate.
#   4. --review flag is documented with "force"/"fidelity gate" prose.
#   5. --no-review flag is documented with "skip" or "force off" prose.
#   6. --force flag semantics include BLOCK-verdict bypass (BLOCK token appears
#      within 10 lines of a --force occurrence).
#
# Bash 3.2 compatible.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$REPO/commands/ingest.md"
GATE="$REPO/scripts/engine/intensity-gate.sh"

fail=0

assert_substeps() {
  local level="$1"
  local must_have="$2"
  local must_exclude="$3"
  local out
  out="$(bash "$GATE" --stage ingest --intensity "$level" 2>/dev/null || true)"
  if [ -z "$out" ]; then
    printf 'FAIL[intensity:%s]: intensity-gate produced no output\n' "$level"
    fail=1
    return
  fi
  local substeps
  substeps="$(printf '%s\n' "$out" | grep -E '^execute_substeps=' | head -n 1)"
  if [ -z "$substeps" ]; then
    printf 'FAIL[intensity:%s]: no execute_substeps= line in output\n' "$level"
    fail=1
    return
  fi
  if ! printf '%s\n' "$substeps" | grep -Fq -- "$must_have"; then
    printf 'FAIL[intensity:%s]: expected %s in %s\n' "$level" "$must_have" "$substeps"
    fail=1
  fi
  if [ -n "$must_exclude" ]; then
    if printf '%s\n' "$substeps" | grep -Fq -- "$must_exclude"; then
      printf 'FAIL[intensity:%s]: expected %s NOT in %s\n' "$level" "$must_exclude" "$substeps"
      fail=1
    fi
  fi
}

# 1. Quick -> normalize only (no fidelity-gate)
assert_substeps "Quick" "normalize" "fidelity-gate"
# 2. Standard -> normalize + fidelity-gate
assert_substeps "Standard" "fidelity-gate" ""
# 3. Full -> normalize + fidelity-gate
assert_substeps "Full" "fidelity-gate" ""

# 4. --review override documented with force + fidelity gate prose.
REVIEW_CTX="$(grep -B 2 -A 5 -- '--review' "$DOC" 2>/dev/null || true)"
if [ -z "$REVIEW_CTX" ]; then
  printf 'FAIL[doc:--review]: no context found around --review flag in %s\n' "$DOC"
  fail=1
else
  if ! printf '%s\n' "$REVIEW_CTX" | grep -Eiq 'force.*fidelity.*gate|fidelity.*gate.*on|force.*the.*fidelity'; then
    printf 'FAIL[doc:--review]: --review context missing force/fidelity-gate prose\n'
    fail=1
  fi
fi

# 5. --no-review override documented with skip/force off prose.
NOREVIEW_CTX="$(grep -B 2 -A 5 -- '--no-review' "$DOC" 2>/dev/null || true)"
if [ -z "$NOREVIEW_CTX" ]; then
  printf 'FAIL[doc:--no-review]: no context found around --no-review flag\n'
  fail=1
else
  if ! printf '%s\n' "$NOREVIEW_CTX" | grep -Eiq 'skip|force off|force.*off'; then
    printf 'FAIL[doc:--no-review]: --no-review context missing skip/force-off prose\n'
    fail=1
  fi
fi

# 6. --force semantics include BLOCK bypass. Search for BLOCK within 10 lines
# of a --force occurrence.
FORCE_CTX="$(grep -n -- '--force' "$DOC" 2>/dev/null || true)"
if [ -z "$FORCE_CTX" ]; then
  printf 'FAIL[doc:--force]: no --force occurrences in %s\n' "$DOC"
  fail=1
else
  FOUND_BLOCK_NEAR_FORCE=0
  # For each --force occurrence, extract the ±10 line window and look for BLOCK.
  while IFS= read -r line; do
    n="$(printf '%s\n' "$line" | awk -F: '{print $1}')"
    if [ -z "$n" ]; then
      continue
    fi
    lo=$((n - 10))
    if [ "$lo" -lt 1 ]; then
      lo=1
    fi
    hi=$((n + 10))
    WINDOW="$(awk -v lo="$lo" -v hi="$hi" 'NR>=lo && NR<=hi {print}' "$DOC")"
    if printf '%s\n' "$WINDOW" | grep -Fq -- 'BLOCK'; then
      FOUND_BLOCK_NEAR_FORCE=1
      break
    fi
  done <<EOF
$FORCE_CTX
EOF
  if [ "$FOUND_BLOCK_NEAR_FORCE" -ne 1 ]; then
    printf 'FAIL[doc:--force]: no BLOCK mention within 10 lines of a --force occurrence\n'
    fail=1
  fi
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS: intensity matrix + --review/--no-review/--force documentation verified"
exit 0
