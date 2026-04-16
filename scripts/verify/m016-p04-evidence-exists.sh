#!/usr/bin/env bash
# m016-p04-evidence-exists.sh — Verify attestation file exists with prompt_count: 0
# Checks that the zero-prompts attestation evidence file exists and contains
# the required prompt_count: 0 field.
# Bash 3.2 compatible. Standalone.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
attestation="$root/.orchestrator/milestones/M016/phases/P04/evidence/zero-prompts-attestation.md"

if [ ! -f "$attestation" ]; then
  echo "FAIL: attestation file missing: $attestation"
  exit 1
fi

if grep -q 'prompt_count: 0' "$attestation"; then
  echo "PASS: attestation file exists with prompt_count: 0"
  exit 0
else
  echo "FAIL: attestation file does not contain prompt_count: 0"
  exit 1
fi
