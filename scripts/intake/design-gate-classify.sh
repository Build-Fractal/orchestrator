#!/usr/bin/env bash
# scripts/intake/design-gate-classify.sh
# M024/P07/T01 — Pure decision emitter for the design_gate axis (FR-1, FR-7).
#
# Inputs:
#   --input <text>       Paragraph/idea/fragment input string.
#   --spec-path <path>   Spec file path (mutually exclusive with --input).
#
# Stdout (exactly two lines on success):
#   design_gate=<none|walkthrough>
#   design_gate_confidence=<low|high>
#
# Exit 0 on success, 1 on missing spec file, 2 on usage error.

set -u

usage() {
  cat >&2 <<'EOF'
usage: design-gate-classify.sh (--input <text> | --spec-path <path>)

Scans the supplied input or spec body for design-domain tokens and emits
the design_gate axis verdict as two key=value stdout lines.

Tokens (whole-word match): ui UI render design layout screen view panel viewer dashboard interface visual theme

Verdict:
  0 hits   -> design_gate=none         design_gate_confidence=high
  1 hit    -> design_gate=walkthrough  design_gate_confidence=low
  >=2 hits -> design_gate=walkthrough  design_gate_confidence=high
EOF
  exit 2
}

INPUT=""
SPEC_PATH=""

while [ $# -gt 0 ]; do
  case "$1" in
    --input)     INPUT="$2";     shift 2 ;;
    --spec-path) SPEC_PATH="$2"; shift 2 ;;
    -h|--help)   usage ;;
    *)           usage ;;
  esac
done

# Exactly one of --input | --spec-path must be supplied.
if [ -n "$INPUT" ] && [ -n "$SPEC_PATH" ]; then usage; fi
if [ -z "$INPUT" ] && [ -z "$SPEC_PATH" ]; then usage; fi

# Resolve text source.
if [ -n "$SPEC_PATH" ]; then
  if [ ! -f "$SPEC_PATH" ]; then
    echo "ERR: spec not found at $SPEC_PATH" >&2
    exit 1
  fi
  body_file="$SPEC_PATH"
else
  body_file="$(mktemp)"
  trap 'rm -f "$body_file"' EXIT
  printf '%s' "$INPUT" > "$body_file"
fi

# Token alternation. -w on grep -E treats the alternation as whole-word
# tokens at word boundaries. Note: bash 3.2 portable; no process subst.
PATTERN='ui|UI|render|design|layout|screen|view|panel|viewer|dashboard|interface|visual|theme'

# Count distinct token hits. We scan for each token individually so that
# repeated occurrences of the same token count as one hit. The hit count
# is the number of tokens that matched at least once.
hits=0
for tok in ui UI render design layout screen view panel viewer dashboard interface visual theme; do
  if grep -qwE "$tok" "$body_file"; then
    hits=$((hits + 1))
  fi
done

# Verdict.
if [ "$hits" -eq 0 ]; then
  echo "design_gate=none"
  echo "design_gate_confidence=high"
elif [ "$hits" -eq 1 ]; then
  echo "design_gate=walkthrough"
  echo "design_gate_confidence=low"
else
  echo "design_gate=walkthrough"
  echo "design_gate_confidence=high"
fi

exit 0
