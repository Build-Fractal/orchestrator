---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T02-knowledge-filter (Phase P02, Milestone M018)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-978 | ~600 | required |
| Upstream Context | 980-1061 | ~2100 | required |
| Task Plan | 1063-1456 | ~6300 | required |
| State Context | 1458-1464 | ~100 | required |
| First-Turn Completeness | 1466-1507 | ~900 | required |
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
hit_count: 601
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
hit_count: 601
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
hit_count: 601
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
hit_count: 601
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
hit_count: 531
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
hit_count: 531
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
hit_count: 531
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
hit_count: 601
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
hit_count: 531
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
hit_count: 531
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
hit_count: 531
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
hit_count: 601
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
hit_count: 601
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
hit_count: 601
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
hit_count: 531
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
hit_count: 531
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
hit_count: 531
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
hit_count: 601
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
hit_count: 531
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
hit_count: 531
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
hit_count: 601
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
hit_count: 601
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
hit_count: 531
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
hit_count: 531
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
hit_count: 531
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
hit_count: 186
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
hit_count: 186
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
hit_count: 186
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
hit_count: 177
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
hit_count: 177
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
hit_count: 167
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

<!-- Per AD-19, every Check is a single-script-file invocation. No inline
     compound bash, no plain subshells, no $(... | ...) containing pipes.
     See commands/plan-phase.md for the full forbidden-shape enumeration. -->

- `scripts/dispatch/build-context.sh` reads each knowledge entry's `status:` field and excludes entries whose value matches the configured drop-list (`compression.knowledge_filter.drop_list`, default `["superseded", "experimental"]`) before payload assembly. Entries without a `status:` field default to `stable` and are never dropped (FR-3 back-compat per A-1).
  - Check: `bash scripts/verify/m018-p02-filter-drops.sh`

- When the filter drops at least one entry, a `payload_filter` JSONL record is appended to `execution-log.jsonl` naming `{filter, drop_list, dropped_count, dropped_tokens, dropped_ids, source: runtime}`; the existing `payload_breakdown` record carries an additive `filter_dropped_tokens` field. Pre-M018 records remain valid JSON (CON-5 — additive emitter).
  - Check: `bash scripts/verify/m018-p02-emitter-additivity.sh`

- The preservation-contract self-check library `scripts/lib/preservation-check.sh` exposes `pres_check_section` (regex-driven pattern walker that compares pre- and post-transform byte spans for every preserved-pattern row from `references/compression-grammar.md` `## Preserved-Pattern Vocabulary`), `pres_emit_violation` (writes `tier_preservation_violation` JSONL), and `pres_density_pre_check` (refuses tier3 invocation when input density exceeds the configured threshold per MIT-08). Library is bash 3.2 compatible, sourceable, and pure (no global writes other than the named emitter).
  - Check: `bash scripts/verify/m018-p02-preservation-check-api.sh`

- The aggregate-savings self-check emits a `compression_underperformance` JSONL record when the running mean payload-token reduction across the last N dispatches falls below the SC-9 calibrated 34.7% floor (MIT-09). The check is operational signal — never blocks dispatch. The threshold and window are config-driven (`compression.underperformance.window_size`, `compression.underperformance.floor_pct`).
  - Check: `bash scripts/verify/m018-p02-underperformance-emit.sh`

<dispatch-volatile>

## Upstream Context


### P01 Summary
---
schema_version: "1.0"
type: phase-summary
id: P01
parent: M018
milestone: M018
provides: "compression-grammar contract v1.0.1 (Reviewed); compression-grammar lint script; conversus --strict gate verdict (PASS); RUNTIME-ASSUMPTIONS.md M018/P01 entry; six P01-private truth verifiers including m018-p01-conversus-pass.sh; CLAUDE.md/AGENTS.md recent-changes refresh"
requires: "P00 SC-9 calibrated 34.7% floor; P00 per-tier 80% CIs from .orchestrator/scratch/m018-section-distribution-output.json; conversus adapter scripts/dispatch/adapters/tool/conversus.sh (DEP-4)"
affects: "P02 (filter — first tier consumer of the contract; preservation-contract self-check pattern lands here per MIT-10); P03 (T1 microcompact — reuses self-check pattern); P04 (T2 snip — reuses self-check pattern + extended code-fence regex from MIT-01); P06 (T3 auto-compact — gated by MIT-08 LLM-preservation enforcement before unit_close); P05 (eval harness — reads tier_preservation_violation + compression_underperformance JSONL emitters from MIT-09)"
key_files: "references/compression-grammar.md;scripts/verify/compression-grammar-lint.sh;scripts/verify/m018-p01-grammar-shape.sh;scripts/verify/m018-p01-lint-clean.sh;scripts/verify/m018-p01-sc9-traceability.sh;scripts/verify/m018-p01-runtime-assumptions.sh;scripts/verify/m018-p01-conversus-pass.sh;scripts/verify/m018-p01-dual-write-recent.sh;templates/conversus-presets/compression-grammar.yml;[.orchestrator/milestones/M018/phases/P01/conversus/gate-result.md](../../../../../milestones/M018/phases/P01/conversus/gate-result.md);RUNTIME-ASSUMPTIONS.md"
key_decisions: "Adopted P0-only mitigation strategy on first conversus BLOCK (token-economy decision; MIT-01 nested-fence regex + MIT-02 JSONL-in-fenced-code, both single-line edits); deferred P1/P2 mitigations to follow-up cycle via Open Questions deferrals; second gate returned PASS (surviving_disputes=0); captured three new non-gating findings from second deliberation (THREAT-04/08/09) as MIT-08/09/10 P02-entry-gate items rather than blocking P01; advanced grammar status Draft → Reviewed per spec acceptance scenario 3"
patterns_established: "Conversus gate retry pattern at minimal-fix surface area to maximize PASS odds (P0 only, defer P1+ unless gate re-flags); P02-entry-gate documentation pattern via grammar Open Questions section (P02 plan reads OQ before scoping its self-check); HTML-entity-escaped TODO marker pattern (`&lt;TODO:&gt;`) so docs can document a forbidden-marker regex without tripping the conversus pre-flight check"
drill_down_paths: "[.orchestrator/milestones/M018/phases/P01/tasks/T01-grammar-contract-SUMMARY.md](../../../../../milestones/M018/phases/P01/tasks/T01-grammar-contract-SUMMARY.md);[.orchestrator/milestones/M018/phases/P01/tasks/T02-lint-and-runtime-SUMMARY.md](../../../../../milestones/M018/phases/P01/tasks/T02-lint-and-runtime-SUMMARY.md);[.orchestrator/milestones/M018/phases/P01/tasks/T03-conversus-gate-SUMMARY.md](../../../../../milestones/M018/phases/P01/tasks/T03-conversus-gate-SUMMARY.md);[.orchestrator/milestones/M018/phases/P01/conversus/gate-result.md](../../../../../milestones/M018/phases/P01/conversus/gate-result.md);[.orchestrator/milestones/M018/phases/P01/conversus/summary/final.md](../../../../../milestones/M018/phases/P01/conversus/summary/final.md)"
duration: "~3h"
verification_result: pass
observability_surfaces: none
completed_at: "2026-04-27T00:00:00Z"
---

# Phase Summary: M018/P01 — Grammar Contract + Conversus Gate

## Closure summary

P01 ships the versioned tier-by-tier compression-grammar contract that gates the M018 pipeline's downstream phases. `references/compression-grammar.md` (v1.0.1, status: Reviewed) names per-tier `applies-to:` artifact classes, `preserves:` byte-pattern regexes, savings ceilings cited verbatim from P00's 80% CIs, and failure semantics for the FR-2 preservation contract. The conversus `--strict` red/blue advocate gate ran twice — first verdict BLOCK on two P0 grammar bugs, second verdict **PASS** after applying both single-line fixes. P01 closure unblocks P02 (filter — first tier consumer of the contract).

## Conversus gate result

**Verdict**: PASS (surviving_disputes=0). Preset: `compression-grammar` (red-blue mode, charters scoped to the grammar contract, arbiter grounded in constitution Principles II/III/XV). Provider: `claude-code` (mandatory per user policy memory — anthropic 429s are policy gates, not transient).

**First gate (BLOCK, 2026-04-27)**: 10 disputes. Two P0 mitigations gating closure:

- **MIT-01 (THREAT-01)** — code-fence regex `^`{3}[a-zA-Z0-9_-]*$` matched only exactly 3 backticks; nested 4+-backtick fences unprotected. Fix: regex extended to `^`{3,}[a-zA-Z0-9_-]*$`.
- **MIT-02 (THREAT-03)** — JSONL preservation was `.jsonl`-extension-scoped only; didn't protect JSON-shaped lines inside markdown code fences. Fix: JSONL pattern extended to also match complete `{...}` lines inside fenced code blocks of any language tag.

Four P1 mitigations (MIT-03/04/06/07) and one P2 mitigation (MIT-05) were deferred to a follow-up cycle via the contract's Open Questions section. Deferral rationale: arbiter's headline was "proceed with conditions" — non-blocking, and the smaller-surface-area retry maximizes PASS odds.

**Second gate (PASS, 2026-04-27)**: surviving_disputes=0. Three new non-gating findings emerged from deliberation but did not survive scoring; they're captured in the contract's Open Questions as P02-entry-gate items:

- **MIT-08 (P02 entry gate, THREAT-04)** — LLM preservation trust boundary. Tier3's preservation contract is detection-only at the boundary; P02 self-check pattern must include a density pre-check + deterministic fallback to tier2 passthrough on any self-check failure. Re-evaluate before P06 ships tier3.
- **MIT-09 (P02 entry gate, THREAT-08)** — SC-9 threshold operational fragility. P02 ships an aggregate-savings self-check emitting `compression_underperformance` JSONL records when running mean falls below the 34.7% floor.
- **MIT-10 (P02, THREAT-09)** — preservation-contract self-check algorithmic specification: regex-driven pattern walker (one pass per preserved-pattern row) before/after each tier transformation; byte-mismatch on any preserved span triggers passthrough plus `tier_preservation_violation` emission.

## Calibrated threshold defense

Grammar contract's `## Aggregate Plausibility (SC-9)` section cites P00's 80% CIs verbatim:

| Tier   | low      | mean     | high     |
|--------|----------|----------|----------|
| filter | 12.55%   | 13.08%   | 13.67%   |
| tier1  | 6.24%    | 6.31%    | 6.40%    |
| tier2  | 25.33%   | 25.49%   | 25.68%   |
| tier3  | 12.10%   | 12.22%   | 12.36%   |
| **agg**| **34.73%**| **35.08%**| **35.39%**|

The aggregate low (34.73%) defends against the SC-9 calibrated floor (34.7%) under the per-tier modeling assumptions documented verbatim in the probe JSON (`.orchestrator/scratch/m018-section-distribution-output.json` `.model_assumptions` block).

## Risk-mitigation traceability

- **RISK-1 (M018/P00)** → MIT-1 (P00/T01 emitter parity) → P00 closed with 100% parity over 20-dispatch fixture replay.
- **RISK-2 (M018/P00)** → MIT-2 (P00/T02 probe + P00/T03 SC-9 calibration) → SC-9 amended to 34.7% floor in spec.
- **RISK-3 (M018/P01)** → MIT-3 (this phase) → grammar contract reviewed via conversus PASS; downstream phases gate against the contract by mechanical lint + verifier.
- **MIT-08/09/10 (P02 entry gates)** → carried forward into P02-PLAN.md scope; P02 self-check pattern must satisfy them before P02 closes.

## Followups for downstream phases

- **P02 (filter)** consumes the contract's `## Tier: filter` section; establishes the preservation-contract self-check pattern that P03/P04/P06 reuse. Must satisfy MIT-08/09/10 before P02 closes.
- **P03 (tier1)** consumes the contract's `## Tier: tier1` section + tool-result preservation patterns.
- **P04 (tier2)** consumes the contract's `## Tier: tier2` section. The MIT-01 fix (4+-backtick fences) is load-bearing for P04's head-drop boundary detection.
- **P05 (eval harness)** reads `tier_preservation_violation` + `compression_underperformance` JSONL emitters defined per the additive emitter invariants section.
- **P06 (tier3)** consumes the contract's `## Tier: tier3` section. MIT-08 (LLM preservation trust boundary) is a P06 unit_close gate, not a P02 gate.
- **All phases**: pre-bash-shape-guard hook compliance is universal (AP-009).

## Verification result

All P01 truths PASS via `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P01/`. All artifacts present, all key-links resolve. Lint clean. Conversus gate-result.md frontmatter `verdict: "PASS"`.

P01 closed. M018 advances to P02.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M018"
name: "Knowledge-aware filter in build-context.sh + config key + payload_filter emitter + filter_dropped_tokens field"
depends_on: ["T01"]
---

## Prerequisites

- T01 has landed `scripts/lib/preservation-check.sh`. Sourcing the library exposes `pres_check_section`, `pres_emit_violation`, `pres_density_pre_check`, `PRES_PATTERNS_REGEX`, `PRES_PATTERN_NAMES`. T02 sources the library defensively (the filter operates on whole-entry granularity per grammar contract `## Tier: filter` failure semantics — there is no preserved-pattern self-check at the entry interior — but sourcing the library now means P03/P04/P06 inherit a working source path with no further wiring).
- `references/compression-grammar.md` `## Tier: filter` (lines 144–164) names the contract: filter reads each knowledge entry's `status:` field; drops list-matched values; missing `status:` → RETAINED (fail-open); parse error on `status:` → RETAINED + `entry_status_unparseable` field on the `payload_filter` record.
- `scripts/dispatch/build-context.sh` is the integration target. Filter integration lands BEFORE `_bc_emit_payload_breakdown` (line 1042 in current file); the precise insertion point is inside `_bc_gather_knowledge_from_index` and `_bc_gather_knowledge_flat` (lines 382–482) — both knowledge-gather paths must apply the filter so the filter is path-independent.
- M020 ships the `status:` field on knowledge entries. Per the planning payload note, most pre-M020 entries default to `graduated`. The filter treats absent `status:` field as `stable` (per spec FR-3 + grammar contract `## Tier: filter` failure semantics). The filter does NOT special-case `graduated` — it drops only what `compression.knowledge_filter.drop_list` names, defaulting to `["superseded", "experimental"]`.
- AP-009 (`scripts/hooks/pre-bash-shape-guard.sh`) bans compound chains > 2, plain subshells, `$(... | ...)`. `build-context.sh` already complies; T02's additions must too.

## Description

Wire the knowledge-aware injection filter into `scripts/dispatch/build-context.sh`. The filter:

1. Reads `compression.knowledge_filter.drop_list` from `.orchestrator/config.yml` (default: `["superseded", "experimental"]`).
2. Honors a `compression.enabled: false` short-circuit (FR-15 / SC-8) — when disabled, the filter is a no-op and the Knowledge section is byte-identical to the pre-M018 baseline.
3. For each knowledge entry resolved by the existing scope-filter pipeline (`scripts/knowledge/resolve-entries.sh` output), reads the entry's `status:` frontmatter field. If the value matches the drop-list, the entry is excluded from the payload. Missing field → retained (fail-open per A-1 + grammar contract).
4. When the filter drops at least one entry, emits a `payload_filter` JSONL record to `execution-log.jsonl` with the schema below, AND the existing `_bc_emit_payload_breakdown` function adds an additive `filter_dropped_tokens` field to the `payload_breakdown` record.
5. When the entire Knowledge section becomes empty (filter dropped every entry), emits the literal `(no qualifying knowledge entries)` instead of an empty section, preserving downstream-parser shape (spec acceptance scenario 5).

`payload_filter` JSONL record schema (additive — CON-5):

```json
{
  "record_type": "payload_filter",
  "filter": "knowledge_status",
  "drop_list": ["superseded", "experimental"],
  "dropped_count": 3,
  "dropped_tokens": 1247,
  "dropped_ids": ["MEM042", "MEM055", "MEM061"],
  "source": "runtime",
  "unitId": "M018/P02/T02",
  "milestone": "M018",
  "phase": "P02",
  "task": "T02",
  "timestamp": "2026-04-27T14:23:01Z"
}
```

The `payload_breakdown` extension is additive: existing record stays valid; a new optional `filter_dropped_tokens` field is added at top level (sibling of `payload_tokens_estimate`). Pre-M018 records remain valid JSON (CON-5 — missing field treated as null by post-M018 rollups).

## Steps

1. **Add `compression:` block to `.orchestrator/config.yml`** (and mirror in `templates/config-defaults.yml`):

   ```yaml
   # M018 — Context Compression Layer
   compression:
     enabled: true                      # FR-15: master toggle. false → entire pipeline short-circuits.
     knowledge_filter:
       enabled: true                    # FR-3: tier-specific toggle.
       drop_list:                       # FR-3: status: values that trigger drop.
         - superseded
         - experimental
   ```

   Use `Edit` to insert the block at end of file. Keep ordering: append after the existing `comments:` block. Preserve existing keys.

2. **Author a small helper in `build-context.sh`** to read the drop-list. The existing `config_read` helper (line 141) reads scalar keys; the drop-list is a YAML array. Add a sibling helper:

   ```bash
   # Reads compression.knowledge_filter.drop_list as newline-separated values.
   # Returns the default 'superseded\nexperimental' if the key is absent or the
   # config is missing. Bash 3.2; AP-009 compliant (no compound chain > 2,
   # no $(...|...)).
   _bc_read_drop_list() {
     local cfg="$ORCH_ROOT/config.yml"
     [ ! -f "$cfg" ] && cfg="$PROJECT_ROOT/.orchestrator/config.yml"
     if [ ! -f "$cfg" ]; then
       printf 'superseded\nexperimental\n'
       return
     fi
     # Single-pass awk: find drop_list:, then collect subsequent leading-dash bullets
     # until the indent level exits or a non-bullet line appears.
     awk '
       BEGIN { in_block=0 }
       /^[[:space:]]*drop_list:[[:space:]]*$/ { in_block=1; next }
       in_block==1 {
         if ($0 ~ /^[[:space:]]+-[[:space:]]+[A-Za-z_-]+/) {
           sub(/^[[:space:]]+-[[:space:]]+/, "")
           gsub(/[[:space:]]+$/, "")
           print
         } else if ($0 ~ /^[^[:space:]]/) {
           in_block=0
         }
       }
     ' "$cfg"
   }
   ```

   Place this helper between `config_read` (line 141) and the `CONTEXT_VERBOSITY=` line (line 153).

   Add a sibling read for `compression.enabled` and `compression.knowledge_filter.enabled` (both scalar — use the existing `config_read`):

   ```bash
   COMPRESSION_ENABLED="$(config_read 'compression.enabled' true)"
   KNOWLEDGE_FILTER_ENABLED="$(config_read 'compression.knowledge_filter.enabled' true)"
   ```

   Verify the existing `READ_CONFIG` script (`bash "$READ_CONFIG" key`) handles dotted keys. If not, fall back to a per-key awk grep similar to `_bc_read_drop_list`. (The codebase already uses dotted keys in `comments.auto_apply_threshold.uat-bug` etc., so the reader supports them — confirm by `grep dotted scripts/util/read-config.sh` before assuming.)

3. **Author the filter function** `_bc_filter_knowledge_by_status`. Place it near `_bc_gather_knowledge_from_index` (around line 380):

   ```bash
   # Input on stdin: resolved knowledge entries (output of $RESOLVE_ENTRIES) — a
   # multi-entry markdown stream where each entry begins with a YAML frontmatter
   # block (^---$ ... ^---$) and ends before the next ^---$ at column 0.
   # Output on stdout: the filtered stream, with drop-list-matching entries removed.
   # Side effect: writes a stats line to $TMPDIR_BUILD/_filter_stats.txt of the form:
   #   dropped_count=<N> dropped_tokens=<N> dropped_ids=<comma-separated>
   # The caller reads this file to emit the payload_filter JSONL record.
   _bc_filter_knowledge_by_status() {
     local drop_list_file="$1"
     local stats_file="$TMPDIR_BUILD/_filter_stats.txt"
     local dropped_count=0 dropped_tokens=0 dropped_ids=""

     # Short-circuit when filter is disabled.
     if [ "$COMPRESSION_ENABLED" != "true" ] || [ "$KNOWLEDGE_FILTER_ENABLED" != "true" ]; then
       cat
       printf 'dropped_count=0 dropped_tokens=0 dropped_ids=\n' > "$stats_file"
       return 0
     fi

     # Stage stdin to a temp file so we can iterate by entry.
     local in_file="$TMPDIR_BUILD/_filter_in.md"
     cat > "$in_file"

     # Split into entries by ^---$ frontmatter delimiter pairs. Use awk to
     # output one entry per record-separator-bracketed block.
     local out_file="$TMPDIR_BUILD/_filter_out.md"
     : > "$out_file"

     # Single-pass awk: track frontmatter open/close, capture status: field
     # within frontmatter, and decide retain/drop on the close delimiter.
     awk -v drop_file="$drop_list_file" -v stats_file="$stats_file" '
       BEGIN {
         # Load drop-list into associative-style keyed lookup. awk gawk has true
         # associative arrays — we are not bound by bash 3.2 here.
         while ((getline d < drop_file) > 0) {
           gsub(/[[:space:]]+/, "", d)
           if (d != "") drop[d] = 1
         }
         in_fm = 0
         entry_buf = ""
         status_val = ""
         entry_id = ""
         dropped_count = 0
         dropped_tokens = 0
         dropped_ids = ""
       }
       {
         entry_buf = entry_buf $0 "\n"
         if ($0 == "---") {
           if (in_fm == 0) {
             in_fm = 1
           } else {
             in_fm = 0
             # Frontmatter just closed. Continue reading body until next "---" at col 0
             # or EOF.
             next
           }
         }
         if (in_fm == 1 && $0 ~ /^status:[[:space:]]/) {
           status_val = $0
           sub(/^status:[[:space:]]*/, "", status_val)
           sub(/[[:space:]]+$/, "", status_val)
           gsub(/^"|"$/, "", status_val)
         }
         if (in_fm == 1 && $0 ~ /^id:[[:space:]]/) {
           entry_id = $0
           sub(/^id:[[:space:]]*"?/, "", entry_id)
           sub(/"?[[:space:]]*$/, "", entry_id)
         }
       }
       # Detect entry boundary: a line that is exactly "---" AND the next line
       # starts a new entry frontmatter. We approximate: flush on next "id:" at
       # frontmatter open OR at EOF.
       /^---$/ && in_fm == 1 && entry_buf != "" {
         # second occurrence above flips in_fm to 0; this path is the start of
         # the NEXT entry frontmatter or trailing body. We handle the simpler
         # rule below at END.
       }
       END {
         # Final flush: decide on the last entry buffered.
         _decide(entry_buf, status_val, entry_id)
         printf "dropped_count=%d dropped_tokens=%d dropped_ids=%s\n", \
           dropped_count, dropped_tokens, dropped_ids > stats_file
       }
       function _decide(buf, st, eid,    keep, tok) {
         keep = 1
         if (st != "" && (st in drop)) keep = 0
         tok = int(length(buf) / 4)   # rough char-quartile estimate
         if (keep == 1) {
           printf "%s", buf
         } else {
           dropped_count++
           dropped_tokens += tok
           if (dropped_ids == "") dropped_ids = eid
           else dropped_ids = dropped_ids "," eid
         }
       }
     ' "$in_file" > "$out_file"

     cat "$out_file"
   }
   ```

   **NOTE on the awk above**: the entry-boundary detection in real M018 code needs to actually flush on EVERY entry boundary, not just at EOF. The simplified single-flush version above is a placeholder — when implementing, scan multiple `^---$` pairs and flush per entry. Two production-clean approaches:
   - **Approach A (recommended)**: pre-split the input file with a Python-free shell pre-pass — `awk '/^---$/ {n++} {print n " " $0}' "$in_file"` numbers every line by block. Group pairs (n=1+2 = entry 1 frontmatter; n=3 = entry 1 body until next n=4 opens entry 2 frontmatter). This is more verbose but each step is a single command.
   - **Approach B**: process entry-by-entry by splitting on the `^---$` *boundary between entries* (the resolved-entries stream from `$RESOLVE_ENTRIES` separates entries by a closing `---` followed by a blank line followed by the next opening `---`). Use awk's `RS` set to that boundary.

   Pick Approach A for clarity and AP-009 compliance. Implement step-by-step; test against the fixture in step 7 before integrating.

4. **Wire the filter into both knowledge-gather paths**. In `_bc_gather_knowledge_from_index` (around line 463 where the function does `echo "$resolved"`), pipe the resolved entries through the filter:

   ```bash
   # Write drop list to a temp file for the filter awk to read.
   local drop_list_file="$TMPDIR_BUILD/_drop_list.txt"
   _bc_read_drop_list > "$drop_list_file"

   if [ -z "$resolved" ]; then
     echo "No knowledge entries in scope."
   else
     local entry_count
     entry_count="$(echo "$all_ids" | grep -c 'MEM' 2>/dev/null || echo 0)"
     echo "<!-- $entry_count knowledge entries resolved from index -->"
     echo ""
     # Apply M018/P02 status filter.
     printf '%s\n' "$resolved" | _bc_filter_knowledge_by_status "$drop_list_file"
   fi
   ```

   In `_bc_gather_knowledge_flat` (around line 480 where it does `echo "$entries"`), do the same pipe.

   Handle the empty-after-filter case (spec acceptance scenario 5): if the filter dropped every entry, emit `(no qualifying knowledge entries)`. Detect this by checking the post-filter byte count or grep-count for `^---$` frontmatter delimiters in the filter output.

5. **Source the preservation library defensively**. At the top of `build-context.sh` (just after `config_read` definition, around line 152), add:

   ```bash
   # M018/P02: source preservation-check library so downstream tier wiring inherits
   # a single source path. The filter operates on whole-entry granularity (no
   # interior preservation check per grammar contract `## Tier: filter` failure
   # semantics), so no caller wires pres_check_section yet.
   if [ -r "$PROJECT_ROOT/scripts/lib/preservation-check.sh" ]; then
     . "$PROJECT_ROOT/scripts/lib/preservation-check.sh" || true
   fi
   ```

6. **Extend `_bc_emit_payload_breakdown`** (line 1042) to include `filter_dropped_tokens` when present. Read the stats file (`$TMPDIR_BUILD/_filter_stats.txt`); parse `dropped_tokens=N`; default to 0 when the file is missing (e.g., when the planning branch did not run knowledge gather, or filter was disabled). Add the field to the existing `printf` JSONL line:

   ```bash
   local filter_dropped_tokens=0
   local stats_file="$TMPDIR_BUILD/_filter_stats.txt"
   if [ -f "$stats_file" ]; then
     filter_dropped_tokens="$(awk '{ for (i=1;i<=NF;i++) if ($i ~ /^dropped_tokens=/) { sub("dropped_tokens=","",$i); print $i; exit } }' "$stats_file")"
     [ -z "$filter_dropped_tokens" ] && filter_dropped_tokens=0
   fi
   ```

   Extend the `printf` format string with `,"filter_dropped_tokens":%d` and add the variable to the value list. Ensure the field appears in the JSONL output AT THE END of the existing object so existing rollup `jq` filters that key by leading fields keep working.

7. **Emit the `payload_filter` JSONL record** when the filter dropped at least one entry. Add a new function `_bc_emit_payload_filter` near `_bc_emit_payload_breakdown` and call it from the same top-level invocation site (line 1208 region):

   ```bash
   _bc_emit_payload_filter() {
     [ "${ORCH_M019_EMIT:-1}" = "0" ] && return 0
     local stats_file="$TMPDIR_BUILD/_filter_stats.txt"
     [ ! -f "$stats_file" ] && return 0
     local dropped_count dropped_tokens dropped_ids
     dropped_count="$(awk '{ for (i=1;i<=NF;i++) if ($i ~ /^dropped_count=/) { sub("dropped_count=","",$i); print $i; exit } }' "$stats_file")"
     dropped_tokens="$(awk '{ for (i=1;i<=NF;i++) if ($i ~ /^dropped_tokens=/) { sub("dropped_tokens=","",$i); print $i; exit } }' "$stats_file")"
     dropped_ids="$(awk '{ for (i=1;i<=NF;i++) if ($i ~ /^dropped_ids=/) { sub("dropped_ids=","",$i); print $i; exit } }' "$stats_file")"
     [ -z "$dropped_count" ] && dropped_count=0
     [ "$dropped_count" -eq 0 ] && return 0
     local log_dir log_file ts
     log_dir="$ORCH_ROOT/milestones/$MILESTONE_ID"
     [ ! -d "$log_dir" ] && [ -d "$ORCH_ROOT/phases" ] && log_dir="$ORCH_ROOT"
     log_file="$log_dir/execution-log.jsonl"
     ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
     # Build dropped_ids JSON array from comma-separated string.
     local ids_json="[]"
     if [ -n "$dropped_ids" ]; then
       ids_json="[\"$(printf '%s' "$dropped_ids" | sed 's/,/","/g')\"]"
     fi
     # Build drop_list JSON array from drop-list file.
     local drop_list_file="$TMPDIR_BUILD/_drop_list.txt"
     local drop_json="[]"
     if [ -f "$drop_list_file" ]; then
       drop_json="$(awk '{ if (NR==1) printf "[\"%s\"", $0; else printf ",\"%s\"", $0 } END { print "]" }' "$drop_list_file")"
     fi
     mkdir -p "$log_dir" 2>/dev/null || return 0
     printf '{"record_type":"payload_filter","filter":"knowledge_status","drop_list":%s,"dropped_count":%d,"dropped_tokens":%d,"dropped_ids":%s,"source":"runtime","unitId":"%s/%s/%s","milestone":"%s","phase":"%s","task":"%s","timestamp":"%s"}\n' \
       "$drop_json" "$dropped_count" "$dropped_tokens" "$ids_json" \
       "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" \
       "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" \
       "$ts" \
       >> "$log_file" 2>/dev/null || true
     return 0
   }
   ```

   Call it from the bottom of build-context (after `_bc_emit_payload_breakdown "$PAYLOAD_CAPTURE" || true`):

   ```bash
   _bc_emit_payload_filter || true
   ```

8. **Construct the test fixture**. Create `tests/fixtures/m018-p02-knowledge-status/` with:
   - `README.md` — documents the fixture's purpose: "Mixed-status knowledge entries for the M018/P02 filter verifier. 5 entries: 2 `status: stable`, 1 `status: superseded`, 1 `status: experimental`, 1 missing-status (back-compat)."
   - `KNOWLEDGE.md` — five MEM entries with the indicated `status:` field values. Use realistic content (not just lorem ipsum) so the filter's regex grep-match doesn't produce false positives.
   - `KNOWLEDGE-INDEX.md` (or whatever the existing index format is — check `scripts/knowledge/resolve-entries.sh` for the expected shape).
   - A minimal milestone scaffold (`M999-FIXTURE/M999-ROADMAP.md` etc.) so `build-context.sh` can be invoked against it.

9. **Capture a baseline golden payload** at `tests/fixtures/m018-p02-baseline-payload.golden.txt`. Run `build-context.sh` with `compression.enabled: false` against the fixture; capture the Knowledge section verbatim. SC-8 / FR-15 regression test: T04's `m018-p02-disable-flag-honored.sh` verifier diffs the disable-flag-on output against this golden.

10. **Smoke-test locally**:
    - With filter enabled (default): run `build-context.sh` against the fixture; assert the resulting payload omits the 2 drop-list-matching entries; assert `execution-log.jsonl` carries a `payload_filter` record with `dropped_count: 2`; assert the `payload_breakdown` record carries `filter_dropped_tokens > 0`.
    - With `compression.enabled: false`: run again; assert the payload's Knowledge section is byte-identical to the golden; assert no `payload_filter` record was written.
    - With missing-status entry: assert it is RETAINED (not dropped).

## Must-Haves

This task addresses the phase truths:

- The filter reads `status:` and excludes drop-list values; missing field → retained. (Verified by `bash scripts/verify/m018-p02-filter-drops.sh` from T04.)
- The `payload_filter` record is emitted; `payload_breakdown` carries `filter_dropped_tokens`; pre-M018 records remain valid JSON. (Verified by `bash scripts/verify/m018-p02-emitter-additivity.sh` from T04.)
- `compression.enabled: false` short-circuits the filter; payload byte-identical to golden. (Verified by `bash scripts/verify/m018-p02-disable-flag-honored.sh` from T04.)

## Verification

```
bash scripts/dispatch/build-context.sh --fixture tests/fixtures/m018-p02-knowledge-status
```

Expected: stdout payload's Knowledge section omits the 2 drop-list-matching MEM IDs; the missing-status MEM is retained; `execution-log.jsonl` (under the fixture's milestone dir) carries one new `payload_filter` line with `dropped_count: 2` and one `payload_breakdown` line with `filter_dropped_tokens` > 0.

Then run with the disable flag:

```
ORCH_OVERRIDE_COMPRESSION_ENABLED=false bash scripts/dispatch/build-context.sh --fixture tests/fixtures/m018-p02-knowledge-status > /tmp/p02-disabled-payload.txt
diff <(grep -A 999 '## Knowledge' /tmp/p02-disabled-payload.txt | sed -n '/^## Knowledge/,/^## /p') tests/fixtures/m018-p02-baseline-payload.golden.txt
```

(Note: the verifier T04 ships will use script-file shape per AD-19; the inline `diff <(...)` above is for manual smoke only.)

The phase-level verifier `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P02/` runs after T04 lands all phase-truth verifiers.

## Inputs

### From Previous Tasks

- `scripts/lib/preservation-check.sh` (from T01)
  - Key API: `pres_check_section <section_id> <pre_file> <post_file> [tier]`, `pres_emit_violation <tier> <section> <pattern> <log_file>`, `pres_density_pre_check <section_file> <max_density_pct>`.
  - Key types: parallel indexed arrays `PRES_PATTERNS_REGEX`, `PRES_PATTERN_NAMES`. Sourceable.
  - Behavioral contract: `pres_check_section` returns 0 on PASS, 1 on first violation; `pres_emit_violation` is bail-safe; `pres_density_pre_check` returns 1 (refuse) when density exceeds threshold.
  - In T02: source the library defensively. T02's filter does NOT call `pres_check_section` (filter operates on whole-entry granularity per grammar contract); the source ensures P03/P04/P06 inherit a working source path with no further wiring.

### From Disk (Pre-existing)

- `scripts/dispatch/build-context.sh` — integration target. Existing functions to extend: `_bc_gather_knowledge_from_index` (line 382), `_bc_gather_knowledge_flat` (line 467), `_bc_emit_payload_breakdown` (line 1042). Existing helpers to reuse: `config_read` (line 141), `chars_to_tokens_quartile` (sourced from `scripts/lib/pricing.sh`).
- `scripts/knowledge/resolve-entries.sh` — produces the multi-entry markdown stream the filter consumes. Output contract: each entry begins with `---\n`, ends before the next `---\n` or EOF; the entry's `status:` field appears within the frontmatter block.
- `references/compression-grammar.md` `## Tier: filter` (lines 144–164) — the failure-semantics contract: missing `status:` → retain; parse error → retain + `entry_status_unparseable` field; never crash.
- `templates/config-defaults.yml` — the canonical defaults file mirrored into `.orchestrator/config.yml`.
- `.orchestrator/scratch/m018-section-distribution-output.json` — `model_assumptions.filter` block (mean_drop=0.30, Beta(2,5) prior) informs the test fixture's drop ratio (5 entries × 30% ≈ 1.5 → fixture ships 2 drops to demonstrate).

## Constraints

- **Bash 3.2 + AP-009 / AD-19 shape**. Every new shell function uses sequential statements, no compound chains > 2, no `$(...|...)`, no plain subshells.
- **Awk is the heavy lift**. The `_bc_filter_knowledge_by_status` function delegates entry-boundary detection to a single awk script — gawk's associative arrays and `RS`/`FS` machinery are AP-009-safe (awk runs in its own process; the bash `awk '...' file > out` invocation is a single command).
- **Additive emitter (CON-5)**. The `payload_breakdown` extension adds a single new top-level field (`filter_dropped_tokens`); pre-M018 records remain valid JSON. The `payload_filter` record is a brand-new `record_type`; existing rollups that key by `record_type` ignore it cleanly.
- **Bail-safe**. Filter failure (config missing, awk error) MUST pass through unmodified knowledge stream and emit no `payload_filter` record. Constitution Principle XI compliance.
- **Originals authoritative (FR-17 / Constitution VI)**. The filter operates on a stream piped from `resolve-entries.sh` output; it never modifies on-disk knowledge files.
- **Multi-runtime parity (FR-13)**. The filter is bash-only; no LLM call; output is byte-identical across CC / Codex CLI / Cursor (M009 launch gate).
- **AGENTS.md dual-write convention**. T02 does NOT edit CLAUDE.md or AGENTS.md. T04 handles the dual-write recent-changes refresh.
- **Dogfood inflection**. Once T02 lands, every M018 dispatch from P03 onward filters knowledge entries. The integration MUST not break self-application: existing M018 phase plans + summaries reference MEM IDs that may or may not carry `status:` fields. Missing-field defaults to RETAINED, so no in-flight phase loses knowledge.

## Expected Output

- `scripts/dispatch/build-context.sh` modified — adds `_bc_read_drop_list`, `_bc_filter_knowledge_by_status`, `_bc_emit_payload_filter`, sourced preservation library, extended `_bc_emit_payload_breakdown`. Estimated +180–250 lines.
- `.orchestrator/config.yml` modified — adds `compression:` block.
- `templates/config-defaults.yml` modified — same block mirrored.
- `tests/fixtures/m018-p02-knowledge-status/` created — fixture milestone with 5 mixed-status MEM entries.
- `tests/fixtures/m018-p02-baseline-payload.golden.txt` created — golden capture under `compression.enabled: false`.
- Smoke tests pass: filter drops 2/5 entries in the default config; disable flag produces byte-identical golden; missing-status entry is retained.

## State Context

- **Current State**: executing
- **Milestone**: M018
- **Phase**: P02
- **Task**: T02-knowledge-filter
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **Bash 3.2 + AP-009 / AD-19 shape**. Every new shell function uses sequential statements, no compound chains > 2, no `$(...|...)`, no plain subshells.
- **Awk is the heavy lift**. The `_bc_filter_knowledge_by_status` function delegates entry-boundary detection to a single awk script — gawk's associative arrays and `RS`/`FS` machinery are AP-009-safe (awk runs in its own process; the bash `awk '...' file > out` invocation is a single command).
- **Additive emitter (CON-5)**. The `payload_breakdown` extension adds a single new top-level field (`filter_dropped_tokens`); pre-M018 records remain valid JSON. The `payload_filter` record is a brand-new `record_type`; existing rollups that key by `record_type` ignore it cleanly.
- **Bail-safe**. Filter failure (config missing, awk error) MUST pass through unmodified knowledge stream and emit no `payload_filter` record. Constitution Principle XI compliance.
- **Originals authoritative (FR-17 / Constitution VI)**. The filter operates on a stream piped from `resolve-entries.sh` output; it never modifies on-disk knowledge files.
- **Multi-runtime parity (FR-13)**. The filter is bash-only; no LLM call; output is byte-identical across CC / Codex CLI / Cursor (M009 launch gate).
- **AGENTS.md dual-write convention**. T02 does NOT edit CLAUDE.md or AGENTS.md. T04 handles the dual-write recent-changes refresh.
- **Dogfood inflection**. Once T02 lands, every M018 dispatch from P03 onward filters knowledge entries. The integration MUST not break self-application: existing M018 phase plans + summaries reference MEM IDs that may or may not carry `status:` fields. Missing-field defaults to RETAINED, so no in-flight phase loses knowledge.

### Acceptance Criteria

This task addresses the phase truths:

- The filter reads `status:` and excludes drop-list values; missing field → retained. (Verified by `bash scripts/verify/m018-p02-filter-drops.sh` from T04.)
- The `payload_filter` record is emitted; `payload_breakdown` carries `filter_dropped_tokens`; pre-M018 records remain valid JSON. (Verified by `bash scripts/verify/m018-p02-emitter-additivity.sh` from T04.)
- `compression.enabled: false` short-circuits the filter; payload byte-identical to golden. (Verified by `bash scripts/verify/m018-p02-disable-flag-honored.sh` from T04.)

### Files To Touch

- `scripts/lib/preservation-check.sh` (create — T01)
- `scripts/dispatch/build-context.sh` (modify — T02 adds knowledge filter + emitter extension; T03 adds aggregate self-check)
- `.orchestrator/config.yml` (modify — T02 adds `compression:` block; T03 adds `compression.underperformance:` keys)
- `templates/config-defaults.yml` (modify — T02 + T03 mirror new defaults)
- `tests/fixtures/m018-p02-knowledge-status/` (create — T02 fixture milestone with mixed-status MEMs)
- `tests/fixtures/m018-p02-knowledge-status/README.md` (create — T02)
- `tests/fixtures/m018-p02-baseline-payload.golden.txt` (create — T02 golden capture)
- `scripts/verify/m018-p02-filter-drops.sh` (create — T04)
- `scripts/verify/m018-p02-emitter-additivity.sh` (create — T04)
- `scripts/verify/m018-p02-preservation-check-api.sh` (create — T04)
- `scripts/verify/m018-p02-underperformance-emit.sh` (create — T04)
- `scripts/verify/m018-p02-disable-flag-honored.sh` (create — T04)
- `scripts/verify/m018-p02-dual-write-recent.sh` (create — T04)
- `CLAUDE.md` (modify — T04 refreshes `orchestrator:recent-changes` block)
- `AGENTS.md` (modify — T04 via `scripts/util/dual-write-runtime-md.sh`; never edited directly)
- [`.orchestrator/milestones/M018/phases/P02/P02-SUMMARY.md`](../../../../../milestones/M018/phases/P02/P02-SUMMARY.md) (create — T04)

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