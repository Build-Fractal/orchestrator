#!/usr/bin/env bash
# tools/verify/m044-p01-phase-suite.sh
# M044/P01 phase-suite aggregator — runs every m044-p01-* verifier (except
# itself) and reports a battery tally. Exits non-zero on any failure.
# Bash 3.2. NOTE: this is the project-owned phase aggregator; the framework
# rollup scripts/verify/check-must-haves.sh is invoked separately by the runner,
# never from here.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

SELF="$(basename "$0")"
pass=0
fail=0
failed_names=""

for v in tools/verify/m044-p01-*.sh; do
  [ -f "$v" ] || continue
  case "$(basename "$v")" in
    "$SELF") continue ;;
  esac
  if bash "$v" >/dev/null 2>&1; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    failed_names="${failed_names}${failed_names:+, }$(basename "$v")"
  fi
done

if [ -n "$failed_names" ]; then
  echo "FAILED: $failed_names"
fi
echo "BATTERY: pass=$pass fail=$fail"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
exit 0
