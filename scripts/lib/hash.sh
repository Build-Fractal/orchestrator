#!/usr/bin/env bash
# scripts/lib/hash.sh -- Content hash utility for knowledge entries.
# Provides compute_content_hash and compute_file_body_hash functions.
# Hash format: sha256:{64-hex} per AD-1 convention. Body-only hashing
# excludes YAML frontmatter so metadata changes do not alter the hash.
#
# Bash 3.2 compatible (NFR-200). No jq required.

# --- Double-sourcing guard (follows errors.sh pattern) ---
[ -n "${_HASH_SOURCED:-}" ] && return 0
_HASH_SOURCED=1

# compute_content_hash <string>
# Computes SHA-256 of the given string and returns sha256:{hex}.
# Uses shasum -a 256 (available on macOS and Linux).
# Returns empty string and exit 1 if input is empty.
compute_content_hash() {
  local content="$1"
  if [ -z "$content" ]; then
    echo ""
    return 1
  fi
  local hex
  hex="$(printf '%s' "$content" | shasum -a 256 | cut -d ' ' -f 1)"
  printf 'sha256:%s\n' "$hex"
}

# compute_file_body_hash <filepath>
# Reads a markdown file with YAML frontmatter (delimited by --- lines),
# extracts the body (everything after the closing --- delimiter), and
# computes its content hash. Returns sha256:{hex}.
# Returns empty string and exit 1 if file does not exist or has no body.
compute_file_body_hash() {
  local filepath="$1"
  if [ ! -f "$filepath" ]; then
    echo ""
    return 1
  fi
  local body=""
  local in_frontmatter=0
  local frontmatter_closed=0
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$frontmatter_closed" -eq 1 ]; then
      if [ -z "$body" ]; then
        body="$line"
      else
        body="$body
$line"
      fi
    elif [ "$in_frontmatter" -eq 0 ] && [ "$line" = "---" ]; then
      in_frontmatter=1
    elif [ "$in_frontmatter" -eq 1 ] && [ "$line" = "---" ]; then
      frontmatter_closed=1
    fi
  done < "$filepath"
  # Trim leading blank line (common after frontmatter closing ---)
  body="$(printf '%s' "$body" | sed '1{/^$/d;}')"
  if [ -z "$body" ]; then
    echo ""
    return 1
  fi
  compute_content_hash "$body"
}
