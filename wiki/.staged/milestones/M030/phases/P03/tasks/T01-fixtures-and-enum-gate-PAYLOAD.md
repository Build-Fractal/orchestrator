---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T01-fixtures-and-enum-gate (Phase P03, Milestone M030)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~600 | required |
| Upstream Context | 981-1060 | ~2900 | required |
| Task Plan | 1062-1303 | ~5300 | required |
| State Context | 1305-1311 | ~100 | required |
| First-Turn Completeness | 1313-1362 | ~1000 | required |
| **Total** | | **~20700** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 670
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
hit_count: 670
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
hit_count: 670
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
hit_count: 670
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
hit_count: 591
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
hit_count: 591
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
hit_count: 591
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
hit_count: 670
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
hit_count: 591
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
hit_count: 591
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
hit_count: 591
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
hit_count: 670
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
hit_count: 670
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
hit_count: 670
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
hit_count: 591
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
hit_count: 591
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
hit_count: 591
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
hit_count: 670
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
hit_count: 591
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
hit_count: 591
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
hit_count: 670
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
hit_count: 670
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
hit_count: 591
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
hit_count: 591
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
hit_count: 591
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
hit_count: 246
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
hit_count: 246
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
hit_count: 246
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
hit_count: 246
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
hit_count: 246
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
hit_count: 236
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
     Project-owned per-phase verifiers live under tools/verify/ with
     slug-bearing filenames (p03-*) so install-clobber risk is contained.
     Verifier authorship is co-scheduled with the artifact it gates, in
     the SAME task, per Plan-Time Discipline rule 2. T01 ships the
     additive-schema gate + override-source enum verifier + fixture
     plans/configs BEFORE T02 amends dispatch-interface.sh; T02 amends
     the override-resolution path; T03 stages the round-trip dispatch
     fixtures + the SC-6/SC-7/SC-7a verifiers; T04 closes with the
     phase-suite aggregator. Strict linear chain. -->

### Truths

- `scripts/dispatch/dispatch-interface.sh` emits an `override_source` field on every shadow-on `dispatch_usage` record drawn from the closed enum {`plan_frontmatter`, `milestone_floor`, `disabled`, `shadow_gate_blocked`, `none`}. Shadow-off records do NOT contain the `override_source` field (additive-only — CON-2/FR-19/SC-11). The verifier exercises four scenarios (plan-frontmatter override, milestone-floor overlay, kill-switch overlay, no-overlay-no-override) under shadow-on and asserts the appended JSONL line contains exactly one `"override_source"` token whose value is one of the five enum strings; under shadow-off it asserts zero `override_source` tokens. (FR-4/FR-11/FR-12/FR-13/FR-14/D-A5.)
  - Check: `bash tools/verify/p03-override-source-enum.sh`

- SC-6 holds: a PLAN.md whose frontmatter declares `model_override: smart` and which the P01 classifier would have classified as `mechanical` dispatches with `model_routed=smart` (post-override) and `override_source=plan_frontmatter`. The verifier stages a fixture plan at `tests/fixtures/m030-p03/plans/plan-with-frontmatter-override.md` whose body matches the mechanical-classifier signature (explicit `## Steps` block with file paths + bash verifiers) AND whose frontmatter declares `model_override: smart`, runs an `M030_SHADOW_MODE=1 CLAUDECODE=1` round-trip dispatch through `dispatch-interface.sh`, reads the appended JSONL line, asserts `model_routed=smart` AND `override_source=plan_frontmatter`. Independently re-runs `bash scripts/dispatch/classify-task.sh <plan>` on the same plan and asserts the classifier alone returned `character=mechanical` (i.e., the override actually changed the routed tier). (FR-11/SC-6.)
  - Check: `bash tools/verify/p03-sc6-frontmatter-override.sh`

<dispatch-volatile>

## Upstream Context


### P02 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P02"
parent: "M030"
milestone: "M030"
provides:
  - "tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl,tests/fixtures/m030-p02/round-trip-stage/,tools/verify/p02-fixture-shape.sh,tools/verify/p02-additive-schema.sh,dispatch-interface.sh shadow hook (M030_SHADOW_MODE+CLAUDECODE gated classifier+routing-table emit),4 additive JSONL fields (model_routed,model_used,partial_flip_active,withheld_classes),tools/verify/p02-shadow-emit.sh,tools/verify/p02-con3-closure.sh,tools/verify/p02-append-only.sh,scripts/diagnostics/shadow-compare.sh (4-verdict aggregator),tools/verify/p02-shadow-compare-verdicts.sh,tools/verify/p02-partial-flip-enum.sh,tools/verify/p02-stability-metric-traceability.sh,tools/verify/p02-sc3a-roundtrip.sh,5 shadow-corpus JSONL fixtures,classifier_confidence additive field on dispatch-interface.sh shadow-on emit,tools/verify/p02-phase-suite.sh straight-line aggregator over 9 P02 sub-gates; CLAUDE.md+AGENTS.md recent-changes P02-close fragment"
requires:
  - "P01"
affects:
  - "P03,P04,P05,P06,P07"
key_files:
  - "tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl,tests/fixtures/m030-p02/round-trip-stage/phases/P01/tasks/M001-T01-stage-PLAN.md,tests/fixtures/m030-p02/round-trip-stage/phases/P01/tasks/T01-stage-PAYLOAD.md,tests/fixtures/m030-p02/round-trip-stage/intensity-metadata.txt,tools/verify/p02-fixture-shape.sh,tools/verify/p02-additive-schema.sh,scripts/dispatch/dispatch-interface.sh,tools/verify/p02-shadow-emit.sh,tools/verify/p02-con3-closure.sh,tools/verify/p02-append-only.sh,scripts/diagnostics/shadow-compare.sh,tools/verify/p02-shadow-compare-verdicts.sh,tools/verify/p02-partial-flip-enum.sh,tools/verify/p02-stability-metric-traceability.sh,tools/verify/p02-sc3a-roundtrip.sh,tests/fixtures/m030-p02/shadow-corpus-ready.jsonl,tests/fixtures/m030-p02/shadow-corpus-partially-ready.jsonl,tests/fixtures/m030-p02/shadow-corpus-evidence-insufficient.jsonl,tests/fixtures/m030-p02/shadow-corpus-block.jsonl,tests/fixtures/m030-p02/sc3a-roundtrip-corpus.jsonl,tools/verify/p02-phase-suite.sh,CLAUDE.md,AGENTS.md,[.orchestrator/milestones/M030/phases/P02/P02-PLAN.md](../../../../../milestones/M030/phases/P02/P02-PLAN.md)"
key_decisions:
  - "SC-11 byte-equality verifier authored before T02 amends dispatch-interface.sh (graduation-verifier pattern reused from P01/T01); pricing-warning + adapter-failed shapes covered via fixture-presence grep only -- full round-trip would require stale-pricing-rate or crashing-adapter setup,both out-of-scope for byte-equality gate; payload sized to exactly 4096B so chars_to_tokens_quartile=1024 deterministically matches fixture record 1; round-trip plan basename includes M001 token so MILESTONE_ID regex extraction succeeds without restructuring tests/fixtures/ tree,dual-printf-branch-per-emit-side preserves SC-11 byte-equality mechanically;awk-section-walker (P01 pattern) extracts routing+resolution at dispatch time;CC-only short-circuit gated by CLAUDECODE=1 AND M030_SHADOW_MODE=1;partial_flip_active=false / withheld_classes=empty as P03/P04 schema reservation,D-A1-4-verdict-closed-enum;D-A3-partial-flip-safety-smart-default-only;D-A7-SC-3a-write-path-correctness;classifier_confidence-field-end-to-end-in-P02-not-deferred-to-P03,phase-suite-shape-mirrors-p01-straight-line-AD-19-no-loops; plan-side-grep-amendments-tier-symbols-not-character-labels-CON-3; plan-side-key-link-direction-corrections-dispatch-interface-references-upstreams"
patterns_established:
  - "round-trip-byte-equality fixture pattern: committed payload+plan+intensity-metadata stage with deterministic byte length; ORCHESTRATOR_ROOT carve-out routes log to staged dir; timestamp-normalization sed before diff yields full byte-equality minus the dynamic field; tools/verify/p02-* slug-bearing filenames per project-owned-verifier-paths discipline; AD-19 single-script-file shape preserved with parallel grep-q + rc captures (no compound chains),dual-format-string emit branches (shadow-on adds 4 trailing fields; shadow-off byte-identical to pre-amendment);CON-3 closure verifier compares HEAD-vs-working-tree per-pattern grep counts (no new provider model-ID literals);append-only verifier asserts inode + first-N-lines + line-count delta = +1,awk-section-walker-extended-to-tier-to-class-inverse-map;tmp-file-staging-for-routing-map-to-bypass-macos-awk-multiline-v-limit;SSOT-numeric-traceability-via-awk-line-content-predicate-not-grep-line-number-prefix;per-record-loop-unrolled-into-explicit-blocks-AD-19;classifier-confidence-end-to-end-from-classifier-emit-to-shadow-record-to-variance-aggregator,phase-suite-aggregator-extends-from-7-to-9-gates-without-shape-change; plan-amendment-pattern-when-must-haves-grep-fails-but-phase-suite-green"
drill_down_paths:
  - "[.orchestrator/milestones/M030/phases/P02/tasks/T01-SUMMARY.md](../../../../../milestones/M030/phases/P02/tasks/T01-SUMMARY.md), [.orchestrator/milestones/M030/phases/P02/tasks/T02-dispatch-shadow-hook-SUMMARY.md](../../../../../milestones/M030/phases/P02/tasks/T02-dispatch-shadow-hook-SUMMARY.md), [.orchestrator/milestones/M030/phases/P02/tasks/T03-shadow-compare-SUMMARY.md](../../../../../milestones/M030/phases/P02/tasks/T03-shadow-compare-SUMMARY.md), [.orchestrator/milestones/M030/phases/P02/tasks/T04-phase-suite-and-close-SUMMARY.md](../../../../../milestones/M030/phases/P02/tasks/T04-phase-suite-and-close-SUMMARY.md)"
duration: "245m"
verification_result: "pass"
completed_at: "2026-04-30T14:35:53Z"
observability_surfaces:
  - "none"
---

## P02: Shadow-Mode Telemetry + Routing Verifier Suite

P02 builds the shadow-mode emit path on top of P01's classifier and routing table, then closes with a 9-gate phase-suite verifier that locks every property into a single mechanical aggregator.

### What was built

**T01 — pre-M030 dispatch_usage fixture + additive-schema gate (preflight, shipped pre-P02 in commit `91a743e`).** Hand-authored 5-record JSONL at `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` covering happy-path / pricing-warning / adapter-failed / cost-null / latest-baseline shapes. SC-11 byte-equality verifier `tools/verify/p02-additive-schema.sh` round-trips the fixture's first record through `dispatch-interface.sh` under `M030_SHADOW_MODE=0`, normalizes the dynamic timestamp, and asserts byte-identity. Round-trip stage at `tests/fixtures/m030-p02/round-trip-stage/` provides a deterministic 4096B payload + intensity-metadata fixture so `chars_to_tokens_quartile=1024` matches mechanically. Authoring the verifier *before* T02 amended the emitter is the graduation-verifier pattern reused from P01/T01.

**T02 — dispatch-interface shadow hook + 4-field schema (commit `6d23af5`).** Amended `scripts/dispatch/dispatch-interface.sh` with a CC-only shadow path gated on `M030_SHADOW_MODE=1 && CLAUDECODE=1`. The hook calls `scripts/dispatch/classify-task.sh`, walks `templates/model-routing.yml`'s `routing:` + `resolution:` blocks via an awk section-walker (extending the P01 pattern), and emits four additive fields: `model_routed` (symbolic routing-table choice), `model_used` (runtime default in shadow mode), `partial_flip_active=false`, `withheld_classes=` (both reserved for P03/P04). Dual format-string branches preserve SC-11 byte-equality: shadow-off emits the pre-amendment line literal-for-literal; shadow-on appends the four fields. Zero new provider model-ID literals introduced — every concrete model identifier resolves through `templates/model-routing.yml`. Closes CON-3 mechanically.

**T03 — shadow-compare 4-verdict aggregator + classifier-confidence end-to-end (commit `3936738`).** New `scripts/diagnostics/shadow-compare.sh` consumes shadow JSONL corpora and emits exactly one `flip_recommendation=` line drawn from the closed enum `{ready, partially_ready, block, evidence_insufficient}` (D-A1). Partial-flip safety: only classes whose routing-table default is `smart` may be enumerated in `withheld_classes` (D-A3). Pinned stability-metric numerics (variance ≤ 0.10, N=20, per-class coverage 50) traceable to `references/model-routing.md` SSOT via inline reference comments — verified by per-line content predicate (not `grep -n` line-number-prefix, which produces false-positive substring matches). T03 also amended `dispatch-interface.sh` to emit `classifier_confidence` end-to-end so the variance-stability check is genuinely usable in P02 rather than deferred to P03 (D-A7 / SC-3a write-path correctness).

**T04 — phase-suite aggregator + close prep (commit `55ebeea`).** `tools/verify/p02-phase-suite.sh` invokes all nine sub-gates in literal sequence (`set -uo pipefail`, no loops, `$?` capture per sub-gate, single `SUMMARY:` line) — same straight-line shape as `p01-phase-suite.sh`. CLAUDE.md + AGENTS.md recent-changes fragment via `dual-write-runtime-md.sh --append-entry`. Plan-side amendments to `P02-PLAN.md` resolved 4 `check-must-haves.sh` gaps that were artifact-grep / key-link-direction errors, not task re-opens (per Step-7 plan rule).

### Verification

- `tools/verify/p02-phase-suite.sh` → pass=9 fail=0 (fixture-shape 23/0, additive-schema 6/0, shadow-emit 17/0, con3-closure 7/0, append-only 4/0, shadow-compare-verdicts 4/0, partial-flip-enum 6/0, stability-metric-traceability 3/0, sc3a-roundtrip 6/0)
- `scripts/verify/check-must-haves.sh` → 10 truths + 49 artifacts + 9 key-links all PASS
- `P02-VERIFICATION.md` → overall_result=pass (Tier 1 pass=69/69; Tier 2/3/4 skip)

### Key decisions

- **D-A1 closed-enum 4-verdict**: `flip_recommendation` ∈ `{ready, partially_ready, block, evidence_insufficient}` — no string-interpolation, no open enumeration.
- **D-A3 partial-flip safety**: only `smart`-defaulted classes may be enumerated in `withheld_classes` — fast / balanced classes either flip wholesale or block.
- **D-A7 / SC-3a**: re-classifying the plan path of any shadow record's `unitId` MUST agree with the recorded `model_routed` — verified end-to-end via `tools/verify/p02-sc3a-roundtrip.sh` over a 6-record fixture (2 fast / 2 balanced / 2 smart).
- **Classifier-confidence in P02, not P03**: the variance-stability metric requires per-record confidence; emitting it end-to-end now means P03 can land its variance aggregator without re-amending the emitter.
- **Phase-suite shape mirrors P01**: straight-line, no loops, AD-19-clean.

### Patterns established

- Dual-format-string emit branches preserve byte-equality across additive schema changes — the shadow-off branch is byte-identical to pre-amendment; shadow-on appends fields after the existing set.
- CON-3 closure verifier compares HEAD vs working-tree per-pattern grep counts so the closure constraint can be re-checked on every commit cycle without snapshot drift.
- Append-only JSONL verification via inode preservation + first-N-lines bit-identity + line-count delta = +1.
- AD-19 single-script-file shape preserved through parallel `grep -q` + return-code captures rather than compound `&&`/`||` chains; per-record corpora unrolled into explicit blocks rather than `for` loops.
- Plan-amendment-not-task-reopen pattern when phase-suite is green but `check-must-haves.sh` fails on artifact-grep or key-link-direction.

### Provides downstream

- `dispatch-interface.sh` shadow path + 5 emitted fields → P03 shadow-compare aggregator over real auto-loop telemetry corpus
- `shadow-compare.sh` → P04 partial-flip activation gate
- 9 P02 verifiers + classifier_confidence emit → P03/P04/P05/P06/P07 reuse without re-amendment

### Phase metrics

- 4 tasks (T01 preflight + T02 + T03 + T04)
- Duration: ~245m total dispatch + verify + close
- Phase verification: pass (Tier 1 69/69)
- 0 task re-opens (T04 plan-side-amendment pattern resolved must-have gaps cleanly)

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M030"
name: "P03 fixture plans + overlay configs + override-source-enum gate (preflight)"
depends_on: []
---

## Prerequisites

- scripts/dispatch/dispatch-interface.sh exists in its post-P02 form: `_di_emit_dispatch_usage` body at lines ~185-392; shadow path at lines ~279-324; happy-path printf at line ~332; degradation printf at line ~364.
- scripts/dispatch/classify-task.sh exists and emits `character=<mechanical|standard|novel>` + `confidence=<high|medium|low>` to stdout (P01/T02 close).
- templates/model-routing.yml exists with `routing:` (3 characters x 3 runtimes), `resolution:` (3 tiers x 3 runtimes), `cost_rates:` (3 tiers) sections (P01/T03 close).
- tools/verify/p02-additive-schema.sh exists and exits 0 against the post-P02 dispatch-interface.sh (P02/T04 close).
- tools/verify/p02-phase-suite.sh exists and exits 0 (P02/T04 close).
- tests/fixtures/m030-p02/round-trip-stage/ exists with phases/P01/tasks/M001-T01-stage-PLAN.md + T01-stage-PAYLOAD.md + intensity-metadata.txt — provides the round-trip pattern T01 mirrors at tests/fixtures/m030-p03/round-trip-stage/.

Plan-time prerequisite-existence verification: every path above is asserted by P02 close (verified via `scripts/state/derive-phase.sh .orchestrator/milestones/M030`); the post-P02 `dispatch-interface.sh` shape was inspected during plan-authoring (head -400 reads cleanly; lines 279-324 contain the existing P02 shadow-classifier-and-resolution block; line 332 is the happy-path shadow-on printf, line 364 is the degradation shadow-on printf).

## Description

T01 ships before any work on `scripts/dispatch/dispatch-interface.sh` so the override_source enum invariant is mechanically enforced at the moment T02 amends the emitter. Three deliverable groups that ship as a single coherent change:

1. **Fixture files** under `tests/fixtures/m030-p03/`:
   - Three plan files exercising the three plan-frontmatter override shapes (override+smart, no-override mechanical, override-fast-vs-floor).
   - Four config files exercising the four overlay shapes (routing-disabled, min-tier-smart, killswitch-and-floor, baseline-no-overrides).
   - One round-trip stage directory mirroring the P02 stage shape (intensity-metadata.txt + payload.txt) — staged for T02/T03 round-trip dispatch invocations.

2. **`tools/verify/p03-override-source-enum.sh`** — gates the closed enum invariant. Runs four scenarios under `M030_SHADOW_MODE=1 CLAUDECODE=1`: (a) plain plan + baseline config -> override_source token present with value `none` (post-T02; pre-T02 the gate is vacuously satisfied because the field is absent entirely), (b) plain plan + routing-disabled config -> override_source=disabled, (c) override-smart plan + baseline config -> override_source=plan_frontmatter, (d) plain plan + min-tier-smart config -> override_source=milestone_floor. Plus one shadow-off scenario asserting zero override_source tokens. T01 ships this verifier in a "pre-amendment-tolerant" mode: when the emitted record contains no `override_source` token AT ALL (the pre-T02 reality), the enum check is satisfied (the field has not yet been added, so it cannot violate the closed enum). After T02 lands, the same verifier asserts the field is present AND its value is in the closed enum.

3. **`tools/verify/p03-additive-schema.sh`** — thin pass-through wrapper that invokes `tools/verify/p02-additive-schema.sh` and asserts exit 0. The P02 SC-11 contract continues to hold under HEAD; T01's wrapper is a phase-suite-friendly delegation so `p03-phase-suite.sh` can include the SC-11 gate inline without re-implementing the round-trip.

T01 ends green: all artifacts on disk, both verifiers pass against the pre-amendment `dispatch-interface.sh` (override-source-enum gate green via the pre-amendment-tolerant branch; additive-schema gate green via P02 pass-through).

### Pre-amendment-tolerance shape (load-bearing)

The override-source-enum verifier MUST be runnable BEFORE T02 amends `dispatch-interface.sh`. Pre-T02, the emitted JSONL record contains no `override_source` field; the verifier's enum check accepts this case as PASS (zero matches, zero violations). Post-T02, the emitted record contains exactly one `override_source` field whose value MUST be in the closed enum {`plan_frontmatter`, `milestone_floor`, `disabled`, `shadow_gate_blocked`, `none`}; non-enum values FAIL. The verifier's shape:

```bash
# Per scenario, capture the appended JSONL line.
line="$(tail -n 1 "$log_file")"

# Count override_source tokens. Zero is acceptable (pre-T02 emission); exactly
# one with an enum-valid value is acceptable (post-T02 emission); anything
# else FAILs.
token_count=$(printf '%s' "$line" | grep -o '"override_source"' | wc -l | tr -d ' ')
if [ "$token_count" = "0" ]; then
  pass_scenario "$scenario_name (pre-amendment, field absent)"
elif [ "$token_count" = "1" ]; then
  # Extract value via grep+sed; assert it is in the closed enum.
  value="$(printf '%s' "$line" | grep -oE '"override_source":"[^"]*"' | sed -E 's/.*:"([^"]*)".*/\1/')"
  case "$value" in
    plan_frontmatter|milestone_floor|disabled|shadow_gate_blocked|none)
      pass_scenario "$scenario_name (post-amendment, value=$value)" ;;
    *)
      fail_scenario "$scenario_name (override_source value '$value' not in closed enum)" ;;
  esac
else
  fail_scenario "$scenario_name (override_source token count $token_count, expected 0 or 1)"
fi
```

### Shadow-off scenario

The shadow-off scenario (CLAUDECODE unset OR M030_SHADOW_MODE unset) MUST emit ZERO override_source tokens regardless of pre/post-T02 amendment state. This is the additive-only-when-shadow-on invariant — under shadow off, the four P02 fields AND the new P03 field are all absent. The verifier asserts `token_count == 0` (strict zero, no tolerance) for the shadow-off case.

## Steps

1. **Confirm P02 deliverables are on disk and green.** Run:

   ```bash
   bash tools/verify/p02-additive-schema.sh
   bash tools/verify/p02-phase-suite.sh
   ```

   Expected: both exit 0. If either fails, P02 must be re-opened (out-of-scope for T01 — block T01 with a STUCK signal).

2. **Author the fixture plan files.** Create three plans under `tests/fixtures/m030-p03/plans/`:

   - `plan-with-frontmatter-override.md`: frontmatter declares `model_override: smart`; body has the mechanical-classifier signature (explicit `## Steps` section with file paths + bash verifiers; ≤3 file targets; unambiguous `## Verification` block).
   - `plan-mechanical-no-override.md`: frontmatter declares no `model_override`; body identical mechanical signature.
   - `plan-frontmatter-fast-vs-floor.md`: frontmatter declares `model_override: fast`; body identical mechanical signature.

   The frontmatter shape MUST be standard YAML (the same shape `classify-task.sh` already parses):

   ```yaml
   ---
   schema_version: "1.0"
   type: task-plan
   task: "T99"
   phase: "P99"
   milestone: "M999"
   name: "<fixture name>"
   model_override: "smart"
   ---
   ```

   The path encodes `M999/P99/T99` so `dispatch-interface.sh`'s `MILESTONE_ID` regex extraction succeeds.

3. **Author the fixture config files.** Create four configs under `tests/fixtures/m030-p03/configs/`:

   - `config-baseline.yml` — minimal config with no `model_routing:` block (the no-override-no-floor baseline).
   - `config-with-routing-disabled.yml` — `model_routing_enabled: false` at the top level (NOT under `model_routing:` — kill switch is its own root key per FR-13 and the P03 amendment shape).
   - `config-with-min-tier-smart.yml` — `model_routing:\n  min_tier: smart`.
   - `config-with-killswitch-and-floor.yml` — both knobs: `model_routing_enabled: false` at top level AND `model_routing:\n  min_tier: smart`. This is the SC-7a compound case.

   Each config file uses standard `schema_version: "1.0"` + `type: orchestrator-config` frontmatter to match the existing `.orchestrator/config.yml` shape.

4. **Stage the round-trip directory.** Create `tests/fixtures/m030-p03/round-trip-stage/` with two files:

   - `intensity-metadata.txt` — single line `intensity: standard\nmodel: <runtime-default-model-id>`. The `model:` field is the runtime-default channel `dispatch-interface.sh` reads when `${ORCH_MODEL:-}` is unset.
   - `payload.txt` — any nontrivial payload bytes (≥256 bytes; the byte count drives `chars_to_tokens_quartile` but is not load-bearing for the override-source check).

   The round-trip stage does NOT need its own task-plan files — T02/T03 use the plans authored in Step 2 as the `--task-plan` argument, and the round-trip stage provides the payload + intensity-metadata fixtures.

5. **Author `tools/verify/p03-additive-schema.sh`** — the thin pass-through wrapper:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/p03-additive-schema.sh — Pass-through wrapper over P02 SC-11 gate.
   set -uo pipefail
   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   p02_gate="$PROJECT_ROOT/tools/verify/p02-additive-schema.sh"
   if [ ! -f "$p02_gate" ]; then
     echo "FAIL: p02-additive-schema.sh missing (P02 gate not on disk)"
     echo "SUMMARY: p03-additive-schema.sh pass=0 fail=1"
     exit 1
   fi
   bash "$p02_gate"
   rc=$?
   if [ "$rc" -eq 0 ]; then
     echo "PASS: p02-additive-schema.sh delegated check (SC-11 byte-equality)"
     echo "SUMMARY: p03-additive-schema.sh pass=1 fail=0"
     exit 0
   fi
   echo "FAIL: p02-additive-schema.sh exited $rc"
   echo "SUMMARY: p03-additive-schema.sh pass=0 fail=1"
   exit 1
   ```

6. **Author `tools/verify/p03-override-source-enum.sh`.** Bash 3.2-compatible. AD-19 single-script-file shape. Per-scenario pass/fail accumulators. Five scenarios:

   - **Scenario A — shadow-on, baseline plan + baseline config, no overrides.** Stage a fresh log file, set `M030_SHADOW_MODE=1`, `CLAUDECODE=1`, `ORCHESTRATOR_ROOT=tests/fixtures/m030-p03/orch-root-baseline/` (a tmp dir whose `.orchestrator/config.yml` is the baseline fixture). Invoke `dispatch-interface.sh` with `--task-plan tests/fixtures/m030-p03/plans/plan-mechanical-no-override.md --payload tests/fixtures/m030-p03/round-trip-stage/payload.txt --intensity-metadata tests/fixtures/m030-p03/round-trip-stage/intensity-metadata.txt --backend stub`. Read the appended JSONL line. Apply the pre-amendment-tolerant enum check (pre-T02: zero tokens PASS; post-T02: exactly one with value `none` PASS).
   - **Scenario B — shadow-on, baseline plan + routing-disabled config.** Same staging with `ORCHESTRATOR_ROOT` pointing at a tmp dir whose `.orchestrator/config.yml` is `config-with-routing-disabled.yml`. Apply pre-amendment-tolerant enum check (pre-T02: zero tokens PASS; post-T02: exactly one with value `disabled` PASS).
   - **Scenario C — shadow-on, override-smart plan + baseline config.** Same staging, `--task-plan tests/fixtures/m030-p03/plans/plan-with-frontmatter-override.md`. Apply check (pre-T02: zero PASS; post-T02: value `plan_frontmatter` PASS).
   - **Scenario D — shadow-on, baseline plan + min-tier-smart config.** Same staging, config = `config-with-min-tier-smart.yml`. Apply check (pre-T02: zero PASS; post-T02: value `milestone_floor` PASS).
   - **Scenario E — shadow-off, override-smart plan + min-tier-smart config (most-overlay-rich case).** `unset M030_SHADOW_MODE; export CLAUDECODE=1`. Apply STRICT zero-tokens check (zero PASS; any tokens FAIL — the shadow-off branch must NOT emit override_source).

   Per-scenario pass/fail accumulators; final `SUMMARY: p03-override-source-enum.sh pass=N fail=M`. Exit 0 iff `fail == 0`.

7. **Stage the per-scenario `ORCHESTRATOR_ROOT` tmp dirs.** Each scenario invocation needs an `ORCHESTRATOR_ROOT` whose `.orchestrator/config.yml` is the scenario's fixture config. The verifier creates these tmp dirs at runtime via `mkdir -p "$tmp_root/.orchestrator"` + `cp <fixture-config> "$tmp_root/.orchestrator/config.yml"`. Cleanup: `rm -rf "$tmp_root"` after each scenario. Use `mktemp -d` for the tmp dir name to avoid collisions across parallel runs.

8. **Run all T01 verifiers as a self-check:**

   ```bash
   bash tools/verify/p03-additive-schema.sh
   bash tools/verify/p03-override-source-enum.sh
   ```

   Expected: both exit 0. If `p03-override-source-enum.sh` Scenario E fails (override_source tokens leaking under shadow-off), the P02 emit branches were misordered — investigate `dispatch-interface.sh` lines 326-389 for shadow-off branches accidentally emitting the new field. Pre-T02 this should not happen because the new field has not been added; if Scenario E fails here, T01 has a bug.

9. **Stage and commit.** Stage `tests/fixtures/m030-p03/`, `tools/verify/p03-additive-schema.sh`, `tools/verify/p03-override-source-enum.sh`. Author commit message file via Write to /tmp/p03-t01-commit-msg.txt; commit with `git commit -F /tmp/p03-t01-commit-msg.txt`. Recommended subject: `M030/P03/T01: P03 fixture plans + overlay configs + override-source-enum gate (preflight)`.

## Must-Haves

This task satisfies the phase truths:

- "scripts/dispatch/dispatch-interface.sh emits an override_source field on every shadow-on dispatch_usage record drawn from the closed enum..." — gated by `tools/verify/p03-override-source-enum.sh` (pre-amendment-tolerant; T02 will tighten the gate by populating the field).
- "SC-11 byte-equality re-confirmed against P02's pre-M030 fixture..." — gated by `tools/verify/p03-additive-schema.sh` (pass-through wrapper over P02's SC-11 gate).

## Verification

```bash
bash tools/verify/p03-additive-schema.sh
bash tools/verify/p03-override-source-enum.sh
```

Each verifier uses single-script-file shape per AD-19. Both must exit 0 before T01 closes.

## Inputs

### From Previous Tasks

None directly (T01 is the first task in P03). T01 reads P02 deliverables on disk:

- tools/verify/p02-additive-schema.sh (from M030/P02/T01) — Key API: `bash <path>` exits 0 with `SUMMARY: p02-additive-schema.sh pass=N fail=0` confirming SC-11 byte-equality holds for `dispatch-interface.sh` shadow-off emit.
- tools/verify/p02-phase-suite.sh (from M030/P02/T04) — Key API: `bash <path>` exits 0 with `SUMMARY: p02-phase-suite.sh pass=9 fail=0` aggregating all P02 sub-gates.
- tests/fixtures/m030-p02/round-trip-stage/ (from M030/P02/T01) — Key API: contains `phases/P01/tasks/M001-T01-stage-PLAN.md` + `T01-stage-PAYLOAD.md` + `intensity-metadata.txt` — the P02 round-trip pattern T01 mirrors for P03.

### From Disk (Pre-existing)

- scripts/dispatch/dispatch-interface.sh — pre-T02 form. T01 invokes the emitter via round-trip dispatch under shadow-on; the emitted JSONL line is the verifier input. T01 does NOT modify this file.
  - Key API: `bash scripts/dispatch/dispatch-interface.sh --task-plan <path> --payload <path> --intensity-metadata <path> --backend stub` — runs a stub-backend dispatch and appends one `dispatch_usage` JSONL record to `${ORCH_ROOT:-.orchestrator}/milestones/<milestone-id>/execution-log.jsonl` (or `${ORCH_ROOT}/execution-log.jsonl` if `ORCH_ROOT` is itself a milestone dir). Under shadow-on (`M030_SHADOW_MODE=1` AND `CLAUDECODE=1`), the record contains the four P02 additive fields (`model_routed`, `model_used`, `partial_flip_active`, `withheld_classes`) plus `classifier_confidence`. Under shadow-off, none of those appear.
- scripts/dispatch/classify-task.sh — P01 classifier. T01 indirectly exercises it via the shadow-on dispatch.
  - Key API: `bash scripts/dispatch/classify-task.sh <plan-path>` writes two stdout lines: `character=<mechanical|standard|novel>` and `confidence=<high|medium|low>`. Bash 3.2-safe.
- templates/model-routing.yml — P01 routing-table SSOT. T01 does not read directly; the shadow path inside `dispatch-interface.sh` consumes it.
- scripts/dispatch/adapters/backend/stub.sh — minimal adapter for round-trip harness invocations.

## Constraints

- **AD-19 single-script-file shape**: all verifier `Check:` invocations are `bash <single-path>.sh`. T01 ships verifier scripts; the inline `Check:` commands in this task plan and the parent phase plan invoke those scripts.
- **AP-009 compound-chain-gt2 (verifier shape)**: T01 verifiers MUST avoid `result=$(cmd | grep | head)` patterns. Use tmp-file intermediates: `cmd > /tmp/<f>.txt; grep ... < /tmp/<f>.txt > /tmp/<g>.txt`. Each `Bash` tool invocation in `auto-loop` runs through the harness shape-guard; `bash <verifier>.sh` is the safe invocation shape.
- **Pre-amendment tolerance**: `p03-override-source-enum.sh` MUST exit 0 against the pre-T02 `dispatch-interface.sh` (where the field is absent). The post-T02 tightening of the gate (zero tokens FAIL the post-amendment scenarios A-D) is T02's responsibility, not T01's. T01 SHIPS the gate in pre-amendment-tolerant mode.
- **CON-2/FR-19/SC-11 (additive-only schema)**: shadow-off Scenario E MUST emit zero `override_source` tokens regardless of plan or config overlay state. Pre-T02 this is the universal case (the field doesn't exist yet); post-T02 it remains the case (shadow-off branch ignores all override-resolution logic).
- **Bash 3.2 compatibility**: no `declare -A`, no `mapfile`, no `readarray`. The verifier uses parallel-indexed-array pattern when accumulating per-scenario state.
- **No new hardcoded model IDs**: T01's verifier reads the JSONL `model_used` value but does NOT compare it against a literal `claude-haiku-4-5` etc. Concrete model IDs flow through `templates/model-routing.yml resolution.<tier>.claude-code` exclusively (CON-3).
- **Plan-Time Discipline rule 4 (run-probe.sh scope)**: T01's verifier invokes `bash tools/verify/<path>.sh` directly — `run-probe.sh` is reserved for `/tmp/`, `/var/folders/`, `<repo>/tmp/` paths.
- **Plan-Time Discipline rule 5 (real-DB verification)**: T01 introduces no SQL — N/A.

## Expected Output

- `tests/fixtures/m030-p03/plans/plan-with-frontmatter-override.md` — fixture plan with `model_override: smart` frontmatter + mechanical body signature.
- `tests/fixtures/m030-p03/plans/plan-mechanical-no-override.md` — fixture plan with no override + mechanical body signature.
- `tests/fixtures/m030-p03/plans/plan-frontmatter-fast-vs-floor.md` — fixture plan with `model_override: fast` frontmatter + mechanical body signature.
- `tests/fixtures/m030-p03/configs/config-baseline.yml` — baseline config (no overrides).
- `tests/fixtures/m030-p03/configs/config-with-routing-disabled.yml` — `model_routing_enabled: false` at top level.
- `tests/fixtures/m030-p03/configs/config-with-min-tier-smart.yml` — `model_routing.min_tier: smart`.
- `tests/fixtures/m030-p03/configs/config-with-killswitch-and-floor.yml` — both knobs.
- `tests/fixtures/m030-p03/round-trip-stage/intensity-metadata.txt` — single-line metadata with `intensity:` + `model:` fields.
- `tests/fixtures/m030-p03/round-trip-stage/payload.txt` — nontrivial payload (≥256 bytes).
- `tools/verify/p03-additive-schema.sh` — green: pass-through delegation to P02 SC-11 gate.
- `tools/verify/p03-override-source-enum.sh` — green under pre-amendment-tolerant mode (pre-T02): all five scenarios PASS because shadow-on records have zero override_source tokens (vacuously enum-compliant) AND shadow-off Scenario E has zero tokens (strictly compliant).
- `bash tools/verify/p03-additive-schema.sh` exits 0 with `SUMMARY: p03-additive-schema.sh pass=1 fail=0`.
- `bash tools/verify/p03-override-source-enum.sh` exits 0 with `SUMMARY: p03-override-source-enum.sh pass=5 fail=0`.

## Notes

Expected verifier output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p03-additive-schema.sh` -> delegation to p02-additive-schema.sh; `SUMMARY: p03-additive-schema.sh pass=1 fail=0`, exit 0.
- `bash tools/verify/p03-override-source-enum.sh` -> 5 scenarios pass; `SUMMARY: p03-override-source-enum.sh pass=5 fail=0`, exit 0.

The pre-amendment-tolerant pattern is the same graduation discipline P02/T01 used for the SC-11 byte-equality gate: ship the verifier BEFORE the deliverable that satisfies its strictest form, with a fall-through branch that accepts the pre-amendment shape as PASS. Once T02 amends the emitter, the strictest branch activates and the gate becomes a hard floor.

When T02's amendment lands, T02 will re-run `bash tools/verify/p03-override-source-enum.sh` and observe the post-amendment branch fire for Scenarios A-D (token_count=1, value enum-checked). If T02's amendment is wrong (e.g., emits `override_source=invalid_value`), the enum check FAILs and T02 must re-author the emit branch.

The fixture-config shape — `model_routing_enabled` at the top level vs. `model_routing.min_tier` nested — matches the spec's FR-13 + FR-12 declarations literally. The kill switch is a top-level boolean per FR-13's "kill switch is the operator's panic button" framing; `min_tier` is nested under `model_routing` because it is one of several routing-table-related knobs (others land in M030/P05). This shape is documented in `references/model-routing.md` § Operator Overrides (T03 deliverable).

## State Context

- **Current State**: executing
- **Milestone**: M030
- **Phase**: P03
- **Task**: T01-fixtures-and-enum-gate
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **AD-19 single-script-file shape**: all verifier `Check:` invocations are `bash <single-path>.sh`. T01 ships verifier scripts; the inline `Check:` commands in this task plan and the parent phase plan invoke those scripts.
- **AP-009 compound-chain-gt2 (verifier shape)**: T01 verifiers MUST avoid `result=$(cmd | grep | head)` patterns. Use tmp-file intermediates: `cmd > /tmp/<f>.txt; grep ... < /tmp/<f>.txt > /tmp/<g>.txt`. Each `Bash` tool invocation in `auto-loop` runs through the harness shape-guard; `bash <verifier>.sh` is the safe invocation shape.
- **Pre-amendment tolerance**: `p03-override-source-enum.sh` MUST exit 0 against the pre-T02 `dispatch-interface.sh` (where the field is absent). The post-T02 tightening of the gate (zero tokens FAIL the post-amendment scenarios A-D) is T02's responsibility, not T01's. T01 SHIPS the gate in pre-amendment-tolerant mode.
- **CON-2/FR-19/SC-11 (additive-only schema)**: shadow-off Scenario E MUST emit zero `override_source` tokens regardless of plan or config overlay state. Pre-T02 this is the universal case (the field doesn't exist yet); post-T02 it remains the case (shadow-off branch ignores all override-resolution logic).
- **Bash 3.2 compatibility**: no `declare -A`, no `mapfile`, no `readarray`. The verifier uses parallel-indexed-array pattern when accumulating per-scenario state.
- **No new hardcoded model IDs**: T01's verifier reads the JSONL `model_used` value but does NOT compare it against a literal `claude-haiku-4-5` etc. Concrete model IDs flow through `templates/model-routing.yml resolution.<tier>.claude-code` exclusively (CON-3).
- **Plan-Time Discipline rule 4 (run-probe.sh scope)**: T01's verifier invokes `bash tools/verify/<path>.sh` directly — `run-probe.sh` is reserved for `/tmp/`, `/var/folders/`, `<repo>/tmp/` paths.
- **Plan-Time Discipline rule 5 (real-DB verification)**: T01 introduces no SQL — N/A.

### Acceptance Criteria

This task satisfies the phase truths:

- "scripts/dispatch/dispatch-interface.sh emits an override_source field on every shadow-on dispatch_usage record drawn from the closed enum..." — gated by `tools/verify/p03-override-source-enum.sh` (pre-amendment-tolerant; T02 will tighten the gate by populating the field).
- "SC-11 byte-equality re-confirmed against P02's pre-M030 fixture..." — gated by `tools/verify/p03-additive-schema.sh` (pass-through wrapper over P02's SC-11 gate).

### Files To Touch

- scripts/dispatch/dispatch-interface.sh (modify)
- references/model-routing.md (modify)
- tests/fixtures/m030-p03/plans/plan-with-frontmatter-override.md (create)
- tests/fixtures/m030-p03/plans/plan-mechanical-no-override.md (create)
- tests/fixtures/m030-p03/plans/plan-frontmatter-fast-vs-floor.md (create)
- tests/fixtures/m030-p03/configs/config-with-routing-disabled.yml (create)
- tests/fixtures/m030-p03/configs/config-with-min-tier-smart.yml (create)
- tests/fixtures/m030-p03/configs/config-with-killswitch-and-floor.yml (create)
- tests/fixtures/m030-p03/configs/config-baseline.yml (create)
- tests/fixtures/m030-p03/round-trip-stage/intensity-metadata.txt (create)
- tests/fixtures/m030-p03/round-trip-stage/payload.txt (create)
- tools/verify/p03-override-source-enum.sh (create)
- tools/verify/p03-sc6-frontmatter-override.sh (create)
- tools/verify/p03-sc7-kill-switch.sh (create)
- tools/verify/p03-sc7a-compound.sh (create)
- tools/verify/p03-con3-closure.sh (create)
- tools/verify/p03-min-tier-floor.sh (create)
- tools/verify/p03-override-conflict.sh (create)
- tools/verify/p03-additive-schema.sh (create)
- tools/verify/p03-phase-suite.sh (create)
- CLAUDE.md (modify — recent-changes region)
- AGENTS.md (modify if present — recent-changes region dual-write)

<!-- Phase plan and task plan files (this file + tasks/T0[1-4]-*-PLAN.md)
     are written by the planner, not by the executor — not listed here. -->

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