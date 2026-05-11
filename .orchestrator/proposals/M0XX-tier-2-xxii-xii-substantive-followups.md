# Proposal: Tier 2 XXII + conversus Tier 2 XII — Substantive Follow-Ups (deferred from Path 1)

**Captured**: 2026-05-11 (alongside the Path 1 ratification of the original Tier 2 XXII + XII inheritance amendment).
**Status**: Open — awaiting demand signal before queue entry.
**Predecessor**: `.orchestrator/proposals/constitution-amendment-inclusion-criteria.md` (closed at v2.2.0, 2026-05-11).
**Originating decision packet**: `.orchestrator/comments/review-queue/2026-05-11-XXII-XII-blind-substantive-findings.md` (Path 1).
**Originating blind deliberation**: `.orchestrator/ratification/2026-05-11-XXII-XII/blind-evidence/`.

---

## Why this proposal exists

The 2026-05-11 ratification of Tier 2 XXII + conversus Tier 2 XII shipped under operator-selected **Path 1**: accept the three headline-PASS verdicts (originating + self-consistency + blind), defer the blind's substantive distinctness findings to a follow-on amendment. This file captures those deferred findings so future amendment authors don't re-derive them from the blind-evidence tree, and so the headline-PASS provenance is never misread as "no findings."

The six deferred items below are listed verbatim from the decision packet's "Three resolution paths" Path 2 + Path 3 framing. Each is independently authorable as a future MINOR or PATCH amendment; they do not need to ship together.

---

## Deferred Item 1 — Candidate A Invariant 1 distinctness analysis (XXII vs Principle XI)

**Origin**: blind P1 finding S1 (disputed); arbiter resolution.md (Dispute 1 ruling).

**Question**: is Invariant 1 (single-source versioning) an application of existing Principle XI (Single Source of Truth) rather than a separate principle?

**Skeptic's default** (S1): unconditional reassignment of `scripts/verify/version-source-of-truth.sh` as an XI enforcement script with a compliance note in XI's body.

**Advocate's counter** (A-N1): PATCH-then-decide branching — first PATCH XI to name the version-source script as enforcement; if independent motivation surfaces (e.g., installer-channel-specific versioning constraints), retain Invariant 1 as XXII-distinct.

**Resolution path**: textual analysis against Principle XI's body in `.orchestrator/memory/constitution.md` § XI. If XI covers single-source versioning *as written*, reassign; if reassignment leaves a behavioral-correctness gap (the install-channel coverage XXII intends), retain.

---

## Deferred Item 2 — Candidate A Invariant 2 distinctness analysis (XXII vs Principle X)

**Origin**: blind P1 finding S6 (bilateral).

**Question**: is Invariant 2 (force-include discipline / manifest coverage) an application of Principle X (Templating Over Inference) rather than a separate principle?

**Evaluation prerequisite** (not yet performed): first-principles textual analysis. A `manifest.txt` that MUST be explicitly populated for every bundle file — is that a "declared in templates, not inferred at runtime" application of X?

**Two outcomes**:
- If X covers: reassign `manifest-coverage.sh` as a Principle X enforcement script. Combined with Item 1's reassignment, Candidate A has zero surviving distinct constitutional content; the XXII inheritance shape collapses to "XI gets a PATCH; X gets a PATCH; Invariant 3 lands in Quality Gates" (no new principle slot).
- If X doesn't cover: Candidate A ratifies with Invariant 2 as its sole surviving content — a single-invariant XXII-equivalent.

---

## Deferred Item 3 — Candidate A Invariant 3 reassignment to Quality Gates

**Origin**: blind P1 finding S2 + S8 (unanimous).

**Statement**: Invariant 3 (end-to-end install testing) belongs in the constitution's `## Quality Gates` section, not as a constitutional invariant. Quality gates are operational; constitutional principles govern shape.

**Triggering condition**: "version-tag publication triggering M035 GH release automation."

**Resolution path**: a PATCH-level amendment moving the install-testing requirement to the constitution's Quality Gates section with the named triggering condition.

---

## Deferred Item 4 — Principle VIII PATCH prerequisite for Candidate B

**Origin**: blind P1 finding S4 + A-N2 (unanimous).

**Statement**: VIII's "configuration entry" wording is ambiguous about whether it covers config knobs (Candidate B's domain). The ambiguity must be resolved by PATCH amendment BEFORE Candidate B can be considered fully ratified; otherwise the scope boundary between VIII and Candidate B is contested-by-prose-only.

**Path 1's posture**: at v2.2.0 the VIII Tier 2 alignment paragraph was restored *as-is*, declaring the scope boundary via cross-reference to CONFORMANCE.md's three-bucket structure. This is the prose-only resolution the blind found insufficient.

**Resolution path**: a VIII PATCH amendment that promotes the scope-boundary statement from "see CONFORMANCE.md" cross-reference to constitutional-body text. The PATCH should land alongside the joint scope table (Item 5) in the same commit.

---

## Deferred Item 5 — Joint scope table for XXII / Candidate B overlap surfaces

**Origin**: blind P1 finding A8 modified to P1 + S-N1 (unanimous).

**Statement**: XXII / Candidate B overlap surfaces exist (e.g., a config knob that controls a distribution surface). The joint scope table assigns governance unambiguously: knob liveness → Candidate B (conversus Tier 2 XII); surface behavioral correctness → XXII (Distribution Surface Integrity).

**Where**: `CONFORMANCE.md` § Component-tier declarations, immediately after the Tier 2 XII three-bucket structure.

**Sequencing**: must be committed in the same batch as the VIII PATCH (Item 4).

---

## Deferred Item 6 — PENDING/ACTIVE tier with named consequence for stub scripts

**Origin**: blind P1 finding S-N2 + A1 modified (unanimous).

**Statement**: the three `scripts/verify/*.sh` stubs created in commit `11523319` (`version-source-of-truth.sh`, `manifest-coverage.sh`, `installer-smoke.sh`) are "infrastructure declared, never implemented." Without a named PENDING→ACTIVE promotion deadline + failure consequence, they violate Candidate B's own normative body (dead-infrastructure).

**Required**: declare PENDING → ACTIVE promotion deadline (e.g., "by next MAJOR" or "by first `v*` tag publication"), with named consequence on miss (e.g., XXII inheritance reverts to Provisional until implementations land).

---

## Deferred Item 7 — Mechanical-precision "reader" definition for conversus Tier 2 XII

**Origin**: blind P1 finding A2 modified + S5 modified (unanimous).

**Statement**: current "at least one reader in the codebase" wording is insufficient for static linter enforcement. Required:
- **Verbatim-pattern requirement**: linter looks for exact string match.
- **Dynamic-reader exception table**: config keys read via `${jq -r .field}` in shell need explicit allowlist or runtime introspection.

**Where**: lives in the scope-precision text of the inheritance declaration (CONFORMANCE.md) or in a co-shipped reference doc (e.g., `references/dead-infra-linter-conventions.md`).

---

## Deferred Item 8 — Procedural: CONFORMANCE.md as deliberation grounding

**Origin**: blind procedural finding S3 + A4 modified (unanimous).

**Statement**: future ratification deliberations should supply both `.orchestrator/memory/constitution.md` AND `CONFORMANCE.md` as `--source` grounding to the conversus presets. The blind preset's original design (constitution.md only, to test the candidates on their own merits without provenance) was insufficient — criterion (i) cannot be evaluated against the membership basis preamble without CONFORMANCE.md available.

**Resolution path**: update the three deliberation preset templates under `templates/conversus-presets/constitution-ratify-{originating,self-consistency,blind}.yml` to declare both `--source` files. Backport-compatible — existing deliberations stay valid; future ones get both files.

**Shipped (2026-05-11, commit `7390163e`)**: scope expanded beyond the proposal's 15-min YAML-only estimate when investigation revealed the consumer (`scripts/dispatch/adapters/tool/conversus-synth.py` + `scripts/dispatch/adapters/tool/conversus.sh`) only supported single-string `grounding_file:` and single-valued `--source`. Operator authorized the larger scope (option A). Single commit landed: (a) synth accepts new `grounding_files:` list key alongside legacy `grounding_file:` scalar; (b) synth `--source` flag now accepts repeated invocations (`action="append"`); (c) bash adapter accumulates repeated `--source` flags into a newline-separated set, validates each, threads each through to synth, and emits plural `grounding_sources:` / `grounding_source_hashes:` YAML list fields in gate-result frontmatter when count ≥ 2 (singular fields preserved for back-compat); (d) all three constitution-ratify preset YAMLs switched to `grounding_files:` list with `[constitution.md, CONFORMANCE.md]`. Back-compat verified — `m036-p03-conversus-preset-shape.sh` (tier-2-fidelity, single `grounding_file:`) and `m014-p04-pressure-test-preset.sh` (spec-pressure-test, single `grounding_file:`) both PASS unchanged. Synth + adapter smoke tests confirmed single-source / multi-source / no-source-on-required / bad-source paths all behave correctly.

**Dual-grounding validation re-run (2026-05-11, post-commit)**: blind pass re-run under the corrected dual-grounding shape to validate that Item 8's procedural fix produces stable headline verdicts. Output at `.orchestrator/ratification/2026-05-11-XXII-XII/blind-rerun-with-conformance/`; comparison note at `…/blind-rerun-with-conformance/COMPARISON.md`.

- **Headline**: PASS / PASS (both Candidate A and Candidate B per-principle blind verdicts) — original blind run also headline-PASS. The ratification's **procedural soundness is fully discharged** under proper dual-grounding.
- **Echo-bias check**: explicit PASS (no procedural FLAG) — neither agent referenced provenance (conversus / Tier 2 / build-fractal).
- **Substantive divergence**: meaningfully different per-principle structural recommendations. Rerun activated the arbiter via `disputes_remain` (3 core disputes), producing 13 spec-change recommendations (6 P1 / 4 P2 / 3 P3). Most consequential divergence: rerun **rejects** the original's "Invariant 3 → Quality Gates" central finding and instead **restructures** Candidate A so Invariant 3 leads with Invariants 1–2 as enabling constraints. Mapped to this ledger: Item 4 / Item 6 / Item 7 demand-signals confirmed or strengthened; Item 2 strengthened (X distinctness sentence drafted bilaterally); Items 1 / 3 require operator decision (the two runs propose architecturally incompatible Candidate A shapes); Item 5 carries forward unchanged.
- **Caveat**: rerun grounded against the post-ratification constitution (124b58f5ef…, v2.2.0 with Tier 2 XXII + XII references). Original blind grounded against the pre-ratification constitution (d36e70eab8…). A fully controlled re-run would require checking out the pre-ratification sha; the operator can authorize that follow-up if the post-ratification-constitution caveat is load-bearing for the audit conclusion.
- **Operator decision points** captured in `COMPARISON.md` § "Operator decision points": (A) Candidate A structural shape — original Quality-Gates-move vs rerun enabling-constraint restructure; (B) pre-ratification text amendments now landing as v2.2.0 PATCH/MINOR or deferred to v2.3.0; (C) post-ratification grounding caveat load-bearing or not. Until these decisions land, no amendments are made.
- **Operator note**: the conversus.sh `gate` invocation passed a directory as the `<output>` positional arg where a file path was expected, causing synth to write artifacts into the parent ratification tree and clobber three tracked files. Recovery: rerun artifacts moved to `blind-rerun-with-conformance/`; originals restored via `git restore`. Deliberation content is intact and uncontaminated — only destination paths were affected. Adapter ergonomics gap (path-shape validation in `<output>`) is a candidate for a paper-cut follow-up.

---

## Estimated effort

- Items 1+2 (textual analyses against XI and X): ~2 hours combined, single PR if both reassign; two PRs if outcomes differ.
- Item 3 (Quality Gates move): ~30 min PATCH amendment.
- Items 4+5 (VIII PATCH + joint scope table): ~1 hour, single PR (sequenced together per blind finding).
- Item 6 (PENDING/ACTIVE tier): ~30 min — a single dated commitment paragraph in CONFORMANCE.md + named consequence in the row.
- Item 7 (reader-precision definition): ~1 hour — depends on whether it lands in CONFORMANCE.md inline or in a new reference doc.
- Item 8 (preset grounding): ~15 min — three YAML edits.

**Total**: ~5 hours for the full deferred set, two or three coordinated PRs.

## Demand-signal trigger

This proposal stays Open until one of:
- A second downstream consumer (sibling orchestrator joining build-fractal, or a second project inheriting orchestrator's Tier 2 stance) needs the unresolved scope-boundary questions answered to author their own conformance declaration.
- A maintainer notices the stubs at `scripts/verify/*.sh` drifting (still empty months after the 2026-05-11 ratification) and wants to land Item 6's deadline-with-consequence before stub-rot calcifies.
- A future XII-class linter capability lands that requires the mechanical-precision "reader" definition (Item 7) for the dynamic-reader exception table.

Until one of those signals arrives, the headline-PASS ratification (v2.2.0) stands as authority; this proposal is the open ledger of what was deferred.
