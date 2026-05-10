---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T02-tier-2-llm-helper-and-unit-close (Phase P03, Milestone M036)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-981 | ~600 | required |
| Upstream Context | 983-1041 | ~5000 | required |
| Task Plan | 1043-1359 | ~3300 | required |
| State Context | 1361-1367 | ~100 | required |
| First-Turn Completeness | 1369-1416 | ~800 | required |
| **Total** | | **~20600** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 737
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
hit_count: 737
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
hit_count: 737
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
hit_count: 737
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
hit_count: 643
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
hit_count: 643
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
hit_count: 643
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
hit_count: 737
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
hit_count: 643
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
hit_count: 643
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
hit_count: 643
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
hit_count: 737
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
hit_count: 737
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
hit_count: 737
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
hit_count: 643
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
hit_count: 643
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
hit_count: 643
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
hit_count: 737
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
hit_count: 643
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
hit_count: 643
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
hit_count: 737
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
hit_count: 737
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
hit_count: 643
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
hit_count: 643
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
hit_count: 643
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
hit_count: 298
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
hit_count: 298
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
hit_count: 298
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
hit_count: 313
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
hit_count: 313
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
hit_count: 303
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

Implement the synchronous Tier 2 leg of `orchestrator:extract` by replacing the P02 `summary_mode: auto` deferred-error seam at

### Demo

```bash

### Must-Haves
## Must-Haves

### Truths

<!-- All Check: lines are bash <single-script-file> per AD-19. Verifiers under tools/verify/ (project-owned, milestone-prefixed slug per the post-M031 contract). -->

- `summary_mode: auto` no longer hard-errors when `tier: 2` — it dispatches Tier 2 LLM extraction + conversus gate.
  - Check: `bash tools/verify/m036-p03-tier-2-deferred-error-removed.sh`
- A Tier 2 extraction whose conversus gate returns PASS writes `.structured.md` next to the Tier 0 chunk and a `<cite_id>.pass.md` verdict file under `.orchestrator/knowledge/reference/_extraction-log/`.
  - Check: `bash tools/verify/m036-p03-tier-2-pass-end-to-end.sh`
- A Tier 2 extraction whose conversus gate returns BLOCK writes `<cite_id>.block.md` under `_extraction-log/` and **does NOT** create the `.structured.md` chunk file.
  - Check: `bash tools/verify/m036-p03-tier-2-block-retention.sh`
- Each Tier 2 invocation appends one well-formed `unit_close` JSONL record to `.orchestrator/execution-log.jsonl` with `task_type=extraction`, non-empty `model`, and non-empty `cost_usd`.
  - Check: `bash tools/verify/m036-p03-unit-close-extraction-shape.sh`
- The M030 routing table at `templates/model-routing.yml` recognises `task_type: extraction` (additive; does not change `mechanical|standard|novel` rows; does not touch `resolution:` model IDs — CON-3 closure preserved).
  - Check: `bash tools/verify/m036-p03-m030-task-type-extraction.sh`
- The conversus preset `tier-2-fidelity.yml` exists at `templates/conversus-presets/tier-2-fidelity.yml`, declares two agents (`extractor-advocate` + `fidelity-advocate`), an arbiter `verdict_contract: PASS|BLOCK`, and a `grounding_file:` reference.
  - Check: `bash tools/verify/m036-p03-conversus-preset-shape.sh`
- The Tier 2 helper lib `scripts/knowledge/lib/extract-tier-2-llm.sh` exposes the pure functions `extract_tier_2_dispatch` (LLM call, mockable via `EXTRACT_TIER_2_DISPATCH`) and `extract_tier_2_emit_unit_close`. The driver sources the helper alongside the existing P02 `extract-tier-0-summary.sh`.
  - Check: `bash tools/verify/m036-p03-driver-tier-2-shape.sh`

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
  - ".orchestrator/milestones/M036/phases/P02/tasks/T01-manifest-contract-and-fixtures-SUMMARY.md, .orchestrator/milestones/M036/phases/P02/tasks/T02-driver-and-preservation-SUMMARY.md, .orchestrator/milestones/M036/phases/P02/tasks/T03-summary-and-command-doc-SUMMARY.md, .orchestrator/milestones/M036/phases/P02/tasks/T04-acceptance-harness-and-aggregator-SUMMARY.md"
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

- **P03** (Tier 2 LLM extraction + M030 routing + conversus fidelity gate) consumes P02's `extract_tier_1_via_registry` helper and the `summary_mode: auto` deferred-error seam: P03 implements the auto branch by calling M030 routing + conversus gate, replacing the current "P03 not implemented" hard-error with a real Tier 2 extraction path. P03's structured-output writer lands beside the existing chunk under `<cite_id>.structured.md` per the spec.
- **P04** (ingest layer) consumes the extraction outputs + the chunk frontmatter shape established here (manifest entry + content_hash + tier label + binary-preservation pointer) as input to the chunk classifier.
- **P06** (idempotent re-extract + re-ingest + supersede chain) builds on the content-hash idempotency gate established in P02's driver. The `version: <vN>` optional field in the manifest contract is the seam P06 will leverage to author supersede chains; P02 declares the field but doesn't yet implement chain-following.
- **Pure-lib factoring (MEM004)**: the `scripts/knowledge/lib/extract-*` helpers carry pure-function discipline (args-in / stdout+exit-out / no top-level I/O) into M036's surface. P03+ helper libs should follow the same shape.
- **Registry-driven Tier 1 dispatch**: the driver holds zero per-format logic — new formats land entirely as new `registry.tsv` rows + adapters with no driver edits. P03's Tier 2 path follows the same delegation pattern (Tier 2 model registration in M030's task-type ledger, no driver-side model knowledge).

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M036"
name: "Tier 2 LLM dispatch helper + unit_close emitter (mockable; no live LLM in CI)"
depends_on: ["T01"]
---

## Prerequisites

- T01 closed: `templates/conversus-presets/tier-2-fidelity.yml` exists, `templates/model-routing.yml` carries `task_type.extraction: smart` for claude-code, `tests/fixtures/m036-p03-tier-2/extract-manifest.yaml` + `sample.md` exist.
- P02 driver `scripts/knowledge/extract-reference.sh` exists and sources `scripts/knowledge/lib/extract-tier-0-summary.sh`.
- `scripts/dispatch/select-model.sh` exists (M030 P01).

Verified at plan-authoring time: all five files present.

## Description

Author a pure helper lib `scripts/knowledge/lib/extract-tier-2-llm.sh` (MEM004 — args-in / stdout+exit-out / no top-level I/O) that:

1. Performs the Tier 2 LLM extraction call (live mode — uses `select-model.sh` for `task_type=extraction` resolution; **NOT exercised in CI per CON-3**) OR routes to a deterministic fixture when `EXTRACT_TIER_2_DISPATCH=stub:pass|stub:block`.
2. Emits an M030-shape `unit_close` JSONL record with `task_type=extraction`, `model`, `tokens_in`, `tokens_out`, `cost_usd`, `quality_score` to `${ORCHESTRATOR_ROOT}/.orchestrator/execution-log.jsonl`.

Three verifiers under `tools/verify/m036-p03-*` (driver shape, unit_close shape, llm-helper shape).

## Steps

### Step 1 — Author `scripts/knowledge/lib/extract-tier-2-llm.sh`

Create `scripts/knowledge/lib/extract-tier-2-llm.sh`:

```bash
#!/usr/bin/env bash
# scripts/knowledge/lib/extract-tier-2-llm.sh -- M036 P03 T02 helper.
# Pure functions for Tier 2 LLM extraction dispatch + unit_close emission.
# Sourced by scripts/knowledge/extract-reference.sh. No top-level I/O
# (MEM004 pure-lib pattern). Bash 3.2 / POSIX-sh per CON-2.
#
# Mock contract (CON-3: no live LLM in CI):
#   EXTRACT_TIER_2_DISPATCH=live          (default) — call [M030](../../../../../milestones/M030/index.md) + LLM
#   EXTRACT_TIER_2_DISPATCH=stub:pass     — copy canned-structured.md to <out>
#   EXTRACT_TIER_2_DISPATCH=stub:block    — copy canned-structured-low-fidelity.md
#
# In stub modes the helper emits stub model/token/cost values to stderr
# in NAME=VALUE form (one pair per line) so the driver can parse them
# back into unit_close fields.

# extract_tier_2_dispatch <input-path> <out-path> <category> <cite_id>
#   Returns 0 on success, 1 on error.
#   Always emits to stderr (one pair per line, NAME=VALUE form):
#     MODEL=<model-id>
#     TOKENS_IN=<n>
#     TOKENS_OUT=<n>
#     COST_USD=<float>
#     QUALITY_SCORE=<float>
extract_tier_2_dispatch() {
  local input="$1"
  local out="$2"
  local category="$3"
  local cite_id="$4"
  local mode="${EXTRACT_TIER_2_DISPATCH:-live}"
  local fx_dir="${ORCHESTRATOR_ROOT:-$(pwd)}/tests/fixtures/m036-p03-tier-2"
  case "$mode" in
    stub:pass)
      if [ ! -f "$fx_dir/canned-structured.md" ]; then
        echo "extract_tier_2_dispatch: canned-structured.md missing at $fx_dir" >&2
        return 1
      fi
      cp "$fx_dir/canned-structured.md" "$out"
      printf 'MODEL=claude-haiku-4-5\nTOKENS_IN=512\nTOKENS_OUT=2048\nCOST_USD=0.0123\nQUALITY_SCORE=0.92\n' >&2
      return 0
      ;;
    stub:block)
      if [ ! -f "$fx_dir/canned-structured-low-fidelity.md" ]; then
        echo "extract_tier_2_dispatch: canned-structured-low-fidelity.md missing at $fx_dir" >&2
        return 1
      fi
      cp "$fx_dir/canned-structured-low-fidelity.md" "$out"
      printf 'MODEL=claude-haiku-4-5\nTOKENS_IN=512\nTOKENS_OUT=1800\nCOST_USD=0.0119\nQUALITY_SCORE=0.61\n' >&2
      return 0
      ;;
    live)
      # Live path: route through M030, dispatch LLM, write structured-md.
      # NOT exercised in CI per CON-3. Implementation surface:
      #   - resolve model via select-model.sh against task_type=extraction
      #   - call backend dispatch with the source text + extraction prompt
      #   - persist real model+tokens+cost values for the unit_close record
      echo "extract_tier_2_dispatch: live mode not yet implemented (use EXTRACT_TIER_2_DISPATCH=stub:pass|stub:block in CI)" >&2
      return 1
      ;;
    *)
      echo "extract_tier_2_dispatch: unknown mode '$mode' (expected: live|stub:pass|stub:block)" >&2
      return 1
      ;;
  esac
}

# extract_tier_2_emit_unit_close <cite_id> <model> <tokens_in> <tokens_out> <cost_usd> <quality_score>
#   Appends one JSONL record to ${ORCHESTRATOR_ROOT}/.orchestrator/execution-log.jsonl.
#   Returns 0 on success, 1 on error.
extract_tier_2_emit_unit_close() {
  local cite_id="$1"
  local model="$2"
  local tokens_in="$3"
  local tokens_out="$4"
  local cost_usd="$5"
  local quality_score="$6"
  local root="${ORCHESTRATOR_ROOT:-$(pwd)}"
  local log="$root/.orchestrator/execution-log.jsonl"
  mkdir -p "$(dirname "$log")"
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  printf '{"event":"unit_close","task_type":"extraction","cite_id":"%s","model":"%s","tokens_in":%s,"tokens_out":%s,"cost_usd":%s,"quality_score":%s,"timestamp":"%s","source":"runtime"}\n' \
    "$cite_id" "$model" "$tokens_in" "$tokens_out" "$cost_usd" "$quality_score" "$ts" >> "$log"
}
```

Make it executable: `chmod +x scripts/knowledge/lib/extract-tier-2-llm.sh`.

### Step 2 — Author `tools/verify/m036-p03-tier-2-llm-helper-shape.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p03-tier-2-llm-helper-shape.sh -- M036 P03 T02.
# Asserts the Tier 2 LLM helper exists, executable, exposes the two
# documented functions, and honors the EXTRACT_TIER_2_DISPATCH env var.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
LIB="$ROOT/scripts/knowledge/lib/extract-tier-2-llm.sh"
fail=0
if [ -f "$LIB" ] && [ -x "$LIB" ]; then
  echo "PASS: exists+executable $LIB"
else
  echo "FAIL: missing or non-executable $LIB"
  fail=$((fail + 1))
fi
checkpat() {
  local pat="$1"
  if grep -qF -e "$pat" "$LIB"; then
    echo "PASS: '$pat' in $(basename "$LIB")"
  else
    echo "FAIL: '$pat' missing in $(basename "$LIB")"
    fail=$((fail + 1))
  fi
}
checkpat "extract_tier_2_dispatch()"
checkpat "extract_tier_2_emit_unit_close()"
checkpat "EXTRACT_TIER_2_DISPATCH"
checkpat "stub:pass"
checkpat "stub:block"
checkpat "task_type"
echo "SUMMARY: m036-p03-tier-2-llm-helper-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### Step 3 — Author `tools/verify/m036-p03-driver-tier-2-shape.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p03-driver-tier-2-shape.sh -- M036 P03 T02.
# Asserts that scripts/knowledge/extract-reference.sh sources both new
# helpers (extract-tier-2-llm.sh + extract-tier-2-gate.sh authored in
# T03) and references the Tier 2 dispatch path. Cross-task ordering
# note: this verifier passes after T03 lands the gate helper +
# driver edits; T02 is responsible only for the llm helper part.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
DRV="$ROOT/scripts/knowledge/extract-reference.sh"
fail=0
if [ ! -f "$DRV" ]; then
  echo "FAIL: driver missing $DRV"
  echo "SUMMARY: m036-p03-driver-tier-2-shape.sh fail=1"
  exit 1
fi
checkpat() {
  local pat="$1"
  if grep -qF -e "$pat" "$DRV"; then
    echo "PASS: '$pat' in $(basename "$DRV")"
  else
    echo "FAIL: '$pat' missing in $(basename "$DRV")"
    fail=$((fail + 1))
  fi
}
checkpat "extract-tier-2-llm.sh"
checkpat "extract-tier-2-gate.sh"
checkpat "extract_tier_2_dispatch"
checkpat "extract_tier_2_invoke_gate"
checkpat "extract_tier_2_emit_unit_close"
checkpat "BLOCKED:"
echo "SUMMARY: m036-p03-driver-tier-2-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### Step 4 — Author `tools/verify/m036-p03-unit-close-extraction-shape.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p03-unit-close-extraction-shape.sh -- M036 P03 T02.
# Drives extract_tier_2_emit_unit_close in a mktemp -d workspace and
# asserts the resulting JSONL line carries the required M030 unit_close
# fields. Bash 3.2 / POSIX-sh per CON-2. Single-script-file shape.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
LIB="$ROOT/scripts/knowledge/lib/extract-tier-2-llm.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p03-unitclose.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
fail=0
if [ ! -f "$LIB" ]; then
  echo "FAIL: helper lib missing $LIB"
  echo "SUMMARY: m036-p03-unit-close-extraction-shape.sh fail=1"
  exit 1
fi
# shellcheck disable=SC1090
. "$LIB"
ORCHESTRATOR_ROOT="$WORK" extract_tier_2_emit_unit_close "verifier-cite-01" "claude-haiku-4-5" 100 200 0.005 0.95
LOG="$WORK/.orchestrator/execution-log.jsonl"
if [ ! -f "$LOG" ]; then
  echo "FAIL: log not created at $LOG"
  fail=$((fail + 1))
else
  echo "PASS: log created at $LOG"
fi
checkpat() {
  local pat="$1"
  if grep -qF -e "$pat" "$LOG"; then
    echo "PASS: '$pat' in unit_close JSONL"
  else
    echo "FAIL: '$pat' missing in unit_close JSONL"
    fail=$((fail + 1))
  fi
}
checkpat '"event":"unit_close"'
checkpat '"task_type":"extraction"'
checkpat '"model":"claude-haiku-4-5"'
checkpat '"cite_id":"verifier-cite-01"'
checkpat '"cost_usd":0.005'
checkpat '"tokens_in":100'
checkpat '"tokens_out":200'
echo "SUMMARY: m036-p03-unit-close-extraction-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

Make all three verifiers executable: `chmod +x tools/verify/m036-p03-{tier-2-llm-helper-shape,driver-tier-2-shape,unit-close-extraction-shape}.sh`.

## Must-Haves

- The Tier 2 helper lib `scripts/knowledge/lib/extract-tier-2-llm.sh` exposes `extract_tier_2_dispatch` (mockable via `EXTRACT_TIER_2_DISPATCH`) and `extract_tier_2_emit_unit_close`.
- Each Tier 2 invocation appends one well-formed `unit_close` JSONL record with `task_type=extraction`, `model`, `tokens_in`, `tokens_out`, `cost_usd`, `quality_score`.

## Verification

```bash
bash tools/verify/m036-p03-tier-2-llm-helper-shape.sh
```

```bash
bash tools/verify/m036-p03-unit-close-extraction-shape.sh
```

(Note: `m036-p03-driver-tier-2-shape.sh` is authored in T02 but exercises driver edits that land in T03 — under the cross-task-ordering pattern carried from M036/P02, this verifier goes green retroactively at T03 close. Listed in T03's verification block, not T02's, so the auto-loop's first-fail-retry doesn't pause T02 incorrectly.)

## Inputs

### From Previous Tasks

- `tests/fixtures/m036-p03-tier-2/extract-manifest.yaml` (from T01)
  - Key API: declares one tier-2 doc with `summary_mode: auto` + cite_id `tier2-fixture-01`. Source path: `sample.md` (markdown — CON-3).

### From Disk (Pre-existing)

- `scripts/dispatch/select-model.sh` — M030 model resolver. Live-path uses it; not exercised in CI.
- `scripts/knowledge/extract-reference.sh` — P02 driver. T02 does NOT modify it; T03 will (sources the new helper + adds Tier 2 dispatch).
- `scripts/knowledge/lib/extract-binary-preservation.sh` — provides `preservation_sha256` (used by the P02 driver for content-hash idempotency; the live-path Tier 2 helper would re-use it but the live path is deferred).
- `scripts/dispatch/adapters/tool/conversus.sh` — invoked by T03's gate helper, not by T02's llm helper.

## Constraints

- CON-2 (Bash 3.2 / POSIX-sh).
- CON-3 (no live LLM in CI — `extract_tier_2_dispatch` returns error 1 in `live` mode for now; CI uses stub modes).
- MEM004 (pure-lib pattern: args-in / stdout+exit-out / no top-level I/O — the lib has only function definitions).
- AD-19 single-script-file shape for verifier `Check:` invocations.
- Verifier filename milestone-prefixed slug `m036-p03-*`.
- `grep -qF -e "$pat"` form throughout (BSD-grep flag-safety carried from M036/P02).
- The `unit_close` JSONL record format MUST match the existing emitter convention used by `scripts/integrations/github-common.sh::emit_tier1_record` (single-line JSONL, fields: `event`, `source`, `timestamp`, plus task-specific fields). The M036/P03 record adds `task_type` + `cite_id` + `model` + `tokens_in` + `tokens_out` + `cost_usd` + `quality_score`.

## Expected Output

After T02 completes:

- `scripts/knowledge/lib/extract-tier-2-llm.sh` exists (~80 lines), executable, sources cleanly with no top-level I/O.
- 3 new executable verifiers under `tools/verify/m036-p03-*`.
- `m036-p03-tier-2-llm-helper-shape.sh` and `m036-p03-unit-close-extraction-shape.sh` exit 0.
- `m036-p03-driver-tier-2-shape.sh` may FAIL at T02-close (driver not yet edited) and goes green at T03-close. Documented under cross-task-ordering.

## Notes

The `live` branch is intentionally a stub error in T02 because:
1. CON-3 forbids live LLM in CI — the live path can never be exercised by the auto-loop or phase-suite.
2. The live-path implementation requires choosing a backend dispatch surface (subprocess `claude -p`, MCP, conversus run, etc.) that is out of scope for the M036a critical path. PBJ pilot uses the stub path with operator-supplied summaries authored in advance.
3. M036b (post-launch) will land the live extraction path with operator-facing UX (queue, retry, etc.) — the stub seam in T02 is the future-extension point.

The decision to ship `live` as a stub-error is captured here in the plan body rather than in [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) because it's an implementation seam (re-openable when M036b plans), not a load-bearing architectural commitment.

## State Context

- **Current State**: executing
- **Milestone**: M036
- **Phase**: P03
- **Task**: T02-tier-2-llm-helper-and-unit-close
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- CON-2 (Bash 3.2 / POSIX-sh).
- CON-3 (no live LLM in CI — `extract_tier_2_dispatch` returns error 1 in `live` mode for now; CI uses stub modes).
- MEM004 (pure-lib pattern: args-in / stdout+exit-out / no top-level I/O — the lib has only function definitions).
- AD-19 single-script-file shape for verifier `Check:` invocations.
- Verifier filename milestone-prefixed slug `m036-p03-*`.
- `grep -qF -e "$pat"` form throughout (BSD-grep flag-safety carried from M036/P02).
- The `unit_close` JSONL record format MUST match the existing emitter convention used by `scripts/integrations/github-common.sh::emit_tier1_record` (single-line JSONL, fields: `event`, `source`, `timestamp`, plus task-specific fields). The M036/P03 record adds `task_type` + `cite_id` + `model` + `tokens_in` + `tokens_out` + `cost_usd` + `quality_score`.

### Acceptance Criteria

- The Tier 2 helper lib `scripts/knowledge/lib/extract-tier-2-llm.sh` exposes `extract_tier_2_dispatch` (mockable via `EXTRACT_TIER_2_DISPATCH`) and `extract_tier_2_emit_unit_close`.
- Each Tier 2 invocation appends one well-formed `unit_close` JSONL record with `task_type=extraction`, `model`, `tokens_in`, `tokens_out`, `cost_usd`, `quality_score`.

### Files To Touch

- `templates/conversus-presets/tier-2-fidelity.yml` (create)
- `templates/model-routing.yml` (modify — additive `routing.extraction:` row only; CON-3 closure preserved — no new model IDs outside `resolution:`)
- `tests/fixtures/m036-p03-tier-2/extract-manifest.yaml` (create)
- `tests/fixtures/m036-p03-tier-2/sample.md` (create)
- `tests/fixtures/m036-p03-tier-2/canned-structured.md` (create)
- `tests/fixtures/m036-p03-tier-2/canned-structured-low-fidelity.md` (create)
- `scripts/knowledge/lib/extract-tier-2-llm.sh` (create)
- `scripts/knowledge/lib/extract-tier-2-gate.sh` (create)
- `scripts/knowledge/lib/extract-tier-0-summary.sh` (modify — auto branch returns sentinel for tier=2 instead of hard-erroring; tier!=2 + auto continues to deferral-error)
- `scripts/knowledge/extract-reference.sh` (modify — source new helpers; add Tier 2 dispatch + gate + promote/retain block when tier==2 && summary_mode==auto)
- `tests/test-tier-2-extraction-with-gate.sh` (create)
- `tools/verify/m036-p03-conversus-preset-shape.sh` (create)
- `tools/verify/m036-p03-m030-task-type-extraction.sh` (create)
- `tools/verify/m036-p03-fixture-corpus-shape.sh` (create)
- `tools/verify/m036-p03-driver-tier-2-shape.sh` (create)
- `tools/verify/m036-p03-tier-2-llm-helper-shape.sh` (create)
- `tools/verify/m036-p03-unit-close-extraction-shape.sh` (create)
- `tools/verify/m036-p03-gate-helper-shape.sh` (create)
- `tools/verify/m036-p03-tier-2-deferred-error-removed.sh` (create)
- `tools/verify/m036-p03-tier-2-pass-end-to-end.sh` (create)
- `tools/verify/m036-p03-tier-2-block-retention.sh` (create)
- `tools/verify/m036-p03-p02-regression-pass.sh` (create)
- `tools/verify/m036-p03-fixture-canned-structured-shape.sh` (create)
- `tools/verify/m036-p03-test-harness.sh` (create)
- `tools/verify/m036-p03-acceptance-harness-passes.sh` (create)
- `tools/verify/m036-p03-phase-suite.sh` (create)

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