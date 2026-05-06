---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M029"
name: "Cross-milestone feature data-model contract (AD-6, FR-13, #Q-G5 + #Q-5 resolution)"
depends_on: []
---

## Prerequisites

- The `references/` directory exists and holds sibling design docs (`status-headline-shape.md`, `status-json-schema.md` from P01; `installation.md`, `state-machine.md`, `engine.md`); verify `[ -d references ]`.
- No file currently lives at `references/cross-milestone-feature-shape.md` (path-collision rule 6 already checked at plan-authoring time — clean).
- `tools/verify/` exists; the M029 P01 verifiers (`m029-p01-headline-shape-contract.sh` etc.) live there as shape precedents.
- The M029 spec body (`specs/037-roadmap-visibility-cli-ux/spec.md`) and context draft (`.orchestrator/milestones/M029/M029-CONTEXT.md` AD-6) define FR-13 and AD-6; the load-bearing pieces are restated inline below so the executor does not need to re-read those documents.
- The current spec frontmatter declares `milestone: "M029"` (singular). T01 introduces the optional plural `milestones:` list as an additive schema change; existing singular consumers continue to read correctly.

## Description

T01 ships the **AD-6 cross-milestone data-model design contract**. M029 ships `orchestrator:where` as a feature-grain renderer (FR-13: when a feature spec spans multiple milestones, render the full feature view and mark the active milestone within it). AD-6 locks the data model: feature-spec frontmatter MAY declare an explicit `milestones: [M###, ...]` list (additive); existing singular `milestone:` is retained for backward compatibility; the renderer does **reverse-lookup advisory validation** by enumerating `.orchestrator/milestones/M*/M*-EVALUATION.md`, grouping by `feature_ref`, and emitting a stderr warning on mismatch with the spec frontmatter (not a hard error per Principle XI; spec is authoritative).

T01 also resolves **#Q-5** (cross-milestone-inactive-render-shape): collapsed by default (one line per inactive milestone with progress bar + glyph state), `--expand-all` override expands every milestone's full phase tree.

Why ship the contract before the renderer code (Principle III): AD-6 is a public schema change to the feature-spec format. Inverting the order (writing renderer first, deriving contract later) would lock arbitrary parsing choices into the schema retroactively. The contract is upstream of the renderer in T03; T03's parsing logic asserts conformance with this contract via the gate verifier.

## Steps

1. **Create `references/cross-milestone-feature-shape.md`** (≥50 lines). Required H2 sections (gate verifier asserts each):

   - `# Cross-Milestone Feature Shape` (H1)
   - `## Purpose` — one paragraph naming FR-13 / AD-6 / `commands/where.md` / `scripts/diagnostics/render-position.sh` as consumers; states this contract is the SSOT for the cross-milestone data model; references `.orchestrator/milestones/M029/M029-CONTEXT.md` AD-6 as the authorising decision.
   - `## Frontmatter Schema` — documents the schema rule:
     - **Singular form** (legacy, retained): `milestone: "M###"` — single canonical milestone for the feature.
     - **Plural form** (new, AD-6): `milestones: [M###, M###, ...]` — explicit list when the feature spans multiple milestones; the FIRST element is the canonical entry point.
     - **Exactly-one-of**: a feature spec MUST declare exactly one of the two; declaring both is a schema violation; declaring neither implies the spec is feature-less (e.g. an architectural amendment) and `where` does not render it.
     - **Backward compatibility**: existing specs with only `milestone:` continue to parse correctly without modification; the M033 spec migration (AD-6 / NG-3 noted in M029-CONTEXT) is **not** part of M029.
   - `## Reverse-Lookup Advisory Validation` — documents the renderer-side check:
     - At render time, `render-position.sh` enumerates `.orchestrator/milestones/M*/M*-EVALUATION.md` and groups by `feature_ref:` field.
     - For each feature, the renderer cross-references the spec's frontmatter (`milestone:` or `milestones:`) against the discovered set.
     - On mismatch, the renderer emits `WARN: feature <slug> spec frontmatter declares <set>; reverse-lookup discovered <set>; using spec` on stderr and uses the spec's declaration (Principle XI — spec is authoritative).
     - The advisory is **never a hard error**; render proceeds. Spec drift is a known operational pattern that the renderer surfaces but does not block on.
   - `## Inactive Milestone Render Shape` — documents the #Q-5 resolution:
     - **Default**: collapsed (one line per inactive milestone — `<glyph> M### <name>  ▓░ X% (k/n phases)`).
     - **`--expand-all`**: expands every milestone's full phase tree (active + inactive).
     - **Active milestone**: always expanded regardless of flag.
     - The active milestone is identified via `scripts/state/find-active-milestone.sh`.
   - `## Marker Glyph Set` — documents the canonical glyph alphabet used by `where`:
     - `✓` — phase / task complete.
     - `▶` — phase / task currently executing.
     - `◇` — phase / task pending (not yet started).
     - `✗` — phase / task failed (last verify result was `fail`).
     - `▽` — savings marker for `--live` mode (FR-8); canonical compact form is `▽ saved Nk` per #Q-G8 resolution. The verbose form (`▽ saved Nk via tier1 cache reuse`) is reserved for a future `--verbose` mode and MUST NOT appear in v1 fixtures or verifiers.
   - `## Cross-References` — names `commands/where.md` (consumer), `scripts/diagnostics/render-position.sh` (consumer), `scripts/diagnostics/summarize-milestone.sh` (consumer), `scripts/state/find-active-milestone.sh` (active-milestone resolver), the spec entries (FR-13), `.orchestrator/milestones/M029/M029-CONTEXT.md` (AD-6 + #Q-5 + #Q-G8 resolution authorities).

2. **Author `tools/verify/m029-p02-cross-milestone-shape-contract.sh`** (≥30 lines, executable, single-script-file shape). The verifier MUST follow AD-19 — straight-line bash, no inline compound, no plain subshells, no `$(…)` containing pipes. Use `grep -F` with separate invocations per assertion. Pattern after `tools/verify/m029-p01-headline-shape-contract.sh`:

   - First gates on file existence: `[ ! -f references/cross-milestone-feature-shape.md ]` → FAIL with "references/cross-milestone-feature-shape.md missing".
   - Asserts every required H1/H2 header exists via `grep -F` (one assertion per call; record pass/fail using parallel indexed arrays per MEM001):
     - `# Cross-Milestone Feature Shape`
     - `## Purpose`
     - `## Frontmatter Schema`
     - `## Reverse-Lookup Advisory Validation`
     - `## Inactive Milestone Render Shape`
     - `## Marker Glyph Set`
     - `## Cross-References`
   - Asserts the schema literal tokens appear: `milestone:`, `milestones:`, `M###`, `feature_ref`.
   - Asserts the four canonical glyphs each appear literally: `✓`, `▶`, `◇`, `✗`, `▽`.
   - Asserts the canonical compact savings form `saved Nk` appears AND the forbidden verbose form `via tier1 cache reuse` does NOT appear (assert by `grep -q -F` returning 1).
   - Asserts the AD-6 + FR-13 + #Q-5 + #Q-G8 spec references appear.
   - Asserts the `--expand-all` flag is named.
   - Asserts the `WARN:` advisory token is documented.
   - Emits `PASS:` per assertion + final `SUMMARY: m029-p02-cross-milestone-shape-contract.sh pass=N fail=M` line. Exit 0 iff `fail=0`.

3. **Mark the verifier executable**: `chmod +x tools/verify/m029-p02-cross-milestone-shape-contract.sh`.

4. **Run the verifier** — should exit 0 with `fail=0` after T01 completes. It runs again in T05's phase-suite as gate 1.

## Must-Haves

This task addresses these P02 phase truths:
- The AD-6 cross-milestone data-model contract document exists and pins the schema rule, advisory validation, and inactive-render shape.

This task creates these P02 phase artifacts:
- Cross-milestone shape contract document at `references/cross-milestone-feature-shape.md` — pins the AD-6 schema rule + #Q-5 + #Q-G8 resolutions.
- Cross-milestone contract gate verifier at `tools/verify/m029-p02-cross-milestone-shape-contract.sh` — mechanical enforcement of every required section, glyph, spec reference.

## Verification

```bash
bash tools/verify/m029-p02-cross-milestone-shape-contract.sh
```

## Inputs

### From Previous Tasks

None. T01 is independent of T02; both run before T03.

### From Disk (Pre-existing)

- `references/status-headline-shape.md` — sibling P01 contract; T01 mirrors its 8-section H2 structure.
- `references/status-json-schema.md` — sibling P01 contract; T01 mirrors its versioning-policy section style.
- `tools/verify/m029-p01-headline-shape-contract.sh` — verifier shape precedent. T01's verifier mirrors its straight-line bash + `grep -F` per-assertion pattern (AD-19 compliant).
- `.orchestrator/milestones/M029/M029-CONTEXT.md` — AD-6, #Q-5, #Q-G8 authorities (restated inline above).
- `specs/037-roadmap-visibility-cli-ux/spec.md` — FR-13 + active milestone declaration (`milestone: "M029"`).

## Constraints

- The contract document MUST NOT contain executable code, only documentation. Implementation lives in T03 (`render-position.sh` parsing logic). Per Principle III + AD-6, contract is upstream of code.
- The verifier MUST be straight-line bash per AD-19. NO inline compound chains, NO plain subshells (`( ... )`), NO `$(…)` containing pipes, NO process substitution. Use parallel indexed arrays for pass/fail tracking (MEM001 / MEM002 — bash 3.2 compatible).
- Per CON-7 + AD-8: T01 introduces NO new schema additions to M013 sidecar, M019 JSONL, M020 KNOWLEDGE.md, or M027 surfaces. The new `references/*.md` and `tools/verify/*.sh` files are the only artifacts.
- The forbidden marker form `via tier1 cache reuse` MUST NOT appear anywhere in this task's deliverables (#Q-G8 resolution).

## Expected Output

After T01 completes:
- `references/cross-milestone-feature-shape.md` exists with all seven required H2 sections + the AD-6 schema rule + #Q-5 + #Q-G8 resolutions.
- `tools/verify/m029-p02-cross-milestone-shape-contract.sh` exists, is executable, and exits 0 when run from project root.
- A summary file at `.orchestrator/milestones/M029/phases/P02/tasks/T01-cross-milestone-data-model-SUMMARY.md` documents the deliverables.

## Notes

Expected verifier output: `PASS:` lines for each assertion (≈14–18 assertions), ending with `SUMMARY: m029-p02-cross-milestone-shape-contract.sh pass=N fail=0`. The phase-suite aggregator (T05) chains this verifier as gate 1.

Why ship contract first (Principle III): every later P02 task reads at least part of this contract. T03's `render-position.sh` reads the schema rule and glyph set. T04's fixtures use the canonical glyph set. T05's phase-suite gate-1 enforces the contract is on disk before any later gate runs. Shipping the contract first keeps every implementation honest.

The reverse-lookup advisory is **deliberately advisory** rather than a hard error per Principle XI: the spec frontmatter is authoritative, and a transient mismatch (e.g. M### dir was created but M###-EVALUATION.md hasn't been written yet) should not block render. The `WARN:` channel surfaces drift without crashing the operator's `where` invocation.
