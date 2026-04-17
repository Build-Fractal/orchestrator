# Ingesting Arbitrary Specs

## Overview

The orchestrator accepts any markdown document as a spec, not just files already
shaped into the spec-kit canonical layout. The ingest pipeline auto-detects the
input's shape, normalizes foreign-shaped input (narrative PRDs, design docs,
ADR-style briefs, vendor-supplied requirements dumps) into the section vocabulary
the chunker expects, and then feeds the normalized artifact through the existing
`ingest-spec.sh` -> `rebuild-index.sh` -> `scope-filter.sh --graph` pipeline.

This guide covers the format-agnostic intake path added in M011/P07. For the
original spec-kit-shaped workflow, see `commands/ingest.md`. For the reusable
two-agent deliberation protocol behind the fidelity gate, see
`commands/conversus-gate.md`.

The six-stage pipeline is:

1. Shape detection (`scripts/knowledge/detect-spec-shape.sh`) — fast, agent-free.
2. Normalization (`scripts/knowledge/normalize-spec.sh`) — LLM-driven, only for foreign input.
3. Intensity-stage policy resolution (`scripts/engine/intensity-gate.sh --stage ingest`).
4. Fidelity gate (`scripts/dispatch/adapters/tool/conversus.sh`) — Standard/Full only.
5. Chunker (`scripts/knowledge/ingest-spec.sh`).
6. Index rebuild (triggered internally by the chunker).

## Quickstart

To ingest a foreign-shaped PRD in one command:

```bash
bash scripts/knowledge/ingest-spec.sh \
  --spec-path ~/Downloads/arbitrary-prd.md \
  --slug 019-inventory-reconciliation \
  --scope-tags "[project]"
```

The `orchestrator:ingest` command (see `commands/ingest.md`) wraps this
invocation with the shape-detect, normalize, and fidelity-gate prefix stages.
Run it by hand when you want to walk each stage independently:

```bash
# 1. Detect shape
bash scripts/knowledge/detect-spec-shape.sh \
  --spec-path ~/Downloads/arbitrary-prd.md
# -> shape=foreign reasons=

# 2. Normalize (writes specs/<slug>/spec.md atomically)
bash scripts/knowledge/normalize-spec.sh \
  --spec-path ~/Downloads/arbitrary-prd.md \
  --slug 019-inventory-reconciliation
# -> NORMALIZED: specs/019-inventory-reconciliation/spec.md (source_hash=...)

# 3. Run fidelity gate (Standard/Full intensity)
bash scripts/dispatch/adapters/tool/conversus.sh gate \
  normalize-fidelity \
  specs/019-inventory-reconciliation/spec.md \
  .orchestrator/milestones/M011/phases/P07/gate-result.md
# -> verdict=PASS   (exit 0)

# 4. Chunker
bash scripts/knowledge/ingest-spec.sh \
  --spec-path specs/019-inventory-reconciliation/spec.md \
  --slug 019-inventory-reconciliation \
  --scope-tags "[project]"
# -> CREATED: knowledge/spec/story/SPEC-US-001.md
# -> CREATED: knowledge/spec/requirement/SPEC-FR-001.md
# -> ...
```

On a spec that is already in the spec-kit layout, step 1 emits `shape=speckit`
and steps 2-3 are skipped entirely — the chunker runs directly against the
source.

## When the fidelity gate fires

The intensity engine decides whether the fidelity gate runs on each invocation:

- **Quick** — `execute_substeps=normalize`, `skip_substeps=fidelity-gate`.
  The normalizer runs; the gate is bypassed.
- **Standard** — `execute_substeps=normalize,fidelity-gate`.
  Both run.
- **Full** — `execute_substeps=normalize,fidelity-gate`.
  Both run.

Two user-facing overrides let you force the gate regardless of resolved intensity:

- `--review` forces the fidelity gate ON. Promotes `fidelity-gate` into
  `execute_substeps` even under Quick intensity. Use this when the normalization
  is high-stakes (foreign vendor spec, legal-compliance document) and you want a
  cooperative-deliberation check before the chunker writes knowledge entries.
- `--no-review` forces the fidelity gate OFF. Forces `fidelity-gate` into
  `skip_substeps` even under Standard/Full intensity. Use this in CI or when
  you have already audited the normalization manually.

The overrides live at the command layer (`commands/ingest.md` applies them);
`intensity-gate.sh` exposes only the policy matrix.

## Interpreting BLOCK verdicts

When the fidelity gate returns BLOCK, the chunker does not run. The adapter
exits 2 (distinct from 1 for adapter errors) and writes a `gate-result.md`
artifact with a `## Disputes` section enumerating the specific fidelity issues
the deliberation surfaced.

To resolve a BLOCK:

1. Read `## Disputes` in `gate-result.md`. Each entry names a source claim that
   the normalized artifact failed to preserve or introduced without derivation.
2. Open the normalized `specs/<slug>/spec.md` side-by-side with the source.
   Look for: missing requirements, invented requirements, lost non-goals,
   altered constraint language, dropped acceptance criteria.
3. Fix the normalization directly in `specs/<slug>/spec.md`. The orchestrator
   reads the edited artifact on the next chunker run — the `source_hash:`
   marker in the normalized file's frontmatter prevents `normalize-spec.sh`
   from overwriting your edits on re-run against the same source.
4. Re-run the chunker. The idempotency layer in `ingest-spec.sh` treats the
   edited artifact as authoritative and emits `CREATED:` / `SUPERSEDED:` /
   `SKIPPED:` / `REMOVED:` per chunk exactly as if the normalized artifact
   had been hand-written.

## `--force` escape hatch

If you cannot address the BLOCK disputes (the normalization is correct but the
deliberation is too strict for your use case) or if you need to unblock a CI
run, pass `--force` to bypass the BLOCK verdict:

```bash
bash scripts/knowledge/ingest-spec.sh \
  --spec-path specs/019-foo/spec.md \
  --slug 019-foo \
  --force
```

When `--force` bypasses a BLOCK, an audit-trail line of the form
`FORCE: gate BLOCK bypassed by --force at <iso-8601>` is appended to the
milestone's `.ingest-log.jsonl`. This makes the decision visible in later
review without failing the current pipeline.

Note: `--force` has two semantically-separate effects that share the same flag:

- **P06 re-ingest bypass**: allow a re-ingest to proceed when prior chunks
  exist on disk for the same slug.
- **P07 BLOCK-verdict bypass**: allow the chunker to run after the fidelity
  gate returns BLOCK.

Both uses are documented in `commands/ingest.md`.

## Stub modes for CI

The pipeline supports two stub modes that make an end-to-end run deterministic
without live agents or external binaries:

- `NORMALIZER_STUB=1` — the normalizer wrapper skips the dispatch call and
  copies `tests/fixtures/normalized-stub.md` to the output path (still with
  the `source_hash:` marker prepended). Used by P07 e2e gates.
- `CONVERSUS_STUB=1` — the conversus adapter uses the canned
  `tests/fixtures/gate-result-{pass,block}.md` fixture selected by
  `CONVERSUS_STUB_VERDICT=PASS|BLOCK` (default PASS).

Example CI invocation:

```bash
NORMALIZER_STUB=1 CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=PASS \
  bash scripts/verify/m011-p07-e2e-arbitrary-spec.sh
```

The e2e verify script runs all four stages end-to-end in a sandboxed
`mktemp -d` directory, asserts each stage's stdout contract, and checks the
total elapsed time stays under a 120-second budget.

## Graceful degradation

Conversus is an opt-in external dependency, not a hard prerequisite of the
ingest pipeline. When the binary is missing, the adapter's `gate` subcommand
emits a `SKIPPED:` line on stdout and exits 0 — the calling pipeline treats
this as a pass-through and proceeds to the chunker.

Resolver order for the conversus binary:

1. `CONVERSUS_STUB=1` — stub mode (testing).
2. `command -v conversus` — on PATH.
3. `$CONVERSUS_HOME/bin/conversus` — explicit env var.
4. `$HOME/Sites/conversus/bin/conversus` — user-local convention.

To install conversus locally, clone the repo to `~/Sites/conversus` (or any
location pointed at by `CONVERSUS_HOME`). See the conversus project for its
own install docs — the orchestrator does not ship a copy.

## Extending to new gate points

M011/P07 ships the `normalize-fidelity` preset. M013 (GitHub integration)
and M014 (wiki) will add their own presets under
`templates/conversus-presets/` and invoke the same reusable tool adapter
(`scripts/dispatch/adapters/tool/conversus.sh`) at their own gate points.

To add a new preset:

1. Copy `templates/conversus-presets/normalize-fidelity.yml` to a new file
   named for the gate point (e.g. `github-issue-fidelity.yml`).
2. Edit the `source_role` / `target_role` / `arbiter_role` fields to match
   the new gate point's semantics. Keep the `constitution_path` pointing
   at `.orchestrator/memory/constitution.md` so the arbiter stays grounded
   in the project's governing principles.
3. Invoke the gate from your own command doc via:
   `bash scripts/dispatch/adapters/tool/conversus.sh gate <preset-name> <artifact> <output>`.
4. Cross-link `commands/conversus-gate.md` from your command's Reference
   Files so the reusable protocol is discoverable.

## See also

- `commands/ingest.md` — the user-facing wrapper command that chains the
  six-stage pipeline with `--review` / `--no-review` / `--force` flag handling.
- `commands/conversus-gate.md` — the reusable cooperative-deliberation
  protocol documentation. All gate points (normalize-fidelity,
  github-issue-fidelity, wiki-page-fidelity) share this command shape.
- `templates/spec-normalizer-prompt.md` — the normalizer prompt body. Edit
  only to refine normalization instructions; the agent input/output contract
  is load-bearing across `normalize-spec.sh` and the chunker.
- `templates/conversus-presets/normalize-fidelity.yml` — the canonical
  fidelity-gate preset for source-vs-normalized fidelity checks.
- `templates/gate-result.md` — the gate-result artifact shape emitted by
  the conversus adapter on each gate invocation.
