---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M018"
name: "Conversus --strict gate run + archive + P01 summary"
depends_on: ["T02"]
---

## Prerequisites

T01 has authored `references/compression-grammar.md` v1.0.0 (frontmatter `status: Draft`); T02 has shipped the lint script and verifiers, appended the M018/P01 entry to `RUNTIME-ASSUMPTIONS.md`, and refreshed the CLAUDE.md / AGENTS.md `recent-changes` block via the dual-write helper. All five T02 verifiers pass:

- `bash scripts/verify/compression-grammar-lint.sh` exits 0.
- `bash scripts/verify/m018-p01-grammar-shape.sh` exits 0.
- `bash scripts/verify/m018-p01-lint-clean.sh` exits 0.
- `bash scripts/verify/m018-p01-sc9-traceability.sh` exits 0.
- `bash scripts/verify/m018-p01-runtime-assumptions.sh` exits 0.
- `bash scripts/verify/m018-p01-dual-write-recent.sh` exits 0.

If any of those fail, T03 does not start; fix in T02 first.

## Description

Run the conversus `--strict` red/blue advocate gate against `references/compression-grammar.md`, archive the result under `.orchestrator/milestones/M018/phases/P01/conversus/`, require a `verdict: "PASS"` to close P01, advance the grammar contract's frontmatter `status:` from `Draft` to `Reviewed`, ship the `m018-p01-conversus-pass.sh` verifier (the last truth check), and write `P01-SUMMARY.md`.

The conversus adapter (`scripts/dispatch/adapters/tool/conversus.sh`) is shipped via M011/P07 and accepts the `gate` subcommand with `--strict`. Calling shape:

```
bash scripts/dispatch/adapters/tool/conversus.sh gate --strict <preset-name> <artifact-path> <output-path>
```

`<preset-name>` is the basename (without `.yml`) of a preset under `templates/conversus-presets/`. T03 ships a new preset `compression-grammar.yml` shaped specifically for this gate — the existing `spec-pressure-test` preset would deliberate against the wrong evaluation criteria.

**Provider environment**: per the user's standing memory (feedback_conversus_provider_claude_code), every conversus invocation in this repo MUST set `CONVERSUS_PROVIDER=claude-code` because the default `anthropic` path returns 429 as a policy gate, not a transient error. Set this in the calling shell before each conversus run.

## Steps

1. **Author the gate preset** at `templates/conversus-presets/compression-grammar.yml`. Use `templates/conversus-presets/spec-pressure-test.yml` as the structural template (red-blue mode, blue/red advocates, arbiter grounded against the constitution). Replace the *charter* prose so advocates argue the right question:

   - Frontmatter:
     ```yaml
     ---
     schema_version: "1.0"
     type: conversus-preset
     ---
     ```
   - `preset_name: compression-grammar`
   - `description`: "Red-blue adversarial deliberation gating the M018 compression-grammar contract. Blue argues the per-tier preservation contracts, marker grammar, and SC-9 plausibility composition are sufficient to gate downstream tier implementations (P02–P05). Red argues the contract has a fatal preservation-gap, marker-grammar ambiguity, modeling-assumption fragility, or SC-9 composition flaw that would let parse-regression slip past the gate. Arbiter grounds verdicts in `.orchestrator/memory/constitution.md` (Principles II, III, XV)."
   - `mode: red-blue`
   - **blue-advocate** charter: defend that the four `## Tier:` sections specify enough to prevent parse-regression, that the marker grammar is unambiguous, that the preserved-pattern vocabulary covers the byte classes that would corrupt downstream parsers (frontmatter, code fences, paths, MEM IDs, command names, URLs, JSONL records, scaffold-placeholder markers), and that the per-tier modeling assumptions in the SC-9 section plausibly compose to ≥ 34.7%. Blue cites specific block names, regexes, and the P00 probe CIs verbatim.
   - **red-advocate** charter: argue at least one of: (a) a preserved-pattern is missing or under-specified such that a tier could corrupt it (e.g., nested code fences, JSONL records inside markdown, multi-line scaffold-placeholder markers); (b) the marker grammar `<!-- compressed:tierN ... -->` is ambiguous (e.g., kvpair value tokenization); (c) a per-tier `applies-to:` block names a class the corresponding `preserves:` block cannot defend (e.g., tier3 summarizes Knowledge sections but does not preserve MEM IDs verbatim across the boundary); (d) the SC-9 composition is fragile — overlap between tiers (filter drops tokens that tier3 would also have summarized) is hand-waved rather than derived from the probe.
   - **arbiter**: `grounding_file: .orchestrator/memory/constitution.md`; `verdict_contract: PASS|BLOCK`; description identical in spirit to spec-pressure-test (weigh disputes, ground in Principles II/III/XV, ties resolve to BLOCK).
   - **output**: `template: templates/gate-result.md`; `required_fields: [verdict, disputes, rationale, source_hash]`.

2. **Confirm the gate output directory exists** by creating it (idempotent):
   ```
   mkdir -p .orchestrator/milestones/M018/phases/P01/conversus
   ```

3. **Confirm CONVERSUS_PROVIDER is set** to `claude-code` in the calling shell:
   ```
   export CONVERSUS_PROVIDER=claude-code
   ```
   Skipping this step risks a 429 policy gate that looks transient but is not. The user has flagged this as standing policy.

4. **Run the conversus gate** at `--strict` against the grammar contract, with output landing under the phase's conversus directory:

   ```
   bash scripts/dispatch/adapters/tool/conversus.sh gate --strict \
     compression-grammar \
     references/compression-grammar.md \
     .orchestrator/milestones/M018/phases/P01/conversus/gate-result.md
   ```

   The adapter writes a structured `gate-result.md` with frontmatter (`verdict`, `disputes`, `rationale`, `source_hash`, `preset`, `artifact`, `conversus_output_dir`, `conversus_config`) plus a body section. The full deliberation transcripts (red, blue, arbiter, summary) are also written under `.orchestrator/milestones/M018/phases/P01/conversus/{red-advocate,blue-advocate,arbiter,summary}/`.

   **Note**: the adapter takes ~6 minutes wall-clock for a typical gate (per the script's own header documentation). Treat this as a long-running operation; do not poll inside the same task.

5. **Inspect the verdict** by reading the frontmatter of `gate-result.md`. The expected line is `verdict: "PASS"`.

   - **If PASS**: proceed to step 6.
   - **If BLOCK**: read the body's "Surviving disputes" / "Rationale" sections, append findings to a new `## Open Questions` block in `references/compression-grammar.md` (replacing the v1.0.0 placeholder line), revise the contract to address the disputes, bump the frontmatter `version` to `1.0.1` (or higher), re-run the gate at step 4 (output to a new dated subdirectory under conversus/ if you want history; or overwrite gate-result.md — the spec leaves this to the operator). P01 stays open until verdict is PASS.

6. **Advance the grammar contract's frontmatter `status:` from `Draft` to `Reviewed`**. Use `Edit` with `old_string: 'status: "Draft"'` / `new_string: 'status: "Reviewed"'`. Bump `last_revised:` to today (2026-04-27 or the actual gate-run date — use the date of the PASS verdict).

   This satisfies spec.md User Story 1 acceptance scenario 3: "on PASS, the contract document advances to `Status: Reviewed` (frontmatter)".

7. **Ship `scripts/verify/m018-p01-conversus-pass.sh`** — the last truth verifier:
   - Asserts `.orchestrator/milestones/M018/phases/P01/conversus/gate-result.md` exists.
   - Greps for the literal `verdict: "PASS"` in the frontmatter (the conversus adapter writes verdict on its own line near the top — see `specs/030-context-compression-layer/conversus/gate-result.md` line 2 for shape: `verdict: "BLOCK"`; ours must be `verdict: "PASS"`).
   - Asserts `references/compression-grammar.md` has `status: "Reviewed"` in frontmatter.
   - Single-script-file shape; ~25 lines.
   - Bash 3.2 compatible.

8. **Run all six P01 truth verifiers** to confirm the phase must-haves close:

   ```
   bash scripts/verify/compression-grammar-lint.sh
   bash scripts/verify/m018-p01-grammar-shape.sh
   bash scripts/verify/m018-p01-lint-clean.sh
   bash scripts/verify/m018-p01-sc9-traceability.sh
   bash scripts/verify/m018-p01-runtime-assumptions.sh
   bash scripts/verify/m018-p01-dual-write-recent.sh
   bash scripts/verify/m018-p01-conversus-pass.sh
   ```

   All seven must exit 0. (Six from T02 + one from this task.)

9. **Run the phase-level must-haves check**:

   ```
   bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P01/
   ```

   Must exit 0; lists all six artifacts + truth checks above.

10. **Author `P01-SUMMARY.md`** at `.orchestrator/milestones/M018/phases/P01/P01-SUMMARY.md`. Use the existing M018/P00-SUMMARY.md as a structural template. Required content:
    - YAML frontmatter (`schema_version: "1.0"`, `type: phase-summary`, `phase: P01`, `milestone: M018`, `status: complete`, `closed_at: <ISO date>`).
    - `## Closure summary` paragraph naming the three deliverables (grammar contract, lint script + RUNTIME-ASSUMPTIONS row, conversus gate PASS).
    - `## Conversus gate result` block: verdict, disputes count, surviving-dispute summary (if any survived a PASS verdict — strict mode will let some disputes survive even on PASS as long as the arbiter weighs them as non-fatal), `source_hash` from gate-result.md frontmatter.
    - `## Per-tier savings ceilings (defended)` block: cite the same per-tier numbers as the grammar contract (filter ≈ 13%, tier1 ≈ 6.3%, tier2 ≈ 25.5%, tier3 ≈ 12.2%; aggregate 34.7% / 35.08% / 35.39%).
    - `## Followups for downstream phases` block, with one bullet per phase P02–P07 naming what each consumes from this phase's contract (e.g., "P02 reads the filter `applies-to:`/`preserves:` blocks when implementing the knowledge-aware filter").
    - `## Risk-mitigation traceability` block tying P01 to the conversus gate's RISK-3 finding (US-7 promotion to P2 — handled spec-side, but P01 ships the contract that downstream Tier 3 quality work depends on).
    - Min 40 lines, contains literal `PASS` (per phase-plan artifact spec).

11. **Final sanity sweep** before declaring P01 closed: `bash scripts/state/derive-phase.sh .orchestrator/milestones/M018/`. Expected output: `executing` (because P02 has no plan yet) or `complete` (if P02+ already advanced via roadmap-derived state). Report observed state.

## Must-Haves

This task addresses the phase must-haves:

- Truth: "conversus `--strict` gate report shows PASS verdict before phase close" — implemented by step 4 + verified by step 7.
- Truth: "grammar contract advances to `Status: Reviewed`" — implemented by step 6.
- Artifact: `templates/conversus-presets/compression-grammar.yml` (created step 1).
- Artifact: `.orchestrator/milestones/M018/phases/P01/conversus/gate-result.md` (created step 4).
- Artifact: `scripts/verify/m018-p01-conversus-pass.sh` (created step 7).
- Artifact: `.orchestrator/milestones/M018/phases/P01/P01-SUMMARY.md` (created step 10).

## Verification

- `bash scripts/verify/m018-p01-conversus-pass.sh` — exits 0 (verdict=PASS + status=Reviewed).
- `bash scripts/dispatch/adapters/tool/conversus.sh parse-verdict .orchestrator/milestones/M018/phases/P01/conversus/gate-result.md` — emits `verdict=PASS`.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P01/` — exits 0; all phase artifacts + truths confirmed.
- `bash scripts/state/derive-phase.sh .orchestrator/milestones/M018/` — does not regress (state advances forward, never backward).

## Inputs

### From Previous Tasks

- `references/compression-grammar.md` (from T01) — the grammar contract document. Frontmatter `status: "Draft"` on entry; advanced to `"Reviewed"` by this task on PASS verdict.
- `scripts/verify/compression-grammar-lint.sh` (from T02) — the public lint gate (FR-1 / SC-1). T03 does not call it directly but the conversus adapter may; in any case the phase-level must-haves check (step 9) re-runs all verifiers.
- All five `m018-p01-*.sh` verifiers from T02 (grammar-shape, lint-clean, sc9-traceability, runtime-assumptions, dual-write-recent) — must still pass after T03's edits to the contract's frontmatter (`status:` Draft→Reviewed should not break any verifier).

### From Disk (Pre-existing)

- `scripts/dispatch/adapters/tool/conversus.sh` — the conversus adapter from M011/P07 (DEP-4). Subcommand `gate [--strict] <preset-name> <artifact-path> <output-path>`. Behavioral contract: writes `gate-result.md` with frontmatter `verdict: "PASS"|"BLOCK"`, plus full deliberation transcripts under `<output-path-dir>/{red-advocate,blue-advocate,arbiter,summary}/`. Pre-flight refuses artifacts containing `<TODO:` markers (`CONVERSUS_GATE_SKIP_TODO_CHECK=1` to bypass — do not bypass for the grammar contract; the contract must be author-clean).
- `templates/conversus-presets/spec-pressure-test.yml` — structural template for the new preset. Same red-blue mode, same arbiter shape; only the charter prose changes.
- `templates/gate-result.md` — output template the adapter renders into. Read once to confirm field names (verdict, disputes, rationale, source_hash) match what the verifier asserts.
- `.orchestrator/memory/constitution.md` — arbiter's grounding file. Principles II (Evidence Before Claims), III (Design Before Code), XV (Surgical Precision) are the principles the arbiter weighs against.
- `.orchestrator/milestones/M018/phases/P00/P00-SUMMARY.md` — structural template for the P01-SUMMARY.md to write at step 10.
- `specs/030-context-compression-layer/conversus/gate-result.md` — example of a prior conversus gate output on the M018 spec (the BLOCK-with-conditions pre-spec gate that drove D028). Useful as a shape reference; do not copy its content.

### From Environment

- `CONVERSUS_PROVIDER=claude-code` — REQUIRED export before step 4. Standing policy per user memory (anthropic 429 = policy gate, not transient).

## Constraints

- **CON-6 (conversus-gate-non-negotiable)** — the gate MUST run at `--strict` and MUST return PASS before P01 closes. BLOCK halts the phase; no fallback is acceptable.
- **CON-1 (read-mostly)** — this task creates exactly one new preset, one new verifier, the gate output (the adapter writes), and the phase summary. It edits the grammar contract's frontmatter `status:` field only (Draft → Reviewed).
- **AD-19 (script-file shape)** — the new verifier is single-script-file shape; conversus invocation is via the adapter's existing entry point.
- **AP-009 (compound-chain-gt2)** — pre-bash-shape-guard hook will fire on commit; new verifier respects the rule.
- **MEM029 / MEM030 (edition handling)** — the conversus adapter resolves `CONVERSUS_EDITION` (oss|paid) automatically; the `compression-grammar` preset must NOT declare `edition_required: paid` because M018 ships under the OSS-default. Verify the preset has no `edition_required:` line in frontmatter (or the line is `edition_required: oss` / absent).
- **Constitution Principle II (Evidence Before Claims)** — the gate verdict is the evidence; T03 does not paraphrase or selectively quote disputes. The verifier asserts the literal frontmatter value.
- **Constitution Principle III (Design Before Code)** — by closing P01 with a PASS verdict, this task confirms the design (grammar contract) is reviewable and adversarially-defensible before any tier code starts in P02.
- **Long-running operation** — conversus gate takes ~6 minutes. Do not embed it in a `Check:` command; it runs once at step 4. Truth verification is on the *artifact* the gate produces (gate-result.md), not on the gate run itself.

## Expected Output

```
$ export CONVERSUS_PROVIDER=claude-code
$ bash scripts/dispatch/adapters/tool/conversus.sh gate --strict \
    compression-grammar \
    references/compression-grammar.md \
    .orchestrator/milestones/M018/phases/P01/conversus/gate-result.md
... (~6 min) ...
PASS: gate complete; verdict=PASS; output=.orchestrator/milestones/M018/phases/P01/conversus/gate-result.md

$ bash scripts/verify/m018-p01-conversus-pass.sh
PASS: gate-result exists
PASS: verdict=PASS
PASS: grammar contract status=Reviewed

$ bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P01/
PASS: references/compression-grammar.md (200+ lines, contains "preserves:")
PASS: scripts/verify/compression-grammar-lint.sh (80+ lines, contains "applies-to")
... (one PASS per artifact)
PASS: all truth checks
PASS: all key links

$ bash scripts/state/derive-phase.sh .orchestrator/milestones/M018/
executing
```

P01 is closed. P02 (Knowledge-Aware Filter) is the next phase per the M018 roadmap; its plan is generated by a fresh invocation of `orchestrator:plan-phase`.
