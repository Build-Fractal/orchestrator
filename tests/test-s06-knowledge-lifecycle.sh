#!/usr/bin/env bash
# tests/test-s06-knowledge-lifecycle.sh — Validates S06 knowledge & lifecycle contracts
# Tests: knowledge scripts (write-summary, append-decision, append-knowledge),
#        lifecycle scripts (rollback, mark-complete), consolidation, and commands.
# Outputs structured PASS/FAIL lines per check. Exits 0 if all pass, 1 if any fail.
# Dependencies: bash only (no declare -A, bash 3.2 compatible per K001)

set -euo pipefail

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=0

# Resolve project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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

# ==========================================================================
# Section 1: Knowledge Script Tests
# ==========================================================================
echo ""
echo "--- Section 1: Knowledge Scripts ---"

WRITE_SUMMARY="$PROJECT_ROOT/scripts/knowledge/write-summary.sh"
APPEND_DECISION="$PROJECT_ROOT/scripts/knowledge/append-decision.sh"
APPEND_KNOWLEDGE="$PROJECT_ROOT/scripts/knowledge/append-knowledge.sh"

# --------------------------------------------------------------------------
# 1.1 write-summary.sh — task type produces correct frontmatter
# --------------------------------------------------------------------------

TMPDIR_SUMMARY="$(mktemp -d)"

output=$(bash "$WRITE_SUMMARY" task "$TMPDIR_SUMMARY/task.md" \
  --id=T01 --parent=P01 --milestone=M001 \
  --provides="state derivation" --requires="from:P01/T01 what:config.yml" \
  --affects=P02 --key_files=scripts/foo.sh --key_decisions=D001 \
  --patterns_established="file presence" --drill_down_paths=plans/T01.md \
  --duration=25m --verification_result=pass \
  --completed_at=2026-03-19T14:30:00Z --body="Task summary body" 2>/dev/null) && exit_code=0 || exit_code=$?

if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "^SUMMARY: task T01 written"; then
  pass "write-summary.sh task type → SUMMARY: task T01 written (exit 0)"
else
  fail "write-summary.sh task type → expected SUMMARY output (exit=$exit_code, output: $output)"
fi

# Check frontmatter field count: task has 15 fields (schema_version, type, id, parent,
# milestone, provides, requires, affects, key_files, key_decisions, patterns_established,
# drill_down_paths, duration, verification_result, completed_at)
if [ -f "$TMPDIR_SUMMARY/task.md" ]; then
  # Count lines between --- markers (frontmatter lines)
  frontmatter=$(sed -n '/^---$/,/^---$/p' "$TMPDIR_SUMMARY/task.md" | grep -c ':' || true)
  if [ "$frontmatter" -ge 15 ]; then
    pass "write-summary.sh task frontmatter has ≥15 fields (got $frontmatter)"
  else
    fail "write-summary.sh task frontmatter has ≥15 fields (got $frontmatter)"
  fi
else
  fail "write-summary.sh task frontmatter — output file not created"
fi

# --------------------------------------------------------------------------
# 1.2 write-summary.sh — phase type produces correct frontmatter
# --------------------------------------------------------------------------

output=$(bash "$WRITE_SUMMARY" phase "$TMPDIR_SUMMARY/phase.md" \
  --id=P01 --parent=M001 --milestone=M001 \
  --provides="state derivation" --requires="from:P01/T01 what:config.yml" \
  --affects=P02 --key_files=scripts/foo.sh --key_decisions=D001 \
  --patterns_established="file presence" --drill_down_paths=plans/P01.md \
  --duration=2h --verification_result=pass \
  --completed_at=2026-03-19T16:00:00Z \
  --observability_surfaces="stderr structured output" \
  --body="Phase summary body" 2>/dev/null) && exit_code=0 || exit_code=$?

if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "^SUMMARY: phase P01 written"; then
  pass "write-summary.sh phase type → SUMMARY: phase P01 written (exit 0)"
else
  fail "write-summary.sh phase type → expected SUMMARY output (exit=$exit_code, output: $output)"
fi

# Phase should have 16 fields (adds observability_surfaces)
if [ -f "$TMPDIR_SUMMARY/phase.md" ]; then
  frontmatter=$(sed -n '/^---$/,/^---$/p' "$TMPDIR_SUMMARY/phase.md" | grep -c ':' || true)
  if [ "$frontmatter" -ge 16 ]; then
    pass "write-summary.sh phase frontmatter has ≥16 fields (got $frontmatter)"
  else
    fail "write-summary.sh phase frontmatter has ≥16 fields (got $frontmatter)"
  fi
else
  fail "write-summary.sh phase frontmatter — output file not created"
fi

# --------------------------------------------------------------------------
# 1.3 write-summary.sh — milestone type produces correct frontmatter
# --------------------------------------------------------------------------

output=$(bash "$WRITE_SUMMARY" milestone "$TMPDIR_SUMMARY/milestone.md" \
  --id=M001 --parent=null --milestone=M001 \
  --provides="orchestrator extension" --requires="from:spec what:spec.md" \
  --affects=M002 --key_files=config.yml --key_decisions=D001 \
  --patterns_established="SDD workflow" --drill_down_paths=milestones/M001 \
  --duration=8h --verification_result=pass \
  --completed_at=2026-03-20T10:00:00Z \
  --observability_surfaces="execution-log.jsonl" \
  --body="Milestone summary body" 2>/dev/null) && exit_code=0 || exit_code=$?

if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "^SUMMARY: milestone M001 written"; then
  pass "write-summary.sh milestone type → SUMMARY: milestone M001 written (exit 0)"
else
  fail "write-summary.sh milestone type → expected SUMMARY output (exit=$exit_code, output: $output)"
fi

# Milestone should have 16 fields (same as phase)
if [ -f "$TMPDIR_SUMMARY/milestone.md" ]; then
  frontmatter=$(sed -n '/^---$/,/^---$/p' "$TMPDIR_SUMMARY/milestone.md" | grep -c ':' || true)
  if [ "$frontmatter" -ge 16 ]; then
    pass "write-summary.sh milestone frontmatter has ≥16 fields (got $frontmatter)"
  else
    fail "write-summary.sh milestone frontmatter has ≥16 fields (got $frontmatter)"
  fi
else
  fail "write-summary.sh milestone frontmatter — output file not created"
fi

# --------------------------------------------------------------------------
# 1.4 write-summary.sh — missing required field exits non-zero with field name
# --------------------------------------------------------------------------

err_output=$(bash "$WRITE_SUMMARY" task "$TMPDIR_SUMMARY/bad.md" \
  --id=T01 --parent=P01 --milestone=M001 \
  --provides="x" --requires="x" --affects="x" \
  --key_files="x" --key_decisions="x" \
  --patterns_established="x" --drill_down_paths="x" \
  --duration=5m --verification_result=pass 2>&1) && exit_code=0 || exit_code=$?

if [ "$exit_code" -ne 0 ]; then
  pass "write-summary.sh missing field → exits non-zero (exit=$exit_code)"
else
  fail "write-summary.sh missing field → should exit non-zero (exit=$exit_code)"
fi

# Error should name the missing field
if echo "$err_output" | grep -qi "completed_at\|body"; then
  pass "write-summary.sh missing field → error names the missing field"
else
  fail "write-summary.sh missing field → error should name missing field (got: $err_output)"
fi

# --------------------------------------------------------------------------
# 1.5 write-summary.sh — no args exits non-zero
# --------------------------------------------------------------------------

bash "$WRITE_SUMMARY" > /dev/null 2>&1 && exit_code=0 || exit_code=$?
if [ "$exit_code" -ne 0 ]; then
  pass "write-summary.sh no args → exits non-zero"
else
  fail "write-summary.sh no args → should exit non-zero"
fi

rm -rf "$TMPDIR_SUMMARY"

# --------------------------------------------------------------------------
# 1.6 append-decision.sh — appends D004 after D001-D003
# --------------------------------------------------------------------------

TMPDIR_DECISION="$(mktemp -d)"
cp "$PROJECT_ROOT/tests/fixtures/knowledge-decisions/DECISIONS.md" "$TMPDIR_DECISION/DECISIONS.md"

output=$(bash "$APPEND_DECISION" "$TMPDIR_DECISION/DECISIONS.md" \
  "M001/P03/T01" "arch" "Knowledge format?" "Structured markdown" "Human-readable and grep-searchable" 2>/dev/null) && exit_code=0 || exit_code=$?

if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "^DECISION: D004 appended"; then
  pass "append-decision.sh → D004 appended after D001-D003"
else
  fail "append-decision.sh → expected D004 (exit=$exit_code, output: $output)"
fi

# Verify original rows unchanged
original_d001=$(grep "D001" "$PROJECT_ROOT/tests/fixtures/knowledge-decisions/DECISIONS.md")
current_d001=$(grep "D001" "$TMPDIR_DECISION/DECISIONS.md")
if [ "$original_d001" = "$current_d001" ]; then
  pass "append-decision.sh → existing D001 row unchanged (append-only)"
else
  fail "append-decision.sh → D001 row was modified (append-only violated)"
fi

# --------------------------------------------------------------------------
# 1.7 append-decision.sh — nonexistent file exits non-zero
# --------------------------------------------------------------------------

bash "$APPEND_DECISION" "/tmp/nonexistent-$(date +%s).md" \
  "M001/P01/T01" "arch" "Test?" "Test" "Test" > /dev/null 2>&1 && exit_code=0 || exit_code=$?

if [ "$exit_code" -ne 0 ]; then
  pass "append-decision.sh nonexistent file → exits non-zero"
else
  fail "append-decision.sh nonexistent file → should exit non-zero"
fi

# --------------------------------------------------------------------------
# 1.8 append-decision.sh — empty table (first entry becomes D001)
# --------------------------------------------------------------------------

cp "$PROJECT_ROOT/tests/fixtures/knowledge-decisions/DECISIONS-empty.md" "$TMPDIR_DECISION/DECISIONS-empty.md"

output=$(bash "$APPEND_DECISION" "$TMPDIR_DECISION/DECISIONS-empty.md" \
  "M001/P01/T01" "convention" "First decision?" "First choice" "First rationale" "No" 2>/dev/null) && exit_code=0 || exit_code=$?

if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "^DECISION: D001 appended"; then
  pass "append-decision.sh empty table → D001 created"
else
  fail "append-decision.sh empty table → expected D001 (exit=$exit_code, output: $output)"
fi

rm -rf "$TMPDIR_DECISION"

# --------------------------------------------------------------------------
# 1.9 append-knowledge.sh — project scope
# --------------------------------------------------------------------------

TMPDIR_KNOWLEDGE="$(mktemp -d)"
cp "$PROJECT_ROOT/tests/fixtures/knowledge-knowledge/KNOWLEDGE.md" "$TMPDIR_KNOWLEDGE/KNOWLEDGE.md"

output=$(bash "$APPEND_KNOWLEDGE" "$TMPDIR_KNOWLEDGE/KNOWLEDGE.md" \
  "New project-scoped knowledge entry" "project" 2>/dev/null) && exit_code=0 || exit_code=$?

if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q 'KNOWLEDGE: entry appended with scope \[project\]'; then
  pass "append-knowledge.sh project scope → entry appended"
else
  fail "append-knowledge.sh project scope → expected KNOWLEDGE output (exit=$exit_code, output: $output)"
fi

# Verify scope tag in output file
if grep -q '\*\*\[project\]\*\*' "$TMPDIR_KNOWLEDGE/KNOWLEDGE.md"; then
  pass "append-knowledge.sh project scope → [project] tag in file"
else
  fail "append-knowledge.sh project scope → missing [project] tag in file"
fi

# --------------------------------------------------------------------------
# 1.10 append-knowledge.sh — milestone scope
# --------------------------------------------------------------------------

output=$(bash "$APPEND_KNOWLEDGE" "$TMPDIR_KNOWLEDGE/KNOWLEDGE.md" \
  "Milestone-scoped knowledge" "milestone:M001" 2>/dev/null) && exit_code=0 || exit_code=$?

if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q 'KNOWLEDGE: entry appended with scope \[milestone:M001\]'; then
  pass "append-knowledge.sh milestone scope → entry appended"
else
  fail "append-knowledge.sh milestone scope → expected KNOWLEDGE output (exit=$exit_code, output: $output)"
fi

# --------------------------------------------------------------------------
# 1.11 append-knowledge.sh — phase scope
# --------------------------------------------------------------------------

output=$(bash "$APPEND_KNOWLEDGE" "$TMPDIR_KNOWLEDGE/KNOWLEDGE.md" \
  "Phase-scoped knowledge" "phase:M001/P02" 2>/dev/null) && exit_code=0 || exit_code=$?

if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q 'KNOWLEDGE: entry appended with scope \[phase:M001/P02\]'; then
  pass "append-knowledge.sh phase scope → entry appended"
else
  fail "append-knowledge.sh phase scope → expected KNOWLEDGE output (exit=$exit_code, output: $output)"
fi

# --------------------------------------------------------------------------
# 1.12 append-knowledge.sh — nonexistent file exits non-zero
# --------------------------------------------------------------------------

bash "$APPEND_KNOWLEDGE" "/tmp/nonexistent-$(date +%s).md" \
  "Test entry" "project" > /dev/null 2>&1 && exit_code=0 || exit_code=$?

if [ "$exit_code" -ne 0 ]; then
  pass "append-knowledge.sh nonexistent file → exits non-zero"
else
  fail "append-knowledge.sh nonexistent file → should exit non-zero"
fi

# --------------------------------------------------------------------------
# 1.13 append-knowledge.sh — existing entries unchanged
# --------------------------------------------------------------------------

original_count=$(wc -l < "$PROJECT_ROOT/tests/fixtures/knowledge-knowledge/KNOWLEDGE.md" | tr -d ' ')
current_first_lines=$(head -n "$original_count" "$TMPDIR_KNOWLEDGE/KNOWLEDGE.md")
original_content=$(cat "$PROJECT_ROOT/tests/fixtures/knowledge-knowledge/KNOWLEDGE.md")
if [ "$current_first_lines" = "$original_content" ]; then
  pass "append-knowledge.sh → existing entries unchanged"
else
  fail "append-knowledge.sh → existing entries were modified"
fi

rm -rf "$TMPDIR_KNOWLEDGE"

# ==========================================================================
# Section 2: Lifecycle Script Tests
# ==========================================================================
echo ""
echo "--- Section 2: Lifecycle Scripts ---"

ROLLBACK_PHASE="$PROJECT_ROOT/scripts/lifecycle/rollback-phase.sh"
MARK_COMPLETE="$PROJECT_ROOT/scripts/lifecycle/mark-complete.sh"

# --------------------------------------------------------------------------
# 2.1 rollback-phase.sh — rolls back P01, summary moves to archive
# --------------------------------------------------------------------------

TMPDIR_ROLLBACK="$(mktemp -d)"
cp -r "$PROJECT_ROOT/tests/fixtures/rollback-state/"* "$TMPDIR_ROLLBACK/"

output=$(bash "$ROLLBACK_PHASE" "$TMPDIR_ROLLBACK" M001 P01 "Test rollback reason" 2>/dev/null) && exit_code=0 || exit_code=$?

if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "^ROLLBACK: P01 rolled back"; then
  pass "rollback-phase.sh → P01 rolled back (exit 0)"
else
  fail "rollback-phase.sh → expected ROLLBACK output (exit=$exit_code, output: $output)"
fi

# 2.2 Phase summary moved to archive
archive_files=$(ls "$TMPDIR_ROLLBACK/milestones/M001/phases/P01/archive/" 2>/dev/null | grep "P01-SUMMARY" || true)
if [ -n "$archive_files" ]; then
  pass "rollback-phase.sh → P01-SUMMARY.md moved to archive"
else
  fail "rollback-phase.sh → P01-SUMMARY.md not found in archive"
fi

# 2.3 Task summaries moved to archive
task_archives=$(ls "$TMPDIR_ROLLBACK/milestones/M001/phases/P01/archive/" 2>/dev/null | grep "T.*-SUMMARY" | wc -l | tr -d ' ')
if [ "$task_archives" -ge 2 ]; then
  pass "rollback-phase.sh → task summaries moved to archive ($task_archives files)"
else
  fail "rollback-phase.sh → expected ≥2 task summaries in archive (got $task_archives)"
fi

# 2.4 Downstream P02 flagged
if echo "$output" | grep -q "downstream P02 flagged"; then
  pass "rollback-phase.sh → downstream P02 flagged for review"
else
  fail "rollback-phase.sh → expected downstream P02 flagged (output: $output)"
fi

# 2.5 Reversal decision appended to DECISIONS.md
if grep -q "D003.*lifecycle.*Rollback P01" "$TMPDIR_ROLLBACK/DECISIONS.md" 2>/dev/null; then
  pass "rollback-phase.sh → reversal decision D003 appended to DECISIONS.md"
else
  fail "rollback-phase.sh → reversal decision not found in DECISIONS.md"
fi

rm -rf "$TMPDIR_ROLLBACK"

# --------------------------------------------------------------------------
# 2.6 rollback-phase.sh — exits non-zero when no summary exists
# --------------------------------------------------------------------------

TMPDIR_ROLLBACK_ERR="$(mktemp -d)"
cp -r "$PROJECT_ROOT/tests/fixtures/rollback-no-summary/"* "$TMPDIR_ROLLBACK_ERR/"

err_output=$(bash "$ROLLBACK_PHASE" "$TMPDIR_ROLLBACK_ERR" M001 P01 "Should fail" 2>&1) && exit_code=0 || exit_code=$?

if [ "$exit_code" -ne 0 ]; then
  pass "rollback-phase.sh no summary → exits non-zero (exit=$exit_code)"
else
  fail "rollback-phase.sh no summary → should exit non-zero (exit=$exit_code)"
fi

rm -rf "$TMPDIR_ROLLBACK_ERR"

# --------------------------------------------------------------------------
# 2.7 mark-complete.sh — creates M001-VALIDATED marker
# --------------------------------------------------------------------------

TMPDIR_COMPLETE="$(mktemp -d)"
cp -r "$PROJECT_ROOT/tests/fixtures/consolidate-state/milestones" "$TMPDIR_COMPLETE/"

output=$(bash "$MARK_COMPLETE" "$TMPDIR_COMPLETE" M001 2>/dev/null) && exit_code=0 || exit_code=$?

if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "^VALIDATE: M001 validated"; then
  pass "mark-complete.sh → M001 validated (exit 0)"
else
  fail "mark-complete.sh → expected VALIDATE output (exit=$exit_code, output: $output)"
fi

# 2.8 Marker file exists and contains phase list
if [ -f "$TMPDIR_COMPLETE/milestones/M001/M001-VALIDATED" ]; then
  if grep -q "P01: complete" "$TMPDIR_COMPLETE/milestones/M001/M001-VALIDATED" && \
     grep -q "P02: complete" "$TMPDIR_COMPLETE/milestones/M001/M001-VALIDATED"; then
    pass "mark-complete.sh → M001-VALIDATED contains phase list"
  else
    fail "mark-complete.sh → M001-VALIDATED missing phase list"
  fi
else
  fail "mark-complete.sh → M001-VALIDATED marker not created"
fi

# 2.9 mark-complete.sh — idempotent on re-run
output2=$(bash "$MARK_COMPLETE" "$TMPDIR_COMPLETE" M001 2>/dev/null) && exit_code=0 || exit_code=$?

if [ "$exit_code" -eq 0 ] && echo "$output2" | grep -q "already validated"; then
  pass "mark-complete.sh → idempotent re-run (exit 0, already validated)"
else
  fail "mark-complete.sh → expected idempotent behavior (exit=$exit_code, output: $output2)"
fi

# 2.10 mark-complete.sh — exits non-zero when phases incomplete
TMPDIR_INCOMPLETE="$(mktemp -d)"
cp -r "$PROJECT_ROOT/tests/fixtures/consolidate-incomplete/milestones" "$TMPDIR_INCOMPLETE/"

err_output=$(bash "$MARK_COMPLETE" "$TMPDIR_INCOMPLETE" M001 2>&1) && exit_code=0 || exit_code=$?

if [ "$exit_code" -ne 0 ]; then
  pass "mark-complete.sh incomplete phases → exits non-zero (exit=$exit_code)"
else
  fail "mark-complete.sh incomplete phases → should exit non-zero (exit=$exit_code)"
fi

rm -rf "$TMPDIR_COMPLETE" "$TMPDIR_INCOMPLETE"

# ==========================================================================
# Section 3: Consolidation Tests
# ==========================================================================
echo ""
echo "--- Section 3: Consolidation ---"

CONSOLIDATE="$PROJECT_ROOT/scripts/knowledge/consolidate-artifacts.sh"

# --------------------------------------------------------------------------
# 3.1 consolidate-artifacts.sh — archives task plans and summaries
# --------------------------------------------------------------------------

TMPDIR_CONSOLIDATE="$(mktemp -d)"
cp -r "$PROJECT_ROOT/tests/fixtures/consolidate-state/"* "$TMPDIR_CONSOLIDATE/"

output=$(bash "$CONSOLIDATE" "$TMPDIR_CONSOLIDATE" M001 2>"$TMPDIR_CONSOLIDATE/stderr.log") && exit_code=0 || exit_code=$?

if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "^CONSOLIDATE: M001 consolidated"; then
  pass "consolidate-artifacts.sh → M001 consolidated (exit 0)"
else
  fail "consolidate-artifacts.sh → expected CONSOLIDATE output (exit=$exit_code, output: $output)"
fi

# 3.2 Task plans and summaries archived
archived_count=$(find "$TMPDIR_CONSOLIDATE/milestones/M001/archive" -name "T*-PLAN.md" -o -name "T*-SUMMARY.md" 2>/dev/null | wc -l | tr -d ' ')
if [ "$archived_count" -ge 12 ]; then
  pass "consolidate-artifacts.sh → task plans/summaries archived ($archived_count files)"
else
  fail "consolidate-artifacts.sh → expected ≥12 archived task files (got $archived_count)"
fi

# 3.3 Phase summaries preserved (NOT archived)
p01_summary="$TMPDIR_CONSOLIDATE/milestones/M001/phases/P01/P01-SUMMARY.md"
p02_summary="$TMPDIR_CONSOLIDATE/milestones/M001/phases/P02/P02-SUMMARY.md"
if [ -f "$p01_summary" ] && [ -f "$p02_summary" ]; then
  pass "consolidate-artifacts.sh → phase summaries preserved"
else
  fail "consolidate-artifacts.sh → phase summaries not preserved"
fi

# 3.4 Roadmap preserved
if [ -f "$TMPDIR_CONSOLIDATE/milestones/M001/M001-ROADMAP.md" ]; then
  pass "consolidate-artifacts.sh → roadmap preserved"
else
  fail "consolidate-artifacts.sh → roadmap not preserved"
fi

# 3.5 DECISIONS.md and KNOWLEDGE.md preserved
if [ -f "$TMPDIR_CONSOLIDATE/DECISIONS.md" ] && [ -f "$TMPDIR_CONSOLIDATE/KNOWLEDGE.md" ]; then
  pass "consolidate-artifacts.sh → DECISIONS.md and KNOWLEDGE.md preserved"
else
  fail "consolidate-artifacts.sh → DECISIONS.md or KNOWLEDGE.md missing"
fi

# 3.6 Achieves ≥60% reduction
stderr_content=$(cat "$TMPDIR_CONSOLIDATE/stderr.log")
reduction=$(echo "$stderr_content" | grep -oE '[0-9]+% reduction' | grep -oE '[0-9]+')
if [ -n "$reduction" ] && [ "$reduction" -ge 60 ]; then
  pass "consolidate-artifacts.sh → ≥60% reduction achieved (${reduction}%)"
else
  fail "consolidate-artifacts.sh → expected ≥60% reduction (got: ${reduction:-none}, stderr: $stderr_content)"
fi

# 3.7 Reports reduction to stderr
if echo "$stderr_content" | grep -q "^CONSOLIDATE:.*reduction"; then
  pass "consolidate-artifacts.sh → reports reduction to stderr"
else
  fail "consolidate-artifacts.sh → expected reduction report on stderr"
fi

rm -rf "$TMPDIR_CONSOLIDATE"

# --------------------------------------------------------------------------
# 3.8 consolidate-artifacts.sh — exits non-zero for incomplete milestones
# --------------------------------------------------------------------------

TMPDIR_CONSOLIDATE_ERR="$(mktemp -d)"
cp -r "$PROJECT_ROOT/tests/fixtures/consolidate-incomplete/"* "$TMPDIR_CONSOLIDATE_ERR/"

err_output=$(bash "$CONSOLIDATE" "$TMPDIR_CONSOLIDATE_ERR" M001 2>&1) && exit_code=0 || exit_code=$?

if [ "$exit_code" -ne 0 ]; then
  pass "consolidate-artifacts.sh incomplete → exits non-zero (exit=$exit_code)"
else
  fail "consolidate-artifacts.sh incomplete → should exit non-zero (exit=$exit_code)"
fi

rm -rf "$TMPDIR_CONSOLIDATE_ERR"

# ==========================================================================
# Section 4: Command File Validation & Integration Checks
# ==========================================================================
echo ""
echo "--- Section 4: Command File & Integration ---"

CONSOLIDATE_CMD="$PROJECT_ROOT/commands/consolidate.md"

# --------------------------------------------------------------------------
# 4.1 consolidate.md — YAML frontmatter present
# --------------------------------------------------------------------------

first_line=$(head -1 "$CONSOLIDATE_CMD")
if [ "$first_line" = "---" ]; then
  pass "consolidate.md has YAML frontmatter (first line is ---)"
else
  fail "consolidate.md has YAML frontmatter (first line: '$first_line')"
fi

# --------------------------------------------------------------------------
# 4.2 consolidate.md — no placeholder text
# --------------------------------------------------------------------------

placeholder_count=$(grep -ci 'placeholder' "$CONSOLIDATE_CMD" || true)
if [ "$placeholder_count" -eq 0 ]; then
  pass "consolidate.md contains no 'Placeholder' text"
else
  fail "consolidate.md contains 'Placeholder' text ($placeholder_count occurrences)"
fi

# --------------------------------------------------------------------------
# 4.3 consolidate.md — references consolidate-artifacts.sh
# --------------------------------------------------------------------------

if grep -q 'consolidate-artifacts.sh' "$CONSOLIDATE_CMD"; then
  pass "consolidate.md references consolidate-artifacts.sh"
else
  fail "consolidate.md references consolidate-artifacts.sh"
fi

# --------------------------------------------------------------------------
# 4.4 consolidate.md — references derive-phase.sh
# --------------------------------------------------------------------------

if grep -q 'derive-phase.sh' "$CONSOLIDATE_CMD"; then
  pass "consolidate.md references derive-phase.sh"
else
  fail "consolidate.md references derive-phase.sh"
fi

# --------------------------------------------------------------------------
# 4.5 consolidate.md — contains Idempotency section
# --------------------------------------------------------------------------

if grep -q '## Idempotency' "$CONSOLIDATE_CMD"; then
  pass "consolidate.md contains Idempotency section"
else
  fail "consolidate.md contains Idempotency section"
fi

# --------------------------------------------------------------------------
# 4.6 consolidate.md — contains Error Handling section
# --------------------------------------------------------------------------

if grep -q '## Error Handling' "$CONSOLIDATE_CMD"; then
  pass "consolidate.md contains Error Handling section"
else
  fail "consolidate.md contains Error Handling section"
fi

# --------------------------------------------------------------------------
# 4.7 Cross-reference: all scripts referenced in consolidate.md exist and are executable
# --------------------------------------------------------------------------

script_refs=$(grep -oE 'scripts/[a-z]+/[a-z_-]+\.sh' "$CONSOLIDATE_CMD" | sort -u)
for script_ref in $script_refs; do
  script_path="$PROJECT_ROOT/$script_ref"
  if [ -f "$script_path" ] && [ -x "$script_path" ]; then
    pass "consolidate.md cross-ref: $script_ref exists and is executable"
  elif [ -f "$script_path" ]; then
    fail "consolidate.md cross-ref: $script_ref is executable (file exists but not executable)"
  else
    fail "consolidate.md cross-ref: $script_ref exists (not found)"
  fi
done

# --------------------------------------------------------------------------
# 4.8 Cross-reference: all templates referenced in consolidate.md exist
# --------------------------------------------------------------------------

template_refs=$(grep -oE 'templates/[a-z_-]+\.md' "$CONSOLIDATE_CMD" | sort -u)
for tmpl_ref in $template_refs; do
  tmpl_path="$PROJECT_ROOT/$tmpl_ref"
  if [ -f "$tmpl_path" ]; then
    pass "consolidate.md cross-ref: $tmpl_ref exists"
  else
    fail "consolidate.md cross-ref: $tmpl_ref exists (not found)"
  fi
done

# --------------------------------------------------------------------------
# 4.9 All 4 knowledge scripts exist and are executable
# --------------------------------------------------------------------------

KNOWLEDGE_SCRIPTS="write-summary.sh append-decision.sh append-knowledge.sh consolidate-artifacts.sh"
for script in $KNOWLEDGE_SCRIPTS; do
  script_path="$PROJECT_ROOT/scripts/knowledge/$script"
  if [ -f "$script_path" ] && [ -x "$script_path" ]; then
    pass "scripts/knowledge/$script exists and is executable"
  elif [ -f "$script_path" ]; then
    fail "scripts/knowledge/$script is executable (file exists but not executable)"
  else
    fail "scripts/knowledge/$script exists (not found)"
  fi
done

# --------------------------------------------------------------------------
# 4.10 Both S06 lifecycle scripts exist and are executable
# --------------------------------------------------------------------------

LIFECYCLE_SCRIPTS="rollback-phase.sh mark-complete.sh"
for script in $LIFECYCLE_SCRIPTS; do
  script_path="$PROJECT_ROOT/scripts/lifecycle/$script"
  if [ -f "$script_path" ] && [ -x "$script_path" ]; then
    pass "scripts/lifecycle/$script exists and is executable"
  elif [ -f "$script_path" ]; then
    fail "scripts/lifecycle/$script is executable (file exists but not executable)"
  else
    fail "scripts/lifecycle/$script exists (not found)"
  fi
done

# --------------------------------------------------------------------------
# 4.11 All 6 S06 scripts exist on disk and are executable
# --------------------------------------------------------------------------

S06_SCRIPTS="scripts/knowledge/write-summary.sh scripts/knowledge/append-decision.sh scripts/knowledge/append-knowledge.sh scripts/knowledge/consolidate-artifacts.sh scripts/lifecycle/rollback-phase.sh scripts/lifecycle/mark-complete.sh"
s06_missing=0
for s06_script in $S06_SCRIPTS; do
  if [ ! -f "$PROJECT_ROOT/$s06_script" ] || [ ! -x "$PROJECT_ROOT/$s06_script" ]; then
    fail "$s06_script exists and is executable"
    s06_missing=$((s06_missing + 1))
  fi
done
if [ "$s06_missing" -eq 0 ]; then
  pass "all 6 S06 scripts exist on disk and are executable"
fi

# --------------------------------------------------------------------------
# 4.12 Failure diagnostic: write-summary.sh usage error includes "usage" or "Usage"
# --------------------------------------------------------------------------

usage_err=$(bash "$PROJECT_ROOT/scripts/knowledge/write-summary.sh" 2>&1 || true)
if echo "$usage_err" | grep -qi 'usage'; then
  pass "write-summary.sh usage error includes 'usage'"
else
  fail "write-summary.sh usage error includes 'usage' (got: $usage_err)"
fi

# --------------------------------------------------------------------------
# 4.13 Failure diagnostic: rollback-phase.sh error on nonexistent phase mentions "summary" or "not found"
# --------------------------------------------------------------------------

TMPDIR_DIAG="$(mktemp -d)"
mkdir -p "$TMPDIR_DIAG/milestones/M001/phases/P99"
rollback_err=$(bash "$PROJECT_ROOT/scripts/lifecycle/rollback-phase.sh" "$TMPDIR_DIAG" M001 P99 "diag test" 2>&1 || true)
if echo "$rollback_err" | grep -qi 'summary\|not found'; then
  pass "rollback-phase.sh error on missing phase mentions 'summary' or 'not found'"
else
  fail "rollback-phase.sh error on missing phase mentions 'summary' or 'not found' (got: $rollback_err)"
fi
rm -rf "$TMPDIR_DIAG"

# --------------------------------------------------------------------------
# 4.14 Failure diagnostic: append-decision.sh error on nonexistent file mentions "not found" or "does not exist"
# --------------------------------------------------------------------------

decision_err=$(bash "$PROJECT_ROOT/scripts/knowledge/append-decision.sh" "/tmp/no-such-file-$(date +%s).md" "x" "x" "x" "x" "x" 2>&1 || true)
if echo "$decision_err" | grep -qi 'not found\|does not exist\|no such'; then
  pass "append-decision.sh error on nonexistent file has descriptive message"
else
  fail "append-decision.sh error on nonexistent file has descriptive message (got: $decision_err)"
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
