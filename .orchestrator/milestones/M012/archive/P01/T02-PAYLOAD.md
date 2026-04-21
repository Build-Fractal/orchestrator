---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T02 (Phase P01, Milestone M012)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (25 entries) | 20-589 | ~4900 | filtered |
| Decisions | 591-593 | ~100 | filtered |
| Constraints | 595-628 | ~400 | required |
| Scope | 630-658 | ~400 | required |
| Upstream Context | 660-662 | ~100 | required |
| Task Plan | 664-868 | ~2700 | required |
| State Context | 870-876 | ~100 | required |
| First-Turn Completeness | 878-927 | ~700 | required |
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
hit_count: 309
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
hit_count: 309
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
hit_count: 309
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
hit_count: 309
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
hit_count: 278
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
hit_count: 278
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
hit_count: 278
source_unit: "M005/P07"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: []
content_hash: ""
---

# MEM007: Autonomy Permission Pipeline

`generate-permissions.sh` introspects project toolchain (package.json, Makefile, config files, agent host markers) and emits canonical JSON. `write-permissions.sh` translates to `.claude/settings.json` with additive merge for user-authored files. `check-permissions.sh` detects permission drift. Policy is declarative in `autonomy-defaults.yaml` read via `recipe-parser.sh`.

AD-19 script-file verification shape: task plan Check: commands must use single-script invocations, not inline compound bash.

---
id: MEM008
scope_tags: "[project], [milestone:M001]"
category: patterns
confidence: 0.85
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 309
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
hit_count: 278
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
hit_count: 278
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
hit_count: 278
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
hit_count: 309
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
hit_count: 309
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
hit_count: 309
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
hit_count: 278
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
hit_count: 278
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
hit_count: 278
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
hit_count: 309
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
hit_count: 278
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
hit_count: 278
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
hit_count: 309
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
hit_count: 309
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
hit_count: 278
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
hit_count: 278
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
hit_count: 278
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

### Prohibited inline bash patterns

The following patterns trigger Claude Code safety prompts and MUST NOT
appear in Bash tool calls. See AP-004 in ANTIPATTERNS.md for details.

- **Command substitution**: Do not use $(cmd) or backtick substitution.
  Use --output-file flags or omit dynamic values (e.g., omit --completed_at).
- **Brace expansion**: Do not use {a,b} patterns.
  Pass explicit arguments instead.
- **Compound chains**: Do not chain commands with && || ; or pipes.
  Use wrapper scripts (e.g., bash scripts/verify/run-suite.sh).

### Allowed invocation shapes

When an inline bash shape would otherwise trigger a safety prompt, use one
of these canonical wrappers instead:

- `bash scripts/util/with-env.sh KEY=VALUE [KEY=VALUE ...] -- <command> [args ...]`
  -- Replaces `KEY=VALUE bash cmd` inline-assignment prefixes.
- `bash scripts/util/read-range.sh <file> <M> <N>`
  -- Replaces `sed -n 'M,Np' <file>` line-range reads.
- `bash scripts/util/run-probe.sh <path-to-staged-probe.sh>`
  -- Replaces `cat > /tmp/x.sh <<EOF ... EOF ; bash /tmp/x.sh` heredoc-and-execute.

A pre-Bash hook (`scripts/hooks/pre-bash-shape-guard.sh`) auto-rewrites six
common deviations from these shapes and hard-rejects four others with a
wrapper-pointing diagnostic. See ANTIPATTERNS.md AP-005..AP-009.

## Scope

### Goal


### Demo


### Must-Haves
## Must-Haves

<!-- Each truth is a behavioral statement + a single-script-file Check (AD-19).
     Every Check command is a single-invocation script-file shape — no inline
     compound bash, no plain subshells, no $() containing pipes, no process
     substitution. All M012/P01 verification logic lives inside
     scripts/verify/m012-p01-*.sh files; the Check commands here invoke them. -->

### Truths

- `wiki/` is a self-contained directory holding the full wiki toolchain — removing it does not break the orchestrator (SC-10, Constitution VI).
  - Check: `bash scripts/verify/m012-p01-wiki-self-contained.sh`

- `wiki/requirements.txt` pins exact versions for MkDocs, Material theme, and `mkdocs-include-markdown-plugin` (or the selected include-plugin equivalent) so deploys are reproducible (M012-CONTEXT constraint "MkDocs version pinned").
  - Check: `bash scripts/verify/m012-p01-requirements-pinned.sh`

- `wiki/mkdocs.yml` loads the include plugin and declares a Material theme with navigation enabled; every in-scope `.orchestrator/**.md` artifact has a corresponding stub under `wiki/docs/` that includes the canonical path via the plugin — never by copy (AD-3, SC-1).
  - Check: `bash scripts/verify/m012-p01-include-plugin.sh`

- No `.orchestrator/**.md` file is duplicated under `wiki/docs/` — every `.md` file in `wiki/docs/` is either the placeholder `index.md`, a thin include stub (fewer than 25 lines), or an auto-generated section index; no canonical artifact body lives in two places (AD-3, Constitution VI).

<dispatch-volatile>

## Upstream Context

No upstream summaries available.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M012"
name: "wiki-scan-sources.sh — in-scope artifact enumerator with exclusion policy"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `wiki/` skeleton and `scripts/wiki/wiki-serve.sh` exist.
- `.orchestrator/` tree is populated with real artifacts (constitution, DECISIONS.md, KNOWLEDGE.md, milestone-summary.md, multiple `milestones/M###/` directories, `archive/` directory).
- No stubs generated yet; no nav block exists in `wiki/mkdocs.yml`.

## Description

Ship `scripts/wiki/wiki-scan-sources.sh` — the single source of truth for "what counts as in-scope" for the wiki. Both T03 (stub generator) and T04 (nav generator) consume its output. This is the enforcement point for the exclusion policy (FR-8 + M012-ROADMAP Boundary Map + AD-4).

Output contract (printed to stdout, one record per line):

```
<category>|<relative-path-under-dot-orchestrator>|<display-title>
```

Where `<category>` is one of:

- `top:constitution` — `.orchestrator/memory/constitution.md`
- `top:decisions` — `.orchestrator/DECISIONS.md`
- `top:knowledge` — `.orchestrator/KNOWLEDGE.md`
- `top:milestone-summary` — `.orchestrator/milestone-summary.md`
- `milestone:<M###>` — every `.md` file under `.orchestrator/milestones/<M###>/` (including `phases/**/*.md` and `tasks/**/*.md`)
- `archive:<M###>` — every `.md` file under `.orchestrator/archive/<M###>/**`

Exclusion policy (lines that MUST NOT appear in scan output):

- Any path under `.orchestrator/scratch/`.
- Any path under `.orchestrator/tmp/`.
- Any path under `.orchestrator/config/`.
- Any non-`.md` file (`*.jsonl`, `*.txt`, `*.json`, `*.yml`, `*.yaml`, `VALIDATED` markers, lock files, etc.).
- `P##-PLANNING-PAYLOAD.md` — these are planning scratch, not durable artifacts. Exclude to keep the nav readable.
- `P##-VERIFICATION.md` — verification reports are machine output; exclude to keep the nav focused on plans/summaries. (Planning decision: reports land in execution-log analyses, not in the wiki body.)
- Any `.md` under `.orchestrator/milestones/M###/` or `.orchestrator/archive/` whose file-basename is `AGENTS.md` or `README.md` (if any appear — documentation internal to the orchestrator, not a milestone artifact).

`<display-title>`: derived from the first `# ` H1 line in the file, stripping Markdown. If no H1 exists, fall back to the basename without `.md` extension.

The scanner is read-only. Never writes to disk. Emits one line per in-scope artifact plus a trailing `SUMMARY: <N>` line on stderr for observability.

## Steps

1. **Create `scripts/wiki/wiki-scan-sources.sh`** with Bash 3.2 + pipes/awk/find permitted (MEM004 carve-out: this is emitter-internal, not agent-facing content).

   Shape:

   ```bash
   #!/usr/bin/env bash
   # scripts/wiki/wiki-scan-sources.sh — M012/P01 in-scope artifact enumerator.
   #
   # Prints one record per in-scope .orchestrator/**.md file to stdout:
   #   <category>|<relative-path-under-dot-orchestrator>|<display-title>
   #
   # Category enum:
   #   top:constitution
   #   top:decisions
   #   top:knowledge
   #   top:milestone-summary
   #   milestone:M###
   #   archive:M###
   #
   # Exclusion policy (hard-coded; see M012-ROADMAP Boundary Map + FR-8):
   #   .orchestrator/scratch/**         — transient
   #   .orchestrator/tmp/**             — transient
   #   .orchestrator/config/**          — config, not artifact
   #   any non-.md file                 — wiki is markdown-only
   #   P##-PLANNING-PAYLOAD.md          — planning scratch
   #   P##-VERIFICATION.md              — machine output
   #   AGENTS.md / README.md under milestone/archive trees
   #
   # Usage: bash scripts/wiki/wiki-scan-sources.sh [--root PROJECT_ROOT]
   # Exit 0 on success; 1 on unresolvable PROJECT_ROOT.
   # Bash 3.2 compatible.
   ```

2. **Resolve PROJECT_ROOT**: default to `$(cd "$(dirname "$0")/../.." && pwd)`; override with `--root <path>`.

3. **Scan order** (emit in this order so nav generators can assemble a stable list):
   1. `top:constitution` — check `$ROOT/.orchestrator/memory/constitution.md`; emit if present.
   2. `top:decisions` — check `$ROOT/.orchestrator/DECISIONS.md`; emit if present.
   3. `top:knowledge` — check `$ROOT/.orchestrator/KNOWLEDGE.md`; emit if present.
   4. `top:milestone-summary` — check `$ROOT/.orchestrator/milestone-summary.md`; emit if present.
   5. Milestones — iterate `$ROOT/.orchestrator/milestones/M*/` directories in lexical order; within each, emit the top-level `.md` files (alphabetical) then `phases/P*/` (lexical) with each phase's `.md` files then `phases/P*/tasks/T*/` `.md` files.
   6. Archive — iterate `$ROOT/.orchestrator/archive/M*/` directories in lexical order; same pattern as milestones.

4. **Find-then-filter** implementation:

   ```bash
   # Example filter: list every .md under a directory, apply exclusions.
   # Uses `find ... -type f -name '*.md'` then awk-based filtering.
   #
   # Exclusion enforcement MUST match the full relative path prefix, not
   # just the basename — so `.orchestrator/milestones/M001/scratch/foo.md`
   # would NOT be excluded (because scratch is only excluded at the top
   # level), but `.orchestrator/scratch/foo.md` would.
   ```

   Use `find "$dir" -type f -name '*.md'` piped into `sort` and then an awk filter:

   ```bash
   find "$ROOT/.orchestrator/milestones" -type f -name '*.md' 2>/dev/null \
     | sort \
     | awk -v ROOT_LEN=$((${#ROOT}+1)) '
         {
           rel = substr($0, ROOT_LEN+1)  # strip ROOT + "/"
           base = rel
           sub(/.*\//, "", base)
           if (base == "AGENTS.md") next
           if (base == "README.md") next
           if (base ~ /P[0-9]+-PLANNING-PAYLOAD\.md$/) next
           if (base ~ /P[0-9]+-VERIFICATION\.md$/) next
           print rel
         }'
   ```

   Apply the top-level exclusion check via a separate guard:

   ```bash
   # For scratch/tmp/config: reject paths whose first segment under
   # .orchestrator/ matches any of these three.
   # Implemented with a `case` match on the relative path.
   ```

5. **Title extraction**: for each selected file, read the first line that begins with `# ` (H1) and strip the leading `# `. If no such line exists, fall back to the basename without `.md`. Use `grep -m 1 '^# '` with a safe default:

   ```bash
   title=$(grep -m 1 '^# ' "$path" 2>/dev/null | sed 's/^# //' | head -n 1)
   if [ -z "$title" ]; then
     base=$(basename "$path" .md)
     title="$base"
   fi
   ```

6. **Milestone / archive category derivation**: extract the `M###` directory name by stripping the `.orchestrator/milestones/` or `.orchestrator/archive/` prefix and taking the first path segment. Example: `.orchestrator/milestones/M011/phases/P02/P02-PLAN.md` → `milestone:M011`.

7. **Emit** one line per file with `printf '%s|%s|%s\n' "$category" "$rel" "$title"`. Record count on stderr at end: `printf 'SUMMARY: %d in-scope artifacts\n' "$count" >&2`.

8. **Smoke-run** (manual, do not embed as a Check): `bash scripts/wiki/wiki-scan-sources.sh | head -n 20` — verify output shape and that M012's own `.md` files appear. `bash scripts/wiki/wiki-scan-sources.sh | grep '\.orchestrator/scratch'` must emit nothing.

## Must-Haves

- `scripts/wiki/wiki-scan-sources.sh` exists and is executable.
- Output schema is three pipe-separated fields: `<category>|<rel-path>|<title>`.
- No line in output contains `.orchestrator/scratch/`, `.orchestrator/tmp/`, or `.orchestrator/config/`.
- No line in output ends in anything other than `.md`.
- No line in output references `PLANNING-PAYLOAD`, `VERIFICATION`, `AGENTS.md`, or a basename `README.md` inside milestone / archive trees.
- Top-level artifacts emit before milestone artifacts; milestone artifacts emit before archive artifacts; within each group, lexical order.
- Bash 3.2 compatible — no `declare -A`, no `mapfile`, no `${var^^}`, no `<(...)`, no `&>`.
- Pure read-only (no writes under `$ROOT`).

## Verification

- `bash scripts/verify/m012-p01-exclusion-policy.sh` (ships in T05) — invokes the scanner, asserts no excluded path appears and no non-`.md` appears.
- `bash scripts/verify/m012-p01-bash32-compat.sh` (ships in T05) — scans this script for bash-3.2-incompatible constructs.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P01` — confirms artifact path + pattern after T05 seeds.

Manual smoke check during this task (run once; do NOT embed as a Check):

1. `bash scripts/wiki/wiki-scan-sources.sh | wc -l` — record the count. Expect well north of 50 for a populated repo.
2. `bash scripts/wiki/wiki-scan-sources.sh | awk -F'|' '{print $1}' | sort -u` — expect the seven category prefixes.
3. `bash scripts/wiki/wiki-scan-sources.sh | awk -F'|' '$3 == ""'` — expect no lines (every record must have a non-empty title).

## Inputs

### From Previous Tasks

- T01: `wiki/` skeleton exists so downstream scripts (T03, T04) have a stable target to write into. This task does not touch `wiki/` itself.

### From Disk (Pre-existing)

- `.orchestrator/memory/constitution.md`
- `.orchestrator/DECISIONS.md`
- `.orchestrator/KNOWLEDGE.md`
- `.orchestrator/milestone-summary.md`
- `.orchestrator/milestones/M###/` — many, each with `M###-*.md`, `phases/P##/P##-*.md`, `phases/P##/tasks/T##-*.md`.
- `.orchestrator/archive/M###/` — historical milestones.
- `.orchestrator/scratch/`, `.orchestrator/tmp/`, `.orchestrator/config/` — must be scanned but excluded.

## Constraints

- **Bash 3.2** — per MEM001. macOS baseline.
- **MEM004 carve-out** — this is a helper library, not agent-facing content; pipes, `$()`, `awk`, and `find` are permitted.
- **Read-only** — the scanner never writes under `$ROOT`. Any attempt to write fails review.
- **Stable output order** — top-level artifacts first, then milestones (lexical by `M###`), then archive (lexical by `M###`). Within a milestone: top-level `M###-*.md` (alphabetical), then phases (lexical), then tasks (lexical).
- **Title extraction is best-effort** — fall back to basename without `.md` on H1 miss. Never fail the scan on title extraction.
- **Single-script-file `Check:` shape (AD-19)** — T05's exclusion-policy Check is a single `bash scripts/verify/m012-p01-exclusion-policy.sh` invocation.
- **No network, no external dependencies** — `find`, `grep`, `sed`, `awk`, `sort` only (all in Bash 3.2 baseline).

## Expected Output

- `scripts/wiki/wiki-scan-sources.sh` — executable, Bash 3.2 compliant, 60+ lines.
- Running it prints lines in `<category>|<rel-path>|<title>` shape, zero excluded paths, stable lexical order within categories.
- Running it with `--root /tmp/empty` (or an empty directory) emits zero stdout lines and `SUMMARY: 0 in-scope artifacts` on stderr.
- Returns exit 0 on success, exit 1 only if `--root` points at a non-existent directory or the `.orchestrator/` subdir is missing.

## State Context

- **Current State**: executing
- **Milestone**: M012
- **Phase**: P01
- **Task**: T02
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **Bash 3.2** — per MEM001. macOS baseline.
- **MEM004 carve-out** — this is a helper library, not agent-facing content; pipes, `$()`, `awk`, and `find` are permitted.
- **Read-only** — the scanner never writes under `$ROOT`. Any attempt to write fails review.
- **Stable output order** — top-level artifacts first, then milestones (lexical by `M###`), then archive (lexical by `M###`). Within a milestone: top-level `M###-*.md` (alphabetical), then phases (lexical), then tasks (lexical).
- **Title extraction is best-effort** — fall back to basename without `.md` on H1 miss. Never fail the scan on title extraction.
- **Single-script-file `Check:` shape (AD-19)** — T05's exclusion-policy Check is a single `bash scripts/verify/m012-p01-exclusion-policy.sh` invocation.
- **No network, no external dependencies** — `find`, `grep`, `sed`, `awk`, `sort` only (all in Bash 3.2 baseline).

### Acceptance Criteria

- `scripts/wiki/wiki-scan-sources.sh` exists and is executable.
- Output schema is three pipe-separated fields: `<category>|<rel-path>|<title>`.
- No line in output contains `.orchestrator/scratch/`, `.orchestrator/tmp/`, or `.orchestrator/config/`.
- No line in output ends in anything other than `.md`.
- No line in output references `PLANNING-PAYLOAD`, `VERIFICATION`, `AGENTS.md`, or a basename `README.md` inside milestone / archive trees.
- Top-level artifacts emit before milestone artifacts; milestone artifacts emit before archive artifacts; within each group, lexical order.
- Bash 3.2 compatible — no `declare -A`, no `mapfile`, no `${var^^}`, no `<(...)`, no `&>`.
- Pure read-only (no writes under `$ROOT`).

### Files To Touch

- `wiki/` (create — directory)
- `wiki/requirements.txt` (create)
- `wiki/mkdocs.yml` (create in T01; extended by T04 with nav block)
- `wiki/docs/index.md` (create — placeholder)
- `wiki/docs/README.md` (create — authoring note)
- `wiki/README.md` (create — operator notes)
- `wiki/.gitignore` (create — ignore generated `site/` output)
- `scripts/wiki/wiki-scan-sources.sh` (create)
- `scripts/wiki/wiki-generate-stubs.sh` (create)
- `scripts/wiki/wiki-generate-nav.sh` (create)
- `scripts/wiki/wiki-serve.sh` (create)
- `scripts/verify/m012-p01-wiki-self-contained.sh` (create)
- `scripts/verify/m012-p01-requirements-pinned.sh` (create)
- `scripts/verify/m012-p01-include-plugin.sh` (create)
- `scripts/verify/m012-p01-ssot.sh` (create)
- `scripts/verify/m012-p01-exclusion-policy.sh` (create)
- `scripts/verify/m012-p01-nav-structure.sh` (create)
- `scripts/verify/m012-p01-serve-smoke.sh` (create)
- `scripts/verify/m012-p01-index-placeholder.sh` (create)
- `scripts/verify/m012-p01-bash32-compat.sh` (create)
- `scripts/verify/m012-p01-phase-suite.sh` (create)
- `wiki/docs/**/*.md` (create — thin include stubs, one per in-scope `.orchestrator/**.md`; generated by T03)

</dispatch-volatile>

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