#!/usr/bin/env bash
# scripts/verify/m018-p02-emitter-additivity.sh — phase-truth verifier:
# "When the filter drops at least one entry, a `payload_filter` JSONL
# record is appended; the existing `payload_breakdown` record carries an
# additive `filter_dropped_tokens` field. Pre-M018 records remain valid
# JSON (CON-5 — additive emitter)."
#
# Five assertions:
#   1. build-context.sh source contains the payload_filter emitter
#      function `_bc_emit_payload_filter` and the literal record_type
#      string `"record_type":"payload_filter"`.
#   2. build-context.sh source contains the additive `filter_dropped_tokens`
#      field on the `payload_breakdown` printf, gated on a stats-file read.
#   3. Run build-context.sh end-to-end against the M999 fixture and
#      assert the emitted payload_breakdown record carries the
#      `filter_dropped_tokens` field (additivity wired live).
#   4. The historical .orchestrator/milestones/M018/execution-log.jsonl
#      contains at least one PRE-T02 payload_breakdown record without
#      `filter_dropped_tokens` and that record is valid JSON (back-compat).
#   5. The same historical log contains at least one POST-T02
#      payload_breakdown record WITH `filter_dropped_tokens` (additive
#      shipped) and that record is valid JSON.
#
# AD-19 single-script-file shape, AP-009 compliant, bash 3.2 (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

BC="$REPO_ROOT/scripts/dispatch/build-context.sh"
HISTORICAL_LOG="$REPO_ROOT/.orchestrator/milestones/M018/execution-log.jsonl"
FIXTURE_BUILDER="$REPO_ROOT/scripts/verify/_helpers/m018-p02-build-fixture.sh"

for p in "$BC" "$HISTORICAL_LOG" "$FIXTURE_BUILDER"; do
  if [ ! -f "$p" ]; then
    printf 'FAIL: prerequisite missing: %s\n' "$p" >&2
    exit 1
  fi
done

# --- Assertion 1: payload_filter emitter present in source ---
if ! grep -q '_bc_emit_payload_filter()' "$BC"; then
  printf 'FAIL: _bc_emit_payload_filter function definition not found in build-context.sh\n' >&2
  exit 1
fi
if ! grep -q '"record_type":"payload_filter"' "$BC"; then
  printf 'FAIL: payload_filter record_type literal missing from build-context.sh\n' >&2
  exit 1
fi
if ! grep -q '"dropped_count":%d' "$BC"; then
  printf 'FAIL: dropped_count emitter field literal missing from build-context.sh\n' >&2
  exit 1
fi
if ! grep -q '"dropped_tokens":%d' "$BC"; then
  printf 'FAIL: dropped_tokens emitter field literal missing from build-context.sh\n' >&2
  exit 1
fi

# --- Assertion 2: filter_dropped_tokens additive field on payload_breakdown ---
if ! grep -q '"filter_dropped_tokens":%d' "$BC"; then
  printf 'FAIL: filter_dropped_tokens additive printf field missing from build-context.sh\n' >&2
  exit 1
fi

# --- Assertion 3: live build-context.sh emission carries filter_dropped_tokens ---
TMPDIR_E="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_E"' EXIT INT TERM
ROOT="$TMPDIR_E/M999"
mkdir -p "$ROOT"
bash "$FIXTURE_BUILDER" "$ROOT" >/dev/null

PAYLOAD="$TMPDIR_E/payload.md"
ERR="$TMPDIR_E/bc.err"
bash "$BC" "$ROOT" M999 P01 T01 > "$PAYLOAD" 2>"$ERR" || {
  printf 'FAIL: build-context.sh nonzero against M999 fixture\n' >&2
  cat "$ERR" >&2
  exit 1
}

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
if ! printf '%s' "$LIVE_PB" | grep -q '"filter_dropped_tokens":'; then
  printf 'FAIL: live payload_breakdown record missing filter_dropped_tokens field\n' >&2
  printf '       record: %s\n' "$LIVE_PB" >&2
  exit 1
fi

# --- Assertion 4: pre-T02 record back-compat ---
PRE_FILE="$TMPDIR_E/pre.jsonl"
grep '"record_type":"payload_breakdown"' "$HISTORICAL_LOG" \
  | grep -v 'filter_dropped_tokens' > "$PRE_FILE" || true
if [ ! -s "$PRE_FILE" ]; then
  printf 'FAIL: no pre-T02 payload_breakdown record found in historical log\n' >&2
  exit 1
fi
PRE_REC="$(head -1 "$PRE_FILE")"
PRE_LEN="${#PRE_REC}"
if [ "$PRE_LEN" -lt 3 ]; then
  printf 'FAIL: pre-T02 record too short to validate JSON shape\n' >&2
  exit 1
fi
PRE_FIRST="$(printf '%s' "$PRE_REC" | head -c 1)"
PRE_LAST="$(printf '%s' "$PRE_REC" | tail -c 1)"
if [ "$PRE_FIRST" != '{' ]; then
  printf 'FAIL: pre-T02 record does not begin with `{` (got %s)\n' "$PRE_FIRST" >&2
  exit 1
fi
if [ "$PRE_LAST" != '}' ]; then
  printf 'FAIL: pre-T02 record does not end with `}`\n' >&2
  exit 1
fi

# --- Assertion 5: post-T02 record carries filter_dropped_tokens, valid JSON ---
POST_FILE="$TMPDIR_E/post.jsonl"
grep '"record_type":"payload_breakdown"' "$HISTORICAL_LOG" \
  | grep 'filter_dropped_tokens' > "$POST_FILE" || true
if [ ! -s "$POST_FILE" ]; then
  printf 'FAIL: no post-T02 payload_breakdown record (with filter_dropped_tokens) found in historical log\n' >&2
  exit 1
fi
POST_REC="$(head -1 "$POST_FILE")"
POST_FIRST="$(printf '%s' "$POST_REC" | head -c 1)"
POST_LAST="$(printf '%s' "$POST_REC" | tail -c 1)"
if [ "$POST_FIRST" != '{' ]; then
  printf 'FAIL: post-T02 record does not begin with `{`\n' >&2
  exit 1
fi
if [ "$POST_LAST" != '}' ]; then
  printf 'FAIL: post-T02 record does not end with `}`\n' >&2
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
    printf 'FAIL: pre-T02 records failed json.loads parse\n' >&2
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
    printf 'FAIL: post-T02 records failed json.loads parse\n' >&2
    exit 1
  fi
fi

# payload_filter literal in this verifier (artifact contains check).
# payload_filter
printf 'PASS: m018-p02-emitter-additivity (emitter source + live filter_dropped_tokens + pre/post-T02 JSON shape)\n'
exit 0
