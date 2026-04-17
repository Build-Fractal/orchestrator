#!/usr/bin/env bash
# scripts/verify/m011-p07-e2e-arbitrary-spec.sh
# End-to-end gate for the format-agnostic ingest pipeline on a foreign
# (non-spec-kit-shaped) markdown PRD. Runs the full pipeline in stub mode
# so the check is deterministic: NORMALIZER_STUB=1 + CONVERSUS_STUB=1.
#
# Stages exercised:
#   1. detect-spec-shape.sh  -> shape=foreign
#   2. normalize-spec.sh     -> NORMALIZED: + specs/<slug>/spec.md exists
#   3. conversus.sh gate     -> verdict: "PASS"
#   4. ingest-spec.sh        -> >=1 CREATED: line
#   5. spec-metrics.sh       -> spec_chunks_present=true
# Timing budget: < 120 seconds end-to-end.
#
# Bash 3.2 compatible; sandboxed under mktemp -d with EXIT-trap cleanup.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

SLUG="019-foo"

# Minimum project tree in the sandbox.
mkdir -p "$TMP/specs/${SLUG}"
mkdir -p "$TMP/tests/fixtures"
mkdir -p "$TMP/knowledge/spec"
mkdir -p "$TMP/.orchestrator"
mkdir -p "$TMP/Downloads"

# Copy fixtures the pipeline consumes. The normalize stub and the gate
# stubs both live under tests/fixtures/ in the sandbox so the production
# scripts resolve them relative to $TMP when invoked with $TMP as cwd.
cp "$REPO/tests/fixtures/arbitrary-prd.md" "$TMP/Downloads/arbitrary-prd.md"
cp "$REPO/tests/fixtures/normalized-stub.md" "$TMP/tests/fixtures/normalized-stub.md"
cp "$REPO/tests/fixtures/gate-result-pass.md" "$TMP/tests/fixtures/gate-result-pass.md"
cp "$REPO/tests/fixtures/gate-result-block.md" "$TMP/tests/fixtures/gate-result-block.md"

fail=0

T_START="$(date +%s)"

# --- Stage 1: detect-spec-shape.sh ---
DETECT_OUT="$(bash "$REPO/scripts/knowledge/detect-spec-shape.sh" --spec-path "$TMP/Downloads/arbitrary-prd.md" 2>/dev/null || echo '__err__')"
if ! printf '%s\n' "$DETECT_OUT" | grep -Fq -- 'shape=foreign'; then
  printf 'FAIL[detect]: expected shape=foreign, got:\n%s\n' "$DETECT_OUT"
  fail=1
fi

# --- Stage 2: normalize-spec.sh (stub mode) ---
cd "$TMP"
set +e
NORM_OUT="$(NORMALIZER_STUB=1 bash "$REPO/scripts/knowledge/normalize-spec.sh" \
  --spec-path "$TMP/Downloads/arbitrary-prd.md" \
  --slug "$SLUG" 2>&1)"
NORM_RC=$?
set -e
cd "$REPO"

if [ "$NORM_RC" -ne 0 ]; then
  printf 'FAIL[normalize]: exit=%s, output:\n%s\n' "$NORM_RC" "$NORM_OUT"
  fail=1
fi
if ! printf '%s\n' "$NORM_OUT" | grep -Fq -- 'NORMALIZED:'; then
  printf 'FAIL[normalize]: expected NORMALIZED: in output, got:\n%s\n' "$NORM_OUT"
  fail=1
fi
if [ ! -f "$TMP/specs/${SLUG}/spec.md" ]; then
  printf 'FAIL[normalize]: expected specs/%s/spec.md to exist\n' "$SLUG"
  fail=1
fi

# --- Stage 3: conversus.sh gate (stub PASS) ---
GATE_OUT_PATH="$TMP/gate-result.md"
set +e
GATE_OUT="$(CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=PASS bash "$REPO/scripts/dispatch/adapters/tool/conversus.sh" \
  gate normalize-fidelity "$TMP/specs/${SLUG}/spec.md" "$GATE_OUT_PATH" 2>&1)"
GATE_RC=$?
set -e

if [ "$GATE_RC" -ne 0 ]; then
  printf 'FAIL[gate]: exit=%s, output:\n%s\n' "$GATE_RC" "$GATE_OUT"
  fail=1
fi
if [ ! -f "$GATE_OUT_PATH" ]; then
  printf 'FAIL[gate]: expected gate-result.md at %s\n' "$GATE_OUT_PATH"
  fail=1
elif ! grep -Fq -- 'verdict: "PASS"' "$GATE_OUT_PATH"; then
  printf 'FAIL[gate]: gate-result.md did not contain verdict: "PASS"\n'
  fail=1
fi

# --- Stage 4: ingest-spec.sh ---
set +e
INGEST_OUT="$(PROJECT_ROOT="$TMP" bash "$REPO/scripts/knowledge/ingest-spec.sh" \
  --spec-path "$TMP/specs/${SLUG}/spec.md" \
  --slug "$SLUG" \
  --scope-tags "[project]" 2>&1)"
INGEST_RC=$?
set -e

if [ "$INGEST_RC" -ne 0 ]; then
  printf 'FAIL[ingest]: exit=%s, output:\n%s\n' "$INGEST_RC" "$INGEST_OUT"
  fail=1
fi
CREATED_LINES="$(printf '%s\n' "$INGEST_OUT" | grep -c '^CREATED:' || true)"
if [ "$CREATED_LINES" -lt 1 ]; then
  printf 'FAIL[ingest]: expected >=1 CREATED: line, got %s\n' "$CREATED_LINES"
  printf 'Output:\n%s\n' "$INGEST_OUT"
  fail=1
fi

# --- Stage 5: spec-metrics.sh ---
METRICS_OUT="$(bash "$REPO/scripts/state/spec-metrics.sh" "$TMP/.orchestrator" 2>/dev/null || echo '__err__')"
if ! printf '%s\n' "$METRICS_OUT" | grep -Fq -- 'spec_chunks_present=true'; then
  printf 'FAIL[metrics]: expected spec_chunks_present=true, got:\n%s\n' "$METRICS_OUT"
  fail=1
fi

T_END="$(date +%s)"
ELAPSED=$((T_END - T_START))

if [ "$ELAPSED" -ge 120 ]; then
  printf 'FAIL[timing]: elapsed=%s seconds exceeds 120s budget\n' "$ELAPSED"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

printf 'PASS: foreign-PRD e2e pipeline (detect -> normalize -> gate -> ingest -> metrics) elapsed_seconds=%s\n' "$ELAPSED"
exit 0
