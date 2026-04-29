#!/usr/bin/env bash
# scripts/verify/m028/p01-fixture-sanitized.sh -- M028/P01/T02 must-have
# verifier for the pre-repair fixture snapshot.
#
# Asserts the canonical M028 pre-repair fixture at
#   tests/fixtures/m028-pre-repair-snapshot.json
# is on-disk, parses as valid JSON, contains zero user-specific path /
# email leaks, and preserves at least one M025-flagged entry (so the
# fixture exercises the partial-flag shape the P02 `--repair` verifier
# expects).
#
# Checks:
#   1. File exists and is readable.
#   2. python3 -m json.tool parses the file.
#   3. Zero matches for `/Users/brettkellgren/`.
#   4. Zero matches for the standalone token `brettkellgren` (word-boundary).
#   5. Zero matches for `bkellgren@gmail.com`.
#   6. At least one match for `_orchestrator_managed`.
#
# Exit 0 on PASS. Exit 1 on any FAIL with a one-line stderr diagnostic.
#
# AD-19 single-script-file shape: flat file, no nested helpers, no compound
# chains in the body. Bash 3.2 + POSIX-sh-safe.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
FIXTURE="${REPO_ROOT}/tests/fixtures/m028-pre-repair-snapshot.json"

# Check 1: file presence + readability.
if [ ! -f "$FIXTURE" ]; then
  echo "FAIL: m028-pre-repair-snapshot.json missing at ${FIXTURE}" >&2
  exit 1
fi
if [ ! -r "$FIXTURE" ]; then
  echo "FAIL: m028-pre-repair-snapshot.json unreadable at ${FIXTURE}" >&2
  exit 1
fi

# Check 2: parseable JSON.
python3 -m json.tool "$FIXTURE" >/dev/null
JSON_RC=$?
if [ "$JSON_RC" -ne 0 ]; then
  echo "FAIL: m028-pre-repair-snapshot.json is not valid JSON (python3 exit ${JSON_RC})" >&2
  exit 1
fi

# Check 3: no `/Users/brettkellgren/` leak.
if grep -q '/Users/brettkellgren/' "$FIXTURE"; then
  echo "FAIL: sanitization leak -- found /Users/brettkellgren/" >&2
  exit 1
fi

# Check 4: no standalone `brettkellgren` token. grep -E supports word
# boundaries via \b on macOS BSD grep and GNU grep alike.
if grep -Eq '\bbrettkellgren\b' "$FIXTURE"; then
  echo "FAIL: sanitization leak -- found brettkellgren" >&2
  exit 1
fi

# Check 5: no operator email leak.
if grep -q 'bkellgren@gmail.com' "$FIXTURE"; then
  echo "FAIL: sanitization leak -- found bkellgren@gmail.com" >&2
  exit 1
fi

# Check 6: M025-flag anchor present.
if ! grep -q '_orchestrator_managed' "$FIXTURE"; then
  echo "FAIL: sanitized fixture missing _orchestrator_managed anchor" >&2
  exit 1
fi

echo "PASS: m028-pre-repair-snapshot.json sanitized and shape-valid"
exit 0
