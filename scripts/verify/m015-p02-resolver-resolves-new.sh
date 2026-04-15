#!/usr/bin/env bash
set -eu
# Verify: resolver emits root=.orchestrator source=existing:.orchestrator
# when invoked from repo root with no overrides.
unset ORCHESTRATOR_ROOT
out=$(bash scripts/state/resolve-root.sh --verbose)
echo "$out" | grep -q '^root=\.orchestrator$' || { echo "FAIL: expected root=.orchestrator, got:"; echo "$out"; exit 1; }
echo "$out" | grep -q '^source=existing:\.orchestrator$' || { echo "FAIL: expected source=existing:.orchestrator, got:"; echo "$out"; exit 1; }
echo "PASS: resolver resolves to .orchestrator via existing:.orchestrator rule"
