---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T03 (Phase P01, Milestone M008)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (25 entries) | 19-588 | ~4800 | filtered |
| Decisions | 590-592 | ~100 | filtered |
| Constraints | 594-599 | ~100 | required |
| Scope | 601-629 | ~400 | required |
| Upstream Context | 631-633 | ~100 | required |
| Task Plan | 635-1053 | ~3700 | required |
| State Context | 1055-1061 | ~100 | required |
| **Total** | | **~9300** | |

## Knowledge

<!-- 25 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 3
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
hit_count: 3
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
hit_count: 3
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
hit_count: 3
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
hit_count: 2
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
hit_count: 2
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
hit_count: 2
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
hit_count: 3
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
hit_count: 2
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
hit_count: 2
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
hit_count: 2
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
hit_count: 3
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
hit_count: 3
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
hit_count: 3
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
hit_count: 2
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
hit_count: 2
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
hit_count: 2
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
hit_count: 3
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
hit_count: 2
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
hit_count: 2
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
hit_count: 3
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
hit_count: 3
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
hit_count: 2
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
hit_count: 2
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
hit_count: 2
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
task: "T03"
phase: "P01"
milestone: "M008"
name: "Create intensity-recommend.sh -- recommendation engine combining analyze + capabilities"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 complete: `scripts/dispatch/detect-capabilities.sh` has `--profile` flag outputting cap_execution, cap_graph, cap_mcp, cap_ci, cap_subagent, cap_score.
- T02 complete: `scripts/engine/intensity-analyze.sh` exists and outputs scope, risk_level, complexity, risk_signals, recommended_intensity.

## Description

Create `scripts/engine/intensity-recommend.sh` that combines the output from
`intensity-analyze.sh` and `detect-capabilities.sh --profile` to produce a
final intensity recommendation with confidence level and human-readable
reasoning.

The recommendation engine is the integration point that resolves the final
intensity level the pipeline should operate at. It applies a decision matrix
that considers three inputs:

1. **Scope analysis** (from intensity-analyze.sh): scope, risk_level, complexity,
   risk_signals, recommended_intensity
2. **Capability profile** (from detect-capabilities.sh --profile): cap_execution,
   cap_graph, cap_mcp, cap_ci, cap_subagent, cap_score
3. **Decision matrix** (hardcoded): maps inputs to a final intensity + confidence

### Decision Matrix

The base intensity comes from `intensity-analyze.sh`. The recommendation engine
then adjusts confidence and may escalate (never downgrade) based on capabilities:

| Base Intensity | Capability Score | Confidence | Adjustment |
|----------------|-----------------|------------|------------|
| Quick          | any             | high       | No change -- Quick tasks don't benefit from richer environments |
| Standard       | 0-1             | high       | No change -- Standard is appropriate for lean environments |
| Standard       | 2-3             | high       | No change -- Standard already matched |
| Standard       | 4-5             | high       | No change -- richer environment but Standard still fits |
| Full           | 0-1             | medium     | Confidence reduced -- Full benefits from richer environment but can proceed |
| Full           | 2-3             | high       | Confidence high -- environment has enough for Full |
| Full           | 4-5             | high       | Confidence high -- rich environment |

Risk escalation rules (may override base):
- If risk_level=high AND base=Quick, escalate to Standard (risk overrides convenience).
- If risk_level=high AND complexity=complex, escalate to Full regardless of scope.
- If risk_signals contain "migration" or "security" or "auth", escalate to at least Standard.

Reasoning generation: The script produces a one-line reasoning string that
explains the recommendation. Format:
`"<Intensity> recommended: scope is <scope>, risk is <risk_level> [with signals: <signals>], complexity is <complexity>, environment has <cap_score>/5 capabilities."`

### Interface

```
Usage: intensity-recommend.sh [--analyze-output "key=value lines"] [--profile-output "key=value lines"]
  --analyze-output: output from intensity-analyze.sh (multi-line string)
  --profile-output: output from detect-capabilities.sh --profile (multi-line string)
  If flags not provided, runs both scripts internally.

Output (stdout, key=value):
  intensity=Quick|Standard|Full
  confidence=high|medium|low
  reasoning=<human readable explanation>
  scope=<passthrough from analyze>
  risk_level=<passthrough from analyze>
  complexity=<passthrough from analyze>
  risk_signals=<passthrough from analyze>
  cap_score=<passthrough from profile>

Exit: 0 on success, 1 on error.
```

## Steps

### Step 1 -- Create `scripts/engine/intensity-recommend.sh`

Create the file with the following content:

```bash
#!/usr/bin/env bash
# scripts/engine/intensity-recommend.sh — Intensity recommendation engine.
# Combines scope analysis (intensity-analyze.sh) + capability profile
# (detect-capabilities.sh --profile) into a final intensity recommendation
# with confidence and reasoning. Part of M008 Adaptive Intensity Engine
# (FR-001, FR-005, FR-025).
#
# Usage: intensity-recommend.sh [--analyze-output "text"] [--profile-output "text"]
#                                [--description "text"]
#   --analyze-output: pre-computed output from intensity-analyze.sh
#   --profile-output: pre-computed output from detect-capabilities.sh --profile
#   --description:    task description (runs intensity-analyze.sh internally)
#   If no flags given, reads description from stdin and runs both scripts.
#
# Output (stdout, key=value):
#   intensity=Quick|Standard|Full
#   confidence=high|medium|low
#   reasoning=<explanation>
#   scope=<from analyze>
#   risk_level=<from analyze>
#   complexity=<from analyze>
#   risk_signals=<from analyze>
#   cap_score=<from profile>
#
# Exit: 0 success, 1 error.
# Bash 3.2 compatible (NFR-200).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ANALYZE_OUTPUT=""
PROFILE_OUTPUT=""
DESCRIPTION=""

# --- Argument parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --analyze-output)
      ANALYZE_OUTPUT="$2"; shift 2 ;;
    --profile-output)
      PROFILE_OUTPUT="$2"; shift 2 ;;
    --description)
      DESCRIPTION="$2"; shift 2 ;;
    *)
      shift ;;
  esac
done

# If no analyze output provided, run intensity-analyze.sh
if [[ -z "$ANALYZE_OUTPUT" ]]; then
  if [[ -z "$DESCRIPTION" ]]; then
    if [[ -t 0 ]]; then
      echo "ERROR: no description or analyze output provided." >&2
      exit 1
    fi
    DESCRIPTION="$(cat)"
  fi
  ANALYZE_OUTPUT="$(echo "$DESCRIPTION" | bash "$SCRIPT_DIR/intensity-analyze.sh" 2>/dev/null)"
fi

# If no profile output provided, run detect-capabilities.sh --profile
if [[ -z "$PROFILE_OUTPUT" ]]; then
  PROFILE_OUTPUT="$(bash "$REPO_ROOT/scripts/dispatch/detect-capabilities.sh" --profile 2>/dev/null)"
fi

# --- Parse analyze output ---
# Extract values using grep + cut (no associative arrays)
scope="$(echo "$ANALYZE_OUTPUT" | grep "^scope=" | head -1 | cut -d= -f2)"
risk_level="$(echo "$ANALYZE_OUTPUT" | grep "^risk_level=" | head -1 | cut -d= -f2)"
complexity="$(echo "$ANALYZE_OUTPUT" | grep "^complexity=" | head -1 | cut -d= -f2)"
risk_signals="$(echo "$ANALYZE_OUTPUT" | grep "^risk_signals=" | head -1 | cut -d= -f2-)"
base_intensity="$(echo "$ANALYZE_OUTPUT" | grep "^recommended_intensity=" | head -1 | cut -d= -f2)"

# --- Parse capability profile ---
cap_score="$(echo "$PROFILE_OUTPUT" | grep "^cap_score=" | head -1 | cut -d= -f2)"
cap_score="${cap_score:-0}"

# --- Apply decision matrix ---
intensity="$base_intensity"
confidence="high"

# Risk escalation: risk overrides convenience
if [[ "$risk_level" = "high" ]] && [[ "$intensity" = "Quick" ]]; then
  intensity="Standard"
fi

# Risk + complexity double-escalation
if [[ "$risk_level" = "high" ]] && [[ "$complexity" = "complex" ]]; then
  intensity="Full"
fi

# Specific risk signal escalation (migration, security, auth -> at least Standard)
if [[ "$risk_signals" != "none" ]]; then
  for escalation_signal in "migration" "security" "auth"; do
    if echo "$risk_signals" | grep -qF "$escalation_signal"; then
      if [[ "$intensity" = "Quick" ]]; then
        intensity="Standard"
      fi
      break
    fi
  done
fi

# Confidence adjustment based on capability score
if [[ "$intensity" = "Full" ]] && [[ "$cap_score" -le 1 ]]; then
  confidence="medium"
fi

# --- Build reasoning ---
signal_clause=""
if [[ "$risk_signals" != "none" ]]; then
  signal_clause=" with signals: $risk_signals"
fi

reasoning="${intensity} recommended: scope is ${scope}, risk is ${risk_level}${signal_clause}, complexity is ${complexity}, environment has ${cap_score}/5 capabilities."

# --- Output ---
echo "intensity=$intensity"
echo "confidence=$confidence"
echo "reasoning=$reasoning"
echo "scope=$scope"
echo "risk_level=$risk_level"
echo "complexity=$complexity"
echo "risk_signals=$risk_signals"
echo "cap_score=$cap_score"
```

Make executable:

```bash
chmod +x scripts/engine/intensity-recommend.sh
```

### Step 2 -- Create verification scripts

Create two verification scripts.

**scripts/verify/m008-p01-recommend-output-format.sh:**

```bash
#!/usr/bin/env bash
# Verifies intensity-recommend.sh outputs all required key=value fields.
set -eu

f="scripts/engine/intensity-recommend.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }

# Provide pre-computed inputs so we don't depend on other scripts' runtime behavior
analyze="scope=moderate
risk_level=medium
complexity=moderate
risk_signals=none
recommended_intensity=Standard"

profile="cap_execution=local
cap_graph=false
cap_mcp=false
cap_ci=false
cap_subagent=false
cap_score=0"

output="$(bash "$f" --analyze-output "$analyze" --profile-output "$profile" 2>/dev/null)"

echo "$output" | grep -q "^intensity=" || { echo "FAIL: output missing intensity="; exit 1; }
echo "$output" | grep -q "^confidence=" || { echo "FAIL: output missing confidence="; exit 1; }
echo "$output" | grep -q "^reasoning=" || { echo "FAIL: output missing reasoning="; exit 1; }
echo "$output" | grep -q "^scope=" || { echo "FAIL: output missing scope="; exit 1; }
echo "$output" | grep -q "^risk_level=" || { echo "FAIL: output missing risk_level="; exit 1; }
echo "$output" | grep -q "^complexity=" || { echo "FAIL: output missing complexity="; exit 1; }
echo "$output" | grep -q "^risk_signals=" || { echo "FAIL: output missing risk_signals="; exit 1; }
echo "$output" | grep -q "^cap_score=" || { echo "FAIL: output missing cap_score="; exit 1; }

# Verify intensity is a valid value
intensity_val="$(echo "$output" | grep "^intensity=" | cut -d= -f2)"
case "$intensity_val" in
  Quick|Standard|Full) ;;
  *) echo "FAIL: intensity='$intensity_val' is not Quick|Standard|Full"; exit 1 ;;
esac

# Verify confidence is a valid value
conf_val="$(echo "$output" | grep "^confidence=" | cut -d= -f2)"
case "$conf_val" in
  high|medium|low) ;;
  *) echo "FAIL: confidence='$conf_val' is not high|medium|low"; exit 1 ;;
esac

echo "PASS: intensity-recommend.sh outputs all required key=value fields with valid values"
```

**scripts/verify/m008-p01-recommend-capabilities.sh:**

```bash
#!/usr/bin/env bash
# Verifies intensity-recommend.sh factors capabilities into its recommendation.
# Full intensity with low cap_score should have reduced confidence.
set -eu

f="scripts/engine/intensity-recommend.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# Full intensity + lean environment -> confidence should be medium
analyze_full="scope=large
risk_level=high
complexity=complex
risk_signals=migration_detected
recommended_intensity=Full"

profile_lean="cap_execution=local
cap_graph=false
cap_mcp=false
cap_ci=false
cap_subagent=false
cap_score=0"

output_lean="$(bash "$f" --analyze-output "$analyze_full" --profile-output "$profile_lean" 2>/dev/null)"
conf_lean="$(echo "$output_lean" | grep "^confidence=" | cut -d= -f2)"

if [[ "$conf_lean" != "medium" ]]; then
  echo "FAIL: Full intensity with cap_score=0 should have confidence=medium, got $conf_lean"; exit 1
fi

# Full intensity + rich environment -> confidence should be high
profile_rich="cap_execution=ci
cap_graph=true
cap_mcp=true
cap_ci=true
cap_subagent=true
cap_score=5"

output_rich="$(bash "$f" --analyze-output "$analyze_full" --profile-output "$profile_rich" 2>/dev/null)"
conf_rich="$(echo "$output_rich" | grep "^confidence=" | cut -d= -f2)"

if [[ "$conf_rich" != "high" ]]; then
  echo "FAIL: Full intensity with cap_score=5 should have confidence=high, got $conf_rich"; exit 1
fi

echo "PASS: intensity-recommend.sh factors capabilities into confidence (lean=medium, rich=high)"
```

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "intensity-recommend.sh combines analyze output + capability profile
  and produces intensity, confidence, and reasoning as key=value pairs" and
  "intensity-recommend.sh factors detected capabilities into its recommendation".
- **Artifacts**: `scripts/engine/intensity-recommend.sh`, two verification scripts.

## Verification

Run each verification script standalone:

```bash
bash scripts/verify/m008-p01-recommend-output-format.sh
bash scripts/verify/m008-p01-recommend-capabilities.sh
```

Both should print PASS lines and exit 0.

Additionally, test the full pipeline manually:

```bash
# Run analyze + recommend together via --description
bash scripts/engine/intensity-recommend.sh --description "Fix a typo in the README"
# Expected: intensity=Quick, confidence=high

bash scripts/engine/intensity-recommend.sh --description "Rewrite the authentication system with OAuth2 migration"
# Expected: intensity=Full, confidence=medium (in lean environment)
```

### Files Touched By This Task

- `scripts/engine/intensity-recommend.sh` (create)
- `scripts/verify/m008-p01-recommend-output-format.sh` (create)
- `scripts/verify/m008-p01-recommend-capabilities.sh` (create)

## Inputs

### From Previous Tasks

- **T01**: `scripts/dispatch/detect-capabilities.sh` with `--profile` flag.
  The profile output format is:
  ```
  cap_execution=local|ci
  cap_graph=true|false
  cap_mcp=true|false
  cap_ci=true|false
  cap_subagent=true|false
  cap_score=0..5
  ```

- **T02**: `scripts/engine/intensity-analyze.sh`. The analyze output format is:
  ```
  scope=trivial|moderate|large
  risk_level=low|medium|high
  complexity=simple|moderate|complex
  risk_signals=signal1,signal2,...  (or "none")
  recommended_intensity=Quick|Standard|Full
  ```

### From Disk (Pre-existing)

- `scripts/engine/` directory -- the new script lives here alongside
  checkpoint.sh, run.sh, and intensity-analyze.sh (from T02).

## Constraints

- Bash 3.2 compatible -- no associative arrays, no readarray, no `|&`.
- The recommendation engine may escalate intensity (Quick -> Standard -> Full)
  but NEVER downgrades. Risk overrides convenience.
- The `--analyze-output` and `--profile-output` flags accept pre-computed output
  to avoid redundant script execution (important for testing and when the caller
  has already gathered the data).
- Exit 0 on success, 1 only on error (no description, missing scripts).

## Expected Output

After completing this task:

1. `scripts/engine/intensity-recommend.sh` exists, is chmod +x, ~120+ lines.
2. Providing a Standard analyze output with cap_score=0 produces intensity=Standard,
   confidence=high (lean environment doesn't reduce confidence for Standard).
3. Providing a Full analyze output with cap_score=0 produces intensity=Full,
   confidence=medium (Full in lean environment gets reduced confidence).
4. Providing a Full analyze output with cap_score=5 produces intensity=Full,
   confidence=high.
5. Risk escalation works: analyze output with risk_level=high and base Quick
   gets escalated to at least Standard.
6. Both verification scripts print PASS and exit 0.
7. `git status` shows 3 new files.

## State Context

- **Current State**: executing
- **Milestone**: M008
- **Phase**: P01
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