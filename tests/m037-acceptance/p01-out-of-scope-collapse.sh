#!/usr/bin/env bash
# tests/m037-acceptance/p01-out-of-scope-collapse.sh — M037 P02 SC-16 acceptance.
#
# Exercises the FR-22a OUT-OF-SCOPE diagnostic-budget collapse in
# scripts/diagnostics/wiki-link-check.sh against three synthetic fixtures:
#
#   Case 1 (178-pages-same-target) — 178 pages each link to the same external
#     URL. Default run: ONE summary line `OUT-OF-SCOPE: 178 pages -> <url>
#     [external] (collapsed)`; zero per-page lines for that target.
#   Case 2 (178-pages-same-target with --verbose) — same fixture, --verbose
#     forwarded to wiki-link-check.sh: 178 separate per-page OUT-OF-SCOPE
#     lines emitted (collapse disabled).
#   Case 3 (mixed-targets) — 3 pages link to target A (small-fanout, < 5),
#     175 pages link to target B (high-fanout). Asserts target A emits per-
#     occurrence (within budget) and target B collapses to one summary line.
#   Case 4 (zero-oos) — single page with only in-scope links. Asserts NO
#     OUT-OF-SCOPE lines, NO summary lines emitted.
#
# Fixtures are built at test runtime under mktemp -d (cheaper than committing
# 178+ .html files to disk). Each fixture has the wiki/site/ subdirectory
# wiki-link-check.sh expects.
#
# Phase artifact contract: this file contains the literal string
# "(collapsed)" (M037 P02 plan must-have).
# Bash 3.2 + POSIX sh compatible. Single-script-file (AD-19).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

CHECK="$PROJECT_ROOT/scripts/diagnostics/wiki-link-check.sh"

pass=0
fail=0

ok() {
  printf 'PASS: %s\n' "$1"
  pass=$((pass + 1))
}

bad() {
  printf 'FAIL: %s\n' "$1"
  fail=$((fail + 1))
}

if [ ! -f "$CHECK" ]; then
  bad "wiki-link-check.sh missing at $CHECK"
  printf 'SUMMARY: p01-out-of-scope-collapse pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# Allocate a top-level tmpdir for all four fixtures.
WORK="$(mktemp -d -t m037-oos-collapse.XXXXXX)"
trap 'rm -rf "$WORK" 2>/dev/null' EXIT INT TERM

# Helper: write a minimal valid <article>-wrapped HTML page with one <a href>.
# Args: $1 = path to .html file; $2 = href value.
write_page() {
  _path="$1"
  _href="$2"
  mkdir -p "$(dirname "$_path")"
  {
    printf '%s\n' '<!DOCTYPE html>'
    printf '%s\n' '<html><body>'
    printf '%s\n' '<article>'
    printf '<a href="%s">link</a>\n' "$_href"
    printf '%s\n' '</article>'
    printf '%s\n' '</body></html>'
  } > "$_path"
}

# ---- Case 1: 178 pages -> same external URL, default (collapse on) ---------
F1="$WORK/178-pages-same-target/wiki/site"
mkdir -p "$F1"
TARGET1="https://github.com/Test-Org/Test-Repo/discussions"
i=1
while [ "$i" -le 178 ]; do
  # Three-digit zero-padded basename (p001 .. p178) for deterministic ordering.
  if [ "$i" -lt 10 ]; then
    n="00$i"
  elif [ "$i" -lt 100 ]; then
    n="0$i"
  else
    n="$i"
  fi
  write_page "$F1/p$n.html" "$TARGET1"
  i=$((i + 1))
done

OUT1="$WORK/case1.out"
bash "$CHECK" --site "$F1" > "$OUT1" 2>/dev/null
EC1=$?

if [ "$EC1" -ne 0 ]; then
  bad "case1: wiki-link-check.sh exit code $EC1 (expected 0)"
else
  ok "case1: wiki-link-check.sh exit code 0"
fi

# Expect exactly ONE summary line with shape:
#   OUT-OF-SCOPE: 178 pages -> <url> [external] (collapsed)
SUMMARY_COUNT_1=$(grep -c '^OUT-OF-SCOPE: 178 pages -> .* (collapsed)$' "$OUT1" 2>/dev/null; true)
if [ "$SUMMARY_COUNT_1" -eq 1 ]; then
  ok "case1: exactly one OUT-OF-SCOPE summary line emitted"
else
  bad "case1: expected 1 summary line, got $SUMMARY_COUNT_1"
  printf '%s\n' '----- case1 stdout -----' >&2
  cat "$OUT1" >&2
  printf '%s\n' '------------------------' >&2
fi

# Expect ZERO per-page OUT-OF-SCOPE lines for target1 (collapse should have
# replaced them all).
PER_PAGE_COUNT_1=$(grep -c "^OUT-OF-SCOPE: .*\.html -> $TARGET1 " "$OUT1" 2>/dev/null; true)
if [ "$PER_PAGE_COUNT_1" -eq 0 ]; then
  ok "case1: zero per-page OUT-OF-SCOPE lines for collapsed target"
else
  bad "case1: expected 0 per-page lines for $TARGET1, got $PER_PAGE_COUNT_1"
fi

# Verify the count in the summary line matches 178.
COUNT_FIELD_1=$(grep '^OUT-OF-SCOPE:' "$OUT1" | grep '(collapsed)' | head -n 1 \
  | awk '{print $2}')
if [ "$COUNT_FIELD_1" = "178" ]; then
  ok "case1: collapsed-summary count = 178"
else
  bad "case1: collapsed-summary count != 178 (got '$COUNT_FIELD_1')"
fi

# ---- Case 2: same fixture, --verbose disables collapse ---------------------
OUT2="$WORK/case2.out"
bash "$CHECK" --site "$F1" --verbose > "$OUT2" 2>/dev/null
EC2=$?
if [ "$EC2" -ne 0 ]; then
  bad "case2: wiki-link-check.sh --verbose exit code $EC2 (expected 0)"
else
  ok "case2: wiki-link-check.sh --verbose exit code 0"
fi

# Expect 178 per-page OUT-OF-SCOPE lines for target1 (collapse disabled).
PER_PAGE_COUNT_2=$(grep -c "^OUT-OF-SCOPE: .*\.html -> $TARGET1 " "$OUT2" 2>/dev/null; true)
if [ "$PER_PAGE_COUNT_2" -eq 178 ]; then
  ok "case2 (--verbose): 178 per-page OUT-OF-SCOPE lines emitted"
else
  bad "case2 (--verbose): expected 178 per-page lines, got $PER_PAGE_COUNT_2"
fi

# Expect ZERO collapsed-summary lines under --verbose.
SUMMARY_COUNT_2=$(grep -c '(collapsed)' "$OUT2" 2>/dev/null; true)
if [ "$SUMMARY_COUNT_2" -eq 0 ]; then
  ok "case2 (--verbose): zero collapsed-summary lines"
else
  bad "case2 (--verbose): expected 0 collapsed-summary lines, got $SUMMARY_COUNT_2"
fi

# ---- Case 3: mixed-targets ---------------------------------------------------
F3="$WORK/mixed-targets/wiki/site"
mkdir -p "$F3"
TARGET_A="https://example.com/small-fanout"
TARGET_B="https://example.com/high-fanout"
# 3 pages -> TARGET_A (small-fanout)
i=1
while [ "$i" -le 3 ]; do
  write_page "$F3/a$i.html" "$TARGET_A"
  i=$((i + 1))
done
# 175 pages -> TARGET_B (high-fanout)
i=1
while [ "$i" -le 175 ]; do
  if [ "$i" -lt 10 ]; then
    n="00$i"
  elif [ "$i" -lt 100 ]; then
    n="0$i"
  else
    n="$i"
  fi
  write_page "$F3/b$n.html" "$TARGET_B"
  i=$((i + 1))
done

OUT3="$WORK/case3.out"
bash "$CHECK" --site "$F3" > "$OUT3" 2>/dev/null
EC3=$?
if [ "$EC3" -ne 0 ]; then
  bad "case3: wiki-link-check.sh exit code $EC3 (expected 0)"
else
  ok "case3: wiki-link-check.sh exit code 0"
fi

# Small-fanout (TARGET_A): expect 3 per-page lines (within BUDGET=5).
PER_PAGE_A=$(grep -c "^OUT-OF-SCOPE: .*\.html -> $TARGET_A " "$OUT3" 2>/dev/null; true)
if [ "$PER_PAGE_A" -eq 3 ]; then
  ok "case3: small-fanout target emits 3 per-page lines"
else
  bad "case3: expected 3 per-page lines for small-fanout target, got $PER_PAGE_A"
fi

# High-fanout (TARGET_B): expect ONE collapsed-summary line and ZERO per-page lines.
SUMMARY_B=$(grep -c "^OUT-OF-SCOPE: 175 pages -> $TARGET_B .* (collapsed)$" "$OUT3" 2>/dev/null; true)
if [ "$SUMMARY_B" -eq 1 ]; then
  ok "case3: high-fanout target collapses to one summary line"
else
  bad "case3: expected 1 collapsed-summary line for high-fanout target, got $SUMMARY_B"
fi

PER_PAGE_B=$(grep -c "^OUT-OF-SCOPE: .*\.html -> $TARGET_B " "$OUT3" 2>/dev/null; true)
if [ "$PER_PAGE_B" -eq 0 ]; then
  ok "case3: zero per-page lines for high-fanout target"
else
  bad "case3: expected 0 per-page lines for high-fanout target, got $PER_PAGE_B"
fi

# ---- Case 4: zero-oos -------------------------------------------------------
F4="$WORK/zero-oos/wiki/site"
mkdir -p "$F4"
# Page p001 links only to a same-page anchor target that exists on the page.
{
  printf '%s\n' '<!DOCTYPE html>'
  printf '%s\n' '<html><body>'
  printf '%s\n' '<article>'
  printf '%s\n' '<h2 id="section-a">Section A</h2>'
  printf '%s\n' '<a href="#section-a">link</a>'
  printf '%s\n' '</article>'
  printf '%s\n' '</body></html>'
} > "$F4/p001.html"

OUT4="$WORK/case4.out"
bash "$CHECK" --site "$F4" > "$OUT4" 2>/dev/null
EC4=$?
if [ "$EC4" -ne 0 ]; then
  bad "case4 (zero-oos): wiki-link-check.sh exit code $EC4 (expected 0)"
else
  ok "case4 (zero-oos): wiki-link-check.sh exit code 0"
fi

# Expect ZERO OUT-OF-SCOPE lines and ZERO collapsed-summary lines.
OOS_COUNT_4=$(grep -c '^OUT-OF-SCOPE:' "$OUT4" 2>/dev/null; true)
if [ "$OOS_COUNT_4" -eq 0 ]; then
  ok "case4 (zero-oos): no OUT-OF-SCOPE lines emitted (silent-on-empty)"
else
  bad "case4 (zero-oos): expected 0 OUT-OF-SCOPE lines, got $OOS_COUNT_4"
  printf '%s\n' '----- case4 stdout -----' >&2
  cat "$OUT4" >&2
  printf '%s\n' '------------------------' >&2
fi

COLLAPSED_4=$(grep -c '(collapsed)' "$OUT4" 2>/dev/null; true)
if [ "$COLLAPSED_4" -eq 0 ]; then
  ok "case4 (zero-oos): no collapsed-summary lines emitted"
else
  bad "case4 (zero-oos): expected 0 collapsed-summary lines, got $COLLAPSED_4"
fi

printf 'SUMMARY: p01-out-of-scope-collapse pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
printf 'PASS: m037-p02-out-of-scope-collapse\n'
exit 0
