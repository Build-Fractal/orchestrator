---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M033"
name: "commands/ingest-codebase.md + scripts/lifecycle/ingest-codebase.sh deterministic core + 3 stack fixtures (FR-7)"
depends_on: []
---

## Prerequisites

- M033/P02 closed: `scripts/util/jsonl-event-emitter.sh` accepts `ingest_codebase_completed` and `imported_context_loaded` events; `scripts/util/start-state-markers.sh` accepts `ingest-codebase-completed` sub-flow name; `scripts/util/dual-write-runtime-md.sh append <fragment>` is available.
- `scripts/util/json-field.sh` (MEM008) is available for optional jq-fallback parsing.
- `commands/ingest-codebase.md` does NOT yet exist — verified by `[ ! -f commands/ingest-codebase.md ]`.
- `scripts/lifecycle/ingest-codebase.sh` does NOT yet exist — verified by `[ ! -f scripts/lifecycle/ingest-codebase.sh ]`.
- `tests/fixtures/m033-stack-fixture-ts-saas/` does NOT yet exist.
- `tests/fixtures/m033-stack-fixture-py-cli/` does NOT yet exist.
- `tests/fixtures/m033-stack-fixture-rust-library/` does NOT yet exist.
- Spec context: FR-7 — deterministic structural extraction (NOT LLM-augmented per CON-3 / NG-8); produces 5–15 seed MEMs under `<project-dir>/.orchestrator/knowledge/{architecture,conventions,decisions}/` with stable IDs derivable from source paths; idempotent re-runs detect existing seeds and emit `re-ingest` diagnostic. Knowledge-Layer Boundary — write into existing M020 kinds; no new kinds.

## Description

T03 ships the FR-7 deterministic codebase-ingestion command and three byte-deterministic stack fixtures that exercise the ingest signal set. The command-doc lives at `commands/ingest-codebase.md` (canonical MEM012 shape); the driver lives at `scripts/lifecycle/ingest-codebase.sh`. T03 ships the **core deterministic-extraction branch only**; T04 extends the driver in-place with the FR-8 / MIT-005 rich-context import path.

The driver scans a closed signal set (documented inline under a fenced `# >>> ingest-signal-sources >>>` SSOT block) and emits 5–15 seed MEM files using the M020 `MEM###` naming convention. Stable IDs are derived from a deterministic hash of `<source-path>:<signal-kind>` so re-runs produce the same IDs by construction (idempotency by stable ID — no per-run state persistence required).

The three stack fixtures (TS SaaS / Python CLI / Rust library) are byte-deterministic curated trees following the P01 PBJ-fixture precedent (no timestamps, no random tokens). Each fixture's `README-oracle.md` names the expected MEM count + per-category floor so SC-3 can assert against ground truth. The TS SaaS fixture additionally carries `<fixture>/.orchestrator/DECISIONS.md` with two synthetic `DR-` entries that T04's rich-context import path consumes.

**Bash 3.2 compatibility (MEM001):** No `declare -A`, no process substitution, no `$(...)` containing pipes. Stable-ID hashing uses `md5 -q` (darwin) or `md5sum` (linux) detected via `command -v` — not process substitution.

**Deterministic-not-LLM (CON-3 / NG-8):** The verifier asserts no model-routing hooks (no calls to `scripts/dispatch/build-context.sh`, no `claude-code` invocations, no `conversus` calls) in the extraction path. The path is structural-extraction-only — it reads files and writes MEMs; it does NOT generate semantic summaries.

## Steps

1. **Author `commands/ingest-codebase.md`** (≥60 lines) per MEM012 canonical command-doc shape.

   Frontmatter:
   ```yaml
   ---
   description: "Use when seeding the project knowledge graph from an existing codebase via deterministic structural extraction. Produces 5-15 seed MEMs across architecture/conventions/decisions categories."
   ---
   ```

   Body sections (in order):
   - `# orchestrator:ingest-codebase` title.
   - `## Prerequisites / State Check` — `init-project.sh` has run; `<project-dir>/.orchestrator/` exists.
   - `## Core Workflow` — numbered: signal-source scan; deterministic stable-ID derivation; per-category MEM emission (architecture / conventions / decisions); rich-context import-path branch detection (T04 deliverable); re-ingest detection; marker write; event emission.
   - `## Output` — 5–15 MEM files under `<project-dir>/.orchestrator/knowledge/{architecture,conventions,decisions}/`; optional `<current-milestone>-CONTEXT.md` or `_imported-context/_imported-context.md` (rich-context branch); `<project-dir>/.orchestrator/start-state/ingest-codebase-completed.complete` marker; one `ingest_codebase_completed` JSONL record (and optionally one `imported_context_loaded` record); one FR-21 dual-write fragment.
   - `## Idempotency` — re-runs detect existing seed MEMs by stable ID and emit `re-ingest: <N> existing entries detected, no changes` diagnostic; exit 0.
   - `## Determinism (CON-3 / NG-8)` — structural extraction only; no LLM augmentation; deferred to M033.5 per `#Q-3`.
   - `## Imported Context Sentinel (#Q-11)` — when no active milestone is configured, the rich-context import path emits to `_imported-context/_imported-context.md` per `references/imported-context-sentinel.md`.
   - `## Referenced Scripts` — `scripts/lifecycle/ingest-codebase.sh`, `scripts/util/jsonl-event-emitter.sh`, `scripts/util/start-state-markers.sh`, `references/imported-context-sentinel.md` (T04 deliverable).

   Load-bearing tokens: `orchestrator:ingest-codebase`, `FR-7`, `FR-8`, `ingest-codebase.sh`, `deterministic`, `_imported-context`, `DR-`, `context_source`, `MEM-DR-`, `#Q-3`, `#Q-11`.

2. **Author `scripts/lifecycle/ingest-codebase.sh`** (≥250 lines, executable, `chmod +x`, bash 3.2 compatible).

   2a. **Header.** Hashbang `#!/usr/bin/env bash`, `set -e -u -o pipefail`, comment block naming the script (FR-7), the spec reference, the deterministic-not-LLM invariant (CON-3 / NG-8), the closed signal-source set, and the bash 3.2 compatibility note. Reserve a comment block under `# >>> rich-context-branch >>>` ... `# <<< rich-context-branch <<<` for T04 to fill.

   2b. **Signal-source SSOT block.** Fenced `# >>> ingest-signal-sources >>>` ... `# <<< ingest-signal-sources <<<` block listing the closed signal set, one per line:

     ```
     top-level-docs:README.md,ARCHITECTURE.md,CONTRIBUTING.md,docs/
     package-manifests:package.json,pyproject.toml,Cargo.toml,go.mod
     directory-structure:src/,lib/,app/
     test-directory:tests/,test/,__tests__/,spec/
     git-log-recent:git log --oneline -50
     prior-tooling:.cursor/,.aider/,.claude/,.specify/,.gsd/,.gsd2/
     ```

   2c. **Argument parsing.** Accept `--project-dir <path>` (default `pwd`), `--yes` (suppresses interactive confirmation prompts).

   2d. **Pre-flight.** Verify `<project-dir>` exists; `mkdir -p <project-dir>/.orchestrator/knowledge/{architecture,conventions,decisions}`. Set `KNOWLEDGE_DIR="<project-dir>/.orchestrator/knowledge"`.

   2e. **Stable-ID helper.** Define `stable_id <source-path> <signal-kind>` that emits a deterministic short hash. Implementation:

     ```bash
     stable_id() {
       local source_path="$1"
       local signal_kind="$2"
       local input="${source_path}:${signal_kind}"
       if command -v md5 >/dev/null 2>&1; then
         echo "$input" | md5 -q | cut -c1-8
       elif command -v md5sum >/dev/null 2>&1; then
         echo "$input" | md5sum | cut -c1-8
       else
         echo "FAIL: no md5 or md5sum available" >&2
         return 2
       fi
     }
     ```

     The `cut -c1-8` produces an 8-char hex digest; collision risk at this scale (5–15 MEMs per project) is negligible. Note: `echo X | md5` is allowed under bash 3.2 (it's a simple pipe, not `$(...)` containing a pipe).

   2f. **Per-category emit functions.** Define three functions, each taking `<source-path>` and emitting one MEM file:

     - `emit_architecture_mem <source-path>` — writes to `<knowledge>/architecture/MEM-ARCH-<id>.md` with frontmatter (`schema_version: "1.0"`, `type: knowledge-mem`, `category: architecture`, `source_path: <source-path>`, `signal_kind: <kind>`, `status: graduated` per MEM031, `derived_from_codebase_ingest: true`) and body summarizing the extracted signal (e.g., directory tree, manifest scripts, test conventions). Intentionally thin (≤30 lines per MEM) — these are seeds, not exhaustive documentation.
     - `emit_convention_mem <source-path>` — writes to `<knowledge>/conventions/MEM-CONV-<id>.md` with the same frontmatter shape.
     - `emit_decision_mem <source-path>` — writes to `<knowledge>/decisions/MEM-DEC-<id>.md` with the same frontmatter shape.

   2g. **Signal scan and dispatch.**
     - Top-level docs (`README.md`, `ARCHITECTURE.md`, etc.) → architecture MEMs (one per detected doc).
     - Package manifests (`package.json` etc.) → conventions MEMs (one per manifest with detected dependencies + scripts).
     - Directory structure (top 2 levels of `src/`) → architecture MEM (one summary).
     - Test directory shape → convention MEM (one summary of detected test framework + path).
     - Recent git log (last 50 commits) → decision MEM (one summary of active areas + commit-message conventions); skipped if no `.git/`.
     - Prior-tooling artifacts → convention MEM (one per detected tool).

     Cap at 15 MEMs total per FR-7 — if signals exceed 15, prioritize: top-level docs > manifests > directory structure > tests > git log > prior tooling. Floor at 5 MEMs (FR-7 minimum) — if signals fall below 5, emit a stdout diagnostic listing what was missing (US-3 AS-5 minimum-viable seed) and continue with whatever signals are available.

   2h. **Re-ingest detection.** Before writing any MEM, scan `<knowledge>/{architecture,conventions,decisions}/MEM-*.md` for files with `derived_from_codebase_ingest: true` in frontmatter. If ≥1 exists AND every MEM about to be written has the same stable ID as an existing file, emit `re-ingest: <N> existing entries detected, no changes` to stdout, emit one `ingest_codebase_completed` JSONL event with `payload: {"action":"re-ingest","existing":<N>}`, and exit 0 (idempotent path per FR-7).

   2i. **Marker write.** `bash scripts/util/start-state-markers.sh write ingest-codebase-completed "<project-dir>"`.

   2j. **JSONL event.** `PROJECT_DIR="<project-dir>" bash scripts/util/jsonl-event-emitter.sh emit ingest_codebase_completed '{"mem_count":<N>,"categories":"architecture,conventions,decisions"}'`.

   2k. **FR-21 dual-write fragment.** `bash scripts/util/dual-write-runtime-md.sh append "036-project-onboarding-experience: orchestrator:ingest-codebase seeded <N> MEMs from existing codebase"`.

   2l. **Rich-context branch reservation.** Reserved fenced block `# >>> rich-context-branch >>>` ... `# <<< rich-context-branch <<<` for T04 to populate. Inside, T03 ships a no-op stub (`true # T04 fills this block`) so the script remains syntactically valid; T04 replaces the stub in-place per the P02 stub-helper-with-stable-name pattern. T03's verifier accepts the no-op stub; T04's verifier asserts the stub is replaced.

3. **Author the three stack fixtures.**

   3a. `tests/fixtures/m033-stack-fixture-ts-saas/`:
   - `package.json` — minimal valid JSON with name `ts-saas-fixture`, scripts (`dev`, `build`, `test`), dependencies (`next`, `react`, `react-dom`), devDependencies (`typescript`, `vitest`).
   - `src/index.ts` — empty/trivial (e.g., `export const hello = () => 'world';`).
   - `src/lib/util.ts` — empty/trivial.
   - `README.md` — 1-2 paragraphs describing the synthetic fixture.
   - `ARCHITECTURE.md` — 1-2 paragraphs on synthetic architecture (e.g., "Next.js app with co-located lib").
   - `tests/index.test.ts` — empty/trivial vitest stub.
   - `.orchestrator/DECISIONS.md` — synthetic file containing two `DR-` entries (`DR-DEMO-001: Use Next.js App Router` and `DR-DEMO-002: Co-locate tests with source`). Each entry has a 1-line title + 2-3-line rationale.
   - `README-oracle.md` — names expected MEM count `8` (within 5–15 range), expected categories `architecture: 3` / `conventions: 3` / `decisions: 2`. The oracle also names the two `DR-` entries `DR-DEMO-001` and `DR-DEMO-002` so SC-3 can verify the rich-context import.

   3b. `tests/fixtures/m033-stack-fixture-py-cli/`:
   - `pyproject.toml` — minimal valid TOML naming `py-cli-fixture`, scripts (`pytest`), dependencies (`click`).
   - `src/cli/__init__.py`, `src/cli/main.py` — trivial CLI scaffold.
   - `README.md` — 1-2 paragraphs.
   - `tests/test_cli.py` — empty/trivial pytest stub.
   - `README-oracle.md` — expected MEM count `5` (minimum), expected categories `architecture: 2` / `conventions: 2` / `decisions: 1`.

   3c. `tests/fixtures/m033-stack-fixture-rust-library/`:
   - `Cargo.toml` — minimal valid TOML naming `rust-library-fixture`, `[lib]` declaration.
   - `src/lib.rs` — trivial lib stub (`pub fn hello() -> &'static str { "world" }`).
   - `README.md` — 1-2 paragraphs.
   - `tests/integration_test.rs` — empty/trivial.
   - `README-oracle.md` — expected MEM count `5` (minimum), expected categories `architecture: 2` / `conventions: 2` / `decisions: 1`.

   All fixtures must be byte-deterministic (no timestamps, no random tokens, no machine-specific paths). Same fixture inputs across machines → same hash inputs → same stable IDs → same MEM filenames.

4. **Author `tools/verify/m033-p03-ingest-codebase-md-shape.sh`** (≥30 lines, executable). Asserts:
   - `commands/ingest-codebase.md` exists.
   - Body contains the load-bearing tokens via `grep -F`: `orchestrator:ingest-codebase`, `FR-7`, `FR-8`, `ingest-codebase.sh`, `deterministic`, `_imported-context`, `DR-`, `context_source`, `MEM-DR-`, `#Q-3`, `#Q-11`.
   - Has a YAML frontmatter `description:` field per MEM012.
   - Emits `PASS:` / `SUMMARY:` lines.

5. **Author `tools/verify/m033-p03-ingest-codebase-sh-shape.sh`** (≥30 lines, executable). Asserts:
   - `scripts/lifecycle/ingest-codebase.sh` exists and is executable.
   - Body contains the load-bearing tokens via `grep -F`: `ingest-signal-sources`, `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `knowledge/architecture`, `knowledge/conventions`, `knowledge/decisions`, `re-ingest`, `ingest_codebase_completed`, `ingest-codebase-completed.complete`, `dual-write-runtime-md.sh`, `036-project-onboarding-experience`.
   - The fenced SSOT block markers `# >>> ingest-signal-sources >>>` and `# <<< ingest-signal-sources <<<` appear.
   - The reserved `# >>> rich-context-branch >>>` block appears (T04 will populate; T03 ships the stub).
   - **Negative grep — deterministic invariant (CON-3 / NG-8):** assert zero matches for `claude-code`, `conversus`, `model_routing` in the script body (no LLM augmentation in the extraction path). The verifier echoes any matches to stderr and fails.
   - **Functional smoke test:** copy `tests/fixtures/m033-stack-fixture-ts-saas/` to `mktemp -d`; run `bash scripts/lifecycle/ingest-codebase.sh --project-dir <staging> --yes`; assert ≥5 and ≤15 MEM files exist under `<staging>/.orchestrator/knowledge/`; assert at least one MEM file in each of the three categories. Cleanup mandatory.
   - **Idempotency smoke test:** re-run the same command against the same staging dir; assert zero new MEMs are written AND `re-ingest` appears on stdout. Cleanup mandatory.
   - Emits `PASS:` / `SUMMARY:` lines.

6. **Author `tools/verify/m033-p03-stack-fixtures-shape.sh`** (≥30 lines, executable). Asserts:
   - `tests/fixtures/m033-stack-fixture-ts-saas/` exists with `package.json`, `src/`, `README.md`, `ARCHITECTURE.md`, `tests/`, `.orchestrator/DECISIONS.md`, `README-oracle.md`.
   - The TS SaaS `.orchestrator/DECISIONS.md` contains `DR-DEMO-001` and `DR-DEMO-002` substrings.
   - `tests/fixtures/m033-stack-fixture-py-cli/` exists with `pyproject.toml`, `src/`, `README.md`, `tests/`, `README-oracle.md`.
   - `tests/fixtures/m033-stack-fixture-rust-library/` exists with `Cargo.toml`, `src/`, `README.md`, `tests/`, `README-oracle.md`.
   - Each fixture's `README-oracle.md` contains `expected MEM count` and `expected categories` substrings.
   - Emits `PASS:` / `SUMMARY:` lines per fixture.

## Must-Haves

This task addresses these P03 phase truths:
- `commands/ingest-codebase.md` exists per MEM012.
- `scripts/lifecycle/ingest-codebase.sh` exists with the FR-7 deterministic-extraction core (rich-context branch reservation only — T04 fills it).
- Three byte-deterministic stack fixtures exist at `tests/fixtures/m033-stack-fixture-{ts-saas,py-cli,rust-library}/`.

This task creates these P03 phase artifacts:
- Command doc: `commands/ingest-codebase.md`.
- Driver: `scripts/lifecycle/ingest-codebase.sh` (deterministic core + rich-context-branch reservation stub).
- Fixtures: `tests/fixtures/m033-stack-fixture-{ts-saas,py-cli,rust-library}/`.
- Verifiers: `tools/verify/m033-p03-{ingest-codebase-md-shape,ingest-codebase-sh-shape,stack-fixtures-shape}.sh`.

## Verification

```bash
bash tools/verify/m033-p03-ingest-codebase-md-shape.sh
bash tools/verify/m033-p03-ingest-codebase-sh-shape.sh
bash tools/verify/m033-p03-stack-fixtures-shape.sh
```

## Inputs

### From Previous Tasks

None. T03 has no intra-phase prerequisites — it is independent of T01 / T02.

### From P02 (Pre-existing)

- `scripts/util/jsonl-event-emitter.sh` — accepts `ingest_codebase_completed` (T03 emits) and `imported_context_loaded` (T04 emits in the rich-context branch).
- `scripts/util/start-state-markers.sh` — accepts `ingest-codebase-completed` sub-flow name in the closed enum.
- `scripts/util/dual-write-runtime-md.sh` — invoked as `append <fragment>` per the FR-21 SSOT.

### From Disk (Pre-existing)

- `scripts/util/json-field.sh` (MEM008) — optional jq fallback for parsing manifest JSON. T03 prefers `grep`/`sed`/`awk` per MEM001.
- M020 knowledge-graph kinds (`pattern | convention | lesson | decision`) — T03's emitted MEMs use the M020 schema; the closed-enum frontmatter `category:` value matches the M020 vocabulary.

## Constraints

- Bash 3.2 compatibility (MEM001) — no `declare -A`, no process substitution, no `$(...)` containing pipes.
- Deterministic structural extraction (CON-3 / NG-8) — no LLM-augmented summaries; no `claude-code` / `conversus` / model-routing invocations in the extraction path. The verifier asserts zero matches for these tokens.
- Stable IDs derived from `<source-path>:<signal-kind>` hash — re-runs produce the same IDs by construction. No per-run state file required for idempotency.
- Per-MEM file size cap of ~30 lines (seed, not documentation). Larger summaries are M033.5 territory per `#Q-3`.
- Fixtures byte-deterministic — no timestamps, no random tokens. Same fixture across machines → same hash inputs → same MEM filenames.
- Cap MEM emission at 15 (FR-7 maximum); floor at the maximum-available-signal count when fewer than 5 are detectable (US-3 AS-5 — minimum-viable seed; emit diagnostic listing what was missing).
- Knowledge-Layer Boundary — write into existing M020 kinds (`architecture`, `conventions`, `decisions`); no new kinds. Note: the orchestrator's own knowledge tree uses (`patterns`, `conventions`, `lessons`, `archive`, `spec`) but the FR-7 spec explicitly names `architecture/conventions/decisions/` for project-local seed MEMs — this is a deliberate FR-7 vocabulary, narrower than the orchestrator's full M020 kind set. T03 honors the FR-7 vocabulary; the broader M020 kinds are not regressed.
- T03 MUST NOT modify any P01 or P02 surface.
- T03 MUST NOT modify the orchestrator's own `knowledge/` tree (the driver writes to project-local paths only).

## Expected Output

After T03 completes:
- `commands/ingest-codebase.md` exists per MEM012.
- `scripts/lifecycle/ingest-codebase.sh` exists, is executable, implements the FR-7 deterministic core, and reserves a fenced block for T04's rich-context branch.
- Three stack fixtures exist with the documented shape and byte-deterministic content.
- All three T03 verifiers exit 0 with `SUMMARY:` lines.
- A summary file at `.orchestrator/milestones/M033/phases/P03/tasks/T03-ingest-codebase-core-SUMMARY.md` documents the deliverables.

## Notes

The path-resolver convention for the FR-8 rich-context import file (`<current-milestone>-CONTEXT.md` vs `_imported-context/_imported-context.md`) is documented in T04, but the SSOT for the convention is `references/imported-context-sentinel.md` — also a T04 deliverable. T03 ships the deterministic-core driver and reserves space for T04; T04 ships the sentinel reference and the rich-context branch implementation in-place.

The `derived_from_codebase_ingest: true` frontmatter field is the load-bearing marker for re-ingest detection. Once a MEM carries that flag, T03's idempotency check skips re-emission. Operators who want to force re-ingest can manually delete the seeded MEMs (or use a future `--force` flag — out of T03 scope; demand-driven follow-up).

The TS SaaS fixture's `README-oracle.md` carries `expected MEM count: 8` to land squarely inside the 5–15 range (FR-7 contract); the Python and Rust fixtures land at the floor `5` to exercise the minimum end of the range. SC-3 (T05 deliverable) asserts ≥5 and ≤15 across all three.

The reserved `# >>> rich-context-branch >>>` block stub uses `true # T04 fills this block` — under `set -e -u -o pipefail` this is a syntactically valid no-op that does not propagate failure. T04 replaces the stub in-place; T04's verifier asserts the stub is replaced.

The `git log --oneline -50` invocation is a single pipe-free invocation — `git log` accepts `--oneline -50` arguments directly, no compound shape required.
