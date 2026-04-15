#!/usr/bin/env bash
set -eu
f="scripts/migrate/lib/idempotency.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '\.orchestrator' "$f" || { echo "FAIL: idempotency.sh does not probe .orchestrator/"; exit 1; }
grep -q '\.specify/orchestrator' "$f" || { echo "FAIL: idempotency.sh does not probe .specify/orchestrator/"; exit 1; }
grep -q 'KNOWLEDGE-INDEX.md' "$f" || { echo "FAIL: idempotency.sh missing KNOWLEDGE-INDEX.md probe"; exit 1; }
echo "PASS: idempotency.sh probes both .orchestrator/ and .specify/orchestrator/"
