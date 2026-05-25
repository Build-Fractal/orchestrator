#!/usr/bin/env bash
# tools/verify/m041-p03-doctor-recommendation.sh -- Verify detective-recommend.sh
# emits RECOMMEND for orchestrator-internal paths (FR-8 cross-command hook).
# Bash 3.2 compatible.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

ORCH_ROOT="$(bash scripts/state/resolve-root.sh 2>/dev/null || echo ".orchestrator")"
case "$ORCH_ROOT" in /*) ;; *) ORCH_ROOT="$(pwd)/$ORCH_ROOT" ;; esac

tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile"' EXIT

bash scripts/diagnostics/detective-recommend.sh \
  --symptom "test orphan reference" \
  --path "$ORCH_ROOT/scripts/nonexistent.sh" 2>"$tmpfile"

if grep -qF "RECOMMEND: orchestrator:detective" "$tmpfile"; then
  echo "PASS: detective-recommend.sh emits RECOMMEND for orchestrator-internal path"
else
  echo "FAIL: no RECOMMEND line on stderr for orchestrator-internal path"
  exit 1
fi
