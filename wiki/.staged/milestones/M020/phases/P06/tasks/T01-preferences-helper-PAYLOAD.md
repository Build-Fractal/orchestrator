---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T01-preferences-helper (Phase P06, Milestone M020)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~600 | required |
| Upstream Context | 981-1162 | ~5400 | required |
| Task Plan | 1164-1503 | ~4300 | required |
| State Context | 1505-1511 | ~100 | required |
| First-Turn Completeness | 1513-1553 | ~800 | required |
| **Total** | | **~22000** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 466
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
hit_count: 466
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
hit_count: 466
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
hit_count: 466
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
hit_count: 409
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
hit_count: 409
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
hit_count: 409
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
hit_count: 466
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
hit_count: 409
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
hit_count: 409
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
hit_count: 409
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
hit_count: 466
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
hit_count: 466
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
hit_count: 466
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
hit_count: 409
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
hit_count: 409
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
hit_count: 409
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
hit_count: 466
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
hit_count: 409
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
hit_count: 409
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
hit_count: 466
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
hit_count: 466
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
hit_count: 409
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
hit_count: 409
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
hit_count: 409
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
hit_count: 64
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
hit_count: 64
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
hit_count: 64
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
hit_count: 42
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
hit_count: 42
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
hit_count: 32
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
     Per AD-19, Truth Check commands MUST use single-invocation script-file
     shape — no inline compound bash, no plain subshells, no $() containing
     pipes, no process substitution. Verifier scripts referenced here are
     produced by the listed task; the phase-level Verification Commands
     block at the bottom is the rollup. Plan-deviation invariant from
     P04: every verifier referenced in a task's Verification section MUST
     be authored by THAT task. -->

- `scripts/knowledge/lib/preferences.sh` exists, is sourceable, and exposes `pref_resolve <key>` returning the effective scalar value for any of the five M020 keys (`default_state_filter`, `similarity_threshold`, `staleness_threshold`, `preferred_cluster_size`, `operator_identifier`) on stdout, with built-in defaults baked in (`graduated`, `0.7`, `14`, `8`, `unknown@local`).
  - Check: `bash scripts/verify/m020-p06-preferences-helper-contract.sh`
- `scripts/knowledge/lib/preferences.sh::pref_resolve` honors project>user>built-in-default precedence per-key (THREAT-007 disposition): when both files declare the same key, the project file wins; when only the user file declares it, the user value wins; when neither declares it, the built-in default is returned.
  - Check: `bash scripts/verify/m020-p06-preferences-precedence.sh`
- `scripts/knowledge/lib/preferences.sh::pref_resolve` falls back to the built-in default when a preference value is malformed (non-numeric for numeric keys, out-of-range for bounded keys, value outside the closed enum for `default_state_filter`), emits a single-line stderr diagnostic naming the offending key + offending value + selected fallback, and NEVER mutates the preferences file (operator-owned).
  - Check: `bash scripts/verify/m020-p06-preferences-malformed-fallback.sh`
- `scripts/knowledge/lib/preferences.sh::pref_resolve` rejects unknown keys (closed-enum key vocabulary, matching the schema-authority pattern of MEM031): an unknown key emits `FAIL: pref_resolve: unknown key '<key>'` on stderr and returns non-zero exit, with no stdout output.

<dispatch-volatile>

## Upstream Context


### P02 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P02"
parent: "M020"
milestone: "M020"
provides:
  - "scripts/knowledge/query.sh implementing FR-2 sub-clauses a-e plus --format ids from f; five T01 verifier scripts under scripts/verify/ for help,default-state-filter,match-rule,ranking,and format-ids,query.sh --format json single-document output (matches array of id/title/status/rank records); empty-result diagnostics for ids and json formats per US-1 acceptance scenario 3; three new verifiers m020-p02-query-format-json.sh / m020-p02-query-no-match-empty.sh / m020-p02-query-side-effect-free.sh enforcing FR-2(f),acceptance scenario 3,and FR-8/CON-1/SC-7 invariant,scripts/dispatch/dispatch-interface.sh --query subcommand passthrough (OQ-4 closure); 12-line early-exit block exec-bridges to scripts/knowledge/query.sh with byte-equivalent stdout/stderr/exit-code; scripts/verify/m020-p02-dispatch-query-wrapper.sh contract verifier (5 cases: ids byte-equiv,json byte-equiv,exit-code propagation on invalid --state,knowledge-tree non-perturbation),tests/test-knowledge-query.sh — 233-line MEM002-conformant integration test covering SC-1 (graduated-only filter,topic+tag matching,rank order,ids+json shapes) and SC-7 (read-only invariant via pre/post hash snapshot) for both direct query.sh and dispatch-interface.sh --query passthrough; degraded-mode skip for jq-absent"
requires:
  - "P01"
affects:
  - "P06"
key_files:
  - "scripts/knowledge/query.sh,scripts/verify/m020-p02-query-help.sh,scripts/verify/m020-p02-query-default-state-filter.sh,scripts/verify/m020-p02-query-match-rule.sh,scripts/verify/m020-p02-query-ranking.sh,scripts/verify/m020-p02-query-format-ids.sh,scripts/verify/m020-p02-query-format-json.sh,scripts/verify/m020-p02-query-no-match-empty.sh,scripts/verify/m020-p02-query-side-effect-free.sh,scripts/dispatch/dispatch-interface.sh;scripts/verify/m020-p02-dispatch-query-wrapper.sh,tests/test-knowledge-query.sh"
key_decisions:
  - "D024,none-new"
patterns_established:
  - "dispatch-callable read-only knowledge query surface sourcing only fm_read_status; lazy topic-keyword index (no persistent cache,walks knowledge tree every query per Principle VI); two-tier ranking buffer tier 0 topic-field tier 1 tag-only sorted -k1,1n -k2,2r for last_verified-desc tiebreak; PROJECT_ROOT env-var fixture isolation reused from P01,bash 3.2-safe JSON emission via comma-before-element pattern (subshell-loop limitation workaround); awk-based JSON quote-escape for backslash and double-quote in title/id/status; format-aware empty-result diagnostic via case-on-format with ids fallback star arm; side-effect-free invariant verified by md5 snapshot diff across 7-invocation battery (matched/unmatched/state-filtered/format-toggled); jq optional with degraded-mode soft PASS per MEM001,dispatch early-exit-passthrough pattern: insert minimal POSIX bracket-shape guard before main argument loop,exec bash to delegate fully (preserves exit/stdout/stderr byte-equivalent) and bypasses dispatch-usage JSONL emitter for read-only knowledge queries (FR-8/CON-1); CON-4 surface preservation via unreachable-block construction (when first arg is not --query,inserted block is dead code so existing 13 surface flags + 4 backend paths byte-equivalent by inspection,not asserted as Tier-1 verifier),tempdir+trap fixture isolation per MEM002; PROJECT_ROOT env override matches T01-T03 verifier convention; pre/post md5 hash snapshot proves read-only invariant; case-statement-based candidate-leak check (Bash 3.2 safe,no compound chains); inline pass()/fail() with parallel scalars (no declare -A); md5/md5sum portability fallback for macOS+linux"
drill_down_paths:
  - "[.orchestrator/milestones/M020/phases/P02/tasks/T01-query-core-SUMMARY.md](../../../../../milestones/M020/phases/P02/tasks/T01-query-core-SUMMARY.md), [.orchestrator/milestones/M020/phases/P02/tasks/T02-query-json-side-effect-SUMMARY.md](../../../../../milestones/M020/phases/P02/tasks/T02-query-json-side-effect-SUMMARY.md), [.orchestrator/milestones/M020/phases/P02/tasks/T03-dispatch-wrapper-SUMMARY.md](../../../../../milestones/M020/phases/P02/tasks/T03-dispatch-wrapper-SUMMARY.md), [.orchestrator/milestones/M020/phases/P02/tasks/T04-integration-test-SUMMARY.md](../../../../../milestones/M020/phases/P02/tasks/T04-integration-test-SUMMARY.md)"
duration: "70m"
verification_result: "pass"
completed_at: "2026-04-25T12:35:41Z"
observability_surfaces:
  - "none"
---

## Phase Outcome

P02 delivered the deterministic, read-only query surface for the
graduated knowledge layer (US-1, FR-2). Four tasks executed
sequentially with each task summary written via the structured
helper:

- **T01 (query-core):** `scripts/knowledge/query.sh` implementing
  FR-2 sub-clauses a-e plus the `--format ids` half of (f) — argument
  parser, default `--state graduated` filter, case-insensitive topic
  + tags[] match, two-tier ranking (topic-field above tag-only) with
  `last_verified` desc tiebreaks, and the ids emitter. Five per-task
  verifiers under `scripts/verify/` cover each FR-2 sub-clause.
- **T02 (query-json-side-effect):** `--format json` single-document
  emitter with `matches: [{id,title,status,rank}]`, no-match
  diagnostic for both formats per US-1 acceptance scenario 3, and
  the FR-8/CON-1/SC-7 side-effect-free invariant verifier (md5+mtime
  snapshot diff across 7-invocation battery — strictly stronger than
  a `git status` diff because it catches in-place rewrites that
  round-trip byte-for-byte).
- **T03 (dispatch-wrapper):** `dispatch-interface.sh --query`
  early-exit passthrough (12-line guard before the main argument
  loop, `exec bash`-delegating to query.sh) closing OQ-4 from the
  P02 planning payload. Byte-equivalent stdout/stderr/exit-code
  asserted by `m020-p02-dispatch-query-wrapper.sh` (5 cases: ids
  byte-equiv, json byte-equiv, exit-code propagation on invalid
  `--state`, knowledge-tree non-perturbation).
- **T04 (integration-test):** `tests/test-knowledge-query.sh` —
  233-line MEM002-conformant end-to-end test covering SC-1
  (graduated-only filter + ranking + JSON shape) and SC-7 (read-only
  invariant via pre/post hash snapshot) for both direct query.sh
  and dispatch-interface.sh `--query` entry points; jq-absent
  degraded-mode soft skip per MEM001.

## Verification

10/10 phase-level truths PASS. 32/32 artifact assertions PASS. 3/3
key-link assertions PASS. All four per-task verifications PASS.
Phase rollup `bash scripts/verify/check-must-haves.sh
.orchestrator/milestones/M020/phases/P02` exits 0.

`tests/test-knowledge-query.sh` exits 0 with 9/9 cases (3 ids-format,
3 json-format, 1 dispatch-wrapper byte-equivalence, 2 read-only
hash-snapshot).

## Key Patterns

- **Lazy topic-keyword index:** no persistent cache; walks
  `knowledge/` every query per Constitution Principle VI (state on
  disk is truth). Acceptable for small N (<200 entries today).
- **Bash 3.2-safe JSON emission:** comma-before-element pattern
  (subshell-loop limitation workaround); awk-based quote-escape for
  backslash and double-quote in title/id/status fields.
- **Format-aware empty-result diagnostic:** case-on-format with ids
  fallback `*` arm — single source of empty-result truth across
  formats.
- **Dispatch early-exit-passthrough:** minimal POSIX bracket-shape
  guard before main argument loop, `exec bash` delegating fully.
  Preserves byte-equivalent stdout/stderr/exit and bypasses the
  dispatch-usage JSONL emitter for read-only knowledge queries
  (FR-8/CON-1).
- **CON-4 surface preservation via unreachable-block construction:**
  when first arg is not `--query`, the inserted block is dead code,
  so the existing 13 surface flags + 4 backend paths remain
  byte-equivalent by inspection.
- **Verifier conventions reinforced from P01:** PROJECT_ROOT env
  fixture isolation, tempdir+trap cleanup (MEM002), pre/post md5
  hash snapshot for read-only proofs, inline `pass()`/`fail()` with
  parallel scalars (no `declare -A`), md5/md5sum portability
  fallback for macOS+linux.

## Carry-Forward Lessons

1. **Plan must-haves with literal-string sentinels can drift from
   implementation reality.** The phase plan asserted the
   side-effect-free verifier "contains 'git status'", but the
   implementation shipped a strictly stronger md5/mtime snapshot
   diff (catches in-place byte-equivalent rewrites that
   `git status` misses). Fixed by adding a documentation comment
   referencing `git status` while keeping the stronger check.
   Future plans should either (a) match implementation reality, or
   (b) phrase the must-have semantically (e.g. "verifier asserts
   knowledge tree unchanged across N invocations").

2. **`write-summary.sh` body strings reject brace expansion with
   quote chars.** Two task agents hit AP-007/AP-008 rejections from
   `pre-bash-shape-guard` when their `--patterns_established` body
   contained `{a,b}` or heredoc-with-expansion shapes. Workaround:
   stage the multiline invocation in a tmpdir script and dispatch
   through `scripts/util/run-probe.sh` (the documented allowed
   shape).

3. **Surface-preservation via dead-code construction is acceptable
   for thin pre-loop guards** but should be verified by inspection,
   not by Tier-1 verifier — the absence of compile-time
   reachability analysis in bash makes "surface flag count
   unchanged" a manual check rather than a mechanical one.

## Affects Downstream

- **P06 (preferences layer):** consumes `query.sh` JSON output
  shape; treat the schema as a public contract.
- **`orchestrator:status` review queue (P04):** can reuse the
  default-state filter pattern.
- **Dispatch-interface convention:** future read-only subcommands
  should follow the `--query` early-exit-passthrough pattern to
  avoid dispatch-usage JSONL pollution.


### P05 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P05"
parent: "M020"
milestone: "M020"
provides:
  - "scripts/knowledge/lib/cluster.sh sourceable helper exposing cluster_compute <root> <threshold> (walks <root>/**/MEM*.md,filters to status: candidate,computes pairwise Jaccard via subprocess invocation of jaccard.sh,builds union-find similarity graph with edges where similarity >= threshold,emits TAB-separated <cluster-id>\t<member-id> lines on stdout sorted by cluster-id then member-id; singletons form one-member clusters; pure read,no knowledge/** or .orchestrator/** mutations) and cluster_id_for <sorted-csv> (deterministic AD-3 C<8-hex-of-sha1(sorted-csv)>); three contract verifiers covering function exposure + AD-3 ID shape + determinism + empty + singleton + 10-entry singleton-coverage,scripts/knowledge/lib/jaccard.sh::_jaccard_extract_tokens extended in place with relates_to[] + source_unit frontmatter reads + body window widened from first-paragraph-50 to full-body-200; [.orchestrator/milestones/M020/phases/P05/jaccard-validation-report.md](../../../../../milestones/M020/phases/P05/jaccard-validation-report.md) regenerated against the live tree under CON-5 v2 with H1 updated to M020/P05 and an appended P05 Vector Extension Notes section documenting v1->v2 deltas; scripts/verify/m020-p05-feature-vector-extension.sh contract verifier (six checks: lib mentions relates_to + source_unit,head -200 literal present,no printed=1 v1 sentinel,P05 report mentions relates_to + source_unit + M020/P05 token),scripts/knowledge/consolidate-artifacts.sh extended in place with --cluster short-circuit (FR-5),sources lib/cluster.sh + lib/decision-history.sh + lib/frontmatter.sh,emits cluster_id=C<8-hex> + indent member= block per cluster,advisory conflict: divergent-decision-history line on mixed-history or distinct-rationale-hash clusters,one consolidate_cluster JSONL record per cluster (cluster_id+member_count+member_ids+threshold_used+conflict_flag+milestone_id) via dh_emit_jsonl; four verifier scripts under scripts/verify/ (m020-p05-consolidate-cluster-emit/conflict-diagnostic/jsonl-emit/legacy-shape-preserved) all green; legacy two-positional invocation shape preserved byte-equivalent in observable behavior (CON-4),tests/test-jaccard-clustering.sh — SC-4 end-to-end integration test exercising the P05 clustering loop through consolidate-artifacts.sh --cluster across three scenarios: (1) ten-entry fixture (4 near-duplicates + 6 vocabulary-disjoint singletons) at threshold 0.1 yielding 7 cluster IDs covering 10 members exactly once with all IDs matching AD-3 C<8-hex>; (2) conflict-diagnostic surface on mixed decision_history fixtures emitting `conflict: cluster=<id> reason=divergent-decision-history` plus JSONL conflict_flag=1; (3) round-trip cluster ID handoff to graduate.sh --cluster <id> with canonical=>graduated,siblings=>archived back-references,and JSONL knowledge_graduate + N-1 knowledge_archive records. 16 PASS / 0 FAIL. Bash 3.2 + MEM002 pass()/fail() conventions. Tempdir + PROJECT_ROOT + ORCH_ROOT env-override fixture isolation per CON-1 / FR-8 — live knowledge/** and .orchestrator/execution-log.jsonl never touched."
requires:
  - "P01,P03"
affects:
  - "P06"
key_files:
  - "scripts/knowledge/lib/cluster.sh,scripts/verify/m020-p05-cluster-helper-contract.sh,scripts/verify/m020-p05-cluster-determinism.sh,scripts/verify/m020-p05-cluster-singleton-coverage.sh,scripts/knowledge/lib/jaccard.sh,[.orchestrator/milestones/M020/phases/P05/jaccard-validation-report.md](../../../../../milestones/M020/phases/P05/jaccard-validation-report.md),scripts/verify/m020-p05-feature-vector-extension.sh,scripts/knowledge/consolidate-artifacts.sh,scripts/verify/m020-p05-consolidate-cluster-emit.sh,scripts/verify/m020-p05-consolidate-conflict-diagnostic.sh,scripts/verify/m020-p05-consolidate-jsonl-emit.sh,scripts/verify/m020-p05-consolidate-legacy-shape-preserved.sh,tests/test-jaccard-clustering.sh"
key_decisions:
  - "none-new,AD-3,FR-5,FR-7,FR-8,CON-1,CON-4,THREAT-006"
patterns_established:
  - "cluster.sh invokes jaccard.sh as subprocess (bash <jaccard.sh> pairwise_jaccard a b) NOT as sourced function -- jaccard.sh's file-scope set -euo pipefail + dollar-zero-based SCRIPT_DIR + bottom-of-file case dispatch makes sourcing it from another helper hostile (missing subcommand triggers exit 1 in host shell; dollar-zero resolves to bash not the script when sourced via bash -c). Subprocess invocation is AD-19-compatible since cluster.sh internals are not Bash-tool-call-shape gated; awk-pass-with-scratch-file pattern for cluster grouping (subshell-locality of bash while loops would lose current_members at exit; awk's associative arrays are bash-3.2-constraint-exempt because the constraint applies to bash code only); cluster_id_for as pure deterministic content-hash decouples ID generation from the union-find result so the same sorted-CSV always yields the same C<8-hex>; bash 3.2 union-find via parallel newline-joined parent_arr scalars with awk-indexed get/set helpers (path compression on find); inline awk-based status reader instead of sourcing fm_read_status -- keeps the candidate-filter contract visible to verifier readers in one place and dodges nested-source quirks; reference-implementation drift caught and corrected at execution time (payload reference impl sourced jaccard.sh which fails for the reasons above; T01 substituted subprocess invocation while preserving the documented external contract),evidence-driven vector extension (P01 validate-subcommand recommended widening; P05/T02 implemented exactly the three sources P01 named -- relates_to[] + source_unit + body cap 200 -- nothing more); P01-deliverable byte-preservation via capture-validate-restore (cp P01 report to /tmp before validate; validate rewrites the canonical P01 path; copy v2-derived report to P05 path; /bin/cp restores P01 because cp is aliased to cp -i); tokenizer-stage cap as body-window bound (body block awk no longer terminates at first blank line; 200-token head cap prevents long bodies from saturating the vector); editing only _jaccard_extract_tokens preserves pairwise_jaccard's callable contract (same arity + similarity=N.NNNN stdout shape) so P01 contract verifier stays green without modification,short-circuit-before-legacy-validation in-place extension (guard new flag at entry-point top + source helpers locally + exit 0 before legacy parser); subshell scope for pipefail-hostile pipelines (grep -v on empty input + find | head SIGPIPE wrapped in set +o pipefail; set +e capture); conflict-as-advisory (stdout conflict: line + JSONL conflict_flag=1 but no non-zero exit -- mutation gates live in graduate.sh per THREAT-006); awk associative grouping for bash-3.2 streams (flat <key>\t<value> -> one-summary-line-per-key); decision-history awk reader inlined for list-typed YAML (fm_field is scalar-only so per-record rationale_hash extraction uses inline awk state machine); read-only enforcement (FR-8/CON-1) via tempdir+PROJECT_ROOT+ORCH_ROOT verifier isolation -- live knowledge/ + execution-log.jsonl never touched,Distinct-vocabulary fixture pattern — when a clustering integration test relies on should-be-singletons,boilerplate words (distinct,fixture,body,unique,for) must be removed from per-entry bodies; otherwise v2 feature-vector token overlap on common scaffolding pushes pairwise similarity above the threshold and the entries co-cluster spuriously. Each singleton entry must use a wholly disjoint word list (zero token intersection with siblings) for the test to satisfy the SC-4 7-cluster contract. Documented for downstream verifier authors. Test-internal heredocs + pipes + process-substitutions remain AD-19 safe because the harness shape-guard inspects directly-invoked Bash tool-call shapes,not script internals (P03/T04 carry-forward)."
drill_down_paths:
  - "[.orchestrator/milestones/M020/phases/P05/tasks/T01-cluster-helper-SUMMARY.md](../../../../../milestones/M020/phases/P05/tasks/T01-cluster-helper-SUMMARY.md), [.orchestrator/milestones/M020/phases/P05/tasks/T02-feature-vector-extension-SUMMARY.md](../../../../../milestones/M020/phases/P05/tasks/T02-feature-vector-extension-SUMMARY.md), [.orchestrator/milestones/M020/phases/P05/tasks/T03-consolidate-cluster-extension-SUMMARY.md](../../../../../milestones/M020/phases/P05/tasks/T03-consolidate-cluster-extension-SUMMARY.md), [.orchestrator/milestones/M020/phases/P05/tasks/T04-integration-test-SUMMARY.md](../../../../../milestones/M020/phases/P05/tasks/T04-integration-test-SUMMARY.md)"
duration: "120m"
verification_result: "pass"
completed_at: "2026-04-25T15:29:10Z"
observability_surfaces:
  - "consolidate_cluster"
---

P05 delivers FR-5 / SC-4 — Jaccard clustering inside `orchestrator:consolidate`. The phase landed across four tasks executed in dependency order T01 ⊥ T02 → T03 → T04.

**T01 (cluster-helper)** — `scripts/knowledge/lib/cluster.sh` exposes two functions: `cluster_compute <root> <threshold>` walks `<root>/**/MEM*.md`, filters to `status: candidate`, computes pairwise Jaccard via subprocess invocation of `jaccard.sh`, runs union-find on the similarity graph, and emits `<cluster-id>\t<member-id>` lines (sorted, singletons preserved). `cluster_id_for <sorted-csv>` returns a deterministic AD-3 `C<8-hex-of-sha1>`. Three contract verifiers cover function exposure, ID determinism, and 10-entry singleton coverage. Caught and corrected a reference-implementation drift: the payload's `. jaccard.sh` would have killed the host shell because of jaccard.sh's file-scope `set -euo pipefail` + bottom-of-file empty-subcommand exit; substituted subprocess invocation instead.

**T02 (feature-vector-extension)** — `scripts/knowledge/lib/jaccard.sh::_jaccard_extract_tokens` extended in place per the P01 validation-report recommendation: now reads `relates_to[]` + `source_unit` from frontmatter and widens the body window from first-paragraph-50 to full-body-200 tokens. Regenerated the validation report against the live tree under CON-5 v2 at [`.orchestrator/milestones/M020/phases/P05/jaccard-validation-report.md`](../../../../../milestones/M020/phases/P05/jaccard-validation-report.md); preserved the P01 deliverable byte-equivalent (CON-4) via capture-validate-restore. One contract verifier covers the six-checks (lib mentions, head -200, no `printed=1` v1 sentinel, P05 report metadata).

**T03 (consolidate-cluster-extension)** — `scripts/knowledge/consolidate-artifacts.sh` extended in place with a `--cluster` short-circuit at entry-point top, sources `lib/cluster.sh` + `lib/decision-history.sh` + `lib/frontmatter.sh`, emits `cluster_id=C<8-hex>` + indented `member=` blocks, surfaces an advisory `conflict: cluster=<id> reason=divergent-decision-history` line on mixed-history or distinct-rationale-hash clusters (no abort — operator decides at graduate-time per THREAT-006), and appends one `consolidate_cluster` JSONL record per cluster via `dh_emit_jsonl`. Legacy two-positional invocation shape preserved byte-equivalent (CON-4). Four verifier scripts all green (cluster-emit, conflict-diagnostic, jsonl-emit, legacy-shape-preserved).

**T04 (integration-test)** — `tests/test-jaccard-clustering.sh` exercises the SC-4 contract end-to-end across three scenarios: ten-entry fixture (4 near-duplicates + 6 vocabulary-disjoint singletons → 7 cluster IDs, 10 members, all AD-3 `C<8-hex>`), conflict-diagnostic surface (mixed `decision_history` → `conflict_flag=1` in JSONL), and round-trip cluster-ID handoff to `graduate.sh --cluster <id>` (canonical=>graduated, siblings=>archived back-references). 16 PASS / 0 FAIL. Tempdir + `PROJECT_ROOT` + `ORCH_ROOT` env-override fixture isolation per CON-1 / FR-8 — live `knowledge/**` and `.orchestrator/execution-log.jsonl` never touched.

**Verification result.** All task verifiers green; external-mods PASS; roadmap-sync OK. Patterns established: subprocess invocation of jaccard.sh from helpers (avoids host-shell death), capture-validate-restore for byte-equivalent preservation of upstream-phase deliverables, short-circuit-before-legacy-validation as the in-place extension idiom, conflict-as-advisory (stdout + JSONL flag, no abort — mutation gates live downstream), distinct-vocabulary-fixture rule for clustering integration tests (boilerplate scaffolding words push singleton pairs above threshold). Cumulatively these patterns make the cluster-extension layer auditable and reversible without disturbing the existing two-positional consolidate contract.

**Affects.** P06 will consume the consolidate-cluster output and the `consolidate_cluster` JSONL surface. No upstream phase invalidation — P01's contract verifier remains green under v2 vector because only the tokenizer stage was touched, not `pairwise_jaccard`'s callable surface.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P06"
milestone: "M020"
name: "Preferences helper (lib/preferences.sh)"
depends_on: []
---

## Prerequisites

- M020-CONTEXT.md AD-5: preferences are flat key-value scalar YAML; parsing strategy is grep+sed-based shell helper, NOT a full YAML parser. No `yq` dependency.
- M020-CONTEXT.md DC-8 THREAT-007 disposition: per-key resolution. Each key resolves INDEPENDENTLY with project>user>built-in-default precedence; partial overlap (project declares key A, user declares key B) is NOT a conflict — each key picks its winning source on its own.
- spec 025 FR-6: preferences live at `~/.orchestrator/preferences.yml` (user) and `.orchestrator/preferences.yml` (project). Project wins over user where both declare the same key.
- spec 025 acceptance scenario US-5/3 + Edge Case "Preferences file declares a threshold outside the valid range": malformed values fall back to default with a stderr diagnostic; the operator's preferences file is never rewritten.
- M020-CONTEXT.md DC-5 (Jaccard threshold default 0.7), OQ-1 (staleness threshold default 14 days), OQ-2 (operator identity fallback `unknown@local`).
- M020 cross-cutting concern (FR-8 / CON-1, "Read-only-during-dispatch invariant"): preferences.sh is a pure read helper; it MUST NOT mutate any file. All output flows to stdout; diagnostics flow to stderr.
- Bash 3.2 compatibility (MEM001): no `declare -A`, no associative arrays. Parallel scalars or per-key case statements only.
- AD-19 (`commands/plan-phase.md` "Truth Check command shape"): every verifier script's body may use any internal shell construct; AD-19 governs the SHAPE of the `bash <script>` invocations the orchestrator's outer Bash tool issues, not the internals of those scripts.

## Description

Create a NEW pure-function helper at `scripts/knowledge/lib/preferences.sh` that implements FR-6 / US-5 preference resolution. The helper is sourceable (double-source-guarded per the P03/P05 convention) and exposes a single callable surface:

**`pref_resolve <key>`** — echoes the effective scalar value for `<key>` on stdout. Resolution algorithm:

1. If `<key>` is not in the closed-enum vocabulary {`default_state_filter`, `similarity_threshold`, `staleness_threshold`, `preferred_cluster_size`, `operator_identifier`}, emit `FAIL: pref_resolve: unknown key '<key>'` on stderr and return non-zero exit. No stdout output.
2. Compute the project preferences path as `${PROJECT_ROOT:-<derived-project-root>}/.orchestrator/preferences.yml`. If the file exists AND contains a syntactically-clean `<key>: <value>` line AND `<value>` is valid for the key's type, echo `<value>` and return 0.
3. Else compute the user preferences path as `${HOME}/.orchestrator/preferences.yml`. If the file exists AND contains a syntactically-clean `<key>: <value>` line AND `<value>` is valid for the key's type, echo `<value>` and return 0.
4. Else echo the built-in default for `<key>` and return 0.

When step 2 or step 3 finds a `<key>: <value>` line whose value is INVALID (non-numeric for numeric keys, out-of-range for bounded keys, value outside the closed enum for `default_state_filter`), the helper:

- Skips that source (does NOT use the malformed value).
- Emits a single-line stderr diagnostic of the form `WARN: pref_resolve: malformed value for '<key>' in '<file>': '<raw-value>' — falling back to <next-source-or-default>`.
- Continues to the next source per the precedence chain.
- NEVER mutates the file (operator-owned file).

The five keys and their type/range constraints + built-in defaults:

| Key | Type | Range | Built-in default |
|-----|------|-------|------------------|
| `default_state_filter` | string | closed enum {`candidate`, `graduated`, `archived`} | `graduated` |
| `similarity_threshold` | float | `0.0 <= x <= 1.0` | `0.7` |
| `staleness_threshold` | int | `1 <= x <= 365` | `14` (days) |
| `preferred_cluster_size` | int | `1 <= x <= 50` | `8` |
| `operator_identifier` | string | non-empty, no `\n` or surrounding whitespace | `unknown@local` |

Path resolution honors environment-variable overrides for fixture isolation (matches the P01–P05 verifier convention):

- `PROJECT_ROOT` env var (when exported by a verifier) overrides the script-derived project root for the project-preferences path.
- `HOME` env var (standard POSIX) controls the user-preferences path.

`preferences.sh` is sourced by `scripts/knowledge/query.sh` (T02 of this phase) and from inside the `--cluster` short-circuit of `scripts/knowledge/consolidate-artifacts.sh` (T03 of this phase). It is NOT a callable surface from dispatch (FR-8 / CON-1 — preferences are operator-owned configuration, but `pref_resolve` itself is read-only and dispatch-safe through the consumer scripts).

## Steps

### Step 1: Create `scripts/knowledge/lib/preferences.sh`

Path: `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/knowledge/lib/preferences.sh`

Reference implementation:

```bash
#!/usr/bin/env bash
# scripts/knowledge/lib/preferences.sh — FR-6 / US-5 preferences resolution helper.
#
# Provides:
#   pref_resolve <key>
#       Echoes the effective scalar value of <key> on stdout, applying
#       project>user>built-in-default precedence per-key (THREAT-007).
#       Closed-enum keys: default_state_filter, similarity_threshold,
#       staleness_threshold, preferred_cluster_size, operator_identifier.
#       Built-in defaults: graduated, 0.7, 14, 8, unknown@local.
#       Malformed values fall back with a single-line stderr diagnostic;
#       the preferences file is NEVER mutated.
#       Path resolution honors PROJECT_ROOT and HOME env vars for fixture
#       isolation (P01/P02/P05 verifier convention).
#
# Pure read helper — no writes anywhere. AD-19 single-script-invocation safe.
# Bash 3.2 compatible (MEM001). MEM001 prefixed-output conventions.

# --- Double-source guard ---
[ -n "${_PREFERENCES_HELPER_SOURCED:-}" ] && return 0
_PREFERENCES_HELPER_SOURCED=1

# --- Built-in defaults (single source of truth) ---
_PREF_DEFAULT_default_state_filter="graduated"
_PREF_DEFAULT_similarity_threshold="0.7"
_PREF_DEFAULT_staleness_threshold="14"
_PREF_DEFAULT_preferred_cluster_size="8"
_PREF_DEFAULT_operator_identifier="unknown@local"

# --- Closed-enum key vocabulary ---
_pref_is_known_key() {
  case "$1" in
    default_state_filter|similarity_threshold|staleness_threshold|preferred_cluster_size|operator_identifier)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# --- Per-key validators. Return 0 iff $2 is a valid value for key $1. ---
_pref_validate_value() {
  local key="$1"
  local val="$2"
  case "$key" in
    default_state_filter)
      case "$val" in
        candidate|graduated|archived) return 0 ;;
        *) return 1 ;;
      esac
      ;;
    similarity_threshold)
      # Float in [0.0, 1.0]. Accept N, N.NN, .NN forms.
      printf '%s\n' "$val" | awk '
        /^[0-9]+(\.[0-9]+)?$|^\.[0-9]+$/ {
          v = $0 + 0.0
          if (v >= 0.0 && v <= 1.0) { exit 0 } else { exit 1 }
        }
        { exit 1 }
      '
      return $?
      ;;
    staleness_threshold)
      # Int in [1, 365].
      case "$val" in
        ''|*[!0-9]*) return 1 ;;
      esac
      [ "$val" -ge 1 ] && [ "$val" -le 365 ]
      ;;
    preferred_cluster_size)
      # Int in [1, 50].
      case "$val" in
        ''|*[!0-9]*) return 1 ;;
      esac
      [ "$val" -ge 1 ] && [ "$val" -le 50 ]
      ;;
    operator_identifier)
      # Non-empty, no embedded newline or surrounding whitespace.
      [ -n "$val" ] || return 1
      case "$val" in
        ' '*|*' '|*$'\n'*) return 1 ;;
      esac
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# --- Read a scalar key from a YAML file (grep+sed; AD-5 strategy). ---
# Echoes the raw scalar on stdout if found; empty stdout + return 1 if absent.
# Strips surrounding whitespace and surrounding single/double quotes.
_pref_read_scalar() {
  local file="$1"
  local key="$2"
  [ -f "$file" ] || return 1
  local raw
  raw="$(grep -E "^${key}:[[:space:]]" "$file" 2>/dev/null | head -1 \
    | sed -E "s/^${key}:[[:space:]]*//; s/[[:space:]]*\$//; s/^['\"]//; s/['\"]\$//")"
  [ -n "$raw" ] || return 1
  printf '%s\n' "$raw"
  return 0
}

# --- Resolve the project preferences path (PROJECT_ROOT-aware). ---
_pref_project_path() {
  local root
  if [ -n "${PROJECT_ROOT:-}" ]; then
    root="$PROJECT_ROOT"
  else
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
  fi
  printf '%s/.orchestrator/preferences.yml\n' "$root"
}

# --- Resolve the user preferences path (HOME-aware). ---
_pref_user_path() {
  printf '%s/.orchestrator/preferences.yml\n' "${HOME:-/tmp}"
}

# --- Try one source: read scalar, validate, echo + return 0 OR diagnose + return 1. ---
# Args: <key> <file> <next-source-label-for-diagnostic>
_pref_try_source() {
  local key="$1"
  local file="$2"
  local next="$3"
  local raw
  raw="$(_pref_read_scalar "$file" "$key")" || return 1
  if _pref_validate_value "$key" "$raw"; then
    printf '%s\n' "$raw"
    return 0
  fi
  printf "WARN: pref_resolve: malformed value for '%s' in '%s': '%s' — falling back to %s\n" \
    "$key" "$file" "$raw" "$next" >&2
  return 1
}

# --- Public: pref_resolve <key>. ---
pref_resolve() {
  local key="${1:-}"
  if [ -z "$key" ]; then
    echo "FAIL: pref_resolve: missing key argument" >&2
    return 1
  fi
  if ! _pref_is_known_key "$key"; then
    echo "FAIL: pref_resolve: unknown key '$key'" >&2
    return 1
  fi

  local proj_file user_file
  proj_file="$(_pref_project_path)"
  user_file="$(_pref_user_path)"

  # Step 1: project file (highest precedence).
  _pref_try_source "$key" "$proj_file" "user-or-default" && return 0

  # Step 2: user file.
  _pref_try_source "$key" "$user_file" "default" && return 0

  # Step 3: built-in default.
  local default_var="_PREF_DEFAULT_${key}"
  printf '%s\n' "${!default_var}"
  return 0
}
```

### Step 2: Create `scripts/verify/m020-p06-preferences-helper-contract.sh`

Verifier asserts:

- `scripts/knowledge/lib/preferences.sh` exists and is sourceable.
- After sourcing, `pref_resolve` is a defined function (`type -t pref_resolve` returns `function`).
- For each of the five keys, calling `pref_resolve <key>` against an empty fixture environment (tempdir `HOME` + tempdir `PROJECT_ROOT` with no preferences files present) returns the documented built-in default (`graduated`, `0.7`, `14`, `8`, `unknown@local`) on stdout with exit 0.

Use the `pass()`/`fail()` parallel-scalar pattern from MEM002. Tempdir + trap cleanup. Set `HOME` and `PROJECT_ROOT` to fresh tempdirs with no preferences files inside.

### Step 3: Create `scripts/verify/m020-p06-preferences-precedence.sh`

Verifier asserts project>user>default precedence per-key:

- Set `HOME=<user-tempdir>` and `PROJECT_ROOT=<project-tempdir>`.
- Write `<user-tempdir>/.orchestrator/preferences.yml` with `similarity_threshold: 0.8`.
- Write `<project-tempdir>/.orchestrator/preferences.yml` with `similarity_threshold: 0.6`.
- Assert `pref_resolve similarity_threshold` echoes `0.6` (project wins).
- Remove the project file. Assert `pref_resolve similarity_threshold` echoes `0.8` (user wins).
- Remove the user file. Assert `pref_resolve similarity_threshold` echoes `0.7` (default).
- Repeat for `default_state_filter` (project=`candidate`, user=`graduated` → `candidate`; user-only → `graduated`; none → `graduated`).
- Repeat for `staleness_threshold` (project=7, user=21, none → 14).
- Per-key partial-overlap assertion (THREAT-007): write project file with ONLY `similarity_threshold: 0.5` and user file with ONLY `staleness_threshold: 30`. Assert `pref_resolve similarity_threshold` → `0.5` AND `pref_resolve staleness_threshold` → `30` (each key resolves independently).

### Step 4: Create `scripts/verify/m020-p06-preferences-malformed-fallback.sh`

Verifier asserts malformed-value fallback semantics:

- Set `HOME=<user-tempdir>` and `PROJECT_ROOT=<project-tempdir>`.
- Write project file with `similarity_threshold: not-a-number`. Assert `pref_resolve similarity_threshold` echoes `0.7` on stdout, exits 0, AND emits a stderr line matching `^WARN: pref_resolve: malformed value for 'similarity_threshold'`.
- Assert the project file is byte-identical before and after the call (md5 snapshot).
- Write project file with `similarity_threshold: 1.5` (out-of-range). Same assertions.
- Write project file with `default_state_filter: zombie` (outside closed enum). Assert stdout = `graduated`, stderr matches `malformed value for 'default_state_filter'`.
- Write project file with `staleness_threshold: -1`. Assert stdout = `14`, stderr matches the warn pattern.
- Project malformed + user valid: project file `similarity_threshold: not-a-number`, user file `similarity_threshold: 0.9`. Assert stdout = `0.9` (falls through project to user), stderr emits the warn for project only.

### Step 5: Create `scripts/verify/m020-p06-preferences-key-vocabulary.sh`

Verifier asserts unknown-key rejection:

- Set up empty fixture environment.
- Call `pref_resolve some_unknown_key`. Assert: stdout is empty, stderr matches `^FAIL: pref_resolve: unknown key 'some_unknown_key'`, exit code is non-zero.
- Call `pref_resolve` with no arguments. Assert: stdout is empty, stderr matches `missing key argument`, exit code is non-zero.
- For sanity, call `pref_resolve` for each of the five known keys. Assert each call exits 0 (does not regress key-acceptance under the same code path).

## Must-Haves

This task addresses the following P06 must-haves:

- Truth: preferences.sh exists, is sourceable, exposes `pref_resolve <key>` (Check: `m020-p06-preferences-helper-contract.sh`).
- Truth: `pref_resolve` honors project>user>default precedence per-key (Check: `m020-p06-preferences-precedence.sh`).
- Truth: `pref_resolve` falls back on malformed values with stderr diagnostic, no file mutation (Check: `m020-p06-preferences-malformed-fallback.sh`).
- Truth: `pref_resolve` rejects unknown keys (Check: `m020-p06-preferences-key-vocabulary.sh`).
- Artifact: `scripts/knowledge/lib/preferences.sh` (min 100 lines, contains "pref_resolve").
- Artifact: each of the four T01 verifier scripts.

## Verification

```bash
bash scripts/verify/m020-p06-preferences-helper-contract.sh
bash scripts/verify/m020-p06-preferences-precedence.sh
bash scripts/verify/m020-p06-preferences-malformed-fallback.sh
bash scripts/verify/m020-p06-preferences-key-vocabulary.sh
```

Each script must exit 0. AD-19 compliant: each is a single `bash <script>` invocation with no compound chains.

## Inputs

### From Previous Tasks

None — T01 has no upstream P06 dependencies.

### From Disk (Pre-existing)

- `scripts/knowledge/lib/frontmatter.sh` (P01) — not sourced by preferences.sh, but referenced for the double-source-guard convention pattern. Convention: `[ -n "${_<NAME>_SOURCED:-}" ] && return 0; _<NAME>_SOURCED=1`.
- `tests/test-knowledge-query.sh` (P02) — referenced for the tempdir + `HOME` + `PROJECT_ROOT` fixture-isolation pattern that the four T01 verifiers must use verbatim.

## Constraints

- **CON-1 / FR-8 (read-only)**: `pref_resolve` MUST NOT write to any file under any condition. Verifier `m020-p06-preferences-malformed-fallback.sh` enforces this with an md5 snapshot of the preferences file before/after each call.
- **AD-5 (scalar-only YAML)**: parse with `grep` + `sed` only. Do NOT introduce a `yq` dependency or call any external YAML parser. If the M020 schema later requires nested structures, a new D-row authorizes the parser swap; this task is not the place.
- **MEM001 (Bash 3.2)**: no `declare -A`. Use parallel scalars or `case` statements for the per-key vocabulary + validators.
- **AD-19 (single-script-invocation shape)**: each verifier's external test runner invokes it as a single `bash <script>` command. Internal shell constructs (subshells, pipes, etc.) inside the verifier scripts are unrestricted; AD-19 governs the orchestrator's outer Bash tool calls only.
- **MEM002 (test conventions)**: verifiers use the `pass()`/`fail()` parallel-scalar pattern; tempdir + trap cleanup; tempdir-based `HOME` and `PROJECT_ROOT` for fixture isolation (no live `~/.orchestrator/` or repo-root `.orchestrator/` access).
- **CON-4 (surgical precision)**: this task creates new files only — no in-place edits to other M020 files.

## Expected Output

After T01 ships:

```
$ bash scripts/verify/m020-p06-preferences-helper-contract.sh
PASS: lib/preferences.sh exists and is sourceable
PASS: pref_resolve is a defined function after source
PASS: pref_resolve default_state_filter -> graduated (built-in default)
PASS: pref_resolve similarity_threshold -> 0.7 (built-in default)
PASS: pref_resolve staleness_threshold -> 14 (built-in default)
PASS: pref_resolve preferred_cluster_size -> 8 (built-in default)
PASS: pref_resolve operator_identifier -> unknown@local (built-in default)
RESULT: 7/7 PASS
exit 0
```

Similar `RESULT: <N>/<N> PASS` exit-0 output from the other three verifiers.

## State Context

- **Current State**: executing
- **Milestone**: M020
- **Phase**: P06
- **Task**: T01-preferences-helper
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **CON-1 / FR-8 (read-only)**: `pref_resolve` MUST NOT write to any file under any condition. Verifier `m020-p06-preferences-malformed-fallback.sh` enforces this with an md5 snapshot of the preferences file before/after each call.
- **AD-5 (scalar-only YAML)**: parse with `grep` + `sed` only. Do NOT introduce a `yq` dependency or call any external YAML parser. If the M020 schema later requires nested structures, a new D-row authorizes the parser swap; this task is not the place.
- **MEM001 (Bash 3.2)**: no `declare -A`. Use parallel scalars or `case` statements for the per-key vocabulary + validators.
- **AD-19 (single-script-invocation shape)**: each verifier's external test runner invokes it as a single `bash <script>` command. Internal shell constructs (subshells, pipes, etc.) inside the verifier scripts are unrestricted; AD-19 governs the orchestrator's outer Bash tool calls only.
- **MEM002 (test conventions)**: verifiers use the `pass()`/`fail()` parallel-scalar pattern; tempdir + trap cleanup; tempdir-based `HOME` and `PROJECT_ROOT` for fixture isolation (no live `~/.orchestrator/` or repo-root `.orchestrator/` access).
- **CON-4 (surgical precision)**: this task creates new files only — no in-place edits to other M020 files.

### Acceptance Criteria

This task addresses the following P06 must-haves:

- Truth: preferences.sh exists, is sourceable, exposes `pref_resolve <key>` (Check: `m020-p06-preferences-helper-contract.sh`).
- Truth: `pref_resolve` honors project>user>default precedence per-key (Check: `m020-p06-preferences-precedence.sh`).
- Truth: `pref_resolve` falls back on malformed values with stderr diagnostic, no file mutation (Check: `m020-p06-preferences-malformed-fallback.sh`).
- Truth: `pref_resolve` rejects unknown keys (Check: `m020-p06-preferences-key-vocabulary.sh`).
- Artifact: `scripts/knowledge/lib/preferences.sh` (min 100 lines, contains "pref_resolve").
- Artifact: each of the four T01 verifier scripts.

### Files To Touch

- `scripts/knowledge/lib/preferences.sh` (create)
- `scripts/knowledge/query.sh` (modify — source preferences.sh + deferred state-filter resolution)
- `scripts/knowledge/consolidate-artifacts.sh` (modify — source preferences.sh inside `--cluster` arm + emit `effective_threshold=` line + threshold resolution)
- `references/preferences.md` (create)
- `tests/test-preferences-resolution.sh` (create)
- `scripts/verify/m020-p06-preferences-helper-contract.sh` (create)
- `scripts/verify/m020-p06-preferences-precedence.sh` (create)
- `scripts/verify/m020-p06-preferences-malformed-fallback.sh` (create)
- `scripts/verify/m020-p06-preferences-key-vocabulary.sh` (create)
- `scripts/verify/m020-p06-query-state-from-pref.sh` (create)
- `scripts/verify/m020-p06-query-pref-side-effect-free.sh` (create)
- `scripts/verify/m020-p06-consolidate-effective-threshold.sh` (create)
- `scripts/verify/m020-p06-consolidate-cli-precedence.sh` (create)
- `scripts/verify/m020-p06-preferences-doc-content.sh` (create)

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