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
