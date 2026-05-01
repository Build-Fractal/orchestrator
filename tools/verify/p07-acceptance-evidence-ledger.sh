#!/usr/bin/env bash
# tools/verify/p07-acceptance-evidence-ledger.sh — M030 acceptance-evidence
# ledger shape gate.
#
# Asserts the one-shot evidence ledger at
# .orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md is well-shaped:
#
#   1. file exists
#   2. frontmatter contains required keys (schema_version,
#      type: acceptance-evidence, milestone: "M030", recorded_at,
#      battery_summary, runner)
#   3. body contains a "## Evidence" section header and each of the
#      14 SC labels (SC-1, SC-2, SC-2a, SC-3, SC-3a, SC-4, SC-5, SC-6,
#      SC-7, SC-7a, SC-8, SC-9, SC-10, SC-11)
#   4. every cited verifier path (matching tools/verify/p[0-9]+-.*\.sh)
#      resolves to an existing-on-disk script
#
# Bash 3.2 compatible. AD-19 single-script-file shape preserved —
# parallel scalars + if-statements; no compound chains; no eval.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

LEDGER="$PROJECT_ROOT/.orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md"

pass=0
fail=0

# ---------- Check 1: ledger file exists ----------

if [ -f "$LEDGER" ]; then
  pass=$((pass + 1))
  echo "OK: ledger exists at $LEDGER"
else
  fail=$((fail + 1))
  echo "FAIL: ledger not found at $LEDGER"
  printf 'SUMMARY: p07-acceptance-evidence-ledger.sh pass=%s fail=%s\n' "$pass" "$fail"
  exit 1
fi

# ---------- Check 2: frontmatter required keys ----------

# Extract frontmatter (lines between the first two --- lines) into a tmp file.
FM_FILE=$(mktemp -t p07-evidence-fm.XXXXXX)
trap 'rm -f "$FM_FILE"' EXIT

awk '
  BEGIN { in_fm = 0; seen = 0 }
  /^---$/ {
    if (seen == 0) { in_fm = 1; seen = 1; next }
    if (in_fm == 1) { in_fm = 0; exit }
  }
  in_fm == 1 { print }
' "$LEDGER" > "$FM_FILE"

grep -q '^schema_version:' "$FM_FILE"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
  echo "OK: frontmatter has schema_version"
else
  fail=$((fail + 1))
  echo "FAIL: frontmatter missing schema_version"
fi

grep -q '^type: acceptance-evidence' "$FM_FILE"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
  echo "OK: frontmatter has type: acceptance-evidence"
else
  fail=$((fail + 1))
  echo "FAIL: frontmatter missing type: acceptance-evidence"
fi

grep -q '^milestone: "M030"' "$FM_FILE"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
  echo "OK: frontmatter has milestone: \"M030\""
else
  fail=$((fail + 1))
  echo "FAIL: frontmatter missing milestone: \"M030\""
fi

grep -q '^recorded_at:' "$FM_FILE"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
  echo "OK: frontmatter has recorded_at"
else
  fail=$((fail + 1))
  echo "FAIL: frontmatter missing recorded_at"
fi

grep -q '^battery_summary:' "$FM_FILE"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
  echo "OK: frontmatter has battery_summary"
else
  fail=$((fail + 1))
  echo "FAIL: frontmatter missing battery_summary"
fi

grep -q '^runner:' "$FM_FILE"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
  echo "OK: frontmatter has runner"
else
  fail=$((fail + 1))
  echo "FAIL: frontmatter missing runner"
fi

# ---------- Check 3: body has ## Evidence + 14 SC labels ----------

grep -q '^## Evidence' "$LEDGER"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
  echo "OK: body has ## Evidence section"
else
  fail=$((fail + 1))
  echo "FAIL: body missing ## Evidence section"
fi

# 14 distinct SC labels. Use word-boundary-aware patterns so SC-1 doesn't
# match SC-10/SC-11 substrings, SC-2 doesn't match SC-2a, etc.
# Each label is searched for as a literal token followed by a non-alphanumeric
# boundary (space, |, end-of-line, etc.) — grep -E with [^A-Za-z0-9].

check_sc_label() {
  local label="$1"
  if grep -Eq "${label}([^A-Za-z0-9]|$)" "$LEDGER"; then
    pass=$((pass + 1))
    echo "OK: body contains label ${label}"
  else
    fail=$((fail + 1))
    echo "FAIL: body missing label ${label}"
  fi
}

check_sc_label 'SC-1'
check_sc_label 'SC-2'
check_sc_label 'SC-2a'
check_sc_label 'SC-3'
check_sc_label 'SC-3a'
check_sc_label 'SC-4'
check_sc_label 'SC-5'
check_sc_label 'SC-6'
check_sc_label 'SC-7'
check_sc_label 'SC-7a'
check_sc_label 'SC-8'
check_sc_label 'SC-9'
check_sc_label 'SC-10'
check_sc_label 'SC-11'

# ---------- Check 4: every cited verifier path resolves on-disk ----------

# Extract all tools/verify/p<digits>-*.sh tokens from the ledger.
# Use grep -oE to pull each token; sort -u to dedupe; then check existence.

PATHS_FILE=$(mktemp -t p07-evidence-paths.XXXXXX)
PATHS_TRAP_FILE=$(mktemp -t p07-evidence-paths-trap.XXXXXX)
# Update trap to clean both
trap 'rm -f "$FM_FILE" "$PATHS_FILE" "$PATHS_TRAP_FILE"' EXIT

grep -oE 'tools/verify/p[0-9]+-[A-Za-z0-9_-]+\.sh' "$LEDGER" | sort -u > "$PATHS_FILE"

# Count entries (informational).
path_count=$(wc -l < "$PATHS_FILE" | tr -d ' ')

if [ "$path_count" -eq 0 ]; then
  fail=$((fail + 1))
  echo "FAIL: no tools/verify/p[0-9]+-*.sh paths found in ledger"
else
  echo "INFO: found $path_count distinct verifier paths in ledger"

  # Check each path's existence. Use a while-read loop fed by a file
  # (no pipe / no compound chain; AD-19-clean per assertion-body
  # carve-out).
  missing=0
  while IFS= read -r p; do
    if [ -z "$p" ]; then continue; fi
    if [ -f "$PROJECT_ROOT/$p" ]; then
      :
    else
      missing=$((missing + 1))
      echo "FAIL: cited verifier path does not exist: $p"
    fi
  done < "$PATHS_FILE"

  if [ "$missing" -eq 0 ]; then
    pass=$((pass + 1))
    echo "OK: every cited verifier path ($path_count distinct) resolves on-disk"
  else
    fail=$((fail + 1))
    echo "FAIL: $missing cited verifier paths missing on-disk"
  fi
fi

# ---------- Aggregate summary ----------

printf 'SUMMARY: p07-acceptance-evidence-ledger.sh pass=%s fail=%s\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi
