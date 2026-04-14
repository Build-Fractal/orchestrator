#!/usr/bin/env bash
# m008-p06-skills-coverage.sh — verify 12 orchestrator skill files with required frontmatter.
#
# Checks:
#   1. packaging/skills/ contains exactly 12 orchestrator-*.md files.
#   2. Each file carries the required frontmatter keys:
#        schema_version, type, name, namespace, description,
#        runtime_compatibility, command_file.
#
# Exits 0 on PASS, 1 on FAIL. Bash 3.2 compatible.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILLS_DIR="$REPO_ROOT/packaging/skills"

if [ ! -d "$SKILLS_DIR" ]; then
    echo "FAIL: packaging/skills/ directory not found" >&2
    exit 1
fi

# Count orchestrator-*.md files (bash 3.2 safe: iterate, count, handle null glob).
count=0
files=""
for f in "$SKILLS_DIR"/orchestrator-*.md; do
    [ -e "$f" ] || continue
    count=$((count + 1))
    files="$files $f"
done

if [ "$count" -ne 12 ]; then
    echo "FAIL: expected 12 packaging/skills/orchestrator-*.md files, found $count" >&2
    exit 1
fi

REQUIRED_KEYS="schema_version type name namespace description runtime_compatibility command_file"

bad=0
for f in $files; do
    rel=${f#"$REPO_ROOT/"}
    for key in $REQUIRED_KEYS; do
        if ! grep -q -E "^${key}:" "$f"; then
            echo "FAIL: $rel missing frontmatter key: $key" >&2
            bad=1
        fi
    done
done

if [ "$bad" -ne 0 ]; then
    exit 1
fi

echo "PASS: 12 orchestrator skill files present with required frontmatter"
exit 0
