#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INGEST="$PROJECT_ROOT/scripts/knowledge/ingest-spec.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TMP_ROOT/knowledge/spec/non-goal"
mkdir -p "$TMP_ROOT/.orchestrator"

cat > "$TMP_ROOT/test-spec.md" <<'SPEC'
# Test Spec

## Non-Goals

- Expanding autonomy to credential prompts.
- Hardening interactive commands.
SPEC

output="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-spec 2>&1)" || true

if echo "$output" | grep -q "CREATED: SPEC-NG-001" && echo "$output" | grep -q "CREATED: SPEC-NG-002"; then
  echo "PASS: 2 non-goals classified as spec/non-goal with SPEC-NG-NNN IDs"
else
  echo "FAIL: Expected CREATED: SPEC-NG-001 and SPEC-NG-002"
  echo "Output: $output"
  exit 1
fi
