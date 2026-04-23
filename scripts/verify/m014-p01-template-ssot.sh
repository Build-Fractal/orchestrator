#!/usr/bin/env bash
# scripts/verify/m014-p01-template-ssot.sh — verify templates/spec-template.md Section Contract shape.
# Exit 0 if all required sections present in order; exit 1 otherwise.
# Bash 3.2 compatible.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEMPLATE="${PROJECT_ROOT}/templates/spec-template.md"
EXPECTED="${PROJECT_ROOT}/tests/fixtures/m014-p01/expected-section-headings.txt"

if [ ! -f "$TEMPLATE" ]; then
  echo "FAIL: templates/spec-template.md missing" >&2
  exit 1
fi
if [ ! -f "$EXPECTED" ]; then
  echo "FAIL: tests/fixtures/m014-p01/expected-section-headings.txt missing" >&2
  exit 1
fi

# Extract headings from template (lines starting with # optionally followed by space).
ACTUAL_FILE="$(mktemp)"
grep -E '^#+[[:space:]]' "$TEMPLATE" > "$ACTUAL_FILE"

# Compare with expected heading list. Use diff for shape-clean comparison.
if diff -q "$EXPECTED" "$ACTUAL_FILE" >/dev/null 2>&1; then
  rm -f "$ACTUAL_FILE"
  echo "PASS: templates/spec-template.md section headings match expected"
  exit 0
fi

echo "FAIL: section headings diverge from expected:" >&2
diff "$EXPECTED" "$ACTUAL_FILE" >&2 || true
rm -f "$ACTUAL_FILE"
exit 1
