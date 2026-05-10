---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T04-status-json-format (Phase P01, Milestone M029)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~1100 | required |
| Upstream Context | 981-983 | ~100 | required |
| Task Plan | 985-1191 | ~5100 | required |
| State Context | 1193-1199 | ~100 | required |
| First-Turn Completeness | 1201-1268 | ~1200 | required |
| **Total** | | **~18400** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 830
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
hit_count: 830
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
hit_count: 830
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
hit_count: 830
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
hit_count: 722
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
hit_count: 722
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
hit_count: 722
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
hit_count: 830
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
hit_count: 722
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
hit_count: 722
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
hit_count: 722
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
hit_count: 830
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
hit_count: 830
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
hit_count: 830
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
hit_count: 722
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
hit_count: 722
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
hit_count: 722
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
hit_count: 830
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
hit_count: 722
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
hit_count: 722
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
hit_count: 830
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
hit_count: 830
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
hit_count: 722
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
hit_count: 722
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
hit_count: 722
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
hit_count: 377
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
hit_count: 377
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
hit_count: 377
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
hit_count: 406
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
hit_count: 406
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
hit_count: 396
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
     Project-owned slug-bearing verifiers live under tools/verify/.
     Verifier scripts are co-authored alongside their corresponding
     artifact within the SAME task (plan-time discipline rule 2).
     Namespacing: `m029-p01-*` prefix avoids collision with the
     existing phase-only `p01-phase-suite.sh` ([M030](../../../../../milestones/M030/index.md) era) per the
     milestone-slug-required convention. -->

### Truths

- `references/status-headline-shape.md` exists and is the canonical Principle-III design contract for the FR-2 headline. The document carries: (a) an H1 (`# Status Headline Shape`); (b) `## Purpose` naming FR-2 / SC-2 / `commands/status.md` as consumers; (c) `## Field Set` listing exactly five headline fields in fixed order — milestone ID + name, phase index + percent complete, lock state, last-dispatch recency, last-verify result; (d) `## Embedded Footer` documenting that the [M027](../../../../../milestones/M027/index.md) `scripts/diagnostics/efficiency-footer.sh` block follows the five-field block verbatim under `efficiency_footer: true` and disappears under `efficiency_footer: false` per CON-5 suppression-matrix inheritance; (e) `## Regex` carrying the canonical SC-2 regex that asserts the first three non-blank lines match a documented field-shape pattern; (f) `## Cross-References` naming `references/status-json-schema.md`, `commands/status.md`, M027 surfaces. Per Principle III, this contract MUST be on disk before any FR-2 implementation work begins.
  - Check: `bash tools/verify/m029-p01-headline-shape-contract.sh`

- `references/status-json-schema.md` exists and is the canonical Principle-III design contract for the FR-3 JSON output. The document carries: (a) an H1 (`# Status JSON Schema`); (b) `## schema_version` declaring `1.0` as the day-1 value per AD-7 with the documented stability policy ("non-breaking field additions under minor bumps; field removals or type changes require a major bump and a deprecation cycle"); (c) `## Top-Level Keys` enumerating the required keys — `schema_version`, `milestone_id`, `milestone_name`, `phase_index`, `phase_count`, `phase_percent_complete`, `lock_state`, `last_dispatch_recency`, `last_verify_result`, `sections`, plus an optional `state` key set to `"degraded"` when the JSONL stream parses with errors; (d) `## sections` documenting the ANSI-strip rule per AD-2 (every string in `sections` is ANSI-stripped unconditionally regardless of TTY); (e) `## Edge Cases` covering the corrupt-JSONL stream → `state: "degraded"` + `parse_errors: [...]` shape from the spec's Edge Cases section; (f) `## Cross-References` naming `references/status-headline-shape.md`, `commands/status.md`, `scripts/diagnostics/render-status-json.sh`, [M035](../../../../../milestones/M035/index.md) packaging, post-launch `external-tool-adapters`. Per Principle III + AD-7, this contract MUST be on disk before any FR-3 implementation work begins.
  - Check: `bash tools/verify/m029-p01-json-schema-contract.sh`

- `scripts/state/detect-invocation-context.sh` exists, is executable, accepts `--tty=<true|false>` and `--ci=<true|false>` test-injection flags (used by SC-1; production callers omit these and rely on real `[ -t 1 ]` + env-var probing), and emits an env-block on stdout in `key=value` lines with exactly three fields per AD-1: `renderer ∈ {tui, json, plain}`, `exit_code_scheme ∈ {interactive, governance}`, `default_provider` (passthrough from existing config; resolved via the standard 4-layer fallback). Resolution rules: TTY=true + no CI vars → `renderer=tui exit_code_scheme=interactive`; TTY=false → `renderer=plain exit_code_scheme=governance`; `--format=json` invocation context (passed via `--format=json` flag) → `renderer=json exit_code_scheme=governance`. Exit 0 on success. Read-only — never writes to disk. AD-1 single-resolve discipline: every M029 surface (`status` headline, `--format=json`, `where`, `context`, live-tail, preflight) reads this script's emitted env block at command entry; no surface re-derives. The script MUST refuse unknown flags with exit non-zero and a usage diagnostic on stderr.
  - Check: `bash tools/verify/m029-p01-invocation-context-resolver-shape.sh`

<dispatch-volatile>

## Upstream Context

No upstream summaries available.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M029"
name: "JSON renderer + --format=json wiring + SC-3 fixture/script + verifier (FR-3, AD-2, AD-7)"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- T01 has completed: `references/status-json-schema.md` exists and documents the schema_version, top-level keys, the AD-2 unconditional ANSI-strip rule, the degraded-state edge case, and the AD-7 versioning policy. Verify with `[ -f references/status-json-schema.md ]` AND `bash tools/verify/m029-p01-json-schema-contract.sh` exits 0.
- T02 has completed: `scripts/state/detect-invocation-context.sh` exists and emits `renderer=json` under `--format=json`.
- T03 has completed: `commands/status.md` carries the headline block + the resolver-eval at command entry. Verify with `bash tools/verify/m029-p01-status-headline-shape.sh` exits 0.
- `scripts/diagnostics/` exists; sibling helpers (`efficiency-footer.sh`, `metrics-rollup.sh`) follow the source-guard + bash-3.2 + read-only convention.
- No file currently lives at `scripts/diagnostics/render-status-json.sh`; verify `[ ! -f scripts/diagnostics/render-status-json.sh ]`. Path-collision check passed at plan-authoring time.
- `jq` is available on the runtime host (verify with `command -v jq` exits 0). The renderer uses `jq -n` for safe JSON construction.

## Description

T04 implements **FR-3 (`--format=json`)** plus the **AD-2 unconditional ANSI-strip rule** plus the **AD-7 schema_version: "1.0" from day 1** policy.

T04 ships:
- `scripts/diagnostics/render-status-json.sh` — the JSON renderer; the SINGLE ANSI-strip site per AD-2; emits a JSON object validating against `references/status-json-schema.md`.
- A modification to `commands/status.md` adding `--format=json` flag wiring: when `renderer=json` (per the resolver), the headline+flat-sections markdown path is SKIPPED and the JSON renderer's stdout becomes the command's stdout.
- The fixture milestone trees at `tests/m029-acceptance/fixtures/status-json-executing.fixture/` (the SC-3 happy path) and `tests/m029-acceptance/fixtures/status-json-degraded.fixture/` (the corrupt-JSONL edge case from the spec's Edge Cases section).
- The SC-3 acceptance script `tests/m029-acceptance/p01-sc3-format-json.sh` covering the schema_version assertion, every required key via `jq -e`, the ANSI-strip invariant, and the degraded-state path.
- Two shape verifiers (`tools/verify/m029-p01-render-status-json-shape.sh` for the renderer; `tools/verify/m029-p01-status-format-json-wiring.sh` for the commands/status.md wiring; `tools/verify/m029-p01-sc3-shape.sh` for the SC-3 wrapper).

The renderer reads the resolver's env block at entry — but in production, the resolver is invoked WITH the `--format=json` flag set on the parent (status command), so `renderer=json` is already resolved. The renderer's job is to construct the JSON payload, ANSI-strip every section's rendered string unconditionally per AD-2, and emit valid JSON.

## Steps

1. **Author `scripts/diagnostics/render-status-json.sh`** (≥100 lines, executable, bash 3.2 compatible). Required structure:

   - Shebang `#!/usr/bin/env bash` + `set -u`.
   - Header comment naming FR-3, AD-2, AD-7, the single-strip-site invariant, and the schema SSOT (`references/status-json-schema.md`).
   - Re-source guard following the project convention (`_RENDER_STATUS_JSON_SH_SOURCED` scalar).
   - Constant `_M029_SCHEMA_VERSION="1.0"` declared once at the top — single source of truth in the script for the schema_version field. The verifier asserts this constant exists.
   - Argument parser for: `--milestone <Mxxx>` (optional; falls back to `find-active-milestone.sh` when omitted), `--orchestrator-root <path>` (optional; falls back to `scripts/state/resolve-root.sh`), `--help|-h`.
   - Function `_collect_headline_fields()` that reads:
     - milestone ID + name (via `find-active-milestone.sh` + roadmap parse)
     - phase index + count + percent complete (via `read-roadmap.sh` + summary count)
     - lock state (via lock-manager state file read; mirrors the existing pattern in `commands/status.md`'s `### Stale Lock File` section)
     - last-dispatch recency (via JSONL parse; computes `Nh ago` / `Nm ago` / `Ns ago` / `none`)
     - last-verify result (via most-recent `P##-VERIFICATION.md` lookup in active phase)
   - Function `_collect_sections()` that captures the rendered string of each existing flat section. Implementation hint: invoke the existing markdown-rendering scripts/skills (or replicate their logic minimally) and capture stdout; ANSI-strip is applied at the next step. Each section is keyed by a stable lowercase-snake-case name: `progress`, `blockers`, `execution_history`, `telemetry_metrics`, `efficiency_footer`, `next_action`. (Match the section list in `references/status-json-schema.md`.)
   - Function `_ansi_strip()` that takes stdin and emits ANSI-stripped stdout. Primitive: `sed 's/\x1b\[[0-9;]*[mGKHF]//g'`. This is the SINGLE strip site per AD-2.
   - Function `_emit_json()` that builds the JSON object via `jq -n --arg ...` style argument injection (NOT raw printf string concatenation) so quote escaping is mechanically correct. The payload includes:
     - `schema_version: $_M029_SCHEMA_VERSION` (`"1.0"`)
     - `milestone_id`, `milestone_name`, `phase_index`, `phase_count`, `phase_percent_complete`, `lock_state`, `last_dispatch_recency`, `last_verify_result`
     - `sections: { progress, blockers, execution_history, telemetry_metrics, efficiency_footer, next_action }` — every value ANSI-stripped via `_ansi_strip`
   - Degraded-state branch: when JSONL parsing fails (detected via try-parse + capture parse-errors), `_emit_json()` adds `state: "degraded"` and `parse_errors: [...]` to the top level. Other fields populate to whatever extent the partial parse permits. Implementation hint: wrap the JSONL probe in a `jq -c '.' execution-log.jsonl 2>&1 >/dev/null` style check and capture the diagnostic lines; emit them as the `parse_errors` array.
   - Exit 0 on success; exit non-zero only on catastrophic failure (e.g., orchestrator-root resolution fails). Note: corrupt JSONL is NOT a failure — it produces the `state: "degraded"` shape and exits 0.
   - Read-only — never writes to disk.

2. **Modify `commands/status.md` additively** to add `--format=json` flag wiring. Add a new `## Format Flag` section between `## Headline Block` (added in T03) and `## State Derivation`. Required prose:

   > **FR-3 / SC-3 / AD-2 / AD-7.** The `--format=<format>` flag selects the rendering mode. Valid values: `tui` (default; the headline+flat-sections markdown path), `json` (the FR-3 JSON object), `plain` (markdown without ANSI; auto-selected by the resolver under non-TTY).
   >
   > **Resolution.** When `--format=json` is present, the resolver returns `renderer=json`; the headline+flat-sections markdown path is SKIPPED and `bash scripts/diagnostics/render-status-json.sh` is invoked. Its stdout becomes the command's stdout.
   >
   > **Schema.** The JSON output validates against `references/status-json-schema.md`. The top-level `schema_version` field is `"1.0"` per AD-7.
   >
   > **ANSI-strip rule (AD-2).** Every string under `sections` is ANSI-stripped unconditionally regardless of TTY. This applies even on interactive TTYs where `--format=json` is invoked manually — the JSON contract is for downstream tooling (`jq`, CI, `external-tool-adapters`), and stripping ANSI universally avoids contract migrations later.
   >
   > **Degraded state.** When `execution-log.jsonl` parses with errors, the JSON output includes `state: "degraded"` and a `parse_errors` array. The renderer never crashes on a corrupt JSONL stream.

   - Update the `## Reference Files` section to confirm `scripts/diagnostics/render-status-json.sh` and `references/status-json-schema.md` are listed (T03 may already have added these; verify presence and add if absent).

3. **Create the SC-3 happy-path fixture** at `tests/m029-acceptance/fixtures/status-json-executing.fixture/`. Same shape as the SC-2 fixture from T03 (M999 milestone, P01 complete + P02 in-flight, populated execution log with a valid `dispatch_usage` record). Implementation: copy the SC-2 fixture as a starting point, change the milestone slug if needed for fixture isolation, ensure all 3 deliverable files (`M999-ROADMAP.md`, `phases/P01/P01-SUMMARY.md`, `execution-log.jsonl`) carry valid content.

4. **Create the SC-3 degraded-state fixture** at `tests/m029-acceptance/fixtures/status-json-degraded.fixture/`. Same shape as the happy-path fixture, but `execution-log.jsonl` deliberately contains 1–2 invalid lines (e.g., truncated JSON, missing required field, garbage text on its own line). Mix valid and invalid lines so the renderer can both extract partial data AND emit `parse_errors`. Add a comment at the top of the file (a `#` line — illegal in strict JSONL but used here as a fixture-author note that the renderer should tolerate) explaining which lines are deliberately corrupt.

5. **Author `tests/m029-acceptance/p01-sc3-format-json.sh`** (≥80 lines, executable). The script:

   - Sets `set -u` and traps cleanup.
   - Creates a working temp dir; copies the happy-path fixture into it.
   - Runs `orchestrator:status --format=json` against the happy-path fixture; captures stdout to `<tmpdir>/sc3-json.out`.
   - Asserts stdout is parseable JSON: `jq empty <tmpdir>/sc3-json.out` exits 0.
   - Asserts `jq -e '.schema_version == "1.0"' <tmpdir>/sc3-json.out` exits 0.
   - For each required top-level key, runs `jq -e '.<key>' <tmpdir>/sc3-json.out` and asserts exit 0:
     - `.schema_version`, `.milestone_id`, `.milestone_name`, `.phase_index`, `.phase_count`, `.phase_percent_complete`, `.lock_state`, `.last_dispatch_recency`, `.last_verify_result`, `.sections`
   - For each required section key, runs `jq -e '.sections.<section>' <tmpdir>/sc3-json.out` and asserts exit 0:
     - `.sections.progress`, `.sections.blockers`, `.sections.execution_history`, `.sections.telemetry_metrics`, `.sections.efficiency_footer`, `.sections.next_action`
   - Asserts the AD-2 unconditional-strip invariant: `jq -r '.sections | values[]' <tmpdir>/sc3-json.out | grep -c $'\x1b\\[' || true` returns 0 (no ANSI escape sequences anywhere in any section value).
   - Re-runs `orchestrator:status --format=json` against the degraded-state fixture; captures to `<tmpdir>/sc3-degraded.out`.
   - Asserts `jq -e '.state == "degraded"' <tmpdir>/sc3-degraded.out` exits 0.
   - Asserts `jq -e '.parse_errors | length > 0' <tmpdir>/sc3-degraded.out` exits 0.
   - Asserts `jq -e '.schema_version == "1.0"' <tmpdir>/sc3-degraded.out` exits 0 (degraded-state still carries schema_version).
   - Cleanup `rm -rf <tmpdir>` on exit.
   - Tracks pass/fail; emits per-assertion `PASS:` / `FAIL:` lines + final `SC-3: pass=N fail=M`. Exits 0 iff `fail=0`.

6. **Author `tools/verify/m029-p01-render-status-json-shape.sh`** (≥30 lines, executable). The verifier:

   - Gates on file existence: `[ -f scripts/diagnostics/render-status-json.sh ]`. FAIL if missing.
   - Asserts the script is executable.
   - Asserts header comment names FR-3, AD-2, AD-7.
   - Asserts the `_M029_SCHEMA_VERSION="1.0"` constant appears (single source of truth).
   - Asserts the script invokes `jq -n` (the safe-JSON-construction primitive).
   - Asserts the ANSI-strip primitive `\x1b\[[0-9;]*[mGKHF]` appears (the AD-2 single strip site).
   - Asserts the script names the resolver (`scripts/state/detect-invocation-context.sh`).
   - Asserts the degraded-state shape appears: `state` and `parse_errors` literal tokens.
   - Asserts the section names appear: `progress`, `blockers`, `execution_history`, `telemetry_metrics`, `efficiency_footer`, `next_action`.
   - Emits `PASS:` per assertion + `SUMMARY: m029-p01-render-status-json-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

7. **Author `tools/verify/m029-p01-status-format-json-wiring.sh`** (≥25 lines, executable). The verifier:

   - Gates on `[ -f commands/status.md ]`.
   - Asserts `commands/status.md` contains `## Format Flag` (the new T04 section).
   - Asserts `commands/status.md` contains `--format=json` AND `FR-3` AND `AD-2` AND `AD-7`.
   - Asserts `commands/status.md` contains `scripts/diagnostics/render-status-json.sh`.
   - Asserts the Reference Files section names both `references/status-json-schema.md` and `scripts/diagnostics/render-status-json.sh`.
   - Emits `PASS:` per assertion + `SUMMARY: m029-p01-status-format-json-wiring.sh pass=N fail=M`. Exit 0 iff `fail=0`.

8. **Author `tools/verify/m029-p01-sc3-shape.sh`** (≥25 lines, executable). The verifier:

   - Gates on `[ -f tests/m029-acceptance/p01-sc3-format-json.sh ]` AND both fixture dirs exist.
   - Asserts the SC-3 script is executable.
   - Asserts the SC-3 script's header references SC-3 AND FR-3.
   - Asserts the script greps for `schema_version`, `1.0`, `jq -e`, AND `ANSI`.
   - Asserts the degraded fixture's `execution-log.jsonl` contains intentionally-malformed content (greps for at least one line that is NOT a complete JSON object — implementation hint: assert the file contains a line not matching `^\\s*\\{.*\\}\\s*$`).
   - Runs `bash tests/m029-acceptance/p01-sc3-format-json.sh` and asserts exit 0.
   - Emits `PASS:` per assertion + `SUMMARY: m029-p01-sc3-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

9. **Run all verifiers + the SC-3 script** to confirm green.

## Must-Haves

This task addresses these P01 phase truths:
- `scripts/diagnostics/render-status-json.sh` exists and is the AD-2 single ANSI-strip site.
- `commands/status.md` carries `--format=json` flag wiring.
- The SC-3 acceptance script exits 0 (schema_version=1.0, all required keys present via `jq -e`, AD-2 strip invariant holds, degraded state path works).

This task creates these P01 phase artifacts:
- `scripts/diagnostics/render-status-json.sh`
- `commands/status.md` modifications (FR-3 wiring + Reference Files updates)
- `tests/m029-acceptance/fixtures/status-json-executing.fixture/`
- `tests/m029-acceptance/fixtures/status-json-degraded.fixture/`
- `tests/m029-acceptance/p01-sc3-format-json.sh`
- `tools/verify/m029-p01-render-status-json-shape.sh`
- `tools/verify/m029-p01-status-format-json-wiring.sh`
- `tools/verify/m029-p01-sc3-shape.sh`

## Verification

```bash
bash tools/verify/m029-p01-render-status-json-shape.sh
```

```bash
bash tools/verify/m029-p01-status-format-json-wiring.sh
```

```bash
bash tools/verify/m029-p01-sc3-shape.sh
```

## Inputs

### From Previous Tasks

- `references/status-json-schema.md` (from T01) — the schema SSOT. T04's renderer reads: top-level keys, canonical shape, AD-2 unconditional ANSI-strip rule, degraded-state shape.
  - Key API: documented top-level keys (10 fields + optional `state` + `parse_errors`), section names (6 sections), AD-2 strip rule (every section value stripped regardless of TTY), AD-7 stability policy.
- `references/status-headline-shape.md` (from T01) — the headline shape contract. T04's renderer reuses the five headline fields as top-level JSON keys (`milestone_id` + `milestone_name`, `phase_index` + `phase_count` + `phase_percent_complete`, `lock_state`, `last_dispatch_recency`, `last_verify_result`).
- `scripts/state/detect-invocation-context.sh` (from T02) — the AD-1 resolver. T04's renderer reads the resolver's env block at entry. In production, status command calls the resolver before deciding whether to invoke T04's renderer; T04's renderer is invoked only under `renderer=json`.
  - Key API: `bash scripts/state/detect-invocation-context.sh` emits 3 lines to stdout; eval'able.
- `commands/status.md` headline-block additions (from T03) — T04 modifies the same file additively to add `## Format Flag` and Reference Files. Both T03 and T04 land additive content in commands/status.md; T04 runs strictly after T03 in the serial executor pipeline to avoid concurrent-edit conflict.

### From Disk (Pre-existing)

- `scripts/state/find-active-milestone.sh` — used to identify the active milestone for headline-field collection.
- `scripts/state/derive-phase.sh`, `scripts/state/read-roadmap.sh` — used for phase index + count.
- `scripts/state/resolve-root.sh` — used to resolve the orchestrator root when `--orchestrator-root` is omitted.
- `scripts/state/read-config.sh` — used to read config knobs (e.g., `efficiency_footer` to know whether to render that section).
- The lock-manager state file (path mirrors `commands/status.md`'s existing `### Stale Lock File` lookup).
- The most recent `P##-VERIFICATION.md` lookup mirrors `commands/status.md`'s existing `### Failed Verification` section.
- `jq` — required runtime dependency; the renderer uses `jq -n --arg` for safe JSON construction. Verify availability at script entry and exit non-zero with a clear diagnostic if missing.

## Constraints

- AD-2 single strip site: `_ansi_strip()` in `render-status-json.sh` is the ONLY ANSI-strip site for JSON output. The legacy markdown flat-section path retains ANSI emission unchanged. Per the spec's #Q-G3 resolution at AD-2: TTY split was rejected for complexity-vs-benefit reasons; unconditional strip is the locked-in invariant.
- AD-7 schema_version: `"1.0"` is locked at day 1. The constant `_M029_SCHEMA_VERSION="1.0"` is the single source of truth in the renderer; the schema doc is the SSOT for the contract; both must agree. Future field additions follow semver-style minor bumps; field removals or type changes require a major bump + deprecation cycle.
- Safe JSON construction: use `jq -n --arg key value` style argument injection; do NOT use raw printf string concatenation. This is mechanically correct (handles quotes, special chars, unicode) and is the project convention for JSON emission.
- Degraded-state behavior: corrupt JSONL is NOT a fatal error. The renderer captures parse errors, emits `state: "degraded"` + `parse_errors: [...]`, populates other fields to the extent partial parsing permits, and exits 0. This is documented in the spec's Edge Cases section.
- Bash 3.2 compatibility (CON-7 carry-forward from `efficiency-footer.sh`): no associative arrays, no case-folding parameter expansion, no process substitution, no herestrings. Mirror the M027 helpers' style.
- Read-only (CON-1 / FR-14): the renderer never writes to `.orchestrator/`, never modifies `execution-log.jsonl`, never invokes external HTTP APIs.
- Per the M029 knowledge-layer boundary (CON-7, AD-8): T04 modifies only `commands/status.md` (additive); creates only the renderer + fixtures + acceptance + verifiers. NO modification to M013/M019/M020/M027 surfaces. NO new schema additions outside `references/status-json-schema.md` (which T01 owns).

## Expected Output

After T04 completes:
- `scripts/diagnostics/render-status-json.sh` exists, is executable, and emits valid JSON validating against `references/status-json-schema.md`.
- `commands/status.md` carries `## Format Flag` section + updated Reference Files.
- Both fixture milestone trees exist (`status-json-executing.fixture/`, `status-json-degraded.fixture/`).
- `tests/m029-acceptance/p01-sc3-format-json.sh` exists, is executable, and exits 0 with `SC-3: pass=N fail=0`.
- All three verifiers (`m029-p01-render-status-json-shape.sh`, `m029-p01-status-format-json-wiring.sh`, `m029-p01-sc3-shape.sh`) exist, are executable, and exit 0.
- A summary file at [`.orchestrator/milestones/M029/phases/P01/tasks/T04-status-json-format-SUMMARY.md`](../../../../../milestones/M029/phases/P01/tasks/T04-status-json-format-SUMMARY.md) documents the deliverables.

## Notes

Expected verifier output: `PASS:` lines for each assertion, ending with `SUMMARY: m029-p01-render-status-json-shape.sh pass=10 fail=0` (and similar for the other two verifiers). Expected SC-3 acceptance output: per-key `PASS:` lines + ANSI invariant + degraded-state assertions, ending with `SC-3: pass=N fail=0`.

The schema_version: "1.0" lock is the load-bearing public-contract decision. M035 packaging consumes the schema as a post-install verification surface; post-launch `external-tool-adapters` consume it for GitHub Projects / Trello / Notion / Linear adapters. Any drift between the schema doc constant ("1.0") and the renderer constant (`_M029_SCHEMA_VERSION`) is a contract violation; the verifiers cross-check both literally.

## State Context

- **Current State**: executing
- **Milestone**: M029
- **Phase**: P01
- **Task**: T04-status-json-format
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- AD-2 single strip site: `_ansi_strip()` in `render-status-json.sh` is the ONLY ANSI-strip site for JSON output. The legacy markdown flat-section path retains ANSI emission unchanged. Per the spec's #Q-G3 resolution at AD-2: TTY split was rejected for complexity-vs-benefit reasons; unconditional strip is the locked-in invariant.
- AD-7 schema_version: `"1.0"` is locked at day 1. The constant `_M029_SCHEMA_VERSION="1.0"` is the single source of truth in the renderer; the schema doc is the SSOT for the contract; both must agree. Future field additions follow semver-style minor bumps; field removals or type changes require a major bump + deprecation cycle.
- Safe JSON construction: use `jq -n --arg key value` style argument injection; do NOT use raw printf string concatenation. This is mechanically correct (handles quotes, special chars, unicode) and is the project convention for JSON emission.
- Degraded-state behavior: corrupt JSONL is NOT a fatal error. The renderer captures parse errors, emits `state: "degraded"` + `parse_errors: [...]`, populates other fields to the extent partial parsing permits, and exits 0. This is documented in the spec's Edge Cases section.
- Bash 3.2 compatibility (CON-7 carry-forward from `efficiency-footer.sh`): no associative arrays, no case-folding parameter expansion, no process substitution, no herestrings. Mirror the M027 helpers' style.
- Read-only (CON-1 / FR-14): the renderer never writes to `.orchestrator/`, never modifies `execution-log.jsonl`, never invokes external HTTP APIs.
- Per the M029 knowledge-layer boundary (CON-7, AD-8): T04 modifies only `commands/status.md` (additive); creates only the renderer + fixtures + acceptance + verifiers. NO modification to M013/M019/M020/M027 surfaces. NO new schema additions outside `references/status-json-schema.md` (which T01 owns).

### Acceptance Criteria

This task addresses these P01 phase truths:
- `scripts/diagnostics/render-status-json.sh` exists and is the AD-2 single ANSI-strip site.
- `commands/status.md` carries `--format=json` flag wiring.
- The SC-3 acceptance script exits 0 (schema_version=1.0, all required keys present via `jq -e`, AD-2 strip invariant holds, degraded state path works).

This task creates these P01 phase artifacts:
- `scripts/diagnostics/render-status-json.sh`
- `commands/status.md` modifications (FR-3 wiring + Reference Files updates)
- `tests/m029-acceptance/fixtures/status-json-executing.fixture/`
- `tests/m029-acceptance/fixtures/status-json-degraded.fixture/`
- `tests/m029-acceptance/p01-sc3-format-json.sh`
- `tools/verify/m029-p01-render-status-json-shape.sh`
- `tools/verify/m029-p01-status-format-json-wiring.sh`
- `tools/verify/m029-p01-sc3-shape.sh`

### Files To Touch

- `references/status-headline-shape.md` (create)
- `references/status-json-schema.md` (create)
- `scripts/state/detect-invocation-context.sh` (create)
- `scripts/diagnostics/render-status-json.sh` (create)
- `commands/status.md` (modify)
- `commands/context.md` (create)
- `tests/m029-acceptance/p01-sc1-resolver.sh` (create)
- `tests/m029-acceptance/p01-sc2-headline.sh` (create)
- `tests/m029-acceptance/p01-sc3-format-json.sh` (create)
- `tests/m029-acceptance/p01-sc4-context.sh` (create)
- `tests/m029-acceptance/p01-acceptance-battery.sh` (create)
- `tests/m029-acceptance/fixtures/status-headline-executing.fixture/M999-ROADMAP.md` (create)
- `tests/m029-acceptance/fixtures/status-headline-executing.fixture/execution-log.jsonl` (create)
- `tests/m029-acceptance/fixtures/status-headline-executing.fixture/phases/P01/P01-SUMMARY.md` (create)
- `tests/m029-acceptance/fixtures/status-json-executing.fixture/M999-ROADMAP.md` (create)
- `tests/m029-acceptance/fixtures/status-json-executing.fixture/execution-log.jsonl` (create)
- `tests/m029-acceptance/fixtures/status-json-executing.fixture/phases/P01/P01-SUMMARY.md` (create)
- `tests/m029-acceptance/fixtures/status-json-degraded.fixture/M999-ROADMAP.md` (create)
- `tests/m029-acceptance/fixtures/status-json-degraded.fixture/execution-log.jsonl` (create)
- `tools/verify/m029-p01-headline-shape-contract.sh` (create)
- `tools/verify/m029-p01-json-schema-contract.sh` (create)
- `tools/verify/m029-p01-invocation-context-resolver-shape.sh` (create)
- `tools/verify/m029-p01-sc1-shape.sh` (create)
- `tools/verify/m029-p01-status-headline-shape.sh` (create)
- `tools/verify/m029-p01-sc2-shape.sh` (create)
- `tools/verify/m029-p01-render-status-json-shape.sh` (create)
- `tools/verify/m029-p01-status-format-json-wiring.sh` (create)
- `tools/verify/m029-p01-sc3-shape.sh` (create)
- `tools/verify/m029-p01-context-skill-shape.sh` (create)
- `tools/verify/m029-p01-sc4-shape.sh` (create)
- `tools/verify/m029-p01-acceptance-battery-shape.sh` (create)
- `tools/verify/m029-p01-readonly-invariant.sh` (create)
- `tools/verify/m029-p01-scope-guard.sh` (create)
- `tools/verify/m029-p01-phase-suite.sh` (create)

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