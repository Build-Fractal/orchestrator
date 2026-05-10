---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T02-dispatch-shadow-hook (Phase P02, Milestone M030)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~500 | required |
| Upstream Context | 981-1048 | ~1900 | required |
| Task Plan | 1050-1332 | ~6100 | required |
| State Context | 1334-1340 | ~100 | required |
| First-Turn Completeness | 1342-1392 | ~1000 | required |
| **Total** | | **~20400** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 666
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
hit_count: 666
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
hit_count: 666
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
hit_count: 666
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
hit_count: 588
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
hit_count: 588
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
hit_count: 588
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
hit_count: 666
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
hit_count: 588
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
hit_count: 588
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
hit_count: 588
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
hit_count: 666
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
hit_count: 666
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
hit_count: 666
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
hit_count: 588
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
hit_count: 588
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
hit_count: 588
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
hit_count: 666
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
hit_count: 588
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
hit_count: 588
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
hit_count: 666
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
hit_count: 666
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
hit_count: 588
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
hit_count: 588
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
hit_count: 588
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
hit_count: 243
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
hit_count: 243
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
hit_count: 243
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
hit_count: 242
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
hit_count: 242
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
hit_count: 232
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
     slug-bearing filenames (p02-*) so install-clobber risk is contained.
     Verifier authorship is co-scheduled with the artifact it gates, in
     the SAME task, per Plan-Time Discipline rule 2 (verifier-availability
     cross-check). No cross-task verifier dependencies. T01 deliberately
     ships the SC-11 byte-equality verifier + golden fixture BEFORE T02
     touches dispatch-interface.sh — this is the same discipline P01 used
     for the D-A4 timeline graduation: the additive-schema gate exists
     and gates the diff at the moment dispatch-interface.sh is amended. -->

### Truths

- A pre-M030 `dispatch_usage` JSONL fixture (`tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl`) exists at version-control with at minimum 5 records spanning happy-path, pricing-warning, and cost-null degradation shapes. The fixture's first-commit timestamp predates `dispatch-interface.sh`'s P02 amendment commit (mechanical proxy for additive-only-schema enforcement). (CON-2/FR-19/SC-11 foundation.)
  - Check: `bash tools/verify/p02-fixture-shape.sh`

- SC-11 byte-equality holds: when `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` is round-tripped through `scripts/dispatch/dispatch-interface.sh`'s emit path under `M030_SHADOW_MODE=0` (or unset), the emitter output for an equivalent fixture invocation is byte-identical to the recorded fixture line for the same `(unitId, backend, payload_bytes, model)` tuple. The verifier stages a fixture invocation, captures the emitter's stdout/log line, and `diff`s against the corresponding fixture record byte-for-byte — empty diff is the pass condition. New fields (`model_routed`, `model_used`, `partial_flip_active`, `withheld_classes`) MUST NOT appear in the output when shadow mode is off; when shadow mode is on, they appear ONLY as appended fields after the existing field set. (CON-2/FR-19/SC-11.)
  - Check: `bash tools/verify/p02-additive-schema.sh`

<dispatch-volatile>

## Upstream Context


### P01 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M030"
milestone: "M030"
provides:
  - "tools/verify/p01-d-a4-timeline.sh,scripts/dispatch/classify-task.sh,tools/verify/p01-classifier-determinism.sh,tools/verify/p01-classifier-perf-and-network.sh,tools/verify/p01-classifier-ground-truth.sh,templates/model-routing.yml SSOT (routing+resolution+cost_rates) + references/model-routing.md operator docs (5 sections,concrete stability-metric numerics 0.10/N=20/50) + tools/verify/p01-routing-table-shape.sh + tools/verify/p01-model-routing-doc-shape.sh,scripts/diagnostics/run-doctor.sh --config-check extension wired to tools/verify/p01-routing-table-shape.sh (file:line emission per FR-17 + SC-9); tools/verify/p01-doctor-config-check.sh exercises both well-formed-pass and malformed-fail paths; tools/verify/p01-phase-suite.sh straight-line aggregator over all 7 P01 sub-gates"
requires:
  - "P00"
affects:
  - "P02"
key_files:
  - "tools/verify/p01-d-a4-timeline.sh,scripts/dispatch/classify-task.sh,tools/verify/p01-classifier-determinism.sh,tools/verify/p01-classifier-perf-and-network.sh,tools/verify/p01-classifier-ground-truth.sh,templates/model-routing.yml,references/model-routing.md,tools/verify/p01-routing-table-shape.sh,tools/verify/p01-model-routing-doc-shape.sh,scripts/diagnostics/run-doctor.sh,tools/verify/p01-doctor-config-check.sh,tools/verify/p01-phase-suite.sh,CLAUDE.md,AGENTS.md"
key_decisions:
  - "D-A4 timeline-graduation verifier authored before classify-task.sh ships -- automatic mode swap on T02 commit,file-count signal scoped to deliverable sections; body-line cap as secondary mech-vs-std distinguisher; two-tier novel lexicon with verdict exclusion; bash -c <cmd> accepted as verifier-bash invocation,CON-3-closure-invariant-model-IDs-only-in-resolution; D-A6-cost_rates-SSOT; classifier-confidence-stability-metric-pinned-0.10-N=20-50-dispatches; CC-only-launch-other-runtimes-inherit,FR-17-file-line-diagnostic-emission-via-grep-n-lookup-during-closure-walk; doctor-config-check-additive-not-replacement-existing-doctor-pipeline-preserved; phase-suite-straight-line-no-loops-AD-19-shape-discipline-mirrored-from-P00"
patterns_established:
  - "graduation-verifier-pattern (two-mode pre/post-graduation gate keyed off filesystem state); single-pipeline command-substitution exemption under AD-19,two-tier-lexicon-for-symbolic-classifiers; body-line-proxy-for-narrative-vs-transcription; comment-stripped-grep-for-self-referential-gates; bash-3.2-only-classifier-no-jq-no-network,declarative-routing-table-with-symbolic-tier-indirection; awk-section-walker-for-YAML-closure-check-no-jq-dependency; doc-shape-verifier-grep-asserts-concrete-numerics-as-load-bearing-downstream-contract,config-check-flag-as-thin-wrapper-around-shape-verifier-with-file-line-passthrough; verifier-stages-malformed-fixture-in-tmp-with-trap-cleanup; phase-suite-aggregator-pattern-extends-from-5-to-7-gates-without-shape-change"
drill_down_paths:
  - "[.orchestrator/milestones/M030/phases/P01/tasks/T01-SUMMARY.md](../../../../../milestones/M030/phases/P01/tasks/T01-SUMMARY.md), [.orchestrator/milestones/M030/phases/P01/tasks/T02-SUMMARY.md](../../../../../milestones/M030/phases/P01/tasks/T02-SUMMARY.md), [.orchestrator/milestones/M030/phases/P01/tasks/T03-SUMMARY.md](../../../../../milestones/M030/phases/P01/tasks/T03-SUMMARY.md), [.orchestrator/milestones/M030/phases/P01/tasks/T04-SUMMARY.md](../../../../../milestones/M030/phases/P01/tasks/T04-SUMMARY.md)"
duration: "240m"
verification_result: "pass"
completed_at: "2026-04-30T13:19:42Z"
observability_surfaces:
  - "none"
---

## What was built

P01 ships the M030 classifier surface and routing-table SSOT — the load-bearing infrastructure for adaptive model selection. Four tasks, strict linear chain T01 → T02 → T03 → T04, all green:

- **T01** authored `tools/verify/p01-d-a4-timeline.sh` BEFORE `classify-task.sh` existed, satisfying the D-A4 / SC-10 mechanical-independence constraint by construction. The verifier auto-graduates from Mode A (absence-check) to Mode B (commit-ordering check) the moment T02 lands the classifier.
- **T02** delivered `scripts/dispatch/classify-task.sh` — Bash 3.2-safe, zero network calls, 50ms wall-clock, 90% (36/40) ground-truth agreement against the P00 fixture corpus (mechanical 19/20, standard 12/15, novel 5/5). Well above the 85% gate. FR-2 inputs (e) phase-position and (f) anomaly-JSONL signal are stubbed per plan; (a)-(d) reach 90% on their own.
- **T03** shipped `templates/model-routing.yml` (routing + resolution + cost_rates SSOT) and `references/model-routing.md` (operator docs). Classifier-confidence stability-metric numerics pinned to concrete values: variance threshold 0.10, rolling window N=20, per-class coverage floor 50 dispatches. CON-3 closure honored — model IDs appear ONLY in `resolution:`.
- **T04** extended `scripts/diagnostics/run-doctor.sh` with `--config-check` (file:line emission per FR-17 / SC-9) and authored `tools/verify/p01-phase-suite.sh` — straight-line aggregator over all 7 P01 sub-gates, modeled on `p00-phase-suite.sh`.

## Verification

Phase-suite green: `pass=7 fail=0` across d-a4-timeline (Mode B), classifier-determinism (4/0), classifier-perf-and-network (2/0), classifier-ground-truth (1/0 @ 90%), routing-table-shape (8/0), doctor-config-check (4/0), model-routing-doc-shape (8/0). Tier-1 must-haves: 8 truths + 34 artifacts + 8 key-links all PASS. Tier-3 behavioral: FR-1, FR-2 (with documented stubs), FR-3, FR-17, D-A1, D-A4, D-A6, CON-3 all satisfied.

## Patterns established

- **Graduation-verifier pattern**: two-mode pre/post-graduation gate keyed off filesystem state — Mode A asserts artifact absence; Mode B asserts git-commit ordering once the artifact lands. Reusable for any "fixture must precede consumer" constraint.
- **Two-tier lexicon for symbolic classifiers**: body-line count as narrative-vs-transcription proxy; verdict-exclusion lexicon for novel-class detection.
- **Awk section-walker for YAML closure-check**: no `jq` dependency; portable across runtimes.
- **Doc-shape verifier asserts concrete numerics** as load-bearing downstream contract — pins variance/window/coverage values into the doc itself so P02 cannot drift.
- **Phase-suite aggregator extension**: P00's 5-gate suite extends cleanly to P01's 7 gates with no shape change — straight-line bash, no loops, AD-19 compliant.

## Cross-cutting concerns honored

- **CON-3 (symbolic-tier closure)**: classifier emits symbolic class names only; routing table maps character → tier symbolically; concrete model IDs confined to `resolution:` block. Verified by `p01-routing-table-shape.sh`.
- **D-A4 / SC-10 (pre-implementation independence)**: P00 fixture corpus committed at ts=1777523592; classify-task.sh committed at ts=1777550632. Mode B graduation verifier asserts ordering on every run.
- **CC-only launch posture**: routing-table resolution table has Codex CLI / Cursor entries set to `inherit` — no per-runtime model-ID branching beyond CC.

## Hand-off to P02

P02 will consume P01's deliverables: classifier interface (`classify-task.sh`), routing table (`templates/model-routing.yml`), pinned stability-metric numerics (0.10 / N=20 / 50). The P02 plan-phase MUST grep for hardcoded model IDs in its diff (CON-3 enforcement) and verify SC-11 byte-equality on pre-M030 fixtures (additive-only JSONL schema).

## Open notes for downstream

- FR-2 inputs (e) phase-position and (f) anomaly-JSONL stubbed in classify-task.sh; if future tuning needs to push past 90%, wire those inputs.
- 4 ground-truth disagreements (M004/P02/T05, M013/P02/T01, M019/P01/T01, M026/P03/T02) sit near body-line / file-count threshold boundaries; documented in T02-SUMMARY.md.
- `roadmap_sync=SYNC:OK`; no downstream phases were invalidated by P01 close.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M030"
name: "dispatch-interface.sh shadow hook + classifier integration + CON-3 closure + append-only"
depends_on: ["T01"]
---

## Prerequisites

- `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` exists with 5+ canonical pre-M030 records (T01 close).
- `tests/fixtures/m030-p02/round-trip-stage/` exists with `phases/P01/tasks/T01-stage-PLAN.md`, `phases/P01/tasks/T01-stage-PAYLOAD.md`, `intensity-metadata.txt` (T01 close).
- `tools/verify/p02-fixture-shape.sh` exists and exits 0 (T01 close).
- `tools/verify/p02-additive-schema.sh` exists and exits 0 against the pre-amendment `dispatch-interface.sh` (T01 close).
- `scripts/dispatch/classify-task.sh` exists and emits `character=<mechanical|standard|novel>` + `confidence=<high|medium|low>` to stdout (P01/T02 close).
- `templates/model-routing.yml` exists with `routing:` (3 characters × 3 runtimes), `resolution:` (3 tiers × 3 runtimes), `cost_rates:` (3 tiers) sections (P01/T03 close).
- `references/model-routing.md` exists with `## Classifier-Confidence Stability Metric` section pinning numerics 0.10 / N=20 / 50 (P01/T03 close).
- `scripts/dispatch/dispatch-interface.sh` exists with `_di_emit_dispatch_usage` body at lines 185-311 (pre-P02 form).

Plan-time prerequisite-existence verification: every path above is asserted by T01's deliverables (T01 closes only when both verifiers exit 0); P01 deliverables are present per [`.orchestrator/milestones/M030/phases/P01/P01-SUMMARY.md`](../../../../../milestones/M030/phases/P01/P01-SUMMARY.md) `key_files:`. The pre-P02 `dispatch-interface.sh` shape was inspected during plan-authoring (head -311 reads cleanly; lines 283 + 298 contain the canonical `printf` templates).

## Description

T02 is the high-risk core amendment. Three deliverables that ship as a single coherent change:

1. **Amend `scripts/dispatch/dispatch-interface.sh`** — extend `_di_emit_dispatch_usage` so that when `M030_SHADOW_MODE=1` AND `CLAUDECODE=1`, the classifier runs and the routing-table choice is recorded as additive fields appended after `timestamp` (the current last field). When either env var is unset/0, the new code path is bypassed and the emitter behaves byte-identically to the pre-P02 form.

2. **`tools/verify/p02-shadow-emit.sh`** — gates the shadow-on path: `model_routed`/`model_used`/`partial_flip_active`/`withheld_classes` appear in the JSONL record when `M030_SHADOW_MODE=1` AND `CLAUDECODE=1`; do NOT appear when either env var is off (CC-only short-circuit + shadow-off short-circuit).

3. **`tools/verify/p02-con3-closure.sh`** — gates that no hardcoded model IDs appear in the diff that T02 introduces. Greps the post-amendment file for the closed set of provider model-ID patterns and asserts zero NEW occurrences (relative to the pre-amendment file).

4. **`tools/verify/p02-append-only.sh`** — gates that the shadow write path is append-only. Stages a fixture log file with N pre-existing records, runs an `M030_SHADOW_MODE=1` dispatch, and asserts: (a) the first N lines are byte-identical before and after; (b) exactly one new line was appended; (c) the file's inode is unchanged.

T02 also re-runs T01's `p02-additive-schema.sh` against the amended emitter to confirm that with shadow mode off, the byte-equality contract still holds.

### dispatch-interface.sh amendment shape (load-bearing detail)

The amendment is surgical. Locate `_di_emit_dispatch_usage` (line 185) and the two `printf` templates (lines 283 + 298). The shadow path is a pre-emit branch that computes two new values before the `printf` call:

```bash
# --- M030/P02/T02: shadow-mode classifier + routing-table fields ---
# Gated by BOTH env vars: M030_SHADOW_MODE=1 (operator flag) AND
# CLAUDECODE=1 (CC-only launch posture per CON-3 + spec edge case
# "Runtime that does not support model selection"). Codex CLI / Cursor
# fall through to the pre-P02 emit (no new fields).
shadow_routed=""
shadow_used=""
shadow_partial=""
shadow_withheld=""
if [ "${M030_SHADOW_MODE:-0}" = "1" ] && [ "${CLAUDECODE:-0}" = "1" ]; then
  # 1. Classify the task plan (P01/T02 deliverable; FR-1 + FR-2).
  classifier_out="$(bash "$_DI_PROJECT_ROOT/scripts/dispatch/classify-task.sh" "$TASK_PLAN" 2>/dev/null)"
  shadow_character="$(printf '%s\n' "$classifier_out" | grep -E '^character=' | head -n 1 | sed 's/^character=//')"
  # 2. Resolve symbolic tier via templates/model-routing.yml routing: block.
  #    Awk section-walker (P01 pattern; no jq dependency).
  shadow_routed="$(awk -v ch="$shadow_character" '
    BEGIN { in_routing = 0; in_class = 0 }
    /^routing:/                       { in_routing = 1; next }
    in_routing && /^[a-z_]+:$/        { in_class = ($1 == ch ":") ? 1 : 0; next }
    in_routing && in_class && /claude-code:/ {
      val = $2; gsub(/[",]/, "", val); print val; exit
    }
    /^resolution:/                    { exit }
  ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
  # 3. Resolve symbolic tier -> runtime model ID via resolution: block.
  #    Same awk pattern, scoped to resolution: section.
  shadow_used="$(awk -v tier="$shadow_routed" '
    BEGIN { in_resolution = 0; in_tier = 0 }
    /^resolution:/                    { in_resolution = 1; next }
    in_resolution && /^[a-z_]+:$/     { in_tier = ($1 == tier ":") ? 1 : 0; next }
    in_resolution && in_tier && /claude-code:/ {
      val = $2; gsub(/[",]/, "", val); print val; exit
    }
    /^cost_rates:/                    { exit }
  ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
  # 4. P03/P04 placeholders — emitted as no-op-empty in P02.
  shadow_partial="false"
  shadow_withheld=""
fi
```

The `printf` templates at lines 283 + 298 are amended to append four new fields after `timestamp`:

```text
,"model_routed":"%s","model_used":"%s","partial_flip_active":%s,"withheld_classes":"%s"
```

with the trailing `\n` preserved at end. The `partial_flip_active` value is a JSON boolean literal (`false` / `true`, no surrounding quotes — that's why the format specifier is `%s` not `"%s"`). When shadow mode is off, the four shell variables are empty strings; the format string emits `,"model_routed":"","model_used":"","partial_flip_active":,"withheld_classes":""` which is INVALID JSON.

To preserve the additive-only-when-shadow-on invariant, the printf format string is itself selected at emit time:

```bash
if [ "${M030_SHADOW_MODE:-0}" = "1" ] && [ "${CLAUDECODE:-0}" = "1" ]; then
  # Shadow-on emit: pre-M030 fields + 4 P02 additive fields.
  printf '{"record_type":"dispatch_usage",...,"timestamp":"%s","model_routed":"%s","model_used":"%s","partial_flip_active":%s,"withheld_classes":"%s"}\n' \
    ...existing_args... "$ts" "$shadow_routed" "$shadow_used" "$shadow_partial" "$shadow_withheld" \
    >> "$log_file" 2>/dev/null || ...
else
  # Shadow-off emit: byte-identical to pre-P02 (preserves SC-11).
  printf '{"record_type":"dispatch_usage",...,"timestamp":"%s"}\n' \
    ...existing_args... "$ts" \
    >> "$log_file" 2>/dev/null || ...
fi
```

Two parallel branches per emit-side (happy-path AND degradation path → 4 total `printf` invocations after the amendment). This is verbose but preserves SC-11 byte-equality for the shadow-off path mechanically: when neither env var is set, the original `printf` template runs unchanged.

### CC-only conditional discipline

The shadow path requires `CLAUDECODE=1` AND `M030_SHADOW_MODE=1`. Why both:

- `CLAUDECODE=1` is the runtime-detection signal Claude Code sets in dispatch contexts. Codex CLI does not set it; Cursor does not set it. This is the load-bearing CON-3 + edge-case "Runtime that does not support model selection" gate — only on Claude Code do we record the shadow fields.
- `M030_SHADOW_MODE=1` is the operator-controlled flag. It can be set on a per-session basis to opt into shadow recording without modifying any config file.

When `CLAUDECODE` is unset (Codex CLI, Cursor, non-orchestrator-direct invocations), the shadow branch is bypassed. The record is byte-identical to the pre-P02 shape. SC-11 byte-equality holds for these runtimes regardless of `M030_SHADOW_MODE`.

### CON-3 closure: zero hardcoded model IDs

The amendment's awk extraction reads `templates/model-routing.yml` at every dispatch (acceptable per FR-1 latency budget — awk on a ~100-line YAML is sub-millisecond). The result: dispatch-interface.sh contains no literal `claude-haiku-*`, `claude-sonnet-*`, `claude-opus-*`, `gpt-*`, `o1-*`, `o3-*`, or `gemini-*` strings. `p02-con3-closure.sh` greps for these patterns in the diff and asserts zero new occurrences.

The reference comment in the amendment block names `templates/model-routing.yml` so future readers see the indirection target without needing to chase the awk template.

### Append-only discipline (CON-6)

The new code path uses the same `>> "$log_file"` redirection as the existing emitter (line 290, 305). No `mv`, no `cp`, no temp-file-and-swap. The verifier (`p02-append-only.sh`) confirms via `stat` inode comparison that the file is unchanged in identity across the dispatch invocation; only its byte length grows.

This locks in the discipline P04 will inherit: escalation will produce NEW records with new timestamps, never rewrite prior records. P04 cannot break this without a new `mv`/`cp`/`>` (truncating) usage that would be caught by the same verifier.

## Steps

1. **Confirm T01 deliverables are on disk and green.** Run:

   ```bash
   bash tools/verify/p02-fixture-shape.sh
   bash tools/verify/p02-additive-schema.sh
   ```

   Expected: both exit 0. If either fails, T01 must be re-opened.

2. **Snapshot the pre-amendment `dispatch-interface.sh` for the CON-3 diff baseline.** The CON-3 verifier compares the post-amendment file against `git show HEAD:scripts/dispatch/dispatch-interface.sh`; the snapshot is whatever HEAD points at when T02 begins. No explicit snapshot file is needed — the verifier reads HEAD via `git show`.

3. **Amend `scripts/dispatch/dispatch-interface.sh`** per the shape described in the Description. Concretely:

   - Insert the shadow-mode classifier-and-resolution block after the existing `mkdir -p "$log_dir"` call (around line 273) and before the `if [ -n "$cost_usd" ] && [ -z "$warning" ]; then` happy-path branch (line 279). The new block is the four-step bash + awk routine described above.
   - Replace the single happy-path `printf` (line 283) with an `if/else` that selects the shadow-on vs shadow-off format string. The shadow-on format string adds four trailing fields (`,"model_routed":"%s","model_used":"%s","partial_flip_active":%s,"withheld_classes":"%s"`) before the closing `}`; the shadow-off format string is byte-identical to the pre-amendment form.
   - Same treatment for the degradation `printf` (line 298).
   - Both branches preserve the existing `>> "$log_file" 2>/dev/null || { ...; return 0; }` failure-handling shape.

4. **Re-run T01's `p02-additive-schema.sh` against the amended emitter.** The verifier runs with shadow off (`unset CLAUDECODE`, `unset M030_SHADOW_MODE`); the round-trip diff must come back empty.

   ```bash
   bash tools/verify/p02-additive-schema.sh
   ```

   Expected: exits 0, `SUMMARY: p02-additive-schema.sh pass=N fail=0`. If it fails, the shadow-off `printf` branch's format string differs from the pre-P02 form — re-author the format string verbatim from `git show HEAD:scripts/dispatch/dispatch-interface.sh:283` (or :298 for the degradation path). The format string is the byte-equality SSOT; even a re-ordering of escape sequences breaks SC-11.

5. **Author `tools/verify/p02-shadow-emit.sh`.** Bash 3.2-compatible. AD-19 single-script-file shape. Exercises three scenarios:

   - **Scenario A — shadow on, CC on**: `export M030_SHADOW_MODE=1; export CLAUDECODE=1`. Stage a fixture log file (rm + touch). Invoke `bash scripts/dispatch/dispatch-interface.sh --task-plan <stage>/T01-stage-PLAN.md --payload <stage>/T01-stage-PAYLOAD.md --intensity-metadata <stage>/intensity-metadata.txt --backend stub`. Read the appended JSONL line. Assert `grep -q '"model_routed"' <line>` AND `grep -q '"model_used"' <line>` AND `grep -q '"partial_flip_active"' <line>` AND `grep -q '"withheld_classes"' <line>`. Also assert the line is well-formed JSON (`grep -q '^{.*}$' <line>`).
   - **Scenario B — shadow off, CC on**: `unset M030_SHADOW_MODE; export CLAUDECODE=1`. Same staging + invocation. Assert NONE of the four shadow tokens appear in the appended line.
   - **Scenario C — shadow on, CC off (Codex CLI / Cursor simulation)**: `export M030_SHADOW_MODE=1; unset CLAUDECODE`. Same staging + invocation. Assert NONE of the four shadow tokens appear in the appended line (CC-only short-circuit).

   Each scenario uses a fresh log file at `<round-trip-stage>/execution-log.jsonl` (rm + touch before, rm after). Per-scenario pass/fail accumulators; final `SUMMARY: p02-shadow-emit.sh pass=N fail=M`. Exit 0 iff `fail == 0`.

6. **Author `tools/verify/p02-con3-closure.sh`.** Bash 3.2-compatible. Greps both the pre-amendment HEAD version and the working-tree version of `scripts/dispatch/dispatch-interface.sh` for the closed set of provider model-ID patterns:

   - `claude-haiku-`
   - `claude-sonnet-`
   - `claude-opus-`
   - `gpt-`
   - `o1-`
   - `o3-`
   - `gemini-`

   For each pattern, count occurrences in HEAD version: `git show HEAD:scripts/dispatch/dispatch-interface.sh | grep -c -E '<pattern>' > /tmp/p02-con3-head-<n>.txt`. Count in working tree: `grep -c -E '<pattern>' scripts/dispatch/dispatch-interface.sh > /tmp/p02-con3-wt-<n>.txt`. Read both counts; assert working-tree count is <= HEAD count (i.e., T02's amendment did not INTRODUCE any provider model-ID literal). Cleanup: `rm -f /tmp/p02-con3-*.txt`.

   Per-pattern pass/fail; final `SUMMARY: p02-con3-closure.sh pass=N fail=M`. Exit 0 iff `fail == 0`.

7. **Author `tools/verify/p02-append-only.sh`.** Bash 3.2-compatible. Stages a fixture log file with 5 pre-existing records (cat the T01 fixture into a fresh log), captures the file's inode via `stat -f '%i' <log> > /tmp/p02-inode-pre.txt` (macOS) or `stat -c '%i' <log> > /tmp/p02-inode-pre.txt` (GNU — use `uname -s` to dispatch), captures the first-N-lines content via `head -5 <log> > /tmp/p02-pre-content.txt`, captures line count via `wc -l < <log> > /tmp/p02-pre-lines.txt`. Then `export M030_SHADOW_MODE=1; export CLAUDECODE=1` and invokes `dispatch-interface.sh`. Re-captures inode + first-5-lines + line-count. Assertions:

   - Inode pre == post (file identity preserved — `diff /tmp/p02-inode-pre.txt /tmp/p02-inode-post.txt` exits 0).
   - First-5-lines pre == post (existing records bit-identical — `diff /tmp/p02-pre-content.txt /tmp/p02-post-content.txt` exits 0).
   - Post-line-count == pre-line-count + 1 (exactly one new record appended).

   Cleanup: `rm -f /tmp/p02-{inode,pre-content,post-content,pre-lines,post-lines}-*.txt`. Final `SUMMARY: p02-append-only.sh pass=N fail=M`. Exit 0 iff `fail == 0`.

8. **Run all four T02 verifiers as a self-check:**

   ```bash
   bash tools/verify/p02-additive-schema.sh
   bash tools/verify/p02-shadow-emit.sh
   bash tools/verify/p02-con3-closure.sh
   bash tools/verify/p02-append-only.sh
   ```

   Expected: all four exit 0. If `p02-additive-schema.sh` fails, the shadow-off `printf` branch's format string differs from pre-amendment — fix Step 3. If `p02-shadow-emit.sh` Scenario A fails (shadow tokens missing under shadow-on), the format-string selection logic in Step 3 mis-branched — fix the env-var check. If Scenario B/C fails (shadow tokens leaking under shadow-off / CC-off), the gate is wrong — both env vars must be set for the shadow branch. If `p02-con3-closure.sh` fails, a literal model ID slipped into the amendment — replace with the awk-resolution pattern. If `p02-append-only.sh` fails on inode check, a `mv`/`cp` snuck in; on first-5-lines check, the emitter is rewriting prior records (CON-6 violation).

9. **Stage and commit.** Stage `scripts/dispatch/dispatch-interface.sh`, `tools/verify/p02-shadow-emit.sh`, `tools/verify/p02-con3-closure.sh`, `tools/verify/p02-append-only.sh`. Author commit message file via Write to `/tmp/p02-t02-commit-msg.txt`; commit with `git commit -F /tmp/p02-t02-commit-msg.txt`. Recommended message subject: `M030/P02/T02: dispatch-interface shadow hook + classifier + CON-3 closure + append-only`.

## Must-Haves

This task satisfies the phase truths:

- "`scripts/dispatch/dispatch-interface.sh` invokes the P01 classifier on every dispatch when `M030_SHADOW_MODE=1` AND `CLAUDECODE=1`..." — gated by `tools/verify/p02-shadow-emit.sh`.
- "The shadow-mode amendment to `dispatch-interface.sh` contains zero hardcoded model IDs..." — gated by `tools/verify/p02-con3-closure.sh`.
- "The shadow JSONL write path is append-only..." — gated by `tools/verify/p02-append-only.sh`.
- "SC-11 byte-equality holds..." — re-asserted by `tools/verify/p02-additive-schema.sh` against the amended emitter.

## Verification

```bash
bash tools/verify/p02-additive-schema.sh
bash tools/verify/p02-shadow-emit.sh
bash tools/verify/p02-con3-closure.sh
bash tools/verify/p02-append-only.sh
```

Each verifier uses single-script-file shape per AD-19. All four must exit 0 before T02 closes.

## Inputs

### From Previous Tasks

- `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` (from T01)
  - Key API: 5+ canonical pre-M030 `dispatch_usage` JSONL records — the byte-equality golden file.
- `tests/fixtures/m030-p02/round-trip-stage/` (from T01)
  - Key API: `phases/P01/tasks/T01-stage-PLAN.md` + `phases/P01/tasks/T01-stage-PAYLOAD.md` + `intensity-metadata.txt` — fixture inputs for round-trip dispatch invocations.
- `tools/verify/p02-additive-schema.sh` (from T01)
  - Key API: `bash <path>` exits 0 with `SUMMARY: p02-additive-schema.sh pass=N fail=0` when shadow off + CC unset, byte-equality holds against the golden fixture.
- `tools/verify/p02-fixture-shape.sh` (from T01)
  - Key API: `bash <path>` exits 0 confirming fixture well-formedness.

### From Disk (Pre-existing)

- `scripts/dispatch/dispatch-interface.sh` — pre-P02 emitter at lines 185-311. T02 amends `_di_emit_dispatch_usage` body.
  - Key API: `_di_emit_dispatch_usage [warning_override]` writes one `dispatch_usage` record to `$log_file` per invocation. Function-internal access to `$TASK_PLAN`, `$PAYLOAD`, `$INTENSITY_METADATA`, `$BACKEND`, `$UNIT_ID`, `$MILESTONE_ID`, `$PHASE_ID`, `$TASK_ID`, `$ORCH_ROOT`, `$_DI_PROJECT_ROOT` (set in the parent script body before the function is invoked).
- `scripts/dispatch/classify-task.sh` — P01 classifier.
  - Key API: `bash scripts/dispatch/classify-task.sh <plan-path>` writes two stdout lines: `character=<mechanical|standard|novel>` and `confidence=<high|medium|low>`. Bash 3.2-safe, no network, <100ms wall-clock. Exit 0 on success; exit 1 on missing plan-path.
- `templates/model-routing.yml` — P01 routing-table SSOT.
  - Key API: YAML file with three top-level sections. Closure invariant: every symbolic-tier reference in `routing:` resolves to an entry in `resolution:`. Per-runtime: `claude-code` always resolves to a concrete model ID; `codex-cli` and `cursor` resolve to literal `inherit`.
- `references/model-routing.md` — operator docs (T03 will consume the stability-metric section, not T02).
- `scripts/dispatch/adapters/backend/stub.sh` — minimal adapter for round-trip harness invocations.

## Constraints

- **AD-19 single-script-file shape**: all verifier `Check:` invocations are `bash <single-path>.sh`. The amendment to `dispatch-interface.sh` is internal code; AD-19 governs the verifier-invocation shape, not the script's internal structure.
- **MEM004 emitter-internal carve-out**: `_di_emit_dispatch_usage` already declares (line 184) that pipes / `awk` / `$()` are permitted in its body as a dispatch-internal carve-out. T02's amendment extends that carve-out — the new awk extraction blocks are body-internal and are NOT subject to AD-19's outer-invocation shape rules.
- **AP-009 compound-chain-gt2 (verifier shape)**: the four T02 verifiers MUST avoid `result=$(cmd | grep | head)` patterns. Use tmp-file intermediates: `cmd > /tmp/<f>; grep ... < /tmp/<f> > /tmp/<g>; head -1 < /tmp/<g>`. Each `Bash` tool invocation in `auto-loop` runs through the harness shape-guard; `bash <verifier>.sh` is the safe invocation shape.
- **CON-2/FR-19/SC-11 (additive-only schema)**: the shadow-off `printf` format strings MUST be byte-identical to the pre-amendment form. T01's golden fixture is the SSOT; if Step 4's re-run of `p02-additive-schema.sh` fails, the format string is wrong.
- **CON-3 (symbolic-tier closure)**: zero literal provider model IDs in `dispatch-interface.sh`. The awk extraction reads `templates/model-routing.yml` at every dispatch. Verified by `p02-con3-closure.sh` (HEAD-vs-working-tree count comparison per pattern).
- **CON-6 (append-only shadow corpus)**: the new code path uses `>> "$log_file"` only. No `mv`, no `cp`, no truncating `>`, no temp-file-and-swap. Verified by `p02-append-only.sh` (inode + first-N-lines + line-count comparison).
- **CC-only launch posture**: shadow path requires `CLAUDECODE=1` AND `M030_SHADOW_MODE=1`. Codex CLI / Cursor short-circuit to the pre-P02 emit. Verified by `p02-shadow-emit.sh` Scenario C.
- **Bash 3.2 compatibility**: no `declare -A`, no `mapfile`, no `readarray`. The awk blocks are POSIX awk, not gawk-extended.
- **Plan-Time Discipline rule 5 (real-DB verification)**: T02 does NOT introduce SQL — N/A.

## Expected Output

- `scripts/dispatch/dispatch-interface.sh` — amended `_di_emit_dispatch_usage` body with shadow-mode classifier hook + four additive fields, gated by `M030_SHADOW_MODE=1` AND `CLAUDECODE=1`. Shadow-off `printf` branch byte-identical to pre-amendment.
- `tools/verify/p02-shadow-emit.sh` — green: shadow tokens present under shadow-on + CC-on, absent under shadow-off OR CC-off.
- `tools/verify/p02-con3-closure.sh` — green: zero provider-model-ID literals introduced by the amendment.
- `tools/verify/p02-append-only.sh` — green: log file inode + prior records preserved across shadow-on dispatch.
- `bash tools/verify/p02-additive-schema.sh` exits 0 (re-confirmed against amended emitter).
- `bash tools/verify/p02-shadow-emit.sh` exits 0 with `SUMMARY: p02-shadow-emit.sh pass=N fail=0`.
- `bash tools/verify/p02-con3-closure.sh` exits 0 with `SUMMARY: p02-con3-closure.sh pass=N fail=0`.
- `bash tools/verify/p02-append-only.sh` exits 0 with `SUMMARY: p02-append-only.sh pass=N fail=0`.

## Notes

Expected verifier output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p02-shadow-emit.sh` → 3 scenarios pass (12 token-presence/absence checks total); `SUMMARY: p02-shadow-emit.sh pass=12 fail=0`, exit 0.
- `bash tools/verify/p02-con3-closure.sh` → 7 patterns checked, all `working-tree count <= HEAD count`; `SUMMARY: p02-con3-closure.sh pass=7 fail=0`, exit 0.
- `bash tools/verify/p02-append-only.sh` → 3 invariants pass (inode unchanged, first-5-lines unchanged, line-count delta = +1); `SUMMARY: p02-append-only.sh pass=3 fail=0`, exit 0.

The amendment's `awk` extraction blocks are the load-bearing CON-3 mechanism. They are intentionally inline in `dispatch-interface.sh` rather than factored out to a helper because the function is already past the line count where pure-lib extraction (MEM004 pattern) pays off. If T03/T04 grows further dispatch-side routing logic, P03 should consider extracting `_di_resolve_routing()` into `scripts/dispatch/lib/routing-resolve.sh` and sourcing it. P02 keeps the logic inline to minimize the amendment surface.

P03 will consume the four shadow fields T02 emits: `model_routed` for override-source comparison, `model_used` for live-routing baseline, `partial_flip_active` + `withheld_classes` for the per-class flip-activation path. T02's emit-as-no-op-empty for the latter two is the schema reservation P03 builds on.

If the awk YAML extraction proves brittle (e.g., the `templates/model-routing.yml` syntax shifts in a future edit), the fallback shape is: source `scripts/util/json-field.sh` and adopt a YAML-to-JSON converter. P02 explicitly does NOT introduce that dependency — the awk approach is sufficient for the current YAML structure (P01's `awk` section-walker pattern is the precedent per P01-SUMMARY.md `patterns_established:` "Awk section-walker for YAML closure-check").

## State Context

- **Current State**: executing
- **Milestone**: M030
- **Phase**: P02
- **Task**: T02-dispatch-shadow-hook
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **AD-19 single-script-file shape**: all verifier `Check:` invocations are `bash <single-path>.sh`. The amendment to `dispatch-interface.sh` is internal code; AD-19 governs the verifier-invocation shape, not the script's internal structure.
- **MEM004 emitter-internal carve-out**: `_di_emit_dispatch_usage` already declares (line 184) that pipes / `awk` / `$()` are permitted in its body as a dispatch-internal carve-out. T02's amendment extends that carve-out — the new awk extraction blocks are body-internal and are NOT subject to AD-19's outer-invocation shape rules.
- **AP-009 compound-chain-gt2 (verifier shape)**: the four T02 verifiers MUST avoid `result=$(cmd | grep | head)` patterns. Use tmp-file intermediates: `cmd > /tmp/<f>; grep ... < /tmp/<f> > /tmp/<g>; head -1 < /tmp/<g>`. Each `Bash` tool invocation in `auto-loop` runs through the harness shape-guard; `bash <verifier>.sh` is the safe invocation shape.
- **CON-2/FR-19/SC-11 (additive-only schema)**: the shadow-off `printf` format strings MUST be byte-identical to the pre-amendment form. T01's golden fixture is the SSOT; if Step 4's re-run of `p02-additive-schema.sh` fails, the format string is wrong.
- **CON-3 (symbolic-tier closure)**: zero literal provider model IDs in `dispatch-interface.sh`. The awk extraction reads `templates/model-routing.yml` at every dispatch. Verified by `p02-con3-closure.sh` (HEAD-vs-working-tree count comparison per pattern).
- **CON-6 (append-only shadow corpus)**: the new code path uses `>> "$log_file"` only. No `mv`, no `cp`, no truncating `>`, no temp-file-and-swap. Verified by `p02-append-only.sh` (inode + first-N-lines + line-count comparison).
- **CC-only launch posture**: shadow path requires `CLAUDECODE=1` AND `M030_SHADOW_MODE=1`. Codex CLI / Cursor short-circuit to the pre-P02 emit. Verified by `p02-shadow-emit.sh` Scenario C.
- **Bash 3.2 compatibility**: no `declare -A`, no `mapfile`, no `readarray`. The awk blocks are POSIX awk, not gawk-extended.
- **Plan-Time Discipline rule 5 (real-DB verification)**: T02 does NOT introduce SQL — N/A.

### Acceptance Criteria

This task satisfies the phase truths:

- "`scripts/dispatch/dispatch-interface.sh` invokes the P01 classifier on every dispatch when `M030_SHADOW_MODE=1` AND `CLAUDECODE=1`..." — gated by `tools/verify/p02-shadow-emit.sh`.
- "The shadow-mode amendment to `dispatch-interface.sh` contains zero hardcoded model IDs..." — gated by `tools/verify/p02-con3-closure.sh`.
- "The shadow JSONL write path is append-only..." — gated by `tools/verify/p02-append-only.sh`.
- "SC-11 byte-equality holds..." — re-asserted by `tools/verify/p02-additive-schema.sh` against the amended emitter.

### Files To Touch

- `scripts/dispatch/dispatch-interface.sh` (modify)
- `scripts/diagnostics/shadow-compare.sh` (create)
- `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` (create)
- `tests/fixtures/m030-p02/shadow-corpus-ready.jsonl` (create)
- `tests/fixtures/m030-p02/shadow-corpus-partially-ready.jsonl` (create)
- `tests/fixtures/m030-p02/shadow-corpus-evidence-insufficient.jsonl` (create)
- `tests/fixtures/m030-p02/shadow-corpus-block.jsonl` (create)
- `tests/fixtures/m030-p02/sc3a-roundtrip-corpus.jsonl` (create)
- `tools/verify/p02-fixture-shape.sh` (create)
- `tools/verify/p02-additive-schema.sh` (create)
- `tools/verify/p02-shadow-emit.sh` (create)
- `tools/verify/p02-con3-closure.sh` (create)
- `tools/verify/p02-append-only.sh` (create)
- `tools/verify/p02-shadow-compare-verdicts.sh` (create)
- `tools/verify/p02-partial-flip-enum.sh` (create)
- `tools/verify/p02-stability-metric-traceability.sh` (create)
- `tools/verify/p02-sc3a-roundtrip.sh` (create)
- `tools/verify/p02-phase-suite.sh` (create)
- `CLAUDE.md` (modify — recent-changes region)
- `AGENTS.md` (modify if present — recent-changes region dual-write)

<!-- Phase plan and task plan files (this file + tasks/T0[1-4]-*-PLAN.md)
     are written by the planner, not by the executor — not listed here. -->

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