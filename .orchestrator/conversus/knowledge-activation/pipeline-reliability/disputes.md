# Disputes — pipeline-reliability perspective

*Target: `.orchestrator/proposals/knowledge-activation-reliability.md`*
*Reviewer: pipeline-reliability (fail-loud, index-as-cache, raw-corpus-is-truth, resilience-over-atomicity, provenance-travels-with-context).*
*Phase 4, final statement, cooperative mode. Revisions consumed: pipeline-reliability, activation-loop, framework-steward (all iteration 1).*
*Date: 2026-06-06.*

---

### Remaining Disputes

This deliberation converged unusually hard: all three agents *modified* rather than withdrew, every "tension" resolved to composition, and the two true contradictions raised against me (audit blast-radius, capture-format primacy) I already conceded in revision. After reading both other agents' revised positions against my own, **there are no surviving recommendation-vs-recommendation conflicts that I will not concede.** Per the rules, empty here is a valid positive outcome — but two *residual seams* remain that are not full disputes and that I will not let synthesis paper over. I record them as the honest "what little remains."

**Residual seam 1: [byte-equality default vs round-trip dynamic assertion — keep the harness split, do not collapse it]**
- My claim (revision Rec 3, New-rec consumers): the P0 regression harness must be *two-shaped* — static byte-equality fixtures for the schema-settled deterministic surfaces (`INDEXED:/SKIPPED:` summary, path-collision count, freshness flag), AND a *separate* round-trip oracle that writes→rebuilds→greps→asserts the fresh entry dynamically. These cannot be the same fixture: a frozen expected-output file cannot contain a row appended at runtime.
- Opposing-ish position(s): activation-loop (revision Rec 6, New-2 `[merge-coverage-and-byte-stability-into-one-AC]`) pushes "one fixture, both guarantees" — AC-1 runs on a Quick fixture AND asserts byte-for-byte. framework-steward (revision New-rec C) sequences byte-equality fixtures to schema-settledness but frames them as one acceptance discipline.
- Evidence vs advocacy: this is *evidence* — the V1.x cycle (per `feedback_fixtures_byte_equality_default.md`) proved byte-equality is the right default, but a round-trip test that writes a fresh entry *cannot* be frozen-corpus byte-locked without defeating its own purpose. activation-loop's own revision Rec 10 caveat *agrees* with the split ("split the harness so the *static* byte-equality fixtures don't collide with the *dynamic* round-trip oracle").
- Why I will not concede (the split): collapsing the two into "one AC" risks a synthesizer reading "byte-for-byte" and freezing the round-trip's expected output, which then either (a) can't contain the dynamic row, or (b) gets softened to a substring-assert — the exact asymptotic-not-convergent failure byte-equality exists to prevent.
- Counter-argument (theirs, which I accept): activation-loop is right that *coverage without byte-stability and byte-stability without coverage each leave a hole*. The merge intent is correct; only the literal "one fixture" wording is the hazard.
- Proposed resolution path: synthesis states it as activation-loop already did in their Rec 10 — **one AC-1 lane that is byte-equality-disciplined in BOTH shapes** (`LC_ALL=C`, no wall-clock, stable ordering), realized as (a) static frozen-corpus fixtures for settled surfaces + (b) a dynamic round-trip oracle that byte-asserts the *resolved row* against a computed-expected, not a frozen file. Same discipline, two assertion shapes. This is a wording reconciliation, not a real fork — flag it so synthesis does not mint a single frozen fixture.

**Residual seam 2: [provenance-header schema timing — P1 schema vs P0 minimal-payload subset]**
- My claim (revision Rec 4, Rec 8): the *full* versioned provenance-header byte-contract lands P1 (you cannot byte-lock a schema that is still open); but a *minimal* payload-resident header (source enum + one age/count field) ships P0 in the payload, with full provenance to stderr/evidence-artifact.
- Opposing-ish position(s): framework-steward (revision New-rec C) agrees the provenance-header *fixture* ships P1 with its schema. activation-loop (revision Rec 4) needs the header's `resolved-id` field at the P0 capture-confirm table. These are compatible but live on different ship lines, which can read as a contradiction.
- Evidence vs advocacy: advocacy on timing, evidence on the constraint (a schema-open output is unfixturable).
- Why I will not concede (the minimal-P0 subset): if synthesis defers the *entire* header to P1, then P0 ships fail-loud-without-provenance — the agent is warned "degraded" but the downstream confirm-step has no `source:` enum or `resolved-id` to assert against. The minimal subset (source enum + resolved-id + one age field) must ride P0 even though the *full versioned contract + its fixture* is P1.
- Counter-argument: framework-steward could read "header to P1" as the whole header. I do not believe they intend that — their New-rec C explicitly keeps a "payload-resident header subset minimal (source enum + one age/count field)" in P0.
- Proposed resolution path: synthesis splits the header explicitly — **P0: minimal payload header (source enum + resolved-id + index_age) + full provenance to stderr; P1: the versioned `schema_version`-bearing byte-contract + its fixture + the M034/M038/wiki consumer documentation.** One design pass, two ship windows, no schema byte-locked before it is settled.

Neither seam is a position I hold *against* a peer's held position — both other agents already wrote the compatible shape. I record them only so synthesis does not flatten a sequencing nuance into a false either/or. **I have no Phase-4 dispute I will die on; my revision conceded the two real contradictions and they stayed conceded.**

---

### Convergence

**Converged: [deterministic-grep floor is the index-free guarantee — DQ-2 jointly RESOLVED, not open]**
- Shared position (actionable): deterministic substring/grep over raw `knowledge/**/*.md` is the activation guarantee floor and the *sole* input to the corpus-gate evidence artifact; embeddings, if ever added, are additive recall that never gates and never enters the receipt. Nondeterminism vectors forbidden: `LC_ALL=C`, no wall-clock fields in artifact bodies, stable file ordering.
- Agreeing agents: pipeline-reliability (revision Rec 6, reproducibility framing), framework-steward (revision Rec 3, Principle-IX framing + hardening addendum), activation-loop (revision Rec 10, round-trip same-instant-confirmation framing).
- Strength: **Unanimous.**
- Path to convergence: three independent rationales (reproducibility, Principle IX, round-trip immediacy) reach one invariant. **Synthesis must record DQ-2 as jointly RESOLVED and must not mislabel the three framings as a fork** — I flagged this explicitly in revision Rec 6 and framework-steward flagged the same mislabel risk.

**Converged: [proven bugs ship P0, milestone-independent — §7 cleave axis holds]**
- Shared position (actionable): B-1..B-5 (proven, file:line-verified bugs) + FR-15 alarm + index-free fallback ship as a P0 hotfix independent of any milestone; the activation *UX build* composes with M040. The cleave line is drawn at **"local primitive vs UX wrapper,"** not "bug vs feature."
- Agreeing agents: pipeline-reliability (revision Rec 11), framework-steward (revision Rec 1, New-rec A), activation-loop (revision Rec 2, Scope Discipline).
- Strength: **Unanimous.**
- Path to convergence: framework-steward's original "bug vs feature" line was corrected by both other agents to "primitive vs UX"; framework-steward adopted it. The §7 *structure* survives; only FR *membership* moved.

**Converged: [BUG A / B-3 capture-format mismatch is co-primary P0 — a truth-layer failure outranks a cache-layer failure]**
- Shared position (actionable): FR-1 (producer/consumer format unification + round-trip test) is a co-primary P0 deliverable, foregrounded alongside the rebuild-bug fixes. The round-trip oracle must assert against the *observed awk field indices* (`$5` scope, `$6` when after leading-pipe shift), reconciling three disagreeing shapes (producer, consumer-comment, consumer-awk). One fixture corpus locks both capture-format and grep-fallback; neither ships green alone.
- Agreeing agents: activation-loop (revision Rec 1, Rec 3), pipeline-reliability (revision Scope-Discipline concession — my own P-B *logically concedes* a truth-layer bug outranks a cache-layer bug), framework-steward (revision Position Summary — "zero daylight," now foregrounded co-primary).
- Strength: **Unanimous.**
- Path to convergence: I came in leading the rebuild-bug as P0-primary; my own P-B principle (cache may be absent) forced the concession that B-3 (capture unreadable) outranks B-1 (index absent). All three converged on co-primary.

**Converged: [fail-loud + provenance header + index-free fallback — but budget-bounded through the M036a governor]**
- Shared position (actionable): every index consumer detects empty/missing/stale index and (a) emits a visible WARNING into the injected payload + stderr, (b) prefers a grep-over-raw-files fallback over silent first-N, (c) stamps a knowledge-provenance header — and the grep retrieval routes through the existing M036a token-budget governor (SC-3/SC-7); the regression asserts hits *within budget*, not unbounded.
- Agreeing agents: pipeline-reliability (revision Rec 1, Rec 5, Rec 8, New-rec budget-bound), framework-steward (revision Rec 2, Rec 7, Rec 10 — accepted the grep path into P0, held the governor), activation-loop (revision — endorses fail-loud as the substrate).
- Strength: **Unanimous.**
- Path to convergence: framework-steward conceded the FR-5-minimum-cut stripped P-B's load-bearing fail-over (fail-loud-without-fail-over); I conceded the all-consumers grep firehose needs the M036a governor. The two concessions interlock — fail-over *and* budget, one mechanism.

**Converged: [the G-1 explicit-decision-capture-at-Quick primitive ships P0 — so the 0-MEM alarm points at a populated store]**
- Shared position (actionable): the one-line `append-decision.sh`-at-Quick call ships P0 in the same change set as FR-6 (compact bounded Decisions digest), so the FR-15 0-MEM alarm points at a *populated* store on a default-intensity project rather than certifying an empty one as "activated." Capture-cost (disk write) is free/unbudgeted; inject-cost (read into payload) is governor-bounded. The capture *command* UX, auto-graduate, and two-store *graduation build* defer to the M040 track.
- Agreeing agents: activation-loop (revision Rec 2 — the one item they refuse to withdraw), framework-steward (revision New-rec A — decoupled command-name from ship-timing), pipeline-reliability (revision Rec 11 — pulled FR-6 + explicit-FR-8 into P0).
- Strength: **Unanimous.**
- Path to convergence: M040's formal trigger has NOT cleanly fired (only #2 + #3, not #4 which needs ≥5 reports), so "fold into M040" without the P0 primitive would defer the capture path indefinitely. All three converged: M040 owns the verb and UX; the minimum write-side primitive rides the hotfix on a committed timeline.

---

### Final Position Statement

**Non-Negotiables**

1. **The index-free deterministic-grep fallback is a mandated, enumerated, fixture-byte-equality-tested invariant for EVERY index consumer — budget-bounded through the M036a governor.** (target §3 FR-5, §4 DQ-1, my revision Rec 1/5.) Why: a fail-loud guarantee covering 1-of-N readers is a silent fail-open for the other N-1; a fail-loud guarantee over an unparseable store is a green receipt for an empty corpus. The consumer inventory must (a) enumerate every reader, (b) name runtime agent memory as a *zero-reader store* (the negative finding), and (c) assert over rows produced by the *unified* (FR-1-fixed) producer. This is the load-bearing P-B invariant and I will not let it be narrowed back to "the actively-burning consumer only" without the all-consumers *visibility* guarantee landing in the same P0.

2. **One fixture corpus must lock both capture-format (FR-1/B-3) and the grep fallback — neither ships green alone, and the round-trip oracle asserts against the observed awk field indices.** (target §5 AC-1, §4 DQ-6, my revision Rec 3 + Scope-Discipline.) Why: a perfectly hardened retrieval pipeline over a mis-columned store injects nothing — grep finds the row, `filter_decisions` reads scope from the wrong awk field, the scope-match drops it. FR-1 (B-3) is a *prerequisite* of my index-free fixture suite, not a parallel track. Byte-equality is the default per the V1.x cycle; substring-asserts are asymptotic-not-convergent.

3. **DQ-2 is jointly RESOLVED in the brief — deterministic grep is the floor, embeddings additive-only, never gating, never in the receipt.** (target §4 DQ-2, my revision Rec 6.) Why: unanimous across all three agents from three independent rationales. Carrying it as "open" would falsely imply a fork that does not exist. Synthesis must record the resolution and the forbidden-nondeterminism-vector hardening (`LC_ALL=C`, no wall-clock, stable ordering).

**Flexibility**

1. **The provenance-header schema timing — full versioned contract is P1; only the minimal payload subset must ride P0.** Flexible on: which exact fields beyond `{source-enum, resolved-id, index_age}` sit in the P0 payload vs stderr; the `schema_version` machinery and M034/M038/wiki consumer documentation can fully defer to P1. Must be preserved: a minimal `source:` enum + `resolved-id` ships P0 in the payload so the capture-confirm step has something to assert against — fail-loud-without-provenance is not acceptable even in P0.

2. **The unguarded-pipeline audit scope and the doctor-check consolidation.** Flexible on: I already conceded the audit is a bounded grep-enumeration of `rebuild-index.sh` + directly-sourced libs (not a repo-wide sweep), and fixing a non-`:117` pipeline is P0 only if reproduced; and I folded my no-vestigial-index assertion into framework-steward's consolidated three-symptom doctor check. Must be preserved: the *enumeration* of `:117`-class pipelines ships P0 (the "guard assumed, never enumerated" trap closes), and the consolidated doctor check covers the no-vestigial-index assertion.

3. **The exact P0 membership boundary for capture items (FR-6 / explicit-FR-8 / FR-9 enforcement-warning).** Flexible on: build-order sequencing within P0 (I accept activation-loop's New-1 "alarm-first" — FR-15 + FR-5 have no dependencies and ship day one, capture rides on top as a load-bearing tenant; both P0, list unordered). Must be preserved: the explicit-decision-capture-at-Quick primitive and the FR-9 0-MEM-on-mature-project enforcement-warning are *inside* P0, not deferred to M040's unfired trigger — so the alarm points at a populated store, not an empty one.
