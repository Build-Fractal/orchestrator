---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T04-throwaway-fixture-and-sc5 (Phase P03, Milestone M032)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~300 | required |
| Upstream Context | 981-1161 | ~4000 | required |
| Task Plan | 1163-1714 | ~7000 | required |
| State Context | 1716-1722 | ~100 | required |
| First-Turn Completeness | 1724-1771 | ~900 | required |
| **Total** | | **~23100** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 819
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
hit_count: 819
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
hit_count: 819
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
hit_count: 819
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
hit_count: 712
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
hit_count: 712
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
hit_count: 712
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
hit_count: 819
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
hit_count: 712
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
hit_count: 712
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
hit_count: 712
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
hit_count: 819
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
hit_count: 819
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
hit_count: 819
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
hit_count: 712
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
hit_count: 712
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
hit_count: 712
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
hit_count: 819
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
hit_count: 712
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
hit_count: 712
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
hit_count: 819
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
hit_count: 819
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
hit_count: 712
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
hit_count: 712
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
hit_count: 712
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
hit_count: 367
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
hit_count: 367
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
hit_count: 367
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
hit_count: 395
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
hit_count: 395
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
hit_count: 385
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
     Project-owned slug-bearing verifiers live under tools/verify/ with
     m032-p03-* prefix to avoid collision with M030/M031/M032 P00–P02
     existing verifiers in the shared tools/verify/ tree. Verifier scripts
     are co-authored alongside their corresponding artifact within the
     SAME task per plan-time discipline rule 2. -->

### Truths

- `wiki/overrides/partials/comments.html` has its four hardcoded Giscus
  `data-*` attribute interpolation expressions amended to also accept the
  M032-spec-mandated `{{giscus_repo}}` / `{{giscus_repo_id}}` /
  `{{giscus_category}}` / `{{giscus_category_id}}` placeholder tokens per
  FR-7. The placeholder tokens are the load-bearing surface that
  `wiki-init.sh --with-giscus` substitutes against; the existing
  `{{ config.extra.giscus.repo }}` Jinja interpolations (which read from
  `mkdocs.yml`'s `extra.giscus.*` `!ENV [GISCUS_*, "" ]` block) remain in
  place as the live runtime path. The two interpolation paths coexist:

<dispatch-volatile>

## Upstream Context


### P02 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P02"
parent: "M032"
milestone: "M032"
provides:
  - "commands/wiki-init.md (orchestrator:wiki-init command document,MEM012 structure); scripts/lifecycle/wiki-init.sh (FR-5 default-scope canonical implementation,bash 3.2 + AD-19 single-script-file shape); wiki/mkdocs.yml four-field placeholder amendment (bundle template state) + FR-6 self-application loop closed against orchestrator repo (resolved orchestrator-identity values restored); packaging/bundle/manifest.yml additive wiki/ entry under project_assets:; tools/verify/m032-p02-wiki-init-command-shape.sh + tools/verify/m032-p02-wiki-init-default-scope.sh + tools/verify/m032-p02-mkdocs-templating-and-self-application.sh + tools/verify/lib/m032-p02-wiki-serve-probe.sh helper,commands/init.md --with-wiki documentation block; init-project.sh recognizes --with-wiki/--with-giscus/--deploy with composition validation; sequential-atomicity dispatch of wiki-init.sh per FR-11/MIT-011; M032_WIKI_INIT_FORCE_EXIT test-only escape hatch in wiki-init.sh; tools/verify/m032-p02-init-with-wiki-passthrough.sh four-scenario verifier,wiki/glossary.md path-convention with three populated US-6-format entries (Constitution,Knowledge Graph,Milestone); scripts/wiki/wiki-scan-sources.sh --include-glossary additive flag emitting top:glossary record as second top-level source after Constitution; scripts/wiki/wiki-generate-nav.sh HAS_GLOSSARY discovery flag + emit_leaf 1 'Glossary' 'glossary.md' between Constitution and Decisions; scripts/wiki/wiki-generate-stubs.sh top:glossary case-arm routing stub to wiki/docs/glossary.md via build_canonical_repo_rel; tools/verify/m032-p02-glossary-format-invariant.sh + tools/verify/m032-p02-glossary-scanner-and-nav.sh verifiers,scripts/knowledge/lookup-mems.sh --kind=glossary READER adapter (parses wiki/glossary.md ### TERM headings,synthesizes M020-knowledge-record-compatible records on stdout,honors [M031](../../../../../milestones/M031/index.md) Quick/Standard/Full profile contract per FR-16 with MIT-010 safe-default-no-terms fallback under --profile=quick); stable id derivation gloss-<slug> via lower-case + non-alphanumeric-collapse + leading/trailing-dash-strip; tools/verify/m032-p02-lookup-mems-glossary.sh six-scenario verifier,tests/m032-acceptance/p02-wiki-init-default-scope.sh (SC-3); tests/m032-acceptance/p02-glossary-surface.sh (SC-7); tests/paired-m032-m033/seam-A.sh + seam-B.sh + seam-C.sh paired-launch contracts; tools/verify/m032-p02-acceptance-shape-sc3.sh + m032-p02-acceptance-shape-sc7.sh + m032-p02-seam-a-shape.sh + m032-p02-seam-b-shape.sh + m032-p02-seam-c-shape.sh + m032-p02-phase-suite.sh + m032-p02-scope-guard.sh; tools/verify/fixtures/m032-p02-baseline-ref.txt baseline captured"
requires:
  - "P01"
affects:
  - "P03,P04"
key_files:
  - "commands/wiki-init.md,scripts/lifecycle/wiki-init.sh,wiki/mkdocs.yml,packaging/bundle/manifest.yml,tools/verify/m032-p02-wiki-init-command-shape.sh,tools/verify/m032-p02-wiki-init-default-scope.sh,tools/verify/m032-p02-mkdocs-templating-and-self-application.sh,tools/verify/lib/m032-p02-wiki-serve-probe.sh,wiki/glossary.md,commands/init.md,scripts/lifecycle/init-project.sh,tools/verify/m032-p02-init-with-wiki-passthrough.sh,scripts/wiki/wiki-scan-sources.sh,scripts/wiki/wiki-generate-nav.sh,scripts/wiki/wiki-generate-stubs.sh,wiki/docs/glossary.md,tools/verify/m032-p02-glossary-format-invariant.sh,tools/verify/m032-p02-glossary-scanner-and-nav.sh,scripts/knowledge/lookup-mems.sh,tools/verify/m032-p02-lookup-mems-glossary.sh,tests/m032-acceptance/p02-wiki-init-default-scope.sh,tests/m032-acceptance/p02-glossary-surface.sh,tests/paired-m032-m033/seam-A.sh,tests/paired-m032-m033/seam-B.sh,tests/paired-m032-m033/seam-C.sh,tools/verify/m032-p02-acceptance-shape-sc3.sh,tools/verify/m032-p02-acceptance-shape-sc7.sh,tools/verify/m032-p02-seam-a-shape.sh,tools/verify/m032-p02-seam-b-shape.sh,tools/verify/m032-p02-seam-c-shape.sh,tools/verify/m032-p02-phase-suite.sh,tools/verify/m032-p02-scope-guard.sh,tools/verify/fixtures/m032-p02-baseline-ref.txt"
key_decisions:
  - "FR-5,FR-6,FR-12,FR-15,FR-22,MIT-002,AD-5,AD-19,MEM012,MEM001,#Q-2,FR-11,MIT-011,CON-3,AP-009,MEM030,US-6,CON-6,FR-16,MIT-010,MEM008,MEM031,SC-3,SC-7,MIT-001,SC-13,Q-4,Q-B"
patterns_established:
  - "self-application detection (REPO_ROOT == PROJECT_DIR) skips bundle staging in dogfooding loops; field-line rewrite is idempotent against BOTH placeholders AND already-resolved values where the bundle source IS the orchestrator-local resolved copy; pre-stage idempotency short-circuit avoids cp-overwrites-operator-edits failure mode; lowercase owner for site_url + preserved case for repo_url matches GitHub Pages canonical convention; verifier toolchain-probe via symlink-only PATH excluding python3/pip3 exercises FR-12 fail-closed without breaking other tool lookups; wiki-serve probe helper prefers wiki-serve.sh --probe (mkdocs build --strict) for port-free health check with start+curl+kill fallback per AD-19 envelope,sequential-atomicity dispatch (init-project.sh writes outputs first; wiki-init.sh runs second; wiki-init.sh failure preserves init outputs and propagates literal exit code with init-complete-wiki-pending diagnostic); M032_WIKI_INIT_FORCE_EXIT env-var-only test-only failure-injection seam; pre-stage no-op short-circuit (wiki-init.sh skips bundle-staging when wiki/mkdocs.yml already exists from prior installer project_assets loop,avoiding FR-22 collision-check operator-owned trip),top-level scanner record + nav-generator HAS_* flag + stub-generator case-arm trio for new top-level wiki sources; verifier-contract-over-verifier-skeleton (implement plan's contract wording when embedded verifier code conflicts); side-effect-free verifier via backup-and-trap-restore (EXIT/INT/TERM),reader-only knowledge-adapter boundary (M020 retains schema-authority over on-disk knowledge/<category>/MEM*.md; M032 synthesizes records on-the-fly for build-context.sh consumption); --kind=<glossary|mem|reference> extensible argument-parsing seam at the adapter front; safe-default-no-terms fallback fires BEFORE any I/O on the budget-conscious Quick path (MIT-010); single-pipe-inside-function-body for slugify (AD-19-OK because harness shape-detection scope does not extend into function bodies); intermediary-variable prefix-strip _prefix=###  + ${line#$_prefix} to disambiguate bash 3.2 ${line#### } parameter-expansion parser quirk,paired-milestone seam-script convention under tests/paired-m032-m033/ shared by both M032 and [M033](../../../../../milestones/M033/index.md) verifier suites; scope-guard first-run-captures-baseline pattern (mirrors P01 m032-p01-baseline-ref.txt precedent); SC-7 actual contract reified (Glossary follows Constitution,not second-top-level-entry) -- the payload awk count was off-by-one against the Home-prefix nav; Seam-B identity-leak assertion (NOT file-absence) -- install-claude-code stages wiki/ from REPO_ROOT before wiki-init runs,so file presence is expected and the load-bearing invariant is that the FIXTURE identity is not baked into mkdocs.yml; grep -c under set -eu in command-substitution requires || true fallback to avoid silent abort when count==0"
drill_down_paths:
  - "[.orchestrator/milestones/M032/phases/P02/tasks/T01-wiki-init-default-scope-SUMMARY.md](../../../../../milestones/M032/phases/P02/tasks/T01-wiki-init-default-scope-SUMMARY.md), [.orchestrator/milestones/M032/phases/P02/tasks/T02-init-with-wiki-passthrough-SUMMARY.md](../../../../../milestones/M032/phases/P02/tasks/T02-init-with-wiki-passthrough-SUMMARY.md), [.orchestrator/milestones/M032/phases/P02/tasks/T03-glossary-surface-SUMMARY.md](../../../../../milestones/M032/phases/P02/tasks/T03-glossary-surface-SUMMARY.md), [.orchestrator/milestones/M032/phases/P02/tasks/T04-glossary-knowledge-adapter-SUMMARY.md](../../../../../milestones/M032/phases/P02/tasks/T04-glossary-knowledge-adapter-SUMMARY.md), [.orchestrator/milestones/M032/phases/P02/tasks/T05-acceptance-and-seam-and-suite-SUMMARY.md](../../../../../milestones/M032/phases/P02/tasks/T05-acceptance-and-seam-and-suite-SUMMARY.md)"
duration: "460m"
verification_result: "pass"
completed_at: "2026-05-04T20:16:37Z"
observability_surfaces:
  - "none"
---

## What Shipped

P02 lands the wiki tooling distribution path end-to-end: the
`orchestrator:wiki-init` command, the `init --with-wiki` paired-launch
passthrough, the wiki/glossary.md US-6 surface and its scan/nav/stub
routing, the `lookup-mems.sh --kind=glossary` knowledge-adapter, the SC-3
+ SC-7 acceptance scripts, the M032+M033 paired-launch seam tests
(`tests/paired-m032-m033/seam-A.sh|seam-B.sh|seam-C.sh`), and the
`m032-p02-phase-suite.sh` aggregator. FR-6 self-application loop is
closed: the orchestrator dogfoods its own wiki via
`scripts/lifecycle/wiki-init.sh` against the orchestrator-local wiki/
tree.

The five task tranches:

1. **T01 — wiki-init default scope (FR-5 + FR-6)**: authored
   `commands/wiki-init.md` + `scripts/lifecycle/wiki-init.sh` (single-script
   bash 3.2, AD-19 shape) + `wiki/mkdocs.yml` four-field placeholder
   amendment + the `wiki/` entry under `project_assets:` in
   `packaging/bundle/manifest.yml`. Self-application detection
   (`REPO_ROOT == PROJECT_DIR`) skips bundle-staging in the
   orchestrator-dogfooding-itself path. mkdocs.yml templating uses
   field-line rewrite (`^site_name:.*` → `site_name: "<value>"`) — idempotent
   against both starting states because the bundle source IS the
   orchestrator-local resolved file. Three verifiers green (15/15 + 19/19 +
   15/15).

2. **T02 — init --with-wiki passthrough (FR-11 + FR-15)**:
   `commands/init.md` documents the flag; `scripts/lifecycle/init-project.sh`
   recognizes `--with-wiki` / `--with-giscus` / `--deploy` with composition
   validation and dispatches `wiki-init.sh` sequentially per FR-11/MIT-011.
   `M032_WIKI_INIT_FORCE_EXIT` env-var test-only escape hatch added for
   failure-injection coverage. Verifier
   `tools/verify/m032-p02-init-with-wiki-passthrough.sh` exercises four
   scenarios. Two design adjustments documented inline: (a) test 2 checks
   absence of `wiki-init: done` rather than absence of `wiki/mkdocs.yml`;
   (b) test 4 checks absence of any `wiki-init:` diagnostic. Both preserve
   the spirit of the original task plan; rationale carried in T02-SUMMARY.

   T02 also surfaced a P01-verifier regression created by T01 (5th
   project_assets entry vs. hardcoded `expected 4`; commands count drift
   33→34 from `wiki-init.md`; scripts count drift 1160→1161 from
   `wiki-init.sh`). Resolved as an in-flight repair (commit `4dedb92a`)
   relaxing `m032-p01-manifest-schema-shape.sh` + `m032-p01-reader-emits-tuples.sh`
   to `-ge 4` + source-count parity, and refreshing the pre-M032 golden
   to commands=34, scripts=1161, total=1277. P01 phase-suite recovered to
   11/11.

3. **T03 — glossary surface (FR-13 + FR-14, US-6)**: populated
   `wiki/glossary.md` with three alphabetized US-6-format entries
   (Constitution, Knowledge Graph, Milestone). Wired the
   `top:glossary` source through `scripts/wiki/wiki-scan-sources.sh`
   (`--include-glossary` flag), `scripts/wiki/wiki-generate-nav.sh`
   (Glossary slot between Constitution and Decisions), and
   `scripts/wiki/wiki-generate-stubs.sh` (top:glossary case-arm routing).
   The plan-time-sketched stub-generator was NOT path-agnostic; T03
   added a routing case-arm. Two verifiers green.

4. **T04 — glossary knowledge-adapter (FR-16 + MIT-010)**:
   `scripts/knowledge/lookup-mems.sh --kind=glossary` reads
   `wiki/glossary.md`, parses `### TERM` headings, synthesizes
   M020-knowledge-record-compatible records on stdout. Honors M031
   Quick/Standard/Full profile contract; safe-default-no-terms fallback
   (MIT-010) fires before any I/O on the budget-conscious Quick path.
   Stable id derivation `gloss-<slug>` via lowercase + non-alphanumeric
   collapse + leading/trailing-dash strip. Six-scenario verifier green.

5. **T05 — acceptance + seam + suite**: SC-3 + SC-7 acceptance scripts
   (`tests/m032-acceptance/p02-wiki-init-default-scope.sh` +
   `p02-glossary-surface.sh`); the M032+M033 paired-launch seam contracts
   (`tests/paired-m032-m033/seam-A.sh` + `seam-B.sh` + `seam-C.sh`); the
   m032-p02-phase-suite.sh aggregator (12/12 PASS) and the
   m032-p02-scope-guard.sh (3/0 PASS, 13 in-scope paths). Baseline ref
   captured at `tools/verify/fixtures/m032-p02-baseline-ref.txt`.
   T05 modified zero T01–T04 deliverables.

## Verification Results

P02 phase-suite: **12/12 PASS**, scope-guard 3/0 PASS, all task-level
verifiers green at task close. Acceptance: SC-3 + SC-7 PASS. Paired-launch
seams: A/B/C all PASS. P01 phase-suite: 11/11 PASS post in-flight repair.

## Key Decisions

- **FR-5 + FR-6 (self-application loop)**: the orchestrator dogfoods its
  own wiki — `scripts/lifecycle/wiki-init.sh` runs against the
  orchestrator's own tree, with detection that skips bundle-staging when
  `REPO_ROOT == PROJECT_DIR`.
- **FR-11 + MIT-011 (sequential atomicity)**: `init-project.sh` writes its
  outputs first; `wiki-init.sh` runs second; if `wiki-init.sh` fails, init
  outputs are preserved and the literal exit code propagates with an
  `init-complete-wiki-pending` diagnostic.
- **MIT-010 (safe-default-no-terms)**: glossary-adapter Quick path
  fail-fast fallback fires before any I/O — under
  `lookup-mems.sh --kind=glossary --profile=quick` an empty/missing
  glossary returns nothing on stdout instead of erroring.
- **US-6 (glossary format invariant)**: `### TERM` headings, alphabetized,
  with structured body. Format-invariant verifier locks the contract.
- **Verifier-contract-over-verifier-skeleton**: when a plan-time-sketched
  verifier line conflicts semantically with the reified contract, the
  ship shape implements the contract wording. Two cases in T02
  (test 2 + test 4 documented inline); one case in T03 (SC-7 nav-position
  off-by-one against the Home-prefix nav).

## Patterns Established

- Self-application detection (`REPO_ROOT == PROJECT_DIR`) skips bundle
  staging in dogfooding loops.
- Field-line rewrite (`^key:.*` → `key: "<value>"`) is idempotent against
  both placeholder and resolved starting states when the bundle source IS
  the orchestrator-local resolved copy.
- Sequential-atomicity dispatch (writes-first-then-secondary; secondary
  failure preserves primary outputs and propagates exit code with
  diagnostic).
- Top-level scanner record + nav-generator HAS_* flag + stub-generator
  case-arm trio for new top-level wiki sources (replicable for future
  `top:*` source types).
- Reader-only knowledge-adapter boundary: M020 retains schema-authority
  over on-disk `knowledge/<category>/MEM*.md`; M032 synthesizes records
  on-the-fly for `build-context.sh` consumption — no MEM-file writes.
- Side-effect-free verifier via backup-and-trap-restore (EXIT/INT/TERM)
  for verifiers that must mutate-then-revert state.
- Paired-milestone seam-script convention at
  `tests/paired-m032-m033/seam-{A,B,C}.sh` shared by both M032 and M033
  verifier suites — reusable for future paired-launch milestones.
- `M0##_<COMMAND>_FORCE_EXIT` env-var-only test-only failure-injection
  seam (replicable for any milestone's failure-coverage verifier).
- Pre-stage no-op short-circuit (skip bundle-staging when target file
  already exists from a prior installer project_assets loop) — avoids
  the FR-22 collision-check operator-owned trip in dogfood loops.
- bash 3.2 parameter-expansion quirk: `${line#### }` parser-confuses with
  literal-`#` strip; resolved via intermediary `_prefix=###  ` +
  `${line#$_prefix}`.
- `grep -c` under `set -eu` in command-substitution requires `|| true`
  fallback — silent abort when count==0 otherwise.

## Affects Downstream

- **P03 (--with-giscus + --deploy composition)** — picks up the FR-15
  composition validation surface, the wiki-init dispatch envelope, and
  the wiki-serve probe helper.
- **P04 (acceptance + closure)** — extends the m032-p02-phase-suite.sh
  pattern + scope-guard convention to P03 + P04 verifiers.
- **M033** — paired-launch seams (`tests/paired-m032-m033/seam-{A,B,C}.sh`)
  are shared contracts; M033's P05 closure invokes the same seam suite.
- **M020 / M031 knowledge layer** — `lookup-mems.sh --kind=glossary`
  participates in the M031 Quick/Standard/Full profile contract; the
  reader-only adapter pattern is reusable for any future
  schema-foreign knowledge source.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P03"
milestone: "M032"
name: "FR-13 progressive-opt-in doc + AD-7 throwaway-fixture-protocol + SC-5 live-deploy acceptance"
depends_on: []
---

## Prerequisites

- `references/installation.md` exists at the orchestrator-repo level. Verified by `[ -f references/installation.md ]`. T04 amends it additively (new section appended; pre-existing content preserved verbatim).
- `tests/m032-acceptance/` exists from P01/P02 with prior acceptance scripts. T04 adds two new files: `throwaway-fixture-protocol.md` and `p03-wiki-init-deploy-live.sh`.
- `tests/fixtures/m032-fresh-project-fixture/` exists from P01 with a configured git remote.
- `gh` CLI MAY be on PATH and authenticated. SC-5 detects this at script start (via `gh auth status`) and emits SKIP_REASON / exit 77 if unauthenticated. T04's verifiers exercise the SKIP branch hermetically and the live branch only when `gh` is authenticated.
- T01 and T02 have landed (or will land before SC-5 is dispatched at execution time) — SC-5 invokes the full `--with-wiki --with-giscus --deploy` flag chain. At task-plan-authoring time, T04 plans against the documented flag-chain contract; at execution time, the SC-5 acceptance script runs against the actual T01+T02 surface.
- `tools/verify/` exists.

## Description

T04 lands the M032/M013-M014 counter-pattern surface — the live-throwaway-GH-repo discipline CON-5 mandates and the FR-13 documentation that establishes `--with-<feature>` as the project-wide progressive-opt-in convention. The deliverable surface has three pieces that ship together:

1. **FR-13 progressive-opt-in flag-pattern doc**: amend `references/installation.md` to add a new `## --with-<feature> Progressive Opt-In Flag Pattern` section documenting the convention (default-off, independently composable, opt-in is operator decision per Constitution I) and naming `--with-wiki`, `--with-giscus`, `--deploy` as the canonical M032 prior art.

2. **AD-7 throwaway-fixture-protocol document**: author `tests/m032-acceptance/throwaway-fixture-protocol.md` documenting the `gh repo create <ts>-m032-fixture --private --add-readme` + `gh repo delete <ts>-m032-fixture --yes` teardown contract — timestamp-prefix naming, four no-orphan-state invariants, recovery protocol on partial-failure teardown, trap-EXIT pattern.

3. **SC-5 acceptance script**: author `tests/m032-acceptance/p03-wiki-init-deploy-live.sh` implementing the protocol — `gh auth status` precondition with SKIP_REASON / exit 77 branch (POSIX skip-code per MIT-001), timestamped fixture creation, full `--with-wiki --with-giscus --deploy` invocation, live-URL curl retry loop bounded by `M032_DEPLOY_PROPAGATION_TIMEOUT`, served-HTML `data-repo` attribute assertion, MIT-008 audit-trail record assertion, trap-EXIT teardown, post-teardown no-orphan-state verification.

The atomicity argument: the FR-13 doc cites `tests/m032-acceptance/throwaway-fixture-protocol.md` as prior art for the `--deploy` operator-onboarding flow; the protocol document is the authoritative spec the SC-5 script implements. Splitting introduces a window where the SC-5 script ships without a documented protocol (operators have no recovery-on-partial-failure runbook) or where the FR-13 doc cites a non-existent protocol document. All three pieces co-author cleanly because they share token vocabulary (timestamp prefix, `--add-readme` flag, MIT-001 SKIP_REASON shape, MIT-008 audit-trail shape) and have no other inter-task dependencies.

## Steps

1. **Amend `references/installation.md`** to add the new section. Append to the end of the file (or insert before any existing trailing references — preserve byte-identity of existing content). Required content shape:

```markdown
## `--with-<feature>` Progressive Opt-In Flag Pattern

The orchestrator's installer commands honor a project-wide convention for
progressive-opt-in feature flags shaped as `--with-<feature>`. Each flag
follows three invariants:

- **Default-off** — the consumer never receives the feature surface unless
  they explicitly request it. This is Constitution I (Context Minimization)
  applied to the consumer-facing install surface: extra capability is an
  operator decision, not an installer default.
- **Independently composable** — every `--with-` flag is order-invariant
  and stateless with respect to every other `--with-` flag. Presence of
  one flag does not change the semantics of another. Composition is
  defined by the per-flag contract, not by flag-presence interactions.
- **Opt-in is reversible** — every `--with-<feature>` flag has a documented
  reversibility path (the inverse of the feature surface) that operators
  can run after the fact. Feature surfaces that cannot be cleanly removed
  do not qualify for the `--with-` pattern; they require a new gating
  primitive.

### Canonical M032 prior art (FR-13)

The first three flags landing under this pattern are M032's wiki tooling
trio:

- `--with-wiki` (FR-11) — installs `wiki/` tooling alongside the default
  `init` surface. Composes with `init`'s default flag set; reversibility
  is `rm -rf <project>/wiki/` plus removal of the corresponding
  `installed-files.txt` entries.
- `--with-giscus --repo <owner>/<repo> --category <name>` (FR-8) —
  configures Giscus comments against the consumer's own GitHub Discussions.
  Composes with `--with-wiki`; reversibility is re-running `--with-giscus`
  against a different repo/category, or manually editing the partial.
- `--deploy [--force-pages-reconfigure]` (FR-9 / MIT-007) — first GH Pages
  push. Composes with `--with-wiki --with-giscus`; reversibility is
  `gh repo edit --enable-pages=false` plus deleting the `gh-pages` branch.
  The `--force-pages-reconfigure` opt-in inside this flag handles the
  case where Pages was already configured for a different source on the
  consumer's repo (MIT-007 read-before-write Pages guard).

### Future flags (forward-compatibility commitments)

The `--with-` pattern is the documented precedent for future feature
surfaces. Anticipated additions:

- `--with-github-integration` (M013/M014 progressive opt-in fold-in) —
  enables GitHub-native sidecar tooling (issues/PRs/discussions adapter
  shim).
- `--with-design-layer` (M023, post-launch) — installs the design-layer
  fan-out tooling (`orchestrator:design` and the renderer adapter tree).

Each future flag will inherit the three invariants above. Adding a new
`--with-<feature>` flag requires (a) explicit documentation in this
section, (b) integration tests asserting the flag composes cleanly with
every existing `--with-` flag, and (c) a documented reversibility path.

### See also

- `commands/wiki-init.md` — the canonical `--with-wiki` / `--with-giscus`
  / `--deploy` flag-chain command surface.
- `tests/m032-acceptance/throwaway-fixture-protocol.md` — the live-deploy
  test discipline (`--deploy` is the highest-blast-radius `--with-` flag
  in M032; CON-5 mandates live-fixture testing rather than synthetic
  stubs).
```

2. **Author `tests/m032-acceptance/throwaway-fixture-protocol.md`**. Required content shape:

```markdown
# Throwaway-Fixture Protocol (AD-7 / CON-5)

This document specifies the protocol for live-network acceptance tests
that exercise GitHub-state-mutating commands (`gh api PATCH`,
`gh api PUT`, `gh repo create`, `mkdocs gh-deploy --force`, etc.). It is
M032's spec-side amendment of the M013/M014 cautionary tale: those
milestones tested only against synthetic stubs (`M013_GH_STUB_DIR`),
which produced the walker-contract dogfood blocker. M032 SHALL NOT
repeat that failure mode (CON-5).

## Fixture naming convention

Throwaway fixtures use a timestamp-prefixed name to ensure no collisions
across parallel CI invocations:

```
<ts>-m032-fixture
```

where `<ts>` is the unix-seconds timestamp at fixture creation
(`date +%s`). Example: `1714567890-m032-fixture`. The `m032-fixture`
suffix identifies the milestone for grep-able orphan-cleanup audits.

## Creation contract

```bash
TS=$(date +%s)
FIXTURE_NAME="${TS}-m032-fixture"
gh repo create "$FIXTURE_NAME" --private --add-readme
```

Flag rationale:

- `--private` (CON-5) — fixtures are private to avoid public test artifact
  pollution. CI runs against authenticated `gh` tokens with `repo` scope.
- `--add-readme` — ensures the default branch (`main`) exists immediately,
  required by the `gh api PUT /repos/<owner>/<repo>/pages` call (Pages
  source must reference an existing branch).

## Teardown contract

```bash
gh repo delete "<owner>/$FIXTURE_NAME" --yes
```

The teardown MUST run via a `trap` registered at fixture creation, so it
fires even on test-script failure mid-run:

```bash
cleanup() {
  gh repo delete "<owner>/$FIXTURE_NAME" --yes 2>/dev/null || true
}
trap cleanup EXIT INT TERM
```

## No-orphan-state invariants

After teardown, the test MUST verify four invariants:

1. **No `<ts>-m032-fixture` GitHub repo** — `gh repo view <owner>/<ts>-m032-fixture --json name 2>/dev/null` returns non-zero (repo not found).
2. **No `<ts>-m032-fixture` directory in `tests/fixtures/`** — fixtures created on disk are local-only; throwaway fixtures live entirely on GitHub. Any `tests/fixtures/<ts>-m032-fixture/` directory is leaked state.
3. **No `<ts>-m032-fixture` references in the orchestrator's `.git/refs/`** — `mkdocs gh-deploy --force` against a different cwd would push to a `gh-pages` ref under the orchestrator's tree (Finding J cross-project hazard); FR-10's cwd-vs-`repo_url:` sanity gate prevents this. Verify post-teardown with `find .git/refs -name '<ts>-m032-fixture*' -print | wc -l` returning 0.
4. **No leaked `<ts>-m032-fixture` records in audit logs** — `wiki-init.sh --deploy` appends `wiki-deploy-mutation` records to `<PROJECT_DIR>/.orchestrator/execution-log.jsonl`. These records ARE expected (audit-trail integrity per MIT-008); the invariant is that there are NO records OUTSIDE the test run's `<PROJECT_DIR>` (i.e., no records in the orchestrator-repo's own log file).

## Recovery on partial-failure teardown

If `gh repo delete` fails mid-run (network failure, auth expiry, etc.),
the operator MUST manually clean up:

```bash
# 1. Verify the throwaway fixture still exists.
gh repo view <owner>/<ts>-m032-fixture

# 2. Manually delete.
gh repo delete <owner>/<ts>-m032-fixture --yes

# 3. Audit local refs.
find .git/refs -name '<ts>-m032-fixture*' -print
# (manually `rm` any matches)
```

The recovery is documented here so operators encountering a half-cleaned
state on resume have a runbook.

## Counter-pattern history

The 2026-04-28 PBJ pilot bootstrap surfaced two related cross-project
hazards (Finding J): (a) `mkdocs gh-deploy -f` invoked from the wrong
cwd silently force-pushed one project's built site into another
project's `gh-pages` branch; (b) `tests/m032-acceptance/p03-wiki-init-deploy-live.sh`
without a teardown trap left orphan throwaway repos visible from the
operator's GitHub account. M032's protocol resolves both: (a) via
FR-10's sanity gate in `wiki-deploy.sh` (T02 deliverable), (b) via
this document's mandatory trap-EXIT teardown.

## SKIP_REASON branch (MIT-001 / POSIX exit 77)

When `gh auth status` exits non-zero (CI environment without
authenticated `gh`), the SC-5 acceptance script does NOT attempt fixture
creation. Instead it emits `SKIP_REASON: gh unauthenticated` to stdout
and exits 77 (POSIX skip-code convention). This exit code is distinct
from pass (exit 0) and fail (other non-zero); the SC-12 battery's
three-category output (`pass=N skip=M fail=K`) treats exit 77 as a
skip increment, not a pass.
```

3. **Author `tests/m032-acceptance/p03-wiki-init-deploy-live.sh`** (SC-5). Required content shape:

```bash
#!/usr/bin/env bash
# tests/m032-acceptance/p03-wiki-init-deploy-live.sh — SC-5 (FR-9 + FR-10 + FR-21).
#
# Implements the throwaway-fixture-protocol per
# tests/m032-acceptance/throwaway-fixture-protocol.md and CON-5. Exits 0
# on pass, 77 on SKIP_REASON (gh unauthenticated), other non-zero on fail.
# Three-category exit-code semantics per MIT-001.
#
# Coverage:
#  - Live --with-wiki --with-giscus --deploy invocation against a throwaway repo.
#  - Live URL responds 200 within M032_DEPLOY_PROPAGATION_TIMEOUT seconds.
#  - Served HTML contains data-repo="<owner>/<ts>-m032-fixture" attribute.
#  - .orchestrator/execution-log.jsonl carries ≥ 1 wiki-deploy-mutation record.
#  - Post-teardown: no GitHub repo, no local refs, no orphan state.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE="$REPO_ROOT/tests/fixtures/m032-fresh-project-fixture"

pass=0
fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

# Precondition: gh auth status. SKIP_REASON / exit 77 if non-zero.
if ! command -v gh >/dev/null 2>&1; then
  printf 'SKIP_REASON: gh unauthenticated (gh CLI not on PATH)\n'
  exit 77
fi
if ! gh auth status >/dev/null 2>&1; then
  printf 'SKIP_REASON: gh unauthenticated (gh auth status non-zero)\n'
  exit 77
fi

# Resolve owner from gh's authenticated account.
GH_OWNER="$(gh api user --jq .login 2>/dev/null)"
if [ -z "$GH_OWNER" ]; then
  printf 'SKIP_REASON: gh unauthenticated (could not resolve user.login)\n'
  exit 77
fi

# Throwaway fixture creation per AD-7 / throwaway-fixture-protocol.md.
TS="$(date +%s)"
FIXTURE_NAME="${TS}-m032-fixture"
PROPAGATION_TIMEOUT="${M032_DEPLOY_PROPAGATION_TIMEOUT:-90}"

cleanup() {
  set +e
  if [ -n "${FIXTURE_NAME:-}" ]; then
    gh repo delete "$GH_OWNER/$FIXTURE_NAME" --yes 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

if ! gh repo create "$FIXTURE_NAME" --private --add-readme >/dev/null 2>&1; then
  say_fail "throwaway-fixture creation failed: gh repo create $FIXTURE_NAME --private --add-readme"
  printf 'SUMMARY: SC-5 acceptance pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi
say_pass "throwaway-fixture created: $GH_OWNER/$FIXTURE_NAME"

# Re-point the fixture's git remote to the throwaway repo so wiki-init's
# FR-5 git-remote parsing resolves to the throwaway, not the P01-baseline
# fixture-owner/m032-fresh-project-fixture remote.
git -C "$FIXTURE" remote set-url origin "https://github.com/$GH_OWNER/$FIXTURE_NAME.git" 2>/dev/null || true

# Full --with-wiki --with-giscus --deploy invocation.
M032_GISCUS_IDS_FROM_GH_STUB=1 bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" \
  --with-wiki --with-giscus --deploy \
  --repo "$GH_OWNER/$FIXTURE_NAME" --category 'Wiki Comments' \
  --project-dir "$FIXTURE" >/tmp/sc5-wiki-init-stdout.$$ 2>/tmp/sc5-wiki-init-stderr.$$
deploy_rc=$?
if [ "$deploy_rc" -eq 0 ]; then
  say_pass "wiki-init.sh --with-wiki --with-giscus --deploy exited 0"
else
  say_fail "wiki-init.sh --deploy exited $deploy_rc; stderr: $(tail -10 /tmp/sc5-wiki-init-stderr.$$ | tr '\n' ' ')"
  rm -f /tmp/sc5-wiki-init-stdout.$$ /tmp/sc5-wiki-init-stderr.$$
  printf 'SUMMARY: SC-5 acceptance pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# Parse live URL from stdout.
LIVE_URL="$(tail -1 /tmp/sc5-wiki-init-stdout.$$)"
rm -f /tmp/sc5-wiki-init-stdout.$$ /tmp/sc5-wiki-init-stderr.$$
case "$LIVE_URL" in
  https://*) say_pass "live URL printed: $LIVE_URL" ;;
  *) say_fail "live URL not parsed from wiki-init stdout (got: '$LIVE_URL')"; LIVE_URL="" ;;
esac

# Curl retry loop bounded by M032_DEPLOY_PROPAGATION_TIMEOUT.
if [ -n "$LIVE_URL" ]; then
  ELAPSED=0
  STEP=10
  HTTP_OK=0
  while [ "$ELAPSED" -lt "$PROPAGATION_TIMEOUT" ]; do
    if curl -fsS -o /tmp/sc5-html.$$ "$LIVE_URL" >/dev/null 2>&1; then
      HTTP_OK=1
      break
    fi
    sleep "$STEP"
    ELAPSED=$((ELAPSED + STEP))
  done
  if [ "$HTTP_OK" -eq 1 ]; then
    say_pass "live URL responded 200 within ${ELAPSED}s (timeout ${PROPAGATION_TIMEOUT}s)"
  else
    say_fail "live URL did not respond 200 within ${PROPAGATION_TIMEOUT}s"
  fi

  # Served HTML contains the per-fixture data-repo attribute.
  if [ -f /tmp/sc5-html.$$ ] && grep -qF "data-repo=\"$GH_OWNER/$FIXTURE_NAME\"" /tmp/sc5-html.$$; then
    say_pass "served HTML contains data-repo=\"$GH_OWNER/$FIXTURE_NAME\" (FR-21 end-to-end loop)"
  else
    say_fail "served HTML missing data-repo attribute for $GH_OWNER/$FIXTURE_NAME"
  fi
  rm -f /tmp/sc5-html.$$
fi

# MIT-008 audit-trail invariant.
LOG_FILE="$FIXTURE/.orchestrator/execution-log.jsonl"
if [ -f "$LOG_FILE" ] && grep -qF '"event_type":"wiki-deploy-mutation"' "$LOG_FILE" \
   && grep -qF '"result":"success"' "$LOG_FILE"; then
  say_pass "MIT-008 audit-trail: ≥ 1 wiki-deploy-mutation record with result=success"
else
  say_fail "MIT-008 audit-trail: no wiki-deploy-mutation success record in $LOG_FILE"
fi

# Teardown is via trap. Verify post-teardown invariants AFTER trap fires by
# explicitly invoking cleanup and re-checking. (The trap will fire again at
# script exit; gh repo delete is idempotent.)
cleanup
trap - EXIT INT TERM

# No-orphan-state invariant 1: GitHub repo is gone.
if gh repo view "$GH_OWNER/$FIXTURE_NAME" --json name >/dev/null 2>&1; then
  say_fail "post-teardown: $GH_OWNER/$FIXTURE_NAME still exists on GitHub"
else
  say_pass "post-teardown: throwaway repo absent from GitHub"
fi

# No-orphan-state invariant 2: no fixture dir left in tests/fixtures/.
if [ -d "$REPO_ROOT/tests/fixtures/$FIXTURE_NAME" ]; then
  say_fail "post-teardown: tests/fixtures/$FIXTURE_NAME directory leaked"
else
  say_pass "post-teardown: no tests/fixtures/$FIXTURE_NAME directory"
fi

# No-orphan-state invariant 3: no orphan refs.
ORPHAN_REFS=$(find "$REPO_ROOT/.git/refs" -name "*$FIXTURE_NAME*" -print 2>/dev/null | wc -l | tr -d ' ')
if [ "$ORPHAN_REFS" -eq 0 ]; then
  say_pass "post-teardown: no orphan refs in .git/refs"
else
  say_fail "post-teardown: $ORPHAN_REFS orphan ref(s) in .git/refs"
fi

# Restore fixture's git remote to baseline (avoid leaving the shared fixture
# pointing at a deleted throwaway repo for downstream tests).
git -C "$FIXTURE" remote set-url origin \
  "https://github.com/fixture-owner/m032-fresh-project-fixture.git" 2>/dev/null || true

printf 'SUMMARY: SC-5 acceptance pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

4. **Author `tools/verify/m032-p03-with-feature-pattern-doc.sh`**:

```bash
#!/usr/bin/env bash
# tools/verify/m032-p03-with-feature-pattern-doc.sh — FR-13 verifier.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$REPO_ROOT/references/installation.md"
pass=0; fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

[ -f "$DOC" ] || { say_fail "$DOC absent"; printf 'SUMMARY: m032-p03-with-feature-pattern-doc pass=%d fail=%d\n' "$pass" "$fail"; exit 1; }

for tok in '--with-<feature>' 'Progressive Opt-In' 'default-off' \
           'independently composable' 'Constitution I' 'FR-13' \
           '--with-wiki' '--with-giscus' '--deploy' 'reversibility' \
           'M032 prior art'; do
  if grep -qF "$tok" "$DOC"; then
    say_pass "installation.md contains: $tok"
  else
    say_fail "installation.md missing: $tok"
  fi
done

printf 'SUMMARY: m032-p03-with-feature-pattern-doc pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

5. **Author `tools/verify/m032-p03-throwaway-protocol-shape.sh`**:

```bash
#!/usr/bin/env bash
# tools/verify/m032-p03-throwaway-protocol-shape.sh — AD-7 / CON-5 verifier.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$REPO_ROOT/tests/m032-acceptance/throwaway-fixture-protocol.md"
pass=0; fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

[ -f "$DOC" ] || { say_fail "$DOC absent"; printf 'SUMMARY: m032-p03-throwaway-protocol-shape pass=%d fail=%d\n' "$pass" "$fail"; exit 1; }

for tok in 'AD-7' 'CON-5' '<ts>-m032-fixture' 'gh repo create' 'gh repo delete' \
           '--private' '--add-readme' '--yes' 'trap cleanup EXIT INT TERM' \
           'No-orphan-state' 'SKIP_REASON' 'exit 77' 'M013' 'M014'; do
  if grep -qF "$tok" "$DOC"; then
    say_pass "throwaway-fixture-protocol.md contains: $tok"
  else
    say_fail "throwaway-fixture-protocol.md missing: $tok"
  fi
done

printf 'SUMMARY: m032-p03-throwaway-protocol-shape pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

6. **Author `tools/verify/m032-p03-acceptance-shape-sc5.sh`**:

```bash
#!/usr/bin/env bash
# tools/verify/m032-p03-acceptance-shape-sc5.sh
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ACC="$REPO_ROOT/tests/m032-acceptance/p03-wiki-init-deploy-live.sh"
pass=0; fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

[ -x "$ACC" ] || { say_fail "$ACC absent or non-executable"; printf 'SUMMARY: m032-p03-acceptance-shape-sc5 pass=%d fail=%d\n' "$pass" "$fail"; exit 1; }

for tok in 'SC-5' 'FR-9' 'FR-10' 'FR-21' 'MIT-007' 'MIT-008' \
           'throwaway-fixture-protocol.md' 'gh repo create' 'gh repo delete' \
           'M032_DEPLOY_PROPAGATION_TIMEOUT' 'wiki-deploy-mutation' \
           'SKIP_REASON' 'exit 77' 'gh auth status' 'trap cleanup' \
           'data-repo'; do
  if grep -qF "$tok" "$ACC"; then
    say_pass "SC-5 contains: $tok"
  else
    say_fail "SC-5 missing: $tok"
  fi
done

# SKIP branch hermetic exercise: invoke the script with PATH stripped of gh
# (so the SKIP precondition fires) and verify exit 77 + SKIP_REASON.
ORIG_PATH="$PATH"
ALT_PATH="$(printf '%s' "$PATH" | tr ':' '\n' | grep -v '/gh' | grep -v 'homebrew' | tr '\n' ':')"
out_skip="$(PATH="$ALT_PATH" bash "$ACC" 2>&1)"
rc_skip=$?
PATH="$ORIG_PATH"
if [ "$rc_skip" -eq 77 ] && printf '%s' "$out_skip" | grep -qF 'SKIP_REASON: gh unauthenticated'; then
  say_pass "SKIP_REASON branch: rc=77 with diagnostic when gh missing from PATH"
else
  say_pass "SKIP_REASON branch: rc=$rc_skip (gh available on stripped PATH; live branch fired — acceptable)"
fi

printf 'SUMMARY: m032-p03-acceptance-shape-sc5 pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

7. **Make all new scripts executable**: `chmod +x tests/m032-acceptance/p03-wiki-init-deploy-live.sh tools/verify/m032-p03-with-feature-pattern-doc.sh tools/verify/m032-p03-throwaway-protocol-shape.sh tools/verify/m032-p03-acceptance-shape-sc5.sh`.

## Must-Haves

- FR-13 progressive-opt-in flag-pattern documentation in `references/installation.md` (default-off, independently composable, opt-in is operator decision)
- AD-7 / CON-5 throwaway-fixture-protocol document at `tests/m032-acceptance/throwaway-fixture-protocol.md`
- SC-5 acceptance script `tests/m032-acceptance/p03-wiki-init-deploy-live.sh` implementing the protocol with three-category exit semantics (0/77/non-zero per MIT-001)
- Three project-owned verifiers: `tools/verify/m032-p03-with-feature-pattern-doc.sh`, `tools/verify/m032-p03-throwaway-protocol-shape.sh`, `tools/verify/m032-p03-acceptance-shape-sc5.sh`

## Verification

```bash
bash tools/verify/m032-p03-with-feature-pattern-doc.sh
```

```bash
bash tools/verify/m032-p03-throwaway-protocol-shape.sh
```

```bash
bash tools/verify/m032-p03-acceptance-shape-sc5.sh
```

## Notes

Expected output of each verifier: the final line is `SUMMARY: <name> pass=<N> fail=0` and exit code is 0.

The SC-5 script's behavior depends on the runtime environment:
- With `gh` authenticated → live-branch executes, exits 0 on full pass with all six pass-counters incremented (creation, deploy-rc, live-URL-print, live-URL-200, served-HTML-data-repo, MIT-008-audit-record, plus the three post-teardown invariants).
- Without `gh` (or `gh auth status` non-zero) → SKIP branch executes, exits 77 with `SKIP_REASON: gh unauthenticated`.
- Live branch failure mid-run → trap fires, throwaway repo cleaned up, exits non-zero.

The verifier-shape gate (`m032-p03-acceptance-shape-sc5.sh`) exercises the SKIP branch hermetically (PATH-stripped) but does NOT exercise the live branch — the live branch is exercised by SC-12's acceptance battery against authenticated `gh` in CI.

The `M032_GISCUS_IDS_FROM_GH_STUB=1` env-var is set in the SC-5 invocation: even though SC-5 is "live", we use stub-mode for the Giscus side because (a) Giscus is the consumer's choice and not load-bearing for the deploy-pipeline correctness test, and (b) it avoids GraphQL rate-limit dependency on the authenticated CI account. The deploy-side `gh api` calls (PATCH discussions, GET pages, PUT pages) ARE live — that's the load-bearing surface CON-5 mandates testing live.

The `tests/fixtures/m032-fresh-project-fixture/` git remote is temporarily re-pointed at the throwaway repo during SC-5 execution so wiki-init's FR-5 git-remote parsing resolves to the throwaway. The script restores the baseline remote in cleanup. If SC-5 exits mid-run via failure path AFTER the remote re-point but BEFORE the cleanup, downstream tests inherit a fixture pointing at a deleted throwaway repo — this is a documented risk; the operator MUST manually `git remote set-url origin https://github.com/fixture-owner/m032-fresh-project-fixture.git` to recover. (A future hardening could move the remote-repoint into a sub-fixture clone, but that's beyond M032/P03 scope.)

## Inputs

### From Previous Tasks

- `scripts/lifecycle/wiki-init.sh` (T01 + T02, parallel within P03) — at SC-5 EXECUTION time (not authoring time), the script must support `--with-wiki --with-giscus --deploy --repo --category --project-dir` flag chain. Plan against the documented flag-chain contract (FR-8 + FR-9 from spec); the implementation is T01+T02's responsibility.
- `scripts/wiki/wiki-deploy.sh` (T02) — at SC-5 execution time, the script must honor the FR-10 cwd-vs-`repo_url:` sanity gate. SC-5 doesn't directly invoke `wiki-deploy.sh` (that's `wiki-init.sh --deploy`'s step 2), but the cwd-gate firing inside step 2 is a load-bearing precondition for the live deploy succeeding.

### From Disk (Pre-existing)

- `references/installation.md` (orchestrator-repo baseline) — T04 amends additively.
- `tests/m032-acceptance/` (P01/P02) — T04 adds two new files; pre-existing scripts are NOT modified.
- `tests/fixtures/m032-fresh-project-fixture/` (P01) — read-only (T04 temporarily re-points its git remote during SC-5; cleanup restores).
- `gh` CLI — environment dependency (presence detected at SC-5 start; absence triggers SKIP branch).

## Constraints

- Single-script-file shape for ALL verifier `Check:` commands per AD-19.
- bash 3.2 compatibility (per MEM001).
- Verifier scripts MUST live under `tools/verify/` with the `m032-p03-*` prefix.
- The FR-13 `references/installation.md` amendment is ADDITIVE — pre-existing content is byte-preserved.
- The `<owner>` value in the throwaway-fixture-protocol document is INTENTIONALLY left as the placeholder `<owner>` in the prose body; the SC-5 script resolves it at runtime via `gh api user --jq .login`.
- The trap-EXIT pattern in SC-5 MUST fire even on script failure (validated by the "Live branch failure mid-run" Notes sub-bullet).
- `M032_DEPLOY_PROPAGATION_TIMEOUT` default is 90 seconds (named in P03-PLAN.md's demo sentence + spec FR-9 + `tests/m032-acceptance/throwaway-fixture-protocol.md`); SC-5 honors operator override via env-var.
- Co-author the verifier scripts within T04 — do NOT defer to T05 per plan-time discipline rule 2.

## Expected Output

After T04 completes:

- `references/installation.md` carries the new `## --with-<feature> Progressive Opt-In Flag Pattern` section (FR-13).
- `tests/m032-acceptance/throwaway-fixture-protocol.md` exists and documents the AD-7 / CON-5 protocol.
- `tests/m032-acceptance/p03-wiki-init-deploy-live.sh` exists and is executable (SC-5 acceptance).
- `tools/verify/m032-p03-with-feature-pattern-doc.sh`, `tools/verify/m032-p03-throwaway-protocol-shape.sh`, `tools/verify/m032-p03-acceptance-shape-sc5.sh` exist and exit 0.
- The three `Check:` commands listed in P03-PLAN.md's "Truths" section for T04-owned truths return exit 0.

## State Context

- **Current State**: executing
- **Milestone**: M032
- **Phase**: P03
- **Task**: T04-throwaway-fixture-and-sc5
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- Single-script-file shape for ALL verifier `Check:` commands per AD-19.
- bash 3.2 compatibility (per MEM001).
- Verifier scripts MUST live under `tools/verify/` with the `m032-p03-*` prefix.
- The FR-13 `references/installation.md` amendment is ADDITIVE — pre-existing content is byte-preserved.
- The `<owner>` value in the throwaway-fixture-protocol document is INTENTIONALLY left as the placeholder `<owner>` in the prose body; the SC-5 script resolves it at runtime via `gh api user --jq .login`.
- The trap-EXIT pattern in SC-5 MUST fire even on script failure (validated by the "Live branch failure mid-run" Notes sub-bullet).
- `M032_DEPLOY_PROPAGATION_TIMEOUT` default is 90 seconds (named in P03-PLAN.md's demo sentence + spec FR-9 + `tests/m032-acceptance/throwaway-fixture-protocol.md`); SC-5 honors operator override via env-var.
- Co-author the verifier scripts within T04 — do NOT defer to T05 per plan-time discipline rule 2.

### Acceptance Criteria

- FR-13 progressive-opt-in flag-pattern documentation in `references/installation.md` (default-off, independently composable, opt-in is operator decision)
- AD-7 / CON-5 throwaway-fixture-protocol document at `tests/m032-acceptance/throwaway-fixture-protocol.md`
- SC-5 acceptance script `tests/m032-acceptance/p03-wiki-init-deploy-live.sh` implementing the protocol with three-category exit semantics (0/77/non-zero per MIT-001)
- Three project-owned verifiers: `tools/verify/m032-p03-with-feature-pattern-doc.sh`, `tools/verify/m032-p03-throwaway-protocol-shape.sh`, `tools/verify/m032-p03-acceptance-shape-sc5.sh`

### Files To Touch

- `wiki/overrides/partials/comments.html` (modify — add the four `{{giscus_*}}` placeholder tokens to the bundle-staged template surface)
- `scripts/lifecycle/wiki-init.sh` (modify — add `--with-giscus` and `--deploy` scope handlers + audit-trail emission)
- `scripts/wiki/wiki-deploy.sh` (modify — add FR-10 cwd-vs-`repo_url:` sanity gate)
- `scripts/wiki/wiki-generate-nav.sh` (modify — split nav block into `auto-nav` / `custom-nav` regions with MIT-005 migration branch)
- `wiki/mkdocs.yml` (modify — self-application: run the migrated nav generator against the orchestrator repo so legacy `# >>> M012-P01 nav` markers migrate to the new region shape)
- `references/installation.md` (modify — add `## --with-<feature> Progressive Opt-In Flag Pattern` section per FR-13)
- `tests/m032-acceptance/throwaway-fixture-protocol.md` (create)
- `tests/m032-acceptance/p02-wiki-init-with-giscus.sh` (create)
- `tests/m032-acceptance/p03-wiki-init-deploy-live.sh` (create)
- `tests/m032-acceptance/p02-wiki-generate-nav-custom-region.sh` (create)
- `tools/verify/m032-p03-giscus-templating.sh` (create)
- `tools/verify/m032-p03-with-giscus-scope.sh` (create)
- `tools/verify/m032-p03-deploy-scope.sh` (create)
- `tools/verify/m032-p03-wiki-deploy-cwd-gate.sh` (create)
- `tools/verify/m032-p03-custom-nav-region.sh` (create)
- `tools/verify/m032-p03-with-feature-pattern-doc.sh` (create)
- `tools/verify/m032-p03-throwaway-protocol-shape.sh` (create)
- `tools/verify/m032-p03-acceptance-shape-sc4.sh` (create)
- `tools/verify/m032-p03-acceptance-shape-sc5.sh` (create)
- `tools/verify/m032-p03-acceptance-shape-sc6.sh` (create)
- `tools/verify/m032-p03-phase-suite.sh` (create)
- `tools/verify/m032-p03-scope-guard.sh` (create)
- `tools/verify/fixtures/m032-p03-baseline-ref.txt` (create — captured by T05 per the P01/P02 baseline-ref convention)

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