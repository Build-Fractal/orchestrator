#!/usr/bin/env bash
# tools/verify/m036-p03-tier-2-pass-advisories-shape.sh
#
# Asserts the C1-B paper-cut shape: on a Tier 2 PASS, the gate helper
# copies the conversus deliberation synthesis (summary/final.md) to
# <log_dir>/<cite_id>.advisories.md, and extract-reference.sh exposes
# the advisories file in chunk frontmatter as tier_2_advisories:.
#
# Three checks:
#   1. The new _t2g_copy_advisories helper exists in extract-tier-2-gate.sh
#      and is wired from extract_tier_2_promote_or_retain on the PASS
#      branch.
#   2. extract-reference.sh emits tier_2_advisories: when the
#      <log_dir>/<cite_id>.advisories.md file exists after promotion.
#   3. Behavioral: invoking _t2g_copy_advisories with a synthetic
#      gate-result.md whose conversus_output_dir frontmatter points at
#      a directory containing summary/final.md results in the advisories
#      file being copied to <log-dir>/<cite_id>.advisories.md.
#
# See .orchestrator/proposals/papercut-m036a-p03-smoke-pass-with-concerns.md
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.

set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
GATE_LIB="$ROOT/scripts/knowledge/lib/extract-tier-2-gate.sh"
EXTRACT_DRV="$ROOT/scripts/knowledge/extract-reference.sh"
fail=0

checkpat() {
  local file="$1"
  local pat="$2"
  local label="$3"
  if grep -qF -e "$pat" "$file"; then
    echo "PASS: $label"
  else
    echo "FAIL: $label (pattern not found: $pat in $(basename "$file"))"
    fail=$((fail + 1))
  fi
}

# --- 1. helper present + wired ---
if [ -f "$GATE_LIB" ]; then
  checkpat "$GATE_LIB" "_t2g_copy_advisories()" "_t2g_copy_advisories function defined"
  checkpat "$GATE_LIB" "advisories.md" "advisories.md path referenced in gate helper"
  checkpat "$GATE_LIB" "_t2g_copy_advisories \"\$gate_out\" \"\$log_dir\" \"\$cite_id\"" "_t2g_copy_advisories invoked from PASS branch"
else
  echo "FAIL: $GATE_LIB missing"
  fail=$((fail + 1))
fi

# --- 2. driver emits tier_2_advisories: ---
if [ -f "$EXTRACT_DRV" ]; then
  checkpat "$EXTRACT_DRV" "tier_2_advisories:" "extract-reference.sh emits tier_2_advisories: frontmatter key"
  checkpat "$EXTRACT_DRV" '${cite_id}.advisories.md' "extract-reference.sh tests for advisories.md presence by cite_id"
else
  echo "FAIL: $EXTRACT_DRV missing"
  fail=$((fail + 1))
fi

# --- 3. behavioral: helper copies synthesis on a synthetic input ---
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p03-advisories.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/cod/summary"
printf 'synthetic synthesis content\n' > "$WORK/cod/summary/final.md"

mkdir -p "$WORK/log"
GATE_OUT="$WORK/gate-result.md"
cat > "$GATE_OUT" <<EOF
---
verdict: "PASS"
disputes: 0
rationale: "synthetic"
preset: "tier-2-fidelity"
artifact: "$WORK/dummy.md"
conversus_output_dir: "$WORK/cod"
---
EOF

# shellcheck disable=SC1090
. "$GATE_LIB"
_t2g_copy_advisories "$GATE_OUT" "$WORK/log" "synthetic-cite-01"

ADVISORIES="$WORK/log/synthetic-cite-01.advisories.md"
if [ -f "$ADVISORIES" ] && grep -qF "synthetic synthesis content" "$ADVISORIES"; then
  echo "PASS: helper copies summary/final.md to <log_dir>/<cite_id>.advisories.md"
else
  echo "FAIL: advisories.md not produced at $ADVISORIES"
  fail=$((fail + 1))
fi

# Stub-mode no-op: gate-result.md without conversus_output_dir must
# silently no-op (returns 0; no advisories file produced).
GATE_OUT_STUB="$WORK/gate-result-stub.md"
cat > "$GATE_OUT_STUB" <<EOF
---
verdict: "PASS"
disputes: 0
---
EOF
mkdir -p "$WORK/log-stub"
_t2g_copy_advisories "$GATE_OUT_STUB" "$WORK/log-stub" "stub-cite-01"
if [ ! -f "$WORK/log-stub/stub-cite-01.advisories.md" ]; then
  echo "PASS: helper silently no-ops when conversus_output_dir absent (stub mode)"
else
  echo "FAIL: helper produced advisories.md in stub mode (should no-op)"
  fail=$((fail + 1))
fi

echo "SUMMARY: m036-p03-tier-2-pass-advisories-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
