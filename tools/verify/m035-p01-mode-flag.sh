#!/usr/bin/env bash
# tools/verify/m035-p01-mode-flag.sh
# M035 P01 T01 must-have: assert that the user-facing --mode=copy|symlink
# flag is wired into all three installers, and that the TEST-ONLY
# --asset-mode-override backward-compat alias is preserved.
#
# Single-script-file shape per AD-19. Bash 3.2 compatible.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

fail=0
for inst in install-claude-code.sh install-codex.sh install-cursor.sh; do
  installer="$REPO_ROOT/packaging/install/$inst"
  if [ ! -f "$installer" ]; then
    echo "FAIL: $inst not found at $installer" >&2
    fail=1
    continue
  fi
  # User-facing --mode flag: both space-separated and equals-form must
  # appear as case-block patterns.
  if ! grep -q -- '--mode)' "$installer"; then
    echo "FAIL: $inst missing --mode) case handler" >&2
    fail=1
  fi
  if ! grep -q -- '--mode=\*)' "$installer"; then
    echo "FAIL: $inst missing --mode=*) case handler" >&2
    fail=1
  fi
  # Backward-compat TEST-ONLY alias must still be recognised.
  if ! grep -q -- '--asset-mode-override)' "$installer"; then
    echo "FAIL: $inst missing --asset-mode-override) backward-compat handler" >&2
    fail=1
  fi
  if ! grep -q -- '--asset-mode-override=\*)' "$installer"; then
    echo "FAIL: $inst missing --asset-mode-override=*) backward-compat handler" >&2
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "PASS: m035-p01-mode-flag"
  exit 0
fi
exit 1
