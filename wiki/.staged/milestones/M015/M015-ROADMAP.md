---
schema_version: "1.0"
type: roadmap
milestone: "M015"
feature_ref: "015-standalone-cutover"
feature_spec: "specs/015-standalone-cutover/spec.md"
vision: "Cut the orchestrator over to a clean standalone posture: remove the spec-kit host, migrate state to .orchestrator/, reframe the docs, and prove it all works end-to-end before M009 launch."
tier: "C"
created_at: "2026-04-15T00:00:00Z"
updated_at: "2026-04-15T00:00:00Z"
---

## Phases

- [x] **P01**: Spec-Kit Host Removal — "The repo no longer contains extension.yml, dogfooded /speckit.* slash commands, .specify/scripts/bash/, or .specify/templates/, and no retained code references the deleted paths."
  - Risk: medium
  - Depends: none
  - Boundary Map:
    - Produces:
      - Deletion: `extension.yml`
      - Deletion: `.claude/commands/speckit.*.md` (9 files: analyze, checklist, clarify, constitution, implement, plan, specify, tasks, taskstoissues)
      - Deletion: `.specify/scripts/bash/` (entire directory)
      - Deletion: `.specify/templates/commands/` (entire directory)
      - Deletion: `.specify/templates/{plan,spec,tasks,checklist,constitution,agent-file}-template.md`
      - Disposition decision applied to: `scripts/verify/m002-p07-extension-registration.sh`, `tests/fixtures/verify-pass/extension.yml`, `tests/fixtures/verify-fail/extension.yml` (each either deleted or rewritten for standalone shape)
      - Fix: `scripts/lifecycle/generate-permissions.sh` argument-handling bug surfaced during evaluate (preflight reported `permissions=error` because the script does not accept the tier as the positional arg preflight passes)
      - Invariant: no retained file in `commands/`, `scripts/`, `references/`, `docs/`, `templates/`, or `tests/` contains references to deleted paths
    - Consumes: none

- [x] **P02**: State Tree Migration — "Orchestrator state lives at `.orchestrator/`, the constitution lives at `.orchestrator/memory/constitution.md`, and `scripts/state/resolve-root.sh` no longer contains the `.specify/orchestrator/` bridge rule."
  - Risk: high
  - Depends: P01
  - Boundary Map:
    - Produces:
      - Created: `.orchestrator/` populated with all milestone, knowledge, decision, telemetry, and lock state migrated from `.specify/orchestrator/`
      - Deletion: `.specify/orchestrator/` (after migration verified)
      - Moved: `.specify/memory/constitution.md` → `.orchestrator/memory/constitution.md`
      - Modified: `scripts/state/resolve-root.sh` (rule 4 removed, former rule 5 renumbered to rule 4; rules 1–3 unchanged in semantics)
      - Modified: every script, command, template, and reference that referenced `.specify/orchestrator/` (as a runtime path, not as a migration source) updated to `.orchestrator/`
      - Modified: every reference to `.specify/memory/constitution.md` updated to `.orchestrator/memory/constitution.md`
      - Invariant: `scripts/migrate/adapters/speckit.sh`, `scripts/state/detect-speckit.sh`, and `scripts/dispatch/adapters/format/speckit.sh` may still reference `.specify/` paths — those are migration-source detectors, not orchestrator runtime paths
    - Consumes:
      - P01: host removal complete (extension.yml gone, dogfooded commands gone) — required because dropping the bridge rule is only safe once the host that depended on it is also gone

- [x] **P03**: Documentation Reframe — "Current-state docs describe the orchestrator as a standalone tool; spec-kit appears only in changelog history or migration-context callouts."
  - Risk: low
  - Depends: P02
  - Boundary Map:
    - Produces:
      - Modified: `README.md` — reframed from "spec-kit extension" to "standalone orchestrator"; install/usage flow described without spec-kit prerequisites
      - Modified: `CLAUDE.md` — "What This Is" + "SDD Workflow" sections rewritten to describe standalone usage; `/speckit.*` references removed from the workflow section
      - Modified: `references/architecture.md` — architecture diagrams and prose reframed for standalone
      - Modified: `references/installation.md` — install steps describe standalone install (skills bundle, init flow); spec-kit-extension install removed
      - Modified: `docs/getting-started.md` — quickstart describes standalone path
      - Modified: `CHANGELOG.md` — append M015 entry; existing historical entries left intact
      - Added or expanded: migration documentation describing how users coming from spec-kit adopt the orchestrator (FR-012)
      - Invariant: `.specify/orchestrator/milestones/M00*/M00*-SUMMARY.md` and other historical artifacts NOT rewritten — immutable per spec assumption
    - Consumes:
      - P02: state at `.orchestrator/`, constitution at `.orchestrator/memory/constitution.md` (docs describe these locations)
      - P01: host removed (docs describe install with no extension.yml and no `/speckit.*` slash commands)

- [x] **P04**: End-to-End Validation — "On a fresh clone with no spec-kit installed, `orchestrator-auto` completes a full evaluate→roadmap→plan-phase→auto cycle, all 7 test suites pass, `orchestrator-doctor` is clean, and the spec-kit migration adapter still produces a valid `.orchestrator/` from a spec-kit-shaped fixture."
  - Risk: medium
  - Depends: P03
  - Boundary Map:
    - Produces:
      - Validation evidence: clean-clone end-to-end transcript of `orchestrator-auto` in Claude Code native mode with no spec-kit installed
      - Validation evidence: `orchestrator-doctor` report (clean — no orphans, no stale references, no missing files)
      - Validation evidence: all 7 test suites passing transcript (no skipped tests hiding removed behavior)
      - Validation evidence: spec-kit migration adapter produces a valid `.orchestrator/` from a spec-kit-shaped fixture
      - File: `M015-SUMMARY.md` consolidating the cutover and recording validation results
      - File: `M015-VERIFICATION.md` with PASS/FAIL per FR-001 through FR-019
    - Consumes:
      - P01: host removal (validation must run with no host present)
      - P02: state at `.orchestrator/` (validation must run against the new state location)
      - P03: docs reframed (clean-clone install validation reads the new docs)

## Cross-Cutting Concerns

- **Hard-migration discipline (no graceful degradation)** — touches P01, P02, P03, P04. P01 establishes the pattern by *deleting* removed files (no deprecation, no compat shim, no feature flag) per [M007](../../milestones/M007/index.md)'s no-graceful-degradation rule. P02 carries the same discipline into the resolver edit (rule 4 deleted outright, not gated). P03 reframes docs without preserving "extension mode" callouts. P04 validates that no half-cutover state exists.

- **Migration adapter preservation** — touches P01, P02, P04. The retained spec-kit *migration* surface (`scripts/migrate/adapters/speckit.sh`, `scripts/state/detect-speckit.sh`, `scripts/dispatch/adapters/format/speckit.sh`, `commands/migrate.md`) MUST NOT be touched by P01 or P02. P04 explicitly validates these still work against a spec-kit-shaped fixture. The cleanest test for "is this code in the keep or remove bucket?" is: does it exist *because of* spec-kit hosting (remove) or *because of* spec-kit migration users (keep)?

- **Historical artifact immutability** — touches P01, P03. Phase summary files, milestone summary files, prior CHANGELOG entries, and prior plan artifacts MUST NOT be rewritten during the cutover even if they reference the now-removed spec-kit hosting model. They are immutable history. Only current-state documentation surfaces are reframed.

- **Reference-update completeness** — touches P01, P02, P03. After deletions or moves, the cutover MUST sweep every retained file for stale references to deleted paths (`extension.yml`, `.specify/scripts/bash/`, `.specify/templates/`) and stale references to moved paths (`.specify/orchestrator/`, `.specify/memory/constitution.md`). Per the spec's edge case about `.claude/settings.json` permissions, the sweep includes that file (remove permission entries pointing to deleted scripts; preserve entries for retained scripts).

## Dependency Graph

```
P01 (host removal, medium)
  ↓
P02 (state migration, high)
  ↓
P03 (docs reframe, low)
  ↓
P04 (e2e validation, medium)
```

Strict linear chain. No phase has more than one upstream. No phase can run concurrently with another. This is the canonical Tier B sequential shape.

## Execution Order

1. **P01** — foundation; no dependencies. Runs first because every downstream phase assumes the host is gone (P02 drops the bridge that the host depended on, P03 documents the post-removal reality, P04 validates against a host-free clone).
2. **P02** — depends on P01. Runs second despite being highest risk because the high-risk-first rule (FR-043) only applies *among phases with satisfied dependencies* — P02's dependency (P01 host removal) is the gating constraint. Running P02 second also surfaces state-migration failures earlier than running it last, which is preferred for risk-shedding.
3. **P03** — depends on P02. Runs third because the documentation reframe describes the post-state-migration shape (state at `.orchestrator/`, constitution at `.orchestrator/memory/`). Running it before P02 would force a double rewrite.
4. **P04** — depends on P03. Runs last because end-to-end validation requires the fully cut-over state (host gone, state moved, docs reframed) — anything earlier would validate a half-cutover that does not exist after the milestone closes.

No phases execute concurrently. Tier B sequential default applies (FR-054).

## Validation

- **No conflicting producers**: PASS — each phase touches distinct surfaces. P01 deletes host-side files; P02 modifies the resolver and migrates the state tree; P03 modifies current-state documentation files; P04 produces only validation evidence and the final summary. The only retained file touched by more than one phase is `CLAUDE.md` (P03 reframes it) and that is owned exclusively by P03.

- **All consumed items have producers**: PASS — P02 consumes P01 (host removal); P03 consumes P01 (host removal) and P02 (state at new location); P04 consumes P01, P02, P03 (full cutover state). All consumed items map to upstream `Produces` entries.

- **DAG is acyclic**: PASS — strict linear chain P01 → P02 → P03 → P04. No cycles possible.

- **Demo sentence coverage**: PASS — each phase has a concrete, observable demo sentence:
  - P01: `extension.yml` and dogfooded `/speckit.*` commands gone; no retained references
  - P02: state at `.orchestrator/`; resolver no longer contains rule 4
  - P03: docs frame standalone; spec-kit only in changelog/migration contexts
  - P04: clean-clone `orchestrator-auto` runs successfully, doctor clean, all suites pass, migration adapter still works
