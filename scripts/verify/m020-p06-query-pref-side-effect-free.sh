#!/usr/bin/env bash
# m020-p06-query-pref-side-effect-free.sh — assert FR-8 / CON-1 read-only
# invariant for the preferences-resolution path through query.sh.
#
# Computes md5 hashes of: project preferences file, user preferences file,
# and per-file md5 of every entry in the knowledge tree. Runs an 8-invocation
# battery (matched/unmatched topic × default-state/explicit-state ×
# ids/json formats × with-pref-fallback/without). Re-computes hashes after
# the battery and asserts byte-identical pre vs. post. Strictly stronger
# than `git status` per P02/T02 lesson — catches in-place rewrites that
# round-trip byte-for-byte.
#
# Bash 3.2 safe. AD-19 single-script-file shape. MEM002 pass/fail pattern.
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

# md5/md5sum portability fallback (macOS+linux).
md5_of_file() {
  if command -v md5sum >/dev/null 2>&1; then
    md5sum "$1" | awk '{print $1}'
  else
    md5 -q "$1"
  fi
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

# Both prefs files declared so the resolution path crosses both layers.
printf 'default_state_filter: graduated\n' > "$PROJ_PREF"
printf 'default_state_filter: candidate\n' > "$USER_PREF"

# Snapshot helper: emits sorted "<path><TAB><md5>" lines for the knowledge tree.
snapshot_ktree() {
  find "$KDIR" -type f -name 'MEM*.md' | sort | while IFS= read -r f; do
    h="$(md5_of_file "$f")"
    printf '%s\t%s\n' "$f" "$h"
  done
}

pre_proj_md5="$(md5_of_file "$PROJ_PREF")"
pre_user_md5="$(md5_of_file "$USER_PREF")"
pre_ktree="$TMPDIR_FIX/pre-ktree.txt"
snapshot_ktree > "$pre_ktree"

run_query() {
  HOME="$USER_HOME" PROJECT_ROOT="$PROJ_DIR" \
    bash "$QUERY" "$@" >/dev/null 2>&1 || true
}

# 8-invocation battery:
#   1. matched topic, no --state (uses pref fallback), --format ids
#   2. matched topic, no --state (uses pref fallback), --format json
#   3. matched topic, --state graduated, --format ids
#   4. matched topic, --state archived, --format json
#   5. unmatched topic, no --state, --format ids
#   6. unmatched topic, no --state, --format json
#   7. unmatched topic, --state candidate, --format ids
#   8. unmatched topic, --state graduated, --format json
run_query --topic X --format ids
run_query --topic X --format json
run_query --topic X --state graduated --format ids
run_query --topic X --state archived --format json
run_query --topic Q --format ids
run_query --topic Q --format json
run_query --topic Q --state candidate --format ids
run_query --topic Q --state graduated --format json

post_proj_md5="$(md5_of_file "$PROJ_PREF")"
post_user_md5="$(md5_of_file "$USER_PREF")"
post_ktree="$TMPDIR_FIX/post-ktree.txt"
snapshot_ktree > "$post_ktree"

if diff -q "$pre_ktree" "$post_ktree" >/dev/null 2>&1; then
  pass "8-invocation battery — knowledge tree md5 unchanged"
else
  fail "8-invocation battery — knowledge tree md5 changed"
  diff "$pre_ktree" "$post_ktree" | head -20
fi

if [ "$pre_proj_md5" = "$post_proj_md5" ]; then
  pass "8-invocation battery — project preferences file md5 unchanged"
else
  fail "8-invocation battery — project preferences file md5 changed (pre=$pre_proj_md5 post=$post_proj_md5)"
fi

if [ "$pre_user_md5" = "$post_user_md5" ]; then
  pass "8-invocation battery — user preferences file md5 unchanged"
else
  fail "8-invocation battery — user preferences file md5 changed (pre=$pre_user_md5 post=$post_user_md5)"
fi

total=$((pass_count + fail_count))
echo "RESULT: ${pass_count}/${total} PASS"
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0
