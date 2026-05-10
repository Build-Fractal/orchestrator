---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T04 (Phase P03, Milestone M008)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (25 entries) | 19-588 | ~4900 | filtered |
| Decisions | 590-592 | ~100 | filtered |
| Constraints | 594-599 | ~100 | required |
| Scope | 601-629 | ~600 | required |
| Upstream Context | 631-694 | ~2300 | required |
| Task Plan | 696-946 | ~3400 | required |
| State Context | 948-954 | ~100 | required |
| **Total** | | **~11500** | |

## Knowledge

<!-- 25 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 17
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
hit_count: 17
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
hit_count: 17
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
scope_tags: "[project], [milestone:[M005](../../../../milestones/M005/index.md)]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 17
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
hit_count: 14
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
hit_count: 14
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
hit_count: 14
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
hit_count: 17
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
scope_tags: "[project], [milestone:[M006](../../../../milestones/M006/index.md)]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 14
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
hit_count: 14
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
scope_tags: "[project], [milestone:[M002](../../../../milestones/M002/index.md)]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 14
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
hit_count: 17
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
hit_count: 17
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
hit_count: 17
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
hit_count: 14
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
hit_count: 14
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
hit_count: 14
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
hit_count: 17
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
hit_count: 14
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
hit_count: 14
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
hit_count: 17
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
hit_count: 17
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
scope_tags: "[project], [milestone:[M004](../../../../milestones/M004/index.md)]"
category: lessons
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 14
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
hit_count: 14
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
hit_count: 14
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

- scripts/engine/intensity-gate.sh accepts --stage <name> and either --intensity <Quick|Standard|Full> or --intensity-metadata <path>, and outputs execute_substeps= and skip_substeps= as key=value lines.
  - Check: `bash scripts/verify/m008-p03-gate-arguments.sh`
- scripts/engine/intensity-gate.sh hardcodes the documented stage x intensity matrix so that, for example, stage=discuss intensity=Quick yields skip_substeps containing "all" and stage=verify intensity=Full yields execute_substeps containing all four tiers.
  - Check: `bash scripts/verify/m008-p03-gate-matrix.sh`
- scripts/engine/intensity-gate.sh covers all seven pipeline stages (discuss, research, plan-phase, dispatch, verify, knowledge, auto) with distinct substep lists per intensity level.
  - Check: `bash scripts/verify/m008-p03-gate-stage-coverage.sh`
- scripts/engine/intensity-gate.sh rejects unknown stage names and unknown intensity levels with exit non-zero and an error message on stderr.
  - Check: `bash scripts/verify/m008-p03-gate-rejects-unknown.sh`
- scripts/engine/intensity-override.sh accepts --metadata-file <path> and --new-intensity <Quick|Standard|Full>, rewrites the metadata YAML frontmatter so intensity= becomes the new value, preserves the prior value as original_intensity=, and sets overridden_by=developer.
  - Check: `bash scripts/verify/m008-p03-override-rewrites-metadata.sh`
- scripts/engine/intensity-override.sh rejects override to the same current intensity with exit non-zero (no-op rejection) and rejects invalid intensity values.
  - Check: `bash scripts/verify/m008-p03-override-rejects-invalid.sh`
- scripts/engine/intensity-override.sh does not modify any file other than the metadata file (does not touch summaries, plans, verification reports, or knowledge files).
  - Check: `bash scripts/verify/m008-p03-override-scope-limited.sh`
- scripts/knowledge/intensity-knowledge.sh reads intensity from a metadata file, runs only scripts/knowledge/write-summary.sh at Quick, runs write-summary.sh + scripts/knowledge/append-decision.sh at Standard, and runs the full pipeline (summary + decision + append-knowledge + rebuild-index) at Full.
  - Check: `bash scripts/verify/m008-p03-knowledge-pipeline.sh`

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


### P02 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P02"
parent: "M008"
milestone: "M008"
provides:
  - "templates/dispatch-result.md + templates/dispatch-error.md — structured dispatch result and error schemas, backend-registry.sh — auto-discovery of dispatch backend adapters with availability probing, local-agent.sh — Claude Code Agent tool backend adapter (probe + coordination boundary modes per MEM018), local-codex.sh — Codex CLI SDK backend adapter (probe mode + uniform interface fallback when codex absent), dispatch-interface.sh — uniform backend-agnostic dispatch entry point with filename-based routing and structured error synthesis, P02 Bash 3.2 compat scan + end-to-end dispatch pipeline integration test"
requires:
  - "none (independent task), none (independent task), from:P02/T01 what:dispatch-result.md schema, from:P02/T01 what:dispatch-result.md schema,from:P02/T01 what:dispatch-error.md schema, from:P02/T01 what:dispatch-result.md,from:P02/T01 what:dispatch-error.md,from:P02/T02 what:backend-registry.sh,from:P02/T03 what:local-agent.sh,from:P02/T04 what:local-codex.sh, from:P02/T02 what:backend-registry.sh,from:P02/T03 what:local-agent.sh,from:P02/T04 what:local-codex.sh,from:P02/T05 what:dispatch-interface.sh"
affects:
  - "P02/T02,P02/T03,P02/T04,P02/T05, P02/T05, P02/T05, P02/T05, P02/T06,P03/all,P05/all, P03/all"
key_files:
  - "templates/dispatch-result.md,templates/dispatch-error.md, scripts/dispatch/backend-registry.sh, scripts/dispatch/adapters/backend/local-agent.sh, scripts/dispatch/adapters/backend/local-codex.sh, scripts/dispatch/dispatch-interface.sh, scripts/verify/m008-p02-bash32-compat.sh,scripts/verify/m008-p02-integration-e2e.sh"
key_decisions:
  - "filename-based adapter routing — zero backend-specific code in core per SC-003"
patterns_established:
  - "structured dispatch result/error schemas — YAML frontmatter + markdown body — consumed by all backend adapters, filename-based adapter auto-discovery — anything in adapters/backend/*.sh is a registered backend (no central registry file), coordination-boundary adapter — adapter emits dispatch instructions for orchestrator agent layer because Agent tool is in-process, uniform-interface fallback — adapter always emits dispatch-result even when backend unavailable, with status=failure rather than exiting with error, uniform dispatch interface — single entry point, adapter resolution purely by filename, structured result on stdout and structured error on stderr with distinct exit codes, integration test verifies uniform interface end-to-end: registry -> interface -> adapter -> result parse"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P02/tasks/T01-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P02/tasks/T02-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P02/tasks/T03-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P02/tasks/T04-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P02/tasks/T05-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P02/tasks/T06-SUMMARY.md"
duration: "713m"
verification_result: "pass"
completed_at: "2026-04-14T15:41:57Z"
observability_surfaces:
  - "dispatch-interface.sh stdout (dispatch-result on success); dispatch-interface.sh stderr (dispatch-error on failure); backend-registry.sh stdout (backends_available, default_backend); adapter --probe stdout (available=true|false)"
---

Phase P02 delivered the uniform Dispatch Interface and two local backend adapters, establishing the extensibility seam for future cloud backends (M010). Created templates/dispatch-result.md (structured success schema: status, backend, dispatched_at, completed_at, duration_s + artifacts list) and templates/dispatch-error.md (structured error schema: error_type, retry_eligible, escalation + context). Created scripts/dispatch/backend-registry.sh implementing filename-based auto-discovery — adapters dropped into scripts/dispatch/adapters/backend/*.sh are automatically registered, eliminating any central registry file and satisfying FR-011. Built two adapters: local-agent.sh (Claude Code Agent tool coordination boundary per MEM018 — adapter emits dispatch instructions since Agent tool is in-process) and local-codex.sh (Codex CLI SDK adapter — probes binary availability, emits dispatch-result with status=failure when absent, preserving uniform interface). The core dispatch-interface.sh routes purely by filename (/<backend>.sh) with zero backend-specific branching — verified by a dedicated agnostic check — satisfying SC-003 (new backend addable with zero core edits). Distinct exit codes 2-6 for input_invalid / registry_error / backend_unavailable / backend_crashed / backend_malformed. Also fixed a latent parser bug in scripts/verify/check-must-haves.sh where grep -q misinterpreted patterns starting with '--' as options (added '--' separator). Patterns established: (1) filename-based adapter auto-discovery, (2) coordination-boundary adapter for in-process tools, (3) uniform-interface fallback (always emit dispatch-result even on backend unavailability), (4) structured result on stdout + structured error on stderr with distinct exit codes.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P03"
milestone: "M008"
name: "Refactor commands/*.md -- add Intensity Behavior sections"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `scripts/engine/intensity-gate.sh` exists and emits `execute_substeps=<csv>` / `skip_substeps=<csv>` for each stage and intensity.
- Existing command docs (MEM012 structure preserved): `commands/discuss.md`, `commands/plan-phase.md`, `commands/dispatch.md`, `commands/verify.md`, `commands/auto.md`.

## Description

Append a new `## Intensity Behavior` section to each of the five pipeline command docs. The section:

1. States the stage name used when invoking the gate.
2. Documents the substeps per intensity level.
3. Instructs the agent interpreting the command to call `scripts/engine/intensity-gate.sh` at entry and branch on `execute_substeps` / `skip_substeps`.

**MINIMAL REFACTOR**. Do not rewrite any existing workflow text. Do not reorder sections. Do not modify YAML frontmatter. Do not delete anything. We are attaching a new section; the rest of the document stays intact. This preserves MEM012 (command file structure) and ensures that a fresh agent reading the doc still sees the original prescriptions and degrades gracefully if the gate is missing.

Placement: insert `## Intensity Behavior` as the second section of each doc, immediately after the title/header (first paragraph after the `# speckit.orchestrator.*` heading) and before the first existing `##` section. This makes intensity a front-of-mind concern rather than an afterthought.

## Steps

### Step 1 — Edit commands/discuss.md

Insert the following new section after the title paragraph (before the first `## Prerequisites` heading):

```markdown
## Intensity Behavior

This command is an intensity-aware stage. At entry, call:

```bash
bash scripts/engine/intensity-gate.sh --stage discuss --intensity-metadata <path-to-metadata>
```

Parse the `execute_substeps=` and `skip_substeps=` output and branch:

| Intensity | execute_substeps | Behavior |
|-----------|------------------|----------|
| Quick     | none             | Skip discussion entirely. Do not create a context draft. Report "Discussion skipped at Quick intensity" and exit. |
| Standard  | optional         | Discussion is optional. If `M###-EVALUATION.md` lists `discuss_required: true`, proceed. Otherwise, prompt the developer: "Discussion is optional at Standard intensity. Proceed or skip?" |
| Full      | required         | Discussion is a hard gate. Proceed with the full question generation and context-draft workflow described below. |

If the gate is missing or returns an unknown value, default to Full (fail-safe: when in doubt, discuss more not less).
```

Use the Edit tool with `old_string` set to the existing line immediately preceding `## Prerequisites` (the line after the intro paragraph) and `new_string` set to that same line followed by the section above. This guarantees surgical placement.

### Step 2 — Edit commands/plan-phase.md

Insert after the title/intro paragraph, before `## Phase Selection`:

```markdown
## Intensity Behavior

This command is an intensity-aware stage. At entry, call:

```bash
bash scripts/engine/intensity-gate.sh --stage plan-phase --intensity-metadata <path-to-metadata>
```

Parse the `execute_substeps=` and `skip_substeps=` output and branch:

| Intensity | execute_substeps        | Behavior |
|-----------|-------------------------|----------|
| Quick     | single-task             | Create ONE task plan. No boundary map. No full decomposition. Must-haves list is minimal (one truth, one artifact). |
| Standard  | basic-decomp,boundary-map | Create 2-4 task plans. Include a basic Boundary Map showing Produces/Consumes. Must-haves cover core behaviors. |
| Full      | full-decomp,boundary-map  | Full decomposition (1-7 tasks per FR-005). Complete Boundary Map. Full Must-Haves section with Truths, Artifacts, Key Links. Zero-context task plans per FR-011. |

The existing planning workflow below describes the Full behavior. At Quick/Standard, apply the reductions above to the same workflow; do not invent a different workflow.
```

### Step 3 — Edit commands/dispatch.md

Insert after the title/intro paragraph, before the first existing `##` section:

```markdown
## Intensity Behavior

This command is an intensity-aware stage. At entry, call:

```bash
bash scripts/engine/intensity-gate.sh --stage dispatch --intensity-metadata <path-to-metadata>
```

Parse the `execute_substeps=` and `skip_substeps=` output and branch:

| Intensity | execute_substeps              | Behavior |
|-----------|-------------------------------|----------|
| Quick     | sequential                    | Skip payload assembly (`build-context.sh`). Invoke `dispatch-interface.sh` with a minimal payload containing only the task plan. Run tasks sequentially — no parallel fan-out. |
| Standard  | standard-payload              | Full payload assembly (task plan + upstream summaries + scope-filtered knowledge). Standard dispatch semantics. |
| Full      | full-context,knowledge-inject | Full payload + graph-traversed knowledge (`traverse-graph.sh`) + explicit provenance chain (`check-graph-health`). Inject full context for high-risk tasks. |

The `--intensity-metadata` argument is already a first-class parameter of `dispatch-interface.sh` (P02). Forward it through unchanged.
```

### Step 4 — Edit commands/verify.md

Insert after the title/intro paragraph, before the first existing `##` section:

```markdown
## Intensity Behavior

This command is an intensity-aware stage. At entry, call:

```bash
bash scripts/engine/intensity-gate.sh --stage verify --intensity-metadata <path-to-metadata>
```

Parse the `execute_substeps=` and `skip_substeps=` output and branch:

| Intensity | execute_substeps          | Behavior |
|-----------|---------------------------|----------|
| Quick     | tier1                     | Run Tier 1 (static checks: file existence, content patterns) only. Skip Tier 2-4. |
| Standard  | tier1,tier2               | Run Tier 1 + Tier 2 (command execution: configured tests/lint). Skip Tier 3-4. |
| Full      | tier1,tier2,tier3,tier4   | Run all four tiers: Tier 1 (static) + Tier 2 (commands) + Tier 3 (behavioral spec-compliance review) + Tier 4 (human UAT). |

Higher tiers are strictly additive — a Tier 2 failure is reported even if Tier 1 passes. The verification report records which tiers ran and which were skipped by intensity policy.
```

### Step 5 — Edit commands/auto.md

Insert after the title/intro paragraph, before the first existing `##` section:

```markdown
## Intensity Behavior

This command is an intensity-aware stage. At entry of every loop iteration, call:

```bash
bash scripts/engine/intensity-gate.sh --stage auto --intensity-metadata <path-to-metadata>
```

Parse the `execute_substeps=` and `skip_substeps=` output and branch:

| Intensity | execute_substeps                      | Behavior |
|-----------|---------------------------------------|----------|
| Quick     | dispatch,no-pause                     | Dispatch the next task and advance immediately after verification. No pause gates between tasks. Auto mode runs end-to-end without interruption. |
| Standard  | dispatch,standard-pause               | Dispatch + standard pause gates (pause on verification failure; pause on budget threshold; pause on explicit `pause_requested` file). |
| Full      | dispatch,strict-pause,human-review    | Dispatch + strict pause gates + human review gate. After each task summary, write a `pending_review` flag; auto loop waits until a human clears it before proceeding to the next task. High-risk stance for platform-level work. |

Intensity can be overridden mid-run via `bash scripts/engine/intensity-override.sh --metadata-file <path> --new-intensity <level>`. The next auto iteration reads the new value and scales accordingly; completed iterations are preserved.
```

### Step 6 — Create scripts/verify/m008-p03-commands-intensity-section.sh

Write verbatim:

```bash
#!/usr/bin/env bash
# Verifies each pipeline command doc contains the Intensity Behavior
# section and references scripts/engine/intensity-gate.sh.
set -u

cmds="commands/discuss.md commands/plan-phase.md commands/dispatch.md commands/verify.md commands/auto.md"

for c in $cmds; do
  test -f "$c" || { echo "FAIL: $c missing"; exit 1; }
  grep -q '^## Intensity Behavior' "$c" || { echo "FAIL: $c missing '## Intensity Behavior' section"; exit 1; }
  grep -q 'scripts/engine/intensity-gate.sh' "$c" || { echo "FAIL: $c missing reference to intensity-gate.sh"; exit 1; }
  grep -q 'execute_substeps' "$c" || { echo "FAIL: $c does not document execute_substeps semantics"; exit 1; }
done

# Per-stage name check: each doc should reference --stage <its-own-name>
grep -q -- '--stage discuss'    commands/discuss.md    || { echo "FAIL: discuss.md missing --stage discuss"; exit 1; }
grep -q -- '--stage plan-phase' commands/plan-phase.md || { echo "FAIL: plan-phase.md missing --stage plan-phase"; exit 1; }
grep -q -- '--stage dispatch'   commands/dispatch.md   || { echo "FAIL: dispatch.md missing --stage dispatch"; exit 1; }
grep -q -- '--stage verify'     commands/verify.md     || { echo "FAIL: verify.md missing --stage verify"; exit 1; }
grep -q -- '--stage auto'       commands/auto.md       || { echo "FAIL: auto.md missing --stage auto"; exit 1; }

echo "PASS: all 5 pipeline commands contain Intensity Behavior sections referencing intensity-gate.sh"
```

### Step 7 — Make verify script executable

```bash
chmod +x scripts/verify/m008-p03-commands-intensity-section.sh
```

## Must-Haves

From the phase plan, this task addresses:

- **Truths**: commands-intensity-section truth ("each doc contains Intensity Behavior section that describes per-level substeps and references intensity-gate.sh").
- **Artifacts**: `commands/discuss.md`, `commands/plan-phase.md`, `commands/dispatch.md`, `commands/verify.md`, `commands/auto.md` (modified; verified by min-line count + contained strings), `scripts/verify/m008-p03-commands-intensity-section.sh`.

## Verification

```bash
bash scripts/verify/m008-p03-commands-intensity-section.sh
```

Prints `PASS:` and exits 0.

Additionally: `git diff commands/` should show additions only (no deletions) in each of the five files. If there are deletions, the refactor is not minimal and must be redone.

### Files Touched By This Task

- `commands/discuss.md` (modify — additive only)
- `commands/plan-phase.md` (modify — additive only)
- `commands/dispatch.md` (modify — additive only)
- `commands/verify.md` (modify — additive only)
- `commands/auto.md` (modify — additive only)
- `scripts/verify/m008-p03-commands-intensity-section.sh` (create)

## Inputs

### From Previous Tasks

- `scripts/engine/intensity-gate.sh` (from T01)
  - Key API: invoked as `bash scripts/engine/intensity-gate.sh --stage <name> --intensity-metadata <path>`. Emits `execute_substeps=<csv>` and `skip_substeps=<csv>` on stdout. Exit 0 success, non-zero on invalid inputs.
  - Stage names: `discuss`, `plan-phase`, `dispatch`, `verify`, `auto`, `research`, `knowledge`. Each of the five refactored docs invokes the gate with the stage name matching its own filename (except `auto`).
  - Substep vocabulary: see matrix tables inserted into each command doc.

### From Disk (Pre-existing)

- `commands/discuss.md` — existing 157-line command doc (MEM012 structure).
- `commands/plan-phase.md` — existing 237-line command doc.
- `commands/dispatch.md` — existing 143-line command doc.
- `commands/verify.md` — existing 149-line command doc.
- `commands/auto.md` — existing 531-line command doc.

## Constraints

- **Additive only.** The edit to each command doc inserts a new `## Intensity Behavior` section. It does NOT delete, reorder, or rewrite any existing content. `git diff` should show only additions in each of the five files. Any deletions are a bug.
- Placement: insert after the title/intro paragraph, before the first existing `##` section. This makes intensity a first-class concern at read time.
- YAML frontmatter: MUST NOT be modified. The `description:` field stays as-is.
- MEM012 structure preserved: the canonical section order (title -> prereq/state-check -> workflow -> output -> idempotency -> error handling -> referenced scripts) is extended, not replaced. The new section lives between the title and the prereq section.
- Every inserted section references `scripts/engine/intensity-gate.sh` and uses the stage name documented in T01's matrix (discuss, plan-phase, dispatch, verify, auto). The verify script enforces this.
- Tables use standard markdown pipe syntax. No HTML.
- The `discuss` section's Quick row must read `execute_substeps: none` to match T01's matrix; `Full` row must read `required`. Same pattern for other stages. Any mismatch between the doc table and T01's gate output is a bug.

## Expected Output

After completing this task:

1. All five command docs contain a `## Intensity Behavior` section placed after the title and before the first existing `##` section.
2. Each section contains a 3-row table (Quick/Standard/Full) describing substep behavior.
3. Each section references `scripts/engine/intensity-gate.sh` and the stage name matching its own command.
4. `bash scripts/verify/m008-p03-commands-intensity-section.sh` prints `PASS:` and exits 0.
5. `git diff commands/` shows additions only (no deletions) in each of the five files.
6. Line counts increase by roughly 20-30 lines per file (no other changes).

## State Context

- **Current State**: executing
- **Milestone**: M008
- **Phase**: P03
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