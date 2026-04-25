#!/usr/bin/env bash
# m020-p06-query-state-from-pref.sh — assert query.sh resolves state filter
# end-to-end through preferences with CLI > project > user > built-in-default
# precedence (FR-6 / US-5; THREAT-007 disposition).
#
# Five cases (A-E) verify the precedence cascade against a live query.sh
# invocation. Bash 3.2 safe. AD-19 single-script-file shape. MEM002 pass/fail.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
QUERY="$ROOT/scripts/knowledge/query.sh"

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

if [ ! -f "$QUERY" ]; then
  echo "FAIL: query.sh does not exist at $QUERY"
  exit 1
fi

TMPDIR_FIX="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_FIX"' EXIT

USER_HOME="$TMPDIR_FIX/home"
PROJ_DIR="$TMPDIR_FIX/proj"
mkdir -p "$USER_HOME/.orchestrator" "$PROJ_DIR/.orchestrator/knowledge/conventions"
USER_PREF="$USER_HOME/.orchestrator/preferences.yml"
PROJ_PREF="$PROJ_DIR/.orchestrator/preferences.yml"

# Knowledge tree: three entries on topic X, one per status.
KDIR="$PROJ_DIR/knowledge/conventions"
mkdir -p "$KDIR"

write_entry() {
  local id="$1"
  local status="$2"
  local file="$KDIR/${id}.md"
  cat >"$file" <<EOF
---
id: ${id}
scope_tags: "[project]"
category: conventions
confidence: 0.9
created_at: 2026-04-25
last_verified: 2026-04-25
hit_count: 1
source_unit: "M020/P06"
source_type: test
supersedes: ""
superseded_by: ""
relates_to: []
content_hash: ""
status: ${status}
topic: X
tags: [X]
---

# ${id}: Test entry for ${status}

Body for ${status}.
EOF
}

write_entry "MEM900" "graduated"
write_entry "MEM901" "candidate"
write_entry "MEM902" "archived"

run_query() {
  HOME="$USER_HOME" PROJECT_ROOT="$PROJ_DIR" \
    bash "$QUERY" "$@"
}

# Case A: no preferences file anywhere → built-in default `graduated`.
rm -f "$USER_PREF" "$PROJ_PREF"
out_a="$(run_query --topic X 2>/dev/null)"
exit_a=$?
if [ "$exit_a" -eq 0 ] && printf '%s\n' "$out_a" | grep -qx 'entry_id=MEM900'; then
  if printf '%s\n' "$out_a" | grep -qx 'entry_id=MEM901'; then
    fail "case A no-pref no-CLI -> graduated only (MEM901 candidate leaked)"
  elif printf '%s\n' "$out_a" | grep -qx 'entry_id=MEM902'; then
    fail "case A no-pref no-CLI -> graduated only (MEM902 archived leaked)"
  else
    pass "case A no-pref no-CLI -> graduated only"
  fi
else
  fail "case A no-pref no-CLI -> graduated only (got: $out_a)"
fi

# Case B: only user file declares default_state_filter=candidate.
rm -f "$PROJ_PREF"
printf 'default_state_filter: candidate\n' > "$USER_PREF"
out_b="$(run_query --topic X 2>/dev/null)"
exit_b=$?
if [ "$exit_b" -eq 0 ] && printf '%s\n' "$out_b" | grep -qx 'entry_id=MEM901'; then
  if printf '%s\n' "$out_b" | grep -qx 'entry_id=MEM900'; then
    fail "case B user-only -> candidate only (MEM900 graduated leaked)"
  elif printf '%s\n' "$out_b" | grep -qx 'entry_id=MEM902'; then
    fail "case B user-only -> candidate only (MEM902 archived leaked)"
  else
    pass "case B user-only -> candidate only"
  fi
else
  fail "case B user-only -> candidate only (got: $out_b)"
fi

# Case C: project=archived, user=candidate → project wins.
printf 'default_state_filter: archived\n' > "$PROJ_PREF"
out_c="$(run_query --topic X 2>/dev/null)"
exit_c=$?
if [ "$exit_c" -eq 0 ] && printf '%s\n' "$out_c" | grep -qx 'entry_id=MEM902'; then
  if printf '%s\n' "$out_c" | grep -qx 'entry_id=MEM900'; then
    fail "case C project-overrides-user -> archived only (MEM900 graduated leaked)"
  elif printf '%s\n' "$out_c" | grep -qx 'entry_id=MEM901'; then
    fail "case C project-overrides-user -> archived only (MEM901 candidate leaked)"
  else
    pass "case C project-overrides-user -> archived only"
  fi
else
  fail "case C project-overrides-user -> archived only (got: $out_c)"
fi

# Case D: project=archived, user=candidate, CLI=graduated → CLI wins.
out_d="$(run_query --topic X --state graduated 2>/dev/null)"
exit_d=$?
if [ "$exit_d" -eq 0 ] && printf '%s\n' "$out_d" | grep -qx 'entry_id=MEM900'; then
  if printf '%s\n' "$out_d" | grep -qx 'entry_id=MEM901'; then
    fail "case D CLI-overrides-both -> graduated only (MEM901 candidate leaked)"
  elif printf '%s\n' "$out_d" | grep -qx 'entry_id=MEM902'; then
    fail "case D CLI-overrides-both -> graduated only (MEM902 archived leaked)"
  else
    pass "case D CLI-overrides-both -> graduated only"
  fi
else
  fail "case D CLI-overrides-both -> graduated only (got: $out_d)"
fi

# Case E: project=zombie (malformed, outside closed enum), user=candidate.
# Expect: stdout contains MEM901 (project malformed → fall through to user);
# stderr contains a WARN: pref_resolve line for default_state_filter.
printf 'default_state_filter: zombie\n' > "$PROJ_PREF"
printf 'default_state_filter: candidate\n' > "$USER_PREF"
err_file="$TMPDIR_FIX/case-e-stderr"
out_e="$(run_query --topic X 2>"$err_file")"
exit_e=$?
if [ "$exit_e" -eq 0 ] && printf '%s\n' "$out_e" | grep -qx 'entry_id=MEM901'; then
  pass "case E project-malformed -> falls through to user candidate"
else
  fail "case E project-malformed -> falls through to user candidate (got: $out_e)"
fi

if grep -q 'WARN: pref_resolve' "$err_file" && grep -q 'default_state_filter' "$err_file"; then
  pass "case E stderr emits WARN for malformed default_state_filter"
else
  err_dump="$(cat "$err_file")"
  fail "case E stderr emits WARN for malformed default_state_filter (stderr: $err_dump)"
fi

total=$((pass_count + fail_count))
echo "RESULT: ${pass_count}/${total} PASS"
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0
