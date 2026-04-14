#!/usr/bin/env bash
# generate-skills.sh — regenerate packaging/skills/orchestrator-*.md from commands/*.md
#
# Transforms each commands/<cmd>.md (excluding README.md per MEM008) into a
# thin skill discovery file at packaging/skills/orchestrator-<cmd>.md. The
# skill file carries YAML frontmatter conforming to packaging/SKILL.md and a
# 3-6 line body pointing back at the canonical command document.
#
# Usage:
#   scripts/packaging/generate-skills.sh           # regenerate (writes files)
#   scripts/packaging/generate-skills.sh --check   # diff against committed files; non-zero on drift
#
# Bash 3.2 compatible. No python, no jq, no associative arrays.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Walk up two dirs: scripts/packaging -> repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

COMMANDS_DIR="$REPO_ROOT/commands"
SKILLS_DIR="$REPO_ROOT/packaging/skills"

MODE="write"
if [ "${1:-}" = "--check" ]; then
    MODE="check"
elif [ -n "${1:-}" ]; then
    echo "error: unknown argument: $1" >&2
    echo "usage: $(basename "$0") [--check]" >&2
    exit 2
fi

if [ ! -d "$COMMANDS_DIR" ]; then
    echo "error: commands directory not found: $COMMANDS_DIR" >&2
    exit 1
fi

# extract_description <path>
# Reads the first `description:` line from a command file's YAML frontmatter
# and strips surrounding quotes. Pure grep+sed, no jq/python.
extract_description() {
    _path="$1"
    _line=$(grep -m1 '^description:' "$_path" || true)
    if [ -z "$_line" ]; then
        echo ""
        return 0
    fi
    # Remove `description:` prefix, trim leading spaces, strip surrounding quotes.
    _desc=$(printf '%s\n' "$_line" \
        | sed -e 's/^description:[[:space:]]*//' \
              -e 's/^"//' -e 's/"$//' \
              -e "s/^'//" -e "s/'$//")
    printf '%s\n' "$_desc"
}

# write_skill <cmd> <description> <out_path>
write_skill() {
    _cmd="$1"
    _desc="$2"
    _out="$3"
    # Escape any embedded double quotes in the description for YAML safety.
    _desc_escaped=$(printf '%s' "$_desc" | sed 's/"/\\"/g')
    {
        printf '%s\n' '---'
        printf '%s\n' 'schema_version: "1.0"'
        printf '%s\n' 'type: skill'
        printf 'name: "orchestrator:%s"\n' "$_cmd"
        printf '%s\n' 'namespace: "orchestrator"'
        printf 'description: "%s"\n' "$_desc_escaped"
        printf '%s\n' 'runtime_compatibility: ["claude-code", "codex", "cursor"]'
        printf 'command_file: "commands/%s.md"\n' "$_cmd"
        printf '%s\n' '---'
        printf '\n'
        printf '# orchestrator:%s\n' "$_cmd"
        printf '\n'
        printf 'Canonical behavior is defined in [`commands/%s.md`](../../commands/%s.md).\n' "$_cmd" "$_cmd"
        printf 'This skill file is a thin discovery surface for runtimes that enumerate skills\n'
        printf 'from disk. When the runtime invokes `orchestrator:%s`, it delegates to the\n' "$_cmd"
        printf 'command document above.\n'
    } > "$_out"
}

# Determine output directory (real for write mode, temp for check mode).
if [ "$MODE" = "check" ]; then
    TMP_DIR=$(mktemp -d -t spec-kit-skills.XXXXXX)
    # shellcheck disable=SC2064
    trap "rm -rf '$TMP_DIR'" EXIT INT TERM
    OUT_DIR="$TMP_DIR"
else
    mkdir -p "$SKILLS_DIR"
    OUT_DIR="$SKILLS_DIR"
fi

# Iterate commands/*.md in a bash-3.2-safe way (no globstar, no mapfile).
count=0
for cmd_path in "$COMMANDS_DIR"/*.md; do
    [ -e "$cmd_path" ] || continue
    base=$(basename "$cmd_path" .md)
    # Skip README per MEM008.
    if [ "$base" = "README" ]; then
        continue
    fi
    desc=$(extract_description "$cmd_path")
    out_path="$OUT_DIR/orchestrator-$base.md"
    write_skill "$base" "$desc" "$out_path"
    if [ "$MODE" = "write" ]; then
        printf 'wrote=%s\n' "packaging/skills/orchestrator-$base.md"
    fi
    count=$((count + 1))
done

if [ "$MODE" = "check" ]; then
    # Compare generated set against committed files.
    drift=0
    if [ ! -d "$SKILLS_DIR" ]; then
        echo "drift: committed skills directory missing: packaging/skills/" >&2
        exit 1
    fi
    # Compare every generated file to its committed counterpart.
    for gen_path in "$OUT_DIR"/orchestrator-*.md; do
        [ -e "$gen_path" ] || continue
        gen_base=$(basename "$gen_path")
        committed="$SKILLS_DIR/$gen_base"
        if [ ! -f "$committed" ]; then
            echo "drift: missing committed skill: packaging/skills/$gen_base" >&2
            drift=1
            continue
        fi
        if ! diff -q "$committed" "$gen_path" >/dev/null 2>&1; then
            echo "drift: content mismatch: packaging/skills/$gen_base" >&2
            drift=1
        fi
    done
    # Detect orphan committed files that the generator would not produce.
    for committed_path in "$SKILLS_DIR"/orchestrator-*.md; do
        [ -e "$committed_path" ] || continue
        committed_base=$(basename "$committed_path")
        if [ ! -f "$OUT_DIR/$committed_base" ]; then
            echo "drift: orphan committed skill (no source command): packaging/skills/$committed_base" >&2
            drift=1
        fi
    done
    if [ "$drift" -ne 0 ]; then
        echo "FAIL: skill files drift from commands/*.md — run scripts/packaging/generate-skills.sh" >&2
        exit 1
    fi
    printf 'PASS: %d orchestrator skill files in sync with commands/*.md\n' "$count"
    exit 0
fi

printf 'generated=%d\n' "$count"
exit 0
