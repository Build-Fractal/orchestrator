# Constitutional Conversations Log

Append-only log of every deliberation that produced or *proposed* a
constitutional change to `.orchestrator/memory/constitution.md` — including
deferred and rejected proposals. Distinct from the constitution itself
(the contract) and from `.orchestrator/DECISIONS.md` (general project
decisions, broader scope).

**File created**: 2026-05-11 as part of the originating-deliberation
P1-1 fix during ratification of the Tier 2 XXII + XII inheritance
amendment (`.orchestrator/proposals/constitution-amendment-inclusion-criteria.md`).
The first four entries below are backfill from `CHANGELOG.md` and the
existing Sync Impact Report header at `constitution.md:1-29`. The fifth
entry records the deliberation that produced this file.

**Append-only convention**: never delete or rewrite past entries.
Corrections land as new entries that supersede prior ones via the
`References` field; never via in-place edit.

Entry format (per proposal Change 2):

```
## YYYY-MM-DD — <Title>
**Type**: Amendment | Proposal | Rejection | Deferral
**Trigger**: <one-line incident or observation that prompted the deliberation>
**Outcome**: <decision> (or: deferred to <date> | rejected: <reason>)
**References**: <PR #s, spec dirs, milestone IDs>
**Status**: Open | Closed
```

---

## 2026-03-18 — Constitution v1.0.0 ratified (original I-VII)

**Type**: Amendment
**Trigger**: Initial project bootstrap — first formal constitutional
contract for the orchestrator (then "speckit-orchestrator"). Captured
the seven governing principles derived from the project's earliest
design conversations.
**Outcome**: Ratified seven core principles — I (Context Minimization),
II (Evidence Before Claims), III (Design Before Code), IV (Plans Assume
Zero Context), V (Fresh Context Per Unit), VI (State On Disk Is Truth),
VII (Knowledge Compounds). Established the Sync Impact Report header
convention at the top of `constitution.md`, the version-bump semantic
(MAJOR / MINOR / PATCH), and the consistency-propagation requirement
for amendments.
**References**: `.orchestrator/memory/constitution.md` Sync Impact
Report § "Prior version history" line 28; CLAUDE.md § "Constitution
Principles".
**Status**: Closed

---

## 2026-03-26 — Constitution v2.0.0: VIII–XIII added, II amended for event emission

**Type**: Amendment
**Trigger**: M005 / M006 work surfaced that the original seven
principles did not provide mechanical hooks for several emerging
patterns: dead-infrastructure detection, reproducibility discipline,
template-over-inference discipline, single-source-of-truth for state,
hook isolation, and the agent-instruction-schema canonical shape.
Principle II also required strengthening to mandate structured event
emission rather than ad-hoc log parsing.
**Outcome**: MAJOR version bump (additive but redefined Principle II's
evidence shape). Six new principles ratified — VIII (No Dead
Infrastructure), IX (Reproducibility Over Convenience), X (Templating
Over Inference), XI (Single Source of Truth), XII (Hook Isolation),
XIII (Agent Instruction Schema). Mechanical verification: extended
`scripts/diagnostics/run-doctor.sh` to cover the new principles;
added `scripts/diagnostics/check-events.sh` and
`scripts/diagnostics/check-constitution.sh`.
**References**: `CHANGELOG.md` § "Constitution v2.0"
(line 295); `.orchestrator/memory/constitution.md` Sync Impact Report
§ "Prior version history" line 27.
**Status**: Closed

---

## 2026-04-14 — Constitution v2.1.0: XIV–XV added, II + III amended

**Type**: Amendment
**Trigger**: Accreted dogfood incidents during M015 / M016 / M018
surfaced two distinct anti-pattern classes that lacked principle-level
governance: speculative complexity (premature abstractions, error
handling for impossible scenarios) and surgical-precision drift
(uncommitted scope, "while I'm here" edits). Principle II also
required upfront-success-criteria capture; Principle III required
explicit ambiguity surfacing during the design pass.
**Outcome**: MINOR version bump. Two new principles ratified — XIV
(No Speculative Complexity), XV (Surgical Precision). Principle II
amended to mandate captured success criteria before "complete" can be
claimed; Principle III amended to require ambiguity surfacing during
the design pass. Principle count rose from 13 → 15.
**References**: `.orchestrator/memory/constitution.md` Sync Impact
Report § "Added principles" / § "Amended principles" lines 4-15;
constitution body at lines 255-284 (XIV-XV) and lines 52-108 (II / III
amended bodies).
**Status**: Closed

---

## 2026-04-23 — Constitution canonical path move (M015 standalone cutover)

**Type**: Amendment
**Trigger**: M015 (standalone cutover) removed the spec-kit extension
host. The constitution's prior canonical location at
`.specify/memory/constitution.md` was no longer load-bearing for
the orchestrator's runtime. The state-root resolver was simplified
from 5 rules to 4 by removing the `.specify/orchestrator/` bridge rule.
Procedural-only move, no principle changes.
**Outcome**: Canonical constitution path moved to
`.orchestrator/memory/constitution.md`. No version bump (the contract
itself was unchanged; only the file location). Consistency-propagation
applied across `references/`, `commands/`, and `docs/` — every prior
reference to `.specify/memory/constitution.md` updated to the new
path. The `gate.grounding_file` field in every conversus preset
re-pointed to the new path (precedent for the current 2026-05-11
ratification flow's preset frontmatter).
**References**: `CHANGELOG.md` § M015 standalone cutover entry (line
135 + § "Removed" line 144); commit history around 2026-04-23.
**Status**: Closed

---

## 2026-05-11 — Originating deliberation for Tier 2 XXII + XII inheritance amendment

**Type**: Proposal (deliberation in progress)
**Trigger**: Alignment sweep with conversus v4.0.0 tier extraction
surfaced that orchestrator's `pending Principle XVI (Distribution
Surface Integrity)` from the 2026-04-27-captured proposal would
duplicate conversus's Tier 2 XXII (same name, same intent). A separate
Tier C alignment-sweep port shipped a dead-infrastructure linter
(`scripts/diagnostics/check-dead-infra.sh` + `tests/test-dead-infra-knobs.sh`,
baseline: 0 dead / 41 leaves across `templates/orchestrator-config-default.yml`)
that mirrors conversus Tier 2 XII (No Dead Infrastructure). Both
capabilities are on disk; the inheritance declarations were not. The
2026-05-11 refresh of the proposal (`.orchestrator/proposals/constitution-amendment-inclusion-criteria.md`)
reshaped the amendment to declare Tier 2 inheritance for both
principles in a single three-deliberation set
(originating + self-consistency + blind) rather than authoring
component-tier principles.
**Outcome** (originating only): Headline verdict **PASS**;
per-principle verdicts **XXII FLAG / XII FLAG** with 5 named fixes
each. Three arbiter Dispute rulings produced P1 changes routed to
`CONFORMANCE.md` (3-paragraph membership basis preamble; tracking
policy placeholder + Provisional remediation row; 4-row PENDING
clause-mapping scaffold). Synthesis converged-on additional P1 items:
this file (`CONSTITUTIONAL_CONVERSATIONS.md`) creation + backfill;
Principle VIII disposition declaration (path b chosen — explicit scope
boundary, principle count stays at 15); three-bucket XII row structure
(Satisfied / Provisional / Extended); stub scripts at three
`scripts/verify/` paths discharging XXII Criterion 1 feasibility. A
P2 procedural fix strengthened the blind preset
(`templates/conversus-presets/constitution-ratify-blind.yml`) with a
cross-tier-weakening checklist evaluating the membership basis
preamble against criterion (i) ("Does the declaration grant implicit
relief outside the formal Relief pathway?"). Self-consistency and
blind deliberations pending.
**References**: `.orchestrator/proposals/constitution-amendment-inclusion-criteria.md`
(proposal under deliberation); `.orchestrator/ratification/2026-05-11-XXII-XII/`
(deliberation evidence tree); `.orchestrator/ratification/2026-05-11-XXII-XII/originating-gate-result.md`
(headline verdict); `.orchestrator/ratification/2026-05-11-XXII-XII/arbiter/resolution.md`
(binding rulings); `.orchestrator/ratification/2026-05-11-XXII-XII/summary/final.md`
(synthesis); `CONFORMANCE.md` § "Component-tier declarations"
(declaration rows under amendment).
**Status**: Open (self-consistency + blind deliberations pending)

---

## 2026-05-11 — Self-consistency deliberation for Tier 2 XXII + conversus Tier 2 XII inheritance amendment

**Type**: Proposal (deliberation in progress)
**Trigger**: Second of the three-deliberation set ratifying the
2026-05-11 amendment. The self-consistency pass tests whether the
inheritance declarations cohere with the existing orchestrator
constitution AND with each other. Source-grounding was the
orchestrator's own `.orchestrator/memory/constitution.md` at the
post-P1-fixes commit (`11523319`), which at dispatch time embedded
the Tier 2 alignment paragraph in Principle VIII's body.
**Outcome** (self-consistency only): Headline verdict **PASS** (0
surviving disputes); substance is **PASS-WITH-EXTENSIVE-FIXES** —
6 P1 items, 7 P2 items, 3 P3 items. **Load-bearing finding**: both
advocates (coherence-advocate and pairwise-advocate) converged
unanimously that the Principle VIII Tier 2 alignment paragraph
embedded in the constitution by the 2026-05-11 P1+P2 commit
(`11523319`) violates **Principle VI (State On Disk Is Truth)** —
the constitution as-written claimed a ratification event that had
not yet occurred (the blind deliberation hadn't run). The blind
agents would have reviewed a constitution that already embedded the
outcome they were chartered to evaluate, defeating the
three-deliberation pattern's echo-bias-prevention function. **Fix
landed** (commit pending alongside this log entry): reverted the
Tier 2 alignment paragraph from `constitution.md:175-185`; placed
the text verbatim (with namespace-qualification correction per P1-4
— `conversus Tier 2 XII`) in
`.orchestrator/ratification/2026-05-11-XXII-XII/PENDING-VIII-AMENDMENT.md`;
the held text lands in `constitution.md` along with the 2.2.0
version bump (per P1-2) only upon blind-deliberation PASS verdict.
Other P1 items applied as proposal-text edits in the same commit:
P1-2 declares 2.2.0 version-bump target in the Ratification path
section; P1-3 declares `packaging/install/*.sh` scope as option (b)
— outside conversus Tier 2 XII's linter scope, governed by inherited
XXII; P1-4 establishes the global `conversus Tier 2 XII`
namespace-qualification rule (rather than bare `XII` or `Tier 2 XII`
which would collide with orchestrator §XII Hook Isolation); P1-5
formalizes the two-phase implementation sequencing rule with
CONFORMANCE.md-authoritative Phase 2 framing; P1-6 declares the
constitution `L48` formula receives a PATCH-level annotation
clarifying it measures a payload-efficiency proxy for the
governing total-task-tokens target — without this, the blind
deliberation would encounter Principle I with two irreconcilable
enforcement expressions. P2 items (`references/` Extended-bucket
callout; pairwise interaction paragraph for dual-governed
artifacts; adoption-feasibility / scope-separation split at L45;
Governance-section CONFORMANCE.md pointer; XII design-before-code
inversion documented as bounded exception; installed-artifact
reachability surfaced as open question; XXII evidence-script
config-knob attribution) and P3 items are documented in the
synthesis but not applied in the pre-blind commit per the user's
authorized scope ("apply all P1 proposal edits"). Blind
deliberation pending.
**References**: `.orchestrator/ratification/2026-05-11-XXII-XII/self-consistency-gate-result.md`
(headline verdict); `.orchestrator/ratification/2026-05-11-XXII-XII/summary/final.md`
(Phase 4 convergence + P1/P2/P3 actionable spec changes);
`.orchestrator/ratification/2026-05-11-XXII-XII/PENDING-VIII-AMENDMENT.md`
(held VIII Tier 2 alignment text). Synthesis line numbers
(`final.md:141`-`final.md:175`) carry the per-convergence-point
detail.
**Status**: Open (blind deliberation pending)

---

## 2026-05-11 — Blind deliberation for Tier 2 XXII + conversus Tier 2 XII inheritance amendment

**Type**: Proposal (operator review pending)
**Trigger**: Third of the three-deliberation set. Blind pass tested
the two candidate principles on their own merits, with the artifact
de-provenanced (`/tmp/inheritance-claims-blind.md` — no reference to
conversus, Tier 2, or build-fractal inheritance). Source-grounding
was `.orchestrator/memory/constitution.md` at the post-self-consistency
revert state (commit `0f0db069`, no embedded Tier 2 alignment
paragraph; held text lives in PENDING-VIII-AMENDMENT.md). Purpose:
catch first-deliberation echo bias by presenting the principles
fresh.
**Outcome** (blind only): Headline verdict **PASS** (0 surviving
disputes per the gate adapter); substance is **PASS-WITH-MAJOR-FIXES**
— 12 P1 items unanimous (or unanimous-with-modification) + 2
unresolved disputes about Candidate A's relationship to existing
Principle XI. The blind agents (principle-advocate and
principle-skeptic) surfaced **substantive distinctness challenges**
that the headline PASS does not reflect:
  - **Candidate A Invariant 1 (single-source versioning)** may be an
    application of existing Principle XI (Single Source of Truth);
    skeptic's default position is unconditional reassignment of the
    `scripts/verify/version-source-of-truth.sh` script as an XI
    enforcement script with a compliance note in XI's body. Advocate
    proposed PATCH-then-decide branching. **Disputed** (S1 vs A-N1).
  - **Candidate A Invariant 2 (force-include discipline)** requires
    first-principles textual analysis against Principle X (Templating
    Over Inference). If X covers manifest discipline, reassign
    `manifest-coverage.sh` as an X enforcement script — Candidate A
    has no surviving distinct constitutional content. Evaluation
    prerequisite not yet performed.
  - **Candidate A Invariant 3 (end-to-end install testing)** belongs
    in `## Quality Gates`, not as a constitutional invariant
    (unanimous, S2). Triggering condition: version-tag publication
    via M035 GH release automation.
  - **Candidate B requires Principle VIII PATCH** as a hard
    prerequisite (unanimous, S4 + A-N2). VIII's "configuration entry"
    wording is ambiguous about Candidate B's domain. PATCH must
    resolve the scope boundary before Candidate B ratifies.
  - **Candidate B scope narrows to demonstrated verifier coverage
    only** (unanimous, S5 + A3 + A-N3). Drop "documented consumer in
    reference docs" sub-category.
  - **"Reader" needs mechanical-precision definition** (unanimous,
    A2 + S5 modified) — verbatim-pattern requirement + dynamic-reader
    exception table.
  - **Joint scope table in CONFORMANCE.md** (unanimous, A8 modified
    to P1 + S-N1) for XXII / Candidate B overlap surfaces, committed
    with the VIII PATCH.
  - **PENDING/ACTIVE tier with named consequence** (unanimous,
    S-N2 + A1 modified) for the three `scripts/verify/*.sh` stubs.
  - **Procedural finding** (unanimous, S3 + A4 modified):
    CONFORMANCE.md should have been supplied as deliberation
    grounding ("BINDING PROCEDURAL BLOCK"). I supplied only
    constitution.md per the blind preset's design (test the
    candidates on their own merits, no provenance). The agents
    argued criterion (i) cannot be evaluated against the membership
    basis preamble without CONFORMANCE.md. Future ratification
    deliberations should supply both as `--source`.

**Operator routing**: per the operator's authorized "Pause: surface
findings to operator before any implementation move" path, the
substantive findings are routed to a decision packet at
`.orchestrator/comments/review-queue/2026-05-11-XXII-XII-blind-substantive-findings.md`.
Implementation Steps 4-5 (close log entries; restore VIII Tier 2
alignment from PENDING file; bump constitution to 2.2.0; apply L48
annotation; author operator-vs-developer-config.md + deep-modules
subsection; drop CONFORMANCE.md pending-amendment caveats) are
PAUSED pending operator decision among three resolution paths
(accept-as-is / restructure / defer-XXII).

**References**:
`.orchestrator/ratification/2026-05-11-XXII-XII/blind-evidence/blind-gate-result.md`
(headline verdict);
`.orchestrator/ratification/2026-05-11-XXII-XII/blind-evidence/summary/final.md`
(Phase 4 convergence + 12 P1 items + 2 disputes);
`.orchestrator/ratification/2026-05-11-XXII-XII/blind-evidence/arbiter/resolution.md`
(arbitration on the 2 disputes);
`.orchestrator/comments/review-queue/2026-05-11-XXII-XII-blind-substantive-findings.md`
(operator decision packet).
**Status**: Open (operator decision pending)
