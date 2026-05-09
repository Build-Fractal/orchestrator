#!/usr/bin/env bash
# tools/verify/m035-p04-byte-equivalence-curl-arm.sh
#
# M035 P04 T03 task-grain verifier. Asserts cross-channel-byte-
# equivalence.sh has the curl-pipe-bash arm + 3-way equality
# assertion shape; runs the test functionally and asserts the
# 3-way assertion fires (or SKIPs cleanly when npm is unavailable).
#
# AD-19 single-script-file shape. Bash 3.2 compatible.

set -u

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
TEST_FILE="$REPO_ROOT/tests/m035-acceptance/cross-channel-byte-equivalence.sh"

pass=0
fail=0

check() {
  local name="$1"
  local result="$2"
  if [ "$result" = "0" ]; then
    echo "PASS: $name"
    pass=$((pass + 1))
  else
    echo "FAIL: $name"
    fail=$((fail + 1))
  fi
}

# --- Static shape assertions ---

# 1. Test file exists.
if [ -f "$TEST_FILE" ]; then check "test file exists" 0; else check "test file exists" 1; fi

# 2. SKIP: pending P04 stub is gone.
if grep -F 'SKIP: pending P04' "$TEST_FILE" >/dev/null; then check "SKIP pending P04 stub removed" 1; else check "SKIP pending P04 stub removed" 0; fi

# 3. CURL_HASH= assignment present (variable used).
if grep -F 'CURL_HASH=' "$TEST_FILE" >/dev/null; then check "CURL_HASH= variable used" 0; else check "CURL_HASH= variable used" 1; fi

# 4. install.sh invoked from the test.
if grep -F 'packaging/install/install.sh' "$TEST_FILE" >/dev/null; then check "install.sh invoked from test" 0; else check "install.sh invoked from test" 1; fi

# 5. M035_P04_LOCAL_TARBALL test-mode env-var used.
if grep -F 'M035_P04_LOCAL_TARBALL' "$TEST_FILE" >/dev/null; then check "M035_P04_LOCAL_TARBALL test-mode" 0; else check "M035_P04_LOCAL_TARBALL test-mode" 1; fi

# 6. M035_P04_STAGE_ONLY test-mode env-var used.
if grep -F 'M035_P04_STAGE_ONLY' "$TEST_FILE" >/dev/null; then check "M035_P04_STAGE_ONLY test-mode" 0; else check "M035_P04_STAGE_ONLY test-mode" 1; fi

# 7. 3-way equality assertion present.
if grep -F 'NPM_HASH = HOMEBREW_HASH = CURL_HASH' "$TEST_FILE" >/dev/null; then check "3-way equality PASS message" 0; else check "3-way equality PASS message" 1; fi

# 8. CHANNEL=curl-pipe-bash used to extract exclusion list.
if grep -F 'CHANNEL=curl-pipe-bash' "$TEST_FILE" >/dev/null; then check "CHANNEL=curl-pipe-bash exclusion-list extraction" 0; else check "CHANNEL=curl-pipe-bash exclusion-list extraction" 1; fi

# --- Functional smoke (test-IS-the-smoke pattern from P02 T03) ---

# 9. Run the test end-to-end and assert it exits 0 (or a clean SKIP
#    when npm is absent on PATH). We capture stdout + exit code; if
#    npm is on PATH and install.sh is on disk, the 3-way assertion
#    must fire.
TEST_LOG="$(mktemp 2>/dev/null || mktemp -t m035p04t03verifier)"
if bash "$TEST_FILE" >"$TEST_LOG" 2>&1; then
  if grep -F 'cross-channel byte-equivalence (3-way) — NPM_HASH = HOMEBREW_HASH = CURL_HASH' "$TEST_LOG" >/dev/null; then
    check "3-way equality assertion fired and PASSed" 0
  elif grep -F 'cross-channel byte-equivalence (2-way)' "$TEST_LOG" >/dev/null; then
    # 2-way fallback path — acceptable if curl arm SKIPped (e.g.,
    # install.sh missing on disk in some pre-T01 fixture). Should
    # NOT happen under normal P04 dispatch ordering.
    check "3-way equality assertion fired" 1
  else
    check "test exited 0 but neither 3-way nor 2-way assertion fired" 1
  fi
else
  # Test exited non-zero. Acceptable only if npm is genuinely absent.
  if ! command -v npm >/dev/null 2>&1; then
    check "test exited non-zero with npm absent on PATH (acceptable SKIP)" 0
  else
    echo "FAIL: test exited non-zero — see test log:"
    cat "$TEST_LOG" >&2 || true
    check "test functional smoke" 1
  fi
fi
rm -f "$TEST_LOG"

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
