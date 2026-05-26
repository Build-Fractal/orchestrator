#!/usr/bin/env bash
# tools/verify/m041-p06-config-repo.sh
# Verifies detective.repo resolves via read-config.sh and that file-issue.sh
# honors it (config key > default) when --repo is not passed.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

# read-config.sh knows the key and returns the defaults-template value
val="$(bash scripts/state/read-config.sh detective.repo 2>/dev/null)"
if [ "$val" != "Build-Fractal/orchestrator" ]; then
  echo "FAIL: read-config.sh detective.repo returned '$val' (expected Build-Fractal/orchestrator)"
  exit 1
fi

# file-issue.sh resolves the repo from config into its mock write when --repo omitted
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
bash scripts/diagnostics/triage-issue.sh --symptom "config repo test" > "$tmpdir/report.md" 2>/dev/null
GH_MOCK_DIR="$tmpdir" bash scripts/diagnostics/file-issue.sh \
  --triage-report "$tmpdir/report.md" --yes < /dev/null > /dev/null 2>&1
if ! grep -q '"repo":"Build-Fractal/orchestrator"' "$tmpdir/issue-create-request.json"; then
  echo "FAIL: file-issue.sh did not resolve repo from config into the mock request"
  exit 1
fi
echo "PASS: detective.repo resolves via config and file-issue.sh honors it"
