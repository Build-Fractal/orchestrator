---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T02-driver-and-preservation (Phase P02, Milestone M036)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~300 | required |
| Upstream Context | 981-1085 | ~5400 | required |
| Task Plan | 1087-1787 | ~6800 | required |
| State Context | 1789-1795 | ~100 | required |
| First-Turn Completeness | 1797-1849 | ~1000 | required |
| **Total** | | **~24400** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 732
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
hit_count: 732
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
hit_count: 732
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
hit_count: 732
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
hit_count: 639
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
hit_count: 639
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
hit_count: 639
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
hit_count: 732
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
hit_count: 639
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
hit_count: 639
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
hit_count: 639
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
hit_count: 732
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
hit_count: 732
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
hit_count: 732
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
hit_count: 639
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
hit_count: 639
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
hit_count: 639
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
hit_count: 732
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
hit_count: 639
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
hit_count: 639
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
hit_count: 732
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
hit_count: 732
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
hit_count: 639
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
hit_count: 639
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
hit_count: 639
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
hit_count: 294
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
hit_count: 294
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
hit_count: 294
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
hit_count: 308
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
hit_count: 308
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
hit_count: 298
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

<!-- Each Truth's Check is a single-script-file invocation (AD-19 / AP-009).
     All verifier slugs are milestone-prefixed (m036-p02-*) per the
     "milestone slug REQUIRED" naming convention. All verifiers live under
     tools/verify/ (project-owned, slug-bearing).

     Host-tooling-aware SKIP semantic: per-adapter verifiers (PDF, DOCX)
     probe `command -v` first and emit `SKIP: <tool>-absent` + exit 0 when
     the host tool is missing. The aggregator inspects exit code only; SKIP
     reports as PASS at the aggregator level. Mirrors the M036/P01 pattern. -->

- The manifest contract reference doc declares the required top-level + per-document fields and the summary-mode enum.
  - Check: `bash tools/verify/m036-p02-manifest-contract-shape.sh`
- The fixture manifest at `tests/fixtures/m036/extract-manifest.yaml` validates against the manifest contract (declares 3 documents covering `cms-rule`, `training-material`, `glossary` categories).
  - Check: `bash tools/verify/m036-p02-fixture-manifest-shape.sh`
- The 3-doc fixture corpus exists with one binary per format (PDF, DOCX, MD).
  - Check: `bash tools/verify/m036-p02-fixture-corpus-shape.sh`

<dispatch-volatile>

## Upstream Context


### P00 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P00"
parent: "M036"
milestone: "M036"
provides:
  - "taxonomy SSOT (4 categories),frontmatter contract (FR-2/FR-4/FR-5 fields),per-category default-tier YAML,3 shape verifiers under tools/verify/,edge-type SSOT (5 edges: cites/derived_from/applies_to_field new + relates_to/supersedes pre-existing),adapter registry TSV seam (4 stub rows: markdown/pdf/docx/xlsx),2 shape verifiers under tools/verify/,scope-tag namespace extension (source:cite_id row appended to file-formats.md Scope Tags + cross-reference paragraph in spec-management.md),chunk-frontmatter validator library (tools/verify/lib/p00-validate-chunk-frontmatter.sh — rejects out-of-taxonomy categories and out-of-tier-enum values),3 new verifiers + the 8-gate phase-suite aggregator under tools/verify/"
requires:
  - "none"
affects:
  - "P01,P02,P05"
key_files:
  - "references/reference-taxonomy.md,references/reference-frontmatter-contract.md,references/reference-source-types.yaml,tools/verify/p00-taxonomy-shape.sh,tools/verify/p00-frontmatter-contract-shape.sh,tools/verify/p00-source-types-shape.sh,references/reference-edge-types.md,scripts/dispatch/adapters/format/registry.tsv,tools/verify/p00-edge-types-shape.sh,tools/verify/p00-adapter-registry-shape.sh,references/file-formats.md,references/spec-management.md,tools/verify/lib/p00-validate-chunk-frontmatter.sh,tools/verify/p00-scope-tag-extension.sh,tools/verify/p00-spec-management-crossref.sh,tools/verify/p00-taxonomy-rejects-unknown.sh,tools/verify/m036-p00-phase-suite.sh"
key_decisions:
  - "none"
patterns_established:
  - "grep -qF token-loop shape verifier (single-script-file AD-19 shape); SSOT lockstep between reference-taxonomy.md keys and reference-source-types.yaml source_types: keys (Principle XI),runtime-constructed TAB via printf '\t' for tab-anchored grep patterns (resilient against editor space-conversion of verifier file itself); registry-row status=stub at declaration phase,status=live flip deferred to adapter-implementation phase (P01); SSOT lockstep between reference-edge-types.md heading list and reference-frontmatter-contract.md graph-edge field declarations (Principle XI),dual-write SSOT bridge (file-formats.md is the real scope-tag SSOT; spec-management.md cross-references it per roadmap directive without forking); validator-internal pipeline classifier-shape pass-through (grep-pipe-head-pipe-sed inside script body never surfaces to the harness shape-classifier because classify_command inspects only invocation form — single-script-file invocation classifies clean); phase-suite aggregator slot reuse (tools/verify/m036-p00-phase-suite.sh path was previously M031s; [M031](../../../../../milestones/M031/index.md) closed,M036 now owns the meta-aggregator slot while M031s individual sub-gates remain on disk under their slugged names); negative-test driver pattern (3 fixtures written to mktemp -d,validator invoked with each as path argument — avoids heredoc-feeding-pipe shapes AD-19 forbids)"
drill_down_paths:
  - "[.orchestrator/milestones/M036/phases/P00/tasks/T01-taxonomy-and-contract-SUMMARY.md](../../../../../milestones/M036/phases/P00/tasks/T01-taxonomy-and-contract-SUMMARY.md), [.orchestrator/milestones/M036/phases/P00/tasks/T02-edge-types-and-registry-SUMMARY.md](../../../../../milestones/M036/phases/P00/tasks/T02-edge-types-and-registry-SUMMARY.md), [.orchestrator/milestones/M036/phases/P00/tasks/T03-scope-tag-and-validator-SUMMARY.md](../../../../../milestones/M036/phases/P00/tasks/T03-scope-tag-and-validator-SUMMARY.md)"
duration: "70m"
verification_result: "pass"
completed_at: "2026-05-02T02:21:28Z"
observability_surfaces:
  - "none"
---

P00 (Foundation) lands the M036 reference-corpus declarative substrate as five SSOT artifacts plus the additive `[source:<cite_id>]` scope-tag namespace, plus a 9-verifier shape-check suite gated by `tools/verify/m036-p00-phase-suite.sh` (8 sub-gates wired through the aggregator + 1 negative-test driver). All artifacts ship as plain markdown / YAML / TSV — no executable scripts in P00's product surface beyond the verifiers themselves; the four format-adapter scripts the registry seam declares are P01 deliverables.

**What was built (across T01 + T02 + T03)**:

- T01 — Taxonomy + frontmatter contract + source-types tier-policy. `references/reference-taxonomy.md` declares the four categories (cms-rule, training-material, glossary, regulatory-doc) at level-3 headings with one-line definitions and example `cite_id` slugs. `references/reference-frontmatter-contract.md` enumerates required FR-2 fields, FR-4 chunk-output additions, and the five graph-edge-bearing fields (3 new in M036 + 2 pre-existing). `references/reference-source-types.yaml` carries the per-category default-tier policy (`cms-rule: 2`, `training-material: 2`, `glossary: 2`, `regulatory-doc: 1`) per spec #Q-8. Three single-script-file shape verifiers landed under `tools/verify/`.

- T02 — Edge-type SSOT + adapter registry seam. `references/reference-edge-types.md` is a NEW SSOT file declaring all five graph edges (3 new: `cites`, `derived_from`, `applies_to_field`; 2 pre-existing cross-referenced for completeness: `relates_to`, `supersedes`). The traverser at `scripts/knowledge/traverse-graph.sh` was deliberately NOT modified — refactoring it to read from this SSOT is P05's contract, scope-discipline-separated. `scripts/dispatch/adapters/format/registry.tsv` declares the adapter seam with all four format rows (markdown, pdf, docx, xlsx) at `status=stub`; P01 flips them to `status=live` when the adapter scripts land.

- T03 — Scope-tag namespace + chunk-frontmatter validator + phase-suite aggregator. Dual-write SSOT bridge: the `[source:<cite_id>]` row was appended to the actual SSOT (`references/file-formats.md` Scope Tags table) and a cross-reference paragraph was appended to `references/spec-management.md` (the roadmap's literal target) — Principle XI is honored without forking the SSOT. `tools/verify/lib/p00-validate-chunk-frontmatter.sh` is the load-bearing harness that mechanically rejects out-of-taxonomy categories and out-of-{0,1,2} tiers; the negative-test driver `tools/verify/p00-taxonomy-rejects-unknown.sh` exercises three fixtures (blog-post category rejected, tier 5 rejected, cms-rule + tier 2 accepted). The phase-suite aggregator (renamed mid-phase — see Forward Note below) wires all 8 sub-gates.

**Mid-phase orchestrator-layer correction (filename collision discovered + fixed)**: T03's planning called for the phase-suite aggregator at `tools/verify/p00-phase-suite.sh`. That path was already occupied by M031's P00 phase-suite (which itself had silently overwritten [M030](../../../../../milestones/M030/index.md)'s earlier). T03 honored the plan literally and overwrote M031's, then surfaced the collision as DONE_WITH_CONCERNS at task close. Mid-session correction:

1. Restored M031's content as `tools/verify/m031-p00-phase-suite.sh` (NEW file, recovered from git commit 428650d). M030's was lost weeks earlier and is not recoverable from git history at as-of-M030 state — separate paper-cut.
2. Renamed M036's aggregator to `tools/verify/m036-p00-phase-suite.sh` and updated its docstring + self-referencing SUMMARY line.
3. Updated T03 PLAN, T03 SUMMARY, and P00 PLAN references.
4. Tightened the planner contract in `commands/plan-phase.md`: (a) the verifier-naming discriminator example now uses a milestone-prefixed slug `m036-p01-foundation-bundle.sh` instead of the phase-only `p01-foundation-bundle.sh`; (b) a new "Naming convention — milestone slug REQUIRED for per-phase verifiers" rule prohibits unprefixed `p##-*` slugs going forward; (c) a new Plan-Time Discipline rule 6 (Path-collision check) requires planners to `ls -la` every declared `create` path before authoring and STOP if it already exists.

The contract change prevents this collision class going forward; the immediate damage to M031 is repaired. Other M036 P00 verifiers (the 7 sub-gate shape verifiers under unprefixed `p00-*` slugs) were left in place — their slugs are M036-unique by content and don't currently collide with anything; future-milestone hygiene will ratchet via the new contract rule.

**Verification result**: PASS at every gate. `tools/verify/m036-p00-phase-suite.sh` exits 0 with `SUMMARY: m036-p00-phase-suite.sh pass=8 fail=0`. Tier 1 must-haves (`scripts/verify/check-must-haves.sh`) all PASS — 9 truths, 17 artifact existence checks, 11 line-count checks, 18 artifact-content pattern checks, 7 key-link checks, all green after one mid-phase plan-pattern correction (`[source:` → `source:<cite_id>` to match the `references/file-formats.md` table-cell convention; two spurious spec→artifact key-links removed since the spec predates the artifacts).

**Forward-pointing notes**:
- (a) M030's `p00-phase-suite.sh` content was lost weeks before today's session when M031 silently overwrote it. The M030 README at `tests/fixtures/m030-classifier-corpus/README.md:167,189` still references the file under its original name. This is a stale reference but causes no live failure (M030 is closed; nothing re-runs that aggregator). Recommended cleanup: restore M030's content from its as-of-closure commit OR rename the M030 README references to `m030-p00-phase-suite.sh` even if the file content can't be recovered. Folds into the post-launch `tools/verify/` namespace cleanup proposal.
- (b) The other 7 unprefixed M036 P00 verifiers (`p00-taxonomy-shape.sh` etc.) are M036-content-unique today but live under a fragile namespace. Future milestones authoring under the new "milestone slug REQUIRED" rule won't add to the unprefixed bucket; a one-shot retroactive rename to `m036-p00-*` is queued as a small-batch follow-up.
- (c) The plan-time path-collision check (rule 6) is text-only at this point; a lint script that mechanically flags collisions in plan deliverables is a candidate for `scripts/diagnostics/check-plans.sh` extension.

P00 closes; P01 (Tier 1 live format adapters: pdf, docx, xlsx, markdown) and P05 (graph schema extension consuming `references/reference-edge-types.md`) are now dispatchable.


### P01 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M036"
milestone: "M036"
provides:
  - "tests/fixtures/m036-tier-1-adapters/ (4 sample binaries + 4 expected-output files),scripts/lifecycle/probe-extraction-tools.sh (host-tool probe; informational; exit 0),tools/verify/m036-p01-fixture-corpus-shape.sh (8-check verifier),tools/verify/m036-p01-probe-shape.sh (4-check verifier),markdown.sh adapter (passthrough cat),pdf.sh adapter (pdftotext -layout shell-out),registry.tsv markdown+pdf rows flipped from stub to live,m036-p01-markdown-adapter.sh verifier (2 checks: exit-0 + byte-identical),m036-p01-pdf-adapter.sh verifier (2 anchor checks + 5 token checks; host-tooling-aware skip when pdftotext absent),docx.sh adapter (pandoc -t plain shell-out),xlsx.sh adapter (bash wrapper delegating to lib/xlsx-to-csv.py),lib/xlsx-to-csv.py openpyxl shim (read_only mode + per-sheet CSV emission with deterministic sheet-name sanitization),registry.tsv docx+xlsx rows flipped from stub to live (combined with T02's flips all 4 rows now live),m036-p01-docx-adapter.sh verifier (token-allowlist shape with pandoc-absent SKIP),m036-p01-xlsx-adapter.sh verifier (byte-identity diff per sheet with openpyxl-absent SKIP),tests/test-tier-1-adapters.sh (SC-9 acceptance harness invoking all four real Tier 1 adapters against real binary fixtures with host-tooling-aware SKIP per adapter; emits BATTERY: pass=N fail=N skip=N summary line; exit 0 iff fail=0),tools/verify/m036-p01-registry-all-live.sh (registry contract verifier asserting all four formats at status=live via per-format awk single-script extraction),tools/verify/m036-p01-test-harness.sh (harness shape verifier asserting harness exists+executable+ran-to-completion+emitted-BATTERY-line; permissive on per-adapter PASS/SKIP counts so host-tooling absence does not false-FAIL),tools/verify/m036-p01-phase-suite.sh (8-gate aggregator wiring all M036 P01 sub-gates — fixture-corpus-shape + probe-shape + 4 per-adapter verifiers + registry-all-live + test-harness — patterned after m036-p00-phase-suite.sh)"
requires:
  - "P00"
affects:
  - "P02"
key_files:
  - "tests/fixtures/m036-tier-1-adapters/sample.md,tests/fixtures/m036-tier-1-adapters/sample.pdf,tests/fixtures/m036-tier-1-adapters/sample.docx,tests/fixtures/m036-tier-1-adapters/sample.xlsx,tests/fixtures/m036-tier-1-adapters/expected/sample-pdf.txt,tests/fixtures/m036-tier-1-adapters/expected/sample-docx.txt,tests/fixtures/m036-tier-1-adapters/expected/sample-xlsx-sheet1.csv,tests/fixtures/m036-tier-1-adapters/expected/sample-xlsx-sheet2.csv,scripts/lifecycle/probe-extraction-tools.sh,tools/verify/m036-p01-fixture-corpus-shape.sh,tools/verify/m036-p01-probe-shape.sh,scripts/dispatch/adapters/format/markdown.sh,scripts/dispatch/adapters/format/pdf.sh,scripts/dispatch/adapters/format/registry.tsv,tools/verify/m036-p01-markdown-adapter.sh,tools/verify/m036-p01-pdf-adapter.sh,scripts/dispatch/adapters/format/docx.sh,scripts/dispatch/adapters/format/xlsx.sh,scripts/dispatch/adapters/format/lib/xlsx-to-csv.py,tools/verify/m036-p01-docx-adapter.sh,tools/verify/m036-p01-xlsx-adapter.sh,tests/test-tier-1-adapters.sh,tools/verify/m036-p01-registry-all-live.sh,tools/verify/m036-p01-test-harness.sh,tools/verify/m036-p01-phase-suite.sh"
key_decisions:
  - "none"
patterns_established:
  - "hand-authored minimal PDF (5-object: catalog/pages/page/contents/font + xref) + minimal OOXML (zipfile stdlib only) generator pattern for binary fixtures on hosts without pandoc/openpyxl,probe-shape verifier captures stdout to TMPDIR file + four discrete grep -q anchor checks (avoids piped chains; AD-19 single-script-file shape),informational-only probe contract (exit 0 regardless; Hint-on-miss with one-line install suggestion; trailing SUMMARY: probe k=v line for downstream parsing),Tier 1 deterministic shell adapter shape -- input path as positional arg 1; stdout = extracted text; exit 0 success / 1 missing-input / 2 missing-host-tool; set -eu strict; bash 3.2 / POSIX-sh per CON-2; behavioral verifier shape -- capture adapter stdout to TMPDIR file; assert exit code; assert structural property (byte-identity for passthrough; token allowlist for lossy extractor); single-script-file invocation per AD-19 / AP-009; host-tooling-aware skip semantic -- verifier first probes command -v <tool> and emits SKIP: <tool>-absent + exit 0 informationally when missing (avoids false-FAIL on hosts lacking optional host tools); parallels the docx and xlsx verifier posture in T03; allowlist file format -- one token per line; blank lines + #-comment lines ignored; consumed via while IFS= read -r token loop; matched with grep -q -F (fixed-string) so no regex surprises with token characters,bash-wrapper-plus-python-shim adapter shape (xlsx.sh forwards to lib/xlsx-to-csv.py via python3 $shim $@ -- preserves CON-2 bash-3.2 compat for the shell entrypoint while letting the implementation use a richer language for binary-format parsing); two-gate host-tooling-aware skip (verifier probes BOTH command -v python3 AND python3 -c 'import openpyxl' before running the adapter -- bare-host typical state is python3-present + openpyxl-absent so probing only the binary would false-FAIL; the pattern is 'probe binary AND library' for any Python-library-dependent verifier); deterministic sheet-name sanitization for filesystem safety (re.sub(r'[/\\s]+','-',name).strip('-') -- whitespace and slash collapse to single dashes; trailing/leading dashes stripped; deterministic so verifier diff -q against expected files is reliable); openpyxl read_only=True + data_only=True load mode (memory-streaming for tens-of-thousands-of-rows regulatory sheets and formula-value resolution -- the production code path not a fixture-special); ImportError fallback with pipx and pip install hints on stderr (sys.exit(2) parallels the bash-side 'missing host tool' exit-2 contract -- caller can't tell whether the tool was missing at the binary or library layer; both look like exit 2),host-tooling-aware SKIP at the harness level (per-adapter case checks command -v tool or python3 -c import openpyxl BEFORE invoking the adapter; SKIP increments a separate counter that does not contribute to the fail count — the contract is fail=0 not skip=0; mirrors the per-adapter verifier shape from T02 m036-p01-pdf-adapter.sh and T03 m036-p01-xlsx-adapter.sh),BATTERY: pass=N fail=N skip=N output contract (machine-parseable single line; consumers grep for ^BATTERY: and parse pass= and fail= explicitly; exit 0 iff fail=0 regardless of skip count),permissive harness shape verifier (m036-p01-test-harness.sh accepts rc 0 or 1 as ran-to-completion since rc=1 is fail-mode-but-still-emitted-BATTERY whereas rc=2+ would be syntax/abort — captures shape contract without coupling to per-adapter pass count),per-format awk single-script extraction (awk -F TAB -v f=format dollar1==f print dollar3 registry.tsv — one tool one invocation no pipe; classifies clean under AD-19 / AP-009),8-gate phase-suite aggregator pattern reuse (m036-p00-phase-suite.sh used as template — same set -eu + run helper + SUMMARY: line format; per-adapter SKIPs at sub-gate verifier level still report PASS at aggregator level since aggregator inspects exit code only)"
drill_down_paths:
  - "[.orchestrator/milestones/M036/phases/P01/tasks/T01-fixtures-and-probe-SUMMARY.md](../../../../../milestones/M036/phases/P01/tasks/T01-fixtures-and-probe-SUMMARY.md), [.orchestrator/milestones/M036/phases/P01/tasks/T02-markdown-and-pdf-adapters-SUMMARY.md](../../../../../milestones/M036/phases/P01/tasks/T02-markdown-and-pdf-adapters-SUMMARY.md), [.orchestrator/milestones/M036/phases/P01/tasks/T03-docx-and-xlsx-adapters-SUMMARY.md](../../../../../milestones/M036/phases/P01/tasks/T03-docx-and-xlsx-adapters-SUMMARY.md), [.orchestrator/milestones/M036/phases/P01/tasks/T04-acceptance-harness-and-aggregator-SUMMARY.md](../../../../../milestones/M036/phases/P01/tasks/T04-acceptance-harness-and-aggregator-SUMMARY.md)"
duration: "110m"
verification_result: "pass"
completed_at: "2026-05-02T12:29:57Z"
observability_surfaces:
  - "none"
---

P01 delivers Tier 1 live format adapters for the four reference-corpus formats (markdown, pdf, docx, xlsx), plus the host-tool probe and SC-9 acceptance harness that downstream phases rely on. The four adapters land at `scripts/dispatch/adapters/format/` and follow a uniform CLI shape (single positional input path; stdout = body text; exit 0 = success; exit 2 = host tool missing with install hint via the probe). The registry at `scripts/dispatch/adapters/format/registry.tsv` flips all four rows from `status=stub` to `status=live`.

Four tasks delivered the surface:

- T01 authored the binary fixture corpus at `tests/fixtures/m036-tier-1-adapters/` (one sample per format, all under the 50KB CON-3 cap) plus expected-output files, and `scripts/lifecycle/probe-extraction-tools.sh` reporting host presence of `pdftotext`, `pandoc`, and `openpyxl` with install hints. DOCX and XLSX fixtures were generated as syntactically minimal OOXML packages via Python stdlib `zipfile` + manual XML literals (no host-tool dependency at fixture-author time — significant since pandoc was absent on the dev host).
- T02 implemented `markdown.sh` (pure passthrough via `cat`) and `pdf.sh` (shell-out to `pdftotext -layout`), flipping their registry rows to live. Live exercise on the dev host (pdftotext present) produced 9/9 verifier checks PASS.
- T03 implemented `docx.sh` (shell-out to `pandoc -t plain`) and `xlsx.sh` (delegates to `lib/xlsx-to-csv.py` openpyxl shim with `read_only=True`, deterministic sheet-name sanitization, and ImportError → exit-2-with-install-hint). Verifiers SKIP gracefully when host tools absent (the canonical pattern: probe `command -v <tool>`; emit `SKIP: <tool>-absent` + exit 0 informationally). Both T02 and T03 verifiers re-use the host-tooling-aware skip shape from M030/P05.
- T04 authored `tests/test-tier-1-adapters.sh` (SC-9 end-to-end harness), `tools/verify/m036-p01-registry-all-live.sh` (registry shape gate), `tools/verify/m036-p01-test-harness.sh` (harness wrapper), and `tools/verify/m036-p01-phase-suite.sh` (8-gate aggregator). On the dev host the SC-9 battery reports `BATTERY: pass=2 fail=0 skip=2` (markdown + pdf live; docx + xlsx SKIP); idempotent across consecutive runs (CON-4 guard via `diff -q`).

Plan-defect repair mid-phase: T03's plan included a raw `bash docx.sh sample.docx` Truth Check that would fail by design when pandoc is absent (documented exit 2 is the adapter's correct behavior). Patched the plan's Verification block to invoke only the host-aware verifier wrappers — the wrappers handle the skip; raw adapter calls are exercised inside the SC-9 harness (also host-aware). Knowledge: any Truth Check that depends on a host tool absent on CI hosts must invoke a SKIP-aware verifier wrapper, not the raw adapter.

Verification: 8/8 must-have truths PASS; 22/22 declared artifacts exist and pass min-line/contains gates; 8/8 key-link cross-references resolve; 8/8 phase-suite sub-gates green; SC-9 harness idempotent.

Patterns established (carried into downstream phases): host-tooling-aware verifier shape (probe → SKIP-with-install-hint pattern); adapter-CLI uniformity (single positional input; stdout body text; exit 0/1/2 with documented contracts; install hint in exit-2 stderr); openpyxl shim pattern for XLSX (Python stdlib + targeted dependency, deterministic sheet-name sanitization); milestone-prefixed verifier slugs (`m036-p01-*`) avoiding collision with M030's existing `tools/verify/p01-*.sh`; SC-9 acceptance-harness shape (`BATTERY: pass=N fail=N skip=N` summary line consumed by both phase-suite aggregator and operator-readable reports).

Forward notes: P02 (Tier 0 manifest + extract command) consumes T01's adapter registry to dispatch the right adapter per source-type. P03 (Tier 2 LLM extraction) consumes T01's probe output to gate Tier 2 attempts (no host tool → no extraction). P04 (ingest layer) consumes the structured outputs of T02–T04 adapters as input for chunk classification.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M036"
name: "Extract driver + manifest helper + binary-preservation helper + content-hash + size-cap external-pointer"
depends_on: ["T01"]
---

## Prerequisites

T01 must be complete:

- `references/extract-manifest-contract.md` — read by the driver to confirm field names; this task implements the parser logic.
- `tests/fixtures/m036/extract-manifest.yaml` — fixture manifest the driver runs against in verifiers.
- `tests/fixtures/m036/sample.{pdf,docx,md}` — fixture binaries.
- `.gitignore` already contains the `_originals/` line.

P00 + P01 prerequisites (already on disk before P02 began):

- `references/reference-source-types.yaml` (read by the driver to resolve missing `tier:` per category).
- `scripts/dispatch/adapters/format/registry.tsv` (read by the driver to resolve format → adapter path; T03 actually invokes them — T02 just authors the helper).
- `tools/verify/lib/p00-validate-chunk-frontmatter.sh` (executable; T03 wires defence-in-depth chunk validation).

Confirmed on disk at plan-authoring time.

## Description

Author the extract driver and its two pure helper libraries (manifest parsing + binary preservation). Implement content-hash gating, `_originals/` byte-identical preservation, and the size-cap external-pointer escape hatch. T03 layers the Tier 0 summary helper + Tier 1 adapter dispatch on top of this scaffold; T04 adds the SC-10 harness.

The driver is split into three files for testability:

- `scripts/knowledge/lib/extract-manifest.sh` — pure functions: parse manifest, iterate document records, expose accessors.
- `scripts/knowledge/lib/extract-binary-preservation.sh` — pure functions: compute sha256, copy binary into `_originals/<source>/<basename>`, evaluate size-cap, emit `external_pointer:` shape.
- `scripts/knowledge/extract-reference.sh` — driver that sources both helpers and orchestrates per-doc work.

Per MEM004 (Pure Lib Extraction Pattern): helpers are sourced; they take stdin/arguments, produce stdout, perform no top-level file I/O.

## Steps

### 1. Author `scripts/knowledge/lib/extract-manifest.sh`

```bash
#!/usr/bin/env bash
# scripts/knowledge/lib/extract-manifest.sh -- pure manifest parser.
# Sourced by scripts/knowledge/extract-reference.sh.
# No top-level I/O; functions take args + emit to stdout.
# Bash 3.2 / POSIX-sh per CON-2; no associative arrays, no jq required.

# extract_manifest_top_field <manifest-path> <field-name>
#   Echoes the value of a top-level scalar field (e.g., size_cap_bytes).
#   Empty stdout if absent.
extract_manifest_top_field() {
  local m="$1"
  local f="$2"
  grep -E "^${f}:" "$m" | head -n 1 | sed -E "s/^${f}:[[:space:]]*//" | sed -E 's/[[:space:]]*$//' | sed -E 's/^"//' | sed -E 's/"$//'
}

# extract_manifest_doc_count <manifest-path>
#   Echoes the count of YAML list entries under `documents:`.
extract_manifest_doc_count() {
  local m="$1"
  grep -cE '^[[:space:]]+-[[:space:]]+cite_id:' "$m"
}

# extract_manifest_doc_field <manifest-path> <doc-index-1based> <field-name>
#   Echoes the value of <field-name> within the Nth document record.
#   Implementation: awk one-liner that tracks the doc index and prints
#   the requested field within the matching record. Single-script-file
#   invocation shape (this is internal pipeline; classifier inspects
#   only the *invocation* of extract-reference.sh, not its helper bodies).
extract_manifest_doc_field() {
  local m="$1"
  local idx="$2"
  local field="$3"
  awk -v idx="$idx" -v field="$field" '
    BEGIN { current=0 }
    /^[[:space:]]+-[[:space:]]+cite_id:/ { current++ }
    current==idx {
      if (match($0, "^[[:space:]]+(-[[:space:]]+)?" field ":")) {
        line=$0
        sub("^[[:space:]]*-?[[:space:]]*" field ":[[:space:]]*", "", line)
        sub("[[:space:]]+$", "", line)
        sub("^\"", "", line); sub("\"$", "", line)
        print line
        exit
      }
    }
  ' "$m"
}

# extract_manifest_resolve_tier <category> <source-types-yaml-path>
#   Echoes the default tier for a category from the source-types SSOT.
extract_manifest_resolve_tier() {
  local cat="$1"
  local yaml="$2"
  awk -v cat="$cat" '
    $0 ~ "^  " cat ":" { found=1; next }
    found && /^    default_tier:/ { sub("^[[:space:]]*default_tier:[[:space:]]*", ""); print; exit }
  ' "$yaml"
}
```

### 2. Author `scripts/knowledge/lib/extract-binary-preservation.sh`

```bash
#!/usr/bin/env bash
# scripts/knowledge/lib/extract-binary-preservation.sh -- pure helpers
# for binary preservation, sha256, and size-cap policy. Sourced by
# scripts/knowledge/extract-reference.sh. No top-level I/O.
# Bash 3.2 / POSIX-sh per CON-2.

# preservation_sha256 <path>
#   Echoes the sha256 hex digest of <path>.
#   Probes shasum (BSD/macOS) then sha256sum (GNU/Linux). Errors clearly
#   if neither present.
preservation_sha256() {
  local p="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$p" | awk '{print $1}'
    return 0
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$p" | awk '{print $1}'
    return 0
  fi
  echo "preservation_sha256: neither shasum nor sha256sum on PATH" >&2
  return 1
}

# preservation_size_bytes <path>
#   Echoes the size in bytes. POSIX wc -c.
preservation_size_bytes() {
  local p="$1"
  wc -c < "$p" | tr -d ' '
}

# preservation_copy_under_originals <source-path> <source-id> <originals-root>
#   Copies <source-path> to <originals-root>/<source-id>/<basename>.
#   Idempotent: if destination exists with matching sha256, skips silently.
preservation_copy_under_originals() {
  local src="$1"
  local sid="$2"
  local root="$3"
  local dest_dir="$root/$sid"
  local dest="$dest_dir/$(basename "$src")"
  mkdir -p "$dest_dir"
  if [ -f "$dest" ]; then
    local h_src
    local h_dst
    h_src=$(preservation_sha256 "$src")
    h_dst=$(preservation_sha256 "$dest")
    if [ "$h_src" = "$h_dst" ]; then
      return 0
    fi
  fi
  cp "$src" "$dest"
}

# preservation_above_cap <path> <size-cap-bytes>
#   Returns 0 (true) if file size > cap; 1 otherwise.
preservation_above_cap() {
  local p="$1"
  local cap="$2"
  local sz
  sz=$(preservation_size_bytes "$p")
  if [ "$sz" -gt "$cap" ]; then
    return 0
  fi
  return 1
}

# preservation_external_pointer_shape <source-path>
#   Echoes the external_pointer YAML scalar to embed in chunk frontmatter
#   when binary is above cap. Currently emits the absolute source path;
#   future iterations may accept S3 URLs or other URI schemes (#Q-9).
preservation_external_pointer_shape() {
  local p="$1"
  local abs
  abs=$(cd "$(dirname "$p")" && pwd)/$(basename "$p")
  printf 'file://%s\n' "$abs"
}
```

### 3. Author `scripts/knowledge/extract-reference.sh`

```bash
#!/usr/bin/env bash
# scripts/knowledge/extract-reference.sh -- M036 P02 driver for
# orchestrator:extract synchronous Tier 0/1 path. Reads a manifest,
# iterates documents, computes content_hash, preserves binaries under
# .orchestrator/knowledge/reference/_originals/, emits Tier 1 plain-text
# files (T03 wires the adapter call), and writes Tier 0 chunk files.
#
# Usage:
#   scripts/knowledge/extract-reference.sh --manifest <path>
#                                          [--reference-root <path>]
#                                          [--originals-root <path>]
#                                          [--summary-mode <operator|stub|auto>]
#                                          [--size-cap-bytes <int>]
#
# Output contract (stdout):
#   EXTRACTED: <cite_id> tier=<n> bytes=<n> hash=<sha256-prefix>
#   SKIPPED:   <cite_id> reason=<unchanged|external-pointer>
# Errors to stderr; non-zero exit on any error.
#
# Bash 3.2 / POSIX-sh per CON-2. Idempotent (CON-4): re-running on
# unchanged inputs produces zero modifications.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="${ORCHESTRATOR_ROOT:-$(cd "$HERE/../.." && pwd)}"

# shellcheck disable=SC1091
. "$HERE/lib/extract-manifest.sh"
# shellcheck disable=SC1091
. "$HERE/lib/extract-binary-preservation.sh"
# shellcheck disable=SC1091
. "$HERE/lib/extract-tier-0-summary.sh"   # authored in T03

MANIFEST=""
REF_ROOT="$ROOT/knowledge/reference"
ORIGINALS_ROOT="$ROOT/.orchestrator/knowledge/reference/_originals"
SUMMARY_MODE_OVERRIDE=""
SIZE_CAP_OVERRIDE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --manifest) MANIFEST="$2"; shift 2 ;;
    --reference-root) REF_ROOT="$2"; shift 2 ;;
    --originals-root) ORIGINALS_ROOT="$2"; shift 2 ;;
    --summary-mode) SUMMARY_MODE_OVERRIDE="$2"; shift 2 ;;
    --size-cap-bytes) SIZE_CAP_OVERRIDE="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,16p' "$0"
      exit 0
      ;;
    *)
      echo "extract-reference.sh: unknown flag: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$MANIFEST" ] || [ ! -f "$MANIFEST" ]; then
  echo "extract-reference.sh: --manifest <path> required (got: '$MANIFEST')" >&2
  exit 1
fi

MANIFEST_DIR="$(cd "$(dirname "$MANIFEST")" && pwd)"

SIZE_CAP="$(extract_manifest_top_field "$MANIFEST" size_cap_bytes)"
if [ -z "$SIZE_CAP" ]; then SIZE_CAP=10485760; fi
if [ -n "$SIZE_CAP_OVERRIDE" ]; then SIZE_CAP="$SIZE_CAP_OVERRIDE"; fi

SOURCE_TYPES_YAML="$ROOT/references/reference-source-types.yaml"
REGISTRY_TSV="$ROOT/scripts/dispatch/adapters/format/registry.tsv"

DOC_COUNT="$(extract_manifest_doc_count "$MANIFEST")"
i=1
while [ "$i" -le "$DOC_COUNT" ]; do
  cite_id=$(extract_manifest_doc_field "$MANIFEST" "$i" cite_id)
  source_path_rel=$(extract_manifest_doc_field "$MANIFEST" "$i" source_path)
  category=$(extract_manifest_doc_field "$MANIFEST" "$i" category)
  source=$(extract_manifest_doc_field "$MANIFEST" "$i" source)
  tier=$(extract_manifest_doc_field "$MANIFEST" "$i" tier)
  summary_mode=$(extract_manifest_doc_field "$MANIFEST" "$i" summary_mode)
  size_cap_override_doc=$(extract_manifest_doc_field "$MANIFEST" "$i" size_cap_bytes_override)

  if [ -z "$tier" ]; then
    tier=$(extract_manifest_resolve_tier "$category" "$SOURCE_TYPES_YAML")
  fi
  if [ -z "$summary_mode" ]; then summary_mode="operator"; fi
  if [ -n "$SUMMARY_MODE_OVERRIDE" ]; then summary_mode="$SUMMARY_MODE_OVERRIDE"; fi

  effective_cap="$SIZE_CAP"
  if [ -n "$size_cap_override_doc" ]; then effective_cap="$size_cap_override_doc"; fi

  # Resolve source binary
  if [ "${source_path_rel#/}" != "$source_path_rel" ]; then
    src_abs="$source_path_rel"
  else
    src_abs="$MANIFEST_DIR/$source_path_rel"
  fi
  if [ ! -f "$src_abs" ]; then
    echo "extract-reference.sh: source not found for $cite_id at $src_abs" >&2
    exit 1
  fi

  hash=$(preservation_sha256 "$src_abs")
  size=$(preservation_size_bytes "$src_abs")

  # Chunk path
  chunk_dir="$REF_ROOT/$category"
  chunk_file="$chunk_dir/REF-${category}-${cite_id}.md"
  mkdir -p "$chunk_dir"

  # Idempotency gate: if existing chunk has matching content_hash, SKIP.
  if [ -f "$chunk_file" ]; then
    prior=$(grep -E '^content_hash:' "$chunk_file" | head -n 1 | sed -E 's/^content_hash:[[:space:]]*//' | tr -d '"')
    if [ "$prior" = "$hash" ]; then
      echo "SKIPPED: $cite_id reason=unchanged"
      i=$((i + 1))
      continue
    fi
  fi

  # Binary preservation OR external pointer
  external_pointer=""
  if preservation_above_cap "$src_abs" "$effective_cap"; then
    external_pointer=$(preservation_external_pointer_shape "$src_abs")
  else
    preservation_copy_under_originals "$src_abs" "$source" "$ORIGINALS_ROOT"
  fi

  # Tier 1 leg: invoke registry-resolved adapter when tier >= 1.
  # T03 fills this in (currently no-op stub here).
  text_file=""
  if [ "$tier" -ge 1 ]; then
    text_file="$chunk_dir/REF-${category}-${cite_id}.text.md"
    extract_tier_1_via_registry "$src_abs" "$text_file" "$REGISTRY_TSV" || {
      echo "extract-reference.sh: Tier 1 adapter dispatch failed for $cite_id" >&2
      exit 1
    }
  fi

  # Tier 0 summary (T03 helper).
  operator_summary=$(extract_manifest_doc_field "$MANIFEST" "$i" summary)
  summary_text=$(generate_tier_0_summary "$summary_mode" "$category" "$cite_id" "$operator_summary" "$tier") || {
    echo "extract-reference.sh: summary generation failed for $cite_id" >&2
    exit 1
  }

  # Emit chunk frontmatter + body.
  {
    printf -- "---\n"
    printf 'schema_version: "1.0"\n'
    printf 'type: reference-chunk\n'
    printf 'milestone: "M036"\n'
    printf 'category: "%s"\n' "$category"
    printf 'chunk_id: "REF-%s-%s"\n' "$category" "$cite_id"
    printf 'cite_id: "%s"\n' "$cite_id"
    printf 'source: "%s"\n' "$source"
    printf 'published: "%s"\n' "$(extract_manifest_doc_field "$MANIFEST" "$i" published)"
    printf 'version: "%s"\n' "$(extract_manifest_doc_field "$MANIFEST" "$i" version)"
    printf 'tier: %s\n' "$tier"
    printf 'content_hash: "%s"\n' "$hash"
    printf 'size_bytes: %s\n' "$size"
    if [ -n "$external_pointer" ]; then
      printf 'external_pointer: "%s"\n' "$external_pointer"
    fi
    printf 'summary_mode: "%s"\n' "$summary_mode"
    printf -- "---\n\n"
    printf '%s\n' "$summary_text"
  } > "$chunk_file"

  echo "EXTRACTED: $cite_id tier=$tier bytes=$size hash=${hash%${hash#????????}}"
  i=$((i + 1))
done
exit 0
```

**Note**: The script body uses `grep | head | sed` and `awk` pipelines internally. These are legal: AD-19's classifier inspects only the *invocation* of the script (`bash scripts/knowledge/extract-reference.sh ...` — single-script-file shape), not the body. Per MEM031 "validator-internal pipeline classifier-shape pass-through" pattern from M036/P00 T03.

The driver references `extract_tier_1_via_registry` and `generate_tier_0_summary` which are **T03 deliverables** in `lib/extract-tier-0-summary.sh`. T02 lands the driver scaffold; T03 fills in the helper functions. The driver will fail to source `lib/extract-tier-0-summary.sh` until T03 lands, so T02's verifiers do NOT execute the driver — they exercise shape-only checks. Behavioural verifiers land in T03 and T04.

### 4. Make scripts executable

```bash
chmod +x scripts/knowledge/extract-reference.sh \
         scripts/knowledge/lib/extract-manifest.sh \
         scripts/knowledge/lib/extract-binary-preservation.sh
```

### 5. Author `tools/verify/m036-p02-extract-driver-shape.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p02-extract-driver-shape.sh -- M036 P02 T02.
# Asserts the extract driver exists, executable, declares --manifest,
# and sources the two T02 lib helpers.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
DRV="$ROOT/scripts/knowledge/extract-reference.sh"
LIB1="$ROOT/scripts/knowledge/lib/extract-manifest.sh"
LIB2="$ROOT/scripts/knowledge/lib/extract-binary-preservation.sh"
fail=0
checkfile() {
  local p="$1"
  if [ -f "$p" ] && [ -x "$p" ]; then
    echo "PASS: exists+executable $p"
  else
    echo "FAIL: missing or non-executable $p"
    fail=$((fail + 1))
  fi
}
checkfile "$DRV"
checkfile "$LIB1"
checkfile "$LIB2"
checkpat() {
  local p="$1"
  local pat="$2"
  if grep -qF "$pat" "$p"; then
    echo "PASS: '$pat' in $(basename "$p")"
  else
    echo "FAIL: '$pat' missing in $(basename "$p")"
    fail=$((fail + 1))
  fi
}
checkpat "$DRV" "--manifest"
checkpat "$DRV" "EXTRACTED:"
checkpat "$DRV" "SKIPPED:"
checkpat "$DRV" "extract-manifest.sh"
checkpat "$DRV" "extract-binary-preservation.sh"
checkpat "$LIB1" "extract_manifest_doc_count"
checkpat "$LIB2" "preservation_sha256"
echo "SUMMARY: m036-p02-extract-driver-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### 6. Author `tools/verify/m036-p02-binary-preservation.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p02-binary-preservation.sh -- M036 P02 T02.
# Drives the extract driver against the fixture manifest in a temp
# workspace and asserts that each binary appears byte-identical under
# _originals/<source>/<filename>. Host-tooling-aware SKIP if the
# Tier 1 leg fails because pdftotext/pandoc absent (binary preservation
# is independent of Tier 1 dispatch, but the driver bails on adapter
# failure -- so we treat host-tool absence as SKIP for this verifier).
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p02-bp.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
DRV="$ROOT/scripts/knowledge/extract-reference.sh"
MANIFEST="$ROOT/tests/fixtures/m036/extract-manifest.yaml"

# Host-tooling probe: this verifier runs the driver end-to-end; bail
# clean if Tier 1 host tools absent.
if ! command -v pdftotext >/dev/null 2>&1; then
  echo "SKIP: pdftotext-absent"
  exit 0
fi
if ! command -v pandoc >/dev/null 2>&1; then
  echo "SKIP: pandoc-absent"
  exit 0
fi

# Run driver in temp workspace.
ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" \
  --manifest "$MANIFEST" \
  --reference-root "$WORK/knowledge/reference" \
  --originals-root "$WORK/_originals" \
  >/dev/null 2>"$WORK/stderr.txt" || {
    echo "FAIL: driver exited non-zero"
    cat "$WORK/stderr.txt" >&2
    exit 1
  }

# Three originals expected -- under <source>/<filename>.
fail=0
checkbyte() {
  local src="$1"
  local sid="$2"
  local base="$3"
  local dest="$WORK/_originals/$sid/$base"
  if [ ! -f "$dest" ]; then
    echo "FAIL: missing $dest"
    fail=$((fail + 1))
    return
  fi
  if cmp -s "$src" "$dest"; then
    echo "PASS: byte-identical $sid/$base"
  else
    echo "FAIL: byte-differ $sid/$base"
    fail=$((fail + 1))
  fi
}
checkbyte "$ROOT/tests/fixtures/m036/sample.pdf"  "cms"               "sample.pdf"
checkbyte "$ROOT/tests/fixtures/m036/sample.docx" "sme-pbj-circle"    "sample.docx"
checkbyte "$ROOT/tests/fixtures/m036/sample.md"   "internal-glossary" "sample.md"
echo "SUMMARY: m036-p02-binary-preservation.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### 7. Author `tools/verify/m036-p02-content-hash.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p02-content-hash.sh -- M036 P02 T02.
# Drives the extract driver against the fixture manifest and asserts
# each emitted chunk's content_hash frontmatter equals shasum -a 256
# of the source binary.
# Host-tooling-aware SKIP if pdftotext/pandoc absent.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p02-ch.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
DRV="$ROOT/scripts/knowledge/extract-reference.sh"
MANIFEST="$ROOT/tests/fixtures/m036/extract-manifest.yaml"

if ! command -v pdftotext >/dev/null 2>&1; then echo "SKIP: pdftotext-absent"; exit 0; fi
if ! command -v pandoc    >/dev/null 2>&1; then echo "SKIP: pandoc-absent"; exit 0; fi

ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" \
  --manifest "$MANIFEST" \
  --reference-root "$WORK/knowledge/reference" \
  --originals-root "$WORK/_originals" \
  >/dev/null 2>&1 || { echo "FAIL: driver exited non-zero"; exit 1; }

fail=0
verify_hash() {
  local src="$1"
  local chunk="$2"
  local actual
  local frontmatter
  actual=$(shasum -a 256 "$src" | awk '{print $1}')
  frontmatter=$(grep -E '^content_hash:' "$chunk" | head -n 1 | sed -E 's/^content_hash:[[:space:]]*//' | tr -d '"')
  if [ "$actual" = "$frontmatter" ]; then
    echo "PASS: hash matches for $(basename "$chunk")"
  else
    echo "FAIL: hash mismatch for $(basename "$chunk") (src=$actual frontmatter=$frontmatter)"
    fail=$((fail + 1))
  fi
}
verify_hash "$ROOT/tests/fixtures/m036/sample.pdf"  "$WORK/knowledge/reference/cms-rule/REF-cms-rule-cms-rule-fixture-01.md"
verify_hash "$ROOT/tests/fixtures/m036/sample.docx" "$WORK/knowledge/reference/training-material/REF-training-material-training-pbj-fixture-01.md"
verify_hash "$ROOT/tests/fixtures/m036/sample.md"   "$WORK/knowledge/reference/glossary/REF-glossary-glossary-fixture-01.md"
echo "SUMMARY: m036-p02-content-hash.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### 8. Author `tools/verify/m036-p02-size-cap-external-pointer.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p02-size-cap-external-pointer.sh -- M036 P02 T02.
# Stages a synthetic single-doc manifest in a temp workspace whose
# size_cap_bytes=1 forces the source binary above the cap. Asserts the
# emitted chunk frontmatter contains an external_pointer: line and the
# binary is NOT copied under _originals/.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p02-cap.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
DRV="$ROOT/scripts/knowledge/extract-reference.sh"

# Stage a 1-doc manifest with cap=1 against the markdown fixture.
cp "$ROOT/tests/fixtures/m036/sample.md" "$WORK/sample.md"
cat > "$WORK/manifest.yaml" <<'YAML'
schema_version: "1.0"
type: extract-manifest
milestone: "M036"
size_cap_bytes: 1

documents:
  - cite_id: "size-cap-fixture-01"
    source_path: "sample.md"
    category: "glossary"
    source: "test"
    published: "2026-05-02"
    version: "test"
    topic_tags: []
    applies_to_field: []
    tier: 0
    summary_mode: "stub"
YAML

ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" \
  --manifest "$WORK/manifest.yaml" \
  --reference-root "$WORK/knowledge/reference" \
  --originals-root "$WORK/_originals" \
  >"$WORK/stdout.txt" 2>"$WORK/stderr.txt" || {
    echo "FAIL: driver exited non-zero"
    cat "$WORK/stderr.txt" >&2
    exit 1
  }

fail=0
chunk="$WORK/knowledge/reference/glossary/REF-glossary-size-cap-fixture-01.md"
if [ ! -f "$chunk" ]; then
  echo "FAIL: chunk not emitted at $chunk"
  exit 1
fi
if grep -qE '^external_pointer:' "$chunk"; then
  echo "PASS: external_pointer recorded in chunk"
else
  echo "FAIL: external_pointer missing in chunk"
  fail=$((fail + 1))
fi
if [ -f "$WORK/_originals/test/sample.md" ]; then
  echo "FAIL: binary was copied despite above-cap"
  fail=$((fail + 1))
else
  echo "PASS: binary not copied (above cap)"
fi
echo "SUMMARY: m036-p02-size-cap-external-pointer.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### 9. Make verifiers executable

```bash
chmod +x tools/verify/m036-p02-extract-driver-shape.sh \
         tools/verify/m036-p02-binary-preservation.sh \
         tools/verify/m036-p02-content-hash.sh \
         tools/verify/m036-p02-size-cap-external-pointer.sh
```

## Must-Haves

This task addresses:

- The extract driver `scripts/knowledge/extract-reference.sh` exists, executable, accepts `--manifest <path>`, sources the lib helpers.
- Running the driver against the fixture manifest preserves each binary at `_originals/<source>/<filename>` byte-identical to the source.
- Each emitted chunk's `content_hash` frontmatter field matches `shasum -a 256` of the source binary.
- A document above the size cap records `external_pointer:` and is NOT copied under `_originals/`.

## Verification

```bash
bash tools/verify/m036-p02-extract-driver-shape.sh
bash tools/verify/m036-p02-binary-preservation.sh
bash tools/verify/m036-p02-content-hash.sh
bash tools/verify/m036-p02-size-cap-external-pointer.sh
```

## Inputs

### From Previous Tasks

- `tests/fixtures/m036/extract-manifest.yaml` (from T01) — fixture manifest.
  - Key API: read by the driver via `lib/extract-manifest.sh` accessors (`extract_manifest_doc_count`, `extract_manifest_doc_field`).
  - Key types: YAML; per-doc record fields (`cite_id`, `source_path`, `category`, `source`, `published`, `version`, `tier`, `summary_mode`, `summary`, `topic_tags`, `applies_to_field`).
- `tests/fixtures/m036/sample.{pdf,docx,md}` (from T01) — fixture binaries.
- `references/extract-manifest-contract.md` (from T01) — schema documented.

### From Disk (Pre-existing)

- `references/reference-source-types.yaml` — used: driver resolves missing `tier:` per category via `extract_manifest_resolve_tier`.
- `scripts/dispatch/adapters/format/registry.tsv` — used: driver reads adapter path per format (T03 invokes; T02 just declares the seam).
- `shasum -a 256` (BSD/macOS) or `sha256sum` (GNU/Linux) — used by `preservation_sha256`.

## Constraints

- Bash 3.2 / POSIX-sh per CON-2. No `declare -A`. No process substitution. No `(...)` subshells in invocation lines.
- Pure-lib pattern (MEM004): helper sources do no top-level I/O; functions take args and return via stdout / exit code.
- Driver invocation uses single-script-file shape per AD-19; internal pipelines (`grep | head | sed`, `awk`) are legal inside the script body.
- Idempotency (CON-4): re-running with unchanged inputs is a no-op (content-hash gate inside the driver loop).
- Binary preservation governance (CON-7): `_originals/` lives under `.orchestrator/knowledge/reference/` (gitignored — line landed in T01).
- Driver references T03 functions (`extract_tier_1_via_registry`, `generate_tier_0_summary`) — verifier runs the driver end-to-end, so the verifiers `m036-p02-binary-preservation.sh`, `m036-p02-content-hash.sh`, and `m036-p02-size-cap-external-pointer.sh` only PASS once T03 has landed. **Order discipline: this task's verifiers will FAIL until T03 also lands**. Plan-time mitigation: T02 ships the lib helpers + driver scaffold; T04's phase-suite gate is what guarantees end-to-end PASS at phase close. (Per Plan-Time Discipline rule 2: cross-task verifier dependencies are rejected — the resolution here is that T02's verifiers exercise behavioural properties that need T03's helper, but the verifiers are *authored* in T02 alongside the code-they-test. They will be re-run after T03 closes; the auto-loop's first-fail-retry semantics handle the ordering at execute time. The shape verifier `m036-p02-extract-driver-shape.sh` PASSes immediately on T02 close because it inspects file shape only.)

## Notes

Order discipline rationale (cross-task expectation):

- T02 deliverables `extract-driver-shape.sh` PASS at T02 close (shape-only).
- T02 deliverables `binary-preservation.sh`, `content-hash.sh`, `size-cap-external-pointer.sh` are *authored* in T02 but become green only after T03 lands the summary helper that the driver sources.
- The phase-suite aggregator (T04) is what gates end-to-end PASS for the entire phase. This is the standard auto-loop pattern: per-task verifiers are written alongside the code they test; phase-level closure waits for all sub-gates to go green.

Expected verifier output on success:

- `m036-p02-extract-driver-shape.sh` → `SUMMARY: m036-p02-extract-driver-shape.sh fail=0`, exit 0.
- `m036-p02-binary-preservation.sh` → `SUMMARY: m036-p02-binary-preservation.sh fail=0`, exit 0 (or `SKIP:` lines + exit 0 on pdftotext/pandoc-absent hosts).
- `m036-p02-content-hash.sh` → `SUMMARY: m036-p02-content-hash.sh fail=0`, exit 0 (same SKIP semantic).
- `m036-p02-size-cap-external-pointer.sh` → `SUMMARY: m036-p02-size-cap-external-pointer.sh fail=0`, exit 0 (no host-tool dep — markdown-only).

## Expected Output

Files created:

- `scripts/knowledge/extract-reference.sh` (~120 lines, executable)
- `scripts/knowledge/lib/extract-manifest.sh` (~50 lines, executable for sourceability)
- `scripts/knowledge/lib/extract-binary-preservation.sh` (~50 lines, executable for sourceability)
- `tools/verify/m036-p02-extract-driver-shape.sh`
- `tools/verify/m036-p02-binary-preservation.sh`
- `tools/verify/m036-p02-content-hash.sh`
- `tools/verify/m036-p02-size-cap-external-pointer.sh`

## State Context

- **Current State**: executing
- **Milestone**: M036
- **Phase**: P02
- **Task**: T02-driver-and-preservation
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- Bash 3.2 / POSIX-sh per CON-2. No `declare -A`. No process substitution. No `(...)` subshells in invocation lines.
- Pure-lib pattern (MEM004): helper sources do no top-level I/O; functions take args and return via stdout / exit code.
- Driver invocation uses single-script-file shape per AD-19; internal pipelines (`grep | head | sed`, `awk`) are legal inside the script body.
- Idempotency (CON-4): re-running with unchanged inputs is a no-op (content-hash gate inside the driver loop).
- Binary preservation governance (CON-7): `_originals/` lives under `.orchestrator/knowledge/reference/` (gitignored — line landed in T01).
- Driver references T03 functions (`extract_tier_1_via_registry`, `generate_tier_0_summary`) — verifier runs the driver end-to-end, so the verifiers `m036-p02-binary-preservation.sh`, `m036-p02-content-hash.sh`, and `m036-p02-size-cap-external-pointer.sh` only PASS once T03 has landed. **Order discipline: this task's verifiers will FAIL until T03 also lands**. Plan-time mitigation: T02 ships the lib helpers + driver scaffold; T04's phase-suite gate is what guarantees end-to-end PASS at phase close. (Per Plan-Time Discipline rule 2: cross-task verifier dependencies are rejected — the resolution here is that T02's verifiers exercise behavioural properties that need T03's helper, but the verifiers are *authored* in T02 alongside the code-they-test. They will be re-run after T03 closes; the auto-loop's first-fail-retry semantics handle the ordering at execute time. The shape verifier `m036-p02-extract-driver-shape.sh` PASSes immediately on T02 close because it inspects file shape only.)

### Acceptance Criteria

This task addresses:

- The extract driver `scripts/knowledge/extract-reference.sh` exists, executable, accepts `--manifest <path>`, sources the lib helpers.
- Running the driver against the fixture manifest preserves each binary at `_originals/<source>/<filename>` byte-identical to the source.
- Each emitted chunk's `content_hash` frontmatter field matches `shasum -a 256` of the source binary.
- A document above the size cap records `external_pointer:` and is NOT copied under `_originals/`.

### Files To Touch

- `commands/extract.md` (create)
- `scripts/knowledge/extract-reference.sh` (create)
- `scripts/knowledge/lib/extract-manifest.sh` (create)
- `scripts/knowledge/lib/extract-binary-preservation.sh` (create)
- `scripts/knowledge/lib/extract-tier-0-summary.sh` (create)
- `references/extract-manifest-contract.md` (create)
- `tests/fixtures/m036/extract-manifest.yaml` (create)
- `tests/fixtures/m036/sample.pdf` (create — byte-copy from `tests/fixtures/m036-tier-1-adapters/sample.pdf`)
- `tests/fixtures/m036/sample.docx` (create — byte-copy from `tests/fixtures/m036-tier-1-adapters/sample.docx`)
- `tests/fixtures/m036/sample.md` (create)
- `tests/test-tier-0-manifest.sh` (create)
- `.gitignore` (modify — append `.orchestrator/knowledge/reference/_originals/` line per CON-7 (b))
- `tools/verify/m036-p02-manifest-contract-shape.sh` (create)
- `tools/verify/m036-p02-fixture-manifest-shape.sh` (create)
- `tools/verify/m036-p02-fixture-corpus-shape.sh` (create)
- `tools/verify/m036-p02-extract-driver-shape.sh` (create)
- `tools/verify/m036-p02-binary-preservation.sh` (create)
- `tools/verify/m036-p02-content-hash.sh` (create)
- `tools/verify/m036-p02-size-cap-external-pointer.sh` (create)
- `tools/verify/m036-p02-extract-md.sh` (create)
- `tools/verify/m036-p02-extract-pdf-host-aware.sh` (create)
- `tools/verify/m036-p02-extract-docx-host-aware.sh` (create)
- `tools/verify/m036-p02-idempotency.sh` (create)
- `tools/verify/m036-p02-extract-command-shape.sh` (create)
- `tools/verify/m036-p02-summary-mode-stub-vs-operator.sh` (create)
- `tools/verify/m036-p02-tier-2-deferred-error.sh` (create)
- `tools/verify/m036-p02-test-harness.sh` (create)
- `tools/verify/m036-p02-phase-suite.sh` (create)

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