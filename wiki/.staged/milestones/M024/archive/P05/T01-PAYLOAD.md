---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T01 (Phase P05, Milestone M024)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~800 | required |
| Upstream Context | 981-1047 | ~1600 | required |
| Task Plan | 1049-1218 | ~2100 | required |
| State Context | 1220-1226 | ~100 | required |
| First-Turn Completeness | 1228-1266 | ~600 | required |
| **Total** | | **~16000** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 491
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
hit_count: 491
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
hit_count: 491
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
hit_count: 491
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
hit_count: 430
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
hit_count: 430
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
hit_count: 430
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
hit_count: 491
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
hit_count: 430
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
hit_count: 430
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
hit_count: 430
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
hit_count: 491
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
hit_count: 491
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
hit_count: 491
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
hit_count: 430
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
hit_count: 430
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
hit_count: 430
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
hit_count: 491
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
hit_count: 430
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
hit_count: 430
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
hit_count: 491
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
hit_count: 491
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
hit_count: 430
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
hit_count: 430
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
hit_count: 430
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
hit_count: 85
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
hit_count: 85
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
hit_count: 85
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
hit_count: 67
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
hit_count: 67
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
hit_count: 57
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
milestones (M024 universal intake, [M019](../../../../milestones/M019/index.md) Tier 2+3 observability) MAY READ
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

### Truths

- `templates/intake-qa-questions.md` exists with YAML frontmatter (`schema_version: "1.0"`, `type: intake-qa-questions`) and a body containing exactly five questions numbered `### Q1` through `### Q5`, each with a one-line prompt and a one-line guidance hint. The five question topics (goal / scope / surface / adversarial / time-boxing) are present and grep-stable.
  - Check: `bash scripts/verify/m024-p05-qa-questions-template.sh`
- `scripts/intake/qa-loop.sh` is executable, accepts `--answers-from <file>` (line-mode: one answer per line, blank line or `enough` short-circuits), and emits a transcript to a caller-supplied path via `--transcript-out <path>`. The transcript file format is one `### Q<N>` heading + one prose answer block per turn, plus a final `qa_short_circuited=true|false` stdout key=value line.
  - Check: `bash scripts/verify/m024-p05-qa-loop-script.sh`
- `scripts/intake/qa-loop.sh` enforces the FR-5 cap: a `--answers-from` file with more than 5 lines is truncated to the first 5; the resulting transcript contains exactly 5 `### Q` headings; `qa_short_circuited=false` is emitted.
  - Check: `bash scripts/verify/m024-p05-qa-loop-cap.sh`
- `scripts/intake/qa-loop.sh` honors the `enough` short-circuit: when an answer line is the literal lowercase string `enough` (whitespace-trimmed, case-insensitive) the loop terminates after the prior turn; the resulting transcript contains exactly the answers gathered before the `enough` token; `qa_short_circuited=true` is emitted.
  - Check: `bash scripts/verify/m024-p05-qa-loop-shortcircuit.sh`
- `scripts/intake/proposal-emit.sh`, when invoked with neither `--input` nor `--spec-path`, accepts a new `--qa-answers-from <file>` flag that triggers the qa-loop, embeds the resulting transcript under a `## Q&A` heading in the proposal body, sets `input_shape: empty_qa` (instead of the P01 `empty` stub), and propagates `qa_short_circuited=true|false` to the proposal frontmatter. When `qa_short_circuited=true`, `low_confidence: true` is also set so the P04 fast-path guard fires.
  - Check: `bash scripts/verify/m024-p05-proposal-emit-empty-qa.sh`
- A full-5-answers Q&A flow produces a proposal with `input_shape: empty_qa`, `qa_short_circuited: false`, `low_confidence: false` (unless overridden by the shape-detect classifier — N/A for empty-qa), and a `## Q&A` section containing exactly 5 `### Q<N>` headings.
  - Check: `bash scripts/verify/m024-p05-empty-qa-full.sh`
- A short-circuited Q&A flow (operator types `enough` after turn 2) produces a proposal with `input_shape: empty_qa`, `qa_short_circuited: true`, `low_confidence: true`, and a `## Q&A` section containing exactly 2 `### Q<N>` headings; the proposal cannot auto-proceed via the P04 fast-path because `low_confidence: true` is one of the five disqualifying conditions.
  - Check: `bash scripts/verify/m024-p05-empty-qa-shortcircuit.sh`
- All P05-introduced shell scripts respect SB-3 write-confinement: writes target only `.orchestrator/intake/<id>/` (proposal frontmatter + body mutations) and `/tmp` (test scratch + transcript scratch). The qa-loop itself writes only to its `--transcript-out` argument.
  - Check: `bash scripts/verify/m024-p05-write-confinement.sh`

<dispatch-volatile>

## Upstream Context


### P01 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M024"
milestone: "M024"
provides:
  - "templates/intake-proposal.md (25-key frontmatter contract); scripts/intake/shape-detect.sh; scripts/intake/intake-id-allocate.sh; scripts/intake/proposal-emit.sh; 7 scripts/verify/m024-p01-*.sh helpers; tests/test-intake-proposal-shape.sh; tests/test-intake-manifest-superset.sh; tests/fixtures/m014-interim-manifest-keys.txt"
requires:
  - "none"
affects:
  - "P02,P03,P04,P05,P06,P07"
key_files:
  - "templates/intake-proposal.md, scripts/intake/proposal-emit.sh, scripts/intake/shape-detect.sh, scripts/intake/intake-id-allocate.sh, scripts/verify/m024-p01-suite.sh, tests/test-intake-proposal-shape.sh, tests/test-intake-manifest-superset.sh, tests/fixtures/m014-interim-manifest-keys.txt"
key_decisions:
  - "P01 emits stub axis values (scope_tier=A, decomposition=single-task, design_gate=none, conversus_gate=none); fixture-based M014 manifest superset (AD-4 direction a, P02 wires live read); strict-superset loop-back added feature_slug+milestone+status to T01"
patterns_established:
  - "P01-stub axis pattern (SC-7+FR-13 honored without fabrication); AD-19 single-script-file verify shape; verification-block authoring convention (only runnable commands inside fenced blocks under Verification, expected output in inline backticks)"
drill_down_paths:
  - ".orchestrator/milestones/M024/phases/P01/tasks/T01-SUMMARY.md, .orchestrator/milestones/M024/phases/P01/tasks/T02-SUMMARY.md, .orchestrator/milestones/M024/phases/P01/tasks/T03-SUMMARY.md, .orchestrator/milestones/M024/phases/P01/tasks/T04-SUMMARY.md, .orchestrator/milestones/M024/phases/P01/tasks/T05-SUMMARY.md"
duration: "10m"
verification_result: "pass"
completed_at: "2026-04-26T01:05:39Z"
observability_surfaces:
  - "none"
---

## Summary

P01 lays the schema spine for M024 universal intake routing: a static proposal template, three composable scripts (shape detector + intake-id allocator + emitter), and a phase-level test suite that proves the proposal frontmatter is a strict superset of the M014 interim manifest. Five tasks (T01–T05) executed sequentially; T05 looped back to T01/T04 to add `feature_slug`, `milestone`, and `status` keys after the manifest-superset check exposed the gap.

## What was built

- **`templates/intake-proposal.md`** — pinned 25-key frontmatter (23 from T01 + `feature_slug`/`milestone` + `status` from T05 loopback), six axis sections (Input Shape / Scope Tier / Decomposition / Design Gate / Conversus Gate / Intensity), `{{placeholder}}` substitution syntax. AD-3 pin: `schema_version: "1.0"`.
- **`scripts/intake/shape-detect.sh`** — mechanical classifier across the FR-1 enum (`spec | empty | fragment | idea | paragraph`). Resolves spec #Q-1 with an ordered rule table; emits `input_shape=<value>` + `shape_classification=<high|low>`.
- **`scripts/intake/intake-id-allocate.sh`** — two-mode allocator: spec-path reuses the spec slug (FR-11); free-text input counter-allocates `<NNN>-<short-slug>` (AD-2). Writes nothing.
- **`scripts/intake/proposal-emit.sh`** — orchestration script wiring the three components + `scripts/engine/intensity-recommend.sh` (FR-9 reuse, falls back to `Standard`). Emits to `.orchestrator/intake/<intake_id>/proposal.md`. P01 emits stub axis values for `scope_tier=A` / `decomposition=single-task` / `design_gate=none` / `conversus_gate=none` / `recommended_command=orchestrator:dispatch` — deep classifiers ship in P02–P07. SC-7 (frontmatter completeness) satisfied; FR-13 evidence honesty preserved via stub rationale `"P01 stub — deep classifier ships in a later phase."`.
- **`tests/test-intake-proposal-shape.sh`** — SC-7 frontmatter completeness across paragraph/idea/spec-path inputs.
- **`tests/test-intake-manifest-superset.sh`** — SC-8 / FR-15 / DC-5 strict-superset assertion against `tests/fixtures/m014-interim-manifest-keys.txt` (P01 captures the M014 manifest key set as a static fixture; P02 wires the live read direction per AD-4 direction `a`).
- **`scripts/verify/m024-p01-*.sh`** (7 scripts) — single-script-file shape (AD-19): template-frontmatter, intake-id-allocate, shape-detector, proposal-emit, write-confinement (SB-3), schema-version (AD-3), suite.

## Key decisions / patterns

- **AD-19 verify-script convention reinforced**: every external invocation is a single-script-file shape; no inline compound bash, no plain subshells, no `$(...)` containing pipes.
- **Verification block authoring fix**: removed "Expected output:" fenced blocks from T01–T03/T05 task plans — `auto-loop.sh --step=V` extracts every line inside fenced blocks under `## Verification` as a runnable command. Expected-output text now lives in inline backticks. This is a plan-authoring convention worth promoting to `commands/plan-phase.md`.
- **P01-stub axis pattern**: SC-7 (frontmatter completeness) and FR-13 (evidence citation) are both honored without P01 fabricating tier/gate decisions. Each axis records the value AND an honest fallback evidence string. P02–P07 progressively replace stub rationales with real per-axis logic.
- **Loop-back-on-strict-superset**: T05's manifest-superset check found three M014 keys missing from T01 (`feature_slug`, `milestone`, `status`); T05 looped back and edited the upstream files rather than weakening the assertion. This is the FR-15 commitment in action.

## Verification

`bash scripts/verify/m024-p01-suite.sh` — all five P01 verifies pass:
- `PASS: test-intake-proposal-shape.sh — paragraph, idea, spec-path (3 cases)`
- `PASS: test-intake-manifest-superset.sh — proposal contains all 6 M014 manifest keys + 20 M024-specific keys`
- `PASS: M024/P01 suite — proposal-shape + manifest-superset`

Per-task verifies (template-frontmatter, intake-id-allocate, shape-detector, proposal-emit, write-confinement, schema-version) all PASS independently.

## Downstream notes for P02–P07

- The 25-key frontmatter is forward-binding. Any later phase that wants to add a key must ship a Decision row first.
- The five P01 stub axis values are placeholders awaiting per-phase deep classifiers (P02 scope-tier-spec, P03 scope-tier-paragraph, P07 design-gate, etc.).
- The fixture-based superset assertion is the FR-15 canary. P02 should wire the live M014 manifest read direction; the fixture stays as the contracted source of truth at P01 time.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P05"
milestone: "M024"
name: "Static qa-questions template — templates/intake-qa-questions.md"
depends_on: []
---

## Prerequisites

- P01 complete: the `templates/intake-proposal.md` shape exists; the proposal frontmatter carries `qa_short_circuited: <bool>` and `low_confidence: <bool>` keys (both default to `false`); the proposal body has a body-rendering path consumable by P05/T03 (see T03 plan for the embedding shape).
- The repo's `templates/` directory follows MEM013 conventions: YAML frontmatter with `schema_version` + `type` fields, `{{placeholder}}` syntax for dynamic values when applicable, no hardcoded milestone/phase/task IDs.

## Description

Author `templates/intake-qa-questions.md` — the **static 5-question template** that resolves spec open-question #Q-3 first cut. The template is pure data: a YAML frontmatter block plus five numbered question blocks, each with a one-line prompt and a one-line guidance hint covering one load-bearing routing axis.

The five questions are pinned in this exact order (T02's loop reads them by `### Q<N>` heading number):

1. **Q1 — Goal** (drives input_shape rationale + scope_tier evidence)
2. **Q2 — Scope** (drives decomposition axis)
3. **Q3 — Visible surface** (drives design_gate signal)
4. **Q4 — Adversarial review** (drives conversus_gate signal)
5. **Q5 — Time-boxing** (drives intensity axis)

This is a static-template-first cut per the planning-payload's #Q-3 resolution and the D019 reuse-over-rebuild posture. Conversus-loop and knowledge-driven question sources are deferred — they can land as a future M024.x extension if dogfood signals demand a richer source. The static cut earns SC-3 (≤5 turns + transcript embedded) and FR-5 (bounded loop, `enough` short-circuit, transcript embedded under `## Q&A`) without introducing new dynamic plumbing.

## Steps

1. **Author `templates/intake-qa-questions.md`** with the following content verbatim:

   ```markdown
   ---
   schema_version: "1.0"
   type: intake-qa-questions
   ---

   # Intake Q&A — Static 5-Question Template (M024/P05)

   This template is consumed by `scripts/intake/qa-loop.sh` when an operator
   invokes `orchestrator:evaluate` with neither `--input` nor `--spec-path`.
   The qa-loop reads questions in order by `### Q<N>` heading number, presents
   each prompt to the operator (or the line-mode answers file in tests), and
   captures the answer for embedding under `## Q&A` in the emitted proposal.

   The operator may answer any subset and short-circuit at any point with
   the literal token `enough`. The cap is 5 turns (FR-5).

   ### Q1 — Goal

   **Prompt**: What outcome do you want this work to produce?

   **Guidance**: One sentence. A target state ("status command caches the
   last result") rather than an action ("add caching"). This drives the
   input_shape rationale and the scope_tier evidence for the proposal.

   ### Q2 — Scope

   **Prompt**: Is this a single fix, a single feature, or a milestone-sized body of work?

   **Guidance**: One of `single-task`, `single-feature`, or
   `milestone`. Single-task is a one-script bug fix or doc edit;
   single-feature is one phase of work; milestone is multi-phase. This
   drives the decomposition axis.

   ### Q3 — Visible surface

   **Prompt**: What surface does the change touch — code, docs, config, workflow, or UI?

   **Guidance**: One or more of `code`, `docs`, `config`, `workflow`,
   `ui`. UI-touching work hints at a design-gate recommendation; the
   other surfaces typically do not. This drives the design_gate signal.

   ### Q4 — Adversarial review

   **Prompt**: Does the change touch security, correctness, or contested design?

   **Guidance**: `yes` or `no`. Yes-answers escalate the conversus_gate
   axis to `recommended`; no-answers leave it at `none`. This drives the
   conversus_gate signal.

   ### Q5 — Time-boxing

   **Prompt**: Roughly how long should this take — Quick (≤30 minutes), Standard (≤2 hours), or Full (multi-session)?

   **Guidance**: One of `Quick`, `Standard`, or `Full`. The answer
   feeds the intensity axis directly (the proposal-emit may still
   override via `intensity-recommend.sh` if the input description
   warrants).
   ```

2. **Author `scripts/verify/m024-p05-qa-questions-template.sh`** — asserts the template ships with the expected YAML schema fields and the five `### Q<N>` headings:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m024-p05-qa-questions-template.sh
   # Verifies templates/intake-qa-questions.md ships with the pinned schema
   # fields and the five ### Q<N> heading blocks per M024/P05 #Q-3 resolution.

   set -u
   ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   F="$ROOT/templates/intake-qa-questions.md"

   [ -f "$F" ] || { echo "FAIL: $F missing"; exit 1; }

   grep -q '^schema_version: "1.0"' "$F" \
     || { echo "FAIL: schema_version 1.0 not present in $F"; exit 1; }
   grep -q '^type: intake-qa-questions' "$F" \
     || { echo "FAIL: type: intake-qa-questions not present in $F"; exit 1; }

   for n in 1 2 3 4 5; do
     grep -q "^### Q$n " "$F" \
       || { echo "FAIL: ### Q$n heading missing in $F"; exit 1; }
   done

   # Topic words must be grep-stable so T02 can rely on them.
   grep -q -i 'goal'             "$F" || { echo "FAIL: Q1 goal topic missing";          exit 1; }
   grep -q -i 'scope'            "$F" || { echo "FAIL: Q2 scope topic missing";         exit 1; }
   grep -q -i 'surface'          "$F" || { echo "FAIL: Q3 visible surface missing";     exit 1; }
   grep -q -i 'adversarial'      "$F" || { echo "FAIL: Q4 adversarial review missing";  exit 1; }
   grep -q -i 'time'             "$F" || { echo "FAIL: Q5 time-boxing missing";         exit 1; }

   echo "PASS: intake-qa-questions.md — schema + five ### Q<N> blocks + topic words present"
   exit 0
   ```

3. **Make the verify executable**: `chmod +x scripts/verify/m024-p05-qa-questions-template.sh` (single command — do not chain).

## Must-Haves

- `templates/intake-qa-questions.md` exists, has YAML frontmatter with `schema_version: "1.0"` and `type: intake-qa-questions`, and contains exactly five `### Q<N>` headings (Q1 through Q5).
- The five topic words (goal / scope / surface / adversarial / time) are grep-stable in the template body — T02's loop and downstream test assertions rely on them.
- `scripts/verify/m024-p05-qa-questions-template.sh` exists, is executable, and exits 0 with `PASS: ...` on a clean checkout.
- AD-19 single-script-file shape: every external command in the verify is a top-level invocation; no inline compound bash, no plain subshells, no `$(... | ...)`.
- SB-3 write-confinement: T01 writes only to `templates/intake-qa-questions.md` and `scripts/verify/m024-p05-qa-questions-template.sh`.

## Verification

```
bash scripts/verify/m024-p05-qa-questions-template.sh
```

Exits 0 with `PASS: intake-qa-questions.md — schema + five ### Q<N> blocks + topic words present`.

## Inputs

### From Previous Tasks

- None. T01 is the first task in P05 and depends only on pre-existing P01 / P04 infrastructure (which T01 does not modify).

### From Disk (Pre-existing)

- `templates/` directory — pre-existing template directory that follows MEM013 conventions (YAML frontmatter with `schema_version` + `type`).
- `scripts/verify/` directory — pre-existing verify-script home for M024 phase verifies.

## Constraints

- POSIX sh + bash 3.2 portable. No `declare -A`. No process substitution. No `[[ ]]` in the verify body.
- Writes only to `templates/intake-qa-questions.md` and `scripts/verify/m024-p05-qa-questions-template.sh` (SB-3).
- AD-19 single-script-file shape: every external invocation in the verify is a top-level command; no inline compound bash, no plain subshells, no `$(... | ...)` containing pipes.
- The template is **static and pinned** — no `{{placeholder}}` substitutions. T02's loop reads literal heading text. (Future dynamic-question-source extensions can land as a sibling file without breaking the static contract.)
- The five `### Q<N>` headings MUST be in the order Q1–Q5 per the loop's read-by-number convention.

## Expected Output

`templates/intake-qa-questions.md` is created with the five-question content above; `scripts/verify/m024-p05-qa-questions-template.sh` is created and executable; the verify exits 0 with the `PASS:` line.

## State Context

- **Current State**: executing
- **Milestone**: M024
- **Phase**: P05
- **Task**: T01
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- POSIX sh + bash 3.2 portable. No `declare -A`. No process substitution. No `[[ ]]` in the verify body.
- Writes only to `templates/intake-qa-questions.md` and `scripts/verify/m024-p05-qa-questions-template.sh` (SB-3).
- AD-19 single-script-file shape: every external invocation in the verify is a top-level command; no inline compound bash, no plain subshells, no `$(... | ...)` containing pipes.
- The template is **static and pinned** — no `{{placeholder}}` substitutions. T02's loop reads literal heading text. (Future dynamic-question-source extensions can land as a sibling file without breaking the static contract.)
- The five `### Q<N>` headings MUST be in the order Q1–Q5 per the loop's read-by-number convention.

### Acceptance Criteria

- `templates/intake-qa-questions.md` exists, has YAML frontmatter with `schema_version: "1.0"` and `type: intake-qa-questions`, and contains exactly five `### Q<N>` headings (Q1 through Q5).
- The five topic words (goal / scope / surface / adversarial / time) are grep-stable in the template body — T02's loop and downstream test assertions rely on them.
- `scripts/verify/m024-p05-qa-questions-template.sh` exists, is executable, and exits 0 with `PASS: ...` on a clean checkout.
- AD-19 single-script-file shape: every external command in the verify is a top-level invocation; no inline compound bash, no plain subshells, no `$(... | ...)`.
- SB-3 write-confinement: T01 writes only to `templates/intake-qa-questions.md` and `scripts/verify/m024-p05-qa-questions-template.sh`.

### Files To Touch

- templates/intake-qa-questions.md (create)
- scripts/intake/qa-loop.sh (create)
- scripts/intake/proposal-emit.sh (modify — add --qa-answers-from flag + empty-qa branch + Q&A section embedding)
- commands/evaluate.md (modify — update empty-shape row in Input Shapes table)
- tests/test-empty-qa-loop.sh (create)
- tests/test-qa-short-circuit.sh (create)
- scripts/verify/m024-p05-qa-questions-template.sh (create)
- scripts/verify/m024-p05-qa-loop-script.sh (create)
- scripts/verify/m024-p05-qa-loop-cap.sh (create)
- scripts/verify/m024-p05-qa-loop-shortcircuit.sh (create)
- scripts/verify/m024-p05-proposal-emit-empty-qa.sh (create)
- scripts/verify/m024-p05-empty-qa-full.sh (create)
- scripts/verify/m024-p05-empty-qa-shortcircuit.sh (create)
- scripts/verify/m024-p05-write-confinement.sh (create)
- scripts/verify/m024-p05-evaluate-md.sh (create)
- scripts/verify/m024-p05-suite.sh (create)

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