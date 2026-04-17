#!/usr/bin/env bash
# scripts/verify/m011-p07-evidence-present.sh
# File-exists + token-contains gate for every dogfood evidence artifact
# produced during the P07 foreign-PRD e2e run. Extends the P06
# evidence-present pattern.
#
# Bash 3.2 compatible.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
EVID="$REPO/.orchestrator/milestones/M011/phases/P07/evidence"

fail=0

check_file() {
  local label="$1"
  local path="$2"
  local tok="$3"
  if [ ! -f "$path" ]; then
    printf 'FAIL[%s]: missing evidence file: %s\n' "$label" "$path"
    fail=1
    return
  fi
  if ! grep -Fq -- "$tok" "$path"; then
    printf 'FAIL[%s]: expected token "%s" not found in %s\n' "$label" "$tok" "$path"
    fail=1
    return
  fi
  printf 'PASS[%s]: %s contains "%s"\n' "$label" "$path" "$tok"
}

check_file "detect-shape"        "$EVID/detect-shape.txt"          "shape=foreign"
check_file "normalize-transcript" "$EVID/normalize-transcript.txt"  "NORMALIZED:"
check_file "gate-result"          "$EVID/gate-result.md"            "verdict:"
check_file "chunker-transcript"   "$EVID/chunker-transcript.txt"    "CREATED:"

TIMING="$EVID/timing.txt"
if [ ! -f "$TIMING" ]; then
  printf 'FAIL[timing]: missing %s\n' "$TIMING"
  fail=1
else
  if ! grep -Fq -- "elapsed_seconds=" "$TIMING"; then
    printf 'FAIL[timing]: %s missing elapsed_seconds= key\n' "$TIMING"
    fail=1
  else
    val="$(grep -E '^elapsed_seconds=' "$TIMING" | head -n 1 | sed -E 's/^elapsed_seconds=//')"
    case "$val" in
      ''|*[!0-9]*)
        printf 'FAIL[timing]: elapsed_seconds value "%s" is not a non-negative integer\n' "$val"
        fail=1
        ;;
      *)
        if [ "$val" -ge 120 ]; then
          printf 'FAIL[timing]: elapsed_seconds=%s exceeds 120s budget\n' "$val"
          fail=1
        else
          printf 'PASS[timing]: elapsed_seconds=%s (<120)\n' "$val"
        fi
        ;;
    esac
  fi
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS: all P07 dogfood evidence artifacts present and contain expected tokens"
exit 0
