# Decision A brief — Candidate A structural shape

**Authored**: 2026-05-11 (post-Item-4/5/6/7 ship; Items 1, 2, 3 remain Open pending this decision).
**Scope**: resolves operator-decision-required gate captured in `blind-rerun-with-conformance/COMPARISON.md § Operator decision points` (Decision A). Decisions B and C are addressed after Decision A lands (see § Decisions B + C below).
**Decision authority**: operator. This brief surfaces the evidence; it does not bind the choice.

---

## What's at stake

The 2026-05-11 XXII+XII ratification deferred three substantive findings about Candidate A (Tier 2 XXII — Distribution Surface Integrity) to a follow-on amendment ledger. Items 1 + 2 + 3 of that ledger ask three apparently independent questions:

- **Item 1**: is Invariant 1 (single-source versioning) an application of Principle XI?
- **Item 2**: is Invariant 2 (force-include / manifest discipline) an application of Principle X?
- **Item 3**: does Invariant 3 (end-to-end install testing) belong in the constitution's Quality Gates section rather than as a constitutional invariant?

The original blind deliberation (2026-05-11 13:38) treated these as three separable questions and reached unanimous convergence on each, including the recommendation to **move Invariant 3 to Quality Gates** (final.md Convergence §3, Actionable Spec Changes P1 #4).

The dual-grounding rerun (2026-05-11 15:48) — run with the CONFORMANCE.md procedural fix from Item 8 — activated its arbiter via `disputes_remain` and produced a **structural reframe** that is architecturally incompatible with Pathway 1: Invariant 3 STAYS as a constitutional invariant and LEADS the principle; Invariants 1 and 2 become **enabling constraints** that exist to make Invariant 3's end-to-end surface verification determinate.

The two pathways cannot coexist. Choosing Pathway 1 forecloses the rerun's restructuring; choosing Pathway 2 forecloses the original's Quality Gates move and converts Item 1 from "ship-now reassignment" to "may not be needed (becomes enabling-constraint framing instead)."

Downstream effects:
- **Item 1**: Pathway 1 ships the unconditional reassignment of `scripts/verify/version-source-of-truth.sh` as a Principle XI enforcement script (with compliance note in XI's body). Pathway 2 keeps Invariant 1 in place and reframes it as "ensures the end-to-end test verifies a determinate version."
- **Item 2**: Pathway 1 ships the textual X-distinctness analysis with the rerun's bilaterally drafted sentence as the conclusion. Pathway 2 ships the same sentence but framed as "Invariant 2 is an enabling constraint on Invariant 3, not an independent application of X."
- **Item 3**: Pathway 1 ships the Quality Gates move. Pathway 2 keeps Invariant 3 in place and adds operational definitions for "fresh project fixture" and "works" (arbiter Dispute 1 ruling + Dispute 3 ruling).

---

## Pathway 1 — Quality Gates move (original blind run)

**Concrete shape on disk:**

1. Constitution `## Quality Gates` section gains a new bullet (verbatim from final.md Actionable Spec Changes P1 #4):
   > **Install gates**: every version-tag publication triggering the GH release automation workflow introduced in M035 runs each per-runtime installer against a committed fixture directory at `tests/fixtures/install-smoke/` (or produced by a deterministic generation script with byte-identical output) and verifies the project's status command exits 0. Ad-hoc freshly-generated directories are not acceptable; they produce non-deterministic environments that violate Principle IX.

2. CONFORMANCE.md Component-tier declarations table — XXII row's invariant enumeration loses Invariant 3. The PENDING/ACTIVE cap entry (already shipped 2026-05-11 in `6e0c837b`) drops the `installer-smoke.sh` row OR keeps it but reclassifies its PASS/FAIL fixtures as Quality-Gate-evidence rather than Criterion-3-enforcement-evidence. (Choice deferred to the ship commit; both are mechanically equivalent under Principle II.)

3. CONFORMANCE.md "Two-principle boundary" sub-table (shipped 2026-05-11 in `0edcdf29`) — the installer-script row's "verified by Invariants 1-3" cell updates to "verified by Invariants 1-2 + Quality Gate install-gates entry."

4. `.orchestrator/memory/constitution.md` Sync Impact Report header — Tier 2 XXII inheritance description updates from "three invariants" to "two invariants plus the constitutional Quality Gates install-gates entry."

5. Item 1 ships in same commit batch: Invariant 1 reassigned to Principle XI enforcement. `scripts/verify/version-source-of-truth.sh` documented as Principle XI's enforcement script with a one-paragraph compliance note appended to constitution.md § XI. CONFORMANCE.md XXII row loses Invariant 1 from its enumeration; the script appears in a new "XI enforcement" row.

6. Item 2 ships in same commit batch: textual X-distinctness analysis recorded in CONFORMANCE.md (or as an Item-2 evidence file under `.orchestrator/proposals/`). Rerun's bilaterally drafted sentence is adopted verbatim:
   > X governs whether policy is declared in templates rather than inferred at runtime — a constraint on configuration architecture; Invariant 2 governs whether distribution artifacts on disk match their declared manifests at ship time — a packaging completeness constraint.
   Conclusion: Invariant 2 is distinct from X; it survives as Candidate A's sole remaining constitutional invariant.

**Final Candidate A shape after Pathway 1**: a single-invariant principle (Invariant 2 only — force-include / manifest discipline). Invariant 1 reassigned to XI. Invariant 3 moved to Quality Gates. Distinctness from XI / X / VIII is constitutionally self-derivable.

**Principles cited in support (from original blind final.md):**

- **Systemic contradiction #3 — "Structural classification of quality gates vs. constitutional invariants"** (final.md L104–107). The constitution has distinct structural homes — constitutional principles for architectural mandates, Quality Gates for release evidence. The governance-home test: "would relaxing this requirement in a future release require constitutional deliberation, or would it be operational maintenance? If the answer is operational maintenance, it belongs in Quality Gates."
- **Contradiction R1 resolution** (final.md L60–62): unanimous Phase-3 convergence. Advocate conceded the structural misclassification after reading skeptic's cross-review.
- **Principle II + IX** (verification mechanism + reproducibility): the Quality Gates section is the constitution's existing structural home for release-time mechanical evidence. The install-gates bullet inherits Quality Gates' existing mechanical-gate enforcement.

---

## Pathway 2 — Restructure-in-place (dual-grounding rerun)

**Concrete shape on disk:**

1. CONFORMANCE.md Component-tier declarations table — XXII row's invariant enumeration is **restructured**, not shortened. Invariant 3 leads; Invariants 1 and 2 follow as enabling constraints with the agreed framing language (arbiter Dispute 2 Path A ruling):
   > Invariant 1 ensures the end-to-end test (Invariant 3) verifies a determinate version — without version SST, the test cannot confirm which artifact was installed; Invariant 2 ensures the end-to-end test covers the right files — without manifest completeness, the test verifies an incomplete surface.

2. Invariant 3 text gains two operational definitions (arbiter Dispute 1 + Dispute 3 rulings, verbatim):
   - **"Fresh project fixture"** definition:
     > A fresh project fixture is a temporary directory containing only the files the installer places there, with no prior `.orchestrator/` state. The fixture is created immediately before and destroyed immediately after each release gate run. Where a runtime requires pre-existing scaffold files before the installer can be invoked, those files MUST be enumerated explicitly in the smoke test fixture's documented preconditions and MUST NOT overlap with any file that the installation itself places. A fixture specification that requires runtime-specific preconditions must document those preconditions in a named fixture manifest file within `scripts/verify/`.
   - **"Works"** definition:
     > The installer invocation exits with code 0 and the resulting project's status command exits with code 0 and emits at least one line of output matching the structured status format. These are the minimum conditions for `installer-smoke.sh` to emit a deterministic PASS/FAIL without human judgment.

3. CONFORMANCE.md PENDING/ACTIVE cap entry (already shipped in `6e0c837b`) — the `installer-smoke.sh` row's "remaining conditions" cell updates: the cross-cap dependency on the "fresh project fixture" operational definition is **closed** (definition now lives in Invariant 3's body). The XI/X distinctness conditions become the only remaining cap conditions.

4. Item 2 X-distinctness sentence ships in same commit batch with rerun's enabling-constraint framing appended:
   > X governs whether policy is declared in templates rather than inferred at runtime — a constraint on configuration architecture; Invariant 2 governs whether distribution artifacts on disk match their declared manifests at ship time — a packaging completeness constraint. Invariant 2 is an enabling constraint on Invariant 3's end-to-end surface verification, not an independent application of X's runtime-policy governance. A PR can satisfy X while violating Invariant 2.

5. Item 1 ships as enabling-constraint textual analysis (NOT reassignment): Invariant 1's distinctness from XI is reframed as "does this version-stability constraint serve the Invariant 3 test's determinacy?" — answer: yes (per rerun's arbiter rationale). Invariant 1 stays in place; the XI structural argument is recorded in CONFORMANCE.md.

6. `.orchestrator/memory/constitution.md` Sync Impact Report header — Tier 2 XXII inheritance description updates to record the Invariant-3-leads restructure.

**Final Candidate A shape after Pathway 2**: a three-invariant principle with Invariant 3 as the load-bearing architectural mandate and Invariants 1-2 as named enabling constraints. Operational definitions for the test fixture and PASS/FAIL conditions live in Invariant 3's body. Distinctness from XI and X is preserved via the enabling-constraint framing.

**Principles cited in support (from rerun arbiter-resolution.md):**

- **Principle II (Evidence Before Claims)** — Verification is a mechanical gate; must-haves checkable without human judgment. The arbiter rules that the operational definitions are required pre-ratification to make Invariant 3 mechanically falsifiable.
- **Principle VI (State On Disk Is Truth)** — The text on disk is the authoritative commitment; CONFORMANCE.md annotations pointing to pending amendments do not retroactively make text falsifiable.
- **Principle XIV (No Speculative Complexity)** — Applied to governance process: single-commit constraints add procedural friction without incremental enforcement benefit. The cap's comprehensiveness is the operative enforcement.

---

## Side-by-side comparison

| Dimension | Pathway 1 (Quality Gates move) | Pathway 2 (Restructure-in-place) |
|---|---|---|
| **Constitutional shape impact** | Constitution gains a new Quality Gates bullet (install gates). CONFORMANCE.md XXII row shrinks from 3 invariants → 1 invariant + reassignment + Quality Gate. The constitution's existing structural homes are respected: architectural mandates in principle bodies, release evidence in Quality Gates. | CONFORMANCE.md XXII row restructures hierarchically: Invariant 3 leads, Invariants 1-2 become subordinate enabling constraints. Operational test-fixture definitions land inside the constitutional invariant's body. No change to Quality Gates section. |
| **Reader cognitive load** (future maintainer reading § VIII + § XXII + § Quality Gates) | **Lower.** A maintainer reads XXII as "system-design integrity for distribution artifacts" (clean architectural concerns: SST versioning, manifest completeness) and Quality Gates as "release-time mechanical evidence including install testing" (matches the section's existing pattern: verification artifacts, mechanical gates). The conceptual hierarchy is flat. | **Higher.** A maintainer reads XXII as "primarily about end-to-end install testing, plus two helper constraints that ensure the test is determinate." The conceptual hierarchy is inverted: what looks like architectural concerns (version SST, manifest discipline) become subordinated to a verification procedure (install testing). Operational test-fixture details appear in a constitutional invariant's body, which is unusual. |
| **Testability — Principle II mechanical-gate preservation** | **Preserved.** Quality Gates entries are mechanically checkable in the same way constitutional invariants are; the existing section already governs `## Quality Gates` mechanical-gate enforcement ("required artifacts MUST exist on disk with passing verification status"). Operational definitions ("fresh project fixture", "works") live in the Quality Gates entry's body — natural home for procedural definitions. | **Preserved with caveat.** The rerun's arbiter requires the operational definitions in Invariant 3's body for Principle II compliance. This works mechanically but locates procedural-test definitions inside a constitutional invariant — an unusual content type for that location. |
| **Reversibility cost** | **Low.** Moving a bullet between Quality Gates and an invariant body is a normal amendment shape. If Pathway 1 ships and a future ratification finds the restructure preferable, the reverse amendment is single-commit. | **Higher.** The restructure creates a hierarchical dependency (Invariant 3 leads; Invariants 1-2 are enabling). Reversing requires unwinding the dependency framing across CONFORMANCE.md + Sync Impact Report + any downstream documentation that references the hierarchy. |
| **Bilateral convergence content preservation** | Preserves: original blind's Quality-Gates classification (unanimous Phase-3 convergence after advocate concession); Item 1's unconditional reassignment (skeptic surviving + synthesizer recommendation); Item 2's X-distinctness sentence (drafted bilaterally in rerun, path-agnostic — usable here). Discards: rerun's restructuring framing. | Preserves: rerun's Invariant-3-leads restructure (bilateral Phase-3 convergence in rerun); rerun's operational definitions (arbiter binding rulings); rerun's enabling-constraint framing for Invariants 1-2. Discards: original blind's Quality-Gates classification (unanimous in original run); original's Item 1 reassignment default. |
| **Grounding strength** | Original run lacked the CONFORMANCE.md procedural input (Item 8 fix was identified BY this run but not yet applied). Substantive conclusions stand on principle-text reading without CONFORMANCE.md context. | Rerun had proper dual grounding (constitution.md + CONFORMANCE.md). Arbiter activated via `disputes_remain` and produced binding rulings. But: rerun grounded against post-ratification constitution (124b58f5…), not pre-ratification (d36e70eab8…) — Decision C caveat applies. |

---

## Recommendation

**Pathway 1 (Quality Gates move).** High confidence.

The decisive argument is structural-home fit. The constitution already has a Quality Gates section whose existing pattern — release-time mechanical evidence with required artifacts on disk and passing verification status — is exactly what Invariant 3 describes. End-to-end install testing IS release-time mechanical evidence: it runs at version-tag publication, it verifies output behavior, and its enforcement is a CI/release pipeline check, not a design-time constraint on the system.

The rerun's reframe (Invariant 3 is "the load-bearing architectural mandate that Invariants 1-2 exist to serve") is philosophically interesting but semantically inverts the content. The actual architectural mandates are "distribution artifacts must have a single-source version" (Invariant 1) and "distribution artifacts must match their manifests" (Invariant 2) — these are constraints on system design. "End-to-end install testing must run at every release tag" is a constraint on system verification procedure — a Quality Gate.

The strongest tell that Invariant 3 is operational, not architectural: the rerun's arbiter ruling required adding operational definitions ("fresh project fixture" — a `temporary directory containing only the files the installer places there...`; "works" — `exits with code 0 and the resulting project's status command exits with code 0...`) to make Invariant 3 mechanically falsifiable. These are test-fixture and PASS/FAIL definitions — inherently procedural content. The need to embed them in a constitutional invariant's body to satisfy Principle II is evidence that the content belongs somewhere that already houses procedural definitions: Quality Gates.

Counterargument considered: the rerun had stronger grounding (dual sources, arbiter activation). The procedural-soundness benefit of dual grounding is real and is the basis for the Item 8 fix being shipped already (`7390163e`). But the substantive structural conclusion is a secondary effect of the dual-grounding fix, not a direct consequence. The rerun's Invariant-3-leads framing emerged from Phase 3 cross-review under arbiter pressure to resolve disputes; the original's Quality-Gates classification emerged from Phase 3 mutual concession with unanimous convergence. Convergence-under-mutual-concession is at least as strong an evidence signal as arbiter-resolved disputes, and the original's conclusion fits the constitution's existing structural pattern.

If the evidence were genuinely balanced, this would be a values choice (reverence for the rerun's procedural rigor vs. respect for the constitution's existing structural pattern). It is not balanced. The constitution's Quality Gates section is a load-bearing structural fact, not a stylistic preference. Adding install gates there is the lowest-cognitive-load, highest-pattern-match destination, and the operational definitions the rerun introduces land cleanly in that destination instead of awkwardly in an invariant body.

**Confidence calibration**: high on Pathway 1 being structurally cleaner; medium-to-high on the procedural-rigor concern (rerun had better grounding) not being decisive. A reasonable operator could choose Pathway 2 to honor the rerun's findings as authoritative; the brief's recommendation is the evidence-stronger path, not the only defensible path.

---

## What ships under Pathway 1

Estimated 2–3 atomic commits, constitution bump v2.2.1 → v2.3.0 (MINOR — Quality Gates section gains a new bullet; XXII inheritance shape changes materially; Sync Impact Report header updates).

**Commit 1 — Constitution Quality Gates entry + Sync Impact Report bump:**
- Append `Install gates: …` bullet to `.orchestrator/memory/constitution.md` § Quality Gates (verbatim from original blind final.md P1 #4).
- Update constitution.md Sync Impact Report header: bump version 2.2.1 → 2.3.0; add MINOR amendment note documenting Quality Gates addition + XXII inheritance shape change; document amended sections.
- Update constitution.md trailer: `**Version**: 2.3.0 | **Last Amended**: 2026-05-11`.

**Commit 2 — CONFORMANCE.md restructure + Item 3 ship + Item 2 distinctness sentence:**
- Update CONFORMANCE.md XXII inheritance row: remove Invariant 3 from enumeration; reference the new Quality Gates entry as authoritative for end-to-end install testing.
- Update Two-principle boundary table (rows touching Invariants): adjust "verified by Invariants 1-3" → "verified by Invariants 1-2 + Quality Gate install-gates entry."
- Update Tier 2 XXII PENDING/ACTIVE cap entry: `installer-smoke.sh` row reclassifies from "Criterion 3 enforcement" to "Quality Gate evidence" (or row drops; choose at ship time).
- Add Item 2 X-distinctness analysis: drop the rerun's bilaterally drafted sentence into CONFORMANCE.md (Component-tier declarations section, Tier 2 XXII row evidence cell, or new ledger-item-evidence file under `.orchestrator/proposals/`).

**Commit 3 — Item 1 reassignment + CONSTITUTIONAL_CONVERSATIONS.md entry:**
- Reassign `scripts/verify/version-source-of-truth.sh` as Principle XI enforcement script (add compliance note paragraph to constitution.md § XI body).
- Update CONFORMANCE.md XXII inheritance row: remove Invariant 1 from enumeration; add new XI-enforcement-script row.
- Update CONFORMANCE.md Tier 2 XXII PENDING/ACTIVE cap: `version-source-of-truth.sh` row moves under XI enforcement (or drops from XXII cap and gains an XI enforcement-status row).
- Append CONSTITUTIONAL_CONVERSATIONS.md v2.3.0 entry following the v2.2.1 template (commit `0edcdf29`).
- Update `.orchestrator/proposals/M0XX-tier-2-xxii-xii-substantive-followups.md` Items 1, 2, 3 → Shipped with SHAs; top-line Status updated.

(Commits 2 and 3 may merge if the operator prefers a tighter atomic shape; the planner-template default is 2-3 commits.)

---

## What ships under Pathway 2

Estimated 2–3 atomic commits, constitution bump v2.2.1 → v2.3.0 (MINOR — XXII inheritance shape changes materially via restructure; operational definitions added; Sync Impact Report header updates).

**Commit 1 — CONFORMANCE.md Invariant-3-leads restructure + operational definitions:**
- Restructure XXII row's invariant enumeration: Invariant 3 first, Invariants 1-2 follow as named enabling constraints with the agreed framing language.
- Add the "fresh project fixture" and "works" operational definitions verbatim from the arbiter-resolution.md rulings into Invariant 3's body.
- Update the Tier 2 XXII PENDING/ACTIVE cap entry: `installer-smoke.sh` row's "fresh project fixture" cross-cap dependency closes (definition now lives in Invariant 3's body); XI/X distinctness conditions remain.

**Commit 2 — Item 2 X-distinctness sentence with enabling-constraint framing + Item 1 enabling-constraint textual analysis:**
- Append the rerun's X-distinctness sentence (verbatim from arbiter Dispute 2 Path A ruling) to CONFORMANCE.md, including the enabling-constraint reframe ("Invariant 2 is an enabling constraint on Invariant 3's end-to-end surface verification, not an independent application of X's runtime-policy governance").
- Author Item 1 textual analysis: Invariant 1's relationship to XI reframed as "does this version-stability constraint serve the Invariant 3 test's determinacy?" — answer yes; Invariant 1 stays as enabling constraint, not reassigned. Record in CONFORMANCE.md or evidence file.

**Commit 3 — Constitution Sync Impact Report bump + CONSTITUTIONAL_CONVERSATIONS.md entry + ledger close:**
- Update constitution.md Sync Impact Report header: bump version 2.2.1 → 2.3.0; document the XXII restructure (Invariant 3 leads; Invariants 1-2 as enabling constraints; operational definitions added).
- Update constitution.md trailer: `**Version**: 2.3.0 | **Last Amended**: 2026-05-11`.
- Append CONSTITUTIONAL_CONVERSATIONS.md v2.3.0 entry following the v2.2.1 template.
- Update `.orchestrator/proposals/M0XX-tier-2-xxii-xii-substantive-followups.md` Items 1, 2, 3 → Shipped with SHAs; top-line Status updated.

---

## Decisions B + C (addressed after Decision A)

**Decision B — Pre-ratification text amendments**: under Pathway 1, the operational definitions ("fresh project fixture" / "works") are still relevant because they would land in the Quality Gates install-gates entry's body, where procedural definitions naturally live. Recommend: include them in the Quality Gates entry as part of Commit 1 (this fits Pathway 1's structural-home argument). Under Pathway 2, the operational definitions are required pre-ratification (arbiter Dispute 1 ruling) and ship as part of Commit 1. Either way, they ship in this v2.3.0 amendment; no deferral to a later cycle.

**Decision C — Post-ratification constitution drift caveat**: recommendation is to annotate COMPARISON.md and the ledger with: *"post-ratification grounding caveat noted; not load-bearing for this audit conclusion. The rerun's substantive findings are accepted as authoritative because the procedural fix (Item 8) makes dual-grounding the new default for future deliberations, and re-running against the pre-ratification constitution would not surface different findings — XXII+XII's principle-specific scope arguments do not depend on whether XXII+XII references are present in the grounding constitution."* This is a one-line annotation if Decision A lands cleanly; no separate AskUserQuestion needed unless the operator's reading differs.

---

## Defer path

If the operator chooses "Defer all three": this brief lands as the read-only decision-prep artifact at `decision-a-brief.md`. Ledger Items 1, 2, 3 stay Open. Top-line Status of the ledger updates to note the brief's existence. No constitution changes ship. Decisions B and C also defer (they are downstream of Decision A).
