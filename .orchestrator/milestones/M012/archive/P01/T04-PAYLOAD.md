---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T04 (Phase P01, Milestone M012)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (25 entries) | 20-589 | ~4900 | filtered |
| Decisions | 591-593 | ~100 | filtered |
| Constraints | 595-628 | ~400 | required |
| Scope | 630-658 | ~400 | required |
| Upstream Context | 660-662 | ~100 | required |
| Task Plan | 664-936 | ~3300 | required |
| State Context | 938-944 | ~100 | required |
| First-Turn Completeness | 946-995 | ~700 | required |
| **Total** | | **~10000** | |

## Knowledge

<!-- 25 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 312
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
hit_count: 312
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
hit_count: 312
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
hit_count: 312
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
hit_count: 281
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
hit_count: 281
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
hit_count: 281
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
hit_count: 312
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
hit_count: 281
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
hit_count: 281
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
hit_count: 281
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
hit_count: 312
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
hit_count: 312
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
hit_count: 312
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
hit_count: 281
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
hit_count: 281
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
hit_count: 281
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
hit_count: 312
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
hit_count: 281
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
hit_count: 281
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
hit_count: 312
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
hit_count: 312
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
hit_count: 281
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
hit_count: 281
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
hit_count: 281
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
task: "T04"
phase: "P01"
milestone: "M012"
name: "wiki-generate-nav.sh — Constitution / Decisions / Knowledge / Milestone Summary / Milestones / Archive nav assembly"
depends_on: ["T03"]
---

## Prerequisites

- T01 complete: `wiki/mkdocs.yml` has no `nav:` key (intentionally absent from T01).
- T02 complete: `scripts/wiki/wiki-scan-sources.sh` emits the in-scope list.
- T03 complete: every in-scope artifact has a stub under `wiki/docs/**` with predictable path layout.

## Description

Generate the MkDocs `nav:` block and splice it into `wiki/mkdocs.yml`. The final top-level nav order is:

```
nav:
  - Home: index.md
  - Constitution: constitution.md
  - Decisions: decisions.md
  - Knowledge: knowledge.md
  - Milestone Summary: milestone-summary.md
  - Milestones:
    - milestones/index.md
    - M001:
      - milestones/M001/index.md
      - M001 Context: milestones/M001/M001-CONTEXT.md
      - M001 Evaluation: milestones/M001/M001-EVALUATION.md
      - M001 Roadmap: milestones/M001/M001-ROADMAP.md
      - M001 Summary: milestones/M001/M001-SUMMARY.md
      - P01:
        - milestones/M001/phases/P01/index.md
        - P01 Plan: milestones/M001/phases/P01/P01-PLAN.md
        - P01 Summary: milestones/M001/phases/P01/P01-SUMMARY.md
        - T01 Plan: milestones/M001/phases/P01/tasks/T01-PLAN.md
        - T01 Summary: milestones/M001/phases/P01/tasks/T01-SUMMARY.md
        - ...
    - M002:
      ...
  - Archive:
    - archive/index.md
    - M###:
      - ...
```

This matches AD-6 (phase/task nesting as expandable nav) and M012-ROADMAP's Boundary Map ("Nav structure: Constitution, Decisions, Knowledge, Milestone Summary, Milestones expandable per-milestone, Archive labeled").

The nav block is injected into `wiki/mkdocs.yml` between two marker comments, so the generator can safely replace the block on subsequent runs without disturbing surrounding config. If the markers are absent, the generator appends them at the end of the file.

## Steps

1. **Create `scripts/wiki/wiki-generate-nav.sh`** — Bash 3.2, MEM004 carve-out.

   Shape:

   ```bash
   #!/usr/bin/env bash
   # scripts/wiki/wiki-generate-nav.sh — M012/P01 nav block generator.
   #
   # Consumes scripts/wiki/wiki-scan-sources.sh output and writes a MkDocs
   # nav: block into wiki/mkdocs.yml between these two marker lines:
   #   # >>> M012-P01 nav (auto-generated — do not edit by hand)
   #   # <<< M012-P01 nav end
   #
   # On first run, the markers are appended at the end of wiki/mkdocs.yml
   # with the nav block between them. On subsequent runs, the content
   # between the existing markers is replaced atomically.
   #
   # Nav order (top level):
   #   Home, Constitution, Decisions, Knowledge, Milestone Summary,
   #   Milestones (expandable per-milestone), Archive (labeled).
   #
   # Usage: bash scripts/wiki/wiki-generate-nav.sh [--dry-run] [--root PROJECT_ROOT]
   # Exit 0 on success; 1 on scanner failure; 2 on config write error.
   # Bash 3.2 compatible.
   ```

2. **Resolve PROJECT_ROOT** (same pattern as T02/T03).

3. **Read scanner output once** into an ordered stream. Use a temp file or a single pipe; do not embed scanner calls inside `$()` in Checks (AD-19), but internal script use of `$()` is fine (MEM004 carve-out).

   ```bash
   SCAN_OUT="$(mktemp -t m012p01navXXXXXX)"
   trap 'rm -f "$SCAN_OUT"' EXIT
   bash "$ROOT/scripts/wiki/wiki-scan-sources.sh" --root "$ROOT" > "$SCAN_OUT"
   ```

4. **Map scanner path → nav path under `wiki/docs/`** (mirror of T03's target-path mapping):

   - `top:constitution` → `constitution.md`
   - `top:decisions` → `decisions.md`
   - `top:knowledge` → `knowledge.md`
   - `top:milestone-summary` → `milestone-summary.md`
   - `milestone:<M###>` + rel `...milestones/M###/<rest>` → `milestones/M###/<rest>`
   - `archive:<M###>` + rel `...archive/M###/<rest>` → `archive/M###/<rest>`

5. **Build the nav tree**. Walk the scanner stream and group by milestone, by phase, by task. Bash 3.2 has no associative arrays; use the parallel-indexed-array pattern (MEM001): one array of milestone IDs encountered in order, and per-milestone arrays of stub nav paths, built on the fly.

   Pragmatic implementation: rather than building nested arrays, emit the YAML in a single stream-friendly pass. Because the scanner output is already lexically sorted (top → milestones lexical → archive lexical, nested phases/tasks lexical), a stateful while-read loop can emit the right indentation at group transitions:

   ```bash
   prev_milestone=""
   prev_phase=""
   prev_group=""   # "top" | "milestone" | "archive"
   while IFS='|' read -r category rel title; do
     # Derive nav path + milestone id + phase id from category/rel.
     # Compare to prev_* state; emit section headers + indentation when
     # group, milestone, or phase changes.
     # Print the bullet line with 2 * depth spaces.
   done < "$SCAN_OUT"
   ```

   Emit entries with consistent 2-space YAML indentation. Titles with special YAML characters (`:`, `#`, `"`) are double-quoted and internal `"` is escaped `\"`. Use `printf '%s\n'` for every line — no pipes, no `$(…)` with pipes inside the stream.

6. **Nav title derivation** (keep consistent with AD-6 and the Boundary Map):

   - Top-level: fixed labels `Home`, `Constitution`, `Decisions`, `Knowledge`, `Milestone Summary`, `Milestones`, `Archive`.
   - Per-milestone group label: the `M###` id (e.g., `M001`, `M011`). (Short labels keep the sidebar readable.)
   - Per-artifact label under a milestone: strip the `M###-` prefix and title-case the remainder. Examples: `M011-CONTEXT.md` → `Context`, `M011-EVALUATION.md` → `Evaluation`, `M011-ROADMAP.md` → `Roadmap`, `M011-SUMMARY.md` → `Summary`.
   - Per-phase group label: `P##` (e.g., `P01`).
   - Per-phase-artifact label: strip `P##-` prefix and title-case. `P01-PLAN.md` → `Plan`, `P01-SUMMARY.md` → `Summary`.
   - Per-task label: strip numeric prefix, keep the kind. `T01-PLAN.md` → `T01 Plan`, `T01-SUMMARY.md` → `T01 Summary`. (Task bullets stay identifiable at a glance.)
   - Section-index `index.md` entries: use a visually light label. `Overview` is acceptable for milestones/archive index pages; per-milestone/per-phase index pages can reuse the group label or be collapsed per MkDocs Material's `navigation.indexes` feature (already enabled in T01).

7. **Marker-based atomic replacement** in `wiki/mkdocs.yml`:

   ```bash
   MARKER_START="# >>> M012-P01 nav (auto-generated — do not edit by hand)"
   MARKER_END="# <<< M012-P01 nav end"

   if ! grep -qF "$MARKER_START" "$CONFIG"; then
     # First run: append markers (with an empty block between) at EOF.
     {
       printf '\n%s\n' "$MARKER_START"
       printf '%s\n' "$MARKER_END"
     } >> "$CONFIG"
   fi

   # Extract pre-block, nav-block, post-block into temp files.
   # Replace middle with newly assembled nav YAML.
   # Write atomically via mv over a temp file.
   ```

   Use `awk` with a state machine to split on markers — much cleaner than `sed -i` (which differs between GNU and BSD):

   ```bash
   TMP_PRE=$(mktemp)
   TMP_POST=$(mktemp)
   awk -v s="$MARKER_START" -v e="$MARKER_END" \
       -v pre="$TMP_PRE" -v post="$TMP_POST" '
     BEGIN { state = "pre" }
     {
       if (state == "pre") {
         if ($0 == s) { print s > pre; state = "in"; next }
         print > pre; next
       }
       if (state == "in") {
         if ($0 == e) { state = "post"; print e > post; next }
         next
       }
       # state == "post"
       print > post
     }' "$CONFIG"

   TMP_FINAL=$(mktemp)
   cat "$TMP_PRE" > "$TMP_FINAL"
   # Append freshly assembled nav between markers.
   assemble_nav_block >> "$TMP_FINAL"
   cat "$TMP_POST" >> "$TMP_FINAL"

   mv "$TMP_FINAL" "$CONFIG"
   rm -f "$TMP_PRE" "$TMP_POST"
   ```

   The marker lines themselves are emitted by `assemble_nav_block` so the final file keeps its start + body + end in one contiguous region. Dry-run mode prints the assembled nav block to stdout instead of writing the config.

8. **Final block shape** (what `assemble_nav_block` writes to stdout):

   ```yaml
   # >>> M012-P01 nav (auto-generated — do not edit by hand)
   nav:
     - Home: index.md
     - Constitution: constitution.md
     - Decisions: decisions.md
     - Knowledge: knowledge.md
     - Milestone Summary: milestone-summary.md
     - Milestones:
       - Overview: milestones/index.md
       - M001:
         - Overview: milestones/M001/index.md
         - Context: milestones/M001/M001-CONTEXT.md
         ...
         - P01:
           - Overview: milestones/M001/phases/P01/index.md
           - Plan: milestones/M001/phases/P01/P01-PLAN.md
           ...
     - Archive:
       - Overview: archive/index.md
       - M###:
         ...
   # <<< M012-P01 nav end
   ```

9. **Idempotency**: running twice in a row without scanner output changing produces a byte-identical `wiki/mkdocs.yml`.

10. **Smoke check** after writing (manual; do NOT embed as a Check): `head -n 120 wiki/mkdocs.yml` — confirm markers + `nav:` + expected top-level entries. If `mkdocs` installed: `bash scripts/wiki/wiki-serve.sh --probe` — strict build must succeed.

## Must-Haves

- `scripts/wiki/wiki-generate-nav.sh` exists, is executable, Bash 3.2 compliant.
- After running the generator once, `wiki/mkdocs.yml` contains a `nav:` block between the marker comments.
- Top-level nav includes (in order): `Home`, `Constitution`, `Decisions`, `Knowledge`, `Milestone Summary`, `Milestones`, `Archive`.
- Every in-scope milestone (every `.orchestrator/milestones/M###/` under scanner output) appears as an expandable group under `Milestones`.
- Every in-scope archived milestone appears under `Archive`.
- Every scanner record maps to exactly one nav entry (no orphaned stubs, no missing entries).
- Running the generator twice produces byte-identical `wiki/mkdocs.yml` (idempotency).
- No copied or symlinked artifact appears; every `nav:` leaf points at a stub under `wiki/docs/`.

## Verification

- `bash scripts/verify/m012-p01-nav-structure.sh` (T05) — asserts the seven top-level nav labels appear in order; asserts `Archive:` appears exactly once; asserts every scanner entry has a matching nav line.
- `bash scripts/verify/m012-p01-include-plugin.sh` (T05) — indirectly validated (stubs referenced by nav exist).
- `bash scripts/verify/m012-p01-bash32-compat.sh` (T05) — scans this script.
- `bash scripts/verify/m012-p01-serve-smoke.sh` (T05) — strict mkdocs build exits 0 (probe mode).

Manual smoke check during this task (run once; do NOT embed as a Check):

1. `bash scripts/wiki/wiki-generate-nav.sh --dry-run | head -n 60` — sanity-check the assembled block.
2. `bash scripts/wiki/wiki-generate-nav.sh` — write to `wiki/mkdocs.yml`.
3. `diff <(bash scripts/wiki/wiki-generate-nav.sh --dry-run) <(bash scripts/wiki/wiki-generate-nav.sh --dry-run)` — empty diff (deterministic).
4. `grep -c '^nav:' wiki/mkdocs.yml` — exactly 1.

## Inputs

### From Previous Tasks

- **T01**: `wiki/mkdocs.yml` base — no existing `nav:` key; `plugins:` block declares `include-markdown`.
- **T02**: `scripts/wiki/wiki-scan-sources.sh` — emits `<category>|<rel-path>|<title>` per in-scope artifact, stable lexical order.
- **T03**: `wiki/docs/**` stubs — one per scanner record; section indexes (`milestones/index.md`, `archive/index.md`, per-milestone/per-phase `index.md`).

### Scanner Output Contract (reproduced for zero-context execution)

- Line format: `<category>|<rel-path>|<title>`.
- Category enum: `top:constitution`, `top:decisions`, `top:knowledge`, `top:milestone-summary`, `milestone:<M###>`, `archive:<M###>`.
- Stable lexical ordering as detailed in T02.

### From Disk (Pre-existing)

- `wiki/docs/**/*.md` — stubs + section indexes produced by T03. The nav generator checks their existence (via path-reconstruction) but does not read their bodies.

## Constraints

- **Bash 3.2** — per MEM001. macOS baseline. No `declare -A`; use parallel indexed arrays if any cross-iteration state is needed.
- **MEM004 carve-out** — helper-internal; pipes, `$()`, awk, heredocs permitted.
- **Atomic write** — write to a temp file under the config's directory, then `mv` over `wiki/mkdocs.yml`. Partial writes on crash are forbidden.
- **Marker discipline** — the entire auto-generated nav region lives between the two marker comments and nowhere else. Never rewrite content outside markers.
- **Deterministic output** — same scanner output → byte-identical nav block.
- **YAML escaping** — titles with `:`, `#`, `"` are double-quoted; internal `"` becomes `\"`. Titles with newlines are forbidden (shouldn't happen — scanner emits single-line titles).
- **Single-script-file `Check:` shape (AD-19)** — all T05 Checks remain single-invocation.

## Expected Output

- `scripts/wiki/wiki-generate-nav.sh` — executable, Bash 3.2 compliant, ≥ 60 lines, supports `--dry-run` and `--root`.
- `wiki/mkdocs.yml` contains a `nav:` block bounded by the two marker comments, with the seven top-level sections in fixed order and every in-scope artifact reachable under the correct section.
- Running the generator twice is a no-op (byte-identical output).
- If `mkdocs` is on PATH, `bash scripts/wiki/wiki-serve.sh --probe` exits 0.

## State Context

- **Current State**: executing
- **Milestone**: M012
- **Phase**: P01
- **Task**: T04
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **Bash 3.2** — per MEM001. macOS baseline. No `declare -A`; use parallel indexed arrays if any cross-iteration state is needed.
- **MEM004 carve-out** — helper-internal; pipes, `$()`, awk, heredocs permitted.
- **Atomic write** — write to a temp file under the config's directory, then `mv` over `wiki/mkdocs.yml`. Partial writes on crash are forbidden.
- **Marker discipline** — the entire auto-generated nav region lives between the two marker comments and nowhere else. Never rewrite content outside markers.
- **Deterministic output** — same scanner output → byte-identical nav block.
- **YAML escaping** — titles with `:`, `#`, `"` are double-quoted; internal `"` becomes `\"`. Titles with newlines are forbidden (shouldn't happen — scanner emits single-line titles).
- **Single-script-file `Check:` shape (AD-19)** — all T05 Checks remain single-invocation.

### Acceptance Criteria

- `scripts/wiki/wiki-generate-nav.sh` exists, is executable, Bash 3.2 compliant.
- After running the generator once, `wiki/mkdocs.yml` contains a `nav:` block between the marker comments.
- Top-level nav includes (in order): `Home`, `Constitution`, `Decisions`, `Knowledge`, `Milestone Summary`, `Milestones`, `Archive`.
- Every in-scope milestone (every `.orchestrator/milestones/M###/` under scanner output) appears as an expandable group under `Milestones`.
- Every in-scope archived milestone appears under `Archive`.
- Every scanner record maps to exactly one nav entry (no orphaned stubs, no missing entries).
- Running the generator twice produces byte-identical `wiki/mkdocs.yml` (idempotency).
- No copied or symlinked artifact appears; every `nav:` leaf points at a stub under `wiki/docs/`.

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