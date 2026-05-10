---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T02-rollup-and-footer-amendments (Phase P05, Milestone M030)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~300 | required |
| Upstream Context | 981-1060 | ~2900 | required |
| Task Plan | 1062-1503 | ~7200 | required |
| State Context | 1505-1511 | ~100 | required |
| First-Turn Completeness | 1513-1562 | ~1100 | required |
| **Total** | | **~22400** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 681
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
hit_count: 681
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
hit_count: 681
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
hit_count: 681
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
hit_count: 600
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
hit_count: 600
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
hit_count: 600
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
hit_count: 681
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
hit_count: 600
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
hit_count: 600
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
hit_count: 600
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
hit_count: 681
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
hit_count: 681
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
hit_count: 681
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
hit_count: 600
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
hit_count: 600
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
hit_count: 600
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
hit_count: 681
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
hit_count: 600
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
hit_count: 600
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
hit_count: 681
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
hit_count: 681
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
hit_count: 600
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
hit_count: 600
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
hit_count: 600
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
hit_count: 255
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
hit_count: 255
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
hit_count: 255
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
hit_count: 257
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
hit_count: 257
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
hit_count: 247
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
     slug-bearing filenames (p05-*) so install-clobber risk is contained
     ([M032](../../../../../milestones/M032/index.md) Finding A discipline).

     P05 is low-risk and surface-only: three additive amendments + a
     verifier wrapper. Three tasks total:
       T01 — fixtures + cost_rates-absent malformed routing.yml +
             tolerant pre-amendment SC-11 byte-equality gate.
       T02 — amend metrics-rollup.sh (--by-model) + amend
             efficiency-footer.sh (model_mix: line) + co-authored
             SC-8 and SC-9 verifiers + SC-11 confirmation against
             pre-M030 fixtures + doctor-config-check wrapper for SC-9.
       T03 — phase-suite aggregator + recent-changes dual-write +
             commit.

     T02 deliberately combines the rollup and footer amendments because
     they share a fixture corpus, share the cost_rates-present /

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

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P05"
milestone: "M030"
name: "metrics-rollup --by-model + efficiency-footer model_mix: line + co-authored verifiers + references doc amendment"
depends_on: ["T01"]
---

## Prerequisites

- T01 deliverables on disk and green:
  - `tests/fixtures/m030-p05/live-routed-corpus.jsonl` — 23 records (14 fast / 7 balanced / 2 smart).
  - `tests/fixtures/m030-p05/no-cost-rates-routing.yml` — routing-table copy without `cost_rates:`.
  - `tests/fixtures/m030-p05/rollup-pre-m030-baseline.txt` — golden baseline of unflagged rollup.
  - `tests/fixtures/m030-p05/footer-pre-m030-baseline.txt` — golden baseline of footer against pre-M030 corpus.
  - `tests/fixtures/m030-p05/synthesize-corpus.sh` — corpus synthesizer.
  - `tools/verify/p05-sc11-rollup-byte-equality.sh` — exits 0.
  - `tools/verify/p05-sc11-footer-byte-equality.sh` — exits 0.
  - `tools/verify/p05-doctor-config-check.sh` — exits 0.
- `scripts/diagnostics/metrics-rollup.sh` is in its post-M027/[M018](../../../../../milestones/M018/index.md) form. Key surface T02 will amend:
  - `metrics_rollup_main` argparse loop (lines ~702-770) — extend with `--by-model` and (optionally) `--routing-table` flags.
  - The CLI dispatch path after argparse (lines ~790-849) — branch on the new `--by-model` flag to take a different output path that suppresses the existing tabular emission and emits the per-tier dispatch-count + cost lines instead.
  - `metrics_rollup_normalize` projection (lines ~140-315) — extend the column set to include `model_routed` (currently column shape stops at column 18 with tier3 fields; T02 appends `model_routed` as column 19 to preserve the M018/P06 carry-forward convention, OR T02 extracts `model_routed` directly via a separate awk pass for the `--by-model` code-path so the normalize projection stays untouched and SC-11 byte-equality is trivially preserved). Recommended: separate awk pass — simpler invariant.
- `scripts/diagnostics/efficiency-footer.sh` is in its post-M018/P05 form. Key surface T02 will amend:
  - `efficiency_footer_render` body (lines ~44-157) — after the existing `compression:` line block (lines ~115-155), add a `model_mix:` block that invokes `metrics-rollup.sh --by-model` and parses the per-tier counts.
  - The `model_mix:` line is suppressed when the underlying corpus has zero shadow-on records (zero `model_routed` fields present). This is the SC-11 byte-equality preservation mechanism for pre-M030 fixtures.
- `templates/model-routing.yml` carries the shipped `cost_rates:` section (3 tiers × {input_per_mtok, output_per_mtok}).
- `references/model-routing.md` exists with the existing P01–P04 sections (`## Operator Overrides`, `## Live Routing`, etc.). T02 appends a `## Cost Rollup Surfaces` section.

Plan-time prerequisite-existence verification: every path above is asserted by T01 close. T02 entry runs `bash tools/verify/p05-sc11-rollup-byte-equality.sh && echo $?` (logical equivalent — actually run as a single script `bash <path>` and check `$?`) to confirm T01 is green before any amendment.

## Description

T02 lands the additive `--by-model` flag on `metrics-rollup.sh` and the additive `model_mix:` line on `efficiency-footer.sh`. Five deliverable groups:

1. **`metrics-rollup.sh --by-model` flag implementation.**
2. **`efficiency-footer.sh model_mix:` line implementation.**
3. **Co-authored scenario-specific verifiers** (4 new gates).
4. **`references/model-routing.md` amendment** — `## Cost Rollup Surfaces` section.
5. **Re-run T01's SC-11 gates** against the post-amendment surfaces to confirm byte-equality holds.

### `metrics-rollup.sh --by-model` shape

The amendment introduces:

- A new `--by-model` flag in `metrics_rollup_main`. When set, `by_model_mode=1`; the rollup takes a different code-path after argparse.
- A new optional `--routing-table <path>` flag. When set, `routing_table_path=<path>`; otherwise defaults to `M030_ROUTING_TABLE_PATH` env var, then `<project-root>/templates/model-routing.yml`. (Mirrors the doctor surface's pattern.)
- A new internal function `_metrics_rollup_by_model_emit` that:
  1. Reads the JSONL log line-by-line via awk, counting records by `model_routed` value (`fast | balanced | smart`). Records without `model_routed` (pre-M030) are skipped; they don't contribute to counts.
  2. Computes the total dispatch count `N = fast + balanced + smart`.
  3. Emits the per-tier dispatch-count line:
     ```
     N dispatches: <fast> fast / <balanced> balanced / <smart> smart
     ```
     (Exact label format documented; the SC-8 verifier matches this regex.)
  4. Reads `cost_rates:` from the routing-table file via an awk section-walker (same shape as P01/T03's routing-table parsing).
  5. If `cost_rates:` is present AND each tier's `input_per_mtok` + `output_per_mtok` are numeric, computes:
     - `aggregated_cost_usd` = sum over records of `(input_tokens_estimate / 1_000_000) * cost_rates.<tier-of-record>.input_per_mtok + (output_tokens_estimate / 1_000_000) * cost_rates.<tier-of-record>.output_per_mtok`.
     - `counterfactual_all_smart_cost_usd` = same sum but every record's tier replaced with `smart` (use `cost_rates.smart.input_per_mtok` + `cost_rates.smart.output_per_mtok` for every record's token counts).
     - Emits two additional lines:
       ```
       aggregated_cost_usd: 0.00012345
       counterfactual_all_smart_cost_usd: 0.00067890
       ```
     - (8-decimal precision; same precision as the existing tabular `EST_COST_USD` cell.)
  6. If `cost_rates:` is absent OR a tier entry is missing OR a rate value is non-numeric, emits:
     ```
     cost rates not configured
     aggregated_cost_usd: 0
     counterfactual_all_smart_cost_usd: 0
     ```
     (Warning, not hard failure. Exit 0 still.)
  7. Returns 0.

The new code-path is gated by `if [ "$by_model_mode" -eq 1 ]; then _metrics_rollup_by_model_emit ...; return 0; fi` placed AFTER the snapshot/normalize steps but BEFORE the existing `metrics_rollup_aggregate` + `metrics_rollup_render` invocations. This way the `--by-model` path reads from the same `$snapshot` (FR-19 / AD-3 atomicity) but emits a different shape.

**Critical invariant**: when `--by-model` is ABSENT, the `by_model_mode=0` default skips the new code-path entirely; the existing rollup emission is byte-identical to pre-T02. The SC-11 rollup gate (`p05-sc11-rollup-byte-equality.sh`) is the mechanical contract for this.

### `efficiency-footer.sh model_mix:` shape

The amendment introduces a new block in `efficiency_footer_render` AFTER the compression-line block (after line ~155 in the current source) and BEFORE the `return 0`:

```bash
# M030/P05/T02 — model_mix: line. Invokes metrics-rollup.sh --by-model
# against the same milestone/log path the parent footer is rendering.
# Suppressed when the corpus has zero shadow-on records (zero
# `model_routed` fields). This is the SC-11 byte-equality preservation
# mechanism — pre-M030 fixtures emit zero new bytes through the footer.
cfg_model_mix_footer="${ORCH_MODEL_MIX_FOOTER:-}"
if [ -z "$cfg_model_mix_footer" ] && [ -x "$_EFF_PROJECT_ROOT/scripts/state/read-config.sh" ]; then
  cfg_model_mix_footer="$(bash "$_EFF_PROJECT_ROOT/scripts/state/read-config.sh" model_routing.efficiency_footer.enabled 2>/dev/null || true)"
fi
case "$cfg_model_mix_footer" in
  false|FALSE|False|0|no|NO|No)
    : # suppressed by config
    ;;
  *)
    by_model_out=""
    if [ -n "$milestone" ]; then
      by_model_out="$(bash "$_EFF_PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh" \
        --by-model --milestone "$milestone" 2>/dev/null || true)"
    fi
    # Parse the per-tier dispatch-count line.
    mm_line="$(printf '%s\n' "$by_model_out" | grep -E '^[0-9]+ dispatches:' | head -n 1)"
    if [ -n "$mm_line" ]; then
      mm_total="$(printf '%s\n' "$mm_line" | awk '{print $1}')"
      mm_fast="$(printf '%s\n' "$mm_line" | awk -F'[: /]+' '{for(i=1;i<=NF;i++) if($i=="fast") print $(i-1)}' | head -n 1)"
      mm_bal="$(printf '%s\n' "$mm_line" | awk -F'[: /]+' '{for(i=1;i<=NF;i++) if($i=="balanced") print $(i-1)}' | head -n 1)"
      mm_smart="$(printf '%s\n' "$mm_line" | awk -F'[: /]+' '{for(i=1;i<=NF;i++) if($i=="smart") print $(i-1)}' | head -n 1)"
      # Suppress if total == 0 (no shadow-on records — SC-11 contract).
      if [ -n "$mm_total" ] && [ "$mm_total" -gt 0 ] 2>/dev/null; then
        printf '  model_mix: fast=%s balanced=%s smart=%s\n' "${mm_fast:-0}" "${mm_bal:-0}" "${mm_smart:-0}"
      fi
    fi
    ;;
esac
```

The block:

- Respects an `ORCH_MODEL_MIX_FOOTER` env var override (matches the existing `ORCH_EFFICIENCY_FOOTER` / `ORCH_COMPRESSION_FOOTER` convention).
- Falls through to `read-config.sh model_routing.efficiency_footer.enabled` for project/local/defaults config layers.
- Invokes `metrics-rollup.sh --by-model --milestone "$milestone"` and parses stdout for the per-tier line.
- Suppresses the line when total dispatches == 0 (the load-bearing SC-11 mechanism).
- Emits `  model_mix: fast=<N> balanced=<M> smart=<K>` with the standard 2-space indent.

Optional savings suffix: when `cost_rates:` is present (the rollup output additionally carries the `aggregated_cost_usd:` and `counterfactual_all_smart_cost_usd:` lines), T02 may compute `savings_usd = counterfactual - aggregated` and append ` savings: <USD>` to the model_mix: line. This is OPTIONAL — T02 documents whether it ships in P05 or defers to a later phase. The phase-suite verifier `p05-model-mix-footer-line.sh` accepts EITHER shape (with or without savings suffix); T02 commits to one and updates the verifier accordingly.

### Co-authored verifiers

Four new verifiers under `tools/verify/`:

1. **`p05-by-model-dispatch-counts.sh`** — invokes the rollup against the live-routed corpus and asserts the per-tier dispatch-count line has the expected exact integer counts.

   ```bash
   #!/usr/bin/env bash
   set -u
   PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   FIXTURE="$PROJECT_ROOT/tests/fixtures/m030-p05/live-routed-corpus.jsonl"

   pass=0; fail=0

   ACTUAL="$(mktemp -t p05-by-model-disp.XXXXXX)"
   trap 'rm -f "$ACTUAL"' EXIT

   bash "$PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh" \
     --by-model --log "$FIXTURE" \
     > "$ACTUAL" 2>/dev/null
   rc=$?

   if [ "$rc" -ne 0 ]; then
     fail=$((fail + 1))
     echo "FAIL: rollup --by-model exited $rc"
   fi

   # Assert the dispatch-count line is present.
   if grep -qE '^[0-9]+ dispatches: [0-9]+ fast / [0-9]+ balanced / [0-9]+ smart' "$ACTUAL"; then
     pass=$((pass + 1))
     echo "OK: dispatch-count line present"
   else
     fail=$((fail + 1))
     echo "FAIL: dispatch-count line missing or malformed"
   fi

   # Assert the exact counts (14 fast / 7 balanced / 2 smart over 23 total).
   if grep -qE '^23 dispatches: 14 fast / 7 balanced / 2 smart' "$ACTUAL"; then
     pass=$((pass + 1))
     echo "OK: counts match expected (14/7/2 over 23)"
   else
     fail=$((fail + 1))
     echo "FAIL: counts diverge from expected (14/7/2 over 23)"
     echo "Actual stdout:"
     cat "$ACTUAL"
   fi

   echo "SUMMARY: p05-by-model-dispatch-counts.sh pass=$pass fail=$fail"
   if [ "$fail" -eq 0 ]; then exit 0; fi
   exit 1
   ```

2. **`p05-by-model-cost-rates-present.sh`** — invokes the rollup with the shipped `templates/model-routing.yml` and asserts both the aggregated-cost line and counterfactual-cost line are present. Hand-computed expected values:

   - 14 records × 1024 input + 512 output @ fast (1.00/Mtok input, 5.00/Mtok output): 14 × (1024/1e6 × 1.00 + 512/1e6 × 5.00) = 14 × (0.001024 + 0.002560) = 14 × 0.003584 = 0.050176
   - 7 records × @ balanced (3.00/15.00): 7 × (0.003072 + 0.007680) = 7 × 0.010752 = 0.075264
   - 2 records × @ smart (15.00/75.00): 2 × (0.015360 + 0.038400) = 2 × 0.053760 = 0.107520
   - Aggregated: 0.050176 + 0.075264 + 0.107520 = 0.232960
   - Counterfactual (all 23 at smart): 23 × 0.053760 = 1.236480
   - Savings: 1.236480 − 0.232960 = 1.003520

   The verifier asserts the rollup emits these values to within 8-decimal precision (allow `0.232960` to render as `0.23296000` per the existing rollup's printf format).

3. **`p05-by-model-cost-rates-absent.sh`** — invokes the rollup with `--routing-table tests/fixtures/m030-p05/no-cost-rates-routing.yml` (or `M030_ROUTING_TABLE_PATH=...`) and asserts:

   - `cost rates not configured` line present.
   - `aggregated_cost_usd: 0` line present (or the documented zero-savings shape).
   - `counterfactual_all_smart_cost_usd: 0` line present.
   - Exit 0 (warning, not failure).
   - Per-tier dispatch-count line still present (fall-through from the rollup amendment).

4. **`p05-model-mix-footer-line.sh`** — invokes the footer against the live-routed corpus via an `ORCHESTRATOR_ROOT=tmp_root` carve-out. Stages `tmp_root/milestones/M999/execution-log.jsonl` as a copy of the fixture, then:

   ```bash
   ORCHESTRATOR_ROOT="$tmp_root" bash scripts/diagnostics/efficiency-footer.sh \
     --milestone M999 \
     > "$ACTUAL" 2>/dev/null
   ```

   Asserts the footer body contains `  model_mix: fast=14 balanced=7 smart=2` (with the expected counts). If T02 ships the optional savings suffix, the verifier additionally asserts ` savings: <numeric>` is present.

### `references/model-routing.md` amendment

Append a new `## Cost Rollup Surfaces` section after the existing `## Live Routing` section. Section content:

```markdown
## Cost Rollup Surfaces

`scripts/diagnostics/metrics-rollup.sh --by-model` emits per-tier
dispatch counts, aggregated cost, and the all-`smart` counterfactual
for any milestone with shadow-on or live-routed `dispatch_usage`
records. Output shape:

```text
N dispatches: <fast> fast / <balanced> balanced / <smart> smart
aggregated_cost_usd: <USD>
counterfactual_all_smart_cost_usd: <USD>
```

When `cost_rates:` is absent from `templates/model-routing.yml` (or
the path passed via `--routing-table`/`M030_ROUTING_TABLE_PATH`), the
output substitutes:

```text
N dispatches: <fast> fast / <balanced> balanced / <smart> smart
cost rates not configured
aggregated_cost_usd: 0
counterfactual_all_smart_cost_usd: 0
```

`scripts/diagnostics/efficiency-footer.sh` emits an additional
`model_mix:` line at the close of an `orchestrator:auto` run when
the milestone's `dispatch_usage` records contain `model_routed`
fields. Line shape: `  model_mix: fast=<N> balanced=<M> smart=<K>`.
The line is suppressed when the corpus has zero shadow-on records
(byte-equality with pre-M030 footer output).

### Operator obligation

Update `cost_rates:` in `templates/model-routing.yml` when provider
pricing changes. The `--by-model` counterfactual relies on these
values being current. The doctor's `--config-check` validates the
SECTION shape (closure invariants) but does NOT validate that the
RATES are current — staleness is an operator-noticed fact, not a
mechanical gate.
```

### SC-11 re-confirmation

Post-amendment, T02 re-runs the T01 SC-11 gates:

```bash
bash tools/verify/p05-sc11-rollup-byte-equality.sh
bash tools/verify/p05-sc11-footer-byte-equality.sh
```

Both must continue to exit 0. If either fails, T02's amendment has broken byte-equality and must be reworked. Common breakage modes:

- The rollup amendment accidentally emits a new line on the unflagged code-path (e.g., a debug `printf` left in). Fix: gate every new emission on `by_model_mode=1`.
- The footer amendment accidentally emits the `model_mix:` line when the corpus has zero shadow-on records (e.g., the suppression check is skipped or the `mm_total` parse is empty-string-vs-zero confused). Fix: tighten the `[ "$mm_total" -gt 0 ] 2>/dev/null` guard or add an explicit `[ -n "$mm_total" ] && [ "$mm_total" != "0" ]` check.

## Steps

1. **Confirm T01 deliverables are green**:

   ```bash
   bash tools/verify/p05-sc11-rollup-byte-equality.sh
   bash tools/verify/p05-sc11-footer-byte-equality.sh
   bash tools/verify/p05-doctor-config-check.sh
   ```

   Expected: all three exit 0. If any fail, halt T02 and re-open T01.

2. **Read `scripts/diagnostics/metrics-rollup.sh`** in full to confirm the line numbers and surface shape match the prerequisite description. Identify the argparse loop's insertion point (after `--source` case block) and the post-argparse CLI dispatch (after `_metrics_rollup_default_milestone` resolution).

3. **Read `scripts/diagnostics/efficiency-footer.sh`** in full to confirm the insertion point for the `model_mix:` block (after the compression-line block, before the `return 0`).

4. **Amend `scripts/diagnostics/metrics-rollup.sh`** per the Description:

   - Add `--by-model` and `--routing-table` flags to the argparse loop.
   - Add the `_metrics_rollup_by_model_emit` function near the other internal functions (e.g., after `metrics_rollup_render`).
   - Add the `if [ "$by_model_mode" -eq 1 ]; then _metrics_rollup_by_model_emit ...; return 0; fi` branch after the snapshot+normalize but before aggregate+render.
   - Bash 3.2 compatible. MEM004 emitter-internal carve-out applies — pipes / `$(...)` / awk allowed inside the function body.

5. **Author `tools/verify/p05-by-model-dispatch-counts.sh`** per the shape in the Description. Make executable.

6. **Author `tools/verify/p05-by-model-cost-rates-present.sh`** with the hand-computed expected values. Make executable.

7. **Author `tools/verify/p05-by-model-cost-rates-absent.sh`** with the cost-rates-absent fixture. Make executable.

8. **Run all three rollup verifiers** to confirm the rollup amendment is green:

   ```bash
   bash tools/verify/p05-by-model-dispatch-counts.sh
   bash tools/verify/p05-by-model-cost-rates-present.sh
   bash tools/verify/p05-by-model-cost-rates-absent.sh
   ```

   Expected: all three exit 0 with `SUMMARY: ... pass=N fail=0`.

9. **Re-run the SC-11 rollup gate** to confirm byte-equality is preserved:

   ```bash
   bash tools/verify/p05-sc11-rollup-byte-equality.sh
   ```

   Expected: exit 0. If fail, the rollup amendment has broken unflagged byte-equality — investigate and fix before proceeding.

10. **Amend `scripts/diagnostics/efficiency-footer.sh`** per the Description — add the `model_mix:` block after the compression-line block.

11. **Author `tools/verify/p05-model-mix-footer-line.sh`** with the carve-out staging and per-tier-count assertion. Make executable.

12. **Run the footer verifier**:

    ```bash
    bash tools/verify/p05-model-mix-footer-line.sh
    ```

    Expected: exit 0.

13. **Re-run the SC-11 footer gate** to confirm byte-equality is preserved on pre-M030 corpora:

    ```bash
    bash tools/verify/p05-sc11-footer-byte-equality.sh
    ```

    Expected: exit 0. If fail, the footer amendment has accidentally emitted a `model_mix:` line for a corpus with zero shadow-on records — investigate the suppression guard.

14. **Amend `references/model-routing.md`** by appending the `## Cost Rollup Surfaces` section per the Description.

15. **Run the full T01+T02 verifier set** as a self-check:

    ```bash
    bash tools/verify/p05-sc11-rollup-byte-equality.sh
    bash tools/verify/p05-sc11-footer-byte-equality.sh
    bash tools/verify/p05-doctor-config-check.sh
    bash tools/verify/p05-by-model-dispatch-counts.sh
    bash tools/verify/p05-by-model-cost-rates-present.sh
    bash tools/verify/p05-by-model-cost-rates-absent.sh
    bash tools/verify/p05-model-mix-footer-line.sh
    ```

    Expected: all seven exit 0.

## Must-Haves

T02 satisfies the following phase truths:

- "`bash scripts/diagnostics/metrics-rollup.sh --by-model --log <fixture>` emits a per-tier dispatch-count line" — gated by `bash tools/verify/p05-by-model-dispatch-counts.sh`.
- "With `cost_rates:` present, additionally emits aggregated cost + counterfactual lines" — gated by `bash tools/verify/p05-by-model-cost-rates-present.sh`.
- "With `cost_rates:` absent, emits warning + zero-savings lines, exit 0" — gated by `bash tools/verify/p05-by-model-cost-rates-absent.sh`.
- "`efficiency-footer.sh` emits `model_mix: fast=<N> balanced=<M> smart=<K>` when corpus has shadow-on records" — gated by `bash tools/verify/p05-model-mix-footer-line.sh`.
- SC-11 gates from T01 continue to pass post-amendment — gated by `bash tools/verify/p05-sc11-rollup-byte-equality.sh` and `bash tools/verify/p05-sc11-footer-byte-equality.sh`.

## Verification

```bash
bash tools/verify/p05-by-model-dispatch-counts.sh
bash tools/verify/p05-by-model-cost-rates-present.sh
bash tools/verify/p05-by-model-cost-rates-absent.sh
bash tools/verify/p05-model-mix-footer-line.sh
bash tools/verify/p05-sc11-rollup-byte-equality.sh
bash tools/verify/p05-sc11-footer-byte-equality.sh
bash tools/verify/p05-doctor-config-check.sh
```

Each command uses single-script-file shape per AD-19. All seven must exit 0 before T02 closes. Each emits `SUMMARY: <verifier-name> pass=N fail=0` on success.

## Inputs

### From Previous Tasks (T01)

- `tests/fixtures/m030-p05/live-routed-corpus.jsonl` — Key API: 23-record JSONL fixture; 14 fast / 7 balanced / 2 smart distribution; deterministic per-record token counts (1024 input / 512 output). Consumed by the rollup verifiers and the footer verifier.
- `tests/fixtures/m030-p05/no-cost-rates-routing.yml` — Key API: routing-table YAML without `cost_rates:` section; otherwise structurally valid. Consumed by `p05-by-model-cost-rates-absent.sh`.
- `tests/fixtures/m030-p05/rollup-pre-m030-baseline.txt` + `tests/fixtures/m030-p05/footer-pre-m030-baseline.txt` — Key API: golden stdout snapshots of pre-amendment rollup + footer against pre-M030 fixture. Consumed by SC-11 gates.
- `tools/verify/p05-sc11-rollup-byte-equality.sh` + `tools/verify/p05-sc11-footer-byte-equality.sh` + `tools/verify/p05-doctor-config-check.sh` — Key API: each `bash <path>` exits 0 on green; emits `SUMMARY:` line with pass-count.

### From Disk (Pre-existing)

- `scripts/diagnostics/metrics-rollup.sh` — Key API: sourceable + CLI; `bash <path> [flags]` emits cost+quality table to stdout; flags include `--granularity`, `--milestone`, `--phase`, `--task`, `--source`, `--log`, `--help`. T02 extends with `--by-model` and `--routing-table`.
- `scripts/diagnostics/efficiency-footer.sh` — Key API: sourceable function `efficiency_footer_render <milestone> <quiet-flag>` + CLI `bash <path> [--milestone <id>] [--project] [--quiet]`. Emits multi-line footer body to stdout. T02 amends to additionally emit `model_mix:` line.
- `templates/model-routing.yml` — Key API: 3 top-level sections (`routing:`, `resolution:`, `cost_rates:`); per-tier `cost_rates.<tier>.{input_per_mtok,output_per_mtok}` keys. SSOT for cost computation.
- `references/model-routing.md` — operator-facing routing-table documentation. T02 appends `## Cost Rollup Surfaces` section.
- `scripts/state/read-config.sh` — Key API: `bash <path> <key>` reads `<key>` from the `.orchestrator/config.yml` overlay layers. Used by the footer's config-knob resolution.

## Constraints

- **AD-19 single-script-file shape**: every verifier under `tools/verify/p05-*` is invoked as a single `bash <path>`. The amendments themselves are emitter-internal (MEM004 carve-out applies — pipes / `$(...)` / awk allowed inside `metrics-rollup.sh` and `efficiency-footer.sh` bodies).
- **AP-008 heredoc-with-expansion**: not introduced — T02 ships only code amendments + verifiers. T03 handles the commit.
- **AP-009 compound-chain-gt2**: verifier scripts use straight-line shape (per-command `bash <path>` then `$?` capture); no `cmd1 && cmd2 && cmd3` chains.
- **Bash 3.2 compatibility**: amendments use parallel scalars, plain `case`, `while [ ... ]; do` loops. No `declare -A`, no `mapfile`, no process substitution.
- **CON-2 / FR-19 / SC-11 (additive schema)**: every amendment is strictly additive. Default rollup output (no `--by-model`) is byte-identical to pre-T02. Footer output on pre-M030 corpus is byte-identical to pre-T02 (suppress the `model_mix:` line entirely when no `model_routed` records present). The SC-11 gates from T01 are the mechanical contract.
- **CON-3 closure preserved**: T02 introduces zero new hardcoded model IDs. The `_metrics_rollup_by_model_emit` function reads model IDs ONLY from `templates/model-routing.yml resolution:` (and even then, only indirectly via `model_routed` symbolic-tier values from JSONL records — the cost computation uses `cost_rates.<tier>` not `cost_rates.<model-id>`). Verified by visual inspection of the diff (no `claude-haiku-*` / `claude-sonnet-*` / `claude-opus-*` literals introduced).
- **Plan-Time Discipline rule 5 (real-DB verification)**: T02 introduces no SQL — N/A.
- **Plan-Time Discipline rule 4 (run-probe.sh scope)**: T02 invokes verifiers under `tools/verify/` and `scripts/diagnostics/` directly via `bash <path>`. No `run-probe.sh` invocations.
- **Project-owned-verifier-paths discipline (M032 Finding A)**: every new verifier lives under `tools/verify/p05-*`; none under `scripts/verify/`.

## Expected Output

- `scripts/diagnostics/metrics-rollup.sh` — amended with `--by-model` flag handler + per-tier aggregation + cost_rates-present and cost_rates-absent branches. Default behavior byte-identical to pre-T02.
- `scripts/diagnostics/efficiency-footer.sh` — amended with `model_mix:` line block. Suppression on no-shadow-on-records preserves SC-11 byte-equality.
- `references/model-routing.md` — extended with `## Cost Rollup Surfaces` section.
- `tools/verify/p05-by-model-dispatch-counts.sh` + `p05-by-model-cost-rates-present.sh` + `p05-by-model-cost-rates-absent.sh` + `p05-model-mix-footer-line.sh` — four new verifiers; each exits 0 against post-T02 surfaces.
- T01 SC-11 gates continue to exit 0.

## Notes

Expected output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p05-by-model-dispatch-counts.sh` → `SUMMARY: p05-by-model-dispatch-counts.sh pass=2 fail=0`, exit 0.
- `bash tools/verify/p05-by-model-cost-rates-present.sh` → `SUMMARY: p05-by-model-cost-rates-present.sh pass=N fail=0`, exit 0.
- `bash tools/verify/p05-by-model-cost-rates-absent.sh` → `SUMMARY: p05-by-model-cost-rates-absent.sh pass=N fail=0`, exit 0.
- `bash tools/verify/p05-model-mix-footer-line.sh` → `SUMMARY: p05-model-mix-footer-line.sh pass=N fail=0`, exit 0.
- `bash scripts/diagnostics/metrics-rollup.sh --by-model --log tests/fixtures/m030-p05/live-routed-corpus.jsonl` (rough sample) →
  ```
  23 dispatches: 14 fast / 7 balanced / 2 smart
  aggregated_cost_usd: 0.23296000
  counterfactual_all_smart_cost_usd: 1.23648000
  ```
- `bash scripts/diagnostics/efficiency-footer.sh --milestone M999` (with carve-out → live-routed corpus) — appends `  model_mix: fast=14 balanced=7 smart=2` to the existing footer body.

The label tokens `aggregated_cost_usd:` and `counterfactual_all_smart_cost_usd:` are stable contract — the SC-8 verifier locks them. If T02 chooses different label tokens (e.g., `total_cost_usd:` and `counterfactual_smart_only_usd:`), the label change must be reflected in BOTH the rollup amendment AND the verifier scripts authored in T02 — the labels are a coupled commit. Recommended: use the labels documented above for consistency with the spec's prose-level mention of "an aggregated cost line + an all-`smart` counterfactual line".

The `--routing-table` flag is OPTIONAL plumbing — T02 may instead expose only the `M030_ROUTING_TABLE_PATH` env var (matches the doctor surface's `ROUTING_TABLE_PATH` env-only convention). The verifier `p05-by-model-cost-rates-absent.sh` should use whichever mechanism T02 ships; the choice is documented in the rollup amendment's inline comments.

If the rollup-shape verifier `tools/verify/p01-routing-table-shape.sh` rejected the cost-rates-absent fixture in T01 step 5, T01 should have already amended the verifier to relax the cost_rates: presence requirement. T02 inherits that amendment and assumes the routing-table-shape verifier accepts cost_rates: as optional. If T01 did not make that amendment (because the verifier already accepted absence), no T02 action is needed.

The savings-suffix on the `model_mix:` line is a stylistic choice — both forms (`model_mix: fast=14 balanced=7 smart=2` and `model_mix: fast=14 balanced=7 smart=2 savings: 1.00352000`) are acceptable. T02 ships ONE form; the verifier `p05-model-mix-footer-line.sh` asserts the chosen form. If T02 ships only the per-tier counts (no savings suffix), the verifier asserts only the per-tier counts; if T02 ships the savings suffix, the verifier additionally asserts the suffix is present with a numeric value.

If `efficiency-footer.sh` cannot resolve the active milestone in the carve-out (because `find-active-milestone.sh` returns empty under the staged ORCHESTRATOR_ROOT), pass `--milestone M999` explicitly to short-circuit the resolver. The verifier should always pass `--milestone` explicitly to keep the carve-out predictable.

## State Context

- **Current State**: executing
- **Milestone**: M030
- **Phase**: P05
- **Task**: T02-rollup-and-footer-amendments
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **AD-19 single-script-file shape**: every verifier under `tools/verify/p05-*` is invoked as a single `bash <path>`. The amendments themselves are emitter-internal (MEM004 carve-out applies — pipes / `$(...)` / awk allowed inside `metrics-rollup.sh` and `efficiency-footer.sh` bodies).
- **AP-008 heredoc-with-expansion**: not introduced — T02 ships only code amendments + verifiers. T03 handles the commit.
- **AP-009 compound-chain-gt2**: verifier scripts use straight-line shape (per-command `bash <path>` then `$?` capture); no `cmd1 && cmd2 && cmd3` chains.
- **Bash 3.2 compatibility**: amendments use parallel scalars, plain `case`, `while [ ... ]; do` loops. No `declare -A`, no `mapfile`, no process substitution.
- **CON-2 / FR-19 / SC-11 (additive schema)**: every amendment is strictly additive. Default rollup output (no `--by-model`) is byte-identical to pre-T02. Footer output on pre-M030 corpus is byte-identical to pre-T02 (suppress the `model_mix:` line entirely when no `model_routed` records present). The SC-11 gates from T01 are the mechanical contract.
- **CON-3 closure preserved**: T02 introduces zero new hardcoded model IDs. The `_metrics_rollup_by_model_emit` function reads model IDs ONLY from `templates/model-routing.yml resolution:` (and even then, only indirectly via `model_routed` symbolic-tier values from JSONL records — the cost computation uses `cost_rates.<tier>` not `cost_rates.<model-id>`). Verified by visual inspection of the diff (no `claude-haiku-*` / `claude-sonnet-*` / `claude-opus-*` literals introduced).
- **Plan-Time Discipline rule 5 (real-DB verification)**: T02 introduces no SQL — N/A.
- **Plan-Time Discipline rule 4 (run-probe.sh scope)**: T02 invokes verifiers under `tools/verify/` and `scripts/diagnostics/` directly via `bash <path>`. No `run-probe.sh` invocations.
- **Project-owned-verifier-paths discipline (M032 Finding A)**: every new verifier lives under `tools/verify/p05-*`; none under `scripts/verify/`.

### Acceptance Criteria

T02 satisfies the following phase truths:

- "`bash scripts/diagnostics/metrics-rollup.sh --by-model --log <fixture>` emits a per-tier dispatch-count line" — gated by `bash tools/verify/p05-by-model-dispatch-counts.sh`.
- "With `cost_rates:` present, additionally emits aggregated cost + counterfactual lines" — gated by `bash tools/verify/p05-by-model-cost-rates-present.sh`.
- "With `cost_rates:` absent, emits warning + zero-savings lines, exit 0" — gated by `bash tools/verify/p05-by-model-cost-rates-absent.sh`.
- "`efficiency-footer.sh` emits `model_mix: fast=<N> balanced=<M> smart=<K>` when corpus has shadow-on records" — gated by `bash tools/verify/p05-model-mix-footer-line.sh`.
- SC-11 gates from T01 continue to pass post-amendment — gated by `bash tools/verify/p05-sc11-rollup-byte-equality.sh` and `bash tools/verify/p05-sc11-footer-byte-equality.sh`.

### Files To Touch

- scripts/diagnostics/metrics-rollup.sh (modify — add --by-model flag + per-tier aggregation + cost_rates branches; preserve unflagged byte-equality)
- scripts/diagnostics/efficiency-footer.sh (modify — add model_mix: line; preserve byte-equality on no-shadow-on-records)
- references/model-routing.md (modify — add `## Cost Rollup Surfaces` section)
- tests/fixtures/m030-p05/live-routed-corpus.jsonl (create)
- tests/fixtures/m030-p05/no-cost-rates-routing.yml (create)
- tests/fixtures/m030-p05/rollup-pre-m030-baseline.txt (create)
- tests/fixtures/m030-p05/footer-pre-m030-baseline.txt (create)
- tests/fixtures/m030-p05/synthesize-corpus.sh (create)
- tools/verify/p05-by-model-dispatch-counts.sh (create)
- tools/verify/p05-by-model-cost-rates-present.sh (create)
- tools/verify/p05-by-model-cost-rates-absent.sh (create)
- tools/verify/p05-model-mix-footer-line.sh (create)
- tools/verify/p05-sc11-rollup-byte-equality.sh (create)
- tools/verify/p05-sc11-footer-byte-equality.sh (create)
- tools/verify/p05-doctor-config-check.sh (create)
- tools/verify/p05-phase-suite.sh (create)
- CLAUDE.md (modify — recent-changes region)
- AGENTS.md (modify if present — recent-changes region dual-write)

<!-- Phase plan and task plan files (this file + tasks/T0[1-3]-*-PLAN.md)
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