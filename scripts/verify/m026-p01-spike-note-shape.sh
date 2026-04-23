#!/usr/bin/env bash
# m026-p01-spike-note-shape.sh
# Asserts: SPIKE-SYNTHESIS-CRUX.md exists, carries the required frontmatter
# keys with correct values, exposes the four required body sections (Method,
# Findings, Verdict, Rationale), and the Verdict section contains exactly
# one line matching `Verdict: GO` or `Verdict: NO-GO` (no MAYBE / INCONCLUSIVE
# / PARTIAL — DC-6 verdict vocabulary is binary by design).
# Bash 3.2 safe (MEM001). Single-script-file shape per AD-19.

set -euo pipefail

SPIKE=".orchestrator/milestones/M026/phases/P01/SPIKE-SYNTHESIS-CRUX.md"
PASS=0
FAIL=0

check_exists() {
  if [ ! -f "$SPIKE" ]; then
    echo "FAIL: spike report file not found at $SPIKE"
    FAIL=$((FAIL + 1))
    return 1
  fi
  echo "PASS: spike report file exists at $SPIKE"
  PASS=$((PASS + 1))
  return 0
}

check_frontmatter_key() {
  key="$1"
  expected="$2"
  actual=""
  actual=$(grep -E "^${key}:" "$SPIKE" | head -n 1 | sed -E "s/^${key}:[[:space:]]*//;s/[[:space:]]*$//")
  if [ "$actual" = "$expected" ]; then
    echo "PASS: frontmatter ${key} = ${expected}"
    PASS=$((PASS + 1))
    return 0
  fi
  echo "FAIL: frontmatter ${key} expected '${expected}' got '${actual}'"
  FAIL=$((FAIL + 1))
  return 1
}

check_section_present() {
  section="$1"
  if grep -qE "^## ${section}\$" "$SPIKE"; then
    echo "PASS: body section '## ${section}' present"
    PASS=$((PASS + 1))
    return 0
  fi
  echo "FAIL: body section '## ${section}' missing"
  FAIL=$((FAIL + 1))
  return 1
}

check_verdict_line() {
  # Exactly one line in the document must match `^Verdict: GO$` or
  # `^Verdict: NO-GO$`. Any other Verdict-prefix shape fails.
  go_count=0
  nogo_count=0
  bad_count=0
  go_count=$(grep -cE '^Verdict: GO$' "$SPIKE" || true)
  nogo_count=$(grep -cE '^Verdict: NO-GO$' "$SPIKE" || true)
  bad_count=$(grep -cE '^Verdict: (MAYBE|INCONCLUSIVE|PARTIAL)' "$SPIKE" || true)
  total=$((go_count + nogo_count))
  if [ "$bad_count" != "0" ]; then
    echo "FAIL: forbidden Verdict vocabulary present (MAYBE/INCONCLUSIVE/PARTIAL count=${bad_count})"
    FAIL=$((FAIL + 1))
    return 1
  fi
  if [ "$total" = "1" ]; then
    echo "PASS: exactly one Verdict line present (GO=${go_count} NO-GO=${nogo_count})"
    PASS=$((PASS + 1))
    return 0
  fi
  echo "FAIL: expected exactly one Verdict line, got GO=${go_count} NO-GO=${nogo_count}"
  FAIL=$((FAIL + 1))
  return 1
}

# Run all checks. Failures do not short-circuit — we want a full SUMMARY.
check_exists || true
check_frontmatter_key "schema_version" '"1.0"' || true
check_frontmatter_key "type" "spike-report" || true
check_frontmatter_key "phase" '"P01"' || true
check_frontmatter_key "task" '"T02"' || true
check_frontmatter_key "milestone" '"M026"' || true
check_frontmatter_key "status" "final" || true
check_section_present "Method" || true
check_section_present "Findings" || true
check_section_present "Verdict" || true
check_section_present "Rationale" || true
check_verdict_line || true

echo "SUMMARY: pass=${PASS} fail=${FAIL}"
if [ "$FAIL" -gt "0" ]; then
  exit 1
fi
exit 0
