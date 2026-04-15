---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T05 (Phase P02, Milestone M008)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (25 entries) | 19-588 | ~4900 | filtered |
| Decisions | 590-592 | ~100 | filtered |
| Constraints | 594-599 | ~100 | required |
| Scope | 601-629 | ~500 | required |
| Upstream Context | 631-633 | ~100 | required |
| Task Plan | 635-1101 | ~4600 | required |
| State Context | 1103-1109 | ~100 | required |
| **Total** | | **~10400** | |

## Knowledge

<!-- 25 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 11
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
hit_count: 11
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
hit_count: 11
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
hit_count: 11
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
hit_count: 9
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
hit_count: 9
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
hit_count: 9
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
hit_count: 11
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
hit_count: 9
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
hit_count: 9
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
hit_count: 9
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
hit_count: 11
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
hit_count: 11
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
hit_count: 11
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
hit_count: 9
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
hit_count: 9
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
hit_count: 9
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
hit_count: 11
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
hit_count: 9
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
hit_count: 9
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
hit_count: 11
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
hit_count: 11
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
hit_count: 9
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
hit_count: 9
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
hit_count: 9
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
task: "T05"
phase: "P02"
milestone: "M008"
name: "Create dispatch-interface.sh -- the uniform entry point"
depends_on: ["T02", "T03", "T04"]
---

## Prerequisites

- T02 complete: `scripts/dispatch/backend-registry.sh` exists and outputs `backends_discovered=`, `backends_available=`, `default_backend=` as key=value lines, and supports `--list` and `--probe <backend>` sub-modes.
- T03 complete: `scripts/dispatch/adapters/backend/local-agent.sh` exists and supports `--probe` plus the normal-mode argument contract (`--task-plan`, `--payload`, `--intensity-metadata`).
- T04 complete: `scripts/dispatch/adapters/backend/local-codex.sh` exists with the same argument contract.
- `templates/dispatch-error.md` exists (from T01).

## Description

Create `scripts/dispatch/dispatch-interface.sh`, the uniform dispatch entry point that satisfies FR-009 ("define a uniform dispatch interface that accepts a task plan and context payload, and returns a structured result"), FR-011 (new backends registerable without core edits), and FR-012 (structured error information on failure).

The interface is intentionally a thin router. It has three responsibilities:

1. **Parse arguments** — `--task-plan`, `--payload`, `--intensity-metadata`, optional `--backend`.
2. **Resolve backend** — if `--backend` is supplied explicitly, use that name; otherwise query `backend-registry.sh` for `default_backend`.
3. **Invoke adapter as a subprocess** — pass through the task-plan, payload, and intensity-metadata arguments. Emit the adapter's stdout unchanged on success. On failure (adapter not found, adapter exited non-zero without emitting a conforming result, malformed adapter output), synthesize a `dispatch-error.md` conforming document on stderr and exit non-zero.

**SC-003 / FR-011 guarantee**: the interface contains NO backend-specific branching. There is no `if [[ backend == "local-agent" ]]` or similar code. Backend selection is purely by filename lookup in `scripts/dispatch/adapters/backend/`. Adding a new backend = dropping a new file in that directory. Verification script `m008-p02-interface-agnostic.sh` enforces this by grepping for forbidden patterns.

## Steps

### Step 1 — Create scripts/dispatch/dispatch-interface.sh

Write the following content verbatim to `scripts/dispatch/dispatch-interface.sh`:

```bash
#!/usr/bin/env bash
# scripts/dispatch/dispatch-interface.sh — Uniform dispatch interface
#
# Thin router that accepts a task plan + context payload + intensity
# metadata, resolves a backend adapter (via backend-registry.sh or an
# explicit --backend flag), and invokes the adapter as a subprocess.
#
# On success: emits the adapter's stdout (a dispatch-result.md
# conforming document) unchanged, exit 0.
#
# On failure: synthesizes a dispatch-error.md conforming document on
# stderr and exits non-zero. Failure modes:
#   - missing required inputs (--task-plan, --payload)
#   - explicit --backend that does not exist in adapters/backend/
#   - no backends available (registry reports default_backend empty)
#   - adapter subprocess exits non-zero without emitting a result
#
# Usage:
#   dispatch-interface.sh --task-plan <path> --payload <path> \
#                         --intensity-metadata <path> [--backend <name>]
#
# FR-009: uniform interface, structured result.
# FR-011: no backend-specific branching -- adapters are resolved purely
#         by filename lookup in scripts/dispatch/adapters/backend/.
# FR-012: structured error schema on failure.
# SC-003: new backends = new files; zero edits to this file required.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="${SCRIPT_DIR}/backend-registry.sh"
ADAPTERS_DIR="${SCRIPT_DIR}/adapters/backend"

TASK_PLAN=""
PAYLOAD=""
INTENSITY_METADATA=""
BACKEND=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-plan)
      TASK_PLAN="${2:-}"; shift 2 ;;
    --payload)
      PAYLOAD="${2:-}"; shift 2 ;;
    --intensity-metadata)
      INTENSITY_METADATA="${2:-}"; shift 2 ;;
    --backend)
      BACKEND="${2:-}"; shift 2 ;;
    *)
      shift ;;
  esac
done

# --- Helper: emit a dispatch-error document on stderr ---
emit_error() {
  local error_type="$1"
  local retry_eligible="$2"
  local escalation="$3"
  local backend="$4"
  local error_message="$5"
  local error_context="$6"
  local suggested_action="$7"
  local occurred_at
  occurred_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  cat >&2 <<EOF
---
schema_version: "1.0"
type: dispatch-error
error_type: "${error_type}"
retry_eligible: "${retry_eligible}"
escalation: "${escalation}"
backend: "${backend}"
occurred_at: "${occurred_at}"
---

# Dispatch Error

## Error Type

${error_type}

## Retry Eligibility

retry_eligible: ${retry_eligible}

## Escalation

escalation: ${escalation}

## Error Message

${error_message}

## Context

${error_context}

## Suggested Action

${suggested_action}
EOF
}

# --- Validate inputs ---

if [[ -z "$TASK_PLAN" ]] || [[ ! -f "$TASK_PLAN" ]]; then
  emit_error "input_invalid" "false" "developer" "" \
    "--task-plan is required and must point to an existing file" \
    "Received --task-plan='${TASK_PLAN}'" \
    "Provide a valid --task-plan path."
  exit 2
fi
if [[ -z "$PAYLOAD" ]] || [[ ! -f "$PAYLOAD" ]]; then
  emit_error "input_invalid" "false" "developer" "" \
    "--payload is required and must point to an existing file" \
    "Received --payload='${PAYLOAD}'" \
    "Provide a valid --payload path."
  exit 2
fi

# --- Resolve backend ---

if [[ -z "$BACKEND" ]]; then
  # Query registry for default
  if [[ ! -x "$REGISTRY" ]]; then
    emit_error "registry_error" "false" "developer" "" \
      "backend-registry.sh is missing or not executable" \
      "Expected at ${REGISTRY}" \
      "Restore the registry script or pass --backend <name> explicitly."
    exit 3
  fi
  registry_output="$(bash "$REGISTRY" 2>/dev/null)"
  BACKEND="$(echo "$registry_output" | grep -E '^default_backend=' | head -n 1 | cut -d= -f2)"
  if [[ -z "$BACKEND" ]]; then
    available="$(echo "$registry_output" | grep -E '^backends_available=' | head -n 1 | cut -d= -f2)"
    emit_error "backend_unavailable" "false" "developer" "" \
      "No dispatch backends reported available" \
      "Registry output: backends_available=${available}" \
      "Install a supported backend (e.g., Claude Code with SPECKIT_AGENT_TOOL=1, or Codex CLI) or register a new adapter in scripts/dispatch/adapters/backend/."
    exit 4
  fi
fi

# --- Resolve adapter path by filename (no backend-specific branching) ---

ADAPTER="${ADAPTERS_DIR}/${BACKEND}.sh"
if [[ ! -f "$ADAPTER" ]]; then
  emit_error "backend_unavailable" "false" "developer" "${BACKEND}" \
    "Requested backend '${BACKEND}' has no adapter script" \
    "Expected adapter at ${ADAPTER}" \
    "Drop an adapter file at the expected path, or pass --backend with a registered name (see 'bash ${REGISTRY} --list')."
  exit 4
fi

# --- Invoke adapter as a subprocess ---

adapter_rc=0
adapter_output="$(bash "$ADAPTER" \
  --task-plan "$TASK_PLAN" \
  --payload "$PAYLOAD" \
  --intensity-metadata "$INTENSITY_METADATA" 2>/dev/null)" || adapter_rc=$?

if [[ $adapter_rc -ne 0 ]]; then
  emit_error "backend_crashed" "true" "developer" "${BACKEND}" \
    "Adapter subprocess exited with code ${adapter_rc}" \
    "Adapter: ${ADAPTER}" \
    "Inspect adapter stderr or re-run with the adapter directly for diagnostics."
  exit 5
fi

# Minimal conformance check: adapter output must contain schema_version
# and type: "dispatch-result" frontmatter.
if ! echo "$adapter_output" | grep -q '^schema_version:'; then
  emit_error "backend_malformed" "false" "developer" "${BACKEND}" \
    "Adapter output missing schema_version frontmatter" \
    "Adapter: ${ADAPTER}" \
    "Adapter must emit a dispatch-result.md conforming document. See templates/dispatch-result.md."
  exit 6
fi
if ! echo "$adapter_output" | grep -q '^type: "dispatch-result"'; then
  emit_error "backend_malformed" "false" "developer" "${BACKEND}" \
    "Adapter output missing type: dispatch-result frontmatter" \
    "Adapter: ${ADAPTER}" \
    "Adapter must emit a dispatch-result.md conforming document. See templates/dispatch-result.md."
  exit 6
fi

# --- Emit adapter output unchanged ---
echo "$adapter_output"
exit 0
```

### Step 2 — Make the interface executable

```bash
chmod +x scripts/dispatch/dispatch-interface.sh
```

### Step 3 — Create scripts/verify/m008-p02-interface-arguments.sh

Write the following content verbatim:

```bash
#!/usr/bin/env bash
# Verifies dispatch-interface.sh accepts required arguments and rejects
# missing inputs with a structured error.
set -u

f="scripts/dispatch/dispatch-interface.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }

# Script declares the expected flags
grep -q '\-\-task-plan' "$f" || { echo "FAIL: $f missing --task-plan"; exit 1; }
grep -q '\-\-payload' "$f" || { echo "FAIL: $f missing --payload"; exit 1; }
grep -q '\-\-intensity-metadata' "$f" || { echo "FAIL: $f missing --intensity-metadata"; exit 1; }
grep -q '\-\-backend' "$f" || { echo "FAIL: $f missing --backend"; exit 1; }
grep -q 'backend-registry.sh' "$f" || { echo "FAIL: $f does not reference backend-registry.sh"; exit 1; }

# Missing --task-plan: must exit non-zero and emit a dispatch-error on stderr
err="$(bash "$f" --payload /dev/null 2>&1 >/dev/null || true)"
echo "$err" | grep -q '^type: "dispatch-error"' || { echo "FAIL: missing --task-plan did not emit dispatch-error"; exit 1; }
echo "$err" | grep -q 'input_invalid' || { echo "FAIL: missing --task-plan did not emit error_type=input_invalid"; exit 1; }

# Missing --payload: must exit non-zero and emit a dispatch-error
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
echo '---' > "$tmp/tp.md"
err2="$(bash "$f" --task-plan "$tmp/tp.md" 2>&1 >/dev/null || true)"
echo "$err2" | grep -q '^type: "dispatch-error"' || { echo "FAIL: missing --payload did not emit dispatch-error"; exit 1; }

echo "PASS: dispatch-interface.sh accepts required arguments and rejects missing inputs with structured errors"
```

Make executable:

```bash
chmod +x scripts/verify/m008-p02-interface-arguments.sh
```

### Step 4 — Create scripts/verify/m008-p02-interface-routing.sh

Write the following content verbatim:

```bash
#!/usr/bin/env bash
# Verifies dispatch-interface.sh routes to the correct adapter and
# emits either the adapter's result (success) or a dispatch-error
# (failure).
set -u

f="scripts/dispatch/dispatch-interface.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/task-plan.md" <<'EOF'
---
schema_version: "1.0"
type: task-plan
task: "T77"
phase: "P02"
milestone: "M008"
name: "Routing fixture"
depends_on: []
---

## Description

Fixture.
EOF

echo "payload" > "$tmp/payload.md"
echo "metadata" > "$tmp/metadata.md"

# Route explicitly to local-agent (always exists after T03)
output="$(SPECKIT_AGENT_TOOL=1 bash "$f" \
  --task-plan "$tmp/task-plan.md" \
  --payload "$tmp/payload.md" \
  --intensity-metadata "$tmp/metadata.md" \
  --backend local-agent 2>/dev/null)"
rc=$?
if [[ $rc -ne 0 ]]; then
  echo "FAIL: --backend local-agent exited $rc (expected 0)"; exit 1
fi
echo "$output" | grep -q '^type: "dispatch-result"' || { echo "FAIL: routing to local-agent did not emit dispatch-result"; exit 1; }
echo "$output" | grep -q '^backend: "local-agent"' || { echo "FAIL: routing to local-agent did not emit backend: local-agent"; exit 1; }
echo "$output" | grep -q '^task_id: "T77"' || { echo "FAIL: routing did not propagate task_id"; exit 1; }

# Request a non-existent backend -> dispatch-error on stderr
err="$(bash "$f" \
  --task-plan "$tmp/task-plan.md" \
  --payload "$tmp/payload.md" \
  --intensity-metadata "$tmp/metadata.md" \
  --backend does-not-exist 2>&1 >/dev/null || true)"
echo "$err" | grep -q '^type: "dispatch-error"' || { echo "FAIL: nonexistent backend did not emit dispatch-error"; exit 1; }
echo "$err" | grep -q 'backend_unavailable' || { echo "FAIL: nonexistent backend did not emit error_type=backend_unavailable"; exit 1; }

echo "PASS: dispatch-interface.sh routes correctly and emits structured errors on failure"
```

Make executable:

```bash
chmod +x scripts/verify/m008-p02-interface-routing.sh
```

### Step 5 — Create scripts/verify/m008-p02-interface-agnostic.sh

Write the following content verbatim:

```bash
#!/usr/bin/env bash
# Verifies dispatch-interface.sh contains NO backend-specific branching,
# satisfying FR-011 and SC-003 (new backends can be added by dropping
# an adapter file; zero edits to this interface file required).
set -u

f="scripts/dispatch/dispatch-interface.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# Forbidden patterns: any conditional that names a specific backend
# indicates the interface is no longer backend-agnostic. Allowed
# references: the placeholder "${BACKEND}" or "$BACKEND" variable.
#
# Check for literal backend names appearing in conditional expressions.
# Matches on '= "local-agent"' or '= "local-codex"' or similar patterns
# that would tie the router to a specific backend.

if grep -E '\[\[[[:space:]]+["$]?BACKEND["$]?[[:space:]]*[=!]=?[[:space:]]*["]?(local-agent|local-codex)["]?' "$f" >/dev/null; then
  echo "FAIL: $f contains backend-specific branching (compares \$BACKEND to a literal adapter name)"
  exit 1
fi

# Also check for `case "$BACKEND" in local-agent)` style branches
if grep -E 'case[[:space:]]+["$]?BACKEND["$]?' "$f" >/dev/null; then
  echo "FAIL: $f switches on \$BACKEND (backend-specific branching)"
  exit 1
fi

# The file must use filename-based resolution (ADAPTERS_DIR + BACKEND + .sh)
grep -q 'ADAPTERS_DIR' "$f" || { echo "FAIL: $f does not use ADAPTERS_DIR for filename-based resolution"; exit 1; }
grep -qE '\$\{?ADAPTERS_DIR\}?/\$\{?BACKEND\}?\.sh' "$f" || { echo "FAIL: $f does not resolve adapter via \${ADAPTERS_DIR}/\${BACKEND}.sh"; exit 1; }

echo "PASS: dispatch-interface.sh is backend-agnostic (filename-based resolution only)"
```

Make executable:

```bash
chmod +x scripts/verify/m008-p02-interface-agnostic.sh
```

## Must-Haves

From the phase plan, this task addresses:

- **Truths**: "scripts/dispatch/dispatch-interface.sh accepts --task-plan, --payload, --intensity-metadata, and optional --backend arguments...", "scripts/dispatch/dispatch-interface.sh invokes the selected adapter as a subprocess...", and "scripts/dispatch/dispatch-interface.sh contains no backend-specific branching...".
- **Artifacts**: `scripts/dispatch/dispatch-interface.sh`, `scripts/verify/m008-p02-interface-arguments.sh`, `scripts/verify/m008-p02-interface-routing.sh`, `scripts/verify/m008-p02-interface-agnostic.sh`.

## Verification

Run each verification script standalone:

```bash
bash scripts/verify/m008-p02-interface-arguments.sh
bash scripts/verify/m008-p02-interface-routing.sh
bash scripts/verify/m008-p02-interface-agnostic.sh
```

All three should print `PASS:` and exit 0.

### Files Touched By This Task

- `scripts/dispatch/dispatch-interface.sh` (create)
- `scripts/verify/m008-p02-interface-arguments.sh` (create)
- `scripts/verify/m008-p02-interface-routing.sh` (create)
- `scripts/verify/m008-p02-interface-agnostic.sh` (create)

## Inputs

### From Previous Tasks

- `scripts/dispatch/backend-registry.sh` (from T02)
  - Key API: invoked as `bash scripts/dispatch/backend-registry.sh` (no args). Outputs three key=value lines including `default_backend=<name>` (empty if none available). Also supports `--list` and `--probe <name>`.
  - Behavioral contract: always exits 0; failure modes are reflected in output fields.

- `scripts/dispatch/adapters/backend/local-agent.sh` (from T03)
  - Key API: invoked as `bash ... --task-plan <p> --payload <p> --intensity-metadata <p>`. Emits a dispatch-result.md conforming document on stdout. Exit 0 on success, 2 on malformed inputs.

- `scripts/dispatch/adapters/backend/local-codex.sh` (from T04)
  - Key API: identical to local-agent.sh.

- `templates/dispatch-error.md` (from T01)
  - Schema: `type: dispatch-error`, frontmatter includes `error_type`, `retry_eligible`, `escalation`, `backend`, `occurred_at`. Body: Error Type, Retry Eligibility, Escalation, Error Message, Context, Suggested Action.
  - The interface emits text matching this schema via a heredoc on stderr when dispatch fails.

### From Disk (Pre-existing)

- None required beyond standard utilities (`bash`, `date`, `grep`, `cut`, `echo`, `cat`).

## Constraints

- Bash 3.2 compatible — no associative arrays, no `readarray`, no `|&`.
- MUST NOT contain backend-specific branching. Adapter resolution is purely by filename (`${ADAPTERS_DIR}/${BACKEND}.sh`). No `case "$BACKEND" in local-agent) ... esac` or equivalent. Verified by `m008-p02-interface-agnostic.sh`.
- MUST invoke adapters as subprocesses (`bash "$adapter" ...`), never via `source`. Isolation is a hard requirement.
- MUST emit adapter stdout unchanged on success — no reformatting, no truncation.
- On failure MUST emit a dispatch-error.md conforming document on stderr (not stdout) and exit non-zero.
- Exit codes are informational (callers primarily inspect the emitted document), but use distinct codes: 2 (input_invalid), 3 (registry_error), 4 (backend_unavailable), 5 (backend_crashed), 6 (backend_malformed).
- ISO 8601 UTC timestamps (`date -u +%Y-%m-%dT%H:%M:%SZ`) per MEM008.

## Expected Output

After completing this task:

1. `scripts/dispatch/dispatch-interface.sh` exists (~160 lines), is executable.
2. With missing `--task-plan` or `--payload`, the script emits a `dispatch-error` on stderr with `error_type: input_invalid` and exits non-zero.
3. With valid inputs and `--backend local-agent`, the script invokes the adapter and emits the adapter's `dispatch-result` on stdout unchanged. Exit 0.
4. With `--backend does-not-exist`, the script emits a `dispatch-error` with `error_type: backend_unavailable`. Exit non-zero.
5. Without `--backend`, the script queries the registry for `default_backend` and routes accordingly.
6. The script contains no backend-specific branching.
7. `bash scripts/verify/m008-p02-interface-arguments.sh` prints `PASS`.
8. `bash scripts/verify/m008-p02-interface-routing.sh` prints `PASS`.
9. `bash scripts/verify/m008-p02-interface-agnostic.sh` prints `PASS`.
10. `git status` shows 4 new files.

## State Context

- **Current State**: executing
- **Milestone**: M008
- **Phase**: P02
- **Task**: T05
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