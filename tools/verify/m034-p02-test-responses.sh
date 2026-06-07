#!/usr/bin/env bash
# tools/verify/m034-p02-test-responses.sh — M034 P02 T02 verifier.
#
# Exercises the fully-deterministic --test-responses path of
# scripts/lifecycle/interactive-review.sh (FR-5 / SC-3 / PC-3).
#
# Builds a fixture packet via write-decisions.sh (>=3 decisions, one whose
# fixture action is `override` carrying a multi-word value + rationale), drives
# interactive-review.sh --test-responses, and asserts:
#   1. One REVIEW.md block per active decision id, in packet order.
#   2. The override block contains the exact value + rationale strings verbatim.
#   3. SIGNOFF.md has approved_by non-null and terminal_review_block == block count.
#   4. read-decisions.sh unreviewed-count returns 0 after the run (SC-2 zero-after).
#   5. A second identical run against a fresh scratch dir produces byte-identical
#      REVIEW block bodies (determinism, modulo the timestamp line).
#   6. A missing packet (non-resume) fails closed (exit 3).
#
# Prints `PASS: m034-p02 test-responses` + exit 0 on success, else
# `FAIL: m034-p02 test-responses — <reason>` + exit 1.
#
# Bash 3.2 / POSIX-sh. set -u. Scratch under mktemp. No human, no network.

set -u

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SELF_DIR/../.." && pwd)"

WRITER="$REPO_ROOT/scripts/knowledge/write-decisions.sh"
READER="$REPO_ROOT/scripts/knowledge/read-decisions.sh"
SPINE="$REPO_ROOT/scripts/lifecycle/interactive-review.sh"

fail() {
  echo "FAIL: m034-p02 test-responses — $1"
  exit 1
}

command -v jq >/dev/null 2>&1 || fail "jq not on PATH"
[ -f "$WRITER" ] || fail "write-decisions.sh missing at $WRITER"
[ -f "$READER" ] || fail "read-decisions.sh missing at $READER"
[ -f "$SPINE" ] || fail "interactive-review.sh missing at $SPINE"

SCRATCH="$(mktemp -d 2>/dev/null || mktemp -d -t m034p02t02)"
[ -n "$SCRATCH" ] && [ -d "$SCRATCH" ] || fail "mktemp scratch dir failed"
trap 'rm -rf "$SCRATCH"' EXIT

OVERRIDE_VALUE="event-sourced append-only ledger"
OVERRIDE_RATIONALE="operator prefers an immutable audit trail over in-place mutation"

# --- build a fixture packet (>=3 decisions) ----------------------------------
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

# --- fixture: D-2 override (multi-word value + rationale), D-3 pushback -------
write_fixture() {
  fx="$1"
  jq -n --arg ov "$OVERRIDE_VALUE" --arg orat "$OVERRIDE_RATIONALE" '
    [
      { id: "D-2", action: "override", value: $ov, rationale: $orat },
      { id: "D-3", action: "pushback", rationale: "revisit at scale" }
    ]
  ' > "$fx"
}

# --- run 1 -------------------------------------------------------------------
RUN1="$SCRATCH/run1"
mkdir -p "$RUN1"
PKT1="$RUN1/MTEST-store-DECISIONS.md"
FX1="$RUN1/fixture.json"
build_packet "$PKT1" || fail "write-decisions.sh failed to build packet (run1)"
[ -f "$PKT1" ] || fail "packet not created (run1)"
write_fixture "$FX1"

REVIEW1="${PKT1%-DECISIONS.md}-REVIEW.md"
SIGNOFF1="${PKT1%-DECISIONS.md}-SIGNOFF.md"

out1="$(bash "$SPINE" --milestone=MTEST --phase=P02 --gate-id=store-gate \
  --packet="$PKT1" --test-responses="$FX1" 2>&1)" \
  || fail "interactive-review.sh exited non-zero (run1): $out1"

[ -f "$REVIEW1" ] || fail "REVIEW.md not written (run1)"
[ -f "$SIGNOFF1" ] || fail "SIGNOFF.md not written (run1)"

# --- assert 1: one REVIEW block per active id, in packet order ---------------
active_ids="$(bash "$READER" active-ids "$PKT1")"
active_count="$(printf '%s\n' "$active_ids" | grep -c . || true)"
[ "$active_count" = "3" ] || fail "expected 3 active ids, got '$active_count'"

block_count="$(grep -c '^## ' "$REVIEW1" || true)"
[ "$block_count" = "3" ] || fail "expected 3 REVIEW blocks, got '$block_count'"

# block headings carry the ids in packet order
review_block_ids="$(grep '^## ' "$REVIEW1" | sed -E 's/^## ([^ ]+) .*/\1/')"
expected_order="$(printf '%s\n' "$active_ids")"
if [ "$review_block_ids" != "$expected_order" ]; then
  fail "REVIEW block id order mismatch: got [$review_block_ids] expected [$expected_order]"
fi

# the `- **id**:` bullet order must also match packet order
review_id_bullets="$(grep '^- \*\*id\*\*: ' "$REVIEW1" | sed -E 's/^- \*\*id\*\*: //')"
if [ "$review_id_bullets" != "$expected_order" ]; then
  fail "REVIEW id-bullet order mismatch: got [$review_id_bullets] expected [$expected_order]"
fi

# --- assert 2: override value + rationale verbatim in the D-2 block ----------
# Extract the D-2 block region.
d2_block="$(awk '/^## D-2 /{f=1} /^## D-3 /{f=0} f' "$REVIEW1")"
printf '%s\n' "$d2_block" | grep -q -e "^- \*\*action\*\*: override\$" \
  || fail "D-2 block missing action=override"
printf '%s\n' "$d2_block" | grep -qF -e "- **override_value**: $OVERRIDE_VALUE" \
  || fail "D-2 block missing verbatim override_value '$OVERRIDE_VALUE'"
printf '%s\n' "$d2_block" | grep -qF -e "- **rationale**: $OVERRIDE_RATIONALE" \
  || fail "D-2 block missing verbatim rationale '$OVERRIDE_RATIONALE'"

# --- assert 3: SIGNOFF populated --------------------------------------------
approved_by="$(grep '^approved_by:' "$SIGNOFF1" | sed -E 's/^approved_by:[[:space:]]*//')"
case "$approved_by" in
  ""|null|'"null"') fail "SIGNOFF approved_by not populated (got '$approved_by')" ;;
  *) : ;;
esac
term_block="$(grep '^terminal_review_block:' "$SIGNOFF1" | sed -E 's/^terminal_review_block:[[:space:]]*//')"
[ "$term_block" = "3" ] || fail "SIGNOFF terminal_review_block expected 3, got '$term_block'"

# --- assert 4: unreviewed-count == 0 after the run --------------------------
unrev="$(bash "$READER" unreviewed-count "$PKT1")"
[ "$unrev" = "0" ] || fail "unreviewed-count expected 0 after review, got '$unrev'"

# --- assert 5: determinism across a fresh run (modulo timestamp line) --------
RUN2="$SCRATCH/run2"
mkdir -p "$RUN2"
PKT2="$RUN2/MTEST-store-DECISIONS.md"
FX2="$RUN2/fixture.json"
build_packet "$PKT2" || fail "write-decisions.sh failed to build packet (run2)"
write_fixture "$FX2"
REVIEW2="${PKT2%-DECISIONS.md}-REVIEW.md"

bash "$SPINE" --milestone=MTEST --phase=P02 --gate-id=store-gate \
  --packet="$PKT2" --test-responses="$FX2" >/dev/null 2>&1 \
  || fail "interactive-review.sh exited non-zero (run2)"

# Strip the volatile reviewed_at lines from both REVIEW files and compare.
norm1="$(grep -v '^- \*\*reviewed_at\*\*: ' "$REVIEW1")"
norm2="$(grep -v '^- \*\*reviewed_at\*\*: ' "$REVIEW2")"
if [ "$norm1" != "$norm2" ]; then
  fail "REVIEW block bodies not deterministic across runs (modulo timestamp)"
fi

# --- assert 6: missing packet (non-resume) fails closed (exit 3) ------------
set +e
bash "$SPINE" --milestone=MTEST --phase=P02 --gate-id=ghost \
  --packet="$SCRATCH/does-not-exist-DECISIONS.md" --test-responses="$FX1" >/dev/null 2>&1
rc=$?
set -e 2>/dev/null || true
[ "$rc" = "3" ] || fail "missing packet expected exit 3 (fail closed), got '$rc'"

echo "PASS: m034-p02 test-responses"
exit 0
