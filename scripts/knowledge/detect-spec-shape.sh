#!/usr/bin/env bash
# scripts/knowledge/detect-spec-shape.sh
# Fast, agent-free probe classifying a markdown file as
# shape=speckit or shape=foreign based on heading-pattern probes.
#
# Usage:
#   detect-spec-shape.sh --spec-path <path>
#
# Output (stdout): one line of the form
#   shape=<speckit|foreign> reasons=<csv>
#   PASS: ...  (on success)
# On missing/unreadable input: error to stderr, exit 1.
# On success: exit 0 for both speckit and foreign outcomes.
#
# Bash 3.2 compatible. No declare -A; uses parallel indexed arrays.

set -u

SPEC_PATH=""

while [ $# -gt 0 ]; do
  case "$1" in
    --spec-path) SPEC_PATH="${2:-}"; shift 2 ;;
    *) echo "ERROR: unknown option '$1'" >&2; exit 1 ;;
  esac
done

if [ -z "$SPEC_PATH" ]; then
  echo "ERROR: --spec-path is required" >&2
  exit 1
fi

if [ ! -f "$SPEC_PATH" ] || [ ! -r "$SPEC_PATH" ]; then
  echo "ERROR: spec file not found or not readable: $SPEC_PATH" >&2
  exit 1
fi

# --- Probe families as parallel indexed arrays (MEM001) ---
probe_name_0="user_stories"
probe_re_0='^##+[[:space:]]+User[[:space:]]+Stor(y|ies)\b'

probe_name_1="functional_requirements"
probe_re_1='^##+[[:space:]]+Functional[[:space:]]+Requirements\b'

probe_name_2="acceptance"
probe_re_2='^##+[[:space:]]+Acceptance[[:space:]]+(Scenarios|Criteria)\b'

probe_name_3="non_goals_constraints_success"
probe_re_3='^##+[[:space:]]+(Non-Goals|Constraints|Success[[:space:]]+Criteria)\b'

probe_name_4="id_tags"
probe_re_4='\b(FR|US|AC|NFR)-[0-9]+\b'

probe_name_5="gherkin"
probe_re_5='^[[:space:]]*(Given|When|Then)[[:space:]]'

probe_name_6="as_a_i_want"
probe_re_6='As[[:space:]]+a[[:space:]]+.*,[[:space:]]+I[[:space:]]+want[[:space:]]+'

PROBE_COUNT=7

matched_families=""
matched_count=0

i=0
while [ $i -lt $PROBE_COUNT ]; do
  eval "name=\$probe_name_$i"
  eval "re=\$probe_re_$i"
  if grep -Eiq -- "$re" "$SPEC_PATH"; then
    if [ -z "$matched_families" ]; then
      matched_families="$name"
    else
      matched_families="$matched_families,$name"
    fi
    matched_count=$((matched_count + 1))
  fi
  i=$((i + 1))
done

if [ "$matched_count" -ge 3 ]; then
  shape="speckit"
else
  shape="foreign"
fi

printf 'shape=%s reasons=%s\n' "$shape" "$matched_families"
printf 'PASS: detect-spec-shape classified %s as shape=%s (matched=%d)\n' \
  "$SPEC_PATH" "$shape" "$matched_count"
exit 0
