#!/usr/bin/env bash
# scripts/lifecycle/read-project-assets.sh -- M032 P01 FR-2 prep.
#
# Shared reader sourced by all three installers (claude-code / codex /
# cursor) in T02 + T03. Reads the bundle manifest at
# <bundle-dir>/manifest.yml and emits one tab-separated tuple per
# project_assets: entry on stdout.
#
# Usage:
#   bash scripts/lifecycle/read-project-assets.sh [<bundle-dir>]
#
# Default bundle-dir: packaging/bundle/.
#
# Output: one line per entry, tab-separated:
#   source=<src>\ttarget=<tgt>\tmode=<copy|symlink>
#
# Exit codes:
#   0 = success (zero or more tuples emitted)
#   2 = invalid input (malformed manifest: missing key, unknown mode)
#
# The reader is the single shared seam that all three installers read.
# Reader output is line-oriented, tab-separated, UTF-8, and stable
# across re-invocations against the same manifest.
#
# Bash 3.2 compatible (no declare -A per K001 / MEM001).

set -u

BUNDLE_DIR="${1:-packaging/bundle/}"
# Strip trailing slash if any.
BUNDLE_DIR="${BUNDLE_DIR%/}"
MANIFEST="${BUNDLE_DIR}/manifest.yml"

if [ ! -f "$MANIFEST" ]; then
    echo "FAIL: manifest not found: $MANIFEST" >&2
    exit 2
fi

# ---------- Walk the project_assets: section line by line ----------
#
# We are looking for the block between `^project_assets:$` and the next
# top-level YAML key (a line that begins with a non-space, non-#
# character) or EOF. Within the block, list entries start with `^  - `
# and following keys are indented `^    `.

awk '
BEGIN {
    in_block = 0
    entry_idx = -1
    err = ""
}
function flush_entry() {
    if (entry_idx < 0) return
    if (!has_source[entry_idx]) {
        err = sprintf("FAIL: project_assets entry %d missing required key source", entry_idx + 1)
        exit 2
    }
    if (!has_target[entry_idx]) {
        err = sprintf("FAIL: project_assets entry %d missing required key target", entry_idx + 1)
        exit 2
    }
    if (!has_mode[entry_idx]) {
        err = sprintf("FAIL: project_assets entry %d missing required key mode", entry_idx + 1)
        exit 2
    }
    if (mode_v[entry_idx] != "copy" && mode_v[entry_idx] != "symlink") {
        err = sprintf("FAIL: project_assets entry %d mode='\''%s'\'' invalid (must be copy|symlink)", entry_idx + 1, mode_v[entry_idx])
        exit 2
    }
    printf "source=%s\ttarget=%s\tmode=%s\n", source_v[entry_idx], target_v[entry_idx], mode_v[entry_idx]
}
{
    line = $0
}
# Detect entering the project_assets: block.
/^project_assets:[[:space:]]*$/ {
    in_block = 1
    next
}
# Exit block on any new top-level key (non-space, non-# line).
in_block && /^[A-Za-z]/ {
    flush_entry()
    in_block = 0
    next
}
# Comment lines inside the block: skip.
in_block && /^[[:space:]]*#/ {
    next
}
# Blank lines inside the block: skip.
in_block && /^[[:space:]]*$/ {
    next
}
# New list item: `^  - source: <val>` OR `^  - <key>: <val>`.
in_block && /^  - / {
    # Flush the previous entry before starting a new one.
    flush_entry()
    entry_idx++
    has_source[entry_idx] = 0
    has_target[entry_idx] = 0
    has_mode[entry_idx] = 0
    # Parse the first key on this line.
    sub(/^  - /, "", line)
    # line is now e.g. "source: commands/"
    if (line ~ /^source:[[:space:]]/) {
        v = line
        sub(/^source:[[:space:]]+/, "", v)
        gsub(/[[:space:]]+$/, "", v)
        source_v[entry_idx] = v
        has_source[entry_idx] = 1
    } else if (line ~ /^target:[[:space:]]/) {
        v = line
        sub(/^target:[[:space:]]+/, "", v)
        gsub(/[[:space:]]+$/, "", v)
        target_v[entry_idx] = v
        has_target[entry_idx] = 1
    } else if (line ~ /^mode:[[:space:]]/) {
        v = line
        sub(/^mode:[[:space:]]+/, "", v)
        gsub(/[[:space:]]+$/, "", v)
        mode_v[entry_idx] = v
        has_mode[entry_idx] = 1
    }
    next
}
# Continuation key for current entry: `^    <key>: <val>`.
in_block && entry_idx >= 0 && /^    [A-Za-z]/ {
    sub(/^    /, "", line)
    if (line ~ /^source:[[:space:]]/) {
        v = line
        sub(/^source:[[:space:]]+/, "", v)
        gsub(/[[:space:]]+$/, "", v)
        source_v[entry_idx] = v
        has_source[entry_idx] = 1
    } else if (line ~ /^target:[[:space:]]/) {
        v = line
        sub(/^target:[[:space:]]+/, "", v)
        gsub(/[[:space:]]+$/, "", v)
        target_v[entry_idx] = v
        has_target[entry_idx] = 1
    } else if (line ~ /^mode:[[:space:]]/) {
        v = line
        sub(/^mode:[[:space:]]+/, "", v)
        gsub(/[[:space:]]+$/, "", v)
        mode_v[entry_idx] = v
        has_mode[entry_idx] = 1
    }
    next
}
END {
    if (err != "") {
        print err > "/dev/stderr"
        exit 2
    }
    if (in_block) {
        flush_entry()
    }
    if (err != "") {
        print err > "/dev/stderr"
        exit 2
    }
}
' "$MANIFEST"
rc=$?
exit "$rc"
