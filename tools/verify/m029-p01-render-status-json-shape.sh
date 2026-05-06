#!/usr/bin/env bash
# tools/verify/m029-p01-render-status-json-shape.sh
#
# M029/P01/T04 shape verifier for scripts/diagnostics/render-status-json.sh.
# Asserts the renderer carries the AD-2 single ANSI-strip site, the AD-7
# schema_version constant, the safe-JSON-construction primitive (jq -n),
# the resolver linkage, the degraded-state shape, and the canonical
# section names.
#
# Single-script-file shape per AD-19. Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

RENDER="$PROJECT_ROOT/scripts/diagnostics/render-status-json.sh"

pass=0
fail=0

ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

# Gate: renderer file present.
if [ ! -f "$RENDER" ]; then
    bad "renderer missing at $RENDER"
    printf 'SUMMARY: m029-p01-render-status-json-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi
ok "renderer exists at scripts/diagnostics/render-status-json.sh"

# Executable.
if [ -x "$RENDER" ]; then
    ok "renderer is executable"
else
    bad "renderer is NOT executable"
fi

# Header comment names FR-3, AD-2, AD-7.
HEADER=$(head -50 "$RENDER")
if printf '%s' "$HEADER" | grep -q 'FR-3'; then
    ok "header references FR-3"
else
    bad "header missing 'FR-3' reference"
fi
if printf '%s' "$HEADER" | grep -q 'AD-2'; then
    ok "header references AD-2"
else
    bad "header missing 'AD-2' reference"
fi
if printf '%s' "$HEADER" | grep -q 'AD-7'; then
    ok "header references AD-7"
else
    bad "header missing 'AD-7' reference"
fi

# Schema SSOT cross-reference.
if grep -q 'references/status-json-schema.md' "$RENDER"; then
    ok "renderer references the schema SSOT (references/status-json-schema.md)"
else
    bad "renderer missing reference to references/status-json-schema.md"
fi

# _M029_SCHEMA_VERSION="1.0" -- single source of truth in the renderer.
if grep -qE '^_M029_SCHEMA_VERSION="1\.0"' "$RENDER"; then
    ok "_M029_SCHEMA_VERSION=\"1.0\" constant present (AD-7 SSOT)"
else
    bad "_M029_SCHEMA_VERSION=\"1.0\" constant missing"
fi

# jq -n usage (safe JSON construction).
if grep -qE 'jq -n' "$RENDER"; then
    ok "renderer invokes jq -n (safe JSON construction primitive)"
else
    bad "renderer does NOT invoke jq -n"
fi

# AD-2 ANSI strip primitive.
if grep -qE 'x1b\\\[\[0-9;\]\*\[mGKHF\]' "$RENDER"; then
    ok "AD-2 ANSI strip primitive present (\\x1b\\[[0-9;]*[mGKHF])"
else
    bad "AD-2 ANSI strip primitive missing"
fi

# Resolver linkage.
if grep -q 'scripts/state/detect-invocation-context.sh' "$RENDER"; then
    ok "renderer references the AD-1 resolver (scripts/state/detect-invocation-context.sh)"
else
    bad "renderer missing reference to scripts/state/detect-invocation-context.sh"
fi

# Degraded-state shape: literal `state` and `parse_errors` tokens present.
if grep -q '"degraded"' "$RENDER" && grep -q 'parse_errors' "$RENDER"; then
    ok "degraded-state shape present (literal 'degraded' and parse_errors tokens)"
else
    bad "degraded-state shape missing (need both 'degraded' and parse_errors tokens)"
fi

# Section names.
for sec in progress blockers execution_history telemetry_metrics \
           efficiency_footer next_action ; do
    if grep -q "$sec" "$RENDER"; then
        ok "section name present: $sec"
    else
        bad "section name missing: $sec"
    fi
done

printf 'SUMMARY: m029-p01-render-status-json-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
