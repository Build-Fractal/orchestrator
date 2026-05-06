---
type: papercut-proposal
created: 2026-05-06
updated: 2026-05-06 (broader sweep landed)
status: shipped (with deferred residue noted below)
priority: low
size: shipped — broader sweep applied
---

# Paper-cut: User-facing command names use `/orchestrator-X` form, not `orchestrator:X` or `speckit.orchestrator.X`

## Problem

The orchestrator's command docs and reference material historically used two namespaced forms when referring to commands in user-facing prose:

- `orchestrator:X` (colon form — spec-kit-shaped command-document naming convention used in H1 headings)
- `speckit.orchestrator.X` (dotted namespace alias used in suggestion strings, "next action" hints, error messages)

The form a user actually types at the Claude Code prompt is `/orchestrator-X` (slash + hyphen). This forced users to mentally translate between docs and invocation, which the user explicitly flagged as friction.

Additionally, the user wants a clean OSS launch posture where orchestrator never proactively recommends or names adjacent unrelated tools — specifically GSD (`gsd:*`, `gsd-*` agents) and spec-kit beyond what the migration tooling structurally requires.

## Resolution shipped 2026-05-06

### Phase 1 — High-impact user-facing surfaces (initial sweep)

- `commands/auto.md` — 7 emit strings (lock states, tier B/A guidance, pause/resume/rotation next-actions, gotchas)
- `commands/resume.md` — 7 emit strings (path-A/B continuation, idempotency fallthrough, error-handling)
- `docs/getting-started.md` — 8 workflow example blocks (init / evaluate / discuss / roadmap / plan-phase / dispatch / auto / resume / status / doctor)
- `scripts/diagnostics/render-status-json.sh` — `_section_next_action` printf
- `scripts/lifecycle/recovery-briefing.sh` — both recovery-plan branches
- `scripts/migrate/transform/report.sh` — migration report next-steps

### Phase 2 — GSD and spec-kit suggestions outside the migration path

- `commands/auto.md` — Tier A "Use spec-kit commands directly" replaced with host-runtime guidance per CLAUDE.md
- `commands/auto.md`, `templates/claude-code-appendix.md` — `gsd-*` anti-pattern callouts reworded to "framework-named agents from other tools that may also be installed on the user's machine" (preserves the safety guidance without naming GSD)
- `templates/compression-tier3-prompt.md` — spec-kit/`gsd:*` example tokens generalized to "orchestrator command names (slash form, colon form, or namespaced alias)"
- `commands/discuss.md` — Tier A "Use standard spec-kit commands directly" replaced with host-runtime guidance
- `commands/evaluate.md` — "Run `speckit.specify`" → `/orchestrator-specify`; "spec-kit process flows" → "Spec-Driven Development (SDD) process flows"
- `docs/getting-started.md` — gratuitous "you do not need spec-kit installed" wording rewritten to focus on the format-adapter mechanism

### Phase 3 — Inline `speckit.orchestrator.X` cross-references in command bodies and reference docs

All user-facing command-name suggestions in command bodies and reference material flipped to `/orchestrator-X` form:

- `commands/dispatch.md` — verify reference
- `commands/auto.md` — consolidate, verify, plan-phase references (5 occurrences) + planning-payload prompt body
- `commands/plan-phase.md` — auto, dispatch, evaluate, roadmap references
- `commands/discuss.md` — status, dispatch, roadmap, evaluate references (8 occurrences)
- `commands/roadmap.md` — evaluate, discuss references (5 occurrences)
- `commands/consolidate.md` — verify references (2 occurrences)
- `commands/evaluate.md` — specify, roadmap, discuss references
- `commands/status.md` — full state-to-recommended-action table (9 occurrences) + error-handling fallthroughs
- `commands/migrate.md` — post-migration status suggestion (1 occurrence; historical-context references about the namespace alias retained per AD-15)
- `references/status-json-schema.md` — example next_action text
- `references/tier-definitions.md` — Tier B and Tier C "Commands Available" lists (15 occurrences)
- `references/file-formats.md` — example evaluation file output
- `references/state-machine.md` — per-state "what it means for the orchestrator" recommendations (~12 occurrences across 7 states)
- `templates/claude-code-appendix.md` — autonomous-loop intro
- `templates/compression-tier3-prompt.md` — reference example
- `scripts/dispatch/build-context.sh` — phase-planning prompt body (build-context dispatches the planner with this string)

### Phase 4 — Verifier sync (M002, M011, M013)

Closed-milestone verifiers that asserted specific token strings in command-doc bodies were updated to assert the current shape:

- `scripts/verify/m002-p07-doctor-md-sections.sh` — `speckit.orchestrator.doctor` → `orchestrator:doctor`
- `scripts/verify/m011-p05-roadmap-doc-references-intensity.sh` — `speckit.orchestrator.discuss` → `/orchestrator-discuss`
- `scripts/verify/m011-p06-ingest-doc-conventions.sh` — H1 heading check `# speckit.orchestrator.ingest` → `# orchestrator:ingest` (this verifier was already failing on master against pre-existing doc drift; this brings it back to PASS)
- `scripts/verify/m013-p01-github-status-command.sh` — H1 heading check synced to current `# orchestrator:github-status`
- `scripts/verify/m013-p02-github-init-command.sh` — same sync

All four verifiers now PASS. M029/P01 deliverable verifiers (render-status-json shape, status headline shape, etc.) all still PASS.

## Deferred residue (intentional, not a defect)

These references to `speckit.orchestrator.X` or `speckit.*` remain in the codebase intentionally:

1. **`commands/migrate.md` AD-15 architectural-context block** — explicitly documents the namespace-alias decision and tracks the cohort-rename roadmap. Renaming this would invert the document's purpose.
2. **`templates/claude-settings.json` and `templates/autonomy-defaults.yaml` permission allowlists** — `Skill(speckit.orchestrator.*)` is a *functional* permission pattern that grants skill access to namespace-alias commands. Removing it would break invocations of any user that has come to depend on the alias form.
3. **`templates/instruction-schema.md`** — schema documentation of legacy command-name shape. Architectural reference.
4. **`docs/migrating-from-speckit.md`** — the migration tool's user guide. Naming spec-kit is structurally required.
5. **`references/RENAME-PLAN.md`** — the explicit rename-plan proposal that documents the intended transition. Its body of `speckit.orchestrator.*` references describes the things being renamed.
6. **`scripts/migrate/adapters/speckit.sh`, `scripts/migrate/adapters/gsd1.sh`, `scripts/migrate/adapters/gsd2.sh`, plus `scripts/migrate/transform/*` and `scripts/migrate/lib/*` files** — adapter implementations for the migration tool. These name spec-kit and GSD by intent.
7. **`commands/start.md` and `references/branch-detection.md`** — the migration-routing code paths that detect `.gsd/`, `.gsd2/`, and `.specify/` directories to identify the source format.
8. **`packaging/SKILL.md`** — translation note describing how to map the namespaced label to the slash form.

In short: the migration tool surface is allowed to name its source tools, and architectural / governance documents that record the rename history retain those names. Everywhere else, the user-visible prompt surface uses `/orchestrator-X` exclusively.

## Memory note

Companion memory entry at `feedback_orchestrator_command_hyphens.md` captures the user-facing rule:

- Always use `/orchestrator-X` form when referring to orchestrator commands in responses
- Never proactively recommend `gsd:*`, `/gsd-*`, `speckit:*`, or `speckit.*` commands (unrelated tools that happen to be installed on this machine)
- The single exception: the user has explicitly invoked one of those, or is asking specifically about migrating from spec-kit / GSD

## Verification

After the sweep:
- `grep -rln "speckit\.orchestrator\." commands/ templates/ docs/ references/ scripts/ packaging/` returns only the deferred-residue files listed above
- All touched closed-milestone verifiers PASS
- M029/P01 deliverable verifiers still PASS (no regression)
- M029/P02 deliverables unaffected (no edits to P02 surface)

## See also

- `feedback_orchestrator_command_hyphens.md` — user-facing convention memory
- `references/RENAME-PLAN.md` — full rename-plan history including the namespace-alias purge
- `commands/migrate.md` AD-15 — the architectural decision the deferred residue cites
