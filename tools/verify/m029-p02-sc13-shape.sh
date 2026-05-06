#!/usr/bin/env bash
# tools/verify/m029-p02-sc13-shape.sh
#
# M029 P02 / T04 SC-13 acceptance script wrapper verifier.
#
# Asserts:
#   - tests/m029-acceptance/p02-sc13-anti-coupling.sh exists, is
#     executable, references the load-bearing /integrations/github
#     literal it scans for, and references the renderer file path.
#   - The script emits the canonical SUMMARY line shape.
#   - Behavioral run: invoking the SC-13 acceptance script yields exit
#     0 (no /integrations/github coupling in the renderer body, no
#     normative read-imperative against the path in spec.md).
#
# Spec references: FR-11, CON-4, SC-13.
#
# Single-script-file shape per AD-19. Bash 3.2 compatible.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
SC13="$PROJECT_ROOT/tests/m029-acceptance/p02-sc13-anti-coupling.sh"

pass=0
fail=0

ok() { printf 'PASS: %s\n' "$1"; pass=$(( pass + 1 )); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$(( fail + 1 )); }

# 1. File exists.
if [ -f "$SC13" ]; then
    ok "p02-sc13-anti-coupling.sh exists"
else
    bad "p02-sc13-anti-coupling.sh missing at $SC13"
    printf 'SUMMARY: m029-p02-sc13-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2. Executable.
if [ -x "$SC13" ]; then
    ok "p02-sc13-anti-coupling.sh is executable"
else
    bad "p02-sc13-anti-coupling.sh is NOT executable"
fi

# 3. References /integrations/github literal (the load-bearing token).
if grep -q -- '/integrations/github' "$SC13"; then
    ok "SC-13 references /integrations/github literal"
else
    bad "SC-13 missing /integrations/github literal"
fi

# 4. References render-position.sh.
if grep -q -- 'render-position.sh' "$SC13"; then
    ok "SC-13 references render-position.sh"
else
    bad "SC-13 missing render-position.sh reference"
fi

# 5. Emits canonical SUMMARY line shape.
if grep -E -q -- 'SUMMARY: p02-sc13-anti-coupling\.sh pass=' "$SC13"; then
    ok "SC-13 emits canonical SUMMARY line"
else
    bad "SC-13 missing canonical SUMMARY line"
fi

# 6. Header references SC-13 + FR-11 / CON-4.
HEADER="$( head -40 "$SC13" )"
if printf '%s' "$HEADER" | grep -q -- 'SC-13'; then
    ok "SC-13 header references SC-13"
else
    bad "SC-13 header missing SC-13 reference"
fi
if printf '%s' "$HEADER" | grep -E -q -- 'FR-11|CON-4'; then
    ok "SC-13 header references FR-11 / CON-4"
else
    bad "SC-13 header missing FR-11 / CON-4 reference"
fi

# 7. Behavioral run: assert SC-13 acceptance exits 0.
SC13_OUT="$( mktemp )"
set +e
bash "$SC13" >"$SC13_OUT" 2>&1
sc13_rc=$?
set -e
if [ "$sc13_rc" -eq 0 ]; then
    ok "behavioral SC-13 acceptance script exits 0 (rc=$sc13_rc)"
else
    bad "behavioral SC-13 acceptance script exit non-zero (rc=$sc13_rc)"
    sed 's/^/   | /' "$SC13_OUT" >&2
fi
rm -f "$SC13_OUT"

printf 'SUMMARY: m029-p02-sc13-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
