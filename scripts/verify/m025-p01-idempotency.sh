#!/usr/bin/env bash
# scripts/verify/m025-p01-idempotency.sh -- M025/P01/T02 gate:
# validates that running install-claude-code.sh twice in succession against
# the same HOME produces byte-identical settings.json on runs 1 vs 2.
#
# Bash 3.2 compatible. AD-19 single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INSTALLER="${REPO_ROOT}/packaging/install/install-claude-code.sh"

passed=0
failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }

TMPHOME="$(mktemp -d -t m025-p01-idemp-home.XXXXXX)"
TMPPRJ="$(mktemp -d -t m025-p01-idemp-prj.XXXXXX)"
cleanup() { rm -rf "$TMPHOME" "$TMPPRJ"; }
trap cleanup EXIT

mkdir -p "$TMPHOME/.claude"

# First install (onto empty HOME -- new-file path).
CLAUDECODE=1 HOME="$TMPHOME" bash "$INSTALLER" --project-dir "$TMPPRJ" >/dev/null 2>&1
rc1=$?
if [ "$rc1" -eq 0 ]; then
  pass "first install exits 0"
else
  fail "first install exited rc=${rc1}"
fi

RESULT="$TMPHOME/.claude/settings.json"
sha1="$(shasum -a 256 "$RESULT" | awk '{print $1}')"

# Second install (exercises merge-existing + idempotency guard).
# Run without --force so the idempotency guard is engaged -- a same-command
# orchestrator-managed entry must NOT be appended a second time.
CLAUDECODE=1 HOME="$TMPHOME" bash "$INSTALLER" --project-dir "$TMPPRJ" >/dev/null 2>&1
rc2=$?
if [ "$rc2" -eq 0 ]; then
  pass "second install (no --force) exits 0"
else
  fail "second install exited rc=${rc2}"
fi
sha2="$(shasum -a 256 "$RESULT" | awk '{print $1}')"

if [ "$sha1" = "$sha2" ]; then
  pass "sha256 byte-identical across runs (${sha1})"
else
  fail "sha256 mismatch: run1=${sha1} run2=${sha2}"
fi

echo "SUMMARY: m025-p01-idempotency.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m025-p01-idempotency.sh"
  exit 0
fi
echo "FAIL: m025-p01-idempotency.sh" >&2
exit 1
