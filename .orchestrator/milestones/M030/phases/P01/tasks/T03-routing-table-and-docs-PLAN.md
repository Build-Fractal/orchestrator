---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M030"
name: "Routing table + cost_rates SSOT + operator docs + classifier-confidence stability metric"
depends_on: ["T02"]
---

## Prerequisites

- `scripts/dispatch/classify-task.sh` exists and the four T02 verifiers exit 0 (T02 close).
- `tools/verify/p01-d-a4-timeline.sh` exists and exits 0 in Mode B (timeline ordering held post-T02 classifier commit).
- `tests/fixtures/m030-classifier-corpus/labels.yml` exists (P00).
- `templates/model-routing.yml` does **NOT** yet exist on disk.
- `references/model-routing.md` does **NOT** yet exist on disk.

Plan-time prerequisite-existence verification: every existing-path above resolves under `[ -f <path> ]`; the two future-files MUST NOT exist (`[ ! -f templates/model-routing.yml ]` and `[ ! -f references/model-routing.md ]`).

## Description

T03 authors the routing-table SSOT and the operator-facing documentation. The routing table is the M030 declarative interface where `(character × runtime) → symbolic-tier` and `(symbolic-tier × runtime) → model-id` are mapped. The operator docs explain how to read and modify the table, and — load-bearing for downstream P02 — they pin the **classifier-confidence stability metric** to concrete numeric values so P02's `shadow-compare.sh` consumes a fixed contract rather than a TBD.

Concrete deliverables:

1. `templates/model-routing.yml` — routing table + per-runtime resolution table + `cost_rates:` SSOT section.
2. `references/model-routing.md` — operator docs covering Routing Table, Per-Runtime Resolution, Cost Rates SSOT, Aggressive Overlay, and Classifier-Confidence Stability Metric (concrete numeric thresholds).
3. `tools/verify/p01-routing-table-shape.sh` — symbolic-tier closure verifier (every tier referenced in `routing:` resolves in `resolution:`; every tier in `cost_rates:` resolves in `resolution:`).
4. `tools/verify/p01-model-routing-doc-shape.sh` — README-shape verifier confirming all five required sections + concrete-numeric assertion in the stability-metric section.

### Routing table contract (FR-3 + D-A6 + CON-3)

`templates/model-routing.yml` has three top-level sections:

```yaml
schema_version: "1.0"
type: model-routing-table
milestone: "M030"
created_at: "2026-04-30"

# Symbolic interface — characters map to symbolic tiers (per CON-3).
# CC-only at launch; codex-cli and cursor resolve to "inherit" per FR-6.
routing:
  mechanical:
    claude-code: fast
    codex-cli: inherit
    cursor: inherit
  standard:
    claude-code: balanced
    codex-cli: inherit
    cursor: inherit
  novel:
    claude-code: smart
    codex-cli: inherit
    cursor: inherit

# Per-runtime resolution — symbolic tiers to concrete model IDs.
# Hardcoded model IDs ONLY appear here (CON-3 closure invariant).
resolution:
  fast:
    claude-code: "claude-haiku-4-5"
    codex-cli: inherit
    cursor: inherit
  balanced:
    claude-code: "claude-sonnet-4-7"
    codex-cli: inherit
    cursor: inherit
  smart:
    claude-code: "claude-opus-4-7"
    codex-cli: inherit
    cursor: inherit

# Cost-rate SSOT (D-A6) — per-symbolic-tier USD per million tokens.
# Operator obligation to update on provider pricing changes
# (see references/model-routing.md ## Cost Rates SSOT).
# Values as of 2026-04-30 Anthropic published pricing for the
# claude-code runtime tiers.
cost_rates:
  fast:
    input_per_mtok: 1.00
    output_per_mtok: 5.00
  balanced:
    input_per_mtok: 3.00
    output_per_mtok: 15.00
  smart:
    input_per_mtok: 15.00
    output_per_mtok: 75.00
```

The exact model IDs and cost rates are operator-editable; the executor authors them based on the runtime's documented pricing at the moment of the commit. Recommended IDs above are illustrative and consistent with the existing `claude-opus-4-7` and `claude-haiku-4-5` references in this repo's CLAUDE.md and project tree. Exact verification of "current pricing" is not a phase-close gate — the doctor-config-check verifier (T04) gates the *shape*, not the *values*.

### Operator docs contract (D-A1 + D-A6 + #Q-3)

`references/model-routing.md` has five required sections in this order:

```markdown
# Adaptive Model Routing — Operator Reference

(Brief intro: this document describes templates/model-routing.yml.)

## Routing Table

(How (character × runtime) → symbolic-tier works. The classifier emits
character; this table resolves character + runtime into a symbolic tier.
Mechanical → fast; Standard → balanced; Novel → smart, with codex-cli
and cursor falling back to inherit per FR-6 / M009-deferred.)

## Per-Runtime Resolution

(How (symbolic-tier × runtime) → concrete model ID works. CON-3 closure:
hardcoded model IDs ONLY live in this section. Renaming a model is a
single-file edit here. Operators update this section when providers
release new models.)

## Cost Rates SSOT

(The cost_rates: section's contract. Per-symbolic-tier input/output USD
per million tokens. The SSOT consumed by metrics-rollup.sh --by-model
for the all-smart counterfactual computation. Operator obligation:
update cost_rates: when provider pricing changes — this is documented
here so operators have a clear update procedure. When cost_rates: is
absent or a tier is missing, metrics-rollup.sh --by-model emits a
"cost rates not configured" warning and a zero-savings line per FR-3.)

## Aggressive Overlay

(Opt-in operator overlay shape — for operators who want every standard
task routed to fast and every novel task routed to balanced. Lives at
.orchestrator/config.yml under model_routing.overlay: aggressive.
Documented but not the default; the default routing-table is the
conservative shipping defaults above.)

## Classifier-Confidence Stability Metric

(Concrete numeric thresholds — load-bearing contract for P02
shadow-compare.sh. The metric has two parts:

  - **Rolling per-class confidence-score variance threshold**: the
    classifier's confidence output is mapped to numeric scores
    (high=1.0, medium=0.5, low=0.0). For each class c ∈ {mechanical,
    standard, novel}, the rolling variance of the confidence-score
    sequence over the last N=20 dispatches in that class MUST be
    BELOW 0.10 for the class to be considered stable. (Variance of a
    sequence stuck at one value is 0; variance of a sequence
    flipping between high and low is ~0.25; the 0.10 threshold
    accepts modest medium↔high oscillation but rejects high↔low
    instability.)

  - **Minimum class-coverage count**: each class c MUST have at
    least 50 dispatches in the shadow corpus (matches FR-8's
    per-class evidence threshold for the `ready` verdict).

Both thresholds MUST be met for shadow-compare.sh to return
flip_recommendation=ready. If ≥2 of 3 classes meet both thresholds
AND the under-threshold class's routing-table default is `smart`,
shadow-compare.sh returns flip_recommendation=partially_ready
per D-A3.

Threshold rationale: 0.10 variance is conservative — empirical
classifier dogfood data is not yet available pre-flip, so the
threshold is set to reject sequences whose confidence-score range
spans more than ~0.5 units within the rolling window. Operators may
relax this to 0.15 in the aggressive overlay if dogfood data shows
the conservative threshold rejects acceptably-stable sequences.

The numeric thresholds are version-controlled here; changing them
is a documentation edit + a `references/model-routing.md` D-row in
DECISIONS.md, not a code change. P02's shadow-compare.sh reads
these values at runtime via the same YAML parser used for the
routing table — the executor's exact mechanism for parsing is a
P02 concern; T03's job is to nail the numeric contract.)
```

The five-section shape is gated by `tools/verify/p01-model-routing-doc-shape.sh`. The numeric-thresholds gate (`grep -q '0\.10' && grep -q 'N=20' && grep -q '50 dispatches'`) is part of that verifier — the section MUST have concrete numbers, not "TBD" placeholders.

### Routing-table-shape verifier (CON-3 closure)

`tools/verify/p01-routing-table-shape.sh` enforces:

1. File exists at `templates/model-routing.yml`.
2. YAML frontmatter has `schema_version`, `type: model-routing-table`, `milestone: "M030"`.
3. Three top-level sections present: `routing:`, `resolution:`, `cost_rates:`.
4. Every symbolic-tier name referenced in `routing:` (right-hand side of `claude-code:`, `codex-cli:`, `cursor:` lines, excluding the literal `inherit`) has a matching key in `resolution:`.
5. Every symbolic-tier name referenced in `cost_rates:` has a matching key in `resolution:`.
6. The character keys under `routing:` are the closed enum {mechanical, standard, novel}.
7. The symbolic-tier keys under `resolution:` and `cost_rates:` are the closed enum {fast, balanced, smart}.
8. Every `cost_rates:` tier entry has both `input_per_mtok:` and `output_per_mtok:` numeric values.

On all checks pass, emit `SUMMARY: p01-routing-table-shape.sh pass=N fail=0` and exit 0; on any fail, exit 1 with the diagnostic.

## Steps

1. **Author `templates/model-routing.yml`** per the contract in the Description above. Use the exact YAML shape (`schema_version`, `type: model-routing-table`, `milestone: "M030"`, three top-level sections). Recommended approach: use the Write tool to author the file in a single call.

2. **Author `references/model-routing.md`** per the five-section contract above. Use the Write tool. The Classifier-Confidence Stability Metric section MUST contain the concrete numeric values: `0.10` (variance threshold), `N=20` (rolling window), `50 dispatches` (per-class coverage floor). The section is the load-bearing P02 contract — TBD values are unacceptable per Plan-Time Discipline rule.

3. **Author `tools/verify/p01-routing-table-shape.sh`** per the eight-check contract above. Bash 3.2-compatible. AD-19 single-script-file shape. YAML parsing via `awk` walking section markers (`^routing:`, `^resolution:`, `^cost_rates:`) — no jq dependency. Closure check: build a list of tier-names-referenced-in-routing via `awk` and a list of tier-names-defined-in-resolution; for each referenced name (excluding `inherit`), assert it appears in the defined list. Same closure check for cost_rates → resolution.

4. **Author `tools/verify/p01-model-routing-doc-shape.sh`** with five header-presence checks and one numeric-thresholds check:

   - `grep -q '^## Routing Table$' references/model-routing.md`
   - `grep -q '^## Per-Runtime Resolution$' references/model-routing.md`
   - `grep -q '^## Cost Rates SSOT$' references/model-routing.md`
   - `grep -q '^## Aggressive Overlay$' references/model-routing.md`
   - `grep -q '^## Classifier-Confidence Stability Metric$' references/model-routing.md`
   - `grep -q '0\.10' references/model-routing.md` (variance threshold)
   - `grep -q 'N=20' references/model-routing.md` (rolling-window size)
   - `grep -q '50 dispatches' references/model-routing.md` (coverage floor)

   On all pass, emit `SUMMARY: p01-model-routing-doc-shape.sh pass=8 fail=0` and exit 0; on any fail, exit 1.

5. **Run the two T03 verifiers** to self-check:

   ```bash
   bash tools/verify/p01-routing-table-shape.sh
   bash tools/verify/p01-model-routing-doc-shape.sh
   ```

   Expected: both exit 0 with `SUMMARY:` lines reporting `pass=N fail=0`.

6. **Stage and commit.** Add `templates/model-routing.yml`, `references/model-routing.md`, `tools/verify/p01-routing-table-shape.sh`, `tools/verify/p01-model-routing-doc-shape.sh` and commit with `git commit -F <message-file>`. Recommended message: `M030/P01/T03: routing table + cost_rates SSOT + operator docs`.

## Must-Haves

This task satisfies the phase truths:

- "`templates/model-routing.yml` exists with three required top-level sections plus symbolic-tier closure" — gated by `tools/verify/p01-routing-table-shape.sh`.
- "`references/model-routing.md` exists with the five required sections and concrete numeric stability-metric thresholds" — gated by `tools/verify/p01-model-routing-doc-shape.sh`.

## Verification

```bash
bash tools/verify/p01-routing-table-shape.sh
bash tools/verify/p01-model-routing-doc-shape.sh
```

Each verifier uses single-script-file shape per AD-19. The first enforces FR-3 + CON-3 closure; the second enforces the operator-docs shape including the concrete classifier-confidence stability metric values.

## Inputs

### From Previous Tasks

- `scripts/dispatch/classify-task.sh` (from T02)
  - Key API: emits `character=<mechanical|standard|novel>` + `confidence=<high|medium|low>` to stdout. T03 does NOT invoke the classifier — the routing table is purely declarative — but `references/model-routing.md` documents the (character × runtime) → tier flow, which references the classifier as the upstream input.

### From Disk (Pre-existing)

- `specs/032-adaptive-model-selection/spec.md` FR-3 (line 629), FR-6 (line 632), FR-8 (line 634), FR-12 (line 638), CON-3 (line 679), SC-8 (line 659), CC-only-launch posture (under "Constraints" → "Pre-launch CC-only posture" in `M030-CONTEXT.md`).
- `.orchestrator/milestones/M030/M030-CONTEXT.md` D-A1 (lines 14-25; classifier-calibration semantics for the stability metric), D-A3 (lines 32-36; partially_ready verdict consumes the per-class threshold), D-A6 (lines 52-56; cost_rates: SSOT), D-A8 (lines 64-68; min_tier ≠ partial-flip).
- `templates/routing.yaml` — the existing pre-M030 routing config (different format, used by `select-model.sh` for non-M030 model selection); T03 does NOT modify this file. `templates/model-routing.yml` is a new sibling with M030-specific structure.
- `scripts/dispatch/select-model.sh` — existing routing pattern; reference for tier/model resolution shape. T03 does not call this script; it's documentation context.

## Constraints

- **CON-3 (per-runtime symbolic resolution)**: hardcoded model IDs MUST appear ONLY in the `resolution:` section. The `routing:` section refers to symbolic tiers (fast, balanced, smart, or `inherit`). The shape verifier enforces this closure.
- **D-A6 (cost_rates: SSOT)**: every symbolic tier in `resolution:` SHOULD have a matching `cost_rates:` entry; missing entries trigger a runtime warning per FR-3's fallback semantics, not a hard failure (FR-15 / SC-8). The shape verifier checks the *shape* of `cost_rates:` entries that ARE present, not that all three tiers have entries.
- **CC-only launch posture**: codex-cli and cursor resolve to `inherit`; T03 MUST NOT add adapter logic for those runtimes. M009 post-launch will revisit.
- **Bash 3.2 compatibility + AD-19 single-script-file shape**: the two verifier scripts MUST avoid all forbidden shapes (compound chains, plain subshells, `$()` containing pipes feeding compound operators, process substitution, heredocs feeding pipes).
- **No TBD in stability-metric section**: per Plan-Time Discipline (the M030/P01 plan-phase frontmatter explicitly blocks TBD here), the three numeric values (0.10, N=20, 50) are mandatory in `references/model-routing.md` and grep-asserted by the doc-shape verifier.
- **Plan-time confabulation guard for the YAML closure check**: the routing-table-shape verifier walks YAML by line-prefix matching (`^routing:`, indented `mechanical:` / `standard:` / `novel:`, doubly-indented `claude-code:` etc.). The grep / awk patterns MUST match the actual indentation in `templates/model-routing.yml`. Author both files in the same task so the verifier patterns can be tuned to the actual file shape.

## Expected Output

- `templates/model-routing.yml` — routing table + resolution table + cost_rates SSOT, ≥60 lines.
- `references/model-routing.md` — operator docs with five required sections + concrete numeric stability-metric values, ≥80 lines.
- `tools/verify/p01-routing-table-shape.sh` — symbolic-tier closure verifier, ≥50 lines.
- `tools/verify/p01-model-routing-doc-shape.sh` — README-shape + numeric-thresholds verifier, ≥35 lines.
- Both verifiers exit 0 on a clean run.

## Notes

Expected verifier output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p01-routing-table-shape.sh` → `OK: routing → resolution closure holds (3 tiers referenced, 3 defined)`, `OK: cost_rates → resolution closure holds`, `SUMMARY: p01-routing-table-shape.sh pass=N fail=0`, exit 0.
- `bash tools/verify/p01-model-routing-doc-shape.sh` → `OK: all 5 required sections present`, `OK: concrete numeric thresholds present (0.10 N=20 50 dispatches)`, `SUMMARY: p01-model-routing-doc-shape.sh pass=8 fail=0`, exit 0.

The classifier-confidence stability metric numeric values (0.10 variance / N=20 window / 50 per-class) are the load-bearing contract P02's `shadow-compare.sh` reads. P02 plan-phase MUST consume these values verbatim — any numeric drift between T03's commit and P02's `shadow-compare.sh` implementation is a P02 plan-phase blocker per the M030 cross-cutting concern "Classifier-confidence stability metric definition" (see `M030-ROADMAP.md` Cross-Cutting Concerns). The 50-per-class floor matches FR-8's `ready` threshold; the 0.10 variance threshold and N=20 window are T03 plan-phase determinations grounded in the conservative-shipping-defaults rationale documented in the operator docs section.

If the dogfood data after M030 ships shows the 0.10 threshold rejects acceptably-stable sequences, the relaxation path is documented in the operator docs (move to 0.15 in the aggressive overlay, OR ship a routing-table D-row updating the SSOT). The goal at T03 is a defensible conservative shipping default, not a calibration optimum.
