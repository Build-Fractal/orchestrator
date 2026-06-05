#!/usr/bin/env bash
# tools/verify/m035-p03-phase-suite.sh -- M035 P03 phase-suite
# aggregator. Chains every per-truth verifier in T01–T04 order and
# emits a single BATTERY summary line.
set -u

pass=0
fail=0
skip=0

VERIFIERS=" \
  tools/verify/m035-p03-formula-template-shape.sh \
  tools/verify/m035-p03-formula-install-glob.sh \
  tools/verify/m035-p03-render-formula-shape.sh \
  tools/verify/m035-p03-release-workflow-homebrew-job.sh \
  tools/verify/m035-p03-release-workflow-con6-homebrew.sh \
  tools/verify/m035-p03-byte-equivalence-homebrew-arm.sh \
  tools/verify/m035-p03-installation-doc-homebrew.sh \
  tools/verify/m035-p03-update-skill-doc-homebrew.sh \
"

for v in $VERIFIERS; do
  if [ ! -x "$v" ]; then
    echo "FAIL: $v missing or not executable"
    fail=$((fail + 1))
    continue
  fi
  # Capture each verifier's output for diagnostic value when the
  # aggregator FAILs in CI.
  out="$(bash "$v" 2>&1)"
  rc=$?
  # Per-verifier BATTERY line: parse pass/fail/skip counts.
  line="$(printf '%s\n' "$out" | grep -E '^BATTERY:' | tail -1)"
  if [ "$rc" -eq 0 ]; then
    pass=$((pass + 1))
    echo "PASS: $v ($line)"
  else
    echo "FAIL: $v exit $rc"
    echo "$out" | sed 's/^/    /'
    fail=$((fail + 1))
  fi
  # Surface skip counts from per-verifier BATTERY lines.
  vskip="$(printf '%s' "$line" | sed -nE 's/.*skip=([0-9]+).*/\1/p')"
  if [ -n "$vskip" ]; then
    skip=$((skip + vskip))
  fi
done

echo "BATTERY: pass=$pass fail=$fail skip=$skip"
[ "$fail" -eq 0 ]
