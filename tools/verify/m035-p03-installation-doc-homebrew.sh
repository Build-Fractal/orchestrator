#!/usr/bin/env bash
# tools/verify/m035-p03-installation-doc-homebrew.sh
set -u

pass=0
fail=0
DOC="references/installation.md"

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC missing"
  echo "BATTERY: pass=0 fail=1"
  exit 1
fi
pass=$((pass + 1))

for needle in \
  '## Installing via Homebrew' \
  '## Releasing via Homebrew' \
  'brew tap build-fractal/orchestrator' \
  'brew install orchestrator' \
  'brew uninstall orchestrator' \
  'orchestrator --version' \
  'secrets.HOMEBREW_TAP_TOKEN' \
  'Build-Fractal/homebrew-orchestrator' \
  'PAT rotation cadence' \
  'CON-6'; do
  if grep -qF "$needle" "$DOC"; then
    pass=$((pass + 1))
  else
    echo "FAIL: $DOC missing pattern: $needle"
    fail=$((fail + 1))
  fi
done

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
