#!/usr/bin/env bash
# tools/verify/m035-p04-update-skill-doc-curl.sh
#
# M035 P04 T04 task-grain verifier. Asserts commands/update.md
# contains the curl-pipe-bash row in ## Update sources.
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
if grep -qF 'update_source: curl-pipe-bash' "$DOC"; then check "update_source: curl-pipe-bash row" 0; else check "update_source: curl-pipe-bash row" 1; fi
if grep -qF 'releases/latest/download/install.sh' "$DOC"; then check "latest/download URL in update doc" 0; else check "latest/download URL in update doc" 1; fi

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
