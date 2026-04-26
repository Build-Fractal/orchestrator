#!/usr/bin/env bash
# scripts/verify/m024-p05-empty-qa-full.sh
# Suite-runnable wrapper for tests/test-empty-qa-loop.sh.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
T="$ROOT/tests/test-empty-qa-loop.sh"
[ -x "$T" ] || { echo "FAIL: $T not executable"; exit 1; }
bash "$T"
