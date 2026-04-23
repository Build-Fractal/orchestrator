#!/usr/bin/env bash
# Gate: run the FR-18 byte-compat fixture test.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEST="${PROJECT_ROOT}/tests/test-specify-shape.sh"

if [ ! -x "$TEST" ]; then
  echo "FAIL: tests/test-specify-shape.sh missing or not executable" >&2
  exit 1
fi

bash "$TEST"
exit $?
