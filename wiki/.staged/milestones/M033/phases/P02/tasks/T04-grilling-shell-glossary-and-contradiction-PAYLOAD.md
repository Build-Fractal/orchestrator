---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T04-grilling-shell-glossary-and-contradiction (Phase P02, Milestone M033)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~500 | required |
| Upstream Context | 981-1056 | ~3000 | required |
| Task Plan | 1058-1418 | ~5300 | required |
| State Context | 1420-1426 | ~100 | required |
| First-Turn Completeness | 1428-1477 | ~900 | required |
| **Total** | | **~20600** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 788
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
hit_count: 788
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
hit_count: 788
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
hit_count: 788
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
hit_count: 687
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
hit_count: 687
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
hit_count: 687
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
hit_count: 788
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
hit_count: 687
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
hit_count: 687
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
hit_count: 687
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
hit_count: 788
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
hit_count: 788
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
hit_count: 788
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
hit_count: 687
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
hit_count: 687
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
hit_count: 687
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
hit_count: 788
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
hit_count: 687
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
hit_count: 687
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
hit_count: 788
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
hit_count: 788
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
hit_count: 687
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
hit_count: 687
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
hit_count: 687
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
hit_count: 342
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
hit_count: 342
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
hit_count: 342
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
hit_count: 364
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
hit_count: 364
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
hit_count: 354
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
     Namespacing: `m033-p02-*` prefix avoids collision with M030/M031/[M032](../../../../../milestones/M032/index.md)
     and with M033/P01's `m033-p01-*` namespace.

     Per the P01 plan-shape finding (P01-SUMMARY.md "Plan-shape finding"):
     artifact-list bullets in `## Must-Haves` MUST NOT use the bare-backtick
     shape — the auto-loop --step=V parser eval's bare-backtick bullets as
     commands. Each Truths bullet is labeled as a sentence with backticks
     embedded; each Artifacts bullet uses the `path (constraints) — create`
     shape. Verification commands use fenced bash blocks. -->

### Truths

- `scripts/lifecycle/grilling-shell.sh` exists and is sourceable by other bash scripts. It exposes a single uniform public function `ask_one <question> <recommendation> [<context-file>]` per FR-17. The function presents one question at a time (sequential never batched per CON-5), names the recommendation first (recommendation-not-interrogation framing per the brief's Adopted External Pattern rule 4), accepts `Y/y/<enter>` as a one-keystroke recommendation accept, accepts `n/N` to request an alternative answer (read via `read -r`), and accepts any other input as an explicit operator-supplied answer. The resolved answer is echoed to stdout on a single line prefixed `answer:` (the load-bearing token for downstream tests). The module MUST run on bash 3.2 (MEM001 — no `declare -A`, no process substitution, no `$(...)` containing pipes). The module MUST NOT batch questions — calling commands invoking `ask_one` in a loop without awaiting answers is a CON-5 violation.
  - Check: `bash tools/verify/m033-p02-grilling-shell-shape.sh`

<dispatch-volatile>

## Upstream Context


### P01 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M033"
milestone: "M033"
provides:
  - "PBJ acceptance fixture; SC-4 ground-truth README oracle; two T01 verifiers (shape + oracle),references/branch-detection.md SSOT for FR-2 branch-detection rules; tools/verify/m033-p01-branch-detection-ssot-parity.sh cross-parity verifier,commands/start.md (orchestrator:start command doc) + scripts/lifecycle/start.sh (FR-1 flag set + FR-2 ordered branch detection + idempotent init invocation + four sub-flow stubs + US-1 AS-5 + MIT-006/RISK-006 disambiguation question) + 5 T03 verifiers,friendly-tester pass protocol + report template + validate-report.sh SC-15 mechanical gate + pass/fail report fixtures + 4 shape verifiers under tools/verify/m033-p01-*,SC-1 + SC-8 acceptance scripts; m033-p01-phase-suite aggregator (14 verifiers); m033-p01-scope-guard (P02-P05 boundary invariant)"
requires:
  - "none"
affects:
  - "P02,P03,P04"
key_files:
  - "tests/fixtures/m033-pbj-materials-fixture/PRODUCT-BRIEF.md;tests/fixtures/m033-pbj-materials-fixture/MVP-PLAN.md;tests/fixtures/m033-pbj-materials-fixture/DECISIONS.md;tests/fixtures/m033-pbj-materials-fixture/MILESTONE-AUDIT.md;tests/fixtures/m033-pbj-materials-fixture/README.md;tools/verify/m033-p01-pbj-fixture-shape.sh;tools/verify/m033-p01-pbj-fixture-readme-oracle.sh,references/branch-detection.md;tools/verify/m033-p01-branch-detection-ssot-parity.sh,commands/start.md,scripts/lifecycle/start.sh,tools/verify/m033-p01-start-md-shape.sh,tools/verify/m033-p01-start-sh-flags-and-init-invocation.sh,tools/verify/m033-p01-branch-detection-rules.sh,tools/verify/m033-p01-subflow-stubs-shape.sh,tools/verify/m033-p01-disambiguation-question-shape.sh,tests/m033-acceptance/friendly-tester-pass/protocol.md,tests/m033-acceptance/friendly-tester-pass/report-template.md,tests/m033-acceptance/friendly-tester-pass/validate-report.sh,tests/m033-acceptance/friendly-tester-pass/fixtures/report-pass.md,tests/m033-acceptance/friendly-tester-pass/fixtures/report-fail.md,tools/verify/m033-p01-friendly-tester-protocol-shape.sh,tools/verify/m033-p01-report-template-shape.sh,tools/verify/m033-p01-validate-report-sh-contract.sh,tools/verify/m033-p01-validate-report-fixtures-shape.sh,tests/m033-acceptance/p01-start-branch-routing.sh;tests/m033-acceptance/p07-friendly-tester-protocol.sh;tools/verify/m033-p01-acceptance-shape-sc1.sh;tools/verify/m033-p01-acceptance-shape-sc8.sh;tools/verify/m033-p01-phase-suite.sh;tools/verify/m033-p01-scope-guard.sh;scripts/lifecycle/start.sh"
key_decisions:
  - "branch-detection patterns byte-match SSOT via grep -F parity; sub-flow stubs deliberately vacuous (printf would-execute only); disambiguation prompt inline via read -r (grilling-shell.sh is P02); --branch override is silent unless detection differs (then branch-override: stderr diagnostic),D-T05-01:fix-start.sh-subshell-state-leak-via-tempfile;D-T05-02:scope-guard-wiki-rule-narrowed-to-M033-tagged-paths"
patterns_established:
  - "deterministic curatorial fixture with README oracle; oracle parser uses markdown numbered-list shape (lines 1.-5.) + closed CON-4 enum tokens,SSOT-with-byte-matched-implementation parity pattern (grep -F fixed-string cross-check between reference doc and implementing script); fenced-rule-block convention (branch-detection-rule-N markers); SKIP-gate pattern for verifiers co-authored before their implementation lands,SSOT-and-impl byte-match via grep -F parity verifier (T02 ssot-parity verifier transitions skip=1 to skip=0 on T03 land); vacuous-stub pattern for cross-phase scope-guarding (P01 stubs print would-execute: only,P02-P05 replace with real logic); load-bearing token tripwire convention (init already complete,branch:,would-execute:,disambiguation:,recommended:,MIT-006,branch-override: are all literal-grep tokens for downstream SC verification),frontmatter-only attestation counting (awk in_fm guard); per-report shape verifier separate from milestone-close escalation gate; em-dash literal in US-8 AS-5 diagnostic,phase-suite-aggregator-emits-canonical-SUMMARY-line;side-channel-tempfile-for-subshell-globals;wrapper-verifier-executes-target-and-propagates-exit-code"
drill_down_paths:
  - "[.orchestrator/milestones/M033/phases/P01/tasks/T01-pbj-fixture-and-oracle-SUMMARY.md](../../../../../milestones/M033/phases/P01/tasks/T01-pbj-fixture-and-oracle-SUMMARY.md), [.orchestrator/milestones/M033/phases/P01/tasks/T02-branch-detection-ssot-SUMMARY.md](../../../../../milestones/M033/phases/P01/tasks/T02-branch-detection-ssot-SUMMARY.md), [.orchestrator/milestones/M033/phases/P01/tasks/T03-start-command-and-driver-SUMMARY.md](../../../../../milestones/M033/phases/P01/tasks/T03-start-command-and-driver-SUMMARY.md), [.orchestrator/milestones/M033/phases/P01/tasks/T04-friendly-tester-pass-artifacts-SUMMARY.md](../../../../../milestones/M033/phases/P01/tasks/T04-friendly-tester-pass-artifacts-SUMMARY.md), [.orchestrator/milestones/M033/phases/P01/tasks/T05-acceptance-suite-and-phase-suite-SUMMARY.md](../../../../../milestones/M033/phases/P01/tasks/T05-acceptance-suite-and-phase-suite-SUMMARY.md)"
duration: "173m"
verification_result: "pass"
completed_at: "2026-05-04T03:16:34Z"
observability_surfaces:
  - "none"
---

P01 ships the foundational scaffolding for M033 (Project Onboarding Experience): the `orchestrator:start` command and driver, the four sub-flow stubs that P02–P05 will replace, the SSOT for branch detection, the friendly-tester pass artifact set, and the acceptance + verification scaffolding that future phases depend on.

## What was built

- **PBJ acceptance fixture + SC-4 ground-truth oracle** (T01): `tests/fixtures/m033-pbj-materials-fixture/` with four PBJ-shape documents (`PRODUCT-BRIEF.md`, `MVP-PLAN.md`, `DECISIONS.md`, `MILESTONE-AUDIT.md`) carrying exactly 5 inconsistencies covering all three CON-4 categories (`id-misalignment`, `scheme-contradiction`, `orphan-reference`), plus a `README.md` oracle that enumerates the 5 expected detections in the parser-load-bearing markdown numbered-list shape. Two verifiers under `tools/verify/m033-p01-*` lock the fixture shape and the oracle entry layout.
- **Branch-detection SSOT** (T02): `references/branch-detection.md` documents the four FR-2 rules (greenfield-empty / greenfield-with-materials / existing-codebase / migrating) with literal pattern strings in fenced `branch-detection-rule-N` blocks. `tools/verify/m033-p01-branch-detection-ssot-parity.sh` byte-cross-checks the SSOT against `scripts/lifecycle/start.sh` via `grep -F`; the verifier emits `SKIP:` for the impl-side assertions until T03 lands and transitions to `pass=28 skip=0` once start.sh is in place.
- **`orchestrator:start` command + driver** (T03): `commands/start.md` (canonical command-doc shape per MEM012) plus `scripts/lifecycle/start.sh` implementing FR-1 flag set (`--project-dir`, `--branch`, `--init-only`, `--with-wiki`, `--with-giscus`, `--deploy`, `--debug`), FR-2 ordered branch detection, idempotent `init-project.sh` invocation, four vacuous sub-flow stubs (each printing only `would-execute: <stub-name> --project-dir <path>`), and the inline `read -r` US-1 AS-5 + MIT-006/RISK-006 disambiguation question. Five shape verifiers cover command-doc shape, flag set, branch-detection rule presence, sub-flow stub vacuity, and disambiguation token shape.
- **Friendly-tester pass artifacts** (T04): `tests/m033-acceptance/friendly-tester-pass/` carries the FR-19 protocol, report template, fixtures (`report-pass.md`, `report-fail.md`), and `validate-report.sh` (the SC-15 mechanical gate, bash 3.2 + awk only, frontmatter-scoped attestation count, `friction_blockers=N` stderr emission, and the literal `friendly-tester pass not run — milestone close blocked` em-dash diagnostic for the missing-file path). Four shape verifiers lock the protocol, template, validator contract, and fixtures.
- **Acceptance suite + phase-suite + scope-guard** (T05): `tests/m033-acceptance/p01-start-branch-routing.sh` (SC-1) and `tests/m033-acceptance/p07-friendly-tester-protocol.sh` (SC-8) run the end-to-end branch-routing and friendly-tester paths against synthetic fixtures. `tools/verify/m033-p01-phase-suite.sh` aggregates 14 P01 verifiers; `tools/verify/m033-p01-scope-guard.sh` asserts no P02–P05 file leakage.

## Patterns established

- **SSOT-with-byte-matched-impl parity**: `grep -F` cross-check between a reference doc and its implementing script, with a SKIP-gate convention so the verifier ships before the impl and surfaces SKIP until impl lands.
- **Vacuous sub-flow stubs**: P01 ships stubs that print only `would-execute: <stub> --project-dir <path>`; later phases replace with real logic. Combined with the scope-guard, this prevents accidental P02–P05 scope leakage during P01.
- **Load-bearing-token tripwires**: Every cross-phase boundary is enforced via literal token grep (`init already complete`, `branch:`, `would-execute:`, `disambiguation:`, `recommended:`, `MIT-006`, `branch-override:`). Downstream SC verification consumes these as fixed strings.
- **Deterministic curatorial fixture + README oracle**: The PBJ fixture ships with no timestamps, no random tokens — byte-identical across machines. The README is the parser-load-bearing oracle (markdown numbered-list shape).
- **Frontmatter-scoped attestation counting** (validate-report.sh): awk `in_fm` guard counts `not_familiar_with_orchestrator: yes` only inside the YAML frontmatter, immune to comment/prose noise in real-world reports.

## Decisions captured during execution

- **D-T05-01**: Fixed a subshell state leak in `scripts/lifecycle/start.sh` surfaced by the SC-1 acceptance test. `detect_branch` ran in a `$(...)` subshell so its mutations to `DETECTED_FROM`/`MIT006_ELIGIBLE` never propagated. Fix: side-channel tempfile populated by `write_detect_state` inside `detect_branch`, reloaded by `load_detect_state` in parent after each invocation; cleanup via `trap ... EXIT`. Strictly T03 territory but blocked P01 close — surgical fix.
- **D-T05-02**: Narrowed the scope-guard's `wiki/` rule to M033-tagged paths. The literal "wiki/ exists → fail" form would unconditionally fail because `wiki/` is a pre-existing [M012](../../../../../milestones/M012/index.md) artifact. Narrowed to: scan `wiki/` for basenames matching `M033*`/`m033*`. Preserves SC-13 intent without flagging unrelated history.

## Plan-shape finding (orchestrator-internal)

The five P01 task plans initially carried bare-backtick artifact bullets in `## Must-Haves` (e.g. `- \`tests/fixtures/.../README.md\``). The auto-loop `--step=V` parser eval's every bare-backtick bullet in Must-Haves as a command, which fails for non-executable artifact paths (especially brace-expansion forms like `{a,b,c}.md`). All five plans were edited mid-phase to label artifact bullets with prefixes (e.g. `- Fixture documents: \`...\`, \`...\``), breaking the strict `^- \`...\`$` regex match. Future planner agents should follow this convention by default — candidate for a `templates/task-plan.md` Must-Haves shape clarification.

## Verification result

- `tools/verify/m033-p01-phase-suite.sh`: `pass=14 fail=0`
- `tools/verify/m033-p01-scope-guard.sh`: `pass=14 fail=0`
- All 5 task-level verify cycles: `AUTO:VERIFY_PASS`
- Acceptance scripts: `p01-start-branch-routing.sh` `pass=14 fail=0`; `p07-friendly-tester-protocol.sh` `pass=10 fail=0`
- External-modification check: `PASS: no external modifications`
- Roadmap sync: `SYNC:OK`

## What downstream phases consume

- P02 (existing-codebase deep-discovery sub-flow): consumes `commands/start.md`, `scripts/lifecycle/start.sh`, the `existing-codebase` sub-flow stub slot, the disambiguation question contract, the SSOT branch-detection rules, and the SC-1 acceptance script as its regression boundary.
- P03 (greenfield-empty + greenfield-with-materials sub-flows): consumes the same start.sh + sub-flow stub slots, plus the PBJ fixture (T01) for the materials-detection branch.
- P04 (PBJ inconsistency detector): consumes the PBJ fixture + README oracle (T01) as its development target and SC-4 ground truth.
- P05 (M032 paired-launch integration): consumes the `--with-wiki`/`--with-giscus`/`--deploy` flag set already wired through start.sh, plus the friendly-tester pass artifacts (T04) as the gate before milestone close.

The friendly-tester pass artifacts (T04) ship in P01 deliberately — the spec's SC-14 amendment treats `p07-` as a concern-tag, not a phase-tag, so FR-19 protocol + report template + validator must exist in P01 to unblock recruiting in parallel with P02–P05 execution.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P02"
milestone: "M033"
name: "Grilling-shell glossary inline-update writer + MIT-007 contradiction-detection wiring + SC-11 acceptance (FR-17 / FR-18 / MIT-007)"
depends_on: ["T03"]
---

## Prerequisites

- T03 complete: `scripts/lifecycle/grilling-shell.sh` exists with the core `ask_one` API, recommendation-not-interrogation framing, and reserved fenced SSOT block markers (`# >>> contradiction-pairs >>>`, `# >>> glossary-triggers >>>`) plus stub helper functions (`_grilling_check_contradiction`, `_grilling_glossary_update`). Verified by `[ -f scripts/lifecycle/grilling-shell.sh ]` AND `grep -q 'contradiction-pairs' scripts/lifecycle/grilling-shell.sh`.
- `tools/verify/m033-p02-grilling-shell-shape.sh` exists and exits 0 (T03 verifier — T04 must not break it).
- `tests/m033-acceptance/` exists.
- Spec context: FR-18 codifies the inline glossary writer at `<PROJECT_DIR>/wiki/glossary.md` (alphabetized-insert; immediate-not-batched). MIT-007 codifies the live contradiction-detection wiring active whenever `[<context-file>]` is non-empty. SC-11 is the acceptance test exercising both surfaces.

## Description

T04 layers the load-bearing logic onto T03's core grilling-shell module:

1. **MIT-007 contradiction-detection wiring** — replaces T03's `_grilling_check_contradiction` no-op stub with the real implementation. When `ask_one` is invoked with a non-empty `[<context-file>]` argument pointing at a YAML accumulator (e.g., `partial-answers.yml`), the function scans the file for contradictions against the new resolved answer BEFORE returning success. A contradiction is defined by the closed `# >>> contradiction-pairs >>>` table populated in T04. On contradiction detection, the function emits `contradiction:` to stdout naming the conflicting prior answer + the new answer, then re-prompts the operator to reconcile (re-prompt for a new answer, or accept-with-attestation via `! <reason>` shorthand).

2. **FR-18 glossary inline-update writer** — replaces T03's `_grilling_glossary_update` no-op stub with the real implementation. When a question whose key matches the closed `# >>> glossary-triggers >>>` set resolves, the function writes `<term>: <one-line definition>` (with at most a two-line elaboration on continuation lines) to `<PROJECT_DIR>/wiki/glossary.md` immediately. The write is alphabetized-insert (preserves existing entries; never full-file rewrite) and idempotent on identical input (re-writing the same term with the same definition produces no diff).

3. **SC-11 acceptance script** — `tests/m033-acceptance/p07-grilling-shell.sh` exercises the full surface end-to-end against synthetic `mktemp -d` staging.

**Bash 3.2 compatibility (MEM001):** No `declare -A`, no process substitution. Glossary alphabetized-insert uses `awk` (single-pass, no associative arrays). YAML parsing for contradiction detection uses `grep`/`sed` (no jq dependency).

**Closed enums for contradiction-pairs and glossary-triggers.** Both tables are documented inline in the module under fenced SSOT blocks (T04 populates the blocks T03 left empty). The vocabularies are intentionally minimal at v1 (per Constitution-XIV no speculative complexity):

- **`contradiction-pairs`** (v1): a small set of mutually-exclusive value pairs keyed by question-key. Examples documented inline:
  - `target-user`: `consumer` ⟂ `enterprise` ⟂ `internal-tools-only`
  - `deployment-target`: `serverless` ⟂ `self-hosted-vm` ⟂ `kubernetes`
  - `auth-model`: `passwordless` ⟂ `password-required` ⟂ `sso-only`

  v1 ships ~3–5 pairs; future demand-driven expansion adds more. The verifier asserts at least 3 pairs are documented and the parsing logic uses the documented format.

- **`glossary-triggers`** (v1): a small set of question-keys that, when answered, trigger a glossary-entry write. Examples:
  - `domain-term-defined` (any answer)
  - `acronym-resolved` (any answer)
  - `convention-named` (any answer)
  - `framework-chosen` (any answer matching a known framework token)

  v1 ships ~4 triggers; the verifier asserts at least 3 are documented.

## Steps

1. **Populate `# >>> contradiction-pairs >>>` SSOT block** in `scripts/lifecycle/grilling-shell.sh`. Format: bash array of `<question-key>:<value-a>:<value-b>` triples, parseable by `awk -F:`. Example:

   ```bash
   # >>> contradiction-pairs >>>
   # Format: question-key:value-a:value-b — answers a and b are mutually
   # exclusive when both appear under the same question-key in the
   # accumulator. v1 ships the minimal set; expand demand-driven.
   _GRILLING_CONTRADICTION_PAIRS="target-user:consumer:enterprise
   target-user:consumer:internal-tools-only
   target-user:enterprise:internal-tools-only
   deployment-target:serverless:self-hosted-vm
   deployment-target:serverless:kubernetes
   deployment-target:self-hosted-vm:kubernetes
   auth-model:passwordless:password-required
   auth-model:passwordless:sso-only
   auth-model:password-required:sso-only"
   # <<< contradiction-pairs <<<
   ```

   The variable is global (module-level); the parsing function reads it line-by-line via `IFS=$'\n'`.

2. **Populate `# >>> glossary-triggers >>>` SSOT block** in `scripts/lifecycle/grilling-shell.sh`. Format: bash array of question-keys, one per line:

   ```bash
   # >>> glossary-triggers >>>
   # Question-keys that, when answered via ask_one, trigger an
   # immediate write to <PROJECT_DIR>/wiki/glossary.md per FR-18.
   # v1 ships the minimal set; expand demand-driven.
   _GRILLING_GLOSSARY_TRIGGERS="domain-term-defined
   acronym-resolved
   convention-named
   framework-chosen"
   # <<< glossary-triggers <<<
   ```

3. **Replace `_grilling_check_contradiction` stub body** with real implementation:

   ```bash
   _grilling_check_contradiction() {
     local resolved="$1"
     local context_file="$2"

     # No context file → no contradiction check (still a valid call shape)
     if [ -z "$context_file" ] || [ ! -f "$context_file" ]; then
       return 0
     fi

     # Determine the question-key for this resolved answer. Calling
     # commands set _GRILLING_CURRENT_QKEY before invoking ask_one
     # (e.g., _GRILLING_CURRENT_QKEY=target-user; ask_one ...).
     local qkey="${_GRILLING_CURRENT_QKEY:-}"
     if [ -z "$qkey" ]; then
       # No question-key context → cannot check contradictions
       return 0
     fi

     # Scan the accumulator file for prior answers under this qkey
     local prior_answer=""
     prior_answer="$(grep "^${qkey}:" "$context_file" 2>/dev/null | tail -1 | sed -E 's/^[^:]+:[[:space:]]*//')"
     if [ -z "$prior_answer" ]; then
       return 0
     fi

     # Check if (qkey, prior_answer, resolved) matches a contradiction pair
     local found_contradiction=0
     local IFSO="$IFS"
     IFS=$'\n'
     local pair
     for pair in $_GRILLING_CONTRADICTION_PAIRS; do
       local pkey pa pb
       pkey="$(echo "$pair" | cut -d: -f1)"
       pa="$(echo "$pair" | cut -d: -f2)"
       pb="$(echo "$pair" | cut -d: -f3)"
       if [ "$pkey" = "$qkey" ]; then
         if { [ "$pa" = "$prior_answer" ] && [ "$pb" = "$resolved" ]; } || \
            { [ "$pb" = "$prior_answer" ] && [ "$pa" = "$resolved" ]; }; then
           found_contradiction=1
           break
         fi
       fi
     done
     IFS="$IFSO"

     if [ "$found_contradiction" -eq 1 ]; then
       printf 'contradiction: %s prior=%s new=%s\n' "$qkey" "$prior_answer" "$resolved"
       printf 'reconcile [r=re-prompt, !<reason>=accept-with-attestation]: ' >&2
       local reconcile=""
       IFS= read -r reconcile || reconcile="r"
       case "$reconcile" in
         r|R|"") return 2 ;;  # Caller re-prompts
         "!"*) printf 'attestation: %s\n' "${reconcile#!}"; return 0 ;;
         *) printf 'unrecognized reconciliation: %s — re-prompt\n' "$reconcile" >&2; return 2 ;;
       esac
     fi
     return 0
   }
   ```

4. **Replace `_grilling_glossary_update` stub body** with real implementation:

   ```bash
   _grilling_glossary_update() {
     local question="$1"
     local resolved="$2"

     # Question-key extraction: calling commands set _GRILLING_CURRENT_QKEY
     local qkey="${_GRILLING_CURRENT_QKEY:-}"
     if [ -z "$qkey" ]; then
       return 0
     fi

     # Check if this qkey is a glossary trigger
     local triggered=0
     local IFSO="$IFS"
     IFS=$'\n'
     local trigger
     for trigger in $_GRILLING_GLOSSARY_TRIGGERS; do
       if [ "$trigger" = "$qkey" ]; then
         triggered=1
         break
       fi
     done
     IFS="$IFSO"

     if [ "$triggered" -eq 0 ]; then
       return 0
     fi

     # Determine the project dir (caller sets PROJECT_DIR; fall back to PWD)
     local project_dir="${PROJECT_DIR:-$PWD}"
     local glossary_dir="$project_dir/wiki"
     local glossary_path="$glossary_dir/glossary.md"
     mkdir -p "$glossary_dir"

     # Term: derived from the qkey (e.g., 'framework-chosen' → resolved is
     # the framework name; the term is the resolved value itself).
     # Definition: the calling command sets _GRILLING_CURRENT_DEFINITION
     # if it has a definition to attach; otherwise we use the question text
     # as the definition.
     local term="$resolved"
     local definition="${_GRILLING_CURRENT_DEFINITION:-$question}"

     # Idempotent check: if the entry already exists with this exact
     # term + definition, no-op.
     if [ -f "$glossary_path" ]; then
       if grep -qF "${term}: ${definition}" "$glossary_path"; then
         return 0
       fi
     fi

     # Alphabetized-insert via awk single-pass
     local tmp
     tmp="$(mktemp)"
     awk -v term="$term" -v def="$definition" '
       BEGIN { inserted=0 }
       /^[^:]+: / && !inserted {
         # Extract the existing term (everything up to first ":")
         existing_term = $0
         sub(/:.*$/, "", existing_term)
         if (term < existing_term) {
           printf "%s: %s\n", term, def
           inserted=1
         }
       }
       { print }
       END {
         if (!inserted) {
           printf "%s: %s\n", term, def
         }
       }
     ' "$glossary_path" 2>/dev/null > "$tmp" || {
       # File might not exist yet; create with single entry
       printf '%s: %s\n' "$term" "$definition" > "$tmp"
     }
     mv "$tmp" "$glossary_path"
     return 0
   }
   ```

5. **Update the `ask_one` body in T03's module** to:
   - Set `_GRILLING_CURRENT_QKEY` from a documented optional 4th argument (or from the existing-caller-set var). Recommendation: keep the public API at 3 args (`question`, `recommendation`, `[<context-file>]`); calling commands set `_GRILLING_CURRENT_QKEY` directly before invoking `ask_one`. This keeps the FR-17 API signature stable.
   - On `_grilling_check_contradiction` returning non-zero (contradiction with re-prompt requested), re-prompt the operator for an alternative answer and re-run the check (single retry; second contradiction exits non-zero with a `contradiction-unresolved:` diagnostic).
   - Append the resolved answer to the `<context-file>` (if non-empty) AFTER passing contradiction detection, so subsequent `ask_one` invocations under the same accumulator see this answer. Format: `<qkey>: <resolved>` per line.

6. **Author `tests/m033-acceptance/p07-grilling-shell.sh`** (≥100 lines, executable, exits 0 → SC-11).

   6a. **Setup.** `mktemp -d` for staging; trap EXIT for cleanup.

   6b. **Test 1 — recommendation-not-interrogation ordering.** Source the module, set `PROJECT_DIR=<staging>`, invoke `_GRILLING_CURRENT_QKEY=stack ask_one 'What stack?' 'web-saas' ''` against simulated stdin (`printf 'y\n'`). Capture stdout. Assert: `recommendation: web-saas` line appears AND `answer: web-saas` line appears AND `recommendation:` precedes `answer:` (line-number comparison).

   6c. **Test 2 — explicit answer (n/N path).** Invoke same `ask_one 'What stack?' 'web-saas' ''` with stdin `printf 'n\nfastify\n'`. Assert `answer: fastify` appears.

   6d. **Test 3 — contradiction detection fires (MIT-007).** Pre-populate `<staging>/partial-answers.yml` with `target-user: consumer`. Set `_GRILLING_CURRENT_QKEY=target-user`. Invoke `ask_one 'Refine target user?' 'enterprise' '<staging>/partial-answers.yml'` with stdin `printf 'y\nr\n'` (accept the recommendation, then choose re-prompt on contradiction). Then a second `read` for the alternative... actually the contradiction handler re-prompts via stderr; simpler test: stdin `printf 'y\n!still-the-right-call\n'` (accept recommendation, then attestation reconciliation). Assert: `contradiction: target-user prior=consumer new=enterprise` appears on stdout BEFORE `answer: enterprise` appears, AND `attestation: still-the-right-call` appears.

   6e. **Test 4 — glossary trigger writes alphabetized.** Pre-populate `<staging>/wiki/glossary.md` with two entries:

   ```
   alpha: first entry
   gamma: third entry
   ```

   Set `_GRILLING_CURRENT_QKEY=framework-chosen` (a documented trigger). Invoke `ask_one 'Which framework?' 'beta' ''` with stdin `printf 'y\n'`. Assert `<staging>/wiki/glossary.md` now contains:

   ```
   alpha: first entry
   beta: ...
   gamma: third entry
   ```

   (with `beta:` inserted alphabetically between `alpha:` and `gamma:`).

   6f. **Test 5 — glossary idempotent on identical input.** Re-run the same trigger with the same answer; assert the glossary file is unchanged (byte-identical via `cmp` against the saved version after Test 4).

   6g. **Test 6 — non-trigger qkey produces no glossary entry.** Set `_GRILLING_CURRENT_QKEY=stack` (NOT a trigger). Invoke `ask_one 'What stack?' 'web-saas' ''` with `printf 'y\n'`. Assert `<staging>/wiki/glossary.md` is unchanged from Test 5 baseline.

   6h. **Cleanup mandatory.** `rm -rf "$staging"` in EXIT trap.

7. **Author `tools/verify/m033-p02-grilling-shell-contradiction-detection.sh`** (≥30 lines, executable). Asserts:
   - `scripts/lifecycle/grilling-shell.sh` exists.
   - The `# >>> contradiction-pairs >>>` block is populated (at least 3 lines between the markers, each matching `<key>:<a>:<b>` shape).
   - Required tokens appear: `MIT-007`, `contradiction:`, `_grilling_check_contradiction`, `context_file`, `_GRILLING_CURRENT_QKEY`.
   - The MIT-007 wiring path is non-trivial: `_grilling_check_contradiction` is no longer a no-op (assert the function body has more than 5 lines via `awk`/grep on the function definition).
   - **Functional smoke test:** sandboxed source + invoke with a contradicting accumulator; assert `contradiction:` appears on stdout.
   - Emits PASS/SUMMARY lines.

8. **Author `tools/verify/m033-p02-glossary-writer-shape.sh`** (≥30 lines, executable). Asserts:
   - The `# >>> glossary-triggers >>>` block is populated (at least 3 trigger keys).
   - Required tokens appear: `FR-18`, `glossary.md`, `wiki/`, `_grilling_glossary_update`, `alphabetized-insert` or `awk` (insert mechanism).
   - The `_grilling_glossary_update` body is non-trivial (>10 lines).
   - **Functional smoke test:** create staging; source the module; invoke `ask_one` with a glossary trigger; assert `<staging>/wiki/glossary.md` contains the entry. Re-invoke with the same trigger; assert idempotency (file byte-identical).
   - Emits PASS/SUMMARY lines.

9. **Author `tools/verify/m033-p02-acceptance-shape-sc11.sh`** (≥25 lines, executable). Asserts:
   - `tests/m033-acceptance/p07-grilling-shell.sh` exists and is executable.
   - The literal SC-11 + FR-17 + FR-18 tokens appear.
   - The cross-references to `grilling-shell.sh`, `recommendation:`, `answer:`, `contradiction:`, `glossary.md` appear.
   - Emits PASS/SUMMARY lines.

## Must-Haves

This task addresses these P02 phase truths:
- The MIT-007 contradiction-detection wiring is live in `scripts/lifecycle/grilling-shell.sh` whenever `[<context-file>]` is non-empty.
- The FR-18 glossary inline-update writer fires immediately (not batched) when a documented trigger qkey resolves.
- `tests/m033-acceptance/p07-grilling-shell.sh` (SC-11) exits 0 and exercises both surfaces end-to-end.

This task creates these P02 phase artifacts:
- Module extension (replaces T03 stubs in-place): `scripts/lifecycle/grilling-shell.sh` (T04 populates contradiction-pairs + glossary-triggers blocks; replaces `_grilling_check_contradiction` and `_grilling_glossary_update` stub bodies with real logic).
- Acceptance script: `tests/m033-acceptance/p07-grilling-shell.sh` (SC-11).
- Verifiers: `tools/verify/m033-p02-grilling-shell-contradiction-detection.sh`, `tools/verify/m033-p02-glossary-writer-shape.sh`, `tools/verify/m033-p02-acceptance-shape-sc11.sh`.

## Verification

```bash
bash tools/verify/m033-p02-grilling-shell-shape.sh
```

```bash
bash tools/verify/m033-p02-grilling-shell-contradiction-detection.sh
```

```bash
bash tools/verify/m033-p02-glossary-writer-shape.sh
```

```bash
bash tools/verify/m033-p02-acceptance-shape-sc11.sh
```

```bash
bash tests/m033-acceptance/p07-grilling-shell.sh
```

## Inputs

### From Previous Tasks

- T03 deliverable: `scripts/lifecycle/grilling-shell.sh` with the core `ask_one` function, the recommendation-not-interrogation framing, and the empty fenced SSOT blocks (`# >>> contradiction-pairs >>>` and `# >>> glossary-triggers >>>`) plus stub helpers `_grilling_check_contradiction` and `_grilling_glossary_update`. T04 populates the SSOT blocks and replaces the stub bodies in-place. T03's verifier (`m033-p02-grilling-shell-shape.sh`) must continue to exit 0 after T04 (P03/P04/P05 will source the same module — T03's API contract MUST remain stable).

### From Disk (Pre-existing)

- `awk` (POSIX-standard, present on macOS + Linux). Used by the alphabetized-insert in `_grilling_glossary_update`.

## Constraints

- Bash 3.2 compatibility (MEM001) — no `declare -A`, no process substitution, no `$(...)` containing pipes.
- T04 MUST preserve T03's `m033-p02-grilling-shell-shape.sh` verifier passing — T04's edits to `grilling-shell.sh` are additive (populating empty SSOT blocks) and replacement-in-place (stub body → real body); the public API surface (`ask_one` signature) is unchanged.
- The closed contradiction-pairs and glossary-triggers vocabularies are minimal at v1 (3–5 pairs, 3–4 triggers). Expansion is demand-driven via P03/P04/P05 acceptance feedback or post-launch friendly-tester signal.
- The `contradiction:` and `attestation:` line prefixes are load-bearing for SC-11 assertions. Use `printf` (not `echo -e`).
- The glossary write MUST be alphabetized-insert (preserve existing entries) and idempotent on identical input. Full-file rewrite is forbidden (operator edits between writes must survive).
- The accumulator file (`partial-answers.yml`) format is `<qkey>: <resolved>` per line. T04 appends to it; T03's `ask_one` is also extended to append. Calling commands MUST set `_GRILLING_CURRENT_QKEY` before invoking `ask_one`; documented in the SSOT comment block.
- T04 MUST NOT touch `scripts/util/jsonl-event-emitter.sh` (T01 deliverable) or `scripts/util/start-state-markers.sh` (T02 deliverable), or any P03/P04/P05 surface.
- Verifier scripts use single-script-file shape per AD-19.

## Expected Output

After T04 completes:
- `scripts/lifecycle/grilling-shell.sh` carries populated SSOT blocks + real `_grilling_check_contradiction` + real `_grilling_glossary_update`.
- `tests/m033-acceptance/p07-grilling-shell.sh` exists, is executable, exits 0.
- All three new T04 verifiers (`grilling-shell-contradiction-detection`, `glossary-writer-shape`, `acceptance-shape-sc11`) exist, are executable, exit 0.
- T03's `m033-p02-grilling-shell-shape.sh` continues to exit 0 (regression-preserved).
- A summary file at [`.orchestrator/milestones/M033/phases/P02/tasks/T04-grilling-shell-glossary-and-contradiction-SUMMARY.md`](../../../../../milestones/M033/phases/P02/tasks/T04-grilling-shell-glossary-and-contradiction-SUMMARY.md) documents the deliverables.

## Notes

The `_GRILLING_CURRENT_QKEY` and `_GRILLING_CURRENT_DEFINITION` are caller-set bash variables (not `ask_one` arguments), keeping the FR-17 public API at 3 args. P03/P04/P05 calling commands document the convention by setting them before each invocation. This is the established [M021](../../../../../milestones/M021/index.md) pattern for cross-cutting context (env-var-style variables that don't pollute the function signature).

The contradiction-detection fall-through on `_GRILLING_CURRENT_QKEY` empty is intentional: it lets ad-hoc `ask_one` invocations (operator scripts, smoke tests) skip contradiction detection without false positives. The detection only fires when the calling command opts in by setting the qkey.

The glossary write uses `awk` for the alphabetized-insert because bash 3.2 has no clean way to insert into a file at a sorted position without process substitution. `awk` is POSIX-standard; the single-pass insert preserves comments / non-entry lines transparently.

The reconciliation UX (`r` for re-prompt, `!<reason>` for accept-with-attestation) is a minimal v1 surface. If friendly-tester signal surfaces "operators get stuck on contradiction prompts", post-launch can expand to a richer dialog. The two-mode UX is adequate for the launch first-impression promise.

## State Context

- **Current State**: executing
- **Milestone**: M033
- **Phase**: P02
- **Task**: T04-grilling-shell-glossary-and-contradiction
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- Bash 3.2 compatibility (MEM001) — no `declare -A`, no process substitution, no `$(...)` containing pipes.
- T04 MUST preserve T03's `m033-p02-grilling-shell-shape.sh` verifier passing — T04's edits to `grilling-shell.sh` are additive (populating empty SSOT blocks) and replacement-in-place (stub body → real body); the public API surface (`ask_one` signature) is unchanged.
- The closed contradiction-pairs and glossary-triggers vocabularies are minimal at v1 (3–5 pairs, 3–4 triggers). Expansion is demand-driven via P03/P04/P05 acceptance feedback or post-launch friendly-tester signal.
- The `contradiction:` and `attestation:` line prefixes are load-bearing for SC-11 assertions. Use `printf` (not `echo -e`).
- The glossary write MUST be alphabetized-insert (preserve existing entries) and idempotent on identical input. Full-file rewrite is forbidden (operator edits between writes must survive).
- The accumulator file (`partial-answers.yml`) format is `<qkey>: <resolved>` per line. T04 appends to it; T03's `ask_one` is also extended to append. Calling commands MUST set `_GRILLING_CURRENT_QKEY` before invoking `ask_one`; documented in the SSOT comment block.
- T04 MUST NOT touch `scripts/util/jsonl-event-emitter.sh` (T01 deliverable) or `scripts/util/start-state-markers.sh` (T02 deliverable), or any P03/P04/P05 surface.
- Verifier scripts use single-script-file shape per AD-19.

### Acceptance Criteria

This task addresses these P02 phase truths:
- The MIT-007 contradiction-detection wiring is live in `scripts/lifecycle/grilling-shell.sh` whenever `[<context-file>]` is non-empty.
- The FR-18 glossary inline-update writer fires immediately (not batched) when a documented trigger qkey resolves.
- `tests/m033-acceptance/p07-grilling-shell.sh` (SC-11) exits 0 and exercises both surfaces end-to-end.

This task creates these P02 phase artifacts:
- Module extension (replaces T03 stubs in-place): `scripts/lifecycle/grilling-shell.sh` (T04 populates contradiction-pairs + glossary-triggers blocks; replaces `_grilling_check_contradiction` and `_grilling_glossary_update` stub bodies with real logic).
- Acceptance script: `tests/m033-acceptance/p07-grilling-shell.sh` (SC-11).
- Verifiers: `tools/verify/m033-p02-grilling-shell-contradiction-detection.sh`, `tools/verify/m033-p02-glossary-writer-shape.sh`, `tools/verify/m033-p02-acceptance-shape-sc11.sh`.

### Files To Touch

- `scripts/lifecycle/grilling-shell.sh` (create, T03 + T04)
- `scripts/util/jsonl-event-emitter.sh` (create, T01)
- `scripts/util/start-state-markers.sh` (create, T02)
- `scripts/lifecycle/start.sh` (modify in place — additive resume-extension, T02)
- `references/m033-fr21-dual-write-convention.md` (create, T05)
- `tests/m033-acceptance/p07-grilling-shell.sh` (create, T04)
- `tests/m033-acceptance/p07-resume-on-partial-state.sh` (create, T02)
- `tests/m033-acceptance/p07-observability-records.sh` (create, T05)
- `tools/verify/m033-p02-grilling-shell-shape.sh` (create, T03)
- `tools/verify/m033-p02-grilling-shell-contradiction-detection.sh` (create, T04)
- `tools/verify/m033-p02-glossary-writer-shape.sh` (create, T04)
- `tools/verify/m033-p02-jsonl-event-schema.sh` (create, T01)
- `tools/verify/m033-p02-start-state-markers-shape.sh` (create, T02)
- `tools/verify/m033-p02-start-sh-resume-extension.sh` (create, T02)
- `tools/verify/m033-p02-fr21-convention-shape.sh` (create, T05)
- `tools/verify/m033-p02-acceptance-shape-sc11.sh` (create, T04)
- `tools/verify/m033-p02-acceptance-shape-sc12.sh` (create, T02)
- `tools/verify/m033-p02-acceptance-shape-sc13.sh` (create, T05)
- `tools/verify/m033-p02-phase-suite.sh` (create, T05)
- `tools/verify/m033-p02-scope-guard.sh` (create, T05)

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