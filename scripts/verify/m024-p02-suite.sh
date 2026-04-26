#!/usr/bin/env bash
# scripts/verify/m024-p02-suite.sh — run both phase tests + every per-task verify.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

ok=1

bash "$ROOT/tests/test-evaluate-spec-backcompat.sh" || ok=0
bash "$ROOT/tests/test-m014-manifest-read.sh"      || ok=0
bash "$ROOT/scripts/verify/m024-p02-spec-shape-classify.sh"     || ok=0
bash "$ROOT/scripts/verify/m024-p02-m014-manifest-read.sh"      || ok=0
bash "$ROOT/scripts/verify/m024-p02-fixture-vs-live.sh"         || ok=0
bash "$ROOT/scripts/verify/m024-p02-evaluate-spec-backcompat.sh" || ok=0
bash "$ROOT/scripts/verify/m024-p02-spec-rationale.sh"          || ok=0
bash "$ROOT/scripts/verify/m024-p02-write-confinement.sh"       || ok=0

if [ "$ok" -eq 0 ]; then
  echo "FAIL: M024/P02 phase suite reported a failure (see above)"
  exit 1
fi

echo "PASS: M024/P02 suite — backcompat + manifest-read + fixture-vs-live + rationale + confinement"
exit 0
