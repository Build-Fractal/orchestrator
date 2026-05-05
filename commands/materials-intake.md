---
description: "Use when intaking heterogeneous source materials (Product Brief, Decision Register, MVP Plan, Handoff JSON, milestone audits) and producing a reconciled orchestrator:specify-consumable pre-spec."
---

# orchestrator:materials-intake

`orchestrator:materials-intake` is the FR-9 surface of M033 (Project
Onboarding Experience). It takes a heterogeneous set of source materials
in PBJ-shape (Product Brief, MVP Plan, Decision Register, Milestone
Audit, optional Handoff JSON), labels each one against the closed
labeling enum, runs **deterministic** drift detection across the labeled
set, reconciles conflicts via terminal-interactive UX (or file-based UX
when conflicts exceed `M033_CONFLICT_FILE_THRESHOLD`), and emits a
byte-deterministic reconciled pre-spec that `orchestrator:specify`
consumes verbatim.

The drift detector is **deterministic-not-LLM** per CON-4. It uses only
`grep` / `awk` / `sed` regex over the closed three-category enum:
`id-misalignment`, `scheme-contradiction`, `orphan-reference`. There is
no model invocation in the extraction path. The PBJ acceptance fixture
at `tests/fixtures/m033-pbj-materials-fixture/` is the SC-4 ground-
truth oracle: its `README.md` enumerates the 5 expected detections in
the parser-load-bearing markdown numbered-list shape, and SC-4 asserts
that the detector output names exactly those 5.

## Prerequisites / State Check

- `orchestrator:init` has run for the target project: the directory
  `<project-dir>/.orchestrator/` exists.
- The project has been opened via `orchestrator:start` on the
  `greenfield-with-materials` branch. The `init-invoked.complete`
  start-state marker is present.
- The target directory contains at least one source material in one of
  the closed extension set (`.md`, `.pdf`, `.json`, `.txt`).
- For `.pdf` materials: a converter binary is on `PATH` — `textutil` on
  darwin, `pdftotext` on linux. Missing-binary surfaces a diagnostic
  (NOT a silent skip per the Edge Case "Materials intake against a
  directory with binary materials").

## Core Workflow

1. **Material enumeration by extension.** Walk the project root and
   collect files matching the closed extension SSOT (`.md`, `.pdf`,
   `.json`, `.txt`) declared in the `# >>> material-extensions >>>`
   block of `scripts/lifecycle/materials-intake.sh`. The fixture at
   `tests/fixtures/m033-pbj-materials-fixture/` is the canonical
   PBJ-shape example: four `.md` documents covering PRODUCT-BRIEF,
   MVP-PLAN, DECISIONS, and MILESTONE-AUDIT roles plus a README oracle
   that is excluded from intake (the README is the ground truth, not a
   material).

2. **Labeling loop with the closed enum.** For each detected material,
   the driver derives a recommendation via filename heuristics
   (`*BRIEF*` -> `primary`; `*PLAN*` -> `primary`; `*DECISIONS*` ->
   `decision-history`; `*AUDIT*` -> `decision-history`; `*HANDOFF*` ->
   `supplementary`; otherwise `supplementary`). The closed labeling-loop
   enum is `primary | supplementary | decision-history | out-of-scope`.
   Under `--yes`, recommendations auto-accept. Otherwise the driver
   invokes `ask_one` once per material (CON-5 sequential-never-batched)
   and the operator confirms the recommendation or supplies an explicit
   label from the closed enum. The labeling loop sets
   `_GRILLING_CURRENT_QKEY=""` because labeling questions are
   independent of contradiction-detection — the contradiction detector
   fires on schema-key collisions, not on label choices.

3. **Deterministic CON-4 drift detection.** Three closed detection
   categories run sequentially over the labeled material set:
   - `id-misalignment` — extracts `<TOKEN>-<NUMBER>` references (e.g.
     `DR-001`, `M001`, `FR-12`, `US-3`) per material via
     `grep -oE '[A-Z][A-Z]+-[0-9]+'`. For each token-prefix family,
     compares the maximum number across documents; emits an
     `id-misalignment` entry when two documents reference the same
     token-prefix family with non-overlapping number ranges.
   - `scheme-contradiction` — extracts same-key declarations across
     `primary` + `supplementary` materials (e.g. `target_user:`,
     `mvp_boundary:`, `success_metric:`, `MVP timeline:`,
     `deployment target:`); emits a `scheme-contradiction` entry when
     the same key has different values across documents.
   - `orphan-reference` — collects every `<TOKEN>-<NUMBER>` reference
     across all materials, then collects every defining occurrence
     (lines matching `^### TOKEN-NUMBER` or `^TOKEN-NUMBER:` per the
     PBJ fixture's convention); emits an `orphan-reference` entry for
     any reference without a defining occurrence anywhere in the set.

   The detector is **deterministic-not-LLM** per CON-4. There is no
   `claude-code` / `conversus` / `llm` / `model_routing` invocation in
   the extraction path. The detector's output is byte-identical across
   platforms and operator identities for byte-identical inputs.

4. **Terminal-interactive resolution.** When the conflict count is at
   or below `M033_CONFLICT_FILE_THRESHOLD` (default 5 per #Q-6), the
   driver reconciles each conflict via `ask_one` with the closed
   resolution enum: `accept-primary | accept-supplementary |
   manual-edit | defer`. One ask per conflict (CON-5). Each resolution
   appends a `<!-- Reconciled: conflict-N -> <resolution> -->`
   provenance comment to the reconciled pre-spec body per US-4 AS-2.

5. **File-based resolution above threshold.** When the conflict count
   exceeds `M033_CONFLICT_FILE_THRESHOLD`, the driver writes a markdown
   checklist of conflicts to
   `<project-dir>/.orchestrator/intake/<timestamp>/conflicts.md` and
   exits 0 with the diagnostic
   `edit then re-invoke with --resolve <path>`. The `--resolve
   <conflicts.md>` re-invocation path resumes from the on-disk
   checklist.

6. **Reconciled pre-spec emission.** The driver composes a
   byte-deterministic reconciled pre-spec body (no embedded
   timestamps, no random tokens — the directory-name timestamp is
   the only non-deterministic element, and it is not embedded in the
   body) and writes it to
   `<project-dir>/.orchestrator/intake/<timestamp>/reconciled-pre-spec.md`.
   Same fixture + same answers -> byte-identical output across
   platforms (SC-4 `diff` determinism check). The `M033_INTAKE_TIMESTAMP`
   env var pins the timestamp for SC-4's byte-determinism assertion.

7. **Marker, JSONL emission, dual-write fragment.** On successful
   pre-spec emission, the driver invokes
   `bash scripts/util/start-state-markers.sh write materials-intake
   <project-dir>` (FR-20 marker), then
   `bash scripts/util/jsonl-event-emitter.sh emit
   materials_intake_completed '{"materials_count":<N>,"conflicts_resolved":<M>}'`
   (FR-22 observability event), then
   `bash scripts/util/dual-write-runtime-md.sh --root <project-dir>
   --marker recent-changes --append-entry
   "materials-intake: reconciled <N> materials with <M> conflicts
   resolved"` (FR-21 dual-write fragment per the SSOT at
   `references/m033-fr21-dual-write-convention.md`).

## Output

- `<project-dir>/.orchestrator/intake/<timestamp>/reconciled-pre-spec.md`
  — the byte-deterministic reconciled pre-spec consumed by
  `orchestrator:specify --description`.
- `<project-dir>/.orchestrator/intake/<timestamp>/conflicts.md` —
  written only when conflict count exceeds
  `M033_CONFLICT_FILE_THRESHOLD`. The driver exits 0 with a re-invoke
  diagnostic in this branch.
- `<project-dir>/.orchestrator/start-state/materials-intake.complete`
  — FR-20 partial-state marker.
- One `materials_intake_completed` line appended to
  `<project-dir>/.orchestrator/execution-log.jsonl` (FR-22).
- One fragment appended to the
  `# >>> orchestrator:recent-changes >>>` block in `CLAUDE.md` (and
  `AGENTS.md` unless `dual_write_agents: false` in config) per FR-21.

## Idempotency

- Re-running against the same `<timestamp>` directory resumes labeling
  / reconciliation from on-disk state. The accumulator file under the
  intake directory carries resolved labels and conflict resolutions so
  a partial run can resume.
- The `--resolve <conflicts.md>` re-invocation path is idempotent: it
  re-reads the on-disk checklist, applies each resolution, and produces
  the same reconciled pre-spec a fresh run would.
- The marker write preserves the first-completion timestamp (idempotent
  per `start-state-markers.sh` semantics).
- The JSONL emit is append-only — re-runs append additional events;
  uniqueness is enforced by downstream consumers, not the emitter.

## Error Handling

- **All-out-of-scope fallback (US-4 AS-5).** When ALL detected
  materials are labeled `out-of-scope`, the driver exits 0 with the
  diagnostic `no primary spec materials labeled - skipping
  reconciliation, falling back to greenfield-empty ideation flow`. No
  reconciled-pre-spec, conflicts.md, marker, or JSONL emission in this
  branch.
- **Missing-converter binary.** When a `.pdf` material is detected but
  neither `textutil` (darwin) nor `pdftotext` (linux) is on `PATH`, the
  driver emits `missing-binary: pdf converter not found` to stderr and
  skips that material. The skip is surfaced (NOT silent) per the Edge
  Case.
- **Empty material set.** When no materials match the extension SSOT,
  the driver exits 0 with the diagnostic
  `no materials detected - falling back to greenfield-empty ideation
  flow`. Same shape as the all-out-of-scope branch.
- **Unrecognized label / resolution.** `ask_one` enforces the closed
  enum at the prompt; explicit answers outside the closed enum cause a
  re-prompt at the call site.

## Referenced Scripts

- `scripts/lifecycle/materials-intake.sh` — the FR-9 driver.
- `scripts/lifecycle/grilling-shell.sh` — sourced for the `ask_one`
  API used by the labeling and reconciliation loops.
- `scripts/util/jsonl-event-emitter.sh` — `emit
  materials_intake_completed <payload>` (FR-22).
- `scripts/util/start-state-markers.sh` — `write materials-intake
  <project-dir>` (FR-20).
- `scripts/util/dual-write-runtime-md.sh` — `--root <project-dir>
  --marker recent-changes --append-entry '<fragment>'` per the FR-21
  SSOT.

## Spec References

- FR-9 (materials-intake surface).
- CON-4 (deterministic-not-LLM drift detector invariant).
- CON-5 (sequential-never-batched ask_one loops).
- FR-20 (start-state marker), FR-21 (dual-write convention),
  FR-22 (JSONL observability events).
- SC-4 (PBJ fixture acceptance — ground-truth oracle at
  `tests/fixtures/m033-pbj-materials-fixture/README.md`).
- US-4 (materials-intake user story); US-4 AS-2 (provenance
  comments); US-4 AS-5 (all-out-of-scope fallback).
- #Q-6 (`M033_CONFLICT_FILE_THRESHOLD` default 5).
