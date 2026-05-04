#!/usr/bin/env bash
# m033-p03-imported-context-sentinel-shape.sh
#
# Asserts references/imported-context-sentinel.md exists with the
# load-bearing #Q-11 tokens AND that the additive `_*`-prefix skip
# clauses landed at every milestone-enumerating downstream traverser
# identified at T04 execution time.
#
# Single-script-file shape per AD-19. Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SENTINEL_REF="$PROJECT_ROOT/references/imported-context-sentinel.md"

pass=0
fail=0

# Enumerating traversers — get the inline `_*) continue ;;` skip clause.
ENUMERATING_TRAVERSERS="
$PROJECT_ROOT/scripts/diagnostics/check-plans.sh
$PROJECT_ROOT/scripts/diagnostics/check-constitution.sh
"

# Single-milestone (non-enumerating) traversers — get an inline doc comment
# referencing M033/P03/T04 + #Q-11 explaining why no skip clause is needed.
DOC_ONLY_TRAVERSERS="
$PROJECT_ROOT/scripts/state/derive-phase.sh
$PROJECT_ROOT/scripts/dispatch/build-context.sh
$PROJECT_ROOT/scripts/diagnostics/run-doctor.sh
"

assert_token_in() {
    local file="$1"
    local token="$2"
    if [ ! -f "$file" ]; then
        fail=$((fail + 1))
        echo "FAIL: file missing for token check: $file" >&2
        return 0
    fi
    if grep -qF "$token" "$file"; then
        pass=$((pass + 1))
        echo "PASS: token present in $(basename "$file"): $token"
    else
        fail=$((fail + 1))
        echo "FAIL: token missing in $(basename "$file"): $token" >&2
    fi
}

# --- references/imported-context-sentinel.md presence + tokens ---
if [ ! -f "$SENTINEL_REF" ]; then
    echo "FAIL: references/imported-context-sentinel.md missing" >&2
    echo "SUMMARY: m033-p03-imported-context-sentinel-shape pass=0 fail=1"
    exit 1
fi
pass=$((pass + 1))
echo "PASS: references/imported-context-sentinel.md exists"

assert_token_in "$SENTINEL_REF" '_imported-context'
assert_token_in "$SENTINEL_REF" 'context_source: imported-from-existing'
assert_token_in "$SENTINEL_REF" 'validate-milestone.sh'
assert_token_in "$SENTINEL_REF" 'build-context.sh'
assert_token_in "$SENTINEL_REF" 'run-doctor.sh'
assert_token_in "$SENTINEL_REF" '_*'
assert_token_in "$SENTINEL_REF" '#Q-11'
assert_token_in "$SENTINEL_REF" 'MEM-DR-'

# --- Enumerating traversers carry the additive skip clause + comment ---
for tv in $ENUMERATING_TRAVERSERS; do
    if [ ! -f "$tv" ]; then
        fail=$((fail + 1))
        echo "FAIL: enumerating traverser missing: $tv" >&2
        continue
    fi
    # The skip-clause case-statement form is the load-bearing token.
    if grep -qF '_*) continue' "$tv"; then
        pass=$((pass + 1))
        echo "PASS: $(basename "$tv") carries _*) continue skip clause"
    else
        fail=$((fail + 1))
        echo "FAIL: $(basename "$tv") missing _*) continue skip clause" >&2
    fi
    # The inline comment naming M033/P03/T04 + #Q-11.
    if grep -qF 'M033/P03/T04 #Q-11' "$tv"; then
        pass=$((pass + 1))
        echo "PASS: $(basename "$tv") carries M033/P03/T04 #Q-11 inline comment"
    else
        fail=$((fail + 1))
        echo "FAIL: $(basename "$tv") missing M033/P03/T04 #Q-11 inline comment" >&2
    fi
done

# --- Doc-only traversers carry the inline note (no skip clause needed) ---
for tv in $DOC_ONLY_TRAVERSERS; do
    if [ ! -f "$tv" ]; then
        fail=$((fail + 1))
        echo "FAIL: doc-only traverser missing: $tv" >&2
        continue
    fi
    if grep -qF 'M033/P03/T04 #Q-11' "$tv"; then
        pass=$((pass + 1))
        echo "PASS: $(basename "$tv") carries M033/P03/T04 #Q-11 inline doc-note"
    else
        fail=$((fail + 1))
        echo "FAIL: $(basename "$tv") missing M033/P03/T04 #Q-11 inline doc-note" >&2
    fi
done

echo "SUMMARY: m033-p03-imported-context-sentinel-shape pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
