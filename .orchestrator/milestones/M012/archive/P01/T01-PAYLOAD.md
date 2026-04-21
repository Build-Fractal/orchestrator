---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T01 (Phase P01, Milestone M012)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (25 entries) | 20-589 | ~4900 | filtered |
| Decisions | 591-593 | ~100 | filtered |
| Constraints | 595-628 | ~400 | required |
| Scope | 630-658 | ~400 | required |
| Upstream Context | 660-662 | ~100 | required |
| Task Plan | 664-1008 | ~3500 | required |
| State Context | 1010-1016 | ~100 | required |
| First-Turn Completeness | 1018-1066 | ~700 | required |
| **Total** | | **~10200** | |

## Knowledge

<!-- 25 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 308
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
hit_count: 308
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
hit_count: 308
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
hit_count: 308
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
hit_count: 277
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
hit_count: 277
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
hit_count: 277
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
hit_count: 308
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
hit_count: 277
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
hit_count: 277
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
hit_count: 277
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
hit_count: 308
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
hit_count: 308
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
hit_count: 308
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
hit_count: 277
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
hit_count: 277
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
hit_count: 277
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
hit_count: 308
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
hit_count: 277
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
hit_count: 277
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
hit_count: 308
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
hit_count: 308
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
hit_count: 277
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
hit_count: 277
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
hit_count: 277
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
task: "T01"
phase: "P01"
milestone: "M012"
name: "wiki/ skeleton — requirements.txt, mkdocs.yml base, index placeholder, wiki-serve.sh"
depends_on: []
---

## Prerequisites

- Repository root is `/Users/brettkellgren/Sites/lakeledger/spec-kit-orchestrator` (the orchestrator's own repo; `.orchestrator/` is already populated with real artifacts).
- `.orchestrator/milestones/M012/M012-CONTEXT.md` decisions AD-3 (include-plugin, no copies / no symlinks), AD-6 (phase and task plan inclusion), AD-7 (MkDocs + Material + `mkdocs-include-markdown-plugin` stack) are binding.
- Python 3.9+ and `pip` are available on the developer's box; no guarantee that they are available in the auto-mode sandbox. Scripts in this task MUST NOT require an `mkdocs` installation to run — `mkdocs` is only needed at preview time via `scripts/wiki/wiki-serve.sh`.
- No existing `wiki/` directory under the repo root.

## Description

Create the `wiki/` directory skeleton that downstream P01 tasks (T02–T05) extend. Specifically:

1. `wiki/requirements.txt` — pinned dependencies for reproducible builds (Constitution constraint "MkDocs version pinned").
2. `wiki/mkdocs.yml` — minimal base config: site metadata, Material theme, include-markdown plugin block; the `nav:` block is intentionally absent here because T04 generates it. T03 will append include-plugin stubs under `wiki/docs/`; they are picked up once `nav:` exists.
3. `wiki/docs/index.md` — one-screen placeholder home page (P04 replaces the body).
4. `wiki/docs/README.md` — authoring note: stubs in this tree are auto-generated by `scripts/wiki/wiki-generate-stubs.sh`; do not hand-edit.
5. `wiki/README.md` — operator notes: install requirements, preview via `bash scripts/wiki/wiki-serve.sh`, regenerate stubs via `scripts/wiki/wiki-generate-stubs.sh`, regenerate nav via `scripts/wiki/wiki-generate-nav.sh`.
6. `wiki/.gitignore` — ignore `site/` (MkDocs build output) and any `.cache/` directory the toolchain may write.
7. `scripts/wiki/wiki-serve.sh` — Bash 3.2 single-script launcher. Default mode: `exec mkdocs serve -f wiki/mkdocs.yml` from the repo root (no `cd`). `--probe` mode: exec `mkdocs build -f wiki/mkdocs.yml --strict --site-dir /tmp/m012-probe-site-$$` then remove the output; this is what the `m012-p01-serve-smoke.sh` verify script calls so auto-mode never blocks on a listening port. `--help` prints usage.

No stubs are generated in this task. No nav is generated in this task. T02–T04 do that.

## Steps

1. **Create the `wiki/` directory tree**:

   ```
   wiki/
     .gitignore
     README.md
     requirements.txt
     mkdocs.yml
     docs/
       index.md
       README.md
   ```

2. **Write `wiki/requirements.txt`** with pinned versions. Use known-good pins as of 2026-04 (these are the last-published stable versions the team has used on adjacent projects; if a planning reviewer flags a newer pin, update, but pin exactly — no version ranges):

   ```
   mkdocs==1.6.1
   mkdocs-material==9.5.49
   mkdocs-include-markdown-plugin==7.1.2
   pymdown-extensions==10.14.3
   ```

   All four pins use `==`, not `>=` or `~=`. Pin-exact is mandatory for reproducibility (M012-CONTEXT "Version pinning for build determinism").

3. **Write `wiki/mkdocs.yml`** with the minimal base config. Leave `nav:` entirely out — T04 writes it. The include plugin is declared under `plugins:` so T03's stubs can reference it.

   ```yaml
   # wiki/mkdocs.yml — spec-kit-orchestrator dogfood wiki.
   #
   # This config is assembled across M012/P01 in stages:
   #   T01 writes this base (theme + plugins + exclusion markdown_extensions).
   #   T04 appends a nav: block referencing every in-scope .orchestrator/**.md
   #        artifact via include-plugin stubs under wiki/docs/.
   # Do not edit the nav: block by hand — regenerate via
   # scripts/wiki/wiki-generate-nav.sh.

   site_name: "spec-kit-orchestrator — dogfood wiki"
   site_description: "Browseable projection of .orchestrator/ artifacts for the dogfood team."
   site_url: "https://example.invalid/"  # placeholder; final URL set in P04.
   repo_url: "https://github.com/lakeledger/spec-kit-orchestrator"
   docs_dir: "docs"
   site_dir: "site"

   theme:
     name: material
     features:
       - navigation.sections
       - navigation.expand
       - navigation.indexes
       - navigation.top
       - search.suggest
       - search.highlight
       - content.code.copy

   plugins:
     - search
     - include-markdown

   markdown_extensions:
     - admonition
     - attr_list
     - def_list
     - footnotes
     - md_in_html
     - tables
     - toc:
         permalink: true
     - pymdownx.highlight
     - pymdownx.inlinehilite
     - pymdownx.superfences
     - pymdownx.snippets
     - pymdownx.tabbed:
         alternate_style: true

   # nav: block intentionally omitted here; regenerated by
   # scripts/wiki/wiki-generate-nav.sh in T04.
   ```

4. **Write `wiki/docs/index.md`** — placeholder home page (P04 replaces the body; the file path is stable so the nav generator can reference it):

   ```markdown
   ---
   title: "spec-kit-orchestrator dogfood wiki"
   ---

   # spec-kit-orchestrator dogfood wiki

   > **placeholder** — this home page is a P01 scaffold. Final orientation copy
   > ships in M012/P04 (Deploy pipeline, home page, first-deploy validation).

   This site is the **dogfood team's** browseable projection of the orchestrator's
   own `.orchestrator/` state: Constitution, Decisions, Knowledge, the
   milestone summary, and every milestone's plans and summaries.

   - Use the left navigation to reach Constitution / Decisions / Knowledge /
     Milestone Summary / Milestones / Archive.
   - Use the search box (top right) to find any rendered artifact.
   - Comment threads appear on every page (added in M012/P03).

   This is **not** a public-facing site. External launch lives in M009.
   ```

5. **Write `wiki/docs/README.md`** — auto-generation note:

   ```markdown
   # wiki/docs/ — auto-generated stubs

   Files under this directory (other than `index.md` and this README) are
   **auto-generated** by `scripts/wiki/wiki-generate-stubs.sh` and
   `scripts/wiki/wiki-generate-nav.sh`.

   Do not hand-edit stubs. Changes will be overwritten on the next regeneration.

   Source of truth remains `.orchestrator/**.md` — stubs reference canonical
   paths via `mkdocs-include-markdown-plugin` (M012 AD-3).

   To regenerate everything after an `.orchestrator/` change:

   ```
   bash scripts/wiki/wiki-generate-stubs.sh
   bash scripts/wiki/wiki-generate-nav.sh
   bash scripts/wiki/wiki-serve.sh --probe
   ```
   ```

6. **Write `wiki/README.md`** — operator notes:

   ```markdown
   # spec-kit-orchestrator wiki (M012)

   Dogfood-only MkDocs site that renders `.orchestrator/` artifacts.

   ## Install

   ```
   cd wiki
   python3 -m venv .venv
   . .venv/bin/activate
   pip install -r requirements.txt
   ```

   Pinned versions are authoritative; do not upgrade without a paired commit
   documenting why.

   ## Preview

   From the repo root:

   ```
   bash scripts/wiki/wiki-serve.sh
   ```

   This runs `mkdocs serve -f wiki/mkdocs.yml` and binds a local port.

   For a headless config-validation probe (used by auto-mode verify):

   ```
   bash scripts/wiki/wiki-serve.sh --probe
   ```

   ## Regenerate

   After any `.orchestrator/` change:

   ```
   bash scripts/wiki/wiki-generate-stubs.sh
   bash scripts/wiki/wiki-generate-nav.sh
   ```

   Source of truth: `.orchestrator/**.md`. Stubs never carry body content;
   they only `include-markdown` from the canonical path (M012 AD-3).

   ## Scope

   See `.orchestrator/milestones/M012/M012-CONTEXT.md` for the binding
   scope boundaries. Archive inclusion: all (AD-4). Giscus: added in P03.
   Deploy: `mkdocs gh-deploy --force` (wired in P04).
   ```

7. **Write `wiki/.gitignore`**:

   ```
   site/
   .cache/
   .venv/
   __pycache__/
   ```

8. **Create `scripts/wiki/` directory** (new top-level helper tree for wiki-specific scripts) and write `scripts/wiki/wiki-serve.sh`:

   ```bash
   #!/usr/bin/env bash
   # scripts/wiki/wiki-serve.sh — M012/P01 wiki preview launcher.
   #
   # Default mode: exec `mkdocs serve -f wiki/mkdocs.yml` from the repo root.
   #   Binds a local port; use Ctrl-C to exit.
   #
   # --probe mode: exec `mkdocs build -f wiki/mkdocs.yml --strict` into a
   #   throwaway site-dir, then remove the output. Used by verification to
   #   validate the config without binding a port or blocking the caller.
   #
   # --help: print usage.
   #
   # Exit 0 on success, non-zero on mkdocs error (propagated).
   # Bash 3.2 compatible. Single-script-file shape (no inline compounds).

   set -eu

   PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   CONFIG="$PROJECT_ROOT/wiki/mkdocs.yml"

   usage() {
     printf 'Usage: %s [--probe] [--help]\n' "$0"
     printf '\n'
     printf '  (default)   Run `mkdocs serve -f wiki/mkdocs.yml` — binds a local port.\n'
     printf '  --probe     Run `mkdocs build --strict` to a throwaway site-dir.\n'
     printf '  --help      Print this message.\n'
   }

   MODE="serve"
   if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
     usage
     exit 0
   fi
   if [ "${1:-}" = "--probe" ]; then
     MODE="probe"
   fi

   if [ ! -f "$CONFIG" ]; then
     printf 'FAIL: wiki/mkdocs.yml not found at %s\n' "$CONFIG" >&2
     exit 1
   fi

   if ! command -v mkdocs >/dev/null 2>&1; then
     printf 'FAIL: `mkdocs` not on PATH — run `pip install -r wiki/requirements.txt`.\n' >&2
     exit 2
   fi

   if [ "$MODE" = "probe" ]; then
     TMP_SITE="/tmp/m012-p01-probe-site-$$"
     mkdocs build -f "$CONFIG" --strict --site-dir "$TMP_SITE"
     rc=$?
     rm -rf "$TMP_SITE" 2>/dev/null || true
     exit "$rc"
   fi

   exec mkdocs serve -f "$CONFIG"
   ```

   Make it executable (`chmod 755 scripts/wiki/wiki-serve.sh`).

9. **Do NOT run `mkdocs`.** This task ships the skeleton only. T05 adds the verification gates; T05's `m012-p01-serve-smoke.sh` calls `wiki-serve.sh --probe` but also gracefully handles the case where mkdocs is not installed in the sandbox (it exits with a SKIP message, counted as pass for Tier 1 static verification, and flagged as Tier 4 UAT).

## Must-Haves

- `wiki/requirements.txt` has exactly four `==` pin lines.
- `wiki/mkdocs.yml` declares `theme: material`, includes `include-markdown` in `plugins:`, and does **not** contain a `nav:` key (T04 adds that).
- `wiki/docs/index.md` exists and contains the word `placeholder`.
- `wiki/docs/README.md` documents that stubs are auto-generated.
- `wiki/README.md` describes install, preview, regenerate.
- `wiki/.gitignore` includes `site/`.
- `scripts/wiki/wiki-serve.sh` is executable, accepts `--probe` and `--help`, and uses only Bash 3.2 constructs.
- Removing `wiki/` and `scripts/wiki/` from a scratch checkout leaves the orchestrator functional (tested by T05's `m012-p01-wiki-self-contained.sh`).

## Verification

- `bash scripts/verify/m012-p01-requirements-pinned.sh` (ships in T05) — asserts four `==` pins present.
- `bash scripts/verify/m012-p01-include-plugin.sh` (ships in T05) — asserts plugin declared (full plugin round-trip checked after T03).
- `bash scripts/verify/m012-p01-index-placeholder.sh` (ships in T05).
- `bash scripts/verify/m012-p01-wiki-self-contained.sh` (ships in T05).
- `bash scripts/verify/m012-p01-bash32-compat.sh` (ships in T05) — scans `scripts/wiki/wiki-serve.sh`.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P01` — after T05 seeds the verify scripts, confirms artifact paths + patterns.

Manual smoke check during this task (run once; do NOT embed as a Check):

1. `ls wiki/` — confirm all six expected files/dirs are present.
2. `bash scripts/wiki/wiki-serve.sh --help` — prints usage, exits 0.
3. If `mkdocs` is installed: `bash scripts/wiki/wiki-serve.sh --probe` — expect a strict-mode build to either succeed or fail on the deliberately-missing `nav:` block. Record which. T04 resolves this.

## Inputs

### From Previous Tasks

None — T01 is the first task of P01.

### From Disk (Pre-existing)

- `.orchestrator/milestones/M012/M012-CONTEXT.md` — AD-3 (include-plugin, no copies), AD-6 (nested plan inclusion), AD-7 (MkDocs + Material + include-plugin stack), version-pinning constraint.
- `.orchestrator/milestones/M012/M012-ROADMAP.md` — Boundary Map (file names, nav structure).
- `.orchestrator/memory/constitution.md` — Principle VI (State On Disk Is Truth), Principle VIII (Bash 3.2), Principle XV (no speculative complexity).
- Adjacent Bash 3.2 helper pattern — e.g. `scripts/state/derive-phase.sh` — for style reference (set -eu, PROJECT_ROOT derivation, `printf` for structured output).

## Constraints

- **Bash 3.2** — `scripts/wiki/wiki-serve.sh` uses no `declare -A`, no `mapfile`, no `${var^^}`, no `<(...)`, no `&>`. macOS baseline per MEM001.
- **No mkdocs invocation in this task** — shipping a skeleton does not require `mkdocs` on PATH. The `--probe` mode is for later verification use by T05.
- **No stubs, no nav** — T03 generates stubs; T04 generates nav. This task leaves both intentionally absent.
- **No symlinks, no copies** — AD-3. The skeleton does not pre-populate `wiki/docs/` with any reference to `.orchestrator/**.md`; that is T03's job via include-plugin stubs.
- **Single-script-file `Check:` shape (AD-19)** — every verify Check in the phase plan references one `scripts/verify/m012-p01-*.sh` script.
- **Self-contained `wiki/`** — the directory is independently removable (SC-10). Nothing outside `wiki/` and `scripts/wiki/` in this task creates a dependency on the wiki existing at any point.

## Expected Output

- `wiki/requirements.txt` with four `==` pins.
- `wiki/mkdocs.yml` ≥ 40 lines, no `nav:` key.
- `wiki/docs/index.md` with "placeholder" marker.
- `wiki/docs/README.md` authoring note.
- `wiki/README.md` operator notes.
- `wiki/.gitignore` ignoring `site/` and local venv / cache dirs.
- `scripts/wiki/wiki-serve.sh` executable, 3 modes (default / `--probe` / `--help`), Bash 3.2 compliant.

## State Context

- **Current State**: executing
- **Milestone**: M012
- **Phase**: P01
- **Task**: T01
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **Bash 3.2** — `scripts/wiki/wiki-serve.sh` uses no `declare -A`, no `mapfile`, no `${var^^}`, no `<(...)`, no `&>`. macOS baseline per MEM001.
- **No mkdocs invocation in this task** — shipping a skeleton does not require `mkdocs` on PATH. The `--probe` mode is for later verification use by T05.
- **No stubs, no nav** — T03 generates stubs; T04 generates nav. This task leaves both intentionally absent.
- **No symlinks, no copies** — AD-3. The skeleton does not pre-populate `wiki/docs/` with any reference to `.orchestrator/**.md`; that is T03's job via include-plugin stubs.
- **Single-script-file `Check:` shape (AD-19)** — every verify Check in the phase plan references one `scripts/verify/m012-p01-*.sh` script.
- **Self-contained `wiki/`** — the directory is independently removable (SC-10). Nothing outside `wiki/` and `scripts/wiki/` in this task creates a dependency on the wiki existing at any point.

### Acceptance Criteria

- `wiki/requirements.txt` has exactly four `==` pin lines.
- `wiki/mkdocs.yml` declares `theme: material`, includes `include-markdown` in `plugins:`, and does **not** contain a `nav:` key (T04 adds that).
- `wiki/docs/index.md` exists and contains the word `placeholder`.
- `wiki/docs/README.md` documents that stubs are auto-generated.
- `wiki/README.md` describes install, preview, regenerate.
- `wiki/.gitignore` includes `site/`.
- `scripts/wiki/wiki-serve.sh` is executable, accepts `--probe` and `--help`, and uses only Bash 3.2 constructs.
- Removing `wiki/` and `scripts/wiki/` from a scratch checkout leaves the orchestrator functional (tested by T05's `m012-p01-wiki-self-contained.sh`).

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