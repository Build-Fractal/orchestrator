#!/usr/bin/env bash
# tests/m032-acceptance/p01-symlink-mode.sh -- M032 P01 SC-2.
#
# Asserts FR-3:
#   1. With --asset-mode-override symlink, each of the four runtime dirs
#      (commands/, scripts/, references/, templates/) is materialized as
#      a symbolic link under the project dir.
#   2. The fixture's .gitignore excludes those four dirs, so post-install
#      `git status --short -- commands scripts references templates` emits
#      zero lines.
#   3. Under M032_FORCE_WINDOWS=1, the installer fails closed with
#      "POSIX-only in v1" on stderr and writes nothing under the runtime
#      dirs (no half-state).
#
# POSIX SKIP: if `ln -s` is unavailable in the test host, exit 77 with
# `SKIP_REASON: ln -s unavailable` per MIT-001.
#
# Output:
#   RESULT: ok p01-symlink-mode.sh
#   RESULT: skip p01-symlink-mode.sh reason=<reason>
#   RESULT: fail p01-symlink-mode.sh reason=<reason>
#
# Bash 3.2 compatible. No jq/python.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
REPO_ROOT="$( cd "$REPO_ROOT/.." && pwd )"
FIXTURE="$REPO_ROOT/tests/fixtures/m032-fresh-project-fixture"
INSTALLER="$REPO_ROOT/packaging/install/install-claude-code.sh"

emit_fail() {
    printf 'RESULT: fail p01-symlink-mode.sh reason=%s\n' "$1"
}
emit_skip() {
    printf 'RESULT: skip p01-symlink-mode.sh reason=%s\n' "$1"
}

if [ ! -d "$FIXTURE" ]; then
    emit_fail "fixture-missing:$FIXTURE"
    exit 1
fi
if [ ! -f "$INSTALLER" ]; then
    emit_fail "installer-missing:$INSTALLER"
    exit 1
fi

# --- Stage primary fixture for the symlink-success branch. ---
TMP_BASE="$(mktemp -d)"
TMP_FIX="$TMP_BASE/m032-sc2-$$"
TMP_FIX2="$TMP_BASE/m032-sc2b-$$"
TMP_HOME="$TMP_BASE/home-$$"
RUNTIME_CACHE="$TMP_BASE/orchestrator-runtime/m032-test-$$"
mkdir -p "$TMP_FIX" "$TMP_FIX2" "$TMP_HOME/.claude/orchestrator-runtime/test-$$"
mkdir -p "$RUNTIME_CACHE"

cleanup() {
    rm -rf "$TMP_BASE"
}
trap cleanup EXIT

# Probe `ln -s` availability per MIT-001.
if ! ln -s /dev/null "$TMP_FIX/.lntest" 2>/dev/null; then
    emit_skip "ln-s-unavailable"
    echo "SKIP_REASON: ln -s unavailable" >&2
    exit 77
fi
rm -f "$TMP_FIX/.lntest"

# Stage primary fixture.
cp -R "$FIXTURE/." "$TMP_FIX/"
( cd "$TMP_FIX" && git init -q && \
  git remote add origin https://github.com/fixture-owner/m032-fresh-project-fixture.git )

# Set up runtime cache that the symlink handler will resolve to.
cp -R "$REPO_ROOT/commands" "$REPO_ROOT/scripts" "$REPO_ROOT/references" "$REPO_ROOT/templates" "$RUNTIME_CACHE/"

# The symlink handler in install-asset-mode.sh prefers
# ${HOME}/.claude/orchestrator-runtime/<version>/, so place a symlink
# under TMP_HOME pointing at our runtime cache. Lexicographic-sort picks
# the last subdir; "v1" works fine.
ln -s "$RUNTIME_CACHE" "$TMP_HOME/.claude/orchestrator-runtime/v1"

# --- Branch A: symlink success. ---
HOME="$TMP_HOME" bash "$INSTALLER" --asset-mode-override symlink --project-dir "$TMP_FIX" \
    > "$TMP_BASE/run-symlink.log" 2>&1
rc_ok=$?
if [ "$rc_ok" -ne 0 ]; then
    emit_fail "symlink-install-exit=$rc_ok"
    cat "$TMP_BASE/run-symlink.log" >&2
    exit 1
fi

# Each runtime dir under TMP_FIX must be a symbolic link.
for dir in commands scripts references templates; do
    if [ ! -L "$TMP_FIX/$dir" ]; then
        emit_fail "FR-3:not-a-symlink:$dir"
        ls -la "$TMP_FIX" >&2
        exit 1
    fi
done

# git status --short should report ZERO lines for the four runtime dirs
# because the .gitignore excludes them.
( cd "$TMP_FIX" && git add -A . 2>/dev/null )
status_lines=$( cd "$TMP_FIX" && git status --short -- commands scripts references templates | wc -l | tr -d ' ' )
if [ "$status_lines" != "0" ]; then
    emit_fail "FR-3:git-status-not-clean:lines=$status_lines"
    ( cd "$TMP_FIX" && git status --short -- commands scripts references templates ) >&2
    exit 1
fi

# --- Branch B: Windows fail-closed. ---
cp -R "$FIXTURE/." "$TMP_FIX2/"
( cd "$TMP_FIX2" && git init -q && \
  git remote add origin https://github.com/fixture-owner/m032-fresh-project-fixture.git )

# Snapshot pre-run file count to assert no-write-on-fail.
before_count=$(find "$TMP_FIX2" -maxdepth 2 -type f | wc -l | tr -d ' ')

M032_FORCE_WINDOWS=1 HOME="$TMP_HOME" bash "$INSTALLER" \
    --asset-mode-override symlink --project-dir "$TMP_FIX2" \
    > "$TMP_BASE/run-windows.log" 2>&1
rc_win=$?

if [ "$rc_win" = "0" ]; then
    emit_fail "FR-3:windows-fail-closed-did-not-fail (exit=0)"
    cat "$TMP_BASE/run-windows.log" >&2
    exit 1
fi

# M035 P01 T01 (#Q-G4): advisory wording updated from "POSIX-only in v1"
# to "symlink mode unsupported on this filesystem -- re-run with --mode=copy".
# The exit-code contract (rc=3, fail-closed) is unchanged; only the user-
# facing advisory text changed.
if ! grep -q 'symlink mode unsupported on this filesystem' "$TMP_BASE/run-windows.log"; then
    emit_fail "FR-3:windows-fail-closed-missing-advisory-message"
    cat "$TMP_BASE/run-windows.log" >&2
    exit 1
fi

# No-write-on-fail: none of the four runtime dirs should exist as either
# a symlink or a populated directory under TMP_FIX2.
for dir in commands scripts references templates; do
    if [ -L "$TMP_FIX2/$dir" ]; then
        emit_fail "FR-3:windows-no-write-on-fail-violation:$dir-was-symlinked"
        exit 1
    fi
    if [ -d "$TMP_FIX2/$dir" ]; then
        # A populated dir under FORCE_WINDOWS proves the handler did NOT
        # fail-closed before writing. Empty dir is tolerated only if
        # truly empty (no files inside).
        cnt=$(find "$TMP_FIX2/$dir" -type f | wc -l | tr -d ' ')
        if [ "$cnt" != "0" ]; then
            emit_fail "FR-3:windows-no-write-on-fail-violation:$dir-has-$cnt-files"
            exit 1
        fi
    fi
done

printf 'RESULT: ok p01-symlink-mode.sh\n'
exit 0
