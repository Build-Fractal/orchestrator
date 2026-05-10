---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T06 (Phase P02, Milestone M008)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (25 entries) | 19-588 | ~4900 | filtered |
| Decisions | 590-592 | ~100 | filtered |
| Constraints | 594-599 | ~100 | required |
| Scope | 601-629 | ~500 | required |
| Upstream Context | 631-633 | ~100 | required |
| Task Plan | 635-881 | ~2500 | required |
| State Context | 883-889 | ~100 | required |
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
hit_count: 12
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
hit_count: 12
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
hit_count: 12
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
hit_count: 12
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
hit_count: 10
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
hit_count: 10
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
hit_count: 10
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
hit_count: 12
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
hit_count: 10
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
hit_count: 10
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
hit_count: 10
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
hit_count: 12
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
hit_count: 12
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
hit_count: 12
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
hit_count: 10
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
hit_count: 10
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
hit_count: 10
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
hit_count: 12
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
hit_count: 10
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
hit_count: 10
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
hit_count: 12
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
hit_count: 12
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
hit_count: 10
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
hit_count: 10
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
hit_count: 10
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
task: "T06"
phase: "P02"
milestone: "M008"
name: "Integration test + Bash 3.2 compatibility check"
depends_on: ["T01", "T02", "T03", "T04", "T05"]
---

## Prerequisites

- All prior P02 tasks complete:
  - T01: `templates/dispatch-result.md`, `templates/dispatch-error.md`
  - T02: `scripts/dispatch/backend-registry.sh`
  - T03: `scripts/dispatch/adapters/backend/local-agent.sh`
  - T04: `scripts/dispatch/adapters/backend/local-codex.sh`
  - T05: `scripts/dispatch/dispatch-interface.sh`

## Description

Create two final verification scripts:

1. **`scripts/verify/m008-p02-bash32-compat.sh`** — scans all P02 shell scripts for Bash-4-only constructs (associative arrays `declare -A`, `readarray`/`mapfile`, `|&`, `&>>` append-redirect) and fails if any are found. Mirrors `m002-p02-bash32-compat.sh` and `m008-p01-bash32-compat.sh`.

2. **`scripts/verify/m008-p02-integration-e2e.sh`** — end-to-end integration smoke test. Constructs a fixture task plan, payload, and intensity-metadata file in a scratch directory, then invokes `dispatch-interface.sh` routed to `local-agent` (forced available via `SPECKIT_AGENT_TOOL=1`). Asserts that the emitted stdout is a parseable dispatch-result with the correct backend and propagated task_id.

This task adds no new source scripts or templates — only the two verification scripts. It is the phase "glue" check confirming all five prior tasks integrate correctly.

## Steps

### Step 1 — Create scripts/verify/m008-p02-bash32-compat.sh

Write the following content verbatim:

```bash
#!/usr/bin/env bash
# Verifies all P02 shell scripts are Bash 3.2 compatible.
# macOS ships Bash 3.2; the orchestrator targets this baseline.
set -u

FILES=(
  "scripts/dispatch/backend-registry.sh"
  "scripts/dispatch/dispatch-interface.sh"
  "scripts/dispatch/adapters/backend/local-agent.sh"
  "scripts/dispatch/adapters/backend/local-codex.sh"
)

for f in "${FILES[@]}"; do
  test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

  # Forbidden: declare -A (associative arrays, Bash 4+)
  if grep -qE '^[[:space:]]*declare[[:space:]]+-A' "$f"; then
    echo "FAIL: $f uses 'declare -A' (associative arrays, Bash 4+)"
    exit 1
  fi

  # Forbidden: readarray / mapfile (Bash 4+)
  if grep -qE '^[[:space:]]*(readarray|mapfile)[[:space:]]' "$f"; then
    echo "FAIL: $f uses readarray/mapfile (Bash 4+)"
    exit 1
  fi

  # Forbidden: |& (Bash 4+ shorthand for 2>&1 |)
  if grep -qE '[^|]\|&[^|]' "$f"; then
    echo "FAIL: $f uses '|&' (Bash 4+ shorthand)"
    exit 1
  fi
done

echo "PASS: all P02 scripts are Bash 3.2 compatible"
```

Make it executable:

```bash
chmod +x scripts/verify/m008-p02-bash32-compat.sh
```

### Step 2 — Create scripts/verify/m008-p02-integration-e2e.sh

Write the following content verbatim:

```bash
#!/usr/bin/env bash
# End-to-end integration smoke test for P02.
#
# Constructs a fixture task plan, payload, and intensity-metadata file,
# then invokes dispatch-interface.sh with --backend local-agent (forced
# available via SPECKIT_AGENT_TOOL=1). Asserts that the emitted stdout
# is a parseable dispatch-result with backend=local-agent and the
# propagated task_id.
set -u

INTERFACE="scripts/dispatch/dispatch-interface.sh"
REGISTRY="scripts/dispatch/backend-registry.sh"
LOCAL_AGENT="scripts/dispatch/adapters/backend/local-agent.sh"
LOCAL_CODEX="scripts/dispatch/adapters/backend/local-codex.sh"
RESULT_TEMPLATE="templates/dispatch-result.md"
ERROR_TEMPLATE="templates/dispatch-error.md"

# All P02 artifacts must exist
for f in "$INTERFACE" "$REGISTRY" "$LOCAL_AGENT" "$LOCAL_CODEX" "$RESULT_TEMPLATE" "$ERROR_TEMPLATE"; do
  test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
done
for f in "$INTERFACE" "$REGISTRY" "$LOCAL_AGENT" "$LOCAL_CODEX"; do
  test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }
done

# Registry must list both adapters
discovered="$(bash "$REGISTRY" --list 2>/dev/null | tr '\n' ',' | sed 's/,$//')"
echo ",${discovered}," | grep -q ',local-agent,' || { echo "FAIL: registry did not discover local-agent (got: $discovered)"; exit 1; }
echo ",${discovered}," | grep -q ',local-codex,' || { echo "FAIL: registry did not discover local-codex (got: $discovered)"; exit 1; }

# Registry summary must succeed
summary="$(bash "$REGISTRY" 2>/dev/null)"
echo "$summary" | grep -q '^backends_discovered=' || { echo "FAIL: registry summary missing backends_discovered"; exit 1; }
echo "$summary" | grep -q '^backends_available=' || { echo "FAIL: registry summary missing backends_available"; exit 1; }
echo "$summary" | grep -q '^default_backend=' || { echo "FAIL: registry summary missing default_backend"; exit 1; }

# Fixture inputs
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/task-plan.md" <<'EOF'
---
schema_version: "1.0"
type: task-plan
task: "T42"
phase: "P02"
milestone: "M008"
name: "E2E fixture"
depends_on: []
---

## Description

Fixture task plan for P02 integration test.
EOF

echo "Integration payload fixture" > "$tmp/payload.md"
echo "Integration metadata fixture" > "$tmp/metadata.md"

# Invoke dispatch-interface.sh routed explicitly to local-agent.
# SPECKIT_AGENT_TOOL=1 forces local-agent probe to report available=true.
output="$(SPECKIT_AGENT_TOOL=1 bash "$INTERFACE" \
  --task-plan "$tmp/task-plan.md" \
  --payload "$tmp/payload.md" \
  --intensity-metadata "$tmp/metadata.md" \
  --backend local-agent 2>/dev/null)"
rc=$?
if [[ $rc -ne 0 ]]; then
  echo "FAIL: dispatch-interface.sh --backend local-agent exited $rc (expected 0)"
  exit 1
fi

# Assert parseable dispatch-result
echo "$output" | grep -q '^schema_version: "1.0"' || { echo "FAIL: output missing schema_version frontmatter"; exit 1; }
echo "$output" | grep -q '^type: "dispatch-result"' || { echo "FAIL: output not a dispatch-result"; exit 1; }
echo "$output" | grep -q '^backend: "local-agent"' || { echo "FAIL: output backend is not local-agent"; exit 1; }
echo "$output" | grep -q '^task_id: "T42"' || { echo "FAIL: output did not propagate task_id from fixture"; exit 1; }
echo "$output" | grep -q '^phase_id: "P02"' || { echo "FAIL: output did not propagate phase_id from fixture"; exit 1; }
echo "$output" | grep -q '^milestone_id: "M008"' || { echo "FAIL: output did not propagate milestone_id from fixture"; exit 1; }
echo "$output" | grep -qE '^status: "(success|failure|retry|timeout)"' || { echo "FAIL: output status not in expected set"; exit 1; }

# Also verify a failure path: non-existent backend -> structured error on stderr
err="$(bash "$INTERFACE" \
  --task-plan "$tmp/task-plan.md" \
  --payload "$tmp/payload.md" \
  --intensity-metadata "$tmp/metadata.md" \
  --backend nonexistent-backend 2>&1 >/dev/null || true)"
echo "$err" | grep -q '^type: "dispatch-error"' || { echo "FAIL: nonexistent backend did not emit dispatch-error"; exit 1; }

echo "PASS: P02 integration -- registry discovers adapters, interface routes to local-agent, result schema conforms"
```

Make it executable:

```bash
chmod +x scripts/verify/m008-p02-integration-e2e.sh
```

## Must-Haves

From the phase plan, this task addresses:

- **Truths**: "All new scripts are Bash 3.2 compatible..." and "End-to-end integration: dispatch-interface.sh, invoked with a fixture task plan and payload and explicit --backend local-agent, produces a parseable dispatch-result on stdout."
- **Artifacts**: `scripts/verify/m008-p02-bash32-compat.sh`, `scripts/verify/m008-p02-integration-e2e.sh`.

## Verification

Run each verification script standalone:

```bash
bash scripts/verify/m008-p02-bash32-compat.sh
bash scripts/verify/m008-p02-integration-e2e.sh
```

Both should print `PASS:` and exit 0.

Also run the full phase verification to confirm all must-haves are satisfied:

```bash
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M008/phases/P02
```

### Files Touched By This Task

- `scripts/verify/m008-p02-bash32-compat.sh` (create)
- `scripts/verify/m008-p02-integration-e2e.sh` (create)

## Inputs

### From Previous Tasks

- `scripts/dispatch/dispatch-interface.sh` (from T05)
  - Key API: `bash ... --task-plan <p> --payload <p> --intensity-metadata <p> [--backend <name>]`. Emits adapter's dispatch-result on stdout (exit 0) or dispatch-error on stderr (exit non-zero).
- `scripts/dispatch/backend-registry.sh` (from T02)
  - Key API: `bash ...` -> `backends_discovered=`, `backends_available=`, `default_backend=` lines. `--list` prints adapter names.
- `scripts/dispatch/adapters/backend/local-agent.sh` (from T03)
  - Behavior: probe honors `SPECKIT_AGENT_TOOL=1`; normal mode emits dispatch-result with backend=local-agent.
- `scripts/dispatch/adapters/backend/local-codex.sh` (from T04)
  - Behavior: probe checks PATH for `codex`.
- `templates/dispatch-result.md`, `templates/dispatch-error.md` (from T01)
  - Schemas emitted by adapters (result) and interface (error).

### From Disk (Pre-existing)

- Standard utilities (`bash`, `grep`, `mktemp`, `cat`, `echo`, `tr`, `sed`).

## Constraints

- No new source scripts or templates are created in this task — only verification scripts.
- The Bash 3.2 check targets only the P02 source scripts (not the verify scripts themselves, which may use slightly richer constructs within reason).
- The integration test must be hermetic: all fixture files are created in `mktemp -d` and cleaned via `trap`.
- `SPECKIT_AGENT_TOOL=1` is used to force local-agent availability so the test is deterministic regardless of the developer's current runtime (avoids false failures on CI where `.claude/` may not exist).

## Expected Output

After completing this task:

1. `scripts/verify/m008-p02-bash32-compat.sh` exists, is executable, and prints `PASS` when run.
2. `scripts/verify/m008-p02-integration-e2e.sh` exists, is executable, and prints `PASS` when run.
3. `bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M008/phases/P02` reports all phase truths pass.
4. `git status` shows 2 new files.

## State Context

- **Current State**: executing
- **Milestone**: M008
- **Phase**: P02
- **Task**: T06
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