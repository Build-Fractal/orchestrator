#!/usr/bin/env bash
# tests/test-s05-autonomous-mode.sh — Validates S05 autonomous mode contracts
# Tests: lifecycle scripts (lock-manager, stuck-detector, recovery-briefing,
#        budget-checker), command files, and integration.
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
# Section 1: Lifecycle Script Tests
# ==========================================================================
echo ""
echo "--- Section 1: Lifecycle Scripts ---"

LOCK_MGR="$PROJECT_ROOT/scripts/lifecycle/lock-manager.sh"
STUCK_DET="$PROJECT_ROOT/scripts/lifecycle/stuck-detector.sh"
RECOVERY="$PROJECT_ROOT/scripts/lifecycle/recovery-briefing.sh"
BUDGET="$PROJECT_ROOT/scripts/lifecycle/budget-checker.sh"

# --------------------------------------------------------------------------
# 1.1 lock-manager.sh — create in temp dir, check status (ACTIVE), break, check (NONE)
# --------------------------------------------------------------------------

TMPDIR_LOCK="$(mktemp -d)"
TMPLOCK="$TMPDIR_LOCK/test.lock"

# Create lock
output=$(bash "$LOCK_MGR" create "$TMPLOCK" task "M001/P01/T01" 2>/dev/null) && exit_code=0 || exit_code=$?
if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "^LOCK:CREATED"; then
  pass "lock-manager.sh create → LOCK:CREATED (exit 0)"
else
  fail "lock-manager.sh create → LOCK:CREATED (exit=$exit_code, output: $output)"
fi

# The lock was created by a subshell (whose PID is dead now). Overwrite pid with
# PID 1 (launchd/init — always alive) so the status check can verify ACTIVE detection.
sed "s/\"pid\":[[:space:]]*[0-9]*/\"pid\": 1/" "$TMPLOCK" > "${TMPLOCK}.new" && mv "${TMPLOCK}.new" "$TMPLOCK"

# Status should be ACTIVE (our own PID is running)
output=$(bash "$LOCK_MGR" status "$TMPLOCK" 2>/dev/null) && exit_code=0 || exit_code=$?
if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "^LOCK:ACTIVE"; then
  pass "lock-manager.sh status → LOCK:ACTIVE (own PID)"
else
  fail "lock-manager.sh status → LOCK:ACTIVE (exit=$exit_code, output: $output)"
fi

# Break the lock
output=$(bash "$LOCK_MGR" break "$TMPLOCK" 2>/dev/null) && exit_code=0 || exit_code=$?
if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "^LOCK:BROKEN"; then
  pass "lock-manager.sh break → LOCK:BROKEN"
else
  fail "lock-manager.sh break → LOCK:BROKEN (exit=$exit_code, output: $output)"
fi

# Status after break should be NONE
output=$(bash "$LOCK_MGR" status "$TMPLOCK" 2>/dev/null) && exit_code=0 || exit_code=$?
if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "^LOCK:NONE"; then
  pass "lock-manager.sh status after break → LOCK:NONE"
else
  fail "lock-manager.sh status after break → LOCK:NONE (exit=$exit_code, output: $output)"
fi

rm -rf "$TMPDIR_LOCK"

# --------------------------------------------------------------------------
# 1.2 lock-manager.sh — stale lock fixture → STALE
# --------------------------------------------------------------------------

STALE_FIXTURE="$PROJECT_ROOT/tests/fixtures/auto-lock/orchestrator.lock"
output=$(bash "$LOCK_MGR" status "$STALE_FIXTURE" 2>/dev/null) && exit_code=0 || exit_code=$?
if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "^LOCK:STALE"; then
  pass "lock-manager.sh status on stale fixture → LOCK:STALE"
else
  fail "lock-manager.sh status on stale fixture → LOCK:STALE (exit=$exit_code, output: $output)"
fi

# --------------------------------------------------------------------------
# 1.3 lock-manager.sh — update appends completed unit
# --------------------------------------------------------------------------

TMPDIR_UPD="$(mktemp -d)"
TMPLOCK_UPD="$TMPDIR_UPD/update-test.lock"
bash "$LOCK_MGR" create "$TMPLOCK_UPD" task "M001/P01/T01" >/dev/null 2>&1
output=$(bash "$LOCK_MGR" update "$TMPLOCK_UPD" "M001/P01/T01" 2>/dev/null) && exit_code=0 || exit_code=$?
if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "^LOCK:UPDATED"; then
  # Verify the completed unit is in the file
  if grep -q "M001/P01/T01" "$TMPLOCK_UPD"; then
    pass "lock-manager.sh update → LOCK:UPDATED with completed unit in file"
  else
    fail "lock-manager.sh update → completed unit not found in lock file"
  fi
else
  fail "lock-manager.sh update → LOCK:UPDATED (exit=$exit_code, output: $output)"
fi
rm -rf "$TMPDIR_UPD"

# --------------------------------------------------------------------------
# 1.4 lock-manager.sh — invalid operation → exit 1
# --------------------------------------------------------------------------

output=$(bash "$LOCK_MGR" bogus 2>&1) && exit_code=0 || exit_code=$?
if [ "$exit_code" -ne 0 ]; then
  pass "lock-manager.sh invalid operation → exit 1"
else
  fail "lock-manager.sh invalid operation → exit 1 (got exit 0)"
fi

# --------------------------------------------------------------------------
# 1.5 lock-manager.sh — no args → exit 1 with usage
# --------------------------------------------------------------------------

stderr_output=$(bash "$LOCK_MGR" 2>&1 1>/dev/null) && exit_code=$? || exit_code=$?
if [ "$exit_code" -ne 0 ] && echo "$stderr_output" | grep -qi "usage"; then
  pass "lock-manager.sh no args → exit 1 with usage"
else
  fail "lock-manager.sh no args → exit 1 with usage (exit=$exit_code, stderr='$stderr_output')"
fi

# --------------------------------------------------------------------------
# 1.6 stuck-detector.sh — fixture stuck log → STUCK:YES
# --------------------------------------------------------------------------

STUCK_LOG="$PROJECT_ROOT/tests/fixtures/auto-stuck/execution-log.jsonl"
output=$(bash "$STUCK_DET" "$STUCK_LOG" "M001/P01/T01" 2>/dev/null) && exit_code=0 || exit_code=$?
if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "^STUCK:YES"; then
  pass "stuck-detector.sh fixture log → STUCK:YES"
else
  fail "stuck-detector.sh fixture log → STUCK:YES (exit=$exit_code, output: $output)"
fi

# Verify dispatches=2 is in the output
if echo "$output" | grep -q "dispatches=2"; then
  pass "stuck-detector.sh → reports dispatches=2"
else
  fail "stuck-detector.sh → reports dispatches=2 (output: $output)"
fi

# --------------------------------------------------------------------------
# 1.7 stuck-detector.sh — empty log → STUCK:NO with "No dispatches"
# --------------------------------------------------------------------------

EMPTY_LOG="$PROJECT_ROOT/tests/fixtures/auto-budget/execution-log-empty.jsonl"
output=$(bash "$STUCK_DET" "$EMPTY_LOG" "M001/P01/T01" 2>/dev/null) && exit_code=0 || exit_code=$?
if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "^STUCK:NO" && echo "$output" | grep -q "No dispatches"; then
  pass "stuck-detector.sh empty log → STUCK:NO with 'No dispatches'"
else
  fail "stuck-detector.sh empty log → STUCK:NO (exit=$exit_code, output: $output)"
fi

# --------------------------------------------------------------------------
# 1.8 stuck-detector.sh — missing arguments → exit 1
# --------------------------------------------------------------------------

stderr_output=$(bash "$STUCK_DET" 2>&1 1>/dev/null) && exit_code=$? || exit_code=$?
if [ "$exit_code" -ne 0 ]; then
  pass "stuck-detector.sh missing args → exit 1"
else
  fail "stuck-detector.sh missing args → exit 1 (got exit 0)"
fi

# --------------------------------------------------------------------------
# 1.9 recovery-briefing.sh — fixture dir → produces output with Crash State
# --------------------------------------------------------------------------

RECOVERY_FIXTURE="$PROJECT_ROOT/tests/fixtures/auto-recovery"
output=$(bash "$RECOVERY" "$RECOVERY_FIXTURE" 2>/dev/null) && exit_code=0 || exit_code=$?
if [ "$exit_code" -eq 0 ] && [ -n "$output" ] && echo "$output" | grep -q "Crash State"; then
  pass "recovery-briefing.sh fixture → produces output with 'Crash State'"
else
  fail "recovery-briefing.sh fixture → produces output with 'Crash State' (exit=$exit_code)"
fi

# Verify it includes Completed Work and Incomplete Work sections
if echo "$output" | grep -q "Completed Work" && echo "$output" | grep -q "Incomplete Work"; then
  pass "recovery-briefing.sh → includes Completed and Incomplete Work sections"
else
  fail "recovery-briefing.sh → includes Completed and Incomplete Work sections"
fi

# --------------------------------------------------------------------------
# 1.10 recovery-briefing.sh — nonexistent dir → exit 1
# --------------------------------------------------------------------------

output=$(bash "$RECOVERY" "/tmp/nonexistent-dir-$$" 2>&1) && exit_code=0 || exit_code=$?
if [ "$exit_code" -ne 0 ]; then
  pass "recovery-briefing.sh nonexistent dir → exit 1"
else
  fail "recovery-briefing.sh nonexistent dir → exit 1 (got exit 0)"
fi

# --------------------------------------------------------------------------
# 1.11 budget-checker.sh — fixture log with --dispatch-budget 3 → EXCEEDED
# --------------------------------------------------------------------------

BUDGET_LOG="$PROJECT_ROOT/tests/fixtures/auto-budget/execution-log.jsonl"
output=$(bash "$BUDGET" "$BUDGET_LOG" --dispatch-budget 3 2>/dev/null) && exit_code=0 || exit_code=$?
if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "^BUDGET:EXCEEDED"; then
  pass "budget-checker.sh dispatch-budget 3 with 5 dispatches → BUDGET:EXCEEDED"
else
  fail "budget-checker.sh dispatch-budget 3 with 5 dispatches → BUDGET:EXCEEDED (exit=$exit_code, output: $output)"
fi

# --------------------------------------------------------------------------
# 1.12 budget-checker.sh — fixture log with --dispatch-budget 10 → OK
# --------------------------------------------------------------------------

output=$(bash "$BUDGET" "$BUDGET_LOG" --dispatch-budget 10 2>/dev/null) && exit_code=0 || exit_code=$?
if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "^BUDGET:OK"; then
  pass "budget-checker.sh dispatch-budget 10 with 5 dispatches → BUDGET:OK"
else
  fail "budget-checker.sh dispatch-budget 10 with 5 dispatches → BUDGET:OK (exit=$exit_code, output: $output)"
fi

# --------------------------------------------------------------------------
# 1.13 budget-checker.sh — empty log → BUDGET:OK
# --------------------------------------------------------------------------

output=$(bash "$BUDGET" "$EMPTY_LOG" --dispatch-budget 5 2>/dev/null) && exit_code=0 || exit_code=$?
if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "^BUDGET:OK"; then
  pass "budget-checker.sh empty log → BUDGET:OK"
else
  fail "budget-checker.sh empty log → BUDGET:OK (exit=$exit_code, output: $output)"
fi

# --------------------------------------------------------------------------
# 1.14 budget-checker.sh — no limits → BUDGET:OK (no limits configured)
# --------------------------------------------------------------------------

output=$(bash "$BUDGET" "$BUDGET_LOG" 2>/dev/null) && exit_code=0 || exit_code=$?
if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "no limits configured"; then
  pass "budget-checker.sh no limits → BUDGET:OK (no limits configured)"
else
  fail "budget-checker.sh no limits → BUDGET:OK (no limits configured) (exit=$exit_code, output: $output)"
fi

# --------------------------------------------------------------------------
# 1.15 budget-checker.sh — no args → exit 1 with usage
# --------------------------------------------------------------------------

stderr_output=$(bash "$BUDGET" 2>&1 1>/dev/null) && exit_code=$? || exit_code=$?
if [ "$exit_code" -ne 0 ] && echo "$stderr_output" | grep -qi "usage"; then
  pass "budget-checker.sh no args → exit 1 with usage"
else
  fail "budget-checker.sh no args → exit 1 with usage (exit=$exit_code)"
fi

# --------------------------------------------------------------------------
# 1.16 lock-manager.sh — break on nonexistent file → LOCK:NONE
# --------------------------------------------------------------------------

output=$(bash "$LOCK_MGR" break "/tmp/nonexistent-lock-$$" 2>/dev/null) && exit_code=0 || exit_code=$?
if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "^LOCK:NONE"; then
  pass "lock-manager.sh break nonexistent → LOCK:NONE"
else
  fail "lock-manager.sh break nonexistent → LOCK:NONE (exit=$exit_code, output: $output)"
fi

# --------------------------------------------------------------------------
# 1.17 All 4 lifecycle scripts have shebang and set -euo pipefail
# --------------------------------------------------------------------------

all_have_shebang=true
for script in "$LOCK_MGR" "$STUCK_DET" "$RECOVERY" "$BUDGET"; do
  if ! head -1 "$script" | grep -q '#!/usr/bin/env bash'; then
    all_have_shebang=false
    break
  fi
done
if [ "$all_have_shebang" = "true" ]; then
  pass "All 4 lifecycle scripts have #!/usr/bin/env bash shebang"
else
  fail "All 4 lifecycle scripts have #!/usr/bin/env bash shebang"
fi

all_have_strict=true
for script in "$LOCK_MGR" "$STUCK_DET" "$RECOVERY" "$BUDGET"; do
  if ! grep -q 'set -euo pipefail' "$script"; then
    all_have_strict=false
    break
  fi
done
if [ "$all_have_strict" = "true" ]; then
  pass "All 4 lifecycle scripts have set -euo pipefail"
else
  fail "All 4 lifecycle scripts have set -euo pipefail"
fi

# --------------------------------------------------------------------------
# 1.18 No lifecycle scripts use declare -A (bash 3.2 compatibility)
# --------------------------------------------------------------------------

uses_declare_a=false
for script in "$LOCK_MGR" "$STUCK_DET" "$RECOVERY" "$BUDGET"; do
  if grep -q 'declare -A' "$script"; then
    uses_declare_a=true
    break
  fi
done
if [ "$uses_declare_a" = "false" ]; then
  pass "No lifecycle scripts use declare -A (bash 3.2 compatible)"
else
  fail "No lifecycle scripts use declare -A (bash 3.2 compatible)"
fi

# ==========================================================================
# Section 2: Command File Tests — auto.md
# ==========================================================================
echo ""
echo "--- Section 2: auto.md Command File ---"

AUTO_CMD="$PROJECT_ROOT/commands/auto.md"

# --------------------------------------------------------------------------
# 2.1 auto.md exists and has YAML frontmatter
# --------------------------------------------------------------------------
if [ -f "$AUTO_CMD" ] && head -1 "$AUTO_CMD" | grep -q '^---$'; then
  pass "auto.md exists and has YAML frontmatter"
else
  fail "auto.md exists and has YAML frontmatter"
fi

# --------------------------------------------------------------------------
# 2.2 auto.md does not contain "Placeholder"
# --------------------------------------------------------------------------
if ! grep -q 'Placeholder' "$AUTO_CMD"; then
  pass "auto.md does not contain 'Placeholder'"
else
  fail "auto.md does not contain 'Placeholder'"
fi

# --------------------------------------------------------------------------
# 2.3 auto.md has ≥100 lines
# --------------------------------------------------------------------------
line_count=$(wc -l < "$AUTO_CMD" | tr -d ' ')
if [ "$line_count" -ge 100 ]; then
  pass "auto.md has ≥100 lines ($line_count lines)"
else
  fail "auto.md has ≥100 lines (got $line_count)"
fi

# --------------------------------------------------------------------------
# 2.4 auto.md has trigger-phrased description in frontmatter
# --------------------------------------------------------------------------
if head -5 "$AUTO_CMD" | grep -q '^description:'; then
  pass "auto.md has description in YAML frontmatter"
else
  fail "auto.md has description in YAML frontmatter"
fi

# --------------------------------------------------------------------------
# 2.5 auto.md references scripts/lifecycle/lock-manager.sh
# --------------------------------------------------------------------------
if grep -q 'scripts/lifecycle/lock-manager.sh' "$AUTO_CMD"; then
  pass "auto.md references scripts/lifecycle/lock-manager.sh"
else
  fail "auto.md references scripts/lifecycle/lock-manager.sh"
fi

# --------------------------------------------------------------------------
# 2.6 auto.md references scripts/lifecycle/stuck-detector.sh
# --------------------------------------------------------------------------
if grep -q 'scripts/lifecycle/stuck-detector.sh' "$AUTO_CMD"; then
  pass "auto.md references scripts/lifecycle/stuck-detector.sh"
else
  fail "auto.md references scripts/lifecycle/stuck-detector.sh"
fi

# --------------------------------------------------------------------------
# 2.7 auto.md references scripts/lifecycle/budget-checker.sh
# --------------------------------------------------------------------------
if grep -q 'scripts/lifecycle/budget-checker.sh' "$AUTO_CMD"; then
  pass "auto.md references scripts/lifecycle/budget-checker.sh"
else
  fail "auto.md references scripts/lifecycle/budget-checker.sh"
fi

# --------------------------------------------------------------------------
# 2.8 auto.md references scripts/lifecycle/recovery-briefing.sh
# --------------------------------------------------------------------------
if grep -q 'scripts/lifecycle/recovery-briefing.sh' "$AUTO_CMD"; then
  pass "auto.md references scripts/lifecycle/recovery-briefing.sh"
else
  fail "auto.md references scripts/lifecycle/recovery-briefing.sh"
fi

# --------------------------------------------------------------------------
# 2.9 auto.md references scripts/dispatch/build-context.sh
# --------------------------------------------------------------------------
if grep -q 'scripts/dispatch/build-context.sh' "$AUTO_CMD"; then
  pass "auto.md references scripts/dispatch/build-context.sh"
else
  fail "auto.md references scripts/dispatch/build-context.sh"
fi

# --------------------------------------------------------------------------
# 2.10 auto.md references scripts/verify/check-must-haves.sh
# --------------------------------------------------------------------------
if grep -q 'scripts/verify/check-must-haves.sh' "$AUTO_CMD"; then
  pass "auto.md references scripts/verify/check-must-haves.sh"
else
  fail "auto.md references scripts/verify/check-must-haves.sh"
fi

# --------------------------------------------------------------------------
# 2.11 auto.md covers key workflow sections
# --------------------------------------------------------------------------
missing_sections=""
for section in "Autonomous Loop" "Pause Handling" "Phase Transition" "Completion" "Idempotency" "Error Handling" "Lock Acquisition"; do
  if ! grep -q "$section" "$AUTO_CMD"; then
    missing_sections="$missing_sections $section"
  fi
done
if [ -z "$missing_sections" ]; then
  pass "auto.md covers all key workflow sections"
else
  fail "auto.md missing sections:$missing_sections"
fi

# ==========================================================================
# Section 3: Command File Tests — resume.md and discuss.md
# ==========================================================================
echo ""
echo "--- Section 3: resume.md and discuss.md Command Files ---"

RESUME_CMD="$PROJECT_ROOT/commands/resume.md"
DISCUSS_CMD="$PROJECT_ROOT/commands/discuss.md"

# --------------------------------------------------------------------------
# 3.1 resume.md exists and has YAML frontmatter
# --------------------------------------------------------------------------
if [ -f "$RESUME_CMD" ] && head -1 "$RESUME_CMD" | grep -q '^---$'; then
  pass "resume.md exists and has YAML frontmatter"
else
  fail "resume.md exists and has YAML frontmatter"
fi

# --------------------------------------------------------------------------
# 3.2 resume.md does not contain "Placeholder"
# --------------------------------------------------------------------------
if ! grep -q 'Placeholder' "$RESUME_CMD"; then
  pass "resume.md does not contain 'Placeholder'"
else
  fail "resume.md does not contain 'Placeholder'"
fi

# --------------------------------------------------------------------------
# 3.3 resume.md has ≥80 lines
# --------------------------------------------------------------------------
resume_lines=$(wc -l < "$RESUME_CMD" | tr -d ' ')
if [ "$resume_lines" -ge 80 ]; then
  pass "resume.md has ≥80 lines ($resume_lines lines)"
else
  fail "resume.md has ≥80 lines (got $resume_lines)"
fi

# --------------------------------------------------------------------------
# 3.4 resume.md has trigger-phrased description in frontmatter
# --------------------------------------------------------------------------
if head -5 "$RESUME_CMD" | grep -q '^description:'; then
  pass "resume.md has description in YAML frontmatter"
else
  fail "resume.md has description in YAML frontmatter"
fi

# --------------------------------------------------------------------------
# 3.5 resume.md references scripts/lifecycle/lock-manager.sh
# --------------------------------------------------------------------------
if grep -q 'scripts/lifecycle/lock-manager.sh' "$RESUME_CMD"; then
  pass "resume.md references scripts/lifecycle/lock-manager.sh"
else
  fail "resume.md references scripts/lifecycle/lock-manager.sh"
fi

# --------------------------------------------------------------------------
# 3.6 resume.md references scripts/lifecycle/recovery-briefing.sh
# --------------------------------------------------------------------------
if grep -q 'scripts/lifecycle/recovery-briefing.sh' "$RESUME_CMD"; then
  pass "resume.md references scripts/lifecycle/recovery-briefing.sh"
else
  fail "resume.md references scripts/lifecycle/recovery-briefing.sh"
fi

# --------------------------------------------------------------------------
# 3.7 resume.md references scripts/lifecycle/stuck-detector.sh
# --------------------------------------------------------------------------
if grep -q 'scripts/lifecycle/stuck-detector.sh' "$RESUME_CMD"; then
  pass "resume.md references scripts/lifecycle/stuck-detector.sh"
else
  fail "resume.md references scripts/lifecycle/stuck-detector.sh"
fi

# --------------------------------------------------------------------------
# 3.8 resume.md covers crash recovery and pause resume paths
# --------------------------------------------------------------------------
missing_paths=""
for section in "Path A" "Path B" "Crash Recovery" "Pause" "Recovery Type Detection"; do
  if ! grep -q "$section" "$RESUME_CMD"; then
    missing_paths="$missing_paths $section"
  fi
done
if [ -z "$missing_paths" ]; then
  pass "resume.md covers crash recovery and pause resume paths"
else
  fail "resume.md missing sections:$missing_paths"
fi

# --------------------------------------------------------------------------
# 3.9 resume.md references templates/continue-file.md
# --------------------------------------------------------------------------
if grep -q 'templates/continue-file.md' "$RESUME_CMD"; then
  pass "resume.md references templates/continue-file.md"
else
  fail "resume.md references templates/continue-file.md"
fi

# --------------------------------------------------------------------------
# 3.10 discuss.md exists and has YAML frontmatter
# --------------------------------------------------------------------------
if [ -f "$DISCUSS_CMD" ] && head -1 "$DISCUSS_CMD" | grep -q '^---$'; then
  pass "discuss.md exists and has YAML frontmatter"
else
  fail "discuss.md exists and has YAML frontmatter"
fi

# --------------------------------------------------------------------------
# 3.11 discuss.md does not contain "Placeholder"
# --------------------------------------------------------------------------
if ! grep -q 'Placeholder' "$DISCUSS_CMD"; then
  pass "discuss.md does not contain 'Placeholder'"
else
  fail "discuss.md does not contain 'Placeholder'"
fi

# --------------------------------------------------------------------------
# 3.12 discuss.md has ≥60 lines
# --------------------------------------------------------------------------
discuss_lines=$(wc -l < "$DISCUSS_CMD" | tr -d ' ')
if [ "$discuss_lines" -ge 60 ]; then
  pass "discuss.md has ≥60 lines ($discuss_lines lines)"
else
  fail "discuss.md has ≥60 lines (got $discuss_lines)"
fi

# --------------------------------------------------------------------------
# 3.13 discuss.md has trigger-phrased description in frontmatter
# --------------------------------------------------------------------------
if head -5 "$DISCUSS_CMD" | grep -q '^description:'; then
  pass "discuss.md has description in YAML frontmatter"
else
  fail "discuss.md has description in YAML frontmatter"
fi

# --------------------------------------------------------------------------
# 3.14 discuss.md references templates/context-draft.md
# --------------------------------------------------------------------------
if grep -q 'templates/context-draft.md' "$DISCUSS_CMD"; then
  pass "discuss.md references templates/context-draft.md"
else
  fail "discuss.md references templates/context-draft.md"
fi

# --------------------------------------------------------------------------
# 3.15 discuss.md covers create, update, and finalize operations
# --------------------------------------------------------------------------
missing_ops=""
for op in "Create Context Draft" "Update Context Draft" "Finalize Context"; do
  if ! grep -q "$op" "$DISCUSS_CMD"; then
    missing_ops="$missing_ops '$op'"
  fi
done
if [ -z "$missing_ops" ]; then
  pass "discuss.md covers create, update, and finalize operations"
else
  fail "discuss.md missing operations:$missing_ops"
fi

# ==========================================================================
# Section 4: Integration & Diagnostics
# ==========================================================================
echo ""
echo "--- Section 4: Integration & Diagnostics ---"

# --------------------------------------------------------------------------
# 4.1 Cross-reference: commands reference only existing, executable scripts
# --------------------------------------------------------------------------

all_scripts_ok=true
missing_scripts=""
for cmd_file in "$AUTO_CMD" "$RESUME_CMD" "$DISCUSS_CMD"; do
  cmd_name=$(basename "$cmd_file")
  # Extract all scripts/ references (e.g., scripts/lifecycle/lock-manager.sh)
  script_refs=$(grep -oE 'scripts/[a-z]+/[a-z_-]+\.sh' "$cmd_file" | sort -u)
  for ref in $script_refs; do
    full_path="$PROJECT_ROOT/$ref"
    if [ ! -f "$full_path" ]; then
      all_scripts_ok=false
      missing_scripts="$missing_scripts $cmd_name→$ref(missing)"
    elif [ ! -x "$full_path" ]; then
      all_scripts_ok=false
      missing_scripts="$missing_scripts $cmd_name→$ref(not-executable)"
    fi
  done
done
if [ "$all_scripts_ok" = "true" ]; then
  pass "All commands reference only existing, executable scripts"
else
  fail "Commands reference missing/non-executable scripts:$missing_scripts"
fi

# --------------------------------------------------------------------------
# 4.2 Cross-reference: commands reference only existing templates
# --------------------------------------------------------------------------

all_templates_ok=true
missing_templates=""
for cmd_file in "$AUTO_CMD" "$RESUME_CMD" "$DISCUSS_CMD"; do
  cmd_name=$(basename "$cmd_file")
  # Extract all templates/ references (e.g., templates/continue-file.md)
  template_refs=$(grep -oE 'templates/[a-z_-]+\.md' "$cmd_file" | sort -u)
  for ref in $template_refs; do
    full_path="$PROJECT_ROOT/$ref"
    if [ ! -f "$full_path" ]; then
      all_templates_ok=false
      missing_templates="$missing_templates $cmd_name→$ref"
    fi
  done
done
if [ "$all_templates_ok" = "true" ]; then
  pass "All commands reference only existing templates"
else
  fail "Commands reference missing templates:$missing_templates"
fi

# --------------------------------------------------------------------------
# 4.3 Cross-reference: auto.md references speckit.orchestrator.verify
# --------------------------------------------------------------------------

if grep -q 'speckit.orchestrator.verify' "$AUTO_CMD"; then
  pass "auto.md references speckit.orchestrator.verify (verification in loop)"
else
  fail "auto.md references speckit.orchestrator.verify"
fi

# --------------------------------------------------------------------------
# 4.4 Cross-reference: resume.md references dispatch or auto command
# --------------------------------------------------------------------------

if grep -q 'speckit.orchestrator.dispatch\|speckit.orchestrator.auto' "$RESUME_CMD"; then
  pass "resume.md references speckit.orchestrator.dispatch or .auto (resumes execution)"
else
  fail "resume.md references speckit.orchestrator.dispatch or .auto"
fi

# --------------------------------------------------------------------------
# 4.5 Failure diagnostic: lock-manager.sh no args → exit 1, stderr non-empty
# --------------------------------------------------------------------------

lm_stderr=$(bash "$LOCK_MGR" 2>&1 1>/dev/null) && lm_exit=$? || lm_exit=$?
if [ "$lm_exit" -ne 0 ] && [ -n "$lm_stderr" ]; then
  pass "lock-manager.sh no args → exit 1 with non-empty stderr"
else
  fail "lock-manager.sh no args → exit=$lm_exit, stderr='$lm_stderr'"
fi

# --------------------------------------------------------------------------
# 4.6 Failure diagnostic: stuck-detector.sh no args → exit 1, stderr non-empty
# --------------------------------------------------------------------------

sd_stderr=$(bash "$STUCK_DET" 2>&1 1>/dev/null) && sd_exit=$? || sd_exit=$?
if [ "$sd_exit" -ne 0 ] && [ -n "$sd_stderr" ]; then
  pass "stuck-detector.sh no args → exit 1 with non-empty stderr"
else
  fail "stuck-detector.sh no args → exit=$sd_exit, stderr='$sd_stderr'"
fi

# --------------------------------------------------------------------------
# 4.7 Failure diagnostic: stuck-detector.sh empty log → exit 0, "No dispatches"
# --------------------------------------------------------------------------

sd_output=$(bash "$STUCK_DET" "$EMPTY_LOG" "M001/P01/T99" 2>/dev/null) && sd_exit2=$? || sd_exit2=$?
if [ "$sd_exit2" -eq 0 ] && echo "$sd_output" | grep -q "No dispatches"; then
  pass "stuck-detector.sh empty log + unknown task → exit 0 with 'No dispatches'"
else
  fail "stuck-detector.sh empty log → exit=$sd_exit2, output='$sd_output'"
fi

# --------------------------------------------------------------------------
# 4.8 Failure diagnostic: recovery-briefing.sh nonexistent path → exit 1
# --------------------------------------------------------------------------

bash "$RECOVERY" /nonexistent/path >/dev/null 2>&1 && rb_exit=$? || rb_exit=$?
if [ "$rb_exit" -ne 0 ]; then
  pass "recovery-briefing.sh nonexistent path → exit 1"
else
  fail "recovery-briefing.sh nonexistent path → expected exit 1, got exit 0"
fi

# --------------------------------------------------------------------------
# 4.9 Failure diagnostic: budget-checker.sh no args → exit 1, stderr non-empty
# --------------------------------------------------------------------------

bc_stderr=$(bash "$BUDGET" 2>&1 1>/dev/null) && bc_exit=$? || bc_exit=$?
if [ "$bc_exit" -ne 0 ] && [ -n "$bc_stderr" ]; then
  pass "budget-checker.sh no args → exit 1 with non-empty stderr"
else
  fail "budget-checker.sh no args → exit=$bc_exit, stderr='$bc_stderr'"
fi

# --------------------------------------------------------------------------
# 4.10 Completeness: all 3 commands have YAML frontmatter, no Placeholder text
# --------------------------------------------------------------------------

commands_ok=true
for cmd_file in "$AUTO_CMD" "$RESUME_CMD" "$DISCUSS_CMD"; do
  cmd_name=$(basename "$cmd_file")
  if ! head -1 "$cmd_file" | grep -q '^---$'; then
    commands_ok=false
  fi
  if grep -q 'Placeholder' "$cmd_file"; then
    commands_ok=false
  fi
done
if [ "$commands_ok" = "true" ]; then
  pass "All 3 S05 commands have YAML frontmatter and no Placeholder text"
else
  fail "Some S05 commands missing frontmatter or contain Placeholder"
fi

# --------------------------------------------------------------------------
# 4.11 Completeness: all 4 lifecycle scripts are executable
# --------------------------------------------------------------------------

scripts_exec=true
for script in "$LOCK_MGR" "$STUCK_DET" "$RECOVERY" "$BUDGET"; do
  if [ ! -x "$script" ]; then
    scripts_exec=false
  fi
done
if [ "$scripts_exec" = "true" ]; then
  pass "All 4 lifecycle scripts are executable (-x)"
else
  fail "Some lifecycle scripts are not executable"
fi

# ==========================================================================
# Summary
# ==========================================================================
echo ""
echo "--- Overall Results ---"
echo "$PASS_COUNT/$TOTAL checks passed"

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "$FAIL_COUNT checks FAILED"
  exit 1
fi

exit 0
