---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T05 (Phase P01, Milestone M012)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (25 entries) | 20-589 | ~4900 | filtered |
| Decisions | 591-593 | ~100 | filtered |
| Constraints | 595-628 | ~400 | required |
| Scope | 630-658 | ~400 | required |
| Upstream Context | 660-662 | ~100 | required |
| Task Plan | 664-955 | ~3800 | required |
| State Context | 957-963 | ~100 | required |
| First-Turn Completeness | 965-1012 | ~700 | required |
| **Total** | | **~10500** | |

## Knowledge

<!-- 25 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 314
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
hit_count: 314
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
hit_count: 314
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
hit_count: 314
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
hit_count: 283
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
hit_count: 283
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
hit_count: 283
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
hit_count: 314
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
hit_count: 283
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
hit_count: 283
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
hit_count: 283
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
hit_count: 314
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
hit_count: 314
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
hit_count: 314
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
hit_count: 283
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
hit_count: 283
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
hit_count: 283
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
hit_count: 314
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
hit_count: 283
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
hit_count: 283
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
hit_count: 314
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
hit_count: 314
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
hit_count: 283
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
hit_count: 283
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
hit_count: 283
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
task: "T05"
phase: "P01"
milestone: "M012"
name: "Phase verification suite — nine gates + phase-suite orchestrator"
depends_on: ["T04"]
---

## Prerequisites

- T01–T04 complete: `wiki/` skeleton, scanner, stub generator, nav generator all shipped. `wiki/docs/**` is populated. `wiki/mkdocs.yml` has the marker-bounded `nav:` block.
- No M012/P01 verify scripts exist yet.

## Description

Ship the full P01 verification suite. One script per phase-plan Truth `Check:` entry, plus the phase-suite orchestrator that runs them all. Each script is a single-invocation shape (AD-19 compliant so auto-mode never prompts). Scripts read-only except for the phase-suite orchestrator, which creates a summary file in a `/tmp` scratch location for its own reporting but does not touch repo state.

Nine gates:

1. `m012-p01-wiki-self-contained.sh` — `wiki/` + `scripts/wiki/` together are removable without breaking the orchestrator's own tests.
2. `m012-p01-requirements-pinned.sh` — `wiki/requirements.txt` has ≥ 4 `==` pins; no `>=`, no `~=`, no open ranges.
3. `m012-p01-include-plugin.sh` — every stub under `wiki/docs/` carries an `include-markdown` directive referencing an existing `.orchestrator/**.md` path.
4. `m012-p01-ssot.sh` — no stub's body reproduces canonical content: every stub is ≤ 25 lines, every stub has at most one `include-markdown` directive, and for each stub the referenced canonical file exists.
5. `m012-p01-exclusion-policy.sh` — scanner output (and therefore the generated stubs + nav) contains zero paths under `.orchestrator/scratch/`, `.orchestrator/tmp/`, `.orchestrator/config/`, and zero non-`.md` paths.
6. `m012-p01-nav-structure.sh` — `wiki/mkdocs.yml` contains a `nav:` block between the M012-P01 markers; top-level entries appear in order Home / Constitution / Decisions / Knowledge / Milestone Summary / Milestones / Archive; every scanner record has a matching nav leaf.
7. `m012-p01-serve-smoke.sh` — runs `bash scripts/wiki/wiki-serve.sh --probe`. If mkdocs is not on PATH, exits 0 with a `SKIP:` message (Tier 1 static only; Tier 4 UAT covers it). Otherwise relies on mkdocs strict build.
8. `m012-p01-index-placeholder.sh` — `wiki/docs/index.md` exists, contains the word `placeholder`, is ≤ 30 lines.
9. `m012-p01-bash32-compat.sh` — every `.sh` file under `scripts/wiki/` and `scripts/verify/m012-p01-*.sh` is free of `declare -A`, `mapfile`, `${var^^}`, `<(...)`, `&>`, Bash 4-only features. Excludes inline comments that mention these strings by requiring the match to be non-comment code.

Plus the orchestrator:

10. `m012-p01-phase-suite.sh` — invokes all nine gates in order, prints a pass/fail line per gate, exits 0 only if all nine pass.

## Steps

1. **Create `scripts/verify/m012-p01-wiki-self-contained.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p01-wiki-self-contained.sh — M012/P01 SC-10 gate.
   #
   # Asserts wiki/ and scripts/wiki/ are the only places M012 P01 code lives,
   # so removing those trees does not break the orchestrator itself.
   #
   # Check list:
   #   1. wiki/ exists and contains mkdocs.yml, requirements.txt, docs/.
   #   2. scripts/wiki/ exists and contains wiki-scan-sources.sh,
   #      wiki-generate-stubs.sh, wiki-generate-nav.sh, wiki-serve.sh.
   #   3. No file outside wiki/, scripts/wiki/, scripts/verify/m012-p01-*.sh,
   #      and .orchestrator/milestones/M012/ imports / sources a wiki script.
   #
   # Bash 3.2 compatible. Single-script-file shape.
   ```

   Use `grep -rl 'scripts/wiki/'` (ignoring `wiki/`, `scripts/wiki/`, `scripts/verify/m012-p01-`, `.orchestrator/milestones/M012/`). Any hit → FAIL.

2. **Create `scripts/verify/m012-p01-requirements-pinned.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p01-requirements-pinned.sh — asserts exact-pin discipline.
   # Requires ≥4 lines of shape `<pkg>==<ver>`. No `>=`, `~=`, `<`, empty version.
   ```

   Use `grep -c '^[a-zA-Z0-9_-]\+==' wiki/requirements.txt` ≥ 4, and `grep -E '(>=|~=|<|!=)' wiki/requirements.txt` must emit nothing.

3. **Create `scripts/verify/m012-p01-include-plugin.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p01-include-plugin.sh — every stub references an
   # existing .orchestrator/**.md path via include-markdown.
   #
   # 1. wiki/mkdocs.yml has `include-markdown` listed under `plugins:`.
   # 2. For every .md under wiki/docs/ that is NOT wiki/docs/index.md,
   #    wiki/docs/README.md, or a section-index `index.md`, the file
   #    contains `include-markdown "<path>"`. Extract <path>, resolve
   #    against the stub's directory, confirm the target file exists.
   ```

   Use `find wiki/docs -type f -name '*.md'`, filter out the three exclusions, extract each `include-markdown` path, resolve and stat. FAIL on any miss.

4. **Create `scripts/verify/m012-p01-ssot.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p01-ssot.sh — no duplicate artifact bodies.
   #
   # For every stub under wiki/docs/:
   #   - Line count ≤ 25.
   #   - Exactly one `include-markdown` directive, OR zero (section indexes).
   #   - No raw body beyond frontmatter + comment + include directive + bullets.
   #
   # Additional: no file under wiki/docs/ has a byte-identical match to any
   # file under .orchestrator/ (SSOT enforcement — no silent copies).
   ```

   Use `wc -l` per stub (note: avoid `$()` with pipe in Checks, but this is inside the verify script itself — MEM004 carve-out). SSOT compare via `cmp` file-to-file for suspiciously large stubs (>25 lines): since they shouldn't exist at all, the line-count gate is the primary guard; the byte-compare check is belt-and-suspenders.

5. **Create `scripts/verify/m012-p01-exclusion-policy.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p01-exclusion-policy.sh — scanner emits no excluded paths.
   #
   # Runs bash scripts/wiki/wiki-scan-sources.sh and asserts:
   #   - Zero lines contain `.orchestrator/scratch/`.
   #   - Zero lines contain `.orchestrator/tmp/`.
   #   - Zero lines contain `.orchestrator/config/`.
   #   - Every line's rel-path ends in `.md`.
   #   - No rel-path contains `PLANNING-PAYLOAD` or `VERIFICATION`.
   #   - Every rel-path starts with `.orchestrator/`.
   #
   # Also asserts wiki/docs/**.md stubs (via include-markdown refs) do not
   # reference any excluded path.
   ```

6. **Create `scripts/verify/m012-p01-nav-structure.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p01-nav-structure.sh — nav top-level + completeness.
   #
   # Checks:
   #   1. wiki/mkdocs.yml has exactly one `nav:` at column 0.
   #   2. The marker pair `# >>> M012-P01 nav ...` / `# <<< M012-P01 nav end`
   #      both appear, once each.
   #   3. Top-level nav labels (Home, Constitution, Decisions, Knowledge,
   #      Milestone Summary, Milestones, Archive) appear in order within
   #      the marker region.
   #   4. For every scanner record, the corresponding stub path appears at
   #      least once in the nav block (asserts completeness).
   ```

   Use `awk` with a state machine bounded by markers to extract the nav block, then grep for each label in order.

7. **Create `scripts/verify/m012-p01-serve-smoke.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p01-serve-smoke.sh — mkdocs strict build probe.
   #
   # Runs `bash scripts/wiki/wiki-serve.sh --probe` and checks exit code.
   # If mkdocs is not on PATH, emits `SKIP: mkdocs not installed` and exits 0.
   # The skip is Tier 1 acceptable; UAT (Tier 4) exercises the actual build.
   ```

   Use `command -v mkdocs` to detect; skip-exit on miss.

8. **Create `scripts/verify/m012-p01-index-placeholder.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p01-index-placeholder.sh — index.md is a placeholder.
   # Checks: file exists, contains "placeholder", ≤ 30 lines.
   ```

9. **Create `scripts/verify/m012-p01-bash32-compat.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p01-bash32-compat.sh — scans P01-touched .sh files.
   #
   # Target set:
   #   scripts/wiki/wiki-scan-sources.sh
   #   scripts/wiki/wiki-generate-stubs.sh
   #   scripts/wiki/wiki-generate-nav.sh
   #   scripts/wiki/wiki-serve.sh
   #   scripts/verify/m012-p01-*.sh   (this script is self-inclusive)
   #
   # Forbidden patterns (match non-comment, non-string code):
   #   declare -A
   #   mapfile
   #   readarray
   #   ${var^^} / ${var,,}
   #   <(...)   (process substitution)
   #   >(...)   (process substitution)
   #   &>       (Bash 4 merge redirect)
   #
   # Emits FAIL: <file>:<line> <pattern> per hit. PASS with count otherwise.
   ```

   Use `grep -nE` against each file. Filter out lines that match `^[[:space:]]*#` (comments). Accept that string-literal occurrences are rare enough that a comment filter is sufficient; false positives here are acceptable because fix is trivial (paraphrase the mention).

10. **Create `scripts/verify/m012-p01-phase-suite.sh`** — the orchestrator:

    ```bash
    #!/usr/bin/env bash
    # scripts/verify/m012-p01-phase-suite.sh — orchestrates all nine M012/P01 gates.
    #
    # Runs each gate script as a subprocess and aggregates results.
    # Emits one `GATE: <name> PASS|FAIL` line per gate to stdout.
    # Prints `SUMMARY: <passed>/<total> gates passed` at end (stderr).
    # Exit 0 iff all nine gates exit 0.
    #
    # Bash 3.2 compatible. Single-script-file shape (no compound bash).
    ```

    Use a simple indexed-array of script basenames and a plain `for name in "${gates[@]}"; do ... done` loop — NOT inside a Check command (Checks invoke this script; the loop inside the script is fine).

    ```bash
    gates=(
      "m012-p01-wiki-self-contained.sh"
      "m012-p01-requirements-pinned.sh"
      "m012-p01-include-plugin.sh"
      "m012-p01-ssot.sh"
      "m012-p01-exclusion-policy.sh"
      "m012-p01-nav-structure.sh"
      "m012-p01-serve-smoke.sh"
      "m012-p01-index-placeholder.sh"
      "m012-p01-bash32-compat.sh"
    )
    passed=0
    total=${#gates[@]}
    for g in "${gates[@]}"; do
      if bash "$PROJECT_ROOT/scripts/verify/$g"; then
        printf 'GATE: %s PASS\n' "$g"
        passed=$((passed + 1))
      else
        printf 'GATE: %s FAIL\n' "$g"
      fi
    done
    printf 'SUMMARY: %d/%d gates passed\n' "$passed" "$total" >&2
    [ "$passed" -eq "$total" ]
    ```

11. **Mark every verify script executable** (`chmod 755`).

12. **Smoke-run the phase-suite once** (manual; do NOT embed as a Check): `bash scripts/verify/m012-p01-phase-suite.sh` — expect `9/9 gates passed`. If one fails, fix the underlying T01–T04 output until all pass.

## Must-Haves

- All nine gate scripts exist under `scripts/verify/m012-p01-*.sh` and are executable.
- `scripts/verify/m012-p01-phase-suite.sh` exists and is executable.
- Every gate is a single-invocation Bash 3.2 script — no compound bash, no subshell compound commands, no `$()` containing pipes in the Check command layer.
- Running `bash scripts/verify/m012-p01-phase-suite.sh` against the T01–T04 output exits 0.
- Every gate emits `PASS: <name> ...` on success to stdout and `FAIL: <name> ...` with a pointer on failure.
- `scripts/verify/m012-p01-serve-smoke.sh` gracefully SKIPs when `mkdocs` is not installed.

## Verification

- `bash scripts/verify/m012-p01-phase-suite.sh` — the suite's own exit code is the phase's exit code.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P01` — confirms artifact paths + patterns (every verify script file appears in the Artifacts section with min-lines + pattern).
- Self-test: run the phase-suite twice in a row; exit code must be identical (no hidden state).

Manual smoke check during this task (run once; do NOT embed as a Check):

1. `bash scripts/verify/m012-p01-phase-suite.sh` — expect 9/9 green.
2. Temporarily rename `wiki/mkdocs.yml` away; rerun — expect `m012-p01-include-plugin.sh` (or another config-dependent gate) to FAIL. Restore.
3. Temporarily add an extra body paragraph to one stub; rerun — expect `m012-p01-ssot.sh` to FAIL on the line-count threshold. Revert.

## Inputs

### From Previous Tasks

- **T01**: `wiki/requirements.txt`, `wiki/mkdocs.yml` (base), `wiki/docs/index.md`, `scripts/wiki/wiki-serve.sh`.
- **T02**: `scripts/wiki/wiki-scan-sources.sh` — contract as documented in T02.
- **T03**: `wiki/docs/**/*.md` stubs — each ≤ 25 lines, each with exactly one `include-markdown` directive; section indexes with lightweight bullet lists.
- **T04**: `wiki/mkdocs.yml` now has the marker-bounded `nav:` block with Home / Constitution / Decisions / Knowledge / Milestone Summary / Milestones / Archive top-level order.

### Scanner Output Contract (reproduced for zero-context execution)

- Line format: `<category>|<rel-path>|<title>`.
- Category enum: `top:constitution`, `top:decisions`, `top:knowledge`, `top:milestone-summary`, `milestone:<M###>`, `archive:<M###>`.
- No line contains `.orchestrator/scratch/`, `.orchestrator/tmp/`, `.orchestrator/config/`.
- Every `<rel-path>` ends in `.md` and starts with `.orchestrator/`.

### From Disk (Pre-existing)

- [`.orchestrator/milestones/M012/M012-ROADMAP.md`](../../../../milestones/M012/M012-ROADMAP.md) — ground truth for the Boundary Map (nav structure, exclusion policy).
- `.orchestrator/memory/constitution.md` — Principle VI (SSOT) + Principle VIII (Bash 3.2).

## Constraints

- **Bash 3.2** — every verify script. MEM001.
- **MEM004 carve-out** — these are verification scripts, not agent-facing content; pipes, `$()`, `awk` are allowed inside the scripts.
- **Single-script-file `Check:` shape (AD-19)** — every Truth `Check:` in P01-PLAN.md invokes one `bash scripts/verify/m012-p01-*.sh`. The logic inside the script can use whatever internal Bash it wants, bounded by the bash-3.2 compat gate.
- **Read-only** — gates never modify repo state. The phase-suite may write to `/tmp/` for intermediate state; that is acceptable and is cleaned on exit via `trap`.
- **Graceful skip for missing `mkdocs`** — the serve-smoke gate must not hard-fail on a sandbox without mkdocs; it emits `SKIP:` and exits 0. This keeps auto-mode progress on CI boxes that don't have mkdocs installed; Tier 4 UAT exercises the real thing.
- **Deterministic** — same T01–T04 output → same exit code across runs.
- **No global state** — each gate is independently invokable. The phase-suite orchestrator is optional scaffolding, not a dependency of individual gates.

## Expected Output

- Ten `.sh` files under `scripts/verify/` with `m012-p01-*` prefix, all executable, all Bash 3.2 compliant.
- `bash scripts/verify/m012-p01-phase-suite.sh` exits 0 against clean T01–T04 output.
- Each gate, run individually, emits `PASS:`/`FAIL:` structured output and exits 0/1 deterministically.
- Removing any single verify script causes the phase-suite to FAIL on that gate without side effects on the other eight.

## State Context

- **Current State**: executing
- **Milestone**: M012
- **Phase**: P01
- **Task**: T05
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **Bash 3.2** — every verify script. MEM001.
- **MEM004 carve-out** — these are verification scripts, not agent-facing content; pipes, `$()`, `awk` are allowed inside the scripts.
- **Single-script-file `Check:` shape (AD-19)** — every Truth `Check:` in P01-PLAN.md invokes one `bash scripts/verify/m012-p01-*.sh`. The logic inside the script can use whatever internal Bash it wants, bounded by the bash-3.2 compat gate.
- **Read-only** — gates never modify repo state. The phase-suite may write to `/tmp/` for intermediate state; that is acceptable and is cleaned on exit via `trap`.
- **Graceful skip for missing `mkdocs`** — the serve-smoke gate must not hard-fail on a sandbox without mkdocs; it emits `SKIP:` and exits 0. This keeps auto-mode progress on CI boxes that don't have mkdocs installed; Tier 4 UAT exercises the real thing.
- **Deterministic** — same T01–T04 output → same exit code across runs.
- **No global state** — each gate is independently invokable. The phase-suite orchestrator is optional scaffolding, not a dependency of individual gates.

### Acceptance Criteria

- All nine gate scripts exist under `scripts/verify/m012-p01-*.sh` and are executable.
- `scripts/verify/m012-p01-phase-suite.sh` exists and is executable.
- Every gate is a single-invocation Bash 3.2 script — no compound bash, no subshell compound commands, no `$()` containing pipes in the Check command layer.
- Running `bash scripts/verify/m012-p01-phase-suite.sh` against the T01–T04 output exits 0.
- Every gate emits `PASS: <name> ...` on success to stdout and `FAIL: <name> ...` with a pointer on failure.
- `scripts/verify/m012-p01-serve-smoke.sh` gracefully SKIPs when `mkdocs` is not installed.

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