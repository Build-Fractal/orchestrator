#!/usr/bin/env bash
# m043-p00-findings-shape.sh — assert the P00 Cloudflare-API findings note
# resolves #Q-5-sub (FR-3a probe Decision) and #Q-6 (FR-9 diagnostic Decision)
# with closed-set values + evidence provenance. Tier 1 structural check only.
set -u

NOTE=".orchestrator/milestones/M043/phases/P00/cloudflare-api-findings.md"
fail=0

check() {
  # $1 = human label, $2 = exit status of a preceding test (0=pass)
  if [ "$2" -eq 0 ]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1"
    fail=1
  fi
}

test -f "$NOTE"
check "findings note exists" $?

if [ ! -f "$NOTE" ]; then
  echo "SUMMARY: m043-p00-findings-shape.sh pass=0 fail=1"
  exit 1
fi

grep -q "#Q-5-sub" "$NOTE"
check "#Q-5-sub section present" $?

grep -q "FR-3a Probe Decision" "$NOTE"
check "FR-3a Probe Decision heading present" $?

grep -Eq "authenticated-edit-token|authenticated-new-read-scope|unauthenticated-redirect-fallback" "$NOTE"
check "FR-3a probe Decision is a closed-set value" $?

grep -q "#Q-6" "$NOTE"
check "#Q-6 section present" $?

grep -q "FR-9 Diagnostic Decision" "$NOTE"
check "FR-9 Diagnostic Decision heading present" $?

grep -Eq "distinguishable|indistinguishable" "$NOTE"
check "FR-9 Decision is a closed-set value" $?

grep -q "Fixture-Seed Inventory" "$NOTE"
check "Fixture-Seed Inventory section present" $?

grep -q "Evidence Provenance" "$NOTE"
check "Evidence Provenance section present" $?

grep -Eq "live-confirmed|doc-derived" "$NOTE"
check "evidence provenance tag present" $?

if [ "$fail" -eq 0 ]; then
  echo "SUMMARY: m043-p00-findings-shape.sh pass=ALL fail=0"
  exit 0
fi
echo "SUMMARY: m043-p00-findings-shape.sh pass=SOME fail=1"
exit 1
