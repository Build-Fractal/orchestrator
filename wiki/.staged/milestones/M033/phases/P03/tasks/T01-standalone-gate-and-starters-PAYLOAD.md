---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T01-standalone-gate-and-starters (Phase P03, Milestone M033)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~300 | required |
| Upstream Context | 981-1134 | ~6400 | required |
| Task Plan | 1136-1318 | ~4200 | required |
| State Context | 1320-1326 | ~100 | required |
| First-Turn Completeness | 1328-1394 | ~1200 | required |
| **Total** | | **~23000** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 791
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
hit_count: 791
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
hit_count: 791
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
hit_count: 791
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
hit_count: 689
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
hit_count: 689
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
hit_count: 689
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
hit_count: 791
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
hit_count: 689
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
hit_count: 689
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
hit_count: 689
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
hit_count: 791
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
hit_count: 791
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
hit_count: 791
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
hit_count: 689
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
hit_count: 689
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
hit_count: 689
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
hit_count: 791
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
hit_count: 689
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
hit_count: 689
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
hit_count: 791
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
hit_count: 791
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
hit_count: 689
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
hit_count: 689
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
hit_count: 689
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
hit_count: 344
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
hit_count: 344
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
hit_count: 344
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
hit_count: 367
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
hit_count: 367
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
hit_count: 357
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
     Framework-owned non-slug-bearing verifiers (constitution-shape-lint.sh,
     standalone-gate.sh) live under scripts/verify/ per FR-5/FR-6 spec
     paths and the M033 Knowledge-Layer Boundary "Write-sites M033 claims".
     Verifier scripts are co-authored alongside their corresponding
     artifact within the SAME task (plan-time discipline rule 2).
     Namespacing: `m033-p03-*` prefix avoids collision with M030/M031/[M032](../../../../../milestones/M032/index.md)
     and with M033/P01's `m033-p01-*` and M033/P02's `m033-p02-*` namespaces.

     Per the P01 plan-shape finding (P01-SUMMARY.md "Plan-shape finding"):
     artifact-list bullets in `## Must-Haves` MUST NOT use the bare-backtick
     shape — the auto-loop --step=V parser eval's bare-backtick bullets as
     commands. Each Truths bullet is labeled as a sentence with backticks
     embedded; each Artifacts bullet uses the `Label: path (constraints) — create`
     shape. -->

### Truths

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


### P02 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P02"
parent: "M033"
milestone: "M033"
provides:
  - "scripts/util/jsonl-event-emitter.sh (FR-22 emitter library,11 closed-enum event types,schema 1.0,480-byte atomic-append size guard); tools/verify/m033-p02-jsonl-event-schema.sh (25-check shape + functional + negative-path verifier),scripts/util/start-state-markers.sh marker primitives library; scripts/lifecycle/start.sh additive resume-on-partial-state extension; tests/m033-acceptance/p07-resume-on-partial-state.sh SC-12 acceptance script; three T02 verifiers under tools/verify/m033-p02-*,scripts/lifecycle/grilling-shell.sh-FR-17-core-API,tools/verify/m033-p02-grilling-shell-shape.sh,scripts/lifecycle/grilling-shell.sh-MIT-007-contradiction-and-FR-18-glossary,tests/m033-acceptance/p07-grilling-shell.sh,tools/verify/m033-p02-grilling-shell-contradiction-detection.sh,tools/verify/m033-p02-glossary-writer-shape.sh,tools/verify/m033-p02-acceptance-shape-sc11.sh,references/m033-fr21-dual-write-convention.md FR-21 SSOT for P03/P04/P05; tests/m033-acceptance/p07-observability-records.sh SC-13 acceptance covering all 11 event types; tools/verify/m033-p02-fr21-convention-shape.sh; tools/verify/m033-p02-acceptance-shape-sc13.sh; tools/verify/m033-p02-phase-suite.sh aggregating 10 P02 verifiers; tools/verify/m033-p02-scope-guard.sh bidirectional forbidden+allowed scope-guard"
requires:
  - "P01"
affects:
  - "P03,P04,P05"
key_files:
  - "scripts/util/jsonl-event-emitter.sh,tools/verify/m033-p02-jsonl-event-schema.sh,scripts/util/start-state-markers.sh,scripts/lifecycle/start.sh,tests/m033-acceptance/p07-resume-on-partial-state.sh,tools/verify/m033-p02-start-state-markers-shape.sh,tools/verify/m033-p02-start-sh-resume-extension.sh,tools/verify/m033-p02-acceptance-shape-sc12.sh,scripts/lifecycle/grilling-shell.sh,tools/verify/m033-p02-grilling-shell-shape.sh,tests/m033-acceptance/p07-grilling-shell.sh,tools/verify/m033-p02-grilling-shell-contradiction-detection.sh,tools/verify/m033-p02-glossary-writer-shape.sh,tools/verify/m033-p02-acceptance-shape-sc11.sh,references/m033-fr21-dual-write-convention.md,tests/m033-acceptance/p07-observability-records.sh,tools/verify/m033-p02-fr21-convention-shape.sh,tools/verify/m033-p02-acceptance-shape-sc13.sh,tools/verify/m033-p02-phase-suite.sh,tools/verify/m033-p02-scope-guard.sh"
key_decisions:
  - "closed-7-name-subflow-enum-as-fenced-SSOT;idempotent-marker-write-preserves-first-completion-timestamp;init-invoked-marker-write-post-init-for-symmetry;resume-detection-block-exits-0-after-diagnostic-pending-P03-P04-P05-real-dispatch"
patterns_established:
  - "fenced SSOT closed-enum block for grep-friendly event-type cross-checking; printf-into-local + linelen size-guard for POSIX atomic-append discipline (480 bytes under macOS PIPE_BUF 512); JSON-object payload validation via case-glob shape check (no jq dependency at emit path),closed-enum-as-fenced-SSOT-grep-token-tripwire;idempotent-marker-with-first-write-timestamp-preservation;P01-preservation-gate-via-AD-15-cross-phase-regression-precedent-sub-step;additive-extension-discipline-no-touch-of-P01-behavior-paths,stub-helper-with-stable-name-for-T04-replacement,reserved-fenced-SSOT-block-markers,sourceability-guard-via-BASH_SOURCE-vs-dollar-zero,recommendation-not-interrogation-prefix-ordering,caller-set-bash-vars-for-ask_one-cross-cutting-context,accumulator-append-only-after-contradiction-clean,awk-single-pass-alphabetized-insert,closed-vocabulary-SSOT-block-via-IFS-newline-for-loop,bidirectional-scope-guard pattern reused from m033-p01-scope-guard.sh: forbidden-presence + allowed-presence whitelist catches both overflow and underflow; phase-suite-aggregator pattern with newline-delimited verifier list iterated under IFS swap; hard-coded event-type emission in acceptance scripts so per-event-type regressions name themselves in failure output"
drill_down_paths:
  - "[.orchestrator/milestones/M033/phases/P02/tasks/T01-jsonl-event-emitter-SUMMARY.md](../../../../../milestones/M033/phases/P02/tasks/T01-jsonl-event-emitter-SUMMARY.md), [.orchestrator/milestones/M033/phases/P02/tasks/T02-start-state-markers-and-resume-SUMMARY.md](../../../../../milestones/M033/phases/P02/tasks/T02-start-state-markers-and-resume-SUMMARY.md), [.orchestrator/milestones/M033/phases/P02/tasks/T03-grilling-shell-core-SUMMARY.md](../../../../../milestones/M033/phases/P02/tasks/T03-grilling-shell-core-SUMMARY.md), [.orchestrator/milestones/M033/phases/P02/tasks/T04-grilling-shell-glossary-and-contradiction-SUMMARY.md](../../../../../milestones/M033/phases/P02/tasks/T04-grilling-shell-glossary-and-contradiction-SUMMARY.md), [.orchestrator/milestones/M033/phases/P02/tasks/T05-fr21-convention-and-phase-suite-SUMMARY.md](../../../../../milestones/M033/phases/P02/tasks/T05-fr21-convention-and-phase-suite-SUMMARY.md)"
duration: "201m"
verification_result: "pass"
completed_at: "2026-05-04T03:58:32Z"
observability_surfaces:
  - "jsonl-event-emitter.sh@.orchestrator/execution-log.jsonl"
---

P02 ships the cross-cutting infrastructure that all of M033's downstream phases (P03 greenfield, P04 PBJ detection, P05 M032-paired-launch) consume: the FR-22 JSONL event-emitter and 11-event closed enum, the FR-20 start-state markers + `start.sh` resume-on-partial-state extension, the FR-17 grilling-shell with FR-18 glossary writer and MIT-007 contradiction detection, the FR-21 dual-write convention SSOT, and the SC-13 end-to-end observability acceptance.

## What was built

- **FR-22 JSONL event-emitter** (T01): `scripts/util/jsonl-event-emitter.sh` exposes a single `emit_event` entry point. Schema 1.0, 11-event closed enum (`subflow_started`, `subflow_completed`, `flag_passed`, `disambiguation_resolved`, `contradiction_detected`, `glossary_term_added`, `materials_classified`, `pbj_inconsistency_detected`, `wiki_initialized`, `giscus_configured`, `imported_context_loaded`) declared in a fenced `# >>> event-types >>> ... # <<< event-types <<<` SSOT block. Atomic-append `>>` to `<PROJECT_DIR>/.orchestrator/execution-log.jsonl` with a 480-byte size guard (under macOS PIPE_BUF 512 — `payload too large for atomic append` diagnostic + rc=2 if exceeded). ISO 8601 UTC timestamps via `date -u`. JSON-object payload shape validated via case-glob (no jq dependency at emit path). 25-check shape verifier locks the contract.
- **FR-20 start-state markers + resume-on-partial-state** (T02): `scripts/util/start-state-markers.sh` provides write/read/next/clear primitives over a 7-name closed enum (`pre-init`, `init-invoked`, `subflow-started`, `subflow-completed`, `pbj-detection-completed`, `wiki-initialized`, `giscus-configured`). Markers are idempotent — first-completion timestamps are preserved on re-write. `scripts/lifecycle/start.sh` extended additively with a `--no-resume` flag, post-init `init-invoked` marker write, and a resume-detection block in `main()` that emits `start-state: resuming from <next>` when this branch's marker is present. P01 behavior fully preserved (re-verified: `m033-p01-phase-suite.sh` 14/14 PASS, SC-1 14/14 PASS) — AD-15 cross-phase regression precedent sub-step baked into T02's verifier.
- **FR-17 grilling-shell core + FR-18 glossary + MIT-007 contradiction** (T03 + T04): `scripts/lifecycle/grilling-shell.sh` exposes `ask_one` (3-arg public API: question key, prompt text, default), with caller-set `_GRILLING_CURRENT_QKEY` / `_GRILLING_CURRENT_DEFINITION` vars threading cross-cutting context per call. T03 shipped the sourceable core with stub bodies + reserved fenced SSOT block markers (`# >>> contradiction-pairs >>>`, `# >>> glossary-triggers >>>`); T04 replaced the stubs in-place with real implementations. Contradiction-pairs SSOT carries 9 pairs across target-user / deployment-target / auth-model. Glossary-triggers SSOT carries 4 keys (domain-term-defined, acronym-resolved, convention-named, framework-chosen). `_grilling_glossary_update` does an awk-single-pass alphabetized insert against a `wiki/glossary.md` target (fixture-local under `mktemp -d` per the P02 stub-mode escape valve — same path becomes the real M032-owned surface in M033/P05 with no code change). T03's verifier still passes after T04's edits — additive contract preserved.
- **FR-21 dual-write convention SSOT + 10-verifier phase-suite + bidirectional scope-guard + SC-13 end-to-end** (T05): `references/m033-fr21-dual-write-convention.md` documents inheritance from M014/spec 035 (`bash scripts/util/dual-write-runtime-md.sh append "<fragment>"` canonical call shape, `dual_write_agents: false` config-respect note, 5 per-command fragment templates for FR-3/FR-7/FR-9/FR-10/FR-13). The FR-21 callsite-discovery contract is the load-bearing `# >>> fr-21-dual-write-callsites >>>` fenced block. `tests/m033-acceptance/p07-observability-records.sh` is the SC-13 acceptance: hard-coded emit calls for all 11 event types + uniqueness + timestamp + payload pass-through + closed-enum negative-path + drift-catch (31 PASS / 0 FAIL). `tools/verify/m033-p02-phase-suite.sh` aggregates exactly 10 P02 sub-verifiers. `tools/verify/m033-p02-scope-guard.sh` is bidirectional: forbidden-presence (15 P03/P04/P05 surfaces absent) + wiki-boundary (clean) + allowed-presence whitelist (20 P02 deliverables present) — catches both overflow and silent-skip underflow.

## Patterns established

- **Closed-enum-as-fenced-SSOT grep token tripwire**: every cross-phase boundary (event types, marker states, contradiction pairs, glossary triggers) ships as a fenced SSOT block parseable by `IFS=$'\n'` for-loop iteration. Downstream verifiers `grep -F` against the fenced block as the source of truth.
- **Idempotent marker with first-completion-timestamp preservation**: write operations check for prior content and preserve it; only the secondary fields update.
- **Stub-helper-with-stable-name-for-T04-replacement**: T03's no-op function bodies share signatures + names with T04's real implementations, enabling surgical in-place replacement without contract drift.
- **Sourceability guard via `BASH_SOURCE` vs `$0`**: a single end-of-file gate lets scripts be both directly executable and importable; sourcing in a sandboxed subshell exits 0 with no top-level `set` directives or `exit` calls leaking.
- **Recommendation-not-interrogation prefix ordering**: grilling-shell prompt structure surfaces a default-recommendation line before the question, framing the interaction as a confirmable suggestion rather than an interrogation.
- **Awk-single-pass alphabetized insert** for glossary writes — bash 3.2 compatible, no `sort`-pipe dependency.
- **Hard-coded event-type emission** in SC-13 acceptance — per-event-type regressions name themselves in failure output rather than aggregate-counting that hides which event broke.
- **Bidirectional scope-guard** (forbidden + allowed whitelist) reused from P01's `m033-p01-scope-guard.sh` pattern.
- **Phase-suite-aggregator** pattern: newline-delimited verifier list iterated under `IFS=$'\n'` swap; canonical `SUMMARY: <verifier-name> pass=N fail=M` final-line token preserved per verifier.
- **AD-15 P01 cross-phase preservation gate**: T02 baked an explicit P01-preservation sub-step into its verifier so the additive `start.sh` extension provably did not regress P01 behavior.

## Decisions captured during execution

- T01: JSONL atomic-append size guard set at 480 bytes (under macOS PIPE_BUF 512), enforcing State On Disk Is Truth invariant.
- T02: idempotent marker design preserves first-completion timestamp on re-write; `init-invoked` marker writes post-init for symmetry with the resume-detection block; resume-detection block exits 0 after the diagnostic, deferring real dispatch to P03/P04/P05.
- T03/T04: closed contradiction-pairs and glossary-triggers vocabularies at v1; demand-driven expansion post-launch per Constitution-XIV.
- T05: P02 stub-mode escape valve — `wiki/glossary.md` writes are fixture-local under `mktemp -d`. Same path becomes the real M032-owned surface in M033/P05 with no source change.

## Verification result

- `tools/verify/m033-p02-phase-suite.sh`: `pass=10 fail=0`
- `tools/verify/m033-p02-scope-guard.sh`: `pass=36 fail=0` (forbidden-presence + wiki-boundary + allowed-presence all green)
- All 5 task-level verify cycles: `AUTO:VERIFY_PASS`
- SC-11 acceptance (`tests/m033-acceptance/p07-grilling-shell.sh`): `pass=12 fail=0`
- SC-12 acceptance (`tests/m033-acceptance/p07-resume-on-partial-state.sh`): `pass=14 fail=0`
- SC-13 acceptance (`tests/m033-acceptance/p07-observability-records.sh`): `pass=31 fail=0`
- P01 cross-phase regression (`tests/m033-acceptance/p01-start-branch-routing.sh`): `pass=14 fail=0` (T02 preservation gate)
- External-modification check: `PASS: no external modifications`
- Roadmap sync: `SYNC:OK`

## What downstream phases consume

- **P03** (greenfield + materials sub-flows): consumes `jsonl-event-emitter.sh` for `subflow_started` / `subflow_completed` / `materials_classified` / `imported_context_loaded`; consumes `start-state-markers.sh` for `subflow-started` / `subflow-completed`; consumes `grilling-shell.sh` for greenfield grilling questions; consumes `m033-fr21-dual-write-convention.md` for the dual-write callsite shape.
- **P04** (PBJ inconsistency detector): consumes `jsonl-event-emitter.sh` for `pbj_inconsistency_detected`; consumes the PBJ fixture from P01 (T01) as its development target.
- **P05** (M032 paired-launch + friendly-tester gate): consumes `jsonl-event-emitter.sh` for `wiki_initialized` / `giscus_configured`; consumes `start-state-markers.sh` for `wiki-initialized` / `giscus-configured`; replaces the P02 fixture-local `mktemp -d` glossary path with the real `--with-wiki` surface.

The dual-write convention SSOT (T05) is the single point of contact for P03/P04/P05 dual-write call shape — any drift across phases will surface as a verifier failure against the SSOT, not as silent inconsistency.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M033"
name: "Standalone gate + constitution-shape-lint + 3 stack starters + format reference (FR-4 / FR-5 / FR-6)"
depends_on: []
---

## Prerequisites

- `scripts/verify/` exists — verified by `[ -d scripts/verify ]`.
- `templates/` exists — verified by `[ -d templates ]`.
- `references/` exists — verified by `[ -d references ]`.
- `tools/verify/` exists.
- `scripts/verify/constitution-shape-lint.sh` does NOT yet exist — verified by `[ ! -f scripts/verify/constitution-shape-lint.sh ]`.
- `scripts/verify/standalone-gate.sh` does NOT yet exist — verified by `[ ! -f scripts/verify/standalone-gate.sh ]`.
- `templates/constitution-starters/` does NOT yet exist — verified by `[ ! -d templates/constitution-starters ]`.
- `references/constitution-starter-format.md` does NOT yet exist — verified by `[ ! -f references/constitution-starter-format.md ]`.
- M033/P01 closed: `scripts/lifecycle/start.sh` exists. M033/P02 closed: `scripts/lifecycle/grilling-shell.sh` exists, `scripts/util/jsonl-event-emitter.sh` exists, `scripts/util/start-state-markers.sh` exists, `scripts/util/dual-write-runtime-md.sh` exists.
- Spec context: FR-4 names three stacks (`web-saas`, `cli-tool`, `library`) with stack-specific principles. FR-5 lint asserts `## Constitution Check` + `### Principle <Roman>` headers + non-empty bodies + zero `{{` placeholders. FR-6 standalone gate scans the closed M033 constitution-authoring surface (file set documented inline) for any `speckit` substring (case-insensitive); zero matches required. CON-3 — Principle XVI's first content-authoring compliance test.

## Description

T01 lands the verifier surfaces and templates that T02 (`constitution-author.sh`) consumes at runtime: the FR-5 `scripts/verify/constitution-shape-lint.sh` lint, the FR-6 `scripts/verify/standalone-gate.sh constitution` handler (Principle XVI's first content-authoring compliance test), the three FR-4 stack starter templates (`web-saas.md`, `cli-tool.md`, `library.md`), and the FR-4 / US-2 AS-4 starter-format reference at `references/constitution-starter-format.md`.

The standalone gate is the load-bearing CON-3 enforcement — zero `speckit.*` references in the M033-shipped constitution-authoring surface. The closed surface file set is documented inline in the gate script under a fenced `# >>> constitution-surface-files >>>` block (SSOT — extending the surface requires editing this block). Subcommand-dispatched (`constitution` is v1; future `ingest-codebase` etc. extends without contract drift).

Each stack starter ships YAML frontmatter (`schema_version: "1.0"` + `type: constitution-starter` + `stack: <name>`) per MEM013 template-convention precedent, a `## Constitution Check` section header (load-bearing for `commands/specify.md:86,99,115` cross-references), 6–8 baseline principles named with Roman-numeral `### Principle <I..VIII>` sub-headers, and 2–3 stack-specific principles named in FR-4. Placeholder vocabulary (`{{project_type}}`, `{{primary_constraint}}`, `{{target_user}}`) is consumed by T02's `constitution-author.sh`.

**Bash 3.2 compatibility (MEM001):** No `declare -A`, no process substitution, no `$(...)` containing pipes. Verifiers emit `PASS:` / `FAIL:` / `SUMMARY:` lines per MEM001.

## Steps

1. **Author `scripts/verify/constitution-shape-lint.sh`** (≥50 lines, executable, `chmod +x`, bash 3.2 compatible). Given a `<path>` argument naming a constitution file, the script asserts:
   - `## Constitution Check` section header is present (`grep -q '^## Constitution Check' <path>`).
   - At least 6 `### Principle <Roman>` sub-headers are present (`grep -cE '^### Principle [IVX]+' <path>`; assert count ≥ 6).
   - Every principle sub-header has at least one non-empty body line before the next `### Principle` or end-of-file. Implement via a loop reading the file with `while IFS= read -r line` and a state machine; on any empty principle, exit non-zero with the principle name echoed.
   - Zero literal `{{` placeholder strings remain. `grep -nF '{{' <path>` MUST produce no matches; on any match, echo the line numbers to stderr and exit non-zero.
   - Emit `PASS: <path> shape lint passed` on success; `SUMMARY: constitution-shape-lint.sh path=<path> pass=N fail=M` final line.

2. **Author `scripts/verify/standalone-gate.sh`** (≥60 lines, executable, `chmod +x`, bash 3.2 compatible). The script:
   - Accepts a single subcommand argument (`constitution` is the v1 dispatch).
   - Contains a fenced `# >>> constitution-surface-files >>>` ... `# <<< constitution-surface-files <<<` SSOT block enumerating the closed surface file set (one path per line):

     ```
     commands/constitution.md
     scripts/lifecycle/constitution-author.sh
     templates/constitution-starters/web-saas.md
     templates/constitution-starters/cli-tool.md
     templates/constitution-starters/library.md
     references/constitution-starter-format.md
     scripts/verify/constitution-shape-lint.sh
     ```

   - Reads the SSOT block via `awk '/>>> constitution-surface-files >>>/,/<<< constitution-surface-files <<</'` (no process substitution; bash 3.2 compatible).
   - For each surface file that exists on disk (skip-with-diagnostic if absent — co-authored-but-not-yet-landed surfaces are tolerated under SKIP semantics matching M033/P01's verifier discipline), runs `grep -nFi 'speckit' <path>` and collects matches. Tolerates absence: a file that does not yet exist (e.g., `commands/constitution.md` before T02 lands) emits `SKIP: <path>` and is not counted as fail.
   - On any match, echoes `FAIL: speckit reference at <path>:<lineno>` to stderr and exits non-zero.
   - On no matches, echoes `PASS: zero speckit references in M033-shipped constitution surface` and `SUMMARY: standalone-gate.sh subcommand=constitution pass=N skip=M fail=0` and exits 0.
   - Unknown subcommand exits 2 with `usage: standalone-gate.sh constitution`.

3. **Author `templates/constitution-starters/web-saas.md`** (≥50 lines). Frontmatter:

   ```yaml
   ---
   schema_version: "1.0"
   type: constitution-starter
   stack: web-saas
   ---
   ```

   Body:
   - `# Constitution — {{project_type}}` title.
   - `## Constitution Check` section header.
   - 6 baseline `### Principle <I..VI>` sub-headers (e.g., I. Context Minimization; II. Evidence Before Claims; III. Design Before Code; IV. Plans Assume Zero Context; V. State On Disk Is Truth; VI. Knowledge Compounds — copy from `.orchestrator/memory/constitution.md` baseline).
   - 2 web-saas-specific `### Principle VII..VIII` sub-headers: `Idempotent Deploys`, `User Data Privacy` — each with non-empty body referencing `{{primary_constraint}}` and `{{target_user}}`.
   - Each principle body is 2–4 lines of prose seeded with the placeholder vocabulary `{{project_type}}`, `{{primary_constraint}}`, `{{target_user}}` so T02's substitution step exercises them.

4. **Author `templates/constitution-starters/cli-tool.md`** (≥50 lines). Same frontmatter shape (`stack: cli-tool`) and 6 baseline principles, plus 2 cli-tool-specific: `Composable Default Exit Codes`, `POSIX Convention Adherence`. Same placeholder vocabulary.

5. **Author `templates/constitution-starters/library.md`** (≥50 lines). Same frontmatter shape (`stack: library`) and 6 baseline principles, plus 2 library-specific: `Stable API Surface`, `Semantic Versioning Discipline`. Same placeholder vocabulary.

6. **Author `references/constitution-starter-format.md`** (≥60 lines). Documents:
   - The starter file format: YAML frontmatter (`schema_version`, `type: constitution-starter`, `stack: <name>`) + `## Constitution Check` section + Roman-numeral `### Principle` sub-headers + placeholder vocabulary.
   - The closed v1 stack list: `web-saas`, `cli-tool`, `library`.
   - The demand-driven expansion criterion per `#Q-2`: "≥2 distinct external requests for a stack post-launch trigger expansion of that stack; no speculative pre-build."
   - The minimum baseline-principle count (6) and the 2–3-stack-specific principle convention.
   - The placeholder vocabulary (`{{project_type}}`, `{{primary_constraint}}`, `{{target_user}}`) and the rule that all `{{...}}` placeholders MUST be resolved before write (FR-5 lint enforcement).
   - A note for community-contributed-additions: a future M033.5 may extend the v1 stack list per `#Q-2`; until then, custom stacks ride a fork of one of the v1 starters with a follow-up D-row.

7. **Author `tools/verify/m033-p03-constitution-shape-lint-shape.sh`** (≥30 lines, executable). Asserts:
   - `scripts/verify/constitution-shape-lint.sh` exists and is executable.
   - The script body contains the load-bearing tokens via `grep -F`: `Constitution Check`, `Principle`, `{{`, `PASS:`, `FAIL:`, `SUMMARY:`.
   - **Functional smoke test:** create a `mktemp -d` staging dir; write a constitution-shaped fixture with 6 `### Principle <I..VI>` sub-headers + a non-empty body each + a `## Constitution Check` section header + zero `{{` placeholders; invoke `bash scripts/verify/constitution-shape-lint.sh <fixture>` and assert exit 0 + `PASS:` line. Cleanup mandatory.
   - **Negative smoke test:** write a fixture with one literal `{{unresolved}}` placeholder; invoke the lint and assert exit non-zero + the line number echoed to stderr. Cleanup mandatory.
   - Emits `PASS:` / `SUMMARY:` lines.

8. **Author `tools/verify/m033-p03-standalone-gate-sh-shape.sh`** (≥30 lines, executable). Asserts:
   - `scripts/verify/standalone-gate.sh` exists and is executable.
   - The script body contains the load-bearing tokens via `grep -F`: `constitution`, `speckit`, `constitution-surface-files`, `PASS:`, `FAIL:`, `SUMMARY:`.
   - The fenced SSOT block markers `# >>> constitution-surface-files >>>` and `# <<< constitution-surface-files <<<` appear.
   - The closed surface file set is enumerated inside the SSOT block (one of: `commands/constitution.md`, `templates/constitution-starters/web-saas.md`, `references/constitution-starter-format.md`, `scripts/verify/constitution-shape-lint.sh`).
   - **Functional smoke test:** invoke `bash scripts/verify/standalone-gate.sh constitution` against the M033 working tree; assert exit 0 (no `speckit` references in the M033 surface — at T01 land time, surfaces co-authored-but-not-yet-landed are tolerated via SKIP); assert `PASS:` or `SKIP:` lines appear and `FAIL:` does NOT appear. Note: `scripts/verify/standalone-gate.sh` itself is NOT in its own surface file list (the gate scans authored surfaces, not its own implementation).
   - Emits `PASS:` / `SUMMARY:` lines.

9. **Author `tools/verify/m033-p03-constitution-starter-templates-shape.sh`** (≥30 lines, executable). For each of `templates/constitution-starters/{web-saas,cli-tool,library}.md`, asserts:
   - File exists and is non-empty.
   - Frontmatter contains `schema_version: "1.0"`, `type: constitution-starter`, and the matching `stack: <name>`.
   - Body contains `## Constitution Check`, ≥6 `### Principle <Roman>` sub-headers, the stack-specific tokens (`Idempotent Deploys` / `Composable Default Exit Codes` / `Stable API Surface` per stack), and the placeholder tokens (`{{project_type}}`, `{{primary_constraint}}`, `{{target_user}}`).
   - Emits `PASS:` / `SUMMARY:` lines per starter.

10. **Author `tools/verify/m033-p03-constitution-starter-format-ref-shape.sh`** (≥25 lines, executable). Asserts:
    - `references/constitution-starter-format.md` exists.
    - Body contains the load-bearing tokens via `grep -F`: `schema_version`, `Roman-numeral`, `Constitution Check`, `Principle`, `{{`, `web-saas`, `cli-tool`, `library`, `#Q-2`.
    - Emits `PASS:` / `SUMMARY:` lines.

## Must-Haves

This task addresses these P03 phase truths:
- `scripts/verify/constitution-shape-lint.sh` exists with the documented assertions (FR-5).
- `scripts/verify/standalone-gate.sh` exists with the `constitution` subcommand handler (FR-6 / Principle XVI).
- Three stack starters exist at `templates/constitution-starters/{web-saas,cli-tool,library}.md` (FR-4).
- `references/constitution-starter-format.md` exists with the v1 stack list and `#Q-2` expansion criterion.

This task creates these P03 phase artifacts:
- Lint verifier: `scripts/verify/constitution-shape-lint.sh` (FR-5).
- Standalone gate: `scripts/verify/standalone-gate.sh` (FR-6).
- Starters: `templates/constitution-starters/{web-saas,cli-tool,library}.md` (FR-4).
- Reference: `references/constitution-starter-format.md`.
- Verifiers: `tools/verify/m033-p03-{constitution-shape-lint-shape,standalone-gate-sh-shape,constitution-starter-templates-shape,constitution-starter-format-ref-shape}.sh`.

## Verification

```bash
bash tools/verify/m033-p03-constitution-shape-lint-shape.sh
bash tools/verify/m033-p03-standalone-gate-sh-shape.sh
bash tools/verify/m033-p03-constitution-starter-templates-shape.sh
bash tools/verify/m033-p03-constitution-starter-format-ref-shape.sh
```

## Inputs

### From Previous Tasks

None. T01 has no intra-phase prerequisites.

### From Disk (Pre-existing)

- `.orchestrator/memory/constitution.md` — the orchestrator's own constitution (read-only reference for the 6 baseline principles seeded into the three starters; T01 reads this file to copy the principle names + framing into the starter bodies but does NOT modify it).
- `scripts/util/json-field.sh` (MEM008) — NOT required by T01 (verifiers parse via grep/awk, no JSON field extraction at this layer).

## Constraints

- Bash 3.2 compatibility (MEM001) — no `declare -A`, no process substitution, no `$(...)` containing pipes.
- Verifiers use single-script-file shape per AD-19 — no `( … )` subshells, no `$(...)` with pipes, no compound chains.
- Standalone-gate's closed surface file set is the SSOT — extending the surface requires editing the fenced block, not the consumer.
- The standalone gate tolerates SKIP for co-authored-but-not-yet-landed surfaces (e.g., `commands/constitution.md` before T02 lands) — this preserves T01's ability to ship before T02 without false failures. T05's SC-2 acceptance script asserts the gate produces zero SKIP lines after T02 lands.
- T01 MUST NOT modify `scripts/lifecycle/start.sh` (P01-shipped surface).
- T01 MUST NOT modify any P02-shipped surface (`grilling-shell.sh`, `jsonl-event-emitter.sh`, `start-state-markers.sh`, `references/m033-fr21-dual-write-convention.md`).
- T01 MUST NOT introduce any `speckit.*` reference into any of the four authored surfaces (Principle XVI / CON-3 dogfood — the gate will scan its own outputs).

## Expected Output

After T01 completes:
- `scripts/verify/constitution-shape-lint.sh` exists, is executable, and exits 0 against a valid constitution fixture.
- `scripts/verify/standalone-gate.sh` exists, is executable, and exits 0 against the (partial) M033 surface (any not-yet-authored surface emits SKIP).
- Three starter templates exist at `templates/constitution-starters/{web-saas,cli-tool,library}.md`.
- `references/constitution-starter-format.md` exists.
- All four T01 verifiers exit 0 with `SUMMARY:` lines.
- A summary file at `.orchestrator/milestones/M033/phases/P03/tasks/T01-standalone-gate-and-starters-SUMMARY.md` documents the deliverables.

## Notes

T01's standalone gate is the dogfood compliance test for CON-3 / Principle XVI — the gate scans its own M033 surface for `speckit.*` leakage. T02's `constitution-author.sh` will be one of the surface files; the gate-against-T02 fires at T02 land time. SC-2 (T05 deliverable) is the end-to-end assertion that the full surface is `speckit.*`-free.

The 6 baseline principles in the starters intentionally mirror the orchestrator's own `.orchestrator/memory/constitution.md` v1 baseline (Context Minimization / Evidence Before Claims / Design Before Code / Plans Assume Zero Context / State On Disk Is Truth / Knowledge Compounds) — this is deliberate dogfood (the orchestrator constitution is the canonical seed; downstream-project constitutions are derivatives). Stack-specific principles extend the baseline; they do not replace it.

The placeholder vocabulary (`{{project_type}}`, `{{primary_constraint}}`, `{{target_user}}`) is the v1 closed set. T02's `constitution-author.sh` runs a 5–8 question grilling-shell flow that resolves these three placeholders plus 2–5 stack-specific follow-ups; the FR-5 lint asserts zero `{{` survivors.

The standalone gate's path discipline (framework-owned non-slug-bearing under `scripts/verify/`) is deliberate: the gate must ship in the install bundle so any downstream project that adopts the orchestrator inherits the Principle XVI compliance test for free.

## State Context

- **Current State**: executing
- **Milestone**: M033
- **Phase**: P03
- **Task**: T01-standalone-gate-and-starters
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- Bash 3.2 compatibility (MEM001) — no `declare -A`, no process substitution, no `$(...)` containing pipes.
- Verifiers use single-script-file shape per AD-19 — no `( … )` subshells, no `$(...)` with pipes, no compound chains.
- Standalone-gate's closed surface file set is the SSOT — extending the surface requires editing the fenced block, not the consumer.
- The standalone gate tolerates SKIP for co-authored-but-not-yet-landed surfaces (e.g., `commands/constitution.md` before T02 lands) — this preserves T01's ability to ship before T02 without false failures. T05's SC-2 acceptance script asserts the gate produces zero SKIP lines after T02 lands.
- T01 MUST NOT modify `scripts/lifecycle/start.sh` (P01-shipped surface).
- T01 MUST NOT modify any P02-shipped surface (`grilling-shell.sh`, `jsonl-event-emitter.sh`, `start-state-markers.sh`, `references/m033-fr21-dual-write-convention.md`).
- T01 MUST NOT introduce any `speckit.*` reference into any of the four authored surfaces (Principle XVI / CON-3 dogfood — the gate will scan its own outputs).

### Acceptance Criteria

This task addresses these P03 phase truths:
- `scripts/verify/constitution-shape-lint.sh` exists with the documented assertions (FR-5).
- `scripts/verify/standalone-gate.sh` exists with the `constitution` subcommand handler (FR-6 / Principle XVI).
- Three stack starters exist at `templates/constitution-starters/{web-saas,cli-tool,library}.md` (FR-4).
- `references/constitution-starter-format.md` exists with the v1 stack list and `#Q-2` expansion criterion.

This task creates these P03 phase artifacts:
- Lint verifier: `scripts/verify/constitution-shape-lint.sh` (FR-5).
- Standalone gate: `scripts/verify/standalone-gate.sh` (FR-6).
- Starters: `templates/constitution-starters/{web-saas,cli-tool,library}.md` (FR-4).
- Reference: `references/constitution-starter-format.md`.
- Verifiers: `tools/verify/m033-p03-{constitution-shape-lint-shape,standalone-gate-sh-shape,constitution-starter-templates-shape,constitution-starter-format-ref-shape}.sh`.

### Files To Touch

- `commands/constitution.md` (create, T02)
- `commands/ingest-codebase.md` (create, T03)
- `scripts/lifecycle/constitution-author.sh` (create, T02)
- `scripts/lifecycle/ingest-codebase.sh` (create, T03 — extended in place by T04 for rich-context branch)
- `scripts/verify/constitution-shape-lint.sh` (create, T01)
- `scripts/verify/standalone-gate.sh` (create, T01)
- `templates/constitution-starters/web-saas.md` (create, T01)
- `templates/constitution-starters/cli-tool.md` (create, T01)
- `templates/constitution-starters/library.md` (create, T01)
- `references/constitution-starter-format.md` (create, T01)
- `references/imported-context-sentinel.md` (create, T04)
- `tests/fixtures/m033-stack-fixture-ts-saas/` (create tree, T03)
- `tests/fixtures/m033-stack-fixture-py-cli/` (create tree, T03)
- `tests/fixtures/m033-stack-fixture-rust-library/` (create tree, T03)
- `tests/m033-acceptance/p02-constitution-author.sh` (create, T05)
- `tests/m033-acceptance/p03-ingest-codebase.sh` (create, T05)
- `tools/verify/m033-p03-constitution-md-shape.sh` (create, T02)
- `tools/verify/m033-p03-constitution-author-sh-shape.sh` (create, T02)
- `tools/verify/m033-p03-constitution-starter-templates-shape.sh` (create, T01)
- `tools/verify/m033-p03-constitution-starter-format-ref-shape.sh` (create, T01)
- `tools/verify/m033-p03-constitution-shape-lint-shape.sh` (create, T01)
- `tools/verify/m033-p03-standalone-gate-sh-shape.sh` (create, T01)
- `tools/verify/m033-p03-ingest-codebase-md-shape.sh` (create, T03)
- `tools/verify/m033-p03-ingest-codebase-sh-shape.sh` (create, T03)
- `tools/verify/m033-p03-rich-context-import-shape.sh` (create, T04)
- `tools/verify/m033-p03-imported-context-sentinel-shape.sh` (create, T04)
- `tools/verify/m033-p03-stack-fixtures-shape.sh` (create, T03)
- `tools/verify/m033-p03-acceptance-shape-sc2.sh` (create, T05)
- `tools/verify/m033-p03-acceptance-shape-sc3.sh` (create, T05)
- `tools/verify/m033-p03-phase-suite.sh` (create, T05)
- `tools/verify/m033-p03-cross-phase-regression.sh` (create, T05)
- `tools/verify/m033-p03-scope-guard.sh` (create, T05)
- `scripts/state/derive-phase.sh` (additive `_*`-prefix skip annotation only — T04; no behavior change for projects without imported context)
- `scripts/dispatch/build-context.sh` (additive `_*`-prefix skip annotation only — T04; no behavior change for projects without imported context)
- `scripts/diagnostics/run-doctor.sh` (additive `_*`-prefix skip annotation only — T04 — exact target file may differ; T04 identifies precise filename at execution time)

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