---
schema_version: "1.0"
type: phase-plan
phase: "P06"
milestone: "M036"
goal: "Wire content-hash supersede-chain authoring into extract + ingest, emit REVIEW: advisories for cites-edge drift, and lock in idempotency invariants (SC-5/SC-6/SC-13) — the last in-flight M036a phase before milestone-grain validation."
demo_sentence: "Operator runs extract + ingest twice on an unchanged fixture corpus and `git status knowledge/reference/` reports zero modified files (SC-5, SC-13). Operator mutates one fixture body, re-runs extract + ingest; a `REF-cat-id-v2.md` exists, the prior file's frontmatter has gained `superseded_by:`, and a `REVIEW:` line surfaces for any spec/memory chunk that cites the prior version (SC-6)."
risk: "medium"
depends_on: ["P02", "P04"]
---

# P06 — Idempotent re-extract + re-ingest + supersede chain mechanism

## Goal

Land the supersede-chain authoring mechanism on top of the M036 content-hash idempotency baseline already shipped by P02 (extract driver) and P04 (ingest driver). Three load-bearing additions:

1. **Versioned successor authoring** in `scripts/knowledge/extract-reference.sh`: when an existing chunk's `content_hash:` does not match the new source binary, the driver writes `REF-<cat>-<id>-v<N+1>.md` (next free version slot in the chain) AND amends the prior chain-tip's frontmatter with `superseded_by: <new-chunk-id>` (FR-10). Mirrors the spec-chunk re-ingest pattern at `commands/ingest.md:99-100`.

2. **Cross-citer `REVIEW:` advisory emission** in `scripts/knowledge/ingest-reference.sh`: after the ingest pass walks `knowledge/reference/`, if any chunk just received a fresh `superseded_by:` line, the driver invokes `scripts/knowledge/traverse-graph.sh --start <prior-chunk-id> --edge-types cites --reverse --depth 1` to enumerate spec/memory/reference chunks that currently `cites:` the now-superseded version, and emits one `REVIEW: <citer-chunk-id> reason=cites-superseded-target=<prior-chunk-id> tip=<new-chunk-id>` line per citer (FR-11). Also handles `removed_at:` for chunks whose source disappears between ingests (Edge Case in spec).

3. **Three milestone-grain acceptance harnesses** that lock in the SC-5 / SC-6 / SC-13 contracts: `tests/test-extract-idempotency.sh` (SC-13: re-extract on unchanged corpus → zero diff), `tests/test-reference-reingest-idempotency.sh` (SC-5: re-ingest on unchanged corpus → zero diff under `knowledge/reference/`), and `tests/test-reference-supersede-chain.sh` (SC-6: mutate-and-re-extract → versioned successor + `superseded_by:` lineage + `REVIEW:` line surfaces for citers). All three emit the M036-canonical `BATTERY: pass=N fail=N skip=N` last-stdout-line contract.

The phase is purely **additive** to P02 and P04: the existing fast-path (first-time extraction; first-time ingest; content-hash-equal SKIPPED) remains byte-equivalent. The mutation path (content-hash mismatch, source-removed) is the one that gains new behavior. CON-1 (no regression on pre-feature payloads) and CON-4 (idempotency mandatory) are both load-bearing assertions in the harnesses.

## Demo

> Operator runs extract + ingest twice on an unchanged fixture corpus and `git status knowledge/reference/` reports zero modified files (SC-5, SC-13). Operator mutates one fixture body, re-runs extract + ingest; a `REF-cat-id-v2.md` exists, the prior file's frontmatter has gained `superseded_by:`, and a `REVIEW:` line surfaces for any spec/memory chunk that cites the prior version (SC-6).

## Boundary Map

**Produces** (this phase writes / amends):

- `scripts/knowledge/extract-reference.sh` (modify) — adds the supersede-chain authoring branch on the content-hash mismatch path. When an existing chunk's `content_hash:` differs from the freshly-computed hash, the driver: (a) walks the existing chain (REF-<cat>-<id>.md, REF-<cat>-<id>-v2.md, ...) to find the current chain tip's basename, (b) computes the next version slot N+1, (c) writes a NEW chunk file at `REF-<cat>-<id>-v<N+1>.md` with the new content/hash AND the previous chain-tip's chunk_id stamped into a `supersedes:` frontmatter field, (d) updates the previous chain-tip's frontmatter to add `superseded_by: <new-chunk-id>` (idempotent — does not duplicate the line if it already exists). Emits `SUPERSEDED: <prior-chunk-id> -> <new-chunk-id>` stdout. The unchanged-content path (existing chunk frontmatter `content_hash:` matches new source hash) remains exactly the prior P02 SKIPPED behavior. The `version: <N+1>` numeric stamp in the new chunk's frontmatter is the operator-facing handle resolving Open Question #Q-3.
- `scripts/knowledge/lib/extract-supersede.sh` (create) — pure-lib MEM004 helper exposing `supersede_find_chain_tip(chunk_dir, category, cite_id) -> stdout: chunk-file-path` and `supersede_next_version(chunk_dir, category, cite_id) -> stdout: integer N+1` and `supersede_amend_prior_chunk(prior-chunk-file, new-chunk-id)` (idempotent in-place sed amendment). No top-level execution; sourced by `extract-reference.sh`.
- `scripts/knowledge/ingest-reference.sh` (modify) — adds the cross-citer `REVIEW:` emission pass. After the per-chunk classify/idempotency loop, the driver: (a) discovers chunks whose frontmatter contains `superseded_by:` but whose chunk_id is NOT itself a chain tip (i.e. they were just superseded — these are the candidates for citer review), (b) for each, invokes `scripts/knowledge/traverse-graph.sh --start <prior-chunk-id> --edge-types cites --reverse --depth 1` to enumerate citers, (c) emits one `REVIEW: <citer-id> reason=cites-superseded target=<prior-id> tip=<new-tip-id>` per citer. ALSO adds a removal-detection pass: chunks whose source file disappeared between ingests (extract-reference would no longer write them; the operator removed the source) are detected by an optional `--detect-removals` flag (default off — explicit opt-in to avoid false-positive removal advisories during normal partial-fixture-corpus development) and annotated with `removed_at:` frontmatter + `REMOVED:` stdout + cross-citer `REVIEW:` walk. This pass is purely advisory — does NOT auto-edit citer chunks (FR-11 + Principle XV Surgical Precision).
- `scripts/knowledge/lib/ingest-review-advisory.sh` (create) — pure-lib MEM004 helper exposing `review_emit_for_superseded_chunks(reference_root)` and `review_emit_for_removed_chunks(reference_root, prior_manifest_or_lockfile)`. Each enumerates target chunks, invokes the existing P05 `traverse-graph.sh --reverse --edge-types cites`, and emits well-shaped `REVIEW:` lines to stdout. No top-level execution.
- `tests/fixtures/m036-p06-supersede-corpus/` (create) — three fixtures used by the supersede harness:
  - `original/cms-rule/REF-cms-rule-supersede-fixture.md` — V1 reference chunk (full FR-2 frontmatter + `topic_tags: [pbj-staffing]` + `applies_to_field: [staff_count]` + a stable `cite_id: supersede-fixture` + body "BODY V1 ...").
  - `mutated/cms-rule/REF-cms-rule-supersede-fixture.md` — same chunk-file path, same FR-2 frontmatter, but body is "BODY V2 ..." so its body sha256 differs from V1.
  - `citer-spec/SPEC-requirement-supersede-citer.md` — synthetic spec chunk declaring `cites: [REF-cms-rule-supersede-fixture]` (the V1 chunk_id, not the v2 successor) — exercises the cross-citer REVIEW: walk.
- `tests/fixtures/m036-p06-extract-manifest.yaml` (create) — single-document manifest pointing at the markdown fixture so the extract harness can drive synchronously without host-tool dependencies. Two variants are inlined inside the harnesses themselves (mktemp -d workspaces) — the on-disk manifest is reference-shape only, exercised by a token-presence shape verifier.
- `tests/test-extract-idempotency.sh` (create) — SC-13 acceptance harness. Stages the fixture into a `mktemp -d` workspace, runs `bash scripts/knowledge/extract-reference.sh --manifest <ws>/manifest.yaml --reference-root <ws>/ref --originals-root <ws>/orig` twice, asserts (a) first run rc=0 + EXTRACTED stdout, (b) second run rc=0 + SKIPPED stdout for every doc, (c) `diff -qr` between two fresh-workspace runs yields zero output (byte-identical trees), (d) re-run against the populated tree leaves it byte-identical (`find <ws>/ref -type f -newer <pre-rerun-marker>` returns empty). Emits `BATTERY: pass=N fail=N skip=N` last line.
- `tests/test-reference-reingest-idempotency.sh` (create) — SC-5 acceptance harness. Stages an already-ingested REF-* chunk corpus into a `mktemp -d` workspace, runs `bash scripts/knowledge/ingest-reference.sh --reference-root <ws>/ref --no-index-rebuild` twice, asserts (a) first run rc=0 + per-chunk SKIPPED stdout (chunks already have matching content_hash), (b) tree byte-identical pre/post via `diff -qr` against a baseline snapshot, (c) re-running `ingest-reference.sh` again still emits SKIPPED uniformly. The `--no-index-rebuild` flag avoids touching `KNOWLEDGE-INDEX.md` (which is non-idempotent in M036 today — that's an M036b item and not in scope here). Emits `BATTERY:` last line.
- `tests/test-reference-supersede-chain.sh` (create) — SC-6 acceptance harness. Stages original/ fixture into `<ws>/ref`, runs extract → asserts V1 chunk exists. Replaces source body with mutated/, runs extract again → asserts (a) `REF-cms-rule-supersede-fixture-v2.md` was created, (b) original `REF-cms-rule-supersede-fixture.md` frontmatter contains `superseded_by: REF-cms-rule-supersede-fixture-v2`, (c) extract stdout contains `SUPERSEDED:` line for the chunk. Stages a citer spec chunk declaring `cites: [REF-cms-rule-supersede-fixture]` into `knowledge/spec/<ws-scope>/`, runs ingest with the existing graph, asserts (d) ingest stdout contains a `REVIEW: ... reason=cites-superseded target=REF-cms-rule-supersede-fixture` line. Emits `BATTERY:` last line.
- `tools/verify/m036-p06-extract-supersede-shape.sh` (create) — token-presence + functional shape verifier on `scripts/knowledge/extract-reference.sh` (T01) asserting the supersede branch tokens (`SUPERSEDED:`, `superseded_by:`, `supersedes:`, `version:`, the new helper-source line) are present. Combined existence-and-grep checks (10 token-presence + 1 file-existence for the helper lib).
- `tools/verify/m036-p06-extract-supersede-helper-shape.sh` (create) — token-presence verifier on `scripts/knowledge/lib/extract-supersede.sh` (T01) asserting the three helper functions (`supersede_find_chain_tip`, `supersede_next_version`, `supersede_amend_prior_chunk`) are defined and the file declares MEM004 in a structured comment (per the M036/P04 attribution-comment convention).
- `tools/verify/m036-p06-supersede-chain-end-to-end.sh` (create) — T01 behavioral verifier driving the extract driver against an inline mutated fixture (mktemp -d workspace + heredoc'd two-version markdown) and asserting (a) v2 chunk file exists post-mutation re-run, (b) prior chunk frontmatter contains `superseded_by:`, (c) stdout contains `SUPERSEDED:` line, (d) re-running on the now-mutated source emits SKIPPED (idempotency restored). No host-tool dependency (markdown-only).
- `tools/verify/m036-p06-ingest-review-shape.sh` (create) — T02 token-presence verifier on `scripts/knowledge/ingest-reference.sh` asserting the `REVIEW:` emission branch + the helper-source line for `lib/ingest-review-advisory.sh`. Five grep -qF -e checks.
- `tools/verify/m036-p06-ingest-review-helper-shape.sh` (create) — T02 token-presence verifier on `scripts/knowledge/lib/ingest-review-advisory.sh` asserting the two functions defined + traverse-graph.sh invocation + reverse + edge-types cites.
- `tools/verify/m036-p06-review-emission-end-to-end.sh` (create) — T02 behavioral verifier: stages a 2-chunk reference corpus (V1 chunk with `superseded_by: REF-...-v2` frontmatter + V2 chunk file present) plus a citer spec chunk (`SPEC-requirement-fixture-cites-v1` declaring `cites: [REF-cms-rule-fixture]`) into a `mktemp -d` workspace under the orchestrator's existing `knowledge/spec/` shape. Runs ingest-reference.sh against the workspace's reference root and asserts stdout contains the `REVIEW:` line naming the citer chunk-id, the superseded target, and the chain-tip target. The fixture is staged inline via heredocs so no shared on-disk fixture proliferates.
- `tools/verify/m036-p06-removed-detection-end-to-end.sh` (create) — T02 behavioral verifier: stages a chunk + a "prior manifest" lockfile recording the chunk's cite_id, then runs the ingest driver with `--detect-removals --prior-manifest <path>` against an empty reference corpus (the chunk's source has been "removed"). Asserts stdout contains `REMOVED: <chunk-id>` and `REVIEW: ... reason=cites-removed`. Markdown-only; no host-tool dependency.
- `tools/verify/m036-p06-fixture-corpus-shape.sh` (create) — T03 token-presence verifier on the 3-fixture corpus (`tests/fixtures/m036-p06-supersede-corpus/`) asserting each fixture exists, each declares the expected cite_id and topic_tags, and the citer-spec chunk's `cites:` frontmatter names the V1 chunk_id (NOT the v2 successor — the test exercises the chain-walk).
- `tools/verify/m036-p06-extract-manifest-shape.sh` (create) — T03 token-presence verifier on `tests/fixtures/m036-p06-extract-manifest.yaml`.
- `tools/verify/m036-p06-test-harness.sh` (create) — T04 permissive harness-shape verifier covering all three SC-5 / SC-6 / SC-13 harnesses (rc≤1 acceptable since rc=1 is fail-mode-but-still-emitted-BATTERY; rc≥2 indicates abort). Asserts each emits a well-formed `BATTERY: pass=N fail=N skip=N` last line.
- `tools/verify/m036-p06-acceptance-harness-passes.sh` (create) — T04 strict pass-rate gate (rc=0 specifically) covering the same three harnesses. Permissive+strict split per M036-canonical M036/P02..P05/P07 acceptance-harness convention.
- `tools/verify/m036-p06-p02-regression-pass.sh` (create) — T04 cross-phase regression: re-runs 14 of 15 P02 sub-gates (excluding the `m036-p02-tier-2-deferred-error.sh` whose semantics flipped at P03 close). Selective-gate-list pattern carried verbatim from M036/P03/T03 + M036/P04/T04 + M036/P07/T03.
- `tools/verify/m036-p06-p03-regression-pass.sh` (create) — T04 cross-phase regression: full pass-through of `tools/verify/m036-p03-phase-suite.sh`.
- `tools/verify/m036-p06-p04-regression-pass.sh` (create) — T04 cross-phase regression: full pass-through of `tools/verify/m036-p04-phase-suite.sh`. Load-bearing — P06 modifies `ingest-reference.sh` so this regression confirms the existing P04 contracts (CREATED/SKIPPED/REJECTED/BLOCKED/SUMMARY emission, partial-success ingest, FR-18 BLOCK detection) survive byte-equivalent.
- `tools/verify/m036-p06-p05-regression-pass.sh` (create) — T04 cross-phase regression: full pass-through of `tools/verify/m036-p05-phase-suite.sh`. P06 *consumes* `traverse-graph.sh --reverse --edge-types cites` but does not modify it; this regression is the load-bearing assertion that P06 did not perturb the script (whose CON-5 default-mode byte-equality baseline is the strongest possible guard).
- `tools/verify/m036-p06-p07-regression-pass.sh` (create) — T04 cross-phase regression: full pass-through of `tools/verify/m036-p07-phase-suite.sh`. P06 modifies `extract-reference.sh` and `ingest-reference.sh`; P07's dispatch path consumes the chunk store those drivers populate. Confirms the P07 SC-3 / SC-7 contracts survive.
- `tools/verify/m036-p06-phase-suite.sh` (create) — T04 16-gate phase-suite aggregator wiring all P06 sub-gates. Filename milestone-prefixed per Plan-Time Discipline rule 6. Sub-gate count: T01=3 (extract-supersede-shape + helper-shape + supersede-end-to-end) + T02=4 (ingest-review-shape + helper-shape + review-emission-end-to-end + removed-detection-end-to-end) + T03=2 (fixture-corpus-shape + extract-manifest-shape) + T04=7 (test-harness + acceptance-harness-passes + p02-regression + p03-regression + p04-regression + p05-regression + p07-regression) = 16 sub-gates.

**Consumes** (read but not modified):

- P02 `scripts/knowledge/extract-reference.sh` baseline driver — extended additively. The content-hash idempotency gate at lines ~115-122 (chunk-file-exists + frontmatter `content_hash:` matches → SKIPPED) is the seam; P06's mutation-path branch fires when the gate falls through (existing chunk + content_hash mismatch). The `version: <vN>` optional manifest field declared in P02's manifest contract is the operator-facing handle resolving #Q-3.
- P02 `scripts/knowledge/lib/extract-binary-preservation.sh` — `preservation_sha256` re-used unchanged.
- P02 `scripts/knowledge/lib/extract-manifest.sh` — manifest parsers re-used unchanged.
- P04 `scripts/knowledge/ingest-reference.sh` baseline driver — extended additively. P04's existing per-chunk loop (FR-1/FR-2 classify + content_hash idempotency + FR-18 BLOCK detection + CREATED/SKIPPED/REJECTED/BLOCKED stdout) is the seam; P06 adds a SECOND pass after the loop (post-classify, pre-rebuild-index) that walks superseded chunks and emits REVIEW: lines.
- P04 `scripts/knowledge/classify-reference.sh` — used unchanged by the ingest driver; P06 does not amend.
- P04 `tests/fixtures/m036-p04-reference-corpus/` — re-used as the corpus for the SC-5 re-ingest harness (already-ingested chunks with `content_hash:` frontmatter — re-runs MUST emit SKIPPED).
- P05 `scripts/knowledge/traverse-graph.sh --start <id> --edge-types cites --reverse --depth 1` — invoked by `lib/ingest-review-advisory.sh` to find citers of a superseded chunk. P05's flag surface confirmed at plan-authoring (verified `--start`, `--edge-types`, `--reverse`, `--depth` all parse-supported in `scripts/knowledge/traverse-graph.sh` at lines 29, 54, 58, plus the pre-existing depth flag).
- P05 graph schema declaring the `cites` edge type — P06 reads citer chunks but does not modify the schema.
- P07 dispatch surface — P06 does NOT touch dispatch. The cross-phase regression `m036-p06-p07-regression-pass.sh` is the assertion that the chunk-store deltas P06 introduces (new v2 chunk files; `superseded_by:` lines on prior chunks) do not perturb P07's SC-3 / SC-7 byte-identical-payload contracts. P07's `handle_reference` ranks chunks by topic_tags / applies_to_field / published recency / chunk_id — none of those signals change for the unchanged corpus the SC-7 baseline was captured against.
- M036/P02/P04 idempotency invariants (CON-4) — P06 strengthens (does not weaken) these by adding two additional acceptance harnesses that exercise the contract.

## Cross-Task Ordering (M036-canonical disclosure)

Three load-bearing ordering nuances disclosed up-front (M036-canonical convention; misses produce false-passes or path-discipline violations):

1. **T02 ingest-review-emission depends on a chunk that already has `superseded_by:` frontmatter.** The behavioral verifier `m036-p06-review-emission-end-to-end.sh` stages such a chunk inline via heredoc — it does NOT depend on T01's extract driver having run first. Both T01 and T02 are independently testable. The full SC-6 harness in T04 chains them (drive T01's extract → drive T02's ingest → assert REVIEW: in stdout) and IS the integration gate. Pattern: each task's verifiers exercise their unit contract in isolation; the harness exercises the cross-task integration.

2. **T01 extract-driver edits MUST preserve the existing P02 content-hash-equal SKIPPED fast path.** The mutation-path branch ONLY fires when an existing chunk file is present AND its `content_hash:` differs from the freshly-computed hash. The first-time extraction path (no prior chunk file) and the unchanged-content path (prior `content_hash:` matches) MUST emit byte-equivalent stdout to P02 (EXTRACTED:/SKIPPED:). This is asserted by the `m036-p06-p02-regression-pass.sh` cross-phase regression check in T04 — the P02 phase-suite's `m036-p02-idempotency.sh` exercises both paths and MUST still pass post-P06. T01's plan body explicitly fences the new branch behind the dual condition (file-exists AND hash-differs).

3. **Selective-gate-list cross-phase regression pattern is M036-canonical.** P02's `m036-p02-tier-2-deferred-error.sh` semantics flipped at P03 close; future regression checks targeting the P02 phase-suite MUST exclude that one gate. Pattern is carried verbatim from M036/P03/T03 + M036/P04/T04 + M036/P07/T03 into `tools/verify/m036-p06-p02-regression-pass.sh`. P03/P04/P05/P07 phase-suites have no flipped sub-gates that affect P06 — full pass-through is correct for those four.

## Plan-Time Path-Collision Check

Confirmed at plan-authoring time (commands/plan-phase.md Plan-Time Discipline rule 6). All `create` paths verified non-existent on disk via `ls`:

| Path declared `create` | Pre-existing? |
|---|---|
| `scripts/knowledge/lib/extract-supersede.sh` | NO |
| `scripts/knowledge/lib/ingest-review-advisory.sh` | NO |
| `tests/fixtures/m036-p06-supersede-corpus/**` | NO (directory does not exist) |
| `tests/fixtures/m036-p06-extract-manifest.yaml` | NO |
| `tests/test-extract-idempotency.sh` | NO |
| `tests/test-reference-reingest-idempotency.sh` | NO |
| `tests/test-reference-supersede-chain.sh` | NO |
| `tools/verify/m036-p06-*.sh` (16 files) | NO (no `m036-p06-*` files in `tools/verify/`) |
| `.orchestrator/milestones/M036/phases/P06/tasks/T0[1-4]-*-PLAN.md` | NO (tasks dir freshly created) |

Modify-not-create paths (declared `modify` not `create`):

- `scripts/knowledge/extract-reference.sh` — exists (P02); T01 amends the content-hash mismatch branch additively. Existing line range ~115-122 is the seam.
- `scripts/knowledge/ingest-reference.sh` — exists (P04); T02 amends with a post-loop REVIEW: emission pass + an opt-in `--detect-removals` flag. Existing per-chunk loop body remains byte-equivalent for unchanged corpora.

No collisions. No silent-clobber risk.

## Plan-Time Verifier-Slug Uniqueness Check

Every P06 verifier filename starts with the milestone-prefixed slug `m036-p06-` (Plan-Time Discipline rule 6 + M036-canonical convention from M036/P00 phase-summary). No `m036-p06-*` files exist in `tools/verify/` today (confirmed above). All 16 declared verifier filenames (15 sub-gates + the phase-suite aggregator) are unique within `tools/verify/`. No cross-milestone collisions ([M030](../../../../milestones/M030/index.md) / [M031](../../../../milestones/M031/index.md) use `p##-*` and `m030-*` / `m031-*` prefixes respectively; no overlap).

## Must-Haves

### Truths

- `scripts/knowledge/extract-reference.sh` declares the supersede authoring branch (writes versioned successor + `superseded_by:` lineage) and the `SUPERSEDED:` stdout protocol on content-hash mismatch.
  - Check: `bash tools/verify/m036-p06-extract-supersede-shape.sh`
- `scripts/knowledge/lib/extract-supersede.sh` defines `supersede_find_chain_tip()`, `supersede_next_version()`, and `supersede_amend_prior_chunk()` as a pure-lib MEM004 helper (no top-level execution).
  - Check: `bash tools/verify/m036-p06-extract-supersede-helper-shape.sh`
- A mutated source body re-extracted produces a `-v2.md` successor file, the prior chunk gains `superseded_by:`, and re-running on the now-mutated source emits SKIPPED (idempotency restored).
  - Check: `bash tools/verify/m036-p06-supersede-chain-end-to-end.sh`
- `scripts/knowledge/ingest-reference.sh` declares the `REVIEW:` emission pass and sources `lib/ingest-review-advisory.sh`.
  - Check: `bash tools/verify/m036-p06-ingest-review-shape.sh`
- `scripts/knowledge/lib/ingest-review-advisory.sh` defines `review_emit_for_superseded_chunks()` and `review_emit_for_removed_chunks()` and invokes `traverse-graph.sh --reverse --edge-types cites`.
  - Check: `bash tools/verify/m036-p06-ingest-review-helper-shape.sh`
- A reference corpus containing a chunk with `superseded_by:` frontmatter plus a spec chunk declaring `cites: [<prior-chunk-id>]` produces a `REVIEW:` line in ingest stdout naming the citer, the superseded target, and the chain tip.
  - Check: `bash tools/verify/m036-p06-review-emission-end-to-end.sh`
- The opt-in `--detect-removals` flag emits `REMOVED:` + `REVIEW:` lines for chunks whose source disappeared between ingests.
  - Check: `bash tools/verify/m036-p06-removed-detection-end-to-end.sh`
- The supersede-corpus fixtures and the manifest fixture exist on disk with the expected shape (V1 + mutated + citer-spec).
  - Check: `bash tools/verify/m036-p06-fixture-corpus-shape.sh`
- The `tests/fixtures/m036-p06-extract-manifest.yaml` fixture exists with the expected single-document manifest shape.
  - Check: `bash tools/verify/m036-p06-extract-manifest-shape.sh`
- The SC-5, SC-6, and SC-13 acceptance harnesses each emit a well-formed `BATTERY: pass=N fail=N skip=N` last line and rc≤1 (shape-only, permissive).
  - Check: `bash tools/verify/m036-p06-test-harness.sh`
- The SC-5, SC-6, and SC-13 acceptance harnesses each pass with rc=0 (strict pass-rate gate).
  - Check: `bash tools/verify/m036-p06-acceptance-harness-passes.sh`
- M036/P02 phase-suite (selective 14 of 15 sub-gates excluding the P03-flipped `m036-p02-tier-2-deferred-error.sh`) still passes after P06 lands.
  - Check: `bash tools/verify/m036-p06-p02-regression-pass.sh`
- M036/P03 phase-suite (14 sub-gates) still passes after P06 lands.
  - Check: `bash tools/verify/m036-p06-p03-regression-pass.sh`
- M036/P04 phase-suite (13 sub-gates) still passes after P06 lands.
  - Check: `bash tools/verify/m036-p06-p04-regression-pass.sh`
- M036/P05 phase-suite (8 sub-gates including default-mode CON-5 byte-equality baselines for `traverse-graph.sh` + `scope-filter.sh`) still passes after P06 lands.
  - Check: `bash tools/verify/m036-p06-p05-regression-pass.sh`
- M036/P07 phase-suite (17 sub-gates including SC-3 dispatch-injection + SC-7 golden-baseline backwards-compat) still passes after P06 lands.
  - Check: `bash tools/verify/m036-p06-p07-regression-pass.sh`
- The 16-gate P06 phase-suite aggregator reports `pass=16 fail=0`.
  - Check: `bash tools/verify/m036-p06-phase-suite.sh`

### Artifacts

- `scripts/knowledge/extract-reference.sh` (min 240 lines, contains "SUPERSEDED:")
- `scripts/knowledge/lib/extract-supersede.sh` (min 50 lines, contains "supersede_find_chain_tip")
- `scripts/knowledge/ingest-reference.sh` (min 200 lines, contains "REVIEW:")
- `scripts/knowledge/lib/ingest-review-advisory.sh` (min 50 lines, contains "review_emit_for_superseded_chunks")
- `tests/fixtures/m036-p06-supersede-corpus/original/cms-rule/REF-cms-rule-supersede-fixture.md` (min 15 lines, contains "BODY V1")
- `tests/fixtures/m036-p06-supersede-corpus/mutated/cms-rule/REF-cms-rule-supersede-fixture.md` (min 15 lines, contains "BODY V2")
- `tests/fixtures/m036-p06-supersede-corpus/citer-spec/SPEC-requirement-supersede-citer.md` (min 10 lines, contains "cites:")
- `tests/fixtures/m036-p06-extract-manifest.yaml` (min 10 lines, contains "supersede-fixture")
- `tests/test-extract-idempotency.sh` (min 50 lines, contains "BATTERY")
- `tests/test-reference-reingest-idempotency.sh` (min 50 lines, contains "BATTERY")
- `tests/test-reference-supersede-chain.sh` (min 60 lines, contains "BATTERY")
- `tools/verify/m036-p06-extract-supersede-shape.sh` (min 15 lines, contains "PASS:")
- `tools/verify/m036-p06-extract-supersede-helper-shape.sh` (min 10 lines, contains "PASS:")
- `tools/verify/m036-p06-supersede-chain-end-to-end.sh` (min 40 lines, contains "PASS:")
- `tools/verify/m036-p06-ingest-review-shape.sh` (min 10 lines, contains "PASS:")
- `tools/verify/m036-p06-ingest-review-helper-shape.sh` (min 10 lines, contains "PASS:")
- `tools/verify/m036-p06-review-emission-end-to-end.sh` (min 40 lines, contains "PASS:")
- `tools/verify/m036-p06-removed-detection-end-to-end.sh` (min 30 lines, contains "PASS:")
- `tools/verify/m036-p06-fixture-corpus-shape.sh` (min 15 lines, contains "PASS:")
- `tools/verify/m036-p06-extract-manifest-shape.sh` (min 10 lines, contains "PASS:")
- `tools/verify/m036-p06-test-harness.sh` (min 15 lines, contains "PASS:")
- `tools/verify/m036-p06-acceptance-harness-passes.sh` (min 15 lines, contains "PASS:")
- `tools/verify/m036-p06-p02-regression-pass.sh` (min 20 lines, contains "PASS:")
- `tools/verify/m036-p06-p03-regression-pass.sh` (min 10 lines, contains "PASS:")
- `tools/verify/m036-p06-p04-regression-pass.sh` (min 10 lines, contains "PASS:")
- `tools/verify/m036-p06-p05-regression-pass.sh` (min 10 lines, contains "PASS:")
- `tools/verify/m036-p06-p07-regression-pass.sh` (min 10 lines, contains "PASS:")
- `tools/verify/m036-p06-phase-suite.sh` (min 30 lines, contains "SUMMARY:")

### Key Links

- `scripts/knowledge/extract-reference.sh` → `scripts/knowledge/lib/extract-supersede.sh` (driver sources the helper).
- `scripts/knowledge/ingest-reference.sh` → `scripts/knowledge/lib/ingest-review-advisory.sh` (driver sources the helper).
- `scripts/knowledge/lib/ingest-review-advisory.sh` → `scripts/knowledge/traverse-graph.sh` (helper invokes the traverser to find citers).
- `tests/test-reference-supersede-chain.sh` → `tests/fixtures/m036-p06-supersede-corpus/original/cms-rule/REF-cms-rule-supersede-fixture.md` (SC-6 harness drives the original fixture).
- `tests/test-reference-supersede-chain.sh` → `tests/fixtures/m036-p06-supersede-corpus/mutated/cms-rule/REF-cms-rule-supersede-fixture.md` (SC-6 harness drives the mutated fixture).
- `tests/test-reference-supersede-chain.sh` → `tests/fixtures/m036-p06-supersede-corpus/citer-spec/SPEC-requirement-supersede-citer.md` (SC-6 harness stages the citer chunk).
- `tools/verify/m036-p06-phase-suite.sh` → all 15 P06 sub-gate verifiers (aggregator wires them).

## Files Likely Touched

- `scripts/knowledge/extract-reference.sh` (modify)
- `scripts/knowledge/lib/extract-supersede.sh` (create)
- `scripts/knowledge/ingest-reference.sh` (modify)
- `scripts/knowledge/lib/ingest-review-advisory.sh` (create)
- `tests/fixtures/m036-p06-supersede-corpus/original/cms-rule/REF-cms-rule-supersede-fixture.md` (create)
- `tests/fixtures/m036-p06-supersede-corpus/mutated/cms-rule/REF-cms-rule-supersede-fixture.md` (create)
- `tests/fixtures/m036-p06-supersede-corpus/citer-spec/SPEC-requirement-supersede-citer.md` (create)
- `tests/fixtures/m036-p06-extract-manifest.yaml` (create)
- `tests/test-extract-idempotency.sh` (create)
- `tests/test-reference-reingest-idempotency.sh` (create)
- `tests/test-reference-supersede-chain.sh` (create)
- `tools/verify/m036-p06-extract-supersede-shape.sh` (create)
- `tools/verify/m036-p06-extract-supersede-helper-shape.sh` (create)
- `tools/verify/m036-p06-supersede-chain-end-to-end.sh` (create)
- `tools/verify/m036-p06-ingest-review-shape.sh` (create)
- `tools/verify/m036-p06-ingest-review-helper-shape.sh` (create)
- `tools/verify/m036-p06-review-emission-end-to-end.sh` (create)
- `tools/verify/m036-p06-removed-detection-end-to-end.sh` (create)
- `tools/verify/m036-p06-fixture-corpus-shape.sh` (create)
- `tools/verify/m036-p06-extract-manifest-shape.sh` (create)
- `tools/verify/m036-p06-test-harness.sh` (create)
- `tools/verify/m036-p06-acceptance-harness-passes.sh` (create)
- `tools/verify/m036-p06-p02-regression-pass.sh` (create)
- `tools/verify/m036-p06-p03-regression-pass.sh` (create)
- `tools/verify/m036-p06-p04-regression-pass.sh` (create)
- `tools/verify/m036-p06-p05-regression-pass.sh` (create)
- `tools/verify/m036-p06-p07-regression-pass.sh` (create)
- `tools/verify/m036-p06-phase-suite.sh` (create)

## Task Decomposition (4 tasks)

Ordered by dependency. Each task fits in one fresh-context window.

- **T01 — Extract-side supersede authoring + helper lib + end-to-end behavioral** (depends: P02). Authors `scripts/knowledge/lib/extract-supersede.sh` (pure-lib MEM004 with `supersede_find_chain_tip`, `supersede_next_version`, `supersede_amend_prior_chunk`). Modifies `scripts/knowledge/extract-reference.sh` to source the helper and wire the supersede branch on the existing content-hash-mismatch path: writes `REF-<cat>-<id>-v<N+1>.md` with `supersedes:` frontmatter, amends the prior chain-tip's frontmatter with `superseded_by:` (idempotent — sed-amend skips if the line is already present), emits `SUPERSEDED:` stdout. Authors three T01 verifiers: `m036-p06-extract-supersede-shape.sh` (token-presence on the driver) + `m036-p06-extract-supersede-helper-shape.sh` (token-presence on the helper lib) + `m036-p06-supersede-chain-end-to-end.sh` (behavioral; markdown-only mktemp -d workspace; drives extract twice with mutated body in between). Lands first because (a) the supersede authoring is a prerequisite for T02's REVIEW: emission to have a `superseded_by:` chunk to walk against, (b) the unchanged-content fast path remains byte-equivalent so existing P02 tests stay green throughout T01.

- **T02 — Ingest-side REVIEW: emission + helper lib + removed-detection** (depends: T01 conceptually but independently testable). Authors `scripts/knowledge/lib/ingest-review-advisory.sh` (pure-lib MEM004 with `review_emit_for_superseded_chunks` and `review_emit_for_removed_chunks`; both invoke `traverse-graph.sh --start <id> --edge-types cites --reverse --depth 1` and emit `REVIEW:` lines). Modifies `scripts/knowledge/ingest-reference.sh` to source the helper and add a post-loop pass that walks the reference root for chunks with `superseded_by:` frontmatter and emits REVIEW: lines for each citer. Adds an opt-in `--detect-removals` flag that consumes a prior-manifest lockfile (or a previous-known-cite-id list) and emits `REMOVED:` + `REVIEW:` lines for chunks whose source has disappeared. Authors four T02 verifiers: `m036-p06-ingest-review-shape.sh` + `m036-p06-ingest-review-helper-shape.sh` + `m036-p06-review-emission-end-to-end.sh` (stages a synthetic V1+v2 chunk pair plus a citer spec chunk inline, asserts `REVIEW:` line present in ingest stdout) + `m036-p06-removed-detection-end-to-end.sh` (stages a chunk + prior-manifest lockfile, runs ingest with `--detect-removals` against an empty corpus, asserts `REMOVED:` + `REVIEW:` lines). Lands second — all behavioral checks stage their fixtures inline; no T02 verifier depends on T01's extract driver having been run.

- **T03 — On-disk supersede-corpus fixtures + manifest fixture** (depends: T01 + T02 conceptually). Authors the three on-disk fixtures under `tests/fixtures/m036-p06-supersede-corpus/` (original V1 + mutated V2 + citer-spec), the single-doc manifest at `tests/fixtures/m036-p06-extract-manifest.yaml`, and two T03 token-presence verifiers (`m036-p06-fixture-corpus-shape.sh` + `m036-p06-extract-manifest-shape.sh`). Splits into its own task (rather than folding into T01 or T02) because the SC-6 harness in T04 needs ALL three on-disk fixtures, and a clean fixture-only task gives the executor a separable unit. The fixtures are small (~5 KB total); no host-tool dependency.

- **T04 — Three SC harnesses + permissive/strict harness gate split + phase-suite aggregator + 5 cross-phase regressions** (depends: T01 + T02 + T03). Authors `tests/test-extract-idempotency.sh` (SC-13), `tests/test-reference-reingest-idempotency.sh` (SC-5), and `tests/test-reference-supersede-chain.sh` (SC-6). Each is a `mktemp -d` workspace harness emitting `BATTERY: pass=N fail=N skip=N` last line and exiting 0 iff fail=0. Authors `m036-p06-test-harness.sh` (permissive: rc≤1 + BATTERY emitted) + `m036-p06-acceptance-harness-passes.sh` (strict: rc=0). Authors five cross-phase regression verifiers (`p02-regression-pass.sh` selective 14 of 15; `p03-regression-pass.sh`, `p04-regression-pass.sh`, `p05-regression-pass.sh`, `p07-regression-pass.sh` full pass-through). Authors the 16-gate phase-suite aggregator `m036-p06-phase-suite.sh` wiring all sub-gates. Lands last because it consumes all upstream task deliverables.

## Risk Notes

**MEDIUM RISK — additive-edits-to-shared-driver path.** P06 modifies `scripts/knowledge/extract-reference.sh` (P02) and `scripts/knowledge/ingest-reference.sh` (P04). Both have shipped phase-suites (P02 = 15 sub-gates, P04 = 13 sub-gates) that exercise the unchanged-corpus fast path. If T01 or T02 inadvertently perturbs the fast path, the upstream regression checks (`m036-p06-p02-regression-pass.sh` + `m036-p06-p04-regression-pass.sh` in T04) will fail and surface the regression. The mitigation discipline (fence the new branch behind dual `[ -f $chunk_file ] && [ "$prior_hash" != "$new_hash" ]` conditions; keep the SKIPPED path byte-equivalent; never change the EXTRACTED stdout shape on first-time extraction) is called out explicitly in T01/T02 task plans.

**LOW-MEDIUM RISK — citer detection requires P05's typed-edge traversal mode.** `scripts/knowledge/traverse-graph.sh --start <id> --edge-types cites --reverse` is a P05 deliverable (closed; in `affects: [P06, P07]`). T02's helper lib invokes it via single-script-file shape (`bash scripts/knowledge/traverse-graph.sh --start "$x" --edge-types cites --reverse --depth 1`). At plan-authoring time the verifier-availability cross-check confirmed the script exists and the four flags parse-supported (lines 29, 54, 58, plus `--depth` already supported in the pre-T02 traverser per P05 summary). If `--depth 1` is not supported, the helper falls back to the `--all` traversal and post-filters in shell — both forms are acceptable. The behavioral verifiers (`review-emission-end-to-end.sh` + `removed-detection-end-to-end.sh`) exercise the integration; if the flag form is wrong they fail loudly with a tractable error.

**LOW RISK — REVIEW: line is advisory, not a hard fail.** Per FR-11 (Principle XV Surgical Precision), `REVIEW:` is informational. It does NOT block ingest. T02's plan body is explicit: emit the line, increment a counter for the SUMMARY, but never exit non-zero on REVIEW alone. The contract reduces the blast radius of false-positive citer matches (e.g., the citer's `cites:` field references a stale id; the operator audits and updates).

**LOW RISK — host-tool absence.** No new external tools required. SHA-256 via the existing shasum/sha256sum probe-and-fallback (P02 pattern). All harnesses are pure shell + markdown fixtures + `diff -qr`. SC-13 / SC-5 / SC-6 all run on bare hosts (no pdftotext / pandoc dependency for the markdown-only fixture path).

## Verification

Phase verification runs the aggregator:

```bash
bash tools/verify/m036-p06-phase-suite.sh
```

Expected output (last line): `SUMMARY: m036-p06-phase-suite.sh pass=16 fail=0`.

## Notes

P06 is the last in-flight M036a phase. Downstream the milestone goes to validation (`scripts/state/validate-milestone.sh`) and `M036-SUMMARY.md` authorship per the milestone-grain close pattern. The three SC harnesses authored here (SC-5, SC-6, SC-13) plus P02's SC-10 + P03's SC-11/SC-12 + P04's SC-1/SC-2 + P05's SC-4 + P07's SC-3/SC-7 constitute the M036a milestone-grain acceptance battery (`tests/m036a-acceptance/run-acceptance-battery.sh` is an M036b/post-validation deliverable not in P06 scope; per-harness invocation is sufficient for P06 close).

The supersede-chain mechanism shipping here is **mechanism only** per the brief — exercising it at scale (multi-version chains, REVIEW queue UX, change-over-time queries) is M036b/P09. The mechanism is cheap to implement once content-hash is wired; M036b is about operator-facing surfaces that exercise the mechanism at validator-pilot scale.
