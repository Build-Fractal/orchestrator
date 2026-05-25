---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M041"
goal: "Deliver the core triage engine (triage-issue.sh) and command definition (detective.md) so operators can generate structured triage reports from orchestrator-internal symptoms"
demo_sentence: "Running `triage-issue.sh --symptom 'test' --capture-log` exits 0 and prints a structured report with all six body sections; `commands/detective.md` passes shape lint."
risk: "high"
depends_on: []
---

## Must-Haves

### Truths

- `triage-issue.sh` exits 0 and produces a report containing all six Markdown body sections (`## Symptom`, `## Environment`, `## Recent Execution Log`, `## Relevant Files`, `## Disk State`, `## Suggested Fix`)
  - Check: `bash tools/verify/m041-p01-triage-report-sections.sh`
- `triage-issue.sh` includes the `## Suggested Fix` section unconditionally (always present regardless of `--suggest-fix` flag) with default text "No simple fix identified — run with --suggest-fix for heuristic analysis."
  - Check: `bash tools/verify/m041-p01-suggest-fix-unconditional.sh`
- When `--suggest-fix` is passed and the symptom references a non-existent file path, the `## Suggested Fix` section is populated with the missing path and expected state
  - Check: `bash tools/verify/m041-p01-suggest-fix-heuristic.sh`
- When stdin is a pipe, `triage-issue.sh` reads piped content as the symptom (FR-10)
  - Check: `bash tools/verify/m041-p01-pipe-input.sh`
- `commands/detective.md` passes `scripts/verify/spec-shape-lint.sh` (well-formed command doc with frontmatter `description:` field)
  - Check: `bash tools/verify/m041-p01-command-shape.sh`
- The triage report YAML frontmatter includes `symptom`, `captured_at`, `orchestrator_version` fields
  - Check: `bash tools/verify/m041-p01-report-frontmatter.sh`

### Artifacts

- `scripts/diagnostics/triage-issue.sh` (min 80 lines, contains "## Symptom")
- `commands/detective.md` (min 40 lines, contains "description:")

### Key Links

- `commands/detective.md` → `scripts/diagnostics/triage-issue.sh` (command references its implementing script)

## Tasks

### T01: triage-issue.sh — core triage report engine

Implement the main diagnostic script that captures structured triage context from orchestrator-internal symptoms.

### T02: commands/detective.md — command definition

Author the command definition document following the standard command-doc structure.

### T03: Verifier scripts + integration smoke test

Author all P01 verifier scripts under `tools/verify/` and run the phase suite to confirm all must-haves pass.

## Task Dependencies

T01 → T02 → T03

## Files Likely Touched

- `scripts/diagnostics/triage-issue.sh` (create)
- `commands/detective.md` (create)
- `tools/verify/m041-p01-triage-report-sections.sh` (create)
- `tools/verify/m041-p01-suggest-fix-unconditional.sh` (create)
- `tools/verify/m041-p01-suggest-fix-heuristic.sh` (create)
- `tools/verify/m041-p01-pipe-input.sh` (create)
- `tools/verify/m041-p01-command-shape.sh` (create)
- `tools/verify/m041-p01-report-frontmatter.sh` (create)
- `tools/verify/m041-p01-phase-suite.sh` (create)
