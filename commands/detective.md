---
description: "Use when triaging orchestrator-internal issues — captures structured diagnostic context, searches Build-Fractal/orchestrator GitHub Issues for matches, files or comments on issues with a triage report, and suggests fixes for simple problems. Distinct from diagnose (user-project bugs) and doctor (health symptoms)."
---

# orchestrator:detective

Structured triage for issues with the orchestrator itself. Where `orchestrator:diagnose` is a debugging loop for bugs in a user's project and `orchestrator:doctor` checks health symptoms across orchestrator subsystems, detective investigates orchestrator-internal problems and connects them to the GitHub issue tracker. It captures diagnostic context, searches for matching open issues, and files or comments with a structured triage report — closing the feedback loop between operators who hit problems and the maintainers who fix them.

## Usage

```
orchestrator:detective --symptom "<description>" [--suggest-fix] [--yes] [--errors-only] [--log-tail <N>] [--repo <owner/name>]
echo "<symptom>" | orchestrator:detective [--suggest-fix] [--yes]
```

- `--symptom "<description>"` — plain-text description of the problem observed.
- `--suggest-fix` — run heuristic analysis to populate the `## Suggested Fix` section with actionable guidance (the section is always present; the flag controls depth).
- `--yes` — skip confirmation gates; proceed with GitHub actions without prompting.
- `--errors-only` — restrict log capture to error-level entries only.
- `--log-tail <N>` — number of recent execution-log lines to include (default 20).
- `--repo <owner/name>` — target GitHub repository (default `Build-Fractal/orchestrator`; configurable via `detective.repo` in `.orchestrator/config.yml`).

## Prerequisites

- `.orchestrator/` exists (orchestrator state root). Run `orchestrator:init` first if absent.
- `scripts/diagnostics/triage-issue.sh` is installed.
- `gh` CLI (>= 2.0) authenticated against the target repo (optional; degrades gracefully — see Graceful Degradation below).

## Workflow

Three-step flow:

1. **Capture** — invoke `scripts/diagnostics/triage-issue.sh` with the operator's flags to generate the structured triage report (six sections: `## Symptom`, `## Environment`, `## Recent Execution Log`, `## Relevant Files`, `## Disk State`, `## Suggested Fix`).
2. **Search** — invoke `scripts/diagnostics/search-issues.sh` to find matching open issues on the target repo. If the script is missing (ships in P02), skip to step 3 with the full triage report.
3. **File/Comment** — invoke `scripts/diagnostics/file-issue.sh` to create a new issue or comment on an existing match. If the script is missing (ships in P02), print the triage report to stdout and exit 0.

When steps 2-3 scripts are not available, detective operates in **local-only mode**: it generates and prints the triage report, which is still valuable for manual filing.

## TTY Detection and Non-Interactive Mode

- When stdin is a pipe: read piped content as the symptom (FR-10).
- When stdin is not a TTY (`[ ! -t 0 ]`) and `--yes` is not passed: degrade to stdout-only mode for GitHub actions (FR-9 TTY-detection rule). This prevents deadlock when piped input has consumed stdin.
- When `--yes` is passed: skip confirmation gates, proceed with GitHub actions without prompting.

## Graceful Degradation

- `gh` not installed: print triage report to stdout, emit `DETECTIVE: gh unavailable` to stderr, exit 0.
- `gh` not authenticated: same behavior.
- GitHub API error (403/429): emit `DETECTIVE: GitHub action failed -- report follows for manual filing` to stderr, print report, exit 0.
- `search-issues.sh` not found (P01 state): skip search, print triage report to stdout, exit 0.
- `file-issue.sh` not found (P01 state): skip filing, print triage report to stdout, exit 0.

## Output

- Triage report to stdout (always).
- Status messages to stderr: `DETECTIVE: commented on #<N>`, `DETECTIVE: opened #<N>`, `DETECTIVE: gh unavailable`, etc.
- `unit_close` record appended to `.orchestrator/execution-log.jsonl`.

## Idempotency

Running detective twice with the same symptom produces two separate timestamped triage reports. No local deduplication — deduplication is via the GitHub search step (step 2), which finds existing issues before filing duplicates.

## Error Handling

- No `.orchestrator/`: exit 2, print `ERROR: .orchestrator/ not found — run orchestrator:init first`.
- No symptom provided (non-pipe, no `--symptom`): exit 1, print usage.
- `triage-issue.sh` missing: exit 1, print `ERROR: scripts/diagnostics/triage-issue.sh not found — check installation`.

## Gotchas

- Detective is for orchestrator-internal issues only. For user-project bugs, use `orchestrator:diagnose`.
- The `## Suggested Fix` section is always present in the report; `--suggest-fix` controls the heuristic depth, not section presence. Without the flag, the section reads "No simple fix identified -- run with --suggest-fix for heuristic analysis."
- Piped invocations consume stdin — confirmation gates require `--yes` in non-interactive contexts.
- The `--repo` flag defaults to `Build-Fractal/orchestrator` (configurable via `detective.repo` in `.orchestrator/config.yml`).

## Referenced Scripts

- `scripts/diagnostics/triage-issue.sh` — triage report engine (P01).
- `scripts/diagnostics/search-issues.sh` — GitHub issue search (P02).
- `scripts/diagnostics/file-issue.sh` — GitHub issue create/comment (P02).
