---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M016"
goal: "Add anti-pattern linter, update agent-facing content to remove Class A patterns, and inject prohibited-patterns section into dispatch payloads"
demo_sentence: "The dispatch payload includes a 'Prohibited inline bash patterns' section, plan templates reference run-suite.sh instead of chained commands, and anti-pattern-lint.sh exits non-zero on a test fixture containing $(date ...)."
risk: "high"
depends_on: ["P01", "P02"]
---

## Must-Haves

### Truths

- `anti-pattern-lint.sh` exits non-zero on a test fixture containing `$(date ...)` with file:line diagnostics
  - Check: `bash scripts/verify/m016-p03-lint-detects-subst.sh`
- `anti-pattern-lint.sh` exits non-zero on a test fixture containing backtick command substitution
  - Check: `bash scripts/verify/m016-p03-lint-detects-backtick.sh`
- `anti-pattern-lint.sh` exits non-zero on a test fixture containing `{a,b}` brace expansion
  - Check: `bash scripts/verify/m016-p03-lint-detects-brace.sh`
- `anti-pattern-lint.sh` exits 0 when scanning its own source (self-exclusion works)
  - Check: `bash scripts/verify/m016-p03-lint-self-excludes.sh`
- `anti-pattern-lint.sh` exits 0 when scanning clean agent-facing files (no false positives on current content)
  - Check: `bash scripts/verify/m016-p03-lint-clean-pass.sh`
- Dispatch payload includes a "Prohibited inline bash patterns" section referencing ANTIPATTERNS.md
  - Check: `bash scripts/verify/m016-p03-payload-prohibited.sh`
- `templates/task-plan.md` does not contain `$(` outside of comment/documentation blocks that describe forbidden patterns
  - Check: `bash scripts/verify/m016-p03-task-template-clean.sh`
- `commands/consolidate.md` does not contain `state=$(bash` command substitution
  - Check: `bash scripts/verify/m016-p03-consolidate-clean.sh`
- `templates/claude-code-appendix.md` does not contain `output=$(bash` command substitution as an example to follow
  - Check: `bash scripts/verify/m016-p03-appendix-clean.sh`
- `anti-pattern-lint.sh` is Bash 3.2 compatible
  - Check: `bash scripts/verify/m016-p03-lint-bash32.sh`

### Artifacts

- scripts/verify/anti-pattern-lint.sh (min 60 lines, contains "ANTIPATTERNS")
- scripts/verify/m016-p03-lint-detects-subst.sh (min 10 lines, contains "PASS")
- scripts/verify/m016-p03-lint-detects-backtick.sh (min 10 lines, contains "PASS")
- scripts/verify/m016-p03-lint-detects-brace.sh (min 10 lines, contains "PASS")
- scripts/verify/m016-p03-lint-self-excludes.sh (min 5 lines, contains "PASS")
- scripts/verify/m016-p03-lint-clean-pass.sh (min 5 lines, contains "PASS")
- scripts/verify/m016-p03-payload-prohibited.sh (min 10 lines, contains "PASS")
- scripts/verify/m016-p03-task-template-clean.sh (min 5 lines, contains "PASS")
- scripts/verify/m016-p03-consolidate-clean.sh (min 5 lines, contains "PASS")
- scripts/verify/m016-p03-appendix-clean.sh (min 5 lines, contains "PASS")
- scripts/verify/m016-p03-lint-bash32.sh (min 5 lines, contains "PASS")

### Key Links

- scripts/verify/anti-pattern-lint.sh → ANTIPATTERNS.md (linter references catalog)
- scripts/dispatch/build-context.sh → ANTIPATTERNS.md (payload references catalog)
- templates/task-plan.md → scripts/verify/run-suite.sh (template references wrapper)

## Tasks

### T01: Create anti-pattern-lint.sh linter

See `tasks/T01-PLAN.md`.

### T02: Update agent-facing command and template files to remove Class A patterns

See `tasks/T02-PLAN.md`.

### T03: Add prohibited-patterns section to dispatch payload via build-context.sh

See `tasks/T03-PLAN.md`.

### T04: Create verify scripts for all P03 must-haves

See `tasks/T04-PLAN.md`.

## Task Dependencies

```
T01 → T04
T02 → T04
T03 → T04
```

T01, T02, and T03 can run in parallel. T04 depends on all three (it creates the verify scripts that test their deliverables).

## Files Likely Touched

- scripts/verify/anti-pattern-lint.sh (create)
- commands/consolidate.md (modify)
- commands/plan-phase.md (modify)
- templates/task-plan.md (modify)
- templates/claude-code-appendix.md (modify)
- scripts/dispatch/lib/section-handlers.sh (modify)
- scripts/verify/m016-p03-lint-detects-subst.sh (create)
- scripts/verify/m016-p03-lint-detects-backtick.sh (create)
- scripts/verify/m016-p03-lint-detects-brace.sh (create)
- scripts/verify/m016-p03-lint-self-excludes.sh (create)
- scripts/verify/m016-p03-lint-clean-pass.sh (create)
- scripts/verify/m016-p03-payload-prohibited.sh (create)
- scripts/verify/m016-p03-task-template-clean.sh (create)
- scripts/verify/m016-p03-consolidate-clean.sh (create)
- scripts/verify/m016-p03-appendix-clean.sh (create)
- scripts/verify/m016-p03-lint-bash32.sh (create)
