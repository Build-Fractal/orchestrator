---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T01-hook-self-locate (Phase P02, Milestone M028)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~700 | required |
| Upstream Context | 981-1048 | ~2900 | required |
| Task Plan | 1050-1216 | ~3500 | required |
| State Context | 1218-1224 | ~100 | required |
| First-Turn Completeness | 1226-1262 | ~700 | required |
| **Total** | | **~18700** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 630
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
hit_count: 630
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
hit_count: 630
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
hit_count: 630
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
hit_count: 559
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
hit_count: 559
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
hit_count: 559
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
hit_count: 630
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
hit_count: 559
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
hit_count: 559
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
hit_count: 559
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
hit_count: 630
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
hit_count: 630
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
hit_count: 630
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
hit_count: 559
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
hit_count: 559
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
hit_count: 559
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
hit_count: 630
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
hit_count: 559
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
hit_count: 559
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
hit_count: 630
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
hit_count: 630
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
hit_count: 559
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
hit_count: 559
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
hit_count: 559
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
hit_count: 214
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
hit_count: 214
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
hit_count: 214
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
hit_count: 206
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
hit_count: 206
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
hit_count: 196
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

- The PreToolUse shape-guard hook resolves its classifier and reject_lookup paths via `$(dirname "${BASH_SOURCE[0]}")` (with symlink resolution) and never references `$CLAUDE_PROJECT_DIR`. Verified by inspecting the hook body for the literal `BASH_SOURCE` self-location pattern and the absence of any `CLAUDE_PROJECT_DIR` reference inside the resolution block. Satisfies FR-2 + US-1 acceptance scenario 4.
  - Check: `bash scripts/verify/m028/p02-hook-self-locate.sh`

- The Claude Code runtime adapter emits, for every hook entry, a `command` field of the literal shape `bash <hooks-dir>/<name>.sh` (never a bare command name) and every emitted leaf object carries `_orchestrator_managed: true`. Verified by capturing `--hook-config` output and asserting each `command` field starts with `bash ` and ends with `.sh`, and that the count of `_orchestrator_managed: true` flags equals the count of leaf hook objects. Satisfies FR-3 + FR-4 + US-1 + US-3 acceptance scenario 4.
  - Check: `bash scripts/verify/m028/p02-adapter-absolute-paths.sh`

- The shape-guard hook self-conforms to its own classifier output under AP-009 (no compound chain exceeding 2 connectors anywhere in its body). Verified by sourcing the [M021](../../../../../milestones/M021/index.md) classifier, scanning the hook body line-by-line, and asserting `classify_command` returns ALLOW for every non-comment non-blank line. Satisfies CON-3 + FR-21 (P02 half — P03's `finding-G-self-conformance.sh` verifies via the M028 classifier; P02 verifier here uses M021 classifier as the day-one floor).
  - Check: `bash scripts/verify/m028/p02-hook-self-conformance.sh`

- `settings-merge.sh merge` is install-side idempotent — running the install path twice in succession against the same target settings.json produces a byte-identical file (SHA-256 equal). The dedup key is `(event, matcher, command) × _orchestrator_managed: true`. Verified by the install-roundtrip pinned-sha gate.
  - Check: `bash scripts/verify/m028/install-roundtrip.sh`

- `bash packaging/install/install-claude-code.sh --uninstall` against a post-install state returns `~/.claude/settings.json` to its pre-install canonical bytes (M025 reversibility extended to M028's expanded entry set). Verified by the install-roundtrip pinned-sha gate's reversibility leg.
  - Check: `bash scripts/verify/m028/install-roundtrip.sh`

- `bash packaging/install/install-claude-code.sh --repair` (and the `--repair --dry-run` preview) removes flag-less orphan entries whose `(event, matcher, command)` tuple matches a known M025 pattern fingerprint (exact-tuple match, never structural-shape match) and preserves user-authored entries verbatim. Verified by running the repair path against the canonical pre-repair fixture P01/T02 produced and asserting the result matches a canonical post-repair reference.

<dispatch-volatile>

## Upstream Context


### P01 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M028"
milestone: "M028"
provides:
  - "classifier-replay audit covering all 9 M028 source events (Findings A-G); per-event classifier verdict captured verbatim from M021 shape-classifier.sh git SHA 12fcd98; replay-coverage verifier,canonical M028 pre-repair fixture (sanitized operator M018-close ~/.claude/settings.json backup) at tests/fixtures/m028-pre-repair-snapshot.json; deterministic sanitizer scripts/verify/m028/p01-fixture-sanitize.sh; must-have verifier scripts/verify/m028/p01-fixture-sanitized.sh,P01-VERIFICATION.md collapse-decision evidence document at .orchestrator/milestones/M028/phases/P01/P01-VERIFICATION.md (per-screenshot causal trace for SE-01 through SE-09,explicit collapse_decision frontmatter field,corpus staging list consumed by P03); shape verifier scripts/verify/m028/p01-collapse-decision-recorded.sh (AD-19 single-script-file,bash 3.2 + POSIX-sh-safe,asserts frontmatter and section headings and Resolved-by-Finding-A-alone YES/NO discipline)"
requires:
  - "none"
affects:
  - "P02"
key_files:
  - "[.orchestrator/milestones/M028/phases/P01/classifier-audit.md](../../../../../milestones/M028/phases/P01/classifier-audit.md);scripts/verify/m028/p01-replay-coverage.sh;scripts/verify/m028/p01-classify-one.sh,tests/fixtures/m028-pre-repair-snapshot.json;scripts/verify/m028/p01-fixture-sanitize.sh;scripts/verify/m028/p01-fixture-sanitized.sh,.orchestrator/milestones/M028/phases/P01/P01-VERIFICATION.md;scripts/verify/m028/p01-collapse-decision-recorded.sh"
key_decisions:
  - "9 source events enumerated (SE-01 Finding A non-firing,SE-02..SE-05 Finding B four shapes,SE-06 Finding C,SE-07 Finding D,SE-08 Finding F adapter+installer non-Bash,SE-09 Finding G); SE-06 and SE-09 already reject under M021 as compound-chain-gt2 (AP-009); SE-02..SE-05 and SE-07 currently classify as allow (the gap M028 closes via AP-010..AP-014); SE-01 + SE-08 are non-classifier events (portability + adapter-emission),partial-flag fixture shape (5 unflagged + 1 flagged Stop entries; 7 unflagged + 1 flagged PreToolUse Bash entries) preserves Finding F regression evidence while satisfying _orchestrator_managed anchor must-have; token-redaction regex restricted to a 32+ char alphanumeric (plus underscore and hyphen) class drops + / = from char class to prevent path-segment false positives; sanitization implemented in two stages -- sed for path/email/token bytes,python3 for structural flag injection -- both deterministic,collapse_decision=full-5-phase based on M=0 of N=7 (threshold 6 not met); SE-01 contributes to A but is NOT resolved-by-A-alone because its in-family commands SE-02..SE-05 all yield existing verdict allow (hook portability alone does not eliminate the in-the-wild failures); SE-09 attributed to G not A despite running on the orchestrator repo itself because the in-tree event proves hook portability is irrelevant to the body-descent bypass surface; corpus staging count is 5 (one per reserved AP-ID) with the FR-13 reconciliation to 7 explicitly delegated to P03 per the rubric in the task plan"
patterns_established:
  - "staged-probe replay shape: write probe under tmp/<milestone>-<phase>/ then invoke via scripts/util/run-probe.sh,source the classifier and call classify_command verbatim,capture stdout byte-exact for the audit's fenced verdict block; throwaway shim under scripts/verify/<milestone>/p01-classify-one.sh as AD-19 single-script-file flat shape,two-stage deterministic sanitization (BSD-portable sed -E for byte-level redactions then python3 json mutation for structural injection); partial-flag fixture realism (mixing pre-M025 unflagged residue with post-M025 flagged entries reflects real downstream user systems); separate -sanitize (transformer,runs once at fixture creation) and -sanitized (verifier,runs at every phase verification) script naming,rubric-driven attribution (verdict + shape + path-prefix triggers map mechanically to Findings A through G; reproducible from classifier-audit.md alone); shape-only verifier discipline (the verifier asserts frontmatter and section headings and per-line YES/NO tokens,never the M/N arithmetic values themselves -- the document body shows the math); corpus-staging delegation pattern (T03 lands the AP-anchored entries derivable from per-screenshot evidence,P03 owns regression and boundary-case padding to the FR-13 target)"
drill_down_paths:
  - "[.orchestrator/milestones/M028/phases/P01/tasks/T01-classifier-replay-audit-SUMMARY.md](../../../../../milestones/M028/phases/P01/tasks/T01-classifier-replay-audit-SUMMARY.md), [.orchestrator/milestones/M028/phases/P01/tasks/T02-fixture-snapshot-SUMMARY.md](../../../../../milestones/M028/phases/P01/tasks/T02-fixture-snapshot-SUMMARY.md), [.orchestrator/milestones/M028/phases/P01/tasks/T03-collapse-decision-evidence-SUMMARY.md](../../../../../milestones/M028/phases/P01/tasks/T03-collapse-decision-evidence-SUMMARY.md)"
duration: "120m"
verification_result: "pass"
completed_at: "2026-04-29T14:18:48Z"
observability_surfaces:
  - "none"
---

P01 closes the M028 input audit and pins the collapse decision: **`full-5-phase`** (P02–P05 stay as-roadmapped). The phase produced three deliverable rounds plus the canonical pre-repair fixture and the verifier triad that downstream phases consume.

## What was built

- **T01 — classifier replay audit** (`classifier-audit.md`, 211 lines, 9 source events). Every M028 source event (Findings A–G plus the operator-reported Stop-hook event) replayed verbatim through the M021 shape classifier (`scripts/verify/lib/shape-classifier.sh` git SHA `12fcd98`). Per-event verdict captured byte-exact in fenced blocks. Two SEs already reject under M021 as `compound-chain-gt2` anchored on AP-009 (SE-06 Finding C, SE-09 Finding G); four SEs classify as `allow` (SE-02..SE-05 Finding B), confirming the spec's gap narration that AP-010..AP-013 close real shapes; SE-07 Finding D classifies as `allow` (destructive-op prompting is shape-independent at the CC layer); SE-01 + SE-08 are non-classifier events (portability + adapter-emission). Replay-coverage verifier `scripts/verify/m028/p01-replay-coverage.sh` PASS.

- **T02 — pre-repair fixture snapshot** (`tests/fixtures/m028-pre-repair-snapshot.json`, 173 lines). Operator's M018-close `~/.claude/settings.json.bak` captured and sanitized: `/Users/brettkellgren/`, the standalone `brettkellgren` token, the operator email, and 32+ char alphanumeric token-like runs all redacted via BSD-portable `sed -E`; `python3` then appended one `_orchestrator_managed: true` entry per `Stop` and `PreToolUse` array. Partial-flag shape preserved (5 unflagged + 1 flagged Stop entries; 7 unflagged + 1 flagged PreToolUse Bash entries) — models the realistic post-M025 mixed-state P02 `--repair` will encounter. Char class deliberately excludes `+ / =` to prevent path-segment false positives. Sanitization is deterministic (double-run byte-identity diff). Two scripts: `p01-fixture-sanitize.sh` (one-shot transformer) + `p01-fixture-sanitized.sh` (must-have verifier). Both PASS.

- **T03 — collapse-decision evidence** (`P01-VERIFICATION.md`, 165 lines, frontmatter `collapse_decision: "full-5-phase"`). Per-screenshot causal trace for SE-01..SE-09; collapse-decision arithmetic M=0 of N=7 (threshold M≥N−1=6 not met); 5-entry corpus staging list with FR-13-to-7 padding delegated to P03. Reasoning summary: hook portability resolves zero events because the four B-family screenshots all carry existing-classifier verdict `allow` (the classifier under-matches regardless of where the hook fires); SE-07 and SE-06 are wrapper-class remediations independent of portability; SE-09 was observed in-tree on the orchestrator repo itself, proving portability is irrelevant to the body-descent bypass surface AP-014 closes. Shape verifier `p01-collapse-decision-recorded.sh` PASS.

## Verification

- Tier 1 (`check-must-haves.sh`): **22/22 PASS** — 3 truths (all carrying `Check:` sub-items), 12 artifact assertions, 2 key-link cross-references, 5 file-presence checks.
- Tier 1 (`check-boundary-map.sh`): SKIP (P01 has no boundary-map produce items).
- Tier 2 (`run-commands.sh`): SKIP (no project-level verification commands configured).
- Tier 3 (behavioral truths): N/A — all P01 truths carry `Check:` sub-items, fully covered at Tier 1.
- Tier 4 (human review): not gated for this phase.

## Patterns established

- **Staged-probe replay shape**: write probe under `tmp/<milestone>-<phase>/`, invoke via `scripts/util/run-probe.sh`, source the classifier and call `classify_command` verbatim, capture stdout byte-exact for the audit's fenced verdict block. Throwaway shim under `scripts/verify/<milestone>/p01-classify-one.sh` as AD-19 single-script-file flat shape.
- **Two-stage deterministic sanitization**: BSD-portable `sed -E` for byte-level redactions (paths, emails, tokens) → `python3` for structural JSON mutation (flag injection). Both stages deterministic, double-run byte-identity verified.
- **Partial-flag fixture realism**: mix pre-M025 unflagged residue with post-M025 flagged entries — models the real downstream user state P02 `--repair` will encounter, not the empty-or-fully-tagged synthetic case.
- **Separate `-sanitize` vs `-sanitized` scripts**: transformer runs once at fixture creation; verifier runs at every phase verification. Naming makes the role unambiguous.
- **Rubric-driven attribution**: verdict + shape + path-prefix triggers map mechanically to Findings A–G, reproducible from `classifier-audit.md` alone.
- **Shape-only verifier discipline**: the verifier asserts frontmatter and section headings and per-line YES/NO tokens, never the M/N arithmetic values themselves — the document body shows the math, the verifier proves the document shape.
- **Corpus-staging delegation**: T03 lands the AP-anchored entries derivable from per-screenshot evidence; P03 owns regression and boundary-case padding to the FR-13 target of 7 entries.

## Dogfood findings

- **auto-loop `--step=V` eval'd `Expected output:` example fences as commands.** First run of T01 verification reported false `AUTO:VERIFY_FAIL` because the parser eval'd `PASS: ...` example output as a literal shell command. Two-layer fix landed in commit `73effdc`: (a) parser-side defensive skip in `scripts/lifecycle/auto-loop.sh:340-353` for verifier-verdict prefixes (`PASS:`, `FAIL:`, `WARN:`, `OK:`, `SKIP:`, `ERROR:`, `INFO:`, `EXPECT:`, `EXPECTED:`, `Expected:`, `Output:`, `Sample:`); (b) plan-author guidance in `commands/plan-phase.md:190` documenting "`## Verification` carries executable checks only; expected output goes in `## Notes`". Regression coverage: `tests/test-auto-loop-verify-extraction.sh` Test 3 + `tests/fixtures/.../T03-PLAN.md`. M028/P01/T01..T03 plans reshaped to match. CLAUDE.md hotfix-log entry captures the dogfood for future plan authors and parser-touchers.
- **Per-task commit discipline drift.** T01 committed its work; T02 did not (orchestrator stitched it up). T03 committed correctly after the dispatch prompt was made explicit. No long-term remediation needed at the phase level — the dispatch prompt convention now reminds agents to commit before writing the summary.

## Roadmap state

P02 (installer + adapter portability + install-side dedup) consumes the canonical fixture (T02 deliverable) and the AP-anchored corpus seed list (T03 staging). No roadmap deviation: the collapse-decision recommendation is `full-5-phase`, so no phase removal or reshaping is triggered. The decisions register requires no new entry — the audit and recommendation are documented in `P01-VERIFICATION.md` itself, which is the canonical evidence artifact per the M028 plan.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M028"
name: "Hook self-location via BASH_SOURCE (Finding A core)"
depends_on: []
---

## Prerequisites

- `scripts/hooks/pre-bash-shape-guard.sh` exists at the M021 baseline shape (PreToolUse hook for the `Bash` tool, sources `scripts/verify/lib/shape-classifier.sh`, defines an inline `reject_lookup` function, exits 0 / 0+stdout / 2 per the `(a) passthrough / (b) rewrite / (c) reject` protocol). Confirm the file is present with `bash scripts/util/run-probe.sh scripts/hooks/pre-bash-shape-guard.sh`. The file's current resolution block (lines 38–44 at the time of the M028 spec authoring) reads:

    ```
    REPO_ROOT="${CLAUDE_PROJECT_DIR:-}"
    if [ -z "$REPO_ROOT" ] || [ ! -d "$REPO_ROOT" ]; then
      REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    fi
    CLASSIFIER="${REPO_ROOT}/scripts/verify/lib/shape-classifier.sh"
    ```

    This task replaces the project-relative-first / self-relative-fallback shape with a pure self-relative resolution that is location-stable in the runtime-stable hooks dir P02 ships into (`~/.claude/orchestrator-hooks/`).

- `scripts/verify/lib/shape-classifier.sh` exists (M021/P03 deliverable). The hook will continue to source it; T01 does not modify the classifier.

- `scripts/util/run-probe.sh` exists (M021 deliverable). Used to invoke other scripts under the harness shape-guard.

- `scripts/verify/m028/` directory exists (P01 created it). T01 adds two new verifiers under it.

- The pre-existing M021 self-conformance contract (no compound chain > 2 connectors anywhere in the hook body — AP-009) MUST be preserved by every line T01 introduces. CON-3 is hard-gated from day one.

## Description

Refactor `scripts/hooks/pre-bash-shape-guard.sh` so its classifier and reject_lookup-data paths are resolved purely from `${BASH_SOURCE[0]}` — never from `$CLAUDE_PROJECT_DIR`. After T03's installer ships the hook to `~/.claude/orchestrator-hooks/pre-bash-shape-guard.sh`, the hook will sit alongside `shape-classifier.sh` in the same dir; T01's resolution must locate the classifier as a sibling of the hook (`<hook-dir>/shape-classifier.sh`), with a one-step parent-fallback for in-tree development (where the hook lives at `scripts/hooks/` and the classifier lives at `scripts/verify/lib/`).

The two-location strategy:
1. Compute `HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"` (resolves symlinks via `pwd -P`).
2. If `${HOOK_DIR}/shape-classifier.sh` exists, set `CLASSIFIER` to that. (Runtime-stable installed location.)
3. Else if `${HOOK_DIR}/../verify/lib/shape-classifier.sh` exists, set `CLASSIFIER` to that. (In-tree development location: hook at `scripts/hooks/`, classifier at `scripts/verify/lib/`.)
4. Else exit 0 (passthrough). The hook NEVER hard-fails on missing classifier — fails-open is the safe default for a pre-tool hook (matches M021 baseline behavior); the install-roundtrip gate (T05) is responsible for proving the classifier was actually staged.

Author the refactor under the AP-009 self-conformance constraint: every line must lint clean against the M021 classifier output. The check is "no compound chain exceeding 2 connectors" — count `&&`, `||`, `;`, `|` connectors per line and keep each line ≤ 2.

Land two new verifiers under `scripts/verify/m028/`:
- `p02-hook-self-locate.sh` — asserts the hook body contains the `BASH_SOURCE[0]` self-resolve pattern AND contains zero references to `CLAUDE_PROJECT_DIR` inside the resolution block (lines after `# Locate repo root + classifier` up to the next `# ---` section divider). The verifier reads the file with `grep -n` / `sed -n` only.
- `p02-hook-self-conformance.sh` — sources `scripts/verify/lib/shape-classifier.sh`, reads `scripts/hooks/pre-bash-shape-guard.sh` line-by-line skipping comments and blank lines, and asserts `classify_command` returns ALLOW for every line. Single-script-file shape per AD-19; no inline compound bash, no `( ... )` plain subshell, no `$(...)` containing a pipe.

## Steps

1. Read `scripts/hooks/pre-bash-shape-guard.sh` end to end to confirm the current resolution block (around lines 35–44) and understand the surrounding hook protocol. Note the file uses `set -u` and is bash 3.2 safe.

2. Replace the resolution block (between the `# Locate repo root + classifier` divider and the `# Read stdin (Claude Code's hook JSON)` divider) with the self-relative two-location pattern. Verbatim shape (note: each line ≤ 2 connectors; the `if/else if` is multi-line not chained):

    ```bash
    # -----------------------------------------------------------------------------
    # Locate classifier — self-relative via BASH_SOURCE (Finding A fix, M028/P02/T01)
    #
    # The hook resolves the classifier from its own on-disk location, NOT from
    # $CLAUDE_PROJECT_DIR. This makes the hook portable: it fires correctly in any
    # consumer project where Claude Code launches with the project as
    # $CLAUDE_PROJECT_DIR, because the hook lives at the runtime-stable
    # ~/.claude/orchestrator-hooks/ dir (M028/P02 installer) and resolves its
    # sibling classifier from there. The in-tree development location (hook at
    # scripts/hooks/, classifier at scripts/verify/lib/) is supported via a
    # one-step parent-fallback. On both miss, fail open (exit 0) — never hard-fail
    # the hook on a missing classifier; that is the install-roundtrip gate's job.
    # -----------------------------------------------------------------------------

    HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    CLASSIFIER=""

    if [ -f "${HOOK_DIR}/shape-classifier.sh" ]; then
      CLASSIFIER="${HOOK_DIR}/shape-classifier.sh"
    elif [ -f "${HOOK_DIR}/../verify/lib/shape-classifier.sh" ]; then
      CLASSIFIER="${HOOK_DIR}/../verify/lib/shape-classifier.sh"
    fi

    if [ -z "$CLASSIFIER" ] || [ ! -f "$CLASSIFIER" ]; then
      exit 0
    fi
    ```

    Notes for the implementer:
    - `pwd -P` resolves symlinks (Edge-Cases item: hook self-location through symlinks).
    - The `HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"` line contains one `&&` connector — within the AP-009 ≤ 2 budget.
    - `[ -z "$CLASSIFIER" ] || [ ! -f "$CLASSIFIER" ]` contains one `||` connector — within budget.
    - Every other line uses single-statement `if`/`elif`/`fi` blocks; no inline-`if`-then-fi-on-one-line.
    - DO NOT use `$(...)` containing a pipe anywhere in this block.
    - DO NOT use a plain `( ... )` subshell.
    - The block introduces no `bash -c '...'` invocations.

3. Verify by reading the modified file that NO line in the resolution block (or anywhere else in the file) references `CLAUDE_PROJECT_DIR`. The variable is being intentionally retired from the hook's logic. (It may still be set by Claude Code in the runtime environment; the hook simply does not consult it.)

4. Author `scripts/verify/m028/p02-hook-self-locate.sh`. Single-file flat shape, bash 3.2 safe, ≥ 10 lines. The script:
    - `set -u`, no `set -e` (we want to read every check independently).
    - Locates the hook at `scripts/hooks/pre-bash-shape-guard.sh` relative to the script's `cd $(dirname $0)/../../..` parent.
    - Asserts the file contains the literal substring `BASH_SOURCE` (via `grep -q "BASH_SOURCE" "$hook"`).
    - Asserts the file does NOT contain the literal substring `CLAUDE_PROJECT_DIR` (via `grep -q "CLAUDE_PROJECT_DIR" "$hook"` returning non-zero — invert with `if grep ... ; then echo FAIL; exit 1; fi`).
    - Asserts the file contains the literal substring `pwd -P` (symlink resolution proof).
    - On all-pass, emits `PASS: hook self-location via BASH_SOURCE confirmed; CLAUDE_PROJECT_DIR retired; pwd -P symlink resolution present` to stdout and exits 0.
    - On any FAIL, emits a `FAIL:` diagnostic to stderr naming the missing/extra substring and exits 1.

5. Author `scripts/verify/m028/p02-hook-self-conformance.sh`. Single-file flat shape, bash 3.2 safe, ≥ 10 lines. The script:
    - `set -u`, no `set -e`.
    - Resolves repo root via `cd $(dirname $0)/../../..` and `pwd -P`.
    - Sources the M021 classifier: `. "${REPO_ROOT}/scripts/verify/lib/shape-classifier.sh"`. The classifier exposes `classify_command "<cmd>"` (M021/P03 API).
    - Reads `scripts/hooks/pre-bash-shape-guard.sh` line-by-line via a plain `while IFS= read -r line; do ... done < "$hook"` loop. **Note**: this is a top-level `while` loop in script body — that is allowed; the AD-19 shape rule prohibits inline `while` blocks embedded inside a single command, not script-level loop bodies. The loop is the script's primary control flow and does not violate AD-19.
    - For each line, skip if blank or starts with `#` (comment). Otherwise call `classify_command "$line"` and capture the verdict via plain command-substitution (no pipe inside the substitution): `verdict=$(classify_command "$line")`.
    - If the verdict starts with `REJECT`, emit `FAIL: line $LINENO classified $verdict` to stderr and exit 1.
    - On clean pass through the file, emit `PASS: pre-bash-shape-guard.sh self-conforms to AP-009 (no compound chain > 2)` to stdout and exit 0.
    - The verifier is the P02 day-one floor for CON-3; FR-21's `finding-G-self-conformance.sh` (P03 deliverable) is the M028-classifier-aware companion that lints the same file against the AP-009 rule under the extended classifier.

6. Run both verifiers via `bash scripts/util/run-probe.sh scripts/verify/m028/p02-hook-self-locate.sh` and `bash scripts/util/run-probe.sh scripts/verify/m028/p02-hook-self-conformance.sh`. Confirm both exit 0 with `PASS:` lines. If either fails, iterate on the hook body — do not weaken the verifier to make it pass.

7. Confirm the hook still passes the existing M021 `tests/run-prompt-corpus-replay.sh` if that harness is invocable in the working tree (no regression — the change is only to path resolution). If the M021 harness is not invocable here for procedural reasons, document the deferral in the task summary; FR-22's strict-superset gate (P03 deliverable) is the binding regression check.

## Must-Haves

This task addresses the phase Truths:
- "The PreToolUse shape-guard hook resolves its classifier and reject_lookup paths via `$(dirname "${BASH_SOURCE[0]}")` (with symlink resolution) and never references `$CLAUDE_PROJECT_DIR`."
- "The shape-guard hook self-conforms to its own classifier output under AP-009."

It produces the verifiers `scripts/verify/m028/p02-hook-self-locate.sh` and `scripts/verify/m028/p02-hook-self-conformance.sh` that gate those Truths.

## Verification

```bash
bash scripts/util/run-probe.sh scripts/verify/m028/p02-hook-self-locate.sh
```

```bash
bash scripts/util/run-probe.sh scripts/verify/m028/p02-hook-self-conformance.sh
```

## Notes

Expected output for the self-locate verifier is a single line `PASS: hook self-location via BASH_SOURCE confirmed; CLAUDE_PROJECT_DIR retired; pwd -P symlink resolution present`.

Expected output for the self-conformance verifier is a single line `PASS: pre-bash-shape-guard.sh self-conforms to AP-009 (no compound chain > 2)`.

If the self-conformance verifier reports `FAIL: line $LINENO classified REJECT: <ap-id> — <reason>`, the offending line in the hook body has too many connectors — split it into two statements. The classifier's verdict is authoritative; the hook author conforms.

The retirement of `CLAUDE_PROJECT_DIR` from the hook's logic is intentional per Finding A's root-cause analysis: the variable was the project-relative path that didn't exist in consumer projects, causing the hook to fall through to passthrough silently.

## Inputs

### From Previous Tasks

None within P02. Reads P01's deliverables only as background context.

### From Disk (Pre-existing)

- `scripts/hooks/pre-bash-shape-guard.sh` — M021/P05 hook. T01 modifies the classifier-resolution block; preserves all other logic (`reject_lookup`, stdin-read, `tool_name` extraction, classify+rewrite+reject decision tree, exit-code protocol).
- `scripts/verify/lib/shape-classifier.sh` — M021/P03 classifier library. T01 sources it from the new self-conformance verifier. Key API: `classify_command "<cmd>"` writes verdict to stdout (`ALLOW` on pass; `REJECT: <ap-id> — <reason>` on reject); returns 0 on ALLOW, non-zero on REJECT.
- `scripts/util/run-probe.sh` — shape-safe wrapper for invoking scripts under the harness shape-guard. T01's verification step uses it.

## Constraints

- **AD-19 single-script-file shape (CON-1)**: both new verifiers are flat single-file scripts under `scripts/verify/m028/`. No nested helper dirs. No inline compound bash, no plain `( ... )` subshells, no `$(...)` containing a pipe, no process substitution.
- **bash 3.2 + POSIX sh (CON-2)**: every line of the modified hook block AND the new verifiers runs on bash 3.2. No associative arrays. No `mapfile` / `readarray`. No unguarded `<<<` here-strings.
- **Shape-guard self-conformance (CON-3 + FR-21)**: every line T01 introduces into the hook body lints clean under the M021 classifier. The `p02-hook-self-conformance.sh` verifier gates this at the P02 day-one floor. Hard gate, no soft-warning grace.
- **No new runtime deps (CON-6)**: the resolution block uses only `cd`, `dirname`, `pwd -P`, `[ -f ... ]`, `[ -z ... ]`, plain string assignment. No `jq`, `node`, `python3`.
- **Non-Goal: no M021 surface revision**: T01 modifies only the classifier-resolution block of `pre-bash-shape-guard.sh`. It does NOT touch `scripts/verify/lib/shape-classifier.sh`, the existing `reject_lookup` function inside the hook, or `tests/fixtures/m021-prompt-corpus.txt`. M021's verification artifacts stay immutable.
- **Symlink resolution**: `pwd -P` resolves symlinks; do not use `pwd` alone or `realpath` (the latter is non-POSIX on some macOS variants without the GNU coreutils install).

## State Context

- **Current State**: executing
- **Milestone**: M028
- **Phase**: P02
- **Task**: T01-hook-self-locate
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **AD-19 single-script-file shape (CON-1)**: both new verifiers are flat single-file scripts under `scripts/verify/m028/`. No nested helper dirs. No inline compound bash, no plain `( ... )` subshells, no `$(...)` containing a pipe, no process substitution.
- **bash 3.2 + POSIX sh (CON-2)**: every line of the modified hook block AND the new verifiers runs on bash 3.2. No associative arrays. No `mapfile` / `readarray`. No unguarded `<<<` here-strings.
- **Shape-guard self-conformance (CON-3 + FR-21)**: every line T01 introduces into the hook body lints clean under the M021 classifier. The `p02-hook-self-conformance.sh` verifier gates this at the P02 day-one floor. Hard gate, no soft-warning grace.
- **No new runtime deps (CON-6)**: the resolution block uses only `cd`, `dirname`, `pwd -P`, `[ -f ... ]`, `[ -z ... ]`, plain string assignment. No `jq`, `node`, `python3`.
- **Non-Goal: no M021 surface revision**: T01 modifies only the classifier-resolution block of `pre-bash-shape-guard.sh`. It does NOT touch `scripts/verify/lib/shape-classifier.sh`, the existing `reject_lookup` function inside the hook, or `tests/fixtures/m021-prompt-corpus.txt`. M021's verification artifacts stay immutable.
- **Symlink resolution**: `pwd -P` resolves symlinks; do not use `pwd` alone or `realpath` (the latter is non-POSIX on some macOS variants without the GNU coreutils install).

### Acceptance Criteria

This task addresses the phase Truths:
- "The PreToolUse shape-guard hook resolves its classifier and reject_lookup paths via `$(dirname "${BASH_SOURCE[0]}")` (with symlink resolution) and never references `$CLAUDE_PROJECT_DIR`."
- "The shape-guard hook self-conforms to its own classifier output under AP-009."

It produces the verifiers `scripts/verify/m028/p02-hook-self-locate.sh` and `scripts/verify/m028/p02-hook-self-conformance.sh` that gate those Truths.

### Files To Touch

- `scripts/hooks/pre-bash-shape-guard.sh` (modify)
- `scripts/dispatch/adapters/runtime/claude-code.sh` (modify)
- `scripts/util/settings-merge.sh` (modify)
- `packaging/install/install-claude-code.sh` (modify)
- `scripts/verify/m028/install-roundtrip.sh` (create)
- `scripts/verify/m028/finding-A-verifier.sh` (create)
- `scripts/verify/m028/finding-F-verifier.sh` (create)
- `scripts/verify/m028/p02-hook-self-locate.sh` (create)
- `scripts/verify/m028/p02-hook-self-conformance.sh` (create)
- `scripts/verify/m028/p02-adapter-absolute-paths.sh` (create)
- `scripts/verify/m028/p02-hooks-payload-staged.sh` (create)
- `scripts/verify/m028/p02-repair-fixture.sh` (create)
- `tests/fixtures/m028-post-repair-canonical.json` (create)

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