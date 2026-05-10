---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P06"
milestone: "M005"
name: "check-plans.sh — AD-19 task plan shape lint"
depends_on: []
---

## Prerequisites

P07 delivered AD-19 shape guidance in `commands/plan-phase.md`, `templates/phase-plan.md`, and `templates/task-plan.md`. These templates forbid inline compound bash in `Check:` commands and verification blocks, requiring single-script-file invocations instead. This task creates the diagnostic that lints for violations.

## Description

Create `scripts/diagnostics/check-plans.sh` — an advisory lint that scans task plan `Check:` commands AND inline `` ```bash `` verification blocks for patterns that trip the harness obfuscation heuristic (AD-19). This is the most complex diagnostic check in P06.

**The full AD-19 trigger list to detect:**
1. `bash -c '` with embedded quoted character classes or escape sequences
2. `&&`/`||` chained compound bash invocations beyond a trivial two-token pair
3. Heredocs containing bash expansion (`<<` with `$()` or `${}` or backticks)
4. Plain `(…)` subshells that source a library or contain pipes
5. Command substitution `$(…)` containing pipes
6. Process substitution `<(…)` / `>(…)`
7. `cmd <file` input redirection nested inside `$(…)`
8. Compound `;`-separated statements with more than two commands
9. Inline `for`/`while`/`if` blocks

The script emits `DOCTOR:PLANS status=<ok|warn> heuristic_risk=N trigger=<class>`. It is **advisory only** — reports warnings but does not fail the doctor (run-doctor.sh treats its exit code as non-fatal).

## Steps

### Step 1: Create `scripts/diagnostics/check-plans.sh`

Create the file at `scripts/diagnostics/check-plans.sh`:

```bash
#!/usr/bin/env bash
# scripts/diagnostics/check-plans.sh — AD-19 task plan shape lint.
#
# Scans task plan Check: commands and inline ```bash verification blocks
# for patterns that trip the Claude Code harness obfuscation heuristic.
# Advisory only — reports warnings, does not block.
#
# Per AD-19, the harness safety heuristic sits above the allow list and
# cannot be disabled. Task plan verification must use single-script-file
# invocations to avoid interactive prompts during auto mode.
#
# Usage: check-plans.sh [--root <project-root>] [--target <file>]
#
# Output: DOCTOR:PLANS status=<ok|warn> heuristic_risk=N trigger=<class>
#
# Bash 3.2 compatible.
set -eu
```

**Arguments:**
- `--root <project-root>` — defaults to `PROJECT_ROOT` env var or two levels up from script
- `--target <file>` — check a single file instead of scanning all task plans

**Logic:**

1. **Collect files to scan**: If `--target` is provided, scan that file. Otherwise, find all `*-PLAN.md` files under `.specify/orchestrator/milestones/*/phases/*/tasks/`. Also scan `templates/phase-plan.md` and `templates/task-plan.md` as canary files (if templates are clean, drift is author-only).

2. **Extract checkable lines**: From each file, extract:
   - Lines that start with `  - Check:` (truth check commands)
   - Lines inside `` ```bash `` ... `` ``` `` fenced code blocks within `## Verification` sections

3. **Apply trigger patterns**: For each extracted line, test against the AD-19 trigger set. Use `grep -E` with these patterns:

   | Trigger Class | Pattern (grep -E) | Description |
   |---|---|---|
   | `bash-c` | `bash -c '` | bash -c with inline script |
   | `chain` | `&& bash\|&& \.\|\|\| bash\|\|\| \.` | chained compound invocations (but allow simple `cmd && echo ok`) |
   | `heredoc` | `<<[^']*\$[\({]` | heredoc with bash expansion |
   | `subshell-source` | `\( *\. ` | subshell that sources a library |
   | `subshell-pipe` | `\([^)]*\|[^)]*\)` | subshell containing pipe |
   | `cmdsub-pipe` | `\$\([^)]*\|[^)]*\)` | command substitution with pipe |
   | `procsub` | `<\(\|>\(` | process substitution |
   | `redirect-in-cmdsub` | `\$\([^)]*<[^)]*\)` | input redirect inside $() |
   | `compound-semi` | `;.*;\s*[a-z]` | three+ ;-separated commands |
   | `inline-loop` | `\bfor \|;\s*do\b\|\bwhile \|;\s*then\b\|\bif ` | inline for/while/if |

   Note: The `chain` pattern must exclude trivial `cmd && echo` pairs. Check if the `&&`/`||` connects two `bash` or `. ` invocations or if there are more than two commands.

4. **Count and classify**: Track total trigger hits (`heuristic_risk`) and the trigger class of the most severe hit.

5. **Output**: `DOCTOR:PLANS status=<ok|warn> heuristic_risk=N trigger=<class>`
   - `status=ok` when `heuristic_risk=0`, `trigger=none`
   - `status=warn` when `heuristic_risk>0`, `trigger=<most-common-class>`
   - If `status=warn`, list each flagged line with its file, line number, and trigger class, prefixed with `  WARNING: `

6. **Exit code**: Always exit 0 (advisory — does not fail the doctor). The structured output conveys the risk.

Make executable: `chmod +x scripts/diagnostics/check-plans.sh`

### Step 2: Create verification script

Create `scripts/verify/p06-check-plans.sh`:

```bash
#!/usr/bin/env bash
# Verify check-plans.sh exists, is executable, contains DOCTOR:PLANS,
# and runs without error.
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

script="$PROJECT_ROOT/scripts/diagnostics/check-plans.sh"

# File exists and is executable
[ -f "$script" ] || { echo "FAIL: check-plans.sh not found"; exit 1; }
[ -x "$script" ] || { echo "FAIL: check-plans.sh not executable"; exit 1; }

# Contains structured output marker
grep -q 'DOCTOR:PLANS' "$script" || { echo "FAIL: missing DOCTOR:PLANS output"; exit 1; }

# Has minimum complexity (checks for at least 3 trigger patterns)
trigger_count="$(grep -cE 'bash-c|chain|heredoc|subshell|cmdsub|procsub|redirect|compound|inline' "$script" || true)"
[ "$trigger_count" -ge 3 ] || { echo "FAIL: check-plans.sh has too few trigger patterns ($trigger_count)"; exit 1; }

# Runs without crash (advisory — always exits 0)
output="$(bash "$script" --root "$PROJECT_ROOT" 2>&1)"
exit_code=$?
echo "$output" | grep -q 'DOCTOR:PLANS' || { echo "FAIL: no DOCTOR:PLANS in output"; exit 1; }

echo "PASS: check-plans.sh verified"
```

Make executable.

## Must-Haves

- check-plans.sh scans task plan Check: commands and inline bash blocks for AD-19 trigger patterns and emits `DOCTOR:PLANS status=<ok|warn> heuristic_risk=N trigger=<class>`

### Artifacts

- scripts/diagnostics/check-plans.sh (min 60 lines, contains "DOCTOR:PLANS")

## Verification

```
bash scripts/verify/p06-check-plans.sh
```

Expected: `PASS: check-plans.sh verified`

## Inputs

### From Previous Tasks
None — this is independent of T01 and T02.

### From Disk (Pre-existing)
- `commands/plan-phase.md` (from P07) — contains the AD-19 shape guidance and forbidden-shape enumeration that check-plans.sh enforces
- `templates/phase-plan.md` (from P07) — template with script-file shape examples that should pass the lint
- `templates/task-plan.md` (from P07) — template with AD-19 comments and script-file shape
- `.specify/orchestrator/milestones/M005/phases/*/tasks/*-PLAN.md` — active task plans to scan
- Existing doctor checks — follow the `DOCTOR:*` structured output protocol

## Constraints

- Bash 3.2 compatible
- Follow the `DOCTOR:*` structured output protocol
- **Advisory only** — always exit 0 (unlike other checks that exit 1 on warn). The structured output conveys risk level. run-doctor.sh will display the output but not count it toward the error total.
- Do not source `errors.sh` or `events.sh`
- Pattern matching uses `grep -E` (extended regex) — no PCRE or lookaheads
- Must handle edge cases: empty files, plans with no Check: commands, Check: commands that legitimately use `&&` in a trivial way (e.g., `cd dir && ls`). The `chain` trigger should focus on `bash`/`. ` invocations, not arbitrary `&&` usage.

## Expected Output

One new file:
- `scripts/diagnostics/check-plans.sh` — ~80-120 lines
- `scripts/verify/p06-check-plans.sh` — ~25 lines

Both executable. check-plans.sh emits `DOCTOR:PLANS` structured output and always exits 0.
