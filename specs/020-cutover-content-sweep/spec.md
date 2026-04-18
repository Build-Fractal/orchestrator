# Feature Specification: Cutover Content Sweep

**Feature Branch**: `020-cutover-content-sweep`
**Created**: 2026-04-16
**Status**: Draft
**Input**: User description: "Post-M015 hardening. A conversus red-blue audit against the `.orchestrator/` specs found that the M015 cutover cleaned the *file layer* (no legacy spec-kit host) but left the *content layer* in the pre-cutover state: `commands/auto.md` still tells users to type `speckit.orchestrator.resume`, templates bake `Skill(speckit.orchestrator.*)` into every fresh install, `commands/migrate.md` describes the deleted 5-rule resolver, `packaging/skills/` has no `orchestrator-init.md` despite `commands/init.md` advertising `orchestrator:init`, and `CLAUDE.md` claims 7 governing principles when the constitution has 15. Blind-arbiter ruling: mechanical defects are real and mandatory to fix; the rhetorical framing of 'clean cutover' needs narrowing. Sweep the content layer, install mechanical gates to prevent regression, and record the class of drift in DECISIONS.md so future cutovers catch it."

## Problem Statement

M015 declared the legacy spec-kit host removed. The declaration is true at the file-layer: `specify/` is gone, `.specify/` scaffolding is gone, the 4-rule state root resolver shipped, migration adapters are preserved only where external users still need them. A mechanical `git diff` gate passed.

But the **content layer** — agent-facing prose in commands, templates, reference docs, and the project's own bootstrap scripts — was not swept. The cutover removed `specify/` without sweeping every `Skill(speckit.*)` mention, every `speckit.orchestrator.<cmd>` identifier in user-visible prose, every description of the deleted resolver, every principle-count claim that predates the v2.1.0 constitution expansion. The agent that reads this repo to learn the project (either a human contributor or an LLM pair-programmer) encounters a project where the `.orchestrator/` specs say one thing and half the surfaces say another.

A conversus red-blue deliberation (`conversus-oss/deliberations/spec-kit-orc-audit/`) enumerated the drift and ruled on which items are mechanical defects vs. rhetorical overreach. This milestone implements the mechanical-defect half of the ruling: the surfaces that violate the specs get swept; the gates that would have caught the drift get installed; the governance rule that would have required a DECISIONS entry for a content-layer deviation gets recorded. The rhetorical-overreach half (M016-SUMMARY's "zero prompts" scope language) is bundled as the narrow summary-edit + locked-down re-run that was the arbiter's required action for RISK-05.

The drift classes targeted:

1. **Runtime-path drift — load-bearing.** `commands/auto.md` emits prose at lines 68, 296, 518 instructing the user to type `speckit.orchestrator.resume` for crash recovery. An agent copy-pasting this string invokes the decommissioned identifier. This is not display text; it is a runtime instruction.

2. **Template regeneration drift — self-propagating.** `templates/autonomy-defaults.yaml:90-91` and `templates/claude-settings.json` carry `Skill(speckit.orchestrator.*)` allow entries. Every `orchestrator:init` in a fresh project re-infects that project with the legacy namespace, indefinitely.

3. **Missing-skill drift — advertised-but-unreachable.** `commands/init.md` advertises `orchestrator:init` as the first-run entry point. `packaging/skills/` contains 12 `orchestrator-*.md` skill files but no `orchestrator-init.md`. The advertised identifier does not resolve through the harness. A fresh clone's first-run command is the single identifier with no backing skill.

4. **Document-description drift — stale prose.** `commands/migrate.md:47,83` describes the 5-rule state-root resolver. M015 reduced it to 4 rules. The document is now incorrect.

5. **Count-claim drift — summary framing.** `CLAUDE.md:37,48-54` says "7 governing principles" and enumerates I–VII; the constitution is v2.1.0 with 15 principles (I–XV). Four docs claim "7 test suites"; there are 8 on disk.

6. **Attestation-scope drift — rhetorical overreach.** `M016-SUMMARY.md:8` phrases the zero-prompt attestation as a property of "autonomous hardening" without the `orchestrator:auto`-only qualifier that `M016-ROADMAP.md:7,50` established as the scoping sentence. The attestation itself is valid; the summary framing is not.

7. **Governance-gap drift — process.** The content-layer drifts in classes 1–6 would have been caught by either a mechanical grep gate or a required DECISIONS.md entry. Neither existed. The deliberation's evidence — including blue-defender's own self-citation of `speckit.orchestrator.resume` while defending the cutover — demonstrates that human review alone is insufficient.

Carrying this state into M009 would contradict the launch narrative. The fix is bounded, surgical, and validatable.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Fresh Clone First-Run Resolves (Priority: P1)

A developer clones `spec-kit-orc` into a new workspace, runs the recommended first command from `commands/init.md`, and the Claude Code harness resolves `orchestrator:init` to a shipped skill file without emitting an approval prompt or an "unknown command" error.

**Why this priority**: The advertised first-run entry point is the project's front door. If the front door is broken, every downstream claim about "runs end-to-end" is vacuous — the loop cannot start.

**Independent Test**: From a fresh clone with only the checked-in `settings.json`, invoke `orchestrator:init`. Verify that `packaging/skills/orchestrator-init.md` exists, is registered in `packaging/bundle/manifest.yml`, and resolves through the harness the same way every other `orchestrator:*` skill does.

**Acceptance Scenarios**:

1. **Given** a fresh clone of `spec-kit-orc`, **When** the developer runs `orchestrator:init`, **Then** the harness resolves the identifier to `packaging/skills/orchestrator-init.md` and executes it with zero approval prompts.
2. **Given** the `scripts/verify/packaging-skills-match-commands.sh` gate script, **When** run against HEAD, **Then** every `commands/*.md` file has a corresponding `packaging/skills/<slug>.md` entry and the gate exits zero.
3. **Given** a future contributor adds `commands/new-command.md` without a matching `packaging/skills/new-command.md`, **When** they run the gate, **Then** the gate exits non-zero with a file:line diagnostic naming the missing skill.

---

### User Story 2 - Template-Borne Legacy Namespace Eliminated (Priority: P1)

A developer runs `orchestrator:init` on a brand-new, previously-untouched project directory. The generated `.claude/settings.json` contains no `Skill(speckit.orchestrator.*)` allow entries. The generated bootstrap output contains no `speckit.*` identifiers outside of the documented migration-adapter path. The regeneration chain is closed.

**Why this priority**: Template-borne legacy is self-propagating — every future project inherits the drift from the dogfood template unless the template itself is swept. Every day the template sits unfixed multiplies the downstream surface.

**Independent Test**: Run `orchestrator:init` in an empty tmp directory. Grep the generated `.claude/settings.json` and any generated instruction files for `speckit.orchestrator`. Count must be zero. Re-run the `scripts/verify/no-legacy-content.sh` gate against both the source templates and the generated output — both must pass.

**Acceptance Scenarios**:

1. **Given** a developer runs `orchestrator:init` in a fresh project, **When** the template expansion completes, **Then** the resulting `.claude/settings.json` contains zero `Skill(speckit.orchestrator.*)` entries.
2. **Given** the `scripts/verify/no-legacy-content.sh` gate is run against `templates/autonomy-defaults.yaml` and `templates/claude-settings.json`, **When** the sweep has landed, **Then** the gate exits zero.
3. **Given** a contributor reintroduces `Skill(speckit.*)` into a template, **When** CI runs, **Then** the `no-legacy-content.sh` gate exits non-zero with a file:line diagnostic.

---

### User Story 3 - Crash Recovery Uses Current Identifier (Priority: P1)

A developer's `orchestrator:auto` run fails mid-phase. The error message in the subagent output and the recovery instructions in `commands/auto.md` reference the current `orchestrator:resume` identifier, not the decommissioned `speckit.orchestrator.resume`. A copy-paste of the displayed identifier resolves and runs.

**Why this priority**: This is a runtime-load-bearing path. Crash recovery happens specifically when the user is already frustrated; handing them a stale identifier to type is the worst possible moment for a UX failure.

**Independent Test**: Grep `commands/auto.md` for `speckit.orchestrator`. Count must be zero. Seed a crash, trigger recovery, verify the displayed identifier matches a real skill in `packaging/skills/`.

**Acceptance Scenarios**:

1. **Given** `commands/auto.md` after P02 lands, **When** grepped for `speckit.orchestrator`, **Then** the count is zero.
2. **Given** a dispatched subagent crashes mid-task, **When** the user follows the printed recovery instruction verbatim, **Then** the resumed run completes without an "unknown command" error.
3. **Given** the `scripts/verify/no-legacy-content.sh` gate is run against `commands/auto.md`, **When** the sweep has landed, **Then** the gate exits zero.

**Ordering constraint**: This story must land before User Story 4 (settings allow-list deletion). If the allow-list is deleted while `auto.md` still references the legacy identifier, users in the window between the two changes get a broken recovery UX.

---

### User Story 4 - Project Settings Reflect Reality (Priority: P2)

A developer inspecting `.claude/settings.json` sees allow entries that correspond to skills and commands that actually exist in this repo. No `Skill(speckit.orchestrator.*)` entries remain; no bash entries reference paths the cutover deleted.

**Why this priority**: Permission surfaces that don't match reality confuse contributors and rot as the project evolves. This is not load-bearing (the harness-trigger mechanism is shape-based, not match-based, per the deliberation's Phase 2 F3 ruling), but it is a credibility surface — a reviewer opening `settings.json` to understand permissions expects the entries to be real.

**Independent Test**: Inspect `.claude/settings.json:55-56`. The `Skill(speckit.orchestrator.*)` entries must be gone. The `Bash(bash .specify/*)` entries must either be gone or retained with an explicit comment citing the migration-adapter rationale from `M015-SUMMARY.md:32`.

**Acceptance Scenarios**:

1. **Given** `.claude/settings.json` after P03 lands, **When** grepped for `speckit.orchestrator`, **Then** the count is zero.
2. **Given** a zero-prompt re-run dogfood with the cleaned settings, **When** executed on a fresh clone against a completed phase, **Then** the prompt count remains zero (proves the allow-list deletion did not regress autonomy).

---

### User Story 5 - Migration Doc Describes Current Resolver (Priority: P2)

A developer coming from spec-kit reads `commands/migrate.md` to understand state-root resolution. The document describes the 4-rule resolver (`ORCHESTRATOR_ROOT` → config → `.orchestrator/` → default) that actually ships. No references to the 5-rule resolver, the bridge, or the hash-preservation clause remain.

**Why this priority**: Incorrect migration documentation costs external users directly. Every minute a migrating user spends reconciling the document against the code is a minute the cutover's cost narrative underperforms.

**Independent Test**: Grep `commands/migrate.md` for "5-rule", "5 rule", "five-rule", "bridge". Count must be zero. Run `scripts/verify/no-legacy-resolver-docs.sh` against `docs/` and `commands/`. All gates must pass.

**Acceptance Scenarios**:

1. **Given** `commands/migrate.md` after P03 lands, **When** read cover-to-cover, **Then** the resolver is described as 4-rule with the current rule sequence.
2. **Given** `.orchestrator/DECISIONS.md` after P03 lands, **When** read, **Then** D007 is present and retires the FR-013 hash-preservation clause with an evidence pointer to this milestone's ROADMAP and the deliberation.
3. **Given** the `scripts/verify/no-legacy-resolver-docs.sh` gate, **When** run against `docs/`, `commands/`, and `references/`, **Then** it exits zero.

---

### User Story 6 - CLAUDE.md Reflects Constitution v2.1.0 (Priority: P2)

A developer opening `CLAUDE.md` for project orientation sees a principle count and enumeration that matches `.orchestrator/memory/constitution.md` v2.1.0 (15 principles, I–XV). The orientation document does not narrate a version of the project that existed two constitution-versions ago.

**Why this priority**: `CLAUDE.md` is the single orientation document every contributor and every LLM pair-programmer reads first. If it's wrong, every other doc inherits the wrong mental model.

**Independent Test**: `scripts/verify/principle-count-sync.sh` extracts the principle count from CLAUDE.md and the constitution file and compares them. They must match.

**Acceptance Scenarios**:

1. **Given** `CLAUDE.md:37,48-54` after P04 lands, **When** read, **Then** the document claims 15 governing principles and enumerates all 15 (at least by name + one-sentence gloss).
2. **Given** the `scripts/verify/principle-count-sync.sh` gate, **When** run, **Then** it exits zero and prints both sources agreeing.
3. **Given** a future constitution amendment adds principle XVI, **When** it lands without updating CLAUDE.md, **Then** the gate exits non-zero in CI.

---

### User Story 7 - M016 Attestation Scope Is Truthful (Priority: P2)

A developer reading `M016-SUMMARY.md` to understand the zero-prompt attestation understands that the measurement is scoped to `orchestrator:auto` Class A harness-trigger prompts on the attested posture. A re-run on a locked-down posture exists to bound the generalization.

**Why this priority**: The M016-SUMMARY phrasing was ruled overreach by the blind arbiter (dispute 5). A launch reviewer reading the summary would over-generalize the attestation. Narrow the framing; record the locked-down re-run as the empirical bound.

**Independent Test**: `M016-SUMMARY.md:8` explicitly scopes to `orchestrator:auto` Class A prompts. `.orchestrator/milestones/M020/phases/P04/evidence/zero-prompts-locked.md` records a re-run on a fresh clone with `.claude/settings.json` stripped to a minimal posture.

**Acceptance Scenarios**:

1. **Given** `M016-SUMMARY.md` after P04 lands, **When** read, **Then** the zero-prompt claim is qualified by its scope (command, prompt class, posture).
2. **Given** the M020/P04 locked-down re-run, **When** executed on a fresh clone against a completed phase, **Then** the prompt count and any new prompt sources are recorded in evidence.

---

## Out of Scope

- **Expanding the anti-pattern-lint scope beyond fenced code blocks.** The deliberation surfaced this as NEW-3 / RISK-08 but the arbiter ruled it a scope correction, not a standalone risk. Bundling it with this milestone would inflate scope; track it separately.
- **Broadening the hermetic-only glob beyond `m008-p07-*`.** Same ruling as above (NEW-4 / RISK-09 reclassified as scope correction).
- **Managed Agents backend (M010 scope).**
- **Conversus hook integration (lands in M011/P07 per D005).**
- **New `.orchestrator/` specs or milestones unrelated to the content-layer sweep.**

## Success Criteria

- **SC-1**: `orchestrator:init` resolves to a shipped skill on a fresh clone with zero approval prompts.
- **SC-2**: Zero occurrences of `Skill(speckit.orchestrator.*)` in `templates/`, `.claude/settings.json`, or the output of `orchestrator:init` run in a tmp directory.
- **SC-3**: Zero occurrences of `speckit.orchestrator.resume` (or any `speckit.orchestrator.*` runtime identifier) in `commands/auto.md`.
- **SC-4**: `commands/migrate.md` describes only the current 4-rule resolver; `DECISIONS.md` D007 records the FR-013 retirement.
- **SC-5**: `CLAUDE.md` principle count matches `.orchestrator/memory/constitution.md` exactly; `scripts/verify/principle-count-sync.sh` exits zero.
- **SC-6**: Six new verify gates exist and are wired into `scripts/verify/run-suite.sh`: `no-legacy-content.sh`, `no-legacy-resolver-docs.sh`, `packaging-skills-match-commands.sh`, `principle-count-sync.sh`, `test-suite-count-sync.sh`, `config-schema-matches-live.sh`.
- **SC-7**: A locked-down zero-prompt dogfood on a fresh clone produces zero prompts across the `init → auto → pause → resume` loop. Evidence lives at `.orchestrator/milestones/M020/phases/P04/evidence/`.
- **SC-8**: `.orchestrator/DECISIONS.md` contains a new D008 governance entry requiring a DECISIONS.md record for future content-layer drifts.

## Evidence Sources

- Conversus deliberation: `conversus-oss/deliberations/spec-kit-orc-audit/summary/final.md` (Phase 5 synthesis) and `conversus-oss/deliberations/spec-kit-orc-audit/arbitration/resolution.md` (blind-arbiter binding decisions).
- Arbiter rulings used as scoping authority: Dispute 1 (C1 reclassified critical, M016 SC-1 cascade framing rejected), Dispute 2 (A2+A5 propagation upheld critical, attestation-invalidation framing rejected), Dispute 3 (NEW-2 converged at high severity, ordering constraint identified), Dispute 4 (NEW-3/4/5 bifurcated — NEW-5 standalone, others scope corrections), Dispute 5 (RISK-05 reclassified high→medium, bounded summary edit).
