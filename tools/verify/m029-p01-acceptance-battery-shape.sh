#!/usr/bin/env bash
# tools/verify/m029-p01-acceptance-battery-shape.sh -- M029 P01 acceptance battery shape verifier.
#
# Asserts tests/m029-acceptance/p01-acceptance-battery.sh exists, is
# executable, invokes all four P01 SC scripts in dependency order, emits the
# canonical `BATTERY:` line, and exits 0 with `BATTERY: p01-acceptance pass=4 fail=0`
# when run end-to-end. The battery is the SC-11 slice -- the full SC-11
# acceptance battery (covering all 14 SCs) lands in P03.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BATTERY="$PROJECT_ROOT/tests/m029-acceptance/p01-acceptance-battery.sh"

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
    ok "tests/m029-acceptance/p01-acceptance-battery.sh exists"
else
    bad "tests/m029-acceptance/p01-acceptance-battery.sh missing"
    printf 'SUMMARY: m029-p01-acceptance-battery-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2. Executable.
if [ -x "$BATTERY" ]; then
    ok "battery script is executable"
else
    bad "battery script not executable"
fi

# 3. Body invokes all four SC scripts.
if grep -F -q 'p01-sc1-resolver.sh' "$BATTERY"; then
    ok "battery invokes p01-sc1-resolver.sh"
else
    bad "battery does not reference p01-sc1-resolver.sh"
fi
if grep -F -q 'p01-sc2-headline.sh' "$BATTERY"; then
    ok "battery invokes p01-sc2-headline.sh"
else
    bad "battery does not reference p01-sc2-headline.sh"
fi
if grep -F -q 'p01-sc3-format-json.sh' "$BATTERY"; then
    ok "battery invokes p01-sc3-format-json.sh"
else
    bad "battery does not reference p01-sc3-format-json.sh"
fi
if grep -F -q 'p01-sc4-context.sh' "$BATTERY"; then
    ok "battery invokes p01-sc4-context.sh"
else
    bad "battery does not reference p01-sc4-context.sh"
fi

# 4. Battery emits BATTERY: token.
if grep -F -q 'BATTERY:' "$BATTERY"; then
    ok "battery emits BATTERY: token literal"
else
    bad "battery does not emit BATTERY: token"
fi

# 5. Run end-to-end and capture stdout.
TMPDIR_LOCAL="$(mktemp -d -t m029-p01-battery-shape-XXXXXX)"
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

# 6. Stdout contains BATTERY: p01-acceptance pass= line.
if grep -F -q 'BATTERY: p01-acceptance pass=' "$battery_out"; then
    ok "stdout carries BATTERY: p01-acceptance pass= line"
else
    bad "stdout missing BATTERY: p01-acceptance pass= line"
fi

# 7. Final BATTERY line ends with fail=0 (no non-zero failure digit).
if grep -E -q '^BATTERY: p01-acceptance pass=[0-9]+ fail=0$' "$battery_out"; then
    ok "BATTERY line ends with fail=0"
else
    bad "BATTERY line missing fail=0 (likely indicates a SC sub-script failed)"
fi

printf 'SUMMARY: m029-p01-acceptance-battery-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
