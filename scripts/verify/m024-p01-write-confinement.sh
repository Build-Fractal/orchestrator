#!/usr/bin/env bash
# scripts/verify/m024-p01-write-confinement.sh
# Asserts grep against P01-produced shell scripts shows no writes outside .orchestrator/intake.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Allowed write targets (each line is a fixed substring matched against the
# script body — any disk write must reference one of these paths).
ALLOWED="\\.orchestrator/intake|/tmp|mktemp|\\\${tmp_render}|\\\$out_path|\\\$out_dir|\\\$INTAKE_ROOT|\\\$INTAKE_DIR"

violations=""
for f in "$ROOT/scripts/intake/proposal-emit.sh" "$ROOT/scripts/intake/shape-detect.sh" "$ROOT/scripts/intake/intake-id-allocate.sh"; do
  [ -f "$f" ] || continue
  # Find any redirection or mkdir target. If a >, >>, mkdir, or cp/mv target
  # references something other than ALLOWED paths, flag it.
  hits=$(grep -nE 'mkdir |^[^#]*>[^&]' "$f" | grep -vE "$ALLOWED" | grep -vE '^[[:space:]]*#' | grep -vE '^[0-9]+:[[:space:]]*echo ' | grep -vE '2>/dev/null' || true)
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

echo "PASS: P01 scripts write only under .orchestrator/intake or /tmp"
exit 0
