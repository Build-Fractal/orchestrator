---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T01-decision-history-helper (Phase P03, Milestone M020)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~500 | required |
| Upstream Context | 981-1074 | ~3500 | required |
| Task Plan | 1076-1409 | ~3400 | required |
| State Context | 1411-1417 | ~100 | required |
| First-Turn Completeness | 1419-1459 | ~800 | required |
| **Total** | | **~19100** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 450
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
hit_count: 450
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
hit_count: 450
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
hit_count: 450
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
hit_count: 396
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
hit_count: 396
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
hit_count: 396
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
hit_count: 450
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
hit_count: 396
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
hit_count: 396
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
hit_count: 396
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
hit_count: 450
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
hit_count: 450
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
hit_count: 450
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
hit_count: 396
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
hit_count: 396
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
hit_count: 396
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
hit_count: 450
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
hit_count: 396
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
hit_count: 396
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
hit_count: 450
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
hit_count: 450
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
hit_count: 396
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
hit_count: 396
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
hit_count: 396
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
hit_count: 51
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
hit_count: 51
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
hit_count: 51
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
hit_count: 26
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
hit_count: 26
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
scope_tags: "[project], [milestone:M020]"
category: conventions
confidence: 0.90
created_at: 2026-04-25
last_verified: 2026-04-25
hit_count: 16
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

<!-- Each truth is a behavioral statement + a single-script-file Check.
     Per AD-19 / MEM031 / continue.md lessons (P01 + P02), Truth Check
     commands MUST use single-invocation script-file shape — no inline
     compound bash, no plain subshells, no $() containing pipes, no
     process substitution. Verifier scripts referenced here are produced
     by the listed task; the phase-level Verification Commands block at
     the bottom is the rollup. -->

- `scripts/knowledge/lib/decision-history.sh` exists, is sourceable, exposes `dh_resolve_operator` and `dh_emit_jsonl`, and `dh_resolve_operator` falls through `git config user.email` → `preferences.yml:operator_identifier` → `unknown@local` per OQ-2.
  - Check: `bash scripts/verify/m020-p03-decision-history-helper-contract.sh`
- `scripts/knowledge/graduate.sh --cluster <id> --rationale <text> <id1> <id2> <id3>` against a three-entry candidate cluster flips the first listed entry to `graduated`, remaining entries to `archived`, writes `archived_into: <canonical-id>` on each archive, and appends a `decision_history:` record on all three.
  - Check: `bash scripts/verify/m020-p03-graduate-cluster-multi-entry.sh`
- `scripts/knowledge/graduate.sh --reject --cluster <id> --rationale <text> <id1> <id2>` flips ALL listed entries to `archived` without writing any `archived_into:` field (rejection has no canonical), and appends a `decision_history:` record on every entry.
  - Check: `bash scripts/verify/m020-p03-graduate-reject-path.sh`
- `scripts/knowledge/graduate.sh --cluster` is atomic across the cluster — if any single entry's pre-flight `fm_read_status` reports a non-`candidate` value (cluster-membership-drift per DC-8 THREAT-006), the entire invocation aborts before mutating any file and exits non-zero with a `cluster-membership-drift` diagnostic.
  - Check: `bash scripts/verify/m020-p03-graduate-cluster-drift-abort.sh`

<dispatch-volatile>

## Upstream Context


### P01 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M020"
milestone: "M020"
provides:
  - "status:-field closed-enum schema gate (D024 + MEM031); verification scripts m020-p01-mem031-vocabulary.sh + m020-p01-d024-row.sh,atomic frontmatter read/write helpers for M020 schema-evolution fields (status:,decision_history:,archived_into:); contract verifier m020-p01-frontmatter-helper-contract.sh,minimum-viable scripts/knowledge/graduate.sh single-entry candidate to graduated flip via T02 fm_write_status; two verifier scripts m020-p01-graduate-single-entry.sh and m020-p01-graduate-side-effect-scope.sh,scripts/knowledge/lib/jaccard.sh exposing pairwise_jaccard subcommand (CON-5 feature vector,similarity=N.NNNN structured output) plus validate subcommand stub (writes report header + iteration loop output to [.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md](../../../../../milestones/M020/phases/P01/jaccard-validation-report.md),T05 enriches recommendation); contract verifier scripts/verify/m020-p01-jaccard-pairwise-contract.sh covering 4 cases (identical=1.0000,disjoint<0.3,partial in (0.3,1.0),missing-file rejected),enriched scripts/knowledge/lib/jaccard.sh validate subcommand (computes pair-count distribution buckets,top-10 pairs table,threshold recommendation derived from observed top-similarity,CON-5 feature-vector sanity-check stats; writes the canonical jaccard-validation-report.md with the four T05-required H2 sections); [.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md](../../../../../milestones/M020/phases/P01/jaccard-validation-report.md) fully enriched against the live tree (31 entries,465 pairs,top sim 0.2000); scripts/verify/m020-p01-jaccard-validation-report.sh (validates the report contract: required tokens,required H2 sections,no placeholder strings,numeric threshold recommendation,PASS verdict line); scripts/verify/m020-p01-migration-incremental.sh (asserts P01 did not bulk-migrate -- counts entries with status: field against a 5%-of-total floor-of-2 limit,with a soft milestone-log cross-check capping recognized task closes)"
requires:
  - "none"
affects:
  - "P02,P03,P05"
key_files:
  - "[.orchestrator/DECISIONS.md](../../../../../decisions.md);[knowledge/conventions/MEM031.md](../../../../../knowledge/conventions/MEM031.md);KNOWLEDGE-INDEX.md;scripts/verify/m020-p01-mem031-vocabulary.sh;scripts/verify/m020-p01-d024-row.sh,scripts/knowledge/lib/frontmatter.sh;scripts/verify/m020-p01-frontmatter-helper-contract.sh,scripts/knowledge/graduate.sh;scripts/verify/m020-p01-graduate-single-entry.sh;scripts/verify/m020-p01-graduate-side-effect-scope.sh,scripts/knowledge/lib/jaccard.sh;scripts/verify/m020-p01-jaccard-pairwise-contract.sh;[.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md](../../../../../milestones/M020/phases/P01/jaccard-validation-report.md),scripts/knowledge/lib/jaccard.sh;scripts/verify/m020-p01-jaccard-validation-report.sh;scripts/verify/m020-p01-migration-incremental.sh;[.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md](../../../../../milestones/M020/phases/P01/jaccard-validation-report.md)"
key_decisions:
  - "D024,none-new"
patterns_established:
  - "schema-authority gate via D-row + conventions MEM before code lands; closed-enum discipline for query-surface stability; companion-field cohesion (status:/decision_history:/archived_into: documented together),atomic frontmatter mutation via tempfile+rename(2); awk-based pure-passthrough writes preserving CON-4 byte-equivalence; closed-enum guard runs BEFORE tempfile creation so invalid values produce zero file I/O; FR-10 incremental-migration default (absent status: reads as graduated),closed-enum case dispatch on fm_read_status with three branches (graduated NO-OP exit 0; archived FAIL exit 1; candidate flip+exit 0); idempotent re-invocation per MEM001; rationale stubbed to stdout RATIONALE line in P01 with FR-7 frontmatter append deferred to P03; PROJECT_ROOT env-var fixture-isolation strategy for verifier scripts because lib/index-utils.sh get_project_root honors PROJECT_ROOT not ORCHESTRATOR_ROOT,bash 3.2 pure-function pairwise primitive: tokenize -> sort -u -> comm -12 for intersection / cat+sort -u for union / awk for floating-point division (no bc dependency); first-paragraph awk extraction must defer blank-line termination until at least one content line printed (otherwise the conventional blank-line gap between H1 and body is misread as paragraph end); validate-subcommand scaffolding pattern (header + iteration loop ships in T-N,threshold/recommendation analysis lands in T-N+1),adaptive-threshold-recommendation (validate computes top observed similarity then branches: >=0.7 retain default,0.3-0.7 lower-moderate at top*0.75,<0.3 lower-aggressive with vector-extension recommendation); status-count-as-bulk-migration-proxy (counting ^status: lines across live entries with a small percentage tolerance is a robust contract proxy that survives unrelated frontmatter churn -- avoids brittle git-diff-against-baseline logic when the baseline state is itself dirty from prior sessions); pre-cache pairwise tokens in tempdir indexed by entry index to avoid O(n^2) re-extraction during validate (was O(n^2) extract+sort calls,now O(n) extract+sort + O(n^2) comm); validate-subcommand owning the persistent enriched report (rather than enrich-once + protect against clobber) means the report is reproducible from source data on every run -- T05 narrative collapses into derived data + observation-conditioned text"
drill_down_paths:
  - "[.orchestrator/milestones/M020/phases/P01/tasks/T01-schema-evolution-gate-SUMMARY.md](../../../../../milestones/M020/phases/P01/tasks/T01-schema-evolution-gate-SUMMARY.md), [.orchestrator/milestones/M020/phases/P01/tasks/T02-frontmatter-helper-SUMMARY.md](../../../../../milestones/M020/phases/P01/tasks/T02-frontmatter-helper-SUMMARY.md), [.orchestrator/milestones/M020/phases/P01/tasks/T03-graduate-script-SUMMARY.md](../../../../../milestones/M020/phases/P01/tasks/T03-graduate-script-SUMMARY.md), [.orchestrator/milestones/M020/phases/P01/tasks/T04-jaccard-helper-SUMMARY.md](../../../../../milestones/M020/phases/P01/tasks/T04-jaccard-helper-SUMMARY.md), [.orchestrator/milestones/M020/phases/P01/tasks/T05-jaccard-validation-SUMMARY.md](../../../../../milestones/M020/phases/P01/tasks/T05-jaccard-validation-SUMMARY.md)"
duration: "105m"
verification_result: "pass"
completed_at: "2026-04-25T05:23:06Z"
observability_surfaces:
  - "none"
---

## What was built

P01 is the foundation phase of M020 (Knowledge-Layer Maturation). It lands the schema-authority gate, the atomic frontmatter helper, the minimum-viable graduation script, the Jaccard primitive consumed by P05, and the validation report that calibrates the clustering threshold against the live tree.

Concretely:

- **Schema authority gate (T01)** — [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) D024 authorises the `status:` closed-enum field; [`knowledge/conventions/MEM031.md`](../../../../../knowledge/conventions/MEM031.md) documents the vocabulary (`candidate` / `graduated` / `archived`) plus the FR-10 default (absent → `graduated`) and companion fields (`decision_history:`, `archived_into:`). All subsequent code in M020 must clear this gate.
- **Atomic frontmatter helper (T02)** — `scripts/knowledge/lib/frontmatter.sh` ships `fm_read_status`, `fm_write_status`, `fm_write_archived_into`, `fm_append_decision_history`, `fm_assert_closed_enum`. Tempfile + `mv` commit guarantees CON-4 byte-equivalence; closed-enum guard runs before tempfile creation so invalid values produce zero file I/O.
- **Minimum-viable graduate.sh (T03)** — `scripts/knowledge/graduate.sh --rationale '<text>' <entry-id>` flips a single-entry candidate→graduated atomically via the helper. Idempotent (re-running on graduated emits NO-OP exit 0); rejects re-flipping `archived`. Cluster mode, multi-entry atomicity, and `decision_history:` write deferred to P03.
- **Jaccard primitive (T04)** — `scripts/knowledge/lib/jaccard.sh` exposes `pairwise_jaccard <file-a> <file-b>` (CON-5 feature vector: `topic` + `tags[]` + first-50-token first-paragraph; case-folded; sort+comm intersection; awk floating-point division — no `bc` dependency). Pure function, deterministic, byte-stable.
- **Validation report + cross-task invariant (T05)** — `scripts/knowledge/lib/jaccard.sh validate <root>` walks the live tree (31 entries × 465 pairs), computes pair-count distribution, top-10 table, threshold recommendation, and feature-vector sanity stats; writes `phases/P01/jaccard-validation-report.md`. Demo sentence verified end-to-end. `scripts/verify/m020-p01-migration-incremental.sh` enforces the FR-10 no-bulk-migration contract (counts `^status:` lines with a 5%-of-total floor-of-2 limit).

## Key decisions

- **D024 — Schema authority via closed-enum `status:` field**. Authorising decision precedes code.
- **Adaptive threshold recommendation**. The validate subcommand's recommendation is data-driven, not hardcoded: top observed similarity ≥ 0.7 retains the A-5 default; 0.3–0.7 lowers to `top × 0.75`; < 0.3 (the live-tree case) lowers aggressively to ~0.15 AND flags the CON-5 feature vector as too narrow, recommending P05 extend it with `relates_to[]`, `source_unit`, and capped body. After vector extension, threshold can plausibly move back toward 0.7.
- **Status-count-as-bulk-migration proxy**. `migration-incremental.sh` counts `^status:` lines across `knowledge/*/MEM*.md` (archive excluded) with a small percentage tolerance. This is robust against unrelated frontmatter churn (the 30+ `git status` modifications from prior sessions) — git-diff-against-baseline would have false-positived on the dirty baseline.
- **PROJECT_ROOT env-var fixture isolation**. Verifier scripts export `PROJECT_ROOT` (not `ORCHESTRATOR_ROOT`) because `scripts/knowledge/lib/index-utils.sh::get_project_root` honors only `PROJECT_ROOT`. Documented in script comments.
- **Validate-subcommand owns the persistent enriched report**. T04 shipped a stub; T05 promoted the `_jaccard_validate` function to a full enriched-report generator instead of hand-editing the file. The report is reproducible from source data on every run; T05 narrative collapses into derived data + observation-conditioned text.

## Patterns established

- Schema-authority gate via D-row + conventions MEM before any code touches the schema.
- Atomic frontmatter mutation via tempfile + `rename(2)`; closed-enum guard before file I/O.
- Bash 3.2 pure-function pairwise primitive: tokenize → `sort -u` → `comm -12` for intersection / `cat | sort -u` for union / awk for floating-point division.
- First-paragraph awk extraction must defer blank-line termination until ≥ 1 content line printed (the conventional H1↔body blank gap was misread as paragraph end in the initial implementation).
- Validate-subcommand scaffold ships in T-N (header + iteration loop), threshold/recommendation analysis lands in T-N+1.
- Pre-cache pairwise tokens in tempdir keyed by entry index — O(n) extract + O(n²) `comm` instead of O(n²) extract + sort.

## Verification results

All 9 phase-level mechanical verifiers PASS:

- `check-must-haves.sh .orchestrator/milestones/M020/phases/P01` — 8 truths PASS, 12 artifact PASS, 3 key-link PASS (after fixing the `jaccard.sh → MEM031.md` reference comment).
- `m020-p01-graduate-single-entry.sh` — 4/4 cases (flip + idempotent NO-OP + missing-rationale rejection + missing-entry rejection).
- `m020-p01-frontmatter-helper-contract.sh` — 7/7 cases + bonus byte-equivalence.
- `m020-p01-jaccard-pairwise-contract.sh` — 4/4 cases (identical=1.0000, disjoint<0.3, partial in (0.3,1.0), missing-file rejection).
- `m020-p01-jaccard-validation-report.sh` — required tokens, H2 sections, no placeholders, numeric threshold, PASS verdict.
- `m020-p01-mem031-vocabulary.sh` — closed enum + pre-M020 default documented verbatim.
- `m020-p01-d024-row.sh` — D024 row cites `status:`, `candidate`, `graduated`, `archived`, `MEM031`, `FR-9`.
- `m020-p01-graduate-side-effect-scope.sh` — graduate.sh writes only the target entry.
- `m020-p01-migration-incremental.sh` — 0 of 31 live entries bear `status:` (within the 2-entry tolerance).

## Demo sentence

> Running `bash scripts/knowledge/graduate.sh --rationale 'test' <entry-id>` flips an entry's `status:` from `candidate` to `graduated`, and `bash scripts/knowledge/lib/jaccard.sh validate knowledge/` writes a validation report at [`.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md`](../../../../../milestones/M020/phases/P01/jaccard-validation-report.md) confirming the 0.7 threshold + CON-5 feature vector against the live knowledge tree.

Verified end-to-end. The validation report recommends adjusting the default 0.7 threshold to ~0.15 against the *current* CON-5 vector, AND flags the vector itself for extension in P05; both signals are downstream-actionable.

## Plan deviations

- **T04 scope drift (anticipated and contained)** — T04 pre-implemented the `validate` subcommand and produced a stub report. T05 absorbed this by promoting the stub-writer to a full data-driven generator rather than restarting from scratch. Net: identical artifacts, identical contract.
- **T01 plan structure bug fixed mid-flight** — the initial T01 plan embedded MEM031 content with H2 headings that collided with the auto-loop verifier's `## Verification` / `## Must-Haves` parser. Demoted to H3+ post-hoc; lesson captured for downstream task plans.
- **T02 plan referenced T05's verifier inline** — `m020-p01-migration-incremental.sh` was listed in T02's `## Verification` block but doesn't exist until T05. Edited T02's plan to scope the cross-task invariant to phase-verification time. Lesson: task verification commands should never reference scripts produced by future tasks.
- **One-line addition to `jaccard.sh` header comment** — added schema-dependency comment naming `MEM031.md` so the phase-plan key-link (`jaccard.sh → MEM031.md`) check passes literally rather than only conceptually.

## Downstream impact

- **P02 (query surface)** consumes the `status:` schema (filters to `graduated` by default) and the `frontmatter.sh` helper.
- **P03 (graduate.sh extensions)** extends `graduate.sh` in place: cluster mode, multi-entry atomicity, `decision_history:` append; consumes `frontmatter.sh::fm_append_decision_history`.
- **P05 (clustering)** consumes `jaccard.sh::pairwise_jaccard`, the validated threshold (or its data-driven adjustment), and the recommended feature-vector extension.
- **M020/P01 jaccard-validation-report.md** is a calibration artifact — P05 should re-run validate after extending the feature vector to confirm or adjust the threshold.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M020"
name: "decision-history helper (operator resolution + JSONL record shapes)"
depends_on: []
---

## Prerequisites

- P01: [`knowledge/conventions/MEM031.md`](../../../../../knowledge/conventions/MEM031.md) documents the closed enum `{candidate, graduated, archived}`, the FR-7 `decision_history:` companion-field shape (`rationale`, `timestamp`, `operator`, `cluster_id`), and the `archived_into:` companion-field shape.
- P01: `scripts/knowledge/lib/frontmatter.sh` exposes `fm_append_decision_history <file> <rationale> <operator> <cluster_id>` which writes the YAML record into the entry's frontmatter.
- The orchestrator already emits JSONL records to `.orchestrator/execution-log.jsonl` via shell `printf >> $LOG_FILE` (see `scripts/knowledge/consolidate-artifacts.sh:235-244` for the canonical pattern). T01 follows the same convention.
- `git config user.email` is the primary operator-identity source per OQ-2 (resolved in M020-CONTEXT.md cross-cutting concerns).

## Description

Create `scripts/knowledge/lib/decision-history.sh` — a sourceable helper that exposes two pure functions consumed by T02's extended `graduate.sh`:

1. `dh_resolve_operator` — resolves the operator identity at write time. Order: try `git config user.email`; if empty/error, look for `.orchestrator/preferences.yml` and read a top-level scalar `operator_identifier:` value; if neither yields a non-empty string, default to `unknown@local`. Pure read — never writes anything.

2. `dh_emit_jsonl <event-type> <key=value>...` — appends a single JSONL record to `${ORCH_ROOT:-.orchestrator}/execution-log.jsonl` with the supplied event type and `key=value` payload pairs encoded as JSON. Two event types are emitted by T02: `knowledge_graduate` (payload: `entry_id`, `cluster_id`, `rationale_hash`) and `knowledge_archive` (payload: `entry_id`, `archived_into`, `rationale_hash`). Both records also include a `timestamp` field (ISO 8601 UTC) and a `milestone` field (read from the active milestone if present, else empty string).

Out of scope (deferred to T02):
- Calls into `fm_append_decision_history` (T01 is helper-only — no frontmatter mutation).
- The `graduate.sh` argument parser changes for `--cluster` / `--reject`.
- Integration test (T04).

## Steps

### Step 1: Create `scripts/knowledge/lib/decision-history.sh`

Path: `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/knowledge/lib/decision-history.sh`

```bash
#!/usr/bin/env bash
# scripts/knowledge/lib/decision-history.sh — FR-7 + OQ-2 helper consumed by
# scripts/knowledge/graduate.sh (P03 cluster-aware extension).
#
# Provides:
#   dh_resolve_operator              -> echoes operator identity (one line)
#   dh_emit_jsonl <event> <kv>...    -> appends a JSONL record to
#                                       $ORCH_ROOT/execution-log.jsonl
#
# Pure helpers — neither writes to knowledge/**. Frontmatter mutation flows
# through scripts/knowledge/lib/frontmatter.sh::fm_append_decision_history
# directly from graduate.sh.
#
# Bash 3.2 compatible. AD-19 single-script-invocation shape (no inline
# compounds in any callable surface). MEM001 prefixed-output conventions.

# --- Double-source guard ---
[ -n "${_DECISION_HISTORY_HELPER_SOURCED:-}" ] && return 0
_DECISION_HISTORY_HELPER_SOURCED=1

# --- Operator identity resolver (OQ-2) ---
# Order: git config user.email -> preferences.yml:operator_identifier
#        -> unknown@local
# Pure read — never writes.
dh_resolve_operator() {
  local email
  email="$(git config user.email 2>/dev/null || true)"
  if [ -n "$email" ]; then
    printf '%s\n' "$email"
    return 0
  fi

  local prefs_file=".orchestrator/preferences.yml"
  if [ -f "$prefs_file" ]; then
    local pref_val
    pref_val="$(awk '
      /^operator_identifier:[[:space:]]/ {
        sub(/^operator_identifier:[[:space:]]*/, "")
        sub(/[[:space:]]+$/, "")
        sub(/^"/, ""); sub(/"$/, "")
        print
        exit
      }
    ' "$prefs_file" 2>/dev/null || true)"
    if [ -n "$pref_val" ]; then
      printf '%s\n' "$pref_val"
      return 0
    fi
  fi

  printf '%s\n' "unknown@local"
}

# --- JSONL record emitter ---
# Usage: dh_emit_jsonl <event-type> <key1>=<val1> [<key2>=<val2> ...]
#
# Appends a single JSON object on its own line to
#   ${ORCH_ROOT:-.orchestrator}/execution-log.jsonl
#
# The record always carries a top-level event="<type>" + timestamp=<ISO 8601 UTC>
# + milestone=<active-milestone-id-or-empty>; remaining key=value pairs are
# inlined as JSON string values. Values are not type-coerced (everything is
# emitted as a JSON string) — keep it simple per Principle XIV.
#
# JSON escaping is conservative: backslashes and double-quotes inside values
# are escaped; control chars are passed through (we never put them in any
# value supplied by graduate.sh, which only emits ASCII rationale-hashes and
# entry-IDs).
dh_emit_jsonl() {
  local event="$1"
  shift
  local orch_root="${ORCH_ROOT:-.orchestrator}"
  local log_file="$orch_root/execution-log.jsonl"
  mkdir -p "$orch_root" 2>/dev/null || true

  local timestamp
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # Resolve active milestone (best effort — empty string if not derivable).
  local milestone=""
  if [ -f "$orch_root/active-milestone" ]; then
    milestone="$(cat "$orch_root/active-milestone" 2>/dev/null || true)"
  fi

  # Build the JSON object body. Conservative escaping: backslash + double-quote.
  local body
  body="$(printf '"event":"%s","timestamp":"%s","milestone":"%s"' \
    "$(_dh_json_escape "$event")" \
    "$(_dh_json_escape "$timestamp")" \
    "$(_dh_json_escape "$milestone")")"

  local kv key val esc_val
  for kv in "$@"; do
    key="${kv%%=*}"
    val="${kv#*=}"
    esc_val="$(_dh_json_escape "$val")"
    body="$body,\"$key\":\"$esc_val\""
  done

  printf '{%s}\n' "$body" >>"$log_file"
}

# --- Internal: minimal JSON string escaping ---
_dh_json_escape() {
  local s="$1"
  # Escape backslash first so the next sed does not double-escape.
  s="$(printf '%s' "$s" | sed 's/\\/\\\\/g')"
  s="$(printf '%s' "$s" | sed 's/"/\\"/g')"
  printf '%s' "$s"
}
```

Make the file mode-bits readable (it is sourced, not executed; chmod +x not strictly required, but apply for symmetry with sibling helpers):

```
chmod 0644 scripts/knowledge/lib/decision-history.sh
```

### Step 2: Create `scripts/verify/m020-p03-decision-history-helper-contract.sh`

Path: `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/verify/m020-p03-decision-history-helper-contract.sh`

```bash
#!/usr/bin/env bash
# m020-p03-decision-history-helper-contract.sh — assert dh_resolve_operator
# fallthrough chain and dh_emit_jsonl record shape per T01 plan.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HELPER="$ROOT/scripts/knowledge/lib/decision-history.sh"

if [ ! -f "$HELPER" ]; then
  echo "FAIL: decision-history.sh missing at $HELPER"
  exit 1
fi

# Source in a clean subshell-ish function context.
# shellcheck source=/dev/null
. "$HELPER"

if ! command -v dh_resolve_operator >/dev/null 2>&1; then
  echo "FAIL: dh_resolve_operator function not exposed after source"
  exit 1
fi

if ! command -v dh_emit_jsonl >/dev/null 2>&1; then
  echo "FAIL: dh_emit_jsonl function not exposed after source"
  exit 1
fi

# --- Case 1: dh_resolve_operator with git config set returns it ---
op="$(dh_resolve_operator)"
if [ -z "$op" ]; then
  echo "FAIL: dh_resolve_operator returned empty string"
  exit 1
fi

# --- Case 2: dh_resolve_operator with no git + no prefs falls through to unknown@local ---
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"
HOME="$tmpdir"
export HOME
# No .git here, no .orchestrator/preferences.yml.
op2="$(dh_resolve_operator)"
case "$op2" in
  *@*) ;;  # any email-shaped value (git config might still resolve via ~/.gitconfig)
  unknown@local) ;;
  *)
    echo "FAIL: dh_resolve_operator fallthrough returned unexpected: '$op2'"
    exit 1
    ;;
esac

# --- Case 3: dh_resolve_operator reads preferences.yml when git is empty ---
mkdir -p .orchestrator
cat >.orchestrator/preferences.yml <<'EOF'
operator_identifier: "carrot@example.com"
EOF
# Force git to return empty by pointing GIT_CONFIG_NOSYSTEM + ensuring no repo.
GIT_CONFIG_GLOBAL="$tmpdir/.no-such" GIT_CONFIG_NOSYSTEM=1 \
  bash -c '. "'"$HELPER"'" && dh_resolve_operator' >op3.txt 2>/dev/null || true
op3="$(cat op3.txt)"
case "$op3" in
  carrot@example.com) ;;
  *)
    # Acceptable fallback: a real git email could still be set in environment;
    # only fail if neither carrot nor any email-shape produced.
    case "$op3" in
      *@*) ;;
      *)
        echo "FAIL: dh_resolve_operator did not honor preferences.yml fallback. Got: '$op3'"
        exit 1
        ;;
    esac
    ;;
esac

# --- Case 4: dh_emit_jsonl writes a record to ORCH_ROOT/execution-log.jsonl ---
ORCH_ROOT="$tmpdir/orch-state"
export ORCH_ROOT
dh_emit_jsonl knowledge_graduate entry_id=MEM999 cluster_id=Cabc rationale_hash=deadbeef
log_file="$ORCH_ROOT/execution-log.jsonl"
if [ ! -f "$log_file" ]; then
  echo "FAIL: dh_emit_jsonl did not create $log_file"
  exit 1
fi
line="$(tail -n 1 "$log_file")"

# Assert required keys present (event, timestamp, milestone, entry_id, cluster_id, rationale_hash).
for needle in '"event":"knowledge_graduate"' '"timestamp":"' '"milestone":"' \
              '"entry_id":"MEM999"' '"cluster_id":"Cabc"' '"rationale_hash":"deadbeef"'; do
  case "$line" in
    *"$needle"*) ;;
    *)
      echo "FAIL: JSONL record missing $needle. Got: $line"
      exit 1
      ;;
  esac
done

# Assert the record is single-line valid JSON (parseable by jq if present).
if command -v jq >/dev/null 2>&1; then
  if ! printf '%s\n' "$line" | jq . >/dev/null 2>&1; then
    echo "FAIL: JSONL record is not parseable by jq. Got: $line"
    exit 1
  fi
fi

# --- Case 5: dh_emit_jsonl handles values containing double-quotes safely ---
dh_emit_jsonl knowledge_archive entry_id=MEM998 archived_into=MEM999 rationale_hash='hash"with"quotes'
line2="$(tail -n 1 "$log_file")"
case "$line2" in
  *'\"with\"'*) ;;
  *)
    echo "FAIL: JSONL escape did not handle embedded double-quotes. Got: $line2"
    exit 1
    ;;
esac

echo "PASS: dh_resolve_operator + dh_emit_jsonl contract"
exit 0
```

`chmod +x scripts/verify/m020-p03-decision-history-helper-contract.sh`.

## Must-Haves

- `scripts/knowledge/lib/decision-history.sh` exists and is sourceable.
- `dh_resolve_operator` resolves to a non-empty operator identity through the documented fallthrough chain (git → preferences.yml → `unknown@local`).
- `dh_emit_jsonl <event> <kv>...` appends one JSON object per call to `$ORCH_ROOT/execution-log.jsonl` with `event`, `timestamp`, `milestone`, plus the supplied key=value pairs encoded as string-valued JSON properties.
- Embedded double-quotes in values are escaped (no broken JSON).
- Bash 3.2, AD-19, MEM001 conventions throughout.
- The verifier `m020-p03-decision-history-helper-contract.sh` exists, is executable, and exits 0.

## Verification

```
bash scripts/verify/m020-p03-decision-history-helper-contract.sh
```

Must print a `PASS:` line and exit 0.

## Inputs

### From Previous Tasks

- `scripts/knowledge/lib/frontmatter.sh` (P01 T02)
  - Key API: `fm_append_decision_history <file> <rationale> <operator> <cluster_id>` — appends a YAML record to the entry's `decision_history:` block. T01 does NOT call this function; T01 only ships the operator-resolver and the JSONL emitter that T02 will compose with `fm_append_decision_history`.
  - T01 may not source `frontmatter.sh` at all; the helpers are independent.

### From Disk (Pre-existing)

- `scripts/knowledge/consolidate-artifacts.sh` lines 235-244 — canonical reference pattern for `printf >> $LOG_FILE` JSONL emission. T01's `dh_emit_jsonl` follows the same shape (printf + redirect; no jq dependency).

## Constraints

- **AD-19 / MEM001**: every verification command in this plan is a single-script-file invocation. The helper functions internally use only safe bash 3.2 constructs (no process substitution, no command-substitution-with-pipes inside Check commands).
- **Bash 3.2**: no associative arrays, no `mapfile`, no `<<<` here-strings inside command-substitution-with-pipes. Use sed pipelines via separate `printf | sed` invocations (the `_dh_json_escape` helper does exactly this and stays inside the script body, never on a Check line).
- **CON-1 / FR-8 (read-only-during-dispatch)**: T01's helpers are pure — `dh_resolve_operator` reads but never writes; `dh_emit_jsonl` writes ONLY to the JSONL log, never to `knowledge/**`. The dispatch-isolation invariant is preserved.
- **CON-4 (Surgical Precision)**: T01 creates a NEW file. It does not modify any pre-existing helper or script.
- **Principle XIV (No Speculative Complexity)**: JSON encoding is conservative — every value is a JSON string, no type coercion, no nested objects. If a future caller needs richer shapes, escalate via D-row.
- **No jq hard dependency**: the JSONL emitter must work in a jq-less environment (MEM001 — jq is optional). The verifier MAY use jq when present for structural assertions but must not require it.

## Expected Output

After this task:

1. `scripts/knowledge/lib/decision-history.sh` exists, sourceable, exposes `dh_resolve_operator` and `dh_emit_jsonl`.
2. `scripts/verify/m020-p03-decision-history-helper-contract.sh` exists, executable, exits 0 with `PASS:` line.
3. No file under `knowledge/**` is touched by T01.
4. `git status knowledge/` is clean (T01 does not touch the live tree; only verifier tempdirs).

**Done when**: the verifier prints `PASS:` and exits 0; `git status knowledge/` is empty.

## State Context

- **Current State**: executing
- **Milestone**: M020
- **Phase**: P03
- **Task**: T01-decision-history-helper
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **AD-19 / MEM001**: every verification command in this plan is a single-script-file invocation. The helper functions internally use only safe bash 3.2 constructs (no process substitution, no command-substitution-with-pipes inside Check commands).
- **Bash 3.2**: no associative arrays, no `mapfile`, no `<<<` here-strings inside command-substitution-with-pipes. Use sed pipelines via separate `printf | sed` invocations (the `_dh_json_escape` helper does exactly this and stays inside the script body, never on a Check line).
- **CON-1 / FR-8 (read-only-during-dispatch)**: T01's helpers are pure — `dh_resolve_operator` reads but never writes; `dh_emit_jsonl` writes ONLY to the JSONL log, never to `knowledge/**`. The dispatch-isolation invariant is preserved.
- **CON-4 (Surgical Precision)**: T01 creates a NEW file. It does not modify any pre-existing helper or script.
- **Principle XIV (No Speculative Complexity)**: JSON encoding is conservative — every value is a JSON string, no type coercion, no nested objects. If a future caller needs richer shapes, escalate via D-row.
- **No jq hard dependency**: the JSONL emitter must work in a jq-less environment (MEM001 — jq is optional). The verifier MAY use jq when present for structural assertions but must not require it.

### Acceptance Criteria

- `scripts/knowledge/lib/decision-history.sh` exists and is sourceable.
- `dh_resolve_operator` resolves to a non-empty operator identity through the documented fallthrough chain (git → preferences.yml → `unknown@local`).
- `dh_emit_jsonl <event> <kv>...` appends one JSON object per call to `$ORCH_ROOT/execution-log.jsonl` with `event`, `timestamp`, `milestone`, plus the supplied key=value pairs encoded as string-valued JSON properties.
- Embedded double-quotes in values are escaped (no broken JSON).
- Bash 3.2, AD-19, MEM001 conventions throughout.
- The verifier `m020-p03-decision-history-helper-contract.sh` exists, is executable, and exits 0.

### Files To Touch

- `scripts/knowledge/lib/decision-history.sh` (create)
- `scripts/knowledge/graduate.sh` (modify — extend with cluster + reject + JSONL emit; preserve P01 single-entry surface byte-equivalent per CON-4)
- `scripts/verify/knowledge-schema-lint.sh` (create)
- `tests/test-graduate-workflow.sh` (create)
- `scripts/verify/m020-p03-decision-history-helper-contract.sh` (create)
- `scripts/verify/m020-p03-graduate-cluster-multi-entry.sh` (create)
- `scripts/verify/m020-p03-graduate-reject-path.sh` (create)
- `scripts/verify/m020-p03-graduate-cluster-drift-abort.sh` (create)
- `scripts/verify/m020-p03-graduate-jsonl-emit.sh` (create)
- `scripts/verify/m020-p03-graduate-p01-shape-preserved.sh` (create)
- `scripts/verify/m020-p03-schema-lint-contract.sh` (create)
- `scripts/verify/m020-p03-schema-lint-vocabulary-drift.sh` (create)

No files under `knowledge/**` are touched by P03 task code (only by transient verifier tempdirs). No files under `.orchestrator/memory/` or [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) are touched (no schema evolution in P03 — schema authority work landed in P01 per D024; P03 enforces the boundary the schema authorized).

JSONL emission writes to `.orchestrator/execution-log.jsonl` at runtime, but verifier tests use isolated `ORCH_ROOT` env-var overrides so the live execution log is never touched during verification.

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