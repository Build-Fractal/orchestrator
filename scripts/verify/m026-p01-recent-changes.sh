#!/usr/bin/env bash
# scripts/verify/m026-p01-recent-changes.sh -- M026/P01/T04 gate:
# asserts CLAUDE.md and AGENTS.md Recent Changes regions contain a
# dual-write fragment naming M026 AND (parity OR spike). The fragment is
# written by scripts/util/dual-write-runtime-md.sh at T04 close.
#
# Marker-bounded region: the helper at
#   scripts/verify/lib/m026-p01-recent-changes-region.sh
# extracts the body between
#   # >>> orchestrator:recent-changes >>>
#   # <<< orchestrator:recent-changes <<<
#
# Bash 3.2 compatible. AD-19 single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
HELPER="${SCRIPT_DIR}/lib/m026-p01-recent-changes-region.sh"

passed=0
failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }

if [ ! -x "$HELPER" ] && [ ! -f "$HELPER" ]; then
  fail "recent-changes region helper missing at ${HELPER}"
  echo "SUMMARY: m026-p01-recent-changes.sh pass=${passed} fail=${failed}"
  exit 1
fi

check_region() {
  rel="$1"
  path="${REPO_ROOT}/${rel}"
  if [ ! -f "$path" ]; then
    fail "${rel} missing"
    return
  fi
  region=""
  region=$(bash "$HELPER" "$path" 2>/dev/null || true)
  if [ -z "$region" ]; then
    fail "${rel}: Recent Changes region empty or markers missing"
    return
  fi
  # Require M026 AND (parity OR spike) anywhere in the region.
  if echo "$region" | grep -q 'M026'; then
    if echo "$region" | grep -qE 'parity|spike'; then
      pass "${rel}: Recent Changes region contains M026 + (parity|spike) fragment"
      return
    fi
    fail "${rel}: Recent Changes region mentions M026 but missing parity/spike token"
    return
  fi
  fail "${rel}: Recent Changes region missing M026 token"
}

check_region "CLAUDE.md"
check_region "AGENTS.md"

echo "SUMMARY: m026-p01-recent-changes.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m026-p01-recent-changes.sh"
  exit 0
fi
echo "FAIL: m026-p01-recent-changes.sh" >&2
exit 1
