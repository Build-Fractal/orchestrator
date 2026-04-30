#!/usr/bin/env bash
# scripts/verify/m028/p02-hook-self-locate.sh
#
# M028/P02/T01 verifier (Finding A): asserts the PreToolUse shape-guard hook
# resolves its classifier path purely from BASH_SOURCE -- no
# CLAUDE_PROJECT_DIR consultation, with pwd -P symlink resolution.
#
# Single-script-file shape (AD-19). Bash 3.2 + POSIX-sh safe.
# set -u; no set -e (we want every check to run independently).

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd -P)"
HOOK="${REPO_ROOT}/scripts/hooks/pre-bash-shape-guard.sh"

if [ ! -f "$HOOK" ]; then
  printf 'FAIL: hook file not found at %s\n' "$HOOK" >&2
  exit 1
fi

fail_count=0

# Check 1: hook must contain BASH_SOURCE self-location pattern.
if ! grep -q "BASH_SOURCE" "$HOOK"; then
  printf 'FAIL: hook does not contain BASH_SOURCE self-location pattern\n' >&2
  fail_count=$((fail_count + 1))
fi

# Check 2: hook must NOT reference CLAUDE_PROJECT_DIR anywhere
# (intentionally retired from the hook's logic per Finding A).
if grep -q "CLAUDE_PROJECT_DIR" "$HOOK"; then
  printf 'FAIL: hook still references CLAUDE_PROJECT_DIR (Finding A retirement violated)\n' >&2
  fail_count=$((fail_count + 1))
fi

# Check 3: hook must contain `pwd -P` for symlink resolution.
if ! grep -q "pwd -P" "$HOOK"; then
  printf 'FAIL: hook does not contain pwd -P symlink resolution\n' >&2
  fail_count=$((fail_count + 1))
fi

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi

printf 'PASS: hook self-location via BASH_SOURCE confirmed; CLAUDE_PROJECT_DIR retired; pwd -P symlink resolution present\n'
exit 0
