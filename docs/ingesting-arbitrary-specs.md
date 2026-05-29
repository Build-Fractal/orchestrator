# Ingesting Arbitrary Specs

**Point any markdown document at the orchestrator — narrative PRD, ADR brief, vendor requirements dump — and it auto-normalizes the foreign shape into the canonical spec layout, gates the result for fidelity, then chunks it into the knowledge graph.**

## TL;DR

- The ingest pipeline accepts **any** `.md` file, not just files already in the spec-kit canonical layout.
- It detects the input's shape, normalizes foreign-shaped input into the section vocabulary the chunker expects, optionally runs a fidelity gate, then chunks the spec into typed knowledge entries.
- One-command path: `bash scripts/knowledge/ingest-spec.sh --spec-path <file> --slug <slug> --scope-tags "[project]"`.
- The `/orchestrator-ingest` command (see [`commands/ingest.md`](../commands/ingest.md)) wraps the whole pipeline with the shape-detect / normalize / fidelity-gate prefix stages and the `--review` / `--no-review` / `--force` flags.

This is the format-agnostic intake path added in M011/P07. For the field-level flag reference and error-handling matrix, [`commands/ingest.md`](../commands/ingest.md) is the canonical home.

## Prerequisites / assumes you know

Assumes you have an installed, initialized orchestrator project — see [getting-started](getting-started.md) for clone + install. This is a reference guide for the intake pipeline, not an onboarding doc.

| Term | One-line definition |
|------|---------------------|
| **Canonical layout** | The spec-kit section vocabulary the chunker expects: `## User Scenarios & Testing` (with acceptance scenarios embedded under each user story in Given/When/Then Gherkin form), `## Functional Requirements`, `## Non-Goals`/`## Constraints`/`## Success Criteria`, plus `FR-`/`US-`/`AC-`/`NFR-` ID tags. Lives at `specs/<slug>/spec.md`. |
| **Foreign-shaped input** | Any markdown spec that is *not* in the canonical layout — its headings/IDs don't match the patterns above. Gets normalized before chunking. |
| **Narrative PRD** | A prose product-requirements doc written as paragraphs ("the system should…") rather than typed `FR-###` requirement lines. A common foreign shape. |
| **ADR-style brief** | An architecture-decision-record-shaped document (context / decision / consequences). Another common foreign shape. |
| **conversus** | Optional sister project — a multi-agent deliberation engine. Used here to run the fidelity gate. The pipeline works standalone without it (see [What conversus is](#what-conversus-is)). |
| **Fidelity gate** | A two-agent deliberation that checks the normalized artifact faithfully preserves the source's claims. Returns `PASS` or `BLOCK`. |
| **Scope tag** | The `scope_tags: "[...]"` value stamped on every chunk (e.g. `[project]` or `[spec:<slug>]`) so the knowledge graph can filter by scope. |

## Section index

1. [Quickstart](#quickstart) — the impatient one-liner
2. [What conversus is](#what-conversus-is)
3. [The six-stage pipeline](#the-six-stage-pipeline)
4. [Stage walkthrough](#stage-walkthrough) — command + expected output per stage
5. [Normalization explained](#normalization-explained)
6. [The fidelity gate](#the-fidelity-gate)
7. [Stub modes for CI](#stub-modes-for-ci)
8. [The `--force` flag](#the---force-flag)
9. [Extending to new gate points](#extending-to-new-gate-points-developer) (developer/advanced)
10. [See also](#see-also)

## Quickstart

If the source is already a clean foreign PRD and you trust the normalization, run the chunker directly:

```bash
bash scripts/knowledge/ingest-spec.sh \
  --spec-path ~/Downloads/arbitrary-prd.md \
  --slug 019-inventory-reconciliation \
  --scope-tags "[project]"
```

For the full path — shape-detect, normalize, fidelity-gate, then chunk — use the wrapper command [`/orchestrator-ingest`](../commands/ingest.md), or walk the stages by hand (below) when you want to inspect each one.

## What conversus is

**conversus** is an optional sister project: a multi-agent deliberation engine the orchestrator invokes through a graceful-degradation adapter. Here it powers the **fidelity gate** — a two-agent (source-advocate vs target-advocate) deliberation that verifies the normalized spec preserved the source's meaning.

- It is **not** a hard prerequisite. When the `conversus` binary is missing, the gate adapter emits `SKIPPED:` and exits 0; the pipeline treats this as a pass-through and proceeds to the chunker.
- The reusable gate protocol is documented in [`commands/conversus-gate.md`](../commands/conversus-gate.md).
- To install it, clone the OSS build to `~/Sites/conversus-oss` (the user-local default). See the conversus project's own install docs — the orchestrator does not ship a copy.

| Resolver order for the `conversus` binary | Purpose |
|-------------------------------------------|---------|
| `CONVERSUS_STUB=1` | Stub mode (testing) |
| `command -v conversus` | On `PATH` |
| `$CONVERSUS_HOME/bin/conversus` | Explicit absolute override |
| `$HOME/Sites/conversus-oss/bin/conversus` | User-local OSS default |
| `$HOME/Sites/conversus/bin/conversus` | User-local paid escape hatch |

Edition (`oss|paid|unknown`) is reported on `conversus.sh check` stdout. Declare it via `CONVERSUS_EDITION=oss|paid` (primary); fallback is a `pip show conversus` metadata probe. Stub mode is edition-agnostic.

## The six-stage pipeline

| # | Stage | Script | Notes |
|---|-------|--------|-------|
| 1 | Shape detection | `scripts/knowledge/detect-spec-shape.sh` | Fast, agent-free |
| 2 | Normalization | `scripts/knowledge/normalize-spec.sh` | LLM-driven; foreign input only |
| 3 | Intensity-stage policy | `scripts/engine/intensity-gate.sh --stage ingest` | Decides if the gate runs |
| 4 | Fidelity gate | `scripts/dispatch/adapters/tool/conversus.sh` | Standard/Full intensity only |
| 5 | Chunker | `scripts/knowledge/ingest-spec.sh` | Writes typed knowledge entries |
| 6 | Index rebuild | (internal to the chunker) | Refreshes `KNOWLEDGE-INDEX.md` |

On a spec already in the canonical layout, stage 1 emits `shape=speckit` and stages 2–4 are skipped entirely — the chunker runs directly against the source.

## Stage walkthrough

### Stage 1 — detect shape

```bash
bash scripts/knowledge/detect-spec-shape.sh \
  --spec-path ~/Downloads/arbitrary-prd.md
# -> shape=foreign reasons=
```

The probe emits `shape=<value> reasons=<csv>` to stdout and exits 0 on either outcome. There are exactly **two** shape values:

| `shape=` value | Meaning | Next stage |
|----------------|---------|------------|
| `speckit` | Already in the canonical layout (matched ≥ 3 probe families) | Skip to the chunker (stage 5) |
| `foreign` | Not canonical (matched < 3 families) — needs normalization | Proceed to stage 2 |

The `reasons=` CSV lists which of these heading/ID-pattern families matched: `user_stories`, `functional_requirements`, `acceptance`, `non_goals_constraints_success`, `id_tags`, `gherkin`, `as_a_i_want`. (Three or more matches ⇒ `speckit`.)

### Stage 2 — normalize (foreign input only)

```bash
bash scripts/knowledge/normalize-spec.sh \
  --spec-path ~/Downloads/arbitrary-prd.md \
  --slug 019-inventory-reconciliation
# -> NORMALIZED: specs/019-inventory-reconciliation/spec.md (source_hash=...)
```

Writes the canonical spec atomically to `specs/<slug>/spec.md`. See [Normalization explained](#normalization-explained).

### Stage 3 + 4 — fidelity gate (Standard/Full intensity)

```bash
bash scripts/dispatch/adapters/tool/conversus.sh gate \
  normalize-fidelity \
  specs/019-inventory-reconciliation/spec.md \
  .orchestrator/milestones/M011/phases/P07/gate-result.md
# -> verdict=PASS   (exit 0)
```

See [The fidelity gate](#the-fidelity-gate) for when this fires and what `BLOCK` means.

### Stage 5 — chunk

```bash
bash scripts/knowledge/ingest-spec.sh \
  --spec-path specs/019-inventory-reconciliation/spec.md \
  --slug 019-inventory-reconciliation \
  --scope-tags "[project]"
# -> CREATED: knowledge/spec/story/SPEC-US-001.md
# -> CREATED: knowledge/spec/requirement/SPEC-FR-001.md
# -> ...
```

The chunker classifies every structural element into one of six categories — `spec/story`, `spec/requirement`, `spec/acceptance`, `spec/constraint`, `spec/nfr`, `spec/non-goal` — and emits `CREATED:` / `SKIPPED:` / `SUPERSEDED:` / `REMOVED:` / `REVIEW:` lines. Stage 6 (the `KNOWLEDGE-INDEX.md` rebuild) runs automatically inside this call.

## Normalization explained

**The pipeline is format-agnostic at the input but canonical at the output.** It does not chunk arbitrary shapes in place — it *transforms* foreign input into the canonical layout first, then chunks that. "Format-agnostic" and "auto-normalizes" are the same fact stated from the two ends of the pipe.

What normalization does to the input:

- Reads the source and re-emits it in the canonical section layout (`## User Stories`, `## Functional Requirements`, `## Acceptance Scenarios`, etc.), driven by `templates/spec-normalizer-prompt.md`.
- **Preserves** every factual claim, requirement, non-goal, constraint, and acceptance criterion from the source. **Introduces no new requirements.**
- Writes the result atomically (temp-file-then-rename) to `specs/<slug>/spec.md`, so readers never observe a half-written file. The artifact is written **before** the fidelity gate runs, so you can always audit it — even on a `BLOCK`.

**Can you reject it?** Yes. Normalization is just a file write you own afterward:

- The output is plain markdown at `specs/<slug>/spec.md`. Edit it directly — the chunker reads whatever is on disk.
- A `source_hash:` marker in the file's frontmatter prevents `normalize-spec.sh` from overwriting your hand-edits when you re-run against the same source.

**How to tell if it succeeded:** `normalize-spec.sh` prints `NORMALIZED: specs/<slug>/spec.md (source_hash=...)` and exits 0. A non-zero exit (empty/malformed agent output, runtime resolver failure) stops the pipeline before any chunks are written — the pipeline never falls back to chunking raw input.

## The fidelity gate

The gate is a conversus deliberation that compares the normalized artifact against the source and returns `PASS` or `BLOCK`. **The resolved intensity decides whether it fires:**

| Intensity | `execute_substeps` | Gate runs? |
|-----------|--------------------|------------|
| Quick | `normalize` | No (bypassed) |
| Standard | `normalize,fidelity-gate` | Yes |
| Full | `normalize,fidelity-gate` | Yes |

Two command-layer overrides force the gate regardless of resolved intensity (applied by [`/orchestrator-ingest`](../commands/ingest.md); `intensity-gate.sh` only exposes the matrix):

| Flag | Effect | When to use |
|------|--------|-------------|
| `--review` | Forces the gate **ON** even under Quick | High-stakes normalization (foreign vendor spec, legal/compliance doc) |
| `--no-review` | Forces the gate **OFF** even under Standard/Full | CI, or after you've manually audited the normalization |

### What `gate-result.md` contains

Every gate invocation writes a `gate-result.md` artifact (template at `templates/gate-result.md`):

- **Frontmatter**: `schema_version`, `type: gate-result`, `preset`, `artifact`, `verdict` (`PASS|BLOCK`), `timestamp`, `source_hash`.
- **`## Verdict`** — the PASS/BLOCK result.
- **`## Disputes`** — on `BLOCK`, one entry per fidelity issue the deliberation surfaced (named per agent).
- **`## Rationale`** — the deliberation's reasoning.

### What happens on BLOCK

On `BLOCK` the adapter exits **2** (distinct from `1` for adapter errors) and the chunker does **not** run. To resolve:

1. Read `## Disputes` in `gate-result.md`. Each entry names a source claim the normalized artifact failed to preserve or introduced without derivation.
2. Open `specs/<slug>/spec.md` side-by-side with the source. Look for: missing requirements, invented requirements, lost non-goals, altered constraint language, dropped acceptance criteria.
3. Fix the normalization directly in `specs/<slug>/spec.md`. The `source_hash:` marker keeps `normalize-spec.sh` from overwriting your edits on re-run.
4. Re-run the chunker. The idempotency layer treats your edited artifact as authoritative and emits `CREATED:` / `SUPERSEDED:` / `SKIPPED:` / `REMOVED:` per chunk exactly as if it had been hand-written.

If you cannot resolve the disputes (the normalization is correct but the deliberation is too strict), bypass the `BLOCK` with [`--force`](#the---force-flag).

## Stub modes for CI

Two env vars make an end-to-end run deterministic without live agents or external binaries:

| Env var | Effect |
|---------|--------|
| `NORMALIZER_STUB=1` | Normalizer skips the dispatch call and copies `tests/fixtures/normalized-stub.md` to the output path (still prepending the `source_hash:` marker). |
| `CONVERSUS_STUB=1` | Conversus adapter uses the canned `tests/fixtures/gate-result-{pass,block}.md` fixture, selected by `CONVERSUS_STUB_VERDICT=PASS\|BLOCK` (default `PASS`). |

Example CI invocation:

```bash
NORMALIZER_STUB=1 CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=PASS \
  bash scripts/verify/m011-p07-e2e-arbitrary-spec.sh
```

The e2e verify script runs all four pre-chunker-through-chunker stages in a sandboxed `mktemp -d` directory, asserts each stage's stdout contract, and checks total elapsed time stays under a 120-second budget.

## The `--force` flag

`--force` has **two distinct, legitimate uses** that happen to share one flag — neither implies you did anything wrong:

| Use | What it bypasses | When you reach for it |
|-----|------------------|------------------------|
| **Re-ingest bypass** (P06) | The confirmation that fires when prior chunks already exist on disk for the same slug | Re-ingesting an evolved spec during planning — the expected, idempotent workflow |
| **BLOCK-verdict bypass** (P07) | A fidelity-gate `BLOCK` (exit 2) | The normalization is correct but the deliberation is too strict, or you need to unblock a CI run |

```bash
bash scripts/knowledge/ingest-spec.sh \
  --spec-path specs/019-foo/spec.md \
  --slug 019-foo \
  --force
```

When `--force` bypasses a `BLOCK`, an audit line of the form `FORCE: gate BLOCK bypassed by --force at <iso-8601>` is appended to the milestone's `.ingest-log.jsonl` — the decision stays visible in later review without failing the current pipeline. Both uses are documented in [`commands/ingest.md`](../commands/ingest.md).

## Extending to new gate points (developer)

> **Developer/advanced.** Skip this if you are just ingesting a spec — it covers wiring the reusable gate adapter into *new* orchestrator stages.

M011/P07 ships the `normalize-fidelity` preset. Other milestones add their own presets under `templates/conversus-presets/` and invoke the same reusable adapter (`scripts/dispatch/adapters/tool/conversus.sh`) at their own gate points.

To add a new preset:

1. Copy `templates/conversus-presets/normalize-fidelity.yml` to a new file named for the gate point (e.g. `github-issue-fidelity.yml`).
2. Edit the `source_role` / `target_role` / `arbiter_role` fields to match the new gate point's semantics. Keep `constitution_path` pointing at `.orchestrator/memory/constitution.md` so the arbiter stays grounded in the project's governing principles.
3. Invoke the gate from your command doc:
   `bash scripts/dispatch/adapters/tool/conversus.sh gate <preset-name> <artifact> <output>`.
4. Cross-link [`commands/conversus-gate.md`](../commands/conversus-gate.md) from your command's Reference Files so the reusable protocol stays discoverable.

## See also

- [`commands/ingest.md`](../commands/ingest.md) — the `/orchestrator-ingest` wrapper command: canonical home for every flag, the workflow steps, and the full error-handling matrix.
- [`commands/conversus-gate.md`](../commands/conversus-gate.md) — the reusable cooperative-deliberation protocol shared by all gate points.
- `templates/spec-normalizer-prompt.md` — the normalizer prompt body (the agent input/output contract is load-bearing).
- `templates/conversus-presets/normalize-fidelity.yml` — the canonical fidelity-gate preset.
- `templates/gate-result.md` — the gate-result artifact shape.

**Next:** new to the orchestrator? Start at [getting-started](getting-started.md). Migrating spec-kit content? See [migrating-from-speckit](migrating-from-speckit.md).
