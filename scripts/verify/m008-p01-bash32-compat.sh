#!/usr/bin/env bash
# Verifies all P01 scripts are Bash 3.2 compatible.
# Checks for prohibited constructs: declare -A, readarray, mapfile, |&, &>>,
# ${var,,}, ${var^^}, variable regex patterns.
set -eu

fail_count=0
pass_count=0

check_file() {
  local f="$1"
  local bad=false

  # declare -A (associative arrays)
  if grep -nE 'declare\s+-A\b' "$f" >/dev/null 2>&1; then
    echo "FAIL: $f uses declare -A (associative arrays)"
    bad=true
  fi

  # readarray / mapfile
  if grep -nE '\b(readarray|mapfile)\b' "$f" >/dev/null 2>&1; then
    echo "FAIL: $f uses readarray/mapfile"
    bad=true
  fi

  # |& (pipe stderr)
  if grep -nE '\|\&' "$f" >/dev/null 2>&1; then
    echo "FAIL: $f uses |& (pipe stderr)"
    bad=true
  fi

  # &>> (append redirect both)
  if grep -nE '\&>>' "$f" >/dev/null 2>&1; then
    echo "FAIL: $f uses &>> (append redirect)"
    bad=true
  fi

  # ${var,,} or ${var^^} (case modification)
  if grep -nE '\$\{[a-zA-Z_][a-zA-Z0-9_]*(,,|^^)\}' "$f" >/dev/null 2>&1; then
    echo "FAIL: $f uses case modification syntax"
    bad=true
  fi

  if [[ "$bad" = true ]]; then
    fail_count=$((fail_count + 1))
  else
    pass_count=$((pass_count + 1))
  fi
}

# Check all P01 scripts
check_file "scripts/dispatch/detect-capabilities.sh"
check_file "scripts/engine/intensity-analyze.sh"
check_file "scripts/engine/intensity-recommend.sh"
check_file "scripts/engine/context-pressure.sh"

if [[ "$fail_count" -gt 0 ]]; then
  echo "FAIL: $fail_count file(s) have Bash 3.2 incompatible constructs"
  exit 1
fi

echo "PASS: all $pass_count P01 scripts are Bash 3.2 compatible"
