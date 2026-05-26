#!/usr/bin/env bash
# tools/verify/m041-p06-match-threshold.sh
# Verifies detective.match_threshold resolves via config and search-issues.sh
# emits a meets_threshold boolean per result driven by it.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

val="$(bash scripts/state/read-config.sh detective.match_threshold 2>/dev/null)"
if [ "$val" != "3" ]; then
  echo "FAIL: read-config.sh detective.match_threshold returned '$val' (expected 3)"
  exit 1
fi

# A strong-match query against the mock issue #42 must yield meets_threshold:true;
# the default threshold (3) is met by a 4-keyword overlap.
out="$(GH_MOCK_DIR=tests/fixtures/detective/gh-mock \
  bash scripts/diagnostics/search-issues.sh --query "scaffold exits milestone dir" 2>/dev/null)"
case "$out" in
  *'"meets_threshold": true'*|*'"meets_threshold":true'*) : ;;
  *) echo "FAIL: search-issues.sh did not emit meets_threshold:true for a strong match"; exit 1 ;;
esac

# An explicit high --threshold must flip the same hit to meets_threshold:false
out_hi="$(GH_MOCK_DIR=tests/fixtures/detective/gh-mock \
  bash scripts/diagnostics/search-issues.sh --query "scaffold exits milestone dir" --threshold 99 2>/dev/null)"
case "$out_hi" in
  *'"meets_threshold": true'*|*'"meets_threshold":true'*)
    echo "FAIL: --threshold 99 should have set meets_threshold:false for all hits"; exit 1 ;;
  *) : ;;
esac
echo "PASS: match_threshold resolves via config and drives meets_threshold"
