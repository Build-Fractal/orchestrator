#!/usr/bin/env bash
# m026-p01-ollama-probe.sh
# Asserts: OLLAMA-PROBE.md exists, carries the required frontmatter keys
# with correct values, exposes the mandatory `result=` + ollama path/version
# + models_present lines, contains the six pipx `oss_venv_*` + `paid_venv_*`
# lines (path + python_present + conversus_binary_present for each edition),
# and the `FR-8 OSS-branch provider:` posture line. Result vocabulary is
# enforced: result= must be one of {available, absent, skipped-operator-choice}.
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

check_frontmatter_key() {
  key="$1"
  expected="$2"
  actual=""
  actual=$(grep -E "^${key}:" "$PROBE" | head -n 1 | sed -E "s/^${key}:[[:space:]]*//;s/[[:space:]]*$//")
  if [ "$actual" = "$expected" ]; then
    echo "PASS: frontmatter ${key} = ${expected}"
    PASS=$((PASS + 1))
    return 0
  fi
  echo "FAIL: frontmatter ${key} expected '${expected}' got '${actual}'"
  FAIL=$((FAIL + 1))
  return 1
}

check_line_present() {
  prefix="$1"
  if grep -qE "^${prefix}" "$PROBE"; then
    echo "PASS: line prefix '${prefix}' present"
    PASS=$((PASS + 1))
    return 0
  fi
  echo "FAIL: line prefix '${prefix}' missing"
  FAIL=$((FAIL + 1))
  return 1
}

check_result_vocabulary() {
  # result= must be exactly one of {available, absent, skipped-operator-choice}
  actual=""
  actual=$(grep -E "^result=" "$PROBE" | head -n 1 | sed -E "s/^result=//;s/[[:space:]]*$//")
  case "$actual" in
    available|absent|skipped-operator-choice)
      echo "PASS: result= value '${actual}' is in fixed vocabulary"
      PASS=$((PASS + 1))
      return 0
      ;;
    *)
      echo "FAIL: result= value '${actual}' not in {available, absent, skipped-operator-choice}"
      FAIL=$((FAIL + 1))
      return 1
      ;;
  esac
}

check_fr8_provider_line() {
  # The P02 fallback posture section must carry a bullet naming the FR-8
  # OSS-branch provider call. Match both leading-dash and leading-whitespace
  # markdown bullet shapes.
  if grep -qE "FR-8 OSS-branch provider:" "$PROBE"; then
    echo "PASS: 'FR-8 OSS-branch provider:' line present"
    PASS=$((PASS + 1))
    return 0
  fi
  echo "FAIL: 'FR-8 OSS-branch provider:' line missing"
  FAIL=$((FAIL + 1))
  return 1
}

# Run all checks. Failures do not short-circuit — we want a full SUMMARY.
check_exists || true
check_frontmatter_key "schema_version" '"1.0"' || true
check_frontmatter_key "type" "probe-report" || true
check_frontmatter_key "phase" '"P01"' || true
check_frontmatter_key "task" '"T03"' || true
check_frontmatter_key "milestone" '"M026"' || true
check_line_present "result=" || true
check_line_present "ollama_path=" || true
check_line_present "ollama_version=" || true
check_line_present "models_present=" || true
check_line_present "oss_venv_path=" || true
check_line_present "oss_venv_python_present=" || true
check_line_present "oss_venv_conversus_binary_present=" || true
check_line_present "paid_venv_path=" || true
check_line_present "paid_venv_python_present=" || true
check_line_present "paid_venv_conversus_binary_present=" || true
check_result_vocabulary || true
check_fr8_provider_line || true

echo "SUMMARY: pass=${PASS} fail=${FAIL}"
if [ "$FAIL" -gt "0" ]; then
  exit 1
fi
exit 0
