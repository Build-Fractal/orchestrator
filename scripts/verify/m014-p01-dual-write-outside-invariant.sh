#!/usr/bin/env bash
# Gate: run the outside-markers invariant fixture test.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEST="${PROJECT_ROOT}/tests/test-dual-write-outside-invariant.sh"

if [ ! -x "$TEST" ]; then
  echo "FAIL: tests/test-dual-write-outside-invariant.sh missing or not executable" >&2
  exit 1
fi

bash "$TEST"
exit $?
