#!/usr/bin/env bash
# scripts/verify/m013-p01-uat-template.sh — M013/P01/T03 gate.
#
# Asserts the UAT Bug Issue Form contract:
#   1. .github/ISSUE_TEMPLATE/uat-bug.yml exists.
#   2. File parses as valid YAML (python3+PyYAML preferred, yq fallback, else SKIP).
#   3. Required top-level keys present: name, description, title, labels, body.
#   4. title prefix is the literal "[UAT] " string (with trailing space).
#   5. labels list contains the uat-bug entry.
#   6. Body has an input block with id: spec_chunk_id, type: input.
#   7. spec_chunk_id field carries validations.required: true within ~10 lines
#      following the id line.
#   8. Template links to KNOWLEDGE-INDEX.md for the Spec Chunks autocomplete
#      source (FR-9 + T03 must-have).
#   9. Template is not indented with tab characters (GitHub Issue Forms requires
#      two-space indentation; tabs fail the renderer).
#
# Single-script-file shape (AD-19). Bash 3.2 compatible (MEM001). No jq/yq/
# python3 hard dependency; graceful-absent-tool SKIP path (M012 pattern).
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMPLATE="${REPO_ROOT}/.github/ISSUE_TEMPLATE/uat-bug.yml"

fail_count=0
assert_ok() {
  if [ "$1" -eq 0 ]; then
    echo "PASS: $2"
  else
    echo "FAIL: $2"
    fail_count=$((fail_count + 1))
  fi
}

# 1. Template file exists
[ -f "$TEMPLATE" ]
assert_ok $? "uat-bug.yml present"

# 2. YAML parse-clean (prefer python3+PyYAML, fall back to yq, else SKIP)
if command -v python3 >/dev/null 2>&1; then
  python3 -c "import yaml" >/dev/null 2>&1
  yaml_import_rc=$?
  if [ "$yaml_import_rc" -eq 0 ]; then
    python3 -c "import yaml,sys; yaml.safe_load(open('$TEMPLATE'))" >/dev/null 2>&1
    assert_ok $? "template is valid YAML (python3)"
  elif command -v yq >/dev/null 2>&1; then
    yq . "$TEMPLATE" >/dev/null 2>&1
    assert_ok $? "template is valid YAML (yq)"
  else
    echo "SKIP: YAML validator (no PyYAML, no yq); gate passes"
  fi
elif command -v yq >/dev/null 2>&1; then
  yq . "$TEMPLATE" >/dev/null 2>&1
  assert_ok $? "template is valid YAML (yq)"
else
  echo "SKIP: YAML validator (no python3, no yq); gate passes"
fi

# 3. Required top-level keys
for key in name description title labels body; do
  grep -qE "^${key}:" "$TEMPLATE"
  assert_ok $? "has top-level key: ${key}"
done

# 4. title prefix is "[UAT] " (with trailing space)
grep -qE '^title:[[:space:]]+"\[UAT\] "' "$TEMPLATE"
assert_ok $? "title prefix is [UAT] with trailing space"

# 5. labels list contains uat-bug entry
grep -qE "^[[:space:]]+-[[:space:]]+uat-bug[[:space:]]*$" "$TEMPLATE"
assert_ok $? "labels list contains uat-bug"

# 6. spec_chunk_id input block exists
grep -q "id: spec_chunk_id" "$TEMPLATE"
assert_ok $? "form has id: spec_chunk_id"

# spec_chunk_id block carries type: input somewhere before its id line
grep -B 1 "id: spec_chunk_id" "$TEMPLATE" | grep -q "type: input"
assert_ok $? "spec_chunk_id block has type: input"

# 7. spec_chunk_id field is required within 10 lines after the id line
grep -A 10 "id: spec_chunk_id" "$TEMPLATE" | grep -q "required: true"
assert_ok $? "spec_chunk_id field is required"

# 8. Template links to KNOWLEDGE-INDEX.md (autocomplete source)
grep -q "KNOWLEDGE-INDEX.md" "$TEMPLATE"
assert_ok $? "links to KNOWLEDGE-INDEX.md"

# 9. No tab indentation (GitHub Issue Forms convention)
grep -qP "^\t" "$TEMPLATE" 2>/dev/null
rc=$?
# grep returns 0 if tabs found, 1 if not found, 2 on error (e.g. no -P). Treat
# "not found" as PASS. If grep -P unsupported, fall back to awk.
if [ "$rc" -eq 1 ]; then
  echo "PASS: template uses space indentation (no tabs)"
elif [ "$rc" -eq 0 ]; then
  echo "FAIL: template uses space indentation (no tabs)"
  fail_count=$((fail_count + 1))
else
  # grep -P unsupported; use awk as portable fallback
  awk '/^\t/ { found=1; exit } END { exit (found?1:0) }' "$TEMPLATE"
  assert_ok $? "template uses space indentation (no tabs)"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m013-p01-uat-template.sh"
  exit 0
fi
echo "FAIL: m013-p01-uat-template.sh ($fail_count failures)"
exit 1
