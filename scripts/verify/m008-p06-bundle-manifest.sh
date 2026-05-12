#!/usr/bin/env bash
# m008-p06-bundle-manifest.sh — verify packaging/bundle/manifest.yml is valid.
#
# Checks:
#   - manifest.yml exists
#   - contains version: field
#   - skills: list has 13 entries
#   - hooks: list has 5 events (before-tasks, after-tasks, before-implement,
#     after-implement, before-commit)
#
# Bash 3.2 compatible. No python, no jq.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../.." && pwd)
MANIFEST="$REPO_ROOT/packaging/bundle/manifest.yml"

EXPECTED_SKILLS=13
EXPECTED_HOOKS=5
EXPECTED_HOOK_EVENTS="before-tasks after-tasks before-implement after-implement before-commit"

errors=0

if [ ! -f "$MANIFEST" ]; then
    printf 'FAIL: manifest missing: %s\n' "$MANIFEST" >&2
    exit 1
fi

# version:
version_line=$(grep -E '^version: ' "$MANIFEST" | head -n1 || true)
if [ -z "$version_line" ]; then
    printf 'FAIL: manifest missing version: field\n' >&2
    errors=$((errors + 1))
fi
version=$(printf '%s\n' "$version_line" | sed -e 's/^version: //' -e 's/^"//' -e 's/"$//')

# skills: list entries — count lines between 'skills:' and the next top-level key.
skill_count=$(awk '
    /^skills:/ { in_skills=1; next }
    in_skills && /^[a-zA-Z_][a-zA-Z0-9_]*:/ { in_skills=0 }
    in_skills && /^[[:space:]]*-[[:space:]]+orchestrator-/ { count++ }
    END { print count+0 }
' "$MANIFEST")

if [ "$skill_count" -ne "$EXPECTED_SKILLS" ]; then
    printf 'FAIL: manifest skills count=%d, expected %d\n' "$skill_count" "$EXPECTED_SKILLS" >&2
    errors=$((errors + 1))
fi

# hooks: list events — each event: <name> within hooks: block.
hook_count=0
missing_events=""
for ev in $EXPECTED_HOOK_EVENTS; do
    if grep -E "^[[:space:]]+-[[:space:]]+event:[[:space:]]+$ev\$" "$MANIFEST" >/dev/null 2>&1; then
        hook_count=$((hook_count + 1))
    else
        missing_events="$missing_events $ev"
    fi
done

if [ "$hook_count" -ne "$EXPECTED_HOOKS" ]; then
    printf 'FAIL: manifest hook events found=%d, expected %d (missing:%s)\n' \
        "$hook_count" "$EXPECTED_HOOKS" "$missing_events" >&2
    errors=$((errors + 1))
fi

if [ "$errors" -ne 0 ]; then
    exit 1
fi

printf 'PASS: bundle manifest valid (version=%s, %d skills, %d hooks)\n' \
    "$version" "$skill_count" "$hook_count"
