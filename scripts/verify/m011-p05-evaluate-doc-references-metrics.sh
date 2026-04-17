#!/usr/bin/env bash
# scripts/verify/m011-p05-evaluate-doc-references-metrics.sh
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$REPO/commands/evaluate.md"

if ! grep -q "scripts/state/spec-metrics.sh" "$DOC"; then
  echo "FAIL: evaluate.md missing reference to scripts/state/spec-metrics.sh"
  exit 1
fi

if ! grep -q "spec_chunks_present" "$DOC"; then
  echo "FAIL: evaluate.md missing spec_chunks_present key description"
  exit 1
fi

if ! grep -q "metrics_source" "$DOC"; then
  echo "FAIL: evaluate.md missing metrics_source evaluation-field description"
  exit 1
fi

if ! grep -q "Chunks-first path" "$DOC"; then
  echo "FAIL: evaluate.md missing Chunks-first path heading"
  exit 1
fi

if ! grep -q "Raw-spec fallback" "$DOC"; then
  echo "FAIL: evaluate.md missing Raw-spec fallback heading"
  exit 1
fi

echo "PASS: evaluate.md references spec-metrics.sh path and keys"
