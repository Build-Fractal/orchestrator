#!/usr/bin/env bash
# tools/verify/m035-p04-installation-doc-curl.sh
#
# M035 P04 T04 task-grain verifier. Asserts references/installation.md
# contains the curl-pipe-bash sections after T04 edits.
#
# AD-19 single-script-file shape. Bash 3.2 compatible.

set -u

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
DOC="$REPO_ROOT/references/installation.md"

pass=0
fail=0

check() {
  local name="$1"
  local result="$2"
  if [ "$result" = "0" ]; then
    echo "PASS: $name"
    pass=$((pass + 1))
  else
    echo "FAIL: $name"
    fail=$((fail + 1))
  fi
}

if [ -f "$DOC" ]; then check "installation.md exists" 0; else check "installation.md exists" 1; fi

# Consumer-facing § Installing via curl-pipe-bash.
if grep -qF '## Installing via curl-pipe-bash' "$DOC"; then check "## Installing via curl-pipe-bash heading" 0; else check "## Installing via curl-pipe-bash heading" 1; fi
if grep -qF 'releases/latest/download/install.sh' "$DOC"; then check "latest/download URL recipe" 0; else check "latest/download URL recipe" 1; fi
if grep -qF 'ORCHESTRATOR_VERSION=' "$DOC"; then check "ORCHESTRATOR_VERSION pinning recipe" 0; else check "ORCHESTRATOR_VERSION pinning recipe" 1; fi
if grep -qF '/orchestrator-init' "$DOC"; then check "per-project /orchestrator-init step" 0; else check "per-project /orchestrator-init step" 1; fi
if grep -qF -- '--uninstall' "$DOC"; then check "uninstall recipe" 0; else check "uninstall recipe" 1; fi

# Operator-facing § Releasing via curl-pipe-bash.
if grep -qF '## Releasing via curl-pipe-bash' "$DOC"; then check "## Releasing via curl-pipe-bash heading" 0; else check "## Releasing via curl-pipe-bash heading" 1; fi
if grep -qF 'D009' "$DOC"; then check "D009 cross-reference" 0; else check "D009 cross-reference" 1; fi
if grep -qF 'CON-8' "$DOC"; then check "CON-8 timeout reference" 0; else check "CON-8 timeout reference" 1; fi
if grep -qF 'D010' "$DOC"; then check "D010 cross-reference" 0; else check "D010 cross-reference" 1; fi
if grep -qF 'D011' "$DOC"; then check "D011 cross-reference" 0; else check "D011 cross-reference" 1; fi
if grep -qF 'MOS-4' "$DOC"; then check "MOS-4 first-release smoke" 0; else check "MOS-4 first-release smoke" 1; fi
if grep -qF 'MOS-5' "$DOC"; then check "MOS-5 synthetic tag push" 0; else check "MOS-5 synthetic tag push" 1; fi

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
