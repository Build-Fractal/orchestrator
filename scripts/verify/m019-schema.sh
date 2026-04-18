#!/usr/bin/env bash
# scripts/verify/m019-schema.sh — M019 JSONL schema validator.
#
# Usage: m019-schema.sh <execution-log.jsonl>
#
# Enforces (M019/P01):
#   - Valid JSONL (one JSON object per non-empty line).
#   - If a line has "record_type", its value must be one of:
#       payload_breakdown | dispatch_usage | unit_close
#   - If a line has "source", value must be: estimate | runtime (SC-4).
#   - unit_close records: "granularity" must be task|phase|milestone,
#     AND the record must contain both a cost block (estimated_cost_usd AND
#     pricing_version keys present, even if null) AND a quality block
#     (verification_pass_rate, deviation_count, retry_count all present).
#   - Pre-M019 records (no "record_type" field) are NOT rejected (SC-10
#     additivity).
#
# Emits one line per violation on stderr in the form:
#   FAIL: <file>:<lineno> <reason>
# Emits "PASS: m019-schema.sh <N> records validated" on stdout on green.
# Exit 0 on all-pass, 1 on any failure.
#
# Bash 3.2 compatible (MEM004 carve-out: awk/grep permitted).

set -u

RECORD_TYPES="payload_breakdown dispatch_usage unit_close"
SOURCES="estimate runtime"
GRANULARITIES="task phase milestone"
UNIT_CLOSE_REQUIRED="estimated_cost_usd pricing_version verification_pass_rate deviation_count retry_count"

m019_usage() {
  printf 'Usage: %s <jsonl-file>\n' "$0" >&2
}

if [ "$#" -lt 1 ]; then
  m019_usage
  exit 2
fi

file="$1"

if [ ! -e "$file" ]; then
  printf 'FAIL: %s file not found\n' "$file" >&2
  exit 1
fi

if [ ! -r "$file" ]; then
  printf 'FAIL: %s file not readable\n' "$file" >&2
  exit 1
fi

_m019_extract_string_field() {
  # $1 = line, $2 = field name. Prints the captured quoted value, or empty.
  local line="$1"
  local field="$2"
  printf '%s' "$line" | grep -oE "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
    | head -n 1 \
    | sed -E "s/^\"${field}\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/"
}

_m019_has_key() {
  # $1 = line, $2 = key. Returns 0 if the line contains "key": ...
  local line="$1"
  local key="$2"
  printf '%s' "$line" | grep -qE "\"${key}\"[[:space:]]*:"
}

_m019_in_set() {
  # $1 = needle, $2 = space-separated whitelist
  local needle="$1"
  local set="$2"
  local item
  for item in $set; do
    if [ "$item" = "$needle" ]; then
      return 0
    fi
  done
  return 1
}

fail_count=0
record_count=0
lineno=0

while IFS= read -r line || [ -n "$line" ]; do
  lineno=$(( lineno + 1 ))

  # Strip trailing CR (possible on Windows-authored fixtures).
  line="${line%$'\r'}"
  # Skip empty / whitespace-only lines.
  case "$line" in
    '') continue ;;
    *[![:space:]]*) : ;;
    *) continue ;;
  esac

  # Basic JSON shape: starts with `{`, ends with `}`.
  first_char="${line:0:1}"
  last_char="${line: -1}"
  if [ "$first_char" != "{" ] || [ "$last_char" != "}" ]; then
    printf 'FAIL: %s:%d not-json\n' "$file" "$lineno" >&2
    fail_count=$(( fail_count + 1 ))
    continue
  fi

  record_count=$(( record_count + 1 ))

  record_type="$(_m019_extract_string_field "$line" "record_type")"

  if [ -z "$record_type" ]; then
    # Pre-M019 record: additivity rule — do not reject.
    continue
  fi

  if ! _m019_in_set "$record_type" "$RECORD_TYPES"; then
    printf 'FAIL: %s:%d invalid-record_type=%s\n' "$file" "$lineno" "$record_type" >&2
    fail_count=$(( fail_count + 1 ))
    continue
  fi

  # source enum (if present)
  if _m019_has_key "$line" "source"; then
    source_val="$(_m019_extract_string_field "$line" "source")"
    if [ -n "$source_val" ]; then
      if ! _m019_in_set "$source_val" "$SOURCES"; then
        printf 'FAIL: %s:%d invalid-source=%s\n' "$file" "$lineno" "$source_val" >&2
        fail_count=$(( fail_count + 1 ))
        continue
      fi
    fi
  fi

  # unit_close: granularity enum + mandatory cost+quality pairing
  if [ "$record_type" = "unit_close" ]; then
    granularity="$(_m019_extract_string_field "$line" "granularity")"
    if [ -z "$granularity" ]; then
      printf 'FAIL: %s:%d unit_close-missing-granularity\n' "$file" "$lineno" >&2
      fail_count=$(( fail_count + 1 ))
      continue
    fi
    if ! _m019_in_set "$granularity" "$GRANULARITIES"; then
      printf 'FAIL: %s:%d invalid-granularity=%s\n' "$file" "$lineno" "$granularity" >&2
      fail_count=$(( fail_count + 1 ))
      continue
    fi

    missing_key=""
    for key in $UNIT_CLOSE_REQUIRED; do
      if ! _m019_has_key "$line" "$key"; then
        missing_key="$key"
        break
      fi
    done
    if [ -n "$missing_key" ]; then
      printf 'FAIL: %s:%d unit_close-missing-%s\n' "$file" "$lineno" "$missing_key" >&2
      fail_count=$(( fail_count + 1 ))
      continue
    fi
  fi
done < "$file"

if [ "$fail_count" -gt 0 ]; then
  printf 'FAIL: m019-schema.sh %d violations across %d records\n' "$fail_count" "$record_count" >&2
  exit 1
fi

printf 'PASS: m019-schema.sh %d records validated\n' "$record_count"
exit 0
