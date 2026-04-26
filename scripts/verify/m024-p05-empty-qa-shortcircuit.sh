#!/usr/bin/env bash
# scripts/verify/m024-p05-empty-qa-shortcircuit.sh
# Suite-runnable wrapper for tests/test-qa-short-circuit.sh.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
T="$ROOT/tests/test-qa-short-circuit.sh"
[ -x "$T" ] || { echo "FAIL: $T not executable"; exit 1; }
bash "$T"
