#!/usr/bin/env bash
# tools/verify/m032-p01-installed-files-format.sh -- M032 P01 T04 (supersedes T01).
#
# Verifies FR-4 (installed-files.txt per-asset mode tracking).
#
# Actually-asserting-format-on-disk verifier (replaces T01's documentation-only
# stub). Stages the fresh-project fixture into mktemp -d, runs
# install-claude-code.sh, then reads <fixture>/.orchestrator/installed-files.txt
# and asserts:
#
#   * file is non-empty
#   * every non-blank line matches `^[^\t]+\tmode:(copy|symlink)$`
#     (path, single literal tab, mode:copy|symlink token)
#   * all four runtime dirs (commands/, scripts/, references/, templates/)
#     are represented in column 1 (path-of-record)
#
# Bash 3.2 compatible. No jq/python.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
FIXTURE="$PROJECT_ROOT/tests/fixtures/m032-fresh-project-fixture"
INSTALLER="$PROJECT_ROOT/packaging/install/install-claude-code.sh"
COLLISION="$PROJECT_ROOT/scripts/lifecycle/install-collision-check.sh"
HANDLER="$PROJECT_ROOT/scripts/lifecycle/install-asset-mode.sh"

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

# Pre-flight: helpers and fixture exist.
if [ ! -f "$COLLISION" ]; then
    check "install-collision-check.sh exists" 1
    printf 'SUMMARY: m032-p01-installed-files-format.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi
if [ ! -f "$HANDLER" ]; then
    check "install-asset-mode.sh exists" 1
    printf 'SUMMARY: m032-p01-installed-files-format.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi
if [ ! -d "$FIXTURE" ]; then
    check "fresh-project-fixture exists" 1
    printf 'SUMMARY: m032-p01-installed-files-format.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi
if [ ! -f "$INSTALLER" ]; then
    check "install-claude-code.sh exists" 1
    printf 'SUMMARY: m032-p01-installed-files-format.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# Stage fixture and run installer with sandboxed HOME.
TMP_BASE="$(mktemp -d)"
TMP_FIX="$TMP_BASE/m032-format-$$"
TMP_HOME="$TMP_BASE/home-$$"
mkdir -p "$TMP_FIX" "$TMP_HOME/.claude"

cleanup() {
    rm -rf "$TMP_BASE"
}
trap cleanup EXIT

cp -R "$FIXTURE/." "$TMP_FIX/"
( cd "$TMP_FIX" && git init -q && \
  git remote add origin https://github.com/fixture-owner/m032-fresh-project-fixture.git )

HOME="$TMP_HOME" bash "$INSTALLER" --project-dir "$TMP_FIX" > "$TMP_BASE/install.log" 2>&1
inst_rc=$?
if [ "$inst_rc" -ne 0 ]; then
    check "installer succeeds against staged fixture" 1
    cat "$TMP_BASE/install.log" >&2
    printf 'SUMMARY: m032-p01-installed-files-format.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi
check "installer succeeds against staged fixture" 0

INSTALLED="$TMP_FIX/.orchestrator/installed-files.txt"
if [ ! -f "$INSTALLED" ]; then
    check "installed-files.txt written by installer" 1
    printf 'SUMMARY: m032-p01-installed-files-format.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi
check "installed-files.txt written by installer" 0

# 1. Non-empty.
if [ -s "$INSTALLED" ]; then
    check "installed-files.txt is non-empty" 0
else
    check "installed-files.txt is non-empty" 1
fi

# 2. Every non-blank line matches `^[^\t]+\tmode:(copy|symlink)$`.
bad_line_count=$(awk 'NF > 0 && $0 !~ /^[^\t]+\tmode:(copy|symlink)$/' "$INSTALLED" | wc -l | tr -d ' ')
if [ "$bad_line_count" = "0" ]; then
    check "installed-files.txt: every non-blank line matches '<rel>\\tmode:(copy|symlink)' shape" 0
else
    check "installed-files.txt: every non-blank line matches '<rel>\\tmode:(copy|symlink)' shape (violations=$bad_line_count)" 1
    awk 'NF > 0 && $0 !~ /^[^\t]+\tmode:(copy|symlink)$/' "$INSTALLED" | head -5 >&2
fi

# 3. All four runtime dirs represented in column 1.
for dir in commands scripts references templates; do
    if awk -F'\t' '{print $1}' "$INSTALLED" | grep -qE "^${dir}/"; then
        check "installed-files.txt column 1 contains entries under ${dir}/" 0
    else
        check "installed-files.txt column 1 contains entries under ${dir}/" 1
    fi
done

# 4. The literal `mode:` token appears in column 2 (we already validated
#    line shape, but spell-check the contract by counting matches).
mode_line_count=$(grep -cE $'\tmode:(copy|symlink)$' "$INSTALLED")
if [ "$mode_line_count" -gt 0 ]; then
    check "installed-files.txt contains 'mode:(copy|symlink)' tokens (count=$mode_line_count)" 0
else
    check "installed-files.txt contains 'mode:(copy|symlink)' tokens" 1
fi

printf 'SUMMARY: m032-p01-installed-files-format.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
