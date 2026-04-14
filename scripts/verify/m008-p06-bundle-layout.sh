#!/usr/bin/env bash
# m008-p06-bundle-layout.sh — verify bundle directory contents match manifest.
#
# Checks:
#   - packaging/bundle/skills/  contains every file named in manifest 'skills:'.
#   - packaging/bundle/hooks/   contains one JSON per hook event in manifest.
#   - packaging/bundle/config/orchestrator.default.yml exists and matches
#     manifest 'config_default:'.
#   - packaging/bundle/README.md exists.
#
# Bash 3.2 compatible. No python, no jq.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../.." && pwd)
BUNDLE_DIR="$REPO_ROOT/packaging/bundle"
MANIFEST="$BUNDLE_DIR/manifest.yml"
SKILLS_DIR="$BUNDLE_DIR/skills"
HOOKS_DIR="$BUNDLE_DIR/hooks"
CONFIG_DIR="$BUNDLE_DIR/config"
README="$BUNDLE_DIR/README.md"

errors=0

if [ ! -f "$MANIFEST" ]; then
    printf 'FAIL: manifest missing: %s\n' "$MANIFEST" >&2
    exit 1
fi

# Skills declared in manifest.
skills_declared=$(awk '
    /^skills:/ { in_skills=1; next }
    in_skills && /^[a-zA-Z_][a-zA-Z0-9_]*:/ { in_skills=0 }
    in_skills && /^[[:space:]]*-[[:space:]]+/ {
        sub(/^[[:space:]]*-[[:space:]]+/, "")
        sub(/[[:space:]]*#.*$/, "")
        print
    }
' "$MANIFEST")

skill_missing=""
skill_count=0
for name in $skills_declared; do
    skill_count=$((skill_count + 1))
    if [ ! -f "$SKILLS_DIR/$name" ]; then
        skill_missing="$skill_missing $name"
    fi
done

if [ -n "$skill_missing" ]; then
    printf 'FAIL: manifest declares skills missing on disk:%s\n' "$skill_missing" >&2
    errors=$((errors + 1))
fi

# Check for extra skills on disk not in manifest.
extra_skills=""
for f in "$SKILLS_DIR"/orchestrator-*.md; do
    if [ -f "$f" ]; then
        base=$(basename "$f")
        if ! printf '%s\n' "$skills_declared" | grep -Fxq "$base"; then
            extra_skills="$extra_skills $base"
        fi
    fi
done

if [ -n "$extra_skills" ]; then
    printf 'FAIL: skills on disk not declared in manifest:%s\n' "$extra_skills" >&2
    errors=$((errors + 1))
fi

# Hook events declared in manifest (event: <name>).
hook_events=$(grep -E "^[[:space:]]+-[[:space:]]+event:[[:space:]]+" "$MANIFEST" \
    | sed -e 's/^[[:space:]]*-[[:space:]]*event:[[:space:]]*//' -e 's/[[:space:]]*$//')

hook_missing=""
hook_count=0
for ev in $hook_events; do
    hook_count=$((hook_count + 1))
    if [ ! -f "$HOOKS_DIR/$ev.json" ]; then
        hook_missing="$hook_missing $ev.json"
    fi
done

if [ -n "$hook_missing" ]; then
    printf 'FAIL: manifest declares hooks missing on disk:%s\n' "$hook_missing" >&2
    errors=$((errors + 1))
fi

# config_default value.
config_rel=$(grep -E '^config_default: ' "$MANIFEST" | head -n1 \
    | sed -e 's/^config_default: //' -e 's/^"//' -e 's/"$//')
if [ -z "$config_rel" ]; then
    printf 'FAIL: manifest missing config_default:\n' >&2
    errors=$((errors + 1))
elif [ ! -f "$BUNDLE_DIR/$config_rel" ]; then
    printf 'FAIL: config_default file missing: %s\n' "$BUNDLE_DIR/$config_rel" >&2
    errors=$((errors + 1))
fi

# README.
if [ ! -f "$README" ]; then
    printf 'FAIL: missing README: %s\n' "$README" >&2
    errors=$((errors + 1))
fi

if [ "$errors" -ne 0 ]; then
    exit 1
fi

printf 'PASS: bundle layout matches manifest (%d skills, %d hooks, config=%s)\n' \
    "$skill_count" "$hook_count" "$config_rel"
