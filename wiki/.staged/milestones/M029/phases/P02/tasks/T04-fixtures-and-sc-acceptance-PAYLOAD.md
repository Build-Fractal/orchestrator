---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T04-fixtures-and-sc-acceptance (Phase P02, Milestone M029)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~600 | required |
| Upstream Context | 981-1045 | ~3200 | required |
| Task Plan | 1047-1408 | ~6500 | required |
| State Context | 1410-1416 | ~100 | required |
| First-Turn Completeness | 1418-1485 | ~1300 | required |
| **Total** | | **~22500** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 837
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
hit_count: 837
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
hit_count: 837
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
hit_count: 837
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
hit_count: 728
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
hit_count: 728
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
hit_count: 728
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
hit_count: 837
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
hit_count: 728
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
hit_count: 728
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
hit_count: 728
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
hit_count: 837
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
hit_count: 837
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
hit_count: 837
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
hit_count: 728
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
hit_count: 728
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
hit_count: 728
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
hit_count: 837
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
hit_count: 728
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
hit_count: 728
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
hit_count: 837
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
hit_count: 837
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
hit_count: 728
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
hit_count: 728
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
hit_count: 728
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
hit_count: 383
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
hit_count: 383
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
hit_count: 383
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
hit_count: 413
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
hit_count: 413
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
hit_count: 403
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

<!-- Behavioral truths that scripts/verify/check-must-haves.sh checks via the bound script-file shape (AD-19). Every Check is a single bash <path> invocation; no inline compound, no plain subshell, no $() with pipes. Project-owned per-phase verifiers live under tools/verify/ with the m029-p02-* slug prefix; framework-owned verifiers live under scripts/verify/. -->

- The AD-6 cross-milestone data-model contract document exists at `references/cross-milestone-feature-shape.md` and pins the exactly-one-of `milestone:` ⊕ `milestones:` rule + reverse-lookup advisory + collapsed/expanded inactive-render shape (#Q-5 resolution).
  - Check: `bash tools/verify/m029-p02-cross-milestone-shape-contract.sh`

- `scripts/diagnostics/summarize-milestone.sh` exists, is executable, emits a fixed-order key=value block (`phase_count=...`, `phases_complete=...`, `tasks_remaining=...`, `intensity=...`) read-only against the active milestone, and accepts `--milestone <M###>` as the AD-4 SC-8 oracle interface.
  - Check: `bash tools/verify/m029-p02-summarize-milestone-shape.sh`

- `scripts/diagnostics/render-position.sh` exists, is executable, sources the AD-1 invocation-context resolver and emits a tree using the documented glyph set (`✓ ▶ ◇ ✗ ▽`) with milestone progress bar + per-row cost column, suppresses the cost column silently on pre-M019 milestones (FR-6/CON-3), and never invokes `gh` / GitHub APIs (FR-11/CON-4/SC-13).
  - Check: `bash tools/verify/m029-p02-render-position-shape.sh`

- `commands/where.md` exists with the canonical 8-section command-doc shape, declares read-only discipline (CON-1/FR-14), references `scripts/diagnostics/render-position.sh` + `scripts/state/detect-invocation-context.sh` + `references/cross-milestone-feature-shape.md`, and embeds the documented glyph legend.
  - Check: `bash tools/verify/m029-p02-where-skill-shape.sh`

- The SC-5 mixed-state golden fixture covers all four glyph states (`✓ ▶ ◇ ✗`) and is byte-stable under the #Q-G6 enumerated timestamp-strip regex set; `tests/m029-acceptance/timestamp-strip.sh` enumerates exactly the #Q-G6 patterns; the FR-8 marker canonical form `▽ saved Nk` (#Q-G8 resolution) is the only form that appears in fixtures and verifiers (no `▽ 4k saved` or `▽ saved Nk via tier1 cache reuse` strings anywhere in P02 deliverables).
  - Check: `bash tools/verify/m029-p02-sc5-fixtures-shape.sh`

<dispatch-volatile>

## Upstream Context


### P01 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M029"
milestone: "M029"
provides:
  - "Principle III design contracts for FR-2 status headline + FR-3 status --format=json; gate verifiers that mechanically enforce field,regex,and key presence so downstream tasks (T03/T04) cannot drift from the contracts,AD-1 single-resolve invocation-context resolver (scripts/state/detect-invocation-context.sh) emitting renderer/exit_code_scheme/default_provider env block consumed by every M029 surface; SC-1 acceptance script + two shape verifiers gating downstream drift,FR-2 status headline block additions to commands/status.md (## Headline Block section + 5 Reference Files entries) plus SC-2 fixture milestone tree (M999 in executing state with one complete phase + one in-flight phase + populated execution-log.jsonl) plus SC-2 acceptance script (regex assertion + flat-section byte-identity diff + CON-5 footer-suppression test) plus two shape verifiers gating downstream drift,JSON renderer (FR-3) + commands/status.md --format=json wiring (FR-3 + AD-2 + AD-7) + SC-3 fixtures + acceptance + three shape verifiers,orchestrator:context FR-4 single-screen runtime-profile skill (commands/context.md) + SC-4 fixture/script + 2 verifiers,P01 phase-close gate: SC-11 acceptance battery (SC-1..SC-4 slice) + 3 close-gate verifiers + 14-gate phase-suite aggregator"
requires:
  - "none"
affects:
  - "P02"
key_files:
  - "references/status-headline-shape.md,references/status-json-schema.md,tools/verify/m029-p01-headline-shape-contract.sh,tools/verify/m029-p01-json-schema-contract.sh,scripts/state/detect-invocation-context.sh,tests/m029-acceptance/p01-sc1-resolver.sh,tools/verify/m029-p01-invocation-context-resolver-shape.sh,tools/verify/m029-p01-sc1-shape.sh,commands/status.md,tests/m029-acceptance/fixtures/status-headline-executing.fixture/milestones/M999/M999-ROADMAP.md,tests/m029-acceptance/fixtures/status-headline-executing.fixture/milestones/M999/phases/P01/P01-SUMMARY.md,tests/m029-acceptance/fixtures/status-headline-executing.fixture/milestones/M999/execution-log.jsonl,tests/m029-acceptance/p01-sc2-headline.sh,tools/verify/m029-p01-status-headline-shape.sh,tools/verify/m029-p01-sc2-shape.sh,scripts/diagnostics/render-status-json.sh,tests/m029-acceptance/p01-sc3-format-json.sh,tests/m029-acceptance/fixtures/status-json-executing.fixture,tests/m029-acceptance/fixtures/status-json-degraded.fixture,tools/verify/m029-p01-render-status-json-shape.sh,tools/verify/m029-p01-status-format-json-wiring.sh,tools/verify/m029-p01-sc3-shape.sh,commands/context.md,tests/m029-acceptance/p01-sc4-context.sh,tests/m029-acceptance/fixtures/context-minimal.fixture/,tools/verify/m029-p01-context-skill-shape.sh,tools/verify/m029-p01-sc4-shape.sh,tests/m029-acceptance/p01-acceptance-battery.sh,tools/verify/m029-p01-acceptance-battery-shape.sh,tools/verify/m029-p01-readonly-invariant.sh,tools/verify/m029-p01-scope-guard.sh,tools/verify/m029-p01-phase-suite.sh"
key_decisions:
  - "AD-1 single-resolve invocation context discipline,AD-2 unconditional ANSI strip under --format=json,AD-7 schema_version 1.0 from day 1 + stability policy,Principle III design contracts upstream of code,AD-1 single-resolve invocation context (renderer/exit_code_scheme/default_provider env block as SSOT for every M029 surface),Principle XI (no surface re-derives TTY/CI/runtime detection),CON-1/FR-14 read-only resolver,FR-2 (status headline block as 3 non-blank lines packing 5 fields),SC-2 (headline regex + flat-section byte-identity invariant),CON-5 (suppression-matrix inheritance from [M027](../../../../../milestones/M027/index.md) efficiency_footer knob),AD-1 (single-resolve invocation context consumed by headline path),AD-2,AD-7,AD-1,AD-1 single-resolve at command entry; SC-2 embedded-reference-renderer pattern reused; sentinel-file precursor for SC-14; new minimal fixture (not SC-2 reuse) for .orchestrator/-rooted read-only check,AD-19 linear bash invocation pattern; sentinel-file find -newer as SC-14 precursor; conservative scope-guard (WARN advisory for unclassified paths,FAIL only on denylist hits); battery / phase-suite split (battery embeds in milestone validator,phase-suite is per-phase close gate)"
patterns_established:
  - "paired design contracts cross-checked by gate verifiers in both directions; verifiers assert field/regex/key presence rather than just file existence so downstream consumers cannot silently drift,three-helper resolver shape (_resolve_renderer / _resolve_exit_code_scheme / _resolve_default_provider) emitting fixed-order key=value env block; test-injection flags (--tty/--ci) decouple resolution from real TTY state for SC-1 fixturing; shape verifier asserts field names + values + fixed-order stdout regex so downstream consumers cannot drift silently,reference-renderer-in-acceptance-script (SC-2 embeds an inline m029_render_status function mirroring commands/status.md instructions because the command is an LLM-instruction document,not an executable script -- the function is test-internal and explicitly NOT a production code path); fixture-milestone-tree-under-orch-root (fixture root contains milestones/M999/ matching find-active-milestone.sh probe shape); flat-section-byte-identity-via-tail-skip (SC-2 trims headline+blank+footer-block+blank prefix via tail -n +N then diffs against M029_DISABLE_HEADLINE=1 baseline); CON-5 footer-off path keeps headline (suppression knob disappears footer line ONLY,headline 3 lines remain),single ANSI-strip site (AD-2); _M029_SCHEMA_VERSION constant as renderer-side SSOT cross-checked against schema doc; jq -n --arg safe JSON construction; degraded-state envelope (state + parse_errors) on corrupt JSONL never crashes the renderer,LLM-instruction-doc skills get an embedded reference renderer in their acceptance script; sentinel-file find -newer is the precursor for the AD-9 SC-14 mechanism,phase-suite aggregator structure mirrors m031-p00-phase-suite.sh (linear bash <path> + emit_gate_result + final SUMMARY); acceptance-battery wrapper aggregates SC scripts and emits BATTERY: line; scope-guard combines git status --porcelain=v1 with allowlist/denylist classification + WARN: advisory for unclassified"
drill_down_paths:
  - "[.orchestrator/milestones/M029/phases/P01/tasks/T01-design-contracts-SUMMARY.md](../../../../../milestones/M029/phases/P01/tasks/T01-design-contracts-SUMMARY.md), [.orchestrator/milestones/M029/phases/P01/tasks/T02-invocation-context-resolver-SUMMARY.md](../../../../../milestones/M029/phases/P01/tasks/T02-invocation-context-resolver-SUMMARY.md), [.orchestrator/milestones/M029/phases/P01/tasks/T03-status-headline-block-SUMMARY.md](../../../../../milestones/M029/phases/P01/tasks/T03-status-headline-block-SUMMARY.md), [.orchestrator/milestones/M029/phases/P01/tasks/T04-status-json-format-SUMMARY.md](../../../../../milestones/M029/phases/P01/tasks/T04-status-json-format-SUMMARY.md), [.orchestrator/milestones/M029/phases/P01/tasks/T05-context-skill-SUMMARY.md](../../../../../milestones/M029/phases/P01/tasks/T05-context-skill-SUMMARY.md), [.orchestrator/milestones/M029/phases/P01/tasks/T06-acceptance-and-phase-suite-SUMMARY.md](../../../../../milestones/M029/phases/P01/tasks/T06-acceptance-and-phase-suite-SUMMARY.md)"
duration: "9m"
verification_result: "pass"
completed_at: "2026-05-05T23:29:31Z"
observability_surfaces:
  - "none"
---

M029/P01 ships the entire `orchestrator:status` headline + `--format=json` + `orchestrator:context` skill surface, gated by mechanically-enforced design contracts and a 14-gate phase-suite aggregator.

**What was built (six tasks, all PASS):**

- **T01 — design contracts (Principle III).** Two paired contract documents: `references/status-headline-shape.md` (FR-2 — five fields, three-line packing, SC-2 regex, CON-5 inheritance) and `references/status-json-schema.md` (FR-3 — `schema_version: "1.0"` from day 1 per AD-7, ten required top-level keys, AD-2 unconditional ANSI strip, degraded-state envelope). Two gate verifiers (`m029-p01-headline-shape-contract.sh` 20/20, `m029-p01-json-schema-contract.sh` 31/31) assert every header / regex token / top-level key / spec reference rather than mere existence — so T03/T04 cannot silently drift.

- **T02 — AD-1 single-resolve invocation-context resolver.** `scripts/state/detect-invocation-context.sh` emits a fixed-order three-line env block (`renderer=…`, `exit_code_scheme=…`, `default_provider=…`) consumed by every downstream M029 surface; no T03/T04/T05 code path re-derives TTY/CI/runtime detection. Test-injection flags (`--tty`, `--ci`) decouple resolution from real TTY state for SC-1 fixturing. SC-1 acceptance covers all four AD-1 cases (CI-forces-plain-over-TTY, `--format=json`-wins, unknown-flag exit-2-with-stderr-usage, plain-fallback).

- **T03 — FR-2 status headline block.** Additive `## Headline Block` section + 5 Reference Files entries in `commands/status.md`. SC-2 fixture milestone tree (M999 in executing state, valid M019 Tier 1 dispatch_usage + unit_close records). SC-2 acceptance asserts the regex shape, the flat-section byte-identity invariant (M027 / [M013](../../../../../milestones/M013/index.md) / M019 sections must be unchanged after headline insertion), and CON-5 footer-suppression inheritance.

- **T04 — FR-3 `--format=json`.** `scripts/diagnostics/render-status-json.sh` is the SINGLE AD-2 ANSI-strip site for JSON output, declares `_M029_SCHEMA_VERSION="1.0"` cross-checked against the schema doc, uses `jq -n --arg` for safe JSON construction, and emits a degraded-state envelope (`state="degraded"` + `parse_errors[]`) on corrupt JSONL without crashing. `commands/status.md` gains a `## Format Flag` section between Headline Block and State Derivation. SC-3 covers the executing-state and degraded-state fixture trees.

- **T05 — FR-4 `orchestrator:context` skill.** `commands/context.md` (canonical 8-section command-doc shape, single-screen ≤ 24 lines, six labeled fields, AD-1 single-resolve discipline, read-only contract). SC-4 acceptance via embedded reference renderer (SC-2 precedent for LLM-instruction-doc skills) against a new minimal fixture (`<root>/.orchestrator/...` shape required by the sentinel-file precursor for AD-9/SC-14).

- **T06 — close gate.** SC-11 acceptance battery (`p01-acceptance-battery.sh`, chains SC-1..SC-4 → 4/4 PASS), 14-gate phase-suite aggregator (`m029-p01-phase-suite.sh`, mirrors `m031-p00-phase-suite.sh` shape), CON-1/FR-14 readonly-invariant verifier (sentinel-file `find -newer` precursor for SC-14), conservative scope-guard (denylist FAIL + WARN-on-unclassified).

**Verification.** Phase-suite **14/14 PASS**, acceptance battery **4/4 PASS**, full 4-tier `orchestrator:verify` PASS (Tier 1: 116/116, Tier 2: phase-suite 14/14 + battery 4/4, Tier 3: behavioral spot-checks confirm AD-1 / AD-2 / FR-2-3-4, Tier 4: N/A — no human-review must-haves at phase grain).

**Patterns established (load-bearing for P02 and downstream M029 phases):**

1. **Paired design contracts cross-checked by gate verifiers in both directions** — each verifier asserts the companion contract is referenced, enforcing the pairing invariant. T03/T04 cannot silently drift from the FR-2/FR-3 specs.
2. **Three-helper resolver shape with fixed-order env block** — `_resolve_renderer` / `_resolve_exit_code_scheme` / `_resolve_default_provider`. AD-1 single-resolve discipline is now mechanical.
3. **Reference-renderer-in-acceptance-script** for LLM-instruction-doc skills (SC-2 / SC-4 pattern). The function is test-internal and explicitly NOT a production code path; production rendering is performed by an LLM agent reading the `.md` skill doc.
4. **Single ANSI-strip site (AD-2)** + `jq -n --arg` safe JSON construction + degraded-state envelope on corrupt JSONL.
5. **Phase-suite aggregator + acceptance battery split** — battery wraps SC scripts (re-used by milestone validator), phase-suite is the per-phase close gate (mirrors `m031-p00-phase-suite.sh`).
6. **Sentinel-file `find -newer` mechanism** as the precursor for the AD-9 SC-14 milestone-grain readonly-invariant gate.
7. **Conservative scope-guard** — `git status --porcelain=v1` × allowlist/denylist classification, FAIL only on denylist hits, WARN: advisory for unclassified.

**Plan-shape paper-cut surfaced and patched in-flight.** T04/T05/T06 task plans listed "creates these phase artifacts" using bare-backtick bullets (`- \`path\``), which the auto-loop verify-step parser at `scripts/lifecycle/auto-loop.sh:359-369` matches as bare-backtick command bullets and `eval`s. Bullets resolving to directories (T04 fixtures) or non-executable markdown (T05 `commands/context.md`) failed verification as a parser-shape false positive even though the actual `## Verification` block was green. Repaired the three plans in-flight to use the T01/T02/T03 convention `- \`path\` — description.` (description after the backtick keeps the bullet off the bare-backtick parser regex). Followup: planner template should default to the description-suffixed shape so future task plans don't surface this; deliverables themselves are unaffected.

**Decisions register.** AD-1 (single-resolve), AD-2 (unconditional strip), AD-7 (`schema_version: "1.0"` lock), AD-19 (linear bash invocation pattern preserved end-to-end). All on disk in the per-task SUMMARYs.

**P02 unblocked** — `orchestrator:where` tree renderer phase consumes the resolver, the headline, the JSON shape, and the phase-suite aggregator scaffolding from P01.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P02"
milestone: "M029"
name: "SC-5/SC-6/SC-13/SC-14 fixtures + acceptance scripts + sentinel harness (AD-9, #Q-G6, #Q-G8)"
depends_on: ["T03"]
---

## Prerequisites

- T03 has landed: `scripts/diagnostics/render-position.sh` and `commands/where.md` are on disk and their shape verifiers exit 0; verify `[ -x scripts/diagnostics/render-position.sh ]` and `[ -f commands/where.md ]`.
- T01 + T02 have landed (transitively required by T03; double-check `[ -f references/cross-milestone-feature-shape.md ]` and `[ -x scripts/diagnostics/summarize-milestone.sh ]`).
- `tests/m029-acceptance/` exists (P01 created it); verify `[ -d tests/m029-acceptance ]`.
- `tests/m029-acceptance/fixtures/` exists (P01 created it for status-fixtures).
- No file currently lives at any of: `tests/m029-acceptance/fixtures/where-mixed-state.golden`, `tests/m029-acceptance/fixtures/where-mixed-state.fixture/`, `tests/m029-acceptance/fixtures/where-pre-m019.fixture/`, `tests/m029-acceptance/timestamp-strip.sh`, `tests/m029-acceptance/sentinel-harness.sh`, `tests/m029-acceptance/p02-sc5-where-mixed-state.sh`, `tests/m029-acceptance/p02-sc6-where-pre-m019.sh`, `tests/m029-acceptance/p02-sc13-anti-coupling.sh`, `tests/m029-acceptance/p02-sc14-readonly.sh` (path-collision rule 6 already checked at plan-authoring time — all clean).
- The M029 spec body and context draft restate FR-5/FR-6/FR-11/FR-13/FR-14, SC-5/SC-6/SC-13/SC-14, AD-6/AD-9, #Q-G6 and #Q-G8 inline above; the executor does not need to re-read the spec.

## Description

T04 ships **all four SC fixtures + acceptance scripts that gate P02**:

1. **SC-5 mixed-state fixture + golden render** — `tests/m029-acceptance/fixtures/where-mixed-state.fixture/` is a deterministic project tree containing:
   - `.orchestrator/milestones/M998/M998-ROADMAP.md` (3 phases: P01 done, P02 executing, P03 pending)
   - `.orchestrator/milestones/M998/M998-EVALUATION.md` (intensity=full, feature_ref=037-roadmap-visibility-cli-ux)
   - `.orchestrator/milestones/M998/phases/P01/P01-PLAN.md` + `P01-SUMMARY.md` + one task pair → `✓` glyph
   - `.orchestrator/milestones/M998/phases/P02/P02-PLAN.md` + `tasks/T01-x-PLAN.md` + `T01-x-SUMMARY.md` (✓), `T02-y-PLAN.md` (▶), `T03-z-PLAN.md` (◇), `T04-w-PLAN.md` + a synthetic `last_verify=fail` execution-log entry (✗) — all four glyph states present.
   - `.orchestrator/milestones/M998/phases/P03/P03-PLAN.md` only → `◇` for the entire phase.
   - `.orchestrator/milestones/M998/execution-log.jsonl` with synthetic `dispatch_usage` records under M019 Tier 1 schema, sufficient for `metrics-rollup.sh --granularity task` to emit cost values.

   The byte-stable golden render at `tests/m029-acceptance/fixtures/where-mixed-state.golden` captures `render-position.sh --milestone M998 --root <fixture-root>/.orchestrator` output AFTER passing through `timestamp-strip.sh` (the #Q-G6 normalizer).

2. **SC-6 pre-M019 fixture** — `tests/m029-acceptance/fixtures/where-pre-m019.fixture/` is a parallel project tree containing a milestone whose `execution-log.jsonl` is **empty** (or absent), simulating a milestone predating M019 Tier 1 emission. The renderer must omit the cost column entirely AND emit nothing on stderr (FR-6 / CON-3).

3. **`tests/m029-acceptance/timestamp-strip.sh`** — the canonical #Q-G6 timestamp-strip filter. Reads stdin, writes to stdout. Strips:
   - ISO-8601 timestamps: `\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z`
   - Recency phrasing: `\d+[smhd] ago`
   - Epoch-second tokens that appear in dispatch_id contexts: `\b1[6-9]\d{8}\b`
   Replaces each match with a fixed placeholder (`<TS>` or `<RECENCY>` or `<EPOCH>`). Reproducible across runs.

4. **`tests/m029-acceptance/sentinel-harness.sh`** — the AD-9 mechanism. Wraps an arbitrary command:
   - Writes `.orchestrator/.m029-sc14-sentinel` with the current ISO-8601 UTC timestamp.
   - Records the sentinel's mtime (via `stat`).
   - Runs the wrapped command (forwarded as `"$@"`).
   - After the command completes, scans `.orchestrator/` for any file whose mtime is newer than the sentinel's recorded mtime, EXCLUDING the sentinel itself and EXCLUDING `.orchestrator/start-state/<stage>.complete` markers (the only documented write-site exception per AD-9 / FR-10).
   - On any newer-mtime hit: print `FAIL: read-only invariant violated by <path>` per offender + final `SUMMARY: sentinel-harness.sh fail=N`. Exit 1.
   - On no hits: print `PASS: read-only invariant held`. Exit 0.

5. **SC-5 / SC-6 / SC-13 / SC-14 acceptance scripts** under `tests/m029-acceptance/`:
   - `p02-sc5-where-mixed-state.sh` — invokes the renderer against the mixed-state fixture, normalizes through `timestamp-strip.sh`, diffs against the golden, exits 0 on byte-identity.
   - `p02-sc6-where-pre-m019.sh` — invokes the renderer against the pre-M019 fixture, asserts cost column is absent (no row contains the cost-column delimiter) AND stderr is empty (FR-6 / CON-3).
   - `p02-sc13-anti-coupling.sh` — runs the SC-13 anti-coupling guard: `grep -r '/integrations/github' specs/037-roadmap-visibility-cli-ux/ scripts/diagnostics/render-position.sh` returns no match.
   - `p02-sc14-readonly.sh` — wraps `bash sentinel-harness.sh bash render-position.sh --milestone M998 --root <fixture-root>/.orchestrator > /dev/null` and asserts the read-only invariant holds.

## Steps

1. **Create the SC-5 mixed-state fixture tree** at `tests/m029-acceptance/fixtures/where-mixed-state.fixture/`:

   ```
   tests/m029-acceptance/fixtures/where-mixed-state.fixture/
   └── .orchestrator/
       └── milestones/
           └── M998/
               ├── M998-ROADMAP.md       (3 phases listed)
               ├── M998-EVALUATION.md    (intensity=full, feature_ref=037-roadmap-visibility-cli-ux)
               ├── execution-log.jsonl   (synthetic dispatch_usage records for the four task IDs + one unit_close per completed phase)
               └── phases/
                   ├── P01/
                   │   ├── P01-PLAN.md
                   │   ├── P01-SUMMARY.md   (presence → ✓)
                   │   └── tasks/
                   │       ├── T01-foo-PLAN.md
                   │       └── T01-foo-SUMMARY.md
                   ├── P02/
                   │   ├── P02-PLAN.md      (no SUMMARY → ▶)
                   │   └── tasks/
                   │       ├── T01-x-PLAN.md
                   │       ├── T01-x-SUMMARY.md   (✓)
                   │       ├── T02-y-PLAN.md      (▶ — no SUMMARY, latest task in execution-log)
                   │       ├── T03-z-PLAN.md      (◇ — no SUMMARY, no execution record)
                   │       └── T04-w-PLAN.md      (✗ — last verify fail in execution-log)
                   └── P03/
                       └── P03-PLAN.md            (◇ — no tasks dir)
   ```

   Frontmatter for ROADMAP/EVALUATION must use the schemas already established by sibling milestones (e.g. M027/[M028](../../../../../milestones/M028/index.md)) — readable by `scripts/state/read-roadmap.sh` and the parsers in `summarize-milestone.sh`. The execution-log.jsonl records must conform to M019 Tier 1 schema (`record_type=dispatch_usage`, `granularity=task`, `milestone=M998`, `phase=P02`, `task=T##`, plus the documented cost / quality fields). For T04-w (the failed task), include a `record_type=verify_result` with `pass=false` so the renderer can derive the `✗` glyph.

2. **Generate `tests/m029-acceptance/fixtures/where-mixed-state.golden`** by running `bash scripts/diagnostics/render-position.sh --milestone M998 --root tests/m029-acceptance/fixtures/where-mixed-state.fixture/.orchestrator | bash tests/m029-acceptance/timestamp-strip.sh > tests/m029-acceptance/fixtures/where-mixed-state.golden`. The golden is then the BYTE-STABLE expected output. Inspect it manually to confirm:
   - All four glyphs (`✓ ▶ ◇ ✗`) appear at least once.
   - The milestone progress bar (`▓░ 33%`) appears.
   - The cost column is present (cost values from M019 Tier 1 records).
   - The headline summary line (mirroring P01 vocabulary) is present.

3. **Create the SC-6 pre-M019 fixture tree** at `tests/m029-acceptance/fixtures/where-pre-m019.fixture/` — mirrors the SC-5 structure but for milestone M997 with NO `execution-log.jsonl` (or an empty one — both are valid pre-M019 markers):

   ```
   tests/m029-acceptance/fixtures/where-pre-m019.fixture/
   └── .orchestrator/
       └── milestones/
           └── M997/
               ├── M997-ROADMAP.md   (1 phase)
               ├── M997-EVALUATION.md
               └── phases/
                   └── P01/
                       ├── P01-PLAN.md
                       └── P01-SUMMARY.md
   ```

4. **Create `tests/m029-acceptance/timestamp-strip.sh`** (≥20 lines, executable, bash 3.2 compatible). Single `sed -E` invocation with three `-e` clauses (one per regex), reading stdin and writing stdout. Per AD-19 / MEM001: NO process substitution, NO `<<<` herestring; the script body MAY use sed pipes (MEM004 carve-out — pipes are permitted INSIDE script bodies, just not on Check: lines).

   ```bash
   #!/usr/bin/env bash
   # tests/m029-acceptance/timestamp-strip.sh
   # M029 / #Q-G6 enumerated-pattern timestamp-strip filter for SC-5 golden-render comparison.
   #
   # Reads stdin, writes stdout. Strips:
   #   - ISO-8601 UTC timestamps:  \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z   -> <TS>
   #   - Recency phrasing:         \d+[smhd] ago                          -> <RECENCY>
   #   - Epoch-second tokens:      \b1[6-9]\d{8}\b                        -> <EPOCH>
   #
   # Reproducible across runs. Bash 3.2 / MEM001 compatible.
   set -u
   sed -E \
       -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z/<TS>/g' \
       -e 's/[0-9]+[smhd] ago/<RECENCY>/g' \
       -e 's/(^|[^0-9])1[6-9][0-9]{8}([^0-9]|$)/\1<EPOCH>\2/g'
   ```

   `chmod +x`.

5. **Create `tests/m029-acceptance/sentinel-harness.sh`** (≥30 lines, executable, bash 3.2 compatible, AD-19 single-script-file shape — NO inline compound chains).

   ```bash
   #!/usr/bin/env bash
   # tests/m029-acceptance/sentinel-harness.sh
   # M029 / AD-9 sentinel-file harness for SC-14 read-only enforcement.
   #
   # Usage: bash sentinel-harness.sh <command-and-args>...
   #
   # Mechanism (AD-9):
   #   1. Write .orchestrator/.m029-sc14-sentinel with the current ISO-8601 UTC timestamp.
   #   2. Capture the sentinel's mtime via `stat`.
   #   3. Run the wrapped command.
   #   4. Scan .orchestrator/ for any file whose mtime is newer than the sentinel's,
   #      EXCLUDING the sentinel itself AND .orchestrator/start-state/*.complete.
   #   5. PASS iff no offenders; FAIL with one line per offender otherwise.
   #
   # Bash 3.2 / MEM001 compatible. AD-19: straight-line bash. No process substitution.

   set -u

   if [ $# -lt 1 ]; then
       printf 'Usage: sentinel-harness.sh <command> [args...]\n' >&2
       exit 2
   fi

   ORCH_ROOT="${ORCHESTRATOR_ROOT:-.orchestrator}"
   if [ ! -d "$ORCH_ROOT" ]; then
       printf 'sentinel-harness.sh: %s does not exist\n' "$ORCH_ROOT" >&2
       exit 2
   fi

   SENTINEL="$ORCH_ROOT/.m029-sc14-sentinel"
   date -u +%Y-%m-%dT%H:%M:%SZ > "$SENTINEL"

   # Run the wrapped command. Forward exit code on failure but always proceed
   # to the sentinel scan so the operator sees both the command failure AND
   # any read-only violation.
   "$@"
   CMD_RC=$?

   # find -newer is AD-19 safe (single command, no pipe, no $()).
   # Use a tempfile to capture the find output.
   TMP_OUT="${TMPDIR:-/tmp}/m029-sentinel-scan.$$"
   find "$ORCH_ROOT" -type f -newer "$SENTINEL" \
       ! -path "$SENTINEL" \
       ! -path "$ORCH_ROOT/start-state/*.complete" \
       > "$TMP_OUT" 2>/dev/null

   fail=0
   while IFS= read -r line; do
       [ -n "$line" ] || continue
       printf 'FAIL: read-only invariant violated by %s\n' "$line"
       fail=$(( fail + 1 ))
   done < "$TMP_OUT"
   rm -f "$TMP_OUT"

   if [ "$fail" -eq 0 ]; then
       printf 'PASS: read-only invariant held\n'
       printf 'SUMMARY: sentinel-harness.sh pass=1 fail=0\n'
       exit "$CMD_RC"
   fi

   printf 'SUMMARY: sentinel-harness.sh pass=0 fail=%d\n' "$fail"
   exit 1
   ```

   `chmod +x`.

6. **Create `tests/m029-acceptance/p02-sc5-where-mixed-state.sh`** (≥25 lines, executable, AD-19 single-script-file shape):
   - Asserts the fixture tree exists.
   - Asserts the golden file exists.
   - Captures `bash scripts/diagnostics/render-position.sh --milestone M998 --root tests/m029-acceptance/fixtures/where-mixed-state.fixture/.orchestrator` stdout to `${TMPDIR:-/tmp}/m029-sc5-actual.$$.raw`.
   - Pipes through `bash tests/m029-acceptance/timestamp-strip.sh` to produce `${TMPDIR:-/tmp}/m029-sc5-actual.$$.normalized` (script body pipe is permitted per MEM004 carve-out; the assertion line that runs the diff is straight-line bash).
   - Diffs the normalized file against `tests/m029-acceptance/fixtures/where-mixed-state.golden` via `diff -u`.
   - On byte-identity: `PASS: SC-5 byte-identity` + final `SUMMARY: p02-sc5-where-mixed-state.sh pass=N fail=0`. Exit 0.
   - On diff: emit the diff verbatim (helpful for debugging) + `FAIL: SC-5 byte-identity` + final SUMMARY. Exit 1.
   - Cleans up tempfiles on EXIT via `trap`.

7. **Create `tests/m029-acceptance/p02-sc6-where-pre-m019.sh`** (≥20 lines, executable, AD-19 single-script-file shape):
   - Asserts the pre-M019 fixture tree exists.
   - Captures `bash scripts/diagnostics/render-position.sh --milestone M997 --root tests/m029-acceptance/fixtures/where-pre-m019.fixture/.orchestrator` stdout to a tempfile and stderr to a separate tempfile (uses standard `> stdout 2> stderr` redirection — straight-line, AD-19 safe).
   - Asserts the cost column delimiter (e.g. literal `cost=` or the column header `cost`) does NOT appear in stdout.
   - Asserts stderr is byte-empty (`[ ! -s "$stderr_file" ]`).
   - On both: `PASS: SC-6 cost column suppressed` + `PASS: SC-6 stderr empty` + `SUMMARY: p02-sc6-where-pre-m019.sh pass=N fail=0`. Exit 0.
   - Cleans up tempfiles on EXIT.

8. **Create `tests/m029-acceptance/p02-sc13-anti-coupling.sh`** (≥15 lines, executable, AD-19 single-script-file shape):
   - Runs `grep -r '/integrations/github' specs/037-roadmap-visibility-cli-ux/` capturing exit code; **expects** exit 1 (no match).
   - Runs `grep -F '/integrations/github' scripts/diagnostics/render-position.sh` capturing exit code; **expects** exit 1 (no match).
   - On both no-match: `PASS: SC-13 spec anti-coupling` + `PASS: SC-13 renderer anti-coupling` + `SUMMARY: p02-sc13-anti-coupling.sh pass=N fail=0`. Exit 0.
   - Per AD-19: avoid `if grep | grep`; capture exit codes via straight `grep ...; rc=$?`.

9. **Create `tests/m029-acceptance/p02-sc14-readonly.sh`** (≥20 lines, executable, AD-19 single-script-file shape):
   - Asserts `[ -x tests/m029-acceptance/sentinel-harness.sh ]`.
   - Sets `ORCHESTRATOR_ROOT="$PWD/tests/m029-acceptance/fixtures/where-mixed-state.fixture/.orchestrator"` so the harness scans the FIXTURE tree, not the project tree (the renderer is read-only against `.orchestrator/`; SC-14 must enforce this against the fixture's tree to avoid false-positive collisions with developer state in the live `.orchestrator/`).
   - Invokes `bash tests/m029-acceptance/sentinel-harness.sh bash scripts/diagnostics/render-position.sh --milestone M998 --root "$ORCHESTRATOR_ROOT" > /dev/null`.
   - Captures the harness exit code.
   - On exit 0 (harness asserts read-only invariant held): `PASS: SC-14 read-only invariant` + `SUMMARY: p02-sc14-readonly.sh pass=N fail=0`. Exit 0.
   - On non-zero: `FAIL:` + propagate harness output + `SUMMARY: ... fail=1`. Exit 1.

10. **Author `tools/verify/m029-p02-sc5-fixtures-shape.sh`** (≥30 lines, executable, AD-19):
    - Asserts the fixture trees exist (`[ -d tests/m029-acceptance/fixtures/where-mixed-state.fixture/.orchestrator/milestones/M998 ]`, `[ -d tests/m029-acceptance/fixtures/where-pre-m019.fixture/.orchestrator/milestones/M997 ]`).
    - Asserts the golden file exists and contains all four glyphs literally (`✓ ▶ ◇ ✗`).
    - Asserts `timestamp-strip.sh` exists, is executable, and references the three #Q-G6 patterns (`<TS>`, `<RECENCY>`, `<EPOCH>` placeholders).
    - Asserts the canonical `▽ saved Nk` form does NOT appear in any P02 fixture file (the at-rest renderer never emits the savings glyph; T04 fixtures must not contain it). Asserts the verbose form `via tier1 cache reuse` does NOT appear anywhere in the fixture tree (#Q-G8).
    - Emits SUMMARY.

11. **Author `tools/verify/m029-p02-sentinel-harness-shape.sh`** (≥25 lines, executable, AD-19):
    - Asserts `[ -x tests/m029-acceptance/sentinel-harness.sh ]`.
    - Asserts the script declares the AD-9 sentinel file path literal (`.m029-sc14-sentinel`).
    - Asserts the script excludes `start-state/*.complete` (AD-9 documented exception).
    - Asserts the script invokes `find ... -newer` (the AD-9 mechanism).
    - Asserts the read-only contract token (`AD-9` or `read-only`) appears in the header.
    - Behavioral spot-check: invoke the harness against a no-op (`bash sentinel-harness.sh true`) under a temp `ORCHESTRATOR_ROOT` and assert it exits 0 with `PASS: read-only invariant held`. Use a `${TMPDIR:-/tmp}/m029-sentinel-test.$$/` temp tree containing an empty `.orchestrator/` directory.
    - Emits SUMMARY.

12. **Author `tools/verify/m029-p02-sc5-shape.sh`**, **`m029-p02-sc6-shape.sh`**, **`m029-p02-sc13-shape.sh`**, **`m029-p02-sc14-shape.sh`** (each ≥20 lines, executable, AD-19) — one shape verifier per acceptance script. Each:
    - Asserts the corresponding `tests/m029-acceptance/p02-sc##-*.sh` exists, is executable.
    - Asserts the script references the correct surfaces (e.g. SC-5 references `where-mixed-state.golden` AND `timestamp-strip.sh`; SC-13 references `/integrations/github`; SC-14 references `sentinel-harness.sh`).
    - Asserts the script emits the standard `SUMMARY: p02-sc##-*.sh pass=N fail=M` line shape.
    - **Behavioral run**: invokes the acceptance script and asserts exit 0 (full SC pass against the fixtures T04 just built). This is the load-bearing assertion that proves the fixtures actually work end-to-end.
    - Emits SUMMARY.

13. **`chmod +x` every new `.sh` file**.

## Must-Haves

This task addresses these P02 phase truths:
- The SC-5 mixed-state golden fixture covers all four glyph states and is byte-stable under the #Q-G6 enumerated timestamp-strip regex set.
- `tests/m029-acceptance/timestamp-strip.sh` enumerates exactly the #Q-G6 patterns (#Q-G6 resolution).
- The FR-8 marker canonical form `▽ saved Nk` is the only form that appears in fixtures (no `via tier1 cache reuse` anywhere) (#Q-G8 resolution).
- The SC-14 sentinel-file harness implements the AD-9 mechanism (write sentinel before read; assert no `.orchestrator/` mtime newer than the sentinel after).
- The SC-5 acceptance script renders against the mixed-state fixture, normalizes via `timestamp-strip.sh`, and diffs against the golden with exit 0.
- The SC-6 acceptance script asserts cost column omitted AND stderr empty on the pre-M019 fixture.
- The SC-13 anti-coupling guard asserts no `/integrations/github` match in spec or render path.
- The SC-14 acceptance script wraps the sentinel harness around `where` and asserts read-only invariant held.

This task creates these P02 phase artifacts:
- Mixed-state fixture tree under `tests/m029-acceptance/fixtures/where-mixed-state.fixture/`.
- Golden render at `tests/m029-acceptance/fixtures/where-mixed-state.golden`.
- Pre-M019 fixture tree under `tests/m029-acceptance/fixtures/where-pre-m019.fixture/`.
- Timestamp-strip filter at `tests/m029-acceptance/timestamp-strip.sh`.
- AD-9 sentinel harness at `tests/m029-acceptance/sentinel-harness.sh`.
- Four SC acceptance scripts at `tests/m029-acceptance/p02-sc{5,6,13,14}-*.sh`.
- Six shape verifiers at `tools/verify/m029-p02-sc5-fixtures-shape.sh`, `m029-p02-sentinel-harness-shape.sh`, `m029-p02-sc{5,6,13,14}-shape.sh`.

## Verification

```bash
bash tools/verify/m029-p02-sc5-fixtures-shape.sh
```

```bash
bash tools/verify/m029-p02-sentinel-harness-shape.sh
```

```bash
bash tools/verify/m029-p02-sc5-shape.sh
```

```bash
bash tools/verify/m029-p02-sc6-shape.sh
```

```bash
bash tools/verify/m029-p02-sc13-shape.sh
```

```bash
bash tools/verify/m029-p02-sc14-shape.sh
```

## Inputs

### From Previous Tasks

- `scripts/diagnostics/render-position.sh` (from T03)
  - Key API: `bash render-position.sh --milestone <M###> --root <fixture-orch-root>` emits the tree to stdout; `--no-cost` suppresses the cost column; `--expand-all` expands inactive milestones.
  - Key behavior: read-only against `.orchestrator/`, never invokes GitHub APIs, suppresses cost column silently on pre-M019 milestones.
- `commands/where.md` (from T03) — the orchestrator-level skill; not directly invoked by acceptance scripts (which test the engine), but referenced by SC-13's anti-coupling grep when extended.
- `scripts/diagnostics/summarize-milestone.sh` (from T02) — used transitively by T03's renderer.
- `references/cross-milestone-feature-shape.md` (from T01) — the AD-6 schema authority for fixture frontmatter shape.

### From Disk (Pre-existing)

- `tests/m029-acceptance/fixtures/` directory — created by P01 (status fixtures).
- `tests/m029-acceptance/p01-sc{1,2,3,4}-*.sh` — sibling acceptance-script shape precedents.
- `scripts/state/find-active-milestone.sh` — invoked by T03's renderer.
- M019 Tier 1 JSONL schema documentation: `record_type=dispatch_usage`, `granularity=task`, `milestone=...`, `phase=...`, `task=...`, plus the cost / quality fields enumerated in `scripts/diagnostics/metrics-rollup.sh` header (≈ lines 22–34).
- `tools/verify/m029-p01-headline-shape-contract.sh` — verifier shape precedent.

## Constraints

- **Read-only renderer (CON-1 / FR-14)**: `render-position.sh` MUST NOT mutate `.orchestrator/`. SC-14 enforces this.
- **No GitHub API (CON-4 / FR-11)**: SC-13 enforces this; T04's fixtures contain no GitHub sidecars.
- **#Q-G6 enumerated patterns**: `timestamp-strip.sh` MUST enumerate exactly the three documented regex patterns. Adding patterns silently risks under-stripping in CI; missing one causes byte-identity failures from natural drift.
- **#Q-G8 canonical marker form**: NO occurrences of `▽ saved Nk via tier1 cache reuse` ANYWHERE in T04 deliverables (fixtures, golden, scripts). The verbose form is reserved for a future `--verbose` mode.
- **AD-19 verifier shape**: every shape verifier and acceptance script MUST be straight-line bash on Check: lines. Pipes are permitted INSIDE script bodies (MEM004 carve-out — sed/awk/grep pipes are legitimate transformation tools). The constraint is that the `Check:` line invoked from the harness is a single `bash <path>` invocation.
- **Bash 3.2 (MEM001)**: NO `declare -A`, NO process substitution, NO `<<<` herestring.
- **`run-probe.sh` scope discipline (rule 4)**: tempfiles MUST live under `${TMPDIR:-/tmp}` (the staged-probe domain). NO writes outside `/tmp`, `/var/folders`, or `<repo>/tmp/`.
- **CON-7 + AD-8**: T04 introduces NO new schemas. Fixtures consume existing M019 Tier 1 / M020 / M027 schemas; T04's only schema-relevant artifact is fixture data conforming to those schemas.
- **Path-collision rule 6**: every fixture path was checked at plan-authoring time — all clean.

## Expected Output

After T04 completes:
- All fixture trees, the golden, the strip filter, the sentinel harness, and the four SC acceptance scripts are on disk and executable.
- The six shape verifiers in `tools/verify/m029-p02-sc{5,6,13,14}-shape.sh`, `m029-p02-sc5-fixtures-shape.sh`, `m029-p02-sentinel-harness-shape.sh` exit 0 from project root.
- Each acceptance script (`p02-sc5-where-mixed-state.sh`, `p02-sc6-where-pre-m019.sh`, `p02-sc13-anti-coupling.sh`, `p02-sc14-readonly.sh`) exits 0 when invoked directly.
- A summary file at [`.orchestrator/milestones/M029/phases/P02/tasks/T04-fixtures-and-sc-acceptance-SUMMARY.md`](../../../../../milestones/M029/phases/P02/tasks/T04-fixtures-and-sc-acceptance-SUMMARY.md) documents the deliverables.

## Notes

Expected verifier output:
- `m029-p02-sc5-fixtures-shape.sh`: ≈8–10 PASS lines + SUMMARY.
- `m029-p02-sentinel-harness-shape.sh`: ≈6–8 PASS lines + behavioral spot-check PASS + SUMMARY.
- `m029-p02-sc5-shape.sh`: shape PASSes + behavioral SC-5 PASS (the full byte-identical golden diff) + SUMMARY.
- `m029-p02-sc6-shape.sh`: shape PASSes + behavioral SC-6 PASS (cost column omitted + stderr empty) + SUMMARY.
- `m029-p02-sc13-shape.sh`: shape PASSes + behavioral SC-13 PASS (no `/integrations/github` matches) + SUMMARY.
- `m029-p02-sc14-shape.sh`: shape PASSes + behavioral SC-14 PASS (sentinel harness reports read-only invariant held) + SUMMARY.

The phase-suite aggregator (T05) chains all six T04 verifiers as gates 5–10.

Why the mixed-state fixture uses M998/M997 (not M029): keeping fixture milestones in the M9xx range avoids any collision with real milestones, mirrors the P01 SC-2 fixture-milestone convention (M999), and keeps the fixture tree fully self-contained under `tests/m029-acceptance/fixtures/`. The renderer's `--root` flag points it at the fixture's `.orchestrator/` so production state is never read.

Why `find -newer` rather than `stat | sort` (AD-9 mechanism choice): `find -newer <sentinel>` is a single-command AD-19-safe invocation that returns one path per line — straight to the loop. `stat | sort | diff` would chain three commands with pipes (compound-chain-gt2), tripping the harness shape-guard. The AD-9 mechanism was specifically designed around this constraint.

Why the SC-13 verifier uses TWO greps rather than one wildcard: `grep -r 'pattern' specs/ scripts/` would mix the spec directory and a single file in one invocation, but `render-position.sh` is a single file (not a tree), and combining can mask which surface had the leak. Two separate greps produce diagnostic clarity at the cost of one extra line.

## State Context

- **Current State**: executing
- **Milestone**: M029
- **Phase**: P02
- **Task**: T04-fixtures-and-sc-acceptance
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **Read-only renderer (CON-1 / FR-14)**: `render-position.sh` MUST NOT mutate `.orchestrator/`. SC-14 enforces this.
- **No GitHub API (CON-4 / FR-11)**: SC-13 enforces this; T04's fixtures contain no GitHub sidecars.
- **#Q-G6 enumerated patterns**: `timestamp-strip.sh` MUST enumerate exactly the three documented regex patterns. Adding patterns silently risks under-stripping in CI; missing one causes byte-identity failures from natural drift.
- **#Q-G8 canonical marker form**: NO occurrences of `▽ saved Nk via tier1 cache reuse` ANYWHERE in T04 deliverables (fixtures, golden, scripts). The verbose form is reserved for a future `--verbose` mode.
- **AD-19 verifier shape**: every shape verifier and acceptance script MUST be straight-line bash on Check: lines. Pipes are permitted INSIDE script bodies (MEM004 carve-out — sed/awk/grep pipes are legitimate transformation tools). The constraint is that the `Check:` line invoked from the harness is a single `bash <path>` invocation.
- **Bash 3.2 (MEM001)**: NO `declare -A`, NO process substitution, NO `<<<` herestring.
- **`run-probe.sh` scope discipline (rule 4)**: tempfiles MUST live under `${TMPDIR:-/tmp}` (the staged-probe domain). NO writes outside `/tmp`, `/var/folders`, or `<repo>/tmp/`.
- **CON-7 + AD-8**: T04 introduces NO new schemas. Fixtures consume existing M019 Tier 1 / M020 / M027 schemas; T04's only schema-relevant artifact is fixture data conforming to those schemas.
- **Path-collision rule 6**: every fixture path was checked at plan-authoring time — all clean.

### Acceptance Criteria

This task addresses these P02 phase truths:
- The SC-5 mixed-state golden fixture covers all four glyph states and is byte-stable under the #Q-G6 enumerated timestamp-strip regex set.
- `tests/m029-acceptance/timestamp-strip.sh` enumerates exactly the #Q-G6 patterns (#Q-G6 resolution).
- The FR-8 marker canonical form `▽ saved Nk` is the only form that appears in fixtures (no `via tier1 cache reuse` anywhere) (#Q-G8 resolution).
- The SC-14 sentinel-file harness implements the AD-9 mechanism (write sentinel before read; assert no `.orchestrator/` mtime newer than the sentinel after).
- The SC-5 acceptance script renders against the mixed-state fixture, normalizes via `timestamp-strip.sh`, and diffs against the golden with exit 0.
- The SC-6 acceptance script asserts cost column omitted AND stderr empty on the pre-M019 fixture.
- The SC-13 anti-coupling guard asserts no `/integrations/github` match in spec or render path.
- The SC-14 acceptance script wraps the sentinel harness around `where` and asserts read-only invariant held.

This task creates these P02 phase artifacts:
- Mixed-state fixture tree under `tests/m029-acceptance/fixtures/where-mixed-state.fixture/`.
- Golden render at `tests/m029-acceptance/fixtures/where-mixed-state.golden`.
- Pre-M019 fixture tree under `tests/m029-acceptance/fixtures/where-pre-m019.fixture/`.
- Timestamp-strip filter at `tests/m029-acceptance/timestamp-strip.sh`.
- AD-9 sentinel harness at `tests/m029-acceptance/sentinel-harness.sh`.
- Four SC acceptance scripts at `tests/m029-acceptance/p02-sc{5,6,13,14}-*.sh`.
- Six shape verifiers at `tools/verify/m029-p02-sc5-fixtures-shape.sh`, `m029-p02-sentinel-harness-shape.sh`, `m029-p02-sc{5,6,13,14}-shape.sh`.

### Files To Touch

- `references/cross-milestone-feature-shape.md` (create)
- `scripts/diagnostics/summarize-milestone.sh` (create)
- `scripts/diagnostics/render-position.sh` (create)
- `commands/where.md` (create)
- `tests/m029-acceptance/fixtures/where-mixed-state.golden` (create)
- `tests/m029-acceptance/fixtures/where-mixed-state.fixture/` (create — directory tree containing milestones/M998/...)
- `tests/m029-acceptance/fixtures/where-pre-m019.fixture/` (create — directory tree containing milestones/M997/...)
- `tests/m029-acceptance/timestamp-strip.sh` (create)
- `tests/m029-acceptance/sentinel-harness.sh` (create)
- `tests/m029-acceptance/p02-sc5-where-mixed-state.sh` (create)
- `tests/m029-acceptance/p02-sc6-where-pre-m019.sh` (create)
- `tests/m029-acceptance/p02-sc13-anti-coupling.sh` (create)
- `tests/m029-acceptance/p02-sc14-readonly.sh` (create)
- `tests/m029-acceptance/p02-acceptance-battery.sh` (create)
- `tools/verify/m029-p02-cross-milestone-shape-contract.sh` (create)
- `tools/verify/m029-p02-summarize-milestone-shape.sh` (create)
- `tools/verify/m029-p02-render-position-shape.sh` (create)
- `tools/verify/m029-p02-where-skill-shape.sh` (create)
- `tools/verify/m029-p02-sc5-fixtures-shape.sh` (create)
- `tools/verify/m029-p02-sentinel-harness-shape.sh` (create)
- `tools/verify/m029-p02-sc5-shape.sh` (create)
- `tools/verify/m029-p02-sc6-shape.sh` (create)
- `tools/verify/m029-p02-sc13-shape.sh` (create)
- `tools/verify/m029-p02-sc14-shape.sh` (create)
- `tools/verify/m029-p02-acceptance-battery-shape.sh` (create)
- `tools/verify/m029-p02-readonly-invariant.sh` (create)
- `tools/verify/m029-p02-scope-guard.sh` (create)
- `tools/verify/m029-p02-phase-suite.sh` (create)

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