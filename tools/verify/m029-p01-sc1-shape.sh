#!/usr/bin/env bash
# tools/verify/m029-p01-sc1-shape.sh -- M029 P01 SC-1 acceptance-script wrapper verifier.
#
# Asserts tests/m029-acceptance/p01-sc1-resolver.sh exists, is executable,
# references SC-1 + FR-1 in its header, invokes the AD-1 resolver script,
# and exits 0 when run.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SC1="$PROJECT_ROOT/tests/m029-acceptance/p01-sc1-resolver.sh"

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
if [ -f "$SC1" ]; then
    ok "tests/m029-acceptance/p01-sc1-resolver.sh exists"
else
    bad "tests/m029-acceptance/p01-sc1-resolver.sh missing"
    printf 'SUMMARY: m029-p01-sc1-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2. Executable.
if [ -x "$SC1" ]; then
    ok "tests/m029-acceptance/p01-sc1-resolver.sh executable"
else
    bad "tests/m029-acceptance/p01-sc1-resolver.sh not executable"
fi

# 3. Header references SC-1.
if grep -F -q 'SC-1' "$SC1"; then
    ok "header references SC-1"
else
    bad "header missing SC-1 reference"
fi

# 4. Header references FR-1.
if grep -F -q 'FR-1' "$SC1"; then
    ok "header references FR-1"
else
    bad "header missing FR-1 reference"
fi

# 5. Invokes the AD-1 resolver script.
if grep -F -q 'scripts/state/detect-invocation-context.sh' "$SC1"; then
    ok "invokes scripts/state/detect-invocation-context.sh"
else
    bad "does not invoke scripts/state/detect-invocation-context.sh"
fi

# 6. Run the SC-1 script and assert exit 0.
TMPDIR_LOCAL="$(mktemp -d -t m029-sc1-shape-XXXXXX)"
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT
sc1_out="$TMPDIR_LOCAL/sc1.out"
set +e
bash "$SC1" >"$sc1_out" 2>&1
sc1_rc=$?
set -e
if [ "$sc1_rc" -eq 0 ]; then
    ok "SC-1 acceptance script exits 0"
else
    bad "SC-1 acceptance script exited with rc=$sc1_rc"
    sed 's/^/   | /' "$sc1_out" >&2
fi

# 7. SC-1 final-line summary present.
if grep -q '^SC-1: pass=[0-9]\{1,\} fail=0$' "$sc1_out"; then
    ok "SC-1 final summary line present with fail=0"
else
    bad "SC-1 final summary line missing or fail!=0"
fi

printf 'SUMMARY: m029-p01-sc1-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
