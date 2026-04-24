#!/usr/bin/env bash
# scripts/verify/m026-p02-adapter-invariants.sh
#
# M026/P02/T01 gate: verify the conversus adapter preserves CON-1..CON-3
# invariants after the T01 edition-detection changes:
#
#   - No forbidden Bash 3.2 tokens (declare -A, mapfile, readarray,
#     process substitution).
#   - 0/1/2 exit-code contract preserved (missing preset → 1, stub PASS
#     → 0, stub BLOCK → 2).
#   - gate-result.md frontmatter key-set (verdict, disputes, rationale,
#     source_hash, preset, artifact, conversus_output_dir,
#     conversus_config) still emitted verbatim in stub-mode PASS.
#   - D019 TODO pre-flight block still present (unique error substring
#     "<TODO: marker(s); gate refuses unauthored drafts" retained).
#   - Full env-var set (CONVERSUS_STUB, CONVERSUS_STUB_VERDICT,
#     CONVERSUS_HOME, CONVERSUS_STRICT, CONVERSUS_PROVIDER,
#     CONVERSUS_RUN_OUTPUT_DIR, CONVERSUS_GATE_TODO_THRESHOLD,
#     CONVERSUS_GATE_SKIP_TODO_CHECK, CONVERSUS_INTEGRATION) still
#     referenced.
#
# Bash 3.2 compatible. Single-script-file shape (AD-19).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ADAPTER="${REPO_ROOT}/scripts/dispatch/adapters/tool/conversus.sh"

passed=0
failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1" >&2; failed=$((failed + 1)); }

if [ ! -f "$ADAPTER" ]; then
  fail "adapter missing: $ADAPTER"
  echo "FAIL: m026-p02-adapter-invariants.sh" >&2
  exit 1
fi

SCRATCH="$(mktemp -d -t m026-p02-invariants.XXXXXX)"
trap 'rm -rf "$SCRATCH"' EXIT

# -----------------------------------------------------------------------
# 1. Bash 3.2 forbidden-token scan. Strip full-line comments so the
#    spec-documenting comments don't trip the scanner.
# -----------------------------------------------------------------------
if bash -n "$ADAPTER" 2>/dev/null; then
  pass "bash -n parse check"
else
  fail "bash -n parse check"
fi

# assoc-array declaration.
if grep -v -E '^[[:space:]]*#' "$ADAPTER" | grep -nE '\bdeclare[[:space:]]+-A\b' >/dev/null 2>&1; then
  fail "assoc-array declaration token present"
else
  pass "no assoc-array declaration token"
fi
# mapfile / readarray.
if grep -v -E '^[[:space:]]*#' "$ADAPTER" | grep -nE '\b(mapfile|readarray)\b' >/dev/null 2>&1; then
  fail "mapfile or readarray token present"
else
  pass "no mapfile/readarray token"
fi
# Process substitution <(...) or >(...).
if grep -v -E '^[[:space:]]*#' "$ADAPTER" | grep -nE '<\(|>\(' >/dev/null 2>&1; then
  fail "process substitution present"
else
  pass "no process substitution"
fi

# -----------------------------------------------------------------------
# 2. Exit-code contract: missing preset → 1.
# -----------------------------------------------------------------------
NONEXIST_ART="${SCRATCH}/artifact.md"
echo "# stub" > "$NONEXIST_ART"
CONVERSUS_STUB=1 bash "$ADAPTER" gate nope-missing-preset "$NONEXIST_ART" "${SCRATCH}/out.md" >/dev/null 2>&1
rc=$?
if [ $rc -eq 1 ]; then
  pass "missing preset → exit 1"
else
  fail "missing preset expected exit 1, got $rc"
fi

# -----------------------------------------------------------------------
# 3. Exit-code contract: stub PASS → 0.
# -----------------------------------------------------------------------
STUB_PASS_OUT="${SCRATCH}/stub-pass.md"
CONVERSUS_STUB=1 bash "$ADAPTER" gate spec-pressure-test "$NONEXIST_ART" "$STUB_PASS_OUT" >/dev/null 2>&1
rc=$?
if [ $rc -eq 0 ]; then
  pass "stub PASS → exit 0"
else
  fail "stub PASS expected exit 0, got $rc"
fi

# -----------------------------------------------------------------------
# 4. Exit-code contract: stub BLOCK → 2.
# -----------------------------------------------------------------------
STUB_BLOCK_OUT="${SCRATCH}/stub-block.md"
CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=BLOCK bash "$ADAPTER" gate spec-pressure-test "$NONEXIST_ART" "$STUB_BLOCK_OUT" >/dev/null 2>&1
rc=$?
if [ $rc -eq 2 ]; then
  pass "stub BLOCK → exit 2"
else
  fail "stub BLOCK expected exit 2, got $rc"
fi

# -----------------------------------------------------------------------
# 5. gate-result frontmatter key-set. Stub-mode copies the canned
#    fixture verbatim, which already carries the canonical keys. Real-
#    mode writes the same keys from the adapter HEREDOC — verify that
#    key-set is still present in the adapter source (the HEREDOC we
#    cannot easily exercise without a real conversus run).
# -----------------------------------------------------------------------
FIXTURE_PASS="${REPO_ROOT}/tests/fixtures/gate-result-pass.md"
if [ -f "$FIXTURE_PASS" ]; then
  if grep -qE '^verdict:' "$FIXTURE_PASS"; then
    pass "stub fixture has verdict: frontmatter"
  else
    fail "stub fixture missing verdict:"
  fi
else
  fail "stub fixture missing: $FIXTURE_PASS"
fi

# Adapter HEREDOC key-set: grep the real-mode HEREDOC block for all
# eight frontmatter keys. Each key must appear on its own line in the
# adapter source.
for key in verdict disputes rationale source_hash preset artifact conversus_output_dir conversus_config; do
  if grep -qE "^${key}:" "$ADAPTER"; then
    pass "adapter HEREDOC carries key: ${key}"
  else
    fail "adapter HEREDOC missing key: ${key}"
  fi
done

# -----------------------------------------------------------------------
# 6. D019 TODO pre-flight block still present.
# -----------------------------------------------------------------------
if grep -qE '<TODO: marker\(s\); gate refuses unauthored drafts' "$ADAPTER"; then
  pass "D019 TODO pre-flight error message present"
else
  fail "D019 TODO pre-flight error message missing"
fi
if grep -qE 'CONVERSUS_GATE_SKIP_TODO_CHECK' "$ADAPTER"; then
  pass "TODO-guard bypass env var referenced"
else
  fail "TODO-guard bypass env var missing"
fi

# -----------------------------------------------------------------------
# 7. Full env-var set referenced.
# -----------------------------------------------------------------------
for var in CONVERSUS_STUB CONVERSUS_STUB_VERDICT CONVERSUS_HOME CONVERSUS_STRICT CONVERSUS_PROVIDER CONVERSUS_RUN_OUTPUT_DIR CONVERSUS_GATE_TODO_THRESHOLD CONVERSUS_GATE_SKIP_TODO_CHECK; do
  if grep -qE "\\\$\\{${var}:-" "$ADAPTER"; then
    pass "env var referenced: ${var}"
  else
    fail "env var missing: ${var}"
  fi
done

# CONVERSUS_INTEGRATION is referenced by the test shim rather than the
# adapter directly; grep the shim.
SHIM="${REPO_ROOT}/tests/test-conversus-adapter-shim.sh"
if [ -f "$SHIM" ]; then
  if grep -qE 'CONVERSUS_INTEGRATION' "$SHIM"; then
    pass "env var referenced in shim: CONVERSUS_INTEGRATION"
  else
    fail "env var missing from shim: CONVERSUS_INTEGRATION"
  fi
else
  fail "test shim missing: $SHIM"
fi

# -----------------------------------------------------------------------
# 8. CONVERSUS_EDITION env var documented (new for T01).
# -----------------------------------------------------------------------
if grep -qE 'CONVERSUS_EDITION' "$ADAPTER"; then
  pass "CONVERSUS_EDITION env var referenced"
else
  fail "CONVERSUS_EDITION env var missing"
fi

# -----------------------------------------------------------------------
# 9. Filename-routed adapter auto-discovery invariant: no new adapter
#    files under scripts/dispatch/adapters/tool/ beyond the known set.
# -----------------------------------------------------------------------
TOOL_DIR="${REPO_ROOT}/scripts/dispatch/adapters/tool"
if [ -d "$TOOL_DIR" ]; then
  # Known files: conversus.sh, conversus-synth.py, README (if any).
  unexpected=""
  for f in "$TOOL_DIR"/*; do
    base="$(basename "$f")"
    case "$base" in
      conversus.sh|conversus-synth.py|README.md|README) : ;;
      *) unexpected="$unexpected $base" ;;
    esac
  done
  if [ -z "$unexpected" ]; then
    pass "no unexpected adapter files in tool/"
  else
    fail "unexpected files in tool/:${unexpected}"
  fi
else
  fail "tool adapter dir missing: $TOOL_DIR"
fi

echo "SUMMARY: m026-p02-adapter-invariants.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m026-p02-adapter-invariants.sh"
  exit 0
fi
echo "FAIL: m026-p02-adapter-invariants.sh" >&2
exit 1
