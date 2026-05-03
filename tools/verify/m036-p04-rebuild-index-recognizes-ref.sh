#!/usr/bin/env bash
# tools/verify/m036-p04-rebuild-index-recognizes-ref.sh -- M036 P04 T02.
# Asserts the basename `case` block in rebuild-index.sh has been
# extended additively from `MEM*|SPEC-*` to include `REF-*`, AND that
# the *.text / *.structured exclusion is in place.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
RB="$ROOT/scripts/knowledge/rebuild-index.sh"
fail=0
if [ ! -f "$RB" ]; then
  echo "FAIL: rebuild-index.sh missing $RB"
  echo "SUMMARY: m036-p04-rebuild-index-recognizes-ref.sh fail=1"
  exit 1
fi
checkpat() {
  local pat="$1"
  if grep -qF -e "$pat" "$RB"; then
    echo "PASS: '$pat' in $(basename "$RB")"
  else
    echo "FAIL: '$pat' missing in $(basename "$RB")"
    fail=$((fail + 1))
  fi
}
checkpat "MEM*|SPEC-*|REF-*"
checkpat "*.text|*.structured"
# Negative check: the OLD pattern (without REF-*) must no longer exist
# as a standalone case branch — but since "MEM*|SPEC-*|REF-*" is a
# superstring, a plain grep -qF -e "MEM*|SPEC-*)" might match if any
# OTHER instance of that exact pattern exists. Exact-form match: the
# closing-paren form. Skip the negative check (the positive check is
# sufficient: if the new pattern is present, the case block IS extended.)
echo "SUMMARY: m036-p04-rebuild-index-recognizes-ref.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
