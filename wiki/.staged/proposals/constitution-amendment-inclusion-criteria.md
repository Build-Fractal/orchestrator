# Proposal: Constitution Amendment — Inclusion Criteria + Governance Log + Distribution Surface

**Captured**: 2026-04-27
**Shape**: Single PR. No milestone needed.
**Source**: Conversus sweep — `~/Sites/conversus-oss/CONSTITUTION.md` v2.4.0 (`:1077-1138`, `:832-859`, `:996-1030`) and `~/Sites/conversus-oss/CONSTITUTIONAL_CONVERSATIONS.md`.
**Target file**: `.orchestrator/memory/constitution.md` (currently 15 principles, last sync impact report 2026-04-23)

## Goal

Tighten constitutional governance with three small, additive changes adopted from conversus's recent revisions. None alter existing principles I-XV; all add gates / mechanisms / one new principle around distribution.

## Motivation

The orchestrator's constitution has accreted 15 principles over the project's life. Some (e.g., XIV "No Speculative Complexity", III "Design Before Code") are inspirational rather than mechanically falsifiable. Without a gate, future principle additions risk diluting the document's bite. Conversus solved the same drift problem in v2.4.0 with explicit inclusion criteria; the orchestrator should adopt the pattern.

Separately: the constitution today preserves only *accepted* amendments via Sync Impact Reports. The reasoning behind *rejected* or *deferred* proposals evaporates. As knowledge consolidation grows (M021/M016/[M018](../milestones/M018/index.md)), the why-not signal is as valuable as the why.

## Proposed changes

### Change 1 — Add "Inclusion Criteria for New Principles" subsection to Governance

Adopted from `~/Sites/conversus-oss/CONSTITUTION.md:1077-1138`. Verbatim spirit, orchestrator-flavored wording. Three tests every new principle MUST satisfy before adoption:

1. **Mechanical verification capability** — a CI check, lint, or parity test must be *feasible* (even if not yet built). Principles whose violation cannot be detected by tooling are routed to operational guidance (`AGENTS.md`, `references/`, command docs) instead.
2. **Falsifiable scope** — the principle's wording must flag a hypothetical PR violator without requiring "interpretation." If two readers can disagree about whether a given change violates the principle, scope is too vague.
3. **Distinctness** — not composable from existing principles. If the principle restates I-VII or I-XV in new words, fold the language into the existing principle instead.

Principles that fail any test are recorded in the governance log (Change 2) as deferred, with reasoning, so the same proposal isn't re-litigated.

**Grandfather clause**: I-XV are not retroactively required to satisfy these tests. The gate applies only to amendments dated after this PR lands.

### Change 2 — Introduce `.orchestrator/memory/CONSTITUTION-LOG.md`

Append-only log of every deliberation that produced or *proposed* a constitutional change — including deferred and rejected proposals. Distinct from the constitution itself (the contract) and from [`.orchestrator/DECISIONS.md`](../decisions.md) (general project decisions, broader scope).

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

Adopted from `~/Sites/conversus-oss/CONSTITUTION.md:832-859` (Principle XXII in conversus's numbering). Highly relevant given [M025](../milestones/M025/index.md) (installer coexistence, shipped 2026-04-23) just exposed how multi-surface installation drift happens.

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

**Captured 2026-04-28** while drafting [M031](../milestones/M031/index.md) (Right-Sized Entry). Existing implementations conflated two different things under "minimization": minimizing *payload bytes shipped to an agent* vs minimizing *total tokens spent on a task*. They are not the same; sometimes they are inversely related.

**Concrete instance**: `commands/dispatch.md:21` had Quick intensity skip `build-context.sh` "to save tokens" — yielding zero knowledge injection. The actual cost: agents either fly blind (lower-quality output, re-dispatch cost) or rediscover via grep/read (5-15k tokens of exploration). Either way total task tokens go *up*, not down. The optimization optimized the wrong sub-metric.

**Proposed clarification** to Principle I:

> Minimize **total task tokens** by delivering the right context efficiently — not by sending less context. The knowledge graph is the orchestrator's compression mechanism; bypassing it to "save tokens" typically increases total tokens spent because the agent recovers context the expensive way (exploration tokens) or produces lower-quality output that requires re-dispatch. Context minimization means *minimum sufficient context, delivered via the cheapest pipeline available*.

**Falsifiable scope** (per inclusion criteria, Change 1): a future PR that proposes any execution path bypassing the knowledge graph + compression pipeline must justify that bypass with empirical token data showing total task tokens go down, not just payload size. Without that data the PR fails the principle.

**Mechanical verification capability**: feasible — a verifier could compare JSONL token totals on fixtures with-knowledge vs without-knowledge for any path that introduces a bypass. [M027](../milestones/M027/index.md)'s existing rollup engine does most of the math.

**Distinctness**: doesn't restate VII (Knowledge Compounds) — VII says knowledge accumulates; this clarifies how knowledge is *delivered*. Together they imply: knowledge layer is the load-bearing context delivery mechanism, full stop.

This is a clarification of intent, not a new principle. Lives in Principle I's body. Existing wording stays; one paragraph appended.

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

- Change 1 (~30 LOC in constitution.md): 30 min draft + review
- Change 2 (new file + 4 backfill entries): 1 hour
- Change 3 (~50 LOC in constitution.md + 3 verification scripts as stubs / TODO): 2 hours
- Change 4 (~80 LOC in references/): 1 hour
- Change 6 (~40 LOC subsection in references/plan-time-discipline.md + 1 cross-ref): 30 min

**Total**: ~5.5 hours, single PR. No dependency on any milestone.

## Risk / open questions

- Will the inclusion criteria gate be applied retroactively if a future deliberation argues an existing principle (e.g., XIV) is non-falsifiable? **Recommendation**: no. Grandfather is permanent; the gate is forward-only.
- Should `CONSTITUTION-LOG.md` cross-link to `DECISIONS.md` entries when a constitutional change derives from a broader project decision? **Recommendation**: yes, by reference (D-NNN format), but neither is the source of truth for the other.
- Should Change 3 be adopted as-is or tied to a specific milestone (e.g., a future M0XX "release readiness")? **Recommendation**: adopt as-is now; verification scripts can land as stubs that emit "TODO" until each is implemented. The principle's existence drives subsequent work.

## Specify-time questions

When `orchestrator:specify` consumes this brief, prompt the user on:
1. Backfill scope for the governance log — last 4 amendments, last 8, or all of git history?
2. Whether Change 3 (Principle XVI) should land in this PR or split out (since it adds verification-script work).
3. Naming: `CONSTITUTION-LOG.md` vs `GOVERNANCE-LOG.md` vs folding into `DECISIONS.md` with a filter.
