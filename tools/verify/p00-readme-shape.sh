#!/usr/bin/env bash
# tools/verify/p00-readme-shape.sh — M030/P00/T03 corpus README shape gate.
#
# Verifies the corpus README at
#   tests/fixtures/m030-classifier-corpus/README.md
# carries the four required section headings and the rubric
# vocabulary + classifier-name reference.
#
# Seven checks:
#   1. README file exists.
#   2. `## Source Pool` heading present.
#   3. `## Sampling Methodology` heading present.
#   4. `## Labeling Rubric` heading present.
#   5. `## D-A4 Independence Compliance` heading present.
#   6. Rubric vocabulary present (literal `mechanical`, `standard`,
#      `novel` all appear in the body).
#   7. Classifier filename `classify-task.sh` referenced (the D-A4
#      compliance section names the load-bearing future file).
#
# Bash 3.2 compatible. AD-19 single-script-file shape.
# Override README path via $1.

set -u

README="${1:-tests/fixtures/m030-classifier-corpus/README.md}"

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

# ---------- Check 1: README file exists ----------

if [ -f "$README" ]; then
  note_pass
else
  note_fail "README missing at ${README}"
  printf '%s' "$fail_reasons"
  printf 'SUMMARY: p00-readme-shape.sh pass=%s fail=%s\n' "$pass" "$fail"
  exit 1
fi

# ---------- Checks 2-5: required section headings ----------

if grep -q '^## Source Pool$' "$README"; then
  note_pass
else
  note_fail "missing heading: ## Source Pool"
fi

if grep -q '^## Sampling Methodology$' "$README"; then
  note_pass
else
  note_fail "missing heading: ## Sampling Methodology"
fi

if grep -q '^## Labeling Rubric$' "$README"; then
  note_pass
else
  note_fail "missing heading: ## Labeling Rubric"
fi

if grep -q '^## D-A4 Independence Compliance$' "$README"; then
  note_pass
else
  note_fail "missing heading: ## D-A4 Independence Compliance"
fi

# ---------- Check 6: rubric vocabulary present ----------

mech_hits=$(grep -c 'mechanical' "$README" || true)
std_hits=$(grep -c 'standard' "$README" || true)
nov_hits=$(grep -c 'novel' "$README" || true)

if [ "$mech_hits" -ge 1 ] && [ "$std_hits" -ge 1 ] && [ "$nov_hits" -ge 1 ]; then
  note_pass
else
  note_fail "rubric vocabulary missing (mechanical=${mech_hits} standard=${std_hits} novel=${nov_hits})"
fi

# ---------- Check 7: classify-task.sh referenced ----------

if grep -q 'classify-task.sh' "$README"; then
  note_pass
else
  note_fail "missing reference to classify-task.sh (D-A4 compliance section must name the load-bearing future file)"
fi

# ---------- Final summary ----------

if [ -n "$fail_reasons" ]; then
  printf '%s' "$fail_reasons"
fi
printf 'SUMMARY: p00-readme-shape.sh pass=%s fail=%s\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi
