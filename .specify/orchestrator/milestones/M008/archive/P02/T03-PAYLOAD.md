---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T03 (Phase P02, Milestone M008)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (25 entries) | 19-588 | ~4800 | filtered |
| Decisions | 590-592 | ~100 | filtered |
| Constraints | 594-599 | ~100 | required |
| Scope | 601-629 | ~500 | required |
| Upstream Context | 631-633 | ~100 | required |
| Task Plan | 635-1001 | ~3700 | required |
| State Context | 1003-1009 | ~100 | required |
| **Total** | | **~9400** | |

## Knowledge

<!-- 25 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 9
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
hit_count: 9
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
hit_count: 9
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
hit_count: 9
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
hit_count: 7
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
hit_count: 7
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
hit_count: 7
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
hit_count: 9
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
hit_count: 7
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
hit_count: 7
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
hit_count: 7
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
hit_count: 9
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
hit_count: 9
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
hit_count: 9
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
hit_count: 7
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
hit_count: 7
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
hit_count: 7
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
hit_count: 9
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
hit_count: 7
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
hit_count: 7
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
hit_count: 9
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
hit_count: 9
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
hit_count: 7
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
hit_count: 7
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
hit_count: 7
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
task: "T03"
phase: "P02"
milestone: "M008"
name: "Create local-agent.sh adapter (Claude Code Agent tool)"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `templates/dispatch-result.md` exists and defines the success result schema (YAML frontmatter with `status`, `backend`, `task_id`, `dispatched_at`, `completed_at`, `duration_s`; body sections Status, Summary, Artifacts, Notes).
- `scripts/dispatch/adapters/backend/` directory may not yet exist — this task creates it.
- MEM018 applies: the Claude Code Agent tool is an in-process capability of the orchestrating agent runtime; shell scripts cannot invoke it directly. The adapter therefore functions as a COORDINATION BOUNDARY, emitting a dispatch-result whose `notes` section instructs the orchestrating agent to perform the actual Agent invocation.

## Description

Create `scripts/dispatch/adapters/backend/local-agent.sh`, the backend adapter for Claude Code's native Agent tool. This adapter satisfies FR-010 (ship at least two local dispatch backends — this one being the Claude Code backend).

The adapter supports two modes:

1. **`--probe`** — emit `available=true|false` based on whether the environment is Claude Code.
   - Available if `SPECKIT_AGENT_TOOL=1` env var is set, OR
   - Available if a `.claude/` directory exists at the project root (heuristic: running inside Claude Code).
   - Otherwise `available=false`.

2. **Normal mode** — emit a dispatch-result.md conforming document on stdout. Because the Agent tool is in-process (MEM018), the adapter does not perform the actual execution. Instead it emits a result with `status=success` and a `Notes` section explaining that the orchestrating agent layer is responsible for the actual Agent tool invocation using the supplied `--payload`. This preserves the uniform interface contract while acknowledging the architectural reality.

Arguments (normal mode):

- `--task-plan <path>` — path to the task plan file the adapter is dispatching.
- `--payload <path>` — path to the assembled context payload (output of `scripts/dispatch/build-context.sh`).
- `--intensity-metadata <path>` — path to the intensity metadata file (output of P01).

The adapter reads task identification (task_id, phase_id, milestone_id) from the YAML frontmatter of `--task-plan` and embeds these in the result.

## Steps

### Step 1 — Create the adapter directory

```bash
mkdir -p scripts/dispatch/adapters/backend
```

### Step 2 — Create scripts/dispatch/adapters/backend/local-agent.sh

Write the following content verbatim to `scripts/dispatch/adapters/backend/local-agent.sh`:

```bash
#!/usr/bin/env bash
# scripts/dispatch/adapters/backend/local-agent.sh — Claude Code Agent tool adapter
#
# Dispatch backend adapter for Claude Code's in-process Agent tool. Per
# MEM018, the Agent tool cannot be invoked directly from a shell script;
# it is an in-process capability of the orchestrating agent runtime. This
# adapter therefore functions as a coordination boundary: its normal-mode
# output is a dispatch-result.md conforming document whose Notes section
# instructs the orchestrating agent layer to perform the actual Agent
# invocation.
#
# The uniform dispatch interface is preserved: callers receive a
# parseable dispatch-result, independent of where/how the Agent tool
# ultimately runs.
#
# Usage:
#   local-agent.sh --probe
#     Emits: available=true|false
#
#   local-agent.sh --task-plan <path> --payload <path> --intensity-metadata <path>
#     Emits a dispatch-result.md conforming document on stdout.
#
# Bash 3.2 compatible. Exits 0 on success, non-zero only if input is
# malformed (missing required flags).

set -u

MODE="normal"
TASK_PLAN=""
PAYLOAD=""
INTENSITY_METADATA=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --probe)
      MODE="probe"; shift ;;
    --task-plan)
      TASK_PLAN="${2:-}"; shift 2 ;;
    --payload)
      PAYLOAD="${2:-}"; shift 2 ;;
    --intensity-metadata)
      INTENSITY_METADATA="${2:-}"; shift 2 ;;
    *)
      shift ;;
  esac
done

# --- Probe mode ---

if [[ "$MODE" = "probe" ]]; then
  available="false"
  reason="not-claude-code"
  if [[ "${SPECKIT_AGENT_TOOL:-0}" = "1" ]]; then
    available="true"
    reason="SPECKIT_AGENT_TOOL=1"
  elif [[ -d .claude ]]; then
    available="true"
    reason="claude-directory-present"
  fi
  echo "available=${available}"
  echo "backend=local-agent"
  echo "reason=${reason}"
  exit 0
fi

# --- Normal mode ---

# Validate required inputs
if [[ -z "$TASK_PLAN" ]] || [[ ! -f "$TASK_PLAN" ]]; then
  echo "ERROR: --task-plan is required and must point to an existing file" >&2
  exit 2
fi
if [[ -z "$PAYLOAD" ]] || [[ ! -f "$PAYLOAD" ]]; then
  echo "ERROR: --payload is required and must point to an existing file" >&2
  exit 2
fi

# Extract task/phase/milestone IDs from task plan YAML frontmatter
task_id="$(grep -E '^task:' "$TASK_PLAN" | head -n 1 | sed -E 's/^task:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/')"
phase_id="$(grep -E '^phase:' "$TASK_PLAN" | head -n 1 | sed -E 's/^phase:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/')"
milestone_id="$(grep -E '^milestone:' "$TASK_PLAN" | head -n 1 | sed -E 's/^milestone:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/')"

# Default empty values to the string "unknown" to keep frontmatter valid
: "${task_id:=unknown}"
: "${phase_id:=unknown}"
: "${milestone_id:=unknown}"

dispatched_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
completed_at="$dispatched_at"

# Emit a dispatch-result.md conforming document. Per MEM018 the adapter
# does not actually execute the Agent tool -- the orchestrating agent
# layer does. This result encodes the coordination boundary: status is
# 'success' (the adapter successfully produced a dispatch descriptor) and
# the Notes section tells the agent layer what to invoke.

cat <<EOF
---
schema_version: "1.0"
type: dispatch-result
status: "success"
backend: "local-agent"
task_id: "${task_id}"
phase_id: "${phase_id}"
milestone_id: "${milestone_id}"
dispatched_at: "${dispatched_at}"
completed_at: "${completed_at}"
duration_s: "0"
---

# Dispatch Result

## Status

success -- dispatch descriptor prepared for orchestrating agent layer

## Summary

The local-agent adapter prepared an Agent-tool dispatch descriptor for
task ${task_id} in phase ${phase_id} of milestone ${milestone_id}. Per
MEM018, the actual Agent tool invocation happens at the orchestrating
agent layer (in-process); this adapter defines the coordination boundary
that preserves uniform dispatch-interface semantics.

## Artifacts

<!-- Artifacts are produced by the Agent tool invocation itself. The
     orchestrating agent records them in the task summary after the
     Agent tool returns. This adapter emits an empty artifacts list by
     design. -->

## Notes

Orchestrating-agent action required: invoke the Claude Code Agent tool
with the following inputs:
  - task-plan: ${TASK_PLAN}
  - payload: ${PAYLOAD}
  - intensity-metadata: ${INTENSITY_METADATA}

Backend: local-agent (Claude Code in-process Agent tool)
Reference: MEM018 (Runtime Adapter Interface)
EOF

exit 0
```

### Step 3 — Make the adapter executable

```bash
chmod +x scripts/dispatch/adapters/backend/local-agent.sh
```

### Step 4 — Create scripts/verify/m008-p02-local-agent-probe.sh

Write the following content verbatim:

```bash
#!/usr/bin/env bash
# Verifies local-agent.sh --probe works and emits available= key.
set -u

f="scripts/dispatch/adapters/backend/local-agent.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }

# Check --probe flag handling exists
grep -q '\-\-probe' "$f" || { echo "FAIL: $f does not handle --probe"; exit 1; }
grep -q 'backend=local-agent' "$f" || { echo "FAIL: $f missing backend=local-agent identifier"; exit 1; }

# Run probe with SPECKIT_AGENT_TOOL=1 — must emit available=true
probe_on="$(SPECKIT_AGENT_TOOL=1 bash "$f" --probe 2>/dev/null)"
echo "$probe_on" | grep -q '^available=true' || { echo "FAIL: probe with SPECKIT_AGENT_TOOL=1 did not emit available=true: $probe_on"; exit 1; }

# Run probe with explicit env disabled and no .claude directory in a scratch dir
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
probe_off="$(cd "$tmp" && SPECKIT_AGENT_TOOL=0 bash "${OLDPWD}/$f" --probe 2>/dev/null || true)"
echo "$probe_off" | grep -q '^available=' || { echo "FAIL: probe in empty dir did not emit available= key"; exit 1; }

echo "PASS: local-agent.sh --probe emits available= and backend=local-agent"
```

Make executable:

```bash
chmod +x scripts/verify/m008-p02-local-agent-probe.sh
```

### Step 5 — Create scripts/verify/m008-p02-local-agent-result.sh

Write the following content verbatim:

```bash
#!/usr/bin/env bash
# Verifies local-agent.sh normal mode emits a dispatch-result conforming document.
set -u

f="scripts/dispatch/adapters/backend/local-agent.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# Create a minimal task plan fixture
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/task-plan.md" <<'EOF'
---
schema_version: "1.0"
type: task-plan
task: "T99"
phase: "P99"
milestone: "M999"
name: "Fixture task for adapter verification"
depends_on: []
---

## Description

Fixture.
EOF

echo "Fixture payload" > "$tmp/payload.md"
echo "Fixture metadata" > "$tmp/metadata.md"

# Invoke the adapter
output="$(bash "$f" --task-plan "$tmp/task-plan.md" --payload "$tmp/payload.md" --intensity-metadata "$tmp/metadata.md" 2>/dev/null)"
rc=$?
if [[ $rc -ne 0 ]]; then
  echo "FAIL: adapter exited $rc (expected 0)"; exit 1
fi

# Check frontmatter fields
echo "$output" | grep -q '^schema_version: "1.0"' || { echo "FAIL: output missing schema_version"; exit 1; }
echo "$output" | grep -q '^type: "dispatch-result"' || { echo "FAIL: output missing type: dispatch-result"; exit 1; }
echo "$output" | grep -q '^status: "success"' || { echo "FAIL: output missing status: success"; exit 1; }
echo "$output" | grep -q '^backend: "local-agent"' || { echo "FAIL: output missing backend: local-agent"; exit 1; }
echo "$output" | grep -q '^task_id: "T99"' || { echo "FAIL: output did not propagate task_id from task plan"; exit 1; }
echo "$output" | grep -q '^phase_id: "P99"' || { echo "FAIL: output did not propagate phase_id from task plan"; exit 1; }
echo "$output" | grep -q '^milestone_id: "M999"' || { echo "FAIL: output did not propagate milestone_id from task plan"; exit 1; }
echo "$output" | grep -qE '^dispatched_at: "[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z"' || { echo "FAIL: output missing ISO 8601 dispatched_at"; exit 1; }

# Check body sections
echo "$output" | grep -q '^# Dispatch Result' || { echo "FAIL: output missing '# Dispatch Result' heading"; exit 1; }
echo "$output" | grep -q '^## Status' || { echo "FAIL: output missing '## Status' section"; exit 1; }
echo "$output" | grep -q '^## Summary' || { echo "FAIL: output missing '## Summary' section"; exit 1; }
echo "$output" | grep -q '^## Artifacts' || { echo "FAIL: output missing '## Artifacts' section"; exit 1; }
echo "$output" | grep -q '^## Notes' || { echo "FAIL: output missing '## Notes' section"; exit 1; }

echo "PASS: local-agent.sh emits a dispatch-result conforming document"
```

Make executable:

```bash
chmod +x scripts/verify/m008-p02-local-agent-result.sh
```

## Must-Haves

From the phase plan, this task addresses:

- **Truths**: "scripts/dispatch/adapters/backend/local-agent.sh supports --probe and emits available=true|false key=value output." and "scripts/dispatch/adapters/backend/local-agent.sh in normal mode emits a dispatch-result.md conforming document with backend=local-agent."
- **Artifacts**: `scripts/dispatch/adapters/backend/local-agent.sh`, `scripts/verify/m008-p02-local-agent-probe.sh`, `scripts/verify/m008-p02-local-agent-result.sh`.

## Verification

Run each verification script standalone:

```bash
bash scripts/verify/m008-p02-local-agent-probe.sh
bash scripts/verify/m008-p02-local-agent-result.sh
```

Both should print `PASS:` and exit 0.

### Files Touched By This Task

- `scripts/dispatch/adapters/backend/local-agent.sh` (create)
- `scripts/verify/m008-p02-local-agent-probe.sh` (create)
- `scripts/verify/m008-p02-local-agent-result.sh` (create)

## Inputs

### From Previous Tasks

- `templates/dispatch-result.md` (from T01)
  - Key schema fields (frontmatter): `schema_version`, `type` (must equal `dispatch-result`), `status` (success|failure|retry|timeout), `backend`, `task_id`, `phase_id`, `milestone_id`, `dispatched_at`, `completed_at`, `duration_s`.
  - Key body sections: `# Dispatch Result`, `## Status`, `## Summary`, `## Artifacts`, `## Notes`.
  - The adapter emits text matching this schema via a heredoc; no file I/O with the template itself.

### From Disk (Pre-existing)

- `scripts/dispatch/detect-capabilities.sh` — reference for key=value probe-style output convention.
- MEM018 documentation context (Runtime Adapter Interface) — describes why this adapter does not actually invoke the Agent tool.

## Constraints

- Bash 3.2 compatible — no associative arrays, no `readarray`, no `|&`.
- Probe mode must never fail (exits 0 even when unavailable — emits `available=false`).
- Normal mode must fail with non-zero exit only on malformed inputs (missing `--task-plan` or `--payload`); emits an error message to stderr and exits 2.
- Heredoc output must be verbatim — no command substitution inside the heredoc body except for documented placeholders (task_id, phase_id, milestone_id, timestamps, input paths).
- ISO 8601 UTC timestamps (`date -u +%Y-%m-%dT%H:%M:%SZ`) per MEM008.
- Must not require any network, daemon, or elevated permissions.

## Expected Output

After completing this task:

1. `scripts/dispatch/adapters/backend/local-agent.sh` exists (~110 lines), is executable.
2. `bash scripts/dispatch/adapters/backend/local-agent.sh --probe` emits key=value lines including `available=true|false` and `backend=local-agent`. Exit 0.
3. With `SPECKIT_AGENT_TOOL=1`, probe emits `available=true`. In a scratch directory without `.claude/`, probe emits `available=false`.
4. `bash scripts/dispatch/adapters/backend/local-agent.sh --task-plan <p> --payload <p> --intensity-metadata <p>` emits a dispatch-result.md conforming document on stdout with `backend: "local-agent"` and the task/phase/milestone IDs extracted from the task plan's frontmatter.
5. `bash scripts/verify/m008-p02-local-agent-probe.sh` prints `PASS`.
6. `bash scripts/verify/m008-p02-local-agent-result.sh` prints `PASS`.
7. `git status` shows 3 new files (plus one new directory `scripts/dispatch/adapters/backend/`).

## State Context

- **Current State**: executing
- **Milestone**: M008
- **Phase**: P02
- **Task**: T03
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