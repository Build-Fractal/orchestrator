---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M031"
name: "build-context.sh --profile=quick|standard|full + --meta-out JSON sidecar (FR-2 + AD-11), additive surface only"
depends_on: []
---

## Prerequisites

- P00 complete: `specs/034-right-sized-entry/spec.md` carries AD-1..AD-20 fold-in (verified by `bash tools/verify/p00-spec-foldin-shape.sh`).
- P00 complete: `templates/orchestrator-config-default.yml` declares the three M031 knobs at the P00 pinned defaults (`quick_knowledge_token_budget: 800`, `entry_routing_confidence_floor: 0.7`, `tier_a_plus_prompt_summary_lines: 8`); verified by `bash tools/verify/p00-config-defaults-pinned.sh`.
- P00 complete: `references/RUNTIME-ASSUMPTIONS.md` documents the M018 tier-1 `inline_threshold_tokens=1500` value (verified by `bash tools/verify/p00-runtime-assumptions-foldin.sh`).
- P00 complete: 20-task corpus exists under `tests/m031-acceptance/fixtures/empirical-baseline/` (`task-01.txt` through `task-20.txt` plus `CORPUS-MANIFEST.md`).
- P00 complete: `tests/m031-acceptance/empirical-baseline.sh` exists with the `--post-m031-emitter <path>` seam (verified by `bash tools/verify/p00-baseline-harness-shape.sh`).
- P00 complete: pre-M031 baseline frozen at `tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-baseline.jsonl` (20 records).
- The live Quick-skip branch in `commands/dispatch.md:21` ("Skip payload assembly") is STILL live at T01 entry. T01 MUST NOT touch `commands/dispatch.md`. The skip-branch removal is T02's job, gated on T02's post-M031 capture.

## Description

T01 extends `scripts/dispatch/build-context.sh` with two additive flags — `--profile=quick|standard|full` (FR-2) and `--meta-out <file>` (AD-11) — and ships three shape verifiers under `tools/verify/`. T01 is purely additive on the build-context.sh surface: existing positional invocation form (`build-context.sh <orch_root> <milestone> <phase> <task>`) MUST keep working byte-for-byte, and the existing JSONL `payload_breakdown` schema MUST keep emitting (with new fields added additively, not overwriting any existing field).

The `--profile=quick` policy:
- **Scope**: touched-files-only (parse the task plan's `Inputs` / `Files Likely Touched` sections; if no touched-file set is derivable, fall back to the milestone or project root scope identical to today's degenerate-plan behavior — not a regression).
- **Traversal**: 1-hop direct knowledge-graph hits only. Use `scripts/knowledge/traverse-graph.sh` with depth=1 (or equivalent). Do not chase provenance edges beyond the immediate hop.
- **Decisions section**: omit entirely (no Decisions section in the assembled payload).
- **Glossary slice**: include only entries whose terms appear in the touched-file set.
- **Compression**: M018 tier-1 + tier-2 apply per existing `compression.tier1.enabled` / `compression.tier2.enabled` flags. Tier-3 stays gated by the existing `TIER3_INTENSITY_FLOOR` (Quick skips T3 per FR-14 of M018).

The `--profile=standard` policy:
- **Scope**: phase scope (today's default).
- **Traversal**: 2-hop graph traversal.
- **Decisions section**: phase-relevant rows.
- **Glossary slice**: phase-touched terms.

The `--profile=full` policy:
- **Scope**: milestone-plus-dependencies.
- **Traversal**: full provenance.
- **Decisions section**: all milestone Decisions.
- **Glossary slice**: full glossary.

The `--meta-out <file>` flag writes a JSON sidecar with the minimum AD-11 schema:

```json
{
  "mem_count": <int>,
  "total_tokens": <int>,
  "profile": "<quick|standard|full>",
  "compression_applied": <bool>,
  "snip_applied": <bool>
}
```

Schema is additive — implementations MAY add fields, but the five named keys MUST appear with the named types. The sidecar is the cross-milestone interface contract for M029's `orchestrator:where` summary line and M036's reference-corpus ingest scoping (both consume the sidecar without reinventing the interface).

## Steps

1. **Read the existing `scripts/dispatch/build-context.sh`** (5500+ lines; read the CLI parsing section near the top and the JSONL emission section near the bottom). Identify (a) where positional args are parsed, (b) where the manifest table is assembled, (c) where the JSONL `payload_breakdown` record is emitted, (d) where `traverse-graph.sh` is invoked.

2. **Add CLI parsing for `--profile=quick|standard|full` and `--meta-out <file>`.** Extend the existing arg-parsing loop (do not introduce a new parser). Default profile MUST be inferred from the existing intensity-metadata pathway when no explicit `--profile` is supplied (so the existing positional call shape stays byte-equal). Reject unrecognized profile values with a stderr diagnostic + exit 1.

3. **Implement profile-aware scope/traversal/decisions/glossary policy.** Branch on the resolved profile value:
   - For `quick`: derive touched-file set from the task plan's `Inputs` + `Files Likely Touched` sections; pass `--depth 1` (or equivalent) to `scripts/knowledge/traverse-graph.sh`; skip the Decisions section assembly entirely; filter the glossary to terms appearing in the touched-file set.
   - For `standard`: today's behavior. No code change beyond labelling the branch as the `standard` default.
   - For `full`: extend scope to milestone + dependencies; traversal depth = unbounded (full provenance); include all milestone-scoped Decisions; full glossary.

4. **Implement `--meta-out <file>` JSON emission.** After the payload assembly completes (including post-compression bookkeeping), if `--meta-out` was supplied, write the AD-11 schema JSON to the named file. Use plain `printf` and quote-escape carefully (no `jq` hard dependency per MEM001 — `jq` is optional fallback). Fields:
   - `mem_count`: integer count of MEMs included in the assembled Knowledge section.
   - `total_tokens`: integer payload token estimate (reuse the existing token-estimation function in build-context.sh — do NOT introduce a new estimator).
   - `profile`: literal string `quick`, `standard`, or `full`.
   - `compression_applied`: boolean — true iff any tier-1, tier-2, or tier-3 emission record fired during assembly; else false.
   - `snip_applied`: boolean — true iff any tier-2 snip emission record fired; else false.

5. **Update the JSONL `payload_breakdown` record** to include three new fields additively: `profile`, `knowledge_section_tokens`, and (where not already present) compression-tier counters (`tier1_replacements`, `tier2_snips`). Existing fields MUST remain byte-identical when the profile is unspecified (default behavior unchanged).

6. **Author `tools/verify/m031-p01-build-context-profile-shape.sh`.** Bash 3.2-compatible, executable. Behavior:
   - Assert `scripts/dispatch/build-context.sh` contains the literal substring `--profile` AND `--meta-out` AND `quick` AND `mem_count` AND `compression_applied`.
   - Assert that an invocation `bash scripts/dispatch/build-context.sh --profile=quick --task-plan tests/m031-acceptance/fixtures/empirical-baseline/task-01.txt --out /tmp/m031-p01-t01-payload.md --meta-out /tmp/m031-p01-t01-meta.json` exits 0 against a non-empty corpus task fixture.
   - Assert that `/tmp/m031-p01-t01-meta.json` after the invocation is a valid JSON object containing exactly the keys `mem_count`, `total_tokens`, `profile`, `compression_applied`, `snip_applied` (no fewer; additional keys allowed).
   - Assert `profile` value in the JSON sidecar equals `quick`.
   - Output: a single final stdout line `SUMMARY: m031-p01-build-context-profile-shape.sh pass=N fail=M`. Exit 0 iff fail=0.

7. **Author `tools/verify/m031-p01-quick-no-skip-branch.sh`.** Bash 3.2-compatible, executable. Behavior:
   - This verifier asserts the CON-1 invariant from build-context.sh's perspective: the script's body MUST contain a profile-aware branch that always reaches the manifest-assembly + payload_breakdown emission code path. Concretely: assert `scripts/dispatch/build-context.sh` does NOT contain a literal early-exit pattern matching `# skip context` (case-insensitive) AND contains the substring `payload_breakdown` (which is the JSONL record name proving every dispatch path emits one).
   - This is a build-context.sh-side check; the dispatch.md-side check (FR-4) is `m031-p01-dispatch-md-reconciliation.sh` shipped in T02.
   - Output: a single final stdout line `SUMMARY: m031-p01-quick-no-skip-branch.sh pass=N fail=M`. Exit 0 iff fail=0.

8. **Author `tools/verify/m031-p01-config-knobs-stable.sh`.** Bash 3.2-compatible, executable. Behavior:
   - Assert `templates/orchestrator-config-default.yml` contains exactly one occurrence of each of `quick_knowledge_token_budget: 800`, `entry_routing_confidence_floor: 0.7`, `tier_a_plus_prompt_summary_lines: 8` (stability check — P00 set these; P01 does not modify them).
   - Output: a single final stdout line `SUMMARY: m031-p01-config-knobs-stable.sh pass=N fail=M`. Exit 0 iff fail=0.

9. **Run all three new verifiers locally** to confirm exit 0. Run an integration smoke test:
   - `bash scripts/dispatch/build-context.sh --profile=quick --task-plan tests/m031-acceptance/fixtures/empirical-baseline/task-01.txt --out /tmp/m031-p01-t01-payload.md --meta-out /tmp/m031-p01-t01-meta.json`
   - Inspect `/tmp/m031-p01-t01-meta.json` and confirm the five-key schema appears.
   - Inspect `/tmp/m031-p01-t01-payload.md` and confirm the Knowledge section is present and the Decisions section is absent.

10. **Confirm `commands/dispatch.md` UNCHANGED.** Run `git diff --stat commands/dispatch.md` and confirm zero output. T01 has no business amending `commands/dispatch.md`; that is T02's job (post-AD-14 capture).

## Must-Haves

This task addresses the following Must-Haves from `P01-PLAN.md`:
- "scripts/dispatch/build-context.sh accepts --profile=quick|standard|full and --meta-out <file> flags" (Truth #1; Check via `m031-p01-build-context-profile-shape.sh`)
- "The Quick profile path runs build-context.sh end-to-end (CON-1 invariant)" (Truth #2; Check via `m031-p01-quick-no-skip-branch.sh`)
- "templates/orchestrator-config-default.yml is unchanged with respect to the three P00 knobs" (Truth #3; Check via `m031-p01-config-knobs-stable.sh`)

## Verification

```bash
bash tools/verify/m031-p01-build-context-profile-shape.sh
```

```bash
bash tools/verify/m031-p01-quick-no-skip-branch.sh
```

```bash
bash tools/verify/m031-p01-config-knobs-stable.sh
```

## Notes

- Each verifier MUST emit `SUMMARY: <script-name> pass=N fail=M` as its final stdout line and exit 0 iff `fail=0`. This is the standard P00 convention reused in P01.
- Compatibility note: when `--profile` is NOT supplied, build-context.sh MUST behave byte-identically to the pre-T01 implementation. This is what keeps T01 strictly additive and lets the live Quick-skip branch in `commands/dispatch.md:21` keep working until T02's AD-14 capture completes.
- Token-estimation reuse: the `total_tokens` field in the meta sidecar MUST reuse the existing build-context.sh estimator. Introducing a second estimator silently is a known false-pass shape (two estimators drift; tests pass against one and ship the other). One estimator, one field.
- D020 token hygiene (CON-7): comments and prose in build-context.sh and the new verifiers MUST NOT embed the literal scaffold-placeholder open-bracket-TODO-colon byte pattern inside backticked inline code; paraphrase or escape.

## Inputs

### From Previous Tasks

(No upstream tasks within P01.)

### From Disk (Pre-existing)

- `scripts/dispatch/build-context.sh` — existing dispatch payload assembler. T01 extends this file additively. Read CLI parsing, manifest assembly, JSONL emission, and traverse-graph invocation sections before editing.
- `scripts/knowledge/traverse-graph.sh` — graph-traversal helper. T01 invokes this with `--depth 1` for the Quick profile. Read the existing CLI surface to confirm `--depth` (or equivalent) exists; if not, T01 may extend it minimally.
- `templates/orchestrator-config-default.yml` — declares `quick_knowledge_token_budget: 800` (line near the new M031 knobs section), `compression.tier1.inline_threshold_tokens: 1500` (line ~87), `compression.tier1.enabled: true`, `compression.tier2.enabled: true`. T01 reads these knobs at runtime via `scripts/state/read-config.sh` (already used by build-context.sh).
- `references/RUNTIME-ASSUMPTIONS.md` — documents the M018 tier-1 `inline_threshold_tokens=1500` value. T01's verifier prose may reference this file.
- `tests/m031-acceptance/fixtures/empirical-baseline/task-01.txt` — corpus task fixture. T01's integration smoke test invokes build-context.sh against this fixture.
- `commands/dispatch.md` — existing intensity table at line 21 declares the Quick-skip branch. T01 MUST NOT modify this file. (FR-4 amendment lands in T02 after AD-14 capture.)

## Constraints

- **Bash 3.2 compatibility** (MEM001): no `declare -A`, no process substitution, no `$()` containing pipes inside conditionals.
- **Strictly additive** to `scripts/dispatch/build-context.sh`: existing positional invocation `build-context.sh <orch_root> <milestone> <phase> <task>` MUST work byte-equal post-T01.
- **No edits to `commands/dispatch.md`** in T01 (AD-14 single-window: skip-branch removal is T02's job, gated on T02's post-M031 capture).
- **No edits to `templates/orchestrator-config-default.yml`** in T01 (P00 owns the M031 knobs; T01's `m031-p01-config-knobs-stable.sh` is a stability assertion, not a write).
- **SC-12 scope-guard**: T01 MUST NOT touch `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, or `scripts/auto/loop/`.
- **CON-1 invariant**: build-context.sh after T01 has no "skip context" exit path; only profile-aware scope tightening.
- **Verifier path discipline (AD-19 + M032 Finding A)**: project-owned slug-bearing verifiers live under `tools/verify/`, NOT `scripts/verify/`. The M031-namespaced prefix `m031-p01-` avoids collision with M030's `p01-*` verifiers in the shared tree.

## Expected Output

After T01 completes:

1. `scripts/dispatch/build-context.sh` accepts the new `--profile=quick|standard|full` and `--meta-out <file>` flags. Existing positional invocation form is unchanged.
2. `tools/verify/m031-p01-build-context-profile-shape.sh` exists, executable, exits 0 (`SUMMARY: m031-p01-build-context-profile-shape.sh pass=N fail=0`).
3. `tools/verify/m031-p01-quick-no-skip-branch.sh` exists, executable, exits 0.
4. `tools/verify/m031-p01-config-knobs-stable.sh` exists, executable, exits 0.
5. `commands/dispatch.md` is byte-identical to its pre-T01 state.
6. Integration smoke: `bash scripts/dispatch/build-context.sh --profile=quick --task-plan tests/m031-acceptance/fixtures/empirical-baseline/task-01.txt --out /tmp/m031-p01-t01-payload.md --meta-out /tmp/m031-p01-t01-meta.json` exits 0; `/tmp/m031-p01-t01-meta.json` is a valid JSON object with the five required keys.

T01 leaves the system in a state where the live Quick-skip branch in `commands/dispatch.md:21` and the new `--profile=quick` Quick-with-knowledge path COEXIST. This coexistence is the AD-14 single-window. T02 closes the window.
