---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T01-fetch (Phase P03, Milestone M014)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (30 entries) | 20-809 | ~9200 | filtered |
| Decisions | 811-813 | ~100 | filtered |
| Constraints | 815-867 | ~600 | required |
| Scope | 869-897 | ~500 | required |
| Upstream Context | 899-1007 | ~3700 | required |
| Task Plan | 1009-1273 | ~3400 | required |
| State Context | 1275-1281 | ~100 | required |
| First-Turn Completeness | 1283-1332 | ~700 | required |
| **Total** | | **~18300** | |

## Knowledge

<!-- 30 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 426
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
hit_count: 426
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
hit_count: 426
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
hit_count: 426
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
hit_count: 376
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
hit_count: 376
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
hit_count: 376
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
hit_count: 426
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
hit_count: 376
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
hit_count: 376
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
hit_count: 376
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
hit_count: 426
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
hit_count: 426
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
hit_count: 426
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
hit_count: 376
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
hit_count: 376
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
hit_count: 376
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
hit_count: 426
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
hit_count: 376
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
hit_count: 376
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
hit_count: 426
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
hit_count: 426
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
hit_count: 376
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
hit_count: 376
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
hit_count: 376
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
hit_count: 31
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
hit_count: 31
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
scope_tags: "[project], [milestone:M014], [concern:bash-compat]"
category: lessons
confidence: 0.95
created_at: 2026-04-23
last_verified: 2026-04-23
hit_count: 31
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
hit_count: 2
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
hit_count: 2
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

<!-- AD-19: every Check is a single-script-file invocation. No inline compound bash, subshells, or $(...|pipe). -->

### Truths

- `scripts/comments/fetch.sh` enumerates unactioned comments from Giscus + GitHub Issue/PR surfaces, caches each to `.orchestrator/comments/inbox/<comment-id>.json`, and skips entries whose URL is already in `.orchestrator/comments/actioned.jsonl`. Dry-run path emits FR-19 JSONL action records without disk mutation.
  - Check: `bash scripts/verify/m014-p03-fetch.sh`

- `scripts/comments/classify.sh <inbox-file>` reads one cached inbox comment and emits a single-line `class=<class> confidence=<score>` verdict on stdout for one of the four FR-9 classes (`uat-bug`, `decision-append`, `spec-amendment`, `ambiguous`). Per D023, classifier shape is regex/heuristic v1 — no LLM round-trip on the primary classification path. Ambiguous routes to `scripts/dispatch/adapters/tool/conversus.sh gate classify-comment` per CON-4 (`--strict`).
  - Check: `bash scripts/verify/m014-p03-classify.sh`

- `commands/comments.md` documents the user-facing surface with subcommands `classify`, `status`, `apply`, `reject`, `triage`, `reclassify`; references the regex/heuristic v1 baseline per D023 with explicit retune-trigger language; documents the FR-19 dry-run manifest shape.
  - Check: `bash scripts/verify/m014-p03-commands-md.sh`

- `scripts/comments/apply.sh <queue-id>` applies an operator-approved spec-amendment queue item atomically: edits the target spec at the [M011](../../../../milestones/M011/index.md) chunk source line range, runs `scripts/knowledge/rebuild-index.sh`, marks the comment actioned in `actioned.jsonl`. Refuses on stale diffs (US-5 AS-2). Refuses when the target spec has an in-flight conversus deliberation (US-5 AS-4).
  - Check: `bash scripts/verify/m014-p03-apply.sh`

- `scripts/comments/reject.sh <queue-id> --reason <prose>` marks a queue item actioned with `applied: false` and records the rejection reason; `scripts/comments/triage.sh` lists comments routed to the human-triage bucket with their conversus-adapter verdict (when present).
  - Check: `bash scripts/verify/m014-p03-reject-triage.sh`

<dispatch-volatile>

## Upstream Context


### P01 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M014"
milestone: "M014"
provides:
  - "templates/spec-template.md Section Contract SSOT; templates/spec-scaffolder-prompt.md FR-3 prompt; tests/fixtures/m014-p01/expected-section-headings.txt; tests/fixtures/m014-p01/specify-fixture-prose.txt; scripts/verify/m014-p01-template-ssot.sh, spec-shape-lint-surface,m014-p01-gate-verifier, FR-12 dual-write helper (marker-bounded), dual_write_agents config key, SC-6a outside-bytes invariant test, three P01 gate verifiers, FR-5 complexity probe stub surface + D016 RUNTIME-ASSUMPTIONS.md registry scaffold, commands/specify.md + scripts/specify/specify.sh FR-1 create-path + .orchestrator/config.yml specify: section, FR-18 byte-compat fixture test; SC-11 partial spec-management reference doc, M014/P01 phase verification suite: bash32-compat + zero-prompts + phase-suite orchestrator (14 gates)"
requires:
  - "(none), T01, from:disk what:.orchestrator/config.yml and scripts/verify/anti-pattern-lint.sh, from:T01 what:templates/spec-template.md + templates/spec-scaffolder-prompt.md; from:T02 what:scripts/verify/spec-shape-lint.sh; from:T03 what:scripts/util/dual-write-runtime-md.sh + dual_write_agents config key; from:T04 what:scripts/knowledge/spec-complexity-probe.sh stub, from:P01/T01 what:spec-template.md+expected-section-headings.txt+specify-fixture-prose.txt; from:P01/T02 what:spec-shape-lint.sh; from:P01/T05 what:specify.sh, from:P01/T01..T06 what:twelve upstream gate scripts; from:disk what:anti-pattern-lint.sh,m021-prompt-corpus.txt"
affects:
  - "T02 spec-shape-lint derives required-section list from template; T05 specify.sh copies template; T06 FR-18 byte-compat fixture test; T07 phase-suite runs gate verifier, scripts/verify, P02 (adds call sites to this helper), T05 (specify.sh wires probe call, no-ops on below-threshold); M009 runtime-parity audit (consumes RUNTIME-ASSUMPTIONS.md), T06 (phase-suite consumer of T05 artifacts); T07 (consolidation reads scaffold contract); M014/P02-P04 (full FR-14 amend semantics + scaffolder LLM round-trip + complexity probe full logic), tests,references,scripts/verify, scripts/verify"
key_files:
  - "templates/spec-template.md,templates/spec-scaffolder-prompt.md,tests/fixtures/m014-p01/expected-section-headings.txt,tests/fixtures/m014-p01/specify-fixture-prose.txt,scripts/verify/m014-p01-template-ssot.sh, scripts/verify/spec-shape-lint.sh,scripts/verify/m014-p01-spec-shape-lint.sh, scripts/util/dual-write-runtime-md.sh,tests/test-dual-write-outside-invariant.sh,scripts/verify/m014-p01-dual-write-helper.sh,scripts/verify/m014-p01-dual-write-outside-invariant.sh,scripts/verify/m014-p01-config-keys.sh,.orchestrator/config.yml, scripts/knowledge/spec-complexity-probe.sh,RUNTIME-ASSUMPTIONS.md,scripts/verify/m014-p01-complexity-probe-stub.sh,scripts/verify/m014-p01-runtime-assumptions.sh, commands/specify.md,scripts/specify/specify.sh,.orchestrator/config.yml,scripts/verify/m014-p01-specify-command.sh,scripts/verify/m014-p01-specify-sh.sh,scripts/verify/m014-p01-agents-md-shape.sh, tests/test-specify-shape.sh,references/spec-management.md,references/README.md,scripts/verify/m014-p01-specify-shape-test.sh,scripts/verify/m014-p01-spec-management-reference.sh, scripts/verify/m014-p01-bash32-compat.sh,scripts/verify/m014-p01-zero-prompts.sh,scripts/verify/m014-p01-phase-suite.sh"
key_decisions:
  - "Followed verbatim plan bodies; no deviations in section ordering or placeholder syntax; template uses double-brace placeholder syntax plus TODO bracketed blocks per MEM013 and T02 linter contract, order-check-advisory,top-level-section-presence-only, D016, D016"
patterns_established:
  - "Template SSOT plus ground-truth heading fixture; verifier extracts headings via grep -E and diffs against expected fixture file, template-derived-required-section-list,loose-heading-presence-match, marker-bounded atomic splice with byte-preserved outside region; dual_write_agents gate as runtime toggle; --dry-run JSONL FR-19 manifest shape, P01-stub-with-stable-structured-fields (probe emits below-threshold + zero-valued fr_count/user_story_count/todo_count/contradiction_signals so P04 replaces body without changing caller); D016 append-only runtime-assumptions registry with four-subsection entry schema (Claude Code assumption / Codex-Cursor fallback / Milestone-phase / M009 obligation), subcommand-surface-with-deferred-body -- amend+split stubs print diagnostics and exit 0 or 2 while full semantics land in a later phase; slug-collision-scan-separate-from-number-allocation -- slug match across all NNN-SLUG dirs produces collision; number allocation is max+1 independent; dual-write-fallback-on-dual_write_agents-false -- try both files then fall back to CLAUDE.md-only with the count reflected in dual_writes observability field, __PLACEHOLDER__ normalization for heading byte-match across scaffolded substitutions; BSD-vs-GNU sed no-i portability pattern; hermetic scratch test pattern for specify.sh dispatch, verifier self-exemption for rule-embedding gates (precedent M016/P03); awk-INPUT-extraction for [M021](../../../../milestones/M021/index.md) corpus parse (vs naive line-grep)"
drill_down_paths:
  - ".orchestrator/milestones/M014/phases/P01/tasks/T01-SUMMARY.md, .orchestrator/milestones/M014/phases/P01/tasks/T02-SUMMARY.md, .orchestrator/milestones/M014/phases/P01/tasks/T03-SUMMARY.md, .orchestrator/milestones/M014/phases/P01/tasks/T04-SUMMARY.md, .orchestrator/milestones/M014/phases/P01/tasks/T05-SUMMARY.md, .orchestrator/milestones/M014/phases/P01/tasks/T06-SUMMARY.md, .orchestrator/milestones/M014/phases/P01/tasks/T07-SUMMARY.md"
duration: "157m"
verification_result: "pass"
completed_at: "2026-04-22T20:58:46Z"
observability_surfaces:
  - "execution-log.jsonl"
---

## What Was Built

P01 ships the load-bearing foundation for native `orchestrator:specify` — the command that every future milestone's spec will scaffold through. Seven tasks, 35 new files, zero failing gates across a 14-gate phase suite.

**Core surface**:
- `commands/specify.md` — user-facing command with `specify`, `--amend` (deferral stub), and `split` (hard stub) subcommands.
- `scripts/specify/specify.sh` — Bash 3.2 implementation. `--description <prose> --slug <slug> --yes` resolves next `NNN`, copies `templates/spec-template.md` into `specs/<NNN>-<slug>/spec.md` with placeholder substitution, calls the FR-5 probe (no-ops on `below-threshold`), dual-writes a Recent Changes entry to CLAUDE.md + AGENTS.md, emits `unit_close` JSONL.
- `templates/spec-template.md` — the Section Contract SSOT. Every FR-2 heading in required order with bracketed `<TODO: ...>` placeholders.
- `templates/spec-scaffolder-prompt.md` — FR-3 CC LLM round-trip prompt. Surface only; invocation deferred (CC-only per CON-2 / D016).

**Load-bearing invariants** (mechanically enforced):
- **SC-6a byte-preservation**: `scripts/util/dual-write-runtime-md.sh` preserves bytes outside the `# >>> orchestrator:<region> >>>` / `# <<< orchestrator:<region> <<<` marker region. `tests/test-dual-write-outside-invariant.sh` asserts `shasum -a 256` equality across repeated writes.
- **Shape contract**: `scripts/verify/spec-shape-lint.sh` derives required sections from `templates/spec-template.md` (SSOT — not hardcoded). Presence is binding; section order is advisory (T02 deviation — documented, with rationale that T01's template-ssot gate enforces order against the template itself).
- **Byte-compat**: `tests/test-specify-shape.sh` exercises the scaffolder end-to-end with deterministic fixture prose, asserts scaffolded headings byte-match the ground-truth fixture (with `__PLACEHOLDER__` normalization for `{{feature_title}}`), asserts `shape=speckit` via M011's detector (SC-2 I/O-contract).

**Deferred surfaces** (authored so downstream phases wire without re-authoring):
- `scripts/knowledge/spec-complexity-probe.sh` — stub emits `probe=below-threshold` unconditionally; structured fields (`fr_count`, `user_story_count`, `todo_count`, `contradiction_signals`) all zero. P04 replaces the body without changing the caller contract.
- `RUNTIME-ASSUMPTIONS.md` registry — D016 scaffold with FR-3 + FR-5-stub entries (four-subsection schema: Claude Code assumption / Codex-Cursor fallback / Milestone-phase / M009 obligation). Append-only; P03/P04 add entries.
- `references/spec-management.md` — partial (Section Contract + marker convention + FR-19 dry-run manifest shape); `<!-- partial: P04 -->` sentinel. P04 completes with pressure-test + decomposition sections.
- `commands/specify.md --amend` — diagnostic deferral, exit 0. Full FR-14 three-case semantics land in P04 (depends on full probe).
- `commands/specify.md split` — diagnostic deferral, exit 2. Full decomposition lands in P04.

**Configuration**:
- `.orchestrator/config.yml` additive: `dual_write_agents: true` (top-level) + `specify:` section with all-zero complexity thresholds (P04 tunes via calibration corpus).

## Key Decisions

- **Dual-write shape: byte-identical** between `CLAUDE.md` and `AGENTS.md`, not transform-based. AGENTS.md has no runtime header; first marker is line 1. Transform-based shape remains open for later phases if FR-13 drift-detector findings justify it.
- **Slug collision: loud error** without `--force`. Collision scan matches across all `specs/*-<slug>/` directories (not just the resolved `NNN-<slug>` path — T05 deviation, caught the original logic being unreachable).
- **Number allocation**: `max(existing NNN prefix) + 1`, decoupled from slug-collision check.
- **Scaffolder prompt**: surface-only in P01. LLM round-trip deferred. Skeleton specs are the P01 product; LLM-populated first-pass prose lands later.
- **Order advisory**: `spec-shape-lint.sh` treats heading presence as hard, order as advisory (T02 deviation; T01's template-ssot is the strict-order gate against the template).
- **Stub→full transition contract**: P01 stub of complexity-probe emits stable structured fields with zero values; P04 replaces the body without changing output shape or caller wiring.

## Cross-Cutting Patterns Established

- **Template SSOT with ground-truth fixture**: `scripts/verify/m014-p01-template-ssot.sh` extracts headings from the template via `grep -E`, diffs against `tests/fixtures/m014-p01/expected-section-headings.txt`. Any drift fails the gate.
- **Template-derived required-section list**: `spec-shape-lint.sh` reads the template at runtime rather than hardcoding. Future template changes propagate automatically.
- **Marker-bounded atomic splice with byte-preserved outside region**: pattern inherited from M012/P04 `mkdocs.yml` splice; mechanically enforced by `shasum -a 256` equality of outside bytes.
- **Subcommand surface with deferred body**: `--amend` and `split` ship as subcommands that print diagnostics and exit at distinct codes (0 vs 2). Full semantics land in P04 without command-file re-authoring.
- **Hermetic scratch project pattern**: `tests/test-specify-shape.sh` sets up a temp workdir, runs `specify.sh` against it, asserts behavior without polluting the live `specs/` tree.
- **Verifier self-exemption for rule-embedding gates**: `m014-p01-bash32-compat.sh` self-exempts because its diagnostic strings and regexes match the patterns it scans for (precedent: M016/P03 `lint-self-excludes.sh`).
- **`awk`-field extraction for structured corpus parse**: M021 prompt-corpus is `---`-separated with `ID:` / `INPUT:` / `EXPECTED_OUTCOME:` fields — `awk '/^INPUT: /'` extraction beats naive line-grep (T07 deviation caught this).

## Verification Results

- **T07 phase suite**: 14 gates, all PASS, exit 0.
  - T01 template-ssot, T02 spec-shape-lint, T03 dual-write-helper + outside-invariant + config-keys, T04 complexity-probe-stub + runtime-assumptions, T05 specify-command + specify-sh + agents-md-shape, T06 specify-shape-test + spec-management-reference, T07 bash32-compat + zero-prompts.
- **SC-2 I/O-contract**: `scripts/knowledge/detect-spec-shape.sh` (M011) reports `shape=speckit` on scaffolded specs — passes byte-compat test.
- **SC-6a byte-preservation**: `tests/test-dual-write-outside-invariant.sh` asserts `shasum -a 256` equality across repeated helper invocations.
- **FR-19 dry-run manifest**: `--dry-run` emits JSONL records with `{command, action_type, target_path, source_ref, description}` — zero disk writes.
- **CON-6 anti-pattern lint**: every new shell script passes `scripts/verify/anti-pattern-lint.sh` (no Class A/B patterns).
- **MEM001 Bash 3.2 compat**: `m014-p01-bash32-compat.sh` scan of all P01-shipped scripts — no `declare -A`, no `mapfile`, no `${var,,}`, no process substitution, no `&>`.
- **CON-3 zero-prompts**: `m014-p01-zero-prompts.sh` verifies `--yes` + `--dry-run` surface + M021 prompt-corpus cross-check.

## Deviations Worth Surfacing

Four task-level deviations from verbatim plan bodies, all correctness fixes with documented rationale in individual task summaries:

1. **T02**: order-strictness downgraded from hard-fail to advisory — authored specs predate template, strict-order-on-authored-specs tension is resolved by keeping template-strict-order enforcement in T01's gate and authored-spec shape-check on presence only.
2. **T03**: dropped spurious `print ""` blank-line in marker-insert awk block — verbatim body would have violated the SC-6a invariant this task ships a test for.
3. **T05**: slug collision scan widened beyond the unreachable `NNN-<slug>` path — original verbatim logic always evaluated false.
4. **T06**: `$( ... || true)` subshell rc-capture bug fixed (rc always 0 with `|| true`); BSD/GNU sed portability simplified.

No deviations affected cross-task contracts or downstream phase scope.

## Dogfood Artifacts Remaining On Disk (From T05 Live Run)

An accidental live-repo run of `specify.sh` during T05 debugging left two artifacts:
- `CLAUDE.md` top-of-file marker region with stale entry `- 021-test-exporter: foo`
- `AGENTS.md` created with the same stale entry

These are intentional dogfood state — they make `m014-p01-agents-md-shape.sh` testable against the live repo rather than hermetic fixtures. Operator discretion on whether to retain or revert; scope boundary to resolve is P02's responsibility (that phase extends dual-write sites). The `specs/021-test-exporter/` scratch directory was fully cleaned up.

## Ready for P02, P03, P04

All four downstream phases of M014 depend only on P01. Dependency graph: P01 → {P02, P03, P04}, no cross-dependencies among P02/P03/P04. P03 has an additional external preflight ([M012](../../../../milestones/M012/index.md) wiki DEPLOY-RECORD sentinels must resolve) — that's operator-gated and runs in parallel with P02/P04 dispatch.

## Task Plan

---
schema_version: "1.0"
task: "T01"
phase: "P03"
milestone: "M014"
name: "Comment fetcher + idempotency log (FR-8, CON-8)"
depends_on: []
---

## Prerequisites

- [M013](../../../../milestones/M013/index.md) has shipped — `scripts/integrations/github-common.sh` exists with `gh` invocation helpers and orchestrator-id-marker conventions. T01 reads from this file's contract; it does not modify it.
- M012 has shipped — `scripts/wiki/wiki-giscus-remap.sh` provides Discussion → spec-chunk pathname-keyed thread mapping. T01 consumes via shellout.
- `gh` CLI is operator-installed and authenticated when this script runs against the live repo. Verifier exercises hermetic stub path (PATH-prefixed `gh` shim under scratch) — never invokes the real `gh` binary.
- `.orchestrator/comments/` directory does not yet exist; T01 creates it on first run.

## Description

T01 ships `scripts/comments/fetch.sh` — the comment fetcher (FR-8). Behavior:

1. Enumerate unactioned comments from two surfaces:
   - **Giscus Discussions** on the wiki: `gh api graphql` query against the M012-shipped Discussions category, filtered to comment-bearing threads keyed to spec-chunk pathnames.
   - **GitHub Issue/PR comments**: `gh api repos/<owner>/<repo>/issues/comments` (and `/pulls/comments`) for orchestrator-id-marker-bearing Issue/PR threads.
2. For each fetched comment, compute the idempotency key as `URL || shasum(body)` (URL is the canonical part; body shasum is a fallback when URL fragments collide).
3. Skip any comment whose URL is already present in `.orchestrator/comments/actioned.jsonl` (one JSONL row per actioned comment with `comment_url`, `actioned_at`, `class`, `applied`).
4. Cache each new comment to `.orchestrator/comments/inbox/<comment-id>.json` with fields `{url, body, source_surface, fetched_at, body_shasum, anchor_chunk_id (optional)}`.
5. Support `--dry-run`: print FR-19 JSONL action records to stdout (one per comment that would be cached) without disk writes.
6. Support `--yes`: auto-resolve any interactive prompt to the conservative default (none planned in T01; the flag is honored as inheritance from CON-3).
7. Emit a `unit_close` JSONL record at exit with `{command: "comments fetch", comments_fetched: N, comments_skipped: M, source_surfaces: ["giscus","github"], elapsed_ms, source: "runtime"}`.

The fetcher does NOT classify, queue, or apply — it is a pure cache primer.

## Steps

1. **Create `scripts/comments/fetch.sh`** with this skeleton (Bash 3.2, AD-19-compliant, no inline compounds beyond `&&`/`||` of two commands):

   ```bash
   #!/usr/bin/env bash
   # scripts/comments/fetch.sh
   # FR-8 comment fetcher — Giscus + GitHub Issue/PR.
   # Bash 3.2 compatible. CON-8 idempotent via actioned.jsonl.
   set -u

   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   PROJECT_ROOT="${ORCHESTRATOR_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
   ORCH_ROOT="${PROJECT_ROOT}/.orchestrator"
   INBOX_DIR="${ORCH_ROOT}/comments/inbox"
   ACTIONED_LOG="${ORCH_ROOT}/comments/actioned.jsonl"
   EXEC_LOG="${ORCH_ROOT}/execution-log.jsonl"

   DRY_RUN=0
   YES=0
   while [ $# -gt 0 ]; do
     case "$1" in
       --dry-run) DRY_RUN=1 ;;
       --yes) YES=1 ;;
       --help|-h) sed -n '2,15p' "$0"; exit 0 ;;
       *) printf 'FAIL: unknown arg %s\n' "$1" >&2; exit 2 ;;
     esac
     shift
   done

   mkdir -p "$INBOX_DIR"
   touch "$ACTIONED_LOG"

   _start_ms="$(date +%s)"
   _fetched=0
   _skipped=0

   # ... see Step 2 for surface-specific fetchers ...

   _elapsed_ms=$(( ( $(date +%s) - _start_ms ) * 1000 ))
   if [ "$DRY_RUN" -eq 0 ]; then
     printf '{"event":"unit_close","command":"comments fetch","comments_fetched":%d,"comments_skipped":%d,"source_surfaces":["giscus","github"],"elapsed_ms":%d,"source":"runtime"}\n' \
       "$_fetched" "$_skipped" "$_elapsed_ms" >> "$EXEC_LOG"
   fi
   printf 'SUMMARY: comments fetch fetched=%d skipped=%d\n' "$_fetched" "$_skipped"
   ```

2. **Implement the surface-specific fetchers** as helper functions:

   ```bash
   _fetch_github() {
     # Iterate gh api repos/<owner>/<repo>/issues/comments + /pulls/comments.
     # Filter to comments whose body contains an orchestrator-id marker
     # (per M013/scripts/integrations/github-common.sh convention).
     # Honor GH_API_STUB env var for hermetic testing — when set, read from
     # the file path it points at instead of calling gh.
     local _src
     if [ -n "${GH_API_STUB:-}" ] && [ -f "${GH_API_STUB}" ]; then
       _src="${GH_API_STUB}"
     else
       command -v gh >/dev/null 2>&1 || { printf 'WARN: gh not installed; skipping github surface\n' >&2; return 0; }
       _src="$(mktemp)"
       gh api repos/:owner/:repo/issues/comments --paginate > "$_src" 2>/dev/null || true
     fi
     # ... parse JSON, write to inbox, increment counters ...
   }

   _fetch_giscus() {
     # Iterate gh api graphql against Discussions.
     # Honor GH_GRAPHQL_STUB env var for hermetic testing.
     local _src
     if [ -n "${GH_GRAPHQL_STUB:-}" ] && [ -f "${GH_GRAPHQL_STUB}" ]; then
       _src="${GH_GRAPHQL_STUB}"
     else
       command -v gh >/dev/null 2>&1 || { printf 'WARN: gh not installed; skipping giscus surface\n' >&2; return 0; }
       _src="$(mktemp)"
       gh api graphql -f query='query { repository(owner:":owner",name:":repo"){ discussions(first:100){ nodes { id url comments(first:50){ nodes { id url body createdAt } } } } } }' > "$_src" 2>/dev/null || true
     fi
     # ... parse JSON, write to inbox, increment counters ...
   }
   ```

   For JSON parsing under Bash 3.2 with no jq dependency hard-required, use `awk`-based extraction of the load-bearing fields (`url`, `body`, `id`). If `jq` is on PATH, prefer `jq` (operator-installed convenience). Fall back to awk for the hermetic verifier path.

   The full function bodies parse one comment per JSON object, compute the body shasum, check `actioned.jsonl` for the URL, and either skip (incrementing `_skipped`) or write `<inbox>/<comment-id>.json` with the full record (incrementing `_fetched`). On `--dry-run`, the same iteration runs but prints FR-19 JSONL records to stdout instead of writing to inbox:
   `{"command":"comments fetch","action_type":"cache-comment","target_path":"<inbox-path>","source_ref":"<url>","description":"would cache comment from <surface>"}`

3. **Implement the actioned.jsonl skip check** as a helper:

   ```bash
   _is_actioned() {
     # _is_actioned <url>
     # Returns 0 if the URL appears in actioned.jsonl, 1 otherwise.
     local _url="$1"
     [ -f "$ACTIONED_LOG" ] || return 1
     grep -F -- "\"comment_url\":\"$_url\"" "$ACTIONED_LOG" >/dev/null 2>&1
   }
   ```

   Use `grep -F` (literal) for performance and correctness on URLs containing regex metacharacters.

4. **Make the script executable**:

   ```bash
   chmod +x scripts/comments/fetch.sh
   ```

5. **Create test fixtures** under `tests/fixtures/m014-p03/`:

   - `sample-inbox.jsonl` — 4 fake comments (one per FR-9 class). Used by T02 + downstream tasks; T01 also uses it as the GH_API_STUB target for one of the verifier cases. Format: one JSON object per line with `url`, `body`, `source_surface`, `id`, `created_at` fields. Example seed lines:
     ```
     {"url":"https://github.com/Build-Fractal/orchestrator/issues/1#issuecomment-1","body":"acceptance criterion 2 fails on macOS 13","source_surface":"github","id":"c1","created_at":"2026-04-24T00:00:00Z"}
     {"url":"https://github.com/Build-Fractal/orchestrator/issues/2#issuecomment-2","body":"decision: we should pin Bash 3.2 across all scripts","source_surface":"github","id":"c2","created_at":"2026-04-24T00:01:00Z"}
     {"url":"https://github.com/Build-Fractal/orchestrator/discussions/3#discussioncomment-3","body":"FR-5 should also cover token-density measurement","source_surface":"giscus","id":"c3","created_at":"2026-04-24T00:02:00Z"}
     {"url":"https://github.com/Build-Fractal/orchestrator/discussions/4#discussioncomment-4","body":"hmm not sure about this approach","source_surface":"giscus","id":"c4","created_at":"2026-04-24T00:03:00Z"}
     ```

6. **Create `scripts/verify/m014-p03-fetch.sh`** as the T01 verifier (single-script-file shape, Bash 3.2):

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m014-p03-fetch.sh
   # Verifies M014/P03/T01: comment fetcher + idempotency.
   set -u

   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   FETCHER="${REPO_ROOT}/scripts/comments/fetch.sh"
   FIXTURE="${REPO_ROOT}/tests/fixtures/m014-p03/sample-inbox.jsonl"

   pass=0; fail=0
   _pass() { pass=$((pass+1)); echo "PASS: $1"; }
   _fail() { fail=$((fail+1)); echo "FAIL: $1"; }

   SCRATCH="$(mktemp -d)"
   trap 'rm -rf "$SCRATCH"' EXIT
   mkdir -p "$SCRATCH/.orchestrator/comments"
   touch "$SCRATCH/.orchestrator/execution-log.jsonl"

   # Case A: Hermetic fetch via stub — fixture fed as GH_API_STUB; expect 4 inbox files.
   ORCHESTRATOR_PROJECT_ROOT="$SCRATCH" \
   GH_API_STUB="$FIXTURE" \
   GH_GRAPHQL_STUB="$FIXTURE" \
     bash "$FETCHER" --yes > "$SCRATCH/run-a.out" 2>&1
   rc_a=$?
   if [ "$rc_a" = "0" ]; then _pass "Case A: fetch exits 0 with stub"; else _fail "Case A: rc=$rc_a"; fi
   if grep -q "fetched=4" "$SCRATCH/run-a.out"; then _pass "Case A: SUMMARY reports fetched=4"; else _fail "Case A: SUMMARY missing fetched=4 (out: $(cat $SCRATCH/run-a.out))"; fi
   inbox_count=$(ls -1 "$SCRATCH/.orchestrator/comments/inbox/" 2>/dev/null | wc -l | tr -d ' ')
   if [ "$inbox_count" = "4" ]; then _pass "Case A: 4 inbox files written"; else _fail "Case A: inbox count=$inbox_count, expected 4"; fi
   if grep -q '"event":"unit_close"' "$SCRATCH/.orchestrator/execution-log.jsonl"; then _pass "Case A: unit_close emitted"; else _fail "Case A: unit_close missing"; fi

   # Case B: Idempotency — seed actioned.jsonl with one URL, re-fetch, expect skipped=1 fetched=3.
   echo '{"comment_url":"https://github.com/Build-Fractal/orchestrator/issues/1#issuecomment-1","actioned_at":"2026-04-24T00:00:00Z","class":"uat-bug","applied":true}' > "$SCRATCH/.orchestrator/comments/actioned.jsonl"
   rm -rf "$SCRATCH/.orchestrator/comments/inbox"
   ORCHESTRATOR_PROJECT_ROOT="$SCRATCH" \
   GH_API_STUB="$FIXTURE" \
   GH_GRAPHQL_STUB="$FIXTURE" \
     bash "$FETCHER" --yes > "$SCRATCH/run-b.out" 2>&1
   if grep -q "fetched=3 skipped=1" "$SCRATCH/run-b.out"; then _pass "Case B: idempotency skip on actioned URL"; else _fail "Case B: expected fetched=3 skipped=1 (out: $(cat $SCRATCH/run-b.out))"; fi

   # Case C: --dry-run emits FR-19 JSONL to stdout, no inbox writes.
   rm -rf "$SCRATCH/.orchestrator/comments/inbox"
   rm -f "$SCRATCH/.orchestrator/comments/actioned.jsonl"
   touch "$SCRATCH/.orchestrator/comments/actioned.jsonl"
   ORCHESTRATOR_PROJECT_ROOT="$SCRATCH" \
   GH_API_STUB="$FIXTURE" \
   GH_GRAPHQL_STUB="$FIXTURE" \
     bash "$FETCHER" --yes --dry-run > "$SCRATCH/run-c.out" 2>&1
   if grep -q '"action_type":"cache-comment"' "$SCRATCH/run-c.out"; then _pass "Case C: dry-run emits FR-19 manifest"; else _fail "Case C: missing dry-run JSONL"; fi
   inbox_dry=$(ls -1 "$SCRATCH/.orchestrator/comments/inbox/" 2>/dev/null | wc -l | tr -d ' ')
   if [ "$inbox_dry" = "0" ]; then _pass "Case C: dry-run no inbox writes"; else _fail "Case C: dry-run wrote $inbox_dry files"; fi

   echo "----"
   echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   echo "PASS: $(basename "$0")"
   exit 0
   ```

7. **Run the verifier**:

   ```bash
   bash scripts/verify/m014-p03-fetch.sh
   ```

   Expected:
   ```
   ----
   SUMMARY: m014-p03-fetch.sh pass=8 fail=0
   PASS: m014-p03-fetch.sh
   ```

## Must-Haves

Addresses phase must-haves:
- "Truth: fetch.sh enumerates unactioned comments + writes inbox + skips actioned URLs + dry-run FR-19 manifest"
- Artifacts: `scripts/comments/fetch.sh`, `scripts/verify/m014-p03-fetch.sh`, `tests/fixtures/m014-p03/sample-inbox.jsonl`

## Verification

```
bash scripts/verify/m014-p03-fetch.sh
```

Must exit 0 with `PASS: m014-p03-fetch.sh`.

## Inputs

### From Previous Tasks

None — T01 is independent within P03.

### From Disk (Pre-existing)

- `scripts/integrations/github-common.sh` (M013/P04) — orchestrator-id marker convention reference. T01 does not modify it.
- `scripts/wiki/wiki-giscus-remap.sh` (M012) — Giscus Discussion → spec-chunk thread mapping. T01 reads behavior contract; does not modify.
- `.orchestrator/execution-log.jsonl` — append target for unit_close emission.

## Constraints

- **CON-6 / MEM001**: Bash 3.2; no `declare -A`, no `mapfile`, no `${var,,}`, no process substitution, no `&>`. Verifier asserts via `m014-p03-bash32-and-lint.sh` (T05 omnibus).
- **CON-3 / SC-7**: `--yes` resolves all interactive prompts to documented defaults; verifier seeds `--yes` on every invocation.
- **CON-8**: idempotent — re-running fetch never duplicates inbox files; URL+shasum is the dedup key against `actioned.jsonl`.
- **D007 reuse**: T01 does NOT modify `scripts/dispatch/adapters/tool/conversus.sh`. Conversus integration belongs to T02 (ambiguous-routing).
- **AD-19**: every `Check:` in this plan is `bash scripts/verify/m014-p03-<name>.sh`. The verifier itself uses no inline compounds beyond two-command `&&`/`||`.

## Expected Output

- `scripts/comments/fetch.sh` created (~120-160 lines).
- `tests/fixtures/m014-p03/sample-inbox.jsonl` created (~4-6 lines).
- `scripts/verify/m014-p03-fetch.sh` created (~80-100 lines).
- `bash scripts/verify/m014-p03-fetch.sh` exits 0, prints `SUMMARY: ... pass=8 fail=0` and `PASS: m014-p03-fetch.sh`.

## State Context

- **Current State**: executing
- **Milestone**: M014
- **Phase**: P03
- **Task**: T01-fetch
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **CON-6 / MEM001**: Bash 3.2; no `declare -A`, no `mapfile`, no `${var,,}`, no process substitution, no `&>`. Verifier asserts via `m014-p03-bash32-and-lint.sh` (T05 omnibus).
- **CON-3 / SC-7**: `--yes` resolves all interactive prompts to documented defaults; verifier seeds `--yes` on every invocation.
- **CON-8**: idempotent — re-running fetch never duplicates inbox files; URL+shasum is the dedup key against `actioned.jsonl`.
- **D007 reuse**: T01 does NOT modify `scripts/dispatch/adapters/tool/conversus.sh`. Conversus integration belongs to T02 (ambiguous-routing).
- **AD-19**: every `Check:` in this plan is `bash scripts/verify/m014-p03-<name>.sh`. The verifier itself uses no inline compounds beyond two-command `&&`/`||`.

### Acceptance Criteria

Addresses phase must-haves:
- "Truth: fetch.sh enumerates unactioned comments + writes inbox + skips actioned URLs + dry-run FR-19 manifest"
- Artifacts: `scripts/comments/fetch.sh`, `scripts/verify/m014-p03-fetch.sh`, `tests/fixtures/m014-p03/sample-inbox.jsonl`

### Files To Touch

- scripts/comments/fetch.sh (create)
- scripts/comments/classify.sh (create)
- scripts/comments/apply.sh (create)
- scripts/comments/reject.sh (create)
- scripts/comments/triage.sh (create)
- scripts/comments/comments.sh (create)
- commands/comments.md (create)
- scripts/verify/m014-p03-fetch.sh (create)
- scripts/verify/m014-p03-classify.sh (create)
- scripts/verify/m014-p03-commands-md.sh (create)
- scripts/verify/m014-p03-apply.sh (create)
- scripts/verify/m014-p03-reject-triage.sh (create)
- scripts/verify/m014-p03-spec-amendment-human-gate.sh (create)
- scripts/verify/m014-p03-pipeline.sh (create)
- scripts/verify/m014-p03-observability.sh (create)
- scripts/verify/m014-p03-config-keys.sh (create)
- scripts/verify/m014-p03-references-section.sh (create)
- scripts/verify/m014-p03-dogfood-capture.sh (create)
- scripts/verify/m014-p03-bash32-and-lint.sh (create)
- scripts/verify/m014-p03-zero-prompts.sh (create)
- scripts/verify/m014-p03-phase-suite.sh (create)
- specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md (create)
- references/spec-management.md (modify — append "Comment Classification" section)
- .orchestrator/config.yml (modify — add comments: section)
- tests/fixtures/m014-p03/sample-inbox.jsonl (create)
- tests/fixtures/m014-p03/queued-amendment.md (create)
- CLAUDE.md (modify — RC region only via dual-write)
- AGENTS.md (modify — RC region only via dual-write)
- [.orchestrator/milestones/M014/phases/P03/P03-SUMMARY.md](../../../../milestones/M014/phases/P03/P03-SUMMARY.md) (create at phase close)

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