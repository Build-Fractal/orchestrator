#!/usr/bin/env bash
# tools/verify/m035-p03-release-workflow-homebrew-job.sh
set -u

pass=0
fail=0
WF=".github/workflows/release.yml"

if [ ! -f "$WF" ]; then
  echo "FAIL: $WF missing"
  echo "BATTERY: pass=0 fail=1"
  exit 1
fi
pass=$((pass + 1))

for needle in \
  'homebrew-publish:' \
  'needs: npm-publish' \
  "startsWith(github.ref, 'refs/tags/v')" \
  'secrets.HOMEBREW_TAP_TOKEN' \
  'Build-Fractal/homebrew-orchestrator' \
  'render-formula.sh' \
  'Formula/orchestrator.rb' \
  'formula: bump to v'; do
  if grep -qF "$needle" "$WF"; then
    pass=$((pass + 1))
  else
    echo "FAIL: $WF missing pattern: $needle"
    fail=$((fail + 1))
  fi
done

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
