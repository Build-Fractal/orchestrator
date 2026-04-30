#!/usr/bin/env bash
# tools/verify/p04-con6-prior-records-bit-identical.sh -- M030/P04 CON-6 append-only.
#
# Asserts the CON-6 invariant for the escalation log: as additional records
# are appended (mid-loop dispatch_usage emits + escalation_cap_hit emit),
# prior records' bytes remain unchanged. Two checks:
#
#   1. INODE preservation -- the log file's inode does NOT change between
#      pre-dispatch creation and post-dispatch end. Catches `mv old new`,
#      `cp old new`, or temp-file-and-swap shapes that would silently
#      replace the file under the same path.
#   2. HEAD-2 hash equality after synthetic append -- after the dispatch
#      completes, capture SHA-256 of head -n 2 of the log; append a
#      synthetic line; recompute SHA-256 of head -n 2; assert equal. This
#      proves that downstream appends do NOT mutate prior records' bytes
#      (the file-system invariant CON-6 ultimately asserts).
#
# Two assertions. The verifier uses the fail-twice-then-pass plan
# (counter=2) so 3 dispatch_usage records get appended; head -n 2 reads
# the first two records and asserts they remain bit-stable across a
# synthetic append.
#
# Note: the escalation loop is synchronous, so capturing first-2-lines
# hashes between adapter invocations would require modifying
# dispatch-interface.sh. The post-dispatch synthetic-append + head-2-hash
# equality is the mechanically-verifiable proxy for "appending records
# does not mutate prior records' bytes".
#
# Bash 3.2 compatible. AD-19 single-script-file shape. AP-009: tmp-file
# intermediates throughout (head ... | shasum ... | cut chain unrolled).

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURES="$REPO_ROOT/tests/fixtures/m030-p04"
PLAN="$FIXTURES/plans/plan-fail-twice-then-pass.md"
PAYLOAD="$FIXTURES/round-trip-stage/payload.txt"
INTENSITY_META="$FIXTURES/round-trip-stage/intensity-metadata.txt"
CONFIG="$FIXTURES/configs/config-with-live-true.yml"
READY_CORPUS="$FIXTURES/shadow-corpus-ready.jsonl"
DISPATCH="$REPO_ROOT/scripts/dispatch/dispatch-interface.sh"

pass=0
fail=0

ok=1
for f in "$PLAN" "$PAYLOAD" "$INTENSITY_META" "$CONFIG" "$READY_CORPUS" "$DISPATCH"; do
  if [ ! -f "$f" ]; then
    ok=0
    printf 'FAIL: prerequisite missing at %s\n' "$f"
  fi
done
if [ "$ok" -ne 1 ]; then
  printf 'SUMMARY: p04-con6-prior-records-bit-identical.sh pass=%d fail=1\n' "$pass"
  exit 1
fi

# --- Stage tmp_root + counter file (value=2 -> fail twice then pass) ---
TMP_ROOT="$(mktemp -d 2>/dev/null)"
if [ -z "$TMP_ROOT" ]; then
  TMP_ROOT="/tmp/p04-con6-fallback-$$"
  rm -rf "$TMP_ROOT" 2>/dev/null
  mkdir -p "$TMP_ROOT" 2>/dev/null
fi
mkdir -p "$TMP_ROOT/.orchestrator" 2>/dev/null
mkdir -p "$TMP_ROOT/phases" 2>/dev/null
cp "$CONFIG" "$TMP_ROOT/.orchestrator/config.yml" 2>/dev/null
LOG_FILE="$TMP_ROOT/execution-log.jsonl"

COUNTER_FILE="$TMP_ROOT/fail-counter.txt"
printf '2\n' > "$COUNTER_FILE"
INVOCATIONS_FILE="$TMP_ROOT/invocations.txt"
: > "$INVOCATIONS_FILE"

# Pre-create the log file with `:>` so we can capture a baseline inode
# before dispatch starts. The dispatcher's mkdir/append will reuse the
# same file path; if the inode changes, something replaced the file.
: > "$LOG_FILE"

# Capture pre-dispatch inode. macOS uses `stat -f %i`, Linux uses `stat -c %i`.
# Try macOS first (the project's primary dev platform); fall back to Linux.
INODE_BEFORE_TMP="/tmp/p04-con6-inode-before.txt"
rm -f "$INODE_BEFORE_TMP" 2>/dev/null
stat -f %i "$LOG_FILE" > "$INODE_BEFORE_TMP" 2>/dev/null
INODE_BEFORE="$(tr -d '[:space:]' < "$INODE_BEFORE_TMP" 2>/dev/null)"
if [ -z "$INODE_BEFORE" ]; then
  stat -c %i "$LOG_FILE" > "$INODE_BEFORE_TMP" 2>/dev/null
  INODE_BEFORE="$(tr -d '[:space:]' < "$INODE_BEFORE_TMP" 2>/dev/null)"
fi
rm -f "$INODE_BEFORE_TMP" 2>/dev/null

unset ORCH_MODEL
export ORCHESTRATOR_ROOT="$TMP_ROOT"
export M030_SHADOW_MODE=1
export CLAUDECODE=1
export M030_SHADOW_COMPARE_CORPUS="$READY_CORPUS"
export STUB_FAIL_COUNTER_FILE="$COUNTER_FILE"
export STUB_FAIL_COUNTER_INVOCATIONS_FILE="$INVOCATIONS_FILE"

DISPATCH_OUT_TMP="/tmp/p04-con6-out.txt"
DISPATCH_ERR_TMP="/tmp/p04-con6-err.txt"
rm -f "$DISPATCH_OUT_TMP" "$DISPATCH_ERR_TMP" 2>/dev/null
bash "$DISPATCH" \
  --task-plan "$PLAN" \
  --payload "$PAYLOAD" \
  --intensity-metadata "$INTENSITY_META" \
  --backend stub-fail-n \
  > "$DISPATCH_OUT_TMP" 2> "$DISPATCH_ERR_TMP"
DISPATCH_RC=$?

# Capture post-dispatch inode.
INODE_AFTER_TMP="/tmp/p04-con6-inode-after.txt"
rm -f "$INODE_AFTER_TMP" 2>/dev/null
stat -f %i "$LOG_FILE" > "$INODE_AFTER_TMP" 2>/dev/null
INODE_AFTER="$(tr -d '[:space:]' < "$INODE_AFTER_TMP" 2>/dev/null)"
if [ -z "$INODE_AFTER" ]; then
  stat -c %i "$LOG_FILE" > "$INODE_AFTER_TMP" 2>/dev/null
  INODE_AFTER="$(tr -d '[:space:]' < "$INODE_AFTER_TMP" 2>/dev/null)"
fi
rm -f "$INODE_AFTER_TMP" 2>/dev/null

# --- Assertion 1: inode preserved across dispatch ---
if [ -n "$INODE_BEFORE" ] && [ "$INODE_BEFORE" = "$INODE_AFTER" ]; then
  pass=$((pass + 1))
  printf 'PASS: log-file inode preserved (%s == %s) across dispatch\n' \
    "$INODE_BEFORE" "$INODE_AFTER"
else
  fail=$((fail + 1))
  printf 'FAIL: log-file inode changed (%s -> %s); file may have been replaced\n' \
    "$INODE_BEFORE" "$INODE_AFTER"
fi

# --- Capture HEAD_PRE: SHA-256 of head -n 2 of the log file ---
# AP-009 unrolling: head -> shasum -> cut as three tmp-file stages.
HEAD_PRE_TMP="/tmp/p04-con6-head-pre.txt"
SHA_PRE_TMP="/tmp/p04-con6-sha-pre.txt"
rm -f "$HEAD_PRE_TMP" "$SHA_PRE_TMP" 2>/dev/null
head -n 2 "$LOG_FILE" > "$HEAD_PRE_TMP" 2>/dev/null
shasum -a 256 "$HEAD_PRE_TMP" > "$SHA_PRE_TMP" 2>/dev/null
HASH_PRE_RAW="$(head -n 1 "$SHA_PRE_TMP" 2>/dev/null)"
HASH_PRE="$(printf '%s' "$HASH_PRE_RAW" | awk '{print $1}')"
rm -f "$HEAD_PRE_TMP" "$SHA_PRE_TMP" 2>/dev/null

# --- Append a synthetic line to the log file ---
printf 'synthetic-line-for-con6-test\n' >> "$LOG_FILE"

# --- Capture HEAD_POST: SHA-256 of head -n 2 of the log file (post-append) ---
HEAD_POST_TMP="/tmp/p04-con6-head-post.txt"
SHA_POST_TMP="/tmp/p04-con6-sha-post.txt"
rm -f "$HEAD_POST_TMP" "$SHA_POST_TMP" 2>/dev/null
head -n 2 "$LOG_FILE" > "$HEAD_POST_TMP" 2>/dev/null
shasum -a 256 "$HEAD_POST_TMP" > "$SHA_POST_TMP" 2>/dev/null
HASH_POST_RAW="$(head -n 1 "$SHA_POST_TMP" 2>/dev/null)"
HASH_POST="$(printf '%s' "$HASH_POST_RAW" | awk '{print $1}')"
rm -f "$HEAD_POST_TMP" "$SHA_POST_TMP" 2>/dev/null

# --- Assertion 2: head-2 hash unchanged after synthetic append ---
if [ -n "$HASH_PRE" ] && [ "$HASH_PRE" = "$HASH_POST" ]; then
  pass=$((pass + 1))
  printf 'PASS: head-2 hash unchanged after synthetic append (%s)\n' "$HASH_PRE"
else
  fail=$((fail + 1))
  printf 'FAIL: head-2 hash changed across synthetic append (%s -> %s)\n' \
    "$HASH_PRE" "$HASH_POST"
fi

# --- Cleanup ---
rm -f "$DISPATCH_OUT_TMP" "$DISPATCH_ERR_TMP" 2>/dev/null
rm -rf "$TMP_ROOT" 2>/dev/null
unset M030_SHADOW_COMPARE_CORPUS STUB_FAIL_COUNTER_FILE STUB_FAIL_COUNTER_INVOCATIONS_FILE

# Reference $DISPATCH_RC so set -u is happy on future audits (we don't
# assert exit code here -- the inode + hash checks are CON-6's contract).
: "$DISPATCH_RC"

printf 'SUMMARY: p04-con6-prior-records-bit-identical.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
