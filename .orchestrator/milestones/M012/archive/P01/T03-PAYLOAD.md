---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T03 (Phase P01, Milestone M012)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (25 entries) | 20-589 | ~4900 | filtered |
| Decisions | 591-593 | ~100 | filtered |
| Constraints | 595-628 | ~400 | required |
| Scope | 630-658 | ~400 | required |
| Upstream Context | 660-662 | ~100 | required |
| Task Plan | 664-915 | ~3300 | required |
| State Context | 917-923 | ~100 | required |
| First-Turn Completeness | 925-973 | ~700 | required |
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
hit_count: 310
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
hit_count: 310
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
hit_count: 310
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
hit_count: 310
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
hit_count: 279
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
hit_count: 279
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
hit_count: 279
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
hit_count: 310
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
hit_count: 279
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
hit_count: 279
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
hit_count: 279
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
hit_count: 310
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
hit_count: 310
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
hit_count: 310
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
hit_count: 279
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
hit_count: 279
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
hit_count: 279
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
hit_count: 310
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
hit_count: 279
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
hit_count: 279
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
hit_count: 310
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
hit_count: 310
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
hit_count: 279
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
hit_count: 279
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
hit_count: 279
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
task: "T03"
phase: "P01"
milestone: "M012"
name: "wiki-generate-stubs.sh — include-plugin stubs for every in-scope .orchestrator/**.md"
depends_on: ["T02"]
---

## Prerequisites

- T01 complete: `wiki/` + `wiki/mkdocs.yml` + `wiki/docs/index.md` exist; `include-markdown` is declared in `plugins:`.
- T02 complete: `scripts/wiki/wiki-scan-sources.sh` emits in-scope records in `<category>|<rel-path>|<title>` shape.

## Description

Generate one include-plugin stub under `wiki/docs/` per in-scope `.orchestrator/**.md` artifact. Each stub contains no body content — only a YAML frontmatter `title:` and an `include-markdown` directive pointing at the canonical path under `.orchestrator/`. This is the mechanism that enforces AD-3 (no copies, no symlinks): the file under `wiki/docs/` is ≤ ~10 lines of template; the real content lives at `.orchestrator/**.md` and is pulled at MkDocs build time.

Stub layout mirrors the category structure emitted by the scanner, flattened into navigable directories under `wiki/docs/`:

```
wiki/docs/
  index.md                       (from T01 — placeholder, not a stub)
  README.md                      (from T01 — authoring note)
  constitution.md                (top:constitution)
  decisions.md                   (top:decisions)
  knowledge.md                   (top:knowledge)
  milestone-summary.md           (top:milestone-summary)
  milestones/
    index.md                     (auto-generated section index; one-liner)
    M001/
      index.md                   (auto-generated per-milestone section index)
      M001-CONTEXT.md            (stub → .orchestrator/milestones/M001/M001-CONTEXT.md)
      M001-EVALUATION.md
      M001-ROADMAP.md
      M001-SUMMARY.md
      P01/
        index.md
        P01-PLAN.md
        P01-SUMMARY.md
        T01-PLAN.md
        T01-SUMMARY.md
        ...
  archive/
    index.md                     (auto-generated section index)
    M001/
      ...
```

The generator:

1. Calls `wiki-scan-sources.sh` for the authoritative in-scope list.
2. Wipes any existing stubs under `wiki/docs/` — but only the stubs (never `index.md` or `README.md` at the top).
3. Writes one stub per scanned record.
4. Generates section index pages (`milestones/index.md`, `archive/index.md`, `milestones/M###/index.md`, `milestones/M###/P##/index.md`) that list their children. These are one-screen lists; T04 consumes the directory layout for the mkdocs `nav:` block.

## Steps

1. **Create `scripts/wiki/wiki-generate-stubs.sh`** — Bash 3.2, MEM004 carve-out (pipes/awk/find permitted; it's a helper script, not agent-facing content).

   Shape:

   ```bash
   #!/usr/bin/env bash
   # scripts/wiki/wiki-generate-stubs.sh — M012/P01 stub generator.
   #
   # Reads scan output from scripts/wiki/wiki-scan-sources.sh and writes one
   # thin include-plugin stub per in-scope .orchestrator/**.md artifact under
   # wiki/docs/.
   #
   # Stubs are < 15 lines each. Body content stays at .orchestrator/**.md
   # (single source of truth, M012 AD-3).
   #
   # Idempotent: safe to re-run. Removes existing auto-generated stubs before
   # writing fresh ones. Never touches wiki/docs/index.md or wiki/docs/README.md.
   #
   # Usage: bash scripts/wiki/wiki-generate-stubs.sh [--dry-run] [--root PROJECT_ROOT]
   # Exit 0 on success; 1 on scanner failure; 2 on write error.
   # Bash 3.2 compatible.
   ```

2. **Resolve PROJECT_ROOT** (same pattern as T02): default `$(cd "$(dirname "$0")/../.." && pwd)`; `--root` override.

3. **Clean phase**: identify auto-generated stubs under `wiki/docs/` and remove them. Definition of "auto-generated": any `.md` file under `wiki/docs/` except `index.md` and `README.md` at the top level. Use:

   ```bash
   # Remove every .md under wiki/docs/ except the top-level index.md and README.md.
   find "$ROOT/wiki/docs" -mindepth 1 -type f -name '*.md' \
     ! -path "$ROOT/wiki/docs/index.md" \
     ! -path "$ROOT/wiki/docs/README.md" \
     -delete
   # Remove now-empty subdirectories.
   find "$ROOT/wiki/docs" -mindepth 1 -type d -empty -delete 2>/dev/null || true
   ```

4. **Map category → target path**:

   | Scanner category | Target stub path (under `wiki/docs/`) |
   |------------------|----------------------------------------|
   | `top:constitution` | `constitution.md` |
   | `top:decisions` | `decisions.md` |
   | `top:knowledge` | `knowledge.md` |
   | `top:milestone-summary` | `milestone-summary.md` |
   | `milestone:<M###>` | `milestones/<M###>/<mirror of rel-path after milestones/M###/>` |
   | `archive:<M###>` | `archive/<M###>/<mirror of rel-path after archive/M###/>` |

   Examples:
   - `milestone:M011 | .orchestrator/milestones/M011/M011-SUMMARY.md | M011 Summary`
     → `wiki/docs/milestones/M011/M011-SUMMARY.md`
   - `milestone:M011 | .orchestrator/milestones/M011/phases/P02/P02-PLAN.md | P02 Plan`
     → `wiki/docs/milestones/M011/phases/P02/P02-PLAN.md`
   - `milestone:M011 | .orchestrator/milestones/M011/phases/P02/tasks/T03-PLAN.md | T03 Plan`
     → `wiki/docs/milestones/M011/phases/P02/tasks/T03-PLAN.md`

   Preserve the nested `phases/P##/` and `tasks/T##-*` structure under each milestone. This keeps AD-6 (nested plan inclusion) working and makes nav paths predictable.

5. **Stub template** (write this exact body, with substitution, for every stub):

   ```markdown
   ---
   title: "{{title}}"
   ---

   <!-- Auto-generated by scripts/wiki/wiki-generate-stubs.sh. Do not hand-edit.
        Source of truth: {{canonical_path}} (M012 AD-3). -->

   {%
     include-markdown "{{canonical_path}}"
     heading-offset=0
     rewrite-relative-urls=true
   %}
   ```

   Where:
   - `{{title}}` is the scanner's third field (H1 or basename fallback).
   - `{{canonical_path}}` is an absolute-from-repo-root path: e.g., `../../../.orchestrator/milestones/M011/M011-SUMMARY.md`. Compute the relative path from the stub location back to `.orchestrator/` with pure Bash string counting (bash 3.2 safe: count slashes in the stub's relative path, emit that many `../`).

   Write via `printf '%s\n' ...` (heredocs are fine for literal content as long as they have no pipes / further redirects — AD-19 forbids `heredoc | pipe`, not plain heredoc to stdout / file). A single heredoc to a named file via `> "$path"` is acceptable.

   Helper function:

   ```bash
   write_stub() {
     local target="$1" canonical="$2" title="$3"
     mkdir -p "$(dirname "$target")"
     {
       printf -- '---\n'
       printf 'title: "%s"\n' "$title"
       printf -- '---\n\n'
       printf '<!-- Auto-generated by scripts/wiki/wiki-generate-stubs.sh. Do not hand-edit.\n'
       printf '     Source of truth: %s (M012 AD-3). -->\n\n' "$canonical"
       printf '{%%\n'
       printf '  include-markdown "%s"\n' "$canonical"
       printf '  heading-offset=0\n'
       printf '  rewrite-relative-urls=true\n'
       printf '%%}\n'
     } > "$target"
   }
   ```

6. **Section indexes** (auto-generated one-screen lists):

   - `wiki/docs/milestones/index.md`: lists every `milestones/M###/` directory created under the stubs tree with a one-line pointer.
   - `wiki/docs/archive/index.md`: same, for `archive/M###/`.
   - `wiki/docs/milestones/M###/index.md`: lists the milestone's top-level `M###-*.md` stubs plus its `phases/P##/` subdirectories.
   - `wiki/docs/milestones/M###/phases/P##/index.md`: lists the phase's top-level `P##-*.md` stubs plus its `tasks/` children.

   Index template:

   ```markdown
   ---
   title: "{{section_title}}"
   ---

   # {{section_title}}

   <!-- Auto-generated section index. Regenerated by wiki-generate-stubs.sh. -->

   {{body_lines}}
   ```

   Where `{{body_lines}}` is one bullet per child entry — `- [<child-title>](<child-relative-path>)`. Keep bullets in lexical order. T04's nav generator mirrors this ordering.

7. **Idempotency + `--dry-run` mode**: `--dry-run` prints every path that WOULD be written/removed (prefixed `WOULD-WRITE:` / `WOULD-REMOVE:`) and exits 0 without touching disk. Running without `--dry-run` twice in a row is a no-op on the second run if `.orchestrator/` has not changed.

8. **Progress + summary**: emit `STUB: <target-path>` per stub written (stderr), and `SUMMARY: wrote <N> stubs, <M> section indexes, removed <K> stale files` on stderr at end.

9. **Run the generator once after writing it** (manual smoke check; not a Check): `bash scripts/wiki/wiki-generate-stubs.sh` then `find wiki/docs -type f -name '*.md' | wc -l` — confirm the count matches the T02 scanner count + section indexes + 2 (index.md + README.md).

## Must-Haves

- `scripts/wiki/wiki-generate-stubs.sh` exists and is executable.
- Every stub file under `wiki/docs/` is ≤ 25 lines (short template body; no duplicated artifact content).
- Every stub under `wiki/docs/` (except `index.md` and `README.md` at top level and `index.md` section indexes) contains an `include-markdown` directive referencing a path under `.orchestrator/`.
- `wiki/docs/index.md` and `wiki/docs/README.md` are preserved untouched across generator runs.
- Running the generator twice in a row produces byte-identical `wiki/docs/` contents (idempotency).
- Bash 3.2 compatible.
- Stub count matches scanner line count (every in-scope artifact gets exactly one stub).

## Verification

- `bash scripts/verify/m012-p01-include-plugin.sh` (T05) — asserts every stub has an `include-markdown` directive and references an existing `.orchestrator/` path.
- `bash scripts/verify/m012-p01-ssot.sh` (T05) — asserts no stub's body reproduces source content; stubs are ≤ 25 lines; no duplicate content under `wiki/docs/`.
- `bash scripts/verify/m012-p01-exclusion-policy.sh` (T05) — asserts no stub references `scratch/`, `tmp/`, `config/`, or non-`.md` paths.
- `bash scripts/verify/m012-p01-bash32-compat.sh` (T05) — scans this script.

Manual smoke check during this task (run once; do NOT embed as a Check):

1. `bash scripts/wiki/wiki-generate-stubs.sh --dry-run | head -n 20` — sanity-check the planned writes.
2. `bash scripts/wiki/wiki-generate-stubs.sh` — writes stubs for real.
3. `bash scripts/wiki/wiki-generate-stubs.sh` (again) — expect `SUMMARY:` line showing 0 new writes (idempotent).
4. If `mkdocs` installed: `bash scripts/wiki/wiki-serve.sh --probe` — expect failure only on the absent `nav:` block (resolved by T04).
5. `grep -r '^# ' wiki/docs/milestones/M012/ | head` — confirm the milestone's own artifacts appear.

## Inputs

### From Previous Tasks

- **T01**: `wiki/` skeleton — `wiki/mkdocs.yml` with the include plugin declared; `wiki/docs/index.md` placeholder; `wiki/docs/README.md` authoring note.
- **T02**: `scripts/wiki/wiki-scan-sources.sh` — emits `<category>|<rel-path>|<title>` per in-scope artifact. Contract is stable; this script treats it as a black box.

### Scanner Output Contract (from T02 — reproduced for zero-context execution)

- Line format: `<category>|<rel-path>|<title>`.
- Category enum: `top:constitution`, `top:decisions`, `top:knowledge`, `top:milestone-summary`, `milestone:<M###>`, `archive:<M###>`.
- `<rel-path>`: relative path under the repo root (e.g., `.orchestrator/milestones/M011/M011-SUMMARY.md`).
- `<title>`: single-line string, never empty.
- Stable lexical ordering: top-level first; then milestones (lexical); then archive (lexical). Within each milestone, `M###-*.md` (alphabetical), then `phases/P##/P##-*.md`, then `phases/P##/tasks/T##-*.md`.

### From Disk (Pre-existing)

- `.orchestrator/**.md` — content referenced by stubs via the include plugin (not read by the generator itself).
- `wiki/mkdocs.yml` — generator does not modify it here; T04 handles nav injection.

## Constraints

- **Bash 3.2** — MEM001. macOS baseline.
- **MEM004 carve-out** — helper-script-internal; pipes, `$()`, awk, find, heredocs are permitted. AD-19 prohibits `heredoc | pipe`; heredocs writing to a single file via redirect are fine.
- **No copies, no symlinks** — AD-3. Stubs reference canonical paths via include-markdown. Verified by T05.
- **Idempotency** — second run after a first successful run must produce zero writes (or, if scanner output is unchanged, zero net diff). The "clean phase" is explicit for reproducibility.
- **Never touch `wiki/docs/index.md` or `wiki/docs/README.md`** — these are T01 / P04 territory. Hard-guard in the clean-phase `find` command.
- **Path traversal safety** — every stub target path is constructed relative to `wiki/docs/`. Never emit a stub whose canonical include path does not start with `../` (i.e., never reference something inside `wiki/`).
- **Single-script-file `Check:` shape (AD-19)** — T05 gates are single invocations; no compound bash inside Checks.

## Expected Output

- `scripts/wiki/wiki-generate-stubs.sh` — executable, Bash 3.2 compliant, ≥ 80 lines, supports `--dry-run` and `--root`.
- After running the generator once: `wiki/docs/` holds one stub per in-scope artifact plus section indexes, with every stub ≤ 25 lines, every stub referencing a canonical `.orchestrator/**.md` path via the include plugin.
- Running the generator twice leaves `wiki/docs/` byte-identical (idempotency).

## State Context

- **Current State**: executing
- **Milestone**: M012
- **Phase**: P01
- **Task**: T03
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **Bash 3.2** — MEM001. macOS baseline.
- **MEM004 carve-out** — helper-script-internal; pipes, `$()`, awk, find, heredocs are permitted. AD-19 prohibits `heredoc | pipe`; heredocs writing to a single file via redirect are fine.
- **No copies, no symlinks** — AD-3. Stubs reference canonical paths via include-markdown. Verified by T05.
- **Idempotency** — second run after a first successful run must produce zero writes (or, if scanner output is unchanged, zero net diff). The "clean phase" is explicit for reproducibility.
- **Never touch `wiki/docs/index.md` or `wiki/docs/README.md`** — these are T01 / P04 territory. Hard-guard in the clean-phase `find` command.
- **Path traversal safety** — every stub target path is constructed relative to `wiki/docs/`. Never emit a stub whose canonical include path does not start with `../` (i.e., never reference something inside `wiki/`).
- **Single-script-file `Check:` shape (AD-19)** — T05 gates are single invocations; no compound bash inside Checks.

### Acceptance Criteria

- `scripts/wiki/wiki-generate-stubs.sh` exists and is executable.
- Every stub file under `wiki/docs/` is ≤ 25 lines (short template body; no duplicated artifact content).
- Every stub under `wiki/docs/` (except `index.md` and `README.md` at top level and `index.md` section indexes) contains an `include-markdown` directive referencing a path under `.orchestrator/`.
- `wiki/docs/index.md` and `wiki/docs/README.md` are preserved untouched across generator runs.
- Running the generator twice in a row produces byte-identical `wiki/docs/` contents (idempotency).
- Bash 3.2 compatible.
- Stub count matches scanner line count (every in-scope artifact gets exactly one stub).

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