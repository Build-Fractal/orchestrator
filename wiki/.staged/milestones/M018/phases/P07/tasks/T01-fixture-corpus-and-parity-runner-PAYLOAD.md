---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T01-fixture-corpus-and-parity-runner (Phase P07, Milestone M018)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~500 | required |
| Upstream Context | 981-1268 | ~5700 | required |
| Task Plan | 1270-1585 | ~4900 | required |
| State Context | 1587-1593 | ~100 | required |
| First-Turn Completeness | 1595-1631 | ~700 | required |
| **Total** | | **~22700** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 698
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
hit_count: 698
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
hit_count: 698
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
hit_count: 698
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
hit_count: 621
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
hit_count: 621
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
hit_count: 621
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
hit_count: 698
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
hit_count: 621
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
hit_count: 621
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
hit_count: 621
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
hit_count: 698
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
hit_count: 698
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
hit_count: 698
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
hit_count: 621
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
hit_count: 621
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
hit_count: 621
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
hit_count: 698
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
hit_count: 621
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
hit_count: 621
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
hit_count: 698
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
hit_count: 698
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
hit_count: 621
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
hit_count: 621
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
hit_count: 621
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
hit_count: 276
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
hit_count: 276
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
hit_count: 276
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
hit_count: 274
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
hit_count: 274
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
hit_count: 264
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

<!-- Every truth's Check is a single-script-file invocation per AD-19. The
     three canonical verifiers ship in T03; T01-T02 each carry a `bash -n`
     self-check as their task-local extractable Check (the auto-loop verify
     parser refuses zero-Check plans). -->

### Truths

- The bash-only tiers (filter + T1 + T2) produce byte-identical compressed payloads across the three simulated runtime environments (`ORCH_BACKEND` ∈ {`claude-code`, `codex`, `cursor`}) for every fixture in `tests/compression-runtime-parity/`. SHA-256 over the post-T2 payload bytes is identical across runtimes per fixture.
  - Check: `bash scripts/verify/m018-p07-zero-llm-parity.sh`
- Tier 3 routes its LLM call through `scripts/dispatch/lib/tier3-llm-call.sh` (which fronts the runtime's resolution surface) under every simulated runtime; with `ORCH_TIER3_LLM_BIN` pointing at the deterministic stub, the helper invokes the stub once per fixture per runtime, the stub receives the rendered prompt-file bytes verbatim, and the captured output replaces the section in the payload. The dispatch pipeline never crashes when the stub exits 0; on stub-exit-1 the failure-passthrough emits `tier3_failed`.
  - Check: `bash scripts/verify/m018-p07-tier3-routing.sh`
- `references/RUNTIME-ASSUMPTIONS.md` exists and carries a `# Compression (M018)` block listing at least one documented divergence (model-pricing differences feeding `dispatch_usage.estimated_cost_usd`, OR `claude` CLI PATH presence for the no-stub fallback path) with rationale and an M009 audit-row reference. CLAUDE.md and AGENTS.md `orchestrator:recent-changes` blocks both name "M018/P07" and "runtime-parity".
  - Check: `bash scripts/verify/m018-p07-runtime-assumptions-and-dual-write.sh`

### Artifacts

- `scripts/diagnostics/m018-runtime-parity.sh` (min 60 lines, contains "ORCH_BACKEND")
- `scripts/diagnostics/m018-runtime-parity-tier3.sh` (min 50 lines, contains "ORCH_TIER3_LLM_BIN")

<dispatch-volatile>

## Upstream Context


### P06 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P06"
parent: "M018"
milestone: "M018"
provides:
  - "_bc_apply_tier3 helper in scripts/dispatch/build-context.sh (intensity gate + density pre-check + dispatch-routed LLM call + originals persistence + preservation self-check + failure-passthrough on every error path; writes savings_tokens=0 invocations=0 to TMPDIR_BUILD/_tier3_stats.txt as first action; success path writes savings_tokens=<delta> invocations=1; emits tier3_skipped/tier3_failed/tier3_no_savings JSONL records via MEM004 carve-out _bc_emit_tier3_event); six kf_get_tier3_* config accessors in scripts/lib/knowledge-filter.sh (enabled/intensity_floor/section_budget_tokens/originals_dir/output_max_ratio/density_floor) mirroring the tier2 accessor shape with documented defaults; templates/compression-tier3-prompt.md (versioned frontmatter + input/output contract body naming preserved-pattern list verbatim from the compression-grammar v1.0.1); scripts/dispatch/lib/tier3-llm-call.sh shim (operator-binary | claude-code-claude | exit-1 ladder for runtime portability); pipeline wiring inserts _bc_apply_tier3 between _bc_apply_tier2 and _bc_emit_payload_breakdown with trailing || true (FR-9); templates/orchestrator-config-default.yml gains compression.tier3 stanza so orchestrator:init copies forward defaults,additive `tier3_compression_savings_tokens` + `tier3_invocations` integer fields on payload_breakdown / dispatch_usage / unit_close JSONL records (CON-5); TIER3_SAVINGS + TIER3_INVOCS columns appended at indices 17-18 of the metrics-rollup.sh data row (back-compat preserved on cols 1-12 + 13-16); efficiency-footer.sh compression-line numerator widened to filter+tier1+tier2+tier3; check-anomalies.sh per-row sav_total widened with tier3_compression_savings_tokens; pinned column-index contract retrofit on m018-p05-cost-rollup-savings-columns.sh (absolute indices replacing fragile NF-relative reads),scripts/diagnostics/compression-eval.sh --tier 3 real cohort logic against tier3_compression_savings_tokens (replaces P05 reservation stub); cohort split + Wilson 95% CI for pass-rate + pooled-SE for retry/deviation; below-floor 'insufficient sample'; sourceable + CLI shape preserved (FR-12 always-exit-0; AD-19 single-script-file Check shape)"
requires:
  - "P05"
affects:
  - "P07"
key_files:
  - "scripts/dispatch/build-context.sh;scripts/lib/knowledge-filter.sh;scripts/dispatch/lib/tier3-llm-call.sh;templates/compression-tier3-prompt.md;templates/orchestrator-config-default.yml,scripts/dispatch/build-context.sh;scripts/dispatch/dispatch-interface.sh;scripts/knowledge/write-summary.sh;scripts/diagnostics/metrics-rollup.sh;scripts/diagnostics/efficiency-footer.sh;scripts/diagnostics/check-anomalies.sh;scripts/verify/m018-p05-cost-rollup-savings-columns.sh,scripts/diagnostics/compression-eval.sh"
key_decisions:
  - "helper failure-passthrough is the default behavior when no LLM provider is wired (ORCH_TIER3_LLM_BIN unset AND claude not on PATH) — shim exits 1 → tier3_failed reason=llm-call-nonzero → stats stay at zero → dispatch proceeds without compaction; helper writes savings_tokens=0 invocations=0 to stats file BEFORE any short-circuit so the T02-widened emitter never reads a missing file; in-band marker substitution uses literal <MODEL>/<N>/<M> placeholders the LLM emits and the orchestrator post-substitutes (LLM does not need to know its own model name or token counts); originals persisted to .orchestrator/cache/tier3-originals/<sha256>.txt with sha256 keyed on header + body bytes (cache-prune.sh non-recursive so co-tenant under cache_dir is untouched); intensity-floor closed enum quick|standard|full → anything else falls through to standard (kf_get_tier3_intensity_floor); MIT-08 density pre-check (input_tokens/section_budget < density_floor → skip without paying LLM cost) emits tier3_skipped reason=density-floor; new JSONL record_type values tier3_skipped/tier3_failed/tier3_no_savings additive (CON-5 — pre-M018 readers ignore unknown record_type),Field placement: tier3_compression_savings_tokens + tier3_invocations placed AFTER tier2_savings_tokens / tier1_invocations and BEFORE the model/source/timestamp triplet on payload_breakdown / dispatch_usage / unit_close — preserves every prior field position so existing JSONL consumers see no shift (CON-5 byte-identity carry-forward); rollup column-index contract: TIER3_SAVINGS + TIER3_INVOCS appended at absolute indices 17-18 (cols 1-12 + 13-16 byte-identical); MEM004 emitter-internal carve-out extends to the six widened helpers; co-located dispatch_usage emitter (_bc_emit_dispatch_usage_colocated) NOT widened — never carried the four P05 fields either; staying consistent with P05 posture; m018-p05-cost-rollup-savings-columns.sh retrofit from $(NF-3)..$NF to absolute $13..$16 because the pinned column-index contract IS the back-compat invariant,and NF-relative reads were a fragile choice not the contract,P05/T03 cohort-build awk pass and Wilson/pooled-SE arithmetic are correct as-is for tier3 — only the JSONL field name driving the cohort split changes; defensive else-zero arm in awk preserved against awk uninitialized-variable warnings; P05 compression-eval verifier 'tier 3 missing P06-reservation stub' assertion intentionally inverted by T03 — T04 replaces that assertion with the tier3 cohort-block assertion"
patterns_established:
  - "Tier 3 helper mirrors the tier1/tier2 helper shape (stats-file write as first action,atomic mv-replace via temp file,in-place rewrite,MEM004 carve-out,preservation self-check + restore-on-violation); LLM-call shim isolates runtime-portability surface (operator-binary | backend-default | exit-1 ladder) so multi-runtime parity work swaps providers without touching the helper body; failure-passthrough audit invariant — every return-0 path that does NOT mutate the capture file MUST leave the stats file at savings_tokens=0 invocations=0 (defensive first-write enforces this); intensity gate honors INTENSITY_METADATA_FILE env var with grep+sed parser matching scripts/engine/intensity-gate.sh:50; six closed-enum accessors return documented defaults when config key absent (CON-5 absent-as-default),Schema-extension carve-out reuse pattern: when an additive emitter has an in-flight rollup helper (T01-style _di_rollup_savings_fields / _ws_rollup_savings_fields),extending it with N more fields is a 4-step recipe (1: extend awk BEGIN initializer + per-record match() + END printf with N more accumulators; 2: extend the calling sed -n line-extraction with N more positional reads; 3: extend the emitter printf format string + value list; 4: leave defensive [-n] || var=0 fallback unchanged); rollup-source restriction carry-forward: metrics-rollup.sh / efficiency-footer.sh / check-anomalies.sh consume payload_breakdown rows ONLY for savings sums to avoid double-counting the rolled-up copies on dispatch_usage / unit_close; absolute column-index contract over NF-relative indexing in shape verifiers — when a column-set will grow over time,anchor verifier reads to absolute positions,not offset-from-end,MEM004 emitter-internal carve-out applies inside compression-eval body; tier-N case fall-through pattern widens cleanly when a new tier joins the cohort-segmentation diagnostic without touching CI/SEM math; T03 single-file surgical pattern — production code modification only,with canonical truth verifier shipped in T04 per P03/P04/P05 phase shape"
drill_down_paths:
  - "/Users/brettkellgren/Sites/spec-kit-orchestrator/.orchestrator/milestones/M018/phases/P06/tasks/T01-tier3-helper-SUMMARY.md, /Users/brettkellgren/Sites/spec-kit-orchestrator/.orchestrator/milestones/M018/phases/P06/tasks/T02-schema-extensions-SUMMARY.md, /Users/brettkellgren/Sites/spec-kit-orchestrator/.orchestrator/milestones/M018/phases/P06/tasks/T03-compression-eval-tier3-SUMMARY.md"
duration: "19m"
verification_result: "pass"
completed_at: "2026-04-28T14:34:47Z"
observability_surfaces:
  - "execution-log.jsonl: payload_breakdown.{tier3_compression_savings_tokens,tier3_invocations} additive integer fields; dispatch_usage.{tier3_compression_savings_tokens,tier3_invocations} rolled-up additive fields; unit_close.{tier3_compression_savings_tokens,tier3_invocations} granularity-aware additive fields; tier3_skipped / tier3_failed / tier3_no_savings new JSONL record_types (additive); metrics-rollup.sh stdout: TIER3_SAVINGS / TIER3_INVOCS columns; efficiency-footer.sh stdout: compression: line numerator widens to fold tier3 savings; check-anomalies.sh stdout: compression-regression denominator widens to fold tier3 savings; compression-eval.sh stdout: --tier 3 cohort + delta block with 95% CIs and regression_flag (no longer P06-reservation stub)."
---

P06 lands the **tier 3 auto-compact tier** of the M018 compression
pipeline: an LLM-routed section summarization helper in
`build-context.sh` (`_bc_apply_tier3`), a versioned prompt template, six
config accessors, additive `tier3_compression_savings_tokens` +
`tier3_invocations` fields on three JSONL record types, three new
`tier3_skipped` / `tier3_failed` / `tier3_no_savings` event record
schemas, and the `compression-eval.sh --tier 3` real cohort logic that
replaces the P05 reservation stub.

After P06, build-context can route an oversized post-Tier-2 section
through `dispatch-interface.sh` against `templates/compression-tier3-prompt.md`,
verify preservation, splice the compressed output back, and emit savings
telemetry. Any failure in that pipeline (LLM non-zero exit, empty
output, output-too-large, preservation breach) passes Tier 2's bytes
through unchanged and emits a `tier3_failed` (or `tier3_no_savings`)
JSONL record — the dispatch never crashes from a Tier 3 fault. Density
and intensity gates short-circuit the helper before the LLM call when
appropriate, emitting `tier3_skipped` events instead.

The phase ships:

- **`_bc_apply_tier3` LLM-routed summarization helper** (T01) in
  `scripts/dispatch/build-context.sh`. Wired between `_bc_apply_tier2`
  and `_bc_emit_payload_breakdown`. Honors the master
  `compression.enabled` toggle, the per-tier `compression.tier3.enabled`
  toggle, the `compression.tier3.intensity_floor` gate (FR-14: Quick
  skips T3), and the `compression.tier3.density_floor` MIT-08 pre-check
  (input_tokens / section_budget below floor → short-circuit). Persists
  originals to `.orchestrator/cache/tier3-originals/<sha256>.txt`. Routes
  the rendered prompt + section bytes through
  `scripts/dispatch/dispatch-interface.sh` (or the
  `scripts/dispatch/lib/tier3-llm-call.sh` shim when present). MEM004
  emitter-internal carve-out — single-pass awk inside the helper body.

- **`templates/compression-tier3-prompt.md`** (T01) — versioned
  `schema_version: "1.0" type: compression-prompt tier: 3
  applies_to: ["dispatch-payload-section"]` frontmatter; `preserves:`
  array names every preserved-pattern token from
  `references/compression-grammar.md` Tier 3 (frontmatter, code fences,
  JSONL, MEM identifiers, paths, scaffold-placeholder markers, URLs,
  command names, in-band markers); body declares input/output contracts
  and ends with a `## Section to compress` header where the helper
  appends the section bytes.

- **Six `kf_get_tier3_*` config accessors** (T01) in
  `scripts/lib/knowledge-filter.sh`: `enabled` / `intensity_floor` /
  `section_budget_tokens` / `originals_dir` / `output_max_ratio` /
  `density_floor`. Defaults installed in
  `templates/orchestrator-config-default.yml`.

- **`scripts/dispatch/lib/tier3-llm-call.sh`** (T01) — LLM-call shim that
  fronts `dispatch-interface.sh` for the Tier 3 helper. Encapsulates
  prompt-file → completion → output-file routing so the helper can swap
  in a stub during tests without touching dispatch-interface.

- **Six `kf_get_tier3_*` accessors + three event record types** (T01) —
  `tier3_skipped` (intensity gate / density floor short-circuit),
  `tier3_failed` (LLM call non-zero / empty / preservation breach),
  `tier3_no_savings` (LLM output exceeded `output_max_ratio`). All three
  are additive JSONL record_type schemas — pre-M018 readers ignore
  unknown record_type values.

- **Additive schema extensions** (T02) — `tier3_compression_savings_tokens`
  and `tier3_invocations` integer fields on three JSONL record types:
  `payload_breakdown` (build-context emitter, co-located with the helper
  in build-context.sh), `dispatch_usage`
  (`scripts/dispatch/dispatch-interface.sh:_di_emit_dispatch_usage` —
  rolled up from same-unitId payload_breakdown rows at emit-time), and
  `unit_close` (`scripts/knowledge/write-summary.sh:_ws_emit_unit_close`
  — rolled up from in-scope payload_breakdown rows under granularity-aware
  scope match). Pre-M018 records remain valid JSON; downstream consumers
  treat absent fields as zero (CON-5 absent-as-zero contract preserved).

- **Cost-rollup column extension** (T02) — `metrics-rollup.sh` projects
  the two new fields at columns 17-18 (after the four P05 columns at
  13-16; columns 1-12 remain byte-identical for back-compat consumers).
  Header carries `TIER3_SAVINGS` and `TIER3_INVOCS` labels.

- **Efficiency-footer fold** (T02) — `efficiency-footer.sh` widens the
  `compression: <pct>% reduction over baseline` numerator to fold
  `tier3_savings` into the existing `filter+tier1+tier2` sum; the line
  text now reads `(filter+tier1+tier2+tier3 / payload_tokens)`.

- **Doctor anomaly fold** (T02) — `check-anomalies.sh`
  `compression-regression` flag widens its `sav_total` denominator to
  fold tier3_savings; the SC-9 0.347 floor and configurability
  (`compression.regression_floor`) are preserved.

- **`compression-eval.sh --tier 3` real cohort** (T03) — replaces the
  P05 reservation stub with real cohort logic against
  `tier3_compression_savings_tokens`. Single awk pass classifies
  (milestone, phase, task) into compressed (tier3_savings > 0) or
  uncompressed cohorts; task-granularity unit_close records measure
  pass_rate / retry / deviation; END block enforces sample floor
  (default 30), computes Wilson 95% CI for proportions and pooled-SE
  deltas, emits a `regression_flag:` advisory line. Always exits 0
  (FR-12 / CON-5). Sourceable + CLI shape preserved.

- **Five P06-private truth verifiers** (T04) under
  `scripts/verify/m018-p06-*.sh` exercise all five mechanical truths
  end-to-end against hermetic fixture logs. Verifier shape mirrors the
  P05/T04 pattern: pass()/fail() helpers, hermetic root staging via
  `ORCHESTRATOR_ROOT`, single-script-file Check shape (AD-19 / AP-009),
  shim-style awk function extraction where dispatch-interface.sh /
  write-summary.sh CLI bodies prevent direct sourcing.

- **Two fixture trees** (T04) under
  `tests/fixtures/m018-p06-{tier3-fired,tier3-failed}-log/`. The
  `tier3-fired` fixture mixes 5 P06 tasks (T01/T02/T04 compressed;
  T03/T05 uncompressed) plus a pre-P06 baseline row at top (CON-5
  back-compat) and a `tier3_skipped` event. The `tier3-failed` fixture
  carries 2 tasks with `tier3_failed` events naming `llm-call-nonzero`
  and `preservation-breach` reasons — the FR-9 failure-passthrough
  scenario.

- **`scripts/verify/_helpers/m018-p06-build-fixture.sh`** (T04) —
  fixture-staging helper mirroring the P03/P04/P05 shape. Stages a
  hermetic `.orchestrator/`-style root at `<root>/milestones/<MS_ID>/`
  with a copy of the chosen fixture log (`tier3-fired` → M018F;
  `tier3-failed` → M018G) and a minimal `config.yml` so `read-config.sh`
  resolves cleanly under `ORCHESTRATOR_ROOT=<root>`.

- **CLAUDE.md / AGENTS.md `orchestrator:recent-changes` dual-write**
  (T04) via `scripts/util/dual-write-runtime-md.sh --marker recent-changes
  --append-entry "..."`. Both runtime instruction files name M018/P06
  and tier3.

## Risk-mitigation traceability

- **CON-5 (additive emitters)** — the two new fields on
  `payload_breakdown`, `dispatch_usage`, and `unit_close` are additive.
  The pre-P06 row at the top of the `tier3-fired` fixture
  (`M018F/P04/T99`) carries only the four P05 fields and NO tier3
  fields; it parses as valid JSON via python3 json.loads, and the
  rollup helpers in dispatch-interface.sh and write-summary.sh treat
  absent fields as zero. Verified by the back-compat assertions in
  `m018-p06-tier3-additivity.sh`.

- **FR-9 (tier3 failure-passthrough)** — every error path inside
  `_bc_apply_tier3` returns 0 after writing a stats file with
  `savings_tokens=0 invocations=0` and emitting a `tier3_failed` JSONL
  record naming the reason. The `tier3-failed` fixture documents two
  representative failure paths (`llm-call-nonzero`, `preservation-breach`)
  and confirms that `unit_close: pass` is still emitted on the dispatch
  (the agent received Tier 2's output unchanged).

- **FR-12 (read-only diagnostic surfaces)** — `compression-eval.sh`
  never appends to or rewrites JSONL; always exits 0. Verified by the
  missing-log assertion in `m018-p06-compression-eval-tier3.sh` (degraded
  text + exit 0).

- **FR-14 (intensity-gating)** — Quick → T3 skipped + `tier3_skipped`
  JSONL record. Standard / Full → T3 active per
  `compression.tier3.intensity_floor` config.

- **MIT-08 (density pre-check)** — input_tokens / section_budget below
  `compression.tier3.density_floor` (default 1.5) short-circuits the
  helper before the LLM call and emits `tier3_skipped reason=density-floor`.
  Avoids paying LLM cost on sections that cannot meaningfully compress.

- **AD-19 / AP-009 single-script-file Check shape** — every truth's
  Check: line is a single bash invocation. Verifier scripts use
  pass()/fail() per MEM002 and printf-prefixed lines per MEM001.

## RISK-3 disposition (phase-close gate)

The spec's RISK-3 gate states that P06's `unit_close: pass` is gated by
`compression-eval.sh --milestone M018 --tier 3` showing no statistically
significant outcome-rate regression vs the uncompressed cohort.

At P06 close, the live `.orchestrator/milestones/M018/execution-log.jsonl`
cohort sizes are below the statistical floor (compression-eval emits
`insufficient sample (compressed=N uncompressed=M floor=30)` and exits
0). Per the spec's RISK-3 framing, this counts as a non-regression for
P06 close — the diagnostic is operational, the cohort split logic is
verified against the M018F fixture (compressed=3 uncompressed=2 with
pass-rates 1.0/1.0 across both cohorts → `regression_flag: none`), and
subsequent milestones will exercise the diagnostic against larger n. The
diagnostic stays operational as M018 telemetry accumulates so the
regression check gains statistical power without code changes.

The next operator running `compression-eval.sh --milestone <Mxxx>
--tier 3` against a future milestone with sufficient cohort sizes can
either confirm continued non-regression (sustains the P06 close
disposition) or surface a regression flag for manual review. The flag's
trigger condition (`delta_pass_rate <= -0.05 AND CI excludes 0`) is the
contract the M019 and [M027](../../../../../milestones/M027/index.md) cost+token transparency surfaces will
ultimately consume.

## Followups for downstream phases

- **Tier 3 originals retention** — `.orchestrator/cache/tier3-originals/`
  is lazily created at first T3 fire. `cache-prune.sh` (P03) does not
  recurse into sub-directories under cache_dir, so tier3-originals/
  co-tenants are untouched by tier1 prune passes. A future T-row will
  add tier3-originals retention if disk-pressure surfaces (e.g.,
  `cache-prune.sh --tier3-originals --max-age 30d`).

- **M019 / M027 future surfaces** — the two additive fields on the
  three JSONL record types are the contract M019 cost+token transparency
  surfaces (M027 extension target) read. The rollup column-index
  contract is now pinned: 1-12 stable; 13-16 are the M018 P05 savings
  columns; 17-18 are the M018 P06 tier3 columns.

- **Outstanding RISK-3 evaluation** — once M018 (or a downstream
  milestone) accumulates ≥30 dispatches per cohort, re-run
  `compression-eval.sh --milestone <Mxxx> --tier 3` and confirm
  `regression_flag: none`. If a regression flag fires, raise a discuss
  task to evaluate Tier 3 model-quality / preservation-check tuning.

## Verification result

All five P06 truths PASS via
`bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P06/`.
All artifacts present at required line counts with required substrings;
all key links resolve; all five private verifiers green:

- `m018-p06-tier3-helper-shape.sh` — PASS (13 assertions: helper
  defined; references dispatch-interface.sh and compression-tier3-prompt.md;
  pipeline wiring tier2 → tier3 → emit; six accessors; bash -n green
  on build-context and knowledge-filter).
- `m018-p06-tier3-prompt-template.sh` — PASS (16 assertions: template
  exists; tier=3 frontmatter; applies_to dispatch-payload-section;
  schema_version present; preserves: array contains all nine required
  preserved-pattern tokens; in-band marker template literal; ## Section
  to compress header).
- `m018-p06-tier3-additivity.sh` — PASS (21 assertions: source-level
  printf fields in DI + WS; fixture rows carry both fields; pre-P06
  back-compat row valid JSON; live emit through DI shim sums to 400/1
  for T01; WS rollup phase scope sums to 1800/3 across T01+T02+T04;
  metrics-rollup TIER3_SAVINGS + TIER3_INVOCS columns; efficiency-footer
  numerator label includes tier3; check-anomalies.sh runs cleanly).
- `m018-p06-compression-eval-tier3.sh` — PASS (17 assertions: bash -n
  green; references tier3_compression_savings_tokens; no stub literal;
  cohort + delta block emitted with header; regression_flag: none on
  fixture; high floor → insufficient sample; missing log → degraded
  text + exit 0).
- `m018-p06-dual-write-recent.sh` — PASS (CLAUDE.md and AGENTS.md
  recent-changes blocks both name M018/P06 and tier3).

P06 closed. M018 advances to phase-end consolidation.

## P05/T04 verifier disposition

The P05 verifier `scripts/verify/m018-p05-compression-eval.sh`
assertion 3 was authored against the P05 stub behavior (`--tier 3`
recognized-but-no-op) and is retroactively outdated by P06/T03's real
cohort logic. The new P06 verifier
`scripts/verify/m018-p06-compression-eval-tier3.sh` asserts the inverse
(real cohort + delta block, no stub literal). The P05 verifier is left
in place untouched at this phase close — its core assertions (cohort
block on tier=1, sample-floor, missing-log) remain valid and useful as
P05 regression tests; only assertion 3's stub-behavior expectation is
stale. A follow-up consolidation can either delete the stale assertion
or relax it to "tier 3 cohort produces output (stub or real)" once the
M018 milestone-summary scope is finalized.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P07"
milestone: "M018"
name: "Fixture corpus + zero-LLM parity runner — filter + T1 + T2 byte-equality across CC / Codex CLI / Cursor simulated runtimes"
depends_on: []
---

## Prerequisites

- The bash-only tier helpers exist and are stable from prior phases:
  - `_bc_apply_filter` at `scripts/dispatch/build-context.sh` (P02) — knowledge-aware filter; honors `compression.knowledge_filter.drop_list`.
  - `_bc_apply_tier1` at `scripts/dispatch/build-context.sh:614` (P03) — tool-result paging + SHA-256 cache reuse; reads `compression.tier1.tool_result_budget_bytes` and persists to `.orchestrator/cache/tool-results/<sha256>.txt`.
  - `_bc_apply_tier2` at `scripts/dispatch/build-context.sh:823` (P04) — section head-drop with `compression.tier2.protected_tail_ratio`; refuses to cross preserved-pattern boundaries.
- `scripts/lib/knowledge-filter.sh` `kf_get_*` accessors (P02/P03/P04/P06) read config keys from `.orchestrator/config.yml` resolved via `ORCHESTRATOR_ROOT` (`scripts/state/resolve-root.sh`).
- `scripts/util/dual-write-runtime-md.sh` exists; T01 does NOT invoke it (T03 closes the dual-write).
- `scripts/verify/_helpers/m018-p06-build-fixture.sh` (P06/T04) is the canonical fixture-staging helper shape T01's helper mirrors. Read it once for shape (config-override scaffolding, fixture path resolution under `$TMPDIR_BUILD/_p07_fixture/<slug>/`) before authoring `m018-p07-build-fixture.sh`.
- AP-009 / AD-19: no compound chains > 2; no inline `$(...)` containing pipes; no plain subshells; no process substitution. SHA-256 over a generated payload is computed by writing the payload to a temp file first, then invoking `shasum -a 256 <file>` as a single command, then awk-reading the hash from stdout. Bash 3.2.

## Description

T01 ships **one fixture corpus tree** and **one zero-LLM parity runner** that proves filter + T1 + T2 produce byte-identical compressed payloads across three simulated runtime environments (`ORCH_BACKEND` ∈ {`claude-code`, `codex`, `cursor`}).

Specifically, T01 ships:

1. **`tests/compression-runtime-parity/`** corpus tree with three fixtures (one per zero-LLM tier):
   - `fixtures/filter-mixed-status/` — knowledge tree with mixed `status:` field values (graduated / experimental / superseded) so the filter has work to do.
   - `fixtures/tier1-oversized-tool-result/` — a payload-input file containing an oversized tool-result block past the configured T1 budget.
   - `fixtures/tier2-oversized-section/` — a payload-input file containing an oversized section body past the configured T2 budget.
   - Each fixture carries its own minimal `config.yml` (compression knobs only — `compression.enabled: true`; per-tier knobs sized so the tier under test fires) and an `input/` subdirectory with the bytes the parity runner feeds into `build-context.sh`.
2. **`tests/compression-runtime-parity/README.md`** documenting the corpus, the SHA-256 byte-equality contract, and how to add a new fixture.
3. **`scripts/diagnostics/m018-runtime-parity.sh`** — the parity runner. Single-script-file shape. CLI:

   ```
   m018-runtime-parity.sh [--corpus-dir <path>] [--fixture <name>] [--runtimes <csv>]
   ```

   Defaults: `--corpus-dir tests/compression-runtime-parity`, `--fixture all`, `--runtimes claude-code,codex,cursor`. For each fixture × runtime pair: stages a hermetic `ORCHESTRATOR_ROOT` via the helper, exports `ORCH_BACKEND=<runtime>`, invokes `bash scripts/dispatch/build-context.sh` with the fixture's input bytes, captures the post-T2 payload to a fixture-local temp file, computes SHA-256, prints a `runtime-parity` line per (fixture, runtime, sha256) triple, and emits a `runtime_parity` JSONL record to the staged fixture's `execution-log.jsonl`. After all (fixture, runtime) pairs run, asserts that the three SHA-256 values per fixture match. Always exits 0 (advisory pattern; FAIL surfaces via `regression_flag:` advisory line read by the T03 verifier).
4. **`scripts/verify/_helpers/m018-p07-build-fixture.sh`** — fixture-staging helper. Mirrors `m018-p06-build-fixture.sh` shape. Takes one argument (the fixture name from `tests/compression-runtime-parity/fixtures/<name>/`) and prints the staged hermetic root on stdout. Idempotent (clean-stage on re-invocation). Bash 3.2.

T01 does NOT ship:

- Tier 3 routing parity (T02).
- Verifiers (T03 — except the bash-n self-check on the parity runner that serves as T01's task-local Check).
- RUNTIME-ASSUMPTIONS.md (T03).
- P07-SUMMARY.md or dual-write (T03).

## Steps

### Step 1 — Author `scripts/verify/_helpers/m018-p07-build-fixture.sh`

Mirror P06/T04 helper. Job: stage a hermetic `ORCHESTRATOR_ROOT`-style root at `$TMPDIR/_p07_fixture/<runtime>-<fixture>/` containing:

- `.orchestrator/config.yml` — copied from `tests/compression-runtime-parity/fixtures/<fixture>/config.yml`.
- `knowledge/` — copied from `tests/compression-runtime-parity/fixtures/<fixture>/knowledge/` if present (filter fixture has this; T1 / T2 fixtures may have empty knowledge tree).
- `.orchestrator/milestones/M-FIXTURE/` — minimal milestone scaffolding (a `M-FIXTURE-ROADMAP.md`, an empty `execution-log.jsonl`).
- `input/payload-input.txt` — copied from `tests/compression-runtime-parity/fixtures/<fixture>/input/payload-input.txt`.

Helper takes two positional args: `<runtime>` `<fixture>`. Prints the staged root path on stdout. Idempotent — `rm -rf` the existing staged root before re-staging.

Pseudo-shape (single-script-file; no compound > 2; no `$(... | ...)`):

```bash
#!/usr/bin/env bash
# scripts/verify/_helpers/m018-p07-build-fixture.sh
# M018/P07/T01 — Stage a hermetic fixture root for runtime-parity assertions.
# Usage: bash _helpers/m018-p07-build-fixture.sh <runtime> <fixture-name>
set -u
RUNTIME="${1:?runtime required}"
FIXTURE="${2:?fixture name required}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CORPUS="$PROJECT_ROOT/tests/compression-runtime-parity/fixtures/$FIXTURE"
if [ ! -d "$CORPUS" ]; then
  printf 'FAIL: fixture not found: %s\n' "$CORPUS" >&2
  exit 1
fi
STAGE="${TMPDIR:-/tmp}/_p07_fixture/${RUNTIME}-${FIXTURE}"
rm -rf "$STAGE"
mkdir -p "$STAGE/.orchestrator/milestones/M-FIXTURE"
mkdir -p "$STAGE/input"
# Stage config + knowledge + input
cp "$CORPUS/config.yml" "$STAGE/.orchestrator/config.yml"
if [ -d "$CORPUS/knowledge" ]; then
  cp -R "$CORPUS/knowledge" "$STAGE/knowledge"
fi
cp "$CORPUS/input/payload-input.txt" "$STAGE/input/payload-input.txt"
: > "$STAGE/.orchestrator/milestones/M-FIXTURE/execution-log.jsonl"
# Minimal roadmap so derive-phase / read-config find a milestone
printf -- '---\nschema_version: "1.0"\ntype: roadmap\nmilestone: "M-FIXTURE"\n---\n' \
  > "$STAGE/.orchestrator/milestones/M-FIXTURE/M-FIXTURE-ROADMAP.md"
printf '%s\n' "$STAGE"
```

### Step 2 — Author `tests/compression-runtime-parity/fixtures/filter-mixed-status/`

Create directory tree:

```
fixtures/filter-mixed-status/
  config.yml          # compression.enabled: true; knowledge_filter.drop_list: ["superseded","experimental"]
  knowledge/
    conventions/
      MEM-FXT-A.md   # status: graduated  (kept)
      MEM-FXT-B.md   # status: experimental (dropped)
    patterns/
      MEM-FXT-C.md   # status: superseded (dropped)
      MEM-FXT-D.md   # status: graduated  (kept)
  input/
    payload-input.txt  # canonical payload-input shape build-context expects
  README.md           # what this fixture exercises
```

Each MEM-FXT-* entry is a minimal valid knowledge entry (frontmatter with `id:`, `status:`, `category:`, `confidence:`, `created_at:`, `last_verified:`, `hit_count:`, `source_unit:`, `source_type:`, `supersedes:`, `superseded_by:`, `relates_to:`, `content_hash:`) plus a one-line body. The filter contract (US-2 / FR-3) drops entries with `status: superseded` or `status: experimental` from the Knowledge section.

`config.yml` minimum content (Bash 3.2-friendly grep/sed parsing per MEM001):

```yaml
compression:
  enabled: true
  knowledge_filter:
    drop_list: ["superseded", "experimental"]
  tier1:
    enabled: false
  tier2:
    enabled: false
  tier3:
    enabled: false
```

Disabling tier1/tier2/tier3 isolates the filter as the only mutating stage so byte-equality across runtimes is provable on filter alone.

### Step 3 — Author `tests/compression-runtime-parity/fixtures/tier1-oversized-tool-result/`

Create directory tree:

```
fixtures/tier1-oversized-tool-result/
  config.yml          # compression.enabled: true; tier1.enabled: true; tier1.tool_result_budget_bytes: 4096
  input/
    payload-input.txt # canonical payload with one inline tool-result block sized at ~12 KB
  README.md
```

`config.yml` enables T1 only (filter / T2 / T3 disabled). The `payload-input.txt` carries one tool-result block with body size ~12 KB so T1's 4 KB budget triggers paging. The post-T1 output replaces the inline block with a `<tool-result file="..." preview-bytes="200">…</tool-result>` reference and persists the original to `<staged-root>/.orchestrator/cache/tool-results/<sha256>.txt`. The byte-equality assertion is on the post-pipeline payload bytes including the file-path reference (which is computed from a SHA-256 over the tool-call command + input — runtime-agnostic).

### Step 4 — Author `tests/compression-runtime-parity/fixtures/tier2-oversized-section/`

Create directory tree:

```
fixtures/tier2-oversized-section/
  config.yml          # compression.enabled: true; tier2.enabled: true; tier2.section_budget tuned to fire snip
  input/
    payload-input.txt # canonical payload with one ~30 KB Upstream Context section
  README.md
```

`config.yml` enables T2 only. The `payload-input.txt` carries a single ~30 KB Upstream Context section. T2's head-drop reduces it to budget while preserving the configured tail ratio; emits the in-band `<!-- compressed:tier2 head-dropped=N bytes -->` marker. Byte-equality across runtimes is provable because the snip is rule-based, not LLM-based.

### Step 5 — Author `tests/compression-runtime-parity/fixtures/tier3-oversized-section/`

Create directory tree:

```
fixtures/tier3-oversized-section/
  config.yml          # compression.enabled: true; tier3.enabled: true; tier3.section_budget tuned to fire T3
  input/
    payload-input.txt # canonical payload with one ~25 KB Knowledge section that survives T1+T2
  README.md
```

This fixture is **consumed by T02** (Tier 3 routing parity), not by T01's zero-LLM runner. T01 stages the directory but does not exercise it. Documenting it here keeps the corpus shape complete and authored in one place; T02's runner reads from the same tree.

### Step 6 — Author `tests/compression-runtime-parity/README.md`

Document:

1. **Purpose**: byte-equality proof that bash-only compression tiers (filter, T1, T2) produce identical compressed payloads under every supported runtime (`claude-code`, `codex`, `cursor`); routing proof that T3 dispatches through `dispatch-interface.sh` correctly under every runtime.
2. **Corpus structure**: `fixtures/<name>/{config.yml, knowledge/, input/payload-input.txt, README.md}` — each fixture isolates one tier under test.
3. **How to add a fixture**: copy an existing fixture; tune `config.yml`; rewrite `input/payload-input.txt`; add a `README.md` naming what it exercises.
4. **Byte-equality contract**: the parity runner asserts `sha256(post-pipeline payload bytes)` is identical across all runtimes per fixture. Any divergence is either a bug to fix or a row to document in `references/RUNTIME-ASSUMPTIONS.md`.
5. **Stub usage** (forward reference to T02): the `_stubs/tier3-stub-llm.sh` deterministic stub fronts `tier3-llm-call.sh` via `ORCH_TIER3_LLM_BIN` so T3 invocations are byte-deterministic across runtimes.

Min 20 lines; must contain the literal substring "byte-identical".

### Step 7 — Author `scripts/diagnostics/m018-runtime-parity.sh`

Single-script-file. Bash 3.2. AP-009-clean. Outline:

```bash
#!/usr/bin/env bash
# scripts/diagnostics/m018-runtime-parity.sh
# M018/P07/T01 — Zero-LLM parity runner.
#
# For each fixture in tests/compression-runtime-parity/fixtures/, stage a
# hermetic root under each runtime (claude-code|codex|cursor), invoke
# build-context.sh, capture the post-pipeline payload, compute SHA-256
# over the bytes, and assert the three runtimes' hashes match.
#
# Always exits 0 (FR-12 advisory pattern). Per-fixture FAIL surfaces via
# 'regression_flag: divergence' line read by the T03 verifier.

set -u
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="$PROJECT_ROOT/scripts/verify/_helpers/m018-p07-build-fixture.sh"
CORPUS_DIR="$PROJECT_ROOT/tests/compression-runtime-parity/fixtures"
FIXTURE_FILTER="all"
RUNTIMES="claude-code,codex,cursor"

# CLI parsing (case ladder; no compound chains > 2)
while [ $# -gt 0 ]; do
  case "$1" in
    --corpus-dir) CORPUS_DIR="$2"; shift 2 ;;
    --fixture)    FIXTURE_FILTER="$2"; shift 2 ;;
    --runtimes)   RUNTIMES="$2"; shift 2 ;;
    *)            shift ;;
  esac
done

# For each fixture, for each runtime: stage; invoke; capture; hash; compare.
# (Skip the tier3-oversized-section fixture in T01 — that's T02's job.)
# Print: 'runtime-parity fixture=<name> runtime=<name> sha256=<hash>'
# Per-fixture summary: 'parity fixture=<name> result=<match|divergence> runtimes=<n>'
# Always exit 0.
```

Detailed contract:

- For each fixture name (excluding `tier3-oversized-section` — T02's fixture):
  - For each runtime in `$RUNTIMES`:
    - Stage root via `bash "$HELPER" "$runtime" "$fixture"` → stdout is the staged root path.
    - Export `ORCH_BACKEND=$runtime`, `ORCHESTRATOR_ROOT=<staged-root>`.
    - Invoke `bash "$PROJECT_ROOT/scripts/dispatch/build-context.sh" --task-plan <staged-root>/input/payload-input.txt --milestone M-FIXTURE > <staged-root>/output/payload.txt 2>/dev/null`. (If build-context's CLI requires different flags, T01 author reads `scripts/dispatch/build-context.sh --help` once and matches the actual surface; the contract is "feed the fixture in; capture the post-pipeline payload out".)
    - Compute SHA-256 over the captured payload: `shasum -a 256 <staged-root>/output/payload.txt > <staged-root>/output/payload.sha256` then awk-extract field 1.
    - Print `runtime-parity fixture=<name> runtime=<runtime> sha256=<hash>`.
    - Append a `runtime_parity` JSONL record to `<staged-root>/.orchestrator/milestones/M-FIXTURE/execution-log.jsonl`: `{"record_type":"runtime_parity","fixture":"<name>","runtime":"<runtime>","sha256":"<hash>","timestamp":"<iso8601>"}`.
  - After all runtimes for this fixture: compare the three hashes. Print `parity fixture=<name> result=match runtimes=3` if all match, else `parity fixture=<name> result=divergence runtimes=3 diffs=<list>`.
- Final line: `regression_flag: <none|divergence>` (none if every fixture matched; divergence otherwise).
- Always exit 0.

MEM004 carve-out applies inside the runner body — single-pass awk + pipes permitted INSIDE the runner script. The AD-19 single-script-file shape rule applies only to the Check: line at task / phase plan level.

### Step 8 — Run the parity runner end-to-end against the corpus

```bash
bash scripts/diagnostics/m018-runtime-parity.sh --runtimes claude-code,codex,cursor --fixture all
```

Expected stdout (example):

```
runtime-parity fixture=filter-mixed-status runtime=claude-code sha256=abc...
runtime-parity fixture=filter-mixed-status runtime=codex sha256=abc...
runtime-parity fixture=filter-mixed-status runtime=cursor sha256=abc...
parity fixture=filter-mixed-status result=match runtimes=3
runtime-parity fixture=tier1-oversized-tool-result runtime=claude-code sha256=def...
[...]
parity fixture=tier2-oversized-section result=match runtimes=3
regression_flag: none
```

Exit 0. If a fixture produces divergent hashes, the run still exits 0 but the `parity ... result=divergence` line names the fixture; T03's verifier asserts on the runner's stdout.

### Step 9 — Bash-n self-check (T01 task-local Check)

```bash
bash -n scripts/diagnostics/m018-runtime-parity.sh
bash -n scripts/verify/_helpers/m018-p07-build-fixture.sh
```

Both exit 0.

## Verification

T01's task-local extractable Check is the syntax-only self-check on the parity runner:

- Check: `bash -n scripts/diagnostics/m018-runtime-parity.sh`

(One Check per task per the auto-loop verify parser. The canonical truth verifier — `m018-p07-zero-llm-parity.sh` — ships in T03 and exercises the runner end-to-end.)

## Inputs

### From Previous Tasks

(none — T01 is the entry task in the T01/T02 fan-in, both depend on P06's surface only)

### From Disk (Pre-existing)

- `scripts/dispatch/build-context.sh` — bash-only tier helpers (`_bc_apply_filter`, `_bc_apply_tier1`, `_bc_apply_tier2`) that the parity runner exercises end-to-end. Reads its own `--task-plan` / `--milestone` / `--intensity-metadata` CLI flags; T01 author reads the actual flag set once at integration time.
- `scripts/lib/knowledge-filter.sh` — `kf_get_*` accessors that read config keys from the staged `config.yml`.
- `scripts/state/resolve-root.sh` — 4-rule state root resolver that build-context.sh uses to find the staged fixture root via `ORCHESTRATOR_ROOT`.
- `scripts/verify/_helpers/m018-p06-build-fixture.sh` — canonical fixture-staging helper shape T01's helper mirrors.
- `tests/fixtures/m018-p06-tier3-fired-log/execution-log.jsonl` — JSONL-record-mix shape T01's `runtime_parity` record schema mirrors.

## Constraints

- **AD-19 / AP-009**: no compound chains > 2; no inline `$(...)` containing pipes; no plain subshells; no process substitution. SHA-256 is computed by writing to a temp file, invoking `shasum -a 256 <file>`, and awk-reading the hash.
- **CON-1 / Constitution Principle VI**: T01 modifies no production code. New files only under `scripts/diagnostics/`, `scripts/verify/_helpers/`, and `tests/compression-runtime-parity/`. Pre-M018 sentinel byte-identity is preserved.
- **CON-5 (additive emitters)**: the new `runtime_parity` JSONL record_type is additive; pre-M018 readers ignore unknown record_type values; no existing record schemas change.
- **Bash 3.2** (MEM001): no `declare -A`, no process substitution, no merged stdout-stderr shorthand. Parallel scalars / indexed arrays only.
- **Hermetic fixtures**: every parity invocation uses `ORCHESTRATOR_ROOT=<staged-root>`. No write to canonical `.orchestrator/` during the runner.
- **Always-exit-0 advisory pattern**: the runner always exits 0 even on divergence; FAIL surfaces via the `regression_flag:` line.

## Expected Output

After T01 lands:

- `tests/compression-runtime-parity/` corpus tree exists with four fixture directories (filter / tier1 / tier2 / tier3) and a `README.md`.
- `scripts/diagnostics/m018-runtime-parity.sh` exists and `bash -n` clean.
- `scripts/verify/_helpers/m018-p07-build-fixture.sh` exists and `bash -n` clean.
- `bash scripts/diagnostics/m018-runtime-parity.sh --runtimes claude-code,codex,cursor --fixture all` runs end-to-end, prints per-fixture parity lines and a `regression_flag: <none|divergence>` summary, and exits 0.
- All three filter / tier1 / tier2 fixtures report `parity ... result=match runtimes=3` on a clean checkout (the bash-only tiers ARE byte-identical because they're bash code that ignores `ORCH_BACKEND`); if a fixture diverges, T01 author files an issue and T03 documents the divergence in RUNTIME-ASSUMPTIONS.md.

## State Context

- **Current State**: executing
- **Milestone**: M018
- **Phase**: P07
- **Task**: T01-fixture-corpus-and-parity-runner
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **AD-19 / AP-009**: no compound chains > 2; no inline `$(...)` containing pipes; no plain subshells; no process substitution. SHA-256 is computed by writing to a temp file, invoking `shasum -a 256 <file>`, and awk-reading the hash.
- **CON-1 / Constitution Principle VI**: T01 modifies no production code. New files only under `scripts/diagnostics/`, `scripts/verify/_helpers/`, and `tests/compression-runtime-parity/`. Pre-M018 sentinel byte-identity is preserved.
- **CON-5 (additive emitters)**: the new `runtime_parity` JSONL record_type is additive; pre-M018 readers ignore unknown record_type values; no existing record schemas change.
- **Bash 3.2** (MEM001): no `declare -A`, no process substitution, no merged stdout-stderr shorthand. Parallel scalars / indexed arrays only.
- **Hermetic fixtures**: every parity invocation uses `ORCHESTRATOR_ROOT=<staged-root>`. No write to canonical `.orchestrator/` during the runner.
- **Always-exit-0 advisory pattern**: the runner always exits 0 even on divergence; FAIL surfaces via the `regression_flag:` line.

### Acceptance Criteria


### Files To Touch

- scripts/diagnostics/m018-runtime-parity.sh (create) — zero-LLM tier parity driver.
- scripts/diagnostics/m018-runtime-parity-tier3.sh (create) — T3 routing parity driver.
- tests/compression-runtime-parity/README.md (create) — corpus documentation.
- tests/compression-runtime-parity/fixtures/filter-mixed-status/ (create tree) — knowledge-entry fixtures with mixed `status:` values for filter parity.
- tests/compression-runtime-parity/fixtures/tier1-oversized-tool-result/ (create tree) — oversized tool-result inputs for T1 paging parity.
- tests/compression-runtime-parity/fixtures/tier2-oversized-section/ (create tree) — oversized section inputs for T2 head-drop parity.
- tests/compression-runtime-parity/fixtures/tier3-oversized-section/ (create tree) — oversized post-T2 section inputs for T3 routing parity.
- tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh (create) — deterministic stub honoring the four-flag tier3-llm-call.sh contract.
- tests/compression-runtime-parity/_stubs/README.md (create) — stub documentation.
- references/RUNTIME-ASSUMPTIONS.md (create or extend) — compression block.
- scripts/verify/m018-p07-zero-llm-parity.sh (create).
- scripts/verify/m018-p07-tier3-routing.sh (create).
- scripts/verify/m018-p07-runtime-assumptions-and-dual-write.sh (create).
- scripts/verify/_helpers/m018-p07-build-fixture.sh (create).
- .orchestrator/milestones/M018/phases/P07/_summary-body.txt (create) — narrative body for phase-transition.sh --write.
- [.orchestrator/milestones/M018/phases/P07/P07-SUMMARY.md](../../../../../milestones/M018/phases/P07/P07-SUMMARY.md) (create) — written atomically by phase-transition.sh --write.
- CLAUDE.md (modify) — `orchestrator:recent-changes` block append.
- AGENTS.md (modify) — `orchestrator:recent-changes` block (dual-write mirror).

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