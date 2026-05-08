#!/usr/bin/env bash
# tools/verify/m035-p00-managed-gitignore.sh -- M035 P00 T02 shape verifier.
#
# Asserts FR-6 / SC-6: each of the three installers emits a marker-delimited
# `# >>> orchestrator-managed: gitignore >>>` block to <PROJECT_DIR>/.gitignore
# containing at minimum `.orchestrator/install-meta.txt`, and re-runs replace
# the block contents in place (idempotent — exactly one block remains).
#
# Two layers of verification:
#
#   1. Wiring layer (per installer, grep-based): each installer invokes
#      scripts/lifecycle/emit-managed-gitignore.sh with --project-dir and
#      surfaces a non-zero exit on failure.
#
#   2. Behaviour layer (4-fixture battery against the helper directly + a
#      dry-run probe of install-claude-code.sh per the task plan):
#        Fixture A: dry-run on absent .gitignore emits would_write=...
#        Fixture B: real run on absent .gitignore creates exactly one
#                   marker block containing .orchestrator/install-meta.txt.
#        Fixture C: pre-existing .gitignore content preserved AND block
#                   appended below.
#        Fixture D: idempotency — two consecutive runs leave exactly one
#                   marker block.
#
# Behaviour-layer fixtures B/C/D run against the helper directly because:
#   - The helper IS what each installer invokes (proven by the wiring layer);
#   - Running install-codex.sh / install-cursor.sh end-to-end requires those
#     runtimes to be probe-available, which is not portable to CI.
# Fixture A additionally exercises install-claude-code.sh in --dry-run mode
# (probe must succeed in dev environments with Claude Code installed).
#
# Bash 3.2 compatible.
#
# Exit:
#   0  PASS
#   1  FAIL

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"

INSTALLERS="install-claude-code.sh install-codex.sh install-cursor.sh"
HELPER="$REPO_ROOT/scripts/lifecycle/emit-managed-gitignore.sh"

OPENER='# >>> orchestrator-managed: gitignore >>>'
CLOSER='# <<< orchestrator-managed: gitignore <<<'

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

WORKDIR="$( mktemp -d -t m035-gitignore.XXXXXX )"
trap 'rm -rf "$WORKDIR"' EXIT

printf '=== m035-p00-managed-gitignore (T02 / FR-6 / SC-6) ===\n'
printf 'bash_version=%s\n' "${BASH_VERSION:-unknown}"
printf 'workdir=%s\n' "$WORKDIR"
printf '\n'

# ---------- Helper presence ----------

if [ -f "$HELPER" ]; then
    check_pass "helper exists: scripts/lifecycle/emit-managed-gitignore.sh"
else
    check_fail "helper missing: scripts/lifecycle/emit-managed-gitignore.sh"
fi

# ---------- Wiring layer ----------

for name in $INSTALLERS; do
    installer="$REPO_ROOT/packaging/install/$name"
    if [ ! -f "$installer" ]; then
        check_fail "$name: file not found"
        continue
    fi

    if grep -qE 'emit-managed-gitignore\.sh' "$installer"; then
        check_pass "$name: wires emit-managed-gitignore.sh"
    else
        check_fail "$name: missing emit-managed-gitignore.sh wiring"
    fi

    if grep -qE 'emit-managed-gitignore\.sh.*--project-dir' "$installer"; then
        check_pass "$name: passes --project-dir to helper"
    else
        check_fail "$name: missing --project-dir to helper"
    fi

    # Wiring must surface a non-zero helper exit on failure.
    if grep -qE 'FAIL: emit-managed-gitignore\.sh exited' "$installer"; then
        check_pass "$name: surfaces helper failure on stderr"
    else
        check_fail "$name: missing FAIL message for emit-managed-gitignore.sh"
    fi

    # Wiring must NOT live inside the --uninstall or --repair short-circuit.
    # Heuristic: the helper invocation should appear after the second
    # 'install-meta.txt' write (the install path's sidecar), which itself is
    # past the uninstall/repair short-circuits.
    helper_line="$( grep -n 'emit-managed-gitignore\.sh' "$installer" | head -1 | cut -d: -f1 )"
    meta_line="$( grep -n 'meta_file=.*install-meta\.txt' "$installer" | tail -1 | cut -d: -f1 )"
    if [ -n "$helper_line" ] && [ -n "$meta_line" ] && [ "$helper_line" -gt "$meta_line" ]; then
        check_pass "$name: helper invocation appears after install-meta.txt write (install path, not uninstall/repair)"
    else
        check_fail "$name: helper invocation not positioned after install-meta.txt write"
    fi
done

# ---------- Fixture A: dry-run on absent .gitignore via install-claude-code.sh ----------

FIX_A="$WORKDIR/fixA"
mkdir -p "$FIX_A"
# Probe Claude Code availability via the adapter -- if unavailable, fall back
# to direct helper dry-run (still proves the helper's contract).
ADAPTER="$REPO_ROOT/scripts/dispatch/adapters/runtime/claude-code.sh"
adapter_avail=0
if [ -f "$ADAPTER" ]; then
    bash "$ADAPTER" --probe 2>/dev/null | grep -q '^available=true'
    if [ $? -eq 0 ]; then adapter_avail=1; fi
fi

if [ "$adapter_avail" = "1" ]; then
    a_log="$WORKDIR/fixA.log"
    bash "$REPO_ROOT/packaging/install/install-claude-code.sh" \
        --project-dir "$FIX_A" --dry-run --force > "$a_log" 2>&1
    a_rc=$?
    # The installer dry-run will print would_write=<FIX_A>/.gitignore via the
    # helper. Don't gate on the installer's overall rc — many other dry-run
    # branches may emit informational stderr. Just check the helper line.
    if grep -qE "would_write=$FIX_A/\\.gitignore" "$a_log"; then
        check_pass "fixture A: install-claude-code.sh --dry-run emits would_write=<fixA>/.gitignore"
    else
        check_fail "fixture A: install-claude-code.sh --dry-run did not emit would_write line for .gitignore (rc=$a_rc, log=$a_log)"
    fi
else
    # Adapter unavailable: prove helper contract directly.
    a_log="$WORKDIR/fixA-direct.log"
    bash "$HELPER" --project-dir "$FIX_A" --dry-run > "$a_log" 2>&1
    a_rc=$?
    if [ "$a_rc" -eq 0 ] && grep -qE "would_write=$FIX_A/\\.gitignore" "$a_log"; then
        check_pass "fixture A (claude-code probe unavailable, helper-direct fallback): dry-run emits would_write=<fixA>/.gitignore"
    else
        check_fail "fixture A (helper-direct fallback): dry-run did not emit expected would_write line (rc=$a_rc)"
    fi
fi

# ---------- Helper-direct fixtures (B / C / D) ----------
# These run against the helper directly. The wiring layer above proves each
# installer invokes this same helper, so behaviour-layer parity follows.

# Helper for "exactly one block" assertion.
count_blocks() {
    f="$1"
    if [ ! -f "$f" ]; then echo "0"; return; fi
    grep -cE '^# >>> orchestrator-managed: gitignore >>>$' "$f" | tr -d ' '
}

# ---------- Fixture B: absent .gitignore -> created with one block + sidecar ----------
FIX_B="$WORKDIR/fixB"
mkdir -p "$FIX_B"
bash "$HELPER" --project-dir "$FIX_B" > "$WORKDIR/fixB.log" 2>&1
b_rc=$?
if [ "$b_rc" -ne 0 ]; then
    check_fail "fixture B: helper exited $b_rc (log=$WORKDIR/fixB.log)"
elif [ ! -f "$FIX_B/.gitignore" ]; then
    check_fail "fixture B: .gitignore not created"
else
    nblk="$(count_blocks "$FIX_B/.gitignore")"
    if [ "$nblk" = "1" ]; then
        check_pass "fixture B: exactly one marker block in newly-created .gitignore"
    else
        check_fail "fixture B: expected 1 block, found $nblk"
    fi
    if grep -qE '^\.orchestrator/install-meta\.txt$' "$FIX_B/.gitignore"; then
        check_pass "fixture B: block contains .orchestrator/install-meta.txt"
    else
        check_fail "fixture B: .orchestrator/install-meta.txt missing from block"
    fi
    if grep -qE '^# <<< orchestrator-managed: gitignore <<<$' "$FIX_B/.gitignore"; then
        check_pass "fixture B: closer present"
    else
        check_fail "fixture B: closer missing"
    fi
fi

# ---------- Fixture C: pre-existing user content preserved + block appended ----------
FIX_C="$WORKDIR/fixC"
mkdir -p "$FIX_C"
printf 'node_modules/\n*.log\n' > "$FIX_C/.gitignore"
bash "$HELPER" --project-dir "$FIX_C" > "$WORKDIR/fixC.log" 2>&1
c_rc=$?
if [ "$c_rc" -ne 0 ]; then
    check_fail "fixture C: helper exited $c_rc"
else
    if grep -qE '^node_modules/$' "$FIX_C/.gitignore"; then
        check_pass "fixture C: pre-existing 'node_modules/' line preserved"
    else
        check_fail "fixture C: pre-existing 'node_modules/' line lost"
    fi
    if grep -qE '^\*\.log$' "$FIX_C/.gitignore"; then
        check_pass "fixture C: pre-existing '*.log' line preserved"
    else
        check_fail "fixture C: pre-existing '*.log' line lost"
    fi
    nblk="$(count_blocks "$FIX_C/.gitignore")"
    if [ "$nblk" = "1" ]; then
        check_pass "fixture C: exactly one managed block appended"
    else
        check_fail "fixture C: expected 1 block, found $nblk"
    fi
fi

# ---------- Fixture D: idempotency — two consecutive runs leave exactly one block ----------
FIX_D="$WORKDIR/fixD"
mkdir -p "$FIX_D"
printf 'dist/\n' > "$FIX_D/.gitignore"
bash "$HELPER" --project-dir "$FIX_D" > "$WORKDIR/fixD-run1.log" 2>&1
d1_rc=$?
bash "$HELPER" --project-dir "$FIX_D" > "$WORKDIR/fixD-run2.log" 2>&1
d2_rc=$?
if [ "$d1_rc" -ne 0 ] || [ "$d2_rc" -ne 0 ]; then
    check_fail "fixture D: helper run failed (rc1=$d1_rc rc2=$d2_rc)"
else
    nblk="$(count_blocks "$FIX_D/.gitignore")"
    if [ "$nblk" = "1" ]; then
        check_pass "fixture D: exactly one marker block after two consecutive runs (idempotent, SC-6 load-bearing)"
    else
        check_fail "fixture D: expected 1 block after second run, found $nblk"
    fi
    if grep -qE '^dist/$' "$FIX_D/.gitignore"; then
        check_pass "fixture D: pre-existing user content survives idempotent re-run"
    else
        check_fail "fixture D: pre-existing 'dist/' line lost on idempotent re-run"
    fi
fi

# ---------- Defensive: multiple-blocks collapse ----------
FIX_E="$WORKDIR/fixE"
mkdir -p "$FIX_E"
{
    printf 'node_modules/\n'
    printf '%s\n' "$OPENER"
    printf 'old-content-1\n'
    printf '%s\n' "$CLOSER"
    printf 'middle-user\n'
    printf '%s\n' "$OPENER"
    printf 'old-content-2\n'
    printf '%s\n' "$CLOSER"
    printf 'trailing-user\n'
} > "$FIX_E/.gitignore"
bash "$HELPER" --project-dir "$FIX_E" > "$WORKDIR/fixE.log" 2>&1
e_rc=$?
if [ "$e_rc" -ne 0 ]; then
    check_fail "fixture E (defensive collapse): helper exited $e_rc"
else
    nblk="$(count_blocks "$FIX_E/.gitignore")"
    if [ "$nblk" = "1" ]; then
        check_pass "fixture E (defensive): pre-existing duplicate blocks collapsed to one"
    else
        check_fail "fixture E (defensive): expected 1 block after collapse, found $nblk"
    fi
    if grep -qE '^middle-user$' "$FIX_E/.gitignore"; then
        check_pass "fixture E (defensive): user content between original blocks preserved"
    else
        check_fail "fixture E (defensive): 'middle-user' lost during collapse"
    fi
    if grep -qE '^trailing-user$' "$FIX_E/.gitignore"; then
        check_pass "fixture E (defensive): user content after final block preserved"
    else
        check_fail "fixture E (defensive): 'trailing-user' lost during collapse"
    fi
fi

# ---------- Verdict ----------

printf '\n'
if [ "$fail" -eq 0 ]; then
    printf 'PASS: m035-p00-managed-gitignore (4-fixture battery x 3 installers green; idempotent) checks=%d\n' "$pass"
    exit 0
else
    printf 'FAIL: m035-p00-managed-gitignore (pass=%d fail=%d)\n' "$pass" "$fail"
    printf '%b' "$failures" >&2
    exit 1
fi
