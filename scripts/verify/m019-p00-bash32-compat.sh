#!/usr/bin/env bash
# scripts/verify/m019-p00-bash32-compat.sh — Constitution VIII compliance gate.
#
# Scans every .sh file authored or modified by P00 for Bash-4-only
# constructs and confirms bash -n parses each file.
#
# Exit 0 on clean, 1 on any violation. Bash 3.2 compatible.
#
# Implementation note: the gate scans its own source. Forbidden needles are
# assembled from split string literals so the source does not self-match.
# Established M021/P04 pattern.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# P00 touched/created .sh files
FILES="
scripts/dispatch/build-context.sh
scripts/engine/intensity-gate.sh
scripts/lifecycle/write-permissions.sh
scripts/lifecycle/generate-permissions.sh
scripts/lifecycle/apply-sentinel-overwrite.sh
scripts/verify/m019-p00-payload-shape.sh
scripts/verify/m019-p00-evaluate-preflight-additivity.sh
scripts/verify/m019-p00-no-regression.sh
scripts/verify/m019-p00-bash32-compat.sh
scripts/verify/m019-p00-phase-suite.sh
"

# Forbidden constructs. Split across string literals so this source does
# not self-match during its own scan.
FORBID_A='declare'' -A'
FORBID_B='map''file'
FORBID_C='read''array'
FORBID_D='${''var'',,}'
FORBID_E='${''var''^^}'
FORBID_F='${!''prefix''*}'
FORBID_G='<''('
FORBID_H='>''('

for rel in $FILES; do
  f="$REPO_ROOT/$rel"
  if [ ! -f "$f" ]; then
    fail "file exists" "$rel"
    continue
  fi
  # (a) bash -n parse
  if bash -n "$f" 2>/dev/null; then
    pass "$rel parses clean"
  else
    fail "$rel parses clean" "bash -n failed"
  fi
  # (b) forbidden constructs — strip comment-only lines first
  _stripped="$(grep -v '^[[:space:]]*#' "$f")"
  for needle in "$FORBID_A" "$FORBID_B" "$FORBID_C" "$FORBID_D" "$FORBID_E" "$FORBID_F" "$FORBID_G" "$FORBID_H"; do
    if printf '%s' "$_stripped" | grep -qF "$needle"; then
      fail "$rel forbidden construct" "found [$needle]"
    fi
  done
done

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m019-p00-bash32-compat.sh"
  exit 0
else
  echo "FAIL: m019-p00-bash32-compat.sh ($fail_count failures)"
  exit 1
fi
