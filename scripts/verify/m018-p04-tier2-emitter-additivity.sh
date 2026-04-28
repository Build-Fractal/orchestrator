#!/usr/bin/env bash
# scripts/verify/m018-p04-tier2-emitter-additivity.sh — phase-truth verifier:
# "`payload_breakdown` JSONL records carry an additive integer
# `tier2_savings_tokens` field; pre-T2 records remain valid JSON;
# missing field defaults to 0 in rollups (CON-5)."
#
# Five assertions:
#   1. build-context.sh source carries the additive `tier2_savings_tokens`
#      field literal on the payload_breakdown printf, plus the
#      `_bc_apply_tier2` function definition.
#   2. The historical execution-log contains pre-T2 payload_breakdown
#      records WITHOUT `tier2_savings_tokens` and those records remain
#      valid JSON (back-compat).
#   3. The historical execution-log contains post-T2 payload_breakdown
#      records WITH `tier2_savings_tokens` and those records are valid
#      JSON (additive shipped).
#   4. Pre-existing fields (payload_chars, filter_dropped_tokens,
#      tier1_savings_tokens, model) are still present on post-T2 records
#      (CON-5 additivity check — no replacement).
#   5. Run end-to-end build-context.sh against the M018-fixture and
#      assert the live payload_breakdown record carries
#      `tier2_savings_tokens` with an integer value (zero or positive
#      depending on whether the fixture body crosses budget — additive
#      contract requires the field present, not the value > 0).
#
# AD-19 single-script-file shape, AP-009 compliant, bash 3.2 (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

BC="$REPO_ROOT/scripts/dispatch/build-context.sh"
HELPER="$REPO_ROOT/scripts/verify/_helpers/m018-p04-build-fixture.sh"
HISTORICAL_LOG="$REPO_ROOT/.orchestrator/milestones/M018/execution-log.jsonl"

for p in "$BC" "$HELPER" "$HISTORICAL_LOG"; do
  if [ ! -f "$p" ]; then
    printf 'FAIL: prerequisite missing: %s\n' "$p" >&2
    exit 1
  fi
done

# --- Assertion 1: emitter source carries tier2 additive field + function def ---
if ! grep -q '_bc_apply_tier2()' "$BC"; then
  printf 'FAIL: _bc_apply_tier2 function definition missing from build-context.sh\n' >&2
  exit 1
fi
if ! grep -q '"tier2_savings_tokens":%d' "$BC"; then
  printf 'FAIL: tier2_savings_tokens additive printf field missing from build-context.sh\n' >&2
  exit 1
fi

TMPDIR_E="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_E"' EXIT INT TERM

# --- Assertion 2: pre-T2 records are JSON-valid + missing tier2 field ---
PRE_FILE="$TMPDIR_E/pre.jsonl"
grep '"record_type":"payload_breakdown"' "$HISTORICAL_LOG" \
  | grep -v 'tier2_savings_tokens' > "$PRE_FILE" || true
if [ ! -s "$PRE_FILE" ]; then
  printf 'FAIL: no pre-T2 payload_breakdown record found in historical log\n' >&2
  exit 1
fi
PRE_REC="$(head -1 "$PRE_FILE")"
PRE_FIRST="$(printf '%s' "$PRE_REC" | head -c 1)"
PRE_LAST="$(printf '%s' "$PRE_REC" | tail -c 1)"
if [ "$PRE_FIRST" != '{' ] || [ "$PRE_LAST" != '}' ]; then
  printf 'FAIL: pre-T2 record not bracketed as JSON object\n' >&2
  exit 1
fi

# --- Assertion 3: post-T2 records carry tier2_savings_tokens, valid JSON ---
POST_FILE="$TMPDIR_E/post.jsonl"
grep '"record_type":"payload_breakdown"' "$HISTORICAL_LOG" \
  | grep 'tier2_savings_tokens' > "$POST_FILE" || true
if [ ! -s "$POST_FILE" ]; then
  printf 'FAIL: no post-T2 payload_breakdown record (with tier2_savings_tokens) in historical log\n' >&2
  exit 1
fi
POST_REC="$(head -1 "$POST_FILE")"
POST_FIRST="$(printf '%s' "$POST_REC" | head -c 1)"
POST_LAST="$(printf '%s' "$POST_REC" | tail -c 1)"
if [ "$POST_FIRST" != '{' ] || [ "$POST_LAST" != '}' ]; then
  printf 'FAIL: post-T2 record not bracketed as JSON object\n' >&2
  exit 1
fi

# --- Assertion 4: post-T2 records still carry pre-existing fields ---
for fld in '"payload_chars":' '"filter_dropped_tokens":' '"tier1_savings_tokens":' '"model":'; do
  if ! printf '%s' "$POST_REC" | grep -q "$fld"; then
    printf 'FAIL: post-T2 record missing pre-existing field %s\n' "$fld" >&2
    printf '       record: %s\n' "$POST_REC" >&2
    exit 1
  fi
done

# --- Assertion 5: live emission carries integer tier2_savings_tokens ---
ROOT="$TMPDIR_E/M018-fixture"
mkdir -p "$ROOT"
bash "$HELPER" "$ROOT" section-overflow >/dev/null

PAYLOAD="$TMPDIR_E/payload.md"
ERR="$TMPDIR_E/bc.err"
if ! bash "$BC" "$ROOT" M018-fixture P04 T01 > "$PAYLOAD" 2>"$ERR"; then
  printf 'FAIL: build-context.sh nonzero against M018-fixture\n' >&2
  cat "$ERR" >&2
  exit 1
fi

LIVE_LOG="$ROOT/execution-log.jsonl"
if [ ! -s "$LIVE_LOG" ]; then
  printf 'FAIL: execution-log.jsonl missing or empty after build-context run\n' >&2
  exit 1
fi
LIVE_PB="$(grep '"record_type":"payload_breakdown"' "$LIVE_LOG" | head -1)"
if [ -z "$LIVE_PB" ]; then
  printf 'FAIL: live log missing payload_breakdown record\n' >&2
  exit 1
fi
if ! printf '%s' "$LIVE_PB" | grep -qE '"tier2_savings_tokens":[0-9]+'; then
  printf 'FAIL: live payload_breakdown record missing integer tier2_savings_tokens\n' >&2
  printf '       record: %s\n' "$LIVE_PB" >&2
  exit 1
fi
# Additivity: live record still carries pre-existing tier1 + filter fields.
for fld in '"tier1_savings_tokens":' '"tier1_invocations":' '"filter_dropped_tokens":'; do
  if ! printf '%s' "$LIVE_PB" | grep -q "$fld"; then
    printf 'FAIL: live record missing pre-existing field %s (tier2 additivity broke prior tiers)\n' "$fld" >&2
    exit 1
  fi
done

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
    printf 'FAIL: pre-T2 records failed json.loads parse\n' >&2
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
    printf 'FAIL: post-T2 records failed json.loads parse\n' >&2
    exit 1
  fi
fi

# tier2_savings_tokens literal in this verifier (artifact contains check).
printf 'PASS: m018-p04-tier2-emitter-additivity (emitter source + live record + pre/post-T2 historical JSON shape)\n'
exit 0
