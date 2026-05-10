---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T01-tier2-head-drop (Phase P04, Milestone M018)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~600 | required |
| Upstream Context | 981-1139 | ~3400 | required |
| Task Plan | 1141-1770 | ~10400 | required |
| State Context | 1772-1778 | ~100 | required |
| First-Turn Completeness | 1780-1824 | ~1600 | required |
| **Total** | | **~26900** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 656
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
hit_count: 656
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
hit_count: 656
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
hit_count: 656
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
hit_count: 584
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
hit_count: 584
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
hit_count: 584
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
hit_count: 656
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
hit_count: 584
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
hit_count: 584
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
hit_count: 584
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
hit_count: 656
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
hit_count: 656
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
hit_count: 656
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
hit_count: 584
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
hit_count: 584
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
hit_count: 584
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
hit_count: 656
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
hit_count: 584
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
hit_count: 584
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
hit_count: 656
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
hit_count: 656
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
hit_count: 584
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
hit_count: 584
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
hit_count: 584
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
hit_count: 239
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
hit_count: 239
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
hit_count: 239
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
hit_count: 232
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
hit_count: 232
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
hit_count: 222
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
task: "T01"
phase: "P04"
milestone: "M018"
name: "Tier 2 head-drop function + boundary-refusal logic in build-context.sh + tier2 config accessors + additive tier2_savings_tokens emitter field"
depends_on: []
---

## Prerequisites

- P02 (knowledge-aware filter + preservation-check library) and P03 (Tier 1 microcompact) have shipped:
  - `scripts/lib/preservation-check.sh` exports `pres_check_section <section_id> <pre_file> <post_file> [tier]` (strict-multiplicity for `tier1`/`tier2`, at-least-once for `tier3`), `pres_emit_violation <tier> <section> <pattern> <log_file>`, the parallel arrays `PRES_PATTERNS_REGEX` and `PRES_PATTERN_NAMES` (10 entries), and `pres_density_pre_check` (Tier 3 only — not used by T01). T01 sources this library and uses `pres_check_section` + `pres_emit_violation` plus reads `PRES_PATTERNS_REGEX` directly for the boundary-refusal detector.
    - Critical detail: `PRES_PATTERNS_REGEX[1]` is `^\`{3,}[a-zA-Z0-9_-]*$` — the MIT-01 4+-backtick nested code-fence regex. The boundary-refusal detector MUST honor this (a code fence opened with 4+ backticks crosses ordinary 3-backtick boundaries and would be split unsafely if the detector only looked for 3-backtick rows).
  - `scripts/lib/knowledge-filter.sh` exports `kf_resolve_config_path <project_root>`, `kf_read_compression_scalar <cfg_file> <key>`, the existing `kf_get_compression_enabled`, `kf_get_knowledge_filter_enabled`, and the parallel `kf_get_tier1_{enabled,inline_threshold_tokens,preview_lines,cache_dir}` accessors. T01 adds `kf_get_tier2_{enabled,section_budget_tokens,protected_tail_ratio}` mirroring the tier1 shape verbatim (same default-when-empty case, same printf-newline contract).
  - `scripts/dispatch/build-context.sh` carries:
    - Config reads at lines ~189–192 — `TIER1_ENABLED`, `TIER1_INLINE_THRESHOLD_TOKENS`, `TIER1_PREVIEW_LINES`, `TIER1_CACHE_DIR`. T01 inserts `TIER2_*` reads immediately below this block.
    - `_bc_apply_knowledge_filter` (line 534) and `_bc_apply_tier1` (line 588) — dispatch-internal helpers. T01 adds `_bc_apply_tier2` adjacent to `_bc_apply_tier1` (immediately below it, before `_bc_gather_decisions` at line 761).
    - `_bc_emit_payload_breakdown` (line 1319) — the JSONL emitter that already carries `filter_dropped_tokens`, `tier1_savings_tokens`, and `tier1_invocations`. T01 extends it with one additive integer field `tier2_savings_tokens`.
    - Call-site at line 1723: `_bc_apply_tier1 "$PAYLOAD_CAPTURE" || true` runs against the assembled payload BEFORE the `cat "$PAYLOAD_CAPTURE"` (line 1724) and BEFORE `_bc_emit_payload_breakdown` (line 1725). T01 inserts `_bc_apply_tier2 "$PAYLOAD_CAPTURE" || true` IMMEDIATELY AFTER the tier1 call.
    - `PAYLOAD_CAPTURE="$TMPDIR_BUILD/_payload_capture.txt"` (line 1716) — the capture file the pipeline rewrites in place.
- `compression:` block in `.orchestrator/config.yml` already carries `compression.enabled`, `compression.knowledge_filter.*`, `compression.underperformance.*`, and `compression.tier1.*`. T01 appends a new `compression.tier2.*` sub-block under the existing `compression:` map; preserve every existing key byte-identical. Same change in `templates/orchestrator-config-default.yml`.
- `references/compression-grammar.md` `## Tier: tier2` (lines 191–211) is the contract:
  - applies-to: `payload-section-body` for `Knowledge`, `Task Plan`, `Upstream Context`. Other sections out of scope.
  - preserves: all cross-tier vocabulary patterns; the trailing `protected_tail_ratio` of the section byte-identical; the section heading line itself (head-drop never deletes the heading); the in-band tier2 marker once emitted (downstream tier3 wraps but never mutates kvpairs).
  - savings ceiling (P00 probe, 80% CI): low 25.33% / mean 25.49% / high 25.68%; model assumption is "head-drops ~40% of EXCESS over the 1500-tok tail threshold on any section that exceeds it (preserves last 1500 tok verbatim)".
  - failure semantics: self-check on output via `pres_check_section ... tier2`; on failure, pass section through unmodified plus `tier_preservation_violation` JSONL emit. Protected-tail breach (rare/should-be-impossible) emits a distinct `tier2_preservation_breach` record — T01 does NOT need to emit this in normal operation since boundary-refusal makes the breach unreachable; the record type is reserved for the grammar contract and exercised in T02's verifiers as a documented-but-unreachable path (no behavioral assertion required).
- `tests/fixtures/m018-p02-baseline-payload.golden.txt` is the byte-identity disable-flag golden. T01 must not break it: when `compression.enabled: false`, the entire pipeline (filter + tier1 + tier2) short-circuits and the golden remains byte-identical. T02's `m018-p04-tier2-disable-flag.sh` verifier asserts this.
- AP-009 (`scripts/hooks/pre-bash-shape-guard.sh`) bans: compound chains > 2; plain subshells; `$(...|...)` shell forms; process substitution `<(...)` / `>(...)`. Bash 3.2 — no `declare -A`. T01 follows MEM004's dispatch-internal carve-out (build-context.sh `_bc_*` helpers may use awk/pipes inside their bodies — the carve-out applies to dispatch-internal helpers, NOT to verifier scripts and NOT to agent-facing payload bytes).

## Description

Land Tier 2 snip inside `scripts/dispatch/build-context.sh`. After T01:

1. The build-context.sh assembled payload (captured to `$PAYLOAD_CAPTURE` after Tier 1 runs) passes through a Tier 2 head-drop stage that detects each in-scope section (`## Knowledge`, `## Task Plan`, `## Upstream Context`), measures the section's body-token count, and — if it exceeds `compression.tier2.section_budget_tokens` (default 1500) — head-drops the leading bytes that exceed the budget while preserving the trailing `compression.tier2.protected_tail_ratio` (default 0.3) of the section's pre-snip body byte-identical. The section heading line and any frontmatter that immediately follows the heading are never deleted.
2. The head-drop boundary is computed as a **line-aligned cut point**: T2 walks backward from the byte the budget would naively cut at, looking for a line whose start does not split a preserved-pattern row, and retreats further if the cut line lies inside a multi-line preserved span (frontmatter delimiter to delimiter, opening 4+-backtick code-fence to its matching closing fence at the same backtick-count). When no safe boundary exists in the head-drop range, the section passes through unmodified plus a `tier_preservation_violation` JSONL record names tier=`tier2` and the offending pattern (the cross-tier label of the spanning regex).
3. After the head-drop completes, `pres_check_section "<section>" <pre_file> <post_file> tier2` runs over the section bodies. On failure, the section reverts to the pre-snip body and `pres_emit_violation` records the violation. Strict-multiplicity tier2 semantics are exactly what the boundary-refusal detector is built to satisfy: any preserved-pattern occurrence inside the dropped head would change the post-vs-pre count by at least one and the self-check would catch it. The boundary-refusal detector is the "fail-fast before the snip" guard; the self-check is the "fail-safe after the snip" guard.
4. Tier 2 emits an in-band marker IMMEDIATELY AFTER the section heading line of every section it modifies:
   `<!-- compressed:tier2 head_dropped=<dropped_tokens> protected_tail_ratio=<R> -->`
   The marker is on its own line. The kvpair grammar matches the cross-tier vocabulary entry `<!-- compressed:tier[0-9]+ [^>]*-->` verbatim. `<dropped_tokens>` is the integer-quartile-tokens count of the dropped head bytes; `<R>` is the configured ratio formatted with two-decimal precision (e.g., `0.30`).
5. `_bc_emit_payload_breakdown` is extended with one additive integer field: `tier2_savings_tokens` (sum of dropped-head tokens across all in-scope sections in this dispatch). Pre-T2 records remain valid JSON; rollups read missing fields as 0.
6. `compression.tier2.*` config keys land in `.orchestrator/config.yml` and `templates/orchestrator-config-default.yml`:
   - `compression.tier2.enabled` (default `true`)
   - `compression.tier2.section_budget_tokens` (default `1500`)
   - `compression.tier2.protected_tail_ratio` (default `0.3`)
7. Disable semantics:
   - `compression.enabled: false` → entire pipeline short-circuits (P02/P03 contract preserved).
   - `compression.tier2.enabled: false` → only Tier 2 short-circuits; the knowledge filter and Tier 1 still run.
   - `ORCH_OVERRIDE_COMPRESSION_ENABLED=false` env var still wins over both (existing test seam).

T01 does NOT ship the verifiers (T02), the fixtures (T02), the fixture-staging helper (T02), or the P04-SUMMARY (T02). T01 ships ONLY the production code that T02's verifiers exercise.

### Section grammar (canonical input shape T01 detects)

The build-context.sh-assembled payload organizes top-level sections by `^## <Section>` markdown headings. The in-scope section names per the grammar contract are:

```
## Knowledge
## Task Plan
## Upstream Context
```

A section body extends from the line AFTER its heading up to (but not including) the next `^## ` heading or end-of-file. T01's head-drop operates on the section body only — the heading line and any blank line immediately following it are never deleted.

### Boundary-refusal detector (the load-bearing inner loop)

The naive head-drop boundary is the byte index inside the section body at which keeping the suffix gives a `protected_tail_ratio`-sized preserved tail (default 0.3 of the pre-snip body). Computed in characters: `cut_byte = floor(body_len * (1 - protected_tail_ratio))`. The naive cut may land inside a preserved span. T01's detector retreats the cut to the nearest safe line boundary above the protected tail, refusing the snip outright if no safe boundary exists.

A line is **unsafe to cut at** when the line is part of an open multi-line preserved span. Multi-line spans T01 detects:

1. **YAML frontmatter delimiters** — pairs of `^---$` lines. A cut between the opening and closing `---` would orphan one delimiter.
2. **Code fences** — pairs of `^\`{3,}[a-zA-Z0-9_-]*$` lines at matching backtick-count (MIT-01: 4+-backtick fences nest inside 3-backtick fences and only close at a matching 4+-backtick line). A cut between the opening and closing fence would orphan the opener.
3. **In-band tier markers** — single-line `<!-- compressed:tier[0-9]+ [^>]*-->`. A previously-emitted marker (from a prior tier in the pipeline) must not be split. Single-line spans count as "unsafe at cut" only if the cut would land mid-line — line-aligned cuts cannot split a single-line marker, so marker-handling reduces to the line-aligned guarantee.

Single-line preserved patterns (paths, MEM IDs, command names, URLs, JSONL records, scaffold markers) are protected automatically by line-aligned cuts: no cut between two complete lines can split a single-line pattern. The detector only needs the multi-line span tracker.

**Algorithm:**

```
1. Walk the section body line-by-line, tracking nesting state for frontmatter
   (in_fm: bool) and code fences (fence_open_ticks: int, 0 when closed).
2. For each line index, record whether it is "inside a multi-line span" (i.e.,
   in_fm == 1 OR fence_open_ticks > 0 at the START of that line).
3. The naive cut byte determines the naive cut line — the line at which the
   cumulative byte count first crosses cut_byte.
4. Walk DOWN from the naive cut line toward line 0 looking for the first line
   whose "inside a multi-line span" flag is FALSE. That line's start byte is
   the safe head-drop boundary.
5. If the walk reaches the section heading line (i.e., no safe boundary above
   the protected tail), the section is passed through unmodified plus a
   tier_preservation_violation record names tier=tier2 and pattern as the
   spanning vocabulary entry (yaml-frontmatter-delim or code-fence).
```

The walk-down direction is correct: we want a cut at or above the naive cut byte (not below), because cutting below would shrink the protected tail beyond the configured ratio. If retreating eats into more than the budget allows the head-drop to still produce savings, T2 still emits the smaller savings — the budget is a maximum, not a minimum (see grammar contract: "budget" framing, not "target reduction").

### In-band marker emission

After the head-drop, the section is reassembled as:

```
## <Section>
<!-- compressed:tier2 head_dropped=<dropped_tokens> protected_tail_ratio=<R> -->
<verbatim post-cut bytes — the trailing protected_tail_ratio of the pre-snip body>
```

Where `<dropped_tokens>` is `tok(dropped_chars)` using the same `int((c+3)/4)` quartile estimator that Tier 1 uses (mirrors `chars_to_tokens_quartile` from `scripts/lib/pricing.sh`). `<R>` is the configured `protected_tail_ratio` formatted as `printf "%.2f"`.

The blank line that typically follows the section heading is preserved if it was present in the pre-snip body — the marker is inserted ABOVE that blank line so the visual structure stays consistent.

## Steps

### Step 1 — Append `compression.tier2.*` to `.orchestrator/config.yml` and `templates/orchestrator-config-default.yml`

Use `Edit` to append after the existing `compression.tier1:` block in both files. Insert below it (still nested under `compression:`):

```yaml
  # M018/P04 — Tier 2 snip (head-drop with protected tail ratio).
  # When an in-scope section body's body-token count exceeds
  # `section_budget_tokens`, the leading bytes are head-dropped while the
  # trailing `protected_tail_ratio` of pre-snip section bytes survives
  # byte-identical. An in-band marker
  # `<!-- compressed:tier2 head_dropped=N protected_tail_ratio=R -->` names
  # the snip. The cut is line-aligned and refuses to split frontmatter,
  # 4+-backtick code fences, or other multi-line preserved spans
  # (cross-tier vocabulary in `scripts/lib/preservation-check.sh`). In-scope
  # sections: `## Knowledge`, `## Task Plan`, `## Upstream Context`.
  tier2:
    enabled: true
    section_budget_tokens: 1500
    protected_tail_ratio: 0.3
```

Indentation: two-space, matching the existing `knowledge_filter:`, `underperformance:`, and `tier1:` siblings.

### Step 2 — Add `kf_get_tier2_*` accessors to `scripts/lib/knowledge-filter.sh`

Locate the existing `kf_get_tier1_cache_dir` function (line ~370) and append the three new accessors immediately below it, mirroring the tier1 pattern verbatim:

```bash
# ---------------------------------------------------------------------------
# kf_get_tier2_<key> <project_root>  ->  scalar
# M018/P04/T01: Tier 2 snip config accessors. Each returns the scalar value
# from compression.tier2.<key> or the documented default when absent.
# ---------------------------------------------------------------------------
kf_get_tier2_enabled() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" tier2.enabled)"
  if [ "$val" = "false" ]; then
    printf 'false\n'
  else
    printf 'true\n'
  fi
}

kf_get_tier2_section_budget_tokens() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" tier2.section_budget_tokens)"
  if [ -z "$val" ]; then
    printf '1500\n'
  else
    printf '%s\n' "$val"
  fi
}

kf_get_tier2_protected_tail_ratio() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" tier2.protected_tail_ratio)"
  if [ -z "$val" ]; then
    printf '0.3\n'
  else
    printf '%s\n' "$val"
  fi
}
```

Also extend the file's top-of-file `Public surface` comment block to list the three new accessors (cosmetic — keeps the documented exports in sync with code).

### Step 3 — Add `TIER2_*` config reads to `build-context.sh`

In `scripts/dispatch/build-context.sh`, locate the existing tier1 config-read block (line ~189–192). Add immediately below the `TIER1_CACHE_DIR=` line:

```bash
# M018/P04/T01: Tier 2 snip config.
TIER2_ENABLED="$(kf_get_tier2_enabled "$PROJECT_ROOT")"
TIER2_SECTION_BUDGET_TOKENS="$(kf_get_tier2_section_budget_tokens "$PROJECT_ROOT")"
TIER2_PROTECTED_TAIL_RATIO="$(kf_get_tier2_protected_tail_ratio "$PROJECT_ROOT")"
```

(Use the `kf_get_tier2_*` accessors exactly as the surrounding tier1 reads do — same shape, same defaults-via-accessor contract.)

### Step 4 — Author the Tier 2 head-drop function `_bc_apply_tier2`

Place this function adjacent to `_bc_apply_tier1` (immediately below it; before `_bc_gather_decisions` at line ~761). The function reads the captured-payload file path on argument 1 and rewrites the file in place via a temp file + `mv` for atomicity. It returns 0 on success and on no-op short-circuit; it returns 0 (passthrough) on internal errors and emits a one-line stderr warning if needed. Stats are written to `$TMPDIR_BUILD/_tier2_stats.txt` for the emitter to read.

```bash
# M018/P04/T01: Tier 2 snip — section head-drop with protected tail.
#
# Argument 1: path to the captured payload file (already through Tier 1, prior
# to _bc_emit_payload_breakdown). The function rewrites the file in place
# when head-drop fires; otherwise leaves it untouched.
#
# Side-effect outputs:
#   - Writes a stats line to $TMPDIR_BUILD/_tier2_stats.txt of the form:
#       savings_tokens=<N>
#     The caller (_bc_emit_payload_breakdown) reads this file to populate
#     the additive `tier2_savings_tokens` field.
#
# Short-circuits (passthrough; stats file written with savings_tokens=0):
#   - $COMPRESSION_ENABLED != "true"
#   - $TIER2_ENABLED != "true"
#   - The capture file contains zero in-scope `^## ` sections.
#   - Every in-scope section's body token-count is at or below
#     $TIER2_SECTION_BUDGET_TOKENS.
#
# Boundary-refusal: when the line-aligned cut would land inside a
# multi-line preserved span (frontmatter `^---$` pair or `^`{3,}[a-zA-Z0-9_-]*$`
# code-fence pair at matching backtick-count), the cut retreats above the
# span; if no safe boundary exists at or above the naive cut byte and
# below the protected tail, the section passes through unmodified plus a
# tier_preservation_violation JSONL emit (tier=tier2, pattern=spanning
# vocabulary label).
#
# Preservation self-check:
#   - After head-drop, runs pres_check_section "<section>" <pre> <post> tier2
#     against the section bodies (pre = pre-snip body file, post = post-snip
#     body file). On failure, restores the pre-snip body byte-identical and
#     emits tier_preservation_violation via pres_emit_violation.
#
# AP-009 compliance: no compound chains > 2; no plain subshells; no
# $(...|...). Awk does the heavy lifting in a single invocation. The
# pres_check_section invocation is the standard library shape (same as
# tier1's call).
# MEM004 carve-out: dispatch-internal helper, like _bc_apply_tier1.
_bc_apply_tier2() {
  local capture_file="$1"
  if [ "$COMPRESSION_ENABLED" != "true" ] || [ "$TIER2_ENABLED" != "true" ]; then
    return 0
  fi
  if [ ! -f "$capture_file" ]; then
    return 0
  fi

  local pre_file out_file stats_file
  pre_file="$TMPDIR_BUILD/_tier2_pre.txt"
  out_file="$TMPDIR_BUILD/_tier2_out.txt"
  stats_file="$TMPDIR_BUILD/_tier2_stats.txt"
  cp "$capture_file" "$pre_file"

  # Single awk pass:
  #   - Stream the input line by line.
  #   - Buffer each in-scope section's body (between its `## <Section>`
  #     heading and the next `## ` heading or EOF).
  #   - Track multi-line preserved spans line-by-line so each buffered line
  #     carries a "safe-to-cut-above-this-line" flag.
  #   - At section close, decide whether to head-drop:
  #       body_tokens > budget? compute naive cut, retreat to safe boundary,
  #       emit `## <Section>\n<!-- compressed:tier2 ... -->\n<tail>` or pass
  #       through verbatim plus emit a violation marker for the bash caller
  #       to pick up (via $TMPDIR_BUILD/_tier2_violations.txt).
  #
  # Inputs threaded as awk variables:
  #   budget   — section_budget_tokens
  #   ratio    — protected_tail_ratio (e.g. 0.3)
  #   stf      — stats_file
  #   vlf      — violations_file
  awk -v budget="$TIER2_SECTION_BUDGET_TOKENS" \
      -v ratio="$TIER2_PROTECTED_TAIL_RATIO" \
      -v stf="$stats_file" \
      -v vlf="$TMPDIR_BUILD/_tier2_violations.txt" \
      '
      function tok(c) { return int((c + 3) / 4) }
      function in_scope(name) {
        return (name == "Knowledge" || name == "Task Plan" || name == "Upstream Context")
      }
      function flush_section(   body_chars, body_tokens, cut_byte, i, cum, cut_line, j, drop_chars, drop_tokens, head_safe, fence_state, fm_state) {
        # body_buf has section body in body_lines[1..body_n], joined with
        # newlines on emit. body_unsafe[i] == 1 when line i sits inside an
        # open multi-line preserved span.
        if (!in_scope(sec_name)) {
          # Out-of-scope: emit as captured.
          printf "%s", sec_raw
          sec_name=""; sec_raw=""; body_n=0
          return
        }
        body_chars = 0
        for (i = 1; i <= body_n; i++) {
          # +1 for the newline that joins back at emit time.
          body_chars += length(body_lines[i]) + 1
        }
        body_tokens = tok(body_chars)
        if (body_tokens <= budget + 0) {
          # Under budget — pass through verbatim.
          printf "%s", sec_raw
          sec_name=""; sec_raw=""; body_n=0
          return
        }
        # Naive cut byte = floor(body_chars * (1 - ratio)).
        cut_byte = int(body_chars * (1.0 - ratio))
        # Walk forward in body lines accumulating until we cross cut_byte.
        cum = 0
        cut_line = body_n  # default sentinel (will retreat below)
        for (i = 1; i <= body_n; i++) {
          if (cum + length(body_lines[i]) + 1 > cut_byte) {
            cut_line = i
            break
          }
          cum += length(body_lines[i]) + 1
        }
        # Retreat: walk DOWN from cut_line toward line 1 until body_unsafe[i] == 0.
        head_safe = 0
        for (j = cut_line; j >= 1; j--) {
          if (body_unsafe[j] != 1) {
            head_safe = j
            break
          }
        }
        if (head_safe == 0) {
          # No safe boundary found — pass through unmodified, log violation.
          printf "%s", sec_raw
          # Find the spanning pattern label (best-effort).
          if (body_unsafe[cut_line] == 1) {
            printf "section=%s pattern=%s\n", sec_name, body_unsafe_label[cut_line] >> vlf
          } else {
            printf "section=%s pattern=%s\n", sec_name, "unknown" >> vlf
          }
          close(vlf)
          sec_name=""; sec_raw=""; body_n=0
          return
        }
        # Compute drop_chars = cumulative bytes of lines [1..head_safe-1].
        drop_chars = 0
        for (i = 1; i < head_safe; i++) {
          drop_chars += length(body_lines[i]) + 1
        }
        if (drop_chars == 0) {
          # Cut at line 1 means nothing actually dropped — pass through.
          printf "%s", sec_raw
          sec_name=""; sec_raw=""; body_n=0
          return
        }
        drop_tokens = tok(drop_chars)
        # Emit: heading line + marker + post-cut body.
        printf "%s\n", sec_heading
        printf "<!-- compressed:tier2 head_dropped=%d protected_tail_ratio=%.2f -->\n", drop_tokens, ratio + 0
        for (i = head_safe; i <= body_n; i++) {
          printf "%s", body_lines[i]
          if (i < body_n) {
            printf "\n"
          }
        }
        # Trailing newline iff the captured section ended with one (sec_raw
        # already encoded that; we mirror it by checking the last char of
        # the captured raw).
        savings_tok += drop_tokens
        sec_name=""; sec_raw=""; body_n=0
      }
      function open_section(line,   m) {
        # Any prior section is flushed by the caller before open_section is
        # called. Parse `## <Section>` heading.
        if (match(line, /^## [A-Za-z][^\n]*$/)) {
          sec_heading = line
          # Section name = heading minus the `## ` prefix; strip any
          # ` (N entries)`-style suffix introduced by the assembler.
          sub(/^## /, "", line)
          # Match the bare section identifier (one of Knowledge / Task Plan /
          # Upstream Context) by prefix-string compare to keep awk simple.
          if (line ~ /^Knowledge( |$)/)        { sec_name = "Knowledge" }
          else if (line ~ /^Task Plan( |$)/)   { sec_name = "Task Plan" }
          else if (line ~ /^Upstream Context( |$)/) { sec_name = "Upstream Context" }
          else                                  { sec_name = "OTHER" }
          sec_raw = sec_heading "\n"
          body_n = 0
          # Reset multi-line span trackers — sections are independent.
          fm_open = 0
          fence_open_ticks = 0
        }
      }
      BEGIN { sec_name=""; sec_raw=""; body_n=0; savings_tok=0; fm_open=0; fence_open_ticks=0 }
      /^## / {
        # New section header → flush any prior section, then open.
        if (sec_name != "") { flush_section() }
        open_section($0)
        next
      }
      sec_name == "" {
        # Pre-first-section bytes (manifest, frontmatter) — emit verbatim.
        print
        next
      }
      {
        # Body line of current section.
        body_n += 1
        body_lines[body_n] = $0
        # Compute "is this line INSIDE a multi-line span at the START of the
        # line?" — that is the unsafe flag the cut-retreat walker reads.
        body_unsafe[body_n] = (fm_open == 1 || fence_open_ticks > 0) ? 1 : 0
        body_unsafe_label[body_n] = (fm_open == 1) ? "yaml-frontmatter-delim" : (fence_open_ticks > 0 ? "code-fence" : "")
        # Update span state AFTER recording the flag (so the line that opens
        # a span is itself safe — the cut may land at the OPENER, but a cut
        # below the opener falls inside the span and is unsafe).
        if ($0 == "---") {
          if (fm_open == 0) { fm_open = 1 } else { fm_open = 0 }
        } else if (match($0, /^`{3,}[a-zA-Z0-9_-]*$/)) {
          # Count backticks at start.
          ticks = 0
          for (k = 1; k <= length($0); k++) {
            if (substr($0, k, 1) == "`") { ticks += 1 } else { break }
          }
          if (fence_open_ticks == 0) {
            fence_open_ticks = ticks
          } else if (ticks == fence_open_ticks) {
            # Matching closer — close.
            fence_open_ticks = 0
          }
          # Mismatched ticks inside an open fence — leave fence_open_ticks
          # unchanged (the inner line is just content of the outer fence).
        }
        # sec_raw mirrors the captured bytes for the verbatim-passthrough path.
        sec_raw = sec_raw $0 "\n"
        next
      }
      END {
        if (sec_name != "") { flush_section() }
        printf "savings_tokens=%d\n", savings_tok > stf
        close(stf)
      }
      ' "$pre_file" > "$out_file"

  # Pick up any boundary-refusal violations the awk pass logged.
  if [ -f "$TMPDIR_BUILD/_tier2_violations.txt" ]; then
    if type pres_emit_violation >/dev/null 2>&1; then
      local _t2_log _vline _vsec _vpat
      _t2_log="$ORCH_ROOT/milestones/$MILESTONE_ID/execution-log.jsonl"
      if [ ! -d "$ORCH_ROOT/milestones/$MILESTONE_ID" ] && [ -d "$ORCH_ROOT/phases" ]; then
        _t2_log="$ORCH_ROOT/execution-log.jsonl"
      fi
      while IFS= read -r _vline; do
        # _vline shape: `section=<name> pattern=<label>`.
        _vsec="$(printf '%s' "$_vline" | sed -n 's/^section=\([^ ]*\).*$/\1/p')"
        _vpat="$(printf '%s' "$_vline" | sed -n 's/.* pattern=\(.*\)$/\1/p')"
        pres_emit_violation "tier2" "$_vsec" "$_vpat" "$_t2_log" 2>/dev/null || true
      done < "$TMPDIR_BUILD/_tier2_violations.txt"
    fi
    rm -f "$TMPDIR_BUILD/_tier2_violations.txt" 2>/dev/null || true
  fi

  # Preservation self-check on the rewritten payload as a whole. Strict
  # tier2 multiplicity — every preserved-pattern occurrence in the pre
  # payload must occur in the post payload (the head-drop of an in-scope
  # section legitimately removes content; the boundary-refusal detector
  # is the guarantee that the removed content carried zero preserved
  # patterns. If the self-check disagrees, the snip is undone.)
  if type pres_check_section >/dev/null 2>&1; then
    if ! pres_check_section "tier2" "$pre_file" "$out_file" tier2 >/dev/null 2>&1; then
      if type pres_emit_violation >/dev/null 2>&1; then
        local _t2_log2
        _t2_log2="$ORCH_ROOT/milestones/$MILESTONE_ID/execution-log.jsonl"
        if [ ! -d "$ORCH_ROOT/milestones/$MILESTONE_ID" ] && [ -d "$ORCH_ROOT/phases" ]; then
          _t2_log2="$ORCH_ROOT/execution-log.jsonl"
        fi
        pres_emit_violation "tier2" "payload" "cross-tier" "$_t2_log2" 2>/dev/null || true
      fi
      cp "$pre_file" "$capture_file"
      printf 'savings_tokens=0\n' > "$stats_file"
      return 0
    fi
  fi

  # Atomic in-place replace.
  mv "$out_file" "$capture_file"
  return 0
}
```

Notes on the awk implementation:

- The `body_unsafe` flag is computed for each body line at the START of the line, BEFORE the line itself is processed for span-open/close. That gives the correct invariant: "if I cut JUST ABOVE this line, am I inside an open span?" The line that OPENS a fence has `body_unsafe[i] == 0` because the span was not yet open at the start of that line — cutting above the opener is safe (the opener and everything below it falls into the protected tail). Cutting below the opener but above the closer is unsafe.
- `body_unsafe_label[]` records which span class is open at each unsafe line so the violation message names the right cross-tier pattern.
- The 4+-backtick detection (MIT-01) is built into the regex `^\`{3,}[a-zA-Z0-9_-]*$` and the explicit `ticks == fence_open_ticks` matching: a 3-backtick line CANNOT close an open 4-backtick fence (different tick count), so nested fences are tracked correctly by tick-count.
- `protected_tail_ratio` is forced to numeric via `ratio + 0` in arithmetic and `printf "%.2f"` for the marker emit. The accessor returns the textual scalar (e.g., `0.3`), and awk converts on first arithmetic use.
- The `END` block writes `savings_tokens=<N>` to `$stats_file`; the emitter (Step 6) reads that file with the same defaulting pattern as the existing `_tier1_stats.txt` reader.
- `sec_raw` accumulates the captured section bytes for the verbatim-passthrough path (under-budget sections, out-of-scope sections, and refusal cases). This avoids re-stitching `body_lines[]` with newline-joining quirks for the passthrough path.

### Step 5 — Wire `_bc_apply_tier2` into the dispatch path

`build-context.sh` already calls `_bc_apply_tier1 "$PAYLOAD_CAPTURE" || true` at line 1723 between `_bc_assemble_manifest_and_emit` and `cat "$PAYLOAD_CAPTURE"`. Insert the Tier 2 call IMMEDIATELY AFTER the tier1 call:

```bash
_bc_apply_tier1 "$PAYLOAD_CAPTURE" || true
# M018/P04/T01: Tier 2 snip runs against the post-tier1 captured payload BEFORE
# the receiving agent sees the bytes (cat below) and BEFORE the breakdown
# emitter samples it (so emitter section sizes reflect post-tier2 reality).
# Short-circuits when `compression.enabled: false` (P02 byte-identity contract)
# or when `compression.tier2.enabled: false` (per-tier disable).
_bc_apply_tier2 "$PAYLOAD_CAPTURE" || true
cat "$PAYLOAD_CAPTURE"
_bc_emit_payload_breakdown "$PAYLOAD_CAPTURE" || true
```

(The existing `_bc_emit_payload_filter || true` and `_bc_emit_compression_underperformance || true` at lines 1726–1727 are unaffected.)

### Step 6 — Extend `_bc_emit_payload_breakdown` with the `tier2_savings_tokens` additive field

In `_bc_emit_payload_breakdown` (line ~1319), find the existing `tier1_savings_tokens` read block (around line 1407+ — it reads `$TMPDIR_BUILD/_tier1_stats.txt`). Add a sibling block immediately after it:

```bash
  # M018/P04/T01 (CON-5): additive `tier2_savings_tokens` field. Reads
  # $TMPDIR_BUILD/_tier2_stats.txt written by _bc_apply_tier2. Defaults to 0
  # when tier2 was disabled, the file is absent, or no in-scope section
  # exceeded the budget.
  local tier2_savings_tokens=0
  local _bc_pb_t2_stats="$TMPDIR_BUILD/_tier2_stats.txt"
  if [ -f "$_bc_pb_t2_stats" ]; then
    tier2_savings_tokens="$(awk '{
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^savings_tokens=/) { sub("savings_tokens=", "", $i); print $i; exit }
      }
    }' "$_bc_pb_t2_stats")"
    if [ -z "$tier2_savings_tokens" ]; then tier2_savings_tokens=0; fi
  fi
```

Then update the printf format string at line ~1436 to insert `"tier2_savings_tokens":%d,` IMMEDIATELY AFTER the `tier1_invocations` field (preserving every other field in current order):

```bash
  printf '{"record_type":"payload_breakdown","unitId":"%s/%s/%s","milestone":"%s","phase":"%s","task":"%s","payload_chars":%d,"payload_tokens_estimate":%d,"token_estimate_method":"char-quartile","section_tokens":{%s},"filter_dropped_tokens":%d,"tier1_savings_tokens":%d,"tier1_invocations":%d,"tier2_savings_tokens":%d,"model":"%s","source":"estimate","timestamp":"%s"}\n' \
    "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" \
    "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" \
    "$payload_chars" "$payload_tokens" \
    "$section_tokens_json" "$filter_dropped_tokens" \
    "$tier1_savings_tokens" "$tier1_invocations" \
    "$tier2_savings_tokens" \
    "$model" "$ts" \
    >> "$log_file" 2>/dev/null || {
    printf 'build-context.sh: payload_breakdown append failed on %s\n' "$log_file" >&2
    return 0
  }
```

CON-5 invariants: pre-T2 records remain valid JSON; T01 only ADDS one field. Rollups treat missing fields as 0.

### Step 7 — Self-test: dispatch the build-context.sh against the existing P03 fixture

Run:

```
bash scripts/dispatch/build-context.sh M018 P04 T01-self-test
```

against the current state with `compression.enabled: true`. The execution-log.jsonl should now show a `payload_breakdown` record with `tier2_savings_tokens` field present (0 if no in-scope section exceeded the budget — that's fine; T02's verifiers exercise a fixture with real over-budget sections).

Run:

```
ORCH_OVERRIDE_COMPRESSION_ENABLED=false bash scripts/dispatch/build-context.sh M018 P04 T01-self-test
```

The captured payload bytes must remain byte-identical to the pre-P04 path under disable. (T02 wires the golden-payload regression verifier; T01's self-check is an interactive sanity check.)

Also confirm `bash -n scripts/dispatch/build-context.sh` succeeds (syntax check).

## Must-Haves

- Tier 2 head-drop fires on in-scope sections (`## Knowledge`, `## Task Plan`, `## Upstream Context`) whose body-token count exceeds `compression.tier2.section_budget_tokens`, removing head bytes above the budget while leaving the trailing `protected_tail_ratio` byte-identical (T02 verifier `m018-p04-tier2-head-drop.sh`).
- Tier 2 emits the in-band `<!-- compressed:tier2 head_dropped=N protected_tail_ratio=R -->` marker immediately after every modified section's heading line (T02 verifier `m018-p04-tier2-marker.sh`).
- Boundary-refusal: when the line-aligned cut would split a 4+-backtick code fence or a frontmatter delimiter pair, the cut retreats above the span; with no safe boundary, the section passes through unmodified plus a `tier_preservation_violation` (tier=`tier2`) JSONL emit (T02 verifier `m018-p04-tier2-boundary-refusal.sh`).
- `payload_breakdown` records carry an additive integer `tier2_savings_tokens` field; pre-T2 records remain valid JSON (T02 verifier `m018-p04-tier2-emitter-additivity.sh`).
- `compression.enabled: false` short-circuits the entire pipeline; `compression.tier2.enabled: false` short-circuits only Tier 2 (T02 verifier `m018-p04-tier2-disable-flag.sh`).
- Body-level preservation self-check via `pres_check_section ... tier2`; failure passes the section through unmodified plus a `tier_preservation_violation` JSONL emit (T02 verifier `m018-p04-tier2-preservation-self-check.sh`).

## Verification

- `bash scripts/verify/m018-p04-tier2-head-drop.sh` — PASS.
- `bash scripts/verify/m018-p04-tier2-marker.sh` — PASS.
- `bash scripts/verify/m018-p04-tier2-boundary-refusal.sh` — PASS.
- `bash scripts/verify/m018-p04-tier2-emitter-additivity.sh` — PASS.
- `bash scripts/verify/m018-p04-tier2-disable-flag.sh` — PASS.
- `bash scripts/verify/m018-p04-tier2-preservation-self-check.sh` — PASS.

T02 ships these verifiers; they exercise T01's production code. Until T02 lands, T01 is verifiable via the self-test in Step 7 plus a `bash -n scripts/dispatch/build-context.sh` syntax check.

## Inputs

### From Previous Tasks

(None within P04 — T01 is the first task.)

### From Disk (Pre-existing)

- `scripts/dispatch/build-context.sh` — the dispatch payload assembler. Key insertion points:
  - line ~189–192 (tier1 config-read block; tier2 reads land immediately below).
  - line ~588 (`_bc_apply_tier1`; `_bc_apply_tier2` lands immediately below it, before `_bc_gather_decisions` at line 761).
  - line ~1319 (`_bc_emit_payload_breakdown`); line ~1407 (the `tier1_savings_tokens` read block; tier2 read lands immediately after); line ~1436 (the JSONL printf format).
  - line ~1723 (the `_bc_apply_tier1` call site; the `_bc_apply_tier2` call lands immediately after).
- `scripts/lib/preservation-check.sh` — sourceable. T01 uses `pres_check_section` and `pres_emit_violation` (tier2 strict-multiplicity branch). The `PRES_PATTERNS_REGEX` array is referenced by the boundary-refusal detector through the explicit awk regex constants in the implementation (NOT via array-indirection — awk variable scoping makes that awkward; the two multi-line regexes that matter live verbatim in the awk script).
- `scripts/lib/knowledge-filter.sh` — sourceable. T01 adds three new accessors (`kf_get_tier2_*`) mirroring `kf_get_tier1_*`. Same `kf_resolve_config_path` + `kf_read_compression_scalar` plumbing.
- `scripts/lib/pricing.sh` — sourceable; `chars_to_tokens_quartile` defines the `(chars+3)/4` token estimator T01 mirrors in awk via the `tok()` helper (identical to the tier1 implementation).
- `.orchestrator/config.yml` — Step 1 appends to the `compression:` map (current end of `compression.tier1:` block is around line 75 — locate `cache_dir:` + insert below).
- `templates/orchestrator-config-default.yml` — Step 1 appends the same block.
- `references/compression-grammar.md` `## Tier: tier2` (lines 191–211) — contract.
- `tests/fixtures/m018-p02-baseline-payload.golden.txt` — P02/P03 disable-flag golden; T01 must NOT change its bytes when `compression.enabled: false`.

## Constraints

- **AP-009 (Bash shape guard)**: zero compound chains > 2 in shell-shape; zero plain subshells; zero `$(...|...)` shell forms. Awk-internal `cmd | getline` is permitted (it's awk-internal, not shell-shape) — but T01's awk implementation does not need shell-out; SHA-256 is not required for Tier 2 since the tier has no cache.
- **Bash 3.2 compatibility**: no `declare -A`; no associative arrays; parallel indexed arrays only. The awk implementation can use awk associative arrays freely (awk is awk, not bash).
- **CON-5 (additive emitters)**: `payload_breakdown` records gain ONE new field (`tier2_savings_tokens`); no existing field is removed or renamed; pre-T2 records remain valid JSON.
- **Constitution Principle VI (originals authoritative)**: T01 writes ONLY to `$TMPDIR_BUILD/*` (transient), `execution-log.jsonl` (additive emit), and the in-flight `$PAYLOAD_CAPTURE`. No canonical file (knowledge tree, spec, plan, roadmap) is touched. Tier 2 has NO cache directory — head-drop is destructive on the dispatch-time payload; the originals on disk are untouched.
- **MIT-01 (4+-backtick code-fence regex)**: T01's boundary-refusal detector MUST honor the `^\`{3,}[a-zA-Z0-9_-]*$` regex from `PRES_PATTERNS_REGEX[1]`. The fence-state tracker counts the opening backticks and closes only on a matching backtick-count line — a 3-backtick line cannot close a 4-backtick fence. T02's `m018-p04-tier2-boundary-refusal.sh` verifier exercises a fixture with a 4-backtick-fenced over-budget section to assert this directly.
- **Disable contract**: when `compression.enabled: false` OR `ORCH_OVERRIDE_COMPRESSION_ENABLED=false`, T01 MUST short-circuit before any payload mutation. The P02 golden payload (`tests/fixtures/m018-p02-baseline-payload.golden.txt`) is the regression contract — T02's `m018-p04-tier2-disable-flag.sh` verifier asserts byte-identity.
- **MEM004 (Pure Lib Extraction)**: T01's `_bc_apply_tier2` is dispatch-internal, like the existing `_bc_apply_knowledge_filter` and `_bc_apply_tier1`. It does not need to live in a separate `scripts/lib/tier2.sh` (single call site; no second consumer in scope). If P05 or beyond demands cross-call-site reuse, the function migrates to `scripts/lib/tier2.sh` then.

## Expected Output

- `scripts/dispatch/build-context.sh` grew by ~200 lines (the `_bc_apply_tier2` function plus the four config-read lines plus the 10–15-line emitter additions plus the call-site insertion).
- `scripts/lib/knowledge-filter.sh` grew by ~45 lines (three new `kf_get_tier2_*` accessors).
- `.orchestrator/config.yml` and `templates/orchestrator-config-default.yml` carry the new `compression.tier2.*` block under the existing `compression:` map.
- `bash -n scripts/dispatch/build-context.sh` succeeds (syntax check).
- A self-test invocation of build-context.sh produces a `payload_breakdown` JSONL line whose JSON parses cleanly (`python3 -c 'import json,sys;[json.loads(l) for l in open(sys.argv[1])]' execution-log.jsonl`) and contains a `tier2_savings_tokens` integer-valued key.
- No verifier files yet — T02 ships those.

## State Context

- **Current State**: executing
- **Milestone**: M018
- **Phase**: P04
- **Task**: T01-tier2-head-drop
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **AP-009 (Bash shape guard)**: zero compound chains > 2 in shell-shape; zero plain subshells; zero `$(...|...)` shell forms. Awk-internal `cmd | getline` is permitted (it's awk-internal, not shell-shape) — but T01's awk implementation does not need shell-out; SHA-256 is not required for Tier 2 since the tier has no cache.
- **Bash 3.2 compatibility**: no `declare -A`; no associative arrays; parallel indexed arrays only. The awk implementation can use awk associative arrays freely (awk is awk, not bash).
- **CON-5 (additive emitters)**: `payload_breakdown` records gain ONE new field (`tier2_savings_tokens`); no existing field is removed or renamed; pre-T2 records remain valid JSON.
- **Constitution Principle VI (originals authoritative)**: T01 writes ONLY to `$TMPDIR_BUILD/*` (transient), `execution-log.jsonl` (additive emit), and the in-flight `$PAYLOAD_CAPTURE`. No canonical file (knowledge tree, spec, plan, roadmap) is touched. Tier 2 has NO cache directory — head-drop is destructive on the dispatch-time payload; the originals on disk are untouched.
- **MIT-01 (4+-backtick code-fence regex)**: T01's boundary-refusal detector MUST honor the `^\`{3,}[a-zA-Z0-9_-]*$` regex from `PRES_PATTERNS_REGEX[1]`. The fence-state tracker counts the opening backticks and closes only on a matching backtick-count line — a 3-backtick line cannot close a 4-backtick fence. T02's `m018-p04-tier2-boundary-refusal.sh` verifier exercises a fixture with a 4-backtick-fenced over-budget section to assert this directly.
- **Disable contract**: when `compression.enabled: false` OR `ORCH_OVERRIDE_COMPRESSION_ENABLED=false`, T01 MUST short-circuit before any payload mutation. The P02 golden payload (`tests/fixtures/m018-p02-baseline-payload.golden.txt`) is the regression contract — T02's `m018-p04-tier2-disable-flag.sh` verifier asserts byte-identity.
- **MEM004 (Pure Lib Extraction)**: T01's `_bc_apply_tier2` is dispatch-internal, like the existing `_bc_apply_knowledge_filter` and `_bc_apply_tier1`. It does not need to live in a separate `scripts/lib/tier2.sh` (single call site; no second consumer in scope). If P05 or beyond demands cross-call-site reuse, the function migrates to `scripts/lib/tier2.sh` then.

### Acceptance Criteria

- Tier 2 head-drop fires on in-scope sections (`## Knowledge`, `## Task Plan`, `## Upstream Context`) whose body-token count exceeds `compression.tier2.section_budget_tokens`, removing head bytes above the budget while leaving the trailing `protected_tail_ratio` byte-identical (T02 verifier `m018-p04-tier2-head-drop.sh`).
- Tier 2 emits the in-band `<!-- compressed:tier2 head_dropped=N protected_tail_ratio=R -->` marker immediately after every modified section's heading line (T02 verifier `m018-p04-tier2-marker.sh`).
- Boundary-refusal: when the line-aligned cut would split a 4+-backtick code fence or a frontmatter delimiter pair, the cut retreats above the span; with no safe boundary, the section passes through unmodified plus a `tier_preservation_violation` (tier=`tier2`) JSONL emit (T02 verifier `m018-p04-tier2-boundary-refusal.sh`).
- `payload_breakdown` records carry an additive integer `tier2_savings_tokens` field; pre-T2 records remain valid JSON (T02 verifier `m018-p04-tier2-emitter-additivity.sh`).
- `compression.enabled: false` short-circuits the entire pipeline; `compression.tier2.enabled: false` short-circuits only Tier 2 (T02 verifier `m018-p04-tier2-disable-flag.sh`).
- Body-level preservation self-check via `pres_check_section ... tier2`; failure passes the section through unmodified plus a `tier_preservation_violation` JSONL emit (T02 verifier `m018-p04-tier2-preservation-self-check.sh`).

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