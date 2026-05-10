#!/usr/bin/env bash
# tools/verify/papercut-m035-p00-exec-bit.sh — papercut-sweep-post-M035 PC-4
#
# Asserts every M035 P00 verifier under tools/verify/ has the executable
# bit set. The acceptance battery's run_one() helper at
# tests/m035-acceptance/run-acceptance-battery.sh:47 uses `[ ! -x "$cmd" ]`
# as its existence gate; verifiers without the exec bit silently SKIP,
# which masked SC-5/SC-6 coverage from M035 P06 close until 2026-05-09.
#
# Bash 3.2 / AD-19 single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

pass=0
fail=0

p00_verifiers="\
tools/verify/m035-p00-phase-suite.sh
tools/verify/m035-p00-bash32-collision.sh
tools/verify/m035-p00-managed-gitignore.sh
tools/verify/m035-p00-wiki-stubs-fresh.sh
tools/verify/m035-p00-npm-collision-evidence.sh
tools/verify/m035-p00-wiki-deploy-stage.sh"

while IFS= read -r v; do
  if [ -z "$v" ]; then continue; fi
  if [ -x "$v" ]; then
    printf 'PASS: executable: %s\n' "$v"
    pass=$((pass + 1))
  else
    printf 'FAIL: not executable: %s\n' "$v"
    fail=$((fail + 1))
  fi
done <<EOF
$p00_verifiers
EOF

printf 'BATTERY: pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi
