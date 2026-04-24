#!/usr/bin/env bash
# tests/test-dual-write-append-entry.sh — Issue #6 regression test
#
# Issue #6: dual-write-runtime-md.sh's only mode was --content <path>,
# which REPLACES the entire region body. Every caller (M026/P01,
# M026/P02, bbt-companion dogfood) had to read existing region content,
# rebuild it with the new entry, and pass the whole thing back. T05's
# first attempt missed an entry and had to re-dual-write to recover.
#
# Fix: --append-entry "<text>" prepends the new entry above existing
# region body without forcing the caller to reconstruct anything.
# Reverse-chronological by design.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DUAL_WRITE="$PROJECT_ROOT/scripts/util/dual-write-runtime-md.sh"
WORK="$(mktemp -d)"

PASS_COUNT=0
FAIL_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL: $1"; }

cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

mkdir -p "$WORK/.orchestrator"
printf '# Test\n' > "$WORK/CLAUDE.md"

# --- Test 1: append into a fresh file → marker region created with the entry ---
bash "$DUAL_WRITE" --root "$WORK" --marker test --append-entry "first entry" --file CLAUDE.md >/dev/null
expected_1='# >>> orchestrator:test >>>
first entry
# <<< orchestrator:test <<<
# Test'
actual_1=$(cat "$WORK/CLAUDE.md")
if [[ "$actual_1" = "$expected_1" ]]; then
  pass "first --append-entry creates region above first heading"
else
  fail "first --append-entry layout (got: $actual_1)"
fi

# --- Test 2: subsequent --append-entry calls prepend (reverse-chronological) ---
bash "$DUAL_WRITE" --root "$WORK" --marker test --append-entry "second entry" --file CLAUDE.md >/dev/null
bash "$DUAL_WRITE" --root "$WORK" --marker test --append-entry "third entry" --file CLAUDE.md >/dev/null
expected_3='# >>> orchestrator:test >>>
third entry
second entry
first entry
# <<< orchestrator:test <<<
# Test'
actual_3=$(cat "$WORK/CLAUDE.md")
if [[ "$actual_3" = "$expected_3" ]]; then
  pass "subsequent --append-entry prepends (reverse-chronological)"
else
  fail "subsequent --append-entry order (got: $actual_3)"
fi

# --- Test 3: --content and --append-entry are mutually exclusive ---
err=$(mktemp)
content_file=$(mktemp)
printf 'replacement\n' > "$content_file"
if bash "$DUAL_WRITE" --root "$WORK" --marker test --content "$content_file" --append-entry "x" --file CLAUDE.md 2>"$err"; then
  fail "--content + --append-entry should exit non-zero"
else
  if grep -q "mutually exclusive" "$err"; then
    pass "--content + --append-entry rejected as mutually exclusive"
  else
    fail "--content + --append-entry rejection message (got: $(cat "$err"))"
  fi
fi
rm -f "$err" "$content_file"

# --- Test 4: --content mode unchanged (replace) ---
content_file=$(mktemp)
printf 'replaced body\n' > "$content_file"
bash "$DUAL_WRITE" --root "$WORK" --marker test --content "$content_file" --file CLAUDE.md >/dev/null
expected_replace='# >>> orchestrator:test >>>
replaced body
# <<< orchestrator:test <<<
# Test'
actual_replace=$(cat "$WORK/CLAUDE.md")
if [[ "$actual_replace" = "$expected_replace" ]]; then
  pass "--content mode still replaces entire region"
else
  fail "--content mode replace (got: $actual_replace)"
fi
rm -f "$content_file"

# --- Test 5: append into a region that doesn't exist yet on a file with markers absent ---
printf '# Other\nbody\n' > "$WORK/CLAUDE.md"
bash "$DUAL_WRITE" --root "$WORK" --marker fresh --append-entry "fresh-entry" --file CLAUDE.md >/dev/null
if grep -q '^fresh-entry$' "$WORK/CLAUDE.md" && grep -qF '# >>> orchestrator:fresh >>>' "$WORK/CLAUDE.md"; then
  pass "append-entry inserts new region with single entry into existing file"
else
  fail "append-entry on absent region (got: $(cat "$WORK/CLAUDE.md"))"
fi

# --- Test 6: missing --content and --append-entry → error ---
err=$(mktemp)
if bash "$DUAL_WRITE" --root "$WORK" --marker x --file CLAUDE.md 2>"$err"; then
  fail "missing --content/--append-entry should exit non-zero"
else
  if grep -q "missing --content or --append-entry" "$err"; then
    pass "missing --content/--append-entry emits specific message"
  else
    fail "missing --content/--append-entry message (got: $(cat "$err"))"
  fi
fi
rm -f "$err"

echo "----"
echo "PASS: $PASS_COUNT  FAIL: $FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
