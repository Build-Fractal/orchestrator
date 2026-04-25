#!/usr/bin/env bash
# scripts/verify/m014-p03-pipeline.sh
# Verifies M014/P03/T04: scripts/comments/comments.sh master pipeline.
#
# Hermetic scratch root + 4-comment fixture exercising every routing class
# (uat-bug, decision-append, spec-amendment, ambiguous). Asserts:
#
#   1. comments.sh classify exits 0 with the FR-9-style summary line.
#   2. classified=4 across the four fixture comments.
#   3. The decision-append comment (R5 @ 0.85) auto-applies (above 0.8 default
#      threshold) — DECISIONS.md gets a templated row, comment_actioned event
#      lands with action_taken=auto-apply-decision-append.
#   4. The uat-bug comment (R2 @ 0.7) lands in the review-queue (below the
#      0.8 default threshold) — Q-<id>.md present.
#   5. The spec-amendment comment (R7 @ 0.85) ALWAYS queues regardless of
#      its high confidence (CON-5 / SC-5 invariant retest at the pipeline
#      seam — the apply.sh class-gate is verified separately by
#      m014-p03-spec-amendment-human-gate.sh).
#   6. The ambiguous comment routes to human-triage with
#      conversus_verdict=adapter-missing because the verifier points
#      COMMENTS_ADAPTER at a non-executable path (D007 reuse — we never
#      modify the real adapter to test).
#   7. unit_close JSONL emitted with comments_classified, comments_auto_applied,
#      comments_queued, conversus_invocations, elapsed_ms, source=runtime.
#   8. Idempotency: a second classify run on the same scratch root
#      classifies 0 new comments (every URL already in actioned.jsonl is
#      skipped) for trivial-class auto-apply paths; queue/triage entries
#      remain stable (deterministic shasum filenames).
#
# AD-19 single-script-file shape; CON-6 / MEM001 Bash 3.2.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMMENTS="${REPO_ROOT}/scripts/comments/comments.sh"
FIXTURE="${REPO_ROOT}/tests/fixtures/m014-p03/sample-inbox.jsonl"

pass=0
fail=0
_pass() { pass=$((pass + 1)); echo "PASS: $1"; }
_fail() { fail=$((fail + 1)); echo "FAIL: $1"; }

if [ ! -x "$COMMENTS" ]; then
  _fail "comments.sh missing or not executable at $COMMENTS"
  echo "----"
  echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
  exit 1
fi
if [ ! -f "$FIXTURE" ]; then
  _fail "fixture missing at $FIXTURE"
  echo "----"
  echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
  exit 1
fi

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
mkdir -p "$SCRATCH/.orchestrator/comments"
# Seed an empty DECISIONS.md so the decision-append append-path has a target.
printf '# DECISIONS\n\n| ID | Title | Owner | Body | Rationale | Outcome |\n| --- | --- | --- | --- | --- | --- |\n' \
  > "$SCRATCH/.orchestrator/DECISIONS.md"

# Point COMMENTS_ADAPTER at a non-executable path — the ambiguous-routing
# code-path under D007 deliberately does not modify the real adapter for
# tests. The pipeline takes the adapter-missing → triage branch.
ABSENT_ADAPTER="$SCRATCH/no-adapter.sh"

# ---------------- Run 1 ----------------
ORCHESTRATOR_PROJECT_ROOT="$SCRATCH" \
GH_API_STUB="$FIXTURE" \
GH_GRAPHQL_STUB="$FIXTURE" \
COMMENTS_ADAPTER="$ABSENT_ADAPTER" \
  bash "$COMMENTS" classify --yes \
    > "$SCRATCH/run1.out" 2> "$SCRATCH/run1.err"
rc=$?

if [ "$rc" -eq 0 ]; then
  _pass "classify exits 0"
else
  _fail "classify exited ${rc} (stdout=$(cat "$SCRATCH/run1.out") stderr=$(cat "$SCRATCH/run1.err"))"
fi

# Assertion 2: classified=4.
if grep -qE 'SUMMARY: comments classify classified=4' "$SCRATCH/run1.out"; then
  _pass "classified=4 across the fixture"
else
  _fail "expected classified=4 in summary; got: $(grep -E 'SUMMARY:' "$SCRATCH/run1.out")"
fi

# Assertion 3: decision-append auto-apply landed in DECISIONS.md +
# comment_actioned event in execution-log.jsonl.
if grep -q 'decision-append from' "$SCRATCH/.orchestrator/DECISIONS.md"; then
  _pass "decision-append auto-apply appended a templated row to DECISIONS.md"
else
  _fail "DECISIONS.md missing decision-append templated row"
fi
if grep -q '"action_taken":"auto-apply-decision-append"' "$SCRATCH/.orchestrator/execution-log.jsonl"; then
  _pass "comment_actioned event for decision-append present"
else
  _fail "comment_actioned event for decision-append missing"
fi

# Assertion 4: uat-bug below default 0.8 threshold queued (R2 fires at 0.7).
queued_uat="$(grep -lE 'class:[[:space:]]*"uat-bug"' "$SCRATCH/.orchestrator/comments/review-queue/"*.md 2>/dev/null | head -n 1)"
if [ -n "$queued_uat" ]; then
  _pass "low-confidence uat-bug queued at $(basename "$queued_uat")"
else
  _fail "expected a queued uat-bug (R2 @ 0.7 below 0.8 default threshold)"
fi

# Assertion 5: spec-amendment always queues regardless of its 0.85 confidence.
queued_amend="$(grep -lE 'class:[[:space:]]*"spec-amendment"' "$SCRATCH/.orchestrator/comments/review-queue/"*.md 2>/dev/null | head -n 1)"
if [ -n "$queued_amend" ]; then
  _pass "spec-amendment queued regardless of confidence (CON-5/SC-5)"
else
  _fail "expected a queued spec-amendment file in review-queue"
fi
# Belt-and-suspenders: no auto-apply event for spec-amendment.
if grep -q '"class":"spec-amendment".*"action_taken":"auto-apply' "$SCRATCH/.orchestrator/execution-log.jsonl"; then
  _fail "spec-amendment auto-apply event leaked (SC-5 violation)"
else
  _pass "no spec-amendment auto-apply event (SC-5 invariant holds at pipeline seam)"
fi

# Assertion 6: ambiguous routes to triage with adapter-missing verdict.
triage_files="$(ls "$SCRATCH/.orchestrator/comments/triage/" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$triage_files" -ge 1 ]; then
  if grep -lE 'conversus_verdict:[[:space:]]*"adapter-missing"' "$SCRATCH/.orchestrator/comments/triage/"*.md >/dev/null 2>&1; then
    _pass "ambiguous routed to triage with adapter-missing verdict (D007 reuse: real adapter untouched)"
  else
    _fail "triage entry present but adapter-missing verdict not recorded"
  fi
else
  _fail "expected at least one triage entry for the ambiguous comment"
fi

# Assertion 7: unit_close JSONL with FR-16 fields.
if grep -qE '"event":"unit_close".*"command":"comments classify"' "$SCRATCH/.orchestrator/execution-log.jsonl"; then
  unit_line="$(grep '"event":"unit_close"' "$SCRATCH/.orchestrator/execution-log.jsonl" | tail -n 1)"
  ok=1
  for k in comments_classified comments_auto_applied comments_queued conversus_invocations elapsed_ms '"source":"runtime"'; do
    if ! printf '%s' "$unit_line" | grep -q "$k"; then
      _fail "unit_close missing field: $k"
      ok=0
    fi
  done
  if [ "$ok" -eq 1 ]; then
    _pass "unit_close emitted with all FR-16 fields"
  fi
else
  _fail "unit_close JSONL not emitted to execution-log.jsonl"
fi

# Capture queue + triage filenames pre-second-run for idempotency check.
queue_before="$(ls "$SCRATCH/.orchestrator/comments/review-queue/" 2>/dev/null | sort | tr '\n' ' ')"
triage_before="$(ls "$SCRATCH/.orchestrator/comments/triage/" 2>/dev/null | sort | tr '\n' ' ')"
exec_before_lines="$(wc -l < "$SCRATCH/.orchestrator/execution-log.jsonl" | tr -d ' ')"

# ---------------- Run 2: idempotency ----------------
ORCHESTRATOR_PROJECT_ROOT="$SCRATCH" \
GH_API_STUB="$FIXTURE" \
GH_GRAPHQL_STUB="$FIXTURE" \
COMMENTS_ADAPTER="$ABSENT_ADAPTER" \
  bash "$COMMENTS" classify --yes \
    > "$SCRATCH/run2.out" 2> "$SCRATCH/run2.err"
rc2=$?

if [ "$rc2" -eq 0 ]; then
  _pass "second classify run exits 0"
else
  _fail "second classify run exited ${rc2}"
fi

# Auto-applied URLs are now in actioned.jsonl, so they are skipped on the
# loop; queued/triage URLs are NOT in actioned.jsonl (they have not been
# applied yet) so they re-classify. Queue + triage filenames are
# deterministic shasum prefixes, so the entries are overwritten in place
# rather than duplicated. We assert that the file SETS are identical.
queue_after="$(ls "$SCRATCH/.orchestrator/comments/review-queue/" 2>/dev/null | sort | tr '\n' ' ')"
triage_after="$(ls "$SCRATCH/.orchestrator/comments/triage/" 2>/dev/null | sort | tr '\n' ' ')"

if [ "$queue_before" = "$queue_after" ]; then
  _pass "review-queue filenames stable across runs (deterministic shasum)"
else
  _fail "review-queue filenames diverged: before='${queue_before}' after='${queue_after}'"
fi
if [ "$triage_before" = "$triage_after" ]; then
  _pass "triage filenames stable across runs (deterministic shasum)"
else
  _fail "triage filenames diverged: before='${triage_before}' after='${triage_after}'"
fi

# Idempotency for the auto-apply path: actioned.jsonl should not gain a
# duplicate row for the decision-append comment.
applied_rows="$(grep -c '"action_taken":"auto-apply-decision-append"' "$SCRATCH/.orchestrator/comments/actioned.jsonl" 2>/dev/null || true)"
if [ "${applied_rows:-0}" -eq 1 ]; then
  _pass "auto-apply path idempotent — single decision-append row in actioned.jsonl"
else
  _fail "expected 1 decision-append row in actioned.jsonl, got ${applied_rows}"
fi

echo "----"
echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
echo "PASS: $(basename "$0")"
exit 0
