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

# 4. Exactly four `^  - source: ` entries.
source_count=$(grep -cE '^  - source: ' "$MANIFEST")
if [ "$source_count" -eq 4 ]; then
    check "exactly four project_assets entries (source:)" 0
else
    printf 'FAIL: expected 4 entries, got %s\n' "$source_count"
    fail=$((fail + 1))
fi

# 5. Each entry has matching target: and mode: copy lines.
target_count=$(grep -cE '^    target: ' "$MANIFEST")
mode_copy_count=$(grep -cE '^    mode: copy$' "$MANIFEST")
if [ "$target_count" -eq 4 ]; then
    check "four target: lines" 0
else
    printf 'FAIL: expected 4 target: lines, got %s\n' "$target_count"
    fail=$((fail + 1))
fi
if [ "$mode_copy_count" -eq 4 ]; then
    check "four mode: copy lines" 0
else
    printf 'FAIL: expected 4 mode: copy lines, got %s\n' "$mode_copy_count"
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
