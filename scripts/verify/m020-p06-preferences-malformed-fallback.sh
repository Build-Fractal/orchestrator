#!/usr/bin/env bash
# m020-p06-preferences-malformed-fallback.sh — assert pref_resolve falls back
# on malformed values, emits stderr WARN diagnostic, and NEVER mutates
# the preferences file (CON-1 / FR-8). md5 snapshot before/after each call.
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

# Portable md5 hashing (macOS md5, linux md5sum).
hash_file() {
  if command -v md5 >/dev/null 2>&1; then
    md5 -q "$1" 2>/dev/null
  else
    md5sum "$1" 2>/dev/null | awk '{print $1}'
  fi
}

TMPDIR_FIX="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_FIX"' EXIT
USER_HOME="$TMPDIR_FIX/home"
PROJ_DIR="$TMPDIR_FIX/proj"
mkdir -p "$USER_HOME/.orchestrator" "$PROJ_DIR/.orchestrator"
USER_PREF="$USER_HOME/.orchestrator/preferences.yml"
PROJ_PREF="$PROJ_DIR/.orchestrator/preferences.yml"
STDERR_FILE="$TMPDIR_FIX/stderr.txt"
STDOUT_FILE="$TMPDIR_FIX/stdout.txt"

call_resolve() {
  local key="$1"
  HOME="$USER_HOME" PROJECT_ROOT="$PROJ_DIR" \
    bash -c ". '$LIB' && pref_resolve $key" \
    >"$STDOUT_FILE" 2>"$STDERR_FILE"
}

stdout_eq() {
  local label="$1"
  local expected="$2"
  local actual
  actual="$(cat "$STDOUT_FILE")"
  if [ "$actual" = "$expected" ]; then
    pass "$label: stdout='$expected'"
  else
    fail "$label: stdout expected '$expected', got '$actual'"
  fi
}

stderr_matches() {
  local label="$1"
  local pattern="$2"
  if grep -E "$pattern" "$STDERR_FILE" >/dev/null 2>&1; then
    pass "$label: stderr matches /$pattern/"
  else
    fail "$label: stderr did not match /$pattern/. Got: $(cat "$STDERR_FILE")"
  fi
}

snapshot_unchanged() {
  local label="$1"
  local file="$2"
  local pre="$3"
  local post
  post="$(hash_file "$file")"
  if [ "$pre" = "$post" ]; then
    pass "$label: file unchanged (md5=$pre)"
  else
    fail "$label: file mutated! pre=$pre post=$post"
  fi
}

# === Case 1: similarity_threshold = not-a-number (project) ===
printf 'similarity_threshold: not-a-number\n' > "$PROJ_PREF"
pre_md5="$(hash_file "$PROJ_PREF")"
call_resolve similarity_threshold
rc=$?
if [ "$rc" -eq 0 ]; then
  pass "case1: exit 0 on malformed similarity_threshold"
else
  fail "case1: exit $rc on malformed similarity_threshold"
fi
stdout_eq "case1: similarity_threshold malformed -> default" "0.7"
stderr_matches "case1: WARN diagnostic" "^WARN: pref_resolve: malformed value for 'similarity_threshold'"
snapshot_unchanged "case1: project file" "$PROJ_PREF" "$pre_md5"

# === Case 2: similarity_threshold out-of-range (1.5) ===
printf 'similarity_threshold: 1.5\n' > "$PROJ_PREF"
pre_md5="$(hash_file "$PROJ_PREF")"
call_resolve similarity_threshold
stdout_eq "case2: similarity_threshold=1.5 -> default" "0.7"
stderr_matches "case2: WARN diagnostic" "^WARN: pref_resolve: malformed value for 'similarity_threshold'"
snapshot_unchanged "case2: project file" "$PROJ_PREF" "$pre_md5"

# === Case 3: default_state_filter outside closed enum ===
printf 'default_state_filter: zombie\n' > "$PROJ_PREF"
pre_md5="$(hash_file "$PROJ_PREF")"
call_resolve default_state_filter
stdout_eq "case3: default_state_filter=zombie -> default" "graduated"
stderr_matches "case3: WARN diagnostic" "malformed value for 'default_state_filter'"
snapshot_unchanged "case3: project file" "$PROJ_PREF" "$pre_md5"

# === Case 4: staleness_threshold = -1 ===
printf 'staleness_threshold: -1\n' > "$PROJ_PREF"
pre_md5="$(hash_file "$PROJ_PREF")"
call_resolve staleness_threshold
stdout_eq "case4: staleness_threshold=-1 -> default" "14"
stderr_matches "case4: WARN diagnostic" "malformed value for 'staleness_threshold'"
snapshot_unchanged "case4: project file" "$PROJ_PREF" "$pre_md5"

# === Case 5: project malformed + user valid -> falls through to user ===
printf 'similarity_threshold: not-a-number\n' > "$PROJ_PREF"
printf 'similarity_threshold: 0.9\n' > "$USER_PREF"
pre_proj_md5="$(hash_file "$PROJ_PREF")"
pre_user_md5="$(hash_file "$USER_PREF")"
call_resolve similarity_threshold
stdout_eq "case5: project malformed + user valid -> 0.9" "0.9"
stderr_matches "case5: WARN diagnostic for project only" "^WARN: pref_resolve: malformed value for 'similarity_threshold'"
# Confirm user file did NOT trigger a warn (only one WARN line expected).
warn_count="$(grep -cE "^WARN: pref_resolve: malformed value" "$STDERR_FILE" 2>/dev/null || echo 0)"
warn_count="$(printf '%s' "$warn_count" | tr -dc '0-9')"
if [ "${warn_count:-0}" = "1" ]; then
  pass "case5: exactly one WARN line (project only)"
else
  fail "case5: expected exactly one WARN line, got $warn_count. Stderr: $(cat "$STDERR_FILE")"
fi
snapshot_unchanged "case5: project file" "$PROJ_PREF" "$pre_proj_md5"
snapshot_unchanged "case5: user file" "$USER_PREF" "$pre_user_md5"

total=$((pass_count + fail_count))
echo "RESULT: ${pass_count}/${total} PASS"
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0
