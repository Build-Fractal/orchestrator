#!/usr/bin/env bash
# tools/verify/m035-p00-bash32-collision.sh -- M035 P00 T01 shape verifier.
#
# Asserts the three installers (install-claude-code.sh, install-codex.sh,
# install-cursor.sh) no longer carry the process-substitution-fed
# `while read` masking pattern (`done < <(bash ...)`) in executable code,
# carry the temp-file + producer-rc capture shape that replaced it, and
# that the regression fixture exists.
#
# Bash 3.2 compatible.
#
# Exit:
#   0  PASS (all three installers cleared + fixture authored)
#   1  FAIL (any installer still masks, or required shape missing,
#           or fixture missing)

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"

INSTALLERS="
$REPO_ROOT/packaging/install/install-claude-code.sh
$REPO_ROOT/packaging/install/install-codex.sh
$REPO_ROOT/packaging/install/install-cursor.sh
"

FIXTURE="$REPO_ROOT/tests/installer-acceptance/m035-collision-exit-status.sh"

pass=0
fail=0
failures=""

check_pass() {
    pass=$((pass + 1))
    printf '  ok: %s\n' "$1"
}

check_fail() {
    fail=$((fail + 1))
    failures="${failures}    - ${1}\n"
    printf '  FAIL: %s\n' "$1"
}

# ---------- Pattern checks (one set per installer) ----------

for installer in $INSTALLERS; do
    name="$( basename "$installer" )"
    if [ ! -f "$installer" ]; then
        check_fail "$name: file not found"
        continue
    fi

    # 1. Forbidden shape: `done < <(bash ...)` in executable code (not a
    #    comment line). Any uncommented match is a regression.
    forbidden_count="$( grep -nE '^[^#]*done < <\(bash' "$installer" | wc -l | tr -d ' ' )"
    if [ "$forbidden_count" = "0" ]; then
        check_pass "$name: no executable 'done < <(bash ...)' masking pattern"
    else
        check_fail "$name: $forbidden_count executable 'done < <(bash ...)' line(s) remain"
    fi

    # 2. Required shape: at least one mktemp temp-file allocation
    #    (the replacement form).
    if grep -qE 'mktemp -t orch-install-' "$installer"; then
        check_pass "$name: uses mktemp -t orch-install-* temp files"
    else
        check_fail "$name: missing mktemp -t orch-install-* temp file allocation"
    fi

    # 3. Required shape: producer rc captured.
    if grep -qE '_producer_rc=\$\?' "$installer"; then
        check_pass "$name: captures producer rc as _producer_rc"
    else
        check_fail "$name: missing _producer_rc capture"
    fi

    # 4. Required shape: producer rc gate (exit non-zero on producer fail).
    if grep -qE 'FAIL: read-project-assets\.sh exited' "$installer"; then
        check_pass "$name: surfaces read-project-assets.sh failure on stderr"
    else
        check_fail "$name: missing FAIL message for read-project-assets.sh"
    fi

    # 5. Required shape: temp file iterated via `done < "$_..._tmp"`.
    if grep -qE 'done < "\$_(collect|dispatch|manifest)_tmp"' "$installer"; then
        check_pass "$name: iterates temp file with 'done < \$_..._tmp'"
    else
        check_fail "$name: missing 'done < \$_..._tmp' iteration"
    fi
done

# ---------- Fixture check ----------

if [ -f "$FIXTURE" ]; then
    check_pass "regression fixture exists: tests/installer-acceptance/m035-collision-exit-status.sh"
else
    check_fail "regression fixture missing: tests/installer-acceptance/m035-collision-exit-status.sh"
fi

if [ -f "$FIXTURE" ] && grep -qE 'm035-p00-collision-exit-status' "$FIXTURE"; then
    check_pass "fixture announces canonical PASS line m035-p00-collision-exit-status"
else
    check_fail "fixture missing canonical PASS line m035-p00-collision-exit-status"
fi

# ---------- Summary ----------

printf '\n'
if [ "$fail" -eq 0 ]; then
    printf 'PASS: m035-p00-bash32-collision (3 installers cleared of process-substitution masking; fixture authored) checks=%d\n' "$pass"
    exit 0
else
    printf 'FAIL: m035-p00-bash32-collision (pass=%d fail=%d)\n' "$pass" "$fail"
    printf '%b' "$failures" >&2
    exit 1
fi
