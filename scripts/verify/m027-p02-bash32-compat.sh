#!/usr/bin/env bash
# scripts/verify/m027-p02-bash32-compat.sh -- M027/P02 Truth #11
# (CON-7, SC-11).
#
# Scans the M027/P02 .sh file set + commands/status.md + commands/dispatch.md
# for Bash-4-only constructs and confirms `bash -n` parses each .sh file
# cleanly. Self-applying -- this verifier is in the scanned set.
#
# Forbidden literals (assembled at runtime via split string fragments
# below so this scanner does not self-match):
#   declare -A, mapfile, readarray, herestring, process-substitution
#   in/out, merged stdout-stderr, ${var^^}, ${var,,}
#
# Bash 3.2 compatible. MEM004 carve-out -- pipes / awk / $() permitted.

set -u

NAME="m027-p02-bash32-compat.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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
FORBID_I='${''var'',,}'

# Explicit verifier list (no globbing -- keeps the set deterministic and
# bounded).
verifier_list="
m027-p02-suite.sh
m027-p02-efficiency-footer-shape.sh
m027-p02-status-md-shape.sh
m027-p02-status-quiet-byte-identity.sh
m027-p02-predictive-surface-shape.sh
m027-p02-suppression-matrix.sh
m027-p02-dispatch-md-shape.sh
m027-p02-predictive-surface-latency.sh
m027-p02-predictive-goodhart-pairing.sh
m027-p02-zero-llm-token.sh
m027-p02-read-only.sh
m027-p02-bash32-compat.sh
"

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

# Scan set: helpers + verifier set + status.md + dispatch.md.
files=""
[ -f "$PROJECT_ROOT/scripts/diagnostics/efficiency-footer.sh" ] && \
  files="$files $PROJECT_ROOT/scripts/diagnostics/efficiency-footer.sh"
[ -f "$PROJECT_ROOT/scripts/dispatch/predictive-surface.sh" ] && \
  files="$files $PROJECT_ROOT/scripts/dispatch/predictive-surface.sh"
for v in $verifier_list; do
  vp="$PROJECT_ROOT/scripts/verify/$v"
  [ -f "$vp" ] || continue
  files="$files $vp"
done
[ -f "$PROJECT_ROOT/commands/status.md" ] && files="$files $PROJECT_ROOT/commands/status.md"
[ -f "$PROJECT_ROOT/commands/dispatch.md" ] && files="$files $PROJECT_ROOT/commands/dispatch.md"

if [ -z "$files" ]; then
  fail "no files in scan set"
fi

violations=0
scanned=0
for f in $files; do
  scanned=$((scanned + 1))
  # bash -n parse only on .sh files.
  case "$f" in
    *.sh)
      if ! bash -n "$f" 2>/dev/null; then
        printf 'FAIL: %s %s parse failed\n' "$NAME" "$f" >&2
        violations=$((violations + 1))
        continue
      fi
      ;;
  esac
  # Strip comment-only lines so scanner-shape comments do not trip the
  # match.
  body="$(grep -v '^[[:space:]]*#' "$f")"
  for needle in "$FORBID_A" "$FORBID_B" "$FORBID_C" "$FORBID_D" "$FORBID_E" "$FORBID_F" "$FORBID_G" "$FORBID_H" "$FORBID_I"; do
    if printf '%s' "$body" | grep -qF "$needle"; then
      printf 'FAIL: %s %s contains forbidden construct [%s]\n' "$NAME" "$f" "$needle" >&2
      violations=$((violations + 1))
    fi
  done
done

if [ "$violations" -ne 0 ]; then
  fail "$violations violation(s) across $scanned file(s)"
fi

printf 'PASS: %s scanned=%d files clean\n' "$NAME" "$scanned"
exit 0
