---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T03-scope-tag-and-validator (Phase P00, Milestone M036)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~600 | required |
| Upstream Context | 981-983 | ~100 | required |
| Task Plan | 985-1356 | ~5200 | required |
| State Context | 1358-1364 | ~100 | required |
| First-Turn Completeness | 1366-1412 | ~1100 | required |
| **Total** | | **~17900** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 718
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
hit_count: 718
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
hit_count: 718
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
hit_count: 718
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
hit_count: 628
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
hit_count: 628
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
hit_count: 628
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
hit_count: 718
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
hit_count: 628
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
hit_count: 628
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
hit_count: 628
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
hit_count: 718
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
hit_count: 718
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
hit_count: 718
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
hit_count: 628
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
hit_count: 628
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
hit_count: 628
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
hit_count: 718
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
hit_count: 628
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
hit_count: 628
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
hit_count: 718
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
hit_count: 718
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
hit_count: 628
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
hit_count: 628
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
hit_count: 628
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
hit_count: 283
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
hit_count: 283
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
hit_count: 283
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
hit_count: 294
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
hit_count: 294
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
hit_count: 284
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
     Verifier scripts live under tools/verify/ — project-owned path,
     slug-bearing filenames so install-clobber risk is contained.
     Each verifier is co-authored alongside its corresponding artifact
     within the SAME task (plan-time discipline rule 2). -->

### Truths

- `references/reference-taxonomy.md` exists with YAML frontmatter (`schema_version: "1.0"`, `type: reference-taxonomy`, `milestone: "M036"`, `phase: "P00"`) and declares exactly the four categories `cms-rule`, `training-material`, `glossary`, `regulatory-doc` in a body section titled `## Categories` (each category appears as a level-3 heading `### <category>` with a one-paragraph definition + an example `cite_id` slug).
  - Check: `bash tools/verify/p00-taxonomy-shape.sh`

- `references/reference-frontmatter-contract.md` exists with frontmatter (`schema_version: "1.0"`, `type: reference-frontmatter-contract`) and a body that names every required FR-2 field (`source`, `published`, `version`, `cite_id`, `topic_tags`, `applies_to_field`) under a `## Required Fields` section, every additional FR-4 chunk-output field (`category`, `chunk_id`, `content_hash`, `scope_tags`) under `## Chunk-Output Additions`, and every graph-edge-bearing field (`cites`, `derived_from`, `applies_to_field`, `relates_to`, `supersedes`) under `## Graph Edge Fields`.
  - Check: `bash tools/verify/p00-frontmatter-contract-shape.sh`

- `references/reference-source-types.yaml` exists with frontmatter-style top-of-file comment header pointing at `## Source Types` in `references/reference-source-types.md` (or inline in this YAML — see frontmatter contract), and a `source_types:` map containing exactly the four taxonomy keys with a `default_tier:` value in the closed enum `{0, 1, 2}` for each. Defaults declared per spec #Q-8: `cms-rule: 2`, `training-material: 2`, `glossary: 2`, `regulatory-doc: 1`.
  - Check: `bash tools/verify/p00-source-types-shape.sh`

- `references/reference-edge-types.md` exists with frontmatter (`schema_version: "1.0"`, `type: reference-edge-types`) and a body section `## Edge Types` listing five edges — three new (`cites`, `derived_from`, `applies_to_field`) authored by M036, and two pre-existing (`relates_to`, `supersedes`) cross-referenced for completeness — each with a one-line directionality declaration (`directional from <source> → <target>` or `bidirectional`).

<dispatch-volatile>

## Upstream Context

No upstream summaries available.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P00"
milestone: "M036"
name: "Scope-tag namespace extension + chunk-frontmatter validator + phase-suite gate"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 completed: `references/reference-taxonomy.md`, `references/reference-frontmatter-contract.md`, `references/reference-source-types.yaml` exist; their three shape verifiers exist under `tools/verify/`.
- T02 completed: `references/reference-edge-types.md`, `scripts/dispatch/adapters/format/registry.tsv` exist; their two shape verifiers exist under `tools/verify/`.
- `references/file-formats.md` exists with a `### Scope Tags` table at line ~649 (current state: three rows — `project`, `milestone:M001`, `phase:M001/P02`).
- `references/spec-management.md` exists (currently has no scope-tag content; receives a forward cross-reference paragraph).
- `tools/verify/` exists with the five T01+T02 verifier scripts.

## Description

Land the three remaining P00 deliverables and prove the foundation gates the demo sentence promises:

1. **Additive scope-tag namespace extension** — append a fourth row `[source:<cite_id>]` to `references/file-formats.md` `### Scope Tags` table (the actual SSOT) and add a one-paragraph cross-reference in `references/spec-management.md` (the roadmap's literal target). Verifiers: `p00-scope-tag-extension.sh` + `p00-spec-management-crossref.sh`.

2. **Chunk-frontmatter validator library** — `tools/verify/lib/p00-validate-chunk-frontmatter.sh` reads stdin (a YAML frontmatter block) and rejects any chunk whose `category` is outside the four-category taxonomy or whose `tier` (when present) is outside `{0, 1, 2}`. This is the harness that proves the demo sentence's "fail validation if they declare a category outside the taxonomy or a tier outside {0, 1, 2}" property — without it, the SSOT files are documentation alone. Validator: `p00-taxonomy-rejects-unknown.sh` (negative test) drives the library against three synthetic stdin fixtures.

3. **Phase-suite aggregator** — `tools/verify/p00-phase-suite.sh` invokes all eight P00 gates (three from T01 + two from T02 + three new in T03) in order, exits 0 iff every sub-gate passes, and emits the `SUMMARY: p00-phase-suite.sh pass=N fail=M` line. This is the must-have aggregator that `scripts/verify/check-must-haves.sh` and `auto-loop.sh --step=V` resolve against.

T03 is the close-out task. After T03 succeeds, P00 transitions from `executing` to `phase-complete`.

## Steps

1. **Append the `[source:<cite_id>]` row to `references/file-formats.md` `### Scope Tags` table.** Locate the table at line ~649 (search for `### Scope Tags`). The table is a 3-row markdown table:

   ```markdown
   | Scope | Applies to |
   |-------|------------|
   | `project` | Entire project, all milestones |
   | `milestone:M001` | Specific milestone |
   | `phase:M001/P02` | Specific phase |
   ```

   Append a fourth row. The exact insertion (immediately after the `phase:M001/P02` row, preserving the trailing pipe alignment):

   ```markdown
   | `source:<cite_id>` | Specific reference-corpus source (M036 — see `references/reference-frontmatter-contract.md`) |
   ```

   Do NOT modify the existing three rows (CON-1: existing namespaces preserved verbatim).

2. **Append a cross-reference paragraph to `references/spec-management.md`.** The spec-management.md file currently has no scope-tag content; append a new section (or insert alongside an existing thematically appropriate section) containing this content:

   ```markdown
   ## Scope-Tag Grammar Cross-Reference

   The orchestrator's scope-tag grammar (`[project]`, `[milestone:M###]`,
   `[phase:M###/P##]`, `[source:<cite_id>]`) is declared in
   `references/file-formats.md` `### Scope Tags`. Spec-management
   workflows consume scope tags via `scripts/dispatch/scope-filter.sh`.

   The `[source:<cite_id>]` namespace is M036-introduced
   (reference-corpus ingest, spec
   `specs/033-reference-corpus-ingest/spec.md`). Operator-asserted —
   the orchestrator does not factually verify that a chunk tagged
   `[source:cms-pbj-2024-q3]` actually derives from that source (see
   spec #Q-7).
   ```

   The shape verifier (step 4) greps for the `[source:` token and the `file-formats.md` filename in this file.

3. **Author `tools/verify/lib/p00-validate-chunk-frontmatter.sh`.** This is a library helper invoked from T03's negative-test verifier (and reused by P04's ingest classifier in a future phase). Bash 3.2-compatible. Behavior:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/lib/p00-validate-chunk-frontmatter.sh — M036 P00 T03
   # chunk-frontmatter validator. Reads a YAML frontmatter block from
   # stdin (or a file path argument) and rejects entries whose category
   # is outside the M036 taxonomy or whose tier is outside {0, 1, 2}.
   #
   # Authoritative SSOT: references/reference-taxonomy.md (categories),
   #                    references/reference-source-types.yaml (tier enum).
   # The taxonomy values are duplicated here as a hardcoded list ONLY
   # for the validator's tight loop — adding a category requires updating
   # both this file and the SSOT in lockstep, gated by the M036 D-row
   # convention. The shape verifier (p00-taxonomy-shape.sh) catches the
   # SSOT side; this validator catches the validator side.
   #
   # Usage:
   #   bash tools/verify/lib/p00-validate-chunk-frontmatter.sh < frontmatter.yaml
   #   bash tools/verify/lib/p00-validate-chunk-frontmatter.sh path/to/frontmatter.yaml
   #
   # Exit: 0 if valid, 1 if any rejection. Emits ACCEPT: / REJECT: lines
   # to stdout. Errors to stderr.
   set -eu
   if [ $# -ge 1 ] && [ -f "$1" ]; then
     INPUT="$1"
     CATEGORY=$(grep -E '^category:' "$INPUT" | head -n 1 | sed -E 's/^category:[[:space:]]*//' | sed -E 's/[[:space:]]*$//')
     TIER=$(grep -E '^tier:' "$INPUT" | head -n 1 | sed -E 's/^tier:[[:space:]]*//' | sed -E 's/[[:space:]]*$//')
   else
     # Read stdin into a temp file (avoid $() with pipe).
     TMP=$(mktemp)
     cat > "$TMP"
     CATEGORY=$(grep -E '^category:' "$TMP" | head -n 1 | sed -E 's/^category:[[:space:]]*//' | sed -E 's/[[:space:]]*$//')
     TIER=$(grep -E '^tier:' "$TMP" | head -n 1 | sed -E 's/^tier:[[:space:]]*//' | sed -E 's/[[:space:]]*$//')
     rm -f "$TMP"
   fi
   reject=0
   # Category check — must be one of the four taxonomy values when present.
   if [ -n "${CATEGORY:-}" ]; then
     case "$CATEGORY" in
       cms-rule|training-material|glossary|regulatory-doc)
         echo "ACCEPT: category=$CATEGORY"
         ;;
       *)
         echo "REJECT: category=$CATEGORY (not in taxonomy: cms-rule|training-material|glossary|regulatory-doc)"
         reject=1
         ;;
     esac
   fi
   # Tier check — must be 0, 1, or 2 when present.
   if [ -n "${TIER:-}" ]; then
     case "$TIER" in
       0|1|2)
         echo "ACCEPT: tier=$TIER"
         ;;
       *)
         echo "REJECT: tier=$TIER (not in {0, 1, 2})"
         reject=1
         ;;
     esac
   fi
   if [ "$reject" -gt 0 ]; then exit 1; fi
   exit 0
   ```

   The validator reads at most one `category:` and one `tier:` line; downstream phases may extend it to validate the full FR-2 field set. T03 ships only the taxonomy + tier check — the load-bearing pair the demo sentence calls out.

   Note on cat-with-pipe avoidance: `$(grep ... | head ... | sed ...)` chains a substitution containing pipes. Per AD-19, `$()` containing pipes triggers the harness shape-guard. The validator file is invoked via `bash tools/verify/lib/...sh` (single-script-file shape), so the harness inspects only the *invocation*, not the script's internals — substitution-with-pipes inside the script body does not trigger the heuristic. Confirmed by classifier trace: the literal command `bash tools/verify/lib/p00-validate-chunk-frontmatter.sh` classifies as `single-script-file` (verdict from `scripts/verify/lib/shape-classifier.sh::classify_command` — script-file invocation form, no inline compound shell, no `$()` pipe in the invocation itself).

4. **Author `tools/verify/p00-scope-tag-extension.sh`.** Shape-checks the `references/file-formats.md` modification:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/p00-scope-tag-extension.sh — M036 P00 T03 gate for
   # the [source:<cite_id>] namespace addition to file-formats.md
   # ### Scope Tags table.
   set -eu
   FILE="${1:-references/file-formats.md}"
   pass=0; fail=0
   if [ ! -f "$FILE" ]; then
     echo "FAIL: $FILE missing"
     echo "SUMMARY: p00-scope-tag-extension.sh pass=0 fail=1"
     exit 1
   fi
   for token in '### Scope Tags' '`source:<cite_id>`' 'reference-frontmatter-contract'; do
     if grep -qF "$token" "$FILE"; then
       pass=$((pass + 1))
     else
       fail=$((fail + 1))
       echo "FAIL: $FILE missing token: $token"
     fi
   done
   # Pre-existing namespaces preserved (CON-1).
   for token in '`project`' '`milestone:M001`' '`phase:M001/P02`'; do
     if grep -qF "$token" "$FILE"; then
       pass=$((pass + 1))
     else
       fail=$((fail + 1))
       echo "FAIL: $FILE missing pre-existing token: $token"
     fi
   done
   echo "SUMMARY: p00-scope-tag-extension.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

5. **Author `tools/verify/p00-spec-management-crossref.sh`.** Shape-checks the spec-management.md modification:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/p00-spec-management-crossref.sh — M036 P00 T03 gate
   # for the cross-reference paragraph added to spec-management.md.
   set -eu
   FILE="${1:-references/spec-management.md}"
   pass=0; fail=0
   if [ ! -f "$FILE" ]; then
     echo "FAIL: $FILE missing"
     echo "SUMMARY: p00-spec-management-crossref.sh pass=0 fail=1"
     exit 1
   fi
   for token in 'file-formats.md' 'source:<cite_id>' 'M036'; do
     if grep -qF "$token" "$FILE"; then
       pass=$((pass + 1))
     else
       fail=$((fail + 1))
       echo "FAIL: $FILE missing token: $token"
     fi
   done
   echo "SUMMARY: p00-spec-management-crossref.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

6. **Author `tools/verify/p00-taxonomy-rejects-unknown.sh`.** Negative-test driver. Behavior:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/p00-taxonomy-rejects-unknown.sh — M036 P00 T03 negative
   # test for the chunk-frontmatter validator. Asserts the validator
   # rejects out-of-taxonomy categories AND out-of-{0,1,2} tiers, and
   # accepts in-policy combinations.
   set -eu
   VALIDATOR="${1:-tools/verify/lib/p00-validate-chunk-frontmatter.sh}"
   pass=0; fail=0
   if [ ! -f "$VALIDATOR" ]; then
     echo "FAIL: $VALIDATOR missing"
     echo "SUMMARY: p00-taxonomy-rejects-unknown.sh pass=0 fail=1"
     exit 1
   fi
   TMPDIR=$(mktemp -d)
   trap 'rm -rf "$TMPDIR"' EXIT
   # Fixture A — out-of-taxonomy category, must reject (validator exits 1).
   cat > "$TMPDIR/a.yaml" <<'EOF'
   category: blog-post
   tier: 1
   EOF
   if bash "$VALIDATOR" "$TMPDIR/a.yaml" >/dev/null 2>&1; then
     fail=$((fail + 1))
     echo "FAIL: validator accepted out-of-taxonomy category=blog-post (expected reject)"
   else
     pass=$((pass + 1))
   fi
   # Fixture B — out-of-enum tier, must reject (validator exits 1).
   cat > "$TMPDIR/b.yaml" <<'EOF'
   category: cms-rule
   tier: 5
   EOF
   if bash "$VALIDATOR" "$TMPDIR/b.yaml" >/dev/null 2>&1; then
     fail=$((fail + 1))
     echo "FAIL: validator accepted out-of-enum tier=5 (expected reject)"
   else
     pass=$((pass + 1))
   fi
   # Fixture C — in-policy, must accept (validator exits 0).
   cat > "$TMPDIR/c.yaml" <<'EOF'
   category: cms-rule
   tier: 2
   EOF
   if bash "$VALIDATOR" "$TMPDIR/c.yaml" >/dev/null 2>&1; then
     pass=$((pass + 1))
   else
     fail=$((fail + 1))
     echo "FAIL: validator rejected in-policy category=cms-rule tier=2 (expected accept)"
   fi
   echo "SUMMARY: p00-taxonomy-rejects-unknown.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

   Three fixtures, three assertions: reject `blog-post` category, reject `tier: 5`, accept `cms-rule + tier: 2`. The harness writes fixture YAML files to a temp directory and invokes the validator with each as a path argument (avoiding heredoc-feeding-pipe shapes that AD-19 forbids).

7. **Author `tools/verify/p00-phase-suite.sh`.** Aggregator gate. Behavior:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/p00-phase-suite.sh — M036 P00 phase-suite aggregator.
   # Invokes the eight P00 sub-gates in order. Exits 0 iff every sub-gate
   # passes. Single-script-file shape per AD-19.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   pass=0; fail=0
   run() {
     local gate="$1"
     if bash "$ROOT/tools/verify/$gate" >/dev/null 2>&1; then
       echo "PASS: $gate"
       pass=$((pass + 1))
     else
       echo "FAIL: $gate"
       fail=$((fail + 1))
     fi
   }
   run p00-taxonomy-shape.sh
   run p00-frontmatter-contract-shape.sh
   run p00-source-types-shape.sh
   run p00-edge-types-shape.sh
   run p00-adapter-registry-shape.sh
   run p00-scope-tag-extension.sh
   run p00-spec-management-crossref.sh
   run p00-taxonomy-rejects-unknown.sh
   echo "SUMMARY: p00-phase-suite.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

   Eight sub-gates total: three from T01, two from T02, three from T03. The `run` helper is a single function invocation per gate — no compound chains. Output is one `PASS: <gate>` or `FAIL: <gate>` line per sub-gate plus the aggregator `SUMMARY:` line.

8. **Self-check.** Run the full phase suite from repo root:

   ```bash
   bash tools/verify/p00-phase-suite.sh
   ```

   Exits 0 with `SUMMARY: p00-phase-suite.sh pass=8 fail=0`.

## Must-Haves

This task satisfies these phase truths:

- "`references/file-formats.md` `### Scope Tags` table contains a fourth row `[source:<cite_id>]` with pre-existing rows preserved" — T03 modifies; `p00-scope-tag-extension.sh` gates.
- "`references/spec-management.md` contains a cross-reference paragraph pointing to file-formats.md and naming `[source:<cite_id>]`" — T03 modifies; `p00-spec-management-crossref.sh` gates.
- "Taxonomy and tier-policy validators reject out-of-taxonomy categories and out-of-{0,1,2} tiers" — T03 authors `tools/verify/lib/p00-validate-chunk-frontmatter.sh` + `p00-taxonomy-rejects-unknown.sh`; the negative-test driver gates.
- "`bash tools/verify/p00-phase-suite.sh` invokes all eight P00 gates in order, exits 0 iff every sub-gate passes" — T03 authors the aggregator.

## Verification

```bash
bash tools/verify/p00-scope-tag-extension.sh
bash tools/verify/p00-spec-management-crossref.sh
bash tools/verify/p00-taxonomy-rejects-unknown.sh
bash tools/verify/p00-phase-suite.sh
```

Each verifier uses single-script-file shape per AD-19. The phase-suite aggregator is the load-bearing close-out gate; it must exit 0 with `SUMMARY: p00-phase-suite.sh pass=8 fail=0`.

## Inputs

### From Previous Tasks

- T01 outputs (`references/reference-taxonomy.md`, `references/reference-frontmatter-contract.md`, `references/reference-source-types.yaml`) and verifiers (`p00-taxonomy-shape.sh`, `p00-frontmatter-contract-shape.sh`, `p00-source-types-shape.sh`). Key API: each verifier exits 0 with `SUMMARY: <name> pass=N fail=0` against the artifact at its default path. Key types: shell exit codes (0/1) and the `SUMMARY:` stdout line.
- T02 outputs (`references/reference-edge-types.md`, `scripts/dispatch/adapters/format/registry.tsv`) and verifiers (`p00-edge-types-shape.sh`, `p00-adapter-registry-shape.sh`). Same API contract.

### From Disk (Pre-existing)

- `references/file-formats.md` — line 649 declares the `### Scope Tags` table. T03 appends a fourth row. The pre-existing three rows (`project`, `milestone:M001`, `phase:M001/P02`) are preserved verbatim.
- `references/spec-management.md` — currently has no scope-tag content. T03 appends a cross-reference paragraph.
- `specs/033-reference-corpus-ingest/spec.md` — FR-1 (taxonomy enum), FR-6 (`[source:...]` namespace), #Q-7 (operator-asserted note for the cross-reference paragraph). Authoritative content source.
- `scripts/verify/lib/shape-classifier.sh` — used at plan-authoring time to classify the validator-library invocation form; not invoked at execution time.

## Constraints

- **CON-1 (no-regression)**: pre-existing scope-tag namespaces (`project`, `milestone:M001`, `phase:M001/P02`) are preserved verbatim in `file-formats.md`. The `p00-scope-tag-extension.sh` verifier asserts both the new row's presence AND the pre-existing rows' presence — a regression that drops a pre-existing row would fail the verifier.
- **CON-5 (no-spec-chunk-schema-change)**: T03 adds the `[source:<cite_id>]` namespace additively. Existing spec / memory / reference chunk frontmatter remains valid without modification.
- **Bash 3.2 compatibility**: same as T01/T02 — no `mapfile`, `declare -A`, process substitution, no `$()` containing pipes. Per the AD-19 note in step 3: substitutions-with-pipes *inside* a script body do not trigger the harness heuristic because the harness inspects only the invocation form. The validator script's internal `grep | head | sed` pipeline is fine; the *Verification* invocations in this plan use single-script-file shape.
- **Single-script-file Truth Check shape (AD-19)**: every command in the `## Verification` section above is a single `bash tools/verify/<name>.sh` invocation. No inline compound bash, no plain subshells, no `$(...)` containing pipes at the invocation layer.
- **Plan-time discipline rule 3 (classifier-shape pre-validation)**: the validator-library invocation form `bash tools/verify/lib/p00-validate-chunk-frontmatter.sh` was classified at plan-authoring time as `single-script-file` (verdict from `scripts/verify/lib/shape-classifier.sh::classify_command` — see step 3 note). The verdict is recorded; the validator's internal pipeline does not surface to the classifier because the classifier inspects invocations, not script bodies.
- **Plan-time discipline rule 2 (verifier-availability cross-check)**: every verifier T03's Verification section names is co-authored within T03's Steps. No cross-task verifier dependencies. T01 and T02 verifiers (referenced by the phase-suite aggregator) were authored in their respective tasks per plan-time discipline.
- **Plan-time discipline rule 4 (`run-probe.sh` scope discipline)**: T03 does NOT use `scripts/util/run-probe.sh` for any verifier invocation. All verifiers are repo-resident under `tools/verify/` and invoked directly via `bash tools/verify/<name>.sh`.

## Expected Output

- `references/file-formats.md` — modified, fourth row appended to the `### Scope Tags` table; pre-existing rows preserved.
- `references/spec-management.md` — modified, new cross-reference paragraph appended.
- `tools/verify/lib/p00-validate-chunk-frontmatter.sh` — created, validator library exits 1 on out-of-policy frontmatter, exits 0 on in-policy.
- `tools/verify/p00-scope-tag-extension.sh` — created, exits 0.
- `tools/verify/p00-spec-management-crossref.sh` — created, exits 0.
- `tools/verify/p00-taxonomy-rejects-unknown.sh` — created, exits 0 (validator correctly rejects two negative fixtures + accepts the in-policy fixture).
- `tools/verify/p00-phase-suite.sh` — created, exits 0 with `SUMMARY: p00-phase-suite.sh pass=8 fail=0`.

## Notes

Expected verifier output examples (for human readers, not for `auto-loop --step=V` evaluation):

- `bash tools/verify/p00-scope-tag-extension.sh` → stdout ends with `SUMMARY: p00-scope-tag-extension.sh pass=6 fail=0`, exit 0.
- `bash tools/verify/p00-spec-management-crossref.sh` → stdout ends with `SUMMARY: p00-spec-management-crossref.sh pass=3 fail=0`, exit 0.
- `bash tools/verify/p00-taxonomy-rejects-unknown.sh` → stdout ends with `SUMMARY: p00-taxonomy-rejects-unknown.sh pass=3 fail=0`, exit 0.
- `bash tools/verify/p00-phase-suite.sh` → stdout has 8 `PASS: <gate>` lines followed by `SUMMARY: p00-phase-suite.sh pass=8 fail=0`, exit 0.

After the phase-suite gate passes, P00 is complete. P01 (Tier 1 live adapters) becomes the next dispatchable phase — it will replace the four `status=stub` rows in `scripts/dispatch/adapters/format/registry.tsv` with `status=live` and author `markdown.sh`, `pdf.sh`, `docx.sh`, `xlsx.sh`. P05 (graph schema extension) also becomes dispatchable — it will refactor `scripts/knowledge/traverse-graph.sh` to read the edge-type list from `references/reference-edge-types.md` instead of hardcoding `relates_to` / `supersedes`.

Per the planner-template Section-Discipline rule, expected output stays under `## Notes` — everything in `## Verification` is eval'd as a command by `auto-loop.sh --step=V`.

## State Context

- **Current State**: executing
- **Milestone**: M036
- **Phase**: P00
- **Task**: T03-scope-tag-and-validator
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **CON-1 (no-regression)**: pre-existing scope-tag namespaces (`project`, `milestone:M001`, `phase:M001/P02`) are preserved verbatim in `file-formats.md`. The `p00-scope-tag-extension.sh` verifier asserts both the new row's presence AND the pre-existing rows' presence — a regression that drops a pre-existing row would fail the verifier.
- **CON-5 (no-spec-chunk-schema-change)**: T03 adds the `[source:<cite_id>]` namespace additively. Existing spec / memory / reference chunk frontmatter remains valid without modification.
- **Bash 3.2 compatibility**: same as T01/T02 — no `mapfile`, `declare -A`, process substitution, no `$()` containing pipes. Per the AD-19 note in step 3: substitutions-with-pipes *inside* a script body do not trigger the harness heuristic because the harness inspects only the invocation form. The validator script's internal `grep | head | sed` pipeline is fine; the *Verification* invocations in this plan use single-script-file shape.
- **Single-script-file Truth Check shape (AD-19)**: every command in the `## Verification` section above is a single `bash tools/verify/<name>.sh` invocation. No inline compound bash, no plain subshells, no `$(...)` containing pipes at the invocation layer.
- **Plan-time discipline rule 3 (classifier-shape pre-validation)**: the validator-library invocation form `bash tools/verify/lib/p00-validate-chunk-frontmatter.sh` was classified at plan-authoring time as `single-script-file` (verdict from `scripts/verify/lib/shape-classifier.sh::classify_command` — see step 3 note). The verdict is recorded; the validator's internal pipeline does not surface to the classifier because the classifier inspects invocations, not script bodies.
- **Plan-time discipline rule 2 (verifier-availability cross-check)**: every verifier T03's Verification section names is co-authored within T03's Steps. No cross-task verifier dependencies. T01 and T02 verifiers (referenced by the phase-suite aggregator) were authored in their respective tasks per plan-time discipline.
- **Plan-time discipline rule 4 (`run-probe.sh` scope discipline)**: T03 does NOT use `scripts/util/run-probe.sh` for any verifier invocation. All verifiers are repo-resident under `tools/verify/` and invoked directly via `bash tools/verify/<name>.sh`.

### Acceptance Criteria

This task satisfies these phase truths:

- "`references/file-formats.md` `### Scope Tags` table contains a fourth row `[source:<cite_id>]` with pre-existing rows preserved" — T03 modifies; `p00-scope-tag-extension.sh` gates.
- "`references/spec-management.md` contains a cross-reference paragraph pointing to file-formats.md and naming `[source:<cite_id>]`" — T03 modifies; `p00-spec-management-crossref.sh` gates.
- "Taxonomy and tier-policy validators reject out-of-taxonomy categories and out-of-{0,1,2} tiers" — T03 authors `tools/verify/lib/p00-validate-chunk-frontmatter.sh` + `p00-taxonomy-rejects-unknown.sh`; the negative-test driver gates.
- "`bash tools/verify/p00-phase-suite.sh` invokes all eight P00 gates in order, exits 0 iff every sub-gate passes" — T03 authors the aggregator.

### Files To Touch

- `references/reference-taxonomy.md` (create) — T01
- `references/reference-frontmatter-contract.md` (create) — T01
- `references/reference-source-types.yaml` (create) — T01
- `references/reference-edge-types.md` (create) — T02
- `scripts/dispatch/adapters/format/registry.tsv` (create) — T02
- `references/file-formats.md` (modify — append fourth row to `### Scope Tags` table) — T03
- `references/spec-management.md` (modify — append cross-reference paragraph) — T03
- `tools/verify/p00-taxonomy-shape.sh` (create) — T01
- `tools/verify/p00-frontmatter-contract-shape.sh` (create) — T01
- `tools/verify/p00-source-types-shape.sh` (create) — T01
- `tools/verify/p00-edge-types-shape.sh` (create) — T02
- `tools/verify/p00-adapter-registry-shape.sh` (create) — T02
- `tools/verify/p00-scope-tag-extension.sh` (create) — T03
- `tools/verify/p00-spec-management-crossref.sh` (create) — T03
- `tools/verify/p00-taxonomy-rejects-unknown.sh` (create) — T03
- `tools/verify/lib/p00-validate-chunk-frontmatter.sh` (create) — T03
- `tools/verify/p00-phase-suite.sh` (create) — T03

<!-- The phase plan and task plan files themselves (this file +
     tasks/T0[1-3]-*-PLAN.md) are written by the planner, not by the
     executor — they are not listed here. -->

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