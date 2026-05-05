#!/usr/bin/env bash
# m033-p04-migrate-routing-shape.sh
#
# Asserts the FR-11 / FR-12 / US-6 AS-5 migrate-routing real
# implementation in scripts/lifecycle/start.sh shipped by M033/P04/T04.
#
# Verifies the function `migrate_routing` exists (without the `_stub`
# suffix), the `translate_from_to_source` helper is present, the
# spec-shape -> impl-shape translation is implemented (gsd-v1 -> gsd1,
# gsd-v2 -> gsd2, spec-kit -> speckit), the load-bearing operator-facing
# tokens are present, and the file is bash 3.2 compatible (no
# associative arrays, no process substitution, no $(...) containing
# pipes).
#
# Bash 3.2 compatible (MEM001). Plain `grep -qF`, no process
# substitution, no `$(...)` containing pipes.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SH="$PROJECT_ROOT/scripts/lifecycle/start.sh"

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

assert_no_token() {
    local target="$1"
    local token="$2"
    local label="$3"
    if grep -qF "$token" "$target"; then
        fail=$((fail + 1))
        echo "FAIL: forbidden pattern present in $(basename "$target") ($label): $token" >&2
    else
        pass=$((pass + 1))
        echo "PASS: forbidden pattern absent in $(basename "$target") ($label): $token"
    fi
}

# --- File presence + executable ---
if [ ! -f "$TARGET_SH" ]; then
    echo "FAIL: scripts/lifecycle/start.sh missing" >&2
    echo "SUMMARY: m033-p04-migrate-routing-shape pass=0 fail=1"
    exit 1
fi
pass=$((pass + 1))
echo "PASS: scripts/lifecycle/start.sh exists"

if [ -x "$TARGET_SH" ]; then
    pass=$((pass + 1))
    echo "PASS: start.sh is executable"
else
    fail=$((fail + 1))
    echo "FAIL: start.sh is not executable" >&2
fi

# --- Function definitions ---
# `migrate_routing` (without `_stub` suffix) must exist as a function.
if grep -qE '^migrate_routing\(\)' "$TARGET_SH"; then
    pass=$((pass + 1))
    echo "PASS: migrate_routing function definition present"
else
    fail=$((fail + 1))
    echo "FAIL: migrate_routing function definition missing" >&2
fi

# `translate_from_to_source` helper must exist.
if grep -qE '^translate_from_to_source\(\)' "$TARGET_SH"; then
    pass=$((pass + 1))
    echo "PASS: translate_from_to_source helper definition present"
else
    fail=$((fail + 1))
    echo "FAIL: translate_from_to_source helper definition missing" >&2
fi

# `migrate_routing_stub` deprecated alias preserved.
if grep -qE '^migrate_routing_stub\(\)' "$TARGET_SH"; then
    pass=$((pass + 1))
    echo "PASS: migrate_routing_stub deprecated alias preserved"
else
    fail=$((fail + 1))
    echo "FAIL: migrate_routing_stub deprecated alias missing (AD-15 backward compat)" >&2
fi

# --- Load-bearing operator-facing tokens ---
assert_token "$TARGET_SH" 'migrate-routed: from='
assert_token "$TARGET_SH" 'proposed: orchestrator:migrate --from'
assert_token "$TARGET_SH" 'no orchestrator:migrate adapter for this tooling'
assert_token "$TARGET_SH" 'migrate_routed'

# --- Spec-shape -> impl-shape translation tokens ---
# Spec-shape (operator contract).
assert_token "$TARGET_SH" 'gsd-v1'
assert_token "$TARGET_SH" 'gsd-v2'
assert_token "$TARGET_SH" 'spec-kit'

# Impl-shape (migrate.sh internal flag values).
assert_token "$TARGET_SH" 'gsd1'
assert_token "$TARGET_SH" 'gsd2'
assert_token "$TARGET_SH" 'speckit'

# --- Invocation tokens ---
assert_token "$TARGET_SH" 'scripts/migrate/migrate.sh'
assert_token "$TARGET_SH" 'scripts/lifecycle/ingest-codebase.sh'
assert_token "$TARGET_SH" 'start-state-markers.sh write migrate-routed'
# Use grep -- separator to avoid '--source' being parsed as a grep flag.
if grep -qF -- '--source' "$TARGET_SH"; then
    pass=$((pass + 1))
    echo "PASS: token present in start.sh: --source"
else
    fail=$((fail + 1))
    echo "FAIL: missing load-bearing token in start.sh: --source" >&2
fi

# --- FR-11 / FR-12 contract markers ---
assert_token "$TARGET_SH" 'FR-11'
assert_token "$TARGET_SH" 'FR-12'

# --- Bash 3.2 compatibility (MEM001) negative greps ---
assert_no_token "$TARGET_SH" 'declare -A' 'declare -A associative arrays'

# Process substitution forbidden.
if grep -q '<(' "$TARGET_SH"; then
    fail=$((fail + 1))
    echo "FAIL: process substitution '<(' present in start.sh (MEM001 violation)" >&2
else
    pass=$((pass + 1))
    echo "PASS: no process substitution '<(' in start.sh"
fi

# $(...) containing single pipes — visual-scan grep. We must distinguish
# a real pipe (single `|`) from logical-or (`||`) which is allowed and
# pre-existing in the P01 detect_branch git rev-list call. The regex
# excludes `||` by anchoring on a single `|` not adjacent to another.
if grep -qE '\$\([^)]*[^|]\|[^|][^)]*\)' "$TARGET_SH"; then
    fail=$((fail + 1))
    echo "FAIL: '\$(...)' containing single pipe present in start.sh (MEM001 violation)" >&2
else
    pass=$((pass + 1))
    echo "PASS: no '\$(...)' containing single pipes in start.sh"
fi

# --- Min line count delta sanity check ---
# P02-extended baseline was 535 lines; T04 adds the translate helper and
# migrate_routing function (~+95 lines net). Conservative floor: 600.
linecount=$(wc -l < "$TARGET_SH" | tr -d ' ')
if [ "$linecount" -ge 600 ]; then
    pass=$((pass + 1))
    echo "PASS: start.sh line count $linecount >= 600 (post-T04 floor)"
else
    fail=$((fail + 1))
    echo "FAIL: start.sh line count $linecount < 600 (post-T04 floor)" >&2
fi

# --- Functional shape: invoke translate_from_to_source via subshell ---
# Source the script's translation helper alone (skipping main()) by
# extracting the function body and evaluating it in a sandboxed subshell.
# We can't `source` start.sh wholesale because it runs `main "$@"` at
# top-level. Instead, exercise the contract by piping through awk.
TRANSLATE_BODY=$(awk '
    /^translate_from_to_source\(\) \{/ { capture = 1 }
    capture { print }
    capture && /^\}/ { capture = 0 }
' "$TARGET_SH")

if [ -n "$TRANSLATE_BODY" ]; then
    pass=$((pass + 1))
    echo "PASS: translate_from_to_source body extractable"

    # Functional smoke: load the helper into a clean subshell and check
    # all three mappings + the empty-default branch.
    out_v1=$(bash -c "$TRANSLATE_BODY"$'\n'"translate_from_to_source gsd-v1")
    out_v2=$(bash -c "$TRANSLATE_BODY"$'\n'"translate_from_to_source gsd-v2")
    out_sk=$(bash -c "$TRANSLATE_BODY"$'\n'"translate_from_to_source spec-kit")
    out_un=$(bash -c "$TRANSLATE_BODY"$'\n'"translate_from_to_source unknown-tool")

    if [ "$out_v1" = "gsd1" ]; then
        pass=$((pass + 1))
        echo "PASS: translate_from_to_source gsd-v1 -> gsd1"
    else
        fail=$((fail + 1))
        echo "FAIL: translate_from_to_source gsd-v1 -> '$out_v1' (expected 'gsd1')" >&2
    fi
    if [ "$out_v2" = "gsd2" ]; then
        pass=$((pass + 1))
        echo "PASS: translate_from_to_source gsd-v2 -> gsd2"
    else
        fail=$((fail + 1))
        echo "FAIL: translate_from_to_source gsd-v2 -> '$out_v2' (expected 'gsd2')" >&2
    fi
    if [ "$out_sk" = "speckit" ]; then
        pass=$((pass + 1))
        echo "PASS: translate_from_to_source spec-kit -> speckit"
    else
        fail=$((fail + 1))
        echo "FAIL: translate_from_to_source spec-kit -> '$out_sk' (expected 'speckit')" >&2
    fi
    if [ -z "$out_un" ]; then
        pass=$((pass + 1))
        echo "PASS: translate_from_to_source unknown-tool -> '' (US-6 AS-5 unsupported-tooling default)"
    else
        fail=$((fail + 1))
        echo "FAIL: translate_from_to_source unknown-tool -> '$out_un' (expected empty)" >&2
    fi
else
    fail=$((fail + 1))
    echo "FAIL: translate_from_to_source body NOT extractable from start.sh" >&2
fi

echo "SUMMARY: m033-p04-migrate-routing-shape pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
