#!/usr/bin/env bash
# scripts/verify/m026-p02-dual-edition-test-shape.sh
#
# M026/P02/T03 gate: verify tests/test-conversus-adapter-shim.sh has a
# CONVERSUS_INTEGRATION=1-gated dual-edition block (section 3) that:
#
#   1. Contains the section-3 marker line behind a CONVERSUS_INTEGRATION=1
#      guard.
#   2. OSS branch carries the literal `known-upstream-429` skip annotation.
#   3. Paid branch carries the literal `paid build not installed` skip
#      annotation.
#   4. Uses the SC-6 sorted-key `diff` pattern for frontmatter key-set
#      comparison (DC-4: shape not value).
#   5. Running the shim test without CONVERSUS_INTEGRATION=1 exits 0
#      (sections 1, 1b, 2 unaffected — AD-6).
#   6. Running the shim test with CONVERSUS_INTEGRATION=1 under the
#      current operator environment exits 0 and prints both SKIP
#      annotations (visible-skip, not silent-skip).
#
# Bash 3.2 compatible. Single-script-file shape (AD-19).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SHIM="${REPO_ROOT}/tests/test-conversus-adapter-shim.sh"

passed=0
failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1" >&2; failed=$((failed + 1)); }

if [ ! -f "$SHIM" ]; then
  fail "shim test missing: $SHIM"
  echo "FAIL: m026-p02-dual-edition-test-shape.sh" >&2
  exit 1
fi

SCRATCH="$(mktemp -d -t m026-p02-dual-edition.XXXXXX)"
trap 'rm -rf "$SCRATCH"' EXIT

# -----------------------------------------------------------------------
# 1. Section-3 marker line is present and follows a
#    CONVERSUS_INTEGRATION=1 guard. We do NOT require immediate adjacency
#    (the guard may emit a SKIP branch first), only that the guard line
#    precedes the marker somewhere earlier in the file.
# -----------------------------------------------------------------------
MARKER_LINE="$(grep -nF -e '---- Section 3: dual-edition integration ----' "$SHIM" | head -n 1 | cut -d: -f1)"
GUARD_LINE="$(grep -nE '"\$\{CONVERSUS_INTEGRATION:-0\}"[[:space:]]*!?=[[:space:]]*"1"' "$SHIM" | head -n 1 | cut -d: -f1)"

if [ -n "$MARKER_LINE" ]; then
  pass "section-3 marker present"
else
  fail "section-3 marker missing"
fi

if [ -n "$GUARD_LINE" ]; then
  pass "CONVERSUS_INTEGRATION=1 guard line present"
else
  fail "CONVERSUS_INTEGRATION=1 guard line missing"
fi

if [ -n "$MARKER_LINE" ] && [ -n "$GUARD_LINE" ]; then
  if [ "$GUARD_LINE" -lt "$MARKER_LINE" ]; then
    pass "marker follows CONVERSUS_INTEGRATION=1 guard"
  else
    fail "marker at line $MARKER_LINE precedes guard at line $GUARD_LINE"
  fi
fi

# -----------------------------------------------------------------------
# 2. OSS branch carries the literal `known-upstream-429` annotation.
# -----------------------------------------------------------------------
if grep -qF 'known-upstream-429' "$SHIM"; then
  pass "OSS branch: known-upstream-429 annotation present"
else
  fail "OSS branch: known-upstream-429 annotation missing"
fi

# -----------------------------------------------------------------------
# 3. Paid branch carries the literal `paid build not installed` annotation.
# -----------------------------------------------------------------------
if grep -qF 'paid build not installed' "$SHIM"; then
  pass "paid branch: 'paid build not installed' annotation present"
else
  fail "paid branch: 'paid build not installed' annotation missing"
fi

# -----------------------------------------------------------------------
# 4. SC-6 sorted-key diff pattern present (shape-not-value contract).
# -----------------------------------------------------------------------
if grep -qE 'diff -q "[^"]*oss-keys\.txt" "[^"]*paid-keys\.txt"' "$SHIM"; then
  pass "SC-6: sorted-key diff pattern present (oss-keys.txt vs paid-keys.txt)"
else
  fail "SC-6: sorted-key diff pattern missing"
fi

# -----------------------------------------------------------------------
# 5. Running shim test WITHOUT CONVERSUS_INTEGRATION=1 exits 0.
#    Sections 1, 1b, 2 must still pass (AD-6: stub-paths untouched).
# -----------------------------------------------------------------------
STUB_LOG="${SCRATCH}/stub.log"
bash "$SHIM" > "$STUB_LOG" 2>&1
stub_rc=$?
if [ $stub_rc -eq 0 ]; then
  pass "shim test exits 0 without CONVERSUS_INTEGRATION=1"
else
  fail "shim test without CONVERSUS_INTEGRATION=1 exited $stub_rc (expected 0)"
  sed -n '1,40p' "$STUB_LOG" >&2
fi

# -----------------------------------------------------------------------
# 6. Running shim test WITH CONVERSUS_INTEGRATION=1 exits 0 under the
#    current operator environment, and both SKIP annotations print to
#    stdout (visible-skip, not silent-skip).
# -----------------------------------------------------------------------
INT_LOG="${SCRATCH}/integration.log"
bash "${REPO_ROOT}/scripts/util/with-env.sh" CONVERSUS_INTEGRATION=1 -- bash "$SHIM" > "$INT_LOG" 2>&1
int_rc=$?
if [ $int_rc -eq 0 ]; then
  pass "shim test exits 0 with CONVERSUS_INTEGRATION=1"
else
  fail "shim test with CONVERSUS_INTEGRATION=1 exited $int_rc (expected 0)"
  sed -n '1,40p' "$INT_LOG" >&2
fi

if grep -qF 'known-upstream-429' "$INT_LOG"; then
  pass "visible-skip: known-upstream-429 printed under CONVERSUS_INTEGRATION=1"
else
  fail "visible-skip: known-upstream-429 not printed"
fi

if grep -qF 'paid build not installed' "$INT_LOG"; then
  pass "visible-skip: 'paid build not installed' printed under CONVERSUS_INTEGRATION=1"
else
  fail "visible-skip: 'paid build not installed' not printed"
fi

echo "SUMMARY: m026-p02-dual-edition-test-shape.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m026-p02-dual-edition-test-shape.sh"
  exit 0
fi
echo "FAIL: m026-p02-dual-edition-test-shape.sh" >&2
exit 1
