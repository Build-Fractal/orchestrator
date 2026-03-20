---
description: "Use when running mechanical verification for a completed task or phase. Executes 4-tier verification: static checks (file existence, content patterns), command execution (configured tests/lint), behavioral review (spec compliance), and human review (UAT). Produces a structured verification report."
---

# speckit.orchestrator.verify

Run the verification pipeline against the current phase or task to determine if must-haves are satisfied. This command orchestrates 4 verification tiers and produces a structured report.

## Prerequisites

Before running verification:

1. **Derive current state** by running `bash scripts/state/derive-phase.sh <milestone-dir>`.
2. **Confirm verifiable state**: verification is meaningful when state is `executing`, `summarizing`, or `validating`. If state is `pre-planning`, `discussing`, or `planning`, report that there is nothing to verify yet and exit.
3. **Identify the target phase**: use `bash scripts/state/read-roadmap.sh <roadmap-file> active-phase` to find the current active phase, or accept a phase ID as input.
4. **Locate the phase plan**: find `<milestone-dir>/phases/<phase-id>/<phase-id>-PLAN.md`.

## Idempotency

If a verification report already exists at `<milestone-dir>/phases/<phase-id>/<phase-id>-VERIFICATION.md` and no files in the phase directory have been modified since the report was created (compare timestamps), return the cached result. Output: `"Cached verification result from <timestamp>. Re-run with --force to re-verify."` This satisfies R012 (idempotent commands).

## Tier 1 — Static Checks

Run file existence, content patterns, and cross-reference checks:

```bash
bash scripts/verify/check-must-haves.sh <milestone-dir>/phases/<phase-id>
```

This script:
- Parses the `## Must-Haves` section of the phase plan
- Checks **Truths**: runs `Check:` commands (grep patterns) against project files
- Checks **Artifacts**: verifies file existence, minimum line counts, and content patterns
- Checks **Key Links**: verifies cross-file references between source and target files
- Outputs structured `PASS`/`FAIL` lines per check
- Exits 0 if all pass, 1 if any fail

Also run boundary map verification:

```bash
bash scripts/verify/check-boundary-map.sh <milestone-dir>/<milestone-id>-ROADMAP.md <phase-id> --root <project-root>
```

This script:
- Reads the `Produces:` entries from the phase's boundary map in the roadmap
- Checks that each produced file/pattern exists on disk
- Outputs structured `PASS`/`FAIL` lines per produce item

**Collect all Tier 1 results.** If any check fails, record the tier as `fail` but continue to other tiers for a complete report.

## Tier 2 — Command Execution

Run configured verification commands (tests, linters, type checkers):

```bash
bash scripts/verify/run-commands.sh --config <project-root>/orchestrator-config.yml
```

This script:
- Reads `verification_commands` from the orchestrator config
- Runs each command and captures exit code + output
- Outputs `PASS`, `FAIL`, or `SKIP` per command
- If no commands are configured, outputs `SKIP` and continues

**Alternatively**, pass commands directly:

```bash
bash scripts/verify/run-commands.sh "npm test" "npm run lint"
```

## Tier 3 — Behavioral Review

This tier is agent-driven, not script-driven. As the verifying agent:

1. Read the **Truths** section of the phase plan that do NOT have `- Check:` sub-items. These are behavioral truths that require judgment.
2. For each behavioral truth, determine if it is satisfied by:
   - Reading the relevant source files
   - Checking that the described behavior is implemented
   - Running the system if needed to observe behavior
3. Record each behavioral truth as `PASS` or `FAIL` with an observation note.

This implements FR-059 (spec compliance verification at phase boundaries).

## Tier 4 — Human/UAT Review

If the orchestration tier is C and the phase plan contains must-haves marked for human review:

1. List the human review items in the verification report with status `PENDING`.
2. Prompt the developer: *"The following items require human review: [list]. Mark each as pass/fail when ready."*
3. Do not auto-advance past human review gates.

For Tier B orchestration, skip this tier unless explicitly requested.

## Scope Check

Run scope analysis as an informational check (warnings only, does not block):

```bash
bash scripts/verify/check-scope.sh <milestone-dir>/phases/<phase-id>/<phase-id>-PLAN.md --files <modified-files>
```

Where `<modified-files>` is a comma-separated list from `git diff --name-only HEAD`, or omit `--files` to let the script use git directly.

Report any `WARN` lines in the verification report's scope section, but do not count them as failures.

## External Modification Check (FR-064)

As a pre-check before Tier 1 verification, detect files modified outside the orchestrator's scope:

```bash
bash scripts/verify/check-external-mods.sh .specify/orchestrator/orchestrator.lock --scope "<milestone-dir>/phases/<phase-id>"
```

If modifications are detected (exit code 2), include `WARN` lines in the verification report's scope section alongside check-scope.sh output. External modifications are informational warnings — they do not fail verification.

If the lock file is missing or has no `phase_start_tree`, the check is gracefully skipped.

## Output

Write the verification report using the template at `templates/verification-report.md`:

1. Fill in the template placeholders:
   - `{{milestone_id}}`, `{{phase_id}}`, `{{verified_at}}` (ISO timestamp)
   - `{{overall_result}}`: `pass` if all tiers pass, `fail` if any tier fails, `partial` if some pass and others are pending/skipped
   - Per-tier status, check counts, failure counts, and result rows
2. Write to: `<milestone-dir>/phases/<phase-id>/<phase-id>-VERIFICATION.md`
3. Log the verification event to `<milestone-dir>/execution-log.jsonl`

## Reference Files

- `scripts/verify/check-must-haves.sh` — Tier 1 must-have checker
- `scripts/verify/check-boundary-map.sh` — Tier 1 boundary map checker
- `scripts/verify/check-scope.sh` — scope analysis (warnings only)
- `scripts/verify/run-commands.sh` — Tier 2 command executor
- `templates/verification-report.md` — output template
- `references/verification-ladder.md` — 4-tier verification protocol reference

## Error Handling

- If the phase plan is missing, exit with error: *"Phase plan not found for <phase-id>. Run plan-phase first."*
- If the milestone directory doesn't exist, exit with error: *"Milestone directory not found. Run evaluate first."*
- If state derivation shows `complete`, report: *"Phase already verified and complete. No action needed."*
