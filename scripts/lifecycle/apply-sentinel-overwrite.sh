#!/usr/bin/env bash
# scripts/lifecycle/apply-sentinel-overwrite.sh — AD-7 sentinel-scoped overwrite.
#
# Replaces the span between _generated_start and _generated_end sentinel
# JSON keys in TARGET with the span between the same sentinels in INPUT.
# Preserves everything outside the span byte-identical.
#
# Bash 3.2 compatible. No jq required.

set -eu

TARGET=""
INPUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --input)  INPUT="$2"; shift 2 ;;
    *) echo "apply-sentinel-overwrite.sh: unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$TARGET" ] || [ -z "$INPUT" ]; then
  echo "apply-sentinel-overwrite.sh: --target and --input required" >&2
  exit 1
fi

# Locate sentinel line numbers in TARGET
start_line="$(grep -n '_generated_start' "$TARGET" | head -1 | sed 's/:.*//')"
end_line="$(grep -n '_generated_end' "$TARGET" | head -1 | sed 's/:.*//')"
if [ -z "$start_line" ] || [ -z "$end_line" ]; then
  echo "apply-sentinel-overwrite.sh: sentinels not found in $TARGET" >&2
  exit 1
fi
if [ "$start_line" -ge "$end_line" ]; then
  echo "apply-sentinel-overwrite.sh: sentinel order invalid (start=$start_line end=$end_line)" >&2
  exit 1
fi

# Locate sentinel line numbers in INPUT
in_start="$(grep -n '_generated_start' "$INPUT" | head -1 | sed 's/:.*//')"
in_end="$(grep -n '_generated_end' "$INPUT" | head -1 | sed 's/:.*//')"
if [ -z "$in_start" ] || [ -z "$in_end" ]; then
  echo "apply-sentinel-overwrite.sh: sentinels not found in $INPUT" >&2
  exit 1
fi

# Build the replacement file: TARGET head (lines 1..start_line-1)
# + INPUT span (lines in_start..in_end)
# + TARGET tail (lines end_line+1..end)
tmp="$(mktemp -t ad7-overwrite.XXXXXX)"
head_end=$((start_line - 1))
tail_start=$((end_line + 1))

if [ "$head_end" -ge 1 ]; then
  sed -n "1,${head_end}p" "$TARGET" > "$tmp"
fi

# Emit the INPUT span (sentinel lines inclusive) into the replacement file.
# If the TARGET tail (lines after _generated_end) contains another JSON key
# (more top-level entries follow the generated block), the _generated_end
# line must carry a trailing comma. INPUT's _generated_end lacks one since
# it's the final key in the canonical envelope. Inject a comma when needed.
tail_has_key=0
tail_probe="$(sed -n "${tail_start},\$p" "$TARGET" | grep -c '^[[:space:]]*"')"
if [ "$tail_probe" -gt 0 ]; then
  tail_has_key=1
fi

in_before_end=$((in_end - 1))
if [ "$in_before_end" -ge "$in_start" ]; then
  sed -n "${in_start},${in_before_end}p" "$INPUT" >> "$tmp"
fi
end_line_text="$(sed -n "${in_end}p" "$INPUT")"
if [ "$tail_has_key" -eq 1 ]; then
  # Strip any existing trailing comma first, then append exactly one.
  end_line_text="${end_line_text%,}"
  printf '%s,\n' "$end_line_text" >> "$tmp"
else
  printf '%s\n' "$end_line_text" >> "$tmp"
fi

sed -n "${tail_start},\$p" "$TARGET" >> "$tmp"

mv "$tmp" "$TARGET"
echo "RESULT:ok applied sentinel-scoped overwrite to $TARGET"
