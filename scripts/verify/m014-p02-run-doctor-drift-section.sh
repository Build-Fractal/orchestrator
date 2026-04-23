#!/usr/bin/env bash
# Gate: verify run-doctor.sh wires the Runtime Instruction Drift section.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RUN_DOCTOR="${PROJECT_ROOT}/scripts/diagnostics/run-doctor.sh"

if [ ! -f "$RUN_DOCTOR" ]; then echo "FAIL: run-doctor.sh missing" >&2; exit 1; fi

# Shape checks.
if ! grep -q 'Runtime Instruction Drift' "$RUN_DOCTOR"; then
  echo "FAIL: Runtime Instruction Drift section not wired" >&2
  exit 1
fi
if ! grep -q -- '--check drift' "$RUN_DOCTOR"; then
  echo "FAIL: --check drift invocation missing" >&2
  exit 1
fi

# Verify advisory=1 (the fourth positional arg is "1").
if ! grep -E 'run_check "Runtime Instruction Drift".*"1"' "$RUN_DOCTOR" >/dev/null; then
  echo "FAIL: Runtime Instruction Drift is not advisory (expected fourth arg \"1\")" >&2
  exit 1
fi

# Integration test: run-doctor against a scratch project with matching regions.
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
mkdir -p "$SCRATCH/.orchestrator"

cat > "$SCRATCH/CLAUDE.md" <<'EOF'
# >>> orchestrator:recent-changes >>>
- aligned
# <<< orchestrator:recent-changes <<<
EOF
cp "$SCRATCH/CLAUDE.md" "$SCRATCH/AGENTS.md"

OUT="$(bash "$RUN_DOCTOR" --root "$SCRATCH" 2>&1 || true)"
if ! echo "$OUT" | grep -q 'Runtime Instruction Drift'; then
  echo "FAIL: run-doctor did not display Runtime Instruction Drift section" >&2
  exit 1
fi
if ! echo "$OUT" | grep -q 'DOCTOR:DRIFT'; then
  echo "FAIL: run-doctor did not surface DOCTOR:DRIFT output" >&2
  exit 1
fi

echo "PASS: run-doctor.sh surfaces Runtime Instruction Drift section"
exit 0
