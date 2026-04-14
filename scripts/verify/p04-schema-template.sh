#!/usr/bin/env bash
# Verifies templates/instruction-schema.md exists and declares the expected
# required and optional section groups.
set -eu
f="templates/instruction-schema.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

grep -q "## Required Sections" "$f" || { echo "FAIL: $f missing '## Required Sections' heading"; exit 1; }
grep -q "## Optional Sections" "$f" || { echo "FAIL: $f missing '## Optional Sections' heading"; exit 1; }

# Count required groups (### 1. through ### 5. headings)
required_count="$(grep -c '^### [1-5]\.' "$f")"
if [ "$required_count" -lt 5 ]; then
  echo "FAIL: $f has $required_count required groups (expected at least 5)"
  exit 1
fi

# Count optional groups (### 6. and ### 7.)
optional_count=0
grep -q '^### 6\.' "$f" && optional_count=$((optional_count + 1))
grep -q '^### 7\.' "$f" && optional_count=$((optional_count + 1))
if [ "$optional_count" -lt 2 ]; then
  echo "FAIL: $f has $optional_count optional groups (expected at least 2)"
  exit 1
fi

echo "PASS: $f declares $required_count required and $optional_count optional section groups"
