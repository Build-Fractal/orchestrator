---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T02-spec-dir-rename (Phase P01.5, Milestone M035)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~200 | required |
| Upstream Context | 981-1107 | ~3300 | required |
| Task Plan | 1109-1353 | ~2600 | required |
| State Context | 1355-1361 | ~100 | required |
| First-Turn Completeness | 1363-1442 | ~1000 | required |
| **Total** | | **~18000** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 862
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
hit_count: 862
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
hit_count: 862
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
hit_count: 862
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
hit_count: 750
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
hit_count: 750
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
hit_count: 750
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
hit_count: 862
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
hit_count: 750
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
hit_count: 750
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
hit_count: 750
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
hit_count: 862
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
hit_count: 862
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
hit_count: 862
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
hit_count: 750
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
hit_count: 750
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
hit_count: 750
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
hit_count: 862
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
hit_count: 750
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
hit_count: 750
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
hit_count: 862
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
hit_count: 862
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
hit_count: 750
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
hit_count: 750
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
hit_count: 750
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
hit_count: 405
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
hit_count: 405
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
hit_count: 405
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
hit_count: 438
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
hit_count: 438
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
hit_count: 428
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

- The legacy-namespace allowlist file
  `tests/m035-acceptance/legacy-namespace-allowlist.txt` exists on disk
  and enumerates exactly the 5 historical/migration files specified by
  the M035 roadmap Boundary Map (`commands/migrate.md`,
  `docs/migrating-from-speckit.md`, `references/RENAME-PLAN.md`,
  `scripts/verify/m015-p03-helpers/changelog-historical-snapshot.txt`,
  `scripts/state/namespace-aliases.sh`).
  - Check: `bash tools/verify/m035-p015-allowlist-shape.sh`

- `[D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }")..[D-RN-7](../../../../../decisions.md#d-rn-7-pre-rename-version-tag-v09x-final-spec-kit-name-dr-code-035 "Pre-rename version tag `v0.9.X-final-spec-kit-name` { #dr-code-035 }")` are recorded in [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) as a
  single `D0XX` block following the existing `### <Title> { #dr-code-NNN }`
  shape. The block is greppable as a unit (one heading per decision OR
  one composite heading naming all seven).
  - Check: `bash tools/verify/m035-p015-decisions-block.sh`

- The pre-rename git tag `v0.9.X-final-spec-kit-name` (where `X` is the

<dispatch-volatile>

## Upstream Context


### P01 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M035"
milestone: "M035"
provides:
  - "user-facing --mode=copy|symlink flag on all 3 installers; --asset-mode-override preserved as TEST-ONLY backward-compat alias; install-asset-mode.sh symlink branch retargeted to direct REPO_ROOT/<src> path (US-1 dogfood-velocity contract); install-meta.txt extended with commit_sha= + version= fields (Q-9 5-line shape); references/installation.md Symlink-mode caveats section documents Q-7 + Q-8 + bundle-hygiene; m035-acceptance fixture pair (with-sha + pre-m035) for downstream T03; two task-grain verifiers (m035-p01-mode-flag.sh + m035-p01-symlink-source-target.sh),mode-aware manifest write (symlink emits 1 row per target with mode:symlink,copy emits per-file rows as today) in all 3 installers; mode-aware --uninstall short-circuit (symlink-mode rm -f's the symlink only via -L test,copy-mode rm -f's regular files via -f test) preserving CON-1 source-repo invariant; references/installation.md § Rollback-and-symlink-mode-interaction documenting #Q-G8 (--rollback unsupported in symlink mode); tools/verify/m035-p01-mode-aware-uninstall.sh task-grain verifier exercising both round-trips with snapshot-based source-repo invariant check,scripts/state/check-orchestrator-drift.sh (read-only drift helper,FR-3 / FR-15); SHA-absent fallback per #Q-G5; tools/verify/m035-p01-drift-detection.sh (SC-3 SHA-bearing path); tools/verify/m035-p01-drift-detection-sha-absent.sh (SC-3b pre-M035 fallback path),drift-line render path wired into both TUI (commands/status.md doc-step) and JSON (render-status-json.sh top-level `drift` object); FR-4/FR-16 suppression matrix implementation; § Drift Line (M035 P01) addendum on status-headline-shape.md + § drift (M035 P01) addendum on status-json-schema.md; m035-p01-drift-line-in-status.sh (SC-4 primary) + m035-p01-drift-line-suppressed.sh (3 sub-cases) + m035-p01-phase-suite.sh AD-19-prefixed P01 aggregator"
requires:
  - "P00"
affects:
  - "P01.5"
key_files:
  - "packaging/install/install-claude-code.sh,packaging/install/install-codex.sh,packaging/install/install-cursor.sh,scripts/lifecycle/install-asset-mode.sh,references/installation.md,tests/m035-acceptance/fixtures/install-meta-with-sha.txt,tests/m035-acceptance/fixtures/install-meta-pre-m035.txt,tools/verify/m035-p01-mode-flag.sh,tools/verify/m035-p01-symlink-source-target.sh,tests/m032-acceptance/p01-symlink-mode.sh,tools/verify/m035-p01-mode-aware-uninstall.sh,scripts/state/check-orchestrator-drift.sh,tools/verify/m035-p01-drift-detection.sh,tools/verify/m035-p01-drift-detection-sha-absent.sh,scripts/diagnostics/render-status-json.sh,commands/status.md,references/status-headline-shape.md,references/status-json-schema.md,tools/verify/m035-p01-drift-line-in-status.sh,tools/verify/m035-p01-drift-line-suppressed.sh,tools/verify/m035-p01-phase-suite.sh"
key_decisions:
  - "Q-G4 advisory-message wording (symlink mode unsupported on this filesystem -- re-run with --mode=copy,exit 3 unchanged); Q-7 symlinks-only at v1,hardlinks deferred (cross-machine fragility caveat documented); Q-8 --mode=symlink is Unix-only at v1,copy-mode is platform-agnostic; Q-9 install-meta.txt gains commit_sha= + version= as always-present lines,empty values explicit not skipped,#Q-G8 resolution recorded in references/installation.md (--rollback unsupported in symlink mode; symlink consumers are always at HEAD by construction; P05 will emit advisory + non-zero exit; P01 ships no --rollback code); manifest-write loop branches on mode_val via case block (NOT inline conditional or compound chain) so AP-009 shape-guard is honoured; codex+cursor uninstall loops upgraded from bare-rel read to tab-split shape that install-claude-code.sh has used since [M032](../../../../../milestones/M032/index.md) P01,inline awk semver-delta (no separate lib/semver-delta.sh — patch-diff when major+minor match,else 1); CHANGELOG awk pattern restricted to ^## \[[0-9] to skip past ## [Unreleased]; verifier owns fixture upstream creation under mktemp -d with git config commit.gpgsign false guard against operator gpg configs,additive `drift` top-level object does NOT bump _M029_SCHEMA_VERSION (AD-7 stability policy honored — inline comment in renderer captures intent; [M029](../../../../../milestones/M029/index.md) SC-3 acceptance re-run 26/26 green); commits_behind encoded as JSON string (accommodates both numeric and unknown-fallback shapes without parser brittleness); drift object key set is STABLE across availability states (deviation from sections-side suppression-by-omission convention — downstream consumers need stable shape regardless of helper availability); _rsj_collect_drift_block strips trailing /.orchestrator from _RSJ_ORCH_ROOT to compute consumer project root for the helper invocation; verifier sub-case (c) tests render-side suppression matrix with update_source=none rather than helper-unavailable path (the latter is owned by T03 graceful-degrade tests)"
patterns_established:
  - "user-facing-flag-promoted-from-test-only-alias-without-deprecating-alias (--mode supersedes --asset-mode-override at the surface; alias preserved byte-identically for M032 acceptance scripts); symlink-target-equals-src-abs (link_target=SRC retires the runtime-cache indirection; one-line replacement for the M032/P01 11-line resolution block); install-meta.txt always-present-lines-with-explicit-empty-values (downstream drift helper distinguishes field-absent-pre-M035 from field-present-but-empty),single-row-per-symlink-target manifest shape (symlink mode emits one <tgt>\tmode:symlink line; copy mode keeps per-file expansion); -L/-f conditional uninstall (symlink branch tests -L only; copy branch tests -f only) so a copy-mode uninstall never accidentally removes a symlink and vice versa; verifier-snapshot source-repo invariant (ls /<dir> | head -n 1 pre/post-uninstall) — guards CON-1 against future regressions cheaply without sha-summing the entire source tree; symmetric verifier shape across mode branches with skip-when-ln-s-unavailable for symlink branch only (copy branch always runs),read-only drift helper exits 0 always (FR-15 — consumers branch on data not exit code); SHA-absent fallback emits commits_behind=unknown + one-time stderr advisory; verifier owns its fixture upstream-repo (mktemp -d + git init + N seeded commits + rewrite consumer commit_sha to fixture INITIAL_SHA) for deterministic commits_behind=N assertions,render-side reuse of T03 helper four-line key=value stdout block via grep+sed parse (no jq dependency on helper invocation; jq used only for envelope assembly); JSON envelope key-set stability under suppression — empty string for rendered_line + zero/none defaults for the rest,NOT key omission (downstream-consumer ergonomics); AD-19 phase-suite aggregator filename mirrors P00 shape (m035-p<NN>-phase-suite.sh) for cross-phase grep discovery; verifier scaffold for render-side drift fixtures = T03 upstream-fixture pattern (mktemp -d + git init + N seeded commits + INITIAL_SHA rewrite of consumer install-meta) + M029 milestone-fixture overlay (cp -R from tests/m029-acceptance/fixtures/status-json-executing.fixture/milestones)"
drill_down_paths:
  - "[.orchestrator/milestones/M035/phases/P01/tasks/T01-SUMMARY.md](../../../../../milestones/M035/phases/P01/tasks/T01-SUMMARY.md), [.orchestrator/milestones/M035/phases/P01/tasks/T02-SUMMARY.md](../../../../../milestones/M035/phases/P01/tasks/T02-SUMMARY.md), [.orchestrator/milestones/M035/phases/P01/tasks/T03-SUMMARY.md](../../../../../milestones/M035/phases/P01/tasks/T03-SUMMARY.md), [.orchestrator/milestones/M035/phases/P01/tasks/T04-SUMMARY.md](../../../../../milestones/M035/phases/P01/tasks/T04-SUMMARY.md)"
duration: "185m"
verification_result: "pass"
completed_at: "2026-05-08T13:50:21Z"
observability_surfaces:
  - "none"
---

P01 closes the M035 pre-launch dev-ergonomics layer for orchestrator-source
visibility and `--mode=symlink` velocity. With P00's installer hardening as
foundation, P01 promotes the M032/P01 TEST-ONLY `--asset-mode-override`
flag to the user-facing `--mode=copy|symlink` surface across all three
installers, retargets the symlink branch directly at the source repo
(US-1 dogfood-velocity contract), wires drift detection from
`install-meta.txt` into `orchestrator:status`, and ships a 7-verifier
phase-suite that the M035 publishing pipelines (P02–P06) inherit as
preconditions.

Four tasks landed:

- **T01** (mode flag + symlink-to-source + meta extension). Promoted
  `--asset-mode-override` to `--mode=copy|symlink` across the three
  installers; preserved the old flag byte-identically as a TEST-ONLY
  alias so M032 acceptance scripts keep working. Retargeted
  `scripts/lifecycle/install-asset-mode.sh`'s symlink branch to set
  `link_target="$SRC"` directly — replacing the M032-era 11-line
  runtime-cache resolution block with a one-line assignment that
  delivers the US-1 contract: `git pull` in `$REPO_ROOT` updates every
  consumer immediately. Extended `install-meta.txt` with two new
  always-present fields (`commit_sha=` from `git rev-parse HEAD`,
  `version=` from `CHANGELOG.md` top-line per #Q-9) so T03's drift
  helper has the data shape it consumes. Authored
  `references/installation.md § Symlink-mode caveats` covering #Q-7
  (cross-machine fragility), #Q-8 (Unix-only at v1), and bundle hygiene.
  Updated the Windows fail-closed advisory wording per #Q-G4
  (`"FAIL: symlink mode unsupported on this filesystem -- re-run with
  --mode=copy"`) and synced the M032 acceptance grep accordingly.

- **T02** (mode-aware uninstall). Branched the manifest-write loop in
  all three installers on `mode_val` via `case`: symlink mode emits one
  `<tgt>\tmode:symlink` row per target; copy mode emits per-file rows
  as today. `--uninstall` short-circuit branches symmetrically on
  `mode_tok` — symlink-mode tests `[ -L "$f" ]` then `rm -f`, copy-mode
  tests `[ -f "$f" ]` then `rm -f`, so a copy-mode uninstall never
  accidentally removes a symlink and vice versa. The CON-1 source-repo
  invariant is enforced in the verifier via `ls /<dir> | head -n 1`
  pre/post-uninstall snapshots — cheap, reusable, and catches any
  future regression that would `rm` through the symlink. Added
  `### Rollback-and-symlink-mode-interaction` section recording #Q-G8
  (--rollback unsupported in symlink mode) for P05 plan-phase.

- **T03** (orchestrator-source drift detection). Authored
  `scripts/state/check-orchestrator-drift.sh` — a read-only helper that
  reads `.orchestrator/install-meta.txt` + `.orchestrator/config.yml`
  and emits a four-line `key=value` block (`commits_behind`,
  `update_source`, `upstream_path`, `versions_behind`) on stdout,
  exiting 0 always (FR-15 — consumers branch on data, not exit code).
  SHA-absent fallback per #Q-G5 emits `commits_behind=unknown` plus a
  one-time stderr advisory. Two task-grain verifiers: SC-3 SHA-bearing
  path (fixture upstream owns 14 seeded commits past INITIAL_SHA;
  asserts `commits_behind=14`) and SC-3b pre-M035 fallback path
  (asserts `commits_behind=unknown` + one stderr advisory).
  Verifier-owned fixture upstream pattern (mktemp -d + git init +
  N seeded commits + rewrite consumer commit_sha to INITIAL_SHA) makes
  the assertion deterministic without depending on the live repo HEAD.
  CHANGELOG awk pattern restricted to `^## \[[0-9]` to skip past
  `## [Unreleased]` heading; inline awk semver-delta avoids authoring
  a separate `lib/semver-delta.sh` per the payload's budget-saving
  endorsement.

- **T04** (drift line in status). Wired the drift surface into both
  status render paths: TUI side documented as a render rule in
  `commands/status.md`; JSON side emits a top-level `drift` object
  via two new helpers in `scripts/diagnostics/render-status-json.sh`
  (`_rsj_collect_drift_block` parses the helper's four-line stdout via
  grep+sed; `_rsj_drift_rendered_line` formats the human line). The
  drift `_M029_SCHEMA_VERSION` stays at `"1.0"` per AD-7 stability
  policy — the inline comment in the renderer captures intent — and
  M029 SC-3 acceptance battery re-runs 26/26 green to confirm. The
  drift object key set is STABLE across availability states (deviation
  from the M029 sections-side suppression-by-omission convention,
  reasoned: downstream consumers need stable shape regardless of
  helper availability). Authored `tools/verify/m035-p01-drift-line-in-status.sh`
  (SC-4 primary path), `tools/verify/m035-p01-drift-line-suppressed.sh`
  (SC-4 three suppression sub-cases), and the AD-19-prefixed P01
  phase-suite aggregator `tools/verify/m035-p01-phase-suite.sh`.

Verification: phase-suite battery `pass=7 fail=0` on all 7 task-grain
verifiers. Lock held throughout; no blockers, budget under at 4 tasks /
~185m duration. The 28 "external modification" warnings reported by
`phase-transition.sh` are the genuine T01–T04 implementation diffs
(installer modifications, references doc additions, new verifiers, new
helpers, T01–T04 SUMMARY.md and PLAN.md files) — not actual external
edits. Roadmap sync: SYNC:OK.

P02 (M035 launch event — npm + homebrew + curl-pipe-bash publishing
pipelines) inherits: an installer trio that takes `--mode=copy|symlink`,
emits 5-line `install-meta.txt` (with `commit_sha=` + `version=`), and
uninstalls correctly under both modes; a read-only drift helper that
already does the work the publish-pipeline first-user UX needs; and a
status-line drift surface that surfaces `Orchestrator drift: N commits /
M versions behind via <source>` to operators the moment a consumer
falls behind a published release.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01.5"
milestone: "M035"
name: "C9 — git mv specs/001-speckit-orchestrator → specs/001-orchestrator + content reference sweep"
depends_on: ["T01"]
---

## Prerequisites

Files that MUST exist on disk at task entry:

- `specs/001-speckit-orchestrator/` directory (current spec dir for
  the original orchestrator feature; verified at plan-authoring time
  via direct ls — contains `spec.md`, `plan.md`, `tasks.md`,
  `data-model.md`, `quickstart.md`, `research.md`, `checklists/`,
  `contracts/`, `conversus-plan/`, `conversus-spec/`).
- `tests/m035-acceptance/legacy-namespace-allowlist.txt` (authored by
  T01) — used by T08 verifiers; not directly consumed by T02 but its
  existence confirms T01 is complete.
- The 27 files referencing `specs/001-speckit-orchestrator/` per
  the 2026-05-08 inventory grep (CLAUDE.md, references/file-formats.md,
  M035-ROADMAP.md, M008/archive payloads/plans, fixtures, RENAME-PLAN.md
  itself, and content inside `specs/001-speckit-orchestrator/` files).

Pre-existing decisions consumed:

- [D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }") = `@build-fractal/orchestrator` (T01 D0XX block; informs the
  spec-dir basename — `001-orchestrator` matches the npm package's
  unscoped name).
- RENAME-PLAN.md § 5 Commit 1 (Filename moves) and Commit 6 (spec dir
  content references) — this task executes those two commits as one
  surface (both touch the same path, no benefit from splitting).

## Description

Execute RENAME-PLAN.md § 5 Commit 1 + Commit 6 as one task surface:
`git mv` the spec directory from `specs/001-speckit-orchestrator` to
`specs/001-orchestrator`, then sweep every in-tree content reference
to the old path and rewrite to the new path. Includes references both
inside the renamed directory itself (self-references in spec.md /
plan.md / tasks.md / data-model.md / contracts/state-files.md /
conversus-spec/* / conversus-plan/*) and outside (CLAUDE.md,
references/file-formats.md, M035-ROADMAP.md, M008/archive, test fixtures).

The historical/migration files (RENAME-PLAN.md, archived [M008](../../../../../milestones/M008/index.md)
payloads, etc.) are NOT in the C9 path-rewrite scope — RENAME-PLAN.md's
own self-reference is documentation, and archived-milestone files
preserve audit trail. The verifier in step 6 enforces this distinction.

## Steps

1. **Run `git mv` for the spec directory**:

   ```bash
   git mv specs/001-speckit-orchestrator specs/001-orchestrator
   ```

   Verify with `git status` that the move is staged as a rename
   (single-letter `R` in the porcelain, not `D`/`A` pair). `git log
   --follow specs/001-orchestrator/spec.md` should return the
   pre-rename commit history.

2. **Sweep in-tree content references** to the old path. The C9 surface
   touches these files (per the 2026-05-08 inventory):

   - `CLAUDE.md` — line 88 `specs/001-speckit-orchestrator/spec.md` →
     `specs/001-orchestrator/spec.md`.
   - `references/file-formats.md` — line 55
     `feature_spec: "specs/001-speckit-orchestrator/spec.md"` →
     `feature_spec: "specs/001-orchestrator/spec.md"`.
   - `tests/fixtures/roadmap-sample.md`,
     `tests/fixtures/state-completing/M001-ROADMAP.md`,
     `tests/fixtures/state-replanning/M001-ROADMAP.md`,
     `tests/fixtures/state-verifying/M001-ROADMAP.md`,
     `tests/fixtures/state-summarizing/M001-ROADMAP.md`,
     `tests/fixtures/state-complete/M001-ROADMAP.md`,
     `tests/fixtures/state-executing/M001-ROADMAP.md`,
     `tests/fixtures/state-validating/M001-ROADMAP.md` — each contains
     a content reference to `specs/001-speckit-orchestrator/`. Rewrite
     to `specs/001-orchestrator/`.
   - [`.orchestrator/milestones/M035/M035-ROADMAP.md`](../../../../../milestones/M035/M035-ROADMAP.md) — line 29
     references the old path inside the demo sentence narrative
     describing what P01.5 produces. The narrative should describe
     "the rename FROM `specs/001-speckit-orchestrator/` TO
     `specs/001-orchestrator/`" — preserve both forms in the prose
     (it documents the rename itself), no edit required.
   - Self-references inside `specs/001-orchestrator/` (formerly
     `…/001-speckit-orchestrator/`) — `plan.md`, `tasks.md`,
     `data-model.md`, `contracts/state-files.md`, `conversus-spec/*.md`,
     `conversus-plan/*.md` — each may carry the old path in
     descriptive prose. Update to `specs/001-orchestrator/`.

3. **PRESERVE references in archived/historical files**. Do NOT edit:

   - [`.orchestrator/milestones/M008/archive/P05/T06-PAYLOAD.md`](../../../../../milestones/M008/archive/P05/T06-PAYLOAD.md),
     [`.orchestrator/milestones/M008/archive/P05/T06-PLAN.md`](../../../../../milestones/M008/archive/P05/T06-PLAN.md) — archived
     milestone artifacts. The path reference in those files documents
     historical state at the time the milestone was authored. Survives
     under the M0XX-archived-milestone allowlist convention (preserved
     at the M035 closure level via `references/RENAME-PLAN.md` § 6
     allowlist; not in the SC-7 allowlist scope but in the C1 sweep
     allowlist scope at T04).
   - `references/RENAME-PLAN.md` — the runbook itself documents the
     rename and explicitly references the OLD path. Preserved.
   - `.planning/speckit-orchestrator-playbook.md` — operator
     personal-state planning doc; not in C9 scope, will be addressed
     at T03 (path rename) or T04 (basename rename) per its content.

4. **Use single-script-file shape for the sweep**. Author a one-shot
   helper at task execution time (not committed to the repo —
   `mktemp -d` workspace) that:
   - Reads a hardcoded list of the files in step 2.
   - For each file, runs `sed -i '' 's|specs/001-speckit-orchestrator|specs/001-orchestrator|g' <file>`
     (BSD sed; CON-2 bash 3.2 compatibility honored).
   - Verifies with `grep -nE 'specs/001-speckit-orchestrator' <file>`
     returning empty after each edit.

   The helper is one-shot because the file list is finite and known;
   no need for a persistent script. The dispatched agent emits the
   sed commands as separate edits per AD-19 — one Edit tool call per
   file, NOT a compound `git ls-files | xargs sed` chain.

5. **Verify zero residual references in non-allowlisted files**:

   ```bash
   git grep -nE 'specs/001-speckit-orchestrator' \
     | grep -vE '^(references/RENAME-PLAN.md|\.orchestrator/milestones/M008/archive/|\.orchestrator/milestones/M035/M035-ROADMAP\.md|\.orchestrator/milestones/M035/phases/P01\.5/P01\.5-PLANNING-PAYLOAD\.md|\.planning/speckit-orchestrator-playbook\.md):'
   ```

   Expected output: empty. The exclusion list captures (a) the
   historical/runbook surfaces, (b) M035 P01.5's own planning artifacts
   (which document the rename narratively).

6. **Author `tools/verify/m035-p015-spec-dir-rename.sh`**. Verifier
   asserts:
   - `specs/001-orchestrator/` exists as a directory.
   - `specs/001-speckit-orchestrator/` does NOT exist.
   - `specs/001-orchestrator/spec.md` exists (sentinel file from the
     renamed directory).
   - `git log --follow specs/001-orchestrator/spec.md | head -n 1`
     returns a commit hash (history preservation check).
   - The five non-historical content-reference targets named in step 2
     (CLAUDE.md, references/file-formats.md, the 8 fixture files) all
     contain `specs/001-orchestrator/` and zero matches for
     `specs/001-speckit-orchestrator/`.

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p015-spec-dir-rename.sh
   set -u
   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   fail=0
   if [ ! -d "$REPO_ROOT/specs/001-orchestrator" ]; then
     echo "FAIL: specs/001-orchestrator/ does not exist" >&2
     fail=1
   fi
   if [ -d "$REPO_ROOT/specs/001-speckit-orchestrator" ]; then
     echo "FAIL: specs/001-speckit-orchestrator/ still exists (should be gone)" >&2
     fail=1
   fi
   if [ ! -f "$REPO_ROOT/specs/001-orchestrator/spec.md" ]; then
     echo "FAIL: specs/001-orchestrator/spec.md missing" >&2
     fail=1
   fi
   for f in \
     "CLAUDE.md" \
     "references/file-formats.md" \
     "tests/fixtures/roadmap-sample.md"; do
     full="$REPO_ROOT/$f"
     if grep -qE 'specs/001-speckit-orchestrator' "$full"; then
       echo "FAIL: $f still references specs/001-speckit-orchestrator" >&2
       fail=1
     fi
   done
   if [ "$fail" -eq 0 ]; then
     echo "PASS: m035-p015-spec-dir-rename"
     exit 0
   fi
   exit 1
   ```

## Must-Haves

- `specs/001-orchestrator/` exists; `specs/001-speckit-orchestrator/` gone
  - Check: `bash tools/verify/m035-p015-spec-dir-rename.sh`

## Verification

```bash
bash tools/verify/m035-p015-spec-dir-rename.sh
```

## Inputs

### From Previous Tasks

- T01: [D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }")..[D-RN-7](../../../../../decisions.md#d-rn-7-pre-rename-version-tag-v09x-final-spec-kit-name-dr-code-035 "Pre-rename version tag `v0.9.X-final-spec-kit-name` { #dr-code-035 }") decision block exists in [`.orchestrator/DECISIONS.md`](../../../../../decisions.md);
  legacy-namespace allowlist file exists; pre-rename tag in local refs.

### From Disk (Pre-existing)

- `specs/001-speckit-orchestrator/` — the directory to rename.
- The 11+ files referencing the old path per the 2026-05-08 inventory.
- `references/RENAME-PLAN.md` § 5 Commit 1 + Commit 6 — runbook source.

## Constraints

- **CON-3 (AP-009-shape-guard-honored)**: no compound `git ls-files |
  xargs sed` chains. Each file edited as a separate Edit tool call.
- **AD-19 (single-script-file Check shape)**: the verifier is one
  script file; no compound test patterns.
- **Git history preservation**: use `git mv` (not `mv` + `git rm` +
  `git add`) so `git log --follow` traces history through the rename.
- **Reversibility**: `git revert <T02-commit-sha>` reverses both the
  rename and the content sweep in a single commit.

## Notes

- **Why the spec dir basename is `001-orchestrator` not
  `039-packaging-distribution`**: the existing dir name encodes the
  feature index; `001-` is the index for the original orchestrator
  feature (the foundational spec under M001 — see `specs/`). Renaming
  the basename to `001-orchestrator` preserves the index while updating
  the slug. This matches the RENAME-PLAN.md § 3 C9 mapping exactly.
- **Plan-phase verifier-availability cross-check (rule 2)**: T02
  authors `m035-p015-spec-dir-rename.sh` in step 6.
- **Plan-phase classifier-shape pre-validation (rule 3)**: pure grep
  shape; no classifier.
- **Plan-phase real-DB rule (rule 5)**: not applicable.

## Expected Output

After T02 completes:

- `specs/001-orchestrator/` exists with all the files from
  `specs/001-speckit-orchestrator/` (history preserved via `git mv`).
- `specs/001-speckit-orchestrator/` no longer exists on disk.
- 11+ non-historical files have their content references rewritten
  to `specs/001-orchestrator/`.
- One verifier script exists under `tools/verify/`.

## State Context

- **Current State**: executing
- **Milestone**: M035
- **Phase**: P01.5
- **Task**: T02-spec-dir-rename
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **CON-3 (AP-009-shape-guard-honored)**: no compound `git ls-files |
  xargs sed` chains. Each file edited as a separate Edit tool call.
- **AD-19 (single-script-file Check shape)**: the verifier is one
  script file; no compound test patterns.
- **Git history preservation**: use `git mv` (not `mv` + `git rm` +
  `git add`) so `git log --follow` traces history through the rename.
- **Reversibility**: `git revert <T02-commit-sha>` reverses both the
  rename and the content sweep in a single commit.

### Acceptance Criteria

- `specs/001-orchestrator/` exists; `specs/001-speckit-orchestrator/` gone
  - Check: `bash tools/verify/m035-p015-spec-dir-rename.sh`

### Files To Touch

In-tree edits (autonomous-executable):

- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) (modify — append [D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }")..[D-RN-7](../../../../../decisions.md#d-rn-7-pre-rename-version-tag-v09x-final-spec-kit-name-dr-code-035 "Pre-rename version tag `v0.9.X-final-spec-kit-name` { #dr-code-035 }") block) — T01
- `tests/m035-acceptance/legacy-namespace-allowlist.txt` (create) — T01
- `specs/001-speckit-orchestrator/` → `specs/001-orchestrator/` (`git mv`) — T02
- `CLAUDE.md` (modify — `specs/001-speckit-orchestrator/spec.md` →
  `specs/001-orchestrator/spec.md` + `spec-kit-orchestrator project`
  reference rewrite) — T02 + T04
- `references/file-formats.md` (modify — `feature_spec:` example path) — T02
- `tests/fixtures/state-*/M001-ROADMAP.md` (modify — content references
  to `specs/001-speckit-orchestrator/`) — T02
- `tests/fixtures/roadmap-sample.md` (modify — same) — T02
- [`.orchestrator/milestones/M008/archive/P05/T06-PAYLOAD.md`](../../../../../milestones/M008/archive/P05/T06-PAYLOAD.md),
  [`.orchestrator/milestones/M008/archive/P05/T06-PLAN.md`](../../../../../milestones/M008/archive/P05/T06-PLAN.md) (modify —
  archived references; verify these are NOT load-bearing for any
  current verifier before editing) — T02
- `references/installation.md` (modify — operator-environment recipes) — T03
- `.planning/speckit-orchestrator-playbook.md` (rename basename + content) — T03/T04
- `*.md`, `*.yml`, `*.yaml` files outside the allowlist (modify — C1
  lowercase-hyphenated sweep) — T04
- `*.md` files outside the allowlist (modify — C2 + C3 prose sweep) — T05
- `templates/claude-settings.json` (modify — line 56
  `Skill(speckit.orchestrator.*)` → `Skill(orchestrator:*)`,
  line 64 `Bash(bash spec-kit-orchestrator/scripts/*)` →
  `Bash(bash orchestrator/scripts/*)`) — T06
- `templates/autonomy-defaults.yaml` (modify — line 91
  `Skill(speckit.orchestrator.*)` → `Skill(orchestrator:*)`) — T06
- `templates/instruction-schema.md` (modify — line 140 reframe legacy
  reference) — T06
- `templates/compression-tier3-prompt.md` (modify — lines 14, 45 reframe
  legacy reference) — T06
- `.orchestrator/milestones/M035/phases/P01.5/c4-classification.txt`
  (create — T07 output log)
- `tools/verify/m035-p015-allowlist-shape.sh` (create) — T01
- `tools/verify/m035-p015-decisions-block.sh` (create) — T01
- `tools/verify/m035-p015-pre-rename-tag.sh` (create) — T01
- `tools/verify/m035-p015-spec-dir-rename.sh` (create) — T02
- `tools/verify/m035-p015-operator-paths.sh` (create) — T03
- `tools/verify/m035-p015-c1-sweep.sh` (create) — T04
- `tools/verify/m035-p015-c2-c3-prose.sh` (create) — T05
- `tools/verify/m035-p015-c5-cohort-finish.sh` (create) — T06
- `tools/verify/m035-p015-c4-classification.sh` (create) — T07
- `tools/verify/m035-p015-sc7.sh` (create) — T08
- `tools/verify/m035-p015-sc7b.sh` (create) — T08
- `tools/verify/m035-p015-phase-suite.sh` (create) — T08

Off-tree operator steps (NOT autonomous-executable; surfaced as PAUSE
conditions in task plans):

- Pre-rename git tag `v0.9.X-final-spec-kit-name` — T01 (operator
  runs `git tag` locally; auto loop may emit via dispatch but
  reversibility via `git tag -d` is documented)
- GitHub remote rename `Build-Fractal/spec-kit-orchestrator` →
  `Build-Fractal/orchestrator` — T08 runbook (operator web-UI)
- Local working-dir rename `~/Sites/spec-kit-orchestrator` →
  `~/Sites/orchestrator` + `git remote set-url` — T08 runbook
- Claude memory project-key migration — T08 runbook

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