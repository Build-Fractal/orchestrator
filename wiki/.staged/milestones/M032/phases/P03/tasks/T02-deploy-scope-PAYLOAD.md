---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T02-deploy-scope (Phase P03, Milestone M032)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~300 | required |
| Upstream Context | 981-1161 | ~4000 | required |
| Task Plan | 1163-1651 | ~6800 | required |
| State Context | 1653-1659 | ~100 | required |
| First-Turn Completeness | 1661-1706 | ~1000 | required |
| **Total** | | **~23000** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 817
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
hit_count: 817
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
hit_count: 817
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
hit_count: 817
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
hit_count: 710
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
hit_count: 710
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
hit_count: 710
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
hit_count: 817
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
hit_count: 710
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
hit_count: 710
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
hit_count: 710
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
hit_count: 817
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
hit_count: 817
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
hit_count: 817
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
hit_count: 710
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
hit_count: 710
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
hit_count: 710
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
hit_count: 817
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
hit_count: 710
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
hit_count: 710
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
hit_count: 817
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
hit_count: 817
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
hit_count: 710
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
hit_count: 710
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
hit_count: 710
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
hit_count: 365
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
hit_count: 365
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
hit_count: 365
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
hit_count: 393
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
hit_count: 393
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
hit_count: 383
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
task: "T02"
phase: "P03"
milestone: "M032"
name: "FR-9 + MIT-007 + MIT-008 --deploy scope on wiki-init.sh + FR-10 cwd sanity gate on wiki-deploy.sh"
depends_on: []
---

## Prerequisites

- `scripts/lifecycle/wiki-init.sh` exists and is executable from P02/T01. T02 modifies it independently of T01's `--with-giscus` amendments. T01 and T02 modify NON-OVERLAPPING sections of the script (T01 adds the `--with-giscus` block AFTER the FR-12 toolchain probe; T02 adds the `--deploy` block AFTER T01's `--with-giscus` block). If T01 and T02 are dispatched in parallel and a merge conflict surfaces, resolve by ordering: `--with-giscus` block first, `--deploy` block second.
- `scripts/wiki/wiki-deploy.sh` exists and is executable from [M012](../../../../../milestones/M012/index.md) baseline. Verified by `[ -x scripts/wiki/wiki-deploy.sh ]`. Behavioral contract: bash 3.2; `set -u`; runs the four pre-deploy gates (giscus-config-check, mkdocs build, link-check, giscus-smoke); runs `mkdocs gh-deploy --force` on the live path; honors `--dry-run`, `--root`, `--skip-smoke`, `--help` flags.
- `wiki/mkdocs.yml` exists with a parsable `repo_url:` field (from P02/T01's FR-6 templating amendment). Verified by `grep -q '^repo_url:' wiki/mkdocs.yml`.
- `gh` CLI MAY be on PATH (T02's live-path code reaches the network; the `M032_DEPLOY_GH_API_STUB=1` env-var shortcuts past it for hermetic verifier coverage). Live-path verification is reserved for SC-5 (T04 deliverable).
- `tests/fixtures/m032-fresh-project-fixture/` exists from P01 with a configured git remote. The verifier scripts in this task use ephemeral tmpdir fixtures and do NOT modify the shared fixture.
- `.orchestrator/execution-log.jsonl` may or may not exist at task start; `wiki-init.sh --deploy` creates it on first append per the JSONL append-only convention.

## Description

T02 lands the highest-blast-radius surface in M032: the `--deploy` scope on `wiki-init.sh` plus the FR-10 cwd-vs-`repo_url:` sanity gate on `wiki-deploy.sh`. The deliverable surface has three pieces that ship together:

1. **FR-10 cwd sanity gate** on `scripts/wiki/wiki-deploy.sh` — a hard precondition that fires BEFORE the existing pre-deploy gates, parsing `repo_url:` from `<PROJECT_ROOT>/wiki/mkdocs.yml` and `git -C $PROJECT_ROOT remote get-url origin`, normalizing both to `<owner>/<repo>` form, and exiting non-zero on mismatch with the `cross-project hazard` diagnostic. This is the Finding J counter-pattern.

2. **FR-9 + MIT-007 + MIT-008 `--deploy` scope** on `scripts/lifecycle/wiki-init.sh` — the four-step ordered sequence (`gh api PATCH /repos/.../discussions=true` → `wiki-deploy.sh` → MIT-007 read-before-write Pages guard → `gh api PUT /repos/.../pages`) followed by the MIT-008 audit-trail JSONL append AFTER step 4 / BEFORE the live URL print. Failure modes append a `result: "failure"` audit record and exit non-zero before printing the URL.

3. **Two verifiers**: `tools/verify/m032-p03-deploy-scope.sh` exercises the workflow end-to-end via `M032_DEPLOY_GH_API_STUB=1` against a tmpdir fixture (no live network); `tools/verify/m032-p03-wiki-deploy-cwd-gate.sh` exercises FR-10 happy-path (matching cwd / remote / repo_url) and mismatch-fails-closed branches.

The atomicity argument for landing all three pieces together: the `--deploy` scope CALLS `wiki-deploy.sh` (which T02 amends with the FR-10 gate); splitting into separate tasks introduces a window where `wiki-init.sh --deploy` invokes a `wiki-deploy.sh` without the FR-10 gate, replicating exactly the cross-project-cwd-hazard the gate was added to prevent. The verifier set must co-author per plan-time discipline rule 2 (no cross-task verifier dependencies).

## Steps

1. **Amend `scripts/wiki/wiki-deploy.sh` with the FR-10 cwd-vs-`repo_url:` sanity gate**. Insert the gate as the FIRST gate (before the existing "gate 1: giscus config-check" block at line ~94). The gate is conditional on `M032_WIKI_DEPLOY_BYPASS_CWD_GATE` env-var: unset/empty/0 → gate fires; `=1` → gate skipped (test-only override for hermetic verifier coverage where the fixture has no real git remote).

Required code block to insert at line ~93 (immediately after the `cd "$ROOT"` line at line 92, before the `# -------- gate 1: giscus config-check --------` comment header):

```bash
# -------- gate 0: FR-10 cwd-vs-repo_url sanity gate (Finding J counter-pattern) --------
# Compares repo_url: parsed from <ROOT>/wiki/mkdocs.yml against
# git -C $ROOT remote get-url origin. Normalizes both to canonical
# <owner>/<repo> form (case-lowered owner, case-preserved repo;
# strip .git suffix; strip https://github.com/ or git@github.com:
# prefixes). Exits non-zero with cross-project-hazard diagnostic on
# mismatch — protects against the silent cross-project force-push
# class of bug observed in the 2026-04-28 PBJ pilot session.
#
# Test-only override: M032_WIKI_DEPLOY_BYPASS_CWD_GATE=1 skips the gate.
# Used ONLY by tools/verify/m032-p03-* verifiers and by the SC-5/SC-6
# acceptance scripts when their fixture has no real GH remote. The
# operator-facing surface never honors this env-var unset path.
if [ "${M032_WIKI_DEPLOY_BYPASS_CWD_GATE:-0}" != "1" ]; then
  if [ ! -f "$ROOT/wiki/mkdocs.yml" ]; then
    printf 'FAIL: wiki-deploy: FR-10 cwd-gate: %s/wiki/mkdocs.yml missing; cannot run cwd-vs-repo_url sanity gate\n' "$ROOT" >&2
    exit 1
  fi
  REPO_URL_LINE=$(grep -E '^repo_url:' "$ROOT/wiki/mkdocs.yml" | head -n 1)
  REPO_URL_VAL=$(printf '%s' "$REPO_URL_LINE" | sed -E 's/^repo_url:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')
  if [ -z "$REPO_URL_VAL" ]; then
    printf 'FAIL: wiki-deploy: FR-10 cwd-gate: cannot parse repo_url: from %s/wiki/mkdocs.yml\n' "$ROOT" >&2
    exit 1
  fi
  GIT_REMOTE_VAL=$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)
  if [ -z "$GIT_REMOTE_VAL" ]; then
    printf 'FAIL: wiki-deploy: FR-10 cwd-gate: no git remote at origin in %s\n' "$ROOT" >&2
    exit 1
  fi
  # Normalize both to <owner>/<repo> form. Strip .git, strip protocol/host prefixes.
  norm_repo() {
    printf '%s' "$1" | sed -E 's#^https?://github\.com/##; s#^git@github\.com:##; s#\.git$##; s#/$##'
  }
  REPO_URL_NORM=$(norm_repo "$REPO_URL_VAL")
  GIT_REMOTE_NORM=$(norm_repo "$GIT_REMOTE_VAL")
  # Owner-lower-case, repo-case-preserved (matches wiki-init.sh's P02 convention).
  REPO_URL_OWNER=$(printf '%s' "$REPO_URL_NORM" | awk -F/ '{print tolower($1)"/"$2}')
  GIT_REMOTE_OWNER=$(printf '%s' "$GIT_REMOTE_NORM" | awk -F/ '{print tolower($1)"/"$2}')
  if [ "$REPO_URL_OWNER" != "$GIT_REMOTE_OWNER" ]; then
    printf 'FAIL: wiki-deploy: cross-project hazard — mkdocs.yml repo_url=%s does not match git remote origin=%s; aborting before gh-deploy. cwd: %s\n' "$REPO_URL_VAL" "$GIT_REMOTE_VAL" "$ROOT" >&2
    exit 1
  fi
  printf 'GATE: cwd-vs-repo_url PASS (%s)\n' "$REPO_URL_OWNER"
fi
```

2. **Amend `scripts/lifecycle/wiki-init.sh`** to recognize `--deploy` and replace the P02-baseline reject-stub. After T01's `--with-giscus` block (or in parallel with T01 — see Description), add the `--deploy` workflow block AFTER T01's `--with-giscus` block and BEFORE the script's existing FR-15 glossary-stub authoring section. Required `--deploy` flag-parsing additions to the flag-parse loop (preserve T01's `--repo`, `--category` arms; add `--force-pages-reconfigure`):

```bash
FORCE_PAGES_RECONFIG=0
# (inside the existing while [ $# -gt 0 ]; do case "$1" in ... esac done loop, add new arm:)
    --force-pages-reconfigure)
      FORCE_PAGES_RECONFIG=1; shift ;;
```

Required `--deploy` workflow block (insert after T01's `--with-giscus` block; the block does NOT depend on `--with-giscus` having run — `--deploy` composes with the default scope OR with `--with-giscus`):

```bash
# FR-9 + MIT-007 + MIT-008 --deploy scope: four-step ordered sequence with
# read-before-write Pages guard and structured JSONL audit-trail.
if [ "$WITH_DEPLOY" = "1" ]; then
  # Parse owner/repo from the project's git remote (re-using the FR-5 logic
  # already executed earlier in this script — ORIGIN_URL / OWNER / REPO are
  # in scope). If --with-wiki was not on the command line, ORIGIN_URL is
  # already populated by the FR-5 block.

  # JSONL log path: <PROJECT_DIR>/.orchestrator/execution-log.jsonl
  # (initialized via mkdir -p .orchestrator/ if absent).
  LOG_DIR="$PROJECT_DIR/.orchestrator"
  LOG_FILE="$LOG_DIR/execution-log.jsonl"
  mkdir -p "$LOG_DIR"

  # Track which mutations actually fire so the audit-trail mutations array
  # reflects the truth on disk. Bash 3.2 — use parallel indexed strings, not
  # arrays of objects.
  MUT_DISCUSSIONS=0
  MUT_GH_PAGES_BRANCH=0
  MUT_PAGES_CONFIGURED=0

  iso_ts() {
    date -u +%Y-%m-%dT%H:%M:%SZ
  }

  # Step 1: enable Discussions via PATCH /repos/<owner>/<repo>.
  step1_rc=0
  case "${M032_DEPLOY_GH_API_STUB:-}" in
    1)
      # Stub mode — read fixture state from M032_DEPLOY_GH_API_STUB_DIR.
      step1_rc=0
      MUT_DISCUSSIONS=1
      ;;
    *)
      set +e
      gh api --method PATCH "/repos/$OWNER/$REPO" -f has_discussions=true >/dev/null 2>&1
      step1_rc=$?
      set -e
      if [ "$step1_rc" -eq 0 ]; then
        MUT_DISCUSSIONS=1
      fi
      ;;
  esac
  if [ "$step1_rc" -ne 0 ]; then
    audit_failure "discussions_enable" "$step1_rc"
    echo "FAIL: wiki-init: --deploy step 1: gh api PATCH /repos/$OWNER/$REPO has_discussions=true exited $step1_rc" >&2
    exit 10
  fi

  # Step 2: invoke wiki-deploy.sh (it runs the FR-10 cwd-gate + the four
  # P02-baseline gates + mkdocs gh-deploy --force).
  step2_rc=0
  case "${M032_DEPLOY_GH_API_STUB:-}" in
    1)
      # Stub mode — skip the deploy invocation entirely (no mkdocs install
      # required for hermetic verifier coverage).
      step2_rc=0
      MUT_GH_PAGES_BRANCH=1
      ;;
    *)
      set +e
      bash "$PROJECT_DIR/scripts/wiki/wiki-deploy.sh" --root "$PROJECT_DIR"
      step2_rc=$?
      set -e
      if [ "$step2_rc" -eq 0 ]; then
        MUT_GH_PAGES_BRANCH=1
      fi
      ;;
  esac
  if [ "$step2_rc" -ne 0 ]; then
    audit_failure "wiki_deploy" "$step2_rc"
    echo "FAIL: wiki-init: --deploy step 2: wiki-deploy.sh exited $step2_rc" >&2
    exit 11
  fi

  # Step 3: MIT-007 read-before-write Pages guard.
  # gh api GET /repos/<owner>/<repo>/pages — inspect .source.branch and .source.path.
  PAGES_RESP=""
  pages_get_rc=0
  case "${M032_DEPLOY_GH_API_STUB:-}" in
    1)
      # Stub mode — read fixture state from $M032_DEPLOY_GH_API_STUB_DIR/pages-get.json
      # (or default to "404 / no Pages configured" if file absent).
      if [ -n "${M032_DEPLOY_GH_API_STUB_DIR:-}" ] && [ -f "$M032_DEPLOY_GH_API_STUB_DIR/pages-get.json" ]; then
        PAGES_RESP="$(cat "$M032_DEPLOY_GH_API_STUB_DIR/pages-get.json")"
        pages_get_rc=0
      else
        PAGES_RESP=""
        pages_get_rc=1  # simulates 404 Not Found
      fi
      ;;
    *)
      set +e
      PAGES_RESP="$(gh api "/repos/$OWNER/$REPO/pages" 2>/dev/null)"
      pages_get_rc=$?
      set -e
      ;;
  esac

  PAGES_PUT_NEEDED=1
  if [ "$pages_get_rc" -eq 0 ] && [ -n "$PAGES_RESP" ]; then
    # Pages exist — inspect source.
    EXISTING_BRANCH=$(printf '%s' "$PAGES_RESP" | sed -n 's/.*"source":{[^}]*"branch":"\([^"]*\)".*/\1/p')
    EXISTING_PATH=$(printf '%s' "$PAGES_RESP" | sed -n 's/.*"source":{[^}]*"path":"\([^"]*\)".*/\1/p')
    if [ "$EXISTING_BRANCH" = "gh-pages" ] && [ "$EXISTING_PATH" = "/" ]; then
      # No-op: already configured for our target source.
      PAGES_PUT_NEEDED=0
      echo "wiki-init: --deploy step 3: pages-already-configured (gh-pages root) — skipping PUT"
    else
      # Incompatible source.
      if [ "$FORCE_PAGES_RECONFIG" -eq 1 ]; then
        echo "wiki-init: --deploy step 3: WARNING — overwriting existing Pages source ($EXISTING_BRANCH $EXISTING_PATH) per --force-pages-reconfigure" >&2
      else
        audit_failure "pages_guard" "$pages_get_rc"
        echo "FAIL: wiki-init: Repository has an existing Pages deployment from a different source ($EXISTING_BRANCH $EXISTING_PATH). This source will be overwritten. Pass --force-pages-reconfigure to proceed, or reconfigure Pages manually before running --deploy." >&2
        exit 12
      fi
    fi
  fi

  # Step 4: PUT /repos/<owner>/<repo>/pages (only if PAGES_PUT_NEEDED).
  if [ "$PAGES_PUT_NEEDED" -eq 1 ]; then
    step4_rc=0
    case "${M032_DEPLOY_GH_API_STUB:-}" in
      1)
        step4_rc=0
        MUT_PAGES_CONFIGURED=1
        ;;
      *)
        set +e
        gh api --method PUT "/repos/$OWNER/$REPO/pages" -f 'source[branch]=gh-pages' -f 'source[path]=/' >/dev/null 2>&1
        step4_rc=$?
        set -e
        if [ "$step4_rc" -eq 0 ]; then
          MUT_PAGES_CONFIGURED=1
        fi
        ;;
    esac
    if [ "$step4_rc" -ne 0 ]; then
      audit_failure "pages_put" "$step4_rc"
      echo "FAIL: wiki-init: --deploy step 4: gh api PUT /repos/$OWNER/$REPO/pages exited $step4_rc" >&2
      exit 13
    fi
  fi

  # Step 5: MIT-008 audit-trail append BEFORE live URL print.
  # NDJSON shape — one line, newline-terminated.
  TS="$(iso_ts)"
  MUTATIONS=""
  if [ "$MUT_DISCUSSIONS" -eq 1 ]; then
    MUTATIONS='{"type":"discussions_enabled"}'
  fi
  if [ "$MUT_GH_PAGES_BRANCH" -eq 1 ]; then
    MUTATIONS="${MUTATIONS:+$MUTATIONS,}"'{"type":"gh_pages_branch_created","ref":"gh-pages"}'
  fi
  if [ "$MUT_PAGES_CONFIGURED" -eq 1 ]; then
    MUTATIONS="${MUTATIONS:+$MUTATIONS,}"'{"type":"pages_source_configured","source":{"branch":"gh-pages","path":"/"}}'
  fi
  printf '{"event_type":"wiki-deploy-mutation","timestamp":"%s","repo":"%s/%s","mutations":[%s],"result":"success"}\n' \
    "$TS" "$OWNER" "$REPO" "$MUTATIONS" >> "$LOG_FILE"

  # Step 6: print live URL.
  OWNER_LOWER_DEPLOY="$(printf '%s' "$OWNER" | tr '[:upper:]' '[:lower:]')"
  printf 'https://%s.github.io/%s/\n' "$OWNER_LOWER_DEPLOY" "$REPO"
fi
```

The `audit_failure` helper (define earlier in the script, near other helpers):

```bash
audit_failure() {
  _step="$1"
  _rc="$2"
  _ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  _muts=""
  if [ "${MUT_DISCUSSIONS:-0}" -eq 1 ]; then
    _muts='{"type":"discussions_enabled"}'
  fi
  if [ "${MUT_GH_PAGES_BRANCH:-0}" -eq 1 ]; then
    _muts="${_muts:+$_muts,}"'{"type":"gh_pages_branch_created","ref":"gh-pages"}'
  fi
  if [ "${MUT_PAGES_CONFIGURED:-0}" -eq 1 ]; then
    _muts="${_muts:+$_muts,}"'{"type":"pages_source_configured","source":{"branch":"gh-pages","path":"/"}}'
  fi
  printf '{"event_type":"wiki-deploy-mutation","timestamp":"%s","repo":"%s/%s","mutations":[%s],"result":"failure","error":"%s: rc=%s"}\n' \
    "$_ts" "${OWNER:-unknown}" "${REPO:-unknown}" "$_muts" "$_step" "$_rc" >> "${LOG_FILE:-/dev/null}"
}
```

Update the file-header exit-code comment block to include the new exit codes 10–13:

```
#  10 — --deploy step 1 (gh api PATCH discussions=true) failed.
#  11 — --deploy step 2 (wiki-deploy.sh) failed.
#  12 — --deploy step 3 (MIT-007 Pages guard rejected incompatible source).
#  13 — --deploy step 4 (gh api PUT /pages) failed.
```

3. **Author `tools/verify/m032-p03-deploy-scope.sh`**. Hermetic stub-mode coverage of the FR-9 / MIT-007 / MIT-008 workflow against a tmpdir fixture. Three coverage branches: (a) happy path with no existing Pages → all three mutations recorded; (b) Pages already configured for `gh-pages` root → discussions + branch entries only (no `pages_source_configured` mutation, true no-op skip), audit record reflects truth; (c) Pages configured for incompatible source without `--force-pages-reconfigure` → exit 12 with diagnostic, partial-failure audit record present.

```bash
#!/usr/bin/env bash
# tools/verify/m032-p03-deploy-scope.sh — FR-9 + MIT-007 + MIT-008 verifier.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WI="$REPO_ROOT/scripts/lifecycle/wiki-init.sh"
pass=0; fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

# Static text checks for the FR-9 + MIT-007 + MIT-008 surface.
for tok in '--deploy' '--force-pages-reconfigure' 'M032_DEPLOY_GH_API_STUB' \
           'M032_DEPLOY_GH_API_STUB_DIR' 'wiki-deploy-mutation' \
           'discussions_enabled' 'gh_pages_branch_created' 'pages_source_configured' \
           'pages-already-configured' 'has_discussions=true' \
           'audit_failure' 'execution-log.jsonl' 'MIT-007' 'MIT-008' 'FR-9'; do
  if grep -qF "$tok" "$WI"; then
    say_pass "wiki-init.sh contains: $tok"
  else
    say_fail "wiki-init.sh missing: $tok"
  fi
done

# Hermetic stub-mode: happy path (no existing Pages).
TMPDIR_F=$(mktemp -d -t m032-p03-deploy.XXXXXX)
trap 'rm -rf "$TMPDIR_F"' EXIT
mkdir -p "$TMPDIR_F/.orchestrator"
(cd "$TMPDIR_F" && git init -q && git remote add origin https://github.com/fixture-owner/m032-p03-deploy.git)

M032_DEPLOY_GH_API_STUB=1 bash "$WI" --deploy --project-dir "$TMPDIR_F" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ] && [ -f "$TMPDIR_F/.orchestrator/execution-log.jsonl" ] && \
   grep -qF '"event_type":"wiki-deploy-mutation"' "$TMPDIR_F/.orchestrator/execution-log.jsonl" && \
   grep -qF '"result":"success"' "$TMPDIR_F/.orchestrator/execution-log.jsonl" && \
   grep -qF '"discussions_enabled"' "$TMPDIR_F/.orchestrator/execution-log.jsonl" && \
   grep -qF '"pages_source_configured"' "$TMPDIR_F/.orchestrator/execution-log.jsonl"; then
  say_pass "stub happy path: rc=0, audit record present with all three mutations"
else
  say_fail "stub happy path: rc=$rc; audit record absent or missing mutations"
fi

# Hermetic stub-mode: Pages already configured for gh-pages root → no-op skip-PUT.
STUB_DIR=$(mktemp -d -t m032-p03-deploy-stub.XXXXXX)
printf '{"source":{"branch":"gh-pages","path":"/"},"html_url":"https://example.github.io/x/"}' \
  > "$STUB_DIR/pages-get.json"
rm -f "$TMPDIR_F/.orchestrator/execution-log.jsonl"
M032_DEPLOY_GH_API_STUB=1 M032_DEPLOY_GH_API_STUB_DIR="$STUB_DIR" bash "$WI" --deploy --project-dir "$TMPDIR_F" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ] && grep -qF '"discussions_enabled"' "$TMPDIR_F/.orchestrator/execution-log.jsonl" && \
   grep -qF '"gh_pages_branch_created"' "$TMPDIR_F/.orchestrator/execution-log.jsonl" && \
   ! grep -qF '"pages_source_configured"' "$TMPDIR_F/.orchestrator/execution-log.jsonl"; then
  say_pass "stub MIT-007 no-op: rc=0, audit record omits pages_source_configured (true no-op skip-PUT)"
else
  say_fail "stub MIT-007 no-op: rc=$rc; audit record shape unexpected"
fi
rm -rf "$STUB_DIR"

# Hermetic stub-mode: Pages incompatible source without --force-pages-reconfigure → exit 12.
STUB_DIR=$(mktemp -d -t m032-p03-deploy-incompat.XXXXXX)
printf '{"source":{"branch":"main","path":"/docs"},"html_url":"https://example.github.io/x/"}' \
  > "$STUB_DIR/pages-get.json"
rm -f "$TMPDIR_F/.orchestrator/execution-log.jsonl"
err_out="$(M032_DEPLOY_GH_API_STUB=1 M032_DEPLOY_GH_API_STUB_DIR="$STUB_DIR" bash "$WI" --deploy --project-dir "$TMPDIR_F" 2>&1)"
rc=$?
if [ "$rc" -eq 12 ] && \
   printf '%s' "$err_out" | grep -qF 'existing Pages deployment from a different source' && \
   grep -qF '"result":"failure"' "$TMPDIR_F/.orchestrator/execution-log.jsonl"; then
  say_pass "stub MIT-007 incompatible: rc=12, diagnostic emitted, failure audit record appended"
else
  say_fail "stub MIT-007 incompatible: rc=$rc; expected exit 12 + diagnostic + failure record"
fi
rm -rf "$STUB_DIR"

printf 'SUMMARY: m032-p03-deploy-scope pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

4. **Author `tools/verify/m032-p03-wiki-deploy-cwd-gate.sh`**. Two coverage branches: (a) gate fires on cwd / repo_url mismatch (`cross-project hazard` diagnostic + non-zero exit); (b) gate skipped under `M032_WIKI_DEPLOY_BYPASS_CWD_GATE=1`.

```bash
#!/usr/bin/env bash
# tools/verify/m032-p03-wiki-deploy-cwd-gate.sh — FR-10 verifier.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WD="$REPO_ROOT/scripts/wiki/wiki-deploy.sh"
pass=0; fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

for tok in 'FR-10' 'cross-project hazard' 'cwd-vs-repo_url' 'repo_url' \
           'M032_WIKI_DEPLOY_BYPASS_CWD_GATE' 'GATE: cwd-vs-repo_url'; do
  if grep -qF "$tok" "$WD"; then
    say_pass "wiki-deploy.sh contains: $tok"
  else
    say_fail "wiki-deploy.sh missing: $tok"
  fi
done

# Hermetic mismatch fixture.
TMPDIR_F=$(mktemp -d -t m032-p03-cwd-gate.XXXXXX)
trap 'rm -rf "$TMPDIR_F"' EXIT
mkdir -p "$TMPDIR_F/wiki"
printf 'site_name: "fixture"\nrepo_url: "https://github.com/owner-A/repo-A"\n' > "$TMPDIR_F/wiki/mkdocs.yml"
(cd "$TMPDIR_F" && git init -q && git remote add origin https://github.com/owner-B/repo-B.git)

err_out="$(bash "$WD" --root "$TMPDIR_F" --dry-run 2>&1)"
rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$err_out" | grep -qF 'cross-project hazard'; then
  say_pass "FR-10 mismatch: rc=$rc with cross-project hazard diagnostic"
else
  say_fail "FR-10 mismatch: rc=$rc; expected non-zero with diagnostic"
fi

# Bypass override.
M032_WIKI_DEPLOY_BYPASS_CWD_GATE=1 bash "$WD" --root "$TMPDIR_F" --dry-run >/dev/null 2>&1
rc_bypass=$?
# rc_bypass may still be non-zero (mkdocs not installed in the tmpdir), but
# it should NOT be a FR-10 cwd-gate failure. Distinguish by checking stderr:
err_out="$(M032_WIKI_DEPLOY_BYPASS_CWD_GATE=1 bash "$WD" --root "$TMPDIR_F" --dry-run 2>&1 || true)"
if printf '%s' "$err_out" | grep -qF 'cross-project hazard'; then
  say_fail "FR-10 bypass: cross-project-hazard fired despite M032_WIKI_DEPLOY_BYPASS_CWD_GATE=1"
else
  say_pass "FR-10 bypass: cross-project-hazard skipped under M032_WIKI_DEPLOY_BYPASS_CWD_GATE=1"
fi

printf 'SUMMARY: m032-p03-wiki-deploy-cwd-gate pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

5. **Make verifier scripts executable**: `chmod +x tools/verify/m032-p03-deploy-scope.sh tools/verify/m032-p03-wiki-deploy-cwd-gate.sh`.

## Must-Haves

- FR-10 cwd-vs-`repo_url:` sanity gate on `wiki-deploy.sh` with `cross-project hazard` diagnostic and `M032_WIKI_DEPLOY_BYPASS_CWD_GATE=1` test-only bypass
- FR-9 + MIT-007 + MIT-008 `--deploy` scope on `wiki-init.sh` (four-step ordered sequence; read-before-write Pages guard with `--force-pages-reconfigure` escape hatch; structured `wiki-deploy-mutation` JSONL audit-trail record append BEFORE live URL print, with mutations-array reflecting actual fired steps and a failure-mode `result: "failure"` record + named error step)
- Two project-owned verifiers: `tools/verify/m032-p03-deploy-scope.sh`, `tools/verify/m032-p03-wiki-deploy-cwd-gate.sh`

## Verification

```bash
bash tools/verify/m032-p03-deploy-scope.sh
```

```bash
bash tools/verify/m032-p03-wiki-deploy-cwd-gate.sh
```

## Notes

Expected output of each verifier: the final line is `SUMMARY: <name> pass=<N> fail=0` and exit code is 0.

The live `--deploy` workflow is exercised end-to-end ONLY by SC-5 (T04 deliverable) against a throwaway GH repo per CON-5 / `tests/m032-acceptance/throwaway-fixture-protocol.md`. T02's verifiers cover stub-mode hermetic branches; the full live-network coverage is T04's job.

The `M032_DEPLOY_GH_API_STUB` env-var follows the M026/MEM030 `<TOOL>_*` env-var convention. The operator-facing surface MUST NOT honor this var unset path implicitly; it is test-only. The `M032_DEPLOY_GH_API_STUB_DIR` companion env-var lets verifiers parameterize the stubbed `gh api GET /pages` response to exercise MIT-007 branches (404, gh-pages-root, incompatible-source).

The audit-trail JSONL append is INTENTIONAL even on partial failure (a `result: "failure"` record is appended with the failed step name and stderr-tail). This makes operator-visible the difference between "deploy never started" (no record) and "deploy started and failed at step X" (failure record). Constitution VI (State On Disk Is Truth) — remote-state mutations have an on-disk audit trail.

Bash 3.2 gotcha for the JSONL emit: the `mutations` array is built as a literal-string concatenation rather than a structured JSON-array-builder because bash 3.2 lacks `declare -A` and structured serialization libraries. The `${MUTATIONS:+$MUTATIONS,}` expansion is a parameter-expansion-safe way to elide the leading comma when the prior mutation set is empty.

## Inputs

### From Previous Tasks

(none from within P03 — T02 is independent of T01/T03/T04; depends only on P02 artifacts; T01 and T02 modify non-overlapping sections of `wiki-init.sh`)

### From Disk (Pre-existing)

- `scripts/lifecycle/wiki-init.sh` (P02/T01) — bash 3.2 default-scope script. T02 amends it to add `--deploy` handling and the `audit_failure` helper. T01 (in parallel) adds `--with-giscus` handling. The two amendments live at non-overlapping line ranges.
- `scripts/wiki/wiki-deploy.sh` (M012 baseline) — chained deploy wrapper. T02 inserts the FR-10 gate-0 block at line ~93 (after the `cd "$ROOT"` line, before "gate 1"). The existing four gates are NOT modified.
- `wiki/mkdocs.yml` (P02/T01) — carries `repo_url:` field that the FR-10 gate parses.
- `scripts/diagnostics/giscus-ids-from-gh.sh`, `scripts/diagnostics/wiki-giscus-config-check.sh` — read-only references; T02 does NOT modify either (T01's domain).
- `tests/fixtures/m032-fresh-project-fixture/` (P01) — referenced for context only; T02's verifiers use ephemeral tmpdir fixtures.

## Constraints

- Single-script-file shape for ALL verifier `Check:` commands per AD-19.
- bash 3.2 compatibility (per MEM001) — NDJSON shape built via `printf` literal-string concatenation; no `declare -A`; no process substitution; no command substitution containing pipes (use `sed -n` chains and intermediate variables).
- Verifier scripts MUST live under `tools/verify/` with the `m032-p03-*` prefix per AD-19 path discipline.
- No modifications to P02-owned files (`commands/init.md`, `scripts/lifecycle/init-project.sh`, `wiki/glossary.md`, `scripts/wiki/wiki-scan-sources.sh`, `scripts/knowledge/lookup-mems.sh`, the paired-launch seam scripts) or P01-owned files (`packaging/install/install-*.sh`, `packaging/bundle/manifest.yml`, `tests/fixtures/m032-fresh-project-fixture/.gitignore`).
- The `audit_failure` helper MUST be defined ONCE in `wiki-init.sh` (early, near other helpers); failure-paths in step 1, step 2, step 3, step 4 ALL invoke it.
- The MIT-008 audit-trail JSONL append is the LAST action before printing the live URL on success — order is load-bearing per the spec ("MUST be appended before the live URL is printed to stdout"). The verifier MUST exercise this ordering invariant (the verifier's grep for the audit record runs AFTER `wiki-init.sh` has exited, so any URL-print-before-record race would surface as a missing record).
- Co-author the two verifier scripts within T02 — do NOT defer them to T05 per plan-time discipline rule 2. T05 only authors the phase-suite + scope-guard.

## Expected Output

After T02 completes:

- `scripts/wiki/wiki-deploy.sh` carries the FR-10 gate-0 block, fires on cwd / repo_url mismatch, can be bypassed under `M032_WIKI_DEPLOY_BYPASS_CWD_GATE=1`.
- `scripts/lifecycle/wiki-init.sh` recognizes `--deploy --force-pages-reconfigure` and implements the four-step FR-9 / MIT-007 / MIT-008 sequence with audit-trail append.
- `tools/verify/m032-p03-deploy-scope.sh` and `tools/verify/m032-p03-wiki-deploy-cwd-gate.sh` exist and exit 0.
- The three `Check:` commands listed in P03-PLAN.md's "Truths" section for T02-owned truths return exit 0.

## State Context

- **Current State**: executing
- **Milestone**: M032
- **Phase**: P03
- **Task**: T02-deploy-scope
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- Single-script-file shape for ALL verifier `Check:` commands per AD-19.
- bash 3.2 compatibility (per MEM001) — NDJSON shape built via `printf` literal-string concatenation; no `declare -A`; no process substitution; no command substitution containing pipes (use `sed -n` chains and intermediate variables).
- Verifier scripts MUST live under `tools/verify/` with the `m032-p03-*` prefix per AD-19 path discipline.
- No modifications to P02-owned files (`commands/init.md`, `scripts/lifecycle/init-project.sh`, `wiki/glossary.md`, `scripts/wiki/wiki-scan-sources.sh`, `scripts/knowledge/lookup-mems.sh`, the paired-launch seam scripts) or P01-owned files (`packaging/install/install-*.sh`, `packaging/bundle/manifest.yml`, `tests/fixtures/m032-fresh-project-fixture/.gitignore`).
- The `audit_failure` helper MUST be defined ONCE in `wiki-init.sh` (early, near other helpers); failure-paths in step 1, step 2, step 3, step 4 ALL invoke it.
- The MIT-008 audit-trail JSONL append is the LAST action before printing the live URL on success — order is load-bearing per the spec ("MUST be appended before the live URL is printed to stdout"). The verifier MUST exercise this ordering invariant (the verifier's grep for the audit record runs AFTER `wiki-init.sh` has exited, so any URL-print-before-record race would surface as a missing record).
- Co-author the two verifier scripts within T02 — do NOT defer them to T05 per plan-time discipline rule 2. T05 only authors the phase-suite + scope-guard.

### Acceptance Criteria

- FR-10 cwd-vs-`repo_url:` sanity gate on `wiki-deploy.sh` with `cross-project hazard` diagnostic and `M032_WIKI_DEPLOY_BYPASS_CWD_GATE=1` test-only bypass
- FR-9 + MIT-007 + MIT-008 `--deploy` scope on `wiki-init.sh` (four-step ordered sequence; read-before-write Pages guard with `--force-pages-reconfigure` escape hatch; structured `wiki-deploy-mutation` JSONL audit-trail record append BEFORE live URL print, with mutations-array reflecting actual fired steps and a failure-mode `result: "failure"` record + named error step)
- Two project-owned verifiers: `tools/verify/m032-p03-deploy-scope.sh`, `tools/verify/m032-p03-wiki-deploy-cwd-gate.sh`

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