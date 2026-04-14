#!/usr/bin/env bash
# m008-p07-init-interface.sh — static flag/exit-code surface check for init-project.sh
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/lifecycle/init-project.sh"

test -x "$SCRIPT" || { echo "FAIL: not executable: $SCRIPT" >&2; exit 1; }

for flag in "\-\-project-dir" "\-\-runtime" "\-\-dry-run" "\-\-force" "\-\-verbose"; do
  grep -qE "$flag" "$SCRIPT" || { echo "FAIL: missing flag parser for $flag" >&2; exit 1; }
done

# Exit codes 1/2/3 must be referenced literally.
for rc in "exit 1" "exit 2" "exit 3"; do
  grep -qF "$rc" "$SCRIPT" || { echo "FAIL: missing '$rc' in script" >&2; exit 1; }
done

echo "PASS: init-project.sh interface surface"
