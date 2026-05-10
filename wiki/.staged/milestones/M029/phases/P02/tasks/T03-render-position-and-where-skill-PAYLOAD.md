---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T03-render-position-and-where-skill (Phase P02, Milestone M029)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~600 | required |
| Upstream Context | 981-1045 | ~3200 | required |
| Task Plan | 1047-1328 | ~5300 | required |
| State Context | 1330-1336 | ~100 | required |
| First-Turn Completeness | 1338-1395 | ~1100 | required |
| **Total** | | **~21100** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 836
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
hit_count: 836
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
hit_count: 836
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
hit_count: 836
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
hit_count: 727
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
hit_count: 727
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
hit_count: 727
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
hit_count: 836
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
hit_count: 727
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
hit_count: 727
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
hit_count: 727
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
hit_count: 836
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
hit_count: 836
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
hit_count: 836
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
hit_count: 727
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
hit_count: 727
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
hit_count: 727
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
hit_count: 836
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
hit_count: 727
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
hit_count: 727
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
hit_count: 836
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
hit_count: 836
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
hit_count: 727
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
hit_count: 727
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
hit_count: 727
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
hit_count: 382
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
hit_count: 382
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
hit_count: 382
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
hit_count: 412
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
hit_count: 412
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
hit_count: 402
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

<!-- Behavioral truths that scripts/verify/check-must-haves.sh checks via the bound script-file shape (AD-19). Every Check is a single bash <path> invocation; no inline compound, no plain subshell, no $() with pipes. Project-owned per-phase verifiers live under tools/verify/ with the m029-p02-* slug prefix; framework-owned verifiers live under scripts/verify/. -->

- The AD-6 cross-milestone data-model contract document exists at `references/cross-milestone-feature-shape.md` and pins the exactly-one-of `milestone:` ⊕ `milestones:` rule + reverse-lookup advisory + collapsed/expanded inactive-render shape (#Q-5 resolution).
  - Check: `bash tools/verify/m029-p02-cross-milestone-shape-contract.sh`

- `scripts/diagnostics/summarize-milestone.sh` exists, is executable, emits a fixed-order key=value block (`phase_count=...`, `phases_complete=...`, `tasks_remaining=...`, `intensity=...`) read-only against the active milestone, and accepts `--milestone <M###>` as the AD-4 SC-8 oracle interface.
  - Check: `bash tools/verify/m029-p02-summarize-milestone-shape.sh`

- `scripts/diagnostics/render-position.sh` exists, is executable, sources the AD-1 invocation-context resolver and emits a tree using the documented glyph set (`✓ ▶ ◇ ✗ ▽`) with milestone progress bar + per-row cost column, suppresses the cost column silently on pre-M019 milestones (FR-6/CON-3), and never invokes `gh` / GitHub APIs (FR-11/CON-4/SC-13).
  - Check: `bash tools/verify/m029-p02-render-position-shape.sh`

- `commands/where.md` exists with the canonical 8-section command-doc shape, declares read-only discipline (CON-1/FR-14), references `scripts/diagnostics/render-position.sh` + `scripts/state/detect-invocation-context.sh` + `references/cross-milestone-feature-shape.md`, and embeds the documented glyph legend.
  - Check: `bash tools/verify/m029-p02-where-skill-shape.sh`

- The SC-5 mixed-state golden fixture covers all four glyph states (`✓ ▶ ◇ ✗`) and is byte-stable under the #Q-G6 enumerated timestamp-strip regex set; `tests/m029-acceptance/timestamp-strip.sh` enumerates exactly the #Q-G6 patterns; the FR-8 marker canonical form `▽ saved Nk` (#Q-G8 resolution) is the only form that appears in fixtures and verifiers (no `▽ 4k saved` or `▽ saved Nk via tier1 cache reuse` strings anywhere in P02 deliverables).
  - Check: `bash tools/verify/m029-p02-sc5-fixtures-shape.sh`

<dispatch-volatile>

## Upstream Context


### P01 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M029"
milestone: "M029"
provides:
  - "Principle III design contracts for FR-2 status headline + FR-3 status --format=json; gate verifiers that mechanically enforce field,regex,and key presence so downstream tasks (T03/T04) cannot drift from the contracts,AD-1 single-resolve invocation-context resolver (scripts/state/detect-invocation-context.sh) emitting renderer/exit_code_scheme/default_provider env block consumed by every M029 surface; SC-1 acceptance script + two shape verifiers gating downstream drift,FR-2 status headline block additions to commands/status.md (## Headline Block section + 5 Reference Files entries) plus SC-2 fixture milestone tree (M999 in executing state with one complete phase + one in-flight phase + populated execution-log.jsonl) plus SC-2 acceptance script (regex assertion + flat-section byte-identity diff + CON-5 footer-suppression test) plus two shape verifiers gating downstream drift,JSON renderer (FR-3) + commands/status.md --format=json wiring (FR-3 + AD-2 + AD-7) + SC-3 fixtures + acceptance + three shape verifiers,orchestrator:context FR-4 single-screen runtime-profile skill (commands/context.md) + SC-4 fixture/script + 2 verifiers,P01 phase-close gate: SC-11 acceptance battery (SC-1..SC-4 slice) + 3 close-gate verifiers + 14-gate phase-suite aggregator"
requires:
  - "none"
affects:
  - "P02"
key_files:
  - "references/status-headline-shape.md,references/status-json-schema.md,tools/verify/m029-p01-headline-shape-contract.sh,tools/verify/m029-p01-json-schema-contract.sh,scripts/state/detect-invocation-context.sh,tests/m029-acceptance/p01-sc1-resolver.sh,tools/verify/m029-p01-invocation-context-resolver-shape.sh,tools/verify/m029-p01-sc1-shape.sh,commands/status.md,tests/m029-acceptance/fixtures/status-headline-executing.fixture/milestones/M999/M999-ROADMAP.md,tests/m029-acceptance/fixtures/status-headline-executing.fixture/milestones/M999/phases/P01/P01-SUMMARY.md,tests/m029-acceptance/fixtures/status-headline-executing.fixture/milestones/M999/execution-log.jsonl,tests/m029-acceptance/p01-sc2-headline.sh,tools/verify/m029-p01-status-headline-shape.sh,tools/verify/m029-p01-sc2-shape.sh,scripts/diagnostics/render-status-json.sh,tests/m029-acceptance/p01-sc3-format-json.sh,tests/m029-acceptance/fixtures/status-json-executing.fixture,tests/m029-acceptance/fixtures/status-json-degraded.fixture,tools/verify/m029-p01-render-status-json-shape.sh,tools/verify/m029-p01-status-format-json-wiring.sh,tools/verify/m029-p01-sc3-shape.sh,commands/context.md,tests/m029-acceptance/p01-sc4-context.sh,tests/m029-acceptance/fixtures/context-minimal.fixture/,tools/verify/m029-p01-context-skill-shape.sh,tools/verify/m029-p01-sc4-shape.sh,tests/m029-acceptance/p01-acceptance-battery.sh,tools/verify/m029-p01-acceptance-battery-shape.sh,tools/verify/m029-p01-readonly-invariant.sh,tools/verify/m029-p01-scope-guard.sh,tools/verify/m029-p01-phase-suite.sh"
key_decisions:
  - "AD-1 single-resolve invocation context discipline,AD-2 unconditional ANSI strip under --format=json,AD-7 schema_version 1.0 from day 1 + stability policy,Principle III design contracts upstream of code,AD-1 single-resolve invocation context (renderer/exit_code_scheme/default_provider env block as SSOT for every M029 surface),Principle XI (no surface re-derives TTY/CI/runtime detection),CON-1/FR-14 read-only resolver,FR-2 (status headline block as 3 non-blank lines packing 5 fields),SC-2 (headline regex + flat-section byte-identity invariant),CON-5 (suppression-matrix inheritance from [M027](../../../../../milestones/M027/index.md) efficiency_footer knob),AD-1 (single-resolve invocation context consumed by headline path),AD-2,AD-7,AD-1,AD-1 single-resolve at command entry; SC-2 embedded-reference-renderer pattern reused; sentinel-file precursor for SC-14; new minimal fixture (not SC-2 reuse) for .orchestrator/-rooted read-only check,AD-19 linear bash invocation pattern; sentinel-file find -newer as SC-14 precursor; conservative scope-guard (WARN advisory for unclassified paths,FAIL only on denylist hits); battery / phase-suite split (battery embeds in milestone validator,phase-suite is per-phase close gate)"
patterns_established:
  - "paired design contracts cross-checked by gate verifiers in both directions; verifiers assert field/regex/key presence rather than just file existence so downstream consumers cannot silently drift,three-helper resolver shape (_resolve_renderer / _resolve_exit_code_scheme / _resolve_default_provider) emitting fixed-order key=value env block; test-injection flags (--tty/--ci) decouple resolution from real TTY state for SC-1 fixturing; shape verifier asserts field names + values + fixed-order stdout regex so downstream consumers cannot drift silently,reference-renderer-in-acceptance-script (SC-2 embeds an inline m029_render_status function mirroring commands/status.md instructions because the command is an LLM-instruction document,not an executable script -- the function is test-internal and explicitly NOT a production code path); fixture-milestone-tree-under-orch-root (fixture root contains milestones/M999/ matching find-active-milestone.sh probe shape); flat-section-byte-identity-via-tail-skip (SC-2 trims headline+blank+footer-block+blank prefix via tail -n +N then diffs against M029_DISABLE_HEADLINE=1 baseline); CON-5 footer-off path keeps headline (suppression knob disappears footer line ONLY,headline 3 lines remain),single ANSI-strip site (AD-2); _M029_SCHEMA_VERSION constant as renderer-side SSOT cross-checked against schema doc; jq -n --arg safe JSON construction; degraded-state envelope (state + parse_errors) on corrupt JSONL never crashes the renderer,LLM-instruction-doc skills get an embedded reference renderer in their acceptance script; sentinel-file find -newer is the precursor for the AD-9 SC-14 mechanism,phase-suite aggregator structure mirrors m031-p00-phase-suite.sh (linear bash <path> + emit_gate_result + final SUMMARY); acceptance-battery wrapper aggregates SC scripts and emits BATTERY: line; scope-guard combines git status --porcelain=v1 with allowlist/denylist classification + WARN: advisory for unclassified"
drill_down_paths:
  - "[.orchestrator/milestones/M029/phases/P01/tasks/T01-design-contracts-SUMMARY.md](../../../../../milestones/M029/phases/P01/tasks/T01-design-contracts-SUMMARY.md), [.orchestrator/milestones/M029/phases/P01/tasks/T02-invocation-context-resolver-SUMMARY.md](../../../../../milestones/M029/phases/P01/tasks/T02-invocation-context-resolver-SUMMARY.md), [.orchestrator/milestones/M029/phases/P01/tasks/T03-status-headline-block-SUMMARY.md](../../../../../milestones/M029/phases/P01/tasks/T03-status-headline-block-SUMMARY.md), [.orchestrator/milestones/M029/phases/P01/tasks/T04-status-json-format-SUMMARY.md](../../../../../milestones/M029/phases/P01/tasks/T04-status-json-format-SUMMARY.md), [.orchestrator/milestones/M029/phases/P01/tasks/T05-context-skill-SUMMARY.md](../../../../../milestones/M029/phases/P01/tasks/T05-context-skill-SUMMARY.md), [.orchestrator/milestones/M029/phases/P01/tasks/T06-acceptance-and-phase-suite-SUMMARY.md](../../../../../milestones/M029/phases/P01/tasks/T06-acceptance-and-phase-suite-SUMMARY.md)"
duration: "9m"
verification_result: "pass"
completed_at: "2026-05-05T23:29:31Z"
observability_surfaces:
  - "none"
---

M029/P01 ships the entire `orchestrator:status` headline + `--format=json` + `orchestrator:context` skill surface, gated by mechanically-enforced design contracts and a 14-gate phase-suite aggregator.

**What was built (six tasks, all PASS):**

- **T01 — design contracts (Principle III).** Two paired contract documents: `references/status-headline-shape.md` (FR-2 — five fields, three-line packing, SC-2 regex, CON-5 inheritance) and `references/status-json-schema.md` (FR-3 — `schema_version: "1.0"` from day 1 per AD-7, ten required top-level keys, AD-2 unconditional ANSI strip, degraded-state envelope). Two gate verifiers (`m029-p01-headline-shape-contract.sh` 20/20, `m029-p01-json-schema-contract.sh` 31/31) assert every header / regex token / top-level key / spec reference rather than mere existence — so T03/T04 cannot silently drift.

- **T02 — AD-1 single-resolve invocation-context resolver.** `scripts/state/detect-invocation-context.sh` emits a fixed-order three-line env block (`renderer=…`, `exit_code_scheme=…`, `default_provider=…`) consumed by every downstream M029 surface; no T03/T04/T05 code path re-derives TTY/CI/runtime detection. Test-injection flags (`--tty`, `--ci`) decouple resolution from real TTY state for SC-1 fixturing. SC-1 acceptance covers all four AD-1 cases (CI-forces-plain-over-TTY, `--format=json`-wins, unknown-flag exit-2-with-stderr-usage, plain-fallback).

- **T03 — FR-2 status headline block.** Additive `## Headline Block` section + 5 Reference Files entries in `commands/status.md`. SC-2 fixture milestone tree (M999 in executing state, valid M019 Tier 1 dispatch_usage + unit_close records). SC-2 acceptance asserts the regex shape, the flat-section byte-identity invariant (M027 / [M013](../../../../../milestones/M013/index.md) / M019 sections must be unchanged after headline insertion), and CON-5 footer-suppression inheritance.

- **T04 — FR-3 `--format=json`.** `scripts/diagnostics/render-status-json.sh` is the SINGLE AD-2 ANSI-strip site for JSON output, declares `_M029_SCHEMA_VERSION="1.0"` cross-checked against the schema doc, uses `jq -n --arg` for safe JSON construction, and emits a degraded-state envelope (`state="degraded"` + `parse_errors[]`) on corrupt JSONL without crashing. `commands/status.md` gains a `## Format Flag` section between Headline Block and State Derivation. SC-3 covers the executing-state and degraded-state fixture trees.

- **T05 — FR-4 `orchestrator:context` skill.** `commands/context.md` (canonical 8-section command-doc shape, single-screen ≤ 24 lines, six labeled fields, AD-1 single-resolve discipline, read-only contract). SC-4 acceptance via embedded reference renderer (SC-2 precedent for LLM-instruction-doc skills) against a new minimal fixture (`<root>/.orchestrator/...` shape required by the sentinel-file precursor for AD-9/SC-14).

- **T06 — close gate.** SC-11 acceptance battery (`p01-acceptance-battery.sh`, chains SC-1..SC-4 → 4/4 PASS), 14-gate phase-suite aggregator (`m029-p01-phase-suite.sh`, mirrors `m031-p00-phase-suite.sh` shape), CON-1/FR-14 readonly-invariant verifier (sentinel-file `find -newer` precursor for SC-14), conservative scope-guard (denylist FAIL + WARN-on-unclassified).

**Verification.** Phase-suite **14/14 PASS**, acceptance battery **4/4 PASS**, full 4-tier `orchestrator:verify` PASS (Tier 1: 116/116, Tier 2: phase-suite 14/14 + battery 4/4, Tier 3: behavioral spot-checks confirm AD-1 / AD-2 / FR-2-3-4, Tier 4: N/A — no human-review must-haves at phase grain).

**Patterns established (load-bearing for P02 and downstream M029 phases):**

1. **Paired design contracts cross-checked by gate verifiers in both directions** — each verifier asserts the companion contract is referenced, enforcing the pairing invariant. T03/T04 cannot silently drift from the FR-2/FR-3 specs.
2. **Three-helper resolver shape with fixed-order env block** — `_resolve_renderer` / `_resolve_exit_code_scheme` / `_resolve_default_provider`. AD-1 single-resolve discipline is now mechanical.
3. **Reference-renderer-in-acceptance-script** for LLM-instruction-doc skills (SC-2 / SC-4 pattern). The function is test-internal and explicitly NOT a production code path; production rendering is performed by an LLM agent reading the `.md` skill doc.
4. **Single ANSI-strip site (AD-2)** + `jq -n --arg` safe JSON construction + degraded-state envelope on corrupt JSONL.
5. **Phase-suite aggregator + acceptance battery split** — battery wraps SC scripts (re-used by milestone validator), phase-suite is the per-phase close gate (mirrors `m031-p00-phase-suite.sh`).
6. **Sentinel-file `find -newer` mechanism** as the precursor for the AD-9 SC-14 milestone-grain readonly-invariant gate.
7. **Conservative scope-guard** — `git status --porcelain=v1` × allowlist/denylist classification, FAIL only on denylist hits, WARN: advisory for unclassified.

**Plan-shape paper-cut surfaced and patched in-flight.** T04/T05/T06 task plans listed "creates these phase artifacts" using bare-backtick bullets (`- \`path\``), which the auto-loop verify-step parser at `scripts/lifecycle/auto-loop.sh:359-369` matches as bare-backtick command bullets and `eval`s. Bullets resolving to directories (T04 fixtures) or non-executable markdown (T05 `commands/context.md`) failed verification as a parser-shape false positive even though the actual `## Verification` block was green. Repaired the three plans in-flight to use the T01/T02/T03 convention `- \`path\` — description.` (description after the backtick keeps the bullet off the bare-backtick parser regex). Followup: planner template should default to the description-suffixed shape so future task plans don't surface this; deliverables themselves are unaffected.

**Decisions register.** AD-1 (single-resolve), AD-2 (unconditional strip), AD-7 (`schema_version: "1.0"` lock), AD-19 (linear bash invocation pattern preserved end-to-end). All on disk in the per-task SUMMARYs.

**P02 unblocked** — `orchestrator:where` tree renderer phase consumes the resolver, the headline, the JSON shape, and the phase-suite aggregator scaffolding from P01.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M029"
name: "render-position.sh + commands/where.md (FR-5, FR-6, CON-3, CON-4)"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 has landed: `references/cross-milestone-feature-shape.md` is on disk; verify `[ -f references/cross-milestone-feature-shape.md ]`. T03 reads it as the AD-6 schema authority.
- T02 has landed: `scripts/diagnostics/summarize-milestone.sh` is on disk and executable; verify `[ -x scripts/diagnostics/summarize-milestone.sh ]`. T03 invokes it for inactive-milestone summary lines.
- P01 deliverables on disk and verified: `scripts/state/detect-invocation-context.sh` (AD-1 single-resolve resolver — `[ -x scripts/state/detect-invocation-context.sh ]`), `references/status-headline-shape.md`, `references/status-json-schema.md`.
- M027 surfaces on disk (closed milestone, read-only consumers): `scripts/diagnostics/metrics-rollup.sh`, `scripts/diagnostics/efficiency-footer.sh`. Verify `[ -x scripts/diagnostics/metrics-rollup.sh ]`.
- M019 JSONL schema on disk: `.orchestrator/milestones/M*/execution-log.jsonl` paths exist for closed milestones (read-only consumer).
- `scripts/state/read-roadmap.sh` and `scripts/state/find-active-milestone.sh` exist and are executable.
- No file currently lives at `scripts/diagnostics/render-position.sh` or `commands/where.md` (path-collision rule 6 already checked at plan-authoring time — clean).

## Description

T03 ships **two coupled deliverables** that together satisfy FR-5 (where renderer), FR-6 (cost-column graceful degradation), CON-3 (silent suppression), CON-4 (no GitHub API on render), CON-1/FR-14 (read-only):

1. **`scripts/diagnostics/render-position.sh`** — the at-rest tree renderer. Reads:
   - The AD-1 resolver's env block (`renderer`, `exit_code_scheme`, `default_provider`).
   - The active feature spec frontmatter (`milestone:` singular OR `milestones:` plural per AD-6).
   - Each milestone's `M###-ROADMAP.md` for phase ordering.
   - Each phase's `P##-PLAN.md` / `P##-SUMMARY.md` / `tasks/T##-*-{PLAN,SUMMARY}.md` for state derivation.
   - `metrics-rollup.sh --granularity task` for the per-row cost column on M019-Tier-1-equipped milestones.
   - `summarize-milestone.sh --format=keys` for collapsed inactive-milestone summary lines.
   - `scripts/lifecycle/lock-manager.sh` (read-only probe) for lock state if relevant to the headline.
   - The reverse-lookup advisory (T01 contract): enumerate `.orchestrator/milestones/M*/M*-EVALUATION.md`, group by `feature_ref:`, emit `WARN:` on mismatch, render-from-spec.

   Emits a tree to stdout using the canonical glyph alphabet from `references/cross-milestone-feature-shape.md`:
   - `✓` complete, `▶` executing, `◇` pending, `✗` failed, `▽` saved-Nk (P03 live-only; T03 never emits this glyph itself).

   Renderer flags:
   - `--milestone <M###>` (active-only view; default behavior is the FULL feature view per FR-13).
   - `--expand-all` (#Q-5: expand inactive milestones).
   - `--feature <slug>` (override the active feature; used by SC-5 fixture to point at a known feature).
   - `--no-cost` (operator-side cost-column suppression; FR-6's pre-M019 detection is automatic and silent).
   - `--root <path>` (override `.orchestrator/` root for fixturing; required by SC-5 / SC-6 / SC-14 fixtures).
   - `--help` / `-h`.

2. **`commands/where.md`** — the canonical 8-section command-doc shape mirrored from P01's `commands/context.md`. The command document is an LLM-instruction skill (per T05/P01 pattern); production rendering is performed by an agent reading the skill, but the skill instructs the agent to invoke `render-position.sh` and pass its output through unchanged. The skill must:
   - Reference `scripts/diagnostics/render-position.sh` in the Referenced Scripts section.
   - Reference `scripts/state/detect-invocation-context.sh` (AD-1 single-resolve discipline).
   - Reference `references/cross-milestone-feature-shape.md` (AD-6 contract).
   - Embed the canonical glyph legend.
   - Declare the read-only contract (CON-1 / FR-14): no writes to `.orchestrator/`.
   - Declare CON-4 (no GitHub API): the skill MUST NOT invoke `gh` or any GitHub HTTP API; the M013 sidecar at `.orchestrator/integrations/github.json` is NOT read in v1.

## Steps

1. **Create `scripts/diagnostics/render-position.sh`** (≥120 lines, executable, bash 3.2 compatible per MEM001).

   - Header: re-source guard, `_RP_SCRIPT_DIR`, `_RP_PROJECT_ROOT`, the standard read-only declaration, AD-1/AD-6/AD-19/CON-1/CON-3/CON-4 cross-references in the comment block.
   - Argument parser: handles `--milestone`, `--expand-all`, `--feature`, `--no-cost`, `--root`, `-h`/`--help`, default error on unknown flag with exit 2.
   - Resolve invocation context via `bash "$_RP_PROJECT_ROOT/scripts/state/detect-invocation-context.sh" --format=plain` (AD-1 single-resolve; capture stdout into a temp file under `${TMPDIR:-/tmp}/m029-rp.$$/` to avoid `$(…)` pipe). Read the four lines back via `grep -E '^renderer=' "$tmp"`.
   - Resolve the feature: if `--feature` is set, use that slug; otherwise glob `specs/*/spec.md` and pick the spec whose frontmatter `milestone:` or `milestones:` includes the active milestone (from `find-active-milestone.sh`).
   - Parse the spec frontmatter to extract milestone list (singular `milestone:` → `[M###]`; plural `milestones: [M###, M###]` → list).
   - For each milestone in the list:
     - Read `M###-ROADMAP.md` for milestone name + phase IDs.
     - For each phase ID: state-derive via P##-SUMMARY.md exists (✓), tasks dir but no SUMMARY (▶), no plan (◇), last-verify=fail in execution-log.jsonl (✗).
     - For the in-flight phase: enumerate tasks from `tasks/T##-*-PLAN.md` and emit each task's status glyph.
     - Per-row cost column: invoke `metrics-rollup.sh --granularity task --milestone M### --phase P## --task T##` ONLY when the milestone has M019 Tier 1 records (detect via `[ -s execution-log.jsonl ]` + a single `grep -m1 -F '"record_type":"dispatch_usage"'` probe). On detection-miss, OMIT the cost column entirely — no blank column, no stderr warning (FR-6 / CON-3).
   - Active milestone is always expanded; inactive milestones default to collapsed (one summary line via `summarize-milestone.sh`); `--expand-all` expands every milestone.
   - Render the milestone progress bar using `▓░` + percentage (`▓░ 33% (1/3 phases)`).
   - Reverse-lookup advisory: enumerate `.orchestrator/milestones/M*/M*-EVALUATION.md`, group by `feature_ref:` (read frontmatter), compare to spec's declaration, emit `WARN: feature <slug> spec frontmatter declares <set>; reverse-lookup discovered <set>; using spec` to stderr on mismatch. Continue rendering from the spec's declaration.
   - Read-only invariant: NO writes to `.orchestrator/`. The only writes the script may perform are to `${TMPDIR:-/tmp}/m029-rp.$$/` (per `run-probe.sh` scope rule 4 — `/tmp/` is the staged probe domain). Clean up the temp directory on EXIT via `trap`.

   Reference structural shape (NOT a literal full implementation; the executor authors the implementation following this skeleton):

   ```bash
   #!/usr/bin/env bash
   # scripts/diagnostics/render-position.sh -- M029 / FR-5 at-rest tree renderer.
   #
   # Reads (no writes): feature spec frontmatter, M###-ROADMAP.md, P##-PLAN/SUMMARY.md,
   # T##-*-PLAN/SUMMARY.md, execution-log.jsonl (only for FR-6 detection probe),
   # metrics-rollup.sh (--granularity task), summarize-milestone.sh.
   #
   # Glyph alphabet: ✓ (complete) ▶ (executing) ◇ (pending) ✗ (failed); ▽ savings
   # is P03 live-only and NEVER emitted by this at-rest renderer.
   #
   # Read-only (CON-1 / FR-14). Bash 3.2 (MEM001). No GitHub API (CON-4 / FR-11).
   # AD-1 single-resolve via detect-invocation-context.sh. AD-6 cross-milestone
   # data model per references/cross-milestone-feature-shape.md.
   #
   # See M029 spec FR-5/FR-6/FR-13/CON-1/CON-3/CON-4 and M029-CONTEXT AD-1/AD-6.

   set -u
   if [ -n "${_RENDER_POSITION_SH_SOURCED:-}" ]; then return 0 2>/dev/null || exit 0; fi
   _RENDER_POSITION_SH_SOURCED=1

   _RP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   _RP_PROJECT_ROOT="$(cd "$_RP_SCRIPT_DIR/../.." && pwd)"

   # ... argument parser, helpers, render loop ...

   exit 0
   ```

2. **`chmod +x scripts/diagnostics/render-position.sh`**.

3. **Create `commands/where.md`** (≥60 lines). Required sections (mirrors `commands/context.md` 8-section shape):

   ```markdown
   ---
   description: "Use when a developer wants to see the full work hierarchy at a glance — feature → milestone → phases → tasks → current dispatch — with per-row cost columns and progress bars. Renders read-only from on-disk state."
   ---

   # orchestrator:where

   Read-only tree renderer for the work hierarchy. Composes existing M013/M018/M019/M027 surfaces into a glanceable view; never mutates state; never invokes GitHub APIs.

   ## Prerequisites / State Check

   - The active milestone resolves via `scripts/state/find-active-milestone.sh` (returns NONE if no milestone is active; the renderer prints a one-line "no active milestone" notice).
   - Invocation context is single-resolved via `scripts/state/detect-invocation-context.sh` (AD-1).

   ## Core Workflow

   1. Resolve invocation context.
   2. Invoke `scripts/diagnostics/render-position.sh` with the operator's flags forwarded unchanged.
   3. Print the renderer's stdout verbatim.
   4. On non-zero exit, surface the renderer's stderr unchanged.

   ## Glyph Legend

   - `✓` — phase or task complete.
   - `▶` — phase or task currently executing.
   - `◇` — phase or task pending (not yet started).
   - `✗` — phase or task failed (last verify result was `fail`).
   - `▽` — savings marker (P03 `--live` mode only; the canonical compact form is `▽ saved Nk`).

   ## Flags

   - `--milestone <M###>`: render only the named milestone (active-only view).
   - `--expand-all`: expand every milestone's full phase tree (default: inactive milestones are collapsed).
   - `--feature <slug>`: override the active feature; used for testing.
   - `--no-cost`: suppress the per-row cost column.
   - `--root <path>`: override the `.orchestrator/` root (fixturing).

   ## Output

   Tree on stdout. Reads-only; never writes to `.orchestrator/`. ANSI color when TTY=true; auto-stripped when piped or under CI per the AD-1 resolver.

   ## Idempotency

   `where` is read-only and produces identical output for identical disk state.

   ## Error Handling

   - No active milestone → one-line notice; exit 0.
   - Spec frontmatter missing both `milestone:` and `milestones:` → "feature <slug> declares no milestone; nothing to render"; exit 0.
   - Reverse-lookup mismatch → `WARN:` on stderr; render proceeds from spec's declaration.

   ## Constraints

   - **Read-only (CON-1 / FR-14)**: no writes to `.orchestrator/`. The only allowed write site is `${TMPDIR:-/tmp}/m029-rp.$$/` for transient resolver capture.
   - **No GitHub API (CON-4 / FR-11)**: the renderer MUST NOT invoke `gh` or any GitHub HTTP API; the M013 sidecar at `.orchestrator/integrations/github.json` is NOT read in v1. Enforced by SC-13's anti-coupling guard.

   ## Referenced Scripts

   - `scripts/diagnostics/render-position.sh` — the renderer engine.
   - `scripts/state/detect-invocation-context.sh` — AD-1 single-resolve resolver.
   - `scripts/state/find-active-milestone.sh` — active-milestone resolver.
   - `scripts/diagnostics/summarize-milestone.sh` — collapsed inactive-milestone summary helper.
   - `scripts/diagnostics/metrics-rollup.sh` — per-row cost column source (M027, read-only).

   ## Reference Files

   - `references/cross-milestone-feature-shape.md` — AD-6 cross-milestone schema contract.
   - `references/status-headline-shape.md` — sibling P01 contract; `where`'s tree reuses the headline field vocabulary in its top-of-tree summary line.
   - [`.orchestrator/milestones/M029/M029-CONTEXT.md`](../../../../../milestones/M029/M029-CONTEXT.md) — AD-1 / AD-6 / AD-9 authorities.
   ```

4. **Author `tools/verify/m029-p02-render-position-shape.sh`** (≥35 lines, executable, AD-19 single-script-file shape):
   - Asserts `[ -f scripts/diagnostics/render-position.sh ]` and `[ -x scripts/diagnostics/render-position.sh ]`.
   - Asserts (via `grep -F` per assertion, parallel indexed arrays for pass/fail tracking) the script declares the four glyphs literally: `✓`, `▶`, `◇`, `✗`. Asserts `▽` is referenced (in a comment naming P03's live-mode use).
   - Asserts the AD-19 forbidden shape `via tier1 cache reuse` does NOT appear (no v1 verbose form).
   - Asserts the read-only contract token (`Read-only` or `CON-1` or `FR-14`) appears in the header.
   - Asserts the CON-4 / FR-11 anti-coupling token (`No GitHub API` or `CON-4` or `FR-11`) appears in the header.
   - Asserts the script does NOT contain the literal substring `/integrations/github` (anti-coupling enforcement; complements SC-13).
   - Asserts the script invokes `detect-invocation-context.sh` (AD-1).
   - Asserts the script invokes `metrics-rollup.sh` (M027 cost column source) AND that the FR-6 detection probe pattern is present (grep for `dispatch_usage` literal).
   - Asserts the bash 3.2 compatibility token (`Bash 3.2` or `MEM001`) appears.
   - Emits `PASS:` per assertion + final `SUMMARY: m029-p02-render-position-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

5. **Author `tools/verify/m029-p02-where-skill-shape.sh`** (≥30 lines, executable, AD-19 single-script-file shape):
   - Asserts `[ -f commands/where.md ]`.
   - Asserts every required H2 section exists (`## Prerequisites`, `## Core Workflow`, `## Glyph Legend`, `## Flags`, `## Output`, `## Idempotency`, `## Error Handling`, `## Constraints`, `## Referenced Scripts`, `## Reference Files`).
   - Asserts the canonical glyphs each appear literally: `✓`, `▶`, `◇`, `✗`, `▽`.
   - Asserts `scripts/diagnostics/render-position.sh` is referenced.
   - Asserts `scripts/state/detect-invocation-context.sh` is referenced (AD-1 single-resolve).
   - Asserts `references/cross-milestone-feature-shape.md` is referenced.
   - Asserts the read-only contract token appears.
   - Asserts the CON-4 token appears.
   - Asserts the literal substring `/integrations/github` does NOT appear in `commands/where.md` (anti-coupling enforcement).
   - Asserts the canonical compact form `▽ saved Nk` appears AND the verbose form `via tier1 cache reuse` does NOT appear (#Q-G8).
   - Emits `PASS:` per assertion + final `SUMMARY: m029-p02-where-skill-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

6. **`chmod +x` both verifiers**.

## Must-Haves

This task addresses these P02 phase truths:
- `scripts/diagnostics/render-position.sh` exists, is executable, sources the AD-1 resolver, emits the canonical glyph set, suppresses cost column silently on pre-M019 milestones, and never invokes GitHub APIs.
- `commands/where.md` exists with the canonical 8-section command-doc shape, declares read-only discipline, references `render-position.sh` + `detect-invocation-context.sh` + `cross-milestone-feature-shape.md`, and embeds the glyph legend.

This task creates these P02 phase artifacts:
- Tree renderer engine at `scripts/diagnostics/render-position.sh` — FR-5 / FR-6 / CON-1 / CON-3 / CON-4 implementation.
- `orchestrator:where` skill doc at `commands/where.md` — LLM-instruction skill that invokes the renderer.
- Renderer shape verifier at `tools/verify/m029-p02-render-position-shape.sh` — mechanical glyph + read-only + anti-coupling enforcement.
- Skill shape verifier at `tools/verify/m029-p02-where-skill-shape.sh` — mechanical 8-section + reference + glyph enforcement.

## Verification

```bash
bash tools/verify/m029-p02-render-position-shape.sh
```

```bash
bash tools/verify/m029-p02-where-skill-shape.sh
```

## Inputs

### From Previous Tasks

- `references/cross-milestone-feature-shape.md` (from T01)
  - Key API: documents the AD-6 schema (`milestone:` singular vs `milestones:` plural), reverse-lookup advisory, inactive-render shape, glyph alphabet.
  - Key types: feature-spec frontmatter shape; T03 parses these per the contract.
- `scripts/diagnostics/summarize-milestone.sh` (from T02)
  - Key API: `bash scripts/diagnostics/summarize-milestone.sh --milestone <M###> --format=keys` emits four lines: `phase_count=`, `phases_complete=`, `tasks_remaining=`, `intensity=`.
  - Key types: fixed-order key=value block on stdout; exit 0 on success, 2 on usage error.

### From Disk (Pre-existing)

- `scripts/state/detect-invocation-context.sh` (P01) — AD-1 single-resolve resolver. T03 invokes via `bash <path>` and reads stdout-captured-to-tempfile (no `$(…)` pipe).
- `scripts/state/find-active-milestone.sh` — active-milestone resolver. T03 invokes for default-milestone resolution.
- `scripts/state/read-roadmap.sh` — roadmap parser. T03 invokes for phase-list extraction.
- `scripts/diagnostics/metrics-rollup.sh` (M027) — per-row cost column source. T03 invokes with `--granularity task --milestone M### --phase P## --task T##`. Read-only.
- `scripts/diagnostics/efficiency-footer.sh` (M027) — comment-header style precedent for read-only diagnostic helpers.
- `references/status-headline-shape.md` (P01) — vocabulary precedent for top-of-tree summary line.
- `commands/context.md` (P01) — 8-section command-doc shape precedent.
- `commands/status.md` (P01) — sibling skill that the operator hits at session resume; `commands/where.md` is the tree-view counterpart.

## Constraints

- **Read-only (CON-1 / FR-14)**: no writes to `.orchestrator/`. Allowed write site: `${TMPDIR:-/tmp}/m029-rp.$$/` for transient capture.
- **No GitHub API (CON-4 / FR-11)**: NO `gh` invocations, NO HTTP calls, NO read of `.orchestrator/integrations/github.json`. SC-13 enforces this with `grep -r '/integrations/github'` against `render-position.sh`.
- **Bash 3.2 (MEM001)**: no `declare -A`, no process substitution, no `<<<`, no `$(cmd | …)` in public surface (awk/sed pipes inside script body are permitted per MEM004 carve-out).
- **AD-19 verifier shape**: gate verifiers MUST be straight-line bash. NO inline compound chains, NO plain subshells, NO `$(cmd | grep …)`, NO process substitution.
- **AD-1 single-resolve discipline (Principle XI)**: T03 MUST NOT re-derive TTY/CI/runtime detection; it reads from `detect-invocation-context.sh` exclusively.
- **CON-7 + AD-8 knowledge-layer boundary**: T03 introduces NO new schema additions to M013 sidecar, M019 JSONL, M020 KNOWLEDGE.md, or M027 surfaces. Reads M027 / M019 surfaces only; never modifies.
- **No M027 modification**: `render-position.sh` MUST NOT modify `metrics-rollup.sh`, `efficiency-footer.sh`, or `predictive-surface.sh`. These are read-only consumers.
- **Glyph alphabet (#Q-G8)**: the canonical compact savings form is `▽ saved Nk`; the verbose form `via tier1 cache reuse` MUST NOT appear in T03 deliverables. The `▽` glyph itself is P03 live-only; T03 must reference it (in comments / glyph legend) but MUST NOT emit it from the at-rest renderer.

## Expected Output

After T03 completes:
- `scripts/diagnostics/render-position.sh` exists, is executable, and runs without error against the active M029 milestone (a smoke-test invocation `bash scripts/diagnostics/render-position.sh --milestone M029 > /tmp/where-smoke.$$` should exit 0; full SC-5 acceptance lands in T04 against the dedicated mixed-state fixture).
- `commands/where.md` exists with all 8 required sections.
- `tools/verify/m029-p02-render-position-shape.sh` exists, is executable, exits 0 from project root.
- `tools/verify/m029-p02-where-skill-shape.sh` exists, is executable, exits 0 from project root.
- A summary file at [`.orchestrator/milestones/M029/phases/P02/tasks/T03-render-position-and-where-skill-SUMMARY.md`](../../../../../milestones/M029/phases/P02/tasks/T03-render-position-and-where-skill-SUMMARY.md) documents the deliverables.

## Notes

Expected verifier output:
- `m029-p02-render-position-shape.sh`: `PASS:` per assertion (≈10–14), `SUMMARY: m029-p02-render-position-shape.sh pass=N fail=0`.
- `m029-p02-where-skill-shape.sh`: `PASS:` per assertion (≈12–16), `SUMMARY: m029-p02-where-skill-shape.sh pass=N fail=0`.

The phase-suite aggregator (T05) chains these as gates 3 and 4.

The full SC-5 byte-identical golden-render assertion does NOT land in T03; it lands in T04 alongside the dedicated mixed-state fixture. T03's verifiers are SHAPE checks (does the renderer reference the right surfaces; does the skill have the right sections); T04's verifiers are BEHAVIORAL (does the renderer produce the byte-identical golden output). This is intentional — T03's gates run quickly even before fixtures exist, so the shape problems surface before the more expensive behavioral assertions.

Why `where` is an LLM-instruction skill rather than a thin wrapper script: the SC-5 fixture compares the byte-stream emitted by the renderer engine (`render-position.sh`), not by an agent. The skill exists because the operator invokes `orchestrator:where` (an LLM command) which delegates to the engine; production rendering is performed by the engine, not the agent. This mirrors P01's `commands/context.md` precedent — the agent reads the skill, invokes the script, prints the output.

## State Context

- **Current State**: executing
- **Milestone**: M029
- **Phase**: P02
- **Task**: T03-render-position-and-where-skill
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **Read-only (CON-1 / FR-14)**: no writes to `.orchestrator/`. Allowed write site: `${TMPDIR:-/tmp}/m029-rp.$$/` for transient capture.
- **No GitHub API (CON-4 / FR-11)**: NO `gh` invocations, NO HTTP calls, NO read of `.orchestrator/integrations/github.json`. SC-13 enforces this with `grep -r '/integrations/github'` against `render-position.sh`.
- **Bash 3.2 (MEM001)**: no `declare -A`, no process substitution, no `<<<`, no `$(cmd | …)` in public surface (awk/sed pipes inside script body are permitted per MEM004 carve-out).
- **AD-19 verifier shape**: gate verifiers MUST be straight-line bash. NO inline compound chains, NO plain subshells, NO `$(cmd | grep …)`, NO process substitution.
- **AD-1 single-resolve discipline (Principle XI)**: T03 MUST NOT re-derive TTY/CI/runtime detection; it reads from `detect-invocation-context.sh` exclusively.
- **CON-7 + AD-8 knowledge-layer boundary**: T03 introduces NO new schema additions to M013 sidecar, M019 JSONL, M020 KNOWLEDGE.md, or M027 surfaces. Reads M027 / M019 surfaces only; never modifies.
- **No M027 modification**: `render-position.sh` MUST NOT modify `metrics-rollup.sh`, `efficiency-footer.sh`, or `predictive-surface.sh`. These are read-only consumers.
- **Glyph alphabet (#Q-G8)**: the canonical compact savings form is `▽ saved Nk`; the verbose form `via tier1 cache reuse` MUST NOT appear in T03 deliverables. The `▽` glyph itself is P03 live-only; T03 must reference it (in comments / glyph legend) but MUST NOT emit it from the at-rest renderer.

### Acceptance Criteria

This task addresses these P02 phase truths:
- `scripts/diagnostics/render-position.sh` exists, is executable, sources the AD-1 resolver, emits the canonical glyph set, suppresses cost column silently on pre-M019 milestones, and never invokes GitHub APIs.
- `commands/where.md` exists with the canonical 8-section command-doc shape, declares read-only discipline, references `render-position.sh` + `detect-invocation-context.sh` + `cross-milestone-feature-shape.md`, and embeds the glyph legend.

This task creates these P02 phase artifacts:
- Tree renderer engine at `scripts/diagnostics/render-position.sh` — FR-5 / FR-6 / CON-1 / CON-3 / CON-4 implementation.
- `orchestrator:where` skill doc at `commands/where.md` — LLM-instruction skill that invokes the renderer.
- Renderer shape verifier at `tools/verify/m029-p02-render-position-shape.sh` — mechanical glyph + read-only + anti-coupling enforcement.
- Skill shape verifier at `tools/verify/m029-p02-where-skill-shape.sh` — mechanical 8-section + reference + glyph enforcement.

### Files To Touch

- `references/cross-milestone-feature-shape.md` (create)
- `scripts/diagnostics/summarize-milestone.sh` (create)
- `scripts/diagnostics/render-position.sh` (create)
- `commands/where.md` (create)
- `tests/m029-acceptance/fixtures/where-mixed-state.golden` (create)
- `tests/m029-acceptance/fixtures/where-mixed-state.fixture/` (create — directory tree containing milestones/M998/...)
- `tests/m029-acceptance/fixtures/where-pre-m019.fixture/` (create — directory tree containing milestones/M997/...)
- `tests/m029-acceptance/timestamp-strip.sh` (create)
- `tests/m029-acceptance/sentinel-harness.sh` (create)
- `tests/m029-acceptance/p02-sc5-where-mixed-state.sh` (create)
- `tests/m029-acceptance/p02-sc6-where-pre-m019.sh` (create)
- `tests/m029-acceptance/p02-sc13-anti-coupling.sh` (create)
- `tests/m029-acceptance/p02-sc14-readonly.sh` (create)
- `tests/m029-acceptance/p02-acceptance-battery.sh` (create)
- `tools/verify/m029-p02-cross-milestone-shape-contract.sh` (create)
- `tools/verify/m029-p02-summarize-milestone-shape.sh` (create)
- `tools/verify/m029-p02-render-position-shape.sh` (create)
- `tools/verify/m029-p02-where-skill-shape.sh` (create)
- `tools/verify/m029-p02-sc5-fixtures-shape.sh` (create)
- `tools/verify/m029-p02-sentinel-harness-shape.sh` (create)
- `tools/verify/m029-p02-sc5-shape.sh` (create)
- `tools/verify/m029-p02-sc6-shape.sh` (create)
- `tools/verify/m029-p02-sc13-shape.sh` (create)
- `tools/verify/m029-p02-sc14-shape.sh` (create)
- `tools/verify/m029-p02-acceptance-battery-shape.sh` (create)
- `tools/verify/m029-p02-readonly-invariant.sh` (create)
- `tools/verify/m029-p02-scope-guard.sh` (create)
- `tools/verify/m029-p02-phase-suite.sh` (create)

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