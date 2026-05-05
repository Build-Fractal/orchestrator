---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M033"
name: "commands/constitution.md + scripts/lifecycle/constitution-author.sh (FR-3)"
depends_on: ["T01"]
---

## Prerequisites

- T01 closed: `templates/constitution-starters/{web-saas,cli-tool,library}.md` exist; `scripts/verify/constitution-shape-lint.sh` exists; `scripts/verify/standalone-gate.sh` exists; `references/constitution-starter-format.md` exists. Verified by `[ -f templates/constitution-starters/web-saas.md ]`, `[ -f scripts/verify/constitution-shape-lint.sh ]`, `[ -f scripts/verify/standalone-gate.sh ]`, `[ -f references/constitution-starter-format.md ]`.
- M033/P02 closed: `scripts/lifecycle/grilling-shell.sh` exposes `ask_one <question> <recommendation> [<context-file>]`; `scripts/util/jsonl-event-emitter.sh emit <event_type> <payload_json>` accepts `constitution_authored` event; `scripts/util/start-state-markers.sh write <sub-flow-name> <project-dir>` accepts `constitution-authored` (matched against the closed sub-flow-names enum); `scripts/util/dual-write-runtime-md.sh append <fragment>` writes to `# >>> orchestrator:recent-changes >>>` regions in CLAUDE.md / AGENTS.md per FR-21.
- `commands/constitution.md` does NOT yet exist — verified by `[ ! -f commands/constitution.md ]`.
- `scripts/lifecycle/constitution-author.sh` does NOT yet exist — verified by `[ ! -f scripts/lifecycle/constitution-author.sh ]`.
- Spec context: FR-3 contract — accept `--stack <stack>` (validated against `web-saas|cli-tool|library`), `--project-dir <path>`, `--force`, `--yes`; load starter; run 5–8 question grilling-shell flow; substitute `{{...}}` placeholders; hand to `$EDITOR`; verify via `constitution-shape-lint.sh`; write to `<project-dir>/.orchestrator/memory/constitution.md`. CON-3 — zero `speckit.*` references in the M033 surface (Principle XVI compliance).

## Description

T02 ships the FR-3 constitution-author command (the orchestrator-native authoring path that replaces `speckit.constitution`). The command-doc lives at `commands/constitution.md` (canonical MEM012 shape); the driver lives at `scripts/lifecycle/constitution-author.sh`. The driver: (a) accepts the FR-3 flag set; (b) loads the stack-specific starter from T01; (c) runs a 5–8 question grilling-shell flow consuming P02's `ask_one` API (sequential never batched per CON-5; recommendation-not-interrogation); (d) substitutes `{{...}}` placeholders into the starter; (e) hands the draft to `$EDITOR` for operator review; (f) verifies via T01's FR-5 lint; (g) writes to `.orchestrator/memory/constitution.md`; (h) writes the FR-20 partial-state marker; (i) emits the FR-22 JSONL event; (j) appends the FR-21 dual-write Recent Changes fragment.

The driver is the **first content-authoring command to use P02's grilling-shell** — it is the dogfood for CON-5 (sequential never batched) + the recommendation-not-interrogation framing + the MIT-007 partial-answers.yml live-contradiction wiring. The driver passes a `<context-file>` accumulator path on every `ask_one` invocation, NOT only on resume — this is FR-10's amendment (MIT-007) applied to FR-3.

**Bash 3.2 compatibility (MEM001):** No `declare -A`, no process substitution, no `$(...)` containing pipes. The driver uses parallel indexed arrays for placeholder vocabulary mapping.

**Idempotency:** Re-runs without `--force` preserve the existing constitution byte-identical with stdout `no changes` diagnostic and exit 0. `--force` regenerates with stderr warning naming discarded edits.

**Standalone posture (CON-3):** Zero `speckit.*` references in `commands/constitution.md`, `scripts/lifecycle/constitution-author.sh`. T01's `scripts/verify/standalone-gate.sh constitution` is the mechanical compliance test; T02's surfaces are added to the closed surface file set (already present in T01's SSOT block).

## Steps

1. **Author `commands/constitution.md`** (≥60 lines) per MEM012 canonical command-doc shape:

   ```yaml
   ---
   description: "Use when authoring the project's constitution from a stack-aware starter via interactive grilling-protocol flow. Lands at .orchestrator/memory/constitution.md."
   ---
   ```

   Body sections (in order):
   - `# orchestrator:constitution` title.
   - `## Prerequisites / State Check` — `init-project.sh` has run; `.orchestrator/memory/` directory exists or will be created.
   - `## Core Workflow` — numbered sections naming: stack selection (closed v1 enum); starter load; grilling-protocol flow (5–8 questions consuming `ask_one`); placeholder substitution; editor hand-off; lint gate (FR-5); write-and-mark; event emission; dual-write fragment append.
   - `## Output` — `.orchestrator/memory/constitution.md` written; `.orchestrator/start-state/constitution-authored.complete` marker; one `constitution_authored` JSONL record in `.orchestrator/execution-log.jsonl`; one one-line fragment appended to the `# >>> orchestrator:recent-changes >>>` region in CLAUDE.md / AGENTS.md.
   - `## Idempotency` — re-runs without `--force` preserve existing constitution; `--force` regenerates with stderr warning.
   - `## Error Handling` — unknown `--stack` exits non-zero with v1 list + `#Q-2`; lint failure halts write with named missing/malformed item to stderr per US-2 AS-5.
   - `## Standalone Posture (CON-3 / Principle XVI)` — zero `speckit.*` dependencies; mechanical compliance test is `bash scripts/verify/standalone-gate.sh constitution`.
   - `## Referenced Scripts` — `scripts/lifecycle/constitution-author.sh`, `scripts/verify/constitution-shape-lint.sh`, `scripts/verify/standalone-gate.sh`, `templates/constitution-starters/{web-saas,cli-tool,library}.md`, `references/constitution-starter-format.md`.

   Load-bearing tokens (verifier greps these): `orchestrator:constitution`, `FR-3`, `constitution-author.sh`, `web-saas`, `cli-tool`, `library`, `standalone-gate.sh`, `Idempotent Deploys`, `Composable Default Exit Codes`, `Stable API Surface`.

2. **Author `scripts/lifecycle/constitution-author.sh`** (≥200 lines, executable, `chmod +x`, bash 3.2 compatible).

   2a. **Header.** Hashbang `#!/usr/bin/env bash`, `set -e -u -o pipefail`, comment block naming the script (FR-3), the spec reference (M033 / 036-project-onboarding-experience), the v1 stack list, the load-bearing tokens, and the bash 3.2 compatibility note.

   2b. **Argument parsing.** Accept `--stack <stack>`, `--project-dir <path>`, `--force`, `--yes`. Validate `--stack` against the closed enum `web-saas|cli-tool|library` via `case`; unknown stack exits non-zero with the v1 list and `#Q-2` echoed to stderr per US-2 AS-4.

   2c. **Pre-flight checks.** Verify `templates/constitution-starters/<stack>.md` exists. Verify `<project-dir>/.orchestrator/` exists; create if absent. Resolve final write path `<project-dir>/.orchestrator/memory/constitution.md`. If the file exists and `--force` is NOT set, echo `no changes` to stdout, emit a `constitution_authored` JSONL event with `payload: {"action":"no-changes"}`, and exit 0 (idempotent path per US-2 AS-2).

   2d. **Source grilling-shell.** `. "$REPO_ROOT/scripts/lifecycle/grilling-shell.sh"` (with `REPO_ROOT` resolved via `BASH_SOURCE` discipline matching P02's pattern). Set up the partial-answers accumulator `<project-dir>/.orchestrator/intake/<timestamp>/partial-answers.yml` with `mkdir -p`.

   2e. **5–8 question grilling-protocol flow.** For each placeholder in the closed vocabulary (`{{project_type}}`, `{{primary_constraint}}`, `{{target_user}}` plus 2–5 stack-specific follow-ups documented in each starter's frontmatter `# placeholders:` block — T02 reads the placeholder list from the starter via grep/awk, not hard-coded), invoke `ask_one <question-text> <recommendation> <accumulator-path>`. The recommendation is derived from the detected manifest type (`package.json` with web framework → recommend `web-saas`; etc.) per FR-1's `--stack` recommendation convention. Set `_GRILLING_CURRENT_QKEY` and `_GRILLING_CURRENT_DEFINITION` per P02's caller-set-bash-vars convention before each `ask_one` call. Append the resolved answer to the accumulator file as `<placeholder-key>: <resolved-answer>` after each `ask_one` returns success (P02's MIT-007 contradiction-detection wiring fires automatically against the accumulator on every subsequent call).

   2f. **Placeholder substitution.** Read the starter file into a temp file under `mktemp -d`. For each resolved `{{placeholder}}` → `<answer>` mapping, run `sed -i.bak "s|{{<placeholder-key>}}|<answer>|g"` against the temp file (POSIX `sed -i` portability via the `.bak` form; clean up the `.bak` afterward). Bash 3.2 compatible — no associative arrays; use parallel indexed arrays `placeholders[i]` and `answers[i]`.

   2g. **Editor hand-off.** Set `EDITOR="${EDITOR:-vi}"`. Invoke `"$EDITOR" "<temp-file>"` (operator reviews the substituted draft). Skip the editor pass if `--yes` is set (matches the EDITOR=cat test convention).

   2h. **Lint gate.** Invoke `bash scripts/verify/constitution-shape-lint.sh "<temp-file>"`. On non-zero exit, propagate the lint stderr, echo `FAIL: lint rejected — re-invoke and re-edit; no partial write` to stderr, and exit non-zero per US-2 AS-5. Do NOT write the partial file.

   2i. **Write.** On lint pass, `cp "<temp-file>" "<project-dir>/.orchestrator/memory/constitution.md"`. Clean up the temp dir.

   2j. **Marker write.** `bash scripts/util/start-state-markers.sh write constitution-authored "<project-dir>"` per FR-20.

   2k. **JSONL event emit.** `PROJECT_DIR="<project-dir>" bash scripts/util/jsonl-event-emitter.sh emit constitution_authored '{"stack":"<stack>","force":<true-or-false>}'` per FR-22.

   2l. **FR-21 dual-write Recent Changes fragment.** Per the `references/m033-fr21-dual-write-convention.md` SSOT (P02/T05 deliverable), append a one-line fragment naming the milestone, command, and stack: `bash scripts/util/dual-write-runtime-md.sh append "036-project-onboarding-experience: orchestrator:constitution authored constitution for stack=<stack>"`. Respect the `dual_write_agents: false` config flag (the helper handles the config lookup; T02 just calls the helper).

   2m. **--force path.** If `--force` is set AND a prior constitution exists, echo `WARN: --force discards prior operator edits` to stderr before the lint+write step per US-2 AS-3. The substitution + lint + write steps proceed normally; the prior file is overwritten.

   2n. **Cleanup.** Remove the temp dir (`rm -rf "<temp-dir>"`).

3. **Author `tools/verify/m033-p03-constitution-md-shape.sh`** (≥30 lines, executable). Asserts:
   - `commands/constitution.md` exists.
   - The file body contains the load-bearing tokens via `grep -F`: `orchestrator:constitution`, `FR-3`, `constitution-author.sh`, `web-saas`, `cli-tool`, `library`, `standalone-gate.sh`, `Idempotent Deploys`, `Composable Default Exit Codes`, `Stable API Surface`.
   - The doc has a YAML frontmatter `description:` field per MEM012.
   - Emits `PASS:` / `SUMMARY:` lines.

4. **Author `tools/verify/m033-p03-constitution-author-sh-shape.sh`** (≥30 lines, executable). Asserts:
   - `scripts/lifecycle/constitution-author.sh` exists and is executable.
   - The file body contains the load-bearing tokens via `grep -F`: `--stack`, `--project-dir`, `--force`, `--yes`, `web-saas`, `cli-tool`, `library`, `templates/constitution-starters`, `grilling-shell.sh`, `ask_one`, `constitution-shape-lint.sh`, `EDITOR`, `.orchestrator/memory/constitution.md`, `start-state-markers.sh`, `constitution-authored`, `jsonl-event-emitter.sh`, `constitution_authored`, `dual-write-runtime-md.sh`, `036-project-onboarding-experience`.
   - **Standalone-gate dogfood:** invoke `bash scripts/verify/standalone-gate.sh constitution`; assert exit 0 (T02's surfaces now exist; no `speckit.*` matches).
   - **Negative grep:** assert zero literal `speckit` substring matches in `commands/constitution.md` AND `scripts/lifecycle/constitution-author.sh` (case-insensitive, via `grep -ic 'speckit'` returning `0` for each).
   - Emits `PASS:` / `SUMMARY:` lines.

## Must-Haves

This task addresses these P03 phase truths:
- `commands/constitution.md` exists per MEM012.
- `scripts/lifecycle/constitution-author.sh` exists and implements FR-3.

This task creates these P03 phase artifacts:
- Command doc: `commands/constitution.md` (FR-3 documented surface).
- Driver: `scripts/lifecycle/constitution-author.sh` (FR-3 implementation).
- Verifiers: `tools/verify/m033-p03-constitution-md-shape.sh`, `tools/verify/m033-p03-constitution-author-sh-shape.sh`.

## Verification

```bash
bash tools/verify/m033-p03-constitution-md-shape.sh
bash tools/verify/m033-p03-constitution-author-sh-shape.sh
bash scripts/verify/standalone-gate.sh constitution
```

## Inputs

### From Previous Tasks

- T01 — `templates/constitution-starters/{web-saas,cli-tool,library}.md` (the starter templates loaded in step 2c); `scripts/verify/constitution-shape-lint.sh` (the FR-5 lint invoked in step 2h); `scripts/verify/standalone-gate.sh` (the FR-6 gate invoked in step 4 verifier — surface includes T02's deliverables as of land time).

### From P02 (Pre-existing)

- `scripts/lifecycle/grilling-shell.sh` — sourced; exposes `ask_one <question> <recommendation> [<context-file>]` per FR-17. Caller sets `_GRILLING_CURRENT_QKEY` and `_GRILLING_CURRENT_DEFINITION` before each call; returns the resolved answer via `answer:` line on stdout (caller captures via `read` after invocation).
- `scripts/util/jsonl-event-emitter.sh` — invoked as `bash scripts/util/jsonl-event-emitter.sh emit <event_type> <payload_json>`. `constitution_authored` is in the closed enum.
- `scripts/util/start-state-markers.sh` — invoked as `bash scripts/util/start-state-markers.sh write constitution-authored <project-dir>`. `constitution-authored` is in the closed sub-flow-names enum.
- `scripts/util/dual-write-runtime-md.sh` — invoked as `bash scripts/util/dual-write-runtime-md.sh append <fragment>` per the `references/m033-fr21-dual-write-convention.md` SSOT.

### From Disk (Pre-existing)

- `.orchestrator/memory/constitution.md` — the orchestrator's own v1 constitution; T02 does NOT modify it. T02 writes to `<project-dir>/.orchestrator/memory/constitution.md` for downstream projects (project-local, not orchestrator-local).

## Constraints

- Bash 3.2 compatibility (MEM001) — no `declare -A`, no process substitution, no `$(...)` containing pipes.
- Standalone posture (CON-3 / FR-6) — zero `speckit.*` references in any file authored by T02.
- Idempotent without `--force` (US-2 AS-2) — re-runs preserve existing constitution byte-identical.
- `--force` overwrites with stderr warning (US-2 AS-3).
- Unknown `--stack` exits non-zero with v1 list + `#Q-2` (US-2 AS-4).
- Lint failure halts write with named missing/malformed item to stderr (US-2 AS-5) — no partial file on disk.
- The driver consumes P02's `ask_one` API verbatim — no re-implementation; calls `ask_one` sequentially per CON-5 (never in a batched loop).
- The accumulator file (`<project-dir>/.orchestrator/intake/<timestamp>/partial-answers.yml`) is passed as the `[<context-file>]` argument on EVERY `ask_one` invocation per FR-10's MIT-007 amendment (live-contradiction-detection during normal sessions, not only on resume).
- Verifiers use single-script-file shape per AD-19 — no `( … )` subshells, no `$(...)` with pipes, no compound chains.
- T02 MUST NOT modify any P01 or P02 surface (`scripts/lifecycle/start.sh`, `scripts/lifecycle/grilling-shell.sh`, `scripts/util/jsonl-event-emitter.sh`, `scripts/util/start-state-markers.sh`).
- T02 MUST NOT modify the orchestrator's own `.orchestrator/memory/constitution.md` (the driver writes to project-local paths only).

## Expected Output

After T02 completes:
- `commands/constitution.md` exists per MEM012.
- `scripts/lifecycle/constitution-author.sh` exists, is executable, and implements FR-3.
- `bash scripts/verify/standalone-gate.sh constitution` exits 0 against the M033 working tree (no `speckit.*` matches across the surface).
- Both T02 verifiers exit 0 with `SUMMARY:` lines.
- A summary file at `.orchestrator/milestones/M033/phases/P03/tasks/T02-constitution-author-SUMMARY.md` documents the deliverables.

## Notes

The 5–8 question count is a range, not a fixed number — the v1 closed placeholder vocabulary is 3 (`{{project_type}}`, `{{primary_constraint}}`, `{{target_user}}`); each starter's frontmatter declares its own 2–5 stack-specific follow-ups (e.g., web-saas may ask `{{deployment_target}}`, `{{auth_model}}`; cli-tool may ask `{{primary_subcommand_pattern}}`). The total is 5–8 per FR-3.

The accumulator path `<project-dir>/.orchestrator/intake/<timestamp>/partial-answers.yml` matches the P02-introduced convention (FR-10's MIT-007 amendment named this exact path). The `<timestamp>` is `date -u +%Y%m%dT%H%M%SZ` — second-granularity is sufficient (operators don't run constitution-author multiple times per second).

The `--force` warning ("discards prior operator edits") is informational; the actual byte-identical preservation under no-`--force` is the enforcement (US-2 AS-2). Operators who hit `--force` accidentally are warned but not blocked.

The driver does NOT emit a `start_init_invoked` event — that's `start.sh` territory (FR-1). The driver emits exactly one `constitution_authored` event per successful run.

The dual-write fragment is intentionally short (one line): the FR-21 contract shaped it as a `# >>> orchestrator:recent-changes >>>` region append, and operators consume the region as a chronological log. Future runs accumulate; the helper does not deduplicate. This is the deliberate M014 dual-write shape.
