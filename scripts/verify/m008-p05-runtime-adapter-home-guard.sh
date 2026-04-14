#!/usr/bin/env bash
# Verifies runtime adapters reject --register when HOME is unset or "/".
set -u

ADAPTERS=(
  "scripts/dispatch/adapters/runtime/claude-code.sh"
  "scripts/dispatch/adapters/runtime/codex.sh"
)

for a in "${ADAPTERS[@]}"; do
  if [[ ! -f "$a" ]]; then
    echo "FAIL: $a missing"
    exit 1
  fi

  # HOME=/ should be rejected.
  out="$(HOME="/" bash "$a" --register 2>&1)"
  rc=$?
  if [[ $rc -eq 0 ]]; then
    echo "FAIL: $a accepted HOME=/ (must refuse)"
    exit 1
  fi
  if ! echo "$out" | grep -qiE 'FAIL|unsafe|refuse|invalid'; then
    echo "FAIL: $a HOME=/ did not emit a FAIL/unsafe message"
    echo "---OUTPUT---"
    echo "$out"
    exit 1
  fi

  # HOME empty should also be rejected.
  out="$(HOME="" bash "$a" --register 2>&1)"
  rc=$?
  if [[ $rc -eq 0 ]]; then
    echo "FAIL: $a accepted empty HOME (must refuse)"
    exit 1
  fi
done

echo "PASS: runtime adapters guard against HOME=/ and empty HOME"
