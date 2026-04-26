#!/usr/bin/env bash
# scripts/verify/m024-p04-fast-path-condition-violation.sh
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
exec bash "$ROOT/tests/test-fast-path-condition-violation.sh"
