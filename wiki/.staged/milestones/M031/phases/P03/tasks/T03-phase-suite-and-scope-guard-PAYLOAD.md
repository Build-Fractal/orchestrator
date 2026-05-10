---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T03-phase-suite-and-scope-guard (Phase P03, Milestone M031)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~1000 | required |
| Upstream Context | 981-1106 | ~7300 | required |
| Task Plan | 1108-1322 | ~4000 | required |
| State Context | 1324-1330 | ~100 | required |
| First-Turn Completeness | 1332-1381 | ~800 | required |
| **Total** | | **~24000** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 708
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
hit_count: 708
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
hit_count: 708
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
scope_tags: "[project], [milestone:[M005](../../../../../milestones/M005/index.md)]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 708
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
hit_count: 620
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
hit_count: 620
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
hit_count: 620
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
hit_count: 708
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
scope_tags: "[project], [milestone:[M006](../../../../../milestones/M006/index.md)]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 620
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
hit_count: 620
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
scope_tags: "[project], [milestone:[M002](../../../../../milestones/M002/index.md)]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 620
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
hit_count: 708
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
hit_count: 708
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
hit_count: 708
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
hit_count: 620
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
hit_count: 620
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
hit_count: 620
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
hit_count: 708
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
hit_count: 620
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
hit_count: 620
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
hit_count: 708
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
hit_count: 708
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
scope_tags: "[project], [milestone:[M004](../../../../../milestones/M004/index.md)]"
category: lessons
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 620
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
hit_count: 620
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
hit_count: 620
source_unit: "M004/P06"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM023, MEM024]
content_hash: ""
---

# MEM025: Verification Script Grep Patterns

Verification helper scripts that grep for library sourcing should use broad patterns (e.g. `errors\.sh`) not narrow literal patterns (e.g. `lib/errors\.sh`). Scripts may source libs via variable expansion (`$_LIB_DIR/errors.sh`) which does not match the literal path. The broader pattern still uniquely identifies the sourcing intent.

---
id: MEM026
scope_tags: "[project], [milestone:[M025](../../../../../milestones/M025/index.md)]"
category: lessons
confidence: 0.95
created_at: 2026-04-23
last_verified: 2026-04-23
hit_count: 275
source_unit: "M025/P01"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM027]
content_hash: ""
---

# MEM026: M013/P04/T04 hook-config regression

## What regressed

Commit `d33b8a7` (M013/P04/T04) shipped a `scripts/dispatch/adapters/runtime/claude-code.sh --hook-config` emitter whose root object carried wrapper metadata (`runtime`, `hook_count`, `target_file`) alongside orchestrator-internal event names (`before_tasks`, `after_tasks`, `before_implement`, `after_implement`, `before_commit`, `post_verify`) that Claude Code does not recognize. The companion installer `packaging/install/install-claude-code.sh` wrote that invalid document unconditionally to `$HOME/.claude/settings.json`, overwriting any sibling tool's configuration (notably GSD-authored `statusLine`, `SessionStart`, `PostToolUse`, and `permissions` keys) with no merge path and no reversibility.

## Why P04 gates missed it

Every P04 verification script — including `scripts/verify/m013-p04-post-verify-hook.sh` — ran against an empty `$HOME/.claude/` fixture. No gate seeded a pre-existing non-orchestrator `settings.json`, so the overwrite path was never exercised. The schema-validity failure was invisible because CC itself was not invoked against the emitted document in any P04 gate; the gates only asserted presence of the wrapper JSON's internal keys, not conformance to the CC `hooks` schema. The regression required a real user on a real multi-tool system to observe.

## Lesson

Every user-scope config write — `~/.claude/settings.json`, `~/.codex/*.toml`, `~/.cursor/*.json`, shell rc files, git hooks paths, and anything else jointly owned with sibling tools — requires a coexistence gate driven by a pre-seeded non-orchestrator fixture (pattern realized by M025 at `tests/fixtures/m025-p01/gsd-baseline/`). Empty-home fixtures are insufficient: they cannot surface overwrite damage or schema-shape issues that only manifest when the host tool actually parses the file. Pair the coexistence gate with (a) a round-trip reversibility gate (install → uninstall → sha256 byte-match) and (b) an idempotency gate (double-install → sha256 byte-match) to lock the invariant triad.

---
id: MEM027
scope_tags: "[project], [milestone:M025]"
category: patterns
confidence: 0.90
created_at: 2026-04-23
last_verified: 2026-04-23
hit_count: 275
source_unit: "M025/P01"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM026]
content_hash: ""
---

# MEM027: merge-not-overwrite user-scope config

## Problem

User-scope config files (`~/.claude/settings.json`, `~/.codex/*.toml`, `~/.cursor/*.json`, shell rc files, git `core.hooksPath`) are jointly owned by multiple tools — the host runtime itself, sibling workflow tools (GSD, spec-kit, orchestrator), user hand-edits, and corporate MDM policy. Any installer that writes these files with `printf > "$file"` or `cp` silently destroys sibling configurations and user edits. The regression surfaced at M013/P04/T04 (see MEM026) made this concrete: the orchestrator clobbered GSD's `statusLine`, `SessionStart`, and `PostToolUse` hooks with no warning and no rollback.

## Pattern: merge-not-overwrite

Every orchestrator user-scope config write obeys four rules:

1. **Inline ownership tag.** Every orchestrator-inserted leaf object carries `"_orchestrator_managed": true`. No sidecar manifest — the tag travels with the data, so uninstall works even if the manifest is lost and copy-paste of config snippets between machines stays honest.
2. **jq-optional merge with structural fallback.** Detect `jq` via `command -v jq`. Under jq, use `jq -S` for deterministic sorted-key output. Without jq, fall back to a `python3`-driven merge (or a bash-3.2-compatible awk script) that preserves every non-orchestrator key byte-identically at the structural level — semantic equivalence is the contract, not byte-identity across the jq/fallback boundary.
3. **Temp-file-then-rename atomicity.** Write to `$target.tmp.$$`, fsync-equivalent via `mv -f`. Never write the target file in place; a half-written settings.json can lock a user out of their host runtime.
4. **`--uninstall` strips only tagged entries, with cascade cleanup.** Remove only objects whose `_orchestrator_managed` is `true`; if that leaves a wrapper with an empty `hooks` array, remove the wrapper; if that leaves an event key with an empty array, remove the event key; if that leaves `hooks` empty, remove the `hooks` key. Every other key in the target is preserved byte-identically.

## Gate shape

The pattern is enforced by a three-gate triad — any user-scope config write without all three gates fails review:

- **Coexistence fixture.** Pre-seed a representative non-orchestrator config shape (e.g. `tests/fixtures/m025-p01/gsd-baseline/settings.json`), run the installer, compare the result against a pinned `expected-post-install.json` via structural (not byte-identity) comparator.
- **Round-trip reversibility.** Capture the pre-install sha256, run install then uninstall, capture the post-uninstall sha256, assert byte-identity against both the pre-install sum and a pinned `expected-post-uninstall.sha256`.
- **Idempotency.** Run the installer twice in succession, assert the post-first-install and post-second-install sha256 match. No accretion of duplicate orchestrator entries.

---
id: MEM028
scope_tags: "[project], [milestone:[M014](../../../../../milestones/M014/index.md)], [concern:bash-compat]"
category: lessons
confidence: 0.95
created_at: 2026-04-23
last_verified: 2026-04-23
hit_count: 275
source_unit: "M014/P01"
source_type: dogfood
supersedes: ""
superseded_by: ""
relates_to: []
content_hash: ""
---

# MEM028: Bash arithmetic silently interprets zero-padded numerics as octal

## What regressed

`scripts/specify/specify.sh:336` computed the next spec number as `NEXT=$((HIGHEST + 1))` where `HIGHEST` was a zero-padded prefix parsed from existing directory names (`024-foo/` → `HIGHEST=024`). Bash arithmetic treats `024` as octal (= decimal 20), so `NEXT` became `21` and the next spec landed as `specs/021-<slug>/` rather than `025-<slug>/`. The bug is silent on octal-valid digits (0–7) and hard-errors (`value too great for base`) on `008`/`009`/`018`/`019`/etc.

Historical damage: M025's spec landed at `specs/021-github-installer-coexistence/` instead of `specs/025-*` (bug pre-dated this fix; renaming deferred since all M025 artifacts reference the `021-` path consistently and the milestone is closed). A smoke-test fixture `specs/021-yn-test/` was also cleaned up as leaked state from a pre-hermetic verifier run.

## Why the FR-18 shape test missed it

`tests/test-specify-shape.sh` runs in a hermetic scratch whose `specs/` starts empty, so `HIGHEST=0` and `NEXT=1` — the zero-padded octal ambiguity never triggers. Shape tests asserted Section Contract conformance, not number-allocator correctness. The gap was: the allocator was exercised only in production where the bug finally surfaced on a real M014/P01 dogfood run.

## Lesson

In bash, never put a zero-padded external string directly into `$((...))`. Force base-10 with the `10#` prefix:

```bash
# Broken — octal interpretation
NEXT=$((HIGHEST + 1))

# Correct — explicit base-10
NEXT=$((10#$HIGHEST + 1))
```

The `10#` prefix is portable across Bash 3.2+ and is the canonical idiom for parsing numerics that may carry leading zeros. Apply it to any arithmetic whose inputs come from (a) directory-name parsing, (b) `printf '%03d'` round-trips, (c) date-field components (`$(date +%H)` returns `08` at 8am), or (d) user-supplied strings.

Regression coverage: `tests/test-specify-number-allocator.sh` pre-seeds a scratch `specs/` with `008/009/024` sentinels and asserts the expected `009/010/025` outputs. Any future allocator that consumes zero-padded input belongs in that test's fixture matrix.

## Related

- M014/P01 ships the allocator; the dogfood-first-use revealed the bug. The fix is a one-character change (the `10#` prefix) but the lesson generalizes to any bash script handling numeric directory names, ISO date fields, or versioned filenames.
- This is a cousin of the Bash 3.2 discipline codified in CON-6 (anti-pattern lint) — both are "bash looks like it works, until input shape tripwires a latent feature."

---
id: MEM029
scope_tags: "[project], [milestone:[M026](../../../../../milestones/M026/index.md)]"
category: patterns
confidence: 0.90
created_at: 2026-04-24
last_verified: 2026-04-24
hit_count: 284
source_unit: "M026/P02"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM018, MEM030]
content_hash: ""
---

# MEM029: Edition-resolution two-tier detection (env-var primary, metadata-probe fallback)

## Problem

When an installed package has multiple distributable builds (OSS vs paid, dev vs prod, community vs enterprise) that share a single PyPI/npm/etc. package name and venv install path, path-based detection is infeasible — both editions install to the same canonical path under pip/pipx/npm. A consumer that needs to know which edition is currently active (for routing decisions, edition-aware diagnostics, or telemetry) cannot rely on the binary path alone.

The M026 conversus migration surfaced this concretely: both `~/Sites/conversus-oss` (OSS) and `~/Sites/conversus` (paid) publish as the `conversus` PyPI package and install to `~/.local/pipx/venvs/conversus/`. A path-difference check at the `~/Sites/` level is fragile (operators may install via pipx-only with no source clone, or install via brew, or develop one tree and install the other) and fails entirely under the single-venv reality.

## Pattern: two-tier detection

1. **Primary signal — operator declaration via env var**. A `<TOOL>_EDITION=<value>` env var is the operator's declarative signal. The consumer trusts the declaration without further probing. This makes the active edition explicit, audit-trail-visible (env-var is logged with the dispatch), and portable across host-OS and install-method differences. Bad values (typos) emit a single-line stderr warning and fall through to tier 2 — never silently accept a bad declaration.

2. **Fallback — runtime metadata probe**. When the env var is unset, query the package's installed metadata (`pip show <pkg>` for Python; `npm ls <pkg> --json` for Node; equivalent registry probes for other ecosystems). Parse a stable identifying field (`Home-page:` for Python pip; `repository.url` for Node) and key on a canonical substring (e.g., `*-oss` in the URL). The probe is read-only, side-effect-free, and runs under the consumer's existing subprocess discipline. On probe failure (subprocess fails, field absent, value unrecognized), emit `edition=unknown reason=metadata-probe-failed` rather than guessing.

3. **Short-circuit cases**. Stub mode (test-only) is edition-agnostic by design — emit `edition=unknown reason=stub` without probing. Operator-supplied absolute overrides (e.g., `<TOOL>_HOME`) attempt the metadata probe at that location but fall through to `edition=unknown reason=home` if the probe fails — the operator already knows what they pointed at.

## Output contract

The consumer's edition resolver emits two structured stdout lines per resolution: `edition=<oss|paid|unknown>` and `reason=<env-override|metadata-probe|metadata-probe-failed|stub|home|command-v|fallback>`. Line ordering is the verifiable contract. Warnings (e.g., bad env-var value) go to stderr. The same stdout shape is consumed downstream by JSONL emitters (M026/P02/T02 pattern) and by edition-aware-diagnostic refusal blocks (M026/P03/T01 pattern).

## Gate shape

- **Edition-detection contract test** (e.g., `scripts/verify/m026-p02-edition-detection-contract.sh`): exercise every resolver branch (env-override, stub, metadata-probe, metadata-probe-failed) and assert the `edition=`/`reason=` line ordering and values.
- **Stderr/stdout discipline** (cross-cuts MEM015 DOCTOR Structured Output Protocol): structured fields go to stdout in fixed line order; warnings go to stderr; never cross-contaminate.
- **Bash 3.2 compatibility**: probe subprocess via plain `"$venv_py" -m pip show <pkg>` — no process substitution, no command-substitution-containing-pipes.

## Reusable beyond M026

- Distinguishing editions of any pip/pipx-installed Python tool that publishes under one package name across multiple build channels.
- Distinguishing runtime modes of MCP servers where the binary is the same but the active configuration tier differs.
- Distinguishing local development vs CI installations where path differs but the operator's declarative intent is the load-bearing signal.

See: `scripts/dispatch/adapters/tool/conversus.sh` `_resolve_edition` for the canonical implementation; MEM030 for the paired env-var naming convention.

---
id: MEM030
scope_tags: "[project], [milestone:M026]"
category: conventions
confidence: 0.90
created_at: 2026-04-24
last_verified: 2026-04-24
hit_count: 284
source_unit: "M026/P02"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM018, MEM029]
content_hash: ""
---

# MEM030: `<TOOL>_EDITION=<value>` env-var convention for OSS-default escape hatches

## Problem

When an orchestrator integration flips its default from a paid build to an OSS build, the operator still needs a discoverable, undestructive way to reach the paid build for one-off invocations (debugging a paid-only feature, reproducing a paid-build regression, running a preset that depends on paid-only upstream plumbing). Three anti-patterns to avoid:

1. **Path-only escape** — requiring the operator to set `<TOOL>_HOME=/explicit/path/to/paid/build` per invocation. Undiscoverable, easy to forget, and brittle across machines with different install paths.
2. **Magic-value escape** — using a generic feature flag like `USE_PAID=1` or `LEGACY_MODE=1`. Doesn't express edition intent, doesn't compose with other build-channel distinctions, and is inconsistent across tools.
3. **No escape** — routing all paid-only access through a separate command or wrapper. Forces the orchestrator to maintain two parallel invocation paths with the same surface, doubling test burden.

## Convention: `<TOOL>_EDITION=<edition-name>`

1. **Naming**: `<TOOL>_EDITION` (uppercase tool name + literal `_EDITION` suffix). Examples: `CONVERSUS_EDITION`, `<NEWTOOL>_EDITION`. Reads naturally in shell history, in JSONL telemetry, and in operator-facing error messages.

2. **Values**: closed enum `oss|paid` (or analogous closed enum for non-OSS-vs-paid distinctions like `community|enterprise` or `free|pro`). Enforce the closed enum with a stderr warning on unrecognized values; fall through to the metadata probe (see MEM029) rather than silently accepting.

3. **Precedence**: env-var declaration is **primary**. Metadata-probe fallback is secondary. Operator-supplied absolute overrides (`<TOOL>_HOME`) trump both — they're an explicit "use exactly this binary" instruction. Resolver order from highest to lowest precedence: STUB (test-only) → PATH (`command -v`) → `<TOOL>_HOME` → `<TOOL>_EDITION`-aware user-local probe.

4. **Diagnostic surface**: the `check` subcommand of the integration's adapter MUST emit `edition=<value> reason=<resolution-tag>` on stdout so the resolved edition is visible to the operator and to telemetry without a separate probe call.

5. **Telemetry shape**: every JSONL record emitted by the integration adapter MUST include an `edition` field alongside the existing identifying fields (e.g., `adapter_version`, `gate_id`). Place adjacent to the version field for readability and for adjacency-invariant tests (M026/P02/T02 pattern).

6. **Refusal diagnostic**: when an upstream artifact (preset, config, manifest) declares `edition_required: <edition>` and the resolved edition does not match, the integration MUST refuse the invocation BEFORE any heavy work, with a stderr diagnostic naming both the requirement and the escape — `<TOOL>_EDITION=<required-edition>` (M026/P03 FR-11 pattern).

## Why a convention

The M026 migration is the first OSS-default escape-hatch landing in this repo. Future migrations (e.g., when M010 ships and the orchestrator starts integrating with multiple LLM-provider editions, or when M023 ships and design-renderer adapters need to distinguish freemium tier vs paid tier) will face the same shape. Naming it as a convention now means the next migration can copy the pattern verbatim instead of re-deliberating the env-var name in each milestone.

## Gate shape

- **Env-var-name lint** (advisory): a future `scripts/diagnostics/check-edition-conventions.sh` could grep adapter-tree env-var references and flag any non-`<TOOL>_EDITION`-shaped escape-hatch names.
- **JSONL `edition` field presence**: every `*_invocation` record from an edition-aware adapter MUST contain an `edition` field. Verify with `scripts/verify/m026-p02-jsonl-edition-field.sh` (existing) — extend the pattern when adding a second edition-aware adapter.
- **Refusal regex stability**: `paid-only.*<TOOL>_EDITION=paid` (case-insensitive) is the SC-7 contract for paid-only-on-OSS refusals; preserve verbatim across tools so operator runbooks transfer.

See: `scripts/dispatch/adapters/tool/conversus.sh` for the canonical implementation; MEM029 for the paired two-tier-detection pattern.

---
id: MEM031
scope_tags: "[project], [milestone:[M020](../../../../../milestones/M020/index.md)]"
category: conventions
confidence: 0.90
created_at: 2026-04-25
last_verified: 2026-04-25
hit_count: 274
source_unit: "M020/P01"
source_type: schema-evolution
supersedes: ""
superseded_by: ""
relates_to: [MEM013, MEM014]
content_hash: ""
---

# MEM031: Knowledge entry `status:` field vocabulary (M020 schema evolution)

## Convention

Every `knowledge/**/MEM*.md` and `knowledge/spec/**` entry carries a
`status:` frontmatter field with one of three values from a **closed enum**:

| Value       | Meaning                                                                 |
|-------------|-------------------------------------------------------------------------|
| `candidate` | Tentative — written by a dispatch or operator, not yet reviewed.        |
| `graduated` | Reviewed and accepted; visible to the default query surface (FR-2).     |
| `archived`  | Reviewed and rejected, OR superseded by a graduated canonical entry.    |

Closed-enum discipline: any value outside `candidate | graduated | archived`
is a schema violation and MUST be rejected by the schema-lint gate landing
in P02 (`scripts/verify/knowledge-schema-lint.sh`, FR-9 + SC-8). Adding a
fourth state (e.g. `deprecated`) requires a follow-up M020 D-row that
extends the enum and updates this note — see D024 reversibility clause (a).

## Default semantics for pre-M020 entries

Entries that exist on main without a `status:` field are treated as `graduated` on first read (most conservative — do not re-review what was
already implicitly trusted). The field is written on next touch by
`scripts/knowledge/lib/frontmatter.sh` per FR-10. **No bulk migration pass
is performed in M020** (NG-3): the schema fills in lazily as entries are
edited, archived, graduated, or otherwise mutated by knowledge tooling.

## Companion fields

Two paired fields land in the same schema evolution and are documented
together for cohesion:

- `decision_history:` — append-only YAML list of records. Each record is a
  YAML map containing `rationale: <text>`, `timestamp: <ISO 8601 UTC>`,
  `operator: <identifier>`, `cluster_id: <id-or-empty>`. Written by
  `graduate.sh` (P03 cluster-aware path) and `archive` operations.
  Append-only invariant: existing records are never edited or removed in
  place. Compaction is deferred (NG-6); a future D-row will define
  compaction rules if list length crosses the operability threshold (>50
  records per entry per D024 reversibility clause (b)).
- `archived_into: <entry-id>` — single canonical entry-ID back-reference
  written when an entry is archived as a sibling of a graduated canonical
  entry within a cluster. Empty / absent for outright-rejection archives
  (the entry was not subsumed into another canonical record, just retired).

## Authority

M020 holds exclusive schema authority over these fields per FR-9. Consuming
milestones ([M024](../../../../../milestones/M024/index.md) universal intake, [M019](../../../../../milestones/M019/index.md) Tier 2+3 observability) MAY READ
the fields but MUST NOT introduce new fields without a follow-up M020 D-row.
The handshake is: open an M020 D-row → M020 lands the schema change →
consuming milestone uses the field. Never bypass this gate.

## Authorising decision

[`.orchestrator/DECISIONS.md`](../../../../../decisions.md) D024 (2026-04-25).

## Verification

- `scripts/verify/m020-p01-mem031-vocabulary.sh` checks the closed enum and
  the pre-M020 default are documented verbatim.
- `scripts/verify/m020-p01-d024-row.sh` checks the D024 row exists with the
  load-bearing tokens.
- `scripts/verify/knowledge-schema-lint.sh` (lands in P02 per FR-9 + SC-8)
  enforces the schema-authority boundary at lint time.

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

### Branch Discipline

You inherit the git branch the dispatcher is sitting on. Commit your work
on that branch.

- Do NOT `git checkout`, `git switch`, `git branch`, `git merge`, or
  `git rebase` to a different branch unless your task plan explicitly
  requires it.
- Do NOT create a new branch as a side-effect of "isolating" your work
  — git worktrees handle that at the dispatcher layer when configured.
- If you genuinely believe a side-branch is required (e.g. the task plan
  calls for a hotfix branch), STOP and report rather than acting
  unilaterally. The dispatcher will tell you whether to proceed.

This rule exists because branch switches inside a dispatched task are
invisible to the dispatcher audit trail and have caused mid-loop
confusion (commits landing on a branch the operator did not expect,
then being merged opaquely).

## Scope

### Goal


### Demo


### Must-Haves
## Must-Haves

<!-- All Check commands use single-script-file shape per AD-19.
     Project-owned slug-bearing verifiers live under tools/verify/ per
     [M032](../../../../../milestones/M032/index.md) Finding A. Verifier scripts are co-authored alongside their
     corresponding artifact within the SAME task (plan-time discipline
     rule 2). Namespacing: `m031-p03-*` prefix avoids collision with
     [M030](../../../../../milestones/M030/index.md)'s `p02-*` and M031's `m031-p01-*` / `m031-p02-*` verifiers in
     the shared tools/verify/ tree. -->

### Truths

- `commands/do.md` exists with YAML frontmatter (`description: "Use when ..."`) and a body documenting the universal entry skill registered as `orchestrator:do <task>` (per AD-6 — verbless `orchestrator <task>` reserved for post-M009 runtime parity; CC at launch ships the `do` form because CC slash-commands are verb-prefixed). The body MUST describe the four routing branches by name (`tier_a_plus` → P02 router; high-confidence Tier A degenerate → Quick-profile single dispatch; Tier B/C → passthrough to `orchestrator:specify` / `orchestrator:evaluate`; low-confidence → explicit Tier A vs Tier B prompt) and reference the backing script `scripts/intake/do-entry.sh` in a Referenced Scripts section per MEM012.
  - Check: `bash tools/verify/m031-p03-do-md-shape.sh`

- `scripts/intake/do-entry.sh` exists, is executable, and implements the FR-10 / FR-11 / FR-12 / FR-13 contract: (a) accepts `--task <description>` (required), `--yes`, `--no-prompt-mode <A|B|C>` (test-only, mirroring the P02 prompt helper bypass), `--dispatch-stub <script>` (test-only seam), `--scratch-root <dir>` (test-only override of `.orchestrator/tier-a-plus/`), `--config <path>` (test-only override of `.orchestrator/config.yml`); (b) invokes `bash scripts/intake/shape-detect.sh --input <task>` and parses `input_shape=<verdict>` + `shape_classification=<high|low>`; (c) maps `high` → `1.0` and `low` → `0.5` and compares against `entry_routing_confidence_floor` from active config (P00 default `0.7`); (d) routes per branch table: `tier_a_plus` → exec `route-to-dispatch.sh --verdict tier_a_plus --task <desc> [--yes] [--dispatch-stub <stub>] [--scratch-root <dir>]`; high-confidence `idea` or `paragraph` → fast-path single dispatch (Quick profile); `fragment` / `spec` / long `paragraph` (Tier B/C) → emit one stderr line `route=tier_bc passthrough=orchestrator:specify` and exit 0 without firing a dispatch from the entry script; low-confidence (numeric < floor) → emit explicit Tier A vs Tier B prompt and record the chosen shape in the captured JSONL `unit_close` record. Bash 3.2 compatible (MEM001).
  - Check: `bash tools/verify/m031-p03-do-entry-shape.sh`

- For the high-confidence Tier A degenerate fast-path branch, `scripts/intake/do-entry.sh` invokes `bash scripts/dispatch/build-context.sh --profile=quick --task-plan <task-plan-path> --out <payload-path> --meta-out <sidecar-path>` (P01 direct-mode driver shape) AND emits exactly one stderr line of shape `doing: <task> — knowledge: <N> MEMs / <X> tokens` where `<N>` is the `mem_count` field from the AD-11 sidecar JSON and `<X>` is the `total_tokens` field (FR-12). Zero approval prompts on the fast-path. The dispatch surface invocation seam is `--dispatch-stub` for testing — when the stub flag is present the entry script invokes the stub script with positional arguments `(branch=tier_a_degenerate, task, payload-path, meta-out-path)` and stops; when the stub flag is absent the production path invokes the agent-runtime handoff (per MEM018 — the agent IS the adapter; the entry script writes the payload + sidecar to disk and emits the summary line, then returns control). The fast-path emits ZERO scaffold-placeholder marker bracket-TODO byte patterns on stdout/stderr (CON-7 / D020).
  - Check: `bash tools/verify/m031-p03-fastpath-shape.sh`

<dispatch-volatile>

## Upstream Context


### P01 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M031"
milestone: "M031"
provides:
  - "build-context.sh new --profile and --meta-out flags (FR-2 + AD-11),direct-mode --task-plan/--out invocation,AD-11 5-key JSON sidecar,additive payload_breakdown JSONL fields,3 m031-p01 verifiers under tools/verify/,post-m031-emitter wrapper sibling-symmetric with pre-m031-stub,post-m031-baseline.jsonl frozen artifact (20 records under post-m031 path with non-zero knowledge_section_tokens),FR-4 single-line amendment to commands/dispatch.md:21 closing the AD-14 single-window,2 m031-p01 verifiers under tools/verify/ (post-baseline-jsonl-population + dispatch-md-reconciliation),SC-1/SC-2/SC-3/SC-15 acceptance tests under tests/m031-acceptance/ + 4 corresponding shape verifiers under tools/verify/m031-p01-test-*-shape.sh; all 4 verifiers exit 0 with pass>=6 fail=0; SC tests gate the schema commitments per AD-11/AD-13/AD-17/AD-18 against the T01 direct-mode build-context.sh emitter contract,m031-p01-phase-suite.sh aggregator (9 sub-gates straight-line AD-19); m031-p01-scope-guard.sh SC-12 block-list verifier"
requires:
  - "P00"
affects:
  - "P02,P03,P04"
key_files:
  - "scripts/dispatch/build-context.sh,tools/verify/m031-p01-build-context-profile-shape.sh,tools/verify/m031-p01-quick-no-skip-branch.sh,tools/verify/m031-p01-config-knobs-stable.sh,tests/m031-acceptance/fixtures/empirical-baseline/post-m031-emitter.sh,tests/m031-acceptance/fixtures/empirical-baseline/post-m031-baseline.jsonl,commands/dispatch.md,tools/verify/m031-p01-post-baseline-jsonl-population.sh,tools/verify/m031-p01-dispatch-md-reconciliation.sh,tests/m031-acceptance/test-quick-injects-knowledge.sh,tests/m031-acceptance/test-build-context-profile.sh,tests/m031-acceptance/test-compression-applies-to-quick.sh,tests/m031-acceptance/test-quick-budget-median.sh,tools/verify/m031-p01-test-quick-injects-knowledge-shape.sh,tools/verify/m031-p01-test-build-context-profile-shape.sh,tools/verify/m031-p01-test-compression-applies-to-quick-shape.sh,tools/verify/m031-p01-test-quick-budget-median-shape.sh,tools/verify/m031-p01-phase-suite.sh,tools/verify/m031-p01-scope-guard.sh"
key_decisions:
  - "AD-11 5-key sidecar schema landed verbatim,AD-14 single-window preserved (commands/dispatch.md untouched),AD-19 single-script Truth Check shape for all 3 verifiers,direct-mode bypasses milestone/phase/task derivation when --task-plan supplied,positional-mode meta-out emit wired into both planning branch and payload_breakdown emitter so AD-11 fires on every code path,token-estimator reuse via chars_to_tokens_quartile from scripts/lib/pricing.sh,AD-14 single-window order discipline obeyed (capture BEFORE FR-4 amendment),knowledge_section_tokens reported as sidecar total_tokens (Knowledge section dominates Quick payload size),temp payload + sidecar cleaned per-task (JSONL is the durable artifact),FR-4 replacement preserves intensity-table shape with single-line diff (Quick row only),verifier carries header guard against future polarity flip mirroring P00 inverted-polarity convention,SC tests gate schema commitments (CON-1 invariant slots) rather than runtime-firing values when T01 direct mode does not yet wire compression into the Quick path; matches the explicit proxy-substitution pattern the task plan documents for SC-15 (Note); SC-1 OR-clause empty-cache-hit branch satisfied by knowledge_section_tokens:0 record; T03 leaves T01 deliverables untouched per task-plan constraints,none (T04 is purely additive verifier authoring; no decision packets)"
patterns_established:
  - "additive flag-stacking on legacy positional CLIs,direct-mode short-circuit pattern,inverted-polarity verifier guarding CON-1 invariant,sidecar emission at two call sites for forked exit paths,post-stub sibling-symmetric emitter pattern (same JSONL schema as pre-stub except path + non-zero knowledge_section_tokens + compression flags from sidecar),direct-mode build-context driver pattern (bash build-context.sh --profile=quick --task-plan FIXTURE --out TMP --meta-out TMP),inverted-polarity verifier on prose surface (assert ABSENCE of Skip payload assembly with explicit header guard),FR-4 single-line table-row amendment via Edit (single-line diff discipline for SC-12 scope-guard),AD-14 capture-before-amend ordering as a normative step list (step 3 verification gates step 4 destructive edit),schema-commitment SC tests (gate field-presence + literal substring contracts; runtime-firing values gate when downstream tasks wire the surface);RESULT: SC-N pass envelope on SC tests vs SUMMARY: <verifier> pass=N fail=M envelope on shape verifiers (two distinct AD-19 conventions);proxy-substitution documented inline in file header (mirrors P00 SC-15 Note pattern);direct-mode-execution-log.jsonl pre/post line-count delta as freshness gate,P01 phase-suite mirrors P00 straight-line nine-gate aggregation pattern (AD-19); SC-12 scope-guard surfaces working-tree noise from cross-milestone hit_count touches"
drill_down_paths:
  - "[.orchestrator/milestones/M031/phases/P01/tasks/T01-build-context-profile-SUMMARY.md](../../../../../milestones/M031/phases/P01/tasks/T01-build-context-profile-SUMMARY.md), [.orchestrator/milestones/M031/phases/P01/tasks/T02-ad14-capture-and-fr4-SUMMARY.md](../../../../../milestones/M031/phases/P01/tasks/T02-ad14-capture-and-fr4-SUMMARY.md), [.orchestrator/milestones/M031/phases/P01/tasks/T03-acceptance-tests-SUMMARY.md](../../../../../milestones/M031/phases/P01/tasks/T03-acceptance-tests-SUMMARY.md), [.orchestrator/milestones/M031/phases/P01/tasks/T04-SUMMARY.md](../../../../../milestones/M031/phases/P01/tasks/T04-SUMMARY.md)"
duration: "270m"
verification_result: "pass"
completed_at: "2026-05-01T17:47:36Z"
observability_surfaces:
  - "none"
---

## What Was Built

P01 closes the **AD-14 single-capture window** for Quick-profile dispatch. Before P01, `commands/dispatch.md:21` carried a Quick skip-knowledge branch that bypassed `build-context.sh`; that branch is gone post-P01. The four-task ordering was load-bearing: T01 made `build-context.sh` Quick-aware (additive only, no caller change); T02 captured the post-M031 baseline with both code paths live, then amended `commands/dispatch.md`; T03 shipped the SC-1/SC-2/SC-3/SC-15 acceptance tests against the AD-15 corpus; T04 aggregated the 9-gate phase-suite and shipped the SC-12 scope-guard.

- **T01 (build-context-profile):** Additive `--profile=quick|standard|full`, `--task-plan`, `--out`, `--meta-out` flags on `scripts/dispatch/build-context.sh` (+271/-2). Direct-mode short-circuit bypasses milestone/phase/task derivation when `--task-plan` is supplied. AD-11 5-key JSON sidecar (`mem_count`, `total_tokens`, `profile`, `compression_applied`, `snip_applied`) emitted at both planning-branch and payload_breakdown call sites so AD-11 fires on every exit path. Quote one CON-1 invariant: every dispatch path emits one `payload_breakdown` JSONL record. `commands/dispatch.md` untouched in T01 — that's T02's job.
- **T02 (ad14-capture-and-fr4):** Authored `post-m031-emitter.sh` sibling-symmetric with `pre-m031-stub.sh`. Captured `post-m031-baseline.jsonl` (20 records, all `path:"post-m031"`, all non-zero `knowledge_section_tokens`) by running `empirical-baseline.sh --post-m031-emitter` while both code paths were still live. THEN amended `commands/dispatch.md:21` (single-line FR-4 diff: "Skip payload assembly" gone, "Quick profile" present). The order is normative — T02 step 3 verification gates step 4 destructive edit.
- **T03 (acceptance-tests):** Shipped 4 SC scripts (`test-quick-injects-knowledge.sh` SC-1, `test-build-context-profile.sh` SC-2/AD-13, `test-compression-applies-to-quick.sh` SC-3/AD-17, `test-quick-budget-median.sh` SC-15/AD-18) plus 4 corresponding shape verifiers under `tools/verify/m031-p01-test-*-shape.sh`. Schema-commitment gating chosen over runtime-firing checks because T01's direct-mode does not yet wire [M018](../../../../../milestones/M018/index.md) compression into the Quick path; the proxy substitution is documented inline in each SC file header per the P00 SC-15 Note pattern.
- **T04 (phase-suite-and-scope-guard):** `m031-p01-phase-suite.sh` aggregates the 9 P01 sub-gates straight-line (AD-19 compliant, mirrors P00 phase-suite pattern). `m031-p01-scope-guard.sh` enforces SC-12 block-list with a MEM `hit_count`-only carve-out (added during T04 remediation — orchestrator-emitted MEM hit_count drift on `knowledge/(conventions|lessons|patterns)/MEM*.md` is a dispatch side-effect, not a manual scope violation; the carve-out logic checks every changed line matches `^[+-]hit_count: [0-9]+$` before excluding).

Mid-phase remediation:
- **MEM hit_count carve-out** (T04) — scope-guard reported 31 false-positive block-list violations from cross-session `hit_count` drift. Carve-out added; verifier now reports `pass=33 fail=0 block_list_violations=0 mem_hitcount_carveouts=31`.
- **Phase-level key-link doc references** — `scripts/dispatch/build-context.sh` was missing literal-string references to `templates/orchestrator-config-default.yml` and `references/RUNTIME-ASSUMPTIONS.md` required by the phase plan's Key Links. Added a `# Key links (M031/P01):` comment block near the top of the script body.

## Key Decisions

- **AD-14 capture-before-amend ordering** is now a normative step-list pattern (T02 step 3 gates step 4). Future destructive surface modifications follow this template.
- **Direct-mode bypasses derivation** — when `--task-plan FIXTURE` is supplied, `build-context.sh` skips milestone/phase/task path resolution. This is the harness-driving shape that lets `empirical-baseline.sh` invoke build-context against arbitrary fixtures without standing up a milestone tree.
- **Schema-commitment SC tests** — when downstream surfaces don't yet emit runtime-firing values, SC tests gate on field/key presence + literal substring contracts and document the proxy substitution inline. Gate tightens automatically when downstream tasks wire the runtime path.
- **Two distinct envelope conventions** — `RESULT: SC-N pass` for acceptance tests, `SUMMARY: <verifier> pass=N fail=M` for shape verifiers. Both AD-19 compliant; downstream consumers can grep either.
- **MEM hit_count carve-out** as a documented exception class — scope-guards in future milestones with similar dispatch side-effects can adopt the same `^[+-]hit_count: [0-9]+$` line-content check.

## Patterns Established

- Additive flag-stacking on legacy positional CLIs (preserve all existing call sites; new flags trail).
- Direct-mode short-circuit pattern (one `if` branch at the top of the script that bypasses canonical resolution when a fixture flag is present).
- Sidecar emission at every fork (every exit path emits the AD-11 sidecar so observability is invariant).
- Post-stub sibling-symmetric emitter pattern (same JSONL schema as pre-stub except `path` + non-zero `knowledge_section_tokens` + compression flags from sidecar).
- Inverted-polarity verifier on prose surface (assert ABSENCE of "Skip payload assembly" with explicit header guard against future polarity flips).
- FR-4 single-line table-row amendment via Edit (single-line diff discipline for SC-12 scope-guard cleanliness).
- Phase-suite straight-line N-gate aggregation (mirrors P00 pattern, AD-19 compliant, no array loops).
- SC-12 scope-guard with carve-out helpers for known-orchestrator-emitted side-effect classes.

## Verification

- `m031-p01-phase-suite.sh pass=9 fail=0` — all 9 sub-gates green.
- `m031-p01-scope-guard.sh pass=33 fail=0 block_list_violations=0 mem_hitcount_carveouts=31` — clean post-carve-out.
- `check-must-haves.sh` 77 PASS / 0 FAIL — all phase-level Truths, Artifacts, and Key Links satisfied.
- `check-boundary-map.sh` SKIP — boundary-map produce items not declared at P01 grain (foundation-style; will tighten at P04).
- External-mods WARN list ([M036](../../../../../milestones/M036/index.md), CLAUDE.md, spec 033) is pre-existing session-entry dirty-tree state, not P01 modification.

## Forward-Looking Notes for P02+

- AD-15 corpus is now stable on disk with both pre- and post-M031 baseline JSONL captures; P02–P04 SC verifiers can grep either.
- T03 SC tests gate schema slots; when M018 compression eventually wires into Quick-profile direct-mode, the gates will tighten automatically without test rewrite.
- Pre-existing M036 / CLAUDE.md / spec-033 working-tree drift should be committed onto a separate housekeeping commit before P02 close to keep the scope-guard signal clean.


### P02 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P02"
parent: "M031"
milestone: "M031"
provides:
  - "scripts/intake/shape-detect.sh extended with tier_a_plus verdict (FR-6,30-80 word zero-structural-marker band),scripts/intake/paragraph-classify.sh annotated with tier_a_plus literal token,tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md (AD-16 normative grounding citing 2 historical unit_close records),tests/m031-acceptance/fixtures/tier-a-plus-input.txt (62-word fixture paraphrased from M031/P01/T01),tests/m031-acceptance/test-tier-a-plus-classifier.sh (SC-5 acceptance test),4 m031-p02 shape verifiers under tools/verify/,scripts/intake/lib/task-slug.sh sourceable derive_task_slug function (AD-10 40-char base slug + 4-char SHA-1 collision suffix + untitled empty-input fallback),templates/dispatch-role-research.md (96 lines prescriptive read-only research-role contract producing research.md with Findings Open Questions Recommended Approach),templates/dispatch-role-plan.md (93 lines prescriptive plan-authoring contract producing PLAN.md with Steps Verification Inputs Files Likely Touched),templates/dispatch-role-build.md (93 lines prescriptive executor contract reading plan.md and running Verification inline with no implicit retry),tools/verify/m031-p02-task-slug-shape.sh (10 checks AD-19 single-script Truth Check),tools/verify/m031-p02-role-templates-shape.sh (21 checks AD-19 single-script Truth Check),scripts/intake/lib/tier-a-plus-prompt.sh sourceable + directly-invokable AD-7 + AD-20 Tier A+ approval prompt helper (273 lines bash 3.2 compatible -- _tap_read_summary_lines _tap_resume_marker _tap_emit_audit _tap_emit_prompt_body tier_a_plus_prompt + direct-invocation dispatcher),tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh (203 lines SC-16 acceptance test exercising all seven AD-20 UX-protocol clauses),tools/verify/m031-p02-prompt-shape.sh (16 checks AD-19 single-script Truth Check for the helper),tools/verify/m031-p02-test-tier-a-plus-prompt-ux-shape.sh (12 checks AD-19 single-script Truth Check for the SC-16 test),route-to-dispatch.sh extended additively with --verdict tier_a_plus mode (research/approval/plan/build chain via Quick-profile build-context.sh + role templates),unit_close JSONL schema additions tier_a_plus_role and aborted (additive optional fields),--dispatch-stub seam for SC-6 acceptance test,SC-6 end-to-end acceptance test tests/m031-acceptance/test-tier-a-plus-flow.sh,m031-p02-router-shape.sh + m031-p02-test-tier-a-plus-flow-shape.sh shape verifiers under tools/verify/,tools/verify/m031-p02-phase-suite.sh,tools/verify/m031-p02-scope-guard.sh,11-gate phase-suite straight-line aggregator,SC-12 scope-guard with dual-prefix permissive carve-out (.orchestrator/observability + .orchestrator/tier-a-plus),MEM hit_count carve-out inherited verbatim from P01"
requires:
  - "P01"
affects:
  - "P03,P04"
key_files:
  - "scripts/intake/shape-detect.sh,scripts/intake/paragraph-classify.sh,tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md,tests/m031-acceptance/fixtures/tier-a-plus-input.txt,tests/m031-acceptance/test-tier-a-plus-classifier.sh,tools/verify/m031-p02-classifier-extension-shape.sh,tools/verify/m031-p02-fixture-provenance-shape.sh,tools/verify/m031-p02-tier-a-plus-input-shape.sh,tools/verify/m031-p02-test-tier-a-plus-classifier-shape.sh,scripts/intake/lib/task-slug.sh,templates/dispatch-role-research.md,templates/dispatch-role-plan.md,templates/dispatch-role-build.md,tools/verify/m031-p02-task-slug-shape.sh,tools/verify/m031-p02-role-templates-shape.sh,scripts/intake/lib/tier-a-plus-prompt.sh,tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh,tools/verify/m031-p02-prompt-shape.sh,tools/verify/m031-p02-test-tier-a-plus-prompt-ux-shape.sh,scripts/intake/route-to-dispatch.sh,tests/m031-acceptance/test-tier-a-plus-flow.sh,tools/verify/m031-p02-router-shape.sh,tools/verify/m031-p02-test-tier-a-plus-flow-shape.sh,scripts/dispatch/build-context.sh,tools/verify/m031-p02-phase-suite.sh,tools/verify/m031-p02-scope-guard.sh"
key_decisions:
  - "Tier A+ heuristic boundary chosen as 30-80 words AND zero structural markers (^## heading / Given-When-Then triple / ^- FR- bullet) — answers P02 open question A1; new branch inserted AFTER fragment branch and BEFORE idea branch in shape-detect.sh so it claims the uninstantiated middle band without disturbing the fragment >=81 or words<=10 idea boundaries; paragraph-classify.sh extended via comment-only annotation (rationale_paragraph emitted output stays byte-equal pre/post — router consumes shape-detect.sh's verdict directly and skips paragraph-classify.sh on the Tier A+ branch); FIXTURE-PROVENANCE.md cites both M031/P01/T01 and M030/P07/T03 unit_close records for cross-record breadth (heuristic generalizes beyond a single citation); SC-5 acceptance test uses RESULT: SC-5 pass envelope per the M031 P01 SC-* convention; shape verifiers use SUMMARY: <name> pass=N fail=M envelope per the M031 P01 convention,AD-10 collision discipline implemented as conservative bare-base-slug-on-no-collision + 4-char SHA-1 suffix only on real collision against an unrelated prior research.md (preserves human-readable slugs for AD-20 prompt UX),empty-input fallback chosen as deterministic literal untitled rather than SHA-1 of empty string (keeps the slug human-readable; collision discipline still applies if untitled/research.md exists),hash availability shasum -a 1 preferred with openssl sha1 fallback (POSIX-portable across macOS and Linux dispatch hosts),sourceability discipline (no top-level side-effects when sourced; private helpers prefixed _task_slug_*),new schema entry type: dispatch-role reserved by M031 P02 (future role-template additions MUST be additive not parallel),role-template body avoids D020 prohibited scaffold-placeholder bracket-TODO byte pattern via paraphrase,AD-19 single-script-file shape preserved across both new verifiers (no inline compound bash no process substitution no plain subshells in verifier bodies),AD-20 mechanical contract implemented with strict BEGIN/END PROMPT BODY sentinels around _tap_emit_prompt_body so the prohibited token assertions (null brace scaffold-placeholder bracket-TODO) gate against the operator-facing prose region only -- not against helper-internal logic such as 2>/dev/null shell-substitution braces or comment text mentioning the prohibited tokens by name (mirrors the M031 P01 inverted-polarity surface-region convention),A4 open question (session-ID sidecar mechanism) answered: a single-line .session-id file under <task-slug>/ holding the session ID; helper reads it and flips the [fresh research from this session] vs [resume from prior research] marker on match/mismatch (T04 router writes the sidecar on first session entry),tier_a_plus_prompt_summary_lines resolution path -- direct YAML grep against .orchestrator/config.yml then templates/orchestrator-config-default.yml then hardcoded P00 default 8 (read-config.sh VALID_KEYS list does not yet whitelist this knob; the equivalent permitted by the task-plan note keeps T03 scope bounded -- P04 or M032 may extend VALID_KEYS as a separate single-line amendment),--no-prompt-mode y|n|c test-only flag added to bypass the read -r -n 1 -t 60 interactive path so the SC-16 test exercises every UX clause deterministically without driving stdin (production default stays the interactive read path),60-second read timeout with empty/EOF/timeout all collapsing to the c cancel default per AD-20 clause 3 default-on-no-answer requirement,SC-16 test constructs prohibited byte patterns at runtime via printf octal escapes (173 175 133) so the test source itself does not embed the literal forbidden bytes -- same source-side discipline the helper applies to its own prompt body,helper writes the audit line research: <path> to stderr in BOTH --yes and interactive modes so callers grep stderr regardless of mode (path emission discipline AD-20 clause 7),AD-19 single-script-file Truth Check shape preserved across both new verifiers (no inline compound bash no process substitution no plain subshells in verifier bodies),A2 router CLI surface: --verdict tier_a_plus --task DESC --yes --session-id ID --scratch-root DIR --dispatch-stub SCRIPT (--proposal/--verdict mutually exclusive),A3 stub-vs-real dispatch: --dispatch-stub flag + ORCH_DISPATCH_STUB env var (one shell argument; receives role/slug/desc/slug-dir positionals); SC-6 ships canned stub; production unset path invokes build-context.sh --profile=quick + role-template + AD-11 sidecar and stops at agent-runtime handoff (MEM018),A5 scratch prefix: .orchestrator/tier-a-plus/SLUG/ (matches T03 prompt helper); --scratch-root override for tests; ORCH_TIER_A_PLUS_LOG override for unit_close JSONL log path,docstring discipline: paraphrase forbidden command names so the router-shape grep stays strict per task plan step 6,phase-suite gate ordering follows T01->T05 dependency order with scope-guard last,added .orchestrator/tier-a-plus/ as second permissive prefix alongside .orchestrator/observability/,MEM hit_count-only carve-out function copied verbatim from P01 (project-wide convention now),no edits to T01-T04 deliverables per plan-time discipline (3 pre-existing key-link FAILs forwarded for P02 close-out remediation)"
patterns_established:
  - "additive verdict-enum extension on a closed M024 surface (insert new branch BEFORE the fallback default and AFTER the higher-priority sibling so fallback semantics stay byte-equal); comment-only annotation pattern for satisfying literal-token verifier requirements without changing emitted output (paragraph-classify.sh); AD-16 normative grounding pattern (FIXTURE-PROVENANCE.md cites historical unit_close records by M###/P##/T## provenance; downstream verifier requires both file existence and provenance pattern); fixture-paraphrase-from-citation discipline (tier-a-plus-input.txt body is a paraphrase of the cited record's task description,keeping the heuristic empirically grounded),sourceable shell library with private function prefix discipline (_task_slug_* helpers + public derive_task_slug entry),deterministic-by-construction slug derivation (5-step pipeline lower -> ws-hyphen -> strip -> collapse -> truncate) with optional collision-only suffix,role-template trio sibling-symmetric with existing dispatch-prompt.md and dispatch-result.md siblings (same templates/ directory same frontmatter shape),per-role required-literal-substring contract enforced by single-script Truth Check verifier (each role template asserts 4 role-specific literals plus 2 frontmatter literals),collision-check rooted at project-relative .orchestrator/tier-a-plus/<base-slug>/research.md (caller-cwd-independent via BASH_SOURCE-driven project-root resolution),bracketed prompt-body sentinel pattern (BEGIN PROMPT BODY / END PROMPT BODY) for source-side enforcement of operator-facing prose token discipline (verifier extracts the region with awk and asserts the prohibited tokens do not appear inside),test-only --no-prompt-mode bypass for interactive UX surfaces (test exercises every UX clause deterministically without driving stdin; production keeps the interactive read path),direct-YAML-grep config knob resolution as a permitted equivalent when the canonical reader VALID_KEYS list lags behind a new knob (4-layer precedence preserved: env-var implicit / .orchestrator/config.yml / templates default / hardcoded P00 default),session-ID sidecar pattern under <task-slug>/.session-id (single-line file holding session ID; presence + match flips a UX marker; non-state-machine scratch artifact under .orchestrator/tier-a-plus/ permissive prefix),runtime construction of prohibited byte patterns via printf octal escapes for D020/CON-7 self-application (test/verifier source itself does not embed the literal forbidden bytes),additive --verdict CLI mode on legacy positional router (preserves existing --proposal path byte-equal),per-role dispatch wrapper with stub-vs-real bifurcation,inline JSONL emitter for new schema additions (no new emitter introduced; Bash 3.2 string concatenation per existing convention),paraphrased-forbidden-token discipline (router-shape verifier grep stays strict by paraphrasing CON-4 command names in source docstrings),sandbox SC-6 with --dispatch-stub + --scratch-root + ORCH_TIER_A_PLUS_LOG env override (test exercises router shape without touching real .orchestrator/ tree),phase-suite straight-line N-gate aggregation repeats across milestones (P01:9 / P02:11),SC-12 scope-guard with dual-prefix permissive carve-out (observability + per-flow scratch),MEM hit_count-only carve-out invariantly inherited verbatim across phases"
drill_down_paths:
  - "[.orchestrator/milestones/M031/phases/P02/tasks/T01-classifier-and-provenance-SUMMARY.md](../../../../../milestones/M031/phases/P02/tasks/T01-classifier-and-provenance-SUMMARY.md), [.orchestrator/milestones/M031/phases/P02/tasks/T02-slug-and-role-templates-SUMMARY.md](../../../../../milestones/M031/phases/P02/tasks/T02-slug-and-role-templates-SUMMARY.md), [.orchestrator/milestones/M031/phases/P02/tasks/T03-prompt-and-prompt-ux-test-SUMMARY.md](../../../../../milestones/M031/phases/P02/tasks/T03-prompt-and-prompt-ux-test-SUMMARY.md), [.orchestrator/milestones/M031/phases/P02/tasks/T04-router-and-flow-test-SUMMARY.md](../../../../../milestones/M031/phases/P02/tasks/T04-router-and-flow-test-SUMMARY.md), [.orchestrator/milestones/M031/phases/P02/tasks/T05-phase-suite-and-scope-guard-SUMMARY.md](../../../../../milestones/M031/phases/P02/tasks/T05-phase-suite-and-scope-guard-SUMMARY.md)"
duration: "495m"
verification_result: "pass"
completed_at: "2026-05-01T19:41:00Z"
observability_surfaces:
  - "none"
---

M031/P02 added the Tier A+ middle flow (research → approval → plan → build) end-to-end:

- **T01 (classifier + provenance)** [`92cd6eb`] — extended `scripts/intake/shape-detect.sh` with the `tier_a_plus` verdict for inputs in the 30–80 word band with no structural markers (`^##` heading / Given-When-Then / `^- FR-` bullet). Added `tests/m031-acceptance/fixtures/{FIXTURE-PROVENANCE.md,tier-a-plus-input.txt}` (AD-16 normative grounding citing M031/P01/T01 and M030/P07/T03 unit_close records). SC-5 acceptance test green. Existing 5 verdicts (`idea`, `paragraph`, `fragment`, `spec`, `empty`) byte-equal.
- **T02 (slug lib + role templates)** [`af7a88d`] — `scripts/intake/lib/task-slug.sh` exposing `derive_task_slug` (5-step base + optional 4-char SHA-1 collision suffix + `untitled` empty-input fallback). Three sibling role templates `templates/dispatch-role-{research,plan,build}.md` (each ≥93 lines) declaring `type: dispatch-role`. Bash 3.2 / MEM001 compliant.
- **T03 (approval prompt + SC-16)** [`bd5a742`] — `scripts/intake/lib/tier-a-plus-prompt.sh` (273 lines, AD-7 + AD-20). CLI: `--research-path`, `--task-slug`, `--yes`, `--session-id`, `--no-prompt-mode y|n|c`. Exit codes 0/1/2 (proceed/re-research/abort). All 7 AD-20 clauses implemented; 60-second `read` timeout collapses to abort default. SC-16 prompt-UX test green. Open question A4 resolved: session-ID sidecar = single-line `<task-slug>/.session-id`.
- **T04 (router amend + SC-6)** [`b91f202`] — `scripts/intake/route-to-dispatch.sh` extended additively with `--verdict tier_a_plus` mode. Chains research → approval → plan → build via `build-context.sh --profile=quick` + role templates. Inline JSONL emitter writes one `unit_close` per role with new `tier_a_plus_role` + `aborted` fields (additive optional). SC-6 acceptance test uses `--dispatch-stub` + `--scratch-root` + `ORCH_TIER_A_PLUS_LOG` for hermetic execution. Legacy `--proposal` path byte-equal. Open questions A2 / A3 / A5 resolved.
- **T05 (phase-suite + SC-12 scope-guard)** [`58e6a2f` + `7624397`] — `tools/verify/m031-p02-phase-suite.sh` (11-gate straight-line aggregator, T01→T05 dependency order, no short-circuit) + `tools/verify/m031-p02-scope-guard.sh` (dual-prefix permissive carve-out: `.orchestrator/observability/` + `.orchestrator/tier-a-plus/`; MEM `hit_count`-only carve-out inherited verbatim from P01). Mid-task remediation (`7624397`) added a `# Key links` doc-comment block to `route-to-dispatch.sh` listing the three literal role-template filenames so the phase-plan key-link must-haves resolve (mirrors the P01 build-context.sh remediation pattern).

**Phase-level verification (Tier 1 + Tier 3)**:
- `check-must-haves.sh` → 97 PASS / 0 FAIL.
- `check-boundary-map.sh` → SKIP (no produce items declared in plan).
- `m031-p02-phase-suite.sh` → `pass=11 fail=0`.
- `m031-p02-scope-guard.sh` → `pass=31 fail=0 block_list_violations=0 mem_hitcount_carveouts=31`.
- 3 acceptance tests green (SC-5 classifier, SC-16 prompt-UX, SC-6 flow).
- M024 regression: `tests/test-paragraph-intake.sh` 3/3 dispatch-path tests pass (3 specify-path failures pre-existing T01 classifier ripple, unrelated to P02).

**Open questions resolved this phase**: A1 (boundary band 30–80 words + zero structural markers, T01); A2 (router CLI surface, T04); A3 (SC-6 stub-vs-real seam, T04); A4 (session-ID sidecar, T03); A5 (`.orchestrator/tier-a-plus/` allow-list prefix, T04). Zero unresolved.

**Forwarded to P03+**: extending `read-config.sh` `VALID_KEYS` to whitelist `tier_a_plus_prompt_summary_lines` (T03 helper currently uses direct YAML grep with hardcoded P00 default 8 — equivalent permitted by task plan); phase-level housekeeping commit to clear pre-existing working-tree drift (M036, CLAUDE.md, spec-033, references/RUNTIME-ASSUMPTIONS.md, scripts/dispatch/build-context.sh, templates/orchestrator-config-default.yml, tools/verify/p00-phase-suite.sh) carried forward from prior sessions.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M031"
name: "P03 phase-suite aggregator + SC-12 scope-guard"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 complete: `tools/verify/m031-p03-do-md-shape.sh`, `tools/verify/m031-p03-do-entry-shape.sh`, `tools/verify/m031-p03-fastpath-shape.sh`, `tools/verify/m031-p03-passthrough-shape.sh` all exist, executable, exit 0.
- T02 complete: `tools/verify/m031-p03-test-universal-entry-trivial-shape.sh`, `tools/verify/m031-p03-test-universal-entry-lowconf-shape.sh` both exist, executable, exit 0. SC-7 + SC-8 acceptance tests both pass.
- The P02 phase-suite + scope-guard (`tools/verify/m031-p02-phase-suite.sh`, `tools/verify/m031-p02-scope-guard.sh`) exist on disk and are read for shape inheritance — NOT modified by T03.
- The P01 phase-suite + scope-guard (`tools/verify/m031-p01-phase-suite.sh`, `tools/verify/m031-p01-scope-guard.sh`) exist on disk and are read for the MEM `hit_count`-only carve-out function shape — NOT modified by T03.

## Description

T03 ships the P03 phase-close gates: the phase-suite aggregator (chains every P03 sub-gate in T01 → T02 dependency order) and the SC-12 scope-guard (asserts the P03 diff stays inside the declared "Files Likely Touched" surface). Both inherit verbatim shapes from the P02 verifiers landed by P02/T05.

**Phase-suite shape** (mirrors P01/P02 straight-line aggregation, AD-19 compliant):
- 6 sub-gates from T01 + T02:
  1. `m031-p03-do-md-shape.sh` (T01)
  2. `m031-p03-do-entry-shape.sh` (T01)
  3. `m031-p03-fastpath-shape.sh` (T01)
  4. `m031-p03-passthrough-shape.sh` (T01)
  5. `m031-p03-test-universal-entry-trivial-shape.sh` (T02)
  6. `m031-p03-test-universal-entry-lowconf-shape.sh` (T02)
- 1 sub-gate from T03 itself:
  7. `m031-p03-scope-guard.sh` (T03 — last gate per the P01/P02 convention)
- Total: 7 sub-gates straight-line invoked. No array loops, no compound chains, no eval. Each gate's exit code is captured into a `pass`/`fail` accumulator. Aggregator emits `SUMMARY: m031-p03-phase-suite.sh pass=N fail=M` and exits 0 iff `fail=0`. Does NOT short-circuit on a sub-gate failure (all 7 gates run regardless).

**Scope-guard shape** (mirrors P02/T05 dual-prefix permissive carve-out + MEM hit_count-only carve-out):
- **Block-list** (SC-12 verbatim): any working-tree diff (vs HEAD) touching `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, `scripts/auto/loop/` is a block-list violation.
- **MEM hit_count carve-out** (P01/P02 verbatim): for diffs under `knowledge/(conventions|lessons|patterns)/MEM*.md`, if every `+`/`-` line matches `^[+-]hit_count: [0-9]+$`, the diff is treated as orchestrator-emitted hit-count drift, not a manual scope violation. Carve-out is counted in `mem_hitcount_carveouts`.
- **Dual-prefix permissive carve-out** (P02 verbatim): diffs under `.orchestrator/observability/` AND `.orchestrator/tier-a-plus/` are permissive — not block-list violations.
- **Allow-list**: the P03 "Files Likely Touched" surface (T01 + T02 deliverables) plus phase/task plan + summary paths under `.orchestrator/milestones/M031/phases/P03/`. Diffs outside the allow-list AND outside the carve-outs AND outside the block-list are reported as `out_of_scope` (pass per SC-12 — the SC-12 contract is block-list-only — but emitted as a warning so the operator notices unintended drift).
- Output: `SUMMARY: m031-p03-scope-guard.sh pass=N fail=M block_list_violations=K mem_hitcount_carveouts=L`. Exit 0 iff `block_list_violations == 0`.

## Steps

1. **Read the P02 phase-suite for shape inheritance**. Open `tools/verify/m031-p02-phase-suite.sh`. Note:
   - `set -u` at the top.
   - `pass=0; fail=0` accumulators.
   - `emit_gate_result()` helper accepting `(rc, name)` and incrementing `pass` or `fail` based on rc.
   - Eleven gate blocks, each three lines: `bash <verifier-path>` then `rc=$?` then `emit_gate_result "$rc" "<name>"`.
   - Final block: `printf 'SUMMARY: m031-p02-phase-suite.sh pass=%d fail=%d\n' "$pass" "$fail"` then `if [ "$fail" -eq 0 ]; then exit 0; else exit 1; fi`.

2. **Author `tools/verify/m031-p03-phase-suite.sh`** (executable, bash 3.2). Mirror the P02 shape exactly except:
   - 7 gate blocks instead of 11.
   - Sub-gate ordering matches the T01 → T02 → T03 dependency order:
     1. `tools/verify/m031-p03-do-md-shape.sh`
     2. `tools/verify/m031-p03-do-entry-shape.sh`
     3. `tools/verify/m031-p03-fastpath-shape.sh`
     4. `tools/verify/m031-p03-passthrough-shape.sh`
     5. `tools/verify/m031-p03-test-universal-entry-trivial-shape.sh`
     6. `tools/verify/m031-p03-test-universal-entry-lowconf-shape.sh`
     7. `tools/verify/m031-p03-scope-guard.sh`
   - Header comment block (≥ 30 lines) documenting the gate ordering, the AD-19 straight-line discipline (no array loops, no compound chains, no eval), and a `# Key links (M031/P03):` block listing the 7 sub-gate basenames so phase-level key-link must-haves resolve via grep.
   - Final SUMMARY line `SUMMARY: m031-p03-phase-suite.sh pass=%d fail=%d`.
   - Exit 0 iff `fail == 0`.

3. **Read the P02 scope-guard for shape inheritance**. Open `tools/verify/m031-p02-scope-guard.sh`. Note:
   - The `git diff --name-only HEAD` invocation (or equivalent) for enumerating changed files.
   - The block-list pattern matcher (`case "$path" in knowledge/*|scripts/cost/*|scripts/dispatch/adapters/router/*|scripts/auto/loop/*) ...`).
   - The MEM hit_count carve-out function — checks every `+`/`-` line of the file's diff against `^[+-]hit_count: [0-9]+$` regex; if all match, count under `mem_hitcount_carveouts` instead of `block_list_violations`.
   - The permissive prefix carve-out (`.orchestrator/observability/*` and `.orchestrator/tier-a-plus/*`).
   - The allow-list for P02's files-likely-touched surface.
   - The final SUMMARY line shape: `SUMMARY: m031-p02-scope-guard.sh pass=%d fail=%d block_list_violations=%d mem_hitcount_carveouts=%d`.

4. **Author `tools/verify/m031-p03-scope-guard.sh`** (executable, bash 3.2). Mirror the P02 shape exactly except:
   - **Allow-list** updated to the P03 "Files Likely Touched" surface (verbatim from P03-PLAN.md "Files Likely Touched" — 15 paths under `commands/`, `scripts/intake/`, `tests/m031-acceptance/`, `tools/verify/`):

     ```
     commands/do.md
     scripts/intake/do-entry.sh
     tests/m031-acceptance/fixtures/do-entry-stub.sh
     tests/m031-acceptance/fixtures/do-entry-trivial-input.txt
     tests/m031-acceptance/fixtures/do-entry-lowconf-input.txt
     tests/m031-acceptance/test-universal-entry-trivial.sh
     tests/m031-acceptance/test-universal-entry-lowconf.sh
     tools/verify/m031-p03-do-md-shape.sh
     tools/verify/m031-p03-do-entry-shape.sh
     tools/verify/m031-p03-fastpath-shape.sh
     tools/verify/m031-p03-passthrough-shape.sh
     tools/verify/m031-p03-test-universal-entry-trivial-shape.sh
     tools/verify/m031-p03-test-universal-entry-lowconf-shape.sh
     tools/verify/m031-p03-phase-suite.sh
     tools/verify/m031-p03-scope-guard.sh
     ```

     Plus phase/task-plan/summary paths under `.orchestrator/milestones/M031/phases/P03/`.

   - **Block-list** preserved verbatim from P02: `knowledge/**` (with MEM hit_count carve-out), `scripts/cost/`, `scripts/dispatch/adapters/router/`, `scripts/auto/loop/`.
   - **MEM hit_count-only carve-out** function copied verbatim from `tools/verify/m031-p02-scope-guard.sh`. The function tests every `+`/`-` line of a file's diff against the regex `^[+-]hit_count: [0-9]+$`; if all match, returns 0 (carve-out applies).
   - **Dual-prefix permissive carve-out** preserved verbatim from P02: `.orchestrator/observability/*` and `.orchestrator/tier-a-plus/*` paths are not block-list violations.
   - Header comment block (≥ 30 lines) documenting the SC-12 contract, the carve-outs (block-list, MEM hit_count, dual-prefix permissive), and the allow-list provenance.
   - Final SUMMARY line `SUMMARY: m031-p03-scope-guard.sh pass=%d fail=%d block_list_violations=%d mem_hitcount_carveouts=%d`.
   - Exit 0 iff `block_list_violations == 0`.

5. **Co-author the `# Key links` doc-comment** in `tools/verify/m031-p03-phase-suite.sh` (mirrors the P01 build-context.sh + P02 route-to-dispatch.sh remediation pattern from commit `7624397`). The block lists the seven sub-gate basenames so the phase plan's Key Links must-haves resolve via `grep -q '<basename>' tools/verify/m031-p03-phase-suite.sh`:

   ```bash
   # Key links (M031/P03):
   #   - m031-p03-do-md-shape.sh                       (T01 do-md gate)
   #   - m031-p03-do-entry-shape.sh                    (T01 do-entry gate)
   #   - m031-p03-fastpath-shape.sh                    (T01 fastpath gate)
   #   - m031-p03-passthrough-shape.sh                 (T01 passthrough gate)
   #   - m031-p03-test-universal-entry-trivial-shape.sh (T02 SC-7 gate)
   #   - m031-p03-test-universal-entry-lowconf-shape.sh (T02 SC-8 gate)
   #   - m031-p03-scope-guard.sh                       (T03 scope-guard gate; last)
   ```

6. **Run the phase-suite + scope-guard locally to confirm exit 0**:

   ```bash
   bash tools/verify/m031-p03-phase-suite.sh
   bash tools/verify/m031-p03-scope-guard.sh
   ```

   The phase-suite must report `SUMMARY: m031-p03-phase-suite.sh pass=7 fail=0`. The scope-guard must report `block_list_violations=0`. If either fails, the failure is one of:
   - **A T01 or T02 deliverable is missing**: re-verify the upstream tasks shipped their artifacts.
   - **The scope-guard's allow-list does not cover a touched file**: check the working-tree diff against the allow-list and add any missed file. (If the missed file is correctly within scope, add it; if it is out-of-scope, revert the touch.)
   - **The scope-guard reports `block_list_violations > 0`**: the diff actually touches a forbidden path. Revert and reroute.
   - **MEM hit_count drift** is reported: this is an orchestrator-emitted side-effect from prior dispatches and is counted under `mem_hitcount_carveouts`, NOT `block_list_violations` — green pass.

7. **Verify the phase-level Tier 1 must-haves**:

   ```bash
   bash scripts/verify/check-must-haves.sh [.orchestrator/milestones/M031/phases/P03/P03-PLAN.md](../../../../../milestones/M031/phases/P03/P03-PLAN.md)
   ```

   Expect 0 FAIL.

8. **Verify the phase-level boundary map** (informational; may SKIP if no produce items declared):

   ```bash
   bash scripts/verify/check-boundary-map.sh [.orchestrator/milestones/M031/phases/P03/P03-PLAN.md](../../../../../milestones/M031/phases/P03/P03-PLAN.md) || true
   ```

## Must-Haves

This task addresses the following Must-Haves from `P03-PLAN.md`:
- "`tools/verify/m031-p03-phase-suite.sh` exists, is executable, invokes every P03 sub-gate ... emits `SUMMARY: m031-p03-phase-suite.sh pass=N fail=M`" (Truth #7; Check via `m031-p03-phase-suite.sh`)
- "`tools/verify/m031-p03-scope-guard.sh` exists, is executable, asserts the P03 diff does NOT touch any path under the SC-12 block-list" (Truth #8; Check via `m031-p03-scope-guard.sh`)

## Verification

```bash
bash tools/verify/m031-p03-phase-suite.sh
```

```bash
bash tools/verify/m031-p03-scope-guard.sh
```

```bash
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M031/phases/P03/P03-PLAN.md
```

## Notes

- The phase-suite emits `SUMMARY: m031-p03-phase-suite.sh pass=7 fail=0` when every sub-gate is green — N is exactly 7 (4 from T01 + 2 from T02 + 1 from T03 itself).
- The scope-guard's `mem_hitcount_carveouts=K` field is informational (the value depends on cross-session MEM hit_count drift since HEAD); only `block_list_violations` is gated.
- AD-19 single-script-file invariant: each gate inside the phase-suite is invoked as a literal `bash <path>` line followed by `rc=$?`. NO `for` loops over arrays, NO `(...)` subshells, NO `&&`/`||` chains, NO `$(...)` containing pipes.
- Bash 3.2 (MEM001): no `declare -A`, no process substitution.
- D020 / CON-7: no scaffold-placeholder marker bracket-TODO byte pattern in any new file.
- The phase-suite does NOT parse SUMMARY lines from sub-gates — it consumes exit codes only (mirrors P02 — parsing would couple the suite to envelope formatting; exit codes are the load-bearing contract).
- The scope-guard's allow-list does NOT include test-run scratch artifacts under `.orchestrator/tier-a-plus/` or `.orchestrator/observability/` — those land under the dual-prefix permissive carve-out and are not allow-list-gated.
- **Real-app smoke test pending** (plan-time discipline rule 5): T03's verifiers gate the phase-close shape, not the live runtime end-to-end. Production confirmation that `orchestrator:do <task>` works against a CC-installed consumer project is the [M033](../../../../../milestones/M033/index.md) onboarding milestone's job; T03 + the P03 phase-suite confirm the contract surface.

## Inputs

### From Previous Tasks

- **T01: 4 shape verifiers** — `m031-p03-do-md-shape.sh`, `m031-p03-do-entry-shape.sh`, `m031-p03-fastpath-shape.sh`, `m031-p03-passthrough-shape.sh`. T03's phase-suite invokes each via `bash <path>`.
- **T02: 2 shape verifiers** — `m031-p03-test-universal-entry-trivial-shape.sh`, `m031-p03-test-universal-entry-lowconf-shape.sh`. T03's phase-suite invokes each via `bash <path>`.

### From Previous Phases

- **P01: `tools/verify/m031-p01-phase-suite.sh`** — read for the straight-line N-gate aggregation pattern (AD-19 compliant). T03 mirrors the shape with N=7 instead of N=9.
- **P01: `tools/verify/m031-p01-scope-guard.sh`** — read for the MEM `hit_count`-only carve-out function (`^[+-]hit_count: [0-9]+$` line-content check on `knowledge/(conventions|lessons|patterns)/MEM*.md` paths).
- **P02: `tools/verify/m031-p02-phase-suite.sh`** — read for the `emit_gate_result` helper shape and the SUMMARY line format.
- **P02: `tools/verify/m031-p02-scope-guard.sh`** — read for the dual-prefix permissive carve-out (`.orchestrator/observability/` + `.orchestrator/tier-a-plus/`) and the allow-list / block-list / carve-out wiring.

### From Disk (Pre-existing)

- [`.orchestrator/milestones/M031/phases/P03/P03-PLAN.md`](../../../../../milestones/M031/phases/P03/P03-PLAN.md) — read for the "Files Likely Touched" allow-list surface.

## Constraints

- **Bash 3.2 compatibility** (MEM001): no `declare -A`, no process substitution, no `$()` containing pipes inside conditionals.
- **AD-19 single-script-file shape**: phase-suite gate invocations are straight-line `bash <path>` + `rc=$?` + `emit_gate_result`. No array loops, no compound chains, no eval.
- **No edits to T01 / T02 deliverables** in T03.
- **No edits to P01 / P02 verifiers** (`m031-p01-*.sh`, `m031-p02-*.sh`) in T03.
- **No edits to scripts/intake/ or commands/ or templates/** in T03.
- **CON-4 / DC-4**: T03 makes no orchestration-state writes.
- **CON-7 / D020 hygiene**: no scaffold-placeholder marker bracket-TODO byte pattern in any new file.
- **SC-12 scope-guard**: T03 MUST NOT touch `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, or `scripts/auto/loop/`. The scope-guard verifier itself MAY contain literal references to those paths (block-list patterns) — the carve-out logic distinguishes "literal pattern in source" from "actual diff touches the path."
- **Verifier path discipline** (AD-19 + M032 Finding A): project-owned slug-bearing verifiers live under `tools/verify/`, NOT `scripts/verify/`.

## Expected Output

After T03 completes:

1. `tools/verify/m031-p03-phase-suite.sh` exists, executable, ≥ 70 lines, invokes 7 sub-gates straight-line, emits `SUMMARY: m031-p03-phase-suite.sh pass=7 fail=0`, exits 0.
2. `tools/verify/m031-p03-scope-guard.sh` exists, executable, ≥ 100 lines, asserts SC-12 block-list compliance with carve-outs, emits `SUMMARY: m031-p03-scope-guard.sh pass=N fail=0 block_list_violations=0 mem_hitcount_carveouts=K`, exits 0.
3. `bash scripts/verify/check-must-haves.sh [.orchestrator/milestones/M031/phases/P03/P03-PLAN.md](../../../../../milestones/M031/phases/P03/P03-PLAN.md)` reports 0 FAIL.
4. No edits to any T01 or T02 deliverable.
5. No edits to any P01 or P02 verifier.

T03 leaves the P03 phase-close gate suite green. P03 is ready for verify+consolidate. The next phase (P04 — drift fix + observability + comms + acceptance battery aggregator) consumes the seven P03 sub-gates' SUMMARY contracts when wiring the milestone-grain acceptance battery (SC-14).

## State Context

- **Current State**: executing
- **Milestone**: M031
- **Phase**: P03
- **Task**: T03-phase-suite-and-scope-guard
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **Bash 3.2 compatibility** (MEM001): no `declare -A`, no process substitution, no `$()` containing pipes inside conditionals.
- **AD-19 single-script-file shape**: phase-suite gate invocations are straight-line `bash <path>` + `rc=$?` + `emit_gate_result`. No array loops, no compound chains, no eval.
- **No edits to T01 / T02 deliverables** in T03.
- **No edits to P01 / P02 verifiers** (`m031-p01-*.sh`, `m031-p02-*.sh`) in T03.
- **No edits to scripts/intake/ or commands/ or templates/** in T03.
- **CON-4 / DC-4**: T03 makes no orchestration-state writes.
- **CON-7 / D020 hygiene**: no scaffold-placeholder marker bracket-TODO byte pattern in any new file.
- **SC-12 scope-guard**: T03 MUST NOT touch `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, or `scripts/auto/loop/`. The scope-guard verifier itself MAY contain literal references to those paths (block-list patterns) — the carve-out logic distinguishes "literal pattern in source" from "actual diff touches the path."
- **Verifier path discipline** (AD-19 + M032 Finding A): project-owned slug-bearing verifiers live under `tools/verify/`, NOT `scripts/verify/`.

### Acceptance Criteria

This task addresses the following Must-Haves from `P03-PLAN.md`:
- "`tools/verify/m031-p03-phase-suite.sh` exists, is executable, invokes every P03 sub-gate ... emits `SUMMARY: m031-p03-phase-suite.sh pass=N fail=M`" (Truth #7; Check via `m031-p03-phase-suite.sh`)
- "`tools/verify/m031-p03-scope-guard.sh` exists, is executable, asserts the P03 diff does NOT touch any path under the SC-12 block-list" (Truth #8; Check via `m031-p03-scope-guard.sh`)

### Files To Touch

- `commands/do.md` (create)
- `scripts/intake/do-entry.sh` (create)
- `tests/m031-acceptance/fixtures/do-entry-stub.sh` (create)
- `tests/m031-acceptance/fixtures/do-entry-trivial-input.txt` (create)
- `tests/m031-acceptance/fixtures/do-entry-lowconf-input.txt` (create)
- `tests/m031-acceptance/test-universal-entry-trivial.sh` (create)
- `tests/m031-acceptance/test-universal-entry-lowconf.sh` (create)
- `tools/verify/m031-p03-do-md-shape.sh` (create)
- `tools/verify/m031-p03-do-entry-shape.sh` (create)
- `tools/verify/m031-p03-fastpath-shape.sh` (create)
- `tools/verify/m031-p03-passthrough-shape.sh` (create)
- `tools/verify/m031-p03-test-universal-entry-trivial-shape.sh` (create)
- `tools/verify/m031-p03-test-universal-entry-lowconf-shape.sh` (create)
- `tools/verify/m031-p03-phase-suite.sh` (create)
- `tools/verify/m031-p03-scope-guard.sh` (create)

<!-- The phase plan and task plan files themselves (this file +
     tasks/T0[1-3]-*-PLAN.md) are written by the planner, not by the
     executor — they are not listed here. Test-run scratch files
     written under .orchestrator/tier-a-plus/<task-slug>/ during
     integration smoke runs land under the .orchestrator/tier-a-plus/
     permissive prefix (carve-out inherited from P02 scope-guard).
     Test-run JSONL records written via ORCH_DO_ENTRY_LOG land at
     paths the test controls (typically /tmp); they are out of the
     scope-guard's purview because /tmp is outside the repo tree. -->

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
UPDATED: MEM026 (hit_count)
UPDATED: MEM027 (hit_count)
UPDATED: MEM028 (hit_count)
UPDATED: MEM029 (hit_count)
UPDATED: MEM030 (hit_count)
UPDATED: MEM031 (hit_count)