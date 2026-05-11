# Pending VIII Amendment Text — archived after blind-PASS ratification

**Status**: Archived 2026-05-11. The text below landed in
`.orchestrator/memory/constitution.md` Principle VIII body at the
v2.2.0 ratification commit `e2c510ef` (Path 1 ratification per the
operator-routed decision packet
`.orchestrator/comments/review-queue/2026-05-11-XXII-XII-blind-substantive-findings.md`).
This file is kept in
`.orchestrator/ratification/2026-05-11-XXII-XII/archive/` as the
audit trail of the held-text mechanism the self-consistency
deliberation introduced.

This text was previously added to
`.orchestrator/memory/constitution.md` as a `**Tier 2 alignment**`
paragraph under Principle VIII as part of the originating-deliberation
P1+P2 fixes commit (`11523319`, 2026-05-11). The self-consistency
deliberation (`.orchestrator/ratification/2026-05-11-XXII-XII/self-consistency-gate-result.md`)
identified this as a Principle VI (State On Disk Is Truth) violation:
the constitution as-written claimed a ratification event that had not
occurred yet — the blind deliberation had not run. Both
self-consistency advocates converged unanimously that the text MUST
be removed from the constitution before the blind deliberation
proceeds; otherwise the blind agents review a constitution that
already embeds the outcome they are chartered to evaluate, defeating
the three-deliberation pattern's echo-bias-prevention function.

This file holds the text verbatim (with the namespace-qualification
correction per self-consistency P1-4 — `conversus Tier 2 XII` rather
than bare `Tier 2 XII`). The paragraph lands in the constitution —
along with the 2.2.0 version bump per self-consistency P1-2 — only
after the third (blind) deliberation closes with a PASS verdict.

## Two-phase sequencing note (per self-consistency P1-5)

Phase 2 scope-precision text in the proposal is **CONFORMANCE.md-authoritative
and does not depend on L175-185's ratification**; L175-185's eventual
PASS will add a constitutional cross-reference to the same scope map,
completing the dual-pointer structure (constitution → CONFORMANCE.md
and proposal → CONFORMANCE.md).

The scope map itself is on disk and already authoritative as
`CONFORMANCE.md § Tier 2 XII — Three-bucket structure` (landed in the
originating-deliberation P1+P2 commit, 2026-05-11). Phase 2 work
proceeds against that authority, not against the pending text below.

## Pending text (lands at Principle VIII body upon blind-deliberation PASS)

> **Tier 2 alignment** (added 2026-05-11 by the XXII + conversus Tier 2 XII
> inheritance amendment): the build-fractal namespace carries
> conversus Tier 2 XII (No Dead Infrastructure) governing config-knob,
> schema-variable, and documented-consumer surfaces with
> `scripts/diagnostics/check-dead-infra.sh` as the canonical linter.
> VIII governs file-system-level infrastructure reachability with
> `scripts/diagnostics/run-doctor.sh` as the canonical audit. The
> scope boundary is declared explicitly in
> [`CONFORMANCE.md`](../../CONFORMANCE.md) under the Component-tier
> declarations § conversus Tier 2 XII inheritance row and its
> three-bucket structure. Together VIII + inherited conversus Tier 2
> XII discharge the orchestrator's full dead-infrastructure coverage.

## Insertion target on PASS

When the blind deliberation closes with a PASS verdict:
1. Insert the pending text above as a new paragraph at the bottom of
   Principle VIII's body in `.orchestrator/memory/constitution.md`,
   immediately after the bullet list ending with
   "When in doubt, delete."
2. Bump the constitution's version line to `2.2.0` and update the
   Sync Impact Report header at the top of `constitution.md`.
3. Close the corresponding `CONSTITUTIONAL_CONVERSATIONS.md` entry
   for the 2026-05-11 originating deliberation by appending a
   reference to the blind PASS verdict file and marking Status: Closed.
4. Drop the "Pending" caveat from the CONFORMANCE.md XXII and
   conversus Tier 2 XII inheritance rows; advance their status from
   Provisional to Satisfied (where the three-bucket structure
   indicates Satisfied) or keep Provisional (where the three-bucket
   structure indicates Provisional).
5. Delete this file (or move it to an archive) — its purpose
   completes at PASS.
