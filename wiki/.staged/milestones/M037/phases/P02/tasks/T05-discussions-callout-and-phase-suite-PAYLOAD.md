---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T05-discussions-callout-and-phase-suite (Phase P02, Milestone M037)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~800 | required |
| Upstream Context | 981-1081 | ~4700 | required |
| Task Plan | 1083-1346 | ~3600 | required |
| State Context | 1348-1354 | ~100 | required |
| First-Turn Completeness | 1356-1401 | ~800 | required |
| **Total** | | **~20800** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 849
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
hit_count: 849
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
hit_count: 849
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
hit_count: 849
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
hit_count: 740
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
hit_count: 740
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
hit_count: 740
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
hit_count: 849
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
hit_count: 740
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
hit_count: 740
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
hit_count: 740
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
hit_count: 849
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
hit_count: 849
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
hit_count: 849
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
hit_count: 740
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
hit_count: 740
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
hit_count: 740
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
hit_count: 849
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
hit_count: 740
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
hit_count: 740
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
hit_count: 849
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
hit_count: 849
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
hit_count: 740
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
hit_count: 740
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
hit_count: 740
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
hit_count: 395
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
hit_count: 395
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
hit_count: 395
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
hit_count: 425
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
hit_count: 425
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
hit_count: 415
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

### Truths

- T1 — `scripts/wiki/wiki-generate-stubs.sh` carries a new `feedback:<basename>` routing arm mirroring the existing `proposals:*` arm; stubs land at `wiki/docs/feedback/<basename>.md` with fragment-only passthrough; title derives from H1 with humanized-basename fallback. (FR-18, US-10)
  - Check: `bash tools/verify/m037-p02-feedback-routing.sh`
- T2 — `scripts/wiki/wiki-scan-sources.sh` emits `feedback:<basename>` records for every `.orchestrator/feedback/*.md` source file (parallel to the proposals enumeration block at lines 322-337). (FR-18)
  - Check: `bash tools/verify/m037-p02-feedback-routing.sh`
- T3 — Operator-edited feedback stubs declaring `auto_generated: false` survive byte-identical across re-runs (MIT-01/02 escape-hatch pattern reused from P01/T02 — `existing_stub_is_protected()` helper consumed, NOT forked). (FR-18, MIT-01/02 inheritance)
  - Check: `bash tools/verify/m037-p02-feedback-routing.sh`
- T4 — `scripts/lifecycle/wiki-init.sh` emits `.github/workflows/pages.yml` carrying the four-component verbatim shape (`actions/configure-pages@v5` + `actions/upload-pages-artifact@v3` + `actions/deploy-pages@v4`, two-job build+deploy topology, Python 3.12 + pip-cache on `wiki/requirements.txt`, `concurrency: pages cancel-in-progress: false`, `permissions: contents:read pages:write id-token:write`, `push: branches: [main]` + `workflow_dispatch` triggers). (FR-19, US-11)
  - Check: `bash tools/verify/m037-p02-workflow-pages-publishing.sh`
- T5 — `scripts/lifecycle/wiki-init.sh` invokes `gh api -X PUT "repos/$OWNER/$REPO/pages" -f build_type=workflow` with manual-fallback diagnostic on `gh` unavailable / unauthenticated (verbatim command surfaced in the diagnostic so the operator can run it manually). (FR-19)
  - Check: `bash tools/verify/m037-p02-workflow-pages-publishing.sh`
- T6 — Pre-existing `.github/workflows/pages.yml` is NOT clobbered by `wiki-init.sh`; CON-3 preservation honored via diagnostic-only emit (no per-key merge). (FR-19, CON-3)
  - Check: `bash tools/verify/m037-p02-workflow-pages-publishing.sh`
- T7 — `scripts/wiki/wiki-deploy.sh` keeps gates 1-4 (giscus-config-check + mkdocs build + link-check + giscus-smoke) and drops gate 5 (`mkdocs gh-deploy --force`). The script prints `OK: pre-deploy gates PASS. Push to main to trigger workflow deploy:` followed by `git push origin main` and the workflow URL, then exits 0. No `mkdocs gh-deploy` invocation remains on the live path. (FR-20, US-11)
  - Check: `bash tools/verify/m037-p02-workflow-pages-publishing.sh`
- T8 — `wiki/README.md` "Running the deploy wrapper" + "First-deploy checklist" sections updated: no remaining `bash scripts/wiki/wiki-deploy.sh` invocation as the live-deploy primitive; replaced with `git push origin main` + workflow URL pattern. M032-shipped quickstart docs reflect the new flow (cross-milestone touch owned by M037). (FR-20 done-definition, cross-milestone)
  - Check: `bash tools/verify/m037-p02-workflow-pages-publishing.sh`

<dispatch-volatile>

## Upstream Context


### P01 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M037"
milestone: "M037"
provides:
  - "templates/wiki-index-cards.md.tmpl + wiki.landing_cards: schema in templates/orchestrator-config-default.yml + render_landing_cards in scripts/wiki/wiki-generate-stubs.sh + wiki/docs/index.md grid-cards block (FR-1/FR-2/FR-3/FR-4),wiki-generate-stubs.sh derive_stub_title() reading version: from frontmatter + write_stub projecting to title: + wiki-generate-nav.sh emit_leaf_prefer_stub_title() + auto_generated: false escape hatch (FR-5/FR-6/MIT-01/MIT-02),[.orchestrator/DECISIONS.md](../../../../../decisions.md) restructured from 7-column markdown table (28 D### rows) to 28 ### Title { #dr-code-NNN } heading entries with attr_list anchors + body chips + framework-owned shape-lint at scripts/verify/decisions-shape-lint.sh + tools/verify/m037-p01-decisions-shape.sh wrapper (FR-7),references/authoring-conventions.md (278 lines) covering DR/BG/AN/MEM/Q-### code conventions + already-enabled mkdocs-material features (Mermaid, pymdownx.details, navigation.prune, content tabs, attr_list status chips) + commands/dispatch.md ## Payload Guidance section referencing it + wiki/docs/stylesheets/code-chips.css plug-in-free pill styling + extra_css: declaration in wiki/mkdocs.yml (FR-8 + theme-leverage),scripts/wiki/resolve-default-branch.sh CON-4 helper + wiki/mkdocs.yml polish bundle (theme.features navigation.tabs/sticky/prune + content.action.edit/view, toc_depth: 2, markdown_extensions pymdownx.details + pymdownx.tasklist with custom_checkbox: true, top-level edit_uri: derived from repo_url:) + scripts/lifecycle/wiki-init.sh fifth-field substitution for edit_uri: (FR-9 + CON-4),scripts/lib/yaml-merge.sh shared YAML-merge primitive (sed/awk only, fail-closed on malformed YAML) + 3-installer cfg_target write block migration (install-claude-code.sh / install-codex.sh / install-cursor.sh) + wiki-init.sh post-sed yaml-merge invocation for mkdocs.yml refresh + tests/m037-acceptance/run-acceptance-battery.sh aggregator (BATTERY: pass=N skip=M fail=K) + tests/fixtures/m037-config-merge/ corpus + Truth #6/#7 verifiers (FR-10/FR-11/CON-3/MIT-03/MIT-03 P0),tools/verify/m037-p01-phase-suite.sh straight-line aggregator (9 gates, OK at 9/9 PASS)"
requires:
  - "none"
affects:
  - "M037 P02 — round 3.5 polish (F1.2 tag-driven nav subgrouping + F2 GitHub source-link + F5 knowledge card grid + 3 plugins). Demand-driven; ships after first PBJ feedback signal lands."
  - "[M035](../../../../../milestones/M035/index.md) P02–P06 — packaging & distribution. P01's yaml-merge primitive becomes the canonical install-template refresh path; M035 must address packaging/bundle/config/orchestrator.default.yml stub divergence (see paper-cut)."
key_files:
  - "templates/wiki-index-cards.md.tmpl,templates/orchestrator-config-default.yml,scripts/wiki/wiki-generate-stubs.sh,scripts/wiki/wiki-generate-nav.sh,scripts/wiki/resolve-default-branch.sh,wiki/docs/index.md,wiki/docs/stylesheets/code-chips.css,wiki/mkdocs.yml,[.orchestrator/DECISIONS.md](../../../../../decisions.md),references/authoring-conventions.md,commands/dispatch.md,scripts/verify/decisions-shape-lint.sh,scripts/lib/yaml-merge.sh,scripts/lifecycle/wiki-init.sh,packaging/install/install-claude-code.sh,packaging/install/install-codex.sh,packaging/install/install-cursor.sh,tests/m037-acceptance/run-acceptance-battery.sh,tests/m037-acceptance/p01-card-grid-homepage.sh,tests/m037-acceptance/p01-version-to-nav-title.sh,tests/m037-acceptance/p01-dr-heading-shape.sh,tests/m037-acceptance/p01-mkdocs-polish-bundle.sh,tests/m037-acceptance/p01-config-clobber-fix.sh,tests/fixtures/m037-config-merge/,tools/verify/m037-p01-card-grid.sh,tools/verify/m037-p01-version-to-title.sh,tools/verify/m037-p01-auto-generated-escape-hatch.sh,tools/verify/m037-p01-decisions-shape.sh,tools/verify/m037-p01-authoring-conventions-doc.sh,tools/verify/m037-p01-dispatch-references-conventions.sh,tools/verify/m037-p01-mkdocs-polish-bundle.sh,tools/verify/m037-p01-config-clobber-fix.sh,tools/verify/m037-p01-malformed-yaml-fail-closed.sh,tools/verify/m037-p01-phase-suite.sh"
key_decisions:
  - "FR-1,FR-2,FR-3,FR-4,FR-5,FR-6,FR-7,FR-8,FR-9,FR-10,FR-11,MIT-01,MIT-02,MIT-03,CON-1,CON-3,CON-4,AD-19,DISP-1,Q-3,Q-4,Q-7,Surface-E-Option-B,SC-1,SC-2,SC-3,SC-4,SC-5"
patterns_established:
  - "Body-chip pattern for code-anchored entries: `<span class=\"md-tag md-tag-icon md-tag--<class>\">CODE</span>` with `{: .code-chip-row }` attr_list + plugin-free CSS at wiki/docs/stylesheets/code-chips.css; reusable across DR/BG/AN/MEM/Q-### prefixes; framework-owned shape-lint at scripts/verify/decisions-shape-lint.sh enforces heading regex + anchor uniqueness + zero-legacy-row invariant,Sentinel-bracketed mkdocs.yml additions: # >>> M0##-P##-T## <key> ... # <<< M0##-P##-T## end pattern (mirrors existing M012-P03 Giscus convention) — survives yaml-merge round-trip via per-top-level-key replacement under managed namespaces,Line-oriented YAML-merge primitive (bash 3.2 + POSIX sh + sed/awk only, NO yq/python): top-level keys detected via ^[a-zA-Z_][a-zA-Z0-9_-]*: regex; per-key dispatch on managed-vs-operator classification; sub-key-aware merge for managed namespaces with sub-keys (preserves operator content byte-identical, adds new framework sub-keys); fail-closed on YAML parse error (exit 4 + diagnostic + no write); reusable across config.yml + mkdocs.yml + future YAML targets,CON-4 fail-back-to-main default-branch helper: scripts/wiki/resolve-default-branch.sh always exits 0 with a usable branch name (real or 'main' fallback) — downstream consumers can rely on non-empty stdout. Reusable by P02's FR-13 GitHub source-link rewrite,Synthetic-git-remote test fixture: mktemp -d + git init + git remote add origin <fake-url> + manual git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main — resolves CON-4 helper without network access. Reusable for any acceptance test exercising remote-aware paths,Phase-suite aggregator with straight-line invocation per AD-19 — no loops, no compound chains; 9 gates × 'bash <verifier>' + accumulator; emits canonical SUMMARY: pass=N fail=M line; mirrors m029-p01-phase-suite.sh shape"
drill_down_paths:
  - "[.orchestrator/milestones/M037/phases/P01/tasks/T01-card-grid-surface-PLAN.md](../../../../../milestones/M037/phases/P01/tasks/T01-card-grid-surface-PLAN.md) (no SUMMARY — committed pre-orchestrator-loop), [.orchestrator/milestones/M037/phases/P01/tasks/T02-version-to-title-projection-SUMMARY.md](../../../../../milestones/M037/phases/P01/tasks/T02-version-to-title-projection-SUMMARY.md), [.orchestrator/milestones/M037/phases/P01/tasks/T03-decisions-shape-pivot-SUMMARY.md](../../../../../milestones/M037/phases/P01/tasks/T03-decisions-shape-pivot-SUMMARY.md), [.orchestrator/milestones/M037/phases/P01/tasks/T04-authoring-conventions-doc-SUMMARY.md](../../../../../milestones/M037/phases/P01/tasks/T04-authoring-conventions-doc-SUMMARY.md), [.orchestrator/milestones/M037/phases/P01/tasks/T05-mkdocs-polish-bundle-SUMMARY.md](../../../../../milestones/M037/phases/P01/tasks/T05-mkdocs-polish-bundle-SUMMARY.md), [.orchestrator/milestones/M037/phases/P01/tasks/T06-yaml-merge-and-install-emission-SUMMARY.md](../../../../../milestones/M037/phases/P01/tasks/T06-yaml-merge-and-install-emission-SUMMARY.md)"
duration: "≈ 4h (T03-T06 wall-clock; T01/T02 pre-orchestrator-loop)"
verification_result: "pass"
completed_at: "2026-05-06T20:30:00Z"
observability_surfaces:
  - "tests/m037-acceptance/run-acceptance-battery.sh (BATTERY: pass=5 skip=0 fail=0)"
  - "tools/verify/m037-p01-phase-suite.sh (SUMMARY: pass=9 fail=0)"
---

## What Shipped

P01 ships the **wiki team-feedback-ready ship-it minimum** for M037 — six task tranches landing the seven Truths the M037 brief named load-bearing for opening the wiki to the PBJ-central team this week. Goal verbatim from the phase plan: "A non-author reader (PBJ domain SME) opens an orchestrator-managed wiki and lands on a card-grid homepage, scans a reference nav of human-readable strings (not slug-soup), reads a decisions TOC of human concepts (not codes), sees top-level sections in a sticky tab header with a 2-level TOC and an edit-this-page affordance, and the operator's `wiki:` block in `.orchestrator/config.yml` survives `orchestrator:update` byte-identical."

The six task tranches:

1. **T01 — Card-grid surface end-to-end (FR-1/2/3/4, commit `deef3e96`)**: ships `templates/wiki-index-cards.md.tmpl`, the `wiki.landing_cards:` schema entry in `templates/orchestrator-config-default.yml`, the `render_landing_cards` function in `scripts/wiki/wiki-generate-stubs.sh`, and the rendered grid-cards block in `wiki/docs/index.md`.

2. **T02 — `version:` → `title:` projection + auto_generated escape hatch (FR-5/6 + MIT-01/02, commit `8f77d453`)**: ships `derive_stub_title()` and `existing_stub_is_protected()` helpers in `scripts/wiki/wiki-generate-stubs.sh`, `emit_leaf_prefer_stub_title()` in `scripts/wiki/wiki-generate-nav.sh`. Operator-edited stubs declaring `auto_generated: false` survive byte-identical across re-runs.

3. **T03 — DECISIONS.md heading-shape pivot + framework-owned shape-lint (FR-7, commit `e3b8696c`)**: restructures [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) from a 7-column markdown table (28 `| Dnnn |` rows, D001–D028) into 28 `### Title { #dr-code-NNN }` heading entries with `attr_list` anchors and body chips. Framework-owned `scripts/verify/decisions-shape-lint.sh` enforces the heading-shape regex + anchor uniqueness + zero-legacy-row invariant. One inbound permalink rewrite landed (`specs/022-spec-wiki/spec.md` `#d009` → `#dr-code-009`); below the 50-ref blast-radius surface threshold.

4. **T04 — Authoring conventions doc + dispatch payload-guidance + Surface E code-chip CSS (FR-8 + theme-leverage, commit `2031a9af`)**: ships `references/authoring-conventions.md` (278 lines) covering (a) DR/BG/AN/MEM/Q-### code conventions with the new heading-shape and body-chip pattern (verbatim D003 before/after exemplar), and (b) already-enabled mkdocs-material features authors should leverage (Mermaid, content reuse, admonitions, attr_list status chips, content tabs, plus T05's incoming pymdownx.details + pymdownx.tasklist + navigation.prune polish-bundle additions). `commands/dispatch.md` gains a `## Payload Guidance` section referencing the doc. **T03 Surface E follow-up folded in (Option B)**: `wiki/docs/stylesheets/code-chips.css` (~33 lines, plugin-free pill styling for code chips) + `extra_css:` declaration in `wiki/mkdocs.yml`. Plugin-free per CON-1; reversible if a future milestone adopts Material's `tags:` plugin.

5. **T05 — CON-4 default-branch helper + mkdocs.yml polish bundle (FR-9 + CON-4, commit `a4ea4cd6`)**: ships `scripts/wiki/resolve-default-branch.sh` (CON-4 helper, falls back to `main` on any failure mode, always exits 0). `wiki/mkdocs.yml` gains nine polish-bundle additions: `theme.features` adds `navigation.tabs` / `navigation.tabs.sticky` / `navigation.prune` (top of list) + `content.action.edit` / `content.action.view` (bottom); `markdown_extensions` modifies the `toc:` block to add `toc_depth: 2` and appends `pymdownx.details` + `pymdownx.tasklist:` (with `custom_checkbox: true`); a top-level `edit_uri:` is derived from `repo_url:` at template-emit time. `scripts/lifecycle/wiki-init.sh` extends the four-field substitution block to a fifth field (`edit_uri:`); US-4 AS-4 edge case (operator unset `repo_url:`) skips `edit_uri:` injection with a diagnostic. `pymdownx.details` and `pymdownx.tasklist` are built into the existing `pymdown-extensions` package — no `wiki/requirements.txt` change required (CON-1).

6. **T06 — Shared YAML-merge primitive + 3-installer config emission + acceptance battery scaffold + Truth #6/#7 (FR-10/11 + CON-3 + MIT-03 P0, commit `702c8dbf`)**: ships `scripts/lib/yaml-merge.sh` (shared YAML-merge primitive — bash 3.2 + POSIX sh + sed/awk only, NO `yq`/`python`; subcommand interface `merge --target <file> --framework-default <file> --managed-namespaces <comma-list> [--dry-run]`; per-top-level-key dispatch on managed-vs-operator classification; sub-key-aware merge for managed namespaces with sub-keys; fail-closed on YAML parse error with exit 4). All three installers (`install-claude-code.sh`, `install-codex.sh`, `install-cursor.sh`) replace their pre-M037 "skip if exists / overwrite with --force" `cfg_target` write block with a `yaml-merge.sh merge` invocation. `wiki-init.sh` invokes `yaml-merge.sh` against the staged `mkdocs.yml` after the field-line rewrite to preserve operator-authored top-level keys. `tests/m037-acceptance/run-acceptance-battery.sh` aggregates SC-1..SC-5; expected output `BATTERY: pass=5 skip=0 fail=0` after T01..T06 land. `tests/fixtures/m037-config-merge/` corpus exercises operator-authored key preservation (`pbj_team_dashboard_url:` + 3-entry `wiki.landing_cards:`). Truth #6 + Truth #7 verifiers + SC-5 acceptance test all green.

## Verification Results

`tools/verify/m037-p01-phase-suite.sh`: **PASS — 9/9 gates green**:

```
OK: m037-p01-card-grid.sh
OK: m037-p01-version-to-title.sh
OK: m037-p01-auto-generated-escape-hatch.sh
OK: m037-p01-decisions-shape.sh
OK: m037-p01-authoring-conventions-doc.sh
OK: m037-p01-dispatch-references-conventions.sh
OK: m037-p01-mkdocs-polish-bundle.sh
OK: m037-p01-config-clobber-fix.sh
OK: m037-p01-malformed-yaml-fail-closed.sh
SUMMARY: m037-p01-phase-suite.sh pass=9 fail=0
```

`tests/m037-acceptance/run-acceptance-battery.sh`: **BATTERY: pass=5 skip=0 fail=0** (SC-1..SC-5 covered in P01; SC-6..SC-12 ride P02 + milestone close).

## Key Decisions

- **Surface E Option B (T04 fold-in, plugin-free CSS)**: `wiki/docs/stylesheets/code-chips.css` + `extra_css:` declaration over Material's `tags:` plugin (Option A) or deferral (Option C). Rationale: plugin-free preserves CON-1; doesn't entangle with T05's in-flight `markdown_extensions:` polish bundle; reversible if a future milestone adopts the `tags:` plugin (chip classes pick up Material's built-in pill styling automatically).
- **`extra_css` namespace classification (T06 executor-time addendum)**: classified as orchestrator-managed in T06's `wiki-init.sh` MKDOCS_MANAGED list. T04 added the namespace AFTER T06's plan was authored, so the plan's mkdocs.yml managed-namespace table didn't list it. Sub-key-aware merge preserves any operator-authored extra `- stylesheets/*.css` entries while ensuring the framework-supplied `- stylesheets/code-chips.css` always renders.
- **Plan §33 vs §145 yaml-merge semantics resolution (T06)**: managed namespaces with sub-keys use sub-key-aware merge (preserves operator content byte-identical, adds new framework sub-keys); managed flat scalars/lists use framework-wins. Resolves SC-5 verifier requirement: operator's 3-entry `wiki.landing_cards:` survives byte-identical AND framework can introduce `wiki.nav_buckets:` on schema evolution.
- **DISP-1 PBJ-central cross-reference deferred**: PBJ-central's `.orchestrator/config.yml` not accessible from the executor at dispatch time. Per plan §143-147 fallback, the 15-key cross-reference table in T06's plan is the authoritative classification. Fail-closed design (operator-only keys preserved byte-identical at original relative position) makes silent re-classification structurally impossible.

## Patterns Established

- **Body-chip pattern for code-anchored entries**: `<span class="md-tag md-tag-icon md-tag--<class>">CODE</span>` with `{: .code-chip-row }` attr_list, plugin-free CSS at `wiki/docs/stylesheets/code-chips.css`. Reusable across DR/BG/AN/MEM/Q-### prefixes; framework-owned shape-lint enforces heading regex + anchor uniqueness + zero-legacy-row invariant.
- **Sentinel-bracketed mkdocs.yml additions**: `# >>> M0##-P##-T## <key> ... # <<< M0##-P##-T## end` (mirrors existing M012-P03 Giscus convention). Survives yaml-merge round-trip via per-top-level-key replacement under managed namespaces.
- **Line-oriented YAML-merge primitive** (bash 3.2 + POSIX sh + sed/awk only, NO `yq`/`python`): per-top-level-key dispatch on managed-vs-operator classification; sub-key-aware merge for managed namespaces with sub-keys; fail-closed on YAML parse error. Reusable across `config.yml` + `mkdocs.yml` + future YAML targets.
- **CON-4 fail-back-to-`main` default-branch helper**: `scripts/wiki/resolve-default-branch.sh` always exits 0 with a usable branch name. Downstream consumers rely on non-empty stdout; reusable by P02's FR-13 GitHub source-link rewrite.
- **Synthetic-git-remote test fixture**: `mktemp -d` + `git init` + `git remote add origin <fake-url>` + manual `git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main`. Resolves CON-4 helper without network access; reusable for any acceptance test exercising remote-aware paths.
- **Phase-suite aggregator with straight-line invocation per AD-19**: 9 gates × `bash <verifier>` + accumulator; emits canonical `SUMMARY: pass=N fail=M` line; mirrors `m029-p01-phase-suite.sh` shape.

## Affects Downstream

- **M037 P02 (round 3.5 polish, demand-driven)** — consumes T01's `wiki.landing_cards:` schema for F5 knowledge card grid, T03's heading-shape exemplar for F1.2 tag-driven nav subgrouping conventions, T05's CON-4 default-branch helper for F2 GitHub source-link rewrite, and T06's yaml-merge primitive for any P02 schema additions. Ships after first PBJ feedback signal lands.
- **M035 P02–P06 (packaging & distribution, blocked by P02)** — consumes T06's yaml-merge primitive as the canonical install-template refresh path. **Blocking finding**: `packaging/bundle/config/orchestrator.default.yml` is a 12-line stub, not a copy/symlink of the canonical 175-line `templates/orchestrator-config-default.yml`. T01's `wiki: landing_cards: []` schema does not reach consumer projects via the install bundle today. Captured as paper-cut at [`.orchestrator/proposals/papercut-bundle-config-stub-divergence.md`](../../../../../proposals/papercut-bundle-config-stub-divergence.md); M035 must address before launch.

## Deferred / Out-of-Scope

- **`tools/verify/m037-p01-scope-guard.sh`** — listed in plan's "Files Likely Touched" surface (line 133) but not built. Scope-guard requires a baseline-ref capture and is mostly forward-looking (catches future drift). Verification surface is fully covered by the 9-gate phase-suite + 5-test acceptance battery for P01 close. Can be added pre-M035 if desired; not blocking PBJ-team ship.
- **`tools/verify/m037-p01-phase-suite-scope-guard.sh`** combined check — same rationale; deferred.

## Pre-Existing Drift Notes

- **`wiki/docs/**` auto-nav drift** — predates this session. Includes regenerated stubs for M032/M033/[M029](../../../../../milestones/M029/index.md) milestones, new `proposals/` nav block, [M032](../../../../../milestones/M032/index.md) acceptance evidence stubs. Untouched by P01 task work; will be picked up by the next `wiki-generate-nav.sh` run. Recommend a separate "wiki regen sync" commit before PBJ-team ship so the dogfood wiki reflects current state.
- **`packaging/bundle/config/orchestrator.default.yml` 12-line stub vs canonical 175-line template** — see paper-cut at [`.orchestrator/proposals/papercut-bundle-config-stub-divergence.md`](../../../../../proposals/papercut-bundle-config-stub-divergence.md). Pre-existing condition, surfaced by T06's path-resolution check; documented for M035 pre-launch.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P02"
milestone: "M037"
name: "Discussions-redirect README callout + acceptance battery extension + phase-suite aggregator"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

- T01..T04 have shipped (verifiers exist on disk: `tools/verify/m037-p02-feedback-routing.sh`, `tools/verify/m037-p02-workflow-pages-publishing.sh`, `tools/verify/m037-p02-private-site-url.sh`, `tools/verify/m037-p02-out-of-scope-collapse.sh`). T05's phase-suite aggregator references them; if any is missing, T05's verifier-availability cross-check fails.
- T02 has updated `wiki/README.md` "First-deploy checklist" + "Running the deploy wrapper" sections (the cross-milestone docs update). T05 adds a callout on top of T02's restructured layout.
- `tests/m037-acceptance/run-acceptance-battery.sh` exists (verified at plan-authoring time, P01/T06 deliverable; iterates `tests/m037-acceptance/p01-*.sh` and emits `BATTERY: pass=N skip=M fail=K`).
- `tools/verify/m037-p01-phase-suite.sh` exists (verified at plan-authoring time, P01/T06 deliverable; AD-19 straight-line aggregator shape — used as the structural template for T05's m037-p02-phase-suite.sh).

## Description

Lands FR-22b per US-14 and SC-17, plus the phase-close gate aggregator and acceptance battery extension. Three deliverables ship together because they are small and share the "phase-close hygiene" theme:

1. **FR-22b README callout** — `wiki/README.md` § "First-deploy checklist" gains an org-level-discussions-redirect callout naming both the symptom (`<Org>/<Repo>/discussions` 302s to `orgs/<Org>/discussions`) AND the recovery path (`<Org>/<Repo>/discussions/categories` direct URL). PBJ-central operator hit this dead-end on 2026-05-07. Source: `papercut-sweep-wiki-deploy-2026-05-07.md` finding #7.

2. **Acceptance battery extension** — `tests/m037-acceptance/run-acceptance-battery.sh` extended to invoke the two top-level handoff-doc scaffolds (`tests/test-wiki-init-workflow-mode.sh`, `tests/test-wiki-init-private-site-url.sh`) IN ADDITION to the existing `p01-*.sh` glob. Target: `BATTERY: pass=10 skip=0 fail=0` (5 P01 + 3 new p01-*.sh + 2 top-level scaffolds = 10).

3. **Phase-suite aggregator** — `tools/verify/m037-p02-phase-suite.sh` straight-line aggregator per AD-19. Aggregates the five P02 verifiers (T01-T05 minus T05's own verifier — T05's verifier IS the phase-suite aggregator itself + a sibling discussions-callout verifier).

## Steps

1. **Author `tools/verify/m037-p02-discussions-callout.sh`**:
   - Greps `wiki/README.md` for: `discussions/categories` (the recovery URL pattern) AND a literal mention of the symptom (e.g., `302` or `redirect` near the callout).
   - Greps `wiki/README.md` for the literal string `First-deploy checklist` (the callout MUST land in that section).
   - Asserts the section preserves byte-identically the pre-existing checklist items by checking for: `Install the giscus GitHub App` (step 1 anchor), `wiki-init --with-giscus` (step 2 anchor), `Smoke-test the deployed URL` (step 4-or-similar anchor).
   - Emits `SUMMARY: m037-p02-discussions-callout pass=N fail=M` on completion.

2. **Add the callout to `wiki/README.md`**. Insert AFTER step 1 (giscus app install, line 294-302) and BEFORE step 2 (wiki-init --with-giscus run, line 304+), or at a position chosen at execute time that flows naturally with the post-T02 restructure. Recommended shape:

   ```markdown
   > **Org-level redirect quirk**: if your GitHub org has org-level
   > Discussions enabled, `https://github.com/<Org>/<Repo>/discussions`
   > may 302-redirect to the org-level page (`https://github.com/orgs/<Org>/discussions`).
   > The repo's discussions still work via API and giscus, but the
   > "create category" UI lives at the org level until you navigate
   > directly to:
   >
   > ```
   > https://github.com/<Org>/<Repo>/discussions/categories
   > ```
   >
   > Use that URL to manage repo-scoped discussion categories. giscus
   > and the discussions API both still work against the repo; only
   > the web UI redirects.
   ```

   Pre-existing checklist items + the giscus.app private-repo callout (lines 286-292) byte-preserved; only the new callout is added. The placement (after step 1, before step 2) puts the callout adjacent to the discussions-enable step where operators will encounter the redirect.

3. **Extend `tests/m037-acceptance/run-acceptance-battery.sh`** to invoke the two top-level handoff-doc scaffolds AFTER the existing p01-*.sh glob loop:

   ```bash
   # M037/P02/T05 — explicit invocation of verbatim handoff-doc test scaffolds.
   # These tests live at the test-tree root (not under tests/m037-acceptance/)
   # so they are not picked up by the p01-*.sh glob; invoke explicitly to
   # include in the battery total.
   for explicit_test in \
     "$PROJECT_ROOT/tests/test-wiki-init-workflow-mode.sh" \
     "$PROJECT_ROOT/tests/test-wiki-init-private-site-url.sh"; do
     test_name="$(basename "$explicit_test")"
     if [ ! -f "$explicit_test" ]; then
       printf 'SKIP: %s (not present)\n' "$test_name"
       skip=$((skip + 1))
       continue
     fi
     printf -- '--- %s ---\n' "$test_name"
     set +e
     bash "$explicit_test"
     rc=$?
     set -e
     if [ "$rc" -eq 0 ]; then
       printf 'OK: %s (rc=0)\n\n' "$test_name"
       pass=$((pass + 1))
     else
       printf 'FAIL: %s (rc=%d)\n\n' "$test_name" "$rc"
       fail=$((fail + 1))
     fi
   done
   ```

   Insert this block IMMEDIATELY BEFORE the final `printf 'BATTERY: pass=%d skip=%d fail=%d\n' ...` line. The aggregate counts include the explicit invocations.

4. **Author `tools/verify/m037-p02-phase-suite.sh`** mirroring `tools/verify/m037-p01-phase-suite.sh` shape (straight-line invocations per AD-19, no loops, no compound chains, no eval):

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m037-p02-phase-suite.sh — M037 P02 phase-close gate suite.
   #
   # Aggregates every P02 verifier from T01..T05 of the publishing-robustness
   # paper-cut bundle and emits a single aggregate SUMMARY line. Canonical
   # "P02 is done" gate.
   #
   # Sub-gates (in task order — upstream task gates surface BEFORE downstream
   # consumers, so an upstream failure short-circuits diagnostics):
   #
   #   T01 — feedback routing arm:
   #     1. m037-p02-feedback-routing.sh
   #
   #   T02 — F12 publishing cluster:
   #     2. m037-p02-workflow-pages-publishing.sh
   #
   #   T03 — private site_url visibility branch:
   #     3. m037-p02-private-site-url.sh
   #
   #   T04 — OUT-OF-SCOPE collapse:
   #     4. m037-p02-out-of-scope-collapse.sh
   #
   #   T05 — discussions callout:
   #     5. m037-p02-discussions-callout.sh
   #
   # Each sub-gate's own SUMMARY line is preserved on stdout for diagnostics;
   # the suite emits a single aggregate SUMMARY line at end.
   #
   # Bash 3.2 compatible. Straight-line invocation per AD-19 — no loops over
   # arrays, no compound chains, no eval. Mirrors tools/verify/m037-p01-phase-suite.sh.

   set -u

   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

   cd "$PROJECT_ROOT"

   pass=0
   fail=0

   emit_gate_result() {
       rc="$1"
       name="$2"
       if [ "$rc" -eq 0 ]; then
           pass=$(( pass + 1 ))
           printf 'OK: %s\n' "$name"
       else
           fail=$(( fail + 1 ))
           printf 'FAIL: %s\n' "$name"
       fi
   }

   # ---------- T01 Gate 1: feedback-routing ----------

   bash tools/verify/m037-p02-feedback-routing.sh
   rc=$?
   emit_gate_result "$rc" "m037-p02-feedback-routing.sh"

   # ---------- T02 Gate 2: workflow-pages-publishing ----------

   bash tools/verify/m037-p02-workflow-pages-publishing.sh
   rc=$?
   emit_gate_result "$rc" "m037-p02-workflow-pages-publishing.sh"

   # ---------- T03 Gate 3: private-site-url ----------

   bash tools/verify/m037-p02-private-site-url.sh
   rc=$?
   emit_gate_result "$rc" "m037-p02-private-site-url.sh"

   # ---------- T04 Gate 4: out-of-scope-collapse ----------

   bash tools/verify/m037-p02-out-of-scope-collapse.sh
   rc=$?
   emit_gate_result "$rc" "m037-p02-out-of-scope-collapse.sh"

   # ---------- T05 Gate 5: discussions-callout ----------

   bash tools/verify/m037-p02-discussions-callout.sh
   rc=$?
   emit_gate_result "$rc" "m037-p02-discussions-callout.sh"

   # ---------- Aggregate summary ----------

   printf 'SUMMARY: m037-p02-phase-suite.sh pass=%d fail=%d\n' "$pass" "$fail"

   if [ "$fail" -eq 0 ]; then
       exit 0
   fi
   exit 1
   ```

5. **Author `tests/m037-acceptance/p01-discussions-callout.sh`** (SC-17):
   - Greps `wiki/README.md` for `discussions/categories` (recovery URL pattern present).
   - Asserts the callout is inside the "First-deploy checklist" section by checking that the pattern appears between the section heading and the next `## ` heading (use awk to extract the section content; assert the URL pattern is present in the extracted text).
   - Asserts pre-existing checklist items survive: `giscus GitHub App`, `wiki-init.sh`, `Smoke-test`.
   - Emits `PASS: m037-p02-discussions-callout` on success.

   Note: SC-17 ALSO requires that "M032 wiki-deploy quickstart docs" no longer reference `bash scripts/wiki/wiki-deploy.sh` as the live-deploy path. That assertion lives in T02's `tools/verify/m037-p02-workflow-pages-publishing.sh` (wiki/README.md grep), NOT in T05's discussions-callout test — separation of concerns.

6. **Verify the acceptance battery rolls up correctly**. With T01-T05 all shipped:
   - Existing P01 tests (5): `p01-card-grid-homepage.sh`, `p01-version-to-nav-title.sh`, `p01-dr-heading-shape.sh`, `p01-mkdocs-polish-bundle.sh`, `p01-config-clobber-fix.sh`.
   - New P02 tests glob-matched as `p01-*.sh` (3): `p01-feedback-routing.sh`, `p01-out-of-scope-collapse.sh`, `p01-discussions-callout.sh`.
   - New P02 explicit-invocation tests (2): `tests/test-wiki-init-workflow-mode.sh`, `tests/test-wiki-init-private-site-url.sh`.
   - Total: 10. Target output: `BATTERY: pass=10 skip=0 fail=0`.

   Note: the spec/roadmap names the new P02 tests with `p01-` prefix because that's how they were declared in the spec at SC-13/SC-16/SC-17. The naming convention is "the test exercises the live behavior reachable from `M037 P01`+P02 wiki" rather than "the test ships in P01." The prefix is preserved for spec-fidelity.

## Must-Haves

- T13 (FR-22b README discussions callout) — phase plan.
- T14 (battery aggregator extension) — phase plan.
- T15 (phase-suite aggregator AD-19 straight-line) — phase plan.

## Verification

```bash
bash tools/verify/m037-p02-phase-suite.sh
```

```bash
bash tests/m037-acceptance/run-acceptance-battery.sh
```

```bash
bash tools/verify/m037-p02-discussions-callout.sh
```

## Inputs

### From Previous Tasks

- T01 produces `tools/verify/m037-p02-feedback-routing.sh` — invoked by phase-suite Gate 1.
- T02 produces `tools/verify/m037-p02-workflow-pages-publishing.sh` — invoked by phase-suite Gate 2. T02 also owns the M032 wiki/README.md restructure that T05 lands the callout on top of.
- T03 produces `tools/verify/m037-p02-private-site-url.sh` — invoked by phase-suite Gate 3.
- T04 produces `tools/verify/m037-p02-out-of-scope-collapse.sh` — invoked by phase-suite Gate 4.

### From Disk (Pre-existing)

- `tools/verify/m037-p01-phase-suite.sh` — structural template for T05's phase-suite aggregator. AD-19 straight-line shape; no loops, no compound chains.
- `tests/m037-acceptance/run-acceptance-battery.sh` — extended in step 3.
- `wiki/README.md` — modified in step 2 (callout addition); pre-existing content byte-preserved.

## Constraints

- AD-19: all `Check:` commands single-script-file shape; phase-suite aggregator MUST use straight-line invocations (no loops over arrays, no `for v in $(...)`, no compound chains).
- Bash 3.2 + POSIX sh in script additions.
- The README callout MUST be additive — pre-existing checklist items byte-preserved. Use `diff`-checking at executor time to confirm: `git diff wiki/README.md` should show ONLY the callout addition (modulo line-number context shifts), no other content modifications.
- The acceptance battery extension MUST preserve the existing glob behavior for `p01-*.sh` — the explicit-invocation block is ADDITIVE, inserted before the final `printf BATTERY:` line. Existing skip/fail/pass counters are reused.
- `BATTERY: pass=10 skip=0 fail=0` is the SUCCESS target. If any P02 verifier or fixture is unbuilt at executor time, the battery surfaces the gap as `fail` rather than `skip` — only "test file not present" maps to `skip`. (T05 verifier-availability cross-check at plan-authoring time confirms all five verifiers will exist before T05 dispatches.)

## Expected Output

After T05 ships:
- `bash tools/verify/m037-p02-phase-suite.sh` exits 0 with `SUMMARY: m037-p02-phase-suite.sh pass=5 fail=0`.
- `bash tests/m037-acceptance/run-acceptance-battery.sh` exits 0 with `BATTERY: pass=10 skip=0 fail=0`.
- `wiki/README.md` § "First-deploy checklist" carries the org-level-discussions-redirect callout between steps 1 and 2; pre-existing items unchanged.

## Notes

- **Why `p01-` prefix on new P02 tests**: spec-fidelity. The spec at SC-13/SC-16/SC-17 names them with `p01-` prefix and the roadmap preserves the names. Renaming would force spec/roadmap edits and is not load-bearing — the glob `p01-*.sh` picks them up regardless of which phase implements them.

- **The phase-suite aggregator does NOT include `m037-p01-phase-suite.sh`** — P01 is closed and its phase-suite ran at P01 close. P02's phase-suite gates only the surface area added by P02. Milestone-close gating (the eventual `tools/verify/m037-milestone-suite.sh` or equivalent) would aggregate both.

- **The acceptance battery's `BATTERY: pass=10 fail=0` line** is the canonical "P02 is done" external-facing signal. Phase-close runs both `m037-p02-phase-suite.sh` (pass=5 fail=0) and the acceptance battery (pass=10 skip=0 fail=0). Both must be green before P02 closes.

- **No real-DB verification (rule 5)**: NOT APPLICABLE. T05 is documentation + test plumbing only.

- **Verifier-availability cross-check passed at plan-authoring time**: T01-T04 all schedule their verifier authorship inside their own task plan's `## Steps`. T05's phase-suite aggregator references those verifiers; they will exist on disk before T05 dispatches under sequential `orchestrator:auto` ordering (T01 → T02 → T03 → T04 → T05).

## State Context

- **Current State**: executing
- **Milestone**: M037
- **Phase**: P02
- **Task**: T05-discussions-callout-and-phase-suite
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- AD-19: all `Check:` commands single-script-file shape; phase-suite aggregator MUST use straight-line invocations (no loops over arrays, no `for v in $(...)`, no compound chains).
- Bash 3.2 + POSIX sh in script additions.
- The README callout MUST be additive — pre-existing checklist items byte-preserved. Use `diff`-checking at executor time to confirm: `git diff wiki/README.md` should show ONLY the callout addition (modulo line-number context shifts), no other content modifications.
- The acceptance battery extension MUST preserve the existing glob behavior for `p01-*.sh` — the explicit-invocation block is ADDITIVE, inserted before the final `printf BATTERY:` line. Existing skip/fail/pass counters are reused.
- `BATTERY: pass=10 skip=0 fail=0` is the SUCCESS target. If any P02 verifier or fixture is unbuilt at executor time, the battery surfaces the gap as `fail` rather than `skip` — only "test file not present" maps to `skip`. (T05 verifier-availability cross-check at plan-authoring time confirms all five verifiers will exist before T05 dispatches.)

### Acceptance Criteria

- T13 (FR-22b README discussions callout) — phase plan.
- T14 (battery aggregator extension) — phase plan.
- T15 (phase-suite aggregator AD-19 straight-line) — phase plan.

### Files To Touch

- [`.orchestrator/milestones/M037/phases/P02/P02-PLAN.md`](../../../../../milestones/M037/phases/P02/P02-PLAN.md) (create)
- [`.orchestrator/milestones/M037/phases/P02/tasks/T01-feedback-routing-arm-PLAN.md`](../../../../../milestones/M037/phases/P02/tasks/T01-feedback-routing-arm-PLAN.md) (create)
- [`.orchestrator/milestones/M037/phases/P02/tasks/T02-workflow-publishing-cluster-PLAN.md`](../../../../../milestones/M037/phases/P02/tasks/T02-workflow-publishing-cluster-PLAN.md) (create)
- [`.orchestrator/milestones/M037/phases/P02/tasks/T03-private-site-url-PLAN.md`](../../../../../milestones/M037/phases/P02/tasks/T03-private-site-url-PLAN.md) (create)
- [`.orchestrator/milestones/M037/phases/P02/tasks/T04-out-of-scope-collapse-PLAN.md`](../../../../../milestones/M037/phases/P02/tasks/T04-out-of-scope-collapse-PLAN.md) (create)
- [`.orchestrator/milestones/M037/phases/P02/tasks/T05-discussions-callout-and-phase-suite-PLAN.md`](../../../../../milestones/M037/phases/P02/tasks/T05-discussions-callout-and-phase-suite-PLAN.md) (create)
- `scripts/wiki/wiki-generate-stubs.sh` (modify — T01)
- `scripts/wiki/wiki-scan-sources.sh` (modify — T01)
- `scripts/lifecycle/wiki-init.sh` (modify — T02 + T03)
- `scripts/wiki/wiki-deploy.sh` (modify — T02 + T04)
- `scripts/diagnostics/wiki-link-check.sh` (modify — T04)
- `wiki/README.md` (modify — T02 + T05)
- `tests/m037-acceptance/run-acceptance-battery.sh` (modify — T05)
- `tests/m037-acceptance/p01-feedback-routing.sh` (create — T01)
- `tests/m037-acceptance/p01-out-of-scope-collapse.sh` (create — T04)
- `tests/m037-acceptance/p01-discussions-callout.sh` (create — T05)
- `tests/test-wiki-init-workflow-mode.sh` (create — T02, verbatim from handoff)
- `tests/test-wiki-init-private-site-url.sh` (create — T03, verbatim from handoff)
- `tests/fixtures/m037-feedback-routing/` (create — T01 fixture corpus, three .md files)
- `tools/verify/m037-p02-feedback-routing.sh` (create — T01)
- `tools/verify/m037-p02-workflow-pages-publishing.sh` (create — T02)
- `tools/verify/m037-p02-private-site-url.sh` (create — T03)
- `tools/verify/m037-p02-out-of-scope-collapse.sh` (create — T04)
- `tools/verify/m037-p02-discussions-callout.sh` (create — T05)
- `tools/verify/m037-p02-phase-suite.sh` (create — T05)

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