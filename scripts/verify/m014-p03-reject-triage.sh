#!/usr/bin/env bash
# scripts/verify/m014-p03-reject-triage.sh
# Verifies M014/P03/T03: scripts/comments/reject.sh + scripts/comments/triage.sh.
#
# Cases:
#   A) reject.sh records applied:false row with reason in actioned.jsonl
#      against a hermetic scratch project root.
#   B) reject.sh requires both queue-id and --reason (exits 2 otherwise).
#   C) reject.sh refuses missing queue-id with exit 2.
#   D) triage.sh on empty triage dir prints SUMMARY entries=0 and exit 0.
#   E) triage.sh lists triage entries with conversus_verdict field.
#
# AD-19 single-script-file shape; CON-6 / MEM001 Bash 3.2.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REJECT="${REPO_ROOT}/scripts/comments/reject.sh"
TRIAGE="${REPO_ROOT}/scripts/comments/triage.sh"
FIXTURE="${REPO_ROOT}/tests/fixtures/m014-p03/queued-amendment.md"

pass=0
fail=0
_pass() { pass=$((pass + 1)); echo "PASS: $1"; }
_fail() { fail=$((fail + 1)); echo "FAIL: $1"; }

if [ ! -x "$REJECT" ]; then
  _fail "reject.sh missing or not executable at $REJECT"
fi
if [ ! -x "$TRIAGE" ]; then
  _fail "triage.sh missing or not executable at $TRIAGE"
fi
if [ "$fail" -gt 0 ]; then
  echo "----"
  echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
  exit 1
fi

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

# Case A: reject records applied:false row.
ROOT_A="${SCRATCH}/case-a"
mkdir -p "${ROOT_A}/.orchestrator/comments/review-queue"
cp "$FIXTURE" "${ROOT_A}/.orchestrator/comments/review-queue/Q001.md"
ORCHESTRATOR_PROJECT_ROOT="$ROOT_A" bash "$REJECT" Q001 --reason "operator declined" > "${SCRATCH}/a.out" 2> "${SCRATCH}/a.err"
rc_a=$?
if [ "$rc_a" -eq 0 ]; then
  if grep -q '"applied":false' "${ROOT_A}/.orchestrator/comments/actioned.jsonl"; then
    if grep -q 'operator declined' "${ROOT_A}/.orchestrator/comments/actioned.jsonl"; then
      _pass "Case A: reject records applied:false + reason in actioned.jsonl"
    else
      _fail "Case A: reason missing from actioned.jsonl row"
    fi
  else
    _fail "Case A: applied:false row missing from actioned.jsonl"
  fi
else
  _fail "Case A: reject.sh exited ${rc_a} (stderr=$(cat "${SCRATCH}/a.err"))"
fi

# Case B: requires --reason.
ROOT_B="${SCRATCH}/case-b"
mkdir -p "${ROOT_B}/.orchestrator/comments/review-queue"
cp "$FIXTURE" "${ROOT_B}/.orchestrator/comments/review-queue/Q001.md"
ORCHESTRATOR_PROJECT_ROOT="$ROOT_B" bash "$REJECT" Q001 > "${SCRATCH}/b.out" 2> "${SCRATCH}/b.err"
rc_b=$?
if [ "$rc_b" -eq 2 ]; then
  _pass "Case B: missing --reason refused with exit 2"
else
  _fail "Case B: expected exit 2, got ${rc_b}"
fi

# Case C: missing queue-id.
ROOT_C="${SCRATCH}/case-c"
mkdir -p "${ROOT_C}/.orchestrator/comments/review-queue"
ORCHESTRATOR_PROJECT_ROOT="$ROOT_C" bash "$REJECT" QBOGUS --reason "x" > "${SCRATCH}/c.out" 2> "${SCRATCH}/c.err"
rc_c=$?
if [ "$rc_c" -eq 2 ]; then
  _pass "Case C: missing queue-id refused with exit 2"
else
  _fail "Case C: expected exit 2, got ${rc_c}"
fi

# Case D: triage on empty/absent dir.
ROOT_D="${SCRATCH}/case-d"
mkdir -p "${ROOT_D}/.orchestrator"
ORCHESTRATOR_PROJECT_ROOT="$ROOT_D" bash "$TRIAGE" > "${SCRATCH}/d.out" 2> "${SCRATCH}/d.err"
rc_d=$?
if [ "$rc_d" -eq 0 ]; then
  if grep -q 'SUMMARY: triage entries=0' "${SCRATCH}/d.out"; then
    _pass "Case D: empty triage prints entries=0"
  else
    _fail "Case D: SUMMARY line missing or wrong (out=$(cat "${SCRATCH}/d.out"))"
  fi
else
  _fail "Case D: triage.sh exited ${rc_d}"
fi

# Case E: triage lists entries.
ROOT_E="${SCRATCH}/case-e"
mkdir -p "${ROOT_E}/.orchestrator/comments/triage"
cat > "${ROOT_E}/.orchestrator/comments/triage/T001.md" <<'TRIAGE'
---
comment_url: "https://example/issues/9#issuecomment-9"
conversus_verdict: "low-confidence"
reason: "ambiguous intent"
---

ambiguous comment requiring human review.
TRIAGE
ORCHESTRATOR_PROJECT_ROOT="$ROOT_E" bash "$TRIAGE" > "${SCRATCH}/e.out" 2> "${SCRATCH}/e.err"
rc_e=$?
if [ "$rc_e" -eq 0 ]; then
  if grep -q 'T001' "${SCRATCH}/e.out"; then
    if grep -q 'conversus_verdict=low-confidence' "${SCRATCH}/e.out"; then
      if grep -q 'SUMMARY: triage entries=1' "${SCRATCH}/e.out"; then
        _pass "Case E: triage lists entry with conversus_verdict + count"
      else
        _fail "Case E: SUMMARY count wrong (out=$(cat "${SCRATCH}/e.out"))"
      fi
    else
      _fail "Case E: conversus_verdict field missing in output"
    fi
  else
    _fail "Case E: T001 entry not listed (out=$(cat "${SCRATCH}/e.out"))"
  fi
else
  _fail "Case E: triage.sh exited ${rc_e}"
fi

echo "----"
echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
echo "PASS: $(basename "$0")"
exit 0
