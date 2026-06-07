#!/usr/bin/env bash
# tools/verify/m034-p01-surfacing.sh — M034 P01 T04 verifier (FR-4 + SC-2).
#
# Exercises the unreviewed-decision surfacing chain:
#   - read-decisions.sh active-count / unreviewed-count / unreviewed-warn-count
#     / dir-unreviewed-count
#   - the sibling *-REVIEW.md review mechanism (P02's gate driver) dropping the
#     unreviewed count by 1
#   - check-decisions.sh DOCTOR: status=warn at/above threshold, ok below, skip
#     when no packets exist
#   - render-status-json.sh emitting the additive `unreviewed_decisions` key
#   - run-doctor.sh carrying the advisory "Unreviewed Decisions" run_check wiring
#
# Bash 3.2 / POSIX-sh. Read-only against the repo; all scratch under a tmp dir.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
READER="$REPO_ROOT/scripts/knowledge/read-decisions.sh"
WRITER="$REPO_ROOT/scripts/knowledge/write-decisions.sh"
CHECKER="$REPO_ROOT/scripts/diagnostics/check-decisions.sh"
RENDERER="$REPO_ROOT/scripts/diagnostics/render-status-json.sh"
DOCTOR="$REPO_ROOT/scripts/diagnostics/run-doctor.sh"

# shellcheck source=scripts/knowledge/lib/decisions-constants.sh
. "$REPO_ROOT/scripts/knowledge/lib/decisions-constants.sh"
THRESHOLD="$DECISIONS_WARN_FINDING_THRESHOLD"

fail() {
  echo "FAIL: m034-p01 surfacing — $1"
  exit 1
}

# --- Scratch root under the repo's tmp/ (stays inside the working tree). -----
SCRATCH="$REPO_ROOT/tmp/m034-p01-surfacing.$$"
mkdir -p "$SCRATCH" || fail "could not create scratch dir"
trap 'rm -rf "$SCRATCH"' EXIT

# Build a fixture milestone tree: <root>/milestones/MTEST/phases/P01/
MROOT="$SCRATCH/.orchestrator"
PHASE_DIR="$MROOT/milestones/MTEST/phases/P01"
mkdir -p "$PHASE_DIR" || fail "could not create phase dir"
PACKET="$PHASE_DIR/MTEST-P01-DECISIONS.md"

# --- Build a packet with >=3 active warn-severity entries via the T02 writer.
ENTRIES_JSON='{"decisions":[
  {"id":"D-1","summary":"warn one","picked_value":"v1","rationale":"r1","alternatives_considered":"a1","concrete_impact":"i1","severity":"warn","type":"decision"},
  {"id":"D-2","summary":"warn two","picked_value":"v2","rationale":"r2","alternatives_considered":"a2","concrete_impact":"i2","severity":"warn","type":"decision"},
  {"id":"D-3","summary":"warn three","picked_value":"v3","rationale":"r3","alternatives_considered":"a3","concrete_impact":"i3","severity":"warn","type":"decision"},
  {"id":"D-4","summary":"a block one","picked_value":"v4","rationale":"r4","alternatives_considered":"a4","concrete_impact":"i4","severity":"block","type":"decision"}
]}'

printf '%s' "$ENTRIES_JSON" | bash "$WRITER" --milestone=MTEST --artifact="phases/P01/plan.md" --out="$PACKET" >/dev/null 2>&1 \
  || fail "write-decisions.sh did not produce the fixture packet"
[ -f "$PACKET" ] || fail "fixture packet not on disk at $PACKET"

# --- active-count: 4 active (none superseded). ------------------------------
active=$(bash "$READER" active-count "$PACKET")
[ "$active" = "4" ] || fail "active-count expected 4, got '$active'"

# --- unreviewed-count: all active, no REVIEW.md -> 4. -----------------------
unrev=$(bash "$READER" unreviewed-count "$PACKET")
[ "$unrev" = "4" ] || fail "unreviewed-count expected 4 (no REVIEW.md), got '$unrev'"

# --- unreviewed-warn-count: 3 warn entries, all unreviewed -> 3. ------------
unrev_warn=$(bash "$READER" unreviewed-warn-count "$PACKET")
[ "$unrev_warn" = "3" ] || fail "unreviewed-warn-count expected 3, got '$unrev_warn'"

# --- Adding a sibling *-REVIEW.md marking one id reviewed drops count by 1. --
REVIEW="$PHASE_DIR/MTEST-P01-REVIEW.md"
{
  printf '# Review — MTEST P01\n'
  printf '\n'
  printf 'reviewed: D-1\n'
} > "$REVIEW"

unrev_after=$(bash "$READER" unreviewed-count "$PACKET")
[ "$unrev_after" = "3" ] || fail "unreviewed-count after one review expected 3, got '$unrev_after'"

# A reviewed warn id should also drop the warn count by 1.
unrev_warn_after=$(bash "$READER" unreviewed-warn-count "$PACKET")
[ "$unrev_warn_after" = "2" ] || fail "unreviewed-warn-count after reviewing D-1 expected 2, got '$unrev_warn_after'"

# --- dir-unreviewed-count: sum over the phase dir (1 packet, 3 unreviewed). --
dir_count=$(bash "$READER" dir-unreviewed-count "$MROOT/milestones/MTEST")
[ "$dir_count" = "3" ] || fail "dir-unreviewed-count expected 3, got '$dir_count'"

# --- check-decisions.sh: status=warn while >= threshold unreviewed warn. -----
# Remove the REVIEW.md so all 3 warn entries are unreviewed again (>= threshold=3).
rm -f "$REVIEW"
doctor_out=$(bash "$CHECKER" --root "$SCRATCH" 2>&1)
echo "$doctor_out" | grep -q "DOCTOR: status=warn check=decisions" \
  || fail "check-decisions.sh did not emit status=warn at/above threshold ($THRESHOLD); got: $doctor_out"

# --- check-decisions.sh: status=ok when below threshold. --------------------
# Review two warn ids so unreviewed warn count = 1 (< threshold=3).
{
  printf '# Review\n'
  printf 'reviewed: D-1\n'
  printf 'reviewed: D-2\n'
} > "$REVIEW"
doctor_ok=$(bash "$CHECKER" --root "$SCRATCH" 2>&1)
echo "$doctor_ok" | grep -q "DOCTOR: status=ok check=decisions" \
  || fail "check-decisions.sh did not emit status=ok below threshold; got: $doctor_ok"

# --- check-decisions.sh: status=skip when no packets exist. -----------------
EMPTY_ROOT="$SCRATCH/empty"
mkdir -p "$EMPTY_ROOT/.orchestrator/milestones"
doctor_skip=$(bash "$CHECKER" --root "$EMPTY_ROOT" 2>&1)
echo "$doctor_skip" | grep -q "DOCTOR: status=skip check=decisions" \
  || fail "check-decisions.sh did not emit status=skip with no packets; got: $doctor_skip"

# --- render-status-json.sh: output carries the unreviewed_decisions key. -----
render_out=$(bash "$RENDERER" --milestone M034 2>&1)
echo "$render_out" | grep -q "unreviewed_decisions" \
  || fail "render-status-json.sh output is missing the unreviewed_decisions key"
# It must still be valid JSON.
echo "$render_out" | jq -e . >/dev/null 2>&1 \
  || fail "render-status-json.sh output is not valid JSON"

# --- run-doctor.sh: source carries the advisory wiring. ---------------------
grep -q "Unreviewed Decisions" "$DOCTOR" \
  || fail "run-doctor.sh is missing the Unreviewed Decisions run_check wiring"

echo "PASS: m034-p01 surfacing"
exit 0
