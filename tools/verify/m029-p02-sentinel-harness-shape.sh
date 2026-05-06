#!/usr/bin/env bash
# tools/verify/m029-p02-sentinel-harness-shape.sh
#
# M029 P02 / T04 sentinel-harness shape verifier.
#
# Asserts:
#   - tests/m029-acceptance/sentinel-harness.sh exists and is
#     executable.
#   - The script declares the AD-9 sentinel file path literal
#     (`.m029-sc14-sentinel`).
#   - The script excludes `start-state/*.complete` (the AD-9 documented
#     write-site exception per FR-10).
#   - The script invokes `find ... -newer` (the AD-9 mechanism choice).
#   - The script header carries the AD-9 / read-only contract token.
#   - Behavioral spot-check: harness against `true` under a synthetic
#     temp ORCHESTRATOR_ROOT exits 0 with the canonical PASS line.
#
# Spec references: AD-9, FR-10, SC-14, CON-1, FR-14.
#
# Single-script-file shape per AD-19. Bash 3.2 compatible.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
HARNESS="$PROJECT_ROOT/tests/m029-acceptance/sentinel-harness.sh"

pass=0
fail=0

ok() { printf 'PASS: %s\n' "$1"; pass=$(( pass + 1 )); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$(( fail + 1 )); }

# 1. File exists.
if [ -f "$HARNESS" ]; then
    ok "sentinel-harness.sh exists"
else
    bad "sentinel-harness.sh missing at $HARNESS"
    printf 'SUMMARY: m029-p02-sentinel-harness-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2. Executable.
if [ -x "$HARNESS" ]; then
    ok "sentinel-harness.sh is executable"
else
    bad "sentinel-harness.sh is NOT executable"
fi

# 3. Declares the AD-9 sentinel file path literal.
if grep -F -q -- '.m029-sc14-sentinel' "$HARNESS"; then
    ok "sentinel-harness.sh declares .m029-sc14-sentinel path literal"
else
    bad "sentinel-harness.sh missing .m029-sc14-sentinel literal"
fi

# 4. Excludes start-state/*.complete (AD-9 documented exception).
if grep -F -q -- 'start-state/*.complete' "$HARNESS"; then
    ok "sentinel-harness.sh excludes start-state/*.complete (AD-9 carve-out)"
else
    bad "sentinel-harness.sh missing start-state/*.complete exclusion"
fi

# 5. Invokes `find ... -newer` (the AD-9 mechanism).
if grep -E -q -- 'find[[:space:]].*-newer' "$HARNESS"; then
    ok "sentinel-harness.sh invokes find ... -newer (AD-9 mechanism)"
else
    bad "sentinel-harness.sh missing find ... -newer invocation"
fi

# 6. Header references AD-9 / read-only contract.
HEADER="$( head -40 "$HARNESS" )"
if printf '%s' "$HEADER" | grep -q -- 'AD-9'; then
    ok "header references AD-9"
else
    bad "header missing AD-9 reference"
fi
if printf '%s' "$HEADER" | grep -q -E -- 'read-only|SC-14'; then
    ok "header references read-only / SC-14 contract"
else
    bad "header missing read-only / SC-14 contract reference"
fi

# 7. Bash 3.2 / MEM001 compatibility marker.
if grep -E -q -- 'Bash 3\.2|MEM001' "$HARNESS"; then
    ok "sentinel-harness.sh declares Bash 3.2 / MEM001 compatibility"
else
    bad "sentinel-harness.sh missing Bash 3.2 / MEM001 compatibility marker"
fi

# 8. Behavioral spot-check: harness against `true` under a temp tree.
TMP="${TMPDIR:-/tmp}/m029-sentinel-test.$$"
mkdir -p "$TMP/.orchestrator"
SPOT_OUT="$TMP/spot-output"
set +e
ORCHESTRATOR_ROOT="$TMP/.orchestrator" bash "$HARNESS" true >"$SPOT_OUT" 2>&1
spot_rc=$?
set -e

if [ "$spot_rc" -eq 0 ]; then
    ok "behavioral spot-check: harness around true exits 0"
else
    bad "behavioral spot-check: harness around true exit non-zero (rc=$spot_rc)"
    sed 's/^/   | /' "$SPOT_OUT" >&2
fi
if grep -q -- 'PASS: read-only invariant held' "$SPOT_OUT"; then
    ok "behavioral spot-check: canonical PASS line emitted"
else
    bad "behavioral spot-check: canonical PASS line missing"
    sed 's/^/   | /' "$SPOT_OUT" >&2
fi

# Cleanup.
rm -rf "$TMP"

printf 'SUMMARY: m029-p02-sentinel-harness-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
