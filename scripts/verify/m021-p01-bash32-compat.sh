#!/usr/bin/env bash
# scripts/verify/m021-p01-bash32-compat.sh — Parse-check all P01 wrappers.
# Uses `bash -n` as a syntactic parse check and greps for known
# Bash-4-only constructs. Exits 0 when all three wrappers are clean.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

wrappers="with-env.sh read-range.sh run-probe.sh"
fail_count=0

for w in $wrappers; do
  path="${REPO_ROOT}/scripts/util/${w}"
  if [ ! -f "$path" ]; then
    echo "FAIL: missing $path"
    fail_count=$((fail_count + 1))
    continue
  fi
  if ! bash -n "$path" 2>/dev/null; then
    echo "FAIL: $w — bash -n parse error"
    fail_count=$((fail_count + 1))
    continue
  fi
  # Scan for Bash-4-only constructs. Keep this list conservative.
  if grep -qE 'declare[[:space:]]+-A|mapfile|readarray|\$\{[A-Za-z_][A-Za-z_0-9]*,,\}|\$\{[A-Za-z_][A-Za-z_0-9]*\^\^\}|\$\{![A-Za-z_][A-Za-z_0-9]*\*\}' "$path"; then
    echo "FAIL: $w — contains Bash-4-only construct"
    fail_count=$((fail_count + 1))
    continue
  fi
  echo "PASS: $w bash-3.2 clean"
done

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m021-p01-bash32-compat.sh"
  exit 0
fi
echo "FAIL: m021-p01-bash32-compat.sh ($fail_count failures)"
exit 1
