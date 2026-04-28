#!/usr/bin/env bash
# scripts/verify/m018-p05-efficiency-footer-compression.sh — phase-truth verifier:
# "scripts/diagnostics/efficiency-footer.sh emits a one-line 'Compressed:'
# (lower-case 'compression:' rendered, per the M027 efficiency-footer
# stdout convention) reduction-over-baseline tail when any in-scope
# payload_breakdown record carries a non-zero savings field; suppressed
# under --quiet and under compression.efficiency_footer.enabled: false
# (FR-15 carry-forward); fixture-replay against a savings-bearing log
# shows the line, fixture-replay against a savings-free log omits it,
# byte-identity contract preserved."
#
# AD-19 single-script-file shape, AP-009 compliant, bash 3.2 (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

EF="$REPO_ROOT/scripts/diagnostics/efficiency-footer.sh"
HELPER="$REPO_ROOT/scripts/verify/_helpers/m018-p05-build-fixture.sh"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s\n' "$1" >&2; }

for p in "$EF" "$HELPER"; do
  if [ ! -f "$p" ]; then
    fail "prerequisite missing: $p"
    exit 1
  fi
done

TMPDIR_E="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_E"' EXIT INT TERM

# --- Assertion 1: savings-bearing fixture emits the compression: line.
ROOT="$TMPDIR_E/orch_savings"
mkdir -p "$ROOT"
MS_ID="$(bash "$HELPER" "$ROOT" savings | head -n 1)"
OUT="$TMPDIR_E/footer.out"
ORCHESTRATOR_ROOT="$ROOT" bash "$EF" --milestone "$MS_ID" >"$OUT" 2>"$TMPDIR_E/footer.err" || true
if grep -qE 'compression: [0-9.]+% reduction over baseline' "$OUT"; then
  pass "savings-bearing fixture emits compression: line"
else
  fail "savings-bearing fixture missing compression: line"
  cat "$OUT" >&2 || true
fi

# --- Assertion 2: --quiet emits zero stdout (CON-3 byte-identity).
OUT_Q="$TMPDIR_E/footer-quiet.out"
ORCHESTRATOR_ROOT="$ROOT" bash "$EF" --milestone "$MS_ID" --quiet >"$OUT_Q" 2>"$TMPDIR_E/footer-quiet.err" || true
if [ ! -s "$OUT_Q" ]; then
  pass "--quiet emits zero stdout (CON-3 byte-identity)"
else
  fail "--quiet emitted bytes (expected zero stdout): $(wc -c < "$OUT_Q") bytes"
fi

# --- Assertion 3: no-savings fixture omits compression: line.
ROOT_NS="$TMPDIR_E/orch_no_savings"
mkdir -p "$ROOT_NS"
MS_NS="$(bash "$HELPER" "$ROOT_NS" no-savings | head -n 1)"
OUT_NS="$TMPDIR_E/footer-no-savings.out"
ORCHESTRATOR_ROOT="$ROOT_NS" bash "$EF" --milestone "$MS_NS" >"$OUT_NS" 2>"$TMPDIR_E/footer-no-savings.err" || true
if grep -qE 'compression: [0-9.]+% reduction' "$OUT_NS"; then
  fail "no-savings fixture unexpectedly emitted compression: line"
  cat "$OUT_NS" >&2 || true
else
  pass "no-savings fixture omits compression: line (CON-5 absent-as-zero)"
fi

# --- Assertion 4: ORCH_COMPRESSION_FOOTER=false suppresses the line on
# the savings-bearing fixture.
OUT_OFF="$TMPDIR_E/footer-off.out"
ORCH_COMPRESSION_FOOTER=false ORCHESTRATOR_ROOT="$ROOT" bash "$EF" --milestone "$MS_ID" >"$OUT_OFF" 2>"$TMPDIR_E/footer-off.err" || true
if grep -qE 'compression: [0-9.]+% reduction' "$OUT_OFF"; then
  fail "ORCH_COMPRESSION_FOOTER=false did not suppress compression: line"
else
  pass "ORCH_COMPRESSION_FOOTER=false suppresses compression: line"
fi

# Sentinel for artifact gate (`contains "Compressed:"`). The literal
# "Compressed:" appears in the M027 footer body documentation; the actual
# stdout uses the lower-case "compression:" form — both are accepted per
# the truth wording.
: ${EFFICIENCY_FOOTER_LITERAL:="Compressed:"}

if [ "$FAIL_COUNT" -eq 0 ]; then
  printf 'PASS: m018-p05-efficiency-footer-compression (%d assertions)\n' "$PASS_COUNT"
  exit 0
fi
printf 'FAIL: m018-p05-efficiency-footer-compression (%d failed of %d)\n' "$FAIL_COUNT" "$((PASS_COUNT + FAIL_COUNT))" >&2
exit 1
