# Proposal: Constitution Amendment — Inclusion Criteria + Governance Log + Distribution Surface

**Captured**: 2026-04-27
**Last refreshed**: 2026-05-11 (alignment sweep with conversus v4.0.0 tier extraction — see "Refresh" block below)
**Shape**: Single PR. No milestone needed.
**Source**: Conversus sweep — `~/Sites/conversus-oss/CONSTITUTION.md` v2.4.0 (`:1077-1138`, `:832-859`, `:996-1030`) and `~/Sites/conversus-oss/CONSTITUTIONAL_CONVERSATIONS.md`. **Updated source (refresh)**: conversus-oss commits `79fcf0f` (v4.0.0 tier extraction) and `15f0f2f` (Principle XII dead-infrastructure linter).
**Target file**: `.orchestrator/memory/constitution.md` (currently 15 principles, last sync impact report 2026-04-23)

---

## Refresh 2026-05-11 — alignment with conversus v4.0.0 tier extraction

Three updates supersede parts of the original draft below. The original Changes 1-6 remain as audit trail; the refresh changes which **shape** each lands in. Order matches the original Change numbering.

### Supersedes Change 1 (Inclusion Criteria)

Conversus's Inclusion Criteria already lives at `~/Sites/conversus-oss/CONSTITUTION.md` Governance section (v3.2.0+, currently v4.0.0) and is meant as the canonical procedural reference for amendments **at any tier** in the build-fractal suite. Orchestrator now inherits Tier 1 (per [`CONFORMANCE.md`](../../CONFORMANCE.md), 2026-05-10), so re-authoring Inclusion Criteria as an orchestrator-only addition would duplicate work and risk drift.

**New shape**: Change 1 lands as a one-paragraph **reference** in `.orchestrator/memory/constitution.md`'s Governance section pointing at conversus's canonical taxonomy ("Inclusion Criteria for new principles are defined in `build-fractal/conversus/CONSTITUTION.md` Governance § Inclusion Criteria and apply to orchestrator amendments by Tier 1 inheritance. No orchestrator-specific override authored at this time."). The three tests (mechanical verification capability / falsifiable scope / distinctness) are not re-stated — readers follow the cross-reference. Grandfather clause for orchestrator principles I-XV is preserved verbatim.

### Supersedes Change 2 (`CONSTITUTION-LOG.md`)

Rename to **`CONSTITUTIONAL_CONVERSATIONS.md`** to match conversus's file (which is the canonical sibling-project pattern, currently 332 lines, append-only). Same purpose, same shape, recognizable filename across the suite. Path: `.orchestrator/memory/CONSTITUTIONAL_CONVERSATIONS.md`.

Entry-format draft from the original Change 2 is preserved unchanged — it already matches conversus's structure.

### Supersedes Change 3 (Principle XVI — Distribution Surface Integrity)

Conversus carries this principle at **Tier 2 XXII** (Distribution Surface Integrity) — same name, same intent. Authoring orchestrator's own component-tier XVI would duplicate a principle that's already canonical in the build-fractal namespace.

**New shape**: instead of authoring Principle XVI in `.orchestrator/memory/constitution.md`, the amendment declares **orchestrator inherits conversus Tier 2 XXII** for all installer / packaging / distribution surfaces. This is recorded in [`CONFORMANCE.md`](../../CONFORMANCE.md)'s "Component-tier declarations" cross-suite analogue table (already landed 2026-05-11). The mechanical verification scripts named in the original Change 3 (`version-source-of-truth.sh` / `manifest-coverage.sh` / `installer-smoke.sh`) still ship — they're the orchestrator's **evidence** for satisfying inherited XXII, not their own principle's enforcement mechanism.

The original component-tier numbering (XVI) is freed for future use. The constitution's principle count stays at 15.

### Adds (new): Tier 2 XII inheritance declaration (No Dead Infrastructure)

Captured 2026-05-11 during the same alignment sweep that produced the XXII inheritance shape. Conversus carries **Tier 2 XII (No Dead Infrastructure)** — the "fully defined, fully typed, fully dead" gate that catches config knobs, helper scripts, and reference scaffolding declared but never read. The Tier C layer of the alignment sweep ported conversus's `linter/dead_infra.py` to orchestrator as `scripts/diagnostics/check-dead-infra.sh` + `tests/test-dead-infra-knobs.sh` (baseline: 0 dead / 41 leaves scanned across `templates/orchestrator-config-default.yml`). The capability is on disk; the inheritance declaration is not.

**Shape**: parallel to the XXII inheritance. Instead of authoring an orchestrator-side Principle XII (no original draft existed — this inheritance surfaced after the Tier C port), the amendment declares **orchestrator inherits conversus Tier 2 XII** for all config knobs / infrastructure surfaces in `templates/`, `scripts/`, `commands/`, and `references/`. This is recorded in [`CONFORMANCE.md`](../../CONFORMANCE.md)'s "Component-tier declarations" cross-suite analogue table (XII row already landed 2026-05-11; the "not yet declared" caveat on that row is dropped once this amendment ratifies). The shipped linter + test are the orchestrator's **evidence** for satisfying inherited XII, not their own principle's enforcement mechanism.

Orchestrator's existing component-tier numbering uses XII for "Hook Isolation" — that mapping (XII Hook Isolation ↔ conversus Tier 2 XV Plugin Isolation) is also a relocation candidate per CONFORMANCE.md but is a **separate** inheritance question and is not in scope for this amendment. Tier 1 / Tier 2 numerals operate in the build-fractal namespace; orchestrator's component-tier numerals operate in the `.orchestrator/memory/constitution.md` namespace. No collision.

**Namespace-qualification rule**: every reference in this Refresh-block text (and any text added downstream that arises from this deliberation set) to the inherited build-fractal dead-infrastructure principle uses the verbatim form **`conversus Tier 2 XII`**, not bare `XII` or `Tier 2 XII`. The nearest in-document referent for bare `XII` is orchestrator Principle XII (Hook Isolation, `constitution.md:220-235`); a reader encountering the inheritance text without the namespace prefix would navigate to hook-isolation semantics instead of dead-infrastructure semantics. This applies to all new text in the revised proposal, `CONFORMANCE.md` additions, the `PENDING-VIII-AMENDMENT.md` file, and `CONSTITUTIONAL_CONVERSATIONS.md` entries arising from this deliberation set. References to orchestrator §XII (Hook Isolation) retain the bare form.

**`packaging/install/*.sh` scope disposition — option (b) explicit**: Config-knob-shaped variables inside `packaging/install/*.sh` installer scripts are **outside conversus Tier 2 XII's linter scope**; their internal variable hygiene is governed by inherited XXII's end-to-end install testing invariant and standard code review, not by `scripts/diagnostics/check-dead-infra.sh`. `check-dead-infra.sh` is calibrated for config-knob-dense surfaces (`templates/`, `scripts/`, `commands/`, `references/`) where the variable population is well-defined; installer scripts contain shell variables, path assignments, and installer-logic flags that are structurally similar to config knobs but semantically distinct — they are installer mechanics, not orchestrator configuration. Extending the linter without a principled scope filter would produce false positives (legitimate installer variables flagged as dead knobs), degrading conversus Tier 2 XII's enforcement precision. XXII's behavioral-correctness invariants already govern installer correctness at the end-to-end level; no second linter is needed at the installer-mechanics layer.

### Ratification path (new)

Original draft did not specify how the amendment gets ratified. Refresh adopts the **three-deliberation pattern** conversus used for v4.0.0 (originating + self-consistency + blind), dispatched through `/orchestrator-conversus-gate`. **Both inheritance declarations (XXII and conversus Tier 2 XII) ratify in a single deliberation set** — they share the same inheritance-not-authoring shape, the same Tier 2 source, and the same evidence-on-disk posture, so splitting them into two deliberation sets would duplicate the procedural work without adding scrutiny:

1. **Originating deliberation** — do both inheritance shapes pass? (PASS / FLAG / BLOCK per principle)
2. **Self-consistency deliberation** — do the inheritance declarations cohere with the existing constitution and with each other? (PASS WITH FIXES if drift surfaces)
3. **Blind deliberation** — do the declarations pass when re-presented without provenance? (catches first-deliberation echo bias)

Each deliberation logs to `CONSTITUTIONAL_CONVERSATIONS.md` (the renamed Change 2). Soft target: 2026-06-15 (60-day post-launch window).

**Version-bump target**: upon PASS verdict from the third (blind) deliberation, the version line at `constitution.md:343` advances from **2.1.0 → 2.2.0**. The Sync Impact Report comment block at `constitution.md:1-29` documents: MINOR amendment; adds Governance § Inheritance reference paragraph (Change 1), `CONSTITUTIONAL_CONVERSATIONS.md` (Change 2), conversus Tier 2 XXII inheritance declaration (Change 3), conversus Tier 2 XII inheritance declaration (added under Refresh 2026-05-11), Principle I expanded guidance (Change 5). Principles I (number) and VIII (number) are unchanged by number; their bodies receive PATCH-level annotations (Change 5 clarification paragraph for I; Tier 2 alignment cross-reference for VIII — see `.orchestrator/ratification/2026-05-11-XXII-XII/PENDING-VIII-AMENDMENT.md` for the held VIII text).

**Two-phase implementation sequencing** (per self-consistency deliberation Phase 4 convergence): the amendment's implementation work splits into two phases with a strict ordering constraint.

- **Phase 1 — Baseline corrections**: (a) maintain `constitution.md` in its pre-amendment shape until the third deliberation closes with PASS (no premature Tier 2 alignment paragraphs in Principle VIII's body; held text lives at `.orchestrator/ratification/2026-05-11-XXII-XII/PENDING-VIII-AMENDMENT.md`); (b) declare the 2.2.0 version-bump target in this Ratification path section (this paragraph satisfies that requirement). Phase 1 establishes that no Phase 2 text may treat the pending constitution amendment as already-ratified evidence.
- **Phase 2 — Scope-precision additions**: scope-disposition text in the Refresh block (e.g., `packaging/install/` disposition, `references/` Extended-bucket callout, pairwise interaction paragraph) is drafted with `CONFORMANCE.md § Tier 2 XII — Three-bucket structure` as the **direct, first-class evidentiary authority**. Phase 2 text is **CONFORMANCE.md-authoritative and does not depend on the pending VIII paragraph's ratification**; the eventual PASS adds a constitutional cross-reference to the same scope map (completing the dual-pointer structure: constitution → CONFORMANCE.md and proposal → CONFORMANCE.md), but the scope map is already authoritative.

Phase 2 items MUST NOT be drafted until Phase 1 is complete. This sequencing rule was earned through cross-review convergence in the self-consistency deliberation and is documented in `CONSTITUTIONAL_CONVERSATIONS.md` for future inheritance-amendment authors.

### Changes 4, 5, 6 (light)

Untouched by the refresh. Operator-subtraction asymmetry doc (Change 4), Principle I clarification (Change 5), and deep-modules planning lens (Change 6) all stand as drafted. Change 5's clarification is independent of tier-extraction — Principle I is orchestrator-specific (component-tier identity) and doesn't have a Tier 1 analogue to inherit from.

---

## Goal

Tighten constitutional governance with three small, additive changes adopted from conversus's recent revisions. None alter existing principles I-XV; all add gates / mechanisms / one new principle around distribution.

## Motivation

The orchestrator's constitution has accreted 15 principles over the project's life. Some (e.g., XIV "No Speculative Complexity", III "Design Before Code") are inspirational rather than mechanically falsifiable. Without a gate, future principle additions risk diluting the document's bite. Conversus solved the same drift problem in v2.4.0 with explicit inclusion criteria; the orchestrator should adopt the pattern.

Separately: the constitution today preserves only *accepted* amendments via Sync Impact Reports. The reasoning behind *rejected* or *deferred* proposals evaporates. As knowledge consolidation grows (M021/M016/M018), the why-not signal is as valuable as the why.

## Proposed changes

### Change 1 — Add "Inclusion Criteria for New Principles" subsection to Governance

> **Superseded 2026-05-11** by the Refresh block — Change 1 now lands as a one-paragraph cross-reference to conversus's canonical Inclusion Criteria taxonomy rather than re-authoring it in orchestrator's constitution. Original draft preserved below for audit.

Adopted from `~/Sites/conversus-oss/CONSTITUTION.md:1077-1138`. Verbatim spirit, orchestrator-flavored wording. Three tests every new principle MUST satisfy before adoption:

1. **Mechanical verification capability** — a CI check, lint, or parity test must be *feasible* (even if not yet built). Principles whose violation cannot be detected by tooling are routed to operational guidance (`AGENTS.md`, `references/`, command docs) instead.
2. **Falsifiable scope** — the principle's wording must flag a hypothetical PR violator without requiring "interpretation." If two readers can disagree about whether a given change violates the principle, scope is too vague.
3. **Distinctness** — not composable from existing principles. If the principle restates I-VII or I-XV in new words, fold the language into the existing principle instead.

Principles that fail any test are recorded in the governance log (Change 2) as deferred, with reasoning, so the same proposal isn't re-litigated.

**Grandfather clause**: I-XV are not retroactively required to satisfy these tests. The gate applies only to amendments dated after this PR lands.

### Change 2 — Introduce `.orchestrator/memory/CONSTITUTION-LOG.md`

> **Renamed 2026-05-11** by the Refresh block — file path is now `.orchestrator/memory/CONSTITUTIONAL_CONVERSATIONS.md` to match the conversus sibling-project canonical filename. Entry format and purpose unchanged.

Append-only log of every deliberation that produced or *proposed* a constitutional change — including deferred and rejected proposals. Distinct from the constitution itself (the contract) and from `.orchestrator/DECISIONS.md` (general project decisions, broader scope).

Adopted from `~/Sites/conversus-oss/CONSTITUTIONAL_CONVERSATIONS.md` (332 lines, chronological).

Entry format:
```
## YYYY-MM-DD — <Title>
**Type**: Amendment | Proposal | Rejection | Deferral
**Trigger**: <one-line incident or observation that prompted the deliberation>
**Outcome**: <decision> (or: deferred to <date> | rejected: <reason>)
**References**: <PR #s, spec dirs, milestone IDs>
**Status**: Open | Closed
```

Initial entries: backfill the 4 most recent constitutional amendments (XIII-XV plus the most recent sync) so the log isn't born empty. Source the trigger reasoning from `CHANGELOG.md` and existing Sync Impact Reports.

**Alternative considered**: extend `DECISIONS.md` with a `scope: constitution` filter. Rejected because the constitution governs everything else and deserves its own provenance trail — co-mingling with day-to-day decisions makes both harder to navigate. Conversus reached the same conclusion (per its own README and structure).

### Change 3 — Add Principle XVI: Distribution Surface Integrity

> **Superseded 2026-05-11** by the Refresh block — instead of authoring a new orchestrator Principle XVI, the amendment declares Tier 2 inheritance of conversus XXII (same name, same intent). The verification scripts named below still ship as orchestrator's evidence for satisfying inherited XXII. Principle slot XVI stays free for future use. Original draft preserved below for audit.

Adopted from `~/Sites/conversus-oss/CONSTITUTION.md:832-859` (Principle XXII in conversus's numbering). Highly relevant given M025 (installer coexistence, shipped 2026-04-23) just exposed how multi-surface installation drift happens.

**Statement** (draft):
> Every distribution surface — `packaging/install/install-claude-code.sh`, `install-codex.sh`, `install-cursor.sh`, plus any future runtime adapter — MUST satisfy three invariants:
> 1. **Single-source versioning**: one canonical source field; all surfaces derive from it. No per-installer version strings.
> 2. **Force-include discipline**: no implicit packaging. If a file ships in a runtime adapter's bundle, it appears explicitly in `packaging/bundle/<runtime>/manifest.txt` (or equivalent). New files require manifest update; CI fails on un-manifested includes.
> 3. **End-to-end install testing**: every release gate runs the per-runtime installer against a fresh project fixture and verifies `orchestrator:status` works. No hand-waving "it worked on dev."

**Mechanical verification**:
- (1) `scripts/verify/version-source-of-truth.sh` — greps installers for hardcoded version strings.
- (2) `scripts/verify/manifest-coverage.sh` — diffs each bundle dir against its manifest.
- (3) `scripts/verify/installer-smoke.sh` — exists today partially; extend to cover all three runtimes.

The mechanical-verification feasibility satisfies the inclusion criteria (Change 1).

**Pairs with**: `M025-installer-coexistence` lessons. Could fold the principle landing into a small follow-up PR after M025's lessons are written into `knowledge/lessons/`.

### Change 4 (light, not a principle) — Operator-subtraction asymmetry doc note

Document the existing reality: operators MAY restrict the orchestrator's tool surface (env vars, runtime detection, `ORCHESTRATOR_ROOT` resolution); they MAY NOT extend it. Plugins and skills extend; operators filter. Asymmetry is already implicit; codifying it in `references/` (probably `references/operator-vs-developer-config.md`) keeps `M025`-style coexistence work from re-litigating.

Not a constitutional principle (per inclusion criteria — too narrow). Lives in `references/`.

### Change 5 — Clarification to Principle I (Context Minimization)

**Captured 2026-04-28** while drafting M031 (Right-Sized Entry). Existing implementations conflated two different things under "minimization": minimizing *payload bytes shipped to an agent* vs minimizing *total tokens spent on a task*. They are not the same; sometimes they are inversely related.

**Concrete instance**: `commands/dispatch.md:21` had Quick intensity skip `build-context.sh` "to save tokens" — yielding zero knowledge injection. The actual cost: agents either fly blind (lower-quality output, re-dispatch cost) or rediscover via grep/read (5-15k tokens of exploration). Either way total task tokens go *up*, not down. The optimization optimized the wrong sub-metric.

**Proposed clarification** to Principle I:

> Minimize **total task tokens** by delivering the right context efficiently — not by sending less context. The knowledge graph is the orchestrator's compression mechanism; bypassing it to "save tokens" typically increases total tokens spent because the agent recovers context the expensive way (exploration tokens) or produces lower-quality output that requires re-dispatch. Context minimization means *minimum sufficient context, delivered via the cheapest pipeline available*.

**Falsifiable scope** (per inclusion criteria, Change 1): a future PR that proposes any execution path bypassing the knowledge graph + compression pipeline must justify that bypass with empirical token data showing total task tokens go down, not just payload size. Without that data the PR fails the principle.

**Mechanical verification capability**: feasible — a verifier could compare JSONL token totals on fixtures with-knowledge vs without-knowledge for any path that introduces a bypass. M027's existing rollup engine does most of the math.

**Distinctness**: doesn't restate VII (Knowledge Compounds) — VII says knowledge accumulates; this clarifies how knowledge is *delivered*. Together they imply: knowledge layer is the load-bearing context delivery mechanism, full stop.

This is a clarification of intent, not a new principle. Lives in Principle I's body. Existing wording stays; one paragraph appended.

**L48 formula disposition (added 2026-05-11 by self-consistency deliberation Phase 4 finding)**: constitution `L48` carries a formula — `Context_Efficiency = Relevant_Instructions / Total_Instructions_Inherited` — that quantifies an optimization target the original v2.1.0 wording framed as payload-ratio efficiency. Change 5's clarification reframes the operative target as **total task tokens** (including exploration-recovery tokens when the agent flies blind). Left unaddressed, L48 would survive Change 5's ratification carrying a contradictory enforcement expression: a future compliance reviewer could cite L48 to justify bypassing knowledge injection ("payload efficiency"), directly undercutting Change 5's intent and the conversus Tier 2 XII dead-infrastructure rationale. Change 5's ratification path therefore includes a PATCH-level annotation to L48 — appended in the same commit that lands the Change 5 clarification paragraph:

> *(Note: this ratio measures context payload efficiency as a proxy for the governing optimization target; the operative target is total task tokens across the full dispatch cycle, including exploration-recovery costs, per the clarification below.)*

The annotation is a parenthetical addition that does not redraft Principle I's operative clause. It composes with the appended clarification paragraph: the formula remains useful as a payload-efficiency proxy, but its proxy status is now explicit. Without this annotation, the blind deliberation would encounter Principle I with two irreconcilable enforcement expressions and correctly FLAG / BLOCK on falsifiability-regression grounds (per Change 1's inclusion criteria, the "Mechanical Verification Capability" test).

### Change 6 — Add "Deep modules" lens to the Plan-Time Discipline reference (light, not a principle)

**Captured 2026-04-30** during a sweep of `mattpocock/skills` (MIT). The skill `improve-codebase-architecture` formalizes a vocabulary that the orchestrator's planning prose has been working around without naming:

- **Module** — any unit with an interface and an implementation (function, class, package, slice).
- **Interface** — everything callers must know: types, invariants, error modes, ordering, config.
- **Implementation** — the code inside.
- **Depth** — leverage at the interface. *Deep* modules expose simple interfaces over complex implementations; *shallow* modules expose interfaces whose complexity mirrors implementation complexity (callers gain nothing).
- **Seam** — where an interface lives; the place behavior alters without in-place editing.
- **Adapter** — a concrete implementation satisfying an interface at a seam.
- **Locality** — what maintainers gain when one concern concentrates in one place.

Operative principle from the source: **the interface is the test surface**. The "deletion test" follows: would removing this module concentrate complexity, or just relocate it?

**Where this lands**: not a constitution principle (it's a planning lens, not a falsifiable rule about the orchestrator's behavior — fails the inclusion criteria from Change 1). Add a short subsection to `references/plan-time-discipline.md` (or `references/architecture.md`, depending on which reference doc is the natural home; `commands/plan-phase.md` already has a "Plan-Time Discipline" section that points to a reference). The subsection lifts the vocabulary verbatim, references the source as `mattpocock/skills::improve-codebase-architecture` (MIT), and adds two orchestrator-specific notes:

1. **Adapters at runtime seams**: the orchestrator's existing adapter pattern (`scripts/dispatch/adapters/backend/<runtime>.sh`, `scripts/runtime/<runtime>/`, the format-tier adapter tree) *is* this pattern. Naming the pattern aligns prose so future plans (M009 multi-runtime parity, M010 Managed Agents) inherit the vocabulary without re-deriving it.
2. **Deletion test as planning gate (optional)**: when `orchestrator:plan-phase` proposes a new helper script or new `references/` doc, the agent SHOULD apply the deletion test in the plan's *Risk* section. Not a hard gate; a discipline. Composes with Constitution Principle III (Design Before Code).

**Pairs with**: Change 1 (the inclusion criteria explicitly excludes design lenses from the principle list — Change 6 is the worked example of a lens that lands as reference doc, not principle).

**Effort**: ~30 minutes — one section in `references/plan-time-discipline.md`, one cross-reference from `commands/plan-phase.md` "Plan-Time Discipline" section, one credit line.

## Out of scope

- Renumbering existing principles. Keep I-XV stable to preserve cross-references in `ANTIPATTERNS.md` ("Principle Violated: IX") and `knowledge/` entries.
- Pulling in conversus's other principles (XXV live test cost discipline, XXVI meta-testing for parametrized capabilities, XXVII operator-configurable tool surface). These are interesting but lower-leverage for the orchestrator today; revisit when test cost actually rises (post-M010 Managed Agents).
- Touching the orchestrator's existing Sync Impact Report header. The log (Change 2) supplements, doesn't replace, the header.

## Estimated effort

Pre-refresh estimate (kept as audit trail):

- Change 1 (~30 LOC in constitution.md): 30 min draft + review
- Change 2 (new file + 4 backfill entries): 1 hour
- Change 3 (~50 LOC in constitution.md + 3 verification scripts as stubs / TODO): 2 hours
- Change 4 (~80 LOC in references/): 1 hour
- Change 6 (~40 LOC subsection in references/plan-time-discipline.md + 1 cross-ref): 30 min

**Pre-refresh total**: ~5.5 hours, single PR.

Post-refresh estimate (2026-05-11):

- Change 1 (now a one-paragraph cross-reference): 15 min
- Change 2 (rename to `CONSTITUTIONAL_CONVERSATIONS.md` + 4 backfill entries): 1 hour
- Change 3 (now a CONFORMANCE.md row + 3 verification-script stubs as evidence for inherited XXII): 1.5 hours
- **New: Tier 2 XII inheritance declaration** (CONFORMANCE.md row caveat drop; linter + test already shipped at `scripts/diagnostics/check-dead-infra.sh` + `tests/test-dead-infra-knobs.sh`): 15 min
- Change 4 (unchanged): 1 hour
- Change 5 (Principle I clarification, unchanged): 30 min
- Change 6 (unchanged): 30 min
- Ratification: three-deliberation pass via `/orchestrator-conversus-gate` covering **both XXII and XII inheritance in a single deliberation set** (originating + self-consistency + blind): ~2-3 hours wall time across the three gates

**Post-refresh total**: ~4.75 hours implementation + 2-3 hours ratification, single PR. No dependency on any milestone. Net reduction vs the pre-refresh draft: still ~1 hour, because Tier 1 / Tier 2 inheritance is cheaper than re-authoring even with the added XII declaration (the linter + test are already on disk from the Tier C alignment-sweep port).

## Risk / open questions

- Will the inclusion criteria gate be applied retroactively if a future deliberation argues an existing principle (e.g., XIV) is non-falsifiable? **Recommendation**: no. Grandfather is permanent; the gate is forward-only.
- Should `CONSTITUTION-LOG.md` cross-link to `DECISIONS.md` entries when a constitutional change derives from a broader project decision? **Recommendation**: yes, by reference (D-NNN format), but neither is the source of truth for the other.
- Should Change 3 be adopted as-is or tied to a specific milestone (e.g., a future M0XX "release readiness")? **Recommendation**: adopt as-is now; verification scripts can land as stubs that emit "TODO" until each is implemented. The principle's existence drives subsequent work.

## Specify-time questions

When `orchestrator:specify` consumes this brief, prompt the user on:
1. Backfill scope for the governance log — last 4 amendments, last 8, or all of git history?
2. Whether Change 3 (Principle XVI) should land in this PR or split out (since it adds verification-script work).
3. Naming: `CONSTITUTION-LOG.md` vs `GOVERNANCE-LOG.md` vs folding into `DECISIONS.md` with a filter.
