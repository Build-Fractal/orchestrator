#!/usr/bin/env bash
# m026-p01-parity-matrix-shape.sh
# Asserts: M026-CONVERSUS-PARITY.md exists, carries required frontmatter keys
# with correct values, exposes the 4 required table columns, every data row
# has a non-empty Verified cell drawn from the fixed vocabulary, and no row
# carries the scratch-matrix `VERIFY` placeholder.
# Bash 3.2 safe (MEM001). Single-script-file shape per AD-19.

set -euo pipefail

MATRIX=".orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md"
PASS=0
FAIL=0

check_exists() {
  if [ ! -f "$MATRIX" ]; then
    echo "FAIL: matrix file not found at $MATRIX"
    FAIL=$((FAIL + 1))
    return 1
  fi
  echo "PASS: matrix file exists at $MATRIX"
  PASS=$((PASS + 1))
  return 0
}

check_frontmatter_key() {
  key="$1"
  expected="$2"
  actual=""
  actual=$(grep -E "^${key}:" "$MATRIX" | head -n 1 | sed -E "s/^${key}:[[:space:]]*//;s/[[:space:]]*$//")
  if [ "$actual" = "$expected" ]; then
    echo "PASS: frontmatter ${key} = ${expected}"
    PASS=$((PASS + 1))
    return 0
  fi
  echo "FAIL: frontmatter ${key} expected '${expected}' got '${actual}'"
  FAIL=$((FAIL + 1))
  return 1
}

check_frontmatter_present() {
  key="$1"
  if grep -qE "^${key}:" "$MATRIX"; then
    echo "PASS: frontmatter ${key} present"
    PASS=$((PASS + 1))
    return 0
  fi
  echo "FAIL: frontmatter ${key} missing"
  FAIL=$((FAIL + 1))
  return 1
}

check_column_header() {
  col="$1"
  if grep -qE "^\|.*\b${col}\b.*\|.*\|" "$MATRIX"; then
    echo "PASS: table column '${col}' present"
    PASS=$((PASS + 1))
    return 0
  fi
  echo "FAIL: table column '${col}' missing from header row"
  FAIL=$((FAIL + 1))
  return 1
}

check_no_verify_placeholder() {
  hits=0
  hits=$(grep -cE '(\| |\|)VERIFY( |\|)' "$MATRIX" || true)
  if [ "${hits:-0}" = "0" ]; then
    echo "PASS: no literal 'VERIFY' placeholder in any cell"
    PASS=$((PASS + 1))
    return 0
  fi
  echo "FAIL: ${hits} row(s) contain literal 'VERIFY' placeholder"
  FAIL=$((FAIL + 1))
  return 1
}

check_verdict_vocab() {
  # Extract data rows (lines starting with `|` that are not header/separator)
  # and confirm each has a Verified cell in the fixed vocabulary.
  bad_rows=0
  data_rows=0
  while IFS= read -r line; do
    # Skip header + separator rows
    case "$line" in
      "| Surface |"*) continue ;;
      "|---"*) continue ;;
      "|"*)
        # Only count rows inside the Consumption Surface table — those have
        # exactly 5 `|` boundary markers (6 segments including empties) and
        # at least one verified-* token. We check for any of the four tokens;
        # if none present, record as bad.
        case "$line" in
          *verified-identical*|*verified-drifted*|*verified-absent*|*verified-moot*)
            data_rows=$((data_rows + 1))
            ;;
          *)
            # Could be a non-data row (summary bullet in a table); skip if
            # it doesn't carry the Surface-column shape. Detect by counting
            # pipes — data rows have >=5 pipe chars.
            pipe_count=0
            pipe_count=$(printf '%s\n' "$line" | tr -cd '|' | wc -c | tr -d ' ')
            if [ "${pipe_count:-0}" -ge "5" ]; then
              bad_rows=$((bad_rows + 1))
              echo "FAIL: data row missing verdict vocabulary: $line"
            fi
            ;;
        esac
        ;;
    esac
  done < "$MATRIX"
  if [ "$bad_rows" = "0" ] && [ "$data_rows" -gt "0" ]; then
    echo "PASS: all ${data_rows} data rows carry a fixed-vocabulary verdict"
    PASS=$((PASS + 1))
    return 0
  fi
  echo "FAIL: data_rows=${data_rows} bad_rows=${bad_rows}"
  FAIL=$((FAIL + 1))
  return 1
}

# Run all checks. Failures do not short-circuit — we want a full SUMMARY.
check_exists || true
check_frontmatter_key "schema_version" '"1.0"' || true
check_frontmatter_key "type" "parity-matrix" || true
check_frontmatter_key "milestone" '"M026"' || true
check_frontmatter_key "phase" '"P01"' || true
check_frontmatter_present "created_at" || true
check_frontmatter_key "status" "final" || true
check_column_header "Surface" || true
check_column_header "OSS" || true
check_column_header "Paid" || true
check_column_header "Verified" || true
check_no_verify_placeholder || true
check_verdict_vocab || true

echo "SUMMARY: pass=${PASS} fail=${FAIL}"
if [ "$FAIL" -gt "0" ]; then
  exit 1
fi
exit 0
