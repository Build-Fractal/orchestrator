#!/usr/bin/env bash
# scripts/verify/m018-p06-tier3-helper-shape.sh — phase-truth verifier:
# "The `_bc_apply_tier3` helper exists in `scripts/dispatch/build-context.sh`
# and routes summarization through `dispatch-interface.sh` with
# `templates/compression-tier3-prompt.md`. Six `kf_get_tier3_*` accessors
# exist in `scripts/lib/knowledge-filter.sh`."
#
# AD-19 single-script-file shape, AP-009 compliant, bash 3.2 (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

BC="$REPO_ROOT/scripts/dispatch/build-context.sh"
KF="$REPO_ROOT/scripts/lib/knowledge-filter.sh"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s\n' "$1" >&2; }

for p in "$BC" "$KF"; do
  if [ ! -f "$p" ]; then
    fail "prerequisite missing: $p"
    exit 1
  fi
done

# --- Assertion 1: _bc_apply_tier3 exists in build-context.sh.
if grep -q '^_bc_apply_tier3()' "$BC"; then
  pass "_bc_apply_tier3 helper defined in build-context.sh"
else
  fail "_bc_apply_tier3 helper missing from build-context.sh"
fi

# --- Assertion 2: helper body references dispatch-interface.sh and
# compression-tier3-prompt.md. Extract the function body via awk and grep
# for the references inside.
TMPDIR_E="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_E"' EXIT INT TERM
BODY="$TMPDIR_E/tier3-body.sh"
awk '
  /^_bc_apply_tier3\(\) \{/ { in_fn=1 }
  in_fn { print }
  in_fn && /^\}$/ { in_fn=0 }
' "$BC" > "$BODY"

if [ ! -s "$BODY" ]; then
  fail "could not extract _bc_apply_tier3 body from build-context.sh"
else
  pass "extracted _bc_apply_tier3 body"
fi

if grep -q 'dispatch-interface.sh' "$BODY"; then
  pass "_bc_apply_tier3 references dispatch-interface.sh"
else
  fail "_bc_apply_tier3 does not reference dispatch-interface.sh"
fi

if grep -q 'compression-tier3-prompt.md' "$BODY"; then
  pass "_bc_apply_tier3 references compression-tier3-prompt.md"
else
  fail "_bc_apply_tier3 does not reference compression-tier3-prompt.md"
fi

# --- Assertion 3: pipeline wiring tail invokes _bc_apply_tier3 between
# _bc_apply_tier2 and _bc_emit_payload_breakdown.
WIRING="$(awk '
  /_bc_apply_tier2 "\$PAYLOAD_CAPTURE"/   { found_t2=NR }
  /_bc_apply_tier3 "\$PAYLOAD_CAPTURE"/   { found_t3=NR }
  /_bc_emit_payload_breakdown "\$PAYLOAD_CAPTURE"/ { found_emit=NR }
  END {
    if (found_t2 > 0 && found_t3 > found_t2 && found_emit > found_t3) {
      print "ok"
    } else {
      printf "t2=%d t3=%d emit=%d", found_t2, found_t3, found_emit
    }
  }
' "$BC")"
if [ "$WIRING" = "ok" ]; then
  pass "wiring: _bc_apply_tier2 -> _bc_apply_tier3 -> _bc_emit_payload_breakdown"
else
  fail "wiring out of order: $WIRING"
fi

# --- Assertion 4: six kf_get_tier3_* accessors in knowledge-filter.sh.
EXPECTED_ACCESSORS="enabled intensity_floor section_budget_tokens originals_dir output_max_ratio density_floor"
for key in $EXPECTED_ACCESSORS; do
  if grep -q "^kf_get_tier3_${key}()" "$KF"; then
    pass "kf_get_tier3_${key}() defined in knowledge-filter.sh"
  else
    fail "kf_get_tier3_${key}() missing from knowledge-filter.sh"
  fi
done

# --- Assertion 5: bash -n syntax checks.
if bash -n "$BC" 2>/dev/null; then
  pass "bash -n build-context.sh exits 0"
else
  fail "bash -n build-context.sh syntax errors"
fi
if bash -n "$KF" 2>/dev/null; then
  pass "bash -n knowledge-filter.sh exits 0"
else
  fail "bash -n knowledge-filter.sh syntax errors"
fi

if [ "$FAIL_COUNT" -eq 0 ]; then
  printf 'PASS: m018-p06-tier3-helper-shape (%d assertions)\n' "$PASS_COUNT"
  exit 0
fi
printf 'FAIL: m018-p06-tier3-helper-shape (%d failed of %d)\n' "$FAIL_COUNT" "$((PASS_COUNT + FAIL_COUNT))" >&2
exit 1
