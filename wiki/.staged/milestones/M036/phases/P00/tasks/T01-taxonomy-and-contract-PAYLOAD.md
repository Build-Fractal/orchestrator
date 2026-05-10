---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T01-taxonomy-and-contract (Phase P00, Milestone M036)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~600 | required |
| Upstream Context | 981-983 | ~100 | required |
| Task Plan | 985-1368 | ~4500 | required |
| State Context | 1370-1376 | ~100 | required |
| First-Turn Completeness | 1378-1430 | ~900 | required |
| **Total** | | **~17000** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 716
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
hit_count: 716
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
hit_count: 716
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
hit_count: 716
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
hit_count: 626
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
hit_count: 626
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
hit_count: 626
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
hit_count: 716
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
hit_count: 626
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
hit_count: 626
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
hit_count: 626
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
hit_count: 716
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
hit_count: 716
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
hit_count: 716
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
hit_count: 626
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
hit_count: 626
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
hit_count: 626
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
hit_count: 716
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
hit_count: 626
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
hit_count: 626
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
hit_count: 716
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
hit_count: 716
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
hit_count: 626
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
hit_count: 626
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
hit_count: 626
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
hit_count: 281
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
hit_count: 281
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
hit_count: 281
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
hit_count: 292
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
hit_count: 292
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
hit_count: 282
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
     Verifier scripts live under tools/verify/ — project-owned path,
     slug-bearing filenames so install-clobber risk is contained.
     Each verifier is co-authored alongside its corresponding artifact
     within the SAME task (plan-time discipline rule 2). -->

### Truths

- `references/reference-taxonomy.md` exists with YAML frontmatter (`schema_version: "1.0"`, `type: reference-taxonomy`, `milestone: "M036"`, `phase: "P00"`) and declares exactly the four categories `cms-rule`, `training-material`, `glossary`, `regulatory-doc` in a body section titled `## Categories` (each category appears as a level-3 heading `### <category>` with a one-paragraph definition + an example `cite_id` slug).
  - Check: `bash tools/verify/p00-taxonomy-shape.sh`

- `references/reference-frontmatter-contract.md` exists with frontmatter (`schema_version: "1.0"`, `type: reference-frontmatter-contract`) and a body that names every required FR-2 field (`source`, `published`, `version`, `cite_id`, `topic_tags`, `applies_to_field`) under a `## Required Fields` section, every additional FR-4 chunk-output field (`category`, `chunk_id`, `content_hash`, `scope_tags`) under `## Chunk-Output Additions`, and every graph-edge-bearing field (`cites`, `derived_from`, `applies_to_field`, `relates_to`, `supersedes`) under `## Graph Edge Fields`.
  - Check: `bash tools/verify/p00-frontmatter-contract-shape.sh`

- `references/reference-source-types.yaml` exists with frontmatter-style top-of-file comment header pointing at `## Source Types` in `references/reference-source-types.md` (or inline in this YAML — see frontmatter contract), and a `source_types:` map containing exactly the four taxonomy keys with a `default_tier:` value in the closed enum `{0, 1, 2}` for each. Defaults declared per spec #Q-8: `cms-rule: 2`, `training-material: 2`, `glossary: 2`, `regulatory-doc: 1`.
  - Check: `bash tools/verify/p00-source-types-shape.sh`

- `references/reference-edge-types.md` exists with frontmatter (`schema_version: "1.0"`, `type: reference-edge-types`) and a body section `## Edge Types` listing five edges — three new (`cites`, `derived_from`, `applies_to_field`) authored by M036, and two pre-existing (`relates_to`, `supersedes`) cross-referenced for completeness — each with a one-line directionality declaration (`directional from <source> → <target>` or `bidirectional`).

<dispatch-volatile>

## Upstream Context

No upstream summaries available.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P00"
milestone: "M036"
name: "Taxonomy SSOT + frontmatter contract + tier-policy YAML + shape verifiers"
depends_on: []
---

## Prerequisites

- Working tree at `~/Sites/spec-kit-orchestrator/` with `references/` directory present (existing, populated with 21 reference docs).
- `tools/verify/` directory may exist; create it via `mkdir -p tools/verify` if absent (project-owned verifier home per AD-19 path discipline; framework verifiers live under `scripts/verify/` and ship in the install bundle).
- `specs/033-reference-corpus-ingest/spec.md` exists and is the binding contract — FR-1 (taxonomy), FR-2 (provenance frontmatter), FR-4 (chunk-output shape additions), FR-17 (tier-policy declaration), and #Q-8 (per-category default tier proposals) are the requirements this task transcribes into SSOT files.
- T01 is the head of P00; no upstream task dependencies.

## Description

Author three declarative SSOT files that downstream phases (P02 extract, P04 ingest classifier, P05 graph traverser, P08 wiki nav) consume without modification — plus three structural shape verifiers that gate each file's contract. These three files are the load-bearing P00 deliverable: every M036 chunk lifecycle (extract → ingest → graph → dispatch → wiki) reads these to know what is in-policy.

The three SSOT files:

1. `references/reference-taxonomy.md` — names the four reference categories with definitions + example `cite_id` slugs (FR-1).
2. `references/reference-frontmatter-contract.md` — names every required FR-2 frontmatter field + chunk-output FR-4 additions + graph-edge fields (FR-5).
3. `references/reference-source-types.yaml` — declares the per-category default-tier policy (FR-17 + #Q-8 resolution).

The three shape verifiers (`tools/verify/p00-taxonomy-shape.sh`, `p00-frontmatter-contract-shape.sh`, `p00-source-types-shape.sh`) run `grep -q` checks per required header / field / key to assert structure. They do not validate semantics — semantic enforcement lands in T03's chunk-frontmatter validator library.

T01 ships ONLY taxonomy / contract / tier-policy + their shape verifiers. Edge types and adapter registry are T02; scope-tag extension and chunk validator are T03; phase-suite aggregator is T03.

## Steps

1. **Create `tools/verify/` if absent** (project-owned per AD-19): `mkdir -p tools/verify`.

2. **Author `references/reference-taxonomy.md`.** Required structure:

   ```markdown
   ---
   schema_version: "1.0"
   type: reference-taxonomy
   milestone: "M036"
   phase: "P00"
   created_at: "2026-05-01"
   ---

   # Reference Corpus Taxonomy (M036 SSOT)

   The orchestrator's reference-corpus ingest (M036, spec
   `specs/033-reference-corpus-ingest/spec.md`) recognizes a closed
   four-category taxonomy. Files declared with a `category` field
   outside this list are rejected at ingest (FR-1 / US-1 acceptance
   scenario 3).

   This file is the single source of truth (Principle XI). Consumers:
   - `scripts/knowledge/ingest-reference.sh` (P04) — classifier
   - `scripts/dispatch/extract.sh` (P02) — manifest validation
   - `scripts/wiki/build-nav.sh` (P08) — top-level nav generation
   - `references/reference-source-types.yaml` (P00) — keys must match

   Adding or removing a category requires a follow-on M036 D-row in
   [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) and a coordinated update across the
   four consumers above. Do not hardcode the list in any consumer.

   ## Categories

   ### cms-rule
   CMS-published regulatory rule. Citation-grade; small (typically
   <50 pages); structure (sections, tables) matters for verbatim
   quoting. Default extraction tier: 2 (clean structured Markdown).
   Example `cite_id`: `cms-rule-483-20`.

   ### training-material
   SME-authored training content (e.g., PBJ Circle decks). Already
   prose; relatively small; high reference value across many
   validator agents. Default extraction tier: 2. Example `cite_id`:
   `training-pbj-circle-2024-08`.

   ### glossary
   Definitional content (term → definition mappings). Frequently
   cited in narrow excerpts. Default extraction tier: 2. Example
   `cite_id`: `glossary-pbj-2024`.

   ### regulatory-doc
   Long-form regulatory documents (CMS state operations manuals,
   guidance bulletins). Often hundreds of pages; clean Markdown
   conversion is expensive and produces a worse retrieval surface
   than searchable plain text + read-section workflows. Default
   extraction tier: 1 (searchable text via `pdftotext -layout`).
   Example `cite_id`: `regulatory-cms-som-app-pp`.
   ```

   The four `### <category>` headings are load-bearing — the shape
   verifier greps for each of `cms-rule`, `training-material`,
   `glossary`, `regulatory-doc` plus the `## Categories` parent
   heading.

3. **Author `references/reference-frontmatter-contract.md`.** Required structure:

   ```markdown
   ---
   schema_version: "1.0"
   type: reference-frontmatter-contract
   milestone: "M036"
   phase: "P00"
   created_at: "2026-05-01"
   ---

   # Reference Chunk Frontmatter Contract (M036 SSOT)

   Every reference markdown file ingested by `orchestrator:ingest`
   into `knowledge/reference/<category>/REF-<cat>-<id>.md` MUST
   carry the following frontmatter. Files missing required fields
   are rejected at ingest (FR-2 / US-1 acceptance scenario 2).

   ## Required Fields

   - `source` — operator-facing identifier of the publishing body
     (e.g., `cms`, `sme-pbj-circle`, `internal-glossary`). String.
   - `published` — publication date in `YYYY-MM-DD` format. The
     extractor MAY auto-derive this from PDF/DOCX metadata; the
     operator manifest is the override path (Assumption A-2).
   - `version` — operator-supplied version string. Free-form;
     orchestrator does not parse semver. The supersede chain
     (FR-10) is content-hash-driven, not version-string-driven —
     `version` is human-facing only.
   - `cite_id` — unique stable identifier for citation. Must be
     unique within an ingest pass; duplicates are rejected (Edge
     Cases — "Two reference files declare the same `cite_id`").
   - `topic_tags` — YAML list (may be empty). Free-form tags
     consumed by dispatch injection (FR-7) for topic-scoped
     retrieval.
   - `applies_to_field` — YAML list (may be empty). Field names
     this content authoritatively governs (e.g., `staff_count`,
     `census`). Consumed by dispatch injection (FR-7) for
     field-scoped retrieval.

   ## Chunk-Output Additions

   Fields the ingest classifier writes into the emitted chunk's
   frontmatter (in addition to preserving the FR-2 fields above):

   - `category` — one of the four taxonomy values
     (`cms-rule|training-material|glossary|regulatory-doc`). See
     `references/reference-taxonomy.md`.
   - `chunk_id` — the assigned `REF-<cat>-<id>` slug.
   - `content_hash` — sha256 of the chunk body. Drives idempotent
     re-ingest (FR-9) and the supersede chain (FR-10).
   - `scope_tags` — YAML list of orchestrator scope tags
     (`[project]`, `[milestone:M###]`, `[source:<cite_id>]`, etc.).
     The `[source:...]` namespace is M036-introduced — see
     `references/file-formats.md` `### Scope Tags`.

   ## Graph Edge Fields

   Fields the ingest classifier interprets as graph edges into the
   `KNOWLEDGE-INDEX.md` graph. Each is a YAML list of `chunk_id`
   targets. Edge directionality is declared in
   `references/reference-edge-types.md`.

   - `cites` — chunk → reference. New in M036. Directional.
   - `derived_from` — chunk → upstream-source-chunk. New in M036.
     Directional (downstream → upstream).
   - `applies_to_field` — chunk → field-name. New in M036.
     (Note: `applies_to_field` is BOTH a frontmatter field name
     AND an edge type — the field is interpreted as an edge by
     the graph layer.)
   - `relates_to` — bidirectional. Pre-existing (M011/M020).
     Listed for completeness; not authored by M036.
   - `supersedes` — directional (newer → older). Pre-existing.
     Listed for completeness; not authored by M036.

   ## Validation

   Frontmatter validation is mechanical: `tools/verify/lib/p00-validate-chunk-frontmatter.sh`
   (T03 deliverable) reads stdin and rejects any chunk whose
   `category` is outside the taxonomy or whose `tier` (when
   present, used by the extract command) is outside `{0, 1, 2}`.
   ```

   The shape verifier greps for the four section headings
   (`## Required Fields`, `## Chunk-Output Additions`,
   `## Graph Edge Fields`, plus a `## Validation` section as a
   forward pointer) and every required-field name.

4. **Author `references/reference-source-types.yaml`.** Required structure:

   ```yaml
   # references/reference-source-types.yaml
   #
   # M036 SSOT for per-category default extraction tier (FR-17).
   # Consumers:
   #   - scripts/dispatch/extract.sh (P02) — resolves `tier` for
   #     manifest entries that don't declare a per-document override.
   #
   # The keys of `source_types:` MUST match the four categories in
   # references/reference-taxonomy.md exactly (Principle XI). The
   # taxonomy SSOT and this file are kept in lockstep — adding or
   # removing a category requires updating both files in the same
   # commit, gated by the M036 D-row that authorizes the change.
   #
   # `default_tier` is one of {0, 1, 2}. Out-of-enum values are
   # rejected by tools/verify/lib/p00-validate-chunk-frontmatter.sh
   # (T03 deliverable).
   #
   # Default rationales (per spec #Q-8 resolution at planning):
   #   - cms-rule:          2  (small, citation-grade, structure matters)
   #   - training-material: 2  (already prose, cheap LLM upgrade)
   #   - glossary:          2  (definitional, frequently cited)
   #   - regulatory-doc:    1  (long-form, clean conversion expensive;
   #                            grep+read-section is the load-bearing
   #                            retrieval pattern)

   schema_version: "1.0"
   type: reference-source-types
   milestone: "M036"
   phase: "P00"

   source_types:
     cms-rule:
       default_tier: 2
       rationale: "small, citation-grade, structure matters"
     training-material:
       default_tier: 2
       rationale: "already prose, cheap LLM upgrade"
     glossary:
       default_tier: 2
       rationale: "definitional, frequently cited"
     regulatory-doc:
       default_tier: 1
       rationale: "long-form; grep+read-section retrieval pattern"
   ```

   The shape verifier greps for the `source_types:` map header and
   each of the four taxonomy keys with `default_tier:` present.

5. **Author `tools/verify/p00-taxonomy-shape.sh`.** Bash 3.2-compatible. Behavior:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/p00-taxonomy-shape.sh — M036 P00 T01 shape gate for
   # references/reference-taxonomy.md. Asserts frontmatter + ## Categories
   # heading + each of the four taxonomy categories appears as a level-3
   # heading. Single-script-file shape per AD-19.
   set -eu
   FILE="${1:-references/reference-taxonomy.md}"
   pass=0; fail=0
   if [ ! -f "$FILE" ]; then
     echo "FAIL: $FILE missing"
     echo "SUMMARY: p00-taxonomy-shape.sh pass=0 fail=1"
     exit 1
   fi
   for token in 'schema_version' 'type: reference-taxonomy' '## Categories' '### cms-rule' '### training-material' '### glossary' '### regulatory-doc'; do
     if grep -qF "$token" "$FILE"; then
       pass=$((pass + 1))
     else
       fail=$((fail + 1))
       echo "FAIL: $FILE missing token: $token"
     fi
   done
   echo "SUMMARY: p00-taxonomy-shape.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

   Use `grep -qF` (fixed-string) to avoid regex confusion. Loop over
   token list — single command per iteration, no compound shells.

6. **Author `tools/verify/p00-frontmatter-contract-shape.sh`.** Same structural pattern as the taxonomy verifier. Token list:

   - `schema_version`
   - `type: reference-frontmatter-contract`
   - `## Required Fields`
   - `source`
   - `published`
   - `version`
   - `cite_id`
   - `topic_tags`
   - `applies_to_field`
   - `## Chunk-Output Additions`
   - `category`
   - `chunk_id`
   - `content_hash`
   - `scope_tags`
   - `## Graph Edge Fields`
   - `cites`
   - `derived_from`
   - `relates_to`
   - `supersedes`

   Same exit conventions and `SUMMARY:` line shape.

7. **Author `tools/verify/p00-source-types-shape.sh`.** Same pattern; token list:

   - `schema_version`
   - `type: reference-source-types`
   - `source_types:`
   - `cms-rule:`
   - `training-material:`
   - `glossary:`
   - `regulatory-doc:`
   - `default_tier:`

   Same exit conventions.

8. **Self-check.** Run all three verifiers from repo root:

   ```bash
   bash tools/verify/p00-taxonomy-shape.sh
   bash tools/verify/p00-frontmatter-contract-shape.sh
   bash tools/verify/p00-source-types-shape.sh
   ```

   All three exit 0 with `SUMMARY: <name> pass=N fail=0`.

## Must-Haves

This task satisfies these phase truths:

- "`references/reference-taxonomy.md` exists with frontmatter + four categories under `## Categories`" — T01 authors the file; `p00-taxonomy-shape.sh` gates.
- "`references/reference-frontmatter-contract.md` exists naming every FR-2 / FR-4 / FR-5 field" — T01 authors; `p00-frontmatter-contract-shape.sh` gates.
- "`references/reference-source-types.yaml` exists with four-key `source_types:` map and `default_tier:` per category" — T01 authors; `p00-source-types-shape.sh` gates.

This task does NOT satisfy:

- The edge-type SSOT truth (T02 deliverable).
- The adapter registry TSV truth (T02 deliverable).
- The scope-tag extension truths (T03).
- The taxonomy-rejects-unknown negative-test truth (T03).
- The phase-suite aggregator truth (T03).

## Verification

```bash
bash tools/verify/p00-taxonomy-shape.sh
bash tools/verify/p00-frontmatter-contract-shape.sh
bash tools/verify/p00-source-types-shape.sh
```

Each verifier uses single-script-file shape per AD-19. Each emits `SUMMARY: <script> pass=N fail=0` on success and exits 0.

## Inputs

### From Previous Tasks

- None (T01 is the head of P00).

### From Disk (Pre-existing)

- `specs/033-reference-corpus-ingest/spec.md` — FR-1 (closed taxonomy with the four named categories), FR-2 (six required frontmatter fields), FR-4 (chunk-output additions), FR-5 (three new edge types — informational here; T02 owns), FR-17 (tier-policy with per-category defaults), #Q-8 (default-tier proposals). Authoritative content source.
- `references/file-formats.md` — line 649 declares the existing `### Scope Tags` table. T01 does not modify this file (T03 does); T01 references it informationally in the frontmatter contract's `scope_tags` description.
- `references/` — 21 existing reference docs. T01 adds three new files (`reference-taxonomy.md`, `reference-frontmatter-contract.md`, `reference-source-types.yaml`) without modifying any existing files.

## Constraints

- **Bash 3.2 compatibility**: verifier scripts MUST NOT use `mapfile`/`readarray`, `declare -A`, process substitution `<(...)`, `&>`, or `${var^^}`. Use plain loops with `grep -qF` (fixed-string) — no `$(...)` containing pipes.
- **Single-script-file Truth Check shape (AD-19)**: each verifier is a standalone script invoked as `bash tools/verify/<name>.sh`. No inline compound bash, no plain subshells, no `$(...)` containing a pipe.
- **No semantic validation here**: T01 verifiers are *structural* (does the file contain the required headings / field names / map keys?). Semantic enforcement (does a synthetic chunk with `category: blog-post` actually fail validation?) is T03's job via `tools/verify/lib/p00-validate-chunk-frontmatter.sh` + `tools/verify/p00-taxonomy-rejects-unknown.sh`.
- **CON-2 (cli-first-bash)**: all new scripts are POSIX-sh / Bash 3.2 portable. No Python, no jq hard dependency.
- **CON-5 (no-spec-chunk-schema-change)**: T01 adds new SSOT files; does not modify any existing spec-chunk frontmatter / file layout / chain-walking rules.
- **Principle XI (Single Source of Truth)**: the taxonomy categories are listed in exactly two places — `reference-taxonomy.md` (authoritative) and `reference-source-types.yaml` (keys MUST match). The shape verifier checks both files independently; semantic equivalence is enforced informationally in commentary.

## Expected Output

- `references/reference-taxonomy.md` — created, ≥40 lines, four `### <category>` headings.
- `references/reference-frontmatter-contract.md` — created, ≥60 lines, four section headings + every required field name.
- `references/reference-source-types.yaml` — created, ≥30 lines, four-key `source_types:` map.
- `tools/verify/p00-taxonomy-shape.sh` — created, exits 0 against the new taxonomy file.
- `tools/verify/p00-frontmatter-contract-shape.sh` — created, exits 0 against the new contract file.
- `tools/verify/p00-source-types-shape.sh` — created, exits 0 against the new source-types YAML.

## Notes

Expected verifier output examples (for human readers, not for `auto-loop --step=V` evaluation):

- `bash tools/verify/p00-taxonomy-shape.sh` → stdout ends with `SUMMARY: p00-taxonomy-shape.sh pass=7 fail=0`, exit 0.
- `bash tools/verify/p00-frontmatter-contract-shape.sh` → stdout ends with `SUMMARY: p00-frontmatter-contract-shape.sh pass=19 fail=0`, exit 0.
- `bash tools/verify/p00-source-types-shape.sh` → stdout ends with `SUMMARY: p00-source-types-shape.sh pass=8 fail=0`, exit 0.

Per the planner-template Section-Discipline rule, expected output stays under `## Notes` — everything in `## Verification` is eval'd as a command by `auto-loop.sh --step=V`.

Path discipline (AD-19): all new verifier scripts live under `tools/verify/` (project-owned, slug-bearing filenames `p00-*-shape.sh`). The framework-owned verifier directory `scripts/verify/` is bulk-staged in downstream projects and gitignored — project-owned scripts there are at risk of install-clobber. Stay under `tools/verify/`.

## State Context

- **Current State**: executing
- **Milestone**: M036
- **Phase**: P00
- **Task**: T01-taxonomy-and-contract
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **Bash 3.2 compatibility**: verifier scripts MUST NOT use `mapfile`/`readarray`, `declare -A`, process substitution `<(...)`, `&>`, or `${var^^}`. Use plain loops with `grep -qF` (fixed-string) — no `$(...)` containing pipes.
- **Single-script-file Truth Check shape (AD-19)**: each verifier is a standalone script invoked as `bash tools/verify/<name>.sh`. No inline compound bash, no plain subshells, no `$(...)` containing a pipe.
- **No semantic validation here**: T01 verifiers are *structural* (does the file contain the required headings / field names / map keys?). Semantic enforcement (does a synthetic chunk with `category: blog-post` actually fail validation?) is T03's job via `tools/verify/lib/p00-validate-chunk-frontmatter.sh` + `tools/verify/p00-taxonomy-rejects-unknown.sh`.
- **CON-2 (cli-first-bash)**: all new scripts are POSIX-sh / Bash 3.2 portable. No Python, no jq hard dependency.
- **CON-5 (no-spec-chunk-schema-change)**: T01 adds new SSOT files; does not modify any existing spec-chunk frontmatter / file layout / chain-walking rules.
- **Principle XI (Single Source of Truth)**: the taxonomy categories are listed in exactly two places — `reference-taxonomy.md` (authoritative) and `reference-source-types.yaml` (keys MUST match). The shape verifier checks both files independently; semantic equivalence is enforced informationally in commentary.

### Acceptance Criteria

This task satisfies these phase truths:

- "`references/reference-taxonomy.md` exists with frontmatter + four categories under `## Categories`" — T01 authors the file; `p00-taxonomy-shape.sh` gates.
- "`references/reference-frontmatter-contract.md` exists naming every FR-2 / FR-4 / FR-5 field" — T01 authors; `p00-frontmatter-contract-shape.sh` gates.
- "`references/reference-source-types.yaml` exists with four-key `source_types:` map and `default_tier:` per category" — T01 authors; `p00-source-types-shape.sh` gates.

This task does NOT satisfy:

- The edge-type SSOT truth (T02 deliverable).
- The adapter registry TSV truth (T02 deliverable).
- The scope-tag extension truths (T03).
- The taxonomy-rejects-unknown negative-test truth (T03).
- The phase-suite aggregator truth (T03).

### Files To Touch

- `references/reference-taxonomy.md` (create) — T01
- `references/reference-frontmatter-contract.md` (create) — T01
- `references/reference-source-types.yaml` (create) — T01
- `references/reference-edge-types.md` (create) — T02
- `scripts/dispatch/adapters/format/registry.tsv` (create) — T02
- `references/file-formats.md` (modify — append fourth row to `### Scope Tags` table) — T03
- `references/spec-management.md` (modify — append cross-reference paragraph) — T03
- `tools/verify/p00-taxonomy-shape.sh` (create) — T01
- `tools/verify/p00-frontmatter-contract-shape.sh` (create) — T01
- `tools/verify/p00-source-types-shape.sh` (create) — T01
- `tools/verify/p00-edge-types-shape.sh` (create) — T02
- `tools/verify/p00-adapter-registry-shape.sh` (create) — T02
- `tools/verify/p00-scope-tag-extension.sh` (create) — T03
- `tools/verify/p00-spec-management-crossref.sh` (create) — T03
- `tools/verify/p00-taxonomy-rejects-unknown.sh` (create) — T03
- `tools/verify/lib/p00-validate-chunk-frontmatter.sh` (create) — T03
- `tools/verify/p00-phase-suite.sh` (create) — T03

<!-- The phase plan and task plan files themselves (this file +
     tasks/T0[1-3]-*-PLAN.md) are written by the planner, not by the
     executor — they are not listed here. -->

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