#!/usr/bin/env bash
# scripts/verify/m018-p03-emitter-additivity.sh — phase-truth verifier:
# "`payload_breakdown` JSONL records carry additive `tier1_savings_tokens`
# and `tier1_invocations` integer fields; pre-T1 records remain valid
# JSON; missing fields default to 0 in rollups (CON-5)."
#
# Five assertions:
#   1. build-context.sh source contains the additive `tier1_savings_tokens`
#      and `tier1_invocations` field literals on the payload_breakdown
#      printf, plus `_bc_apply_tier1` function definition.
#   2. Run build-context.sh end-to-end against the M018-fixture and
#      assert the emitted payload_breakdown record carries both
#      `tier1_savings_tokens` and `tier1_invocations` keys with integer
#      values.
#   3. The historical .orchestrator/milestones/M018/execution-log.jsonl
#      contains at least one PRE-T01 payload_breakdown record without
#      `tier1_savings_tokens` and that record is valid JSON (back-compat).
#   4. The same historical log contains at least one POST-T01
#      payload_breakdown record WITH `tier1_savings_tokens` (additive
#      shipped) and that record is valid JSON.
#   5. Pre-existing fields (payload_chars, filter_dropped_tokens, model)
#      are still present on the live emission (CON-5 additivity check).
#
# AD-19 single-script-file shape, AP-009 compliant, bash 3.2 (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

BC="$REPO_ROOT/scripts/dispatch/build-context.sh"
HISTORICAL_LOG="$REPO_ROOT/.orchestrator/milestones/M018/execution-log.jsonl"
HELPER="$REPO_ROOT/scripts/verify/_helpers/m018-p03-build-fixture.sh"

for p in "$BC" "$HISTORICAL_LOG" "$HELPER"; do
  if [ ! -f "$p" ]; then
    printf 'FAIL: prerequisite missing: %s\n' "$p" >&2
    exit 1
  fi
done

# --- Assertion 1: emitter source carries tier1_* additive fields + function def ---
if ! grep -q '_bc_apply_tier1()' "$BC"; then
  printf 'FAIL: _bc_apply_tier1 function definition missing from build-context.sh\n' >&2
  exit 1
fi
if ! grep -q '"tier1_savings_tokens":%d' "$BC"; then
  printf 'FAIL: tier1_savings_tokens additive printf field missing from build-context.sh\n' >&2
  exit 1
fi
if ! grep -q '"tier1_invocations":%d' "$BC"; then
  printf 'FAIL: tier1_invocations additive printf field missing from build-context.sh\n' >&2
  exit 1
fi

# --- Assertion 2: live build-context.sh emission carries tier1_* fields ---
TMPDIR_E="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_E"' EXIT INT TERM
ROOT="$TMPDIR_E/M018-fixture"
mkdir -p "$ROOT"
bash "$HELPER" "$ROOT" >/dev/null

PAYLOAD="$TMPDIR_E/payload.md"
ERR="$TMPDIR_E/bc.err"
if ! bash "$BC" "$ROOT" M018-fixture P03 T01 > "$PAYLOAD" 2>"$ERR"; then
  printf 'FAIL: build-context.sh nonzero against M018-fixture\n' >&2
  cat "$ERR" >&2
  exit 1
fi

LIVE_LOG="$ROOT/execution-log.jsonl"
if [ ! -s "$LIVE_LOG" ]; then
  printf 'FAIL: execution-log.jsonl missing or empty after build-context run\n' >&2
  exit 1
fi
if ! grep -q '"record_type":"payload_breakdown"' "$LIVE_LOG"; then
  printf 'FAIL: live log missing payload_breakdown record\n' >&2
  exit 1
fi

LIVE_PB="$(grep '"record_type":"payload_breakdown"' "$LIVE_LOG" | head -1)"
if ! printf '%s' "$LIVE_PB" | grep -q '"tier1_savings_tokens":'; then
  printf 'FAIL: live payload_breakdown record missing tier1_savings_tokens field\n' >&2
  printf '       record: %s\n' "$LIVE_PB" >&2
  exit 1
fi
if ! printf '%s' "$LIVE_PB" | grep -q '"tier1_invocations":'; then
  printf 'FAIL: live payload_breakdown record missing tier1_invocations field\n' >&2
  printf '       record: %s\n' "$LIVE_PB" >&2
  exit 1
fi
# Integer-valued check for both fields.
if ! printf '%s' "$LIVE_PB" | grep -qE '"tier1_savings_tokens":[0-9]+'; then
  printf 'FAIL: live tier1_savings_tokens not integer-valued\n' >&2
  exit 1
fi
if ! printf '%s' "$LIVE_PB" | grep -qE '"tier1_invocations":[0-9]+'; then
  printf 'FAIL: live tier1_invocations not integer-valued\n' >&2
  exit 1
fi

# --- Assertion 5 (live additivity): pre-existing fields still present ---
for fld in '"payload_chars":' '"filter_dropped_tokens":' '"model":'; do
  if ! printf '%s' "$LIVE_PB" | grep -q "$fld"; then
    printf 'FAIL: live payload_breakdown record missing pre-existing field %s\n' "$fld" >&2
    printf '       record: %s\n' "$LIVE_PB" >&2
    exit 1
  fi
done

# --- Assertion 3: pre-T01 record back-compat ---
PRE_FILE="$TMPDIR_E/pre.jsonl"
grep '"record_type":"payload_breakdown"' "$HISTORICAL_LOG" \
  | grep -v 'tier1_savings_tokens' > "$PRE_FILE" || true
if [ ! -s "$PRE_FILE" ]; then
  printf 'FAIL: no pre-T01 payload_breakdown record found in historical log\n' >&2
  exit 1
fi
PRE_REC="$(head -1 "$PRE_FILE")"
PRE_FIRST="$(printf '%s' "$PRE_REC" | head -c 1)"
PRE_LAST="$(printf '%s' "$PRE_REC" | tail -c 1)"
if [ "$PRE_FIRST" != '{' ]; then
  printf 'FAIL: pre-T01 record does not begin with `{` (got %s)\n' "$PRE_FIRST" >&2
  exit 1
fi
if [ "$PRE_LAST" != '}' ]; then
  printf 'FAIL: pre-T01 record does not end with `}`\n' >&2
  exit 1
fi

# --- Assertion 4: post-T01 record carries tier1_savings_tokens, valid JSON ---
POST_FILE="$TMPDIR_E/post.jsonl"
grep '"record_type":"payload_breakdown"' "$HISTORICAL_LOG" \
  | grep 'tier1_savings_tokens' > "$POST_FILE" || true
if [ ! -s "$POST_FILE" ]; then
  printf 'FAIL: no post-T01 payload_breakdown record (with tier1_savings_tokens) found in historical log\n' >&2
  exit 1
fi
POST_REC="$(head -1 "$POST_FILE")"
POST_FIRST="$(printf '%s' "$POST_REC" | head -c 1)"
POST_LAST="$(printf '%s' "$POST_REC" | tail -c 1)"
if [ "$POST_FIRST" != '{' ]; then
  printf 'FAIL: post-T01 record does not begin with `{`\n' >&2
  exit 1
fi
if [ "$POST_LAST" != '}' ]; then
  printf 'FAIL: post-T01 record does not end with `}`\n' >&2
  exit 1
fi

# Optional Python jsonl validation pass when python3 is available.
if command -v python3 >/dev/null 2>&1; then
  if ! python3 -c 'import sys, json
ok=True
for line in sys.stdin:
    line=line.strip()
    if not line: continue
    try: json.loads(line)
    except Exception as e:
        print("BADJSON:"+str(e)); ok=False
sys.exit(0 if ok else 2)' < "$PRE_FILE" >/dev/null 2>&1; then
    printf 'FAIL: pre-T01 records failed json.loads parse\n' >&2
    exit 1
  fi
  if ! python3 -c 'import sys, json
ok=True
for line in sys.stdin:
    line=line.strip()
    if not line: continue
    try: json.loads(line)
    except Exception as e:
        print("BADJSON:"+str(e)); ok=False
sys.exit(0 if ok else 2)' < "$POST_FILE" >/dev/null 2>&1; then
    printf 'FAIL: post-T01 records failed json.loads parse\n' >&2
    exit 1
  fi
fi

# tier1_savings_tokens literal in this verifier (artifact contains check).
printf 'PASS: m018-p03-emitter-additivity (emitter source + live tier1_savings_tokens/tier1_invocations + pre/post-T01 JSON shape)\n'
exit 0
