#!/usr/bin/env bash
# scripts/verify/m027-p00-bash32-compat.sh — M027/P00 CON-7 / SC-11.
#
# Scans the M027/P00 .sh file set for Bash-4-only constructs and confirms
# `bash -n` parses each cleanly. Self-applying — this verifier itself is in
# the scanned set. Forbidden literals (documented here for human readers,
# assembled at runtime via split string literals so this scanner does not
# self-match):
#   declare -A, mapfile, readarray, <<<, <(...), >(...), &>, ${var^^}
#
# Scanned set:
#   - scripts/diagnostics/metrics-rollup.sh
#   - every scripts/verify/m027-p00-*.sh (this file included)
#   - tests/fixtures/m027-p00/perf-10mb.jsonl.gen.sh
#
# Bash 3.2 compatible. MEM004 carve-out — pipes/$()/awk permitted.

set -u

NAME="m027-p00-bash32-compat.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ROLLUP="$PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh"
PERF_GEN="$PROJECT_ROOT/tests/fixtures/m027-p00/perf-10mb.jsonl.gen.sh"
VERIFY_GLOB="$PROJECT_ROOT/scripts/verify/m027-p00-*.sh"

# Split-literal forbidden tokens (the scanner must not self-match on its
# own source).
FORBID_A='declare'' -A'
FORBID_B='map''file'
FORBID_C='read''array'
FORBID_D='<<''<'
FORBID_E='<''('
FORBID_F='>''('
FORBID_G='&''>'
FORBID_H='${''var''^^}'

files=""
[ -f "$ROLLUP" ] && files="$files $ROLLUP"
[ -f "$PERF_GEN" ] && files="$files $PERF_GEN"
for f in $VERIFY_GLOB; do
  [ -f "$f" ] || continue
  files="$files $f"
done

if [ -z "$files" ]; then
  printf 'FAIL: %s no files in scan set\n' "$NAME" >&2
  exit 1
fi

violations=0
scanned=0
for f in $files; do
  scanned=$((scanned + 1))
  # (a) bash -n parse
  if ! bash -n "$f" 2>"/dev/null"; then
    printf 'FAIL: %s %s parse failed\n' "$NAME" "$f" >&2
    violations=$((violations + 1))
    continue
  fi
  # (b) forbidden constructs — strip comment-only lines first.
  stripped="$(grep -v '^[[:space:]]*#' "$f")"
  for needle in "$FORBID_A" "$FORBID_B" "$FORBID_C" "$FORBID_D" "$FORBID_E" "$FORBID_F" "$FORBID_G" "$FORBID_H"; do
    if printf '%s' "$stripped" | grep -qF "$needle"; then
      printf 'FAIL: %s %s contains forbidden construct [%s]\n' "$NAME" "$f" "$needle" >&2
      violations=$((violations + 1))
    fi
  done
done

if [ "$violations" -ne 0 ]; then
  printf 'FAIL: %s %d violation(s) across %d file(s)\n' "$NAME" "$violations" "$scanned" >&2
  exit 1
fi

printf 'PASS: %s scanned=%d files clean\n' "$NAME" "$scanned"
exit 0
