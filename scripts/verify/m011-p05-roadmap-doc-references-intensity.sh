#!/usr/bin/env bash
# scripts/verify/m011-p05-roadmap-doc-references-intensity.sh
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$REPO/commands/roadmap.md"

if ! grep -Fq "intensity-gate.sh --stage roadmap" "$DOC"; then
  echo "FAIL: roadmap.md missing intensity-gate.sh --stage roadmap call"
  exit 1
fi

if ! grep -Fq "single-pass" "$DOC"; then
  echo "FAIL: roadmap.md missing 'single-pass' substep description"
  exit 1
fi

if ! grep -Fq "collaborative-loop" "$DOC"; then
  echo "FAIL: roadmap.md missing 'collaborative-loop' substep description"
  exit 1
fi

if ! grep -Fq "/orchestrator-discuss" "$DOC"; then
  echo "FAIL: roadmap.md missing delegation to /orchestrator-discuss"
  exit 1
fi

echo "PASS: roadmap.md documents intensity-aware interaction"
