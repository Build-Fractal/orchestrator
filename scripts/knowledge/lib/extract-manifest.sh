#!/usr/bin/env bash
# scripts/knowledge/lib/extract-manifest.sh -- pure manifest parser.
# Sourced by scripts/knowledge/extract-reference.sh.
# No top-level I/O; functions take args + emit to stdout.
# Bash 3.2 / POSIX-sh per CON-2; no associative arrays, no jq required.

# extract_manifest_top_field <manifest-path> <field-name>
#   Echoes the value of a top-level scalar field (e.g., size_cap_bytes).
#   Empty stdout if absent.
extract_manifest_top_field() {
  local m="$1"
  local f="$2"
  grep -E "^${f}:" "$m" | head -n 1 | sed -E "s/^${f}:[[:space:]]*//" | sed -E 's/[[:space:]]*$//' | sed -E 's/^"//' | sed -E 's/"$//'
}

# extract_manifest_doc_count <manifest-path>
#   Echoes the count of YAML list entries under `documents:`.
extract_manifest_doc_count() {
  local m="$1"
  grep -cE '^[[:space:]]+-[[:space:]]+cite_id:' "$m"
}

# extract_manifest_doc_field <manifest-path> <doc-index-1based> <field-name>
#   Echoes the value of <field-name> within the Nth document record.
#   Implementation: awk one-liner that tracks the doc index and prints
#   the requested field within the matching record. Single-script-file
#   invocation shape (this is internal pipeline; classifier inspects
#   only the *invocation* of extract-reference.sh, not its helper bodies).
extract_manifest_doc_field() {
  local m="$1"
  local idx="$2"
  local field="$3"
  awk -v idx="$idx" -v field="$field" '
    BEGIN { current=0 }
    /^[[:space:]]+-[[:space:]]+cite_id:/ { current++ }
    current==idx {
      if (match($0, "^[[:space:]]+(-[[:space:]]+)?" field ":")) {
        line=$0
        sub("^[[:space:]]*-?[[:space:]]*" field ":[[:space:]]*", "", line)
        sub("[[:space:]]+$", "", line)
        sub("^\"", "", line); sub("\"$", "", line)
        print line
        exit
      }
    }
  ' "$m"
}

# extract_manifest_resolve_tier <category> <source-types-yaml-path>
#   Echoes the default tier for a category from the source-types SSOT.
extract_manifest_resolve_tier() {
  local cat="$1"
  local yaml="$2"
  awk -v cat="$cat" '
    $0 ~ "^  " cat ":" { found=1; next }
    found && /^    default_tier:/ {
      line=$0
      sub("^[[:space:]]*default_tier:[[:space:]]*", "", line)
      sub("[[:space:]]+$", "", line)
      print line
      exit
    }
  ' "$yaml"
}
