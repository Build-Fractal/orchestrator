# Changelog

All notable changes to spec-kit-orchestrator are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This project uses semantic versioning.

## [0.1.1] — 2026-03-22

### Fixed

- **evaluate command: spec discovery** — Added spec discovery step that lists available specs and confirms with the user instead of requiring the agent to guess the correct spec path
- **evaluate command: extension availability** — Added prerequisite check for extension scripts; exits with clear installation error instead of letting the agent create a manual scaffold that diverges from `scaffold.sh` output
- **evaluate command: scaffold.sh signature** — Fixed documented signature from `scaffold.sh <root> <milestone> <spec-path>` (3 args) to the correct `scaffold.sh <root> <milestone>` (2 args)
- **evaluate command: structured output** — Added `templates/evaluation.md` template for evaluation output; replaces unstructured "brief evaluation summary" that caused agents to invent ad-hoc formats (e.g., config.json with non-standard fields)
- **discuss command: tier awareness** — Added tier reading from `M###-EVALUATION.md` so the command informs the agent whether discussion is required (Tier C), optional (Tier B), or not applicable (Tier A)
- **discuss command: question guidance** — Added spec-driven question generation heuristic so the agent analyzes the spec for technology gaps, integration boundaries, scope edges, and other ambiguities instead of formulating questions from scratch
- **roadmap command: explicit tier reading** — Added explicit instruction to read tier from `M###-EVALUATION.md` with documentation that the Tier C discussion gate is enforced here (not in `derive-phase.sh`)
- **roadmap command: cross-cutting concerns** — Added guidance for identifying, recording, and referencing cross-cutting concerns that span multiple phases
- **roadmap command: dependency graph and execution order** — Added instructions to produce ASCII DAG visualization and ordered execution list with parallelization notes for dispatch scheduling
- **roadmap command: boundary map granularity** — Added scaling heuristic for boundary map specificity based on phase count (file paths < 8, interfaces 8–15, modules > 15)
- **roadmap command: validation output** — Validation results now recorded inline in the roadmap's `## Validation` section instead of ephemeral response text
- **roadmap command: demo sentence traceability** — Clarified that demo sentences are phase-level observables, not acceptance scenario paraphrases; traceability handled at task level during `plan-phase`
- **roadmap command: state/context-draft edge case** — Documented behavior when `derive-phase.sh` returns `planning` but Tier C context draft exists as `status: draft` (treat as `discussing`, block)
- **roadmap command: check-boundary-map.sh reference** — Added `scripts/verify/check-boundary-map.sh` to Reference Files with note that it runs during `verify`, not `roadmap`
- **roadmap template: structural expansion** — Added `## Cross-Cutting Concerns`, `## Dependency Graph`, `## Execution Order`, and `## Validation` sections to `templates/roadmap.md` for consistent roadmap structure across projects

### Added

- **`templates/evaluation.md`** — New template for evaluation output with tier, metrics, reasoning, spec path, and tier source fields
- **`references/installation.md`** — New reference doc documenting how to install the extension in a consumer project (which files to copy, what to exclude, directory structure, verification steps)
- **EVALUATION.md format** documented in `references/file-formats.md` with frontmatter schema and role description
- **auto-loop.sh: `--step=V` verification** — New verification step that reads task plan Verification/Must-Haves section and mechanically executes check commands, reporting `AUTO:VERIFY_PASS` or `AUTO:VERIFY_FAIL` with check counts
- **build-context.sh: `PHASE_PLAN` mode** — New planning payload assembly when task-id is `PHASE_PLAN`; includes roadmap phase section, upstream summaries, feature spec, context draft, decisions, and knowledge
- **auto-loop.sh: planning payload assembly** — `AUTO:PLANNING` output now includes `payload_bytes` and `payload_file` fields pointing to pre-assembled planning context on disk
- **phase-transition.sh: `--write` flag** — Accepts `--body`, `--observability_surfaces`, and `--verification_result` args; calls `write-summary.sh` directly with all derived + provided fields in a single command
- **claude-settings.json: compound command patterns** — Added `echo`, `for`, `if`, `[`, `true`, `false`, `wc -l`, `test -f`, `test -d` permission patterns for verification idioms

### Changed

- **`derive-phase.sh`** — Added design note comment explaining why the script is intentionally not tier-aware (tier-specific policy is at the command layer)
- **`references/state-machine.md`** — Added "Tier-Agnostic Derivation" section documenting the intentional separation between state derivation (file presence) and tier policy (command layer)
- **`references/file-formats.md`** — Added EVALUATION.md to directory structure diagram and file format reference
- **auto-loop.sh: ORCH_ROOT computation** — Fixed off-by-one: changed `$MILESTONE_DIR/..` to `$MILESTONE_DIR/../..` so ORCH_ROOT resolves to `.specify/orchestrator/` instead of `.specify/orchestrator/milestones/`; added stderr logging when `build-context.sh` fails instead of silently falling back to 40-byte minimal payload
- **auto-loop.sh: post-dispatch simplification** — Removed next-task scanning and phase-complete detection from `--step=G` post-dispatch; post-dispatch now only records result and updates lock; next-task determination deferred to pre-dispatch to avoid race with summary writing
- **phase-transition.sh: roadmap sync ordering** — Moved `sync-roadmap.sh --fix` to run after `--write` summary creation so roadmap checkboxes reflect the newly-completed phase
- **auto.md: permission documentation** — Added guidance on common permission patterns that trigger prompts, compound command patterns, and subagent permission inheritance
- **auto.md: verification integration** — Updated task-level verification instructions to use `auto-loop.sh --step=V` instead of manual grep checks
- **auto.md: phase summary workflow** — Updated to use `phase-transition.sh --write` instead of manual `write-summary.sh` invocation with 16 flags
- **auto.md: planning payload** — Updated to reference pre-assembled `payload_file` from `AUTO:PLANNING` output instead of manual context assembly

## [0.1.0] — 2026-03-20

### Added

- **10 orchestrator commands**: evaluate, discuss, roadmap, plan-phase, dispatch, auto, verify, status, resume, consolidate
- **23 helper scripts** organized by concern: state (3), dispatch (3), verify (5), knowledge (4), lifecycle (7), util (1)
- **13 output templates** with `{{placeholder}}` syntax and YAML frontmatter convention
- **4 progressive disclosure reference docs**: state machine, verification ladder, tier definitions, file formats
- **7 test suites** with 334 assertions covering structure, state machine, design artifacts, core commands, autonomous mode, knowledge lifecycle, and cross-slice integration
- **3-tier scope classification** (A/B/C) with manual override and tier promotion
- **9-state file-presence state machine** derived entirely from disk artifacts — no stored state field
- **4-tier verification ladder**: static checks, command execution, behavioral validation, human review
- **Autonomous dispatch loop** with budget enforcement, stuck detection, and pause handling
- **Crash recovery** via lock files, PID liveness checks, and recovery briefing synthesis
- **Knowledge generation**: structured summaries (15/16-field YAML frontmatter), append-only decisions register, scoped knowledge file
- **Artifact consolidation** achieving 87% reduction in test scenarios
- **5 spec-kit lifecycle hooks**: before/after tasks, before/after implement, before commit
- **Multi-layer configuration**: environment vars > local config > project config > extension defaults
- **Git worktree isolation** (optional, via `git_isolation` config)
- **External modification detection** at phase boundaries via git diff
- **7 constitutional principles** governing all development decisions

### Not Included (Deferred)

- US7 — GitHub Agentic Workflows runtime (M002 candidate)
- US8 — APM packaging and distribution (M002 candidate)
- User-facing documentation (`docs/getting-started.md`, `docs/configuration.md`)
- Distribution manifests (`apm.yml`, `SKILL.md`, `.extensionignore`)
- Multi-agent runtime validation (Claude Code-only for v0.1.0)

### Post-Release: Audit Remediation (2026-03-20)

Four sequential remediation phases applied after initial build:

1. **Documentation accuracy + spec clarifications** — frontmatter field counts, FR-029 trigger phrasing, test output format, lock file CI notes, DONE_WITH_CONCERNS documentation
2. **Gotchas sections** — added to all 10 command documents documenting known failure modes, context pollution patterns, and anti-patterns (FR-030)
3. **Structural test coverage** — Tier A zero-artifacts, boundary map enforcement, external modification detection, payload ratio verification (+27 assertions)
4. **Behavioral test coverage** — pause/resume round-trip, idempotency tests, multi-milestone scope filtering (+27 assertions — total: 307 → 334)

### Post-Release: Audit Review (2026-03-20)

- **Spec alignment**: Added implementation notes for FR-045 (destructive ops delegation to agent runtime), FR-067/FR-068/FR-069 (adapter interface mapping to extension architecture), SC-007 (Claude Code-only acknowledgment)
- **Spec field counts**: Added `type` field to file format specifications (task: 15 fields, phase/milestone: 16 fields)
- **Auto mode**: Made roadmap reassessment mandatory at phase transitions (FR-009/FR-061)
- **README fixes**: Architecture diagram (`util/` placement), Bash version (4+ → 3.2+), test counts (307 → 334), agent compatibility (Claude Code-only acknowledgment), quickstart visualization
- **KNOWLEDGE.md**: Added adapter interface design note, Claude Code-only validation note
