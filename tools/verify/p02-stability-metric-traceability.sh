#!/usr/bin/env bash
# tools/verify/p02-stability-metric-traceability.sh — M030/P02/T03
#
# Asserts that the pinned classifier-confidence stability-metric numerics
# (0.10 / 20 / 50) appearing in scripts/diagnostics/shadow-compare.sh are
# accompanied by an inline reference to the SSOT (references/model-routing.md
# / model-routing / Classifier-Confidence Stability Metric). Loose-coupled
# numerics drifting away from the doc would be a CON-3-class governance
# violation.
#
# Per-numeric scoping:
#   0.10 — variance threshold; matches anywhere in the file.
#   20   — rolling window; restricted to lines also containing
#          WINDOW/window/ROLLING/rolling.
#   50   — class coverage minimum; restricted to lines also containing
#          COVERAGE/coverage/CLASS/class.
#
# Bash 3.2 compatible. AD-19 single-script-file shape.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET="$REPO_ROOT/scripts/diagnostics/shadow-compare.sh"

pass=0
fail=0

if [ ! -f "$TARGET" ]; then
  fail=$((fail + 1))
  printf 'FAIL: target script missing at %s\n' "$TARGET"
  printf 'SUMMARY: p02-stability-metric-traceability.sh pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# SSOT-naming pattern: any of these strings on the same line counts as
# a traceability anchor.
SSOT_PATTERN='references/model-routing\.md|model-routing|Classifier-Confidence Stability Metric'

# Tmp files for the per-numeric in-scope match sets.
M010_TMP="/tmp/p02-stability-010.txt"
M20_TMP="/tmp/p02-stability-20.txt"
M50_TMP="/tmp/p02-stability-50.txt"
SSOT_010_TMP="/tmp/p02-stability-010-ssot.txt"
SSOT_20_TMP="/tmp/p02-stability-20-ssot.txt"
SSOT_50_TMP="/tmp/p02-stability-50-ssot.txt"

cleanup() {
  rm -f "$M010_TMP" "$M20_TMP" "$M50_TMP" \
        "$SSOT_010_TMP" "$SSOT_20_TMP" "$SSOT_50_TMP" 2>/dev/null
}
trap cleanup EXIT

# ---------- Numeric 0.10 (variance threshold) ----------
grep -n '0\.10' "$TARGET" > "$M010_TMP" 2>/dev/null
total_010="$(wc -l < "$M010_TMP" | tr -d ' ')"
grep -E "$SSOT_PATTERN" "$M010_TMP" > "$SSOT_010_TMP" 2>/dev/null
ssot_010="$(wc -l < "$SSOT_010_TMP" | tr -d ' ')"

if [ "$total_010" -eq 0 ]; then
  fail=$((fail + 1))
  printf 'FAIL: numeric 0.10 not found in %s\n' "$TARGET"
elif [ "$ssot_010" -eq "$total_010" ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: numeric 0.10 — %d total occurrences, %d SSOT-traceable; non-traceable lines:\n' "$total_010" "$ssot_010"
  grep -v -E "$SSOT_PATTERN" "$M010_TMP"
fi

# ---------- Numeric 20 (rolling window) ----------
# Restrict to lines containing WINDOW/window/ROLLING/rolling AND the literal `20`.
# We use awk to apply both predicates on the LINE CONTENT (not the line-number
# prefix that grep -n would otherwise emit).
awk '
  /WINDOW|window|ROLLING|rolling/ && /20/ { printf "%d:%s\n", NR, $0 }
' "$TARGET" > "$M20_TMP" 2>/dev/null
total_20="$(wc -l < "$M20_TMP" | tr -d ' ')"
grep -E "$SSOT_PATTERN" "$M20_TMP" > "$SSOT_20_TMP" 2>/dev/null
ssot_20="$(wc -l < "$SSOT_20_TMP" | tr -d ' ')"

if [ "$total_20" -eq 0 ]; then
  fail=$((fail + 1))
  printf 'FAIL: numeric 20 (rolling window) not found in %s\n' "$TARGET"
elif [ "$ssot_20" -eq "$total_20" ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: numeric 20 — %d in-scope occurrences, %d SSOT-traceable; non-traceable lines:\n' "$total_20" "$ssot_20"
  grep -v -E "$SSOT_PATTERN" "$M20_TMP"
fi

# ---------- Numeric 50 (class coverage minimum) ----------
awk '
  /COVERAGE|coverage|CLASS|class/ && /50/ { printf "%d:%s\n", NR, $0 }
' "$TARGET" > "$M50_TMP" 2>/dev/null
total_50="$(wc -l < "$M50_TMP" | tr -d ' ')"
grep -E "$SSOT_PATTERN" "$M50_TMP" > "$SSOT_50_TMP" 2>/dev/null
ssot_50="$(wc -l < "$SSOT_50_TMP" | tr -d ' ')"

if [ "$total_50" -eq 0 ]; then
  fail=$((fail + 1))
  printf 'FAIL: numeric 50 (class coverage) not found in %s\n' "$TARGET"
elif [ "$ssot_50" -eq "$total_50" ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: numeric 50 — %d in-scope occurrences, %d SSOT-traceable; non-traceable lines:\n' "$total_50" "$ssot_50"
  grep -v -E "$SSOT_PATTERN" "$M50_TMP"
fi

printf 'SUMMARY: p02-stability-metric-traceability.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
