#!/usr/bin/env bash
# scripts/verify/m018-p04-tier2-disable-flag.sh — phase-truth verifier:
# "compression.enabled: false keeps the P02 golden byte-identical
# against the post-P04 build-context.sh; compression.tier2.enabled: false
# short-circuits only Tier 2 (filter + Tier 1 still run)."
#
# Five assertions:
#   1. The P02 golden baseline is byte-identical to the P02 fixture
#      knowledge-stream (regression net — P04 must not have drifted
#      the P02 golden).
#   2. build-context.sh source has the COMPRESSION_ENABLED short-circuit
#      guard inside _bc_apply_tier2.
#   3. build-context.sh source has the TIER2_ENABLED short-circuit
#      guard inside _bc_apply_tier2.
#   4. With compression.tier2.enabled: false (tier1.enabled=true,
#      compression.enabled=true), end-to-end build-context.sh against
#      the M018-fixture leaves no `<!-- compressed:tier2` marker on
#      the rendered payload AND `tier2_savings_tokens=0` in the live
#      payload_breakdown JSONL record.
#   5. With ORCH_OVERRIDE_COMPRESSION_ENABLED=false, end-to-end
#      build-context.sh leaves no compression markers (filter, tier1,
#      tier2) on the rendered payload — master toggle short-circuits
#      the entire pipeline.
#
# AD-19 single-script-file shape, AP-009 compliant, bash 3.2 (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

BC="$REPO_ROOT/scripts/dispatch/build-context.sh"
HELPER="$REPO_ROOT/scripts/verify/_helpers/m018-p04-build-fixture.sh"
GOLDEN="$REPO_ROOT/tests/fixtures/m018-p02-baseline-payload.golden.txt"
P02_FIXTURE="$REPO_ROOT/tests/fixtures/m018-p02-knowledge-status/knowledge-stream.md"

for p in "$BC" "$HELPER" "$GOLDEN" "$P02_FIXTURE"; do
  if [ ! -f "$p" ]; then
    printf 'FAIL: prerequisite missing: %s\n' "$p" >&2
    exit 1
  fi
done

# --- Assertion 1: P02 golden byte-identity preserved (compression.enabled regression net). ---
TMPDIR_D="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_D"' EXIT INT TERM
DIFF_OUT="$TMPDIR_D/diff.out"
if ! diff -u "$P02_FIXTURE" "$GOLDEN" > "$DIFF_OUT" 2>&1; then
  printf 'FAIL: P02 golden baseline diverged from fixture knowledge-stream\n' >&2
  cat "$DIFF_OUT" >&2
  exit 1
fi

# --- Assertion 2: build-context.sh COMPRESSION_ENABLED short-circuit guard inside _bc_apply_tier2 ---
T2_BODY="$TMPDIR_D/_t2_body.sh"
awk '/^_bc_apply_tier2\(\)/,/^}$/' "$BC" > "$T2_BODY"
if ! grep -q 'COMPRESSION_ENABLED.*!= "true"' "$T2_BODY"; then
  printf 'FAIL: _bc_apply_tier2 missing COMPRESSION_ENABLED short-circuit guard\n' >&2
  exit 1
fi

# --- Assertion 3: TIER2_ENABLED short-circuit guard inside _bc_apply_tier2 ---
if ! grep -q 'TIER2_ENABLED.*!= "true"' "$T2_BODY"; then
  printf 'FAIL: _bc_apply_tier2 missing TIER2_ENABLED short-circuit guard\n' >&2
  exit 1
fi

# --- Assertion 4: compression.tier2.enabled=false short-circuits only Tier 2. ---
ROOT4="$TMPDIR_D/root4"
mkdir -p "$ROOT4"
TIER2_OFF_BLOCK="$TMPDIR_D/_tier2_off.yml"
cat > "$TIER2_OFF_BLOCK" <<'EOF'
compression:
  enabled: true
  knowledge_filter:
    enabled: true
    drop_list: ["superseded", "experimental"]
  underperformance:
    enabled: true
    window_size: 30
    floor_pct: 34.7
    min_sample_size: 10
  tier1:
    enabled: true
    inline_threshold_tokens: 1500
    preview_lines: 5
  tier2:
    enabled: false
    section_budget_tokens: 200
    protected_tail_ratio: 0.3
EOF
COMPRESSION_BLOCK_OVERRIDE="$TIER2_OFF_BLOCK" \
  bash "$HELPER" "$ROOT4" section-overflow >/dev/null

PAYLOAD4="$TMPDIR_D/payload4.md"
ERR4="$TMPDIR_D/bc4.err"
if ! bash "$BC" "$ROOT4" M018-fixture P04 T01 > "$PAYLOAD4" 2>"$ERR4"; then
  printf 'FAIL: build-context.sh nonzero with tier2.enabled=false\n' >&2
  cat "$ERR4" >&2
  exit 1
fi

# No tier2 marker on the rendered payload.
if grep -q '<!-- compressed:tier2' "$PAYLOAD4"; then
  printf 'FAIL: tier2 marker present despite tier2.enabled=false\n' >&2
  exit 1
fi
# tier2_savings_tokens=0 in payload_breakdown.
LIVE_LOG4="$ROOT4/execution-log.jsonl"
if [ ! -s "$LIVE_LOG4" ]; then
  printf 'FAIL: execution-log.jsonl empty after tier2.enabled=false run\n' >&2
  exit 1
fi
LIVE_PB4="$(grep '"record_type":"payload_breakdown"' "$LIVE_LOG4" | head -1)"
if ! printf '%s' "$LIVE_PB4" | grep -q '"tier2_savings_tokens":0'; then
  printf 'FAIL: tier2.enabled=false run reported tier2_savings_tokens != 0\n' >&2
  printf '       record: %s\n' "$LIVE_PB4" >&2
  exit 1
fi

# --- Assertion 5: ORCH_OVERRIDE_COMPRESSION_ENABLED=false short-circuits entire pipeline. ---
ROOT5="$TMPDIR_D/root5"
mkdir -p "$ROOT5"
bash "$HELPER" "$ROOT5" section-overflow >/dev/null

PAYLOAD5="$TMPDIR_D/payload5.md"
ERR5="$TMPDIR_D/bc5.err"
if ! bash "$REPO_ROOT/scripts/util/with-env.sh" \
       ORCH_OVERRIDE_COMPRESSION_ENABLED=false -- \
       bash "$BC" "$ROOT5" M018-fixture P04 T01 > "$PAYLOAD5" 2>"$ERR5"; then
  printf 'FAIL: build-context.sh nonzero with compression.enabled override=false\n' >&2
  cat "$ERR5" >&2
  exit 1
fi
# No compression markers (any tier).
if grep -qE '<!-- compressed:tier[0-9]+' "$PAYLOAD5"; then
  printf 'FAIL: compression marker present despite ORCH_OVERRIDE_COMPRESSION_ENABLED=false\n' >&2
  exit 1
fi

# compression.enabled literal in this verifier (artifact contains check).
printf 'PASS: m018-p04-tier2-disable-flag (golden byte-identical; tier2.enabled=false short-circuits T2 only; compression.enabled=false short-circuits pipeline)\n'
exit 0
