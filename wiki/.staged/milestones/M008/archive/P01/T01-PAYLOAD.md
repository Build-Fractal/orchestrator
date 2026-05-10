---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T01 (Phase P01, Milestone M008)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (25 entries) | 19-588 | ~4800 | filtered |
| Decisions | 590-592 | ~100 | filtered |
| Constraints | 594-599 | ~100 | required |
| Scope | 601-629 | ~400 | required |
| Upstream Context | 631-633 | ~100 | required |
| Task Plan | 635-1016 | ~3400 | required |
| State Context | 1018-1024 | ~100 | required |
| **Total** | | **~9000** | |

## Knowledge

<!-- 25 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 1
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
hit_count: 1
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
hit_count: 1
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
hit_count: 1
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
hit_count: 0
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
hit_count: 0
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
hit_count: 0
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
hit_count: 1
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
hit_count: 0
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
hit_count: 0
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
hit_count: 0
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
hit_count: 1
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
hit_count: 1
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
hit_count: 1
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
hit_count: 0
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
hit_count: 0
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
hit_count: 0
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
hit_count: 1
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
hit_count: 0
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
hit_count: 0
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
hit_count: 1
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
hit_count: 1
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
hit_count: 0
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
hit_count: 0
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
hit_count: 0
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
task: "T01"
phase: "P01"
milestone: "M008"
name: "Refactor detect-capabilities.sh -- add graph DB, MCP, CI detection + --profile flag"
depends_on: []
---

## Prerequisites

- `scripts/dispatch/detect-capabilities.sh` exists (119 lines, committed on main).
- `sqlite3` CLI available on macOS as `/usr/bin/sqlite3`.

## Description

Extend `scripts/dispatch/detect-capabilities.sh` to detect three new environment
capabilities and add a `--profile` output mode for the intensity recommendation
engine. The three new capabilities are:

1. **graph_db** -- checks whether sqlite3 is available AND the project has a
   `.specify/orchestrator/knowledge.db` or `.orchestrator/knowledge.db` file
   (the SQLite graph backend from [M007](../../../../milestones/M007/index.md)).
2. **mcp_servers** -- checks whether an MCP configuration file exists at any
   of: `.claude/mcp_servers.json`, `.cursor/mcp.json`, `mcp.json`, or the
   `MCP_CONFIG` environment variable points to a file.
3. **ci_pipeline** -- checks whether CI configuration files exist:
   `.github/workflows/` directory, `.gitlab-ci.yml`, `.circleci/config.yml`,
   `Jenkinsfile`, or `.buildkite/pipeline.yml`.

All existing output fields (subagent_dispatch, agent_tool_available,
shell_execution, git_available, git_worktree, github_actions, runtime,
host_claude_code, host_cursor, host_copilot) must be preserved unchanged.

The new `--profile` flag outputs a high-level capability summary as key=value
pairs designed for consumption by `intensity-recommend.sh`:
- `cap_execution=local|ci` (derived from runtime)
- `cap_graph=true|false` (from graph_db)
- `cap_mcp=true|false` (from mcp_servers)
- `cap_ci=true|false` (from ci_pipeline)
- `cap_subagent=true|false` (from subagent_dispatch)
- `cap_score=0..5` (count of true capabilities -- higher = richer environment)

## Steps

### Step 1 -- Add new capability detection to detect-capabilities.sh

Open `scripts/dispatch/detect-capabilities.sh`. Insert the following detection
blocks AFTER the existing `host_copilot` detection (line ~89) and BEFORE the
`# --- Output ---` section (line ~92).

Add this code between the last detection block and the output section:

```bash
# graph_db: check for sqlite3 AND a knowledge graph database file
graph_db=false
if command -v sqlite3 >/dev/null 2>&1; then
  if [[ -f .specify/orchestrator/knowledge.db ]] || [[ -f .orchestrator/knowledge.db ]]; then
    graph_db=true
  fi
fi

# mcp_servers: check for MCP configuration files
mcp_servers=false
if [[ -f .claude/mcp_servers.json ]] || [[ -f .cursor/mcp.json ]] || [[ -f mcp.json ]]; then
  mcp_servers=true
elif [[ -n "${MCP_CONFIG:-}" ]] && [[ -f "${MCP_CONFIG}" ]]; then
  mcp_servers=true
fi

# ci_pipeline: check for CI configuration files
ci_pipeline=false
if [[ -d .github/workflows ]] || [[ -f .gitlab-ci.yml ]] || [[ -f .circleci/config.yml ]] || [[ -f Jenkinsfile ]] || [[ -f .buildkite/pipeline.yml ]]; then
  ci_pipeline=true
fi
```

### Step 2 -- Update the --format argument parsing to accept --profile

Modify the argument parsing section (lines ~15-22) to also accept `--profile`:

Replace the existing argument parsing block:

```bash
FORMAT="text"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)
      FORMAT="$2"; shift 2 ;;
    *)
      shift ;;
  esac
done
```

With:

```bash
FORMAT="text"
PROFILE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)
      FORMAT="$2"; shift 2 ;;
    --profile)
      PROFILE=true; shift ;;
    *)
      shift ;;
  esac
done
```

### Step 3 -- Add the --profile output mode

Replace the entire `# --- Output ---` section with:

```bash
# --- Output ---

if [[ "$PROFILE" = true ]]; then
  # Profile mode: high-level summary for intensity recommendation engine
  cap_execution="local"
  if [[ "$runtime" != "local" ]]; then
    cap_execution="ci"
  fi
  cap_graph="$graph_db"
  cap_mcp="$mcp_servers"
  cap_ci="$ci_pipeline"
  cap_subagent="$subagent_dispatch"

  # Count true capabilities for an aggregate score (0..5)
  cap_score=0
  [[ "$cap_graph" = true ]] && cap_score=$((cap_score + 1))
  [[ "$cap_mcp" = true ]] && cap_score=$((cap_score + 1))
  [[ "$cap_ci" = true ]] && cap_score=$((cap_score + 1))
  [[ "$cap_subagent" = true ]] && cap_score=$((cap_score + 1))
  [[ "$cap_execution" = "ci" ]] && cap_score=$((cap_score + 1))

  echo "cap_execution=$cap_execution"
  echo "cap_graph=$cap_graph"
  echo "cap_mcp=$cap_mcp"
  echo "cap_ci=$cap_ci"
  echo "cap_subagent=$cap_subagent"
  echo "cap_score=$cap_score"
elif [[ "$FORMAT" = "json" ]]; then
  cat <<EOF
{
  "subagent_dispatch": $subagent_dispatch,
  "agent_tool_available": $agent_tool_available,
  "shell_execution": $shell_execution,
  "git_available": $git_available,
  "git_worktree": $git_worktree,
  "github_actions": $github_actions,
  "runtime": "$runtime",
  "host_claude_code": $host_claude_code,
  "host_cursor": $host_cursor,
  "host_copilot": $host_copilot,
  "graph_db": $graph_db,
  "mcp_servers": $mcp_servers,
  "ci_pipeline": $ci_pipeline
}
EOF
else
  echo "subagent_dispatch=$subagent_dispatch"
  echo "agent_tool_available=$agent_tool_available"
  echo "shell_execution=$shell_execution"
  echo "git_available=$git_available"
  echo "git_worktree=$git_worktree"
  echo "github_actions=$github_actions"
  echo "runtime=$runtime"
  echo "host_claude_code=$host_claude_code"
  echo "host_cursor=$host_cursor"
  echo "host_copilot=$host_copilot"
  echo "graph_db=$graph_db"
  echo "mcp_servers=$mcp_servers"
  echo "ci_pipeline=$ci_pipeline"
fi
```

### Step 4 -- Update the script header comment

Update the header comment at the top of the file to document the new
capabilities and the `--profile` flag:

Replace:

```bash
# scripts/dispatch/detect-capabilities.sh — Detect runtime capabilities
# Reports available capabilities for graceful degradation across agent runtimes (R008).
#
# Usage: detect-capabilities.sh [--format json|text]
#   --format: output format (default: text — key=value lines)
#
# Always exits 0 (capability detection never fails — unknown capabilities default to false).
```

With:

```bash
# scripts/dispatch/detect-capabilities.sh — Detect runtime and environment capabilities
# Reports available capabilities for graceful degradation across agent runtimes (R008)
# and environment-aware intensity recommendation (FR-024, FR-025, FR-026).
#
# Usage: detect-capabilities.sh [--format json|text] [--profile]
#   --format:  output format (default: text — key=value lines)
#   --profile: output high-level capability summary for intensity recommendation
#
# Capabilities detected:
#   subagent_dispatch   — can dispatch to sub-agents
#   agent_tool_available — in-process agent tools (override via SPECKIT_AGENT_TOOL=1)
#   shell_execution     — always true (running in bash)
#   git_available       — git CLI present
#   git_worktree        — git worktree support
#   github_actions      — running in GitHub Actions
#   runtime             — local or ci-github
#   host_claude_code    — .claude directory present
#   host_cursor         — .cursor directory present
#   host_copilot        — .github/copilot directory present
#   graph_db            — sqlite3 + knowledge graph database present
#   mcp_servers         — MCP server configuration present
#   ci_pipeline         — CI/CD configuration files present
#
# Always exits 0 (capability detection never fails — unknown capabilities default to false).
```

### Step 5 -- Create verification scripts

Create two verification scripts.

**scripts/verify/m008-p01-capabilities-backward-compat.sh:**

```bash
#!/usr/bin/env bash
# Verifies detect-capabilities.sh preserves all original output fields and adds
# new graph_db, mcp_servers, ci_pipeline fields.
set -eu

f="scripts/dispatch/detect-capabilities.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# Check all original fields are still present in the script
for field in subagent_dispatch agent_tool_available shell_execution git_available git_worktree github_actions runtime host_claude_code host_cursor host_copilot; do
  grep -q "echo \"${field}=" "$f" || { echo "FAIL: $f missing original field $field in text output"; exit 1; }
done

# Check new fields are present
for field in graph_db mcp_servers ci_pipeline; do
  grep -q "$field=" "$f" || { echo "FAIL: $f missing new field $field"; exit 1; }
done

# Check JSON output includes new fields
grep -q '"graph_db"' "$f" || { echo "FAIL: $f missing graph_db in JSON output"; exit 1; }
grep -q '"mcp_servers"' "$f" || { echo "FAIL: $f missing mcp_servers in JSON output"; exit 1; }
grep -q '"ci_pipeline"' "$f" || { echo "FAIL: $f missing ci_pipeline in JSON output"; exit 1; }

# Run the script and verify output contains expected fields
output="$(bash "$f" 2>/dev/null)"
echo "$output" | grep -q "^subagent_dispatch=" || { echo "FAIL: text output missing subagent_dispatch"; exit 1; }
echo "$output" | grep -q "^graph_db=" || { echo "FAIL: text output missing graph_db"; exit 1; }
echo "$output" | grep -q "^mcp_servers=" || { echo "FAIL: text output missing mcp_servers"; exit 1; }
echo "$output" | grep -q "^ci_pipeline=" || { echo "FAIL: text output missing ci_pipeline"; exit 1; }

echo "PASS: detect-capabilities.sh preserves all original fields and adds graph_db, mcp_servers, ci_pipeline"
```

**scripts/verify/m008-p01-capabilities-profile.sh:**

```bash
#!/usr/bin/env bash
# Verifies detect-capabilities.sh --profile outputs capability summary.
set -eu

f="scripts/dispatch/detect-capabilities.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# Check --profile flag is handled
grep -q '\-\-profile' "$f" || { echo "FAIL: $f missing --profile flag handling"; exit 1; }

# Run with --profile and verify output format
output="$(bash "$f" --profile 2>/dev/null)"
echo "$output" | grep -q "^cap_execution=" || { echo "FAIL: profile output missing cap_execution"; exit 1; }
echo "$output" | grep -q "^cap_graph=" || { echo "FAIL: profile output missing cap_graph"; exit 1; }
echo "$output" | grep -q "^cap_mcp=" || { echo "FAIL: profile output missing cap_mcp"; exit 1; }
echo "$output" | grep -q "^cap_ci=" || { echo "FAIL: profile output missing cap_ci"; exit 1; }
echo "$output" | grep -q "^cap_subagent=" || { echo "FAIL: profile output missing cap_subagent"; exit 1; }
echo "$output" | grep -q "^cap_score=" || { echo "FAIL: profile output missing cap_score"; exit 1; }

# Verify cap_score is a number 0-5
score="$(echo "$output" | grep "^cap_score=" | cut -d= -f2)"
if ! echo "$score" | grep -qE '^[0-5]$'; then
  echo "FAIL: cap_score='$score' is not a number 0-5"; exit 1
fi

echo "PASS: detect-capabilities.sh --profile outputs valid capability summary"
```

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "detect-capabilities.sh adds graph_db, mcp_servers, and ci_pipeline
  detection while preserving all existing output fields" and
  "detect-capabilities.sh supports a --profile flag that outputs a capability
  summary suitable for intensity recommendation."
- **Artifacts**: `scripts/dispatch/detect-capabilities.sh` (modified),
  `scripts/verify/m008-p01-capabilities-backward-compat.sh`,
  `scripts/verify/m008-p01-capabilities-profile.sh`.

## Verification

Run each verification script standalone:

```bash
bash scripts/verify/m008-p01-capabilities-backward-compat.sh
bash scripts/verify/m008-p01-capabilities-profile.sh
```

Both should print PASS lines and exit 0.

Additionally, verify backward compatibility manually:

```bash
# Default text output should include all original + new fields
bash scripts/dispatch/detect-capabilities.sh

# JSON output should include new fields
bash scripts/dispatch/detect-capabilities.sh --format json

# Profile output should be a compact summary
bash scripts/dispatch/detect-capabilities.sh --profile
```

### Files Touched By This Task

- `scripts/dispatch/detect-capabilities.sh` (modify)
- `scripts/verify/m008-p01-capabilities-backward-compat.sh` (create)
- `scripts/verify/m008-p01-capabilities-profile.sh` (create)

## Inputs

### From Previous Tasks

None -- T01 is independent.

### From Disk (Pre-existing)

- `scripts/dispatch/detect-capabilities.sh` -- the existing 119-line capability
  detection script. Current capabilities detected: subagent_dispatch,
  agent_tool_available, shell_execution, git_available, git_worktree,
  github_actions, runtime, host_claude_code, host_cursor, host_copilot. Supports
  `--format json|text`. Always exits 0.

## Constraints

- Bash 3.2 compatible -- no associative arrays, no readarray, no `|&`.
- Must exit 0 always (capability detection never fails -- unknown capabilities
  default to false).
- Must not break existing callers that parse text or JSON output.
- New fields are appended after existing fields in both text and JSON formats.

## Expected Output

After completing this task:

1. `scripts/dispatch/detect-capabilities.sh` is extended to ~170+ lines.
2. Running `bash scripts/dispatch/detect-capabilities.sh` outputs all 13
   key=value pairs (10 original + 3 new: graph_db, mcp_servers, ci_pipeline).
3. Running `bash scripts/dispatch/detect-capabilities.sh --format json` outputs
   a JSON object with all 13 fields.
4. Running `bash scripts/dispatch/detect-capabilities.sh --profile` outputs 6
   key=value pairs: cap_execution, cap_graph, cap_mcp, cap_ci, cap_subagent,
   cap_score.
5. `bash scripts/verify/m008-p01-capabilities-backward-compat.sh` prints PASS.
6. `bash scripts/verify/m008-p01-capabilities-profile.sh` prints PASS.
7. `git status` shows 1 modified file + 2 new files.

## State Context

- **Current State**: executing
- **Milestone**: M008
- **Phase**: P01
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