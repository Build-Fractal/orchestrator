#!/usr/bin/env bash
# scripts/verify/m012-p01-bash32-compat.sh — scans P01-touched .sh files
# for Bash 4+ features that break macOS stock bash 3.2.
#
# Target set:
#   scripts/wiki/*.sh
#   scripts/verify/m012-p01-*.sh   (self-inclusive)
#
# Forbidden patterns (match non-comment code only; lines starting with
# optional whitespace then `#` are treated as comments and skipped):
#   declare -A                (associative array)
#   mapfile                   (Bash 4)
#   readarray                 (Bash 4)
#   ${var^^} / ${var^} / ${var,,} / ${var,}   (case-modification)
#   <(cmd)                    (process substitution — input)
#   >(cmd)                    (process substitution — output)
#   &>                        (Bash 4 merge redirect)
#
# Exit 0 if no violations. Exit 1 on any hit, emitting one
# `FAIL: m012-p01-bash32-compat <file>:<line> <pattern>` per offence.
# Emits `PASS: m012-p01-bash32-compat <N> files scanned, 0 violations`.
#
# Self-note: the forbidden-pattern regexes are embedded in variables so that
# they don't appear as literal tokens in a scanned line of THIS script. The
# comment filter also suppresses the documentation block above. Bash 3.2
# compatible — no Bash 4 features used in this script.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

FAIL_COUNT=0
FILE_COUNT=0

TMP_FILES="/tmp/m012-p01-compat-files-$$.list"
trap 'rm -f "$TMP_FILES"' EXIT INT TERM

: > "$TMP_FILES"
if [ -d "$ROOT/scripts/wiki" ]; then
  find "$ROOT/scripts/wiki" -type f -name '*.sh' 2>/dev/null >> "$TMP_FILES"
fi
find "$ROOT/scripts/verify" -maxdepth 1 -type f -name 'm012-p01-*.sh' 2>/dev/null >> "$TMP_FILES"

# Deduplicate and sort.
sort -u "$TMP_FILES" > "${TMP_FILES}.s"
mv "${TMP_FILES}.s" "$TMP_FILES"

# Pattern registry. Each pattern has:
#   label       — human-friendly tag printed in FAIL lines.
#   grep_pat    — extended-regex pattern passed to grep -nE.
# We keep patterns in parallel arrays (bash 3.2 safe — no declare -A).
PAT_LABELS_0="declare-A"
PAT_REGEX_0='declare[[:space:]]+-[Aa]'
PAT_LABELS_1="mapfile"
PAT_REGEX_1='[^[:alnum:]_]mapfile[[:space:]]|^mapfile[[:space:]]'
PAT_LABELS_2="readarray"
PAT_REGEX_2='[^[:alnum:]_]readarray[[:space:]]|^readarray[[:space:]]'
PAT_LABELS_3="case-modify"
# ${var^^} or ${var,,} etc. Use octal escapes to avoid putting the literal
# tokens in the pattern source (keeps a self-scan from flagging this file).
# Construct pattern at runtime from pieces.
_CARET=$(printf '\136')     # ^
_COMMA=$(printf '\054')     # ,
PAT_REGEX_3='\$\{[A-Za-z_][A-Za-z0-9_]*('"$_CARET$_CARET"'|'"$_CARET"'|'"$_COMMA$_COMMA"'|'"$_COMMA"')\}'
PAT_LABELS_4="proc-sub-in"
PAT_REGEX_4='<\('
PAT_LABELS_5="proc-sub-out"
PAT_REGEX_5='>\('
PAT_LABELS_6="merge-redirect"
PAT_REGEX_6='[^0-9&]&>'
PAT_COUNT=7

scan_file() {
  _f="$1"
  _i=0
  while [ "$_i" -lt "$PAT_COUNT" ]; do
    eval "_lab=\$PAT_LABELS_${_i}"
    eval "_pat=\$PAT_REGEX_${_i}"
    # Skip pure comment lines (optional whitespace + #) via inverse grep
    # chained in pipeline: grep -nE pattern | filter out comments.
    grep -nE "$_pat" "$_f" 2>/dev/null | while IFS= read -r hit; do
      # hit = "N:line-contents"
      _line_no=$(printf '%s' "$hit" | sed 's/:.*//')
      _content=$(printf '%s' "$hit" | sed 's/^[0-9]*://')
      # Skip comment lines (optional leading ws + #).
      case "$_content" in
        ""|\#*) continue ;;
        [[:space:]]*\#*)
          _trim=$(printf '%s' "$_content" | sed 's/^[[:space:]]*//')
          case "$_trim" in
            \#*) continue ;;
          esac
          ;;
      esac
      # Skip lines that are self-referential pattern definitions in this
      # scanner (PAT_REGEX_*= assignments). These are data, not executable
      # Bash 4 features. Match the PAT_REGEX_ or PAT_LABELS_ token.
      case "$_content" in
        *PAT_REGEX_*=*|*PAT_LABELS_*=*) continue ;;
      esac
      printf 'FAIL: m012-p01-bash32-compat %s:%s %s\n' "${_f#$ROOT/}" "$_line_no" "$_lab"
      # NOTE: FAIL_COUNT cannot be mutated from inside this pipeline subshell;
      # we track hits via a sentinel file instead.
      printf '1\n' >> "/tmp/m012-p01-compat-hits-$$.list"
    done
    _i=$((_i + 1))
  done
}

: > "/tmp/m012-p01-compat-hits-$$.list"

while IFS= read -r f; do
  [ -n "$f" ] || continue
  FILE_COUNT=$((FILE_COUNT + 1))
  scan_file "$f"
done < "$TMP_FILES"

HITS=$(wc -l < "/tmp/m012-p01-compat-hits-$$.list" 2>/dev/null | tr -d ' ')
rm -f "/tmp/m012-p01-compat-hits-$$.list"
[ -z "$HITS" ] && HITS=0

if [ "$HITS" -eq 0 ]; then
  printf 'PASS: m012-p01-bash32-compat %s files scanned, 0 violations\n' "$FILE_COUNT"
  exit 0
fi
printf 'FAIL: m012-p01-bash32-compat %s violation(s) across %s file(s)\n' "$HITS" "$FILE_COUNT"
exit 1
