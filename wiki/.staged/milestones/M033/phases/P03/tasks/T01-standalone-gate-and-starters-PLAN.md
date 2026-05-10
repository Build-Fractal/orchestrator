---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M033"
name: "Standalone gate + constitution-shape-lint + 3 stack starters + format reference (FR-4 / FR-5 / FR-6)"
depends_on: []
---

## Prerequisites

- `scripts/verify/` exists — verified by `[ -d scripts/verify ]`.
- `templates/` exists — verified by `[ -d templates ]`.
- `references/` exists — verified by `[ -d references ]`.
- `tools/verify/` exists.
- `scripts/verify/constitution-shape-lint.sh` does NOT yet exist — verified by `[ ! -f scripts/verify/constitution-shape-lint.sh ]`.
- `scripts/verify/standalone-gate.sh` does NOT yet exist — verified by `[ ! -f scripts/verify/standalone-gate.sh ]`.
- `templates/constitution-starters/` does NOT yet exist — verified by `[ ! -d templates/constitution-starters ]`.
- `references/constitution-starter-format.md` does NOT yet exist — verified by `[ ! -f references/constitution-starter-format.md ]`.
- M033/P01 closed: `scripts/lifecycle/start.sh` exists. M033/P02 closed: `scripts/lifecycle/grilling-shell.sh` exists, `scripts/util/jsonl-event-emitter.sh` exists, `scripts/util/start-state-markers.sh` exists, `scripts/util/dual-write-runtime-md.sh` exists.
- Spec context: FR-4 names three stacks (`web-saas`, `cli-tool`, `library`) with stack-specific principles. FR-5 lint asserts `## Constitution Check` + `### Principle <Roman>` headers + non-empty bodies + zero `{{` placeholders. FR-6 standalone gate scans the closed M033 constitution-authoring surface (file set documented inline) for any `speckit` substring (case-insensitive); zero matches required. CON-3 — Principle XVI's first content-authoring compliance test.

## Description

T01 lands the verifier surfaces and templates that T02 (`constitution-author.sh`) consumes at runtime: the FR-5 `scripts/verify/constitution-shape-lint.sh` lint, the FR-6 `scripts/verify/standalone-gate.sh constitution` handler (Principle XVI's first content-authoring compliance test), the three FR-4 stack starter templates (`web-saas.md`, `cli-tool.md`, `library.md`), and the FR-4 / US-2 AS-4 starter-format reference at `references/constitution-starter-format.md`.

The standalone gate is the load-bearing CON-3 enforcement — zero `speckit.*` references in the M033-shipped constitution-authoring surface. The closed surface file set is documented inline in the gate script under a fenced `# >>> constitution-surface-files >>>` block (SSOT — extending the surface requires editing this block). Subcommand-dispatched (`constitution` is v1; future `ingest-codebase` etc. extends without contract drift).

Each stack starter ships YAML frontmatter (`schema_version: "1.0"` + `type: constitution-starter` + `stack: <name>`) per MEM013 template-convention precedent, a `## Constitution Check` section header (load-bearing for `commands/specify.md:86,99,115` cross-references), 6–8 baseline principles named with Roman-numeral `### Principle <I..VIII>` sub-headers, and 2–3 stack-specific principles named in FR-4. Placeholder vocabulary (`{{project_type}}`, `{{primary_constraint}}`, `{{target_user}}`) is consumed by T02's `constitution-author.sh`.

**Bash 3.2 compatibility (MEM001):** No `declare -A`, no process substitution, no `$(...)` containing pipes. Verifiers emit `PASS:` / `FAIL:` / `SUMMARY:` lines per MEM001.

## Steps

1. **Author `scripts/verify/constitution-shape-lint.sh`** (≥50 lines, executable, `chmod +x`, bash 3.2 compatible). Given a `<path>` argument naming a constitution file, the script asserts:
   - `## Constitution Check` section header is present (`grep -q '^## Constitution Check' <path>`).
   - At least 6 `### Principle <Roman>` sub-headers are present (`grep -cE '^### Principle [IVX]+' <path>`; assert count ≥ 6).
   - Every principle sub-header has at least one non-empty body line before the next `### Principle` or end-of-file. Implement via a loop reading the file with `while IFS= read -r line` and a state machine; on any empty principle, exit non-zero with the principle name echoed.
   - Zero literal `{{` placeholder strings remain. `grep -nF '{{' <path>` MUST produce no matches; on any match, echo the line numbers to stderr and exit non-zero.
   - Emit `PASS: <path> shape lint passed` on success; `SUMMARY: constitution-shape-lint.sh path=<path> pass=N fail=M` final line.

2. **Author `scripts/verify/standalone-gate.sh`** (≥60 lines, executable, `chmod +x`, bash 3.2 compatible). The script:
   - Accepts a single subcommand argument (`constitution` is the v1 dispatch).
   - Contains a fenced `# >>> constitution-surface-files >>>` ... `# <<< constitution-surface-files <<<` SSOT block enumerating the closed surface file set (one path per line):

     ```
     commands/constitution.md
     scripts/lifecycle/constitution-author.sh
     templates/constitution-starters/web-saas.md
     templates/constitution-starters/cli-tool.md
     templates/constitution-starters/library.md
     references/constitution-starter-format.md
     scripts/verify/constitution-shape-lint.sh
     ```

   - Reads the SSOT block via `awk '/>>> constitution-surface-files >>>/,/<<< constitution-surface-files <<</'` (no process substitution; bash 3.2 compatible).
   - For each surface file that exists on disk (skip-with-diagnostic if absent — co-authored-but-not-yet-landed surfaces are tolerated under SKIP semantics matching M033/P01's verifier discipline), runs `grep -nFi 'speckit' <path>` and collects matches. Tolerates absence: a file that does not yet exist (e.g., `commands/constitution.md` before T02 lands) emits `SKIP: <path>` and is not counted as fail.
   - On any match, echoes `FAIL: speckit reference at <path>:<lineno>` to stderr and exits non-zero.
   - On no matches, echoes `PASS: zero speckit references in M033-shipped constitution surface` and `SUMMARY: standalone-gate.sh subcommand=constitution pass=N skip=M fail=0` and exits 0.
   - Unknown subcommand exits 2 with `usage: standalone-gate.sh constitution`.

3. **Author `templates/constitution-starters/web-saas.md`** (≥50 lines). Frontmatter:

   ```yaml
   ---
   schema_version: "1.0"
   type: constitution-starter
   stack: web-saas
   ---
   ```

   Body:
   - `# Constitution — {{project_type}}` title.
   - `## Constitution Check` section header.
   - 6 baseline `### Principle <I..VI>` sub-headers (e.g., I. Context Minimization; II. Evidence Before Claims; III. Design Before Code; IV. Plans Assume Zero Context; V. State On Disk Is Truth; VI. Knowledge Compounds — copy from `.orchestrator/memory/constitution.md` baseline).
   - 2 web-saas-specific `### Principle VII..VIII` sub-headers: `Idempotent Deploys`, `User Data Privacy` — each with non-empty body referencing `{{primary_constraint}}` and `{{target_user}}`.
   - Each principle body is 2–4 lines of prose seeded with the placeholder vocabulary `{{project_type}}`, `{{primary_constraint}}`, `{{target_user}}` so T02's substitution step exercises them.

4. **Author `templates/constitution-starters/cli-tool.md`** (≥50 lines). Same frontmatter shape (`stack: cli-tool`) and 6 baseline principles, plus 2 cli-tool-specific: `Composable Default Exit Codes`, `POSIX Convention Adherence`. Same placeholder vocabulary.

5. **Author `templates/constitution-starters/library.md`** (≥50 lines). Same frontmatter shape (`stack: library`) and 6 baseline principles, plus 2 library-specific: `Stable API Surface`, `Semantic Versioning Discipline`. Same placeholder vocabulary.

6. **Author `references/constitution-starter-format.md`** (≥60 lines). Documents:
   - The starter file format: YAML frontmatter (`schema_version`, `type: constitution-starter`, `stack: <name>`) + `## Constitution Check` section + Roman-numeral `### Principle` sub-headers + placeholder vocabulary.
   - The closed v1 stack list: `web-saas`, `cli-tool`, `library`.
   - The demand-driven expansion criterion per `#Q-2`: "≥2 distinct external requests for a stack post-launch trigger expansion of that stack; no speculative pre-build."
   - The minimum baseline-principle count (6) and the 2–3-stack-specific principle convention.
   - The placeholder vocabulary (`{{project_type}}`, `{{primary_constraint}}`, `{{target_user}}`) and the rule that all `{{...}}` placeholders MUST be resolved before write (FR-5 lint enforcement).
   - A note for community-contributed-additions: a future M033.5 may extend the v1 stack list per `#Q-2`; until then, custom stacks ride a fork of one of the v1 starters with a follow-up D-row.

7. **Author `tools/verify/m033-p03-constitution-shape-lint-shape.sh`** (≥30 lines, executable). Asserts:
   - `scripts/verify/constitution-shape-lint.sh` exists and is executable.
   - The script body contains the load-bearing tokens via `grep -F`: `Constitution Check`, `Principle`, `{{`, `PASS:`, `FAIL:`, `SUMMARY:`.
   - **Functional smoke test:** create a `mktemp -d` staging dir; write a constitution-shaped fixture with 6 `### Principle <I..VI>` sub-headers + a non-empty body each + a `## Constitution Check` section header + zero `{{` placeholders; invoke `bash scripts/verify/constitution-shape-lint.sh <fixture>` and assert exit 0 + `PASS:` line. Cleanup mandatory.
   - **Negative smoke test:** write a fixture with one literal `{{unresolved}}` placeholder; invoke the lint and assert exit non-zero + the line number echoed to stderr. Cleanup mandatory.
   - Emits `PASS:` / `SUMMARY:` lines.

8. **Author `tools/verify/m033-p03-standalone-gate-sh-shape.sh`** (≥30 lines, executable). Asserts:
   - `scripts/verify/standalone-gate.sh` exists and is executable.
   - The script body contains the load-bearing tokens via `grep -F`: `constitution`, `speckit`, `constitution-surface-files`, `PASS:`, `FAIL:`, `SUMMARY:`.
   - The fenced SSOT block markers `# >>> constitution-surface-files >>>` and `# <<< constitution-surface-files <<<` appear.
   - The closed surface file set is enumerated inside the SSOT block (one of: `commands/constitution.md`, `templates/constitution-starters/web-saas.md`, `references/constitution-starter-format.md`, `scripts/verify/constitution-shape-lint.sh`).
   - **Functional smoke test:** invoke `bash scripts/verify/standalone-gate.sh constitution` against the M033 working tree; assert exit 0 (no `speckit` references in the M033 surface — at T01 land time, surfaces co-authored-but-not-yet-landed are tolerated via SKIP); assert `PASS:` or `SKIP:` lines appear and `FAIL:` does NOT appear. Note: `scripts/verify/standalone-gate.sh` itself is NOT in its own surface file list (the gate scans authored surfaces, not its own implementation).
   - Emits `PASS:` / `SUMMARY:` lines.

9. **Author `tools/verify/m033-p03-constitution-starter-templates-shape.sh`** (≥30 lines, executable). For each of `templates/constitution-starters/{web-saas,cli-tool,library}.md`, asserts:
   - File exists and is non-empty.
   - Frontmatter contains `schema_version: "1.0"`, `type: constitution-starter`, and the matching `stack: <name>`.
   - Body contains `## Constitution Check`, ≥6 `### Principle <Roman>` sub-headers, the stack-specific tokens (`Idempotent Deploys` / `Composable Default Exit Codes` / `Stable API Surface` per stack), and the placeholder tokens (`{{project_type}}`, `{{primary_constraint}}`, `{{target_user}}`).
   - Emits `PASS:` / `SUMMARY:` lines per starter.

10. **Author `tools/verify/m033-p03-constitution-starter-format-ref-shape.sh`** (≥25 lines, executable). Asserts:
    - `references/constitution-starter-format.md` exists.
    - Body contains the load-bearing tokens via `grep -F`: `schema_version`, `Roman-numeral`, `Constitution Check`, `Principle`, `{{`, `web-saas`, `cli-tool`, `library`, `#Q-2`.
    - Emits `PASS:` / `SUMMARY:` lines.

## Must-Haves

This task addresses these P03 phase truths:
- `scripts/verify/constitution-shape-lint.sh` exists with the documented assertions (FR-5).
- `scripts/verify/standalone-gate.sh` exists with the `constitution` subcommand handler (FR-6 / Principle XVI).
- Three stack starters exist at `templates/constitution-starters/{web-saas,cli-tool,library}.md` (FR-4).
- `references/constitution-starter-format.md` exists with the v1 stack list and `#Q-2` expansion criterion.

This task creates these P03 phase artifacts:
- Lint verifier: `scripts/verify/constitution-shape-lint.sh` (FR-5).
- Standalone gate: `scripts/verify/standalone-gate.sh` (FR-6).
- Starters: `templates/constitution-starters/{web-saas,cli-tool,library}.md` (FR-4).
- Reference: `references/constitution-starter-format.md`.
- Verifiers: `tools/verify/m033-p03-{constitution-shape-lint-shape,standalone-gate-sh-shape,constitution-starter-templates-shape,constitution-starter-format-ref-shape}.sh`.

## Verification

```bash
bash tools/verify/m033-p03-constitution-shape-lint-shape.sh
bash tools/verify/m033-p03-standalone-gate-sh-shape.sh
bash tools/verify/m033-p03-constitution-starter-templates-shape.sh
bash tools/verify/m033-p03-constitution-starter-format-ref-shape.sh
```

## Inputs

### From Previous Tasks

None. T01 has no intra-phase prerequisites.

### From Disk (Pre-existing)

- `.orchestrator/memory/constitution.md` — the orchestrator's own constitution (read-only reference for the 6 baseline principles seeded into the three starters; T01 reads this file to copy the principle names + framing into the starter bodies but does NOT modify it).
- `scripts/util/json-field.sh` (MEM008) — NOT required by T01 (verifiers parse via grep/awk, no JSON field extraction at this layer).

## Constraints

- Bash 3.2 compatibility (MEM001) — no `declare -A`, no process substitution, no `$(...)` containing pipes.
- Verifiers use single-script-file shape per AD-19 — no `( … )` subshells, no `$(...)` with pipes, no compound chains.
- Standalone-gate's closed surface file set is the SSOT — extending the surface requires editing the fenced block, not the consumer.
- The standalone gate tolerates SKIP for co-authored-but-not-yet-landed surfaces (e.g., `commands/constitution.md` before T02 lands) — this preserves T01's ability to ship before T02 without false failures. T05's SC-2 acceptance script asserts the gate produces zero SKIP lines after T02 lands.
- T01 MUST NOT modify `scripts/lifecycle/start.sh` (P01-shipped surface).
- T01 MUST NOT modify any P02-shipped surface (`grilling-shell.sh`, `jsonl-event-emitter.sh`, `start-state-markers.sh`, `references/m033-fr21-dual-write-convention.md`).
- T01 MUST NOT introduce any `speckit.*` reference into any of the four authored surfaces (Principle XVI / CON-3 dogfood — the gate will scan its own outputs).

## Expected Output

After T01 completes:
- `scripts/verify/constitution-shape-lint.sh` exists, is executable, and exits 0 against a valid constitution fixture.
- `scripts/verify/standalone-gate.sh` exists, is executable, and exits 0 against the (partial) M033 surface (any not-yet-authored surface emits SKIP).
- Three starter templates exist at `templates/constitution-starters/{web-saas,cli-tool,library}.md`.
- `references/constitution-starter-format.md` exists.
- All four T01 verifiers exit 0 with `SUMMARY:` lines.
- A summary file at `.orchestrator/milestones/M033/phases/P03/tasks/T01-standalone-gate-and-starters-SUMMARY.md` documents the deliverables.

## Notes

T01's standalone gate is the dogfood compliance test for CON-3 / Principle XVI — the gate scans its own M033 surface for `speckit.*` leakage. T02's `constitution-author.sh` will be one of the surface files; the gate-against-T02 fires at T02 land time. SC-2 (T05 deliverable) is the end-to-end assertion that the full surface is `speckit.*`-free.

The 6 baseline principles in the starters intentionally mirror the orchestrator's own `.orchestrator/memory/constitution.md` v1 baseline (Context Minimization / Evidence Before Claims / Design Before Code / Plans Assume Zero Context / State On Disk Is Truth / Knowledge Compounds) — this is deliberate dogfood (the orchestrator constitution is the canonical seed; downstream-project constitutions are derivatives). Stack-specific principles extend the baseline; they do not replace it.

The placeholder vocabulary (`{{project_type}}`, `{{primary_constraint}}`, `{{target_user}}`) is the v1 closed set. T02's `constitution-author.sh` runs a 5–8 question grilling-shell flow that resolves these three placeholders plus 2–5 stack-specific follow-ups; the FR-5 lint asserts zero `{{` survivors.

The standalone gate's path discipline (framework-owned non-slug-bearing under `scripts/verify/`) is deliberate: the gate must ship in the install bundle so any downstream project that adopts the orchestrator inherits the Principle XVI compliance test for free.
