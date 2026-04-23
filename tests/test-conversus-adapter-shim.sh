#!/usr/bin/env bash
# tests/test-conversus-adapter-shim.sh
#
# End-to-end test for the conversus gate adapter shim
# (scripts/dispatch/adapters/tool/conversus.sh `gate` subcommand).
#
# Guards against the class of drift that landed at M011 close: an
# adapter written against a speculative upstream CLI that never shipped.
# By exercising the full path against a REAL conversus binary (with the
# `mock` provider so no API cost), we catch breakage when any of these
# change:
#   - conversus's `run` subcommand signature
#   - conversus's config schema (mode/target/output/agents/arbiter)
#   - canonical synthesis output path (output/summary/final.md)
#   - the linter.output_contract JSON schema we parse for PASS/BLOCK
#
# Gated by CONVERSUS_INTEGRATION=1 so CI + normal test runs skip it
# cleanly when the binary isn't installed. The stub-mode path (which
# does NOT shell out to conversus) is exercised unconditionally.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

ADAPTER="${PROJECT_ROOT}/scripts/dispatch/adapters/tool/conversus.sh"
SYNTH="${PROJECT_ROOT}/scripts/dispatch/adapters/tool/conversus-synth.py"
PRESET="${PROJECT_ROOT}/templates/conversus-presets/spec-pressure-test.yml"

for f in "$ADAPTER" "$SYNTH" "$PRESET"; do
  if [ ! -e "$f" ]; then
    echo "FAIL: upstream artifact missing: $f" >&2
    exit 1
  fi
done

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1" >&2; exit 1; }

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

# Tiny artifact — just enough to feed conversus a target file.
ARTIFACT="${SCRATCH}/tiny-spec.md"
cat > "$ARTIFACT" <<'EOF'
# Tiny Spec

## User Story

As a tester, I want this spec to exist so the conversus gate has something
to chew on.

## Functional Requirements

- FR-1: The spec shall exist.
EOF

# ---------------------------------------------------------------------------
# 1. Stub-mode path — adapter must still honor canned fixtures without
#    touching any conversus binary. This is the existing contract.
# ---------------------------------------------------------------------------
STUB_OUT="${SCRATCH}/stub-verdict.md"
CONVERSUS_STUB=1 bash "$ADAPTER" gate spec-pressure-test "$ARTIFACT" "$STUB_OUT" >/dev/null
rc=$?
if [ $rc -ne 0 ]; then
  fail "stub mode rc=$rc (expected 0 for canned PASS fixture)"
fi
if [ ! -f "$STUB_OUT" ]; then
  fail "stub mode did not produce output at $STUB_OUT"
fi
if ! grep -qE '^verdict:' "$STUB_OUT"; then
  fail "stub output missing verdict: frontmatter"
fi
pass "stub-mode gate produces verdict-bearing output"

# ---------------------------------------------------------------------------
# 1b. Pre-flight TODO guard — adapter must refuse artifacts that still
#     contain `<TODO:` section placeholders. See D019.
# ---------------------------------------------------------------------------
TODO_ARTIFACT="${SCRATCH}/unauthored-spec.md"
cat > "$TODO_ARTIFACT" <<'EOF'
# Half-Authored Spec

## Problem Statement

<TODO: fill in the problem>

## User Story 1

<TODO: who/what/why>
EOF

TODO_OUT="${SCRATCH}/todo-verdict.md"
# Guard should fire BEFORE stub-mode kicks in, so CONVERSUS_STUB=1 must not
# save us here.
CONVERSUS_STUB=1 bash "$ADAPTER" gate spec-pressure-test "$TODO_ARTIFACT" "$TODO_OUT" 2>/dev/null
rc=$?
if [ $rc -eq 0 ]; then
  fail "gate accepted TODO-filled artifact (expected non-zero exit; D019 pre-flight)"
fi
pass "gate refuses TODO-filled artifact with non-zero exit"

# Bypass env var must actually bypass the guard.
CONVERSUS_STUB=1 CONVERSUS_GATE_SKIP_TODO_CHECK=1 \
  bash "$ADAPTER" gate spec-pressure-test "$TODO_ARTIFACT" "$TODO_OUT" >/dev/null 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  fail "CONVERSUS_GATE_SKIP_TODO_CHECK=1 did not bypass the guard (rc=$rc)"
fi
pass "CONVERSUS_GATE_SKIP_TODO_CHECK=1 bypasses the pre-flight guard"

# ---------------------------------------------------------------------------
# 2. Synth helper is pure — exercise it directly without conversus.
# ---------------------------------------------------------------------------
# Find any python3 with pyyaml; prefer conversus venv if present.
VENV_PY=""
if [ -x "/Users/$(whoami)/.local/pipx/venvs/conversus/bin/python" ]; then
  VENV_PY="/Users/$(whoami)/.local/pipx/venvs/conversus/bin/python"
elif command -v conversus >/dev/null 2>&1; then
  _CBIN="$(command -v conversus)"
  VENV_PY="$(head -n 1 "$_CBIN" | sed -E 's|^#!([^[:space:]]+).*|\1|')"
fi
if [ -n "$VENV_PY" ] && [ -x "$VENV_PY" ] && "$VENV_PY" -c "import yaml" >/dev/null 2>&1; then
  SYNTH_OUT="${SCRATCH}/synth.yml"
  "$VENV_PY" "$SYNTH" \
    --preset "$PRESET" \
    --artifact "$ARTIFACT" \
    --output-dir "${SCRATCH}/synth-output" \
    --out "$SYNTH_OUT"
  if [ ! -f "$SYNTH_OUT" ]; then
    fail "synth did not write $SYNTH_OUT"
  fi
  for key in "mode:" "target:" "output:" "agents:" "arbiter:"; do
    if ! grep -qE "^${key}" "$SYNTH_OUT"; then
      fail "synth output missing required key: $key"
    fi
  done
  if ! grep -qE "role: blue" "$SYNTH_OUT"; then
    fail "synth did not derive 'role: blue' for blue-advocate"
  fi
  if ! grep -qE "role: red" "$SYNTH_OUT"; then
    fail "synth did not derive 'role: red' for red-advocate"
  fi
  pass "synth emits valid conversus.yml with red/blue role hints"
else
  echo "SKIP: no python3-with-pyyaml available — synth-direct check bypassed"
fi

# ---------------------------------------------------------------------------
# 3. Full gate path against real binary (env-gated).
#    Uses --provider mock so no API key, no cost, deterministic output.
# ---------------------------------------------------------------------------
if [ "${CONVERSUS_INTEGRATION:-0}" != "1" ]; then
  echo "SKIP: CONVERSUS_INTEGRATION!=1 — real-binary gate path not exercised"
  echo "ALL TESTS: pass (stub path + synth-direct; integration skipped)"
  exit 0
fi

if ! command -v conversus >/dev/null 2>&1; then
  fail "CONVERSUS_INTEGRATION=1 but no conversus binary on PATH"
fi

GATE_OUT="${SCRATCH}/gate-result.md"
RUN_OUT_DIR="${SCRATCH}/conversus-run"
CONVERSUS_PROVIDER=mock \
CONVERSUS_RUN_OUTPUT_DIR="$RUN_OUT_DIR" \
  bash "$ADAPTER" gate --strict spec-pressure-test "$ARTIFACT" "$GATE_OUT"
rc=$?

# Expect 0 (PASS) or 2 (BLOCK) — both are valid verdicts. Anything else
# means the adapter itself hit an error.
if [ $rc -ne 0 ] && [ $rc -ne 2 ]; then
  fail "gate adapter returned rc=$rc (expected 0 or 2; 1 means adapter/CLI drift)"
fi

if [ ! -f "$GATE_OUT" ]; then
  fail "gate did not produce output at $GATE_OUT"
fi
if ! grep -qE '^verdict: "(PASS|BLOCK)"' "$GATE_OUT"; then
  fail "gate output missing 'verdict: PASS|BLOCK' frontmatter"
fi
if ! grep -qE '^disputes: [0-9]+' "$GATE_OUT"; then
  fail "gate output missing 'disputes: N' frontmatter"
fi
if [ ! -f "${RUN_OUT_DIR}/summary/final.md" ]; then
  fail "conversus synthesis not at expected path ${RUN_OUT_DIR}/summary/final.md"
fi
if [ ! -f "${RUN_OUT_DIR}/conversus.yml" ]; then
  fail "synthesized conversus.yml not preserved for audit"
fi

pass "full gate path produces verdict-bearing output against real binary"
echo "ALL TESTS: pass"
