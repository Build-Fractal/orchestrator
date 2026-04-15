#!/usr/bin/env bash
set -eu
out=$(bash scripts/lifecycle/evaluate-preflight.sh . B 2>&1) || true
echo "$out" | grep -E 'permissions=(generated|merged)' >/dev/null || {
  echo "FAIL: preflight did not report permissions=generated or merged"
  echo "Got: $out"
  exit 1
}
echo "PASS: preflight reports permissions=generated or merged"
