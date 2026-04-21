#!/usr/bin/env bash
# scripts/verify/m012-p04-index-finalized.sh — M012/P04 T01 gate.
#
# Asserts wiki/docs/index.md carries the finalized home page:
#   - contains the four required orientation headings
#   - links to the five required stub routes
#   - does NOT contain the literal word "placeholder"
#   - stays within [40, 120] lines (orientation prose, not a dump)
#
# Maps to US1 / SC-3 / Constitution VI. Bash 3.2 compatible.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DEFAULT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
ROOT="${1:-$DEFAULT_ROOT}"

IDX="$ROOT/wiki/docs/index.md"
if [ ! -f "$IDX" ]; then
  printf 'FAIL: %s not found\n' "$IDX" >&2
  exit 1
fi

# Reject any lingering placeholder language from the P01 scaffold.
if grep -qiF 'placeholder' "$IDX"; then
  printf 'FAIL: %s still contains "placeholder"\n' "$IDX" >&2
  exit 1
fi

lines=$(wc -l < "$IDX" | tr -d '[:space:]')
if [ -z "$lines" ]; then
  lines=0
fi
if [ "$lines" -lt 40 ] || [ "$lines" -gt 120 ]; then
  printf 'FAIL: %s line count %s out of range [40,120]\n' "$IDX" "$lines" >&2
  exit 1
fi

# Four required orientation headings (substring match tolerates level variance).
for heading in 'What this site is' 'How to navigate' 'Where to comment' 'Audience scope'; do
  if ! grep -qF "$heading" "$IDX"; then
    printf 'FAIL: %s missing heading "%s"\n' "$IDX" "$heading" >&2
    exit 1
  fi
done

# Five stub-route targets the home page links to.
for link in 'constitution' 'decisions' 'knowledge' 'milestone-summary' 'milestones'; do
  if ! grep -qF "$link" "$IDX"; then
    printf 'FAIL: %s missing link target "%s"\n' "$IDX" "$link" >&2
    exit 1
  fi
done

printf 'PASS: index finalized (%s lines, 4 headings, 5 links)\n' "$lines"
exit 0
