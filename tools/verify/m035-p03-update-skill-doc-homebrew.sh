#!/usr/bin/env bash
# tools/verify/m035-p03-update-skill-doc-homebrew.sh
set -u

pass=0
fail=0
DOC="commands/update.md"

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC missing"
  echo "BATTERY: pass=0 fail=1"
  exit 1
fi
pass=$((pass + 1))

for needle in \
  'update_source: homebrew' \
  'brew upgrade'; do
  if grep -qF "$needle" "$DOC"; then
    pass=$((pass + 1))
  else
    echo "FAIL: $DOC missing pattern: $needle"
    fail=$((fail + 1))
  fi
done

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
