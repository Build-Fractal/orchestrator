---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T07 (Phase P05, Milestone M008)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (25 entries) | 19-588 | ~4900 | filtered |
| Decisions | 590-592 | ~100 | filtered |
| Constraints | 594-599 | ~100 | required |
| Scope | 601-629 | ~400 | required |
| Upstream Context | 631-694 | ~2600 | required |
| Task Plan | 696-823 | ~1700 | required |
| State Context | 825-831 | ~100 | required |
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
hit_count: 33
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
hit_count: 33
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
hit_count: 33
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
hit_count: 33
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
hit_count: 28
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
hit_count: 28
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
hit_count: 28
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
hit_count: 33
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
hit_count: 28
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
hit_count: 28
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
hit_count: 28
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
hit_count: 33
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
hit_count: 33
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
hit_count: 33
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
hit_count: 28
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
hit_count: 28
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
hit_count: 28
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
hit_count: 33
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
hit_count: 28
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
hit_count: 28
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
hit_count: 33
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
hit_count: 33
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
hit_count: 28
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
hit_count: 28
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
hit_count: 28
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

<!-- All Truth Check commands use single-script-file shape per AD-19. Each
     m008-p05-*.sh script under scripts/verify/ runs hermetically: it
     builds mktemp fixtures for HOME, never touches the real developer
     home, and exits 0 on pass / 1 on fail with PASS:/FAIL: prefixes per
     MEM001. -->

- detect-runtime.sh emits runtime= and confidence= key=value lines and never exits non-zero on unknown runtime.
  - Check: `bash scripts/verify/m008-p05-detect-runtime-output-shape.sh`
- detect-runtime.sh probes CLAUDECODE env, CURSOR_* env, CODEX_* env, and filesystem markers (.claude/, .cursor/, .codex/, ~/.claude, ~/.cursor, ~/.codex), and reports confidence=high when env and filesystem agree.
  - Check: `bash scripts/verify/m008-p05-detect-runtime-signal-coverage.sh`
- detect-runtime.sh returns runtime=unknown with confidence=low when no signals match, with exit code 0.
  - Check: `bash scripts/verify/m008-p05-detect-runtime-unknown-path.sh`
- Every runtime adapter (claude-code.sh, codex.sh, cursor.sh) supports three modes: --probe, --register [--dry-run], --hook-config, and emits PASS:/FAIL:/registered=true|false key=value lines on stdout.
  - Check: `bash scripts/verify/m008-p05-runtime-adapter-interface.sh`
- Every runtime adapter --register --dry-run emits the list of files it WOULD write to stdout with one `would_write=<path>` line per file and writes nothing to disk.
  - Check: `bash scripts/verify/m008-p05-runtime-adapter-dry-run.sh`

## Upstream Context


### P02 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P02"
parent: "M008"
milestone: "M008"
provides:
  - "templates/dispatch-result.md + templates/dispatch-error.md — structured dispatch result and error schemas, backend-registry.sh — auto-discovery of dispatch backend adapters with availability probing, local-agent.sh — Claude Code Agent tool backend adapter (probe + coordination boundary modes per MEM018), local-codex.sh — Codex CLI SDK backend adapter (probe mode + uniform interface fallback when codex absent), dispatch-interface.sh — uniform backend-agnostic dispatch entry point with filename-based routing and structured error synthesis, P02 Bash 3.2 compat scan + end-to-end dispatch pipeline integration test"
requires:
  - "none (independent task), none (independent task), from:P02/T01 what:dispatch-result.md schema, from:P02/T01 what:dispatch-result.md schema,from:P02/T01 what:dispatch-error.md schema, from:P02/T01 what:dispatch-result.md,from:P02/T01 what:dispatch-error.md,from:P02/T02 what:backend-registry.sh,from:P02/T03 what:local-agent.sh,from:P02/T04 what:local-codex.sh, from:P02/T02 what:backend-registry.sh,from:P02/T03 what:local-agent.sh,from:P02/T04 what:local-codex.sh,from:P02/T05 what:dispatch-interface.sh"
affects:
  - "P02/T02,P02/T03,P02/T04,P02/T05, P02/T05, P02/T05, P02/T05, P02/T06,P03/all,P05/all, P03/all"
key_files:
  - "templates/dispatch-result.md,templates/dispatch-error.md, scripts/dispatch/backend-registry.sh, scripts/dispatch/adapters/backend/local-agent.sh, scripts/dispatch/adapters/backend/local-codex.sh, scripts/dispatch/dispatch-interface.sh, scripts/verify/m008-p02-bash32-compat.sh,scripts/verify/m008-p02-integration-e2e.sh"
key_decisions:
  - "filename-based adapter routing — zero backend-specific code in core per SC-003"
patterns_established:
  - "structured dispatch result/error schemas — YAML frontmatter + markdown body — consumed by all backend adapters, filename-based adapter auto-discovery — anything in adapters/backend/*.sh is a registered backend (no central registry file), coordination-boundary adapter — adapter emits dispatch instructions for orchestrator agent layer because Agent tool is in-process, uniform-interface fallback — adapter always emits dispatch-result even when backend unavailable, with status=failure rather than exiting with error, uniform dispatch interface — single entry point, adapter resolution purely by filename, structured result on stdout and structured error on stderr with distinct exit codes, integration test verifies uniform interface end-to-end: registry -> interface -> adapter -> result parse"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P02/tasks/T01-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P02/tasks/T02-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P02/tasks/T03-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P02/tasks/T04-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P02/tasks/T05-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P02/tasks/T06-SUMMARY.md"
duration: "713m"
verification_result: "pass"
completed_at: "2026-04-14T15:41:57Z"
observability_surfaces:
  - "dispatch-interface.sh stdout (dispatch-result on success); dispatch-interface.sh stderr (dispatch-error on failure); backend-registry.sh stdout (backends_available, default_backend); adapter --probe stdout (available=true|false)"
---

Phase P02 delivered the uniform Dispatch Interface and two local backend adapters, establishing the extensibility seam for future cloud backends (M010). Created templates/dispatch-result.md (structured success schema: status, backend, dispatched_at, completed_at, duration_s + artifacts list) and templates/dispatch-error.md (structured error schema: error_type, retry_eligible, escalation + context). Created scripts/dispatch/backend-registry.sh implementing filename-based auto-discovery — adapters dropped into scripts/dispatch/adapters/backend/*.sh are automatically registered, eliminating any central registry file and satisfying FR-011. Built two adapters: local-agent.sh (Claude Code Agent tool coordination boundary per MEM018 — adapter emits dispatch instructions since Agent tool is in-process) and local-codex.sh (Codex CLI SDK adapter — probes binary availability, emits dispatch-result with status=failure when absent, preserving uniform interface). The core dispatch-interface.sh routes purely by filename (/<backend>.sh) with zero backend-specific branching — verified by a dedicated agnostic check — satisfying SC-003 (new backend addable with zero core edits). Distinct exit codes 2-6 for input_invalid / registry_error / backend_unavailable / backend_crashed / backend_malformed. Also fixed a latent parser bug in scripts/verify/check-must-haves.sh where grep -q misinterpreted patterns starting with '--' as options (added '--' separator). Patterns established: (1) filename-based adapter auto-discovery, (2) coordination-boundary adapter for in-process tools, (3) uniform-interface fallback (always emit dispatch-result even on backend unavailability), (4) structured result on stdout + structured error on stderr with distinct exit codes.


### P04 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P04"
parent: "M008"
milestone: "M008"
provides:
  - "resolve-root.sh — canonical orchestrator state root resolver with 5-rule precedence, detect-speckit.sh — spec-kit presence detection with integration mode toggle, config-system.sh — unified orchestrator config get/set/list with dot-notation nested keys, migrate-state.sh — hard one-shot .specify/orchestrator/ → .orchestrator/ migration tool with --dry-run, Surgical derive-phase.sh refactor (NOTE comment) + namespace-aliases.sh documentation generator, P04 Bash 3.2 compat scan + hermetic standalone e2e test proving SC-004"
requires:
  - "none (independent task), none (independent task), from:P04/T01 what:resolve-root.sh, from:P04/T01 what:resolve-root.sh, from:P04/T01 what:resolve-root.sh, from:P04/T01 what:resolve-root.sh,from:P04/T02 what:detect-speckit.sh,from:P04/T03 what:config-system.sh,from:P04/T04 what:migrate-state.sh,from:P04/T05 what:derive-phase.sh refactor+namespace-aliases.sh"
affects:
  - "P04/T03,P04/T04,P04/T05,P04/T06, P04/T06, P04/T06,P07/all, P04/T06,P07/all, P04/T06,P05/all, P05/all,P06/all,P07/all"
key_files:
  - "scripts/state/resolve-root.sh, scripts/state/detect-speckit.sh, scripts/state/config-system.sh, scripts/migrate/migrate-state.sh, scripts/state/derive-phase.sh,scripts/state/namespace-aliases.sh, scripts/verify/m008-p04-bash32-compat.sh,scripts/verify/m008-p04-standalone-e2e.sh"
key_decisions:
  - "read-only resolver — never creates directories; 5-rule precedence ensures backward compatibility bridge for .specify/orchestrator/, YAML-based config storage under resolved root; subcommand CLI interface (get/set/list), hard migration per project memory (no dual code paths) — move not copy, refuse populated destination, surgical documentation-only refactor of derive-phase.sh per Constitution XV (Surgical Precision); namespace-aliases.sh is a doc generator, not a runtime router"
patterns_established:
  - "pure resolver pattern — reads from env/config/filesystem, emits path to stdout, zero side effects, feature-toggle probe — inspects filesystem signals and env to produce integration_mode verdict, unified config subcommand CLI pattern with dot-notation key path resolution, hermetic migration test — always use mktemp -d fixtures, never run against live project trees, documentation-only surgical refactor preserving public interface and behavior, hermetic standalone e2e — runs full workflow in mktemp fixture with no spec-kit present, validates SC-004"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P04/tasks/T01-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P04/tasks/T02-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P04/tasks/T03-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P04/tasks/T04-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P04/tasks/T05-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P04/tasks/T06-SUMMARY.md"
duration: "50m"
verification_result: "pass"
completed_at: "2026-04-14T16:44:47Z"
observability_surfaces:
  - "resolve-root.sh stdout (resolved path) + --verbose (root= and source= lines); detect-speckit.sh stdout (speckit_installed + integration_mode); config-system.sh stdout (values); migrate-state.sh stdout (MIGRATED: or SKIP: messages)"
---

Phase P04 delivered state and namespace independence. Created scripts/state/resolve-root.sh — canonical root resolver with 5-rule precedence (ORCHESTRATOR_ROOT env → config.yml state_root → .orchestrator/ → .specify/orchestrator/ bridge → default .orchestrator/). Read-only; never creates directories. Created scripts/state/detect-speckit.sh that emits speckit_installed= and integration_mode= key=value pairs based on filesystem + PATH signals, with --force-disabled override. Created scripts/state/config-system.sh implementing unified get/set/list at <root>/config.yml with dot-notation nested keys (first writer of the resolved root). Created scripts/migrate/migrate-state.sh — hard one-shot mv-based migration from .specify/orchestrator/ to .orchestrator/, --dry-run supported, refuses to overwrite populated destination, cross-FS fallback. Applied surgical NOTE-only refactor to derive-phase.sh per Constitution XV (public interface preserved, regression test confirms existing callers work). Created scripts/state/namespace-aliases.sh as a doc-generator mapping speckit.orchestrator.* → orchestrator:* (not a runtime router). Hermetic standalone e2e in mktemp fixture validates SC-004: full pipeline completes in fresh project with no spec-kit, state lands under .orchestrator/ only. Patterns established: (1) pure resolver pattern (read-only, emits path, zero side effects), (2) subcommand CLI pattern with dot-notation keys, (3) hermetic migration tests (mktemp -d only, never touch live project), (4) surgical documentation-only refactor preserving public interface. Live .specify/orchestrator/ remains intact — migration is deferred to P07 init flow or manual invocation.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T07"
phase: "P05"
milestone: "M008"
name: "Bash 3.2 compat + integration e2e test"
depends_on: ["T01", "T02", "T03", "T04", "T05", "T06"]
---

## Prerequisites

All of T01–T06 complete:
- `scripts/dispatch/detect-runtime.sh`
- `scripts/dispatch/adapters/runtime/claude-code.sh`
- `scripts/dispatch/adapters/runtime/codex.sh`
- `scripts/dispatch/adapters/runtime/cursor.sh`
- `scripts/dispatch/adapters/format/native.sh`
- `scripts/dispatch/adapters/format/speckit.sh`

Target scripts to create:
- `scripts/verify/m008-p05-bash32-compat.sh`
- `scripts/verify/m008-p05-integration-e2e.sh`
- `scripts/verify/m008-p05-runtime-filename-discovery.sh`
- `scripts/verify/m008-p05-no-real-home-writes.sh`

## Description

Two orthogonal gates:

1. **Bash 3.2 compat scan** — verifies every script created in P05 is Bash 3.2 compatible (no `declare -A`, no `readarray`/`mapfile`, no `|&`). Copy the pattern from `scripts/verify/m008-p02-bash32-compat.sh`.

2. **Integration e2e** — exercises the full P05 pipeline in a hermetic environment:
   - Create `HOME=$(mktemp -d)` and `PROJECT_DIR=$(mktemp -d)` fixtures.
   - Run `detect-runtime.sh --force claude-code` and assert it emits `runtime=claude-code`.
   - Run `claude-code.sh --probe`, `codex.sh --probe`, `cursor.sh --probe` — each exits 0 with valid key=value output.
   - Run `claude-code.sh --register --dry-run` — assert it emits `would_write=` lines without writing.
   - Run `claude-code.sh --register` with hermetic HOME — assert `$HOME/.claude/commands/orchestrator-*.md` files are created.
   - Build a minimal native task-plan fixture; run `native.sh --read` on it — assert exit 0 and output contains `task:`.
   - Build a minimal spec-kit `tasks.md` fixture; run `speckit.sh --read` on it; pipe the output to `native.sh --read` via a tempfile (no process substitution per AD-19) — assert round-trip passes.
   - Finally, build a dispatch-ready payload + task-plan and feed to `scripts/dispatch/dispatch-interface.sh` from P02 (using `--backend local-agent` since that adapter always succeeds per P02 summary) — assert exit 0 and valid dispatch-result frontmatter.
   - Cleanup fixtures with `rm -rf` on the mktemp roots.

Plus two additional gates:

3. **Filename-discovery** — verifies `scripts/dispatch/adapters/runtime/` contains exactly the three expected adapter files, and that there is no central registry file listing them (mirrors P02's filename-discovery pattern).

4. **No-real-HOME-writes** — verifies that grepping P05 scripts does not find any literal `"$HOME/.claude"` or `"$HOME/.codex"` or `"$HOME/.cursor"` write paths OUTSIDE of the adapter scripts themselves (i.e., no P05 orchestrator code writes to the real developer HOME; only the adapters do, and only when `--register` is invoked with a hermetic fixture).

## Steps

1. Create `scripts/verify/m008-p05-bash32-compat.sh`. List the 6 P05 scripts in a bash-array. For each: grep for forbidden patterns (`^[[:space:]]*declare[[:space:]]+-A`, `^[[:space:]]*(readarray|mapfile)[[:space:]]`, `[^|]\|&[^|]`). Exit 1 on any hit. Final: `echo "PASS: all P05 scripts are Bash 3.2 compatible"`.

2. Create `scripts/verify/m008-p05-integration-e2e.sh`. Use `set -eu` + trap-based cleanup:
   ```
   tmpdir=$(mktemp -d)
   trap 'rm -rf "$tmpdir"' EXIT
   export HOME="$tmpdir/home"
   mkdir -p "$HOME"
   ```
   Sequentially invoke each script listed in the Description. Use simple if-statements (not process substitution) to assert expected output. After each assertion, print a `STEP: <n> PASS` line. Final `PASS: integration e2e`.

3. Create `scripts/verify/m008-p05-runtime-filename-discovery.sh`:
   - List `scripts/dispatch/adapters/runtime/*.sh` and assert exactly 3 files: claude-code.sh, codex.sh, cursor.sh.
   - Grep the repo for any literal `runtime-registry.yml` or `runtime-list.json` — must return nothing.

4. Create `scripts/verify/m008-p05-no-real-home-writes.sh`:
   - Grep P05 non-adapter files for `"\$HOME/\.claude"`, `"\$HOME/\.codex"` — must return nothing outside `scripts/dispatch/adapters/runtime/`.

5. `chmod +x` all four verify scripts.

## Must-Haves

- `scripts/verify/m008-p05-bash32-compat.sh` passes.
- `scripts/verify/m008-p05-integration-e2e.sh` passes.
- `scripts/verify/m008-p05-runtime-filename-discovery.sh` passes.
- `scripts/verify/m008-p05-no-real-home-writes.sh` passes.
- No write to the real `$HOME` occurs during any verification run.

## Verification

```
bash scripts/verify/m008-p05-bash32-compat.sh
bash scripts/verify/m008-p05-integration-e2e.sh
bash scripts/verify/m008-p05-runtime-filename-discovery.sh
bash scripts/verify/m008-p05-no-real-home-writes.sh
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M008/phases/P05
```

Expected: `PASS: ...` and exit 0 for each.

## Inputs

### From Previous Tasks

- `scripts/dispatch/detect-runtime.sh` (T01)
  - Key API: emits `runtime=` / `confidence=` on stdout, exits 0.
- `scripts/dispatch/adapters/runtime/claude-code.sh` (T02)
  - Key API: `--probe | --register [--dry-run] | --hook-config`.
- `scripts/dispatch/adapters/runtime/codex.sh` (T03)
  - Key API: `--probe | --register [--dry-run] | --hook-config`.
- `scripts/dispatch/adapters/runtime/cursor.sh` (T04)
  - Key API: `--probe | --register [--dry-run] --project-dir <path> | --hook-config`.
- `scripts/dispatch/adapters/format/native.sh` (T05)
  - Key API: `--probe | --read <path> | --write <path>`; `--read` returns exit 0 with valid native frontmatter.
- `scripts/dispatch/adapters/format/speckit.sh` (T06)
  - Key API: `--probe | --read <path>`; emits native-shape output that round-trips through native.sh --read.

### From Disk (Pre-existing)

- `scripts/dispatch/dispatch-interface.sh` (P02) — called in integration test with `--backend local-agent`.
- `scripts/verify/m008-p02-bash32-compat.sh` — reference for the compat scan pattern.
- `scripts/verify/check-must-haves.sh` — phase-level verification entry point.

## Constraints

- AD-19 compliance: all `Check:` invocations are single-script-file shape. Do NOT use process substitution `<(...)`, command substitution with pipes `$(cmd | ...)`, or compound `bash -c '...' && bash -c '...'` in verify scripts. Use sequential statements and tempfiles instead.
- All integration fixtures are `mktemp -d`; cleanup via `trap`.
- NEVER invoke adapter `--register` against the real HOME during verification.
- Bash 3.2 compatible.

## Expected Output

- All four new verify scripts exist and are executable.
- Running the full verify sequence for P05 emits `PASS:` lines and exits 0.
- `scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M008/phases/P05` reports all must-haves satisfied.

## State Context

- **Current State**: executing
- **Milestone**: M008
- **Phase**: P05
- **Task**: T07
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