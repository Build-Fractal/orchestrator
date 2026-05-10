---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T03-escalation-loop (Phase P04, Milestone M030)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~400 | required |
| Upstream Context | 981-1145 | ~6300 | required |
| Task Plan | 1147-1746 | ~11300 | required |
| State Context | 1748-1754 | ~100 | required |
| First-Turn Completeness | 1756-1822 | ~1600 | required |
| **Total** | | **~30500** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 677
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
hit_count: 677
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
hit_count: 677
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
hit_count: 677
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
hit_count: 597
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
hit_count: 597
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
hit_count: 597
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
hit_count: 677
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
hit_count: 597
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
hit_count: 597
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
hit_count: 597
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
hit_count: 677
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
hit_count: 677
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
hit_count: 677
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
hit_count: 597
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
hit_count: 597
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
hit_count: 597
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
hit_count: 677
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
hit_count: 597
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
hit_count: 597
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
hit_count: 677
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
hit_count: 677
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
hit_count: 597
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
hit_count: 597
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
hit_count: 597
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
hit_count: 252
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
hit_count: 252
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
hit_count: 252
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
hit_count: 253
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
hit_count: 253
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
hit_count: 243
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
     slug-bearing filenames (p04-*) so install-clobber risk is contained.
     Verifier authorship is co-scheduled with the artifact it gates, in
     the SAME task, per Plan-Time Discipline rule 2. T01 ships fixtures
     + the stub-fail-n adapter + tolerant pre-amendment gates BEFORE T02
     amends dispatch-interface.sh. T02 ships the live-routing branch +
     flip-gate enforcement + partial-flip routing + co-authored
     verifiers (SC-2a, SC-3, partial-flip, CON-3 live-closure, CON-4
     live-killswitch, SC-11 pass-through). T03 ships the escalation
     loop + CON-5 hard-cap + CON-6 prior-records-bit-identical
     verifier. T04 closes with the phase-suite aggregator. Strict
     linear chain T01→T02→T03→T04. -->

### Truths

- `scripts/dispatch/dispatch-interface.sh` short-circuits before invoking any backend adapter when `.orchestrator/config.yml` declares `model_routing:` with `live: true` AND `bash scripts/diagnostics/shadow-compare.sh --corpus <empty>` returns `flip_recommendation=evidence_insufficient`. The dispatch-interface invocation exits nonzero and the appended JSONL line records `override_source=shadow_gate_blocked`. The verifier stages a config with `live: true`, an empty execution log (zero shadow records), and asserts (i) dispatch-interface exit code is nonzero, (ii) the appended JSONL `override_source` field equals `shadow_gate_blocked`, (iii) NO record_type=dispatch_result line was written by the stub adapter (the adapter was never invoked). (FR-9 / SC-2a / D-A2.)
  - Check: `bash tools/verify/p04-sc2a-shadow-gate-block.sh`

<dispatch-volatile>

## Upstream Context


### P02 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P02"
parent: "M030"
milestone: "M030"
provides:
  - "tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl,tests/fixtures/m030-p02/round-trip-stage/,tools/verify/p02-fixture-shape.sh,tools/verify/p02-additive-schema.sh,dispatch-interface.sh shadow hook (M030_SHADOW_MODE+CLAUDECODE gated classifier+routing-table emit),4 additive JSONL fields (model_routed,model_used,partial_flip_active,withheld_classes),tools/verify/p02-shadow-emit.sh,tools/verify/p02-con3-closure.sh,tools/verify/p02-append-only.sh,scripts/diagnostics/shadow-compare.sh (4-verdict aggregator),tools/verify/p02-shadow-compare-verdicts.sh,tools/verify/p02-partial-flip-enum.sh,tools/verify/p02-stability-metric-traceability.sh,tools/verify/p02-sc3a-roundtrip.sh,5 shadow-corpus JSONL fixtures,classifier_confidence additive field on dispatch-interface.sh shadow-on emit,tools/verify/p02-phase-suite.sh straight-line aggregator over 9 P02 sub-gates; CLAUDE.md+AGENTS.md recent-changes P02-close fragment"
requires:
  - "P01"
affects:
  - "P03,P04,P05,P06,P07"
key_files:
  - "tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl,tests/fixtures/m030-p02/round-trip-stage/phases/P01/tasks/M001-T01-stage-PLAN.md,tests/fixtures/m030-p02/round-trip-stage/phases/P01/tasks/T01-stage-PAYLOAD.md,tests/fixtures/m030-p02/round-trip-stage/intensity-metadata.txt,tools/verify/p02-fixture-shape.sh,tools/verify/p02-additive-schema.sh,scripts/dispatch/dispatch-interface.sh,tools/verify/p02-shadow-emit.sh,tools/verify/p02-con3-closure.sh,tools/verify/p02-append-only.sh,scripts/diagnostics/shadow-compare.sh,tools/verify/p02-shadow-compare-verdicts.sh,tools/verify/p02-partial-flip-enum.sh,tools/verify/p02-stability-metric-traceability.sh,tools/verify/p02-sc3a-roundtrip.sh,tests/fixtures/m030-p02/shadow-corpus-ready.jsonl,tests/fixtures/m030-p02/shadow-corpus-partially-ready.jsonl,tests/fixtures/m030-p02/shadow-corpus-evidence-insufficient.jsonl,tests/fixtures/m030-p02/shadow-corpus-block.jsonl,tests/fixtures/m030-p02/sc3a-roundtrip-corpus.jsonl,tools/verify/p02-phase-suite.sh,CLAUDE.md,AGENTS.md,[.orchestrator/milestones/M030/phases/P02/P02-PLAN.md](../../../../../milestones/M030/phases/P02/P02-PLAN.md)"
key_decisions:
  - "SC-11 byte-equality verifier authored before T02 amends dispatch-interface.sh (graduation-verifier pattern reused from P01/T01); pricing-warning + adapter-failed shapes covered via fixture-presence grep only -- full round-trip would require stale-pricing-rate or crashing-adapter setup,both out-of-scope for byte-equality gate; payload sized to exactly 4096B so chars_to_tokens_quartile=1024 deterministically matches fixture record 1; round-trip plan basename includes M001 token so MILESTONE_ID regex extraction succeeds without restructuring tests/fixtures/ tree,dual-printf-branch-per-emit-side preserves SC-11 byte-equality mechanically;awk-section-walker (P01 pattern) extracts routing+resolution at dispatch time;CC-only short-circuit gated by CLAUDECODE=1 AND M030_SHADOW_MODE=1;partial_flip_active=false / withheld_classes=empty as P03/P04 schema reservation,D-A1-4-verdict-closed-enum;D-A3-partial-flip-safety-smart-default-only;D-A7-SC-3a-write-path-correctness;classifier_confidence-field-end-to-end-in-P02-not-deferred-to-P03,phase-suite-shape-mirrors-p01-straight-line-AD-19-no-loops; plan-side-grep-amendments-tier-symbols-not-character-labels-CON-3; plan-side-key-link-direction-corrections-dispatch-interface-references-upstreams"
patterns_established:
  - "round-trip-byte-equality fixture pattern: committed payload+plan+intensity-metadata stage with deterministic byte length; ORCHESTRATOR_ROOT carve-out routes log to staged dir; timestamp-normalization sed before diff yields full byte-equality minus the dynamic field; tools/verify/p02-* slug-bearing filenames per project-owned-verifier-paths discipline; AD-19 single-script-file shape preserved with parallel grep-q + rc captures (no compound chains),dual-format-string emit branches (shadow-on adds 4 trailing fields; shadow-off byte-identical to pre-amendment);CON-3 closure verifier compares HEAD-vs-working-tree per-pattern grep counts (no new provider model-ID literals);append-only verifier asserts inode + first-N-lines + line-count delta = +1,awk-section-walker-extended-to-tier-to-class-inverse-map;tmp-file-staging-for-routing-map-to-bypass-macos-awk-multiline-v-limit;SSOT-numeric-traceability-via-awk-line-content-predicate-not-grep-line-number-prefix;per-record-loop-unrolled-into-explicit-blocks-AD-19;classifier-confidence-end-to-end-from-classifier-emit-to-shadow-record-to-variance-aggregator,phase-suite-aggregator-extends-from-7-to-9-gates-without-shape-change; plan-amendment-pattern-when-must-haves-grep-fails-but-phase-suite-green"
drill_down_paths:
  - "[.orchestrator/milestones/M030/phases/P02/tasks/T01-SUMMARY.md](../../../../../milestones/M030/phases/P02/tasks/T01-SUMMARY.md), [.orchestrator/milestones/M030/phases/P02/tasks/T02-dispatch-shadow-hook-SUMMARY.md](../../../../../milestones/M030/phases/P02/tasks/T02-dispatch-shadow-hook-SUMMARY.md), [.orchestrator/milestones/M030/phases/P02/tasks/T03-shadow-compare-SUMMARY.md](../../../../../milestones/M030/phases/P02/tasks/T03-shadow-compare-SUMMARY.md), [.orchestrator/milestones/M030/phases/P02/tasks/T04-phase-suite-and-close-SUMMARY.md](../../../../../milestones/M030/phases/P02/tasks/T04-phase-suite-and-close-SUMMARY.md)"
duration: "245m"
verification_result: "pass"
completed_at: "2026-04-30T14:35:53Z"
observability_surfaces:
  - "none"
---

## P02: Shadow-Mode Telemetry + Routing Verifier Suite

P02 builds the shadow-mode emit path on top of P01's classifier and routing table, then closes with a 9-gate phase-suite verifier that locks every property into a single mechanical aggregator.

### What was built

**T01 — pre-M030 dispatch_usage fixture + additive-schema gate (preflight, shipped pre-P02 in commit `91a743e`).** Hand-authored 5-record JSONL at `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` covering happy-path / pricing-warning / adapter-failed / cost-null / latest-baseline shapes. SC-11 byte-equality verifier `tools/verify/p02-additive-schema.sh` round-trips the fixture's first record through `dispatch-interface.sh` under `M030_SHADOW_MODE=0`, normalizes the dynamic timestamp, and asserts byte-identity. Round-trip stage at `tests/fixtures/m030-p02/round-trip-stage/` provides a deterministic 4096B payload + intensity-metadata fixture so `chars_to_tokens_quartile=1024` matches mechanically. Authoring the verifier *before* T02 amended the emitter is the graduation-verifier pattern reused from P01/T01.

**T02 — dispatch-interface shadow hook + 4-field schema (commit `6d23af5`).** Amended `scripts/dispatch/dispatch-interface.sh` with a CC-only shadow path gated on `M030_SHADOW_MODE=1 && CLAUDECODE=1`. The hook calls `scripts/dispatch/classify-task.sh`, walks `templates/model-routing.yml`'s `routing:` + `resolution:` blocks via an awk section-walker (extending the P01 pattern), and emits four additive fields: `model_routed` (symbolic routing-table choice), `model_used` (runtime default in shadow mode), `partial_flip_active=false`, `withheld_classes=` (both reserved for P03/P04). Dual format-string branches preserve SC-11 byte-equality: shadow-off emits the pre-amendment line literal-for-literal; shadow-on appends the four fields. Zero new provider model-ID literals introduced — every concrete model identifier resolves through `templates/model-routing.yml`. Closes CON-3 mechanically.

**T03 — shadow-compare 4-verdict aggregator + classifier-confidence end-to-end (commit `3936738`).** New `scripts/diagnostics/shadow-compare.sh` consumes shadow JSONL corpora and emits exactly one `flip_recommendation=` line drawn from the closed enum `{ready, partially_ready, block, evidence_insufficient}` (D-A1). Partial-flip safety: only classes whose routing-table default is `smart` may be enumerated in `withheld_classes` (D-A3). Pinned stability-metric numerics (variance ≤ 0.10, N=20, per-class coverage 50) traceable to `references/model-routing.md` SSOT via inline reference comments — verified by per-line content predicate (not `grep -n` line-number-prefix, which produces false-positive substring matches). T03 also amended `dispatch-interface.sh` to emit `classifier_confidence` end-to-end so the variance-stability check is genuinely usable in P02 rather than deferred to P03 (D-A7 / SC-3a write-path correctness).

**T04 — phase-suite aggregator + close prep (commit `55ebeea`).** `tools/verify/p02-phase-suite.sh` invokes all nine sub-gates in literal sequence (`set -uo pipefail`, no loops, `$?` capture per sub-gate, single `SUMMARY:` line) — same straight-line shape as `p01-phase-suite.sh`. CLAUDE.md + AGENTS.md recent-changes fragment via `dual-write-runtime-md.sh --append-entry`. Plan-side amendments to `P02-PLAN.md` resolved 4 `check-must-haves.sh` gaps that were artifact-grep / key-link-direction errors, not task re-opens (per Step-7 plan rule).

### Verification

- `tools/verify/p02-phase-suite.sh` → pass=9 fail=0 (fixture-shape 23/0, additive-schema 6/0, shadow-emit 17/0, con3-closure 7/0, append-only 4/0, shadow-compare-verdicts 4/0, partial-flip-enum 6/0, stability-metric-traceability 3/0, sc3a-roundtrip 6/0)
- `scripts/verify/check-must-haves.sh` → 10 truths + 49 artifacts + 9 key-links all PASS
- `P02-VERIFICATION.md` → overall_result=pass (Tier 1 pass=69/69; Tier 2/3/4 skip)

### Key decisions

- **D-A1 closed-enum 4-verdict**: `flip_recommendation` ∈ `{ready, partially_ready, block, evidence_insufficient}` — no string-interpolation, no open enumeration.
- **D-A3 partial-flip safety**: only `smart`-defaulted classes may be enumerated in `withheld_classes` — fast / balanced classes either flip wholesale or block.
- **D-A7 / SC-3a**: re-classifying the plan path of any shadow record's `unitId` MUST agree with the recorded `model_routed` — verified end-to-end via `tools/verify/p02-sc3a-roundtrip.sh` over a 6-record fixture (2 fast / 2 balanced / 2 smart).
- **Classifier-confidence in P02, not P03**: the variance-stability metric requires per-record confidence; emitting it end-to-end now means P03 can land its variance aggregator without re-amending the emitter.
- **Phase-suite shape mirrors P01**: straight-line, no loops, AD-19-clean.

### Patterns established

- Dual-format-string emit branches preserve byte-equality across additive schema changes — the shadow-off branch is byte-identical to pre-amendment; shadow-on appends fields after the existing set.
- CON-3 closure verifier compares HEAD vs working-tree per-pattern grep counts so the closure constraint can be re-checked on every commit cycle without snapshot drift.
- Append-only JSONL verification via inode preservation + first-N-lines bit-identity + line-count delta = +1.
- AD-19 single-script-file shape preserved through parallel `grep -q` + return-code captures rather than compound `&&`/`||` chains; per-record corpora unrolled into explicit blocks rather than `for` loops.
- Plan-amendment-not-task-reopen pattern when phase-suite is green but `check-must-haves.sh` fails on artifact-grep or key-link-direction.

### Provides downstream

- `dispatch-interface.sh` shadow path + 5 emitted fields → P03 shadow-compare aggregator over real auto-loop telemetry corpus
- `shadow-compare.sh` → P04 partial-flip activation gate
- 9 P02 verifiers + classifier_confidence emit → P03/P04/P05/P06/P07 reuse without re-amendment

### Phase metrics

- 4 tasks (T01 preflight + T02 + T03 + T04)
- Duration: ~245m total dispatch + verify + close
- Phase verification: pass (Tier 1 69/69)
- 0 task re-opens (T04 plan-side-amendment pattern resolved must-have gaps cleanly)


### P03 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P03"
parent: "M030"
milestone: "M030"
provides:
  - "tests/fixtures/m030-p03/plans/ (3 fixture plans),tests/fixtures/m030-p03/configs/ (4 fixture configs),tests/fixtures/m030-p03/round-trip-stage/ (intensity-metadata.txt + payload.txt),tools/verify/p03-additive-schema.sh (P02 SC-11 pass-through),tools/verify/p03-override-source-enum.sh (5-scenario closed-enum gate pre-amendment-tolerant),dispatch-interface.sh override-resolution path (kill-switch->plan-frontmatter->milestone-floor->none precedence chain),_di_tier_rank helper,2 shadow-on printf format-string extensions adding override_source field,4 new T02 verifiers (p03-sc7-kill-switch.sh p03-sc7a-compound.sh p03-min-tier-floor.sh p03-con3-closure.sh),tools/verify/p03-sc6-frontmatter-override.sh (SC-6 gate FR-11),tools/verify/p03-override-conflict.sh (FR-14 floor-wins gate),references/model-routing.md ## Operator Overrides section + 2 ## See Also bullets,tools/verify/p03-phase-suite.sh straight-line aggregator over 8 P03 sub-gates; CLAUDE.md+AGENTS.md recent-changes P03-close fragment; P03 close commit d70386d"
requires:
  - "P02"
affects:
  - "P04,P07"
key_files:
  - "tests/fixtures/m030-p03/plans/plan-with-frontmatter-override.md,tests/fixtures/m030-p03/plans/plan-mechanical-no-override.md,tests/fixtures/m030-p03/plans/plan-frontmatter-fast-vs-floor.md,tests/fixtures/m030-p03/configs/config-baseline.yml,tests/fixtures/m030-p03/configs/config-with-routing-disabled.yml,tests/fixtures/m030-p03/configs/config-with-min-tier-smart.yml,tests/fixtures/m030-p03/configs/config-with-killswitch-and-floor.yml,tests/fixtures/m030-p03/round-trip-stage/intensity-metadata.txt,tests/fixtures/m030-p03/round-trip-stage/payload.txt,tools/verify/p03-additive-schema.sh,tools/verify/p03-override-source-enum.sh,scripts/dispatch/dispatch-interface.sh,tools/verify/p03-sc7-kill-switch.sh,tools/verify/p03-sc7a-compound.sh,tools/verify/p03-min-tier-floor.sh,tools/verify/p03-con3-closure.sh,tools/verify/p03-sc6-frontmatter-override.sh,tools/verify/p03-override-conflict.sh,references/model-routing.md,tools/verify/p03-phase-suite.sh,CLAUDE.md,AGENTS.md,[.orchestrator/milestones/M030/phases/P03/P03-PLAN.md](../../../../../milestones/M030/phases/P03/P03-PLAN.md),[.orchestrator/milestones/M030/phases/P03/tasks/T01-fixtures-and-enum-gate-PLAN.md](../../../../../milestones/M030/phases/P03/tasks/T01-fixtures-and-enum-gate-PLAN.md),[.orchestrator/milestones/M030/phases/P03/tasks/T02-override-resolution-PLAN.md](../../../../../milestones/M030/phases/P03/tasks/T02-override-resolution-PLAN.md),[.orchestrator/milestones/M030/phases/P03/tasks/T03-sc6-and-conflict-PLAN.md](../../../../../milestones/M030/phases/P03/tasks/T03-sc6-and-conflict-PLAN.md),[.orchestrator/milestones/M030/phases/P03/tasks/T04-phase-suite-and-close-PLAN.md](../../../../../milestones/M030/phases/P03/tasks/T04-phase-suite-and-close-PLAN.md)"
key_decisions:
  - "pre-amendment-tolerant enum check (zero tokens PASS pre-T02; exactly one with enum-valid value PASS post-T02; non-enum or count!=1 FAIL) reuses graduation-verifier pattern from P02/T01; tmp_root staging strategy uses ORCH_ROOT/phases/ carve-out so log routes to <tmp_root>/execution-log.jsonl regardless of fixture-plan path lacking uppercase M### tokens; kill switch placed at config top-level (model_routing_enabled: false) per FR-13 framing; min_tier nested under model_routing per FR-12 (one knob among several); compound config (kill-switch+floor) ships as SC-7a fixture; per-scenario tmp_root + cleanup avoids collisions across parallel runs; tmp-file intermediates throughout (no cmd-pipe-grep-pipe-head chains) per AP-009; expected-value parameter in _check_enum_tolerant tightens post-T02 assertion without breaking pre-amendment-tolerance,config-resolution-three-candidate-paths-ORCH_ROOT-config-yml-then-ORCH_ROOT-dot-orchestrator-config-yml-then-ORCH_ROOT-parent-config-yml,shadow_used-equals-model-runtime-default-channel-under-disabled-recommended-populate-explicitly-shape,floor-wins-conflict-uses-numeric-tier-rank-comparison-with-minus-one-unknown-guard,override-resolution-block-runs-before-routing-extraction-three-mutually-exclusive-post-block-awk-paths,references-doc-Operator-Overrides-section-lands-in-P03-not-P05-to-close-operator-visibility-loop-the-moment-T02-emitter-ships,CON-3-enforced-via-runtime-awk-extraction-of-resolution-smart-claude-code-from-templates-model-routing-yml-not-hardcoded-literal,no-dispatch-interface-change-FR-14-warning-already-authored-in-T02-T03-only-ships-the-gate-verifier-and-the-references-doc-edit,references-doc-is-SSOT-for-warning-string-shape-future-amendments-must-re-align-dispatch-interface,phase-suite-shape-mirrors-p02-straight-line-AD-19-no-loops; sub-gate-ordering-fundamental-contract-first-then-enum-then-con3-then-scenarios-then-fr14-conflict-last; no-plan-side-amendments-needed-check-must-haves-clean-first-try; dual-write-helper-requires-marker-flag-payload-example-was-shorthand"
patterns_established:
  - "pre-amendment-tolerant verifier pattern: zero-tokens-PASS branch + exactly-one-with-enum-valid-value-PASS branch; SAME verifier file flips from tolerant to strict as the deliverable that satisfies it lands; ORCH_ROOT/phases carve-out exploited for fixture log-routing without restructuring tests/fixtures/ to encode uppercase M###; per-scenario tmp_root+cleanup with mktemp -d fallback; 5-scenario closed-enum coverage shape (4 shadow-on overlay-product + 1 shadow-off most-overlay-rich strict-zero); pass-through wrapper pattern (p03-additive-schema.sh delegates to p02-additive-schema.sh) for phase-suite friendliness without duplicating round-trip logic,override-resolution-before-routing-extraction-shape,stderr-warning-emission-inside-emitter-body-with-two-distinct-warning-shapes,per-pattern-HEAD-vs-WT-grep-count-comparison-mirrors-P02-CON3-closure-shape,round-trip-verifier-shape-reused-from-T01-tmp_root-with-dot-orchestrator-config-yml-and-phases-subdir,runtime-extraction-of-expected-literal-from-SSOT-via-awk-section-walker-mirrors-P02-T03-stability-metric-pattern,stderr-capture-via-2-redirect-then-per-pattern-grep-line-count-assertions-AP-009-compliant,operator-facing-precedence-chain-documentation-co-locates-with-gate-verifier-ship-date,phase-suite-aggregator-extends-from-9-gates-P02-to-8-gates-P03-without-shape-change; plan-prediction-quality-improved-after-P02-T04-amendment-cycle-no-amendments-needed-in-P03; payload-quoted-helper-invocations-may-be-shorthand-verify-against-helper-help-text"
drill_down_paths:
  - "[.orchestrator/milestones/M030/phases/P03/tasks/T01-fixtures-and-enum-gate-SUMMARY.md](../../../../../milestones/M030/phases/P03/tasks/T01-fixtures-and-enum-gate-SUMMARY.md), [.orchestrator/milestones/M030/phases/P03/tasks/T02-override-resolution-SUMMARY.md](../../../../../milestones/M030/phases/P03/tasks/T02-override-resolution-SUMMARY.md), [.orchestrator/milestones/M030/phases/P03/tasks/T03-sc6-and-conflict-SUMMARY.md](../../../../../milestones/M030/phases/P03/tasks/T03-sc6-and-conflict-SUMMARY.md), [.orchestrator/milestones/M030/phases/P03/tasks/T04-phase-suite-and-close-SUMMARY.md](../../../../../milestones/M030/phases/P03/tasks/T04-phase-suite-and-close-SUMMARY.md)"
duration: "238m"
verification_result: "pass"
completed_at: "2026-04-30T15:24:30Z"
observability_surfaces:
  - "none"
---

## P03: Operator Overrides — Kill-Switch + Frontmatter + Floor

P03 lands the operator-override surface on top of P02's shadow-mode telemetry: a CC-only override-resolution path inside `dispatch-interface.sh`, an extended `override_source` enum emitted in shadow records, and an `## Operator Overrides` section in `references/model-routing.md` that documents the precedence chain end-to-end.

### What was built

**T01 — fixture plans + overlay configs + override-source-enum gate (commit `7b285a2`).** Three fixture task plans (`plan-with-frontmatter-override.md`, `plan-mechanical-no-override.md`, `plan-frontmatter-fast-vs-floor.md`) drive the SC-6/SC-7/FR-14 scenarios. Four overlay configs (baseline / routing-disabled / min-tier-smart / killswitch-and-floor) provide overlay products. `tools/verify/p03-override-source-enum.sh` is the pre-amendment-tolerant gate (zero-tokens-PASS pre-T02, exactly-one-with-enum-valid-value-PASS post-T02). Round-trip stage (`tests/fixtures/m030-p03/round-trip-stage/`) provides a 466B payload + intensity-metadata. ORCH_ROOT-with-phases carve-out exploited so log routes to `<tmp_root>/execution-log.jsonl` regardless of fixture-plan path lacking uppercase `M###` tokens — established the tmp-root staging pattern reused by all T02/T03 verifiers.

**T02 — override-resolution path + 4 verifiers (commit `4e3d678`).** Amended `scripts/dispatch/dispatch-interface.sh` with the `_di_tier_rank` helper and an override-resolution block (kill-switch → plan-frontmatter → milestone-floor → none) that runs *before* routing-extraction. Two shadow-on printf format-string extensions added the `override_source` field. Four verifiers shipped: `p03-sc7-kill-switch.sh` (config kill-switch wins), `p03-sc7a-compound.sh` (kill-switch + frontmatter compound: kill-switch wins), `p03-min-tier-floor.sh` (`min_tier=smart` floors lower-tier classes), `p03-con3-closure.sh` (zero new provider model-ID literals introduced — closure preserved at runtime via `templates/model-routing.yml` resolution). Config-resolution chain extended to three candidate paths (`$ORCH_ROOT/config.yml` → `$ORCH_ROOT/.orchestrator/config.yml` → `$ORCH_ROOT/../config.yml`).

**T03 — SC-6 + FR-14 + operator-overrides docs (commit `d4646e7`).** `tools/verify/p03-sc6-frontmatter-override.sh` exercises the SC-6 happy-path (frontmatter `model_override` resolves to `templates/model-routing.yml resolution.smart.claude-code` via runtime awk extraction — no hardcoded literals, CON-3-clean). `tools/verify/p03-override-conflict.sh` exercises FR-14 (frontmatter+floor conflict → floor wins, stderr warning shape pinned to "floor wins"). `references/model-routing.md` gains the `## Operator Overrides` section between Stability Metric and See Also: precedence chain table, compound-warning cases, full 5-value `override_source` closed enum (`none` / `disabled` / `plan_frontmatter` / `milestone_floor` / `shadow_gate_blocked`, with `shadow_gate_blocked` reserved for FR-9 / P05). Zero changes to `dispatch-interface.sh` — the FR-14 warning was already authored in T02; T03 ships the gate verifier and the doc.

**T04 — phase-suite aggregator + close (commit `d70386d`).** `tools/verify/p03-phase-suite.sh` invokes all 8 sub-gates in literal sequence (same straight-line shape as `p02-phase-suite.sh`, AD-19-clean, bash 3.2 compatible). CLAUDE.md + AGENTS.md recent-changes fragment via `dual-write-runtime-md.sh --marker recent-changes --append-entry "..."`. `check-must-haves.sh` returned 67 PASS / 0 FAIL on first try — zero plan-side amendments needed (P03 plan predicates were authored cleaner than P02's).

### Verification

- `tools/verify/p03-phase-suite.sh` → pass=8 fail=0 (additive-schema 1/0, override-source-enum 6/0, con3-closure 7/0, sc6-frontmatter-override 4/0, sc7-kill-switch 2/0, sc7a-compound 3/0, min-tier-floor 3/0, override-conflict 5/0)
- `scripts/verify/check-must-haves.sh` → 67 PASS / 0 FAIL (truths + artifacts + key-links)
- `P03-VERIFICATION.md` → overall_result=pass (Tier 1 67/67; Tier 2/3/4 skip)

### Key decisions

- **Pre-amendment-tolerant verifier pattern** carried forward from P02/T01: same verifier file flips from tolerant to strict as the deliverable that satisfies it lands.
- **Override-resolution runs *before* routing-extraction**, with three mutually-exclusive post-block awk paths (frontmatter / floor / none).
- **Floor-wins conflict resolution** uses numeric tier-rank comparison via `_di_tier_rank` with a `-1` unknown-guard.
- **5-value `override_source` enum** closed at P03 close: `none` / `disabled` / `plan_frontmatter` / `milestone_floor` / `shadow_gate_blocked`. The fifth (`shadow_gate_blocked`) is reserved for FR-9 in P05; documenting it now locks the schema so P05 lands without surprise.
- **CON-3 enforced via runtime awk extraction** of `resolution.smart.claude-code` from `templates/model-routing.yml` — no hardcoded literals in either dispatch-interface.sh or the verifiers.
- **References doc is SSOT** for the FR-14 warning string shape; future amendments to `dispatch-interface.sh` must re-align with the doc.
- **Phase-suite shape mirrors P02** straight-line AD-19 (no loops); sub-gate ordering: fundamental contract first, then enum, then CON-3, then scenarios, then FR-14 conflict last.
- **No plan-side amendments needed** — first-try `check-must-haves.sh` clean. The P02/T04 plan-amendment-not-task-reopen pattern was not exercised; planner-template improvements after P02 paid off.

### Patterns established

- Override-resolution before routing-extraction with three mutually-exclusive awk post-block paths.
- Stderr-warning emission inside the emitter body with two distinct warning shapes (kill-switch active / floor wins).
- Per-pattern HEAD-vs-working-tree grep count comparison mirrors P02 CON-3 closure shape.
- Round-trip verifier shape reused from T01 (tmp_root + `.orchestrator/config.yml` + `phases/` carve-out).
- Runtime extraction of expected literals from SSOT via awk section-walker mirrors P02/T03 stability-metric pattern.
- Stderr-capture via `2>` redirect + per-pattern grep line-count assertions, AP-009-compliant.
- Pass-through wrapper pattern (`p03-additive-schema.sh` delegates to `p02-additive-schema.sh`) keeps the phase-suite friendly without duplicating round-trip logic.
- Operator-facing precedence-chain docs co-locate with gate-verifier ship date, closing the operator-visibility loop the moment the emitter ships.

### Provides downstream

- `dispatch-interface.sh` override-resolution path → P04 partial-flip activation (consumes `override_source` enum)
- `references/model-routing.md ## Operator Overrides` section → P07 distribution (operator-readable doc surface)
- 9 P03 verifiers + extended schema → P04 reuse without re-amendment

### Phase metrics

- 4 tasks (T01 → T02 → T03 → T04, strict linear chain)
- Duration: ~238m total dispatch + verify + close
- Phase verification: pass (Tier 1 67/67)
- 0 task re-opens, 0 plan-side amendments
- 4 atomic commits: 7b285a2 (T01) → 4e3d678 (T02) → d4646e7 (T03) → d70386d (T04)

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P04"
milestone: "M030"
name: "dispatch-interface escalation loop + CON-5 hard-cap + escalation_cap_hit record + CON-6 append-only verifier"
depends_on: ["T02"]
---

## Prerequisites

- All T01 + T02 deliverables on disk and green:
  - `bash tools/verify/p04-additive-schema.sh` exits 0 (T01)
  - `bash tools/verify/p04-override-source-enum-extended.sh` exits 0 strict-mode (T02)
  - `bash tools/verify/p04-sc2a-shadow-gate-block.sh` exits 0 (T02)
  - `bash tools/verify/p04-sc3-live-mechanical.sh` exits 0 (T02)
  - `bash tools/verify/p04-partial-flip-routing.sh` exits 0 (T02)
  - `bash tools/verify/p04-con3-live-closure.sh` exits 0 (T02)
  - `bash tools/verify/p04-con4-live-killswitch.sh` exits 0 (T02)
- scripts/dispatch/dispatch-interface.sh exists in its post-T02 form: live-routing branch reads `model_routing.live`; programmatic shadow-compare invocation; conditional `--model "$_DI_LIVE_MODEL_FLAG"` to backend adapter; `_DI_LIVE_GATE_BLOCKED` short-circuits adapter invocation; kill-switch path emits `live: true is inactive` warning when applicable.
- scripts/dispatch/adapters/backend/stub-fail-n.sh exists (T01) with the read-decrement counter contract, the `STUB_FAIL_COUNTER_INVOCATIONS_FILE` side-channel, and the `STUB_INVOCATION_SENTINEL_DIR` sentinel-drop hook.
- tests/fixtures/m030-p04/plans/{plan-fail-twice-then-pass,plan-fail-three-times,plan-fail-four-times}.md exist (T01).
- tests/fixtures/m030-p04/configs/config-with-live-true.yml exists (T01).
- tests/fixtures/m030-p04/shadow-corpus-ready.jsonl exists (T01) — `shadow-compare.sh` returns `flip_recommendation=ready` on it.
- tests/fixtures/m030-p04/round-trip-stage/{intensity-metadata.txt,payload.txt} exist (T01).
- references/model-routing.md exists with the `## Operator Overrides` section authored by P03/T03 (the `## Live Routing` section is T03 deliverable).

Plan-time prerequisite-existence verification: every path above is asserted at T02 close. The post-T02 shape of `dispatch-interface.sh` was inspected at planning time; the live-routing branch + flip-gate + `--model` passing are in place.

## Description

T03 is the high-risk core amendment, part 2 of 2. Six deliverables that ship as a single coherent change:

1. **Amend `scripts/dispatch/dispatch-interface.sh`** — wrap the adapter invocation in an escalation loop that runs ONLY when in live mode AND verdict is `ready` or `partially_ready` AND the current task's class is flippable. The loop iterates up to 3 times (initial + 2 escalations); on rc != 0, recompute the next tier (`fast → balanced → smart`), re-resolve the model ID, emit a NEW dispatch_usage record with incremented `escalation_count` and `escalation_reason=verifier_fail`, and re-invoke the adapter. After the cap is hit (3 attempts all failing), emit ONE `escalation_cap_hit` record and exit nonzero.

2. **Add `_di_tier_at_rank` helper** alongside `_di_tier_rank` (around line 175). Maps numeric rank → symbolic tier (inverse of `_di_tier_rank`).

3. **Add `escalation_count` and `escalation_reason` fields** to BOTH shadow-on printf format strings (happy-path and degradation). Initial dispatch emits `escalation_count=0` + `escalation_reason=""`; escalated dispatches emit the running counter + `verifier_fail`.

4. **Add `escalation_cap_hit` record emission** as a new top-level printf in dispatch-interface.sh (after the escalation loop concludes with cap hit). Single-line JSON record with `record_type=escalation_cap_hit`, `unitId`, `final_count=2`, `timestamp`.

5. **Co-authored verifiers**: `p04-sc4-escalation-sequence.sh`, `p04-sc5-escalation-cap.sh`, `p04-con5-no-fourth-record.sh`, `p04-con6-prior-records-bit-identical.sh`, `p04-escalation-fields-enum.sh`. Each follows the round-trip-stage shape with the `stub-fail-n.sh` adapter.

6. **Amend `references/model-routing.md`** to add a `## Live Routing` section documenting the flip-gate + escalation chain end-to-end (operator-facing docs co-locate with the gate-verifier ship date, mirroring P03/T03's `## Operator Overrides` section pattern).

T03 also re-runs T01/T02's gates against the amended emitter to confirm the post-T03 branches don't break upstream invariants.

### dispatch-interface.sh amendment shape (load-bearing detail)

The amendment is FOUR-block: (a) `_di_tier_at_rank` helper, (b) escalation loop wrapping the adapter invocation, (c) printf format-string extension with `escalation_count` + `escalation_reason`, (d) `escalation_cap_hit` record emission.

**Block A — `_di_tier_at_rank` helper.** Insert immediately after `_di_tier_rank` (current location around line 181-188):

```bash
# --- M030/P04/T03: inverse tier-rank for escalation progression ---
# Maps numeric rank to symbolic tier name (fast=0, balanced=1, smart=2).
# Returns "" for unknown rank. Used by the escalation loop to compute the
# next-higher tier on verifier failure. CON-3-clean (symbolic only).
_di_tier_at_rank() {
  case "$1" in
    0) echo fast ;;
    1) echo balanced ;;
    2) echo smart ;;
    *) echo "" ;;
  esac
}
```

**Block B — escalation loop wrapping the adapter invocation.** The current adapter invocation is at line ~586-595 (post-T02 form, with the conditional `--model` if/else). T03 wraps the entire invocation block in a loop that:

1. Tracks `escalation_count` (starts at 0).
2. Tracks the current symbolic tier (starts at `shadow_routed` from T02's resolution).
3. Invokes the adapter; captures `adapter_rc`.
4. On rc=0: emit happy-path dispatch_usage record (with current `escalation_count` + appropriate `escalation_reason`); break out of loop; continue to "emit adapter output unchanged" line.
5. On rc!=0:
   - If `escalation_count >= 2`: cap is hit. Emit the final dispatch_usage record (with `escalation_count=2`, `escalation_reason=verifier_fail`). Emit ONE `escalation_cap_hit` record. Emit dispatch-error.md on stderr (existing `emit_error "backend_crashed" ...` path). Exit 5.
   - Else: emit current-iteration dispatch_usage record (with current `escalation_count` value, `escalation_reason=verifier_fail`). Increment `escalation_count`. Recompute next tier via `_di_tier_at_rank`. Re-resolve `_DI_LIVE_MODEL_FLAG` for the new tier via the awk section-walker. Loop again.

The loop is gated: it ONLY runs when ALL of `M030_SHADOW_MODE=1` AND `CLAUDECODE=1` AND `_DI_LIVE_MODEL_FLAG` is non-empty (live mode active AND class flippable). Otherwise the original adapter invocation runs as a single-shot (no escalation).

Implementation skeleton (to insert at line ~585 BEFORE the existing adapter invocation block):

```bash
# M030/P04/T03: escalation loop. Active only in live mode.
escalation_count=0
escalation_reason=""
adapter_output=""
adapter_rc=0
escalation_active=0
if [ "${M030_SHADOW_MODE:-0}" = "1" ] && [ "${CLAUDECODE:-0}" = "1" ] && [ -n "${_DI_LIVE_MODEL_FLAG:-}" ]; then
  escalation_active=1
fi

if [ "$escalation_active" -eq 1 ]; then
  # Live-mode escalation loop.
  while : ; do
    # Invoke adapter with current --model flag.
    adapter_rc=0
    adapter_output="$(bash "$ADAPTER" \
      --task-plan "$TASK_PLAN" \
      --payload "$PAYLOAD" \
      --intensity-metadata "$INTENSITY_METADATA" \
      --model "$_DI_LIVE_MODEL_FLAG" 2>/dev/null)" || adapter_rc=$?

    if [ "$adapter_rc" -eq 0 ]; then
      # Success — emit final dispatch_usage record + break.
      _di_emit_dispatch_usage "" || true
      break
    fi

    # Failure — check cap.
    if [ "$escalation_count" -ge 2 ]; then
      # Cap hit. Emit final failed dispatch_usage record + escalation_cap_hit.
      escalation_reason="verifier_fail"
      _di_emit_dispatch_usage "adapter-failed" || true
      _di_emit_escalation_cap_hit
      emit_error "backend_crashed" "false" "developer" "${BACKEND}" \
        "Adapter failed after escalation cap of 2 escalations" \
        "Adapter: ${ADAPTER}; final tier: $shadow_routed" \
        "Inspect adapter stderr; consider lowering min_tier or disabling routing for this task."
      exit 5
    fi

    # Emit current-iteration failed dispatch_usage record (with current count).
    escalation_reason="verifier_fail"
    _di_emit_dispatch_usage "adapter-failed" || true

    # Escalate: bump count, recompute next tier.
    escalation_count=$((escalation_count + 1))
    _di_curr_rank=$(_di_tier_rank "$shadow_routed")
    _di_next_rank=$((_di_curr_rank + 1))
    shadow_routed="$(_di_tier_at_rank "$_di_next_rank")"
    if [ -z "$shadow_routed" ]; then
      # Should not happen — _di_curr_rank=2 already triggered cap above.
      # Defensive: if we get here, treat as cap hit.
      _di_emit_escalation_cap_hit
      emit_error "backend_crashed" "false" "developer" "${BACKEND}" \
        "Adapter failed; tier progression exhausted" \
        "Adapter: ${ADAPTER}" "Reduce escalation aggressiveness."
      exit 5
    fi
    # Re-resolve shadow_used + _DI_LIVE_MODEL_FLAG for the new tier.
    shadow_used="$(awk -v tier="$shadow_routed" '
      BEGIN { in_resolution = 0; in_tier = 0 }
      /^resolution:/                    { in_resolution = 1; next }
      /^cost_rates:/                    { exit }
      in_resolution && /^  [a-z_]+:$/   { in_tier = ($1 == (tier ":")) ? 1 : 0; next }
      in_resolution && in_tier && /^    claude-code:/ {
        val = $2; gsub(/[",]/, "", val); print val; exit
      }
    ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
    _DI_LIVE_MODEL_FLAG="$shadow_used"
  done
else
  # Non-live mode — single-shot dispatch (preserves T02 + pre-T02 behavior).
  if [ -n "${_DI_LIVE_MODEL_FLAG:-}" ]; then
    adapter_output="$(bash "$ADAPTER" \
      --task-plan "$TASK_PLAN" \
      --payload "$PAYLOAD" \
      --intensity-metadata "$INTENSITY_METADATA" \
      --model "$_DI_LIVE_MODEL_FLAG" 2>/dev/null)" || adapter_rc=$?
  else
    adapter_output="$(bash "$ADAPTER" \
      --task-plan "$TASK_PLAN" \
      --payload "$PAYLOAD" \
      --intensity-metadata "$INTENSITY_METADATA" 2>/dev/null)" || adapter_rc=$?
  fi
  # Existing post-adapter-invocation flow (conformance checks + happy-path
  # emit at line ~620) runs as before.
fi

# Single-shot non-live path falls through; live-mode happy-path falls through
# to the existing conformance-check + "emit adapter output unchanged" lines.
if [ "$adapter_rc" -ne 0 ] && [ "$escalation_active" -ne 1 ]; then
  # Pre-T03 adapter-failed flow (single-shot non-live).
  emit_error "backend_crashed" "true" "developer" "${BACKEND}" \
    "Adapter subprocess exited with code ${adapter_rc}" \
    "Adapter: ${ADAPTER}" \
    "Inspect adapter stderr or re-run with the adapter directly for diagnostics."
  _di_emit_dispatch_usage "adapter-failed" || true
  exit 5
fi
```

The above replaces the existing adapter invocation + adapter-rc check block (current lines ~586-598). The conformance-check block (line ~600-617) and the happy-path emit (line ~620) continue as before — they fire on the loop's break-on-success path.

**Important — `escalation_count` and `escalation_reason` propagation:** the printf format strings in `_di_emit_dispatch_usage` need to read these locals. Two options:

- (a) Pass them as function arguments: `_di_emit_dispatch_usage "$warning" "$escalation_count" "$escalation_reason"`. Requires changing the signature.
- (b) Make `escalation_count` and `escalation_reason` shell-scoped (declared at top level of the dispatcher block, not local to the loop). The function reads them via the same shell-variable mechanism it uses for `shadow_routed` etc.

Option (b) is cleaner and matches MEM004 carve-out (the function reads shell-scoped state already). Implementation: declare `escalation_count=0` and `escalation_reason=""` at the top of the dispatcher block (before the BACKEND resolution), so they're visible to `_di_emit_dispatch_usage` via the parent-shell scope.

**Block C — printf format-string extension.** Two shadow-ON printfs (happy-path line ~453, degradation line ~486) gain TWO new fields. Insert `,"escalation_count":%d,"escalation_reason":"%s"` after `,"override_source":"%s"`:

```text
,"override_source":"%s","escalation_count":%d,"escalation_reason":"%s"
```

Append `"$escalation_count" "$escalation_reason"` to the args list at the end. The shadow-OFF printfs (lines ~468 + ~501) are UNCHANGED — SC-11 byte-equality preserved.

**Block D — `_di_emit_escalation_cap_hit` helper + emission.** Add a new helper alongside `_di_emit_dispatch_usage`:

```bash
# --- M030/P04/T03: escalation_cap_hit emission helper ---
# Writes a single escalation_cap_hit JSONL record after the cap is hit. Same
# log_dir resolution as _di_emit_dispatch_usage; bail-safe; idempotent
# (caller guarantees one invocation per cap event).
_di_emit_escalation_cap_hit() {
  if [ "${M030_SHADOW_MODE:-0}" != "1" ] || [ "${CLAUDECODE:-0}" != "1" ]; then
    return 0
  fi
  local cap_log_dir cap_log_file cap_ts
  if [ -d "$ORCH_ROOT/phases" ]; then
    cap_log_dir="$ORCH_ROOT"
  elif [ -n "$MILESTONE_ID" ]; then
    cap_log_dir="$ORCH_ROOT/milestones/$MILESTONE_ID"
  else
    return 0
  fi
  cap_log_file="$cap_log_dir/execution-log.jsonl"
  cap_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  mkdir -p "$cap_log_dir" 2>/dev/null || return 0
  printf '{"record_type":"escalation_cap_hit","unitId":"%s","milestone":"%s","phase":"%s","task":"%s","final_count":2,"timestamp":"%s"}\n' \
    "$UNIT_ID" "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" "$cap_ts" \
    >> "$cap_log_file" 2>/dev/null || true
  return 0
}
```

Called from Block B's cap-hit branch.

### Verifier shapes (load-bearing detail)

**`tools/verify/p04-sc4-escalation-sequence.sh`** — fail-twice-then-pass:

```bash
# Stage tmp_root + counter file at value 2.
COUNTER_FILE="$TMP_ROOT/fail-counter.txt"
printf '2\n' > "$COUNTER_FILE"
INVOCATIONS_FILE="$TMP_ROOT/invocations.txt"
: > "$INVOCATIONS_FILE"

export STUB_FAIL_COUNTER_FILE="$COUNTER_FILE"
export STUB_FAIL_COUNTER_INVOCATIONS_FILE="$INVOCATIONS_FILE"
export M030_SHADOW_COMPARE_CORPUS="$REPO_ROOT/tests/fixtures/m030-p04/shadow-corpus-ready.jsonl"
# Standard live-mode env: ORCHESTRATOR_ROOT, M030_SHADOW_MODE=1, CLAUDECODE=1.
# Plan: plan-fail-twice-then-pass.md (mechanical-classified).
# Backend: stub-fail-n (counter=2 → fail twice then pass).

bash "$DISPATCH" --task-plan "$PLAN_FAIL_TWICE" --payload "$PAYLOAD" \
  --intensity-metadata "$INTENSITY_META" --backend stub-fail-n \
  > /dev/null 2>&1
DISPATCH_RC=$?

# Assertion 1: dispatch-interface exits 0 (third attempt succeeded).
[ "$DISPATCH_RC" -eq 0 ] && pass=$((pass+1)) || fail=$((fail+1))

# Assertion 2: exactly three dispatch_usage records.
grep -F '"record_type":"dispatch_usage"' "$LOG_FILE" > "$LINE_TMP"
wc -l < "$LINE_TMP" > "$LC_TMP"
LC="$(tr -d '[:space:]' < "$LC_TMP")"
[ "$LC" -eq 3 ] && pass=$((pass+1)) || fail=$((fail+1))

# Assertion 3: model_used sequence = fast → balanced → smart (resolved at runtime).
EXPECTED_FAST="$(awk ... fast ...)"
EXPECTED_BALANCED="$(awk ... balanced ...)"
EXPECTED_SMART="$(awk ... smart ...)"
LINE1="$(sed -n '1p' "$LINE_TMP")"
LINE2="$(sed -n '2p' "$LINE_TMP")"
LINE3="$(sed -n '3p' "$LINE_TMP")"
# Per-line model_used assertions via grep -F '"model_used":"$EXPECTED_X"'.

# Assertion 4: third record carries escalation_count=2 + escalation_reason=verifier_fail.
# (Wait — third record is the success after 2 failures. escalation_count on the
#  third record is 2 because two escalations preceded it. escalation_reason is
#  "" on the success record? Or is "verifier_fail" on the second-to-last record?)
```

**Subtle semantic decision**: the escalation_count on the SUCCESS record (third record after fail-twice-then-pass) — is it 0, 2, or something else?

Per the demo: "the third carries `escalation_count=2`". So on the success record, `escalation_count=2` (reflecting that two escalations preceded this attempt). And `escalation_reason` on the success record is empty (the success itself was not a verifier_fail).

This means the implementation must:
- Increment `escalation_count` AFTER each failed attempt's record is emitted, not before. The successful attempt's record reads the post-incremented value (which equals the number of preceding failures).
- Reset `escalation_reason` to empty before the successful emit (since rc=0 on the third attempt).

Concretely: each loop iteration emits its dispatch_usage record AFTER computing rc. The values are:

| Iteration | rc | escalation_count emitted | escalation_reason emitted |
|-----------|----|----|----|
| 1 (initial) | 1 (fail) | 0 | verifier_fail |
| 2 (escalated to balanced) | 1 (fail) | 1 | verifier_fail |
| 3 (escalated to smart) | 0 (success) | 2 | "" |

The increment of `escalation_count` happens BETWEEN iterations (after emit, before next attempt). Block B's logic:

```
loop_start:
  invoke adapter; capture rc
  if rc == 0:
    emit record with current escalation_count + escalation_reason="" (success)
    break
  else if escalation_count >= 2:
    emit record with current escalation_count + escalation_reason="verifier_fail" (final failure)
    emit escalation_cap_hit record
    exit 5
  else:
    emit record with current escalation_count + escalation_reason="verifier_fail"
    escalation_count++
    recompute next tier
    goto loop_start
```

This produces the expected sequence:
- (initial, count=0, reason=verifier_fail, fail)
- (escalated, count=1, reason=verifier_fail, fail)
- (escalated, count=2, reason="", success)

For the SC-5 case (fail-three-times):
- (initial, count=0, reason=verifier_fail, fail)
- (escalated, count=1, reason=verifier_fail, fail)
- (escalated, count=2, reason=verifier_fail, fail) ← cap hit
- escalation_cap_hit record emitted; exit 5

Three dispatch_usage records + one escalation_cap_hit record. NO fourth dispatch_usage.

For the CON-5 case (fail-four-times) — same as fail-three-times. The counter has 4 failures pending but the cap stops at 3 invocations. The stub adapter is invoked exactly 3 times; the 4th invocation never happens.

**`tools/verify/p04-sc5-escalation-cap.sh`** — fail-three-times. Same staging as SC-4 but counter starts at 3. Assertions:

1. dispatch-interface exits nonzero (5).
2. Exactly three dispatch_usage records.
3. Exactly one escalation_cap_hit record.
4. The escalation_cap_hit record's `final_count=2` and `unitId` matches the dispatch_usage records' unitId.
5. Each of the three dispatch_usage records has `escalation_reason=verifier_fail`.
6. The third dispatch_usage record has `escalation_count=2`.

**`tools/verify/p04-con5-no-fourth-record.sh`** — fail-four-times. Counter starts at 4. Same assertions as SC-5 plus:

7. The `STUB_FAIL_COUNTER_INVOCATIONS_FILE` contains exactly 3 lines (proving the stub adapter was invoked 3 times, not 4).

**`tools/verify/p04-con6-prior-records-bit-identical.sh`** — append-only check. The challenge: capturing first-two-lines hashes mid-escalation requires inspecting the log file BEFORE the third attempt. Two approaches:

- (a) Use `STUB_INVOCATION_SENTINEL_DIR` from T01's stub-fail-n. Each adapter invocation drops a sentinel file. The verifier waits for the second sentinel, captures `head -n 2 "$LOG_FILE"` hash, lets the third invocation proceed, captures `head -n 2` again at the end, asserts equal. But the dispatch is synchronous — the verifier cannot inject a wait between adapter invocations.
- (b) Run the escalation in two stages: first dispatch the fail-twice-then-pass plan, capture the full log AFTER it completes (3 records); compute hash of `head -n 2`; then cat the same log to a different file and compute hash again; assert equal. This is a degenerate test — it just asserts that the same `head -n 2` is computed twice.

Better approach (c): use `tee` to capture the log file's growth log + a checksum side-channel. Run the dispatch. After completion, compute hashes of `sed -n '1p' "$LOG_FILE"` and `sed -n '2p' "$LOG_FILE"`. Then run the dispatch AGAIN against a fresh tmp_root (same fixture; counter=2 again). After this second completion, the new log's first two lines are the new attempt's records — DIFFERENT from the first run's. The assertion is: WITHIN a single dispatch, the prior records remain stable AS the escalation unfolds. The simplest way to assert this is to compare the bytes of the first two records BEFORE the third attempt's record is appended.

The CLEANEST shape (chosen): **decouple the assertion from the live escalation timing**. The CON-6 verifier asserts:

1. Run the dispatch against fail-twice-then-pass (counter=2). After completion, `head -n 2 "$LOG_FILE"` produces two record lines (the first two attempts).
2. Compute SHA-256 of `head -n 2 "$LOG_FILE"`.
3. Append a synthetic line to the log file AFTER the dispatch completes: `printf 'synthetic\n' >> "$LOG_FILE"`. This simulates a downstream append without re-running dispatch.
4. Compute SHA-256 of `head -n 2 "$LOG_FILE"` AGAIN. Assert equal to step 2's hash.
5. This proves: the escalation's append-only contract holds — appending more records does NOT mutate prior records' bytes.

The above is a degenerate test (essentially asserting `head -n 2` is deterministic), but it's the mechanically-verifiable proxy for CON-6 in the absence of a mid-dispatch inspection seam. The richer test would require a custom adapter that pauses on the third invocation; out of scope for P04.

A STRONGER variant: assert that the inode of the log file does not change between the start and end of the dispatch. Use `stat -f %i "$LOG_FILE"` (macOS) or `stat -c %i` (Linux) to capture the inode before dispatch starts and after dispatch ends. Equal inodes mean no `mv`/`cp`/swap occurred. This is the same shape as `p02-append-only.sh` from P02/T03.

Implementation chosen: **inode-preservation + first-two-lines hash equality after a synthetic append**. Combines both checks for stronger CON-6 assurance.

**`tools/verify/p04-escalation-fields-enum.sh`** — three scenarios:

| Scenario | Counter | Plan | Expected records |
|----------|---------|------|------------------|
| no-failure | 0 | plan-mechanical-no-override | 1 record, count=0, reason="" |
| fail-twice-then-pass | 2 | plan-fail-twice-then-pass | 3 records, sequence (0/vf, 1/vf, 2/"") |
| fail-three-times | 3 | plan-fail-three-times | 3 records, sequence (0/vf, 1/vf, 2/vf) + escalation_cap_hit |

Assert per-record `escalation_count` + `escalation_reason` values match the expected sequences.

### references/model-routing.md ## Live Routing section

Append after the existing `## Operator Overrides` section. Documents:

1. **The flip-gate enforcement chain** — `model_routing.live: true` triggers programmatic shadow-compare invocation; verdicts gate the adapter call.
2. **Verdict-to-action table** —
   - `ready` → all classes flip live; `--model <id>` passed to backend.
   - `partially_ready` → only flippable classes flip; `withheld_classes=<list>` recorded; `partial_flip_active=true`.
   - `evidence_insufficient` / `block` → adapter NOT invoked; `override_source=shadow_gate_blocked`; dispatch-interface exits nonzero.
3. **Escalation chain** — `fast → balanced → smart` on verifier failure. Cap at 2 escalations (CON-5). Three dispatch_usage records max + one `escalation_cap_hit` on cap.
4. **Override precedence (extended from P03)** — kill switch supersedes live; live supersedes routed; routed defers to plan_frontmatter / milestone_floor / none.
5. **Operator workflow** — flip from shadow to live: (a) ensure ≥50 records per class with stable confidence in shadow corpus; (b) run `bash scripts/diagnostics/shadow-compare.sh`; verify verdict is `ready` or acceptable `partially_ready`; (c) set `model_routing.live: true` in `.orchestrator/config.yml`; (d) the next dispatch validates via programmatic shadow-compare and either proceeds or refuses.

## Steps

1. **Confirm T01 + T02 deliverables are on disk and green.** Run all seven existing P04 verifiers:

   ```bash
   bash tools/verify/p04-additive-schema.sh
   bash tools/verify/p04-override-source-enum-extended.sh
   bash tools/verify/p04-sc2a-shadow-gate-block.sh
   bash tools/verify/p04-sc3-live-mechanical.sh
   bash tools/verify/p04-partial-flip-routing.sh
   bash tools/verify/p04-con3-live-closure.sh
   bash tools/verify/p04-con4-live-killswitch.sh
   ```

   Expected: all seven exit 0. If any fail, T01 or T02 must be re-opened.

2. **Snapshot the pre-amendment `dispatch-interface.sh` for the CON-3 diff baseline.** No explicit snapshot needed — `git show HEAD:scripts/dispatch/dispatch-interface.sh` is the baseline.

3. **Add the `_di_tier_at_rank` helper** (Block A) immediately after `_di_tier_rank` (around line 188).

4. **Add the `_di_emit_escalation_cap_hit` helper** (Block D) alongside `_di_emit_dispatch_usage` (around line 515). Place AFTER the existing function so the existing function is unaffected.

5. **Declare top-level `escalation_count` and `escalation_reason` shell-scoped variables** before the BACKEND resolution block (around line 545). Initialize to `0` and `""` respectively. These are read by `_di_emit_dispatch_usage`'s printf branches.

6. **Extend the printf format strings** in `_di_emit_dispatch_usage` (Block C). The two shadow-on printfs (lines ~453 + ~486) gain `,"escalation_count":%d,"escalation_reason":"%s"` after `,"override_source":"%s"`. Append `"$escalation_count" "$escalation_reason"` to the args list.

   The two shadow-OFF printfs (lines ~468 + ~501) are UNCHANGED — SC-11 byte-equality preserved.

7. **Wrap the adapter invocation in the escalation loop** (Block B). The current adapter invocation block (post-T02) is at line ~580-617. T03 amends it to:

   - Detect live-mode escalation eligibility (`M030_SHADOW_MODE=1` AND `CLAUDECODE=1` AND `_DI_LIVE_MODEL_FLAG` non-empty).
   - When eligible: enter the loop. On rc=0, emit happy-path record + break. On rc!=0 with count<2, emit record with `verifier_fail`, increment, recompute next tier, re-resolve `_DI_LIVE_MODEL_FLAG`, loop. On rc!=0 with count>=2, emit final record with `verifier_fail`, emit `escalation_cap_hit`, emit dispatch-error, exit 5.
   - When not eligible: fall through to the existing single-shot invocation (preserves T02 + pre-T02 behavior).

   Critical: the conformance-check block (line ~600-617) and the happy-path emit (line ~620) must continue to fire correctly on the loop's break-on-success path. Concretely, the loop's success path emits the dispatch_usage record INSIDE the loop body, then breaks; the existing happy-path emit at line ~620 must NOT fire a second time (would produce a duplicate record). The simplest fix: gate the existing happy-path emit at line ~620 on `escalation_active=0` (skip when the loop already emitted).

8. **Author `tools/verify/p04-sc4-escalation-sequence.sh`** per the shape in the Description. Stage tmp_root + counter file (value=2) + invocations file. Standard live-mode env vars + corpus injection. Six assertions:
   - dispatch-interface exits 0.
   - Exactly 3 dispatch_usage records.
   - Record 1 `model_used`=resolution.fast.claude-code (extracted at runtime).
   - Record 2 `model_used`=resolution.balanced.claude-code.
   - Record 3 `model_used`=resolution.smart.claude-code.
   - Record 3 `escalation_count=2`, `escalation_reason=""` (success).

9. **Author `tools/verify/p04-sc5-escalation-cap.sh`** per the shape in the Description. Counter starts at 3. Assertions:
   - dispatch-interface exits nonzero.
   - Exactly 3 dispatch_usage records.
   - Exactly 1 escalation_cap_hit record.
   - escalation_cap_hit record `final_count=2`, `unitId` matches dispatch_usage unitId.
   - Each dispatch_usage record has `escalation_reason=verifier_fail`.
   - Record 3 has `escalation_count=2`.

10. **Author `tools/verify/p04-con5-no-fourth-record.sh`** per the shape in the Description. Counter starts at 4. Same assertions as SC-5 plus:
    - `STUB_FAIL_COUNTER_INVOCATIONS_FILE` contains exactly 3 lines.

11. **Author `tools/verify/p04-con6-prior-records-bit-identical.sh`** per the shape in the Description (inode-preservation + first-two-lines hash equality after synthetic append):

    - Stage tmp_root + counter file (value=2). Capture inode of `$LOG_FILE`'s parent dir's expected log path BEFORE dispatch. (Note: log file doesn't exist before dispatch; capture inode of the parent dir as a stand-in, OR run a no-op append first to create the file with a known inode.)
    - Approach: `touch "$LOG_FILE"; INODE_BEFORE=$(stat ... "$LOG_FILE")`.
    - Run the dispatch (3 records emitted).
    - Capture `INODE_AFTER=$(stat ... "$LOG_FILE")`.
    - Capture `HASH_PRE=$(head -n 2 "$LOG_FILE" | shasum -a 256 | cut -d' ' -f1)`.
    - Append a synthetic line: `printf 'synthetic\n' >> "$LOG_FILE"`.
    - Capture `HASH_POST=$(head -n 2 "$LOG_FILE" | shasum -a 256 | cut -d' ' -f1)`.
    - Assert `INODE_BEFORE == INODE_AFTER` (no `mv`/swap).
    - Assert `HASH_PRE == HASH_POST` (first 2 lines unchanged after append).
    - Assertions count: 2 (inode + hash).

    Note: the `head ... | shasum ... | cut ...` chain is a 3-link pipe. Per AP-009, this is at the boundary of "compound chain >2". Use tmp-file intermediates to keep AD-19-clean:

    ```bash
    head -n 2 "$LOG_FILE" > /tmp/p04-con6-head.txt
    shasum -a 256 /tmp/p04-con6-head.txt > /tmp/p04-con6-shasum.txt
    HASH_PRE="$(cut -d' ' -f1 < /tmp/p04-con6-shasum.txt)"
    rm -f /tmp/p04-con6-head.txt /tmp/p04-con6-shasum.txt
    ```

12. **Author `tools/verify/p04-escalation-fields-enum.sh`** per the shape in the Description. Three scenarios (no-failure, fail-twice-then-pass, fail-three-times). Assert per-record `escalation_count` + `escalation_reason` values match the expected sequences. ~7 assertions total (1 + 3 + 3).

13. **Amend `references/model-routing.md`** to add the `## Live Routing` section per the Description. Insert AFTER the existing `## Operator Overrides` section and BEFORE the `## See Also` section. Update the `## See Also` bullets to include the new `## Live Routing` section.

14. **Re-run all T01 + T02 + T03 verifiers as a self-check:**

    ```bash
    bash tools/verify/p04-additive-schema.sh
    bash tools/verify/p04-override-source-enum-extended.sh
    bash tools/verify/p04-sc2a-shadow-gate-block.sh
    bash tools/verify/p04-sc3-live-mechanical.sh
    bash tools/verify/p04-partial-flip-routing.sh
    bash tools/verify/p04-con3-live-closure.sh
    bash tools/verify/p04-con4-live-killswitch.sh
    bash tools/verify/p04-sc4-escalation-sequence.sh
    bash tools/verify/p04-sc5-escalation-cap.sh
    bash tools/verify/p04-con5-no-fourth-record.sh
    bash tools/verify/p04-con6-prior-records-bit-identical.sh
    bash tools/verify/p04-escalation-fields-enum.sh
    ```

    Expected: all twelve exit 0.

    If `p04-additive-schema.sh` fails: the shadow-off printfs were accidentally modified — revert Step 6 changes to lines ~468 + ~501 (those branches must remain byte-identical to pre-T03).

    If `p04-sc3-live-mechanical.sh` fails post-T03: the happy-path emit at line ~620 may be firing duplicate records. Re-check Step 7's gate on `escalation_active`.

    If `p04-sc4-escalation-sequence.sh` fails on the model_used sequence: the `_di_tier_at_rank` increment logic may be off. Trace through: count=0 → fast (initial); after first fail count=1, tier=balanced; after second fail count=2, tier=smart; success at count=2. The third record's `model_used` is the smart-tier resolution.

    If `p04-con6-prior-records-bit-identical.sh` fails on inode comparison: `mkdir -p` may be creating a new inode each time. Use `:>` instead of `touch` to force file creation.

15. **Stage and commit.** Stage `scripts/dispatch/dispatch-interface.sh`, `references/model-routing.md`, all five new T03 verifier scripts. Write commit message file via Write to `/tmp/p04-t03-commit-msg.txt`; commit with `git commit -F /tmp/p04-t03-commit-msg.txt`. Recommended subject: `M030/P04/T03: dispatch-interface escalation loop + CON-5 cap + escalation_cap_hit + CON-6 verifier`.

## Must-Haves

This task satisfies the phase truths:

- "SC-4 holds: with model_routing.live: true AND a ready-verdict shadow corpus AND the stub-fail-n.sh adapter (counter starts at 2 — fail twice then pass) ..." — gated by `tools/verify/p04-sc4-escalation-sequence.sh`.
- "SC-5 holds: with model_routing.live: true AND a ready-verdict shadow corpus AND the stub-fail-n.sh adapter (counter starts at 3 — fail every attempt) ..." — gated by `tools/verify/p04-sc5-escalation-cap.sh`.
- "CON-5 hard-cap (no-fourth-record) gate ..." — gated by `tools/verify/p04-con5-no-fourth-record.sh`.
- "CON-6 prior-records-bit-identical gate ..." — gated by `tools/verify/p04-con6-prior-records-bit-identical.sh`.
- "New JSONL field escalation_count (integer, 0..2) appears on every shadow-on dispatch_usage record post-T03 ..." — gated by `tools/verify/p04-escalation-fields-enum.sh`.

## Verification

```bash
bash tools/verify/p04-additive-schema.sh
bash tools/verify/p04-override-source-enum-extended.sh
bash tools/verify/p04-sc2a-shadow-gate-block.sh
bash tools/verify/p04-sc3-live-mechanical.sh
bash tools/verify/p04-partial-flip-routing.sh
bash tools/verify/p04-con3-live-closure.sh
bash tools/verify/p04-con4-live-killswitch.sh
bash tools/verify/p04-sc4-escalation-sequence.sh
bash tools/verify/p04-sc5-escalation-cap.sh
bash tools/verify/p04-con5-no-fourth-record.sh
bash tools/verify/p04-con6-prior-records-bit-identical.sh
bash tools/verify/p04-escalation-fields-enum.sh
```

Each verifier uses single-script-file shape per AD-19. All twelve must exit 0 before T03 closes.

## Inputs

### From Previous Tasks

- All T01 fixture plans + configs + corpora + stub adapters (T01) — Key API: stub-fail-n.sh consumes `STUB_FAIL_COUNTER_FILE` env var (counter file with single integer; read-decrement on each invocation; rc=1 if remaining>0 else rc=0). Side-channel: `STUB_FAIL_COUNTER_INVOCATIONS_FILE` env var receives one append per invocation; `STUB_INVOCATION_SENTINEL_DIR` env var receives sentinel files.
- scripts/dispatch/dispatch-interface.sh (post-T02) — Key API: live-routing branch reads `model_routing.live`; on `ready` verdict + flippable class, sets `_DI_LIVE_MODEL_FLAG=<resolution.<tier>.claude-code>`; adapter invocation conditionally passes `--model "$_DI_LIVE_MODEL_FLAG"`; `_DI_LIVE_GATE_BLOCKED=1` short-circuits adapter invocation.
- tools/verify/p04-additive-schema.sh, p04-override-source-enum-extended.sh, p04-sc2a-shadow-gate-block.sh, p04-sc3-live-mechanical.sh, p04-partial-flip-routing.sh, p04-con3-live-closure.sh, p04-con4-live-killswitch.sh (T01/T02) — Key API: each `bash <path>` exits 0; `SUMMARY:` line emitted with pass-count.

### From Disk (Pre-existing)

- scripts/dispatch/dispatch-interface.sh — pre-T03 form (post-T02). T03 amends `_di_emit_dispatch_usage` printfs + dispatcher-level adapter invocation block.
  - Key API: post-T02 the function emits 6 P02/P03 fields under shadow-on (`classifier_confidence`, `model_routed`, `model_used`, `partial_flip_active`, `withheld_classes`, `override_source`). Post-T03 adds 2 more fields: `escalation_count` (integer 0..2) + `escalation_reason` (string).
- scripts/diagnostics/shadow-compare.sh — P02/T03 deliverable. Used by T02's live-routing branch.
- scripts/dispatch/classify-task.sh — P01/T02 classifier. Used indirectly via shadow-mode dispatch.
- templates/model-routing.yml — P01/T03 SSOT. T03's escalation loop reads `resolution.<tier>.claude-code` to recompute `_DI_LIVE_MODEL_FLAG` after each escalation.
- references/model-routing.md — post-P03/T03 form (with `## Operator Overrides` section). T03 amends to add `## Live Routing` section.

## Constraints

- **AD-19 single-script-file shape**: all verifier `Check:` invocations are `bash <single-path>.sh`. The amendment to `dispatch-interface.sh` is internal code; AD-19 governs the verifier-invocation shape.
- **MEM004 emitter-internal carve-out**: `_di_emit_dispatch_usage` and the new `_di_emit_escalation_cap_hit` helper inherit the dispatch-internal-emitter carve-out — pipes / awk / `$()` permitted in their bodies. The escalation loop body in the dispatcher is also dispatch-internal and inherits the same carve-out (MEM004 applies to dispatch-internal logic broadly).
- **AP-009 compound-chain-gt2 (verifier shape)**: the five T03 verifiers MUST avoid `result=$(cmd | grep | head)` patterns. Use tmp-file intermediates throughout. The CON-6 verifier's `head ... | shasum ... | cut ...` chain MUST be unrolled into tmp-file stages.
- **CON-2 / FR-19 / SC-11 (additive-only schema)**: the shadow-OFF `printf` format strings MUST be byte-identical to the post-T02 form (which equals the post-P03 form). T03's amendment touches ONLY the shadow-on printfs (lines ~453 + ~486) and the new `_di_emit_escalation_cap_hit` helper — NEVER the shadow-off printfs. Verified by `tools/verify/p04-additive-schema.sh`.
- **CON-3 (symbolic-tier closure)**: the escalation loop's tier progression uses `_di_tier_at_rank` (symbolic only) and re-resolves `_DI_LIVE_MODEL_FLAG` via the awk section-walker against `templates/model-routing.yml resolution.<tier>.claude-code` — no hardcoded provider model IDs introduced. Verified by `tools/verify/p04-con3-live-closure.sh` (still passing post-T03).
- **CON-4 / D-A5 (kill switch supersedes live AND escalation)**: when `model_routing_enabled: false`, the kill-switch path short-circuits BEFORE the live-mode block runs. The escalation loop is gated on `_DI_LIVE_MODEL_FLAG` non-empty — under kill-switch this is unset, so the loop never engages. Verified by `tools/verify/p04-con4-live-killswitch.sh` (still passing post-T03).
- **CON-5 (escalation hard-cap)**: at `escalation_count >= 2` AND rc != 0, the loop MUST emit the final dispatch_usage record + the escalation_cap_hit record + exit 5 WITHOUT a fourth adapter invocation. Verified by `tools/verify/p04-sc5-escalation-cap.sh` and `tools/verify/p04-con5-no-fourth-record.sh`.
- **CON-6 (append-only shadow corpus)**: each loop iteration uses `>> "$log_file"` only via `_di_emit_dispatch_usage`. The `_di_emit_escalation_cap_hit` helper also uses `>>` only. No `mv`, no `cp`, no truncating `>`, no temp-file-and-swap. Verified by `tools/verify/p04-con6-prior-records-bit-identical.sh` (inode preservation + first-two-lines hash equality).
- **D-A2 (programmatic flip-gate enforcement)**: T02 already enforces this; T03 does not weaken the check. The escalation loop runs only AFTER the flip-gate has been cleared (verdict is ready or partially_ready with flippable class).
- **CC-only launch posture**: escalation path requires `CLAUDECODE=1` AND `M030_SHADOW_MODE=1` AND `_DI_LIVE_MODEL_FLAG` non-empty. Codex CLI / Cursor cannot reach the escalation loop (live mode never engages on those runtimes per the existing T02 gate).
- **Bash 3.2 compatibility**: no `declare -A`, no `mapfile`, no `readarray`. The escalation loop uses `while : ; do ... done` (POSIX-safe).
- **Plan-Time Discipline rule 5 (real-DB verification)**: T03 introduces no SQL — N/A.

## Expected Output

- scripts/dispatch/dispatch-interface.sh — amended with `_di_tier_at_rank` helper + `_di_emit_escalation_cap_hit` helper + escalation loop wrapping the adapter invocation + extended shadow-on printf format strings (`escalation_count` + `escalation_reason` fields). Shadow-off printfs unchanged.
- references/model-routing.md — amended with new `## Live Routing` section between `## Operator Overrides` and `## See Also`; `## See Also` bullets updated.
- tools/verify/p04-sc4-escalation-sequence.sh — green: 6 assertions (3 model_used per record + dispatch exit 0 + record count + final escalation_count).
- tools/verify/p04-sc5-escalation-cap.sh — green: 6 assertions (dispatch exit nonzero + record count + cap_hit count + cap_hit fields + per-record reason + final count).
- tools/verify/p04-con5-no-fourth-record.sh — green: 7 assertions (SC-5's six + invocation count == 3).
- tools/verify/p04-con6-prior-records-bit-identical.sh — green: 2 assertions (inode preserved + head-2 hash unchanged after synthetic append).
- tools/verify/p04-escalation-fields-enum.sh — green: 7 assertions (1 + 3 + 3 across three scenarios).
- bash tools/verify/p04-sc4-escalation-sequence.sh exits 0 with `SUMMARY: p04-sc4-escalation-sequence.sh pass=6 fail=0`.
- bash tools/verify/p04-sc5-escalation-cap.sh exits 0 with `SUMMARY: p04-sc5-escalation-cap.sh pass=6 fail=0`.
- bash tools/verify/p04-con5-no-fourth-record.sh exits 0 with `SUMMARY: p04-con5-no-fourth-record.sh pass=7 fail=0`.
- bash tools/verify/p04-con6-prior-records-bit-identical.sh exits 0 with `SUMMARY: p04-con6-prior-records-bit-identical.sh pass=2 fail=0`.
- bash tools/verify/p04-escalation-fields-enum.sh exits 0 with `SUMMARY: p04-escalation-fields-enum.sh pass=7 fail=0`.

## Notes

Expected verifier output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p04-sc4-escalation-sequence.sh` -> 6 assertions pass; `SUMMARY: p04-sc4-escalation-sequence.sh pass=6 fail=0`, exit 0.
- `bash tools/verify/p04-sc5-escalation-cap.sh` -> 6 assertions pass; `SUMMARY: p04-sc5-escalation-cap.sh pass=6 fail=0`, exit 0.
- `bash tools/verify/p04-con5-no-fourth-record.sh` -> 7 assertions pass; `SUMMARY: p04-con5-no-fourth-record.sh pass=7 fail=0`, exit 0.
- `bash tools/verify/p04-con6-prior-records-bit-identical.sh` -> 2 assertions pass; `SUMMARY: p04-con6-prior-records-bit-identical.sh pass=2 fail=0`, exit 0.
- `bash tools/verify/p04-escalation-fields-enum.sh` -> 7 assertions pass; `SUMMARY: p04-escalation-fields-enum.sh pass=7 fail=0`, exit 0.

The escalation-loop emit-vs-increment ordering is subtle. Iteration 1 (initial dispatch): adapter invoked at tier=fast (count=0). On success, emit (count=0, reason=""). On failure, emit (count=0, reason=verifier_fail), THEN increment count to 1, recompute tier=balanced. Iteration 2: adapter invoked at tier=balanced (count=1). On success, emit (count=1, reason=""). On failure, emit (count=1, reason=verifier_fail), THEN increment count to 2, recompute tier=smart. Iteration 3: adapter invoked at tier=smart (count=2). On success, emit (count=2, reason=""). On failure: this is cap-hit. Emit (count=2, reason=verifier_fail), then emit escalation_cap_hit, then exit 5.

The third dispatch_usage record in the SC-4 fail-twice-then-pass scenario has `escalation_count=2` and `escalation_reason=""` — the reason is empty on the success record because the third attempt itself was not a verifier failure. The demo language "the third carries `escalation_count=2`" is precise; it does NOT say `escalation_reason=verifier_fail` on the third record.

For the SC-5 fail-three-times scenario, the third record has `escalation_count=2` and `escalation_reason=verifier_fail` (the third attempt itself failed and triggered the cap). The escalation_cap_hit record's `final_count=2` matches the third record's `escalation_count=2`.

The CON-6 prior-records-bit-identical test is an inode-preservation + head-2-hash check rather than a true mid-escalation inspection because dispatch-interface.sh is synchronous — there's no seam between adapter invocations where the verifier can inject a hash capture without modifying dispatch-interface.sh itself. The synthetic-append + head-2-hash-equality check is the mechanically-verifiable proxy for "appending records does not mutate prior records' bytes" (which is what CON-6 actually asserts at the file-system level). The inode-preservation check additionally rules out the `cp old new; mv new old` swap shape.

If the executor wants a STRONGER CON-6 test, the alternative is to use `STUB_INVOCATION_SENTINEL_DIR`: the stub-fail-n.sh drops a sentinel file on each invocation. The verifier could SPIN on the sentinel file's appearance (busy-wait with sleep 0.05) and capture the log file's first-two-lines hash between the second and third sentinel drops. This requires the verifier to run dispatch-interface.sh in the background and inspect the log file mid-execution — feasible but adds complexity. The simpler synthetic-append test is preferred.

The `## Live Routing` section in `references/model-routing.md` SHOULD include a verbatim reproduction of the verdict-to-action table (per the Description), the escalation chain (`fast → balanced → smart`, cap=2), and the operator workflow for flipping from shadow to live. This is operator-facing documentation; the audience is project maintainers reading the doc to understand the M030 routing layer's behavior.

If `p04-sc4-escalation-sequence.sh` fails on the third record's `model_used`, common causes are: (a) `_di_tier_at_rank` not defined (Step 3 missed), (b) the `_DI_LIVE_MODEL_FLAG` re-resolution awk block has a typo, (c) the loop's increment happens BEFORE the emit instead of AFTER. Trace: after iteration 1's failed emit (count=0, reason=verifier_fail), count must be incremented to 1 BEFORE iteration 2's adapter invocation at tier=balanced.

The amended `dispatch-interface.sh` after T03 will be approximately 100 lines longer than the post-T02 form (escalation loop + 2 helpers + 2 printf extensions). Bulk of the additions are the loop body and the helper functions; the printf extensions are 1-line each. The shadow-off printfs remain UNTOUCHED — the `p04-additive-schema.sh` gate continues to enforce SC-11 byte-equality.

## State Context

- **Current State**: executing
- **Milestone**: M030
- **Phase**: P04
- **Task**: T03-escalation-loop
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **AD-19 single-script-file shape**: all verifier `Check:` invocations are `bash <single-path>.sh`. The amendment to `dispatch-interface.sh` is internal code; AD-19 governs the verifier-invocation shape.
- **MEM004 emitter-internal carve-out**: `_di_emit_dispatch_usage` and the new `_di_emit_escalation_cap_hit` helper inherit the dispatch-internal-emitter carve-out — pipes / awk / `$()` permitted in their bodies. The escalation loop body in the dispatcher is also dispatch-internal and inherits the same carve-out (MEM004 applies to dispatch-internal logic broadly).
- **AP-009 compound-chain-gt2 (verifier shape)**: the five T03 verifiers MUST avoid `result=$(cmd | grep | head)` patterns. Use tmp-file intermediates throughout. The CON-6 verifier's `head ... | shasum ... | cut ...` chain MUST be unrolled into tmp-file stages.
- **CON-2 / FR-19 / SC-11 (additive-only schema)**: the shadow-OFF `printf` format strings MUST be byte-identical to the post-T02 form (which equals the post-P03 form). T03's amendment touches ONLY the shadow-on printfs (lines ~453 + ~486) and the new `_di_emit_escalation_cap_hit` helper — NEVER the shadow-off printfs. Verified by `tools/verify/p04-additive-schema.sh`.
- **CON-3 (symbolic-tier closure)**: the escalation loop's tier progression uses `_di_tier_at_rank` (symbolic only) and re-resolves `_DI_LIVE_MODEL_FLAG` via the awk section-walker against `templates/model-routing.yml resolution.<tier>.claude-code` — no hardcoded provider model IDs introduced. Verified by `tools/verify/p04-con3-live-closure.sh` (still passing post-T03).
- **CON-4 / D-A5 (kill switch supersedes live AND escalation)**: when `model_routing_enabled: false`, the kill-switch path short-circuits BEFORE the live-mode block runs. The escalation loop is gated on `_DI_LIVE_MODEL_FLAG` non-empty — under kill-switch this is unset, so the loop never engages. Verified by `tools/verify/p04-con4-live-killswitch.sh` (still passing post-T03).
- **CON-5 (escalation hard-cap)**: at `escalation_count >= 2` AND rc != 0, the loop MUST emit the final dispatch_usage record + the escalation_cap_hit record + exit 5 WITHOUT a fourth adapter invocation. Verified by `tools/verify/p04-sc5-escalation-cap.sh` and `tools/verify/p04-con5-no-fourth-record.sh`.
- **CON-6 (append-only shadow corpus)**: each loop iteration uses `>> "$log_file"` only via `_di_emit_dispatch_usage`. The `_di_emit_escalation_cap_hit` helper also uses `>>` only. No `mv`, no `cp`, no truncating `>`, no temp-file-and-swap. Verified by `tools/verify/p04-con6-prior-records-bit-identical.sh` (inode preservation + first-two-lines hash equality).
- **D-A2 (programmatic flip-gate enforcement)**: T02 already enforces this; T03 does not weaken the check. The escalation loop runs only AFTER the flip-gate has been cleared (verdict is ready or partially_ready with flippable class).
- **CC-only launch posture**: escalation path requires `CLAUDECODE=1` AND `M030_SHADOW_MODE=1` AND `_DI_LIVE_MODEL_FLAG` non-empty. Codex CLI / Cursor cannot reach the escalation loop (live mode never engages on those runtimes per the existing T02 gate).
- **Bash 3.2 compatibility**: no `declare -A`, no `mapfile`, no `readarray`. The escalation loop uses `while : ; do ... done` (POSIX-safe).
- **Plan-Time Discipline rule 5 (real-DB verification)**: T03 introduces no SQL — N/A.

### Acceptance Criteria

This task satisfies the phase truths:

- "SC-4 holds: with model_routing.live: true AND a ready-verdict shadow corpus AND the stub-fail-n.sh adapter (counter starts at 2 — fail twice then pass) ..." — gated by `tools/verify/p04-sc4-escalation-sequence.sh`.
- "SC-5 holds: with model_routing.live: true AND a ready-verdict shadow corpus AND the stub-fail-n.sh adapter (counter starts at 3 — fail every attempt) ..." — gated by `tools/verify/p04-sc5-escalation-cap.sh`.
- "CON-5 hard-cap (no-fourth-record) gate ..." — gated by `tools/verify/p04-con5-no-fourth-record.sh`.
- "CON-6 prior-records-bit-identical gate ..." — gated by `tools/verify/p04-con6-prior-records-bit-identical.sh`.
- "New JSONL field escalation_count (integer, 0..2) appears on every shadow-on dispatch_usage record post-T03 ..." — gated by `tools/verify/p04-escalation-fields-enum.sh`.

### Files To Touch

- scripts/dispatch/dispatch-interface.sh (modify)
- scripts/dispatch/adapters/backend/stub-fail-n.sh (create)
- scripts/dispatch/adapters/backend/stub-record-model.sh (create)
- references/model-routing.md (modify)
- tests/fixtures/m030-p04/plans/plan-mechanical-no-override.md (create)
- tests/fixtures/m030-p04/plans/plan-fail-twice-then-pass.md (create)
- tests/fixtures/m030-p04/plans/plan-fail-three-times.md (create)
- tests/fixtures/m030-p04/plans/plan-fail-four-times.md (create)
- tests/fixtures/m030-p04/plans/plan-novel-class.md (create)
- tests/fixtures/m030-p04/configs/config-with-live-true.yml (create)
- tests/fixtures/m030-p04/configs/config-with-live-and-killswitch.yml (create)
- tests/fixtures/m030-p04/configs/config-with-live-false.yml (create)
- tests/fixtures/m030-p04/shadow-corpus-ready.jsonl (create)
- tests/fixtures/m030-p04/shadow-corpus-partially-ready.jsonl (create)
- tests/fixtures/m030-p04/shadow-corpus-empty.jsonl (create)
- tests/fixtures/m030-p04/round-trip-stage/intensity-metadata.txt (create)
- tests/fixtures/m030-p04/round-trip-stage/payload.txt (create)
- tools/verify/p04-additive-schema.sh (create)
- tools/verify/p04-override-source-enum-extended.sh (create)
- tools/verify/p04-sc2a-shadow-gate-block.sh (create)
- tools/verify/p04-sc3-live-mechanical.sh (create)
- tools/verify/p04-sc4-escalation-sequence.sh (create)
- tools/verify/p04-sc5-escalation-cap.sh (create)
- tools/verify/p04-con5-no-fourth-record.sh (create)
- tools/verify/p04-con6-prior-records-bit-identical.sh (create)
- tools/verify/p04-con3-live-closure.sh (create)
- tools/verify/p04-con4-live-killswitch.sh (create)
- tools/verify/p04-partial-flip-routing.sh (create)
- tools/verify/p04-escalation-fields-enum.sh (create)
- tools/verify/p04-phase-suite.sh (create)
- CLAUDE.md (modify — recent-changes region)
- AGENTS.md (modify if present — recent-changes region dual-write)

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