#!/usr/bin/env bash
# scripts/verify/m024-p03-write-confinement.sh
# Asserts P03-introduced scripts write only under .orchestrator/intake or /tmp (SB-3).

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

ALLOWED="\\.orchestrator/intake|/tmp|mktemp|\\\${PROPOSAL}|\\\$PROPOSAL|\\\$out_path|\\\$out_dir|\\\$INTAKE_ROOT|\\\$INTAKE_DIR|\\\$proposal"

# Match real file-write redirections only:
#   - `mkdir ` (directory creation)
#   - ` > <target>` or ` >> <target>` where target is NOT `&N` (stderr/stdout dup)
#     and NOT `/dev/null` (suppression). Requires whitespace before `>` to avoid
#     matching literal `>` inside string literals like `<path>` / `<string>`.
# Excludes:
#   - `>&1`, `>&2` (stream duplication)
#   - `2>/dev/null`, `>/dev/null` (output suppression)
#   - lines starting with `#` (comments)
violations=""
for f in \
  "$ROOT/scripts/intake/paragraph-classify.sh" \
  "$ROOT/scripts/intake/approval-gate.sh" \
  "$ROOT/scripts/intake/route-to-specify.sh" \
  "$ROOT/scripts/intake/route-to-dispatch.sh"; do
  [ -f "$f" ] || continue
  hits=$(grep -nE 'mkdir |[[:space:]]>>?[[:space:]]*[^&[:space:]]' "$f" \
    | grep -vE '>>?[[:space:]]*/dev/null' \
    | grep -vE '>&[12]' \
    | grep -vE "$ALLOWED" \
    | grep -vE '^[0-9]+:[[:space:]]*#' \
    || true)
  if [ -n "$hits" ]; then
    violations="$violations
$f:
$hits"
  fi
done

if [ -n "$violations" ]; then
  echo "FAIL: write-confinement violations:$violations"
  exit 1
fi

echo "PASS: P03 scripts write only under .orchestrator/intake or /tmp"
exit 0
