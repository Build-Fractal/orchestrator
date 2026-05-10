---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T05-roundtrip-and-verifiers (Phase P02, Milestone M028)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~700 | required |
| Upstream Context | 981-1048 | ~2900 | required |
| Task Plan | 1050-1234 | ~4300 | required |
| State Context | 1236-1242 | ~100 | required |
| First-Turn Completeness | 1244-1282 | ~800 | required |
| **Total** | | **~19600** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 635
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
hit_count: 635
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
hit_count: 635
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
hit_count: 635
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
hit_count: 564
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
hit_count: 564
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
hit_count: 564
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
hit_count: 635
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
hit_count: 564
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
hit_count: 564
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
hit_count: 564
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
hit_count: 635
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
hit_count: 635
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
hit_count: 635
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
hit_count: 564
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
hit_count: 564
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
hit_count: 564
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
hit_count: 635
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
hit_count: 564
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
hit_count: 564
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
hit_count: 635
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
hit_count: 635
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
hit_count: 564
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
hit_count: 564
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
hit_count: 564
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
hit_count: 219
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
hit_count: 219
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
hit_count: 219
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
hit_count: 211
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
hit_count: 211
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
hit_count: 201
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

- The PreToolUse shape-guard hook resolves its classifier and reject_lookup paths via `$(dirname "${BASH_SOURCE[0]}")` (with symlink resolution) and never references `$CLAUDE_PROJECT_DIR`. Verified by inspecting the hook body for the literal `BASH_SOURCE` self-location pattern and the absence of any `CLAUDE_PROJECT_DIR` reference inside the resolution block. Satisfies FR-2 + US-1 acceptance scenario 4.
  - Check: `bash scripts/verify/m028/p02-hook-self-locate.sh`

- The Claude Code runtime adapter emits, for every hook entry, a `command` field of the literal shape `bash <hooks-dir>/<name>.sh` (never a bare command name) and every emitted leaf object carries `_orchestrator_managed: true`. Verified by capturing `--hook-config` output and asserting each `command` field starts with `bash ` and ends with `.sh`, and that the count of `_orchestrator_managed: true` flags equals the count of leaf hook objects. Satisfies FR-3 + FR-4 + US-1 + US-3 acceptance scenario 4.
  - Check: `bash scripts/verify/m028/p02-adapter-absolute-paths.sh`

- The shape-guard hook self-conforms to its own classifier output under AP-009 (no compound chain exceeding 2 connectors anywhere in its body). Verified by sourcing the [M021](../../../../../milestones/M021/index.md) classifier, scanning the hook body line-by-line, and asserting `classify_command` returns ALLOW for every non-comment non-blank line. Satisfies CON-3 + FR-21 (P02 half — P03's `finding-G-self-conformance.sh` verifies via the M028 classifier; P02 verifier here uses M021 classifier as the day-one floor).
  - Check: `bash scripts/verify/m028/p02-hook-self-conformance.sh`

- `settings-merge.sh merge` is install-side idempotent — running the install path twice in succession against the same target settings.json produces a byte-identical file (SHA-256 equal). The dedup key is `(event, matcher, command) × _orchestrator_managed: true`. Verified by the install-roundtrip pinned-sha gate.
  - Check: `bash scripts/verify/m028/install-roundtrip.sh`

- `bash packaging/install/install-claude-code.sh --uninstall` against a post-install state returns `~/.claude/settings.json` to its pre-install canonical bytes (M025 reversibility extended to M028's expanded entry set). Verified by the install-roundtrip pinned-sha gate's reversibility leg.
  - Check: `bash scripts/verify/m028/install-roundtrip.sh`

- `bash packaging/install/install-claude-code.sh --repair` (and the `--repair --dry-run` preview) removes flag-less orphan entries whose `(event, matcher, command)` tuple matches a known M025 pattern fingerprint (exact-tuple match, never structural-shape match) and preserves user-authored entries verbatim. Verified by running the repair path against the canonical pre-repair fixture P01/T02 produced and asserting the result matches a canonical post-repair reference.

<dispatch-volatile>

## Upstream Context


### P01 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M028"
milestone: "M028"
provides:
  - "classifier-replay audit covering all 9 M028 source events (Findings A-G); per-event classifier verdict captured verbatim from M021 shape-classifier.sh git SHA 12fcd98; replay-coverage verifier,canonical M028 pre-repair fixture (sanitized operator M018-close ~/.claude/settings.json backup) at tests/fixtures/m028-pre-repair-snapshot.json; deterministic sanitizer scripts/verify/m028/p01-fixture-sanitize.sh; must-have verifier scripts/verify/m028/p01-fixture-sanitized.sh,P01-VERIFICATION.md collapse-decision evidence document at .orchestrator/milestones/M028/phases/P01/P01-VERIFICATION.md (per-screenshot causal trace for SE-01 through SE-09,explicit collapse_decision frontmatter field,corpus staging list consumed by P03); shape verifier scripts/verify/m028/p01-collapse-decision-recorded.sh (AD-19 single-script-file,bash 3.2 + POSIX-sh-safe,asserts frontmatter and section headings and Resolved-by-Finding-A-alone YES/NO discipline)"
requires:
  - "none"
affects:
  - "P02"
key_files:
  - "[.orchestrator/milestones/M028/phases/P01/classifier-audit.md](../../../../../milestones/M028/phases/P01/classifier-audit.md);scripts/verify/m028/p01-replay-coverage.sh;scripts/verify/m028/p01-classify-one.sh,tests/fixtures/m028-pre-repair-snapshot.json;scripts/verify/m028/p01-fixture-sanitize.sh;scripts/verify/m028/p01-fixture-sanitized.sh,.orchestrator/milestones/M028/phases/P01/P01-VERIFICATION.md;scripts/verify/m028/p01-collapse-decision-recorded.sh"
key_decisions:
  - "9 source events enumerated (SE-01 Finding A non-firing,SE-02..SE-05 Finding B four shapes,SE-06 Finding C,SE-07 Finding D,SE-08 Finding F adapter+installer non-Bash,SE-09 Finding G); SE-06 and SE-09 already reject under M021 as compound-chain-gt2 (AP-009); SE-02..SE-05 and SE-07 currently classify as allow (the gap M028 closes via AP-010..AP-014); SE-01 + SE-08 are non-classifier events (portability + adapter-emission),partial-flag fixture shape (5 unflagged + 1 flagged Stop entries; 7 unflagged + 1 flagged PreToolUse Bash entries) preserves Finding F regression evidence while satisfying _orchestrator_managed anchor must-have; token-redaction regex restricted to a 32+ char alphanumeric (plus underscore and hyphen) class drops + / = from char class to prevent path-segment false positives; sanitization implemented in two stages -- sed for path/email/token bytes,python3 for structural flag injection -- both deterministic,collapse_decision=full-5-phase based on M=0 of N=7 (threshold 6 not met); SE-01 contributes to A but is NOT resolved-by-A-alone because its in-family commands SE-02..SE-05 all yield existing verdict allow (hook portability alone does not eliminate the in-the-wild failures); SE-09 attributed to G not A despite running on the orchestrator repo itself because the in-tree event proves hook portability is irrelevant to the body-descent bypass surface; corpus staging count is 5 (one per reserved AP-ID) with the FR-13 reconciliation to 7 explicitly delegated to P03 per the rubric in the task plan"
patterns_established:
  - "staged-probe replay shape: write probe under tmp/<milestone>-<phase>/ then invoke via scripts/util/run-probe.sh,source the classifier and call classify_command verbatim,capture stdout byte-exact for the audit's fenced verdict block; throwaway shim under scripts/verify/<milestone>/p01-classify-one.sh as AD-19 single-script-file flat shape,two-stage deterministic sanitization (BSD-portable sed -E for byte-level redactions then python3 json mutation for structural injection); partial-flag fixture realism (mixing pre-M025 unflagged residue with post-M025 flagged entries reflects real downstream user systems); separate -sanitize (transformer,runs once at fixture creation) and -sanitized (verifier,runs at every phase verification) script naming,rubric-driven attribution (verdict + shape + path-prefix triggers map mechanically to Findings A through G; reproducible from classifier-audit.md alone); shape-only verifier discipline (the verifier asserts frontmatter and section headings and per-line YES/NO tokens,never the M/N arithmetic values themselves -- the document body shows the math); corpus-staging delegation pattern (T03 lands the AP-anchored entries derivable from per-screenshot evidence,P03 owns regression and boundary-case padding to the FR-13 target)"
drill_down_paths:
  - "[.orchestrator/milestones/M028/phases/P01/tasks/T01-classifier-replay-audit-SUMMARY.md](../../../../../milestones/M028/phases/P01/tasks/T01-classifier-replay-audit-SUMMARY.md), [.orchestrator/milestones/M028/phases/P01/tasks/T02-fixture-snapshot-SUMMARY.md](../../../../../milestones/M028/phases/P01/tasks/T02-fixture-snapshot-SUMMARY.md), [.orchestrator/milestones/M028/phases/P01/tasks/T03-collapse-decision-evidence-SUMMARY.md](../../../../../milestones/M028/phases/P01/tasks/T03-collapse-decision-evidence-SUMMARY.md)"
duration: "120m"
verification_result: "pass"
completed_at: "2026-04-29T14:18:48Z"
observability_surfaces:
  - "none"
---

P01 closes the M028 input audit and pins the collapse decision: **`full-5-phase`** (P02–P05 stay as-roadmapped). The phase produced three deliverable rounds plus the canonical pre-repair fixture and the verifier triad that downstream phases consume.

## What was built

- **T01 — classifier replay audit** (`classifier-audit.md`, 211 lines, 9 source events). Every M028 source event (Findings A–G plus the operator-reported Stop-hook event) replayed verbatim through the M021 shape classifier (`scripts/verify/lib/shape-classifier.sh` git SHA `12fcd98`). Per-event verdict captured byte-exact in fenced blocks. Two SEs already reject under M021 as `compound-chain-gt2` anchored on AP-009 (SE-06 Finding C, SE-09 Finding G); four SEs classify as `allow` (SE-02..SE-05 Finding B), confirming the spec's gap narration that AP-010..AP-013 close real shapes; SE-07 Finding D classifies as `allow` (destructive-op prompting is shape-independent at the CC layer); SE-01 + SE-08 are non-classifier events (portability + adapter-emission). Replay-coverage verifier `scripts/verify/m028/p01-replay-coverage.sh` PASS.

- **T02 — pre-repair fixture snapshot** (`tests/fixtures/m028-pre-repair-snapshot.json`, 173 lines). Operator's M018-close `~/.claude/settings.json.bak` captured and sanitized: `/Users/brettkellgren/`, the standalone `brettkellgren` token, the operator email, and 32+ char alphanumeric token-like runs all redacted via BSD-portable `sed -E`; `python3` then appended one `_orchestrator_managed: true` entry per `Stop` and `PreToolUse` array. Partial-flag shape preserved (5 unflagged + 1 flagged Stop entries; 7 unflagged + 1 flagged PreToolUse Bash entries) — models the realistic post-M025 mixed-state P02 `--repair` will encounter. Char class deliberately excludes `+ / =` to prevent path-segment false positives. Sanitization is deterministic (double-run byte-identity diff). Two scripts: `p01-fixture-sanitize.sh` (one-shot transformer) + `p01-fixture-sanitized.sh` (must-have verifier). Both PASS.

- **T03 — collapse-decision evidence** (`P01-VERIFICATION.md`, 165 lines, frontmatter `collapse_decision: "full-5-phase"`). Per-screenshot causal trace for SE-01..SE-09; collapse-decision arithmetic M=0 of N=7 (threshold M≥N−1=6 not met); 5-entry corpus staging list with FR-13-to-7 padding delegated to P03. Reasoning summary: hook portability resolves zero events because the four B-family screenshots all carry existing-classifier verdict `allow` (the classifier under-matches regardless of where the hook fires); SE-07 and SE-06 are wrapper-class remediations independent of portability; SE-09 was observed in-tree on the orchestrator repo itself, proving portability is irrelevant to the body-descent bypass surface AP-014 closes. Shape verifier `p01-collapse-decision-recorded.sh` PASS.

## Verification

- Tier 1 (`check-must-haves.sh`): **22/22 PASS** — 3 truths (all carrying `Check:` sub-items), 12 artifact assertions, 2 key-link cross-references, 5 file-presence checks.
- Tier 1 (`check-boundary-map.sh`): SKIP (P01 has no boundary-map produce items).
- Tier 2 (`run-commands.sh`): SKIP (no project-level verification commands configured).
- Tier 3 (behavioral truths): N/A — all P01 truths carry `Check:` sub-items, fully covered at Tier 1.
- Tier 4 (human review): not gated for this phase.

## Patterns established

- **Staged-probe replay shape**: write probe under `tmp/<milestone>-<phase>/`, invoke via `scripts/util/run-probe.sh`, source the classifier and call `classify_command` verbatim, capture stdout byte-exact for the audit's fenced verdict block. Throwaway shim under `scripts/verify/<milestone>/p01-classify-one.sh` as AD-19 single-script-file flat shape.
- **Two-stage deterministic sanitization**: BSD-portable `sed -E` for byte-level redactions (paths, emails, tokens) → `python3` for structural JSON mutation (flag injection). Both stages deterministic, double-run byte-identity verified.
- **Partial-flag fixture realism**: mix pre-M025 unflagged residue with post-M025 flagged entries — models the real downstream user state P02 `--repair` will encounter, not the empty-or-fully-tagged synthetic case.
- **Separate `-sanitize` vs `-sanitized` scripts**: transformer runs once at fixture creation; verifier runs at every phase verification. Naming makes the role unambiguous.
- **Rubric-driven attribution**: verdict + shape + path-prefix triggers map mechanically to Findings A–G, reproducible from `classifier-audit.md` alone.
- **Shape-only verifier discipline**: the verifier asserts frontmatter and section headings and per-line YES/NO tokens, never the M/N arithmetic values themselves — the document body shows the math, the verifier proves the document shape.
- **Corpus-staging delegation**: T03 lands the AP-anchored entries derivable from per-screenshot evidence; P03 owns regression and boundary-case padding to the FR-13 target of 7 entries.

## Dogfood findings

- **auto-loop `--step=V` eval'd `Expected output:` example fences as commands.** First run of T01 verification reported false `AUTO:VERIFY_FAIL` because the parser eval'd `PASS: ...` example output as a literal shell command. Two-layer fix landed in commit `73effdc`: (a) parser-side defensive skip in `scripts/lifecycle/auto-loop.sh:340-353` for verifier-verdict prefixes (`PASS:`, `FAIL:`, `WARN:`, `OK:`, `SKIP:`, `ERROR:`, `INFO:`, `EXPECT:`, `EXPECTED:`, `Expected:`, `Output:`, `Sample:`); (b) plan-author guidance in `commands/plan-phase.md:190` documenting "`## Verification` carries executable checks only; expected output goes in `## Notes`". Regression coverage: `tests/test-auto-loop-verify-extraction.sh` Test 3 + `tests/fixtures/.../T03-PLAN.md`. M028/P01/T01..T03 plans reshaped to match. CLAUDE.md hotfix-log entry captures the dogfood for future plan authors and parser-touchers.
- **Per-task commit discipline drift.** T01 committed its work; T02 did not (orchestrator stitched it up). T03 committed correctly after the dispatch prompt was made explicit. No long-term remediation needed at the phase level — the dispatch prompt convention now reminds agents to commit before writing the summary.

## Roadmap state

P02 (installer + adapter portability + install-side dedup) consumes the canonical fixture (T02 deliverable) and the AP-anchored corpus seed list (T03 staging). No roadmap deviation: the collapse-decision recommendation is `full-5-phase`, so no phase removal or reshaping is triggered. The decisions register requires no new entry — the audit and recommendation are documented in `P01-VERIFICATION.md` itself, which is the canonical evidence artifact per the M028 plan.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P02"
milestone: "M028"
name: "Install-roundtrip pinned-sha gate + per-finding A/F verifiers (FR-6 + SC-2 + SC-5)"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

- **T01 complete**: `pre-bash-shape-guard.sh` self-locates via `BASH_SOURCE[0]`; `p02-hook-self-locate.sh` and `p02-hook-self-conformance.sh` PASS.
- **T02 complete**: `claude-code.sh --hook-config` emits absolute-path leaves with `_orchestrator_managed: true` on every entry; `p02-adapter-absolute-paths.sh` PASSes.
- **T03 complete**: installer stages the hooks payload to `${HOME}/.claude/orchestrator-hooks/`; `settings-merge.sh merge` deduplicates on the `(event, matcher, command)` tuple; `p02-hooks-payload-staged.sh` PASSes.
- **T04 complete**: installer has `--repair` and `--repair --dry-run`; `p02-repair-fixture.sh` PASSes.
- All four upstream verifiers under `scripts/verify/m028/` are already installed and exercise the surface T05 builds the close-out gate over.
- `scripts/lifecycle/after-verify-sync.sh` exists and is invocable. T05's Finding F verifier exercises the Stop-event resolution end-to-end.

## Description

Land three verifiers under `scripts/verify/m028/`:
1. `install-roundtrip.sh` — the FR-6 pinned-sha install→install→uninstall byte-equality gate. The closing-the-loop proof for SC-2 (M025 reversibility extended).
2. `finding-A-verifier.sh` — the per-finding gate for Finding A. Exercises the self-locating hook in a consumer-project context where `$CLAUDE_PROJECT_DIR` does not point at the orchestrator repo.
3. `finding-F-verifier.sh` — the per-finding gate for Finding F. Exercises the resolved Stop-event lifecycle script with no `command not found` diagnostic.

All three are flat single-file scripts under `scripts/verify/m028/` per AD-19. They reuse the isolated-HOME pattern T03's verifier introduced (tmp dir, `HOME=<tmp> bash <installer>`, post-pass cleanup).

The install-roundtrip gate proof, formally:
- **Snapshot 0**: SHA-256 of `${tmp_home}/.claude/settings.json` BEFORE any install (the file may not exist; treat absence as the canonical "empty" pre-state with a sentinel SHA).
- **Snapshot 1**: SHA-256 after first `bash install-claude-code.sh` run.
- **Snapshot 2**: SHA-256 after second `bash install-claude-code.sh` run.
- **Snapshot 3**: SHA-256 after `bash install-claude-code.sh --uninstall` run.

Assertions:
- `Snapshot 1 == Snapshot 2` (idempotency / install-side dedup proof).
- `Snapshot 0 == Snapshot 3` (M025 reversibility — uninstall returns to pre-install canonical bytes).

The Finding A verifier exercises the hook in a consumer-project context. Pattern:
1. Set up isolated HOME under `${TMPDIR}/p02-finding-A-$$`.
2. Run the installer to stage the hooks payload.
3. Set `CLAUDE_PROJECT_DIR=/some/other/path` (a path that is NOT the orchestrator repo) and invoke `bash ${HOME}/.claude/orchestrator-hooks/pre-bash-shape-guard.sh` with a verbatim Finding A screenshot command piped to stdin (in JSON-shaped Claude Code hook event format).
4. Assert the hook resolves its classifier (not silent passthrough) and emits the expected verdict for the test command. The exact test command is a known-rejected M021 corpus entry (e.g., a compound chain > 2 connectors that AP-009 rejects); the verifier confirms the hook's output matches `REJECT:` rather than empty stdout (which would indicate the classifier was not loaded).

The Finding F verifier exercises the lifecycle-script resolution. Pattern:
1. Set up isolated HOME under `${TMPDIR}/p02-finding-F-$$`.
2. Run the installer to stage the hooks payload + register hooks in `${HOME}/.claude/settings.json`.
3. Read the post-install settings.json and extract the Stop-event command string.
4. Confirm the command string starts with `bash ` and ends with `after-verify-sync.sh`.
5. Execute the resolved command with a minimal stub stdin (Claude Code hook event JSON for a Stop event) and assert exit 0 + no `command not found` substring on stderr.

## Steps

1. Author `scripts/verify/m028/install-roundtrip.sh`. Single-file flat shape, bash 3.2 safe, ≥ 30 lines. The script:
    - `set -u`, no `set -e`.
    - Resolves repo root via `cd $(dirname $0)/../../..` and `pwd -P`.
    - Sets `tmp_home="${TMPDIR:-/tmp}/m028-roundtrip-$$"` and `mkdir -p "$tmp_home/.claude"`.
    - Defines a helper `compute_sha()` (function definition at top of script — function defs are AD-19 safe; only inline-blocks are restricted) that takes a file path and writes the SHA-256 to a passed-in destination file. The function uses `shasum -a 256 "$1" > "$2.raw"` then `awk '{print $1}' "$2.raw" > "$2"`. Avoids `$(...)` containing pipe.
    - **Snapshot 0** (pre-install): if `${tmp_home}/.claude/settings.json` does not exist, write a sentinel hash to `${tmp_home}/sha0.txt` (e.g., literal string `EMPTY`); else compute SHA-256.
    - Run installer: `HOME="$tmp_home" bash "${REPO_ROOT}/packaging/install/install-claude-code.sh" --project-dir "$tmp_home" >/dev/null 2>&1`. Capture exit code; FAIL on non-zero.
    - **Snapshot 1**: compute SHA of `${tmp_home}/.claude/settings.json` to `${tmp_home}/sha1.txt`.
    - Run installer again (second install): `HOME="$tmp_home" bash "${REPO_ROOT}/packaging/install/install-claude-code.sh" --project-dir "$tmp_home" >/dev/null 2>&1`.
    - **Snapshot 2**: compute SHA to `${tmp_home}/sha2.txt`.
    - Run uninstall: `HOME="$tmp_home" bash "${REPO_ROOT}/packaging/install/install-claude-code.sh" --uninstall >/dev/null 2>&1`.
    - **Snapshot 3**: SHA-256 of `${tmp_home}/.claude/settings.json` (or sentinel if file removed) to `${tmp_home}/sha3.txt`.
    - Read all four hashes via `awk '{print $1}'` redirects (no `$(... | ...)`). Pattern: `sha0="$(awk '{print $1}' "${tmp_home}/sha0.txt")"`.
    - Assertion 1 (idempotency): `[ "$sha1" = "$sha2" ]`. On FAIL, emit `FAIL: install-roundtrip idempotency: sha1=$sha1 sha2=$sha2` to stderr, leave tmp dir, exit 1.
    - Assertion 2 (reversibility): `[ "$sha0" = "$sha3" ]`. On FAIL, emit `FAIL: install-roundtrip reversibility: sha0=$sha0 sha3=$sha3` to stderr, leave tmp dir, exit 1.
    - On all-pass, emit `PASS: install-roundtrip idempotency=$sha1 reversibility=$sha0` to stdout, clean up tmp dir, exit 0.

    **Note on multi-stage shasum extraction within AD-19**: every SHA computation uses the helper function which writes to a tmp file then awk-extracts; no compound `$(... | ...)` anywhere. Function bodies in bash 3.2 are NOT subject to the AP-009 classifier (which scans command-line shape, not function-body shape) — the function may use multi-line clear bash inside `compute_sha() { ... }`.

2. Author `scripts/verify/m028/finding-A-verifier.sh`. Single-file flat shape, ≥ 20 lines, bash 3.2. The script:
    - `set -u`, no `set -e`.
    - Resolves repo root.
    - Sets `tmp_home="${TMPDIR:-/tmp}/m028-finding-A-$$"`.
    - Runs installer with `HOME="$tmp_home"` to stage the hooks payload.
    - Sets `CLAUDE_PROJECT_DIR="${tmp_home}/fake-project"` (a non-orchestrator path; create the dir empty: `mkdir -p "$CLAUDE_PROJECT_DIR"`).
    - Constructs a minimal Claude Code hook event JSON for a Bash tool call. Example payload (heredoc into a tmp file):
        ```json
        {
          "tool_name": "Bash",
          "tool_input": {
            "command": "bash -c 'a && b && c && d && e'"
          }
        }
        ```
        The command body has 4 `&&` connectors — guaranteed AP-009 reject under M021 classifier. Write the JSON to `${tmp_home}/hook-event.json`.
    - Invoke the staged hook with the JSON on stdin: `HOME="$tmp_home" CLAUDE_PROJECT_DIR="${tmp_home}/fake-project" bash "${tmp_home}/.claude/orchestrator-hooks/pre-bash-shape-guard.sh" < "${tmp_home}/hook-event.json" > "${tmp_home}/hook-stdout.txt" 2> "${tmp_home}/hook-stderr.txt"`. Capture exit code in `hook_rc=$?`.
    - Assertion 1: `hook_rc -eq 2` (the hook's reject exit code per the M021 protocol — Finding A in the wild was the hook returning 0 silently because the classifier didn't load; T05 confirms it now actually rejects).
    - Assertion 2: `grep -q "REJECT" "${tmp_home}/hook-stderr.txt"` succeeds.
    - On all-pass, emit `PASS: finding-A — self-locating hook fires in non-orchestrator-repo CLAUDE_PROJECT_DIR context, classifier loaded, REJECT verdict surfaced` and clean up; exit 0.
    - On FAIL, leave the tmp dir for inspection and exit 1 with a descriptive `FAIL:` to stderr.

    **Important**: if the M021 hook protocol's exit codes are different in the current implementation (e.g., reject is exit 1 not exit 2), the verifier must match the actual protocol. Read `scripts/hooks/pre-bash-shape-guard.sh` to confirm the protocol before authoring the verifier; the file's header comment (lines 1–18 at the M021 baseline) documents it.

3. Author `scripts/verify/m028/finding-F-verifier.sh`. Single-file flat shape, ≥ 20 lines, bash 3.2. The script:
    - `set -u`, no `set -e`.
    - Resolves repo root.
    - Sets `tmp_home="${TMPDIR:-/tmp}/m028-finding-F-$$"`.
    - Runs installer with `HOME="$tmp_home"` to stage payload + register hooks.
    - Reads `${tmp_home}/.claude/settings.json`, extracts the Stop-event command string. Pattern: write the file to a temp work file and use `grep` + `sed` to extract the `"command":` value under the Stop array. Plain pattern: `python3 -c "import json,sys; s=json.load(open('${tmp_home}/.claude/settings.json')); print(s['hooks']['Stop'][0]['hooks'][0]['command'])" > "${tmp_home}/stop-cmd.txt"`. (python3 is the baseline per M025/P01/T02; OK to use here.)
    - Reads the command: `stop_cmd="$(awk '{print $0}' "${tmp_home}/stop-cmd.txt")"` — wait, this captures the full line; for a single-line file, plain `read`: `read -r stop_cmd < "${tmp_home}/stop-cmd.txt"`.
    - Assertion 1: `stop_cmd` starts with `bash ` (literal). Pattern: `case "$stop_cmd" in 'bash '*) ;; *) echo "FAIL: stop_cmd does not start with 'bash ': $stop_cmd" >&2; exit 1 ;; esac`.
    - Assertion 2: `stop_cmd` ends with `.sh`. Pattern: `case "$stop_cmd" in *'.sh') ;; *) echo "FAIL: stop_cmd does not end with .sh: $stop_cmd" >&2; exit 1 ;; esac`.
    - Assertion 3: the resolved command file exists. Extract the path from `stop_cmd` (strip the leading `bash `): `cmd_path="${stop_cmd#bash }"`. Then `[ -f "$cmd_path" ]` else FAIL.
    - Assertion 4: invoke the resolved command with a minimal Stop-event stdin and assert no `command not found` on stderr. Pattern: emit a tiny JSON Stop event to stdin via heredoc-redirect, capture stderr, grep for `command not found`. The script `after-verify-sync.sh` may exit non-zero in an isolated test context (it depends on M025 lifecycle state); the gate is "no `command not found`", not "exit 0". Pattern: `bash "$cmd_path" < /dev/null > "${tmp_home}/stop-stdout.txt" 2> "${tmp_home}/stop-stderr.txt"; sync_rc=$?` — then `if grep -q 'command not found' "${tmp_home}/stop-stderr.txt"; then echo "FAIL: command not found on Stop event"; exit 1; fi`.
    - On all-pass, emit `PASS: finding-F — Stop event resolves $cmd_path, no command-not-found diagnostic` to stdout, clean up tmp dir, exit 0.

4. Run all three verifiers via `scripts/util/run-probe.sh`:

    ```bash
    bash scripts/util/run-probe.sh scripts/verify/m028/install-roundtrip.sh
    bash scripts/util/run-probe.sh scripts/verify/m028/finding-A-verifier.sh
    bash scripts/util/run-probe.sh scripts/verify/m028/finding-F-verifier.sh
    ```

    Confirm all three PASS. If any FAIL, root-cause via the FAIL diagnostic — the tmp dir is left in place on FAIL for inspection.

5. Document a known-pinned post-install SHA in `.orchestrator/milestones/M028/phases/P02/P02-VERIFICATION.md` (or in the verifier comment block) for the install-roundtrip output. Pattern: capture `sha1` from a known-good run and pin it as a comment in `install-roundtrip.sh`. Future drift is then detectable by simple inspection — if `sha1` changes without an explanatory M028 change, something silently broke. (This is informational pinning, not a hard gate; the hard gate is the idempotency + reversibility assertions.)

## Must-Haves

This task addresses three phase Truths:
- "`settings-merge.sh merge` is install-side idempotent — running the install path twice in succession against the same target settings.json produces a byte-identical file (SHA-256 equal)." (T05's `install-roundtrip.sh` is the canonical-bytes proof.)
- "`bash packaging/install/install-claude-code.sh --uninstall` against a post-install state returns `~/.claude/settings.json` to its pre-install canonical bytes." (Same gate, reversibility leg.)
- "The Finding A end-to-end verifier passes" / "The Finding F end-to-end verifier passes."

It produces three verifiers: `install-roundtrip.sh`, `finding-A-verifier.sh`, `finding-F-verifier.sh`.

## Verification

```bash
bash scripts/verify/m028/install-roundtrip.sh
```

```bash
bash scripts/verify/m028/finding-A-verifier.sh
```

```bash
bash scripts/util/run-probe.sh scripts/verify/m028/finding-F-verifier.sh
```

## Notes

Expected output for `install-roundtrip.sh`: `PASS: install-roundtrip idempotency=<sha1-hex> reversibility=<sha0-hex>` (sha0 may be the literal string `EMPTY` if pre-install settings.json did not exist).

Expected output for `finding-A-verifier.sh`: `PASS: finding-A — self-locating hook fires in non-orchestrator-repo CLAUDE_PROJECT_DIR context, classifier loaded, REJECT verdict surfaced`.

Expected output for `finding-F-verifier.sh`: `PASS: finding-F — Stop event resolves <absolute-path>/after-verify-sync.sh, no command-not-found diagnostic`.

The install-roundtrip gate is the canonical-bytes proof for SC-2. The pinned-SHA comment in the verifier (Step 5) is the audit trail; future M028 changes that affect the JSON shape will alter the SHA and the comment must be updated in the same PR — that drift IS the audit signal.

The Finding A verifier's choice of `bash -c 'a && b && c && d && e'` as the test command is deliberate: 4 `&&` connectors guaranteed reject AP-009 under both M021 and M028 classifiers (no risk of P03's classifier extension changing the verdict). The verifier is stable across M028's classifier evolution.

The Finding F verifier's `command not found` grep is a substring check — the actual CC error format may be `bash: <cmd>: command not found` or similar; the substring `command not found` is robust to both forms.

These three verifiers, together with the four T01–T04 verifiers, constitute P02's verification surface (8 verifiers total). P05's `run-all.sh` (Phase 5 deliverable) will aggregate these plus P03/P04 verifiers into a single CI gate.

## Inputs

### From Previous Tasks

- `scripts/hooks/pre-bash-shape-guard.sh` (from T01) — self-locating hook. Finding-A verifier exercises end-to-end.
- `scripts/dispatch/adapters/runtime/claude-code.sh` (from T02) — emits absolute-path leaves. Indirectly exercised via install-roundtrip + finding-F (which reads the post-install settings.json).
- `packaging/install/install-claude-code.sh` (from T03 + T04) — installer with payload-staging, settings-merge dedup, `--repair`, and `--uninstall`. T05's roundtrip exercises install + install + uninstall.
- `scripts/util/settings-merge.sh` (from T03) — `(event, matcher, command)` tuple dedup. Indirectly exercised by install-roundtrip's idempotency leg.

### From Disk (Pre-existing)

- `scripts/lifecycle/after-verify-sync.sh` — M025 lifecycle script. Finding-F verifier invokes it with stub stdin.
- `scripts/util/run-probe.sh` — shape-safe wrapper for verifier invocation.

## Constraints

- **AD-19 single-script-file shape (CON-1)**: all three verifiers are flat single-file scripts. SHA computation uses helper functions (function bodies are not classifier-scanned) + tmp-file + awk pattern; no `$(... | ...)` and no `cmd <file` nested inside `$()`. The Stop-command extraction uses python3 + write-to-tmp-file + read. The hook-output extraction uses redirect, not pipe.
- **bash 3.2 + POSIX sh (CON-2)**: every line runs on bash 3.2.
- **No new runtime deps (CON-6)**: T05 uses python3 (M025 baseline), `shasum`, `awk`, `grep`, `case`-pattern matching. No new deps.
- **M025 reversibility (CON-4)**: install-roundtrip.sh is the canonical-bytes proof. The `Snapshot 0 == Snapshot 3` assertion is the contract.
- **Non-Goal: classifier extension**: T05's Finding A verifier uses an AP-009-rejected test command (compound chain > 2). It does NOT exercise AP-010..AP-014 (P03's classifier extension) — those are tested by P03's per-finding-B/G verifiers. T05's scope is hook portability + adapter emission + installer idempotency.
- **Tmp-dir hygiene**: every verifier cleans up its tmp dir on PASS. On FAIL, the tmp dir is preserved for post-mortem inspection (per the existing M021/M025 verifier convention).
- **Hook protocol stability**: T05's Finding A verifier asserts on the hook's exit code (likely 2 for reject) and stderr substring (`REJECT`). If the hook protocol changes in a future M028 phase, the verifier must be re-aligned. T05 reads the current protocol from the hook's header comment before authoring.

## State Context

- **Current State**: executing
- **Milestone**: M028
- **Phase**: P02
- **Task**: T05-roundtrip-and-verifiers
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **AD-19 single-script-file shape (CON-1)**: all three verifiers are flat single-file scripts. SHA computation uses helper functions (function bodies are not classifier-scanned) + tmp-file + awk pattern; no `$(... | ...)` and no `cmd <file` nested inside `$()`. The Stop-command extraction uses python3 + write-to-tmp-file + read. The hook-output extraction uses redirect, not pipe.
- **bash 3.2 + POSIX sh (CON-2)**: every line runs on bash 3.2.
- **No new runtime deps (CON-6)**: T05 uses python3 (M025 baseline), `shasum`, `awk`, `grep`, `case`-pattern matching. No new deps.
- **M025 reversibility (CON-4)**: install-roundtrip.sh is the canonical-bytes proof. The `Snapshot 0 == Snapshot 3` assertion is the contract.
- **Non-Goal: classifier extension**: T05's Finding A verifier uses an AP-009-rejected test command (compound chain > 2). It does NOT exercise AP-010..AP-014 (P03's classifier extension) — those are tested by P03's per-finding-B/G verifiers. T05's scope is hook portability + adapter emission + installer idempotency.
- **Tmp-dir hygiene**: every verifier cleans up its tmp dir on PASS. On FAIL, the tmp dir is preserved for post-mortem inspection (per the existing M021/M025 verifier convention).
- **Hook protocol stability**: T05's Finding A verifier asserts on the hook's exit code (likely 2 for reject) and stderr substring (`REJECT`). If the hook protocol changes in a future M028 phase, the verifier must be re-aligned. T05 reads the current protocol from the hook's header comment before authoring.

### Acceptance Criteria

This task addresses three phase Truths:
- "`settings-merge.sh merge` is install-side idempotent — running the install path twice in succession against the same target settings.json produces a byte-identical file (SHA-256 equal)." (T05's `install-roundtrip.sh` is the canonical-bytes proof.)
- "`bash packaging/install/install-claude-code.sh --uninstall` against a post-install state returns `~/.claude/settings.json` to its pre-install canonical bytes." (Same gate, reversibility leg.)
- "The Finding A end-to-end verifier passes" / "The Finding F end-to-end verifier passes."

It produces three verifiers: `install-roundtrip.sh`, `finding-A-verifier.sh`, `finding-F-verifier.sh`.

### Files To Touch

- `scripts/hooks/pre-bash-shape-guard.sh` (modify)
- `scripts/dispatch/adapters/runtime/claude-code.sh` (modify)
- `scripts/util/settings-merge.sh` (modify)
- `packaging/install/install-claude-code.sh` (modify)
- `scripts/verify/m028/install-roundtrip.sh` (create)
- `scripts/verify/m028/finding-A-verifier.sh` (create)
- `scripts/verify/m028/finding-F-verifier.sh` (create)
- `scripts/verify/m028/p02-hook-self-locate.sh` (create)
- `scripts/verify/m028/p02-hook-self-conformance.sh` (create)
- `scripts/verify/m028/p02-adapter-absolute-paths.sh` (create)
- `scripts/verify/m028/p02-hooks-payload-staged.sh` (create)
- `scripts/verify/m028/p02-repair-fixture.sh` (create)
- `tests/fixtures/m028-post-repair-canonical.json` (create)

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