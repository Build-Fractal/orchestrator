---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T04 (Phase P06, Milestone M008)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (25 entries) | 19-588 | ~4900 | filtered |
| Decisions | 590-592 | ~100 | filtered |
| Constraints | 594-599 | ~100 | required |
| Scope | 601-629 | ~300 | required |
| Upstream Context | 631-694 | ~2800 | required |
| Task Plan | 696-837 | ~1500 | required |
| State Context | 839-845 | ~100 | required |
| **Total** | | **~9800** | |

## Knowledge

<!-- 25 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 38
source_unit: "M001/P01"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM002, MEM004]
content_hash: ""
---

# MEM001: Shell Script Conventions

Bash 3.2 compatibility is mandatory — no `declare -A` (associative arrays). Use parallel indexed arrays (`arr_k_0`, `arr_v_0`, etc.) instead. macOS ships bash 3.2.

YAML parsing uses `grep`/`sed`/`awk` only — no python3 or jq hard dependency. jq used as optional fallback via `json_field()` helper.

Structured output: all scripts emit prefixed lines to stdout (`PASS:`, `FAIL:`, `LOCK:`, `STUCK:`, `BUDGET:`, `SUMMARY:`, `DECISION:`, `KNOWLEDGE:`, `ROLLBACK:`, `VALIDATE:`, `CONSOLIDATE:`). Errors to stderr. Exit 0 on success, 1 on failure.

Dual argument style: scripts accept both positional subcommands and `--flag` style for human and programmatic use.

Idempotent operations: all scaffolding/creation scripts check-before-create with early exit on existing state.

---
id: MEM002
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 38
source_unit: "M001/P01"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM001]
content_hash: ""
---

# MEM002: Test Conventions

Pass/fail tracking: `pass()` and `fail()` functions with parallel indexed arrays (bash 3.2 safe). Summary count at end.

Fixture pattern: state fixture directories under `tests/fixtures/` named by scenario (`state-executing`, `verify-pass`, `dispatch-state`).

PID 1 trick: tests use PID 1 (launchd on macOS) as guaranteed-alive process for `ACTIVE` lock detection — subshell PIDs die before assertion.

Cross-reference validation: integration tests extract script/template paths from command files via `grep -oE` regex, then verify existence/executability. Self-maintaining as commands evolve.

Self-diagnostic pattern: test files verify their own `fail()` messages include actionable file paths or contract identifiers.

---
id: MEM003
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 38
source_unit: "M001/P01"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM014]
content_hash: ""
---

# MEM003: State Machine Design

9 states derived from file presence on disk (priority-ordered rules in `derive-phase.sh`).

Rule 3b addition: roadmap exists but active phase has no `P##-PLAN.md` -> `planning` (handles gap between roadmap creation and phase planning).

Empty milestone directory (no `M###-*` files) -> `pre-planning` (distinct from scaffolded).

Milestone ID detected from `M###-*.md` files inside directory, not from directory basename (enables arbitrary fixture names).

---
id: MEM004
scope_tags: "[project], [milestone:M005]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 38
source_unit: "M005/P03"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM001]
content_hash: ""
---

# MEM004: Pure Lib Extraction Pattern

Dispatch scripts (build-context.sh, compress-payload.sh) source pure function libs (payload-transforms.sh, manifest-builder.sh) instead of defining inline duplicates. Pure functions take stdin/arguments, produce stdout, perform no file I/O. Established in P03 per AD-5.

---
id: MEM005
scope_tags: "[project], [milestone:M005]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 32
source_unit: "M005/P01"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM019]
content_hash: ""
---

# MEM005: Content-Hash Idempotency

Knowledge entries carry `content_hash: sha256:{hex}` in frontmatter. `hash.sh` provides `compute_content_hash` (string) and `compute_file_body_hash` (file body). `create-entry.sh` writes hash at creation; `update-entry.sh` recomputes on `--body` changes; `rebuild-index.sh` compares stored vs computed hashes for change detection and self-heals drift. `record-result.sh` accepts `outcome=unchanged` for stagnation signaling.

---
id: MEM006
scope_tags: "[project], [milestone:M005]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 32
source_unit: "M005/P04"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM015]
content_hash: ""
---

# MEM006: Scored Health Reporting

`run-doctor.sh` aggregates 12 checks (4 legacy + 8 DOCTOR:) into `Checks passed: N/M` with HEALTHY/NEEDS_ATTENTION status. Legacy checks use exit-code pass/fail; new checks parse DOCTOR: status lines. Advisory checks (check-plans.sh) counted separately. History appended to `doctor-history.jsonl` per run.

---
id: MEM007
scope_tags: "[project], [milestone:M005]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 32
source_unit: "M005/P07"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: []
content_hash: ""
---

# MEM007: Autonomy Permission Pipeline

`generate-permissions.sh` introspects project toolchain (package.json, Makefile, extension.yml, config files, agent host markers) and emits canonical JSON. `write-permissions.sh` translates to `.claude/settings.json` with additive merge for user-authored files. `check-permissions.sh` detects permission drift. Policy is declarative in `autonomy-defaults.yaml` read via `recipe-parser.sh`.

AD-19 script-file verification shape: task plan Check: commands must use single-script invocations, not inline compound bash.

---
id: MEM008
scope_tags: "[project], [milestone:M001]"
category: patterns
confidence: 0.85
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 38
source_unit: "M001/P01"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM001]
content_hash: ""
---

# MEM008: Audit Remediation Patterns

Shared JSON Utility: `scripts/util/json-field.sh` extracts `json_field()` into a sourceable utility. Lock-manager and recovery-briefing `source` it instead of duplicating the function. Pattern: extract shared functions into `scripts/util/` and `source` them.

ISO 8601 Standardization: all timestamps use `date -u +%Y-%m-%dT%H:%M:%SZ` (UTC, ISO 8601). Rollback-phase.sh was using `date +%Y%m%dT%H%M%S` — fixed for consistency.

IFS Safety: `IFS=',' read -ra` is local to the `read` built-in — safe, does not leak. For `IFS=','` in `for` loops, wrap in subshell `(IFS=','; ...)` to prevent leaking into parent scope.

AGENTS.md -> README.md Convention: documentation files in `commands/`, `references/`, and `templates/` directories renamed from `AGENTS.md` to `README.md`. Integration tests exclude `README.md` from command file checks.

---
id: MEM009
scope_tags: "[project], [milestone:M006]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 32
source_unit: "M006/P01"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM010, MEM011]
content_hash: ""
---

# MEM009: Documentation-as-Verification

Writing documentation and running every documented command catches drift that tests miss. M006 found and fixed a stale routing fallback value in references/file-formats.md through this process. The mechanical discipline of verify-as-you-write surfaces real bugs.

---
id: MEM010
scope_tags: "[project], [milestone:M006]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 32
source_unit: "M006/P01"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM009]
content_hash: ""
---

# MEM010: Cross-Link Validation Scripts

Cross-link validation scripts (checking that doc A references doc B) catch missing references that manual review misses. Every P01-P06 phase in M006 required cross-link fixes during the verification step. Pattern: always create cross-link verification scripts during planning.

---
id: MEM011
scope_tags: "[project], [milestone:M002]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 32
source_unit: "M002/P04"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM009]
content_hash: ""
---

# MEM011: Validation-as-Task Pattern

When scripts pre-exist from prior milestones, phase tasks verify correctness rather than creating new code. T01 creates verification scripts, T02+ runs them. Most phases in M002 P04-P07 required minimal or no code changes — the verification process itself was the deliverable.

---
id: MEM012
scope_tags: "[project]"
category: conventions
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 38
source_unit: "M001/P01"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM013]
content_hash: ""
---

# MEM012: Command File Structure

All command `.md` files follow identical structure:

```
YAML frontmatter (description field)
-> Title
-> Prerequisites / State Check
-> Core Workflow (numbered sections)
-> Output
-> Idempotency
-> Error Handling
-> Referenced Scripts/Templates
```

Commands reference scripts by relative path in "Referenced Scripts" sections. Integration tests verify all cross-references resolve to existing, executable files.

---
id: MEM013
scope_tags: "[project]"
category: conventions
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 38
source_unit: "M001/P01"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM012]
content_hash: ""
---

# MEM013: Template Convention

YAML frontmatter with `schema_version` + `type` fields. Body uses `{{placeholder}}` syntax for dynamic values. No hardcoded milestone/phase/task IDs (context-free per FR-074).

Summary frontmatter: 15-field base schema for tasks (`schema_version`, `type`, `id`, `parent`, `milestone`, `provides`, `requires`, `affects`, `key_files`, `key_decisions`, `patterns_established`, `drill_down_paths`, `duration`, `verification_result`, `completed_at`); phase/milestone summaries add `observability_surfaces` for 16 fields.

---
id: MEM014
scope_tags: "[project]"
category: conventions
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 38
source_unit: "M001/P01"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM003, MEM018]
content_hash: ""
---

# MEM014: Interface Contracts

**Scripts -> Commands**: Commands reference scripts by relative path in "Referenced Scripts" sections. Integration tests verify all cross-references resolve to existing, executable files.

**State -> Dispatch**: `derive-phase.sh` outputs single state word to stdout. `auto.md` reads this to determine loop action. Budget/stuck/lock checks gate dispatch.

**Verification -> State Advancement**: Verification scripts output `PASS:`/`FAIL:` lines. `auto.md` consumes these: all-pass -> advance, any-fail -> retry once then pause. Phase advancement requires verification pass.

**Knowledge -> Context Assembly**: `scope-filter.sh` filters `KNOWLEDGE.md`/`DECISIONS.md` by scope tags. `build-context.sh` assembles filtered knowledge + task plan + upstream summaries into dispatch payload. Budget metrics reported to stderr.

**Templates -> Output**: Commands use `templates/*.md` as starting points. Agent fills `{{placeholder}}` values. Template `schema_version` field enables future format migration.

---
id: MEM015
scope_tags: "[project], [milestone:M005]"
category: conventions
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 32
source_unit: "M005/P04"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM006, MEM017]
content_hash: ""
---

# MEM015: DOCTOR Structured Output Protocol

All diagnostic scripts emit a single structured line for machine parsing by run-doctor.sh:

```
DOCTOR:<CHECK> status=<ok|warn|skip|drift|missing> key=value ...
```

Advisory checks (like check-plans.sh) always exit 0; non-advisory checks exit 0 on ok, 1 on warn. Established in M005/P04, extended through P05-P07.

---
id: MEM016
scope_tags: "[project], [milestone:M005]"
category: conventions
confidence: 0.85
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 32
source_unit: "M005/P02"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: []
content_hash: ""
---

# MEM016: Cost Source Closed Enum

Telemetry entries carry `cost_source` field (estimated/reported/unknown) with closed enum validation. `aggregate-metrics.sh` groups by cost_source, distinguishes null cost (unknown) from zero cost (free). Legacy entries classified by presence of cost data.

---
id: MEM017
scope_tags: "[project], [milestone:M005]"
category: conventions
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 32
source_unit: "M005/P05"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM015]
content_hash: ""
---

# MEM017: Gate Verdict Protocol

`scripts/lib/verdicts.sh` provides `emit_verdict`, `parse_verdict`, `orch_is_verdict` with four constants: PASS, BLOCK, WARN, NEEDS_REVIEW. `hooks.sh` captures hook stdout, parses VERDICT lines, resolves multiple verdicts to most severe, and maps to block/warn/continue behavior. Backward compatible when no VERDICT present. Provider convention documented in `references/provider-convention.md`.

---
id: MEM018
scope_tags: "[project]"
category: conventions
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 38
source_unit: "M001/P01"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM014]
content_hash: ""
---

# MEM018: Runtime Adapter Interface

The spec defines 5 abstract adapter operations (`dispatch-task`, `await-completion`, `collect-result`, `signal-failure`, `inject-context`). In the v0.1.0 extension architecture (markdown commands + shell scripts), these are realized as:

- **dispatch-task / inject-context**: `build-context.sh` assembles the payload; command documents instruct the agent to dispatch (subagent or sequential) based on `detect-capabilities.sh` output.
- **await-completion / collect-result**: The agent runtime handles task execution and writes artifacts to disk. The orchestrator detects completion via file presence (task summary exists = done).
- **signal-failure**: Verification scripts (`check-must-haves.sh`, `run-commands.sh`) detect failure by checking artifacts against must-haves. Failures are recorded in `execution-log.jsonl`.

No formal `adapter-*.sh` scripts exist. The agent interpreting the markdown command IS the adapter. This satisfies FR-067-069's intent (no platform-specific branching in core logic) while being idiomatic for the extension architecture.

---
id: MEM019
scope_tags: "[project], [milestone:M002]"
category: conventions
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 32
source_unit: "M002/P01"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM005, MEM020]
content_hash: ""
---

# MEM019: Three-Temperature Knowledge Architecture

- **Hot** (KNOWLEDGE-INDEX.md, always loaded): pipe-delimited index with 8 fields: id, scope_tags, category, confidence, created_at, last_verified, hit_count, description. Derived artifact — rebuildable from detail files via rebuild-index.sh.
- **Warm** (knowledge/{category}/{entry-id}.md, loaded on scope-match): full detail files with YAML frontmatter and body content. Resolved by resolve-entries.sh from MEM IDs.
- **Cold** (knowledge/archive/, never auto-injected): archived entries moved by archive-entry.sh. Excluded from index rebuild.

---
id: MEM020
scope_tags: "[project], [milestone:M002]"
category: conventions
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 32
source_unit: "M002/P01"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM019]
content_hash: ""
---

# MEM020: Dispatched Agents Must Write Summaries

Dispatched agents must write `T##-SUMMARY.md` files using `write-summary.sh` — without the summary file, the auto-loop cannot advance to the next task. Include explicit write-summary.sh instructions in dispatch prompts.

---
id: MEM021
scope_tags: "[project]"
category: lessons
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 38
source_unit: "M001/P01"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM022]
content_hash: ""
---

# MEM021: PID 1 macOS kill -0 Behavior

`kill -0 $pid` for PID 1 on macOS returns EPERM (exit 1) — same exit code as ESRCH (process not found). Fix: check stderr for "perm" — EPERM means alive (different user), ESRCH means dead.

---
id: MEM022
scope_tags: "[project]"
category: lessons
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 38
source_unit: "M001/P01"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM021]
content_hash: ""
---

# MEM022: Lock Manager PID Subshell Issue

`$(bash lock-manager.sh create ...)` runs in a subshell whose PID dies before the status check. Fix: tests patch the lock file PID to a known-alive process (PID 1) after creation.

---
id: MEM023
scope_tags: "[project], [milestone:M004]"
category: lessons
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 32
source_unit: "M004/P06"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM024, MEM025]
content_hash: ""
---

# MEM023: Backtick-in-Plan-Artifacts Breaks Must-Have Checks

`check-must-haves.sh` includes backtick characters literally when parsing Artifact and Key Links sections from phase plans. Paths in these sections must NOT be wrapped in markdown backticks or the artifact/key-link checks will fail with 'not found' errors pointing to paths like `` `path/to/file` `` instead of `path/to/file`. Truth Check: commands are unaffected because the parser strips the outer backticks from the fenced command.

---
id: MEM024
scope_tags: "[project], [milestone:M004]"
category: lessons
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 32
source_unit: "M004/P06"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM023, MEM025]
content_hash: ""
---

# MEM024: Lib Path Resolution in Task Plans

Task plans for P06 specified `_LIB_DIR` as `../../lib` from `scripts/verify/`, `scripts/lifecycle/`, `scripts/telemetry/`, and `scripts/dispatch/`. The correct path from all of these directories to `scripts/lib/` is `../lib` (one level up, not two). All scripts under `scripts/*/` are one directory level below `scripts/`, so `../lib` always resolves correctly.

---
id: MEM025
scope_tags: "[project], [milestone:M004]"
category: lessons
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 32
source_unit: "M004/P06"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM023, MEM024]
content_hash: ""
---

# MEM025: Verification Script Grep Patterns

Verification helper scripts that grep for library sourcing should use broad patterns (e.g. `errors\.sh`) not narrow literal patterns (e.g. `lib/errors\.sh`). Scripts may source libs via variable expansion (`$_LIB_DIR/errors.sh`) which does not match the literal path. The broader pattern still uniquely identifies the sourcing intent.

## Decisions

No decision entries in scope.

## Constraints

- **Verification Criteria**: See phase plan must-haves
- **Duration Budget**: 2h
- **Dispatch Budget**: 3
- **Budget Enforcement**: warn

## Scope

### Goal


### Demo


### Must-Haves
## Must-Haves

### Truths

<!-- Per AD-19, Check commands use single-script-file shape (no inline
     compound bash, no subshells, no $() with pipes, no process subst). -->

- `packaging/SKILL.md` specification document exists and describes the skill-file frontmatter schema (name, namespace, description, runtime_compatibility) plus body conventions.
  - Check: `bash scripts/verify/m008-p06-skill-spec.sh`

- `packaging/skills/` contains one skill file per orchestrator command (12 total), each with YAML frontmatter carrying `name:`, `namespace:`, `description:`, and `runtime_compatibility:` keys.
  - Check: `bash scripts/verify/m008-p06-skills-coverage.sh`

- `packaging/bundle/manifest.yml` exists and lists the bundled skills + hooks + config + version (defaulting to `0.3.0-dev` when no `VERSION` file is present at repo root).
  - Check: `bash scripts/verify/m008-p06-bundle-manifest.sh`

- `packaging/bundle/` directory structure contains `skills/`, `hooks/`, `config/`, and `README.md` matching the manifest.
  - Check: `bash scripts/verify/m008-p06-bundle-layout.sh`

- Claude Code installer `packaging/install/install-claude-code.sh` runs hermetically against a `HOME=$(mktemp -d)` fixture with `--dry-run`, emitting `would_write=` lines and exiting 0.

## Upstream Context


### P04 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P04"
parent: "M008"
milestone: "M008"
provides:
  - "resolve-root.sh — canonical orchestrator state root resolver with 5-rule precedence, detect-speckit.sh — spec-kit presence detection with integration mode toggle, config-system.sh — unified orchestrator config get/set/list with dot-notation nested keys, migrate-state.sh — hard one-shot .specify/orchestrator/ → .orchestrator/ migration tool with --dry-run, Surgical derive-phase.sh refactor (NOTE comment) + namespace-aliases.sh documentation generator, P04 Bash 3.2 compat scan + hermetic standalone e2e test proving SC-004"
requires:
  - "none (independent task), none (independent task), from:P04/T01 what:resolve-root.sh, from:P04/T01 what:resolve-root.sh, from:P04/T01 what:resolve-root.sh, from:P04/T01 what:resolve-root.sh,from:P04/T02 what:detect-speckit.sh,from:P04/T03 what:config-system.sh,from:P04/T04 what:migrate-state.sh,from:P04/T05 what:derive-phase.sh refactor+namespace-aliases.sh"
affects:
  - "P04/T03,P04/T04,P04/T05,P04/T06, P04/T06, P04/T06,P07/all, P04/T06,P07/all, P04/T06,P05/all, P05/all,P06/all,P07/all"
key_files:
  - "scripts/state/resolve-root.sh, scripts/state/detect-speckit.sh, scripts/state/config-system.sh, scripts/migrate/migrate-state.sh, scripts/state/derive-phase.sh,scripts/state/namespace-aliases.sh, scripts/verify/m008-p04-bash32-compat.sh,scripts/verify/m008-p04-standalone-e2e.sh"
key_decisions:
  - "read-only resolver — never creates directories; 5-rule precedence ensures backward compatibility bridge for .specify/orchestrator/, YAML-based config storage under resolved root; subcommand CLI interface (get/set/list), hard migration per project memory (no dual code paths) — move not copy, refuse populated destination, surgical documentation-only refactor of derive-phase.sh per Constitution XV (Surgical Precision); namespace-aliases.sh is a doc generator, not a runtime router"
patterns_established:
  - "pure resolver pattern — reads from env/config/filesystem, emits path to stdout, zero side effects, feature-toggle probe — inspects filesystem signals and env to produce integration_mode verdict, unified config subcommand CLI pattern with dot-notation key path resolution, hermetic migration test — always use mktemp -d fixtures, never run against live project trees, documentation-only surgical refactor preserving public interface and behavior, hermetic standalone e2e — runs full workflow in mktemp fixture with no spec-kit present, validates SC-004"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P04/tasks/T01-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P04/tasks/T02-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P04/tasks/T03-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P04/tasks/T04-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P04/tasks/T05-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P04/tasks/T06-SUMMARY.md"
duration: "50m"
verification_result: "pass"
completed_at: "2026-04-14T16:44:47Z"
observability_surfaces:
  - "resolve-root.sh stdout (resolved path) + --verbose (root= and source= lines); detect-speckit.sh stdout (speckit_installed + integration_mode); config-system.sh stdout (values); migrate-state.sh stdout (MIGRATED: or SKIP: messages)"
---

Phase P04 delivered state and namespace independence. Created scripts/state/resolve-root.sh — canonical root resolver with 5-rule precedence (ORCHESTRATOR_ROOT env → config.yml state_root → .orchestrator/ → .specify/orchestrator/ bridge → default .orchestrator/). Read-only; never creates directories. Created scripts/state/detect-speckit.sh that emits speckit_installed= and integration_mode= key=value pairs based on filesystem + PATH signals, with --force-disabled override. Created scripts/state/config-system.sh implementing unified get/set/list at <root>/config.yml with dot-notation nested keys (first writer of the resolved root). Created scripts/migrate/migrate-state.sh — hard one-shot mv-based migration from .specify/orchestrator/ to .orchestrator/, --dry-run supported, refuses to overwrite populated destination, cross-FS fallback. Applied surgical NOTE-only refactor to derive-phase.sh per Constitution XV (public interface preserved, regression test confirms existing callers work). Created scripts/state/namespace-aliases.sh as a doc-generator mapping speckit.orchestrator.* → orchestrator:* (not a runtime router). Hermetic standalone e2e in mktemp fixture validates SC-004: full pipeline completes in fresh project with no spec-kit, state lands under .orchestrator/ only. Patterns established: (1) pure resolver pattern (read-only, emits path, zero side effects), (2) subcommand CLI pattern with dot-notation keys, (3) hermetic migration tests (mktemp -d only, never touch live project), (4) surgical documentation-only refactor preserving public interface. Live .specify/orchestrator/ remains intact — migration is deferred to P07 init flow or manual invocation.


### P05 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P05"
parent: "M008"
milestone: "M008"
provides:
  - "detect-runtime.sh — runtime auto-detection via env vars + filesystem signals, claude-code.sh — Claude Code runtime adapter (probe/register/hook-config) with HOME guard, codex.sh — Codex CLI runtime adapter (probe/register/hook-config) with HOME guard, cursor.sh — Cursor runtime adapter (probe/register/hook-config) with --project-dir scope, native.sh — orchestrator native task format adapter (read/write/probe/validate), speckit.sh — spec-kit format adapter (read-only) mapping tasks.md/plan.md to orchestrator native, P05 Bash 3.2 compat scanner (comment-aware) + integration e2e across runtime+format+dispatch"
requires:
  - "none (independent task), from:P05/T01 what:detect-runtime.sh,from:P04/T05 what:namespace-aliases.sh, from:P05/T01 what:detect-runtime.sh,from:P04/T05 what:namespace-aliases.sh, from:P05/T01 what:detect-runtime.sh,from:P04/T05 what:namespace-aliases.sh, none (independent task), from:P05/T05 what:native.sh format interface, from:P05/T01 what:detect-runtime.sh,from:P05/T02 what:claude-code.sh,from:P05/T03 what:codex.sh,from:P05/T04 what:cursor.sh,from:P05/T05 what:native.sh,from:P05/T06 what:speckit.sh,from:P02/T05 what:dispatch-interface.sh"
affects:
  - "P05/T02,P05/T03,P05/T04,P05/T07, P05/T07,P06/all, P05/T07,P06/all, P05/T07,P06/all, P05/T06,P05/T07, P05/T07, P06/all,P07/all"
key_files:
  - "scripts/dispatch/detect-runtime.sh, scripts/dispatch/adapters/runtime/claude-code.sh, scripts/dispatch/adapters/runtime/codex.sh, scripts/dispatch/adapters/runtime/cursor.sh, scripts/dispatch/adapters/format/native.sh, scripts/dispatch/adapters/format/speckit.sh, scripts/verify/m008-p05-bash32-compat.sh,scripts/verify/m008-p05-integration-e2e.sh"
key_decisions:
  - "unknown fallback instead of error — detection never fails per FR-026 spirit, HOME guard mandatory — adapters refuse HOME= or HOME=/ to prevent root-directory writes, AGENTS.md as Codex project instruction file equivalent of CLAUDE.md, project-scoped not HOME-scoped — Cursor uses .cursor/rules/ in project dir, identity adapter for native format enables symmetric treatment of native vs foreign formats, one-directional read — reject --write explicitly to prevent polluting spec-kit artifacts, compat scanner excludes comment lines — prevents false positives on documented non-use of forbidden constructs"
patterns_established:
  - "signal-priority runtime detection — env vars dominate over filesystem; confidence reported alongside runtime, runtime adapter HOME guard pattern + filename-based discovery (mirrors P02 backend pattern), runtime adapter mirrors claude-code.sh pattern with AGENTS.md + ~/.codex/skills/ conventions, project-scoped runtime adapter — --project-dir flag drives all writes, matches HOME-guard safety model, format adapter interface — read/write/probe — with round-trip integrity guarantee, one-directional foreign-format adapter — exits 4 on write attempt; bridges spec-kit to orchestrator native without reverse mapping, comment-aware compat scan pattern — grep -vE '^[[:space:]]*#' to exclude comment lines before forbidden-construct checks"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P05/tasks/T01-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P05/tasks/T02-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P05/tasks/T03-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P05/tasks/T04-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P05/tasks/T05-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P05/tasks/T06-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P05/tasks/T07-SUMMARY.md"
duration: "63m"
verification_result: "pass"
completed_at: "2026-04-14T17:18:16Z"
observability_surfaces:
  - "detect-runtime.sh stdout (runtime= + confidence= + optional probed_env=/probed_path=); runtime adapter --probe stdout (available= + runtime= + reason=); runtime adapter --hook-config stdout (JSON/TOML fragment); runtime adapter --dry-run stdout (would_write= lines); format adapter --probe/--read/--write stdout/stderr"
---

Phase P05 delivered runtime and format adapters enabling cross-runtime operation. Created scripts/dispatch/detect-runtime.sh that auto-detects runtime from env vars (CLAUDECODE/CODEX_*/CURSOR_*) and filesystem markers, emits runtime + confidence key=value, defaults to unknown (never errors). Created 3 runtime adapters with uniform --probe/--register/--hook-config interface: claude-code.sh (writes to $HOME/.claude/commands/orchestrator-*.md, JSON hooks in settings.json), codex.sh (writes to $HOME/.codex/skills/, TOML hooks in config.toml, AGENTS.md conventions), cursor.sh (writes to --project-dir/.cursor/rules/ — project-scoped rather than HOME-scoped, rules-only integration). HOME guards on claude-code and codex refuse empty or root paths; cursor uses --project-dir flag with equivalent safety. Created 2 format adapters: native.sh (identity/round-trip adapter for orchestrator's native task-plan format with frontmatter validation) and speckit.sh (one-directional foreign-format adapter mapping spec-kit tasks.md+plan.md to native format, explicitly rejects --write with exit 4). Filename-based adapter discovery — no central registry. Integration e2e validates detect → probe → dry-run → hermetic register → native round-trip → speckit read → dispatch-interface with --backend local-agent. Bash 3.2 compat scanner updated to be comment-aware (grep -vE '^[[:space:]]*#' excludes comment lines, preventing false positives on documented non-use of forbidden constructs). Patterns established: (1) runtime adapter HOME guard + project-dir guard, (2) filename-based discovery mirroring P02 backend pattern, (3) one-directional foreign format adapter, (4) comment-aware compat scanning. All register tests are hermetic — zero writes to real HOME during P05 execution.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P06"
milestone: "M008"
name: "check-update.sh — offline-safe version checker"
depends_on: ["T02"]
---

## Prerequisites

- T02 produced `packaging/bundle/manifest.yml` with a `version:` field (default `0.3.0-dev`).
- No `VERSION` file is required at repo root; check-update falls back to the manifest.
- FR-019 requires self-update infrastructure that preserves local configuration. This task ships the read-only version checker half of that story; actual upgrade execution is infrastructure reserved for M010.

## Description

Create `scripts/lifecycle/check-update.sh`, a read-only command that compares the installed bundle version against a remote "latest" version and reports structured `key=value` lines. The remote URL is a placeholder for M010 — when the remote is unavailable (no network, 404, or missing curl/wget), the script degrades gracefully: it still emits the installed version and sets `update_available=unknown` rather than crashing.

## Steps

1. Create `scripts/lifecycle/check-update.sh` (Bash 3.2). Interface:

```
Usage:
  scripts/lifecycle/check-update.sh [--project-dir PATH] [--timeout SECONDS] [--remote-url URL]

Outputs (stdout, key=value lines):
  installed_version=<version-string>
  latest_version=<version-string or "unknown">
  update_available=true|false|unknown
  update_instructions=<single line>   # only when update_available=true

Exit codes:
  0  always, unless invoked with invalid arguments.
```

2. Resolve the installed version in this order:
   - `$REPO_ROOT/VERSION` file (if present and non-empty).
   - `packaging/bundle/manifest.yml` — grep `^version:` and strip quotes.
   - Fall back to `0.3.0-dev`.

3. Resolve the remote latest version:
   - Default `--remote-url` to a placeholder (e.g., `https://speckit.example.invalid/orchestrator/latest.txt`). `.invalid` TLD guarantees it won't accidentally resolve in production.
   - If `curl` is available: `curl -fsS --max-time "$TIMEOUT" "$REMOTE_URL"` with stderr suppressed; trim whitespace.
   - Else if `wget` is available: `wget -qO- --timeout="$TIMEOUT" "$REMOTE_URL"`.
   - Else: print `latest_version=unknown` and `update_available=unknown`, then exit 0. Do NOT call `curl`/`wget` in a subshell with `$()` containing pipes (AD-19 / MEM001).
   - If the remote call returns non-zero: `latest_version=unknown`, `update_available=unknown`.

4. Comparison:
   - If `latest_version` is `unknown`, emit `update_available=unknown` and exit 0 without `update_instructions`.
   - If `latest_version` equals `installed_version`, emit `update_available=false`.
   - Else emit `update_available=true` and `update_instructions=<text>` where `<text>` is a single-line hint like:
     `update_instructions=run: bash packaging/install/install-claude-code.sh --force (or the codex/cursor variant)`

5. Offline-safety tests. Create `scripts/verify/m008-p06-check-update.sh` that:
   - Runs `check-update.sh` with `--remote-url https://speckit.example.invalid/does-not-exist --timeout 2` and asserts exit 0 plus all three required keys present.
   - Asserts that `update_available=unknown` when the remote is unreachable.
   - Temporarily overrides `VERSION` file in a hermetic fixture to assert the installed version is sourced correctly.
   - Asserts that when the remote returns the same version as installed, `update_available=false` (tested via a `file://` URL pointing at a mktemp'd file — use curl's `file://` support; skip this subtest if curl is unavailable).

Sample verification script skeleton:

```bash
#!/usr/bin/env bash
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

out="$TMP/out.txt"
bash "$REPO_ROOT/scripts/lifecycle/check-update.sh" \
  --remote-url 'https://speckit.example.invalid/does-not-exist' \
  --timeout 2 > "$out" 2>&1

grep -q '^installed_version=' "$out" || {
  echo "FAIL: missing installed_version" >&2
  cat "$out" >&2
  exit 1
}

grep -q '^latest_version=' "$out" || {
  echo "FAIL: missing latest_version" >&2
  exit 1
}

grep -q '^update_available=unknown' "$out" || {
  echo "FAIL: expected update_available=unknown under offline remote" >&2
  cat "$out" >&2
  exit 1
}

echo "PASS: check-update.sh offline-safe"
```

## Must-Haves

Addresses:

- `scripts/lifecycle/check-update.sh` exists, emits the three required keys, and works offline.
- Key link: `scripts/lifecycle/check-update.sh → packaging/bundle/manifest.yml` (reads bundled version).

## Verification

```
bash scripts/verify/m008-p06-check-update.sh
```

Expected output:

```
PASS: check-update.sh offline-safe
```

## Inputs

### From Previous Tasks

- `packaging/bundle/manifest.yml` (from T02) — source of installed version when no `VERSION` file is present.
  - Key API: YAML with a top-level `version: "<semver-or-dev>"` field. Read via `grep '^version:' manifest.yml | sed`.

### From Disk (Pre-existing)

- `VERSION` (optional) at repo root — if present, takes precedence over manifest.
- `scripts/util/json-field.sh` (MEM008) — not used here (we don't parse JSON), listed for awareness.

## Constraints

- Offline-safe: script MUST exit 0 when the remote is unreachable.
- No python, no jq — pure bash/grep/sed/curl|wget.
- AD-19 / MEM001 shape: do not embed `$(cmd | pipe)`; capture remote output via `curl -fsS ... > "$tmpfile"` then `read` from the file. Similarly, version-file reads use `read -r line < "$file"` patterns, not `$(cat)`.
- Bash 3.2 compat.
- The placeholder `--remote-url` default MUST use a TLD like `.invalid` or `.example` that cannot resolve in real networks.
- Timeout default: 5 seconds. User-overridable via `--timeout`.

## Expected Output

- `scripts/lifecycle/check-update.sh` — 30+ line script (mode 0755).
- `scripts/verify/m008-p06-check-update.sh` — verification script (mode 0755).

## State Context

- **Current State**: executing
- **Milestone**: M008
- **Phase**: P06
- **Task**: T04
- **Tier**: C

UPDATED: MEM001 (hit_count)
UPDATED: MEM002 (hit_count)
UPDATED: MEM003 (hit_count)
UPDATED: MEM004 (hit_count)
UPDATED: MEM005 (hit_count)
UPDATED: MEM006 (hit_count)
UPDATED: MEM007 (hit_count)
UPDATED: MEM008 (hit_count)
UPDATED: MEM009 (hit_count)
UPDATED: MEM010 (hit_count)
UPDATED: MEM011 (hit_count)
UPDATED: MEM012 (hit_count)
UPDATED: MEM013 (hit_count)
UPDATED: MEM014 (hit_count)
UPDATED: MEM015 (hit_count)
UPDATED: MEM016 (hit_count)
UPDATED: MEM017 (hit_count)
UPDATED: MEM018 (hit_count)
UPDATED: MEM019 (hit_count)
UPDATED: MEM020 (hit_count)
UPDATED: MEM021 (hit_count)
UPDATED: MEM022 (hit_count)
UPDATED: MEM023 (hit_count)
UPDATED: MEM024 (hit_count)
UPDATED: MEM025 (hit_count)