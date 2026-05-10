---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P03"
milestone: "M033"
name: "FR-8 / MIT-005 rich-context import path + _imported-context/ sentinel + downstream-traverser annotations (FR-8 / #Q-11)"
depends_on: ["T03"]
---

## Prerequisites

- T03 closed: `scripts/lifecycle/ingest-codebase.sh` exists with the reserved fenced block `# >>> rich-context-branch >>>` ... `# <<< rich-context-branch <<<` containing the no-op stub `true # T04 fills this block`. Verified by `[ -f scripts/lifecycle/ingest-codebase.sh ]` and `grep -F 'rich-context-branch' scripts/lifecycle/ingest-codebase.sh`.
- T03 ships the TS SaaS fixture with `<fixture>/.orchestrator/DECISIONS.md` containing `DR-DEMO-001` and `DR-DEMO-002` entries — verified by `[ -f tests/fixtures/m033-stack-fixture-ts-saas/.orchestrator/DECISIONS.md ]`.
- M033/P02 closed: `scripts/util/jsonl-event-emitter.sh` accepts `imported_context_loaded` event (one of the 11 closed-enum types).
- `references/imported-context-sentinel.md` does NOT yet exist — verified by `[ ! -f references/imported-context-sentinel.md ]`.
- Spec context: FR-8 / MIT-005 — detect rich-context source files in the project; emit a thin `<current-milestone>-CONTEXT.md` with `context_source: imported-from-existing` (or `_imported-context/_imported-context.md` sentinel when no active milestone is configured per `#Q-11`); cross-reference `DR-` entries as `MEM-DR-*` provenance MEMs (NOT duplicate authoring). Downstream traversers (`validate-milestone.sh`, `build-context.sh`, `run-doctor.sh` or equivalents) MUST treat `_*` prefix as a special non-milestone class.

## Description

T04 ships the FR-8 / MIT-005 rich-context import path as an in-place extension of T03's `scripts/lifecycle/ingest-codebase.sh` driver, the `references/imported-context-sentinel.md` SSOT, and additive annotations in the downstream traversers (`scripts/state/derive-phase.sh`, `scripts/dispatch/build-context.sh`, `scripts/diagnostics/run-doctor.sh` — exact filenames identified at execution time via `find scripts/ -name '*.sh' -exec grep -l 'milestones/' {} +`).

The rich-context branch fires when any of three signals is detected in the project: (a) `<project-dir>/.orchestrator/DECISIONS.md` containing `DR-` entries; (b) `<project-dir>/.orchestrator/MILESTONE-AUDIT.md` (any content); (c) a populated `<!-- BEGIN CUSTOM -->` ... `<!-- END CUSTOM -->` region in `<project-dir>/CLAUDE.md`. On detection, the path:

1. Resolves the emit path: when `<project-dir>/.orchestrator/config.yml` declares `current_milestone: <id>`, emit to `<project-dir>/.orchestrator/milestones/<id>/<id>-CONTEXT.md`; when no active milestone is configured, emit to `<project-dir>/.orchestrator/milestones/_imported-context/_imported-context.md` (the sentinel path per `#Q-11`).
2. Writes a thin context file (≤30 lines) with frontmatter `context_source: imported-from-existing` + an inline reference list naming the source files. NO duplicate authoring of the source content — the file is a cross-reference index.
3. For every `DR-<id>` entry detected in `<project-dir>/.orchestrator/DECISIONS.md`, emits a `<project-dir>/.orchestrator/knowledge/decisions/MEM-DR-<id>.md` cross-reference MEM (single-line body referencing the source).
4. Emits one `imported_context_loaded` JSONL event per FR-22.

**The sentinel convention is the load-bearing decision (#Q-11):** any `.orchestrator/milestones/_*` prefix is a special non-milestone class. Downstream traversers that enumerate milestones MUST skip `_*`-prefixed entries (otherwise they treat `_imported-context` as an active milestone and fail validation). The annotations are additive — no behavior change for projects without imported context.

**Bash 3.2 compatibility (MEM001):** No `declare -A`, no process substitution, no `$(...)` containing pipes.

## Steps

1. **Author `references/imported-context-sentinel.md`** (≥50 lines). Documents:
   - The sentinel directory path (`<project-dir>/.orchestrator/milestones/_imported-context/`) and its filename (`_imported-context.md`).
   - The path-resolver precedence: when `<project-dir>/.orchestrator/config.yml` declares `current_milestone: <id>`, emit to `<project-dir>/.orchestrator/milestones/<id>/<id>-CONTEXT.md`; otherwise emit to the sentinel path.
   - The downstream-traverser convention: any `_*`-prefix entry under `.orchestrator/milestones/` is treated as a special non-milestone class. Concretely:
     - `validate-milestone.sh` (or equivalent) skips `_*` entries from milestone enumeration.
     - `build-context.sh` skips `_*` entries from milestone-based context resolution but MAY surface them via dedicated `imported-context` injection.
     - `run-doctor.sh` skips `_*` entries from staleness / orphan checks.
   - The frontmatter SSOT marker `context_source: imported-from-existing` — downstream tools detect imported-context vs natively-authored context by greping this field.
   - The `MEM-DR-*` cross-reference convention: provenance-preserving (NOT duplicate authoring); MEM body is a single-line reference to the source `DR-<id>` in the project's `DECISIONS.md`.
   - Reference to `#Q-11` (the discuss-phase resolution) and the [M020](../../../../../milestones/M020/index.md) Knowledge-Layer Boundary (no new MEM kinds; cross-reference fits inside existing `decisions` category).

   Load-bearing tokens (verifier greps): `_imported-context`, `context_source: imported-from-existing`, `validate-milestone.sh`, `build-context.sh`, `run-doctor.sh`, `_*`, `#Q-11`, `MEM-DR-`.

2. **Identify downstream traversers and apply additive `_*`-prefix skip annotations.**

   2a. **Identify candidate files.** At execution time, run `grep -rl 'milestones/' scripts/state/ scripts/dispatch/ scripts/diagnostics/` (single command, no compound shape) to identify the precise filenames that traverse `.orchestrator/milestones/`. Expected candidates: `scripts/state/derive-phase.sh`, `scripts/state/read-roadmap.sh`, `scripts/dispatch/build-context.sh`, `scripts/diagnostics/run-doctor.sh`, `scripts/verify/validate-milestone.sh`. The exact set may differ; T04 identifies and gates the precise files at execution time.

   2b. **Apply additive skip annotation.** For each identified traverser, locate the `for d in <milestones-glob>` (or equivalent enumeration) and add a guard clause skipping `_*`-prefixed entries:

     ```bash
     for d in "$milestones_dir"/*/; do
       base="$(basename "$d")"
       case "$base" in
         _*) continue ;;  # skip imported-context sentinel (M033/P03/T04 / #Q-11)
       esac
       # ... existing logic
     done
     ```

     The annotation is **additive** — it does NOT change behavior for projects without imported-context entries. It MUST be backward-compatible with the existing P01 + P02 + earlier-milestone surfaces. The phase-suite cross-phase regression verifier (T05 deliverable) re-runs `tools/verify/m033-p01-phase-suite.sh` and `tools/verify/m033-p02-phase-suite.sh` after T04's annotations land, asserting both still pass.

   2c. **Document modifications.** Each touched file gets a single inline comment naming `M033/P03/T04` and `#Q-11` next to the skip clause. The verifier asserts the comment is present.

3. **Extend `scripts/lifecycle/ingest-codebase.sh` in-place.** Replace the `# >>> rich-context-branch >>>` ... `# <<< rich-context-branch <<<` stub block with the real implementation:

   3a. **Detection.** After the deterministic-core MEM emission (T03 step 2g/h), scan for rich-context signals:
   - `[ -f "<project-dir>/.orchestrator/DECISIONS.md" ]` AND `grep -q '^DR-' "<project-dir>/.orchestrator/DECISIONS.md"` (matches lines starting with `DR-`).
   - `[ -f "<project-dir>/.orchestrator/MILESTONE-AUDIT.md" ]`.
   - `[ -f "<project-dir>/CLAUDE.md" ]` AND a non-empty region between `<!-- BEGIN CUSTOM -->` and `<!-- END CUSTOM -->` (extracted via `awk '/<!-- BEGIN CUSTOM -->/,/<!-- END CUSTOM -->/'` then filter).

     If none of these signals fire, the rich-context branch is a no-op and the driver proceeds to step 2i (marker write).

   3b. **Path resolution.** Read `<project-dir>/.orchestrator/config.yml` for `current_milestone:` field via `grep -E '^current_milestone:'` + `awk '{print $2}'` (single-pipe-free shape). If found and non-empty, set `RICH_CONTEXT_PATH="<project-dir>/.orchestrator/milestones/${current_milestone}/${current_milestone}-CONTEXT.md"`. If absent, set `RICH_CONTEXT_PATH="<project-dir>/.orchestrator/milestones/_imported-context/_imported-context.md"`. Create the parent directory via `mkdir -p`.

   3c. **Thin context file emission.** Write a context file (≤30 lines) with frontmatter:

     ```yaml
     ---
     schema_version: "1.0"
     type: imported-context
     context_source: imported-from-existing
     imported_at: <ISO 8601 UTC timestamp>
     source_files:
       - [.orchestrator/DECISIONS.md](../../../../../decisions.md)
       - .orchestrator/MILESTONE-AUDIT.md
       - CLAUDE.md (custom block)
     ---
     ```

     (Only include `source_files` entries that actually exist; omit the others.) Body:

     ```markdown
     # Imported Context

     This context file was generated by `orchestrator:ingest-codebase` from existing project artifacts. The source files (named in `source_files:`) are the authoritative content; this file is a cross-reference index, NOT a duplicate.

     ## Sources

     - [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) — N decision records (DR-DEMO-001 ... DR-DEMO-N) cross-referenced as `knowledge/decisions/MEM-DR-*.md`.
     - `.orchestrator/MILESTONE-AUDIT.md` — milestone-audit history (read directly).
     - `CLAUDE.md` custom block — populated; consumed at dispatch time.

     ## Provenance

     M033/P03/T04 — FR-8 / MIT-005 rich-context import path. See `references/imported-context-sentinel.md`.
     ```

   3d. **`MEM-DR-*` cross-reference emission.** For every `DR-<id>` entry detected in `<project-dir>/.orchestrator/DECISIONS.md` (parsed via `grep -E '^DR-'`), write `<project-dir>/.orchestrator/knowledge/decisions/MEM-DR-<id>.md` with:

     ```yaml
     ---
     schema_version: "1.0"
     type: knowledge-mem
     category: decisions
     status: graduated
     source_path: [.orchestrator/DECISIONS.md](../../../../../decisions.md)
     signal_kind: dr-cross-reference
     dr_id: <id>
     derived_from_codebase_ingest: true
     ---
     ```

     Body (single line):

     ```markdown
     # MEM-DR-<id>

     Cross-reference to `DR-<id>` in [`.orchestrator/DECISIONS.md`](../../../../../decisions.md). Provenance-preserving — see source for canonical content.
     ```

     Idempotency: if `MEM-DR-<id>.md` already exists with `derived_from_codebase_ingest: true` in frontmatter, skip without overwriting (re-ingest discipline matching T03's main path).

   3e. **JSONL event emit.** `PROJECT_DIR="<project-dir>" bash scripts/util/jsonl-event-emitter.sh emit imported_context_loaded '{"path":"<RICH_CONTEXT_PATH>","dr_count":<N>}'`.

   3f. **The `# >>> rich-context-branch >>>` block markers MUST be preserved** (the stub-helper-with-stable-name pattern from P02). T04's verifier asserts the markers still exist AND the stub `true # T04 fills this block` is REMOVED (proves T04 actually did the in-place replacement).

4. **Author `tools/verify/m033-p03-rich-context-import-shape.sh`** (≥30 lines, executable). Asserts:
   - `scripts/lifecycle/ingest-codebase.sh` body contains the load-bearing tokens via `grep -F`: `context_source: imported-from-existing`, `_imported-context`, `MEM-DR-`, `imported_context_loaded`, `current_milestone`, `BEGIN CUSTOM`, `MILESTONE-AUDIT.md`.
   - The `# >>> rich-context-branch >>>` and `# <<< rich-context-branch <<<` markers exist.
   - The stub `true # T04 fills this block` is REMOVED (negative `grep -F` returns 0 matches).
   - **Functional smoke test:** copy `tests/fixtures/m033-stack-fixture-ts-saas/` (which carries [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) with `DR-DEMO-001` and `DR-DEMO-002`) to `mktemp -d`; run `bash scripts/lifecycle/ingest-codebase.sh --project-dir <staging> --yes`; assert `<staging>/.orchestrator/milestones/_imported-context/_imported-context.md` exists; assert it contains `context_source: imported-from-existing`; assert `<staging>/.orchestrator/knowledge/decisions/MEM-DR-DEMO-001.md` and `MEM-DR-DEMO-002.md` exist; assert the JSONL log contains one `imported_context_loaded` event. Cleanup mandatory.
   - **Negative smoke test:** copy `tests/fixtures/m033-stack-fixture-py-cli/` (which has NO [`.orchestrator/DECISIONS.md`](../../../../../decisions.md)) to `mktemp -d`; run the driver; assert `<staging>/.orchestrator/milestones/_imported-context/` does NOT exist (rich-context branch did not fire). Cleanup mandatory.
   - Emits `PASS:` / `SUMMARY:` lines.

5. **Author `tools/verify/m033-p03-imported-context-sentinel-shape.sh`** (≥30 lines, executable). Asserts:
   - `references/imported-context-sentinel.md` exists.
   - Body contains the load-bearing tokens via `grep -F`: `_imported-context`, `context_source: imported-from-existing`, `validate-milestone.sh`, `build-context.sh`, `run-doctor.sh`, `_*`, `#Q-11`, `MEM-DR-`.
   - For each candidate downstream traverser (identified by T04 step 2a), assert the additive `_*`-prefix skip clause is present via `grep -F '_*) continue'` AND the inline comment naming `M033/P03/T04` and `#Q-11` is present. The verifier enumerates the candidate file list inline (file paths hard-coded based on T04 execution-time discovery).
   - Emits `PASS:` / `SUMMARY:` lines.

## Must-Haves

This task addresses these P03 phase truths:
- The FR-8 / MIT-005 rich-context import path is implemented as a branch inside `scripts/lifecycle/ingest-codebase.sh`.
- The `_imported-context/` sentinel convention is documented at `references/imported-context-sentinel.md` per `#Q-11`.
- Downstream traversers carry additive `_*`-prefix skip annotations.

This task creates these P03 phase artifacts:
- Reference: `references/imported-context-sentinel.md`.
- Modifications: `scripts/lifecycle/ingest-codebase.sh` (in-place rich-context-branch fill), downstream traversers (additive skip annotations).
- Verifiers: `tools/verify/m033-p03-{rich-context-import-shape,imported-context-sentinel-shape}.sh`.

## Verification

```bash
bash tools/verify/m033-p03-rich-context-import-shape.sh
bash tools/verify/m033-p03-imported-context-sentinel-shape.sh
```

## Inputs

### From Previous Tasks

- T03 — `scripts/lifecycle/ingest-codebase.sh` (extend in place; the reserved fenced block is the integration seam); `tests/fixtures/m033-stack-fixture-ts-saas/.orchestrator/DECISIONS.md` (the smoke-test input with `DR-DEMO-001` and `DR-DEMO-002` entries).

### From P02 (Pre-existing)

- `scripts/util/jsonl-event-emitter.sh` — accepts `imported_context_loaded` event in the closed enum.

### From Disk (Pre-existing)

- `scripts/state/derive-phase.sh`, `scripts/dispatch/build-context.sh`, `scripts/diagnostics/run-doctor.sh`, `scripts/state/read-roadmap.sh`, `scripts/verify/validate-milestone.sh` — candidate downstream traversers. T04 identifies the precise file set at execution time via `grep -rl 'milestones/'`.
- M020 knowledge-graph kinds (`decisions` is one; T04 emits `MEM-DR-*` cross-references inside the `decisions` category — no new kinds).

## Constraints

- Bash 3.2 compatibility (MEM001) — no `declare -A`, no process substitution, no `$(...)` containing pipes.
- The rich-context import file is **thin** (≤30 lines) — cross-reference index, NOT duplicate authoring of source content.
- `MEM-DR-*` MEMs are **provenance-preserving cross-references** (single-line body referencing the source `DR-<id>`) — NOT duplicate authoring per FR-8.
- Downstream-traverser annotations are **additive** — no behavior change for projects without imported-context entries. P01 and P02 phase-suites MUST still pass after T04 lands (cross-phase regression precedent — T05's verifier asserts this).
- The fenced `# >>> rich-context-branch >>>` block markers are preserved; only the stub body is replaced. The verifier asserts both: markers present AND stub removed.
- Sentinel path discipline — `_imported-context/` (with leading underscore) is the canonical sentinel; never use a numerically-prefixed directory for imported context (would conflict with milestone enumeration).
- Verifiers use single-script-file shape per AD-19 — no `( … )` subshells, no `$(...)` with pipes, no compound chains.
- T04 MUST NOT modify any P01 or P02 surface (`scripts/lifecycle/start.sh`, `scripts/lifecycle/grilling-shell.sh`, `scripts/util/jsonl-event-emitter.sh`, `scripts/util/start-state-markers.sh`, `references/m033-fr21-dual-write-convention.md`).
- T04 MUST NOT modify the orchestrator's own `.orchestrator/milestones/` tree (the rich-context branch writes to project-local paths only).

## Expected Output

After T04 completes:
- `references/imported-context-sentinel.md` exists per `#Q-11`.
- `scripts/lifecycle/ingest-codebase.sh` carries the in-place rich-context branch (stub replaced; markers preserved).
- Downstream traversers carry additive `_*`-prefix skip annotations with inline comments naming `M033/P03/T04` and `#Q-11`.
- Both T04 verifiers exit 0 with `SUMMARY:` lines.
- `tools/verify/m033-p01-phase-suite.sh` AND `tools/verify/m033-p02-phase-suite.sh` still exit 0 (cross-phase regression preserved).
- A summary file at `.orchestrator/milestones/M033/phases/P03/tasks/T04-rich-context-import-SUMMARY.md` documents the deliverables.

## Notes

The exact downstream-traverser file set is identified at T04 execution time via `grep -rl 'milestones/'`. Candidates include `scripts/state/derive-phase.sh`, `scripts/state/read-roadmap.sh`, `scripts/dispatch/build-context.sh`, `scripts/diagnostics/run-doctor.sh`, `scripts/verify/validate-milestone.sh`. T04's verifier hard-codes the discovered file paths so downstream regression catches drift. If a candidate file does NOT enumerate milestones (e.g., it only resolves a single milestone path passed as an argument), the skip clause is unnecessary and T04 documents the omission inline.

The signal-detection logic in step 3a is **OR**-shaped: any one of the three signals fires the branch. Detection is non-destructive — the path reads the source files but does NOT modify them. The cross-reference shape preserves provenance: an operator who later wants to migrate `DR-DEMO-001` to a real M020 graph entry has the source file ([`.orchestrator/DECISIONS.md`](../../../../../decisions.md)) intact.

The `<current-milestone>-CONTEXT.md` filename convention matches the existing milestone-context shape in `.orchestrator/milestones/<id>/M<id>-CONTEXT.md` — using `<id>-CONTEXT.md` keeps the file discoverable by the existing milestone-context machinery ([M005](../../../../../milestones/M005/index.md) D-row precedent). When using the `_imported-context/` sentinel, the filename is `_imported-context.md` (matching the directory name) so the sentinel surface is self-documenting.

The path-resolver branch on `current_milestone:` config presence is the load-bearing #Q-11 decision: pre-milestone-configured projects (no `current_milestone:` set in `config.yml`) get the sentinel; milestone-configured projects get the natively-authored path. This is consistent with M020 D024 reversibility — operators who later configure a milestone can `mv _imported-context/_imported-context.md M<id>/M<id>-CONTEXT.md` to migrate the file (no schema change).

The skip clause `case "$base" in _*) continue ;; esac` is bash 3.2 compatible AND short enough to inline at every traverser site without a shared helper. T04 prefers inline annotation (single-grep-token discoverable) over a shared helper (would introduce a new sourceable dependency).
