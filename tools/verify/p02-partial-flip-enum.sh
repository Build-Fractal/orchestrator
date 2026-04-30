#!/usr/bin/env bash
# tools/verify/p02-partial-flip-enum.sh — M030/P02/T03
#
# Validates D-A3 partial_flip enumeration + safety constraint:
#   - shadow-compare.sh against shadow-corpus-partially-ready.jsonl emits
#     ^flip_recommendation=partially_ready$ AND ^withheld_classes=...$.
#   - withheld_classes contains `novel` and not `mechanical` / `standard`.
#   - The under-threshold class's routing-table default is `smart`
#     (D-A3 safety: only `smart`-defaulted classes may be withheld).
#
# Bash 3.2 compatible. AD-19 single-script-file shape.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/diagnostics/shadow-compare.sh"
FIXTURE="$REPO_ROOT/tests/fixtures/m030-p02/shadow-corpus-partially-ready.jsonl"
ROUTING_TABLE="$REPO_ROOT/templates/model-routing.yml"

OUT_TMP="/tmp/p02-partial-flip-stdout.txt"
WITHHELD_TMP="/tmp/p02-withheld.txt"
DEFAULT_TIER_TMP="/tmp/p02-default-tier.txt"

pass=0
fail=0

cleanup() {
  rm -f "$OUT_TMP" "$WITHHELD_TMP" "$DEFAULT_TIER_TMP" 2>/dev/null
}
trap cleanup EXIT

if [ ! -f "$FIXTURE" ]; then
  fail=$((fail + 1))
  printf 'FAIL: fixture missing at %s\n' "$FIXTURE"
  printf 'SUMMARY: p02-partial-flip-enum.sh pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

bash "$SCRIPT" --corpus "$FIXTURE" > "$OUT_TMP" 2>/dev/null
rc=$?
if [ "$rc" -ne 0 ]; then
  fail=$((fail + 1))
  printf 'FAIL: shadow-compare.sh exited %d (expected 0)\n' "$rc"
  printf 'SUMMARY: p02-partial-flip-enum.sh pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# Gate 1: ^flip_recommendation=partially_ready$ present.
grep -q '^flip_recommendation=partially_ready$' "$OUT_TMP"
if [ $? -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: expected ^flip_recommendation=partially_ready$ on stdout\n'
fi

# Gate 2: ^withheld_classes= line present.
grep -q '^withheld_classes=' "$OUT_TMP"
if [ $? -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: expected ^withheld_classes= on stdout\n'
fi

# Extract withheld list.
grep '^withheld_classes=' "$OUT_TMP" | head -1 | sed 's/^withheld_classes=//' > "$WITHHELD_TMP"

# Gate 3: withheld list contains `novel`.
grep -q 'novel' "$WITHHELD_TMP"
if [ $? -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: withheld_classes does not contain `novel`\n'
fi

# Gate 4: withheld list does NOT contain `mechanical`.
grep -q 'mechanical' "$WITHHELD_TMP"
if [ $? -ne 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: withheld_classes unexpectedly contains `mechanical`\n'
fi

# Gate 5: withheld list does NOT contain `standard`.
grep -q 'standard' "$WITHHELD_TMP"
if [ $? -ne 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: withheld_classes unexpectedly contains `standard`\n'
fi

# Gate 6: D-A3 safety — under-threshold class (novel) has routing default `smart`.
awk '
  BEGIN { in_routing = 0; in_class = 0 }
  /^routing:/                       { in_routing = 1; next }
  /^resolution:/                    { exit }
  in_routing && /^  [a-z_]+:$/      { in_class = ($1 == "novel:") ? 1 : 0; next }
  in_routing && in_class && /^    claude-code:/ {
    val = $2; gsub(/[",]/, "", val); print val; exit
  }
' "$ROUTING_TABLE" > "$DEFAULT_TIER_TMP"
default_tier="$(cat "$DEFAULT_TIER_TMP")"
if [ "$default_tier" = "smart" ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: routing.novel.claude-code expected `smart`; got `%s` (D-A3 safety violated)\n' "$default_tier"
fi

printf 'SUMMARY: p02-partial-flip-enum.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
