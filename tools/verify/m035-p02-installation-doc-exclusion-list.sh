#!/usr/bin/env bash
# tools/verify/m035-p02-installation-doc-exclusion-list.sh
# Asserts references/installation.md  Channel-specific metadata files
# exists with the load-bearing exclusion list (MIT-2 enumeration).
#
# Bash 3.2 compatible.

set -u

REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
DOC="$REPO/references/installation.md"

pass=0
fail=0

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC not found"
  exit 1
fi

if grep -q '^## Channel-specific metadata files' "$DOC"; then
  echo "PASS: Channel-specific metadata files heading present"
  pass=$((pass + 1))
else
  echo "FAIL: Channel-specific metadata files heading absent"
  fail=$((fail + 1))
fi

for path in '.orchestrator/install-meta.txt' '.orchestrator/.previous-version' \
            'package.json' 'package-lock.json' 'node_modules/'; do
  if grep -qF "$path" "$DOC"; then
    echo "PASS: exclusion list contains $path"
    pass=$((pass + 1))
  else
    echo "FAIL: exclusion list missing $path"
    fail=$((fail + 1))
  fi
done

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
