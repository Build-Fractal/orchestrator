#!/usr/bin/env bash
# tools/m036-p03-live-smoke.sh -- M036a P03 pre-pilot live-LLM smoke test
# (one-shot, operator-driven; not part of CI). Runs a SINGLE end-to-end
# Tier 2 extraction against a synthetic representative-of-PBJ fixture
# using a real `claude -p` invocation. CON-3 closure: live mode requires
# the operator to opt in via ORCHESTRATOR_TIER2_LIVE=1.
#
# Conversus gate is stubbed PASS (CONVERSUS_STUB=1 + CONVERSUS_STUB_VERDICT
# =PASS) — this smoke test specifically retires the LLM-extraction-call
# wiring risk; the conversus path has been live-exercised in M026 and is
# not the target.
#
# Usage:
#   ORCHESTRATOR_TIER2_LIVE=1 bash tools/m036-p03-live-smoke.sh
#
# Optional knobs:
#   ORCHESTRATOR_TIER2_LIVE_COST_CAP_USD   default 1.0 (helper-side cap)
#
# Output:
#   - workspace path
#   - extracted .structured.md preview (first 20 lines)
#   - cost / token / model report
#   - SUMMARY: m036-p03-live-smoke pass=N fail=N
#   - exit 0 iff fail=0
#
# Bash 3.2 / POSIX-sh per CON-2. Single-script-file shape per AD-19.
set -eu

ROOT="${ORCHESTRATOR_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p03-live-smoke.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
FIXDIR="$ROOT/tests/fixtures/m036-p03-tier-2-live"
MANIFEST_REL="tests/fixtures/m036-p03-tier-2-live/extract-manifest.yaml"

pass=0; fail=0
ap() { echo "PASS: $1"; pass=$((pass + 1)); }
af() { echo "FAIL: $1"; fail=$((fail + 1)); }

# Pre-flight gates (operator-set, fail-fast).
if [ "${ORCHESTRATOR_TIER2_LIVE:-0}" != "1" ]; then
  echo "FAIL: ORCHESTRATOR_TIER2_LIVE=1 is required to run the live smoke test (CON-3 default-closed)" >&2
  echo "SUMMARY: m036-p03-live-smoke pass=0 fail=1 (preflight)"
  exit 1
fi
if ! command -v claude >/dev/null 2>&1; then
  echo "FAIL: 'claude' CLI not on PATH" >&2
  echo "SUMMARY: m036-p03-live-smoke pass=0 fail=1 (preflight)"
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: python3 not on PATH" >&2
  echo "SUMMARY: m036-p03-live-smoke pass=0 fail=1 (preflight)"
  exit 1
fi
if [ ! -f "$FIXDIR/sample.md" ] || [ ! -f "$FIXDIR/extract-manifest.yaml" ]; then
  echo "FAIL: live fixture missing under $FIXDIR" >&2
  echo "SUMMARY: m036-p03-live-smoke pass=0 fail=1 (preflight)"
  exit 1
fi

echo "INFO: workspace = $WORK"
echo "INFO: fixture   = $FIXDIR/sample.md ($(wc -c < "$FIXDIR/sample.md" | tr -d ' ') bytes)"

# Stage workspace: full ORCHESTRATOR_ROOT isolation (per M036/P03 two-leg
# harness pattern) so the unit_close JSONL and extraction-log writes
# never touch the real repo's .orchestrator/.
REPO="$WORK/repo"
mkdir -p "$REPO"
cp -R "$ROOT/scripts"   "$REPO/scripts"
cp -R "$ROOT/templates" "$REPO/templates"
mkdir -p "$REPO/tests/fixtures/m036-p03-tier-2-live"
cp "$FIXDIR/sample.md"             "$REPO/tests/fixtures/m036-p03-tier-2-live/"
cp "$FIXDIR/extract-manifest.yaml" "$REPO/tests/fixtures/m036-p03-tier-2-live/"
# Conversus stub adapter resolves _REPO_ROOT relative to its own location
# (4 dirs up from scripts/dispatch/adapters/tool/conversus.sh) → the
# workspace. Stage the stub's PASS-fixture under the workspace's
# tests/fixtures/ so CONVERSUS_STUB=1 + CONVERSUS_STUB_VERDICT=PASS
# resolves correctly.
cp "$ROOT/tests/fixtures/gate-result-pass.md"  "$REPO/tests/fixtures/"
cp "$ROOT/tests/fixtures/gate-result-block.md" "$REPO/tests/fixtures/"

# Run extraction.
echo "INFO: invoking extract-reference.sh (live LLM dispatch)..."
set +e
ORCHESTRATOR_ROOT="$REPO" \
EXTRACT_TIER_2_DISPATCH=live \
ORCHESTRATOR_TIER2_LIVE=1 \
ORCHESTRATOR_TIER2_LIVE_COST_CAP_USD="${ORCHESTRATOR_TIER2_LIVE_COST_CAP_USD:-1.0}" \
CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=PASS \
bash "$REPO/scripts/knowledge/extract-reference.sh" \
  --manifest "$REPO/$MANIFEST_REL" \
  --reference-root "$REPO/knowledge/reference" \
  --originals-root "$REPO/_originals" \
  >"$WORK/run.stdout" 2>"$WORK/run.stderr"
rc=$?
set -e
echo "INFO: extract-reference rc=$rc"

# Verifications.
if [ "$rc" -eq 0 ]; then ap "driver rc=0"; else af "driver rc=$rc (see $WORK/run.stderr)"; fi

if grep -qF -e "EXTRACTED: tier2-live-smoke-01" "$WORK/run.stdout"; then
  ap "stdout EXTRACTED line"
else
  af "stdout missing EXTRACTED line"
fi

if grep -qF -e "verdict=PASS" "$WORK/run.stdout"; then
  ap "stdout verdict=PASS"
else
  af "stdout missing verdict=PASS"
fi

STRUCT="$REPO/knowledge/reference/regulatory/REF-regulatory-tier2-live-smoke-01.structured.md"
if [ -f "$STRUCT" ]; then
  ap ".structured.md present in chunk store"
  if [ -s "$STRUCT" ]; then
    ap ".structured.md non-empty"
  else
    af ".structured.md empty"
  fi
  if grep -qE '^#' "$STRUCT"; then
    ap ".structured.md contains markdown headings"
  else
    af ".structured.md has no markdown headings"
  fi
else
  af ".structured.md missing at $STRUCT"
fi

JSONL="$REPO/.orchestrator/execution-log.jsonl"
if [ -f "$JSONL" ] && grep -qF -e '"task_type":"extraction"' "$JSONL"; then
  ap "unit_close extraction record present"
else
  af "unit_close extraction record missing"
fi
if [ -f "$JSONL" ] && grep -qF -e '"cite_id":"tier2-live-smoke-01"' "$JSONL"; then
  ap "unit_close cite_id matches"
else
  af "unit_close cite_id missing or mismatch"
fi

# Extract + report cost / model / tokens from the unit_close record.
if [ -f "$JSONL" ]; then
  REC=$(grep -F -e '"cite_id":"tier2-live-smoke-01"' "$JSONL" | tail -n 1)
  if [ -n "$REC" ]; then
    MODEL=$(printf '%s\n' "$REC" | sed -n 's/.*"model":"\([^"]*\)".*/\1/p')
    TIN=$(printf '%s\n'   "$REC" | sed -n 's/.*"tokens_in":\([0-9]*\).*/\1/p')
    TOUT=$(printf '%s\n'  "$REC" | sed -n 's/.*"tokens_out":\([0-9]*\).*/\1/p')
    COST=$(printf '%s\n'  "$REC" | sed -n 's/.*"cost_usd":\([0-9.]*\).*/\1/p')
    echo "INFO: model=$MODEL tokens_in=$TIN tokens_out=$TOUT cost_usd=\$$COST"
  fi
fi

echo "INFO: --- structured.md (first 20 lines) ---"
if [ -f "$STRUCT" ]; then
  head -n 20 "$STRUCT"
fi
echo "INFO: --- end preview ---"

# Persist artifacts under .orchestrator/milestones/M036/ for evidence.
EVID_DIR="$ROOT/.orchestrator/milestones/M036/p03-live-smoke-evidence"
mkdir -p "$EVID_DIR"
if [ -f "$STRUCT" ]; then
  cp "$STRUCT" "$EVID_DIR/REF-regulatory-tier2-live-smoke-01.structured.md"
fi
if [ -f "$JSONL" ]; then
  grep -F -e '"cite_id":"tier2-live-smoke-01"' "$JSONL" > "$EVID_DIR/unit_close.jsonl" || true
fi
cp "$WORK/run.stdout" "$EVID_DIR/driver.stdout"
cp "$WORK/run.stderr" "$EVID_DIR/driver.stderr"
echo "INFO: evidence persisted under $EVID_DIR"

echo "SUMMARY: m036-p03-live-smoke pass=$pass fail=$fail"
[ "$fail" -eq 0 ] || exit 1
exit 0
