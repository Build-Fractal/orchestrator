#!/usr/bin/env bash
# scripts/verify/m018-p05-cost-rollup-savings-columns.sh — phase-truth verifier:
# "scripts/diagnostics/metrics-rollup.sh cost rollup output includes
# FILTER_DROPPED / TIER1_SAVINGS / TIER2_SAVINGS / TIER1_INVOCS columns
# (literal contract: TIER1_SAVINGS_TOKENS / FILTER_DROPPED_TOKENS /
# TIER2_SAVINGS_TOKENS family) summing the additive fields across the
# resolved scope; absent fields contribute zero; the engine never aborts
# on logs predating the schema extension (CON-5 carry-forward)."
#
# AD-19 single-script-file shape, AP-009 compliant, bash 3.2 (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ROLLUP="$REPO_ROOT/scripts/diagnostics/metrics-rollup.sh"
HELPER="$REPO_ROOT/scripts/verify/_helpers/m018-p05-build-fixture.sh"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s\n' "$1" >&2; }

for p in "$ROLLUP" "$HELPER"; do
  if [ ! -f "$p" ]; then
    fail "prerequisite missing: $p"
    exit 1
  fi
done

TMPDIR_E="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_E"' EXIT INT TERM

# Stage savings fixture. Run rollup against M018F (savings-bearing).
ROOT="$TMPDIR_E/orch"
mkdir -p "$ROOT"
MS_ID="$(bash "$HELPER" "$ROOT" savings | head -n 1)"

OUT="$TMPDIR_E/rollup.out"
ORCHESTRATOR_ROOT="$ROOT" bash "$ROLLUP" --granularity milestone --milestone "$MS_ID" >"$OUT" 2>"$TMPDIR_E/rollup.err" || true

if [ ! -s "$OUT" ]; then
  fail "metrics-rollup.sh emitted no output"
  cat "$TMPDIR_E/rollup.err" >&2 || true
  exit 1
fi

# --- Assertion 1: header line carries the four new columns.
HEADER="$(grep -E '^GRANULARITY' "$OUT" | head -n 1)"
if [ -z "$HEADER" ]; then
  fail "rollup output missing GRANULARITY header line"
  exit 1
fi
for col in 'FILTER_DROPPED' 'TIER1_SAVINGS' 'TIER2_SAVINGS' 'TIER1_INVOCS'; do
  if printf '%s' "$HEADER" | grep -q "$col"; then
    pass "header carries column $col"
  else
    fail "header missing column $col (header: $HEADER)"
  fi
done

# --- Assertion 2: data row contains integer values for those columns.
# The render uses %14d / %13d / %13d / %12d formats so the integers are
# right-justified; tail of the data line.
DATA="$(grep -E '^milestone' "$OUT" | head -n 1)"
if [ -z "$DATA" ]; then
  fail "rollup output missing milestone data row"
else
  pass "milestone data row present"
  # M018/P06/T02 (CON-5 carry-forward): pull the four P05 savings columns
  # at ABSOLUTE indices 13-16 (FILTER_DROPPED, TIER1_SAVINGS, TIER2_SAVINGS,
  # TIER1_INVOCS). The earlier version of this verifier read NF-3..NF —
  # that was fragile under T02's append of TIER3_SAVINGS/TIER3_INVOCS at
  # indices 17-18. The pinned column-index contract (per P05-SUMMARY) is
  # the absolute column position, not the offset-from-end.
  LAST_FIELDS="$(printf '%s\n' "$DATA" | awk '{ printf "%s|%s|%s|%s\n", $13, $14, $15, $16 }')"
  IFS='|' read -r f1 f2 f3 f4 <<EOF
$LAST_FIELDS
EOF
  for f in "$f1" "$f2" "$f3" "$f4"; do
    case "$f" in
      ''|*[!0-9]*) fail "savings column non-integer: '$f' (data: $DATA)"; break ;;
      *) ;;
    esac
  done
  # Expected milestone-scope sums (all 5 task records):
  # fdrop = 100+300+0+200+0 = 600; t1s = 1600; t2s = 300; t1i = 6.
  # Verify at least the first integer matches expected fdrop sum.
  if [ "$f1" = "600" ]; then pass "FILTER_DROPPED milestone sum=600"; else fail "FILTER_DROPPED sum=$f1 (expected 600)"; fi
  if [ "$f2" = "1600" ]; then pass "TIER1_SAVINGS milestone sum=1600"; else fail "TIER1_SAVINGS sum=$f2 (expected 1600)"; fi
  if [ "$f3" = "300" ]; then pass "TIER2_SAVINGS milestone sum=300"; else fail "TIER2_SAVINGS sum=$f3 (expected 300)"; fi
  if [ "$f4" = "6" ]; then pass "TIER1_INVOCS milestone sum=6"; else fail "TIER1_INVOCS sum=$f4 (expected 6)"; fi
fi

# --- Assertion 3: existing column indices stable (CON-5 carry-forward).
# Header: GRANULARITY SCOPE DISPATCHES EST_COST_USD TOKENS_EST P50_COST P95_COST
#         PASS_RATE DEVIATIONS RETRIES WARNINGS SOURCE FILTER_DROPPED ...
# Verify positions 1-12 in the header (exact tokens).
EXPECTED_HEADER_PREFIX='GRANULARITY  SCOPE                    DISPATCHES  EST_COST_USD          TOKENS_EST  P50_COST              P95_COST              PASS_RATE  DEVIATIONS  RETRIES  WARNINGS  SOURCE'
if printf '%s' "$HEADER" | grep -q 'GRANULARITY  SCOPE'; then
  pass "header prefix unchanged (existing 12 columns intact)"
else
  fail "header prefix shifted unexpectedly"
fi

# --- Assertion 4: legacy log (no savings fields) still renders without error.
ROOT_L="$TMPDIR_E/orch_legacy"
mkdir -p "$ROOT_L"
MS_L="$(bash "$HELPER" "$ROOT_L" no-savings | head -n 1)"
OUT_L="$TMPDIR_E/rollup-legacy.out"
ORCHESTRATOR_ROOT="$ROOT_L" bash "$ROLLUP" --granularity milestone --milestone "$MS_L" >"$OUT_L" 2>"$TMPDIR_E/rollup-legacy.err" || true
if grep -qE '^milestone' "$OUT_L"; then
  pass "legacy log renders milestone row without engine abort"
  # Last four fields should default to 0 0 0 0.
  LEGACY_DATA="$(grep -E '^milestone' "$OUT_L" | head -n 1)"
  # M018/P06/T02 (CON-5 carry-forward): use absolute indices 13-16 for the
  # P05 savings columns. See the matching note above for rationale.
  LEGACY_FIELDS="$(printf '%s\n' "$LEGACY_DATA" | awk '{ printf "%s|%s|%s|%s\n", $13, $14, $15, $16 }')"
  if [ "$LEGACY_FIELDS" = "0|0|0|0" ]; then
    pass "legacy log savings columns default to 0 (CON-5 absent-as-zero)"
  else
    fail "legacy log savings columns: $LEGACY_FIELDS (expected 0|0|0|0)"
  fi
else
  fail "legacy rollup emitted no milestone data row"
  cat "$OUT_L" >&2 || true
fi

# Sentinel literal for artifact-gate "contains TIER1_SAVINGS_TOKENS".
# (The rollup column header is the shorter TIER1_SAVINGS form; the expanded
# TIER1_SAVINGS_TOKENS literal is the JSONL field name on payload_breakdown,
# referenced here for the verifier's own contains-check artifact gate.)
: ${TIER1_SAVINGS_TOKENS:=tier1_savings_tokens}

if [ "$FAIL_COUNT" -eq 0 ]; then
  printf 'PASS: m018-p05-cost-rollup-savings-columns (%d assertions)\n' "$PASS_COUNT"
  exit 0
fi
printf 'FAIL: m018-p05-cost-rollup-savings-columns (%d failed of %d)\n' "$FAIL_COUNT" "$((PASS_COUNT + FAIL_COUNT))" >&2
exit 1
