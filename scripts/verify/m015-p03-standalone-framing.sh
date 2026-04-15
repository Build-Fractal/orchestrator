#!/usr/bin/env bash
set -eu
# Verify: the five primary standalone docs no longer describe the
# orchestrator as "a spec-kit extension" in current-state framing.
# Permitted: (a) changelog-style historical prose with explicit history
# markers, (b) migration-context callouts. Both must include an
# explicit MIGRATION or HISTORICAL marker nearby — we check for a
# mention of "migration" or "history" on the same line, or require
# the phrase to appear only inside known safe contexts.
#
# Implementation: disallow the phrase "spec-kit extension" entirely
# in the five primary docs. T02 must use alternative phrasing
# ("spec-kit host", "spec-kit extension host (historically)", etc.)
# in any preserved historical context. Migration contexts live in
# docs/migrating-from-speckit.md, not in the primary docs.
PRIMARIES="README.md CLAUDE.md references/architecture.md references/installation.md docs/getting-started.md"
fail=0
for f in $PRIMARIES; do
  test -f "$f" || { echo "FAIL: $f missing"; fail=1; continue; }
  if grep -q "spec-kit extension" "$f"; then
    echo "FAIL: '$f' still contains 'spec-kit extension'"
    fail=1
  fi
done
if [ "$fail" -ne 0 ]; then exit 1; fi
echo "PASS: no 'spec-kit extension' framing in primary standalone docs"
