---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T01-render-position-live-and-savings-marker (Phase P03, Milestone M029)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-978 | ~500 | required |
| Upstream Context | 980-1046 | ~5000 | required |
| Task Plan | 1048-1235 | ~4500 | required |
| State Context | 1237-1243 | ~100 | required |
| First-Turn Completeness | 1245-1312 | ~1300 | required |
| **Total** | | **~22200** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 839
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
hit_count: 839
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
hit_count: 839
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
hit_count: 839
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
hit_count: 730
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
hit_count: 730
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
hit_count: 730
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
hit_count: 839
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
hit_count: 730
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
hit_count: 730
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
hit_count: 730
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
hit_count: 839
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
hit_count: 839
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
hit_count: 839
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
hit_count: 730
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
hit_count: 730
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
hit_count: 730
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
hit_count: 839
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
hit_count: 730
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
hit_count: 730
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
hit_count: 839
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
hit_count: 839
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
hit_count: 730
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
hit_count: 730
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
hit_count: 730
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
hit_count: 385
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
hit_count: 385
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
hit_count: 385
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
hit_count: 415
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
hit_count: 415
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
hit_count: 405
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
     Project-owned slug-bearing verifiers live under tools/verify/ with
     the m029-p03-* prefix per the milestone-slug-required convention.
     Verifier scripts are co-authored alongside their corresponding
     artifact within the SAME task (plan-time discipline rule 2).
     Path-collision rule 6 has been pre-checked at plan-authoring time:
     no P03 deliverable path shadows an existing file (verified
     2026-05-06 via `ls` against every `(create)` entry in `Files
     Likely Touched`). -->

### Truths

- `scripts/diagnostics/render-position.sh` carries an additive `--live` branch that polls `execution-log.jsonl` via POSIX `tail -f`, full-re-renders the tree on every appended `dispatch_usage` record (#Q-1), emits a `▽ saved Nk` marker on rows whose `(tier1_savings_tokens + tier2_savings_tokens) / dispatch_total_tokens` exceeds the `display_thresholds.compression_savings_pct` config knob (default 5.0 per AD-5), uses ONLY the canonical compact form `▽ saved Nk` (#Q-G8 — no `▽ Nk saved` and no `▽ saved Nk via tier1 cache reuse` strings appear anywhere in P03 deliverables), and never invokes `gh` / GitHub APIs (CON-4 / FR-11). Read-only — never writes to `.orchestrator/`.
  - Check: `bash tools/verify/m029-p03-render-position-live-shape.sh`

- `references/file-formats.md` documents the `display_thresholds:` block per AD-5 with the `compression_savings_pct: 5.0` heuristic-default annotation + review trigger ("Tune after first 10 milestones of M019 Tier 1 + [M018](../../../../../milestones/M018/index.md) Tier 2 telemetry. Review trigger: re-evaluate threshold once `metrics-rollup.sh --scope milestone` shows median savings ≥ 3% across closed milestones."). `templates/orchestrator-config-default.yml` carries the new `display_thresholds:` block at top level with a YAML comment naming AD-5 and the FR-8 review trigger. `scripts/state/read-config.sh`'s `VALID_KEYS` list extends to include `display_thresholds.compression_savings_pct`.
  - Check: `bash tools/verify/m029-p03-display-thresholds-config-shape.sh`

<dispatch-volatile>

## Upstream Context


### P02 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P02"
parent: "M029"
milestone: "M029"
provides:
  - "AD-6 cross-milestone feature data-model design contract at references/cross-milestone-feature-shape.md (Principle III,upstream of T03 render-position.sh implementation); paired gate verifier at tools/verify/m029-p02-cross-milestone-shape-contract.sh that mechanically asserts every required H1/H2 header,schema token (milestone:/milestones:/M###/feature_ref),canonical glyph (✓ ▶ ◇ ✗ ▽),the #Q-G8 canonical compact savings form (saved Nk),the absence of the forbidden verbose form (via tier1 cache reuse),the AD-6/FR-13/#Q-5/#Q-G8 spec references,the --expand-all flag name,the WARN: advisory token,and the four named consumers (commands/where.md,scripts/diagnostics/render-position.sh,scripts/diagnostics/summarize-milestone.sh,scripts/state/find-active-milestone.sh),AD-4 milestone summary helper at scripts/diagnostics/summarize-milestone.sh emitting fixed-order key=value block (phase_count/phases_complete/tasks_remaining/intensity); paired shape verifier at tools/verify/m029-p02-summarize-milestone-shape.sh (17 assertions) gating downstream drift on the four-key set + line regexes + fixed-order; sourceable+CLI dual-shape mirroring metrics-rollup.sh MEM004 pure-lib precedent; --milestone <M###> + --format=keys|text + -h|--help CLI surface; default-milestone resolution via find-active-milestone.sh first-token; intensity read from M###-EVALUATION.md frontmatter against closed enum quick|standard|full|unknown,FR-5/FR-6/CON-1/CON-3/CON-4 at-rest tree renderer engine at scripts/diagnostics/render-position.sh emitting the canonical glyph alphabet (✓ ▶ ◇ ✗) over feature -> milestone -> phase -> task tree with progress bar (▓░ X% (k/n phases)) + per-row cost column gated by FR-6 dispatch_usage detection probe; sources AD-1 detect-invocation-context.sh single-resolve env block; supports --milestone/--expand-all/--feature/--no-cost/--root flags; AD-6 exactly-one-of milestone:/milestones: schema parsing via awk helpers; reverse-lookup advisory against M*-EVALUATION.md feature_ref:; #Q-5 inactive-render collapsed-by-default + active-always-expanded; canonical orchestrator:where skill at commands/where.md (10 H2 sections mirrored from commands/context.md) declaring CON-1/FR-14 read-only + CON-4/FR-11 no-GitHub-API + the canonical compact ▽ saved Nk savings form (#Q-G8) referenced in legend (renderer never emits ▽ -- P03 --live mode only); paired AD-19 single-script-file shape verifiers tools/verify/m029-p02-render-position-shape.sh (20/20 PASS) + tools/verify/m029-p02-where-skill-shape.sh (24/24 PASS) gating glyph alphabet,contract tokens,anti-coupling /integrations/github absent,forbidden verbose-suffix form via tier1 cache reuse absent,AD-1 resolver invocation,[M027](../../../../../milestones/M027/index.md) metrics-rollup invocation + FR-6 dispatch_usage probe presence,all 10 required H2 sections,all 5 canonical glyphs,all 3 required references,SC-5/SC-6/SC-13/SC-14 acceptance fixtures + scripts + AD-9 sentinel harness; six P02 shape verifiers all PASS; SC-5 byte-stable golden render covering all four glyph states (✓ ▶ ◇ ✗); #Q-G6 timestamp-strip pattern set locked; #Q-G8 canonical compact-form invariant mechanically enforced,P02 close-gate scaffolding -- 13-gate phase-suite aggregator + SC-5/6/13/14 acceptance battery + project-tree readonly-invariant + porcelain-classification scope-guard + battery-shape verifier; canonical 'P02 is done' signal is bash tools/verify/m029-p02-phase-suite.sh exiting 0 with SUMMARY pass=13 fail=0; P02 contribution to validate-milestone.sh M029 is exactly the 13 phase-suite gates plus the 4 SC battery hits"
requires:
  - "P01"
affects:
  - "P03"
key_files:
  - "references/cross-milestone-feature-shape.md,tools/verify/m029-p02-cross-milestone-shape-contract.sh,scripts/diagnostics/summarize-milestone.sh,tools/verify/m029-p02-summarize-milestone-shape.sh,scripts/diagnostics/render-position.sh,commands/where.md,tools/verify/m029-p02-render-position-shape.sh,tools/verify/m029-p02-where-skill-shape.sh,tests/m029-acceptance/fixtures/where-mixed-state.fixture/,tests/m029-acceptance/fixtures/where-mixed-state.golden,tests/m029-acceptance/fixtures/where-pre-m019.fixture/,tests/m029-acceptance/timestamp-strip.sh,tests/m029-acceptance/sentinel-harness.sh,tests/m029-acceptance/p02-sc5-where-mixed-state.sh,tests/m029-acceptance/p02-sc6-where-pre-m019.sh,tests/m029-acceptance/p02-sc13-anti-coupling.sh,tests/m029-acceptance/p02-sc14-readonly.sh,tools/verify/m029-p02-sc5-fixtures-shape.sh,tools/verify/m029-p02-sentinel-harness-shape.sh,tools/verify/m029-p02-sc5-shape.sh,tools/verify/m029-p02-sc6-shape.sh,tools/verify/m029-p02-sc13-shape.sh,tools/verify/m029-p02-sc14-shape.sh,tests/m029-acceptance/p02-acceptance-battery.sh,tools/verify/m029-p02-acceptance-battery-shape.sh,tools/verify/m029-p02-readonly-invariant.sh,tools/verify/m029-p02-scope-guard.sh,tools/verify/m029-p02-phase-suite.sh"
key_decisions:
  - "AD-6 cross-milestone feature data model (exactly-one-of milestone:/milestones: schema rule + reverse-lookup advisory),#Q-5 inactive-milestone render shape (collapsed by default + --expand-all override + active-milestone always expanded),#Q-G8 FR-8 marker canonical compact form (saved Nk; verbose suffix reserved for future --verbose mode),Principle III (contract upstream of code),AD-4 (M029 owns its own milestone summary helper; SC-8 oracle amends from predictive-surface.sh --milestone to summarize-milestone.sh --milestone because M027 is closed under CON-3 knowledge-layer boundary),CON-1/FR-14/Principle XV read-only discipline,MEM004 pure-lib sourceable+CLI dual-shape,MEM001 bash 3.2 compatibility,AD-19 single-script-file straight-line bash for verifier,AD-1 single-resolve discipline (renderer reads detect-invocation-context.sh's three-line env block; never re-derives TTY/CI/runtime),AD-6 exactly-one-of milestone:/milestones: schema with stderr WARN + prefer-plural on both-present,#Q-5 collapsed-by-default + --expand-all + active-always-expanded inactive-render shape,#Q-G8 canonical compact form ▽ saved Nk (verbose-suffix forms reserved for future --verbose mode),CON-1/FR-14 read-only with sole allowed write site /tmp/m029-rp.$$/,CON-3 silent FR-6 cost-column suppression on pre-M019 milestones,CON-4/FR-11 no-GitHub-API via anti-coupling /integrations/github absent invariant,MEM004 carve-out for awk/sed/grep pipes inside renderer body (AD-19 verifier-shape rules apply only at Check: command level),AD-9 sentinel-file find -newer mechanism for SC-14; #Q-G6 enumerated timestamp-strip pattern set (TS/RECENCY/EPOCH); #Q-G8 canonical compact-form invariant (▽ saved Nk only,no via-tier1 verbose form); fixture orchestrator-root export so transitively-invoked metrics-rollup.sh sees the fixture tree; SC-13 spec-side scan narrowed to normative read-imperative pattern (carve-out for self-referential spec.md mentions of /integrations/github in FR-11/SC-13 definitions and conversus review meta),AD-19 straight-line bash preserved end-to-end (literal bash path per gate,no compound chains,no process substitution); MEM001 Bash 3.2 (no declare -A,no herestring,parallel indexed accumulators); CON-7/AD-8 read-only-consumer discipline (denylist covers metrics-rollup,efficiency-footer,predictive-surface); run-probe scope rule 4 (sentinel under /tmp/ not under .orchestrator/); scope-guard upstream-phase carve-out (P01 untracked deliverables admitted to P02 allowlist)"
patterns_established:
  - "Principle-III paired design contract gate verifier shape extended from P01 (m029-p01-headline-shape-contract.sh) to P02; AD-19 straight-line bash with separate grep -F invocation per assertion and parallel pass/fail counters (MEM001/MEM002 bash 3.2 safe); negative assertion pattern for forbidden tokens (via tier1 cache reuse) where the verifier asserts absence in the contract while still containing the literal token in its own assertion code (mirrors P01 verifier discipline -- verifier code is not deliverable text),four-key fixed-order output contract as AD-4 SC-8 oracle interface (phase_count/phases_complete/tasks_remaining/intensity); verifier asserts both the literal key strings in script body AND the line-regex shape AND the fixed line order — three independent invariants prevent silent drift; sourceable+CLI dual-shape with _SOURCED re-source guard + _SCRIPT_DIR/_PROJECT_ROOT resolution mirrors metrics-rollup.sh; default-milestone via find-active-milestone.sh first-token (existing convention from check-anomalies.sh / compression-eval.sh); intensity read from EVALUATION frontmatter validated against closed enum with unknown fallback; verifier captures stdout to /tmp/sm-out.$$ trap-cleaned then runs separate grep / case statements against the file (AD-19: no $(cmd | grep)),renderer-engine-plus-LLM-instruction-skill split (P01 commands/context.md precedent; production rendering performed by the engine -- the skill instructs the agent to invoke the engine and pass output through unchanged); AD-1 resolver capture-to-tempfile-then-grep-line pattern (no $() pipe in public surface;  parameter expansion); AD-6 frontmatter parsing via two awk helpers (_rp_yaml_scalar singular + _rp_yaml_inline_list plural [..]); FR-6 / CON-3 silent suppression via single grep -m1 -F probe for literal dispatch_usage with on-miss empty-string return + caller printf-concat (visually identical row minus dollar amount); reverse-lookup advisory pattern (enumerate EVALUATION feature_ref + sort both sets + sorted-string equality + stderr WARN on mismatch + render-from-spec per Principle XI); negative-assertion verifier discipline (T01 precedent: verifier code names forbidden tokens in assertion strings; deliverable body must paraphrase semantically); 8-section command-doc shape mirroring commands/context.md (Prerequisites/Core Workflow/Glyph Legend/Flags/Output/Idempotency/Error Handling/Constraints/Referenced Scripts/Reference Files); MEM004 carve-out applied: awk/sed/grep pipes inside renderer body; AD-19 single-script-file straight-line bash for verifiers (no $(cmd | grep),no plain subshells,no process substitution),empty-phase-directory + .gitkeep as ◇ glyph driver; verify_result-record (phase=P##,result=fail) as ✗ glyph driver; ORCHESTRATOR_ROOT env export alongside --root flag for fixtures with transitively-invoked helpers; MEM004 carve-out applies to acceptance script bodies (sed/grep pipes inside scripts permitted,AD-19 single-script-file rule applies only to Check: lines); self-referential spec-paradox carve-out documented in acceptance-script header,P02 phase-suite shape mirrors P01 precedent end-to-end (linear bash <path>; rc=dollar-question; emit_gate_result; aggregate SUMMARY); acceptance battery wraps SC scripts and embeds in milestone validator while phase-suite is the per-phase close gate (split established in P01/T06); project-tree readonly-invariant complements fixture-tree SC-14 via /tmp-sentinel + .orchestrator-scan with execution-log.jsonl exclusion (diagnostic-distinct from fixture-tree); scope-guard upstream-phase carve-out (P02 allowlist admits P01 untracked deliverables that belong to P01 claim,not P02-introduced); WARN-on-unclassified is genuinely advisory (34 WARN on the live tree from knowledge-graph hit_count + recent-changes block edits is expected noise per P01 precedent)"
drill_down_paths:
  - "[.orchestrator/milestones/M029/phases/P02/tasks/T01-cross-milestone-data-model-SUMMARY.md](../../../../../milestones/M029/phases/P02/tasks/T01-cross-milestone-data-model-SUMMARY.md), [.orchestrator/milestones/M029/phases/P02/tasks/T02-summarize-milestone-SUMMARY.md](../../../../../milestones/M029/phases/P02/tasks/T02-summarize-milestone-SUMMARY.md), [.orchestrator/milestones/M029/phases/P02/tasks/T03-render-position-and-where-skill-SUMMARY.md](../../../../../milestones/M029/phases/P02/tasks/T03-render-position-and-where-skill-SUMMARY.md), [.orchestrator/milestones/M029/phases/P02/tasks/T04-fixtures-and-sc-acceptance-SUMMARY.md](../../../../../milestones/M029/phases/P02/tasks/T04-fixtures-and-sc-acceptance-SUMMARY.md), [.orchestrator/milestones/M029/phases/P02/tasks/T05-phase-close-gates-SUMMARY.md](../../../../../milestones/M029/phases/P02/tasks/T05-phase-close-gates-SUMMARY.md)"
duration: "75m"
verification_result: "pass"
completed_at: "2026-05-06T01:10:04Z"
observability_surfaces:
  - "none"
---

M029/P02 ships the `orchestrator:where` at-rest tree renderer plus its supporting design contract, helper, fixtures, acceptance scripts, and close-gate scaffolding. Five tasks (T01–T05), all PASS.

**What was built:**

- **T01 — AD-6 cross-milestone feature data-model design contract.** `references/cross-milestone-feature-shape.md` (Principle III: contract upstream of T03 code) pins the AD-6 schema rule (`milestone:` singular vs `milestones:` list), the reverse-lookup advisory shape, the canonical glyph alphabet (`✓ ▶ ◇ ✗ ▽`), the `--expand-all` flag name, the `WARN:` advisory token, and the four named consumers. Paired gate verifier (`m029-p02-cross-milestone-shape-contract.sh`, 29/29 PASS) mechanically asserts every required header / schema token / glyph / spec reference / flag / consumer cross-reference.

- **T02 — AD-4 milestone summary helper.** `scripts/diagnostics/summarize-milestone.sh` is the M029-owned milestone roll-up oracle (CON-3 honored — no edit to M027). Sourceable + CLI dual-shape per MEM004 (mirrors `metrics-rollup.sh`); emits a fixed-order four-key block (`phase_count` / `phases_complete` / `tasks_remaining` / `intensity`); `--milestone <M###>` + `--format=keys|text` + `-h|--help` CLI surface; default milestone resolved via `find-active-milestone.sh` first-token; `intensity` read from `<M###>-EVALUATION.md` against closed enum `quick|standard|full|unknown`. Paired shape verifier asserts the four key strings, the per-line regexes, AND the fixed line order — three independent invariants gate downstream drift.

- **T03 — FR-5 / FR-6 / CON-1 / CON-3 / CON-4 core implementation.** `scripts/diagnostics/render-position.sh` (≈ 470 lines) is the at-rest tree renderer engine; `commands/where.md` is the LLM-instruction skill (10 H2 sections mirroring `commands/context.md`) that instructs the agent to invoke the engine and pass output through unchanged. The engine sources the AD-1 resolver's three-line env block (no surface re-derives TTY/CI/runtime), parses AD-6 exactly-one-of `milestone:` / `milestones:` frontmatter via two `awk` helpers (`_rp_yaml_scalar` + `_rp_yaml_inline_list`), performs the reverse-lookup advisory against `M*-EVALUATION.md` `feature_ref:`, applies #Q-5 collapsed-by-default (active milestone always expanded), and emits the canonical glyph alphabet (`✓ ▶ ◇ ✗`) over feature → milestone → phase → task. The FR-6 cost column is gated by a `dispatch_usage` detection probe that silently suppresses the column on pre-M019 milestones per CON-3. Two paired shape verifiers (20/20 + 24/24 PASS) gate the glyph alphabet, contract tokens, AD-1 resolver invocation, M027 metrics-rollup invocation, FR-6 dispatch_usage probe presence, all 10 required H2 sections, and the canonical compact ▽ saved Nk savings form (#Q-G8) referenced in legend (renderer never emits ▽ — that's reserved for P03 `--live` mode).

- **T04 — fixtures + SC-5 / SC-6 / SC-13 / SC-14 acceptance scripts + AD-9 sentinel harness.** Two fixture trees: `where-mixed-state.fixture/` (M998, all four glyph states represented — restructured from plan's 3 phases to 4 once T03 reading revealed the renderer's actual `_rp_task_glyph` semantics — and `where-pre-m019.fixture/` (M997, no `dispatch_usage` records to exercise CON-3 silent cost-column suppression). Byte-stable golden render (`where-mixed-state.golden`) covers all four canonical glyph states. `timestamp-strip.sh` locks the #Q-G6 enumerated pattern set (TS / RECENCY / EPOCH). `sentinel-harness.sh` is the AD-9 SC-14 mechanism. Six P02 shape verifiers (62/62 total assertions). SC-13 spec-side scan narrowed from literal-grep to imperative-pattern matching to handle the spec-paradox where the spec.md self-references the constraint by quoting the literal — load-bearing assertion (renderer body free of literal) is unchanged.

- **T05 — phase-close gate.** SC-11 acceptance battery (chains SC-5 / SC-6 / SC-13 / SC-14 → 4/4 PASS), 13-gate phase-suite aggregator (mirrors `m029-p01-phase-suite.sh`), project-tree readonly-invariant verifier (diagnostic-distinct from T04's fixture-tree SC-14), conservative scope-guard with upstream-phase carve-out (P01 untracked deliverables admitted to P02 allowlist), battery-shape verifier. Canonical "P02 is done" signal: `bash tools/verify/m029-p02-phase-suite.sh` exits 0 with `SUMMARY: m029-p02-phase-suite.sh pass=13 fail=0`.

**Verification.** Phase-suite **13/13 PASS**, acceptance battery **4/4 PASS** (SC-5 / SC-6 / SC-13 / SC-14), full 4-tier `orchestrator:verify` PASS overall (Tier 1: 11/11 truth + 8/8 key links + 40/42 artifact patterns — two FAILs are documented-deviation false positives whose underlying invariants are mechanically asserted by the bound shape verifiers; Tier 2: phase-suite + battery green; Tier 3: behavioral coverage rolled into SC-5/6/13/14; Tier 4: N/A).

**Patterns established (load-bearing for P03):**

1. **Renderer-engine + LLM-instruction-skill split** — T01/P01 precedent (`commands/context.md`) extended to `commands/where.md` + `render-position.sh`. Production rendering happens in the engine; the skill instructs the agent to invoke the engine and pass output through unchanged.
2. **Negative-assertion verifier discipline** — verifier code asserts absence of forbidden tokens (`via tier1 cache reuse`, `/integrations/github`) in deliverable bodies while the verifier itself names those literals in its assertion strings. Verifier code is not deliverable text.
3. **Four-key fixed-order output contract** as AD-4 SC-8 oracle interface — three independent invariants (literal key strings in body + per-line regex + fixed line order) gate silent drift.
4. **AD-6 frontmatter parsing via two awk helpers** (`_rp_yaml_scalar` singular + `_rp_yaml_inline_list` plural `[..]`) with `WARN:` advisory + prefer-plural on both-present.
5. **Sentinel-file `find -newer` AD-9 mechanism** + `#Q-G6` enumerated timestamp-strip pattern set (TS / RECENCY / EPOCH) — the SC-14 readonly contract and the P03 deterministic-byte-equality contract both build on these.
6. **Scope-guard upstream-phase carve-out** — when a phase ships before its upstream is committed, untracked upstream deliverables are admitted to the current-phase allowlist (not denylisted, since they belong to the upstream's claim, not P02's).
7. **MEM004 carve-out** for `awk` / `sed` / `grep` pipes inside renderer + acceptance bodies — AD-19 single-script-file rule applies only at `Check:` lines.

**Decisions surfaced.** AD-4 (M029 owns its own summarize-milestone helper; SC-8 oracle amends from `predictive-surface.sh --milestone` to `summarize-milestone.sh --milestone` because M027 is closed under CON-3). AD-6 exactly-one-of schema. #Q-5 collapsed-by-default render shape. #Q-G8 canonical compact-form invariant. CON-1/FR-14/Principle XV read-only with sole allowed write site `/tmp/m029-rp.$$/`. CON-3 silent FR-6 cost-column suppression. CON-4/FR-11 no-GitHub-API anti-coupling.

**Documented in-flight deviations (all observational, no correctness blockers):**

- **SC-5 fixture restructured to 4 phases** (vs plan's 3) once T03 revealed `_rp_task_glyph` returns `▶` for any task with a PLAN (no `✗` at task grain, no `◇` for plan-present-summary-absent). Restructure exercises all four canonical glyphs literally.
- **SC-13 spec-side check narrowed** from literal-grep to imperative-pattern matching to handle the spec.md's self-referential mentions of the constraint. Load-bearing assertion (renderer body free of literal) preserved.
- **`summarize-milestone.sh --root` paper-cut** — the helper does not honor a `--root` flag (only `_SM_PROJECT_ROOT/.orchestrator`). T04's golden was pinned around the deterministic actual output. Paper-cut for a future tightening: either `summarize-milestone.sh` should accept `--root` / honor `ORCHESTRATOR_ROOT`, or the renderer should pass the root through.

**P03 unblocked.** P03 (`--live` mode + savings disclosure + GitHub fold-in deferred to demand-driven `external-tool-adapters`) consumes the renderer + the AD-9 sentinel harness + the SC battery scaffolding from P02.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M029"
name: "--live branch on render-position.sh + ▽ saved Nk savings marker + display_thresholds.compression_savings_pct config knob"
depends_on: []
---

## Prerequisites

- `scripts/diagnostics/render-position.sh` is on disk from P02/T03 (the at-rest renderer this task extends in-place per Boundary Map "produced once in P02 and *extended in place* in P03"). `[ -f scripts/diagnostics/render-position.sh ]` PASS at plan-authoring time.
- `references/file-formats.md` is on disk (`## Configuration (orchestrator-config.yml)` section at line 666). `[ -f references/file-formats.md ]` PASS.
- `templates/orchestrator-config-default.yml` is on disk. `[ -f templates/orchestrator-config-default.yml ]` PASS.
- `scripts/state/read-config.sh` is on disk with `VALID_KEYS` at line 17. `[ -f scripts/state/read-config.sh ]` PASS.
- M019 `dispatch_usage` JSONL schema is closed and exposes `tier1_savings_tokens`, `tier2_savings_tokens`, and a total-tokens field on every `dispatch_usage` record. M018 `payload_breakdown.tier1_savings_tokens` and `tier2_savings_tokens` fields are stable per `references/RUNTIME-ASSUMPTIONS.md`.
- No path-collision: this task creates one new file (`tools/verify/m029-p03-render-position-live-shape.sh`); `[ ! -f tools/verify/m029-p03-render-position-live-shape.sh ]` PASS at plan-authoring time. All other paths are modifications of existing files.

## Description

T01 ships the foundational live-tail surface and the FR-8 marker:

1. **`scripts/diagnostics/render-position.sh` `--live` branch** (additive, in-place modification): a new branch that polls `execution-log.jsonl` via POSIX `tail -f`, full-re-renders the tree on every appended `dispatch_usage` record (#Q-1 — full re-render, no incremental row update; tree fits in <50 rows so the cost is negligible), exits cleanly on SIGTERM/SIGINT.

2. **`▽ saved Nk` marker rendering** (FR-8, AD-5, #Q-G8): when a `dispatch_usage` record's savings ratio `(tier1_savings_tokens + tier2_savings_tokens) / dispatch_total_tokens` exceeds the `display_thresholds.compression_savings_pct` knob (default 5.0), the row renders the canonical compact-form marker `▽ saved Nk` where `N = ceil((tier1_savings_tokens + tier2_savings_tokens) / 1000)`. The compact form is the ONLY form emitted in P03 deliverables — no `▽ Nk saved`, no `▽ saved Nk via tier1 cache reuse`, no other variants. Per #Q-G8 the verbose form `via tier1 cache reuse` is reserved for a future `--verbose` mode and is NOT shipped in M029.

3. **`display_thresholds.compression_savings_pct` config knob** (AD-5):
   - `templates/orchestrator-config-default.yml` carries a new top-level `display_thresholds:` block with `compression_savings_pct: 5.0` and a YAML comment annotating the heuristic-default rationale + review trigger.
   - `references/file-formats.md` documents the new block under the existing `## Configuration (orchestrator-config.yml)` section.
   - `scripts/state/read-config.sh` extends its `VALID_KEYS` allowlist to include `display_thresholds.compression_savings_pct` so the dotted form resolves through the standard 4-layer fallback.
   - `render-position.sh` reads the knob via `bash scripts/state/read-config.sh display_thresholds.compression_savings_pct` at `--live` entry; on any read failure (key absent / config corrupt / read-config exit non-zero), the renderer falls back to the hard-coded default `5.0` and emits an advisory `WARN: display_thresholds.compression_savings_pct fallback to default` line on stderr (NOT a hard fail — Principle XI fail-open).

4. **Shape verifier** `tools/verify/m029-p03-render-position-live-shape.sh`: mechanical assertions that the `--live` branch exists in the file body, that the canonical compact-form `▽ saved Nk` literal is present, that the forbidden verbose form `via tier1 cache reuse` is absent (negative-assertion verifier discipline — the verifier code itself names the forbidden token in an assertion string but the deliverable body must not contain it), and that the renderer reads the threshold knob via `read-config.sh`.

5. **Config-shape verifier** `tools/verify/m029-p03-display-thresholds-config-shape.sh`: asserts the new block lands at top level in the default-config template, the `compression_savings_pct: 5.0` line is byte-stable, the docstring annotation appears in `references/file-formats.md`, and `VALID_KEYS` in `read-config.sh` includes the dotted form.

## Steps

1. **Modify `scripts/diagnostics/render-position.sh`** — add the `--live` branch:

   - Extend the existing CLI flag parser to accept `--live` (boolean, no argument).
   - When `--live` is set:
     - Resolve the active milestone's `execution-log.jsonl` path via `find-active-milestone.sh` + `<root>/.orchestrator/milestones/<MID>/execution-log.jsonl` (or honour `--milestone <MID>`).
     - If the path does not exist, wait up to 5 seconds for it to appear (poll loop with 0.5s sleeps); if still absent, emit `ERROR: no execution log under <path>` to stderr and exit 1 (per spec Edge Cases entry "Live-tail target file missing").
     - Read the threshold knob via `bash scripts/state/read-config.sh display_thresholds.compression_savings_pct`; capture stdout to a scalar; on non-zero rc OR empty stdout, fall back to `5.0` and emit `WARN: ...` on stderr.
     - Run an initial full re-render (the existing at-rest tree code path).
     - Enter the tail loop: `tail -f -n 0 "$LOG_PATH"` piped to a `while read -r line` loop; on every line containing `"event":"dispatch_usage"` (substring match — keep parsing simple per AD-19), trigger a full re-render. Trap SIGTERM and SIGINT to break out cleanly.

   - For the marker rendering during the tree walk:
     - For each in-flight task row, scan the most-recent `dispatch_usage` record for that `task_id` from the JSONL stream (single-pass, O(n) over recent lines is acceptable; can be a separate helper function `_rp_latest_dispatch_usage_for_task`).
     - Compute `savings_pct = 100.0 * (tier1_savings_tokens + tier2_savings_tokens) / dispatch_total_tokens` using `awk` or bash arithmetic + `printf '%.1f'` (bash 3.2-safe — no associative arrays, no `<<<` herestring; use `printf | awk` for the float division).
     - When `savings_pct >= threshold_pct`, append the marker `printf ' ▽ saved %dk' "$N"` to the row, where `N = ceil((tier1_savings_tokens + tier2_savings_tokens) / 1000)` (use `awk 'BEGIN{ printf("%d", int((s+999)/1000)) }'` or equivalent integer-ceil).

   - **AD-19 discipline inside the renderer body**: complex line-by-line parsing of JSONL is allowed via `awk`/`grep`/`sed` pipes inside function bodies (MEM004 carve-out — AD-19 single-script-file shape applies only to `Check:` command level, not to internal renderer logic). Keep the OUTER CLI flag-handling and tail-loop free of compound chains > 2 stages.

2. **Modify `templates/orchestrator-config-default.yml`** — append a new top-level `display_thresholds:` block (after the `quick_knowledge_token_budget:` / `entry_routing_confidence_floor:` block at the file tail; before EOF):

   ```yaml
   # M029 — display_thresholds (AD-5).
   # FR-8 / AD-5 — minimum compression savings ratio (as a percentage of total
   # dispatch tokens) below which the live-tail render suppresses the
   # `▽ saved Nk` marker on a `dispatch_usage` row. Heuristic default; tune
   # after first 10 milestones of M019 Tier 1 + M018 Tier 2 telemetry.
   # Review trigger: re-evaluate threshold once
   # `metrics-rollup.sh --scope milestone` shows median savings ≥ 3% across
   # closed milestones.
   display_thresholds:
     compression_savings_pct: 5.0
   ```

   Bash 3.2 quoting; YAML 1.2 compatible.

3. **Modify `references/file-formats.md`** — under `## Configuration (orchestrator-config.yml)` (line 666), extend the documented key set or add a new sub-section `### Display Thresholds (M029)` documenting:
   - The block name `display_thresholds:`.
   - The single key `compression_savings_pct: 5.0`.
   - The AD-5 rationale text verbatim ("Heuristic default. Tune after first 10 milestones of M019 Tier 1 + M018 Tier 2 telemetry. Review trigger: re-evaluate threshold once `metrics-rollup.sh --scope milestone` shows median savings ≥ 3% across closed milestones.").
   - The cross-reference to FR-8 + AD-5 + the `▽ saved Nk` marker semantics.

4. **Modify `scripts/state/read-config.sh`** — extend the `VALID_KEYS` string at line 17 by appending `display_thresholds.compression_savings_pct` (single space separator). DO NOT change any other line. The dotted-form key resolves through the standard YAML walker that `read-config.sh` already implements for `compression.efficiency_footer.enabled` and `compression.regression_floor`.

5. **Author `tools/verify/m029-p03-render-position-live-shape.sh`** (≥40 lines, executable, AD-19 single-script-file shape, bash 3.2):
   - Asserts `[ -f scripts/diagnostics/render-position.sh ]` and `[ -x scripts/diagnostics/render-position.sh ]`.
   - Asserts the file body contains `--live` (the new flag is wired).
   - Asserts the file body contains `tail -f` (the POSIX-portable polling primitive per CON-2).
   - Asserts the file body contains the literal `▽ saved` and the literal `display_thresholds.compression_savings_pct` and the literal `read-config.sh`.
   - Asserts the file body does NOT contain the forbidden verbose suffix `via tier1 cache reuse` (negative-assertion discipline: this verifier's assertion string DOES contain that literal token but the deliverable body MUST not).
   - Asserts the file body contains the references `FR-7`, `FR-8`, `#Q-1`, `#Q-G8`, `AD-5`.
   - Emits `PASS:` per assertion, `FAIL:` on any miss, and `SUMMARY: m029-p03-render-position-live-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.
   - `chmod +x`.

6. **Author `tools/verify/m029-p03-display-thresholds-config-shape.sh`** (≥30 lines, executable, AD-19, bash 3.2):
   - Asserts `templates/orchestrator-config-default.yml` contains `display_thresholds:` at line start (`grep -n '^display_thresholds:' ...`), and `compression_savings_pct: 5.0` indented under it.
   - Asserts `references/file-formats.md` contains `display_thresholds:`, `compression_savings_pct`, `AD-5`, and the literal phrase `Tune after first 10 milestones`.
   - Asserts `scripts/state/read-config.sh`'s `VALID_KEYS` line contains `display_thresholds.compression_savings_pct`.
   - Emits per-assertion `PASS:`/`FAIL:` + `SUMMARY:` line. Exit 0 iff `fail=0`.

7. **`chmod +x` every new `.sh` file**.

8. **Smoke-run** the renderer's at-rest path against an existing fixture (`tests/m029-acceptance/fixtures/where-mixed-state.fixture/`) to confirm the additive `--live` flag does not regress the at-rest rendering. The output should match the existing `where-mixed-state.golden` byte-stable contract from P02/SC-5.

9. **Smoke-run** the renderer's `--live` path against the same fixture for ~2 seconds (background the process, append a synthetic `dispatch_usage` line to the fixture's `execution-log.jsonl`, kill the renderer, inspect captured stdout for the `▽ saved Nk` marker). This is a hand-verification step — the SC-7 acceptance script in T04 will codify it.

## Must-Haves

This task addresses these P03 phase truths:
- `scripts/diagnostics/render-position.sh` carries an additive `--live` branch with the canonical compact-form `▽ saved Nk` marker (FR-7, FR-8, #Q-1, #Q-G8) gated by the AD-5 threshold knob.
- `references/file-formats.md` + `templates/orchestrator-config-default.yml` + `scripts/state/read-config.sh` document and surface the `display_thresholds.compression_savings_pct` knob (AD-5).

This task creates these P03 phase artifacts:
- `tools/verify/m029-p03-render-position-live-shape.sh`
- `tools/verify/m029-p03-display-thresholds-config-shape.sh`

## Verification

```bash
bash tools/verify/m029-p03-render-position-live-shape.sh
bash tools/verify/m029-p03-display-thresholds-config-shape.sh
```

## Inputs

### From Previous Tasks (P02)

- `scripts/diagnostics/render-position.sh` (the at-rest renderer, T01 extends in-place).
  - Key API: `bash scripts/diagnostics/render-position.sh [--milestone M###] [--expand-all] [--feature <slug>] [--no-cost] [--root <path>]` emits the at-rest tree to stdout. T01 adds `--live`.
  - Internal helpers used: `_rp_yaml_scalar` (frontmatter scalar), `_rp_yaml_inline_list` (inline list parser), `_rp_resolver_capture` (AD-1 single-resolve), the M027 cost-column probe (`grep -m1 -F dispatch_usage`).
- `scripts/diagnostics/summarize-milestone.sh` (P02/T02) — NOT consumed by T01 directly; consumed by T02's preflight surface and T04's SC-8 oracle wrapper.

### From Disk (Pre-existing — closed milestones)

- `scripts/state/read-config.sh` (4-layer config resolver; dotted-form key support already shipped per `compression.efficiency_footer.enabled` precedent).
- M018 `payload_breakdown.tier1_savings_tokens` / `tier2_savings_tokens` field set (closed; no schema change).
- M019 `dispatch_usage` event schema (closed; no schema change).
- POSIX `tail -f` (CON-2 portability assumption A-3).

### From Disk (Pre-existing — modify-in-place)

- `templates/orchestrator-config-default.yml` — top-level YAML config template; T01 appends a new `display_thresholds:` block at the file tail.
- `references/file-formats.md` — file-formats reference doc; T01 extends `## Configuration (orchestrator-config.yml)` with the new block documentation.
- `scripts/state/read-config.sh` — config resolver script; T01 appends one token to the `VALID_KEYS` string at line 17.

## Constraints

- **AD-19 straight-line bash for `Check:` commands**: every verifier MUST be straight-line (NO inline compound chains, NO plain subshells, NO `$(cmd | …)`, NO process substitution). Internal renderer body MAY use `awk`/`grep`/`sed` pipes inside function bodies (MEM004 carve-out — AD-19 applies at `Check:` command level, not inside renderer logic).
- **Bash 3.2 (MEM001)**: NO `declare -A`, NO `<<<` herestring, parallel indexed arrays for any per-item tracking. Use `printf | awk` for float arithmetic; use `awk 'BEGIN{...}'` for integer ceiling.
- **CON-1 / FR-14 read-only**: the `--live` branch never writes to `.orchestrator/`. The fall-back-to-default branch on threshold-read failure emits ONLY to stderr.
- **CON-2 bash + ANSI only**: live-tail uses POSIX `tail -f` exclusively. NO `inotify`, NO `fswatch`, NO Python, NO Rich/TUI. ANSI escapes only.
- **CON-3 cost-column-graceful-degradation**: pre-M019 milestones (no `dispatch_usage` records) render WITHOUT the `▽` marker AND without stderr noise. The savings probe must mirror P02's silent-suppression contract.
- **CON-4 no-github-api-on-render**: NO `gh` invocations, NO HTTP. The `--live` branch is the same in this regard as the at-rest branch from P02.
- **CON-7 / AD-8 knowledge-layer-boundary**: T01 introduces NO new JSONL event types, NO M020 schema changes, NO M027 surface changes. The new `display_thresholds:` config block is M029-owned per AD-8 write-claim.
- **#Q-G8 canonical-form invariant**: ONLY `▽ saved Nk`. NO `▽ Nk saved`. NO `▽ saved Nk via tier1 cache reuse`. The verifier asserts both presence of the canonical form AND absence of the forbidden suffix.
- **#Q-1 full-re-render**: live-tail performs a full tree re-render on every appended `dispatch_usage` record. NO incremental row-update / row-tracking state. Tree size is bounded (<50 rows) so the cost is negligible per the spec's #Q-1 recommendation.
- **Path-collision rule 6**: `tools/verify/m029-p03-render-position-live-shape.sh` and `tools/verify/m029-p03-display-thresholds-config-shape.sh` do not exist on disk at plan-authoring time (verified 2026-05-06).

## Expected Output

After T01 completes:
- `scripts/diagnostics/render-position.sh` — the `--live` branch is wired; at-rest behaviour unchanged; manual smoke run shows the marker on a synthetic ≥5% savings record.
- `templates/orchestrator-config-default.yml` — `display_thresholds:` block appended.
- `references/file-formats.md` — `display_thresholds:` documented.
- `scripts/state/read-config.sh` — `VALID_KEYS` extended.
- `tools/verify/m029-p03-render-position-live-shape.sh` — exists, executable, exits 0.
- `tools/verify/m029-p03-display-thresholds-config-shape.sh` — exists, executable, exits 0.
- A summary file at [`.orchestrator/milestones/M029/phases/P03/tasks/T01-render-position-live-and-savings-marker-SUMMARY.md`](../../../../../milestones/M029/phases/P03/tasks/T01-render-position-live-and-savings-marker-SUMMARY.md) documents the deliverables.

## Notes

Expected verifier output:
```
PASS: render-position.sh exists and is executable
PASS: --live flag wired
PASS: tail -f primitive present
PASS: ▽ saved canonical form present
PASS: forbidden verbose form `via tier1 cache reuse` absent
PASS: read-config.sh threshold-knob read present
PASS: display_thresholds.compression_savings_pct token present
PASS: FR-7 / FR-8 / #Q-1 / #Q-G8 / AD-5 references present
SUMMARY: m029-p03-render-position-live-shape.sh pass=N fail=0
```

The forbidden-token negative-assertion pattern carries forward from P02/T03's render-position-shape verifier — that verifier's assertion code names `▽ saved Nk via tier1 cache reuse` as the forbidden literal while the renderer body itself never emits it. P03/T01 mirrors this discipline.

`read-config.sh`'s dotted-form key resolution treats `display_thresholds.compression_savings_pct` exactly the way it already treats `compression.efficiency_footer.enabled` — no resolver change is needed beyond extending the `VALID_KEYS` allowlist string. The 4-layer precedence (env > local > project > defaults) applies automatically.

The fall-back-to-default discipline matters because consumer projects that have not yet upgraded their `orchestrator-config.yml` (or are using a legacy default-config template) must continue to render `▽ saved Nk` markers without breaking. The fail-open default is `5.0`; the stderr `WARN:` line is advisory and does not break SC-6's "stderr is empty" invariant against pre-M019 milestones (because pre-M019 milestones have no `dispatch_usage` records to evaluate the threshold against — the marker code path never fires for them).

## State Context

- **Current State**: executing
- **Milestone**: M029
- **Phase**: P03
- **Task**: T01-render-position-live-and-savings-marker
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **AD-19 straight-line bash for `Check:` commands**: every verifier MUST be straight-line (NO inline compound chains, NO plain subshells, NO `$(cmd | …)`, NO process substitution). Internal renderer body MAY use `awk`/`grep`/`sed` pipes inside function bodies (MEM004 carve-out — AD-19 applies at `Check:` command level, not inside renderer logic).
- **Bash 3.2 (MEM001)**: NO `declare -A`, NO `<<<` herestring, parallel indexed arrays for any per-item tracking. Use `printf | awk` for float arithmetic; use `awk 'BEGIN{...}'` for integer ceiling.
- **CON-1 / FR-14 read-only**: the `--live` branch never writes to `.orchestrator/`. The fall-back-to-default branch on threshold-read failure emits ONLY to stderr.
- **CON-2 bash + ANSI only**: live-tail uses POSIX `tail -f` exclusively. NO `inotify`, NO `fswatch`, NO Python, NO Rich/TUI. ANSI escapes only.
- **CON-3 cost-column-graceful-degradation**: pre-M019 milestones (no `dispatch_usage` records) render WITHOUT the `▽` marker AND without stderr noise. The savings probe must mirror P02's silent-suppression contract.
- **CON-4 no-github-api-on-render**: NO `gh` invocations, NO HTTP. The `--live` branch is the same in this regard as the at-rest branch from P02.
- **CON-7 / AD-8 knowledge-layer-boundary**: T01 introduces NO new JSONL event types, NO M020 schema changes, NO M027 surface changes. The new `display_thresholds:` config block is M029-owned per AD-8 write-claim.
- **#Q-G8 canonical-form invariant**: ONLY `▽ saved Nk`. NO `▽ Nk saved`. NO `▽ saved Nk via tier1 cache reuse`. The verifier asserts both presence of the canonical form AND absence of the forbidden suffix.
- **#Q-1 full-re-render**: live-tail performs a full tree re-render on every appended `dispatch_usage` record. NO incremental row-update / row-tracking state. Tree size is bounded (<50 rows) so the cost is negligible per the spec's #Q-1 recommendation.
- **Path-collision rule 6**: `tools/verify/m029-p03-render-position-live-shape.sh` and `tools/verify/m029-p03-display-thresholds-config-shape.sh` do not exist on disk at plan-authoring time (verified 2026-05-06).

### Acceptance Criteria

This task addresses these P03 phase truths:
- `scripts/diagnostics/render-position.sh` carries an additive `--live` branch with the canonical compact-form `▽ saved Nk` marker (FR-7, FR-8, #Q-1, #Q-G8) gated by the AD-5 threshold knob.
- `references/file-formats.md` + `templates/orchestrator-config-default.yml` + `scripts/state/read-config.sh` document and surface the `display_thresholds.compression_savings_pct` knob (AD-5).

This task creates these P03 phase artifacts:
- `tools/verify/m029-p03-render-position-live-shape.sh`
- `tools/verify/m029-p03-display-thresholds-config-shape.sh`

### Files To Touch

- `scripts/diagnostics/render-position.sh` (modify)
- `references/file-formats.md` (modify)
- `templates/orchestrator-config-default.yml` (modify)
- `scripts/state/read-config.sh` (modify — VALID_KEYS extension only)
- `commands/auto.md` (modify)
- `commands/start.md` (modify)
- `scripts/lifecycle/start.sh` (modify)
- `specs/037-roadmap-visibility-cli-ux/spec.md` (modify — Spec Amendment Record entry)
- `tests/m029-acceptance/measure-live-tail-latency.sh` (create)
- `tests/m029-acceptance/p03-sc7-live-tail.sh` (create)
- `tests/m029-acceptance/p03-sc8-auto-preflight.sh` (create)
- `tests/m029-acceptance/p03-sc9-auto-quick-no-preflight.sh` (create)
- `tests/m029-acceptance/p03-sc10-auto-chain.sh` (create)
- `tests/m029-acceptance/p03-acceptance-battery.sh` (create)
- `tests/m029-acceptance/run-acceptance-battery.sh` (create)
- `tests/m029-acceptance/fixtures/auto-preflight-standard.fixture/` (create)
- `tests/m029-acceptance/fixtures/auto-preflight-quick.fixture/` (create)
- `tests/m029-acceptance/fixtures/auto-chain-greenfield.fixture/` (create)
- `tools/verify/m029-p03-render-position-live-shape.sh` (create)
- `tools/verify/m029-p03-display-thresholds-config-shape.sh` (create)
- `tools/verify/m029-p03-auto-preflight-shape.sh` (create)
- `tools/verify/m029-p03-auto-chain-shape.sh` (create)
- `tools/verify/m029-p03-measure-live-tail-latency-shape.sh` (create)
- `tools/verify/m029-p03-sc7-shape.sh` (create)
- `tools/verify/m029-p03-sc8-shape.sh` (create)
- `tools/verify/m029-p03-sc9-shape.sh` (create)
- `tools/verify/m029-p03-sc10-shape.sh` (create)
- `tools/verify/m029-p03-spec-amendment-shape.sh` (create)
- `tools/verify/m029-p03-acceptance-battery-shape.sh` (create)
- `tools/verify/m029-p03-run-acceptance-battery-shape.sh` (create)
- `tools/verify/m029-p03-readonly-invariant.sh` (create)
- `tools/verify/m029-p03-scope-guard.sh` (create)
- `tools/verify/m029-p03-phase-suite.sh` (create)
- `tools/verify/m029-p03-validate-milestone-pass.sh` (create)
- `tools/verify/m029-p03-closure-ceremony-shape.sh` (create)
- `.orchestrator/milestones/M029/M029-VALIDATED` (create)
- [`.orchestrator/milestones/M029/M029-SUMMARY.md`](../../../../../milestones/M029/M029-SUMMARY.md) (create)
- `.orchestrator/milestones/M029/execution-log.jsonl` (append milestone-grain `unit_close` event; existing file)

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