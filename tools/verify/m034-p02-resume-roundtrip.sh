#!/usr/bin/env bash
# tools/verify/m034-p02-resume-roundtrip.sh — M034 P02 T04 verifier.
#
# Exercises the full PC-5 defer->resume round-trip of
# scripts/lifecycle/interactive-review.sh (SC-4 extended round-trip).
#
# Builds a fixture packet (>=3 active decisions) + a fixture response file
# covering all of them, then:
#
#   STEP 1 — interactive-review.sh --policy=defer under ORCH_HEADLESS=1 +
#            ORCH_EVENT_LOG=<scratch>. Asserts: exit 0, a <gate>-CONTINUE.md
#            with last_review_md_block_index: 0, SIGNOFF NOT yet populated.
#   STEP 2 — interactive-review.sh --resume=<continue-file>
#            --test-responses=<fixture>. Asserts: it appends blocks for the
#            remaining decisions (no duplicate ids), removes the continue-file,
#            populates SIGNOFF, drives read-decisions.sh unreviewed-count to 0,
#            and a `review_resumed` line is in the scratch log.
#
# Also asserts the mid-stream re-entry guarantee: a pre-seeded REVIEW.md block
# (one decision already answered) is NOT re-written on resume — re-entry skips
# the already-reviewed id and never double-writes a block.
#
# Prints `PASS: m034-p02 resume-roundtrip` + exit 0, else
# `FAIL: m034-p02 resume-roundtrip — <reason>` + exit 1.
#
# Bash 3.2 / POSIX-sh. set -u. Scratch under mktemp. No human, no network.

set -u

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SELF_DIR/../.." && pwd)"

WRITER="$REPO_ROOT/scripts/knowledge/write-decisions.sh"
READER="$REPO_ROOT/scripts/knowledge/read-decisions.sh"
SPINE="$REPO_ROOT/scripts/lifecycle/interactive-review.sh"

fail() {
  echo "FAIL: m034-p02 resume-roundtrip — $1"
  exit 1
}

command -v jq >/dev/null 2>&1 || fail "jq not on PATH"
[ -f "$WRITER" ] || fail "write-decisions.sh missing at $WRITER"
[ -f "$READER" ] || fail "read-decisions.sh missing at $READER"
[ -f "$SPINE" ]  || fail "interactive-review.sh missing at $SPINE"

SCRATCH="$(mktemp -d 2>/dev/null || mktemp -d -t m034p02t04)"
[ -n "$SCRATCH" ] && [ -d "$SCRATCH" ] || fail "mktemp scratch dir failed"
trap 'rm -rf "$SCRATCH"' EXIT

# --- build a fixture packet (>=3 active decisions) ---------------------------
build_packet() {
  pkt="$1"
  jq -n '{
    decisions: [
      { id: "D-1", summary: "storage engine", picked_value: "postgres",
        rationale: "team familiarity", alternatives_considered: "sqlite",
        concrete_impact: "schema migrations", severity: "warn", type: "decision" },
      { id: "D-2", summary: "audit model", picked_value: "in-place update",
        rationale: "simpler writes", alternatives_considered: "event log",
        concrete_impact: "loses history", severity: "block", type: "decision" },
      { id: "D-3", summary: "cache layer", picked_value: "none",
        rationale: "premature", alternatives_considered: "redis",
        concrete_impact: "latency under load", severity: "warn", type: "decision" }
    ]
  }' | bash "$WRITER" --milestone=MTEST --artifact="src/store.ts" --out="$pkt" >/dev/null 2>&1
}

# --- fixture: a response for every active id ---------------------------------
write_fixture() {
  fx="$1"
  jq -n '
    [
      { id: "D-1", action: "accept", rationale: "good default" },
      { id: "D-2", action: "override", value: "event-sourced ledger", rationale: "immutable audit trail" },
      { id: "D-3", action: "pushback", rationale: "revisit at scale" }
    ]
  ' > "$fx"
}

EXPECTED_N=3

# =============================================================================
# STEP 1 — defer (headless): write the continue-file, no SIGNOFF yet
# =============================================================================
RUN="$SCRATCH/gate"
mkdir -p "$RUN"
PKT="$RUN/MTEST-store-DECISIONS.md"
LOG="$RUN/events.jsonl"
FX="$RUN/fixture.json"

build_packet "$PKT" || fail "write-decisions.sh failed to build packet"
[ -f "$PKT" ] || fail "packet not created"
write_fixture "$FX"

REVIEW="${PKT%-DECISIONS.md}-REVIEW.md"
SIGNOFF="${PKT%-DECISIONS.md}-SIGNOFF.md"
CONTINUE="$RUN/store-gate-CONTINUE.md"

set +e
ORCH_HEADLESS=1 ORCH_EVENT_LOG="$LOG" bash "$SPINE" \
  --milestone=MTEST --phase=P02 --gate-id=store-gate \
  --packet="$PKT" --policy=defer >/dev/null 2>&1
rc=$?
set -e 2>/dev/null || true
[ "$rc" = "0" ] || fail "defer expected exit 0, got '$rc'"

[ -f "$CONTINUE" ] || fail "defer did not write CONTINUE file at $CONTINUE"

# last_review_md_block_index: 0 (no REVIEW blocks pre-existed).
idx_line="$(grep '^last_review_md_block_index:' "$CONTINUE" | sed -E 's/^last_review_md_block_index:[[:space:]]*//')"
[ "$idx_line" = "0" ] || fail "defer CONTINUE last_review_md_block_index expected 0, got '$idx_line'"

# SIGNOFF must NOT be populated yet (defer never signs off).
[ ! -f "$SIGNOFF" ] || fail "defer wrote SIGNOFF.md (must not — review still pending)"

# unreviewed-count is the full set before resume.
unrev_before="$(bash "$READER" unreviewed-count "$PKT")"
[ "$unrev_before" = "$EXPECTED_N" ] || fail "pre-resume unreviewed-count expected $EXPECTED_N, got '$unrev_before'"

# =============================================================================
# STEP 2 — resume: complete the remaining decisions from the fixture
# =============================================================================
set +e
ORCH_HEADLESS=1 ORCH_EVENT_LOG="$LOG" bash "$SPINE" \
  --resume="$CONTINUE" --test-responses="$FX" >/dev/null 2>&1
rc=$?
set -e 2>/dev/null || true
[ "$rc" = "0" ] || fail "resume expected exit 0, got '$rc'"

# The consumed continue-file is removed.
[ ! -f "$CONTINUE" ] || fail "resume did not remove the consumed continue-file"

# REVIEW.md now carries one block per active id (no duplicates).
[ -f "$REVIEW" ] || fail "resume did not write REVIEW.md"
review_blocks="$(grep -c '^## ' "$REVIEW" || true)"
[ "$review_blocks" = "$EXPECTED_N" ] || fail "resume expected $EXPECTED_N REVIEW blocks, got '$review_blocks'"

# No duplicate ids in the REVIEW block headings.
review_ids="$(grep '^## ' "$REVIEW" | sed -E 's/^## ([^ ]+) .*/\1/' | sort)"
review_ids_uniq="$(printf '%s\n' "$review_ids" | sort -u)"
[ "$review_ids" = "$review_ids_uniq" ] || fail "resume wrote duplicate REVIEW blocks: [$review_ids]"

# SIGNOFF is populated.
[ -f "$SIGNOFF" ] || fail "resume did not write SIGNOFF.md"
approved_by="$(grep '^approved_by:' "$SIGNOFF" | sed -E 's/^approved_by:[[:space:]]*//')"
case "$approved_by" in
  ""|null|'"null"'|'""') fail "resume SIGNOFF approved_by not populated (got '$approved_by')" ;;
  *) : ;;
esac

# unreviewed-count driven to 0.
unrev_after="$(bash "$READER" unreviewed-count "$PKT")"
[ "$unrev_after" = "0" ] || fail "post-resume unreviewed-count expected 0, got '$unrev_after'"

# A review_resumed line in the scratch log.
[ -f "$LOG" ] || fail "resume did not write event log"
grep -q '"record_type":"review_resumed"' "$LOG" || fail "resume log missing review_resumed event"

# =============================================================================
# STEP 3 — mid-stream re-entry: a pre-seeded REVIEW block is NOT re-written
# =============================================================================
RUN2="$SCRATCH/midstream"
mkdir -p "$RUN2"
PKT2="$RUN2/MTEST-store-DECISIONS.md"
LOG2="$RUN2/events.jsonl"
FX2="$RUN2/fixture.json"

build_packet "$PKT2" || fail "write-decisions.sh failed to build packet (midstream)"
write_fixture "$FX2"

REVIEW2="${PKT2%-DECISIONS.md}-REVIEW.md"
SIGNOFF2="${PKT2%-DECISIONS.md}-SIGNOFF.md"

# Pre-seed a mid-stream partial answer: a defer first (writes CONTINUE, no
# REVIEW), then hand-seed REVIEW.md with one D-1 block in the exact append-only
# shape, bump the continue-file index to 1, and resume. The resume must skip the
# already-reviewed D-1 and complete only D-2/D-3.
CONTINUE2="$RUN2/store-gate-CONTINUE.md"
set +e
ORCH_HEADLESS=1 ORCH_EVENT_LOG="$LOG2" bash "$SPINE" \
  --milestone=MTEST --phase=P02 --gate-id=store-gate \
  --packet="$PKT2" --policy=defer >/dev/null 2>&1
rc=$?
set -e 2>/dev/null || true
[ "$rc" = "0" ] || fail "midstream defer expected exit 0, got '$rc'"
[ -f "$CONTINUE2" ] || fail "midstream defer did not write CONTINUE"

# Hand-seed REVIEW.md with a header + one D-1 block (mid-stream partial answer).
{
  printf -- '---\n'
  printf 'schema_version: "1.0"\n'
  printf 'type: review-log\n'
  printf 'milestone: "MTEST"\n'
  printf 'phase: "P02"\n'
  printf 'gate_id: "store-gate"\n'
  printf 'packet: "MTEST-store-DECISIONS.md"\n'
  printf -- '---\n'
  printf '\n'
  printf '# Review Log — store-gate\n'
  printf '\n'
  printf '## D-1 — review block 1\n'
  printf -- '- **id**: D-1\n'
  printf -- '- **action**: accept\n'
  printf -- '- **reviewed_at**: 2026-01-01T00:00:00Z\n'
  printf -- '- **rationale**: pre-seeded partial answer\n'
  printf 'reviewed: D-1\n'
} > "$REVIEW2"

# Bump the continue-file's last_review_md_block_index to 1 (one block on disk).
sed -E 's/^last_review_md_block_index:.*/last_review_md_block_index: 1/' "$CONTINUE2" > "$CONTINUE2.tmp"
mv -f "$CONTINUE2.tmp" "$CONTINUE2"

# Capture the pre-seeded D-1 block body (sans timestamp) to prove it is untouched.
d1_before="$(awk '/^## D-1 /{f=1} /^## D-2 /{f=0} f' "$REVIEW2" | grep -v '^- \*\*reviewed_at\*\*: ')"

set +e
ORCH_HEADLESS=1 ORCH_EVENT_LOG="$LOG2" bash "$SPINE" \
  --resume="$CONTINUE2" --test-responses="$FX2" >/dev/null 2>&1
rc=$?
set -e 2>/dev/null || true
[ "$rc" = "0" ] || fail "midstream resume expected exit 0, got '$rc'"

# Exactly 3 blocks total (the pre-seeded D-1 + D-2 + D-3), no D-1 duplicate.
mid_blocks="$(grep -c '^## ' "$REVIEW2" || true)"
[ "$mid_blocks" = "$EXPECTED_N" ] || fail "midstream resume expected $EXPECTED_N total blocks, got '$mid_blocks'"

d1_count="$(grep -c '^## D-1 ' "$REVIEW2" || true)"
[ "$d1_count" = "1" ] || fail "midstream resume double-wrote D-1 ($d1_count blocks — must stay 1)"

# The pre-seeded D-1 block body is byte-identical (append-only, not rewritten).
d1_after="$(awk '/^## D-1 /{f=1} /^## D-2 /{f=0} f' "$REVIEW2" | grep -v '^- \*\*reviewed_at\*\*: ')"
[ "$d1_before" = "$d1_after" ] || fail "midstream resume rewrote the pre-seeded D-1 block (must be append-only)"

# unreviewed-count to 0, SIGNOFF populated, continue-file removed.
unrev2="$(bash "$READER" unreviewed-count "$PKT2")"
[ "$unrev2" = "0" ] || fail "midstream post-resume unreviewed-count expected 0, got '$unrev2'"
[ -f "$SIGNOFF2" ] || fail "midstream resume did not write SIGNOFF.md"
[ ! -f "$CONTINUE2" ] || fail "midstream resume did not remove the consumed continue-file"

echo "PASS: m034-p02 resume-roundtrip"
exit 0
