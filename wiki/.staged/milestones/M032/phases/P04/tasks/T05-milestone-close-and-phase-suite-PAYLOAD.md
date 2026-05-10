---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T05-milestone-close-and-phase-suite (Phase P04, Milestone M032)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~300 | required |
| Upstream Context | 981-1231 | ~9100 | required |
| Task Plan | 1233-1905 | ~8300 | required |
| State Context | 1907-1913 | ~100 | required |
| First-Turn Completeness | 1915-1986 | ~1200 | required |
| **Total** | | **~29800** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 826
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
hit_count: 826
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
hit_count: 826
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
hit_count: 826
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
hit_count: 718
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
hit_count: 718
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
hit_count: 718
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
hit_count: 826
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
hit_count: 718
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
hit_count: 718
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
hit_count: 718
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
hit_count: 826
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
hit_count: 826
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
hit_count: 826
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
hit_count: 718
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
hit_count: 718
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
hit_count: 718
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
hit_count: 826
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
hit_count: 718
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
hit_count: 718
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
hit_count: 826
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
hit_count: 826
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
hit_count: 718
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
hit_count: 718
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
hit_count: 718
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
hit_count: 373
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
hit_count: 373
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
hit_count: 373
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
hit_count: 402
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
hit_count: 402
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
hit_count: 392
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
     m032-p04-* prefix to avoid collision with M030/M031/M032 P00–P03
     existing verifiers. Verifier scripts are co-authored alongside their
     corresponding artifact within the SAME task per plan-time discipline
     rule 2. -->

### Truths

- `scripts/wiki/wiki-scan-sources.sh` is amended additively to enumerate
  three new source families per FR-17 + FR-18 + FR-19. (a) FR-17 — every
  `.orchestrator/proposals/*.md` entry is emitted as a record with category
  prefix `proposals:<basename-without-extension>` (e.g. `proposals:M032-wiki-distribution-and-init-integration`),
  rel-path `proposals/<file>` (under `.orchestrator/`), and a `stage:` badge
  appended to the title field. The badge is derived from a YAML frontmatter
  `stage:` field (`stub | brief | specified | active | closed`); entries
  lacking the field render with `stage: unknown` (no exclusion per US-7
  AS-1). The badge appears as `<title> [stage]` in the title slot — e.g.

<dispatch-volatile>

## Upstream Context


### P02 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P02"
parent: "M032"
milestone: "M032"
provides:
  - "commands/wiki-init.md (orchestrator:wiki-init command document,MEM012 structure); scripts/lifecycle/wiki-init.sh (FR-5 default-scope canonical implementation,bash 3.2 + AD-19 single-script-file shape); wiki/mkdocs.yml four-field placeholder amendment (bundle template state) + FR-6 self-application loop closed against orchestrator repo (resolved orchestrator-identity values restored); packaging/bundle/manifest.yml additive wiki/ entry under project_assets:; tools/verify/m032-p02-wiki-init-command-shape.sh + tools/verify/m032-p02-wiki-init-default-scope.sh + tools/verify/m032-p02-mkdocs-templating-and-self-application.sh + tools/verify/lib/m032-p02-wiki-serve-probe.sh helper,commands/init.md --with-wiki documentation block; init-project.sh recognizes --with-wiki/--with-giscus/--deploy with composition validation; sequential-atomicity dispatch of wiki-init.sh per FR-11/MIT-011; M032_WIKI_INIT_FORCE_EXIT test-only escape hatch in wiki-init.sh; tools/verify/m032-p02-init-with-wiki-passthrough.sh four-scenario verifier,wiki/glossary.md path-convention with three populated US-6-format entries (Constitution,Knowledge Graph,Milestone); scripts/wiki/wiki-scan-sources.sh --include-glossary additive flag emitting top:glossary record as second top-level source after Constitution; scripts/wiki/wiki-generate-nav.sh HAS_GLOSSARY discovery flag + emit_leaf 1 'Glossary' 'glossary.md' between Constitution and Decisions; scripts/wiki/wiki-generate-stubs.sh top:glossary case-arm routing stub to wiki/docs/glossary.md via build_canonical_repo_rel; tools/verify/m032-p02-glossary-format-invariant.sh + tools/verify/m032-p02-glossary-scanner-and-nav.sh verifiers,scripts/knowledge/lookup-mems.sh --kind=glossary READER adapter (parses wiki/glossary.md ### TERM headings,synthesizes M020-knowledge-record-compatible records on stdout,honors [M031](../../../../../milestones/M031/index.md) Quick/Standard/Full profile contract per FR-16 with MIT-010 safe-default-no-terms fallback under --profile=quick); stable id derivation gloss-<slug> via lower-case + non-alphanumeric-collapse + leading/trailing-dash-strip; tools/verify/m032-p02-lookup-mems-glossary.sh six-scenario verifier,tests/m032-acceptance/p02-wiki-init-default-scope.sh (SC-3); tests/m032-acceptance/p02-glossary-surface.sh (SC-7); tests/paired-m032-m033/seam-A.sh + seam-B.sh + seam-C.sh paired-launch contracts; tools/verify/m032-p02-acceptance-shape-sc3.sh + m032-p02-acceptance-shape-sc7.sh + m032-p02-seam-a-shape.sh + m032-p02-seam-b-shape.sh + m032-p02-seam-c-shape.sh + m032-p02-phase-suite.sh + m032-p02-scope-guard.sh; tools/verify/fixtures/m032-p02-baseline-ref.txt baseline captured"
requires:
  - "P01"
affects:
  - "P03,P04"
key_files:
  - "commands/wiki-init.md,scripts/lifecycle/wiki-init.sh,wiki/mkdocs.yml,packaging/bundle/manifest.yml,tools/verify/m032-p02-wiki-init-command-shape.sh,tools/verify/m032-p02-wiki-init-default-scope.sh,tools/verify/m032-p02-mkdocs-templating-and-self-application.sh,tools/verify/lib/m032-p02-wiki-serve-probe.sh,wiki/glossary.md,commands/init.md,scripts/lifecycle/init-project.sh,tools/verify/m032-p02-init-with-wiki-passthrough.sh,scripts/wiki/wiki-scan-sources.sh,scripts/wiki/wiki-generate-nav.sh,scripts/wiki/wiki-generate-stubs.sh,wiki/docs/glossary.md,tools/verify/m032-p02-glossary-format-invariant.sh,tools/verify/m032-p02-glossary-scanner-and-nav.sh,scripts/knowledge/lookup-mems.sh,tools/verify/m032-p02-lookup-mems-glossary.sh,tests/m032-acceptance/p02-wiki-init-default-scope.sh,tests/m032-acceptance/p02-glossary-surface.sh,tests/paired-m032-m033/seam-A.sh,tests/paired-m032-m033/seam-B.sh,tests/paired-m032-m033/seam-C.sh,tools/verify/m032-p02-acceptance-shape-sc3.sh,tools/verify/m032-p02-acceptance-shape-sc7.sh,tools/verify/m032-p02-seam-a-shape.sh,tools/verify/m032-p02-seam-b-shape.sh,tools/verify/m032-p02-seam-c-shape.sh,tools/verify/m032-p02-phase-suite.sh,tools/verify/m032-p02-scope-guard.sh,tools/verify/fixtures/m032-p02-baseline-ref.txt"
key_decisions:
  - "FR-5,FR-6,FR-12,FR-15,FR-22,MIT-002,AD-5,AD-19,MEM012,MEM001,#Q-2,FR-11,MIT-011,CON-3,AP-009,MEM030,US-6,CON-6,FR-16,MIT-010,MEM008,MEM031,SC-3,SC-7,MIT-001,SC-13,Q-4,Q-B"
patterns_established:
  - "self-application detection (REPO_ROOT == PROJECT_DIR) skips bundle staging in dogfooding loops; field-line rewrite is idempotent against BOTH placeholders AND already-resolved values where the bundle source IS the orchestrator-local resolved copy; pre-stage idempotency short-circuit avoids cp-overwrites-operator-edits failure mode; lowercase owner for site_url + preserved case for repo_url matches GitHub Pages canonical convention; verifier toolchain-probe via symlink-only PATH excluding python3/pip3 exercises FR-12 fail-closed without breaking other tool lookups; wiki-serve probe helper prefers wiki-serve.sh --probe (mkdocs build --strict) for port-free health check with start+curl+kill fallback per AD-19 envelope,sequential-atomicity dispatch (init-project.sh writes outputs first; wiki-init.sh runs second; wiki-init.sh failure preserves init outputs and propagates literal exit code with init-complete-wiki-pending diagnostic); M032_WIKI_INIT_FORCE_EXIT env-var-only test-only failure-injection seam; pre-stage no-op short-circuit (wiki-init.sh skips bundle-staging when wiki/mkdocs.yml already exists from prior installer project_assets loop,avoiding FR-22 collision-check operator-owned trip),top-level scanner record + nav-generator HAS_* flag + stub-generator case-arm trio for new top-level wiki sources; verifier-contract-over-verifier-skeleton (implement plan's contract wording when embedded verifier code conflicts); side-effect-free verifier via backup-and-trap-restore (EXIT/INT/TERM),reader-only knowledge-adapter boundary (M020 retains schema-authority over on-disk knowledge/<category>/MEM*.md; M032 synthesizes records on-the-fly for build-context.sh consumption); --kind=<glossary|mem|reference> extensible argument-parsing seam at the adapter front; safe-default-no-terms fallback fires BEFORE any I/O on the budget-conscious Quick path (MIT-010); single-pipe-inside-function-body for slugify (AD-19-OK because harness shape-detection scope does not extend into function bodies); intermediary-variable prefix-strip _prefix=###  + ${line#$_prefix} to disambiguate bash 3.2 ${line#### } parameter-expansion parser quirk,paired-milestone seam-script convention under tests/paired-m032-m033/ shared by both M032 and [M033](../../../../../milestones/M033/index.md) verifier suites; scope-guard first-run-captures-baseline pattern (mirrors P01 m032-p01-baseline-ref.txt precedent); SC-7 actual contract reified (Glossary follows Constitution,not second-top-level-entry) -- the payload awk count was off-by-one against the Home-prefix nav; Seam-B identity-leak assertion (NOT file-absence) -- install-claude-code stages wiki/ from REPO_ROOT before wiki-init runs,so file presence is expected and the load-bearing invariant is that the FIXTURE identity is not baked into mkdocs.yml; grep -c under set -eu in command-substitution requires || true fallback to avoid silent abort when count==0"
drill_down_paths:
  - "[.orchestrator/milestones/M032/phases/P02/tasks/T01-wiki-init-default-scope-SUMMARY.md](../../../../../milestones/M032/phases/P02/tasks/T01-wiki-init-default-scope-SUMMARY.md), [.orchestrator/milestones/M032/phases/P02/tasks/T02-init-with-wiki-passthrough-SUMMARY.md](../../../../../milestones/M032/phases/P02/tasks/T02-init-with-wiki-passthrough-SUMMARY.md), [.orchestrator/milestones/M032/phases/P02/tasks/T03-glossary-surface-SUMMARY.md](../../../../../milestones/M032/phases/P02/tasks/T03-glossary-surface-SUMMARY.md), [.orchestrator/milestones/M032/phases/P02/tasks/T04-glossary-knowledge-adapter-SUMMARY.md](../../../../../milestones/M032/phases/P02/tasks/T04-glossary-knowledge-adapter-SUMMARY.md), [.orchestrator/milestones/M032/phases/P02/tasks/T05-acceptance-and-seam-and-suite-SUMMARY.md](../../../../../milestones/M032/phases/P02/tasks/T05-acceptance-and-seam-and-suite-SUMMARY.md)"
duration: "460m"
verification_result: "pass"
completed_at: "2026-05-04T20:16:37Z"
observability_surfaces:
  - "none"
---

## What Shipped

P02 lands the wiki tooling distribution path end-to-end: the
`orchestrator:wiki-init` command, the `init --with-wiki` paired-launch
passthrough, the wiki/glossary.md US-6 surface and its scan/nav/stub
routing, the `lookup-mems.sh --kind=glossary` knowledge-adapter, the SC-3
+ SC-7 acceptance scripts, the M032+M033 paired-launch seam tests
(`tests/paired-m032-m033/seam-A.sh|seam-B.sh|seam-C.sh`), and the
`m032-p02-phase-suite.sh` aggregator. FR-6 self-application loop is
closed: the orchestrator dogfoods its own wiki via
`scripts/lifecycle/wiki-init.sh` against the orchestrator-local wiki/
tree.

The five task tranches:

1. **T01 — wiki-init default scope (FR-5 + FR-6)**: authored
   `commands/wiki-init.md` + `scripts/lifecycle/wiki-init.sh` (single-script
   bash 3.2, AD-19 shape) + `wiki/mkdocs.yml` four-field placeholder
   amendment + the `wiki/` entry under `project_assets:` in
   `packaging/bundle/manifest.yml`. Self-application detection
   (`REPO_ROOT == PROJECT_DIR`) skips bundle-staging in the
   orchestrator-dogfooding-itself path. mkdocs.yml templating uses
   field-line rewrite (`^site_name:.*` → `site_name: "<value>"`) — idempotent
   against both starting states because the bundle source IS the
   orchestrator-local resolved file. Three verifiers green (15/15 + 19/19 +
   15/15).

2. **T02 — init --with-wiki passthrough (FR-11 + FR-15)**:
   `commands/init.md` documents the flag; `scripts/lifecycle/init-project.sh`
   recognizes `--with-wiki` / `--with-giscus` / `--deploy` with composition
   validation and dispatches `wiki-init.sh` sequentially per FR-11/MIT-011.
   `M032_WIKI_INIT_FORCE_EXIT` env-var test-only escape hatch added for
   failure-injection coverage. Verifier
   `tools/verify/m032-p02-init-with-wiki-passthrough.sh` exercises four
   scenarios. Two design adjustments documented inline: (a) test 2 checks
   absence of `wiki-init: done` rather than absence of `wiki/mkdocs.yml`;
   (b) test 4 checks absence of any `wiki-init:` diagnostic. Both preserve
   the spirit of the original task plan; rationale carried in T02-SUMMARY.

   T02 also surfaced a P01-verifier regression created by T01 (5th
   project_assets entry vs. hardcoded `expected 4`; commands count drift
   33→34 from `wiki-init.md`; scripts count drift 1160→1161 from
   `wiki-init.sh`). Resolved as an in-flight repair (commit `4dedb92a`)
   relaxing `m032-p01-manifest-schema-shape.sh` + `m032-p01-reader-emits-tuples.sh`
   to `-ge 4` + source-count parity, and refreshing the pre-M032 golden
   to commands=34, scripts=1161, total=1277. P01 phase-suite recovered to
   11/11.

3. **T03 — glossary surface (FR-13 + FR-14, US-6)**: populated
   `wiki/glossary.md` with three alphabetized US-6-format entries
   (Constitution, Knowledge Graph, Milestone). Wired the
   `top:glossary` source through `scripts/wiki/wiki-scan-sources.sh`
   (`--include-glossary` flag), `scripts/wiki/wiki-generate-nav.sh`
   (Glossary slot between Constitution and Decisions), and
   `scripts/wiki/wiki-generate-stubs.sh` (top:glossary case-arm routing).
   The plan-time-sketched stub-generator was NOT path-agnostic; T03
   added a routing case-arm. Two verifiers green.

4. **T04 — glossary knowledge-adapter (FR-16 + MIT-010)**:
   `scripts/knowledge/lookup-mems.sh --kind=glossary` reads
   `wiki/glossary.md`, parses `### TERM` headings, synthesizes
   M020-knowledge-record-compatible records on stdout. Honors M031
   Quick/Standard/Full profile contract; safe-default-no-terms fallback
   (MIT-010) fires before any I/O on the budget-conscious Quick path.
   Stable id derivation `gloss-<slug>` via lowercase + non-alphanumeric
   collapse + leading/trailing-dash strip. Six-scenario verifier green.

5. **T05 — acceptance + seam + suite**: SC-3 + SC-7 acceptance scripts
   (`tests/m032-acceptance/p02-wiki-init-default-scope.sh` +
   `p02-glossary-surface.sh`); the M032+M033 paired-launch seam contracts
   (`tests/paired-m032-m033/seam-A.sh` + `seam-B.sh` + `seam-C.sh`); the
   m032-p02-phase-suite.sh aggregator (12/12 PASS) and the
   m032-p02-scope-guard.sh (3/0 PASS, 13 in-scope paths). Baseline ref
   captured at `tools/verify/fixtures/m032-p02-baseline-ref.txt`.
   T05 modified zero T01–T04 deliverables.

## Verification Results

P02 phase-suite: **12/12 PASS**, scope-guard 3/0 PASS, all task-level
verifiers green at task close. Acceptance: SC-3 + SC-7 PASS. Paired-launch
seams: A/B/C all PASS. P01 phase-suite: 11/11 PASS post in-flight repair.

## Key Decisions

- **FR-5 + FR-6 (self-application loop)**: the orchestrator dogfoods its
  own wiki — `scripts/lifecycle/wiki-init.sh` runs against the
  orchestrator's own tree, with detection that skips bundle-staging when
  `REPO_ROOT == PROJECT_DIR`.
- **FR-11 + MIT-011 (sequential atomicity)**: `init-project.sh` writes its
  outputs first; `wiki-init.sh` runs second; if `wiki-init.sh` fails, init
  outputs are preserved and the literal exit code propagates with an
  `init-complete-wiki-pending` diagnostic.
- **MIT-010 (safe-default-no-terms)**: glossary-adapter Quick path
  fail-fast fallback fires before any I/O — under
  `lookup-mems.sh --kind=glossary --profile=quick` an empty/missing
  glossary returns nothing on stdout instead of erroring.
- **US-6 (glossary format invariant)**: `### TERM` headings, alphabetized,
  with structured body. Format-invariant verifier locks the contract.
- **Verifier-contract-over-verifier-skeleton**: when a plan-time-sketched
  verifier line conflicts semantically with the reified contract, the
  ship shape implements the contract wording. Two cases in T02
  (test 2 + test 4 documented inline); one case in T03 (SC-7 nav-position
  off-by-one against the Home-prefix nav).

## Patterns Established

- Self-application detection (`REPO_ROOT == PROJECT_DIR`) skips bundle
  staging in dogfooding loops.
- Field-line rewrite (`^key:.*` → `key: "<value>"`) is idempotent against
  both placeholder and resolved starting states when the bundle source IS
  the orchestrator-local resolved copy.
- Sequential-atomicity dispatch (writes-first-then-secondary; secondary
  failure preserves primary outputs and propagates exit code with
  diagnostic).
- Top-level scanner record + nav-generator HAS_* flag + stub-generator
  case-arm trio for new top-level wiki sources (replicable for future
  `top:*` source types).
- Reader-only knowledge-adapter boundary: M020 retains schema-authority
  over on-disk `knowledge/<category>/MEM*.md`; M032 synthesizes records
  on-the-fly for `build-context.sh` consumption — no MEM-file writes.
- Side-effect-free verifier via backup-and-trap-restore (EXIT/INT/TERM)
  for verifiers that must mutate-then-revert state.
- Paired-milestone seam-script convention at
  `tests/paired-m032-m033/seam-{A,B,C}.sh` shared by both M032 and M033
  verifier suites — reusable for future paired-launch milestones.
- `M0##_<COMMAND>_FORCE_EXIT` env-var-only test-only failure-injection
  seam (replicable for any milestone's failure-coverage verifier).
- Pre-stage no-op short-circuit (skip bundle-staging when target file
  already exists from a prior installer project_assets loop) — avoids
  the FR-22 collision-check operator-owned trip in dogfood loops.
- bash 3.2 parameter-expansion quirk: `${line#### }` parser-confuses with
  literal-`#` strip; resolved via intermediary `_prefix=###  ` +
  `${line#$_prefix}`.
- `grep -c` under `set -eu` in command-substitution requires `|| true`
  fallback — silent abort when count==0 otherwise.

## Affects Downstream

- **P03 (--with-giscus + --deploy composition)** — picks up the FR-15
  composition validation surface, the wiki-init dispatch envelope, and
  the wiki-serve probe helper.
- **P04 (acceptance + closure)** — extends the m032-p02-phase-suite.sh
  pattern + scope-guard convention to P03 + P04 verifiers.
- **M033** — paired-launch seams (`tests/paired-m032-m033/seam-{A,B,C}.sh`)
  are shared contracts; M033's P05 closure invokes the same seam suite.
- **M020 / M031 knowledge layer** — `lookup-mems.sh --kind=glossary`
  participates in the M031 Quick/Standard/Full profile contract; the
  reader-only adapter pattern is reusable for any future
  schema-foreign knowledge source.


### P03 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P03"
parent: "M032"
milestone: "M032"
provides:
  - "FR-7 partial templating; FR-8 --with-giscus scope on wiki-init.sh; SC-4 acceptance; three P03 verifiers; in-flight repair to P02 verifier check 10,FR-9 + MIT-007 + MIT-008 --deploy scope on wiki-init.sh (four-step ordered sequence: gh api PATCH discussions=true | wiki-deploy.sh | MIT-007 read-before-write Pages guard | gh api PUT /pages); FR-10 cwd-vs-repo_url sanity gate on wiki-deploy.sh as gate-0 (Finding J counter-pattern); structured wiki-deploy-mutation JSONL audit-trail with success and failure record shapes appended to .orchestrator/execution-log.jsonl BEFORE live URL print; --force-pages-reconfigure escape hatch; M032_DEPLOY_GH_API_STUB and M032_DEPLOY_GH_API_STUB_DIR test-only env-var stub envelope per M026/MEM030; M032_WIKI_DEPLOY_BYPASS_CWD_GATE test-only bypass; new exit codes 10-13; tools/verify/m032-p03-deploy-scope.sh (18/18 PASS) + tools/verify/m032-p03-wiki-deploy-cwd-gate.sh (8/8 PASS); in-flight repair to m032-p02-wiki-init-default-scope.sh check 11 (reject-stub assertion replaced with stub-mode workflow assertion),FR-14 region split on scripts/wiki/wiki-generate-nav.sh (# >>> auto-nav regenerated wholly; # >>> custom-nav preserved verbatim across regenerates; # >>> M012-P01 nav legacy markers recognized only for one-time migration); US-5 AS-2 empty-legacy migration (rename markers in-place + append empty custom-nav,zero diagnostic); MIT-005 non-empty-legacy migration (move content verbatim into new custom-nav region + emit 'Migrated <N> custom nav entries from legacy markers to custom-nav region' diagnostic naming preserved-entry count); US-5 AS-3 self-healing (re-create deleted custom-nav markers at standard slot immediately after MARKER_AUTO_END); count_between_markers helper (skips blanks+comments to match operator mental model of nav entries); extract_between_markers helper (preserves all bytes including comments to avoid silent comment loss); SC-6 acceptance script tests/m032-acceptance/p02-wiki-generate-nav-custom-region.sh (4/4 PASS,all four FR-14 branches); two project-owned verifiers tools/verify/m032-p03-custom-nav-region.sh (20/20 PASS) and tools/verify/m032-p03-acceptance-shape-sc6.sh (8/8 PASS); self-application against orchestrator-local wiki/mkdocs.yml (legacy markers migrated to new shape,fresh auto-nav populated by splice via 27 milestones,idempotent on second run),FR-13 progressive-opt-in flag-pattern documentation in references/installation.md (default-off + independently composable + reversibility invariants + Constitution I rationale + --with-wiki/--with-giscus/--deploy named as canonical M032 prior art + future-flag forward-compatibility commitments for --with-github-integration and --with-design-layer); AD-7/CON-5 throwaway-fixture-protocol document at tests/m032-acceptance/throwaway-fixture-protocol.md (timestamp-prefix naming + gh repo create --private --add-readme creation contract + trap-EXIT teardown contract + four no-orphan-state invariants + recovery-on-partial-failure runbook + counter-pattern history of M013/M014 stub-only testing + MIT-001 SKIP_REASON branch); SC-5 acceptance script tests/m032-acceptance/p03-wiki-init-deploy-live.sh implementing the protocol with three-category exit semantics (0/77/non-zero per MIT-001) + gh auth status precondition + timestamped fixture creation + full --with-wiki --with-giscus --deploy invocation + live-URL curl retry loop bounded by M032_DEPLOY_PROPAGATION_TIMEOUT + served-HTML data-repo attribute assertion + MIT-008 audit-trail record assertion + trap-EXIT teardown + post-teardown no-orphan-state verification + git remote restore-on-cleanup; three project-owned verifiers tools/verify/m032-p03-with-feature-pattern-doc.sh (11/11 PASS) + tools/verify/m032-p03-throwaway-protocol-shape.sh (14/14 PASS) + tools/verify/m032-p03-acceptance-shape-sc5.sh (17/17 PASS),tools/verify/m032-p03-phase-suite.sh straight-line aggregator chaining all ten P03 sub-gates (FR-7 giscus-templating; FR-8 with-giscus-scope; FR-9 deploy-scope; FR-10 wiki-deploy-cwd-gate; FR-14 custom-nav-region; FR-13 with-feature-pattern-doc; AD-7 throwaway-protocol-shape; SC-4/SC-5/SC-6 acceptance-shape) per AD-19 single-script-file shape exits 0 iff every gate passes emits SUMMARY pass=N fail=M; tools/verify/m032-p03-scope-guard.sh SC-13 scope-guard with allowlist regex (P03-owned paths) plus denylist regex (P00/P01/P02-owned paths) plus first-run baseline-ref capture mirroring P01/P02 m032-p0?-baseline-ref.txt convention; tools/verify/fixtures/m032-p03-baseline-ref.txt baseline captured at HEAD a5f90e64 (T04 close commit) per the committed-history-only diff lesson from P01 patterns-established (verifier-contract-over-verifier-skeleton course-correction from payload-skeleton's git-status-porcelain working-tree approach which fails-noisy in dogfood loops with parallel M033 development)"
requires:
  - "P02"
affects:
  - "P04"
key_files:
  - "wiki/overrides/partials/comments.html,scripts/lifecycle/wiki-init.sh,tests/m032-acceptance/p02-wiki-init-with-giscus.sh,tools/verify/m032-p03-giscus-templating.sh,tools/verify/m032-p03-with-giscus-scope.sh,tools/verify/m032-p03-acceptance-shape-sc4.sh,tools/verify/m032-p02-wiki-init-default-scope.sh,scripts/wiki/wiki-deploy.sh,tools/verify/m032-p03-deploy-scope.sh,tools/verify/m032-p03-wiki-deploy-cwd-gate.sh,scripts/wiki/wiki-generate-nav.sh,wiki/mkdocs.yml,tests/m032-acceptance/p02-wiki-generate-nav-custom-region.sh,tools/verify/m032-p03-custom-nav-region.sh,tools/verify/m032-p03-acceptance-shape-sc6.sh,references/installation.md,tests/m032-acceptance/throwaway-fixture-protocol.md,tests/m032-acceptance/p03-wiki-init-deploy-live.sh,tools/verify/m032-p03-with-feature-pattern-doc.sh,tools/verify/m032-p03-throwaway-protocol-shape.sh,tools/verify/m032-p03-acceptance-shape-sc5.sh,tools/verify/m032-p03-phase-suite.sh,tools/verify/m032-p03-scope-guard.sh,tools/verify/fixtures/m032-p03-baseline-ref.txt"
key_decisions:
  - "FR-7,FR-8,SC-4,US-3-AS-3,AD-19,MEM001,MEM030,M026,FR-9,FR-10,MIT-007,MIT-008,Finding-J,CON-6,FR-14,MIT-005,US-5,Finding-I,SC-6,CON-3,FR-13,AD-7,CON-5,MIT-001,FR-21,MEM013,SC-5,SC-13"
patterns_established:
  - "dual-template interpolation surface; TOOL_HELPER_STUB test envelope extending M026 stub convention to opt-in failure-mode injection; grep -F -e for leading-dash text-grep tokens on BSD grep; compose-don't-replace EXIT traps; in-flight repair convention mirroring P01 precedent,four-step ordered remote-state mutation with read-before-write guard + structured JSONL audit-trail BEFORE side-effect-print (Constitution VI applied to remote-state mutations); per-step parallel-scalar mutation flags as bash 3.2 substitute for declare -A object arrays; literal-string JSON array concatenation via parameter-expansion-safe leading-comma elision pattern ${MUT:+$MUT,}; audit_failure helper defined ONCE near other helpers consumed by every failure path; gate-0 cwd-vs-canonical-source sanity gate as Finding J counter-pattern (validates invocation cwd matches mkdocs.yml repo_url before any remote mutation fires); test-only TOOL_HELPER_STUB and TOOL_HELPER_STUB_DIR pair (M026/MEM030 envelope) for hermetic verifier coverage of multi-branch state-machine without network; grep -F -e for leading-dash text-grep tokens on BSD grep (mirror of T01); in-flight repair convention extended to a P02-owned verifier whose check became structurally obsolete on T02 landing (reject-stub for deferred surface replaced by workflow assertion when the deferred surface lands),two-region marker split for regenerated files (auto-* regenerated wholly; custom-* preserved verbatim) with one-time legacy-migration branch; migration diagnostic mandatory on non-empty content + silent on empty content (silent migration is precisely the failure mode MIT-005 was authored to prevent); split-responsibility marker helpers (count_between_markers excludes blanks+comments to match operator nav-entry mental model; extract_between_markers preserves every byte including operator-authored comments to avoid lossy migration); AS-3 self-healing (regenerator re-creates deleted marker pair at standard slot so operator cannot accidentally remove the seam); manual-empty-then-regenerate self-application pattern (when migration target carries auto-generated content rather than operator-authored content,manually emptying legacy block before running generator avoids polluting new custom-nav region with stale auto-content); verifier-contract-over-verifier-skeleton (when plan-stated expectation 'empty legacy content' conflicts with on-disk reality of populated auto-generated legacy block,ship the contract by manually preparing the inputs the contract expects),three-category exit semantics for live-network acceptance (0=pass / 77=POSIX-skip per MIT-001 / non-zero=fail) — distinguishes test-environment-not-ready from test-failed and lets battery aggregators report pass=N skip=M fail=K rather than collapsing skip into pass; trap-EXIT cleanup pattern for live-network test scripts (cleanup() with set +e + 2>/dev/null + || true so trap firing on script failure-path never propagates a secondary failure that masks the primary one); explicit-cleanup-then-trap-disarm pattern (call cleanup() directly + trap - EXIT INT TERM before post-teardown invariant checks so the invariant-verification phase is hermetic from any second trap firing); progressive-opt-in --with-<feature> convention codified at references/installation.md as project-wide spec — three invariants (default-off + independently composable + reversibility) + future-flag commitments documented up front so M013/M014 fold-in ([M035](../../../../../milestones/M035/index.md) era) and M023 design-layer (post-launch) inherit the contract; verifier-shape repair for grep-with-leading-dash tokens (use grep -qF -- \$tok\ so tokens like --with-wiki/--private/--deploy match correctly + grep -qiF for case-insensitive concept-tokens like default-off/independently composable that the doc bolds as Title-Case); doc-comment reference inclusion (the SC-5 header carries explicit MIT-007 prose mention even though the MIT-007 read-before-write Pages guard executes inside wiki-deploy.sh — the header references it transitively to satisfy the verifier-shape contract that pins the load-bearing decision-id token surface); deferred-cleanup-recovery escape hatch documented in throwaway-fixture-protocol.md (when 'gh repo delete' silently fails inside trap due to delete_repo scope absence on the token,operator runs gh auth refresh -h github.com -s delete_repo + gh repo delete <owner>/<ts>-m032-fixture --yes manually),verifier-contract-over-verifier-skeleton applied to scope-guard diff source -- payload-skeleton specified git-status-porcelain (working-tree state) which produces 146-out-of-scope FAIL noise in the dogfood orchestrator repo where parallel M033 development modifies many unrelated paths in the working tree -- repaired in-flight to committed-history-only diff (git diff --name-only baseline_ref HEAD) per the P01 patterns-established lesson and the P02 m032-p02-scope-guard.sh precedent; first-run-captures-HEAD-as-baseline pattern with SHA-comment-format baseline-ref file (mirrors P02 m032-p02-baseline-ref.txt one-SHA-line-with-leading-comment-headers shape); regex-allowlist plus regex-denylist twin-check pattern (single-pass git diff iteration; each diff path checked against ALLOWED_RE for in-scope-membership and against DENIED_RE for SC-13 violation surface); thin-aggregator phase-suite chains existing verifiers without adding new logic (matches M030/M031/M032 P00-P02 phase-suite-aggregator pattern); FR/SC/AD tag-prefix in gate names preserved for grep-able diagnostics in failure cases; bash 3.2 compatibility maintained throughout (no declare -A no process substitution no compound chains)"
drill_down_paths:
  - "[.orchestrator/milestones/M032/phases/P03/tasks/T01-with-giscus-scope-SUMMARY.md](../../../../../milestones/M032/phases/P03/tasks/T01-with-giscus-scope-SUMMARY.md), [.orchestrator/milestones/M032/phases/P03/tasks/T02-deploy-scope-SUMMARY.md](../../../../../milestones/M032/phases/P03/tasks/T02-deploy-scope-SUMMARY.md), [.orchestrator/milestones/M032/phases/P03/tasks/T03-custom-nav-region-SUMMARY.md](../../../../../milestones/M032/phases/P03/tasks/T03-custom-nav-region-SUMMARY.md), [.orchestrator/milestones/M032/phases/P03/tasks/T04-throwaway-fixture-and-sc5-SUMMARY.md](../../../../../milestones/M032/phases/P03/tasks/T04-throwaway-fixture-and-sc5-SUMMARY.md), [.orchestrator/milestones/M032/phases/P03/tasks/T05-phase-suite-and-scope-guard-SUMMARY.md](../../../../../milestones/M032/phases/P03/tasks/T05-phase-suite-and-scope-guard-SUMMARY.md)"
duration: "695m"
verification_result: "pass"
completed_at: "2026-05-05T03:18:53Z"
observability_surfaces:
  - "none"
---

## P03 — Wiki Composition Layer (Giscus + Deploy + Custom Nav + FR-13 Doc + Phase Close)

P03 closes the M032 wiki composition layer. Five tasks shipped end-to-end, each verified and committed atomically; the phase-suite aggregator (10/10 PASS) and SC-13 scope-guard (4/4 PASS, 0 denylist hits) gate the phase close.

### What was built

- **T01 (FR-7 + FR-8 + SC-4)** — Giscus partial templating + `--with-giscus` scope on `wiki-init.sh`. Dual-template interpolation (mkdocs.yml extras block + `wiki/overrides/partials/comments.html`). `<TOOL>_<HELPER>_STUB=<1|fail>` failure-injection envelope established as the canonical P03+ shape.
- **T02 (FR-9 + FR-10 + MIT-007 + MIT-008)** — `--deploy` scope on `wiki-init.sh` (four-step ordered remote-state mutation: `gh api PATCH discussions=true` → `wiki-deploy.sh` → MIT-007 read-before-write Pages guard → `gh api PUT /pages`). FR-10 cwd-vs-`repo_url` gate-0 sanity check on `wiki-deploy.sh` (Finding J counter-pattern). Structured wiki-deploy-mutation JSONL audit-trail BEFORE side-effect-print (Constitution VI applied to remote-state mutations). `--force-pages-reconfigure` escape hatch. `M032_DEPLOY_GH_API_STUB[_DIR]` + `M032_WIKI_DEPLOY_BYPASS_CWD_GATE` test envelopes per M026/MEM030.
- **T03 (FR-14 + MIT-005 + SC-6)** — Region split on `scripts/wiki/wiki-generate-nav.sh`: `# >>> auto-nav` regenerated wholly; `# >>> custom-nav` preserved verbatim across regenerates; legacy `# >>> M012-P01 nav` markers recognized only for one-time migration. Four-branch migration dispatcher (US-5 AS-2 empty-legacy + MIT-005 non-empty-legacy + AS-3 self-healing). Self-application against orchestrator-local `wiki/mkdocs.yml` (legacy markers migrated, fresh auto-nav populated by splice via 27 milestones, idempotent on second run).
- **T04 (FR-13 + AD-7/CON-5 + SC-5)** — FR-13 progressive-opt-in `--with-<feature>` flag-pattern documentation appended to `references/installation.md` (default-off + independently composable + reversibility invariants + Constitution I rationale + `--with-wiki`/`--with-giscus`/`--deploy` named as canonical M032 prior art + future-flag commitments for `--with-github-integration` and `--with-design-layer`). AD-7/CON-5 throwaway-fixture-protocol document (`tests/m032-acceptance/throwaway-fixture-protocol.md`) with timestamp-prefix naming, `gh repo create --private --add-readme` creation contract, trap-EXIT teardown contract, four no-orphan-state invariants, and recovery-on-partial-failure runbook. SC-5 live-deploy acceptance with three-category exit semantics (0/77/non-zero per MIT-001).
- **T05 (phase-suite + SC-13 + baseline-ref)** — `tools/verify/m032-p03-phase-suite.sh` straight-line aggregator chaining all ten P03 sub-gates per AD-19 single-script-file shape (10/10 PASS). `tools/verify/m032-p03-scope-guard.sh` SC-13 scope-guard with regex-allowlist (P03-owned paths) + regex-denylist (P00/P01/P02-owned paths) + first-run baseline-ref capture mirroring P01/P02 convention. `tools/verify/fixtures/m032-p03-baseline-ref.txt` baseline at HEAD `a5f90e64` (T04 close commit) per the committed-history-only diff lesson from P01.

### Key decisions

FR-7, FR-8, FR-9, FR-10, FR-13, FR-14, FR-21, MIT-001, MIT-005, MIT-007, MIT-008, AD-7, AD-19, CON-3, CON-5, CON-6, US-3-AS-3, US-5, SC-4, SC-5, SC-6, SC-13, Finding-I, Finding-J, MEM001, MEM013, MEM030, M026.

### Patterns established

- **In-flight repair convention (extended)** — Verifier-contract drift caused by sibling-phase task landings repaired in the same task that surfaces it; cheaper than separate hardening tasks or phase-boundary catch-up. Applied to P01 verifiers (T03 in-flight repair to `m032-p02-glossary-scanner-and-nav.sh`) and P02 verifier check 11 (T02 in-flight repair). Established P03/T01, extended T02/T03/T05.
- **`<TOOL>_<HELPER>_STUB=<1|fail>` envelope** — canonical failure-injection seam per M026/MEM030, used by T01 (GISCUS) and T02 (`M032_DEPLOY_GH_API_STUB`).
- **Verifier-contract-over-verifier-skeleton** — When plan-stated expectation conflicts with on-disk reality (T03's "empty legacy content" vs ~2200-line auto-generated block; T05's `git status --porcelain` vs `git diff --name-only baseline_ref HEAD`), ship the contract by manually preparing inputs the contract expects or by adopting the surrounding-phase pattern that survives dogfood-loop noise.
- **Four-step ordered remote-state mutation with read-before-write guard + structured JSONL audit-trail BEFORE side-effect-print** — Constitution VI applied to remote-state mutations (T02).
- **Two-region marker split (auto-* regenerated wholly; custom-* preserved verbatim) + one-time legacy migration with mandatory diagnostic on non-empty content** — silent migration is precisely the failure mode MIT-005 was authored to prevent (T03).
- **Three-category exit semantics for live-network acceptance (0=pass / 77=POSIX-skip / non-zero=fail)** — distinguishes test-environment-not-ready from test-failed; lets battery aggregators report `pass=N skip=M fail=K` rather than collapsing skip into pass (T04).
- **Trap-EXIT cleanup pattern + explicit-cleanup-then-trap-disarm** — `cleanup()` with `set +e` + `2>/dev/null` + `|| true` so trap firing on script failure-path never propagates a secondary failure that masks the primary; explicit `cleanup() && trap - EXIT INT TERM` before post-teardown invariant checks so the invariant-verification phase is hermetic from any second trap firing (T04).
- **Progressive-opt-in `--with-<feature>` convention codified at `references/installation.md`** — three invariants (default-off + independently composable + reversibility) + future-flag commitments documented up front so M013/M014 fold-in (M035 era) and M023 design-layer (post-launch) inherit the contract (T04).
- **Deferred-cleanup-recovery escape hatch** — when `gh repo delete` silently fails inside trap due to `delete_repo` scope absence on the token, operator runs `gh auth refresh -h github.com -s delete_repo && gh repo delete <owner>/<ts>-m032-fixture --yes` manually (T04).
- **First-run-captures-HEAD-as-baseline + regex-allowlist + regex-denylist twin-check** — single-pass `git diff` iteration; each diff path checked against `ALLOWED_RE` for in-scope-membership and against `DENIED_RE` for SC-13 violation surface; thin-aggregator phase-suite chains existing verifiers without adding new logic, matching M030/M031/M032 P00-P02 phase-suite-aggregator pattern (T05).

### Verification results

- **Phase-suite aggregator** (`tools/verify/m032-p03-phase-suite.sh`): **10/10 PASS** (FR-7 + FR-8 + FR-9 + FR-10 + FR-14 + FR-13 + AD-7 + SC-4 + SC-5 + SC-6).
- **SC-13 scope-guard** (`tools/verify/m032-p03-scope-guard.sh`): **4/4 PASS**, `in_scope=4 denylist_hits=0` (T05 commits within P03 allowlist; no P00/P01/P02 denylist hits).
- **Baseline-ref captured** at HEAD `a5f90e64` (T04 close commit).
- **Sibling-phase regression check**: P02 phase-suite remains 12/12 PASS post-T03 in-flight repair to `m032-p02-glossary-scanner-and-nav.sh`. P01 phase-suite known-pre-existing failures (`m032-p01-install-cc-byte-identical.sh`, `m032-p01-installers-parity.sh`, `m032-p01-acceptance-shape-sc1.sh`) are NOT P03-caused — verified via stash compare in T03 dispatch.

### Operator follow-ups (out-of-scope, surfaced during P03)

- **Sibling-phase ship-shape gap**: `wiki-init.sh` rejects `--with-wiki` as unknown argument (T01/T02 implementation surface). Surfaced in T04 SC-5 live branch but does not block P03 close (T04's three required verifiers are green; T05's verifiers do not exercise the live `--with-wiki` flag path). Will need a P04 in-flight repair or carry-forward fix before SC-5's live branch can pass end-to-end against a real PBJ test environment.
- **Leaked GitHub fixture**: `bkellgren/1777950218-m032-fixture` created during T04 SC-5 dry-run; trap cleanup failed silently because the auth token lacks `delete_repo` scope. Operator action: `gh auth refresh -h github.com -s delete_repo && gh repo delete bkellgren/1777950218-m032-fixture --yes` (per the documented recovery runbook in `tests/m032-acceptance/throwaway-fixture-protocol.md`).

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P04"
milestone: "M032"
name: "M032 milestone close ceremony + P04 phase-suite + scope-guard"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

- T01–T04 have all landed at execution time. T05 reads each upstream
  task's verifier paths to compose the phase-suite chain and the
  scope-guard allowlist, AND consumes T04's battery for the SC-12
  verdict in M032-SUMMARY.md and M032-ACCEPTANCE-EVIDENCE.md.
  Verified by:
  - `[ -x tools/verify/m032-p04-scanner-extensions.sh ]` (T01)
  - `[ -x tools/verify/m032-p04-nav-extensions.sh ]` (T01)
  - `[ -x tools/verify/m032-p04-acceptance-shape-sc8.sh ]` (T01)
  - `[ -x tools/verify/m032-p04-decorator-shape.sh ]` (T02)
  - `[ -x tools/verify/m032-p04-acceptance-shape-sc9.sh ]` (T02)
  - `[ -x tools/verify/m032-p04-with-wiki-noop.sh ]` (T02)
  - `[ -x tools/verify/m032-p04-acceptance-shape-sc11.sh ]` (T03)
  - `[ -x tests/m032-acceptance/run-acceptance-battery.sh ]` (T04)
  - `[ -x tools/verify/m032-p04-acceptance-battery-shape.sh ]` (T04)
- `tools/verify/fixtures/` exists from P01/P02/P03 baseline-ref
  convention. Verified by `[ -d tools/verify/fixtures ]`.
- The previous P03 baseline-ref `tools/verify/fixtures/m032-p03-baseline-ref.txt`
  exists as the pattern T05 follows for `m032-p04-baseline-ref.txt`.
  Verified by `[ -f tools/verify/fixtures/m032-p03-baseline-ref.txt ]`.
- [M030](../../../../../milestones/M030/index.md) + M031 milestone-close artifacts exist as the pattern reference
  for M032's close ceremony:
  - `[ -f .orchestrator/milestones/M030/M030-VALIDATED ]`
  - `[ -f [.orchestrator/milestones/M030/M030-SUMMARY.md](../../../../../milestones/M030/M030-SUMMARY.md) ]`
  - `[ -f [.orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md](../../../../../milestones/M030/M030-ACCEPTANCE-EVIDENCE.md) ]`
  - `[ -f .orchestrator/milestones/M031/M031-VALIDATED ]`
  - `[ -f [.orchestrator/milestones/M031/M031-SUMMARY.md](../../../../../milestones/M031/M031-SUMMARY.md) ]`
  - `[ -f [.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md](../../../../../milestones/M031/M031-ACCEPTANCE-EVIDENCE.md) ]`

## Description

T05 is the M032 milestone-close ceremony plus the P04 verification-
aggregation surface. The deliverable surface has nine pieces:

1. **`M032-SUMMARY.md`** at [`.orchestrator/milestones/M032/M032-SUMMARY.md`](../../../../../milestones/M032/M032-SUMMARY.md)
   per the milestone-summary template (16-field frontmatter +
   narrative body) modeled on M030/M031.
2. **`M032-VALIDATED` marker file** at `.orchestrator/milestones/M032/M032-VALIDATED`,
   conditioned on the SC-12 outcome (skip=0 OR signed-attestation
   block in the summary).
3. **`unit_close` JSONL record** appended to `.orchestrator/milestones/M032/execution-log.jsonl`
   at milestone-grain.
4. **`M032-ACCEPTANCE-EVIDENCE.md`** at [`.orchestrator/milestones/M032/M032-ACCEPTANCE-EVIDENCE.md`](../../../../../milestones/M032/M032-ACCEPTANCE-EVIDENCE.md)
   per the M030/M031 evidence-ledger convention.
5. **`tools/verify/m032-p04-validate-milestone.sh`** invoking
   `scripts/verify/validate-milestone.sh .orchestrator/milestones/M032/`
   and asserting the final `VALIDATE: PASS` line.
6. **`tools/verify/m032-p04-milestone-close-ceremony.sh`** asserting
   the marker + summary + JSONL record presence.
7. **`tools/verify/m032-p04-acceptance-evidence-ledger.sh`** asserting
   the evidence ledger's shape.
8. **`tools/verify/m032-p04-phase-suite.sh`** chaining all eleven P04
   sub-gates per AD-19 single-script-file shape.
9. **`tools/verify/m032-p04-scope-guard.sh`** + **`tools/verify/fixtures/m032-p04-baseline-ref.txt`**
   asserting P04's diff confined to the declared "Files Likely Touched"
   list with first-run baseline-ref capture per the M032 P01/P02/P03
   baseline-ref convention.

## Steps

1. **Run the live acceptance battery** to capture the verdict that
   M032-SUMMARY.md + M032-ACCEPTANCE-EVIDENCE.md transcribe:

   ```bash
   bash tests/m032-acceptance/run-acceptance-battery.sh > /tmp/m032-battery.out 2>&1
   ```

   Expected output: final line `BATTERY: pass=10 skip=1 fail=0`
   (SC-5 unauthenticated CI) OR `BATTERY: pass=11 skip=0 fail=0`
   (SC-5 authenticated). Capture the output for transcription into
   M032-ACCEPTANCE-EVIDENCE.md.

   If `fail > 0`, T05 STOPS and surfaces the failure for in-flight
   repair per the P03 patterns-established convention. The
   milestone-close ceremony cannot proceed with `fail > 0`.

   If `skip == 1` (SC-5 unauthenticated), T05 either (a) re-runs SC-5
   in an authenticated environment to drive `skip == 0`, OR (b)
   includes the signed-attestation block in M032-SUMMARY.md per the
   MIT-001 + SC-14 contract. The attestation block shape is documented
   in step 3 below.

2. **Run `validate-milestone.sh` to capture the framework-side verdict**:

   ```bash
   bash scripts/verify/validate-milestone.sh .orchestrator/milestones/M032/ > /tmp/m032-validate.out 2>&1
   ```

   Expected output: `VALIDATE: PASS — NNN/NNN checks passed` with NNN
   matching the framework-side check count (phase-summary existence +
   boundary-map produces presence + cross-phase consumes-met-by-produces).

3. **Author [`.orchestrator/milestones/M032/M032-SUMMARY.md`](../../../../../milestones/M032/M032-SUMMARY.md)** per the
   milestone-summary template (mirror M030 / M031 byte-for-byte where
   structurally possible). Required frontmatter shape:

   ```yaml
   ---
   schema_version: "1.0"
   type: milestone-summary
   id: "M032"
   parent: "035-wiki-distribution-init-integration"
   milestone: "M032"
   provides:
     - "<comma-separated bullet of every load-bearing surface across P01..P04>"
   requires:
     - "M025 (installer coexistence — pinned-sha gate); M031 (Quick/Standard/Full profile contract); M020 (knowledge-kind taxonomy); M030 (milestone-close discipline precedent); commands/conversus-gate.md (manual gate per A-5); M035 P00 (--mode=symlink runtime cache, fallback to local cache per A-1)"
   affects:
     - "M033 (project onboarding — paired-launch via FR-11 --with-wiki gate); M036b (post-launch wiki projection — P08 blocked by M032 closure); post-launch wiki-UX-deep + external-tool-adapters (FR-20 decorator polish surface); future --with-github-integration / --with-design-layer (FR-13 flag pattern); run-doctor.sh (FR-22 collision invariant ongoing consumer)"
   key_files:
     - "<comma-separated key-file enumeration aggregating P01..P04 key_files>"
   key_decisions:
     - "<comma-separated decision list: FR-1..FR-22, MIT-001..MIT-011, AD-5, AD-7, AD-19, CON-1..CON-6, US-1..US-8, SC-1..SC-14, Finding-A..Finding-K, MEM001, MEM012, MEM013, MEM030>"
   patterns_established:
     - "<comma-separated patterns aggregating P01..P04 patterns_established — managed project-asset distribution; sequential-atomicity dispatch; reader-only knowledge-adapter boundary; paired-milestone seam-script convention; throwaway-fixture protocol with three-category exit semantics; verifier-contract-over-verifier-skeleton course-correction; in-flight repair convention; four-step ordered remote-state mutation with audit trail; two-region marker split (auto/custom); progressive-opt-in --with-<feature> convention; first-run-captures-HEAD-as-baseline + regex-allowlist + regex-denylist twin-check>"
   drill_down_paths:
     - "[.orchestrator/milestones/M032/phases/P01/P01-SUMMARY.md](../../../../../milestones/M032/phases/P01/P01-SUMMARY.md), [.orchestrator/milestones/M032/phases/P02/P02-SUMMARY.md](../../../../../milestones/M032/phases/P02/P02-SUMMARY.md), [.orchestrator/milestones/M032/phases/P03/P03-SUMMARY.md](../../../../../milestones/M032/phases/P03/P03-SUMMARY.md), [.orchestrator/milestones/M032/phases/P04/P04-SUMMARY.md](../../../../../milestones/M032/phases/P04/P04-SUMMARY.md), [.orchestrator/milestones/M032/M032-ACCEPTANCE-EVIDENCE.md](../../../../../milestones/M032/M032-ACCEPTANCE-EVIDENCE.md)"
   duration: "<sum-of-P01..P04 durations in minutes>"
   verification_result: "pass"
   completed_at: "<ISO8601Z>"
   observability_surfaces:
     - "wiki-deploy-mutation NDJSON record on .orchestrator/execution-log.jsonl per MIT-008 (Constitution VI applied to remote-state mutations); .orchestrator/installed-files.txt per-asset mode tracking (FR-4 surface for downstream uninstall + collision-invariant inspection); BATTERY: pass=N skip=M fail=K three-category aggregator output (MIT-001); proposals: + extra: + knowledge-flat scanner record families with frontmatter stage badge derivation (FR-17/18/19 surface for wiki nav rendering)"
   ---
   ```

   The body sections (mirror M031-SUMMARY.md structure):

   - **Lead paragraph** — one paragraph: "M032 (wiki distribution +
     init integration) closes the orchestrator's distribution-surface
     gap by..." with the M032 elevator pitch.
   - **Phase rollup** — bullet per phase (P01..P04) with what shipped
     + verification verdict.
   - **Cross-phase inheritance** — patterns repeated verbatim across
     phases; effectively M032-stable utilities.
   - **Verification at close** — `BATTERY: pass=N skip=M fail=K` line
     verbatim from step 1; `validate-milestone.sh` verdict from step 2;
     per-phase phase-suite + scope-guard verdicts.
   - **Forward-pointing notes** — what's deferred to M033, post-launch
     fast-follows, etc.
   - **Signed-attestation block** (CONDITIONAL — only if `skip == 1`
     in step 1's battery output) — see template below.

   **Signed-attestation block template** (per MIT-001 + SC-14 — required
   only when battery closed at skip=1):

   ```markdown
   ## SC-5 Live-Fixture Signed Attestation (per MIT-001 + SC-14)

   The acceptance battery closed at `BATTERY: pass=10 skip=1 fail=0`
   in this run. SC-5 (`p03-wiki-init-deploy-live.sh`) emitted exit 77
   with SKIP_REASON because `gh auth status` was not authenticated in
   the close-ceremony environment. Per MIT-001 + SC-14, the
   `M032-VALIDATED` marker creation is conditioned on SC-12 `skip=0`
   OR this signed-attestation block.

   **Attestation**: SC-5 was independently executed in an authenticated
   environment on <ISO8601Z> against the throwaway GitHub fixture
   `<owner>/<ts>-m032-fixture` (created via `gh repo create
   <ts>-m032-fixture --private --add-readme`, deleted via `gh repo
   delete <ts>-m032-fixture --yes` per the AD-7 throwaway-fixture
   protocol) and produced exit 0 (pass). Operator: <signer-name>.
   Fixture cleanup verified post-teardown (no orphan branches in this
   repo, no leaked `<owner>/<ts>-m032-fixture` references in
   `.git/refs/`, no leaked `.orchestrator/` files in the consumer
   fixture).
   ```

   The attestation block carries the MIT-001 invariant verbatim — without
   it the M032-VALIDATED marker MUST NOT be created at skip=1.

4. **Create the marker file**: `touch .orchestrator/milestones/M032/M032-VALIDATED`.
   The file is empty; its presence is the marker per the M030/M031
   convention. Conditional creation gate: per the SC-14 contract, the
   marker MUST NOT be created if SC-12 closed at `skip=1` AND the
   M032-SUMMARY.md does not contain the signed-attestation block. The
   verifier `m032-p04-milestone-close-ceremony.sh` enforces this gate.

5. **Append the milestone-grain `unit_close` record** to
   `.orchestrator/milestones/M032/execution-log.jsonl`:

   ```bash
   _ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
   printf '{"event_type":"unit_close","unit":"M032","timestamp":"%s","verification_result":"pass"}\n' "$_ts" \
     >> .orchestrator/milestones/M032/execution-log.jsonl
   ```

   The record is single-line NDJSON. Append-only; do not modify
   prior records.

6. **Author [`.orchestrator/milestones/M032/M032-ACCEPTANCE-EVIDENCE.md`](../../../../../milestones/M032/M032-ACCEPTANCE-EVIDENCE.md)**
   per the M030/M031 evidence-ledger convention. Read
   [`.orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md`](../../../../../milestones/M030/M030-ACCEPTANCE-EVIDENCE.md) and
   [`.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md`](../../../../../milestones/M031/M031-ACCEPTANCE-EVIDENCE.md) as
   structural templates and produce a byte-for-byte format-mirror
   where structurally possible. Required content:

   - **Header** with milestone ID, ISO-8601 close timestamp, back-link
     to `tests/m032-acceptance/run-acceptance-battery.sh`.
   - **BATTERY line transcription** verbatim from step 1's output.
   - **Per-SC roll-up table** (one row per SC-1..SC-13) with columns
     [SC, verifier path, verdict (pass/skip/fail), last-run timestamp,
     notes (e.g. SKIP_REASON for SC-5 if applicable)].
   - **`validate-milestone.sh` transcription** — the `VALIDATE: PASS
     — NNN/NNN checks passed` line verbatim from step 2's output.
   - **SC-13 NNN derivation** — references the table in P04-PLAN.md
     `## SC-13 NNN Derivation` section (the per-script assertion-group
     count list summing to NNN). Cross-reference for audit trace.
   - **Phase-suite + scope-guard verdicts** — one row per phase
     (P01..P04) with the suite/guard verdict numbers.

7. **Author `tools/verify/m032-p04-validate-milestone.sh`**:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m032-p04-validate-milestone.sh
   # M032/P04/T05 — asserts validate-milestone.sh M032 reports PASS
   # for every entry per MIT-004 + SC-13.
   set -u
   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   cd "$REPO_ROOT"
   pass=0; fail=0
   say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
   say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

   _out="/tmp/m032-p04-validate-$$.out"
   bash scripts/verify/validate-milestone.sh .orchestrator/milestones/M032/ > "$_out" 2>&1
   _rc=$?
   if [ "$_rc" -eq 0 ] && grep -q '^VALIDATE: PASS' "$_out"; then
     say_pass "validate-milestone.sh M032 final line: $(grep '^VALIDATE: PASS' "$_out" | tail -1)"
   else
     say_fail "validate-milestone.sh M032 rc=$_rc; tail=$(tail -3 "$_out" | tr '\n' ' ')"
   fi
   rm -f "$_out"
   printf 'SUMMARY: m032-p04-validate-milestone.sh pass=%d fail=%d\n' "$pass" "$fail"
   [ "$fail" -eq 0 ]
   ```

8. **Author `tools/verify/m032-p04-milestone-close-ceremony.sh`**:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m032-p04-milestone-close-ceremony.sh
   # M032/P04/T05 — asserts milestone close ceremony artifacts present:
   # M032-VALIDATED marker, M032-SUMMARY.md, milestone-grain unit_close
   # record in execution-log.jsonl. Conditioned on SC-12 outcome per
   # MIT-001 + SC-14.
   set -u
   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   cd "$REPO_ROOT"
   MILE_DIR=".orchestrator/milestones/M032"
   pass=0; fail=0
   say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
   say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

   # Marker file
   if [ -f "$MILE_DIR/M032-VALIDATED" ]; then
     say_pass "M032-VALIDATED marker present at $MILE_DIR/M032-VALIDATED"
   else
     say_fail "M032-VALIDATED marker missing at $MILE_DIR/M032-VALIDATED"
   fi

   # Summary file
   if [ -f "$MILE_DIR/M032-SUMMARY.md" ]; then
     # Spot-check shape: schema_version, type: milestone-summary, id: M032
     if grep -q 'schema_version' "$MILE_DIR/M032-SUMMARY.md" \
        && grep -q 'type: milestone-summary' "$MILE_DIR/M032-SUMMARY.md" \
        && grep -q 'id: "M032"' "$MILE_DIR/M032-SUMMARY.md"; then
       say_pass "M032-SUMMARY.md present with required frontmatter shape"
     else
       say_fail "M032-SUMMARY.md present but frontmatter shape incomplete"
     fi
     # Conditional: if signed-attestation block is required, assert it.
     # Detect skip=1 by reading the BATTERY transcription in the summary body.
     if grep -qE 'BATTERY:.*skip=1' "$MILE_DIR/M032-SUMMARY.md"; then
       if grep -q 'SC-5 Live-Fixture Signed Attestation' "$MILE_DIR/M032-SUMMARY.md"; then
         say_pass 'Signed-attestation block present (skip=1 conditional)'
       else
         say_fail 'Skip=1 verdict but signed-attestation block missing — MIT-001 violation'
       fi
     else
       say_pass 'Skip=0 — signed-attestation block not required'
     fi
   else
     say_fail "M032-SUMMARY.md missing at $MILE_DIR/M032-SUMMARY.md"
   fi

   # unit_close JSONL record
   _logfile="$MILE_DIR/execution-log.jsonl"
   if [ -f "$_logfile" ]; then
     _count=$(grep -cF '"event_type":"unit_close"' "$_logfile" || true)
     _m032_count=$(grep -cF '"unit":"M032"' "$_logfile" || true)
     if [ "$_count" -ge 1 ] && [ "$_m032_count" -ge 1 ]; then
       say_pass "unit_close milestone-grain record present in $_logfile"
     else
       say_fail "unit_close M032 record missing or count $_count/$_m032_count"
     fi
   else
     say_fail "execution-log.jsonl missing at $_logfile"
   fi

   printf 'SUMMARY: m032-p04-milestone-close-ceremony.sh pass=%d fail=%d\n' "$pass" "$fail"
   [ "$fail" -eq 0 ]
   ```

9. **Author `tools/verify/m032-p04-acceptance-evidence-ledger.sh`**:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m032-p04-acceptance-evidence-ledger.sh
   # M032/P04/T05 — asserts M032-ACCEPTANCE-EVIDENCE.md present and
   # transcribes BATTERY + per-SC roll-up + back-link to runner per
   # the M030/M031 evidence-ledger convention.
   set -u
   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   cd "$REPO_ROOT"
   LEDGER="[.orchestrator/milestones/M032/M032-ACCEPTANCE-EVIDENCE.md](../../../../../milestones/M032/M032-ACCEPTANCE-EVIDENCE.md)"
   pass=0; fail=0
   say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
   say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

   if [ ! -f "$LEDGER" ]; then
     say_fail "evidence ledger missing at $LEDGER"
     printf 'SUMMARY: m032-p04-acceptance-evidence-ledger.sh pass=%d fail=%d\n' "$pass" "$fail"
     exit 1
   fi
   say_pass "ledger file present"

   # Required content tokens:
   for _tok in 'BATTERY:' 'SC-1' 'SC-11' 'SC-13' 'run-acceptance-battery.sh' 'VALIDATE:'; do
     if grep -qF "$_tok" "$LEDGER"; then
       say_pass "ledger contains '$_tok'"
     else
       say_fail "ledger missing '$_tok'"
     fi
   done

   printf 'SUMMARY: m032-p04-acceptance-evidence-ledger.sh pass=%d fail=%d\n' "$pass" "$fail"
   [ "$fail" -eq 0 ]
   ```

10. **Author `tools/verify/m032-p04-phase-suite.sh`** chaining all
    eleven P04 sub-gates. Mirror P03/T05's `m032-p03-phase-suite.sh`
    skeleton verbatim — the only differences are the `m032-p04-`
    prefix and the eleven gate names:

    Gates (in order):
    - `FR-17/18/19 scanner-extensions` → `m032-p04-scanner-extensions.sh`
    - `FR-17/18/19 nav-extensions` → `m032-p04-nav-extensions.sh`
    - `FR-20 decorator-shape` → `m032-p04-decorator-shape.sh`
    - `--with-wiki noop` → `m032-p04-with-wiki-noop.sh`
    - `SC-8 acceptance-shape` → `m032-p04-acceptance-shape-sc8.sh`
    - `SC-9 acceptance-shape` → `m032-p04-acceptance-shape-sc9.sh`
    - `SC-11 acceptance-shape` → `m032-p04-acceptance-shape-sc11.sh`
    - `SC-12 battery-shape` → `m032-p04-acceptance-battery-shape.sh`
    - `SC-13 validate-milestone` → `m032-p04-validate-milestone.sh`
    - `SC-14 close-ceremony` → `m032-p04-milestone-close-ceremony.sh`
    - `evidence-ledger` → `m032-p04-acceptance-evidence-ledger.sh`

    Single-script-file shape per AD-19; emits final line `SUMMARY:
    m032-p04-phase-suite.sh pass=N fail=M`; exits 0 iff every sub-
    gate passes.

11. **Author `tools/verify/m032-p04-scope-guard.sh`** mirroring
    P03/T05's `m032-p03-scope-guard.sh` skeleton verbatim. The
    differences are:

    **P04 allowlist** (every path P04 may touch):
    ```
    scripts/wiki/wiki-scan-sources.sh
    scripts/wiki/wiki-generate-nav.sh
    scripts/wiki/wiki-generate-stubs.sh
    scripts/wiki/wiki-decorate-codes.sh
    scripts/lifecycle/wiki-init.sh
    tests/m032-acceptance/p0X-scanner-extensions.sh
    tests/m032-acceptance/p0X-code-decorator.sh
    tests/m032-acceptance/sc11-doctor-no-warnings.sh
    tests/m032-acceptance/run-acceptance-battery.sh
    .orchestrator/milestones/M032/M032-VALIDATED
    [.orchestrator/milestones/M032/M032-SUMMARY.md](../../../../../milestones/M032/M032-SUMMARY.md)
    [.orchestrator/milestones/M032/M032-ACCEPTANCE-EVIDENCE.md](../../../../../milestones/M032/M032-ACCEPTANCE-EVIDENCE.md)
    .orchestrator/milestones/M032/execution-log.jsonl
    [.orchestrator/milestones/M032/phases/P04/P04-PLAN.md](../../../../../milestones/M032/phases/P04/P04-PLAN.md)
    .orchestrator/milestones/M032/phases/P04/P04-PLANNING-PAYLOAD.md
    [.orchestrator/milestones/M032/phases/P04/P04-SUMMARY.md](../../../../../milestones/M032/phases/P04/P04-SUMMARY.md)
    [.orchestrator/milestones/M032/phases/P04/tasks/T01-scanner-extensions-PLAN.md](../../../../../milestones/M032/phases/P04/tasks/T01-scanner-extensions-PLAN.md)
    [.orchestrator/milestones/M032/phases/P04/tasks/T01-scanner-extensions-PAYLOAD.md](../../../../../milestones/M032/phases/P04/tasks/T01-scanner-extensions-PAYLOAD.md)
    [.orchestrator/milestones/M032/phases/P04/tasks/T01-scanner-extensions-SUMMARY.md](../../../../../milestones/M032/phases/P04/tasks/T01-scanner-extensions-SUMMARY.md)
    [.orchestrator/milestones/M032/phases/P04/tasks/T02-decorator-and-with-wiki-noop-PLAN.md](../../../../../milestones/M032/phases/P04/tasks/T02-decorator-and-with-wiki-noop-PLAN.md)
    [.orchestrator/milestones/M032/phases/P04/tasks/T02-decorator-and-with-wiki-noop-PAYLOAD.md](../../../../../milestones/M032/phases/P04/tasks/T02-decorator-and-with-wiki-noop-PAYLOAD.md)
    [.orchestrator/milestones/M032/phases/P04/tasks/T02-decorator-and-with-wiki-noop-SUMMARY.md](../../../../../milestones/M032/phases/P04/tasks/T02-decorator-and-with-wiki-noop-SUMMARY.md)
    [.orchestrator/milestones/M032/phases/P04/tasks/T03-sc11-doctor-and-self-application-PLAN.md](../../../../../milestones/M032/phases/P04/tasks/T03-sc11-doctor-and-self-application-PLAN.md)
    [.orchestrator/milestones/M032/phases/P04/tasks/T03-sc11-doctor-and-self-application-PAYLOAD.md](../../../../../milestones/M032/phases/P04/tasks/T03-sc11-doctor-and-self-application-PAYLOAD.md)
    .orchestrator/milestones/M032/phases/P04/tasks/T03-sc11-doctor-and-self-application-SUMMARY.md
    [.orchestrator/milestones/M032/phases/P04/tasks/T04-acceptance-battery-PLAN.md](../../../../../milestones/M032/phases/P04/tasks/T04-acceptance-battery-PLAN.md)
    [.orchestrator/milestones/M032/phases/P04/tasks/T04-acceptance-battery-PAYLOAD.md](../../../../../milestones/M032/phases/P04/tasks/T04-acceptance-battery-PAYLOAD.md)
    .orchestrator/milestones/M032/phases/P04/tasks/T04-acceptance-battery-SUMMARY.md
    [.orchestrator/milestones/M032/phases/P04/tasks/T05-milestone-close-and-phase-suite-PLAN.md](../../../../../milestones/M032/phases/P04/tasks/T05-milestone-close-and-phase-suite-PLAN.md)
    [.orchestrator/milestones/M032/phases/P04/tasks/T05-milestone-close-and-phase-suite-PAYLOAD.md](../../../../../milestones/M032/phases/P04/tasks/T05-milestone-close-and-phase-suite-PAYLOAD.md)
    .orchestrator/milestones/M032/phases/P04/tasks/T05-milestone-close-and-phase-suite-SUMMARY.md
    tools/verify/m032-p04-scanner-extensions.sh
    tools/verify/m032-p04-nav-extensions.sh
    tools/verify/m032-p04-decorator-shape.sh
    tools/verify/m032-p04-with-wiki-noop.sh
    tools/verify/m032-p04-acceptance-shape-sc8.sh
    tools/verify/m032-p04-acceptance-shape-sc9.sh
    tools/verify/m032-p04-acceptance-shape-sc11.sh
    tools/verify/m032-p04-acceptance-battery-shape.sh
    tools/verify/m032-p04-validate-milestone.sh
    tools/verify/m032-p04-milestone-close-ceremony.sh
    tools/verify/m032-p04-acceptance-evidence-ledger.sh
    tools/verify/m032-p04-phase-suite.sh
    tools/verify/m032-p04-scope-guard.sh
    tools/verify/fixtures/m032-p04-baseline-ref.txt
    ```

    **P04 denylist** (paths P00/P01/P02/P03 own — P04 MUST NOT touch):
    ```
    packaging/install/install-claude-code.sh
    packaging/install/install-codex.sh
    packaging/install/install-cursor.sh
    packaging/bundle/manifest.yml
    commands/init.md
    scripts/lifecycle/init-project.sh
    wiki/glossary.md
    wiki/mkdocs.yml
    scripts/knowledge/lookup-mems.sh
    scripts/wiki/wiki-deploy.sh
    wiki/overrides/partials/comments.html
    references/installation.md
    tests/m032-acceptance/throwaway-fixture-protocol.md
    tests/paired-m032-m033/seam-A.sh
    tests/paired-m032-m033/seam-B.sh
    tests/paired-m032-m033/seam-C.sh
    ```

    **Single sibling-phase exception** (allowlisted in P04):
    `scripts/lifecycle/wiki-init.sh` — P04/T02 amends this file with
    the `--with-wiki) shift ;;` no-op case arm per the in-flight
    repair convention.

    Baseline-ref capture at `tools/verify/fixtures/m032-p04-baseline-ref.txt`
    per the P01/P02/P03 first-run-captures-HEAD convention.

12. **Make all new scripts executable**:
    ```
    chmod +x tools/verify/m032-p04-validate-milestone.sh
    chmod +x tools/verify/m032-p04-milestone-close-ceremony.sh
    chmod +x tools/verify/m032-p04-acceptance-evidence-ledger.sh
    chmod +x tools/verify/m032-p04-phase-suite.sh
    chmod +x tools/verify/m032-p04-scope-guard.sh
    ```

13. **Capture the baseline-ref**. On first execution, the scope-guard's
    first-run-captures-baseline branch writes `tools/verify/fixtures/m032-p04-baseline-ref.txt`:
    ```
    bash tools/verify/m032-p04-scope-guard.sh
    ```

14. **Run the full P04 phase-suite once at task close**:
    ```
    bash tools/verify/m032-p04-phase-suite.sh
    ```
    Expected output: `SUMMARY: m032-p04-phase-suite.sh pass=11 fail=0`,
    exit 0.

15. **Run sibling-phase regression check** (final pass):
    - `bash tools/verify/m032-p01-phase-suite.sh` (or whichever P01
      phase-suite name shipped — see Notes on P01 known-pre-existing
      failures)
    - `bash tools/verify/m032-p02-phase-suite.sh`
    - `bash tools/verify/m032-p03-phase-suite.sh`

    All three should remain green at their close-time numbers (or
    document any pre-existing failures per the P03/T05 stash-compare
    pattern).

## Must-Haves

- [`.orchestrator/milestones/M032/M032-SUMMARY.md`](../../../../../milestones/M032/M032-SUMMARY.md) exists with the 16-field milestone-summary frontmatter and references SC-1..SC-13 verdicts in the body (with signed-attestation block when SC-12 closed at skip=1)
- `.orchestrator/milestones/M032/M032-VALIDATED` marker file exists, conditioned on SC-12 skip=0 OR signed-attestation block per MIT-001 + SC-14
- `.orchestrator/milestones/M032/execution-log.jsonl` contains one milestone-grain `unit_close` record `{event_type: 'unit_close', unit: 'M032', timestamp: '<ISO8601Z>', verification_result: 'pass'}`
- [`.orchestrator/milestones/M032/M032-ACCEPTANCE-EVIDENCE.md`](../../../../../milestones/M032/M032-ACCEPTANCE-EVIDENCE.md) exists per the M030/M031 evidence-ledger convention (BATTERY transcription + per-SC roll-up + validate-milestone transcription + back-link to runner)
- `tools/verify/m032-p04-validate-milestone.sh` asserts validate-milestone.sh M032 reports VALIDATE: PASS
- `tools/verify/m032-p04-milestone-close-ceremony.sh` asserts marker + summary + JSONL record presence with conditional attestation gate
- `tools/verify/m032-p04-acceptance-evidence-ledger.sh` asserts ledger shape + token surface
- `tools/verify/m032-p04-phase-suite.sh` chains all eleven P04 sub-gates per AD-19 single-script-file shape and emits `SUMMARY: m032-p04-phase-suite.sh pass=11 fail=0`
- `tools/verify/m032-p04-scope-guard.sh` enforces SC-13 scope discipline against P04 allowlist + P00/P01/P02/P03 denylist with first-run baseline-ref capture
- `tools/verify/fixtures/m032-p04-baseline-ref.txt` captured per the P01/P02/P03 baseline-ref convention
- T05 modifies ZERO T01–T04 deliverables — purely additive (only consumes them)

## Verification

```bash
bash tools/verify/m032-p04-validate-milestone.sh
```

```bash
bash tools/verify/m032-p04-milestone-close-ceremony.sh
```

```bash
bash tools/verify/m032-p04-acceptance-evidence-ledger.sh
```

```bash
bash tools/verify/m032-p04-phase-suite.sh
```

```bash
bash tools/verify/m032-p04-scope-guard.sh
```

```bash
bash tests/m032-acceptance/run-acceptance-battery.sh
```

## Notes

Expected output:
- `m032-p04-phase-suite.sh` final line: `SUMMARY: m032-p04-phase-suite.sh pass=11 fail=0`, exit 0.
- `m032-p04-scope-guard.sh` final lines (two-line per the P02/P03 precedent): `PASS: m032-p04 scope-guard pass=N fail=0 in_scope=M denylist_hits=0` followed by `SUMMARY: m032-p04-scope-guard.sh pass=N fail=0`, exit 0.
- `run-acceptance-battery.sh` final line: `BATTERY: pass=10 skip=1 fail=0` (SC-5 unauthenticated) OR `BATTERY: pass=11 skip=0 fail=0` (authenticated).

Verifier-contract-over-verifier-skeleton latitude (mirrored from P03/T05):
the phase-suite aggregator is intentionally thin — chains existing
verifiers, no new verification logic. The scope-guard's allowlist
intentionally includes the planning-state files (`P04-PLAN.md`,
`P04-PLANNING-PAYLOAD.md`, `P04-SUMMARY.md`, the per-task `T##-*-PAYLOAD.md`
/ `-SUMMARY.md`) and the milestone execution-log because P04 work
flows through those paths during dispatch. The denylist includes
ONLY the P00/P01/P02/P03-owned paths; future-phase paths are NOT
denylisted (none exist; if a P04 task accidentally created one, the
allowlist check would still flag it as out-of-scope).

P01 known-pre-existing failures (per P03-SUMMARY.md operator
follow-ups): `m032-p01-install-cc-byte-identical.sh`,
`m032-p01-installers-parity.sh`, `m032-p01-acceptance-shape-sc1.sh`
have been failing since pre-P03 close and are NOT P04-caused. T05's
sibling-phase regression check should distinguish "pre-existing red"
from "P04-introduced red" via stash-compare per the P03/T05 pattern.
If P04 introduces any new P01 regression, repair in-flight per the
P03 patterns-established convention.

The leaked GitHub fixture follow-up from P03/T04 SC-5 dry-run
(`bkellgren/1777950218-m032-fixture`) is a separate operator action
(documented recovery runbook in `tests/m032-acceptance/throwaway-fixture-protocol.md`)
and does NOT block T05 close. T05 may note this in M032-SUMMARY.md's
forward-pointing notes section as deferred-cleanup-pending.

Bash 3.2 gotchas: `grep -c` under `set -uo pipefail` requires `|| true`
fallback per the P02/T03 patterns-established gotcha (used in steps 8
and 9). `printf` with `%s` for the unit_close JSONL record handles
ISO-8601 timestamps with `:` characters cleanly (no quoting issues).

Conversus-gate / shape-classifier note: the P03/T05 scope-guard hit the
working-tree noise issue (146 out-of-scope FAILs from parallel M033
development). T05 here adopts the same `git diff --name-only baseline_ref
HEAD` committed-history-only pattern from the P03/T05 patterns-established
to avoid that failure mode. The first-run-captures-HEAD baseline-ref
is the load-bearing convention.

The SC-13 NNN derivation table in P04-PLAN.md (`## SC-13 NNN
Derivation` section) is the audit-trace for the M032-SUMMARY.md SC-13
verdict and the M032-ACCEPTANCE-EVIDENCE.md per-SC roll-up. T05 does
NOT modify the table — the planner authored it; T05 references it.

## Inputs

### From Previous Tasks

- All eleven P04 verifier scripts (T01: 3; T02: 3; T03: 1; T04: 1; T05:
  the remaining 5 it authors plus the phase-suite + scope-guard).
- `tests/m032-acceptance/run-acceptance-battery.sh` (T04) — invoked at
  step 1 to capture the BATTERY verdict for transcription.

Each upstream verifier's contract: exit 0 on pass with final line
`SUMMARY: <name> pass=N fail=0`; exit 77 on skip (battery only); other-
non-zero on fail. The phase-suite aggregator does NOT parse the SUMMARY
line — it only consumes the exit code (`bash <gate>` and check `$?`).

### From Disk (Pre-existing)

- `scripts/verify/validate-milestone.sh` — framework-owned validator
  invoked by `m032-p04-validate-milestone.sh`. Contract: emits
  `VALIDATE: <verdict> — N/M checks passed` final line; exit 0 on PASS.
- `tests/m030-acceptance/run-acceptance-battery.sh` — pattern reference
  for runner shape (M030 lineage).
- `tests/m031-acceptance/run-acceptance-battery.sh` — pattern reference
  (M031 lineage; closest precedent).
- [`.orchestrator/milestones/M030/M030-SUMMARY.md`](../../../../../milestones/M030/M030-SUMMARY.md) — pattern reference
  for milestone-summary structure (M030 byte-for-byte template).
- [`.orchestrator/milestones/M031/M031-SUMMARY.md`](../../../../../milestones/M031/M031-SUMMARY.md) — pattern reference
  (M031 lineage; closest precedent).
- [`.orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md`](../../../../../milestones/M030/M030-ACCEPTANCE-EVIDENCE.md) — pattern
  reference for evidence-ledger structure.
- [`.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md`](../../../../../milestones/M031/M031-ACCEPTANCE-EVIDENCE.md) — pattern
  reference (M031 lineage; closest precedent).
- `tools/verify/m032-p03-phase-suite.sh` — skeleton reference for the
  P04 phase-suite aggregator shape.
- `tools/verify/m032-p03-scope-guard.sh` — skeleton reference for the
  P04 scope-guard shape with allowlist + denylist + baseline-ref
  capture.
- `tools/verify/fixtures/m032-p03-baseline-ref.txt` — file-shape
  reference for the `m032-p04-baseline-ref.txt` capture.
- All P04 task PLAN.md / PAYLOAD.md / SUMMARY.md files (in-progress
  during T05 execution; the scope-guard's allowlist enumerates them
  even before they exist).

## Constraints

- Single-script-file shape for verifier `Check:` commands per AD-19.
- bash 3.2 compatibility (per MEM001).
- Verifier scripts under `tools/verify/m032-p04-*` (slug-bearing per
  AD-19).
- T05 modifies ZERO T01–T04 deliverables — purely additive.
- The `tools/verify/fixtures/m032-p04-baseline-ref.txt` path is INSIDE
  the P04 allowlist (the scope-guard captures its own baseline as part
  of its diff per the P03/T05 precedent).
- The phase-suite's gate-naming preserves the FR-/SC-/AD-/MIT-/CON-
  tag prefixes for grep-able diagnostics in failure cases.
- Milestone-close ceremony artifacts (M032-VALIDATED, M032-SUMMARY.md,
  unit_close JSONL, M032-ACCEPTANCE-EVIDENCE.md) MUST mirror M030/M031
  byte-for-byte where structurally possible per AD-2 milestone-close
  discipline.
- The signed-attestation block in M032-SUMMARY.md is conditional on
  SC-12 outcome — present iff `BATTERY: ... skip=1 ...` per MIT-001 +
  SC-14. The `m032-p04-milestone-close-ceremony.sh` verifier enforces
  this gate.
- T05 may NOT bypass the SC-12 + SC-14 gate. If `BATTERY: ... fail>0`
  occurs, T05 STOPS and surfaces the failure for in-flight repair
  per the P03 patterns-established convention. The milestone-close
  ceremony cannot proceed with `fail > 0`.

## Expected Output

After T05 completes:

- [`.orchestrator/milestones/M032/M032-SUMMARY.md`](../../../../../milestones/M032/M032-SUMMARY.md) (50+ lines, 16-field
  frontmatter, body with phase rollup + verification verdict + signed-
  attestation block when applicable).
- `.orchestrator/milestones/M032/M032-VALIDATED` marker file (empty;
  presence is the marker).
- `.orchestrator/milestones/M032/execution-log.jsonl` carries one
  milestone-grain `unit_close` record at the tail.
- [`.orchestrator/milestones/M032/M032-ACCEPTANCE-EVIDENCE.md`](../../../../../milestones/M032/M032-ACCEPTANCE-EVIDENCE.md) (30+
  lines, BATTERY transcription + per-SC roll-up + back-link to
  runner).
- Five new verifier scripts under `tools/verify/m032-p04-*`
  (validate-milestone, milestone-close-ceremony, acceptance-evidence-
  ledger, phase-suite, scope-guard).
- `tools/verify/fixtures/m032-p04-baseline-ref.txt` captured.
- `bash tools/verify/m032-p04-phase-suite.sh` exits 0 with `pass=11
  fail=0`.
- `bash tools/verify/m032-p04-scope-guard.sh` exits 0 with `pass=N
  fail=0 denylist_hits=0`.
- `bash tests/m032-acceptance/run-acceptance-battery.sh` exits 0 with
  `BATTERY: pass=N skip=M fail=0`.
- `bash scripts/verify/validate-milestone.sh
  .orchestrator/milestones/M032/` exits 0 with `VALIDATE: PASS`.
- M032 milestone is closed.

## State Context

- **Current State**: executing
- **Milestone**: M032
- **Phase**: P04
- **Task**: T05-milestone-close-and-phase-suite
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- Single-script-file shape for verifier `Check:` commands per AD-19.
- bash 3.2 compatibility (per MEM001).
- Verifier scripts under `tools/verify/m032-p04-*` (slug-bearing per
  AD-19).
- T05 modifies ZERO T01–T04 deliverables — purely additive.
- The `tools/verify/fixtures/m032-p04-baseline-ref.txt` path is INSIDE
  the P04 allowlist (the scope-guard captures its own baseline as part
  of its diff per the P03/T05 precedent).
- The phase-suite's gate-naming preserves the FR-/SC-/AD-/MIT-/CON-
  tag prefixes for grep-able diagnostics in failure cases.
- Milestone-close ceremony artifacts (M032-VALIDATED, M032-SUMMARY.md,
  unit_close JSONL, M032-ACCEPTANCE-EVIDENCE.md) MUST mirror M030/M031
  byte-for-byte where structurally possible per AD-2 milestone-close
  discipline.
- The signed-attestation block in M032-SUMMARY.md is conditional on
  SC-12 outcome — present iff `BATTERY: ... skip=1 ...` per MIT-001 +
  SC-14. The `m032-p04-milestone-close-ceremony.sh` verifier enforces
  this gate.
- T05 may NOT bypass the SC-12 + SC-14 gate. If `BATTERY: ... fail>0`
  occurs, T05 STOPS and surfaces the failure for in-flight repair
  per the P03 patterns-established convention. The milestone-close
  ceremony cannot proceed with `fail > 0`.

### Acceptance Criteria

- [`.orchestrator/milestones/M032/M032-SUMMARY.md`](../../../../../milestones/M032/M032-SUMMARY.md) exists with the 16-field milestone-summary frontmatter and references SC-1..SC-13 verdicts in the body (with signed-attestation block when SC-12 closed at skip=1)
- `.orchestrator/milestones/M032/M032-VALIDATED` marker file exists, conditioned on SC-12 skip=0 OR signed-attestation block per MIT-001 + SC-14
- `.orchestrator/milestones/M032/execution-log.jsonl` contains one milestone-grain `unit_close` record `{event_type: 'unit_close', unit: 'M032', timestamp: '<ISO8601Z>', verification_result: 'pass'}`
- [`.orchestrator/milestones/M032/M032-ACCEPTANCE-EVIDENCE.md`](../../../../../milestones/M032/M032-ACCEPTANCE-EVIDENCE.md) exists per the M030/M031 evidence-ledger convention (BATTERY transcription + per-SC roll-up + validate-milestone transcription + back-link to runner)
- `tools/verify/m032-p04-validate-milestone.sh` asserts validate-milestone.sh M032 reports VALIDATE: PASS
- `tools/verify/m032-p04-milestone-close-ceremony.sh` asserts marker + summary + JSONL record presence with conditional attestation gate
- `tools/verify/m032-p04-acceptance-evidence-ledger.sh` asserts ledger shape + token surface
- `tools/verify/m032-p04-phase-suite.sh` chains all eleven P04 sub-gates per AD-19 single-script-file shape and emits `SUMMARY: m032-p04-phase-suite.sh pass=11 fail=0`
- `tools/verify/m032-p04-scope-guard.sh` enforces SC-13 scope discipline against P04 allowlist + P00/P01/P02/P03 denylist with first-run baseline-ref capture
- `tools/verify/fixtures/m032-p04-baseline-ref.txt` captured per the P01/P02/P03 baseline-ref convention
- T05 modifies ZERO T01–T04 deliverables — purely additive (only consumes them)

### Files To Touch

- `scripts/wiki/wiki-scan-sources.sh` (modify — additive FR-17/18/19 enumerations)
- `scripts/wiki/wiki-generate-nav.sh` (modify — additive Proposals + extra-dirs + Knowledge-Flat nav sections inside auto-nav region)
- `scripts/wiki/wiki-decorate-codes.sh` (create — FR-20 build-time decorator stub)
- `scripts/lifecycle/wiki-init.sh` (modify — in-flight repair: accept `--with-wiki` as no-op for FR-11 passthrough symmetry)
- `tests/m032-acceptance/p0X-scanner-extensions.sh` (create — SC-8)
- `tests/m032-acceptance/p0X-code-decorator.sh` (create — SC-9)
- `tests/m032-acceptance/sc11-doctor-no-warnings.sh` (create — SC-11)
- `tests/m032-acceptance/run-acceptance-battery.sh` (create — SC-12 three-category aggregator)
- `.orchestrator/milestones/M032/M032-VALIDATED` (create — SC-14 marker file)
- [`.orchestrator/milestones/M032/M032-SUMMARY.md`](../../../../../milestones/M032/M032-SUMMARY.md) (create — SC-14 milestone summary)
- [`.orchestrator/milestones/M032/M032-ACCEPTANCE-EVIDENCE.md`](../../../../../milestones/M032/M032-ACCEPTANCE-EVIDENCE.md) (create — M030/M031 evidence-ledger convention)
- `.orchestrator/milestones/M032/execution-log.jsonl` (modify — append milestone-grain `unit_close` record)
- `tools/verify/m032-p04-scanner-extensions.sh` (create)
- `tools/verify/m032-p04-nav-extensions.sh` (create)
- `tools/verify/m032-p04-decorator-shape.sh` (create)
- `tools/verify/m032-p04-with-wiki-noop.sh` (create)
- `tools/verify/m032-p04-acceptance-shape-sc8.sh` (create)
- `tools/verify/m032-p04-acceptance-shape-sc9.sh` (create)
- `tools/verify/m032-p04-acceptance-shape-sc11.sh` (create)
- `tools/verify/m032-p04-acceptance-battery-shape.sh` (create)
- `tools/verify/m032-p04-validate-milestone.sh` (create)
- `tools/verify/m032-p04-milestone-close-ceremony.sh` (create)
- `tools/verify/m032-p04-acceptance-evidence-ledger.sh` (create)
- `tools/verify/m032-p04-phase-suite.sh` (create)
- `tools/verify/m032-p04-scope-guard.sh` (create)
- `tools/verify/fixtures/m032-p04-baseline-ref.txt` (create — captured by T05 per the P01/P02/P03 baseline-ref convention)

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