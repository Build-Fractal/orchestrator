---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T03-conversus-gate (Phase P01, Milestone M018)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-978 | ~600 | required |
| Upstream Context | 980-1193 | ~2300 | required |
| Task Plan | 1195-1403 | ~4200 | required |
| State Context | 1405-1411 | ~100 | required |
| First-Turn Completeness | 1413-1457 | ~900 | required |
| **Total** | | **~18900** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 598
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
hit_count: 598
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
hit_count: 598
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
hit_count: 598
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
hit_count: 529
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
hit_count: 529
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
hit_count: 529
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
hit_count: 598
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
hit_count: 529
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
hit_count: 529
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
hit_count: 529
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
hit_count: 598
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
hit_count: 598
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
hit_count: 598
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
hit_count: 529
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
hit_count: 529
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
hit_count: 529
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
hit_count: 598
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
hit_count: 529
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
hit_count: 529
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
hit_count: 598
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
hit_count: 598
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
hit_count: 529
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
hit_count: 529
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
hit_count: 529
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
hit_count: 184
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
hit_count: 184
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
hit_count: 184
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
hit_count: 174
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
hit_count: 174
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
hit_count: 164
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

<!-- Per AD-19, every Check is a single-script-file invocation. No inline
     compound bash, no plain subshells, no $(... | ...). -->

- `references/compression-grammar.md` exists with a versioned per-tier contract — every tier section (filter, tier1, tier2, tier3) carries an `applies-to:` block enumerating artifact classes and a `preserves:` block enumerating byte-pattern regexes; the marker grammar `<!-- compressed:tierN ... -->` is documented; the additive emitter-schema invariant (CON-5) is stated verbatim.
  - Check: `bash scripts/verify/m018-p01-grammar-shape.sh`
- `scripts/verify/compression-grammar-lint.sh` parses the grammar contract and exits 0; rejects any tier section missing `applies-to:` or `preserves:`; emits one PASS line per (tier, artifact-class, preserved-pattern) triple.
  - Check: `bash scripts/verify/m018-p01-lint-clean.sh`
- The grammar contract defends against the SC-9 calibrated 34.7% floor by naming, in-document, the per-tier modeling assumptions from P00's probe (filter ≈ 13%, tier1 ≈ 6.3%, tier2 ≈ 25.5%, tier3 ≈ 12.2%) and the aggregate target ≥ 34.7% so reviewers can dispute the assumptions on paper rather than after tier code lands.
  - Check: `bash scripts/verify/m018-p01-sc9-traceability.sh`
- `RUNTIME-ASSUMPTIONS.md` carries an `## M018/P01: <name>` entry with the four required subsections (Claude Code assumption, Codex/Cursor fallback, Milestone/phase, M009 obligation) describing the compression-grammar runtime expectations (zero-LLM tiers byte-identical across runtimes; Tier 3 LLM call routes through dispatch-interface.sh).
  - Check: `bash scripts/verify/m018-p01-runtime-assumptions.sh`
- [`.orchestrator/milestones/M018/phases/P01/conversus/gate-result.md`](../../../../../milestones/M018/phases/P01/conversus/gate-result.md) exists with frontmatter `verdict: "PASS"`; the conversus `--strict` gate ran against `references/compression-grammar.md` using a preset that exercises the red/blue advocate model.
  - Check: `bash scripts/verify/m018-p01-conversus-pass.sh`
- CLAUDE.md and AGENTS.md `recent-changes` block both name M018/P01 grammar-contract close (dual-write produced via `scripts/util/dual-write-runtime-md.sh` — never edit AGENTS.md directly).
  - Check: `bash scripts/verify/m018-p01-dual-write-recent.sh`

<dispatch-volatile>

## Upstream Context


### P00 Summary
---
schema_version: "1.0"
type: phase-summary
phase: P00
milestone: M018
status: complete
closed_at: 2026-04-27
---

# M018/P00 — Measurement Prerequisites — Summary

## Closure summary

P00 is the measurement-prerequisites phase that D028 made M018's blocking
foundation. It carried the proof for two of the conversus gate findings
(RISK-1: emitter-coverage gap; RISK-2: SC-9 placeholder threshold). The
phase landed three artifacts: a co-located `dispatch_usage` emitter inside
`scripts/dispatch/build-context.sh` so every payload_breakdown record now
ships with a sibling dispatch_usage record (T01); a section-distribution
probe with per-tier savings_ceiling estimator and 80% bootstrap CIs (T02);
and the SC-9 spec amendment that pins the threshold to a probe-derived
floor of 34.7% mean payload-token reduction (T03). With P00 closed, M018
unblocks for P01 grammar-contract work — downstream phases now have an
empirically defensible target and a real telemetry pipeline to measure
against.

## Parity result

**Path used**: B (synthetic fixture-replay).

**Rationale**: At T03 dispatch time the production union scan over
`.orchestrator/milestones/*/execution-log.jsonl` carried 2 dispatch_usage
records against 20 most-recent payload_breakdown records (10% parity);
fewer than 20 fresh dispatches had accumulated against the patched
emitter since T01 landed. Path A would have required waiting for organic
traffic, so we built the fixture-replay harness specified in the T03
plan.

**Harness**: `scripts/verify/m018-p00-fixture-replay.sh` copies the
`tests/fixtures/dispatch-state` fixture into a scratch milestones-style
tree under `.orchestrator/scratch/m018-p00-replay-root/M001/`, wipes the
log, and invokes `scripts/dispatch/build-context.sh` 20 times back-to-back
against `M001/P02/T01`. Each invocation writes a `payload_breakdown`
record AND its co-located `dispatch_usage` record to
`.orchestrator/scratch/m018-p00-replay-root/M001/execution-log.jsonl`.
The harness then mirrors that file to
`.orchestrator/scratch/m018-p00-fixture-log.jsonl` for audit-trail
visibility and runs the T01 parity verifier against the scratch root via
`--root <replay_root>`.

**Result**:

```
PASS: dispatch_usage parity over recent 20 payload_breakdown records:
      20 dispatch_usage / 20 payload_breakdown = 100% (threshold=95%)
PASS: fixture-replay parity (20 invocations against
      .../m018-p00-replay-root)
```

20 dispatch_usage / 20 payload_breakdown = **100%** parity.

**Sample window**: synthetic; all 20 records dated 2026-04-27 within the
single fixture-replay run. The `--root` flag was already supported by
T01's verifier (functionally equivalent to `--log-path`); no extension
to T01's verifier was required for Path B.

## Calibrated threshold

**Threshold floor**: **34.7%** mean payload-token reduction, sourced from
`aggregate_ceiling.low_pct` in the T02 probe JSON output.

**Per-tier 80% CIs (probe output)**:

| tier   | low_pct | mean_pct | high_pct |
|--------|---------|----------|----------|
| filter | 12.55%  | 13.08%   | 13.67%   |
| tier1  | 6.24%   | 6.31%    | 6.40%    |
| tier2  | 25.33%  | 25.49%   | 25.68%   |
| tier3  | 12.10%  | 12.22%   | 12.36%   |

**Aggregate (non-overlap-adjusted)**:

| stat       | pct   | tokens |
|------------|-------|--------|
| low (p10)  | 34.73% | 5,883 |
| mean       | 35.08% | 5,941 |
| high (p90) | 35.39% | 5,994 |

**Model assumptions** (verbatim from
`.orchestrator/scratch/m018-section-distribution-output.json`
`.model_assumptions`):

- **filter (FR-3)**: drops ~30% of Knowledge tokens, Beta(2,5) prior on
  superseded/experimental fraction.
- **tier1 (FR-5)**: drops ~50% of tool-result tokens, conditioned on ~30%
  prevalence inside Task Plan + Upstream Context.
- **tier2 (FR-6)**: head-drops ~40% of EXCESS over the 1500-tok tail
  threshold on any section that exceeds it (preserves last 1500 tok
  verbatim).
- **tier3 (FR-7)**: summarizes ~40% of EXCESS above the per-section
  budget (2000 tok) on Knowledge + Task Plan + Upstream Context;
  Standard+ intensity assumed.

**Probe inputs**: n=172 historical `payload_breakdown` records (the count
grew from 169 at T02-spec time to 172 by the T03-run dispatch time).
Bootstrap iterations: 1000. Seed: 42 (deterministic).

**Probe outputs (audit trail, durable)**:

- `.orchestrator/scratch/m018-section-distribution-output.json`
- `.orchestrator/scratch/m018-section-distribution-output.txt`

## Spec amendment

**File**: `specs/030-context-compression-layer/spec.md`

**Lines touched**: line 14 (frontmatter `Last Revised:`); line 241 (SC-9
acceptance criterion). Both edits applied with `Edit` (byte-surgical, no
surrounding-text reformat).

**SC-9 before** (parenthetical only):

> *(Per gate finding RISK-2: the prior "≥ 25%" target was unbacked and
> is replaced by a probe-derived threshold.)*

**SC-9 after** (parenthetical only):

> *(Per gate finding RISK-2 + P00 calibration: SC-9 threshold floor is
> **34.7%** mean payload-token reduction, derived from
> `scripts/diagnostics/m018-section-distribution.sh` aggregate-ceiling
> 80% CI lower bound across n=169 historical `payload_breakdown` records
> under per-tier modeling assumptions documented in the probe script.
> Probe output archived at
> `.orchestrator/scratch/m018-section-distribution-output.{json,txt}`.
> Expected mean: 35.1%; optimistic ceiling: 35.4%.)*

**Frontmatter `Last Revised:` after**: appended
"**2026-04-27 (P00 close)**: SC-9 threshold pinned to 34.7% per
probe-derived 80% CI lower bound."

**Commit reference**: see git log on branch `feat/m018-context-compression`
for the T03-closing commit; message references D028, parity figure
(100% over 20 dispatches via fixture-replay), threshold value (34.7%),
and the probe-output audit trail.

## Risk-mitigation traceability

This is the audit trail D028 promised P00 would carry. Every conversus
gate risk maps to a mitigation, a delivering task, and a mechanical
verifier whose passing exit code closes the loop.

- **RISK-1 (emitter-coverage gap, 1.2% parity)** → **MIT-1 (co-locate
  `dispatch_usage` emit with `payload_breakdown` inside
  `build-context.sh`)** → **T01** (added
  `_bc_emit_dispatch_usage_colocated`, `--emission_point=build-context`
  disambiguator, additive per CON-5) → **T03 step 1** (Path B
  fixture-replay parity verifier returned 100% parity over 20 dispatches)
  → verifier `scripts/verify/m018-p00-emitter-parity.sh --window 20
  --threshold 95 --root <replay_root>` exits 0.

- **RISK-2 (SC-9 "≥ 25%" placeholder unbacked)** → **MIT-2 (run
  empirical probe over n≥169 historical payload_breakdown records,
  derive threshold from aggregate_ceiling 80% CI lower bound)** → **T02**
  (built `scripts/diagnostics/m018-section-distribution.sh` with per-tier
  bootstrap CIs, deterministic seed, dual text/json output, model
  assumptions emitted verbatim in `model_assumptions{}`) → **T03 steps
  3-5** (extracted `aggregate_ceiling.low_pct=34.7342` → rounded 34.7%,
  applied byte-surgical spec amendment citing probe outputs and model
  assumptions, shipped `scripts/verify/m018-p00-sc9-calibrated.sh`) →
  verifier exits 0.

- **RISK-3 (US-7 priority and conversus gate Q-1/Q-2 resolution)** is
  spec-side only and was already addressed by the original 2026-04-27
  spec revision (US-7 promoted P3→P2; Q-1/Q-2 resolved). No P00 task
  carries it; tracked here for traceability completeness.

## Followups for downstream phases

- **P01 (grammar-contract)**: SC-9 floor is now 34.7%, not "≥ 25%". The
  grammar-contract design must show, at minimum, that the planned tier
  pipeline can plausibly deliver 35% aggregate savings under the probe's
  per-tier modeling assumptions (the probe carries the receipts; P01's
  conversus gate should re-verify the modeling assumptions are fair).

- **P03 (minimal-slice)**: SC-3 / SC-4 fixture-replay tests should reuse
  the `tests/fixtures/dispatch-state` shape that
  `scripts/verify/m018-p00-fixture-replay.sh` already exercises;
  build-context.sh's fixture mode (where `ORCH_ROOT/phases` exists and
  ORCH_ROOT is not under `.../milestones/<M###>`, log written to
  `ORCH_ROOT/execution-log.jsonl`) is verified working end-to-end.

- **P05 ([M027](../../../../../milestones/M027/index.md) surface integration)**: some `dispatch_usage` records will
  carry `emission_point: build-context` instead of `dispatch-interface`
  -- this is by construction (T01 chose Option 1 co-location to close
  the parity gap). Cost rollups, anomaly detection, and the efficiency
  footer must group-by the `emission_point` field cleanly OR ignore it
  (CON-5 additivity guarantees pre-M018 records remain valid). Cost is
  unaffected: pricing is computed identically regardless of emit site.

- **P06 / P07 (parity audit + SC-9 final report)**: SC-9 must report the
  measured reduction against the 34.7% floor; a measured reduction below
  the floor is a spec-failure regardless of mean. The probe output is
  durable in `.orchestrator/scratch/`; future runs of
  `scripts/diagnostics/m018-section-distribution.sh` against post-M018
  data can compare delta against the pre-M018 baseline captured here.

- **General**: parity verifier already accepts `--root <dir>`
  (functionally equivalent to `--log-path`); fixture-replay-style
  regression tests are cheap to add for any future emitter parity gate.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M018"
name: "Conversus --strict gate run + archive + P01 summary"
depends_on: ["T02"]
---

## Prerequisites

T01 has authored `references/compression-grammar.md` v1.0.0 (frontmatter `status: Draft`); T02 has shipped the lint script and verifiers, appended the M018/P01 entry to `RUNTIME-ASSUMPTIONS.md`, and refreshed the CLAUDE.md / AGENTS.md `recent-changes` block via the dual-write helper. All five T02 verifiers pass:

- `bash scripts/verify/compression-grammar-lint.sh` exits 0.
- `bash scripts/verify/m018-p01-grammar-shape.sh` exits 0.
- `bash scripts/verify/m018-p01-lint-clean.sh` exits 0.
- `bash scripts/verify/m018-p01-sc9-traceability.sh` exits 0.
- `bash scripts/verify/m018-p01-runtime-assumptions.sh` exits 0.
- `bash scripts/verify/m018-p01-dual-write-recent.sh` exits 0.

If any of those fail, T03 does not start; fix in T02 first.

## Description

Run the conversus `--strict` red/blue advocate gate against `references/compression-grammar.md`, archive the result under `.orchestrator/milestones/M018/phases/P01/conversus/`, require a `verdict: "PASS"` to close P01, advance the grammar contract's frontmatter `status:` from `Draft` to `Reviewed`, ship the `m018-p01-conversus-pass.sh` verifier (the last truth check), and write `P01-SUMMARY.md`.

The conversus adapter (`scripts/dispatch/adapters/tool/conversus.sh`) is shipped via M011/P07 and accepts the `gate` subcommand with `--strict`. Calling shape:

```
bash scripts/dispatch/adapters/tool/conversus.sh gate --strict <preset-name> <artifact-path> <output-path>
```

`<preset-name>` is the basename (without `.yml`) of a preset under `templates/conversus-presets/`. T03 ships a new preset `compression-grammar.yml` shaped specifically for this gate — the existing `spec-pressure-test` preset would deliberate against the wrong evaluation criteria.

**Provider environment**: per the user's standing memory (feedback_conversus_provider_claude_code), every conversus invocation in this repo MUST set `CONVERSUS_PROVIDER=claude-code` because the default `anthropic` path returns 429 as a policy gate, not a transient error. Set this in the calling shell before each conversus run.

## Steps

1. **Author the gate preset** at `templates/conversus-presets/compression-grammar.yml`. Use `templates/conversus-presets/spec-pressure-test.yml` as the structural template (red-blue mode, blue/red advocates, arbiter grounded against the constitution). Replace the *charter* prose so advocates argue the right question:

   - Frontmatter:
     ```yaml
     ---
     schema_version: "1.0"
     type: conversus-preset
     ---
     ```
   - `preset_name: compression-grammar`
   - `description`: "Red-blue adversarial deliberation gating the M018 compression-grammar contract. Blue argues the per-tier preservation contracts, marker grammar, and SC-9 plausibility composition are sufficient to gate downstream tier implementations (P02–P05). Red argues the contract has a fatal preservation-gap, marker-grammar ambiguity, modeling-assumption fragility, or SC-9 composition flaw that would let parse-regression slip past the gate. Arbiter grounds verdicts in `.orchestrator/memory/constitution.md` (Principles II, III, XV)."
   - `mode: red-blue`
   - **blue-advocate** charter: defend that the four `## Tier:` sections specify enough to prevent parse-regression, that the marker grammar is unambiguous, that the preserved-pattern vocabulary covers the byte classes that would corrupt downstream parsers (frontmatter, code fences, paths, MEM IDs, command names, URLs, JSONL records, scaffold-placeholder markers), and that the per-tier modeling assumptions in the SC-9 section plausibly compose to ≥ 34.7%. Blue cites specific block names, regexes, and the P00 probe CIs verbatim.
   - **red-advocate** charter: argue at least one of: (a) a preserved-pattern is missing or under-specified such that a tier could corrupt it (e.g., nested code fences, JSONL records inside markdown, multi-line scaffold-placeholder markers); (b) the marker grammar `<!-- compressed:tierN ... -->` is ambiguous (e.g., kvpair value tokenization); (c) a per-tier `applies-to:` block names a class the corresponding `preserves:` block cannot defend (e.g., tier3 summarizes Knowledge sections but does not preserve MEM IDs verbatim across the boundary); (d) the SC-9 composition is fragile — overlap between tiers (filter drops tokens that tier3 would also have summarized) is hand-waved rather than derived from the probe.
   - **arbiter**: `grounding_file: .orchestrator/memory/constitution.md`; `verdict_contract: PASS|BLOCK`; description identical in spirit to spec-pressure-test (weigh disputes, ground in Principles II/III/XV, ties resolve to BLOCK).
   - **output**: `template: templates/gate-result.md`; `required_fields: [verdict, disputes, rationale, source_hash]`.

2. **Confirm the gate output directory exists** by creating it (idempotent):
   ```
   mkdir -p .orchestrator/milestones/M018/phases/P01/conversus
   ```

3. **Confirm CONVERSUS_PROVIDER is set** to `claude-code` in the calling shell:
   ```
   export CONVERSUS_PROVIDER=claude-code
   ```
   Skipping this step risks a 429 policy gate that looks transient but is not. The user has flagged this as standing policy.

4. **Run the conversus gate** at `--strict` against the grammar contract, with output landing under the phase's conversus directory:

   ```
   bash scripts/dispatch/adapters/tool/conversus.sh gate --strict \
     compression-grammar \
     references/compression-grammar.md \
     [.orchestrator/milestones/M018/phases/P01/conversus/gate-result.md](../../../../../milestones/M018/phases/P01/conversus/gate-result.md)
   ```

   The adapter writes a structured `gate-result.md` with frontmatter (`verdict`, `disputes`, `rationale`, `source_hash`, `preset`, `artifact`, `conversus_output_dir`, `conversus_config`) plus a body section. The full deliberation transcripts (red, blue, arbiter, summary) are also written under `.orchestrator/milestones/M018/phases/P01/conversus/{red-advocate,blue-advocate,arbiter,summary}/`.

   **Note**: the adapter takes ~6 minutes wall-clock for a typical gate (per the script's own header documentation). Treat this as a long-running operation; do not poll inside the same task.

5. **Inspect the verdict** by reading the frontmatter of `gate-result.md`. The expected line is `verdict: "PASS"`.

   - **If PASS**: proceed to step 6.
   - **If BLOCK**: read the body's "Surviving disputes" / "Rationale" sections, append findings to a new `## Open Questions` block in `references/compression-grammar.md` (replacing the v1.0.0 placeholder line), revise the contract to address the disputes, bump the frontmatter `version` to `1.0.1` (or higher), re-run the gate at step 4 (output to a new dated subdirectory under conversus/ if you want history; or overwrite gate-result.md — the spec leaves this to the operator). P01 stays open until verdict is PASS.

6. **Advance the grammar contract's frontmatter `status:` from `Draft` to `Reviewed`**. Use `Edit` with `old_string: 'status: "Draft"'` / `new_string: 'status: "Reviewed"'`. Bump `last_revised:` to today (2026-04-27 or the actual gate-run date — use the date of the PASS verdict).

   This satisfies spec.md User Story 1 acceptance scenario 3: "on PASS, the contract document advances to `Status: Reviewed` (frontmatter)".

7. **Ship `scripts/verify/m018-p01-conversus-pass.sh`** — the last truth verifier:
   - Asserts [`.orchestrator/milestones/M018/phases/P01/conversus/gate-result.md`](../../../../../milestones/M018/phases/P01/conversus/gate-result.md) exists.
   - Greps for the literal `verdict: "PASS"` in the frontmatter (the conversus adapter writes verdict on its own line near the top — see `specs/030-context-compression-layer/conversus/gate-result.md` line 2 for shape: `verdict: "BLOCK"`; ours must be `verdict: "PASS"`).
   - Asserts `references/compression-grammar.md` has `status: "Reviewed"` in frontmatter.
   - Single-script-file shape; ~25 lines.
   - Bash 3.2 compatible.

8. **Run all six P01 truth verifiers** to confirm the phase must-haves close:

   ```
   bash scripts/verify/compression-grammar-lint.sh
   bash scripts/verify/m018-p01-grammar-shape.sh
   bash scripts/verify/m018-p01-lint-clean.sh
   bash scripts/verify/m018-p01-sc9-traceability.sh
   bash scripts/verify/m018-p01-runtime-assumptions.sh
   bash scripts/verify/m018-p01-dual-write-recent.sh
   bash scripts/verify/m018-p01-conversus-pass.sh
   ```

   All seven must exit 0. (Six from T02 + one from this task.)

9. **Run the phase-level must-haves check**:

   ```
   bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P01/
   ```

   Must exit 0; lists all six artifacts + truth checks above.

10. **Author `P01-SUMMARY.md`** at [`.orchestrator/milestones/M018/phases/P01/P01-SUMMARY.md`](../../../../../milestones/M018/phases/P01/P01-SUMMARY.md). Use the existing M018/P00-SUMMARY.md as a structural template. Required content:
    - YAML frontmatter (`schema_version: "1.0"`, `type: phase-summary`, `phase: P01`, `milestone: M018`, `status: complete`, `closed_at: <ISO date>`).
    - `## Closure summary` paragraph naming the three deliverables (grammar contract, lint script + RUNTIME-ASSUMPTIONS row, conversus gate PASS).
    - `## Conversus gate result` block: verdict, disputes count, surviving-dispute summary (if any survived a PASS verdict — strict mode will let some disputes survive even on PASS as long as the arbiter weighs them as non-fatal), `source_hash` from gate-result.md frontmatter.
    - `## Per-tier savings ceilings (defended)` block: cite the same per-tier numbers as the grammar contract (filter ≈ 13%, tier1 ≈ 6.3%, tier2 ≈ 25.5%, tier3 ≈ 12.2%; aggregate 34.7% / 35.08% / 35.39%).
    - `## Followups for downstream phases` block, with one bullet per phase P02–P07 naming what each consumes from this phase's contract (e.g., "P02 reads the filter `applies-to:`/`preserves:` blocks when implementing the knowledge-aware filter").
    - `## Risk-mitigation traceability` block tying P01 to the conversus gate's RISK-3 finding (US-7 promotion to P2 — handled spec-side, but P01 ships the contract that downstream Tier 3 quality work depends on).
    - Min 40 lines, contains literal `PASS` (per phase-plan artifact spec).

11. **Final sanity sweep** before declaring P01 closed: `bash scripts/state/derive-phase.sh .orchestrator/milestones/M018/`. Expected output: `executing` (because P02 has no plan yet) or `complete` (if P02+ already advanced via roadmap-derived state). Report observed state.

## Must-Haves

This task addresses the phase must-haves:

- Truth: "conversus `--strict` gate report shows PASS verdict before phase close" — implemented by step 4 + verified by step 7.
- Truth: "grammar contract advances to `Status: Reviewed`" — implemented by step 6.
- Artifact: `templates/conversus-presets/compression-grammar.yml` (created step 1).
- Artifact: [`.orchestrator/milestones/M018/phases/P01/conversus/gate-result.md`](../../../../../milestones/M018/phases/P01/conversus/gate-result.md) (created step 4).
- Artifact: `scripts/verify/m018-p01-conversus-pass.sh` (created step 7).
- Artifact: [`.orchestrator/milestones/M018/phases/P01/P01-SUMMARY.md`](../../../../../milestones/M018/phases/P01/P01-SUMMARY.md) (created step 10).

## Verification

- `bash scripts/verify/m018-p01-conversus-pass.sh` — exits 0 (verdict=PASS + status=Reviewed).
- `bash scripts/dispatch/adapters/tool/conversus.sh parse-verdict [.orchestrator/milestones/M018/phases/P01/conversus/gate-result.md](../../../../../milestones/M018/phases/P01/conversus/gate-result.md)` — emits `verdict=PASS`.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P01/` — exits 0; all phase artifacts + truths confirmed.
- `bash scripts/state/derive-phase.sh .orchestrator/milestones/M018/` — does not regress (state advances forward, never backward).

## Inputs

### From Previous Tasks

- `references/compression-grammar.md` (from T01) — the grammar contract document. Frontmatter `status: "Draft"` on entry; advanced to `"Reviewed"` by this task on PASS verdict.
- `scripts/verify/compression-grammar-lint.sh` (from T02) — the public lint gate (FR-1 / SC-1). T03 does not call it directly but the conversus adapter may; in any case the phase-level must-haves check (step 9) re-runs all verifiers.
- All five `m018-p01-*.sh` verifiers from T02 (grammar-shape, lint-clean, sc9-traceability, runtime-assumptions, dual-write-recent) — must still pass after T03's edits to the contract's frontmatter (`status:` Draft→Reviewed should not break any verifier).

### From Disk (Pre-existing)

- `scripts/dispatch/adapters/tool/conversus.sh` — the conversus adapter from M011/P07 (DEP-4). Subcommand `gate [--strict] <preset-name> <artifact-path> <output-path>`. Behavioral contract: writes `gate-result.md` with frontmatter `verdict: "PASS"|"BLOCK"`, plus full deliberation transcripts under `<output-path-dir>/{red-advocate,blue-advocate,arbiter,summary}/`. Pre-flight refuses artifacts containing `<TODO:` markers (`CONVERSUS_GATE_SKIP_TODO_CHECK=1` to bypass — do not bypass for the grammar contract; the contract must be author-clean).
- `templates/conversus-presets/spec-pressure-test.yml` — structural template for the new preset. Same red-blue mode, same arbiter shape; only the charter prose changes.
- `templates/gate-result.md` — output template the adapter renders into. Read once to confirm field names (verdict, disputes, rationale, source_hash) match what the verifier asserts.
- `.orchestrator/memory/constitution.md` — arbiter's grounding file. Principles II (Evidence Before Claims), III (Design Before Code), XV (Surgical Precision) are the principles the arbiter weighs against.
- [`.orchestrator/milestones/M018/phases/P00/P00-SUMMARY.md`](../../../../../milestones/M018/phases/P00/P00-SUMMARY.md) — structural template for the P01-SUMMARY.md to write at step 10.
- `specs/030-context-compression-layer/conversus/gate-result.md` — example of a prior conversus gate output on the M018 spec (the BLOCK-with-conditions pre-spec gate that drove D028). Useful as a shape reference; do not copy its content.

### From Environment

- `CONVERSUS_PROVIDER=claude-code` — REQUIRED export before step 4. Standing policy per user memory (anthropic 429 = policy gate, not transient).

## Constraints

- **CON-6 (conversus-gate-non-negotiable)** — the gate MUST run at `--strict` and MUST return PASS before P01 closes. BLOCK halts the phase; no fallback is acceptable.
- **CON-1 (read-mostly)** — this task creates exactly one new preset, one new verifier, the gate output (the adapter writes), and the phase summary. It edits the grammar contract's frontmatter `status:` field only (Draft → Reviewed).
- **AD-19 (script-file shape)** — the new verifier is single-script-file shape; conversus invocation is via the adapter's existing entry point.
- **AP-009 (compound-chain-gt2)** — pre-bash-shape-guard hook will fire on commit; new verifier respects the rule.
- **MEM029 / MEM030 (edition handling)** — the conversus adapter resolves `CONVERSUS_EDITION` (oss|paid) automatically; the `compression-grammar` preset must NOT declare `edition_required: paid` because M018 ships under the OSS-default. Verify the preset has no `edition_required:` line in frontmatter (or the line is `edition_required: oss` / absent).
- **Constitution Principle II (Evidence Before Claims)** — the gate verdict is the evidence; T03 does not paraphrase or selectively quote disputes. The verifier asserts the literal frontmatter value.
- **Constitution Principle III (Design Before Code)** — by closing P01 with a PASS verdict, this task confirms the design (grammar contract) is reviewable and adversarially-defensible before any tier code starts in P02.
- **Long-running operation** — conversus gate takes ~6 minutes. Do not embed it in a `Check:` command; it runs once at step 4. Truth verification is on the *artifact* the gate produces (gate-result.md), not on the gate run itself.

## Expected Output

```
$ export CONVERSUS_PROVIDER=claude-code
$ bash scripts/dispatch/adapters/tool/conversus.sh gate --strict \
    compression-grammar \
    references/compression-grammar.md \
    .orchestrator/milestones/M018/phases/P01/conversus/gate-result.md
... (~6 min) ...
PASS: gate complete; verdict=PASS; output=.orchestrator/milestones/M018/phases/P01/conversus/gate-result.md

$ bash scripts/verify/m018-p01-conversus-pass.sh
PASS: gate-result exists
PASS: verdict=PASS
PASS: grammar contract status=Reviewed

$ bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P01/
PASS: references/compression-grammar.md (200+ lines, contains "preserves:")
PASS: scripts/verify/compression-grammar-lint.sh (80+ lines, contains "applies-to")
... (one PASS per artifact)
PASS: all truth checks
PASS: all key links

$ bash scripts/state/derive-phase.sh .orchestrator/milestones/M018/
executing
```

P01 is closed. P02 (Knowledge-Aware Filter) is the next phase per the M018 roadmap; its plan is generated by a fresh invocation of `orchestrator:plan-phase`.

## State Context

- **Current State**: executing
- **Milestone**: M018
- **Phase**: P01
- **Task**: T03-conversus-gate
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **CON-6 (conversus-gate-non-negotiable)** — the gate MUST run at `--strict` and MUST return PASS before P01 closes. BLOCK halts the phase; no fallback is acceptable.
- **CON-1 (read-mostly)** — this task creates exactly one new preset, one new verifier, the gate output (the adapter writes), and the phase summary. It edits the grammar contract's frontmatter `status:` field only (Draft → Reviewed).
- **AD-19 (script-file shape)** — the new verifier is single-script-file shape; conversus invocation is via the adapter's existing entry point.
- **AP-009 (compound-chain-gt2)** — pre-bash-shape-guard hook will fire on commit; new verifier respects the rule.
- **MEM029 / MEM030 (edition handling)** — the conversus adapter resolves `CONVERSUS_EDITION` (oss|paid) automatically; the `compression-grammar` preset must NOT declare `edition_required: paid` because M018 ships under the OSS-default. Verify the preset has no `edition_required:` line in frontmatter (or the line is `edition_required: oss` / absent).
- **Constitution Principle II (Evidence Before Claims)** — the gate verdict is the evidence; T03 does not paraphrase or selectively quote disputes. The verifier asserts the literal frontmatter value.
- **Constitution Principle III (Design Before Code)** — by closing P01 with a PASS verdict, this task confirms the design (grammar contract) is reviewable and adversarially-defensible before any tier code starts in P02.
- **Long-running operation** — conversus gate takes ~6 minutes. Do not embed it in a `Check:` command; it runs once at step 4. Truth verification is on the *artifact* the gate produces (gate-result.md), not on the gate run itself.

### Acceptance Criteria

This task addresses the phase must-haves:

- Truth: "conversus `--strict` gate report shows PASS verdict before phase close" — implemented by step 4 + verified by step 7.
- Truth: "grammar contract advances to `Status: Reviewed`" — implemented by step 6.
- Artifact: `templates/conversus-presets/compression-grammar.yml` (created step 1).
- Artifact: [`.orchestrator/milestones/M018/phases/P01/conversus/gate-result.md`](../../../../../milestones/M018/phases/P01/conversus/gate-result.md) (created step 4).
- Artifact: `scripts/verify/m018-p01-conversus-pass.sh` (created step 7).
- Artifact: [`.orchestrator/milestones/M018/phases/P01/P01-SUMMARY.md`](../../../../../milestones/M018/phases/P01/P01-SUMMARY.md) (created step 10).

### Files To Touch

- `references/compression-grammar.md` (create — T01)
- `scripts/verify/compression-grammar-lint.sh` (create — T02)
- `scripts/verify/m018-p01-grammar-shape.sh` (create — T02)
- `scripts/verify/m018-p01-lint-clean.sh` (create — T02)
- `scripts/verify/m018-p01-sc9-traceability.sh` (create — T02)
- `scripts/verify/m018-p01-runtime-assumptions.sh` (create — T02)
- `scripts/verify/m018-p01-conversus-pass.sh` (create — T03)
- `scripts/verify/m018-p01-dual-write-recent.sh` (create — T02)
- `templates/conversus-presets/compression-grammar.yml` (create — T03)
- `RUNTIME-ASSUMPTIONS.md` (modify — T02 appends M018/P01 entry)
- `CLAUDE.md` (modify — T02 refreshes `orchestrator:recent-changes` block)
- `AGENTS.md` (modify — T02 via `scripts/util/dual-write-runtime-md.sh`; never edited directly)
- `.orchestrator/milestones/M018/phases/P01/conversus/conversus.yml` (create — T03 via conversus adapter)
- [`.orchestrator/milestones/M018/phases/P01/conversus/gate-result.md`](../../../../../milestones/M018/phases/P01/conversus/gate-result.md) (create — T03)
- [`.orchestrator/milestones/M018/phases/P01/conversus/summary/final.md`](../../../../../milestones/M018/phases/P01/conversus/summary/final.md) (create — T03 via conversus adapter)
- [`.orchestrator/milestones/M018/phases/P01/P01-SUMMARY.md`](../../../../../milestones/M018/phases/P01/P01-SUMMARY.md) (create — T03)

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