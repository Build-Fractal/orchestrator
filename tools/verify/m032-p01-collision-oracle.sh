#!/usr/bin/env bash
# tools/verify/m032-p01-collision-oracle.sh -- M032 P01 FR-22 verifier.
#
# Exercises all three oracle branches of
# scripts/lifecycle/install-collision-check.sh against mktemp -d fixtures:
#   - Tracking-file branch: writes installed-files.txt then probes.
#   - Bootstrapping branch (MIT-006): no tracking file, target in list.
#   - Operator-owned branch: pre-existing target, not in tracking, not
#     gitignored. Asserts exit 4 + oracle=operator-owned + result=collision
#     on stderr.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
ORACLE="$PROJECT_ROOT/scripts/lifecycle/install-collision-check.sh"

pass=0
fail=0

check() {
    desc="$1"
    rc="$2"
    if [ "$rc" -eq 0 ]; then
        printf 'PASS: %s\n' "$desc"
        pass=$((pass + 1))
    else
        printf 'FAIL: %s\n' "$desc"
        fail=$((fail + 1))
    fi
}

# 1. Oracle script exists and is executable.
if [ -x "$ORACLE" ]; then
    check "install-collision-check.sh exists and is executable" 0
else
    check "install-collision-check.sh exists and is executable" 1
fi

# Stage a fixture project_dir.
FIXTURE="$( mktemp -d -t m032-p01-oracle.XXXXXX )"
trap 'rm -rf "$FIXTURE"' EXIT

PROJECT_DIR="$FIXTURE/project"
mkdir -p "$PROJECT_DIR/.orchestrator"

# Initialize fixture as a git repo (minimal) for git check-ignore behavior.
( cd "$PROJECT_DIR" && git init -q . && git config user.email "verify@example.com" && git config user.name "verify" )
# Add a .gitignore that ignores ignored-target/ to test the gitignored branch.
printf 'ignored-target/\n' > "$PROJECT_DIR/.gitignore"

PROJECT_ASSETS_LIST=$'commands/\nscripts/\nreferences/\ntemplates/'

# ---------- Branch 1: tracking-file oracle ----------

TRACKING="$PROJECT_DIR/.orchestrator/installed-files.txt"
printf 'commands/\nscripts/\n' > "$TRACKING"

ABS_TARGET="$PROJECT_DIR/commands"
out_t="$( mktemp -t m032-p01-oracle-t-out.XXXXXX )"
err_t="$( mktemp -t m032-p01-oracle-t-err.XXXXXX )"
bash "$ORACLE" "$ABS_TARGET" "$PROJECT_DIR" "$PROJECT_ASSETS_LIST" >"$out_t" 2>"$err_t"
rc_t=$?
if [ "$rc_t" -eq 0 ]; then
    check "tracking-file branch exit 0" 0
else
    printf 'FAIL: tracking-file branch exit %s (stderr: %s)\n' "$rc_t" "$(cat "$err_t")"
    fail=$((fail + 1))
fi
if grep -q 'oracle=tracking-file' "$out_t"; then
    check "tracking-file branch emits oracle=tracking-file" 0
else
    check "tracking-file branch emits oracle=tracking-file" 1
fi
if grep -q 'result=framework-installed' "$out_t"; then
    check "tracking-file branch emits result=framework-installed" 0
else
    check "tracking-file branch emits result=framework-installed" 1
fi
rm -f "$out_t" "$err_t"

# ---------- Branch 2: bootstrapping oracle (MIT-006) ----------
# No tracking file (delete it), target in project-assets list.

rm -f "$TRACKING"
ABS_TARGET2="$PROJECT_DIR/references"
out_b="$( mktemp -t m032-p01-oracle-b-out.XXXXXX )"
err_b="$( mktemp -t m032-p01-oracle-b-err.XXXXXX )"
bash "$ORACLE" "$ABS_TARGET2" "$PROJECT_DIR" "$PROJECT_ASSETS_LIST" >"$out_b" 2>"$err_b"
rc_b=$?
if [ "$rc_b" -eq 0 ]; then
    check "bootstrapping branch exit 0" 0
else
    printf 'FAIL: bootstrapping branch exit %s (stderr: %s)\n' "$rc_b" "$(cat "$err_b")"
    fail=$((fail + 1))
fi
if grep -q 'oracle=bootstrapping' "$out_b"; then
    check "bootstrapping branch emits oracle=bootstrapping" 0
else
    check "bootstrapping branch emits oracle=bootstrapping" 1
fi
if grep -q 'mit=MIT-006' "$out_b"; then
    check "bootstrapping branch emits mit=MIT-006" 0
else
    check "bootstrapping branch emits mit=MIT-006" 1
fi
rm -f "$out_b" "$err_b"

# ---------- Branch 3: operator-owned oracle ----------
# Pre-existing target not in tracking, not in project-assets list, not gitignored.
# (Tracking file still absent from the previous branch teardown.)

OPERATOR_TARGET="$PROJECT_DIR/operator-owned-dir"
mkdir -p "$OPERATOR_TARGET"
printf 'operator file\n' > "$OPERATOR_TARGET/file.txt"

# Make sure the tracking file is absent so we don't hit branch 1.
# But wait: if tracking file is absent AND target is not in project-assets list,
# the bootstrapping branch only matches list entries. So our operator-owned
# target ("operator-owned-dir/") is NOT in the list AND IS pre-existing AND
# NOT gitignored -> should hit the operator-owned branch.

# However the spec says: bootstrapping oracle applies only when
# installed-files.txt is absent AND the target IS in the list. Otherwise
# proceeds to operator-owned check. So:

out_o="$( mktemp -t m032-p01-oracle-o-out.XXXXXX )"
err_o="$( mktemp -t m032-p01-oracle-o-err.XXXXXX )"
bash "$ORACLE" "$OPERATOR_TARGET" "$PROJECT_DIR" "$PROJECT_ASSETS_LIST" >"$out_o" 2>"$err_o"
rc_o=$?
if [ "$rc_o" -eq 4 ]; then
    check "operator-owned branch exit 4" 0
else
    printf 'FAIL: operator-owned branch exit %s (expected 4) stderr: %s\n' "$rc_o" "$(cat "$err_o")"
    fail=$((fail + 1))
fi
if grep -q 'oracle=operator-owned' "$err_o"; then
    check "operator-owned branch emits oracle=operator-owned on stderr" 0
else
    check "operator-owned branch emits oracle=operator-owned on stderr" 1
fi
if grep -q 'result=collision' "$err_o"; then
    check "operator-owned branch emits result=collision on stderr" 0
else
    check "operator-owned branch emits result=collision on stderr" 1
fi
if grep -q 'staged-dirs-collision:' "$err_o"; then
    check "operator-owned branch emits staged-dirs-collision diagnostic" 0
else
    check "operator-owned branch emits staged-dirs-collision diagnostic" 1
fi
rm -f "$out_o" "$err_o"

# ---------- Branch 4 (sanity): gitignored target -> clean (exit 0). ----------

IGNORED_TARGET="$PROJECT_DIR/ignored-target"
mkdir -p "$IGNORED_TARGET"
printf 'junk\n' > "$IGNORED_TARGET/junk.txt"
out_i="$( mktemp -t m032-p01-oracle-i-out.XXXXXX )"
err_i="$( mktemp -t m032-p01-oracle-i-err.XXXXXX )"
bash "$ORACLE" "$IGNORED_TARGET" "$PROJECT_DIR" "$PROJECT_ASSETS_LIST" >"$out_i" 2>"$err_i"
rc_i=$?
if [ "$rc_i" -eq 0 ]; then
    check "gitignored target -> exit 0 (clean)" 0
else
    printf 'FAIL: gitignored target exit %s (expected 0) stderr: %s\n' "$rc_i" "$(cat "$err_i")"
    fail=$((fail + 1))
fi
if grep -q 'oracle=clean' "$out_i"; then
    check "gitignored target emits oracle=clean" 0
else
    check "gitignored target emits oracle=clean" 1
fi
rm -f "$out_i" "$err_i"

printf 'SUMMARY: m032-p01-collision-oracle.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
