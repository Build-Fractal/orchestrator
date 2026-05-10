---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T04-verifiers-and-summary (Phase P06, Milestone M018)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-978 | ~500 | required |
| Upstream Context | 980-1179 | ~3900 | required |
| Task Plan | 1181-1431 | ~5600 | required |
| State Context | 1433-1439 | ~100 | required |
| First-Turn Completeness | 1441-1475 | ~500 | required |
| **Total** | | **~21400** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 695
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
hit_count: 695
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
hit_count: 695
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
hit_count: 695
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
hit_count: 620
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
hit_count: 620
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
hit_count: 620
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
hit_count: 695
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
hit_count: 620
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
hit_count: 620
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
hit_count: 620
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
hit_count: 695
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
hit_count: 695
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
hit_count: 695
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
hit_count: 620
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
hit_count: 620
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
hit_count: 620
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
hit_count: 695
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
hit_count: 620
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
hit_count: 620
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
hit_count: 695
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
hit_count: 695
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
hit_count: 620
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
hit_count: 620
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
hit_count: 620
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
hit_count: 275
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
hit_count: 275
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
hit_count: 275
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
hit_count: 271
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
hit_count: 271
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
hit_count: 261
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

<!-- Every truth's Check is a single-script-file invocation per AD-19.
     bash -n self-checks are used as a fallback when the canonical
     verifier ships in T04 (the closing task), so each task always has
     at least one extractable Check at task-plan parse time. -->

- The `_bc_apply_tier3` helper exists in `scripts/dispatch/build-context.sh` and routes summarization through `dispatch-interface.sh` with `templates/compression-tier3-prompt.md`.
  - Check: `bash scripts/verify/m018-p06-tier3-helper-shape.sh`
- `templates/compression-tier3-prompt.md` exists with a versioned frontmatter and a body that names input contract (section header + body bytes) and output contract (in-band marker + summary body).
  - Check: `bash scripts/verify/m018-p06-tier3-prompt-template.sh`
- `payload_breakdown` records carry additive `tier3_compression_savings_tokens` and `tier3_invocations` integer fields; `dispatch_usage` and `unit_close` records carry the same two fields rolled up from in-scope `payload_breakdown` rows; pre-M018 records remain valid JSON (CON-5 absent-as-zero).
  - Check: `bash scripts/verify/m018-p06-tier3-additivity.sh`
- `compression-eval.sh --tier 3` replaces the P05 reservation stub with real cohort logic against `tier3_compression_savings_tokens`; reports per-cohort + delta means with 95% CIs; emits `regression_flag:` advisory; below-floor emits `insufficient sample` and exits 0; sourceable + CLI shape preserved (FR-12 always-exit-0; AD-19 single-script-file Check shape).
  - Check: `bash scripts/verify/m018-p06-compression-eval-tier3.sh`
- CLAUDE.md and AGENTS.md `orchestrator:recent-changes` blocks both name "M018/P06" and "tier3" / "compression-tier3-prompt".
  - Check: `bash scripts/verify/m018-p06-dual-write-recent.sh`

<dispatch-volatile>

## Upstream Context


### P05 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P05"
parent: "M018"
milestone: "M018"
provides:
  - "additive integer fields filter_dropped_tokens / tier1_savings_tokens / tier2_savings_tokens / tier1_invocations on dispatch_usage (scripts/dispatch/dispatch-interface.sh:_di_emit_dispatch_usage) and unit_close (scripts/knowledge/write-summary.sh:_ws_emit_unit_close) JSONL records — rolled up from in-scope payload_breakdown records at emit-time (CON-5); cost-rollup column extension (FILTER_DROPPED / TIER1_SAVINGS / TIER2_SAVINGS / TIER1_INVOCS appended after existing 12 columns); efficiency-footer 'compression: <pct>% reduction over baseline' tail line (configurable via compression.efficiency_footer.enabled); doctor anomaly compression-regression reason (configurable via compression.regression_floor, default 0.347 per SC-9 P00 calibration); scripts/diagnostics/compression-eval.sh sourceable+CLI cohort-segmentation diagnostic with --tier <N> filter (1 and 2 supported in P05; tier 3 stub for P06); eight P05-private truth verifiers under scripts/verify/m018-p05-*.sh; two fixture trees under tests/fixtures/m018-p05-{savings-log,no-savings-log}/; scripts/verify/_helpers/m018-p05-build-fixture.sh fixture-staging helper; CLAUDE.md/AGENTS.md recent-changes refresh"
requires:
  - "P02 payload_filter + filter_dropped_tokens additive field on payload_breakdown; P03 tier1_savings_tokens + tier1_invocations additive fields on payload_breakdown; P04 tier2_savings_tokens additive field on payload_breakdown; SC-9 calibrated 34.7% floor (P00); [M027](../../../../../milestones/M027/index.md) metrics-rollup.sh + efficiency-footer.sh + check-anomalies.sh as extension targets (DEP-2)"
affects:
  - "P06 (Tier 3 auto-compact — extends compression-eval.sh tier=3 stub to a real cohort against tier3_savings_tokens; extends dispatch_usage / unit_close additive fields with tier3_compression_savings_tokens and tier3_invocations; reuses the rollup-helper shape T01 established for the dispatch-internal emitter side; doctor compression-regression flag composes with tier3-quality regression once tier3 ships); M027 future surfaces consume the additive fields with no further changes required (rollup column-index contract is now pinned)"
key_files:
  - "scripts/dispatch/dispatch-interface.sh;scripts/knowledge/write-summary.sh;scripts/diagnostics/metrics-rollup.sh;scripts/diagnostics/efficiency-footer.sh;scripts/diagnostics/check-anomalies.sh;scripts/diagnostics/compression-eval.sh;tests/fixtures/m018-p05-savings-log/execution-log.jsonl;tests/fixtures/m018-p05-savings-log/README.md;tests/fixtures/m018-p05-no-savings-log/execution-log.jsonl;tests/fixtures/m018-p05-no-savings-log/README.md;scripts/verify/_helpers/m018-p05-build-fixture.sh;scripts/verify/m018-p05-dispatch-usage-additivity.sh;scripts/verify/m018-p05-unit-close-additivity.sh;scripts/verify/m018-p05-cost-rollup-savings-columns.sh;scripts/verify/m018-p05-efficiency-footer-compression.sh;scripts/verify/m018-p05-doctor-compression-regression.sh;scripts/verify/m018-p05-compression-eval.sh;scripts/verify/m018-p05-compression-eval-shape.sh;scripts/verify/m018-p05-dual-write-recent.sh"
key_decisions:
  - "MEM004 emitter-internal carve-out applies to JSONL-record-rollup helpers (single-pass awk in helper bodies; pipes/sed permitted); rollup-helper scope-precedence: dispatch_usage = unitId match; unit_close = granularity-aware (task M+P+T / phase M+P / milestone M); rollup-source restriction: metrics-rollup.sh accumulator skips rolled-up copies on dispatch_usage / unit_close to avoid double-counting (only payload_breakdown rows feed savings sums); savings columns appended AFTER existing 12 to preserve rollup column-index contract (CON-5); efficiency-footer compression line gated by tokens > 0 AND pct >= 0.5 AND ORCH_COMPRESSION_FOOTER not falsy; doctor compression-regression gated by sav_total > 0 AND ratio < floor (distinguishes 'compression ran and underperformed' from 'compression did not run at all'); compression-eval cohort definition: (milestone, phase, task)-keyed; compressed = tier<N>_savings_tokens > 0 from payload_breakdown ground truth (NOT the rolled-up unit_close field); --tier 3 ships as recognized-but-no-op stub for P06 forward-compat; sample-floor default 30 prevents false positives at low N; compression-eval honors ORCHESTRATOR_ROOT for fixture-based verifier runs (T04 patch)"
patterns_established:
  - "MEM004 dispatch-internal carve-out extends to JSONL-record-rollup helpers — single-pass awk + sed -n line read with defensive [-n] || var=0 floor; granularity-aware scope match for unit_close mirrors awk index() pattern from existing verification_pass_rate aggregation (parallel-scalar, no declare -A); metrics-rollup.sh additive column extension pattern — append at projection END (cols 13+), accumulate in scope_*[skey] map, defensive zero-fill in render loop; cohort-segmentation diagnostic shape: single awk pass over execution-log.jsonl with per-record-type branches (payload_breakdown classifies, unit_close measures); Wilson 95% CI + pooled-SE delta in pure awk (closed-form, single-pass); always-exit-0 contract on diagnostic CLIs surfaces degraded inputs as text; shim-style verifier pattern from P03/P04 extends to write-summary.sh + dispatch-interface.sh CLI scripts (awk function-extraction shim isolates the unit-under-test from the host CLI body)"
drill_down_paths:
  - "[.orchestrator/milestones/M018/phases/P05/tasks/T01-schema-extensions-SUMMARY.md](../../../../../milestones/M018/phases/P05/tasks/T01-schema-extensions-SUMMARY.md);[.orchestrator/milestones/M018/phases/P05/tasks/T02-surface-extensions-SUMMARY.md](../../../../../milestones/M018/phases/P05/tasks/T02-surface-extensions-SUMMARY.md);[.orchestrator/milestones/M018/phases/P05/tasks/T03-compression-eval-SUMMARY.md](../../../../../milestones/M018/phases/P05/tasks/T03-compression-eval-SUMMARY.md);[.orchestrator/milestones/M018/phases/P05/tasks/T04-verifiers-and-summary-SUMMARY.md](../../../../../milestones/M018/phases/P05/tasks/T04-verifiers-and-summary-SUMMARY.md)"
duration: "~5h"
verification_result: "pass"
completed_at: "2026-04-28T05:30:00Z"
observability_surfaces:
  - "execution-log.jsonl: dispatch_usage.filter_dropped_tokens / .tier1_savings_tokens / .tier2_savings_tokens / .tier1_invocations additive integer fields; unit_close.{filter_dropped_tokens,tier1_savings_tokens,tier2_savings_tokens,tier1_invocations} additive integer fields; metrics-rollup.sh stdout: FILTER_DROPPED / TIER1_SAVINGS / TIER2_SAVINGS / TIER1_INVOCS columns; efficiency-footer.sh stdout: compression: <pct>% reduction over baseline tail; check-anomalies.sh stdout: FLAGGED <task> ... savings_ratio=<pct> ... reasons=... compression-regression; compression-eval.sh stdout: cohort + delta block with 95% CIs and regression_flag"
---

P05 lands the **observability tier** of the M018 compression pipeline:
schema extensions on the dispatch_usage / unit_close JSONL records,
M027 surface extensions (cost rollup column extension, efficiency-footer
compression line, doctor compression-regression flag), and a new
sourceable + CLI cohort-segmentation diagnostic (compression-eval.sh).
After P05, an operator can answer two questions without grepping JSONL:

1. "How much did compression save on this milestone / phase / task?"
   — `metrics-rollup.sh --milestone <M>` shows the four savings columns;
   `efficiency-footer.sh --milestone <M>` shows the one-line compression
   reduction tail.
2. "Did the dispatches that fired tier N produce different verification
   outcomes than the dispatches that did not?" — `compression-eval.sh
   --milestone <M> --tier <N>` reports per-cohort + delta means with
   95% CIs for verification_pass_rate / retry_count / deviation_count.

The phase ships:

- **dispatch_usage / unit_close schema extensions** (T01) — four additive
  integer fields (filter_dropped_tokens / tier1_savings_tokens /
  tier2_savings_tokens / tier1_invocations) on both record types. Each
  emitter rolls up the matching payload_breakdown records from the
  in-flight execution-log.jsonl at emit-time. dispatch_usage rollup is
  unitId-scoped; unit_close rollup is granularity-aware (task = M+P+T,
  phase = M+P, milestone = M only). MEM004 emitter-internal carve-out
  applies — single-pass awk in helper bodies. Pre-P05 records remain
  valid JSON; absent fields default to 0 in downstream rollups (CON-5).

- **Cost rollup column extension** (T02) — `metrics-rollup.sh` projects
  the four savings fields at columns 13-16, accumulates per-scope sums
  from payload_breakdown rows ONLY (skipping the rolled-up copies T01
  added to dispatch_usage / unit_close — avoids double-counting), and
  appends FILTER_DROPPED / TIER1_SAVINGS / TIER2_SAVINGS / TIER1_INVOCS
  columns AFTER the existing 12. Column indices 1-12 remain byte-identical
  for back-compat consumers (CON-5 carry-forward to the rollup
  column-index contract).

- **Efficiency-footer compression line** (T02) — `efficiency-footer.sh`
  emits a `compression: <pct>% reduction over baseline (filter+tier1+tier2
  / payload_tokens)` tail when in-scope payload_breakdown records carry
  non-zero savings. Suppressed under `--quiet`,
  `compression.efficiency_footer.enabled: false`, or
  `ORCH_COMPRESSION_FOOTER=false` (FR-15 carry-forward).

- **Doctor compression-regression flag** (T02) — `check-anomalies.sh`
  composes a `compression-regression` reason additively with cost-spike
  / retry-spike / low-pass-rate when a task's per-row savings ratio
  (sav_total / payload_tokens) falls below the SC-9 calibrated 34.7%
  floor AND sav_total > 0 (the latter guard distinguishes "compression
  ran and underperformed" from "compression did not run at all"). Floor
  configurable via `compression.regression_floor`. Suppression matrix
  preserved (`--no-anomaly`, `--yes`, `ORCHESTRATOR_AUTO=1`,
  `ORCH_ANOMALY_CHECK_ENABLED=false`).

- **scripts/diagnostics/compression-eval.sh** (T03) — sourceable + CLI
  cohort-segmentation diagnostic. Single awk pass walks
  execution-log.jsonl: payload_breakdown classifies each
  (milestone, phase, task) into compressed (tier<N>_savings_tokens > 0)
  or uncompressed cohorts; task-granularity unit_close records measure
  pass_rate / retry / deviation. END block enforces sample floor
  (default 30 per cohort), computes Wilson 95% CI for proportions and
  pooled-SE deltas, emits a regression_flag when delta_pass_rate <= -0.05
  AND CI excludes 0. CLI: `--milestone <Mxxx>`, `--tier <N>` (1 or 2 in
  P05; 3 reserved for P06 stub), `--sample-floor <N>`. Always exits 0
  (FR-12 / CON-5 — degraded inputs surface as text). Honors
  `ORCHESTRATOR_ROOT` env override.

- **Eight P05-private truth verifiers** under `scripts/verify/m018-p05-*.sh`
  exercise all four production-code surfaces end-to-end against
  hand-crafted fixture logs (savings-bearing + no-savings legacy).
  Verifier shape mirrors the P03/P04 pattern: pass()/fail() helpers,
  shim-style awk function extraction where dispatch-interface.sh /
  write-summary.sh CLI bodies prevent direct sourcing, single-script-file
  Check: shape (AD-19 / AP-009).

- **Two fixture trees** under `tests/fixtures/m018-p05-{savings,no-savings}-log/`
  provide the hermetic input. The savings fixture mixes 3 compressed
  (T01/T02/T04) + 2 uncompressed (T03/T05) tasks; T01 has tokens=1000
  with savings=300 → ratio=0.300 (below 0.347 floor, savings > 0) so
  the doctor compression-regression flag fires. The legacy fixture
  carries zero savings fields so the surfaces stay quiet (CON-5
  absent-as-zero).

- **`scripts/verify/_helpers/m018-p05-build-fixture.sh`** — fixture-staging
  helper mirroring the P03 / P04 shape. Stages a hermetic
  `.orchestrator/`-style root with `milestones/<id>/execution-log.jsonl`
  copied from the chosen slug (savings / no-savings) and a minimal
  `config.yml` so `read-config.sh` resolves cleanly under
  `ORCHESTRATOR_ROOT=<root>`.

## Risk-mitigation traceability

- **CON-5 (additive emitters)** — the four new fields on dispatch_usage
  and unit_close are additive. Pre-P05 records (the T99 row in the
  savings fixture, every record in the no-savings fixture, and every
  pre-P05 row in the live `.orchestrator/milestones/M018/execution-log.jsonl`)
  remain valid JSON; downstream consumers (rollup, footer, doctor,
  compression-eval) treat absent fields as zero. Verified by the
  back-compat assertions in `m018-p05-dispatch-usage-additivity.sh` and
  `m018-p05-unit-close-additivity.sh`.

- **SC-9 (34.7% calibrated floor)** — surfaced in `check-anomalies.sh`
  as the default `compression.regression_floor` and in
  `compression-eval.sh` as the regression flag pass-rate delta.
  Configurable via `compression.regression_floor` config knob.

- **FR-12 (read-only diagnostic surfaces)** — `compression-eval.sh`
  never appends to or rewrites JSONL; always exits 0. Verified by the
  malformed-arg-combo assertions in `m018-p05-compression-eval-shape.sh`.

- **AD-19 / AP-009 single-script-file Check shape** — every truth's
  Check: line is a single bash invocation. Verifier scripts use
  pass()/fail() per MEM002 and printf-prefixed lines per MEM001.

## Followups for downstream phases

- **P06 (tier3 auto-compact)** — extends the `--tier 3` stub in
  `compression-eval.sh` to a real cohort against `tier3_savings_tokens`;
  extends dispatch_usage / unit_close additive fields with
  `tier3_compression_savings_tokens` and `tier3_invocations` per the
  same MEM004 carve-out pattern T01 established. The doctor
  compression-regression flag composes with tier3-quality regression
  once tier3 ships. The cohort-segmentation diagnostic is the gate the
  P06 LLM trust boundary (MIT-08) is verified against.

- **M027 future surfaces** — consume the additive savings fields with
  no further changes required. The rollup column-index contract is
  pinned (1-12 stable; 13-16 are the M018 savings columns).

- **M019 future surfaces** — the four additive fields on dispatch_usage
  and unit_close are the contract the M019 cost+token transparency
  surfaces (M027 extension target) read.

## Verification result

All P05 truths PASS via
`bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P05/`.
All artifacts present at required line counts with required substrings;
all key links resolve; all eight private verifiers green:

- `m018-p05-dispatch-usage-additivity.sh` — PASS (14 assertions:
  emitter source carries the four additive fields; live emit produces
  expected sums against fixture; pre-P05 record back-compat).
- `m018-p05-unit-close-additivity.sh` — PASS (18 assertions: rollup
  helper sums correctly across phase scope; live emit through
  `write-summary.sh phase` carries the four fields; pre-P05 record
  back-compat).
- `m018-p05-cost-rollup-savings-columns.sh` — PASS (12 assertions:
  header carries the four new columns; data row sums correctly;
  legacy log columns default to 0).
- `m018-p05-efficiency-footer-compression.sh` — PASS (4 assertions:
  savings-bearing fixture emits compression: line; --quiet zero
  stdout; no-savings fixture omits the line; ORCH_COMPRESSION_FOOTER
  override suppresses).
- `m018-p05-doctor-compression-regression.sh` — PASS (5 assertions:
  T01 row flagged with savings_ratio token; ORCHESTRATOR_AUTO=1 zero
  stdout; --no-anomaly zero stdout; legacy log NOT flagged).
- `m018-p05-compression-eval.sh` — PASS (13 assertions: cohort + delta
  block emitted; high floor → insufficient sample; --tier 3 stub;
  missing-log degraded text; --tier 2 cohort).
- `m018-p05-compression-eval-shape.sh` — PASS (10 assertions: file
  readable; sourceable guard present; BASH_SOURCE CLI block; MEM004
  carve-out; --help exits 0; malformed-arg combos all exit 0; bash -n;
  no declare -A; sourceable function).
- `m018-p05-dual-write-recent.sh` — PASS (CLAUDE.md + AGENTS.md
  recent-changes blocks both name M018/P05 / compression-eval).

P05 closed. M018 advances to P06 (tier3 auto-compact).

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P06"
milestone: "M018"
name: "P06 verifiers (5), fixtures (2 trees), fixture-staging helper, P06-SUMMARY (via phase-transition.sh --write), CLAUDE.md / AGENTS.md orchestrator:recent-changes dual-write"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- T01 has shipped `_bc_apply_tier3` in `scripts/dispatch/build-context.sh`, the prompt template at `templates/compression-tier3-prompt.md`, the six `kf_get_tier3_*` accessors in `scripts/lib/knowledge-filter.sh`, and the config-default block in `templates/orchestrator-config-default.yml`.
- T02 has shipped the additive `tier3_compression_savings_tokens` + `tier3_invocations` fields on `payload_breakdown`, `dispatch_usage` (both co-located + dispatch-interface), and `unit_close` JSONL records; the two new columns on `metrics-rollup.sh`; the tier3 fold into `efficiency-footer.sh` + `check-anomalies.sh`.
- T03 has replaced the `--tier 3` stub in `scripts/diagnostics/compression-eval.sh` with real cohort logic against `tier3_compression_savings_tokens`.
- The P05/T04 implementation is the canonical shape T04 mirrors. Re-read [`.orchestrator/milestones/M018/phases/P05/tasks/T04-verifiers-and-summary-PLAN.md`](../../../../../milestones/M018/phases/P05/tasks/T04-verifiers-and-summary-PLAN.md) for the verifier-shape, fixture-shape, and dual-write conventions before authoring.
- `scripts/verify/_helpers/m018-p05-build-fixture.sh` is the fixture-staging helper shape T04 mirrors. Read it once for shape (config-override scaffolding, fixture path resolution) before authoring `m018-p06-build-fixture.sh`.
- `scripts/util/dual-write-runtime-md.sh` is the canonical dual-write helper used by every prior phase. Invocation pattern: `bash scripts/util/dual-write-runtime-md.sh <orchestrator:recent-changes block content>` — writes the block to both `CLAUDE.md` and `AGENTS.md` between the `# >>> orchestrator:recent-changes >>>` and `# <<< orchestrator:recent-changes <<<` sentinels. The verifier `m018-p06-dual-write-recent.sh` only checks that both files contain "M018/P06" in their recent-changes block.
- `scripts/lifecycle/phase-transition.sh` is the canonical phase-summary writer for P06. **CRITICAL**: T04 invokes `phase-transition.sh --write` (NOT `write-summary.sh phase` directly). P05/T04 wrote the summary directly via `write-summary.sh phase` and triggered a `SYNC:MISMATCH` that needed `sync-roadmap.sh --fix`; P06 avoids the regression by using the atomic transition helper. Invocation:

  ```bash
  bash scripts/lifecycle/phase-transition.sh \
    .orchestrator/milestones/M018 P06 \
    --write \
    --body-file=.orchestrator/milestones/M018/phases/P06/_summary-body.txt \
    --observability_surfaces='execution-log.jsonl: payload_breakdown.{tier3_compression_savings_tokens,tier3_invocations} additive integer fields; ...' \
    --verification_result=pass
  ```

  The helper reads all task summaries from the phase directory, derives `provides` / `requires` / `affects` / `key_files` / `key_decisions` / `patterns_established` / `drill_down_paths` automatically, runs the external mod check, syncs the roadmap, and writes the summary atomically.
- AD-19 single-script-file `Check:` contract: every verifier exposes its truth via a single bash invocation. The verifier may shell out to subordinate helpers (e.g., `_helpers/m018-p06-build-fixture.sh`) but `check-must-haves.sh` invokes ONE bash file per truth.
- AP-009 applies to verifier scripts. No compound chains > 2; no plain subshells; no `$(... | ...)`. Verifier scripts use `pass()` / `fail()` per MEM002 and `printf 'PASS:' / printf 'FAIL:'` line-prefix convention.
- Bash 3.2 — verifiers use parallel indexed arrays (no `declare -A`).

## Description

T04 ships:

1. **One fixture-staging helper** at `scripts/verify/_helpers/m018-p06-build-fixture.sh`.
2. **Two fixture trees** under `tests/fixtures/m018-p06-{tier3-fired,tier3-failed}-log/`.
3. **Five verifier scripts** under `scripts/verify/m018-p06-*.sh` (one per mechanical truth in P06-PLAN.md):
   - `m018-p06-tier3-helper-shape.sh` — Truth #1 (helper exists + routes through dispatch-interface).
   - `m018-p06-tier3-prompt-template.sh` — Truth #2 (prompt template exists + frontmatter contract).
   - `m018-p06-tier3-additivity.sh` — Truth #3 (three-record-type additive fields).
   - `m018-p06-compression-eval-tier3.sh` — Truth #4 (tier-3 cohort replaces stub).
   - `m018-p06-dual-write-recent.sh` — Truth #5 (CLAUDE.md / AGENTS.md recent-changes).
4. **P06-SUMMARY.md** via `bash scripts/lifecycle/phase-transition.sh --write`.
5. **CLAUDE.md / AGENTS.md `orchestrator:recent-changes` dual-write** for M018/P06.

T04 does NOT ship:

- T01's helper, prompt template, or accessors.
- T02's schema field additivity.
- T03's compression-eval cohort logic.

## Inputs

Surface contracts T04 reads from upstream files:

- `scripts/verify/m018-p05-*.sh` (eight verifiers from P05) — read for the canonical verifier shape (pass()/fail() helpers, hermetic root staging via `ORCHESTRATOR_ROOT`, single-script-file Check shape, MEM004 carve-out comments where applicable).
- `scripts/verify/_helpers/m018-p05-build-fixture.sh` and `scripts/verify/_helpers/m018-p04-build-fixture.sh` — read for the fixture-staging helper shape.
- `tests/fixtures/m018-p05-savings-log/execution-log.jsonl` — read for the JSONL-record-mix shape; T04's `m018-p06-tier3-fired-log/execution-log.jsonl` extends this with tier3 fields and at least one `tier3_failed` event record.
- `scripts/lifecycle/phase-transition.sh --help` — read at integration time for the `--write` invocation surface; the canonical body-file pattern is `.orchestrator/milestones/M018/phases/P06/_summary-body.txt`.
- `scripts/util/dual-write-runtime-md.sh` — read for the recent-changes block shape.

## Steps

### Step 1 — Author `scripts/verify/_helpers/m018-p06-build-fixture.sh`

Mirror the P05 helper. Job: stage two fixture milestone directories (tier3-fired log + tier3-failed log) under `$TMPDIR_BUILD/_p06_fixture/<slug>/`, each containing:

- `.orchestrator/milestones/M-FIXTURE/execution-log.jsonl` — synthesized JSONL with the appropriate record mix.
- (Optionally) a stub `.orchestrator/config.yml` for tests that exercise config-driven knobs.

The helper takes one argument (`tier3-fired` | `tier3-failed`) and prints the staged fixture root on stdout. Idempotent (clean staging dir on re-invocation). Bash 3.2; no compound chains > 2.

### Step 2 — Author `tests/fixtures/m018-p06-tier3-fired-log/execution-log.jsonl`

Hand-craft a JSONL log with:

- 5 `payload_breakdown` records (tasks T01-T05 of a fictional M-FIXTURE milestone) carrying:
  - T01: `tier3_compression_savings_tokens=400`, `tier3_invocations=1`, `payload_tokens_estimate=2000`. Other tier savings = 0.
  - T02: `tier3_compression_savings_tokens=600`, `tier3_invocations=1`, `payload_tokens_estimate=3000`.
  - T03: `tier3_compression_savings_tokens=0`, `tier3_invocations=0`, `payload_tokens_estimate=2500` (uncompressed-cohort representative).
  - T04: `tier3_compression_savings_tokens=800`, `tier3_invocations=1`, `payload_tokens_estimate=3500` (high-savings).
  - T05: `tier3_compression_savings_tokens=0`, `tier3_invocations=0`, `payload_tokens_estimate=2200` (uncompressed-cohort representative).
- 5 `unit_close` records (granularity=task) for the same five tasks with `verification_pass_rate=1.0`, `retry_count=0`, `deviation_count=0`. Compressed cohort: T01/T02/T04 (tier3 fired). Uncompressed cohort: T03/T05.
- 1 `tier3_skipped` record naming `reason=density-floor` (exercises the helper's MIT-08 short-circuit emit).
- 1 pre-P06 row at the top of the file: a `payload_breakdown` record from a hand-curated baseline carrying ONLY the four P05 fields and NONE of the tier3 fields. The verifier's back-compat assertion confirms this row still parses as valid JSON and treats absent tier3 fields as zero.

Add a `tests/fixtures/m018-p06-tier3-fired-log/README.md` documenting the fixture's record mix and what each verifier expects.

### Step 3 — Author `tests/fixtures/m018-p06-tier3-failed-log/execution-log.jsonl`

Hand-craft a smaller JSONL log carrying:

- 2 `payload_breakdown` records with `tier3_compression_savings_tokens=0`, `tier3_invocations=0` (T3 didn't fire because it failed-passthrough).
- 2 `tier3_failed` records naming `reason=llm-call-nonzero` and `reason=preservation-breach` respectively (exercises the failure-passthrough emit path from T01).
- 2 `unit_close` records with `verification_pass_rate=1.0` (the dispatches still succeeded — failure-passthrough means the agent received the Tier 2 output and ran successfully on it).

Add a `README.md` documenting the failure-passthrough scenario.

### Step 4 — Author `scripts/verify/m018-p06-tier3-helper-shape.sh` (Truth #1)

Single bash file. Asserts:

- The string `_bc_apply_tier3` exists in `scripts/dispatch/build-context.sh` (helper shipped).
- The string `dispatch-interface.sh` is referenced inside the `_bc_apply_tier3` function body (uses `awk` to extract the function body and `grep` for the reference).
- The string `compression-tier3-prompt.md` is referenced inside the helper body.
- The pipeline-wiring tail invokes `_bc_apply_tier3 "$PAYLOAD_CAPTURE"` between `_bc_apply_tier2` and `_bc_emit_payload_breakdown`.
- The six `kf_get_tier3_*` accessors exist in `scripts/lib/knowledge-filter.sh`.
- `bash -n scripts/dispatch/build-context.sh` exits 0.
- `bash -n scripts/lib/knowledge-filter.sh` exits 0.

Verifier uses `pass() / fail()` per MEM002. AD-19 single-script-file Check shape — the verifier itself is the canonical Check.

### Step 5 — Author `scripts/verify/m018-p06-tier3-prompt-template.sh` (Truth #2)

Single bash file. Asserts:

- `templates/compression-tier3-prompt.md` exists.
- The template's frontmatter declares `tier: 3` and `applies_to: ["dispatch-payload-section"]`.
- The frontmatter `preserves:` array contains every preserved-pattern token named in `references/compression-grammar.md` Tier 3 section (frontmatter, code fences, JSONL records, MEM identifiers, paths, scaffold-placeholder markers, URLs, command names, in-band markers).
- The body contains the literal substring `compressed:tier3 model=<MODEL> input_tokens=<N> output_tokens=<M>` (the in-band marker the helper substitutes post-call).
- The body contains the literal `## Section to compress` header (last section of the template, where the helper appends the section bytes).

### Step 6 — Author `scripts/verify/m018-p06-tier3-additivity.sh` (Truth #3)

Single bash file. Stages a fixture log via `_helpers/m018-p06-build-fixture.sh tier3-fired`, then asserts:

- The fixture's `payload_breakdown` records (post-T02) carry both `"tier3_compression_savings_tokens":` and `"tier3_invocations":` fields with non-negative integer values.
- A pre-P06 `payload_breakdown` row in the fixture (the hand-curated baseline at the top) parses as valid JSON via a minimal awk/sed parse-check (or `python3 -c 'import json,sys; [json.loads(l) for l in sys.stdin]'` if available).
- Driving `_di_emit_dispatch_usage` (or equivalent — the verifier may invoke `bash scripts/dispatch/dispatch-interface.sh ...` against the fixture root if the CLI exposes the emit, otherwise it shims the function via the same shape pattern P05/T04 used) produces a `dispatch_usage` record with both new fields, and the values are the SUM of the in-scope payload_breakdown rows (not just one row).
- Driving `_ws_emit_unit_close` (via `bash scripts/knowledge/write-summary.sh phase ...` against the fixture root) produces a `unit_close` record with the new fields rolled up at granularity-aware scope.
- `bash scripts/diagnostics/metrics-rollup.sh --milestone M-FIXTURE` (with `ORCHESTRATOR_ROOT=<fixture-root>`) emits a header containing `TIER3_SAVINGS` and `TIER3_INVOCS` and a data row with integer values for those columns.
- `bash scripts/diagnostics/efficiency-footer.sh --milestone M-FIXTURE` emits a `compression:` line whose percent reflects the SUM of all four P05 fields plus tier3_savings (not just the P05 fields).
- `bash scripts/diagnostics/check-anomalies.sh --milestone M-FIXTURE --sample-floor 1` produces output where any flagged row's `savings_ratio` reflects the widened sav_total (the verifier confirms tier3_savings is folded into the denominator by checking ratio against the known fixture-row inputs).

### Step 7 — Author `scripts/verify/m018-p06-compression-eval-tier3.sh` (Truth #4)

Single bash file. Asserts:

- `bash scripts/diagnostics/compression-eval.sh --milestone M-FIXTURE --tier 3 --sample-floor 1` (with `ORCHESTRATOR_ROOT=<tier3-fired-fixture>`) emits a `# compression-eval — milestone=M-FIXTURE tier=3` header followed by a `COHORT` line with `compressed`, `uncompressed`, and `delta` rows. Exit 0.
- The output contains `regression_flag:` (advisory line — value is "none" expected on this fixture because pass-rates are 1.0/1.0 across cohorts).
- `bash scripts/diagnostics/compression-eval.sh --milestone M-FIXTURE --tier 3 --sample-floor 1000` emits an `insufficient sample` line and exits 0 (cohort sizes are below the floor).
- The output never contains the literal "tier 3 reserved for P06" (regression check — confirms the stub is gone).
- `bash -n scripts/diagnostics/compression-eval.sh` exits 0.
- `bash scripts/diagnostics/compression-eval.sh --tier 3` against an absent log emits a degraded-input line and exits 0 (FR-12 / CON-5 always-exit-0 contract preserved).

### Step 8 — Author `scripts/verify/m018-p06-dual-write-recent.sh` (Truth #5)

Single bash file. Asserts:

- `CLAUDE.md` contains a `# >>> orchestrator:recent-changes >>>` block.
- `AGENTS.md` contains a `# >>> orchestrator:recent-changes >>>` block.
- Both blocks contain the literal substring `M018/P06`.
- Both blocks contain the literal substring `tier3` (or `compression-tier3-prompt`).

Mirrors `m018-p05-dual-write-recent.sh` exactly (substituting `M018/P05` → `M018/P06`).

### Step 9 — Run all five verifiers; iterate until green

Each verifier must exit 0 and emit `PASS:` lines per assertion. Failures emit `FAIL:` with a message naming the file/line/value mismatch.

```bash
bash scripts/verify/m018-p06-tier3-helper-shape.sh
bash scripts/verify/m018-p06-tier3-prompt-template.sh
bash scripts/verify/m018-p06-tier3-additivity.sh
bash scripts/verify/m018-p06-compression-eval-tier3.sh
bash scripts/verify/m018-p06-dual-write-recent.sh
```

(The dual-write verifier won't pass until Step 11 lands the dual-write block.)

### Step 10 — Author `_summary-body.txt` for `phase-transition.sh --write`

Write the P06-SUMMARY narrative body to `.orchestrator/milestones/M018/phases/P06/_summary-body.txt`. Mirror the P05-SUMMARY narrative shape (the `## Risk-mitigation traceability`, `## Followups for downstream phases`, `## Verification result` sections). Name what P06 ships:

- `_bc_apply_tier3` LLM-routed summarization helper with intensity-gate, MIT-08 density pre-check, originals persistence, failure-passthrough.
- `templates/compression-tier3-prompt.md` summarization prompt template.
- Six `kf_get_tier3_*` config accessors.
- Additive `tier3_compression_savings_tokens` + `tier3_invocations` fields on `payload_breakdown` / `dispatch_usage` / `unit_close`.
- New `tier3_skipped` / `tier3_failed` / `tier3_no_savings` JSONL record schemas.
- `metrics-rollup.sh` `TIER3_SAVINGS` + `TIER3_INVOCS` columns.
- `efficiency-footer.sh` + `check-anomalies.sh` tier3-fold widening.
- `compression-eval.sh --tier 3` real cohort logic replacing the P05 stub.
- Five P06-private truth verifiers + two fixture trees + fixture-staging helper.
- CLAUDE.md / AGENTS.md `orchestrator:recent-changes` dual-write.

Note RISK-3 disposition: state explicitly that the diagnostic surface is operational, that current cohort sizes are below the statistical floor (insufficient sample), that this is treated as a non-regression for P06 close per the spec's RISK-3 framing, and that subsequent milestones will exercise the tier-3 cohort and re-evaluate.

### Step 11 — Dual-write the `orchestrator:recent-changes` block

```bash
bash scripts/util/dual-write-runtime-md.sh '030-context-compression-layer / M018/P06: tier3 auto-compact live in build-context.sh (_bc_apply_tier3: dispatch-interface.sh-routed summarization with intensity-gate, MIT-08 density pre-check, originals persistence to .orchestrator/cache/tier3-originals/, failure-passthrough emitting tier3_failed JSONL); templates/compression-tier3-prompt.md (versioned frontmatter + preserved-pattern body); additive tier3_compression_savings_tokens / tier3_invocations fields on payload_breakdown / dispatch_usage / unit_close (CON-5); compression-eval.sh --tier 3 real cohort logic replaces the P05 stub.'
```

Re-run `bash scripts/verify/m018-p06-dual-write-recent.sh` and confirm PASS.

### Step 12 — Run `phase-transition.sh --write` to atomically write P06-SUMMARY.md + sync roadmap

```bash
bash scripts/lifecycle/phase-transition.sh \
  .orchestrator/milestones/M018 P06 \
  --write \
  --body-file=.orchestrator/milestones/M018/phases/P06/_summary-body.txt \
  --observability_surfaces='execution-log.jsonl: payload_breakdown.{tier3_compression_savings_tokens,tier3_invocations} additive integer fields; dispatch_usage.{tier3_compression_savings_tokens,tier3_invocations} rolled-up additive fields; unit_close.{tier3_compression_savings_tokens,tier3_invocations} granularity-aware additive fields; tier3_skipped / tier3_failed / tier3_no_savings new JSONL record_types (additive); metrics-rollup.sh stdout: TIER3_SAVINGS / TIER3_INVOCS columns; efficiency-footer.sh stdout: compression: line numerator widens to fold tier3 savings; check-anomalies.sh stdout: compression-regression denominator widens to fold tier3 savings; compression-eval.sh stdout: --tier 3 cohort + delta block with 95% CIs and regression_flag (no longer P06-reservation stub).' \
  --verification_result=pass
```

Expected: `phase-transition.sh` reads all four task summaries, derives `provides` / `requires` / `affects` / etc. fields automatically, syncs the roadmap, writes `P06-SUMMARY.md` atomically, and emits a `TRANSITION:READY phase=P06 fields_derived=N` status line. No `SYNC:MISMATCH`.

### Step 13 — Run `check-must-haves.sh` against the phase

```bash
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P06/
```

Expected: every truth Check passes; every artifact line-count + substring matches; every key-link resolves.

## Verification

T04's task-local extractable Check is the syntax-only self-check on the closing-task verifier:

- Check: `bash -n scripts/verify/m018-p06-dual-write-recent.sh`

(One Check per task per the auto-loop verify parser. The five canonical truth verifiers are themselves the phase-level Checks; T04's task-local Check is on the dual-write verifier, which is the truth most tightly tied to T04 itself — the dual-write block is written by T04 alone.)

## Must-Haves (subset addressed by this task)

- **Truth #5** (dual-write recent-changes): wholly addressed by Steps 8 + 11.
- **Truths #1, #2, #3, #4**: T04 ships the canonical verifiers that exercise the truths end-to-end; the underlying production code ships in T01/T02/T03. T04 closes the verification loop on all four mechanical truths plus the dual-write truth.
- **RISK-3 phase-close gate**: T04 executes the manual review of `compression-eval.sh --milestone M018 --tier 3` and records the disposition in `_summary-body.txt` (Step 10 narrative).

## Notes

- **`phase-transition.sh --write` (NOT `write-summary.sh phase`)**: this is the load-bearing convention. P05/T04 wrote the summary directly via `write-summary.sh phase` and had to fix a `SYNC:MISMATCH` post-hoc with `sync-roadmap.sh --fix`. P06 atomically transitions roadmap + disk via the lifecycle helper, avoiding the regression. The helper invokes `write-summary.sh phase` internally with the correctly-derived field values.
- **Five truths, five verifiers** (vs P05's eight): P06's surface is narrower because the schema additivity is concentrated on a single tier and the rollup-fold is a denominator widen rather than a new column block. The five-truth split is:
  1. helper shape (T01),
  2. prompt template shape (T01),
  3. three-record-type additivity end-to-end (T02 + T03's read-side),
  4. compression-eval `--tier 3` cohort (T03),
  5. dual-write (T04).
- **RISK-3 disposition**: the spec's RISK-3 gate says "P06's `unit_close: pass` is gated by `compression-eval.sh` showing no statistically significant outcome-rate regression vs the uncompressed cohort." At P06 close, the cohort sizes will likely be below the sample floor (the diagnostic emits `insufficient sample` and exits 0). Per the spec's framing, this counts as a non-regression — the diagnostic is operational, the cohort split logic works against the fixture log, and subsequent milestones will exercise the diagnostic against larger n. Document this disposition in `_summary-body.txt` so the next operator reading P06-SUMMARY understands the RISK-3 framing without needing to re-derive it.
- **Hermetic fixtures**: every verifier uses `ORCHESTRATOR_ROOT=<fixture-root>` to point production scripts at the fixture log. The fixture-staging helper is the canonical entry point — it stages a fully-formed `.orchestrator/`-style root with `milestones/M-FIXTURE/execution-log.jsonl` and a minimal `config.yml`. Production scripts never write to the fixture; verifiers only read.
- **Five verifiers, single-file Check shape**: every verifier's body is invoked via a single bash file (`bash scripts/verify/m018-p06-<truth>.sh`); verifiers internally shell out to the fixture-staging helper for setup. AD-19 single-script-file Check shape is satisfied at the truth-level.
- **Pre-P06 record back-compat**: every additivity verifier asserts that a hand-curated pre-P06 row (no tier3 fields) parses as valid JSON and that downstream consumers treat absent fields as zero. CON-5 contract verified end-to-end.
- **Bash 3.2** (MEM001): no `declare -A`. Verifier scripts use parallel indexed arrays + `pass() / fail()` per MEM002.
- **The `--tier 3` cohort RISK-3 manual review** is recorded in `_summary-body.txt`, not in a separate file — the operator running `orchestrator:auto` reads the summary at phase-close time and confirms the disposition. The disposition is "operational; insufficient sample at P06 close; non-regression by spec framing."

## State Context

- **Current State**: executing
- **Milestone**: M018
- **Phase**: P06
- **Task**: T04-verifiers-and-summary
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints


### Acceptance Criteria


### Files To Touch

- scripts/dispatch/build-context.sh (modify) — add `_bc_apply_tier3` helper, extend `_bc_emit_payload_breakdown` with the two additive fields, wire intensity-gate + failure-passthrough.
- scripts/lib/knowledge-filter.sh (modify) — add `kf_get_tier3_*` config accessors.
- scripts/dispatch/dispatch-interface.sh (modify) — extend `_di_emit_dispatch_usage` with tier3 rollup.
- scripts/knowledge/write-summary.sh (modify) — extend `_ws_emit_unit_close` with tier3 rollup (granularity-aware).
- scripts/diagnostics/metrics-rollup.sh (modify) — append `TIER3_SAVINGS` + `TIER3_INVOCS` columns after the four P05 columns.
- scripts/diagnostics/efficiency-footer.sh (modify) — fold tier3_savings into the compression-line numerator.
- scripts/diagnostics/check-anomalies.sh (modify) — fold tier3_savings into sav_total denominator.
- scripts/diagnostics/compression-eval.sh (modify) — replace `--tier 3` reservation stub with real cohort logic.
- templates/compression-tier3-prompt.md (create).
- scripts/verify/m018-p06-tier3-helper-shape.sh (create).
- scripts/verify/m018-p06-tier3-prompt-template.sh (create).
- scripts/verify/m018-p06-tier3-additivity.sh (create).
- scripts/verify/m018-p06-compression-eval-tier3.sh (create).
- scripts/verify/m018-p06-dual-write-recent.sh (create).
- scripts/verify/_helpers/m018-p06-build-fixture.sh (create).
- tests/fixtures/m018-p06-tier3-fired-log/execution-log.jsonl (create).
- tests/fixtures/m018-p06-tier3-fired-log/README.md (create).
- tests/fixtures/m018-p06-tier3-failed-log/execution-log.jsonl (create).
- tests/fixtures/m018-p06-tier3-failed-log/README.md (create).
- [.orchestrator/milestones/M018/phases/P06/P06-SUMMARY.md](../../../../../milestones/M018/phases/P06/P06-SUMMARY.md) (create).
- CLAUDE.md (modify) — `orchestrator:recent-changes` block.
- AGENTS.md (modify) — `orchestrator:recent-changes` block (dual-write mirror).

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