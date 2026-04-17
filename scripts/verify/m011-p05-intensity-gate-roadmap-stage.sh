#!/usr/bin/env bash
# scripts/verify/m011-p05-intensity-gate-roadmap-stage.sh
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"

check_intensity() {
  local level="$1" expect_exec="$2"
  local out
  out="$(bash "$REPO/scripts/engine/intensity-gate.sh" --stage roadmap --intensity "$level" 2>/dev/null)"
  local got
  got="$(printf '%s\n' "$out" | awk -F= '$1=="execute_substeps"{print $2; exit}')"
  if [ "$got" != "$expect_exec" ]; then
    printf 'FAIL: stage=roadmap intensity=%s expected execute_substeps=%s got=%s\n' \
      "$level" "$expect_exec" "$got"
    exit 1
  fi
}

check_intensity Quick "single-pass"
check_intensity Standard "basic-decomp,rationale"
check_intensity Full "basic-decomp,rationale,collaborative-loop"

echo "PASS: intensity-gate roadmap stage resolves substeps"
