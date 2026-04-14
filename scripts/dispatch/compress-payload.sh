#!/usr/bin/env bash
# scripts/dispatch/compress-payload.sh — Recipe-driven payload compression
[ -n "${_COMPRESS_PAYLOAD_SOURCED:-}" ] && return 0
_COMPRESS_PAYLOAD_SOURCED=1
#
# Reads the compression: block from templates/context-recipe.yaml (or the
# recipe supplied via --recipe) and applies each step in order until the
# payload fits the token budget. When no recipe is available, falls back to
# the hardcoded 3-step sequence for standalone compatibility — preserving the
# pre-refactor behavior byte-for-byte against the default recipe.
#
# Usage: compress-payload.sh [--budget TOKENS] [--input FILE|-] [--recipe FILE]
#   --budget: target token budget (default: 30000, ~120,000 characters)
#   --input:  read payload from file or '-' for stdin (default: stdin)
#   --recipe: override recipe path (default: templates/context-recipe.yaml)
#
# Output: compressed payload on stdout (with rebuilt manifest).
# Stderr: EVENT:/RESULT: lines + stats "Compressed: X -> Y tokens (removed: ...)"
# Exit 0 on success.
#
# Compression strategy (default recipe, applied in order until under budget):
#   1. drop_optional — drop sections marked "optional" in the manifest
#   2. summarize — truncate upstream summary subsections to max_words
#   3. drop_lowest_confidence — drop knowledge entries with lowest confidence
#   NEVER truncates the task plan section.
#
# Bash 3.2 compatible. Standalone-capable. Implements FR-212 + Principle X.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

. "$PROJECT_ROOT/scripts/lib/errors.sh"
. "$PROJECT_ROOT/scripts/lib/events.sh"
. "$PROJECT_ROOT/scripts/lib/run-context.sh"
. "$PROJECT_ROOT/scripts/lib/recipe-parser.sh"
. "$PROJECT_ROOT/scripts/lib/payload-transforms.sh"
. "$PROJECT_ROOT/scripts/lib/manifest-builder.sh"

# --- Result emission on exit (stderr, not stdout) ---
_CP_RESULT_EMITTED=0
_cp_final_result() {
  local rc=$?
  if [ "$_CP_RESULT_EMITTED" -eq 0 ]; then
    if [ "$rc" -eq 0 ]; then
      emit_result ok "" "payload compressed" >&2
    else
      emit_result error CONFIG "compress-payload rc=$rc" >&2
    fi
    _CP_RESULT_EMITTED=1
  fi
}
trap _cp_final_result EXIT

# --- Defaults ---
TOKEN_BUDGET=30000
INPUT_FILE=""
RECIPE_FILE=""

# --- Argument parsing ---
while [ $# -gt 0 ]; do
  case "$1" in
    --budget)
      TOKEN_BUDGET="$2"; shift 2 ;;
    --input)
      INPUT_FILE="$2"; shift 2 ;;
    --recipe)
      RECIPE_FILE="$2"; shift 2 ;;
    -*)
      printf 'compress-payload.sh: unknown option %s\n' "$1" >&2
      exit 1 ;;
    *)
      if [ -z "$INPUT_FILE" ]; then
        INPUT_FILE="$1"
      fi
      shift ;;
  esac
done

# --- Read payload ---
PAYLOAD=""
if [ -n "$INPUT_FILE" ] && [ "$INPUT_FILE" != "-" ] && [ -f "$INPUT_FILE" ]; then
  PAYLOAD="$(cat "$INPUT_FILE")"
else
  PAYLOAD="$(cat)"
fi

if [ -z "$PAYLOAD" ]; then
  printf 'compress-payload.sh: empty payload\n' >&2
  exit 0
fi

# Initialize run context in standalone mode. _orch_run_nonce uses a
# tr|head pipeline that can trigger SIGPIPE under pipefail, so we drop
# pipefail around the init_run_context call (see P05/T02 workaround,
# queued for P06 run-context.sh fix).
if [ -z "${ORCH_RUN_ID:-}" ]; then
  set +o pipefail
  init_run_context || true
  set -o pipefail
fi

emit_event DISPATCH_START stage=compress budget="$TOKEN_BUDGET" >&2
printf 'EVENT-AUDIT:DISPATCH_START stage="compress"\n' >&2


# --- Check if already under budget ---
ORIGINAL_TOKENS=$(raw_token_count "$PAYLOAD")

if [ "$ORIGINAL_TOKENS" -le "$TOKEN_BUDGET" ]; then
  printf '%s\n' "$PAYLOAD"
  printf 'Compressed: %s tokens -> %s tokens (already under budget)\n' \
    "$ORIGINAL_TOKENS" "$ORIGINAL_TOKENS" >&2
  exit 0
fi

# ============================================================================
# Parse the payload into sections using ## headings (pure bash, no awk redirection)
# ============================================================================

TMPDIR_COMP="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_COMP"; _cp_final_result' EXIT

removed_optional=0
removed_knowledge=0

# First: extract the manifest table to learn known section names and priorities
manifest_lines=$(echo "$PAYLOAD" | sed -n '/^## Manifest/,/^## [^M]/p' | head -50)

# Parse manifest to find section names and priorities
optional_sections=""
known_sections=""
while IFS= read -r mline; do
  # Skip non-data rows
  if ! echo "$mline" | grep -qE '^\|[[:space:]]*[A-Za-z]'; then
    continue
  fi
  # Skip the total row
  if echo "$mline" | grep -q '\*\*Total\*\*'; then
    continue
  fi
  # Extract section name and priority
  local_sec_name=$(echo "$mline" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}')
  local_sec_pri=$(echo "$mline" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $5); print $5}')

  if [ "$local_sec_pri" = "optional" ]; then
    if [ -z "$optional_sections" ]; then
      optional_sections="$local_sec_name"
    else
      optional_sections="$optional_sections|$local_sec_name"
    fi
  fi

  # Track all known section names for splitting
  # Strip parenthetical suffixes like "(8 entries)" for matching
  local_base_name=$(echo "$local_sec_name" | sed 's/ ([^)]*)//')
  if [ -z "$known_sections" ]; then
    known_sections="$local_base_name"
  else
    known_sections="$known_sections|$local_base_name"
  fi
done <<EOF_MANIFEST
$manifest_lines
EOF_MANIFEST

# Build a check function: is this ## heading a known top-level section?
is_known_section() {
  local heading="$1"
  IFS='|' read -ra KS <<< "$known_sections"
  for ks in "${KS[@]}"; do
    if [ "$heading" = "$ks" ]; then
      return 0
    fi
  done
  # Also match "Manifest" as preamble
  if [ "$heading" = "Manifest" ]; then
    return 0
  fi
  return 1
}

# Split payload into preamble (before first known ##) and sections (known ## Heading blocks)
# using pure bash line-by-line parsing. ## headings NOT in the manifest are treated as
# content within the current section (e.g. ## Must-Haves inside Scope section).
in_section=false
sec_idx=0
current_file="$TMPDIR_COMP/preamble.txt"

while IFS= read -r line || [ -n "$line" ]; do
  if [[ "$line" =~ ^##\  ]]; then
    heading_text=$(echo "$line" | sed 's/^## //')
    if is_known_section "$heading_text"; then
      # Manifest is part of the preamble
      if [ "$heading_text" = "Manifest" ]; then
        echo "$line" >> "$current_file"
        continue
      fi
      # Start a new top-level section
      if [ "$in_section" = true ]; then
        sec_idx=$((sec_idx + 1))
      fi
      in_section=true
      current_file="$TMPDIR_COMP/section_${sec_idx}.txt"
      echo "$line" > "$current_file"
    else
      # Not a known section heading -- treat as content within current section
      echo "$line" >> "$current_file"
    fi
  else
    echo "$line" >> "$current_file"
  fi
done <<EOF_PAYLOAD
$PAYLOAD
EOF_PAYLOAD

sec_total=$((sec_idx + 1))
# If we never entered a section, sec_total is 1 but section_0 might not exist
if [ "$in_section" = false ]; then
  sec_total=0
fi

# Identify sections by reading their ## heading lines
sec_names=""
sec_files_ordered=""
for i in $(seq 0 $((sec_total - 1))); do
  sf="$TMPDIR_COMP/section_${i}.txt"
  if [ -f "$sf" ]; then
    heading=$(head -1 "$sf" | sed 's/^## //')
    if [ -z "$sec_names" ]; then
      sec_names="$heading"
      sec_files_ordered="$sf"
    else
      sec_names="$sec_names|$heading"
      sec_files_ordered="$sec_files_ordered|$sf"
    fi
  fi
done

# ============================================================================
# Compression step functions (called by recipe dispatcher or fallback)
# ============================================================================

# _cp_step_drop_optional
# Drops sections whose name matches an entry in $optional_sections.
# Reads/writes $current_tokens, $removed_optional.
_cp_step_drop_optional() {
  [ -z "$optional_sections" ] && return 0

  IFS='|' read -ra OPT_SECS <<< "$optional_sections"
  IFS='|' read -ra ALL_NAMES <<< "$sec_names"
  IFS='|' read -ra ALL_FILES <<< "$sec_files_ordered"

  local opt_name idx name sfile sec_tokens
  for opt_name in "${OPT_SECS[@]}"; do
    for idx in "${!ALL_NAMES[@]}"; do
      name="${ALL_NAMES[$idx]}"
      if echo "$name" | grep -qi "^${opt_name}"; then
        sfile="${ALL_FILES[$idx]}"
        if [ -f "$sfile" ]; then
          sec_tokens=$(raw_token_count "$(cat "$sfile")")
          rm -f "$sfile"
          current_tokens=$((current_tokens - sec_tokens))
          removed_optional=$((removed_optional + 1))
        fi
        break
      fi
    done
    if [ "$current_tokens" -le "$TOKEN_BUDGET" ]; then
      break
    fi
  done
}

# _cp_step_summarize <target_section_substring> <max_words>
# Truncates each ### subsection of the matching section to <max_words> words.
# Reads/writes $current_tokens.
_cp_step_summarize() {
  local target="${1:-upstream}"
  local max_words="${2:-200}"

  IFS='|' read -ra ALL_NAMES <<< "$sec_names"
  IFS='|' read -ra ALL_FILES <<< "$sec_files_ordered"

  local idx name sfile old_content old_tokens new_content new_tokens
  for idx in "${!ALL_NAMES[@]}"; do
    name="${ALL_NAMES[$idx]}"
    if echo "$name" | grep -qi "$target"; then
      sfile="${ALL_FILES[$idx]}"
      if [ -f "$sfile" ]; then
        old_content=$(cat "$sfile")
        old_tokens=$(raw_token_count "$old_content")

        # Truncate each ### subsection to max_words words
        new_content=$(awk -v max="$max_words" '
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
        ' "$sfile")

        echo "$new_content" > "$sfile"
        new_tokens=$(raw_token_count "$new_content")
        current_tokens=$((current_tokens - old_tokens + new_tokens))
      fi
      break
    fi
  done
}

# _cp_step_drop_lowest_confidence <target_section_substring> [min_confidence]
# Splits the target section on --- frontmatter boundaries, sorts entries by
# confidence ascending, removes lowest until under budget. If min_confidence
# is non-empty, stops dropping when the next entry's confidence >= threshold.
# Reads/writes $current_tokens, $removed_knowledge.
_cp_step_drop_lowest_confidence() {
  local target="${1:-knowledge}"
  local min_conf="${2:-}"

  IFS='|' read -ra ALL_NAMES <<< "$sec_names"
  IFS='|' read -ra ALL_FILES <<< "$sec_files_ordered"

  local idx name sfile
  for idx in "${!ALL_NAMES[@]}"; do
    name="${ALL_NAMES[$idx]}"
    if echo "$name" | grep -qi "$target"; then
      sfile="${ALL_FILES[$idx]}"
      if [ -f "$sfile" ]; then
        # Split knowledge entries using bash (each entry starts with ---)
        # Parse entries by tracking frontmatter boundaries
        local local_entry_idx=0
        local local_in_fm=0
        local local_buf=""
        local local_conf="0.90"
        local local_header_lines=""
        local local_past_header=false

        # Clear any previous k_ files
        rm -f "$TMPDIR_COMP"/k_conf.txt "$TMPDIR_COMP"/k_entry_*.txt "$TMPDIR_COMP"/k_header.txt

        while IFS= read -r kline || [ -n "$kline" ]; do
          # Capture section header lines (## Heading, <!-- comments -->)
          if [ "$local_past_header" = false ]; then
            if [[ "$kline" =~ ^##\  ]] || [[ "$kline" =~ ^\<\!-- ]] || [ -z "$kline" ]; then
              local_header_lines="${local_header_lines}${kline}
"
              continue
            fi
            local_past_header=true
          fi

          if [ "$kline" = "---" ]; then
            if [ "$local_in_fm" -eq 0 ]; then
              # Starting frontmatter. If we have a previous entry, save it.
              if [ -n "$local_buf" ]; then
                echo "${local_conf}	${local_entry_idx}" >> "$TMPDIR_COMP/k_conf.txt"
                printf '%s' "$local_buf" > "$TMPDIR_COMP/k_entry_${local_entry_idx}.txt"
                local_entry_idx=$((local_entry_idx + 1))
                local_buf=""
                local_conf="0.90"
              fi
              local_in_fm=1
            else
              local_in_fm=0
            fi
            local_buf="${local_buf}${kline}
"
          elif [ "$local_in_fm" -eq 1 ] && echo "$kline" | grep -q '^confidence:'; then
            local_conf=$(echo "$kline" | sed 's/^confidence:[[:space:]]*//')
            local_buf="${local_buf}${kline}
"
          else
            local_buf="${local_buf}${kline}
"
          fi
        done < "$sfile"

        # Save last entry
        if [ -n "$local_buf" ]; then
          echo "${local_conf}	${local_entry_idx}" >> "$TMPDIR_COMP/k_conf.txt"
          printf '%s' "$local_buf" > "$TMPDIR_COMP/k_entry_${local_entry_idx}.txt"
        fi

        # Save header
        if [ -n "$local_header_lines" ]; then
          printf '%s' "$local_header_lines" > "$TMPDIR_COMP/k_header.txt"
        fi

        # Sort entries by confidence ascending and remove lowest until under budget
        if [ -f "$TMPDIR_COMP/k_conf.txt" ]; then
          local sorted_entries
          sorted_entries=$(sort -t'	' -k1 -n "$TMPDIR_COMP/k_conf.txt")

          # Note: min_conf is accepted for recipe compatibility but is NOT
          # enforced as a drop threshold here. The pre-refactor script used
          # pure "drop until under budget" semantics with no confidence gate,
          # and byte-for-byte parity against the default recipe requires
          # preserving that. A threshold-guarded variant can be re-introduced
          # in P06 once the recipe-migration pattern settles; for now the
          # field is intentionally inert. Referenced here to silence
          # unused-parameter noise under strict modes:
          : "${min_conf:-}"

          local conf_line eidx efile entry_tokens
          while IFS= read -r conf_line; do
            if [ "$current_tokens" -le "$TOKEN_BUDGET" ]; then
              break
            fi
            eidx=$(echo "$conf_line" | awk -F'\t' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}')

            efile="$TMPDIR_COMP/k_entry_${eidx}.txt"
            if [ -f "$efile" ]; then
              entry_tokens=$(raw_token_count "$(cat "$efile")")
              rm -f "$efile"
              current_tokens=$((current_tokens - entry_tokens))
              removed_knowledge=$((removed_knowledge + 1))
            fi
          done <<EOF_SORTED
$sorted_entries
EOF_SORTED

          # Rebuild knowledge section from remaining entries
          local k_header=""
          if [ -f "$TMPDIR_COMP/k_header.txt" ]; then
            k_header=$(cat "$TMPDIR_COMP/k_header.txt")
          fi
          local rebuilt=""
          local kf
          for kf in "$TMPDIR_COMP"/k_entry_*.txt; do
            if [ -f "$kf" ]; then
              if [ -z "$rebuilt" ]; then
                rebuilt=$(cat "$kf")
              else
                rebuilt="$rebuilt
$(cat "$kf")"
              fi
            fi
          done

          if [ -n "$k_header" ] && [ -n "$rebuilt" ]; then
            printf '%s\n%s\n' "$k_header" "$rebuilt" > "$sfile"
          elif [ -n "$rebuilt" ]; then
            printf '## Knowledge\n\n%s\n' "$rebuilt" > "$sfile"
          else
            printf '## Knowledge\n\nNo knowledge entries in scope.\n' > "$sfile"
          fi
        fi
      fi
      break
    fi
  done
}

# ============================================================================
# Recipe-driven step dispatcher + hardcoded fallback
# ============================================================================

# Resolve recipe: honor --recipe, else default to templates/context-recipe.yaml
if [ -z "$RECIPE_FILE" ]; then
  RECIPE_FILE="$PROJECT_ROOT/templates/context-recipe.yaml"
fi

current_tokens=$ORIGINAL_TOKENS

# _cp_run_recipe_steps
# Reads compression steps from the recipe and applies them in order until
# budget is met. Falls back to hardcoded sequence when the recipe is missing
# or empty so standalone operation is preserved.
_cp_run_recipe_steps() {
  if [ ! -f "$RECIPE_FILE" ]; then
    emit_event SAFETY_WARNING reason=recipe_not_found path="$RECIPE_FILE" >&2
    printf 'EVENT-AUDIT:SAFETY_WARNING reason="recipe_not_found"\n' >&2
    _cp_run_fallback_steps
    return
  fi

  local steps_file
  steps_file="$(mktemp)"
  parse_recipe_compression "$RECIPE_FILE" > "$steps_file" 2>/dev/null || true

  if [ ! -s "$steps_file" ]; then
    rm -f "$steps_file"
    emit_event SAFETY_WARNING reason=recipe_compression_empty path="$RECIPE_FILE" >&2
    printf 'EVENT-AUDIT:SAFETY_WARNING reason="recipe_compression_empty"\n' >&2
    _cp_run_fallback_steps
    return
  fi

  local step_key c_type c_target c_maxw c_minc c_desc
  while IFS='|' read -r step_key c_type c_target c_maxw c_minc c_desc; do
    [ -z "$step_key" ] && continue
    if [ "$current_tokens" -le "$TOKEN_BUDGET" ]; then
      break
    fi

    case "$c_type" in
      drop_optional)
        _cp_step_drop_optional
        ;;
      summarize)
        _cp_step_summarize "${c_target:-upstream}" "${c_maxw:-200}"
        ;;
      drop_lowest_confidence)
        _cp_step_drop_lowest_confidence "${c_target:-knowledge}" "${c_minc:-}"
        ;;
      *)
        emit_event SAFETY_WARNING reason=unknown_compression_step_type original_type="$c_type" >&2
        printf 'EVENT-AUDIT:SAFETY_WARNING reason="unknown_compression_step_type"\n' >&2
        ;;
    esac
  done < "$steps_file"
  rm -f "$steps_file"
}

# _cp_run_fallback_steps
# Hardcoded 3-step sequence matching pre-refactor behavior. Invoked when the
# recipe is missing, empty, or parse-failed.
_cp_run_fallback_steps() {
  if [ "$current_tokens" -gt "$TOKEN_BUDGET" ]; then
    _cp_step_drop_optional
  fi
  if [ "$current_tokens" -gt "$TOKEN_BUDGET" ]; then
    _cp_step_summarize "upstream" 200
  fi
  if [ "$current_tokens" -gt "$TOKEN_BUDGET" ]; then
    _cp_step_drop_lowest_confidence "knowledge" ""
  fi
}

_cp_run_recipe_steps

# ============================================================================
# Rebuild the payload with updated manifest
# ============================================================================

# Extract just the frontmatter block (--- ... ---)
fm_block=$(echo "$PAYLOAD" | awk '/^---$/{n++; print; if(n==2) exit; next} n>=1{print}')

# Extract title line
title_line=$(echo "$PAYLOAD" | grep '^# Dispatch Context' || true)

# Collect remaining sections and build new manifest
IFS='|' read -ra ALL_NAMES <<< "$sec_names"
IFS='|' read -ra ALL_FILES <<< "$sec_files_ordered"

remaining_names=""
remaining_priorities=""
remaining_files=""

for idx in "${!ALL_NAMES[@]}"; do
  sfile="${ALL_FILES[$idx]}"
  if [ -f "$sfile" ]; then
    sname="${ALL_NAMES[$idx]}"

    # Determine priority
    pri="required"
    if echo "$sname" | grep -qi "knowledge\|decisions"; then
      pri="filtered"
    fi
    if [ -n "$optional_sections" ]; then
      IFS='|' read -ra OPT_CHECK <<< "$optional_sections"
      for oc in "${OPT_CHECK[@]}"; do
        if echo "$sname" | grep -qi "^${oc}"; then
          pri="optional"
          break
        fi
      done
    fi

    if [ -z "$remaining_names" ]; then
      remaining_names="$sname"
      remaining_priorities="$pri"
      remaining_files="$sfile"
    else
      remaining_names="$remaining_names|$sname"
      remaining_priorities="$remaining_priorities|$pri"
      remaining_files="$remaining_files|$sfile"
    fi
  fi
done

# Build the new manifest
IFS='|' read -ra REM_NAMES <<< "$remaining_names"
IFS='|' read -ra REM_PRIS <<< "$remaining_priorities"
IFS='|' read -ra REM_FILES <<< "$remaining_files"

fm_line_count=$(echo "$fm_block" | wc -l | tr -d ' ')
rem_count=${#REM_NAMES[@]}
# Overhead: fm_block + blank + title + "## Manifest" + header_row + separator_row + data_rows + total_row + blank
manifest_overhead=$((fm_line_count + 1 + 1 + 1 + 1 + 1 + rem_count + 1 + 1))

current_line=$((manifest_overhead + 1))
new_manifest_table="| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|"
new_total_tokens=0

for idx in "${!REM_NAMES[@]}"; do
  sfile="${REM_FILES[$idx]}"
  sname="${REM_NAMES[$idx]}"
  sec_pri="${REM_PRIS[$idx]}"

  sec_lines=$(wc -l < "$sfile" | tr -d ' ')
  sec_content=$(cat "$sfile")
  sec_tokens=$(estimate_tokens "$sec_content")
  end_line=$((current_line + sec_lines - 1))

  new_manifest_table="$new_manifest_table
| $sname | ${current_line}-${end_line} | ~${sec_tokens} | $sec_pri |"
  new_total_tokens=$((new_total_tokens + sec_tokens))
  current_line=$((end_line + 2))
done

new_manifest_table="$new_manifest_table
| **Total** | | **~${new_total_tokens}** | |"

# Assemble final compressed payload
COMPRESSED="$fm_block

$title_line
## Manifest
$new_manifest_table
"

for idx in "${!REM_FILES[@]}"; do
  sfile="${REM_FILES[$idx]}"
  if [ -f "$sfile" ]; then
    COMPRESSED="$COMPRESSED
$(cat "$sfile")
"
  fi
done

printf '%s\n' "$COMPRESSED"

# --- Report compression stats ---
FINAL_TOKENS=$(raw_token_count "$COMPRESSED")
printf 'Compressed: %s tokens -> %s tokens (removed: %s optional, %s knowledge entries)\n' \
  "$ORIGINAL_TOKENS" "$FINAL_TOKENS" "$removed_optional" "$removed_knowledge" >&2
