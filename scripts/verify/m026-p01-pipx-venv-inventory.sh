#!/usr/bin/env bash
# m026-p01-pipx-venv-inventory.sh
# Asserts: OLLAMA-PROBE.md's Pipx venvs block contains both `oss_venv_path=`
# and `paid_venv_path=` lines with non-empty values (either a real path OR
# the literal string N/A), and the four `_present` lines carry exactly
# `true` or `false` literally (no empty strings, no alternative vocabulary).
# Bash 3.2 safe (MEM001). Single-script-file shape per AD-19.

set -euo pipefail

PROBE=".orchestrator/milestones/M026/phases/P01/OLLAMA-PROBE.md"
PASS=0
FAIL=0

check_exists() {
  if [ ! -f "$PROBE" ]; then
    echo "FAIL: probe report file not found at $PROBE"
    FAIL=$((FAIL + 1))
    return 1
  fi
  echo "PASS: probe report file exists at $PROBE"
  PASS=$((PASS + 1))
  return 0
}

check_path_line_nonempty() {
  # Value after `<key>=` must be non-empty. A value of `N/A` is explicitly
  # allowed per the task plan ("Absent editions record N/A on the path line").
  key="$1"
  actual=""
  actual=$(grep -E "^${key}=" "$PROBE" | head -n 1 | sed -E "s/^${key}=//;s/[[:space:]]*$//")
  if [ -z "$actual" ]; then
    echo "FAIL: ${key} value is empty (must be a path or the literal 'N/A')"
    FAIL=$((FAIL + 1))
    return 1
  fi
  echo "PASS: ${key} value present = '${actual}'"
  PASS=$((PASS + 1))
  return 0
}

check_boolean_line() {
  # Value after `<key>=` must be exactly `true` or `false`.
  key="$1"
  actual=""
  actual=$(grep -E "^${key}=" "$PROBE" | head -n 1 | sed -E "s/^${key}=//;s/[[:space:]]*$//")
  case "$actual" in
    true|false)
      echo "PASS: ${key}=${actual} (boolean literal)"
      PASS=$((PASS + 1))
      return 0
      ;;
    *)
      echo "FAIL: ${key}='${actual}' not in {true,false}"
      FAIL=$((FAIL + 1))
      return 1
      ;;
  esac
}

# Run all checks. Failures do not short-circuit — we want a full SUMMARY.
check_exists || true
check_path_line_nonempty "oss_venv_path" || true
check_path_line_nonempty "paid_venv_path" || true
check_boolean_line "oss_venv_python_present" || true
check_boolean_line "oss_venv_conversus_binary_present" || true
check_boolean_line "paid_venv_python_present" || true
check_boolean_line "paid_venv_conversus_binary_present" || true

echo "SUMMARY: pass=${PASS} fail=${FAIL}"
if [ "$FAIL" -gt "0" ]; then
  exit 1
fi
exit 0
