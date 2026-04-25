#!/usr/bin/env bash
# m020-p06-preferences-precedence.sh — assert pref_resolve honors
# project>user>built-in-default precedence per-key (THREAT-007 disposition).
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
USER_PREF="$USER_HOME/.orchestrator/preferences.yml"
PROJ_PREF="$PROJ_DIR/.orchestrator/preferences.yml"

resolve() {
  local key="$1"
  HOME="$USER_HOME" PROJECT_ROOT="$PROJ_DIR" \
    bash -c ". '$LIB' && pref_resolve $key" 2>/dev/null
}

assert_eq() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [ "$actual" = "$expected" ]; then
    pass "$label (got '$actual')"
  else
    fail "$label expected '$expected', got '$actual'"
  fi
}

# === similarity_threshold cascade ===
printf 'similarity_threshold: 0.8\n' > "$USER_PREF"
printf 'similarity_threshold: 0.6\n' > "$PROJ_PREF"
assert_eq "project wins for similarity_threshold (project=0.6, user=0.8)" "0.6" "$(resolve similarity_threshold)"

rm -f "$PROJ_PREF"
assert_eq "user wins when project absent (user=0.8)" "0.8" "$(resolve similarity_threshold)"

rm -f "$USER_PREF"
assert_eq "default when neither present (similarity_threshold)" "0.7" "$(resolve similarity_threshold)"

# === default_state_filter cascade ===
printf 'default_state_filter: graduated\n' > "$USER_PREF"
printf 'default_state_filter: candidate\n' > "$PROJ_PREF"
assert_eq "project wins for default_state_filter (project=candidate, user=graduated)" "candidate" "$(resolve default_state_filter)"

rm -f "$PROJ_PREF"
assert_eq "user wins for default_state_filter (user=graduated)" "graduated" "$(resolve default_state_filter)"

rm -f "$USER_PREF"
assert_eq "default for default_state_filter when neither present" "graduated" "$(resolve default_state_filter)"

# === staleness_threshold cascade ===
printf 'staleness_threshold: 21\n' > "$USER_PREF"
printf 'staleness_threshold: 7\n' > "$PROJ_PREF"
assert_eq "project wins for staleness_threshold (project=7, user=21)" "7" "$(resolve staleness_threshold)"

rm -f "$PROJ_PREF"
assert_eq "user wins for staleness_threshold (user=21)" "21" "$(resolve staleness_threshold)"

rm -f "$USER_PREF"
assert_eq "default for staleness_threshold when neither present" "14" "$(resolve staleness_threshold)"

# === Per-key partial-overlap (THREAT-007): project declares only similarity,
# user declares only staleness. Each key resolves INDEPENDENTLY. ===
printf 'similarity_threshold: 0.5\n' > "$PROJ_PREF"
printf 'staleness_threshold: 30\n' > "$USER_PREF"
assert_eq "partial-overlap: similarity_threshold from project (0.5)" "0.5" "$(resolve similarity_threshold)"
assert_eq "partial-overlap: staleness_threshold from user (30)" "30" "$(resolve staleness_threshold)"
assert_eq "partial-overlap: default_state_filter still default (graduated)" "graduated" "$(resolve default_state_filter)"
assert_eq "partial-overlap: preferred_cluster_size still default (8)" "8" "$(resolve preferred_cluster_size)"
assert_eq "partial-overlap: operator_identifier still default (unknown@local)" "unknown@local" "$(resolve operator_identifier)"

total=$((pass_count + fail_count))
echo "RESULT: ${pass_count}/${total} PASS"
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0
