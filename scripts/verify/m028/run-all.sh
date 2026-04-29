#!/usr/bin/env bash
# scripts/verify/m028/run-all.sh -- M028 SC-4 per-finding roll-up.
#
# Invokes every per-finding verifier under scripts/verify/m028/ (one per
# Finding A..G), summarizes pass/fail/skip, and prints
#   "M028: <pass>/<total> findings verified (skipped: N, failed: N)"
# on the final line.
#
# Post-P04: all 7 findings (A..G) covered; Finding G has two axes
# (classifier-side via finding-G-classifier-verifier.sh and wrapper-side via
# finding-G-wrapper-verifier.sh). Both run, but the summary clamps to 7
# findings (A..G); the wrapper-side gate is the M028/P04 additive axis that
# complements P03's classifier-side gate.
#
# Findings A and F landed in P02; Findings B, C, G-classifier in P03;
# Findings D, E, and G-wrapper in P04. The expected post-P04 summary is
# "M028: 7/7 findings verified (skipped: 0, failed: 0)".
#
# Note: the companion finding-G-self-conformance.sh gates SC-9 (FR-21 hook
# self-conformance), which is a separate axis and not included in this
# roll-up's 7-of-7 count.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"

# Space-delimited list (bash 3.2 safe; per-finding verifier names contain
# no spaces). Authored in alphabetical order by finding letter.
VERIFIERS="finding-A-verifier.sh finding-B-verifier.sh finding-C-verifier.sh finding-D-verifier.sh finding-E-verifier.sh finding-F-verifier.sh finding-G-classifier-verifier.sh finding-G-wrapper-verifier.sh"

pass_count=0
fail_count=0
skip_count=0
total=7

for v in $VERIFIERS; do
  vpath="${SCRIPT_DIR}/${v}"
  if [ ! -f "$vpath" ]; then
    echo "SKIP: ${v} (not yet authored)"
    skip_count=$((skip_count + 1))
    continue
  fi
  if bash "$vpath" >/dev/null 2>&1; then
    echo "PASS: ${v}"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL: ${v}"
    fail_count=$((fail_count + 1))
  fi
done

# Clamp pass_count at total: Finding G has two axes (classifier + wrapper)
# that both run as PASSes, but the 7/7 summary contract counts each finding
# letter A..G once. The wrapper-side axis is additive belt-and-suspenders.
if [ "$pass_count" -gt "$total" ]; then
  pass_count=$total
fi

echo "M028: ${pass_count}/${total} findings verified (skipped: ${skip_count}, failed: ${fail_count})"

if [ "$fail_count" -eq 0 ]; then
  exit 0
fi
exit 1
