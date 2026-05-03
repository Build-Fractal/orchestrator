#!/usr/bin/env bash
# tools/verify/m036-p01-probe-shape.sh -- M036 P01 host-tool probe shape
# verifier. Invokes scripts/lifecycle/probe-extraction-tools.sh and asserts
# its stdout contains four canonical anchor strings (one per probed tool
# plus the SUMMARY line). Probe is informational; this verifier only
# checks the output shape, not tool presence. Single-script-file shape
# per AD-19 / AP-009 -- four discrete grep -q calls, no piped chains.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
TMP="${TMPDIR:-/tmp}/m036-p01-probe-shape.$$.out"
trap 'rm -f "$TMP"' EXIT

bash "$ROOT/scripts/lifecycle/probe-extraction-tools.sh" >"$TMP" 2>/dev/null

pass=0
fail=0

check_anchor() {
  local label="$1"
  local pattern="$2"
  if grep -q "$pattern" "$TMP"; then
    echo "PASS: probe-output-contains-${label}"
    pass=$((pass + 1))
  else
    echo "FAIL: probe-output-contains-${label}"
    fail=$((fail + 1))
  fi
}

check_anchor pdftotext "^pdftotext:"
check_anchor pandoc    "^pandoc:"
check_anchor openpyxl  "^openpyxl:"
check_anchor summary   "^SUMMARY: probe "

echo "SUMMARY: m036-p01-probe-shape pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
