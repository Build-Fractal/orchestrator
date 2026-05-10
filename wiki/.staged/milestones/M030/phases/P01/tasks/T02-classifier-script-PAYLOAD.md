---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T02-classifier-script (Phase P01, Milestone M030)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-978 | ~500 | required |
| Upstream Context | 980-1047 | ~1800 | required |
| Task Plan | 1049-1363 | ~5500 | required |
| State Context | 1365-1371 | ~100 | required |
| First-Turn Completeness | 1373-1418 | ~700 | required |
| **Total** | | **~19400** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 660
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
hit_count: 660
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
hit_count: 660
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
hit_count: 660
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
hit_count: 583
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
hit_count: 583
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
hit_count: 583
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
hit_count: 660
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
hit_count: 583
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
hit_count: 583
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
hit_count: 583
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
hit_count: 660
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
hit_count: 660
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
hit_count: 660
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
hit_count: 583
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
hit_count: 583
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
hit_count: 583
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
hit_count: 660
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
hit_count: 583
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
hit_count: 583
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
hit_count: 660
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
hit_count: 660
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
hit_count: 583
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
hit_count: 583
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
hit_count: 583
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
hit_count: 238
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
hit_count: 238
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
hit_count: 238
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
hit_count: 236
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
hit_count: 236
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
hit_count: 226
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
     Project-owned per-phase verifiers live under tools/verify/ with
     slug-bearing filenames (p01-*) so install-clobber risk is contained.
     Verifier authorship is co-scheduled with the artifact it gates, in
     the SAME task, per Plan-Time Discipline rule 2 (verifier-availability
     cross-check). No cross-task verifier dependencies. -->

### Truths

- D-A4/SC-10 timeline ordering holds: `tests/fixtures/m030-classifier-corpus/labels.yml`'s first-commit timestamp predates `scripts/dispatch/classify-task.sh`'s first-commit timestamp. (Graduates the P00 absence-check proxy to a git-log ordering check; the verifier accepts pre-graduation absence as a pass during T01 itself, then enforces ordering once classify-task.sh ships in T02.)
  - Check: `bash tools/verify/p01-d-a4-timeline.sh`

- `scripts/dispatch/classify-task.sh` exists and emits deterministic stdout. Two consecutive runs against the same plan path produce byte-identical `character=` + `confidence=` lines (no timestamp, no PID, no random ordering). Output vocabulary is closed: `character` ∈ {mechanical, standard, novel}; `confidence` ∈ {high, medium, low}. (FR-1 + FR-2 + SC-1 determinism gate.)
  - Check: `bash tools/verify/p01-classifier-determinism.sh`

- The classifier runs in well under 100ms per plan and makes no network calls. Performance gate: against any one P00 corpus plan, wall-clock measured by the classifier wrapper script is <100ms. Network-call gate: `classify-task.sh` body contains no `curl`, `wget`, `nc`, `dispatch-interface.sh`, or `bash scripts/dispatch/adapters/backend/` invocation; the script body is grep-asserted clean. (FR-1 hot-path constraint + SC-1 no-network-calls gate.)
  - Check: `bash tools/verify/p01-classifier-perf-and-network.sh`

<dispatch-volatile>

## Upstream Context


### P00 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P00"
parent: "M030"
milestone: "M030"
provides:
  - "40-plan classifier ground-truth fixture skeleton at tests/fixtures/m030-classifier-corpus/labels.yml (TBD labels — T02 fills); p00-corpus-shape.sh + p00-plans-exist.sh AD-19 verifiers under tools/verify/ (project-owned path),40-entry hand-labeled classifier ground-truth corpus (20 mechanical / 15 standard / 5 novel) plus tools/verify/p00-class-coverage.sh strict-vocabulary + per-class-floor + total-floor + no-TBD-rationale gate; tools/verify/p00-corpus-shape.sh tightened to reject TBD,corpus-README + D-A4-independence-verifier + README-shape-verifier + phase-suite-gate"
requires:
  - "none"
affects:
  - "P01"
key_files:
  - "tests/fixtures/m030-classifier-corpus/labels.yml,tests/fixtures/m030-classifier-corpus/SELECTION-NOTES.md,tools/verify/p00-corpus-shape.sh,tools/verify/p00-plans-exist.sh,tools/verify/p00-class-coverage.sh,tests/fixtures/m030-classifier-corpus/README.md,tools/verify/p00-d-a4-independence.sh,tools/verify/p00-readme-shape.sh,tools/verify/p00-phase-suite.sh"
key_decisions:
  - "D-A4 (independence-by-construction: classifier labels predate classifier code on disk); closed-milestone-only sourcing (in-flight bias guard); 40-plan floor with provisional class-diversity intent,D-A4 (mechanical independence preserved — classify-task.sh STILL absent during T02 labeling); rubric application per-plan with judgment,no automated pre-pass,D-A4-independence-by-absence-during-P00; phase-suite-straight-line-no-loops"
patterns_established:
  - "project-owned verifier path under tools/verify/ (AD-19 install-clobber containment); single-script-file Truth Check shape with awk-based shape walker + grep-based key probe; TBD-tolerant vocabulary check at skeleton phase that T02/T03 tighten,strict closed-enum vocabulary at T02-close (mechanical|standard|novel for character; high|medium|low for confidence); per-class floor 5; rationale field as audit trail capturing the specific signal that drove each call,phase-suite-aggregator-pattern; absence-check-as-load-bearing-D-A4-proxy; SELECTION-NOTES-graduates-into-README-on-phase-close"
drill_down_paths:
  - "[.orchestrator/milestones/M030/phases/P00/tasks/T01-SUMMARY.md](../../../../../milestones/M030/phases/P00/tasks/T01-SUMMARY.md), [.orchestrator/milestones/M030/phases/P00/tasks/T02-SUMMARY.md](../../../../../milestones/M030/phases/P00/tasks/T02-SUMMARY.md), [.orchestrator/milestones/M030/phases/P00/tasks/T03-SUMMARY.md](../../../../../milestones/M030/phases/P00/tasks/T03-SUMMARY.md)"
duration: "180m"
verification_result: "pass"
completed_at: "2026-04-30T11:14:39Z"
observability_surfaces:
  - "none"
---

P00 builds the version-controlled classifier ground-truth fixture corpus that anchors SC-10's ≥85% agreement check. Three linear tasks (T01 → T02 → T03) shipped 40 hand-labeled task plans drawn from this repo's milestone history, plus the methodology + compliance documentation, plus five Bash 3.2-compatible verifiers under `tools/verify/` aggregated by `p00-phase-suite.sh`.

## What was built

- `tests/fixtures/m030-classifier-corpus/labels.yml` — 40 entries with `plan_path` + `character` (mechanical|standard|novel) + `confidence` (high|medium|low) + non-empty `rationale`. Final class distribution: 20 mechanical / 15 standard / 5 novel. Confidence distribution: 26 high / 14 medium / 0 low (T02 reports `low` is in-vocabulary but unused — borderline cases honestly resolve to a clear two-class window). All 40 `plan_path` values resolve on disk.
- `tests/fixtures/m030-classifier-corpus/README.md` (190 lines) — Source Pool + Sampling Methodology + Labeling Rubric (FR-1 verbatim) + D-A4 Independence Compliance + Cross-References. Graduates T01's SELECTION-NOTES.md working artifact, including T02's load-bearing observation that the file-count threshold is the mechanical/standard distinguisher.
- `tools/verify/p00-corpus-shape.sh` (197 lines) — frontmatter shape + ≥30 entry floor + four-required-keys-per-entry + strict closed-enum vocabulary check (rejects TBD as of T02-tighten).
- `tools/verify/p00-plans-exist.sh` (49 lines) — every `plan_path` resolves on disk via `[ -f "$p" ]`.
- `tools/verify/p00-class-coverage.sh` (161 lines) — per-class floor of 5 + strict three-class character vocabulary + strict three-value confidence vocabulary + non-empty rationale.
- `tools/verify/p00-readme-shape.sh` (109 lines) — required-section presence (Source Pool, Sampling Methodology, Labeling Rubric, D-A4 Independence Compliance) + character keyword reproduction.
- `tools/verify/p00-d-a4-independence.sh` (56 lines) — absence-check for `scripts/dispatch/classify-task.sh`. Header comments document the post-P01 git-log ordering graduation path.
- `tools/verify/p00-phase-suite.sh` (84 lines) — straight-line aggregator over the five P00 gates; emits final SUMMARY line; no loops or eval per AD-19.

## Key decisions

- **D-A4 independence-by-construction** holds at P00-close. `scripts/dispatch/classify-task.sh` did not exist on disk during T01, T02, or T03. The mechanical proxy passes by absence today; post-P01 it graduates to a git-log ordering check (labels.yml first-commit timestamp precedes classify-task.sh first-commit timestamp).
- **Closed-milestone-only sourcing**. Candidate plans came from `.orchestrator/milestones/M*/{archive,phases}/P*/T*-PLAN.md` filtered to milestones with `M*-SUMMARY.md` at root. [M028](../../../../../milestones/M028/index.md) (in-flight) and M030 (self) were excluded so the labeler isn't biased by current development context.
- **Project-owned verifier path** under `tools/verify/`. Slug-bearing filenames (`p00-*`) contain install-clobber risk per AD-19's path discipline.
- **Rubric application per-plan with judgment**. No automated keyword-pre-pass produced labels — T02 read each plan and applied the rubric. The `rationale` field captures the specific signal that drove each call (the D-A4 audit trail).

## Verification results

- `bash tools/verify/p00-phase-suite.sh` → `SUMMARY: p00-phase-suite.sh pass=5 fail=0`, exit 0.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P00` → all truths + artifacts + key-links pass, exit 0.

## Patterns established (carry forward)

- **Phase-suite aggregator pattern** — straight-line invocation of N sub-gates, no loops, single SUMMARY line.
- **Skeleton-tighten-graduate task chain** — T01 ships TBD-tolerant skeleton; T02 fills labels and tightens the shape verifier; T03 documents methodology and ships the gate suite.
- **SELECTION-NOTES → README graduation** — T01's working notes file is removed at T03 close after its content is folded into the README's `## Sampling Methodology` section.

## Notes for downstream

- P01 (`scripts/dispatch/classify-task.sh` author) MUST graduate `p00-d-a4-independence.sh` to its post-P01 git-log ordering check. Header comments in the script identify the graduation point.
- The unused `low` confidence bucket (0 entries in this corpus) is in-vocabulary but absent. If the FR-1 classifier emits `low`, vocabulary parity is preserved but no agreement assertion can be made on that bucket from this corpus.
- The shipped check-must-haves.sh `grep -F` paper-cut fix (changed from regex to fixed-string substring match) is a downstream beneficiary — every prior milestone's `contains "..."` artifact spec that included regex meta-characters was a latent failure waiting on input shape.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M030"
name: "Classifier script + determinism + perf/network + ground-truth verifiers"
depends_on: ["T01"]
---

## Prerequisites

- `tools/verify/p01-d-a4-timeline.sh` exists (T01 deliverable). The script is on disk so the moment T02 commits `classify-task.sh`, re-running this verifier triggers Mode B (git-log ordering) and confirms timeline ordering by construction.
- `tests/fixtures/m030-classifier-corpus/labels.yml` exists with 40 entries (P00/T02; 20 mechanical / 15 standard / 5 novel).
- `tests/fixtures/m030-classifier-corpus/README.md` exists with the FR-1 labeling rubric (P00/T03 deliverable; the rubric is the SSOT for the heuristic table T02 implements).
- All `plan_path` values in `labels.yml` resolve to existing files on disk (P00 verifier `p00-plans-exist.sh` already gates this).
- `scripts/dispatch/classify-task.sh` does **NOT** yet exist on disk at the start of T02.

Plan-time prerequisite-existence verification: every path above resolves under `[ -f <path> ]` except `scripts/dispatch/classify-task.sh` which MUST NOT exist (`[ ! -f scripts/dispatch/classify-task.sh ]`).

## Description

T02 is the high-risk core primitive. It authors `scripts/dispatch/classify-task.sh` — the deterministic, sub-100ms, no-network-call task-character classifier that is the load-bearing input to every downstream M030 phase. Concrete deliverables:

1. `scripts/dispatch/classify-task.sh` — the FR-1 / FR-2 classifier.
2. `tools/verify/p01-classifier-determinism.sh` — SC-1 byte-equality gate (two runs same plan, `diff` empty).
3. `tools/verify/p01-classifier-perf-and-network.sh` — performance (<100ms wall-clock) + grep-clean of the script body (no curl/wget/nc/dispatch-adapter invocations).
4. `tools/verify/p01-classifier-ground-truth.sh` — SC-10 ≥85% agreement gate against the P00 corpus.

The classifier emits exactly two lines on stdout per invocation, in this order:

```
character=<mechanical|standard|novel>
confidence=<high|medium|low>
```

No other stdout output. Stderr may carry diagnostic lines (e.g., `RESULT:` lines if the project's `scripts/lib/errors.sh` is sourced). The output vocabulary is a closed enum identical to the P00 fixture corpus vocabulary.

### Heuristic table (FR-2 SSOT)

The classifier reads PLAN.md frontmatter and body and applies a literal rule table. No machine learning, no LLM, no network. The full input set per FR-2 is: (a) explicit `## Steps` block presence + structure, (b) file-touch breadth declared in plan, (c) verification-block specificity, (d) frontmatter `type:` field if present, (e) phase position within milestone, and (f) recent-retry signal from [M027](../../../../../milestones/M027/index.md) anomaly JSONL. For T02's initial implementation, inputs (a)-(d) are the load-bearing signals; (e) and (f) are stubbed to pass-through values that don't affect classification (left as TODO comments in the script for follow-up). This is acceptable because the SC-10 ≥85% agreement gate is what mechanically validates the heuristic — if the simplified heuristic table hits ≥85% on the 40-entry corpus, it ships; if not, T02 iterates the table until it does, OR the inputs (e)/(f) are wired up.

Concrete heuristic rules (apply in priority order; the first match wins):

1. **Frontmatter override** — if PLAN.md frontmatter contains `complexity: <tier>` or an explicit character hint, use it. Confidence: high.
2. **Novel signals (high-precedence)** — if the plan's Goal / Description section contains any of the literal words `explore`, `design alternatives`, `evaluate alternatives`, `spike`, `research`, `investigate options`, `prototype`, AND no `## Steps` block lists explicit file paths, classify as `novel`. Confidence: high.
3. **Mechanical signals** — if a `## Steps` block exists AND the union of file paths declared in Steps + Files-Likely-Touched ≤ 3 distinct files AND the `## Verification` section contains at least one explicit `bash <path>.sh` invocation, classify as `mechanical`. Confidence: high.
4. **Standard fallback** — anything else is `standard`. Confidence is `high` if both a Steps block and a Verification block are present, `medium` if one is present, `low` if neither (rare — typically novel framing without explicit "explore"-class words).

The exact regex patterns + bash extraction shapes are documented in the script body's commented heuristic table; T02's executor authors them with judgment, then iterates until SC-10's ≥85% agreement gate (`tools/verify/p01-classifier-ground-truth.sh`) passes.

### Output stability — D-A9

Per D-A9, classifier output for the same PLAN.md is consistent within a single `orchestrator:auto` run because the anomaly JSONL state is snapshotted at session start. T02's initial implementation does NOT read anomaly JSONL (input (f) is stubbed), so cross-run consistency is trivially preserved. When input (f) is wired in a future iteration, the script MUST snapshot the JSONL once at the start of the run (or read it once at session startup) so two invocations within the same run produce identical output. The SC-1 determinism verifier in T02 catches violations.

## Steps

1. **Confirm `tools/verify/p01-d-a4-timeline.sh` is on disk and `scripts/dispatch/classify-task.sh` is absent.** Run:

   ```bash
   ls tools/verify/p01-d-a4-timeline.sh
   ```

   Expected: prints the path. Then:

   ```bash
   ls scripts/dispatch/classify-task.sh
   ```

   Expected: `No such file or directory` (stderr) + non-zero exit.

2. **Author `scripts/dispatch/classify-task.sh`.** Bash 3.2-compatible. No `declare -A`. No jq required (jq optional fallback acceptable per MEM001). Single-script-file invocation pattern (`bash classify-task.sh <plan-path>`). Output contract:

   - stdout line 1: `character=<mechanical|standard|novel>`
   - stdout line 2: `confidence=<high|medium|low>`
   - exit 0 on success, exit 1 on usage error (missing arg, plan path doesn't exist).

   Skeleton (executor fills the heuristic table per the FR-2 input set + the priority rules above):

   ```bash
   #!/usr/bin/env bash
   # scripts/dispatch/classify-task.sh — M030 task-character classifier (FR-1, FR-2).
   #
   # Reads a PLAN.md and emits two stdout lines:
   #   character=<mechanical|standard|novel>
   #   confidence=<high|medium|low>
   #
   # Pure bash + grep/sed/awk. NO LLM call. NO network. NO jq dependency
   # on the hot path. Bash 3.2 compatible. Runs in well under 100ms.
   #
   # Usage: classify-task.sh <plan-path>
   #
   # AD-19 single-script-file invocation. CON-1 (no-LLM-on-hot-path).
   # CON-3 (symbolic-tier closure — classifier emits character only;
   # tier resolution lives in templates/model-routing.yml).
   #
   # FR-2 input set (inputs e/f stubbed in v1; see ## Notes for the
   # SC-10 agreement-validated rationale):
   #   (a) ## Steps block presence + structure   — IMPLEMENTED
   #   (b) file-touch breadth in plan            — IMPLEMENTED
   #   (c) ## Verification specificity           — IMPLEMENTED
   #   (d) frontmatter type: field               — IMPLEMENTED
   #   (e) phase position                        — STUBBED (no-op)
   #   (f) recent-retry anomaly JSONL signal     — STUBBED (no-op)

   set -uo pipefail

   PLAN_PATH="${1:-}"
   if [ -z "$PLAN_PATH" ]; then
     echo "usage: classify-task.sh <plan-path>" >&2
     exit 1
   fi
   if [ ! -f "$PLAN_PATH" ]; then
     echo "classify-task.sh: plan not found: $PLAN_PATH" >&2
     exit 1
   fi

   # ---- Heuristic table (priority order, first match wins) ----
   #
   # Rule 1: frontmatter explicit override.
   # Rule 2: novel signals + no concrete file targets.
   # Rule 3: mechanical signals (Steps + ≤3 files + bash verifiers).
   # Rule 4: standard fallback (confidence depends on Steps/Verification presence).

   character=""
   confidence=""

   # Rule 1: explicit override in frontmatter.
   if awk '/^---$/{c++; next} c==1 && /^character: */{print $2; found=1; exit} END{exit !found}' "$PLAN_PATH" > /tmp/p01-classify-fm-char.tmp 2>/dev/null; then
     fm_char="$(cat /tmp/p01-classify-fm-char.tmp)"
     case "$fm_char" in
       mechanical|standard|novel)
         character="$fm_char"
         confidence="high"
         ;;
     esac
     rm -f /tmp/p01-classify-fm-char.tmp
   fi

   # Rule 2: novel signals.
   if [ -z "$character" ]; then
     # Detect "explore"-class language outside code fences.
     if grep -E -i -q '\b(explore|design alternatives|evaluate alternatives|spike|research|investigate options|prototype)\b' "$PLAN_PATH"; then
       # Only classify novel if there are NOT explicit file paths in Steps.
       if ! grep -E -q '^\s*[0-9]+\.\s+\*\*Author\b|^\s*-\s+`[a-zA-Z0-9_/.-]+\.(sh|md|yml|yaml|py|ts|tsx|js)`' "$PLAN_PATH"; then
         character="novel"
         confidence="high"
       fi
     fi
   fi

   # Rule 3: mechanical.
   if [ -z "$character" ]; then
     has_steps=0
     has_verif_bash=0
     file_count=0
     if grep -E -q '^## Steps' "$PLAN_PATH"; then has_steps=1; fi
     if grep -E -q '^bash [a-zA-Z0-9_/.-]+\.sh|^\s*bash [a-zA-Z0-9_/.-]+\.sh' "$PLAN_PATH"; then has_verif_bash=1; fi
     # File-touch count: extract from "Files Likely Touched" section + Steps file paths.
     file_count="$(grep -E -o '`[a-zA-Z0-9_/.-]+\.(sh|md|yml|yaml|py|ts|tsx|js)`' "$PLAN_PATH" | sort -u | wc -l | tr -d ' ')"
     if [ "$has_steps" -eq 1 ] && [ "$has_verif_bash" -eq 1 ] && [ "$file_count" -le 3 ]; then
       character="mechanical"
       confidence="high"
     fi
   fi

   # Rule 4: standard fallback.
   if [ -z "$character" ]; then
     character="standard"
     has_steps=0
     has_verif=0
     if grep -E -q '^## Steps' "$PLAN_PATH"; then has_steps=1; fi
     if grep -E -q '^## Verification' "$PLAN_PATH"; then has_verif=1; fi
     if [ "$has_steps" -eq 1 ] && [ "$has_verif" -eq 1 ]; then
       confidence="high"
     elif [ "$has_steps" -eq 1 ] || [ "$has_verif" -eq 1 ]; then
       confidence="medium"
     else
       confidence="low"
     fi
   fi

   printf 'character=%s\n' "$character"
   printf 'confidence=%s\n' "$confidence"
   exit 0
   ```

   The skeleton is a starting point; the executor MUST iterate the regex patterns + thresholds until `tools/verify/p01-classifier-ground-truth.sh` reports ≥85% agreement against the 40-entry corpus. The classifier MUST NOT call out to any other dispatch script and MUST NOT touch the network.

   `chmod +x scripts/dispatch/classify-task.sh` after writing.

3. **Author `tools/verify/p01-classifier-determinism.sh`.** Bash 3.2-compatible. AD-19 single-script-file shape. Behavior:

   - Path argument default: a sample plan from `tests/fixtures/m030-classifier-corpus/labels.yml` (e.g., the first `plan_path:` value). Override via `$1`.
   - Run `bash scripts/dispatch/classify-task.sh "$plan" > /tmp/p01-determinism-a.out 2>/dev/null` then `bash scripts/dispatch/classify-task.sh "$plan" > /tmp/p01-determinism-b.out 2>/dev/null` (separate statements; no compound chain).
   - `diff /tmp/p01-determinism-a.out /tmp/p01-determinism-b.out > /tmp/p01-determinism-diff.out 2>&1` — exit code 0 means byte-identical.
   - Confirm both stdout files contain exactly two lines, the first matching `^character=(mechanical|standard|novel)$` and the second matching `^confidence=(high|medium|low)$`.
   - On all checks pass, emit `SUMMARY: p01-classifier-determinism.sh pass=N fail=0` and exit 0; on any fail, exit 1 with the diagnostic + summary.
   - Cleanup: `rm -f /tmp/p01-determinism-*.out`.

4. **Author `tools/verify/p01-classifier-perf-and-network.sh`.** Bash 3.2-compatible. AD-19 single-script-file shape. Two gates in one script:

   - **Performance gate**: pick the first `plan_path` from `labels.yml`. Capture wall-clock around `bash scripts/dispatch/classify-task.sh "$plan"` using bash `SECONDS` (precision ~1s — too coarse for sub-100ms) OR `date +%s%N` capturing nanoseconds before/after. Compute elapsed in milliseconds (integer arithmetic via `$((end-start))/1000000`). Assert `elapsed_ms < 100`. (To absorb wall-clock noise, the script does the run 5 times and takes the minimum elapsed value — runtime variance from cold cache / disk read should fall out of the minimum.)
   - **Network-call gate**: grep `scripts/dispatch/classify-task.sh` body for any of the literals `curl`, `wget`, `nc -`, `bash scripts/dispatch/dispatch-interface.sh`, `bash scripts/dispatch/adapters/backend/`, `dispatch-task`, `await-completion`, `LLM`, `claude `, `anthropic`, `openai`, `gpt-`. ALL grep invocations MUST exit 1 (no match). Any match is a fail.
   - On all checks pass, emit `SUMMARY: p01-classifier-perf-and-network.sh pass=N fail=0` and exit 0; on any fail, exit 1.

   Note on `date +%s%N`: macOS `date` does not natively support `%N` — the script MUST detect and fall back. Use `python3 -c 'import time; print(int(time.monotonic_ns()))'` as a portable fallback (python3 is on every supported runtime per existing repo conventions; the optional-jq guard pattern from MEM001 applies — fall back to `date +%s` * 1000 if python3 absent, accepting ±1s precision and looping the run 100 times to amortize). The executor picks the precision strategy that fits the runtime; the gate's contract is "elapsed < 100ms" not "use this specific timer".

5. **Author `tools/verify/p01-classifier-ground-truth.sh`.** Bash 3.2-compatible. AD-19 single-script-file shape. Behavior:

   - Read `tests/fixtures/m030-classifier-corpus/labels.yml`.
   - For each `entries:` block, extract `plan_path` and the human-applied `character` value.
   - For each entry, run `bash scripts/dispatch/classify-task.sh "$plan_path" > /tmp/p01-gt-out.tmp 2>/dev/null`.
   - Parse the classifier's `character=...` line. Compare to the human label.
   - Track `agree` / `disagree` counts. Track per-class disagreements (helpful diagnostic when the gate fails).
   - Compute agreement: `agree * 100 / total`. Assert `agree >= ceil(0.85 * total)` (for total=40, threshold is 34).
   - On pass, emit a per-class breakdown summary (`mechanical: 18/20 agree`, `standard: 12/15 agree`, `novel: 4/5 agree`, total `34/40 = 85.0%`) plus `SUMMARY: p01-classifier-ground-truth.sh pass=1 fail=0` and exit 0.
   - On fail, emit the per-class breakdown + the list of disagreeing plans (`<plan_path> expected=<human_label> got=<classifier_label>`) + `SUMMARY: p01-classifier-ground-truth.sh pass=0 fail=1` and exit 1.

   YAML parsing: use `awk` to walk the `entries:` list. Each entry starts with a line matching `^  - plan_path:`; the `character:` line follows on the next non-comment line. No jq dependency. Bash 3.2 compatible.

6. **Iterate the classifier heuristics until ground-truth gate passes.** Run the four T02 verifiers in this order:

   ```bash
   bash tools/verify/p01-classifier-determinism.sh
   bash tools/verify/p01-classifier-perf-and-network.sh
   bash tools/verify/p01-classifier-ground-truth.sh
   ```

   If the ground-truth gate fails, the executor inspects the per-class disagreements, refines the heuristic table in `classify-task.sh`, and re-runs. The first-fail-retry / second-fail-pause discipline applies — but heuristic iteration is the expected loop here, not an exceptional state.

7. **Re-run T01's timeline verifier** to confirm Mode-B graduation. After committing `classify-task.sh`:

   ```bash
   bash tools/verify/p01-d-a4-timeline.sh
   ```

   Expected: `OK: labels.yml committed at <ts1> precedes classify-task.sh at <ts2>`, `SUMMARY: p01-d-a4-timeline.sh pass=1 fail=0`, exit 0. If this fails, the timeline ordering has been violated — STOP and escalate.

8. **Stage and commit.** Add `scripts/dispatch/classify-task.sh` + the four `tools/verify/p01-classifier-*.sh` verifiers and commit with `git commit -F <message-file>`. Recommended message: `M030/P01/T02: classifier script + determinism + perf/network + ground-truth verifiers`.

## Must-Haves

This task satisfies the phase truths:

- "`scripts/dispatch/classify-task.sh` exists and emits deterministic stdout" — gated by `tools/verify/p01-classifier-determinism.sh`.
- "The classifier runs in well under 100ms per plan and makes no network calls" — gated by `tools/verify/p01-classifier-perf-and-network.sh`.
- "Classifier ground-truth agreement holds at ≥85%" — gated by `tools/verify/p01-classifier-ground-truth.sh`.

This task also confirms the timeline truth from T01 graduates correctly:

- "D-A4/SC-10 timeline ordering holds" — `tools/verify/p01-d-a4-timeline.sh` re-runs in Mode B post-commit.

## Verification

```bash
bash tools/verify/p01-classifier-determinism.sh
bash tools/verify/p01-classifier-perf-and-network.sh
bash tools/verify/p01-classifier-ground-truth.sh
bash tools/verify/p01-d-a4-timeline.sh
```

Each verifier uses single-script-file shape per AD-19. The four are the SC-1 / FR-1-perf / SC-10 / D-A4 mechanical gates respectively.

## Inputs

### From Previous Tasks

- `tools/verify/p01-d-a4-timeline.sh` (from T01)
  - Key API: invoke as `bash tools/verify/p01-d-a4-timeline.sh`. Pre-T02-commit: Mode A passes by absence. Post-T02-commit: Mode B passes via git-log ordering. T02 re-runs this in Step 7 to confirm Mode B fires correctly.

### From Disk (Pre-existing)

- `tests/fixtures/m030-classifier-corpus/labels.yml` — 40 hand-labeled entries; the SC-10 ground-truth source.
- `tests/fixtures/m030-classifier-corpus/README.md` — FR-1 labeling rubric (the SSOT for the heuristic table T02 implements).
- `specs/032-adaptive-model-selection/spec.md` FR-1 (lines 627), FR-2 (line 628), SC-1 (line 649), SC-10 (line 661), CON-1 (line 677), CON-3 (line 679).
- [`.orchestrator/milestones/M030/M030-CONTEXT.md`](../../../../../milestones/M030/M030-CONTEXT.md) D-A9 (lines 71-72; output-stability convention).
- `scripts/dispatch/classify-complexity.sh` (existing pattern for a similar script — useful reference for the awk-based YAML walk + the `errors.sh` / `events.sh` library sourcing convention; T02's classify-task.sh does NOT need to source those libs unless the executor decides the structured-output discipline benefits from it; the SC-1 determinism gate forbids any timestamp / PID in stdout).
- `scripts/dispatch/select-model.sh` (existing routing pattern; reference for tier resolution shape — T02 does NOT modify or call this; it's documentation context for understanding where `classify-task.sh`'s output flows in P02).

## Constraints

- **CON-1 (no-LLM-on-hot-path)**: classifier MUST NOT invoke any LLM. The perf-and-network gate enforces this by grep.
- **CON-3 (symbolic-tier closure)**: classifier emits `character` (mechanical|standard|novel), NOT tier (`fast|balanced|smart`). Tier resolution lives in `templates/model-routing.yml` (T03's deliverable). Hardcoding tier names in `classify-task.sh` is forbidden.
- **D-A9 (output-stability)**: within a single run, output for the same PLAN.md is consistent. T02's v1 trivially satisfies this because input (f) is stubbed (no anomaly JSONL read). Future iterations that wire input (f) MUST snapshot at session start.
- **SC-1 determinism**: two runs against the same plan produce byte-identical stdout. No timestamps, no PIDs, no random ordering, no `find` ordering reliance.
- **SC-10 ≥85% agreement**: classifier's output `character` matches the human label for ≥34 of the 40 corpus entries. T02 iterates until this holds.
- **D-A4 timeline ordering**: the first commit of `scripts/dispatch/classify-task.sh` lands AFTER the existing `tests/fixtures/m030-classifier-corpus/labels.yml` first-commit (`9f99df2`). The timeline verifier from T01 mechanically asserts this.
- **Bash 3.2 compatibility**: no `declare -A`, no `mapfile`, no `readarray`. YAML parsing via `grep`/`sed`/`awk` only.
- **AD-19 single-script-file shape**: all verifier `Check:` invocations are `bash <single-path>.sh`. No compound chains in plan / verifier prose.

## Expected Output

- `scripts/dispatch/classify-task.sh` — heuristic classifier on disk, executable.
- `tools/verify/p01-classifier-determinism.sh` — SC-1 gate.
- `tools/verify/p01-classifier-perf-and-network.sh` — FR-1-perf + CON-1 gate.
- `tools/verify/p01-classifier-ground-truth.sh` — SC-10 ≥85% gate.
- All four T02 verifiers exit 0 on a clean run.
- T01's `p01-d-a4-timeline.sh` exits 0 in Mode B post-commit.

## Notes

Expected verifier output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p01-classifier-determinism.sh` → `OK: classifier output byte-identical across two runs`, `SUMMARY: p01-classifier-determinism.sh pass=N fail=0`, exit 0.
- `bash tools/verify/p01-classifier-perf-and-network.sh` → `OK: min elapsed <NN>ms < 100ms`, `OK: no network-call literals in classify-task.sh body`, `SUMMARY: p01-classifier-perf-and-network.sh pass=N fail=0`, exit 0.
- `bash tools/verify/p01-classifier-ground-truth.sh` → per-class breakdown (`mechanical: 18/20`, `standard: 12/15`, `novel: 4/5`, total `34/40 = 85.0%`), `SUMMARY: p01-classifier-ground-truth.sh pass=1 fail=0`, exit 0.

The 40-entry corpus has class distribution 20 mechanical / 15 standard / 5 novel. The SC-10 ≥85% threshold is 34 agreements; the per-class shape that hits 34 is roughly 18+/12+/4+ given the corpus's class-confidence distribution (26 high / 14 medium / 0 low). The novel class is structurally rare (5 entries) — agreement of 4/5 is a 1-miss tolerance; 5/5 is achievable if the classifier's "explore"-language regex is precise. The executor SHOULD aim for full agreement on novel before relaxing thresholds elsewhere, because shadow-mode P02 verdicts will lean on the novel class as the load-bearing safety class.

If after multiple heuristic iterations the ≥85% gate cannot be reached, the executor escalates to plan-phase rather than fudging the corpus or weakening the threshold — SC-10 is a spec constraint per D-A4 (arbiter-ruled), not a plan-phase question.

The wall-clock perf gate using `date +%s%N` will fail on macOS by default (BSD `date` doesn't honor `%N`). The executor's fallback strategy is documented in Step 4 — python3 monotonic_ns or a 100-iteration loop with second-precision `date +%s`. Either is acceptable; the gate's contract is "single classification < 100ms wall-clock", not the timer mechanism.

## State Context

- **Current State**: executing
- **Milestone**: M030
- **Phase**: P01
- **Task**: T02-classifier-script
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **CON-1 (no-LLM-on-hot-path)**: classifier MUST NOT invoke any LLM. The perf-and-network gate enforces this by grep.
- **CON-3 (symbolic-tier closure)**: classifier emits `character` (mechanical|standard|novel), NOT tier (`fast|balanced|smart`). Tier resolution lives in `templates/model-routing.yml` (T03's deliverable). Hardcoding tier names in `classify-task.sh` is forbidden.
- **D-A9 (output-stability)**: within a single run, output for the same PLAN.md is consistent. T02's v1 trivially satisfies this because input (f) is stubbed (no anomaly JSONL read). Future iterations that wire input (f) MUST snapshot at session start.
- **SC-1 determinism**: two runs against the same plan produce byte-identical stdout. No timestamps, no PIDs, no random ordering, no `find` ordering reliance.
- **SC-10 ≥85% agreement**: classifier's output `character` matches the human label for ≥34 of the 40 corpus entries. T02 iterates until this holds.
- **D-A4 timeline ordering**: the first commit of `scripts/dispatch/classify-task.sh` lands AFTER the existing `tests/fixtures/m030-classifier-corpus/labels.yml` first-commit (`9f99df2`). The timeline verifier from T01 mechanically asserts this.
- **Bash 3.2 compatibility**: no `declare -A`, no `mapfile`, no `readarray`. YAML parsing via `grep`/`sed`/`awk` only.
- **AD-19 single-script-file shape**: all verifier `Check:` invocations are `bash <single-path>.sh`. No compound chains in plan / verifier prose.

### Acceptance Criteria

This task satisfies the phase truths:

- "`scripts/dispatch/classify-task.sh` exists and emits deterministic stdout" — gated by `tools/verify/p01-classifier-determinism.sh`.
- "The classifier runs in well under 100ms per plan and makes no network calls" — gated by `tools/verify/p01-classifier-perf-and-network.sh`.
- "Classifier ground-truth agreement holds at ≥85%" — gated by `tools/verify/p01-classifier-ground-truth.sh`.

This task also confirms the timeline truth from T01 graduates correctly:

- "D-A4/SC-10 timeline ordering holds" — `tools/verify/p01-d-a4-timeline.sh` re-runs in Mode B post-commit.

### Files To Touch

- `scripts/dispatch/classify-task.sh` (create)
- `templates/model-routing.yml` (create)
- `references/model-routing.md` (create)
- `scripts/diagnostics/run-doctor.sh` (modify)
- `tools/verify/p01-d-a4-timeline.sh` (create)
- `tools/verify/p01-classifier-determinism.sh` (create)
- `tools/verify/p01-classifier-perf-and-network.sh` (create)
- `tools/verify/p01-classifier-ground-truth.sh` (create)
- `tools/verify/p01-routing-table-shape.sh` (create)
- `tools/verify/p01-doctor-config-check.sh` (create)
- `tools/verify/p01-model-routing-doc-shape.sh` (create)
- `tools/verify/p01-phase-suite.sh` (create)

<!-- The phase plan and task plan files themselves (this file +
     tasks/T0[1-4]-*-PLAN.md) are written by the planner, not by the
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