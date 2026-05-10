---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M036"
goal: "Tier 2 LLM extraction + M030 task-type=extraction routing + conversus fidelity gate (replaces P02 summary_mode:auto deferred-error seam)"
demo_sentence: "Operator runs orchestrator:extract on a manifest with one tier:2 doc; the structured Markdown lands at knowledge/reference/<cat>/REF-*.structured.md, a PASS verdict file lands at .orchestrator/knowledge/reference/_extraction-log/<doc-id>.pass.md, an M030-shape unit_close JSONL record with non-empty model + cost_usd is appended to the execution-log; a second run with a manifest forcing BLOCK (mocked low-fidelity) lands the BLOCK rationale at _extraction-log/<doc-id>.block.md and the structured output is NOT promoted to the chunk store."
risk: "high"
depends_on: ["P02"]
---

## Goal

Implement the synchronous Tier 2 leg of `orchestrator:extract` by replacing the P02 `summary_mode: auto` deferred-error seam at
`scripts/knowledge/lib/extract-tier-0-summary.sh::generate_tier_0_summary` with a real Tier 2 path that:

1. Routes through [M030](../../../../milestones/M030/index.md) adaptive model selection under the new `task_type: extraction` registration (FR-19),
2. Performs LLM-driven structured-Markdown extraction whose output is written to `knowledge/reference/<cat>/REF-<cat>-<id>.structured.md` (sibling to the Tier 0 chunk file from P02),
3. Submits the Tier 2 output to a conversus fidelity gate (`tier-2-fidelity` preset, two-agent extractor-advocate vs. fidelity-advocate, PASS|BLOCK verdict per doc) via the existing `scripts/dispatch/adapters/tool/conversus.sh` adapter (FR-18),
4. On PASS — promotes `.structured.md` into the chunk store and writes a verdict file at
   `.orchestrator/knowledge/reference/_extraction-log/<cite_id>.pass.md`,
5. On BLOCK — retains the BLOCK rationale at `_extraction-log/<cite_id>.block.md`, **does NOT** write `.structured.md` into the chunk store, and surfaces the BLOCK on stdout as `BLOCKED: <cite_id> reason=<short>`,
6. Emits an M030-shape `unit_close` JSONL record (`event: unit_close`, `task_type: extraction`, `model: <id>`, `tokens_in: <n>`, `tokens_out: <n>`, `cost_usd: <n>`, `quality_score: <n>`) to `.orchestrator/execution-log.jsonl` per Tier 2 invocation.

The synchronous Tier 0 + Tier 1 paths from P02 remain byte-identical for `summary_mode ∈ {operator, stub}`. The change is additive at the `auto` branch only.

## Demo

```bash
# Stub provider, manifest declaring 1 doc at tier:2 + summary_mode:auto.
ORCHESTRATOR_ROOT="$(pwd)" CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=PASS \
  EXTRACT_TIER_2_DISPATCH=stub:pass \
  bash scripts/knowledge/extract-reference.sh \
    --manifest tests/fixtures/m036-p03-tier-2/extract-manifest.yaml

# Expected stdout:
#   EXTRACTED: tier2-fixture-01 tier=2 bytes=<n> hash=<prefix> verdict=PASS

# Artifacts on disk:
#   knowledge/reference/glossary/REF-glossary-tier2-fixture-01.md            (Tier 0 chunk)
#   knowledge/reference/glossary/REF-glossary-tier2-fixture-01.structured.md (Tier 2 PASS-promoted)
#   .orchestrator/knowledge/reference/_extraction-log/tier2-fixture-01.pass.md
#   .orchestrator/execution-log.jsonl   (last line: {"event":"unit_close","task_type":"extraction",...})

# Same manifest with EXTRACT_TIER_2_DISPATCH=stub:block (mocked low-fidelity):
#   stdout:                BLOCKED: tier2-fixture-01 reason=fidelity-gate
#   _extraction-log path:  tier2-fixture-01.block.md
#   chunk-store .structured.md: NOT present
```

## Must-Haves

### Truths

<!-- All Check: lines are bash <single-script-file> per AD-19. Verifiers under tools/verify/ (project-owned, milestone-prefixed slug per the post-[M031](../../../../milestones/M031/index.md) contract). -->

- `summary_mode: auto` no longer hard-errors when `tier: 2` — it dispatches Tier 2 LLM extraction + conversus gate.
  - Check: `bash tools/verify/m036-p03-tier-2-deferred-error-removed.sh`
- A Tier 2 extraction whose conversus gate returns PASS writes `.structured.md` next to the Tier 0 chunk and a `<cite_id>.pass.md` verdict file under `.orchestrator/knowledge/reference/_extraction-log/`.
  - Check: `bash tools/verify/m036-p03-tier-2-pass-end-to-end.sh`
- A Tier 2 extraction whose conversus gate returns BLOCK writes `<cite_id>.block.md` under `_extraction-log/` and **does NOT** create the `.structured.md` chunk file.
  - Check: `bash tools/verify/m036-p03-tier-2-block-retention.sh`
- Each Tier 2 invocation appends one well-formed `unit_close` JSONL record to `.orchestrator/execution-log.jsonl` with `task_type=extraction`, non-empty `model`, and non-empty `cost_usd`.
  - Check: `bash tools/verify/m036-p03-unit-close-extraction-shape.sh`
- The M030 routing table at `templates/model-routing.yml` recognises `task_type: extraction` (additive; does not change `mechanical|standard|novel` rows; does not touch `resolution:` model IDs — CON-3 closure preserved).
  - Check: `bash tools/verify/m036-p03-m030-task-type-extraction.sh`
- The conversus preset `tier-2-fidelity.yml` exists at `templates/conversus-presets/tier-2-fidelity.yml`, declares two agents (`extractor-advocate` + `fidelity-advocate`), an arbiter `verdict_contract: PASS|BLOCK`, and a `grounding_file:` reference.
  - Check: `bash tools/verify/m036-p03-conversus-preset-shape.sh`
- The Tier 2 helper lib `scripts/knowledge/lib/extract-tier-2-llm.sh` exposes the pure functions `extract_tier_2_dispatch` (LLM call, mockable via `EXTRACT_TIER_2_DISPATCH`) and `extract_tier_2_emit_unit_close`. The driver sources the helper alongside the existing P02 `extract-tier-0-summary.sh`.
  - Check: `bash tools/verify/m036-p03-driver-tier-2-shape.sh`
- The Tier 2 fidelity-gate helper `scripts/knowledge/lib/extract-tier-2-gate.sh` exposes `extract_tier_2_invoke_gate` (calls `scripts/dispatch/adapters/tool/conversus.sh gate tier-2-fidelity ...`) and `extract_tier_2_promote_or_retain` (writes pass.md or block.md + promotes/withholds the `.structured.md` based on verdict).
  - Check: `bash tools/verify/m036-p03-gate-helper-shape.sh`
- Backwards compatibility: `summary_mode ∈ {operator, stub}` and `tier ∈ {0, 1}` continue to behave byte-identically to P02 — the P02 phase-suite verifiers must continue to pass.
  - Check: `bash tools/verify/m036-p03-p02-regression-pass.sh`
- The SC-11 + SC-12 acceptance harness `tests/test-tier-2-extraction-with-gate.sh` runs end-to-end on a bare host (CON-3: stub-mocked LLM + stub-mocked conversus gate; no live LLM calls), exercises both PASS and BLOCK paths against the same fixture manifest, and emits `BATTERY: pass=<n> fail=<n> skip=<n>` as its last stdout line.
  - Check: `bash tools/verify/m036-p03-test-harness.sh`

### Artifacts

- `scripts/knowledge/lib/extract-tier-2-llm.sh` (min 70 lines, contains "extract_tier_2_dispatch")
- `scripts/knowledge/lib/extract-tier-2-gate.sh` (min 60 lines, contains "extract_tier_2_invoke_gate")
- `templates/conversus-presets/tier-2-fidelity.yml` (min 30 lines, contains "fidelity-advocate")
- `tests/fixtures/m036-p03-tier-2/extract-manifest.yaml` (min 12 lines, contains "tier: 2")
- `tests/fixtures/m036-p03-tier-2/sample.md` (min 5 lines, contains "fixture")
- `tests/test-tier-2-extraction-with-gate.sh` (min 100 lines, contains "BATTERY:")
- `tools/verify/m036-p03-phase-suite.sh` (min 30 lines, contains "SUMMARY: m036-p03-phase-suite.sh")
- `templates/model-routing.yml` (modify — add `extraction:` row under `routing:`; does NOT add hardcoded model IDs anywhere outside the existing `resolution:` block)

### Key Links

- `scripts/knowledge/lib/extract-tier-0-summary.sh` → `scripts/knowledge/lib/extract-tier-2-llm.sh` (auto branch dispatches into Tier 2 helper)
- `scripts/knowledge/extract-reference.sh` → `scripts/knowledge/lib/extract-tier-2-gate.sh` (driver sources gate helper for promote/retain)
- `scripts/knowledge/lib/extract-tier-2-gate.sh` → `scripts/dispatch/adapters/tool/conversus.sh` (gate helper invokes adapter)
- `scripts/knowledge/lib/extract-tier-2-gate.sh` → `templates/conversus-presets/tier-2-fidelity.yml` (preset name passed to `conversus.sh gate`)
- `tests/test-tier-2-extraction-with-gate.sh` → `scripts/knowledge/extract-reference.sh` (harness drives the driver)

## Tasks

### T01: Conversus preset + M030 task-type registration + extraction-fixture corpus

Authors the `templates/conversus-presets/tier-2-fidelity.yml` preset, amends `templates/model-routing.yml` to add a `routing.extraction:` row pointing at `smart` (so Tier 2 extraction defaults to the highest-fidelity tier under CC), and creates the P03 fixture corpus under `tests/fixtures/m036-p03-tier-2/` (manifest + a markdown source — markdown chosen for CON-3 deterministic-CI; no PDF/DOCX in this leg). Authors three shape verifiers (preset, M030 amendment, fixture corpus). Establishes the SSOT shapes that T02 + T03 will consume.

### T02: Tier 2 LLM helper + M030 dispatch + unit_close emitter (mockable)

Authors `scripts/knowledge/lib/extract-tier-2-llm.sh` — pure helper lib (no top-level I/O per MEM004) exposing:

- `extract_tier_2_dispatch <input-path> <out-path> <category> <cite_id>` — performs the LLM extraction call. Behavior gated by `EXTRACT_TIER_2_DISPATCH` env var:
  - Unset / `live` — calls `scripts/dispatch/select-model.sh` resolved against `task_type=extraction`, then dispatches an LLM extraction request and writes structured Markdown to `<out-path>`. **NOT exercised in CI per CON-3** (no live LLM calls).
  - `stub:pass` — copies `tests/fixtures/m036-p03-tier-2/canned-structured.md` to `<out-path>`; emits stub model/token/cost values to stderr (`MODEL=claude-haiku-4-5 TOKENS_IN=512 TOKENS_OUT=2048 COST_USD=0.0123`).
  - `stub:block` — copies `tests/fixtures/m036-p03-tier-2/canned-structured-low-fidelity.md` to `<out-path>` (intentionally lossy — drops a heading the gate will detect), emits the same stub metrics. Distinct from `stub:pass` only at the conversus-gate-verdict layer (canned BLOCK fixture is consumed by the gate stub, not by this helper).
- `extract_tier_2_emit_unit_close <cite_id> <model> <tokens_in> <tokens_out> <cost_usd> <quality_score>` — appends the JSONL `unit_close` record to `${ORCHESTRATOR_ROOT}/.orchestrator/execution-log.jsonl`. Single `printf` line. Bash 3.2.

Authors three verifiers: driver-shape (the helper file exists, exports both functions, uses `EXTRACT_TIER_2_DISPATCH`), `m030-task-type-extraction.sh` (the model-routing amendment landed in T01 is referenced + consumed correctly), `unit-close-extraction-shape.sh` (the emitter writes a parseable JSONL line with the required fields when invoked with sample args in a mktemp workspace).

### T03: Conversus fidelity-gate helper + driver auto-branch + PASS/BLOCK retention

Authors `scripts/knowledge/lib/extract-tier-2-gate.sh` — pure helper exposing:

- `extract_tier_2_invoke_gate <structured-md-path> <gate-output-path>` — calls `bash "$ORCHESTRATOR_ROOT/scripts/dispatch/adapters/tool/conversus.sh" gate tier-2-fidelity <structured-md-path> <gate-output-path>` and parses verdict via `conversus.sh parse-verdict`. Returns 0 on PASS, 2 on BLOCK, 1 on adapter error. Single-script-file invocations of `conversus.sh` (subcommand-positional shape, AD-19 compatible).
- `extract_tier_2_promote_or_retain <verdict> <structured-md-tmp-path> <chunk-dir> <cite_id> <category> <gate-output-path> <log-dir>` — on PASS: moves `<structured-md-tmp-path>` to `<chunk-dir>/REF-<category>-<cite_id>.structured.md` and copies `<gate-output-path>` to `<log-dir>/<cite_id>.pass.md`. On BLOCK: copies `<gate-output-path>` to `<log-dir>/<cite_id>.block.md`, removes the tmp structured file, does NOT write into `<chunk-dir>`. Idempotent (checks for existing identical files).

Modifies `scripts/knowledge/lib/extract-tier-0-summary.sh` — replaces the `auto` branch's hard-error in `generate_tier_0_summary` with a sentinel-string return (e.g., `__TIER_2_AUTO__`) when `tier=2`; the driver consumes the sentinel and dispatches the Tier 2 helper chain. (Preserves the existing tier!=2 + auto deferral message — matches the P02 `tier-2-deferred-error.sh` verifier semantics for non-tier-2 docs only.)

Modifies `scripts/knowledge/extract-reference.sh` — sources both new helpers, adds Tier 2 dispatch when `tier == 2 && summary_mode == auto`: (a) calls `extract_tier_2_dispatch` writing to a tmp `.structured.md` path, (b) calls `extract_tier_2_invoke_gate` to produce the gate-result.md, (c) calls `extract_tier_2_promote_or_retain`, (d) calls `extract_tier_2_emit_unit_close` with the stub metrics from `EXTRACT_TIER_2_DISPATCH=stub:*` (or live values from the live path), (e) emits `EXTRACTED: <cite_id> tier=2 ... verdict=PASS` on PASS or `BLOCKED: <cite_id> reason=fidelity-gate` on BLOCK.

Authors six verifiers: gate-helper-shape, tier-2-deferred-error-removed (the `tier:2 + auto` flow no longer hard-errors with the P02 message), tier-2-pass-end-to-end (mocked PASS path produces all four artifacts), tier-2-block-retention (mocked BLOCK path produces block.md but no `.structured.md`), p02-regression-pass (the P02 phase-suite still reports `pass=15 fail=0` on its existing fixtures — the P02 `tier-2-deferred-error.sh` continues to pass for non-tier-2 + auto docs), and updates the manifest fixture under `tests/fixtures/m036-p03-tier-2/` with the canned structured-md fixtures referenced by `EXTRACT_TIER_2_DISPATCH=stub:*`.

### T04: SC-11 + SC-12 acceptance harness + phase-suite aggregator

Authors `tests/test-tier-2-extraction-with-gate.sh` — drives the end-to-end PASS path then the BLOCK path in a single mktemp -d workspace using the P03 fixture manifest with `EXTRACT_TIER_2_DISPATCH=stub:pass` then `=stub:block` and `CONVERSUS_STUB=1` + `CONVERSUS_STUB_VERDICT=PASS` then `=BLOCK`. Asserts on disk: PASS produces `.structured.md` + `pass.md` + a `unit_close` JSONL record; BLOCK produces `block.md` + no `.structured.md`. Emits `BATTERY: pass=<n> fail=<n> skip=<n>` as the last stdout line; exit 0 iff `fail=0`.

Authors `tests/fixtures/m036-p03-tier-2/canned-structured.md` (the high-fidelity stub structured-md) and `canned-structured-low-fidelity.md` (the lossy stub).

Authors `tools/verify/m036-p03-phase-suite.sh` — aggregator wiring all P03 sub-gates (count: see Verification Ladder below). Patterned after `tools/verify/m036-p02-phase-suite.sh`: `set -eu`, `run` helper inspects exit code only, emits `SUMMARY: m036-p03-phase-suite.sh pass=<n> fail=<n>`, exits 0 iff `fail=0`.

Authors `tools/verify/m036-p03-test-harness.sh` — verifies the SC-11/SC-12 harness exists, executes (`rc<=1` permissive), and emits a well-formed `BATTERY:` line.

## Task Dependencies

```
T01 → T02 → T03 → T04
```

T01 (preset + M030 amendment + fixtures) is foundational SSOT — T02 + T03 + T04 all consume artifacts T01 lands.

T02 (Tier 2 LLM helper + unit_close emitter) is consumed by T03's driver auto-branch (the driver sources both helpers).

T03 (gate helper + driver edits) is consumed by T04's harness.

**Cross-task ordering note (Plan-Time Discipline rule 2)**: T03's `m036-p03-tier-2-pass-end-to-end.sh` and `m036-p03-tier-2-block-retention.sh` exercise behavior that requires the canned structured-md fixtures (`canned-structured.md`, `canned-structured-low-fidelity.md`) which T04 lands. The auto-loop's first-fail-retry handles this — T03 verifiers go green retroactively at T04 close. Documented here for the auditor; pattern carried from M036/P02/T02 (where T02 verifiers exercised T03 helpers — see P02 SUMMARY mid-phase corrections section).

## Verification Ladder

P03 phase-suite aggregator at `tools/verify/m036-p03-phase-suite.sh` wires the following 14 sub-gates:

- **T01 (3)**: `m036-p03-conversus-preset-shape.sh`, `m036-p03-m030-task-type-extraction.sh`, `m036-p03-fixture-corpus-shape.sh`
- **T02 (3)**: `m036-p03-driver-tier-2-shape.sh`, `m036-p03-tier-2-llm-helper-shape.sh`, `m036-p03-unit-close-extraction-shape.sh`
- **T03 (5)**: `m036-p03-gate-helper-shape.sh`, `m036-p03-tier-2-deferred-error-removed.sh`, `m036-p03-tier-2-pass-end-to-end.sh`, `m036-p03-tier-2-block-retention.sh`, `m036-p03-p02-regression-pass.sh`
- **T04 (3)**: `m036-p03-fixture-canned-structured-shape.sh`, `m036-p03-test-harness.sh`, `m036-p03-acceptance-harness-passes.sh`

The aggregator emits `SUMMARY: m036-p03-phase-suite.sh pass=14 fail=0` on a clean run.

The SC-11 + SC-12 acceptance harness at `tests/test-tier-2-extraction-with-gate.sh` is independent of the aggregator (run separately). It exercises the full PASS + BLOCK end-to-end paths and emits its own `BATTERY: pass=<n> fail=<n> skip=<n>` last-stdout-line.

### BATTERY-line contract for SC-11 acceptance harness

```
BATTERY: pass=<n> fail=<n> skip=<n>
```

- `n_pass + n_fail + n_skip` is always >= 8 on a healthy bare host run (4 PASS-leg assertions + 3 BLOCK-leg assertions + 1 unit_close record assertion).
- `skip` covers conversus-binary-absent / extract-tier-2-dispatch-misconfigured environmental SKIPs (rare given the helper accepts `EXTRACT_TIER_2_DISPATCH=stub:*` deterministically; usually `skip=0`).
- Exit 0 iff `fail=0`, regardless of `skip`.
- Last stdout line MUST match the regex `^BATTERY: pass=[0-9]+ fail=[0-9]+ skip=[0-9]+$` (consumed by `tools/verify/m036-p03-test-harness.sh`).

## Files Likely Touched

- `templates/conversus-presets/tier-2-fidelity.yml` (create)
- `templates/model-routing.yml` (modify — additive `routing.extraction:` row only; CON-3 closure preserved — no new model IDs outside `resolution:`)
- `tests/fixtures/m036-p03-tier-2/extract-manifest.yaml` (create)
- `tests/fixtures/m036-p03-tier-2/sample.md` (create)
- `tests/fixtures/m036-p03-tier-2/canned-structured.md` (create)
- `tests/fixtures/m036-p03-tier-2/canned-structured-low-fidelity.md` (create)
- `scripts/knowledge/lib/extract-tier-2-llm.sh` (create)
- `scripts/knowledge/lib/extract-tier-2-gate.sh` (create)
- `scripts/knowledge/lib/extract-tier-0-summary.sh` (modify — auto branch returns sentinel for tier=2 instead of hard-erroring; tier!=2 + auto continues to deferral-error)
- `scripts/knowledge/extract-reference.sh` (modify — source new helpers; add Tier 2 dispatch + gate + promote/retain block when tier==2 && summary_mode==auto)
- `tests/test-tier-2-extraction-with-gate.sh` (create)
- `tools/verify/m036-p03-conversus-preset-shape.sh` (create)
- `tools/verify/m036-p03-m030-task-type-extraction.sh` (create)
- `tools/verify/m036-p03-fixture-corpus-shape.sh` (create)
- `tools/verify/m036-p03-driver-tier-2-shape.sh` (create)
- `tools/verify/m036-p03-tier-2-llm-helper-shape.sh` (create)
- `tools/verify/m036-p03-unit-close-extraction-shape.sh` (create)
- `tools/verify/m036-p03-gate-helper-shape.sh` (create)
- `tools/verify/m036-p03-tier-2-deferred-error-removed.sh` (create)
- `tools/verify/m036-p03-tier-2-pass-end-to-end.sh` (create)
- `tools/verify/m036-p03-tier-2-block-retention.sh` (create)
- `tools/verify/m036-p03-p02-regression-pass.sh` (create)
- `tools/verify/m036-p03-fixture-canned-structured-shape.sh` (create)
- `tools/verify/m036-p03-test-harness.sh` (create)
- `tools/verify/m036-p03-acceptance-harness-passes.sh` (create)
- `tools/verify/m036-p03-phase-suite.sh` (create)

## Boundary Map

**Produces**:
- Tier 2 LLM extraction logic (additive over the P02 driver) and the `summary_mode: auto + tier: 2` branch implementation.
- M030 `task_type: extraction` row under `templates/model-routing.yml::routing` (additive amendment; CON-3 closure preserved — `resolution:` unchanged).
- conversus tier-2-fidelity preset under `templates/conversus-presets/`.
- Tier 2 helper libs under `scripts/knowledge/lib/extract-tier-2-{llm,gate}.sh` (MEM004 pure-lib pattern).
- BLOCK retention path under `.orchestrator/knowledge/reference/_extraction-log/` per FR-18.
- `unit_close` JSONL records with `task_type=extraction` per FR-19, written to `.orchestrator/execution-log.jsonl`.
- SC-11 + SC-12 acceptance harness `tests/test-tier-2-extraction-with-gate.sh` (mocked LLM + mocked conversus per CON-3).
- 14 sub-gate verifiers under `tools/verify/m036-p03-*` + phase-suite aggregator.

**Consumes**:
- P02 manifest contract + `extract-reference.sh` driver baseline + `extract-tier-0-summary.sh` auto-branch deferred-error seam.
- M030 model-selection adapter (`scripts/dispatch/select-model.sh`, closed 2026-05-01).
- conversus adapter `scripts/dispatch/adapters/tool/conversus.sh` (M011/P07, shipped) — invoked via `gate <preset> <artifact> <output>` + `parse-verdict <gate-result-path>` subcommands.
- `templates/conversus-presets/normalize-fidelity.yml` (read-only — used as the structural template for the new `tier-2-fidelity.yml` preset).
