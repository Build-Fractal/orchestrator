#!/usr/bin/env bash
# scripts/verify/anti-pattern-lint.sh — Detect Class A anti-patterns in agent-facing content
# Scans commands/*.md and templates/*.md for patterns that trigger Claude Code
# safety prompts: $(…), backticks, {a,b} brace expansion.
#
# Usage: anti-pattern-lint.sh [--fixture <file>]
#   Default: scans commands/*.md and templates/*.md
#   --fixture <file>: scan only the specified file (for testing)
#
# Self-excludes its own source. Excludes ANTIPATTERNS.md.
# See AP-004 in ANTIPATTERNS.md for the canonical pattern catalog.
#
# Exit: 0 if clean, 1 if violations found.
# Bash 3.2 compatible.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- Parse arguments ---
FIXTURE_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --fixture)
      if [ $# -lt 2 ]; then
        echo "anti-pattern-lint.sh: --fixture requires a file argument" >&2
        exit 1
      fi
      FIXTURE_FILE="$2"
      shift 2
      ;;
    *)
      echo "anti-pattern-lint.sh: unknown option $1" >&2
      exit 1
      ;;
  esac
done

# --- Self-exclusion paths ---
SELF_PATH="${SCRIPT_DIR}/anti-pattern-lint.sh"
ANTIPATTERNS_PATH="${PROJECT_ROOT}/ANTIPATTERNS.md"

# --- Build file list ---
_file_list="$(mktemp)"
trap 'rm -f "$_file_list"' EXIT

if [ -n "$FIXTURE_FILE" ]; then
  printf '%s\n' "$FIXTURE_FILE" > "$_file_list"
else
  # Discover agent-facing markdown files
  find "$PROJECT_ROOT/commands" -name '*.md' -type f 2>/dev/null >> "$_file_list" || true
  find "$PROJECT_ROOT/templates" -name '*.md' -type f 2>/dev/null >> "$_file_list" || true
fi

# --- Scan each file ---
violation_count=0
# Collect violation output in a temp file to avoid subshell variable issues
_violation_out="$(mktemp)"
trap 'rm -f "$_file_list" "$_violation_out"' EXIT

while IFS= read -r file; do
  [ -z "$file" ] && continue
  [ ! -f "$file" ] && continue

  # Resolve to absolute path for comparison
  _dir="$(cd "$(dirname "$file")" && pwd)"
  _base="$(basename "$file")"
  real_file="${_dir}/${_base}"

  # Self-exclusion
  if [ "$real_file" = "$SELF_PATH" ]; then
    continue
  fi
  # ANTIPATTERNS.md exclusion
  if [ "$real_file" = "$ANTIPATTERNS_PATH" ]; then
    continue
  fi

  # Compute display path (relative to project root when possible)
  short_file="${real_file#${PROJECT_ROOT}/}"

  # Scan inside code blocks only
  in_code_block=0
  line_num=0
  _suppress_next=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))

    # Track fenced code block boundaries
    # A line starting with ``` (possibly followed by a language tag) toggles state
    case "$line" in
      '```'*)
        if [ "$in_code_block" -eq 0 ]; then
          in_code_block=1
        else
          in_code_block=0
        fi
        _suppress_next=0
        continue
        ;;
    esac

    # Only scan inside code blocks
    [ "$in_code_block" -eq 0 ] && continue

    # Skip lines with suppression markers
    case "$line" in
      *'# FORBIDDEN'*)
        # A FORBIDDEN comment suppresses this line and all following lines
        # until the next # comment/heading or blank line
        _suppress_next=1
        continue
        ;;
      *'# lint-ignore'*)
        continue
        ;;
    esac

    # If inside a FORBIDDEN-suppressed region, check if we should exit it
    if [ "$_suppress_next" -eq 1 ]; then
      # End suppression on blank lines or new # comment/heading lines
      case "$line" in
        '#'*)
          # New heading or comment — check if it is itself FORBIDDEN
          case "$line" in
            *'# FORBIDDEN'*) continue ;;  # stay suppressed
          esac
          _suppress_next=0
          # This line is the new heading itself — don't scan it, let it
          # be evaluated on next iteration by falling through
          continue
          ;;
        '')
          _suppress_next=0
          continue
          ;;
        *)
          # Still in the suppressed region (content lines after FORBIDDEN)
          continue
          ;;
      esac
    fi

    # --- Check 1: Command substitution $(...) ---
    # Match literal $( which indicates command substitution
    # This also catches nested forms like $((..)) arithmetic, but that is
    # acceptable — arithmetic expansion inside agent-facing code blocks
    # should also use wrapper scripts.
    if printf '%s\n' "$line" | grep -q '\$(' 2>/dev/null; then
      violation_count=$((violation_count + 1))
      printf '%s:%d: command substitution $(...)  [AP-004]\n' "$short_file" "$line_num" >> "$_violation_out"
      printf '  Hint: Use --output-file or a wrapper script. See AP-004 in ANTIPATTERNS.md.\n' >> "$_violation_out"
    fi

    # --- Check 2: Backtick command substitution ---
    # Flag lines with backtick-delimited content that looks like command
    # substitution in a bash context: assignment =`...` or standalone `cmd arg`
    # We require the backtick content to contain a space (multi-word = command),
    # because single-word backticks in code blocks are usually variable names.
    # Match: =`...` (assignment context) or leading/standalone `cmd ...`
    if printf '%s\n' "$line" | grep -qE '=`[^`]+`' 2>/dev/null; then
      violation_count=$((violation_count + 1))
      printf '%s:%d: backtick command substitution  [AP-004]\n' "$short_file" "$line_num" >> "$_violation_out"
      printf '  Hint: Use a wrapper script or --output-file pattern. See AP-004 in ANTIPATTERNS.md.\n' >> "$_violation_out"
    fi

    # --- Check 3: Brace expansion {word,word} ---
    # Match {word,word} but NOT ${var} parameter expansion.
    # Two-step approach for Bash 3.2 / BSD compat:
    #   1) Check if the line contains {word,word}
    #   2) Strip all ${...} parameter expansions, then re-check
    if printf '%s\n' "$line" | grep -qE '\{[A-Za-z0-9_./-]+,[A-Za-z0-9_./-]+' 2>/dev/null; then
      # Strip ${...} parameter expansions using tr-based approach (BSD sed
      # chokes on literal braces in BRE context). Replace every ${ with a
      # neutral marker so the second grep only sees bare braces.
      _stripped="$(printf '%s\n' "$line" | sed 's/\$[{]/__PEXP__/g')"
      _has_bare_brace=0
      if printf '%s\n' "$_stripped" | grep -qE '\{[A-Za-z0-9_./-]+,[A-Za-z0-9_./-]+' 2>/dev/null; then
        _has_bare_brace=1
      fi
      if [ "$_has_bare_brace" -eq 1 ]; then
        violation_count=$((violation_count + 1))
        printf '%s:%d: brace expansion {a,b}  [AP-004]\n' "$short_file" "$line_num" >> "$_violation_out"
        printf '  Hint: Use explicit arguments or a wrapper script. See AP-004 in ANTIPATTERNS.md.\n' >> "$_violation_out"
      fi
    fi

  done < "$file"

done < "$_file_list"

# --- Report results ---
if [ "$violation_count" -gt 0 ]; then
  printf 'LINT FAIL: %d violation(s) found in agent-facing content\n\n' "$violation_count"
  cat "$_violation_out"
  printf '\nSee AP-004 in ANTIPATTERNS.md for the full Class A pattern catalog.\n'
  exit 1
else
  printf 'LINT PASS: no Class A anti-patterns found in agent-facing content\n'
  exit 0
fi
