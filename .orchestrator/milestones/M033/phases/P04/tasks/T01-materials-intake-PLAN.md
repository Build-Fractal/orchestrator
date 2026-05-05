---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M033"
name: "commands/materials-intake.md + scripts/lifecycle/materials-intake.sh deterministic CON-4 drift detector + reconciliation UX (FR-9)"
depends_on: []
---

## Prerequisites

This task is the FR-9 surface: the orchestrator-native materials-intake command + driver. It has **no intra-phase prerequisites**; it consumes only previously-shipped P01/P02/P03 surfaces.

Files that MUST exist on disk at task-start (prerequisite-existence verification per `commands/plan-phase.md` Plan-Time Discipline rule 1):

- `tests/fixtures/m033-pbj-materials-fixture/PRODUCT-BRIEF.md` (P01/T01 — PBJ fixture material 1)
- `tests/fixtures/m033-pbj-materials-fixture/MVP-PLAN.md` (P01/T01 — PBJ fixture material 2)
- `tests/fixtures/m033-pbj-materials-fixture/DECISIONS.md` (P01/T01 — PBJ fixture material 3)
- `tests/fixtures/m033-pbj-materials-fixture/MILESTONE-AUDIT.md` (P01/T01 — PBJ fixture material 4)
- `tests/fixtures/m033-pbj-materials-fixture/README.md` (P01/T01 — the SC-4 ground-truth oracle: enumerates the 5 expected detections in markdown numbered-list shape with the closed CON-4 enum tokens `id-misalignment`, `scheme-contradiction`, `orphan-reference`)
- `scripts/lifecycle/grilling-shell.sh` (P02/T03+T04 — `ask_one` API; `_GRILLING_CURRENT_QKEY` caller-set var convention)
- `scripts/util/jsonl-event-emitter.sh` (P02/T01 — `emit materials_intake_completed <payload_json>` subcommand)
- `scripts/util/start-state-markers.sh` (P02/T02 — `write materials-intake <project-dir>` subcommand; `materials-intake` is in the closed 7-name sub-flow enum)
- `scripts/util/dual-write-runtime-md.sh` (M014 closed — invoked via `--root <project-dir> --marker recent-changes --append-entry '<fragment>'` per the P03/T05 SSOT-harmonized API)
- `references/m033-fr21-dual-write-convention.md` (P02/T05 — FR-21 SSOT documenting the dual-write call shape)

## Description

T01 ships the FR-9 materials-intake surface — the orchestrator-native command + driver that takes heterogeneous source materials (the PBJ-shape: `PRODUCT-BRIEF.md`, `MVP-PLAN.md`, `DECISIONS.md`, `MILESTONE-AUDIT.md`), labels them, runs **deterministic** CON-4 drift detection (no LLM-magic merge), reconciles via terminal-interactive UX for ≤5 conflicts (file-based UX above the threshold per #Q-6), and emits a byte-deterministic reconciled pre-spec that `orchestrator:specify` consumes verbatim.

The two deliverables are:

1. **`commands/materials-intake.md`** — canonical command-doc per MEM012 (YAML frontmatter `description:` field; `# orchestrator:materials-intake` title; Prerequisites / Core Workflow / Output / Idempotency / Error Handling / Referenced Scripts sections). Documents the FR-9 contract, names the closed labeling enum (`primary | supplementary | decision-history | out-of-scope`), names the closed CON-4 detection-category enum (`id-misalignment`, `scheme-contradiction`, `orphan-reference`), names the threshold env var (`M033_CONFLICT_FILE_THRESHOLD`, default 5 per #Q-6), references the PBJ fixture as the SC-4 oracle, and explicitly states the deterministic-not-LLM invariant per CON-4.

2. **`scripts/lifecycle/materials-intake.sh`** — the FR-9 driver, bash 3.2 compatible (MEM001), structured-output PASS:/FAIL:/SUMMARY: discipline.

Co-authored alongside the deliverables (per Plan-Time Discipline rule 2, verifier-availability cross-check):

3. **`tools/verify/m033-p04-materials-intake-md-shape.sh`** — shape verifier for the command doc.
4. **`tools/verify/m033-p04-materials-intake-sh-shape.sh`** — shape verifier for the driver.

## Steps

1. **Author `commands/materials-intake.md`** following the MEM012 canonical command-doc structure. Include:
   - YAML frontmatter with `description: "Use when intaking heterogeneous source materials (Product Brief, Decision Register, MVP Plan, Handoff JSON, milestone audits) and producing a reconciled orchestrator:specify-consumable pre-spec."`
   - `# orchestrator:materials-intake` title.
   - Prerequisites section — names the four PBJ-shape material types and links to the P01 fixture as the canonical example.
   - Core Workflow — numbered sections covering: (a) material enumeration by extension, (b) labeling loop with the closed enum, (c) deterministic CON-4 drift detection with the closed three-category enum, (d) terminal-interactive resolution for ≤`M033_CONFLICT_FILE_THRESHOLD` conflicts / file-based UX above, (e) reconciled-pre-spec emission to `<project-dir>/.orchestrator/intake/<timestamp>/reconciled-pre-spec.md`, (f) marker write + JSONL emit + dual-write fragment.
   - Output section — names the artifacts (`reconciled-pre-spec.md` or `conflicts.md`), the `materials-intake.complete` marker, the `materials_intake_completed` JSONL event.
   - Idempotency — re-running against the same `<timestamp>` directory resumes labeling/reconciliation from on-disk state.
   - Error Handling — names the `out-of-scope`-only fallback per US-4 AS-5; the missing-converter-binary diagnostic per Edge Case "Materials intake against a directory with binary materials".
   - Referenced Scripts — lists `scripts/lifecycle/materials-intake.sh`, `scripts/lifecycle/grilling-shell.sh` (consumed for `ask_one`), `scripts/util/jsonl-event-emitter.sh`, `scripts/util/start-state-markers.sh`, `scripts/util/dual-write-runtime-md.sh`.

2. **Author `scripts/lifecycle/materials-intake.sh`** — bash 3.2 compatible. Top-level structure:
   - Shebang `#!/usr/bin/env bash`, then `set -e`, `set -u`, `set -o pipefail`.
   - File header comment naming FR-9, CON-4, MEM001, the spec ref (`specs/036-project-onboarding-experience/spec.md`).
   - Fenced SSOT comment blocks:
     - `# >>> material-extensions >>>` containing `.md`, `.pdf`, `.json`, `.txt` (one per line).
     - `# >>> labeling-enum >>>` containing `primary`, `supplementary`, `decision-history`, `out-of-scope` (one per line).
     - `# >>> drift-categories >>>` containing `id-misalignment`, `scheme-contradiction`, `orphan-reference` (one per line).
   - Flag parsing: `--project-dir <path>` (default `pwd`), `--yes` (auto-accept defaults), `--resolve <conflicts.md>` (re-invocation path).
   - Helper `enumerate_materials <project-dir>` — iterates project-root files matching the closed extension SSOT; for `.pdf`, probes `command -v textutil` (darwin) or `command -v pdftotext` (linux) and surfaces a missing-binary diagnostic + skip if absent (NOT silent skip per Edge Case).
   - Helper `label_material <material-path> <yes_flag>` — derives recommendation from filename heuristics (`*BRIEF*` / `*PLAN*` → `primary`; `*DECISIONS*` / `*AUDIT*` → `decision-history`; `*HANDOFF*` → `supplementary`; otherwise `supplementary`); under `--yes` auto-accepts; otherwise invokes `ask_one "Label for <basename>:" "<recommendation>"` (no third-arg context-file — labeling is independent of contradiction-detection).
   - Helper `detect_drift <project-dir> <materials-list>` — three deterministic detectors, each reading the materials and emitting `<category>:<conflict-N>:<details>` lines to a temp accumulator file:
     - `detect_id_misalignment`: extracts `<TOKEN>-<NUMBER>` references (e.g., `DR-001`, `M001`, `FR-12`) per material via `grep -oE '[A-Z][A-Z]+-[0-9]+'`; for each token-prefix family (`DR-`, `FR-`, `M-`, etc.), compares the maximum number across documents — if two documents reference the same token-prefix family but with non-overlapping number ranges, emit an `id-misalignment` entry.
     - `detect_scheme_contradiction`: extracts same-key declarations across `primary` + `supplementary` materials (e.g., `target_user:`, `mvp_boundary:`, `success_metric:` lines) and emits a `scheme-contradiction` entry when the same key has different values across documents.
     - `detect_orphan_reference`: collects every `<TOKEN>-<NUMBER>` reference, then collects every `<TOKEN>-<NUMBER>` definition (lines matching `^### (TOKEN-NUMBER)` or `^TOKEN-NUMBER:` per the PBJ fixture's convention); emits an `orphan-reference` entry for any reference without a defining occurrence.
   - Helper `surface_conflicts <accumulator-file> <count>` — prints the conflict checklist to stdout (numbered 1..N, one per line, `<N>. <category>: <details>` shape).
   - Helper `reconcile_terminal <accumulator-file>` — for each conflict, invokes `ask_one "Resolve conflict <N> (<category>):" "accept-primary"` with the closed resolution enum `accept-primary | accept-supplementary | manual-edit | defer`; appends the resolution to the accumulator.
   - Helper `reconcile_file_based <accumulator-file> <project-dir> <timestamp>` — writes a markdown checklist to `<project-dir>/.orchestrator/intake/<timestamp>/conflicts.md` and exits 0 with `edit then re-invoke with --resolve <path>` diagnostic.
   - Helper `emit_reconciled_prespec <accumulator-file> <project-dir> <timestamp>` — composes the byte-deterministic reconciled pre-spec body: H1 title, sections per labeled material (primary first), provenance comments per resolved conflict (`<!-- Reconciled: conflict-N → accept-primary -->`). Writes to `<project-dir>/.orchestrator/intake/<timestamp>/reconciled-pre-spec.md`. The body must NOT embed timestamps or random tokens; only the directory name carries the timestamp.
   - Main flow: parse flags → resolve `<timestamp>` (honoring `M033_INTAKE_TIMESTAMP` env override for SC-4 byte-determinism) → enumerate → label → detect drift → if conflict-count ≤ threshold → reconcile-terminal → emit prespec; else → reconcile-file-based → exit 0 with diagnostic. After successful pre-spec emit: `bash scripts/util/start-state-markers.sh write materials-intake <project-dir>`; `bash scripts/util/jsonl-event-emitter.sh emit materials_intake_completed '{"materials_count":<N>,"conflicts_resolved":<M>}'` (PROJECT_DIR env set to `<project-dir>`); `bash scripts/util/dual-write-runtime-md.sh --root <project-dir> --marker recent-changes --append-entry "materials-intake: reconciled <N> materials with <M> conflicts resolved"`.
   - Out-of-scope-only fallback: when ALL detected materials are labeled `out-of-scope`, exit 0 with `no primary spec materials labeled — skipping reconciliation, falling back to greenfield-empty ideation flow` to stdout. No reconciled-pre-spec written. No marker written.

3. **Author `tools/verify/m033-p04-materials-intake-md-shape.sh`** — bash 3.2 verifier asserting:
   - File `commands/materials-intake.md` exists.
   - Contains `orchestrator:materials-intake`, `FR-9`, `CON-4`, `materials-intake.sh`, `primary`, `supplementary`, `decision-history`, `out-of-scope`, `id-misalignment`, `scheme-contradiction`, `orphan-reference`, `M033_CONFLICT_FILE_THRESHOLD`, `reconciled-pre-spec.md`, `materials_intake_completed`, `deterministic`, `m033-pbj-materials-fixture`.
   - Min line count 60.
   - Emits `PASS:`/`FAIL:` lines per check; final `SUMMARY: m033-p04-materials-intake-md-shape.sh pass=N fail=M`.

4. **Author `tools/verify/m033-p04-materials-intake-sh-shape.sh`** — bash 3.2 verifier asserting:
   - File `scripts/lifecycle/materials-intake.sh` exists, is executable.
   - Contains the fenced SSOT block markers `>>> material-extensions >>>`, `>>> labeling-enum >>>`, `>>> drift-categories >>>`.
   - Contains `ask_one`, `grilling-shell.sh`, `--project-dir`, `--yes`, `--resolve`, `id-misalignment`, `scheme-contradiction`, `orphan-reference`, `reconciled-pre-spec.md`, `conflicts.md`, `materials_intake_completed`, `materials-intake.complete`, `dual-write-runtime-md.sh`, `textutil`, `pdftotext`, `M033_CONFLICT_FILE_THRESHOLD`, `M033_INTAKE_TIMESTAMP`.
   - Bash 3.2 compat negative grep: does NOT contain `declare -A`, does NOT contain `<(` (process substitution).
   - Min line count 250.
   - Emits PASS/FAIL/SUMMARY lines.

## Must-Haves

- `commands/materials-intake.md` exists, ≥60 lines, satisfies the shape verifier (FR-9 contract documented per MEM012).
- `scripts/lifecycle/materials-intake.sh` exists, executable, ≥250 lines, satisfies the shape verifier (FR-9 driver implemented per spec; bash 3.2 compatible per MEM001).
- `tools/verify/m033-p04-materials-intake-md-shape.sh` exists, executable, exits 0 against the authored doc.
- `tools/verify/m033-p04-materials-intake-sh-shape.sh` exists, executable, exits 0 against the authored driver.

## Verification

```bash
bash tools/verify/m033-p04-materials-intake-md-shape.sh
```

```bash
bash tools/verify/m033-p04-materials-intake-sh-shape.sh
```

```bash
bash scripts/diagnostics/check-plans.sh
```

## Inputs

### From Previous Tasks

- `tests/fixtures/m033-pbj-materials-fixture/README.md` (from M033/P01/T01)
  - Key API: parser-load-bearing markdown numbered-list shape; lines `1.`..`5.` enumerate the 5 expected detections, each tagged with one of the closed CON-4 tokens (`id-misalignment`, `scheme-contradiction`, `orphan-reference`).
  - Key types: ground-truth oracle for SC-4 — drift detector output MUST match this README's enumeration line-by-line.
- `scripts/lifecycle/grilling-shell.sh` (from M033/P02/T03+T04)
  - Key API: `ask_one <question> <recommendation> [<context-file>]`. Prints `recommendation:` token first, then the question; reads one stdin line; one-keystroke contract (`Y`/`y`/empty → accept rec; `N`/`n` → re-prompt for explicit; otherwise treat as explicit answer); echoes `answer: <value>` on stdout. Returns 0 on success, 2 on bad usage / no explicit answer, 3 on contradiction-unresolved.
  - Key types: caller-set vars `_GRILLING_CURRENT_QKEY` (string), `_GRILLING_CURRENT_DEFINITION` (string) — set BEFORE invoking ask_one when contradiction-detection or glossary-update should fire. T01 sets `_GRILLING_CURRENT_QKEY=""` for labeling-loop calls (label questions are independent of contradiction detection).
- `scripts/util/jsonl-event-emitter.sh` (from M033/P02/T01)
  - Key API: `bash scripts/util/jsonl-event-emitter.sh emit <event_type> <payload_json>`. Closed enum includes `materials_intake_completed`. Honors `PROJECT_DIR` env override; appends to `<PROJECT_DIR>/.orchestrator/execution-log.jsonl`.
  - Key types: `<payload_json>` MUST be a JSON object (`{...}`); ≤480 bytes after format.
- `scripts/util/start-state-markers.sh` (from M033/P02/T02)
  - Key API: `bash scripts/util/start-state-markers.sh write materials-intake <project-dir>`. `materials-intake` is in the closed 7-name sub-flow enum; idempotent (first-completion timestamp preserved).
- `scripts/util/dual-write-runtime-md.sh` (M014 closed, P03/T05 SSOT-harmonized API)
  - Key API: `bash scripts/util/dual-write-runtime-md.sh --root <project-dir> --marker recent-changes --append-entry '<fragment>'`. Appends one line to `# >>> orchestrator:recent-changes >>>` block in `CLAUDE.md` (and `AGENTS.md` unless `dual_write_agents: false` in config).

### From Disk (Pre-existing)

- `templates/spec-template.md` — referenced for `orchestrator:specify --description` consumption shape; the reconciled pre-spec body should be flat markdown that this template can absorb.
- `references/m033-fr21-dual-write-convention.md` (from M033/P02/T05) — FR-21 SSOT; T01's dual-write fragment shape follows the convention's per-command examples.
- `commands/plan-phase.md` — Plan-Time Discipline rules 1, 2, 3, 6 inform the verifier-availability + path-collision discipline applied here.

## Constraints

- **CON-4 (deterministic-not-LLM)**: drift detection MUST use deterministic structural extraction only — `grep`/`awk`/`sed` regex; NO model invocation. The verifier asserts no `claude-code` / `conversus` / `llm` / `model_routing` substrings appear in materials-intake.sh.
- **MEM001 (bash 3.2 compat)**: no `declare -A`; no process substitution `<(...)`; no `$(...)` containing pipes. The verifier asserts via negative grep.
- **CON-5 (sequential-never-batched)**: labeling and reconciliation loops MUST invoke `ask_one` once per item, awaiting the resolved answer before proceeding to the next.
- **Byte-deterministic reconciled pre-spec**: same fixture + same answers → byte-identical body content. The directory-name timestamp is the only non-deterministic element; it is not embedded in the body. SC-4's `diff`-based determinism check pins the timestamp via `M033_INTAKE_TIMESTAMP` env override.
- **Path discipline**: command doc → `commands/`, driver → `scripts/lifecycle/`, project-owned slug-bearing verifiers → `tools/verify/m033-p04-*`. NO writes to `scripts/verify/` (framework-owned tree).
- **Path-collision check (Plan-Time Discipline rule 6)**: at task-start, run `ls -la commands/materials-intake.md scripts/lifecycle/materials-intake.sh tools/verify/m033-p04-materials-intake-md-shape.sh tools/verify/m033-p04-materials-intake-sh-shape.sh` — each MUST return "No such file or directory" before authoring (the four `create` deliverables have no pre-existing path collisions).
- **Scope**: T01 does NOT touch start.sh, ingest-codebase.sh, ideation.sh, or any P05 / customblock surface.

## Expected Output

After T01 completes:

- `commands/materials-intake.md` (new file, ≥60 lines)
- `scripts/lifecycle/materials-intake.sh` (new file, ≥250 lines, executable)
- `tools/verify/m033-p04-materials-intake-md-shape.sh` (new file, ≥30 lines, executable)
- `tools/verify/m033-p04-materials-intake-sh-shape.sh` (new file, ≥35 lines, executable)
- Both T01 verifiers exit 0; emit `SUMMARY: <name> pass=N fail=0` on the final line.
- `bash scripts/diagnostics/check-plans.sh` reports no new warnings against the T01 plan.

## Notes

- The shape verifiers run in static-grep-only mode at task time (no integration / functional smoke). Functional verification of the materials-intake driver against the PBJ fixture is T05's SC-4 acceptance script (`tests/m033-acceptance/p04-materials-intake.sh`).
- The `M033_INTAKE_TIMESTAMP` env override is documented in the driver's header comments as a TEST-ONLY escape valve. Production invocations rely on the natural `date -u +%Y%m%dT%H%M%SZ` timestamp.
- T01 OPTIONALLY rewires P01's `materials_intake_stub` in `scripts/lifecycle/start.sh` to invoke the real driver (replacing the `would-execute: materials-intake-stub` token with `materials-intake-completed:` or similar). This rewiring is execution-time-decided by the implementing agent — if SC-1's assertions are token-shape-tolerant, the rewiring is in scope; if SC-1 asserts the exact `would-execute:` literal, the rewiring is deferred to T05's cross-phase regression check (T05 updates SC-1 in lockstep). The cross-phase regression verifier is the canonical gate.
