#!/usr/bin/env bash
# tools/verify/m035-p02-byte-equivalence-skeleton.sh
# Asserts the cross-channel byte-equivalence test skeleton meets
# the M035 P02 T03 contract, reconciled M035 P06 T05.5 to match
# post-P03/P04 state:
#   * test file exists, executable
#   * helper hash script exists, executable
#   * test reads exclusion list from references/installation.md
#   * npm-channel arm emits NPM_HASH=<sha>
#   * homebrew arm is implemented and emits HOMEBREW_HASH= (P03/T03
#     replaced the original `SKIP: pending P03` stub)
#   * curl-pipe-bash arm is implemented and emits CURL_HASH= (P04/T03
#     replaced the original `SKIP: pending P04` stub)
#   * BATTERY: line shape present
#
# Bash 3.2 compatible.

set -u

REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
TEST="$REPO/tests/m035-acceptance/cross-channel-byte-equivalence.sh"
HELPER="$REPO/tests/m035-acceptance/_byte-equivalence-hash.sh"

pass=0
fail=0

# File existence + executability
for f in "$TEST" "$HELPER"; do
  if [ ! -f "$f" ]; then
    echo "FAIL: $f not found"
    fail=$((fail + 1))
  elif [ ! -x "$f" ]; then
    echo "FAIL: $f not executable"
    fail=$((fail + 1))
  else
    echo "PASS: $f exists and is executable"
    pass=$((pass + 1))
  fi
done

check_grep() {
  file="$1"
  pattern="$2"
  label="$3"
  if grep -qE "$pattern" "$file"; then
    echo "PASS: $label"
    pass=$((pass + 1))
  else
    echo "FAIL: $label (file=$file pattern=$pattern)"
    fail=$((fail + 1))
  fi
}

check_grep "$TEST" 'references/installation\.md' \
  "test reads exclusion list from references/installation.md (MIT-2)"
check_grep "$TEST" 'NPM_HASH=' "npm-channel arm emits NPM_HASH= line"
check_grep "$TEST" 'HOMEBREW_HASH=' "homebrew arm implemented (emits HOMEBREW_HASH=)"
check_grep "$TEST" 'CURL_HASH=' "curl-pipe-bash arm implemented (emits CURL_HASH=)"
check_grep "$TEST" 'BATTERY:' "BATTERY: line shape present"
check_grep "$TEST" 'DRY_RUN=1' "npm-channel arm runs postinstall under DRY_RUN=1 (D002)"

# Functional smoke: run the test (it should exit 0 if npm is on PATH)
if command -v npm >/dev/null 2>&1; then
  smoke_log="/tmp/m035-p02-bce.log"
  if bash "$TEST" >"$smoke_log" 2>&1; then
    echo "PASS: cross-channel-byte-equivalence.sh runs end-to-end (exit 0)"
    pass=$((pass + 1))
    if grep -q '^NPM_HASH=' "$smoke_log"; then
      echo "PASS: NPM_HASH= emitted on functional run"
      pass=$((pass + 1))
    else
      echo "FAIL: NPM_HASH= not emitted on functional run (see $smoke_log)"
      fail=$((fail + 1))
    fi
  else
    echo "FAIL: cross-channel-byte-equivalence.sh exited non-zero (see $smoke_log)"
    fail=$((fail + 1))
  fi
else
  echo "SKIP: npm not on PATH -- functional smoke deferred to CI"
fi

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
