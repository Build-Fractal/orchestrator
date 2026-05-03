---
schema_version: "1.0"
type: phase-plan
phase: "P04"
milestone: "M036"
goal: "Ingest layer — promote extraction outputs (Tier 0/1/2) into knowledge/reference/<cat>/REF-*.md chunks via a classifier-validated, idempotent reference-ingest command, with rebuild-index.sh recognizing REF-* basenames."
demo_sentence: "Operator runs `bash scripts/knowledge/ingest-reference.sh --reference-root knowledge/reference/`; the command walks the populated tree, validates every chunk's category + tier + required-frontmatter fields against the M036 SSOT, emits CREATED:/SKIPPED: lines, and rebuilds KNOWLEDGE-INDEX.md so REF-* chunks participate in graph traversal."
risk: "medium"
depends_on: ["P02", "P03"]
---

# Phase P04 — Ingest Layer (promote extraction outputs to chunks + classifier)

## Phase Summary

P02 + P03 land the **extraction** path: `scripts/knowledge/extract-reference.sh` reads an `extract-manifest.yaml`, executes Tier 0 (manifest + binary preservation + summary) + Tier 1 (deterministic shell adapter via `registry.tsv`) + Tier 2 (LLM-driven structured Markdown gated by conversus fidelity), and writes per-doc chunk artifacts into `knowledge/reference/<category>/`:

- `REF-<category>-<cite_id>.md` — Tier 0 chunk (frontmatter + summary body)
- `REF-<category>-<cite_id>.text.md` — Tier 1 plain-text floor (when tier ≥ 1)
- `REF-<category>-<cite_id>.structured.md` — Tier 2 PASS-promoted structured Markdown (when tier=2 and verdict=PASS)

P04 closes the loop: the **ingest layer** is the operator-facing command that consumes those extraction outputs (or any pre-populated `knowledge/reference/<category>/` tree) and promotes them into the orchestrator's knowledge graph by:

1. **Walking the reference tree** — discover every `REF-*.md` chunk under `knowledge/reference/<category>/` (text/structured siblings are extraction artifacts, not graph entries — they are scoped by the Tier 0 chunk's frontmatter and reachable via the chunk's `text_file:` / `structured_file:` pointers, not via direct indexing).
2. **Classifying** — via the new `classify-reference.sh` helper that wraps `tools/verify/lib/p00-validate-chunk-frontmatter.sh` (P00 deliverable, already on disk) plus FR-2 required-field presence checks (`source`, `published`, `version`, `cite_id`, `topic_tags`, `applies_to_field`). Files outside the closed taxonomy or missing required fields are rejected with a per-file error; valid sibling files in the same pass continue (partial-success ingest matching the spec-chunk classifier's tolerance).
3. **Gating Tier 2 BLOCK** — chunks whose Tier 0 frontmatter declares `tier_2_verdict: "BLOCK"` (P03 retention surface) are surfaced as `BLOCKED:` advisories at ingest time and excluded from the chunk store promotion (FR-18 invariant: BLOCK-verdict chunks have a Tier 0 entry on disk but their structured-md output is NOT promoted; ingest must not retroactively promote them).
4. **Idempotency** — re-running ingest on an unchanged tree produces zero modifications (CON-4). The chunks themselves are already on disk from extract; ingest's role is validation + index-rebuild + per-file `CREATED:`/`SKIPPED:` accounting.
5. **Index rebuild** — invokes `scripts/knowledge/rebuild-index.sh` once at the end to refresh `KNOWLEDGE-INDEX.md` so REF-* chunks participate in graph traversal (P05 already extended `rebuild-index.sh` to insert `cites` / `derived_from` / `applies_to_field` edge rows from frontmatter; P04's contribution is to extend the file-discovery glob's basename filter from `MEM*|SPEC-*` to `MEM*|SPEC-*|REF-*` so REF chunks are scanned at all).

The fixture corpus `tests/fixtures/m036-p04-reference-corpus/` mirrors the four-category taxonomy: 2 cms-rule + 2 training-material + 1 glossary + 1 regulatory-doc = 6 hand-authored REF chunks (text-only, no binaries — CON-3 deterministic CI). The acceptance harness `tests/test-reference-ingest-fixture.sh` drives ingest against the fixture in a `mktemp -d` workspace and emits `BATTERY: pass=N fail=N skip=N` (matching the M036/P02 + M036/P03 harness pattern).

## Cross-Task Ordering Disclosure (M036-canonical convention from P02/P03)

P04 follows the M036-canonical cross-task ordering pattern (see M036/P02 + M036/P03 SUMMARYs):

- **T02 → T01 cross-task ordering**: T02's `m036-p04-rebuild-index-recognizes-ref.sh` exercises a property (REF-* basename in rebuild-index's discovery glob) that depends on T01's fixture corpus being on disk. T02 authors the verifier alongside the rebuild-index edit; first-fail-retry handles the green-up at T01 close. (No actual ordering issue here — T01 lands first; documented for symmetry with the pattern.)
- **T03 → T01 + T02 cross-task ordering**: T03's `m036-p04-tier-2-block-not-promoted.sh` exercises a property that needs T02's driver to honor `tier_2_verdict: BLOCK` AND T01's fixture corpus to include a BLOCK-verdict fixture chunk. The verifier is authored at T03 alongside the integration logic; goes green retroactively under auto-loop's first-fail-retry. (Same shape as M036/P02/T02 size-cap-external-pointer.sh and M036/P03/T03 four-fixture green-flip.)
- **T04 → T01–T03 cross-task ordering**: T04's SC-1+SC-2 acceptance harness drives the full driver chain end-to-end and depends on every prior task's deliverable being on disk. Standard M036 acceptance-harness shape — third instance of the pattern.

The auto-loop's DONE_WITH_CONCERNS handling per US3 AS6 carries the loop forward in each case; no manual intervention required.

## Plan-Time Discipline Verification

Per `commands/plan-phase.md` Plan-Time Discipline:

1. **Prerequisite-existence verification** — all `Prerequisites:` paths in the task plans below were `[ -f ... ]`-checked at plan-authoring time:
   - `scripts/knowledge/extract-reference.sh` (P02 deliverable) — present
   - `scripts/knowledge/rebuild-index.sh` (M011 deliverable, P05-extended) — present
   - `tools/verify/lib/p00-validate-chunk-frontmatter.sh` (P00 T03 deliverable) — present
   - `references/reference-taxonomy.md` (P00 T01 deliverable) — present
   - `references/reference-frontmatter-contract.md` (P00 T01 deliverable) — present
   - `references/reference-source-types.yaml` (P00 deliverable) — present
   - `scripts/dispatch/adapters/format/registry.tsv` (P00 deliverable) — present
   - `tools/verify/m036-p02-phase-suite.sh` (P02 deliverable, regression baseline) — present
   - `tools/verify/m036-p03-phase-suite.sh` (P03 deliverable, regression baseline) — present
   - `tools/verify/m036-p05-phase-suite.sh` (P05 deliverable, regression baseline) — present

2. **Verifier-availability cross-check** — every `## Verification` command resolves either to a script authored within its own task's `## Steps` (co-authored alongside the deliverable it tests) OR to a pre-existing on-disk script. No cross-task forward references except the M036-canonical green-flip pattern documented above and explicitly scheduled within the task.

3. **Classifier-shape pre-validation** — all proposed `Check:` commands are single-script-file invocations (`bash tools/verify/m036-p04-<slug>.sh`) which classify clean under `scripts/verify/lib/shape-classifier.sh::classify_command` (no compound chains, no $() with pipes, no process substitution, no plain subshells). Internal pipelines inside the verifier scripts are not surfaced to the classifier per AD-19.

4. **`run-probe.sh` scope discipline** — all verifier invocations are direct `bash tools/verify/<...>.sh` form; no `run-probe.sh` wrappers (the verifiers are repo-resident, not staged probes).

5. **Real-DB verification** — N/A (P04 does not introduce SQL reads or DB schema migrations; the SQLite KNOWLEDGE-INDEX edge-insertion path was extended by P05 and is already covered by `m036-p05-rebuild-emits-new-edges.sh`).

6. **Path-collision check** — every `create` deliverable was `ls`-checked at plan-authoring time:
   - `scripts/knowledge/ingest-reference.sh` — does NOT exist
   - `scripts/knowledge/classify-reference.sh` — does NOT exist
   - `commands/ingest-reference.md` — does NOT exist
   - `tests/test-reference-ingest-fixture.sh` — does NOT exist
   - `tests/fixtures/m036-p04-reference-corpus/` — does NOT exist
   - `tools/verify/m036-p04-*.sh` — none exist (no collision against any prior milestone's slugged verifier)

   No collisions. All deliverable paths free.

## Demo

```bash
# After P02/P03 have populated knowledge/reference/<cat>/ via extract-reference.sh,
# OR using the P04 hand-authored fixture corpus:

bash scripts/knowledge/ingest-reference.sh \
  --reference-root tests/fixtures/m036-p04-reference-corpus

# Expected stdout:
#   CREATED: REF-cms-rule-fixture-01      category=cms-rule         tier=2
#   CREATED: REF-cms-rule-fixture-02      category=cms-rule         tier=2
#   CREATED: REF-training-material-fixture-01  category=training-material tier=2
#   CREATED: REF-training-material-fixture-02  category=training-material tier=2
#   CREATED: REF-glossary-fixture-01      category=glossary         tier=2
#   CREATED: REF-regulatory-doc-fixture-01 category=regulatory-doc  tier=1
#   SUMMARY: ingest-reference.sh created=6 skipped=0 rejected=0 blocked=0

# Index rebuild side-effect: KNOWLEDGE-INDEX.md now lists 6 REF-* entries.

# Re-run on unchanged tree (idempotency):
bash scripts/knowledge/ingest-reference.sh \
  --reference-root tests/fixtures/m036-p04-reference-corpus
# Expected: every chunk emits SKIPPED: ... reason=unchanged-content-hash
# git status: clean (no modifications to chunks or index).

# A chunk with tier_2_verdict: BLOCK frontmatter:
# Expected: BLOCKED: REF-<cat>-<id> reason=tier-2-fidelity-gate (no CREATED:)
```

## Must-Haves

### Truths

<!-- All Check: lines are bash <single-script-file> per AD-19. Verifiers under tools/verify/ (project-owned, milestone-prefixed slug per the post-M031 contract). -->

- `scripts/knowledge/ingest-reference.sh` exists, is executable, parses `--reference-root <path>`, and walks `<path>/<category>/REF-*.md` files for ingestion.
  - Check: `bash tools/verify/m036-p04-driver-shape.sh`

- `scripts/knowledge/classify-reference.sh` exists, is executable, and exposes pure helper functions (`classify_reference_file`, `classify_reference_required_fields`) that source `tools/verify/lib/p00-validate-chunk-frontmatter.sh` and add the FR-2 required-field presence check.
  - Check: `bash tools/verify/m036-p04-classifier-shape.sh`

- A fixture chunk whose `category:` is outside the M036 taxonomy is rejected with a per-file error; valid sibling chunks in the same pass continue to be processed (partial-success ingest, FR-1).
  - Check: `bash tools/verify/m036-p04-classifier-rejects-unknown.sh`

- A fixture chunk missing a required frontmatter field (e.g., `source:`) is rejected with a per-file error naming the missing field (FR-2).
  - Check: `bash tools/verify/m036-p04-classifier-rejects-missing-required.sh`

- A fixture chunk whose Tier 0 frontmatter declares `tier_2_verdict: "BLOCK"` emits `BLOCKED: <chunk_id> reason=tier-2-fidelity-gate` on stdout and is **NOT** promoted (no `CREATED:` line for that chunk) — FR-18 invariant.
  - Check: `bash tools/verify/m036-p04-tier-2-block-not-promoted.sh`

- `scripts/knowledge/rebuild-index.sh`'s file-basename filter is extended additively from `MEM*|SPEC-*` to `MEM*|SPEC-*|REF-*` so reference chunks participate in the index rebuild (additive — does not change spec-chunk schema, CON-5 preserved).
  - Check: `bash tools/verify/m036-p04-rebuild-index-recognizes-ref.sh`

- Re-running ingest on an unchanged fixture corpus produces zero modifications (CON-4 idempotency invariant via content_hash gate).
  - Check: `bash tools/verify/m036-p04-idempotency.sh`

- `commands/ingest-reference.md` exists with the M036/P02-canonical command-doc structure (Prerequisites + Inputs + Output + Idempotency + Error Handling + Referenced Scripts sections); declares the `CREATED:`/`SKIPPED:`/`REJECTED:`/`BLOCKED:`/`SUMMARY:` stdout protocol; documents `--reference-root` and `--no-index-rebuild` flags.
  - Check: `bash tools/verify/m036-p04-command-shape.sh`

- The fixture corpus at `tests/fixtures/m036-p04-reference-corpus/` exists with 6 valid REF chunks across the four taxonomy categories + 1 BLOCK-verdict fixture + 1 missing-field fixture + 1 unknown-category fixture (for the rejection-path verifiers) under `_negative/` subdirectories that the driver does NOT auto-walk.
  - Check: `bash tools/verify/m036-p04-fixture-corpus-shape.sh`

- The SC-1 + SC-2 acceptance harness `tests/test-reference-ingest-fixture.sh` drives the driver end-to-end against the fixture corpus in a `mktemp -d` workspace, asserts the SC-1 chunk-count + index-listing properties and the SC-2 frontmatter-preservation properties, and emits `BATTERY: pass=N fail=N skip=N` as its last stdout line; exit 0 iff `fail=0`.
  - Check: `bash tools/verify/m036-p04-test-harness.sh`

- The SC-1+SC-2 acceptance harness exits 0 on a clean run (strict pass-rate gate companion to the permissive harness-shape verifier above; pattern from M036/P03).
  - Check: `bash tools/verify/m036-p04-acceptance-harness-passes.sh`

- The P02 phase-suite aggregator continues to report `pass=15 fail=0` after P04's edits to `rebuild-index.sh` (regression guard — P04's basename-filter extension must not perturb the existing extract-reference.sh path, which P02 covers).
  - Check: `bash tools/verify/m036-p04-p02-regression-pass.sh`

- The P05 phase-suite aggregator continues to report `pass=8 fail=0` after P04's edits to `rebuild-index.sh` (regression guard — P05's edge-insertion paths must remain green; P04's edit is purely the basename filter).
  - Check: `bash tools/verify/m036-p04-p05-regression-pass.sh`

- The P04 phase-suite aggregator runs all 13 P04 sub-gates with `pass=13 fail=0`.
  - Check: `bash tools/verify/m036-p04-phase-suite.sh`

### Artifacts

- `scripts/knowledge/ingest-reference.sh` (min 100 lines, contains "CREATED:")
- `scripts/knowledge/classify-reference.sh` (min 50 lines, contains "classify_reference_file")
- `commands/ingest-reference.md` (min 60 lines, contains "ingest-reference.sh")
- `tests/fixtures/m036-p04-reference-corpus/cms-rule/REF-cms-rule-fixture-01.md` (min 12 lines, contains "category: \"cms-rule\"")
- `tests/fixtures/m036-p04-reference-corpus/glossary/REF-glossary-fixture-01.md` (min 12 lines, contains "cite_id:")
- `tests/fixtures/m036-p04-reference-corpus/_negative/unknown-category/REF-blog-post-fixture.md` (min 8 lines, contains "category: \"blog-post\"")
- `tests/fixtures/m036-p04-reference-corpus/_negative/missing-source/REF-cms-rule-no-source.md` (min 6 lines, contains "cite_id:")
- `tests/fixtures/m036-p04-reference-corpus/_negative/tier-2-block/REF-cms-rule-blocked.md` (min 10 lines, contains "tier_2_verdict: \"BLOCK\"")
- `tests/test-reference-ingest-fixture.sh` (min 100 lines, contains "BATTERY:")
- `tools/verify/m036-p04-phase-suite.sh` (min 30 lines, contains "SUMMARY: m036-p04-phase-suite.sh")
- `scripts/knowledge/rebuild-index.sh` (modify — extend basename `case` from `MEM*|SPEC-*` to `MEM*|SPEC-*|REF-*`; preserve all other behavior)

### Key Links

- `scripts/knowledge/ingest-reference.sh` → `scripts/knowledge/classify-reference.sh` (driver sources classifier helper)
- `scripts/knowledge/classify-reference.sh` → `tools/verify/lib/p00-validate-chunk-frontmatter.sh` (classifier delegates taxonomy + tier validation)
- `scripts/knowledge/ingest-reference.sh` → `scripts/knowledge/rebuild-index.sh` (driver invokes index rebuild at end)
- `scripts/knowledge/ingest-reference.sh` → `references/reference-frontmatter-contract.md` (driver doc points operators at the SSOT for required fields)
- `commands/ingest-reference.md` → `scripts/knowledge/ingest-reference.sh` (command doc references its own driver per MEM012 Referenced Scripts section)
- `tests/test-reference-ingest-fixture.sh` → `scripts/knowledge/ingest-reference.sh` (harness drives the driver)

## Tasks

### T01: Reference fixture corpus + classifier helper + classifier shape verifiers

Authors the fixture corpus at `tests/fixtures/m036-p04-reference-corpus/` (6 valid REF chunks across the 4 taxonomy categories + 3 negative-path chunks under `_negative/` subdirectories that the driver explicitly skips). Authors `scripts/knowledge/classify-reference.sh` — a pure helper lib (MEM004) that wraps the existing `tools/verify/lib/p00-validate-chunk-frontmatter.sh` and adds the FR-2 required-field presence check (`source`, `published`, `version`, `cite_id`, `topic_tags`, `applies_to_field`). Authors three shape verifiers: `m036-p04-classifier-shape.sh`, `m036-p04-classifier-rejects-unknown.sh`, `m036-p04-classifier-rejects-missing-required.sh`. Authors the fixture-corpus shape verifier `m036-p04-fixture-corpus-shape.sh`.

### T02: Driver `ingest-reference.sh` + rebuild-index.sh basename-filter extension

Authors `scripts/knowledge/ingest-reference.sh` — Bash 3.2 driver that parses `--reference-root <path>` (default: `knowledge/reference/`) + `--no-index-rebuild` flag, sources `classify-reference.sh`, walks `<root>/<category>/REF-*.md` files, calls the classifier per file (rejects on category-mismatch / missing-required-field with per-file error), checks for `tier_2_verdict: "BLOCK"` (emits `BLOCKED:` and skips promotion per FR-18), gates re-ingest via content_hash idempotency (per-file `SKIPPED:` when frontmatter `content_hash` matches the body hash and the chunk already-on-disk shape is consistent), emits structured `CREATED:` / `SKIPPED:` / `REJECTED:` / `BLOCKED:` / `SUMMARY:` stdout per the M036-canonical contract, and invokes `rebuild-index.sh` once at the end (unless `--no-index-rebuild` passed).

Modifies `scripts/knowledge/rebuild-index.sh` — extends the basename `case` block (currently lines 81-87) from `MEM*|SPEC-*` to `MEM*|SPEC-*|REF-*` so reference chunks are picked up by the file-discovery glob. This is the only edit to rebuild-index.sh; all other behavior preserved byte-identically (CON-5: spec-chunk schema unchanged; P05's existing edge-insertion paths untouched).

Authors three verifiers: `m036-p04-driver-shape.sh` (driver script existence + executable + flag-parsing token-presence checks), `m036-p04-rebuild-index-recognizes-ref.sh` (asserts the modified `case` block accepts `REF-*` basenames), `m036-p04-idempotency.sh` (drives the driver twice in a `mktemp -d` workspace, asserts second run emits SKIPPED for every chunk and produces zero file modifications).

### T03: Tier-2 BLOCK gating + commands/ingest-reference.md + regression verifiers

Adds the FR-18 BLOCK-gating logic to the driver authored in T02: the per-file loop in `ingest-reference.sh` reads the `tier_2_verdict` frontmatter field; when value is `"BLOCK"` the driver emits `BLOCKED: <chunk_id> reason=tier-2-fidelity-gate` on stdout, increments the `blocked` counter, and continues the loop without promoting the chunk into the index-eligible set (the chunk file remains on disk per P03's retention contract; ingest does not delete it, but rebuild-index will skip it because the BLOCK chunks are written into a `_blocked/` subdirectory of `knowledge/reference/<category>/` OR — simpler shape — the driver short-circuits before the rebuild-index call's discovery glob would even reach it; pick the simpler shape: BLOCK chunks already live under `knowledge/reference/<category>/` per P03's promote-or-retain logic which leaves a Tier 0 chunk on disk with `tier_2_verdict: "BLOCK"` AND the `.structured.md` file is NOT written; the rebuild-index call will see the Tier 0 chunk and try to insert edges from it; the BLOCK chunk is flagged at ingest as advisory but its frontmatter is still indexable).

Clarification: per the spec, FR-18 says "PASS promotes the structured Markdown into the chunk store; BLOCK retains the rationale on disk and excludes the structured output from the chunk store". The Tier 0 entry persists. So the BLOCK gating at ingest time is **advisory only** — the driver emits `BLOCKED:` for operator awareness but the Tier 0 chunk IS indexed (it carries the cite_id, topic_tags, applies_to_field that downstream dispatch needs). The `.structured.md` sibling, which P03 already withholds on BLOCK, is what's excluded from the chunk store. Implement accordingly: emit `BLOCKED:` advisory + still emit `CREATED:` for the Tier 0 entry; the verifier `m036-p04-tier-2-block-not-promoted.sh` asserts the advisory line AND that no `.structured.md` sibling is created at ingest (since P03 already chose not to author it).

Authors `commands/ingest-reference.md` — the user-facing command document, ~80 lines, following the M036/P02 `commands/extract.md` shape: Prerequisites + Inputs + Output (declares the CREATED:/SKIPPED:/REJECTED:/BLOCKED:/SUMMARY: stdout protocol) + Idempotency + Error Handling + Referenced Scripts sections per MEM012. Documents `--reference-root` and `--no-index-rebuild` flags.

Authors three verifiers: `m036-p04-command-shape.sh` (token-presence checks against `commands/ingest-reference.md`), `m036-p04-tier-2-block-not-promoted.sh` (drives driver against the BLOCK-verdict fixture, asserts BLOCKED stdout + no `.structured.md` file appears), `m036-p04-p05-regression-pass.sh` (re-runs the P05 phase-suite aggregator to confirm rebuild-index.sh's new basename pattern doesn't perturb P05's edge-insertion verifiers).

### T04: SC-1 + SC-2 acceptance harness + phase-suite aggregator + P02 regression verifier

Authors `tests/test-reference-ingest-fixture.sh` — the SC-1 + SC-2 acceptance harness. Drives `ingest-reference.sh` against the fixture corpus in a `mktemp -d` workspace; asserts SC-1 (N chunks created under expected paths, KNOWLEDGE-INDEX lists all N, exit 0), SC-2 (every emitted chunk's frontmatter `source` / `published` / `version` / `cite_id` / `topic_tags` / `applies_to_field` is byte-identical to the fixture input — measured by `grep`-extracting each field from the on-disk chunk and the fixture, then string-comparing). Emits `BATTERY: pass=N fail=N skip=N` as last stdout line; exit 0 iff `fail=0`. AD-19 single-script-file shape; Bash 3.2.

Authors `tools/verify/m036-p04-test-harness.sh` (permissive harness-shape verifier — `rc<=1` permissive since `rc=1` is fail-mode-but-still-emitted-BATTERY) and `tools/verify/m036-p04-acceptance-harness-passes.sh` (strict pass-rate gate — asserts harness exits 0). Pattern from M036/P03/T04.

Authors `tools/verify/m036-p04-p02-regression-pass.sh` — re-runs the M036/P02 phase-suite aggregator and asserts `pass=15 fail=0` (regression guard for P02's extract-reference.sh path, which is independent of P04's ingest layer but shares the rebuild-index.sh discovery glob).

Authors `tools/verify/m036-p04-phase-suite.sh` — 13-gate aggregator wiring all P04 sub-gates. Patterned after `tools/verify/m036-p03-phase-suite.sh` and `tools/verify/m036-p02-phase-suite.sh`: `set -eu`, `run` helper inspects exit code only, emits `SUMMARY: m036-p04-phase-suite.sh pass=N fail=N`, exits 0 iff `fail=0`.

## Task Dependencies

```
T01 → T02 → T03 → T04
```

T01 (fixture corpus + classifier helper) is foundational — T02's driver sources the classifier; T02's idempotency verifier consumes the fixture corpus. T03 (BLOCK gating + command doc + regressions) builds on T02's driver. T04 (acceptance harness + aggregator) depends on every prior task's deliverables.

**Cross-task ordering note (Plan-Time Discipline rule 2)**: T03's `m036-p04-tier-2-block-not-promoted.sh` exercises the BLOCK-verdict fixture under `_negative/tier-2-block/` which T01 lands. T04's harness depends on T01's fixture, T02's driver, and T03's BLOCK-gating logic. Standard M036 cross-task ordering pattern; auto-loop's first-fail-retry handles green-up at the dependent task's close. (This is the FOURTH instance of the M036 cross-task ordering pattern — see M036/P02 size-cap-external-pointer, M036/P03 driver-tier-2-shape T02→T03 flip, M036/P03 four-fixture T03→T04 flip.)

## Verification Ladder

P04 phase-suite aggregator at `tools/verify/m036-p04-phase-suite.sh` wires the following 13 sub-gates:

- **T01 (4)**: `m036-p04-classifier-shape.sh`, `m036-p04-classifier-rejects-unknown.sh`, `m036-p04-classifier-rejects-missing-required.sh`, `m036-p04-fixture-corpus-shape.sh`
- **T02 (3)**: `m036-p04-driver-shape.sh`, `m036-p04-rebuild-index-recognizes-ref.sh`, `m036-p04-idempotency.sh`
- **T03 (3)**: `m036-p04-command-shape.sh`, `m036-p04-tier-2-block-not-promoted.sh`, `m036-p04-p05-regression-pass.sh`
- **T04 (3)**: `m036-p04-test-harness.sh`, `m036-p04-acceptance-harness-passes.sh`, `m036-p04-p02-regression-pass.sh`

The aggregator emits `SUMMARY: m036-p04-phase-suite.sh pass=13 fail=0` on a clean run.

The SC-1 + SC-2 acceptance harness at `tests/test-reference-ingest-fixture.sh` is independent of the aggregator (run separately). It exercises the full ingest end-to-end against the fixture corpus and emits its own `BATTERY: pass=N fail=N skip=N` last-stdout-line.

### BATTERY-line contract for SC-1 + SC-2 acceptance harness

```
BATTERY: pass=<n> fail=<n> skip=<n>
```

- On a healthy bare host, `n_pass + n_fail + n_skip` is >= 12 (6 SC-1 chunk-presence assertions + 6 SC-2 frontmatter-preservation assertions × 6 fields per chunk = 36 field assertions, but most harnesses roll up to one assertion-per-chunk-per-criterion = 6 SC-1 + 6 SC-2 = 12 minimum).
- `skip` covers environmental SKIPs (none expected — fixture is markdown-only, no host-tooling dependency).
- Exit 0 iff `fail=0`, regardless of `skip`.
- Last stdout line MUST match the regex `^BATTERY: pass=[0-9]+ fail=[0-9]+ skip=[0-9]+$` (consumed by `tools/verify/m036-p04-test-harness.sh`).

## Files Likely Touched

- `tests/fixtures/m036-p04-reference-corpus/cms-rule/REF-cms-rule-fixture-01.md` (create)
- `tests/fixtures/m036-p04-reference-corpus/cms-rule/REF-cms-rule-fixture-02.md` (create)
- `tests/fixtures/m036-p04-reference-corpus/training-material/REF-training-material-fixture-01.md` (create)
- `tests/fixtures/m036-p04-reference-corpus/training-material/REF-training-material-fixture-02.md` (create)
- `tests/fixtures/m036-p04-reference-corpus/glossary/REF-glossary-fixture-01.md` (create)
- `tests/fixtures/m036-p04-reference-corpus/regulatory-doc/REF-regulatory-doc-fixture-01.md` (create)
- `tests/fixtures/m036-p04-reference-corpus/_negative/unknown-category/REF-blog-post-fixture.md` (create)
- `tests/fixtures/m036-p04-reference-corpus/_negative/missing-source/REF-cms-rule-no-source.md` (create)
- `tests/fixtures/m036-p04-reference-corpus/_negative/tier-2-block/REF-cms-rule-blocked.md` (create)
- `scripts/knowledge/classify-reference.sh` (create)
- `scripts/knowledge/ingest-reference.sh` (create)
- `scripts/knowledge/rebuild-index.sh` (modify — extend basename `case` glob from `MEM*|SPEC-*` to `MEM*|SPEC-*|REF-*`; all other behavior byte-identical)
- `commands/ingest-reference.md` (create)
- `tests/test-reference-ingest-fixture.sh` (create)
- `tools/verify/m036-p04-classifier-shape.sh` (create)
- `tools/verify/m036-p04-classifier-rejects-unknown.sh` (create)
- `tools/verify/m036-p04-classifier-rejects-missing-required.sh` (create)
- `tools/verify/m036-p04-fixture-corpus-shape.sh` (create)
- `tools/verify/m036-p04-driver-shape.sh` (create)
- `tools/verify/m036-p04-rebuild-index-recognizes-ref.sh` (create)
- `tools/verify/m036-p04-idempotency.sh` (create)
- `tools/verify/m036-p04-command-shape.sh` (create)
- `tools/verify/m036-p04-tier-2-block-not-promoted.sh` (create)
- `tools/verify/m036-p04-p05-regression-pass.sh` (create)
- `tools/verify/m036-p04-test-harness.sh` (create)
- `tools/verify/m036-p04-acceptance-harness-passes.sh` (create)
- `tools/verify/m036-p04-p02-regression-pass.sh` (create)
- `tools/verify/m036-p04-phase-suite.sh` (create)

## Boundary Map

**Produces**:
- `commands/ingest-reference.md` — operator-facing command document.
- `scripts/knowledge/ingest-reference.sh` — driver (Bash 3.2; reads reference-root tree, classifies, indexes).
- `scripts/knowledge/classify-reference.sh` — classifier helper (taxonomy validator + FR-2 required-field check, MEM004 pure-lib).
- Fixture corpus at `tests/fixtures/m036-p04-reference-corpus/` (6 valid + 3 negative-path REF chunks).
- `tests/test-reference-ingest-fixture.sh` — SC-1 + SC-2 acceptance harness.
- 13 sub-gate verifiers under `tools/verify/m036-p04-*` + phase-suite aggregator.
- Additive amendment to `scripts/knowledge/rebuild-index.sh` basename-filter glob (single `case`-block edit; preserves all spec-chunk behavior — CON-5 invariant honored).

**Consumes**:
- P02 manifest contract + extract-reference.sh chunk shape (REF-<cat>-<cite_id>.md frontmatter contract).
- P03 Tier 2 outputs (`tier_2_verdict:` frontmatter discriminator; `.structured.md` sibling promote/retain semantics).
- P00 taxonomy SSOT (`references/reference-taxonomy.md`), frontmatter contract (`references/reference-frontmatter-contract.md`), source-types YAML (`references/reference-source-types.yaml`), adapter registry (`scripts/dispatch/adapters/format/registry.tsv`).
- P00 chunk-frontmatter validator at `tools/verify/lib/p00-validate-chunk-frontmatter.sh` — re-used unmodified.
- Existing `scripts/knowledge/rebuild-index.sh` — modified additively (basename-filter `case` block extended one row); P05's edge-insertion paths preserved byte-identically.
- Existing `knowledge/` directory tree (M011/M020 — `KNOWLEDGE-INDEX.md` mechanics).
