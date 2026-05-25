#!/usr/bin/env bash
# tools/verify/m041-p03-path-disambiguation.sh -- Verify detective-recommend.sh
# does NOT emit RECOMMEND for user-project (non-orchestrator) paths.
# Bash 3.2 compatible.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile"' EXIT

# User-project path should NOT trigger recommendation
bash scripts/diagnostics/detective-recommend.sh \
  --symptom "test" \
  --path "/some/user/project/scripts/foo.sh" 2>"$tmpfile"

if grep -qF "RECOMMEND:" "$tmpfile"; then
  echo "FAIL: RECOMMEND emitted for user-project path (should only fire for orchestrator-internal)"
  exit 1
fi
echo "PASS: no RECOMMEND for user-project path -- disambiguation working"
