#!/usr/bin/env bash
# m020-p06-preferences-key-vocabulary.sh — assert pref_resolve rejects
# unknown keys with a FAIL: stderr line + non-zero exit + empty stdout,
# and accepts the five known keys (sanity regression).
# Bash 3.2 safe. AD-19 single-script-file shape. MEM002 pass/fail pattern.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/scripts/knowledge/lib/preferences.sh"

pass_count=0
fail_count=0

pass() {
  pass_count=$((pass_count + 1))
  echo "PASS: $1"
}
fail() {
  fail_count=$((fail_count + 1))
  echo "FAIL: $1"
}

if [ ! -f "$LIB" ]; then
  echo "FAIL: lib/preferences.sh does not exist at $LIB"
  exit 1
fi

TMPDIR_FIX="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_FIX"' EXIT
USER_HOME="$TMPDIR_FIX/home"
PROJ_DIR="$TMPDIR_FIX/proj"
mkdir -p "$USER_HOME/.orchestrator" "$PROJ_DIR/.orchestrator"
STDERR_FILE="$TMPDIR_FIX/stderr.txt"
STDOUT_FILE="$TMPDIR_FIX/stdout.txt"

# Call pref_resolve with literal args; protect any shell-special chars by
# using bash -c with positional args.
call_with_args() {
  HOME="$USER_HOME" PROJECT_ROOT="$PROJ_DIR" \
    bash -c ". '$LIB' && pref_resolve \"\$@\"" -- "$@" \
    >"$STDOUT_FILE" 2>"$STDERR_FILE"
  echo "$?"
}

# === Unknown key: some_unknown_key ===
rc="$(call_with_args some_unknown_key)"
if [ "$rc" != "0" ]; then
  pass "unknown key: non-zero exit ($rc)"
else
  fail "unknown key: expected non-zero exit, got 0"
fi
stdout_actual="$(cat "$STDOUT_FILE")"
if [ -z "$stdout_actual" ]; then
  pass "unknown key: stdout empty"
else
  fail "unknown key: stdout not empty: '$stdout_actual'"
fi
if grep -E "^FAIL: pref_resolve: unknown key 'some_unknown_key'" "$STDERR_FILE" >/dev/null 2>&1; then
  pass "unknown key: stderr matches FAIL pattern"
else
  fail "unknown key: stderr did not match. Got: $(cat "$STDERR_FILE")"
fi

# === No-argument call ===
rc="$(call_with_args)"
if [ "$rc" != "0" ]; then
  pass "no-args: non-zero exit ($rc)"
else
  fail "no-args: expected non-zero exit, got 0"
fi
stdout_actual="$(cat "$STDOUT_FILE")"
if [ -z "$stdout_actual" ]; then
  pass "no-args: stdout empty"
else
  fail "no-args: stdout not empty: '$stdout_actual'"
fi
if grep -E "missing key argument" "$STDERR_FILE" >/dev/null 2>&1; then
  pass "no-args: stderr matches missing-key pattern"
else
  fail "no-args: stderr did not match. Got: $(cat "$STDERR_FILE")"
fi

# === Sanity: each of the five known keys exits 0 ===
check_known() {
  local key="$1"
  rc="$(call_with_args "$key")"
  if [ "$rc" = "0" ]; then
    pass "known key '$key' exits 0"
  else
    fail "known key '$key' expected exit 0, got $rc. Stderr: $(cat "$STDERR_FILE")"
  fi
}

check_known default_state_filter
check_known similarity_threshold
check_known staleness_threshold
check_known preferred_cluster_size
check_known operator_identifier

# === Edge cases that exercise the closed-enum guard ===
# Keys with leading/trailing whitespace or punctuation should be rejected.
rc="$(call_with_args "default_state_filter ")"
if [ "$rc" != "0" ]; then
  pass "trailing-space key rejected (non-zero exit)"
else
  fail "trailing-space key was accepted; expected rejection"
fi

rc="$(call_with_args "DEFAULT_STATE_FILTER")"
if [ "$rc" != "0" ]; then
  pass "uppercase key rejected (closed-enum is case-sensitive)"
else
  fail "uppercase key was accepted; expected rejection"
fi

total=$((pass_count + fail_count))
echo "RESULT: ${pass_count}/${total} PASS"
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0
