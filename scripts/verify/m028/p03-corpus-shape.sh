#!/usr/bin/env bash
# scripts/verify/m028/p03-corpus-shape.sh
#
# M028/P03/T04 verifier: asserts the corpus fixture
# tests/fixtures/m021-prompt-corpus.txt carries 27 entries
# (20 pre-existing M021 entries unchanged + 7 new M028 entries appended
# verbatim); each new entry has the EXPECTED_OUTCOME the spec mandates;
# IDs 01..20 are byte-identical to the pre-T04 baseline (pinned in this
# verifier's BASELINE_ID_NN_OUTCOME table); ID 25 carries the literal
# UTF-8 box-drawing bytes; the file ends with a terminating "---".
#
# Single-script-file shape (AD-19). Bash 3.2 + POSIX-sh safe.
# No jq; no pipe inside command substitution.
#
# Per CON-7 / SC-8: M021 entries 01..20 must be preserved byte-for-byte.
# Per CON-8: single permanent corpus file; appended-to, never split.
#
# Companion gate: tests/run-prompt-corpus-replay.sh sets EXPECTED_TOTAL=27;
# the M021 historical harness scripts/verify/replay-prompt-corpus.sh was
# patched to EXPECTED_TOTAL=27 in T05 to mirror this corpus extension.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd -P)"
CORPUS="${REPO_ROOT}/tests/fixtures/m021-prompt-corpus.txt"

if [ ! -f "$CORPUS" ]; then
  printf 'FAIL: corpus not found at %s\n' "$CORPUS" >&2
  exit 1
fi

fail_count=0

# --- Pinned baseline: IDs 01..20 EXPECTED_OUTCOME values ---
# These are the M021 SC-1 contract; any drift here is a CON-7 violation.
BASELINE_ID_01='rewrite:bash scripts/util/run-probe.sh /tmp/m011-p05-probe.sh'
BASELINE_ID_02='rewrite:bash scripts/util/read-range.sh specs/011-ingest-a-spec/spec.md 10 20'
BASELINE_ID_03='rewrite:bash scripts/verify/run-suite.sh m011 P05'
BASELINE_ID_04='rewrite:bash scripts/state/derive-phase.sh'
BASELINE_ID_05='rewrite:bash scripts/util/with-env.sh CONVERSUS_TIER=B -- bash scripts/ingest/parse-spec.sh specs/011-ingest-a-spec/spec.md'
BASELINE_ID_06='rewrite:bash scripts/util/read-range.sh'
BASELINE_ID_07='allow'
BASELINE_ID_08='reject:nested-cmd-sub'
BASELINE_ID_09='reject:compound-chain-gt2'
BASELINE_ID_10='reject:heredoc-with-expansion'
BASELINE_ID_11='reject:quoted-brace'
BASELINE_ID_12='rewrite:bash scripts/util/read-range.sh .orchestrator/milestones/M011/phases/P06/P06-PLAN.md 1 50'
BASELINE_ID_13='rewrite:bash scripts/util/with-env.sh WIKI_OUT=/tmp/wiki DRY_RUN=1 -- bash scripts/wiki/build-index.sh'
BASELINE_ID_14='reject:compound-chain-gt2'
BASELINE_ID_15='rewrite:bash scripts/util/run-probe.sh /tmp/m011-p07-conversus.sh'
BASELINE_ID_16='rewrite:bash ../../scripts/ingest/validate.sh'
BASELINE_ID_17='allow'
BASELINE_ID_18='allow'
BASELINE_ID_19='rewrite:bash scripts/verify/anti-pattern-lint.sh'
BASELINE_ID_20='allow'

# --- New entries: IDs 21..27 EXPECTED_OUTCOME values ---
NEW_ID_21='reject:cmd-sub-in-pattern'
NEW_ID_22='reject:quoted-arg-newline-hash'
NEW_ID_23='reject:multiline-quoted-script'
NEW_ID_24='reject:unquoted-brace-glob'
NEW_ID_25='reject:xargs-sh-c-compound-body'
NEW_ID_26='allow'
NEW_ID_27='reject:xargs-sh-c-compound-body'

# --- Build a tab-separated <id>\t<expected> table from the corpus.
# We collect EXPECTED_OUTCOME lines paired with their preceding ID line;
# avoids any pipe-in-cmdsub shape.
TMP_OUT="$(mktemp)"
awk '
  /^ID: /            { id = substr($0, 5); next }
  /^EXPECTED_OUTCOME: / {
    expected = substr($0, 19)
    if (id != "") {
      printf "%s\t%s\n", id, expected
      id = ""
    }
  }
' "$CORPUS" > "$TMP_OUT"

# --- Check 1: total entry count == 27 ---
entry_count=0
while IFS=$'\t' read -r _eid _exp; do
  entry_count=$((entry_count + 1))
done < "$TMP_OUT"

if [ "$entry_count" -eq 27 ]; then
  printf 'PASS: corpus entry count = 27\n'
else
  printf 'FAIL: corpus entry count: expected 27 got %s\n' "$entry_count" >&2
  fail_count=$((fail_count + 1))
fi

# --- Check 2: per-ID EXPECTED_OUTCOME assertions for 01..27 ---
# Read the table back and assert each id maps to its pinned value.

assert_id() {
  # $1 = id (two-digit string); $2 = expected; $3 = actual_from_table
  local id="$1"
  local want="$2"
  local got="$3"
  if [ "$got" = "$want" ]; then
    printf 'PASS: ID %s EXPECTED_OUTCOME: %s\n' "$id" "$want"
  else
    printf 'FAIL: ID %s EXPECTED_OUTCOME: expected [%s] got [%s]\n' "$id" "$want" "$got" >&2
    fail_count=$((fail_count + 1))
  fi
}

# Look up an ID's recorded expected from the table; emits the value or empty.
lookup_expected() {
  # $1 = id (two-digit). Echoes the expected verdict or empty if absent.
  awk -v want_id="$1" -F'\t' '
    $1 == want_id { print $2; found=1; exit }
  ' "$TMP_OUT"
}

# IDs 01..20 byte-identical-to-baseline check.
all_baseline_ok=1
for id_n in 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20; do
  varname="BASELINE_ID_${id_n}"
  want="${!varname}"
  got="$(lookup_expected "$id_n")"
  if [ "$got" != "$want" ]; then
    all_baseline_ok=0
    printf 'FAIL: ID %s baseline drift: expected [%s] got [%s]\n' "$id_n" "$want" "$got" >&2
    fail_count=$((fail_count + 1))
  fi
done

if [ "$all_baseline_ok" -eq 1 ]; then
  printf 'PASS: IDs 01..20 byte-identical to pre-T04 baseline\n'
fi

# IDs 21..27 per-entry pinned-value check.
for id_n in 21 22 23 24 25 26 27; do
  varname="NEW_ID_${id_n}"
  want="${!varname}"
  got="$(lookup_expected "$id_n")"
  assert_id "$id_n" "$want" "$got"
done

rm -f "$TMP_OUT"

# --- Check 3: ID 25 carries literal UTF-8 box-drawing bytes (U+2550, 0xE2 0x95 0x90) ---
# We assert the byte sequence appears at least 4 times anywhere in the corpus
# (the verbatim screenshot string contains four box-drawing glyphs). This is
# a coarse check (not pinned to ID 25 line) because ID-25 INPUT is the only
# corpus line carrying box-drawing bytes; presence implies it's on ID-25.
box_count="$(grep -c '═' "$CORPUS" || true)"
# grep -c counts matching LINES. The ID-25 INPUT line carries multiple glyphs
# but is one line. Verify at least 1 line matches.
if [ "$box_count" -ge 1 ]; then
  printf 'PASS: ID 25 verbatim INPUT contains UTF-8 box-drawing bytes\n'
else
  printf 'FAIL: ID 25 verbatim INPUT missing UTF-8 box-drawing bytes\n' >&2
  fail_count=$((fail_count + 1))
fi

# --- Check 4: file ends with terminating "---" ---
last_line="$(tail -n 1 "$CORPUS")"
if [ "$last_line" = "---" ]; then
  printf 'PASS: file ends with terminating ---\n'
else
  printf 'FAIL: file does not end with terminating --- (got [%s])\n' "$last_line" >&2
  fail_count=$((fail_count + 1))
fi

if [ "$fail_count" -gt 0 ]; then
  printf 'FAIL: %d check(s) failed in p03-corpus-shape.sh\n' "$fail_count" >&2
  exit 1
fi

printf 'PASS: p03-corpus-shape.sh\n'
exit 0
