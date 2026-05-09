#!/usr/bin/env bash
# tools/verify/m035-p03-render-formula-shape.sh
set -u

pass=0
fail=0
RENDER="packaging/homebrew/render-formula.sh"

if [ ! -x "$RENDER" ]; then
  echo "FAIL: $RENDER not executable"
  echo "BATTERY: pass=0 fail=1"
  exit 1
fi

# 1. Missing-flag rejection.
if bash "$RENDER" --version 1.0.0 --url https://x.test/a.tgz \
  >/dev/null 2>&1; then
  echo "FAIL: render-formula did not reject missing --sha256"
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

# 2. Malformed sha256 rejection (too short).
if bash "$RENDER" --version 1.0.0 --url https://x.test/a.tgz \
  --sha256 deadbeef >/dev/null 2>&1; then
  echo "FAIL: render-formula did not reject short --sha256"
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

# 3. Successful render with valid args. SHA-256 of the empty
# string (e3b0c44...b855) is a stable 64-hex-char fixture.
PROBE_OUT="/tmp/m035-p03-render-probe.out"
bash "$RENDER" \
  --version "1.0.0" \
  --url "https://github.com/Build-Fractal/orchestrator/releases/download/v1.0.0/build-fractal-orchestrator-1.0.0.tgz" \
  --sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" \
  > "$PROBE_OUT" 2>/dev/null
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL: render-formula exit $rc on valid args"
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

for needle in '1.0.0' \
  'build-fractal-orchestrator-1.0.0.tgz' \
  'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' \
  'class Orchestrator < Formula'; do
  if grep -qF "$needle" "$PROBE_OUT"; then
    pass=$((pass + 1))
  else
    echo "FAIL: rendered formula missing: $needle"
    fail=$((fail + 1))
  fi
done

if grep -qF '__VERSION__' "$PROBE_OUT"; then
  echo "FAIL: rendered formula still contains __VERSION__"
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

rm -f "$PROBE_OUT"
echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
