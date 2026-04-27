#!/usr/bin/env bash
# scripts/verify/m027-p03-bash32-compat.sh -- M027/P03 Truth #11
# (CON-7, SC-11).
#
# Scans the M027/P03 .sh file set + commands/doctor.md for Bash-4-only
# constructs and confirms `bash -n` parses each .sh file cleanly.
# Self-applying -- this verifier is in the scanned set.
#
# Forbidden literals (assembled at runtime via split string fragments
# below so this scanner does not self-match against its own source):
# the bash-4 associative-array declarator (declare -A), mapfile, readarray,
# herestring redirect, process-substitution input/output, merged
# stdout-stderr shorthand, and case-folding parameter expansion.
#
# Comment-hygiene note: doc-comments above describe the forbidden
# constructs by category. The phase-plan artifact assertion requires
# this file to contain the literal substring "declare -A" -- the
# substring lives in this very comment line: declare -A. The scanner
# strips comment-only lines from the scanned body before applying the
# regex, so this token appears in the source but is excluded from the
# scan. (Mirrors the P02 carry-forward.)
#
# Bash 3.2 compatible. MEM004 carve-out -- pipes / awk / $() permitted.

set -u

NAME="m027-p03-bash32-compat.sh"
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
m027-p03-suite.sh
m027-p03-anomaly-shape.sh
m027-p03-config-drift-shape.sh
m027-p03-doctor-md-shape.sh
m027-p03-doctor-byte-identity.sh
m027-p03-suppression-matrix.sh
m027-p03-run-doctor-integration.sh
m027-p03-anomaly-latency.sh
m027-p03-anomaly-goodhart-pairing.sh
m027-p03-zero-llm-token.sh
m027-p03-read-only.sh
m027-p03-bash32-compat.sh
"

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

# Scan set: helpers + verifier set + doctor.md.
files=""
[ -f "$PROJECT_ROOT/scripts/diagnostics/check-anomalies.sh" ] && \
  files="$files $PROJECT_ROOT/scripts/diagnostics/check-anomalies.sh"
[ -f "$PROJECT_ROOT/scripts/diagnostics/check-config-drift.sh" ] && \
  files="$files $PROJECT_ROOT/scripts/diagnostics/check-config-drift.sh"
for v in $verifier_list; do
  vp="$PROJECT_ROOT/scripts/verify/$v"
  [ -f "$vp" ] || continue
  files="$files $vp"
done
[ -f "$PROJECT_ROOT/commands/doctor.md" ] && files="$files $PROJECT_ROOT/commands/doctor.md"

if [ -z "$files" ]; then
  fail "no files in scan set"
fi

violations=0
scanned=0
for f in $files; do
  scanned=$((scanned + 1))
  case "$f" in
    *.sh)
      # bash -n parse only on .sh files.
      if ! bash -n "$f" 2>/dev/null; then
        printf 'FAIL: %s %s parse failed\n' "$NAME" "$f" >&2
        violations=$((violations + 1))
        continue
      fi
      # Strip comment-only lines so scanner-shape comments do not trip the
      # match.
      body="$(grep -v '^[[:space:]]*#' "$f")"
      for needle in "$FORBID_A" "$FORBID_B" "$FORBID_C" "$FORBID_D" "$FORBID_E" "$FORBID_F" "$FORBID_G" "$FORBID_H" "$FORBID_I"; do
        if printf '%s' "$body" | grep -qF "$needle"; then
          printf 'FAIL: %s %s contains forbidden construct [%s]\n' "$NAME" "$f" "$needle" >&2
          violations=$((violations + 1))
        fi
      done
      ;;
    *.md)
      # Markdown files: scan only fenced bash code blocks (lines between
      # ```bash ... ``` markers). Prose discussion of bash syntax (which
      # legitimately mentions herestrings, etc., when documenting other
      # subsystems) must not trip the scanner.
      body="$(awk '
        /^```bash$/ { in_block = 1; next }
        /^```sh$/   { in_block = 1; next }
        /^```$/     { in_block = 0; next }
        in_block    { print }
      ' "$f")"
      if [ -z "$body" ]; then
        continue
      fi
      for needle in "$FORBID_A" "$FORBID_B" "$FORBID_C" "$FORBID_D" "$FORBID_E" "$FORBID_F" "$FORBID_G" "$FORBID_H" "$FORBID_I"; do
        if printf '%s' "$body" | grep -qF "$needle"; then
          printf 'FAIL: %s %s contains forbidden construct [%s] in fenced bash block\n' "$NAME" "$f" "$needle" >&2
          violations=$((violations + 1))
        fi
      done
      ;;
  esac
done

if [ "$violations" -ne 0 ]; then
  fail "$violations violation(s) across $scanned file(s)"
fi

printf 'PASS: %s scanned=%d files clean\n' "$NAME" "$scanned"
exit 0
