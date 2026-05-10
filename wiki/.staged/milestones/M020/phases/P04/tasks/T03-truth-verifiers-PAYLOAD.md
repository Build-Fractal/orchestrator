---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T03-truth-verifiers (Phase P04, Milestone M020)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~600 | required |
| Upstream Context | 981-1131 | ~3400 | required |
| Task Plan | 1133-1779 | ~5900 | required |
| State Context | 1781-1787 | ~100 | required |
| First-Turn Completeness | 1789-1827 | ~1100 | required |
| **Total** | | **~21900** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 463
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
hit_count: 463
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
hit_count: 463
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
hit_count: 463
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
hit_count: 407
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
hit_count: 407
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
hit_count: 407
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
hit_count: 463
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
hit_count: 407
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
hit_count: 407
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
hit_count: 407
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
hit_count: 463
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
hit_count: 463
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
hit_count: 463
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
hit_count: 407
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
hit_count: 407
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
hit_count: 407
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
hit_count: 463
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
hit_count: 407
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
hit_count: 407
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
hit_count: 463
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
hit_count: 463
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
hit_count: 407
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
hit_count: 407
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
hit_count: 407
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
hit_count: 62
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
hit_count: 62
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
hit_count: 62
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
hit_count: 39
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
hit_count: 39
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
scope_tags: "[project], [milestone:M020]"
category: conventions
confidence: 0.90
created_at: 2026-04-25
last_verified: 2026-04-25
hit_count: 29
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

<!-- Each truth is a behavioral statement + a single-script-file Check.
     Per AD-19 / MEM031 / continue.md lessons (P01 + P02 + P03), Truth Check
     commands MUST use single-invocation script-file shape — no inline
     compound bash, no plain subshells, no $() containing pipes, no
     process substitution. Verifier scripts referenced here are produced
     by the listed task; the phase-level Verification Commands block at
     the bottom is the rollup. -->

- `scripts/knowledge/compute-staleness.sh` exposes a `--review-queue --root <orch-root>` mode that walks `<orch-root>/../knowledge/**/MEM*.md` (or `--knowledge-root <path>` override), filters to `status: candidate`, groups by cluster via the P05 `lib/cluster.sh::cluster_compute` helper, and emits one `cluster_id=<C8hex> topic=<topic> count=<N> oldest_age=<days>` line per cluster on stdout; emits exactly `EMPTY` on stdout when no candidates exist; exits 0 in both cases.
  - Check: `bash scripts/verify/m020-p04-compute-staleness-review-queue.sh`
- `scripts/knowledge/compute-staleness.sh --review-queue` flags clusters whose oldest member's `created_at:` (with `last_verified:` fallback) is older than the resolved staleness threshold (default 14 days per OQ-1; reads `.orchestrator/preferences.yml::staleness_threshold` integer-scalar override when present and non-malformed) by appending ` stale=true` to that cluster's summary line; well-formed clusters emit ` stale=false`.
  - Check: `bash scripts/verify/m020-p04-compute-staleness-stale-flag.sh`
- `scripts/orchestrator/status.sh` emits a `Review Queue:` section after the existing `MILESTONE:` / `STATE:` / `PHASE:` lines: when the queue is non-empty, the section's first line matches `^Review Queue: <N> clusters, <M> entries awaiting review$` (N = cluster count, M = total candidate count) followed by one indented per-cluster summary line per cluster prefixed with two-space indent; when the queue is empty, the section is exactly the single line `Review Queue: empty`.
  - Check: `bash scripts/verify/m020-p04-status-review-queue-section.sh`
- `scripts/orchestrator/status.sh` Review-Queue rendering surfaces the `(stale)` marker on per-cluster summary lines whose underlying compute-staleness output carries `stale=true`; non-stale cluster lines do NOT carry the marker; the marker text is the literal `(stale)` (parenthesised, lowercase) at end-of-line.
  - Check: `bash scripts/verify/m020-p04-status-stale-marker.sh`

<dispatch-volatile>

## Upstream Context


### P03 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P03"
parent: "M020"
milestone: "M020"
provides:
  - "scripts/knowledge/lib/decision-history.sh sourceable helper exposing dh_resolve_operator (git config user.email -> .orchestrator/preferences.yml:operator_identifier -> unknown@local fallthrough per OQ-2) and dh_emit_jsonl <event> <kv>... (appends single JSON object per call to $ORCH_ROOT/execution-log.jsonl with event+timestamp+milestone plus supplied key=value pairs as JSON string properties; conservative backslash+double-quote escaping; no jq dependency); contract verifier scripts/verify/m020-p03-decision-history-helper-contract.sh covering 5 cases (function exposure,git-set path,tmpdir fallthrough,preferences.yml fallback,JSONL shape,embedded-quote escape),scripts/knowledge/graduate.sh extended in place with --cluster <id> + --reject + multi-entry positional shape; cluster atomicity drift gate (THREAT-006 disposition) with zero file mutations on abort; --reject body archives every member without archived_into; canonical+sibling write loop on graduate path with archived_into back-references; decision_history append on every member via T01+P01 helpers; JSONL emission via dh_emit_jsonl (one knowledge_graduate + N-1 knowledge_archive on graduate; N knowledge_archive on reject); P01 single-entry surface preserved per CON-4; five new T02-owned verifier scripts under scripts/verify/ all green,scripts/verify/knowledge-schema-lint.sh — FR-9 + SC-8 schema-authority enforcement gate covering three failure shapes (unauthorized-field,vocabulary-drift,malformed-frontmatter); embeds the M020-authorized field allowlist as canonical machine-readable encoding of D024 + MEM031; per-task contract verifiers scripts/verify/m020-p03-schema-lint-contract.sh and scripts/verify/m020-p03-schema-lint-vocabulary-drift.sh exercising the lint against tempdir fixtures and the live tree,tests/test-graduate-workflow.sh — SC-2 end-to-end integration test for the P03 graduate.sh extension; exercises four operational modes (three-entry cluster graduate,single-entry cluster graduate,cluster reject,cluster-membership-drift abort) using tempdir+PROJECT_ROOT+ORCH_ROOT fixture isolation; 31 assertions covering status flips,archived_into back-references,decision_history block presence,rationale text propagation,JSONL record counts (knowledge_graduate + knowledge_archive),drift-abort exit code + diagnostic + atomic byte-equivalence + zero-JSONL invariant"
requires:
  - "P01"
affects:
  - "P04,P05"
key_files:
  - "scripts/knowledge/lib/decision-history.sh,scripts/verify/m020-p03-decision-history-helper-contract.sh,scripts/knowledge/graduate.sh,scripts/verify/m020-p03-graduate-cluster-multi-entry.sh,scripts/verify/m020-p03-graduate-cluster-drift-abort.sh,scripts/verify/m020-p03-graduate-reject-path.sh,scripts/verify/m020-p03-graduate-jsonl-emit.sh,scripts/verify/m020-p03-graduate-p01-shape-preserved.sh,scripts/verify/knowledge-schema-lint.sh,scripts/verify/m020-p03-schema-lint-contract.sh,scripts/verify/m020-p03-schema-lint-vocabulary-drift.sh,tests/test-graduate-workflow.sh"
key_decisions:
  - "none-new,D024"
patterns_established:
  - "double-source guard sentinel (_<HELPER>_SOURCED=1) lets multiple sourceable helpers coexist without re-definition,pure-helper composition (T01 resolves identity + emits JSONL; T02 graduate.sh calls dh_resolve_operator once and pairs fm_append_decision_history entry-side with dh_emit_jsonl log-side; the two writes are independent),5-case contract verifier template (function exposure -> happy path -> isolated-tmpdir fallthrough -> env-overridden fallback -> emitter shape -> escape edge case),pragmatic case-statement acceptance for git-leakage-into-tmpdir-verifiers (case op in *@*) ;; unknown@local) ;; *) FAIL ;; esac accepts either real-git-email leaked from ~/.gitconfig or the documented sentinel since GIT_CONFIG_NOSYSTEM cannot be set at script invocation level),cluster-aware mutation script pattern (pre-flight read of every member's gate-relevant state -> abort with structured diagnostic + zero mutations on drift -> deterministic write loop with shared per-cluster scalars (operator,rationale_hash,canonical) -> JSONL emission after all writes succeed); drift-gate-as-CON-4-preserver (gating the new pre-flight on the new flag means the legacy invocation shape pays no cost and exhibits no behavior diff -- generalizable to any in-place script extension); operator+rationale_hash resolved once per cluster invocation (not per-member) for JSONL consistency; per-helper atomicity composes into cluster atomicity (each fm_* write is tempfile+rename atomic; pre-flight drift gate guarantees N writes succeed under FR-9 closed-enum); parallel newline-joined scalars for cluster member tracking (ids/files accumulate as newline-separated strings,iterated via awk -v n=$i NR==n) per MEM001 bash-3.2 convention,closed-enum lint pattern (structural-only,read-only,fixture-tested via tempdir + heredoc,single-script Check shape); authorized-field allowlist as newline-separated heredoc-fed string for bash 3.2 iteration without associative arrays; tempdir + trap-EXIT-rm-rf for negative-test fixtures so the live knowledge/ tree is never touched by verifiers; process-substitution-inside-script-body is AD-19-safe because the harness shape-guard inspects Bash tool-call shapes not script internals,grep -c X file safe-counter — the grep -c pattern returns rc=1 when count is 0 AND prints 0 itself; the common '|| echo 0' fallback DOUBLES the count line and breaks subsequent integer comparisons. Wrap in a count_event helper that suppresses rc with '|| true' and defaults empty to 0. Single-script Verification Check shape (bash tests/test-graduate-workflow.sh) where the test file ITSELF uses heredocs + pipes + process redirections internally — AD-19 / AP-009 govern Bash tool-call shapes,not script internals; the harness shape-guard inspects only the directly-invoked command. Tempdir + trap-EXIT-rm-rf + PROJECT_ROOT + ORCH_ROOT env-override fixture isolation pattern (CON-1 / FR-8 read-only-during-dispatch) — every fixture lives under mktemp -d,and the live knowledge/** + .orchestrator/execution-log.jsonl are never touched. Portable md5 (macOS md5 -q vs linux md5sum) via 'command -v md5sum' fallback for byte-equivalence assertions on drift-abort. JSONL structural assertion via 'grep -c event:X' instead of jq parsing — keeps jq optional per MEM001. fm_get awk frontmatter reader inlined in the test (reads first --- block,supports keys with single-line scalar values,strips wrapping quotes) — no source dependency on lib/frontmatter.sh because the test asserts the post-mutation file contract,not the helper's behavior."
drill_down_paths:
  - "[.orchestrator/milestones/M020/phases/P03/tasks/T01-decision-history-helper-SUMMARY.md](../../../../../milestones/M020/phases/P03/tasks/T01-decision-history-helper-SUMMARY.md), [.orchestrator/milestones/M020/phases/P03/tasks/T02-graduate-cluster-extension-SUMMARY.md](../../../../../milestones/M020/phases/P03/tasks/T02-graduate-cluster-extension-SUMMARY.md), [.orchestrator/milestones/M020/phases/P03/tasks/T03-schema-authority-lint-SUMMARY.md](../../../../../milestones/M020/phases/P03/tasks/T03-schema-authority-lint-SUMMARY.md), [.orchestrator/milestones/M020/phases/P03/tasks/T04-integration-test-SUMMARY.md](../../../../../milestones/M020/phases/P03/tasks/T04-integration-test-SUMMARY.md)"
duration: "85m"
verification_result: "pass"
completed_at: "2026-04-25T14:44:42Z"
observability_surfaces:
  - "execution-log.jsonl:knowledge_graduate;execution-log.jsonl:knowledge_archive"
---

## Phase Outcome

P03 delivered the candidate→graduate cluster workflow plus the
schema-authority enforcement gate. Four tasks executed sequentially
with each task summary written via the structured helper:

- **T01 (decision-history-helper):** `scripts/knowledge/lib/decision-history.sh`
  exposes `dh_resolve_operator` (`git config user.email` →
  `.orchestrator/preferences.yml:operator_identifier` → `unknown@local`
  fallthrough per OQ-2) and `dh_emit_jsonl <event> <kv>...` (appends
  one JSON object per call to `$ORCH_ROOT/execution-log.jsonl` with
  conservative backslash + double-quote escaping; no jq dependency).
  5-case contract verifier covers function exposure, git-set path,
  isolated-tmpdir fallthrough, preferences.yml fallback, JSONL shape
  with embedded-quote escape.
- **T02 (graduate-cluster-extension):** `scripts/knowledge/graduate.sh`
  extended in place with `--cluster <id>`, `--reject`, multi-entry
  positional shape. Pre-flight `fm_read_status` on every member;
  `cluster-membership-drift` abort with zero file mutations on any
  non-`candidate` member (THREAT-006 disposition). Graduate path
  flips first member to `graduated`, remaining members to `archived`
  with `archived_into: <canonical>` back-references; reject path
  archives every member without `archived_into`. `decision_history:`
  appended on every member; one `knowledge_graduate` + N-1
  `knowledge_archive` JSONL records on graduate, N
  `knowledge_archive` on reject. P01 single-entry surface preserved
  byte-equivalent (CON-4) — drift gate and cluster fan-out are gated
  on `--cluster` so legacy invocation pays no cost.
- **T03 (schema-authority-lint):** `scripts/verify/knowledge-schema-lint.sh`
  enforces FR-9 + SC-8 with three failure shapes
  (`unauthorized-field`, `vocabulary-drift`, `malformed-frontmatter`).
  Embeds the M020-authorized field allowlist as canonical
  machine-readable encoding of D024 + MEM031. Live tree scan: 31
  entries / 0 violations.
- **T04 (integration-test):** `tests/test-graduate-workflow.sh` —
  311-line MEM002-conformant SC-2 end-to-end across four cases:
  three-entry cluster graduate (13 PASS), single-entry cluster
  graduate (5 PASS), cluster reject (8 PASS), cluster-membership-drift
  abort (5 PASS). 31/31 assertions PASS.

## Verification

9/9 phase-level truths PASS. 32/32 artifact assertions PASS. 4/4
key-link assertions PASS. All four per-task verifications PASS.
Phase rollup `bash scripts/verify/check-must-haves.sh
.orchestrator/milestones/M020/phases/P03` exits 0. Live-tree
schema lint exits 0 against 31 entries.

## Key Patterns

- **Cluster-aware mutation script pattern:** pre-flight read of every
  member's gate-relevant state → abort with structured diagnostic +
  zero mutations on drift → deterministic write loop with shared
  per-cluster scalars (operator, rationale_hash, canonical) → JSONL
  emission after all writes succeed.
- **Drift-gate-as-CON-4-preserver:** gating new pre-flight checks on
  the new flag means legacy invocation pays no cost and exhibits no
  behavior diff — generalizable to any in-place script extension.
- **Pure-helper composition (T01 + T02):** `dh_resolve_operator` once
  per cluster + `fm_append_decision_history` entry-side paired with
  `dh_emit_jsonl` log-side. The two writes are independent and
  composable with file-level atomicity (tempfile+rename) into
  cluster atomicity.
- **Closed-enum lint pattern:** structural-only, read-only,
  fixture-tested via tempdir + heredoc. Authorized-field allowlist
  encoded as newline-separated heredoc-fed string for bash 3.2
  iteration without associative arrays.
- **Pragmatic case-statement acceptance for environmental leakage:**
  when GIT_CONFIG_NOSYSTEM cannot be enforced at script-invocation
  level, accept either the real-git-email leaked from `~/.gitconfig`
  or the documented sentinel via `case op in *@*) ok;; unknown@local) ok;; *) fail;;`.
- **`grep -c X file` safe-counter:** `grep -c` returns rc=1 AND
  prints `0` when count is zero. The common `|| echo 0` fallback
  *doubles* the count line and breaks integer comparisons. Wrap in a
  `count_event()` helper that suppresses rc with `|| true` and
  defaults empty to 0.
- **Process-substitution-inside-script-body is AD-19 safe:** the
  harness shape-guard inspects Bash tool-call shapes, not script
  internals. Test files can use heredocs + pipes + process
  redirections freely; only the directly-invoked command shape is
  gated.
- **Portable md5:** `command -v md5sum` fallback for macOS
  (`md5 -q`) vs linux (`md5sum`) byte-equivalence assertions.
- **Double-source guard sentinel** (`_<HELPER>_SOURCED=1`) lets
  multiple sourceable helpers coexist without re-definition.

## Carry-Forward Lessons

In addition to the seven lessons recorded at the P02→P03 boundary
(see `.orchestrator/milestones/M020/continue.md`), P03 added:

8. **`grep -c` is rc-1 + prints-`0` on no-match.** The `|| echo 0`
   fallback emits `0\n0` on no-match, which breaks `[ "$count" -eq N ]`.
   Wrap in `count_event()` with `|| true` and default-empty-to-zero.
9. **Pre-existing `git status` dirtiness (hit_count churn from prior
   index rebuilds + ingest runs) is the new normal.** Future
   verifiers should NOT assert `git status knowledge/` is empty;
   instead assert that the verifier under test *did not write to
   `knowledge/`* via tempdir-scoped fixture isolation. The phase
   plan's "Done when" criterion misled T03 into noting a non-blocking
   caveat that's structurally pre-existing.
10. **Environmental git-config leakage in tests:** when fixture
    isolation requires "no git identity available", `GIT_CONFIG_NOSYSTEM`
    cannot be set at the dispatched script level. Accept either real
    leaked email or the sentinel — tighter assertion is impossible
    without rewriting the dispatch wrapper.

## Affects Downstream

- **P04 (review queue in `orchestrator:status`):** consumes the
  `decision_history:` schema field + JSONL `knowledge_graduate` /
  `knowledge_archive` records to surface pending-review state.
- **P05 (Jaccard clustering in `orchestrator:consolidate`):**
  consumes `--cluster <id>` graduate.sh entry point + the
  cluster-membership-drift contract (THREAT-006). Cluster-id
  generation lives in P05; graduate.sh trusts the caller's id.
- **P06 (preferences layer):** continues to consume P02's `query.sh`
  JSON shape; P03 added `preferences.yml:operator_identifier` as
  the documented identity-fallback key.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P04"
milestone: "M020"
name: "per-truth contract verifiers (scripts/verify/m020-p04-*.sh)"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01: `scripts/knowledge/compute-staleness.sh --review-queue [--knowledge-root <path>]` ships the documented stdout contract (`EMPTY` sentinel; one `cluster_id=...` line per cluster otherwise). Legacy invocation shape preserved.
- T02: `scripts/orchestrator/status.sh` ships the Review-Queue section rendering with empty / non-empty / unavailable / stale-marker shapes; pre-P04 prefix preserved byte-equivalent.
- P05: `scripts/knowledge/lib/cluster.sh::cluster_compute` is on main and the live tree has zero `status: candidate` entries (so `--review-queue` against the live tree emits `EMPTY` deterministically).
- P03/T04 carry-forward: tempdir + trap-EXIT-rm-rf + PROJECT_ROOT + ORCH_ROOT env-override fixture isolation pattern. The harness shape-guard inspects only directly-invoked Bash tool-call shapes; verifier internals may use heredocs / pipes / process-substitution / `<<EOF` freely (P03/T04 carry-forward and AD-19 + AP-009 governance).

## Description

Ship the six per-truth verifiers under `scripts/verify/`, one per phase-plan Truth. Each verifier is a single-script-file invocation that can be run by `scripts/verify/check-must-haves.sh` or directly by `orchestrator:auto`. All verifiers use tempdir + trap-EXIT-rm-rf fixture isolation; the live `knowledge/**` tree and the live `.orchestrator/execution-log.jsonl` are NEVER touched by any T03 verifier.

The six verifiers map 1:1 to the six "Truths" in `P04-PLAN.md`'s Must-Haves block. Each verifier prints exactly one trailing `PASS: <truth-summary>` line on success and exits 0; on failure each emits one or more `FAIL: <reason>` lines and exits 1.

**Authoring convention** (mirrors P03/T03 + P03/T01 + P05/T02 patterns):

- Bash 3.2 safe (no `declare -A`, no `mapfile`, no `<<<` here-strings inside `$()`).
- `set -u` (NOT `set -e`; we want explicit `|| true` discipline so a failed assertion can emit `FAIL:` and exit 1 instead of dying silently).
- `tmpdir="$(mktemp -d)"; trap 'rm -rf "$tmpdir"' EXIT`.
- Path resolution: `ROOT="$(cd "$(dirname "$0")/../.." && pwd)"` resolves the repo root from `scripts/verify/<this>.sh`.
- Tempdir fixture layout: `<tmpdir>/orch/` is the orchestrator state root, `<tmpdir>/knowledge/` is the candidate knowledge tree (as a sibling of `orch`, mirroring how the live tree sits at `<repo>/knowledge/` next to `<repo>/.orchestrator/`).
- Script-under-test invocation: pass `--knowledge-root "$tmpdir/knowledge"` (compute-staleness.sh) or set `PWD` via `cd "$tmpdir"` plus pass `--root "$tmpdir/orch"` (status.sh).
- Fixture entries are minimal MEM-files with the smallest valid frontmatter (id, status, created_at, last_verified, topic, tags). Bodies are <=10 lines so cluster.sh's body-window doesn't dominate the feature vector.

## Steps

### Step 1: Create the six verifier scripts

Each script lives at `scripts/verify/m020-p04-<truth-slug>.sh`. The full list with one-line descriptions:

1. `m020-p04-compute-staleness-review-queue.sh` — exercises T01's stdout shape: builds a fixture with two candidate entries (similar enough to cluster) + one graduated entry (must be excluded), invokes `--review-queue --knowledge-root <fixture>`, asserts stdout starts with `cluster_id=C` and contains `count=2`, plus a separate run against an empty fixture asserts stdout is `EMPTY` exactly.
2. `m020-p04-compute-staleness-stale-flag.sh` — builds a fixture with one candidate entry whose `created_at:` is `2025-01-01` (>14 days before the test reference date), invokes `--review-queue`, asserts stdout cluster line contains `stale=true`. Second run with `created_at:` set to today's date asserts the line contains `stale=false`.
3. `m020-p04-status-review-queue-section.sh` — builds a fixture orchestrator root + knowledge tree with candidate entries, invokes `bash scripts/orchestrator/status.sh --root <fixture-orch>`, asserts stdout contains a `^Review Queue: <N> clusters, <M> entries awaiting review$` line followed by `<N>` indented `  cluster=` lines. Second sub-case asserts the empty-knowledge-tree fixture emits the literal `Review Queue: empty` line.
4. `m020-p04-status-stale-marker.sh` — builds a fixture with one candidate created `2024-01-01` (clearly stale), invokes status.sh, asserts the cluster line ends with ` (stale)`. Negative sub-case: replaces `created_at:` with today's date, re-invokes, asserts no `(stale)` token.
5. `m020-p04-status-review-queue-readonly.sh` — builds a fixture, captures `find <fixture>/knowledge -type f -exec md5 {} +` (or `md5sum`) into a checksum baseline, invokes status.sh, recomputes the checksum, asserts byte-equivalent. Also asserts `<fixture-orch>/execution-log.jsonl` does NOT exist post-invocation (status.sh must not create it).
6. `m020-p04-status-prefix-preserved.sh` — builds a fixture orchestrator root containing one milestone (`M999/M999-FOO.md`) with one phase (`P01/P01-PLAN.md` to set state to executing). Invokes status.sh against the fixture twice: once before any candidates exist, once after seeding two candidates. Asserts that the prefix lines (`MILESTONE: M999`, `STATE: executing`, `PHASE: P01 executing`) are byte-equivalent in both runs (only the trailing Review-Queue section changes).

#### Verifier 1: `scripts/verify/m020-p04-compute-staleness-review-queue.sh`

```bash
#!/usr/bin/env bash
# m020-p04-compute-staleness-review-queue.sh — assert T01 --review-queue
# stdout shape: EMPTY-on-empty + cluster_id=... line per cluster.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HELPER="$ROOT/scripts/knowledge/compute-staleness.sh"

if [ ! -f "$HELPER" ]; then
  echo "FAIL: compute-staleness.sh missing at $HELPER"
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# --- Case 1: empty knowledge tree -> EMPTY sentinel, exit 0 ---
mkdir -p "$tmpdir/empty/conventions"
out="$(bash "$HELPER" --review-queue --knowledge-root "$tmpdir/empty" 2>"$tmpdir/empty.err")"
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL: empty case exit rc=$rc; stderr: $(cat "$tmpdir/empty.err")"
  exit 1
fi
if [ "$out" != "EMPTY" ]; then
  echo "FAIL: empty case stdout != 'EMPTY'; got: '$out'"
  exit 1
fi

# --- Case 2: two candidates clustering -> one cluster_id= line ---
mkdir -p "$tmpdir/candidates/patterns"
write_entry() {
  local id="$1" topic="$2" body="$3" file="$tmpdir/candidates/patterns/$id.md"
  cat >"$file" <<EOF
---
id: $id
status: candidate
created_at: 2026-04-01
last_verified: 2026-04-01
topic: $topic
tags: [test, fixture]
confidence: 0.5
hit_count: 0
---

$body
EOF
}
write_entry MEM900 alpha "alpha alpha alpha pattern test fixture body unique"
write_entry MEM901 alpha "alpha alpha alpha pattern test fixture body unique"

out2="$(bash "$HELPER" --review-queue --knowledge-root "$tmpdir/candidates" 2>"$tmpdir/cand.err")"
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL: candidates case exit rc=$rc; stderr: $(cat "$tmpdir/cand.err")"
  exit 1
fi

# Expect at least one line starting with cluster_id=C and containing topic=alpha + count=
case "$out2" in
  cluster_id=C*topic=alpha*count=*)
    ;;
  *)
    echo "FAIL: candidates case stdout missing cluster_id=...topic=alpha...count= ; got:"
    echo "$out2"
    exit 1
    ;;
esac

# Sanity: stdout MUST NOT include 'EMPTY' when candidates exist.
case "$out2" in
  *EMPTY*)
    echo "FAIL: candidates case stdout contains EMPTY: $out2"
    exit 1
    ;;
esac

echo "PASS: compute-staleness.sh --review-queue stdout shape (EMPTY + cluster_id lines)"
exit 0
```

`chmod +x scripts/verify/m020-p04-compute-staleness-review-queue.sh`.

#### Verifier 2: `scripts/verify/m020-p04-compute-staleness-stale-flag.sh`

```bash
#!/usr/bin/env bash
# m020-p04-compute-staleness-stale-flag.sh — assert T01 stale=true|false flag
# resolves correctly against the staleness threshold.
# Bash 3.2 safe.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HELPER="$ROOT/scripts/knowledge/compute-staleness.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/k/patterns"
TODAY="$(date -u +%Y-%m-%d)"

# --- Case 1: a clearly-stale candidate (created Jan 2024) ---
cat >"$tmpdir/k/patterns/MEM900.md" <<EOF
---
id: MEM900
status: candidate
created_at: 2024-01-01
last_verified: 2024-01-01
topic: stale_topic
tags: [test]
confidence: 0.5
hit_count: 0
---

stale candidate body unique tokens
EOF

out_stale="$(bash "$HELPER" --review-queue --knowledge-root "$tmpdir/k" 2>"$tmpdir/stale.err")"
case "$out_stale" in
  *stale=true*) ;;
  *)
    echo "FAIL: stale case did not set stale=true; got: $out_stale"
    exit 1
    ;;
esac

# --- Case 2: a fresh candidate (created today) ---
cat >"$tmpdir/k/patterns/MEM900.md" <<EOF
---
id: MEM900
status: candidate
created_at: $TODAY
last_verified: $TODAY
topic: fresh_topic
tags: [test]
confidence: 0.5
hit_count: 0
---

fresh candidate body unique tokens
EOF

out_fresh="$(bash "$HELPER" --review-queue --knowledge-root "$tmpdir/k" 2>"$tmpdir/fresh.err")"
case "$out_fresh" in
  *stale=false*) ;;
  *)
    echo "FAIL: fresh case did not set stale=false; got: $out_fresh"
    exit 1
    ;;
esac

# Confirm fresh case did NOT emit stale=true.
case "$out_fresh" in
  *stale=true*)
    echo "FAIL: fresh case incorrectly emitted stale=true: $out_fresh"
    exit 1
    ;;
esac

echo "PASS: compute-staleness.sh stale=true|false flag resolution"
exit 0
```

`chmod +x scripts/verify/m020-p04-compute-staleness-stale-flag.sh`.

#### Verifier 3: `scripts/verify/m020-p04-status-review-queue-section.sh`

```bash
#!/usr/bin/env bash
# m020-p04-status-review-queue-section.sh — assert T02 emits the
# 'Review Queue:' section with empty + non-empty rendering.
# Bash 3.2 safe.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
STATUS_SH="$ROOT/scripts/orchestrator/status.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# Build a minimal orchestrator state root with one milestone, no candidates.
mkdir -p "$tmpdir/orch/milestones/M999/phases/P01"
cat >"$tmpdir/orch/milestones/M999/M999-EVALUATION.md" <<'EOF'
---
type: evaluation
tier: C
---

placeholder
EOF
cat >"$tmpdir/orch/milestones/M999/M999-ROADMAP.md" <<'EOF'
---
type: roadmap
milestone: M999
---

- [ ] **P01**: placeholder
EOF
cat >"$tmpdir/orch/milestones/M999/phases/P01/P01-PLAN.md" <<'EOF'
---
type: phase-plan
phase: P01
milestone: M999
---

placeholder
EOF

mkdir -p "$tmpdir/knowledge/conventions"

# --- Case 1: empty queue -> 'Review Queue: empty' ---
cd "$tmpdir"
out1="$(bash "$STATUS_SH" --root "$tmpdir/orch" 2>"$tmpdir/case1.err" || true)"
case "$out1" in
  *"Review Queue: empty"*) ;;
  *)
    echo "FAIL: empty case stdout missing 'Review Queue: empty'; got:"
    echo "$out1"
    exit 1
    ;;
esac

# Confirm absence of per-cluster lines (no '  cluster=' indented lines).
if printf '%s\n' "$out1" | grep -qE '^[[:space:]]+cluster='; then
  echo "FAIL: empty case stdout contains an unexpected cluster= line"
  echo "$out1"
  exit 1
fi

# --- Case 2: two candidates clustering -> non-empty header + indented lines ---
mkdir -p "$tmpdir/knowledge/patterns"
write_entry() {
  local id="$1" topic="$2"
  cat >"$tmpdir/knowledge/patterns/$id.md" <<EOF
---
id: $id
status: candidate
created_at: 2026-04-01
last_verified: 2026-04-01
topic: $topic
tags: [test]
confidence: 0.5
hit_count: 0
---

beta beta beta token vocabulary fixture
EOF
}
write_entry MEM910 beta_topic
write_entry MEM911 beta_topic

out2="$(bash "$STATUS_SH" --root "$tmpdir/orch" 2>"$tmpdir/case2.err" || true)"

# Header line shape.
if ! printf '%s\n' "$out2" | grep -qE '^Review Queue: [0-9]+ clusters, [0-9]+ entries awaiting review$'; then
  echo "FAIL: non-empty case missing well-formed 'Review Queue: <N> clusters, <M> entries' header"
  echo "$out2"
  exit 1
fi

# At least one indented cluster= line.
if ! printf '%s\n' "$out2" | grep -qE '^  cluster=C[0-9a-f]{8} '; then
  echo "FAIL: non-empty case missing indented '  cluster=C<8hex>' summary line"
  echo "$out2"
  exit 1
fi

echo "PASS: status.sh Review Queue: section (empty + non-empty rendering)"
exit 0
```

`chmod +x scripts/verify/m020-p04-status-review-queue-section.sh`.

#### Verifier 4: `scripts/verify/m020-p04-status-stale-marker.sh`

```bash
#!/usr/bin/env bash
# m020-p04-status-stale-marker.sh — assert T02 renders ' (stale)' marker on
# stale cluster lines and omits it on fresh ones.
# Bash 3.2 safe.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
STATUS_SH="$ROOT/scripts/orchestrator/status.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/orch/milestones/M999/phases/P01"
cat >"$tmpdir/orch/milestones/M999/M999-EVALUATION.md" <<'EOF'
---
type: evaluation
tier: C
---

placeholder
EOF
cat >"$tmpdir/orch/milestones/M999/phases/P01/P01-PLAN.md" <<'EOF'
---
type: phase-plan
phase: P01
milestone: M999
---

placeholder
EOF

mkdir -p "$tmpdir/knowledge/patterns"

# --- Stale fixture ---
cat >"$tmpdir/knowledge/patterns/MEM900.md" <<'EOF'
---
id: MEM900
status: candidate
created_at: 2024-01-01
last_verified: 2024-01-01
topic: stale_topic
tags: [test]
confidence: 0.5
hit_count: 0
---

stale body content tokens disjoint
EOF

cd "$tmpdir"
out_stale="$(bash "$STATUS_SH" --root "$tmpdir/orch" 2>"$tmpdir/stale.err" || true)"
if ! printf '%s\n' "$out_stale" | grep -qE '^  cluster=.*\(stale\)$'; then
  echo "FAIL: stale fixture cluster line missing ' (stale)' marker; got:"
  echo "$out_stale"
  exit 1
fi

# --- Fresh fixture (today) ---
TODAY="$(date -u +%Y-%m-%d)"
cat >"$tmpdir/knowledge/patterns/MEM900.md" <<EOF
---
id: MEM900
status: candidate
created_at: $TODAY
last_verified: $TODAY
topic: fresh_topic
tags: [test]
confidence: 0.5
hit_count: 0
---

fresh body content tokens disjoint
EOF

out_fresh="$(bash "$STATUS_SH" --root "$tmpdir/orch" 2>"$tmpdir/fresh.err" || true)"
if printf '%s\n' "$out_fresh" | grep -qE '\(stale\)'; then
  echo "FAIL: fresh fixture stdout incorrectly contains '(stale)' marker:"
  echo "$out_fresh"
  exit 1
fi

echo "PASS: status.sh ' (stale)' marker rendering"
exit 0
```

`chmod +x scripts/verify/m020-p04-status-stale-marker.sh`.

#### Verifier 5: `scripts/verify/m020-p04-status-review-queue-readonly.sh`

```bash
#!/usr/bin/env bash
# m020-p04-status-review-queue-readonly.sh — assert status.sh does NOT
# mutate knowledge/** or .orchestrator/execution-log.jsonl when invoked.
# Bash 3.2 safe.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
STATUS_SH="$ROOT/scripts/orchestrator/status.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/orch/milestones/M999/phases/P01"
cat >"$tmpdir/orch/milestones/M999/phases/P01/P01-PLAN.md" <<'EOF'
---
type: phase-plan
phase: P01
milestone: M999
---

placeholder
EOF

mkdir -p "$tmpdir/knowledge/patterns"
cat >"$tmpdir/knowledge/patterns/MEM900.md" <<'EOF'
---
id: MEM900
status: candidate
created_at: 2026-04-01
last_verified: 2026-04-01
topic: read_only_topic
tags: [test]
---

readonly body content tokens
EOF

# --- Capture knowledge/ checksums ---
md5_of() {
  if command -v md5sum >/dev/null 2>&1; then
    md5sum "$1" | awk '{print $1}'
  else
    md5 -q "$1"
  fi
}

before_md5="$(md5_of "$tmpdir/knowledge/patterns/MEM900.md")"

# Invoke status.sh.
cd "$tmpdir"
bash "$STATUS_SH" --root "$tmpdir/orch" >/dev/null 2>"$tmpdir/err"

after_md5="$(md5_of "$tmpdir/knowledge/patterns/MEM900.md")"
if [ "$before_md5" != "$after_md5" ]; then
  echo "FAIL: status.sh mutated knowledge entry MEM900.md (md5 before=$before_md5 after=$after_md5)"
  exit 1
fi

# Confirm no execution-log.jsonl was created under fixture orch.
if [ -f "$tmpdir/orch/execution-log.jsonl" ]; then
  echo "FAIL: status.sh created $tmpdir/orch/execution-log.jsonl (must remain absent)"
  exit 1
fi

echo "PASS: status.sh read-only invariant (knowledge/ + execution-log.jsonl untouched)"
exit 0
```

`chmod +x scripts/verify/m020-p04-status-review-queue-readonly.sh`.

#### Verifier 6: `scripts/verify/m020-p04-status-prefix-preserved.sh`

```bash
#!/usr/bin/env bash
# m020-p04-status-prefix-preserved.sh — assert status.sh emits the same
# pre-Review-Queue prefix lines (MILESTONE/STATE/PHASE) byte-equivalent
# regardless of whether the knowledge tree has candidates.
# Bash 3.2 safe.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
STATUS_SH="$ROOT/scripts/orchestrator/status.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/orch/milestones/M999/phases/P01"
cat >"$tmpdir/orch/milestones/M999/phases/P01/P01-PLAN.md" <<'EOF'
---
type: phase-plan
phase: P01
milestone: M999
---

placeholder
EOF

mkdir -p "$tmpdir/knowledge/patterns"

# --- Capture #1: empty knowledge ---
cd "$tmpdir"
cap1="$(bash "$STATUS_SH" --root "$tmpdir/orch" 2>/dev/null || true)"

# --- Capture #2: with one candidate ---
cat >"$tmpdir/knowledge/patterns/MEM900.md" <<'EOF'
---
id: MEM900
status: candidate
created_at: 2026-04-01
last_verified: 2026-04-01
topic: prefix_topic
tags: [test]
---

prefix preservation body content tokens
EOF
cap2="$(bash "$STATUS_SH" --root "$tmpdir/orch" 2>/dev/null || true)"

# Extract prefix lines (everything before the first 'Review Queue:' line).
extract_prefix() {
  printf '%s\n' "$1" | awk '/^Review Queue:/{exit} {print}'
}

prefix1="$(extract_prefix "$cap1")"
prefix2="$(extract_prefix "$cap2")"

if [ "$prefix1" != "$prefix2" ]; then
  echo "FAIL: status.sh prefix differs between empty and non-empty knowledge runs"
  echo "--- empty prefix ---"
  printf '%s\n' "$prefix1"
  echo "--- non-empty prefix ---"
  printf '%s\n' "$prefix2"
  exit 1
fi

# Confirm prefix contains the expected three line-shapes for M999.
case "$prefix1" in
  *"MILESTONE: M999"*)
    ;;
  *)
    echo "FAIL: prefix missing 'MILESTONE: M999' line: $prefix1"
    exit 1
    ;;
esac
case "$prefix1" in
  *"PHASE: P01 "*)
    ;;
  *)
    echo "FAIL: prefix missing 'PHASE: P01 ...' line: $prefix1"
    exit 1
    ;;
esac

echo "PASS: status.sh pre-Review-Queue prefix byte-equivalent across empty + non-empty runs"
exit 0
```

`chmod +x scripts/verify/m020-p04-status-prefix-preserved.sh`.

### Step 2: `chmod +x` all six

```
chmod +x scripts/verify/m020-p04-compute-staleness-review-queue.sh
chmod +x scripts/verify/m020-p04-compute-staleness-stale-flag.sh
chmod +x scripts/verify/m020-p04-status-review-queue-section.sh
chmod +x scripts/verify/m020-p04-status-stale-marker.sh
chmod +x scripts/verify/m020-p04-status-review-queue-readonly.sh
chmod +x scripts/verify/m020-p04-status-prefix-preserved.sh
```

(One chmod per verifier; six lines total. Single-script-file Check shapes only.)

## Must-Haves

- All six verifier scripts exist under `scripts/verify/m020-p04-*.sh`, are executable, and exit 0 against the on-main `compute-staleness.sh` + `status.sh` after T01 + T02 land.
- Each verifier exercises exactly the Truth it is named for (1:1 mapping between verifier filename and phase-plan Truth).
- Each verifier uses tempdir + trap-EXIT-rm-rf isolation; the live `knowledge/**` and `.orchestrator/execution-log.jsonl` are never touched.
- Each verifier's directly-invoked Bash tool-call shape is a single-script-file invocation (AD-19); internals may use heredocs / awk / case-globs.
- Bash 3.2 safe throughout (no `declare -A`, no `mapfile`, no `<<<`-into-`$()`).
- Each verifier emits exactly one trailing `PASS:` line on success and at least one `FAIL:` line on failure.

## Verification

```
bash scripts/verify/m020-p04-compute-staleness-review-queue.sh
bash scripts/verify/m020-p04-compute-staleness-stale-flag.sh
bash scripts/verify/m020-p04-status-review-queue-section.sh
bash scripts/verify/m020-p04-status-stale-marker.sh
bash scripts/verify/m020-p04-status-review-queue-readonly.sh
bash scripts/verify/m020-p04-status-prefix-preserved.sh
```

All six must print a `PASS:` line and exit 0.

## Inputs

### From Previous Tasks

- `scripts/knowledge/compute-staleness.sh` (M020/P04/T01)
  - Key API: `--review-queue [--knowledge-root <path>]` — see T01 task plan for the full stdout contract. T03 invokes it directly.
- `scripts/orchestrator/status.sh` (M020/P04/T02)
  - Key API: invoked as `bash status.sh --root <fixture-orch>`; emits `MILESTONE:` / `STATE:` / `PHASE:` lines followed by the `Review Queue:` section.

### From Disk (Pre-existing)

- `scripts/knowledge/lib/cluster.sh` (M020/P05) — used indirectly by the helpers under test. T03 verifies the integration via fixture invocations of compute-staleness.sh + status.sh; T03 does not call cluster.sh directly.
- `scripts/knowledge/lib/jaccard.sh` (M020/P01 + extended P05) — used indirectly. The fixture entries' bodies use distinct vocabularies (per P05/T04 carry-forward "distinct-vocabulary fixture pattern") to ensure deterministic 2-entry clustering at the 0.7 default threshold.
- `tests/test-graduate-workflow.sh` (M020/P03/T04) — reference example for tempdir + fm_get awk patterns. T03 does not source this file but mirrors its conventions.

## Constraints

- **AD-19 / MEM001**: every Truth Check in the phase plan is a single-script-file invocation. Each T03 verifier itself is invoked as `bash scripts/verify/<name>.sh`; verifier internals may use heredocs / pipes / awk / case-glob freely (P03/T04 carry-forward — harness shape-guard inspects only directly-invoked Bash tool-call shapes).
- **Bash 3.2**: every verifier is `set -u` (NOT `set -e`); uses `case "$x" in glob) ...` for pattern-matching; uses `printf '%s\n' "$x" | awk ...` rather than `<<<`-here-strings.
- **CON-1 / FR-8 (read-only-during-dispatch)**: every verifier creates `tmpdir="$(mktemp -d)"` and `trap 'rm -rf "$tmpdir"' EXIT`. The live `knowledge/**` tree and the live `.orchestrator/execution-log.jsonl` are never touched; verifier `cd`s into the tmpdir before invoking status.sh so any "default knowledge root" resolution lands inside the tmpdir.
- **CON-4 (Surgical Precision)**: T03 creates only NEW files under `scripts/verify/`. No modifications to any pre-existing script.
- **Principle XIV (No Speculative Complexity)**: each verifier exercises ONE truth. No cross-truth assertions; no setup-once-test-many shortcuts (each verifier owns its tempdir, its fixture, and its assertions).
- **Distinct-vocabulary fixture pattern** (P05/T04 carry-forward): when the fixture relies on candidates clustering or NOT clustering, body content must use disjoint vocabularies for "distinct" entries and overlapping vocabularies for "should-cluster" entries. The 0.7 default threshold is sensitive to scaffolding noise (`distinct`, `fixture`, `body`, `unique`, `for` co-cluster spuriously). T03's verifiers use entry-specific tokens (`alpha alpha alpha`, `beta beta beta`, etc.).
- **`grep -c` safe-counter** (P03/T03 carry-forward): T03 verifiers use `grep -qE` for boolean assertions rather than `grep -c` (which has the rc=1+prints-0 footgun documented in MEM028 / P03 lessons).

## Expected Output

After this task:

1. Six verifier scripts under `scripts/verify/m020-p04-*.sh`, each executable, each <=200 lines.
2. Each verifier exits 0 and emits a `PASS:` line against the on-main compute-staleness.sh + status.sh after T01 + T02 land.
3. No file under `knowledge/**` or `.orchestrator/execution-log.jsonl` is touched by running any verifier.
4. The phase-level rollup `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M020/phases/P04` consumes these verifiers via the `Check:` lines in `P04-PLAN.md` and exits 0.

**Done when**: all six `bash scripts/verify/m020-p04-*.sh` invocations exit 0 with a `PASS:` line and `git status knowledge/` reflects no T03-attributable diff.

## State Context

- **Current State**: executing
- **Milestone**: M020
- **Phase**: P04
- **Task**: T03-truth-verifiers
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **AD-19 / MEM001**: every Truth Check in the phase plan is a single-script-file invocation. Each T03 verifier itself is invoked as `bash scripts/verify/<name>.sh`; verifier internals may use heredocs / pipes / awk / case-glob freely (P03/T04 carry-forward — harness shape-guard inspects only directly-invoked Bash tool-call shapes).
- **Bash 3.2**: every verifier is `set -u` (NOT `set -e`); uses `case "$x" in glob) ...` for pattern-matching; uses `printf '%s\n' "$x" | awk ...` rather than `<<<`-here-strings.
- **CON-1 / FR-8 (read-only-during-dispatch)**: every verifier creates `tmpdir="$(mktemp -d)"` and `trap 'rm -rf "$tmpdir"' EXIT`. The live `knowledge/**` tree and the live `.orchestrator/execution-log.jsonl` are never touched; verifier `cd`s into the tmpdir before invoking status.sh so any "default knowledge root" resolution lands inside the tmpdir.
- **CON-4 (Surgical Precision)**: T03 creates only NEW files under `scripts/verify/`. No modifications to any pre-existing script.
- **Principle XIV (No Speculative Complexity)**: each verifier exercises ONE truth. No cross-truth assertions; no setup-once-test-many shortcuts (each verifier owns its tempdir, its fixture, and its assertions).
- **Distinct-vocabulary fixture pattern** (P05/T04 carry-forward): when the fixture relies on candidates clustering or NOT clustering, body content must use disjoint vocabularies for "distinct" entries and overlapping vocabularies for "should-cluster" entries. The 0.7 default threshold is sensitive to scaffolding noise (`distinct`, `fixture`, `body`, `unique`, `for` co-cluster spuriously). T03's verifiers use entry-specific tokens (`alpha alpha alpha`, `beta beta beta`, etc.).
- **`grep -c` safe-counter** (P03/T03 carry-forward): T03 verifiers use `grep -qE` for boolean assertions rather than `grep -c` (which has the rc=1+prints-0 footgun documented in MEM028 / P03 lessons).

### Acceptance Criteria

- All six verifier scripts exist under `scripts/verify/m020-p04-*.sh`, are executable, and exit 0 against the on-main `compute-staleness.sh` + `status.sh` after T01 + T02 land.
- Each verifier exercises exactly the Truth it is named for (1:1 mapping between verifier filename and phase-plan Truth).
- Each verifier uses tempdir + trap-EXIT-rm-rf isolation; the live `knowledge/**` and `.orchestrator/execution-log.jsonl` are never touched.
- Each verifier's directly-invoked Bash tool-call shape is a single-script-file invocation (AD-19); internals may use heredocs / awk / case-globs.
- Bash 3.2 safe throughout (no `declare -A`, no `mapfile`, no `<<<`-into-`$()`).
- Each verifier emits exactly one trailing `PASS:` line on success and at least one `FAIL:` line on failure.

### Files To Touch

- `scripts/knowledge/compute-staleness.sh` (modify — additive `--review-queue` mode; preserve legacy staleness-report invocation byte-equivalent per CON-4)
- `scripts/orchestrator/status.sh` (modify — append Review-Queue section after existing per-milestone enumeration; preserve `MILESTONE:` / `STATE:` / `PHASE:` line shapes byte-equivalent per CON-4)
- `tests/test-status-review-queue.sh` (create)
- `scripts/verify/m020-p04-compute-staleness-review-queue.sh` (create)
- `scripts/verify/m020-p04-compute-staleness-stale-flag.sh` (create)
- `scripts/verify/m020-p04-status-review-queue-section.sh` (create)
- `scripts/verify/m020-p04-status-stale-marker.sh` (create)
- `scripts/verify/m020-p04-status-review-queue-readonly.sh` (create)
- `scripts/verify/m020-p04-status-prefix-preserved.sh` (create)

No files under `knowledge/**` are touched by P04 task code (only by transient verifier and test tempdirs). No files under `.orchestrator/memory/`, [`.orchestrator/DECISIONS.md`](../../../../../decisions.md), or any pre-existing knowledge convention/pattern/lesson are modified — P04 is a pure read-side surface lift over the schema P01 + P03 already authorized; no schema evolution.

JSONL emission is intentionally NOT in P04's scope. Status.sh and compute-staleness.sh `--review-queue` are read-only by FR-8 / CON-1. M019 Tier 2+3 (downstream) consumes the existing P03 `knowledge_graduate` / `knowledge_archive` records for review-queue throughput metrics — no new event types are added in P04.

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