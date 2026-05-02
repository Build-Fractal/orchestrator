#!/usr/bin/env bash
# tools/verify/p00-adapter-registry-shape.sh -- M036 P00 T02 shape gate
# for scripts/dispatch/adapters/format/registry.tsv. Asserts header +
# exactly four data rows for the four supported formats. Single-script-
# file shape per AD-19.
set -eu
FILE="${1:-scripts/dispatch/adapters/format/registry.tsv}"
pass=0
fail=0
if [ ! -f "$FILE" ]; then
  echo "FAIL: $FILE missing"
  echo "SUMMARY: p00-adapter-registry-shape.sh pass=0 fail=1"
  exit 1
fi
# Header check -- first line must contain the four column names.
header=$(head -n 1 "$FILE")
for col in 'format' 'adapter_path' 'status' 'notes'; do
  case "$header" in
    *"$col"*)
      pass=$((pass + 1))
      ;;
    *)
      fail=$((fail + 1))
      echo "FAIL: header missing column: $col"
      ;;
  esac
done
# Tab-anchored row check -- TAB constructed via printf so the literal
# tab character is robust against editor space-conversion of this file.
TAB=$(printf '\t')
for fmt in 'markdown' 'pdf' 'docx' 'xlsx'; do
  if grep -q "^${fmt}${TAB}" "$FILE"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: registry missing row for format: $fmt"
  fi
done
# Row count check -- must be at least 5 lines (header + 4 data rows).
line_count=$(wc -l < "$FILE")
if [ "$line_count" -ge 5 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "FAIL: registry has fewer than 5 lines (header + 4 data rows)"
fi
echo "SUMMARY: p00-adapter-registry-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
