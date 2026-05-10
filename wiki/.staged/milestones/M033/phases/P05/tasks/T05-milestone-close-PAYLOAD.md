---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T05-milestone-close (Phase P05, Milestone M033)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-978 | ~1600 | required |
| Upstream Context | 980-1153 | ~11800 | required |
| Task Plan | 1155-1751 | ~7600 | required |
| State Context | 1753-1759 | ~100 | required |
| First-Turn Completeness | 1761-1819 | ~1100 | required |
| **Total** | | **~33000** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 808
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
hit_count: 808
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
hit_count: 808
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
hit_count: 808
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
hit_count: 703
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
hit_count: 703
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
hit_count: 703
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
hit_count: 808
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
hit_count: 703
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
hit_count: 703
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
hit_count: 703
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
hit_count: 808
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
hit_count: 808
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
hit_count: 808
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
hit_count: 703
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
hit_count: 703
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
hit_count: 703
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
hit_count: 808
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
hit_count: 703
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
hit_count: 703
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
hit_count: 808
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
hit_count: 808
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
hit_count: 703
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
hit_count: 703
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
hit_count: 703
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
hit_count: 358
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
hit_count: 358
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
hit_count: 358
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
hit_count: 384
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
hit_count: 384
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
hit_count: 374
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
     Project-owned slug-bearing verifiers live under tools/verify/ with the
     m033-p05-* prefix to avoid collision with M030/M031/[M032](../../../../../milestones/M032/index.md) and with
     M033/P01..P04 namespaces. Artifact bullets use the
     `Label: path (constraints) — create|modify` shape (NOT bare-backtick
     bullets — auto-loop --step=V eval's bare-backtick bullets as commands). -->

### Truths

- `commands/customblock-draft.md` exists as a canonical command-doc per MEM012 (YAML frontmatter `description:` field; `# orchestrator:customblock-draft` title; Prerequisites / State Check section; Core Workflow numbered sections; Output / Idempotency / Error Handling / Referenced Scripts sections). The body documents the FR-13/FR-14 contract: invokes `bash scripts/lifecycle/customblock-draft.sh --project-dir <path> [--yes] [--force]`, names the prescribed 5-section structure (`## Project`, `## Stack`, `## Source-Docs`, `## Entry Points`, `## Conventions`, `## Decisions` — `## Source-Docs` and `## Entry Points` are alternative, branch-dependent), names the marker-delimited `<!-- BEGIN CUSTOM -->` / `<!-- END CUSTOM -->` write region per FR-13, names the load-bearing tokens `customblock_drafted` (JSONL event) and `customblock-draft.complete` (start-state marker), names the upstream-output sources (`<project>/.orchestrator/memory/constitution.md` from P03/FR-3, `<project>/.orchestrator/knowledge/{architecture,conventions,decisions}/MEM-*.md` from P03/FR-7, `<project>/.orchestrator/intake/<timestamp>/reconciled-pre-spec.md` from P04/FR-9, `<project>/.orchestrator/intake/<timestamp>/ideation-pre-spec.md` from P04/FR-10), states the strict-aggregation invariant (no LLM-invented facts per Constitution XV), states the structurally-downstream-of-US-2 precondition (constitution-not-present → exit non-zero), and links to `references/customblock-format.md` as the FR-14 SSOT.
  - Check: `bash tools/verify/m033-p05-customblock-draft-md-shape.sh`

- `scripts/lifecycle/customblock-draft.sh` exists, is executable, and implements the FR-13/FR-14 contract per the spec. The driver: (a) accepts `--project-dir <path>` (defaults to `pwd`), `--yes` (auto-accepts editor-pass via `EDITOR=cat`-like passthrough), `--force` (regenerate in place); (b) verifies upstream prerequisites — if `<project-dir>/.orchestrator/memory/constitution.md` does NOT exist, exits non-zero with `constitution not present — run \"orchestrator:constitution\" first` diagnostic on stderr per US-7 AS-5 (structurally-downstream-of-US-2 gate); (c) detects which upstream outputs are present and chooses the section variant — `## Source-Docs` if `<project-dir>/.orchestrator/intake/<timestamp>/reconciled-pre-spec.md` or `ideation-pre-spec.md` exists; `## Entry Points` if neither intake artifact exists but ingest-codebase MEMs exist (existing-codebase branch); (d) drafts the custom block content by **strict aggregation** of upstream outputs — `## Project` line summarizing detected stack + branch (read from existing config or constitution preamble); `## Stack` lines verbatim from `knowledge/architecture/MEM-*.md` content fields (one bullet per MEM); `## Source-Docs` lines verbatim from the intake pre-spec H2 section headers OR `## Entry Points` lines from ingest-codebase architecture MEMs; `## Conventions` lines verbatim from `knowledge/conventions/MEM-*.md` content fields; `## Decisions` lines verbatim from `knowledge/decisions/MEM-*.md` content fields including any `MEM-DR-*` cross-references from FR-8 rich-context import — explicitly NO LLM invocation, NO conversus invocation, NO model-routing in the draft path (Constitution XV); (e) handles re-run idempotency: when the existing `CLAUDE.md` between `<!-- BEGIN CUSTOM -->` and `<!-- END CUSTOM -->` is non-empty AND `--force` was NOT passed, exits 0 with `no changes` diagnostic and the file byte-identical (preserves operator edits per US-7 AS-3); when `--force` is passed and the existing block is non-empty, regenerates with stderr warning `--force discards prior operator edits` per US-7 AS-4; (f) hands the draft to the operator's editor (`$EDITOR`, default `vi`) when `--yes` is NOT set; under `--yes`, skips the editor pass and writes the draft directly; (g) writes the reviewed content into the marker-delimited region of `<project-dir>/CLAUDE.md` — operator additions beyond the 5 prescribed sections (e.g., `## Notes`) MUST be preserved verbatim per US-7 AS-2 (the prescriptive structure is a *floor*, not a *ceiling*); (h) writes `<project-dir>/.orchestrator/start-state/customblock-draft.complete` marker per FR-20 via `bash scripts/util/start-state-markers.sh write customblock-draft <project-dir>`; (i) emits `customblock_drafted` JSONL event per FR-22 via `bash scripts/util/jsonl-event-emitter.sh emit customblock_drafted <payload>` (payload includes `project_dir`, `sections_drafted: [...]`, `force: true|false`); (j) appends a one-line FR-21 dual-write Recent Changes fragment via `bash scripts/util/dual-write-runtime-md.sh --root <project-dir> --marker recent-changes --append-entry '<fragment>'` per the P03/T05-harmonized API. Bash 3.2 compatible per MEM001 (no `declare -A`, no process substitution, no command-substitution-with-pipes). Zero `speckit.*` references in any code path or output (CON-3 / Principle XVI).
  - Check: `bash tools/verify/m033-p05-customblock-draft-sh-shape.sh`

- `references/customblock-format.md` exists as the FR-14 SSOT documenting the prescriptive 5-section custom-block format (per #Q-8). The doc names each section header verbatim (`## Project`, `## Stack`, `## Source-Docs`, `## Entry Points`, `## Conventions`, `## Decisions`), documents the `## Source-Docs` vs `## Entry Points` branch-dependent variant rule, documents the marker-delimited write region (`<!-- BEGIN CUSTOM -->` / `<!-- END CUSTOM -->`), states the *floor-not-ceiling* discipline (operator additions beyond the 5 sections preserved verbatim per US-7 AS-2), states the strict-aggregation invariant (no LLM-invented facts per Constitution XV), and names the upstream-output source map (each section ↔ its upstream sub-flow output path). Includes a worked example showing the rendered custom block for a fixture that completed US-1 + US-2 + US-3.
  - Check: `bash tools/verify/m033-p05-customblock-format-ref-shape.sh`

<dispatch-volatile>

## Upstream Context


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


### P04 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P04"
parent: "M033"
milestone: "M033"
provides:
  - "commands/materials-intake.md FR-9 surface;scripts/lifecycle/materials-intake.sh FR-9 deterministic driver with 3 closed-enum SSOT blocks + filename-heuristic labeling + 3-category CON-4 drift detection + terminal/file-based reconciliation UX + byte-deterministic reconciled pre-spec + FR-20 marker + FR-22 JSONL emit + FR-21 dual-write fragment;tools/verify/m033-p04-materials-intake-md-shape.sh (19 PASS);tools/verify/m033-p04-materials-intake-sh-shape.sh (28 PASS),commands/ideation.md (FR-10 doc surface) + scripts/lifecycle/ideation.sh (FR-10 driver: 7-question grilling-protocol flow + CON-6 resume + MIT-007 third-arg wiring on every ask_one + opt-in --with-conversus-stress-test default OFF per #Q-7) + tools/verify/m033-p04-ideation-md-shape.sh (19 PASS) + tools/verify/m033-p04-ideation-sh-shape.sh (29 PASS,MIT-007 token-count assertion load-bearing),FR-12 migrate-then-ingest dup-prevention sentinel handling in scripts/lifecycle/ingest-codebase.sh; is_migrate_derived_mem helper; skip-duplicate-from-migrate diagnostic; fenced SSOT block; commands/ingest-codebase.md FR-12 Edge Case paragraph; tools/verify/m033-p04-migrate-then-ingest-shape.sh (15-check shape verifier with positive+negative functional smoke),FR-11/FR-12 migrate-routing real implementation in scripts/lifecycle/start.sh (replaces P01 vacuous migrate_routing_stub via deprecated-alias forwarding); translate_from_to_source helper (gsd-v1->gsd1,gsd-v2->gsd2,spec-kit->speckit); US-6 AS-5 unsupported-tooling diagnostic; FR-12 migrate-then-ingest invocation gated on src/ presence; --dry-run gate that skips migrate.sh/ingest-codebase.sh while preserving load-bearing tokens; tools/verify/m033-p04-migrate-routing-shape.sh (30-check shape + functional translate verifier),SC-4 acceptance script tests/m033-acceptance/p04-materials-intake.sh (11 PASS — PBJ file-based UX + small-fixture terminal-interactive byte-determinism + JSONL/marker assertion + US-4 AS-5 fallback path);SC-5 acceptance script tests/m033-acceptance/p04-ideation.sh (11 PASS — full 7-question session + CON-6 resume + opt-in conversus stress-test + zero-conversus default + MIT-007 contradiction-detection live-API exercise);SC-6 acceptance script tests/m033-acceptance/p05-migrate-routing.sh (9 PASS — three --from variants under --dry-run + dup-prevention via direct ingest invocation + .aider unsupported-tooling under --branch migrating override);three SC-wrapper verifiers tools/verify/m033-p04-acceptance-shape-sc4/5/6.sh (12-13 PASS each — token-presence shape check + functional run + exit propagation);phase-suite aggregator tools/verify/m033-p04-phase-suite.sh chaining 9 P04 verifiers in T01..T05 dependency order (pass=9 fail=0);cross-phase regression check tools/verify/m033-p04-cross-phase-regression.sh re-running P01/P02/P03 phase-suites (pass=3 fail=0);bidirectional scope-guard tools/verify/m033-p04-scope-guard.sh (5 forbidden P05 surfaces absent + 20 allowed P04 deliverables present,pass=25 fail=0)"
requires:
  - "P01,P02,P03"
affects:
  - "P05"
key_files:
  - "commands/materials-intake.md;scripts/lifecycle/materials-intake.sh;tools/verify/m033-p04-materials-intake-md-shape.sh;tools/verify/m033-p04-materials-intake-sh-shape.sh,commands/ideation.md,scripts/lifecycle/ideation.sh,tools/verify/m033-p04-ideation-md-shape.sh,tools/verify/m033-p04-ideation-sh-shape.sh,scripts/lifecycle/ingest-codebase.sh,commands/ingest-codebase.md,tools/verify/m033-p04-migrate-then-ingest-shape.sh,scripts/lifecycle/start.sh,tools/verify/m033-p04-migrate-routing-shape.sh,tests/m033-acceptance/p04-materials-intake.sh,tests/m033-acceptance/p04-ideation.sh,tests/m033-acceptance/p05-migrate-routing.sh,tools/verify/m033-p04-acceptance-shape-sc4.sh,tools/verify/m033-p04-acceptance-shape-sc5.sh,tools/verify/m033-p04-acceptance-shape-sc6.sh,tools/verify/m033-p04-phase-suite.sh,tools/verify/m033-p04-cross-phase-regression.sh,tools/verify/m033-p04-scope-guard.sh"
key_decisions:
  - "deterministic-not-LLM-detector-uses-grep-awk-sed-only-no-model-routing;byte-deterministic-prespec-body-no-embedded-timestamps-only-directory-name-timestamp-pinned-via-M033_INTAKE_TIMESTAMP;ask_one-per-item-with-_GRILLING_CURRENT_QKEY-empty-because-labeling-and-reconciliation-are-independent-of-contradiction-detection;closed-resolution-enum-(accept-primary-accept-supplementary-manual-edit-defer)-enforced-via-case-validation-with-fallback-to-accept-primary-on-unrecognized;README-oracle-excluded-from-intake-via-basename-pattern-match-because-the-fixture-README-is-ground-truth-not-a-material;optional-materials_intake_stub-rewiring-in-start.sh-deferred-to-T05-cross-phase-regression-per-plan-Notes,MIT-007-wiring-via-ideate_one-helper-passing-PARTIAL_ANSWERS-as-third-arg-on-every-ask_one-call;CON-6-resume-via-in-flight-scan-of-intake-dir-for-partial-answers-yml-with-fewer-than-7-keys-before-honoring-M033_IDEATION_TIMESTAMP-env-override;recommendations-are-placeholder-operator-supplied-because-ideation-has-no-domain-specific-default;negative-grep-skip-comment-lines-via-grep-Ev-leading-hash-so-doc-text-mentioning-declare-A-or-process-substitution-doesnt-trip-the-MEM001-negative-assertions;Q-7-stress-test-flag-gated-by-fixed-string-shape-WITH_STRESS_TEST-eq-1-rather-than-regex-which-needed-escaping,one-way-READ-contract-no-M015-modification;is_migrate_derived_mem-helper-uses-plain-grep-qF-no-process-substitution;dup-prevention-check-fires-after-stable-id-computation-and-before-printf-emit-block;sentinel-grep-functional-smoke-shapes-NOT-emit-function-end-to-end-test-deferred-to-T05-SC-6,D-T04-01:--dry-run-gate-added-skip-migrate-sh-and-ingest-invocations-while-preserving-load-bearing-tokens-because-SC-1-fixture-4-runs-yes-dry-run-against-stub-gsd-fixture-and-actual-migrate-sh-call-would-fail;D-T04-02:keep-migrate_routing_stub-as-deprecated-alias-forwarding-to-migrate_routing-AND-emitting-legacy-would-execute-token-rather-than-deleting-it-preserves-SC-1-AD-15-backward-compat-without-modifying-SC-1-acceptance-script;D-T04-03:translate_from_to_source-uses-plain-case-and-echo-no-associative-arrays-MEM001-bash-3.2-compat;D-T04-04:no-FR-21-dual-write-fragment-for-migrate-routing-FR-21-closed-callsite-list-covers-FR-3/FR-7/FR-9/FR-10/FR-13-only-FR-11-is-glue-not-content-authoring-surface,D-T05-01:SC-4-test-1-uses-PBJ-fixture-against-file-based-UX-not-terminal-interactive-because-T01-functional-smoke-confirmed-14-conflicts-greater-than-5-threshold-so-byte-determinism-asserted-on-conflicts-md-instead-of-reconciled-pre-spec;D-T05-02:SC-4-test-2-introduces-small-2-material-synthetic-fixture-PRIMARY-BRIEF-md-OTHER-NOTES-md-with-2-orphan-references-to-exercise-terminal-interactive-path-and-byte-deterministic-reconciled-pre-spec-emission;D-T05-03:SC-5-MIT-007-contradiction-test-shifted-from-cross-question-ideation-flow-to-direct-grilling-shell-ask_one-exercise-because-ideation-asks-each-qkey-once-and-cannot-naturally-produce-same-qkey-contradiction-within-a-single-session-the-load-bearing-MIT-007-assertion-is-now-static-shape-check-of-ask_one-3rd-arg-wiring-plus-live-API-exercise-of-the-underlying-grilling-shell-contradiction-detection-block;D-T05-04:SC-6-uses---dry-run-flag-on-start-sh-invocations-for-three---from-variants-because-real-migrate-sh-against-synthetic-fixtures-has-side-effects-beyond-T05-scope-the---dry-run-gate-shipped-by-T04-skips-migrate-sh-and-ingest-codebase-invocations-while-emitting-load-bearing-tokens;D-T05-05:SC-6-dup-prevention-test-uses-direct-ingest-codebase-invocation-against-pre-seeded-fixture-not-end-to-end-start-sh-migrate-sh-ingest-because-this-separates-FR-11-migrate-routing-from-FR-12-dup-prevention-at-test-layer-each-verified-against-the-surface-it-controls-per-task-plan-Notes;D-T05-06:SC-6-unsupported-tooling-test-stages-aider-directory-AND-uses---branch-migrating-override-because-aider-does-not-match-the-SSOT-migrating-rule-patterns-gsd-gsd2-specify-and-without-the-override-falls-through-to-greenfield-empty;D-T05-07:wrapper-verifiers-use-grep-qF-double-dash-not-bare-grep-qF-because---with-conversus-stress-test-token-was-being-interpreted-as-grep-flag-defensive-double-dash-applied-to-all-three-wrappers-for-consistency"
patterns_established:
  - "4-fenced-SSOT-blocks-pattern-(material-extensions+labeling-enum+drift-categories+resolution-enum)-with-load-bearing-token-grep-tripwires-for-shape-verifier;recommend_label-filename-heuristic-via-uppercase-tr-+-case-glob-pattern-match;3-detector-pipeline-(id-misalignment-via-asymmetric-token-reference-+-scheme-contradiction-via-key-value-extraction-and-cross-doc-diff-+-orphan-reference-via-ref-vs-def-set-difference)-running-sequentially-with-de-duped-output-accumulator;byte-deterministic-prespec-pattern-(env-pinned-directory-name-timestamp-NOT-embedded-in-body-+-canonical-section-ordering-by-label-category-+-cat-of-source-material-bodies-verbatim-+-provenance-comments-as-trailing-Reconciliation-Log-section);ask_one-output-capture-via-sed-extraction-of-answer-token-(out=$(ask_one ...);label=$(echo $out | sed -n s/^answer: //p | tail -1));parallel-bash-3.2-safe-detector-output-via-sort-u-+-grep-c-counting-with-||true-tolerance,ideate_one helper as MIT-007 third-arg wiring proof-point: every ask_one invocation in driver routes through one function that always supplies the partial-answers.yml path; verifier asserts via token-count grep on ask_one calls (≥4 whitespace-tokens proves function-name + 3 args);CON-6 in-flight resume scan: ls intake-dir then count keys per partial-answers.yml takes precedence over M033_IDEATION_TIMESTAMP env override which itself takes precedence over fresh date -u timestamp;case-statement-per-index for parallel indexed array dereference (bash 3.2 — no nameref ${!var} game);sourceability-of-grilling-shell with ideate_one wrapper to set _GRILLING_CURRENT_QKEY before each ask_one (matches constitution-author.sh pattern);negative-grep-skips-comment-lines via grep -Ev leading-hash so doc-prose negative assertions aren't tripped by self-reference,fenced-SSOT-block-naming-convention-dup-prevention-sentinel;additive-extension-with-zero-behavior-change-for-projects-without-migrate-derived-MEMs;helper-call-count-asserted-at-3-occurrences-as-emit-function-coverage-tripwire;synthetic-MEM-sentinel-presence-grep-as-functional-shape-smoke-without-sourcing-target-script,deprecated-alias-forwarding-pattern-with-load-bearing-token-emission-preserved-for-AD-15-cross-phase-regression-passthrough;dry-run-gate-pattern-skip-side-effects-but-emit-load-bearing-tokens-so-acceptance-tests-can-verify-routing-without-invoking-real-migrators;spec-shape-impl-shape-translation-helper-pattern-operator-facing-flag-decoupled-from-internal-flag-names-via-thin-case-helper;functional-translate-extraction-pattern-awk-extracts-helper-body-then-bash-c-loads-it-into-clean-subshell-for-positive+negative-functional-smoke-without-sourcing-main-script,dual-fixture-strategy-for-acceptance-byte-determinism-large-deterministic-PBJ-fixture-exercises-overflow-file-based-path-while-synthetic-2-material-fixture-exercises-terminal-interactive-path-each-tested-against-its-load-bearing-UX-branch;tolerance-tier-pattern-in-SC-acceptance-with-fallback-pass-conditions-when-driver-API-permits-multiple-valid-paths-eg-out-of-scope-only-test-tolerates-both-AS-5-fallback-and-no-conflicts-completion-because-filename-heuristic-may-classify-MISC-NOTES-as-supplementary-not-out-of-scope;direct-API-exercise-instead-of-driver-traversal-for-load-bearing-cross-cutting-contracts-MIT-007-exercises-grilling-shell-ask_one-directly-with-pre-seeded-context-file-because-ideation-driver-cannot-produce-same-qkey-contradiction-naturally;dry-run-gate-pattern-applied-at-acceptance-layer-three---from-variant-tests-pass-start-sh---dry-run-because-real-migrate-sh-against-synthetic-fixtures-has-side-effects-beyond-test-scope;separated-test-layer-pattern-FR-11-migrate-routing-tested-via-token-emission-FR-12-dup-prevention-tested-via-direct-ingest-codebase-invocation-each-against-its-controlling-surface;branch-override-for-edge-case-coverage-aider-fixture-falls-through-to-greenfield-empty-without---branch-migrating-override-which-is-the-mechanism-to-exercise-empty-DETECTED_FROM-unsupported-tooling-diagnostic;defensive-grep-double-dash-flag-handling-in-token-shape-verifiers-grep-qF-double-dash-token-prevents-tokens-starting-with-dash-from-being-interpreted-as-grep-flags;bidirectional-scope-guard-pattern-reused-from-P02-P03-five-forbidden-P05-customblock-paired-launch-surfaces-plus-twenty-allowed-P04-T01-T05-deliverables-catches-overflow-and-underflow;phase-suite-aggregator-pattern-with-newline-delimited-VERIFIERS-iterated-under-IFS-swap-canonical-SUMMARY-final-line-pass-N-fail-M;cross-phase-regression-newline-delimited-suites-iterated-the-same-way-AD-15-discipline-made-concrete"
drill_down_paths:
  - "[.orchestrator/milestones/M033/phases/P04/tasks/T01-materials-intake-SUMMARY.md](../../../../../milestones/M033/phases/P04/tasks/T01-materials-intake-SUMMARY.md), [.orchestrator/milestones/M033/phases/P04/tasks/T02-ideation-SUMMARY.md](../../../../../milestones/M033/phases/P04/tasks/T02-ideation-SUMMARY.md), [.orchestrator/milestones/M033/phases/P04/tasks/T03-migrate-then-ingest-dup-prevention-SUMMARY.md](../../../../../milestones/M033/phases/P04/tasks/T03-migrate-then-ingest-dup-prevention-SUMMARY.md), [.orchestrator/milestones/M033/phases/P04/tasks/T04-migrate-routing-SUMMARY.md](../../../../../milestones/M033/phases/P04/tasks/T04-migrate-routing-SUMMARY.md), [.orchestrator/milestones/M033/phases/P04/tasks/T05-acceptance-and-phase-suite-SUMMARY.md](../../../../../milestones/M033/phases/P04/tasks/T05-acceptance-and-phase-suite-SUMMARY.md)"
duration: "230m"
verification_result: "pass"
completed_at: "2026-05-04T15:18:23Z"
observability_surfaces:
  - "none"
---

P04 ships M033's three middle sub-flows — materials-intake (FR-9), ideation (FR-10), and migrate-routing (FR-11/FR-12) — closing the path from raw heterogeneous inputs to an `orchestrator:specify`-consumable pre-spec across all four onboarding branches.

T01 delivered `commands/materials-intake.md` + `scripts/lifecycle/materials-intake.sh` (767 lines) implementing the FR-9 deterministic driver: 4 fenced SSOT blocks (material-extensions, labeling-enum, drift-categories, resolution-enum) with load-bearing token-grep tripwires; filename-heuristic labeling via `recommend_label` (uppercase + case glob); CON-4 3-detector pipeline (ID-misalignment via asymmetric token-reference, scheme-contradiction via key-value diff, orphan-reference via ref-vs-def set difference) — explicitly NO LLM-magic merge; ≤5/>5 conflict UX split with byte-deterministic reconciled-pre-spec emission (env-pinned directory-name timestamp, canonical section ordering, verbatim source bodies, trailing Reconciliation Log). Verified: 19 + 28 PASS across md-shape and sh-shape verifiers.

T02 delivered `commands/ideation.md` + `scripts/lifecycle/ideation.sh` (462 lines) implementing the FR-10 7-question grilling-protocol flow consuming P02's `grilling-shell.sh` `ask_one` API. Load-bearing MIT-007 contract: an `ideate_one` helper routes EVERY `ask_one` invocation through one function that always supplies `partial-answers.yml` as the third (`<context-file>`) arg. CON-6 partial-answer persistence after each question, with in-flight resume scan taking precedence over `M033_IDEATION_TIMESTAMP` env override. Opt-in `--with-conversus-stress-test` flag default OFF per #Q-7. Verified: 19 + 29 PASS, with the sh-shape verifier's MIT-007 token-count assertion (≥4 whitespace-tokens proves function-name + 3 args) as load-bearing tripwire.

T03 extended `scripts/lifecycle/ingest-codebase.sh` (P03 deliverable) with FR-12 migrate-then-ingest duplicate-MEM prevention: a fenced `dup-prevention-sentinel` SSOT block, an `is_migrate_derived_mem` helper (plain `grep -qF`, bash 3.2 compatible), and 3 identical check insertions in `emit_architecture_mem` / `emit_convention_mem` / `emit_decision_mem` that fire after `stable_id` computation and before `printf`-emit. One-way READ contract — `scripts/migrate/migrate.sh` ([M015](../../../../../milestones/M015/index.md)) is NOT modified. Net behavior change is zero for projects without migrate-derived MEMs (P03 SC-3 still 29/29). Verified: 15-check shape verifier (positive + negative functional smoke) PASS.

T04 replaced P01's vacuous `migrate_routing_stub` in `scripts/lifecycle/start.sh` with the real FR-11 implementation: `translate_from_to_source` helper (gsd-v1→gsd1, gsd-v2→gsd2, spec-kit→speckit) decoupling spec-shape operator-facing flags from impl-shape internal flags; full `migrate_routing` function with US-6 AS-5 unsupported-tooling diagnostic; FR-12 migrate-then-ingest invocation gated on `src/` presence. Two AD-15 backward-compat decisions: (a) `migrate_routing_stub` retained as deprecated alias forwarding to `migrate_routing` AND emitting the legacy `would-execute: migrate-routing-stub` token, so SC-1 fixture-4 needed zero modifications; (b) `--dry-run` gate skips real `migrate.sh` / `ingest-codebase.sh` invocations while preserving load-bearing routing tokens, so SC-1 fixture-4's stub `.gsd/v1-roadmap.yml` doesn't trigger an actual migration. Verified: 30 PASS, with SC-1 cross-phase regression unchanged at 14 PASS.

T05 closed the phase: SC-4 acceptance (`tests/m033-acceptance/p04-materials-intake.sh`, 11 PASS — dual-fixture strategy: PBJ fixture exercises file-based UX overflow path with byte-determinism asserted on `conflicts.md`; small synthetic 2-material fixture exercises terminal-interactive path with byte-determinism on `reconciled-pre-spec.md`); SC-5 acceptance (`tests/m033-acceptance/p04-ideation.sh`, 11 PASS — full 7-question session + CON-6 resume + opt-in conversus-stress-test invocation count via JSONL + zero-conversus default + MIT-007 contradiction-detection live-API exercise of grilling-shell `ask_one` directly with pre-seeded context file, since ideation's per-qkey-once flow can't produce same-qkey contradictions naturally); SC-6 acceptance (`tests/m033-acceptance/p05-migrate-routing.sh`, 9 PASS — three `--from` variants under `--dry-run` + dup-prevention via direct ingest invocation + `.aider/` unsupported-tooling under `--branch migrating` override); 3 SC-wrapper verifiers; phase-suite aggregator (9 PASS, T01..T05 dependency order); cross-phase regression (P01 + P02 + P03 phase-suites all green, 3 PASS); bidirectional scope-guard (5 forbidden P05 surfaces absent + 20 allowed P04 deliverables present, 25 PASS).

Verification: `tools/verify/m033-p04-phase-suite.sh pass=9 fail=0`; `tools/verify/m033-p04-cross-phase-regression.sh pass=3 fail=0`; `tools/verify/m033-p04-scope-guard.sh pass=25 fail=0`; standalone-gate `pass=7 skip=0 fail=0`; P01/P02/P03 phase-suites still PASS; `check-plans.sh` advisory warnings all pre-existing M002–M005 (none from P04). Note that the migrate-routing acceptance script is intentionally named `p05-migrate-routing.sh` per MIT-002 explicit-enumeration model — the `p05-` prefix is load-bearing for P05's `run-acceptance-battery.sh` filename enumeration, NOT a renaming error.

Patterns established: dual-fixture strategy for acceptance byte-determinism (large deterministic fixture for overflow path, synthetic small fixture for terminal-interactive path); deprecated-alias-forwarding with legacy-token preservation for AD-15 cross-phase regression passthrough; dry-run-gate skip-side-effects-but-emit-load-bearing-tokens; spec-shape vs impl-shape translation helper for operator-facing flag decoupling; `ideate_one`-style per-call wrapper as proof-point for cross-cutting MIT-007-style wiring contracts; tolerance-tier acceptance assertions when driver permits multiple valid paths; direct API exercise instead of driver traversal for cross-cutting contracts that can't be naturally exercised end-to-end; defensive `grep -qF --` for tokens starting with `--`; bidirectional scope-guard (forbidden + allowed) reused from P02/P03; one-way READ contract for additive-extension into closed surfaces (M015 untouched).

P04 unblocks P05 (customblock-drafter + paired-launch + friendly-tester pass + milestone close). Open follow-ups deferred to P05: (a) optional `materials_intake_stub` rewiring in `start.sh` if P05's cross-phase regression surfaces it (none required for P04 close); (b) MIT-007 wiring is verified at static-shape + direct-API levels — full end-to-end ideation contradiction-detection exercise remains a P05 friendly-tester-pass observation. Skip-zero acceptance closure: 31 PASS across 3 acceptance scripts + 9 phase-suite + 3 cross-phase + 25 scope-guard = 68 PASS, 0 fail, 0 skip; no signed-attestation needed per MIT-001.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P05"
milestone: "M033"
name: "M033 milestone close — phase-suite + cross-phase regression + scope-guard + M033-VALIDATED marker + M033-SUMMARY.md + milestone-grain unit_close JSONL (AD-7 three-part close gate)"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

T05 closes the milestone. Ships the P05 phase-suite aggregator, cross-phase regression, bidirectional scope-guard, the AD-7 three-part close gate (`M033-VALIDATED` marker + `M033-SUMMARY.md` + milestone-grain `unit_close` JSONL), and three shape verifiers for the close-state artifacts.

Files that MUST exist on disk at task-start (verified via `ls -la` per Plan-Time Discipline rule 1):

- `commands/customblock-draft.md` (T01)
- `scripts/lifecycle/customblock-draft.sh` (T01)
- `references/customblock-format.md` (T01)
- `scripts/lifecycle/start.sh` (T02 + T03 extended)
- `tests/m033-acceptance/p06-customblock-draft.sh` (T04)
- `tests/m033-acceptance/p08-with-wiki-passthrough.sh` (T04)
- `tests/m033-acceptance/p08-with-github-passthrough.sh` (T04)
- `tests/m033-acceptance/run-acceptance-battery.sh` (T04)
- All T01..T04 verifiers under `tools/verify/m033-p05-*` (8 files: 3 from T01, 1 from T02, 1 from T03, 4 from T04)
- All P01..P04 phase-suites: `tools/verify/m033-p01-phase-suite.sh`, `tools/verify/m033-p02-phase-suite.sh`, `tools/verify/m033-p03-phase-suite.sh`, `tools/verify/m033-p04-phase-suite.sh`
- `scripts/verify/standalone-gate.sh` (P03/T01) — invoked by cross-phase regression for CON-3 invariant check
- `scripts/verify/validate-milestone.sh` (framework) — invoked at close to compute NNN
- `scripts/util/jsonl-event-emitter.sh` (P02/T01) — emits `unit_close` record (note: `unit_close` is a milestone-grain event type — verify it's in the closed enum or extend additively)
- `tests/m033-acceptance/friendly-tester-pass/validate-report.sh` (P01) — SC-15 mechanical gate

Reference templates:
- `templates/milestone-summary.md` — defines the M033-SUMMARY.md frontmatter shape
- [`.orchestrator/milestones/M030/M030-SUMMARY.md`](../../../../../milestones/M030/M030-SUMMARY.md) and [`.orchestrator/milestones/M031/M031-SUMMARY.md`](../../../../../milestones/M031/M031-SUMMARY.md) — milestone-summary precedents to model on
- `.orchestrator/milestones/M030/M030-VALIDATED` — VALIDATED marker precedent (if present)

## Description

T05 ships ELEVEN deliverables grouped into three concerns:

**Concern A: Phase-level aggregators (3 files)**

1. **`tools/verify/m033-p05-phase-suite.sh`** — chains all 9 P05 verifiers in dependency order; emits `SUMMARY: m033-p05-phase-suite.sh pass=N fail=M`.

2. **`tools/verify/m033-p05-cross-phase-regression.sh`** — re-runs `m033-p01-phase-suite.sh` + `m033-p02-phase-suite.sh` + `m033-p03-phase-suite.sh` + `m033-p04-phase-suite.sh` + `bash scripts/verify/standalone-gate.sh constitution` and asserts each exits 0; AD-15 cross-phase regression discipline.

3. **`tools/verify/m033-p05-scope-guard.sh`** — bidirectional scope-guard (forbidden-presence + allowed-presence whitelist); asserts no out-of-scope writes (M032 internals, [M013](../../../../../milestones/M013/index.md) internals, M015 internals, M020 schema) AND every P05 deliverable is on disk.

**Concern B: AD-7 three-part close gate artifacts (3 files)**

4. **`.orchestrator/milestones/M033/M033-VALIDATED`** — milestone-validated marker file; gated on AD-7 (SC-14 `skip=0` AND SC-15 friendly-tester verdict AND SC-16 NNN ≥ 15).

5. **[`.orchestrator/milestones/M033/M033-SUMMARY.md`](../../../../../milestones/M033/M033-SUMMARY.md)** — milestone summary with canonical M030/M031 shape; references SC-1..SC-16 verdicts.

6. **`.orchestrator/execution-log.jsonl` append** — single milestone-grain `unit_close` JSONL record; modeled on M030/M031 precedents.

**Concern C: Close-state shape verifiers (3 files)**

7. **`tools/verify/m033-p05-validated-marker-shape.sh`** — asserts `M033-VALIDATED` marker exists with non-empty content; documents the AD-7 three-part gate.

8. **`tools/verify/m033-p05-summary-md-shape.sh`** — asserts `M033-SUMMARY.md` shape (frontmatter + SC-1..SC-16 references + standalone-gate verdict).

9. **`tools/verify/m033-p05-unit-close-jsonl-shape.sh`** — asserts a single milestone-grain `unit_close` record was appended.

Plus the close-state authorship logic: T05 manually authors M033-VALIDATED and M033-SUMMARY.md (or extends an existing close-helper script — implementation choice at execution time) and emits the `unit_close` JSONL record via `bash scripts/util/jsonl-event-emitter.sh emit unit_close <payload>`.

## Steps

### 1. Author `tools/verify/m033-p05-phase-suite.sh`

Chain all 9 P05 verifiers in dependency order, emit canonical `SUMMARY:` line:

```bash
#!/usr/bin/env bash
# tools/verify/m033-p05-phase-suite.sh
# M033/P05 phase-suite aggregator -- chains 9 P05 verifiers.
set -u
PASS=0; FAIL=0

VERIFIERS="
tools/verify/m033-p05-customblock-draft-md-shape.sh
tools/verify/m033-p05-customblock-draft-sh-shape.sh
tools/verify/m033-p05-customblock-format-ref-shape.sh
tools/verify/m033-p05-with-wiki-passthrough-shape.sh
tools/verify/m033-p05-with-github-passthrough-shape.sh
tools/verify/m033-p05-acceptance-shape-sc7.sh
tools/verify/m033-p05-acceptance-shape-sc9.sh
tools/verify/m033-p05-acceptance-shape-sc10.sh
tools/verify/m033-p05-acceptance-battery-shape.sh
"

OLDIFS="$IFS"
IFS=$'\n'
for v in $VERIFIERS; do
    [ -z "$v" ] && continue
    bash "$v" > /dev/null 2>&1
    rc=$?
    if [ "$rc" -eq 0 ]; then
        PASS=$((PASS+1))
        printf 'PASS: %s\n' "$v"
    else
        FAIL=$((FAIL+1))
        printf 'FAIL: %s (rc=%d)\n' "$v" "$rc"
    fi
done
IFS="$OLDIFS"

printf 'SUMMARY: m033-p05-phase-suite.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

### 2. Author `tools/verify/m033-p05-cross-phase-regression.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m033-p05-cross-phase-regression.sh
# AD-15 cross-phase regression: re-run P01..P04 phase-suites + standalone-gate.
set -u
PASS=0; FAIL=0

SUITES="
tools/verify/m033-p01-phase-suite.sh
tools/verify/m033-p02-phase-suite.sh
tools/verify/m033-p03-phase-suite.sh
tools/verify/m033-p04-phase-suite.sh
"

OLDIFS="$IFS"
IFS=$'\n'
for s in $SUITES; do
    [ -z "$s" ] && continue
    bash "$s" > /dev/null 2>&1
    rc=$?
    if [ "$rc" -eq 0 ]; then
        PASS=$((PASS+1))
        printf 'PASS: %s\n' "$s"
    else
        FAIL=$((FAIL+1))
        printf 'FAIL: %s (rc=%d)\n' "$s" "$rc"
    fi
done
IFS="$OLDIFS"

# CON-3 / Principle XVI standalone-gate invariant must still hold.
bash scripts/verify/standalone-gate.sh constitution > /dev/null 2>&1
GATE_RC=$?
if [ "$GATE_RC" -eq 0 ]; then
    PASS=$((PASS+1))
    printf 'PASS: standalone-gate constitution (CON-3 / Principle XVI)\n'
else
    FAIL=$((FAIL+1))
    printf 'FAIL: standalone-gate constitution (rc=%d)\n' "$GATE_RC"
fi

printf 'SUMMARY: m033-p05-cross-phase-regression.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

### 3. Author `tools/verify/m033-p05-scope-guard.sh`

Bidirectional scope-guard per the P02/P03/P04 pattern:

```bash
#!/usr/bin/env bash
# tools/verify/m033-p05-scope-guard.sh
# Bidirectional scope-guard: forbidden-presence + allowed-presence.
set -u
PASS=0; FAIL=0

# Forbidden-presence: out-of-scope surfaces MUST NOT be touched by P05.
# (M032 internals, M013 internals, M015 internals, M020 schema.)
FORBIDDEN="
wiki/mkdocs.yml
wiki/overrides
packaging/bundle/manifest.yml.M032-edit
scripts/migrate/migrate.sh.M033-edit
scripts/lifecycle/github-init.sh.M033-edit
knowledge/spec/MEM-NEW-KIND.md
"
OLDIFS="$IFS"
IFS=$'\n'
for f in $FORBIDDEN; do
    [ -z "$f" ] && continue
    if [ -e "$f" ]; then
        FAIL=$((FAIL+1))
        printf 'FAIL: forbidden-presence: %s exists (out-of-scope write)\n' "$f"
    else
        PASS=$((PASS+1))
        printf 'PASS: forbidden-presence: %s absent\n' "$f"
    fi
done
IFS="$OLDIFS"

# Allowed-presence: every P05 deliverable MUST be on disk.
ALLOWED="
commands/customblock-draft.md
scripts/lifecycle/customblock-draft.sh
references/customblock-format.md
scripts/lifecycle/start.sh
tests/m033-acceptance/p06-customblock-draft.sh
tests/m033-acceptance/p08-with-wiki-passthrough.sh
tests/m033-acceptance/p08-with-github-passthrough.sh
tests/m033-acceptance/run-acceptance-battery.sh
tools/verify/m033-p05-customblock-draft-md-shape.sh
tools/verify/m033-p05-customblock-draft-sh-shape.sh
tools/verify/m033-p05-customblock-format-ref-shape.sh
tools/verify/m033-p05-with-wiki-passthrough-shape.sh
tools/verify/m033-p05-with-github-passthrough-shape.sh
tools/verify/m033-p05-acceptance-shape-sc7.sh
tools/verify/m033-p05-acceptance-shape-sc9.sh
tools/verify/m033-p05-acceptance-shape-sc10.sh
tools/verify/m033-p05-acceptance-battery-shape.sh
tools/verify/m033-p05-phase-suite.sh
tools/verify/m033-p05-cross-phase-regression.sh
tools/verify/m033-p05-scope-guard.sh
tools/verify/m033-p05-validated-marker-shape.sh
tools/verify/m033-p05-summary-md-shape.sh
tools/verify/m033-p05-unit-close-jsonl-shape.sh
"
IFS=$'\n'
for f in $ALLOWED; do
    [ -z "$f" ] && continue
    if [ -e "$f" ]; then
        PASS=$((PASS+1))
        printf 'PASS: allowed-presence: %s exists\n' "$f"
    else
        FAIL=$((FAIL+1))
        printf 'FAIL: allowed-presence: %s missing (P05 deliverable)\n' "$f"
    fi
done
IFS="$OLDIFS"

# Customblock-draft must additively-extend, not over-author M020 schema.
# Negative grep on customblock-draft.sh for any M020 schema-extension token.
NONCOMMENT=$(grep -Ev '^[[:space:]]*#' scripts/lifecycle/customblock-draft.sh 2>/dev/null || true)
for forbidden_kind in 'mkdir.*knowledge/[a-z]*kind' 'kind:.*new'; do
    if printf '%s' "$NONCOMMENT" | grep -qE -- "$forbidden_kind"; then
        FAIL=$((FAIL+1))
        printf 'FAIL: M020 schema overreach: %s\n' "$forbidden_kind"
    else
        PASS=$((PASS+1))
        printf 'PASS: no M020 schema overreach: %s\n' "$forbidden_kind"
    fi
done

printf 'SUMMARY: m033-p05-scope-guard.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

### 4. Run the AD-7 three-part close gate and author `M033-VALIDATED`

This step is procedural at execution time, not a script. The executor:

1. Runs `bash tests/m033-acceptance/run-acceptance-battery.sh` (with `M033_FR15_STUB=1 M033_GHINIT_STUB=1` if M032/P02 has not closed). Asserts `BATTERY: pass=13 fail=0` (SC-14 / first AD-7 gate). If `pass<13` OR `skip>0`, STOP and surface — do NOT write the marker. The `skip=0` invariant is non-negotiable per CON-1 / MIT-001.

2. Runs `bash tests/m033-acceptance/friendly-tester-pass/validate-report.sh tests/m033-acceptance/friendly-tester-pass/report-<latest>.md` (where `<latest>` is the lexicographically latest filed report). Asserts exit 0 with `friction_blockers: 0` AND `eligible_testers >= 1` (SC-15 / second AD-7 gate). FALLBACK: if no report has been filed AND `M033_SKIP_FRIENDLY_TESTER_PASS=1` is declared in the close-state environment, the gate is satisfied via signed attestation (per US-8 AS-5 / launch sequencing amendment #Q-1). The signed-attestation block MUST be inserted into `M033-SUMMARY.md` (step 5).

3. Runs `bash scripts/verify/validate-milestone.sh M033`. Asserts `M033: NNN/NNN PASS` with NNN ≥ 15 (SC-16 / third AD-7 gate, non-escalable per MIT-004). If NNN < 15, STOP and surface.

If all three gates pass, the executor authors `.orchestrator/milestones/M033/M033-VALIDATED`:

```
M033 VALIDATED -- 2026-05-DD

AD-7 three-part close gate satisfied:
- SC-14: bash tests/m033-acceptance/run-acceptance-battery.sh exit 0 with BATTERY: pass=13 fail=0 skip=0
- SC-15: bash tests/m033-acceptance/friendly-tester-pass/validate-report.sh exit 0 (friction_blockers: 0, eligible_testers: 1)
        OR M033_SKIP_FRIENDLY_TESTER_PASS=1 signed attestation per US-8 AS-5 / launch sequencing amendment #Q-1
- SC-16: bash scripts/verify/validate-milestone.sh M033 reports M033: NNN/NNN PASS with NNN ≥ 15

Validated by: <maintainer-id>
Validated at: <ISO 8601 UTC>
```

### 5. Author `M033-SUMMARY.md`

Modeled on [`.orchestrator/milestones/M031/M031-SUMMARY.md`](../../../../../milestones/M031/M031-SUMMARY.md) shape. YAML frontmatter:

```yaml
---
schema_version: "1.0"
type: milestone-summary
id: "M033"
parent: "milestone"
milestone: "M033"
provides:
  - "orchestrator:start warm conversational front door (FR-1/FR-2/FR-20/FR-21/FR-22); orchestrator-native constitution authoring (FR-3/FR-4/FR-5/FR-6/CON-3); deterministic codebase ingestion (FR-7/FR-8/MIT-005); materials intake with deterministic CON-4 drift detection (FR-9); ideation with MIT-007 live contradiction detection (FR-10/FR-17); migrate-routing glue (FR-11/FR-12); customblock drafter with strict aggregation (FR-13/FR-14); --with-wiki paired-launch passthrough (FR-15/CON-1/MIT-001); --with-github passthrough (FR-16); grilling-shell + glossary inline-update writer (FR-17/FR-18); friendly-tester pass artifact + validator (FR-19/SC-15)"
requires:
  - "M001 (init), M013 (github-init), M014 (dual-write), M015 (migrate), M020 (knowledge-graph kinds), M027 (observability), M030 (model routing), M031 (build-context profile), M032 (paired wiki-init)"
affects:
  - "Launch first-impression UX; M029 (where) consumes branch-detection signals; M035 (packaging) consumes friendly-tester recruiting protocol; M036b (post-launch wiki UX) consumes grilling-shell"
key_files:
  - "<full file inventory mirroring P01..P05 phase-summaries>"
key_decisions:
  - "<aggregated decision rows from P01..P05>"
patterns_established:
  - "<aggregated patterns from P01..P05 phase-summaries>"
drill_down_paths:
  - ".orchestrator/milestones/M033/phases/P01/P01-SUMMARY.md, .orchestrator/milestones/M033/phases/P02/P02-SUMMARY.md, .orchestrator/milestones/M033/phases/P03/P03-SUMMARY.md, .orchestrator/milestones/M033/phases/P04/P04-SUMMARY.md, .orchestrator/milestones/M033/phases/P05/P05-SUMMARY.md"
duration: "<sum of P01..P05 durations>"
verification_result: "pass"
completed_at: "<ISO 8601 UTC>"
observability_surfaces:
  - "jsonl-event-emitter.sh@.orchestrator/execution-log.jsonl (12 closed-enum event types); customblock-draft.complete + ideation.complete + materials-intake.complete + constitution-authored.complete + ingest-codebase.complete + start-state markers; M033-VALIDATED marker file"
---
```

Body (≥100 lines total) sections:

```markdown
# M033 Milestone Summary

## Vision realized

<one-paragraph synthesis>

## Phase rollup

- P01 closed YYYY-MM-DD: <one-line shipped surface>
- P02 closed YYYY-MM-DD: <one-line>
- P03 closed YYYY-MM-DD: <one-line>
- P04 closed YYYY-MM-DD: <one-line>
- P05 closed YYYY-MM-DD: <one-line>

## SC verdict roll

| SC | Verifier | Verdict |
|----|----------|---------|
| SC-1 | tests/m033-acceptance/p01-start-branch-routing.sh | PASS |
| SC-2 | tests/m033-acceptance/p02-constitution-author.sh | PASS |
| SC-3 | tests/m033-acceptance/p03-ingest-codebase.sh | PASS |
| SC-4 | tests/m033-acceptance/p04-materials-intake.sh | PASS |
| SC-5 | tests/m033-acceptance/p04-ideation.sh | PASS |
| SC-6 | tests/m033-acceptance/p05-migrate-routing.sh | PASS |
| SC-7 | tests/m033-acceptance/p06-customblock-draft.sh | PASS |
| SC-8 | tests/m033-acceptance/p07-friendly-tester-protocol.sh | PASS |
| SC-9 | tests/m033-acceptance/p08-with-wiki-passthrough.sh | PASS (M033_FR15_STUB=1) |
| SC-10 | tests/m033-acceptance/p08-with-github-passthrough.sh | PASS (M033_GHINIT_STUB=1) |
| SC-11 | tests/m033-acceptance/p07-grilling-shell.sh | PASS |
| SC-12 | tests/m033-acceptance/p07-resume-on-partial-state.sh | PASS |
| SC-13 | tests/m033-acceptance/p07-observability-records.sh | PASS |
| SC-14 | tests/m033-acceptance/run-acceptance-battery.sh | PASS (BATTERY: pass=13 fail=0 skip=0) |
| SC-15 | tests/m033-acceptance/friendly-tester-pass/validate-report.sh | PASS (friction_blockers: 0, eligible_testers: 1) OR SIGNED-ATTESTATION (M033_SKIP_FRIENDLY_TESTER_PASS=1) |
| SC-16 | scripts/verify/validate-milestone.sh M033 | PASS (M033: NNN/NNN PASS with NNN ≥ 15) |

## CON-3 standalone-gate verdict

bash scripts/verify/standalone-gate.sh constitution: PASS (pass=N skip=0 fail=0) — Principle XVI's first content-authoring compliance test satisfied.

## AD-15 cross-phase regression verdict

P01 + P02 + P03 + P04 phase-suites all PASS against the post-P05 working tree.

## [Optional] Signed attestation block

If M033_SKIP_FRIENDLY_TESTER_PASS=1 was set per US-8 AS-5:

> Signed attestation: M033 closes without an outsider friendly-tester pass per the launch sequencing amendment #Q-1 fallback path. Cold-start UX risk acknowledged. Recruiting outreach attempted by 2026-05-DD; no eligible tester confirmed by 2026-05-12 fallback deadline. Maintainer signature: <name>, <date>.

## Patterns established

<aggregated from P01..P05>

## Open follow-ups (deferred)

- M032/P02 closure for SC-9 real-mode (paired-launch contract per CON-1)
- M033.5 LLM-augmentation for codebase ingestion per #Q-3 (demand-driven post-launch)
- Constitution starter library expansion per #Q-2 (demand-driven post-launch, ≥2 external requests trigger expansion)
- M034 interactive review gates (deferred post-launch, demand-driven)
```

### 6. Emit milestone-grain `unit_close` JSONL record

Run:

```bash
PAYLOAD='{"unit_grain":"milestone","unit_id":"M033","verification_result":"pass","completed_at":"<ISO 8601 UTC>","gates_passed":["SC-14","SC-15","SC-16"]}'
bash scripts/util/jsonl-event-emitter.sh emit unit_close "$PAYLOAD"
```

NOTE: `unit_close` may not be in the P02-shipped 12-event closed enum (which covers M033 sub-flow events). If absent, T05 includes a 1-line additive enum extension to `scripts/util/jsonl-event-emitter.sh` matching the P03/T04 precedent, OR reuses an existing milestone-close emitter helper if one exists. Verify at task-start by `grep -F 'unit_close' scripts/util/jsonl-event-emitter.sh`. Alternative: emit directly via `printf '%s\n' "..." >> .orchestrator/execution-log.jsonl` if the closed-enum extension is out of M033 scope (and document the deviation in M033-SUMMARY.md). Recommended: extend the enum additively, matching M030/M031's milestone-close precedent.

### 7. Author `tools/verify/m033-p05-validated-marker-shape.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m033-p05-validated-marker-shape.sh
set -u
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1"; }

MARKER=".orchestrator/milestones/M033/M033-VALIDATED"
[ -f "$MARKER" ] && pass "marker exists" || fail "marker missing: $MARKER"

for tok in 'M033' 'VALIDATED' 'AD-7' 'SC-14' 'SC-15' 'SC-16'; do
    grep -qF -- "$tok" "$MARKER" && pass "token present: $tok" || fail "token absent: $tok"
done

LINES=$(wc -l < "$MARKER")
[ "$LINES" -ge 5 ] && pass "min 5 lines (got $LINES)" || fail "below 5 lines"

printf 'SUMMARY: m033-p05-validated-marker-shape.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

### 8. Author `tools/verify/m033-p05-summary-md-shape.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m033-p05-summary-md-shape.sh
set -u
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1"; }

SUM=".orchestrator/milestones/M033/M033-SUMMARY.md"
[ -f "$SUM" ] && pass "summary exists" || fail "summary missing: $SUM"

for tok in 'schema_version' 'type: milestone-summary' 'M033' \
           'SC-1' 'SC-2' 'SC-3' 'SC-4' 'SC-5' 'SC-6' 'SC-7' 'SC-8' 'SC-9' \
           'SC-10' 'SC-11' 'SC-12' 'SC-13' 'SC-14' 'SC-15' 'SC-16' \
           'P01' 'P02' 'P03' 'P04' 'P05' 'standalone-gate' 'verification_result'; do
    grep -qF -- "$tok" "$SUM" && pass "token present: $tok" || fail "token absent: $tok"
done

LINES=$(wc -l < "$SUM")
[ "$LINES" -ge 100 ] && pass "min 100 lines (got $LINES)" || fail "below 100 lines"

printf 'SUMMARY: m033-p05-summary-md-shape.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

### 9. Author `tools/verify/m033-p05-unit-close-jsonl-shape.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m033-p05-unit-close-jsonl-shape.sh
# Asserts a single milestone-grain unit_close record was appended for M033.
set -u
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1"; }

LOG=".orchestrator/execution-log.jsonl"
[ -f "$LOG" ] && pass "execution-log.jsonl exists" || fail "execution-log.jsonl missing"

# Find unit_close records mentioning M033 at milestone grain.
COUNT=$(grep -c '"event_type":"unit_close".*"unit_id":"M033".*"unit_grain":"milestone"' "$LOG" 2>/dev/null || true)
[ "${COUNT:-0}" -ge 1 ] && pass "milestone unit_close record present (count=$COUNT)" \
    || fail "no milestone unit_close record for M033"

# At least one record carries gates_passed.
if grep -q '"gates_passed".*"SC-14".*"SC-16"' "$LOG"; then
    pass "gates_passed includes SC-14 + SC-16"
else
    fail "gates_passed field missing required SC labels"
fi

printf 'SUMMARY: m033-p05-unit-close-jsonl-shape.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

## Must-Haves

This task addresses these P05 must-haves:

- `tools/verify/m033-p05-phase-suite.sh` exists and emits `SUMMARY: ... pass=N fail=0` (Truth #10)
- The P01..P04 cross-phase regression boundary holds (Truth #11)
- The bidirectional scope-guard invariant holds (Truth #12)
- `M033-VALIDATED` marker exists, AD-7-gated (Truth #13)
- `M033-SUMMARY.md` exists with canonical milestone-summary shape (Truth #14)
- Single milestone-grain `unit_close` JSONL record appended (Truth #15)
- Verifier artifacts: `m033-p05-phase-suite.sh`, `m033-p05-cross-phase-regression.sh`, `m033-p05-scope-guard.sh`, `m033-p05-validated-marker-shape.sh`, `m033-p05-summary-md-shape.sh`, `m033-p05-unit-close-jsonl-shape.sh`
- Marker artifact: `.orchestrator/milestones/M033/M033-VALIDATED`
- Summary artifact: [`.orchestrator/milestones/M033/M033-SUMMARY.md`](../../../../../milestones/M033/M033-SUMMARY.md)

## Verification

```bash
bash tools/verify/m033-p05-phase-suite.sh
bash tools/verify/m033-p05-cross-phase-regression.sh
bash tools/verify/m033-p05-scope-guard.sh
bash tools/verify/m033-p05-validated-marker-shape.sh
bash tools/verify/m033-p05-summary-md-shape.sh
bash tools/verify/m033-p05-unit-close-jsonl-shape.sh
bash scripts/verify/validate-milestone.sh M033
```

## Inputs

### From Previous Tasks

- `commands/customblock-draft.md` (T01) — referenced by scope-guard allowed-presence list
- `scripts/lifecycle/customblock-draft.sh` (T01) — referenced by scope-guard
- `references/customblock-format.md` (T01) — referenced by scope-guard
- `scripts/lifecycle/start.sh` (T02 + T03) — referenced by scope-guard; modified additively in P05
- `tests/m033-acceptance/p06-customblock-draft.sh` (T04) — referenced by phase-suite + scope-guard
- `tests/m033-acceptance/p08-with-wiki-passthrough.sh` (T04)
- `tests/m033-acceptance/p08-with-github-passthrough.sh` (T04)
- `tests/m033-acceptance/run-acceptance-battery.sh` (T04)
  - Key API: `bash <path>` runs the 13-script battery; final line `BATTERY: pass=N fail=M`; exit 0 iff fail=0
  - Key env vars: `M033_FR15_STUB`, `M033_GHINIT_STUB` (forwarded from runner environment to child invocations)
- All T01..T04 verifiers under `tools/verify/m033-p05-*` — referenced by phase-suite

### From Disk (Pre-existing)

- `tools/verify/m033-p01-phase-suite.sh` (P01/T05)
- `tools/verify/m033-p02-phase-suite.sh` (P02/T05)
- `tools/verify/m033-p03-phase-suite.sh` (P03/T05)
- `tools/verify/m033-p04-phase-suite.sh` (P04/T05)
- `scripts/verify/standalone-gate.sh` (P03/T01) — `bash <path> constitution` exits 0 with `pass=N skip=0` when CON-3 invariant holds
- `scripts/verify/validate-milestone.sh` (framework) — `bash <path> M033` reports `M033: NNN/NNN PASS`
- `scripts/util/jsonl-event-emitter.sh` (P02/T01) — emits `unit_close` (or extend additively if absent from closed enum)
- `tests/m033-acceptance/friendly-tester-pass/validate-report.sh` (P01) — SC-15 mechanical gate
- `templates/milestone-summary.md` (M001) — frontmatter shape reference
- [`.orchestrator/milestones/M030/M030-SUMMARY.md`](../../../../../milestones/M030/M030-SUMMARY.md) and [`.orchestrator/milestones/M031/M031-SUMMARY.md`](../../../../../milestones/M031/M031-SUMMARY.md) — milestone-summary precedents

## Constraints

- Bash 3.2 compatibility (MEM001) — no `declare -A`, no process substitution
- AD-19 single-script-file shape — Verification commands MUST be `bash <path>` invocations only
- AD-7 three-part close gate — `M033-VALIDATED` MUST NOT be authored if any of the three gates fail. The marker authorship is procedural (step 4) and conditioned on the three gates' verdicts; SC-15's gate has a signed-attestation escalation per US-8 AS-5
- AD-15 cross-phase regression — every P01..P04 phase-suite MUST exit 0 against the post-P05 tree (verified by `m033-p05-cross-phase-regression.sh`)
- CON-3 / Principle XVI — `bash scripts/verify/standalone-gate.sh constitution` MUST exit 0 with `pass=N skip=0` (no `speckit.*` references in M033's content-authoring surfaces)
- Bidirectional scope-guard — both forbidden-presence (out-of-scope absence) AND allowed-presence (P05 deliverable presence) verified
- Closed-enum extension discipline — if `unit_close` is not in the P02-shipped enum, T05's extension is additive, matches the P03/T04 precedent, and preserves the existing 12 event-type tokens
- T05 MUST NOT modify P01..P04 acceptance scripts or P01..P04 phase-suites

## Expected Output

T05 creates 9 new files (3 aggregators + 3 close-state shape verifiers + 2 close-state artifacts + 1 JSONL-record append):

- `tools/verify/m033-p05-phase-suite.sh` (≥60 lines, executable)
- `tools/verify/m033-p05-cross-phase-regression.sh` (≥30 lines, executable)
- `tools/verify/m033-p05-scope-guard.sh` (≥60 lines, executable)
- `tools/verify/m033-p05-validated-marker-shape.sh` (≥25 lines, executable)
- `tools/verify/m033-p05-summary-md-shape.sh` (≥30 lines, executable)
- `tools/verify/m033-p05-unit-close-jsonl-shape.sh` (≥25 lines, executable)
- `.orchestrator/milestones/M033/M033-VALIDATED` (≥5 lines)
- [`.orchestrator/milestones/M033/M033-SUMMARY.md`](../../../../../milestones/M033/M033-SUMMARY.md) (≥100 lines)

T05 modifies one file:
- `.orchestrator/execution-log.jsonl` (append a single milestone-grain `unit_close` record)

T05 may additively extend `scripts/util/jsonl-event-emitter.sh` if `unit_close` is not in the closed enum (1-line addition matching the P03/T04 precedent).

After T05 lands:
- `bash tools/verify/m033-p05-phase-suite.sh` → `SUMMARY: m033-p05-phase-suite.sh pass=9 fail=0`
- `bash tools/verify/m033-p05-cross-phase-regression.sh` → `SUMMARY: m033-p05-cross-phase-regression.sh pass=5 fail=0` (4 phase-suites + 1 standalone-gate)
- `bash tools/verify/m033-p05-scope-guard.sh` → `SUMMARY: m033-p05-scope-guard.sh pass=N fail=0`
- `bash tools/verify/m033-p05-validated-marker-shape.sh` → `SUMMARY: ... pass=N fail=0`
- `bash tools/verify/m033-p05-summary-md-shape.sh` → `SUMMARY: ... pass=N fail=0`
- `bash tools/verify/m033-p05-unit-close-jsonl-shape.sh` → `SUMMARY: ... pass=N fail=0`
- `bash scripts/verify/validate-milestone.sh M033` → `M033: NNN/NNN PASS` with NNN ≥ 15

## Notes

### AD-7 three-part close gate enforcement

Step 4 explicitly STOPs and surfaces if any gate fails. The gate logic is procedural — the executor runs each gate command, captures the verdict, and only authors `M033-VALIDATED` when all three pass. There is NO automated "gate-checker" script; the discipline is enforced by the executor following the step-4 procedure literally.

### `M033_SKIP_FRIENDLY_TESTER_PASS=1` fallback path (US-8 AS-5)

When the env var is declared in the close-state environment AND the friendly-tester report is absent OR shows `eligible_testers: 0`, the SC-15 gate is satisfied via signed attestation. The attestation block (step 5 / "Optional signed attestation block") MUST be inserted into `M033-SUMMARY.md` with: maintainer name, date, recruiting-outreach evidence (date the outreach was attempted), and the cold-start-risk acknowledgment text. The `M033-VALIDATED` marker text references this fallback explicitly. The summary's SC-15 row says `SIGNED-ATTESTATION` instead of `PASS`.

### `unit_close` enum extension precedent

P03/T04 already extended the JSONL emitter closed enum 11→12 (added `imported_context_loaded`). The pattern is documented and verified by `tools/verify/m033-p02-jsonl-event-schema.sh`. T05 MAY follow the same pattern to add `unit_close` 12→13 if absent. Alternatively, T05 may emit the JSONL record via `printf` direct-append (bypassing the emitter library) since this is a one-time milestone-close event, not a recurring sub-flow event. Implementation choice at execution time; the shape verifier (`m033-p05-unit-close-jsonl-shape.sh`) only checks the record's presence and field shape, not the path that wrote it.

### Path-collision check (Plan-Time Discipline rule 6)

All 8 created paths verified absent at planning time:
- `tools/verify/m033-p05-phase-suite.sh`
- `tools/verify/m033-p05-cross-phase-regression.sh`
- `tools/verify/m033-p05-scope-guard.sh`
- `tools/verify/m033-p05-validated-marker-shape.sh`
- `tools/verify/m033-p05-summary-md-shape.sh`
- `tools/verify/m033-p05-unit-close-jsonl-shape.sh`
- `.orchestrator/milestones/M033/M033-VALIDATED`
- [`.orchestrator/milestones/M033/M033-SUMMARY.md`](../../../../../milestones/M033/M033-SUMMARY.md)

`.orchestrator/execution-log.jsonl` is present (M001 + many milestones append to it); declared as `modify`, NOT `create`.

### Verifier-availability cross-check (Plan-Time Discipline rule 2)

Every `## Verification` command resolves to a verifier co-authored inside this task (steps 1, 2, 3, 7, 8, 9) OR an existing framework verifier (`bash scripts/verify/validate-milestone.sh M033`). No cross-task dependency on yet-unwritten verifiers.

### Friendly-tester report path

The friendly-tester report path is `tests/m033-acceptance/friendly-tester-pass/report-<latest>.md` where `<latest>` is the lexicographically-latest filed report (e.g., `report-2026-05-08.md`). T05's step 4.2 invokes `validate-report.sh` against this path. If multiple reports are filed, the lexicographically latest wins per the protocol convention (P01/FR-19).

### Standalone-gate invariant (CON-3 / Principle XVI)

The cross-phase regression verifier (step 2) explicitly invokes `bash scripts/verify/standalone-gate.sh constitution` and asserts exit 0 — the customblock-draft surface (T01) MUST NOT introduce any `speckit.*` references. The shape verifier `m033-p05-customblock-draft-sh-shape.sh` (T01's deliverable) already asserts negative-grep for `conversus|model_routing|dispatch|claude-code.*--task` in the customblock-draft.sh body; the standalone-gate provides the cross-cutting CON-3 check across the full M033 surface.

## State Context

- **Current State**: executing
- **Milestone**: M033
- **Phase**: P05
- **Task**: T05-milestone-close
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- Bash 3.2 compatibility (MEM001) — no `declare -A`, no process substitution
- AD-19 single-script-file shape — Verification commands MUST be `bash <path>` invocations only
- AD-7 three-part close gate — `M033-VALIDATED` MUST NOT be authored if any of the three gates fail. The marker authorship is procedural (step 4) and conditioned on the three gates' verdicts; SC-15's gate has a signed-attestation escalation per US-8 AS-5
- AD-15 cross-phase regression — every P01..P04 phase-suite MUST exit 0 against the post-P05 tree (verified by `m033-p05-cross-phase-regression.sh`)
- CON-3 / Principle XVI — `bash scripts/verify/standalone-gate.sh constitution` MUST exit 0 with `pass=N skip=0` (no `speckit.*` references in M033's content-authoring surfaces)
- Bidirectional scope-guard — both forbidden-presence (out-of-scope absence) AND allowed-presence (P05 deliverable presence) verified
- Closed-enum extension discipline — if `unit_close` is not in the P02-shipped enum, T05's extension is additive, matches the P03/T04 precedent, and preserves the existing 12 event-type tokens
- T05 MUST NOT modify P01..P04 acceptance scripts or P01..P04 phase-suites

### Acceptance Criteria

This task addresses these P05 must-haves:

- `tools/verify/m033-p05-phase-suite.sh` exists and emits `SUMMARY: ... pass=N fail=0` (Truth #10)
- The P01..P04 cross-phase regression boundary holds (Truth #11)
- The bidirectional scope-guard invariant holds (Truth #12)
- `M033-VALIDATED` marker exists, AD-7-gated (Truth #13)
- `M033-SUMMARY.md` exists with canonical milestone-summary shape (Truth #14)
- Single milestone-grain `unit_close` JSONL record appended (Truth #15)
- Verifier artifacts: `m033-p05-phase-suite.sh`, `m033-p05-cross-phase-regression.sh`, `m033-p05-scope-guard.sh`, `m033-p05-validated-marker-shape.sh`, `m033-p05-summary-md-shape.sh`, `m033-p05-unit-close-jsonl-shape.sh`
- Marker artifact: `.orchestrator/milestones/M033/M033-VALIDATED`
- Summary artifact: [`.orchestrator/milestones/M033/M033-SUMMARY.md`](../../../../../milestones/M033/M033-SUMMARY.md)

### Files To Touch

- `commands/customblock-draft.md` (create, T01)
- `scripts/lifecycle/customblock-draft.sh` (create, T01)
- `references/customblock-format.md` (create, T01)
- `scripts/lifecycle/start.sh` (modify, T02 — adds `--with-wiki`/`--with-giscus`/`--deploy` flags + post-onboarding wiki-init invocation gate + stub-mode dispatch + `wiki_init_invoked` JSONL emit; preserves P01/P02/P04 behavior for invocations without `--with-wiki`)
- `scripts/lifecycle/start.sh` (modify, T03 — adds `--with-github` flag + post-onboarding-and-post-wiki-init github-init invocation gate + stub-mode dispatch + `github_init_invoked` JSONL emit; preserves P01/P02/P04/T02 behavior)
- `tests/m033-acceptance/p06-customblock-draft.sh` (create, T04)
- `tests/m033-acceptance/p08-with-wiki-passthrough.sh` (create, T04)
- `tests/m033-acceptance/p08-with-github-passthrough.sh` (create, T04)
- `tests/m033-acceptance/run-acceptance-battery.sh` (create, T04)
- `tools/verify/m033-p05-customblock-draft-md-shape.sh` (create, T01)
- `tools/verify/m033-p05-customblock-draft-sh-shape.sh` (create, T01)
- `tools/verify/m033-p05-customblock-format-ref-shape.sh` (create, T01)
- `tools/verify/m033-p05-with-wiki-passthrough-shape.sh` (create, T02)
- `tools/verify/m033-p05-with-github-passthrough-shape.sh` (create, T03)
- `tools/verify/m033-p05-acceptance-shape-sc7.sh` (create, T04)
- `tools/verify/m033-p05-acceptance-shape-sc9.sh` (create, T04)
- `tools/verify/m033-p05-acceptance-shape-sc10.sh` (create, T04)
- `tools/verify/m033-p05-acceptance-battery-shape.sh` (create, T04)
- `tools/verify/m033-p05-phase-suite.sh` (create, T05)
- `tools/verify/m033-p05-cross-phase-regression.sh` (create, T05)
- `tools/verify/m033-p05-scope-guard.sh` (create, T05)
- `tools/verify/m033-p05-validated-marker-shape.sh` (create, T05)
- `tools/verify/m033-p05-summary-md-shape.sh` (create, T05)
- `tools/verify/m033-p05-unit-close-jsonl-shape.sh` (create, T05)
- `.orchestrator/milestones/M033/M033-VALIDATED` (create, T05 — gated on AD-7 three-part close gate)
- [`.orchestrator/milestones/M033/M033-SUMMARY.md`](../../../../../milestones/M033/M033-SUMMARY.md) (create, T05 — references SC-1..SC-16 verdicts)
- `.orchestrator/execution-log.jsonl` (modify, T05 — append a single milestone-grain `unit_close` record)

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