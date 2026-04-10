#!/usr/bin/env bash
# scripts/dispatch/compress-payload.sh — Compress dispatch payload to fit token budget
# When the assembled payload exceeds a configurable token budget, applies graduated
# compression: drop optional sections, summarize upstream, drop low-confidence knowledge.
#
# Usage: compress-payload.sh [--budget TOKENS] [--input FILE|-]
#   --budget: target token budget (default: 30000, ~120,000 characters)
#   --input: read payload from file (default: stdin)
#
# Output: compressed payload to stdout (with rebuilt manifest)
# Stderr: compression stats "Compressed: X tokens -> Y tokens (removed: Z optional, W knowledge entries)"
# Exit 0 on success.
#
# Compression strategy (applied in order until under budget):
#   1. Drop sections marked "optional" in the manifest
#   2. Summarize verbose upstream summaries (truncate to first 200 words each)
#   3. Drop lowest-confidence knowledge entries (remove entries until under budget)
#   NEVER truncates the task plan section.
#
# Bash 3.2 compatible.

set -euo pipefail

# --- Defaults ---
TOKEN_BUDGET=30000
INPUT_FILE=""

# --- Argument parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --budget)
      TOKEN_BUDGET="$2"; shift 2 ;;
    --input)
      INPUT_FILE="$2"; shift 2 ;;
    -*)
      echo "compress-payload.sh: unknown option '$1'" >&2; exit 1 ;;
    *)
      if [[ -z "$INPUT_FILE" ]]; then
        INPUT_FILE="$1"
      fi
      shift ;;
  esac
done

# --- Read input ---
PAYLOAD=""
if [[ -n "$INPUT_FILE" && "$INPUT_FILE" != "-" && -f "$INPUT_FILE" ]]; then
  PAYLOAD=$(cat "$INPUT_FILE")
else
  PAYLOAD=$(cat)
fi

if [[ -z "$PAYLOAD" ]]; then
  echo "compress-payload.sh: empty payload" >&2
  exit 0
fi

# --- Token estimation: chars / 4, rounded to nearest 100 ---
estimate_tokens() {
  local text="$1"
  local chars
  chars=$(printf '%s' "$text" | wc -c | tr -d ' ')
  local raw_tokens=$((chars / 4))
  local rounded=$(( ((raw_tokens + 50) / 100) * 100 ))
  if [[ "$rounded" -eq 0 && "$raw_tokens" -gt 0 ]]; then
    rounded=100
  fi
  echo "$rounded"
}

# Raw token count (not rounded, for comparison)
raw_token_count() {
  local text="$1"
  local chars
  chars=$(printf '%s' "$text" | wc -c | tr -d ' ')
  echo $((chars / 4))
}

# --- Check if already under budget ---
ORIGINAL_TOKENS=$(raw_token_count "$PAYLOAD")

if [[ "$ORIGINAL_TOKENS" -le "$TOKEN_BUDGET" ]]; then
  echo "$PAYLOAD"
  echo "Compressed: $ORIGINAL_TOKENS tokens -> $ORIGINAL_TOKENS tokens (already under budget)" >&2
  exit 0
fi

# ============================================================================
# Parse the payload into sections using ## headings (pure bash, no awk redirection)
# ============================================================================

TMPDIR_COMP="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_COMP"' EXIT

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

  if [[ "$local_sec_pri" = "optional" ]]; then
    if [[ -z "$optional_sections" ]]; then
      optional_sections="$local_sec_name"
    else
      optional_sections="$optional_sections|$local_sec_name"
    fi
  fi

  # Track all known section names for splitting
  # Strip parenthetical suffixes like "(8 entries)" for matching
  local_base_name=$(echo "$local_sec_name" | sed 's/ ([^)]*)//')
  if [[ -z "$known_sections" ]]; then
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
    if [[ "$heading" = "$ks" ]]; then
      return 0
    fi
  done
  # Also match "Manifest" as preamble
  if [[ "$heading" = "Manifest" ]]; then
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

while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" =~ ^##\  ]]; then
    heading_text=$(echo "$line" | sed 's/^## //')
    if is_known_section "$heading_text"; then
      # Manifest is part of the preamble
      if [[ "$heading_text" = "Manifest" ]]; then
        echo "$line" >> "$current_file"
        continue
      fi
      # Start a new top-level section
      if [[ "$in_section" = true ]]; then
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
if [[ "$in_section" = false ]]; then
  sec_total=0
fi

# Identify sections by reading their ## heading lines
sec_names=""
sec_files_ordered=""
for i in $(seq 0 $((sec_total - 1))); do
  sf="$TMPDIR_COMP/section_${i}.txt"
  if [[ -f "$sf" ]]; then
    heading=$(head -1 "$sf" | sed 's/^## //')
    if [[ -z "$sec_names" ]]; then
      sec_names="$heading"
      sec_files_ordered="$sf"
    else
      sec_names="$sec_names|$heading"
      sec_files_ordered="$sec_files_ordered|$sf"
    fi
  fi
done

# ============================================================================
# Step 1: Drop optional sections
# ============================================================================

current_tokens=$ORIGINAL_TOKENS

if [[ "$current_tokens" -gt "$TOKEN_BUDGET" && -n "$optional_sections" ]]; then
  IFS='|' read -ra OPT_SECS <<< "$optional_sections"
  IFS='|' read -ra ALL_NAMES <<< "$sec_names"
  IFS='|' read -ra ALL_FILES <<< "$sec_files_ordered"

  for opt_name in "${OPT_SECS[@]}"; do
    for idx in "${!ALL_NAMES[@]}"; do
      name="${ALL_NAMES[$idx]}"
      if echo "$name" | grep -qi "^${opt_name}"; then
        sfile="${ALL_FILES[$idx]}"
        if [[ -f "$sfile" ]]; then
          sec_tokens=$(raw_token_count "$(cat "$sfile")")
          rm -f "$sfile"
          current_tokens=$((current_tokens - sec_tokens))
          removed_optional=$((removed_optional + 1))
        fi
        break
      fi
    done
    if [[ "$current_tokens" -le "$TOKEN_BUDGET" ]]; then
      break
    fi
  done
fi

# ============================================================================
# Step 2: Summarize verbose upstream summaries (truncate to 200 words each)
# ============================================================================

if [[ "$current_tokens" -gt "$TOKEN_BUDGET" ]]; then
  IFS='|' read -ra ALL_NAMES <<< "$sec_names"
  IFS='|' read -ra ALL_FILES <<< "$sec_files_ordered"

  for idx in "${!ALL_NAMES[@]}"; do
    name="${ALL_NAMES[$idx]}"
    if echo "$name" | grep -qi "upstream"; then
      sfile="${ALL_FILES[$idx]}"
      if [[ -f "$sfile" ]]; then
        old_content=$(cat "$sfile")
        old_tokens=$(raw_token_count "$old_content")

        # Truncate each ### subsection to 200 words
        new_content=$(awk '
          /^### / {
            if (in_sub && word_count > 200) {
              printf "\n[...truncated...]\n"
            }
            in_sub = 1
            word_count = 0
            print
            next
          }
          /^## / {
            if (in_sub && word_count > 200) {
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
              if (word_count + n <= 200) {
                print
                word_count += n
              } else if (word_count < 200) {
                remaining = 200 - word_count
                out = ""
                for (i = 1; i <= remaining && i <= n; i++) {
                  if (i > 1) out = out " "
                  out = out words[i]
                }
                print out
                word_count = 200
              }
            } else {
              print
            }
          }
          END {
            if (in_sub && word_count > 200) {
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
fi

# ============================================================================
# Step 3: Drop lowest-confidence knowledge entries
# ============================================================================

if [[ "$current_tokens" -gt "$TOKEN_BUDGET" ]]; then
  IFS='|' read -ra ALL_NAMES <<< "$sec_names"
  IFS='|' read -ra ALL_FILES <<< "$sec_files_ordered"

  for idx in "${!ALL_NAMES[@]}"; do
    name="${ALL_NAMES[$idx]}"
    if echo "$name" | grep -qi "knowledge"; then
      sfile="${ALL_FILES[$idx]}"
      if [[ -f "$sfile" ]]; then
        # Split knowledge entries using bash (each entry starts with ---)
        # Parse entries by tracking frontmatter boundaries
        local_entry_idx=0
        local_in_fm=0
        local_buf=""
        local_conf="0.90"
        local_header_lines=""
        local_past_header=false

        # Clear any previous k_ files
        rm -f "$TMPDIR_COMP"/k_conf.txt "$TMPDIR_COMP"/k_entry_*.txt "$TMPDIR_COMP"/k_header.txt

        while IFS= read -r kline || [[ -n "$kline" ]]; do
          # Capture section header lines (## Knowledge, <!-- comments -->)
          if [[ "$local_past_header" = false ]]; then
            if [[ "$kline" =~ ^##\  ]] || [[ "$kline" =~ ^\<\!-- ]] || [[ -z "$kline" ]]; then
              local_header_lines="${local_header_lines}${kline}
"
              continue
            fi
            local_past_header=true
          fi

          if [[ "$kline" = "---" ]]; then
            if [[ "$local_in_fm" -eq 0 ]]; then
              # Starting frontmatter. If we have a previous entry, save it.
              if [[ -n "$local_buf" ]]; then
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
          elif [[ "$local_in_fm" -eq 1 ]] && echo "$kline" | grep -q '^confidence:'; then
            local_conf=$(echo "$kline" | sed 's/^confidence:[[:space:]]*//')
            local_buf="${local_buf}${kline}
"
          else
            local_buf="${local_buf}${kline}
"
          fi
        done < "$sfile"

        # Save last entry
        if [[ -n "$local_buf" ]]; then
          echo "${local_conf}	${local_entry_idx}" >> "$TMPDIR_COMP/k_conf.txt"
          printf '%s' "$local_buf" > "$TMPDIR_COMP/k_entry_${local_entry_idx}.txt"
        fi

        # Save header
        if [[ -n "$local_header_lines" ]]; then
          printf '%s' "$local_header_lines" > "$TMPDIR_COMP/k_header.txt"
        fi

        # Sort entries by confidence ascending and remove lowest until under budget
        if [[ -f "$TMPDIR_COMP/k_conf.txt" ]]; then
          sorted_entries=$(sort -t'	' -k1 -n "$TMPDIR_COMP/k_conf.txt")

          while IFS= read -r conf_line; do
            if [[ "$current_tokens" -le "$TOKEN_BUDGET" ]]; then
              break
            fi
            eidx=$(echo "$conf_line" | awk -F'\t' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}')
            efile="$TMPDIR_COMP/k_entry_${eidx}.txt"
            if [[ -f "$efile" ]]; then
              entry_tokens=$(raw_token_count "$(cat "$efile")")
              rm -f "$efile"
              current_tokens=$((current_tokens - entry_tokens))
              removed_knowledge=$((removed_knowledge + 1))
            fi
          done <<EOF_SORTED
$sorted_entries
EOF_SORTED

          # Rebuild knowledge section from remaining entries
          k_header=""
          if [[ -f "$TMPDIR_COMP/k_header.txt" ]]; then
            k_header=$(cat "$TMPDIR_COMP/k_header.txt")
          fi
          rebuilt=""
          for kf in "$TMPDIR_COMP"/k_entry_*.txt; do
            if [[ -f "$kf" ]]; then
              if [[ -z "$rebuilt" ]]; then
                rebuilt=$(cat "$kf")
              else
                rebuilt="$rebuilt
$(cat "$kf")"
              fi
            fi
          done

          if [[ -n "$k_header" && -n "$rebuilt" ]]; then
            printf '%s\n%s\n' "$k_header" "$rebuilt" > "$sfile"
          elif [[ -n "$rebuilt" ]]; then
            printf '## Knowledge\n\n%s\n' "$rebuilt" > "$sfile"
          else
            printf '## Knowledge\n\nNo knowledge entries in scope.\n' > "$sfile"
          fi
        fi
      fi
      break
    fi
  done
fi

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
  if [[ -f "$sfile" ]]; then
    sname="${ALL_NAMES[$idx]}"

    # Determine priority
    pri="required"
    if echo "$sname" | grep -qi "knowledge\|decisions"; then
      pri="filtered"
    fi
    if [[ -n "$optional_sections" ]]; then
      IFS='|' read -ra OPT_CHECK <<< "$optional_sections"
      for oc in "${OPT_CHECK[@]}"; do
        if echo "$sname" | grep -qi "^${oc}"; then
          pri="optional"
          break
        fi
      done
    fi

    if [[ -z "$remaining_names" ]]; then
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
  if [[ -f "$sfile" ]]; then
    COMPRESSED="$COMPRESSED
$(cat "$sfile")
"
  fi
done

echo "$COMPRESSED"

# --- Report compression stats ---
FINAL_TOKENS=$(raw_token_count "$COMPRESSED")
echo "Compressed: $ORIGINAL_TOKENS tokens -> $FINAL_TOKENS tokens (removed: $removed_optional optional, $removed_knowledge knowledge entries)" >&2
