---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T04 (Phase P01, Milestone M008)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (25 entries) | 19-588 | ~4800 | filtered |
| Decisions | 590-592 | ~100 | filtered |
| Constraints | 594-599 | ~100 | required |
| Scope | 601-629 | ~400 | required |
| Upstream Context | 631-633 | ~100 | required |
| Task Plan | 635-1110 | ~4000 | required |
| State Context | 1112-1118 | ~100 | required |
| **Total** | | **~9600** | |

## Knowledge

<!-- 25 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 4
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
hit_count: 4
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
hit_count: 4
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
hit_count: 4
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
hit_count: 3
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
hit_count: 3
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
hit_count: 3
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
hit_count: 4
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
hit_count: 3
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
hit_count: 3
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
hit_count: 3
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
hit_count: 4
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
hit_count: 4
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
hit_count: 4
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
hit_count: 3
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
hit_count: 3
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
hit_count: 3
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
hit_count: 4
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
hit_count: 3
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
hit_count: 3
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
hit_count: 4
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
hit_count: 4
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
hit_count: 3
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
hit_count: 3
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
hit_count: 3
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

- detect-capabilities.sh adds graph_db, mcp_servers, and ci_pipeline detection while preserving all existing output fields.
  - Check: `bash scripts/verify/m008-p01-capabilities-backward-compat.sh`
- detect-capabilities.sh supports a --profile flag that outputs a capability summary suitable for intensity recommendation.
  - Check: `bash scripts/verify/m008-p01-capabilities-profile.sh`
- intensity-analyze.sh accepts a task description and outputs scope, risk_level, complexity, risk_signals, and recommended_intensity as key=value pairs.
  - Check: `bash scripts/verify/m008-p01-analyze-output-format.sh`
- intensity-analyze.sh classifies a trivial single-file fix as scope=trivial with recommended_intensity=Quick.
  - Check: `bash scripts/verify/m008-p01-analyze-trivial.sh`
- intensity-analyze.sh classifies a multi-component feature as scope=moderate with recommended_intensity=Standard.
  - Check: `bash scripts/verify/m008-p01-analyze-moderate.sh`
- intensity-analyze.sh detects risk signals (auth, security, migration keywords) and escalates intensity.
  - Check: `bash scripts/verify/m008-p01-analyze-risk-escalation.sh`
- intensity-recommend.sh combines analyze output + capability profile and produces intensity, confidence, and reasoning as key=value pairs.
  - Check: `bash scripts/verify/m008-p01-recommend-output-format.sh`
- intensity-recommend.sh factors detected capabilities into its recommendation (richer environment -> higher confidence).
  - Check: `bash scripts/verify/m008-p01-recommend-capabilities.sh`

## Upstream Context

No upstream summaries available.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M008"
name: "Create intensity-metadata.md template + context-pressure.sh"
depends_on: []
---

## Prerequisites

- `templates/` directory exists with existing templates following the `{{placeholder}}`
  convention and YAML frontmatter with `schema_version` + `type` fields.
- `scripts/engine/` directory exists.

## Description

Two independent deliverables in one task:

1. **templates/intensity-metadata.md** -- the YAML frontmatter schema that flows
   through all pipeline stages. This template defines the data structure that
   every intensity-aware pipeline stage reads and writes. It is created once when
   the intensity engine produces a recommendation and then carried through
   discussion, planning, dispatch, verification, and knowledge generation stages.

2. **scripts/engine/context-pressure.sh** -- evaluates estimated token count
   against configurable thresholds and outputs a pressure level and recommended
   action. This prevents dispatching oversized payloads that degrade agent output
   quality. Thresholds are configurable and intensity-aware (Quick has tighter
   thresholds to stay fast).

### Intensity Metadata Schema

The template defines these fields in YAML frontmatter:

```yaml
schema_version: "1.0"
type: intensity-metadata
intensity: Quick|Standard|Full
scope: trivial|moderate|large
risk_level: low|medium|high
complexity: simple|moderate|complex
confidence: high|medium|low
reasoning: "<human-readable explanation>"
overridden_by: ""           # "developer" if manually overridden, else empty
original_intensity: ""      # original recommendation if overridden, else empty
capabilities_used:
  - "<capability name>"     # list of capabilities detected and used
evaluated_at: ""            # ISO 8601 timestamp of evaluation
```

### Context Pressure Evaluator

The script accepts a token estimate and an optional intensity level, then
applies threshold-based rules:

**Default thresholds** (configurable via environment variables):
- `PRESSURE_WARN_PCT=60` -- warn the developer
- `PRESSURE_DECOMPOSE_PCT=75` -- recommend decomposing the task
- `PRESSURE_REFUSE_PCT=85` -- refuse to dispatch

**Context window sizes** (configurable, defaults based on common models):
- `CONTEXT_WINDOW_TOKENS=200000` -- default context window size

**Intensity-aware adjustment**:
- Quick: thresholds are 10% tighter (warn at 50%, decompose at 65%, refuse at 75%)
- Standard: default thresholds
- Full: thresholds are 5% looser (warn at 65%, decompose at 80%, refuse at 90%)

### Interface

```
Usage: context-pressure.sh --tokens N [--intensity Quick|Standard|Full]
                            [--context-window N]
  --tokens:         estimated token count for the payload
  --intensity:      current intensity level (default: Standard)
  --context-window: context window size in tokens (default: 200000)

  Environment variable overrides:
    CONTEXT_WINDOW_TOKENS  — context window size
    PRESSURE_WARN_PCT      — warn threshold percentage
    PRESSURE_DECOMPOSE_PCT — decompose threshold percentage
    PRESSURE_REFUSE_PCT    — refuse threshold percentage

Output (stdout, key=value):
  pressure=low|medium|high|critical
  action=proceed|warn|decompose|refuse
  utilization_pct=<integer 0-100>
  threshold_warn=<integer>
  threshold_decompose=<integer>
  threshold_refuse=<integer>

Exit: 0 always (pressure evaluation never fails — returns pressure=low on bad input).
```

## Steps

### Step 1 -- Create `templates/intensity-metadata.md`

Create the template file:

```markdown
---
schema_version: "1.0"
type: intensity-metadata
intensity: "{{intensity}}"
scope: "{{scope}}"
risk_level: "{{risk_level}}"
complexity: "{{complexity}}"
confidence: "{{confidence}}"
reasoning: "{{reasoning}}"
overridden_by: "{{overridden_by}}"
original_intensity: "{{original_intensity}}"
capabilities_used:
  - "{{capability}}"
evaluated_at: "{{evaluated_at}}"
---

## Intensity Metadata

**Recommended intensity**: {{intensity}}
**Confidence**: {{confidence}}

### Analysis

- **Scope**: {{scope}} -- {{scope_explanation}}
- **Risk**: {{risk_level}} -- {{risk_explanation}}
- **Complexity**: {{complexity}} -- {{complexity_explanation}}

### Risk Signals

{{risk_signals_list}}

### Capabilities Used

{{capabilities_list}}

### Override History

{{override_history}}
```

### Step 2 -- Create `scripts/engine/context-pressure.sh`

Create the file with the following content:

```bash
#!/usr/bin/env bash
# scripts/engine/context-pressure.sh — Context window pressure evaluator.
# Evaluates estimated token count against configurable thresholds to prevent
# dispatching oversized payloads that degrade agent output quality.
# Part of M008 Adaptive Intensity Engine (AD-04, DC-05, OQ-03).
#
# Usage: context-pressure.sh --tokens N [--intensity Quick|Standard|Full]
#                              [--context-window N]
#   --tokens:         estimated token count
#   --intensity:      current intensity level (default: Standard)
#   --context-window: context window size (default: $CONTEXT_WINDOW_TOKENS or 200000)
#
# Environment overrides:
#   CONTEXT_WINDOW_TOKENS   — context window size (default: 200000)
#   PRESSURE_WARN_PCT       — warn threshold % (default: 60)
#   PRESSURE_DECOMPOSE_PCT  — decompose threshold % (default: 75)
#   PRESSURE_REFUSE_PCT     — refuse threshold % (default: 85)
#
# Output (stdout, key=value):
#   pressure=low|medium|high|critical
#   action=proceed|warn|decompose|refuse
#   utilization_pct=<0-100>
#   threshold_warn=<token count>
#   threshold_decompose=<token count>
#   threshold_refuse=<token count>
#
# Exit: 0 always (pressure evaluation never fails).
# Bash 3.2 compatible (NFR-200).

set -euo pipefail

# --- Defaults ---
TOKENS=0
INTENSITY="Standard"
CONTEXT_WINDOW="${CONTEXT_WINDOW_TOKENS:-200000}"
WARN_PCT="${PRESSURE_WARN_PCT:-60}"
DECOMPOSE_PCT="${PRESSURE_DECOMPOSE_PCT:-75}"
REFUSE_PCT="${PRESSURE_REFUSE_PCT:-85}"

# --- Argument parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tokens)
      TOKENS="$2"; shift 2 ;;
    --intensity)
      INTENSITY="$2"; shift 2 ;;
    --context-window)
      CONTEXT_WINDOW="$2"; shift 2 ;;
    *)
      shift ;;
  esac
done

# --- Validate numeric inputs ---
# Default to safe values if inputs are not numeric
case "$TOKENS" in
  ''|*[!0-9]*) TOKENS=0 ;;
esac
case "$CONTEXT_WINDOW" in
  ''|*[!0-9]*) CONTEXT_WINDOW=200000 ;;
esac
case "$WARN_PCT" in
  ''|*[!0-9]*) WARN_PCT=60 ;;
esac
case "$DECOMPOSE_PCT" in
  ''|*[!0-9]*) DECOMPOSE_PCT=75 ;;
esac
case "$REFUSE_PCT" in
  ''|*[!0-9]*) REFUSE_PCT=85 ;;
esac

# --- Intensity-aware threshold adjustment ---
case "$INTENSITY" in
  Quick)
    # 10% tighter thresholds for Quick (stay fast, small payloads)
    WARN_PCT=$((WARN_PCT - 10))
    DECOMPOSE_PCT=$((DECOMPOSE_PCT - 10))
    REFUSE_PCT=$((REFUSE_PCT - 10))
    ;;
  Full)
    # 5% looser thresholds for Full (richer payloads acceptable)
    WARN_PCT=$((WARN_PCT + 5))
    DECOMPOSE_PCT=$((DECOMPOSE_PCT + 5))
    REFUSE_PCT=$((REFUSE_PCT + 5))
    ;;
  Standard|*)
    # Default thresholds, no adjustment
    ;;
esac

# Clamp percentages to valid range
if [[ "$WARN_PCT" -lt 10 ]]; then WARN_PCT=10; fi
if [[ "$WARN_PCT" -gt 95 ]]; then WARN_PCT=95; fi
if [[ "$DECOMPOSE_PCT" -lt 20 ]]; then DECOMPOSE_PCT=20; fi
if [[ "$DECOMPOSE_PCT" -gt 95 ]]; then DECOMPOSE_PCT=95; fi
if [[ "$REFUSE_PCT" -lt 30 ]]; then REFUSE_PCT=30; fi
if [[ "$REFUSE_PCT" -gt 99 ]]; then REFUSE_PCT=99; fi

# --- Calculate thresholds as token counts ---
threshold_warn=$((CONTEXT_WINDOW * WARN_PCT / 100))
threshold_decompose=$((CONTEXT_WINDOW * DECOMPOSE_PCT / 100))
threshold_refuse=$((CONTEXT_WINDOW * REFUSE_PCT / 100))

# --- Calculate utilization ---
if [[ "$CONTEXT_WINDOW" -gt 0 ]]; then
  utilization_pct=$((TOKENS * 100 / CONTEXT_WINDOW))
else
  utilization_pct=0
fi

# Clamp to 0-100
if [[ "$utilization_pct" -gt 100 ]]; then utilization_pct=100; fi
if [[ "$utilization_pct" -lt 0 ]]; then utilization_pct=0; fi

# --- Determine pressure level and action ---
pressure="low"
action="proceed"

if [[ "$TOKENS" -ge "$threshold_refuse" ]]; then
  pressure="critical"
  action="refuse"
elif [[ "$TOKENS" -ge "$threshold_decompose" ]]; then
  pressure="high"
  action="decompose"
elif [[ "$TOKENS" -ge "$threshold_warn" ]]; then
  pressure="medium"
  action="warn"
fi

# --- Output ---
echo "pressure=$pressure"
echo "action=$action"
echo "utilization_pct=$utilization_pct"
echo "threshold_warn=$threshold_warn"
echo "threshold_decompose=$threshold_decompose"
echo "threshold_refuse=$threshold_refuse"
```

Make executable:

```bash
chmod +x scripts/engine/context-pressure.sh
```

### Step 3 -- Create verification scripts

Create two verification scripts.

**scripts/verify/m008-p01-metadata-template.sh:**

```bash
#!/usr/bin/env bash
# Verifies templates/intensity-metadata.md exists with required YAML frontmatter fields.
set -eu

f="templates/intensity-metadata.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# Check schema_version and type in frontmatter
grep -q "schema_version:" "$f" || { echo "FAIL: $f missing schema_version"; exit 1; }
grep -q 'type: intensity-metadata' "$f" || { echo "FAIL: $f missing type: intensity-metadata"; exit 1; }

# Check all required fields exist in the template
for field in intensity scope risk_level complexity confidence reasoning overridden_by original_intensity capabilities_used evaluated_at; do
  grep -q "$field:" "$f" || { echo "FAIL: $f missing field: $field"; exit 1; }
done

# Check placeholder syntax
grep -q '{{intensity}}' "$f" || { echo "FAIL: $f missing {{intensity}} placeholder"; exit 1; }
grep -q '{{overridden_by}}' "$f" || { echo "FAIL: $f missing {{overridden_by}} placeholder"; exit 1; }

echo "PASS: templates/intensity-metadata.md exists with all required fields and placeholder syntax"
```

**scripts/verify/m008-p01-context-pressure.sh:**

```bash
#!/usr/bin/env bash
# Verifies context-pressure.sh evaluates token estimates and outputs pressure/action.
set -eu

f="scripts/engine/context-pressure.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }

# Test 1: Low pressure (10k tokens in 200k window = 5%)
output="$(bash "$f" --tokens 10000 --context-window 200000 2>/dev/null)"
pressure="$(echo "$output" | grep "^pressure=" | cut -d= -f2)"
action="$(echo "$output" | grep "^action=" | cut -d= -f2)"
if [[ "$pressure" != "low" ]]; then
  echo "FAIL: 10k/200k should be pressure=low, got $pressure"; exit 1
fi
if [[ "$action" != "proceed" ]]; then
  echo "FAIL: 10k/200k should be action=proceed, got $action"; exit 1
fi

# Test 2: High pressure (160k tokens in 200k window = 80%)
output="$(bash "$f" --tokens 160000 --context-window 200000 2>/dev/null)"
pressure="$(echo "$output" | grep "^pressure=" | cut -d= -f2)"
action="$(echo "$output" | grep "^action=" | cut -d= -f2)"
if [[ "$pressure" != "high" ]]; then
  echo "FAIL: 160k/200k should be pressure=high, got $pressure"; exit 1
fi
if [[ "$action" != "decompose" ]]; then
  echo "FAIL: 160k/200k should be action=decompose, got $action"; exit 1
fi

# Test 3: Critical pressure (180k tokens in 200k window = 90%)
output="$(bash "$f" --tokens 180000 --context-window 200000 2>/dev/null)"
pressure="$(echo "$output" | grep "^pressure=" | cut -d= -f2)"
action="$(echo "$output" | grep "^action=" | cut -d= -f2)"
if [[ "$pressure" != "critical" ]]; then
  echo "FAIL: 180k/200k should be pressure=critical, got $pressure"; exit 1
fi
if [[ "$action" != "refuse" ]]; then
  echo "FAIL: 180k/200k should be action=refuse, got $action"; exit 1
fi

# Test 4: Verify all output fields present
echo "$output" | grep -q "^pressure=" || { echo "FAIL: missing pressure="; exit 1; }
echo "$output" | grep -q "^action=" || { echo "FAIL: missing action="; exit 1; }
echo "$output" | grep -q "^utilization_pct=" || { echo "FAIL: missing utilization_pct="; exit 1; }
echo "$output" | grep -q "^threshold_warn=" || { echo "FAIL: missing threshold_warn="; exit 1; }
echo "$output" | grep -q "^threshold_decompose=" || { echo "FAIL: missing threshold_decompose="; exit 1; }
echo "$output" | grep -q "^threshold_refuse=" || { echo "FAIL: missing threshold_refuse="; exit 1; }

# Test 5: Quick intensity tightens thresholds (10% tighter)
# At Standard, 130k/200k = 65% is medium (above 60% warn). At Quick, warn is 50%, so 65% > 50% -> medium.
# But let's test: 110k/200k = 55%. Standard: below 60% warn = low. Quick: above 50% warn = medium.
output="$(bash "$f" --tokens 110000 --context-window 200000 --intensity Quick 2>/dev/null)"
pressure="$(echo "$output" | grep "^pressure=" | cut -d= -f2)"
if [[ "$pressure" != "medium" ]]; then
  echo "FAIL: Quick intensity at 55% should be pressure=medium (warn at 50%), got $pressure"; exit 1
fi

echo "PASS: context-pressure.sh correctly evaluates pressure levels, actions, and intensity-aware thresholds"
```

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "templates/intensity-metadata.md exists with YAML frontmatter schema
  containing intensity, scope, risk_level, complexity, confidence, reasoning,
  overridden_by, original_intensity, and capabilities_used fields" and
  "context-pressure.sh evaluates token estimates against configurable thresholds
  and outputs pressure level and recommended action".
- **Artifacts**: `templates/intensity-metadata.md`, `scripts/engine/context-pressure.sh`,
  two verification scripts.

## Verification

Run each verification script standalone:

```bash
bash scripts/verify/m008-p01-metadata-template.sh
bash scripts/verify/m008-p01-context-pressure.sh
```

Both should print PASS lines and exit 0.

Additional manual tests:

```bash
# Low pressure
bash scripts/engine/context-pressure.sh --tokens 5000
# Expected: pressure=low, action=proceed

# Medium pressure at Quick intensity
bash scripts/engine/context-pressure.sh --tokens 110000 --intensity Quick
# Expected: pressure=medium, action=warn (Quick threshold is 50%, 110k/200k = 55%)

# Critical pressure
bash scripts/engine/context-pressure.sh --tokens 180000
# Expected: pressure=critical, action=refuse
```

### Files Touched By This Task

- `templates/intensity-metadata.md` (create)
- `scripts/engine/context-pressure.sh` (create)
- `scripts/verify/m008-p01-metadata-template.sh` (create)
- `scripts/verify/m008-p01-context-pressure.sh` (create)

## Inputs

### From Previous Tasks

None -- T04 is independent.

### From Disk (Pre-existing)

- `templates/` directory -- existing templates use `{{placeholder}}` syntax
  with YAML frontmatter containing `schema_version` and `type` fields.
  The new template follows the same convention.

- `scripts/engine/` directory -- the new script lives here alongside
  checkpoint.sh, run.sh.

## Constraints

- Bash 3.2 compatible -- no associative arrays, no readarray, no `|&`.
- context-pressure.sh exits 0 always (pressure evaluation never fails).
- Template uses `{{placeholder}}` syntax consistent with all other templates.
- Template YAML frontmatter must include `schema_version: "1.0"` and
  `type: intensity-metadata`.
- Thresholds configurable via environment variables for testing and customization.
- Integer arithmetic only (no floating point in Bash) -- use percentage-based
  calculations with `$((token * 100 / window))`.

## Expected Output

After completing this task:

1. `templates/intensity-metadata.md` exists with ~30+ lines, YAML frontmatter
   containing all 10 specified fields, and `{{placeholder}}` syntax in the body.
2. `scripts/engine/context-pressure.sh` exists, is chmod +x, ~100+ lines.
3. `bash scripts/engine/context-pressure.sh --tokens 5000` outputs
   `pressure=low`, `action=proceed`.
4. `bash scripts/engine/context-pressure.sh --tokens 160000` outputs
   `pressure=high`, `action=decompose`.
5. `bash scripts/engine/context-pressure.sh --tokens 180000` outputs
   `pressure=critical`, `action=refuse`.
6. Quick intensity tightens thresholds by 10%; Full intensity loosens by 5%.
7. Both verification scripts print PASS and exit 0.
8. `git status` shows 4 new files.

## State Context

- **Current State**: executing
- **Milestone**: M008
- **Phase**: P01
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