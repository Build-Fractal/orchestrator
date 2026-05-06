#!/usr/bin/env bash
# tools/verify/m029-p02-sc14-shape.sh
#
# M029 P02 / T04 SC-14 acceptance script wrapper verifier.
#
# Asserts:
#   - tests/m029-acceptance/p02-sc14-readonly.sh exists, is
#     executable, references the sentinel-harness path, and
#     references the renderer path.
#   - The script emits the canonical SUMMARY line shape.
#   - Behavioral run: invoking the SC-14 acceptance script yields exit
#     0 (sentinel-harness reports read-only invariant held when the
#     renderer is run against the SC-5 fixture tree).
#
# Spec references: CON-1, FR-14, AD-9, SC-14.
#
# Single-script-file shape per AD-19. Bash 3.2 compatible.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
SC14="$PROJECT_ROOT/tests/m029-acceptance/p02-sc14-readonly.sh"

pass=0
fail=0

ok() { printf 'PASS: %s\n' "$1"; pass=$(( pass + 1 )); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$(( fail + 1 )); }

# 1. File exists.
if [ -f "$SC14" ]; then
    ok "p02-sc14-readonly.sh exists"
else
    bad "p02-sc14-readonly.sh missing at $SC14"
    printf 'SUMMARY: m029-p02-sc14-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2. Executable.
if [ -x "$SC14" ]; then
    ok "p02-sc14-readonly.sh is executable"
else
    bad "p02-sc14-readonly.sh is NOT executable"
fi

# 3. References sentinel-harness.sh.
if grep -q -- 'sentinel-harness.sh' "$SC14"; then
    ok "SC-14 references sentinel-harness.sh"
else
    bad "SC-14 missing sentinel-harness.sh reference"
fi

# 4. References render-position.sh.
if grep -q -- 'render-position.sh' "$SC14"; then
    ok "SC-14 references render-position.sh"
else
    bad "SC-14 missing render-position.sh reference"
fi

# 5. Emits canonical SUMMARY line shape.
if grep -E -q -- 'SUMMARY: p02-sc14-readonly\.sh pass=' "$SC14"; then
    ok "SC-14 emits canonical SUMMARY line"
else
    bad "SC-14 missing canonical SUMMARY line"
fi

# 6. Header references SC-14 + AD-9 / CON-1 / FR-14.
HEADER="$( head -40 "$SC14" )"
if printf '%s' "$HEADER" | grep -q -- 'SC-14'; then
    ok "SC-14 header references SC-14"
else
    bad "SC-14 header missing SC-14 reference"
fi
if printf '%s' "$HEADER" | grep -E -q -- 'AD-9|CON-1|FR-14'; then
    ok "SC-14 header references AD-9 / CON-1 / FR-14"
else
    bad "SC-14 header missing AD-9 / CON-1 / FR-14 reference"
fi

# 7. Behavioral run: assert SC-14 acceptance exits 0.
SC14_OUT="$( mktemp )"
set +e
bash "$SC14" >"$SC14_OUT" 2>&1
sc14_rc=$?
set -e
if [ "$sc14_rc" -eq 0 ]; then
    ok "behavioral SC-14 acceptance script exits 0 (rc=$sc14_rc)"
else
    bad "behavioral SC-14 acceptance script exit non-zero (rc=$sc14_rc)"
    sed 's/^/   | /' "$SC14_OUT" >&2
fi
rm -f "$SC14_OUT"

printf 'SUMMARY: m029-p02-sc14-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
