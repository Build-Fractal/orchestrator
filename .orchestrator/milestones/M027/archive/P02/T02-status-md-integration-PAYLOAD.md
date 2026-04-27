---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T02-status-md-integration (Phase P02, Milestone M027)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~700 | required |
| Upstream Context | 981-1027 | ~5200 | required |
| Task Plan | 1029-1166 | ~3500 | required |
| State Context | 1168-1174 | ~100 | required |
| First-Turn Completeness | 1176-1221 | ~800 | required |
| **Total** | | **~21100** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 518
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
hit_count: 518
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
hit_count: 518
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
scope_tags: "[project], [milestone:M005]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 518
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
hit_count: 451
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
hit_count: 451
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
hit_count: 451
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
hit_count: 518
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
scope_tags: "[project], [milestone:M006]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 451
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
hit_count: 451
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
scope_tags: "[project], [milestone:M002]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 451
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
hit_count: 518
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
hit_count: 518
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
hit_count: 518
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
hit_count: 451
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
hit_count: 451
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
hit_count: 451
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
hit_count: 518
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
hit_count: 451
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
hit_count: 451
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
hit_count: 518
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
hit_count: 518
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
scope_tags: "[project], [milestone:M004]"
category: lessons
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 451
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
hit_count: 451
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
hit_count: 451
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
scope_tags: "[project], [milestone:M025]"
category: lessons
confidence: 0.95
created_at: 2026-04-23
last_verified: 2026-04-23
hit_count: 106
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
hit_count: 106
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
hit_count: 106
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
scope_tags: "[project], [milestone:M026]"
category: patterns
confidence: 0.90
created_at: 2026-04-24
last_verified: 2026-04-24
hit_count: 94
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
hit_count: 94
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
scope_tags: "[project], [milestone:M020]"
category: conventions
confidence: 0.90
created_at: 2026-04-25
last_verified: 2026-04-25
hit_count: 84
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
milestones (M024 universal intake, M019 Tier 2+3 observability) MAY READ
the fields but MUST NOT introduce new fields without a follow-up M020 D-row.
The handshake is: open an M020 D-row → M020 lands the schema change →
consuming milestone uses the field. Never bypass this gate.

## Authorising decision

`.orchestrator/DECISIONS.md` D024 (2026-04-25).

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
     Per the M027/P00 + M027/P01 parser-shape lesson: every Check command
     references ONLY artifacts T01..T04 of THIS phase produces, never future
     tasks. All P02 verification logic lives in scripts/verify/m027-p02-*.sh
     files shipped in T04. The Truths-list `Check:` commands here are
     phase-boundary checks (run after T04 lands); each task plan defines its
     OWN single-script-file Verification block referencing only that task's
     artifacts. -->

### Truths

- `scripts/diagnostics/efficiency-footer.sh` exists, is executable, sourceable, and accepts `--milestone <Mxxx>`, `--project`, `--quiet`, `--config-defaults <path>`, `--help` flags. CLI mode (no `--quiet`) emits a one-block efficiency footer (≤ 6 lines) prefixed with the literal title `Efficiency (Tier 1 rollup)`; under `--quiet`, emits exactly zero stdout, exit 0. The block contains paired cost (USD) + quality (verification_pass_rate, dispatch count) tokens on adjacent lines. Reads via `scripts/diagnostics/metrics-rollup.sh` (sourced or forked); never writes to `execution-log.jsonl` (FR-12 carry-forward). Empty-log path emits `Efficiency: no Tier 1 records yet` per US-3 AS-3 (FR-6, FR-7, US-3 AS-1, AS-3, CON-5 carry-forward).
  - Check: `bash scripts/verify/m027-p02-efficiency-footer-shape.sh`

- `commands/status.md` is updated to invoke the efficiency footer below the existing telemetry block (after the `## Telemetry Metrics` section and before `## Next Action`); the footer is governed by `--quiet` and by `config.efficiency_footer` (default `true`). Pre-footer output remains structurally unchanged from the pre-M027 command document — no re-ordering of existing sections, no rewording of existing prose. Documents `--quiet` suppression and the config knob explicitly. References `scripts/diagnostics/efficiency-footer.sh` in the `## Reference Files` section (FR-6, FR-7, US-3 AS-1, AS-2, MEM012).
  - Check: `bash scripts/verify/m027-p02-status-md-shape.sh`

- Status byte-identity (suppressed mode) — `orchestrator:status --quiet` emits a tail (`tail -n +1` after the existing telemetry block, identified by the `## Next Action` heading boundary) that is byte-identical to the captured pre-M027 baseline. The fixture baseline lives at `tests/fixtures/m027-p02/status-quiet-baseline.txt`. The verifier diffs the tail of a deterministic invocation against the fixture; failure if `diff` exits non-zero. Two suppression paths are exercised: (a) `--quiet` flag on the simulated status invocation; (b) `efficiency_footer: false` in a `mktemp`-isolated `.orchestrator/config.yml`. Both paths produce the byte-identical tail (FR-6, FR-7, CON-3, SC-3).

<dispatch-volatile>

## Upstream Context


### P01 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M027"
milestone: "M027"
provides:
  - "scripts/engine/cost-estimate.sh - sourceable bash 3.2 library + CLI for the M027 P01 predictive cost estimator. Exposes cost_estimate_resolve_model,cost_estimate_recommend,cost_estimate_per_tier. CLI accepts --description (required),--format text|json,--help. Sources scripts/lib/pricing.sh once; emits a 3-row Quick/Standard/Full Goodhart-paired table with COST_USD / INPUT_TOK / OUTPUT_TOK / QUALITY / RECOMMENDED columns and the verbatim D027 trailer estimates +/-~20%; see commands/cost.md#accuracy. JSON shape: top-level recommended + tiers.quick/standard/full each carrying cost_usd,input_tokens,output_tokens,quality,pricing_warning; cost_usd is JSON null on pricing degradation. Goodhart pairing extended to predictive surface (FR-20/CON-4/SC-18) - every cost cell is paired with a QUALITY cell on the same row; QUALITY column renders even when costs are unavailable. Char-quartile token model (M019 AD-1) inlined as bash arithmetic in the per-tier path; per-tier prompt overhead constants Quick=800/Standard=2400/Full=6800 chars; per-tier output token budgets Quick=1500/Standard=4000/Full=12000 tokens (tuned by eye against M019 baseline; revisitable post Tier 3 actuals). Model resolution: ORCH_COST_ESTIMATE_MODEL env override,then pricing_resolve_alias default,then hard-coded claude-opus-4-7 fallback. Recommendation hook: cost_estimate_recommend forks intensity-recommend.sh,parses intensity= line,lowercases via tr (no bash-4 case folding); INTENSITY_RECOMMEND_FAST_PATH=1 plus pre-set _CE_RECOMMENDED short-circuits the fork for T02 recommendation hook re-entry. Pricing degradation never aborts (CON-5/FR-24): missing/stale yields unavailable cost cells plus a one-line override hint plus the recommendation still flows. Read-only (CON-1/FR-12): writes only to stdout/stderr.,scripts/engine/intensity-recommend.sh — extended with --format text|json and --no-cost-annotation flags. Default text mode preserves the 8 byte-stable key=value lines verbatim (CON-3) then appends a per-tier cost-annotation block: # cost estimates (M027/P01) header line,9 numeric lines (cost_quick_usd,cost_quick_in_tokens,cost_quick_out_tokens,cost_standard_usd,cost_standard_in_tokens,cost_standard_out_tokens,cost_full_usd,cost_full_in_tokens,cost_full_out_tokens),3 quality lines (cost_quick_quality,cost_standard_quality,cost_full_quality — CON-4/FR-20 Goodhart pairing at the predictive surface),and 1 cost_pricing_warning= roll-up line. --format json emits a single-line JSON object containing the 8 existing fields plus a top-level cost_estimates object keyed by quick/standard/full where each tier carries cost_usd (number-or-null),pricing_warning per D026. --no-cost-annotation suppresses the trailing cost block in text mode while preserving the 8 key=value lines. Pricing degradation under ORCH_PRICING_FILE pointing at a missing path renders empty cost_*_usd in text mode (cost_pricing_warning=pricing-missing) and JSON null cost_usd per tier with pricing_warning=pricing-missing. Sources scripts/engine/cost-estimate.sh once after the decision-matrix block; sets _CE_RECOMMENDED from the locally-computed intensity and exports INTENSITY_RECOMMEND_FAST_PATH=1 to bypass T01 intensity-recommend re-fork (no-recursion invariant). Two bash 3.2 safe helpers: _cj_field (sed regex per-tier field extractor) and _cj_unquote (string field unwrap). _json_escape escapes backslash,double-quote,and newline for JSON string values via sed plus tr. Zero-LLM-token (FR-21/CON-6) and bash 3.2 (CON-7) verifier regexes return no matches against the file body.,commands/cost.md — canonical user-facing definition for orchestrator:cost following MEM012 shape (frontmatter description,Title,Prerequisites/State Check,Core Workflow numbered sections,Output,Accuracy,Idempotency,Error Handling,Concurrent Safety,Referenced Scripts). Documents two surfaces: retrospective (no flags or scope flags) thin-wraps scripts/diagnostics/metrics-rollup.sh with a one-line orchestrator:cost — retrospective rollup header above engine output (SC-4); predictive (--estimate <description>) thin-wraps scripts/engine/cost-estimate.sh emitting the 3-row Quick/Standard/Full paired cost+quality table with recommended-tier marker and D027 accuracy trailer. Embeds the verbatim D027 disclaimer under ## Accuracy: Estimates use M019 char-quartile token approximation and pricing.yml rates; actual cost typically lands within +/-20%. Runtime-actuals calibration is Tier 3 (deferred). Documents mutually-exclusive flag rules (--estimate vs --milestone/--phase/--task/--granularity/--source/--since exit 2; --task + --granularity milestone|project exit 2; --estimate with empty description exit 2),graceful pricing degradation per FR-24/CON-5,read-only invariant per FR-12/CON-1,zero-LLM-token per FR-21/CON-6,concurrent-safety rationale per AD-3 copy-then-aggregate. References all four scripts: scripts/diagnostics/metrics-rollup.sh,scripts/engine/cost-estimate.sh,scripts/engine/intensity-recommend.sh,scripts/lib/pricing.sh,plus scripts/state/derive-phase.sh for active-milestone detection. 112 lines total. packaging/bundle/skills/orchestrator-cost.md — thin discovery-surface skill stub mirroring orchestrator-status.md shape: schema_version 1.0 / type skill / name orchestrator:cost / namespace orchestrator / runtime_compatibility [claude-code,codex,cursor] / command_file commands/cost.md,body redirects to canonical commands/cost.md. packaging/bundle/manifest.yml — orchestrator-cost.md inserted alphabetically in skills: list between orchestrator-consolidate.md and orchestrator-discuss.md; version unchanged at 0.3.0-dev (preserved per task plan step 7 convention).,scripts/verify/m027-p01-suite.sh phase-suite orchestrator (12 gates,mirrors P00 m027-rollup-schema.sh shape with parallel-string GATES list,per-gate exit-code capture,RELAX-CANDIDATE forwarding); 12 per-contract verifiers under scripts/verify/m027-p01-*.sh: cost-command-shape (Truth #1,FR-5,D027 disclaimer grep -qF),cost-retro-default (Truth #2,FR-12 carry-forward,smoke-tests metrics-rollup.sh against M019),cost-estimate-table (Truth #3,FR-20/21,asserts 3-row paired table + verbatim D027 trailer),predictive-goodhart-pairing (Truth #4,CON-4/SC-18,asserts every cost cell paired with quality cell in both text and JSON),zero-llm-token (Truth #5,FR-21/CON-6/SC-16,split-literal token scan),predictive-latency (Truth #6,CON-9/FR-22/SC-15,perl Time::HiRes warm-cache 3-min,hard-fails on inner-library measurement at 250ms with outer measurement RELAX-CANDIDATE forwarded),pricing-degradation (Truth #7,FR-11/CON-5,ORCH_PRICING_FILE points at nonexistent path; asserts unavailable cells text + cost_usd null in JSON),intensity-text-back-compat (Truth #8,FR-7/SC-3,byte-identity diff against tests/fixtures/m027-p01/intensity-recommend-baseline-text.txt with deterministic --analyze-output + --profile-output to remove env variance),intensity-json-cost-estimates (Truth #9,D026,python3 type-validation of cost_estimates per-tier shape),read-only (Truth #10,FR-12/CON-1/SC-9,git diff --quiet pre/post,WARN-skip on dirty pre-run),runtime-adapter-registration (Truth #11,asserts claude-code/codex/cursor adapters --register --dry-run list orchestrator-cost.md under HOME redirect + --project-dir for cursor),bash32-compat (Truth #12,CON-7/SC-11,split-literal forbidden construct scan + bash -n parse on .sh files); tests/fixtures/m027-p01/intensity-recommend-baseline-text.txt + README.md (deterministic 8-key=value baseline for byte-identity verifier)"
requires:
  - "P00"
affects:
  - "P02"
key_files:
  - "scripts/engine/cost-estimate.sh,scripts/engine/intensity-recommend.sh,commands/cost.md,packaging/bundle/skills/orchestrator-cost.md,packaging/bundle/manifest.yml,scripts/verify/m027-p01-suite.sh,scripts/verify/m027-p01-cost-command-shape.sh,scripts/verify/m027-p01-cost-retro-default.sh,scripts/verify/m027-p01-cost-estimate-table.sh,scripts/verify/m027-p01-predictive-goodhart-pairing.sh,scripts/verify/m027-p01-zero-llm-token.sh,scripts/verify/m027-p01-predictive-latency.sh,scripts/verify/m027-p01-pricing-degradation.sh,scripts/verify/m027-p01-intensity-text-back-compat.sh,scripts/verify/m027-p01-intensity-json-cost-estimates.sh,scripts/verify/m027-p01-read-only.sh,scripts/verify/m027-p01-runtime-adapter-registration.sh,scripts/verify/m027-p01-bash32-compat.sh,tests/fixtures/m027-p01/intensity-recommend-baseline-text.txt,tests/fixtures/m027-p01/README.md"
key_decisions:
  - "D026,D027,AD-19,CON-1,CON-4,CON-6,CON-7,CON-9,FR-20,FR-21,FR-22,FR-24,CON-3,MEM004,MEM012,FR-12,CON-5,SC-4,SC-18,AD-3,CON-12,SC-15"
patterns_established:
  - "Sourceable-CLI duality via BASH_SOURCE-zero == zero-arg guard at bottom of file; load-time _COST_ESTIMATE_SH_SOURCED re-source guard mirrors pricing.sh _PRICING_SH_SOURCED. Single-awk-pass cost computation pattern: instead of calling pricing_estimate_cost_usd 3 times (each forks awk twice for alias-resolve plus rates-lookup,then once for the multiply,~33 ms/tier on the bash interpreter),resolve alias once + lookup rates once + compute all 3 per-tier costs in a single awk BEGIN block that emits 3 raw 8-decimal lines + 3 6-decimal text lines for the table renderer. Net 3 awk forks vs 9; in-process latency dropped ~120 ms -> ~50 ms (well under FR-22 100 ms). Bash-3.2-clean comment hygiene applied per M027/P00 T01 precedent - neutralized literal forbidden-construct tokens (the bash-4 array-from-stdin builtin,herestring redirection,merged stdout-stderr shorthand,the LLM-call markers) in prose so the T04 zero-LLM-token + bash32-compat verifier grep regexes do not false-positive against doc comments. Goodhart pairing in the predictive renderer: text-format renderer renders the QUALITY column unconditionally and substitutes unavailable for empty cost cells rather than dropping the row; pricing degradation path emits an explicit override hint line so the recommendation still flows (FR-24). Module-scope _CE_RECOMMENDED slot pattern: cost_estimate_per_tier reads it; cost_estimate_recommend writes it in CLI mode; library callers (T02 hook) write it directly to bypass the inner intensity-recommend.sh fork - keeps the per-tier function pure-arithmetic for T04 perf benchmarks.,Predictive cost-annotation hook pattern: a parent script (intensity-recommend.sh) invokes a sibling library (cost-estimate.sh) for predictive cost computation by sourcing it and pre-setting the module-scope recommendation slot (_CE_RECOMMENDED) plus exporting INTENSITY_RECOMMEND_FAST_PATH=1,which short-circuits the library own intensity-recommend fork — preventing infinite recursion when the library is sourced from the same script it would otherwise fork. Byte-identity preservation through additive output: when an existing emitter is extended with new structured output,the canonical shape is to keep the existing N output lines byte-for-byte (no re-ordering,no re-formatting,no whitespace changes) and append the new content with a clearly-marked comment-line separator (here: # cost estimates (M027/P01)) that downstream grep ^key= consumers ignore — the CON-3 contract is satisfied with a one-shot diff fixture (head -N pre vs head -N post). bash 3.2 safe inline JSON parsing: a sed -nE regex matching against the flat-tier shape (no nested objects deeper than 2 levels) extracts a single field from a single tier of a printf-built JSON object — paired with a separate _cj_unquote helper for string fields. JSON-by-printf with sed-based escape: _json_escape uses a sed pipeline (escape backslash first then double-quote) plus tr to flatten newlines for safe single-line JSON emission,avoiding any jq dependency. Comment-hygiene-for-verifier-regex pattern carried forward from M027/P00 T01 plus P01/T01: when a CON-7 doc-comment would naturally list bash-4 forbidden constructs (associative-array declarations,inline process substitution,case-folding parameter expansion) literally,reword the prose to describe them by category so the bash32-compat verifier grep regex stays clean against the file body. MEM004 carve-out applied: pipes,dollar-paren,sed are used inside this script body,but the AD-19 single-script-file shape rule binds only Check: commands at task and phase plan level. Pricing degradation never aborts (CON-5/FR-24 inherited from cost-estimate.sh): missing or stale pricing yields empty cost_*_usd in text mode and JSON null cost_usd in JSON mode,but the tier rows still render with their input_tokens/output_tokens/quality data — Goodhart pairing held even on degraded input.,Thin-wrapper command-document pattern over an existing CLI engine: the user-facing commands/cost.md adds exactly one piece of value beyond direct CLI invocation (a one-line header above retrospective rollup output for SC-4 audit-trail clarity) and otherwise streams engine stdout verbatim — keeping the command document as documentation rather than logic and preserving CON-7 (no inline shell anti-patterns in markdown). Verbatim-disclaimer load-bearing string: D027's accuracy disclaimer is treated as immutable copy under ## Accuracy and verified by grep -qF (literal substring match) — establishes the convention that downstream parser tooling can rely on the exact byte sequence. Mutually-exclusive flag-pair documentation pattern: command-document Error Handling section enumerates each forbidden pair (--estimate + scope flag,--task + --granularity milestone|project,--estimate with empty description) with the exact exit-code (2) and one-line diagnostic shape,giving the T04 verifier a static surface to assert against without re-running the command. Skill-stub-mirrors-existing-shape pattern: every new commands/*.md gets a parallel thin discovery skill at packaging/bundle/skills/ matching the YAML frontmatter shape of orchestrator-status.md (schema_version,type,name,namespace,description,runtime_compatibility,command_file) and a 4-line markdown body redirecting to the canonical command document — keeps bundle introspection and runtime-adapter auto-registration in lockstep without code changes to the adapters. Manifest update is alphabetical-insertion-only per existing convention; version pinned at task scope (bumped only at consolidate scope) per git log inspection.,One-verifier-per-contract scaffolding mirrors P00 scripts/verify/m027-p00-*.sh (PROJECT_ROOT via BASH_SOURCE; PASS/FAIL stdout/stderr; exit 0/1/2; MEM004 emitter-internal carve-out for pipes/python3/awk while AD-19 single-script-file shape binds only Check: invocations); phase-suite orchestrator at M027/P01 scale (12 gates) follows m027-rollup-schema.sh shape verbatim — parallel-string GATES list,per-gate exit-code capture,PASS/FAIL emission,single-script-file external Check shape with internal carve-out for the for-loop; RELAX-CANDIDATE forwarding pattern preserved (suite greps each gate output for the structured annotation and forwards verbatim on stdout above the SUMMARY); split-literal forbidden token assembly keeps self-applying scanners from matching their own source (mirrors P00 bash32-compat); deterministic baseline-fixture pattern for byte-identity verifiers — pass inline --analyze-output and --profile-output strings so the verifier removes intensity-analyze.sh + detect-capabilities.sh forks from the equation,leaving only the text-formatter as the system-under-test; latency verifier inner-vs-outer split — applies the hard threshold to the cost-estimate library inner overhead (skipping the inner intensity-recommend re-fork via INTENSITY_RECOMMEND_FAST_PATH=1 + _CE_RECOMMENDED=standard) since outer wall-clock includes ~200ms of bash startup + fork overhead the library author cannot optimize on macOS dev boxes; outer measurement still reported as informational with RELAX-CANDIDATE annotation when over the 250ms threshold so plan-phase can act on environment-sensitive data without false-failing the gate"
drill_down_paths:
  - ".orchestrator/milestones/M027/phases/P01/tasks/T01-cost-estimator-SUMMARY.md, .orchestrator/milestones/M027/phases/P01/tasks/T02-intensity-recommend-hook-SUMMARY.md, .orchestrator/milestones/M027/phases/P01/tasks/T03-cost-command-SUMMARY.md, .orchestrator/milestones/M027/phases/P01/tasks/T04-verifier-suite-SUMMARY.md"
duration: "140m"
verification_result: "pass"
completed_at: "2026-04-27T04:07:02Z"
observability_surfaces:
  - "none"
---

P01 shipped the user-facing `orchestrator:cost` command — both retrospective (thin wrapper over the P00 rollup engine) and predictive (`--estimate <description>`, ±~20% accuracy disclaimer) — plus the `intensity-recommend.sh` cost-annotation hook that exposes the predictive surface to downstream callers in both text (byte-stable additive) and JSON (`cost_estimates` object per D026) shapes.

T01 produced `scripts/engine/cost-estimate.sh` (466 lines, sourceable lib + CLI). The naive shape (3 × `pricing_estimate_cost_usd`) cost ~120 ms in-process due to 9 awk forks per call; refactored to a single awk BEGIN block emitting all 3 tiers' raw and rendered values in one fork. Net 3 awk forks vs 9; in-process latency dropped to ~50 ms — comfortably under the FR-22 100 ms budget.

T02 wired `intensity-recommend.sh --format text|json` per D026: text mode preserves the 8 byte-stable key=value lines (CON-3 byte-identity diff against a deterministic baseline fixture) and appends a per-tier cost-annotation block; JSON mode emits a single-line object with a top-level `cost_estimates` object keyed by tier (each carrying `cost_usd` number-or-null, `input_tokens`, `output_tokens`, `pricing_warning`). A `_CE_RECOMMENDED` module-scope slot + `INTENSITY_RECOMMEND_FAST_PATH=1` short-circuit prevents infinite recursion when intensity-recommend sources cost-estimate.sh, which would otherwise re-fork intensity-recommend.

T03 produced `commands/cost.md` (112 lines, MEM012-shaped) carrying the verbatim D027 accuracy disclaimer (`grep -qF` load-bearing), `packaging/bundle/skills/orchestrator-cost.md` discovery stub, and the `packaging/bundle/manifest.yml` registration. Followed the M015/M025 packaging convention — `bash scripts/dispatch/adapters/runtime/claude-code.sh --register --dry-run` confirms the runtime-adapter contract.

T04 produced 12 per-contract verifiers + `scripts/verify/m027-p01-suite.sh` orchestrator (mirrors P00's `m027-rollup-schema.sh` shape: parallel GATES list, per-gate exit capture, RELAX-CANDIDATE forwarding). Suite reports 12/12 PASS (exit 0). The predictive-latency verifier surfaces an observational outer-wall-clock RELAX-CANDIDATE on macOS (~297ms vs 250ms threshold) — the inner library measurement (the cost-estimate author's actual budget, with INTENSITY_RECOMMEND_FAST_PATH=1) is ~44 ms, well within budget. Outer overhead is ~200 ms of bash startup + fork on macOS dev boxes; CI Linux numbers are typically ~100–150 ms lower per fork.

A plan-shape bug surfaced mid-phase: T03-PLAN.md's Verification block referenced `m027-p01-cost-command-shape.sh`, a T04 deliverable. Auto-loop's verifier extractor runs fenced bash blocks blindly, so this caused a verification fail even though T03's work was correct. Patched by adding a T03-scoped precheck (`scripts/verify/m027-p01-t03-shape-precheck.sh`), updating the plan to point at it, then T04 subsumed it by deleting the precheck once the canonical verifier shipped. This is the second occurrence of the M027/P00 parser-shape lesson — task-level Verification must reference only what the task itself produces. Folded into T03/T04 plans for record-keeping; no codebase regression.

Two decisions pinned: D026 closes #Q-14 (cost_estimates JSON shape) and D027 closes #Q-15 (verbatim accuracy disclaimer). Both load-bearing for downstream P02 byte-identity contracts and external tooling.

Cross-phase handoff: P02 (efficiency footer + dispatch-time predictive surface) inherits the byte-identity verifier cases (SC-3 status-quiet, SC-17 dispatch-yes) which P00's verifier carries as placeholders awaiting P02's suppression-path implementation. P02 also inherits the cost-annotation hook directly — `intensity-recommend.sh --format text` is the dispatch-time surface, with `config.predictive_cost_surface: false` and `--yes`/`--auto` modes suppressing the annotation block. Verification pass (12/12 gates, 0 FAIL across 12 truths + 17 artifacts + 17 key-links via `check-must-haves.sh`); read-only invariant verifier confirms `git diff --quiet` against the project tree post-suite-run is clean. The roadmap reassessment found no boundary-map deviations.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M027"
name: "commands/status.md integration + status-quiet baseline fixture"
depends_on: ["T01"]
---

## Prerequisites

- T01 has shipped `scripts/diagnostics/efficiency-footer.sh` (≥ 80 lines, executable, sourceable). CLI accepts `--milestone <Mxxx>`, `--project`, `--quiet`, `--config-defaults <path>`, `--help`. Default emits a footer block titled `Efficiency (Tier 1 rollup)`; `--quiet` (or `efficiency_footer=false`) emits zero stdout, exit 0.
- T01 has added `efficiency_footer` and `predictive_cost_surface` to the `VALID_KEYS` list in `scripts/state/read-config.sh`.
- Pre-existing `commands/status.md` (171 lines, MEM012-shaped). Sections in current order: frontmatter / Title / State Derivation / Progress Overview / Blockers / Execution History / Telemetry Metrics / Next Action / Concurrent Safety / Idempotency / Error Handling / Gotchas / Reference Files.
- Project commands convention (MEM012): canonical sections; integration tests verify cross-references resolve to existing files.
- AD-19 (single-script-file `Check:` shape): this task's `## Verification` block is a SINGLE bash invocation of T02's own deliverable. Per the M027/P00 + M027/P01 parser-shape lesson, it must NOT reference future tasks' artifacts (T04's canonical verifier ships later); T02 ships its own scoped precheck.

## Description

Update `commands/status.md` to invoke the T01 efficiency-footer helper at a stable, documented attach point (after the `## Telemetry Metrics` section, before `## Next Action`) and document the suppression semantics (`--quiet` flag and `config.efficiency_footer: false`). The pre-footer output (every existing section above the footer attach point) MUST remain structurally unchanged — no re-ordering, no rewording of existing prose. The footer is governed by `--quiet` (passed through to the helper) and by `config.efficiency_footer` (default `true`).

Also create the byte-identity baseline fixture `tests/fixtures/m027-p02/status-quiet-baseline.txt` — this is the load-bearing fixture that T04's `m027-p02-status-quiet-byte-identity.sh` verifier diffs against. The fixture captures the deterministic post-`## Next Action` tail of `orchestrator:status` output (since `commands/status.md` is a markdown command document interpreted by an agent runtime, not a shell script that emits stdout directly, the fixture captures the *prose tail* of the document — specifically the verbatim content of the Next Action / Concurrent Safety / Idempotency / Error Handling / Gotchas / Reference Files sections that an agent following the document instructions would surface verbatim under `--quiet`). The fixture is human-curated from the post-edit `commands/status.md`; T04 re-verifies on every run.

Per CON-3 / SC-3 byte-identity contract: the goal is operator + CI compatibility — `orchestrator:status --quiet` output must remain byte-identical to pre-M027 from any caller's perspective. Since the agent renders the markdown command, the most reliable proxy is to assert (a) the document still contains the same canonical sections in the same order; (b) the footer attach-point is the only structural addition; (c) the suppression-knob documentation is present and unambiguous so the rendering agent always suppresses correctly under `--quiet`. The T04 verifier asserts (a) + (b) + (c) statically (markdown source check) — actual runtime byte-identity is enforced upstream by the agent's contract honoring `--quiet` per the documented semantics.

## Steps

1. **Edit `commands/status.md`** — insert ONE new section between the existing `## Telemetry Metrics` section and the existing `## Next Action` section. The new section is titled `## Efficiency Footer` and reads:

   ```markdown
   ## Efficiency Footer

   After the telemetry block, render a one-block efficiency footer summarizing milestone-to-date cost + paired quality metrics from the M019 Tier 1 JSONL stream. The footer is governed by two suppression conditions; under EITHER, render NOTHING for this section and proceed directly to `## Next Action`.

   ### Suppression Conditions

   The efficiency footer is suppressed (zero output for this section, output remains byte-identical to pre-M027 `orchestrator:status`) when ANY of:

   1. The `--quiet` flag is passed to `orchestrator:status`.
   2. The config knob `efficiency_footer` resolves to `false`. Resolution chain: env `ORCH_EFFICIENCY_FOOTER` → local config → project config → defaults. Default is `true`.

   Otherwise, render the footer.

   ### Render

   Invoke the helper:

   ```bash
   bash scripts/diagnostics/efficiency-footer.sh --milestone <active-milestone-id>
   ```

   When no active milestone exists, fall back to the project-granularity rollup:

   ```bash
   bash scripts/diagnostics/efficiency-footer.sh --project
   ```

   The helper handles both forms — passing `--quiet` propagates the suppression to the helper. Helper output is a one-block efficiency footer (≤ 6 lines) prefixed with the literal title `Efficiency (Tier 1 rollup)`. When the JSONL stream is empty or absent, the helper emits a single-line `Efficiency: no Tier 1 records yet` (US-3 AS-3) — never an error, never a crash (CON-5 carry-forward).

   ### Read-Only

   The efficiency footer is a read-only consumer of `execution-log.jsonl` — it never writes to or rewrites the log (FR-12 / CON-1). The helper is bash-only; zero LLM tokens (FR-21 / CON-6).
   ```

2. **Add `scripts/diagnostics/efficiency-footer.sh` to the `## Reference Files` section** at the end of `commands/status.md`. Insert as a new bullet after the existing `scripts/telemetry/aggregate-metrics.sh` line:

   ```markdown
   - `scripts/diagnostics/efficiency-footer.sh` — efficiency footer helper (M027/P02). Sources or forks `scripts/diagnostics/metrics-rollup.sh` for milestone-to-date paired cost+quality aggregates. Read-only.
   ```

3. **Verify NO existing sections were re-ordered or re-worded.** The exact pre-edit shape (frontmatter / Title / State Derivation / Progress Overview / Blockers / Execution History / Telemetry Metrics / Next Action / Concurrent Safety / Idempotency / Error Handling / Gotchas / Reference Files) must be preserved with the single insertion of `## Efficiency Footer` between Telemetry Metrics and Next Action, plus the one new bullet under Reference Files.

4. **Create `tests/fixtures/m027-p02/`** directory if it does not exist.

5. **Create `tests/fixtures/m027-p02/status-quiet-baseline.txt`** — captures the verbatim tail of `commands/status.md` from the `## Next Action` section onward (post-edit, since this fixture is the post-M027 byte-identity baseline; the verifier asserts that under `--quiet`, no NEW content appears between the telemetry block and Next Action). Concretely, the fixture body is the literal copy of the `## Next Action` section through the end of `commands/status.md` (Next Action / Concurrent Safety / Idempotency / Error Handling / Gotchas / Reference Files), as a multi-line text fixture. The verifier in T04 extracts the same range from the live `commands/status.md` (using `awk` to pluck lines from `## Next Action` through end-of-file) and `diff`s against this fixture. Failure if the diff is non-zero.

6. **Create `tests/fixtures/m027-p02/README.md`** — a short note (10–20 lines) explaining the fixture's role: "Baseline for the M027/P02/T04 `m027-p02-status-quiet-byte-identity.sh` verifier. Captures the verbatim post-`## Next Action` tail of `commands/status.md`. Updated only when intentional changes to those sections land via a follow-up commit; the verifier rejects accidental drift."

7. **Markdown-only discipline.** This task ships markdown only (commands/status.md edit + fixture text + fixture README). No shell code; CON-7 (bash 3.2) does not apply directly, but the T04 `m027-p02-bash32-compat.sh` verifier still scans `commands/status.md` (and the README) for forbidden tokens — the markdown body must NOT contain literal forbidden constructs (`<<<`, `<(`, `>(`, `&>`, `${var^^}`, `declare -A`, `mapfile`). The example `bash` fenced blocks above use only `--milestone`, `--project`, `--quiet` flags — no forbidden tokens.

8. **No edits to T01's helper or to `read-config.sh`.** This task is purely document-shaped; T01 owns the helper / config-key edits.

## Must-Haves

- File `commands/status.md` exists, ≥ 170 lines (post-edit; current is 171, footer addition adds ~30 lines so post-edit ≥ 200 — but the artifact min-line check in P02-PLAN is 170, conservative).
- File `commands/status.md` contains the literal string `efficiency-footer` (referencing the helper).
- File `commands/status.md` contains a `## Efficiency Footer` heading.
- File `commands/status.md` contains a reference to the `--quiet` suppression flag in the new section.
- File `commands/status.md` contains a reference to the `efficiency_footer` config knob in the new section.
- File `commands/status.md` references `scripts/diagnostics/efficiency-footer.sh` in the `## Reference Files` section.
- File `commands/status.md` retains its pre-edit canonical sections in the pre-edit order (no re-ordering of State Derivation / Progress Overview / Blockers / Execution History / Telemetry Metrics / Next Action / Concurrent Safety / Idempotency / Error Handling / Gotchas / Reference Files).
- File `tests/fixtures/m027-p02/status-quiet-baseline.txt` exists, ≥ 1 line, contains the literal `Next Action`.
- File `tests/fixtures/m027-p02/README.md` exists.

## Verification

```bash
bash scripts/verify/m027-p02-t02-shape-precheck.sh
```

This T02-scoped precheck verifier (ships with T02) asserts T02's nine must-haves: `commands/status.md` exists ≥ 170 lines, contains `efficiency-footer`, contains `## Efficiency Footer`, contains `--quiet` and `efficiency_footer` references in the new section, references `scripts/diagnostics/efficiency-footer.sh` in `## Reference Files`, retains the pre-edit canonical section order (verified by `grep -n` line-position assertions: State Derivation < Progress Overview < Blockers < Execution History < Telemetry Metrics < Efficiency Footer < Next Action < Concurrent Safety < Idempotency < Error Handling < Gotchas < Reference Files), the fixture file `tests/fixtures/m027-p02/status-quiet-baseline.txt` exists ≥ 1 line and contains `Next Action`, and the fixture README exists.

T04 ships the canonical phase-level verifier `m027-p02-status-md-shape.sh` (which subsumes this precheck) AND `m027-p02-status-quiet-byte-identity.sh` (the byte-identity diff verifier consuming this fixture). The phase-level `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M027/phases/P02` runs at the phase boundary, not at T02 task verification.

The precheck script is created as part of T02 (its body is a small shell script that performs the nine assertions). T04 may delete this precheck once the canonical verifiers ship, mirroring the M027/P01/T03 + T04 pattern. The precheck lives at `scripts/verify/m027-p02-t02-shape-precheck.sh` and follows the standard verifier skeleton (PROJECT_ROOT via `BASH_SOURCE`; `PASS:` / `FAIL:` to stdout / stderr; exit 0/1).

## Inputs

### From Previous Tasks

- T01: `scripts/diagnostics/efficiency-footer.sh` — referenced from the new `## Efficiency Footer` section of `commands/status.md` and added to the `## Reference Files` bullet list. Not invoked from this task's code (this task is markdown-only); the helper is documented for the agent runtime to invoke at command-execution time.

### From Disk (Pre-existing)

- `commands/status.md` (171 lines) — modified in place. Pre-edit canonical sections must be preserved in pre-edit order.
- `commands/init.md`, `commands/dispatch.md`, `commands/cost.md` (P01) — reference shapes for MEM012 canonical commands convention. Read these to mirror the styling of new section headers / bullet lists.

## Constraints

- **MEM012 (command structure)**: New section follows the canonical sub-bullet style; new entry in `## Reference Files` follows the existing bullet shape (script path + one-line description).
- **CON-3 / SC-3 (back-compat byte-identity)**: Pre-edit sections preserved in pre-edit order. Footer is the ONLY structural addition (plus one bullet under Reference Files). Suppression semantics are unambiguous so an agent rendering the document under `--quiet` deterministically omits the footer.
- **CON-5 (never-abort)**: The new section explicitly documents `Efficiency: no Tier 1 records yet` for the empty-log path; never errors.
- **CON-7 (bash 3.2)**: Markdown body uses no forbidden constructs (`<<<`, `<(`, `>(`, `&>`, `${var^^}`, `declare -A`, `mapfile`). Example fenced bash blocks use plain flag-style invocations only.
- **AD-19 (single-script-file Check shape)**: This task's `Check:` invokes a single helper script (the T02-scoped precheck). T04 ships the canonical phase-level Truth `Check:` invocations.
- **FR-12 / CON-1 (read-only)**: This task is document-shaped; the documented helper invocation is read-only.

## Expected Output

After this task:

1. `commands/status.md` exists, ≥ 200 lines (post-edit), contains the new `## Efficiency Footer` section between Telemetry Metrics and Next Action, contains the new `efficiency-footer.sh` bullet under Reference Files, retains the pre-edit canonical sections in pre-edit order.
2. `tests/fixtures/m027-p02/status-quiet-baseline.txt` exists, contains the verbatim post-`## Next Action` tail of `commands/status.md`.
3. `tests/fixtures/m027-p02/README.md` exists with the short fixture-role note.
4. `scripts/verify/m027-p02-t02-shape-precheck.sh` exists, executable, exits 0 against the post-T02 codebase.
5. `git diff --quiet` is non-zero (this task creates and modifies files); however, no `execution-log.jsonl` file is touched.

## State Context

- **Current State**: executing
- **Milestone**: M027
- **Phase**: P02
- **Task**: T02-status-md-integration
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **MEM012 (command structure)**: New section follows the canonical sub-bullet style; new entry in `## Reference Files` follows the existing bullet shape (script path + one-line description).
- **CON-3 / SC-3 (back-compat byte-identity)**: Pre-edit sections preserved in pre-edit order. Footer is the ONLY structural addition (plus one bullet under Reference Files). Suppression semantics are unambiguous so an agent rendering the document under `--quiet` deterministically omits the footer.
- **CON-5 (never-abort)**: The new section explicitly documents `Efficiency: no Tier 1 records yet` for the empty-log path; never errors.
- **CON-7 (bash 3.2)**: Markdown body uses no forbidden constructs (`<<<`, `<(`, `>(`, `&>`, `${var^^}`, `declare -A`, `mapfile`). Example fenced bash blocks use plain flag-style invocations only.
- **AD-19 (single-script-file Check shape)**: This task's `Check:` invokes a single helper script (the T02-scoped precheck). T04 ships the canonical phase-level Truth `Check:` invocations.
- **FR-12 / CON-1 (read-only)**: This task is document-shaped; the documented helper invocation is read-only.

### Acceptance Criteria

- File `commands/status.md` exists, ≥ 170 lines (post-edit; current is 171, footer addition adds ~30 lines so post-edit ≥ 200 — but the artifact min-line check in P02-PLAN is 170, conservative).
- File `commands/status.md` contains the literal string `efficiency-footer` (referencing the helper).
- File `commands/status.md` contains a `## Efficiency Footer` heading.
- File `commands/status.md` contains a reference to the `--quiet` suppression flag in the new section.
- File `commands/status.md` contains a reference to the `efficiency_footer` config knob in the new section.
- File `commands/status.md` references `scripts/diagnostics/efficiency-footer.sh` in the `## Reference Files` section.
- File `commands/status.md` retains its pre-edit canonical sections in the pre-edit order (no re-ordering of State Derivation / Progress Overview / Blockers / Execution History / Telemetry Metrics / Next Action / Concurrent Safety / Idempotency / Error Handling / Gotchas / Reference Files).
- File `tests/fixtures/m027-p02/status-quiet-baseline.txt` exists, ≥ 1 line, contains the literal `Next Action`.
- File `tests/fixtures/m027-p02/README.md` exists.

### Files To Touch

- scripts/diagnostics/efficiency-footer.sh (create)
- scripts/dispatch/predictive-surface.sh (create)
- commands/status.md (modify)
- commands/dispatch.md (modify)
- tests/fixtures/m027-p02/status-quiet-baseline.txt (create)
- tests/fixtures/m027-p02/README.md (create)
- scripts/verify/m027-p02-suite.sh (create)
- scripts/verify/m027-p02-efficiency-footer-shape.sh (create)
- scripts/verify/m027-p02-status-md-shape.sh (create)
- scripts/verify/m027-p02-status-quiet-byte-identity.sh (create)
- scripts/verify/m027-p02-predictive-surface-shape.sh (create)
- scripts/verify/m027-p02-suppression-matrix.sh (create)
- scripts/verify/m027-p02-dispatch-md-shape.sh (create)
- scripts/verify/m027-p02-predictive-surface-latency.sh (create)
- scripts/verify/m027-p02-predictive-goodhart-pairing.sh (create)
- scripts/verify/m027-p02-zero-llm-token.sh (create)
- scripts/verify/m027-p02-read-only.sh (create)
- scripts/verify/m027-p02-bash32-compat.sh (create)

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