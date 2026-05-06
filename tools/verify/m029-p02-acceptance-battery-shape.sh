#!/usr/bin/env bash
# tools/verify/m029-p02-acceptance-battery-shape.sh -- M029 P02 acceptance battery shape verifier.
#
# Asserts tests/m029-acceptance/p02-acceptance-battery.sh exists, is
# executable, invokes all four P02 SC scripts in dependency order, emits the
# canonical `BATTERY:` line, and exits 0 with `BATTERY: p02-acceptance pass=4 fail=0`
# when run end-to-end. The battery is the SC-11 slice -- the full SC-11
# acceptance battery (covering all 14 SCs) lands in P03.
#
# Mirrors tools/verify/m029-p01-acceptance-battery-shape.sh.
#
# Bash 3.2 / MEM001. AD-19 straight-line bash.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BATTERY="$PROJECT_ROOT/tests/m029-acceptance/p02-acceptance-battery.sh"

pass=0
fail=0

ok() {
    printf 'PASS: %s\n' "$1"
    pass=$((pass + 1))
}

bad() {
    printf 'FAIL: %s\n' "$1"
    fail=$((fail + 1))
}

# 1. File exists.
if [ -f "$BATTERY" ]; then
    ok "tests/m029-acceptance/p02-acceptance-battery.sh exists"
else
    bad "tests/m029-acceptance/p02-acceptance-battery.sh missing"
    printf 'SUMMARY: m029-p02-acceptance-battery-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2. Executable.
if [ -x "$BATTERY" ]; then
    ok "battery script is executable"
else
    bad "battery script not executable"
fi

# 3. Body invokes all four SC scripts.
if grep -F -q 'p02-sc5-where-mixed-state.sh' "$BATTERY"; then
    ok "battery invokes p02-sc5-where-mixed-state.sh"
else
    bad "battery does not reference p02-sc5-where-mixed-state.sh"
fi
if grep -F -q 'p02-sc6-where-pre-m019.sh' "$BATTERY"; then
    ok "battery invokes p02-sc6-where-pre-m019.sh"
else
    bad "battery does not reference p02-sc6-where-pre-m019.sh"
fi
if grep -F -q 'p02-sc13-anti-coupling.sh' "$BATTERY"; then
    ok "battery invokes p02-sc13-anti-coupling.sh"
else
    bad "battery does not reference p02-sc13-anti-coupling.sh"
fi
if grep -F -q 'p02-sc14-readonly.sh' "$BATTERY"; then
    ok "battery invokes p02-sc14-readonly.sh"
else
    bad "battery does not reference p02-sc14-readonly.sh"
fi

# 4. Battery emits BATTERY: token.
if grep -F -q 'BATTERY:' "$BATTERY"; then
    ok "battery emits BATTERY: token literal"
else
    bad "battery does not emit BATTERY: token"
fi

# 5. Bash 3.2 / MEM001 token present.
if grep -E -q 'Bash 3\.2|MEM001' "$BATTERY"; then
    ok "battery declares Bash 3.2 / MEM001 compatibility"
else
    bad "battery does not declare Bash 3.2 / MEM001 compatibility"
fi

# 6. AD-19 token present.
if grep -F -q 'AD-19' "$BATTERY"; then
    ok "battery references AD-19 straight-line discipline"
else
    bad "battery does not reference AD-19"
fi

# 7. Run end-to-end and capture stdout.
TMPDIR_LOCAL="$(mktemp -d -t m029-p02-battery-shape-XXXXXX)"
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT
battery_out="$TMPDIR_LOCAL/battery.out"
set +e
bash "$BATTERY" >"$battery_out" 2>&1
battery_rc=$?
set -e

if [ "$battery_rc" -eq 0 ]; then
    ok "battery exits 0"
else
    bad "battery exited rc=$battery_rc"
    sed 's/^/   | /' "$battery_out" >&2
fi

# 8. Stdout contains BATTERY: p02-acceptance pass= line.
if grep -F -q 'BATTERY: p02-acceptance pass=' "$battery_out"; then
    ok "stdout carries BATTERY: p02-acceptance pass= line"
else
    bad "stdout missing BATTERY: p02-acceptance pass= line"
fi

# 9. Final BATTERY line is exactly pass=4 fail=0 (load-bearing -- confirms
# every T01..T04 deliverable is green end-to-end).
if grep -E -q '^BATTERY: p02-acceptance pass=4 fail=0$' "$battery_out"; then
    ok "BATTERY line is pass=4 fail=0 (all four SCs green)"
else
    bad "BATTERY line is not pass=4 fail=0 (a SC sub-script failed)"
fi

printf 'SUMMARY: m029-p02-acceptance-battery-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
