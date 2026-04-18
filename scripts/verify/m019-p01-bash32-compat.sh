#!/usr/bin/env bash
# scripts/verify/m019-p01-bash32-compat.sh — Constitution VIII compliance gate.
#
# Scans every .sh file authored or modified by M019/P01 for Bash-4-only
# constructs and confirms bash -n parses each file.
#
# Exit 0 on clean, 1 on any violation. Bash 3.2 compatible.
#
# Implementation note: the gate scans its own source. Forbidden needles are
# assembled from split string literals so the source does not self-match.
# Established M021/P04 pattern; mirrored from m019-p00-bash32-compat.sh.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# P01 touched/created .sh files (explicit list per T06 plan).
FILES="
scripts/lib/pricing.sh
scripts/dispatch/build-context.sh
scripts/dispatch/dispatch-interface.sh
scripts/knowledge/write-summary.sh
scripts/verify/m019-schema.sh
scripts/verify/m019-p01-emitter-presence.sh
scripts/verify/m019-p01-pricing-degradation.sh
scripts/verify/m019-p01-source-enum.sh
scripts/verify/m019-p01-zero-token-growth.sh
scripts/verify/m019-p01-fixture-rollup.sh
scripts/verify/m019-p01-additive-compat.sh
scripts/verify/m019-p01-no-pre-p00-emission.sh
scripts/verify/m019-p01-bash32-compat.sh
scripts/verify/m019-p01-phase-suite.sh
scripts/dispatch/adapters/backend/stub.sh
"

# Forbidden constructs (documented here so must-have content checks see
# the literal tokens; the scanner below uses split-literal versions to
# avoid self-match during its own scan):
#   declare -A, mapfile, readarray, ${var^^}, ${var,,}, <(...), >(...)
# Split across string literals so this source does not self-match.
FORBID_A='declare'' -A'
FORBID_B='map''file'
FORBID_C='read''array'
FORBID_D='${''var'',,}'
FORBID_E='${''var''^^}'
FORBID_F='${!''prefix''*}'
FORBID_G='<''('
FORBID_H='>''('

count=0
for rel in $FILES; do
  f="$REPO_ROOT/$rel"
  count=$((count + 1))
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
  echo "PASS: bash32-compat $count files clean"
  echo "PASS: m019-p01-bash32-compat.sh"
  exit 0
else
  echo "FAIL: m019-p01-bash32-compat.sh ($fail_count failures)"
  exit 1
fi
