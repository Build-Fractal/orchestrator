---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T02-intensity-recommend-hook (Phase P01, Milestone M027)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~500 | required |
| Upstream Context | 981-1021 | ~2900 | required |
| Task Plan | 1023-1163 | ~3600 | required |
| State Context | 1165-1171 | ~100 | required |
| First-Turn Completeness | 1173-1216 | ~1000 | required |
| **Total** | | **~18900** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 513
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
hit_count: 513
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
hit_count: 513
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
scope_tags: "[project], [milestone:[M005](../../../../milestones/M005/index.md)]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 513
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
hit_count: 447
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
hit_count: 447
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
hit_count: 447
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
hit_count: 513
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
scope_tags: "[project], [milestone:[M006](../../../../milestones/M006/index.md)]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 447
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
hit_count: 447
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
scope_tags: "[project], [milestone:[M002](../../../../milestones/M002/index.md)]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 447
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
hit_count: 513
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
hit_count: 513
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
hit_count: 513
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
hit_count: 447
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
hit_count: 447
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
hit_count: 447
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
hit_count: 513
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
hit_count: 447
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
hit_count: 447
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
hit_count: 513
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
hit_count: 513
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
scope_tags: "[project], [milestone:[M004](../../../../milestones/M004/index.md)]"
category: lessons
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 447
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
hit_count: 447
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
hit_count: 447
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
scope_tags: "[project], [milestone:[M025](../../../../milestones/M025/index.md)]"
category: lessons
confidence: 0.95
created_at: 2026-04-23
last_verified: 2026-04-23
hit_count: 102
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
hit_count: 102
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
scope_tags: "[project], [milestone:[M014](../../../../milestones/M014/index.md)], [concern:bash-compat]"
category: lessons
confidence: 0.95
created_at: 2026-04-23
last_verified: 2026-04-23
hit_count: 102
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
scope_tags: "[project], [milestone:[M026](../../../../milestones/M026/index.md)]"
category: patterns
confidence: 0.90
created_at: 2026-04-24
last_verified: 2026-04-24
hit_count: 89
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
hit_count: 89
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
scope_tags: "[project], [milestone:[M020](../../../../milestones/M020/index.md)]"
category: conventions
confidence: 0.90
created_at: 2026-04-25
last_verified: 2026-04-25
hit_count: 79
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
milestones ([M024](../../../../milestones/M024/index.md) universal intake, [M019](../../../../milestones/M019/index.md) Tier 2+3 observability) MAY READ
the fields but MUST NOT introduce new fields without a follow-up M020 D-row.
The handshake is: open an M020 D-row → M020 lands the schema change →
consuming milestone uses the field. Never bypass this gate.

## Authorising decision

[`.orchestrator/DECISIONS.md`](../../../../decisions.md) D024 (2026-04-25).

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

<!-- Each truth is a behavioral statement + a single-script-file Check (AD-19).
     Every Check command is a single-invocation script-file shape — no inline
     compound bash, no plain subshells, no $() containing pipes, no process
     substitution. All M027/P01 verification logic lives inside the
     scripts/verify/m027-p01-*.sh files; the Check commands here invoke them. -->

### Truths

- `commands/cost.md` exists with the canonical command-file structure (frontmatter `description`, Title, Prerequisites / State Check, Core Workflow numbered sections, Output, Idempotency, Error Handling, Referenced Scripts) per MEM012; documents both the retrospective surface (no flags / scope flags) and the predictive surface (`--estimate <description>`); embeds the D027 +/-20% accuracy disclaimer verbatim under an "Accuracy" subsection (FR-5).
  - Check: `bash scripts/verify/m027-p01-cost-command-shape.sh`

- `orchestrator:cost` with no flags defaults to a milestone-granularity rollup of the active milestone (or project-granularity if no active milestone), is a thin wrapper over `scripts/diagnostics/metrics-rollup.sh`, and emits no JSONL records (FR-5, FR-12 carry-forward, US-2 AS-1, AS-2, AS-5).
  - Check: `bash scripts/verify/m027-p01-cost-retro-default.sh`

- `orchestrator:cost --estimate <description>` emits a three-row (Quick / Standard / Full) paired cost+quality table with the recommended tier marked, completes in zero LLM tokens, and includes a one-line trailer pointing to `commands/cost.md#accuracy` per D027 (FR-20, FR-21, US-5 AS-1, AS-7).
  - Check: `bash scripts/verify/m027-p01-cost-estimate-table.sh`

- Predictive Goodhart pairing — every row of `orchestrator:cost --estimate` output that contains a cost cell also contains a quality-semantics cell on the same row; the verifier rejects any output schema that drops one without the other (FR-20, CON-4, SC-18).

<dispatch-volatile>

## Upstream Context


### P00 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P00"
parent: "M027"
milestone: "M027"
provides:
  - "scripts/diagnostics/metrics-rollup.sh — sourceable bash library + CLI for M027 rollup engine. Exposes metrics_rollup_snapshot,metrics_rollup_normalize,metrics_rollup_aggregate,metrics_rollup_render,metrics_rollup_main. CLI accepts --granularity task|phase|milestone|project,--milestone Mxxx,--phase Pxx,--task <id>,--source estimate|runtime|aggregate|all,--log <path>,--help. Implements FR-1/FR-2 paired cost+quality rows,FR-3 source filter with empty-result annotation,FR-4 Goodhart pairing (cost columns always paired with quality columns; pass_rate=unknown sentinel for degenerate quality input),FR-11 (N missing) suffix on cost cells with pricing warnings,FR-12/CON-1 read-only via mktemp+cp snapshot + EXIT trap,FR-14 corrupt-line tolerance (WARN: corrupt JSONL line N),FR-17 input-schema validation (WARN: input-schema line N),FR-18/AD-1 aggregation precedence aggregate-greater-than-runtime-greater-than-estimate,FR-19/AD-3 copy-then-aggregate FS-race semantics,CON-5 graceful degradation on missing log,CON-6/FR-21 zero LLM tokens (bash+awk+grep+sed),CON-7 bash 3.2 compat. Live invocation against .orchestrator/milestones/M019/execution-log.jsonl prints exactly one milestone row carrying both cost block and quality block on the same row,exit 0.,tests/fixtures/m027-p00/ — deterministic JSONL fixture suite for M027/P00 per-contract verifiers. Six hand-crafted fixtures (estimate-only.jsonl,mixed-source-aggregate.jsonl,corrupt-line.jsonl,missing-fields.jsonl,pricing-warning.jsonl,pre-m019-mixed.jsonl) each crafted to exercise one specific contract (FR-3,FR-18/AD-1,FR-14,FR-17,FR-11,SC-10 respectively). Plus perf-10mb.jsonl.gen.sh — bash 3.2 deterministic generator producing >=10 MB of unit_close records in <1 s; output gitignored. README.md documents per-fixture contracts and FR/SC mappings. All fixtures use M999 milestone ID to keep read-only invariant trivially satisfied.,14 per-contract verifier scripts under scripts/verify/m027-p00-*.sh covering FR-1/FR-2 (rollup-cli-contract),FR-1/FR-4/SC-1 (live-m019-row),FR-4/SC-12 (goodhart-pairing),FR-3/SC-6 (source-filter),FR-18/AD-1/SC-14 (aggregation-precedence),FR-12/SC-9 (read-only via git diff --quiet),FR-21/CON-6 (zero-llm-token grep),FR-14/SC-5 (corrupt-line WARN line N),FR-17 (input-schema WARN),FR-11 (pricing-warning N missing cell suffix),FR-13/FR-19/AD-3/SC-19 (fs-race copy-then-aggregate),CON-12/AD-2/SC-13 (perf-bound 5s/10MB with RELAX-CANDIDATE diagnostic),SC-10 (pre-m019-additivity silent skip),CON-7/SC-11 (bash32-compat). Each verifier emits PASS:/FAIL: per repo convention,exit 0/1/2.,scripts/verify/m027-rollup-schema.sh phase-suite orchestrator: runs all 14 m027-p00-*.sh verifiers in stable order (cheapest first,perf-bound last),aggregates results,prints PASS: m027-rollup-schema.sh 14 gates on green and FAIL list to stderr on red; surfaces RELAX-CANDIDATE annotations from perf-bound on stdout for downstream tooling; live-M019 demo invocation (bash scripts/diagnostics/metrics-rollup.sh --granularity milestone --milestone M019) confirmed green and emits one paired cost+quality milestone row"
requires:
  - "none"
affects:
  - "P01,P03"
key_files:
  - "scripts/diagnostics/metrics-rollup.sh,tests/fixtures/m027-p00/estimate-only.jsonl,tests/fixtures/m027-p00/mixed-source-aggregate.jsonl,tests/fixtures/m027-p00/corrupt-line.jsonl,tests/fixtures/m027-p00/missing-fields.jsonl,tests/fixtures/m027-p00/pricing-warning.jsonl,tests/fixtures/m027-p00/pre-m019-mixed.jsonl,tests/fixtures/m027-p00/perf-10mb.jsonl.gen.sh,tests/fixtures/m027-p00/README.md,tests/fixtures/m027-p00/.gitignore,scripts/verify/m027-p00-aggregation-precedence.sh,scripts/verify/m027-p00-bash32-compat.sh,scripts/verify/m027-p00-corrupt-line.sh,scripts/verify/m027-p00-fs-race.sh,scripts/verify/m027-p00-goodhart-pairing.sh,scripts/verify/m027-p00-input-schema.sh,scripts/verify/m027-p00-live-m019-row.sh,scripts/verify/m027-p00-perf-bound.sh,scripts/verify/m027-p00-pre-m019-additivity.sh,scripts/verify/m027-p00-pricing-warning.sh,scripts/verify/m027-p00-read-only.sh,scripts/verify/m027-p00-rollup-cli-contract.sh,scripts/verify/m027-p00-source-filter.sh,scripts/verify/m027-p00-zero-llm-token.sh,scripts/verify/m027-rollup-schema.sh"
key_decisions:
  - "AD-1,AD-3,AD-19,AD-2,CON-1,CON-7,CON-12,FR-15,SC-2"
patterns_established:
  - "Sourceable-CLI duality via [ BASH_SOURCE-zero == zero-arg ] guard at bottom of file; load-time _METRICS_ROLLUP_SH_SOURCED re-source guard pattern (mirrors pricing.sh); MEM004 carve-out applied — pipes/awk/dollar-paren permitted inside emitter-internal library while AD-19 single-script-file shape rule binds only Check: commands at task/phase plan level; awk single-pass aggregation with parallel-array buckets keyed by (scope,source,granularity) plus per-scope highest-priority-source selection in END block — sidesteps bash 3.2 lack of associative arrays; pre-declared snapshot/normalized/rolled vars before EXIT trap to keep set -u from blowing up the trap when an early-return path skips assignment; bash-3.2-clean comment hygiene — neutralized literal forbidden-construct tokens in comments to avoid tripping the T03 bash32-compat grep regex against the file body,JSONL fixtures named by contract (estimate-only,mixed-source-aggregate,corrupt-line,missing-fields,pricing-warning,pre-m019-mixed) — one fixture per behavioural axis under tests/fixtures/m027-p00/; M999 sentinel milestone ID ensures fixtures cannot collide with real .orchestrator/milestones/ data and the read-only invariant gate is trivially satisfied; perf fixture committed only as a deterministic generator script (gitignored output) — chunk-build-then-cat-repeat pattern reaches 10 MB target in <1 s while staying byte-identical across invocations (no $RANDOM,no $$,no live timestamps); fixture README documents per-fixture contract + FR/SC mapping so T03 verifier authors do not have to reverse-engineer intent from raw JSONL,One-verifier-per-contract scaffolding mirrors scripts/verify/m019-p01-*.sh (PROJECT_ROOT via BASH_SOURCE; PASS/FAIL stdout/stderr; exit 0/1/2); MEM004 emitter-internal carve-out applied so each verifier may use pipes/awk/dollar-paren internally while AD-19 single-script-file shape rule binds only the Check: invocations from PLAN.md; perf-bound RELAX-CANDIDATE diagnostic pattern for bound-relaxation evidence (mirrors planning-brief 'perf may be revisited'); driving the engine fix into T01 — pure-bash while-read normalize was forking O(7) subprocesses per JSONL line and bubble sort over per-bucket cost arrays was O(n^2),both rewritten as awk passes (single normalize pass + qsort) to satisfy CON-12; engine is now ~2.5s on 10MB / 36k records vs ~3min45s before.,phase-suite orchestrator at M027/P00 scale (14 gates) follows m019-p01-phase-suite.sh shape verbatim — parallel-string GATES list,per-gate exit-code capture,PASS/FAIL emission,single-script-file Check shape externally with internal carve-out for the for-loop; RELAX-CANDIDATE forwarding pattern: capture per-gate stdout,grep for the structured annotation,print on suite stdout so plan-phase / consolidate can act on it without scraping; soft-failure semantics: a RELAX-CANDIDATE on perf still counts as gate failure (suite exits 1) but the diagnostic is preserved"
drill_down_paths:
  - ".orchestrator/milestones/M027/phases/P00/tasks/T01-rollup-engine-SUMMARY.md, .orchestrator/milestones/M027/phases/P00/tasks/T02-fixture-suite-SUMMARY.md, .orchestrator/milestones/M027/phases/P00/tasks/T03-per-contract-verifiers-SUMMARY.md, .orchestrator/milestones/M027/phases/P00/tasks/T04-phase-suite-and-demo-SUMMARY.md"
duration: "95m"
verification_result: "pass"
completed_at: "2026-04-27T01:27:03Z"
observability_surfaces:
  - "none"
---

P00 delivers the foundation of M027: a sourceable bash + CLI rollup engine over the M019 Tier 1 JSONL stream, a deterministic fixture suite covering every behavioral axis, fourteen per-contract verifier scripts, and a phase-suite orchestrator that runs them in stable order with structured RELAX-CANDIDATE forwarding. Together they pin every cross-phase contract that P01–P03 will consume: aggregation precedence aggregate>runtime>estimate (FR-18/AD-1), Goodhart cost+quality output pairing (FR-4), source filtering (FR-3), copy-then-aggregate FS-race semantics (FR-19/AD-3), input-schema validation (FR-17), corrupt-line tolerance (FR-14), pricing-warning surfacing (FR-11), read-only invariant (FR-12/CON-1/SC-9), zero-LLM-token (FR-21/CON-6/SC-16), bash 3.2 compat (CON-7/SC-11), and the 5s/10MB performance bound (CON-12/AD-2/SC-13).

The phase shipped in four atomic tasks. T01 created the engine — sourceable library + CLI duality via the BASH_SOURCE/$0 guard, parallel-array awk aggregation that sidesteps bash 3.2's lack of associative arrays, and the EXIT-trap mktemp+cp snapshot for FS-race tolerance. T02 produced six hand-crafted JSONL fixtures plus a deterministic 10MB perf generator (gitignored output, byte-identical across invocations). T03 wrote the fourteen per-contract verifiers following the scripts/verify/m019-p01-*.sh shape. T04 wrote the phase-suite orchestrator and wired the live-M019 demo as the SC-1 entry point.

The headline lesson came at T03's perf-bound gate: T01's metrics_rollup_normalize was a pure-bash while-read loop forking ~7 subprocesses per record (sed/grep/head per JSON field), and metrics_rollup_aggregate used a bubble sort O(n²) over per-bucket cost arrays. Against the 36 200-record / 10 MB perf fixture this clocked ~3:55 wall-clock — far over the 5s CON-12 bound. T01's plan had explicitly anticipated this ("switch normalizer to awk, replace per-record grep calls in bash loops with single awk pass"). T03 drove the fix back into T01's deliverable: rewrote normalize as a single awk pass with match()-based field extraction, replaced bubble sort with a Hoare-partition qsort (O(n log n)). Engine now ~2.5s on 10MB. All 14 verifiers PASS post-fix; the live-M019 demo emits one paired cost+quality milestone row, exit 0.

Two parser-shape lessons surfaced and were folded into per-task PLAN edits: (1) auto-loop's verifier extractor requires fenced ```bash``` code blocks for the Verification section — bullet-with-inline-backtick format silently extracts zero commands; (2) task-level Verification must reference only what the task itself produces, never the phase-level check-must-haves.sh (which gates on the entire phase including future tasks). T02 + T03 + T04 plans were each reformatted accordingly. Verification: m027-rollup-schema.sh suite passes 14/14 gates; phase-level check-must-haves.sh passes all 60+ truth + artifact + key-link rows; live-M019 demo green; read-only invariant verifier (which itself is exercised inside the suite) confirms git diff --quiet against the project tree post-rollup; total phase duration 95 minutes across 4 tasks.

Cross-phase handoff: P01 (orchestrator:cost retrospective + predictive command) sources metrics-rollup.sh as its engine and inherits the Goodhart pairing contract — extending it to the predictive surface per FR-20 + SC-18. P02 (efficiency footer + dispatch-time predictive surface) inherits the byte-identity verifier cases (SC-3 status-quiet, SC-17 dispatch-yes) which P00's verifier carries as placeholders awaiting P02's suppression-path implementation. P03 (anomaly detection + config-check) sources the engine for baseline math and inherits the sample-floor and never-abort patterns. The roadmap reassessment found no boundary-map deviations.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M027"
name: "intensity-recommend.sh cost-annotation hook + --format json cost_estimates per D026"
depends_on: ["T01"]
---

## Prerequisites

- T01 has shipped `scripts/engine/cost-estimate.sh` (sourceable + CLI). After sourcing T01's library, the following functions are defined:
  - `cost_estimate_per_tier "<description>" [--format text|json]` — emits per-tier cost+quality data (text table or single-line JSON). Reads optional module variable `_CE_RECOMMENDED` (one of `quick|standard|full`) to mark the recommended tier; if unset, the function falls back to invoking `cost_estimate_recommend` itself.
  - `cost_estimate_recommend "<description>"` — returns lowercased intensity tier string. Used by CLI mode of T01; T02 does NOT call this (avoids re-entry — see CON below).
  - `cost_estimate_resolve_model` — returns the model id used for cost estimation.
- T01's text output ends with the verbatim D027 trailer `estimates +/-~20%; see commands/cost.md#accuracy`.
- T01's JSON output is shaped `{"recommended":"<tier>","tiers":{"quick":{...},"standard":{...},"full":{...}}}` where each tier's inner shape is `{"cost_usd":<num-or-null>,"input_tokens":<int>,"output_tokens":<int>,"quality":"<str>","pricing_warning":"<str>"}`.
- The current `scripts/engine/intensity-recommend.sh` (pre-T02) emits 8 key=value lines on stdout in fixed order: `intensity=`, `confidence=`, `reasoning=`, `scope=`, `risk_level=`, `complexity=`, `risk_signals=`, `cap_score=`. It does NOT accept `--format` and does NOT emit JSON. CLI flags currently accepted: `--analyze-output`, `--profile-output`, `--description`.
- The current script uses bash 4-style `[[ … ]]` and is bash 3.2 compatible per the project conventions; T02 must not regress this.

## Description

Modify `scripts/engine/intensity-recommend.sh` so it (1) preserves byte-stable text output for the existing 8 key=value lines (CON-3 carry-forward), (2) appends a per-tier cost-annotation block AFTER the existing key=value lines when format is text (default), and (3) accepts a new `--format text|json` flag where `--format json` emits the existing structured fields PLUS a top-level `cost_estimates` object keyed by tier per D026.

The cost-annotation block in text mode is one or more lines below the existing key=value lines, prefixed with a marker (e.g., `# cost estimates (M027/P01)`), so machine consumers grepping for the existing keys (`grep '^intensity='`) continue to work unchanged. The cost annotations themselves are key=value lines for parseability:

```
cost_quick_usd=<num-or-empty>
cost_quick_in_tokens=<int>
cost_quick_out_tokens=<int>
cost_standard_usd=<num-or-empty>
cost_standard_in_tokens=<int>
cost_standard_out_tokens=<int>
cost_full_usd=<num-or-empty>
cost_full_in_tokens=<int>
cost_full_out_tokens=<int>
cost_pricing_warning=<reason-or-empty>
```

The block is suppressed entirely when the operator passes `--no-cost-annotation` (back-compat escape hatch) or when sourcing this script as a library (the existing implementation already runs main only at top level via the script-vs-source idiom; preserve that).

In `--format json` mode, the script emits a single-line JSON object of shape:

```json
{"intensity":"<tier>","confidence":"<level>","reasoning":"<text>","scope":"<scope>","risk_level":"<level>","complexity":"<level>","risk_signals":"<signals>","cap_score":<int>,"cost_estimates":{"quick":{"cost_usd":<num-or-null>,"input_tokens":<int>,"output_tokens":<int>,"pricing_warning":"<str>"},"standard":{...},"full":{...}}}
```

Per D026 the `cost_estimates` object is always present when `--format json` is set, even on pricing degradation (`cost_usd` becomes JSON `null` and `pricing_warning` carries the reason).

## Steps

1. **Open `scripts/engine/intensity-recommend.sh`** and read the full file (already 136 lines; modifications below add ~80 lines).

2. **Argument parsing** — extend the existing `while [[ $# -gt 0 ]]; do case "$1" in ...` loop to accept:
   - `--format text|json` (default `text`); store in `FORMAT` variable; unknown value → exit 2.
   - `--no-cost-annotation` (boolean flag); store in `NO_COST_ANNOTATION` (default 0).
   - Preserve every existing flag and its semantics. Do not change the order of the existing 8 stdout lines.

3. **Source `scripts/engine/cost-estimate.sh`** AFTER all argument parsing and AFTER the existing analyze-output / profile-output / description resolution block, but BEFORE the final `--Output ---` block. The source line: `# shellcheck disable=SC1091` then `. "$REPO_ROOT/scripts/engine/cost-estimate.sh"`. The re-source guard inside cost-estimate.sh prevents repeat loads.

4. **Resolve description for cost estimation** — if `$DESCRIPTION` is empty (the user fed pre-computed `--analyze-output` / `--profile-output`), set `cost_desc=""`. Cost annotation when description is empty is allowed; the char-quartile estimate degrades to overhead-only — emit a stderr WARN line: `WARN: cost-estimate description=empty; estimates use recipe overhead only`.

5. **Compute the per-tier estimate** — set the module variable used by T01's library to skip re-recommending: `_CE_RECOMMENDED="$(printf '%s' "$intensity" | tr '[:upper:]' '[:lower:]')"`. Then call `cost_estimate_per_tier "$cost_desc" --format json` and capture stdout into a variable `cost_json` (single-line JSON). On any failure (empty output, parse fail) set `cost_json='{"recommended":"standard","tiers":{}}'` and emit `WARN: cost-estimate fallback reason=<reason>` to stderr.

6. **Branch on `$FORMAT`**:

   **Text branch** (default):
   - Emit the existing 8 key=value lines via the existing `echo` block — unchanged byte-for-byte.
   - If `NO_COST_ANNOTATION = 1`, stop.
   - Else, emit the per-tier cost-annotation block. Parse `cost_json` for the per-tier values using a single helper function `_cj_field "<json>" "<tier>" "<field>"` that does a regex match against the inline JSON (printf '%s' "$cost_json" | sed -nE 's/.*"<tier>":\{[^{}]*"<field>":(null|[0-9.]+|"[^"]*")[^{}]*\}.*/\1/p'). Strip surrounding quotes for string fields. For null cost_usd, emit empty value. For text values, prefix with `# cost estimates (M027/P01)` comment line, then 9 key=value lines (3 tiers × 3 cost fields) plus the `cost_pricing_warning=<reason>` line.

   **JSON branch**:
   - Build a single-line JSON object via printf-built string composition. The key order: `intensity`, `confidence`, `reasoning`, `scope`, `risk_level`, `complexity`, `risk_signals`, `cap_score`, `cost_estimates`. JSON-escape string values (replace `"` with `\"`, `\` with `\\`, newlines with `\n`) — write a small `_json_escape` helper that uses `sed`. Numeric fields (`cap_score`) emit unquoted; the rest emit quoted.
   - For `cost_estimates`, splice the inner `tiers` object from `cost_json` directly (T01 owns its inner shape; T02 must not re-marshal it). Specifically: extract the substring between the `"tiers":` marker and the closing of its object, OR re-emit it from parsed fields. Reliable approach: T01's `cost_estimate_per_tier --format json` already emits `tiers` as a self-contained object substring; sed-extract it: `tiers_obj=$(printf '%s' "$cost_json" | sed -nE 's/.*"tiers":(\{[^}]*\}\}*)\}*/\1/p')`. If the regex fails (due to nested-object greediness), fall back to reconstructing the object field-by-field from `_cj_field` results. **Implementation discipline**: a single bash 3.2-safe helper function `_cost_tiers_json "$cost_json"` performs this extraction with a documented invariant that T01's output never contains nested objects deeper than 2 levels (recommendations + tiers + per-tier flat). The verifier in T04 covers the JSON parse with both `python3 -c 'import json,sys; json.load(sys.stdin)'` and a printf round-trip.
   - Emit the assembled JSON as one line on stdout. Newline at end. Exit 0.

7. **Latency discipline** — preserve current text-mode latency. The dominant added cost is the source of `cost-estimate.sh` (~20 ms first-load) and the inner per-tier loop (~5 ms). Total text-mode added overhead target: < 50 ms. Verifier asserts.

8. **Zero-LLM-token discipline (FR-21 / CON-6).** The modified script MUST NOT contain any of: `claude_chat`, `anthropic`, `dispatch-interface.sh`, `dispatch_task`, `subagent`. It only sources `pricing.sh` (transitively via cost-estimate.sh) and forks no LLM call.

9. **bash 3.2 compat (CON-7).** No `declare -A`. No `<<<` herestrings. No `mapfile`/`readarray`. No `${var^^}` / `${var,,}` (use `tr`). No `<(...)`. No `&>`.

10. Preserve the file's executable permission and shebang.

## Must-Haves

- File `scripts/engine/intensity-recommend.sh` exists, ≥ 150 lines, contains the literal string `cost_estimates`.
- The first 8 key=value lines on stdout in text mode (`--format text` or no `--format`) are byte-identical to pre-T02 output for any given input. Verified by T04 against a fixture analyze-output / profile-output pair captured pre-modification.
- `--format json` emits a single-line JSON object that parses with `python3 -c 'import json,sys; json.load(sys.stdin)'` (or a fallback bash regex check) and contains a top-level `cost_estimates` object with keys `quick`, `standard`, `full`; each tier carries `cost_usd`, `input_tokens`, `output_tokens`, `pricing_warning`.
- `--no-cost-annotation` flag suppresses the trailing cost-annotation block in text mode; the first 8 lines are still emitted.
- Under `ORCH_PRICING_FILE=/tmp/nonexistent.yml`, the script still emits the 8 key=value lines + cost-annotation block (with empty cost_usd values + `cost_pricing_warning=missing`) in text mode and a valid JSON object with `cost_usd:null` per tier in JSON mode.
- Zero-LLM-token: file does not match `(claude_chat|anthropic|dispatch-interface\.sh|dispatch_task|subagent)`.
- bash 3.2 compat: file does not match `(declare -A|mapfile|readarray|<<<|<\(|>\(|&>|\$\{[a-zA-Z_][a-zA-Z0-9_]*\^\^}|\$\{[a-zA-Z_][a-zA-Z0-9_]*,,})`.

## Verification

```bash
bash scripts/engine/intensity-recommend.sh --description "add a TypeScript rewrite of the parser" --format json
```

The above must exit 0 and print one single-line JSON object containing both the existing structured fields (intensity, confidence, reasoning, scope, risk_level, complexity, risk_signals, cap_score) and a top-level `cost_estimates` object with `quick`, `standard`, `full` keys. Per-contract verifiers (text byte-stability, JSON shape, pricing degradation, zero-LLM-token, bash 3.2) live in T04 and are wired into `scripts/verify/m027-p01-suite.sh`. The phase-level `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M027/phases/P01` runs at the phase boundary, not at T02 task verification.

## Inputs

### From Previous Tasks

- T01: `scripts/engine/cost-estimate.sh` — sourceable. After source:
  - `cost_estimate_per_tier "<description>" --format json` returns a single-line JSON object `{"recommended":"<tier>","tiers":{"quick":{...},"standard":{...},"full":{...}}}` where each tier's inner shape is `{"cost_usd":<num-or-null>,"input_tokens":<int>,"output_tokens":<int>,"quality":"<str>","pricing_warning":"<str>"}`.
  - Module variable `_CE_RECOMMENDED` may be set before the call to skip the inner intensity-recommend re-fork. T02 sets this from the locally-computed `intensity` to avoid infinite recursion.

### From Disk (Pre-existing)

- `scripts/engine/intensity-recommend.sh` (current shape, pre-T02) — modify in place. Existing flags `--analyze-output`, `--profile-output`, `--description` are preserved. The 8 stdout key=value lines are byte-stable.
- `scripts/lib/pricing.sh` — transitively sourced via `cost-estimate.sh`. T02 does not source it directly.
- `scripts/dispatch/detect-capabilities.sh` — invoked via existing logic; T02 does not modify the call.
- `scripts/engine/intensity-analyze.sh` — invoked via existing logic; T02 does not modify the call.

## Constraints

- **CON-3 (back-compat)**: The first 8 stdout lines in text mode must be byte-identical to pre-T02 output for the same inputs. T04's `m027-p01-intensity-text-back-compat.sh` verifier captures pre-T02 output against fixture inputs and `diff`s.
- **CON-4 / FR-20 (Goodhart)**: The cost-annotation block carries quality semantics (per-tier quality is implicit in T01's output but T02 makes it explicit by emitting `cost_quick_quality=`, `cost_standard_quality=`, `cost_full_quality=` lines after the per-tier numeric lines). This satisfies SC-18 at the predictive intensity-recommend surface. Reconcile with step 6 above: add these 3 lines to the text-mode block; add `quality` to the JSON per-tier object (already present from T01).
- **CON-6 / FR-21 (zero-token)**: bash + sourced `pricing.sh` (transitive) only.
- **CON-7 (bash 3.2)**: T04's bash32-compat verifier will grep this file.
- **CON-9 / FR-22 (latency)**: text-mode end-to-end < 200 ms target (allowing for the existing forks to `intensity-analyze.sh` + `detect-capabilities.sh`); the *cost-annotation overhead* is < 50 ms. T04 measures both.
- **D026 (JSON shape)**: `cost_estimates` keyed by `quick`/`standard`/`full`, each carrying `cost_usd`, `input_tokens`, `output_tokens`, `pricing_warning`. T04's JSON-shape verifier asserts.
- **No-recursion invariant**: T02 sets `_CE_RECOMMENDED` before calling `cost_estimate_per_tier`, ensuring T01's library does not re-fork `intensity-recommend.sh`.
- **MEM004 carve-out applies here**: pipes / `$()` / `awk` / `sed` are permitted *inside* this script.

## Expected Output

After this task:

1. `scripts/engine/intensity-recommend.sh` exists, ≥ 150 lines, executable.
2. Running `bash scripts/engine/intensity-recommend.sh --description "<task>"` emits the existing 8 key=value lines unchanged, followed by a `# cost estimates (M027/P01)` comment line and 12 cost-annotation key=value lines (9 numeric + 3 quality + 1 pricing warning).
3. Running with `--format json` emits one single-line JSON object with the 8 existing fields + `cost_estimates` object per D026.
4. Running with `--no-cost-annotation` (text mode) suppresses the cost-annotation block; the 8 key=value lines are unchanged.
5. Running under `ORCH_PRICING_FILE=/tmp/nonexistent.yml` still produces the cost-annotation block with empty cost_usd values + `cost_pricing_warning=missing` (text) or null cost_usd values (JSON).
6. `git diff --quiet` after running the script on a sample description returns exit 0.

## State Context

- **Current State**: executing
- **Milestone**: M027
- **Phase**: P01
- **Task**: T02-intensity-recommend-hook
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **CON-3 (back-compat)**: The first 8 stdout lines in text mode must be byte-identical to pre-T02 output for the same inputs. T04's `m027-p01-intensity-text-back-compat.sh` verifier captures pre-T02 output against fixture inputs and `diff`s.
- **CON-4 / FR-20 (Goodhart)**: The cost-annotation block carries quality semantics (per-tier quality is implicit in T01's output but T02 makes it explicit by emitting `cost_quick_quality=`, `cost_standard_quality=`, `cost_full_quality=` lines after the per-tier numeric lines). This satisfies SC-18 at the predictive intensity-recommend surface. Reconcile with step 6 above: add these 3 lines to the text-mode block; add `quality` to the JSON per-tier object (already present from T01).
- **CON-6 / FR-21 (zero-token)**: bash + sourced `pricing.sh` (transitive) only.
- **CON-7 (bash 3.2)**: T04's bash32-compat verifier will grep this file.
- **CON-9 / FR-22 (latency)**: text-mode end-to-end < 200 ms target (allowing for the existing forks to `intensity-analyze.sh` + `detect-capabilities.sh`); the *cost-annotation overhead* is < 50 ms. T04 measures both.
- **D026 (JSON shape)**: `cost_estimates` keyed by `quick`/`standard`/`full`, each carrying `cost_usd`, `input_tokens`, `output_tokens`, `pricing_warning`. T04's JSON-shape verifier asserts.
- **No-recursion invariant**: T02 sets `_CE_RECOMMENDED` before calling `cost_estimate_per_tier`, ensuring T01's library does not re-fork `intensity-recommend.sh`.
- **MEM004 carve-out applies here**: pipes / `$()` / `awk` / `sed` are permitted *inside* this script.

### Acceptance Criteria

- File `scripts/engine/intensity-recommend.sh` exists, ≥ 150 lines, contains the literal string `cost_estimates`.
- The first 8 key=value lines on stdout in text mode (`--format text` or no `--format`) are byte-identical to pre-T02 output for any given input. Verified by T04 against a fixture analyze-output / profile-output pair captured pre-modification.
- `--format json` emits a single-line JSON object that parses with `python3 -c 'import json,sys; json.load(sys.stdin)'` (or a fallback bash regex check) and contains a top-level `cost_estimates` object with keys `quick`, `standard`, `full`; each tier carries `cost_usd`, `input_tokens`, `output_tokens`, `pricing_warning`.
- `--no-cost-annotation` flag suppresses the trailing cost-annotation block in text mode; the first 8 lines are still emitted.
- Under `ORCH_PRICING_FILE=/tmp/nonexistent.yml`, the script still emits the 8 key=value lines + cost-annotation block (with empty cost_usd values + `cost_pricing_warning=missing`) in text mode and a valid JSON object with `cost_usd:null` per tier in JSON mode.
- Zero-LLM-token: file does not match `(claude_chat|anthropic|dispatch-interface\.sh|dispatch_task|subagent)`.
- bash 3.2 compat: file does not match `(declare -A|mapfile|readarray|<<<|<\(|>\(|&>|\$\{[a-zA-Z_][a-zA-Z0-9_]*\^\^}|\$\{[a-zA-Z_][a-zA-Z0-9_]*,,})`.

### Files To Touch

- commands/cost.md (create)
- scripts/engine/cost-estimate.sh (create)
- scripts/engine/intensity-recommend.sh (modify)
- scripts/verify/m027-p01-suite.sh (create)
- scripts/verify/m027-p01-cost-command-shape.sh (create)
- scripts/verify/m027-p01-cost-retro-default.sh (create)
- scripts/verify/m027-p01-cost-estimate-table.sh (create)
- scripts/verify/m027-p01-predictive-goodhart-pairing.sh (create)
- scripts/verify/m027-p01-zero-llm-token.sh (create)
- scripts/verify/m027-p01-predictive-latency.sh (create)
- scripts/verify/m027-p01-pricing-degradation.sh (create)
- scripts/verify/m027-p01-intensity-text-back-compat.sh (create)
- scripts/verify/m027-p01-intensity-json-cost-estimates.sh (create)
- scripts/verify/m027-p01-read-only.sh (create)
- scripts/verify/m027-p01-runtime-adapter-registration.sh (create)
- scripts/verify/m027-p01-bash32-compat.sh (create)

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