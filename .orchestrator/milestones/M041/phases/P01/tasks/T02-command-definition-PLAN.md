---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M041"
name: "commands/detective.md — command definition"
depends_on: ["T01"]
---

## Prerequisites

- `scripts/diagnostics/triage-issue.sh` exists (created by T01)
- Existing command docs at `commands/` follow the frontmatter + sections pattern (see `commands/diagnose.md` for structure reference)

## Description

Author the `commands/detective.md` command definition document. This is the agent instruction document that tells the LLM runtime how to execute the `orchestrator:detective` command. It follows the standard command-doc structure used by all other orchestrator commands: YAML frontmatter with a `description:` field, followed by Markdown sections covering usage, prerequisites, output, idempotency, error handling, gotchas, and referenced scripts.

The command definition wires together `triage-issue.sh` (from T01) with the operator-facing UX: argument parsing, TTY detection, the `--yes` flag for non-interactive mode, and the graceful-degradation contract when `gh` is unavailable.

## Steps

1. **Create `commands/detective.md`** with this structure:

   **YAML frontmatter**:
   ```yaml
   ---
   description: "Use when triaging orchestrator-internal issues — captures structured diagnostic context, searches Build-Fractal/orchestrator GitHub Issues for matches, files or comments on issues with a triage report, and suggests fixes for simple problems. Distinct from diagnose (user-project bugs) and doctor (health symptoms)."
   ---
   ```

   **Sections** (follow the pattern from `commands/diagnose.md`, `commands/doctor.md`):

   **`# orchestrator:detective`** — one-paragraph summary distinguishing detective from diagnose and doctor.

   **`## Usage`**:
   ```
   orchestrator:detective --symptom "<description>" [--suggest-fix] [--yes] [--errors-only] [--log-tail <N>] [--repo <owner/name>]
   echo "<symptom>" | orchestrator:detective [--suggest-fix] [--yes]
   ```

   **`## Prerequisites`**:
   - `.orchestrator/` exists (orchestrator state root)
   - `scripts/diagnostics/triage-issue.sh` is installed
   - `gh` CLI (>= 2.0) authenticated against target repo (optional; degrades gracefully)

   **`## Workflow`** — describe the three-step flow:
   1. **Capture**: invoke `triage-issue.sh` to generate the structured triage report
   2. **Search**: invoke `search-issues.sh` to find matching open issues (P02 — not yet implemented; degrade gracefully if missing)
   3. **File/Comment**: invoke `file-issue.sh` to create or comment on an issue (P02 — not yet implemented; degrade gracefully if missing)

   Document that steps 2 and 3 are wired in P02. In P01, detective produces the triage report only and exits. The command definition should document the full workflow but note that GitHub integration scripts are shipped in P02.

   **`## TTY Detection and Non-Interactive Mode`**:
   - When stdin is a pipe: read piped content as symptom (FR-10)
   - When stdin is not a TTY and `--yes` is not passed: degrade to stdout-only mode for GitHub actions (FR-9 TTY-detection rule)
   - When `--yes` is passed: skip confirmation gates, proceed with GitHub actions

   **`## Graceful Degradation (FR-4)`**:
   - `gh` not installed: print triage report to stdout, emit `DETECTIVE: gh unavailable` to stderr, exit 0
   - `gh` not authenticated: same behavior
   - GitHub API error (403/429): same behavior
   - `search-issues.sh` not found (P01-only state): print triage report to stdout, exit 0

   **`## Output`**:
   - Triage report to stdout (always)
   - `DETECTIVE: commented on #<N>` or `DETECTIVE: opened #<N>` to stderr (when GitHub round-trip succeeds)
   - `DETECTIVE: gh unavailable — report printed to stdout` to stderr (degradation)
   - `unit_close` record appended to `.orchestrator/execution-log.jsonl`

   **`## Idempotency`**: Running detective twice with the same symptom produces two separate triage reports (timestamped). It does not deduplicate locally — deduplication is via the GitHub search step.

   **`## Error Handling`**:
   - No `.orchestrator/`: exit 2, point to `orchestrator:init`
   - No symptom provided (non-pipe, no `--symptom`): exit 1, print usage
   - `triage-issue.sh` missing: exit 1, point to installation

   **`## Gotchas`**:
   - Detective is for orchestrator-internal issues only — do not use for user-project bugs (use `orchestrator:diagnose` instead)
   - The `## Suggested Fix` section is always present; `--suggest-fix` controls the heuristic, not section presence
   - Piped invocations consume stdin — confirmation gates require `--yes` in non-interactive mode

   **`## Referenced Scripts`**:
   - `scripts/diagnostics/triage-issue.sh` — triage report engine
   - `scripts/diagnostics/search-issues.sh` — GitHub issue search (P02)
   - `scripts/diagnostics/file-issue.sh` — GitHub issue create/comment (P02)

## Must-Haves

- `commands/detective.md` exists with frontmatter `description:` field
- Document passes `scripts/verify/spec-shape-lint.sh` (well-formed command doc)
- References `scripts/diagnostics/triage-issue.sh` by name

## Verification

```bash
bash tools/verify/m041-p01-command-shape.sh
```

## Notes

Expected output from `m041-p01-command-shape.sh`: `PASS: commands/detective.md passes shape lint and references triage-issue.sh`

## Inputs

### From Previous Tasks

- `scripts/diagnostics/triage-issue.sh` (from T01)
  - Key API: `--symptom <text>`, `--capture-log`, `--errors-only`, `--suggest-fix`, `--log-tail <N>` flags
  - Key types: stdout is a YAML-frontmatter + Markdown-body triage report; exit 0 on success, exit 1 on usage error
  - Piped stdin accepted when `[ ! -t 0 ]` and no `--symptom`

### From Disk (Pre-existing)

- `commands/diagnose.md` — structural reference for command-doc format (frontmatter + sections pattern)
- `commands/doctor.md` — structural reference for diagnostic command conventions
- `scripts/verify/spec-shape-lint.sh` — validates command doc structure

## Constraints

- Must follow the existing command-doc conventions (YAML frontmatter with `description:`, standard section headings)
- Must clearly distinguish detective from diagnose (user-project bugs) and doctor (health symptoms)
- Must document the full workflow including P02 scripts even though they don't exist yet (graceful degradation documented)

## Expected Output

A new file at `commands/detective.md` (~80-120 lines) that:
- Has YAML frontmatter with a `description:` field
- Passes `scripts/verify/spec-shape-lint.sh`
- Documents the full detective workflow (capture → search → file)
- References all three diagnostic scripts
- Documents TTY detection, non-interactive mode, and graceful degradation
