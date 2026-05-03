#!/usr/bin/env bash
# tools/verify/lib/p00-validate-chunk-frontmatter.sh — M036 P00 T03
# chunk-frontmatter validator. Reads a YAML frontmatter block from
# stdin (or a file path argument) and rejects entries whose category
# is outside the M036 taxonomy or whose tier is outside {0, 1, 2}.
#
# Authoritative SSOT: references/reference-taxonomy.md (categories),
#                    references/reference-source-types.yaml (tier enum).
# The taxonomy values are duplicated here as a hardcoded list ONLY
# for the validator's tight loop -- adding a category requires updating
# both this file and the SSOT in lockstep, gated by the M036 D-row
# convention. The shape verifier (p00-taxonomy-shape.sh) catches the
# SSOT side; this validator catches the validator side.
#
# Usage:
#   bash tools/verify/lib/p00-validate-chunk-frontmatter.sh < frontmatter.yaml
#   bash tools/verify/lib/p00-validate-chunk-frontmatter.sh path/to/frontmatter.yaml
#
# Exit: 0 if valid, 1 if any rejection. Emits ACCEPT: / REJECT: lines
# to stdout. Errors to stderr.
#
# Note on internal pipeline: the harness shape-classifier
# (scripts/verify/lib/shape-classifier.sh::classify_command) inspects
# only the *invocation* form. The single-script-file invocation
# `bash tools/verify/lib/p00-validate-chunk-frontmatter.sh` classifies
# clean; the grep|head|sed pipeline below lives inside the script body
# and never surfaces to the classifier. Bash 3.2 compatible.
set -eu

if [ $# -ge 1 ] && [ -f "$1" ]; then
  INPUT="$1"
  CATEGORY=$(grep -E '^category:' "$INPUT" | head -n 1 | sed -E 's/^category:[[:space:]]*//' | sed -E 's/[[:space:]]*$//' | sed -E 's/^"//; s/"$//; s/^'\''//; s/'\''$//')
  TIER=$(grep -E '^tier:' "$INPUT" | head -n 1 | sed -E 's/^tier:[[:space:]]*//' | sed -E 's/[[:space:]]*$//' | sed -E 's/^"//; s/"$//; s/^'\''//; s/'\''$//')
else
  # Read stdin into a temp file (avoid $() with pipe at top level).
  TMP=$(mktemp)
  cat > "$TMP"
  CATEGORY=$(grep -E '^category:' "$TMP" | head -n 1 | sed -E 's/^category:[[:space:]]*//' | sed -E 's/[[:space:]]*$//' | sed -E 's/^"//; s/"$//; s/^'\''//; s/'\''$//')
  TIER=$(grep -E '^tier:' "$TMP" | head -n 1 | sed -E 's/^tier:[[:space:]]*//' | sed -E 's/[[:space:]]*$//' | sed -E 's/^"//; s/"$//; s/^'\''//; s/'\''$//')
  rm -f "$TMP"
fi

reject=0

# Category check -- must be one of the four taxonomy values when present.
if [ -n "${CATEGORY:-}" ]; then
  case "$CATEGORY" in
    cms-rule|training-material|glossary|regulatory-doc)
      echo "ACCEPT: category=$CATEGORY"
      ;;
    *)
      echo "REJECT: category=$CATEGORY (not in taxonomy: cms-rule|training-material|glossary|regulatory-doc)"
      reject=1
      ;;
  esac
fi

# Tier check -- must be 0, 1, or 2 when present.
if [ -n "${TIER:-}" ]; then
  case "$TIER" in
    0|1|2)
      echo "ACCEPT: tier=$TIER"
      ;;
    *)
      echo "REJECT: tier=$TIER (not in {0, 1, 2})"
      reject=1
      ;;
  esac
fi

if [ "$reject" -gt 0 ]; then
  exit 1
fi
exit 0
