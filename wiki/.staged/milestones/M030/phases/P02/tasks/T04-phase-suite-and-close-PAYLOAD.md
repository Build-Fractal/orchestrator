---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T04-phase-suite-and-close (Phase P02, Milestone M030)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~500 | required |
| Upstream Context | 981-1048 | ~1900 | required |
| Task Plan | 1050-1322 | ~4200 | required |
| State Context | 1324-1330 | ~100 | required |
| First-Turn Completeness | 1332-1379 | ~800 | required |
| **Total** | | **~18300** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 668
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
hit_count: 668
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
hit_count: 668
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
hit_count: 668
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
hit_count: 590
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
hit_count: 590
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
hit_count: 590
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
hit_count: 668
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
hit_count: 590
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
hit_count: 590
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
hit_count: 590
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
hit_count: 668
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
hit_count: 668
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
hit_count: 668
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
hit_count: 590
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
hit_count: 590
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
hit_count: 590
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
hit_count: 668
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
hit_count: 590
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
hit_count: 590
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
hit_count: 668
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
hit_count: 668
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
hit_count: 590
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
hit_count: 590
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
hit_count: 590
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
hit_count: 245
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
hit_count: 245
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
hit_count: 245
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
hit_count: 244
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
hit_count: 244
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
hit_count: 234
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
task: "T04"
phase: "P02"
milestone: "M030"
name: "P02 phase-suite + recent-changes dual-write + commit"
depends_on: ["T03"]
---

## Prerequisites

- All P02 verifiers from T01-T03 are on disk:
  - `tools/verify/p02-fixture-shape.sh` (T01)
  - `tools/verify/p02-additive-schema.sh` (T01)
  - `tools/verify/p02-shadow-emit.sh` (T02 + T03 amendment)
  - `tools/verify/p02-con3-closure.sh` (T02)
  - `tools/verify/p02-append-only.sh` (T02)
  - `tools/verify/p02-shadow-compare-verdicts.sh` (T03)
  - `tools/verify/p02-partial-flip-enum.sh` (T03)
  - `tools/verify/p02-stability-metric-traceability.sh` (T03)
  - `tools/verify/p02-sc3a-roundtrip.sh` (T03)
- All nine verifiers exit 0 against current working tree (T01-T03 close conditions).
- `scripts/dispatch/dispatch-interface.sh` is amended (T02 + T03 small follow-up Step 2) with shadow-mode hook + `classifier_confidence`/`model_routed`/`model_used`/`partial_flip_active`/`withheld_classes` fields under `M030_SHADOW_MODE=1` AND `CLAUDECODE=1`.
- `scripts/diagnostics/shadow-compare.sh` exists with 4-verdict output (T03).
- Five fixture JSONL files at `tests/fixtures/m030-p02/` (T01 + T03).
- `scripts/util/dual-write-runtime-md.sh` exists (pre-existing; verified during plan-authoring at `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/util/dual-write-runtime-md.sh`).
- `tools/verify/p01-phase-suite.sh` exists as the reference shape for the straight-line aggregator pattern (P01/T04 close).

Plan-time prerequisite-existence verification: every path above is either a T01-T03 deliverable (asserted by their respective close conditions) or a pre-existing repo file (asserted during plan-authoring via direct `ls` inspection). `scripts/util/dual-write-runtime-md.sh` was confirmed present.

## Description

T04 closes P02. Three deliverables:

1. **`tools/verify/p02-phase-suite.sh`** — straight-line aggregator over all nine P02 sub-gates. Mirrors `p01-phase-suite.sh` shape: literal `bash <path>` invocations (no loops), `pass`/`fail` accumulators via `$?`, single-line `SUMMARY: p02-phase-suite.sh pass=N fail=M` before exit.

2. **CLAUDE.md / AGENTS.md recent-changes update** — append a one-line P02-close fragment via `scripts/util/dual-write-runtime-md.sh`. Fragment names the load-bearing facts: 4-verdict shadow-compare, SC-11 byte-equality preserved, SC-3a roundtrip green, CC-only short-circuit, stability metric 0.10/N=20/50 traced.

3. **Commit** — stage the phase-suite script + recent-changes updates and commit via `git commit -F <message-file>`.

### P02 phase-suite contract

`tools/verify/p02-phase-suite.sh` invokes nine sub-gates in this order:

1. `bash tools/verify/p02-fixture-shape.sh`
2. `bash tools/verify/p02-additive-schema.sh`
3. `bash tools/verify/p02-shadow-emit.sh`
4. `bash tools/verify/p02-con3-closure.sh`
5. `bash tools/verify/p02-append-only.sh`
6. `bash tools/verify/p02-shadow-compare-verdicts.sh`
7. `bash tools/verify/p02-partial-flip-enum.sh`
8. `bash tools/verify/p02-stability-metric-traceability.sh`
9. `bash tools/verify/p02-sc3a-roundtrip.sh`

Each invocation is a literal statement; `pass`/`fail` accumulators update via `pass=$((pass+1))` / `fail=$((fail+1))` per `$?`. No `for` loop over a script-name array (forbidden by AD-19; the literal-statement form is required). Final line: `SUMMARY: p02-phase-suite.sh pass=N fail=M`. Exit 0 iff all nine exit 0.

Use `set -uo pipefail` (NOT `-e`) so `$?` is captured even on sub-gate fail. Each sub-gate's own diagnostic is emitted to stdout/stderr by the sub-gate; the suite just accumulates and reports.

### Recent-changes dual-write

Per CON-6 dual-write invariant (CLAUDE.md `# >>> orchestrator:recent-changes >>>` region), append a one-line P02 close fragment via `scripts/util/dual-write-runtime-md.sh`. Recommended fragment:

```
M030 P02 close: dispatch-interface shadow hook (M030_SHADOW_MODE=1 + CLAUDECODE=1) + 5 additive JSONL fields + scripts/diagnostics/shadow-compare.sh 4-verdict (ready|partially_ready|block|evidence_insufficient) + SC-3a roundtrip green + SC-11 byte-equality preserved (CON-2/FR-19) + CON-3 closure + CON-6 append-only + stability metric 0.10/N=20/50 traced; phase-suite green pass=9 fail=0
```

The dual-write helper writes to both CLAUDE.md (Claude Code) and AGENTS.md (Codex CLI) when the latter is present; its idempotency rules prevent duplicate fragments.

## Steps

1. **Confirm all T01-T03 deliverables are on disk and green.** Run:

   ```bash
   bash tools/verify/p02-fixture-shape.sh
   bash tools/verify/p02-additive-schema.sh
   bash tools/verify/p02-shadow-emit.sh
   bash tools/verify/p02-con3-closure.sh
   bash tools/verify/p02-append-only.sh
   bash tools/verify/p02-shadow-compare-verdicts.sh
   bash tools/verify/p02-partial-flip-enum.sh
   bash tools/verify/p02-stability-metric-traceability.sh
   bash tools/verify/p02-sc3a-roundtrip.sh
   ```

   Expected: all nine exit 0. If any fails, T04 cannot close — the failing upstream task must be re-opened.

2. **Author `tools/verify/p02-phase-suite.sh`** per the contract above. Verbatim straight-line bash:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/p02-phase-suite.sh — M030 P02 phase-close gate.
   # Invokes all nine P02 sub-gates in order; exits 0 iff all pass.
   # Bash 3.2 compatible. Straight-line — no loops, no eval, no compound chains.
   # Modeled on p01-phase-suite.sh (P01/T04 reference shape).

   set -uo pipefail

   pass=0
   fail=0

   bash tools/verify/p02-fixture-shape.sh
   if [ $? -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

   bash tools/verify/p02-additive-schema.sh
   if [ $? -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

   bash tools/verify/p02-shadow-emit.sh
   if [ $? -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

   bash tools/verify/p02-con3-closure.sh
   if [ $? -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

   bash tools/verify/p02-append-only.sh
   if [ $? -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

   bash tools/verify/p02-shadow-compare-verdicts.sh
   if [ $? -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

   bash tools/verify/p02-partial-flip-enum.sh
   if [ $? -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

   bash tools/verify/p02-stability-metric-traceability.sh
   if [ $? -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

   bash tools/verify/p02-sc3a-roundtrip.sh
   if [ $? -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

   echo "SUMMARY: p02-phase-suite.sh pass=$pass fail=$fail"

   if [ "$fail" -eq 0 ]; then
     exit 0
   else
     exit 1
   fi
   ```

   Note: same shape as `p01-phase-suite.sh`. The set-flags choice (`-uo pipefail`, no `-e`) is load-bearing — `-e` would short-circuit on the first sub-gate failure and skip the SUMMARY emission; `-u` catches unset variables; `-o pipefail` is preserved as defensive even though no pipes are used in the suite body.

3. **Run the new T04 verifier as a self-check:**

   ```bash
   bash tools/verify/p02-phase-suite.sh
   ```

   Expected: `SUMMARY: p02-phase-suite.sh pass=9 fail=0`, exit 0. If any sub-gate exits non-zero, the suite reports `pass=N fail=M` with `M >= 1` and exits 1; the failing sub-gate's own stdout/stderr from its individual run will name the failure mode.

4. **Recent-changes dual-write.** Run the dual-write helper:

   ```bash
   bash scripts/util/dual-write-runtime-md.sh "M030 P02 close: dispatch-interface shadow hook (M030_SHADOW_MODE=1 + CLAUDECODE=1) + 5 additive JSONL fields + scripts/diagnostics/shadow-compare.sh 4-verdict (ready|partially_ready|block|evidence_insufficient) + SC-3a roundtrip green + SC-11 byte-equality preserved (CON-2/FR-19) + CON-3 closure + CON-6 append-only + stability metric 0.10/N=20/50 traced; phase-suite green pass=9 fail=0"
   ```

   Expected: the helper appends the fragment to both `CLAUDE.md` and `AGENTS.md` (if present) inside the `# >>> orchestrator:recent-changes >>>` region. If the helper has its own flag protocol (`--fragment <text>` or stdin-piped input), use that shape instead — read `scripts/util/dual-write-runtime-md.sh` head before invocation to determine the supported shape. The helper is idempotent — re-running with the same fragment is a no-op or an explicit duplicate-detection refusal.

5. **Verify recent-changes update.** Run:

   ```bash
   grep -F 'M030 P02 close' CLAUDE.md
   ```

   Expected: stdout contains the new fragment line. If `AGENTS.md` exists, run the same grep against it; expect the same fragment.

6. **Stage and commit.** Stage:
   - `tools/verify/p02-phase-suite.sh` (create)
   - `CLAUDE.md` (modify — recent-changes region)
   - `AGENTS.md` (modify if present — recent-changes region)

   Author commit message file via the Write tool to `/tmp/p02-t04-commit-msg.txt`. Recommended message body:

   ```
   M030/P02/T04: phase-suite + recent-changes dual-write

   - tools/verify/p02-phase-suite.sh: straight-line aggregator over the 9 P02
     sub-gates (fixture-shape, additive-schema, shadow-emit, con3-closure,
     append-only, shadow-compare-verdicts, partial-flip-enum, stability-
     metric-traceability, sc3a-roundtrip). Same shape as p01-phase-suite.sh.
   - CLAUDE.md / AGENTS.md: recent-changes fragment naming the P02 close
     contract (4-verdict shadow-compare, SC-11 byte-equality preserved,
     SC-3a roundtrip green, CC-only short-circuit, stability metric traced).

   Phase-suite green: pass=9 fail=0.
   ```

   Commit: `git commit -F /tmp/p02-t04-commit-msg.txt`.

   Do NOT use the inline-HEREDOC `git commit -m "$(cat <<'EOF' ... EOF)"` form — AP-008 (`heredoc-with-expansion`) blocks it. Author the message file via Write tool, then `-F` it.

7. **Final post-commit self-check:**

   ```bash
   bash tools/verify/p02-phase-suite.sh
   bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P02
   ```

   Expected:
   - `bash tools/verify/p02-phase-suite.sh` → `SUMMARY: p02-phase-suite.sh pass=9 fail=0`, exit 0.
   - `bash scripts/verify/check-must-haves.sh ...` → all phase truths + artifacts + key-links pass, exit 0.

   If `check-must-haves.sh` reports a missing artifact or a failing truth `Check:`, the corresponding upstream task may have an incomplete deliverable — re-open and fix. If the phase-suite is green but `check-must-haves.sh` fails, the gap is in artifact paths or `grep` patterns in the phase plan's must-haves block; those would be fixed by amending the phase plan in P02-PLAN.md (NOT by re-opening tasks).

## Must-Haves

This task satisfies the phase truth:

- "`bash tools/verify/p02-phase-suite.sh` invokes all nine P02 sub-gates in literal sequence (no loops, no eval), exits 0 iff every sub-gate passes, and emits `SUMMARY: p02-phase-suite.sh pass=N fail=M` on a single line before exit." — `tools/verify/p02-phase-suite.sh` is itself the gate; its own self-check is `bash tools/verify/p02-phase-suite.sh`.

T04 closes the phase: when the suite exits 0 with `pass=9 fail=0`, P02 is ready for `orchestrator:verify` to write `P02-SUMMARY.md` and advance the milestone to P03.

## Verification

```bash
bash tools/verify/p02-phase-suite.sh
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P02
```

Each verifier uses single-script-file shape per AD-19. The phase-suite is the canonical phase-close gate; if it exits 0 with `pass=9 fail=0`, P02 is ready for `orchestrator:verify`. `check-must-haves.sh` is the framework-owned final gate that runs all phase Truth `Check:` commands + Artifact existence + Key Link presence.

## Inputs

### From Previous Tasks

- `tools/verify/p02-fixture-shape.sh`, `tools/verify/p02-additive-schema.sh` (T01)
  - Key API: each is `bash <path>` → exit 0 with `SUMMARY: <name> pass=N fail=0`.
- `tools/verify/p02-shadow-emit.sh`, `tools/verify/p02-con3-closure.sh`, `tools/verify/p02-append-only.sh` (T02)
  - Key API: each is `bash <path>` → exit 0 with `SUMMARY: <name> pass=N fail=0`.
- `tools/verify/p02-shadow-compare-verdicts.sh`, `tools/verify/p02-partial-flip-enum.sh`, `tools/verify/p02-stability-metric-traceability.sh`, `tools/verify/p02-sc3a-roundtrip.sh` (T03)
  - Key API: each is `bash <path>` → exit 0 with `SUMMARY: <name> pass=N fail=0`.

### From Disk (Pre-existing)

- `scripts/util/dual-write-runtime-md.sh` — recent-changes dual-write helper. Idempotent.
- `tools/verify/p01-phase-suite.sh` — reference pattern for the straight-line phase-suite shape.
- `CLAUDE.md` — recent-changes region target for the P02-close fragment.
- `AGENTS.md` (if present) — Codex CLI runtime instructions; recent-changes region dual-write target.

## Constraints

- **AD-19 single-script-file shape**: all verifier `Check:` invocations are `bash <single-path>.sh`. The phase-suite itself is a series of literal `bash <path>` statements — NO `for` loop over a script-name array (forbidden by AD-19).
- **Bash 3.2 compatibility**: no `declare -A`, no `mapfile`, no `readarray`, no `pipefail` reliance for capturing exit codes (use `$?` directly after each invocation, the same pattern as `p01-phase-suite.sh`).
- **CON-2/FR-19/SC-11 (additive-only schema)**: not directly amended in T04. The phase-suite gates the SC-11 verifier (`p02-additive-schema.sh`); failure here surfaces as a phase-suite fail, not a T04-specific issue.
- **CON-3 (symbolic-tier closure)**: gated by `p02-con3-closure.sh` in the suite. T04 itself introduces no model-ID literals (it adds only the phase-suite script and a recent-changes fragment).
- **CON-6 (append-only shadow corpus)**: gated by `p02-append-only.sh` in the suite. Recent-changes dual-write is a CLAUDE.md/AGENTS.md edit, NOT a JSONL append — the CON-6 invariant applies to shadow corpus files only.
- **AP-008 (heredoc-with-expansion)**: forbids `git commit -m "$(cat <<'EOF' ... EOF)"`. T04 uses `git commit -F <message-file>` exclusively per CLAUDE.md commit-authoring guidance.
- **Plan-Time Discipline rule 5 (real-DB verification)**: T04 does NOT introduce SQL — N/A.

## Expected Output

- `tools/verify/p02-phase-suite.sh` — straight-line aggregator over the nine P02 sub-gates.
- `CLAUDE.md` — recent-changes region updated with P02-close fragment.
- `AGENTS.md` — same fragment dual-written (if AGENTS.md is present).
- `bash tools/verify/p02-phase-suite.sh` exits 0 with `SUMMARY: p02-phase-suite.sh pass=9 fail=0`.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P02` exits 0 with all phase truths + artifacts + key-links passing.
- New commit on the working branch with subject `M030/P02/T04: phase-suite + recent-changes dual-write` (or similar).

## Notes

Expected verifier output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p02-phase-suite.sh` → nine sub-gate SUMMARY lines (one per gate), then `SUMMARY: p02-phase-suite.sh pass=9 fail=0`, exit 0.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P02` → all 10 Truth checks pass, all 18 Artifact checks pass, all 9 Key Link checks pass, `PASS: <count> truths, <count> artifacts, <count> key-links`, exit 0.

When P02's phase-suite green and the framework `check-must-haves.sh` green, P02 is ready for `orchestrator:verify` to write `P02-SUMMARY.md` and advance the milestone to P03. Downstream P03 (Operator overrides + kill switch) consumes:

- `scripts/dispatch/dispatch-interface.sh` — for the override-resolution path that overlays on top of T02's classifier hook (FR-4/FR-11/FR-12/FR-13/FR-14).
- The JSONL schema additions T02+T03 shipped (`classifier_confidence`, `model_routed`, `model_used`, `partial_flip_active`, `withheld_classes`) — for `override_source` co-emission.
- The CON-6 append-only invariant T02 locked in via `p02-append-only.sh` — P03's override path must respect the same invariant.

The decision to author `classifier_confidence` in T03 (not T02) keeps T02's amendment maximally surgical; the trade-off is one small follow-up edit in T03 Step 2. An alternative ordering — author `classifier_confidence` in T02 alongside the other four shadow fields — would have collapsed the two amendments into one; it was deferred to T03 because T03 is the consumer (variance computation needs the field) and the classifier-confidence field has no purpose in T02's contract on its own. Either ordering is correct; the chosen one prioritizes T02's amendment minimality.

The `CLAUDE.md` `# >>> orchestrator:recent-changes >>>` region is the single source of truth for "what changed recently across all milestones"; the dual-write to `AGENTS.md` keeps Codex CLI's runtime instructions in sync per CON-6 dual-write invariant. Both files are tracked in git; the commit captures both.

## State Context

- **Current State**: executing
- **Milestone**: M030
- **Phase**: P02
- **Task**: T04-phase-suite-and-close
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **AD-19 single-script-file shape**: all verifier `Check:` invocations are `bash <single-path>.sh`. The phase-suite itself is a series of literal `bash <path>` statements — NO `for` loop over a script-name array (forbidden by AD-19).
- **Bash 3.2 compatibility**: no `declare -A`, no `mapfile`, no `readarray`, no `pipefail` reliance for capturing exit codes (use `$?` directly after each invocation, the same pattern as `p01-phase-suite.sh`).
- **CON-2/FR-19/SC-11 (additive-only schema)**: not directly amended in T04. The phase-suite gates the SC-11 verifier (`p02-additive-schema.sh`); failure here surfaces as a phase-suite fail, not a T04-specific issue.
- **CON-3 (symbolic-tier closure)**: gated by `p02-con3-closure.sh` in the suite. T04 itself introduces no model-ID literals (it adds only the phase-suite script and a recent-changes fragment).
- **CON-6 (append-only shadow corpus)**: gated by `p02-append-only.sh` in the suite. Recent-changes dual-write is a CLAUDE.md/AGENTS.md edit, NOT a JSONL append — the CON-6 invariant applies to shadow corpus files only.
- **AP-008 (heredoc-with-expansion)**: forbids `git commit -m "$(cat <<'EOF' ... EOF)"`. T04 uses `git commit -F <message-file>` exclusively per CLAUDE.md commit-authoring guidance.
- **Plan-Time Discipline rule 5 (real-DB verification)**: T04 does NOT introduce SQL — N/A.

### Acceptance Criteria

This task satisfies the phase truth:

- "`bash tools/verify/p02-phase-suite.sh` invokes all nine P02 sub-gates in literal sequence (no loops, no eval), exits 0 iff every sub-gate passes, and emits `SUMMARY: p02-phase-suite.sh pass=N fail=M` on a single line before exit." — `tools/verify/p02-phase-suite.sh` is itself the gate; its own self-check is `bash tools/verify/p02-phase-suite.sh`.

T04 closes the phase: when the suite exits 0 with `pass=9 fail=0`, P02 is ready for `orchestrator:verify` to write `P02-SUMMARY.md` and advance the milestone to P03.

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