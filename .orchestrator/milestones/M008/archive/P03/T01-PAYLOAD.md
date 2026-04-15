---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T01 (Phase P03, Milestone M008)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (25 entries) | 19-588 | ~4900 | filtered |
| Decisions | 590-592 | ~100 | filtered |
| Constraints | 594-599 | ~100 | required |
| Scope | 601-629 | ~600 | required |
| Upstream Context | 631-694 | ~2300 | required |
| Task Plan | 696-1106 | ~3900 | required |
| State Context | 1108-1114 | ~100 | required |
| **Total** | | **~12000** | |

## Knowledge

<!-- 25 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 14
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
hit_count: 14
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
hit_count: 14
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
hit_count: 14
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
hit_count: 11
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
hit_count: 11
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
hit_count: 11
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
hit_count: 14
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
hit_count: 11
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
hit_count: 11
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
hit_count: 11
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
hit_count: 14
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
hit_count: 14
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
hit_count: 14
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
hit_count: 11
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
hit_count: 11
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
hit_count: 11
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
hit_count: 14
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
hit_count: 11
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
hit_count: 11
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
hit_count: 14
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
hit_count: 14
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
hit_count: 11
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
hit_count: 11
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
hit_count: 11
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
task: "T01"
phase: "P03"
milestone: "M008"
name: "Create scripts/engine/intensity-gate.sh -- the stage-level matrix gate"
depends_on: []
---

## Prerequisites

- `templates/intensity-metadata.md` exists (from P01) with YAML frontmatter field `intensity:` that takes values `Quick`, `Standard`, or `Full`.
- `scripts/engine/intensity-recommend.sh` exists (from P01) and emits `intensity=<level>` as its first stdout line.
- Bash 3.2+ available (macOS default). No Bash 4 features.

## Description

Create `scripts/engine/intensity-gate.sh` — the central stage x intensity matrix consumed by every pipeline command. The gate encodes a single authoritative policy: given a pipeline stage name (discuss, research, plan-phase, dispatch, verify, knowledge, auto) and an intensity level (Quick, Standard, Full), which substeps should execute and which should skip.

Command documents do NOT encode the matrix themselves; they call the gate at entry and parse its output. This guarantees the matrix stays in exactly one place (MEM014 "Scripts -> Commands" interface contract).

Output shape — two key=value lines on stdout:

```
execute_substeps=<csv>
skip_substeps=<csv>
```

Substeps are stage-scoped identifiers; their meaning is defined in the command docs (T04). Values include keywords like `all`, `none`, `tier1`, `tier1+tier2`, and stage-specific tokens.

## Steps

### Step 1 — Create scripts/engine/intensity-gate.sh

Write verbatim to `scripts/engine/intensity-gate.sh`:

```bash
#!/usr/bin/env bash
# scripts/engine/intensity-gate.sh — Stage-level intensity gate.
#
# Given a pipeline stage and an intensity level, emit the set of
# substeps to execute and the set to skip. The matrix is hardcoded
# here to guarantee a single source of truth across all command docs
# (discuss, research, plan-phase, dispatch, verify, knowledge, auto).
#
# Usage:
#   intensity-gate.sh --stage <name> --intensity <Quick|Standard|Full>
#   intensity-gate.sh --stage <name> --intensity-metadata <path-to-md>
#
# Output (stdout, key=value):
#   execute_substeps=<csv>
#   skip_substeps=<csv>
#
# Exit: 0 success, 1 invalid arguments, 2 unknown stage/intensity.
# Bash 3.2 compatible (NFR-200, MEM001).

set -u

STAGE=""
INTENSITY=""
METADATA_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stage)
      STAGE="${2:-}"; shift 2 ;;
    --intensity)
      INTENSITY="${2:-}"; shift 2 ;;
    --intensity-metadata)
      METADATA_FILE="${2:-}"; shift 2 ;;
    *)
      shift ;;
  esac
done

if [[ -z "$STAGE" ]]; then
  echo "ERROR: --stage is required" >&2
  exit 1
fi

# Resolve intensity from metadata file if --intensity not given
if [[ -z "$INTENSITY" ]] && [[ -n "$METADATA_FILE" ]]; then
  if [[ ! -f "$METADATA_FILE" ]]; then
    echo "ERROR: metadata file not found: $METADATA_FILE" >&2
    exit 1
  fi
  INTENSITY="$(grep -E '^intensity:' "$METADATA_FILE" | head -n 1 | sed -E 's/^intensity:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')"
fi

if [[ -z "$INTENSITY" ]]; then
  echo "ERROR: --intensity or --intensity-metadata required" >&2
  exit 1
fi

case "$INTENSITY" in
  Quick|Standard|Full) ;;
  *)
    echo "ERROR: unknown intensity '$INTENSITY' (expected Quick|Standard|Full)" >&2
    exit 2 ;;
esac

# --- Hardcoded stage x intensity matrix ---
# Substep vocabulary (stage-scoped; meaning documented in command docs):
#   discuss:    all | none | optional | required
#   research:   all | none | on-demand | pre-planning
#   plan-phase: single-task | basic-decomp | full-decomp, boundary-map
#   dispatch:   sequential | standard-payload | full-context, knowledge-inject
#   verify:     tier1 | tier2 | tier3 | tier4
#   knowledge:  summary | decision | graph-entry | rebuild-index
#   auto:       dispatch | no-pause | standard-pause | strict-pause | human-review

execute=""
skip=""

case "$STAGE" in
  discuss)
    case "$INTENSITY" in
      Quick)    execute="none";     skip="all" ;;
      Standard) execute="optional"; skip="none" ;;
      Full)     execute="required"; skip="none" ;;
    esac
    ;;
  research)
    case "$INTENSITY" in
      Quick)    execute="none";         skip="all" ;;
      Standard) execute="on-demand";    skip="pre-planning" ;;
      Full)     execute="pre-planning"; skip="none" ;;
    esac
    ;;
  plan-phase)
    case "$INTENSITY" in
      Quick)    execute="single-task";                  skip="boundary-map,full-decomp" ;;
      Standard) execute="basic-decomp,boundary-map";    skip="full-decomp" ;;
      Full)     execute="full-decomp,boundary-map";     skip="none" ;;
    esac
    ;;
  dispatch)
    case "$INTENSITY" in
      Quick)    execute="sequential";                        skip="standard-payload,full-context,knowledge-inject" ;;
      Standard) execute="standard-payload";                  skip="full-context,knowledge-inject" ;;
      Full)     execute="full-context,knowledge-inject";     skip="none" ;;
    esac
    ;;
  verify)
    case "$INTENSITY" in
      Quick)    execute="tier1";                   skip="tier2,tier3,tier4" ;;
      Standard) execute="tier1,tier2";             skip="tier3,tier4" ;;
      Full)     execute="tier1,tier2,tier3,tier4"; skip="none" ;;
    esac
    ;;
  knowledge)
    case "$INTENSITY" in
      Quick)    execute="summary";                                skip="decision,graph-entry,rebuild-index" ;;
      Standard) execute="summary,decision";                       skip="graph-entry,rebuild-index" ;;
      Full)     execute="summary,decision,graph-entry,rebuild-index"; skip="none" ;;
    esac
    ;;
  auto)
    case "$INTENSITY" in
      Quick)    execute="dispatch,no-pause";                    skip="standard-pause,strict-pause,human-review" ;;
      Standard) execute="dispatch,standard-pause";              skip="strict-pause,human-review" ;;
      Full)     execute="dispatch,strict-pause,human-review";   skip="no-pause" ;;
    esac
    ;;
  *)
    echo "ERROR: unknown stage '$STAGE' (expected discuss|research|plan-phase|dispatch|verify|knowledge|auto)" >&2
    exit 2
    ;;
esac

echo "execute_substeps=$execute"
echo "skip_substeps=$skip"
```

### Step 2 — Make executable

```bash
chmod +x scripts/engine/intensity-gate.sh
```

### Step 3 — Create scripts/verify/m008-p03-gate-arguments.sh

Write verbatim:

```bash
#!/usr/bin/env bash
# Verifies intensity-gate.sh accepts --stage plus either --intensity or
# --intensity-metadata, and emits execute_substeps= / skip_substeps= lines.
set -u

f="scripts/engine/intensity-gate.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }

grep -q '\-\-stage' "$f" || { echo "FAIL: $f missing --stage"; exit 1; }
grep -q '\-\-intensity' "$f" || { echo "FAIL: $f missing --intensity"; exit 1; }
grep -q '\-\-intensity-metadata' "$f" || { echo "FAIL: $f missing --intensity-metadata"; exit 1; }
grep -q 'execute_substeps=' "$f" || { echo "FAIL: $f does not emit execute_substeps="; exit 1; }
grep -q 'skip_substeps=' "$f" || { echo "FAIL: $f does not emit skip_substeps="; exit 1; }

# Direct invocation emits both lines
out="$(bash "$f" --stage verify --intensity Standard 2>/dev/null)"
echo "$out" | grep -q '^execute_substeps=' || { echo "FAIL: direct invocation did not emit execute_substeps="; exit 1; }
echo "$out" | grep -q '^skip_substeps=' || { echo "FAIL: direct invocation did not emit skip_substeps="; exit 1; }

# Metadata-file invocation also works
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
printf '%s\n' '---' 'intensity: "Full"' '---' > "$tmp/meta.md"
out2="$(bash "$f" --stage verify --intensity-metadata "$tmp/meta.md" 2>/dev/null)"
echo "$out2" | grep -q '^execute_substeps=' || { echo "FAIL: metadata-file invocation did not emit execute_substeps="; exit 1; }

echo "PASS: intensity-gate.sh accepts documented arguments and emits key=value output"
```

### Step 4 — Create scripts/verify/m008-p03-gate-matrix.sh

Write verbatim:

```bash
#!/usr/bin/env bash
# Verifies the hardcoded stage x intensity matrix returns expected values
# for the critical corner cases.
set -u

f="scripts/engine/intensity-gate.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# discuss Quick -> skip all
out="$(bash "$f" --stage discuss --intensity Quick 2>/dev/null)"
echo "$out" | grep -q '^skip_substeps=all' || { echo "FAIL: discuss Quick should skip=all"; exit 1; }

# discuss Full -> execute required
out="$(bash "$f" --stage discuss --intensity Full 2>/dev/null)"
echo "$out" | grep -q '^execute_substeps=required' || { echo "FAIL: discuss Full should execute=required"; exit 1; }

# verify Quick -> tier1 only
out="$(bash "$f" --stage verify --intensity Quick 2>/dev/null)"
echo "$out" | grep -q '^execute_substeps=tier1$' || { echo "FAIL: verify Quick should execute=tier1"; exit 1; }

# verify Full -> all four tiers
out="$(bash "$f" --stage verify --intensity Full 2>/dev/null)"
echo "$out" | grep -q '^execute_substeps=tier1,tier2,tier3,tier4' || { echo "FAIL: verify Full should execute all four tiers"; exit 1; }

# knowledge Quick -> summary only
out="$(bash "$f" --stage knowledge --intensity Quick 2>/dev/null)"
echo "$out" | grep -q '^execute_substeps=summary$' || { echo "FAIL: knowledge Quick should execute=summary"; exit 1; }

# knowledge Full -> full pipeline
out="$(bash "$f" --stage knowledge --intensity Full 2>/dev/null)"
echo "$out" | grep -q 'rebuild-index' || { echo "FAIL: knowledge Full should include rebuild-index"; exit 1; }

# auto Full -> human-review present
out="$(bash "$f" --stage auto --intensity Full 2>/dev/null)"
echo "$out" | grep -q 'human-review' || { echo "FAIL: auto Full should include human-review"; exit 1; }

echo "PASS: intensity matrix yields expected values for all documented corner cases"
```

### Step 5 — Create scripts/verify/m008-p03-gate-stage-coverage.sh

Write verbatim:

```bash
#!/usr/bin/env bash
# Verifies all seven pipeline stages are handled at all three intensity
# levels with a non-empty, distinct output.
set -u

f="scripts/engine/intensity-gate.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

stages="discuss research plan-phase dispatch verify knowledge auto"
levels="Quick Standard Full"

for s in $stages; do
  for l in $levels; do
    out="$(bash "$f" --stage "$s" --intensity "$l" 2>/dev/null)"
    rc=$?
    if [[ $rc -ne 0 ]]; then
      echo "FAIL: stage=$s intensity=$l exited $rc"
      exit 1
    fi
    echo "$out" | grep -q '^execute_substeps=' || { echo "FAIL: stage=$s intensity=$l missing execute_substeps"; exit 1; }
    echo "$out" | grep -q '^skip_substeps=' || { echo "FAIL: stage=$s intensity=$l missing skip_substeps"; exit 1; }
  done
done

# Distinctness smoke: discuss Quick vs discuss Full must differ
q="$(bash "$f" --stage discuss --intensity Quick 2>/dev/null)"
full="$(bash "$f" --stage discuss --intensity Full 2>/dev/null)"
if [[ "$q" = "$full" ]]; then
  echo "FAIL: discuss Quick and discuss Full produce identical output (matrix not distinct)"
  exit 1
fi

echo "PASS: all 7 stages x 3 levels produce non-empty, distinct key=value output"
```

### Step 6 — Create scripts/verify/m008-p03-gate-rejects-unknown.sh

Write verbatim:

```bash
#!/usr/bin/env bash
# Verifies intensity-gate.sh rejects unknown stages and intensities
# with non-zero exit and a stderr message.
set -u

f="scripts/engine/intensity-gate.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# Unknown stage
err="$(bash "$f" --stage bogus-stage --intensity Quick 2>&1 >/dev/null)"
rc=$?
if [[ $rc -eq 0 ]]; then echo "FAIL: unknown stage did not exit non-zero"; exit 1; fi
echo "$err" | grep -q 'unknown stage' || { echo "FAIL: unknown stage did not emit diagnostic on stderr"; exit 1; }

# Unknown intensity
err2="$(bash "$f" --stage verify --intensity Medium 2>&1 >/dev/null)"
rc2=$?
if [[ $rc2 -eq 0 ]]; then echo "FAIL: unknown intensity did not exit non-zero"; exit 1; fi
echo "$err2" | grep -q 'unknown intensity' || { echo "FAIL: unknown intensity did not emit diagnostic on stderr"; exit 1; }

# Missing --stage
err3="$(bash "$f" --intensity Quick 2>&1 >/dev/null)"
rc3=$?
if [[ $rc3 -eq 0 ]]; then echo "FAIL: missing --stage did not exit non-zero"; exit 1; fi

echo "PASS: intensity-gate.sh rejects unknown/missing inputs with non-zero exit and stderr"
```

### Step 7 — Make all verify scripts executable

```bash
chmod +x scripts/verify/m008-p03-gate-arguments.sh
chmod +x scripts/verify/m008-p03-gate-matrix.sh
chmod +x scripts/verify/m008-p03-gate-stage-coverage.sh
chmod +x scripts/verify/m008-p03-gate-rejects-unknown.sh
```

## Must-Haves

From the phase plan, this task addresses:

- **Truths**: gate arguments, gate matrix, gate stage coverage, gate rejects-unknown.
- **Artifacts**: `scripts/engine/intensity-gate.sh`, `scripts/verify/m008-p03-gate-arguments.sh`, `scripts/verify/m008-p03-gate-matrix.sh`, `scripts/verify/m008-p03-gate-stage-coverage.sh`, `scripts/verify/m008-p03-gate-rejects-unknown.sh`.

## Verification

Run each verification script standalone:

```bash
bash scripts/verify/m008-p03-gate-arguments.sh
bash scripts/verify/m008-p03-gate-matrix.sh
bash scripts/verify/m008-p03-gate-stage-coverage.sh
bash scripts/verify/m008-p03-gate-rejects-unknown.sh
```

All four should print `PASS:` and exit 0.

### Files Touched By This Task

- `scripts/engine/intensity-gate.sh` (create)
- `scripts/verify/m008-p03-gate-arguments.sh` (create)
- `scripts/verify/m008-p03-gate-matrix.sh` (create)
- `scripts/verify/m008-p03-gate-stage-coverage.sh` (create)
- `scripts/verify/m008-p03-gate-rejects-unknown.sh` (create)

## Inputs

### From Previous Tasks

- None. T01 is independent within P03.

### From Disk (Pre-existing)

- `templates/intensity-metadata.md` (from P01)
  - Schema: YAML frontmatter with field `intensity: "Quick|Standard|Full"`. The gate reads this field when `--intensity-metadata` is supplied.
- `scripts/engine/intensity-recommend.sh` (from P01) — not called by the gate but establishes the precedent that intensity values are literal strings `Quick`, `Standard`, `Full`.

## Constraints

- Bash 3.2 compatible — no associative arrays, no `readarray`, no `|&`, no process substitution, no brace expansion with quoted regex classes (per AD-19 and MEM001).
- Zero runtime dependencies beyond `bash`, `grep`, `sed`, `cut`, `echo`, `head`.
- Stage vocabulary is exactly: `discuss research plan-phase dispatch verify knowledge auto`. No more, no fewer. Any other stage must exit 2 with an "unknown stage" diagnostic.
- Intensity vocabulary is exactly: `Quick Standard Full`. Any other value must exit 2 with an "unknown intensity" diagnostic.
- Output format MUST be exactly two lines — `execute_substeps=<csv>` and `skip_substeps=<csv>` — with CSV tokens documented in the matrix above. No extra lines on stdout. Errors go to stderr.
- MUST NOT read or write any file other than the metadata file named by `--intensity-metadata` (and that file is read-only).
- Matrix values must match the P03 phase plan comment block verbatim. When editing, grep the phase plan first — if the matrix changed there, update it here and vice versa.

## Expected Output

After completing this task:

1. `scripts/engine/intensity-gate.sh` exists (~140 lines), executable.
2. `bash scripts/engine/intensity-gate.sh --stage verify --intensity Full` prints:
   ```
   execute_substeps=tier1,tier2,tier3,tier4
   skip_substeps=none
   ```
3. `bash scripts/engine/intensity-gate.sh --stage discuss --intensity Quick` prints:
   ```
   execute_substeps=none
   skip_substeps=all
   ```
4. `bash scripts/engine/intensity-gate.sh --stage bogus --intensity Quick` exits 2 with "unknown stage" on stderr.
5. All four verify scripts print `PASS:` and exit 0.
6. `git status` shows 5 new files under `scripts/engine/` and `scripts/verify/`.

## State Context

- **Current State**: executing
- **Milestone**: M008
- **Phase**: P03
- **Task**: T01
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