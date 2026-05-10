---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T02-verifiers-and-summary (Phase P04, Milestone M018)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~600 | required |
| Upstream Context | 981-1139 | ~3400 | required |
| Task Plan | 1141-1544 | ~6900 | required |
| State Context | 1546-1552 | ~100 | required |
| First-Turn Completeness | 1554-1596 | ~1100 | required |
| **Total** | | **~22900** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 659
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
hit_count: 659
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
hit_count: 659
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
hit_count: 659
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
hit_count: 587
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
hit_count: 587
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
hit_count: 587
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
hit_count: 659
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
hit_count: 587
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
hit_count: 587
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
hit_count: 587
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
hit_count: 659
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
hit_count: 659
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
hit_count: 659
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
hit_count: 587
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
hit_count: 587
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
hit_count: 587
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
hit_count: 659
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
hit_count: 587
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
hit_count: 587
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
hit_count: 659
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
hit_count: 659
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
hit_count: 587
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
hit_count: 587
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
hit_count: 587
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
hit_count: 242
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
hit_count: 242
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
hit_count: 242
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
hit_count: 235
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
hit_count: 235
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
hit_count: 225
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

<!-- AD-19: every Check is a single-script-file invocation. No inline
     compound bash, no plain subshells, no $(...|...). One verifier per
     truth, parked under scripts/verify/m018-p04-*.sh. -->

- Tier 2 head-drop fires on section bodies (`## Knowledge`, `## Task Plan`, `## Upstream Context`) whose body-token count exceeds `compression.tier2.section_budget_tokens` (default 1500), removing head bytes above the budget while leaving the trailing `protected_tail_ratio` (default 0.3) byte-identical to the pre-snip section.
  - Check: `bash scripts/verify/m018-p04-tier2-head-drop.sh`
- Tier 2 emits the in-band marker `<!-- compressed:tier2 head_dropped=<N> protected_tail_ratio=<R> -->` immediately after the section heading line of every section it modifies; the marker's kvpair grammar matches the cross-tier `<!-- compressed:tier[0-9]+ [^>]*-->` vocabulary entry verbatim.
  - Check: `bash scripts/verify/m018-p04-tier2-marker.sh`
- Preserved-pattern boundary refusal: if the computed head-drop boundary lands inside a preserved span from the cross-tier vocabulary (frontmatter delimiter, 4+-backtick code fence, JSONL record, command name, MEM ID, scaffold marker, in-band tier marker, URL, repo-relative or absolute path), the snip retreats to the next safe boundary line; if no safe boundary exists above the protected tail, the section passes through unmodified and a `tier_preservation_violation` JSONL record is appended (record_type=`tier_preservation_violation`, tier=`tier2`).
  - Check: `bash scripts/verify/m018-p04-tier2-boundary-refusal.sh`
- `payload_breakdown` JSONL records carry an additive integer `tier2_savings_tokens` field; pre-T2 records remain valid JSON; missing field defaults to 0 in rollups (CON-5).
  - Check: `bash scripts/verify/m018-p04-tier2-emitter-additivity.sh`
- `compression.enabled: false` keeps the P02 golden (`tests/fixtures/m018-p02-baseline-payload.golden.txt`) byte-identical against the post-P04 build-context.sh; `compression.tier2.enabled: false` short-circuits only Tier 2 (filter + Tier 1 still run).
  - Check: `bash scripts/verify/m018-p04-tier2-disable-flag.sh`
- Body-level preservation self-check: after head-drop, `pres_check_section "tier2" <pre> <post> tier2` runs over the section bodies; on failure the section is restored byte-identical from the pre-snip capture and a `tier_preservation_violation` JSONL record is emitted via `pres_emit_violation` (tier=`tier2`).
  - Check: `bash scripts/verify/m018-p04-tier2-preservation-self-check.sh`

<dispatch-volatile>

## Upstream Context


### P03 Summary
---
schema_version: "1.0"
type: phase-summary
id: P03
parent: M018
milestone: M018
provides: "Tier 1 microcompact live in scripts/dispatch/build-context.sh:_bc_apply_tier1 — paging of inline tool-result blocks above compression.tier1.inline_threshold_tokens (default 1500); SHA-256(command + 0x1F + input)-keyed cache at .orchestrator/cache/tool-results/<sha256>; cache-reuse short-circuits writes (mtime preserved); preview-line reference (`<tool-result file=\"...\" preview-lines=\"5\" command=\"...\" original-body-tokens=\"...\">`) replaces oversized bodies; additive `tier1_savings_tokens` and `tier1_invocations` integer fields on payload_breakdown JSONL emit (CON-5 — pre-T01 records remain valid JSON, missing fields default to 0 in rollups); `tier_preservation_violation` JSONL record (record_type=tier_preservation_violation, tier=tier1) on post-paging pres_check_section failure (P02 library shared with P04/P06); scripts/util/cache-prune.sh --max-age <N>{d|h|m} mtime-based eviction utility (default 7d, idempotent, safe against missing cache dir); compression.tier1.{enabled,inline_threshold_tokens,preview_lines,cache_dir} config keys in .orchestrator/config.yml + templates/orchestrator-config-default.yml; seven P03-private truth verifiers under scripts/verify/m018-p03-*.sh; tests/fixtures/m018-p03-tool-result/ fixture (dispatch-payload-fixture.md + README.md); scripts/verify/_helpers/m018-p03-build-fixture.sh fixture-staging helper; CLAUDE.md/AGENTS.md recent-changes refresh"
requires: "P02 preservation-check library (scripts/lib/preservation-check.sh — pres_check_section + pres_emit_violation); P02 payload_breakdown schema with filter_dropped_tokens additive field; P02 byte-identity golden (tests/fixtures/m018-p02-baseline-payload.golden.txt) for the disable-flag regression contract; P02 _bc_apply_knowledge_filter establishes the awk-driven single-pass pattern Tier 1 mirrors"
affects: "P04 (T2 head-drop sources scripts/lib/preservation-check.sh established by P02 + reuses cache-prune utility for any spillover artifacts; consumes additive `tier1_savings_tokens` field through the rolling underperformance window; MIT-01 4+-backtick-fence regex remains load-bearing for T2 boundary detection); P05 (eval harness reads payload_breakdown.tier1_savings_tokens / .tier1_invocations + tier_preservation_violation records from execution-log.jsonl per the additive-emitter invariants section of the grammar contract); P06 (T3 auto-compact reuses the cache-prune mtime-only utility for tier-3 originals storage; same record-schema invariants — tier_preservation_violation with tier=tier3); P07+ (cache-prune cron / lifecycle wiring inherits the existing single-utility entry point)"
key_files: "scripts/dispatch/build-context.sh;scripts/util/cache-prune.sh;.orchestrator/config.yml;templates/orchestrator-config-default.yml;tests/fixtures/m018-p03-tool-result/dispatch-payload-fixture.md;tests/fixtures/m018-p03-tool-result/README.md;scripts/verify/_helpers/m018-p03-build-fixture.sh;scripts/verify/m018-p03-tier1-paging.sh;scripts/verify/m018-p03-cache-reuse.sh;scripts/verify/m018-p03-emitter-additivity.sh;scripts/verify/m018-p03-cache-prune.sh;scripts/verify/m018-p03-disable-flag-honored.sh;scripts/verify/m018-p03-preservation-self-check.sh;scripts/verify/m018-p03-dual-write-recent.sh"
key_decisions: "Tier 1 awk-driven single-pass paging (AP-009 compliant; mirrors P02 filter shape; single-pipe printf|grep idiom in verifiers, no $(cmd|cmd)); SHA-256(command + 0x1F + input) cache key — full digest, no truncation (collision domain dominated by hash space, not collision probability — keeps cache key small enough that mtime-based prune is correct without reference counting); cache reuse short-circuits writes (`if (getline _t < path) < 0` — open-for-read probe) so mtime is preserved across replays (FR — cache reuse without re-write); preservation self-check restores pre-paging body on failure (cache files written during the failed pass kept on disk for future reuse — they were physically valid bodies, the failure was a delta on the post-paging payload); cache-prune mtime-only (reference-aware preservation deferred — current cache key small enough that mtime is correct; documented as M018 follow-up in cache-prune.sh header); _bc_apply_tier1 inline in build-context.sh (single call site between _bc_emit_payload_breakdown and _bc_emit_compression_underperformance, MEM004 carve-out — no extraction to scripts/lib until a second caller emerges); shim-style verifier (sed/awk-extract _bc_apply_tier1 + source) avoids the brittleness of a full build-context.sh end-to-end probe for paging unit-coverage tests (the end-to-end path is exercised by m018-p03-emitter-additivity.sh + m018-p03-disable-flag-honored.sh)"
patterns_established: "Single-pass awk pagination with cache-write side-effect (T01); shim-style verifier that source-extracts a single bash function via awk range pattern (T03 — usable as P04/P06 verifier pattern when the function under test is too internal to dispatch end-to-end); function-stub pattern for failure-path test coverage (T03 — override pres_check_section to return 1 to exercise the violation/restoration code without depending on regex contents); fixture-staging helper that mirrors P02 helper shape under scripts/verify/_helpers/ (additive — one helper per phase keeps the helper directory legible)"
drill_down_paths: "[.orchestrator/milestones/M018/phases/P03/tasks/T01-tier1-paging-SUMMARY.md](../../../../../milestones/M018/phases/P03/tasks/T01-tier1-paging-SUMMARY.md);[.orchestrator/milestones/M018/phases/P03/tasks/T02-cache-prune-SUMMARY.md](../../../../../milestones/M018/phases/P03/tasks/T02-cache-prune-SUMMARY.md);[.orchestrator/milestones/M018/phases/P03/tasks/T03-verifiers-and-summary-SUMMARY.md](../../../../../milestones/M018/phases/P03/tasks/T03-verifiers-and-summary-SUMMARY.md)"
duration: "~5h"
verification_result: pass
observability_surfaces: "execution-log.jsonl: payload_breakdown.tier1_savings_tokens additive integer field; payload_breakdown.tier1_invocations additive integer field; tier_preservation_violation record_type (tier=tier1 from this phase; same schema reused by P04 with tier=tier2 and P06 with tier=tier3); cache-prune.sh stdout SUMMARY: pruned=N kept=M total=T bytes_freed=B"
completed_at: "2026-04-28T00:00:00Z"
---

# Phase Summary: M018/P03 — Tier 1 Microcompact

## Closure summary

P03 lands the **second tier** of the M018 compression pipeline: Tier 1
microcompact paging of oversized inline tool-result blocks. After P03
closes, every M018 dispatch (and every other orchestrator dispatch in
this repo) runs through the knowledge-aware filter (P02) **and** the
Tier 1 pager — the orchestrator dogfoods its own caveman compression
pipeline starting now.

P03 also ships the first cache-bearing tier — `.orchestrator/cache/tool-results/`
keyed by the full SHA-256 of `command + 0x1F + input`. Cache reuse
short-circuits writes (mtime preserved across replays); cache eviction
is mtime-only via `scripts/util/cache-prune.sh --max-age <duration>`.
P04/T2 head-drop has no cache. P06/T3 auto-compact reuses this same
cache-prune utility for tier-3 originals storage.

The phase ships:

- **Tier 1 paging** (`_bc_apply_tier1` in `scripts/dispatch/build-context.sh`)
  — single awk pass: scan the captured payload, accumulate
  `<tool-result command="...">…</tool-result>` blocks, hash + write
  the cache, replace oversized bodies (> 1500 tokens by default) with
  `<tool-result file="<path>" preview-lines="5" command="..." original-body-tokens="...">`
  + a 5-line preview. Bodies under threshold pass through verbatim.
  Hooked at `build-context.sh` line ~1723 between
  `_bc_emit_payload_breakdown` and `_bc_emit_compression_underperformance`.
- **SHA-256 cache key** — `command + 0x1F + input`. Full 64-hex digest.
  Cache files re-used across dispatches: an open-for-read probe
  (`(getline _t < path) < 0`) tests presence; on hit, the cache write
  is skipped (mtime preserved).
- **Additive emitter fields** (CON-5) — `tier1_savings_tokens` and
  `tier1_invocations` on `_bc_emit_payload_breakdown`'s printf line.
  Stats are captured to `$TMPDIR_BUILD/_tier1_stats.txt` by the awk
  pass and read back by the emitter; missing stats file defaults
  to 0/0 (passthrough case where no paging fired).
- **Preservation self-check integration** — when Tier 1 modifies the
  capture, `pres_check_section "tier1" <pre> <post> tier1` runs over
  the post-paging body. On failure, the pre-paging file is restored
  to `$capture_file` byte-for-byte and `pres_emit_violation` writes a
  `tier_preservation_violation` JSONL record (record_type=`tier_preservation_violation`,
  tier=`tier1`). Cache files written during the failed pass remain on
  disk — they were physically valid bodies; the failure was a delta on
  the post-paging payload bytes, not on the cache contents.
- **`scripts/util/cache-prune.sh --max-age <N>{d|h|m}`** — single-script
  utility, default 7d. Reads `compression.tier1.cache_dir` from
  `.orchestrator/config.yml`; falls back to `.orchestrator/cache/tool-results/`.
  Single-level glob (sub-directories skipped per Constitution VI —
  future tier-3-originals/ co-tenants stay untouched). BSD-vs-GNU stat
  detection. `--dry-run` prints `WOULD-PRUNE:` lines without removal.
  `SUMMARY: pruned=N kept=M total=T bytes_freed=B` line on stdout.
  Idempotent. Malformed `--max-age` exits 1.
- **Config surface** — `compression.tier1.{enabled, inline_threshold_tokens,
  preview_lines, cache_dir}` keys; defaults true / 1500 / 5 /
  `.orchestrator/cache/tool-results/`. Live in `.orchestrator/config.yml`
  + `templates/orchestrator-config-default.yml`.
- **Disable contracts** —
  `compression.enabled: false` (master toggle, FR-15) short-circuits
  the entire pipeline (filter + Tier 1 — byte-identical to pre-M018
  capture against the P02 golden).
  `compression.tier1.enabled: false` short-circuits only Tier 1; the
  knowledge-aware filter still runs.
  `ORCH_OVERRIDE_COMPRESSION_ENABLED=false` env wins over the config
  (test seam, FR-15 SC-8).

## Risk-mitigation traceability

- **MIT-08 (P02 entry gate, P01 conversus deliberation)** — LLM
  preservation trust boundary lives in P06; P03 contributes the
  preservation-check failure-path wiring pattern that P06 will mirror
  with the LLM density-pre-check.
- **MIT-10 (P02, THREAT-09 from P01 conversus deliberation)** —
  preservation-contract self-check algorithmic specification is now
  exercised live: `pres_check_section` runs over every Tier 1 paging
  pass, and the failure-path emits `tier_preservation_violation`
  per the grammar contract.
- **CON-5 (additive emitters)** — `tier1_savings_tokens` /
  `tier1_invocations` are additions to the existing payload_breakdown
  schema; pre-T01 records remain valid JSON; rollups treat absent
  fields as 0. Verified by the historical-log diff in
  `m018-p03-emitter-additivity.sh`.

## Followups for downstream phases

- **P04 (tier2 head-drop)** — sources `scripts/lib/preservation-check.sh`
  (same library; tier=`tier2`); the MIT-01 nested-fence regex
  (`^\`{3,}[a-zA-Z0-9_-]*$`) is load-bearing for P04's head-drop
  boundary detection. T2 has no cache — paging is destructive.
  Reuses `scripts/util/cache-prune.sh` only if any spillover artifacts
  are introduced.
- **P05 (eval harness)** — reads
  `payload_breakdown.tier1_savings_tokens` / `.tier1_invocations`
  from `execution-log.jsonl` for cumulative-savings rollups. Reads
  `tier_preservation_violation` records (tier=`tier1`/`tier2`/`tier3`)
  for trust-boundary diagnostics.
- **P06 (tier3 auto-compact)** — wires `pres_density_pre_check` before
  the LLM call per MIT-08; tier-3-savings field additive on
  `payload_breakdown`; tier-3 originals stored under
  `.orchestrator/cache/tier3-originals/` (sibling, not nested).
  `cache-prune.sh` already-skips sub-directories so tier-3 storage
  needs its own prune pass — recommend `--cache-dir` flag rather than
  hard-coding tier1 vs tier3 in the utility.
- **P07+** — cache-prune cron / lifecycle wiring inherits the existing
  single-utility entry point; recipe-level integration with
  `orchestrator:doctor` is the natural follow-up.

## Verification result

All P03 truths PASS via
`bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P03/`.
All artifacts present at required line counts with required substrings;
all key links resolve; all seven private verifiers green:

- `m018-p03-tier1-paging.sh` — PASS (big block paged, small block
  verbatim, SHA-256 cache file written under fixture cache dir).
- `m018-p03-cache-reuse.sh` — PASS (mtime preserved across two paging
  passes against the same fixture payload).
- `m018-p03-emitter-additivity.sh` — PASS (emitter source carries
  additive fields; live emission carries integer-valued tier1_*
  fields; pre-T01 + post-T01 historical records both valid JSON).
- `m018-p03-cache-prune.sh` — PASS (`--max-age 7d` prunes 30d-old
  file, keeps fresh file, idempotent on second invocation, survives
  missing cache dir).
- `m018-p03-disable-flag-honored.sh` — PASS (P02 golden byte-identical
  to fixture; both `compression.enabled=false` and
  `compression.tier1.enabled=false` short-circuit Tier 1 — empty cache
  dir, tier1_invocations=0).
- `m018-p03-preservation-self-check.sh` — PASS (failure-path
  passthrough holds; `tier_preservation_violation` record emitted with
  tier=`tier1`).
- `m018-p03-dual-write-recent.sh` — PASS (CLAUDE.md + AGENTS.md
  recent-changes blocks both name M018/P03).

P03 closed. M018 advances to P04 (head-drop tier).

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P04"
milestone: "M018"
name: "Tier 2 verifiers, fixtures, fixture-staging helper, P04-SUMMARY + CLAUDE.md/AGENTS.md dual-write"
depends_on: ["T01"]
---

## Prerequisites

- T01 has shipped `_bc_apply_tier2` and the `compression.tier2.*` config keys + accessors + the additive `tier2_savings_tokens` field on `payload_breakdown`. T02 ships the verifier scripts, fixtures, fixture-staging helper, P04-SUMMARY, and the dual-write of the runtime instruction file's recent-changes block.
- `scripts/verify/_helpers/m018-p03-build-fixture.sh` is the canonical helper-shape T02 mirrors. Read it once for shape (config-override scaffolding, fixture path resolution, capture-file staging) before authoring `m018-p04-build-fixture.sh`.
- `scripts/util/dual-write-runtime-md.sh` is the canonical dual-write helper used by every prior phase that updated `CLAUDE.md` recent-changes (M011/P07, [M013](../../../../../milestones/M013/index.md), [M015](../../../../../milestones/M015/index.md), [M016](../../../../../milestones/M016/index.md), M019, M020, [M021](../../../../../milestones/M021/index.md), M025, [M027](../../../../../milestones/M027/index.md), M018/P02, M018/P03). Invocation pattern: `bash scripts/util/dual-write-runtime-md.sh <orchestrator:recent-changes block content>` — writes the block to both `CLAUDE.md` and `AGENTS.md` between the `# >>> orchestrator:recent-changes >>>` and `# <<< orchestrator:recent-changes <<<` sentinels. The verifier `m018-p04-dual-write-recent.sh` only checks that both files contain "M018/P04" in their recent-changes block — the dual-write helper itself is unchanged.
- AD-19 single-script-file `Check:` contract: every verifier exposes its truth via a single bash invocation. The verifier may shell out to subordinate helpers (e.g., `_helpers/m018-p04-build-fixture.sh`) but the orchestrator's `check-must-haves.sh` invokes ONE bash file per truth.
- AP-009 applies to verifier scripts. No compound chains > 2; no plain subshells; no `$(...|...)`. Verifier scripts use `pass()`/`fail()` per MEM002 and the typical `printf 'PASS:' / printf 'FAIL:'` line-prefix convention.
- The `m018-p03-disable-flag-honored.sh` verifier exists and asserts byte-identity of the P02 golden against the post-P03 build-context.sh under `compression.enabled: false`. T02's `m018-p04-tier2-disable-flag.sh` is the same shape, post-P04.
- Bash 3.2 — verifiers use parallel indexed arrays (no `declare -A`).

## Description

T02 ships seven verifier scripts under `scripts/verify/m018-p04-*.sh`, two fixture directories under `tests/fixtures/m018-p04-*/`, one fixture-staging helper under `scripts/verify/_helpers/`, the P04-SUMMARY, and the CLAUDE.md/AGENTS.md `orchestrator:recent-changes` dual-write. The verifiers exercise T01's production code through fixtures plus shim invocations of `_bc_apply_tier2` (sourcing the function the same way `m018-p03-tier1-paging.sh` source-extracts `_bc_apply_tier1`).

The seven verifiers map 1:1 to the P04 truths:

1. `m018-p04-tier2-head-drop.sh` — section-overflow fixture asserts head-drop fires; the trailing 30% of the pre-snip section is byte-identical at the tail of the post-snip section; the heading line is preserved; the post-snip body-token count is at most `section_budget_tokens + tail_token_count` (boundary inequality, not equality, since boundary retreat may leave more than the budget in place).
2. `m018-p04-tier2-marker.sh` — same fixture asserts the marker `<!-- compressed:tier2 head_dropped=<N> protected_tail_ratio=0.30 -->` appears immediately after the heading line, on its own line, with integer N > 0 and the literal string `protected_tail_ratio=0.30`.
3. `m018-p04-tier2-boundary-refusal.sh` — boundary-refusal fixture asserts that when the over-budget section contains an open 4+-backtick code fence whose start lies above the protected tail and whose end lies inside the protected tail, the snip retreats; if no safe boundary exists, the section passes through unmodified plus a `tier_preservation_violation` (tier=`tier2`) JSONL record names the spanning pattern label.
4. `m018-p04-tier2-emitter-additivity.sh` — exercises the dispatch through the section-overflow fixture and asserts (a) the emitted `payload_breakdown` JSONL line is valid JSON; (b) the `tier2_savings_tokens` field is present with an integer value > 0; (c) a historical pre-P04 `payload_breakdown` record (pulled from a checked-in sample inside the fixture, OR from the existing `tests/fixtures/m018-p02-baseline-payload.golden.txt` if the format permits) parses cleanly via `python3 -c 'import json; [json.loads(l) for l in open(...)]'`.
5. `m018-p04-tier2-disable-flag.sh` — asserts (a) `ORCH_OVERRIDE_COMPRESSION_ENABLED=false` produces a payload byte-identical to `tests/fixtures/m018-p02-baseline-payload.golden.txt`; (b) `compression.tier2.enabled=false` (via a fixture config override) leaves Tier 1 still firing on a tier1-only fixture (e.g., the P03 fixture), proving Tier 2 short-circuited without affecting Tier 1.
6. `m018-p04-tier2-preservation-self-check.sh` — function-stub pattern (per the P03/T03 lesson): override `pres_check_section` to return 1 within the verifier's bash scope, source `_bc_apply_tier2`, and assert (a) the post-call payload is byte-identical to the pre-call payload (passthrough on failure); (b) a `tier_preservation_violation` JSONL record is appended with `tier=tier2`.
7. `m018-p04-dual-write-recent.sh` — asserts both `CLAUDE.md` and `AGENTS.md` contain a `# >>> orchestrator:recent-changes >>>`-delimited block whose body names "M018/P04" or "tier2".

## Steps

### Step 1 — Author `scripts/verify/_helpers/m018-p04-build-fixture.sh`

Mirror the P03 fixture-staging helper. The helper's job:

- `set_fixture <fixture-slug>` — given a slug like `section-overflow` or `boundary-refusal`, point `$PROJECT_ROOT_OVERRIDE` (or whatever env var build-context.sh reads — confirm against the P03 helper) at a transient `$TMPDIR_BUILD/_p04_fixture/<slug>/` tree that contains:
  - `.orchestrator/config.yml` — derived from the canonical config but with the tier1/filter caches pointing at fixture-private temp dirs and (for some test cases) `compression.tier2.section_budget_tokens` overridden small (e.g., 200) so a small fixture can exercise head-drop without needing 1500-token-sized sections.
  - `tests/fixtures/m018-p04-<slug>/dispatch-payload-fixture.md` symlinked or copied in.
  - The execution-log.jsonl path resolved under the fixture's milestone dir.
- Returns 0 on successful staging with stdout printing the staged fixture root path.
- Idempotent (clean staging dir on re-invocation).

The helper exists so each verifier is one-shot from outside (the verifier sources it, calls `set_fixture`, runs build-context.sh, asserts, exits). The helper does not embed assertion logic.

### Step 2 — Author `tests/fixtures/m018-p04-section-overflow/dispatch-payload-fixture.md`

A fixture whose `## Knowledge` section body is over-budget but contains NO multi-line preserved spans. Shape (illustrative — actual fixture authored to whatever budget the helper sets, e.g., 200 tokens for a small fast fixture):

```
---
schema_version: "1.0"
type: planning-prompt
---

# Dispatch Context — TASK_DISPATCH (P04, M018)

## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge | 12-200 | ~180 | filtered |

## Knowledge

<filler text — ~180 tokens of plain prose, no code fences, no frontmatter
delimiters past the document opener, no JSONL records, no MEM IDs that
would interact with the boundary-refusal detector. Multi-paragraph,
multi-line, designed to exceed the 200-token fixture budget but to have
plenty of safe line boundaries.>

## Decisions

(no entries.)
```

Plus `tests/fixtures/m018-p04-section-overflow/README.md` documenting the fixture's shape and which truth it exercises.

### Step 3 — Author `tests/fixtures/m018-p04-boundary-refusal/dispatch-payload-fixture.md`

A fixture whose `## Upstream Context` section body is over-budget AND whose head-drop range contains an open 4-backtick (or 5-backtick) code fence whose closer lives inside the protected-tail range. The fence MUST be the canonical MIT-01 case: 4+ backticks, with no language tag or with a `bash`-style language tag, on its own line at column 0.

Sketch:

```
---
schema_version: "1.0"
type: planning-prompt
---

## Manifest
...

## Upstream Context

<text — ~50 tokens — leading prose>

````bash
<fence body — ~200 tokens — embedded code containing 3-backtick lines
that should NOT close the 4-backtick fence>
```nested-3-tick-fence
print "this is content of the outer 4-tick fence"
```
<more fence body — extends until past the protected-tail boundary>
````

<post-fence prose — ~50 tokens>
```

The fixture must be sized so the naive cut byte (`floor(body_chars * 0.7)` for the default 0.3 ratio) lands INSIDE the fence — so the boundary-refusal detector retreats to BEFORE the fence opener, OR (if the fence opener is itself above the budget cut) refuses to snip at all and emits a violation.

The fixture's README documents the expected behavior under the default 0.3 ratio at `section_budget_tokens=200`: cut retreats to line just above the fence opener; head-drop produces savings smaller than the maximum because the fence forces the cut higher than the naive boundary.

### Step 4 — Author `scripts/verify/m018-p04-tier2-head-drop.sh`

Outline:

```bash
#!/bin/bash
# M018/P04/T02: Verify Tier 2 head-drop produces a paged section whose tail
# is byte-identical to the pre-snip tail and whose token count fits the
# budget (or above-budget by no more than one preserved-span retreat).
set -u
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$PROJECT_ROOT/scripts/verify/_helpers/m018-p04-build-fixture.sh"

pass_n=0; fail_n=0
pass() { pass_n=$((pass_n+1)); printf 'PASS: %s\n' "$1"; }
fail() { fail_n=$((fail_n+1)); printf 'FAIL: %s\n' "$1"; }

# Stage fixture, run build-context.sh, capture output, assert.
fixture_root="$(set_fixture section-overflow)" || { fail "set_fixture"; exit 1; }
out="$fixture_root/_payload_out.txt"
ORCH_PROJECT_ROOT="$fixture_root" \
  bash "$PROJECT_ROOT/scripts/dispatch/build-context.sh" M018 P04 T01-test \
  > "$out" 2>/dev/null

# 1. The marker appears once immediately after `## Knowledge`.
grep -A1 '^## Knowledge' "$out" | grep -qE '<!-- compressed:tier2 head_dropped=[0-9]+ protected_tail_ratio=0\.30 -->' \
  && pass "marker emitted after Knowledge heading" \
  || fail "marker missing"

# 2. The trailing 30% of the pre-snip Knowledge section appears byte-identical
#    at the end of the post-snip Knowledge section.
#    The verifier reads the fixture's pre-snip body, computes the protected
#    tail bytes, and grep -F's the bytes against the post-snip output.
pre_body="$fixture_root/_pre_knowledge_body.txt"
# (helper-supplied: the pre-snip body of the Knowledge section.)
tail_bytes="$(wc -c < "$pre_body")"
tail_keep_bytes=$(( tail_bytes * 30 / 100 ))
tail "-c$tail_keep_bytes" "$pre_body" > "$fixture_root/_pre_tail.txt"
if grep -qF "$(head -c 200 "$fixture_root/_pre_tail.txt")" "$out"; then
  pass "protected tail prefix present in post-snip output"
else
  fail "protected tail prefix missing"
fi

printf 'SUMMARY: pass=%d fail=%d\n' "$pass_n" "$fail_n"
[ "$fail_n" -eq 0 ]
```

(The actual verifier handles `head -c 200` quoting more carefully via a temp file rather than the `$(...|...)` shape that AP-009 forbids — the sketch shows the assertion shape, the implementation uses two-step staging.)

### Step 5 — Author `scripts/verify/m018-p04-tier2-marker.sh`

Same fixture-staging shape. Assertions:

- The post-snip output contains EXACTLY ONE `<!-- compressed:tier2 head_dropped=` line.
- That line matches `<!-- compressed:tier2 head_dropped=[0-9]+ protected_tail_ratio=0\.30 -->` (extended-regex grep).
- The line appears immediately after `^## Knowledge` (line-after-heading invariant — `awk` two-line lookahead).
- The marker matches the cross-tier vocabulary entry verbatim: a final `grep -E '<!-- compressed:tier[0-9]+ [^>]*-->'` on the same line passes.

### Step 6 — Author `scripts/verify/m018-p04-tier2-boundary-refusal.sh`

Stage the boundary-refusal fixture. Assertions:

- The post-call output's `## Upstream Context` section either (a) contains an in-band tier2 marker whose `head_dropped` value is SMALLER than the naive head-drop would produce — proving retreat fired; OR (b) is byte-identical to the pre-call section AND a `tier_preservation_violation` JSONL record is present in the fixture's execution-log.jsonl with `tier=tier2` and `pattern=code-fence`.
- The 4-backtick code fence opener and closer are both present and unaltered in the output (no fence orphaned by the snip).

### Step 7 — Author `scripts/verify/m018-p04-tier2-emitter-additivity.sh`

Stage the section-overflow fixture; run the dispatch; read the most recent `payload_breakdown` line from the fixture's execution-log.jsonl. Assertions:

- The line parses as JSON via `python3 -c 'import json,sys;json.loads(sys.stdin.read())' < line`.
- The parsed object contains `tier2_savings_tokens` with an integer value > 0.
- The parsed object also still contains `tier1_savings_tokens`, `tier1_invocations`, `filter_dropped_tokens` (additivity, not replacement).
- A pre-P04 sample record (e.g., `tests/fixtures/m018-p02-baseline-payload.golden.txt`-style historical record bundled in the fixture's README, OR a standalone `tests/fixtures/m018-p04-pre-p04-payload-breakdown.jsonl` if needed) parses as JSON and lacks `tier2_savings_tokens` — proving the field is additive, not required.

### Step 8 — Author `scripts/verify/m018-p04-tier2-disable-flag.sh`

Two sub-assertions sharing the verifier file:

(a) **Master disable** — `ORCH_OVERRIDE_COMPRESSION_ENABLED=false bash scripts/dispatch/build-context.sh ...` against the P02 baseline fixture produces output byte-identical to `tests/fixtures/m018-p02-baseline-payload.golden.txt`. (Same shape as `m018-p03-disable-flag-honored.sh`.)

(b) **Per-tier disable** — stage a fixture with `compression.tier2.enabled: false` but `compression.enabled: true` and `compression.tier1.enabled: true`. Run the dispatch against an input whose Knowledge section is over-budget AND whose tool-result block is over-tier1-threshold. Assert (i) Tier 1 fired (`tier1_invocations > 0` in payload_breakdown); (ii) Tier 2 did NOT fire (`tier2_savings_tokens == 0` AND no `<!-- compressed:tier2` marker in the output).

### Step 9 — Author `scripts/verify/m018-p04-tier2-preservation-self-check.sh`

Function-stub pattern. The verifier:

1. Sources `scripts/lib/preservation-check.sh` then OVERRIDES `pres_check_section() { return 1; }` (a stub that always fails).
2. Source-extracts `_bc_apply_tier2` from `scripts/dispatch/build-context.sh` via the same awk range pattern P03 used for `_bc_apply_tier1` (`/^_bc_apply_tier2\(\)/,/^}/`).
3. Stages the section-overflow fixture, runs `_bc_apply_tier2 "$capture_file"` directly, and asserts (a) `$capture_file` is byte-identical to its pre-call snapshot; (b) the fixture's execution-log.jsonl contains a new `tier_preservation_violation` line with `tier=tier2`.

### Step 10 — Author `scripts/verify/m018-p04-dual-write-recent.sh`

Pure file-content assertion. Reads both `CLAUDE.md` and `AGENTS.md`, extracts the block between `# >>> orchestrator:recent-changes >>>` and `# <<< orchestrator:recent-changes <<<`, asserts both blocks contain the literal string `M018/P04` (or `tier2` — accept either since the dual-write content is editorial). Exit 0 on both-pass; 1 otherwise.

### Step 11 — Author [`.orchestrator/milestones/M018/phases/P04/P04-SUMMARY.md`](../../../../../milestones/M018/phases/P04/P04-SUMMARY.md)

Mirror the P03-SUMMARY shape. Frontmatter fields (matching MEM013 + the existing P03-SUMMARY frontmatter):

```yaml
schema_version: "1.0"
type: phase-summary
id: P04
parent: M018
milestone: M018
provides: |
  Tier 2 snip live in scripts/dispatch/build-context.sh:_bc_apply_tier2 —
  head-drop of in-scope section bodies (Knowledge, Task Plan, Upstream
  Context) above compression.tier2.section_budget_tokens (default 1500),
  preserving compression.tier2.protected_tail_ratio (default 0.3) of
  pre-snip section bytes byte-identical at the tail; in-band marker
  `<!-- compressed:tier2 head_dropped=N protected_tail_ratio=R -->` named
  immediately after the section heading; line-aligned cut with
  boundary-refusal walker that retreats above multi-line preserved spans
  (frontmatter `^---$` pairs and `^\`{3,}[a-zA-Z0-9_-]*$` code-fence pairs
  by tick-count, MIT-01-aware); pass-through on no-safe-boundary plus a
  `tier_preservation_violation` JSONL record (tier=tier2, pattern=spanning
  cross-tier label); preservation self-check via pres_check_section ...
  tier2 (strict multiplicity); additive integer `tier2_savings_tokens`
  field on payload_breakdown JSONL emit (CON-5); compression.tier2.{enabled,
  section_budget_tokens, protected_tail_ratio} config keys in
  .orchestrator/config.yml + templates/orchestrator-config-default.yml;
  three new kf_get_tier2_* accessors in scripts/lib/knowledge-filter.sh;
  seven P04-private truth verifiers under scripts/verify/m018-p04-*.sh;
  two fixture trees under tests/fixtures/m018-p04-{section-overflow,
  boundary-refusal}/; scripts/verify/_helpers/m018-p04-build-fixture.sh
  fixture-staging helper; CLAUDE.md/AGENTS.md recent-changes refresh.
requires: |
  P03 _bc_apply_tier1 wiring shape (build-context.sh call-site adjacency);
  P02 preservation-check library (pres_check_section + pres_emit_violation
  + PRES_PATTERNS_REGEX cross-tier vocabulary including the MIT-01
  4+-backtick code-fence regex which is load-bearing for boundary
  detection); P02 byte-identity golden (tests/fixtures/m018-p02-baseline-
  payload.golden.txt) for the disable-flag regression contract; P01
  references/compression-grammar.md `## Tier: tier2` rules.
affects: |
  P05 (eval harness reads payload_breakdown.tier2_savings_tokens and
  tier_preservation_violation records with tier=tier2 from execution-
  log.jsonl per the additive-emitter invariants section of the grammar
  contract); P06 (T3 auto-compact runs AGAINST the tier2 output — sees
  head-dropped-plus-protected-tail bytes, not pre-snip bytes; tier3
  must NOT mutate the tier2 in-band marker per the grammar contract;
  tier3 wraps the marker if the section is summarized further);
  M027/M019 cost surfaces consume tier2_savings_tokens via the existing
  payload_breakdown read path.
key_files: |
  scripts/dispatch/build-context.sh;scripts/lib/knowledge-filter.sh;
  .orchestrator/config.yml;templates/orchestrator-config-default.yml;
  tests/fixtures/m018-p04-section-overflow/dispatch-payload-fixture.md;
  tests/fixtures/m018-p04-section-overflow/README.md;
  tests/fixtures/m018-p04-boundary-refusal/dispatch-payload-fixture.md;
  tests/fixtures/m018-p04-boundary-refusal/README.md;
  scripts/verify/_helpers/m018-p04-build-fixture.sh;
  scripts/verify/m018-p04-tier2-head-drop.sh;
  scripts/verify/m018-p04-tier2-marker.sh;
  scripts/verify/m018-p04-tier2-boundary-refusal.sh;
  scripts/verify/m018-p04-tier2-emitter-additivity.sh;
  scripts/verify/m018-p04-tier2-disable-flag.sh;
  scripts/verify/m018-p04-tier2-preservation-self-check.sh;
  scripts/verify/m018-p04-dual-write-recent.sh
key_decisions: |
  Boundary-refusal walker retreats DOWN from the naive cut line toward
  line 1 looking for the first line whose at-line-start unsafe flag is 0
  (the line that OPENS a span is itself safe — cutting above the opener
  is correct because everything from the opener onward falls into the
  protected tail); 4+-backtick fence tracking by tick-count not by line
  count (3-backtick lines do not close 4-backtick fences — MIT-01);
  no-safe-boundary refusal passes the section through verbatim plus a
  tier_preservation_violation JSONL emit (NOT a tier2_preservation_breach
  — that record is reserved for the protected-tail breach path which
  the boundary-refusal detector makes unreachable; the grammar contract
  separates the two record types intentionally); strict-multiplicity
  tier2 self-check shape (mirrors the tier1 strict-multiplicity branch
  in pres_check_section); _bc_apply_tier2 inline in build-context.sh
  (single call site, MEM004 carve-out — no extraction to scripts/lib
  until a second caller emerges); tier2 has NO cache (head-drop is
  destructive on the in-flight payload; originals on disk are untouched
  per Constitution Principle VI; cache-prune utility is reusable but not
  wired in this phase); fixture-staging helper mirrors P03 shape
  one-helper-per-phase under scripts/verify/_helpers/.
patterns_established: |
  Awk single-pass section-aware head-drop with at-line-start unsafe-flag
  recording (T01 — usable shape for P05/P06 if their tiers ever need
  per-line span awareness); function-stub pattern reused from P03/T03
  (override pres_check_section to return 1 to exercise the failure path
  without depending on regex contents); dual-fixture pattern (one fixture
  exercising the happy-path, one exercising the boundary-refusal path —
  reusable for any tier whose safety boundary is the load-bearing claim).
drill_down_paths: |
  .orchestrator/milestones/M018/phases/P04/tasks/T01-tier2-head-drop-SUMMARY.md;
  .orchestrator/milestones/M018/phases/P04/tasks/T02-verifiers-and-summary-SUMMARY.md
duration: ~4h
verification_result: pass
observability_surfaces: |
  execution-log.jsonl: payload_breakdown.tier2_savings_tokens additive
  integer field; tier_preservation_violation record_type
  (tier=tier2 from this phase; same schema as tier1 from P03 and tier3
  from P06).
completed_at: 2026-04-28T00:00:00Z
```

The body documents the phase-close summary, risk-mitigation traceability, and follow-ups for downstream phases — same shape as P03-SUMMARY.

### Step 12 — Dual-write CLAUDE.md / AGENTS.md `orchestrator:recent-changes` block

Compose a one-line recent-changes update naming M018/P04. Example:

```
- 030-context-compression-layer: M018/P04 — Tier 2 snip. Section head-drop with protected tail; in-band tier2 marker; preserved-pattern boundary refusal (MIT-01-aware); additive tier2_savings_tokens.
```

Run:

```
bash scripts/util/dual-write-runtime-md.sh "<the new recent-changes line>"
```

Confirm both files received the update.

### Step 13 — Run all P04 verifiers

```
for v in scripts/verify/m018-p04-*.sh; do bash "$v"; done
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P04/
```

Both calls should exit 0 with all PASS lines.

## Must-Haves

- All seven verifier scripts exist and exit 0 (one per truth in P04-PLAN.md).
- Two fixture trees exist under `tests/fixtures/m018-p04-*` with README files.
- Fixture-staging helper exists under `scripts/verify/_helpers/m018-p04-build-fixture.sh`.
- P04-SUMMARY.md exists at [`.orchestrator/milestones/M018/phases/P04/P04-SUMMARY.md`](../../../../../milestones/M018/phases/P04/P04-SUMMARY.md) with the frontmatter named in Step 11 and a body documenting closure summary, risk-mitigation traceability, follow-ups for downstream phases, and verification result.
- CLAUDE.md AND AGENTS.md `orchestrator:recent-changes` blocks both name `M018/P04` (or `tier2`).
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P04/` exits 0.

## Verification

- Each of the seven `scripts/verify/m018-p04-*.sh` scripts exits 0 when invoked directly.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P04/` exits 0 with every truth's `Check:` reporting PASS.
- `python3 -c 'import json,sys;[json.loads(l) for l in sys.stdin]'` against the section-overflow fixture's execution-log.jsonl parses cleanly (every line valid JSON; no schema regression).

## Inputs

### From Previous Tasks (within P04)

- T01 has shipped:
  - `scripts/dispatch/build-context.sh` `_bc_apply_tier2` function, the call-site insertion at line ~1724, the `TIER2_*` config reads at line ~193, and the `tier2_savings_tokens` field on `_bc_emit_payload_breakdown`'s printf.
  - `scripts/lib/knowledge-filter.sh` `kf_get_tier2_{enabled,section_budget_tokens,protected_tail_ratio}` accessors.
  - `.orchestrator/config.yml` and `templates/orchestrator-config-default.yml` `compression.tier2.*` block.

### From Disk (Pre-existing)

- `scripts/verify/_helpers/m018-p03-build-fixture.sh` — canonical fixture-staging helper shape T02 mirrors.
- `scripts/verify/m018-p03-tier1-paging.sh` and the other six P03 verifiers — canonical verifier shape (pass/fail counters, fixture staging, single-script invocation per truth).
- `scripts/verify/m018-p03-preservation-self-check.sh` — canonical function-stub-override-and-source-extract pattern T02 reuses for `m018-p04-tier2-preservation-self-check.sh`.
- `scripts/verify/check-must-haves.sh` — the framework that consumes P04-PLAN.md's `Check:` lines.
- `scripts/util/dual-write-runtime-md.sh` — the CLAUDE.md/AGENTS.md dual-write helper.
- `tests/fixtures/m018-p02-baseline-payload.golden.txt` — disable-flag regression contract.
- `tests/fixtures/m018-p03-tool-result/dispatch-payload-fixture.md` — usable as the per-tier-disable fixture (contains an over-tier1-threshold tool-result block; T2 must NOT fire on it when `compression.tier2.enabled=false`).
- `references/compression-grammar.md` `## Tier: tier2` (lines 191–211) — contract.

## Constraints

- **AD-19 (single-script-file Check)**: every truth in P04-PLAN.md has a `Check: bash <one path>.sh` line; the script may be self-contained or it may source helpers, but `check-must-haves.sh` invokes ONE script per truth.
- **AP-009 (Bash shape guard)**: zero compound chains > 2; zero plain subshells; zero `$(...|...)` shell forms in verifier scripts. Use staged temp files instead of pipes-into-substitutions. (The dispatch-internal carve-out applies to `_bc_*` helpers in build-context.sh, NOT to verifier scripts — verifier scripts must stay AP-009-compliant strictly.)
- **Bash 3.2 compatibility**: parallel indexed arrays only; no associative arrays; no `<(...)` process substitution.
- **Constitution Principle VI**: verifier scripts and fixtures live under their canonical directories (`scripts/verify/`, `tests/fixtures/`, `.orchestrator/milestones/M018/phases/P04/`); they do NOT mutate the canonical knowledge tree, spec, plan, or roadmap files.
- **MIT-01**: the boundary-refusal verifier MUST exercise a 4+-backtick code-fence case to assert the regex behavior — a 3-backtick-only fixture would not catch a regression to the 3-backtick regex.

## Expected Output

- `scripts/verify/_helpers/m018-p04-build-fixture.sh` exists, ~80–120 lines, mirrors the P03 helper.
- `tests/fixtures/m018-p04-section-overflow/{dispatch-payload-fixture.md,README.md}` exist.
- `tests/fixtures/m018-p04-boundary-refusal/{dispatch-payload-fixture.md,README.md}` exist.
- `scripts/verify/m018-p04-tier2-head-drop.sh` exists, ~60–100 lines, exits 0.
- `scripts/verify/m018-p04-tier2-marker.sh` exists, ~50–80 lines, exits 0.
- `scripts/verify/m018-p04-tier2-boundary-refusal.sh` exists, ~80–120 lines, exits 0.
- `scripts/verify/m018-p04-tier2-emitter-additivity.sh` exists, ~60–100 lines, exits 0.
- `scripts/verify/m018-p04-tier2-disable-flag.sh` exists, ~80–120 lines, exits 0.
- `scripts/verify/m018-p04-tier2-preservation-self-check.sh` exists, ~60–100 lines, exits 0.
- `scripts/verify/m018-p04-dual-write-recent.sh` exists, ~30–50 lines, exits 0.
- [`.orchestrator/milestones/M018/phases/P04/P04-SUMMARY.md`](../../../../../milestones/M018/phases/P04/P04-SUMMARY.md) exists, ~80–150 lines, contains "tier2_savings_tokens".
- `CLAUDE.md` and `AGENTS.md` recent-changes blocks both name `M018/P04`.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P04/` exits 0.

## State Context

- **Current State**: executing
- **Milestone**: M018
- **Phase**: P04
- **Task**: T02-verifiers-and-summary
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **AD-19 (single-script-file Check)**: every truth in P04-PLAN.md has a `Check: bash <one path>.sh` line; the script may be self-contained or it may source helpers, but `check-must-haves.sh` invokes ONE script per truth.
- **AP-009 (Bash shape guard)**: zero compound chains > 2; zero plain subshells; zero `$(...|...)` shell forms in verifier scripts. Use staged temp files instead of pipes-into-substitutions. (The dispatch-internal carve-out applies to `_bc_*` helpers in build-context.sh, NOT to verifier scripts — verifier scripts must stay AP-009-compliant strictly.)
- **Bash 3.2 compatibility**: parallel indexed arrays only; no associative arrays; no `<(...)` process substitution.
- **Constitution Principle VI**: verifier scripts and fixtures live under their canonical directories (`scripts/verify/`, `tests/fixtures/`, `.orchestrator/milestones/M018/phases/P04/`); they do NOT mutate the canonical knowledge tree, spec, plan, or roadmap files.
- **MIT-01**: the boundary-refusal verifier MUST exercise a 4+-backtick code-fence case to assert the regex behavior — a 3-backtick-only fixture would not catch a regression to the 3-backtick regex.

### Acceptance Criteria

- All seven verifier scripts exist and exit 0 (one per truth in P04-PLAN.md).
- Two fixture trees exist under `tests/fixtures/m018-p04-*` with README files.
- Fixture-staging helper exists under `scripts/verify/_helpers/m018-p04-build-fixture.sh`.
- P04-SUMMARY.md exists at [`.orchestrator/milestones/M018/phases/P04/P04-SUMMARY.md`](../../../../../milestones/M018/phases/P04/P04-SUMMARY.md) with the frontmatter named in Step 11 and a body documenting closure summary, risk-mitigation traceability, follow-ups for downstream phases, and verification result.
- CLAUDE.md AND AGENTS.md `orchestrator:recent-changes` blocks both name `M018/P04` (or `tier2`).
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P04/` exits 0.

### Files To Touch

- `scripts/dispatch/build-context.sh` (modify) — add `compression.tier2.*` config reads, the `_bc_apply_tier2` head-drop function (placed adjacent to `_bc_apply_tier1` per the existing dispatch-internal helper convention), the call-site wiring (between `_bc_apply_tier1` and `_bc_emit_payload_breakdown`), and the additive `tier2_savings_tokens` field on `_bc_emit_payload_breakdown`'s printf line.
- `scripts/lib/knowledge-filter.sh` (modify) — add `kf_get_tier2_enabled`, `kf_get_tier2_section_budget_tokens`, `kf_get_tier2_protected_tail_ratio` accessors mirroring the existing `kf_get_tier1_*` shape; reuse `kf_read_compression_scalar`.
- `.orchestrator/config.yml` (modify) — append `compression.tier2.{enabled,section_budget_tokens,protected_tail_ratio}` block under the existing `compression:` map.
- `templates/orchestrator-config-default.yml` (modify) — same `compression.tier2.*` block so freshly-installed projects inherit the defaults.
- `tests/fixtures/m018-p04-section-overflow/dispatch-payload-fixture.md` (create) — fixture payload with a Knowledge section large enough to exceed the default budget but with no preserved-pattern boundary inside the head-drop range.
- `tests/fixtures/m018-p04-section-overflow/README.md` (create) — fixture description.
- `tests/fixtures/m018-p04-boundary-refusal/dispatch-payload-fixture.md` (create) — fixture payload with an over-budget Upstream Context section whose head-drop boundary lands inside a 4+-backtick code fence (MIT-01 case) plus a frontmatter delimiter case.
- `tests/fixtures/m018-p04-boundary-refusal/README.md` (create) — fixture description.
- `scripts/verify/_helpers/m018-p04-build-fixture.sh` (create) — fixture-staging helper mirroring `scripts/verify/_helpers/m018-p03-build-fixture.sh`.
- `scripts/verify/m018-p04-tier2-head-drop.sh` (create)
- `scripts/verify/m018-p04-tier2-marker.sh` (create)
- `scripts/verify/m018-p04-tier2-boundary-refusal.sh` (create)
- `scripts/verify/m018-p04-tier2-emitter-additivity.sh` (create)
- `scripts/verify/m018-p04-tier2-disable-flag.sh` (create)
- `scripts/verify/m018-p04-tier2-preservation-self-check.sh` (create)
- `scripts/verify/m018-p04-dual-write-recent.sh` (create)
- [`.orchestrator/milestones/M018/phases/P04/P04-SUMMARY.md`](../../../../../milestones/M018/phases/P04/P04-SUMMARY.md) (create)
- `CLAUDE.md` (modify) — refresh `orchestrator:recent-changes` block to name M018/P04.
- `AGENTS.md` (modify) — same content (dual-write via `scripts/util/dual-write-runtime-md.sh`).

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