---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T01-rollback-marker-contract (Phase P05, Milestone M035)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~300 | required |
| Upstream Context | 981-1047 | ~6400 | required |
| Task Plan | 1049-1399 | ~4100 | required |
| State Context | 1401-1407 | ~100 | required |
| First-Turn Completeness | 1409-1480 | ~900 | required |
| **Total** | | **~22600** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 879
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
hit_count: 879
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
hit_count: 879
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
hit_count: 879
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
hit_count: 763
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
hit_count: 763
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
hit_count: 763
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
hit_count: 879
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
hit_count: 763
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
hit_count: 763
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
hit_count: 763
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
hit_count: 879
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
hit_count: 879
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
hit_count: 879
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
hit_count: 763
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
hit_count: 763
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
hit_count: 763
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
hit_count: 879
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
hit_count: 763
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
hit_count: 763
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
hit_count: 879
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
hit_count: 879
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
hit_count: 763
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
hit_count: 763
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
hit_count: 763
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
hit_count: 418
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
hit_count: 418
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
hit_count: 418
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
hit_count: 455
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
hit_count: 455
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
hit_count: 445
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

- `.orchestrator/.previous-version` is written by every install/update
  invocation (per the FR-12 contract) before the new manifest is staged.
  The file carries the load-bearing schema fields: `prior_version=`,
  `prior_commit_sha=`, `prior_manifest_path=`, `prior_install_mode=`.
  When `prior_install_mode=symlink`, `prior_manifest_path=` is still
  populated (for completeness) but `--rollback` will refuse before
  consulting it.
  - Check: `bash tools/verify/m035-p05-rollback-marker-shape.sh`

- `.orchestrator/.rollback/manifest-<prior-version>.txt` is a verbatim
  snapshot of the prior install's `.orchestrator/installed-files.txt`,
  written by every install/update transition. Snapshot lifecycle: written
  at install-time before the new install replaces `installed-files.txt`;
  reused on subsequent installs (the M035 install-meta.txt + manifest
  pair drives the snapshot — first install with no `.previous-version`
  writes nothing, second install snapshots first install's manifest, etc.).

<dispatch-volatile>

## Upstream Context


### P02 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P02"
parent: "M035"
milestone: "M035"
provides:
  - "package.json npm v1 manifest at repo root with @build-fractal/orchestrator name ([D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }")) + 0.9.2 version (CON-4 CHANGELOG read) + bin.orchestrator -> bin/orchestrator (FR-8) + scripts.postinstall reference (T02 target) + engines.node>=14 + os: [darwin,linux] (D003/MIT-9 npm-side Windows fail-closed) + files whitelist; bin/orchestrator executable v1 binary entry point with --version (jq-free package.json read) + --help/-h/no-args banner naming orchestrator:<cmd> cohort prefix ([D-RN-3](../../../../../decisions.md#d-rn-3-command-cohort-prefix-orchestratorcmd-dr-code-031 "Command-cohort prefix `orchestrator:<cmd>` { #dr-code-031 }")) + non-zero exit on unknown invocation (no subcommand dispatch at v1); tools/verify/m035-p02-package-json-shape.sh task-grain verifier (7 grep-based pattern checks AD-19 single-script shape BATTERY: pass=7 fail=0); tools/verify/m035-p02-bin-entry.sh task-grain verifier (3 conditions: file-exists+executable / --version matches package.json / no-args banner contains cohort-prefix string AD-19 single-script shape BATTERY: pass=3 fail=0),packaging/npm/postinstall.sh executable npm-postinstall driver: Windows fail-closed guard via uname -s case (MIT-9/D003 belt-and-suspenders); INIT_CWD-aware project-dir resolution (npm convention with NPM_PREFIX global-install short-circuit emitting global-install advisory and exit 0); DRY_RUN=1 honor (D002 fixture-strategy contract,emits would_invoke= / would_check= / would_delegate= lines and exits 0 without writes); Claude Code runtime probe via ~/.claude/ directory presence (absence yields runtime_unavailable=true advisory and exit 0 — soft-fail per CI-runner-without-CC use case); delegation to packaging/install/install-claude-code.sh --project-dir $INIT_CWD preserving M025 manifest mechanism (CON-7); tools/verify/m035-p02-postinstall-shape.sh task-grain verifier (1 file-exists+executable + 7 grep contract surfaces + 1 functional DRY_RUN smoke test against temp dir,AD-19 single-script shape BATTERY: pass=9 fail=0),tests/m035-acceptance/cross-channel-byte-equivalence.sh executable Constitution-Principle-XVI compliance test (145 lines,npm-channel arm functional + homebrew-arm SKIP: pending P03 stub + curl-pipe-bash-arm SKIP: pending P04 stub + BATTERY pass/fail/skip line shape mirroring m029/m030/m032 acceptance-battery convention); tests/m035-acceptance/_byte-equivalence-hash.sh executable hashing helper (55 lines,find+LC_ALL=C-sort+grep -vE+per-file shasum + outer shasum yielding deterministic SHA-256 digest of staged tree minus EXCLUSION_LIST regex globs); references/installation.md modification adding Channel-specific metadata files section (~20 lines,MIT-2 canonical exclusion-list as markdown table -- .orchestrator/install-meta.txt + .orchestrator/.previous-version + package.json + package-lock.json + node_modules/ + .brew/*.bottle.tab + Library/Caches/Homebrew/ + .git/+.github/) inserted between Upgrading and Uninstall; tools/verify/m035-p02-byte-equivalence-skeleton.sh task-grain verifier (80 lines,BATTERY pass=10 fail=0 -- 2 file-shape + 6 grep-contract + 2 functional-smoke surfaces); tools/verify/m035-p02-installation-doc-exclusion-list.sh task-grain verifier (41 lines,BATTERY pass=6 fail=0 -- 1 heading + 5 path-presence checks),.github/workflows/release.yml GitHub Actions release pipeline skeleton (160 lines,valid YAML,ubuntu-latest D001,two jobs: pr-validate runs on PR + main-push without secrets exercising T01/T02/T03 verifiers + cross-channel byte-equivalence (npm-channel arm) + CON-6 negative-assertion runtime step that fails on NPM_TOKEN env-var leak; npm-publish runs only on v* tag-push events on canonical repo with NODE_AUTH_TOKEN populated from secrets.NPM_TOKEN,runs npm publish --access public,includes tag-vs-package.json version-gate step + pre-publish gates invoking all T01-T03 verifiers + post-publish npm view confirmation); tools/verify/m035-p02-release-workflow-shape.sh task-grain verifier (75 lines,executable,AD-19 single-script Check shape,BATTERY: pass=10 fail=0 -- 10 grep-contract surfaces covering job presence + runner + CON-6 secrets-scope + SC-14 negative-assertion step presence + T03 test invocation + T01 verifier invocation + scoped-package --access public flag); /tmp/m035-p02-t04-yaml-validate.sh staged probe (Python yaml.safe_load shape-guard against indentation breakage in future workflow edits,invoked via scripts/util/run-probe.sh approved-roots wrapper),Bundle-hygiene pre-publish filter (#Q-9 absorption) wired into `packaging/bundle/build-bundle.sh` as `should_exclude_from_bundle()` + `apply_bundle_hygiene_filter()` (rule 1: pattern exclusion of `m[0-9]*-p[0-9]*-*` under `scripts/verify/`,`tools/verify/`,`templates/conversus-presets/`; rule 2: magic-comment opt-out scanning first 10 lines for `bundle: dogfood-only`); `packaging/bundle/manifest.yml` bundle-hygiene contract comment block (15 lines) inserted after `schema_version`; root `.npmignore` (defense-in-depth + maintainer pointer) + per-subdir `scripts/verify/.npmignore` + `templates/conversus-presets/.npmignore` (the actually-load-bearing layer); three new task-grain verifiers — `tools/verify/m035-p02-bundle-hygiene-filter.sh` (10 grep-contract surfaces,BATTERY pass=10),`tools/verify/m035-p02-npm-pack-contents.sh` (19 include/exclude surfaces against real `npm pack` tarball,BATTERY pass=19),`tools/verify/m035-p02-phase-suite.sh` (8-verifier aggregator emitting BATTERY pass=8 fail=0 across all P02 task-grain verifiers); two staged probes — `/tmp/m035-p02-t05-build-bundle-smoke.sh` (build-bundle.sh --check sanity)"
requires:
  - "P01.5"
affects:
  - "P03,P05,P04,P06"
key_files:
  - "package.json,bin/orchestrator,tools/verify/m035-p02-package-json-shape.sh,tools/verify/m035-p02-bin-entry.sh,packaging/npm/postinstall.sh,tools/verify/m035-p02-postinstall-shape.sh,tests/m035-acceptance/cross-channel-byte-equivalence.sh,tests/m035-acceptance/_byte-equivalence-hash.sh,references/installation.md,tools/verify/m035-p02-byte-equivalence-skeleton.sh,tools/verify/m035-p02-installation-doc-exclusion-list.sh,.github/workflows/release.yml,tools/verify/m035-p02-release-workflow-shape.sh,packaging/bundle/build-bundle.sh,packaging/bundle/manifest.yml,.npmignore,scripts/verify/.npmignore,templates/conversus-presets/.npmignore,tools/verify/m035-p02-bundle-hygiene-filter.sh,tools/verify/m035-p02-npm-pack-contents.sh,tools/verify/m035-p02-phase-suite.sh"
key_decisions:
  - "[D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }") (dr-code-029 binds @build-fractal/orchestrator npm scope); [D-RN-3](../../../../../decisions.md#d-rn-3-command-cohort-prefix-orchestratorcmd-dr-code-031 "Command-cohort prefix `orchestrator:<cmd>` { #dr-code-031 }") (dr-code-031 binds orchestrator:<cmd> cohort prefix); D003 (binds engines.node + os fail-closed Windows guard); CON-4 (CHANGELOG SemVer source-of-truth); CON-3 (compound-chain shape-guard via run-probe.sh staged probes); AP-009 (no inline bash -c chains); MIT-9 (Windows fail-closed via npm os array); FR-8 (bin/orchestrator entry point),[D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }") (dr-code-029 binds @build-fractal/orchestrator npm scope echoed in advisory messages); MIT-9 (Windows fail-closed via uname -s case match — secondary belt-and-suspenders behind package.json os field primary gate per D003); D002 (DRY_RUN=1 test-fixture contract emits would_invoke= lines without writes); CON-7 (M025 reversibility-gate preserved — postinstall delegates to install-claude-code.sh which writes M025 manifest,does NOT bypass); CON-3 / AP-009 (compound-chain shape-guard honored — bash 3.2 compatible,no jq,no python,no inline compound chains),MIT-2 (exclusion list lives in references/installation.md Channel-specific metadata files; test reads at runtime; no hardcoded duplication); CON-5 (cross-channel byte-equivalence contract bootstrapped at P02 with one channel -- npm -- and enforced at P03 close (homebrew arm) and P04 close (curl-pipe-bash arm); P02 contract is the-harness-works); SC-10 / FR-14 (Constitution Principle XVI compliance test surface at v1); AD-2 (byte-equivalence test is an acceptance test not an implementation goal -- asserts same logical install across channels produces same on-disk file set modulo documented exclusion list); D002 (DRY_RUN=1 contract -- postinstall sees DRY_RUN=1 and emits would_invoke lines,making T03 fully offline and side-effect-free); [D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }") (npm scope @build-fractal/orchestrator drives tarball name pattern build-fractal-orchestrator-*.tgz and staged-tree path lib/node_modules/@build-fractal/orchestrator); CON-3 / AP-009 (compound-chain shape-guard honored -- main test script avoids inline compound chains by delegating hashing to single-script-file helper; helper find+sort+grep+shasum pipeline is one logical operation),D001 (CI runner = ubuntu-latest); CON-6 (secrets-scoped to v* tag-push -- secrets.NPM_TOKEN appears ONLY inside npm-publish job body; pr-validate carries runtime negative-assertion step that fails on NPM_TOKEN env-var leak; static shape verifier asserts both surfaces); SC-14 (PR-build job-condition negative assertion encoded as runtime step -- Static analysis of workflow YAML at acceptance-battery time + runtime check at PR-build time = two complementary surfaces); [D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }") (npm scope @build-fractal/orchestrator drives publish target name; --access public flag required for scoped packages); CON-3/AP-009 (workflow YAML is single declarative document; inline run blocks use YAML pipe block scalar = single-script-shape not heredoc; no compound chains); AD-19 (verifier ships single-script Check shape with BATTERY-line output convention); CON-7 (pre-launch reversibility: T04 does not push tags or configure NPM_TOKEN; npm unpublish 72h policy window is operator-side); D002 (DRY_RUN=1 postinstall contract preserved by T03 surface invoked from workflow),#Q-9-absorbed: T05 ships rules + verifiers; explicitly defers retroactive dogfood-tagging audit (the pattern rule alone catches the bulk ~791 verifiers,magic-comment is forward-looking for new authors); per-subdir-.npmignore-is-load-bearing: discovered at execution time that when `package.json` `files:` whitelist is present,the ROOT `.npmignore` is largely subordinate for top-level entries — the actual filtering layer for dogfood content INSIDE whitelisted subtrees is per-subdir `.npmignore` files (`scripts/verify/.npmignore`,`templates/conversus-presets/.npmignore`); root `.npmignore` retained as defense-in-depth + discoverable maintainer pointer; post-copy-filter-shape-preferred: `apply_bundle_hygiene_filter()` runs after the per-skill `cp` loop in `cmd_build` rather than converting the existing iteration to a `find`-pipe — preserves existing [M032](../../../../../milestones/M032/index.md) contract surface and is no-op for the current bundle dir which has no `scripts/verify` subtree,but the contract+verifier surface is what T05 is measured by; verifier-asserts-source-shape-not-runtime-effect: bundle-hygiene-filter verifier checks `build-bundle.sh` CARRIES the filter logic via `grep` on source code rather than running build-bundle.sh and counting excluded files — works regardless of whether the current bundle dir contains dogfood content"
patterns_established:
  - "changelog-as-version-source-of-truth (awk regex skips [Unreleased] reads top-line semver); npm-side-os-allowlist-as-windows-fail-closed (npm rejects EBADPLATFORM when os array excludes win32); minimal-binary-with-skill-redirect (v1 binary surface is --version + banner + non-zero on unknown invocation deferring subcommand dispatch to post-launch); jq-free-version-read-from-package.json (grep -E pipe head -1 pipe sed -E bash 3.2 compatible no toolchain dependency); REPO_ROOT-defensive-fallback-in-staged-probes (run-probe.sh computes but does not export REPO_ROOT; probes use parameter expansion fallback for portability),npm-postinstall-as-thin-delegate (postinstall is a guard layer + INIT_CWD resolver + runtime detector; actual skill registration delegates to existing M025 install-claude-code.sh — preserves M025 manifest mechanism without bypass); INIT_CWD-with-npm-prefix-short-circuit (npm sets INIT_CWD to invocation dir; when INIT_CWD matches $NPM_PREFIX or $NPM_PREFIX/lib/node_modules,treat as 'global install no project context' and emit advisory exit 0 rather than registering against npm prefix dir); soft-fail-on-runtime-absence (Claude Code missing yields runtime_unavailable=true advisory + exit 0,NOT exit 1 — supports CI-runner use case where operator wants binary on PATH for later integration; skill registration deferred to first /orchestrator-init invocation); Windows-belt-and-suspenders-guard-pattern (package.json os field is primary gate at npm side; postinstall uname -s case is secondary defense — if user reaches postinstall on Windows,npm config was bypassed and we fail loudly with issue-tracker URL); DRY_RUN=1-as-pre-delegate-exit (DRY_RUN check fires AFTER INIT_CWD resolution but BEFORE installer invocation,so dry-run output captures the exact command that WOULD have run with the resolved project dir — T03 byte-equivalence test depends on this contract); REPO_ROOT-via-script-dir-traversal (postinstall self-resolves REPO_ROOT as 2-levels-up from $(dirname $0) — works post-npm-extraction where the package layout is preserved),doc-as-canonical-list-with-runtime-read (exclusion list lives in references/installation.md as markdown table; test extracts at runtime via awk+backtick-scrape; future plan-phase authors update doc first; MIT-2 single-source-of-truth preserved by mechanism not just convention); awk-flag-pattern-over-range-pattern-for-section-extraction (the start/end range form self-terminates when start line matches end regex; flag-based form is safer shape for extract-section-between-two-headings-of-same-level); deterministic-hash-via-LC_ALL=C-sort+per-file-digest+outer-digest (find . -type f piped through LC_ALL=C sort then per-file shasum+relpath then outer shasum produces locale-independent reproducible content+layout fingerprint; two-stage shasum means renames or content changes both move the digest); stub-with-SKIP-line-as-multi-channel-bootstrap (test ships with all three channel arms wired but only npm arm functional; P03 replaces SKIP pending P03 with homebrew implementation,P04 same for curl-pipe-bash; cross-channel equality assertion is no-op at P02 -- single-channel byte-equivalence is reflexive -- and becomes load-bearing at P03 close); direct-bash-invocation-of-in-tree-helper-not-via-run-probe.sh (scripts/util/run-probe.sh is scoped to staged /tmp/* probes; committed in-repo helpers at tests/+scripts/+tools/ are invoked directly via bash single-script per AD-19; AP-009 concern is inline compound-shell logic not single-script delegation); test-IS-the-smoke-no-mock-only-verification (verifier functional smoke runs the actual test which runs actual npm pack + npm install -g against mktemp -d fixture; Plan-Time Discipline Rule 5 analog -- npm tarball assembly is load-bearing surface and must be exercised end-to-end); BATTERY-line-shape-skip-aware (BATTERY pass/fail/skip extends the m029/m030/m032 pass/fail convention with skip count; consolidate-time grep aggregation works against either shape because skip lines are explicit SKIP echoes not BATTERY-counted in the skipped-channel arm),CON-6-defense-in-depth (workflow uses TWO layers to enforce secrets-scoping: (a) npm-publish job if-condition startsWith(github.ref refs/tags/v) AND github.event_name == push -- structural gate; (b) pr-validate runtime step CON-6 -- assert no NPM_TOKEN access -- actively fails build if env var leaks; either layer alone load-bearing; both together survive single misconfig like org-level secret leak); tag-vs-manifest-version-gate (npm-publish first non-checkout step strips v from GITHUB_REF and compares to package.json version via grep + head + sed -E pipeline inside YAML pipe block scalar single-script-shape; failed gate exits non-zero before npm publish call preventing accidental publish of mismatched tag/version); job-condition-AND-clause-canonical-repo-canonical-event (publish-job condition combines startsWith(github.ref refs/tags/v) with github.event_name == push; event-name guard prevents fork-PR shenanigans -- fork PR that somehow tagged a commit cannot trigger publish since fork PRs are pull_request not push); verifier-asserts-shape-not-runtime-semantics (workflow-shape verifier checks CON-6 negative-assertion step EXISTS in workflow not that NPM_TOKEN is absent at runtime -- that is SC-14 runtime check inside actual GHA-rendered job; static analysis of YAML at acceptance-battery time + runtime check at PR-build time = two complementary surfaces); skeleton-with-extension-points-for-P03-P04-P05 (workflow comment header explicitly enumerates deferred scope: homebrew-bottle build P03; signed install.sh upload P05; GH release-notes P04; future plan-phase authors have clear contract); pending-T05-step-conditional-shape (if test -x verifier then bash verifier else echo SKIP fi -- canonical extension pattern for verifiers shipping in later tasks of same phase; lets release.yml land at T04 close without re-edit when T05 lands); POSIX-character-class-over-backslash-s-in-grep-E (BSD grep -E on macOS does not honor backslash-s reliably; substituted POSIX space class which is portable across BSD and GNU grep -E; mirrors P01.5 T04 BSD-grep-boundary-anchor-replacement pattern -- functionally identical both match space+tab+ff+vt; verifier runs locally on macOS during dispatch and on ubuntu-latest in CI so portability load-bearing); workflow-YAML-block-scalar-as-single-script-shape (multi-line shell uses YAML pipe block scalar which is single-script-shape per AP-009 -- not heredoc-with-expansion; satisfies CON-3 compound-chain guard while allowing multi-statement shell logic inside one declarative step),package.json-files-whitelist-vs-npmignore-precedence: when `package.json` has a `files:` whitelist,npm packs honor the whitelist for top-level entries; root `.npmignore` patterns scoped under those whitelisted top-level entries do NOT apply,but per-subdirectory `.npmignore` files INSIDE whitelisted subtrees DO apply — this is the canonical pattern for pruning dogfood content from inside `scripts/`,`templates/`,etc. Initial root-only `.npmignore` left 796 dogfood verifiers in the tarball; adding `scripts/verify/.npmignore` dropped the count to zero,contract-via-grep-of-source-not-runtime: bundle-hygiene-filter verifier asserts `build-bundle.sh` carries the filter logic via grep on source code rather than running `build-bundle.sh` and counting excluded files — works for any bundle dir state including the current empty-of-dogfood state; the actual dogfood-exclusion test happens against the npm tarball where dogfood content actually exists today,real-tarball-as-real-bundle-smoke (Plan-Time Discipline Rule 5 analog): npm-pack-contents verifier runs actual `npm pack` against the modified bundle and inspects the staged tarball — this IS the real-bundle smoke test,no mock-only equivalent; if filter logic is wrong the tarball contents are wrong and the verifier fails. Failure mode caught in execution: 796 dogfood verifiers in tarball when only root `.npmignore` was present,BATTERY-line-shape-mirrors-prior-milestones: `BATTERY: pass=N fail=N` matches m030 + m032 + m029 + m037 + m035-p015 phase-suite convention enabling consolidate-time grep aggregation across milestone batteries. The phase-suite uses a `bash $v >/dev/null 2>$ERR_LOG` shape per verifier so individual verifier output doesn't pollute the aggregator's BATTERY line,single-script-find-with-exec-rm-form: `find ... -type f -name 'glob' -exec rm -f {} +` is a single-command shape; satisfies AP-009 single-script-shape constraint without needing `run-probe.sh` wrapper for the build-time filter. The `find ... | while IFS= read -r f; do ... done` pipeline is also AP-009-permitted because the inner body is a single grep+rm,not a compound chain"
drill_down_paths:
  - "[.orchestrator/milestones/M035/phases/P02/tasks/T01-package-json-and-bin-SUMMARY.md](../../../../../milestones/M035/phases/P02/tasks/T01-package-json-and-bin-SUMMARY.md), [.orchestrator/milestones/M035/phases/P02/tasks/T02-postinstall-driver-SUMMARY.md](../../../../../milestones/M035/phases/P02/tasks/T02-postinstall-driver-SUMMARY.md), [.orchestrator/milestones/M035/phases/P02/tasks/T03-byte-equivalence-skeleton-SUMMARY.md](../../../../../milestones/M035/phases/P02/tasks/T03-byte-equivalence-skeleton-SUMMARY.md), [.orchestrator/milestones/M035/phases/P02/tasks/T04-release-workflow-SUMMARY.md](../../../../../milestones/M035/phases/P02/tasks/T04-release-workflow-SUMMARY.md), [.orchestrator/milestones/M035/phases/P02/tasks/T05-bundle-hygiene-and-phase-suite-SUMMARY.md](../../../../../milestones/M035/phases/P02/tasks/T05-bundle-hygiene-and-phase-suite-SUMMARY.md)"
duration: "94m"
verification_result: "pass"
completed_at: "2026-05-08T20:35:47Z"
observability_surfaces:
  - "none"
---

## What was built

P02 establishes the npm publishing channel for `@build-fractal/orchestrator` end-to-end:

- **T01 — `package.json` + `bin/orchestrator`**: scoped manifest declares `@build-fractal/orchestrator` ([D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }")), `0.9.2` from `CHANGELOG.md` top-line (CON-4), `engines.node>=14`, `os: [darwin, linux]` (D003 / MIT-9 npm-side Windows fail-closed), and the postinstall pointer. The binary entry point ships a jq-free `--version` reader, a `--help` banner naming the `orchestrator:<cmd>` cohort prefix ([D-RN-3](../../../../../decisions.md#d-rn-3-command-cohort-prefix-orchestratorcmd-dr-code-031 "Command-cohort prefix `orchestrator:<cmd>` { #dr-code-031 }")), and non-zero exit on unknown invocation — subcommand dispatch is deferred post-launch.
- **T02 — `packaging/npm/postinstall.sh`**: thin delegate. Windows fail-closed via `uname -s` (belt-and-suspenders behind the package.json `os` field), INIT_CWD-aware project-dir resolution with NPM_PREFIX global-install short-circuit, Claude Code soft-fail (runtime-absent → advisory + exit 0 supports CI-runner use case), DRY_RUN=1 emits `would_invoke=` lines (D002 fixture-strategy contract), and final delegation to `packaging/install/install-claude-code.sh` preserving M025's manifest mechanism (CON-7 reversibility-gate).
- **T03 — Constitution Principle XVI test (CON-5)**: `tests/m035-acceptance/cross-channel-byte-equivalence.sh` ships with all three channel arms wired but only the npm arm functional; homebrew + curl-pipe-bash arms emit explicit `SKIP: pending P03/P04` lines until the upstream phases extend. The hashing helper produces a deterministic, locale-independent fingerprint (`LC_ALL=C sort` + per-file shasum + outer shasum). The exclusion list (MIT-2) lives canonically in `references/installation.md § Channel-specific metadata files` and is read at runtime via awk extraction — single source of truth by mechanism, not just convention.
- **T04 — `.github/workflows/release.yml` skeleton**: two-job split with CON-6 defense-in-depth (structural job-condition + runtime negative-assertion step). PR-validate runs all upstream verifiers + the npm-channel byte-equivalence arm without secrets; npm-publish gates on `startsWith(github.ref, 'refs/tags/v') && github.event_name == 'push'` to block fork-PR exfiltration of `secrets.NPM_TOKEN`. Tag-vs-manifest version-gate prevents accidental publish of mismatched versions. SC-14 PR-build job-condition assertion landed both as static-analysis verifier and runtime check.
- **T05 — Bundle hygiene + phase suite (#Q-9 absorption)**: discovered at execution time that `package.json` `files:` whitelist + a root-only `.npmignore` left 796 dogfood verifiers in the tarball — npm honors the root `.npmignore` only weakly when the whitelist is present. Per-subdir `.npmignore` files (`scripts/verify/.npmignore`, `templates/conversus-presets/.npmignore`) are the load-bearing layer. `npm-pack-contents` verifier runs actual `npm pack` and inspects the tarball: 19 include/exclude assertions, all passing. Phase-suite aggregator chains all eight P02 verifiers in T01→T05 order and emits `BATTERY: pass=8 fail=0`.

## Plan-phase Open Questions resolved

- **#Q-7** → CI runner platform = `ubuntu-latest` (D001).
- **#Q-10** → test-fixture strategy = `npm pack` to local tarball, `npm install -g` into mktemp prefix; no real-registry calls (D002).
- **#Q-G9 / MIT-9** → Windows guard = `package.json` `engines`+`os` arrays (primary) + postinstall `uname -s` (secondary) (D003).
- **#Q-9** → install-meta.txt schema extension absorbed into T05 bundle hygiene; pattern-rule + magic-comment opt-out catches the bulk forward; retroactive dogfood-tagging audit explicitly deferred.

## Verification

- `tools/verify/m035-p02-phase-suite.sh` → `BATTERY: pass=8 fail=0`
- All eight task-grain verifiers green: `package-json-shape` (7), `bin-entry` (3), `postinstall-shape` (9), `byte-equivalence-skeleton` (10), `installation-doc-exclusion-list` (6), `release-workflow-shape` (10), `bundle-hygiene-filter` (10), `npm-pack-contents` (19).
- Real-bundle smoke: `npm pack` against the modified bundle produces a clean tarball with zero dogfood verifiers (down from 796 pre-T05).

## Patterns established

- Per-subdir `.npmignore` is the load-bearing dogfood-exclusion layer when `package.json` `files:` whitelist is present
- Verifier shape: `BATTERY: pass=N fail=N` (and `skip=N` where applicable) for grep-aggregable consolidate-time rollups
- CON-6 defense-in-depth: structural job-condition + runtime env-var negative-assertion step
- DRY_RUN=1 as pre-delegate exit point — captures the resolved invocation without side effects, which the byte-equivalence test depends on

## Caveats

- `scripts/util/run-probe.sh` does not export `REPO_ROOT` to child probes; T01, T02, T05 staged probes all hit this and applied a defensive `REPO_ROOT="${REPO_ROOT:-...}"` fallback. Recommended follow-up paper-cut: either export REPO_ROOT in `run-probe.sh` or update its docstring to make the contract explicit.
- `append-decision.sh` produces 7-column-table rows; the M035 P01.5 D-RN-### decisions used the new `### <Title> { #dr-code-NNN }` heading-shape. Reshape from table-row to heading-shape is a separate paper-cut, not a P02 blocker.
- T04 release.yml is a *skeleton*: P03 extends with homebrew-bottle, P04 composes the curl-pipe-bash artifact, P05 adds signing + checksums. The npm-publish job is real but untested against GitHub Actions infrastructure until the first PR after merge.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P05"
milestone: "M035"
name: "Rollback-marker contract — schema + writer + install-script integration (FR-12 minimum surface, #Q-G8 binding)"
depends_on: []
---

## Prerequisites

- **`.orchestrator/installed-files.txt`** exists in any consumer fixture
  used to test this task. Schema is `<rel-path>\tmode:<copy|symlink>`
  per FR-1 / FR-2 (M035 P01). T01 reads this file's full contents at
  upgrade time and snapshots it byte-for-byte.
- **`.orchestrator/install-meta.txt`** exists in the same fixture. Schema
  carries `commit_sha=` and `version=` lines (per M035 P01 T01 / #Q-9
  amendment landed at commit 8bcba64). T01 reads these two fields to
  populate `prior_commit_sha=` and `prior_version=` in the marker file.
- **`scripts/lib/errors.sh`** exists and exports `emit_result()` for
  PASS/FAIL line emission. T01 verifier sources this for consistent
  output shape.
- **`packaging/install/install-claude-code.sh`** exists with the M035 P01
  Stage 4.4 install-meta.txt write block at lines 511–544. T01 hooks
  the rollback-marker write IMMEDIATELY AFTER the install-meta write
  block but BEFORE the manifest write (Stage 4.5+). At the moment of
  the hook, the *prior* `installed-files.txt` is still on disk
  unmodified — that is the file T01 snapshots.
- **`packaging/install/install-codex.sh`** and **`install-cursor.sh`**
  exist with parallel structure to install-claude-code.sh. T01 hooks
  the same writer at the parallel position in each.
- **`scripts/lifecycle/run-update.sh`** exists; T01 does not modify it
  (T02 does). Reads at planning time only to confirm the driver invokes
  `install-claude-code.sh --force` to do the upgrade — this is the
  invocation point at which the install-side hook fires.
- No `scripts/lifecycle/write-rollback-marker.sh` exists at plan-authoring
  time (Plan-Time Discipline Rule 6 — path-collision check confirmed
  absent).
- No `.orchestrator/.previous-version` is on disk in any consumer project
  (it is by design a per-install sidecar; first run of a post-T01
  installer creates it).
- No `.orchestrator/.rollback/` dir exists in any consumer project.

## Description

Author the rollback-marker contract that FR-12 requires. The contract has
three surfaces:

1. **Schema** of `.orchestrator/.previous-version` — five fields capturing
   prior version metadata (D005 binding).
2. **Snapshot** of the prior `installed-files.txt` at `.orchestrator/.rollback/manifest-<prior-version>.txt`
   — this is the load-bearing artifact that T02's `--rollback` driver
   replays at restore time. Snapshotting at upgrade-time (rather than
   reconstructing at rollback-time from git history) is constitutionally
   required because the rollback path must succeed even when the source
   repo is unreachable (e.g. `update_source: npm` upgrades against a
   published tarball with no local clone).
3. **Writer** as a single-script-file `scripts/lifecycle/write-rollback-marker.sh`
   invoked from each of the three installers (claude-code / codex /
   cursor) at a deterministic point in the install pipeline.

The writer is **idempotent**: re-invocation overwrites both the marker
and the snapshot in place. First-install (greenfield, no prior install
on disk) is a no-op — the marker is not written because there is no
prior state to preserve. The writer detects greenfield via the absence
of an existing `installed-files.txt` at invocation time.

Symlink-mode handling: when the prior install is symlink-mode (every
line in the prior `installed-files.txt` carries `\tmode:symlink`), the
writer still snapshots the manifest and writes the marker with
`prior_install_mode=symlink`. T02's `--rollback` driver consults this
field to refuse the rollback per #Q-G8 — the marker exists for
diagnostic completeness but is not actionable. Mixed-mode prior installs
(some entries `mode:copy`, some `mode:symlink`) are recorded as
`prior_install_mode=mixed`; T02 also refuses these per the spec
amendment's symlink-mode-anywhere-blocks-rollback semantics (the more
restrictive interpretation; reasoning: any symlink in the runtime tree
makes byte-equivalent revert undefined).

## Steps

1. **Author `scripts/lifecycle/write-rollback-marker.sh`** — single-script-file
   shape, bash 3.2 + POSIX-sh, ~80–120 lines. The driver contract:

   **Invocation**:
   ```
   bash scripts/lifecycle/write-rollback-marker.sh \
     --project-dir <PATH> \
     [--source-version <X.Y.Z>] \
     [--source-commit-sha <SHA>] \
     [--dry-run]
   ```

   **Behavior** (in order):
   1. Resolve `PROJECT_DIR` (required), abort with FAIL on missing.
   2. Greenfield check: if `<PROJECT_DIR>/.orchestrator/installed-files.txt`
      does NOT exist, emit `SKIP: greenfield install — no prior state to
      preserve` to stdout, exit 0. (This is the no-op branch.)
   3. Read prior version from `<PROJECT_DIR>/.orchestrator/install-meta.txt`
      `version=` line. If absent or empty, set to `unknown`.
   4. Read prior commit SHA from the same file's `commit_sha=` line. If
      absent or empty, set to empty (explicit empty).
   5. Read prior install mode by inspecting `installed-files.txt`:
      - All lines `\tmode:copy` → `copy`.
      - All lines `\tmode:symlink` → `symlink`.
      - Mixed → `mixed`.
      - File present but malformed (no mode markers, e.g. pre-M035 P01
        format) → `unknown`.
   6. Derive `prior_manifest_path=.orchestrator/.rollback/manifest-<prior_version>.txt`
      using the version from step 3. (When step 3 returned `unknown`,
      use literal string `unknown` in the path.)
   7. Snapshot: copy `installed-files.txt` byte-for-byte to the path
      derived in step 6. Create the `.orchestrator/.rollback/` directory
      if absent.
   8. Write the marker file at `<PROJECT_DIR>/.orchestrator/.previous-version`
      with the verbatim shape:
      ```
      prior_version=<from step 3>
      prior_commit_sha=<from step 4>
      prior_manifest_path=<from step 6>
      prior_install_mode=<from step 5>
      rolled_at=
      ```
      (`rolled_at=` is empty until T02's rollback runs.)
   9. Emit `wrote=<PROJECT_DIR>/.orchestrator/.previous-version` to stdout.
   10. Emit `snapshotted=<PROJECT_DIR>/<prior_manifest_path>` to stdout.
   11. Exit 0.

   **Dry-run** (`--dry-run`): emit `would_write=` and `would_snapshot=`
   lines instead of writing. Useful for the install-script integration
   (the install-script's `DRY_RUN=1` path) and for T05 acceptance tests.

   **Exit codes**:
   - `0` success or skip-greenfield
   - `1` PROJECT_DIR validation failed; or installed-files.txt unreadable
   - `2` invalid arguments

   The script MUST honor the AD-19 single-script-file shape — no
   `$(... | ...)`, no plain subshells, no compound chains. Use
   intermediate variables and `if` blocks for any compound logic.
   Reading lines from `installed-files.txt` uses a `while IFS= read -r
   line; do ...; done < "$file"` form (single-input redirect, no
   process substitution).

2. **Hook into `packaging/install/install-claude-code.sh`** — add the
   following block IMMEDIATELY AFTER the existing Stage 4.4 (install-meta.txt
   write, currently at lines 511–544) and IMMEDIATELY BEFORE Stage 4.4.5
   (managed .gitignore, currently lines 546–562):

   ```bash
   # --- 4.4.6 Rollback marker (M035 P05 T01, FR-12 / D005) ---
   # Snapshots the prior install's manifest and writes the
   # .orchestrator/.previous-version marker BEFORE the new manifest is
   # staged at Stage 4.5. Greenfield installs (no prior installed-files.txt)
   # are a no-op via the writer's internal greenfield check.
   #
   # The writer is idempotent: re-installs at the same version overwrite
   # both the marker and the snapshot in place.
   if [ "$DRY_RUN" = "1" ]; then
     bash "$REPO_ROOT/scripts/lifecycle/write-rollback-marker.sh" \
       --project-dir "$PROJECT_DIR" --dry-run
     _wrm_rc=$?
   else
     bash "$REPO_ROOT/scripts/lifecycle/write-rollback-marker.sh" \
       --project-dir "$PROJECT_DIR"
     _wrm_rc=$?
   fi
   if [ "$_wrm_rc" -ne 0 ]; then
     echo "FAIL: write-rollback-marker.sh exited $_wrm_rc" >&2
     exit "$_wrm_rc"
   fi
   ```

   The `--uninstall` and `--repair` paths short-circuit before this stage
   per the existing convention (M035 P00 T02 emit-managed-gitignore
   precedent at lines 552–557). No additional gating needed.

3. **Hook into `packaging/install/install-codex.sh`** — locate the
   parallel position (immediately after install-meta.txt write,
   immediately before managed-gitignore call). Insert the same block
   verbatim from step 2.

4. **Hook into `packaging/install/install-cursor.sh`** — same as step 3.

5. **Append D005 to [`.orchestrator/DECISIONS.md`](../../../../../decisions.md)** — author the row using
   the existing 7-column-table convention (NOT the new heading-shape;
   T01 follows the parent installer's existing convention. The heading-shape
   migration is a separate paper-cut per P02 caveats). Append:

   ```
   | D005 | M035/P05 | rollback-marker schema | `.orchestrator/.previous-version` is a structured `key=value` sidecar with five fields (`prior_version`, `prior_commit_sha`, `prior_manifest_path`, `prior_install_mode`, `rolled_at`); the prior `installed-files.txt` is snapshotted to `.orchestrator/.rollback/manifest-<prior-version>.txt` for replay. | snapshot-at-upgrade-time decouples rollback from source-repo reachability (works under `update_source: npm` with no local clone). | bound by FR-12 / SC-12 / #Q-G8 | 2026-05-08 |
   ```

   (Adjust the column shape to match the existing DECISIONS.md table
   header at append time — read the file first to confirm column count.)

6. **Author the verifier** `tools/verify/m035-p05-rollback-marker-shape.sh`.
   Single-script-file shape, AD-19, ~50 lines. Sources `scripts/lib/errors.sh`
   for `emit_result`. Stages a temp fixture under `/tmp/m035-p05-t01-marker-fixture-$$/`
   (mktemp), runs `write-rollback-marker.sh --dry-run` against three
   scenarios:

   1. **Greenfield**: empty `<fixture>/.orchestrator/`. Assert stdout
      contains `SKIP: greenfield`, exit 0, no `.previous-version` written.
   2. **Copy-mode prior**: `<fixture>/.orchestrator/installed-files.txt`
      with two `\tmode:copy` lines + `<fixture>/.orchestrator/install-meta.txt`
      with `version=0.9.2` and `commit_sha=abc123`. Assert stdout contains
      `would_write=`, the would-be marker content (in --dry-run echo the
      content as `would_content_line=...` lines for verifiability) shows
      `prior_install_mode=copy`, `prior_version=0.9.2`,
      `prior_commit_sha=abc123`, `prior_manifest_path=.orchestrator/.rollback/manifest-0.9.2.txt`.
   3. **Symlink-mode prior**: same fixture but with `\tmode:symlink` lines.
      Assert `prior_install_mode=symlink`.

   Then run the writer in non-dry-run mode against scenario 2's fixture
   and assert:
   - `<fixture>/.orchestrator/.previous-version` exists with all five
     fields.
   - `<fixture>/.orchestrator/.rollback/manifest-0.9.2.txt` exists and
     is byte-identical to the prior `installed-files.txt`.

   Emit `BATTERY: pass=N fail=0` summary. Cleanup fixture on exit.

7. **Author the verifier** `tools/verify/m035-p05-rollback-snapshot-presence.sh`.
   Lighter-weight verifier (~30 lines): runs the writer against a
   minimal copy-mode fixture and asserts the snapshot file exists with
   non-zero size and matches a SHA-256 hash of the prior
   `installed-files.txt`. Three assertions; emit `BATTERY: pass=3 fail=0`.

## Must-Haves

- `scripts/lifecycle/write-rollback-marker.sh` exists, executable,
  ~80+ lines, contains `prior_version=`, `prior_install_mode=`,
  `prior_manifest_path=`, `--dry-run`, greenfield check.
- `packaging/install/install-claude-code.sh` modified — contains the
  literal token `write-rollback-marker.sh` invocation block.
- `packaging/install/install-codex.sh` modified — same.
- `packaging/install/install-cursor.sh` modified — same.
- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) modified — contains `D005` row referencing
  M035/P05 + `.previous-version`.
- `tools/verify/m035-p05-rollback-marker-shape.sh` exists, runs against a
  staged fixture, emits `BATTERY: pass=N fail=0`.
- `tools/verify/m035-p05-rollback-snapshot-presence.sh` exists, emits
  `BATTERY: pass=N fail=0`.

## Verification

```bash
bash tools/verify/m035-p05-rollback-marker-shape.sh
```

```bash
bash tools/verify/m035-p05-rollback-snapshot-presence.sh
```

```bash
bash tests/installer-acceptance/m035-collision-exit-status.sh
```

```bash
bash tools/verify/m029-p01-headline-shape.sh
```

## Inputs

### From Previous Tasks

None — T01 is a leaf task within P05 with no upstream P05 dependencies.

### From Disk (Pre-existing)

- `packaging/install/install-claude-code.sh` (lines 511–562 are the
  insertion zone) — Stage 4.4 install-meta.txt write at lines 511–544;
  Stage 4.4.5 managed-gitignore at lines 546–562. T01 inserts a new
  Stage 4.4.6 between them.
- `packaging/install/install-codex.sh` — parallel structure; locate the
  install-meta.txt write block via `grep -n install-meta.txt` and the
  managed-gitignore block via `grep -n emit-managed-gitignore`.
- `packaging/install/install-cursor.sh` — same.
- `scripts/lib/errors.sh` — sourceable lib exporting `emit_result`,
  `RESULT_OK`, `RESULT_FAIL`. Used by every verifier.
- `scripts/util/run-probe.sh` — staged-throwaway-probe wrapper. T01
  verifier does NOT use this (verifiers are repo-resident; AD-19 says
  invoke `bash <path>` directly).
- `.orchestrator/installed-files.txt` schema (M035 P01 / FR-1) — flat
  list, one entry per line, format `<relative-path>\tmode:<copy|symlink>`.
  Read by step 1.5 of the writer to determine `prior_install_mode`.
- `.orchestrator/install-meta.txt` schema — five fields: `source_root=`,
  `runtime=`, `installed_at=`, `commit_sha=`, `version=`. Read by step 3
  + step 4 of the writer.

## Constraints

- **AD-19 single-script-file shape** — every check command is `bash
  tools/verify/m035-p05-*.sh` or `bash scripts/lifecycle/write-rollback-marker.sh`.
  No inline compound chains; no `$(... | ...)`; no plain subshells.
- **Bash 3.2 + POSIX-sh in the writer and the install-script hooks** —
  CON-2. The writer must run on macOS bash 3.2 unmodified.
- **CON-7 (M025 reversibility-gate preserved)** — T01 reads
  `installed-files.txt` but does NOT modify it. The writer's
  responsibility is purely additive: snapshot + marker. The new
  install's manifest write at Stage 4.5 (existing M025 behavior)
  proceeds unchanged.
- **#Q-G8 binding** — `prior_install_mode=symlink` and `mixed` are
  written but T01 does NOT enforce the rollback refusal. Refusal is
  T02's job. T01's contract: capture enough state for T02 to make the
  decision.
- **Idempotency** — re-invocation overwrites the marker and the
  snapshot in place. Re-running the writer at the same version is
  a no-op functionally (snapshot stays byte-identical).
- **Greenfield no-op** — first install on a project with no prior
  `installed-files.txt` MUST NOT write the marker; the writer's
  greenfield-check branch handles this.
- **Plan-Time Discipline Rule 6 (Path-collision)** — `ls -la` performed
  against every `create` path. All absent at plan-authoring time. New
  files all carry `m035-p05-` slug per the milestone-prefix
  convention.

## Expected Output

Stdout from `bash tools/verify/m035-p05-rollback-marker-shape.sh`:

```
PASS: greenfield no-op
PASS: copy-mode prior writes correct marker
PASS: symlink-mode prior writes correct marker (mode=symlink)
PASS: snapshot is byte-identical to source manifest
PASS: marker file contains all five required fields
PASS: --dry-run emits would_write= and would_snapshot=
BATTERY: pass=6 fail=0
```

Stdout from `bash tools/verify/m035-p05-rollback-snapshot-presence.sh`:

```
PASS: snapshot file written
PASS: snapshot file is non-empty
PASS: snapshot SHA-256 matches source installed-files.txt SHA-256
BATTERY: pass=3 fail=0
```

Stdout from a successful `bash scripts/lifecycle/write-rollback-marker.sh
--project-dir <fixture>` against a copy-mode fixture:

```
wrote=<fixture>/.orchestrator/.previous-version
snapshotted=<fixture>/.orchestrator/.rollback/manifest-0.9.2.txt
```

## State Context

- **Current State**: executing
- **Milestone**: M035
- **Phase**: P05
- **Task**: T01-rollback-marker-contract
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **AD-19 single-script-file shape** — every check command is `bash
  tools/verify/m035-p05-*.sh` or `bash scripts/lifecycle/write-rollback-marker.sh`.
  No inline compound chains; no `$(... | ...)`; no plain subshells.
- **Bash 3.2 + POSIX-sh in the writer and the install-script hooks** —
  CON-2. The writer must run on macOS bash 3.2 unmodified.
- **CON-7 (M025 reversibility-gate preserved)** — T01 reads
  `installed-files.txt` but does NOT modify it. The writer's
  responsibility is purely additive: snapshot + marker. The new
  install's manifest write at Stage 4.5 (existing M025 behavior)
  proceeds unchanged.
- **#Q-G8 binding** — `prior_install_mode=symlink` and `mixed` are
  written but T01 does NOT enforce the rollback refusal. Refusal is
  T02's job. T01's contract: capture enough state for T02 to make the
  decision.
- **Idempotency** — re-invocation overwrites the marker and the
  snapshot in place. Re-running the writer at the same version is
  a no-op functionally (snapshot stays byte-identical).
- **Greenfield no-op** — first install on a project with no prior
  `installed-files.txt` MUST NOT write the marker; the writer's
  greenfield-check branch handles this.
- **Plan-Time Discipline Rule 6 (Path-collision)** — `ls -la` performed
  against every `create` path. All absent at plan-authoring time. New
  files all carry `m035-p05-` slug per the milestone-prefix
  convention.

### Acceptance Criteria

- `scripts/lifecycle/write-rollback-marker.sh` exists, executable,
  ~80+ lines, contains `prior_version=`, `prior_install_mode=`,
  `prior_manifest_path=`, `--dry-run`, greenfield check.
- `packaging/install/install-claude-code.sh` modified — contains the
  literal token `write-rollback-marker.sh` invocation block.
- `packaging/install/install-codex.sh` modified — same.
- `packaging/install/install-cursor.sh` modified — same.
- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) modified — contains `D005` row referencing
  M035/P05 + `.previous-version`.
- `tools/verify/m035-p05-rollback-marker-shape.sh` exists, runs against a
  staged fixture, emits `BATTERY: pass=N fail=0`.
- `tools/verify/m035-p05-rollback-snapshot-presence.sh` exists, emits
  `BATTERY: pass=N fail=0`.

### Files To Touch

- `scripts/lifecycle/write-rollback-marker.sh` (create)
- `scripts/lifecycle/run-update.sh` (modify)
- `packaging/install/install-claude-code.sh` (modify)
- `packaging/install/install-codex.sh` (modify)
- `packaging/install/install-cursor.sh` (modify)
- `commands/update.md` (modify)
- `.github/workflows/release.yml` (modify)
- `references/installation.md` (modify)
- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) (modify — D004 sigstore-keyless, D005 rollback-marker-schema)
- `tools/verify/m035-p05-rollback-marker-shape.sh` (create)
- `tools/verify/m035-p05-rollback-snapshot-presence.sh` (create)
- `tools/verify/m035-p05-rollback-driver-shape.sh` (create)
- `tools/verify/m035-p05-update-skill-doc-shape.sh` (create)
- `tools/verify/m035-p05-release-workflow-signing-shape.sh` (create)
- `tools/verify/m035-p05-signature-verification.sh` (create)
- `tools/verify/m035-p05-installation-doc-verifying-integrity.sh` (create)
- `tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh` (create)
- `tests/m035-acceptance/fixtures/m035-p05-release-fixture/install.sh` (create)
- `tests/m035-acceptance/fixtures/m035-p05-release-fixture/install.sh.sig` (create)
- `tests/m035-acceptance/fixtures/m035-p05-release-fixture/install.sh.pem` (create)
- `tests/m035-acceptance/fixtures/m035-p05-release-fixture/SHA256SUMS` (create)
- `tools/verify/m035-p05-phase-suite.sh` (create)

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