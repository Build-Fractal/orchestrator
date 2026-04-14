#!/usr/bin/env bash
# m008-p06-skill-spec.sh — verify packaging/SKILL.md exists and covers required sections.
#
# Checks:
#   1. packaging/SKILL.md exists.
#   2. File is at least 40 lines long (substantive specification).
#   3. File mentions: runtime_compatibility, name:, namespace:, command_file:.
#
# Exits 0 on PASS, 1 on FAIL. Bash 3.2 compatible.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPEC_PATH="$REPO_ROOT/packaging/SKILL.md"

if [ ! -f "$SPEC_PATH" ]; then
    echo "FAIL: packaging/SKILL.md not found at $SPEC_PATH" >&2
    exit 1
fi

line_count=$(wc -l < "$SPEC_PATH" | tr -d ' ')
if [ "$line_count" -lt 40 ]; then
    echo "FAIL: packaging/SKILL.md too short: $line_count lines (min 40)" >&2
    exit 1
fi

missing=""
for needle in "runtime_compatibility" "name:" "namespace:" "command_file:"; do
    if ! grep -q -F "$needle" "$SPEC_PATH"; then
        missing="$missing $needle"
    fi
done

if [ -n "$missing" ]; then
    echo "FAIL: packaging/SKILL.md missing required tokens:$missing" >&2
    exit 1
fi

echo "PASS: packaging/SKILL.md specification present"
exit 0
