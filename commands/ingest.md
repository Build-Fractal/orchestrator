---
description: "Use when ingesting a markdown spec into the orchestrator's knowledge system. Chunks the spec into spec/story, spec/requirement, spec/acceptance, spec/constraint, spec/nfr, and spec/non-goal entries, then rebuilds the knowledge index so downstream commands (evaluate, roadmap, plan-phase, dispatch) can read spec-chunk metrics and graph edges instead of re-parsing the raw spec."
---

# orchestrator:ingest

Chunk a markdown feature spec into typed knowledge entries so downstream orchestrator commands (`evaluate`, `roadmap`, `plan-phase`, `dispatch`) can drive milestone decomposition from spec-chunk metrics and graph edges rather than re-parsing the raw spec on every invocation. This command is a thin user-facing wrapper around `scripts/knowledge/ingest-spec.sh` that additionally records the spec-slug → milestone mapping into the evaluation file.

Run `orchestrator:ingest` once per spec when you first introduce it to the orchestrator, and re-run it whenever the spec changes. The re-ingest path is idempotent: unchanged chunks are skipped, edited chunks are versioned and superseded, and deleted chunks are marked `REMOVED`.

## Prerequisites

1. **Spec file exists**: A markdown spec file must exist at a readable path. The canonical layout is `specs/<feature-slug>/spec.md`, but any `.md` path is accepted via `--spec-path`.
2. **Extension installed**: The orchestrator scripts at `scripts/knowledge/ingest-spec.sh` and `scripts/knowledge/rebuild-index.sh` must be present in the current project. If either is missing, run the orchestrator installer (see `references/installation.md`).
3. **Knowledge tree initialized**: The `knowledge/` directory must exist at the orchestrator root. `scripts/lifecycle/scaffold.sh` creates this during `orchestrator:evaluate`; this command will not create the tree.

No prior orchestrator state beyond the knowledge tree is required — `orchestrator:ingest` is safe to run before or after `orchestrator:evaluate`. When run before, the spec-slug → milestone mapping is skipped (no milestone exists yet); when run after, the mapping is recorded if `--milestone` is supplied.

## Usage

The canonical invocation shape:

```bash
bash scripts/knowledge/ingest-spec.sh --spec-path <path-to-spec.md> --slug <feature-slug>
```

User-facing flags documented by this command:

- `--spec-path <path>` — required. Absolute or repo-relative path to the markdown spec file. Must exist and be readable.
- `--slug <slug>` — required. Kebab-case feature identifier (for example, `016-autonomous-hardening` or `011-spec-management`). Used as the `scope_tags: "[spec:<slug>]"` value for every chunk emitted from this spec when `--scope-tags` is not supplied. Keep the slug stable across re-ingests — the slug is how the chain-walker identifies previous versions of a chunk.
- `--milestone <M###>` — optional. When supplied, records the spec-slug → milestone mapping in `<milestone-dir>/M###-EVALUATION.md` by appending or updating a `spec_slug: <slug>` line in the evaluation frontmatter. When omitted, no evaluation file edit is performed and the spec is ingested without a milestone association.
- `--review` — optional. Force the fidelity gate ON regardless of the resolved intensity. Promotes `fidelity-gate` into `execute_substeps` even under Quick intensity.
- `--no-review` — optional. Force the fidelity gate OFF regardless of the resolved intensity. Forces `fidelity-gate` into `skip_substeps` even under Standard/Full intensity.
- `--force` — optional. This flag now has two semantically-separate effects, both subsumed under the same flag: (i) the original P06 re-ingest confirmation bypass (allow a re-ingest when prior chunks exist on disk), and (ii) the new P07 BLOCK-verdict bypass (allow the chunker to run even after the conversus fidelity gate returns BLOCK). When `--force` bypasses a BLOCK verdict, an audit-trail `FORCE:` line is appended to the milestone's `.ingest-log.jsonl`.

## Workflow

1. **Validate spec-path**: Confirm the file passed to `--spec-path` exists and is readable. If not, exit with a clear error before any knowledge-tree writes. The underlying `scripts/knowledge/ingest-spec.sh` already performs this check; `orchestrator:ingest` surfaces the error message to the user.

2. **Detect spec shape**: Invoke the shape probe to decide whether the input is already in the spec-kit canonical layout or needs normalization:

   ```bash
   bash scripts/knowledge/detect-spec-shape.sh --spec-path <path>
   ```

   The probe emits `shape=speckit|foreign` plus `reasons=<csv>` to stdout. On `shape=speckit`, skip directly to Step 6 (the chunker) — the input already carries the section vocabulary the chunker expects. On `shape=foreign`, proceed to Step 3 for LLM-driven normalization.

3. **Normalize foreign-shaped input**: For foreign-shaped inputs, invoke the normalizer wrapper which dispatches the normalizer agent through the uniform runtime adapter:

   ```bash
   bash scripts/knowledge/normalize-spec.sh --spec-path <source> --slug <slug>
   ```

   The wrapper resolves the active runtime and dispatches the agent via `scripts/dispatch/dispatch-interface.sh` using `templates/spec-normalizer-prompt.md` as the prompt body. The normalized markdown is written atomically (temp-file-then-rename) to `specs/<slug>/spec.md` so readers never observe a half-written file. Note: the normalized artifact is written BEFORE the fidelity gate so the developer can audit the normalization output even when the gate returns BLOCK.

4. **Resolve ingest-stage policy**: Ask the intensity gate whether the fidelity gate should run for this invocation:

   ```bash
   bash scripts/engine/intensity-gate.sh --stage ingest --intensity-metadata <metadata-path>
   ```

   Parse `execute_substeps=<csv>` to decide whether `fidelity-gate` is in scope. Apply the user-facing overrides: if `--review` was passed on the command line, force `fidelity-gate` into `execute_substeps` regardless of the resolved intensity. If `--no-review` was passed, force `fidelity-gate` into `skip_substeps` regardless. These overrides are applied by this command, not by `intensity-gate.sh` itself (the gate exposes the policy matrix; overrides live at the command layer).

5. **Run fidelity gate (conditional)**: When `fidelity-gate` is in `execute_substeps`, invoke the reusable Conversus tool adapter with the canonical `normalize-fidelity` preset:

   ```bash
   bash scripts/dispatch/adapters/tool/conversus.sh gate normalize-fidelity specs/<slug>/spec.md .orchestrator/milestones/<M>/<P>/gate-result.md
   ```

   Interpret exit codes:
   - `0` = PASS → proceed to Step 6 (the chunker).
   - `0` with a `SKIPPED:` line on stdout (conversus binary missing / external dependency unavailable) → proceed to Step 6 with a warning; graceful degradation per the M011 roadmap (Conversus is an external dependency, not a hard blocker).
   - `2` = BLOCK → stop unless `--force` was passed. When `--force` is present with a BLOCK verdict, record an audit-trail line of the form `FORCE: gate BLOCK bypassed by --force at <iso-8601>` into the milestone's `.ingest-log.jsonl` (or the nearest milestone directory's ingest log) before proceeding to Step 6.
   - `1` = adapter error → stop and surface the adapter's stderr verbatim.

   When `fidelity-gate` is in `skip_substeps` (Quick intensity without `--review`, or `--no-review` explicit), this step is a no-op and the workflow falls through to Step 6.

6. **Invoke `ingest-spec.sh`**: Run the production ingest script:

   ```bash
   bash scripts/knowledge/ingest-spec.sh --spec-path <path> --slug <slug>
   ```

   The script parses the spec, classifies every structural element into one of the six spec chunk categories (`spec/story`, `spec/requirement`, `spec/acceptance`, `spec/constraint`, `spec/nfr`, `spec/non-goal`), decides per-chunk whether to create a new entry, skip an unchanged entry, supersede a changed entry, or mark a removed entry, and writes the results under `knowledge/spec/<category>/SPEC-*.md`.

7. **Capture chunk counts**: Read the `CREATED:`, `SKIPPED:`, `SUPERSEDED:`, `REMOVED:`, and `REVIEW:` prefixed lines from the ingest script's stdout to report a human-readable summary to the user. The summary is informational; the authoritative record of each chunk lives in its detail file.

8. **Record milestone mapping (optional)**: If `--milestone M###` is supplied and `<milestone-dir>/M###-EVALUATION.md` exists, append or update a `spec_slug: <slug>` line in the evaluation frontmatter so downstream commands can resolve the spec from the milestone ID without guessing. If the evaluation file does not yet exist (for example, `orchestrator:ingest` was run before `orchestrator:evaluate`), skip this step and report that the mapping will be recorded on the next evaluate run.

9. **Rebuild the knowledge index**: `ingest-spec.sh` already invokes `scripts/knowledge/rebuild-index.sh` once internally at the end of its run, so the hot `KNOWLEDGE-INDEX.md` artifact is always fresh after a successful ingest. The rebuild is mentioned here so users understand the whole-system effect of a single ingest call.

10. **Report and suggest next command**: Print the CREATED/SKIPPED/SUPERSEDED/REMOVED counts, note any `REVIEW:` lines for the user to audit, and suggest the next orchestrator command. For a brand-new spec, suggest `orchestrator:evaluate`. For a re-ingest with supersessions that affect an existing roadmap, suggest re-running `orchestrator:roadmap` after reviewing the REVIEW lines.

## Re-ingest / Idempotency

Re-running `orchestrator:ingest` on a spec that has already been ingested is fully supported and is the expected workflow when the spec evolves during planning. The P03 re-ingest decision layer guarantees the following behavior:

- `SKIPPED:` is emitted for every chunk whose content (body hash) is unchanged since the previous ingest. No detail file is rewritten; no supersede chain entry is added.
- `SUPERSEDED:` is emitted for every chunk whose content changed. The old detail file's frontmatter gets `superseded_by: SPEC-<cat>-<id>-v<N+1>` populated, and a new versioned detail file is written at the chain tip. The chain is walked before appending, so a chunk that has already been superseded once is extended correctly (v1 → v2 → v3 rather than v1 → v2 twice).
- `REMOVED:` is emitted for every chunk present on disk under the given spec slug that did not appear in this ingest pass. The detail file is annotated with a `removed_at:` timestamp. Versioned successors (`*-v[0-9]*`) are skipped by the REMOVED pass so they do not self-mark when they replace their base.
- `REVIEW:` is emitted for each milestone or phase that scope-tags link to a superseded or removed chunk. These are advisory — downstream phase plans may need revisiting, but `orchestrator:ingest` itself does not modify roadmap or phase artifacts.

Because a casual re-run during draft iteration could inadvertently supersede chunks mid-edit, `orchestrator:ingest` requires `--force` (or an interactive confirmation prompt) when a previous ingest of the same slug is detected on disk. Without `--force`, the command emits a dry-run preview of the decisions it would make (CREATED/SKIPPED/SUPERSEDED/REMOVED counts) and exits without writing, so the user can confirm intent before committing.

This behavior satisfies R012 (idempotent commands): re-running `orchestrator:ingest` with `--force` on an unchanged spec produces a disk state identical to the prior run — every chunk emits `SKIPPED:` and no detail file is touched.

## Error Handling

- **Missing spec file**: If the path passed to `--spec-path` does not exist, exit non-zero with a clear message naming the missing path. No knowledge-tree writes are performed.
- **Unreadable spec file**: If the spec file exists but cannot be read (permission denied), exit non-zero and surface the underlying read error. No partial writes.
- **Missing slug**: If `--slug` is omitted or empty, exit non-zero before invoking `ingest-spec.sh`. The slug is required for scope-tag construction and chain-walking.
- **Ingest script failure**: If `scripts/knowledge/ingest-spec.sh` exits non-zero (parse failure, frontmatter schema violation, rebuild-index failure, or any other internal error), surface the script's stderr verbatim and exit with the same non-zero code. Do not attempt to roll back partial writes — the script's decision layer is idempotent, so re-running after fixing the root cause will converge correctly.
- **Missing milestone directory**: If `--milestone M###` is supplied but `<milestone-dir>/` does not exist, report a warning that the mapping cannot be recorded and continue with the ingest. Do not treat this as a hard error — the ingest itself is still useful without the milestone mapping.
- **Knowledge tree missing**: If `knowledge/` does not exist at the orchestrator root, exit with an installation-error message directing the user to run `orchestrator:evaluate` or the scaffold script first.

### Pre-chunker pipeline errors (P07)

The new pre-chunker pipeline (shape-detect → normalize → fidelity-gate) introduces additional failure modes. All of them stop the pipeline cleanly before any chunks are written so the knowledge tree is never left in a partial state.

- **Shape probe failure**: If `scripts/knowledge/detect-spec-shape.sh` exits non-zero, surface its stderr and stop before any normalization or chunker step. A probe failure almost always indicates a missing or unreadable source file, not a classification problem — both valid classifications (`shape=speckit` and `shape=foreign`) exit 0.
- **Normalizer dispatch failure**: If `scripts/knowledge/normalize-spec.sh` exits non-zero (runtime resolver failed, dispatch interface unreachable, normalizer agent returned an empty or malformed artifact), stop the pipeline and surface the wrapper's stderr verbatim. Do not fall back to chunker-on-raw-input; the chunker's classifier depends on the canonical section vocabulary.
- **Fidelity gate BLOCK without `--force`**: When the conversus adapter returns exit code 2 (BLOCK) and `--force` was not passed on the command line, stop with a non-zero exit and print the `gate-result.md` path so the developer can inspect the BLOCK reasoning before retrying with `--force`. The chunker is not run.
- **Fidelity gate adapter error**: When the conversus adapter returns exit code 1 (adapter error — distinct from BLOCK), stop and surface the adapter's stderr. Do not auto-retry; adapter errors typically indicate a preset misconfiguration or a transient external-tool problem the operator must resolve manually.
- **Conversus binary missing (graceful degradation)**: When `conversus.sh check` reports `available=false`, the `gate` subcommand emits a `SKIPPED:` line and exits 0. Treat this as a pass-through: proceed to the chunker with a warning. Per the M011 roadmap, Conversus is an opt-in external dependency, not a hard prerequisite of the ingest pipeline.
- **Intensity-gate unknown stage**: If `scripts/engine/intensity-gate.sh` rejects `--stage ingest` with a non-zero exit, the installed orchestrator is pre-P07 and the ingest pipeline cannot resolve its policy matrix. Re-run the installer (see `references/installation.md`) or update the extension and retry.

## Reference Files

- `scripts/knowledge/ingest-spec.sh` — the production ingest script this command wraps. Accepts `--spec-path`, `--slug`, and `--scope-tags`. Emits `CREATED:`, `SKIPPED:`, `SUPERSEDED:`, `REMOVED:`, and `REVIEW:` prefixed lines to stdout. Exits 0 on success, 1 on failure. Bash 3.2 compatible.
- `scripts/knowledge/rebuild-index.sh` — rebuilds `KNOWLEDGE-INDEX.md` from every detail file under `knowledge/`. Invoked once internally at the end of every `ingest-spec.sh` run.
- `scripts/state/spec-metrics.sh` — post-ingest verification helper. Emits `spec_chunks_present=true|false` plus seven `key=value` lines (`requirements`, `stories`, `acceptance_criteria`, `constraints`, `non_goals`, `total`, `metrics_source=chunks`). Consumed by `orchestrator:evaluate` and `orchestrator:roadmap` for chunks-first decomposition.
- `scripts/dispatch/scope-filter.sh` — consumes spec chunks via `--category spec/<cat>` and `--graph` flags so dispatch payloads can inject story-graph edges and per-category chunk lists into fresh task contexts.
- `knowledge/spec/` — the destination directory tree where spec chunks land. Layout: `knowledge/spec/<category>/SPEC-<cat>-<id>[-v<N>].md`. Categories: `story`, `requirement`, `acceptance`, `constraint`, `nfr`, `non-goal`.
- `templates/evaluation.md` — the evaluation output template. The optional `spec_slug:` frontmatter field is appended by this command when `--milestone` is supplied.
- `scripts/knowledge/detect-spec-shape.sh` — shape probe for format-agnostic intake. Emits `shape=speckit|foreign` plus `reasons=<csv>` to stdout; exits 0 on either outcome.
- `scripts/knowledge/normalize-spec.sh` — LLM-driven normalizer for foreign-shaped input. Dispatches through `scripts/dispatch/dispatch-interface.sh` using `templates/spec-normalizer-prompt.md`; writes `specs/<slug>/spec.md` atomically.
- `scripts/dispatch/adapters/tool/conversus.sh` — reusable Conversus fidelity-gate adapter. Exposes `check | gate | parse-verdict` subcommands; exit 0 = PASS/SKIPPED, 2 = BLOCK, 1 = adapter error.
- `commands/conversus-gate.md` — the reusable command doc for arbitrary-preset Conversus gating; this command invokes it with the `normalize-fidelity` preset, but M013/M014 will invoke it with their own presets via the same adapter.
- `scripts/engine/intensity-gate.sh` — the intensity gate with the new `ingest` stage. Policy matrix: Quick → `normalize`; Standard/Full → `normalize,fidelity-gate`.
- `templates/spec-normalizer-prompt.md` — the normalizer prompt body. Instructs the agent to preserve every factual claim, requirement, non-goal, constraint, and acceptance criterion from the source; emit the canonical section layout; introduce no new requirements.
- `templates/conversus-presets/normalize-fidelity.yml` — the canonical fidelity-gate preset for source-vs-normalized fidelity checks.
- `templates/gate-result.md` — the gate-result artifact shape emitted by the conversus adapter on each gate invocation.
