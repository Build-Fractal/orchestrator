#!/usr/bin/env bash
# M014/P02 phase verification suite — chains all nine P02 gates.
# Exit 0 on green; exit 1 with per-gate breakdown on failure.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GATES="m014-p02-write-site-manifest.sh
m014-p02-init-dual-write.sh
m014-p02-reinit-dual-write.sh
m014-p02-consolidate-dual-write.sh
m014-p02-check-docs-drift.sh
m014-p02-run-doctor-drift-section.sh
m014-p02-doctor-md.sh
m014-p02-migration-idempotent.sh
m014-p02-lint-and-bash32.sh"

passed=0
failed=0
total=0
failed_list=""

for g in $GATES; do
  total=$((total + 1))
  path="$SCRIPT_DIR/$g"
  if [ ! -x "$path" ]; then
    echo "FAIL: gate missing or not executable: $g" >&2
    failed=$((failed + 1))
    failed_list="${failed_list}  - $g (missing)
"
    continue
  fi

  if bash "$path" >/dev/null 2>&1; then
    passed=$((passed + 1))
    echo "PASS: $g"
  else
    failed=$((failed + 1))
    echo "FAIL: $g" >&2
    failed_list="${failed_list}  - $g
"
  fi
done

echo ""
echo "M014/P02 phase suite: $passed / $total gates passed"

if [ "$failed" -gt 0 ]; then
  echo ""
  echo "Failed gates:"
  printf '%s' "$failed_list"
  exit 1
fi

exit 0
