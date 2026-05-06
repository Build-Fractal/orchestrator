#!/usr/bin/env bash
# tools/verify/m029-p01-status-headline-shape.sh
#
# M029/P01/T03 shape verifier: asserts that commands/status.md carries the
# FR-2 headline block additions per the T03 task plan.
#
# Spec references: FR-2, SC-2, AD-1, CON-5.
# Contract source: references/status-headline-shape.md.
#
# Single-script-file shape per AD-19. Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET="$PROJECT_ROOT/commands/status.md"

pass=0
fail=0

ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

# Gate: file exists.
if [ ! -f "$TARGET" ]; then
    bad "commands/status.md missing at $TARGET"
    printf 'SUMMARY: m029-p01-status-headline-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi
ok "commands/status.md exists"

# Required literal markers.
if grep -qE '^## Headline Block$' "$TARGET"; then
    ok "## Headline Block section present"
else
    bad "## Headline Block section missing"
fi

if grep -q 'FR-2' "$TARGET"; then
    ok "FR-2 reference present"
else
    bad "FR-2 reference missing"
fi

if grep -q 'scripts/state/detect-invocation-context.sh' "$TARGET"; then
    ok "resolver reference (scripts/state/detect-invocation-context.sh) present"
else
    bad "resolver reference missing"
fi

if grep -q 'scripts/diagnostics/efficiency-footer.sh' "$TARGET"; then
    ok "embedded footer reference (scripts/diagnostics/efficiency-footer.sh) present"
else
    bad "embedded footer reference missing"
fi

if grep -q 'references/status-headline-shape.md' "$TARGET"; then
    ok "design contract reference (references/status-headline-shape.md) present"
else
    bad "design contract reference missing"
fi

if grep -q 'CON-5' "$TARGET"; then
    ok "CON-5 (suppression-matrix inheritance) reference present"
else
    bad "CON-5 reference missing"
fi

# Reference Files section names all five required entries. We isolate the
# Reference Files section by line range starting at "## Reference Files"
# (last occurrence) through end-of-file.
REF_START=$(grep -nE '^## Reference Files$' "$TARGET" | tail -1 | cut -d: -f1)
if [ -z "$REF_START" ]; then
    bad "## Reference Files section missing"
else
    REF_BODY=$(awk -v s="$REF_START" 'NR>=s' "$TARGET")
    miss=0
    for needle in \
        'scripts/state/detect-invocation-context.sh' \
        'references/status-headline-shape.md' \
        'references/status-json-schema.md' \
        'scripts/diagnostics/render-status-json.sh' \
        'scripts/diagnostics/efficiency-footer.sh'; do
        if ! printf '%s' "$REF_BODY" | grep -q "$needle"; then
            bad "Reference Files missing entry: $needle"
            miss=$((miss + 1))
        fi
    done
    if [ "$miss" -eq 0 ]; then
        ok "Reference Files names all five required entries"
    fi
fi

printf 'SUMMARY: m029-p01-status-headline-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
