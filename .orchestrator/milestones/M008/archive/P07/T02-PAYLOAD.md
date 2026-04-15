---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T02 (Phase P07, Milestone M008)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (25 entries) | 19-588 | ~4900 | filtered |
| Decisions | 590-592 | ~100 | filtered |
| Constraints | 594-599 | ~100 | required |
| Scope | 601-629 | ~500 | required |
| Upstream Context | 631-725 | ~3900 | required |
| Task Plan | 727-1104 | ~3900 | required |
| State Context | 1106-1112 | ~100 | required |
| **Total** | | **~13500** | |

## Knowledge

<!-- 25 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 42
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
hit_count: 42
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
hit_count: 42
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
hit_count: 42
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
hit_count: 35
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
hit_count: 35
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
hit_count: 35
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
hit_count: 42
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
hit_count: 35
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
hit_count: 35
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
hit_count: 35
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
hit_count: 42
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
hit_count: 42
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
hit_count: 42
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
hit_count: 35
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
hit_count: 35
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
hit_count: 35
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
hit_count: 42
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
hit_count: 35
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
hit_count: 35
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
hit_count: 42
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
hit_count: 42
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
hit_count: 35
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
hit_count: 35
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
hit_count: 35
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

- `commands/init.md` exists, follows MEM012 command structure (frontmatter `description:`, numbered workflow sections, "Referenced Scripts/Templates" tail), references `scripts/lifecycle/init-project.sh` and `templates/project-instruction.md`, and documents the `--dry-run` and `--force` flags.
  - Check: `bash scripts/verify/m008-p07-init-command-doc.sh`

- `scripts/lifecycle/detect-project.sh` emits key=value lines to stdout covering at minimum: `language=`, `framework=`, `ci_system=`, `tools_detected=`, `project_type=`. On a fixture project with no markers, it emits `language=unknown framework=none ci_system=none tools_detected= project_type=generic` and exits 0.
  - Check: `bash scripts/verify/m008-p07-detect-project-contract.sh`

- `scripts/lifecycle/detect-project.sh` correctly identifies a Node project (fixture with `package.json`), a Python project (fixture with `pyproject.toml`), a Rust project (fixture with `Cargo.toml`), and detects GitHub Actions CI when `.github/workflows/` is present.
  - Check: `bash scripts/verify/m008-p07-detect-project-matrix.sh`

- `templates/project-instruction.md` exists with required sections ("Project Overview", "Detected Capabilities", "Detected Runtime", "Orchestrator Conventions", "Custom Instructions") and uses `{{placeholder}}` syntax throughout (MEM013). The "Custom Instructions" section is delimited by HTML comment markers (`<!-- BEGIN CUSTOM -->` / `<!-- END CUSTOM -->`) that the reinit handler preserves.
  - Check: `bash scripts/verify/m008-p07-project-instruction-template.sh`

- `scripts/lifecycle/init-project.sh` supports `--project-dir PATH`, `--dry-run`, `--force`, and `--runtime <claude-code|codex|cursor|auto>`. Default runtime is `auto` (delegates to `detect-runtime.sh`). Exit codes: 0 success, 1 generic failure, 2 unsafe env (empty `$HOME` for claude-code/codex), 3 runtime not available, 4 already initialized (delegates to `reinit-handler.sh`).

## Upstream Context


### P01 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M008"
milestone: "M008"
provides:
  - "Extended detect-capabilities.sh with graph_db, mcp_servers, ci_pipeline detection and --profile flag for intensity recommendation engine, intensity-analyze.sh — natural-language task description analyzer producing scope/risk/complexity classification with recommended intensity, intensity-recommend.sh — recommendation engine combining scope analysis + capability profile into final intensity with confidence and reasoning, templates/intensity-metadata.md schema + scripts/engine/context-pressure.sh token pressure evaluator, Bash 3.2 compatibility verification script + integration smoke test for P01 pipeline"
requires:
  - "none (independent task), none (independent task), from:P01/T01 what:detect-capabilities.sh --profile; from:P01/T02 what:intensity-analyze.sh output, none (independent task), from:P01/T01 what:detect-capabilities.sh; from:P01/T02 what:intensity-analyze.sh; from:P01/T03 what:intensity-recommend.sh; from:P01/T04 what:context-pressure.sh"
affects:
  - "P01/T03, P01/T03, P03/all, P03/all, P03/all"
key_files:
  - "scripts/dispatch/detect-capabilities.sh, scripts/engine/intensity-analyze.sh, scripts/engine/intensity-recommend.sh, templates/intensity-metadata.md,scripts/engine/context-pressure.sh, scripts/verify/m008-p01-bash32-compat.sh"
key_decisions:
  - "none"
patterns_established:
  - "capability profile output mode for intensity recommendation consumption, natural-language scope/risk/complexity pattern matching via keyword tables, pipeline composition — upstream script outputs consumed via --flag file-or-text inputs for testability, intensity-aware threshold adjustment (Quick tighter, Full looser) for pipeline stage gates, automated Bash 3.2 compatibility regression check via prohibited-construct grep"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P01/tasks/T01-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P01/tasks/T02-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P01/tasks/T03-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P01/tasks/T04-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P01/tasks/T05-SUMMARY.md"
duration: "36m"
verification_result: "pass"
completed_at: "2026-04-14T14:42:42Z"
observability_surfaces:
  - "intensity-analyze.sh stdout (key=value pairs); intensity-recommend.sh stdout (final intensity + confidence + reasoning); context-pressure.sh stdout (pressure level + recommended action)"
---

Phase P01 delivered the Adaptive Intensity Engine — the foundational components that analyze a task description and recommend Quick/Standard/Full intensity. Extended detect-capabilities.sh with graph_db, mcp_servers, ci_pipeline detection and a --profile flag producing a capability summary (cap_score 0-5) for downstream consumption. Created intensity-analyze.sh that classifies task descriptions along three axes (scope, risk_level, complexity) via keyword pattern tables, producing a preliminary recommended_intensity. Created intensity-recommend.sh that combines T01 capabilities + T02 analysis through a decision matrix into final intensity + confidence + reasoning, with risk escalation preventing downgrades. Created templates/intensity-metadata.md (10-field YAML schema flowing through pipeline stages as frontmatter) and context-pressure.sh (token pressure evaluator with intensity-aware threshold adjustment: Quick tightens by 10%, Full loosens by 5%). All 4 scripts verified Bash 3.2 compatible via automated prohibited-construct scan. End-to-end integration pipeline validated: trivial->Quick, moderate->Standard, platform+auth->Full. Patterns established: (1) capability profile output mode for cross-script consumption, (2) pipeline composition via --flag file-or-text inputs for testability, (3) intensity-aware threshold adjustment, (4) automated Bash 3.2 regression check via grep-based prohibited-construct scanning.


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


### P06 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P06"
parent: "M008"
milestone: "M008"
provides:
  - "packaging/SKILL.md spec + 12 generated skill files + generate-skills.sh generator with --check mode, packaging/bundle/ installable unit structure + build-bundle.sh assembler, 3 runtime installers (claude-code, codex, cursor) delegating to P05 adapters with shared flag contract, check-update.sh — offline-safe version checker with graceful degradation, P06 Bash 3.2 compat scan (comment-aware) + hermetic end-to-end packaging integration test"
requires:
  - "from:P04/T05 what:namespace-aliases.sh, from:P06/T01 what:packaging/skills/ + generate-skills.sh, from:P05/T02 what:claude-code.sh,from:P05/T03 what:codex.sh,from:P05/T04 what:cursor.sh,from:P06/T02 what:bundle, from:P06/T02 what:packaging/bundle/manifest.yml, from:P06/T01 what:generate-skills.sh,from:P06/T02 what:build-bundle.sh,from:P06/T03 what:3 installers,from:P06/T04 what:check-update.sh"
affects:
  - "P06/T02,P06/T03,P06/T05, P06/T03,P06/T05, P06/T05,P07/all, P06/T05,P07/all, P07/all"
key_files:
  - "packaging/SKILL.md,packaging/skills/,scripts/packaging/generate-skills.sh, packaging/bundle/,scripts/packaging/build-bundle.sh, packaging/install/install-claude-code.sh,packaging/install/install-codex.sh,packaging/install/install-cursor.sh, scripts/lifecycle/check-update.sh, scripts/verify/m008-p06-bash32-compat.sh,scripts/verify/m008-p06-integration-e2e.sh"
key_decisions:
  - "open-standard SKILL.md format — YAML frontmatter (name, namespace, description, runtime_compatibility) + markdown body, skills copied (not symlinked) to be tar-friendly for distribution, installers delegate to P05 runtime adapters — no duplicate install logic; shared flag contract (--dry-run, --force, --project-dir, --verbose), offline-safe — network failure emits installed_version + latest_version=unknown rather than exiting with error"
patterns_established:
  - "skill generation via transform from commands/*.md — single source of truth with generator + --check mode for drift detection, bundle assembly pattern — manifest + copied skills + hook fragments + default config in one installable unit, thin installer pattern — delegates runtime-specific work to adapter, only adds bundle config + hook wiring on top, version check with graceful offline degradation — never fails when remote unreachable, full packaging e2e — regenerate skills + build bundle + hermetic install + verify across all 3 runtimes"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P06/tasks/T01-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P06/tasks/T02-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P06/tasks/T03-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P06/tasks/T04-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P06/tasks/T05-SUMMARY.md"
duration: "81m"
verification_result: "pass"
completed_at: "2026-04-14T17:51:02Z"
observability_surfaces:
  - "generate-skills.sh --check stdout (drift detection per-file); build-bundle.sh --check stdout (version + skills count + hooks count); installer stdout (installed_runtime + skills_installed + config_staged + hooks_wired); check-update.sh stdout (installed_version + latest_version + update_available + update_instructions)"
---

Phase P06 delivered multi-runtime packaging. Created packaging/SKILL.md — the open-standard skill file format specification (YAML frontmatter: name, namespace, description, runtime_compatibility + markdown body with triggers + referenced scripts). Created scripts/packaging/generate-skills.sh generator that transforms commands/*.md into packaging/skills/orchestrator-*.md by adding skill frontmatter, with --check mode for drift detection between commands/ and skills/. 12 skills bootstrapped. Assembled packaging/bundle/ installable unit: manifest.yml (default version 0.3.0-dev with fallback from VERSION file), skills/ (copied not symlinked for tar portability), hooks/ (5 lifecycle events: before-tasks, after-tasks, before-implement, after-implement, before-commit), config/orchestrator.default.yml (default settings), README.md (install instructions). build-bundle.sh assembler with --check mode. Built 3 runtime installers (install-claude-code.sh, install-codex.sh, install-cursor.sh) with shared flag contract (--project-dir, --dry-run, --force, --verbose) and exit codes 0/1/2/3. Thin installer pattern — each delegates --probe/--register/--hook-config to the P05 runtime adapter, only adds bundle config staging + hook file wiring on top. Cursor installer refuses to write anywhere under $HOME (project-scoped). All installer integration tests use hermetic mktemp HOME + project fixtures — zero writes to real HOME during P06 execution. Created scripts/lifecycle/check-update.sh — offline-safe version checker reading installed version from manifest.yml, fetching from .invalid TLD placeholder remote (infrastructure for M010). Network failure emits latest_version=unknown and update_available=unknown, never errors. Bash 3.2 compat scanner is comment-aware (matches P05 pattern). Patterns established: (1) skill generation via single-source-of-truth transform with --check drift detection, (2) bundle assembly with copied (not symlinked) skills for distribution portability, (3) thin installer pattern delegating to P05 adapters, (4) offline-safe version check with graceful degradation.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P07"
milestone: "M008"
name: "project-instruction.md template + commands/init.md command doc"
depends_on: []
---

## Prerequisites

- None (independent leaf task). Produces two documents that T03 (`init-project.sh`) renders into runtime-specific locations.
- Must follow MEM013 template convention (YAML frontmatter with `schema_version` + `type`, `{{placeholder}}` syntax, no hardcoded IDs).
- Must follow MEM012 command file structure for `commands/init.md`.

## Description

Create two deliverables:

1. **`templates/project-instruction.md`** — the runtime-agnostic project instruction file template. T03 renders this into `CLAUDE.md` / `AGENTS.md` / `.cursor/rules/orchestrator.md` depending on the active runtime, with placeholders filled from `detect-project.sh` + `detect-capabilities.sh` + `detect-runtime.sh` output.
2. **`commands/init.md`** — the `orchestrator:init` command definition. Describes the workflow (detect → probe → generate → verify), documents flags, references the scripts and templates used.

## Steps

### 1. `templates/project-instruction.md`

Create with this content shape:

```markdown
---
schema_version: "1.0"
type: project-instruction
---

# {{project_name}} — Orchestrator Project Instructions

<!-- This file is auto-generated by `orchestrator:init` and refreshed by
     re-running init. Custom content should live inside the
     `<!-- BEGIN CUSTOM -->` / `<!-- END CUSTOM -->` markers below — reinit
     preserves that block verbatim. -->

## Project Overview

- Project type: `{{project_type}}`
- Primary language: `{{language}}`
- All languages detected: `{{languages_all}}`
- Primary framework: `{{framework}}`
- All frameworks detected: `{{frameworks_all}}`
- CI system: `{{ci_system}}`
- Tools detected: `{{tools_detected}}`
- Has tests: `{{has_tests}}`
- Git repo: `{{has_git}}`

## Detected Capabilities

- Execution mode: `{{cap_execution}}`
- Graph database available: `{{cap_graph}}`
- MCP servers available: `{{cap_mcp}}`
- CI pipeline integration: `{{cap_ci}}`
- Subagent dispatch: `{{cap_subagent}}`
- Capability score: `{{cap_score}}` / 5

## Detected Runtime

- Runtime: `{{runtime}}`
- Detection confidence: `{{runtime_confidence}}`
- Instruction file location: `{{instruction_file_path}}`
- State root: `{{state_root}}`

## Orchestrator Conventions

The orchestrator stores state under `{{state_root}}`. Key locations:

- `{{state_root}}/config.yml` — project configuration
- `{{state_root}}/milestones/` — milestone state (roadmaps, phases, tasks)
- `{{state_root}}/KNOWLEDGE.md` — consolidated patterns and lessons

Commands are invoked via the `orchestrator:*` namespace. Recommended starting points:

- `orchestrator:evaluate` — classify scope of a new feature
- `orchestrator:roadmap` — decompose a feature into phases
- `orchestrator:auto` — run autonomous execution on a planned milestone
- `orchestrator:status` — check current progress

See `{{state_root}}/../references/` for full documentation (if installed alongside this project).

## Intensity Defaults

Based on detected capabilities (score `{{cap_score}}`/5), the recommended
default intensity for this project is `{{recommended_intensity}}`. Override
per-task via `--intensity {{quick|standard|full}}` on the initial evaluate
or roadmap invocation.

<!-- BEGIN CUSTOM -->
<!--
  Add project-specific instructions here. This block is preserved
  verbatim across `orchestrator:init` reruns (unless --force is used).

  Examples:
  - Coding conventions the orchestrator should follow.
  - Files or directories that are off-limits for automated changes.
  - Project-specific hook or verification commands.
-->
<!-- END CUSTOM -->

---

*Generated by orchestrator:init on `{{initialized_at}}`. Run `orchestrator:init`
again to refresh auto-filled sections; use `orchestrator:init --force` to
regenerate everything including the custom block.*
```

Key requirements for the template:

- YAML frontmatter with `schema_version: "1.0"` and `type: project-instruction` (MEM013).
- Every dynamic value uses `{{placeholder}}` syntax.
- The HTML comment markers `<!-- BEGIN CUSTOM -->` and `<!-- END CUSTOM -->` are on their own lines with no leading whitespace. T04's reinit handler uses exact-line matching to extract this block.
- Section headings match the list in the phase plan: "Project Overview", "Detected Capabilities", "Detected Runtime", "Orchestrator Conventions", "Custom Instructions" (the custom block under an implicit/explicit heading).
- File is at least 40 lines.

### 2. `commands/init.md`

Create following MEM012 structure. Draft content:

```markdown
---
description: "Use when initializing a new project for the orchestrator. Detects project context, probes capabilities, generates config + runtime-specific instruction file, and registers the orchestrator skills into the active runtime."
---

# orchestrator:init

Bootstrap the orchestrator in a project. Produces:

1. A project configuration file at `<state_root>/config.yml`.
2. A runtime-specific project instruction file (`CLAUDE.md` on Claude Code, `AGENTS.md` on Codex, `.cursor/rules/orchestrator.md` on Cursor).
3. The 12 orchestrator skills registered into the active runtime via the P06 installer.

Re-running `orchestrator:init` in an already-configured project is safe —
it delegates to the reinit handler, which preserves the `<!-- BEGIN CUSTOM -->`
/ `<!-- END CUSTOM -->` block of the instruction file and merges new
capability detections into the config. Pass `--force` to fully regenerate.

## Prerequisites

### Extension Availability Check

Before invoking init, verify the orchestrator scripts are available in the current project:

```bash
test -f scripts/lifecycle/init-project.sh
```

If non-zero, the orchestrator bundle is not installed. See `references/installation.md`.

### Runtime Detection

`orchestrator:init` defaults to `--runtime auto`, which delegates to
`scripts/dispatch/detect-runtime.sh`. If detection returns `unknown`, the
user must pass `--runtime <claude-code|codex|cursor>` explicitly.

## Workflow

The init pipeline has four phases: **detect → probe → generate → verify**.

### 1. Detect

- Resolve the project directory (`--project-dir PATH`, defaults to `$PWD`).
- Run `scripts/dispatch/detect-runtime.sh` — captures `runtime=` + `confidence=`.
- Run `scripts/lifecycle/detect-project.sh --project-dir <project>` — captures
  `language=`, `framework=`, `ci_system=`, `tools_detected=`, `project_type=`.
- Resolve state root via `scripts/state/resolve-root.sh`.

### 2. Probe

- Run `scripts/dispatch/detect-capabilities.sh --profile` — captures
  `cap_execution=`, `cap_graph=`, `cap_mcp=`, `cap_ci=`, `cap_subagent=`,
  `cap_score=`. The capability profile drives intensity recommendations.
- Recommend a default intensity based on `cap_score` (0-1 → quick,
  2-3 → standard, 4-5 → full) and persist as `default_intensity:` in the
  generated config.

### 3. Generate

- Check for existing `<state_root>/config.yml`. If present and `--force`
  is NOT set, delegate to `scripts/lifecycle/reinit-handler.sh` and exit.
- Render `templates/project-instruction.md` with placeholders resolved from
  the detect/probe outputs. Write to the runtime-specific path:
  - `claude-code` → `<project-dir>/CLAUDE.md`
  - `codex` → `<project-dir>/AGENTS.md`
  - `cursor` → `<project-dir>/.cursor/rules/orchestrator.md`
- Write `<state_root>/config.yml` with `schema_version:`, `state_root:`,
  `runtime:`, `capabilities:` (nested from profile), `default_intensity:`,
  and `initialized_at:` (UTC ISO 8601).

### 4. Verify

- Invoke the matching installer from `packaging/install/install-<runtime>.sh`
  to register the 12 orchestrator skills into the runtime's skill discovery
  location. The installer handles hook wiring and config staging.
- Emit a final `SUMMARY:` line with `project_type=`, `runtime=`,
  `instruction_file=`, `config_file=`, `skills_installed=`, `next_step=`.

## Flags

| Flag | Description |
|---|---|
| `--project-dir PATH` | Project root (default: `$PWD`). |
| `--runtime NAME` | `claude-code`, `codex`, `cursor`, or `auto` (default). |
| `--dry-run` | No writes. Emits `would_write=<path>` lines and a final `SUMMARY:` line. |
| `--force` | Re-initialize even if configured. Overwrites the custom block. |
| `--verbose` | Extra debug output on stderr. |

## Exit Codes

- `0` — success.
- `1` — generic failure (malformed argument, detection error).
- `2` — unsafe environment (empty `$HOME` on claude-code/codex runtimes).
- `3` — runtime not available (`--runtime auto` returned `unknown` and no
  override was provided, OR the requested runtime's `--probe` returned
  `available=false`).
- `4` — already initialized (delegated to reinit handler; not an error).

## Output

- `<state_root>/config.yml` — project configuration.
- `<project-dir>/CLAUDE.md` | `<project-dir>/AGENTS.md` | `<project-dir>/.cursor/rules/orchestrator.md` — runtime-specific instruction file.
- Skills registered under the runtime's skill directory (via installer).
- Final `SUMMARY:` line on stdout describing next steps.

## Idempotency

Running `orchestrator:init` twice without `--force` results in identical disk state after the second run:

- Existing `config.yml` is updated only for auto-fillable fields (capabilities, runtime, detection timestamps).
- Existing instruction file's custom block is preserved verbatim.
- Skills are re-registered (idempotent — installer skips existing files unless `--force`).

## Error Handling

- If `--runtime auto` is used but `detect-runtime.sh` returns
  `runtime=unknown`, exit 3 with message listing supported runtimes.
- If the runtime's adapter `--probe` returns `available=false`, exit 3.
- If `scripts/lifecycle/reinit-handler.sh` is missing and an existing
  config is detected, exit 1 with a diagnostic.
- All failures emit a `FAIL:` line on stderr with a human-readable reason.

## Referenced Scripts

- `scripts/lifecycle/init-project.sh` — entry point.
- `scripts/lifecycle/detect-project.sh` — project context scanner.
- `scripts/lifecycle/reinit-handler.sh` — re-initialization handler.
- `scripts/dispatch/detect-runtime.sh` — runtime auto-detection.
- `scripts/dispatch/detect-capabilities.sh` — capability profile.
- `scripts/state/resolve-root.sh` — state root resolution.
- `packaging/install/install-claude-code.sh` | `install-codex.sh` | `install-cursor.sh` — per-runtime installer.

## Referenced Templates

- `templates/project-instruction.md` — project instruction file template.
```

### 3. Verification script

**`scripts/verify/m008-p07-project-instruction-template.sh`**:

```bash
#!/usr/bin/env bash
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TPL="$REPO_ROOT/templates/project-instruction.md"

test -f "$TPL" || { echo "FAIL: template not found: $TPL" >&2; exit 1; }

# Required sections
for section in "Project Overview" "Detected Capabilities" "Detected Runtime" "Orchestrator Conventions"; do
  grep -q "^## $section" "$TPL" || {
    echo "FAIL: missing section '## $section'" >&2
    exit 1
  }
done

# Required placeholders
for ph in "{{project_type}}" "{{language}}" "{{framework}}" "{{ci_system}}" "{{runtime}}" "{{cap_score}}" "{{state_root}}"; do
  grep -qF "$ph" "$TPL" || {
    echo "FAIL: missing placeholder '$ph'" >&2
    exit 1
  }
done

# Custom-block markers — exact-line match required
grep -q "^<!-- BEGIN CUSTOM -->$" "$TPL" || { echo "FAIL: missing BEGIN CUSTOM marker on its own line" >&2; exit 1; }
grep -q "^<!-- END CUSTOM -->$" "$TPL" || { echo "FAIL: missing END CUSTOM marker on its own line" >&2; exit 1; }

# YAML frontmatter
head -4 "$TPL" | grep -q 'schema_version:' || { echo "FAIL: missing schema_version in frontmatter" >&2; exit 1; }
head -4 "$TPL" | grep -q 'type: project-instruction' || { echo "FAIL: missing type in frontmatter" >&2; exit 1; }

echo "PASS: project-instruction.md template conforms"
```

**`scripts/verify/m008-p07-init-command-doc.sh`**:

```bash
#!/usr/bin/env bash
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CMD="$REPO_ROOT/commands/init.md"

test -f "$CMD" || { echo "FAIL: commands/init.md not found" >&2; exit 1; }

# MEM012 structure
head -3 "$CMD" | grep -q '^description:' || { echo "FAIL: missing description frontmatter" >&2; exit 1; }
grep -q '^# orchestrator:init' "$CMD" || { echo "FAIL: missing title" >&2; exit 1; }
grep -q '^## Workflow' "$CMD" || { echo "FAIL: missing Workflow section" >&2; exit 1; }
grep -q '^## Flags' "$CMD" || { echo "FAIL: missing Flags section" >&2; exit 1; }
grep -q '^## Exit Codes' "$CMD" || { echo "FAIL: missing Exit Codes section" >&2; exit 1; }
grep -q '^## Referenced Scripts' "$CMD" || { echo "FAIL: missing Referenced Scripts section" >&2; exit 1; }

# Required flag documentation
for flag in "\-\-dry-run" "\-\-force" "\-\-project-dir" "\-\-runtime"; do
  grep -qE "$flag" "$CMD" || { echo "FAIL: flag $flag not documented" >&2; exit 1; }
done

# Cross-references exist
grep -q 'scripts/lifecycle/init-project.sh' "$CMD" || { echo "FAIL: no reference to init-project.sh" >&2; exit 1; }
grep -q 'templates/project-instruction.md' "$CMD" || { echo "FAIL: no reference to project-instruction.md template" >&2; exit 1; }

echo "PASS: commands/init.md conforms to MEM012"
```

## Must-Haves

Addresses:

- `templates/project-instruction.md` exists with required sections, placeholders, and custom-block markers.
- `commands/init.md` exists following MEM012 structure, documents flags and exit codes, references all scripts used.
- Key links: `commands/init.md → scripts/lifecycle/init-project.sh`, `commands/init.md → templates/project-instruction.md`.

## Verification

```
bash scripts/verify/m008-p07-project-instruction-template.sh
bash scripts/verify/m008-p07-init-command-doc.sh
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M008/phases/P07
```

Each must emit `PASS:` and exit 0.

## Inputs

### From Previous Tasks

- None (independent leaf task, parallel with T01).

### From Disk (Pre-existing)

- `commands/evaluate.md` — reference for MEM012 command-file structure (numbered workflow sections, Referenced Scripts tail).
- `templates/task-plan.md` — reference for MEM013 template style (YAML frontmatter + `{{placeholder}}` body).
- `scripts/dispatch/detect-capabilities.sh` (P01) — defines the `cap_*` keys the template references.
- `scripts/dispatch/detect-runtime.sh` (P05) — defines `runtime=` + `confidence=` outputs referenced.
- `scripts/state/resolve-root.sh` (P04) — defines the `state_root` convention the template references.

## Constraints

- Template MUST use `{{placeholder}}` syntax, not shell `$VAR` or other conventions (MEM013).
- Custom-block markers MUST appear on their own lines (no leading whitespace, no trailing content). T04's reinit handler depends on exact-line matching.
- `commands/init.md` MUST follow MEM012 — integration tests across the project verify this.
- No hardcoded milestone/phase/task IDs in the template (context-free per FR-074).

## Expected Output

- `templates/project-instruction.md` (40+ lines, contains `{{project_type}}` and `<!-- BEGIN CUSTOM -->`)
- `commands/init.md` (60+ lines, contains `orchestrator:init`)
- `scripts/verify/m008-p07-project-instruction-template.sh` (mode 0755)
- `scripts/verify/m008-p07-init-command-doc.sh` (mode 0755)

## State Context

- **Current State**: executing
- **Milestone**: M008
- **Phase**: P07
- **Task**: T02
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