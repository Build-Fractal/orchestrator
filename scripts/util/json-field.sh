#!/usr/bin/env bash
# scripts/util/json-field.sh — Shared JSON field extraction utility
# Provides json_field() function for grep-based JSON parsing without jq dependency.
# Source this file: source "$(dirname "${BASH_SOURCE[0]}")/../util/json-field.sh"
#
# Usage: json_field <file> <key>
# Returns the value of the first occurrence of "key" in a JSON file.
# Strips surrounding quotes, trailing commas, and whitespace.

json_field() {
  local file="$1"
  local key="$2"
  grep "\"${key}\"" "$file" 2>/dev/null \
    | head -1 \
    | sed 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*//' \
    | sed 's/^"//' \
    | sed 's/"[[:space:]]*,*[[:space:]]*$//' \
    | sed 's/,*[[:space:]]*$//' \
    | sed 's/[[:space:]]*$//'
}
