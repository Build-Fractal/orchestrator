#!/usr/bin/env bash
# m033-p04-migrate-then-ingest-shape.sh
#
# Asserts the FR-12 / US-6 AS-3 / brief #Q-10 dup-prevention surface in
# scripts/lifecycle/ingest-codebase.sh + the documenting paragraph in
# commands/ingest-codebase.md + a functional-shape smoke test against a
# staged migrate-derived MEM (sentinel-presence grep, NOT an
# emit-function dup-prevention end-to-end test — that lives in T05's
# SC-6 acceptance).
#
# Bash 3.2 compatible (MEM001). Plain `grep -qF`, no process
# substitution, no `$(...)` containing pipes.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SH="$PROJECT_ROOT/scripts/lifecycle/ingest-codebase.sh"
TARGET_MD="$PROJECT_ROOT/commands/ingest-codebase.md"

pass=0
fail=0

assert_token() {
    local target="$1"
    local token="$2"
    if grep -qF "$token" "$target"; then
        pass=$((pass + 1))
        echo "PASS: token present in $(basename "$target"): $token"
    else
        fail=$((fail + 1))
        echo "FAIL: missing load-bearing token in $(basename "$target"): $token" >&2
    fi
}

# --- File presence + executable for the script ---
if [ ! -f "$TARGET_SH" ]; then
    echo "FAIL: scripts/lifecycle/ingest-codebase.sh missing" >&2
    echo "SUMMARY: m033-p04-migrate-then-ingest-shape pass=0 fail=1"
    exit 1
fi
pass=$((pass + 1))
echo "PASS: scripts/lifecycle/ingest-codebase.sh exists"

if [ -x "$TARGET_SH" ]; then
    pass=$((pass + 1))
    echo "PASS: ingest-codebase.sh is executable"
else
    fail=$((fail + 1))
    echo "FAIL: ingest-codebase.sh is not executable" >&2
fi

if [ ! -f "$TARGET_MD" ]; then
    echo "FAIL: commands/ingest-codebase.md missing" >&2
    echo "SUMMARY: m033-p04-migrate-then-ingest-shape pass=$pass fail=$((fail + 1))"
    exit 1
fi
pass=$((pass + 1))
echo "PASS: commands/ingest-codebase.md exists"

# --- Fenced SSOT block markers in the script ---
assert_token "$TARGET_SH" "# >>> dup-prevention-sentinel >>>"
assert_token "$TARGET_SH" "# <<< dup-prevention-sentinel <<<"

# --- Load-bearing tokens in the script ---
assert_token "$TARGET_SH" "derived_from_migrate: true"
assert_token "$TARGET_SH" "skip-duplicate-from-migrate:"
assert_token "$TARGET_SH" "is_migrate_derived_mem"
assert_token "$TARGET_SH" "FR-12"

# --- Each emit function must reference the dup-prevention helper ---
# The contract is: each of the three emit functions consults
# is_migrate_derived_mem before writing. We grep for the helper-call
# shape inside the script and require at least 3 occurrences (one per
# emit function).
helper_call_count=$(grep -c 'is_migrate_derived_mem "\$out"' "$TARGET_SH" || true)
if [ "$helper_call_count" -ge 3 ]; then
    pass=$((pass + 1))
    echo "PASS: dup-prevention check called in >=3 emit-function sites ($helper_call_count)"
else
    fail=$((fail + 1))
    echo "FAIL: dup-prevention check call count $helper_call_count < 3 (expected one per emit function)" >&2
fi

# --- Documenting paragraph in the command doc ---
assert_token "$TARGET_MD" "skip-duplicate-from-migrate"
assert_token "$TARGET_MD" "derived_from_migrate"
assert_token "$TARGET_MD" "FR-12"

# --- Functional shape smoke (mktemp-d positive + negative test) ---
# Stage one synthetic migrate-derived MEM and one synthetic
# codebase-ingest MEM under a temporary knowledge tree. Run the same
# `grep -qF 'derived_from_migrate: true' "$staged"` check the
# is_migrate_derived_mem helper performs. Positive test asserts match;
# negative test asserts no match.
STAGING="$(mktemp -d)"
echo "DIAG: staging dir: $STAGING"

mkdir -p "$STAGING/.orchestrator/knowledge/architecture"

POS_MEM="$STAGING/.orchestrator/knowledge/architecture/MEM-ARCH-deadbeef.md"
NEG_MEM="$STAGING/.orchestrator/knowledge/architecture/MEM-ARCH-cafef00d.md"

{
    printf '%s\n' '---'
    printf '%s\n' 'schema_version: "1.0"'
    printf '%s\n' 'type: knowledge-mem'
    printf '%s\n' 'category: architecture'
    printf '%s\n' 'derived_from_migrate: true'
    printf '%s\n' '---'
    printf '\n'
    printf '%s\n' '# MEM-ARCH-deadbeef: synthetic migrate-derived MEM'
} > "$POS_MEM"

{
    printf '%s\n' '---'
    printf '%s\n' 'schema_version: "1.0"'
    printf '%s\n' 'type: knowledge-mem'
    printf '%s\n' 'category: architecture'
    printf '%s\n' 'derived_from_codebase_ingest: true'
    printf '%s\n' '---'
    printf '\n'
    printf '%s\n' '# MEM-ARCH-cafef00d: synthetic codebase-ingest MEM (no sentinel)'
} > "$NEG_MEM"

# Positive test — sentinel must be detectable.
if grep -qF 'derived_from_migrate: true' "$POS_MEM"; then
    pass=$((pass + 1))
    echo "PASS: positive smoke — sentinel detected in synthetic migrate-derived MEM"
else
    fail=$((fail + 1))
    echo "FAIL: positive smoke — sentinel NOT detected in synthetic migrate-derived MEM" >&2
fi

# Negative test — sentinel must NOT be detected on a non-migrate MEM.
if grep -qF 'derived_from_migrate: true' "$NEG_MEM"; then
    fail=$((fail + 1))
    echo "FAIL: negative smoke — sentinel falsely detected in non-migrate MEM" >&2
else
    pass=$((pass + 1))
    echo "PASS: negative smoke — sentinel correctly absent from non-migrate MEM"
fi

# Cleanup
rm -rf "$STAGING"

echo "SUMMARY: m033-p04-migrate-then-ingest-shape pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
