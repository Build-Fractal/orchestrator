---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T01-pbj-fixture-and-oracle (Phase P01, Milestone M033)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~800 | required |
| Upstream Context | 981-983 | ~100 | required |
| Task Plan | 985-1118 | ~3100 | required |
| State Context | 1120-1126 | ~100 | required |
| First-Turn Completeness | 1128-1184 | ~900 | required |
| **Total** | | **~15800** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 778
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
hit_count: 778
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
hit_count: 778
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
hit_count: 778
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
hit_count: 679
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
hit_count: 679
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
hit_count: 679
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
hit_count: 778
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
hit_count: 679
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
hit_count: 679
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
hit_count: 679
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
hit_count: 778
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
hit_count: 778
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
hit_count: 778
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
hit_count: 679
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
hit_count: 679
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
hit_count: 679
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
hit_count: 778
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
hit_count: 679
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
hit_count: 679
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
hit_count: 778
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
hit_count: 778
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
hit_count: 679
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
hit_count: 679
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
hit_count: 679
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
hit_count: 334
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
hit_count: 334
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
hit_count: 334
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
hit_count: 354
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
hit_count: 354
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
hit_count: 344
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
     Project-owned slug-bearing verifiers live under tools/verify/.
     Verifier scripts are co-authored alongside their corresponding
     artifact within the SAME task (plan-time discipline rule 2).
     Namespacing: `m033-p01-*` prefix avoids collision with M030/M031/[M032](../../../../../milestones/M032/index.md)
     existing `m###-p##-*` verifiers in the shared tools/verify/ tree
     (per the milestone-slug-required convention; phase-only `p##-*`
     names silently clobbered prior milestones — [M030](../../../../../milestones/M030/index.md) lost to [M031](../../../../../milestones/M031/index.md), etc.). -->

### Truths

- `commands/start.md` exists in the canonical command-document shape (YAML frontmatter with `description:`; Title; Prerequisites / State Check; Core Workflow; Output; Idempotency; Error Handling; Referenced Scripts/Templates per MEM012). The `description:` frontmatter advertises `orchestrator:start` as the warm conversational front door for any new orchestrator-managed project. The Referenced Scripts section names `scripts/lifecycle/start.sh`, `scripts/lifecycle/init-project.sh`, and `references/branch-detection.md`.
  - Check: `bash tools/verify/m033-p01-start-md-shape.sh`

- `scripts/lifecycle/start.sh` exists and is executable. It accepts `--project-dir <path>` (default `pwd`), `--yes` (auto-accept defaults), `--branch <branch>` (operator override of detection — `greenfield-empty | greenfield-with-materials | existing-codebase | migrating`), `--stack <stack>` (optional; recommendation is derived at sub-flow time per FR-1 / MIT-004; P01 only forwards the flag — sub-flow stubs do not consume it), and `--dry-run`. Unknown flags exit non-zero with a usage diagnostic naming the unknown flag. The script invokes `bash scripts/lifecycle/init-project.sh --project-dir <path>` exactly once per invocation; if `<path>/.orchestrator/config.yml` already exists, init invocation is skipped and a `init already complete, proceeding to branch sub-flow` diagnostic is emitted (Edge Case `init already ran`).
  - Check: `bash tools/verify/m033-p01-start-sh-flags-and-init-invocation.sh`

- `scripts/lifecycle/start.sh` implements FR-2's deterministic branch-detection rules in this strict order, against `<project-dir>` as the probe target: (1) `.gsd/` OR `.gsd2/` OR `.specify/` artifact present → `migrating`; (2) ≥3 project-root `.md` files matching `*BRIEF*.md|*PLAN*.md|*DECISIONS*.md|*HANDOFF*.md|*AUDIT*.md` AND no `src/` directory → `greenfield-with-materials`; (3) `src/` directory present OR ≥10 source files at project root (extensions `.js|.ts|.jsx|.tsx|.py|.rs|.go|.rb|.java|.kt|.swift|.cs|.cpp|.c|.h`) OR `.git/` with ≥1 commit → `existing-codebase`; (4) otherwise → `greenfield-empty`. Detection order is non-negotiable — rule 1 fires before rule 3 even when both match (per US-1 AS-4 — `migrating` always wins over `existing-codebase`). The detected branch is printed to stdout as `branch: <name>` before sub-flow dispatch. Operator-supplied `--branch <name>` skips detection entirely (override is silent — no warning unless detection would have produced a different name, in which case a `branch-override: detected=<X> overridden=<Y>` diagnostic is emitted to stderr).

<dispatch-volatile>

## Upstream Context

No upstream summaries available.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M033"
name: "PBJ acceptance fixture + ground-truth README oracle"
depends_on: []
---

## Prerequisites

- The `tests/fixtures/` directory exists (verified: many existing fixture dirs siblings under it).
- The `tools/verify/` directory exists (verified: M030/M031/M032 verifiers under it).
- No file currently lives at `tests/fixtures/m033-pbj-materials-fixture/` (verified: `ls tests/fixtures/ | grep m033` returns empty). T01 creates this directory.
- The CON-4 / FR-23 spec requirements (exactly 5 inconsistencies, ≥1 per detection category) are documented in the M033 spec body under FR-23 and CON-4 — this task plan re-states the requirement inline so executors do not need to re-read the spec.
- The named PBJ-shape document set is `PRODUCT-BRIEF.md`, `MVP-PLAN.md`, `DECISIONS.md`, `MILESTONE-AUDIT.md` — anchored in the spec's User Story 4 problem statement. The fixture names these four files exactly so the FR-2 rule-2 detection (≥3 PBJ-shape `.md` files) fires cleanly when `start.sh` probes against this fixture (after copying it into a probe target with `src/` absent).

## Description

T01 ships the synthetic-PBJ-shape fixture that powers SC-4 (P04 materials-intake test) AND that exercises FR-2's rule-2 (`greenfield-with-materials`) branch detection in P01's SC-1. The fixture is curatorial work — its value is in the *exact* 5 inconsistencies documented in the README oracle, which P04's deterministic drift detector compares its output against. Frontloading this in P01 (rather than P04) is mandated by FR-23: the fixture must exist before P04's `p04-materials-intake.sh` can run, and authoring the inconsistencies in P01 means P02–P04 implementations have a stable target to develop against.

**Deterministic-output guarantee (FR-23):** the fixture content is text-only, with no timestamps, no machine-name embeddings, no platform-specific paths. Same fixture + same operator answers produces same detector output across any platform and operator identity.

**Inconsistency design.** The 5 inconsistencies cover the three CON-4 detection categories with ≥1 instance each, plus 2 additional instances chosen to stress the deterministic detector:

1. **id-misalignment** (PRODUCT-BRIEF.md ↔ MVP-PLAN.md): `PRODUCT-BRIEF.md` references `US-3` in its scope statement, but `MVP-PLAN.md` defines only `US-1` and `US-2` in its User Stories section. The detector should surface the orphan `US-3` reference.
2. **scheme-contradiction** (DECISIONS.md ↔ MVP-PLAN.md): `DECISIONS.md` records `DR-002: Deploy via Vercel` while `MVP-PLAN.md` lists "Cloudflare Workers" as the deployment target. Conflicting authoritative scheme.
3. **orphan-reference** (MILESTONE-AUDIT.md): `MILESTONE-AUDIT.md` mentions a milestone `M-3 (Authentication)` that no other document defines or scopes. Forward reference to a non-existent target.
4. **id-misalignment, second instance** (PRODUCT-BRIEF.md ↔ DECISIONS.md): `PRODUCT-BRIEF.md` says decisions `DR-001` and `DR-002` cover the architecture; `DECISIONS.md` defines `DR-001`, `DR-002`, AND `DR-003` — but `DR-003` is referenced nowhere upstream (orphan-on-the-other-side variant — defined but never cited).
5. **scheme-contradiction, second instance** (PRODUCT-BRIEF.md ↔ MVP-PLAN.md): `PRODUCT-BRIEF.md` says "MVP timeline: 4 weeks"; `MVP-PLAN.md` says "MVP timeline: 6 weeks". Numeric scheme mismatch.

The README oracle enumerates these 5 by name, category, and document pair so P04's verifier can compare detector output against the oracle line-by-line.

## Steps

1. **Create the fixture directory:** `mkdir -p tests/fixtures/m033-pbj-materials-fixture`.

2. **Author `tests/fixtures/m033-pbj-materials-fixture/PRODUCT-BRIEF.md`** (≥25 lines). Required content tokens (verifier asserts presence): `## Problem`, `## Target User`, `US-` (the literal token, used by US-1 and US-3 references), the literal phrase `MVP timeline: 4 weeks` (inconsistency #5 left side), references to `DR-001` and `DR-002` (inconsistency #4 left side), and a scope statement that names `US-3` explicitly (inconsistency #1 left side). Body sections: Problem (3–4 lines), Target User (2–3 lines), Scope (4–5 lines including the `US-1 / US-2 / US-3` enumeration), Architecture Decisions (3 lines naming `DR-001` and `DR-002`), Timeline (1 line: `MVP timeline: 4 weeks`).

3. **Author `tests/fixtures/m033-pbj-materials-fixture/MVP-PLAN.md`** (≥25 lines). Required tokens: `## User Stories`, `US-` (used for US-1 and US-2 — note the deliberate absence of US-3), the literal phrase `MVP timeline: 6 weeks` (inconsistency #5 right side), the literal phrase `Cloudflare Workers` (inconsistency #2 right side). Body sections: Goals (3–4 lines), User Stories (5–6 lines defining `US-1` and `US-2` only — `US-3` deliberately absent), Deployment Target (1–2 lines naming Cloudflare Workers), Timeline (1 line: `MVP timeline: 6 weeks`), Risks (3 lines).

4. **Author `tests/fixtures/m033-pbj-materials-fixture/DECISIONS.md`** (≥20 lines). Required tokens: `DR-` (the literal token; used for DR-001, DR-002, DR-003), the literal phrase `Deploy via Vercel` (inconsistency #2 left side). Body: a lightweight decision register with three entries (`DR-001 Pick framework`, `DR-002 Deploy via Vercel`, `DR-003 Database choice` — note `DR-003` is defined but never cited by upstream docs, this is inconsistency #4's right side). Each DR is 4–5 lines: title + rationale + status.

5. **Author `tests/fixtures/m033-pbj-materials-fixture/MILESTONE-AUDIT.md`** (≥20 lines). Required tokens: `M-` (the literal token; used by `M-1`, `M-2`, `M-3`). Body: an audit table of three milestones — `M-1 Discovery`, `M-2 Foundation`, `M-3 Authentication` — where `M-3` is the orphan reference (inconsistency #3): no scope appears in any other document. Each milestone entry is 4–5 lines.

6. **Author `tests/fixtures/m033-pbj-materials-fixture/README.md`** (≥60 lines). This is the SC-4 ground-truth oracle. The file MUST contain a numbered list of exactly 5 entries (markdown numbered list, lines starting `1.`, `2.`, `3.`, `4.`, `5.`). Each entry names: (a) the CON-4 category from the closed enum `id-misalignment | scheme-contradiction | orphan-reference`, (b) the affected document pair (e.g., `PRODUCT-BRIEF.md ↔ MVP-PLAN.md`), (c) one to two sentences describing the inconsistency.

   Required README sections (the verifier asserts each):
   - `# m033 PBJ Materials Fixture` (H1 title)
   - `## Purpose` — names FR-23 / SC-4 / P04 as consumers; explains the fixture is the deterministic input for P04's drift detector
   - `## Inconsistencies (Ground-Truth Oracle)` — the numbered 5-item list (the load-bearing section)
   - `## Determinism Guarantee` — names FR-23's "same fixture + same operator answers → same detection output across platforms and operator identities" clause
   - `## Consumers` — lists the consuming phases (`P01 SC-1` for branch-detection rule-2, `P04 SC-4` for materials-intake)

   Sample numbered-list shape (executor MUST author all 5 entries in this exact form for the oracle parser):

   ```markdown
   1. **id-misalignment** — `PRODUCT-BRIEF.md ↔ MVP-PLAN.md`. PRODUCT-BRIEF references `US-3` in its scope statement, but MVP-PLAN defines only `US-1` and `US-2`.
   2. **scheme-contradiction** — `DECISIONS.md ↔ MVP-PLAN.md`. DECISIONS records `DR-002: Deploy via Vercel`; MVP-PLAN names `Cloudflare Workers` as deployment target.
   3. **orphan-reference** — `MILESTONE-AUDIT.md`. Mentions milestone `M-3 (Authentication)` which no other document defines or scopes.
   4. **id-misalignment** — `PRODUCT-BRIEF.md ↔ DECISIONS.md`. DECISIONS defines `DR-003` but no upstream document cites it.
   5. **scheme-contradiction** — `PRODUCT-BRIEF.md ↔ MVP-PLAN.md`. PRODUCT-BRIEF says `MVP timeline: 4 weeks`; MVP-PLAN says `MVP timeline: 6 weeks`.
   ```

7. **Author `tools/verify/m033-p01-pbj-fixture-shape.sh`** (≥25 lines, executable, `chmod +x`). The verifier asserts:
   - The four required documents (`PRODUCT-BRIEF.md`, `MVP-PLAN.md`, `DECISIONS.md`, `MILESTONE-AUDIT.md`) exist under `tests/fixtures/m033-pbj-materials-fixture/`.
   - No `src/` directory and no `.git/` directory under the fixture (the fixture is materials-only — required for FR-2 rule-2 to fire cleanly when copied into a probe target).
   - Each document meets its minimum line count from the artifacts list.
   - Required content tokens are present in each document via `grep -q`.
   - Emits `PASS:` lines for each assertion and a final `SUMMARY: m033-p01-pbj-fixture-shape.sh pass=N fail=M` line. Exit 0 iff all PASS.

8. **Author `tools/verify/m033-p01-pbj-fixture-readme-oracle.sh`** (≥25 lines, executable). The verifier asserts:
   - The README exists.
   - The five numbered list entries (lines matching `^[1-5]\. ` at the start) are present.
   - Each numbered entry contains exactly one of the three CON-4 category tokens (`id-misalignment`, `scheme-contradiction`, `orphan-reference`).
   - Across the 5 entries, each of the three categories appears at least once (≥1 per category per FR-23).
   - The required README section headers (`## Purpose`, `## Inconsistencies (Ground-Truth Oracle)`, `## Determinism Guarantee`, `## Consumers`) are present.
   - Emits PASS lines and a SUMMARY line. Exit 0 iff all PASS.

## Must-Haves

This task addresses these P01 phase truths:
- `tests/fixtures/m033-pbj-materials-fixture/` exists with the four PBJ-shape documents and the 5 inconsistencies.
- `tests/fixtures/m033-pbj-materials-fixture/README.md` is the SC-4 ground-truth oracle.

This task creates these P01 phase artifacts:
- `tests/fixtures/m033-pbj-materials-fixture/{PRODUCT-BRIEF,MVP-PLAN,DECISIONS,MILESTONE-AUDIT,README}.md`
- `tools/verify/m033-p01-pbj-fixture-shape.sh`
- `tools/verify/m033-p01-pbj-fixture-readme-oracle.sh`

## Verification

```bash
bash tools/verify/m033-p01-pbj-fixture-shape.sh
```

```bash
bash tools/verify/m033-p01-pbj-fixture-readme-oracle.sh
```

## Inputs

### From Previous Tasks

None — T01 has no upstream task dependencies.

### From Disk (Pre-existing)

- `tests/fixtures/` — directory must exist; T01 creates `m033-pbj-materials-fixture/` under it.
- `tools/verify/` — directory must exist; T01 creates two new verifier scripts under it.
- The M033 spec body under FR-23 and CON-4 (already on disk at the planning payload location) — re-read only if the inline restatement in this task plan's Description is insufficient.

## Constraints

- The fixture MUST contain exactly 5 inconsistencies — not 4, not 6. SC-4's mechanical assertion is "exactly 5 conflicts surfaced", and the README oracle is the ground truth. Adding a 6th inconsistency silently breaks SC-4.
- The fixture MUST contain NO `src/` directory and NO `.git/` directory. Adding either changes FR-2's branch-detection result for the fixture (rule-3 would fire instead of rule-2).
- The fixture MUST be deterministic — no timestamps, no machine-name embeddings, no `$(date)`, no random tokens. Re-creating the fixture from scratch on a different machine MUST produce byte-identical content.
- The README's numbered-list shape (lines starting `1.`, `2.`, `3.`, `4.`, `5.`) is the parser-load-bearing format. P04's verifier reads this list with a line-prefix regex; deviating from the markdown numbered-list shape silently breaks downstream verification.
- This task creates no `scripts/lifecycle/` files, no `commands/` files, and no `references/` files — the scope is fixture-only. Anything else is out of scope per scope-guard.

## Expected Output

After T01 completes:
- `tests/fixtures/m033-pbj-materials-fixture/` contains 5 files (4 PBJ-shape docs + README).
- `tools/verify/m033-p01-pbj-fixture-shape.sh` and `tools/verify/m033-p01-pbj-fixture-readme-oracle.sh` exist and are executable.
- Both verifiers exit 0 against the authored fixture.
- A summary file at [`.orchestrator/milestones/M033/phases/P01/tasks/T01-pbj-fixture-and-oracle-SUMMARY.md`](../../../../../milestones/M033/phases/P01/tasks/T01-pbj-fixture-and-oracle-SUMMARY.md) documents the deliverables and the 5-inconsistency enumeration (mirrored from the README oracle for cross-reference auditability).

## Notes

Expected verifier output for `m033-p01-pbj-fixture-shape.sh`: a sequence of `PASS:` lines (one per asserted file/token) followed by `SUMMARY: m033-p01-pbj-fixture-shape.sh pass=N fail=0` where N is the assertion count. Same shape for `m033-p01-pbj-fixture-readme-oracle.sh`.

## State Context

- **Current State**: executing
- **Milestone**: M033
- **Phase**: P01
- **Task**: T01-pbj-fixture-and-oracle
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- The fixture MUST contain exactly 5 inconsistencies — not 4, not 6. SC-4's mechanical assertion is "exactly 5 conflicts surfaced", and the README oracle is the ground truth. Adding a 6th inconsistency silently breaks SC-4.
- The fixture MUST contain NO `src/` directory and NO `.git/` directory. Adding either changes FR-2's branch-detection result for the fixture (rule-3 would fire instead of rule-2).
- The fixture MUST be deterministic — no timestamps, no machine-name embeddings, no `$(date)`, no random tokens. Re-creating the fixture from scratch on a different machine MUST produce byte-identical content.
- The README's numbered-list shape (lines starting `1.`, `2.`, `3.`, `4.`, `5.`) is the parser-load-bearing format. P04's verifier reads this list with a line-prefix regex; deviating from the markdown numbered-list shape silently breaks downstream verification.
- This task creates no `scripts/lifecycle/` files, no `commands/` files, and no `references/` files — the scope is fixture-only. Anything else is out of scope per scope-guard.

### Acceptance Criteria

This task addresses these P01 phase truths:
- `tests/fixtures/m033-pbj-materials-fixture/` exists with the four PBJ-shape documents and the 5 inconsistencies.
- `tests/fixtures/m033-pbj-materials-fixture/README.md` is the SC-4 ground-truth oracle.

This task creates these P01 phase artifacts:
- `tests/fixtures/m033-pbj-materials-fixture/{PRODUCT-BRIEF,MVP-PLAN,DECISIONS,MILESTONE-AUDIT,README}.md`
- `tools/verify/m033-p01-pbj-fixture-shape.sh`
- `tools/verify/m033-p01-pbj-fixture-readme-oracle.sh`

### Files To Touch

- `commands/start.md` (create)
- `scripts/lifecycle/start.sh` (create)
- `references/branch-detection.md` (create)
- `tests/m033-acceptance/friendly-tester-pass/protocol.md` (create)
- `tests/m033-acceptance/friendly-tester-pass/report-template.md` (create)
- `tests/m033-acceptance/friendly-tester-pass/validate-report.sh` (create)
- `tests/m033-acceptance/friendly-tester-pass/fixtures/report-pass.md` (create)
- `tests/m033-acceptance/friendly-tester-pass/fixtures/report-fail.md` (create)
- `tests/fixtures/m033-pbj-materials-fixture/PRODUCT-BRIEF.md` (create)
- `tests/fixtures/m033-pbj-materials-fixture/MVP-PLAN.md` (create)
- `tests/fixtures/m033-pbj-materials-fixture/DECISIONS.md` (create)
- `tests/fixtures/m033-pbj-materials-fixture/MILESTONE-AUDIT.md` (create)
- `tests/fixtures/m033-pbj-materials-fixture/README.md` (create)
- `tests/m033-acceptance/p01-start-branch-routing.sh` (create)
- `tests/m033-acceptance/p07-friendly-tester-protocol.sh` (create)
- `tools/verify/m033-p01-start-md-shape.sh` (create)
- `tools/verify/m033-p01-start-sh-flags-and-init-invocation.sh` (create)
- `tools/verify/m033-p01-branch-detection-rules.sh` (create)
- `tools/verify/m033-p01-subflow-stubs-shape.sh` (create)
- `tools/verify/m033-p01-disambiguation-question-shape.sh` (create)
- `tools/verify/m033-p01-branch-detection-ssot-parity.sh` (create)
- `tools/verify/m033-p01-friendly-tester-protocol-shape.sh` (create)
- `tools/verify/m033-p01-report-template-shape.sh` (create)
- `tools/verify/m033-p01-validate-report-sh-contract.sh` (create)
- `tools/verify/m033-p01-validate-report-fixtures-shape.sh` (create)
- `tools/verify/m033-p01-pbj-fixture-shape.sh` (create)
- `tools/verify/m033-p01-pbj-fixture-readme-oracle.sh` (create)
- `tools/verify/m033-p01-acceptance-shape-sc1.sh` (create)
- `tools/verify/m033-p01-acceptance-shape-sc8.sh` (create)
- `tools/verify/m033-p01-phase-suite.sh` (create)
- `tools/verify/m033-p01-scope-guard.sh` (create)

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