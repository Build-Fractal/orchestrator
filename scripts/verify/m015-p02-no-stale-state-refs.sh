#!/usr/bin/env bash
set -eu
# Sweep retained runtime files for stale references to .specify/orchestrator
# or .specify/memory/constitution. Exempts: migration adapters, historical
# artifacts, and P03-reserved docs.
#
# ALLOW_P03_DOCS: P03 complete (M015) — all previously tolerated docs were
#   swept clean of legacy .specify/orchestrator and .specify/memory/constitution
#   references in T02 (primary 5 docs) and T03 (wider 13 docs). Allow-list is
#   sealed to a never-match sentinel; any future re-introduction of a legacy
#   path in these files will correctly FAIL this sweep.
# ALLOW_MIGRATION: migration adapters — target .specify as migration source.
# ALLOW_SELF_REFERENCE: verify scripts that legitimately name the legacy
#   .specify/orchestrator path as an assertion target. Includes:
#     - m015-p02-*.sh              : P02 verify scripts that assert absence
#     - m015-p03-*.sh              : P03 verify scripts that assert absence
#     - m015-p03-helpers/*.txt     : P03 immutable changelog snapshot
#                                    (pinned historical baseline)
#     - m015-p01-no-stale-refs.sh  : P01 verify (still greps stale patterns)
#     - m003-p07-*.sh              : M003 migration-source hardcode checks
#     - m008-p04-migrate-state-*.sh: M008 migration-behavior tests (fixture source)
#     - m008-p04-standalone-e2e.sh : asserts standalone runs do NOT leak
#                                    state to .specify/orchestrator/ (regression guard)
#     - m008-p04-derive-phase-no-hardcode.sh: asserts derive-phase.sh has
#                                    no hardcoded .specify/orchestrator path
#                                    (regression guard)
# P03 complete (M015): all previously tolerated docs swept clean of
# legacy .specify/orchestrator and .specify/memory/constitution
# references. Allow-list is sealed — any re-introduction of a legacy
# path in these files will now correctly FAIL this sweep.
ALLOW_P03_DOCS='__P03_COMPLETE_NEVER_MATCH__'
ALLOW_MIGRATION='commands/migrate\.md|scripts/state/detect-speckit\.sh|scripts/dispatch/adapters/format/speckit\.sh|scripts/migrate/.*|docs/migrating-from-speckit\.md'
ALLOW_SELF_REFERENCE='scripts/verify/m015-p02-.*\.sh|scripts/verify/m015-p03-.*\.sh|scripts/verify/m015-p03-helpers/.*\.txt|scripts/verify/m015-p01-no-stale-refs\.sh|scripts/verify/m003-p07-.*\.sh|scripts/verify/m008-p04-migrate-state-.*\.sh|scripts/verify/m008-p04-standalone-e2e\.sh|scripts/verify/m008-p04-derive-phase-no-hardcode\.sh'
matches=$(grep -rln \
  -e '\.specify/orchestrator' \
  -e '\.specify/memory/constitution' \
  --exclude-dir=node_modules \
  --exclude-dir=.git \
  --exclude-dir='.orchestrator' \
  --exclude-dir='tests/fixtures' \
  --exclude='CHANGELOG.md' \
  . 2>/dev/null \
  | grep -Ev '^\./(\.orchestrator|tests/fixtures|specs|\.planning)/' \
  | grep -Ev "^\./($ALLOW_P03_DOCS)$" \
  | grep -Ev "^\./($ALLOW_MIGRATION)$" \
  | grep -Ev "^\./($ALLOW_SELF_REFERENCE)$" \
  || true)
if [ -n "$matches" ]; then
  echo "FAIL: stale state-path references remain in:"
  echo "$matches"
  exit 1
fi
echo "PASS: no stale state-path references in non-exempt runtime files"
