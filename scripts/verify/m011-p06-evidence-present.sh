#!/usr/bin/env bash
# scripts/verify/m011-p06-evidence-present.sh
# Assert the P06 dogfood evidence transcripts exist and contain the
# expected tokens: CREATED:, spec_chunks_present=true, SPEC-US-,
# elapsed_seconds=<N>, N < 60.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
EVID="$REPO/.orchestrator/milestones/M011/phases/P06/evidence"

fail=0

check_exists() {
  local f="$1"
  if [ ! -s "$EVID/$f" ]; then
    printf 'FAIL[evidence-exists]: %s missing or empty\n' "$f"
    fail=1
  fi
}

check_exists ingest-transcript.txt
check_exists spec-metrics.txt
check_exists story-ids.txt
check_exists timing.txt

if [ "$fail" -ne 0 ]; then
  exit 1
fi

# Token checks
if ! grep -q '^CREATED:' "$EVID/ingest-transcript.txt"; then
  printf 'FAIL[ingest-transcript]: no CREATED: line found\n'
  fail=1
fi

if ! grep -Fq 'spec_chunks_present=true' "$EVID/spec-metrics.txt"; then
  printf 'FAIL[spec-metrics]: spec_chunks_present=true not found\n'
  fail=1
fi

if ! grep -q '^SPEC-US-' "$EVID/story-ids.txt"; then
  printf 'FAIL[story-ids]: no SPEC-US- line found\n'
  fail=1
fi

# Extract elapsed_seconds integer and gate on < 60.
ELAPSED_LINE="$(grep -E '^elapsed_seconds=[0-9]+$' "$EVID/timing.txt" | head -1)"
if [ -z "$ELAPSED_LINE" ]; then
  printf 'FAIL[timing]: elapsed_seconds=<N> line not found in timing.txt\n'
  fail=1
else
  ELAPSED="${ELAPSED_LINE#elapsed_seconds=}"
  if [ "$ELAPSED" -ge 60 ]; then
    printf 'FAIL[timing]: dogfood pipeline took %s seconds (expected < 60)\n' "$ELAPSED"
    fail=1
  fi
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS: P06 dogfood evidence present and within timing budget"
