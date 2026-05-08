#!/usr/bin/env bash
# tools/verify/m035-p02-bundle-hygiene-filter.sh
# Asserts packaging/bundle/build-bundle.sh carries the M035 P02 T05
# pre-publish filter logic (#Q-9 absorption) and that
# packaging/bundle/manifest.yml documents the contract.
set -euo pipefail

REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
BUNDLE_SH="$REPO/packaging/bundle/build-bundle.sh"
MANIFEST="$REPO/packaging/bundle/manifest.yml"

pass=0
fail=0

for f in "$BUNDLE_SH" "$MANIFEST"; do
    if [ ! -f "$f" ]; then
        echo "FAIL: $f not found"
        fail=$((fail + 1))
    else
        echo "PASS: $f exists"
        pass=$((pass + 1))
    fi
done

check_grep() {
    local file="$1" pattern="$2" label="$3"
    if grep -qE "$pattern" "$file"; then
        echo "PASS: $label"
        pass=$((pass + 1))
    else
        echo "FAIL: $label (file=$file pattern=$pattern)"
        fail=$((fail + 1))
    fi
}

# build-bundle.sh contract surfaces:
check_grep "$BUNDLE_SH" 'm\[0-9\]\*-p\[0-9\]\*-\*' \
    "build-bundle.sh carries pattern-exclusion glob (rule 1)"
check_grep "$BUNDLE_SH" 'bundle:[[:space:]]*dogfood-only' \
    "build-bundle.sh carries magic-comment exclusion (rule 2)"
check_grep "$BUNDLE_SH" 'apply_bundle_hygiene_filter|should_exclude_from_bundle' \
    "build-bundle.sh defines a hygiene filter function"
check_grep "$BUNDLE_SH" 'scripts/verify' \
    "build-bundle.sh names scripts/verify in pattern exclusion"
check_grep "$BUNDLE_SH" 'tools/verify' \
    "build-bundle.sh names tools/verify in pattern exclusion"
check_grep "$BUNDLE_SH" 'templates/conversus-presets' \
    "build-bundle.sh names templates/conversus-presets in pattern exclusion"

# manifest.yml contract surface:
check_grep "$MANIFEST" 'Bundle hygiene contract' \
    "manifest.yml documents bundle-hygiene contract block"
check_grep "$MANIFEST" 'm035-p02-bundle-hygiene-filter\.sh' \
    "manifest.yml references the verifier"

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
