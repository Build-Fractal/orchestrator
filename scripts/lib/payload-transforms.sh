#!/usr/bin/env bash
# scripts/lib/payload-transforms.sh — Pure payload transform functions.
# All functions take stdin/arguments and return stdout. No file I/O.
# Sourced by build-context.sh, compress-payload.sh, and test harnesses.
#
# Functions:
#   estimate_tokens <text>        — chars/4, rounded to nearest 100
#   raw_token_count <text>        — chars/4, unrounded
#   assemble_section <heading>    — stdin body → ## Heading\n\nbody
#   drop_by_priority <priority>   — stdin sections → filtered sections
#   summarize_section <max_words> — stdin text → truncated subsections
#   drop_lowest_confidence [--keep N] — stdin entries → sorted, trimmed
#
# Bash 3.2 compatible (NFR-200). No jq required.

# --- Double-sourcing guard (NFR-203 / AP-003) ---
[ -n "${_PAYLOAD_TRANSFORMS_SOURCED:-}" ] && return 0
_PAYLOAD_TRANSFORMS_SOURCED=1

# estimate_tokens <text>
# Token estimate: character count / 4, rounded to nearest 100.
# Returns "100" minimum when input is non-empty.
estimate_tokens() {
  local text="$1"
  local chars
  chars=$(printf '%s' "$text" | wc -c | tr -d ' ')
  local raw_tokens=$((chars / 4))
  local rounded=$(( ((raw_tokens + 50) / 100) * 100 ))
  if [ "$rounded" -eq 0 ] && [ "$raw_tokens" -gt 0 ]; then
    rounded=100
  fi
  printf '%s\n' "$rounded"
}

# raw_token_count <text>
# Raw token count: character count / 4, no rounding.
raw_token_count() {
  local text="$1"
  local chars
  chars=$(printf '%s' "$text" | wc -c | tr -d ' ')
  printf '%s\n' $((chars / 4))
}

# assemble_section <heading>
# Reads body from stdin, emits formatted section on stdout.
# Output: ## <heading>\n\n<body>
assemble_section() {
  local heading="$1"
  local body
  body="$(cat)"
  printf '## %s\n\n%s\n' "$heading" "$body"
}

# drop_by_priority <priority_to_drop>
# Reads pipe-delimited section records from stdin.
# Input format per line: name|content|priority
# Drops lines where field 3 matches <priority_to_drop>.
# Emits remaining lines on stdout in same format.
drop_by_priority() {
  local target_priority="$1"
  while IFS= read -r line || [ -n "$line" ]; do
    local pri
    pri="$(printf '%s' "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $3); print $3}')"
    if [ "$pri" != "$target_priority" ]; then
      printf '%s\n' "$line"
    fi
  done
}

# summarize_section <max_words>
# Reads section text from stdin. Truncates each ### subsection to
# <max_words> words, appending "[...truncated...]" when content is cut.
# Non-subsection content passes through unchanged.
# Emits result on stdout.
summarize_section() {
  local max_words="${1:-200}"
  awk -v max="$max_words" '
    /^### / {
      if (in_sub && word_count > max) {
        printf "\n[...truncated...]\n"
      }
      in_sub = 1
      word_count = 0
      print
      next
    }
    /^## / {
      if (in_sub && word_count > max) {
        printf "\n[...truncated...]\n"
      }
      in_sub = 0
      word_count = 0
      print
      next
    }
    {
      if (in_sub) {
        n = split($0, words, " ")
        if (word_count + n <= max) {
          print
          word_count += n
        } else if (word_count < max) {
          remaining = max - word_count
          out = ""
          for (i = 1; i <= remaining && i <= n; i++) {
            if (i > 1) out = out " "
            out = out words[i]
          }
          print out
          word_count = max
        }
      } else {
        print
      }
    }
    END {
      if (in_sub && word_count > max) {
        printf "\n[...truncated...]\n"
      }
    }
  '
}

# drop_lowest_confidence [--keep N]
# Reads knowledge entries from stdin. Entries are frontmatter-delimited
# blocks (each starting with ---). Parses confidence: field from each
# entry's frontmatter. Sorts entries by confidence ascending.
#
# If --keep N is specified, emits only the N highest-confidence entries.
# Otherwise emits all entries sorted by confidence ascending (caller
# decides how many to drop by piping through head/tail).
#
# Output: entries on stdout, one per block, separated by blank lines.
# Stderr: prints count of entries parsed for caller diagnostics.
drop_lowest_confidence() {
  local keep=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --keep) keep="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  # Collect all entries with their confidence values.
  local entries=""
  local current_entry=""
  local current_conf="0.90"
  local in_fm=0
  local entry_count=0
  local conf_index=""

  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$line" = "---" ]; then
      if [ "$in_fm" -eq 0 ]; then
        if [ -n "$current_entry" ]; then
          conf_index="${conf_index}${current_conf}	${entry_count}
"
          eval "_pt_entry_${entry_count}=\$(printf '%s' \"\$current_entry\")"
          entry_count=$((entry_count + 1))
          current_entry=""
          current_conf="0.90"
        fi
        in_fm=1
      else
        in_fm=0
      fi
      current_entry="${current_entry}${line}
"
    elif [ "$in_fm" -eq 1 ] && printf '%s' "$line" | grep -q '^confidence:'; then
      current_conf="$(printf '%s' "$line" | sed 's/^confidence:[[:space:]]*//')"
      current_entry="${current_entry}${line}
"
    else
      current_entry="${current_entry}${line}
"
    fi
  done

  # Save last entry
  if [ -n "$current_entry" ]; then
    conf_index="${conf_index}${current_conf}	${entry_count}
"
    eval "_pt_entry_${entry_count}=\$(printf '%s' \"\$current_entry\")"
    entry_count=$((entry_count + 1))
  fi

  printf '%s entries parsed\n' "$entry_count" >&2

  if [ "$entry_count" -eq 0 ]; then
    return 0
  fi

  # Sort by confidence ascending
  local sorted
  sorted="$(printf '%s' "$conf_index" | sort -t'	' -k1 -n)"

  # Determine how many to emit
  local emit_start=0
  if [ -n "$keep" ] && [ "$keep" -lt "$entry_count" ]; then
    emit_start=$((entry_count - keep))
  fi

  # Emit entries
  local line_idx=0
  local first_emitted=true
  while IFS= read -r conf_line; do
    [ -z "$conf_line" ] && continue
    if [ "$line_idx" -ge "$emit_start" ]; then
      local eidx
      eidx="$(printf '%s' "$conf_line" | awk -F'	' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}')"
      local entry_var="_pt_entry_${eidx}"
      if [ "$first_emitted" = true ]; then
        first_emitted=false
      else
        printf '\n'
      fi
      eval "printf '%s' \"\$${entry_var}\""
    fi
    line_idx=$((line_idx + 1))
  done <<EOF_SORTED
$sorted
EOF_SORTED
  printf '\n'
}
