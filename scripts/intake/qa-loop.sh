#!/usr/bin/env bash
# scripts/intake/qa-loop.sh
# M024/P05/T02 — Bounded Q&A loop for empty-input intake (FR-5).
#
# Inputs:
#   --answers-from <file>     One answer per line; blank line or `enough` short-circuits.
#   --transcript-out <path>   Absolute path to write the transcript to.
#   --questions <path>        Optional. Defaults to templates/intake-qa-questions.md.
#
# Output (stdout, two lines):
#   qa_short_circuited=<true|false>
#   qa_turns=<count>
#
# Exit 0 on success, 2 on usage error, 1 on internal error.

set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
QUESTIONS_DEFAULT="$ROOT/templates/intake-qa-questions.md"
MAX_TURNS=5

ANSWERS_FROM=""
TRANSCRIPT_OUT=""
QUESTIONS="$QUESTIONS_DEFAULT"

usage() {
  echo "usage: qa-loop.sh --answers-from <file> --transcript-out <path> [--questions <path>]" >&2
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --answers-from)   ANSWERS_FROM="$2"; shift 2 ;;
    --transcript-out) TRANSCRIPT_OUT="$2"; shift 2 ;;
    --questions)      QUESTIONS="$2"; shift 2 ;;
    -h|--help)        usage ;;
    *)                usage ;;
  esac
done

[ -n "$ANSWERS_FROM" ]   || usage
[ -n "$TRANSCRIPT_OUT" ] || usage
[ -f "$ANSWERS_FROM" ]   || { echo "qa-loop.sh: answers file not found: $ANSWERS_FROM" >&2; exit 1; }
[ -f "$QUESTIONS" ]      || { echo "qa-loop.sh: questions file not found: $QUESTIONS" >&2; exit 1; }

# Validate questions file shape — must contain ### Q1..Q5 headings.
for n in 1 2 3 4 5; do
  grep -q "^### Q$n " "$QUESTIONS" \
    || { echo "qa-loop.sh: questions file missing ### Q$n heading" >&2; exit 1; }
done

# Drain the answers file into a temp working file with at most MAX_TURNS lines
# (cap-enforcement is structural — extra lines beyond MAX_TURNS are ignored).
work=$(mktemp)
trap 'rm -f "$work"' EXIT
head -n "$MAX_TURNS" "$ANSWERS_FROM" > "$work"

# Build the transcript by iterating turn-by-turn.
: > "$TRANSCRIPT_OUT"

short_circuited="false"
turns=0
n=1

while [ "$n" -le "$MAX_TURNS" ]; do
  # Read the n-th line. sed -n 'Np' is portable.
  line=$(sed -n "${n}p" "$work")

  # Empty line or end-of-file → no answer on this turn → stop.
  if [ -z "$line" ]; then
    break
  fi

  # Trim leading/trailing whitespace for comparison; keep raw value for transcript.
  trimmed=$(echo "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

  # Short-circuit token (case-insensitive `enough`).
  lc=$(echo "$trimmed" | tr '[:upper:]' '[:lower:]')
  if [ "$lc" = "enough" ]; then
    short_circuited="true"
    break
  fi

  # Append this turn's heading + answer block.
  {
    echo "### Q$n"
    echo "$line"
    echo ""
  } >> "$TRANSCRIPT_OUT"

  turns=$((turns + 1))
  n=$((n + 1))
done

echo "qa_short_circuited=$short_circuited"
echo "qa_turns=$turns"
exit 0
