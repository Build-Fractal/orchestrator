#!/usr/bin/env bash
# tests/test-s07-integration.sh — Cross-slice integration tests
# Validates command-to-script/template cross-references, runtime capability
# detection (R008), idempotency, and failure diagnostic quality.
#
# Bash 3.2 compatible (no declare -A, per K001).
# Outputs structured PASS/FAIL lines. Exits 0 if all pass, 1 if any fail.

set -euo pipefail

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=0

pass() {
  TOTAL=$((TOTAL + 1))
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "PASS: $1"
}

fail() {
  TOTAL=$((TOTAL + 1))
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo "FAIL: $1"
}

# Resolve project root (one level up from tests/)
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# ==========================================================================
# Section 2 — Cross-Reference Validation
# ==========================================================================
echo ""
echo "--- Section 2: Cross-Reference Validation ---"

# 2a. All script paths referenced in command .md files exist on disk
XREF_SCRIPTS_BAD=0
XREF_SCRIPTS_BAD_LIST=""
while IFS= read -r ref_script; do
  if [ ! -f "$ref_script" ]; then
    XREF_SCRIPTS_BAD=$((XREF_SCRIPTS_BAD + 1))
    XREF_SCRIPTS_BAD_LIST="${XREF_SCRIPTS_BAD_LIST} ${ref_script}"
  fi
done < <(grep -rohE 'scripts/[a-z]+/[a-z_-]+\.sh' commands/ 2>/dev/null | sort -u)

if [ "$XREF_SCRIPTS_BAD" -eq 0 ]; then
  pass "all script paths referenced in commands exist on disk"
else
  fail "script paths referenced in commands but missing on disk:${XREF_SCRIPTS_BAD_LIST}"
fi

# 2b. All template paths referenced in command .md files exist on disk
XREF_TEMPLATES_BAD=0
XREF_TEMPLATES_BAD_LIST=""
while IFS= read -r ref_tpl; do
  if [ ! -f "$ref_tpl" ]; then
    XREF_TEMPLATES_BAD=$((XREF_TEMPLATES_BAD + 1))
    XREF_TEMPLATES_BAD_LIST="${XREF_TEMPLATES_BAD_LIST} ${ref_tpl}"
  fi
done < <(grep -rohE 'templates/[a-z_-]+\.(md|yml)' commands/ 2>/dev/null | sort -u)

if [ "$XREF_TEMPLATES_BAD" -eq 0 ]; then
  pass "all template paths referenced in commands exist on disk"
else
  fail "template paths referenced in commands but missing on disk:${XREF_TEMPLATES_BAD_LIST}"
fi

# 2c. No command file contains stub placeholder markers
PLACEHOLDER_FILES=""
for cmd_file in commands/*.md; do
  if grep -qE '^#+ Placeholder|^Placeholder$|placeholder implementation' "$cmd_file" 2>/dev/null; then
    PLACEHOLDER_FILES="${PLACEHOLDER_FILES} ${cmd_file}"
  fi
done

if [ -z "$PLACEHOLDER_FILES" ]; then
  pass "no command files contain stub placeholder markers"
else
  fail "command files with stub placeholders:${PLACEHOLDER_FILES}"
fi

# 2d. All command files have YAML frontmatter (first line is ---)
FRONTMATTER_BAD=0
FRONTMATTER_BAD_LIST=""
for cmd_file in commands/*.md; do
  # Skip README.md — it's documentation, not a command file
  [ "$(basename "$cmd_file")" = "README.md" ] && continue
  first_line=$(head -1 "$cmd_file" 2>/dev/null)
  if [ "$first_line" != "---" ]; then
    FRONTMATTER_BAD=$((FRONTMATTER_BAD + 1))
    FRONTMATTER_BAD_LIST="${FRONTMATTER_BAD_LIST} ${cmd_file}"
  fi
done

if [ "$FRONTMATTER_BAD" -eq 0 ]; then
  pass "all command files have YAML frontmatter"
else
  fail "command files missing YAML frontmatter:${FRONTMATTER_BAD_LIST}"
fi

# ==========================================================================
# Section 3 — Runtime Capability Detection (R008/SC-007)
# ==========================================================================
echo ""
echo "--- Section 3: Runtime Capability Detection ---"

DETECT_SCRIPT="scripts/dispatch/detect-capabilities.sh"

# 3a. detect-capabilities.sh exits 0 (default text format)
if bash "$DETECT_SCRIPT" >/dev/null 2>&1; then
  pass "detect-capabilities.sh exits 0 (text format)"
else
  fail "detect-capabilities.sh exited non-zero (text format) — ${DETECT_SCRIPT}"
fi

# 3b. Text output contains shell_execution=true
TEXT_OUTPUT=$(bash "$DETECT_SCRIPT" 2>/dev/null)
if echo "$TEXT_OUTPUT" | grep -q "shell_execution=true"; then
  pass "text output contains shell_execution=true"
else
  fail "text output missing shell_execution=true — ${DETECT_SCRIPT}"
fi

# 3c. Text output contains runtime=local (when not in CI)
if [ "${GITHUB_ACTIONS:-}" != "true" ]; then
  if echo "$TEXT_OUTPUT" | grep -q "runtime=local"; then
    pass "text output contains runtime=local (not in CI)"
  else
    fail "text output missing runtime=local — ${DETECT_SCRIPT}"
  fi
else
  if echo "$TEXT_OUTPUT" | grep -q "runtime=ci-github"; then
    pass "text output contains runtime=ci-github (in CI)"
  else
    fail "text output missing expected runtime value — ${DETECT_SCRIPT}"
  fi
fi

# 3d. detect-capabilities.sh --format json exits 0
if bash "$DETECT_SCRIPT" --format json >/dev/null 2>&1; then
  pass "detect-capabilities.sh --format json exits 0"
else
  fail "detect-capabilities.sh --format json exited non-zero — ${DETECT_SCRIPT}"
fi

# 3e. JSON output contains all 7 expected keys
JSON_OUTPUT=$(bash "$DETECT_SCRIPT" --format json 2>/dev/null)
EXPECTED_JSON_KEYS="subagent_dispatch agent_tool_available shell_execution git_available git_worktree github_actions runtime"
JSON_KEYS_MISSING=0
JSON_KEYS_MISSING_LIST=""
for key in $EXPECTED_JSON_KEYS; do
  if ! echo "$JSON_OUTPUT" | grep -q "\"${key}\""; then
    JSON_KEYS_MISSING=$((JSON_KEYS_MISSING + 1))
    JSON_KEYS_MISSING_LIST="${JSON_KEYS_MISSING_LIST} ${key}"
  fi
done

if [ "$JSON_KEYS_MISSING" -eq 0 ]; then
  pass "JSON output contains all 7 expected capability keys"
else
  fail "JSON output missing keys:${JSON_KEYS_MISSING_LIST} — ${DETECT_SCRIPT}"
fi

# 3f. shell_execution is true in JSON output
if echo "$JSON_OUTPUT" | grep -q '"shell_execution": true'; then
  pass "JSON output has shell_execution: true"
else
  fail "JSON output shell_execution is not true — ${DETECT_SCRIPT}"
fi

# ==========================================================================
# Section 4 — Failure Diagnostics
# ==========================================================================
echo ""
echo "--- Section 4: Failure Diagnostics ---"

# 4a. Verify that fail() calls in this test include file paths or contract names
OWN_FAIL_CALLS=$(grep 'fail "' "$0" | grep -cv 'lack file paths' 2>/dev/null || echo 0)
FAIL_WITH_CONTEXT=$(grep 'fail "' "$0" | grep -v 'lack file paths' | grep -cE '(/[a-z]|\.sh|\.md|\.yml|missing|mismatch|not-registered|not executable|not true|not in|stub|unregistered|non-zero|runtime)' 2>/dev/null || echo 0)
if [ "$FAIL_WITH_CONTEXT" -eq "$OWN_FAIL_CALLS" ]; then
  pass "all fail() messages include file paths or contract identifiers"
else
  fail "some fail() messages lack file paths — $FAIL_WITH_CONTEXT of $OWN_FAIL_CALLS include context"
fi

# ==========================================================================
# Section 5 — Idempotency Tests (FR-066)
# ==========================================================================
echo ""
echo "--- Section 5: Idempotency Tests ---"

# 5a. Roadmap idempotency: roadmap.md has overwrite protection language
ROADMAP_CMD="$PROJECT_ROOT/commands/roadmap.md"
if grep -qi "already exists\|existing roadmap\|Overwrite" "$ROADMAP_CMD" && grep -qi "confirmation\|confirmed" "$ROADMAP_CMD"; then
  pass "roadmap.md contains overwrite protection with confirmation language (FR-066)"
else
  fail "roadmap.md missing overwrite protection language — commands/roadmap.md"
fi

# 5b. Verify idempotency: verify.md has cached result language
VERIFY_CMD="$PROJECT_ROOT/commands/verify.md"
if grep -qi "cached\|already verified\|Cached verification" "$VERIFY_CMD"; then
  pass "verify.md contains cached result language (FR-066)"
else
  fail "verify.md missing cached result language — commands/verify.md"
fi

# 5c. Verify idempotency: verify.md documents --force for re-verification
if grep -q "\-\-force" "$VERIFY_CMD"; then
  pass "verify.md documents --force flag for re-verification"
else
  fail "verify.md missing --force documentation — commands/verify.md"
fi

# 5d. Dispatch idempotency: dispatch.md has T##-SUMMARY.md skip language
DISPATCH_CMD="$PROJECT_ROOT/commands/dispatch.md"
if grep -q "SUMMARY.md" "$DISPATCH_CMD" && grep -qi "skip\|no-op\|skipped" "$DISPATCH_CMD"; then
  pass "dispatch.md contains SUMMARY.md skip/no-op language (FR-066)"
else
  fail "dispatch.md missing SUMMARY.md skip language — commands/dispatch.md"
fi

# 5e. Scaffold idempotency: run scaffold.sh twice, md5 identical
SCAFFOLD_SCRIPT="$PROJECT_ROOT/scripts/lifecycle/scaffold.sh"
if [ -f "$SCAFFOLD_SCRIPT" ]; then
  TMPDIR_IDEM=$(mktemp -d)

  # First run
  bash "$SCAFFOLD_SCRIPT" "$TMPDIR_IDEM" M001 2>/dev/null
  first_md5=$(find "$TMPDIR_IDEM" -type f -exec md5 {} \; 2>/dev/null | sort || find "$TMPDIR_IDEM" -type f -exec md5sum {} \; 2>/dev/null | sort) || true

  # Second run
  bash "$SCAFFOLD_SCRIPT" "$TMPDIR_IDEM" M001 2>/dev/null
  second_md5=$(find "$TMPDIR_IDEM" -type f -exec md5 {} \; 2>/dev/null | sort || find "$TMPDIR_IDEM" -type f -exec md5sum {} \; 2>/dev/null | sort) || true

  if [ "$first_md5" = "$second_md5" ]; then
    pass "scaffold.sh idempotent re-run produces identical md5 sums (FR-066)"
  else
    fail "scaffold.sh idempotent re-run changed files — scripts/lifecycle/scaffold.sh"
  fi
  rm -rf "$TMPDIR_IDEM"
else
  fail "scaffold.sh idempotency test — scripts/lifecycle/scaffold.sh not found"
fi

# 5f. Resume idempotency: resume.md documents safe re-callable behavior
RESUME_CMD="$PROJECT_ROOT/commands/resume.md"
if grep -qi "idempotency\|re-callable\|Running resume twice" "$RESUME_CMD"; then
  pass "resume.md documents idempotency/re-callable behavior (FR-066)"
else
  fail "resume.md missing idempotency documentation — commands/resume.md"
fi

# ==========================================================================
# Summary
# ==========================================================================
echo ""
echo "$PASS_COUNT/$TOTAL checks passed"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi

exit 0
