#!/usr/bin/env bash
set -eu
lib="scripts/lib/payload-transforms.sh"
test -f "$lib" || { echo "FAIL: $lib missing"; exit 1; }
grep -q '^estimate_tokens()' "$lib" || { echo "FAIL: estimate_tokens not defined in $lib"; exit 1; }
for ds in scripts/dispatch/build-context.sh scripts/dispatch/compress-payload.sh; do
  test -f "$ds" || { echo "FAIL: $ds missing"; exit 1; }
  if grep -q '^estimate_tokens()' "$ds"; then
    echo "FAIL: $ds still defines estimate_tokens locally"
    exit 1
  fi
done
echo "PASS: estimate_tokens defined once in $lib, not duplicated in dispatch scripts"
