#!/usr/bin/env bash
# tools/verify/m034-p02-auto-policies.sh — M034 P02 T03 verifier.
#
# Exercises the headless auto-mode policy paths of
# scripts/lifecycle/interactive-review.sh (FR-8 defer / accept-with-audit /
# refuse-entry + FR-9 QUESTIONS.md hand-off).
#
# Builds a fixture packet (>=2 active decisions) via write-decisions.sh and,
# with ORCH_HEADLESS=1 and ORCH_EVENT_LOG=<scratch> (hermetic — the real
# milestone log is never touched), drives interactive-review.sh three times,
# one per policy, against fresh scratch dirs. Asserts:
#   defer            -> <gate>-CONTINUE.md present with all 5 PC-5 keys
#                       + a pending_review line in the scratch log
#                       + a <gate>-QUESTIONS.md + exit 0
#   accept-with-audit-> N auto_accepted lines + N REVIEW.md blocks
#                       + SIGNOFF populated + exit 0
#   refuse-entry     -> a refused_entry line + non-zero exit + no REVIEW.md
#   every run        -> the *-DECISIONS.md is byte-identical (unchanged)
#
# Prints `PASS: m034-p02 auto-policies` + exit 0, else
# `FAIL: m034-p02 auto-policies — <reason>` + exit 1.
#
# Bash 3.2 / POSIX-sh. set -u. Scratch under mktemp. No human, no network.

set -u

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SELF_DIR/../.." && pwd)"

WRITER="$REPO_ROOT/scripts/knowledge/write-decisions.sh"
READER="$REPO_ROOT/scripts/knowledge/read-decisions.sh"
SPINE="$REPO_ROOT/scripts/lifecycle/interactive-review.sh"

fail() {
  echo "FAIL: m034-p02 auto-policies — $1"
  exit 1
}

command -v jq >/dev/null 2>&1 || fail "jq not on PATH"
[ -f "$WRITER" ] || fail "write-decisions.sh missing at $WRITER"
[ -f "$READER" ] || fail "read-decisions.sh missing at $READER"
[ -f "$SPINE" ]  || fail "interactive-review.sh missing at $SPINE"

SCRATCH="$(mktemp -d 2>/dev/null || mktemp -d -t m034p02t03)"
[ -n "$SCRATCH" ] && [ -d "$SCRATCH" ] || fail "mktemp scratch dir failed"
trap 'rm -rf "$SCRATCH"' EXIT

# --- build a fixture packet (>=2 active decisions) ---------------------------
build_packet() {
  pkt="$1"
  jq -n '{
    decisions: [
      { id: "D-1", summary: "storage engine", picked_value: "postgres",
        rationale: "team familiarity", alternatives_considered: "sqlite",
        concrete_impact: "schema migrations", severity: "warn", type: "decision" },
      { id: "D-2", summary: "audit model", picked_value: "in-place update",
        rationale: "simpler writes", alternatives_considered: "event log",
        concrete_impact: "loses history", severity: "block", type: "decision" }
    ]
  }' | bash "$WRITER" --milestone=MTEST --artifact="src/store.ts" --out="$pkt" >/dev/null 2>&1
}

# Number of active decisions (shared across all three runs).
EXPECTED_N=2

# Compute a byte digest of a file (for the always-write invariant check).
digest() {
  if command -v shasum >/dev/null 2>&1; then
    shasum "$1" | awk '{print $1}'
  else
    cksum "$1" | awk '{print $1, $2}'
  fi
}

# =============================================================================
# RUN 1 — defer
# =============================================================================
RUN1="$SCRATCH/defer"
mkdir -p "$RUN1"
PKT1="$RUN1/MTEST-store-DECISIONS.md"
LOG1="$RUN1/events.jsonl"
build_packet "$PKT1" || fail "write-decisions.sh failed to build packet (defer)"
[ -f "$PKT1" ] || fail "packet not created (defer)"

PKT1_DIGEST_BEFORE="$(digest "$PKT1")"

REVIEW1="${PKT1%-DECISIONS.md}-REVIEW.md"
CONTINUE1="$RUN1/store-gate-CONTINUE.md"
QUESTIONS1="$RUN1/store-gate-QUESTIONS.md"

set +e
ORCH_HEADLESS=1 ORCH_EVENT_LOG="$LOG1" bash "$SPINE" \
  --milestone=MTEST --phase=P02 --gate-id=store-gate \
  --packet="$PKT1" --policy=defer >/dev/null 2>&1
rc1=$?
set -e 2>/dev/null || true
[ "$rc1" = "0" ] || fail "defer expected exit 0, got '$rc1'"

[ -f "$CONTINUE1" ] || fail "defer did not write CONTINUE file at $CONTINUE1"
[ -f "$QUESTIONS1" ] || fail "defer did not write QUESTIONS file at $QUESTIONS1"

# All five PC-5 required keys present in the continue-file.
for key in milestone_id phase_id gate_id last_review_md_block_index declared_policy; do
  grep -q "^${key}:" "$CONTINUE1" || fail "defer CONTINUE missing PC-5 key '$key'"
done
grep -q '^type: pending-review-continue$' "$CONTINUE1" || fail "defer CONTINUE missing type pending-review-continue"
grep -q '^declared_policy: "defer"$' "$CONTINUE1" || fail "defer CONTINUE declared_policy not 'defer'"

# A pending_review line in the scratch log.
[ -f "$LOG1" ] || fail "defer did not write event log"
grep -q '"record_type":"pending_review"' "$LOG1" || fail "defer log missing pending_review event"

# QUESTIONS.md lists each active id.
grep -q 'D-1' "$QUESTIONS1" || fail "defer QUESTIONS missing D-1"
grep -q 'D-2' "$QUESTIONS1" || fail "defer QUESTIONS missing D-2"

# Always-write invariant: the packet is byte-identical.
PKT1_DIGEST_AFTER="$(digest "$PKT1")"
[ "$PKT1_DIGEST_BEFORE" = "$PKT1_DIGEST_AFTER" ] || fail "defer mutated the *-DECISIONS.md (CON-5/SC-5)"

# =============================================================================
# RUN 2 — accept-with-audit
# =============================================================================
RUN2="$SCRATCH/accept"
mkdir -p "$RUN2"
PKT2="$RUN2/MTEST-store-DECISIONS.md"
LOG2="$RUN2/events.jsonl"
build_packet "$PKT2" || fail "write-decisions.sh failed to build packet (accept)"

PKT2_DIGEST_BEFORE="$(digest "$PKT2")"

REVIEW2="${PKT2%-DECISIONS.md}-REVIEW.md"
SIGNOFF2="${PKT2%-DECISIONS.md}-SIGNOFF.md"

set +e
ORCH_HEADLESS=1 ORCH_EVENT_LOG="$LOG2" bash "$SPINE" \
  --milestone=MTEST --phase=P02 --gate-id=store-gate \
  --packet="$PKT2" --policy=accept-with-audit >/dev/null 2>&1
rc2=$?
set -e 2>/dev/null || true
[ "$rc2" = "0" ] || fail "accept-with-audit expected exit 0, got '$rc2'"

[ -f "$REVIEW2" ] || fail "accept-with-audit did not write REVIEW.md"
[ -f "$SIGNOFF2" ] || fail "accept-with-audit did not write SIGNOFF.md"

# N REVIEW.md blocks.
review_blocks="$(grep -c '^## ' "$REVIEW2" || true)"
[ "$review_blocks" = "$EXPECTED_N" ] || fail "accept-with-audit expected $EXPECTED_N REVIEW blocks, got '$review_blocks'"

# N auto_accepted JSONL lines.
[ -f "$LOG2" ] || fail "accept-with-audit did not write event log"
auto_lines="$(grep -c '"record_type":"auto_accepted"' "$LOG2" || true)"
[ "$auto_lines" = "$EXPECTED_N" ] || fail "accept-with-audit expected $EXPECTED_N auto_accepted events, got '$auto_lines'"

# SIGNOFF populated.
approved_by="$(grep '^approved_by:' "$SIGNOFF2" | sed -E 's/^approved_by:[[:space:]]*//')"
case "$approved_by" in
  ""|null|'"null"') fail "accept-with-audit SIGNOFF approved_by not populated (got '$approved_by')" ;;
  *) : ;;
esac

# unreviewed-count must be 0 after accept-with-audit (every id reviewed).
unrev="$(bash "$READER" unreviewed-count "$PKT2")"
[ "$unrev" = "0" ] || fail "accept-with-audit left unreviewed-count '$unrev' (expected 0)"

# Always-write invariant.
PKT2_DIGEST_AFTER="$(digest "$PKT2")"
[ "$PKT2_DIGEST_BEFORE" = "$PKT2_DIGEST_AFTER" ] || fail "accept-with-audit mutated the *-DECISIONS.md (CON-5/SC-5)"

# =============================================================================
# RUN 3 — refuse-entry
# =============================================================================
RUN3="$SCRATCH/refuse"
mkdir -p "$RUN3"
PKT3="$RUN3/MTEST-store-DECISIONS.md"
LOG3="$RUN3/events.jsonl"
build_packet "$PKT3" || fail "write-decisions.sh failed to build packet (refuse)"

PKT3_DIGEST_BEFORE="$(digest "$PKT3")"

REVIEW3="${PKT3%-DECISIONS.md}-REVIEW.md"
SIGNOFF3="${PKT3%-DECISIONS.md}-SIGNOFF.md"

set +e
ORCH_HEADLESS=1 ORCH_EVENT_LOG="$LOG3" bash "$SPINE" \
  --milestone=MTEST --phase=P02 --gate-id=store-gate \
  --packet="$PKT3" --policy=refuse-entry >/dev/null 2>&1
rc3=$?
set -e 2>/dev/null || true
[ "$rc3" != "0" ] || fail "refuse-entry expected non-zero exit, got 0"

[ -f "$LOG3" ] || fail "refuse-entry did not write event log"
grep -q '"record_type":"refused_entry"' "$LOG3" || fail "refuse-entry log missing refused_entry event"

[ ! -f "$REVIEW3" ] || fail "refuse-entry wrote REVIEW.md (must not)"
[ ! -f "$SIGNOFF3" ] || fail "refuse-entry wrote SIGNOFF.md (must not)"

# Always-write invariant.
PKT3_DIGEST_AFTER="$(digest "$PKT3")"
[ "$PKT3_DIGEST_BEFORE" = "$PKT3_DIGEST_AFTER" ] || fail "refuse-entry mutated the *-DECISIONS.md (CON-5/SC-5)"

echo "PASS: m034-p02 auto-policies"
exit 0
