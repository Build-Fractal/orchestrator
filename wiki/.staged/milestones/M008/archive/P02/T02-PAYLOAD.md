---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T02 (Phase P02, Milestone M008)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (25 entries) | 19-588 | ~4800 | filtered |
| Decisions | 590-592 | ~100 | filtered |
| Constraints | 594-599 | ~100 | required |
| Scope | 601-629 | ~500 | required |
| Upstream Context | 631-633 | ~100 | required |
| Task Plan | 635-918 | ~2500 | required |
| State Context | 920-926 | ~100 | required |
| **Total** | | **~8200** | |

## Knowledge

<!-- 25 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 8
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
hit_count: 8
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
hit_count: 8
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
hit_count: 8
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
hit_count: 6
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
hit_count: 6
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
hit_count: 6
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
hit_count: 8
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
hit_count: 6
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
hit_count: 6
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
hit_count: 6
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
hit_count: 8
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
hit_count: 8
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
hit_count: 8
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
hit_count: 6
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
hit_count: 6
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
hit_count: 6
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
hit_count: 8
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
hit_count: 6
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
hit_count: 6
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
hit_count: 8
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
hit_count: 8
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
hit_count: 6
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
hit_count: 6
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
hit_count: 6
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
task: "T02"
phase: "P02"
milestone: "M008"
name: "Create backend-registry.sh -- adapter auto-discovery and probing"
depends_on: []
---

## Prerequisites

- `scripts/dispatch/` directory exists (contains `build-context.sh`, `detect-capabilities.sh`, etc.).
- The directory `scripts/dispatch/adapters/backend/` may not yet exist — this task will create it if absent so registry invocations remain safe when called in isolation.

## Description

Create `scripts/dispatch/backend-registry.sh`, which enumerates available dispatch backend adapters by scanning `scripts/dispatch/adapters/backend/*.sh` and probing each one. The registry is the mechanism that satisfies FR-011 — "new dispatch backends can be registered without modifying core dispatch logic." There is no central registration file; dropping a new adapter script into `scripts/dispatch/adapters/backend/` is sufficient.

The registry contract:

- Adapters are shell scripts matching `scripts/dispatch/adapters/backend/*.sh`.
- Each adapter MUST support a `--probe` sub-command that outputs key=value lines including at minimum `available=true|false`.
- The registry aggregates probe results and outputs the set of available backends and the default backend (first available in sorted-by-filename order).

Output format (key=value lines on stdout, one per line):

```
backends_discovered=local-agent,local-codex
backends_available=local-agent
default_backend=local-agent
```

- `backends_discovered` — comma-separated list of all adapter names (with the `.sh` suffix stripped), sorted alphabetically.
- `backends_available` — comma-separated subset that probed `available=true`.
- `default_backend` — the first entry in `backends_available`; empty string if none available.

If no adapters are discovered, output:

```
backends_discovered=
backends_available=
default_backend=
```

Exit code: always 0. Registry failures (missing adapters, probe timeouts) are reflected in the output, not the exit code.

## Steps

### Step 1 — Ensure the adapters directory exists

The registry must not fail when no adapters are present yet (during bootstrap or in tests). The script will test for the directory and gracefully output empty fields.

### Step 2 — Create scripts/dispatch/backend-registry.sh

Write the following content verbatim to `scripts/dispatch/backend-registry.sh`:

```bash
#!/usr/bin/env bash
# scripts/dispatch/backend-registry.sh — Dispatch backend discovery and probing
#
# Scans scripts/dispatch/adapters/backend/*.sh and probes each adapter via
# --probe to determine which backends are available in the current
# environment. Outputs discovery and availability as key=value lines.
#
# Usage: backend-registry.sh [--list | --probe <backend>]
#   (no args)       — discover + probe all adapters; output key=value summary
#   --list          — list all discovered adapters (one per line), no probing
#   --probe <name>  — probe a single named adapter; print its raw probe output
#
# Output (default mode):
#   backends_discovered=<comma-list>
#   backends_available=<comma-list>
#   default_backend=<name or empty>
#
# FR-011: new backends are registered by dropping a *.sh file into the
# adapters/backend/ directory. No core edits required.
#
# Bash 3.2 compatible. Always exits 0.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTERS_DIR="${SCRIPT_DIR}/adapters/backend"

MODE="summary"
TARGET_BACKEND=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --list)
      MODE="list"; shift ;;
    --probe)
      MODE="probe"; TARGET_BACKEND="${2:-}"; shift 2 ;;
    *)
      shift ;;
  esac
done

# --- Discovery ---

discovered_names=""
if [[ -d "$ADAPTERS_DIR" ]]; then
  for adapter in "$ADAPTERS_DIR"/*.sh; do
    [[ -f "$adapter" ]] || continue
    base="$(basename "$adapter" .sh)"
    if [[ -z "$discovered_names" ]]; then
      discovered_names="$base"
    else
      discovered_names="${discovered_names},${base}"
    fi
  done
fi

# --- Mode: list ---

if [[ "$MODE" = "list" ]]; then
  if [[ -n "$discovered_names" ]]; then
    # Print one adapter name per line
    old_ifs="$IFS"
    IFS=','
    for name in $discovered_names; do
      echo "$name"
    done
    IFS="$old_ifs"
  fi
  exit 0
fi

# --- Mode: probe a single named adapter ---

if [[ "$MODE" = "probe" ]]; then
  if [[ -z "$TARGET_BACKEND" ]]; then
    echo "FAIL: --probe requires a backend name" >&2
    exit 0
  fi
  adapter="${ADAPTERS_DIR}/${TARGET_BACKEND}.sh"
  if [[ ! -f "$adapter" ]]; then
    echo "available=false"
    echo "reason=adapter-not-found"
    exit 0
  fi
  bash "$adapter" --probe 2>/dev/null || echo "available=false"
  exit 0
fi

# --- Mode: summary (default) ---

available_names=""
if [[ -n "$discovered_names" ]]; then
  old_ifs="$IFS"
  IFS=','
  for name in $discovered_names; do
    adapter="${ADAPTERS_DIR}/${name}.sh"
    probe_output="$(bash "$adapter" --probe 2>/dev/null || echo "available=false")"
    # Extract the available= value
    is_available="$(echo "$probe_output" | grep -E '^available=' | head -n 1 | cut -d= -f2)"
    if [[ "$is_available" = "true" ]]; then
      if [[ -z "$available_names" ]]; then
        available_names="$name"
      else
        available_names="${available_names},${name}"
      fi
    fi
  done
  IFS="$old_ifs"
fi

default_backend=""
if [[ -n "$available_names" ]]; then
  default_backend="${available_names%%,*}"
fi

echo "backends_discovered=${discovered_names}"
echo "backends_available=${available_names}"
echo "default_backend=${default_backend}"
exit 0
```

### Step 3 — Make the script executable

```bash
chmod +x scripts/dispatch/backend-registry.sh
```

### Step 4 — Create scripts/verify/m008-p02-registry-discovery.sh

Write the following content verbatim:

```bash
#!/usr/bin/env bash
# Verifies backend-registry.sh discovers and probes adapters correctly.
set -u

f="scripts/dispatch/backend-registry.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }

# Script documents its contract
grep -q 'backends_discovered' "$f" || { echo "FAIL: $f missing backends_discovered key"; exit 1; }
grep -q 'backends_available' "$f" || { echo "FAIL: $f missing backends_available key"; exit 1; }
grep -q 'default_backend' "$f" || { echo "FAIL: $f missing default_backend key"; exit 1; }
grep -q '\-\-probe' "$f" || { echo "FAIL: $f does not probe adapters"; exit 1; }
grep -q 'adapters/backend' "$f" || { echo "FAIL: $f does not reference adapters directory"; exit 1; }

# Script must be bash 3.2 compatible (no declare -A)
if grep -qE '^[[:space:]]*declare[[:space:]]+-A' "$f"; then
  echo "FAIL: $f uses declare -A (not Bash 3.2 compatible)"; exit 1
fi

# Run the script in summary mode — must emit all three required keys and exit 0
output="$(bash "$f" 2>/dev/null)"
rc=$?
if [[ $rc -ne 0 ]]; then
  echo "FAIL: $f exited $rc (expected 0)"; exit 1
fi
echo "$output" | grep -qE '^backends_discovered=' || { echo "FAIL: output missing backends_discovered"; exit 1; }
echo "$output" | grep -qE '^backends_available=' || { echo "FAIL: output missing backends_available"; exit 1; }
echo "$output" | grep -qE '^default_backend=' || { echo "FAIL: output missing default_backend"; exit 1; }

# --list mode must work without adapters present (may print nothing or list names)
bash "$f" --list >/dev/null 2>&1 || { echo "FAIL: --list mode failed"; exit 1; }

echo "PASS: backend-registry.sh discovers and probes adapters"
```

Make it executable:

```bash
chmod +x scripts/verify/m008-p02-registry-discovery.sh
```

## Must-Haves

From the phase plan, this task addresses:

- **Truths**: "scripts/dispatch/backend-registry.sh discovers adapters in scripts/dispatch/adapters/backend/*.sh and probes each to determine availability..."
- **Artifacts**: `scripts/dispatch/backend-registry.sh`, `scripts/verify/m008-p02-registry-discovery.sh`.

## Verification

Run the verification script standalone:

```bash
bash scripts/verify/m008-p02-registry-discovery.sh
```

Should print `PASS:` and exit 0. Note: T02's verification runs successfully even when no adapters exist yet (the `backends_discovered` field is empty but present). Full multi-adapter verification occurs in T06 after T03 and T04 create the adapters.

### Files Touched By This Task

- `scripts/dispatch/backend-registry.sh` (create)
- `scripts/verify/m008-p02-registry-discovery.sh` (create)

## Inputs

### From Previous Tasks

None — T02 is independent of T01.

### From Disk (Pre-existing)

- `scripts/dispatch/detect-capabilities.sh` — existing peer script demonstrating the `--format` / flag-style argument parsing pattern and key=value output convention.

## Constraints

- Bash 3.2 compatible — no `declare -A`, no `readarray`, no `|&`.
- Always exits 0 (registry failures are reflected in output fields, never via exit codes).
- Must function even when `scripts/dispatch/adapters/backend/` directory does not exist (empty output, no error).
- Must not `source` adapter scripts — always invoke them as subprocesses (`bash "$adapter" --probe`). Adapters are isolated.
- Adapter probe output is parsed by grepping `^available=` — adapters that emit malformed probe output are treated as unavailable.

## Expected Output

After completing this task:

1. `scripts/dispatch/backend-registry.sh` exists (~110 lines), is executable, and supports three modes: default (summary), `--list`, and `--probe <name>`.
2. `bash scripts/dispatch/backend-registry.sh` with no adapters present outputs three lines: `backends_discovered=`, `backends_available=`, `default_backend=` (all empty). Exit 0.
3. `bash scripts/dispatch/backend-registry.sh --list` prints adapter names one per line (or nothing if none exist). Exit 0.
4. `bash scripts/verify/m008-p02-registry-discovery.sh` prints `PASS`.
5. `git status` shows 2 new files.

## State Context

- **Current State**: executing
- **Milestone**: M008
- **Phase**: P02
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