#!/usr/bin/env bash
# tools/verify/m029-p02-sc5-shape.sh
#
# M029 P02 / T04 SC-5 acceptance script wrapper verifier.
#
# Asserts:
#   - tests/m029-acceptance/p02-sc5-where-mixed-state.sh exists, is
#     executable, and references the load-bearing surfaces:
#       * where-mixed-state.golden
#       * timestamp-strip.sh
#   - The script emits the standard SUMMARY line shape.
#   - Behavioral run: invoking the SC-5 acceptance script against the
#     fixtures T04 just built yields exit 0 (full SC-5 byte-identity
#     diff against the golden).
#
# Spec references: FR-5, FR-13, SC-5, AD-6, #Q-G6, #Q-G8.
#
# Single-script-file shape per AD-19. Bash 3.2 compatible.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
SC5="$PROJECT_ROOT/tests/m029-acceptance/p02-sc5-where-mixed-state.sh"

pass=0
fail=0

ok() { printf 'PASS: %s\n' "$1"; pass=$(( pass + 1 )); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$(( fail + 1 )); }

# 1. File exists.
if [ -f "$SC5" ]; then
    ok "p02-sc5-where-mixed-state.sh exists"
else
    bad "p02-sc5-where-mixed-state.sh missing at $SC5"
    printf 'SUMMARY: m029-p02-sc5-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2. Executable.
if [ -x "$SC5" ]; then
    ok "p02-sc5-where-mixed-state.sh is executable"
else
    bad "p02-sc5-where-mixed-state.sh is NOT executable"
fi

# 3. References the golden file.
if grep -q -- 'where-mixed-state.golden' "$SC5"; then
    ok "SC-5 references where-mixed-state.golden"
else
    bad "SC-5 missing where-mixed-state.golden reference"
fi

# 4. References timestamp-strip.sh.
if grep -q -- 'timestamp-strip.sh' "$SC5"; then
    ok "SC-5 references timestamp-strip.sh"
else
    bad "SC-5 missing timestamp-strip.sh reference"
fi

# 5. Emits the canonical SUMMARY line shape.
if grep -E -q -- 'SUMMARY: p02-sc5-where-mixed-state\.sh pass=' "$SC5"; then
    ok "SC-5 emits canonical SUMMARY line"
else
    bad "SC-5 missing canonical SUMMARY line"
fi

# 6. Header references SC-5 + FR-5.
HEADER="$( head -40 "$SC5" )"
if printf '%s' "$HEADER" | grep -q -- 'SC-5'; then
    ok "SC-5 header references SC-5"
else
    bad "SC-5 header missing SC-5 reference"
fi
if printf '%s' "$HEADER" | grep -q -- 'FR-5'; then
    ok "SC-5 header references FR-5"
else
    bad "SC-5 header missing FR-5 reference"
fi

# 7. Behavioral run: assert SC-5 acceptance exits 0.
SC5_OUT="$( mktemp )"
set +e
bash "$SC5" >"$SC5_OUT" 2>&1
sc5_rc=$?
set -e
if [ "$sc5_rc" -eq 0 ]; then
    ok "behavioral SC-5 acceptance script exits 0 (rc=$sc5_rc)"
else
    bad "behavioral SC-5 acceptance script exit non-zero (rc=$sc5_rc)"
    sed 's/^/   | /' "$SC5_OUT" >&2
fi
rm -f "$SC5_OUT"

printf 'SUMMARY: m029-p02-sc5-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
