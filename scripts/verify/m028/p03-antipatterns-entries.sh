#!/usr/bin/env bash
# scripts/verify/m028/p03-antipatterns-entries.sh
#
# M028/P03/T01 verifier: asserts ANTIPATTERNS.md carries the five new entries
# AP-010..AP-014 with the required sub-sections and pattern-class labels in
# their Cross-Refs sections, while AP-001..AP-009 headings are preserved
# unchanged (append-only invariant).
#
# Single-script-file shape (AD-19). Bash 3.2 + POSIX-sh safe.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd -P)"
TARGET="${REPO_ROOT}/ANTIPATTERNS.md"

if [ ! -f "$TARGET" ]; then
  printf 'FAIL: ANTIPATTERNS.md not found at %s\n' "$TARGET" >&2
  exit 1
fi

fail_count=0

# Check 1: AP-001..AP-009 headings present (append-only invariant).
existing_id=1
while [ "$existing_id" -le 9 ]; do
  pad=$(printf '%03d' "$existing_id")
  if ! grep -q "^## AP-${pad}:" "$TARGET"; then
    printf 'FAIL: AP-%s heading missing (append-only invariant violated)\n' "$pad" >&2
    fail_count=$((fail_count + 1))
  fi
  existing_id=$((existing_id + 1))
done

# Check 2: Each new entry AP-010..AP-014 has its level-2 heading.
new_id=10
while [ "$new_id" -le 14 ]; do
  pad=$(printf '%03d' "$new_id")
  if ! grep -q "^## AP-${pad}:" "$TARGET"; then
    printf 'FAIL: AP-%s heading missing\n' "$pad" >&2
    fail_count=$((fail_count + 1))
  fi
  new_id=$((new_id + 1))
done

# Check 3: Each new entry has the four required sub-section markers in body.
# We slice the file from the entry's heading to the next AP-### heading
# (or EOF) and assert each marker appears within that slice.
extract_entry_slice() {
  # $1 = AP-NNN id (zero-padded); writes slice to stdout.
  awk -v id="$1" '
    BEGIN { in_entry = 0 }
    $0 ~ "^## AP-" id ":" { in_entry = 1; print; next }
    in_entry && $0 ~ /^## AP-[0-9]{3}:/ { in_entry = 0 }
    in_entry { print }
  ' "$TARGET"
}

assert_sections_present() {
  # $1 = AP-NNN id (zero-padded). Asserts Description/Evidence/Remedy/Cross-Refs.
  local id="$1"
  local slice
  slice=$(extract_entry_slice "$id")
  local marker
  for marker in '\*\*Description\*\*:' '\*\*Evidence\*\*:' '\*\*Remedy\*\*:' '\*\*Cross-Refs\*\*:'; do
    if ! printf '%s\n' "$slice" | grep -qE "$marker"; then
      printf 'FAIL: AP-%s missing sub-section %s\n' "$id" "$marker" >&2
      fail_count=$((fail_count + 1))
    fi
  done
}

assert_sections_present 010
assert_sections_present 011
assert_sections_present 012
assert_sections_present 013
assert_sections_present 014

# Check 4: each entry's Cross-Refs section names the corresponding
# pattern-class label so the document is navigable from AP-ID to label.
assert_label_in_slice() {
  # $1 = AP-NNN id; $2 = pattern-class label.
  local id="$1"
  local label="$2"
  local slice
  slice=$(extract_entry_slice "$id")
  if ! printf '%s\n' "$slice" | grep -q "$label"; then
    printf 'FAIL: AP-%s entry does not name pattern-class label %s\n' "$id" "$label" >&2
    fail_count=$((fail_count + 1))
  fi
}

assert_label_in_slice 010 'cmd-sub-in-pattern'
assert_label_in_slice 011 'quoted-arg-newline-hash'
assert_label_in_slice 012 'multiline-quoted-script'
assert_label_in_slice 013 'unquoted-brace-glob'
assert_label_in_slice 014 'xargs-sh-c-compound-body'

if [ "$fail_count" -gt 0 ]; then
  printf 'FAIL: %d check(s) failed in %s\n' "$fail_count" "$TARGET" >&2
  exit 1
fi

printf 'PASS: ANTIPATTERNS.md carries AP-010..AP-014 with required sub-sections and labels; AP-001..AP-009 preserved\n'
exit 0
