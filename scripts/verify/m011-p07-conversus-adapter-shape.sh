#!/usr/bin/env bash
# scripts/verify/m011-p07-conversus-adapter-shape.sh
#
# Asserts scripts/dispatch/adapters/tool/conversus.sh shape + stub-mode
# end-to-end behavior per M011/P07/T02 Truths.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ADAPTER="${REPO_ROOT}/scripts/dispatch/adapters/tool/conversus.sh"

PASS=0
FAIL=0

pass() {
  PASS=$((PASS + 1))
  echo "PASS: $1"
}

fail() {
  FAIL=$((FAIL + 1))
  echo "FAIL: $1"
}

# --- existence + executable ---

if [ -f "$ADAPTER" ]; then
  pass "adapter exists at $ADAPTER"
else
  fail "adapter missing at $ADAPTER"
  echo "SUMMARY: pass=$PASS fail=$FAIL"
  exit 1
fi

if [ -x "$ADAPTER" ]; then
  pass "adapter is executable"
else
  fail "adapter is not executable"
fi

# --- three subcommands present ---

for tok in 'check)' 'gate)' 'parse-verdict)'; do
  if grep -Fq -- "$tok" "$ADAPTER"; then
    pass "subcommand case branch present: $tok"
  else
    fail "subcommand case branch missing: $tok"
  fi
done

# --- resolver locations documented ---

for tok in 'command -v conversus' 'CONVERSUS_HOME' 'Sites/conversus' 'CONVERSUS_STUB'; do
  if grep -Fq -- "$tok" "$ADAPTER"; then
    pass "resolver token present: $tok"
  else
    fail "resolver token missing: $tok"
  fi
done

# --- available= emission ---

if grep -Fq -- 'available=' "$ADAPTER"; then
  pass "emits available= token"
else
  fail "no available= token emitted"
fi

# --- SKIPPED emission on missing binary ---

if grep -Fq -- 'SKIPPED:' "$ADAPTER"; then
  pass "emits SKIPPED: for graceful degradation"
else
  fail "no SKIPPED: token (graceful degradation missing)"
fi

# --- exit 2 on BLOCK ---

if grep -Fq -- 'exit 2' "$ADAPTER"; then
  pass "returns exit 2 on BLOCK path"
else
  fail "no 'exit 2' in adapter (BLOCK contract missing)"
fi

# --- stub-mode end-to-end: parse-verdict ---

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS_FIX="${REPO_ROOT}/tests/fixtures/gate-result-pass.md"
BLOCK_FIX="${REPO_ROOT}/tests/fixtures/gate-result-block.md"

if [ -f "$PASS_FIX" ]; then
  pass "pass fixture present"
else
  fail "pass fixture missing at $PASS_FIX"
fi

if [ -f "$BLOCK_FIX" ]; then
  pass "block fixture present"
else
  fail "block fixture missing at $BLOCK_FIX"
fi

cp "$PASS_FIX" "$TMP/pass.md"
cp "$BLOCK_FIX" "$TMP/block.md"

PV_OUT="$(bash "$ADAPTER" parse-verdict "$TMP/pass.md" 2>/dev/null || true)"
case "$PV_OUT" in
  *verdict=PASS*)
    pass "parse-verdict emits verdict=PASS on pass fixture"
    ;;
  *)
    fail "parse-verdict pass fixture unexpected output: $PV_OUT"
    ;;
esac

PV_OUT2="$(bash "$ADAPTER" parse-verdict "$TMP/block.md" 2>/dev/null || true)"
case "$PV_OUT2" in
  *verdict=BLOCK*)
    pass "parse-verdict emits verdict=BLOCK on block fixture"
    ;;
  *)
    fail "parse-verdict block fixture unexpected output: $PV_OUT2"
    ;;
esac

# --- stub-mode end-to-end: gate ---

OUT_PASS="$TMP/gate-out-pass.md"
CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=PASS bash "$ADAPTER" gate normalize-fidelity "$PASS_FIX" "$OUT_PASS" >/dev/null 2>&1
RC=$?
if [ "$RC" = "0" ]; then
  pass "gate exit 0 on stub PASS"
else
  fail "gate exit $RC on stub PASS (expected 0)"
fi

OUT_BLOCK="$TMP/gate-out-block.md"
CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=BLOCK bash "$ADAPTER" gate normalize-fidelity "$PASS_FIX" "$OUT_BLOCK" >/dev/null 2>&1
RC=$?
if [ "$RC" = "2" ]; then
  pass "gate exit 2 on stub BLOCK"
else
  fail "gate exit $RC on stub BLOCK (expected 2)"
fi

# --- summary ---

echo "SUMMARY: pass=$PASS fail=$FAIL"
if [ "$FAIL" -eq 0 ]; then
  exit 0
fi
exit 1
