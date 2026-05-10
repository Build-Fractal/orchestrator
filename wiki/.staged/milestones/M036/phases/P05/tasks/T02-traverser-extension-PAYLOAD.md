---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T02-traverser-extension (Phase P05, Milestone M036)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~300 | required |
| Upstream Context | 981-1039 | ~2500 | required |
| Task Plan | 1041-1167 | ~2600 | required |
| State Context | 1169-1175 | ~100 | required |
| First-Turn Completeness | 1177-1212 | ~700 | required |
| **Total** | | **~17000** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 721
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
hit_count: 721
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
hit_count: 721
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
hit_count: 721
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
hit_count: 630
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
hit_count: 630
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
hit_count: 630
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
hit_count: 721
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
hit_count: 630
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
hit_count: 630
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
hit_count: 630
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
hit_count: 721
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
hit_count: 721
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
hit_count: 721
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
hit_count: 630
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
hit_count: 630
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
hit_count: 630
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
hit_count: 721
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
hit_count: 630
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
hit_count: 630
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
hit_count: 721
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
hit_count: 721
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
hit_count: 630
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
hit_count: 630
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
hit_count: 630
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
hit_count: 285
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
hit_count: 285
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
hit_count: 285
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
hit_count: 297
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
hit_count: 297
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
hit_count: 287
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

- Graph DB schema accepts `cites` / `derived_from` / `applies_to_field` edge inserts without CHECK violation
  - Check: `bash tools/verify/m036-p05-edges-schema-accepts-new.sh`

- Pre-existing `relates_to` and `supersedes` edge inserts continue to succeed
  - Check: `bash tools/verify/m036-p05-edges-schema-accepts-old.sh`

- `rebuild-index.sh` populates edges from `cites` / `derived_from` / `applies_to_field` frontmatter
  - Check: `bash tools/verify/m036-p05-rebuild-emits-new-edges.sh`

- `traverse-graph.sh` walks `cites` edges and emits the edge label in `--ranked` / labeled output
  - Check: `bash tools/verify/m036-p05-traverse-cites.sh`

- `traverse-graph.sh` default invocation (no `--edge-types` flag) is byte-identical to pre-P05 for a relates_to fixture (CON-5 regression guard)
  - Check: `bash tools/verify/m036-p05-traverse-relates-to-baseline.sh`

- `scope-filter.sh` accepts `--tag '[source:<cite_id>]'` and returns chunks bearing that tag

<dispatch-volatile>

## Upstream Context


### P00 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P00"
parent: "M036"
milestone: "M036"
provides:
  - "taxonomy SSOT (4 categories),frontmatter contract (FR-2/FR-4/FR-5 fields),per-category default-tier YAML,3 shape verifiers under tools/verify/,edge-type SSOT (5 edges: cites/derived_from/applies_to_field new + relates_to/supersedes pre-existing),adapter registry TSV seam (4 stub rows: markdown/pdf/docx/xlsx),2 shape verifiers under tools/verify/,scope-tag namespace extension (source:cite_id row appended to file-formats.md Scope Tags + cross-reference paragraph in spec-management.md),chunk-frontmatter validator library (tools/verify/lib/p00-validate-chunk-frontmatter.sh — rejects out-of-taxonomy categories and out-of-tier-enum values),3 new verifiers + the 8-gate phase-suite aggregator under tools/verify/"
requires:
  - "none"
affects:
  - "P01,P02,P05"
key_files:
  - "references/reference-taxonomy.md,references/reference-frontmatter-contract.md,references/reference-source-types.yaml,tools/verify/p00-taxonomy-shape.sh,tools/verify/p00-frontmatter-contract-shape.sh,tools/verify/p00-source-types-shape.sh,references/reference-edge-types.md,scripts/dispatch/adapters/format/registry.tsv,tools/verify/p00-edge-types-shape.sh,tools/verify/p00-adapter-registry-shape.sh,references/file-formats.md,references/spec-management.md,tools/verify/lib/p00-validate-chunk-frontmatter.sh,tools/verify/p00-scope-tag-extension.sh,tools/verify/p00-spec-management-crossref.sh,tools/verify/p00-taxonomy-rejects-unknown.sh,tools/verify/m036-p00-phase-suite.sh"
key_decisions:
  - "none"
patterns_established:
  - "grep -qF token-loop shape verifier (single-script-file AD-19 shape); SSOT lockstep between reference-taxonomy.md keys and reference-source-types.yaml source_types: keys (Principle XI),runtime-constructed TAB via printf '\t' for tab-anchored grep patterns (resilient against editor space-conversion of verifier file itself); registry-row status=stub at declaration phase,status=live flip deferred to adapter-implementation phase (P01); SSOT lockstep between reference-edge-types.md heading list and reference-frontmatter-contract.md graph-edge field declarations (Principle XI),dual-write SSOT bridge (file-formats.md is the real scope-tag SSOT; spec-management.md cross-references it per roadmap directive without forking); validator-internal pipeline classifier-shape pass-through (grep-pipe-head-pipe-sed inside script body never surfaces to the harness shape-classifier because classify_command inspects only invocation form — single-script-file invocation classifies clean); phase-suite aggregator slot reuse (tools/verify/m036-p00-phase-suite.sh path was previously M031s; [M031](../../../../../milestones/M031/index.md) closed,M036 now owns the meta-aggregator slot while M031s individual sub-gates remain on disk under their slugged names); negative-test driver pattern (3 fixtures written to mktemp -d,validator invoked with each as path argument — avoids heredoc-feeding-pipe shapes AD-19 forbids)"
drill_down_paths:
  - "[.orchestrator/milestones/M036/phases/P00/tasks/T01-taxonomy-and-contract-SUMMARY.md](../../../../../milestones/M036/phases/P00/tasks/T01-taxonomy-and-contract-SUMMARY.md), [.orchestrator/milestones/M036/phases/P00/tasks/T02-edge-types-and-registry-SUMMARY.md](../../../../../milestones/M036/phases/P00/tasks/T02-edge-types-and-registry-SUMMARY.md), [.orchestrator/milestones/M036/phases/P00/tasks/T03-scope-tag-and-validator-SUMMARY.md](../../../../../milestones/M036/phases/P00/tasks/T03-scope-tag-and-validator-SUMMARY.md)"
duration: "70m"
verification_result: "pass"
completed_at: "2026-05-02T02:21:28Z"
observability_surfaces:
  - "none"
---

P00 (Foundation) lands the M036 reference-corpus declarative substrate as five SSOT artifacts plus the additive `[source:<cite_id>]` scope-tag namespace, plus a 9-verifier shape-check suite gated by `tools/verify/m036-p00-phase-suite.sh` (8 sub-gates wired through the aggregator + 1 negative-test driver). All artifacts ship as plain markdown / YAML / TSV — no executable scripts in P00's product surface beyond the verifiers themselves; the four format-adapter scripts the registry seam declares are P01 deliverables.

**What was built (across T01 + T02 + T03)**:

- T01 — Taxonomy + frontmatter contract + source-types tier-policy. `references/reference-taxonomy.md` declares the four categories (cms-rule, training-material, glossary, regulatory-doc) at level-3 headings with one-line definitions and example `cite_id` slugs. `references/reference-frontmatter-contract.md` enumerates required FR-2 fields, FR-4 chunk-output additions, and the five graph-edge-bearing fields (3 new in M036 + 2 pre-existing). `references/reference-source-types.yaml` carries the per-category default-tier policy (`cms-rule: 2`, `training-material: 2`, `glossary: 2`, `regulatory-doc: 1`) per spec #Q-8. Three single-script-file shape verifiers landed under `tools/verify/`.

- T02 — Edge-type SSOT + adapter registry seam. `references/reference-edge-types.md` is a NEW SSOT file declaring all five graph edges (3 new: `cites`, `derived_from`, `applies_to_field`; 2 pre-existing cross-referenced for completeness: `relates_to`, `supersedes`). The traverser at `scripts/knowledge/traverse-graph.sh` was deliberately NOT modified — refactoring it to read from this SSOT is P05's contract, scope-discipline-separated. `scripts/dispatch/adapters/format/registry.tsv` declares the adapter seam with all four format rows (markdown, pdf, docx, xlsx) at `status=stub`; P01 flips them to `status=live` when the adapter scripts land.

- T03 — Scope-tag namespace + chunk-frontmatter validator + phase-suite aggregator. Dual-write SSOT bridge: the `[source:<cite_id>]` row was appended to the actual SSOT (`references/file-formats.md` Scope Tags table) and a cross-reference paragraph was appended to `references/spec-management.md` (the roadmap's literal target) — Principle XI is honored without forking the SSOT. `tools/verify/lib/p00-validate-chunk-frontmatter.sh` is the load-bearing harness that mechanically rejects out-of-taxonomy categories and out-of-{0,1,2} tiers; the negative-test driver `tools/verify/p00-taxonomy-rejects-unknown.sh` exercises three fixtures (blog-post category rejected, tier 5 rejected, cms-rule + tier 2 accepted). The phase-suite aggregator (renamed mid-phase — see Forward Note below) wires all 8 sub-gates.

**Mid-phase orchestrator-layer correction (filename collision discovered + fixed)**: T03's planning called for the phase-suite aggregator at `tools/verify/p00-phase-suite.sh`. That path was already occupied by M031's P00 phase-suite (which itself had silently overwritten [M030](../../../../../milestones/M030/index.md)'s earlier). T03 honored the plan literally and overwrote M031's, then surfaced the collision as DONE_WITH_CONCERNS at task close. Mid-session correction:

1. Restored M031's content as `tools/verify/m031-p00-phase-suite.sh` (NEW file, recovered from git commit 428650d). M030's was lost weeks earlier and is not recoverable from git history at as-of-M030 state — separate paper-cut.
2. Renamed M036's aggregator to `tools/verify/m036-p00-phase-suite.sh` and updated its docstring + self-referencing SUMMARY line.
3. Updated T03 PLAN, T03 SUMMARY, and P00 PLAN references.
4. Tightened the planner contract in `commands/plan-phase.md`: (a) the verifier-naming discriminator example now uses a milestone-prefixed slug `m036-p01-foundation-bundle.sh` instead of the phase-only `p01-foundation-bundle.sh`; (b) a new "Naming convention — milestone slug REQUIRED for per-phase verifiers" rule prohibits unprefixed `p##-*` slugs going forward; (c) a new Plan-Time Discipline rule 6 (Path-collision check) requires planners to `ls -la` every declared `create` path before authoring and STOP if it already exists.

The contract change prevents this collision class going forward; the immediate damage to M031 is repaired. Other M036 P00 verifiers (the 7 sub-gate shape verifiers under unprefixed `p00-*` slugs) were left in place — their slugs are M036-unique by content and don't currently collide with anything; future-milestone hygiene will ratchet via the new contract rule.

**Verification result**: PASS at every gate. `tools/verify/m036-p00-phase-suite.sh` exits 0 with `SUMMARY: m036-p00-phase-suite.sh pass=8 fail=0`. Tier 1 must-haves (`scripts/verify/check-must-haves.sh`) all PASS — 9 truths, 17 artifact existence checks, 11 line-count checks, 18 artifact-content pattern checks, 7 key-link checks, all green after one mid-phase plan-pattern correction (`[source:` → `source:<cite_id>` to match the `references/file-formats.md` table-cell convention; two spurious spec→artifact key-links removed since the spec predates the artifacts).

**Forward-pointing notes**:
- (a) M030's `p00-phase-suite.sh` content was lost weeks before today's session when M031 silently overwrote it. The M030 README at `tests/fixtures/m030-classifier-corpus/README.md:167,189` still references the file under its original name. This is a stale reference but causes no live failure (M030 is closed; nothing re-runs that aggregator). Recommended cleanup: restore M030's content from its as-of-closure commit OR rename the M030 README references to `m030-p00-phase-suite.sh` even if the file content can't be recovered. Folds into the post-launch `tools/verify/` namespace cleanup proposal.
- (b) The other 7 unprefixed M036 P00 verifiers (`p00-taxonomy-shape.sh` etc.) are M036-content-unique today but live under a fragile namespace. Future milestones authoring under the new "milestone slug REQUIRED" rule won't add to the unprefixed bucket; a one-shot retroactive rename to `m036-p00-*` is queued as a small-batch follow-up.
- (c) The plan-time path-collision check (rule 6) is text-only at this point; a lint script that mechanically flags collisions in plan deliverables is a candidate for `scripts/diagnostics/check-plans.sh` extension.

P00 closes; P01 (Tier 1 live format adapters: pdf, docx, xlsx, markdown) and P05 (graph schema extension consuming `references/reference-edge-types.md`) are now dispatchable.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P05"
milestone: "M036"
name: "Traverser extension (traverse-graph.sh recognizes new edge types)"
depends_on: ["T01"]
---

## Prerequisites

- T01 has shipped the schema + indexer extension. The `edges` table CHECK enum accepts the 5-element edge-type set; `rebuild-index.sh` populates the new edges from frontmatter.
- `references/reference-edge-types.md` exists and is the SSOT for edge directionality. Verified at plan-authoring time.
- `scripts/knowledge/traverse-graph.sh` exists. The recursive CTE at lines ~260-285 hardcodes `edge_type = 'relates_to'` in three places (forward branch, reverse branch, recursive descent).

## Description

Extend `scripts/knowledge/traverse-graph.sh` to walk the three new edge types additively, while preserving byte-identical default behavior for invocations that don't request the extension (CON-5).

Two design decisions, anchored in the P00 SSOT directionality declarations:

1. **Default behavior is unchanged.** Without `--edge-types`, the CTE walks `relates_to` (bidirectional) exactly as today. The `--provenance` mode walks `supersedes` exactly as today.

2. **Opt-in extension via `--edge-types <comma-list>`.** When the flag is present, the CTE walks the specified edges. Directionality follows the SSOT:
   - `relates_to` — bidirectional (existing semantics).
   - `supersedes` — directional (newer → older).
   - `cites` — directional (citer → cited).
   - `derived_from` — directional (downstream → upstream).
   - `applies_to_field` — directional (chunk → field-name).

   Directional edges walk only the forward direction by default. A separate `--reverse` flag walks targets-first (needed for the SSOT acceptance scenario "BFS runs from the cms-rule chunk in reverse, training chunk reachable via derived_from").

3. **Edge label in output.** When walking typed edges (anything other than the default `relates_to`-only mode), each result line is suffixed with `|<edge_type>` so consumers (and the SC-4 test) can grep the label. Default-mode output is unchanged (CON-5 baseline).

The fixture-driven Truth Check that drives this (boundary map demo): `bash scripts/knowledge/traverse-graph.sh --id SPEC-requirement-FR-7 --edge-types cites --max-depth 1` returns `REF-cms-rule-§483-20|cites` on stdout.

## Steps

1. **Add argument parsing** for `--edge-types <comma-list>` and `--reverse` to the existing `while [ $# -gt 0 ]` block (lines 30-57). Default `edge_types=""` (sentinel for "use legacy relates_to-only path"). Default `reverse=false`.

2. **Branch the CTE construction.** When `edge_types` is empty, leave the existing CTE at lines 260-285 unchanged (CON-5 byte-equality). When non-empty:
   - Parse the comma-list into a SQL `IN` clause: `edge_type IN ('cites', 'derived_from', ...)`. Escape each token via `sed "s/'/''/g"` for safety (matches the existing `safe_id` pattern at line 74).
   - Build a CTE that walks only forward direction by default; add reverse direction when `--reverse` is set. The forward CTE shape mirrors the existing one but with the typed-edge `IN` clause and without the second `UNION` branch (since most new types are directional):
     ```sql
     WITH RECURSIVE reachable(id, edge_type, depth) AS (
       SELECT target_id, edge_type, 1 FROM edges
         WHERE source_id = '${safe_id}' AND edge_type IN (${types_clause})
       UNION ALL
       SELECT e2.target_id, e2.edge_type, r.depth + 1
         FROM edges e2 JOIN reachable r ON e2.source_id = r.id
         WHERE r.depth < ${max_depth} AND e2.edge_type IN (${types_clause})
           AND e2.target_id != '${safe_id}'
     )
     SELECT e.id || '|' || r.edge_type
     FROM entries e JOIN reachable r ON e.id = r.id
     WHERE e.id != '${safe_id}'
     GROUP BY e.id, r.edge_type
     LIMIT ${max_entries};
     ```
   - When `--reverse` is set, swap `source_id`/`target_id` in the WHERE clauses (BFS walks from the target backward).
   - When `--ranked` AND `--edge-types` are both present, render the existing ranked output PLUS the edge-type suffix: `e.id || '|' || e.confidence || '|' || MIN(r.depth) || '|' || printf('%.6f', e.confidence * (1.0 / MIN(r.depth))) || '|' || r.edge_type`.

3. **applies_to_field special case.** The `target_id` of an `applies_to_field` edge is a field-name string (e.g., `staff_count`), not a chunk ID. The current CTE joins `edges r` to `entries e ON e.id = r.id`, which would silently drop applies_to_field edges (no entry row exists for `staff_count`). To preserve the demo behavior, when `applies_to_field` is in the edge-types list, replace the inner `JOIN entries` with a `LEFT JOIN entries` and emit the `target_id` directly with a `|<field-name>|applies_to_field` shape when the join misses. Add a short comment block at the join site explaining the asymmetry, citing `references/reference-edge-types.md` directionality table.

4. **Author `tools/verify/m036-p05-traverse-cites.sh`** — single-script-file verifier. Stages a mktemp `knowledge/` tree under `PROJECT_ROOT=$tmpdir`; writes a fixture spec chunk (`SPEC-FR-7.md` with `cites: [REF-cms-rule-483-20]`) and a fixture reference chunk (`REF-cms-rule-483-20.md` with no outgoing edges); runs `bash scripts/knowledge/rebuild-index.sh` to build the staged DB; runs `bash scripts/knowledge/traverse-graph.sh --id SPEC-FR-7 --edge-types cites --max-depth 1`; asserts stdout contains the literal substring `REF-cms-rule-483-20|cites`.

5. **Author `tools/verify/m036-p05-traverse-relates-to-baseline.sh`** — CON-5 regression guard. Stages a fixture corpus under `PROJECT_ROOT=$tmpdir` containing only pre-P05 edge fields (`relates_to: [MEM002]`, `supersedes: ""`); rebuilds the index; runs `bash scripts/knowledge/traverse-graph.sh --id MEM001` (default mode, no `--edge-types`); diffs the output against a checked-in baseline file at `tests/fixtures/m036-p05-baseline/traverse-relates-to.expected.txt`. Any diff exits 1 with a `FAIL: CON-5 regression` message naming the differing line.

   The fixture corpus and baseline file are co-authored by this task (under `tests/fixtures/m036-p05-baseline/`). Two MEM entries (`MEM001`, `MEM002`) with `relates_to: [MEM002]` on MEM001. Baseline file content is whatever `traverse-graph.sh` emits today for that input — captured by running the unmodified traverser once before T02's edits and saving its stdout verbatim.

   Critical sequencing: capture the baseline BEFORE editing `traverse-graph.sh`. The verifier's contract is "post-edit output equals pre-edit output for default-mode invocations." Baseline-after-edit defeats the guard.

## Must-Haves

Truths from the phase plan addressed by this task:

- "`traverse-graph.sh` walks `cites` edges and emits the edge label in `--ranked` / labeled output" — covered by step 4.
- "`traverse-graph.sh` default invocation (no `--edge-types` flag) is byte-identical to pre-P05 for a relates_to fixture (CON-5 regression guard)" — covered by step 5.

## Verification

```bash
bash tools/verify/m036-p05-traverse-cites.sh
```

```bash
bash tools/verify/m036-p05-traverse-relates-to-baseline.sh
```

## Inputs

### From Previous Tasks

- `scripts/knowledge/lib/graph-db.sh` (modified by T01) — Key API: `db_init`, `db_insert_edge` accept the widened CHECK enum.
- `scripts/knowledge/rebuild-index.sh` (modified by T01) — emits `cites`/`derived_from`/`applies_to_field` edges into the staged DB on rebuild.

### From Disk (Pre-existing)

- `scripts/knowledge/traverse-graph.sh` — the file to modify. Key behavior:
  - `--id <entry>` is required.
  - `--max-depth` / `--hops` set CTE depth (default 1).
  - `--max-entries` truncates results (default 5).
  - `--ranked` switches output to `id|confidence|depth|score`.
  - `--provenance` walks supersedes chain (untouched by T02).
  - Default output is one related ID per line.
  - Returns exit 0 always (no related entries is valid).
- `references/reference-edge-types.md` — SSOT for directionality decisions. Each new edge's directionality is declared in its `Directionality:` field.
- `scripts/knowledge/lib/graph-db.sh` — `db_query(db_path, sql)` wraps `sqlite3` with heredoc input.

## Constraints

- **CON-5 byte-equality for default mode** — no `--edge-types` flag means no behavior change. The verifier `m036-p05-traverse-relates-to-baseline.sh` enforces this mechanically. The CTE construction MUST remain in a separate code path from the legacy CTE — do not "unify" the two by injecting `IN ('relates_to')` into the legacy path. SQL string equality at the CTE-source level is the contract.
- **Bash 3.2 / POSIX-sh** — comma-list parsing uses `IFS=','` `for` loop wrapped in subshell or with explicit `IFS` save/restore (matches the existing `--depends` parsing pattern at lines 119-128 of `scope-filter.sh`). No `read -ra` for the SQL `IN` clause construction (must build a single string with quoted tokens).
- **applies_to_field is non-uniform** — its target is a field name, not a chunk ID. The LEFT JOIN handling is required; otherwise the SC-4 demo fails for applies_to_field edges. Document this in code with an inline comment.
- **No edges-table writes from the traverser** — traverse-graph.sh is read-only against the DB. Any test fixture that needs edges in the table must call `rebuild-index.sh` (which T01 owns) to populate them.
- **Single-script-file Truth Check shape (AD-19)** — both Verification commands are single `bash <path>` invocations. The verifiers internally use heredocs and `$(...)` freely (those are fine inside script bodies; AD-19 only constrains the inline Truth Check command surface).

## Expected Output

`m036-p05-traverse-cites.sh` prints `PASS: m036-p05-traverse-cites (cites edge surfaced with label)` on success.

`m036-p05-traverse-relates-to-baseline.sh` prints `PASS: m036-p05-traverse-relates-to-baseline (CON-5 byte-identical)` on success. On failure it prints `FAIL: CON-5 regression at line <N>: expected '<exp>' got '<got>'` to stderr.

After T02 lands, the demo invocation from the phase plan's `demo_sentence` works end-to-end against a fixture corpus: a spec chunk declaring `cites: [REF-...]` is reachable from the traverser at depth 1 with the `cites` label preserved.

## State Context

- **Current State**: executing
- **Milestone**: M036
- **Phase**: P05
- **Task**: T02-traverser-extension
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **CON-5 byte-equality for default mode** — no `--edge-types` flag means no behavior change. The verifier `m036-p05-traverse-relates-to-baseline.sh` enforces this mechanically. The CTE construction MUST remain in a separate code path from the legacy CTE — do not "unify" the two by injecting `IN ('relates_to')` into the legacy path. SQL string equality at the CTE-source level is the contract.
- **Bash 3.2 / POSIX-sh** — comma-list parsing uses `IFS=','` `for` loop wrapped in subshell or with explicit `IFS` save/restore (matches the existing `--depends` parsing pattern at lines 119-128 of `scope-filter.sh`). No `read -ra` for the SQL `IN` clause construction (must build a single string with quoted tokens).
- **applies_to_field is non-uniform** — its target is a field name, not a chunk ID. The LEFT JOIN handling is required; otherwise the SC-4 demo fails for applies_to_field edges. Document this in code with an inline comment.
- **No edges-table writes from the traverser** — traverse-graph.sh is read-only against the DB. Any test fixture that needs edges in the table must call `rebuild-index.sh` (which T01 owns) to populate them.
- **Single-script-file Truth Check shape (AD-19)** — both Verification commands are single `bash <path>` invocations. The verifiers internally use heredocs and `$(...)` freely (those are fine inside script bodies; AD-19 only constrains the inline Truth Check command surface).

### Acceptance Criteria

Truths from the phase plan addressed by this task:

- "`traverse-graph.sh` walks `cites` edges and emits the edge label in `--ranked` / labeled output" — covered by step 4.
- "`traverse-graph.sh` default invocation (no `--edge-types` flag) is byte-identical to pre-P05 for a relates_to fixture (CON-5 regression guard)" — covered by step 5.

### Files To Touch

- `scripts/knowledge/lib/graph-db.sh` (modify) — extend CHECK constraint enum
- `scripts/knowledge/rebuild-index.sh` (modify) — read 3 new frontmatter fields, insert edges
- `scripts/knowledge/traverse-graph.sh` (modify) — `--edge-types` flag + label-bearing output
- `scripts/dispatch/scope-filter.sh` (modify) — `--tag` flag + 3 regex / scope-clause sites
- `tests/test-reference-graph-edges.sh` (create) — SC-4 end-to-end fixture test
- `tools/verify/m036-p05-edges-schema-accepts-new.sh` (create)
- `tools/verify/m036-p05-edges-schema-accepts-old.sh` (create)
- `tools/verify/m036-p05-rebuild-emits-new-edges.sh` (create)
- `tools/verify/m036-p05-traverse-cites.sh` (create)
- `tools/verify/m036-p05-traverse-relates-to-baseline.sh` (create)
- `tools/verify/m036-p05-scope-filter-source-tag.sh` (create)
- `tools/verify/m036-p05-scope-filter-baseline.sh` (create)
- `tools/verify/m036-p05-sc4-test-exists-and-passes.sh` (create)
- `tools/verify/m036-p05-phase-suite.sh` (create)

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