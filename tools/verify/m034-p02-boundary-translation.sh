#!/usr/bin/env bash
# tools/verify/m034-p02-boundary-translation.sh — M034 P02 T05 verifier (FR-13, SC-8).
#
# Exercises the boundary_translation packet type end-to-end:
#   1. emit-boundary-translation.sh with the four bridge fields produces a
#      `type: boundary_translation` entry from which all four field values are
#      recoverable (grep-able) in the emitted *-DECISIONS.md (SC-8).
#   2. interactive-review.sh --test-responses with an `na` action for the BT
#      entry records `gate_kind: confirm-the-bridge`,
#      `acknowledged_not_applicable: true`, and `reviewed: BT-1` in REVIEW.md.
#   3. The producer errors (exit non-zero) when --verify-mechanism is omitted.
#
# Prints `PASS: m034-p02 boundary-translation` + exit 0 on success, else
# `FAIL: m034-p02 boundary-translation — <reason>` + exit 1.
#
# Bash 3.2 / POSIX-sh. set -u. Scratch under mktemp. No human, no network.

set -u

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SELF_DIR/../.." && pwd)"

EMITTER="$REPO_ROOT/scripts/knowledge/emit-boundary-translation.sh"
SPINE="$REPO_ROOT/scripts/lifecycle/interactive-review.sh"

fail() {
  echo "FAIL: m034-p02 boundary-translation — $1"
  exit 1
}

command -v jq >/dev/null 2>&1 || fail "jq not on PATH"
[ -f "$EMITTER" ] || fail "emit-boundary-translation.sh missing at $EMITTER"
[ -f "$SPINE" ] || fail "interactive-review.sh missing at $SPINE"

SCRATCH="$(mktemp -d 2>/dev/null || mktemp -d -t m034p02t05)"
[ -n "$SCRATCH" ] && [ -d "$SCRATCH" ] || fail "mktemp scratch dir failed"
trap 'rm -rf "$SCRATCH"' EXIT

SOURCE_VOCAB="surface_acres"
TARGET_VOCAB="surface_area_acres"
TRANSFORM_SITE="models/lake.py:42"
VERIFY_MECHANISM="real-DB column-existence check"

PKT="$SCRATCH/MTEST-lake-DECISIONS.md"

# --- step 1: emit a boundary_translation entry -------------------------------
bash "$EMITTER" --milestone=MTEST --artifact="models/lake.py" --out="$PKT" \
  --id=BT-1 \
  --source-vocab="$SOURCE_VOCAB" --target-vocab="$TARGET_VOCAB" \
  --transform-site="$TRANSFORM_SITE" --verify-mechanism="$VERIFY_MECHANISM" \
  >/dev/null 2>&1 \
  || fail "emit-boundary-translation.sh exited non-zero"

[ -f "$PKT" ] || fail "packet not created"

# --- assert: entry type is boundary_translation ------------------------------
grep -qF -e "- **type**: boundary_translation" "$PKT" \
  || fail "packet entry type is not boundary_translation"

# --- assert: all four bridge field values are recoverable (grep-able) --------
grep -qF -e "$SOURCE_VOCAB" "$PKT" \
  || fail "source_vocab '$SOURCE_VOCAB' not recoverable in packet"
grep -qF -e "$TARGET_VOCAB" "$PKT" \
  || fail "target_vocab '$TARGET_VOCAB' not recoverable in packet"
grep -qF -e "$TRANSFORM_SITE" "$PKT" \
  || fail "transform_site '$TRANSFORM_SITE' not recoverable in packet"
grep -qF -e "$VERIFY_MECHANISM" "$PKT" \
  || fail "verify_mechanism '$VERIFY_MECHANISM' not recoverable in packet"

# --- step 2: drive --test-responses with an `na` action for BT-1 -------------
FX="$SCRATCH/fixture.json"
NA_RATIONALE="heuristic false-positive: lake.py never touches the surface column"
jq -n --arg rat "$NA_RATIONALE" '
  [ { id: "BT-1", action: "na", rationale: $rat } ]
' > "$FX"

REVIEW="${PKT%-DECISIONS.md}-REVIEW.md"
SIGNOFF="${PKT%-DECISIONS.md}-SIGNOFF.md"

bash "$SPINE" --milestone=MTEST --phase=P02 --gate-id=lake-gate \
  --packet="$PKT" --test-responses="$FX" >/dev/null 2>&1 \
  || fail "interactive-review.sh exited non-zero (na walkthrough)"

[ -f "$REVIEW" ] || fail "REVIEW.md not written"

# --- assert: REVIEW block carries gate_kind / acknowledged / reviewed --------
grep -qF -e "- **gate_kind**: confirm-the-bridge" "$REVIEW" \
  || fail "REVIEW block missing gate_kind: confirm-the-bridge"
grep -qF -e "- **acknowledged_not_applicable**: true" "$REVIEW" \
  || fail "REVIEW block missing acknowledged_not_applicable: true"
grep -Eq "^reviewed: BT-1[[:space:]]*$" "$REVIEW" \
  || fail "REVIEW block missing 'reviewed: BT-1' marker"

# --- assert: the na block also records the fixture rationale -----------------
grep -qF -e "- **action**: na" "$REVIEW" \
  || fail "REVIEW block missing action: na"

# --- step 3: producer errors when --verify-mechanism is omitted --------------
PKT2="$SCRATCH/MTEST-lake2-DECISIONS.md"
set +e
bash "$EMITTER" --milestone=MTEST --artifact="models/lake.py" --out="$PKT2" \
  --id=BT-1 \
  --source-vocab="$SOURCE_VOCAB" --target-vocab="$TARGET_VOCAB" \
  --transform-site="$TRANSFORM_SITE" \
  >/dev/null 2>&1
rc=$?
set -e 2>/dev/null || true
[ "$rc" != "0" ] || fail "producer should error when --verify-mechanism omitted (got exit 0)"
[ ! -f "$PKT2" ] || fail "producer wrote a packet despite missing --verify-mechanism"

echo "PASS: m034-p02 boundary-translation"
exit 0
