#!/usr/bin/env bash
# tools/verify/p00-plans-exist.sh — M030/P00/T01 plan-path existence verifier.
#
# Extracts every `plan_path:` value from labels.yml and asserts that
# each path resolves to a regular file on disk. Emits `MISSING: <path>`
# per fail and a final SUMMARY line.
#
# Bash 3.2 compatible. AD-19 single-script-file shape.
# Override fixture path via $1.

set -u

FIXTURE="${1:-tests/fixtures/m030-classifier-corpus/labels.yml}"

if [ ! -f "$FIXTURE" ]; then
  printf 'FAIL: labels.yml missing at %s\n' "$FIXTURE"
  printf 'SUMMARY: p00-plans-exist.sh pass=0 fail=1\n'
  exit 1
fi

pass=0
fail=0

# Use awk to extract the quoted value after `  - plan_path:` lines.
# Single-line awk; no $() with pipes; Bash 3.2 safe.
PATHS_TMP="${TMPDIR:-/tmp}/p00-plans-exist.$$"
trap 'rm -f "$PATHS_TMP"' EXIT

awk -F'"' '/^  - plan_path:/ { print $2 }' "$FIXTURE" > "$PATHS_TMP"

while IFS= read -r p; do
  if [ -z "$p" ]; then
    continue
  fi
  if [ -f "$p" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'MISSING: %s\n' "$p"
  fi
done < "$PATHS_TMP"

printf 'SUMMARY: p00-plans-exist.sh pass=%s fail=%s\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi
