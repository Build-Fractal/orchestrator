# Proposal: Tier 2 XXII + conversus Tier 2 XII — Substantive Follow-Ups (deferred from Path 1)

**Captured**: 2026-05-11 (alongside the Path 1 ratification of the original Tier 2 XXII + XII inheritance amendment).
**Status**: Shipped (Items 1–8) — Items 4, 5, 6, 7, 8 shipped 2026-05-11 (uncontested ship-now ledger; see per-item commits). Items 1, 2, 3 shipped 2026-05-11 under **Decision A Pathway 1** (Quality Gates move; operator selected this over Pathway 2 enabling-constraint restructure after reviewing the decision-a-brief.md evidence packet); constitution bumped to v2.3.0; per-item SHAs recorded below. **Decision B** (operational definitions for "fresh project fixture" + "works") resolved in-this-amendment — definitions land in the constitution Quality Gates Install gates bullet body. **Decision C** (post-ratification grounding caveat) resolved as not load-bearing — rerun's findings stand and dual-grounding is now the default for future deliberations per Item 8. Items 9+ (rerun-unique findings: section rename, Criterion 1/3 labels, echo-bias check institutionalization) not yet captured as ledger items — see COMPARISON.md § "New findings unique to the rerun." Pre-ratification Invariant 3 operational definitions (new finding #1 in that section) effectively close under Decision B — definitions live constitutionally at the Quality Gates destination; the rerun's Invariant-3-leads restructure (new finding #4) is foreclosed by Pathway 1 selection.
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

**Shipped (2026-05-11, this commit batch — see Commit 3 in `git log` for the precise SHA; the v2.3.0 amendment shipped Items 1+2+3 across three commits starting at `859bfd8c`)**: skeptic's default outcome adopted (unconditional reassignment) per Decision A Pathway 1 operator selection and the original blind run's synthesizer recommendation. `scripts/verify/version-source-of-truth.sh` is now Principle XI's installer-channel version SST enforcement script. New bullet appended to constitution.md § XI body declaring: the version string consumed by every per-runtime installer in `packaging/install/install-*.sh` and by every bundle manifest in `packaging/bundle/*/manifest.txt` MUST derive from the `CHANGELOG.md` top-line `## [X.Y.Z]` heading; no installer or manifest may embed a hardcoded version literal; enforcement script named. CONFORMANCE.md updates: XXII inheritance row's "Surviving constitutional content at v2.3.0" cell notes the reassignment; Two-principle boundary table installer-script row attribution split; PENDING/ACTIVE cap `version-source-of-truth.sh` row annotated with new Principle XI attribution (cap maturity tier and promotion conditions unchanged; the row stays in the XXII cap table by convention because the stub originated under XXII Invariant 1); failure-consequence rollup refined — `version-source-of-truth.sh` ADVISORY demotion now affects Principle XI's installer-channel SST enforcement claim, not Tier 2 XXII. Advocate's PATCH-then-decide path was not exercised; no independent motivation was identified to restrict XI's scope below its current textual coverage.

---

## Deferred Item 2 — Candidate A Invariant 2 distinctness analysis (XXII vs Principle X)

**Origin**: blind P1 finding S6 (bilateral).

**Question**: is Invariant 2 (force-include discipline / manifest coverage) an application of Principle X (Templating Over Inference) rather than a separate principle?

**Evaluation prerequisite** (not yet performed): first-principles textual analysis. A `manifest.txt` that MUST be explicitly populated for every bundle file — is that a "declared in templates, not inferred at runtime" application of X?

**Two outcomes**:
- If X covers: reassign `manifest-coverage.sh` as a Principle X enforcement script. Combined with Item 1's reassignment, Candidate A has zero surviving distinct constitutional content; the XXII inheritance shape collapses to "XI gets a PATCH; X gets a PATCH; Invariant 3 lands in Quality Gates" (no new principle slot).
- If X doesn't cover: Candidate A ratifies with Invariant 2 as its sole surviving content — a single-invariant XXII-equivalent.

**Shipped (2026-05-11, commit `cf4e90ba`)**: textual analysis concluded Invariant 2 is **constitutionally distinct from Principle X**. X-distinctness sentence adopted verbatim from the 2026-05-11 dual-grounding rerun's bilateral Phase-3 convergence (`blind-rerun-with-conformance/arbiter-resolution.md` Dispute 2 Path A "Required changes") — wording is path-agnostic and applies under Decision A Pathway 1: *"X governs whether policy is declared in templates rather than inferred at runtime — a constraint on configuration architecture; Invariant 2 governs whether distribution artifacts on disk match their declared manifests at ship time — a packaging completeness constraint. A PR can satisfy X while violating Invariant 2."* New CONFORMANCE.md sub-section "Tier 2 XXII — Invariant 2 / Principle X distinctness" records the sentence + reading + conclusion. Invariant 2 survives as Candidate A / Tier 2 XXII's sole surviving constitutional invariant; `scripts/verify/manifest-coverage.sh` continues as XXII's enforcement script under the existing PENDING/ACTIVE cap. The outcome's second branch ("X doesn't cover") applies; the first branch ("X covers → reassign and Candidate A collapses to zero content") was rejected on textual grounds.

---

## Deferred Item 3 — Candidate A Invariant 3 reassignment to Quality Gates

**Origin**: blind P1 finding S2 + S8 (unanimous).

**Statement**: Invariant 3 (end-to-end install testing) belongs in the constitution's `## Quality Gates` section, not as a constitutional invariant. Quality gates are operational; constitutional principles govern shape.

**Triggering condition**: "version-tag publication triggering M035 GH release automation."

**Resolution path**: a PATCH-level amendment moving the install-testing requirement to the constitution's Quality Gates section with the named triggering condition.

**Shipped (2026-05-11, commit `859bfd8c`)**: constitution v2.2.1 → v2.3.0 (MINOR — Quality Gates section gains new bullet; Candidate A / Tier 2 XXII inheritance shape changes materially). New bullet appended to constitution.md `## Quality Gates` § "Install gates": every version-tag publication triggering the GH release automation workflow introduced in M035 runs each per-runtime installer in `packaging/install/install-*.sh` against a fresh project fixture and verifies the installation works; both operational terms ("fresh project fixture" / "works") defined within the bullet body — Decision B resolved in-this-amendment, not deferred. Definitions adopted verbatim from the dual-grounding rerun's arbiter Dispute 1 + Dispute 3 rulings. Non-substitutability clause preserved: ad-hoc freshly-generated directories are not acceptable (Principle IX). Evidence: `scripts/verify/installer-smoke.sh` (PENDING per CONFORMANCE.md cap; this script now serves Quality Gate evidence rather than XXII Criterion 3 enforcement). Original blind run's structural-classification argument (final.md systemic contradiction #3: "would relaxing this requirement require constitutional deliberation, or operational maintenance? If operational maintenance, it belongs in Quality Gates") was the decisive factor over the dual-grounding rerun's Invariant-3-leads restructure proposal; the latter was foreclosed by operator selection of Pathway 1.

---

## Deferred Item 4 — Principle VIII PATCH prerequisite for Candidate B

**Origin**: blind P1 finding S4 + A-N2 (unanimous).

**Statement**: VIII's "configuration entry" wording is ambiguous about whether it covers config knobs (Candidate B's domain). The ambiguity must be resolved by PATCH amendment BEFORE Candidate B can be considered fully ratified; otherwise the scope boundary between VIII and Candidate B is contested-by-prose-only.

**Path 1's posture**: at v2.2.0 the VIII Tier 2 alignment paragraph was restored *as-is*, declaring the scope boundary via cross-reference to CONFORMANCE.md's three-bucket structure. This is the prose-only resolution the blind found insufficient.

**Resolution path**: a VIII PATCH amendment that promotes the scope-boundary statement from "see CONFORMANCE.md" cross-reference to constitutional-body text. The PATCH should land alongside the joint scope table (Item 5) in the same commit.

**Shipped (2026-05-11, commit `0edcdf29`)**: constitution v2.2.0 → v2.2.1 (PATCH). VIII opening declaration rewritten so the scope boundary between file-system reachability (Principle VIII) and variable-level config-knob liveness (inherited conversus Tier 2 XII) is constitutionally self-derivable from VIII's plain text without requiring cross-reference to CONFORMANCE.md. Wording adopted from the dual-grounding rerun's P1 #3 proposed text (`blind-rerun-with-conformance/arbiter-resolution.md`); the v2.2.0 Tier 2 alignment paragraph preserved as evidentiary elaboration. CONSTITUTIONAL_CONVERSATIONS.md entry added for the v2.2.1 amendment. Shipped in the same commit as Item 5 per the blind run's sequencing requirement.

---

## Deferred Item 5 — Joint scope table for XXII / Candidate B overlap surfaces

**Origin**: blind P1 finding A8 modified to P1 + S-N1 (unanimous).

**Statement**: XXII / Candidate B overlap surfaces exist (e.g., a config knob that controls a distribution surface). The joint scope table assigns governance unambiguously: knob liveness → Candidate B (conversus Tier 2 XII); surface behavioral correctness → XXII (Distribution Surface Integrity).

**Where**: `CONFORMANCE.md` § Component-tier declarations, immediately after the Tier 2 XII three-bucket structure.

**Sequencing**: must be committed in the same batch as the VIII PATCH (Item 4).

**Shipped (2026-05-11, commit `0edcdf29`)**: new `### Two-principle boundary` sub-section added to CONFORMANCE.md immediately after the Tier 2 XII three-bucket structure. Three-row table declares: `run-doctor.sh` ↔ Principle VIII (file-system objects); `check-dead-infra.sh` ↔ inherited Tier 2 XII (variable-level liveness in `templates/orchestrator-config-default.yml`); installer-script config-knob shapes inside `packaging/install/install-*.sh` ↔ inherited Tier 2 XXII behavioral-correctness scope (explicitly NOT governed by `check-dead-infra.sh` — installer mechanics would produce false positives). Sub-table includes a Cross-references block clarifying that the constitutional scope boundary is in VIII's text (v2.2.1, same commit) and this table is evidentiary. Shipped in the same commit as Item 4.

---

## Deferred Item 6 — PENDING/ACTIVE tier with named consequence for stub scripts

**Origin**: blind P1 finding S-N2 + A1 modified (unanimous).

**Statement**: the three `scripts/verify/*.sh` stubs created in commit `11523319` (`version-source-of-truth.sh`, `manifest-coverage.sh`, `installer-smoke.sh`) are "infrastructure declared, never implemented." Without a named PENDING→ACTIVE promotion deadline + failure consequence, they violate Candidate B's own normative body (dead-infrastructure).

**Required**: declare PENDING → ACTIVE promotion deadline (e.g., "by next MAJOR" or "by first `v*` tag publication"), with named consequence on miss (e.g., XXII inheritance reverts to Provisional until implementations land).

**Shipped (2026-05-11, commit `6e0c837b`)**: new `### Tier 2 XXII — PENDING/ACTIVE verifier-stub cap` sub-section added to CONFORMANCE.md after the Two-principle boundary table (commit `0edcdf29`). Tier name resolution: chose **PENDING/ACTIVE** (original blind P1 #10) over **Provisional** (rerun P1 #2 terminology) because CONFORMANCE.md already uses "Provisional" at two distinct compliance layers (Tier 1 audit status and Tier 2 inheritance-criterion-1-feasibility status); reusing the term for verifier-stub maturity would obscure which "provisional" applies. The two runs agree on the underlying mechanism; only the name diverges. Cap is comprehensive per the rerun's mechanical-precision requirement: status semantics (records normative intent, not a mechanical enforcement gate); promotion deadline (first `v*` tag publication — milestone-identifier, not calendar-date); automatic ADVISORY demotion on miss without recorded extension; re-promotion after demotion requires fresh three-deliberation ratification; ACTIVE promotion requires deterministic verdict=PASS|FAIL emission + paired green-path + red-path test fixtures (PASS-only is not sufficient) + CI wiring + recorded promotion entry. Per-stub state table enumerates outstanding conditions for each of `version-source-of-truth.sh`, `manifest-coverage.sh`, `installer-smoke.sh`. The `installer-smoke.sh` red-path fixture requires the "fresh project fixture" operational definition that the rerun proposes under Item 3 — noted as a known cross-cap dependency deferred until Decision A is resolved. Failure-consequence rollup: if any stub demotes to ADVISORY at first `v*` tag publication, the XXII row's status annotation updates to record Criterion 3 enforcement unmet; the XXII inheritance itself does not revert (Criterion 1 feasibility stands).

---

## Deferred Item 7 — Mechanical-precision "reader" definition for conversus Tier 2 XII

**Origin**: blind P1 finding A2 modified + S5 modified (unanimous).

**Statement**: current "at least one reader in the codebase" wording is insufficient for static linter enforcement. Required:
- **Verbatim-pattern requirement**: linter looks for exact string match.
- **Dynamic-reader exception table**: config keys read via `${jq -r .field}` in shell need explicit allowlist or runtime introspection.

**Where**: lives in the scope-precision text of the inheritance declaration (CONFORMANCE.md) or in a co-shipped reference doc (e.g., `references/dead-infra-linter-conventions.md`).

**Shipped (2026-05-11, commit `9fb08e8c`)**: definition lands in **two surfaces** to keep CONFORMANCE.md skim-readable while preserving authoritativeness for linter authors. (1) New reference doc at `references/dead-infra-linter-conventions.md` carries the full convention: three exhaustive reader classes, explicit non-reader cases, linter-implementation sketch, and the boundary with Principle VIII. (2) CONFORMANCE.md gains a short `### Tier 2 XII — Reader-precision definition` sub-section summarizing the three classes plus a `### Reader-exception table` initialized with a `(none recorded)` row — the empty-state row is itself load-bearing (it makes the empty contract visible so auditors don't mistake the table's absence for its emptiness). Verbatim text from the original blind run P1 #7 (`blind-evidence/summary/final.md`, modified A2 + S5 convergence) adopted; the dual-grounding rerun did not contradict or strengthen this finding (per `blind-rerun-with-conformance/COMPARISON.md` Divergence 6) so the original's specificity stands. Row validity rule: a row is valid only if all three of canonical YAML path, verbatim access pattern, and file(s) are non-empty — the no-evidence escape hatch is explicitly closed.

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

**No longer Open as of 2026-05-11**: all eight deferred items have shipped. The proposal is preserved as the audit record of the 2026-05-11 XXII+XII substantive-findings disposition. Items 9+ (rerun-unique findings — section rename "Mechanical verification" → "Mechanical verification feasibility"; Criterion 1/3 stub-row labels; echo-bias check institutionalization) are NOT shipped under this proposal and would require fresh ledger-item-creation deliberation if a future maintainer chooses to pursue them. The pre-ratification Invariant 3 operational definitions (rerun new-finding #1) effectively closed under Decision B — the definitions live constitutionally in the Quality Gates Install gates bullet body. The Invariant-3-leads restructuring (rerun new-finding #4) was foreclosed by operator selection of Pathway 1 and is not pursued further.
