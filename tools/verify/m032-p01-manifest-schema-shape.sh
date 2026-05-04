#!/usr/bin/env bash
# tools/verify/m032-p01-manifest-schema-shape.sh -- M032 P01 FR-1 verifier.
#
# Asserts packaging/bundle/manifest.yml carries a `project_assets:`
# top-level list with exactly four entries, each declaring source:,
# target:, and mode: copy.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
MANIFEST="$PROJECT_ROOT/packaging/bundle/manifest.yml"

pass=0
fail=0

check() {
    desc="$1"
    rc="$2"
    if [ "$rc" -eq 0 ]; then
        printf 'PASS: %s\n' "$desc"
        pass=$((pass + 1))
    else
        printf 'FAIL: %s\n' "$desc"
        fail=$((fail + 1))
    fi
}

# 1. Manifest exists.
if [ -f "$MANIFEST" ]; then
    check "manifest.yml exists" 0
else
    check "manifest.yml exists" 1
fi

# 2. Top-level `project_assets:` key present.
if grep -qE '^project_assets:[[:space:]]*$' "$MANIFEST"; then
    check "top-level project_assets: key present" 0
else
    check "top-level project_assets: key present" 1
fi

# 3. Pre-M032 top-level keys preserved.
for key in schema_version type name version description skill_spec skills hooks config_default runtime_compatibility; do
    if grep -qE "^${key}:" "$MANIFEST"; then
        check "pre-M032 key preserved: ${key}" 0
    else
        check "pre-M032 key preserved: ${key}" 1
    fi
done

# 4. project_assets entries: at-least-four invariant. P01 lands the four
# runtime dirs (commands/, scripts/, references/, templates/); P02/T01 adds
# wiki/ as the fifth entry per FR-6, and downstream phases may add more.
# The load-bearing P01 invariant is "the four runtime dirs are present" —
# enforced by step 6 below — not the exact count.
source_count=$(grep -cE '^  - source: ' "$MANIFEST")
if [ "$source_count" -ge 4 ]; then
    check "at least four project_assets entries (source:)" 0
else
    printf 'FAIL: expected at least 4 entries, got %s\n' "$source_count"
    fail=$((fail + 1))
fi

# 5. Each entry has matching target: and mode: copy lines (count parity, not
# absolute count — see step 4 rationale).
target_count=$(grep -cE '^    target: ' "$MANIFEST")
mode_copy_count=$(grep -cE '^    mode: copy$' "$MANIFEST")
if [ "$target_count" -eq "$source_count" ]; then
    check "target: lines match source: count" 0
else
    printf 'FAIL: target: lines (%s) != source: count (%s)\n' "$target_count" "$source_count"
    fail=$((fail + 1))
fi
if [ "$mode_copy_count" -eq "$source_count" ]; then
    check "mode: copy lines match source: count" 0
else
    printf 'FAIL: mode: copy lines (%s) != source: count (%s)\n' "$mode_copy_count" "$source_count"
    fail=$((fail + 1))
fi

# 6. Verify the four expected source dirs.
for src in 'commands/' 'scripts/' 'references/' 'templates/'; do
    if grep -qE "^  - source: ${src}\$" "$MANIFEST"; then
        check "entry source: ${src}" 0
    else
        check "entry source: ${src}" 1
    fi
done

printf 'SUMMARY: m032-p01-manifest-schema-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
