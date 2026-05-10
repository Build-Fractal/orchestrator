---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T03 (Phase P03, Milestone M026)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (28 entries) | 20-707 | ~7000 | filtered |
| Decisions | 709-711 | ~100 | filtered |
| Constraints | 713-765 | ~600 | required |
| Scope | 767-795 | ~500 | required |
| Upstream Context | 797-851 | ~3000 | required |
| Task Plan | 853-1105 | ~4100 | required |
| State Context | 1107-1113 | ~100 | required |
| First-Turn Completeness | 1115-1157 | ~600 | required |
| **Total** | | **~16000** | |

## Knowledge

<!-- 28 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 423
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
hit_count: 423
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
hit_count: 423
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
scope_tags: "[project], [milestone:[M005](../../../../milestones/M005/index.md)]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 423
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
hit_count: 373
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
hit_count: 373
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
hit_count: 373
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
hit_count: 423
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
scope_tags: "[project], [milestone:[M006](../../../../milestones/M006/index.md)]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 373
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
hit_count: 373
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
scope_tags: "[project], [milestone:[M002](../../../../milestones/M002/index.md)]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 373
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
hit_count: 423
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
hit_count: 423
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
hit_count: 423
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
hit_count: 373
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
hit_count: 373
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
hit_count: 373
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
hit_count: 423
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
hit_count: 373
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
hit_count: 373
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
hit_count: 423
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
hit_count: 423
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
scope_tags: "[project], [milestone:[M004](../../../../milestones/M004/index.md)]"
category: lessons
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 373
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
hit_count: 373
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
hit_count: 373
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
scope_tags: "[project], [milestone:[M025](../../../../milestones/M025/index.md)]"
category: lessons
confidence: 0.95
created_at: 2026-04-23
last_verified: 2026-04-23
hit_count: 28
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
hit_count: 28
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
scope_tags: "[project], [milestone:[M014](../../../../milestones/M014/index.md)], [concern:bash-compat]"
category: lessons
confidence: 0.95
created_at: 2026-04-23
last_verified: 2026-04-23
hit_count: 28
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

<!-- AD-19: every Check is a single-script-file invocation. No inline compound bash, subshells, or $(...|pipe). -->

- Adapter refuses to invoke `conversus run` when the resolved edition is `oss` and the preset frontmatter declares `edition_required: paid`. Refusal emits a diagnostic to stderr matching the regex `paid-only.*CONVERSUS_EDITION=paid` (case-insensitive) and exits 1. Presets without `edition_required:` behave identically to today (backward-compatible).
  - Check: `bash scripts/verify/m026-p03-edition-required-diagnostic.sh`

- Adapter does not regress the CON-1..CON-5 invariants: 0/1/2 exit codes, full env-var set, `gate-result.md` frontmatter key set, D019 TODO pre-flight, stub-mode fixtures, filename-routed adapter shape, Bash 3.2 compat. Stub-mode path remains untouched (preset frontmatter parsing fires only on real-binary path).
  - Check: `bash scripts/verify/m011-p07-conversus-adapter-shape.sh`

- All six FR-12 doc surfaces grep-match both `conversus-oss` and `CONVERSUS_EDITION` and the original M011-era four-step resolver-order block in `commands/conversus-gate.md` is rewritten to the new edition-aware shape (no longer ends at `$HOME/Sites/conversus/bin/conversus` as the user-local convention).
  - Check: `bash scripts/verify/m026-p03-doc-surface-coverage.sh`

- Two knowledge-layer `MEM*.md` entries are graduated for this milestone: edition-resolution-precedence pattern and paid-escape-hatch env-var convention. `KNOWLEDGE-INDEX.md` lists both entries with the correct categories. Format follows MEM027 shape (frontmatter + `## Problem` + `## Pattern`/`## Convention` + `## Gate shape` body).
  - Check: `bash scripts/verify/m026-p03-mem-graduation.sh`

- [`.orchestrator/DECISIONS.md`](../../../../decisions.md) gains a new `D###` row naming the edition-resolution precedence (env-var primary → metadata probe → fallback) decision, and `CHANGELOG.md` records the M026 migration entry under the current version heading.
  - Check: `bash scripts/verify/m026-p03-decision-row.sh`

<dispatch-volatile>

## Upstream Context


### P02 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P02"
parent: "M026"
milestone: "M026"
provides:
  - "adapter edition-detection resolver (CONVERSUS_EDITION env primary + pip-show metadata probe fallback); check stdout now emits edition= and reason= lines after available=/conversus_path=; new _resolve_edition helper is callable by T02/T03 consumers, JSONL conversus_gate_invocation records carry edition field adjacent to adapter_version at both emission sites (github-common emit_conversus_gate_record + specify.sh REC_G); backward-compatible default edition=unknown when caller omits the 6th positional, dual-edition regression test with visible-skip annotations for OSS and paid Conversus editions; sample-spec.md fixture; shape-not-value (DC-4) sorted-key diff verification, F1-verdict-text-rationale,F2-arbiter-preference,F3-oauth-auto-preflight,m026-p02-gate-verdict-reliability-verifier, P02 phase verification suite orchestrator + M026/P02 Recent Changes dual-write"
requires:
  - "P01 parity matrix addendum ([.orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md](../../../../milestones/M026/M026-CONVERSUS-PARITY.md)) establishing single-venv reality; P01 operator state from OLLAMA-PROBE.md confirming OSS installed at ~/.local/pipx/venvs/conversus/, T01 adapter check output line edition=<oss|paid|unknown>; emit_tier1_record argument-order preservation, T01 (adapter edition=/reason= lines); tests/fixtures/gate-result-pass.md; conversus pipx venv metadata at ~/.local/pipx/venvs/conversus, T01-edition-detection,T02-jsonl-edition-field,T03-dual-edition-test, from:P02/T01 what:m026-p02-edition-detection-contract.sh, m026-p02-adapter-invariants.sh; from:P02/T02 what:m026-p02-jsonl-edition-field.sh; from:P02/T03 what:m026-p02-dual-edition-test-shape.sh; from:P02/T04 what:m026-p02-gate-verdict-reliability.sh"
affects:
  - "T02 (JSONL edition field consumes resolver output); T03 (dual-edition test shape consumes resolver output); T04 (gate verdict reliability); downstream invocations from specify.sh and github-common.sh, scripts/integrations/github-common.sh,scripts/integrations/github-conversus-gate.sh,scripts/specify/specify.sh,scripts/verify/m026-p02-jsonl-edition-field.sh, tests/test-conversus-adapter-shim.sh; tests/fixtures/sample-spec.md; scripts/verify/m026-p02-dual-edition-test-shape.sh, scripts/dispatch/adapters/tool/conversus.sh, milestone-close, orchestrator:verify for P02-SUMMARY authoring"
key_files:
  - "scripts/dispatch/adapters/tool/conversus.sh (modified, +75 lines); scripts/verify/m026-p02-edition-detection-contract.sh (created); scripts/verify/m026-p02-adapter-invariants.sh (created), scripts/integrations/github-common.sh,scripts/integrations/github-conversus-gate.sh,scripts/specify/specify.sh,scripts/verify/m026-p02-jsonl-edition-field.sh, tests/test-conversus-adapter-shim.sh,tests/fixtures/sample-spec.md,scripts/verify/m026-p02-dual-edition-test-shape.sh, scripts/dispatch/adapters/tool/conversus.sh,scripts/verify/m026-p02-gate-verdict-reliability.sh, scripts/verify/m026-p02-phase-suite.sh, scripts/verify/m026-p02-recent-changes.sh, CLAUDE.md, AGENTS.md"
key_decisions:
  - "env-var primary over metadata-only to let operators declare edition without venv probe; fallthrough-with-stderr-warning on invalid CONVERSUS_EDITION values (never silently accept); conversus-oss tried FIRST in user-local fallback order (OSS-primary posture per project_m026_oss_posture.md); stub mode always emits edition=unknown reason=stub (stub is edition-agnostic by design), Emit adapter_version+edition as adjacent pair in github-common emitter (AD-4 adjacency invariant testable symmetrically with specify.sh); default edition=unknown on omitted 6th positional preserves caller backward compat; capture edition via adapter check stdout (not env var) so the two-tier resolver from T01 is the single source of truth, OQ-3 resolution: ollama absent means OSS-Anthropic branch skips with known-upstream-429 annotation (visible-skip); DC-4: SC-6 key-set diff is shape-not-value; AD-6: sections 1/1b/2 untouched, net-new section 3 replaces the prior real-binary mock-provider block, F3-keyed-on-access-token-plus-oauth-subscription-alternation,F3-scoped-to-CONVERSUS_PROVIDER-unset-via-+set-param-expansion,F1-prefers-arbiter-then-synthesis-with-awk-Verdict-extractor,verifier-F3-smoke-is-detection-replay-not-end-to-end-gate, OQ-10 dual-write parity enforced; test-shim omitted for parity with P01 suite"
patterns_established:
  - "two-tier detection (env-var declaration + metadata probe) pattern reusable for future runtime identification; stderr for warnings / stdout for structured fields (DC-5) enforced in resolver; line-order stability as verifiable contract (available=/conversus_path=/edition=/reason=), Adjacent-pair AD-4 placement via argument ordering in emit_tier1_record; backward-compat optional positional with defaulted unknown sentinel; verify script drives live emitter through staged sub-scripts to avoid process substitution / compound bash, visible-skip (annotated SKIP: line) over silent-skip for unavailable edition branches; dual-edition detection via pip-show Home-page probe reusing adapter's metadata probe; sorted-key diff of gate-result frontmatter as DC-4 contract, detection-replay-smoke-harness-for-deep-gate-logic,awk-section-paragraph-extraction-with-newline-collapse, P02 suite mirrors P01 shape (IFS newline GATES list, single-script-file gate invocation, SUMMARY+PASS/FAIL trailer); dual-write helper replaces full region so content file must include existing body lines"
drill_down_paths:
  - ".orchestrator/milestones/M026/phases/P02/tasks/T01-SUMMARY.md, .orchestrator/milestones/M026/phases/P02/tasks/T02-SUMMARY.md, .orchestrator/milestones/M026/phases/P02/tasks/T03-SUMMARY.md, .orchestrator/milestones/M026/phases/P02/tasks/T04-SUMMARY.md, .orchestrator/milestones/M026/phases/P02/tasks/T05-SUMMARY.md"
duration: "148m"
verification_result: "pass"
completed_at: "2026-04-24T22:30:40Z"
observability_surfaces:
  - "none"
---

P02 flips the orchestrator's default Conversus integration from paid to OSS while preserving a first-class paid escape hatch, and closes the OQ-16 false-PASS regression surfaced during P01 dogfood.

Five tasks delivered the minimal slice end-to-end:

- **T01 (27cc7ca)** — Adapter edition-detection resolver. A new `_resolve_edition` helper reads `CONVERSUS_EDITION=oss|paid` as the primary signal (operator declaration), falls back to a `pip show conversus` metadata probe against the pipx venv's `Home-page:` line, and short-circuits to `edition=unknown` under stub mode. `_resolve_binary` emits `edition=`/`reason=` on `check` stdout immediately after the pre-existing `available=`/`conversus_path=` pair. Line ordering is the verifiable contract. Adapter delta: +75 lines. Bash 3.2 clean. User-local fallback now tries `~/Sites/conversus-oss/bin/conversus` first (OSS-primary posture per `project_m026_oss_posture.md`).

- **T02 (fdff944)** — JSONL `edition` field on `conversus_gate_invocation` records. Additive per AD-4. Wired at both emission sites: `scripts/integrations/github-common.sh::emit_conversus_gate_record` (via `emit_tier1_record` argument ordering so `adapter_version` and `edition` land as adjacent JSON keys) and the inline emission at `scripts/specify/specify.sh`. The caller derives the edition by reading the adapter's `check` subcommand output — single source of truth — with `:=unknown` fallback. Pre-existing [M019](../../../../milestones/M019/index.md) Tier 1 readers remain unaffected; M013/P04 observability shape test stays green.

- **T03 (2867170)** — Dual-edition regression test. A new section 3 of `tests/test-conversus-adapter-shim.sh`, gated by `CONVERSUS_INTEGRATION=1`, exercises both editions when both are installed. Under the current operator environment (OSS installed, paid absent, no `ANTHROPIC_API_KEY`, no ollama), both branches emit **visible-skip** annotations — `SKIP: known-upstream-429 (OSS lacks PR #29; ...)` and `SKIP: paid build not installed` — and the test exits 0. Assertion contract is **shape, not value** per DC-4: when both branches actually run, the test diffs sorted frontmatter key-sets across editions rather than comparing verdict values. Stub-path sections 1, 1b, 2 untouched per AD-6.

- **T04 (100c06f)** — Gate-verdict reliability bundle, closing POST-P01-FINDINGS F1/F2/F3 and OQ-16. Three tightly-coupled changes in the adapter: (F1) rationale now extracts the first paragraph of the synthesis file's `## Verdict` section via an awk pattern that tolerates section-heading + blank-line terminators, with fallback to the 32ab6ea synthesized formula; (F2) when `${_run_output_dir}/arbiter/resolution.md` exists, it's preferred over `summary/final.md` as the verdict-text source while structural fields still come from the synthesis; (F3) when `CONVERSUS_PROVIDER` is unset (`[ -z "${CONVERSUS_PROVIDER+set}" ]`), `ANTHROPIC_API_KEY` is not exported, and `~/.conversus/auth.json` contains an OAuth marker (`access_token` as the canonical key per `~/Sites/conversus-oss/engine/auth.py`, with `oauth|subscription` as belt-and-suspenders alternation), the adapter auto-sets `CONVERSUS_PROVIDER=claude-code` and emits a single `note:` line to stderr. Operator-override precedence preserved via `+set` parameter expansion. Adapter delta: +38 lines (budget ≤ +40).

- **T05 (0c6e7a0)** — Phase verification suite orchestrator and Recent Changes dual-write. `scripts/verify/m026-p02-phase-suite.sh` chains the six M026/P02 gates with the three M011/P07 cross-milestone invariant gates (DC-2) and emits `SUMMARY: m026-p02-phase-suite.sh pass=9 fail=0`. CLAUDE.md and AGENTS.md receive a reverse-chronological M026/P02 fragment in the `orchestrator:recent-changes` marker region via `scripts/util/dual-write-runtime-md.sh`; OQ-10 dual-write parity enforced. The helper replaces the full between-markers region (not append-mode), so the content file was constructed to include every existing line plus the new one — the non-overwrite invariant is the caller's responsibility, not the helper's.

**Cross-task patterns reinforced**: two-tier detection (env-var declaration + metadata probe) as a reusable runtime-identification shape; stderr/stdout discipline (DC-5) — structured fields on stdout, warnings on stderr; visible-skip over silent-skip for unavailable branches; shape-not-value assertions for cross-edition equivalence; detection-replay harnesses as the hermetic path for deep-gate logic that can't run end-to-end in a verifier.

**Adapter invariants (CON-1..CON-5)**: preserved. Exit codes 0/1/2 unchanged; full env-var set (nine vars including new `CONVERSUS_EDITION`) present; `gate-result.md` frontmatter key-set unchanged; D019 TODO pre-flight unmodified; stub-mode fixture paths unchanged; filename-routed adapter auto-discovery pattern unbroken; no `~/Sites/conversus*` writes (read-only probe only); Bash 3.2 clean across all nine gates.

**One Key Link fix landed post-T05 (456b814)**: the initial RC fragment did not name `P02-SUMMARY.md` literally, causing `check-must-haves.sh` to fail two key-link rows. The fragment was re-dual-written with a trailing `See [.orchestrator/milestones/M026/phases/P02/P02-SUMMARY.md](../../../../milestones/M026/phases/P02/P02-SUMMARY.md).` clause and verified green.

**One side-fix bundled into the same branch (316411e)**: a `read-roadmap.sh` parens-in-Risk and malformed-Depends silent-pass bug surfaced via bbt-companion dogfood batch 2 was fixed in-line (Depends parsing now hard-fails on non-P## tokens; Risk strips parenthetical commentary). `tests/test-roadmap-dep-safety.sh` (5/5 pass) added as regression coverage.

**Verification**: Tier 1 31/31 PASS (post-key-link-fix). Tier 2 1/1 PASS. Tier 3 skipped (no behavioral-only truths — every P02 truth carries a `Check:` sub-item). Tier 4 skipped (standard intensity). `check-boundary-map.sh` reports 7 FAILs, all traceable to the narrative-prose shape of the roadmap's Produces: cells — same parser limitation P01-VERIFICATION.md documents; all artifacts exist and pass individual Tier 1 artifact checks.

## Task Plan

---
schema_version: "1.0"
task: "T03"
phase: "P03"
milestone: "M026"
name: "Knowledge graduation — two MEM entries (edition-resolution pattern + paid-escape-hatch convention) + index rebuild (FR-13, AD-8)"
depends_on: []
---

## Prerequisites

- `knowledge/` taxonomy on disk has these subdirectories: `patterns/`, `conventions/`, `lessons/`, `spec/`, `archive/`. There is **no** `decisions/` subdirectory; spec 027 §FR-13 and roadmap §P03 Boundary Map reference `knowledge/decisions/MEM*.md` as the destination, but no other consumer or scaffolder script in this repo references `knowledge/decisions/`. Per the P03 plan-phase notes, this task places the two graduated entries under the closest matching existing categories (`patterns/` and `conventions/`).
- `KNOWLEDGE-INDEX.md` at the repo root is the consolidated index. The last existing MEM entry is MEM028. T03 adds MEM029 (pattern) and MEM030 (convention).
- MEM027 ([`knowledge/patterns/MEM027.md`](../../../../knowledge/patterns/MEM027.md)) is the most recent shape exemplar — graduated from M025 with frontmatter (`id`, `scope_tags`, `category`, `confidence`, `created_at`, `last_verified`, `hit_count`, `source_unit`, `source_type`, `supersedes`, `superseded_by`, `relates_to`, `content_hash`) plus body sections `## Problem`, `## Pattern`, `## Gate shape`.
- `scripts/knowledge/rebuild-index.sh` exists and rebuilds `KNOWLEDGE-INDEX.md` from the on-disk `knowledge/**/MEM*.md` files. The verifier uses index re-rebuild as part of its assertion.

## Description

Graduate two M026 decisions into the knowledge layer:

- **MEM029** ([`knowledge/patterns/MEM029.md`](../../../../knowledge/patterns/MEM029.md)) — "Edition-resolution two-tier detection (env-var primary, metadata-probe fallback)". Captures the M026/P02 pattern of using a declarative env var as the primary signal and a runtime metadata probe as fallback for runtime-identification questions where path-based detection is infeasible. Reusable for future similar runtime-identification problems (e.g., distinguishing build editions of any installed Python package, distinguishing runtime modes of MCP servers).

- **MEM030** ([`knowledge/conventions/MEM030.md`](../../../../knowledge/conventions/MEM030.md)) — "Paid-escape-hatch env-var convention". Captures the convention that when an OSS-default tool requires reach-through to a paid alternate, the escape is named `<TOOL>_EDITION=paid` (or analogous) rather than a path or magic value. Reusable for future tool migrations.

After creating both files, rebuild `KNOWLEDGE-INDEX.md` via `scripts/knowledge/rebuild-index.sh` so MEM029 and MEM030 appear in the index.

T03 also creates the verifier `scripts/verify/m026-p03-mem-graduation.sh`.

## Steps

1. **Read MEM027 as a shape exemplar**:

   ```sh
   cat [knowledge/patterns/MEM027.md](../../../../knowledge/patterns/MEM027.md)
   ```

   Note: frontmatter keys, ordering, body section headers (`## Problem`, `## Pattern`, `## Gate shape`).

2. **Create [`knowledge/patterns/MEM029.md`](../../../../knowledge/patterns/MEM029.md)** with the following content:

   ```markdown
   ---
   id: MEM029
   scope_tags: "[project], [milestone:M026]"
   category: patterns
   confidence: 0.90
   created_at: 2026-04-24
   last_verified: 2026-04-24
   hit_count: 0
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
   ```

3. **Create [`knowledge/conventions/MEM030.md`](../../../../knowledge/conventions/MEM030.md)** with the following content:

   ```markdown
   ---
   id: MEM030
   scope_tags: "[project], [milestone:M026]"
   category: conventions
   confidence: 0.90
   created_at: 2026-04-24
   last_verified: 2026-04-24
   hit_count: 0
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
   ```

4. **Rebuild the knowledge index**:

   ```sh
   bash scripts/knowledge/rebuild-index.sh
   ```

   This regenerates `KNOWLEDGE-INDEX.md`. After the rebuild, `KNOWLEDGE-INDEX.md` should list both MEM029 and MEM030.

5. **Create `scripts/verify/m026-p03-mem-graduation.sh`** (single-script-file shape, AD-19, Bash 3.2):

   ```sh
   #!/usr/bin/env bash
   # scripts/verify/m026-p03-mem-graduation.sh
   # Verifies M026/P03/T03: two graduated MEM entries exist and KNOWLEDGE-INDEX is rebuilt.
   set -u

   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

   pass=0; fail=0
   _pass() { pass=$((pass+1)); echo "PASS: $1"; }
   _fail() { fail=$((fail+1)); echo "FAIL: $1"; }

   MEM029="${REPO_ROOT}/knowledge/patterns/MEM029.md"
   MEM030="${REPO_ROOT}/knowledge/conventions/MEM030.md"
   INDEX="${REPO_ROOT}/KNOWLEDGE-INDEX.md"

   for f in "$MEM029" "$MEM030"; do
     base="$(basename "$f")"
     if [ ! -f "$f" ]; then _fail "${base}: file missing"; continue; fi
     if grep -q '^id: MEM' "$f"; then _pass "${base}: has frontmatter id field"; else _fail "${base}: missing 'id:' frontmatter"; fi
     if grep -q '^source_unit: "M026/P02"' "$f"; then _pass "${base}: source_unit pinned to M026/P02"; else _fail "${base}: source_unit not pinned to M026/P02"; fi
     if grep -q '^category:' "$f"; then _pass "${base}: has category field"; else _fail "${base}: missing 'category:' frontmatter"; fi
   done

   if grep -qE '^MEM029 ' "$INDEX"; then _pass "KNOWLEDGE-INDEX.md lists MEM029"; else _fail "KNOWLEDGE-INDEX.md missing MEM029"; fi
   if grep -qE '^MEM030 ' "$INDEX"; then _pass "KNOWLEDGE-INDEX.md lists MEM030"; else _fail "KNOWLEDGE-INDEX.md missing MEM030"; fi

   echo "----"
   echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   echo "PASS: $(basename "$0")"
   exit 0
   ```

6. **Run the verifier**:

   ```sh
   bash scripts/verify/m026-p03-mem-graduation.sh
   ```

   Expected:

   ```
   ----
   SUMMARY: m026-p03-mem-graduation.sh pass=8 fail=0
   PASS: m026-p03-mem-graduation.sh
   ```

   (3 frontmatter checks × 2 files + 2 index checks = 8 PASS lines.)

## Must-Haves

Addresses phase must-haves:
- "Truth: two knowledge-layer MEM*.md entries are graduated for this milestone; KNOWLEDGE-INDEX.md lists both"
- Artifacts: [`knowledge/patterns/MEM029.md`](../../../../knowledge/patterns/MEM029.md), [`knowledge/conventions/MEM030.md`](../../../../knowledge/conventions/MEM030.md), `KNOWLEDGE-INDEX.md` (modified), `scripts/verify/m026-p03-mem-graduation.sh`

## Verification

```
bash scripts/knowledge/rebuild-index.sh
bash scripts/verify/m026-p03-mem-graduation.sh
```

Verifier must exit 0 with `SUMMARY: ... pass=8 fail=0` and `PASS:` final line.

## Inputs

### From Previous Tasks

None — T03 is independent within P03.

### From Disk (Pre-existing)

- [`knowledge/patterns/MEM027.md`](../../../../knowledge/patterns/MEM027.md) — shape exemplar (most recent graduation, M025 source).
- `KNOWLEDGE-INDEX.md` — flat index, regenerated by `scripts/knowledge/rebuild-index.sh`.
- `scripts/knowledge/rebuild-index.sh` — index regenerator.
- `scripts/dispatch/adapters/tool/conversus.sh` — referenced in both MEM bodies as the canonical implementation.

## Constraints

- **Knowledge taxonomy fidelity**: place graduated entries under existing categories (`patterns/`, `conventions/`). Do NOT create a new `decisions/` subdirectory — no consumer references it. The plan-phase notes section documents this deviation.
- **MEM ID monotonicity**: MEM IDs are append-only. Use MEM029 and MEM030 (next two after MEM028).
- **Frontmatter shape**: match MEM027's keys and ordering exactly. The index regenerator parses frontmatter — divergence breaks the index rebuild.
- **AD-19** (single-script-file Check shape): verifier uses no compound bash that triggers the harness heuristic.
- **Idempotent**: re-running `scripts/knowledge/rebuild-index.sh` produces a byte-identical `KNOWLEDGE-INDEX.md` (the regenerator already enforces this; the verifier asserts the result, not the regenerator's idempotency).

## Expected Output

- [`knowledge/patterns/MEM029.md`](../../../../knowledge/patterns/MEM029.md) — created (~70-100 lines).
- [`knowledge/conventions/MEM030.md`](../../../../knowledge/conventions/MEM030.md) — created (~70-100 lines).
- `KNOWLEDGE-INDEX.md` — modified (two new MEM rows added by the regenerator).
- `scripts/verify/m026-p03-mem-graduation.sh` — created (~40-50 lines).
- `bash scripts/verify/m026-p03-mem-graduation.sh` exits 0 with `SUMMARY: ... pass=8 fail=0`.

## State Context

- **Current State**: executing
- **Milestone**: M026
- **Phase**: P03
- **Task**: T03
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **Knowledge taxonomy fidelity**: place graduated entries under existing categories (`patterns/`, `conventions/`). Do NOT create a new `decisions/` subdirectory — no consumer references it. The plan-phase notes section documents this deviation.
- **MEM ID monotonicity**: MEM IDs are append-only. Use MEM029 and MEM030 (next two after MEM028).
- **Frontmatter shape**: match MEM027's keys and ordering exactly. The index regenerator parses frontmatter — divergence breaks the index rebuild.
- **AD-19** (single-script-file Check shape): verifier uses no compound bash that triggers the harness heuristic.
- **Idempotent**: re-running `scripts/knowledge/rebuild-index.sh` produces a byte-identical `KNOWLEDGE-INDEX.md` (the regenerator already enforces this; the verifier asserts the result, not the regenerator's idempotency).

### Acceptance Criteria

Addresses phase must-haves:
- "Truth: two knowledge-layer MEM*.md entries are graduated for this milestone; KNOWLEDGE-INDEX.md lists both"
- Artifacts: [`knowledge/patterns/MEM029.md`](../../../../knowledge/patterns/MEM029.md), [`knowledge/conventions/MEM030.md`](../../../../knowledge/conventions/MEM030.md), `KNOWLEDGE-INDEX.md` (modified), `scripts/verify/m026-p03-mem-graduation.sh`

### Files To Touch

- scripts/dispatch/adapters/tool/conversus.sh (modify)
- scripts/verify/m026-p03-edition-required-diagnostic.sh (create)
- scripts/verify/m026-p03-doc-surface-coverage.sh (create)
- scripts/verify/m026-p03-mem-graduation.sh (create)
- scripts/verify/m026-p03-decision-row.sh (create)
- scripts/verify/m026-p03-recent-changes.sh (create)
- scripts/verify/m026-p03-phase-suite.sh (create)
- tests/fixtures/preset-edition-required-paid.yml (create)
- commands/conversus-gate.md (modify)
- commands/ingest.md (modify)
- commands/specify.md (modify)
- docs/ingesting-arbitrary-specs.md (modify)
- references/github-integration.md (modify)
- references/spec-management.md (modify)
- [knowledge/patterns/MEM029.md](../../../../knowledge/patterns/MEM029.md) (create)
- [knowledge/conventions/MEM030.md](../../../../knowledge/conventions/MEM030.md) (create)
- KNOWLEDGE-INDEX.md (modify)
- [.orchestrator/DECISIONS.md](../../../../decisions.md) (modify)
- CHANGELOG.md (modify)
- CLAUDE.md (modify — RC region only via dual-write)
- AGENTS.md (modify — RC region only via dual-write)
- [.orchestrator/milestones/M026/phases/P03/P03-SUMMARY.md](../../../../milestones/M026/phases/P03/P03-SUMMARY.md) (create at phase close)

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