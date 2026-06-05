#!/usr/bin/env bash
# tools/verify/m035-p03-formula-template-shape.sh
set -u

pass=0
fail=0
TMPL="packaging/homebrew/orchestrator.rb.tmpl"

if [ ! -f "$TMPL" ]; then
  echo "FAIL: $TMPL missing"
  fail=$((fail + 1))
else
  pass=$((pass + 1))
  for needle in 'class Orchestrator < Formula' '__VERSION__' \
    '__URL__' '__SHA256__' 'bin.install_symlink' 'license "MIT"' \
    'def install' 'libexec.install'; do
    if grep -qF "$needle" "$TMPL"; then
      pass=$((pass + 1))
    else
      echo "FAIL: $TMPL missing pattern: $needle"
      fail=$((fail + 1))
    fi
  done
fi

# Anti-pattern: formula MUST NOT declare hard dependencies.
for anti in 'depends_on "node"' 'depends_on "python@3"'; do
  if grep -qF "$anti" "$TMPL"; then
    echo "FAIL: $TMPL contains anti-pattern: $anti (FR-9 — no formula-specific install logic)"
    fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
done

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
