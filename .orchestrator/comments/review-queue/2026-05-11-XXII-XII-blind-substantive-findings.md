---
queue_id: 2026-05-11-XXII-XII-blind-substantive-findings
class: spec-amendment
confidence: high (operator-routed, not classifier-routed)
source: .orchestrator/proposals/constitution-amendment-inclusion-criteria.md
deliberation_set: .orchestrator/ratification/2026-05-11-XXII-XII/
operator_routed: true
status: path-1-selected
created: 2026-05-11
decided: 2026-05-11
---

# Decision Packet — Constitutional Amendment Ratification (Tier 2 XXII + conversus Tier 2 XII)

**Three headline-PASS verdicts in hand. Implementation paused pending operator decision on substantive findings.**

This packet routes through `commands/comments.md` review-queue per the operator's authorized path for the ratification arc. The classifier did NOT route this — the operator directed me to surface it after the blind deliberation completed.

## Situation

The 2026-05-11 amendment (`.orchestrator/proposals/constitution-amendment-inclusion-criteria.md`) declares Tier 2 inheritance of two conversus principles into the orchestrator's component-tier constitution:

- **XXII (Distribution Surface Integrity)** — single-source versioning, force-include discipline, end-to-end install testing
- **conversus Tier 2 XII (No Dead Infrastructure)** — config-knob class dead-infra detection

It ran through the three-deliberation gate pattern (originating + self-consistency + blind). All three returned **headline PASS / 0 surviving disputes** per the conversus-gate adapter's verdict contract (`templates/gate-result.md`). That is the procedural authority the proposal's "Ratification path" section defined for advancing to implementation.

**However, the substantive deliberation outputs flagged non-trivial issues that the headline PASS does not surface.** This packet exists so the operator can decide whether the substantive findings warrant pausing the amendment, restructuring it, or accepting the headline PASS as ratification authority and deferring the findings to a follow-on amendment.

## Verdict matrix (3 deliberations × 2 candidates)

| Deliberation | Candidate A (XXII Distribution Surface Integrity) | Candidate B (conversus Tier 2 XII No Dead Infrastructure) |
|---|---|---|
| **Originating** (arbiter ruled on 3 disputes) | FLAG — 5 fixes (3 ratification-commit P1, 2 deferred). Fixes applied in commit `11523319`. | FLAG — 5 fixes (same shape). Fixes applied in commit `11523319`. |
| **Self-consistency** (Phase 4 cross-cutting findings) | PASS w/ load-bearing finding: L175-185 (constitution VIII Tier 2 alignment paragraph) violated Principle VI; reverted to PENDING file. 5 substantive P1 fixes applied in commit `0f0db069`. | PASS — same cross-cutting fixes apply. |
| **Blind** (12 P1 unanimous + 2 unresolved disputes) | **Substantive distinctness challenges** — both Invariants 1 & 2 may be subsumed by existing principles XI (Single Source of Truth) and X (Templating Over Inference). Invariant 3 should be reassigned to `## Quality Gates` not constitutional. Candidate A's surviving distinct content may be **zero**. | **Requires Principle VIII PATCH amendment first**. Scope narrowing to demonstrated verifier coverage only (drop "documented consumer in reference docs"). "Reader" definition needs mechanical-precision (verbatim pattern + dynamic-reader exception table). |

**Procedural note from blind**: the blind agents (both unanimous, S3+A4-modified) called the failure to supply `CONFORMANCE.md` as deliberation grounding a "BINDING PROCEDURAL BLOCK." I had supplied only `constitution.md` per the blind preset's design intent (test the candidates on their own merits, no provenance). The agents argued criterion (i) cannot be evaluated against the membership basis preamble without CONFORMANCE.md available. The verdict still emitted PASS, but with this caveat in the rationale.

## Substantive blind findings (12 P1 items, unanimous unless noted)

Source: `.orchestrator/ratification/2026-05-11-XXII-XII/blind-evidence/summary/final.md` (Phase 4 convergence + Actionable Spec Changes).

### Findings about Candidate A (XXII Distribution Surface Integrity)

1. **Invariant 1 (single-source versioning) may be Principle XI enforcement, not a separate principle** (S1 — disputed). Skeptic's default: unconditional reassignment — XI is the principle, `scripts/verify/version-source-of-truth.sh` is one of its enforcement scripts. Advocate proposed PATCH-then-decide branching (PATCH XI to name version-source script as enforcement; if independent motivation surfaces, retain Invariant 1). **Unresolved dispute** (S1 vs A-N1).

2. **Invariant 2 (force-include discipline / manifest coverage) requires first-principles textual analysis against Principle X** (S6 — bilateral). Is a `manifest.txt` that must be explicitly populated for every bundle file a "declared in templates, not inferred at runtime" application of X? If yes (X covers it), reassign `manifest-coverage.sh` as a Principle X enforcement script. If no, Candidate A ratifies with Invariant 2 as its sole surviving content. **Evaluation prerequisite** — not yet performed.

3. **Invariant 3 (end-to-end install testing) belongs in `## Quality Gates`, not a constitutional invariant** (S2, S8 absorbed — unanimous). Quality gates are operational; constitutional principles govern shape. Triggering condition: "version-tag publication triggering M035 GH release automation."

4. **Conditional consequence**: if both Invariants 1 and 2 are reassigned to XI / X, **Candidate A has zero surviving distinct constitutional content**. The XXII inheritance shape would collapse to "XI gets a PATCH naming versioning-script as enforcement; X gets a PATCH naming manifest-script as enforcement; install-testing is a Quality Gates entry." No new principle slot is occupied.

### Findings about Candidate B (conversus Tier 2 XII No Dead Infrastructure)

5. **Principle VIII PATCH amendment is a hard prerequisite** (S4, A-N2 — unanimous). VIII's "configuration entry" wording is ambiguous about whether it covers config knobs (Candidate B's domain). The ambiguity must be resolved by PATCH amendment BEFORE Candidate B ratifies; otherwise the scope boundary between VIII and Candidate B is contested-by-prose-only.

6. **Scope narrowing to demonstrated verifier coverage only** (S5 modified, A3, A-N3 — unanimous). Drop "documented consumer in reference docs" sub-category — there is no current linter coverage for it. Note the future-path as aspirational in CONFORMANCE.md. Candidate B's surviving scope = config-knob class (`templates/`) with `check-dead-infra.sh` baseline 0 dead / 41 leaves.

7. **"Reader" needs mechanical-precision definition** (A2 modified, S5 modified — unanimous). Current "at least one reader in the codebase" wording is insufficient for static linter enforcement. Required: verbatim-pattern requirement (linter looks for exact string match) + dynamic-reader exception table (e.g., config keys read via `${jq -r .field}` in shell need explicit allowlist or runtime introspection).

### Cross-A-and-B findings

8. **Joint scope table in CONFORMANCE.md** (A8 modified to P1, S-N1 — unanimous). XXII / Candidate B overlap surfaces exist (e.g., a config knob that controls a distribution surface). The joint scope table assigns governance unambiguously: knob liveness → Candidate B; surface behavioral correctness → XXII. Must be committed in the same batch as the VIII PATCH.

9. **PENDING/ACTIVE tier with named failure consequence** (S-N2, A1 modified — unanimous). The three `scripts/verify/*.sh` stubs (created in commit `11523319`) are "infrastructure declared, never implemented." Without a named deadline + failure consequence, they violate Candidate B's own normative body. Required: declare PENDING → ACTIVE promotion deadline (e.g., "by next MAJOR" or "by M035 release ship"), with named consequence on miss (e.g., XXII inheritance reverts to Provisional until implementations land).

10. **CONFORMANCE.md as deliberation grounding** (S3, A4 modified — unanimous; procedural). Future ratification deliberations should supply both `constitution.md` AND `CONFORMANCE.md` as `--source` grounding. The blind preset's design (constitution.md only, to test merits) was wrong — criterion (i) requires CONFORMANCE.md.

## Three resolution paths

### Path 1: Accept headline PASS, defer findings to follow-on

Treat the three headline-PASS verdicts as sufficient ratification authority. Implement:

- Restore the VIII Tier 2 alignment paragraph from `PENDING-VIII-AMENDMENT.md` to `constitution.md` Principle VIII's body.
- Bump constitution to v2.2.0 + update Sync Impact Report header.
- Apply L48 formula annotation per Change 5.
- Author `references/operator-vs-developer-config.md` (Change 4).
- Add Deep Modules subsection to `references/plan-time-discipline.md` (Change 6).
- Drop "pending amendment" caveats from CONFORMANCE.md XXII + XII rows; advance status from Provisional to Satisfied (per three-bucket structure).
- Close the `CONSTITUTIONAL_CONVERSATIONS.md` entries for the three deliberations.

Open a follow-on proposal for the blind's substantive findings (Candidate A distinctness gaps, Candidate B VIII PATCH prerequisite, PENDING/ACTIVE tier).

**Tradeoff**: ships an amendment whose blind deliberation raised non-trivial distinctness questions. Future auditors reading the deliberation trail will see the gaps. The ratification PR's git history will show the amendment landed despite the blind's substantive findings being unaddressed at the time.

### Path 2: Restructure as "XI + X enforcement PATCHes + XII inheritance (after VIII PATCH)"

Acknowledge the blind's substantive findings. Restructure the amendment:

- **Drop the XXII inheritance shape** as a separate principle. Instead:
  - PATCH Principle XI: name `scripts/verify/version-source-of-truth.sh` as an XI enforcement script.
  - First-principles textual analysis of Invariant 2 against Principle X. If X covers, PATCH X to name `manifest-coverage.sh` as enforcement. If X doesn't cover, ratify Invariant 2 as a single-invariant XXII-like principle.
  - Reassign Invariant 3 (end-to-end install testing) to `## Quality Gates` section, triggered on version-tag publication.
- **VIII PATCH amendment** before Candidate B ratification: clarify VIII's "configuration entry" wording to draw the explicit scope boundary against inherited conversus Tier 2 XII.
- **Author and ratify Candidate B** with the narrowed scope (config-knob class only) and the mechanical-precision "reader" definition.
- **Add joint scope table to CONFORMANCE.md** in the same commit as the VIII PATCH.
- **PENDING/ACTIVE tier** with deadline + consequence for the three `scripts/verify/*.sh` stubs.

**Tradeoff**: Re-runs at least the originating deliberation (the proposal's shape has changed materially). Maximum constitutional rigor; takes longer; would surface any remaining gaps the current shape masks.

### Path 3: Defer XXII entirely; ratify only Candidate B (after VIII PATCH)

Smallest landing scope:

- Drop the XXII inheritance from this amendment. Document in `CONSTITUTIONAL_CONVERSATIONS.md` why (blind found Invariants 1 & 2 likely subsumed by XI & X; reserve for a future deliberated PATCH-or-ratify branching).
- Ratify Candidate B with the narrowed scope.
- Land VIII PATCH amendment in the same ratification commit.
- Document XXII deferral as an Open entry in the log.

**Tradeoff**: XXII inheritance is deferred (the originating arbiter declared it FLAG-passable; deferral means we walk away from that arbiter ruling). Loss of momentum on the distribution-surface governance question. The pre-launch dogfooding tension that motivated the inheritance (M025 installer coexistence lessons) remains unresolved at the principle level until a future amendment lands.

## Evidence on disk

- Proposal: `.orchestrator/proposals/constitution-amendment-inclusion-criteria.md`
- Originating verdict + evidence: `.orchestrator/ratification/2026-05-11-XXII-XII/originating-gate-result.md`, `arbiter/resolution.md`, `summary/final.md`, per-advocate dirs
- Self-consistency verdict + evidence: `.orchestrator/ratification/2026-05-11-XXII-XII/self-consistency-gate-result.md`, `self-consistency-evidence/`
- Blind verdict + evidence: `.orchestrator/ratification/2026-05-11-XXII-XII/blind-evidence/blind-gate-result.md`, `blind-evidence/summary/final.md`, `blind-evidence/arbiter/resolution.md`
- Held VIII text: `.orchestrator/ratification/2026-05-11-XXII-XII/PENDING-VIII-AMENDMENT.md`
- Backfill log: `.orchestrator/memory/CONSTITUTIONAL_CONVERSATIONS.md` (entries for originating + self-consistency; blind entry pending operator decision)

## Operator decision required

This packet remains in `pending-review` status until the operator selects a path. Apply path via `commands/comments.md` `apply <queue_id>` is NOT the appropriate mechanism here — the choice is between three substantively different amendment shapes, each requiring different follow-on work that doesn't fit the comment-apply pattern. The operator's decision should be recorded by editing this file's `status:` to `path-1-selected` / `path-2-selected` / `path-3-selected` and adding a `decision:` block at the bottom describing the rationale, then the implementation work proceeds per that path.

The default fallback (if no operator decision lands within a reasonable window) is **NOT** to auto-proceed with Path 1 — the blind's substantive findings are load-bearing enough that auto-proceeding would constitute the "auto-apply" path that `commands/comments.md` CON-5/SC-5 explicitly forbids for spec-amendment-class items.

---

## Decision (2026-05-11)

**Path selected**: **Path 1 — Accept headline PASS, defer findings to follow-on amendment.**

**Decided by**: operator (Brett Kellgren), responding to the path-selection question in the resume-ratification dispatch. Selection captured via `AskUserQuestion` response: `"Which resolution path should the XXII + XII ratification take?" → "Path 1 — Accept PASS, defer findings"`.

**Rationale (operator's framing)**: ship the amendment under the three headline-PASS verdicts already in hand; surface the substantive distinctness gaps as a separate, deliberate follow-on rather than blocking the v2.2.0 bump on them. The git trail (CONSTITUTIONAL_CONVERSATIONS.md entries, this packet, the follow-on proposal stub) preserves the substantive findings for future auditors so the headline PASS is never misread as "no findings."

**Implementation commits**:

- Constitution v2.2.0 bump (`e2c510ef`): Sync Impact Report rewritten; Principle I clarification + L48 PATCH annotation; Principle VIII Tier 2 alignment paragraph restored from PENDING-VIII-AMENDMENT.md; Governance cross-reference to conversus Inclusion Criteria; version line 2.1.0 → 2.2.0; Last Amended → 2026-05-11.
- References artifacts (`7816b459`): `references/operator-vs-developer-config.md` (Change 4) + `references/plan-time-discipline.md` (Change 6) + cross-reference from `commands/plan-phase.md`.
- CONFORMANCE.md ratification record (`b2895b17`): Status line + Last re-audit + Tier 2 Inheritance Basis criterion (i) closure + XXII / conversus Tier 2 XII row caveats dropped.
- Log closures + archival + follow-on proposal (this commit): CONSTITUTIONAL_CONVERSATIONS.md three Open entries marked Closed with ratification-commit references; PENDING-VIII-AMENDMENT.md moved to `.orchestrator/ratification/2026-05-11-XXII-XII/archive/` with archived-status preamble; this packet's `status:` updated to `path-1-selected`; follow-on proposal stub authored at `.orchestrator/proposals/M0XX-tier-2-xxii-xii-substantive-followups.md`.

**Deferred to follow-on amendment** (carried forward to `.orchestrator/proposals/M0XX-tier-2-xxii-xii-substantive-followups.md`):
- Candidate A Invariants 1 & 2 distinctness analysis against Principles XI and X (PATCH-then-decide branching).
- Candidate A Invariant 3 reassignment to `## Quality Gates`.
- Candidate B's Principle VIII PATCH prerequisite + scope narrowing to demonstrated verifier coverage + mechanical-precision "reader" definition.
- Joint scope table in CONFORMANCE.md for XXII / Candidate B overlap surfaces.
- PENDING/ACTIVE tier with named failure consequence for the three `scripts/verify/*.sh` stubs.
- Procedural fix: future ratification deliberations supply both `constitution.md` AND `CONFORMANCE.md` as `--source` grounding.

This packet is closed. The follow-on proposal carries the substantive work forward.
