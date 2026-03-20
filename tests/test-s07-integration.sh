#!/usr/bin/env bash
# tests/test-s07-integration.sh — Cross-slice integration tests
# Validates manifest-to-filesystem contracts, command-to-script/template
# cross-references, runtime capability detection (R008), and failure
# diagnostic quality across the entire extension.
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
# Section 1 — Manifest Validation
# ==========================================================================
echo ""
echo "--- Section 1: Manifest Validation ---"

# 1a. Every provides.scripts entry's file exists on disk
SCRIPTS_MISSING=0
SCRIPTS_MISSING_LIST=""
while IFS= read -r script_path; do
  if [ ! -f "$script_path" ]; then
    SCRIPTS_MISSING=$((SCRIPTS_MISSING + 1))
    SCRIPTS_MISSING_LIST="${SCRIPTS_MISSING_LIST} ${script_path}"
  fi
done < <(grep '^\s*- file: scripts/' extension.yml | sed 's/.*- file: //' | sed 's/ *$//')

if [ "$SCRIPTS_MISSING" -eq 0 ]; then
  pass "all provides.scripts entries exist on disk"
else
  fail "provides.scripts entries missing on disk:${SCRIPTS_MISSING_LIST}"
fi

# 1b. Every provides.scripts entry's file is executable
SCRIPTS_NOT_EXEC=0
SCRIPTS_NOT_EXEC_LIST=""
while IFS= read -r script_path; do
  if [ -f "$script_path" ] && [ ! -x "$script_path" ]; then
    SCRIPTS_NOT_EXEC=$((SCRIPTS_NOT_EXEC + 1))
    SCRIPTS_NOT_EXEC_LIST="${SCRIPTS_NOT_EXEC_LIST} ${script_path}"
  fi
done < <(grep '^\s*- file: scripts/' extension.yml | sed 's/.*- file: //' | sed 's/ *$//')

if [ "$SCRIPTS_NOT_EXEC" -eq 0 ]; then
  pass "all provides.scripts entries are executable"
else
  fail "provides.scripts entries not executable:${SCRIPTS_NOT_EXEC_LIST}"
fi

# 1c. Every provides.commands entry's file exists on disk
CMDS_MISSING=0
CMDS_MISSING_LIST=""
while IFS= read -r cmd_path; do
  if [ ! -f "$cmd_path" ]; then
    CMDS_MISSING=$((CMDS_MISSING + 1))
    CMDS_MISSING_LIST="${CMDS_MISSING_LIST} ${cmd_path}"
  fi
done < <(grep '^\s*file: commands/' extension.yml | sed 's/.*file: //' | sed 's/ *$//')

if [ "$CMDS_MISSING" -eq 0 ]; then
  pass "all provides.commands entries exist on disk"
else
  fail "provides.commands entries missing on disk:${CMDS_MISSING_LIST}"
fi

# 1d. Every .sh file under scripts/ is registered in provides.scripts
UNREG=0
UNREG_LIST=""
while IFS= read -r disk_script; do
  if ! grep -q "file: ${disk_script}" extension.yml 2>/dev/null; then
    UNREG=$((UNREG + 1))
    UNREG_LIST="${UNREG_LIST} ${disk_script}"
  fi
done < <(find scripts/ -name '*.sh' -type f | sort)

if [ "$UNREG" -eq 0 ]; then
  pass "all scripts on disk are registered in provides.scripts"
else
  fail "scripts on disk not registered in extension.yml:${UNREG_LIST}"
fi

# 1e. config_schema.properties has all 7 expected keys
EXPECTED_SCHEMA_KEYS="default_tier verification_commands context_verbosity git_isolation dispatch_budget duration_budget budget_enforcement"
SCHEMA_MISSING=0
SCHEMA_MISSING_LIST=""
for key in $EXPECTED_SCHEMA_KEYS; do
  if ! grep -q "^    ${key}:" extension.yml 2>/dev/null; then
    SCHEMA_MISSING=$((SCHEMA_MISSING + 1))
    SCHEMA_MISSING_LIST="${SCHEMA_MISSING_LIST} ${key}"
  fi
done

if [ "$SCHEMA_MISSING" -eq 0 ]; then
  pass "config_schema.properties has all 7 expected keys"
else
  fail "config_schema.properties missing keys:${SCHEMA_MISSING_LIST}"
fi

# 1f. All 5 hooks reference commands that are registered in provides.commands
EXPECTED_HOOKS="before_tasks after_tasks before_implement after_implement before_commit"
HOOK_BAD=0
HOOK_BAD_LIST=""
for hook in $EXPECTED_HOOKS; do
  # Extract the command name from the hook
  hook_cmd=$(awk "/^  ${hook}:/{found=1} found && /command:/{print \$2; exit}" extension.yml)
  if [ -z "$hook_cmd" ]; then
    HOOK_BAD=$((HOOK_BAD + 1))
    HOOK_BAD_LIST="${HOOK_BAD_LIST} ${hook}(no-command)"
  else
    # Check if that command is in provides.commands
    if ! grep -q "name: ${hook_cmd}" extension.yml 2>/dev/null; then
      HOOK_BAD=$((HOOK_BAD + 1))
      HOOK_BAD_LIST="${HOOK_BAD_LIST} ${hook}(${hook_cmd}-not-registered)"
    fi
  fi
done

if [ "$HOOK_BAD" -eq 0 ]; then
  pass "all 5 hooks reference registered commands"
else
  fail "hooks with unregistered commands:${HOOK_BAD_LIST}"
fi

# 1g. requires.commands lists all 6 expected spec-kit commands
EXPECTED_REQ_CMDS="speckit.plan speckit.tasks speckit.implement speckit.clarify speckit.specify speckit.analyze"
REQ_MISSING=0
REQ_MISSING_LIST=""
for cmd in $EXPECTED_REQ_CMDS; do
  if ! grep -qE "^[[:space:]]*- ${cmd}$" extension.yml 2>/dev/null; then
    REQ_MISSING=$((REQ_MISSING + 1))
    REQ_MISSING_LIST="${REQ_MISSING_LIST} ${cmd}"
  fi
done

if [ "$REQ_MISSING" -eq 0 ]; then
  pass "requires.commands lists all 6 expected spec-kit commands"
else
  fail "requires.commands missing:${REQ_MISSING_LIST}"
fi

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
# (We check for "# Placeholder" headers or lines that are just "Placeholder"
#  — the word in template-instruction context is fine)
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

# 2e. Commands referenced in hooks are also in provides.commands
# (Complementary to 1f — here we extract from hooks directly)
HOOKS_XREF_BAD=0
HOOKS_XREF_BAD_LIST=""
while IFS= read -r hook_cmd; do
  if ! grep -q "name: ${hook_cmd}" extension.yml 2>/dev/null; then
    HOOKS_XREF_BAD=$((HOOKS_XREF_BAD + 1))
    HOOKS_XREF_BAD_LIST="${HOOKS_XREF_BAD_LIST} ${hook_cmd}"
  fi
done < <(awk '/^hooks:/{in_hooks=1} in_hooks && /command:/{print $2}' extension.yml | sort -u)

if [ "$HOOKS_XREF_BAD" -eq 0 ]; then
  pass "all hook commands are registered in provides.commands"
else
  fail "hook commands not in provides.commands:${HOOKS_XREF_BAD_LIST}"
fi

# 2f. All provides.commands have corresponding .md files in commands/
PROVIDES_CMD_BAD=0
PROVIDES_CMD_BAD_LIST=""
while IFS= read -r cmd_file_path; do
  if [ ! -f "$cmd_file_path" ]; then
    PROVIDES_CMD_BAD=$((PROVIDES_CMD_BAD + 1))
    PROVIDES_CMD_BAD_LIST="${PROVIDES_CMD_BAD_LIST} ${cmd_file_path}"
  fi
done < <(grep '^\s*file: commands/' extension.yml | sed 's/.*file: //' | sed 's/ *$//')

if [ "$PROVIDES_CMD_BAD" -eq 0 ]; then
  pass "all provides.commands .md files exist in commands/"
else
  fail "provides.commands .md files missing:${PROVIDES_CMD_BAD_LIST}"
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
  # In CI, runtime should be ci-github
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

# 3e. JSON output contains all 6 expected keys
JSON_OUTPUT=$(bash "$DETECT_SCRIPT" --format json 2>/dev/null)
EXPECTED_JSON_KEYS="subagent_dispatch shell_execution git_available git_worktree github_actions runtime"
JSON_KEYS_MISSING=0
JSON_KEYS_MISSING_LIST=""
for key in $EXPECTED_JSON_KEYS; do
  if ! echo "$JSON_OUTPUT" | grep -q "\"${key}\""; then
    JSON_KEYS_MISSING=$((JSON_KEYS_MISSING + 1))
    JSON_KEYS_MISSING_LIST="${JSON_KEYS_MISSING_LIST} ${key}"
  fi
done

if [ "$JSON_KEYS_MISSING" -eq 0 ]; then
  pass "JSON output contains all 6 expected capability keys"
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
# Section 4 — Failure Diagnostics & Completeness
# ==========================================================================
echo ""
echo "--- Section 4: Failure Diagnostics & Completeness ---"

# 4a. Verify that fail() calls in this test include file paths or contract names
# (Self-diagnostic: every fail() invocation in this file should include a path
#  or descriptive contract identifier in its message)
# Exclude the self-referential fail line in this check (which reports the diagnostic)
OWN_FAIL_CALLS=$(grep 'fail "' "$0" | grep -cv 'lack file paths' 2>/dev/null || echo 0)
# Count fail calls that include a path-like pattern or a descriptive contract term
# Patterns: file paths (word/word), extensions (.sh .md .yml), contract terms
# (missing, mismatch, not-registered, not executable, stub, unregistered)
FAIL_WITH_CONTEXT=$(grep 'fail "' "$0" | grep -v 'lack file paths' | grep -cE '(/[a-z]|\.sh|\.md|\.yml|missing|mismatch|not-registered|not executable|not true|not in|stub|unregistered|non-zero|runtime)' 2>/dev/null || echo 0)
if [ "$FAIL_WITH_CONTEXT" -eq "$OWN_FAIL_CALLS" ]; then
  pass "all fail() messages include file paths or contract identifiers"
else
  fail "some fail() messages lack file paths — $FAIL_WITH_CONTEXT of $OWN_FAIL_CALLS include context"
fi

# 4b. Count total scripts on disk vs total in manifest — equal
DISK_SCRIPT_COUNT=$(find scripts/ -name '*.sh' -type f | wc -l | tr -d ' ')
MANIFEST_SCRIPT_COUNT=$(grep -c '^\s*- file: scripts/' extension.yml 2>/dev/null || echo 0)
if [ "$DISK_SCRIPT_COUNT" -eq "$MANIFEST_SCRIPT_COUNT" ]; then
  pass "script count matches: disk=$DISK_SCRIPT_COUNT manifest=$MANIFEST_SCRIPT_COUNT"
else
  fail "script count mismatch: disk=$DISK_SCRIPT_COUNT manifest=$MANIFEST_SCRIPT_COUNT"
fi

# 4c. Count total commands on disk vs total in manifest — equal
DISK_CMD_COUNT=$(find commands/ -name '*.md' -type f ! -name 'README.md' | wc -l | tr -d ' ')
MANIFEST_CMD_COUNT=$(grep -c '^\s*- name: speckit\.orchestrator\.' extension.yml 2>/dev/null || echo 0)
if [ "$DISK_CMD_COUNT" -eq "$MANIFEST_CMD_COUNT" ]; then
  pass "command count matches: disk=$DISK_CMD_COUNT manifest=$MANIFEST_CMD_COUNT"
else
  fail "command count mismatch: disk=$DISK_CMD_COUNT manifest=$MANIFEST_CMD_COUNT"
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
