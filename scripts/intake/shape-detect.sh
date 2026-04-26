#!/usr/bin/env bash
# scripts/intake/shape-detect.sh
# M024/P01/T03 — Mechanical input-shape classifier (FR-1, resolves #Q-1).
#
# Inputs:
#   --spec-path <path>    Optional. If file exists and has `type: feature-spec`
#                         in its first 30 lines, shape is `spec`.
#   --input <string>      Optional. The raw input text.
#
# Output (stdout, two lines):
#   input_shape=<idea|paragraph|fragment|spec|empty>
#   shape_classification=<high|low>
#
# Exit 0 on success, 2 on usage error.

set -u

usage() {
  echo "usage: shape-detect.sh [--spec-path <path>] [--input <string>]" >&2
  exit 2
}

SPEC_PATH=""
INPUT=""
HAVE_INPUT_FLAG=0

while [ $# -gt 0 ]; do
  case "$1" in
    --spec-path) SPEC_PATH="$2"; shift 2 ;;
    --input)     INPUT="$2"; HAVE_INPUT_FLAG=1; shift 2 ;;
    -h|--help)   usage ;;
    *)           usage ;;
  esac
done

# Rule 1: spec path that points at a real feature spec.
if [ -n "$SPEC_PATH" ] && [ -f "$SPEC_PATH" ]; then
  if head -30 "$SPEC_PATH" | grep -q 'type: feature-spec'; then
    echo "input_shape=spec"
    echo "shape_classification=high"
    exit 0
  fi
fi

# Rule 2: empty.
# Empty means: no spec path AND (input flag absent OR input is whitespace-only).
trimmed=$(echo "$INPUT" | tr -d '[:space:]')
if [ -z "$SPEC_PATH" ] && [ -z "$trimmed" ]; then
  echo "input_shape=empty"
  echo "shape_classification=high"
  exit 0
fi

# Rule 3 / 4 / 5: structural + word-count classification.
# Word count: split on whitespace.
words=$(echo "$INPUT" | tr -s '[:space:]' '\n' | grep -c .)

# Structural markers.
has_heading=0
has_gwt=0
has_fr_bullet=0
if echo "$INPUT" | grep -qE '^##'; then has_heading=1; fi
# Given/When/Then triple-marker, case-insensitive.
if echo "$INPUT" | grep -qiE '\bGiven\b'; then
  if echo "$INPUT" | grep -qiE '\bWhen\b'; then
    if echo "$INPUT" | grep -qiE '\bThen\b'; then
      has_gwt=1
    fi
  fi
fi
if echo "$INPUT" | grep -qE '^-[[:space:]]+FR-'; then has_fr_bullet=1; fi

structural=$((has_heading + has_gwt + has_fr_bullet))

# Fragment: structural marker OR word count >= 81.
if [ "$structural" -gt 0 ] || [ "$words" -ge 81 ]; then
  conf="high"
  # Low-confidence sub-case: word-count overflow with no structural marker.
  if [ "$structural" -eq 0 ] && [ "$words" -ge 81 ]; then
    conf="low"
  fi
  echo "input_shape=fragment"
  echo "shape_classification=$conf"
  exit 0
fi

# Idea: word count <= 10.
if [ "$words" -le 10 ]; then
  conf="high"
  # Low-confidence sub-case: 8-10 word boundary.
  if [ "$words" -ge 8 ]; then
    conf="low"
  fi
  echo "input_shape=idea"
  echo "shape_classification=$conf"
  exit 0
fi

# Default: paragraph.
# Low-confidence sub-cases: stray heading, partial GWT, or word count outside 20-60.
conf="high"
partial_gwt=0
if echo "$INPUT" | grep -qiE '\bGiven\b|\bWhen\b|\bThen\b'; then
  if [ "$has_gwt" -eq 0 ]; then
    partial_gwt=1
  fi
fi
if [ "$partial_gwt" -eq 1 ] || [ "$words" -lt 20 ] || [ "$words" -gt 60 ]; then
  conf="low"
fi

echo "input_shape=paragraph"
echo "shape_classification=$conf"
exit 0
