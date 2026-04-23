#!/usr/bin/env bash
# Gate: T01 — complexity-threshold calibration & pinning.
# Verifies .orchestrator/config.yml threshold keys, corpus-labels.tsv shape,
# and CALIBRATION-MEMO.md section presence.
# Bash 3.2 compatible.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG="${PROJECT_ROOT}/.orchestrator/config.yml"
MEMO="${PROJECT_ROOT}/.orchestrator/milestones/M014/phases/P04/CALIBRATION-MEMO.md"
TSV="${PROJECT_ROOT}/tests/fixtures/m014-p04/corpus-labels.tsv"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -f "$CONFIG" ] || fail "config.yml missing"
[ -f "$MEMO" ]   || fail "CALIBRATION-MEMO.md missing"
[ -f "$TSV" ]    || fail "corpus-labels.tsv missing"

# Non-zero pinned values under specify.complexity_thresholds:
grep -qE '^ *fr_count: *15' "$CONFIG"                       || fail "fr_count not pinned to 15"
grep -qE '^ *user_story_count: *5' "$CONFIG"                || fail "user_story_count not pinned to 5"
grep -qE '^ *raw_token_count: *8000' "$CONFIG"              || fail "raw_token_count not pinned to 8000"
grep -qE '^ *todo_density: *0\.5' "$CONFIG"                 || fail "todo_density not pinned to 0.5"
grep -qE '^ *contradiction_signal_count: *1' "$CONFIG"      || fail "contradiction_signal_count not pinned to 1"
grep -qE '^ *contradiction_signal_criterion: *cc-llm-or-zero' "$CONFIG" || fail "contradiction_signal_criterion key missing"
grep -qE '^ *hardening_spec_exception: *true' "$CONFIG"     || fail "hardening_spec_exception key missing"

# TSV: header + 6 data rows.
LINES="$(wc -l < "$TSV")"
if [ "$LINES" -lt 7 ]; then fail "corpus-labels.tsv has $LINES lines, expected >=7"; fi
grep -qE '^spec_id' "$TSV" || fail "TSV missing header"
grep -qE '^M011' "$TSV"    || fail "TSV missing M011 row"
grep -qE '^M013' "$TSV"    || fail "TSV missing M013 row"
grep -qE '^M016' "$TSV"    || fail "TSV missing M016 row"
grep -qE '^M021' "$TSV"    || fail "TSV missing M021 row"
grep -qE '^M022' "$TSV"    || fail "TSV missing M022 row"
grep -qE '^M024' "$TSV"    || fail "TSV missing M024 row"

# Memo has required sections.
grep -qE '^## Retrospective Corpus' "$MEMO"     || fail "memo missing Retrospective Corpus section"
grep -qE '^## Cutoffs' "$MEMO"                  || fail "memo missing Cutoffs section"
grep -qE '^## Hardening-Spec Exception' "$MEMO" || fail "memo missing Hardening-Spec Exception section"

echo "PASS: complexity-thresholds pinned + memo + corpus shipped"
exit 0
