#!/usr/bin/env bash
# m020-p06-preferences-helper-contract.sh — assert lib/preferences.sh exposes
# pref_resolve with the documented closed-enum keys + built-in defaults.
# Bash 3.2 safe (MEM001). MEM002 pass()/fail() parallel-scalar pattern.
# AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/scripts/knowledge/lib/preferences.sh"

pass_count=0
fail_count=0
fail_msgs_0=""
fail_msgs_1=""
fail_msgs_2=""
fail_msgs_3=""
fail_msgs_4=""
fail_msgs_5=""
fail_msgs_6=""

pass() {
  pass_count=$((pass_count + 1))
  echo "PASS: $1"
}
fail() {
  case "$fail_count" in
    0) fail_msgs_0="$1" ;;
    1) fail_msgs_1="$1" ;;
    2) fail_msgs_2="$1" ;;
    3) fail_msgs_3="$1" ;;
    4) fail_msgs_4="$1" ;;
    5) fail_msgs_5="$1" ;;
    6) fail_msgs_6="$1" ;;
  esac
  fail_count=$((fail_count + 1))
  echo "FAIL: $1"
}

# Tempdir fixture (no live ~/.orchestrator/ or repo-root .orchestrator/ access).
TMPDIR_FIX="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_FIX"' EXIT
mkdir -p "$TMPDIR_FIX/home" "$TMPDIR_FIX/proj"

# Truth 1: file exists and is sourceable.
if [ ! -f "$LIB" ]; then
  fail "lib/preferences.sh does not exist at $LIB"
else
  out_src="$(bash -c ". '$LIB' && type -t pref_resolve" 2>&1)"
  rc_src=$?
  if [ "$rc_src" -ne 0 ]; then
    fail "sourcing preferences.sh exited $rc_src. Output: $out_src"
  else
    pass "lib/preferences.sh exists and is sourceable"
  fi
fi

# Truth 2: pref_resolve is defined as a function after source.
out_t="$(bash -c ". '$LIB' && type -t pref_resolve" 2>/dev/null)"
if [ "$out_t" = "function" ]; then
  pass "pref_resolve is a defined function after source"
else
  fail "pref_resolve is not a function after source (got: '$out_t')"
fi

# Truth 3-7: each of the five keys returns the documented built-in default
# when no preferences files are present.
check_default() {
  local key="$1"
  local expected="$2"
  local actual
  actual="$(HOME="$TMPDIR_FIX/home" PROJECT_ROOT="$TMPDIR_FIX/proj" \
    bash -c ". '$LIB' && pref_resolve $key" 2>/dev/null)"
  if [ "$actual" = "$expected" ]; then
    pass "pref_resolve $key -> $expected (built-in default)"
  else
    fail "pref_resolve $key expected '$expected', got '$actual'"
  fi
}

check_default default_state_filter "graduated"
check_default similarity_threshold "0.7"
check_default staleness_threshold "14"
check_default preferred_cluster_size "8"
check_default operator_identifier "unknown@local"

total=$((pass_count + fail_count))
echo "RESULT: ${pass_count}/${total} PASS"
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0
