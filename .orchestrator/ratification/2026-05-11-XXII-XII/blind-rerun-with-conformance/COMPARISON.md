# Blind-rerun comparison: original (2026-05-11 13:38) vs dual-grounding rerun (2026-05-11 15:48)

## Headline

| Run | Verdict | Disputes | Per-principle (A / B) | Echo-bias | Mechanism |
|-----|---------|----------|-----------------------|-----------|-----------|
| Original | PASS | 0 surviving | PASS / PASS (implicit; original run did not emit per-principle blind verdicts in the synthesized format) | n/a | Cooperative synthesis (no arbiter activation) |
| Rerun (dual-grounding) | PASS | 3 surviving → resolved | PASS / PASS (explicit, named) | No procedural FLAG | Arbiter activated via `disputes_remain` trigger; binding rulings |

**Headline-PASS-vs-PASS**: the ratification's procedural soundness is fully discharged. The rerun confirms that under proper dual-grounding (constitution.md + CONFORMANCE.md), both candidates still pass the inclusion-criteria gate.

**However**, the substantive findings diverge meaningfully. The rerun is NOT a procedural rubber-stamp of the original — it surfaces structural recommendations the original did not consider, and reverses at least one of the original's central structural findings.

## Substantive divergences

### Divergence 1: Invariant 3 disposition (REVERSED)

- **Original**: "Invariant 3 belongs in Quality Gates, not the constitutional invariant body" — unanimous convergence. P1 spec change #4: move to Quality Gates, end-to-end install testing reclassified as release evidence.
- **Rerun**: Invariant 3 STAYS as constitutional invariant. Restructure Candidate A so **Invariant 3 LEADS** as the novel governance concern; Invariants 1–2 are **enabling constraints** to Invariant 3's end-to-end surface verification. Operational definitions for "fresh project fixture" and "works" added pre-ratification.
- **Reading**: the original treated end-to-end install testing as release procedure (operational); the rerun treats it as the load-bearing architectural mandate that Invariants 1–2 exist to serve. Both agents in the rerun reached this restructuring through Phase 3 cross-review; the framing language was bilaterally agreed.
- **Implication for ledger Item 3** (Quality Gates move): the rerun **softens** demand-signal for Item 3. Shipping Item 3 today would foreclose the rerun's restructuring path. Operator decision: pursue the original's move-to-Quality-Gates pathway, or pursue the rerun's enabling-constraint restructuring pathway? They are not compatible.

### Divergence 2: Invariant 1 disposition (SOFTENED)

- **Original**: "Default to unconditional reassignment of Invariant 1 as a named Principle XI enforcement script… reassignment is the expected outcome" (synthesizer's stronger position; arbiter never activated to issue binding ruling).
- **Rerun**: Invariant 1 is an enabling constraint for Invariant 3 ("Invariant 1 ensures the end-to-end test (Invariant 3) verifies a determinate version — without version SST, the test cannot confirm which artifact was installed"). Its distinctness from XI becomes a "does this version-stability constraint serve the Invariant 3 test's determinacy?" question, not a "is this principle distinct from XI?" question.
- **Reading**: the rerun's restructuring displaces the original's reassignment-as-default stance. XI structural argument is still listed as a remaining advancement condition (P2), but the framing avoids the original's "circular admission" diagnosis.
- **Implication for ledger Item 1** (Invariant 1 → XI reassignment textual analysis): rerun **softens** Item 1's demand signal. Same operator decision as Divergence 1.

### Divergence 3: Invariant 2 / Principle X distinctness (CONTENT-AGREED, REFRAMED)

- **Original**: P1 #3 requires the X distinctness evaluation as a prerequisite, with option (c) — "Candidate A has no constitutional content if Invariant 2 fails X" — held open.
- **Rerun**: provides exact wording for the X distinctness sentence (P1 #7 in arbiter resolution): "X governs whether policy is declared in templates rather than inferred at runtime — a constraint on configuration architecture; Invariant 2 governs whether distribution artifacts on disk match their declared manifests at ship time — a packaging completeness constraint." Bilateral content convergence in Phase 3.
- **Implication for ledger Item 2** (Invariant 2 → X distinctness textual analysis): rerun **strengthens** Item 2's demand signal — the analysis is done; the sentence is drafted; ship-now is unambiguous.

### Divergence 4: CONFORMANCE.md Provisional-cap entry (NEW, STRENGTHENED)

- **Original**: P1 #10 — "PENDING/ACTIVE tier with consequence clause" if stubs remain at ratification. Promotion deadline as milestone identifier; automatic demotion to ADVISORY status on missed deadline.
- **Rerun**: P1 #2 — CONFORMANCE.md Provisional-cap entry must be comprehensive and mechanical (no vague "pending follow-on" language). Path A or Path B election at ratification time; comprehensive condition enumeration is the operative enforcement, not commit structure.
- **Reading**: both runs converge on a structured-status mechanism. The rerun calls it "Provisional"; the original called it "PENDING/ACTIVE." The rerun's comprehensiveness requirement is a refinement of the original's mechanism, not a contradiction.
- **Implication for ledger Item 6** (PENDING/ACTIVE tier): rerun **strengthens** Item 6's demand signal.

### Divergence 5: VIII PATCH (BOTH AGREE)

- **Original**: P1 #5 — "Issue PATCH amendment to Principle VIII defining 'configuration entry' scope."
- **Rerun**: P1 #3 — "VIII PATCH to Principle VIII bullet 1" with proposed text mandating that the scope boundary be constitutionally self-derivable without cross-reference to CONFORMANCE.md.
- **Implication for ledger Item 4** (VIII PATCH): both runs say ship. Rerun's proposed text is slightly more specific than the original's. **Demand signal: confirmed.**

### Divergence 6: Reader-precision definition (BOTH AGREE)

- **Original**: P1 #7 — Reader definition clause enumerating direct shell assignment, jq/yq expressions, and a CONFORMANCE.md reader-exception table with verbatim access patterns.
- **Rerun**: not surfaced as a P1 with the same level of detail; the rerun's narrowing recommendations (P1 #4 — frontmatter clause exclusion) are tangentially related but do not duplicate the original's reader-precision work.
- **Reading**: the original was more specific on this point because of how its Phase 3 cross-review unfolded (S5 + A2 modified). The rerun's deliberation took a different path through Phase 3 and did not converge on a verbatim reader definition.
- **Implication for ledger Item 7** (reader-precision definition): no contradiction; the original's specificity remains the better source. **Demand signal: unchanged.**

### Divergence 7: Joint scope table (PARTIAL)

- **Original**: P1 #11 — "Two-principle boundary" row in CONFORMANCE.md in same commit batch as VIII PATCH.
- **Rerun**: does not emphasize a joint scope table specifically; the rerun's CONFORMANCE.md work is concentrated in the Provisional-cap entry.
- **Implication for ledger Item 5** (joint scope table): no contradiction; demand-signal carries forward from the original.

## New findings unique to the rerun

Findings that did NOT appear in the original blind pass and would require operator authorization to act on:

1. **Pre-ratification Invariant 3 operational definitions** ("fresh project fixture" / "works"). Editorial text amendments to the constitutional principle text. Rerun characterizes these as resolving an "active falsifiable-scope inclusion criterion failure" — the principle's current text contains undefined operational terms that fail Principle II's mechanical-gate requirement.

2. **Section rename "Mechanical verification" → "Mechanical verification feasibility"** + PENDING notation. Honest-heading discipline; the heading currently implies verification, not feasibility-of-verification.

3. **Criterion 1/3 labels in CONFORMANCE.md stub rows**. Auditability of the verification gap without traversing the deliberation tree. "Criterion 1 feasibility only (path existence); Criterion 3 enforcement deferred."

4. **Invariant 3-leads restructuring** with Invariants 1–2 as enabling constraints (per Divergence 1 above).

5. **Echo-bias check explicit PASS**. The original did not check for or report echo-bias.

## Ledger-Item demand-signal summary

| Ledger item | Original signal | Rerun signal | Net |
|-------------|-----------------|--------------|-----|
| 1 — Invariant 1 → XI textual analysis | Ship (default-reassignment) | Softened (becomes enabling-constraint, not reassignment) | **Operator decision required: pursue original or rerun path** |
| 2 — Invariant 2 → X textual analysis | Ship (option (c) held open) | Strengthened (X distinctness sentence drafted bilaterally) | **Ship-now candidate** |
| 3 — Quality Gates move for Invariant 3 | Ship | Reversed (Invariant 3 stays as constitutional invariant) | **Operator decision required: original move-to-QG vs rerun enabling-constraint restructure** |
| 4 — VIII PATCH | Ship | Confirmed | **Ship-now candidate** |
| 5 — Joint scope table in CONFORMANCE.md | Ship (paired with #4) | Carries forward (no rerun contradiction) | **Ship-now candidate (with #4)** |
| 6 — PENDING/ACTIVE tier | Ship | Strengthened (called "Provisional-cap," same mechanism, comprehensiveness requirement added) | **Ship-now candidate** |
| 7 — Reader-precision definition | Ship | Unchanged (not contradicted, not strengthened) | **Ship-now candidate** |

## Operator decision points

Before any amendment work, the operator must resolve:

**Decision A — Candidate A structural shape**: pursue the **original's** Quality-Gates-move pathway (Item 3) or the **rerun's** enabling-constraint restructuring pathway (Items 1+3 reframed)? These are architecturally incompatible. Choosing the rerun pathway moves Item 1 from ship-now to "may not be needed" and converts Item 3 from "move out" to "stay in with companion text."

**Decision B — Pre-ratification text amendments**: the rerun calls for pre-ratification text amendments to Invariant 3 (operational definitions). The v2.2.0 ratification has already shipped — these would now be PATCH or MINOR amendments to v2.2.0, not pre-ratification changes. Authorize that scope expansion, or treat the rerun's findings as forward-only guidance for v2.3.0?

**Decision C — Post-ratification constitution drift caveat**: the rerun grounded against the post-ratification constitution (containing Tier 2 XXII + XII inheritance references). A fully controlled re-run would require checking out the pre-ratification constitution.sha at the original run's epoch. Is this caveat load-bearing for the audit conclusion, or is the post-ratification grounding the more useful test (since real future deliberations will run against the post-ratification constitution)?

Until these decisions land, no amendments are made. The rerun's evidence stands at `blind-rerun-with-conformance/`; the original audit trail at `blind-evidence/` is unmodified.
