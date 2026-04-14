#!/usr/bin/env bash
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CMD="$REPO_ROOT/commands/init.md"

test -f "$CMD" || { echo "FAIL: commands/init.md not found" >&2; exit 1; }

# MEM012 structure
head -3 "$CMD" | grep -q '^description:' || { echo "FAIL: missing description frontmatter" >&2; exit 1; }
grep -q '^# orchestrator:init' "$CMD" || { echo "FAIL: missing title" >&2; exit 1; }
grep -q '^## Workflow' "$CMD" || { echo "FAIL: missing Workflow section" >&2; exit 1; }
grep -q '^## Flags' "$CMD" || { echo "FAIL: missing Flags section" >&2; exit 1; }
grep -q '^## Exit Codes' "$CMD" || { echo "FAIL: missing Exit Codes section" >&2; exit 1; }
grep -q '^## Referenced Scripts' "$CMD" || { echo "FAIL: missing Referenced Scripts section" >&2; exit 1; }

# Required flag documentation
for flag in "\-\-dry-run" "\-\-force" "\-\-project-dir" "\-\-runtime"; do
  grep -qE "$flag" "$CMD" || { echo "FAIL: flag $flag not documented" >&2; exit 1; }
done

# Cross-references exist
grep -q 'scripts/lifecycle/init-project.sh' "$CMD" || { echo "FAIL: no reference to init-project.sh" >&2; exit 1; }
grep -q 'templates/project-instruction.md' "$CMD" || { echo "FAIL: no reference to project-instruction.md template" >&2; exit 1; }

echo "PASS: commands/init.md conforms to MEM012"
