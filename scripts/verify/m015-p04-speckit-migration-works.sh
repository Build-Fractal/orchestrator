#!/usr/bin/env bash
set -eu
# Verify: the spec-kit migration adapter produced a valid .orchestrator/
# from the spec-kit-shaped fixture. T02 runs scripts/migrate/migrate.sh
# against a temp-dir build of tests/fixtures/m015-p04-speckit-migration/
# and captures the transcript to evidence/migration-adapter-transcript.txt.
# The transcript must contain (a) a successful-run marker, (b) the path
# to a produced .orchestrator/ directory, and (c) evidence that
# memory/constitution.md was migrated.
TRANSCRIPT=.orchestrator/milestones/M015/phases/P04/evidence/migration-adapter-transcript.txt
test -f "$TRANSCRIPT" || { echo "FAIL: migration transcript missing at $TRANSCRIPT"; exit 1; }
test -s "$TRANSCRIPT" || { echo "FAIL: migration transcript empty"; exit 1; }
fail=0
if ! grep -q "MIGRATION_SUCCESS" "$TRANSCRIPT"; then
  echo "FAIL: transcript missing MIGRATION_SUCCESS marker"
  fail=1
fi
if ! grep -q ".orchestrator/memory/constitution.md" "$TRANSCRIPT"; then
  echo "FAIL: transcript missing evidence of constitution migration"
  fail=1
fi
# Fixture build script must also exist
BUILD=tests/fixtures/m015-p04-speckit-migration/build-fixture.sh
test -f "$BUILD" || { echo "FAIL: fixture build script missing at $BUILD"; fail=1; }
if [ "$fail" -ne 0 ]; then exit 1; fi
echo "PASS: migration adapter transcript has success markers + fixture exists"
