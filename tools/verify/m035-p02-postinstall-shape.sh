#!/usr/bin/env bash
# tools/verify/m035-p02-postinstall-shape.sh
# Asserts packaging/npm/postinstall.sh exists, is executable, and
# carries the load-bearing M035 P02 T02 contract surfaces:
#   * Windows fail-closed guard (uname -s case match)
#   * DRY_RUN=1 honor (would_invoke= line shape)
#   * INIT_CWD resolution (npm convention)
#   * runtime_unavailable advisory path (Claude Code absence)
#   * delegation to install-claude-code.sh
set -euo pipefail

REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
POSTINSTALL="$REPO/packaging/npm/postinstall.sh"

pass=0
fail=0

if [ ! -f "$POSTINSTALL" ]; then
  echo "FAIL: $POSTINSTALL not found"
  fail=$((fail + 1))
elif [ ! -x "$POSTINSTALL" ]; then
  echo "FAIL: $POSTINSTALL not executable"
  fail=$((fail + 1))
else
  echo "PASS: postinstall.sh exists and is executable"
  pass=$((pass + 1))
fi

check_grep() {
  local pattern="$1"
  local label="$2"
  if grep -qE "$pattern" "$POSTINSTALL"; then
    echo "PASS: $label"
    pass=$((pass + 1))
  else
    echo "FAIL: $label (pattern: $pattern)"
    fail=$((fail + 1))
  fi
}

check_grep 'Windows_NT' "Windows fail-closed guard names Windows_NT (MIT-9)"
check_grep 'MINGW\*|CYGWIN\*|MSYS\*' "Windows fail-closed guard names MINGW/CYGWIN/MSYS (MIT-9)"
check_grep 'INIT_CWD' "INIT_CWD resolution (npm convention)"
check_grep 'DRY_RUN' "DRY_RUN=1 honor (D002 fixture-strategy)"
check_grep 'would_invoke=' "DRY_RUN=1 emits would_invoke= lines"
check_grep 'install-claude-code\.sh' "delegates to install-claude-code.sh"
check_grep 'runtime_unavailable=true' "runtime_unavailable advisory path (Claude Code absence)"

# Functional smoke test: DRY_RUN=1 invocation emits would_invoke=
# without making writes. Use a temp project dir to avoid polluting.
TMPDIR_PROBE="$(mktemp -d 2>/dev/null || mktemp -d -t m035p02t02)"
if INIT_CWD="$TMPDIR_PROBE" DRY_RUN=1 bash "$POSTINSTALL" 2>&1 \
     | grep -q '^would_invoke='; then
  echo "PASS: DRY_RUN=1 dry-run emits would_invoke= line"
  pass=$((pass + 1))
else
  echo "FAIL: DRY_RUN=1 dry-run did not emit would_invoke="
  fail=$((fail + 1))
fi
rm -rf "$TMPDIR_PROBE" 2>/dev/null || true

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
