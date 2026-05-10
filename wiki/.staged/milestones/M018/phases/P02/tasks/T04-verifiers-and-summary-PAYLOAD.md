---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T04-verifiers-and-summary (Phase P02, Milestone M018)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-978 | ~600 | required |
| Upstream Context | 980-1061 | ~2100 | required |
| Task Plan | 1063-1264 | ~4400 | required |
| State Context | 1266-1272 | ~100 | required |
| First-Turn Completeness | 1274-1313 | ~700 | required |
| **Total** | | **~18700** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 612
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
hit_count: 612
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
hit_count: 612
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
hit_count: 612
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
hit_count: 542
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
hit_count: 542
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
hit_count: 542
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
hit_count: 612
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
hit_count: 542
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
hit_count: 542
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
hit_count: 542
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
hit_count: 612
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
hit_count: 612
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
hit_count: 612
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
hit_count: 542
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
hit_count: 542
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
hit_count: 542
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
hit_count: 612
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
hit_count: 542
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
hit_count: 542
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
hit_count: 612
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
hit_count: 612
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
hit_count: 542
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
hit_count: 542
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
hit_count: 542
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
hit_count: 197
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
hit_count: 197
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
hit_count: 197
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
hit_count: 188
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
hit_count: 188
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
hit_count: 178
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

<!-- Per AD-19, every Check is a single-script-file invocation. No inline
     compound bash, no plain subshells, no $(... | ...) containing pipes.
     See commands/plan-phase.md for the full forbidden-shape enumeration. -->

- `scripts/dispatch/build-context.sh` reads each knowledge entry's `status:` field and excludes entries whose value matches the configured drop-list (`compression.knowledge_filter.drop_list`, default `["superseded", "experimental"]`) before payload assembly. Entries without a `status:` field default to `stable` and are never dropped (FR-3 back-compat per A-1).
  - Check: `bash scripts/verify/m018-p02-filter-drops.sh`

- When the filter drops at least one entry, a `payload_filter` JSONL record is appended to `execution-log.jsonl` naming `{filter, drop_list, dropped_count, dropped_tokens, dropped_ids, source: runtime}`; the existing `payload_breakdown` record carries an additive `filter_dropped_tokens` field. Pre-M018 records remain valid JSON (CON-5 — additive emitter).
  - Check: `bash scripts/verify/m018-p02-emitter-additivity.sh`

- The preservation-contract self-check library `scripts/lib/preservation-check.sh` exposes `pres_check_section` (regex-driven pattern walker that compares pre- and post-transform byte spans for every preserved-pattern row from `references/compression-grammar.md` `## Preserved-Pattern Vocabulary`), `pres_emit_violation` (writes `tier_preservation_violation` JSONL), and `pres_density_pre_check` (refuses tier3 invocation when input density exceeds the configured threshold per MIT-08). Library is bash 3.2 compatible, sourceable, and pure (no global writes other than the named emitter).
  - Check: `bash scripts/verify/m018-p02-preservation-check-api.sh`

- The aggregate-savings self-check emits a `compression_underperformance` JSONL record when the running mean payload-token reduction across the last N dispatches falls below the SC-9 calibrated 34.7% floor (MIT-09). The check is operational signal — never blocks dispatch. The threshold and window are config-driven (`compression.underperformance.window_size`, `compression.underperformance.floor_pct`).
  - Check: `bash scripts/verify/m018-p02-underperformance-emit.sh`

<dispatch-volatile>

## Upstream Context


### P01 Summary
---
schema_version: "1.0"
type: phase-summary
id: P01
parent: M018
milestone: M018
provides: "compression-grammar contract v1.0.1 (Reviewed); compression-grammar lint script; conversus --strict gate verdict (PASS); RUNTIME-ASSUMPTIONS.md M018/P01 entry; six P01-private truth verifiers including m018-p01-conversus-pass.sh; CLAUDE.md/AGENTS.md recent-changes refresh"
requires: "P00 SC-9 calibrated 34.7% floor; P00 per-tier 80% CIs from .orchestrator/scratch/m018-section-distribution-output.json; conversus adapter scripts/dispatch/adapters/tool/conversus.sh (DEP-4)"
affects: "P02 (filter — first tier consumer of the contract; preservation-contract self-check pattern lands here per MIT-10); P03 (T1 microcompact — reuses self-check pattern); P04 (T2 snip — reuses self-check pattern + extended code-fence regex from MIT-01); P06 (T3 auto-compact — gated by MIT-08 LLM-preservation enforcement before unit_close); P05 (eval harness — reads tier_preservation_violation + compression_underperformance JSONL emitters from MIT-09)"
key_files: "references/compression-grammar.md;scripts/verify/compression-grammar-lint.sh;scripts/verify/m018-p01-grammar-shape.sh;scripts/verify/m018-p01-lint-clean.sh;scripts/verify/m018-p01-sc9-traceability.sh;scripts/verify/m018-p01-runtime-assumptions.sh;scripts/verify/m018-p01-conversus-pass.sh;scripts/verify/m018-p01-dual-write-recent.sh;templates/conversus-presets/compression-grammar.yml;[.orchestrator/milestones/M018/phases/P01/conversus/gate-result.md](../../../../../milestones/M018/phases/P01/conversus/gate-result.md);RUNTIME-ASSUMPTIONS.md"
key_decisions: "Adopted P0-only mitigation strategy on first conversus BLOCK (token-economy decision; MIT-01 nested-fence regex + MIT-02 JSONL-in-fenced-code, both single-line edits); deferred P1/P2 mitigations to follow-up cycle via Open Questions deferrals; second gate returned PASS (surviving_disputes=0); captured three new non-gating findings from second deliberation (THREAT-04/08/09) as MIT-08/09/10 P02-entry-gate items rather than blocking P01; advanced grammar status Draft → Reviewed per spec acceptance scenario 3"
patterns_established: "Conversus gate retry pattern at minimal-fix surface area to maximize PASS odds (P0 only, defer P1+ unless gate re-flags); P02-entry-gate documentation pattern via grammar Open Questions section (P02 plan reads OQ before scoping its self-check); HTML-entity-escaped TODO marker pattern (`&lt;TODO:&gt;`) so docs can document a forbidden-marker regex without tripping the conversus pre-flight check"
drill_down_paths: "[.orchestrator/milestones/M018/phases/P01/tasks/T01-grammar-contract-SUMMARY.md](../../../../../milestones/M018/phases/P01/tasks/T01-grammar-contract-SUMMARY.md);[.orchestrator/milestones/M018/phases/P01/tasks/T02-lint-and-runtime-SUMMARY.md](../../../../../milestones/M018/phases/P01/tasks/T02-lint-and-runtime-SUMMARY.md);[.orchestrator/milestones/M018/phases/P01/tasks/T03-conversus-gate-SUMMARY.md](../../../../../milestones/M018/phases/P01/tasks/T03-conversus-gate-SUMMARY.md);[.orchestrator/milestones/M018/phases/P01/conversus/gate-result.md](../../../../../milestones/M018/phases/P01/conversus/gate-result.md);[.orchestrator/milestones/M018/phases/P01/conversus/summary/final.md](../../../../../milestones/M018/phases/P01/conversus/summary/final.md)"
duration: "~3h"
verification_result: pass
observability_surfaces: none
completed_at: "2026-04-27T00:00:00Z"
---

# Phase Summary: M018/P01 — Grammar Contract + Conversus Gate

## Closure summary

P01 ships the versioned tier-by-tier compression-grammar contract that gates the M018 pipeline's downstream phases. `references/compression-grammar.md` (v1.0.1, status: Reviewed) names per-tier `applies-to:` artifact classes, `preserves:` byte-pattern regexes, savings ceilings cited verbatim from P00's 80% CIs, and failure semantics for the FR-2 preservation contract. The conversus `--strict` red/blue advocate gate ran twice — first verdict BLOCK on two P0 grammar bugs, second verdict **PASS** after applying both single-line fixes. P01 closure unblocks P02 (filter — first tier consumer of the contract).

## Conversus gate result

**Verdict**: PASS (surviving_disputes=0). Preset: `compression-grammar` (red-blue mode, charters scoped to the grammar contract, arbiter grounded in constitution Principles II/III/XV). Provider: `claude-code` (mandatory per user policy memory — anthropic 429s are policy gates, not transient).

**First gate (BLOCK, 2026-04-27)**: 10 disputes. Two P0 mitigations gating closure:

- **MIT-01 (THREAT-01)** — code-fence regex `^`{3}[a-zA-Z0-9_-]*$` matched only exactly 3 backticks; nested 4+-backtick fences unprotected. Fix: regex extended to `^`{3,}[a-zA-Z0-9_-]*$`.
- **MIT-02 (THREAT-03)** — JSONL preservation was `.jsonl`-extension-scoped only; didn't protect JSON-shaped lines inside markdown code fences. Fix: JSONL pattern extended to also match complete `{...}` lines inside fenced code blocks of any language tag.

Four P1 mitigations (MIT-03/04/06/07) and one P2 mitigation (MIT-05) were deferred to a follow-up cycle via the contract's Open Questions section. Deferral rationale: arbiter's headline was "proceed with conditions" — non-blocking, and the smaller-surface-area retry maximizes PASS odds.

**Second gate (PASS, 2026-04-27)**: surviving_disputes=0. Three new non-gating findings emerged from deliberation but did not survive scoring; they're captured in the contract's Open Questions as P02-entry-gate items:

- **MIT-08 (P02 entry gate, THREAT-04)** — LLM preservation trust boundary. Tier3's preservation contract is detection-only at the boundary; P02 self-check pattern must include a density pre-check + deterministic fallback to tier2 passthrough on any self-check failure. Re-evaluate before P06 ships tier3.
- **MIT-09 (P02 entry gate, THREAT-08)** — SC-9 threshold operational fragility. P02 ships an aggregate-savings self-check emitting `compression_underperformance` JSONL records when running mean falls below the 34.7% floor.
- **MIT-10 (P02, THREAT-09)** — preservation-contract self-check algorithmic specification: regex-driven pattern walker (one pass per preserved-pattern row) before/after each tier transformation; byte-mismatch on any preserved span triggers passthrough plus `tier_preservation_violation` emission.

## Calibrated threshold defense

Grammar contract's `## Aggregate Plausibility (SC-9)` section cites P00's 80% CIs verbatim:

| Tier   | low      | mean     | high     |
|--------|----------|----------|----------|
| filter | 12.55%   | 13.08%   | 13.67%   |
| tier1  | 6.24%    | 6.31%    | 6.40%    |
| tier2  | 25.33%   | 25.49%   | 25.68%   |
| tier3  | 12.10%   | 12.22%   | 12.36%   |
| **agg**| **34.73%**| **35.08%**| **35.39%**|

The aggregate low (34.73%) defends against the SC-9 calibrated floor (34.7%) under the per-tier modeling assumptions documented verbatim in the probe JSON (`.orchestrator/scratch/m018-section-distribution-output.json` `.model_assumptions` block).

## Risk-mitigation traceability

- **RISK-1 (M018/P00)** → MIT-1 (P00/T01 emitter parity) → P00 closed with 100% parity over 20-dispatch fixture replay.
- **RISK-2 (M018/P00)** → MIT-2 (P00/T02 probe + P00/T03 SC-9 calibration) → SC-9 amended to 34.7% floor in spec.
- **RISK-3 (M018/P01)** → MIT-3 (this phase) → grammar contract reviewed via conversus PASS; downstream phases gate against the contract by mechanical lint + verifier.
- **MIT-08/09/10 (P02 entry gates)** → carried forward into P02-PLAN.md scope; P02 self-check pattern must satisfy them before P02 closes.

## Followups for downstream phases

- **P02 (filter)** consumes the contract's `## Tier: filter` section; establishes the preservation-contract self-check pattern that P03/P04/P06 reuse. Must satisfy MIT-08/09/10 before P02 closes.
- **P03 (tier1)** consumes the contract's `## Tier: tier1` section + tool-result preservation patterns.
- **P04 (tier2)** consumes the contract's `## Tier: tier2` section. The MIT-01 fix (4+-backtick fences) is load-bearing for P04's head-drop boundary detection.
- **P05 (eval harness)** reads `tier_preservation_violation` + `compression_underperformance` JSONL emitters defined per the additive emitter invariants section.
- **P06 (tier3)** consumes the contract's `## Tier: tier3` section. MIT-08 (LLM preservation trust boundary) is a P06 unit_close gate, not a P02 gate.
- **All phases**: pre-bash-shape-guard hook compliance is universal (AP-009).

## Verification result

All P01 truths PASS via `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P01/`. All artifacts present, all key-links resolve. Lint clean. Conversus gate-result.md frontmatter `verdict: "PASS"`.

P01 closed. M018 advances to P02.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P02"
milestone: "M018"
name: "Phase verifiers + dual-write recent-changes + P02-SUMMARY"
depends_on: ["T03"]
---

## Prerequisites

- T01 has landed `scripts/lib/preservation-check.sh`.
- T02 has wired the knowledge filter into `scripts/dispatch/build-context.sh`, added the `compression:` block to `.orchestrator/config.yml` and `templates/config-defaults.yml`, created `tests/fixtures/m018-p02-knowledge-status/`, and captured the baseline golden at `tests/fixtures/m018-p02-baseline-payload.golden.txt`.
- T03 has added the aggregate-savings self-check + `compression.underperformance.*` config keys.
- All three upstream task summaries exist (T01-SUMMARY, T02-SUMMARY, T03-SUMMARY) so the P02-SUMMARY can synthesize from them.
- `scripts/util/dual-write-runtime-md.sh` exists and is the canonical mechanism for mirroring CLAUDE.md edits to AGENTS.md (per CLAUDE.md guidance + AGENTS.md dual-write convention from M014/P01 FR-12).

## Description

Ship every phase-truth verifier the P02-PLAN.md `## Truths` section names (six verifiers under `scripts/verify/m018-p02-*.sh`). Refresh the `orchestrator:recent-changes` block in `CLAUDE.md` to name M018/P02; mirror to `AGENTS.md` via the dual-write helper. Write `P02-SUMMARY.md` so the milestone state advances to ready-for-P03.

The verifier set:

1. **`m018-p02-filter-drops.sh`** — verifies the knowledge-aware filter drops drop-list-matching entries; retains missing-status entries (back-compat).
2. **`m018-p02-emitter-additivity.sh`** — verifies the `payload_filter` JSONL record is emitted; the `payload_breakdown` record carries `filter_dropped_tokens`; pre-M018 records remain valid JSON.
3. **`m018-p02-preservation-check-api.sh`** — verifies the T01 library is sourceable, exposes the three required functions, and the `selftest` entry point passes.
4. **`m018-p02-underperformance-emit.sh`** — verifies the underperformance self-check emits a `compression_underperformance` record on a synthetic underperforming log.
5. **`m018-p02-disable-flag-honored.sh`** — verifies `compression.enabled: false` short-circuits the filter; payload Knowledge bytes match the checked-in golden.
6. **`m018-p02-dual-write-recent.sh`** — verifies CLAUDE.md and AGENTS.md `recent-changes` blocks both name M018/P02.

Every verifier is single-script-file shape per AD-19 (no inline compound bash, no plain subshells, no `$(...|...)`), bash 3.2 compatible, exits 0 on PASS, 1 on FAIL with `FAIL:` diagnostics.

## Steps

1. **Author `scripts/verify/m018-p02-filter-drops.sh`**. Shape:

   - Shebang `#!/usr/bin/env bash`, `set -eu`.
   - Resolve `PROJECT_ROOT` (use the same idiom as the M018/P01 verifiers — `cd "$(dirname "$0")/../.."` then `pwd`).
   - Run `bash scripts/dispatch/build-context.sh --fixture tests/fixtures/m018-p02-knowledge-status` against the fixture; redirect stdout to a temp file.
   - Assert the output contains `MEM` IDs from the retained-status entries (2 stable + 1 missing-status = 3 retained MEMs).
   - Assert the output does NOT contain the MEM IDs from the drop-list-matching entries (1 superseded + 1 experimental).
   - The fixture's README documents which MEM IDs are which; the verifier hardcodes the expected retain/drop sets from the fixture (e.g., retain MEM801/802/805, drop MEM803/804).
   - PASS prints `PASS: m018-p02-filter-drops`; FAIL prints `FAIL: <reason>` and exits 1.
   - ~50–80 lines.

2. **Author `scripts/verify/m018-p02-emitter-additivity.sh`**. Shape:

   - Run `bash scripts/dispatch/build-context.sh --fixture tests/fixtures/m018-p02-knowledge-status` against the fixture (or against a fixture's milestone dir directly so `execution-log.jsonl` lands in a known place).
   - Assert the resulting execution log contains a line matching `"record_type":"payload_filter"`.
   - Assert the same log contains a line matching `"record_type":"payload_breakdown"` AND the same line contains `"filter_dropped_tokens"`.
   - Validate JSON-shape additivity: pipe both record types through `python3 -c 'import sys, json; [json.loads(l) for l in sys.stdin]'` if python3 is available; otherwise use a bash-only JSON-shape sniff (assert each line starts with `{` and ends with `}`).
   - Assert there is at least one *pre-M018* `payload_breakdown` record in the historical log under `.orchestrator/milestones/M018/execution-log.jsonl` that does NOT contain `filter_dropped_tokens` and is still well-formed JSON (CON-5 back-compat).
   - PASS / FAIL as above. ~60–90 lines.

3. **Author `scripts/verify/m018-p02-preservation-check-api.sh`**. Shape:

   - Source `scripts/lib/preservation-check.sh` in a child process (NOT in the verifier's own shell — the verifier must remain sourceable-test-isolated). Use `bash -c '. scripts/lib/preservation-check.sh; type pres_check_section pres_emit_violation pres_density_pre_check'`. (Note: this is a single `bash -c` invocation — single command, AP-009 safe; the embedded `. file ; type ...` is two statements separated by `;` which is one compound under the AP-009 limit of 2.)

     **Alternative AP-009-clean shape** (preferred): write a small helper script under `scripts/verify/_helpers/m018-p02-pres-probe.sh` that the verifier invokes as a single command. The helper sources the library and runs `type` checks. This is the cleanest shape — the verifier itself stays a single-script-file invocation.

   - Run `bash scripts/lib/preservation-check.sh selftest`; assert exit 0 + stdout contains `PASS: pres_check_section selftest`.
   - Assert the library file contains the literal `pres_check_section`, `pres_emit_violation`, `pres_density_pre_check` (function definitions).
   - Assert the file contains the `PRES_PATTERNS_REGEX` array declaration (`grep -q 'PRES_PATTERNS_REGEX=(`).
   - PASS / FAIL as above. ~40–60 lines.

4. **Author `scripts/verify/m018-p02-underperformance-emit.sh`**. Shape:

   - Construct a synthetic execution log under a temp dir with 30 `payload_breakdown` records each carrying low `filter_dropped_tokens` (e.g., 5 tokens against 100-token payload — well below the 34.7% floor).
   - Set `ORCH_ROOT` to the temp dir; invoke the underperformance function directly by sourcing build-context's helper logic OR by running build-context end-to-end against a fixture milestone whose log we pre-seed.

     **Recommended approach**: pre-seed `<tmp>/milestones/M999/execution-log.jsonl` with 30 records; run `build-context.sh` against the M999 fixture; assert a new line in `execution-log.jsonl` matches `"record_type":"compression_underperformance"`.

   - Assert the emitted record carries `running_mean_pct` < 34.7 and `floor_pct` = 34.7 and `sample_size` >= 10.
   - PASS / FAIL as above. ~70–100 lines.

5. **Author `scripts/verify/m018-p02-disable-flag-honored.sh`**. Shape:

   - Run `build-context.sh --fixture tests/fixtures/m018-p02-knowledge-status` once with `compression.enabled: true` (default) and capture the Knowledge section.
   - Run again with the disable flag — set via a temporary config override file or via an env var the build-context already honors. The simplest approach: write a temp `.orchestrator/config.yml` with `compression.enabled: false`, point `ORCH_ROOT` at the temp dir, and run.
   - Extract just the Knowledge section from the disabled-run output (`awk '/^## Knowledge/,/^## /'`); diff against `tests/fixtures/m018-p02-baseline-payload.golden.txt`.
   - Assert the diff is empty.
   - Assert the disabled-run's `execution-log.jsonl` contains NO `payload_filter` record.
   - PASS / FAIL as above. ~50–80 lines.

6. **Author `scripts/verify/m018-p02-dual-write-recent.sh`**. Shape:

   - Read CLAUDE.md and AGENTS.md.
   - Use `awk` to extract the `orchestrator:recent-changes` block (between `# >>> orchestrator:recent-changes >>>` and `# <<< orchestrator:recent-changes <<<`) from each.
   - Assert each block contains the literal `M018/P02`.
   - PASS / FAIL as above. ~25–40 lines.

7. **Refresh `CLAUDE.md`** `orchestrator:recent-changes` block. Read the current block; replace its single bullet with two bullets naming P01 close and P02 close. Final shape (the exact wording matches existing P01/P02 phrasing patterns):

   ```
   # >>> orchestrator:recent-changes >>>
   - 030-context-compression-layer / M018/P01: compression-grammar contract v1.0.1 Reviewed; conversus --strict gate PASS.
   - 030-context-compression-layer / M018/P02: knowledge-aware filter live in build-context.sh; preservation-check library shipped; payload_filter + filter_dropped_tokens emitters additive (CON-5); compression_underperformance self-check operational.
   # <<< orchestrator:recent-changes <<<
   ```

   Use `Edit` with `replace_all: false` and a sufficiently unique `old_string` to scope to the block.

8. **Run dual-write to mirror to AGENTS.md**:

   ```
   bash scripts/util/dual-write-runtime-md.sh
   ```

   This is the only mechanism for editing AGENTS.md. Never edit AGENTS.md directly. After the helper runs, AGENTS.md's `orchestrator:recent-changes` block matches CLAUDE.md's.

9. **Write `P02-SUMMARY.md`** at [`.orchestrator/milestones/M018/phases/P02/P02-SUMMARY.md`](../../../../../milestones/M018/phases/P02/P02-SUMMARY.md). Use the existing P01-SUMMARY.md as a shape reference. Frontmatter (15-field base + `observability_surfaces`):

   ```yaml
   ---
   schema_version: "1.0"
   type: phase-summary
   id: P02
   parent: M018
   milestone: M018
   provides: "knowledge-aware injection filter live in scripts/dispatch/build-context.sh; preservation-contract self-check library scripts/lib/preservation-check.sh (sourceable: pres_check_section / pres_emit_violation / pres_density_pre_check); payload_filter JSONL record schema; payload_breakdown.filter_dropped_tokens additive field; compression_underperformance JSONL record (operational signal); compression.knowledge_filter.* + compression.underperformance.* config keys; six P02-private truth verifiers + tests/fixtures/m018-p02-knowledge-status fixture + golden baseline; CLAUDE.md/AGENTS.md recent-changes refresh"
   requires: "P01 grammar contract Reviewed; P00 SC-9 calibrated 34.7% floor; M020 status: field on knowledge entries (DEP-1)"
   affects: "P03 (T1 microcompact — sources scripts/lib/preservation-check.sh; reuses tier_preservation_violation + payload_breakdown schema); P04 (T2 snip — same lib + per-tier savings field); P05 (eval harness — reads compression_underperformance + payload_filter + future tier_preservation_violation records); P06 (T3 auto-compact — wires pres_density_pre_check before LLM call per MIT-08; tier-3-savings field additive)"
   key_files: "scripts/lib/preservation-check.sh;scripts/dispatch/build-context.sh;.orchestrator/config.yml;templates/config-defaults.yml;tests/fixtures/m018-p02-knowledge-status/;tests/fixtures/m018-p02-baseline-payload.golden.txt;scripts/verify/m018-p02-filter-drops.sh;scripts/verify/m018-p02-emitter-additivity.sh;scripts/verify/m018-p02-preservation-check-api.sh;scripts/verify/m018-p02-underperformance-emit.sh;scripts/verify/m018-p02-disable-flag-honored.sh;scripts/verify/m018-p02-dual-write-recent.sh"
   key_decisions: "Filter operates on whole-entry granularity per grammar contract (no interior preservation check); preservation-check library sourced defensively in build-context.sh so P03/P04/P06 inherit a working source path; filter is awk-driven for speed + AP-009 compliance; underperformance check is operational signal (never blocks dispatch); P02-stage logs may legitimately fall below the floor (tier1/2/3 not yet shipped) — handled via min_sample_size guard"
   patterns_established: "Sourceable lib pattern under scripts/lib/ for cross-tier reuse (T01); awk-driven entry-boundary detection in bash 3.2 stream filters (T02); additive JSONL emitter pattern with stats-file handoff between collector and emitter (T02); operational-signal JSONL records that never block dispatch (T03); fixture milestone + golden-payload diff pattern for compression-disabled regression (T02 + T04)"
   drill_down_paths: "[.orchestrator/milestones/M018/phases/P02/tasks/T01-preservation-check-lib-SUMMARY.md](../../../../../milestones/M018/phases/P02/tasks/T01-preservation-check-lib-SUMMARY.md);[.orchestrator/milestones/M018/phases/P02/tasks/T02-knowledge-filter-SUMMARY.md](../../../../../milestones/M018/phases/P02/tasks/T02-knowledge-filter-SUMMARY.md);[.orchestrator/milestones/M018/phases/P02/tasks/T03-underperformance-emitter-SUMMARY.md](../../../../../milestones/M018/phases/P02/tasks/T03-underperformance-emitter-SUMMARY.md);[.orchestrator/milestones/M018/phases/P02/tasks/T04-verifiers-and-summary-SUMMARY.md](../../../../../milestones/M018/phases/P02/tasks/T04-verifiers-and-summary-SUMMARY.md)"
   duration: "<filled at close>"
   verification_result: pass
   observability_surfaces: "execution-log.jsonl: payload_filter record_type, payload_breakdown.filter_dropped_tokens additive field, compression_underperformance record_type"
   completed_at: "<filled at close>"
   ---
   ```

   Body sections:
   - `## Closure summary` — narrative paragraph naming what shipped and the dogfood inflection point.
   - `## Risk-mitigation traceability` — name MIT-08, MIT-09, MIT-10 each with the file/function that satisfies it.
   - `## Followups for downstream phases` — pointers per P03/P04/P05/P06 to the lib/emitter they will reuse.
   - `## Verification result` — `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P02/` exit 0; six P02-private verifiers all PASS.

10. **Run `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P02/`** as the final gate. Expect every truth's Check to pass, every artifact's existence + line count + grep pattern to pass, every key link to resolve.

## Must-Haves

This task addresses the phase truths:

- All six phase-truth Check commands resolve to a script under `scripts/verify/m018-p02-*.sh` and each script exits 0 on a successful M018 build.
- CLAUDE.md and AGENTS.md `recent-changes` blocks both name M018/P02. (Verified by `bash scripts/verify/m018-p02-dual-write-recent.sh`.)
- [`.orchestrator/milestones/M018/phases/P02/P02-SUMMARY.md`](../../../../../milestones/M018/phases/P02/P02-SUMMARY.md) exists with `verification_result: pass` and references all four task summaries.

## Verification

```
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P02/
```

Expected: every truth, artifact, and key link reports PASS. Exit 0. Phase state advances from `executing` to `verifying` on the next `derive-phase.sh` call.

## Inputs

### From Previous Tasks

- `scripts/lib/preservation-check.sh` (from T01)
  - Verified by `m018-p02-preservation-check-api.sh`. The verifier confirms the three function names, the `PRES_PATTERNS_REGEX` array, and the `selftest` entry point.

- `scripts/dispatch/build-context.sh` (modified by T02 + T03)
  - Verified by `m018-p02-filter-drops.sh`, `m018-p02-emitter-additivity.sh`, `m018-p02-disable-flag-honored.sh`, `m018-p02-underperformance-emit.sh` (collectively).

- `tests/fixtures/m018-p02-knowledge-status/` (created by T02)
  - Used as the test substrate for `m018-p02-filter-drops.sh` and `m018-p02-emitter-additivity.sh` and `m018-p02-disable-flag-honored.sh`. Documents which MEM IDs carry which `status:` values; the verifiers hardcode the expected retain/drop sets.

- `tests/fixtures/m018-p02-baseline-payload.golden.txt` (created by T02)
  - The byte-identical baseline `m018-p02-disable-flag-honored.sh` diffs against.

- `.orchestrator/config.yml` (modified by T02 + T03)
  - The `compression:` block T02 added and the `compression.underperformance:` block T03 extended both ship to disk under `.orchestrator/config.yml` and `templates/config-defaults.yml`.

### From Disk (Pre-existing)

- `scripts/util/dual-write-runtime-md.sh` — the canonical dual-write helper. T04 invokes it after editing CLAUDE.md.
- `scripts/verify/check-must-haves.sh` — the phase-level verifier; reads the phase plan's `## Must-Haves` section and runs every Check. T04's last action.
- `templates/phase-summary.md` — the schema source for the P02-SUMMARY frontmatter (15-field base + `observability_surfaces`).
- The existing P01-SUMMARY at [`.orchestrator/milestones/M018/phases/P01/P01-SUMMARY.md`](../../../../../milestones/M018/phases/P01/P01-SUMMARY.md) — shape reference; matches frontmatter / section ordering / risk-mitigation traceability layout.

## Constraints

- **AD-19 single-script-file shape on every verifier**. No inline `( . scripts/lib/foo.sh && fn )` subshells in any verifier. The preservation-check API probe uses a separate helper script under `scripts/verify/_helpers/` if needed (or `bash -c` with sequential statements).
- **AP-009 / pre-bash-shape-guard**. Compound chains > 2 are banned; verifiers use sequential statements + temp files.
- **Bash 3.2 compatibility (MEM001)**. No associative arrays, no `mapfile`, no `[[ =~ ]]` requiring extended flags.
- **AGENTS.md dual-write convention** — T04 edits CLAUDE.md directly, then runs `scripts/util/dual-write-runtime-md.sh`. NEVER edit AGENTS.md directly.
- **No new emitter schema in T04** — the emitter additions all landed in T02 + T03. T04 only verifies them.
- **No regression on the M018/P01 verifier set** — T04's verifiers must coexist with the six M018/P01 verifiers; the `check-must-haves.sh` invocation against the P02 phase dir reads the P02-PLAN.md only and does not interfere with P01's verifier names.

## Expected Output

- Six new files under `scripts/verify/m018-p02-*.sh`, all executable, all bash 3.2 compatible, all AD-19 / AP-009 compliant.
- `CLAUDE.md` updated `orchestrator:recent-changes` block.
- `AGENTS.md` mirrored via `dual-write-runtime-md.sh`.
- [`.orchestrator/milestones/M018/phases/P02/P02-SUMMARY.md`](../../../../../milestones/M018/phases/P02/P02-SUMMARY.md) written with frontmatter + closure-summary + risk-mitigation traceability + followups + verification-result sections.
- Final gate: `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P02/` exits 0 with PASS on every truth, artifact, and key link.

## State Context

- **Current State**: executing
- **Milestone**: M018
- **Phase**: P02
- **Task**: T04-verifiers-and-summary
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **AD-19 single-script-file shape on every verifier**. No inline `( . scripts/lib/foo.sh && fn )` subshells in any verifier. The preservation-check API probe uses a separate helper script under `scripts/verify/_helpers/` if needed (or `bash -c` with sequential statements).
- **AP-009 / pre-bash-shape-guard**. Compound chains > 2 are banned; verifiers use sequential statements + temp files.
- **Bash 3.2 compatibility (MEM001)**. No associative arrays, no `mapfile`, no `[[ =~ ]]` requiring extended flags.
- **AGENTS.md dual-write convention** — T04 edits CLAUDE.md directly, then runs `scripts/util/dual-write-runtime-md.sh`. NEVER edit AGENTS.md directly.
- **No new emitter schema in T04** — the emitter additions all landed in T02 + T03. T04 only verifies them.
- **No regression on the M018/P01 verifier set** — T04's verifiers must coexist with the six M018/P01 verifiers; the `check-must-haves.sh` invocation against the P02 phase dir reads the P02-PLAN.md only and does not interfere with P01's verifier names.

### Acceptance Criteria

This task addresses the phase truths:

- All six phase-truth Check commands resolve to a script under `scripts/verify/m018-p02-*.sh` and each script exits 0 on a successful M018 build.
- CLAUDE.md and AGENTS.md `recent-changes` blocks both name M018/P02. (Verified by `bash scripts/verify/m018-p02-dual-write-recent.sh`.)
- [`.orchestrator/milestones/M018/phases/P02/P02-SUMMARY.md`](../../../../../milestones/M018/phases/P02/P02-SUMMARY.md) exists with `verification_result: pass` and references all four task summaries.

### Files To Touch

- `scripts/lib/preservation-check.sh` (create — T01)
- `scripts/dispatch/build-context.sh` (modify — T02 adds knowledge filter + emitter extension; T03 adds aggregate self-check)
- `.orchestrator/config.yml` (modify — T02 adds `compression:` block; T03 adds `compression.underperformance:` keys)
- `templates/config-defaults.yml` (modify — T02 + T03 mirror new defaults)
- `tests/fixtures/m018-p02-knowledge-status/` (create — T02 fixture milestone with mixed-status MEMs)
- `tests/fixtures/m018-p02-knowledge-status/README.md` (create — T02)
- `tests/fixtures/m018-p02-baseline-payload.golden.txt` (create — T02 golden capture)
- `scripts/verify/m018-p02-filter-drops.sh` (create — T04)
- `scripts/verify/m018-p02-emitter-additivity.sh` (create — T04)
- `scripts/verify/m018-p02-preservation-check-api.sh` (create — T04)
- `scripts/verify/m018-p02-underperformance-emit.sh` (create — T04)
- `scripts/verify/m018-p02-disable-flag-honored.sh` (create — T04)
- `scripts/verify/m018-p02-dual-write-recent.sh` (create — T04)
- `CLAUDE.md` (modify — T04 refreshes `orchestrator:recent-changes` block)
- `AGENTS.md` (modify — T04 via `scripts/util/dual-write-runtime-md.sh`; never edited directly)
- [`.orchestrator/milestones/M018/phases/P02/P02-SUMMARY.md`](../../../../../milestones/M018/phases/P02/P02-SUMMARY.md) (create — T04)

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