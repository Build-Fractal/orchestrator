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
2. **Search** — invoke `scripts/diagnostics/search-issues.sh` to find matching open issues on the target repo. Each result carries a `match_score` (keyword-overlap count) and a `meets_threshold` boolean. If the script is missing (ships in P02), skip to step 3 with the full triage report.
3. **File/Comment** — decide using `meets_threshold` on the top-scored result: if the top hit has `meets_threshold: true`, **comment** on that existing issue (`file-issue.sh --comment-on <N>`); otherwise **create** a new issue. If `search-issues.sh` is unavailable, default to create. If `file-issue.sh` is missing (ships in P02), print the triage report to stdout and exit 0.

When steps 2-3 scripts are not available, detective operates in **local-only mode**: it generates and prints the triage report, which is still valuable for manual filing.

### Match threshold (#Q-1)

`meets_threshold` is `match_score >= detective.match_threshold` (default **3**, configurable in `.orchestrator/config.yml`; override per-run with `search-issues.sh --threshold N`). The default is **provisional and unvalidated** — orchestrator-domain vocabulary ("phase", "milestone", "dispatch", "verify") overlaps across unrelated issues, so a low threshold risks false-positive "matches" that comment on the wrong issue. Before relying on `--yes` in automated/unattended runs, calibrate against the real issue corpus:

```bash
bash scripts/diagnostics/detective-validate-threshold.sh
```

It reports the empirical false-positive rate and a verdict (`PASS` < 20% / `WARN` 20-40% / `ESCALATE` > 40%), or `insufficient corpus` when the tracker is too small to validate. Until it reports `PASS`, keep `--yes` for interactive use only.

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
- `unit_close` record appended to `.orchestrator/execution-log.jsonl` (see Observability).

## Observability

After a detective run completes (any terminal outcome — filed, commented, degraded, or declined), append a single `unit_close` record to `.orchestrator/execution-log.jsonl` so the run is visible to `orchestrator:cost` and `orchestrator:doctor` anomaly rollups (SC-7). Emit it with a single append — do NOT use `$(date ...)` substitution inside a compound command (AP-008 shape guard); compute the timestamp first if needed:

```bash
printf '{"type":"unit_close","command":"orchestrator:detective","outcome":"<filed|commented|degraded|declined>","issue_number":"<N or empty>","repo":"<owner/name>","gh_available":<true|false>,"timestamp":"%s","source":"runtime"}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> .orchestrator/execution-log.jsonl
```

The `outcome` field records which terminal path the run took: `filed` (new issue opened), `commented` (added to an existing issue), `degraded` (gh unavailable / API error → stdout-only), or `declined` (operator answered no at the confirmation gate, or non-interactive without `--yes`). This is best-effort — a failed append warns on stderr but never changes the run's exit code.

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
- Repo resolution is `--repo` flag > `detective.repo` config key > `Build-Fractal/orchestrator` default. Both `search-issues.sh` and `file-issue.sh` honor the config key; forks set `detective.repo` once in `.orchestrator/config.yml`.

## Referenced Scripts

- `scripts/diagnostics/triage-issue.sh` — triage report engine (P01).
- `scripts/diagnostics/search-issues.sh` — GitHub issue search + match scoring (P02; `--threshold` / `meets_threshold` added P06).
- `scripts/diagnostics/file-issue.sh` — GitHub issue create/comment (P02).
- `scripts/diagnostics/detective-validate-threshold.sh` — #Q-1 corpus validation for the match threshold (P06).
- `scripts/diagnostics/detective-recommend.sh` — cross-command recommendation helper (P03).
