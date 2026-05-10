---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T04-drift-line-in-status (Phase P01, Milestone M035)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~200 | required |
| Upstream Context | 981-1086 | ~2200 | required |
| Task Plan | 1088-1437 | ~3700 | required |
| State Context | 1439-1445 | ~100 | required |
| First-Turn Completeness | 1447-1494 | ~600 | required |
| **Total** | | **~17600** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 858
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
hit_count: 858
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
hit_count: 858
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
hit_count: 858
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
hit_count: 748
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
hit_count: 748
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
hit_count: 748
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
hit_count: 858
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
hit_count: 748
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
hit_count: 748
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
hit_count: 748
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
hit_count: 858
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
hit_count: 858
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
hit_count: 858
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
hit_count: 748
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
hit_count: 748
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
hit_count: 748
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
hit_count: 858
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
hit_count: 748
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
hit_count: 748
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
hit_count: 858
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
hit_count: 858
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
hit_count: 748
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
hit_count: 748
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
hit_count: 748
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
hit_count: 403
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
hit_count: 403
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
hit_count: 403
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
hit_count: 434
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
hit_count: 434
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
hit_count: 424
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

- The `--mode=symlink|copy` flag is exposed user-facing on all three
  installers and routes to the same internal asset-mode-override
  variable; the M032-era TEST-ONLY `--asset-mode-override` flag remains
  recognised for backward compatibility (FR-1, US-1 acceptance scenario 1).
  - Check: `bash tools/verify/m035-p01-mode-flag.sh`

- After `install-claude-code.sh --mode=symlink` against a fresh fixture,
  `readlink <fixture>/scripts` resolves to the orchestrator source repo
  path (FR-1, US-1 acceptance scenario 1). The symlink target is
  `$REPO_ROOT/<src_rel>`, NOT a managed-runtime-cache subdirectory. This
  is a behaviour change from the M032/P01 implementation of
  `install-asset-mode.sh` symlink mode, motivated by the US-1
  dogfood-velocity contract.
  - Check: `bash tools/verify/m035-p01-symlink-source-target.sh`

- Mode-aware uninstall: against a `--mode=symlink` fixture, uninstall

<dispatch-volatile>

## Upstream Context


### P00 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P00"
parent: "M035"
milestone: "M035"
provides:
  - "bash-3.2 exit-status capture for project_assets install loops in all 3 installers; regression fixture + shape verifier for the masking pattern,managed .gitignore block emitter (FR-6/SC-6) for installer-owned sidecars; idempotent in-place block replacement; defensive duplicate-block collapse,wiki-stub freshness diagnostic (scripts/diagnostics/wiki-stubs-fresh.sh) + pages.yml pre-build gate; tmp-staged regen + diff approach (no live-tree mutation),[M032](../../../../../milestones/M032/index.md) SC-5 fixture-completeness fallback wired into wiki-init.sh --deploy step 2; [D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }") npm-name collision-check evidence captured at packaging/bundle/D-RN-1-evidence.txt; M035 P00 phase-suite aggregator (m035-p00-phase-suite.sh) authored per AD-19"
requires:
  - "none"
affects:
  - "P01"
key_files:
  - "packaging/install/install-claude-code.sh,packaging/install/install-codex.sh,packaging/install/install-cursor.sh,tools/verify/m035-p00-bash32-collision.sh,tests/installer-acceptance/m035-collision-exit-status.sh,scripts/lifecycle/emit-managed-gitignore.sh,tools/verify/m035-p00-managed-gitignore.sh,scripts/diagnostics/wiki-stubs-fresh.sh,scripts/lifecycle/wiki-init.sh,tools/verify/m035-p00-wiki-stubs-fresh.sh,packaging/bundle/D-RN-1-evidence.txt,tools/verify/m035-p00-wiki-deploy-stage.sh,tools/verify/m035-p00-npm-collision-evidence.sh,tools/verify/m035-p00-phase-suite.sh"
key_decisions:
  - "temp-file iteration over lastpipe (preserves bash 3.2 portability); explicit _producer_rc capture + early-exit gate; per-pass distinct temp file names (_collect_tmp/_dispatch_tmp/_manifest_tmp),opener/closer marker shape '# >>> orchestrator-managed: gitignore >>>' / '# <<< ... <<<' (mirrors CLAUDE.md orchestrator:recent-changes pattern); single-pass awk rewrite with state machine (in_block / seen_block / last_emitted_blank); separator policy = single blank line iff last emitted line was non-blank; helper-direct behaviour-layer fixtures + grep-based wiring layer (CI-portable across runtimes whose probes may fail),exit-code contract 0=fresh / 1=env-fail / 2=drift (per dispatch payload,redefining the prior in-tree script which used 1=drift / 2=env-fail); diagnostic operates against tmp-staged copy via cp -R (.orchestrator/,knowledge/,scripts/,templates/,wiki/) + run generators with --root <tmp> rather than mutating live wiki; mkdocs build --strict gate folded back into the diagnostic's PASS path was dropped — kept the diagnostic single-purpose (drift only) and let pages.yml run mkdocs build separately; existing-workflow CON-3 advisory message extension surfaces the gate in stderr without changing behavior,[D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }")=@build-fractal/orchestrator (unscoped 'orchestrator' on npm is TAKEN by orchestrator@0.3.8; @build-fractal scope AVAILABLE)"
patterns_established:
  - "process-substitution-fed-while-read masking is a bash-3.2 footgun; canonical replacement is mktemp + redirect + rc=$? + done < temp_file + rm -f,marker-delimited block primitive: opener + closer + body content; single helper script invoked identically from all 3 installers (mirrors install-meta.txt sidecar pattern); awk getline file pulls block body from temp file (avoids embedding multi-line strings in awk source); behaviour-layer testing via direct helper invocation when full installer run requires unavailable runtimes,tmp-staged regen-and-diff (cp -R sources,run generators with --root <tmp>,diff -ruN against committed tree) — reusable for any other freshness-gate diagnostic where the producer would otherwise mutate the live tree; printf '%s\n' '----- header -----' to side-step macOS bash printf interpreting leading hyphens as flags,missing-only stage-from-REPO_ROOT fallback for installer scripts where source-repo dirs may not have been bundled into PROJECT_DIR; phase-suite aggregator filename embeds milestone+phase prefix per AD-19 (m035-p00-phase-suite.sh)"
drill_down_paths:
  - "[.orchestrator/milestones/M035/phases/P00/tasks/T01-SUMMARY.md](../../../../../milestones/M035/phases/P00/tasks/T01-SUMMARY.md), [.orchestrator/milestones/M035/phases/P00/tasks/T02-SUMMARY.md](../../../../../milestones/M035/phases/P00/tasks/T02-SUMMARY.md), [.orchestrator/milestones/M035/phases/P00/tasks/T03-SUMMARY.md](../../../../../milestones/M035/phases/P00/tasks/T03-SUMMARY.md), [.orchestrator/milestones/M035/phases/P00/tasks/T04-SUMMARY.md](../../../../../milestones/M035/phases/P00/tasks/T04-SUMMARY.md)"
duration: "145m"
verification_result: "pass"
completed_at: "2026-05-08T12:28:10Z"
observability_surfaces:
  - "none"
---

P00 closes the pre-launch dev-ergonomics surface for M035: it hardens the
three installers against silent failure modes that would otherwise blow up
during the real publish event in P02–P06, and clears two M032 carryovers
(SC-5 fixture-completeness gap, wiki-stub drift) that would have surfaced
as papercuts on the first multi-consumer dogfood run.

Four tasks landed:

- T01 replaced nine process-substitution-fed `while read` loops (3 per
  installer × 3 installers) with the temp-file iteration form. The bash
  3.2 footgun: `done < <(bash producer.sh)` does not propagate the
  producer's exit status to the outer installer, so a malformed manifest
  or missing project-asset key was silently swallowed and the installer
  reported success. The replacement captures `_producer_rc=$?` after a
  `> $tmp` redirect and exits non-zero on any failure. A regression
  fixture (`tests/installer-acceptance/m035-collision-exit-status.sh`)
  exercises the producer-failure path against all three installers and
  records `BASH_VERSION` in its run header — the bash 3.2 vs bash 4+
  matrix wiring lands at P05/P02 when the publishing CI exists.

- T02 introduced a marker-delimited managed `.gitignore` block primitive
  (FR-6 / SC-6). Each installer now invokes
  `scripts/lifecycle/emit-managed-gitignore.sh` after the
  `install-meta.txt` write step. The helper uses a single-pass awk
  rewrite (state machine: in_block / seen_block / last_emitted_blank) to
  guarantee idempotency: re-runs replace the block contents in place,
  duplicate blocks collapse to one, and content outside the markers is
  preserved byte-for-byte. Future M035 P05 rollback markers
  (`.previous-version` per FR-12) extend this block via the helper's
  `--block-content` hook.

- T03 shipped the wiki-stubs-fresh diagnostic
  (`scripts/diagnostics/wiki-stubs-fresh.sh`) and wired it into
  `wiki-init.sh emit_pages_workflow()`'s pages.yml HEREDOC as a pre-build
  gate. The diagnostic stages `.orchestrator/`, `knowledge/`, `scripts/`,
  `templates/`, and `wiki/` under `mktemp -d`, runs the stub and nav
  generators with `--root <tmp>`, then diffs against the committed wiki
  tree. Exit codes: `0=fresh`, `1=env failure`, `2=drift`. The CON-3
  existing-workflow preservation branch in `wiki-init.sh:483-486` is
  untouched — operators with an authored `pages.yml` keep ownership and
  see a stderr advisory recommending the gate. The diagnostic immediately
  earned its keep during T04 itself: writing T04-SUMMARY.md drifted the
  committed wiki, the gate fired loud, and the regen + re-verify cycle
  closed the loop. This is the new normal — every task that authors a
  spec/state file under `.orchestrator/` will require a wiki regen before
  the phase-suite goes green.

- T04 closed three loose ends in one task: (a) the M032 SC-5
  deferred-validation gap — `wiki-init.sh --deploy` step 2 now stages
  `wiki-deploy.sh` from `$REPO_ROOT` when the project copy is missing,
  removing the operator-side install precondition for the deploy path;
  (b) [D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }") npm-name collision-check evidence captured at
  `packaging/bundle/D-RN-1-evidence.txt` (npm view confirmed unscoped
  `orchestrator` is TAKEN by `orchestrator@0.3.8` and
  `@build-fractal/orchestrator` is AVAILABLE — resolution
  `[D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }"): @build-fractal/orchestrator` per RENAME-PLAN.md fallback);
  (c) the M035 P00 phase-suite aggregator
  (`tools/verify/m035-p00-phase-suite.sh`) — filename embeds the
  `m035-p00-` milestone+phase prefix per AD-19 path discipline (the
  unprefixed `p00-phase-suite.sh` shape silently clobbered [M030](../../../../../milestones/M030/index.md)'s
  aggregator with [M031](../../../../../milestones/M031/index.md)'s, and M031's with [M036](../../../../../milestones/M036/index.md)'s; this filename never
  collides).

Verification: phase-suite battery `pass=5 fail=0` on all 5 task-grain
verifiers. Lock held throughout; no blockers, budget under at 4 tasks /
145m duration.

P01 (orchestrator:status version-drift warning) inherits an installer
tree that propagates exit status, a `.gitignore` block primitive ready
for `.previous-version` rollback markers, and a wiki tooling chain that
will surface drift loud rather than silently break `mkdocs build`.
P02–P06 (the publishing pipelines) inherit installer hardening that
prevents the "first user runs `npm install -g … && orchestrator init`
and the symlink loop swallows a manifest error" failure mode.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M035"
name: "FR-4 drift line in [M029](../../../../../milestones/M029/index.md) status headline + status-headline-shape.md addendum + phase-suite aggregator"
depends_on: ["T03"]
---

## Prerequisites

Files that MUST exist on disk at task entry (verified at plan-authoring time):

- `scripts/state/check-orchestrator-drift.sh` (authored by T03;
  emits the structured `key=value` block consumed here)
- `commands/status.md` (M029/P01-shipped TUI render path; carries
  the headline+flat-sections wiring per `references/status-headline-shape.md`)
- `scripts/diagnostics/render-status-json.sh` (M029/P01-shipped
  JSON render path; carries the headline-fields-as-JSON-keys
  contract; `_M029_SCHEMA_VERSION="1.0"`)
- `references/status-headline-shape.md` (M029/P01 design contract;
  this task appends a documented addendum, does not redefine the
  three-line headline regex)
- `tests/m035-acceptance/fixtures/install-meta-with-sha.txt`,
  `tests/m035-acceptance/fixtures/install-meta-pre-m035.txt` (from T01)

Pre-existing decisions consumed:

- `references/status-headline-shape.md` § Embedded Footer (line 87-110):
  the embedded footer line is a documented optional 4th line.
  M035 P01's drift line is a 5th optional line; the regex for the
  three byte-stable headline lines is unchanged.
- AD-4 (M035 discuss): M035 contributes the drift datum, M029 renders.
  The change here is in M029's render code (which M035 owns the right
  to extend per AD-4); the M029 regex contract for lines 1-3 is
  preserved byte-for-byte — SC-2 of M029's spec stays green.
- FR-16 / `update_source: none`: rendering suppression policy.

## Description

Wire the T03 drift helper's stdout into both render paths
(`commands/status.md` TUI + `render-status-json.sh` JSON) so the
documented `STALE: orchestrator runtime is N commits behind upstream
— run \`orchestrator:update\`` line appears as a 5th optional headline
line when `commits_behind > 0`, and is suppressed cleanly when
`update_source=none`, when `commits_behind=0`, and when the drift
helper itself is unavailable.

This task also authors the M035 P01 phase-suite aggregator
(`tools/verify/m035-p01-phase-suite.sh`) per the AD-19 path-discipline
naming convention, and appends the § Drift Line (M035 P01) addendum
to `references/status-headline-shape.md` so the contract is on disk
for downstream scrapers.

## Steps

1. **Update `commands/status.md`** to consume the drift helper. The
   exact wiring is documented as a render step in the LLM-instruction
   skill body (the file is markdown, not bash). The new step appears
   AFTER the embedded efficiency-footer step, BEFORE the existing flat
   sections begin. Pseudocode-shape addition (in the actual file,
   render the change as a documented step + bash snippet, mirroring
   how the headline + footer steps are documented today):

   ```markdown
   > **Drift line (M035 P01 / FR-4 / SC-4).** After the embedded footer
   > line, invoke `bash scripts/state/check-orchestrator-drift.sh
   > --consumer "$PROJECT_DIR" 2>/dev/null`. Parse the structured stdout:
   >
   >   commits_behind=<value>
   >   update_source=<git|npm|homebrew|none>
   >   versions_behind=<value>
   >
   > Suppression matrix (FR-4, FR-16):
   > - `update_source=none` → emit nothing.
   > - `commits_behind=0` AND `versions_behind=0` → emit nothing.
   > - drift helper exits non-zero or output unparseable → emit nothing
   >   (degrade gracefully per Edge Case line 181).
   >
   > Otherwise emit exactly one line, byte-stable:
   >
   >   `STALE: orchestrator runtime is N commits behind upstream — run \`orchestrator:update\``
   >
   > where N is `commits_behind` when numeric, or the literal `unknown`
   > when the SHA-absent fallback fired (the rendered line says
   > `unknown commits behind` in that case; the user-visible advisory
   > line in stderr from the helper has already explained the cause).
   ```

   The actual edit appends this block to `commands/status.md` between
   the existing footer-block and the flat-sections-invariant block.

2. **Update `scripts/diagnostics/render-status-json.sh`** to add a
   new top-level field `drift` to the JSON envelope. Schema:

   ```json
   {
     "schema_version": "1.0",
     "milestone_id": "...",
     "...": "...",
     "drift": {
       "commits_behind": "<integer-or-string-unknown>",
       "update_source": "git|npm|homebrew|none",
       "upstream_path": "<absolute-path-or-empty>",
       "versions_behind": "<integer>",
       "rendered_line": "<exact-string-rendered-by-tui-or-empty>"
     }
   }
   ```

   Implementation: invoke the helper, parse the four fields with
   `sed -n 's/^commits_behind=\(.*\)$/\1/p'` etc., build the `drift`
   object via the existing jq-based assembly path. When the helper
   is unavailable or `update_source=none`, emit
   `"drift": {"update_source": "none", "commits_behind": 0, "versions_behind": 0, "rendered_line": ""}`.

   **Schema-version policy**: the addition of the `drift` field is
   an additive schema change. Per AD-7 stability policy at
   `references/status-json-schema.md`, additive top-level fields do
   NOT bump `_M029_SCHEMA_VERSION`. The M029 cross-check verifier
   that asserts `schema_version == "1.0"` byte-for-byte stays green.
   Document this decision inline in `render-status-json.sh` next
   to the drift-emission code so future readers know the addition
   was intentional.

3. **Append § Drift Line (M035 P01) to `references/status-headline-shape.md`**.
   New section after § CON-5 Suppression Matrix. Body:

   ```markdown
   ## Drift Line (M035 P01)

   The drift line is an optional FIFTH line that appears after the
   three byte-stable headline lines and the embedded efficiency-footer
   line. It is governed by the `update_source` config value and the
   `commits_behind` / `versions_behind` data emitted by
   `scripts/state/check-orchestrator-drift.sh` (M035 P01 / FR-3).

   ### Render Conditions

   The drift line renders if-and-only-if ALL of:
     - `update_source != none` (FR-16 suppression honor)
     - `commits_behind > 0` OR `versions_behind > 0`
     - the drift helper exited 0 with parseable stdout

   ### Line Shape

   When rendered, the line is byte-stable:

       STALE: orchestrator runtime is <N> commits behind upstream — run `orchestrator:update`

   where:
     - `<N>` is the integer `commits_behind` value when numeric.
     - `<N>` is the literal token `unknown` when the SHA-absent
       fallback fired (#Q-G5 / SC-3b path); the user-visible advisory
       in the helper's stderr has already explained the cause.

   The em-dash separator is U+2014 (`—`). The backticks around
   `orchestrator:update` are literal backticks. Renderers MUST NOT
   substitute hyphens for the em-dash.

   ### JSON-side Field

   Under `--format=json`, the drift datum appears as the top-level
   `drift` object:

   ```json
   "drift": {
     "commits_behind": "<integer-or-string-unknown>",
     "update_source": "git|npm|homebrew|none",
     "upstream_path": "<absolute-path-or-empty>",
     "versions_behind": "<integer>",
     "rendered_line": "<exact-string-rendered-by-tui-or-empty>"
   }
   ```

   The `rendered_line` field is empty when suppression conditions fire.

   ### M029 Contract Preservation

   The three byte-stable headline lines (`line1`, `line2`, `line3`) and
   their POSIX-extended regexes in § Regex above are UNCHANGED. The
   drift line is additive: existing M029 SC-2 scrapers continue to
   pass byte-for-byte. The M035 SC-4 scraper greps for the
   `^STALE: orchestrator runtime is .*$` pattern below the embedded
   footer line.

   ### Drift Line Regex

       drift-line: ^STALE: orchestrator runtime is ([0-9]+|unknown) commits behind upstream — run `orchestrator:update`$
   ```

4. **Author `tools/verify/m035-p01-drift-line-in-status.sh`** (SC-4
   primary path). Stage a fixture project + fixture upstream-repo
   (mirror of T03's verifier setup), copy the SHA-bearing
   `install-meta.txt`, write `config.yml` pointing at the upstream,
   then assert:

   - `bash commands/status.md`-equivalent invocation (or
     `scripts/diagnostics/render-status-json.sh` for the JSON path)
     emits stdout containing exactly one line matching the
     documented drift-line regex.
   - Both TUI and JSON paths are exercised — TUI via the rendered
     stdout, JSON via `jq -e '.drift.rendered_line | test("STALE")'`.

   Single-script-file shape per AD-19.

5. **Author `tools/verify/m035-p01-drift-line-suppressed.sh`**
   (SC-4 suppression paths). Three sub-cases:

   a. Toggle `update_source: none` in fixture config; assert
      no `STALE:` line in either render output.
   b. Stage a fixture whose `install-meta.txt` SHA matches the
      fixture upstream's HEAD (`commits_behind=0`); assert no
      `STALE:` line.
   c. Stage a fixture whose `.orchestrator/install-meta.txt` is
      missing entirely (drift helper degrades gracefully); assert
      no `STALE:` line.

   For each sub-case, also assert that the THREE byte-stable
   headline lines are present (the M029 contract is preserved).

   Single-script-file shape per AD-19.

6. **Author `tools/verify/m035-p01-phase-suite.sh`** (the AD-19-prefixed
   phase aggregator; mirrors `tools/verify/m035-p00-phase-suite.sh` from
   M035 P00). Aggregates all P01 task-grain verifiers:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p01-phase-suite.sh — M035 P01 phase aggregator.
   # Filename embeds the m035-p01- milestone+phase prefix per AD-19
   # path discipline (the unprefixed p01-phase-suite.sh shape silently
   # clobbered prior milestones' aggregators in the M030/M031/M036
   # observed regression series, 2026-05-01).
   set -u
   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   suite=(
     m035-p01-mode-flag
     m035-p01-symlink-source-target
     m035-p01-mode-aware-uninstall
     m035-p01-drift-detection
     m035-p01-drift-detection-sha-absent
     m035-p01-drift-line-in-status
     m035-p01-drift-line-suppressed
   )
   pass=0; fail=0
   for v in "${suite[@]}"; do
     if bash "$REPO_ROOT/tools/verify/${v}.sh" >/dev/null 2>&1; then
       pass=$((pass + 1))
     else
       fail=$((fail + 1))
       echo "FAIL: $v" >&2
     fi
   done
   echo "BATTERY: pass=$pass fail=$fail"
   if [ "$fail" -eq 0 ]; then exit 0; fi
   exit 1
   ```

   The naming convention (milestone+phase prefix) is mandatory per
   AD-19 / commands/plan-phase.md "Naming convention" rule —
   `tools/verify/p01-phase-suite.sh` would silently clobber every
   prior milestone's P01 aggregator.

## Must-Haves

- Drift line renders against SC-3 fixture (TUI + JSON)
  - Check: `bash tools/verify/m035-p01-drift-line-in-status.sh`
- Drift line suppressed under `update_source=none` / no-drift / unavailable
  - Check: `bash tools/verify/m035-p01-drift-line-suppressed.sh`

## Verification

```bash
bash tools/verify/m035-p01-drift-line-in-status.sh
bash tools/verify/m035-p01-drift-line-suppressed.sh
bash tools/verify/m035-p01-phase-suite.sh
```

## Inputs

### From Previous Tasks

- `scripts/state/check-orchestrator-drift.sh` (from T03)
  - Key API: `bash scripts/state/check-orchestrator-drift.sh --consumer <path>`; emits a four-line key=value block on stdout (`commits_behind=`, `update_source=`, `upstream_path=`, `versions_behind=`); exit 0 always.
  - Stderr: optional one-line advisory under SHA-absent fallback.
- T03's verifier upstream-fixture pattern (referenced for SC-4 verifier scaffolding).

### From Disk (Pre-existing)

- `commands/status.md` — render path; T04 appends one block (the drift-line render step) between the embedded-footer block and the flat-sections-invariant block.
- `scripts/diagnostics/render-status-json.sh` — JSON renderer; T04 adds the `drift` top-level field. The schema_version constant `_M029_SCHEMA_VERSION` stays at `"1.0"` (additive change per AD-7 policy).
- `references/status-headline-shape.md` — M029 contract; T04 appends § Drift Line (M035 P01) below the existing § CON-5 Suppression Matrix.
- `references/status-json-schema.md` — JSON schema doc (M029); T04 also appends the `drift` field documentation here so the cross-check verifier (which asserts the two files agree) stays green.

## Constraints

- **M029 SC-2 preservation**: the three byte-stable headline lines
  and their regex contract at `references/status-headline-shape.md`
  § Regex are UNCHANGED. M029 acceptance battery stays green.
- **AD-7 schema-version policy**: additive `drift` field does NOT
  bump `_M029_SCHEMA_VERSION`. The M029 cross-check verifier that
  asserts `schema_version == "1.0"` byte-for-byte stays green.
- **FR-15 (read-only)**: T04 reads from `check-orchestrator-drift.sh`
  and renders. No state writes.
- **FR-16 (suppression)**: rendered-line suppression honors
  `update_source: none` + `commits_behind=0` + helper-unavailable.
- **AD-19 path discipline**: phase-suite aggregator filename
  embeds the `m035-p01-` milestone+phase prefix.

## Notes

- Expected verifier outputs:
  - `PASS: m035-p01-drift-line-in-status`
  - `PASS: m035-p01-drift-line-suppressed`
  - `BATTERY: pass=7 fail=0` from the phase-suite aggregator.
- **Plan-phase verifier-availability cross-check (rule 2)**: every
  verifier referenced in T04's `## Verification` section is authored
  in this task (steps 4-6).
- **Plan-phase classifier-shape pre-validation (rule 3)**: every
  proposed `Check:` command is a single-script-file invocation. The
  internal verifier bodies use `case`, `[ ... ] && [ ... ]` two-token
  pairs (below the AP-009 compound-chain-gt2 threshold), and `jq -e`
  invocations — all below the shape-guard threshold.
- **Plan-phase real-DB rule (rule 5)**: not applicable — no SQL
  surface in P01.
- **CON-3 / shape-guard interaction in verifier bodies**: any time
  the verifier needs to chain `cmd1 && cmd2 && cmd3` it should
  refactor to a `case` block or sequential statements separated by
  newlines, not a 3+ inline `&&` chain. This is the same discipline
  the M035 P00 verifiers follow.

## Expected Output

After T04 completes:

- `commands/status.md` carries the drift-line render step between
  the embedded footer step and the flat-sections-invariant block.
- `scripts/diagnostics/render-status-json.sh` emits the `drift`
  top-level field; `_M029_SCHEMA_VERSION="1.0"` unchanged.
- `references/status-headline-shape.md` carries § Drift Line (M035 P01).
- `references/status-json-schema.md` documents the `drift` field.
- Three new verifiers exist (`m035-p01-drift-line-in-status.sh`,
  `m035-p01-drift-line-suppressed.sh`, `m035-p01-phase-suite.sh`)
  and PASS against the new state.
- Phase-suite aggregator emits `BATTERY: pass=7 fail=0` covering
  every P01 task-grain verifier.

## State Context

- **Current State**: executing
- **Milestone**: M035
- **Phase**: P01
- **Task**: T04-drift-line-in-status
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **M029 SC-2 preservation**: the three byte-stable headline lines
  and their regex contract at `references/status-headline-shape.md`
  § Regex are UNCHANGED. M029 acceptance battery stays green.
- **AD-7 schema-version policy**: additive `drift` field does NOT
  bump `_M029_SCHEMA_VERSION`. The M029 cross-check verifier that
  asserts `schema_version == "1.0"` byte-for-byte stays green.
- **FR-15 (read-only)**: T04 reads from `check-orchestrator-drift.sh`
  and renders. No state writes.
- **FR-16 (suppression)**: rendered-line suppression honors
  `update_source: none` + `commits_behind=0` + helper-unavailable.
- **AD-19 path discipline**: phase-suite aggregator filename
  embeds the `m035-p01-` milestone+phase prefix.

### Acceptance Criteria

- Drift line renders against SC-3 fixture (TUI + JSON)
  - Check: `bash tools/verify/m035-p01-drift-line-in-status.sh`
- Drift line suppressed under `update_source=none` / no-drift / unavailable
  - Check: `bash tools/verify/m035-p01-drift-line-suppressed.sh`

### Files To Touch

- `packaging/install/install-claude-code.sh` (modify) — `--mode` flag, install-meta.txt fields, mode-aware manifest write + uninstall dispatch
- `packaging/install/install-codex.sh` (modify) — same as above
- `packaging/install/install-cursor.sh` (modify) — same as above
- `scripts/lifecycle/install-asset-mode.sh` (modify) — symlink branch retargeted to `$SRC` directly; advisory stderr message updated
- `scripts/state/check-orchestrator-drift.sh` (create)
- `scripts/diagnostics/render-status-json.sh` (modify) — drift field in JSON render path
- `commands/status.md` (modify) — drift line in TUI render path; consumes `check-orchestrator-drift.sh`
- `references/installation.md` (modify) — § Symlink-mode caveats; § Rollback-and-symlink-mode-interaction
- `references/status-headline-shape.md` (modify) — § Drift Line (M035 P01) addendum
- `tests/m035-acceptance/fixtures/install-meta-with-sha.txt` (create)
- `tests/m035-acceptance/fixtures/install-meta-pre-m035.txt` (create)
- `tools/verify/m035-p01-mode-flag.sh` (create)
- `tools/verify/m035-p01-symlink-source-target.sh` (create)
- `tools/verify/m035-p01-mode-aware-uninstall.sh` (create)
- `tools/verify/m035-p01-drift-detection.sh` (create)
- `tools/verify/m035-p01-drift-detection-sha-absent.sh` (create)
- `tools/verify/m035-p01-drift-line-in-status.sh` (create)
- `tools/verify/m035-p01-drift-line-suppressed.sh` (create)
- `tools/verify/m035-p01-phase-suite.sh` (create)

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