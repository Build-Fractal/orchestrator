#!/usr/bin/env bash
# scripts/knowledge/classify-reference.sh -- M036 P04 T01.
# Pure helper lib (MEM004): no top-level execution; safe to source.
# Exposes two pure functions for the reference-ingest classifier path:
#
#   classify_reference_required_fields <chunk-file>
#     Asserts FR-2 required-field presence. Returns 0 if all six fields
#     present (source, published, version, cite_id, topic_tags,
#     applies_to_field), 1 if any missing. Errors to stderr name the
#     missing field(s).
#
#   classify_reference_file <chunk-file>
#     Composes the FR-2 required-field check with the existing P00 T03
#     taxonomy + tier validator (tools/verify/lib/p00-validate-chunk-
#     frontmatter.sh). Returns 0 if both pass, 1 if either fails.
#
# Bash 3.2 / POSIX-sh per CON-2. No top-level I/O — sourceable from any
# context. AD-19: invocation form is `bash scripts/knowledge/classify-
# reference.sh` (not directly callable; lib only). The driver
# `scripts/knowledge/ingest-reference.sh` sources this file.

# Guard against accidental direct execution.
if [ "${0##*/}" = "classify-reference.sh" ] && [ -z "${BASH_SOURCE[0]:-}" -o "${BASH_SOURCE[0]:-}" = "$0" ]; then
  : # sourced; OK
fi

# classify_reference_required_fields <chunk-file>
classify_reference_required_fields() {
  local chunk="$1"
  if [ -z "$chunk" ] || [ ! -f "$chunk" ]; then
    echo "classify-reference: chunk file missing: $chunk" >&2
    return 1
  fi
  local missing=""
  for field in source published version cite_id topic_tags applies_to_field; do
    if ! grep -qE "^${field}:" "$chunk"; then
      if [ -z "$missing" ]; then
        missing="$field"
      else
        missing="$missing,$field"
      fi
    fi
  done
  if [ -n "$missing" ]; then
    echo "classify-reference: required field(s) missing in $chunk: $missing" >&2
    return 1
  fi
  return 0
}

# classify_reference_file <chunk-file>
classify_reference_file() {
  local chunk="$1"
  if [ -z "$chunk" ] || [ ! -f "$chunk" ]; then
    echo "classify-reference: chunk file missing: $chunk" >&2
    return 1
  fi
  # FR-2 required-field check.
  if ! classify_reference_required_fields "$chunk"; then
    return 1
  fi
  # FR-1 taxonomy + tier validator (delegates to existing P00 T03 lib).
  local root
  root="${ORCHESTRATOR_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
  local validator="$root/tools/verify/lib/p00-validate-chunk-frontmatter.sh"
  if [ ! -f "$validator" ]; then
    echo "classify-reference: validator missing: $validator" >&2
    return 1
  fi
  if ! bash "$validator" "$chunk" >/dev/null 2>&1; then
    echo "classify-reference: taxonomy/tier validation failed for $chunk" >&2
    return 1
  fi
  return 0
}
