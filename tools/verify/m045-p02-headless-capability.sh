#!/usr/bin/env sh
# m045-p02-headless-capability.sh
# Checks detect-capabilities.sh emits a headless_reentry key in both formats.
set -eu
OUT=$(bash scripts/dispatch/detect-capabilities.sh 2>/dev/null)
echo "$OUT" | grep -q '^headless_reentry=' || { echo "FAIL: no headless_reentry in text output"; exit 1; }
JSON=$(bash scripts/dispatch/detect-capabilities.sh --format json 2>/dev/null)
echo "$JSON" | grep -q '"headless_reentry"' || { echo "FAIL: no headless_reentry in json output"; exit 1; }
echo "PASS: headless_reentry present in text + json"
