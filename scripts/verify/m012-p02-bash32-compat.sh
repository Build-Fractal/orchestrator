#!/usr/bin/env bash
# scripts/verify/m012-p02-bash32-compat.sh — M012/P02 gate 8.
#
# Scans every .sh file touched or created by P02 for Bash 4-only constructs.
# Targets:
#   - scripts/diagnostics/wiki-link-check.sh
#   - scripts/verify/m012-p02-*.sh
#   - scripts/wiki/wiki-scan-sources.sh
#   - scripts/wiki/wiki-generate-stubs.sh
#   - scripts/wiki/wiki-generate-nav.sh
#
# Forbidden: declare -A, mapfile, readarray, ${var^^}, ${var,,},
# <(...), >(...), &>.
#
# Uses parallel indexed arrays (PAT_REGEX_N / PAT_LABEL_N) so the
# scanner itself stays Bash 3.2 compatible. Comment lines and this
# script's own pattern-assignment lines are carved out so self-scan
# does not false-positive.
#
# Bash 3.2 compatible.

set -u

ROOT="${1:-$(pwd)}"

targets="/tmp/m012-p02-bash32.$$"
: > "$targets"
printf '%s\n' "$ROOT/scripts/diagnostics/wiki-link-check.sh" >> "$targets"
find "$ROOT/scripts/verify" -type f -name 'm012-p02-*.sh' 2>/dev/null >> "$targets"
printf '%s\n' "$ROOT/scripts/wiki/wiki-scan-sources.sh" >> "$targets"
printf '%s\n' "$ROOT/scripts/wiki/wiki-generate-stubs.sh" >> "$targets"
printf '%s\n' "$ROOT/scripts/wiki/wiki-generate-nav.sh" >> "$targets"

PAT_REGEX_0='declare -A'
PAT_LABEL_0='declare -A (Bash 4 associative array)'
PAT_REGEX_1='mapfile'
PAT_LABEL_1='mapfile (Bash 4 builtin)'
PAT_REGEX_2='readarray'
PAT_LABEL_2='readarray (Bash 4 builtin)'
PAT_REGEX_3='\$\{[A-Za-z_][A-Za-z0-9_]*\^\^\}'
PAT_LABEL_3='${var^^} (Bash 4 uppercase expansion)'
PAT_REGEX_4='\$\{[A-Za-z_][A-Za-z0-9_]*,,\}'
PAT_LABEL_4='${var,,} (Bash 4 lowercase expansion)'
PAT_REGEX_5='<\('
PAT_LABEL_5='<(...) (process substitution)'
PAT_REGEX_6='>\('
PAT_LABEL_6='>(...) (process substitution)'
PAT_REGEX_7='&>'
PAT_LABEL_7='&> (Bash 4 merge redirect)'

fails="/tmp/m012-p02-bash32-fails.$$"
: > "$fails"

while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ -f "$f" ] || continue
  i=0
  while [ "$i" -le 7 ]; do
    eval "rx=\"\$PAT_REGEX_$i\""
    eval "lbl=\"\$PAT_LABEL_$i\""
    # Strip comment-prefixed lines and the carve-out for this script's own
    # PAT_REGEX_ / PAT_LABEL_ assignment lines so self-scan stays clean.
    hits=$(grep -nE "$rx" "$f" 2>/dev/null \
             | grep -v '^[0-9]*:[[:space:]]*#' \
             | grep -v 'PAT_REGEX_' \
             | grep -v 'PAT_LABEL_')
    if [ -n "$hits" ]; then
      printf '%s\n' "$hits" | while IFS= read -r hit; do
        [ -n "$hit" ] || continue
        printf 'FAIL: %s — %s: %s\n' "$f" "$lbl" "$hit" >> "$fails"
      done
    fi
    i=$((i + 1))
  done
done < "$targets"
rm -f "$targets"

if [ -s "$fails" ]; then
  cat "$fails"
  rm -f "$fails"
  exit 1
fi
rm -f "$fails"

printf 'PASS: all P02 .sh files are Bash 3.2 compatible\n'
exit 0
