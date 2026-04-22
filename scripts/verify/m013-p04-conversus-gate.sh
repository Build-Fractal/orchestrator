#!/usr/bin/env bash
# scripts/verify/m013-p04-conversus-gate.sh — T05 gate: conversus UAT PR gate.
#
# Asserts the behavioral contract of scripts/integrations/github-conversus-gate.sh:
#   - script exists and is executable
#   - invokes scripts/dispatch/adapters/tool/conversus.sh gate --strict
#   - 30s default timeout (Constitution XII)
#   - emits FR-17 conversus_gate_invocation Tier 1 record
#   - SC-7 auto-mode short-circuit (no tty + no --i-am-operator → gate-deferred, rc=0)
#   - stub-mode PASS path (CONVERSUS_STUB=1 + --i-am-operator → rc=0)
#   - JSONL record has all FR-17 fields
#   - watchdog kills runaway gate within $TIMEOUT + buffer
#   - BLOCK verdict path exits rc=2
#
# Bash 3.2 target, jq-optional, hermetic (no live gh or conversus binary).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
GATE="${REPO_ROOT}/scripts/integrations/github-conversus-gate.sh"
ADAPTER="${REPO_ROOT}/scripts/dispatch/adapters/tool/conversus.sh"

passed=0
failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

TMPROOT="$(mktemp -d -t m013-p04-gate.XXXXXX)"
trap 'rm -rf "$TMPROOT"' EXIT INT TERM

# --- Assertion 1: gate script exists + executable ----------------------------
if [ -x "$GATE" ]; then
  pass "github-conversus-gate.sh present + executable"
else
  fail "gate script missing or not executable at ${GATE}"
fi

# --- Assertion 2: gate invokes conversus.sh gate --strict --------------------
if grep -qE 'conversus\.sh.*gate.*--strict|"\$ADAPTER" gate --strict' "$GATE"; then
  pass "gate invokes conversus.sh gate --strict"
else
  fail "gate does not invoke conversus.sh gate --strict"
fi

# --- Assertion 3: default timeout is 30 seconds ------------------------------
if grep -qE '^TIMEOUT=30$' "$GATE"; then
  pass "default timeout is 30s (Constitution XII)"
else
  fail "default timeout missing or not 30s"
fi

# --- Assertion 4: gate emits Tier 1 record -----------------------------------
if grep -qE 'emit_conversus_gate_record' "$GATE"; then
  pass "gate calls emit_conversus_gate_record (FR-17)"
else
  fail "gate does not call emit_conversus_gate_record"
fi

# --- Assertion 5: SC-7 auto-mode short-circuit (no tty + no --i-am-operator) -
artifact="${TMPROOT}/artifact.md"
printf 'test artifact\n' > "$artifact"
export ORCHESTRATOR_ROOT="${TMPROOT}/.orchestrator"
mkdir -p "$ORCHESTRATOR_ROOT"
: > "${ORCHESTRATOR_ROOT}/execution-log.jsonl"

sc7_out="$(bash "$GATE" --issue-ref t/r#999 --artifact "$artifact" </dev/null 2>&1)"
sc7_rc=$?
if [ "$sc7_rc" -eq 0 ] && printf '%s\n' "$sc7_out" | grep -q 'STATUS: gate-deferred'; then
  pass "SC-7 auto-mode short-circuit emits gate-deferred + rc=0"
else
  fail "SC-7 short-circuit failed (rc=${sc7_rc} out=${sc7_out})"
fi

# Auto-mode must not have emitted any JSONL record.
if [ ! -s "${ORCHESTRATOR_ROOT}/execution-log.jsonl" ]; then
  pass "SC-7 short-circuit emits zero JSONL records"
else
  fail "SC-7 short-circuit wrote JSONL records (expected zero)"
fi

# --- Assertion 7: stub-mode PASS path (CONVERSUS_STUB=1) ---------------------
: > "${ORCHESTRATOR_ROOT}/execution-log.jsonl"
CONVERSUS_STUB=1 bash "$GATE" --issue-ref t/r#1 --artifact "$artifact" --i-am-operator --timeout 5 </dev/null >/dev/null 2>&1
stub_rc=$?
if [ "$stub_rc" -eq 0 ]; then
  pass "stub-mode PASS → rc=0"
else
  fail "stub-mode expected rc=0 got rc=${stub_rc}"
fi

# --- Assertion 8: JSONL record was appended ----------------------------------
if grep -q '"event":"conversus_gate_invocation"' "${ORCHESTRATOR_ROOT}/execution-log.jsonl"; then
  pass "Tier 1 JSONL conversus_gate_invocation record appended"
else
  fail "Tier 1 conversus_gate_invocation record missing from execution-log.jsonl"
fi

# --- Assertion 9: FR-17 field completeness -----------------------------------
line="$(grep '"event":"conversus_gate_invocation"' "${ORCHESTRATOR_ROOT}/execution-log.jsonl" | head -n 1)"
ok=1
for key in issue_ref timeout_sec verdict rc duration_ms; do
  if ! printf '%s\n' "$line" | grep -q "\"${key}\""; then
    fail "Tier 1 record missing FR-17 field: ${key}"
    ok=0
  fi
done
if [ "$ok" -eq 1 ]; then
  pass "Tier 1 record has all five FR-17 fields"
fi

# Verdict must be PASS and source must be runtime.
if printf '%s\n' "$line" | grep -q '"verdict":"PASS"' && \
   printf '%s\n' "$line" | grep -q '"source":"runtime"'; then
  pass "Tier 1 record has verdict=PASS + source=runtime"
else
  fail "Tier 1 record verdict/source mismatch: ${line}"
fi

# --- Assertion 11: stub-mode BLOCK path (CONVERSUS_STUB=1 + STUB_VERDICT=BLOCK)
: > "${ORCHESTRATOR_ROOT}/execution-log.jsonl"
CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=BLOCK bash "$GATE" \
  --issue-ref t/r#2 --artifact "$artifact" --i-am-operator --timeout 5 </dev/null >/dev/null 2>&1
block_rc=$?
if [ "$block_rc" -eq 2 ]; then
  pass "stub-mode BLOCK → rc=2 (adapter contract)"
else
  fail "stub-mode BLOCK expected rc=2 got rc=${block_rc}"
fi

block_line="$(grep '"event":"conversus_gate_invocation"' "${ORCHESTRATOR_ROOT}/execution-log.jsonl" | head -n 1)"
if printf '%s\n' "$block_line" | grep -q '"verdict":"BLOCK"'; then
  pass "Tier 1 record has verdict=BLOCK for BLOCK path"
else
  fail "Tier 1 record verdict!=BLOCK: ${block_line}"
fi

# --- Assertion 13: watchdog kills runaway gate -------------------------------
stub_dir="$(mktemp -d -t m013-p04-gate-wd.XXXXXX)"
cat > "${stub_dir}/conversus" <<'ST'
#!/usr/bin/env bash
sleep 60
ST
chmod +x "${stub_dir}/conversus"

start="$(date +%s)"
CONVERSUS_STUB="" PATH="${stub_dir}:${PATH}" \
  bash "$GATE" --issue-ref t/r#3 --artifact "$artifact" --i-am-operator --timeout 2 \
  </dev/null >/dev/null 2>&1 || true
end="$(date +%s)"
elapsed=$((end - start))
rm -rf "$stub_dir"

if [ "$elapsed" -lt 6 ]; then
  pass "watchdog killed runaway gate within timeout+buffer (elapsed=${elapsed}s)"
else
  fail "watchdog did not kill runaway gate within 6s (elapsed=${elapsed}s)"
fi

# --- Assertion 14: --issue-ref + --artifact required -------------------------
missing_out="$(bash "$GATE" </dev/null 2>&1 || true)"
if printf '%s\n' "$missing_out" | grep -q 'required'; then
  pass "missing required flags emit FAIL with guidance"
else
  fail "missing-args path did not emit 'required' diagnostic"
fi

# --- Assertion 15: preset m013-uat-defect-merge.yml exists -------------------
PRESET="${REPO_ROOT}/templates/conversus-presets/m013-uat-defect-merge.yml"
if [ -f "$PRESET" ]; then
  pass "preset m013-uat-defect-merge.yml exists"
else
  fail "preset m013-uat-defect-merge.yml missing at ${PRESET}"
fi

# --- Assertion 16: adapter was authored (sanity) -----------------------------
if [ -f "$ADAPTER" ]; then
  pass "conversus adapter present at canonical path"
else
  fail "conversus adapter missing at ${ADAPTER}"
fi

echo "SUMMARY: m013-p04-conversus-gate.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p04-conversus-gate.sh"
  exit 0
fi
echo "FAIL: m013-p04-conversus-gate.sh" >&2
exit 1
