#!/usr/bin/env bash
# scripts/verify/m014-p03-auto-apply.sh
# Verifies M014/P03/T04 auto-apply gates per FR-10 + CON-5/SC-5.
#
# Cases (each in its own hermetic scratch root):
#   A. High-confidence uat-bug (R1 @ 0.9) → comment_actioned event with
#      action_taken=auto-apply-uat-bug; the M013 UAT-ingest entry-point is
#      stubbed so the auto-apply path is observable without depending on
#      M013's runtime behavior.
#   B. High-confidence decision-append (R4 @ 0.95) → DECISIONS.md gets a
#      templated row + comment_actioned event with
#      action_taken=auto-apply-decision-append.
#   C. Low-confidence uat-bug (R2 @ 0.7) under default 0.8 threshold → no
#      auto-apply event; review-queue Q-<id>.md present.
#   D. High-confidence spec-amendment (R9 @ 0.95) → ALWAYS queues regardless
#      of confidence; no auto-apply event for the spec-amendment class
#      (CON-5 / SC-5 invariant — the SC-5 hard gate is also asserted by
#      m014-p03-spec-amendment-human-gate.sh on the source).
#
# AD-19 single-script-file shape; CON-6 / MEM001 Bash 3.2.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMMENTS="${REPO_ROOT}/scripts/comments/comments.sh"

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

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

# Build a stub UAT-ingest script that is observable. The pipeline calls it
# with `--comment <url> --body-file <inbox-json>`; the stub records the
# invocation to a marker file we can assert on.
UAT_STUB="$SCRATCH/uat-ingest-stub.sh"
cat > "$UAT_STUB" <<'STUB'
#!/usr/bin/env bash
# Test stub — records its arguments to $UAT_STUB_MARKER so the verifier can
# assert the pipeline invoked the M013 UAT-ingest path.
echo "uat-stub-invoked args=$*" >> "${UAT_STUB_MARKER:-/dev/null}"
exit 0
STUB
chmod +x "$UAT_STUB"

# Adapter override — point at a non-executable path so any ambiguous
# fall-through routes to triage rather than calling the real adapter.
ABSENT_ADAPTER="$SCRATCH/no-adapter.sh"

# _seed_root <root> — populate scratch with .orchestrator skeleton +
# DECISIONS.md table.
_seed_root() {
  _r="$1"
  mkdir -p "${_r}/.orchestrator/comments"
  printf '# DECISIONS\n\n| ID | Title | Owner | Body | Rationale | Outcome |\n| --- | --- | --- | --- | --- | --- |\n' \
    > "${_r}/.orchestrator/DECISIONS.md"
}

# ---------------- Case A: high-conf uat-bug ----------------
ROOT_A="$SCRATCH/case-a"
_seed_root "$ROOT_A"
FIX_A="$SCRATCH/fix-a.jsonl"
# R1: body starts with "kind: uat-bug" → confidence 0.9 (above 0.8 threshold).
printf '{"url":"https://github.com/x/y/issues/100#issuecomment-100","body":"kind: uat-bug","source_surface":"github","id":"a1","created_at":"2026-04-24T00:00:00Z"}\n' \
  > "$FIX_A"
MARK_A="$SCRATCH/uat-stub-a.log"
ORCHESTRATOR_PROJECT_ROOT="$ROOT_A" \
GH_API_STUB="$FIX_A" \
GH_GRAPHQL_STUB="$FIX_A" \
COMMENTS_ADAPTER="$ABSENT_ADAPTER" \
COMMENTS_UAT_INGEST="$UAT_STUB" \
UAT_STUB_MARKER="$MARK_A" \
  bash "$COMMENTS" classify --yes > "$SCRATCH/a.out" 2> "$SCRATCH/a.err"
rc_a=$?
if [ "$rc_a" -eq 0 ]; then
  if grep -q '"action_taken":"auto-apply-uat-bug"' "$ROOT_A/.orchestrator/execution-log.jsonl"; then
    if [ -f "$MARK_A" ]; then
      if grep -q 'uat-stub-invoked' "$MARK_A"; then
        _pass "Case A: high-conf uat-bug auto-applied + M013 UAT-ingest stub invoked"
      else
        _fail "Case A: stub marker file present but missing invocation line"
      fi
    else
      _fail "Case A: M013 UAT-ingest stub never invoked (marker file absent)"
    fi
  else
    _fail "Case A: comment_actioned auto-apply-uat-bug event missing"
  fi
else
  _fail "Case A: classify exited ${rc_a}"
fi

# ---------------- Case B: high-conf decision-append ----------------
ROOT_B="$SCRATCH/case-b"
_seed_root "$ROOT_B"
FIX_B="$SCRATCH/fix-b.jsonl"
# R4: body begins with /append-decision → confidence 0.95.
printf '{"url":"https://github.com/x/y/issues/200#issuecomment-200","body":"/append-decision: pin Bash 3.2","source_surface":"github","id":"b1","created_at":"2026-04-24T00:00:00Z"}\n' \
  > "$FIX_B"
ORCHESTRATOR_PROJECT_ROOT="$ROOT_B" \
GH_API_STUB="$FIX_B" \
GH_GRAPHQL_STUB="$FIX_B" \
COMMENTS_ADAPTER="$ABSENT_ADAPTER" \
COMMENTS_UAT_INGEST="$UAT_STUB" \
  bash "$COMMENTS" classify --yes > "$SCRATCH/b.out" 2> "$SCRATCH/b.err"
rc_b=$?
if [ "$rc_b" -eq 0 ]; then
  if grep -q 'decision-append from' "$ROOT_B/.orchestrator/DECISIONS.md"; then
    if grep -q '"action_taken":"auto-apply-decision-append"' "$ROOT_B/.orchestrator/execution-log.jsonl"; then
      _pass "Case B: high-conf decision-append appended row + emitted event"
    else
      _fail "Case B: DECISIONS.md row present but comment_actioned event missing"
    fi
  else
    _fail "Case B: DECISIONS.md not appended"
  fi
else
  _fail "Case B: classify exited ${rc_b}"
fi

# ---------------- Case C: low-conf uat-bug below threshold ----------------
ROOT_C="$SCRATCH/case-c"
_seed_root "$ROOT_C"
FIX_C="$SCRATCH/fix-c.jsonl"
# R2: "acceptance criterion ... fails" → confidence 0.7 (below 0.8 default).
printf '{"url":"https://github.com/x/y/issues/300#issuecomment-300","body":"acceptance criterion 2 fails on macOS 13","source_surface":"github","id":"c1","created_at":"2026-04-24T00:00:00Z"}\n' \
  > "$FIX_C"
ORCHESTRATOR_PROJECT_ROOT="$ROOT_C" \
GH_API_STUB="$FIX_C" \
GH_GRAPHQL_STUB="$FIX_C" \
COMMENTS_ADAPTER="$ABSENT_ADAPTER" \
COMMENTS_UAT_INGEST="$UAT_STUB" \
  bash "$COMMENTS" classify --yes > "$SCRATCH/c.out" 2> "$SCRATCH/c.err"
rc_c=$?
if [ "$rc_c" -eq 0 ]; then
  if grep -lE 'class:[[:space:]]*"uat-bug"' "$ROOT_C/.orchestrator/comments/review-queue/"*.md >/dev/null 2>&1; then
    if grep -q '"action_taken":"auto-apply-uat-bug"' "$ROOT_C/.orchestrator/execution-log.jsonl"; then
      _fail "Case C: low-conf uat-bug should have queued, but auto-apply-uat-bug event present"
    else
      _pass "Case C: low-conf uat-bug queued without auto-apply event (threshold gate)"
    fi
  else
    _fail "Case C: queued uat-bug entry missing in review-queue"
  fi
else
  _fail "Case C: classify exited ${rc_c}"
fi

# ---------------- Case D: high-conf spec-amendment (SC-5 invariant) ----
ROOT_D="$SCRATCH/case-d"
_seed_root "$ROOT_D"
FIX_D="$SCRATCH/fix-d.jsonl"
# R9: "amend " prefix → confidence 0.95 (would be auto-applied if the SC-5
# invariant ever broke). spec-amendment class always queues.
printf '{"url":"https://github.com/x/y/issues/400#issuecomment-400","body":"amend FR-1 to require explicit zero-prompt mode","source_surface":"github","id":"d1","created_at":"2026-04-24T00:00:00Z"}\n' \
  > "$FIX_D"
ORCHESTRATOR_PROJECT_ROOT="$ROOT_D" \
GH_API_STUB="$FIX_D" \
GH_GRAPHQL_STUB="$FIX_D" \
COMMENTS_ADAPTER="$ABSENT_ADAPTER" \
COMMENTS_UAT_INGEST="$UAT_STUB" \
  bash "$COMMENTS" classify --yes > "$SCRATCH/d.out" 2> "$SCRATCH/d.err"
rc_d=$?
if [ "$rc_d" -eq 0 ]; then
  if grep -lE 'class:[[:space:]]*"spec-amendment"' "$ROOT_D/.orchestrator/comments/review-queue/"*.md >/dev/null 2>&1; then
    # Belt-and-suspenders: no spec-amendment auto-apply event.
    if grep -q '"class":"spec-amendment".*"action_taken":"auto-apply' "$ROOT_D/.orchestrator/execution-log.jsonl"; then
      _fail "Case D: SC-5 violation — spec-amendment auto-apply event leaked"
    else
      _pass "Case D: high-conf spec-amendment queued; no auto-apply event (CON-5/SC-5)"
    fi
  else
    _fail "Case D: queued spec-amendment entry missing in review-queue"
  fi
else
  _fail "Case D: classify exited ${rc_d}"
fi

echo "----"
echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
echo "PASS: $(basename "$0")"
exit 0
