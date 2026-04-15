---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T05 (Phase P01, Milestone M008)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (25 entries) | 19-588 | ~4800 | filtered |
| Decisions | 590-592 | ~100 | filtered |
| Constraints | 594-599 | ~100 | required |
| Scope | 601-629 | ~400 | required |
| Upstream Context | 631-633 | ~100 | required |
| Task Plan | 635-877 | ~2100 | required |
| State Context | 879-885 | ~100 | required |
| **Total** | | **~7700** | |

## Knowledge

<!-- 25 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 5
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
hit_count: 5
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
hit_count: 5
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
hit_count: 5
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
hit_count: 4
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
hit_count: 4
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
hit_count: 4
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
hit_count: 5
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
hit_count: 4
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
hit_count: 4
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
hit_count: 4
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
hit_count: 5
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
hit_count: 5
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
hit_count: 5
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
hit_count: 4
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
hit_count: 4
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
hit_count: 4
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
hit_count: 5
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
hit_count: 4
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
hit_count: 4
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
hit_count: 5
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
hit_count: 5
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
hit_count: 4
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
hit_count: 4
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
hit_count: 4
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
task: "T05"
phase: "P01"
milestone: "M008"
name: "Bash 3.2 compatibility check + integration smoke test"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

- T01 complete: `scripts/dispatch/detect-capabilities.sh` refactored with new capabilities and `--profile` flag.
- T02 complete: `scripts/engine/intensity-analyze.sh` exists and outputs structured analysis.
- T03 complete: `scripts/engine/intensity-recommend.sh` exists and combines analysis + capabilities.
- T04 complete: `templates/intensity-metadata.md` and `scripts/engine/context-pressure.sh` exist.
- All 9 verification scripts from T01-T04 pass.

## Description

Two deliverables:

1. **Bash 3.2 compatibility verification script** -- scans all new/modified
   scripts from P01 for Bash 3.2 incompatible constructs: `declare -A`
   (associative arrays), `readarray`/`mapfile`, `|&` (pipe stderr), `&>>`
   (append redirect), `${var,,}` or `${var^^}` (case modification), and
   `[[ $var =~ pattern ]]` with variable patterns (literal patterns are OK).
   This is the standard compatibility check used across all milestones.

2. **Integration smoke test** -- runs the full end-to-end intensity engine
   pipeline: detect capabilities -> analyze description -> recommend intensity.
   Verifies:
   - The pipeline produces valid output for three representative descriptions
     (trivial, moderate, large+risky)
   - All scripts exit 0
   - Output fields are present and have valid values
   - The recommendation engine correctly consumes analyzer and capability outputs
   - context-pressure.sh correctly evaluates a simulated payload

This task does NOT create new functionality -- it only verifies that T01-T04
deliverables work together correctly.

## Steps

### Step 1 -- Create `scripts/verify/m008-p01-bash32-compat.sh`

```bash
#!/usr/bin/env bash
# Verifies all P01 scripts are Bash 3.2 compatible.
# Checks for prohibited constructs: declare -A, readarray, mapfile, |&, &>>,
# ${var,,}, ${var^^}, variable regex patterns.
set -eu

fail_count=0
pass_count=0

check_file() {
  local f="$1"
  local bad=false

  # declare -A (associative arrays)
  if grep -nE 'declare\s+-A\b' "$f" >/dev/null 2>&1; then
    echo "FAIL: $f uses declare -A (associative arrays)"
    bad=true
  fi

  # readarray / mapfile
  if grep -nE '\b(readarray|mapfile)\b' "$f" >/dev/null 2>&1; then
    echo "FAIL: $f uses readarray/mapfile"
    bad=true
  fi

  # |& (pipe stderr)
  if grep -nE '\|\&' "$f" >/dev/null 2>&1; then
    echo "FAIL: $f uses |& (pipe stderr)"
    bad=true
  fi

  # &>> (append redirect both)
  if grep -nE '\&>>' "$f" >/dev/null 2>&1; then
    echo "FAIL: $f uses &>> (append redirect)"
    bad=true
  fi

  # ${var,,} or ${var^^} (case modification)
  if grep -nE '\$\{[a-zA-Z_][a-zA-Z0-9_]*(,,|^^)\}' "$f" >/dev/null 2>&1; then
    echo "FAIL: $f uses case modification syntax"
    bad=true
  fi

  if [[ "$bad" = true ]]; then
    fail_count=$((fail_count + 1))
  else
    pass_count=$((pass_count + 1))
  fi
}

# Check all P01 scripts
check_file "scripts/dispatch/detect-capabilities.sh"
check_file "scripts/engine/intensity-analyze.sh"
check_file "scripts/engine/intensity-recommend.sh"
check_file "scripts/engine/context-pressure.sh"

if [[ "$fail_count" -gt 0 ]]; then
  echo "FAIL: $fail_count file(s) have Bash 3.2 incompatible constructs"
  exit 1
fi

echo "PASS: all $pass_count P01 scripts are Bash 3.2 compatible"
```

### Step 2 -- Run the integration smoke test

This step is the verification for T05. It is performed by running all
verification scripts from T01-T04 plus the bash32 compat check, and then
performing three end-to-end pipeline tests.

The integration tests are embedded in the verification section below and
do not require a separate script file. However, for automated execution
via the orchestrator's verification system, we verify by running the
bash32-compat script which covers the cross-cutting concern.

The three end-to-end pipeline tests to run manually (or in a future
integration test script):

**Test A -- Trivial task:**
```bash
output="$(echo "Fix a typo in the README" | bash scripts/engine/intensity-recommend.sh 2>/dev/null)"
echo "$output" | grep -q "^intensity=Quick" || echo "FAIL: trivial should be Quick"
echo "$output" | grep -q "^confidence=high" || echo "FAIL: trivial should be high confidence"
```

**Test B -- Moderate task:**
```bash
output="$(echo "Add a new API endpoint for user profiles with validation" | bash scripts/engine/intensity-recommend.sh 2>/dev/null)"
echo "$output" | grep -q "^intensity=Standard" || echo "FAIL: moderate should be Standard"
```

**Test C -- Large + risky task:**
```bash
output="$(echo "Rewrite the authentication system with database migration and OAuth2 integration" | bash scripts/engine/intensity-recommend.sh 2>/dev/null)"
echo "$output" | grep -q "^intensity=Full" || echo "FAIL: large+risky should be Full"
echo "$output" | grep -q "^risk_signals=" || echo "FAIL: should have risk signals"
risk_signals="$(echo "$output" | grep "^risk_signals=" | cut -d= -f2-)"
test "$risk_signals" != "none" || echo "FAIL: risk signals should not be none"
```

**Test D -- Context pressure integration:**
```bash
output="$(bash scripts/engine/context-pressure.sh --tokens 5000 --intensity Quick 2>/dev/null)"
echo "$output" | grep -q "^pressure=low" || echo "FAIL: 5k tokens should be low pressure"
echo "$output" | grep -q "^action=proceed" || echo "FAIL: low pressure should proceed"
```

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "All scripts are Bash 3.2 compatible (no associative arrays, no
  readarray, no |&)."
- **Artifacts**: `scripts/verify/m008-p01-bash32-compat.sh`.

## Verification

Run the verification script:

```bash
bash scripts/verify/m008-p01-bash32-compat.sh
```

Should print PASS and exit 0.

Then run ALL phase P01 verification scripts to confirm everything passes:

```bash
bash scripts/verify/m008-p01-capabilities-backward-compat.sh
bash scripts/verify/m008-p01-capabilities-profile.sh
bash scripts/verify/m008-p01-analyze-output-format.sh
bash scripts/verify/m008-p01-analyze-trivial.sh
bash scripts/verify/m008-p01-analyze-moderate.sh
bash scripts/verify/m008-p01-analyze-risk-escalation.sh
bash scripts/verify/m008-p01-recommend-output-format.sh
bash scripts/verify/m008-p01-recommend-capabilities.sh
bash scripts/verify/m008-p01-metadata-template.sh
bash scripts/verify/m008-p01-context-pressure.sh
bash scripts/verify/m008-p01-bash32-compat.sh
```

All 11 should print PASS and exit 0.

### Files Touched By This Task

- `scripts/verify/m008-p01-bash32-compat.sh` (create)

## Inputs

### From Previous Tasks

- **T01**: `scripts/dispatch/detect-capabilities.sh` (modified) --
  `bash scripts/verify/m008-p01-capabilities-backward-compat.sh` and
  `bash scripts/verify/m008-p01-capabilities-profile.sh` must pass.

- **T02**: `scripts/engine/intensity-analyze.sh` (created) --
  `bash scripts/verify/m008-p01-analyze-output-format.sh`,
  `bash scripts/verify/m008-p01-analyze-trivial.sh`,
  `bash scripts/verify/m008-p01-analyze-moderate.sh`, and
  `bash scripts/verify/m008-p01-analyze-risk-escalation.sh` must pass.

- **T03**: `scripts/engine/intensity-recommend.sh` (created) --
  `bash scripts/verify/m008-p01-recommend-output-format.sh` and
  `bash scripts/verify/m008-p01-recommend-capabilities.sh` must pass.

- **T04**: `templates/intensity-metadata.md` and `scripts/engine/context-pressure.sh`
  (created) -- `bash scripts/verify/m008-p01-metadata-template.sh` and
  `bash scripts/verify/m008-p01-context-pressure.sh` must pass.

### From Disk (Pre-existing)

None beyond T01-T04 outputs.

## Constraints

- This task creates only ONE new file (the bash32-compat check script).
- The integration tests are manual verification steps, not additional scripts,
  to avoid speculative complexity (Constitution XIV).
- All 11 verification scripts from the phase must pass for P01 to be considered
  complete.

## Expected Output

After completing this task:

1. `scripts/verify/m008-p01-bash32-compat.sh` exists, ~50+ lines.
2. `bash scripts/verify/m008-p01-bash32-compat.sh` prints PASS -- all 4 P01
   scripts pass the Bash 3.2 compatibility check.
3. All 11 P01 verification scripts pass (PASS output, exit 0).
4. The end-to-end pipeline test confirms:
   - "Fix a typo in the README" -> Quick, high confidence
   - "Add a new API endpoint..." -> Standard
   - "Rewrite the authentication system..." -> Full with risk signals
5. `git status` shows 1 new file.

## State Context

- **Current State**: executing
- **Milestone**: M008
- **Phase**: P01
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