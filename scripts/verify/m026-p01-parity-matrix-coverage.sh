#!/usr/bin/env bash
# m026-p01-parity-matrix-coverage.sh
# Asserts: matrix carries ≥16 data rows AND each of the 4 smoke-confirmed
# drift rows carries `confirmed 2026-04-23` in its Notes cell.
# Bash 3.2 safe. Single-script-file shape per AD-19.

set -euo pipefail

MATRIX=".orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md"
PASS=0
FAIL=0

if [ ! -f "$MATRIX" ]; then
  echo "FAIL: matrix file not found at $MATRIX"
  echo "SUMMARY: pass=0 fail=1"
  exit 1
fi

count_data_rows() {
  rows=0
  while IFS= read -r line; do
    case "$line" in
      "| Surface |"*) continue ;;
      "|---"*) continue ;;
      "|"*)
        case "$line" in
          *verified-identical*|*verified-drifted*|*verified-absent*|*verified-moot*)
            rows=$((rows + 1))
            ;;
        esac
        ;;
    esac
  done < "$MATRIX"
  echo "$rows"
}

data_rows=$(count_data_rows)
if [ "$data_rows" -ge "16" ]; then
  echo "PASS: data row count ${data_rows} >= 16"
  PASS=$((PASS + 1))
else
  echo "FAIL: data row count ${data_rows} < 16"
  FAIL=$((FAIL + 1))
fi

check_smoke_row() {
  anchor="$1"
  label="$2"
  # A smoke row is any data row whose content matches both the anchor token
  # AND "confirmed 2026-04-23". We grep single-line; markdown tables keep
  # rows on a single line, so this is safe.
  if grep -E "${anchor}" "$MATRIX" | grep -q "confirmed 2026-04-23"; then
    echo "PASS: smoke row '${label}' carries confirmed 2026-04-23"
    PASS=$((PASS + 1))
    return 0
  fi
  echo "FAIL: smoke row '${label}' missing confirmed 2026-04-23 anchor"
  FAIL=$((FAIL + 1))
  return 1
}

check_smoke_row "frontmatter rejection" "YAML frontmatter contract" || true
check_smoke_row "agents\[\]\.role.*required" "agents[].role requirement" || true
check_smoke_row "agents\[\]\.prompt:.*OSS.*vs.*agents\[\]\.system_prompt:" "prompt vs system_prompt field" || true
check_smoke_row "Top-level .output:.*object-vs-string" "output object-vs-string semantic" || true

echo "SUMMARY: pass=${PASS} fail=${FAIL}"
if [ "$FAIL" -gt "0" ]; then
  exit 1
fi
exit 0
