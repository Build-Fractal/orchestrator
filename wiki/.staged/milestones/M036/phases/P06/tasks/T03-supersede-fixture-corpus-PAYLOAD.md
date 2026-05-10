---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T03-supersede-fixture-corpus (Phase P06, Milestone M036)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-981 | ~700 | required |
| Upstream Context | 983-1094 | ~12500 | required |
| Task Plan | 1096-1371 | ~3400 | required |
| State Context | 1373-1379 | ~100 | required |
| First-Turn Completeness | 1381-1421 | ~500 | required |
| **Total** | | **~28000** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 766
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
hit_count: 766
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
hit_count: 766
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
hit_count: 766
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
hit_count: 669
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
hit_count: 669
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
hit_count: 669
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
hit_count: 766
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
hit_count: 669
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
hit_count: 669
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
hit_count: 669
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
hit_count: 766
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
hit_count: 766
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
hit_count: 766
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
hit_count: 669
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
hit_count: 669
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
hit_count: 669
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
hit_count: 766
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
hit_count: 669
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
hit_count: 669
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
hit_count: 766
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
hit_count: 766
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
hit_count: 669
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
hit_count: 669
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
hit_count: 669
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
hit_count: 324
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
hit_count: 324
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
hit_count: 324
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
hit_count: 342
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
hit_count: 342
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
hit_count: 332
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

Land the supersede-chain authoring mechanism on top of the M036 content-hash idempotency baseline already shipped by P02 (extract driver) and P04 (ingest driver). Three load-bearing additions:

### Demo

> Operator runs extract + ingest twice on an unchanged fixture corpus and `git status knowledge/reference/` reports zero modified files (SC-5, SC-13). Operator mutates one fixture body, re-runs extract + ingest; a `REF-cat-id-v2.md` exists, the prior file's frontmatter has gained `superseded_by:`, and a `REVIEW:` line surfaces for any spec/memory chunk that cites the prior version (SC-6).

### Must-Haves
## Must-Haves

### Truths

- `scripts/knowledge/extract-reference.sh` declares the supersede authoring branch (writes versioned successor + `superseded_by:` lineage) and the `SUPERSEDED:` stdout protocol on content-hash mismatch.
  - Check: `bash tools/verify/m036-p06-extract-supersede-shape.sh`
- `scripts/knowledge/lib/extract-supersede.sh` defines `supersede_find_chain_tip()`, `supersede_next_version()`, and `supersede_amend_prior_chunk()` as a pure-lib MEM004 helper (no top-level execution).
  - Check: `bash tools/verify/m036-p06-extract-supersede-helper-shape.sh`
- A mutated source body re-extracted produces a `-v2.md` successor file, the prior chunk gains `superseded_by:`, and re-running on the now-mutated source emits SKIPPED (idempotency restored).
  - Check: `bash tools/verify/m036-p06-supersede-chain-end-to-end.sh`
- `scripts/knowledge/ingest-reference.sh` declares the `REVIEW:` emission pass and sources `lib/ingest-review-advisory.sh`.
  - Check: `bash tools/verify/m036-p06-ingest-review-shape.sh`
- `scripts/knowledge/lib/ingest-review-advisory.sh` defines `review_emit_for_superseded_chunks()` and `review_emit_for_removed_chunks()` and invokes `traverse-graph.sh --reverse --edge-types cites`.
  - Check: `bash tools/verify/m036-p06-ingest-review-helper-shape.sh`
- A reference corpus containing a chunk with `superseded_by:` frontmatter plus a spec chunk declaring `cites: [<prior-chunk-id>]` produces a `REVIEW:` line in ingest stdout naming the citer, the superseded target, and the chain tip.
  - Check: `bash tools/verify/m036-p06-review-emission-end-to-end.sh`
- The opt-in `--detect-removals` flag emits `REMOVED:` + `REVIEW:` lines for chunks whose source disappeared between ingests.
  - Check: `bash tools/verify/m036-p06-removed-detection-end-to-end.sh`
- The supersede-corpus fixtures and the manifest fixture exist on disk with the expected shape (V1 + mutated + citer-spec).
  - Check: `bash tools/verify/m036-p06-fixture-corpus-shape.sh`

<dispatch-volatile>

## Upstream Context


### P02 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P02"
parent: "M036"
milestone: "M036"
provides:
  - "references/extract-manifest-contract.md (M036 SSOT manifest contract — top-level + per-document field declarations + 3-mode summary enum + default-tier-resolution table + tier output layout + idempotency + cross-references); tests/fixtures/m036/extract-manifest.yaml (3-doc fixture manifest covering cms-rule + training-material + glossary at summary_mode=operator); tests/fixtures/m036/sample.md (synthetic glossary fixture); tests/fixtures/m036/sample.pdf + sample.docx (byte-copies of P01 Tier 1 fixtures); .gitignore _originals/ entry per CON-7 (b); 3 single-script-file shape verifiers (m036-p02-manifest-contract-shape.sh,m036-p02-fixture-manifest-shape.sh,m036-p02-fixture-corpus-shape.sh),scripts/knowledge/lib/extract-manifest.sh (pure manifest parser: extract_manifest_top_field,extract_manifest_doc_count,extract_manifest_doc_field,extract_manifest_resolve_tier — no top-level I/O,MEM004 pure-lib pattern); scripts/knowledge/lib/extract-binary-preservation.sh (pure helpers: preservation_sha256 with shasum/sha256sum probe fallback,preservation_size_bytes,preservation_copy_under_originals idempotent via sha256 match,preservation_above_cap,preservation_external_pointer_shape emitting file:// URI); scripts/knowledge/extract-reference.sh (driver — sources both T02 helpers + T03 lib/extract-tier-0-summary.sh,accepts --manifest/--reference-root/--originals-root/--summary-mode/--size-cap-bytes flags,iterates documents,computes content_hash,gates on prior content_hash for idempotency,preserves binaries under <originals-root>/<source>/<basename> OR records external_pointer when above cap,emits Tier 0 chunk frontmatter + body,dispatches Tier 1 via T03's extract_tier_1_via_registry helper,emits EXTRACTED:/SKIPPED: stdout contract); 4 verifiers under tools/verify/ (m036-p02-extract-driver-shape.sh — 10 checks: 3 file existence+executable + 7 token-presence; m036-p02-binary-preservation.sh — host-aware: SKIP on pdftotext/pandoc-absent,else 3 byte-identity checks; m036-p02-content-hash.sh — host-aware: SKIP on pdftotext/pandoc-absent,else 3 hash-equality checks; m036-p02-size-cap-external-pointer.sh — markdown-only with cap=1,asserts external_pointer present + binary not copied),scripts/knowledge/lib/extract-tier-0-summary.sh (pure helpers — generate_tier_0_summary <mode> <category> <cite_id> <operator-summary> <tier> with operator|stub|auto modes; extract_tier_1_via_registry <src> <out> <registry> resolving md|pdf|docx|xlsx → adapter via registry.tsv awk lookup,with xlsx multi-output --out-dir contract + marker file; sourced by scripts/knowledge/extract-reference.sh; no top-level I/O per MEM004); commands/extract.md (~80 lines — Prerequisites + Inputs + Output + Idempotency + Error Handling + Referenced Scripts + Reference Files sections; declares EXTRACTED:/SKIPPED: stdout protocol; documents --manifest/--reference-root/--originals-root/--summary-mode/--size-cap-bytes flags; explicitly defers Tier 2 + summary_mode:auto to P03); 6 verifiers under tools/verify/m036-p02-* (extract-md.sh — markdown floor end-to-end,no host-dep,4 checks; extract-pdf-host-aware.sh — host-aware SKIP on pdftotext-absent,2 checks when present; extract-docx-host-aware.sh — host-aware SKIP on pandoc-absent,2 checks when present; extract-command-shape.sh — 9 token-presence checks against commands/extract.md using grep -qF -e form for leading-dash safety; summary-mode-stub-vs-operator.sh — drives driver twice with different summary_modes,asserts both bodies present and distinct; tier-2-deferred-error.sh — asserts tier:2 + summary_mode:auto exits non-zero with stderr naming both 'P03' and 'not implemented'),tests/test-tier-0-manifest.sh (SC-10 end-to-end acceptance harness — drives extract-reference.sh against the 3-doc fixture manifest in a mktemp -d workspace; per-doc host-tooling-aware SKIP for PDF/DOCX; asserts EXTRACTED on first run,SKIPPED on second run,frontmatter shape per chunk,byte-identical originals; emits BATTERY: pass=N fail=N skip=N as the last stdout line; exit 0 iff fail=0); tools/verify/m036-p02-idempotency.sh (CON-4/FR-9 idempotency contract verifier — drives the driver into two fresh workspaces and diff -qr asserts byte-identical trees; then re-runs against an existing tree and asserts SKIPPED emission; markdown-only fixture so always-runnable on bare hosts); tools/verify/m036-p02-test-harness.sh (harness-shape verifier — asserts the SC-10 harness exists,executable,ran-to-completion (rc<=1),and emitted a well-formed BATTERY: line; permissive on per-doc PASS/SKIP counts so host-tooling absence does not false-FAIL); tools/verify/m036-p02-phase-suite.sh (15-gate aggregator wiring 13 prior P02 sub-gates plus the two T04 verifiers; patterned after m036-p01-phase-suite.sh — run helper inspects exit code only so SKIP-emitting sub-gates report PASS at the aggregator level)"
requires:
  - "P00,P01"
affects:
  - "P03,P04,P06"
key_files:
  - "references/extract-manifest-contract.md,tests/fixtures/m036/extract-manifest.yaml,tests/fixtures/m036/sample.md,tests/fixtures/m036/sample.pdf,tests/fixtures/m036/sample.docx,tools/verify/m036-p02-manifest-contract-shape.sh,tools/verify/m036-p02-fixture-manifest-shape.sh,tools/verify/m036-p02-fixture-corpus-shape.sh,.gitignore,scripts/knowledge/extract-reference.sh,scripts/knowledge/lib/extract-manifest.sh,scripts/knowledge/lib/extract-binary-preservation.sh,tools/verify/m036-p02-extract-driver-shape.sh,tools/verify/m036-p02-binary-preservation.sh,tools/verify/m036-p02-content-hash.sh,tools/verify/m036-p02-size-cap-external-pointer.sh,scripts/knowledge/lib/extract-tier-0-summary.sh,commands/extract.md,tools/verify/m036-p02-extract-md.sh,tools/verify/m036-p02-extract-pdf-host-aware.sh,tools/verify/m036-p02-extract-docx-host-aware.sh,tools/verify/m036-p02-extract-command-shape.sh,tools/verify/m036-p02-summary-mode-stub-vs-operator.sh,tools/verify/m036-p02-tier-2-deferred-error.sh,tests/test-tier-0-manifest.sh,tools/verify/m036-p02-idempotency.sh,tools/verify/m036-p02-test-harness.sh,tools/verify/m036-p02-phase-suite.sh"
key_decisions:
  - "none"
patterns_established:
  - "P02 inherits the M036 verifier conventions intact: milestone-prefixed slug (m036-p02-*),AD-19 single-script-file shape,grep -qF token-loop body,structured PASS:/FAIL:/SUMMARY: stdout,set -eu strict,ROOT resolution via ${ORCHESTRATOR_ROOT:-$(pwd)}; fixture-binary reuse pattern (P01 PDF + DOCX byte-copied into P02 fixture dir avoids re-authoring fragile minimal binaries — both already exercised by P01 host-aware verifiers); manifest-contract SSOT lockstep declared at file head (Principle XI cross-reference paragraph naming the two consumers — driver + lib helper — with the explicit lockstep-update rule for any field change),Pure-lib extraction pattern (MEM004) carried into M036 P02: manifest parsing + binary preservation factored into sourceable helper libs under scripts/knowledge/lib/; driver scripts/knowledge/extract-reference.sh sources both + T03's lib/extract-tier-0-summary.sh and orchestrates per-doc work; helpers take args + emit to stdout / exit code only — no top-level I/O so they sourceable safely; AD-19 single-script-file shape for driver invocation (`bash scripts/knowledge/extract-reference.sh --manifest ...`) — internal grep|head|sed and awk pipelines are legal inside the script body because the classifier inspects only the *invocation* form (M036/P00/T03's MEM031 'validator-internal pipeline classifier-shape pass-through' pattern); idempotency via content_hash gate (driver reads existing chunk's `content_hash:` frontmatter; SHA-256 match → SKIPPED:,mismatch → re-emit); binary-preservation idempotency via sha256-match-then-skip in preservation_copy_under_originals (no redundant cp when source unchanged); shasum/sha256sum probe-and-fallback for cross-platform sha256 (BSD-macOS / GNU-Linux); cross-task verifier dependency pattern documented under Plan-Time Discipline rule 2 (T02's behavioural verifiers exercise properties that need T03's helper — verifiers authored in T02 alongside the driver they test,become green only after T03 lands the helper the driver sources; auto-loop's first-fail-retry handles ordering at execute time); host-tooling-aware SKIP carried from M036/P01 verifiers (probe `command -v pdftotext|pandoc` → emit `SKIP: <tool>-absent` + exit 0 informationally so aggregator counts as PASS); grep -F flag-safety: `grep -qF -e \$pat\` form required so token strings starting with `-` (e.g.,`--manifest`) are not misinterpreted as flags by grep; `grep -qF \$pat\` is unsafe for any pattern that may begin with a dash (caught during T02 first-run verification,fix carried into the m036-p02-extract-driver-shape.sh checkpat helper),Registry-driven Tier 1 dispatch pattern (extension → registry.tsv awk-lookup → adapter path → invocation): the driver delegates ALL Tier 1 host-tool knowledge to the format adapters (P01) via the registry table (P00); extract_tier_1_via_registry holds zero per-format logic beyond the extension→fmt label mapping; new formats land entirely as new registry rows + adapters with no driver edits required; xlsx-style multi-output adapters get a marker-file convention (text-output-path holds a pointer line referencing the per-sheet CSV directory) preserving the single-text-output-path contract that downstream chunks key on; cross-task ordering pattern carried from T02 (T02's behavioural verifiers exercise properties needing T03's helper — verifiers authored in T02 alongside the driver they test,become green only after T03 lands the helper the driver sources; auto-loop's first-fail-retry handles ordering at execute time); grep flag-safety carried into all 6 T03 verifiers — grep -qF -e \$pat\ form so leading-dash tokens like '--manifest' are not misinterpreted as flags (initial author of m036-p02-extract-command-shape.sh used grep -qF \$pat\ and hit BSD-grep flag-rejection during first run; corrected mid-task); Tier 2 / summary_mode:auto deferred-error pattern — auto mode in P02 hard-errors with stderr naming the future phase ('P03') and the actionable hint ('not implemented' + 'use summary_mode: operator or stub instead'); makes the seam to P03 explicit and gives operators an actionable error rather than a silent fall-through,BATTERY: pass=N fail=N skip=N output contract reused from M036 P01 (machine-parseable single line at last stdout line; consumers grep ^BATTERY: pass=[0-9]+ fail=[0-9]+ skip=[0-9]+$; exit 0 iff fail=0 regardless of skip count); two-tier idempotency-contract pattern (1) byte-identical-tree across two fresh workspaces via diff -qr REF1 REF2 + diff -qr ORIG1 ORIG2 (2) re-run-against-existing-tree emits SKIPPED rather than EXTRACTED — the second contract is what content-hash gating actually buys; per-doc host-tooling-aware SKIP at harness layer (PDF + DOCX docs SKIP if pdftotext/pandoc absent; markdown doc always runs; harness emits SKIP: <doc> (<tool>-absent) lines for the operator-readable trail and increments skip counter without contributing to fail); markdown-only fallback sub-manifest emitted via heredoc inside mktemp -d workspace when host tooling incomplete (preserves end-to-end coverage of the markdown-floor path even on bare hosts; format-agnostic idempotency contract is gated even when other formats SKIP); permissive harness-shape verifier (rc <=1 acceptable since rc=1 is fail-mode-but-still-emitted-BATTERY whereas rc=2+ would be syntax/abort — captures shape contract without coupling to per-doc pass count); 15-gate aggregator pattern reuse (m036-p01-phase-suite.sh used as template — same set -eu + run helper redirecting both stdout+stderr to /dev/null + SUMMARY: line format; sub-gate exit code is the only signal; SKIP-internal verifiers exit 0 informationally so they report PASS at aggregator level)"
drill_down_paths:
  - "[.orchestrator/milestones/M036/phases/P02/tasks/T01-manifest-contract-and-fixtures-SUMMARY.md](../../../../../milestones/M036/phases/P02/tasks/T01-manifest-contract-and-fixtures-SUMMARY.md), [.orchestrator/milestones/M036/phases/P02/tasks/T02-driver-and-preservation-SUMMARY.md](../../../../../milestones/M036/phases/P02/tasks/T02-driver-and-preservation-SUMMARY.md), [.orchestrator/milestones/M036/phases/P02/tasks/T03-summary-and-command-doc-SUMMARY.md](../../../../../milestones/M036/phases/P02/tasks/T03-summary-and-command-doc-SUMMARY.md), [.orchestrator/milestones/M036/phases/P02/tasks/T04-acceptance-harness-and-aggregator-SUMMARY.md](../../../../../milestones/M036/phases/P02/tasks/T04-acceptance-harness-and-aggregator-SUMMARY.md)"
duration: "80m"
verification_result: "pass"
completed_at: "2026-05-02T14:57:13Z"
observability_surfaces:
  - "none"
---

P02 (Tier 0 manifest + `orchestrator:extract` command + binary preservation) lands the synchronous Tier 0/Tier 1 path of the M036 reference-corpus extraction pipeline. Operators run `bash scripts/knowledge/extract-reference.sh --manifest tests/fixtures/m036/extract-manifest.yaml`; for each declared document the driver computes a SHA-256 content hash, preserves the original binary under `_originals/<source>/<filename>` (or records an `external_pointer` URI when above the size cap per CON-7), generates a Tier 0 chunk with category-default-tier-aware frontmatter and a body whose summary comes from operator-supplied text (`summary_mode: operator`) or a deterministic stub line (`summary_mode: stub`); Tier 1 plain-text extraction shells out to the per-format P01 adapters via a registry awk-lookup. Idempotency: re-runs against an existing tree emit `SKIPPED:` lines and produce byte-identical output. Tier 2 (`summary_mode: auto`) hard-errors with an actionable message naming P03.

**What was built across T01–T04**:

- **T01** — Manifest contract SSOT (`references/extract-manifest-contract.md`) declaring top-level `version` + `documents:` array + per-document fields (`cite_id`, `path`, `category`, `tier`, `summary_mode` enum {operator|stub|auto}, optional `tags`, optional `version`) + default-tier-resolution table sourcing per-category defaults from `references/reference-source-types.yaml`. 3-doc fixture manifest at `tests/fixtures/m036/extract-manifest.yaml` covering cms-rule + training-material + glossary at summary_mode operator. Three fixture documents (synthetic markdown + byte-copies of P01 sample.pdf + sample.docx — re-using P01's host-aware-tested binaries avoids re-authoring fragile minimal binaries). `.gitignore` `_originals/` line per CON-7 (b). Three single-script-file shape verifiers landing the contract gates.

- **T02** — Driver `scripts/knowledge/extract-reference.sh` (Bash 3.2; sources both helper libs and T03's tier-0-summary helper; iterates documents; idempotent via content_hash gate). Two pure helper libs: `lib/extract-manifest.sh` (manifest parsers — `extract_manifest_top_field`, `extract_manifest_doc_count`, `extract_manifest_doc_field`, `extract_manifest_resolve_tier`) and `lib/extract-binary-preservation.sh` (preservation helpers — sha256 with shasum/sha256sum probe-fallback, size_bytes, copy-under-originals with sha256-match idempotency, above_cap predicate, external_pointer file:// URI shape). Four verifiers: driver-shape (10 token-presence checks), binary-preservation (host-aware SKIP), content-hash (host-aware SKIP), size-cap-external-pointer (markdown-only with cap=1 — exercises external_pointer + binary-not-copied properties without host tools).

- **T03** — Tier-0 summary + Tier 1 registry-dispatch helper `scripts/knowledge/lib/extract-tier-0-summary.sh` (`generate_tier_0_summary` with operator|stub|auto modes; auto hard-errors naming P03; `extract_tier_1_via_registry` resolves md|pdf|docx|xlsx → adapter via registry.tsv awk-lookup with xlsx multi-output marker-file contract). `commands/extract.md` (~80 lines, 6 standard headings + EXTRACTED:/SKIPPED: stdout protocol + flags doc + Tier 2 deferral note). Six T03 verifiers: extract-md (markdown floor, no host-dep), extract-pdf-host-aware + extract-docx-host-aware (probe-and-SKIP cascade), extract-command-shape (9 token checks against extract.md), summary-mode-stub-vs-operator (drives driver twice, asserts distinct bodies), tier-2-deferred-error (asserts tier:2 + summary_mode:auto exits non-zero with stderr naming both 'P03' and 'not implemented').

- **T04** — SC-10 acceptance harness `tests/test-tier-0-manifest.sh` (drives the driver against the 3-doc manifest in a mktemp -d workspace; per-doc host-tooling-aware SKIP for PDF/DOCX; asserts EXTRACTED on first run, SKIPPED on second run, frontmatter shape per chunk, byte-identical originals; emits `BATTERY: pass=N fail=N skip=N` last-stdout-line; exit 0 iff fail=0). Idempotency verifier (CON-4/FR-9 contract — diff -qr byte-identical trees across two fresh workspaces + re-run-emits-SKIPPED). Test-harness shape verifier (permissive on rc<=1 since rc=1 is fail-mode-but-still-emitted-BATTERY). 15-gate phase-suite aggregator at `tools/verify/m036-p02-phase-suite.sh` wiring all P02 sub-gates.

**Mid-phase corrections**:

- **T02 cross-task ordering**: `m036-p02-size-cap-external-pointer.sh` was authored in T02 but exercises a property that requires T03's `lib/extract-tier-0-summary.sh` helper (the driver sources it). The verifier failed at T02-time and went green retroactively after T03 landed. Documented as `verification_result: done_with_concerns` at T02-close with explicit citation to the cross-task ordering note in the plan; confirmed PASS at T03 close. The auto-loop's DONE_WITH_CONCERNS handling per US3 AS6 (observational concerns proceed) carried the loop forward without manual intervention.
- **`grep -qF` flag-safety**: T02's `m036-p02-extract-driver-shape.sh` checkpat helper used `grep -qF "$pat"` which BSD-grep on macOS misinterprets when `$pat` starts with `--` (e.g., `--manifest`). Corrected to `grep -qF -e "$pat"`. Same fix applied to T03's `m036-p02-extract-command-shape.sh`. Pattern recorded under `patterns_established` for future P02-style verifiers.
- **Phase-suite aggregator off-by-one**: the T04 plan docstring said "16 sub-gates" but the per-gate enumeration only listed 15 entries (3 from T01 + 4 from T02 + 6 from T03 + 2 from T04). Authored aggregator with the 15 sub-gates that are on disk; corrected docstring + SUMMARY narrative to read 15. Descriptive defect only.

**Verification**: P02 phase-suite aggregator reports `SUMMARY: m036-p02-phase-suite.sh pass=15 fail=0` end-to-end. SC-10 acceptance harness reports `BATTERY: pass=8 fail=0 skip=1` on the dev host (pdftotext present, pandoc absent → DOCX leg SKIPs). All four task-summary files on disk with full task-summary frontmatter contract. External mods PASS (`phase-transition.sh` external-mod check clean). Roadmap sync OK.

**Forward notes**:

- **P03** (Tier 2 LLM extraction + [M030](../../../../../milestones/M030/index.md) routing + conversus fidelity gate) consumes P02's `extract_tier_1_via_registry` helper and the `summary_mode: auto` deferred-error seam: P03 implements the auto branch by calling M030 routing + conversus gate, replacing the current "P03 not implemented" hard-error with a real Tier 2 extraction path. P03's structured-output writer lands beside the existing chunk under `<cite_id>.structured.md` per the spec.
- **P04** (ingest layer) consumes the extraction outputs + the chunk frontmatter shape established here (manifest entry + content_hash + tier label + binary-preservation pointer) as input to the chunk classifier.
- **P06** (idempotent re-extract + re-ingest + supersede chain) builds on the content-hash idempotency gate established in P02's driver. The `version: <vN>` optional field in the manifest contract is the seam P06 will leverage to author supersede chains; P02 declares the field but doesn't yet implement chain-following.
- **Pure-lib factoring (MEM004)**: the `scripts/knowledge/lib/extract-*` helpers carry pure-function discipline (args-in / stdout+exit-out / no top-level I/O) into M036's surface. P03+ helper libs should follow the same shape.
- **Registry-driven Tier 1 dispatch**: the driver holds zero per-format logic — new formats land entirely as new `registry.tsv` rows + adapters with no driver edits. P03's Tier 2 path follows the same delegation pattern (Tier 2 model registration in M030's task-type ledger, no driver-side model knowledge).


### P04 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P04"
parent: "M036"
milestone: "M036"
provides:
  - "tests/fixtures/m036-p04-reference-corpus/cms-rule/REF-cms-rule-fixture-01.md (cms-rule taxonomy fixture,tier 2,full FR-2 frontmatter); tests/fixtures/m036-p04-reference-corpus/cms-rule/REF-cms-rule-fixture-02.md (second cms-rule fixture,distinct content_hash); tests/fixtures/m036-p04-reference-corpus/training-material/REF-training-material-fixture-01.md (training-material taxonomy fixture,tier 2); tests/fixtures/m036-p04-reference-corpus/training-material/REF-training-material-fixture-02.md (second training-material fixture,distinct content_hash); tests/fixtures/m036-p04-reference-corpus/glossary/REF-glossary-fixture-01.md (glossary taxonomy fixture,tier 2); tests/fixtures/m036-p04-reference-corpus/regulatory-doc/REF-regulatory-doc-fixture-01.md (regulatory-doc taxonomy fixture,tier 1 per per-category default); tests/fixtures/m036-p04-reference-corpus/_negative/unknown-category/REF-blog-post-fixture.md (FR-1 taxonomy-rejection negative — category=blog-post outside the closed M036 taxonomy); tests/fixtures/m036-p04-reference-corpus/_negative/missing-source/REF-cms-rule-no-source.md (FR-2 required-field-rejection negative — source: field omitted); tests/fixtures/m036-p04-reference-corpus/_negative/tier-2-block/REF-cms-rule-blocked.md (FR-18 BLOCK-retention negative — tier_2_verdict: BLOCK frontmatter declared); scripts/knowledge/classify-reference.sh (~80-line pure helper lib per MEM004 — no top-level execution; sourceable; exposes classify_reference_required_fields(chunk-file) returning 0 if all six FR-2 required fields present + 1 with stderr error naming missing fields,and classify_reference_file(chunk-file) composing the FR-2 required-field check with bash-shelling-out to the existing P00 T03 tools/verify/lib/p00-validate-chunk-frontmatter.sh validator for the FR-1 taxonomy + tier-enum check; ROOT resolution via ${ORCHESTRATOR_ROOT:-$(cd $(dirname $0)/../.. && pwd)} for sourceable-from-anywhere support); 4 single-script-file shape verifiers under tools/verify/m036-p04-* (m036-p04-classifier-shape.sh — 7 checks: existence + executable + 5 token-presence on classify_reference_required_fields()/classify_reference_file()/p00-validate-chunk-frontmatter.sh/the FR-2 six-field list/MEM004; m036-p04-classifier-rejects-unknown.sh — sources the lib + drives classify_reference_file against the unknown-category negative fixture asserting rc=1 + stderr names taxonomy; m036-p04-classifier-rejects-missing-required.sh — sources the lib + drives classify_reference_required_fields against the missing-source negative fixture asserting rc=1 + stderr names source; m036-p04-fixture-corpus-shape.sh — 16 checks: 9 file-existence asserts + 5 frontmatter spot-checks on the cms-rule sample + 1 BLOCK-fixture tier_2_verdict declaration; AD-19 single-script-file shape,set -eu strict,grep -qF -e leading-dash-safe token-loops,ROOT resolution via ${ORCHESTRATOR_ROOT:-$(pwd)},structured PASS:/FAIL:/SUMMARY: stdout),scripts/knowledge/ingest-reference.sh (~150-line driver; Bash 3.2 / POSIX-sh per CON-2; sources scripts/knowledge/classify-reference.sh; parses --reference-root <path> + --no-index-rebuild flags; walks <root>/<category>/REF-*.md across the four taxonomy categories cms-rule|training-material|glossary|regulatory-doc; per-file delegates FR-1+FR-2 validation to classify_reference_file; emits CREATED:/SKIPPED:/REJECTED:/BLOCKED:/SUMMARY: structured stdout per MEM001; idempotency gate via content_hash frontmatter vs body sha256 with shasum/sha256sum probe-and-fallback; FR-18 BLOCK gate emits BLOCKED: + asserts absence of .structured.md sibling + does NOT emit CREATED for blocked chunks; partial-success ingest — per-chunk REJECTED does not abort the pass; invokes scripts/knowledge/rebuild-index.sh at end unless --no-index-rebuild passed; backwards-compat green path returns SUMMARY: ... created=0 skipped=0 rejected=0 blocked=0 (no reference corpus configured) when REF_ROOT directory does not exist; CON-1 preservation); scripts/knowledge/rebuild-index.sh (modified — additive amendment to basename-filter case block: extended MEM*|SPEC-* → MEM*|SPEC-*|REF-* AND added *.text|*.structured exclusion branch above to skip extraction-artifact siblings; all other behavior — file-discovery glob at line 66 + fm_field reads + edge-insertion paths for cites/derived_from/applies_to_field at lines 145+ — byte-identical pre/post per CON-5); 3 single-script-file shape verifiers under tools/verify/m036-p04-* (m036-p04-driver-shape.sh — 12 checks: existence+executable + 10 token-presence on flags --reference-root/--no-index-rebuild + stdout-protocol prefixes CREATED:/SKIPPED:/REJECTED:/BLOCKED:/SUMMARY: ingest-reference.sh + sourced-helper-name classify-reference.sh + invoked-helper-name rebuild-index.sh + idempotency-field content_hash; m036-p04-rebuild-index-recognizes-ref.sh — 2 checks asserting MEM*|SPEC-*|REF-* widened pattern + *.text|*.structured exclusion both present in rebuild-index.sh; m036-p04-idempotency.sh — CON-4 contract verifier: stages 4 taxonomy fixture-corpus categories into mktemp -d workspace + snapshots tree before run 1 + drives driver twice with --no-index-rebuild + snapshots tree after run 2 + diff -q snapshots assert byte-identical; trap rm -rf cleanup on EXIT; AD-19 single-script-file shape; Bash 3.2; structured PASS:/FAIL:/SUMMARY: stdout),commands/ingest-reference.md (~60-line operator-facing command document following commands/extract.md structural template; declares M036-canonical CREATED:/SKIPPED:/REJECTED:/BLOCKED:/SUMMARY: stdout protocol; documents --reference-root and --no-index-rebuild flags; surfaces FR-18 BLOCK retention contract and partial-success ingest semantics; per MEM012 Command File Structure with Prerequisites + Inputs + Output + Idempotency + Error Handling + Referenced Scripts + Reference Files sections); tools/verify/m036-p04-tier-2-block-not-promoted.sh (FR-18 BLOCK retention contract Truth verifier; stages BLOCK fixture under cms-rule/ in mktemp -d workspace so the driver taxonomy walker actually picks it up; asserts driver exit 0 + BLOCKED stdout with reason=tier-2-fidelity-gate + no CREATED line for blocked chunk_id + no .structured.md sibling promoted; AD-19 single-script-file shape; Bash 3.2); tools/verify/m036-p04-p05-regression-pass.sh (P05 8-gate phase-suite regression guard re-running tools/verify/m036-p05-phase-suite.sh and asserting SUMMARY line still reports fail=0; confirms P04 rebuild-index.sh edits do not perturb P05 edge-insertion paths); tools/verify/m036-p04-command-shape.sh (token-presence verifier for commands/ingest-reference.md with 14 grep -qF -e checks against canonical section headings + flag names + stdout-protocol prefixes + driver basename + FR-18 reference); tools/verify/lib/p00-validate-chunk-frontmatter.sh modified (sed pipeline extended to additionally strip surrounding single OR double quotes from CATEGORY/TIER scalar values; mid-task correction surfaced when T03 became the first M036/P04 verifier to drive the full ingest path against a real fixture),tests/test-reference-ingest-fixture.sh (SC-1+SC-2 acceptance harness; ~120 lines; AD-19 single-script-file shape; Bash 3.2; drives ingest-reference.sh against a workspace-copy of the m036-p04-reference-corpus fixture; emits BATTERY: pass=N fail=N skip=N as last stdout line; asserts SC-1.1 driver-rc=0 + SC-1.2 SUMMARY-line-reports-created=6 + SC-1.3..SC-1.8 per-chunk CREATED stdout for each of the 6 valid taxonomy fixtures + SC-2.1..SC-2.6 byte-equality between fixture sources and on-disk staged copies + CON-4 re-run-rc=0; exit 0 iff fail=0; trap-cleanup of mktemp -d workspace; stages only the four taxonomy-category subdirs not the negative dir so the SC-1+SC-2 contract isolates clean from the negative-path verifiers); tools/verify/m036-p04-test-harness.sh (permissive harness-shape verifier; rc<=1 acceptable since rc=1 still emits BATTERY in fail mode whereas rc=2+ would be syntax/abort; asserts harness exists+executable+well-formed BATTERY last line); tools/verify/m036-p04-acceptance-harness-passes.sh (strict pass-rate gate complementing the permissive shape verifier; asserts harness exit 0 specifically; permissive+strict gate split lets the phase-suite independently fail on harness-machinery-broken vs harness-ran-but-found-regressions); tools/verify/m036-p04-p02-regression-pass.sh (selective-gate-list regression verifier carrying the M036/P03/T03 m036-p03-p02-regression-pass.sh pattern verbatim; explicitly enumerates 14 of the 15 P02 sub-gates excluding m036-p02-tier-2-deferred-error.sh whose semantics intentionally flipped at P03 close when P03 implemented the Tier 2 path that P02 deferred; declarative which gate is excluded and why); tools/verify/m036-p04-phase-suite.sh (M036 P04 13-gate phase-suite aggregator wiring all P04 sub-gates: T01 classifier-shape + classifier-rejects-unknown + classifier-rejects-missing-required + fixture-corpus-shape; T02 driver-shape + rebuild-index-recognizes-ref + idempotency; T03 command-shape + tier-2-block-not-promoted + p05-regression-pass; T04 test-harness + acceptance-harness-passes + p02-regression-pass; patterned after m036-p03-phase-suite.sh; run helper inspects exit code only; SUMMARY: m036-p04-phase-suite.sh pass=13 fail=0 on clean run)"
requires:
  - "P02,P03"
affects:
  - "P06,P07,P08"
key_files:
  - "tests/fixtures/m036-p04-reference-corpus/cms-rule/REF-cms-rule-fixture-01.md,tests/fixtures/m036-p04-reference-corpus/cms-rule/REF-cms-rule-fixture-02.md,tests/fixtures/m036-p04-reference-corpus/training-material/REF-training-material-fixture-01.md,tests/fixtures/m036-p04-reference-corpus/training-material/REF-training-material-fixture-02.md,tests/fixtures/m036-p04-reference-corpus/glossary/REF-glossary-fixture-01.md,tests/fixtures/m036-p04-reference-corpus/regulatory-doc/REF-regulatory-doc-fixture-01.md,tests/fixtures/m036-p04-reference-corpus/_negative/unknown-category/REF-blog-post-fixture.md,tests/fixtures/m036-p04-reference-corpus/_negative/missing-source/REF-cms-rule-no-source.md,tests/fixtures/m036-p04-reference-corpus/_negative/tier-2-block/REF-cms-rule-blocked.md,scripts/knowledge/classify-reference.sh,tools/verify/m036-p04-classifier-shape.sh,tools/verify/m036-p04-classifier-rejects-unknown.sh,tools/verify/m036-p04-classifier-rejects-missing-required.sh,tools/verify/m036-p04-fixture-corpus-shape.sh,scripts/knowledge/ingest-reference.sh,scripts/knowledge/rebuild-index.sh,tools/verify/m036-p04-driver-shape.sh,tools/verify/m036-p04-rebuild-index-recognizes-ref.sh,tools/verify/m036-p04-idempotency.sh,commands/ingest-reference.md,tools/verify/m036-p04-tier-2-block-not-promoted.sh,tools/verify/m036-p04-p05-regression-pass.sh,tools/verify/m036-p04-command-shape.sh,tools/verify/lib/p00-validate-chunk-frontmatter.sh,tests/test-reference-ingest-fixture.sh,tools/verify/m036-p04-test-harness.sh,tools/verify/m036-p04-acceptance-harness-passes.sh,tools/verify/m036-p04-p02-regression-pass.sh,tools/verify/m036-p04-phase-suite.sh"
key_decisions:
  - "none"
patterns_established:
  - "P04 inherits the M036 verifier conventions intact: milestone-prefixed slug (m036-p04-*),AD-19 single-script-file shape,grep -qF -e token-loop body for leading-dash safety,structured PASS:/FAIL:/SUMMARY: stdout,set -eu strict,ROOT resolution via ${ORCHESTRATOR_ROOT:-$(pwd)}; pure-lib MEM004 pattern carried into the classifier surface (classify-reference.sh has only function definitions — classify_reference_required_fields + classify_reference_file — no top-level execution; safe to source from any context including the future ingest-reference.sh driver and the _rejects-* verifiers); two-tier classifier composition pattern (FR-2 required-field presence check authored locally as a fast pre-pass + delegation to the existing P00 T03 tools/verify/lib/p00-validate-chunk-frontmatter.sh for the FR-1 taxonomy + tier-enum check — preserves single-source-of-truth for taxonomy lookup and avoids duplicating the cms-rule|training-material|glossary|regulatory-doc list in two places); _negative/<reason>/ subdirectory naming convention for ergonomically co-locating rejection-path fixtures with the positive corpus (T02's driver scans only top-level taxonomy-category subdirectories so _negative/ is silently skipped on positive-pass walks while remaining trivially addressable by per-rejection-mode verifiers); REF-* chunk frontmatter shape pre-bakes both id: and chunk_id: fields equal to REF-<category>-<cite_id> so rebuild-index.sh::fm_field can pick the chunk up unambiguously when the index extension lands later in the phase; full M036 chunk-frontmatter contract represented in fixtures (schema_version + type + milestone + id + category + chunk_id + cite_id + source + published + version + tier + content_hash + size_bytes + summary_mode + topic_tags + applies_to_field + scope_tags) so any future ingest-layer assertion has a guaranteed-shape input to test against; per-category default-tier alignment with references/reference-source-types.yaml (cms-rule/training-material/glossary at tier 2; regulatory-doc at tier 1) so the corpus exercises both tier values present in the M036 enum; tier-2-block fixture pattern — full valid frontmatter (passes FR-1 + FR-2) + an additional tier_2_verdict: BLOCK frontmatter field — so the FR-18 promote-vs-retain ingest invariant has a deterministic input that does not depend on running the live conversus gate (the verdict is pre-baked into the fixture so the ingest layer's BLOCK-handling path can be exercised in isolation from P03's gate machinery); shellcheck SC1090-disabled-with-comment shape for sourcing the classifier lib in verifier scripts (`. $LIB` after `# shellcheck disable=SC1090`) so dynamic-source warnings do not surface; per-scope tmpfile naming in /tmp/m036-p04-classifier-rejects-*-err.$$.txt — the $$ suffix isolates concurrent invocations and the trailing rm -f cleans up under set -eu without trapping; cross-task verifier-input dependency (T01's classifier-shape verifier asserts the lib exposes a MEM004 token in its body so reviewers can trace the pattern attribution from the verifier output back to MEM004 in the knowledge graph — establishes the convention that pure-lib helpers in this milestone declare their pattern attribution in a structured comment that shape verifiers can grep for),grep -qF -e token-loop body for leading-dash safety (avoids BSD-grep flag-misinterpretation when patterns start with --),structured PASS:/FAIL:/SUMMARY: stdout per MEM001,ROOT resolution via ORCHESTRATOR_ROOT-or-pwd; pure-lib MEM004 carried into ingest surface — driver sources scripts/knowledge/classify-reference.sh + invokes classify_reference_file as the single FR-1+FR-2 gate; per-chunk partial-success ingest pattern (per-chunk REJECTED does not abort the pass — MEM011 validation-as-task semantics applied to ingest path; matches the spec-chunk classifier tolerance per commands/ingest.md:99-100); shasum/sha256sum probe-and-fallback for cross-platform sha256 carried from M036/P02 binary preservation; awk frontmatter-skip recipe for body-content extraction — second --- line marks frontmatter close,everything after is body content fed to sha256; additive case-block amendment pattern for rebuild-index.sh — old MEM*|SPEC-*) widened to MEM*|SPEC-*|REF-*) with new *.text|*.structured) exclusion branch added above (preserves CON-5 spec-chunk-untouched invariant; superstring grep-positive-check is sufficient — no negative check needed since old pattern is fully consumed by new pattern); FR-18 BLOCK gate at ingest-time as defense-in-depth — extract-time gating in P03 already withholds .structured.md promotion; ingest-time BLOCK detection asserts the absence of unexpected .structured.md sibling and emits a stderr WARNING if found (audit trail for any P03 retention-contract violation); backwards-compat green path for missing-reference-root — exit 0 with informational SUMMARY: ... (no reference corpus configured) suffix preserves CON-1 (operators without a reference corpus see no spurious failures); idempotency-via-tree-snapshot pattern in m036-p04-idempotency.sh — find -type f + per-file sha256 + sort + diff -q snapshots gives byte-identical-tree assertion that is the hard CON-4 contract regardless of whether per-line SKIPPED reporting fires (per-line SKIPPED depends on whether content_hash frontmatter equals body_sha256,which is mostly false for extract-produced chunks because extract writes the source-binary hash not the body hash; tree-snapshot is the load-bearing assertion),P04 inherits the M036 verifier conventions intact (milestone-prefixed slug m036-p04-*; AD-19 single-script-file shape; grep -qF -e token-loop body for leading-dash safety; structured PASS:/FAIL:/SUMMARY: stdout per MEM001; set -eu strict; ROOT resolution via ORCHESTRATOR_ROOT-or-pwd); M036 quoted-frontmatter convention vs P00 validator quote-stripping pattern (M036 reference-chunk fixtures use quoted YAML scalars per the frontmatter contract; the P00 validator must accept BOTH quoted and unquoted forms because YAML 1.2 spec treats them as equivalent; fix shape: append sed -E 's/^//; s/$//; s/^single//; s/single$//' to the existing leading/trailing-whitespace strip pipeline; reusable for any future validator parsing scalar values out of YAML frontmatter via grep|sed); Mid-phase end-to-end-first verifier pattern (T01-T02 verifiers in M036/P04 were token-presence and tree-byte-identical shape checks that did not exercise the full ingest path; T03 tier-2-block-not-promoted.sh was the first verifier to drive the full FR-1+FR-2+FR-18 path against a real fixture; lesson: when later phase tasks add their first end-to-end verifier they will surface upstream classifier/validator gaps that earlier shape-only verifiers cannot catch); Workspace-staging-into-cms-rule pattern (BLOCK fixture lives under tests/fixtures/m036-p04-reference-corpus/_negative/tier-2-block/ in the SSOT layout so it does not pollute the positive-path acceptance harness; the verifier stages it into mktemp -d /cms-rule/ before driving the driver so the taxonomy walker actually picks it up; workspace fixture-staging pattern is now M036-standard for any negative-path verifier whose fixture must be picked up by a top-level taxonomy walker); Cross-task ordering pattern reused (third instance in M036 — M036/P02/T02 size-cap-external-pointer green-flip; M036/P03/T03 four-fixture green-flip; M036/P04/T03 BLOCK-gating + validator-quote-strip green-up landed mid-task),Plan-Time Discipline correction: the plan body specified m036-p04-p02-regression-pass.sh re-run the P02 phase-suite aggregator as a single shell-out and assert pass=15 fail=0; but post-P03-close the P02 aggregator emits pass=14 fail=1 because m036-p02-tier-2-deferred-error.sh has had its semantics intentionally flipped (the P03 driver implemented the Tier 2 path that P02 deferred). The plan author missed this when authoring the regression check at planning time. Adopted the M036/P03/T03 selective-gate-list pattern verbatim instead -- explicitly enumerate 14 of the 15 P02 sub-gates and skip the one whose semantics flipped. This is the canonical M036 form for cross-phase regression checks where one phase's deferred-error verifier is replaced by the next phase's full-implementation verifier; recorded as the M036 standard for future cross-phase regression verifiers (e.g. when P05 lands a knowledge-graph traversal that supersedes a P04 deferred path); Fourth instance of the M036 acceptance-harness pattern (M036/P02/T04 SC-10 single-doc,M036/P03/T04 SC-11+SC-12 two-leg,M036/P04/T04 SC-1+SC-2 multi-fixture-corpus) -- shape now M036-canonical: harness emits BATTERY: last line; permissive shape verifier (rc<=1) + strict pass-rate gate (rc=0) split; phase-suite aggregator wires both gates plus all in-task verifiers; per-task mktemp -d workspace isolation; trap-cleanup; AD-19 single-script-file shape for the verifier invocations + script-internal compound bash legal inside the harness body per the validator-internal pipeline classifier-shape pass-through pattern from M036/P00/T03 MEM031; 13-gate phase-suite aggregator pattern reuse from M036/P02 (15 gates) + M036/P03 (14 gates): same set -eu + run helper redirecting both stdout+stderr to /dev/null + SUMMARY: line format; sub-gate exit code is the only signal so SKIP-internal verifiers exit 0 informationally and report PASS at aggregator level; carried verbatim including milestone-prefixed slug m036-p04-phase-suite.sh per the post-[M031](../../../../../milestones/M031/index.md) plan-phase contract; SC-1+SC-2 byte-equality assertion shape: because the ingest-reference.sh driver does not rewrite chunks (it leaves them in place under reference_root and emits CREATED stdout pointing to existing files),the SC-2 frontmatter-preservation assertion reduces to byte-equality between staged fixture copies and the original fixture sources via diff -q; this is tautological for byte-equality but exercises the contract that the driver's classifier+writer path does not perturb the source -- complementary to the m036-p04-idempotency.sh T02 verifier which exercises tree-byte-equality across two ingest runs in fresh workspaces; CON-4 idempotency assertion at the harness layer: re-run against the same workspace must exit 0 and produce a byte-identical tree (driver SHOULD emit SKIPPED stdout per FR-9 but the SC-2 contract is the byte-equality of the tree not the per-line SKIPPED count -- T02's m036-p04-idempotency.sh covers tree-byte-equality strictly while the harness covers re-run-rc=0 + per-fixture byte-equality)"
drill_down_paths:
  - "[.orchestrator/milestones/M036/phases/P04/tasks/T01-classifier-and-fixture-corpus-SUMMARY.md](../../../../../milestones/M036/phases/P04/tasks/T01-classifier-and-fixture-corpus-SUMMARY.md), [.orchestrator/milestones/M036/phases/P04/tasks/T02-driver-and-rebuild-index-SUMMARY.md](../../../../../milestones/M036/phases/P04/tasks/T02-driver-and-rebuild-index-SUMMARY.md), [.orchestrator/milestones/M036/phases/P04/tasks/T03-command-doc-and-block-gating-and-regression-SUMMARY.md](../../../../../milestones/M036/phases/P04/tasks/T03-command-doc-and-block-gating-and-regression-SUMMARY.md), [.orchestrator/milestones/M036/phases/P04/tasks/T04-acceptance-harness-and-aggregator-SUMMARY.md](../../../../../milestones/M036/phases/P04/tasks/T04-acceptance-harness-and-aggregator-SUMMARY.md)"
duration: "90m"
verification_result: "pass"
completed_at: "2026-05-02T18:17:36Z"
observability_surfaces:
  - "none"
---

P04 lands the M036 reference-corpus ingest layer: operators run `bash scripts/knowledge/ingest-reference.sh --reference-root knowledge/reference/` after P02/P03 produce extraction outputs; the driver walks the four taxonomy categories (`cms-rule|training-material|glossary|regulatory-doc`) under the configured root, classifies each `REF-*.md` chunk via the new `scripts/knowledge/classify-reference.sh` helper (FR-2 required-field presence + delegation to P00 T03's `tools/verify/lib/p00-validate-chunk-frontmatter.sh` for the FR-1 taxonomy + tier-enum check), gates Tier 2 BLOCK chunks per FR-18 (no `.structured.md` promotion + audit-trail `BLOCKED:` advisory), emits structured `CREATED:/SKIPPED:/REJECTED:/BLOCKED:/SUMMARY:` stdout, and invokes the additively-amended `scripts/knowledge/rebuild-index.sh` to register the new chunks. Idempotent re-runs against an existing tree produce byte-identical output (CON-4).

What was built across the four tasks:

- **T01** authored the M036 P04 fixture corpus at `tests/fixtures/m036-p04-reference-corpus/` (6 valid REF chunks across the 4 taxonomy categories + 3 negative-path chunks under `_negative/<reason>/` for the FR-1/FR-2/FR-18 rejection paths), the classifier helper `scripts/knowledge/classify-reference.sh` (MEM004 pure-lib exposing `classify_reference_required_fields` and `classify_reference_file`), and four shape verifiers covering classifier shape + rejection paths + fixture corpus shape. All four T01 verifiers PASS first-try.
- **T02** authored the driver `scripts/knowledge/ingest-reference.sh` (Bash 3.2; sources classify-reference.sh; per-chunk partial-success ingest; content_hash idempotency gate via shasum/sha256sum probe-and-fallback; FR-18 BLOCK detection with `.structured.md`-absence assertion as defense-in-depth; CON-1 backwards-compat green path when no reference root configured), additively amended `scripts/knowledge/rebuild-index.sh` (basename `case` block widened from `MEM*|SPEC-*` to `MEM*|SPEC-*|REF-*` with new `*.text|*.structured` exclusion branch above; CON-5 spec-chunk schema preserved byte-identical pre/post), and three shape verifiers covering driver shape + rebuild-index recognition + tree-snapshot idempotency contract. All three T02 verifiers PASS first-try.
- **T03** authored `commands/ingest-reference.md` (~60-line operator-facing command doc following commands/extract.md structural template), the FR-18 BLOCK-not-promoted verifier, the M036/P05 regression guard, and the command-shape token-presence verifier. Mid-task correction: `tools/verify/lib/p00-validate-chunk-frontmatter.sh` was extended to additionally strip surrounding single OR double quotes from CATEGORY/TIER scalar values — surfaced when T03's BLOCK verifier became the first M036/P04 verifier to drive the full ingest path against a real fixture (T01/T02 verifiers were token-presence + tree-byte-identical shape checks that did not exercise the FR-1 validator end-to-end). Fix is byte-additive; pre-existing `m036-p00-phase-suite.sh` reports `pass=8 fail=0` unchanged. All three T03 verifiers PASS post-fix.
- **T04** authored the SC-1+SC-2 acceptance harness `tests/test-reference-ingest-fixture.sh` (drives ingest-reference.sh against a workspace-copy of the fixture corpus; emits `BATTERY: pass=N fail=N skip=N`; asserts driver-rc=0 + per-chunk CREATED stdout + frontmatter byte-equality + CON-4 re-run-rc=0), the M036/P02 selective-gate-list regression verifier (excluding `m036-p02-tier-2-deferred-error.sh` whose semantics flipped at P03 close), the permissive-shape + strict-pass-rate harness gate split, and the 13-gate phase-suite aggregator. Plan-time discipline correction: the plan body specified the regression check shell-out the P02 phase-suite aggregator and assert pass=15 fail=0; post-P03-close that aggregator emits pass=14 fail=1 because P03 implemented the Tier 2 path P02 deferred. Adopted the M036/P03/T03 selective-gate-list pattern verbatim instead — explicitly enumerate 14 of the 15 P02 sub-gates and skip the one whose semantics flipped. Recorded as the canonical M036 form for future cross-phase regression checks where one phase's deferred-error verifier is replaced by the next phase's full-implementation verifier. All four T04 verifiers PASS.

Verification results:

- 13-gate phase-suite aggregator: `SUMMARY: m036-p04-phase-suite.sh pass=13 fail=0` (T01 ×4 + T02 ×3 + T03 ×3 + T04 ×3).
- SC-1+SC-2 acceptance battery: `BATTERY: pass=15 fail=0 skip=0` on the dev host (1 driver-rc + 1 SUMMARY-line-shape + 6 per-chunk CREATED + 6 per-chunk byte-equality + 1 CON-4 re-run-rc).
- All four task summaries on disk with full task-summary frontmatter contract.
- External-mod check (phase-transition.sh): PASS — no external modifications outside declared key_files.
- Roadmap sync: SYNC:OK — P04 marked [x] in M036-ROADMAP.md.
- Cross-phase regression: M036/P02 (selective 14 of 15 sub-gates) + M036/P05 (8-gate phase-suite) both PASS post-P04 close — confirms `rebuild-index.sh` additive amendment does not perturb prior phase contracts.

Cross-task ordering pattern (M036 standard form): third instance in M036 (after M036/P02 size-cap-external-pointer T02→T03 green-flip, M036/P03 four T03→T04 deferred green-flip, M036/P04 BLOCK-gating + validator-quote-strip T03 mid-task green-up). Auto-loop's pass_with_concerns / DONE_WITH_CONCERNS handling per US3 AS6 carried the loop forward without manual intervention.

Patterns established (carried into `key_decisions: none` because all are reusable conventions, not architectural commitments): pure-lib MEM004 carried into the classifier surface; two-tier classifier composition (FR-2 fast-pass + delegation to existing P00 T03 validator); `_negative/<reason>/` subdirectory naming convention for ergonomically co-locating rejection-path fixtures; pre-baked `id:`+`chunk_id:` in REF-* frontmatter so `rebuild-index.sh::fm_field` picks them up unambiguously; tier-2-block fixture pattern (full valid frontmatter + additional `tier_2_verdict: BLOCK` field) so FR-18 promote-vs-retain can be exercised in isolation from P03's gate machinery; per-chunk partial-success ingest pattern (REJECTED does not abort the pass — MEM011 validation-as-task semantics); shasum/sha256sum probe-and-fallback for cross-platform sha256; awk frontmatter-skip recipe for body-content extraction; additive `case`-block amendment pattern for `rebuild-index.sh`; CON-1 backwards-compat green path for missing-reference-root; idempotency-via-tree-snapshot pattern; M036 quoted-frontmatter convention vs P00 validator quote-stripping pattern; mid-phase end-to-end-first verifier pattern (later tasks that add the first end-to-end verifier surface upstream classifier/validator gaps that earlier shape-only verifiers cannot catch); workspace-staging-into-cms-rule pattern for negative-path verifiers whose fixture must be picked up by the taxonomy walker; selective-gate-list cross-phase regression pattern (carried verbatim from M036/P03/T03); fourth instance of the M036 acceptance-harness pattern (BATTERY: contract + permissive+strict gate split); 13-gate phase-suite aggregator carried verbatim from M036/P02 (15 gates) + M036/P03 (14 gates).

Roadmap impact: P06 (idempotent re-extract + re-ingest + supersede chain) consumes the content_hash idempotency gate established in P04's driver and the `version:` optional frontmatter field for supersede chains. P07 (dispatch injection under token-budget governor) consumes the chunk store and rebuild-index registration. P08 (M036b post-launch wiki projection) consumes the registered REF-* chunks. No deviation from the original M036a roadmap; no boundary-map changes; no decisions invalidate downstream phases. Affects: P06, P07, P08; requires: P02, P03 — all gates honored.

## Task Plan

---
schema_version: "1.0"
type: task-plan
id: "T03"
parent: "P06"
milestone: "M036"
parallelizable: false
---

# T03 — On-disk supersede-corpus fixtures + extract-manifest fixture

## Goal

Author the on-disk fixture set under `tests/fixtures/m036-p06-supersede-corpus/` and the single-document extract manifest at `tests/fixtures/m036-p06-extract-manifest.yaml`. The fixtures are the inputs to the SC-6 acceptance harness in T04 (`tests/test-reference-supersede-chain.sh`). Author two T03 token-presence verifiers that gate the fixture shape.

## Context (zero-context summary)

The SC-6 harness in T04 needs three on-disk fixtures to drive a complete supersede-chain story:

1. **Original V1 reference chunk** at `tests/fixtures/m036-p06-supersede-corpus/original/cms-rule/REF-cms-rule-supersede-fixture.md` — full FR-2 frontmatter (source, published, version, cite_id, topic_tags, applies_to_field) plus a body containing the literal string `BODY V1` so the body sha256 differs from the mutated V2 fixture. The chunk_id `REF-cms-rule-supersede-fixture` matches the M036/P04 chunk-id convention.

2. **Mutated V2 reference chunk** at `tests/fixtures/m036-p06-supersede-corpus/mutated/cms-rule/REF-cms-rule-supersede-fixture.md` — same path basename (the harness copies one OR the other into the workspace's reference root depending on whether it's testing the V1 first-extraction or the V2 mutation re-extraction), same FR-2 frontmatter, body containing `BODY V2`.

3. **Citer spec chunk** at `tests/fixtures/m036-p06-supersede-corpus/citer-spec/SPEC-requirement-supersede-citer.md` — declares `cites: [REF-cms-rule-supersede-fixture]` (the V1 chunk_id, NOT the v2 successor). The harness stages this into the workspace's `knowledge/spec/<scope>/` so the typed-edge traverser will find a citer of the V1 chunk, exercising the SC-6 REVIEW: line emission.

The fixtures are deliberately separate from the M036/P04 reference-corpus fixture (`tests/fixtures/m036-p04-reference-corpus/`) so the supersede story is isolated from the P04 ingest happy-path and the P05 graph-traversal happy-path. Co-locating supersede-specific fixtures under their own M036/P06 directory follows the M036-canonical fixture-naming convention.

The single-document extract manifest at `tests/fixtures/m036-p06-extract-manifest.yaml` is a reference-shape only fixture (the SC-6/SC-13 harnesses inline their own manifests via heredocs into `mktemp -d` workspaces). The on-disk manifest exists primarily as documentation + a stable shape gate; the verifier asserts it has the expected fields.

The fixtures are small (~5 KB total), markdown / YAML only; no host-tool dependency.

## Inputs

API surface T03 consumes (from upstream):

- M036/P04 fixture-corpus shape (`tests/fixtures/m036-p04-reference-corpus/cms-rule/REF-cms-rule-fixture-01.md`) — used as a reference template for the FR-2 provenance frontmatter shape. T03's fixtures match the same field set: schema_version, type, milestone, category, chunk_id, cite_id, source, published, version, tier, content_hash, size_bytes, summary_mode, topic_tags, applies_to_field, scope_tags.
- M036/P02 manifest contract (`references/extract-manifest-contract.md`) — used as a template for the single-document manifest shape. T03's manifest matches the field set: schema_version, type, milestone, size_cap_bytes, documents (with cite_id, source_path, category, source, published, version, topic_tags, applies_to_field, tier, summary_mode, summary).
- M036/P04 spec-chunk citer convention — spec chunks under `knowledge/spec/<scope>/` declare `cites: [REF-...]` in their frontmatter; the typed-edge traverser walks these.

## Files Touched

- `tests/fixtures/m036-p06-supersede-corpus/original/cms-rule/REF-cms-rule-supersede-fixture.md` (create)
- `tests/fixtures/m036-p06-supersede-corpus/mutated/cms-rule/REF-cms-rule-supersede-fixture.md` (create)
- `tests/fixtures/m036-p06-supersede-corpus/citer-spec/SPEC-requirement-supersede-citer.md` (create)
- `tests/fixtures/m036-p06-extract-manifest.yaml` (create)
- `tools/verify/m036-p06-fixture-corpus-shape.sh` (create)
- `tools/verify/m036-p06-extract-manifest-shape.sh` (create)

## Steps

1. **Create the original V1 reference chunk fixture** at `tests/fixtures/m036-p06-supersede-corpus/original/cms-rule/REF-cms-rule-supersede-fixture.md`. Verbatim:

   ```markdown
   ---
   schema_version: "1.0"
   type: reference-chunk
   milestone: "M036"
   category: "cms-rule"
   id: "REF-cms-rule-supersede-fixture"
   chunk_id: "REF-cms-rule-supersede-fixture"
   cite_id: "supersede-fixture"
   source: "internal-test"
   published: "2026-05-02"
   version: 1
   tier: 1
   content_hash: "0000000000000000000000000000000000000000000000000000000000000001"
   size_bytes: 64
   summary_mode: "operator"
   topic_tags: [pbj-staffing]
   applies_to_field: [staff_count]
   scope_tags: "[project], [milestone:M036]"
   ---

   BODY V1 -- M036/P06 supersede-chain fixture; original version. Body content
   is intentionally distinct from the mutated/ sibling so the content_hash gate
   in extract-reference.sh fires on re-extraction.
   ```

2. **Create the mutated V2 reference chunk fixture** at `tests/fixtures/m036-p06-supersede-corpus/mutated/cms-rule/REF-cms-rule-supersede-fixture.md`. Verbatim:

   ```markdown
   ---
   schema_version: "1.0"
   type: reference-chunk
   milestone: "M036"
   category: "cms-rule"
   id: "REF-cms-rule-supersede-fixture"
   chunk_id: "REF-cms-rule-supersede-fixture"
   cite_id: "supersede-fixture"
   source: "internal-test"
   published: "2026-05-02"
   version: 2
   tier: 1
   content_hash: "0000000000000000000000000000000000000000000000000000000000000002"
   size_bytes: 64
   summary_mode: "operator"
   topic_tags: [pbj-staffing]
   applies_to_field: [staff_count]
   scope_tags: "[project], [milestone:M036]"
   ---

   BODY V2 -- M036/P06 supersede-chain fixture; mutated successor. The harness
   replaces the original/ source with this content between extract runs to
   exercise the supersede authoring branch.
   ```

   Note: the `content_hash` and `size_bytes` values in BOTH fixtures are placeholders. The harness in T04 does NOT assert these against the body; the harness invokes the live extract driver which computes its own hashes from the live source. These fixtures' frontmatter values are documentation-shape only.

3. **Create the citer spec chunk fixture** at `tests/fixtures/m036-p06-supersede-corpus/citer-spec/SPEC-requirement-supersede-citer.md`. Verbatim:

   ```markdown
   ---
   schema_version: "1.0"
   type: spec-chunk
   milestone: "M-fixture"
   category: "requirement"
   id: "SPEC-requirement-supersede-citer"
   chunk_id: "SPEC-requirement-supersede-citer"
   spec_id: "FR-supersede-citer"
   cites: [REF-cms-rule-supersede-fixture]
   topic_tags: [pbj-staffing]
   scope_tags: "[project]"
   ---

   # FR-supersede-citer

   This synthetic spec requirement cites the M036/P06 supersede-fixture
   reference chunk in its V1 form. After the fixture's V2 successor is
   authored, the M036/P06 cross-citer REVIEW: walk should surface this
   chunk_id with reason=cites-superseded.
   ```

4. **Create the single-document extract manifest** at `tests/fixtures/m036-p06-extract-manifest.yaml`. Verbatim:

   ```yaml
   # tests/fixtures/m036-p06-extract-manifest.yaml -- M036 P06 T03.
   #
   # Reference-shape extract manifest for the supersede-fixture document.
   # Used as documentation + a stable shape gate; the SC-6/SC-13 harnesses
   # inline their own manifests into mktemp -d workspaces because the
   # source path here points outside the workspace root.
   schema_version: "1.0"
   type: extract-manifest
   milestone: "M036"
   size_cap_bytes: 10485760

   documents:
     - cite_id: "supersede-fixture"
       source_path: "../m036-p06-supersede-corpus/original/cms-rule/REF-cms-rule-supersede-fixture.md"
       category: "cms-rule"
       source: "internal-test"
       published: "2026-05-02"
       version: "1"
       topic_tags: [pbj-staffing]
       applies_to_field: [staff_count]
       tier: 1
       summary_mode: "operator"
       summary: "M036 P06 supersede-fixture; the V1 source for the supersede-chain harness."
   ```

5. **Author `tools/verify/m036-p06-fixture-corpus-shape.sh`**. Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m036-p06-fixture-corpus-shape.sh -- M036 P06 T03.
   # Token-presence verifier on the supersede-corpus fixtures.
   # AD-19 single-script-file shape. Bash 3.2 per CON-2.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   BASE="$ROOT/tests/fixtures/m036-p06-supersede-corpus"
   V1="$BASE/original/cms-rule/REF-cms-rule-supersede-fixture.md"
   V2="$BASE/mutated/cms-rule/REF-cms-rule-supersede-fixture.md"
   CITER="$BASE/citer-spec/SPEC-requirement-supersede-citer.md"
   pass=0
   fail=0
   chk() {
     local label="$1" file="$2" pat="$3"
     if [ -f "$file" ] && grep -qF -e "$pat" "$file"; then
       echo "PASS: $label"
       pass=$((pass + 1))
     else
       echo "FAIL: $label (file=$file pat=$pat)"
       fail=$((fail + 1))
     fi
   }
   chk "v1-exists"                    "$V1" "BODY V1"
   chk "v1-cite_id"                   "$V1" 'cite_id: "supersede-fixture"'
   chk "v1-category-cms-rule"         "$V1" 'category: "cms-rule"'
   chk "v1-topic-tag-pbj-staffing"    "$V1" "pbj-staffing"
   chk "v1-applies-to-field"          "$V1" "staff_count"
   chk "v2-exists"                    "$V2" "BODY V2"
   chk "v2-cite_id"                   "$V2" 'cite_id: "supersede-fixture"'
   chk "v2-version-2"                 "$V2" "version: 2"
   chk "citer-spec-exists"            "$CITER" "SPEC-requirement-supersede-citer"
   chk "citer-cites-v1-id"            "$CITER" "cites: [REF-cms-rule-supersede-fixture]"
   # Negative: citer must NOT name the v2 successor (the test exercises
   # the chain-walk from V1 -- if the citer pointed at v2 directly, the
   # supersede-walk would have nothing to surface).
   if [ -f "$CITER" ] && grep -qF -e "REF-cms-rule-supersede-fixture-v2" "$CITER"; then
     echo "FAIL: citer-must-not-name-v2-successor"
     fail=$((fail + 1))
   else
     echo "PASS: citer-points-at-V1-only"
     pass=$((pass + 1))
   fi
   echo "SUMMARY: m036-p06-fixture-corpus-shape.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

6. **Author `tools/verify/m036-p06-extract-manifest-shape.sh`**. Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m036-p06-extract-manifest-shape.sh -- M036 P06 T03.
   # Token-presence verifier on the supersede-fixture extract manifest.
   # AD-19 single-script-file shape. Bash 3.2 per CON-2.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   F="$ROOT/tests/fixtures/m036-p06-extract-manifest.yaml"
   pass=0
   fail=0
   chk() {
     local label="$1" pat="$2"
     if grep -qF -e "$pat" "$F"; then
       echo "PASS: $label"
       pass=$((pass + 1))
     else
       echo "FAIL: $label (missing: $pat)"
       fail=$((fail + 1))
     fi
   }
   if [ ! -f "$F" ]; then
     echo "FAIL: $F not found"
     echo "SUMMARY: m036-p06-extract-manifest-shape.sh pass=0 fail=1"
     exit 1
   fi
   chk "schema_version-declared"      "schema_version:"
   chk "type-extract-manifest"        "type: extract-manifest"
   chk "milestone-M036"               'milestone: "M036"'
   chk "size_cap_bytes-declared"      "size_cap_bytes:"
   chk "documents-array"              "documents:"
   chk "fixture-cite_id"              'cite_id: "supersede-fixture"'
   chk "category-cms-rule"            'category: "cms-rule"'
   chk "tier-1"                       "tier: 1"
   chk "summary_mode-operator"        'summary_mode: "operator"'
   echo "SUMMARY: m036-p06-extract-manifest-shape.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

7. Make both new verifier scripts executable (`chmod +x`).

## Must-Haves (subset T03 addresses)

- The supersede-corpus fixtures and the manifest fixture exist on disk with the expected shape (V1 + mutated + citer-spec).
- The `tests/fixtures/m036-p06-extract-manifest.yaml` fixture exists with the expected single-document manifest shape.

## Verification

```bash
bash tools/verify/m036-p06-fixture-corpus-shape.sh
bash tools/verify/m036-p06-extract-manifest-shape.sh
```

## Notes

The V1 and V2 fixtures share the same path basename intentionally — the SC-6 harness in T04 uses one OR the other depending on the run iteration. The `original/` vs `mutated/` directory split makes that copy operation unambiguous (`cp tests/fixtures/m036-p06-supersede-corpus/original/...` for the first run; `cp tests/fixtures/m036-p06-supersede-corpus/mutated/...` for the second).

The placeholder `content_hash` values are NOT computed from the body — the live extract driver computes the real hash from the source binary at extract time. Token-shape verifiers do not enforce content_hash equality. This is consistent with the M036/P04 fixture-corpus convention where placeholder hashes are present in the frontmatter but the harness does not assert them against the body.

The citer-spec chunk lives under `citer-spec/` (NOT `cms-rule/`) so it is NOT picked up by the M036/P04 ingest driver's taxonomy walker (which only descends into the four canonical category directories). The harness in T04 explicitly stages it into the workspace's `knowledge/spec/<scope>/` path, where the typed-edge traverser's spec-chunk source-glob will find it.

Expected verifier outputs: fixture-corpus-shape reports `pass=11 fail=0`; extract-manifest-shape reports `pass=9 fail=0`.

## State Context

- **Current State**: executing
- **Milestone**: M036
- **Phase**: P06
- **Task**: T03-supersede-fixture-corpus
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints


### Acceptance Criteria


### Files To Touch

- `scripts/knowledge/extract-reference.sh` (modify)
- `scripts/knowledge/lib/extract-supersede.sh` (create)
- `scripts/knowledge/ingest-reference.sh` (modify)
- `scripts/knowledge/lib/ingest-review-advisory.sh` (create)
- `tests/fixtures/m036-p06-supersede-corpus/original/cms-rule/REF-cms-rule-supersede-fixture.md` (create)
- `tests/fixtures/m036-p06-supersede-corpus/mutated/cms-rule/REF-cms-rule-supersede-fixture.md` (create)
- `tests/fixtures/m036-p06-supersede-corpus/citer-spec/SPEC-requirement-supersede-citer.md` (create)
- `tests/fixtures/m036-p06-extract-manifest.yaml` (create)
- `tests/test-extract-idempotency.sh` (create)
- `tests/test-reference-reingest-idempotency.sh` (create)
- `tests/test-reference-supersede-chain.sh` (create)
- `tools/verify/m036-p06-extract-supersede-shape.sh` (create)
- `tools/verify/m036-p06-extract-supersede-helper-shape.sh` (create)
- `tools/verify/m036-p06-supersede-chain-end-to-end.sh` (create)
- `tools/verify/m036-p06-ingest-review-shape.sh` (create)
- `tools/verify/m036-p06-ingest-review-helper-shape.sh` (create)
- `tools/verify/m036-p06-review-emission-end-to-end.sh` (create)
- `tools/verify/m036-p06-removed-detection-end-to-end.sh` (create)
- `tools/verify/m036-p06-fixture-corpus-shape.sh` (create)
- `tools/verify/m036-p06-extract-manifest-shape.sh` (create)
- `tools/verify/m036-p06-test-harness.sh` (create)
- `tools/verify/m036-p06-acceptance-harness-passes.sh` (create)
- `tools/verify/m036-p06-p02-regression-pass.sh` (create)
- `tools/verify/m036-p06-p03-regression-pass.sh` (create)
- `tools/verify/m036-p06-p04-regression-pass.sh` (create)
- `tools/verify/m036-p06-p05-regression-pass.sh` (create)
- `tools/verify/m036-p06-p07-regression-pass.sh` (create)
- `tools/verify/m036-p06-phase-suite.sh` (create)

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