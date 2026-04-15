---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T01 (Phase P02, Milestone M008)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (25 entries) | 19-588 | ~4800 | filtered |
| Decisions | 590-592 | ~100 | filtered |
| Constraints | 594-599 | ~100 | required |
| Scope | 601-629 | ~500 | required |
| Upstream Context | 631-633 | ~100 | required |
| Task Plan | 635-928 | ~2600 | required |
| State Context | 930-936 | ~100 | required |
| **Total** | | **~8300** | |

## Knowledge

<!-- 25 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 7
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
hit_count: 7
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
hit_count: 7
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
hit_count: 7
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
hit_count: 5
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
hit_count: 5
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
hit_count: 5
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
hit_count: 7
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
hit_count: 5
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
hit_count: 5
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
hit_count: 5
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
hit_count: 7
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
hit_count: 7
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
hit_count: 7
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
hit_count: 5
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
hit_count: 5
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
hit_count: 5
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
hit_count: 7
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
hit_count: 5
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
hit_count: 5
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
hit_count: 7
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
hit_count: 7
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
hit_count: 5
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
hit_count: 5
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
hit_count: 5
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

- templates/dispatch-result.md defines the success result schema with YAML frontmatter (schema_version, type, status, backend, dispatched_at, completed_at, duration_s) and body sections for summary and artifacts.
  - Check: `bash scripts/verify/m008-p02-result-template.sh`
- templates/dispatch-error.md defines the failure error schema with YAML frontmatter (schema_version, type, error_type, retry_eligible, escalation, occurred_at, backend) and body sections for error message, context, and suggested action.
  - Check: `bash scripts/verify/m008-p02-error-template.sh`
- scripts/dispatch/backend-registry.sh discovers adapters in scripts/dispatch/adapters/backend/*.sh and probes each to determine availability, outputting key=value pairs (backends_available, default_backend).
  - Check: `bash scripts/verify/m008-p02-registry-discovery.sh`
- scripts/dispatch/adapters/backend/local-agent.sh supports --probe and emits available=true|false key=value output.
  - Check: `bash scripts/verify/m008-p02-local-agent-probe.sh`
- scripts/dispatch/adapters/backend/local-agent.sh in normal mode emits a dispatch-result.md conforming document with backend=local-agent.
  - Check: `bash scripts/verify/m008-p02-local-agent-result.sh`
- scripts/dispatch/adapters/backend/local-codex.sh supports --probe and checks whether the `codex` binary is on PATH.
  - Check: `bash scripts/verify/m008-p02-local-codex-probe.sh`
- scripts/dispatch/adapters/backend/local-codex.sh in normal mode wires a subprocess invocation of the `codex` CLI and emits a dispatch-result.md conforming document with backend=local-codex.
  - Check: `bash scripts/verify/m008-p02-local-codex-result.sh`
- scripts/dispatch/dispatch-interface.sh accepts --task-plan, --payload, --intensity-metadata, and optional --backend arguments and resolves the backend through backend-registry.sh when --backend is not supplied.
  - Check: `bash scripts/verify/m008-p02-interface-arguments.sh`

## Upstream Context

No upstream summaries available.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M008"
name: "Create dispatch-result.md and dispatch-error.md templates"
depends_on: []
---

## Prerequisites

- `templates/` directory exists (contains many existing templates like `task-plan.md`, `phase-plan.md`, `intensity-metadata.md`).
- Per MEM013, all templates use YAML frontmatter with `schema_version` + `type` fields and `{{placeholder}}` syntax in the body.

## Description

Create two template files that define the canonical schemas emitted by all backend adapters:

1. **`templates/dispatch-result.md`** — success result envelope. Emitted by a backend adapter when a dispatched task completes (regardless of whether the task's internal logic succeeded or failed — that is tracked by the `status` field). Downstream consumers (the orchestrator core, verification scripts, the knowledge system) parse this schema to learn completion status and which artifacts were produced.

2. **`templates/dispatch-error.md`** — structured-error envelope. Emitted by `dispatch-interface.sh` (and optionally by adapters themselves) when a dispatch *attempt* fails (backend unavailable, adapter crashed, timeout, malformed input). Distinguished from `dispatch-result.md` with `status: failure` — error.md is for *dispatch infrastructure* failures, whereas result.md with `status: failure` is for *task execution* failures.

Both files are markdown templates (not executable). No scripts import them; adapters emit text matching the schema. Verification scripts check the template files' structural fields are present.

## Steps

### Step 1 — Create templates/dispatch-result.md

Write the following content verbatim to `templates/dispatch-result.md`:

```markdown
---
schema_version: "1.0"
type: dispatch-result
status: "{{status}}"
backend: "{{backend}}"
task_id: "{{task_id}}"
phase_id: "{{phase_id}}"
milestone_id: "{{milestone_id}}"
dispatched_at: "{{dispatched_at}}"
completed_at: "{{completed_at}}"
duration_s: "{{duration_s}}"
---

# Dispatch Result

## Status

{{status}} -- {{status_explanation}}

<!--
  status values:
    success  -- task executed and produced expected artifacts
    failure  -- task executed but verification failed or artifacts missing
    retry    -- task did not complete; a retry is warranted
    timeout  -- task exceeded the configured time budget
-->

## Summary

{{summary}}

<!--
  One to three sentences describing what the task did. Written by the
  backend-adapted agent after task completion. Consumed by the
  orchestrator core and (optionally) surfaced to the developer.
-->

## Artifacts

<!--
  List each file created or modified by the task, one per bullet,
  as a relative path from the project root. Empty list is allowed
  if the task intentionally produced no files.
-->

- {{artifact_path_1}}
- {{artifact_path_2}}

## Notes

<!-- Optional. Backend-specific diagnostic information, performance
     notes, or anything else not captured by the fields above. -->

{{notes}}
```

### Step 2 — Create templates/dispatch-error.md

Write the following content verbatim to `templates/dispatch-error.md`:

```markdown
---
schema_version: "1.0"
type: dispatch-error
error_type: "{{error_type}}"
retry_eligible: "{{retry_eligible}}"
escalation: "{{escalation}}"
backend: "{{backend}}"
task_id: "{{task_id}}"
occurred_at: "{{occurred_at}}"
---

# Dispatch Error

## Error Type

{{error_type}}

<!--
  error_type values:
    backend_unavailable   -- no adapter probed as available
    backend_crashed        -- adapter subprocess exited non-zero without emitting a result
    backend_malformed      -- adapter output did not conform to dispatch-result schema
    input_invalid          -- task plan or payload path missing/unreadable
    timeout                -- dispatch exceeded configured time budget
    registry_error         -- backend-registry.sh could not enumerate adapters
-->

## Retry Eligibility

retry_eligible: {{retry_eligible}}

<!--
  retry_eligible values:
    true   -- orchestrator may safely re-dispatch without intervention
    false  -- re-dispatching will fail in the same way; escalation required
-->

## Escalation

escalation: {{escalation}}

<!--
  escalation values:
    none       -- handled in-band; retry or skip
    developer  -- pause the loop and surface to the developer
    abort      -- terminate the current autonomous run immediately
-->

## Error Message

{{error_message}}

## Context

<!-- Captured context at time of failure: which adapter was attempted,
     which backend resolved, what inputs were provided, what stderr
     lines the adapter emitted. Used by the developer and by crash-
     recovery briefing generators. -->

{{error_context}}

## Suggested Action

<!-- Concrete next step. Examples:
       "Install the codex CLI and re-run."
       "Retry with --backend local-agent."
       "Review the task payload for malformed YAML frontmatter."
-->

{{suggested_action}}
```

### Step 3 — Create scripts/verify/m008-p02-result-template.sh

Write the following content verbatim:

```bash
#!/usr/bin/env bash
# Verifies templates/dispatch-result.md defines the success result schema.
set -eu

f="templates/dispatch-result.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# YAML frontmatter fields
for field in schema_version type status backend task_id dispatched_at completed_at duration_s; do
  grep -q "^${field}:" "$f" || { echo "FAIL: $f missing frontmatter field '${field}'"; exit 1; }
done

# Type value
grep -q '^type: "dispatch-result"' "$f" || { echo "FAIL: $f type must be dispatch-result"; exit 1; }

# Body sections
grep -q '^# Dispatch Result' "$f" || { echo "FAIL: $f missing '# Dispatch Result' heading"; exit 1; }
grep -q '^## Status' "$f" || { echo "FAIL: $f missing '## Status' section"; exit 1; }
grep -q '^## Summary' "$f" || { echo "FAIL: $f missing '## Summary' section"; exit 1; }
grep -q '^## Artifacts' "$f" || { echo "FAIL: $f missing '## Artifacts' section"; exit 1; }

# Comment block enumerating status values
grep -q 'success' "$f" || { echo "FAIL: $f missing 'success' status value documentation"; exit 1; }
grep -q 'failure' "$f" || { echo "FAIL: $f missing 'failure' status value documentation"; exit 1; }
grep -q 'retry' "$f" || { echo "FAIL: $f missing 'retry' status value documentation"; exit 1; }
grep -q 'timeout' "$f" || { echo "FAIL: $f missing 'timeout' status value documentation"; exit 1; }

echo "PASS: templates/dispatch-result.md defines the success result schema"
```

### Step 4 — Create scripts/verify/m008-p02-error-template.sh

Write the following content verbatim:

```bash
#!/usr/bin/env bash
# Verifies templates/dispatch-error.md defines the structured-error schema.
set -eu

f="templates/dispatch-error.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# YAML frontmatter fields
for field in schema_version type error_type retry_eligible escalation backend occurred_at; do
  grep -q "^${field}:" "$f" || { echo "FAIL: $f missing frontmatter field '${field}'"; exit 1; }
done

# Type value
grep -q '^type: "dispatch-error"' "$f" || { echo "FAIL: $f type must be dispatch-error"; exit 1; }

# Body sections
grep -q '^# Dispatch Error' "$f" || { echo "FAIL: $f missing '# Dispatch Error' heading"; exit 1; }
grep -q '^## Error Type' "$f" || { echo "FAIL: $f missing '## Error Type' section"; exit 1; }
grep -q '^## Retry Eligibility' "$f" || { echo "FAIL: $f missing '## Retry Eligibility' section"; exit 1; }
grep -q '^## Escalation' "$f" || { echo "FAIL: $f missing '## Escalation' section"; exit 1; }
grep -q '^## Error Message' "$f" || { echo "FAIL: $f missing '## Error Message' section"; exit 1; }
grep -q '^## Suggested Action' "$f" || { echo "FAIL: $f missing '## Suggested Action' section"; exit 1; }

# Enumerated error_type values
for et in backend_unavailable backend_crashed backend_malformed input_invalid timeout registry_error; do
  grep -q "$et" "$f" || { echo "FAIL: $f missing error_type value '$et' documentation"; exit 1; }
done

# Escalation values
for ev in "none" "developer" "abort"; do
  grep -q "$ev" "$f" || { echo "FAIL: $f missing escalation value '$ev' documentation"; exit 1; }
done

echo "PASS: templates/dispatch-error.md defines the structured-error schema"
```

## Must-Haves

From the phase plan, this task addresses:

- **Truths**: "templates/dispatch-result.md defines the success result schema..." and "templates/dispatch-error.md defines the failure error schema..."
- **Artifacts**: `templates/dispatch-result.md`, `templates/dispatch-error.md`, `scripts/verify/m008-p02-result-template.sh`, `scripts/verify/m008-p02-error-template.sh`.

## Verification

Run each verification script standalone:

```bash
bash scripts/verify/m008-p02-result-template.sh
bash scripts/verify/m008-p02-error-template.sh
```

Both should print `PASS:` lines and exit 0.

### Files Touched By This Task

- `templates/dispatch-result.md` (create)
- `templates/dispatch-error.md` (create)
- `scripts/verify/m008-p02-result-template.sh` (create)
- `scripts/verify/m008-p02-error-template.sh` (create)

## Inputs

### From Previous Tasks

None — T01 is the first task in P02.

### From Disk (Pre-existing)

- `templates/task-plan.md`, `templates/intensity-metadata.md`, `templates/phase-plan.md` — existing templates demonstrating the `schema_version`/`type`/placeholder convention (MEM013).

## Constraints

- Templates are markdown only — no executable code.
- Follow MEM013: YAML frontmatter with `schema_version` + `type` fields; body uses `{{placeholder}}` syntax; no hardcoded IDs.
- `type` field value must exactly match `dispatch-result` and `dispatch-error` respectively (verification scripts grep for the exact string).
- HTML comments (`<!-- ... -->`) document field enumerations inline; they must include every enumerated value since verification scripts grep for each.

## Expected Output

After completing this task:

1. `templates/dispatch-result.md` exists with YAML frontmatter (8 fields including `status`, `backend`, `task_id`, timestamps, `duration_s`), and body sections: Status, Summary, Artifacts, Notes.
2. `templates/dispatch-error.md` exists with YAML frontmatter (7 fields including `error_type`, `retry_eligible`, `escalation`, `backend`, `task_id`, `occurred_at`), and body sections: Error Type, Retry Eligibility, Escalation, Error Message, Context, Suggested Action.
3. `bash scripts/verify/m008-p02-result-template.sh` prints `PASS`.
4. `bash scripts/verify/m008-p02-error-template.sh` prints `PASS`.
5. `git status` shows 4 new files.

## State Context

- **Current State**: executing
- **Milestone**: M008
- **Phase**: P02
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