# Changelog

All notable changes to spec-kit-orchestrator are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This project uses semantic versioning.

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
