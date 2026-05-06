#!/usr/bin/env bash
# tests/m029-acceptance/p01-sc1-resolver.sh -- M029 P01 SC-1 acceptance script.
#
# Exercises FR-1 (the AD-1 single-resolve invocation-context resolver) across
# the four input combinations documented in spec.md US-1 Acceptance Scenarios:
#   1. TTY=true,  CI=false                    -> renderer=tui  exit_code_scheme=interactive
#   2. TTY=false, CI=true                     -> renderer=plain
#   3. TTY=false, CI=false, --format=json     -> renderer=json exit_code_scheme=governance
#   4. TTY=true,  CI=true                     -> renderer=plain (CI forces plain even on TTY)
#   5. unknown flag                           -> non-zero exit, "unknown flag" on stderr
#
# Spec references: FR-1, SC-1, AD-1.
# Resolver under test: scripts/state/detect-invocation-context.sh.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESOLVER="$PROJECT_ROOT/scripts/state/detect-invocation-context.sh"

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

# Cleanup tmpdir on exit.
TMPDIR_LOCAL="$(mktemp -d -t m029-sc1-XXXXXX)"
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT

if [ ! -f "$RESOLVER" ]; then
    bad "resolver script missing at $RESOLVER"
    printf 'SC-1: pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# --- Case 1: TTY=true, CI=false -> tui + interactive --------------------------
out1="$TMPDIR_LOCAL/case1.out"
bash "$RESOLVER" --tty=true --ci=false >"$out1" 2>&1
if grep -q '^renderer=tui$' "$out1"; then
    ok "case1: renderer=tui present"
else
    bad "case1: renderer=tui missing"
fi
if grep -q '^exit_code_scheme=interactive$' "$out1"; then
    ok "case1: exit_code_scheme=interactive present"
else
    bad "case1: exit_code_scheme=interactive missing"
fi

# --- Case 2: TTY=false, CI=true -> plain ------------------------------------
out2="$TMPDIR_LOCAL/case2.out"
bash "$RESOLVER" --tty=false --ci=true >"$out2" 2>&1
if grep -q '^renderer=plain$' "$out2"; then
    ok "case2: renderer=plain present"
else
    bad "case2: renderer=plain missing"
fi

# --- Case 3: TTY=false, CI=false, --format=json -> json + governance ---------
out3="$TMPDIR_LOCAL/case3.out"
bash "$RESOLVER" --tty=false --ci=false --format=json >"$out3" 2>&1
if grep -q '^renderer=json$' "$out3"; then
    ok "case3: renderer=json present"
else
    bad "case3: renderer=json missing"
fi
if grep -q '^exit_code_scheme=governance$' "$out3"; then
    ok "case3: exit_code_scheme=governance present"
else
    bad "case3: exit_code_scheme=governance missing"
fi

# --- Case 4: TTY=true, CI=true -> plain (CI overrides TTY) -------------------
out4="$TMPDIR_LOCAL/case4.out"
bash "$RESOLVER" --tty=true --ci=true >"$out4" 2>&1
if grep -q '^renderer=plain$' "$out4"; then
    ok "case4: renderer=plain (CI=true overrides TTY=true)"
else
    bad "case4: renderer=plain (CI=true overrides TTY=true) -- got:"
    sed 's/^/   | /' "$out4" >&2
fi

# --- Case 5: unknown flag -> exit non-zero, "unknown flag" on stderr ---------
out5_stderr="$TMPDIR_LOCAL/case5.err"
out5_stdout="$TMPDIR_LOCAL/case5.out"
set +e
bash "$RESOLVER" --bogus-flag >"$out5_stdout" 2>"$out5_stderr"
case5_rc=$?
set -e
if [ "$case5_rc" -ne 0 ]; then
    ok "case5: unknown flag exits non-zero (rc=$case5_rc)"
else
    bad "case5: unknown flag should exit non-zero, got 0"
fi
if grep -q 'unknown flag' "$out5_stderr"; then
    ok "case5: stderr contains 'unknown flag'"
else
    bad "case5: stderr missing 'unknown flag' diagnostic"
fi

printf 'SC-1: pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
