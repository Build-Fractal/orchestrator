#!/usr/bin/env bash
# m043-p03-giscus-bytestable.sh — SC-8 (FR-12). The giscus partial is byte-stable
# on both deploy targets; M043 introduces no giscus change. Diffs the live
# wiki/overrides/partials/comments.html against the captured golden (exit 0).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2
LIVE="wiki/overrides/partials/comments.html"
GOLD="tests/fixtures/m043-p03/giscus-comments.golden.html"
fail=0
check() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }

[ -f "$LIVE" ]; check "giscus partial exists" $?
[ -f "$GOLD" ]; check "giscus golden exists" $?

if diff -u "$GOLD" "$LIVE" >/dev/null 2>&1; then d=0; else d=1; fi
[ "$d" -eq 0 ]
check "comments.html is byte-identical to the golden (no M043 giscus change)" $?

echo "SUMMARY: m043-p03-giscus-bytestable.sh fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
