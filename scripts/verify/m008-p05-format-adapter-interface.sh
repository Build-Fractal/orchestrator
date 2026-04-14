#!/usr/bin/env bash
# Verifies format adapters (native.sh, speckit.sh) support --probe and --read.
set -u

ADAPTERS=(
  "scripts/dispatch/adapters/format/native.sh"
  "scripts/dispatch/adapters/format/speckit.sh"
)

for a in "${ADAPTERS[@]}"; do
  if [[ ! -f "$a" ]]; then
    echo "FAIL: $a missing"
    exit 1
  fi
  if [[ ! -x "$a" ]]; then
    echo "FAIL: $a not executable"
    exit 1
  fi

  for flag in "--probe" "--read"; do
    if ! grep -qF -- "$flag" "$a"; then
      echo "FAIL: $a does not handle $flag"
      exit 1
    fi
  done

  out="$(bash "$a" --probe 2>/dev/null)"
  rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "FAIL: $a --probe exited $rc"
    exit 1
  fi
  if ! echo "$out" | grep -qE '^available='; then
    echo "FAIL: $a --probe missing available="
    exit 1
  fi
done

echo "PASS: format adapters implement --probe and --read"
