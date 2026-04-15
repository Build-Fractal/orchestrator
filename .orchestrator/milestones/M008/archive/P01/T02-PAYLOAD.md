---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T02 (Phase P01, Milestone M008)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (25 entries) | 19-588 | ~4800 | filtered |
| Decisions | 590-592 | ~100 | filtered |
| Constraints | 594-599 | ~100 | required |
| Scope | 601-629 | ~400 | required |
| Upstream Context | 631-633 | ~100 | required |
| Task Plan | 635-1111 | ~4300 | required |
| State Context | 1113-1119 | ~100 | required |
| **Total** | | **~9900** | |

## Knowledge

<!-- 25 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 2
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
hit_count: 2
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
hit_count: 2
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
hit_count: 2
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
hit_count: 1
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
hit_count: 1
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
hit_count: 1
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
hit_count: 2
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
hit_count: 1
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
hit_count: 1
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
hit_count: 1
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
hit_count: 2
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
hit_count: 2
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
hit_count: 2
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
hit_count: 1
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
hit_count: 1
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
hit_count: 1
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
hit_count: 2
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
hit_count: 1
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
hit_count: 1
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
hit_count: 2
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
hit_count: 2
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
hit_count: 1
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
hit_count: 1
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
hit_count: 1
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
task: "T02"
phase: "P01"
milestone: "M008"
name: "Create intensity-analyze.sh -- scope/risk/complexity analyzer"
depends_on: []
---

## Prerequisites

- `scripts/engine/` directory exists (contains checkpoint.sh, run.sh, test-resume.sh from prior milestones).
- No external dependencies beyond Bash 3.2 and standard Unix tools (grep, sed, awk, wc).

## Description

Create `scripts/engine/intensity-analyze.sh` that accepts a natural-language
task description and analyzes it for scope markers, risk signals, and complexity
indicators. The script uses pattern matching on the description text to classify
the task along three axes (scope, risk, complexity) and produces a recommended
intensity level.

### Analysis Model

**Scope classification** (how big is the task?):
- `trivial` -- single file, typo fix, small config change, one-liner, rename
- `moderate` -- multi-file feature, new component, refactor, API change
- `large` -- platform build, architecture change, multi-component system, migration

Scope detection uses keyword/phrase pattern matching:

| Scope | Trigger Patterns |
|-------|-----------------|
| trivial | "typo", "fix typo", "rename", "one-line", "single file", "config change", "update comment", "fix whitespace", "bump version", "small fix", "minor", "tweak" |
| large | "platform", "architecture", "migration", "multi-component", "redesign", "rewrite", "system", "infrastructure", "framework", "cross-cutting", "milestone", "epic" |
| moderate | default (neither trivial nor large patterns matched) |

**Risk classification** (how dangerous is the task?):
- `low` -- documentation, tests, comments, formatting
- `medium` -- new files, feature additions, non-critical refactors
- `high` -- auth/security changes, database migrations, dependency updates, CI/CD changes, payment/billing, API breaking changes

Risk detection uses path and keyword patterns:

| Risk | Trigger Patterns |
|------|-----------------|
| high | "auth", "security", "password", "token", "secret", "credential", "migration", "database", "schema", "payment", "billing", "breaking change", "API break", "deploy", "production", ".env", "Dockerfile", "docker-compose", paths containing "auth/", "security/", "middleware/" |
| low | "doc", "readme", "comment", "test", "spec", "typo", "whitespace", "format", "lint" |
| medium | default |

**Complexity classification** (how many moving parts?):
- `simple` -- single concern, isolated change
- `moderate` -- 2-3 concerns, some coordination
- `complex` -- 4+ concerns, cross-cutting, new abstractions

Complexity detection:

| Complexity | Trigger Patterns |
|------------|-----------------|
| complex | "cross-cutting", "abstraction", "interface", "adapter", "plugin", "extension point", "multi-", "distributed", "concurrent", "async", "parallel", 3+ distinct file path references |
| simple | scope=trivial AND risk=low |
| moderate | default |

**Recommended intensity** (decision logic):
- `Quick` -- scope=trivial AND risk!=high AND complexity=simple
- `Full` -- scope=large OR risk=high OR complexity=complex
- `Standard` -- everything else

**Risk signal collection**: The script collects individual risk signals (specific
matches) into a comma-separated list for transparency. Examples:
"auth_keyword_detected", "migration_keyword_detected",
"dependency_file_referenced", "security_path_detected".

### Interface

```
Usage: intensity-analyze.sh [--description "text"] [--file path]
  --description: task description as a string argument
  --file:        path to a file containing the task description
  If neither flag is given, reads from stdin.

Output (to stdout, key=value format):
  scope=trivial|moderate|large
  risk_level=low|medium|high
  complexity=simple|moderate|complex
  risk_signals=signal1,signal2,... (or "none")
  recommended_intensity=Quick|Standard|Full

Exit: 0 on success, 1 if no description provided
```

## Steps

### Step 1 -- Create `scripts/engine/intensity-analyze.sh`

Create the file with the following content:

```bash
#!/usr/bin/env bash
# scripts/engine/intensity-analyze.sh — Scope/risk/complexity analyzer for adaptive intensity.
# Reads a natural-language task description and outputs an intensity recommendation
# with structured reasoning. Part of the M008 Adaptive Intensity Engine (FR-001, FR-005).
#
# Usage: intensity-analyze.sh [--description "text"] [--file path]
#   --description: task description as a string argument
#   --file:        path to a file containing the task description
#   If neither flag is given, reads from stdin.
#
# Output (stdout, key=value):
#   scope=trivial|moderate|large
#   risk_level=low|medium|high
#   complexity=simple|moderate|complex
#   risk_signals=signal1,signal2,...  (or "none")
#   recommended_intensity=Quick|Standard|Full
#
# Exit: 0 success, 1 if no description provided.
# Bash 3.2 compatible (NFR-200). No associative arrays.

set -euo pipefail

DESCRIPTION=""

# --- Argument parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --description)
      DESCRIPTION="$2"; shift 2 ;;
    --file)
      if [[ ! -f "$2" ]]; then
        echo "ERROR: file not found: $2" >&2
        exit 1
      fi
      DESCRIPTION="$(cat "$2")"; shift 2 ;;
    *)
      shift ;;
  esac
done

# Read from stdin if no --description or --file
if [[ -z "$DESCRIPTION" ]]; then
  if [[ -t 0 ]]; then
    echo "ERROR: no description provided. Use --description, --file, or pipe via stdin." >&2
    exit 1
  fi
  DESCRIPTION="$(cat)"
fi

if [[ -z "$DESCRIPTION" ]]; then
  echo "ERROR: empty description" >&2
  exit 1
fi

# Lowercase the description for case-insensitive matching
desc_lower="$(printf '%s' "$DESCRIPTION" | tr '[:upper:]' '[:lower:]')"

# --- Scope classification ---
scope="moderate"

# Check trivial patterns
trivial_match=false
for pattern in "typo" "fix typo" "rename" "one-line" "one line" "single file" "config change" "update comment" "fix whitespace" "bump version" "small fix" "minor fix" "minor tweak" "tweak" "nit" "spelling"; do
  if echo "$desc_lower" | grep -qF "$pattern"; then
    trivial_match=true
    break
  fi
done

# Check large patterns
large_match=false
for pattern in "platform" "architecture" "migration" "multi-component" "redesign" "rewrite" "system-wide" "infrastructure" "framework" "cross-cutting" "milestone" "epic" "overhaul" "rebuild" "greenfield" "from scratch"; do
  if echo "$desc_lower" | grep -qF "$pattern"; then
    large_match=true
    break
  fi
done

if [[ "$trivial_match" = true ]] && [[ "$large_match" = false ]]; then
  scope="trivial"
elif [[ "$large_match" = true ]]; then
  scope="large"
fi

# --- Risk classification ---
risk_level="medium"
# Collect individual risk signals using parallel indexed arrays (bash 3.2 safe)
risk_signal_count=0

# High-risk keyword patterns
for pattern in "auth" "security" "password" "token" "secret" "credential" "migration" "database migration" "schema change" "payment" "billing" "breaking change" "api break" "deploy to prod" "production deploy" "\.env" "dockerfile" "docker-compose"; do
  if echo "$desc_lower" | grep -qF "$pattern"; then
    eval "risk_signal_${risk_signal_count}=\"${pattern}_detected\""
    risk_signal_count=$((risk_signal_count + 1))
  fi
done

# High-risk path patterns
for pattern in "auth/" "security/" "middleware/" "migrations/"; do
  if echo "$desc_lower" | grep -qF "$pattern"; then
    eval "risk_signal_${risk_signal_count}=\"path_${pattern%%/*}_detected\""
    risk_signal_count=$((risk_signal_count + 1))
  fi
done

# Dependency file references
for pattern in "package.json" "requirements.txt" "cargo.toml" "go.mod" "gemfile" "pom.xml" "build.gradle"; do
  if echo "$desc_lower" | grep -qiF "$pattern"; then
    eval "risk_signal_${risk_signal_count}=\"dependency_file_referenced\""
    risk_signal_count=$((risk_signal_count + 1))
    break
  fi
done

# Low-risk patterns (only if no high-risk signals found)
low_risk_match=false
if [[ "$risk_signal_count" -eq 0 ]]; then
  for pattern in "documentation" "readme" "comment" "test file" "add test" "spec file" "whitespace" "formatting" "lint fix"; do
    if echo "$desc_lower" | grep -qF "$pattern"; then
      low_risk_match=true
      break
    fi
  done
fi

if [[ "$risk_signal_count" -gt 0 ]]; then
  risk_level="high"
elif [[ "$low_risk_match" = true ]]; then
  risk_level="low"
fi

# Build risk_signals string
risk_signals="none"
if [[ "$risk_signal_count" -gt 0 ]]; then
  risk_signals=""
  i=0
  while [[ "$i" -lt "$risk_signal_count" ]]; do
    eval "sig=\"\$risk_signal_${i}\""
    if [[ -n "$risk_signals" ]]; then
      risk_signals="${risk_signals},${sig}"
    else
      risk_signals="$sig"
    fi
    i=$((i + 1))
  done
fi

# --- Complexity classification ---
complexity="moderate"

# Check complex patterns
complex_match=false
for pattern in "cross-cutting" "abstraction" "new interface" "adapter" "plugin" "extension point" "multi-service" "distributed" "concurrent" "async" "parallel" "event-driven"; do
  if echo "$desc_lower" | grep -qF "$pattern"; then
    complex_match=true
    break
  fi
done

if [[ "$complex_match" = true ]]; then
  complexity="complex"
elif [[ "$scope" = "trivial" ]] && [[ "$risk_level" = "low" ]]; then
  complexity="simple"
fi

# --- Recommended intensity ---
recommended_intensity="Standard"

if [[ "$scope" = "trivial" ]] && [[ "$risk_level" != "high" ]] && [[ "$complexity" = "simple" ]]; then
  recommended_intensity="Quick"
elif [[ "$scope" = "large" ]] || [[ "$risk_level" = "high" ]] || [[ "$complexity" = "complex" ]]; then
  recommended_intensity="Full"
fi

# --- Output ---
echo "scope=$scope"
echo "risk_level=$risk_level"
echo "complexity=$complexity"
echo "risk_signals=$risk_signals"
echo "recommended_intensity=$recommended_intensity"
```

Make executable:

```bash
chmod +x scripts/engine/intensity-analyze.sh
```

### Step 2 -- Create verification scripts

Create three verification scripts.

**scripts/verify/m008-p01-analyze-output-format.sh:**

```bash
#!/usr/bin/env bash
# Verifies intensity-analyze.sh outputs all required key=value fields.
set -eu

f="scripts/engine/intensity-analyze.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }

output="$(echo "Add a new user authentication module with OAuth2 support" | bash "$f" 2>/dev/null)"

echo "$output" | grep -q "^scope=" || { echo "FAIL: output missing scope="; exit 1; }
echo "$output" | grep -q "^risk_level=" || { echo "FAIL: output missing risk_level="; exit 1; }
echo "$output" | grep -q "^complexity=" || { echo "FAIL: output missing complexity="; exit 1; }
echo "$output" | grep -q "^risk_signals=" || { echo "FAIL: output missing risk_signals="; exit 1; }
echo "$output" | grep -q "^recommended_intensity=" || { echo "FAIL: output missing recommended_intensity="; exit 1; }

# Verify scope is a valid value
scope_val="$(echo "$output" | grep "^scope=" | cut -d= -f2)"
case "$scope_val" in
  trivial|moderate|large) ;;
  *) echo "FAIL: scope='$scope_val' is not trivial|moderate|large"; exit 1 ;;
esac

# Verify recommended_intensity is a valid value
intensity_val="$(echo "$output" | grep "^recommended_intensity=" | cut -d= -f2)"
case "$intensity_val" in
  Quick|Standard|Full) ;;
  *) echo "FAIL: recommended_intensity='$intensity_val' is not Quick|Standard|Full"; exit 1 ;;
esac

echo "PASS: intensity-analyze.sh outputs all required key=value fields with valid values"
```

**scripts/verify/m008-p01-analyze-trivial.sh:**

```bash
#!/usr/bin/env bash
# Verifies intensity-analyze.sh classifies a trivial task as scope=trivial, intensity=Quick.
set -eu

f="scripts/engine/intensity-analyze.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

output="$(echo "Fix typo in README.md" | bash "$f" 2>/dev/null)"

scope_val="$(echo "$output" | grep "^scope=" | cut -d= -f2)"
intensity_val="$(echo "$output" | grep "^recommended_intensity=" | cut -d= -f2)"

if [[ "$scope_val" != "trivial" ]]; then
  echo "FAIL: 'Fix typo in README.md' classified as scope=$scope_val, expected trivial"; exit 1
fi
if [[ "$intensity_val" != "Quick" ]]; then
  echo "FAIL: 'Fix typo in README.md' classified as intensity=$intensity_val, expected Quick"; exit 1
fi

echo "PASS: trivial task correctly classified as scope=trivial, recommended_intensity=Quick"
```

**scripts/verify/m008-p01-analyze-moderate.sh:**

```bash
#!/usr/bin/env bash
# Verifies intensity-analyze.sh classifies a multi-component feature as scope=moderate, intensity=Standard.
set -eu

f="scripts/engine/intensity-analyze.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

output="$(echo "Add a new API endpoint for user profile updates with validation and error handling" | bash "$f" 2>/dev/null)"

scope_val="$(echo "$output" | grep "^scope=" | cut -d= -f2)"
intensity_val="$(echo "$output" | grep "^recommended_intensity=" | cut -d= -f2)"

if [[ "$scope_val" != "moderate" ]]; then
  echo "FAIL: multi-component feature classified as scope=$scope_val, expected moderate"; exit 1
fi
if [[ "$intensity_val" != "Standard" ]]; then
  echo "FAIL: multi-component feature classified as intensity=$intensity_val, expected Standard"; exit 1
fi

echo "PASS: moderate task correctly classified as scope=moderate, recommended_intensity=Standard"
```

**scripts/verify/m008-p01-analyze-risk-escalation.sh:**

```bash
#!/usr/bin/env bash
# Verifies intensity-analyze.sh detects risk signals and escalates intensity.
set -eu

f="scripts/engine/intensity-analyze.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# A small change to auth code should escalate to Full due to risk
output="$(echo "Update the auth middleware to fix a token validation bug" | bash "$f" 2>/dev/null)"

risk_val="$(echo "$output" | grep "^risk_level=" | cut -d= -f2)"
signals_val="$(echo "$output" | grep "^risk_signals=" | cut -d= -f2)"
intensity_val="$(echo "$output" | grep "^recommended_intensity=" | cut -d= -f2)"

if [[ "$risk_val" != "high" ]]; then
  echo "FAIL: auth-related task has risk_level=$risk_val, expected high"; exit 1
fi
if [[ "$signals_val" = "none" ]]; then
  echo "FAIL: auth-related task has risk_signals=none, expected at least one signal"; exit 1
fi
if [[ "$intensity_val" != "Full" ]]; then
  echo "FAIL: high-risk task has intensity=$intensity_val, expected Full"; exit 1
fi

echo "PASS: auth-related task correctly escalated to risk_level=high, recommended_intensity=Full"
```

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "intensity-analyze.sh accepts a task description and outputs scope,
  risk_level, complexity, risk_signals, and recommended_intensity",
  "intensity-analyze.sh classifies a trivial single-file fix as scope=trivial
  with recommended_intensity=Quick", "intensity-analyze.sh classifies a
  multi-component feature as scope=moderate with recommended_intensity=Standard",
  "intensity-analyze.sh detects risk signals and escalates intensity".
- **Artifacts**: `scripts/engine/intensity-analyze.sh`, three verification scripts.

## Verification

Run each verification script standalone:

```bash
bash scripts/verify/m008-p01-analyze-output-format.sh
bash scripts/verify/m008-p01-analyze-trivial.sh
bash scripts/verify/m008-p01-analyze-moderate.sh
bash scripts/verify/m008-p01-analyze-risk-escalation.sh
```

All four should print PASS lines and exit 0.

### Files Touched By This Task

- `scripts/engine/intensity-analyze.sh` (create)
- `scripts/verify/m008-p01-analyze-output-format.sh` (create)
- `scripts/verify/m008-p01-analyze-trivial.sh` (create)
- `scripts/verify/m008-p01-analyze-moderate.sh` (create)
- `scripts/verify/m008-p01-analyze-risk-escalation.sh` (create)

## Inputs

### From Previous Tasks

None -- T02 is independent.

### From Disk (Pre-existing)

- `scripts/engine/` directory exists with checkpoint.sh, run.sh, test-resume.sh.
  The new script follows the same directory convention.

## Constraints

- Bash 3.2 compatible -- no associative arrays, no readarray, no `|&`.
- Pattern matching must be case-insensitive (use `tr '[:upper:]' '[:lower:]'`).
- Risk signals stored using parallel indexed arrays (`risk_signal_0`, `risk_signal_1`, etc.)
  -- the Bash 3.2-safe pattern established in MEM001.
- Exit 0 on success, 1 only if no description is provided.
- All output to stdout as key=value pairs. Errors to stderr.

## Expected Output

After completing this task:

1. `scripts/engine/intensity-analyze.sh` exists, is chmod +x, ~150+ lines.
2. `echo "Fix typo in README" | bash scripts/engine/intensity-analyze.sh` outputs
   `scope=trivial`, `risk_level=low`, `complexity=simple`, `risk_signals=none`,
   `recommended_intensity=Quick`.
3. `echo "Add new API endpoint with validation" | bash scripts/engine/intensity-analyze.sh`
   outputs `scope=moderate`, `recommended_intensity=Standard`.
4. `echo "Rewrite the auth middleware" | bash scripts/engine/intensity-analyze.sh`
   outputs `risk_level=high`, `recommended_intensity=Full`, and risk_signals
   includes at least one signal.
5. All four verification scripts print PASS and exit 0.
6. `git status` shows 5 new files.

## State Context

- **Current State**: executing
- **Milestone**: M008
- **Phase**: P01
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