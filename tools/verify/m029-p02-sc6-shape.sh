#!/usr/bin/env bash
# tools/verify/m029-p02-sc6-shape.sh
#
# M029 P02 / T04 SC-6 acceptance script wrapper verifier.
#
# Asserts:
#   - tests/m029-acceptance/p02-sc6-where-pre-m019.sh exists, is
#     executable, and references the pre-M019 fixture path.
#   - The script asserts both cost-column suppression AND stderr
#     emptiness (FR-6 / CON-3).
#   - The script emits the canonical SUMMARY line shape.
#   - Behavioral run: invoking the SC-6 acceptance script against the
#     fixtures T04 just built yields exit 0.
#
# Spec references: FR-6, CON-3, SC-6.
#
# Single-script-file shape per AD-19. Bash 3.2 compatible.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
SC6="$PROJECT_ROOT/tests/m029-acceptance/p02-sc6-where-pre-m019.sh"

pass=0
fail=0

ok() { printf 'PASS: %s\n' "$1"; pass=$(( pass + 1 )); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$(( fail + 1 )); }

# 1. File exists.
if [ -f "$SC6" ]; then
    ok "p02-sc6-where-pre-m019.sh exists"
else
    bad "p02-sc6-where-pre-m019.sh missing at $SC6"
    printf 'SUMMARY: m029-p02-sc6-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2. Executable.
if [ -x "$SC6" ]; then
    ok "p02-sc6-where-pre-m019.sh is executable"
else
    bad "p02-sc6-where-pre-m019.sh is NOT executable"
fi

# 3. References pre-M019 fixture path.
if grep -q -- 'where-pre-m019.fixture' "$SC6"; then
    ok "SC-6 references where-pre-m019.fixture"
else
    bad "SC-6 missing where-pre-m019.fixture reference"
fi

# 4. Asserts cost-column suppression (looks for the `$<num>` token check).
if grep -E -q -- '\$\[0-9\]|cost' "$SC6"; then
    ok "SC-6 carries cost-column suppression assertion"
else
    bad "SC-6 missing cost-column suppression assertion"
fi

# 5. Asserts stderr emptiness.
if grep -q -- 'stderr' "$SC6"; then
    ok "SC-6 carries stderr-empty assertion"
else
    bad "SC-6 missing stderr-empty assertion"
fi

# 6. Emits canonical SUMMARY line shape.
if grep -E -q -- 'SUMMARY: p02-sc6-where-pre-m019\.sh pass=' "$SC6"; then
    ok "SC-6 emits canonical SUMMARY line"
else
    bad "SC-6 missing canonical SUMMARY line"
fi

# 7. Header references SC-6 + FR-6 / CON-3.
HEADER="$( head -40 "$SC6" )"
if printf '%s' "$HEADER" | grep -q -- 'SC-6'; then
    ok "SC-6 header references SC-6"
else
    bad "SC-6 header missing SC-6 reference"
fi
if printf '%s' "$HEADER" | grep -E -q -- 'FR-6|CON-3'; then
    ok "SC-6 header references FR-6 / CON-3"
else
    bad "SC-6 header missing FR-6 / CON-3 reference"
fi

# 8. Behavioral run: assert SC-6 acceptance exits 0.
SC6_OUT="$( mktemp )"
set +e
bash "$SC6" >"$SC6_OUT" 2>&1
sc6_rc=$?
set -e
if [ "$sc6_rc" -eq 0 ]; then
    ok "behavioral SC-6 acceptance script exits 0 (rc=$sc6_rc)"
else
    bad "behavioral SC-6 acceptance script exit non-zero (rc=$sc6_rc)"
    sed 's/^/   | /' "$SC6_OUT" >&2
fi
rm -f "$SC6_OUT"

printf 'SUMMARY: m029-p02-sc6-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
