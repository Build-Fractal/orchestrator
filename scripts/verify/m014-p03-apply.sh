#!/usr/bin/env bash
# scripts/verify/m014-p03-apply.sh
# Verifies M014/P03/T03: scripts/comments/apply.sh end-to-end.
#
# Cases (all in hermetic scratch repos via ORCHESTRATOR_PROJECT_ROOT):
#   A) Happy path — queue file present, target spec exists, diff applies,
#      apply.sh exits 0, target spec mutated, actioned.jsonl shows
#      applied:true row, comment_actioned event lands in execution-log.jsonl.
#   B) Stale-diff refusal — same setup but target spec already contains the
#      added line; patch --dry-run fails, apply.sh exits 2 with stale-diff
#      diagnostic, no actioned.jsonl row appended.
#   C) In-flight conversus refusal — same setup as A but spec dir has
#      conversus/ subdir without summary/final.md; apply.sh exits 2 with
#      deliberation-in-progress diagnostic.
#   D) Wrong-class refusal — queue file with class!=spec-amendment exits 2.
#   E) Missing queue-id — apply.sh with bogus queue-id exits 2.
#
# AD-19 single-script-file shape; CON-6 / MEM001 Bash 3.2.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APPLY="${REPO_ROOT}/scripts/comments/apply.sh"
FIXTURE="${REPO_ROOT}/tests/fixtures/m014-p03/queued-amendment.md"

pass=0
fail=0
_pass() { pass=$((pass + 1)); echo "PASS: $1"; }
_fail() { fail=$((fail + 1)); echo "FAIL: $1"; }

if [ ! -x "$APPLY" ]; then
  _fail "apply.sh missing or not executable at $APPLY"
  echo "----"
  echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
  exit 1
fi
if [ ! -f "$FIXTURE" ]; then
  _fail "queued-amendment fixture missing at $FIXTURE"
  echo "----"
  echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
  exit 1
fi

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

# _setup_scratch <root> — populate a hermetic project root with the queue
# file + target spec. Caller can then mutate state for stale/conversus
# scenarios.
_setup_scratch() {
  _root="$1"
  mkdir -p "${_root}/.orchestrator/comments/review-queue"
  mkdir -p "${_root}/specs/m014-p03-test"
  cp "$FIXTURE" "${_root}/.orchestrator/comments/review-queue/Q001.md"
  printf '# FR-1: Test spec\nOriginal line.\n' > "${_root}/specs/m014-p03-test/spec.md"
}

# Case A: happy path.
ROOT_A="${SCRATCH}/case-a"
_setup_scratch "$ROOT_A"
ORCHESTRATOR_PROJECT_ROOT="$ROOT_A" bash "$APPLY" Q001 > "${SCRATCH}/a.out" 2> "${SCRATCH}/a.err"
rc_a=$?
if [ "$rc_a" -eq 0 ]; then
  if grep -q 'Additional line proposed by amendment.' "${ROOT_A}/specs/m014-p03-test/spec.md"; then
    if grep -q '"applied":true' "${ROOT_A}/.orchestrator/comments/actioned.jsonl"; then
      if grep -q 'comment_actioned' "${ROOT_A}/.orchestrator/execution-log.jsonl"; then
        _pass "Case A: happy path applies, actioned, event-logged"
      else
        _fail "Case A: comment_actioned event missing from execution-log.jsonl"
      fi
    else
      _fail "Case A: applied:true row missing from actioned.jsonl"
    fi
  else
    _fail "Case A: target spec not mutated"
  fi
else
  _fail "Case A: apply.sh exited ${rc_a} (stdout=$(cat "${SCRATCH}/a.out") stderr=$(cat "${SCRATCH}/a.err"))"
fi

# Case B: stale-diff refusal.
ROOT_B="${SCRATCH}/case-b"
_setup_scratch "$ROOT_B"
# Pre-mutate the target so the diff is stale.
printf '# FR-1: Test spec\nOriginal line.\nAdditional line proposed by amendment.\n' > "${ROOT_B}/specs/m014-p03-test/spec.md"
ORCHESTRATOR_PROJECT_ROOT="$ROOT_B" bash "$APPLY" Q001 > "${SCRATCH}/b.out" 2> "${SCRATCH}/b.err"
rc_b=$?
if [ "$rc_b" -eq 2 ]; then
  if grep -q 'stale-diff' "${SCRATCH}/b.err"; then
    if [ ! -s "${ROOT_B}/.orchestrator/comments/actioned.jsonl" ]; then
      _pass "Case B: stale-diff refused, no actioned.jsonl row appended"
    else
      _fail "Case B: stale-diff refusal but actioned.jsonl was written"
    fi
  else
    _fail "Case B: exit 2 but stale-diff diagnostic missing (stderr=$(cat "${SCRATCH}/b.err"))"
  fi
else
  _fail "Case B: expected exit 2, got ${rc_b}"
fi

# Case C: in-flight conversus refusal.
ROOT_C="${SCRATCH}/case-c"
_setup_scratch "$ROOT_C"
mkdir -p "${ROOT_C}/specs/m014-p03-test/conversus"
# Note: NO summary/final.md => deliberation in progress.
ORCHESTRATOR_PROJECT_ROOT="$ROOT_C" bash "$APPLY" Q001 > "${SCRATCH}/c.out" 2> "${SCRATCH}/c.err"
rc_c=$?
if [ "$rc_c" -eq 2 ]; then
  if grep -q 'deliberation in progress' "${SCRATCH}/c.err"; then
    _pass "Case C: in-flight conversus refused"
  else
    _fail "Case C: exit 2 but deliberation diagnostic missing (stderr=$(cat "${SCRATCH}/c.err"))"
  fi
else
  _fail "Case C: expected exit 2, got ${rc_c}"
fi

# Case D: wrong-class refusal.
ROOT_D="${SCRATCH}/case-d"
_setup_scratch "$ROOT_D"
# Rewrite queue file with a non-spec-amendment class.
sed -e 's/class: "spec-amendment"/class: "uat-bug"/' "$FIXTURE" > "${ROOT_D}/.orchestrator/comments/review-queue/Q001.md"
ORCHESTRATOR_PROJECT_ROOT="$ROOT_D" bash "$APPLY" Q001 > "${SCRATCH}/d.out" 2> "${SCRATCH}/d.err"
rc_d=$?
if [ "$rc_d" -eq 2 ]; then
  if grep -q 'expected spec-amendment' "${SCRATCH}/d.err"; then
    _pass "Case D: wrong-class refused (uat-bug rejected by manual-apply path)"
  else
    _fail "Case D: exit 2 but class-guard diagnostic missing (stderr=$(cat "${SCRATCH}/d.err"))"
  fi
else
  _fail "Case D: expected exit 2, got ${rc_d}"
fi

# Case E: missing queue-id.
ROOT_E="${SCRATCH}/case-e"
mkdir -p "${ROOT_E}/.orchestrator/comments/review-queue"
ORCHESTRATOR_PROJECT_ROOT="$ROOT_E" bash "$APPLY" QBOGUS > "${SCRATCH}/e.out" 2> "${SCRATCH}/e.err"
rc_e=$?
if [ "$rc_e" -eq 2 ]; then
  if grep -q 'not found' "${SCRATCH}/e.err"; then
    _pass "Case E: missing queue-id refused"
  else
    _fail "Case E: exit 2 but not-found diagnostic missing"
  fi
else
  _fail "Case E: expected exit 2, got ${rc_e}"
fi

echo "----"
echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
echo "PASS: $(basename "$0")"
exit 0
