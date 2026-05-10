#!/usr/bin/env bash
# tools/verify/m035-p04-update-skill-doc-curl.sh
#
# M035 P04 T04 task-grain verifier. Reconciled M035 P06 T05.5 to
# match post-T04 state: P06/T04 deliberately collapsed
# `update_source: curl-pipe-bash` -> `npm` per D012 (curl-pipe-bash
# users are auto-detected as npm because the curl-pipe-bash
# installer extracts the npm tarball — D007/D009 single-source-of-
# truth). The literal `releases/latest/download/install.sh` URL
# lives in references/installation.md + packaging/install/install.sh,
# never was in commands/update.md. The verifier's new contract:
# commands/update.md documents the curl-pipe-bash → npm collapse
# narrative AND cross-references the load-bearing decision row(s)
# (D007/D009/D012) that justify it.
#
# AD-19 single-script-file shape. Bash 3.2 compatible.

set -u

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
DOC="$REPO_ROOT/commands/update.md"

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

if [ -f "$DOC" ]; then check "commands/update.md exists" 0; else check "commands/update.md exists" 1; fi

if grep -qF '## Update sources' "$DOC"; then check "## Update sources heading" 0; else check "## Update sources heading" 1; fi
if grep -qF 'Curl-pipe-bash users are auto-detected as' "$DOC"; then check "curl-pipe-bash → npm collapse narrative present" 0; else check "curl-pipe-bash → npm collapse narrative present" 1; fi
if grep -qE 'D007|D009|D012' "$DOC"; then check "D007/D009/D012 cross-reference present" 0; else check "D007/D009/D012 cross-reference present" 1; fi

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
