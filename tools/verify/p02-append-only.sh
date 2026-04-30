#!/usr/bin/env bash
# tools/verify/p02-append-only.sh — M030 P02 CON-6 append-only gate.
#
# Stages a fixture log file with N pre-existing dispatch_usage records
# (cat the T01 fixture into a fresh log), captures inode + first-N-lines +
# line-count, runs an M030_SHADOW_MODE=1 + CLAUDECODE=1 dispatch through
# scripts/dispatch/dispatch-interface.sh, and asserts:
#   - inode pre == post (file identity preserved — no mv/cp swap)
#   - first-N-lines pre == post (existing records bit-identical)
#   - post-line-count == pre-line-count + 1 (exactly one new record)
#
# Cross-platform stat: macOS uses `stat -f '%i'`; GNU uses `stat -c '%i'`.
# Dispatched via `uname -s`.
#
# Bash 3.2 compatible. AD-19 single-script-file shape. Tmp-file intermediates.
#
# Exit 0 iff fail == 0. Emits SUMMARY: line at end.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE="$REPO_ROOT/tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl"
STAGE="$REPO_ROOT/tests/fixtures/m030-p02/round-trip-stage"
PLAN="$STAGE/phases/P01/tasks/M001-T01-stage-PLAN.md"
PAYLOAD="$STAGE/phases/P01/tasks/T01-stage-PAYLOAD.md"
INTENSITY_META="$STAGE/intensity-metadata.txt"
LOG_FILE="$STAGE/execution-log.jsonl"
DISPATCH="$REPO_ROOT/scripts/dispatch/dispatch-interface.sh"

pass=0
fail=0

# ---------- Gate 0: prerequisites exist ----------
ok=1
if [ ! -f "$FIXTURE" ]; then
  ok=0
  printf 'FAIL: fixture missing at %s\n' "$FIXTURE"
fi
if [ ! -f "$PLAN" ]; then
  ok=0
  printf 'FAIL: stage plan missing at %s\n' "$PLAN"
fi
if [ ! -f "$DISPATCH" ]; then
  ok=0
  printf 'FAIL: dispatch-interface.sh missing at %s\n' "$DISPATCH"
fi
if [ "$ok" -eq 0 ]; then
  fail=$((fail + 1))
  printf 'SUMMARY: p02-append-only.sh pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi
pass=$((pass + 1))

# ---------- Stage: pre-populate log file with fixture records ----------

rm -f "$LOG_FILE" 2>/dev/null
cp "$FIXTURE" "$LOG_FILE"

# Capture pre-dispatch inode.
PRE_INODE_TMP="/tmp/p02-append-only-inode-pre.txt"
POST_INODE_TMP="/tmp/p02-append-only-inode-post.txt"
PRE_HEAD_TMP="/tmp/p02-append-only-head-pre.txt"
POST_HEAD_TMP="/tmp/p02-append-only-head-post.txt"
PRE_LC_TMP="/tmp/p02-append-only-lc-pre.txt"
POST_LC_TMP="/tmp/p02-append-only-lc-post.txt"
rm -f "$PRE_INODE_TMP" "$POST_INODE_TMP" "$PRE_HEAD_TMP" "$POST_HEAD_TMP" "$PRE_LC_TMP" "$POST_LC_TMP" 2>/dev/null

UNAME_S_TMP="/tmp/p02-append-only-uname.txt"
rm -f "$UNAME_S_TMP" 2>/dev/null
uname -s > "$UNAME_S_TMP" 2>/dev/null
uname_s="$(tr -d '[:space:]' < "$UNAME_S_TMP")"
rm -f "$UNAME_S_TMP" 2>/dev/null

if [ "$uname_s" = "Darwin" ]; then
  stat -f '%i' "$LOG_FILE" > "$PRE_INODE_TMP" 2>/dev/null
else
  stat -c '%i' "$LOG_FILE" > "$PRE_INODE_TMP" 2>/dev/null
fi
head -5 "$LOG_FILE" > "$PRE_HEAD_TMP" 2>/dev/null
wc -l < "$LOG_FILE" > "$PRE_LC_TMP" 2>/dev/null

# ---------- Invoke dispatch under shadow-on + CC-on ----------

export ORCHESTRATOR_ROOT="$STAGE"
export M030_SHADOW_MODE=1
export CLAUDECODE=1
unset ORCH_MODEL

bash "$DISPATCH" \
  --task-plan "$PLAN" \
  --payload "$PAYLOAD" \
  --intensity-metadata "$INTENSITY_META" \
  --backend stub \
  > /dev/null 2>&1

# ---------- Re-capture post-dispatch state ----------

if [ "$uname_s" = "Darwin" ]; then
  stat -f '%i' "$LOG_FILE" > "$POST_INODE_TMP" 2>/dev/null
else
  stat -c '%i' "$LOG_FILE" > "$POST_INODE_TMP" 2>/dev/null
fi
head -5 "$LOG_FILE" > "$POST_HEAD_TMP" 2>/dev/null
wc -l < "$LOG_FILE" > "$POST_LC_TMP" 2>/dev/null

# ---------- Assertion 1: inode unchanged ----------

diff "$PRE_INODE_TMP" "$POST_INODE_TMP" > /dev/null 2>&1
if [ $? -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: log file inode changed across dispatch (mv/cp/swap detected)\n'
  printf '  pre-inode: '
  cat "$PRE_INODE_TMP"
  printf '  post-inode: '
  cat "$POST_INODE_TMP"
fi

# ---------- Assertion 2: first-N-lines bit-identical ----------

diff "$PRE_HEAD_TMP" "$POST_HEAD_TMP" > /dev/null 2>&1
if [ $? -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: first-5-lines diverged across dispatch (CON-6 violation: existing records mutated)\n'
fi

# ---------- Assertion 3: line-count delta == +1 ----------

pre_lc="$(tr -d '[:space:]' < "$PRE_LC_TMP")"
post_lc="$(tr -d '[:space:]' < "$POST_LC_TMP")"
[ -n "$pre_lc" ] || pre_lc=0
[ -n "$post_lc" ] || post_lc=0
expected_post=$((pre_lc + 1))
if [ "$post_lc" -eq "$expected_post" ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: line-count delta != +1 (pre=%s, post=%s, expected_post=%d)\n' \
    "$pre_lc" "$post_lc" "$expected_post"
fi

# ---------- Cleanup ----------

rm -f "$PRE_INODE_TMP" "$POST_INODE_TMP" "$PRE_HEAD_TMP" "$POST_HEAD_TMP" "$PRE_LC_TMP" "$POST_LC_TMP" 2>/dev/null
rm -f "$LOG_FILE" 2>/dev/null
unset M030_SHADOW_MODE
unset CLAUDECODE

printf 'SUMMARY: p02-append-only.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
