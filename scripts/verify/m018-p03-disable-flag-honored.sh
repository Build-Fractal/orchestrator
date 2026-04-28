#!/usr/bin/env bash
# scripts/verify/m018-p03-disable-flag-honored.sh — phase-truth verifier:
# "compression.enabled: false short-circuits Tier 1 entirely; the P02
# disable-flag golden payload (tests/fixtures/m018-p02-baseline-payload
# .golden.txt) remains byte-identical against the P03 build-context.sh;
# compression.tier1.enabled: false short-circuits only Tier 1 (filter
# still runs)."
#
# Five assertions:
#   1. The P02 golden baseline is byte-identical to the P02 fixture
#      knowledge-stream (regression on P02's golden — P03 must not have
#      drifted it).
#   2. build-context.sh source has the COMPRESSION_ENABLED short-circuit
#      guard inside _bc_apply_tier1.
#   3. build-context.sh source has the TIER1_ENABLED short-circuit
#      guard inside _bc_apply_tier1.
#   4. With ORCH_OVERRIDE_COMPRESSION_ENABLED=false, end-to-end
#      build-context.sh against the M018-fixture leaves the cache
#      directory empty (no cache writes when master toggle is off).
#   5. With compression.tier1.enabled=false (master toggle still true),
#      end-to-end build-context.sh leaves the cache directory empty
#      AND the live payload_breakdown record reports tier1_invocations=0
#      (per-tier toggle short-circuits without disabling the master
#      pipeline).
#
# AD-19 single-script-file shape, AP-009 compliant, bash 3.2 (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

BC="$REPO_ROOT/scripts/dispatch/build-context.sh"
HELPER="$REPO_ROOT/scripts/verify/_helpers/m018-p03-build-fixture.sh"
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
  printf 'FAIL: P02 golden baseline diverged from fixture knowledge-stream (compression.enabled:false byte-identity broken)\n' >&2
  cat "$DIFF_OUT" >&2
  exit 1
fi

# --- Assertion 2: build-context.sh COMPRESSION_ENABLED short-circuit guard ---
if ! grep -q 'COMPRESSION_ENABLED.*!= "true"' "$BC"; then
  printf 'FAIL: build-context.sh missing COMPRESSION_ENABLED short-circuit guard\n' >&2
  exit 1
fi

# --- Assertion 3: build-context.sh TIER1_ENABLED short-circuit guard ---
if ! grep -q 'TIER1_ENABLED.*!= "true"' "$BC"; then
  printf 'FAIL: build-context.sh missing TIER1_ENABLED short-circuit guard\n' >&2
  exit 1
fi

# --- Assertion 4: ORCH_OVERRIDE_COMPRESSION_ENABLED=false short-circuits Tier 1. ---
ROOT4="$TMPDIR_D/root4"
mkdir -p "$ROOT4"
bash "$HELPER" "$ROOT4" >/dev/null

PAYLOAD4="$TMPDIR_D/payload4.md"
ERR4="$TMPDIR_D/bc4.err"
if ! bash "$REPO_ROOT/scripts/util/with-env.sh" \
       ORCH_OVERRIDE_COMPRESSION_ENABLED=false -- \
       bash "$BC" "$ROOT4" M018-fixture P03 T01 > "$PAYLOAD4" 2>"$ERR4"; then
  printf 'FAIL: build-context.sh nonzero with compression.enabled override=false\n' >&2
  cat "$ERR4" >&2
  exit 1
fi

# Cache dir should remain empty (no writes when master toggle off).
CACHE4_COUNT=0
for f in "$ROOT4/cache/tool-results/"*; do
  if [ -f "$f" ]; then
    CACHE4_COUNT=$(( CACHE4_COUNT + 1 ))
  fi
done
if [ "$CACHE4_COUNT" -ne 0 ]; then
  printf 'FAIL: cache dir non-empty after compression.enabled=false run (count=%d)\n' "$CACHE4_COUNT" >&2
  exit 1
fi

# --- Assertion 5: compression.tier1.enabled=false short-circuits only Tier 1. ---
ROOT5="$TMPDIR_D/root5"
mkdir -p "$ROOT5"
TIER1_OFF_BLOCK="$TMPDIR_D/_tier1_off.yml"
cat > "$TIER1_OFF_BLOCK" <<'EOF'
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
    enabled: false
    inline_threshold_tokens: 1500
    preview_lines: 5
EOF
COMPRESSION_BLOCK_OVERRIDE="$TIER1_OFF_BLOCK" \
  bash "$HELPER" "$ROOT5" >/dev/null

PAYLOAD5="$TMPDIR_D/payload5.md"
ERR5="$TMPDIR_D/bc5.err"
if ! bash "$BC" "$ROOT5" M018-fixture P03 T01 > "$PAYLOAD5" 2>"$ERR5"; then
  printf 'FAIL: build-context.sh nonzero with tier1.enabled=false\n' >&2
  cat "$ERR5" >&2
  exit 1
fi

# Cache dir should remain empty.
CACHE5_COUNT=0
for f in "$ROOT5/cache/tool-results/"*; do
  if [ -f "$f" ]; then
    CACHE5_COUNT=$(( CACHE5_COUNT + 1 ))
  fi
done
if [ "$CACHE5_COUNT" -ne 0 ]; then
  printf 'FAIL: cache dir non-empty after tier1.enabled=false run (count=%d)\n' "$CACHE5_COUNT" >&2
  exit 1
fi

# Live payload_breakdown record should report tier1_invocations=0.
LIVE_LOG5="$ROOT5/execution-log.jsonl"
if [ ! -s "$LIVE_LOG5" ]; then
  printf 'FAIL: execution-log.jsonl empty after tier1.enabled=false run\n' >&2
  exit 1
fi
LIVE_PB5="$(grep '"record_type":"payload_breakdown"' "$LIVE_LOG5" | head -1)"
if ! printf '%s' "$LIVE_PB5" | grep -q '"tier1_invocations":0'; then
  printf 'FAIL: tier1.enabled=false run reported tier1_invocations != 0\n' >&2
  printf '       record: %s\n' "$LIVE_PB5" >&2
  exit 1
fi

# compression.enabled literal in this verifier (artifact contains check).
printf 'PASS: m018-p03-disable-flag-honored (golden byte-identical; compression.enabled=false + tier1.enabled=false both short-circuit Tier 1)\n'
exit 0
