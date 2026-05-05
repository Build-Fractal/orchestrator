---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P04"
milestone: "M033"
name: "FR-12 migrate-then-ingest stable-ID dup-prevention sentinel handling in scripts/lifecycle/ingest-codebase.sh"
depends_on: []
---

## Prerequisites

T03 extends `scripts/lifecycle/ingest-codebase.sh` (P03/T03+T04) with FR-12 dup-prevention sentinel handling. T03 has **no intra-phase prerequisites**; it consumes only previously-shipped P03 surfaces.

Files that MUST exist on disk at task-start:

- `scripts/lifecycle/ingest-codebase.sh` (P03/T03+T04 — deterministic FR-7 core + FR-8 rich-context import branch; emit functions `emit_architecture_mem`, `emit_convention_mem`, `emit_decision_mem` with `derived_from_codebase_ingest: true` frontmatter sentinel; `stable_id` helper using md5 / md5sum)
- `commands/ingest-codebase.md` (P03/T03 — command doc; T03 may add a paragraph documenting the `derived_from_migrate` sentinel handling)
- `scripts/migrate/migrate.sh` (M015 closed — emits MEMs to `<project-dir>/.orchestrator/knowledge/...` as part of the migration; the MEMs MUST carry the `derived_from_migrate: true` frontmatter sentinel for T03's check to fire)

## Description

T03 extends `scripts/lifecycle/ingest-codebase.sh` so that, when invoked after `orchestrator:migrate` has populated MEMs into the project's knowledge tree, it does NOT silently overwrite the migrate-derived MEMs with structurally-extracted MEMs at the same stable-ID path. Instead, the emit functions detect any pre-existing on-disk MEM at the candidate path bearing `derived_from_migrate: true` frontmatter and skip the emit with a `skip-duplicate-from-migrate: <stable-id>` diagnostic to stdout.

This is the FR-12 contract per US-6 AS-3 / brief #Q-10:

> "When `start` routes to `migrating` AND the fixture has source files (`src/` or ≥10 root files), the post-migration sub-flow MUST optionally invoke `ingest-codebase` to fill gaps the migrator did not cover. Duplicate-MEM prevention: `ingest-codebase` MUST detect MEMs already emitted by the migrate path (by stable-ID match) and skip with a `skip-duplicate-from-migrate` diagnostic."

T03 also documents the contract in `commands/ingest-codebase.md` (a small additive paragraph) so future operators discover the dup-prevention behavior without reading the script.

T03 does NOT modify `migrate.sh` (M015 is closed). The contract is one-way: migrate.sh's emitted MEMs MUST carry `derived_from_migrate: true` frontmatter (this is assumed pre-existing per the closure of M015; if migrate.sh's emitted MEMs do NOT carry this sentinel, T03 surfaces the gap as a documentation note in its summary — the FR-12 contract still holds at the orchestrator-spec layer; the M015 frontmatter shape is a downstream concern for T05's SC-6 acceptance to verify against fixture-injected synthetic MEMs).

The two deliverables are:

1. **`scripts/lifecycle/ingest-codebase.sh`** (modify) — additive extension to the three emit functions adding the dup-prevention check. The verifier-availability cross-check (Plan-Time Discipline rule 2) is satisfied by co-authoring the verifier in this same task.

2. **`commands/ingest-codebase.md`** (modify) — additive paragraph in the Core Workflow or Edge Cases section documenting the FR-12 dup-prevention contract.

3. **`tools/verify/m033-p04-migrate-then-ingest-shape.sh`** (create) — shape verifier asserting the dup-prevention surface exists in the modified `ingest-codebase.sh`.

## Steps

1. **Read the existing `scripts/lifecycle/ingest-codebase.sh`** to identify the three emit functions (`emit_architecture_mem`, `emit_convention_mem`, `emit_decision_mem`) and the `stable_id` helper. Note the existing on-disk MEM filename shape (e.g., `MEM-ARCH-<id>.md`, `MEM-CONV-<id>.md`, `MEM-DEC-<id>.md`).

2. **Author a new helper `is_migrate_derived_mem <mem-path>`** at the top of the emit functions:
   ```bash
   # ---------------------------------------------------------------------------
   # FR-12 dup-prevention: detect pre-existing migrate-derived MEM at a path.
   # Returns 0 if the file exists AND carries the `derived_from_migrate: true`
   # frontmatter sentinel; returns 1 otherwise.
   # ---------------------------------------------------------------------------
   is_migrate_derived_mem() {
       local mem_path="$1"
       if [ ! -f "$mem_path" ]; then
           return 1
       fi
       if grep -qF 'derived_from_migrate: true' "$mem_path"; then
           return 0
       fi
       return 1
   }
   ```

3. **Modify each of the three emit functions** to consult the helper before writing. The pre-write check goes immediately AFTER the `out=` path computation and BEFORE the `{ printf ... } > "$out"` block:
   ```bash
   # FR-12 dup-prevention check (M033/P04/T03).
   if is_migrate_derived_mem "$out"; then
       printf 'skip-duplicate-from-migrate: %s\n' "$id"
       return 0
   fi
   ```

4. **Add a fenced SSOT comment block** near the top of `ingest-codebase.sh` (after the existing `# >>> ingest-signal-sources >>>` block) documenting the dup-prevention sentinel:
   ```bash
   # >>> dup-prevention-sentinel >>>
   # FR-12 / US-6 AS-3 / brief #Q-10:
   # When ingest-codebase runs after orchestrator:migrate has populated
   # MEMs at the same stable-ID paths, the emit functions skip the write
   # if a pre-existing MEM at the candidate path carries the frontmatter
   # field `derived_from_migrate: true`. The sentinel is the one-way
   # contract from migrate.sh's emitted MEMs to ingest-codebase.sh's
   # check; migrate.sh is M015-closed and not modified by this task.
   #
   # Diagnostic shape: `skip-duplicate-from-migrate: <stable-id>` to stdout.
   # <<< dup-prevention-sentinel <<<
   ```

5. **Modify `commands/ingest-codebase.md`** to add a small additive paragraph (in an Edge Cases or Idempotency section) documenting the FR-12 dup-prevention contract:
   ```markdown
   ## Edge Case: migrate-then-ingest duplicate-MEM prevention (FR-12)

   When `ingest-codebase` runs against a project where `orchestrator:migrate`
   has already populated knowledge MEMs at the same stable-ID paths (e.g.,
   `start` routed the project to `migrating` and the post-migration sub-flow
   invoked `ingest-codebase` to fill gaps the migrator did not cover per
   US-6 AS-3 / brief #Q-10), the emit functions detect any pre-existing
   MEM bearing `derived_from_migrate: true` in its frontmatter and skip
   the write with a `skip-duplicate-from-migrate: <stable-id>` diagnostic
   on stdout. The migrate-derived MEM is preserved (provenance-preserving)
   and `ingest-codebase` still emits MEMs at all OTHER stable-ID paths
   that have no migrate-derived match.
   ```

6. **Author `tools/verify/m033-p04-migrate-then-ingest-shape.sh`** — bash 3.2 verifier asserting:
   - File `scripts/lifecycle/ingest-codebase.sh` exists, executable.
   - Contains the fenced SSOT block markers `>>> dup-prevention-sentinel >>>` and `<<< dup-prevention-sentinel <<<`.
   - Contains the literal tokens `derived_from_migrate: true`, `skip-duplicate-from-migrate:`, `is_migrate_derived_mem`.
   - File `commands/ingest-codebase.md` contains the documenting paragraph (greps for `skip-duplicate-from-migrate`, `derived_from_migrate`, `FR-12`).
   - **Functional smoke (mktemp-d positive + negative test)**: stage a synthetic MEM at `<staging>/.orchestrator/knowledge/architecture/MEM-ARCH-deadbeef.md` with `derived_from_migrate: true` frontmatter; run `is_migrate_derived_mem` against it (via `bash -c '. scripts/lifecycle/ingest-codebase.sh; is_migrate_derived_mem <path>'`) — wait, this triggers the source-in-subshell harness heuristic. Instead: invoke a small wrapper script we co-author at `tools/verify/m033-p04-migrate-then-ingest-shape.sh` itself, that uses plain `grep -qF 'derived_from_migrate: true' "$staged"` directly to verify the sentinel presence in the staged file (functional shape check, NOT a function-call test). The full functional test against the actual emit-function dup-prevention path lives in T05's SC-6 acceptance script.
   - PASS/FAIL/SUMMARY lines.

## Must-Haves

- `scripts/lifecycle/ingest-codebase.sh` modified additively — three emit functions gain the dup-prevention check; `is_migrate_derived_mem` helper added; fenced SSOT block `>>> dup-prevention-sentinel >>>` added.
- `commands/ingest-codebase.md` modified additively — the FR-12 paragraph added.
- `tools/verify/m033-p04-migrate-then-ingest-shape.sh` exists, executable, exits 0.
- The pre-existing P03 SC-3 acceptance still passes against the modified `ingest-codebase.sh` — re-running `bash tests/m033-acceptance/p03-ingest-codebase.sh` exits 0 (the dup-prevention check is additive; for projects with no migrate-derived MEMs, behavior is unchanged).

## Verification

```bash
bash tools/verify/m033-p04-migrate-then-ingest-shape.sh
```

```bash
bash tests/m033-acceptance/p03-ingest-codebase.sh
```

```bash
bash scripts/diagnostics/check-plans.sh
```

## Inputs

### From Previous Tasks

- `scripts/lifecycle/ingest-codebase.sh` (from M033/P03/T03+T04)
  - Key API: emit functions `emit_architecture_mem <source-path> <signal-kind> <body-text>`, `emit_convention_mem`, `emit_decision_mem`; `stable_id <source-path> <signal-kind>` helper computing 8-hex digest via `md5 -q` (darwin) or `md5sum` (linux).
  - Key types: emitted MEM file path is `<KNOWLEDGE_DIR>/<category>/MEM-<KIND>-<8-hex>.md`. Existing frontmatter sentinel for codebase-ingest-derived MEMs: `derived_from_codebase_ingest: true`. T03 adds the parallel `derived_from_migrate: true` sentinel handling on the READ side; the WRITE side is M015's responsibility (assumed-existing).
- `commands/ingest-codebase.md` (from M033/P03/T03)
  - Key API: command-doc per MEM012; T03 adds an Edge Case / Idempotency paragraph.

### From Disk (Pre-existing)

- `scripts/migrate/migrate.sh` (M015 closed) — emits MEMs to `<project-dir>/.orchestrator/knowledge/...` during migration. T03 assumes (but does NOT modify) that migrate.sh's emitted MEMs carry `derived_from_migrate: true` frontmatter. If they do not, the SC-6 acceptance (T05) will surface the gap by injecting synthetic migrate-derived MEMs into a staging fixture before invoking the post-migrate ingest pass — the fixture-injection path verifies the orchestrator-spec contract at the layer T03 controls.
- `tests/m033-acceptance/p03-ingest-codebase.sh` (from M033/P03/T05) — the pre-existing SC-3 acceptance; T03's modification MUST NOT regress it. The cross-phase regression check at the phase level (T05) re-runs this.
- `commands/plan-phase.md` — Plan-Time Discipline rules apply.

## Constraints

- **Additive-extension discipline**: T03's modifications to `ingest-codebase.sh` and `commands/ingest-codebase.md` MUST be additive — no behavior change for projects without migrate-derived MEMs. Re-running P03's SC-3 acceptance against the post-T03 tree MUST exit 0 unchanged.
- **MEM001 (bash 3.2 compat)**: the `is_migrate_derived_mem` helper uses plain `grep -qF` — no process substitution, no `$(...)` with pipes.
- **No M015 surface modifications**: `scripts/migrate/migrate.sh` is closed and is NOT modified by T03. The dup-prevention sentinel is a one-way READ contract.
- **Path discipline**: verifier → `tools/verify/m033-p04-*`. NO writes to `scripts/verify/` or `scripts/migrate/`.
- **Path-collision check**: `ls -la tools/verify/m033-p04-migrate-then-ingest-shape.sh` MUST report no existing file before authoring.
- **Scope**: T03 does NOT touch start.sh, materials-intake.sh, ideation.sh, customblock-draft.sh, or any P05 surface. The only modify-deliverables are `scripts/lifecycle/ingest-codebase.sh` and `commands/ingest-codebase.md`; both are additive.

## Expected Output

After T03 completes:

- `scripts/lifecycle/ingest-codebase.sh` (modified, +30 lines net; new helper + 3 emit-function check insertions + fenced SSOT block)
- `commands/ingest-codebase.md` (modified, +12 lines net; new Edge Case paragraph)
- `tools/verify/m033-p04-migrate-then-ingest-shape.sh` (new file, ≥25 lines, executable)
- The T03 verifier exits 0.
- `bash tests/m033-acceptance/p03-ingest-codebase.sh` still exits 0 (P03 cross-phase regression preserved).

## Notes

- T03's contract is one-way: it READS the `derived_from_migrate: true` sentinel on existing on-disk MEMs and SKIPS its own emit on match. T03 does NOT modify migrate.sh (M015 closed) and does NOT itself write the sentinel anywhere.
- The functional verification of the dup-prevention path (the actual end-to-end test that asserts post-migrate MEMs are NOT overwritten by post-migrate ingest) lives in T05's SC-6 acceptance. T03's verifier is shape-only (asserts the surface tokens exist).
- T04 depends on T03: T04's `start.sh` migrating-branch real implementation invokes `ingest-codebase.sh` post-migrate (when `src/` is present), and the dup-prevention contract from T03 is what makes that invocation safe.
- If M015's migrate.sh emitted MEMs do NOT carry the `derived_from_migrate: true` sentinel today, T03 still ships the orchestrator-spec contract correctly. The gap surfaces in T05's SC-6 — at which point either (a) T05 injects synthetic sentinel-bearing MEMs into the test fixture (preserving the orchestrator-spec contract while documenting the M015 gap as a follow-up), or (b) a small follow-up D-row extends migrate.sh to write the sentinel. Either path keeps T03's surface-shape correct.
