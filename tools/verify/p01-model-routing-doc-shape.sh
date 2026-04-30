#!/usr/bin/env bash
# tools/verify/p01-model-routing-doc-shape.sh — M030/P01/T03 doc-shape
# verifier for references/model-routing.md.
#
# Eight checks (5 section-presence + 3 numeric-threshold):
#   1. ## Routing Table heading present.
#   2. ## Per-Runtime Resolution heading present.
#   3. ## Cost Rates SSOT heading present.
#   4. ## Aggressive Overlay heading present.
#   5. ## Classifier-Confidence Stability Metric heading present.
#   6. Variance threshold "0.10" present somewhere in the file.
#   7. Rolling-window literal "N=20" present.
#   8. Coverage floor literal "50 dispatches" present.
#
# Bash 3.2 compatible. AD-19 single-script-file shape.
# Override target via $1.

set -u

TARGET="${1:-references/model-routing.md}"

pass=0
fail=0
fail_reasons=""

note_pass() {
  pass=$((pass + 1))
}

note_fail() {
  fail=$((fail + 1))
  fail_reasons="${fail_reasons}FAIL: $1
"
}

# ---------- File existence (precheck — not counted toward 8) ----------

if [ ! -f "$TARGET" ]; then
  printf 'FAIL: model-routing.md missing at %s\n' "$TARGET"
  printf 'SUMMARY: p01-model-routing-doc-shape.sh pass=0 fail=1\n'
  exit 1
fi

# ---------- Checks 1-5: required section headings ----------

sections_present=0
sections_missing=""

for heading in \
  '## Routing Table' \
  '## Per-Runtime Resolution' \
  '## Cost Rates SSOT' \
  '## Aggressive Overlay' \
  '## Classifier-Confidence Stability Metric'; do
  if grep -qF "$heading" "$TARGET"; then
    note_pass
    sections_present=$((sections_present + 1))
  else
    note_fail "required section missing: ${heading}"
    sections_missing="${sections_missing}${heading} | "
  fi
done

if [ "$sections_present" -eq 5 ]; then
  printf 'OK: all 5 required sections present\n'
fi

# ---------- Check 6: variance threshold 0.10 ----------

if grep -qF '0.10' "$TARGET"; then
  note_pass
else
  note_fail "variance threshold value '0.10' not found"
fi

# ---------- Check 7: rolling-window N=20 ----------

if grep -qF 'N=20' "$TARGET"; then
  note_pass
else
  note_fail "rolling-window literal 'N=20' not found"
fi

# ---------- Check 8: coverage floor 50 dispatches ----------

if grep -qF '50 dispatches' "$TARGET"; then
  note_pass
else
  note_fail "coverage-floor literal '50 dispatches' not found"
fi

if [ "$fail" -eq 0 ]; then
  printf 'OK: concrete numeric thresholds present (0.10 N=20 50 dispatches)\n'
fi

# ---------- Summary ----------

if [ "$fail" -eq 0 ]; then
  printf 'SUMMARY: p01-model-routing-doc-shape.sh pass=%s fail=%s\n' "$pass" "$fail"
  exit 0
else
  printf '%s' "$fail_reasons"
  printf 'SUMMARY: p01-model-routing-doc-shape.sh pass=%s fail=%s\n' "$pass" "$fail"
  exit 1
fi
