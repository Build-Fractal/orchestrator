---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T04-scope-guard-and-battery (Phase P04, Milestone M031)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-978 | ~400 | required |
| Upstream Context | 980-1162 | ~10900 | required |
| Task Plan | 1164-1541 | ~6200 | required |
| State Context | 1543-1549 | ~100 | required |
| First-Turn Completeness | 1551-1614 | ~1100 | required |
| **Total** | | **~29500** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 713
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
hit_count: 713
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
hit_count: 713
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
hit_count: 713
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
hit_count: 624
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
hit_count: 624
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
hit_count: 624
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
hit_count: 713
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
hit_count: 624
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
hit_count: 624
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
hit_count: 624
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
hit_count: 713
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
hit_count: 713
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
hit_count: 713
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
hit_count: 624
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
hit_count: 624
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
hit_count: 624
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
hit_count: 713
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
hit_count: 624
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
hit_count: 624
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
hit_count: 713
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
hit_count: 713
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
hit_count: 624
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
hit_count: 624
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
hit_count: 624
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
hit_count: 279
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
hit_count: 279
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
hit_count: 279
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
hit_count: 289
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
hit_count: 289
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
hit_count: 279
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

<!-- All Check commands use the single-script-file shape per AD-19.
     Project-owned slug-bearing verifiers live under tools/verify/ per
     [M032](../../../../../milestones/M032/index.md) Finding A. Verifier scripts are co-authored alongside their
     corresponding artifact within the SAME task (plan-time discipline
     rule 2). Namespacing: `m031-p04-*` prefix avoids collision with
     the M031/P01..P03 verifiers + the [M030](../../../../../milestones/M030/index.md) verifiers in the shared
     tools/verify/ tree. The check-must-haves invocation is always
     given the phase DIRECTORY (not a specific plan filename) per the
     P03 plan-time defect note in continue.md. -->

### Truths

- `commands/evaluate.md` post-fix contains zero matches for the pre-M024 Tier A "no orchestrator overhead" / "Do NOT create any orchestrator directory" phrasings (FR-14 / SC-9). The canonical Tier A description "single dispatch with knowledge + compression via the Quick profile" is present.
  - Check: `bash tools/verify/m031-p04-evaluate-md-drift-shape.sh`

- `references/tier-definitions.md` post-fix matches `commands/evaluate.md` and explicitly states that `.orchestrator/` (config, knowledge, integrations) is always present and that only `.orchestrator/milestones/M###/` scaffolding is conditional (FR-15 / SC-9). Zero matches for the pre-M024 "no orchestrator overhead" string.
  - Check: `bash tools/verify/m031-p04-tier-definitions-drift-shape.sh`

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


### P02 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P02"
parent: "M031"
milestone: "M031"
provides:
  - "scripts/intake/shape-detect.sh extended with tier_a_plus verdict (FR-6,30-80 word zero-structural-marker band),scripts/intake/paragraph-classify.sh annotated with tier_a_plus literal token,tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md (AD-16 normative grounding citing 2 historical unit_close records),tests/m031-acceptance/fixtures/tier-a-plus-input.txt (62-word fixture paraphrased from M031/P01/T01),tests/m031-acceptance/test-tier-a-plus-classifier.sh (SC-5 acceptance test),4 m031-p02 shape verifiers under tools/verify/,scripts/intake/lib/task-slug.sh sourceable derive_task_slug function (AD-10 40-char base slug + 4-char SHA-1 collision suffix + untitled empty-input fallback),templates/dispatch-role-research.md (96 lines prescriptive read-only research-role contract producing research.md with Findings Open Questions Recommended Approach),templates/dispatch-role-plan.md (93 lines prescriptive plan-authoring contract producing PLAN.md with Steps Verification Inputs Files Likely Touched),templates/dispatch-role-build.md (93 lines prescriptive executor contract reading plan.md and running Verification inline with no implicit retry),tools/verify/m031-p02-task-slug-shape.sh (10 checks AD-19 single-script Truth Check),tools/verify/m031-p02-role-templates-shape.sh (21 checks AD-19 single-script Truth Check),scripts/intake/lib/tier-a-plus-prompt.sh sourceable + directly-invokable AD-7 + AD-20 Tier A+ approval prompt helper (273 lines bash 3.2 compatible -- _tap_read_summary_lines _tap_resume_marker _tap_emit_audit _tap_emit_prompt_body tier_a_plus_prompt + direct-invocation dispatcher),tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh (203 lines SC-16 acceptance test exercising all seven AD-20 UX-protocol clauses),tools/verify/m031-p02-prompt-shape.sh (16 checks AD-19 single-script Truth Check for the helper),tools/verify/m031-p02-test-tier-a-plus-prompt-ux-shape.sh (12 checks AD-19 single-script Truth Check for the SC-16 test),route-to-dispatch.sh extended additively with --verdict tier_a_plus mode (research/approval/plan/build chain via Quick-profile build-context.sh + role templates),unit_close JSONL schema additions tier_a_plus_role and aborted (additive optional fields),--dispatch-stub seam for SC-6 acceptance test,SC-6 end-to-end acceptance test tests/m031-acceptance/test-tier-a-plus-flow.sh,m031-p02-router-shape.sh + m031-p02-test-tier-a-plus-flow-shape.sh shape verifiers under tools/verify/,tools/verify/m031-p02-phase-suite.sh,tools/verify/m031-p02-scope-guard.sh,11-gate phase-suite straight-line aggregator,SC-12 scope-guard with dual-prefix permissive carve-out (.orchestrator/observability + .orchestrator/tier-a-plus),MEM hit_count carve-out inherited verbatim from P01"
requires:
  - "P01"
affects:
  - "P03,P04"
key_files:
  - "scripts/intake/shape-detect.sh,scripts/intake/paragraph-classify.sh,tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md,tests/m031-acceptance/fixtures/tier-a-plus-input.txt,tests/m031-acceptance/test-tier-a-plus-classifier.sh,tools/verify/m031-p02-classifier-extension-shape.sh,tools/verify/m031-p02-fixture-provenance-shape.sh,tools/verify/m031-p02-tier-a-plus-input-shape.sh,tools/verify/m031-p02-test-tier-a-plus-classifier-shape.sh,scripts/intake/lib/task-slug.sh,templates/dispatch-role-research.md,templates/dispatch-role-plan.md,templates/dispatch-role-build.md,tools/verify/m031-p02-task-slug-shape.sh,tools/verify/m031-p02-role-templates-shape.sh,scripts/intake/lib/tier-a-plus-prompt.sh,tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh,tools/verify/m031-p02-prompt-shape.sh,tools/verify/m031-p02-test-tier-a-plus-prompt-ux-shape.sh,scripts/intake/route-to-dispatch.sh,tests/m031-acceptance/test-tier-a-plus-flow.sh,tools/verify/m031-p02-router-shape.sh,tools/verify/m031-p02-test-tier-a-plus-flow-shape.sh,scripts/dispatch/build-context.sh,tools/verify/m031-p02-phase-suite.sh,tools/verify/m031-p02-scope-guard.sh"
key_decisions:
  - "Tier A+ heuristic boundary chosen as 30-80 words AND zero structural markers (^## heading / Given-When-Then triple / ^- FR- bullet) — answers P02 open question A1; new branch inserted AFTER fragment branch and BEFORE idea branch in shape-detect.sh so it claims the uninstantiated middle band without disturbing the fragment >=81 or words<=10 idea boundaries; paragraph-classify.sh extended via comment-only annotation (rationale_paragraph emitted output stays byte-equal pre/post — router consumes shape-detect.sh's verdict directly and skips paragraph-classify.sh on the Tier A+ branch); FIXTURE-PROVENANCE.md cites both M031/P01/T01 and M030/P07/T03 unit_close records for cross-record breadth (heuristic generalizes beyond a single citation); SC-5 acceptance test uses RESULT: SC-5 pass envelope per the M031 P01 SC-* convention; shape verifiers use SUMMARY: <name> pass=N fail=M envelope per the M031 P01 convention,AD-10 collision discipline implemented as conservative bare-base-slug-on-no-collision + 4-char SHA-1 suffix only on real collision against an unrelated prior research.md (preserves human-readable slugs for AD-20 prompt UX),empty-input fallback chosen as deterministic literal untitled rather than SHA-1 of empty string (keeps the slug human-readable; collision discipline still applies if untitled/research.md exists),hash availability shasum -a 1 preferred with openssl sha1 fallback (POSIX-portable across macOS and Linux dispatch hosts),sourceability discipline (no top-level side-effects when sourced; private helpers prefixed _task_slug_*),new schema entry type: dispatch-role reserved by M031 P02 (future role-template additions MUST be additive not parallel),role-template body avoids D020 prohibited scaffold-placeholder bracket-TODO byte pattern via paraphrase,AD-19 single-script-file shape preserved across both new verifiers (no inline compound bash no process substitution no plain subshells in verifier bodies),AD-20 mechanical contract implemented with strict BEGIN/END PROMPT BODY sentinels around _tap_emit_prompt_body so the prohibited token assertions (null brace scaffold-placeholder bracket-TODO) gate against the operator-facing prose region only -- not against helper-internal logic such as 2>/dev/null shell-substitution braces or comment text mentioning the prohibited tokens by name (mirrors the M031 P01 inverted-polarity surface-region convention),A4 open question (session-ID sidecar mechanism) answered: a single-line .session-id file under <task-slug>/ holding the session ID; helper reads it and flips the [fresh research from this session] vs [resume from prior research] marker on match/mismatch (T04 router writes the sidecar on first session entry),tier_a_plus_prompt_summary_lines resolution path -- direct YAML grep against .orchestrator/config.yml then templates/orchestrator-config-default.yml then hardcoded P00 default 8 (read-config.sh VALID_KEYS list does not yet whitelist this knob; the equivalent permitted by the task-plan note keeps T03 scope bounded -- P04 or M032 may extend VALID_KEYS as a separate single-line amendment),--no-prompt-mode y|n|c test-only flag added to bypass the read -r -n 1 -t 60 interactive path so the SC-16 test exercises every UX clause deterministically without driving stdin (production default stays the interactive read path),60-second read timeout with empty/EOF/timeout all collapsing to the c cancel default per AD-20 clause 3 default-on-no-answer requirement,SC-16 test constructs prohibited byte patterns at runtime via printf octal escapes (173 175 133) so the test source itself does not embed the literal forbidden bytes -- same source-side discipline the helper applies to its own prompt body,helper writes the audit line research: <path> to stderr in BOTH --yes and interactive modes so callers grep stderr regardless of mode (path emission discipline AD-20 clause 7),AD-19 single-script-file Truth Check shape preserved across both new verifiers (no inline compound bash no process substitution no plain subshells in verifier bodies),A2 router CLI surface: --verdict tier_a_plus --task DESC --yes --session-id ID --scratch-root DIR --dispatch-stub SCRIPT (--proposal/--verdict mutually exclusive),A3 stub-vs-real dispatch: --dispatch-stub flag + ORCH_DISPATCH_STUB env var (one shell argument; receives role/slug/desc/slug-dir positionals); SC-6 ships canned stub; production unset path invokes build-context.sh --profile=quick + role-template + AD-11 sidecar and stops at agent-runtime handoff (MEM018),A5 scratch prefix: .orchestrator/tier-a-plus/SLUG/ (matches T03 prompt helper); --scratch-root override for tests; ORCH_TIER_A_PLUS_LOG override for unit_close JSONL log path,docstring discipline: paraphrase forbidden command names so the router-shape grep stays strict per task plan step 6,phase-suite gate ordering follows T01->T05 dependency order with scope-guard last,added .orchestrator/tier-a-plus/ as second permissive prefix alongside .orchestrator/observability/,MEM hit_count-only carve-out function copied verbatim from P01 (project-wide convention now),no edits to T01-T04 deliverables per plan-time discipline (3 pre-existing key-link FAILs forwarded for P02 close-out remediation)"
patterns_established:
  - "additive verdict-enum extension on a closed M024 surface (insert new branch BEFORE the fallback default and AFTER the higher-priority sibling so fallback semantics stay byte-equal); comment-only annotation pattern for satisfying literal-token verifier requirements without changing emitted output (paragraph-classify.sh); AD-16 normative grounding pattern (FIXTURE-PROVENANCE.md cites historical unit_close records by M###/P##/T## provenance; downstream verifier requires both file existence and provenance pattern); fixture-paraphrase-from-citation discipline (tier-a-plus-input.txt body is a paraphrase of the cited record's task description,keeping the heuristic empirically grounded),sourceable shell library with private function prefix discipline (_task_slug_* helpers + public derive_task_slug entry),deterministic-by-construction slug derivation (5-step pipeline lower -> ws-hyphen -> strip -> collapse -> truncate) with optional collision-only suffix,role-template trio sibling-symmetric with existing dispatch-prompt.md and dispatch-result.md siblings (same templates/ directory same frontmatter shape),per-role required-literal-substring contract enforced by single-script Truth Check verifier (each role template asserts 4 role-specific literals plus 2 frontmatter literals),collision-check rooted at project-relative .orchestrator/tier-a-plus/<base-slug>/research.md (caller-cwd-independent via BASH_SOURCE-driven project-root resolution),bracketed prompt-body sentinel pattern (BEGIN PROMPT BODY / END PROMPT BODY) for source-side enforcement of operator-facing prose token discipline (verifier extracts the region with awk and asserts the prohibited tokens do not appear inside),test-only --no-prompt-mode bypass for interactive UX surfaces (test exercises every UX clause deterministically without driving stdin; production keeps the interactive read path),direct-YAML-grep config knob resolution as a permitted equivalent when the canonical reader VALID_KEYS list lags behind a new knob (4-layer precedence preserved: env-var implicit / .orchestrator/config.yml / templates default / hardcoded P00 default),session-ID sidecar pattern under <task-slug>/.session-id (single-line file holding session ID; presence + match flips a UX marker; non-state-machine scratch artifact under .orchestrator/tier-a-plus/ permissive prefix),runtime construction of prohibited byte patterns via printf octal escapes for D020/CON-7 self-application (test/verifier source itself does not embed the literal forbidden bytes),additive --verdict CLI mode on legacy positional router (preserves existing --proposal path byte-equal),per-role dispatch wrapper with stub-vs-real bifurcation,inline JSONL emitter for new schema additions (no new emitter introduced; Bash 3.2 string concatenation per existing convention),paraphrased-forbidden-token discipline (router-shape verifier grep stays strict by paraphrasing CON-4 command names in source docstrings),sandbox SC-6 with --dispatch-stub + --scratch-root + ORCH_TIER_A_PLUS_LOG env override (test exercises router shape without touching real .orchestrator/ tree),phase-suite straight-line N-gate aggregation repeats across milestones (P01:9 / P02:11),SC-12 scope-guard with dual-prefix permissive carve-out (observability + per-flow scratch),MEM hit_count-only carve-out invariantly inherited verbatim across phases"
drill_down_paths:
  - "[.orchestrator/milestones/M031/phases/P02/tasks/T01-classifier-and-provenance-SUMMARY.md](../../../../../milestones/M031/phases/P02/tasks/T01-classifier-and-provenance-SUMMARY.md), [.orchestrator/milestones/M031/phases/P02/tasks/T02-slug-and-role-templates-SUMMARY.md](../../../../../milestones/M031/phases/P02/tasks/T02-slug-and-role-templates-SUMMARY.md), [.orchestrator/milestones/M031/phases/P02/tasks/T03-prompt-and-prompt-ux-test-SUMMARY.md](../../../../../milestones/M031/phases/P02/tasks/T03-prompt-and-prompt-ux-test-SUMMARY.md), [.orchestrator/milestones/M031/phases/P02/tasks/T04-router-and-flow-test-SUMMARY.md](../../../../../milestones/M031/phases/P02/tasks/T04-router-and-flow-test-SUMMARY.md), [.orchestrator/milestones/M031/phases/P02/tasks/T05-phase-suite-and-scope-guard-SUMMARY.md](../../../../../milestones/M031/phases/P02/tasks/T05-phase-suite-and-scope-guard-SUMMARY.md)"
duration: "495m"
verification_result: "pass"
completed_at: "2026-05-01T19:41:00Z"
observability_surfaces:
  - "none"
---

M031/P02 added the Tier A+ middle flow (research → approval → plan → build) end-to-end:

- **T01 (classifier + provenance)** [`92cd6eb`] — extended `scripts/intake/shape-detect.sh` with the `tier_a_plus` verdict for inputs in the 30–80 word band with no structural markers (`^##` heading / Given-When-Then / `^- FR-` bullet). Added `tests/m031-acceptance/fixtures/{FIXTURE-PROVENANCE.md,tier-a-plus-input.txt}` (AD-16 normative grounding citing M031/P01/T01 and M030/P07/T03 unit_close records). SC-5 acceptance test green. Existing 5 verdicts (`idea`, `paragraph`, `fragment`, `spec`, `empty`) byte-equal.
- **T02 (slug lib + role templates)** [`af7a88d`] — `scripts/intake/lib/task-slug.sh` exposing `derive_task_slug` (5-step base + optional 4-char SHA-1 collision suffix + `untitled` empty-input fallback). Three sibling role templates `templates/dispatch-role-{research,plan,build}.md` (each ≥93 lines) declaring `type: dispatch-role`. Bash 3.2 / MEM001 compliant.
- **T03 (approval prompt + SC-16)** [`bd5a742`] — `scripts/intake/lib/tier-a-plus-prompt.sh` (273 lines, AD-7 + AD-20). CLI: `--research-path`, `--task-slug`, `--yes`, `--session-id`, `--no-prompt-mode y|n|c`. Exit codes 0/1/2 (proceed/re-research/abort). All 7 AD-20 clauses implemented; 60-second `read` timeout collapses to abort default. SC-16 prompt-UX test green. Open question A4 resolved: session-ID sidecar = single-line `<task-slug>/.session-id`.
- **T04 (router amend + SC-6)** [`b91f202`] — `scripts/intake/route-to-dispatch.sh` extended additively with `--verdict tier_a_plus` mode. Chains research → approval → plan → build via `build-context.sh --profile=quick` + role templates. Inline JSONL emitter writes one `unit_close` per role with new `tier_a_plus_role` + `aborted` fields (additive optional). SC-6 acceptance test uses `--dispatch-stub` + `--scratch-root` + `ORCH_TIER_A_PLUS_LOG` for hermetic execution. Legacy `--proposal` path byte-equal. Open questions A2 / A3 / A5 resolved.
- **T05 (phase-suite + SC-12 scope-guard)** [`58e6a2f` + `7624397`] — `tools/verify/m031-p02-phase-suite.sh` (11-gate straight-line aggregator, T01→T05 dependency order, no short-circuit) + `tools/verify/m031-p02-scope-guard.sh` (dual-prefix permissive carve-out: `.orchestrator/observability/` + `.orchestrator/tier-a-plus/`; MEM `hit_count`-only carve-out inherited verbatim from P01). Mid-task remediation (`7624397`) added a `# Key links` doc-comment block to `route-to-dispatch.sh` listing the three literal role-template filenames so the phase-plan key-link must-haves resolve (mirrors the P01 build-context.sh remediation pattern).

**Phase-level verification (Tier 1 + Tier 3)**:
- `check-must-haves.sh` → 97 PASS / 0 FAIL.
- `check-boundary-map.sh` → SKIP (no produce items declared in plan).
- `m031-p02-phase-suite.sh` → `pass=11 fail=0`.
- `m031-p02-scope-guard.sh` → `pass=31 fail=0 block_list_violations=0 mem_hitcount_carveouts=31`.
- 3 acceptance tests green (SC-5 classifier, SC-16 prompt-UX, SC-6 flow).
- M024 regression: `tests/test-paragraph-intake.sh` 3/3 dispatch-path tests pass (3 specify-path failures pre-existing T01 classifier ripple, unrelated to P02).

**Open questions resolved this phase**: A1 (boundary band 30–80 words + zero structural markers, T01); A2 (router CLI surface, T04); A3 (SC-6 stub-vs-real seam, T04); A4 (session-ID sidecar, T03); A5 (`.orchestrator/tier-a-plus/` allow-list prefix, T04). Zero unresolved.

**Forwarded to P03+**: extending `read-config.sh` `VALID_KEYS` to whitelist `tier_a_plus_prompt_summary_lines` (T03 helper currently uses direct YAML grep with hardcoded P00 default 8 — equivalent permitted by task plan); phase-level housekeeping commit to clear pre-existing working-tree drift (M036, CLAUDE.md, spec-033, references/RUNTIME-ASSUMPTIONS.md, scripts/dispatch/build-context.sh, templates/orchestrator-config-default.yml, tools/verify/p00-phase-suite.sh) carried forward from prior sessions.


### P03 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P03"
parent: "M031"
milestone: "M031"
provides:
  - "commands/do.md universal-entry skill (160 lines AD-6 verb-prefixed orchestrator:do <task>),scripts/intake/do-entry.sh four-branch routing driver (346 lines bash 3.2 MEM001 compatible -- tier-a-plus-handoff/tier-a-degenerate/tier-bc-passthrough/low-conf-prompt),FR-10 CLI surface (--task required + --yes + --config + --dispatch-stub + --scratch-root + --no-prompt-mode + ORCH_DO_ENTRY_LOG env override),FR-11 confidence-floor numeric mapping (high->1.0 low->0.5 vs entry_routing_confidence_floor numeric),FR-12 fast-path stderr summary line (doing: <task> -- knowledge: <N> MEMs / <X> tokens reading AD-11 sidecar mem_count + total_tokens),FR-13 Tier B/C passthrough surface (route=tier_bc passthrough=orchestrator:specify|orchestrator:evaluate; one-shot NG-6 -- operator runs named command in next turn),JSONL unit_close emitter on low-confidence-prompt branch (chosen_shape captured under .orchestrator/observability/ permissive carve-out),4 m031-p03 shape verifiers under tools/verify/ (do-md-shape + do-entry-shape + fastpath-shape + passthrough-shape; all AD-19 single-script Truth Check shape; all exit 0 with fail=0),tests/m031-acceptance/test-universal-entry-trivial.sh (120 lines bash 3.2 SC-7 acceptance test exercising do-entry.sh tier_a_degenerate fast-path via --dispatch-stub seam),tests/m031-acceptance/test-universal-entry-lowconf.sh (171 lines bash 3.2 SC-8 acceptance test exercising do-entry.sh low-confidence-prompt branch under --no-prompt-mode A and B sub-cases),tests/m031-acceptance/fixtures/do-entry-stub.sh (canned dispatch stub mirroring P02 SC-6 stub shape; positional argv branch+task+payload+sidecar; logs to ORCH_DO_ENTRY_STUB_LOG),tests/m031-acceptance/fixtures/do-entry-trivial-input.txt (4-word idea/high fixture),tests/m031-acceptance/fixtures/do-entry-lowconf-input.txt (9-word idea/low boundary-band fixture; empirically derived via shape-detect.sh first-candidate hit),tools/verify/m031-p03-test-universal-entry-trivial-shape.sh (AD-19 single-script Truth Check; pass=12 fail=0),tools/verify/m031-p03-test-universal-entry-lowconf-shape.sh (AD-19 single-script Truth Check; pass=13 fail=0),tools/verify/m031-p03-phase-suite.sh (7-gate straight-line aggregator AD-19 -- 4 T01 gates + 2 T02 gates + scope-guard last); tools/verify/m031-p03-scope-guard.sh (SC-12 block-list verifier with MEM hit_count carve-out + dual-prefix permissive carve-out for .orchestrator/observability/ + .orchestrator/tier-a-plus/; allow-list reflects P03 Files Likely Touched + phase/task plan + summary paths)"
requires:
  - "P01,P02"
affects:
  - "P04"
key_files:
  - "commands/do.md,scripts/intake/do-entry.sh,tools/verify/m031-p03-do-md-shape.sh,tools/verify/m031-p03-do-entry-shape.sh,tools/verify/m031-p03-fastpath-shape.sh,tools/verify/m031-p03-passthrough-shape.sh,tests/m031-acceptance/test-universal-entry-trivial.sh,tests/m031-acceptance/test-universal-entry-lowconf.sh,tests/m031-acceptance/fixtures/do-entry-stub.sh,tests/m031-acceptance/fixtures/do-entry-trivial-input.txt,tests/m031-acceptance/fixtures/do-entry-lowconf-input.txt,tools/verify/m031-p03-test-universal-entry-trivial-shape.sh,tools/verify/m031-p03-test-universal-entry-lowconf-shape.sh,tools/verify/m031-p03-phase-suite.sh,tools/verify/m031-p03-scope-guard.sh"
key_decisions:
  - "confidence-floor enum->numeric adapter (high=1.0 low=0.5; A-2 closure; forward-compatible if M024 ever emits numeric),word-band split for paragraph verdict (<=30 words -> Tier A degenerate; >30 -> Tier B/C passthrough),eval inside run_tier_a_plus_handoff helper acceptable because input is fully controlled by this script's own argument parser (no operator-supplied unquoted strings reach it; verifiers gate AD-19 Truth Check command shape not implementation internals),verifier check_literal/check_absent helpers use grep -qF -- needle so flags like --task / --yes are treated as patterns not options (BSD grep on macOS rejects bare --task),declare-A comment paraphrased as 'associative-array declarations (the declare minus-A form is forbidden)' so do-entry-shape verifier check_absent does not false-positive on its own MEM001 hygiene callout,JSONL unit_close lands at .orchestrator/observability/dispatch-log.jsonl by default (P01/P02 scope-guard permissive carve-out) with ORCH_DO_ENTRY_LOG override mirroring P02's ORCH_TIER_A_PLUS_LOG pattern,empirical low-confidence fixture chosen as 9-word idea/low boundary input (shape-detect.sh emits low at 8-10 word band) rather than 30-32 or 78-80 tier_a_plus boundary -- simpler deterministic hit; first candidate succeeded so no alternative needed,SC-7 stderr also contains the build-context.sh RESULT JSON line as a side-effect; the SC-7 doing-line assertion uses anchored grep -cE returning exactly 1 to filter past the side-channel line,SC-8 sub-case A and sub-case B use independent TMPDIR scratch roots + independent JSONL log paths so they do not race; trap rm -rf EXIT cleans both,verifier check-helpers use grep -F -q -e needle for flag-token literal matches (T01 deviation note: BSD grep on macOS rejects bare --task / --no-prompt-mode etc as flags),CON-4 invariant gated via verifier absent-check on three orchestration command names (orchestrator-auto / orchestrator-roadmap / orchestrator-consolidate),CON-7 scaffold-placeholder byte pattern detection via printf 0133 octal escape (mirrors the M031 P02 source-side discipline),no T01 deliverable byte changed in T02 (commands/do.md + scripts/intake/do-entry.sh + four T01 shape verifiers all byte-frozen post-T01 per plan-time discipline),phase-suite mirrors P02 11-gate shape with N=7 (4 T01 + 2 T02 + 1 T03); scope-guard inherits dual-prefix permissive carve-out (.orchestrator/observability/ + .orchestrator/tier-a-plus/) verbatim from P02; MEM hit_count-only carve-out copied verbatim from P02 (which itself copied verbatim from P01); allow-list contains 15 Files Likely Touched + 12 phase/task/summary paths under .orchestrator/milestones/M031/phases/P03/"
patterns_established:
  - "four-branch first-match-wins routing table (tier_a_plus -> low-conf -> tier_a_degenerate -> tier_bc passthrough fallback),enum->numeric confidence adapter pattern (forward-compatible without breaking the consumer when the upstream emitter changes shape),verifier check_literal/check_absent helper with grep -qF -- needle for flag-token matching,paraphrase-the-forbidden-token discipline applied to MEM001 callouts (declare minus-A) so the script's own hygiene comment does not trip its own absence verifier,production agent-runtime handoff vs test --dispatch-stub seam bifurcation on the Tier A degenerate fast-path (MEM018 -- agent IS the adapter; entry script writes payload + sidecar to disk and returns),4-layer config knob resolution mirrors P02 tier-a-plus-prompt.sh (--config -> .orchestrator/config.yml -> templates/default -> hardcoded fallback),JSONL unit_close emitter inline (no new emitter introduced; bash 3.2 string concatenation per existing convention) with ORCH_*_LOG env override naming convention,em-dash (U+2014) literal in the FR-12 stderr summary line shape (matches the spec's printed format),acceptance-test-via-stub-seam pattern: drive end-to-end via --dispatch-stub seam against canned stub that logs invocations to ORCH-STUB-LOG env; assertion is grep -c on the log file (mirrors P02 SC-6 stub shape one milestone earlier),independent-tmp-roots-per-sub-case discipline: SC-8 sub-case A and B each get their own mktemp -d work-a / work-b + ORCH_DO_ENTRY_LOG override so the assertions read only this run records,empirical-fixture-derivation as a planning step (run shape-detect.sh against candidate inputs then commit the first hit) -- documented in fixture filename and reasoning lives in the Description block of the task plan + reproduced in this SUMMARY,build-context.sh-stderr-side-channel awareness in test assertions: anchored grep -cE returning 1 filters past the RESULT JSON line build-context.sh emits on stderr without polluting the FR-12 doing-line check,SC-7 + SC-8 envelope conventions match M031 P01/P02: RESULT SC-N pass / RESULT SC-N fail diagnostic on the test scripts; SUMMARY verifier pass=N fail=M on the shape verifiers,test scripts use trap rm -rf work-dirs EXIT for hermetic cleanup -- no /tmp residue between test runs,phase-suite straight-line N-gate aggregation now runs M031/P01:9 / M031/P02:11 / M031/P03:7 (the pattern is invariant across milestone phases regardless of N); SC-12 scope-guard with dual-prefix permissive carve-out is a project-wide convention now (P02 + P03); MEM hit_count-only carve-out function copied verbatim across three consecutive phases (P01 -> P02 -> P03) -- effectively a stable utility now; allow-list provenance comment block lists the source plan section ('Files Likely Touched' from P03-PLAN.md) so future maintainers can trace the surface"
drill_down_paths:
  - "[.orchestrator/milestones/M031/phases/P03/tasks/T01-do-md-and-entry-script-SUMMARY.md](../../../../../milestones/M031/phases/P03/tasks/T01-do-md-and-entry-script-SUMMARY.md), [.orchestrator/milestones/M031/phases/P03/tasks/T02-acceptance-tests-SUMMARY.md](../../../../../milestones/M031/phases/P03/tasks/T02-acceptance-tests-SUMMARY.md), [.orchestrator/milestones/M031/phases/P03/tasks/T03-phase-suite-and-scope-guard-SUMMARY.md](../../../../../milestones/M031/phases/P03/tasks/T03-phase-suite-and-scope-guard-SUMMARY.md)"
duration: "180m"
verification_result: "pass"
completed_at: "2026-05-01T20:21:57Z"
observability_surfaces:
  - "none"
---

P03 closes the M031 right-sized-entry milestone's universal-entry surface: the operator-facing `orchestrator:do <task>` skill (commands/do.md, 160 lines) plus its backing four-branch routing driver `scripts/intake/do-entry.sh` (346 lines, bash 3.2). The skill maps the four shape-detect.sh × M024 verdict combinations onto orchestrator behaviors — `tier_a_plus` → handoff to the P02 Tier A+ flow; ≤30-word `tier_a` → fast-path direct dispatch via build-context.sh; `tier_bc` → one-shot named-command passthrough (orchestrator:specify | orchestrator:evaluate); low-confidence → interactive prompt with JSONL `unit_close` emission for chosen-shape capture.

3 tasks shipped clean across 3 commits:
- **T01 do-md-and-entry-script** [`10baff2`] — commands/do.md + scripts/intake/do-entry.sh + 4 shape verifiers (do-md / do-entry / fastpath / passthrough). FR-10 CLI surface (`--task` + `--yes` + `--config` + `--dispatch-stub` + `--scratch-root` + `--no-prompt-mode` + `ORCH_DO_ENTRY_LOG`). FR-11 confidence-floor enum→numeric adapter (`high→1.0`, `low→0.5`) closes A-2 forward-compatibly without modifying M024. FR-12 stderr summary line shape verified end-to-end against production build-context.sh.
- **T02 acceptance-tests** [`85a4ce9`] — SC-7 (Tier A degenerate fast-path) + SC-8 (low-confidence prompt sub-cases A/B) acceptance tests, 3 fixtures, 2 shape verifiers. Stub-seam pattern mirrors P02/SC-6 one milestone earlier. Empirical low-confidence fixture derivation (9-word boundary band, first-candidate hit on shape-detect.sh:108-114).
- **T03 phase-suite-and-scope-guard** [`65dd1b4`] — 7-gate `m031-p03-phase-suite.sh` straight-line aggregator (4 T01 + 2 T02 + 1 T03) + `m031-p03-scope-guard.sh` SC-12 block-list verifier inheriting the dual-prefix permissive carve-out (`.orchestrator/observability/` + `.orchestrator/tier-a-plus/`) and the MEM `hit_count`-only carve-out verbatim from P02 (which copied from P01).

**Verification result**: phase-suite green 7/7 (all gates exit 0); scope-guard green (`pass=31 block_list_violations=0`); `check-must-haves.sh` against the phase directory reports 0 FAIL across 8 truths + 30 artifacts + 14 key-links.

**Key decisions**:
- Confidence-floor adapter: enum→numeric (`high→1.0`, `low→0.5`) inside do-entry.sh rather than mutating M024 — closes A-2 with forward compatibility (consumer survives any future M024 numeric emission unchanged).
- Word-band split for paragraph verdict: ≤30 words → Tier A degenerate fast-path; >30 → Tier B/C passthrough (no roadmap, no auto, single named command for the operator to run next turn — NG-6 one-shot scope preserved).
- Tier A+ fast-path uses `eval` inside `run_tier_a_plus_handoff` because the input is fully controlled by the script's own arg parser; verifier discipline gates the AD-19 Truth Check command shape, not implementation internals.

**Patterns established**:
- Four-branch first-match-wins routing table consolidated as the canonical entry-point shape.
- Acceptance-test-via-stub-seam (drive end-to-end via `--dispatch-stub` against a canned stub that logs invocations to `ORCH_*_LOG`; assertion is `grep -c` on the log) — now a stable cross-phase utility (P02/SC-6 + P03/SC-7 + P03/SC-8).
- Phase-suite straight-line N-gate aggregation across M031/P01:9, P02:11, P03:7 — invariant pattern regardless of N.
- SC-12 scope-guard with dual-prefix permissive carve-out + MEM hit_count-only carve-out function copied verbatim across P01 → P02 → P03 — effectively a stable cross-phase utility now.
- Paraphrase-the-forbidden-token discipline (e.g., MEM001 `declare -A` callouts paraphrased as "the declare minus-A form") so a verifier's own absence-check does not false-positive on its own MEM-hygiene comment.
- BSD-grep portability: verifier `check_literal` / `check_absent` helpers use `grep -qF -- "$needle"` so flag-token literals (`--task`, `--yes`, `--no-prompt-mode`) survive macOS BSD grep's flag-rejection.

**Plan-time defects observed for P04 / future**:
- T03 task plan invokes `check-must-haves.sh` with a file argument (`P03-PLAN.md`); the script demands a directory. Substantive verification passes when invoked with the directory; the auto-loop verify-step extraction caught the shape mismatch. Recorded as observational concern (US3 AS6 DONE_WITH_CONCERNS — proceeded). Future task plans should write the verification command with a directory arg.

**Pre-existing working-tree drift forwarded**:
- M030 ROADMAP, AGENTS.md, KNOWLEDGE-INDEX.md, knowledge/MEM*.md `hit_count` increments, scripts/dispatch/build-context.sh, templates/orchestrator-config-default.yml, tools/verify/p00-phase-suite.sh, .orchestrator/doctor-history.jsonl, etc. were all present at session entry from prior sessions; carved out as soft `WARN: out-of-allow-list` by the M031 scope-guard's MEM hit_count carve-out. P02's forward-note recommended a housekeeping commit before milestone close; P03 forwards the same recommendation to P04. Recommend a milestone-level housekeeping commit before M031-SUMMARY.md writes.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P04"
milestone: "M031"
name: "Milestone-grain SC-12 scope-guard + acceptance battery aggregator (SC-14)"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- T01 complete: SC-9 `tests/m031-acceptance/doc-drift-verifier.sh` exists and passes; SC-10 `tests/m031-acceptance/test-auto-proceed-default.sh` exists and passes.
- T02 complete: AD-9 `tests/m031-acceptance/test-doctor-compound-change.sh` exists and passes.
- T03 complete: AD-19 `tests/m031-acceptance/test-budget-drift-warning.sh` exists and passes.
- All P01–P03 SC scripts exist on disk under `tests/m031-acceptance/`:
  - SC-1 `test-quick-injects-knowledge.sh` (P01)
  - SC-2 `test-build-context-profile.sh` (P01)
  - SC-3 `test-compression-applies-to-quick.sh` (P01)
  - SC-5 `test-tier-a-plus-classifier.sh` (P02)
  - SC-6 `test-tier-a-plus-flow.sh` (P02)
  - SC-7 `test-universal-entry-trivial.sh` (P03)
  - SC-8 `test-universal-entry-lowconf.sh` (P03)
  - SC-11 `empirical-baseline.sh` (P00, invoked with `--compare`)
  - SC-13 `verify-baseline-ordering.sh` (P00, under Option B per AD-12)
  - SC-15 `test-quick-budget-median.sh` (P01)
  - SC-16 `test-tier-a-plus-prompt-ux.sh` (P02)
- The per-phase scope-guards exist on disk under `tools/verify/`: `m031-p01-scope-guard.sh`, `m031-p02-scope-guard.sh`, `m031-p03-scope-guard.sh` — read for shape inheritance.
- `tests/m030-acceptance/run-acceptance-battery.sh` exists and is the canonical battery-aggregator shape (read for the `run_sc` helper + final `BATTERY: pass=N fail=M` line + AD-19 single-script-file shape).
- The per-phase scope-guard's `tests/m031-acceptance/fixtures/empirical-baseline/SC13-OPTION.md` records whether SC-13 is Option B (git-history check) or Option A (protocol note, drop from battery N).

## Description

T04 ships two milestone-close deliverables:

1. **Milestone-grain SC-12 scope-guard** — `tests/m031-acceptance/scope-guard.sh`. This is **distinct from** the per-phase `tools/verify/m031-p0X-scope-guard.sh` family. The per-phase scope-guards each enforce SC-12 against a **single phase's working-tree diff** (typically vs HEAD); the milestone-grain scope-guard enforces SC-12 against the **entire M031 milestone's diff** (typically the merge-base between the M031 work branch and the project's main branch, OR — equivalently for a working-tree dogfood — the same working-tree-vs-HEAD diff but with an allow-list reflecting every phase's "Files Likely Touched" surface). The verifier emits `RESULT: SC-12 pass` and exits 0 iff `block_list_violations == 0`. POSIX-bash per CON-6.

2. **SC-14 acceptance battery aggregator** — `tests/m031-acceptance/run-acceptance-battery.sh`. Mirrors the M030 acceptance-battery convention at `tests/m030-acceptance/run-acceptance-battery.sh`. Chains every M031 SC script in literal-sequence `bash <path>` invocations (AD-19 — straight-line, no array loops, no compound chains). Captures rc per call into `pass` / `fail` accumulators via a `run_sc` helper. Emits a final `BATTERY: pass=N fail=M` line and exits 0 iff `fail == 0`. Sub-gate inventory (16 SC scripts under Option B; 15 under Option A):

   - SC-1: `test-quick-injects-knowledge.sh`
   - SC-2: `test-build-context-profile.sh`
   - SC-3: `test-compression-applies-to-quick.sh`
   - SC-5: `test-tier-a-plus-classifier.sh`
   - SC-6: `test-tier-a-plus-flow.sh`
   - SC-7: `test-universal-entry-trivial.sh`
   - SC-8: `test-universal-entry-lowconf.sh`
   - SC-9: `doc-drift-verifier.sh`
   - SC-10: `test-auto-proceed-default.sh`
   - SC-11: `empirical-baseline.sh --compare`
   - SC-12: `scope-guard.sh`
   - SC-13: `verify-baseline-ordering.sh` (Option B only — see Notes)
   - SC-15: `test-quick-budget-median.sh`
   - SC-16: `test-tier-a-plus-prompt-ux.sh`
   - AD-9: `test-doctor-compound-change.sh`
   - AD-19: `test-budget-drift-warning.sh`

   N ≥ 15 under Option B (16 entries). N ≥ 14 under Option A (drop SC-13).

T04 ALSO ships three shape verifiers under `tools/verify/`:

- `m031-p04-test-scope-guard-shape.sh` — asserts the milestone-grain `tests/m031-acceptance/scope-guard.sh` exists, contains the SC-12 block-list literals, contains the carve-out logic.
- `m031-p04-battery-shape.sh` — asserts the battery aggregator exists, contains the `BATTERY:` envelope, references every required SC script.
- `m031-p04-evidence-ledger-shape.sh` — asserts [`.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md`](../../../../../milestones/M031/M031-ACCEPTANCE-EVIDENCE.md) exists with the `BATTERY:` line + per-SC roll-up. **At T04 close this verifier may report fail** because T05 has not yet authored the evidence ledger; the verifier becomes load-bearing once T05 completes. T04 ships the verifier itself; T05 ships the artifact it gates.

## Steps

1. **Read `tests/m030-acceptance/run-acceptance-battery.sh`** with the `Read` tool. Note:
   - `set -uo pipefail` at the top.
   - `SCRIPT_DIR` / `PROJECT_ROOT` resolution.
   - `pass=0; fail=0` accumulators.
   - `run_sc()` helper accepting `(label, path)`, invoking `bash "$path"`, capturing rc, incrementing pass/fail, emitting `BATTERY-PASS:` or `BATTERY-FAIL:`.
   - 22 sequential `run_sc "<label>" "$PROJECT_ROOT/<path>"` calls.
   - Final `printf 'BATTERY: pass=%s fail=%s\n' "$pass" "$fail"` and `exit` based on `fail`.
   - AD-19 compliance: every gate invocation is a literal `run_sc` call, no loops over arrays, no compound chains.

2. **Read `tools/verify/m031-p03-scope-guard.sh`** with the `Read` tool. Note:
   - The block-list pattern matcher (`case "$path" in knowledge/*|scripts/cost/*|...`).
   - The MEM `hit_count`-only carve-out function (regex `^[+-]hit_count: [0-9]+$` on `knowledge/(conventions|lessons|patterns)/MEM*.md` paths).
   - The dual-prefix permissive carve-out (`.orchestrator/observability/*` + `.orchestrator/tier-a-plus/*`).
   - The allow-list block.
   - The final `SUMMARY:` line with `block_list_violations=K mem_hitcount_carveouts=L` fields.

3. **Read `tests/m031-acceptance/fixtures/empirical-baseline/SC13-OPTION.md`** to determine whether SC-13 is Option A or Option B. The battery aggregator's sub-gate inventory depends on this.

4. **Author `tests/m031-acceptance/scope-guard.sh`** (≥ 80 lines, executable, POSIX-bash). Mirror the per-phase scope-guard shape with these adjustments:
   - **Allow-list**: aggregate every phase's "Files Likely Touched" surface. A reasonable starting set (the executor refines from the actual phase plans):

     ```
     # P00 surface
     tests/m031-acceptance/fixtures/empirical-baseline/...
     tests/m031-acceptance/empirical-baseline.sh
     tests/m031-acceptance/verify-baseline-ordering.sh
     # P01 surface
     scripts/dispatch/build-context.sh
     commands/dispatch.md
     templates/orchestrator-config-default.yml
     tests/m031-acceptance/test-quick-injects-knowledge.sh
     tests/m031-acceptance/test-build-context-profile.sh
     tests/m031-acceptance/test-compression-applies-to-quick.sh
     tests/m031-acceptance/test-quick-budget-median.sh
     tools/verify/m031-p01-*.sh
     # P02 surface
     scripts/intake/shape-detect.sh
     scripts/intake/paragraph-classify.sh
     scripts/intake/route-to-dispatch.sh
     scripts/intake/lib/task-slug.sh
     scripts/intake/lib/tier-a-plus-prompt.sh
     templates/dispatch-role-research.md
     templates/dispatch-role-plan.md
     templates/dispatch-role-build.md
     tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md
     tests/m031-acceptance/fixtures/tier-a-plus-input.txt
     tests/m031-acceptance/test-tier-a-plus-classifier.sh
     tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh
     tests/m031-acceptance/test-tier-a-plus-flow.sh
     tools/verify/m031-p02-*.sh
     # P03 surface
     commands/do.md
     scripts/intake/do-entry.sh
     tests/m031-acceptance/fixtures/do-entry-stub.sh
     tests/m031-acceptance/fixtures/do-entry-trivial-input.txt
     tests/m031-acceptance/fixtures/do-entry-lowconf-input.txt
     tests/m031-acceptance/test-universal-entry-trivial.sh
     tests/m031-acceptance/test-universal-entry-lowconf.sh
     tools/verify/m031-p03-*.sh
     # P04 surface (this phase)
     commands/evaluate.md
     references/tier-definitions.md
     CHANGELOG.md
     scripts/diagnostics/run-doctor.sh
     scripts/diagnostics/efficiency-footer.sh
     tests/m031-acceptance/doc-drift-verifier.sh
     tests/m031-acceptance/test-auto-proceed-default.sh
     tests/m031-acceptance/test-doctor-compound-change.sh
     tests/m031-acceptance/test-budget-drift-warning.sh
     tests/m031-acceptance/scope-guard.sh
     tests/m031-acceptance/run-acceptance-battery.sh
     [.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md](../../../../../milestones/M031/M031-ACCEPTANCE-EVIDENCE.md)
     tools/verify/m031-p04-*.sh
     # Phase/task plan / summary paths under .orchestrator/milestones/M031/
     ```

   - **Block-list**: verbatim from per-phase scope-guards: `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, `scripts/auto/loop/`.
   - **MEM hit_count-only carve-out**: copy verbatim.
   - **Dual-prefix permissive carve-out**: copy verbatim.
   - **Final SUMMARY line**: `RESULT: SC-12 pass` (acceptance-test envelope) AND `SUMMARY: scope-guard.sh pass=N fail=M block_list_violations=K mem_hitcount_carveouts=L` (compatibility envelope so the battery aggregator + phase-suite + downstream consumers see consistent shapes).
   - **POSIX-bash discipline** (CON-6 / DC-7): use `[ "$a" = "$b" ]` not `[[ ]]`; `printf` not `echo -e`; arithmetic via `$(( ... ))`; no `declare -A`.

   `chmod +x tests/m031-acceptance/scope-guard.sh`.

5. **Author `tests/m031-acceptance/run-acceptance-battery.sh`** (≥ 80 lines, executable, bash 3.2). Mirror the M030 battery shape exactly. Body shape:

   ```bash
   #!/usr/bin/env bash
   # tests/m031-acceptance/run-acceptance-battery.sh
   # M031/P04/T04 — SC-14 acceptance battery runner.
   #
   # Invokes every M031 SC verifier in literal sequence. Mirrors the M030
   # convention at tests/m030-acceptance/run-acceptance-battery.sh.
   # AD-19 single-script-file shape: each verifier is invoked as
   # `bash <path>` with rc captured per-call; no compound chains, no
   # loops, no eval.
   #
   # Final stdout line: `BATTERY: pass=N fail=M`. Exits 0 iff fail=0.

   set -uo pipefail
   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

   pass=0
   fail=0

   run_sc() {
     local label="$1"
     local path="$2"
     local extra="${3:-}"
     if [ -n "$extra" ]; then
       bash "$path" $extra
     else
       bash "$path"
     fi
     local rc=$?
     if [ "$rc" -eq 0 ]; then
       pass=$((pass + 1))
       printf 'BATTERY-PASS: %s (%s)\n' "$label" "$path"
     else
       fail=$((fail + 1))
       printf 'BATTERY-FAIL: %s (%s) exited %d\n' "$label" "$path" "$rc"
     fi
   }

   # ---------- P01 SCs ----------
   run_sc "SC-1"  "$PROJECT_ROOT/tests/m031-acceptance/test-quick-injects-knowledge.sh"
   run_sc "SC-2"  "$PROJECT_ROOT/tests/m031-acceptance/test-build-context-profile.sh"
   run_sc "SC-3"  "$PROJECT_ROOT/tests/m031-acceptance/test-compression-applies-to-quick.sh"

   # ---------- P02 SCs ----------
   run_sc "SC-5"  "$PROJECT_ROOT/tests/m031-acceptance/test-tier-a-plus-classifier.sh"
   run_sc "SC-6"  "$PROJECT_ROOT/tests/m031-acceptance/test-tier-a-plus-flow.sh"
   run_sc "SC-16" "$PROJECT_ROOT/tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh"

   # ---------- P03 SCs ----------
   run_sc "SC-7"  "$PROJECT_ROOT/tests/m031-acceptance/test-universal-entry-trivial.sh"
   run_sc "SC-8"  "$PROJECT_ROOT/tests/m031-acceptance/test-universal-entry-lowconf.sh"

   # ---------- P04 SCs ----------
   run_sc "SC-9"  "$PROJECT_ROOT/tests/m031-acceptance/doc-drift-verifier.sh"
   run_sc "SC-10" "$PROJECT_ROOT/tests/m031-acceptance/test-auto-proceed-default.sh"
   run_sc "SC-12" "$PROJECT_ROOT/tests/m031-acceptance/scope-guard.sh"
   run_sc "AD-9"  "$PROJECT_ROOT/tests/m031-acceptance/test-doctor-compound-change.sh"
   run_sc "AD-19" "$PROJECT_ROOT/tests/m031-acceptance/test-budget-drift-warning.sh"

   # ---------- P01 budget median + P00 baseline + ordering ----------
   run_sc "SC-15" "$PROJECT_ROOT/tests/m031-acceptance/test-quick-budget-median.sh"
   run_sc "SC-11" "$PROJECT_ROOT/tests/m031-acceptance/empirical-baseline.sh" "--compare"
   run_sc "SC-13" "$PROJECT_ROOT/tests/m031-acceptance/verify-baseline-ordering.sh"

   # ---------- Aggregate ----------
   printf 'BATTERY: pass=%s fail=%s\n' "$pass" "$fail"
   if [ "$fail" -eq 0 ]; then
     exit 0
   fi
   exit 1
   ```

   Notes on the `run_sc` helper:
   - The `extra` third positional argument carries trailing flags (e.g. `--compare` for SC-11). The helper splits it via `$extra` (unquoted) — bash 3.2 word-splitting is acceptable here because the arguments are author-controlled, not user input.
   - SC-13 is included unconditionally in this template; if `SC13-OPTION.md` records Option A, the executor REMOVES the `run_sc "SC-13" ...` line entirely (do NOT comment it out, do NOT leave it dead). The aggregator then has 15 entries and N ≥ 14.

   Note on the `set -uo pipefail` line: `pipefail` is bash-specific (not strict POSIX). The battery aggregator is bash-only (matches the M030 precedent); the milestone-grain scope-guard at step 4 is POSIX-bash for portability.

   `chmod +x tests/m031-acceptance/run-acceptance-battery.sh`.

6. **Author `tools/verify/m031-p04-test-scope-guard-shape.sh`** (≥ 20 lines, executable). Asserts:
   - `check_present tests/m031-acceptance/scope-guard.sh "SC-12"`
   - `check_present tests/m031-acceptance/scope-guard.sh "knowledge/"`
   - `check_present tests/m031-acceptance/scope-guard.sh "scripts/cost"`
   - `check_present tests/m031-acceptance/scope-guard.sh "scripts/dispatch/adapters/router"`
   - `check_present tests/m031-acceptance/scope-guard.sh "scripts/auto/loop"`
   - `check_present tests/m031-acceptance/scope-guard.sh "block_list_violations"`
   - `check_present tests/m031-acceptance/scope-guard.sh ".orchestrator/observability"`
   - `check_present tests/m031-acceptance/scope-guard.sh ".orchestrator/tier-a-plus"`

   AD-19 single-script-file shape; emits `SUMMARY: m031-p04-test-scope-guard-shape.sh pass=N fail=M`; exits 0 iff `fail == 0`.

7. **Author `tools/verify/m031-p04-battery-shape.sh`** (≥ 25 lines, executable). Asserts the battery aggregator references every required SC script:
   - `check_present tests/m031-acceptance/run-acceptance-battery.sh "BATTERY:"`
   - `check_present tests/m031-acceptance/run-acceptance-battery.sh "test-quick-injects-knowledge.sh"`
   - `check_present tests/m031-acceptance/run-acceptance-battery.sh "test-tier-a-plus-flow.sh"`
   - `check_present tests/m031-acceptance/run-acceptance-battery.sh "test-universal-entry-trivial.sh"`
   - `check_present tests/m031-acceptance/run-acceptance-battery.sh "doc-drift-verifier.sh"`
   - `check_present tests/m031-acceptance/run-acceptance-battery.sh "test-auto-proceed-default.sh"`
   - `check_present tests/m031-acceptance/run-acceptance-battery.sh "scope-guard.sh"`
   - `check_present tests/m031-acceptance/run-acceptance-battery.sh "test-doctor-compound-change.sh"`
   - `check_present tests/m031-acceptance/run-acceptance-battery.sh "test-budget-drift-warning.sh"`
   - `check_present tests/m031-acceptance/run-acceptance-battery.sh "empirical-baseline.sh"`
   - `check_present tests/m031-acceptance/run-acceptance-battery.sh "test-quick-budget-median.sh"`
   - `check_present tests/m031-acceptance/run-acceptance-battery.sh "test-tier-a-plus-prompt-ux.sh"`
   - `check_present tests/m031-acceptance/run-acceptance-battery.sh "run_sc"`

   AD-19 single-script-file shape; emits `SUMMARY: m031-p04-battery-shape.sh pass=N fail=M`; exits 0 iff `fail == 0`.

8. **Author `tools/verify/m031-p04-evidence-ledger-shape.sh`** (≥ 20 lines, executable). Asserts the evidence ledger exists with required substrings (the ledger itself is authored by T05; this verifier shipped at T04 close becomes load-bearing once T05 completes):
   - `check_present [.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md](../../../../../milestones/M031/M031-ACCEPTANCE-EVIDENCE.md) "BATTERY:"`
   - `check_present [.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md](../../../../../milestones/M031/M031-ACCEPTANCE-EVIDENCE.md) "M031"`
   - `check_present [.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md](../../../../../milestones/M031/M031-ACCEPTANCE-EVIDENCE.md) "SC-"`

   AD-19 single-script-file shape; emits `SUMMARY: m031-p04-evidence-ledger-shape.sh pass=N fail=M`; exits 0 iff `fail == 0`.

   **At T04 close this verifier WILL FAIL** (the evidence ledger does not yet exist — T05 authors it). T04's local-confirmation step (#9 below) acknowledges this expected failure; the verifier becomes load-bearing at T05 close.

9. **Run the battery + scope-guard + shape verifiers locally to confirm exit 0**:

   ```bash
   bash tests/m031-acceptance/scope-guard.sh
   ```

   ```bash
   bash tests/m031-acceptance/run-acceptance-battery.sh
   ```

   ```bash
   bash tools/verify/m031-p04-test-scope-guard-shape.sh
   ```

   ```bash
   bash tools/verify/m031-p04-battery-shape.sh
   ```

   The battery should report `BATTERY: pass=15 fail=0` (Option A) or `BATTERY: pass=16 fail=0` (Option B). If any sub-gate fails, the failure is one of:
   - **A T01–T03 deliverable is missing**: re-verify the upstream tasks shipped their artifacts.
   - **A pre-P04 SC script is missing or broken**: re-run that phase's plan-phase to re-verify the prior-phase deliverable.
   - **The milestone-grain scope-guard's allow-list is too narrow**: extend the allow-list to cover the missing path.

   The `m031-p04-evidence-ledger-shape.sh` verifier is EXPECTED TO FAIL at T04 close (the ledger does not yet exist). T05 ships the ledger.

10. **Commit T04 deliverables** via `git commit -F <message-file>`. Suggested commit subject: `M031/P04/T04: SC-12 milestone-grain scope-guard + SC-14 acceptance battery aggregator`.

## Must-Haves

This task addresses the following Must-Haves from `P04-PLAN.md`:
- "`tests/m031-acceptance/scope-guard.sh` (SC-12 milestone-grain) exists, is executable, and exits 0 against the M031 working-tree diff" (Truth #11; Check via `m031-p04-test-scope-guard-shape.sh`)
- "`tests/m031-acceptance/run-acceptance-battery.sh` (SC-14) exists, is executable, chains every prior-phase SC script and every P04 SC script ... emits a final `BATTERY: pass=N fail=M` line" (Truth #12; Check via `m031-p04-battery-shape.sh`)

## Verification

```bash
bash tests/m031-acceptance/scope-guard.sh
```

```bash
bash tests/m031-acceptance/run-acceptance-battery.sh
```

```bash
bash tools/verify/m031-p04-test-scope-guard-shape.sh
```

```bash
bash tools/verify/m031-p04-battery-shape.sh
```

## Notes

- The milestone-grain scope-guard at `tests/m031-acceptance/scope-guard.sh` and the phase-grain scope-guards at `tools/verify/m031-p0X-scope-guard.sh` are intentionally separate. The acceptance-test family (under `tests/`) is the operator-facing surface invoked by `run-acceptance-battery.sh`; the verifier family (under `tools/verify/`) is the internal phase-suite gate. Both share the same block-list + carve-out logic but operate at different scopes (whole-milestone vs single-phase).
- The `m031-p04-evidence-ledger-shape.sh` verifier authored at T04 step 8 is expected to fail at T04 close because T05 has not yet authored the ledger. T04 ships the verifier as part of the surface contract; T05 ships the artifact.
- The battery aggregator's order matters for diagnostic legibility: P01 SCs first (foundation), then P02 (Tier A+), then P03 (universal entry), then P04 (drift + comms + observability), then P00 baseline tail (SC-11 / SC-13). This mirrors the dependency order so a failing run reads top-to-bottom as a phase-by-phase report.
- SC-13 inclusion depends on the Option A vs B selection in `tests/m031-acceptance/fixtures/empirical-baseline/SC13-OPTION.md`. The template above includes SC-13; the executor consults the option file and removes the line if Option A is active.
- The scope-guard's POSIX-bash discipline (CON-6) means it can run under M009 multi-runtime audit later without rewrite. The battery aggregator uses bash-specific `set -uo pipefail` matching the M030 precedent; this is an explicit choice (the battery is bash-only by design).
- **Real-app smoke test pending** (plan-time discipline rule 5): the battery exercises every gate against in-repo fixtures + working-tree state. Production confirmation that an operator running the battery on a fresh clone of a downstream consumer project sees the same green pass is the [M033](../../../../../milestones/M033/index.md) onboarding milestone's job; T04's gates confirm the contract surface in this repo.

## Inputs

### From Previous Tasks

- **T01**: `doc-drift-verifier.sh` (SC-9), `test-auto-proceed-default.sh` (SC-10). Battery chains both.
- **T02**: `test-doctor-compound-change.sh` (AD-9). Battery chains it.
- **T03**: `test-budget-drift-warning.sh` (AD-19). Battery chains it.

### From Previous Phases

- **P00**: `tests/m031-acceptance/empirical-baseline.sh` (SC-11), `tests/m031-acceptance/verify-baseline-ordering.sh` (SC-13), `tests/m031-acceptance/fixtures/empirical-baseline/SC13-OPTION.md` (Option A vs B selector).
- **P01**: `tests/m031-acceptance/test-quick-injects-knowledge.sh` (SC-1), `test-build-context-profile.sh` (SC-2), `test-compression-applies-to-quick.sh` (SC-3), `test-quick-budget-median.sh` (SC-15).
- **P02**: `tests/m031-acceptance/test-tier-a-plus-classifier.sh` (SC-5), `test-tier-a-plus-flow.sh` (SC-6), `test-tier-a-plus-prompt-ux.sh` (SC-16).
- **P03**: `tests/m031-acceptance/test-universal-entry-trivial.sh` (SC-7), `test-universal-entry-lowconf.sh` (SC-8).
- **Per-phase scope-guards**: `tools/verify/m031-p01-scope-guard.sh`, `m031-p02-scope-guard.sh`, `m031-p03-scope-guard.sh` — read for block-list + carve-out shape inheritance.

### From Disk (Pre-existing)

- `tests/m030-acceptance/run-acceptance-battery.sh` — read as the canonical battery-aggregator template.
- `tools/verify/m031-p03-do-md-shape.sh` — read as the canonical shape-verifier template.

## Constraints

- **Bash 3.2 compatibility** (MEM001) for the battery + shape verifiers.
- **POSIX-bash compatibility** (CON-6 / DC-7) for the milestone-grain `tests/m031-acceptance/scope-guard.sh` so M009 can extend without rewrite.
- **AD-19 single-script-file shape** for Truth `Check:` invocations and verifier internals. The battery's `run_sc` helper invokes each gate as a literal `bash <path>` line — no array loops, no compound chains.
- **No edits to T01 / T02 / T03 deliverables** in T04.
- **No edits to per-phase verifiers (`m031-p01-*.sh`, `m031-p02-*.sh`, `m031-p03-*.sh`)** in T04.
- **No edits to `scripts/intake/`, `scripts/dispatch/`, `commands/evaluate.md`, `commands/dispatch.md`, `commands/do.md`, `references/tier-definitions.md`, `templates/`, `CHANGELOG.md`, `scripts/diagnostics/`** in T04. T04 ships only new files under `tests/m031-acceptance/` and `tools/verify/`.
- **CON-7 / D020**: no scaffold-placeholder marker bracket-TODO byte pattern in any new file.
- **SC-12 scope-guard**: T04 must NOT touch `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, or `scripts/auto/loop/`. The milestone-grain scope-guard verifier itself MAY contain literal references to those paths (block-list patterns) — the carve-out logic distinguishes "literal pattern in source" from "actual diff touches the path."
- **Verifier path discipline** (AD-19 + M032 Finding A): project-owned slug-bearing verifiers live under `tools/verify/`, NOT `scripts/verify/`. Operator-facing acceptance tests live under `tests/m031-acceptance/`.
- **Commit shape**: multi-line messages MUST use `git commit -F <message-file>`.

## Expected Output

After T04 completes:

1. `tests/m031-acceptance/scope-guard.sh` (≥ 80 lines, executable, POSIX-bash) — exits 0 with `RESULT: SC-12 pass` AND `SUMMARY: scope-guard.sh pass=N fail=0 block_list_violations=0`.
2. `tests/m031-acceptance/run-acceptance-battery.sh` (≥ 80 lines, executable, bash) — exits 0 with `BATTERY: pass=N fail=0` (N = 15 under Option A, N = 16 under Option B).
3. `tools/verify/m031-p04-test-scope-guard-shape.sh` (≥ 20 lines, executable) — exits 0 with `SUMMARY: m031-p04-test-scope-guard-shape.sh pass=N fail=0`.
4. `tools/verify/m031-p04-battery-shape.sh` (≥ 25 lines, executable) — exits 0 with `SUMMARY: m031-p04-battery-shape.sh pass=N fail=0`.
5. `tools/verify/m031-p04-evidence-ledger-shape.sh` (≥ 20 lines, executable) — at T04 close this verifier is expected to FAIL because T05 has not yet authored `M031-ACCEPTANCE-EVIDENCE.md`. The verifier is shipped as the surface contract; the artifact lands at T05.

T04 leaves the milestone-close gate stack ready: scope-guard green, battery green, evidence-ledger verifier waiting for its artifact. T05 picks up with the evidence ledger + the P04 phase-suite + the P04 phase-grain scope-guard.

## State Context

- **Current State**: executing
- **Milestone**: M031
- **Phase**: P04
- **Task**: T04-scope-guard-and-battery
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **Bash 3.2 compatibility** (MEM001) for the battery + shape verifiers.
- **POSIX-bash compatibility** (CON-6 / DC-7) for the milestone-grain `tests/m031-acceptance/scope-guard.sh` so M009 can extend without rewrite.
- **AD-19 single-script-file shape** for Truth `Check:` invocations and verifier internals. The battery's `run_sc` helper invokes each gate as a literal `bash <path>` line — no array loops, no compound chains.
- **No edits to T01 / T02 / T03 deliverables** in T04.
- **No edits to per-phase verifiers (`m031-p01-*.sh`, `m031-p02-*.sh`, `m031-p03-*.sh`)** in T04.
- **No edits to `scripts/intake/`, `scripts/dispatch/`, `commands/evaluate.md`, `commands/dispatch.md`, `commands/do.md`, `references/tier-definitions.md`, `templates/`, `CHANGELOG.md`, `scripts/diagnostics/`** in T04. T04 ships only new files under `tests/m031-acceptance/` and `tools/verify/`.
- **CON-7 / D020**: no scaffold-placeholder marker bracket-TODO byte pattern in any new file.
- **SC-12 scope-guard**: T04 must NOT touch `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, or `scripts/auto/loop/`. The milestone-grain scope-guard verifier itself MAY contain literal references to those paths (block-list patterns) — the carve-out logic distinguishes "literal pattern in source" from "actual diff touches the path."
- **Verifier path discipline** (AD-19 + M032 Finding A): project-owned slug-bearing verifiers live under `tools/verify/`, NOT `scripts/verify/`. Operator-facing acceptance tests live under `tests/m031-acceptance/`.
- **Commit shape**: multi-line messages MUST use `git commit -F <message-file>`.

### Acceptance Criteria

This task addresses the following Must-Haves from `P04-PLAN.md`:
- "`tests/m031-acceptance/scope-guard.sh` (SC-12 milestone-grain) exists, is executable, and exits 0 against the M031 working-tree diff" (Truth #11; Check via `m031-p04-test-scope-guard-shape.sh`)
- "`tests/m031-acceptance/run-acceptance-battery.sh` (SC-14) exists, is executable, chains every prior-phase SC script and every P04 SC script ... emits a final `BATTERY: pass=N fail=M` line" (Truth #12; Check via `m031-p04-battery-shape.sh`)

### Files To Touch

- `commands/evaluate.md` (modify)
- `references/tier-definitions.md` (modify)
- `templates/orchestrator-config-default.yml` (modify-or-confirm)
- `CHANGELOG.md` (modify)
- `scripts/diagnostics/run-doctor.sh` (modify)
- `scripts/diagnostics/efficiency-footer.sh` (modify)
- `tests/m031-acceptance/doc-drift-verifier.sh` (create)
- `tests/m031-acceptance/test-auto-proceed-default.sh` (create)
- `tests/m031-acceptance/test-doctor-compound-change.sh` (create)
- `tests/m031-acceptance/test-budget-drift-warning.sh` (create)
- `tests/m031-acceptance/scope-guard.sh` (create)
- `tests/m031-acceptance/run-acceptance-battery.sh` (create)
- [`.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md`](../../../../../milestones/M031/M031-ACCEPTANCE-EVIDENCE.md) (create)
- `tools/verify/m031-p04-evaluate-md-drift-shape.sh` (create)
- `tools/verify/m031-p04-tier-definitions-drift-shape.sh` (create)
- `tools/verify/m031-p04-auto-proceed-default-shape.sh` (create)
- `tools/verify/m031-p04-changelog-shape.sh` (create)
- `tools/verify/m031-p04-doctor-compound-change-shape.sh` (create)
- `tools/verify/m031-p04-budget-drift-shape.sh` (create)
- `tools/verify/m031-p04-test-doc-drift-shape.sh` (create)
- `tools/verify/m031-p04-test-auto-proceed-shape.sh` (create)
- `tools/verify/m031-p04-test-doctor-compound-change-shape.sh` (create)
- `tools/verify/m031-p04-test-budget-drift-shape.sh` (create)
- `tools/verify/m031-p04-test-scope-guard-shape.sh` (create)
- `tools/verify/m031-p04-battery-shape.sh` (create)
- `tools/verify/m031-p04-evidence-ledger-shape.sh` (create)
- `tools/verify/m031-p04-phase-suite.sh` (create)
- `tools/verify/m031-p04-scope-guard.sh` (create)

<!-- The phase plan and task plan files themselves (this file +
     tasks/T0[1-5]-*-PLAN.md) are written by the planner, not by the
     executor — they are not listed here. Test-run scratch files
     written under .orchestrator/tier-a-plus/<task-slug>/ during
     integration smoke runs land under the .orchestrator/tier-a-plus/
     permissive prefix (carve-out inherited from P02/P03 scope-guard).
     Test-run JSONL records written via test-only env overrides land
     at paths the test controls (typically /tmp); they are out of the
     scope-guard's purview because /tmp is outside the repo tree. -->

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