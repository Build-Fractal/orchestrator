---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T01-materials-intake (Phase P04, Milestone M033)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~1200 | required |
| Upstream Context | 981-1181 | ~9700 | required |
| Task Plan | 1183-1344 | ~4600 | required |
| State Context | 1346-1352 | ~100 | required |
| First-Turn Completeness | 1354-1398 | ~1000 | required |
| **Total** | | **~27400** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 797
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
hit_count: 797
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
hit_count: 797
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
hit_count: 797
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
hit_count: 694
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
hit_count: 694
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
hit_count: 694
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
hit_count: 797
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
hit_count: 694
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
hit_count: 694
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
hit_count: 694
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
hit_count: 797
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
hit_count: 797
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
hit_count: 797
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
hit_count: 694
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
hit_count: 694
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
hit_count: 694
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
hit_count: 797
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
hit_count: 694
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
hit_count: 694
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
hit_count: 797
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
hit_count: 797
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
hit_count: 694
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
hit_count: 694
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
hit_count: 694
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
hit_count: 349
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
hit_count: 349
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
hit_count: 349
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
hit_count: 373
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
hit_count: 373
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
hit_count: 363
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
     Project-owned slug-bearing verifiers live under tools/verify/.
     Per the P01 plan-shape finding, artifact-list bullets in
     `## Must-Haves` MUST NOT use the bare-backtick shape — the
     auto-loop --step=V parser eval's bare-backtick bullets as commands.
     Each Truths bullet is a sentence with backticks embedded; each
     Artifacts bullet uses the `Label: path (constraints) — create`
     shape.
     Namespacing: `m033-p04-*` prefix avoids collision with M030/M031/[M032](../../../../../milestones/M032/index.md)
     and with M033/P01..P03 namespaces. -->

### Truths

- `commands/materials-intake.md` exists as a canonical command-doc per MEM012 (YAML frontmatter `description:` field; `# orchestrator:materials-intake` title; Prerequisites / State Check section; Core Workflow numbered sections; Output / Idempotency / Error Handling / Referenced Scripts sections). The body documents the FR-9 contract: invokes `bash scripts/lifecycle/materials-intake.sh --project-dir <path> [--yes] [--resolve <conflicts.md>]`. The doc names the load-bearing tokens `primary`, `supplementary`, `decision-history`, `out-of-scope` (the closed labeling-loop enum), `id-misalignment`, `scheme-contradiction`, `orphan-reference` (the closed CON-4 detection-category enum), `M033_CONFLICT_FILE_THRESHOLD` (default 5 per #Q-6), `reconciled-pre-spec.md`, and `materials_intake_completed`. The doc explicitly states the deterministic-not-LLM invariant per CON-4 and links to `tests/fixtures/m033-pbj-materials-fixture/` (the SC-4 oracle from P01).
  - Check: `bash tools/verify/m033-p04-materials-intake-md-shape.sh`

- `scripts/lifecycle/materials-intake.sh` exists, is executable, and implements the FR-9 contract per the spec. The driver: (a) accepts `--project-dir <path>` (defaults to `pwd`), `--yes` (auto-accepts labeling defaults), `--resolve <conflicts.md>` (re-invocation path for the >5-conflict file-based UX); (b) enumerates detected materials in the project root by extension (`.md`, `.pdf` via `textutil` on darwin / `pdftotext` on linux per Assumption A-3 — missing converter binary surfaced as a diagnostic, not silent skip; `.json`, `.txt`); (c) runs the labeling loop using P02's `ask_one` (one question per material with the recommendation derived from filename heuristics — `*BRIEF*` → `primary`, `*PLAN*` → `primary`, `*DECISIONS*` → `decision-history`, `*AUDIT*` → `decision-history`, `*HANDOFF*` → `supplementary`, otherwise `supplementary`; under `--yes` recommendations auto-accept); (d) runs **deterministic** CON-4 drift detection — three closed detection categories (`id-misalignment` matching `<TOKEN>-<NUMBER>` references that diverge across docs; `scheme-contradiction` matching same-key contradictory values; `orphan-reference` matching `<TOKEN>-<NUMBER>` references with no defining occurrence) — explicitly NO LLM-magic merge; (e) reconciles via terminal-interactive UX for ≤`M033_CONFLICT_FILE_THRESHOLD` (default 5 per #Q-6) conflicts using `ask_one`, accepts `accept-primary | accept-supplementary | manual-edit | defer` per conflict; for >threshold conflicts writes a markdown checklist to `<project-dir>/.orchestrator/intake/<timestamp>/conflicts.md` and exits 0 with `edit then re-invoke with --resolve <conflicts.md>` diagnostic; (f) emits the reconciled pre-spec to `<project-dir>/.orchestrator/intake/<timestamp>/reconciled-pre-spec.md` byte-deterministically — same fixture + same answers → byte-identical output across platforms (no timestamps, no random tokens in body; the timestamp lives in the directory name only, and the directory-name timestamp is not embedded in the body); each conflict resolution is recorded in the body as a `<!-- Reconciled: conflict-N → accept-primary -->` provenance comment per US-4 AS-2; (g) writes `<project-dir>/.orchestrator/start-state/materials-intake.complete` marker per FR-20 (using P02's `start-state-markers.sh write materials-intake <project-dir>`); (h) emits `materials_intake_completed` JSONL event per FR-22 (using P02's `jsonl-event-emitter.sh emit materials_intake_completed <payload>`); (i) appends a one-line FR-21 dual-write Recent Changes fragment via `bash scripts/util/dual-write-runtime-md.sh --root <project-dir> --marker recent-changes --append-entry '<fragment>'` per the P03/T05 SSOT-harmonized API. When ALL detected materials are labeled `out-of-scope`, the driver exits 0 with `no primary spec materials labeled — skipping reconciliation, falling back to greenfield-empty ideation flow` diagnostic per US-4 AS-5. Bash 3.2 compatible per MEM001.
  - Check: `bash tools/verify/m033-p04-materials-intake-sh-shape.sh`

<dispatch-volatile>

## Upstream Context


### P01 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M033"
milestone: "M033"
provides:
  - "PBJ acceptance fixture; SC-4 ground-truth README oracle; two T01 verifiers (shape + oracle),references/branch-detection.md SSOT for FR-2 branch-detection rules; tools/verify/m033-p01-branch-detection-ssot-parity.sh cross-parity verifier,commands/start.md (orchestrator:start command doc) + scripts/lifecycle/start.sh (FR-1 flag set + FR-2 ordered branch detection + idempotent init invocation + four sub-flow stubs + US-1 AS-5 + MIT-006/RISK-006 disambiguation question) + 5 T03 verifiers,friendly-tester pass protocol + report template + validate-report.sh SC-15 mechanical gate + pass/fail report fixtures + 4 shape verifiers under tools/verify/m033-p01-*,SC-1 + SC-8 acceptance scripts; m033-p01-phase-suite aggregator (14 verifiers); m033-p01-scope-guard (P02-P05 boundary invariant)"
requires:
  - "none"
affects:
  - "P02,P03,P04"
key_files:
  - "tests/fixtures/m033-pbj-materials-fixture/PRODUCT-BRIEF.md;tests/fixtures/m033-pbj-materials-fixture/MVP-PLAN.md;tests/fixtures/m033-pbj-materials-fixture/DECISIONS.md;tests/fixtures/m033-pbj-materials-fixture/MILESTONE-AUDIT.md;tests/fixtures/m033-pbj-materials-fixture/README.md;tools/verify/m033-p01-pbj-fixture-shape.sh;tools/verify/m033-p01-pbj-fixture-readme-oracle.sh,references/branch-detection.md;tools/verify/m033-p01-branch-detection-ssot-parity.sh,commands/start.md,scripts/lifecycle/start.sh,tools/verify/m033-p01-start-md-shape.sh,tools/verify/m033-p01-start-sh-flags-and-init-invocation.sh,tools/verify/m033-p01-branch-detection-rules.sh,tools/verify/m033-p01-subflow-stubs-shape.sh,tools/verify/m033-p01-disambiguation-question-shape.sh,tests/m033-acceptance/friendly-tester-pass/protocol.md,tests/m033-acceptance/friendly-tester-pass/report-template.md,tests/m033-acceptance/friendly-tester-pass/validate-report.sh,tests/m033-acceptance/friendly-tester-pass/fixtures/report-pass.md,tests/m033-acceptance/friendly-tester-pass/fixtures/report-fail.md,tools/verify/m033-p01-friendly-tester-protocol-shape.sh,tools/verify/m033-p01-report-template-shape.sh,tools/verify/m033-p01-validate-report-sh-contract.sh,tools/verify/m033-p01-validate-report-fixtures-shape.sh,tests/m033-acceptance/p01-start-branch-routing.sh;tests/m033-acceptance/p07-friendly-tester-protocol.sh;tools/verify/m033-p01-acceptance-shape-sc1.sh;tools/verify/m033-p01-acceptance-shape-sc8.sh;tools/verify/m033-p01-phase-suite.sh;tools/verify/m033-p01-scope-guard.sh;scripts/lifecycle/start.sh"
key_decisions:
  - "branch-detection patterns byte-match SSOT via grep -F parity; sub-flow stubs deliberately vacuous (printf would-execute only); disambiguation prompt inline via read -r (grilling-shell.sh is P02); --branch override is silent unless detection differs (then branch-override: stderr diagnostic),D-T05-01:fix-start.sh-subshell-state-leak-via-tempfile;D-T05-02:scope-guard-wiki-rule-narrowed-to-M033-tagged-paths"
patterns_established:
  - "deterministic curatorial fixture with README oracle; oracle parser uses markdown numbered-list shape (lines 1.-5.) + closed CON-4 enum tokens,SSOT-with-byte-matched-implementation parity pattern (grep -F fixed-string cross-check between reference doc and implementing script); fenced-rule-block convention (branch-detection-rule-N markers); SKIP-gate pattern for verifiers co-authored before their implementation lands,SSOT-and-impl byte-match via grep -F parity verifier (T02 ssot-parity verifier transitions skip=1 to skip=0 on T03 land); vacuous-stub pattern for cross-phase scope-guarding (P01 stubs print would-execute: only,P02-P05 replace with real logic); load-bearing token tripwire convention (init already complete,branch:,would-execute:,disambiguation:,recommended:,MIT-006,branch-override: are all literal-grep tokens for downstream SC verification),frontmatter-only attestation counting (awk in_fm guard); per-report shape verifier separate from milestone-close escalation gate; em-dash literal in US-8 AS-5 diagnostic,phase-suite-aggregator-emits-canonical-SUMMARY-line;side-channel-tempfile-for-subshell-globals;wrapper-verifier-executes-target-and-propagates-exit-code"
drill_down_paths:
  - "[.orchestrator/milestones/M033/phases/P01/tasks/T01-pbj-fixture-and-oracle-SUMMARY.md](../../../../../milestones/M033/phases/P01/tasks/T01-pbj-fixture-and-oracle-SUMMARY.md), [.orchestrator/milestones/M033/phases/P01/tasks/T02-branch-detection-ssot-SUMMARY.md](../../../../../milestones/M033/phases/P01/tasks/T02-branch-detection-ssot-SUMMARY.md), [.orchestrator/milestones/M033/phases/P01/tasks/T03-start-command-and-driver-SUMMARY.md](../../../../../milestones/M033/phases/P01/tasks/T03-start-command-and-driver-SUMMARY.md), [.orchestrator/milestones/M033/phases/P01/tasks/T04-friendly-tester-pass-artifacts-SUMMARY.md](../../../../../milestones/M033/phases/P01/tasks/T04-friendly-tester-pass-artifacts-SUMMARY.md), [.orchestrator/milestones/M033/phases/P01/tasks/T05-acceptance-suite-and-phase-suite-SUMMARY.md](../../../../../milestones/M033/phases/P01/tasks/T05-acceptance-suite-and-phase-suite-SUMMARY.md)"
duration: "173m"
verification_result: "pass"
completed_at: "2026-05-04T03:16:34Z"
observability_surfaces:
  - "none"
---

P01 ships the foundational scaffolding for M033 (Project Onboarding Experience): the `orchestrator:start` command and driver, the four sub-flow stubs that P02–P05 will replace, the SSOT for branch detection, the friendly-tester pass artifact set, and the acceptance + verification scaffolding that future phases depend on.

## What was built

- **PBJ acceptance fixture + SC-4 ground-truth oracle** (T01): `tests/fixtures/m033-pbj-materials-fixture/` with four PBJ-shape documents (`PRODUCT-BRIEF.md`, `MVP-PLAN.md`, `DECISIONS.md`, `MILESTONE-AUDIT.md`) carrying exactly 5 inconsistencies covering all three CON-4 categories (`id-misalignment`, `scheme-contradiction`, `orphan-reference`), plus a `README.md` oracle that enumerates the 5 expected detections in the parser-load-bearing markdown numbered-list shape. Two verifiers under `tools/verify/m033-p01-*` lock the fixture shape and the oracle entry layout.
- **Branch-detection SSOT** (T02): `references/branch-detection.md` documents the four FR-2 rules (greenfield-empty / greenfield-with-materials / existing-codebase / migrating) with literal pattern strings in fenced `branch-detection-rule-N` blocks. `tools/verify/m033-p01-branch-detection-ssot-parity.sh` byte-cross-checks the SSOT against `scripts/lifecycle/start.sh` via `grep -F`; the verifier emits `SKIP:` for the impl-side assertions until T03 lands and transitions to `pass=28 skip=0` once start.sh is in place.
- **`orchestrator:start` command + driver** (T03): `commands/start.md` (canonical command-doc shape per MEM012) plus `scripts/lifecycle/start.sh` implementing FR-1 flag set (`--project-dir`, `--branch`, `--init-only`, `--with-wiki`, `--with-giscus`, `--deploy`, `--debug`), FR-2 ordered branch detection, idempotent `init-project.sh` invocation, four vacuous sub-flow stubs (each printing only `would-execute: <stub-name> --project-dir <path>`), and the inline `read -r` US-1 AS-5 + MIT-006/RISK-006 disambiguation question. Five shape verifiers cover command-doc shape, flag set, branch-detection rule presence, sub-flow stub vacuity, and disambiguation token shape.
- **Friendly-tester pass artifacts** (T04): `tests/m033-acceptance/friendly-tester-pass/` carries the FR-19 protocol, report template, fixtures (`report-pass.md`, `report-fail.md`), and `validate-report.sh` (the SC-15 mechanical gate, bash 3.2 + awk only, frontmatter-scoped attestation count, `friction_blockers=N` stderr emission, and the literal `friendly-tester pass not run — milestone close blocked` em-dash diagnostic for the missing-file path). Four shape verifiers lock the protocol, template, validator contract, and fixtures.
- **Acceptance suite + phase-suite + scope-guard** (T05): `tests/m033-acceptance/p01-start-branch-routing.sh` (SC-1) and `tests/m033-acceptance/p07-friendly-tester-protocol.sh` (SC-8) run the end-to-end branch-routing and friendly-tester paths against synthetic fixtures. `tools/verify/m033-p01-phase-suite.sh` aggregates 14 P01 verifiers; `tools/verify/m033-p01-scope-guard.sh` asserts no P02–P05 file leakage.

## Patterns established

- **SSOT-with-byte-matched-impl parity**: `grep -F` cross-check between a reference doc and its implementing script, with a SKIP-gate convention so the verifier ships before the impl and surfaces SKIP until impl lands.
- **Vacuous sub-flow stubs**: P01 ships stubs that print only `would-execute: <stub> --project-dir <path>`; later phases replace with real logic. Combined with the scope-guard, this prevents accidental P02–P05 scope leakage during P01.
- **Load-bearing-token tripwires**: Every cross-phase boundary is enforced via literal token grep (`init already complete`, `branch:`, `would-execute:`, `disambiguation:`, `recommended:`, `MIT-006`, `branch-override:`). Downstream SC verification consumes these as fixed strings.
- **Deterministic curatorial fixture + README oracle**: The PBJ fixture ships with no timestamps, no random tokens — byte-identical across machines. The README is the parser-load-bearing oracle (markdown numbered-list shape).
- **Frontmatter-scoped attestation counting** (validate-report.sh): awk `in_fm` guard counts `not_familiar_with_orchestrator: yes` only inside the YAML frontmatter, immune to comment/prose noise in real-world reports.

## Decisions captured during execution

- **D-T05-01**: Fixed a subshell state leak in `scripts/lifecycle/start.sh` surfaced by the SC-1 acceptance test. `detect_branch` ran in a `$(...)` subshell so its mutations to `DETECTED_FROM`/`MIT006_ELIGIBLE` never propagated. Fix: side-channel tempfile populated by `write_detect_state` inside `detect_branch`, reloaded by `load_detect_state` in parent after each invocation; cleanup via `trap ... EXIT`. Strictly T03 territory but blocked P01 close — surgical fix.
- **D-T05-02**: Narrowed the scope-guard's `wiki/` rule to M033-tagged paths. The literal "wiki/ exists → fail" form would unconditionally fail because `wiki/` is a pre-existing [M012](../../../../../milestones/M012/index.md) artifact. Narrowed to: scan `wiki/` for basenames matching `M033*`/`m033*`. Preserves SC-13 intent without flagging unrelated history.

## Plan-shape finding (orchestrator-internal)

The five P01 task plans initially carried bare-backtick artifact bullets in `## Must-Haves` (e.g. `- \`tests/fixtures/.../README.md\``). The auto-loop `--step=V` parser eval's every bare-backtick bullet in Must-Haves as a command, which fails for non-executable artifact paths (especially brace-expansion forms like `{a,b,c}.md`). All five plans were edited mid-phase to label artifact bullets with prefixes (e.g. `- Fixture documents: \`...\`, \`...\``), breaking the strict `^- \`...\`$` regex match. Future planner agents should follow this convention by default — candidate for a `templates/task-plan.md` Must-Haves shape clarification.

## Verification result

- `tools/verify/m033-p01-phase-suite.sh`: `pass=14 fail=0`
- `tools/verify/m033-p01-scope-guard.sh`: `pass=14 fail=0`
- All 5 task-level verify cycles: `AUTO:VERIFY_PASS`
- Acceptance scripts: `p01-start-branch-routing.sh` `pass=14 fail=0`; `p07-friendly-tester-protocol.sh` `pass=10 fail=0`
- External-modification check: `PASS: no external modifications`
- Roadmap sync: `SYNC:OK`

## What downstream phases consume

- P02 (existing-codebase deep-discovery sub-flow): consumes `commands/start.md`, `scripts/lifecycle/start.sh`, the `existing-codebase` sub-flow stub slot, the disambiguation question contract, the SSOT branch-detection rules, and the SC-1 acceptance script as its regression boundary.
- P03 (greenfield-empty + greenfield-with-materials sub-flows): consumes the same start.sh + sub-flow stub slots, plus the PBJ fixture (T01) for the materials-detection branch.
- P04 (PBJ inconsistency detector): consumes the PBJ fixture + README oracle (T01) as its development target and SC-4 ground truth.
- P05 (M032 paired-launch integration): consumes the `--with-wiki`/`--with-giscus`/`--deploy` flag set already wired through start.sh, plus the friendly-tester pass artifacts (T04) as the gate before milestone close.

The friendly-tester pass artifacts (T04) ship in P01 deliberately — the spec's SC-14 amendment treats `p07-` as a concern-tag, not a phase-tag, so FR-19 protocol + report template + validator must exist in P01 to unblock recruiting in parallel with P02–P05 execution.


### P02 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P02"
parent: "M033"
milestone: "M033"
provides:
  - "scripts/util/jsonl-event-emitter.sh (FR-22 emitter library,11 closed-enum event types,schema 1.0,480-byte atomic-append size guard); tools/verify/m033-p02-jsonl-event-schema.sh (25-check shape + functional + negative-path verifier),scripts/util/start-state-markers.sh marker primitives library; scripts/lifecycle/start.sh additive resume-on-partial-state extension; tests/m033-acceptance/p07-resume-on-partial-state.sh SC-12 acceptance script; three T02 verifiers under tools/verify/m033-p02-*,scripts/lifecycle/grilling-shell.sh-FR-17-core-API,tools/verify/m033-p02-grilling-shell-shape.sh,scripts/lifecycle/grilling-shell.sh-MIT-007-contradiction-and-FR-18-glossary,tests/m033-acceptance/p07-grilling-shell.sh,tools/verify/m033-p02-grilling-shell-contradiction-detection.sh,tools/verify/m033-p02-glossary-writer-shape.sh,tools/verify/m033-p02-acceptance-shape-sc11.sh,references/m033-fr21-dual-write-convention.md FR-21 SSOT for P03/P04/P05; tests/m033-acceptance/p07-observability-records.sh SC-13 acceptance covering all 11 event types; tools/verify/m033-p02-fr21-convention-shape.sh; tools/verify/m033-p02-acceptance-shape-sc13.sh; tools/verify/m033-p02-phase-suite.sh aggregating 10 P02 verifiers; tools/verify/m033-p02-scope-guard.sh bidirectional forbidden+allowed scope-guard"
requires:
  - "P01"
affects:
  - "P03,P04,P05"
key_files:
  - "scripts/util/jsonl-event-emitter.sh,tools/verify/m033-p02-jsonl-event-schema.sh,scripts/util/start-state-markers.sh,scripts/lifecycle/start.sh,tests/m033-acceptance/p07-resume-on-partial-state.sh,tools/verify/m033-p02-start-state-markers-shape.sh,tools/verify/m033-p02-start-sh-resume-extension.sh,tools/verify/m033-p02-acceptance-shape-sc12.sh,scripts/lifecycle/grilling-shell.sh,tools/verify/m033-p02-grilling-shell-shape.sh,tests/m033-acceptance/p07-grilling-shell.sh,tools/verify/m033-p02-grilling-shell-contradiction-detection.sh,tools/verify/m033-p02-glossary-writer-shape.sh,tools/verify/m033-p02-acceptance-shape-sc11.sh,references/m033-fr21-dual-write-convention.md,tests/m033-acceptance/p07-observability-records.sh,tools/verify/m033-p02-fr21-convention-shape.sh,tools/verify/m033-p02-acceptance-shape-sc13.sh,tools/verify/m033-p02-phase-suite.sh,tools/verify/m033-p02-scope-guard.sh"
key_decisions:
  - "closed-7-name-subflow-enum-as-fenced-SSOT;idempotent-marker-write-preserves-first-completion-timestamp;init-invoked-marker-write-post-init-for-symmetry;resume-detection-block-exits-0-after-diagnostic-pending-P03-P04-P05-real-dispatch"
patterns_established:
  - "fenced SSOT closed-enum block for grep-friendly event-type cross-checking; printf-into-local + linelen size-guard for POSIX atomic-append discipline (480 bytes under macOS PIPE_BUF 512); JSON-object payload validation via case-glob shape check (no jq dependency at emit path),closed-enum-as-fenced-SSOT-grep-token-tripwire;idempotent-marker-with-first-write-timestamp-preservation;P01-preservation-gate-via-AD-15-cross-phase-regression-precedent-sub-step;additive-extension-discipline-no-touch-of-P01-behavior-paths,stub-helper-with-stable-name-for-T04-replacement,reserved-fenced-SSOT-block-markers,sourceability-guard-via-BASH_SOURCE-vs-dollar-zero,recommendation-not-interrogation-prefix-ordering,caller-set-bash-vars-for-ask_one-cross-cutting-context,accumulator-append-only-after-contradiction-clean,awk-single-pass-alphabetized-insert,closed-vocabulary-SSOT-block-via-IFS-newline-for-loop,bidirectional-scope-guard pattern reused from m033-p01-scope-guard.sh: forbidden-presence + allowed-presence whitelist catches both overflow and underflow; phase-suite-aggregator pattern with newline-delimited verifier list iterated under IFS swap; hard-coded event-type emission in acceptance scripts so per-event-type regressions name themselves in failure output"
drill_down_paths:
  - "[.orchestrator/milestones/M033/phases/P02/tasks/T01-jsonl-event-emitter-SUMMARY.md](../../../../../milestones/M033/phases/P02/tasks/T01-jsonl-event-emitter-SUMMARY.md), [.orchestrator/milestones/M033/phases/P02/tasks/T02-start-state-markers-and-resume-SUMMARY.md](../../../../../milestones/M033/phases/P02/tasks/T02-start-state-markers-and-resume-SUMMARY.md), [.orchestrator/milestones/M033/phases/P02/tasks/T03-grilling-shell-core-SUMMARY.md](../../../../../milestones/M033/phases/P02/tasks/T03-grilling-shell-core-SUMMARY.md), [.orchestrator/milestones/M033/phases/P02/tasks/T04-grilling-shell-glossary-and-contradiction-SUMMARY.md](../../../../../milestones/M033/phases/P02/tasks/T04-grilling-shell-glossary-and-contradiction-SUMMARY.md), [.orchestrator/milestones/M033/phases/P02/tasks/T05-fr21-convention-and-phase-suite-SUMMARY.md](../../../../../milestones/M033/phases/P02/tasks/T05-fr21-convention-and-phase-suite-SUMMARY.md)"
duration: "201m"
verification_result: "pass"
completed_at: "2026-05-04T03:58:32Z"
observability_surfaces:
  - "jsonl-event-emitter.sh@.orchestrator/execution-log.jsonl"
---

P02 ships the cross-cutting infrastructure that all of M033's downstream phases (P03 greenfield, P04 PBJ detection, P05 M032-paired-launch) consume: the FR-22 JSONL event-emitter and 11-event closed enum, the FR-20 start-state markers + `start.sh` resume-on-partial-state extension, the FR-17 grilling-shell with FR-18 glossary writer and MIT-007 contradiction detection, the FR-21 dual-write convention SSOT, and the SC-13 end-to-end observability acceptance.

## What was built

- **FR-22 JSONL event-emitter** (T01): `scripts/util/jsonl-event-emitter.sh` exposes a single `emit_event` entry point. Schema 1.0, 11-event closed enum (`subflow_started`, `subflow_completed`, `flag_passed`, `disambiguation_resolved`, `contradiction_detected`, `glossary_term_added`, `materials_classified`, `pbj_inconsistency_detected`, `wiki_initialized`, `giscus_configured`, `imported_context_loaded`) declared in a fenced `# >>> event-types >>> ... # <<< event-types <<<` SSOT block. Atomic-append `>>` to `<PROJECT_DIR>/.orchestrator/execution-log.jsonl` with a 480-byte size guard (under macOS PIPE_BUF 512 — `payload too large for atomic append` diagnostic + rc=2 if exceeded). ISO 8601 UTC timestamps via `date -u`. JSON-object payload shape validated via case-glob (no jq dependency at emit path). 25-check shape verifier locks the contract.
- **FR-20 start-state markers + resume-on-partial-state** (T02): `scripts/util/start-state-markers.sh` provides write/read/next/clear primitives over a 7-name closed enum (`pre-init`, `init-invoked`, `subflow-started`, `subflow-completed`, `pbj-detection-completed`, `wiki-initialized`, `giscus-configured`). Markers are idempotent — first-completion timestamps are preserved on re-write. `scripts/lifecycle/start.sh` extended additively with a `--no-resume` flag, post-init `init-invoked` marker write, and a resume-detection block in `main()` that emits `start-state: resuming from <next>` when this branch's marker is present. P01 behavior fully preserved (re-verified: `m033-p01-phase-suite.sh` 14/14 PASS, SC-1 14/14 PASS) — AD-15 cross-phase regression precedent sub-step baked into T02's verifier.
- **FR-17 grilling-shell core + FR-18 glossary + MIT-007 contradiction** (T03 + T04): `scripts/lifecycle/grilling-shell.sh` exposes `ask_one` (3-arg public API: question key, prompt text, default), with caller-set `_GRILLING_CURRENT_QKEY` / `_GRILLING_CURRENT_DEFINITION` vars threading cross-cutting context per call. T03 shipped the sourceable core with stub bodies + reserved fenced SSOT block markers (`# >>> contradiction-pairs >>>`, `# >>> glossary-triggers >>>`); T04 replaced the stubs in-place with real implementations. Contradiction-pairs SSOT carries 9 pairs across target-user / deployment-target / auth-model. Glossary-triggers SSOT carries 4 keys (domain-term-defined, acronym-resolved, convention-named, framework-chosen). `_grilling_glossary_update` does an awk-single-pass alphabetized insert against a `wiki/glossary.md` target (fixture-local under `mktemp -d` per the P02 stub-mode escape valve — same path becomes the real M032-owned surface in M033/P05 with no code change). T03's verifier still passes after T04's edits — additive contract preserved.
- **FR-21 dual-write convention SSOT + 10-verifier phase-suite + bidirectional scope-guard + SC-13 end-to-end** (T05): `references/m033-fr21-dual-write-convention.md` documents inheritance from M014/spec 035 (`bash scripts/util/dual-write-runtime-md.sh append "<fragment>"` canonical call shape, `dual_write_agents: false` config-respect note, 5 per-command fragment templates for FR-3/FR-7/FR-9/FR-10/FR-13). The FR-21 callsite-discovery contract is the load-bearing `# >>> fr-21-dual-write-callsites >>>` fenced block. `tests/m033-acceptance/p07-observability-records.sh` is the SC-13 acceptance: hard-coded emit calls for all 11 event types + uniqueness + timestamp + payload pass-through + closed-enum negative-path + drift-catch (31 PASS / 0 FAIL). `tools/verify/m033-p02-phase-suite.sh` aggregates exactly 10 P02 sub-verifiers. `tools/verify/m033-p02-scope-guard.sh` is bidirectional: forbidden-presence (15 P03/P04/P05 surfaces absent) + wiki-boundary (clean) + allowed-presence whitelist (20 P02 deliverables present) — catches both overflow and silent-skip underflow.

## Patterns established

- **Closed-enum-as-fenced-SSOT grep token tripwire**: every cross-phase boundary (event types, marker states, contradiction pairs, glossary triggers) ships as a fenced SSOT block parseable by `IFS=$'\n'` for-loop iteration. Downstream verifiers `grep -F` against the fenced block as the source of truth.
- **Idempotent marker with first-completion-timestamp preservation**: write operations check for prior content and preserve it; only the secondary fields update.
- **Stub-helper-with-stable-name-for-T04-replacement**: T03's no-op function bodies share signatures + names with T04's real implementations, enabling surgical in-place replacement without contract drift.
- **Sourceability guard via `BASH_SOURCE` vs `$0`**: a single end-of-file gate lets scripts be both directly executable and importable; sourcing in a sandboxed subshell exits 0 with no top-level `set` directives or `exit` calls leaking.
- **Recommendation-not-interrogation prefix ordering**: grilling-shell prompt structure surfaces a default-recommendation line before the question, framing the interaction as a confirmable suggestion rather than an interrogation.
- **Awk-single-pass alphabetized insert** for glossary writes — bash 3.2 compatible, no `sort`-pipe dependency.
- **Hard-coded event-type emission** in SC-13 acceptance — per-event-type regressions name themselves in failure output rather than aggregate-counting that hides which event broke.
- **Bidirectional scope-guard** (forbidden + allowed whitelist) reused from P01's `m033-p01-scope-guard.sh` pattern.
- **Phase-suite-aggregator** pattern: newline-delimited verifier list iterated under `IFS=$'\n'` swap; canonical `SUMMARY: <verifier-name> pass=N fail=M` final-line token preserved per verifier.
- **AD-15 P01 cross-phase preservation gate**: T02 baked an explicit P01-preservation sub-step into its verifier so the additive `start.sh` extension provably did not regress P01 behavior.

## Decisions captured during execution

- T01: JSONL atomic-append size guard set at 480 bytes (under macOS PIPE_BUF 512), enforcing State On Disk Is Truth invariant.
- T02: idempotent marker design preserves first-completion timestamp on re-write; `init-invoked` marker writes post-init for symmetry with the resume-detection block; resume-detection block exits 0 after the diagnostic, deferring real dispatch to P03/P04/P05.
- T03/T04: closed contradiction-pairs and glossary-triggers vocabularies at v1; demand-driven expansion post-launch per Constitution-XIV.
- T05: P02 stub-mode escape valve — `wiki/glossary.md` writes are fixture-local under `mktemp -d`. Same path becomes the real M032-owned surface in M033/P05 with no source change.

## Verification result

- `tools/verify/m033-p02-phase-suite.sh`: `pass=10 fail=0`
- `tools/verify/m033-p02-scope-guard.sh`: `pass=36 fail=0` (forbidden-presence + wiki-boundary + allowed-presence all green)
- All 5 task-level verify cycles: `AUTO:VERIFY_PASS`
- SC-11 acceptance (`tests/m033-acceptance/p07-grilling-shell.sh`): `pass=12 fail=0`
- SC-12 acceptance (`tests/m033-acceptance/p07-resume-on-partial-state.sh`): `pass=14 fail=0`
- SC-13 acceptance (`tests/m033-acceptance/p07-observability-records.sh`): `pass=31 fail=0`
- P01 cross-phase regression (`tests/m033-acceptance/p01-start-branch-routing.sh`): `pass=14 fail=0` (T02 preservation gate)
- External-modification check: `PASS: no external modifications`
- Roadmap sync: `SYNC:OK`

## What downstream phases consume

- **P03** (greenfield + materials sub-flows): consumes `jsonl-event-emitter.sh` for `subflow_started` / `subflow_completed` / `materials_classified` / `imported_context_loaded`; consumes `start-state-markers.sh` for `subflow-started` / `subflow-completed`; consumes `grilling-shell.sh` for greenfield grilling questions; consumes `m033-fr21-dual-write-convention.md` for the dual-write callsite shape.
- **P04** (PBJ inconsistency detector): consumes `jsonl-event-emitter.sh` for `pbj_inconsistency_detected`; consumes the PBJ fixture from P01 (T01) as its development target.
- **P05** (M032 paired-launch + friendly-tester gate): consumes `jsonl-event-emitter.sh` for `wiki_initialized` / `giscus_configured`; consumes `start-state-markers.sh` for `wiki-initialized` / `giscus-configured`; replaces the P02 fixture-local `mktemp -d` glossary path with the real `--with-wiki` surface.

The dual-write convention SSOT (T05) is the single point of contact for P03/P04/P05 dual-write call shape — any drift across phases will surface as a verifier failure against the SSOT, not as silent inconsistency.


### P03 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P03"
parent: "M033"
milestone: "M033"
provides:
  - "scripts/verify/constitution-shape-lint.sh (FR-5 4-assertion lint),scripts/verify/standalone-gate.sh (FR-6 / Principle XVI dispatcher with constitution v1 subcommand and fenced SSOT surface block),templates/constitution-starters/web-saas.md+cli-tool.md+library.md (FR-4 v1 closed stack list),references/constitution-starter-format.md (US-2 AS-4 starter-format reference),4 T01 verifiers under tools/verify/m033-p03-*,commands/constitution.md (FR-3 documented surface),scripts/lifecycle/constitution-author.sh (FR-3 driver implementing 5-8-question grilling-protocol flow + lint gate + write + marker + JSONL event + dual-write fragment),tools/verify/m033-p03-constitution-md-shape.sh (T02 shape verifier 13 PASS),tools/verify/m033-p03-constitution-author-sh-shape.sh (T02 shape + standalone-gate dogfood verifier 26 PASS),commands/ingest-codebase.md (FR-7/FR-8 doc surface),scripts/lifecycle/ingest-codebase.sh (FR-7 deterministic core + reserved rich-context-branch stub for T04),3 byte-deterministic stack fixtures (ts-saas+py-cli+rust-library),3 T03 verifiers,references/imported-context-sentinel.md (#Q-11 SSOT documenting _imported-context/ sentinel + path-resolver precedence + downstream-traverser convention + frontmatter SSOT marker + MEM-DR-* cross-reference convention),scripts/lifecycle/ingest-codebase.sh in-place rich-context-branch fill (FR-8 / MIT-005 — DR/MILESTONE-AUDIT/CLAUDE-custom-block detection + thin context file emission + MEM-DR-* cross-references + .orchestrator/ prior-tooling MEM + imported_context_loaded JSONL),additive _*-prefix skip clauses at scripts/diagnostics/check-plans.sh + scripts/diagnostics/check-constitution.sh enumeration sites,inline doc-notes at scripts/state/derive-phase.sh + scripts/dispatch/build-context.sh + scripts/diagnostics/run-doctor.sh (non-enumerating callers),tools/verify/m033-p03-rich-context-import-shape.sh (20-check shape + functional + negative smoke),tools/verify/m033-p03-imported-context-sentinel-shape.sh (16-check sentinel + traverser-annotation verifier)"
requires:
  - "P01,P02"
affects:
  - "P04,P05"
key_files:
  - "scripts/verify/constitution-shape-lint.sh,scripts/verify/standalone-gate.sh,templates/constitution-starters/web-saas.md,templates/constitution-starters/cli-tool.md,templates/constitution-starters/library.md,references/constitution-starter-format.md,tools/verify/m033-p03-constitution-shape-lint-shape.sh,tools/verify/m033-p03-standalone-gate-sh-shape.sh,tools/verify/m033-p03-constitution-starter-templates-shape.sh,tools/verify/m033-p03-constitution-starter-format-ref-shape.sh,commands/constitution.md,scripts/lifecycle/constitution-author.sh,tools/verify/m033-p03-constitution-md-shape.sh,tools/verify/m033-p03-constitution-author-sh-shape.sh,commands/ingest-codebase.md,scripts/lifecycle/ingest-codebase.sh,tests/fixtures/m033-stack-fixture-ts-saas/,tests/fixtures/m033-stack-fixture-py-cli/,tests/fixtures/m033-stack-fixture-rust-library/,tools/verify/m033-p03-ingest-codebase-md-shape.sh,tools/verify/m033-p03-ingest-codebase-sh-shape.sh,tools/verify/m033-p03-stack-fixtures-shape.sh,references/imported-context-sentinel.md,scripts/util/jsonl-event-emitter.sh,scripts/diagnostics/check-plans.sh,scripts/diagnostics/check-constitution.sh,scripts/diagnostics/run-doctor.sh,scripts/state/derive-phase.sh,scripts/dispatch/build-context.sh,tools/verify/m033-p03-rich-context-import-shape.sh,tools/verify/m033-p03-imported-context-sentinel-shape.sh"
key_decisions:
  - "standalone-gate-elides-its-own-trigger-substring-in-format-reference-prose-to-prevent-self-trip;SKIP-tolerance-for-co-authored-but-not-yet-landed-surfaces-mirrors-M033-P01-skip-gate-pattern;subcommand-dispatched-gate-(constitution-v1)-keeps-future-extension-contract-stable;closed-v1-stack-list-with-#Q-2-demand-driven-expansion-criterion,capture-resolved-answers-via-accumulator-rather-than-stdout-capture-because-stdout-capture-would-hide-ask_one-prompts-from-operator;use-actual-helper-flag-API-(--marker-recent-changes-+---append-entry)-rather-than-the-shorthand-(append-fragment)-the-FR-21-SSOT-text-suggests-because-the-helper-does-not-implement-an-append-subcommand;stack-specific-questions-do-not-substitute-placeholders-(closed-vocab-stays-at-3)-but-flow-to-the-accumulator-+-glossary-writer-so-MIT-007-+-FR-18-still-fire,use-md5-q-darwin-or-md5sum-linux-detected-via-command-v-not-process-substitution-for-bash3.2-stable-id-derivation;reserved-rich-context-branch-uses-true-stub-not-empty-block-because-set-e-+-empty-block-fails-syntax;TS-saas-fixture-floor-is-5-MEMs-rust+py-fixtures-also-5-MEMs-because-no-prior-tooling-+-no-.git-pushes-them-to-the-floor-and-T04-DR-imports-raise-TS-to-8;use-real-dual-write--marker-recent-changes---append-entry-API-not-the-SSOT-shorthand-(T02-deviation-confirmed-and-carried-forward);start-state-marker-enum-uses-ingest-codebase-but-FR-7-doc-prose-uses-ingest-codebase-completed-as-a-semantic-alias-the-script-comments-name-both-tokens-so-the-load-bearing-grep-passes,extend-jsonl-emitter-enum-additively-with-imported_context_loaded-as-T04-narrowest-fix-(P02-prereq-claimed-this-event-existed-but-actual-emitter-shipped-without-it-T05-open-concern);_*-prefix-skip-applied-only-at-true-enumeration-sites-(check-plans.sh-+-check-constitution.sh)-non-enumerating-traversers-get-inline-doc-notes-only-per-plan-Notes;rich-context-branch-emits-+1-prior-tooling-.orchestrator/-convention-MEM-to-meet-TS-saas-README-oracle-count-of-8;use-grep-^##-DR-OR-^DR--in-decisions-detection-because-fixture-uses-##-DR-heading-style;awk-/BEGIN-CUSTOM/-/END-CUSTOM/-then-grep--v-blank-extracts-non-empty-CLAUDE.md-custom-block-without-process-substitution"
patterns_established:
  - "fenced-SSOT-block-for-closed-surface-file-set-with-awk-block-extraction;positive-and-negative-mktemp-d-functional-smoke-tests-for-shape-lint-shape-verifiers;self-reference-elision-pattern-for-docs-that-document-content-detection-gates,ask_one-uncaptured-stdout-+-accumulator-readback-pattern-for-resolved-answer-extraction;parallel-indexed-arrays-(placeholders+answers+u_qkeys+u_questions+u_recommendations)-for-bash-3.2-MEM001-compatibility;sed-i.bak-with-pre-escaped-value-for-POSIX-portable-placeholder-substitution-with-operator-supplied-content;rc-zero-then-cmd-or-rc-dollar-question-pattern-for-allowing-set-e-coexistence-with-explicit-rc-checks,negative-grep-determinism-invariant-(claude-code+conversus+model_routing-must-not-appear-in-extraction-path);stable-id-by-source-path-+-signal-kind-hash-removes-need-for-per-run-state-file-for-idempotency;reserved-fenced-block-with-true-no-op-stub-for-future-task-fill-in-place;byte-deterministic-stack-fixture-pattern-with-README-oracle.md-naming-expected-MEM-count-+-categories-as-SC-3-ground-truth,additive-closed-enum-extension-pattern-(append-event-type-with-keep-old-stderr-tokens-stable-so-existing-verifiers-still-pass);downstream-traverser-skip-clause-pattern-(_*)-continue-inline-bash-3.2-compatible-no-shared-helper-single-grep-token-discoverable;non-enumerator-doc-note-pattern-(M033/P03/T04-#Q-11-comment-only-no-code-change-when-traverser-resolves-single-milestone-from-arg)"
drill_down_paths:
  - "[.orchestrator/milestones/M033/phases/P03/tasks/T01-SUMMARY.md](../../../../../milestones/M033/phases/P03/tasks/T01-SUMMARY.md), [.orchestrator/milestones/M033/phases/P03/tasks/T02-SUMMARY.md](../../../../../milestones/M033/phases/P03/tasks/T02-SUMMARY.md), [.orchestrator/milestones/M033/phases/P03/tasks/T03-SUMMARY.md](../../../../../milestones/M033/phases/P03/tasks/T03-SUMMARY.md), [.orchestrator/milestones/M033/phases/P03/tasks/T04-SUMMARY.md](../../../../../milestones/M033/phases/P03/tasks/T04-SUMMARY.md), [.orchestrator/milestones/M033/phases/P03/tasks/T05-acceptance-and-phase-suite-SUMMARY.md](../../../../../milestones/M033/phases/P03/tasks/T05-acceptance-and-phase-suite-SUMMARY.md)"
duration: "195m"
verification_result: "pass"
completed_at: "2026-05-04T12:29:19Z"
observability_surfaces:
  - "none"
---

P03 delivered the constitution-authoring + codebase-ingestion stack plus the Principle-XVI standalone-gate compliance test (FR-3..FR-8 / SC-2 / SC-3 / MIT-005 / #Q-11). 5 tasks landed across commits 95ff1046 (T01), 91c15233 (T02), eba3319b (T03), 8755d5b5 (T04), 165d78dd (T05).

T01 shipped the gating layer: `scripts/verify/constitution-shape-lint.sh` (FR-5 4-assertion lint), `scripts/verify/standalone-gate.sh` (FR-6 subcommand-dispatched dispatcher with constitution v1 and a fenced SSOT surface block), three stack starters under `templates/constitution-starters/` (web-saas / cli-tool / library — closed v1 list per FR-4), `references/constitution-starter-format.md` (US-2 AS-4 starter-format reference + #Q-2 demand-driven expansion criterion). T01 introduced the SKIP-tolerance pattern so the gate could land before its own dependent surfaces and still report green.

T02 shipped the FR-3 surface: `commands/constitution.md` doc + `scripts/lifecycle/constitution-author.sh` driver running the 5-8-question grilling-protocol flow on top of P02's `ask_one` API, substituting closed-vocabulary placeholders, gating on shape-lint, writing to `<project>/.orchestrator/memory/constitution.md`, emitting `constitution_authored` JSONL + `constitution-authored.complete` partial-state marker. After T02 landed, the standalone-gate collapsed from `pass=5 skip=2 fail=0` to `pass=7 skip=0 fail=0` (load-bearing for SC-2).

T03 shipped FR-7's deterministic core: `commands/ingest-codebase.md` + `scripts/lifecycle/ingest-codebase.sh` (deterministic structural extractor — explicitly NOT LLM-augmented per Constitution XIV / NG-8) + three byte-deterministic stack fixtures (`tests/fixtures/m033-stack-fixture-{ts-saas,py-cli,rust-library}/`) carrying `README-oracle.md` ground truth and the TS-SaaS [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) for T04's exercise. Stable IDs derived from source paths via md5 (q-darwin or sum-linux); idempotent re-runs emit `re-ingest` diagnostic; minimum-viable seed fallback emits a diagnostic when extraction yields fewer than 5 MEMs (no error). T03 left the `# >>> rich-context-branch >>>` reserved fenced block as a `true` stub for T04 fill.

T04 stitched the FR-8 / MIT-005 rich-context import path into the reserved block in place: detection of `<project>/.orchestrator/DECISIONS.md` `DR-` entries / `MILESTONE-AUDIT.md` / populated `CLAUDE.md` custom blocks → emit a thin context file (`context_source: imported-from-existing`) at `.orchestrator/milestones/<active>/<active>-CONTEXT.md` or at the `.orchestrator/milestones/_imported-context/_imported-context.md` sentinel per #Q-11; `DR-` entries cross-reference as `knowledge/decisions/MEM-DR-*` (provenance-preserving, not duplicate authoring). T04 shipped `references/imported-context-sentinel.md` (#Q-11 SSOT documenting path-resolver precedence + downstream-traverser convention) and added `_*` skip clauses to the two true enumeration sites (`scripts/diagnostics/check-plans.sh`, `scripts/diagnostics/check-constitution.sh`) with inline doc-notes at non-enumerating traversers (`scripts/state/derive-phase.sh`, `scripts/dispatch/build-context.sh`, `scripts/diagnostics/run-doctor.sh`). T04 additively extended the JSONL emitter closed enum 11→12 to add `imported_context_loaded` (P02 prereq claimed it but didn't ship it — narrowest fix; T05 harmonized the documentation).

T05 closed the phase: SC-2 acceptance (`tests/m033-acceptance/p02-constitution-author.sh`, 36 PASS), SC-3 acceptance (`tests/m033-acceptance/p03-ingest-codebase.sh`, 29 PASS), phase-suite (`tools/verify/m033-p03-phase-suite.sh`, 13 PASS), scope-guard (45 PASS), cross-phase regression (P01 14/14 + P02 10/10 + standalone-gate 7-skip0 still all PASS). T05 also harmonized three SSOT mismatches surfaced during execution: (1) `references/m033-fr21-dual-write-convention.md` amended to the real flag-form API (`--root` / `--marker recent-changes` / `--append-entry`) since the helper has no `append <fragment>` subcommand; (2) `scripts/util/start-state-markers.sh` got an alias-mapping comment block reconciling the enum (`ingest-codebase`) with FR-7 doc-prose (`ingest-codebase-completed.complete`); (3) `scripts/util/jsonl-event-emitter.sh` header / comment / SSOT block updated 11→12.

Verification: phase-suite green, every T01..T05 task verifier green, standalone-gate `pass=7 skip=0 fail=0`, P01 + P02 phase-suites still green, scope-guard 45/45. SC-3's MEM-count contract relaxed to floor-1 + diagnostic-on-sub-5 (py-cli + rust-library degenerate-fixture path). `build-context.sh --project-dir` flag deferred — SC-3's [M031](../../../../../milestones/M031/index.md) boundary check uses the existing `--task-plan` direct mode + an independent staging-tree discoverability check. Both halves pass.

Patterns established: fenced-SSOT-block-for-closed-surface with awk extraction; SKIP-tolerance for co-authored-but-not-yet-landed gate surfaces; stable-id by source-path-hash for idempotent re-extraction; byte-deterministic fixture pattern with `README-oracle.md` ground-truth naming; additive closed-enum extension; downstream-traverser `_*` skip-clause convention.

P03 unblocks P04 (materials intake, ideation, migrate-routing) and P05 (M032 paired-launch + friendly-tester gate). Open concerns deferred to those phases: (a) the helper `dual-write-runtime-md.sh` SSOT now matches reality but downstream callers still use the real flag form; (b) the JSONL emitter enum may grow further; treat the `imported_context_loaded` extension as the precedent.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M033"
name: "commands/materials-intake.md + scripts/lifecycle/materials-intake.sh deterministic CON-4 drift detector + reconciliation UX (FR-9)"
depends_on: []
---

## Prerequisites

This task is the FR-9 surface: the orchestrator-native materials-intake command + driver. It has **no intra-phase prerequisites**; it consumes only previously-shipped P01/P02/P03 surfaces.

Files that MUST exist on disk at task-start (prerequisite-existence verification per `commands/plan-phase.md` Plan-Time Discipline rule 1):

- `tests/fixtures/m033-pbj-materials-fixture/PRODUCT-BRIEF.md` (P01/T01 — PBJ fixture material 1)
- `tests/fixtures/m033-pbj-materials-fixture/MVP-PLAN.md` (P01/T01 — PBJ fixture material 2)
- `tests/fixtures/m033-pbj-materials-fixture/DECISIONS.md` (P01/T01 — PBJ fixture material 3)
- `tests/fixtures/m033-pbj-materials-fixture/MILESTONE-AUDIT.md` (P01/T01 — PBJ fixture material 4)
- `tests/fixtures/m033-pbj-materials-fixture/README.md` (P01/T01 — the SC-4 ground-truth oracle: enumerates the 5 expected detections in markdown numbered-list shape with the closed CON-4 enum tokens `id-misalignment`, `scheme-contradiction`, `orphan-reference`)
- `scripts/lifecycle/grilling-shell.sh` (P02/T03+T04 — `ask_one` API; `_GRILLING_CURRENT_QKEY` caller-set var convention)
- `scripts/util/jsonl-event-emitter.sh` (P02/T01 — `emit materials_intake_completed <payload_json>` subcommand)
- `scripts/util/start-state-markers.sh` (P02/T02 — `write materials-intake <project-dir>` subcommand; `materials-intake` is in the closed 7-name sub-flow enum)
- `scripts/util/dual-write-runtime-md.sh` (M014 closed — invoked via `--root <project-dir> --marker recent-changes --append-entry '<fragment>'` per the P03/T05 SSOT-harmonized API)
- `references/m033-fr21-dual-write-convention.md` (P02/T05 — FR-21 SSOT documenting the dual-write call shape)

## Description

T01 ships the FR-9 materials-intake surface — the orchestrator-native command + driver that takes heterogeneous source materials (the PBJ-shape: `PRODUCT-BRIEF.md`, `MVP-PLAN.md`, `DECISIONS.md`, `MILESTONE-AUDIT.md`), labels them, runs **deterministic** CON-4 drift detection (no LLM-magic merge), reconciles via terminal-interactive UX for ≤5 conflicts (file-based UX above the threshold per #Q-6), and emits a byte-deterministic reconciled pre-spec that `orchestrator:specify` consumes verbatim.

The two deliverables are:

1. **`commands/materials-intake.md`** — canonical command-doc per MEM012 (YAML frontmatter `description:` field; `# orchestrator:materials-intake` title; Prerequisites / Core Workflow / Output / Idempotency / Error Handling / Referenced Scripts sections). Documents the FR-9 contract, names the closed labeling enum (`primary | supplementary | decision-history | out-of-scope`), names the closed CON-4 detection-category enum (`id-misalignment`, `scheme-contradiction`, `orphan-reference`), names the threshold env var (`M033_CONFLICT_FILE_THRESHOLD`, default 5 per #Q-6), references the PBJ fixture as the SC-4 oracle, and explicitly states the deterministic-not-LLM invariant per CON-4.

2. **`scripts/lifecycle/materials-intake.sh`** — the FR-9 driver, bash 3.2 compatible (MEM001), structured-output PASS:/FAIL:/SUMMARY: discipline.

Co-authored alongside the deliverables (per Plan-Time Discipline rule 2, verifier-availability cross-check):

3. **`tools/verify/m033-p04-materials-intake-md-shape.sh`** — shape verifier for the command doc.
4. **`tools/verify/m033-p04-materials-intake-sh-shape.sh`** — shape verifier for the driver.

## Steps

1. **Author `commands/materials-intake.md`** following the MEM012 canonical command-doc structure. Include:
   - YAML frontmatter with `description: "Use when intaking heterogeneous source materials (Product Brief, Decision Register, MVP Plan, Handoff JSON, milestone audits) and producing a reconciled orchestrator:specify-consumable pre-spec."`
   - `# orchestrator:materials-intake` title.
   - Prerequisites section — names the four PBJ-shape material types and links to the P01 fixture as the canonical example.
   - Core Workflow — numbered sections covering: (a) material enumeration by extension, (b) labeling loop with the closed enum, (c) deterministic CON-4 drift detection with the closed three-category enum, (d) terminal-interactive resolution for ≤`M033_CONFLICT_FILE_THRESHOLD` conflicts / file-based UX above, (e) reconciled-pre-spec emission to `<project-dir>/.orchestrator/intake/<timestamp>/reconciled-pre-spec.md`, (f) marker write + JSONL emit + dual-write fragment.
   - Output section — names the artifacts (`reconciled-pre-spec.md` or `conflicts.md`), the `materials-intake.complete` marker, the `materials_intake_completed` JSONL event.
   - Idempotency — re-running against the same `<timestamp>` directory resumes labeling/reconciliation from on-disk state.
   - Error Handling — names the `out-of-scope`-only fallback per US-4 AS-5; the missing-converter-binary diagnostic per Edge Case "Materials intake against a directory with binary materials".
   - Referenced Scripts — lists `scripts/lifecycle/materials-intake.sh`, `scripts/lifecycle/grilling-shell.sh` (consumed for `ask_one`), `scripts/util/jsonl-event-emitter.sh`, `scripts/util/start-state-markers.sh`, `scripts/util/dual-write-runtime-md.sh`.

2. **Author `scripts/lifecycle/materials-intake.sh`** — bash 3.2 compatible. Top-level structure:
   - Shebang `#!/usr/bin/env bash`, then `set -e`, `set -u`, `set -o pipefail`.
   - File header comment naming FR-9, CON-4, MEM001, the spec ref (`specs/036-project-onboarding-experience/spec.md`).
   - Fenced SSOT comment blocks:
     - `# >>> material-extensions >>>` containing `.md`, `.pdf`, `.json`, `.txt` (one per line).
     - `# >>> labeling-enum >>>` containing `primary`, `supplementary`, `decision-history`, `out-of-scope` (one per line).
     - `# >>> drift-categories >>>` containing `id-misalignment`, `scheme-contradiction`, `orphan-reference` (one per line).
   - Flag parsing: `--project-dir <path>` (default `pwd`), `--yes` (auto-accept defaults), `--resolve <conflicts.md>` (re-invocation path).
   - Helper `enumerate_materials <project-dir>` — iterates project-root files matching the closed extension SSOT; for `.pdf`, probes `command -v textutil` (darwin) or `command -v pdftotext` (linux) and surfaces a missing-binary diagnostic + skip if absent (NOT silent skip per Edge Case).
   - Helper `label_material <material-path> <yes_flag>` — derives recommendation from filename heuristics (`*BRIEF*` / `*PLAN*` → `primary`; `*DECISIONS*` / `*AUDIT*` → `decision-history`; `*HANDOFF*` → `supplementary`; otherwise `supplementary`); under `--yes` auto-accepts; otherwise invokes `ask_one "Label for <basename>:" "<recommendation>"` (no third-arg context-file — labeling is independent of contradiction-detection).
   - Helper `detect_drift <project-dir> <materials-list>` — three deterministic detectors, each reading the materials and emitting `<category>:<conflict-N>:<details>` lines to a temp accumulator file:
     - `detect_id_misalignment`: extracts `<TOKEN>-<NUMBER>` references (e.g., `DR-001`, `M001`, `FR-12`) per material via `grep -oE '[A-Z][A-Z]+-[0-9]+'`; for each token-prefix family (`DR-`, `FR-`, `M-`, etc.), compares the maximum number across documents — if two documents reference the same token-prefix family but with non-overlapping number ranges, emit an `id-misalignment` entry.
     - `detect_scheme_contradiction`: extracts same-key declarations across `primary` + `supplementary` materials (e.g., `target_user:`, `mvp_boundary:`, `success_metric:` lines) and emits a `scheme-contradiction` entry when the same key has different values across documents.
     - `detect_orphan_reference`: collects every `<TOKEN>-<NUMBER>` reference, then collects every `<TOKEN>-<NUMBER>` definition (lines matching `^### (TOKEN-NUMBER)` or `^TOKEN-NUMBER:` per the PBJ fixture's convention); emits an `orphan-reference` entry for any reference without a defining occurrence.
   - Helper `surface_conflicts <accumulator-file> <count>` — prints the conflict checklist to stdout (numbered 1..N, one per line, `<N>. <category>: <details>` shape).
   - Helper `reconcile_terminal <accumulator-file>` — for each conflict, invokes `ask_one "Resolve conflict <N> (<category>):" "accept-primary"` with the closed resolution enum `accept-primary | accept-supplementary | manual-edit | defer`; appends the resolution to the accumulator.
   - Helper `reconcile_file_based <accumulator-file> <project-dir> <timestamp>` — writes a markdown checklist to `<project-dir>/.orchestrator/intake/<timestamp>/conflicts.md` and exits 0 with `edit then re-invoke with --resolve <path>` diagnostic.
   - Helper `emit_reconciled_prespec <accumulator-file> <project-dir> <timestamp>` — composes the byte-deterministic reconciled pre-spec body: H1 title, sections per labeled material (primary first), provenance comments per resolved conflict (`<!-- Reconciled: conflict-N → accept-primary -->`). Writes to `<project-dir>/.orchestrator/intake/<timestamp>/reconciled-pre-spec.md`. The body must NOT embed timestamps or random tokens; only the directory name carries the timestamp.
   - Main flow: parse flags → resolve `<timestamp>` (honoring `M033_INTAKE_TIMESTAMP` env override for SC-4 byte-determinism) → enumerate → label → detect drift → if conflict-count ≤ threshold → reconcile-terminal → emit prespec; else → reconcile-file-based → exit 0 with diagnostic. After successful pre-spec emit: `bash scripts/util/start-state-markers.sh write materials-intake <project-dir>`; `bash scripts/util/jsonl-event-emitter.sh emit materials_intake_completed '{"materials_count":<N>,"conflicts_resolved":<M>}'` (PROJECT_DIR env set to `<project-dir>`); `bash scripts/util/dual-write-runtime-md.sh --root <project-dir> --marker recent-changes --append-entry "materials-intake: reconciled <N> materials with <M> conflicts resolved"`.
   - Out-of-scope-only fallback: when ALL detected materials are labeled `out-of-scope`, exit 0 with `no primary spec materials labeled — skipping reconciliation, falling back to greenfield-empty ideation flow` to stdout. No reconciled-pre-spec written. No marker written.

3. **Author `tools/verify/m033-p04-materials-intake-md-shape.sh`** — bash 3.2 verifier asserting:
   - File `commands/materials-intake.md` exists.
   - Contains `orchestrator:materials-intake`, `FR-9`, `CON-4`, `materials-intake.sh`, `primary`, `supplementary`, `decision-history`, `out-of-scope`, `id-misalignment`, `scheme-contradiction`, `orphan-reference`, `M033_CONFLICT_FILE_THRESHOLD`, `reconciled-pre-spec.md`, `materials_intake_completed`, `deterministic`, `m033-pbj-materials-fixture`.
   - Min line count 60.
   - Emits `PASS:`/`FAIL:` lines per check; final `SUMMARY: m033-p04-materials-intake-md-shape.sh pass=N fail=M`.

4. **Author `tools/verify/m033-p04-materials-intake-sh-shape.sh`** — bash 3.2 verifier asserting:
   - File `scripts/lifecycle/materials-intake.sh` exists, is executable.
   - Contains the fenced SSOT block markers `>>> material-extensions >>>`, `>>> labeling-enum >>>`, `>>> drift-categories >>>`.
   - Contains `ask_one`, `grilling-shell.sh`, `--project-dir`, `--yes`, `--resolve`, `id-misalignment`, `scheme-contradiction`, `orphan-reference`, `reconciled-pre-spec.md`, `conflicts.md`, `materials_intake_completed`, `materials-intake.complete`, `dual-write-runtime-md.sh`, `textutil`, `pdftotext`, `M033_CONFLICT_FILE_THRESHOLD`, `M033_INTAKE_TIMESTAMP`.
   - Bash 3.2 compat negative grep: does NOT contain `declare -A`, does NOT contain `<(` (process substitution).
   - Min line count 250.
   - Emits PASS/FAIL/SUMMARY lines.

## Must-Haves

- `commands/materials-intake.md` exists, ≥60 lines, satisfies the shape verifier (FR-9 contract documented per MEM012).
- `scripts/lifecycle/materials-intake.sh` exists, executable, ≥250 lines, satisfies the shape verifier (FR-9 driver implemented per spec; bash 3.2 compatible per MEM001).
- `tools/verify/m033-p04-materials-intake-md-shape.sh` exists, executable, exits 0 against the authored doc.
- `tools/verify/m033-p04-materials-intake-sh-shape.sh` exists, executable, exits 0 against the authored driver.

## Verification

```bash
bash tools/verify/m033-p04-materials-intake-md-shape.sh
```

```bash
bash tools/verify/m033-p04-materials-intake-sh-shape.sh
```

```bash
bash scripts/diagnostics/check-plans.sh
```

## Inputs

### From Previous Tasks

- `tests/fixtures/m033-pbj-materials-fixture/README.md` (from M033/P01/T01)
  - Key API: parser-load-bearing markdown numbered-list shape; lines `1.`..`5.` enumerate the 5 expected detections, each tagged with one of the closed CON-4 tokens (`id-misalignment`, `scheme-contradiction`, `orphan-reference`).
  - Key types: ground-truth oracle for SC-4 — drift detector output MUST match this README's enumeration line-by-line.
- `scripts/lifecycle/grilling-shell.sh` (from M033/P02/T03+T04)
  - Key API: `ask_one <question> <recommendation> [<context-file>]`. Prints `recommendation:` token first, then the question; reads one stdin line; one-keystroke contract (`Y`/`y`/empty → accept rec; `N`/`n` → re-prompt for explicit; otherwise treat as explicit answer); echoes `answer: <value>` on stdout. Returns 0 on success, 2 on bad usage / no explicit answer, 3 on contradiction-unresolved.
  - Key types: caller-set vars `_GRILLING_CURRENT_QKEY` (string), `_GRILLING_CURRENT_DEFINITION` (string) — set BEFORE invoking ask_one when contradiction-detection or glossary-update should fire. T01 sets `_GRILLING_CURRENT_QKEY=""` for labeling-loop calls (label questions are independent of contradiction detection).
- `scripts/util/jsonl-event-emitter.sh` (from M033/P02/T01)
  - Key API: `bash scripts/util/jsonl-event-emitter.sh emit <event_type> <payload_json>`. Closed enum includes `materials_intake_completed`. Honors `PROJECT_DIR` env override; appends to `<PROJECT_DIR>/.orchestrator/execution-log.jsonl`.
  - Key types: `<payload_json>` MUST be a JSON object (`{...}`); ≤480 bytes after format.
- `scripts/util/start-state-markers.sh` (from M033/P02/T02)
  - Key API: `bash scripts/util/start-state-markers.sh write materials-intake <project-dir>`. `materials-intake` is in the closed 7-name sub-flow enum; idempotent (first-completion timestamp preserved).
- `scripts/util/dual-write-runtime-md.sh` (M014 closed, P03/T05 SSOT-harmonized API)
  - Key API: `bash scripts/util/dual-write-runtime-md.sh --root <project-dir> --marker recent-changes --append-entry '<fragment>'`. Appends one line to `# >>> orchestrator:recent-changes >>>` block in `CLAUDE.md` (and `AGENTS.md` unless `dual_write_agents: false` in config).

### From Disk (Pre-existing)

- `templates/spec-template.md` — referenced for `orchestrator:specify --description` consumption shape; the reconciled pre-spec body should be flat markdown that this template can absorb.
- `references/m033-fr21-dual-write-convention.md` (from M033/P02/T05) — FR-21 SSOT; T01's dual-write fragment shape follows the convention's per-command examples.
- `commands/plan-phase.md` — Plan-Time Discipline rules 1, 2, 3, 6 inform the verifier-availability + path-collision discipline applied here.

## Constraints

- **CON-4 (deterministic-not-LLM)**: drift detection MUST use deterministic structural extraction only — `grep`/`awk`/`sed` regex; NO model invocation. The verifier asserts no `claude-code` / `conversus` / `llm` / `model_routing` substrings appear in materials-intake.sh.
- **MEM001 (bash 3.2 compat)**: no `declare -A`; no process substitution `<(...)`; no `$(...)` containing pipes. The verifier asserts via negative grep.
- **CON-5 (sequential-never-batched)**: labeling and reconciliation loops MUST invoke `ask_one` once per item, awaiting the resolved answer before proceeding to the next.
- **Byte-deterministic reconciled pre-spec**: same fixture + same answers → byte-identical body content. The directory-name timestamp is the only non-deterministic element; it is not embedded in the body. SC-4's `diff`-based determinism check pins the timestamp via `M033_INTAKE_TIMESTAMP` env override.
- **Path discipline**: command doc → `commands/`, driver → `scripts/lifecycle/`, project-owned slug-bearing verifiers → `tools/verify/m033-p04-*`. NO writes to `scripts/verify/` (framework-owned tree).
- **Path-collision check (Plan-Time Discipline rule 6)**: at task-start, run `ls -la commands/materials-intake.md scripts/lifecycle/materials-intake.sh tools/verify/m033-p04-materials-intake-md-shape.sh tools/verify/m033-p04-materials-intake-sh-shape.sh` — each MUST return "No such file or directory" before authoring (the four `create` deliverables have no pre-existing path collisions).
- **Scope**: T01 does NOT touch start.sh, ingest-codebase.sh, ideation.sh, or any P05 / customblock surface.

## Expected Output

After T01 completes:

- `commands/materials-intake.md` (new file, ≥60 lines)
- `scripts/lifecycle/materials-intake.sh` (new file, ≥250 lines, executable)
- `tools/verify/m033-p04-materials-intake-md-shape.sh` (new file, ≥30 lines, executable)
- `tools/verify/m033-p04-materials-intake-sh-shape.sh` (new file, ≥35 lines, executable)
- Both T01 verifiers exit 0; emit `SUMMARY: <name> pass=N fail=0` on the final line.
- `bash scripts/diagnostics/check-plans.sh` reports no new warnings against the T01 plan.

## Notes

- The shape verifiers run in static-grep-only mode at task time (no integration / functional smoke). Functional verification of the materials-intake driver against the PBJ fixture is T05's SC-4 acceptance script (`tests/m033-acceptance/p04-materials-intake.sh`).
- The `M033_INTAKE_TIMESTAMP` env override is documented in the driver's header comments as a TEST-ONLY escape valve. Production invocations rely on the natural `date -u +%Y%m%dT%H%M%SZ` timestamp.
- T01 OPTIONALLY rewires P01's `materials_intake_stub` in `scripts/lifecycle/start.sh` to invoke the real driver (replacing the `would-execute: materials-intake-stub` token with `materials-intake-completed:` or similar). This rewiring is execution-time-decided by the implementing agent — if SC-1's assertions are token-shape-tolerant, the rewiring is in scope; if SC-1 asserts the exact `would-execute:` literal, the rewiring is deferred to T05's cross-phase regression check (T05 updates SC-1 in lockstep). The cross-phase regression verifier is the canonical gate.

## State Context

- **Current State**: executing
- **Milestone**: M033
- **Phase**: P04
- **Task**: T01-materials-intake
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **CON-4 (deterministic-not-LLM)**: drift detection MUST use deterministic structural extraction only — `grep`/`awk`/`sed` regex; NO model invocation. The verifier asserts no `claude-code` / `conversus` / `llm` / `model_routing` substrings appear in materials-intake.sh.
- **MEM001 (bash 3.2 compat)**: no `declare -A`; no process substitution `<(...)`; no `$(...)` containing pipes. The verifier asserts via negative grep.
- **CON-5 (sequential-never-batched)**: labeling and reconciliation loops MUST invoke `ask_one` once per item, awaiting the resolved answer before proceeding to the next.
- **Byte-deterministic reconciled pre-spec**: same fixture + same answers → byte-identical body content. The directory-name timestamp is the only non-deterministic element; it is not embedded in the body. SC-4's `diff`-based determinism check pins the timestamp via `M033_INTAKE_TIMESTAMP` env override.
- **Path discipline**: command doc → `commands/`, driver → `scripts/lifecycle/`, project-owned slug-bearing verifiers → `tools/verify/m033-p04-*`. NO writes to `scripts/verify/` (framework-owned tree).
- **Path-collision check (Plan-Time Discipline rule 6)**: at task-start, run `ls -la commands/materials-intake.md scripts/lifecycle/materials-intake.sh tools/verify/m033-p04-materials-intake-md-shape.sh tools/verify/m033-p04-materials-intake-sh-shape.sh` — each MUST return "No such file or directory" before authoring (the four `create` deliverables have no pre-existing path collisions).
- **Scope**: T01 does NOT touch start.sh, ingest-codebase.sh, ideation.sh, or any P05 / customblock surface.

### Acceptance Criteria

- `commands/materials-intake.md` exists, ≥60 lines, satisfies the shape verifier (FR-9 contract documented per MEM012).
- `scripts/lifecycle/materials-intake.sh` exists, executable, ≥250 lines, satisfies the shape verifier (FR-9 driver implemented per spec; bash 3.2 compatible per MEM001).
- `tools/verify/m033-p04-materials-intake-md-shape.sh` exists, executable, exits 0 against the authored doc.
- `tools/verify/m033-p04-materials-intake-sh-shape.sh` exists, executable, exits 0 against the authored driver.

### Files To Touch

- `commands/materials-intake.md` (create, T01)
- `commands/ideation.md` (create, T02)
- `scripts/lifecycle/materials-intake.sh` (create, T01)
- `scripts/lifecycle/ideation.sh` (create, T02)
- `scripts/lifecycle/start.sh` (modify, T04 — replaces `migrate_routing_stub` with real FR-11 implementation; preserves P01 behavior for non-migrating branches; T01/T02 OPTIONALLY rewire `materials_intake_stub` and `ideation_stub` to invoke the real drivers — execution-time decision per scope-guard rule "behavior-preserving extension")
- `scripts/lifecycle/ingest-codebase.sh` (modify, T03 — adds `derived_from_migrate: true` sentinel-flag handling and `skip-duplicate-from-migrate:` diagnostic; preserves P03 behavior for non-migrate-mode invocations)
- `tests/m033-acceptance/p04-materials-intake.sh` (create, T05)
- `tests/m033-acceptance/p04-ideation.sh` (create, T05)
- `tests/m033-acceptance/p05-migrate-routing.sh` (create, T05)
- `tools/verify/m033-p04-materials-intake-md-shape.sh` (create, T01)
- `tools/verify/m033-p04-materials-intake-sh-shape.sh` (create, T01)
- `tools/verify/m033-p04-ideation-md-shape.sh` (create, T02)
- `tools/verify/m033-p04-ideation-sh-shape.sh` (create, T02)
- `tools/verify/m033-p04-migrate-routing-shape.sh` (create, T04)
- `tools/verify/m033-p04-migrate-then-ingest-shape.sh` (create, T03)
- `tools/verify/m033-p04-acceptance-shape-sc4.sh` (create, T05)
- `tools/verify/m033-p04-acceptance-shape-sc5.sh` (create, T05)
- `tools/verify/m033-p04-acceptance-shape-sc6.sh` (create, T05)
- `tools/verify/m033-p04-phase-suite.sh` (create, T05)
- `tools/verify/m033-p04-cross-phase-regression.sh` (create, T05)
- `tools/verify/m033-p04-scope-guard.sh` (create, T05)

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