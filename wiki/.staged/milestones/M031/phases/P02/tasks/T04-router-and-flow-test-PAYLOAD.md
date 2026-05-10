---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T04-router-and-flow-test (Phase P02, Milestone M031)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-978 | ~500 | required |
| Upstream Context | 980-1056 | ~3000 | required |
| Task Plan | 1058-1239 | ~4300 | required |
| State Context | 1241-1247 | ~100 | required |
| First-Turn Completeness | 1249-1309 | ~1000 | required |
| **Total** | | **~19700** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 703
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
hit_count: 703
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
hit_count: 703
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
hit_count: 703
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
hit_count: 616
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
hit_count: 616
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
hit_count: 616
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
hit_count: 703
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
hit_count: 616
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
hit_count: 616
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
hit_count: 616
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
hit_count: 703
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
hit_count: 703
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
hit_count: 703
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
hit_count: 616
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
hit_count: 616
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
hit_count: 616
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
hit_count: 703
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
hit_count: 616
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
hit_count: 616
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
hit_count: 703
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
hit_count: 703
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
hit_count: 616
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
hit_count: 616
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
hit_count: 616
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
hit_count: 271
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
hit_count: 271
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
hit_count: 271
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
hit_count: 279
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
hit_count: 279
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
hit_count: 269
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
     Namespacing: `m031-p02-*` prefix avoids collision with [M030](../../../../../milestones/M030/index.md)'s
     existing `p02-*` verifiers in the shared tools/verify/ tree. -->

### Truths

- `scripts/intake/shape-detect.sh` and `scripts/intake/paragraph-classify.sh` accept the M024 input surface unchanged AND emit a fourth verdict value `tier_a_plus` (additive to the existing `idea | paragraph | fragment | spec | empty` enum, AD-2 / CON-3). The Tier A+ heuristic boundary is documented inline in each classifier's body and grounded by `tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md` per AD-16. Word-count and structural-marker heuristics for the existing four verdicts MUST stay byte-equal (no regression on M024 fixtures).
  - Check: `bash tools/verify/m031-p02-classifier-extension-shape.sh`

- `tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md` exists with at least one historical `.orchestrator/` JSONL `unit_close` record cited by `<milestone>/<phase>/<task>` provenance, plus the annotator's classification rationale for why the cited record is a Tier A+ candidate (AD-16). The file is normative — no Tier A+ verifier may pass without its existence.
  - Check: `bash tools/verify/m031-p02-fixture-provenance-shape.sh`

- `tests/m031-acceptance/fixtures/tier-a-plus-input.txt` exists with a 30–80 word feature-request fixture matching the Tier A+ heuristic (input the classifier classifies as `tier_a_plus` with high confidence). The fixture body is keyed to the `FIXTURE-PROVENANCE.md` rationale (a paraphrase of one of the cited historical records).
  - Check: `bash tools/verify/m031-p02-tier-a-plus-input-shape.sh`

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

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P02"
milestone: "M031"
name: "Tier A+ router (FR-7) + JSONL unit_close schema additions + SC-6 end-to-end flow test"
depends_on: ["T03"]
---

## Prerequisites

- T01 complete: classifier emits `tier_a_plus` (verified via SC-5 test).
- T02 complete: `scripts/intake/lib/task-slug.sh` + three role templates on disk.
- T03 complete: `scripts/intake/lib/tier-a-plus-prompt.sh` + SC-16 test on disk.
- Active dispatch surface for the orchestrator is the existing `commands/dispatch.md` flow (one-shot, single-context dispatch; the agent runtime is the adapter per MEM018). T04's router does NOT replace dispatch; it sequences three calls into the existing dispatch surface.
- `scripts/intake/route-to-dispatch.sh` (54 lines pre-T04) currently handles a single `orchestrator:dispatch` invocation derived from a proposal frontmatter. T04 extends this surface — it does NOT replace the existing single-dispatch path.

## Description

T04 amends `scripts/intake/route-to-dispatch.sh` to recognize a `tier_a_plus` verdict and chain exactly three sequential dispatches in this order:

1. **research dispatch** — invoked with `templates/dispatch-role-research.md` as the role payload, `--profile=quick` per the P01 reconciled `commands/dispatch.md`. Output: `.orchestrator/tier-a-plus/<task-slug>/research.md`. Emits one JSONL `unit_close` record with `tier_a_plus_role: research` and `aborted: false` on success (or `aborted: true` if the dispatch itself fails).
2. **operator prompt gate** — `bash scripts/intake/lib/tier-a-plus-prompt.sh --research-path <path> --task-slug <slug> [--yes] [--session-id <id>]` (T03 helper). Exit codes: 0 = proceed, 1 = re-run research (router exits non-zero, no plan/build dispatch), 2 = abort flow (router exits non-zero, no plan/build dispatch).
3. **plan dispatch** (only if prompt exit 0) — invoked with `templates/dispatch-role-plan.md` as the role payload, `--profile=quick`. Output: `.orchestrator/tier-a-plus/<task-slug>/plan.md`. Emits one `unit_close` record with `tier_a_plus_role: plan`.
4. **build dispatch** (only if plan dispatch succeeded) — invoked with `templates/dispatch-role-build.md` as the role payload, `--profile=quick`. The build agent reads `<task-slug>/plan.md`, executes the steps, and runs the plan's `## Verification` commands inline. Build dispatch exits non-zero on any verifier failure (no implicit retry per spec edge case). Emits one `unit_close` record with `tier_a_plus_role: build` and `aborted: <true|false>` reflecting verifier-pass result.

The router MUST honor every CON-4 / DC-4 / Principle XIV invariant:
- MUST NOT invoke `orchestrator:auto`, `orchestrator:roadmap`, or `orchestrator:consolidate`.
- MUST NOT acquire any auto-loop lock file under any path.
- MUST NOT write any `.orchestrator/milestones/M###/` scaffolding.
- MUST NOT introduce a new state machine, lock file, or roadmap surface.
- MAY write the per-flow scratch directory `.orchestrator/tier-a-plus/<task-slug>/` (research.md, plan.md, .session-id sidecar). This is NOT a state-machine surface — it's an output directory consistent with `.orchestrator/observability/` from P01.

T04 ships:

1. The amended `scripts/intake/route-to-dispatch.sh`.
2. JSONL `unit_close` schema additions: two new optional fields `tier_a_plus_role` (enum `research|plan|build`) and `aborted` (boolean). Existing records without these fields stay valid (additive schema per the M031 cross-cutting invariant).
3. `tests/m031-acceptance/test-tier-a-plus-flow.sh` — SC-6 end-to-end test.
4. `tools/verify/m031-p02-router-shape.sh` — shape verifier for the router.
5. `tools/verify/m031-p02-test-tier-a-plus-flow-shape.sh` — shape verifier for the SC-6 test.

## Steps

1. **Read the existing `scripts/intake/route-to-dispatch.sh`** (54 lines pre-T04). Identify (a) the proposal-frontmatter parsing, (b) the `recommended_command` switch, (c) the single-dispatch invocation shape `invoke=orchestrator:dispatch --proposal $PROPOSAL`.

2. **Extend the router CLI surface.** Add a new invocation mode that accepts a `--verdict tier_a_plus --task <description>` flag pair (the dispatched-by-classifier flow) AND a `--role <research|plan|build>` flag for sub-dispatch entry points. The existing single-dispatch path (proposal-frontmatter → recommended_command) MUST keep working byte-equal — the Tier A+ chain is a NEW branch in the existing switch, not a rewrite.

3. **Implement the Tier A+ chain.** Concrete sequence the router executes:
   - Source `scripts/intake/lib/task-slug.sh`. Compute `<task-slug>` via `derive_task_slug "$task_description"`.
   - Create `.orchestrator/tier-a-plus/<task-slug>/` (mkdir -p) if absent.
   - Write `.orchestrator/tier-a-plus/<task-slug>/.session-id` with the current session-id (a generated unique ID; e.g., `date -u +%Y%m%dT%H%M%S` plus a 4-character random hex). The T03 prompt helper reads this sidecar to derive the resume-vs-rerun marker.
   - **Research dispatch**. Invoke the dispatch surface with the research role payload + `--profile=quick`. Concrete shape (the `dispatch_one_role` helper internal to the router):
     - Build a research-role task plan from `templates/dispatch-role-research.md` plus the operator's task description.
     - Invoke `bash scripts/dispatch/build-context.sh --profile=quick --task-plan <tmp-plan> --out <payload> --meta-out <meta-sidecar>`.
     - Hand the resulting payload to the agent runtime per the existing single-dispatch convention (the agent IS the adapter per MEM018).
     - On dispatch success, the agent writes `<task-slug>/research.md`. On dispatch failure, the router emits a `unit_close` JSONL record with `tier_a_plus_role: research`, `aborted: true` and exits non-zero.
   - **Prompt gate**. Invoke `bash scripts/intake/lib/tier-a-plus-prompt.sh --research-path .orchestrator/tier-a-plus/<task-slug>/research.md --task-slug <task-slug> [--yes] --session-id <id>`. Read exit code:
     - 0 → proceed to plan dispatch.
     - 1 or 2 → emit `unit_close` for the research dispatch with `aborted: false`, no further records, router exits non-zero.
   - **Plan dispatch** (only if prompt exit 0). Same shape as research dispatch but with `dispatch-role-plan.md`. Plan agent reads upstream `<task-slug>/research.md` (the role template declares this in its `## Inputs` block) and writes `<task-slug>/plan.md`. Emits `unit_close` with `tier_a_plus_role: plan`, `aborted: false` on success.
   - **Build dispatch** (only if plan dispatch succeeded). Same shape with `dispatch-role-build.md`. Build agent reads `<task-slug>/plan.md`, executes its steps, runs its `## Verification` commands inline. On any verifier failure the build dispatch exits non-zero and emits `unit_close` with `tier_a_plus_role: build`, `aborted: true`. On full success emits `unit_close` with `aborted: false`.

4. **JSONL `unit_close` schema additions.** The two new optional fields ride on every Tier A+ `unit_close` record:
   - `tier_a_plus_role` — string enum: `research` | `plan` | `build`. Absent on non-Tier-A+ records.
   - `aborted` — boolean. Defaults to `false` on success paths; `true` on cancel/abort/verifier-failure paths. May appear on non-Tier-A+ records too (advisory; future milestones may consume).

   Use the existing JSONL emitter in the router/dispatch surface; do not introduce a new emitter. Bash 3.2 string concatenation is sufficient — quote-escape the role/aborted values per existing conventions.

5. **Author `tests/m031-acceptance/test-tier-a-plus-flow.sh`** (executable, bash 3.2). SC-6 contract:
   - Set up a temp scratch dir for `.orchestrator/tier-a-plus/<test-slug>/` (under `.orchestrator/observability/` prefix-equivalent or under `tmp/` per AP-009 / `run-probe.sh` discipline; the SC-6 test does not need to exercise the real `.orchestrator/` tree).
   - Invoke `bash scripts/intake/route-to-dispatch.sh --verdict tier_a_plus --task "<fixture-task-description>" --yes` (with `--yes` to skip the interactive prompt) against a stub dispatch surface. The stub MAY be a fake `build-context.sh` that emits canned payloads (the SC-6 test does not need to exercise real LLM dispatch — it needs to verify the router's shape).
   - Assert exactly 3 `unit_close` JSONL records appear with `tier_a_plus_role: research`, `tier_a_plus_role: plan`, `tier_a_plus_role: build` (one each).
   - Assert `<task-slug>/research.md` exists.
   - Assert `<task-slug>/plan.md` exists.
   - Assert ZERO files are created under any path matching `.orchestrator/milestones/M*/`.
   - Assert ZERO files are created matching the literal substring `lock` anywhere outside the test scratch tree.
   - Under `--yes` mode: assert ZERO interactive prompt was emitted (no characters consumed from stdin) and exactly one `research: <path>` line on stderr.
   - Output: `RESULT: SC-6 pass` / `RESULT: SC-6 fail`. Exit 0 iff pass.

6. **Author `tools/verify/m031-p02-router-shape.sh`** (executable, bash 3.2). Contract:
   - Assert `scripts/intake/route-to-dispatch.sh` exists, executable, ≥ 100 lines (the pre-T04 baseline + the new chain logic).
   - Assert the file contains the literal substrings `tier_a_plus`, `tier_a_plus_role`, `aborted`, `research`, `plan`, `build`, `--profile=quick`, `task-slug.sh`, `tier-a-plus-prompt.sh`.
   - Assert the file does NOT contain the literal substrings `orchestrator:auto`, `orchestrator:roadmap`, or `orchestrator:consolidate` (CON-4 grep — the router MUST NOT invoke any of those three commands).
   - Assert the file does NOT introduce any `mkdir -p .orchestrator/milestones/` line (no milestone scaffolding write).
   - Assert the file does NOT introduce any `lock` file write under `.orchestrator/auto/`.
   - Output: a single final stdout line `SUMMARY: m031-p02-router-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

7. **Author `tools/verify/m031-p02-test-tier-a-plus-flow-shape.sh`** (executable, bash 3.2). Contract:
   - Assert `tests/m031-acceptance/test-tier-a-plus-flow.sh` exists, executable, ≥ 60 lines.
   - Assert the file contains the literal substrings `SC-6`, `tier_a_plus_role`, `research`, `plan`, `build`, `aborted`, `--yes`.
   - Output: a single final stdout line `SUMMARY: m031-p02-test-tier-a-plus-flow-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

8. **Run the two new shape verifiers + the SC-6 acceptance test** to confirm exit 0:

   ```bash
   bash tools/verify/m031-p02-router-shape.sh
   ```

   ```bash
   bash tools/verify/m031-p02-test-tier-a-plus-flow-shape.sh
   ```

   ```bash
   bash tests/m031-acceptance/test-tier-a-plus-flow.sh
   ```

9. **Confirm the existing single-dispatch path unchanged.** Sanity-check by invoking the router with the pre-T04 invocation form (`bash scripts/intake/route-to-dispatch.sh --proposal <fixture-proposal>`) and confirming the `invoke=orchestrator:dispatch --proposal <path>` stdout line still emits byte-equal.

## Must-Haves

This task addresses the following Must-Haves from `P02-PLAN.md`:
- "scripts/intake/route-to-dispatch.sh recognizes tier_a_plus verdict and chains three sequential dispatches" (Truth #7; Check via `m031-p02-router-shape.sh`)
- "tests/m031-acceptance/test-tier-a-plus-flow.sh (SC-6) exists, executable, exits 0" (Truth #9; Check via `m031-p02-test-tier-a-plus-flow-shape.sh`)

## Verification

```bash
bash tools/verify/m031-p02-router-shape.sh
```

```bash
bash tools/verify/m031-p02-test-tier-a-plus-flow-shape.sh
```

```bash
bash tests/m031-acceptance/test-tier-a-plus-flow.sh
```

## Notes

- The router stub-vs-real-dispatch question: SC-6 verifies router *shape* (three records, two markdown outputs, no scaffolding, no locks, no prompts under `--yes`). It does NOT need to exercise real LLM dispatch — a stub `build-context.sh` writing canned payloads to the configured `--out` and `--meta-out` paths suffices. Future P04 acceptance-battery aggregator runs the SC-6 test under the same stub regime.
- JSONL `unit_close` records emit through whatever path the existing dispatch surface already uses (per the single-dispatch baseline). T04 does NOT introduce a new emitter — the two new fields ride on existing records.
- The `--yes` flag flows from the router's CLI through to the prompt helper. Under `--yes` the router MUST NOT consume any byte from stdin; the prompt helper exits 0 immediately after emitting the `research: <path>` audit line.
- Bash 3.2 compatibility (MEM001): no `declare -A`, no process substitution, no `$()` containing pipes inside conditionals.
- D020 token hygiene (CON-7): comments and prose in the router MUST NOT embed the scaffold-placeholder marker bracket-TODO byte pattern; paraphrase or escape.
- The existing `auto_proceeded: true` proposal-frontmatter side-effect (router mutates `proceeded_at`) is preserved verbatim — the Tier A+ chain is an additive branch, not a replacement.

## Inputs

### From Previous Tasks

- `scripts/intake/shape-detect.sh` (modified by T01) — emits `input_shape=tier_a_plus`. The router's verdict-recognition reads this line. Key API: `bash scripts/intake/shape-detect.sh --input <string>` emits two stdout lines.
- `scripts/intake/lib/task-slug.sh` (created by T02) — sourceable; exposes `derive_task_slug <description>` returning `<40-char-lower-hyphen-alnum>[-<sha1-4>]`. Router sources the file and calls the function once per Tier A+ flow.
- `templates/dispatch-role-research.md`, `templates/dispatch-role-plan.md`, `templates/dispatch-role-build.md` (created by T02) — prescriptive role templates. Router invokes the dispatch surface with the corresponding template path per role.
- `scripts/intake/lib/tier-a-plus-prompt.sh` (created by T03) — sourceable + invokable; exit codes 0 (proceed) / 1 (re-run) / 2 (abort). Router invokes with `--research-path`, `--task-slug`, `--session-id`, optional `--yes`. Key API: see T03 plan for the full invocation contract.

### From Disk (Pre-existing)

- `scripts/intake/route-to-dispatch.sh` (54 lines) — existing M024/P03/T03 single-dispatch router. T04 amends additively. Key API today: `bash scripts/intake/route-to-dispatch.sh --proposal <path>`; emits `invoke=orchestrator:dispatch --proposal <path>` stdout line and (when proposal carries `auto_proceeded: true`) emits `auto_proceed=1` line + mutates `proceeded_at`.
- `scripts/dispatch/build-context.sh` (modified by P01) — accepts `--profile=quick|standard|full`, `--task-plan`, `--out`, `--meta-out`. Router invokes with `--profile=quick` for every Tier A+ sub-dispatch.
- `commands/dispatch.md` (modified by P01) — Quick row reads "knowledge + compression with the Quick profile" (FR-4). The router's invocation shape complies with this contract.
- `templates/orchestrator-config-default.yml` — declares `tier_a_plus_prompt_summary_lines: 8` (P00 default). The router does not read this knob directly — it passes the read-responsibility to T03's prompt helper.

## Constraints

- **Bash 3.2 compatibility** (MEM001): no `declare -A`, no process substitution, no `$()` containing pipes inside conditionals.
- **Strictly additive** to `scripts/intake/route-to-dispatch.sh`: existing single-dispatch path (proposal-frontmatter → `invoke=orchestrator:dispatch --proposal <path>`) MUST keep working byte-equal.
- **No edits to `scripts/intake/shape-detect.sh` / `paragraph-classify.sh`** in T04 (T01 owns those edits).
- **No edits to `scripts/intake/lib/`** in T04 (T02 + T03 own the lib helpers; T04 sources/invokes them).
- **No edits to `templates/dispatch-role-*.md`** in T04 (T02 owns those templates).
- **No edits to `templates/orchestrator-config-default.yml`** in T04.
- **No `orchestrator:auto` / `orchestrator:roadmap` / `orchestrator:consolidate` invocations** anywhere in the router (CON-4 / DC-4 — verified by `m031-p02-router-shape.sh` grep).
- **No new lock files** under any path (CON-4 — verified by router-shape grep).
- **No `.orchestrator/milestones/M###/` scaffolding writes** (CON-4 — verified by router-shape grep for `mkdir -p .orchestrator/milestones/`).
- **SC-12 scope-guard**: T04 MUST NOT touch `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, or `scripts/auto/loop/`.
- **Verifier path discipline** (AD-19 + [M032](../../../../../milestones/M032/index.md) Finding A): project-owned slug-bearing verifiers live under `tools/verify/`, NOT `scripts/verify/`.

## Expected Output

After T04 completes:

1. `scripts/intake/route-to-dispatch.sh` recognizes `--verdict tier_a_plus` and chains three sequential dispatches (research → prompt → plan → build) emitting JSONL `unit_close` records with `tier_a_plus_role` and `aborted` fields.
2. The pre-T04 single-dispatch path (`--proposal <path>`) remains byte-equal in stdout output.
3. `tests/m031-acceptance/test-tier-a-plus-flow.sh` exists, executable, exits 0 (`RESULT: SC-6 pass`).
4. `tools/verify/m031-p02-router-shape.sh` exists, executable, exits 0.
5. `tools/verify/m031-p02-test-tier-a-plus-flow-shape.sh` exists, executable, exits 0.
6. No `.orchestrator/milestones/M###/` scaffolding written; no lock file written; no parallel routing implementation introduced (CON-3 grep clean).

T04 closes the Tier A+ middle flow on disk. T05 ships the phase-suite aggregator + SC-12 scope-guard that close the phase mechanically.

## State Context

- **Current State**: executing
- **Milestone**: M031
- **Phase**: P02
- **Task**: T04-router-and-flow-test
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **Bash 3.2 compatibility** (MEM001): no `declare -A`, no process substitution, no `$()` containing pipes inside conditionals.
- **Strictly additive** to `scripts/intake/route-to-dispatch.sh`: existing single-dispatch path (proposal-frontmatter → `invoke=orchestrator:dispatch --proposal <path>`) MUST keep working byte-equal.
- **No edits to `scripts/intake/shape-detect.sh` / `paragraph-classify.sh`** in T04 (T01 owns those edits).
- **No edits to `scripts/intake/lib/`** in T04 (T02 + T03 own the lib helpers; T04 sources/invokes them).
- **No edits to `templates/dispatch-role-*.md`** in T04 (T02 owns those templates).
- **No edits to `templates/orchestrator-config-default.yml`** in T04.
- **No `orchestrator:auto` / `orchestrator:roadmap` / `orchestrator:consolidate` invocations** anywhere in the router (CON-4 / DC-4 — verified by `m031-p02-router-shape.sh` grep).
- **No new lock files** under any path (CON-4 — verified by router-shape grep).
- **No `.orchestrator/milestones/M###/` scaffolding writes** (CON-4 — verified by router-shape grep for `mkdir -p .orchestrator/milestones/`).
- **SC-12 scope-guard**: T04 MUST NOT touch `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, or `scripts/auto/loop/`.
- **Verifier path discipline** (AD-19 + M032 Finding A): project-owned slug-bearing verifiers live under `tools/verify/`, NOT `scripts/verify/`.

### Acceptance Criteria

This task addresses the following Must-Haves from `P02-PLAN.md`:
- "scripts/intake/route-to-dispatch.sh recognizes tier_a_plus verdict and chains three sequential dispatches" (Truth #7; Check via `m031-p02-router-shape.sh`)
- "tests/m031-acceptance/test-tier-a-plus-flow.sh (SC-6) exists, executable, exits 0" (Truth #9; Check via `m031-p02-test-tier-a-plus-flow-shape.sh`)

### Files To Touch

- `scripts/intake/shape-detect.sh` (modify)
- `scripts/intake/paragraph-classify.sh` (modify)
- `scripts/intake/route-to-dispatch.sh` (modify)
- `scripts/intake/lib/task-slug.sh` (create)
- `scripts/intake/lib/tier-a-plus-prompt.sh` (create)
- `templates/dispatch-role-research.md` (create)
- `templates/dispatch-role-plan.md` (create)
- `templates/dispatch-role-build.md` (create)
- `tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md` (create)
- `tests/m031-acceptance/fixtures/tier-a-plus-input.txt` (create)
- `tests/m031-acceptance/test-tier-a-plus-classifier.sh` (create)
- `tests/m031-acceptance/test-tier-a-plus-flow.sh` (create)
- `tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh` (create)
- `tools/verify/m031-p02-classifier-extension-shape.sh` (create)
- `tools/verify/m031-p02-fixture-provenance-shape.sh` (create)
- `tools/verify/m031-p02-tier-a-plus-input-shape.sh` (create)
- `tools/verify/m031-p02-task-slug-shape.sh` (create)
- `tools/verify/m031-p02-role-templates-shape.sh` (create)
- `tools/verify/m031-p02-prompt-shape.sh` (create)
- `tools/verify/m031-p02-router-shape.sh` (create)
- `tools/verify/m031-p02-test-tier-a-plus-classifier-shape.sh` (create)
- `tools/verify/m031-p02-test-tier-a-plus-flow-shape.sh` (create)
- `tools/verify/m031-p02-test-tier-a-plus-prompt-ux-shape.sh` (create)
- `tools/verify/m031-p02-phase-suite.sh` (create)
- `tools/verify/m031-p02-scope-guard.sh` (create)

<!-- The phase plan and task plan files themselves (this file +
     tasks/T0[1-5]-*-PLAN.md) are written by the planner, not by the
     executor — they are not listed here. Test-run output files written
     under .orchestrator/tier-a-plus/<task-slug>/ during integration
     smoke runs are scratch artifacts under the .orchestrator/observability/
     prefix-equivalent — the scope-guard treats .orchestrator/tier-a-plus/
     as a permissive prefix matching the .orchestrator/observability/
     pattern from P01. -->

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