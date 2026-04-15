---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T02 (Phase P03, Milestone M008)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (25 entries) | 19-588 | ~4900 | filtered |
| Decisions | 590-592 | ~100 | filtered |
| Constraints | 594-599 | ~100 | required |
| Scope | 601-629 | ~600 | required |
| Upstream Context | 631-694 | ~2300 | required |
| Task Plan | 696-1100 | ~3500 | required |
| State Context | 1102-1108 | ~100 | required |
| **Total** | | **~11600** | |

## Knowledge

<!-- 25 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 15
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
hit_count: 15
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
hit_count: 15
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
hit_count: 15
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
hit_count: 12
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
hit_count: 12
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
hit_count: 12
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
hit_count: 15
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
hit_count: 12
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
hit_count: 12
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
hit_count: 12
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
hit_count: 15
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
hit_count: 15
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
hit_count: 15
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
hit_count: 12
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
hit_count: 12
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
hit_count: 12
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
hit_count: 15
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
hit_count: 12
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
hit_count: 12
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
hit_count: 15
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
hit_count: 15
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
hit_count: 12
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
hit_count: 12
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
hit_count: 12
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
task: "T02"
phase: "P03"
milestone: "M008"
name: "Create scripts/engine/intensity-override.sh -- mid-workflow override"
depends_on: []
---

## Prerequisites

- `templates/intensity-metadata.md` (from P01) — the schema this script rewrites. Known frontmatter fields: `intensity`, `scope`, `risk_level`, `complexity`, `confidence`, `reasoning`, `overridden_by`, `original_intensity`, `capabilities_used`, `evaluated_at`.
- A metadata instance file conforming to that schema (created by an earlier pipeline stage — typically via `intensity-recommend.sh` output funnelled into the template).
- Bash 3.2+.

## Description

Create `scripts/engine/intensity-override.sh` — a surgical mid-workflow intensity override. Given a metadata file and a new intensity level, rewrite the metadata's YAML frontmatter so:

1. `intensity:` becomes the new value.
2. `original_intensity:` is set to the previous value of `intensity:` (preserving history).
3. `overridden_by:` is set to `"developer"`.

The script MUST NOT touch any file other than the metadata file it was told to rewrite. Completed stage outputs (phase summaries, task summaries, verification reports, knowledge entries) are off-limits: FR-004's "preserving completed stages" guarantee depends on this script being scope-limited.

Reject no-op overrides (new == current) and reject invalid intensity values.

Implementation approach: rewrite the file via a tmp + mv swap (atomic replace). Use `sed`/`awk` on the YAML frontmatter lines only. Do not touch the body.

## Steps

### Step 1 — Create scripts/engine/intensity-override.sh

Write verbatim to `scripts/engine/intensity-override.sh`:

```bash
#!/usr/bin/env bash
# scripts/engine/intensity-override.sh -- Mid-workflow intensity override.
#
# Rewrites the `intensity:` field in an intensity-metadata.md file's
# YAML frontmatter, preserving the previous value as original_intensity
# and flagging overridden_by=developer. Does not touch any other file.
#
# FR-004: override remaining stages while preserving completed stages.
#         This script enforces the "other files untouched" half of that
#         contract. Command docs enforce the "future stages read the
#         new value" half via intensity-gate.sh.
#
# Usage:
#   intensity-override.sh --metadata-file <path> --new-intensity <Quick|Standard|Full>
#
# Exit: 0 success, 1 usage/IO error, 2 invalid intensity, 3 no-op rejection.
# Bash 3.2 compatible.

set -u

METADATA_FILE=""
NEW_INTENSITY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --metadata-file)
      METADATA_FILE="${2:-}"; shift 2 ;;
    --new-intensity)
      NEW_INTENSITY="${2:-}"; shift 2 ;;
    *)
      shift ;;
  esac
done

if [[ -z "$METADATA_FILE" ]]; then
  echo "ERROR: --metadata-file is required" >&2
  exit 1
fi
if [[ ! -f "$METADATA_FILE" ]]; then
  echo "ERROR: metadata file not found: $METADATA_FILE" >&2
  exit 1
fi
if [[ -z "$NEW_INTENSITY" ]]; then
  echo "ERROR: --new-intensity is required" >&2
  exit 1
fi

case "$NEW_INTENSITY" in
  Quick|Standard|Full) ;;
  *)
    echo "ERROR: invalid intensity '$NEW_INTENSITY' (expected Quick|Standard|Full)" >&2
    exit 2 ;;
esac

# Read current intensity from the file's YAML frontmatter.
current="$(grep -E '^intensity:' "$METADATA_FILE" | head -n 1 | sed -E 's/^intensity:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')"

if [[ -z "$current" ]]; then
  echo "ERROR: cannot find intensity: field in $METADATA_FILE" >&2
  exit 1
fi

if [[ "$current" = "$NEW_INTENSITY" ]]; then
  echo "ERROR: already at intensity=$NEW_INTENSITY (no-op rejected)" >&2
  exit 3
fi

# Rewrite via tmp + mv (atomic).
tmp_file="$(mktemp)"
# shellcheck disable=SC2064
trap "rm -f '$tmp_file'" EXIT

# AWK pass: modify three frontmatter fields in place. We consider only
# the first YAML frontmatter block (between the first pair of '---'
# lines). Outside that block, lines are copied verbatim.
awk -v new_intensity="$NEW_INTENSITY" -v old_intensity="$current" '
  BEGIN { in_fm = 0; fm_done = 0; seen_ov = 0; seen_orig = 0; }
  {
    if (fm_done == 0 && $0 == "---") {
      if (in_fm == 0) { in_fm = 1; print; next; }
      else {
        # Closing the frontmatter block — inject override/original fields
        # if the original file did not already contain them.
        if (seen_orig == 0) {
          print "original_intensity: \"" old_intensity "\"";
        }
        if (seen_ov == 0) {
          print "overridden_by: \"developer\"";
        }
        print;
        in_fm = 0;
        fm_done = 1;
        next;
      }
    }
    if (in_fm == 1) {
      if ($0 ~ /^intensity:/) {
        print "intensity: \"" new_intensity "\"";
        next;
      }
      if ($0 ~ /^original_intensity:/) {
        # Only set original_intensity if it is currently empty. If it
        # already holds a non-empty prior value we keep the original
        # chain (so that override-then-override traces to the first
        # recommendation, not to the intermediate).
        val = $0;
        sub(/^original_intensity:[[:space:]]*/, "", val);
        gsub(/"/, "", val);
        gsub(/[[:space:]]+$/, "", val);
        if (val == "") {
          print "original_intensity: \"" old_intensity "\"";
        } else {
          print $0;
        }
        seen_orig = 1;
        next;
      }
      if ($0 ~ /^overridden_by:/) {
        print "overridden_by: \"developer\"";
        seen_ov = 1;
        next;
      }
    }
    print;
  }
' "$METADATA_FILE" > "$tmp_file"

# Sanity check: tmp file should not be empty and should still have a frontmatter.
if [[ ! -s "$tmp_file" ]]; then
  echo "ERROR: rewrite produced empty file" >&2
  exit 1
fi
if ! grep -q '^intensity:' "$tmp_file"; then
  echo "ERROR: rewrite lost intensity: field" >&2
  exit 1
fi

mv "$tmp_file" "$METADATA_FILE"
trap - EXIT

echo "OVERRIDE: ${current} -> ${NEW_INTENSITY} in ${METADATA_FILE}"
exit 0
```

### Step 2 — Make executable

```bash
chmod +x scripts/engine/intensity-override.sh
```

### Step 3 — Create scripts/verify/m008-p03-override-rewrites-metadata.sh

Write verbatim:

```bash
#!/usr/bin/env bash
# Verifies intensity-override.sh rewrites the metadata frontmatter:
# intensity becomes the new value, original_intensity records the old
# value, overridden_by=developer. Body is untouched.
set -u

f="scripts/engine/intensity-override.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
meta="$tmp/intensity.md"
cat > "$meta" <<'EOF'
---
schema_version: "1.0"
type: intensity-metadata
intensity: "Quick"
scope: "trivial"
risk_level: "low"
complexity: "simple"
confidence: "high"
reasoning: "trivial task, low risk"
overridden_by: ""
original_intensity: ""
capabilities_used:
  - "none"
evaluated_at: "2026-04-14T15:00:00Z"
---

## Intensity Metadata

Body content stays untouched by override.
EOF

body_before="$(sed -n '/^---$/,/^---$/!p' "$meta")"

bash "$f" --metadata-file "$meta" --new-intensity Full >/dev/null 2>&1 \
  || { echo "FAIL: override Quick -> Full returned non-zero"; exit 1; }

grep -q '^intensity: "Full"' "$meta" || { echo "FAIL: intensity: not rewritten to Full"; exit 1; }
grep -q '^original_intensity: "Quick"' "$meta" || { echo "FAIL: original_intensity: not set to Quick"; exit 1; }
grep -q '^overridden_by: "developer"' "$meta" || { echo "FAIL: overridden_by: not set to developer"; exit 1; }

body_after="$(sed -n '/^---$/,/^---$/!p' "$meta")"
if [[ "$body_before" != "$body_after" ]]; then
  echo "FAIL: body content changed by override"
  exit 1
fi

echo "PASS: intensity-override.sh rewrites frontmatter correctly and leaves body unchanged"
```

### Step 4 — Create scripts/verify/m008-p03-override-rejects-invalid.sh

Write verbatim:

```bash
#!/usr/bin/env bash
# Verifies intensity-override.sh rejects invalid intensities and no-op
# (same-level) overrides with non-zero exit.
set -u

f="scripts/engine/intensity-override.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
meta="$tmp/intensity.md"
cat > "$meta" <<'EOF'
---
schema_version: "1.0"
type: intensity-metadata
intensity: "Standard"
---
EOF

# Invalid intensity
err="$(bash "$f" --metadata-file "$meta" --new-intensity Medium 2>&1 >/dev/null)"
rc=$?
if [[ $rc -eq 0 ]]; then echo "FAIL: invalid intensity did not exit non-zero"; exit 1; fi
echo "$err" | grep -q 'invalid intensity' || { echo "FAIL: invalid intensity diagnostic missing"; exit 1; }

# No-op (same level)
err2="$(bash "$f" --metadata-file "$meta" --new-intensity Standard 2>&1 >/dev/null)"
rc2=$?
if [[ $rc2 -eq 0 ]]; then echo "FAIL: same-level override did not exit non-zero"; exit 1; fi
echo "$err2" | grep -q 'no-op' || { echo "FAIL: same-level override diagnostic missing"; exit 1; }

# Missing file
err3="$(bash "$f" --metadata-file "$tmp/does-not-exist" --new-intensity Full 2>&1 >/dev/null)"
rc3=$?
if [[ $rc3 -eq 0 ]]; then echo "FAIL: missing file did not exit non-zero"; exit 1; fi

echo "PASS: intensity-override.sh rejects invalid intensities, no-ops, and missing files"
```

### Step 5 — Create scripts/verify/m008-p03-override-scope-limited.sh

Write verbatim:

```bash
#!/usr/bin/env bash
# Verifies intensity-override.sh does not modify any file other than
# the metadata file it was given. Uses a sandbox directory with several
# sentinel files and checks their mtimes after the override runs.
set -u

f="scripts/engine/intensity-override.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

meta="$tmp/intensity.md"
cat > "$meta" <<'EOF'
---
schema_version: "1.0"
type: intensity-metadata
intensity: "Quick"
---
EOF

# Sentinel files that represent completed stage outputs.
sentinel_a="$tmp/P01-SUMMARY.md"
sentinel_b="$tmp/T01-SUMMARY.md"
sentinel_c="$tmp/KNOWLEDGE.md"
echo "phase summary" > "$sentinel_a"
echo "task summary" > "$sentinel_b"
echo "knowledge" > "$sentinel_c"

hash_before_a="$(cksum "$sentinel_a" | cut -d' ' -f1-2)"
hash_before_b="$(cksum "$sentinel_b" | cut -d' ' -f1-2)"
hash_before_c="$(cksum "$sentinel_c" | cut -d' ' -f1-2)"

bash "$f" --metadata-file "$meta" --new-intensity Standard >/dev/null 2>&1 \
  || { echo "FAIL: override returned non-zero"; exit 1; }

hash_after_a="$(cksum "$sentinel_a" | cut -d' ' -f1-2)"
hash_after_b="$(cksum "$sentinel_b" | cut -d' ' -f1-2)"
hash_after_c="$(cksum "$sentinel_c" | cut -d' ' -f1-2)"

if [[ "$hash_before_a" != "$hash_after_a" ]]; then echo "FAIL: override modified P01-SUMMARY.md"; exit 1; fi
if [[ "$hash_before_b" != "$hash_after_b" ]]; then echo "FAIL: override modified T01-SUMMARY.md"; exit 1; fi
if [[ "$hash_before_c" != "$hash_after_c" ]]; then echo "FAIL: override modified KNOWLEDGE.md"; exit 1; fi

# Metadata file ITSELF must have been rewritten
grep -q '^intensity: "Standard"' "$meta" || { echo "FAIL: metadata file not rewritten"; exit 1; }

echo "PASS: intensity-override.sh modifies only the metadata file"
```

### Step 6 — Make verify scripts executable

```bash
chmod +x scripts/verify/m008-p03-override-rewrites-metadata.sh
chmod +x scripts/verify/m008-p03-override-rejects-invalid.sh
chmod +x scripts/verify/m008-p03-override-scope-limited.sh
```

## Must-Haves

From the phase plan, this task addresses:

- **Truths**: override rewrites metadata, override rejects invalid, override scope-limited.
- **Artifacts**: `scripts/engine/intensity-override.sh`, `scripts/verify/m008-p03-override-rewrites-metadata.sh`, `scripts/verify/m008-p03-override-rejects-invalid.sh`, `scripts/verify/m008-p03-override-scope-limited.sh`.

## Verification

```bash
bash scripts/verify/m008-p03-override-rewrites-metadata.sh
bash scripts/verify/m008-p03-override-rejects-invalid.sh
bash scripts/verify/m008-p03-override-scope-limited.sh
```

All three should print `PASS:` and exit 0.

### Files Touched By This Task

- `scripts/engine/intensity-override.sh` (create)
- `scripts/verify/m008-p03-override-rewrites-metadata.sh` (create)
- `scripts/verify/m008-p03-override-rejects-invalid.sh` (create)
- `scripts/verify/m008-p03-override-scope-limited.sh` (create)

## Inputs

### From Previous Tasks

- None. T02 is independent within P03.

### From Disk (Pre-existing)

- `templates/intensity-metadata.md` (from P01) — the schema this script mutates. Only frontmatter fields are touched; body is preserved verbatim.

## Constraints

- Bash 3.2 compatible — `awk` is POSIX-safe, no bash 4 features. No associative arrays, no `readarray`, no `|&`, no process substitution.
- MUST NOT modify any file other than the file passed via `--metadata-file`. Violating this breaks FR-004's completed-stage preservation guarantee. Verified by `m008-p03-override-scope-limited.sh`.
- Atomic rewrite: write to tmp file, then `mv` into place. Never truncate-in-place (a crash mid-write would corrupt the metadata).
- MUST preserve the YAML frontmatter body region boundary — the closing `---` line and all content below must survive.
- `original_intensity` chain: if `original_intensity` is already populated from a previous override, preserve it (so repeat overrides trace back to the first recommendation, not to the intermediate).
- ISO 8601 UTC timestamps only if the script writes timestamps; this script does NOT add any timestamp field itself.

## Expected Output

After completing this task:

1. `scripts/engine/intensity-override.sh` exists (~130 lines), executable.
2. Given a metadata file with `intensity: "Quick"`, running the script with `--new-intensity Full` produces a file with `intensity: "Full"`, `original_intensity: "Quick"`, `overridden_by: "developer"`, body unchanged.
3. Running with `--new-intensity Medium` exits 2 with "invalid intensity" on stderr.
4. Running with `--new-intensity` equal to the current value exits 3 with "no-op" on stderr.
5. No file other than the metadata file is modified.
6. All three verify scripts print `PASS:` and exit 0.
7. `git status` shows 4 new files.

## State Context

- **Current State**: executing
- **Milestone**: M008
- **Phase**: P03
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