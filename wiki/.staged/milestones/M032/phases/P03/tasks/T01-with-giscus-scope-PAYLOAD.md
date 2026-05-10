---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T01-with-giscus-scope (Phase P03, Milestone M032)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~300 | required |
| Upstream Context | 981-1161 | ~4000 | required |
| Task Plan | 1163-1681 | ~8000 | required |
| State Context | 1683-1689 | ~100 | required |
| First-Turn Completeness | 1691-1736 | ~900 | required |
| **Total** | | **~24100** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 816
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
hit_count: 816
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
hit_count: 816
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
hit_count: 816
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
hit_count: 709
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
hit_count: 709
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
hit_count: 709
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
hit_count: 816
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
hit_count: 709
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
hit_count: 709
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
hit_count: 709
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
hit_count: 816
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
hit_count: 816
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
hit_count: 816
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
hit_count: 709
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
hit_count: 709
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
hit_count: 709
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
hit_count: 816
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
hit_count: 709
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
hit_count: 709
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
hit_count: 816
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
hit_count: 816
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
hit_count: 709
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
hit_count: 709
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
hit_count: 709
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
hit_count: 364
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
hit_count: 364
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
hit_count: 364
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
hit_count: 392
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
hit_count: 392
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
hit_count: 382
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
task: "T01"
phase: "P03"
milestone: "M032"
name: "FR-7 Giscus partial templating + FR-8 --with-giscus scope on wiki-init.sh + SC-4 acceptance"
depends_on: []
---

## Prerequisites

- `scripts/lifecycle/wiki-init.sh` exists and is executable from P02/T01. Verified by `[ -x scripts/lifecycle/wiki-init.sh ]`. Behavioral contract: bash 3.2; `set -eu`; recognizes `--project-dir`, `--site-name`, `--site-description`, `--auto-pip`, `--force` flags; honors `--with-giscus` and `--deploy` flags by REJECTING with exit 5 + `not yet implemented in P02; reserved for P03` (the current P02 reject-stub that this task amends to the real implementation); honors `M032_WIKI_INIT_FORCE_EXIT=<n>` env-var test-only failure injection.
- `scripts/diagnostics/giscus-ids-from-gh.sh` exists and is executable. Verified by `[ -x scripts/diagnostics/giscus-ids-from-gh.sh ]`. Behavioral contract: takes `--repo <owner>/<repo>` and `--category <name>` flags; on success emits four `export GISCUS_REPO="<value>"`, `export GISCUS_REPO_ID="<value>"`, `export GISCUS_CATEGORY="<value>"`, `export GISCUS_CATEGORY_ID="<value>"` lines on stdout (in that order, line-by-line, no leading/trailing blank lines); on failure exits non-zero with `ERROR: <reason>` on stderr; requires `gh` on PATH and authenticated.
- `scripts/diagnostics/wiki-giscus-config-check.sh` exists and is executable. Verified by `[ -x scripts/diagnostics/wiki-giscus-config-check.sh ]`. Behavioral contract: takes `--quiet` and `--project-dir <dir>` flags; on success exits 0; on failure exits non-zero with diagnostic on stderr naming any unset `GISCUS_*` env vars or any missing `data-*` attributes in the partial.
- `wiki/overrides/partials/comments.html` exists at the orchestrator repo with the existing `{{ config.extra.giscus.* }}` Jinja interpolations on lines 25–28 (M012/P03/T01-baseline). Verified by `[ -f wiki/overrides/partials/comments.html ]` and `grep -q 'config.extra.giscus.repo' wiki/overrides/partials/comments.html`.
- `tests/fixtures/m032-fresh-project-fixture/` exists from P01 with the fixture's git remote at `https://github.com/fixture-owner/m032-fresh-project-fixture.git`. After P02/T01 ran, `<fixture>/wiki/overrides/partials/comments.html` should already exist as a bundle-staged copy (T01 verifies this precondition and re-stages if absent).
- `tools/verify/` exists as the canonical home for project-owned slug-bearing verifiers per AD-19.
- `tests/m032-acceptance/` exists from P01/P02 with prior acceptance scripts (`p01-managed-bundle-shape.sh`, `p02-wiki-init-default-scope.sh`, etc.).

## Description

T01 lands the first composable scope on top of P02's default-scope `wiki-init.sh`. The deliverable surface has three pieces that ship together:

1. **FR-7 partial templating**: amend `wiki/overrides/partials/comments.html` to interleave the four `{{giscus_repo}}` / `{{giscus_repo_id}}` / `{{giscus_category}}` / `{{giscus_category_id}}` placeholder tokens with the existing Jinja interpolations. The two interpolation paths coexist by design — see "Coexistence model" in step 1 below.

2. **FR-8 `--with-giscus` scope**: amend `scripts/lifecycle/wiki-init.sh` to recognize `--with-giscus --repo <owner>/<repo> --category <name>` and execute the four-step `--with-giscus` workflow: invoke `giscus-ids-from-gh.sh` (with stub-mode envelope), parse four `export GISCUS_*` lines from stdout, sed-substitute the four placeholders in the staged partial, invoke `wiki-giscus-config-check.sh` as post-step verifier.

3. **SC-4 acceptance script**: author `tests/m032-acceptance/p02-wiki-init-with-giscus.sh` exercising happy-path / failure / re-run-idempotency / overwrite branches against the P01 shared fixture using `M032_GISCUS_IDS_FROM_GH_STUB` envelopes for deterministic CI behavior.

The atomicity argument for landing all three sub-deliverables in a single task: the partial templating (FR-7) is meaningless without the script (FR-8) that substitutes against it, and the script's correctness is uninspectable without the acceptance script (SC-4). Splitting introduces test windows where the bundle-staged partial carries placeholder tokens but no script writes against them, which fails the FR-22 collision invariant on next install (any consumer running `init` between landing-FR-7 and landing-FR-8 would inherit the placeholder partial and have no recourse).

## Steps

1. **Amend `wiki/overrides/partials/comments.html`** to add the four placeholder tokens. Coexistence model: the four `data-*` attribute lines (currently lines 25–28) carry BOTH the existing Jinja `{{ config.extra.giscus.* }}` interpolation (which mkdocs resolves at `mkdocs build` time from `extra.giscus.*` `!ENV [GISCUS_*, ""]` block in mkdocs.yml) AND the new M032-spec placeholder tokens that `wiki-init.sh --with-giscus` rewrites at install time. Required line shape (replace existing lines 25–28 with the new lines below; preserve the surrounding `<script ...>` opening tag on line 23–24 and the rest of the file unchanged):

```html
    data-repo="{{giscus_repo}}{{ config.extra.giscus.repo }}"
    data-repo-id="{{giscus_repo_id}}{{ config.extra.giscus.repo_id }}"
    data-category="{{giscus_category}}{{ config.extra.giscus.category }}"
    data-category-id="{{giscus_category_id}}{{ config.extra.giscus.category_id }}"
```

The concatenation shape (`{{giscus_repo}}` immediately followed by `{{ config.extra.giscus.repo }}`) is load-bearing: in the bundle-staged surface (where `mkdocs build` has not yet run) the literal `{{giscus_repo}}` token is what `wiki-init.sh --with-giscus` sed-substitutes against; in the orchestrator-local surface (where `--with-giscus` has not been run because the orchestrator uses `!ENV` Jinja interpolation directly), the literal `{{giscus_repo}}` token resolves at `mkdocs build` time to the empty string (Jinja's default for an undefined variable in a strict-mode-disabled config — verify `wiki/mkdocs.yml`'s `strict: false` baseline) leaving `{{ config.extra.giscus.repo }}` alone to be Jinja-interpolated. After `--with-giscus` runs against a consumer, the literal `{{giscus_repo}}` is replaced with the resolved repo slug AND `{{ config.extra.giscus.repo }}` remains in place (mkdocs build time will resolve THAT to whatever the consumer has in `mkdocs.yml`'s `extra.giscus.repo` — which the consumer can set to a static string in their mkdocs.yml fork OR leave empty for the placeholder-substitution path to be the sole source of truth).

Add a comment block between the existing `{# ... #}` Jinja comment (lines 1–16) and the `{% if ... %}` block (line 17) explaining the coexistence model:

```html
{#
  M032/P03/T01 — FR-7: dual-template interpolation surface.

  Each data-* attribute carries TWO interpolation forms:

    {{giscus_repo}}                  — M032 placeholder, sed-substituted by
                                       wiki-init.sh --with-giscus from the
                                       output of giscus-ids-from-gh.sh.
    {{ config.extra.giscus.repo }}   — Jinja+!ENV interpolation, resolved at
                                       mkdocs build time from mkdocs.yml's
                                       extra.giscus.* !ENV [GISCUS_*, ""] block.

  Bundle-staged copies carry both unrendered. wiki-init.sh --with-giscus
  rewrites the M032 placeholder; mkdocs build then resolves the Jinja form
  (which may be empty for projects that drive Giscus IDs entirely through
  the M032 path). The orchestrator-repo-local copy uses the Jinja+!ENV path
  (no --with-giscus run against the orchestrator itself) — the M032
  placeholders resolve to the empty string at mkdocs build.
#}
```

2. **Stage the amended partial in the bundle source**. The bundle source for the wiki/ project_assets entry is `<repo>/wiki/` (per P02/T01's manifest amendment). Since the orchestrator-repo's `wiki/overrides/partials/comments.html` is now the bundle source AND the orchestrator's own active partial, the amendment lands once and serves both consumers and the orchestrator-itself. Confirm this by inspecting `packaging/bundle/manifest.yml` for the `source: wiki/` entry under `project_assets:`.

3. **Amend `scripts/lifecycle/wiki-init.sh` to recognize `--with-giscus`** and replace the existing P02 reject-stub (which currently exits 5 with `not yet implemented in P02; reserved for P03`). Replace the block at lines 69–73 of P02-baseline `wiki-init.sh` (the `if [ "$WITH_GISCUS" = "1" ] || [ "$WITH_DEPLOY" = "1" ]; then ... reserved for P03 ... fi` block) with a conditional that branches on which scope is set: if `WITH_GISCUS=1` AND `WITH_DEPLOY=0`, dispatch to the new `--with-giscus` workflow (added below); if `WITH_DEPLOY=1`, dispatch to the new `--deploy` workflow (added by T02 — for T01's purpose, leave a placeholder reject for `WITH_DEPLOY=1` only, which T02 replaces).

Required `--with-giscus` flag-parsing additions to the flag-parse block (preserve existing `--project-dir`, `--site-name`, `--site-description`, `--auto-pip`, `--force` flags; add `--repo` and `--category` flags as below):

```bash
GISCUS_REPO_FLAG=""
GISCUS_CATEGORY_FLAG=""

# (inside the existing while [ $# -gt 0 ]; do case "$1" in ... esac done loop, add new arms:)
    --repo)
      shift
      if [ $# -eq 0 ]; then
        echo "FAIL: wiki-init: --repo requires an <owner>/<repo> argument" >&2
        exit 2
      fi
      GISCUS_REPO_FLAG="$1"; shift ;;
    --category)
      shift
      if [ $# -eq 0 ]; then
        echo "FAIL: wiki-init: --category requires a category-name argument" >&2
        exit 2
      fi
      GISCUS_CATEGORY_FLAG="$1"; shift ;;
```

Required `--with-giscus` workflow block (insert AFTER the FR-12 python toolchain probe and BEFORE the FR-5 git-remote-parsing block — `--with-giscus` is composable with `--with-wiki`; if `--with-giscus` is the first scope passed, the default-scope mkdocs templating MUST have already run on a prior `--with-wiki` invocation per the documented composition order. If the default-scope artifacts are absent at `--with-giscus` invocation, the script exits non-zero with `wiki-init: --with-giscus requires --with-wiki to have been run first; missing <fixture>/wiki/overrides/partials/comments.html`):

```bash
# FR-8 --with-giscus scope: substitute the four {{giscus_*}} placeholder tokens
# in <PROJECT_DIR>/wiki/overrides/partials/comments.html against IDs fetched
# from giscus-ids-from-gh.sh (or M032_GISCUS_IDS_FROM_GH_STUB stub mode).
if [ "$WITH_GISCUS" = "1" ]; then
  if [ -z "$GISCUS_REPO_FLAG" ] || [ -z "$GISCUS_CATEGORY_FLAG" ]; then
    echo "FAIL: wiki-init: --with-giscus requires both --repo <owner>/<repo> and --category <name>" >&2
    exit 2
  fi
  PARTIAL="$PROJECT_DIR/wiki/overrides/partials/comments.html"
  if [ ! -f "$PARTIAL" ]; then
    echo "FAIL: wiki-init: --with-giscus requires --with-wiki to have been run first; missing $PARTIAL" >&2
    exit 7
  fi

  # Test-only stub mode envelope per the M026/MEM030 <TOOL>_<NAME> env-var convention.
  IDS_OUT=""
  case "${M032_GISCUS_IDS_FROM_GH_STUB:-}" in
    1)
      # Deterministic fixture IDs — do not reach the network.
      IDS_OUT=$(printf 'export GISCUS_REPO="%s"\nexport GISCUS_REPO_ID="R_kgDOFixture"\nexport GISCUS_CATEGORY="%s"\nexport GISCUS_CATEGORY_ID="DIC_kwDOFixture"\n' "$GISCUS_REPO_FLAG" "$GISCUS_CATEGORY_FLAG")
      ids_rc=0
      ;;
    fail)
      echo "FAIL: wiki-init: integration-giscus-config-failed: M032_GISCUS_IDS_FROM_GH_STUB=fail (forced failure injection)" >&2
      exit 8
      ;;
    *)
      # Live path — invoke the real helper.
      set +e
      IDS_OUT="$(bash "$REPO_ROOT/scripts/diagnostics/giscus-ids-from-gh.sh" --repo "$GISCUS_REPO_FLAG" --category "$GISCUS_CATEGORY_FLAG" 2>&1)"
      ids_rc=$?
      set -e
      if [ "$ids_rc" -ne 0 ]; then
        echo "FAIL: wiki-init: integration-giscus-config-failed: giscus-ids-from-gh.sh exited $ids_rc — $IDS_OUT" >&2
        exit 8
      fi
      ;;
  esac

  # Parse the four export lines into shell variables.
  GISCUS_REPO_VAL=$(printf '%s' "$IDS_OUT" | sed -n 's/^export GISCUS_REPO="\(.*\)"$/\1/p')
  GISCUS_REPO_ID_VAL=$(printf '%s' "$IDS_OUT" | sed -n 's/^export GISCUS_REPO_ID="\(.*\)"$/\1/p')
  GISCUS_CATEGORY_VAL=$(printf '%s' "$IDS_OUT" | sed -n 's/^export GISCUS_CATEGORY="\(.*\)"$/\1/p')
  GISCUS_CATEGORY_ID_VAL=$(printf '%s' "$IDS_OUT" | sed -n 's/^export GISCUS_CATEGORY_ID="\(.*\)"$/\1/p')
  if [ -z "$GISCUS_REPO_VAL" ] || [ -z "$GISCUS_REPO_ID_VAL" ] || [ -z "$GISCUS_CATEGORY_VAL" ] || [ -z "$GISCUS_CATEGORY_ID_VAL" ]; then
    echo "FAIL: wiki-init: integration-giscus-config-failed: could not parse all four GISCUS_* exports from helper output" >&2
    exit 8
  fi

  # Sed-substitute the four {{giscus_*}} placeholders. Use | as the sed
  # delimiter (none of the values contain |); escape & in values for
  # sed-replacement-safety. Bash 3.2 sed-in-place: BSD sed requires `-i ''`,
  # GNU sed accepts `-i`. Use a temp-file rename pattern to avoid the difference.
  TMP_PARTIAL="$(mktemp -t comments.html.XXXXXX)"
  trap 'rm -f "$TMP_PARTIAL"' EXIT
  sed_escape() { printf '%s' "$1" | sed -e 's|[\\&|]|\\&|g'; }
  GR_E=$(sed_escape "$GISCUS_REPO_VAL")
  GRI_E=$(sed_escape "$GISCUS_REPO_ID_VAL")
  GC_E=$(sed_escape "$GISCUS_CATEGORY_VAL")
  GCI_E=$(sed_escape "$GISCUS_CATEGORY_ID_VAL")
  sed \
    -e "s|{{giscus_repo}}|$GR_E|g" \
    -e "s|{{giscus_repo_id}}|$GRI_E|g" \
    -e "s|{{giscus_category}}|$GC_E|g" \
    -e "s|{{giscus_category_id}}|$GCI_E|g" \
    "$PARTIAL" > "$TMP_PARTIAL"
  cp "$TMP_PARTIAL" "$PARTIAL"
  rm -f "$TMP_PARTIAL"
  trap - EXIT

  # FR-8 post-step verifier.
  set +e
  bash "$REPO_ROOT/scripts/diagnostics/wiki-giscus-config-check.sh" --project-dir "$PROJECT_DIR" --quiet
  check_rc=$?
  set -e
  if [ "$check_rc" -ne 0 ]; then
    echo "FAIL: wiki-init: integration-giscus-config-check-failed: wiki-giscus-config-check.sh exited $check_rc against $PROJECT_DIR" >&2
    exit 9
  fi

  echo "wiki-init: --with-giscus done — substituted four giscus IDs in $PARTIAL"
fi
```

Update the file-header exit-code comment block to reflect the new exit codes:

```
# Exit codes:
#   0 — success.
#   2 — argument error.
#   3 — toolchain missing.
#   4 — git remote missing or unparseable.
#   5 — --deploy passed but not implemented (P03/T02 replaces this).
#   6 — bundle staging failure.
#   7 — --with-giscus invoked without --with-wiki (no <fixture>/wiki/overrides/partials/comments.html).
#   8 — integration-giscus-config-failed (giscus-ids-from-gh.sh upstream failure).
#   9 — integration-giscus-config-check-failed (wiki-giscus-config-check.sh post-step failure).
```

4. **Author `tests/m032-acceptance/p02-wiki-init-with-giscus.sh` (SC-4)**. The test runs against the P01 shared fixture at `tests/fixtures/m032-fresh-project-fixture/`. It MUST first run a default `wiki-init.sh --project-dir <fixture>` to ensure the partial is staged in the fixture (idempotent — preserves prior state). Then exercise four branches: happy-path (stub mode 1), failure mode (stub mode `fail`), re-run idempotency, overwrite branch.

```bash
#!/usr/bin/env bash
# tests/m032-acceptance/p02-wiki-init-with-giscus.sh — SC-4 (FR-7 + FR-8).
#
# Verifies: wiki/overrides/partials/comments.html bundle-staged copy carries
# the four {{giscus_*}} placeholder tokens; wiki-init.sh --with-giscus
# substitutes them with deterministic fixture IDs under
# M032_GISCUS_IDS_FROM_GH_STUB=1; the post-step wiki-giscus-config-check.sh
# verifier exits 0; failure injection (M032_GISCUS_IDS_FROM_GH_STUB=fail)
# leaves the partial in placeholder state with `integration-giscus-config-failed`
# diagnostic; re-run with same flags is idempotent; re-run with different
# flags overwrites with new IDs (US-3 AS-3).

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE="$REPO_ROOT/tests/fixtures/m032-fresh-project-fixture"
PARTIAL="$FIXTURE/wiki/overrides/partials/comments.html"

pass=0
fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

# Pre-1: wiki-init default scope to stage the partial in the fixture.
if ! bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" --project-dir "$FIXTURE" >/dev/null 2>&1; then
  say_fail "default-scope wiki-init failed against fixture (SC-4 precondition)"
  printf 'SUMMARY: SC-4 acceptance pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# 1. Bundle-staged partial carries the four placeholder tokens.
if grep -qF '{{giscus_repo}}' "$PARTIAL" && \
   grep -qF '{{giscus_repo_id}}' "$PARTIAL" && \
   grep -qF '{{giscus_category}}' "$PARTIAL" && \
   grep -qF '{{giscus_category_id}}' "$PARTIAL"; then
  say_pass "FR-7: four {{giscus_*}} placeholder tokens present in staged partial"
else
  say_fail "FR-7: one or more {{giscus_*}} placeholder tokens missing from $PARTIAL"
fi

# 2. Happy path with stub mode 1.
M032_GISCUS_IDS_FROM_GH_STUB=1 bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" \
  --with-giscus --repo fixture-owner/fixture-repo --category 'Wiki Comments' \
  --project-dir "$FIXTURE" >/dev/null 2>&1
giscus_rc=$?
if [ "$giscus_rc" -eq 0 ] && \
   grep -qF 'fixture-owner/fixture-repo' "$PARTIAL" && \
   grep -qF 'R_kgDOFixture' "$PARTIAL" && \
   grep -qF 'Wiki Comments' "$PARTIAL" && \
   grep -qF 'DIC_kwDOFixture' "$PARTIAL" && \
   ! grep -qF '{{giscus_repo}}' "$PARTIAL"; then
  say_pass "FR-8 happy path: four IDs substituted, no {{giscus_repo}} placeholder remains"
else
  say_fail "FR-8 happy path: rc=$giscus_rc; partial does not carry expected fixture IDs (or placeholder remains)"
fi

# 3. Post-step verifier exits 0.
bash "$REPO_ROOT/scripts/diagnostics/wiki-giscus-config-check.sh" --project-dir "$FIXTURE" --quiet
check_rc=$?
if [ "$check_rc" -eq 0 ]; then
  say_pass "FR-8 post-step: wiki-giscus-config-check.sh exits 0 after substitution"
else
  say_fail "FR-8 post-step: wiki-giscus-config-check.sh rc=$check_rc"
fi

# 4. Failure injection branch — re-stage the partial first to reset placeholder state.
bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" --project-dir "$FIXTURE" --force >/dev/null 2>&1
err_out="$(M032_GISCUS_IDS_FROM_GH_STUB=fail bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" \
  --with-giscus --repo fixture-owner/fixture-repo --category 'Wiki Comments' \
  --project-dir "$FIXTURE" 2>&1)"
inject_rc=$?
if [ "$inject_rc" -ne 0 ] && \
   printf '%s' "$err_out" | grep -qF 'integration-giscus-config-failed' && \
   grep -qF '{{giscus_repo}}' "$PARTIAL"; then
  say_pass "FR-8 failure injection: rc=$inject_rc, integration-giscus-config-failed diagnostic, partial in placeholder state"
else
  say_fail "FR-8 failure injection: rc=$inject_rc; expected non-zero with diagnostic and placeholders preserved"
fi

# 5. Re-run idempotency (same flags twice).
bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" --project-dir "$FIXTURE" --force >/dev/null 2>&1
M032_GISCUS_IDS_FROM_GH_STUB=1 bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" \
  --with-giscus --repo fixture-owner/fixture-repo --category 'Wiki Comments' \
  --project-dir "$FIXTURE" >/dev/null 2>&1
SHA_FIRST=$(shasum -a 256 "$PARTIAL" | awk '{print $1}')
M032_GISCUS_IDS_FROM_GH_STUB=1 bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" \
  --with-giscus --repo fixture-owner/fixture-repo --category 'Wiki Comments' \
  --project-dir "$FIXTURE" >/dev/null 2>&1
SHA_SECOND=$(shasum -a 256 "$PARTIAL" | awk '{print $1}')
if [ "$SHA_FIRST" = "$SHA_SECOND" ]; then
  say_pass "FR-8 re-run idempotency: partial sha-256 stable across two same-flag invocations"
else
  say_fail "FR-8 re-run idempotency: partial sha-256 changed: $SHA_FIRST -> $SHA_SECOND"
fi

# 6. Overwrite branch (US-3 AS-3) — different --repo / --category re-substitutes.
M032_GISCUS_IDS_FROM_GH_STUB=1 bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" \
  --with-giscus --repo fixture-owner-2/fixture-repo-2 --category 'Different Category' \
  --project-dir "$FIXTURE" >/dev/null 2>&1
overwrite_rc=$?
if [ "$overwrite_rc" -eq 0 ] && \
   grep -qF 'fixture-owner-2/fixture-repo-2' "$PARTIAL" && \
   grep -qF 'Different Category' "$PARTIAL" && \
   ! grep -qF 'fixture-owner/fixture-repo' "$PARTIAL"; then
  say_pass "FR-8 overwrite branch (US-3 AS-3): new IDs replace prior IDs"
else
  say_fail "FR-8 overwrite branch: rc=$overwrite_rc; new IDs absent or prior IDs not displaced"
fi

# Restore placeholder state (clean teardown).
bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" --project-dir "$FIXTURE" --force >/dev/null 2>&1 || true

printf 'SUMMARY: SC-4 acceptance pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

Make executable: `chmod +x tests/m032-acceptance/p02-wiki-init-with-giscus.sh`.

5. **Author `tools/verify/m032-p03-giscus-templating.sh`** (FR-7 verifier). Asserts the four placeholder tokens are present at the expected line shapes in `wiki/overrides/partials/comments.html`. Single-script-file shape per AD-19. Required content shape:

```bash
#!/usr/bin/env bash
# tools/verify/m032-p03-giscus-templating.sh — FR-7 verifier.
# Asserts the four M032 {{giscus_*}} placeholder tokens are interleaved
# with the existing Jinja {{ config.extra.giscus.* }} interpolations in
# the bundle-staged Giscus partial.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PARTIAL="$REPO_ROOT/wiki/overrides/partials/comments.html"
pass=0; fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

[ -f "$PARTIAL" ] || { say_fail "missing $PARTIAL"; printf 'SUMMARY: m032-p03-giscus-templating pass=%d fail=%d\n' "$pass" "$fail"; exit 1; }

for tok in '{{giscus_repo}}' '{{giscus_repo_id}}' '{{giscus_category}}' '{{giscus_category_id}}'; do
  if grep -qF "$tok" "$PARTIAL"; then
    say_pass "placeholder token present: $tok"
  else
    say_fail "placeholder token absent: $tok"
  fi
done

# Coexistence: the existing Jinja interpolations must STILL be present.
for jinja in 'config.extra.giscus.repo' 'config.extra.giscus.repo_id' 'config.extra.giscus.category' 'config.extra.giscus.category_id'; do
  if grep -qF "$jinja" "$PARTIAL"; then
    say_pass "jinja interpolation preserved: $jinja"
  else
    say_fail "jinja interpolation missing: $jinja (FR-7 coexistence model violated)"
  fi
done

# FR-7 documentation comment block.
if grep -qF 'M032/P03/T01 — FR-7' "$PARTIAL"; then
  say_pass "FR-7 comment block present"
else
  say_fail "FR-7 comment block missing (expected 'M032/P03/T01 — FR-7' marker)"
fi

printf 'SUMMARY: m032-p03-giscus-templating pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

6. **Author `tools/verify/m032-p03-with-giscus-scope.sh`** (FR-8 verifier). Asserts the wiki-init.sh `--with-giscus` workflow code path is present (text-grep checks against the script body) and exercises stub-mode happy-path and failure-injection branches against a tmpdir fixture (NOT the shared P01 fixture — keep this verifier hermetic; the SC-4 acceptance script exercises the shared fixture). Single-script-file shape. Required content sketch:

```bash
#!/usr/bin/env bash
# tools/verify/m032-p03-with-giscus-scope.sh — FR-8 verifier.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WI="$REPO_ROOT/scripts/lifecycle/wiki-init.sh"
pass=0; fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

# Static text checks on wiki-init.sh source.
for tok in '--with-giscus' '--repo' '--category' 'M032_GISCUS_IDS_FROM_GH_STUB' \
           'wiki-giscus-config-check.sh' 'integration-giscus-config-failed' \
           'integration-giscus-config-check-failed' 'GISCUS_REPO_VAL' \
           'GISCUS_REPO_ID_VAL' 'GISCUS_CATEGORY_VAL' 'GISCUS_CATEGORY_ID_VAL'; do
  if grep -qF "$tok" "$WI"; then
    say_pass "wiki-init.sh contains: $tok"
  else
    say_fail "wiki-init.sh missing: $tok"
  fi
done

# Hermetic stub-mode happy path against a tmpdir fixture.
TMPDIR_F=$(mktemp -d -t m032-p03-with-giscus.XXXXXX)
trap 'rm -rf "$TMPDIR_F"' EXIT
mkdir -p "$TMPDIR_F/wiki/overrides/partials"
cp "$REPO_ROOT/wiki/overrides/partials/comments.html" "$TMPDIR_F/wiki/overrides/partials/comments.html"
# Set up a minimal git remote so wiki-init's FR-5 path doesn't bail.
(cd "$TMPDIR_F" && git init -q && git remote add origin https://github.com/fixture-owner/m032-p03-tmp.git)

M032_GISCUS_IDS_FROM_GH_STUB=1 bash "$WI" \
  --with-giscus --repo fixture-owner/m032-p03-tmp --category 'Wiki Comments' \
  --project-dir "$TMPDIR_F" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ] && grep -qF 'fixture-owner/m032-p03-tmp' "$TMPDIR_F/wiki/overrides/partials/comments.html"; then
  say_pass "stub-mode happy path substitutes IDs in tmpdir fixture (rc=0)"
else
  say_fail "stub-mode happy path: rc=$rc; substitution did not fire"
fi

# Hermetic failure injection.
cp "$REPO_ROOT/wiki/overrides/partials/comments.html" "$TMPDIR_F/wiki/overrides/partials/comments.html"
M032_GISCUS_IDS_FROM_GH_STUB=fail bash "$WI" \
  --with-giscus --repo fixture-owner/m032-p03-tmp --category 'Wiki Comments' \
  --project-dir "$TMPDIR_F" 2>/dev/null
rc=$?
if [ "$rc" -ne 0 ] && grep -qF '{{giscus_repo}}' "$TMPDIR_F/wiki/overrides/partials/comments.html"; then
  say_pass "stub-mode fail injection: rc=$rc, partial preserved in placeholder state"
else
  say_fail "stub-mode fail injection: rc=$rc; partial not preserved"
fi

printf 'SUMMARY: m032-p03-with-giscus-scope pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

7. **Author `tools/verify/m032-p03-acceptance-shape-sc4.sh`** (acceptance-shape verifier). Single-script-file shape; asserts the SC-4 acceptance script exists, is executable, and contains the load-bearing tokens that prove it exercises all six SC-4 branches (precondition default-scope, FR-7 placeholder-presence, FR-8 happy-path, post-step verifier, failure injection, re-run idempotency, overwrite). Required content sketch:

```bash
#!/usr/bin/env bash
# tools/verify/m032-p03-acceptance-shape-sc4.sh
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ACC="$REPO_ROOT/tests/m032-acceptance/p02-wiki-init-with-giscus.sh"
pass=0; fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

[ -x "$ACC" ] || { say_fail "$ACC absent or non-executable"; printf 'SUMMARY: m032-p03-acceptance-shape-sc4 pass=%d fail=%d\n' "$pass" "$fail"; exit 1; }

for tok in 'SC-4' 'FR-7' 'FR-8' 'M032_GISCUS_IDS_FROM_GH_STUB=1' 'M032_GISCUS_IDS_FROM_GH_STUB=fail' \
           'fixture-owner/fixture-repo' 'R_kgDOFixture' 'wiki-giscus-config-check.sh' \
           'integration-giscus-config-failed' '{{giscus_repo}}' 'fixture-owner-2'; do
  if grep -qF "$tok" "$ACC"; then
    say_pass "SC-4 contains: $tok"
  else
    say_fail "SC-4 missing: $tok"
  fi
done

printf 'SUMMARY: m032-p03-acceptance-shape-sc4 pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

8. **Make all three new verifier scripts executable**: `chmod +x tools/verify/m032-p03-giscus-templating.sh tools/verify/m032-p03-with-giscus-scope.sh tools/verify/m032-p03-acceptance-shape-sc4.sh`.

## Must-Haves

- FR-7 partial templating (the four `{{giscus_*}}` placeholder tokens interleaved with the existing Jinja interpolations in `wiki/overrides/partials/comments.html`)
- FR-8 `--with-giscus` scope on `wiki-init.sh` (helper invocation, parse, sed-substitute, post-step verifier, exit-code mapping including `M032_GISCUS_IDS_FROM_GH_STUB=1|fail` envelope)
- SC-4 acceptance script (`tests/m032-acceptance/p02-wiki-init-with-giscus.sh`)
- Three project-owned verifiers: `tools/verify/m032-p03-giscus-templating.sh`, `tools/verify/m032-p03-with-giscus-scope.sh`, `tools/verify/m032-p03-acceptance-shape-sc4.sh`

## Verification

```bash
bash tools/verify/m032-p03-giscus-templating.sh
```

```bash
bash tools/verify/m032-p03-with-giscus-scope.sh
```

```bash
bash tools/verify/m032-p03-acceptance-shape-sc4.sh
```

```bash
bash tests/m032-acceptance/p02-wiki-init-with-giscus.sh
```

## Notes

Expected output of each verifier: the final line is `SUMMARY: <name> pass=<N> fail=0` and exit code is 0. The SC-4 acceptance script's final line is `SUMMARY: SC-4 acceptance pass=6 fail=0` and exit code is 0 (six branches: FR-7 placeholder presence, happy path, post-step verifier, failure injection, re-run idempotency, overwrite branch).

Coexistence-model gotcha: in the bundle-staged surface, the literal `{{giscus_repo}}` token sits IMMEDIATELY before `{{ config.extra.giscus.repo }}` with no separator (`data-repo="{{giscus_repo}}{{ config.extra.giscus.repo }}"`). The sed-substitution pattern `{{giscus_repo}}` is unique enough that it will not accidentally match the Jinja form (Jinja's form has spaces inside the braces and a dotted path). Verify this empirically with the SC-4 acceptance test's branch 1 assertion (`! grep -qF '{{giscus_repo}}' "$PARTIAL"` after substitution AND `grep -qF '{{ config.extra.giscus.repo }}' "$PARTIAL"` should still pass — the Jinja interpolation is NOT touched by the sed pass).

The dual-template approach is intentional: it gives consumers two equally valid Giscus-config paths (M032 placeholder-substitution at install time OR mkdocs `extra.giscus.*` `!ENV` at build time) without forcing a choice. Documentation lives in the `{# ... #}` comment block in step 1 and in `commands/wiki-init.md`'s `--with-giscus` section.

## Inputs

### From Previous Tasks

(none — T01 is independent of T02–T04 within P03; depends only on P02 artifacts)

### From Disk (Pre-existing)

- `scripts/lifecycle/wiki-init.sh` (P02/T01) — bash 3.2 default-scope script. T01 amends it to add `--with-giscus` handling. Read `scripts/lifecycle/wiki-init.sh:69-73` for the existing reject-stub block to replace.
- `wiki/overrides/partials/comments.html` (M012/P03/T01 baseline) — current Jinja-interpolation-based Giscus partial. T01 amends lines 25-28 to add the four `{{giscus_*}}` placeholder tokens alongside the existing Jinja interpolations.
- `scripts/diagnostics/giscus-ids-from-gh.sh` (M012/P02 baseline) — `--repo`/`--category` GraphQL helper. Read `scripts/diagnostics/giscus-ids-from-gh.sh:149-152` for the four `export GISCUS_*` output line shape.
- `scripts/diagnostics/wiki-giscus-config-check.sh` ([M012](../../../../../milestones/M012/index.md) baseline) — post-step verifier. T01 invokes it via `bash <path> --project-dir <dir> --quiet`.
- `tests/fixtures/m032-fresh-project-fixture/` (P01) — shared fixture used by the SC-4 acceptance script.

## Constraints

- Single-script-file shape for ALL verifier `Check:` commands per AD-19.
- bash 3.2 compatibility (per MEM001) — no `declare -A`, no process substitution, no command substitution containing pipes (use `sed -n`/`grep -F` chains, not `wc -l < <(...)`-style constructs).
- Verifier scripts MUST live under `tools/verify/` with the `m032-p03-*` prefix per AD-19 path discipline.
- No modifications to `commands/init.md`, `scripts/lifecycle/init-project.sh`, `packaging/bundle/manifest.yml`, `wiki/glossary.md`, or `scripts/wiki/wiki-scan-sources.sh` — those are P02-owned (scope-guard enforcement).
- Co-author the three verifier scripts within T01 — do NOT defer them to T05 per plan-time discipline rule 2 (verifier-availability cross-check). T05 only authors the phase-suite + scope-guard.
- The `M032_GISCUS_IDS_FROM_GH_STUB` env-var shape follows the M026/MEM030 `<TOOL>_*` env-var convention — operator-facing surface MUST NOT honor this var unset path implicitly; it is test-only.

## Expected Output

After T01 completes:

- `wiki/overrides/partials/comments.html` carries the four `{{giscus_*}}` placeholder tokens AND the existing Jinja interpolations (FR-7 dual-template surface).
- `scripts/lifecycle/wiki-init.sh` recognizes `--with-giscus --repo <owner>/<repo> --category <name>` and implements the four-step workflow.
- `tests/m032-acceptance/p02-wiki-init-with-giscus.sh` exists and exits 0 (SC-4 PASS).
- `tools/verify/m032-p03-giscus-templating.sh`, `tools/verify/m032-p03-with-giscus-scope.sh`, `tools/verify/m032-p03-acceptance-shape-sc4.sh` exist and exit 0.
- The four `Check:` commands listed in P03-PLAN.md's "Truths" section for T01-owned truths return exit 0.

## State Context

- **Current State**: executing
- **Milestone**: M032
- **Phase**: P03
- **Task**: T01-with-giscus-scope
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- Single-script-file shape for ALL verifier `Check:` commands per AD-19.
- bash 3.2 compatibility (per MEM001) — no `declare -A`, no process substitution, no command substitution containing pipes (use `sed -n`/`grep -F` chains, not `wc -l < <(...)`-style constructs).
- Verifier scripts MUST live under `tools/verify/` with the `m032-p03-*` prefix per AD-19 path discipline.
- No modifications to `commands/init.md`, `scripts/lifecycle/init-project.sh`, `packaging/bundle/manifest.yml`, `wiki/glossary.md`, or `scripts/wiki/wiki-scan-sources.sh` — those are P02-owned (scope-guard enforcement).
- Co-author the three verifier scripts within T01 — do NOT defer them to T05 per plan-time discipline rule 2 (verifier-availability cross-check). T05 only authors the phase-suite + scope-guard.
- The `M032_GISCUS_IDS_FROM_GH_STUB` env-var shape follows the M026/MEM030 `<TOOL>_*` env-var convention — operator-facing surface MUST NOT honor this var unset path implicitly; it is test-only.

### Acceptance Criteria

- FR-7 partial templating (the four `{{giscus_*}}` placeholder tokens interleaved with the existing Jinja interpolations in `wiki/overrides/partials/comments.html`)
- FR-8 `--with-giscus` scope on `wiki-init.sh` (helper invocation, parse, sed-substitute, post-step verifier, exit-code mapping including `M032_GISCUS_IDS_FROM_GH_STUB=1|fail` envelope)
- SC-4 acceptance script (`tests/m032-acceptance/p02-wiki-init-with-giscus.sh`)
- Three project-owned verifiers: `tools/verify/m032-p03-giscus-templating.sh`, `tools/verify/m032-p03-with-giscus-scope.sh`, `tools/verify/m032-p03-acceptance-shape-sc4.sh`

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