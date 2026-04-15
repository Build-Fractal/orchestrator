#!/usr/bin/env bash
set -eu

# Search non-exempt directories for references to deleted paths.
# Exemptions:
#   - .git                       — VCS metadata
#   - .orchestrator              — historical artifacts (immutable)
#   - scripts/migrate            — migration adapters (reference .specify as source)
#   - tests/fixtures             — migration test fixtures (simulate spec-kit)
#   - specs/                     — SDD feature specs (historical + current M015 spec describing the deletions)
#   - .planning/                 — pre-project research (historical)
#   - CHANGELOG.md               — historical entries
#   - References handled by P03  — see ALLOW_DOC_REFRAME_FILES
#   - M015/P01 verify scripts    — they legitimately name the deleted paths as assertions
#   - commands/migrate.md        — migration command doc (references spec-kit as migration source)
#   - scripts/state/detect-speckit.sh           — migration detector (reads spec-kit layout)
#   - scripts/dispatch/adapters/format/speckit.sh — format adapter for spec-kit imports
#
# Documentation files slated for P03 reframe are tolerated here. T04
# ensures non-doc references are gone; P03's verify scripts will
# ensure doc references are gone after the reframe.

ALLOW_DOC_REFRAME_FILES="README.md|CLAUDE.md|references/installation.md|references/architecture.md|docs/getting-started.md"
ALLOW_SELF_REFERENCE="scripts/verify/m015-p01-no-extension-yml.sh|scripts/verify/m015-p01-no-speckit-commands.sh|scripts/verify/m015-p01-no-specify-bash.sh|scripts/verify/m015-p01-no-specify-templates.sh|scripts/verify/m015-p01-no-extension-test-artifacts.sh|scripts/verify/m015-p01-no-stale-refs.sh"
ALLOW_MIGRATION_PATHS="commands/migrate\.md|scripts/state/detect-speckit\.sh|scripts/dispatch/adapters/format/speckit\.sh"

# BSD grep's --exclude-dir matches on directory basenames, so we also post-filter
# with grep -Ev to strip exempt path prefixes.
matches=$(grep -rln \
  'extension\.yml\|\.specify/scripts/bash\|\.specify/templates/commands\|agent-file-template\.md\|checklist-template\.md\|constitution-template\.md\|plan-template\.md\|spec-template\.md\|tasks-template\.md\|\.claude/commands/speckit\.' \
  --exclude-dir=node_modules \
  --exclude-dir=.git \
  --exclude-dir='.orchestrator' \
  --exclude-dir='scripts/migrate' \
  --exclude-dir='tests/fixtures' \
  --exclude='CHANGELOG.md' \
  . 2>/dev/null \
  | grep -Ev "^\./(\.orchestrator|scripts/migrate|tests/fixtures|specs|\.planning)/" \
  | grep -Ev "^\./($ALLOW_DOC_REFRAME_FILES)$" \
  | grep -Ev "^\./($ALLOW_SELF_REFERENCE)$" \
  | grep -Ev "^\./($ALLOW_MIGRATION_PATHS)$" \
  || true)

if [ -n "$matches" ]; then
  echo "FAIL: stale references to deleted paths remain in:"
  echo "$matches"
  exit 1
fi
echo "PASS: no stale references to deleted paths in non-doc files"
