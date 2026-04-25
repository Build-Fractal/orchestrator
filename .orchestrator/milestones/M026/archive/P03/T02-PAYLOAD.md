---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T02 (Phase P03, Milestone M026)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (28 entries) | 20-707 | ~7000 | filtered |
| Decisions | 709-711 | ~100 | filtered |
| Constraints | 713-765 | ~600 | required |
| Scope | 767-795 | ~500 | required |
| Upstream Context | 797-851 | ~3000 | required |
| Task Plan | 853-1087 | ~3300 | required |
| State Context | 1089-1095 | ~100 | required |
| First-Turn Completeness | 1097-1139 | ~500 | required |
| **Total** | | **~15100** | |

## Knowledge

<!-- 28 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 422
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
hit_count: 422
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
hit_count: 422
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
hit_count: 422
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
hit_count: 372
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
hit_count: 372
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
hit_count: 372
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
hit_count: 422
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
hit_count: 372
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
hit_count: 372
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
hit_count: 372
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
hit_count: 422
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
hit_count: 422
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
hit_count: 422
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
hit_count: 372
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
hit_count: 372
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
hit_count: 372
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
hit_count: 422
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
hit_count: 372
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
hit_count: 372
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
hit_count: 422
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
hit_count: 422
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
hit_count: 372
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
hit_count: 372
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
hit_count: 372
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
hit_count: 27
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
hit_count: 27
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
hit_count: 27
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

<!-- AD-19: every Check is a single-script-file invocation. No inline compound bash, subshells, or $(...|pipe). -->

- Adapter refuses to invoke `conversus run` when the resolved edition is `oss` and the preset frontmatter declares `edition_required: paid`. Refusal emits a diagnostic to stderr matching the regex `paid-only.*CONVERSUS_EDITION=paid` (case-insensitive) and exits 1. Presets without `edition_required:` behave identically to today (backward-compatible).
  - Check: `bash scripts/verify/m026-p03-edition-required-diagnostic.sh`

- Adapter does not regress the CON-1..CON-5 invariants: 0/1/2 exit codes, full env-var set, `gate-result.md` frontmatter key set, D019 TODO pre-flight, stub-mode fixtures, filename-routed adapter shape, Bash 3.2 compat. Stub-mode path remains untouched (preset frontmatter parsing fires only on real-binary path).
  - Check: `bash scripts/verify/m011-p07-conversus-adapter-shape.sh`

- All six FR-12 doc surfaces grep-match both `conversus-oss` and `CONVERSUS_EDITION` and the original M011-era four-step resolver-order block in `commands/conversus-gate.md` is rewritten to the new edition-aware shape (no longer ends at `$HOME/Sites/conversus/bin/conversus` as the user-local convention).
  - Check: `bash scripts/verify/m026-p03-doc-surface-coverage.sh`

- Two knowledge-layer `MEM*.md` entries are graduated for this milestone: edition-resolution-precedence pattern and paid-escape-hatch env-var convention. `KNOWLEDGE-INDEX.md` lists both entries with the correct categories. Format follows MEM027 shape (frontmatter + `## Problem` + `## Pattern`/`## Convention` + `## Gate shape` body).
  - Check: `bash scripts/verify/m026-p03-mem-graduation.sh`

- `.orchestrator/DECISIONS.md` gains a new `D###` row naming the edition-resolution precedence (env-var primary → metadata probe → fallback) decision, and `CHANGELOG.md` records the M026 migration entry under the current version heading.
  - Check: `bash scripts/verify/m026-p03-decision-row.sh`

<dispatch-volatile>

## Upstream Context


### P02 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P02"
parent: "M026"
milestone: "M026"
provides:
  - "adapter edition-detection resolver (CONVERSUS_EDITION env primary + pip-show metadata probe fallback); check stdout now emits edition= and reason= lines after available=/conversus_path=; new _resolve_edition helper is callable by T02/T03 consumers, JSONL conversus_gate_invocation records carry edition field adjacent to adapter_version at both emission sites (github-common emit_conversus_gate_record + specify.sh REC_G); backward-compatible default edition=unknown when caller omits the 6th positional, dual-edition regression test with visible-skip annotations for OSS and paid Conversus editions; sample-spec.md fixture; shape-not-value (DC-4) sorted-key diff verification, F1-verdict-text-rationale,F2-arbiter-preference,F3-oauth-auto-preflight,m026-p02-gate-verdict-reliability-verifier, P02 phase verification suite orchestrator + M026/P02 Recent Changes dual-write"
requires:
  - "P01 parity matrix addendum (.orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md) establishing single-venv reality; P01 operator state from OLLAMA-PROBE.md confirming OSS installed at ~/.local/pipx/venvs/conversus/, T01 adapter check output line edition=<oss|paid|unknown>; emit_tier1_record argument-order preservation, T01 (adapter edition=/reason= lines); tests/fixtures/gate-result-pass.md; conversus pipx venv metadata at ~/.local/pipx/venvs/conversus, T01-edition-detection,T02-jsonl-edition-field,T03-dual-edition-test, from:P02/T01 what:m026-p02-edition-detection-contract.sh, m026-p02-adapter-invariants.sh; from:P02/T02 what:m026-p02-jsonl-edition-field.sh; from:P02/T03 what:m026-p02-dual-edition-test-shape.sh; from:P02/T04 what:m026-p02-gate-verdict-reliability.sh"
affects:
  - "T02 (JSONL edition field consumes resolver output); T03 (dual-edition test shape consumes resolver output); T04 (gate verdict reliability); downstream invocations from specify.sh and github-common.sh, scripts/integrations/github-common.sh,scripts/integrations/github-conversus-gate.sh,scripts/specify/specify.sh,scripts/verify/m026-p02-jsonl-edition-field.sh, tests/test-conversus-adapter-shim.sh; tests/fixtures/sample-spec.md; scripts/verify/m026-p02-dual-edition-test-shape.sh, scripts/dispatch/adapters/tool/conversus.sh, milestone-close, orchestrator:verify for P02-SUMMARY authoring"
key_files:
  - "scripts/dispatch/adapters/tool/conversus.sh (modified, +75 lines); scripts/verify/m026-p02-edition-detection-contract.sh (created); scripts/verify/m026-p02-adapter-invariants.sh (created), scripts/integrations/github-common.sh,scripts/integrations/github-conversus-gate.sh,scripts/specify/specify.sh,scripts/verify/m026-p02-jsonl-edition-field.sh, tests/test-conversus-adapter-shim.sh,tests/fixtures/sample-spec.md,scripts/verify/m026-p02-dual-edition-test-shape.sh, scripts/dispatch/adapters/tool/conversus.sh,scripts/verify/m026-p02-gate-verdict-reliability.sh, scripts/verify/m026-p02-phase-suite.sh, scripts/verify/m026-p02-recent-changes.sh, CLAUDE.md, AGENTS.md"
key_decisions:
  - "env-var primary over metadata-only to let operators declare edition without venv probe; fallthrough-with-stderr-warning on invalid CONVERSUS_EDITION values (never silently accept); conversus-oss tried FIRST in user-local fallback order (OSS-primary posture per project_m026_oss_posture.md); stub mode always emits edition=unknown reason=stub (stub is edition-agnostic by design), Emit adapter_version+edition as adjacent pair in github-common emitter (AD-4 adjacency invariant testable symmetrically with specify.sh); default edition=unknown on omitted 6th positional preserves caller backward compat; capture edition via adapter check stdout (not env var) so the two-tier resolver from T01 is the single source of truth, OQ-3 resolution: ollama absent means OSS-Anthropic branch skips with known-upstream-429 annotation (visible-skip); DC-4: SC-6 key-set diff is shape-not-value; AD-6: sections 1/1b/2 untouched, net-new section 3 replaces the prior real-binary mock-provider block, F3-keyed-on-access-token-plus-oauth-subscription-alternation,F3-scoped-to-CONVERSUS_PROVIDER-unset-via-+set-param-expansion,F1-prefers-arbiter-then-synthesis-with-awk-Verdict-extractor,verifier-F3-smoke-is-detection-replay-not-end-to-end-gate, OQ-10 dual-write parity enforced; test-shim omitted for parity with P01 suite"
patterns_established:
  - "two-tier detection (env-var declaration + metadata probe) pattern reusable for future runtime identification; stderr for warnings / stdout for structured fields (DC-5) enforced in resolver; line-order stability as verifiable contract (available=/conversus_path=/edition=/reason=), Adjacent-pair AD-4 placement via argument ordering in emit_tier1_record; backward-compat optional positional with defaulted unknown sentinel; verify script drives live emitter through staged sub-scripts to avoid process substitution / compound bash, visible-skip (annotated SKIP: line) over silent-skip for unavailable edition branches; dual-edition detection via pip-show Home-page probe reusing adapter's metadata probe; sorted-key diff of gate-result frontmatter as DC-4 contract, detection-replay-smoke-harness-for-deep-gate-logic,awk-section-paragraph-extraction-with-newline-collapse, P02 suite mirrors P01 shape (IFS newline GATES list, single-script-file gate invocation, SUMMARY+PASS/FAIL trailer); dual-write helper replaces full region so content file must include existing body lines"
drill_down_paths:
  - ".orchestrator/milestones/M026/phases/P02/tasks/T01-SUMMARY.md, .orchestrator/milestones/M026/phases/P02/tasks/T02-SUMMARY.md, .orchestrator/milestones/M026/phases/P02/tasks/T03-SUMMARY.md, .orchestrator/milestones/M026/phases/P02/tasks/T04-SUMMARY.md, .orchestrator/milestones/M026/phases/P02/tasks/T05-SUMMARY.md"
duration: "148m"
verification_result: "pass"
completed_at: "2026-04-24T22:30:40Z"
observability_surfaces:
  - "none"
---

P02 flips the orchestrator's default Conversus integration from paid to OSS while preserving a first-class paid escape hatch, and closes the OQ-16 false-PASS regression surfaced during P01 dogfood.

Five tasks delivered the minimal slice end-to-end:

- **T01 (27cc7ca)** — Adapter edition-detection resolver. A new `_resolve_edition` helper reads `CONVERSUS_EDITION=oss|paid` as the primary signal (operator declaration), falls back to a `pip show conversus` metadata probe against the pipx venv's `Home-page:` line, and short-circuits to `edition=unknown` under stub mode. `_resolve_binary` emits `edition=`/`reason=` on `check` stdout immediately after the pre-existing `available=`/`conversus_path=` pair. Line ordering is the verifiable contract. Adapter delta: +75 lines. Bash 3.2 clean. User-local fallback now tries `~/Sites/conversus-oss/bin/conversus` first (OSS-primary posture per `project_m026_oss_posture.md`).

- **T02 (fdff944)** — JSONL `edition` field on `conversus_gate_invocation` records. Additive per AD-4. Wired at both emission sites: `scripts/integrations/github-common.sh::emit_conversus_gate_record` (via `emit_tier1_record` argument ordering so `adapter_version` and `edition` land as adjacent JSON keys) and the inline emission at `scripts/specify/specify.sh`. The caller derives the edition by reading the adapter's `check` subcommand output — single source of truth — with `:=unknown` fallback. Pre-existing M019 Tier 1 readers remain unaffected; M013/P04 observability shape test stays green.

- **T03 (2867170)** — Dual-edition regression test. A new section 3 of `tests/test-conversus-adapter-shim.sh`, gated by `CONVERSUS_INTEGRATION=1`, exercises both editions when both are installed. Under the current operator environment (OSS installed, paid absent, no `ANTHROPIC_API_KEY`, no ollama), both branches emit **visible-skip** annotations — `SKIP: known-upstream-429 (OSS lacks PR #29; ...)` and `SKIP: paid build not installed` — and the test exits 0. Assertion contract is **shape, not value** per DC-4: when both branches actually run, the test diffs sorted frontmatter key-sets across editions rather than comparing verdict values. Stub-path sections 1, 1b, 2 untouched per AD-6.

- **T04 (100c06f)** — Gate-verdict reliability bundle, closing POST-P01-FINDINGS F1/F2/F3 and OQ-16. Three tightly-coupled changes in the adapter: (F1) rationale now extracts the first paragraph of the synthesis file's `## Verdict` section via an awk pattern that tolerates section-heading + blank-line terminators, with fallback to the 32ab6ea synthesized formula; (F2) when `${_run_output_dir}/arbiter/resolution.md` exists, it's preferred over `summary/final.md` as the verdict-text source while structural fields still come from the synthesis; (F3) when `CONVERSUS_PROVIDER` is unset (`[ -z "${CONVERSUS_PROVIDER+set}" ]`), `ANTHROPIC_API_KEY` is not exported, and `~/.conversus/auth.json` contains an OAuth marker (`access_token` as the canonical key per `~/Sites/conversus-oss/engine/auth.py`, with `oauth|subscription` as belt-and-suspenders alternation), the adapter auto-sets `CONVERSUS_PROVIDER=claude-code` and emits a single `note:` line to stderr. Operator-override precedence preserved via `+set` parameter expansion. Adapter delta: +38 lines (budget ≤ +40).

- **T05 (0c6e7a0)** — Phase verification suite orchestrator and Recent Changes dual-write. `scripts/verify/m026-p02-phase-suite.sh` chains the six M026/P02 gates with the three M011/P07 cross-milestone invariant gates (DC-2) and emits `SUMMARY: m026-p02-phase-suite.sh pass=9 fail=0`. CLAUDE.md and AGENTS.md receive a reverse-chronological M026/P02 fragment in the `orchestrator:recent-changes` marker region via `scripts/util/dual-write-runtime-md.sh`; OQ-10 dual-write parity enforced. The helper replaces the full between-markers region (not append-mode), so the content file was constructed to include every existing line plus the new one — the non-overwrite invariant is the caller's responsibility, not the helper's.

**Cross-task patterns reinforced**: two-tier detection (env-var declaration + metadata probe) as a reusable runtime-identification shape; stderr/stdout discipline (DC-5) — structured fields on stdout, warnings on stderr; visible-skip over silent-skip for unavailable branches; shape-not-value assertions for cross-edition equivalence; detection-replay harnesses as the hermetic path for deep-gate logic that can't run end-to-end in a verifier.

**Adapter invariants (CON-1..CON-5)**: preserved. Exit codes 0/1/2 unchanged; full env-var set (nine vars including new `CONVERSUS_EDITION`) present; `gate-result.md` frontmatter key-set unchanged; D019 TODO pre-flight unmodified; stub-mode fixture paths unchanged; filename-routed adapter auto-discovery pattern unbroken; no `~/Sites/conversus*` writes (read-only probe only); Bash 3.2 clean across all nine gates.

**One Key Link fix landed post-T05 (456b814)**: the initial RC fragment did not name `P02-SUMMARY.md` literally, causing `check-must-haves.sh` to fail two key-link rows. The fragment was re-dual-written with a trailing `See .orchestrator/milestones/M026/phases/P02/P02-SUMMARY.md.` clause and verified green.

**One side-fix bundled into the same branch (316411e)**: a `read-roadmap.sh` parens-in-Risk and malformed-Depends silent-pass bug surfaced via bbt-companion dogfood batch 2 was fixed in-line (Depends parsing now hard-fails on non-P## tokens; Risk strips parenthetical commentary). `tests/test-roadmap-dep-safety.sh` (5/5 pass) added as regression coverage.

**Verification**: Tier 1 31/31 PASS (post-key-link-fix). Tier 2 1/1 PASS. Tier 3 skipped (no behavioral-only truths — every P02 truth carries a `Check:` sub-item). Tier 4 skipped (standard intensity). `check-boundary-map.sh` reports 7 FAILs, all traceable to the narrative-prose shape of the roadmap's Produces: cells — same parser limitation P01-VERIFICATION.md documents; all artifacts exist and pass individual Tier 1 artifact checks.

## Task Plan

---
schema_version: "1.0"
task: "T02"
phase: "P03"
milestone: "M026"
name: "Six doc-surface in-place rewrites — resolver order + escape-hatch shape (FR-12)"
depends_on: []
---

## Prerequisites

- Six doc surfaces exist on disk and contain `conversus`-related prose:
  - `commands/conversus-gate.md`
  - `commands/ingest.md`
  - `commands/specify.md`
  - `docs/ingesting-arbitrary-specs.md`
  - `references/github-integration.md`
  - `references/spec-management.md`
- Spec 027 §FR-12 specifies the contract: docs grep-match `conversus-oss` and `CONVERSUS_EDITION`, and the M011-era four-step resolver-order block at `commands/conversus-gate.md:24-28` is rewritten to the new edition-aware shape (per Addendum §D, single-venv reality: edition detection via `CONVERSUS_EDITION=oss|paid` env var primary, `python -m pip show conversus` metadata-probe fallback; `CONVERSUS_HOME` remains absolute override).
- AD-7 mandates **revise-in-place** posture — no append-at-end blocks.
- `references/architecture.md` already has the durable Conversus Operator Notes section (FR-14, shipped in P01) — out of scope for T02.

## Description

Update each of the six doc surfaces in place so:

1. The new resolver order (with OSS as user-local default and paid as escape hatch) is reflected wherever the doc currently describes the resolver.
2. Both `conversus-oss` and `CONVERSUS_EDITION` are grep-matchable in every surface (FR-12 mechanical contract).
3. The M011-era four-step resolver order in `commands/conversus-gate.md:24-28` is fully rewritten to the new edition-aware shape (six steps reflecting the P02 resolver: STUB → PATH → CONVERSUS_HOME → CONVERSUS_EDITION → user-local OSS → user-local paid; metadata-probe fallback noted).
4. The same four-step block in `docs/ingesting-arbitrary-specs.md:178-186` is also rewritten.
5. `commands/ingest.md`, `commands/specify.md`, `references/github-integration.md`, `references/spec-management.md` get a shorter mention (one paragraph each) explaining that the adapter resolves OSS by default and the operator can flip to paid via `CONVERSUS_EDITION=paid`. Reading paths chosen by where each doc already mentions the adapter.

T02 also creates the verifier `scripts/verify/m026-p03-doc-surface-coverage.sh` which mechanically asserts the FR-12 grep contract on all six surfaces.

## Steps

1. **Read each of the six doc surfaces** to understand the current shape and best insertion/rewrite points. The user has already done preliminary grep — see the line-numbered hits in the P03 plan-phase summary. Key insertion targets confirmed:
   - `commands/conversus-gate.md` lines 24-28: rewrite the four-step resolver block.
   - `docs/ingesting-arbitrary-specs.md` lines 178-186: rewrite the analogous four-step resolver block.
   - `commands/ingest.md`: add a short paragraph in the section that already references `conversus.sh check` (around line 124, the "Conversus binary missing (graceful degradation)" block) describing edition resolution.
   - `commands/specify.md`: add a short note in the "Gate adapter pre-flight (per D019)" block around line 125 noting `CONVERSUS_EDITION` as a related env var.
   - `references/github-integration.md`: add a short paragraph in the "Conversus Pre-Merge Gate" section around line 321 noting the OSS default + escape hatch.
   - `references/spec-management.md`: add a short note in the section that already references `conversus.sh` (around line 146 "M014 ships preset + prompts only") explaining the edition resolution.

2. **Rewrite `commands/conversus-gate.md` lines 24-28** from the M011 four-step:

   ```
   1. `CONVERSUS_STUB=1` — stub mode (test-only, uses canned fixtures).
   2. `command -v conversus` — PATH.
   3. `$CONVERSUS_HOME/bin/conversus` — explicit env var.
   4. `$HOME/Sites/conversus/bin/conversus` — user-local convention.
   ```

   to the M026/P03 six-step:

   ```
   1. `CONVERSUS_STUB=1` — stub mode (test-only, uses canned fixtures).
   2. `command -v conversus` — PATH.
   3. `$CONVERSUS_HOME/bin/conversus` — explicit absolute override.
   4. `$HOME/Sites/conversus-oss/bin/conversus` — user-local OSS default (M026/P02).
   5. `$HOME/Sites/conversus/bin/conversus` — user-local paid escape hatch.
   ```

   Add a follow-on paragraph (one-liner) describing edition resolution:

   ```
   Edition is reported on `check` stdout as `edition=<oss|paid|unknown>`. Operator declares the edition via `CONVERSUS_EDITION=oss|paid` (primary); fallback is `python -m pip show conversus` metadata probe against the resolved venv's `Home-page:` line. Stub mode is edition-agnostic (`edition=unknown reason=stub`). See `references/architecture.md` "Conversus Adapter — Operator Notes" for the operator runbook.
   ```

   Per FR-10/FR-11 also add a short paragraph (after the resolver section, before the "Subcommands" reference if present) describing the paid-only-preset refusal:

   ```
   **Paid-only-preset refusal (M026/P03)**: a preset whose YAML frontmatter declares `edition_required: paid` invoked on an OSS-resolved binary will be refused before any `conversus run` invocation. The diagnostic on stderr names the preset, the edition requirement, and `CONVERSUS_EDITION=paid` as the escape. Presets without `edition_required:` behave identically to today.
   ```

3. **Rewrite `docs/ingesting-arbitrary-specs.md` lines 178-186** analogously:

   Replace:

   ```
   Resolver order for the conversus binary:

   1. `CONVERSUS_STUB=1` — stub mode (testing).
   2. `command -v conversus` — on PATH.
   3. `$CONVERSUS_HOME/bin/conversus` — explicit env var.
   4. `$HOME/Sites/conversus/bin/conversus` — user-local convention.

   To install conversus locally, clone the repo to `~/Sites/conversus` (or any
   location pointed at by `CONVERSUS_HOME`). See the conversus project for its
   ```

   With:

   ```
   Resolver order for the conversus binary (M026/P02):

   1. `CONVERSUS_STUB=1` — stub mode (testing).
   2. `command -v conversus` — on PATH.
   3. `$CONVERSUS_HOME/bin/conversus` — explicit absolute override.
   4. `$HOME/Sites/conversus-oss/bin/conversus` — user-local OSS default.
   5. `$HOME/Sites/conversus/bin/conversus` — user-local paid escape hatch.

   Edition (`oss|paid|unknown`) is reported on `check` stdout. Operator declares the edition via `CONVERSUS_EDITION=oss|paid`; fallback is a `pip show conversus` metadata probe.

   To install the OSS conversus locally, clone the OSS repo to `~/Sites/conversus-oss`. To install the paid build, clone to `~/Sites/conversus` (or any location pointed at by `CONVERSUS_HOME`). See the conversus project for its
   ```

4. **Add a short paragraph to `commands/ingest.md`** in the "Conversus binary missing (graceful degradation)" block (around line 124). Insert as a new bullet immediately after the existing "Conversus binary missing" bullet:

   ```
   - **Edition resolution (M026)**: the adapter resolves to the OSS conversus build (`~/Sites/conversus-oss`) by default. Operators who need the paid build for a specific invocation set `CONVERSUS_EDITION=paid` in the environment; `CONVERSUS_HOME` remains the absolute override. Edition is reported on `check` stdout as `edition=<oss|paid|unknown>` and surfaces in every `conversus_gate_invocation` JSONL record. See `commands/conversus-gate.md` for the full resolver order.
   ```

5. **Add a short note to `commands/specify.md`** at the end of the "Gate adapter pre-flight (per D019)" block around line 125. Append after the existing TODO-pre-flight prose:

   ```
   The adapter resolves to the OSS conversus build by default (M026); set `CONVERSUS_EDITION=paid` to flip to the paid build for paid-only presets. See `commands/conversus-gate.md` for the full resolver and edition-aware diagnostics.
   ```

6. **Add a short paragraph to `references/github-integration.md`** in the "Conversus Pre-Merge Gate" section. Insert as a new bullet at the end of the bullets that begin with "**Strict mode**" / "**30-second timeout**" / etc. (around line 329):

   ```
   - **Edition resolution** — the adapter resolves to the OSS conversus build (`~/Sites/conversus-oss`) by default; operators set `CONVERSUS_EDITION=paid` to flip to the paid build for paid-only presets. The resolved edition is reported on every `conversus_gate_invocation` JSONL record. See `commands/conversus-gate.md` for the full resolver order.
   ```

7. **Add a short note to `references/spec-management.md`** at the end of the "M014 ships preset + prompts only" paragraph around line 146:

   ```
   The adapter resolves to the OSS conversus build by default (M026/P02); operators set `CONVERSUS_EDITION=paid` to flip. Edition is reported on the `conversus_gate_invocation` JSONL record emitted per gate run.
   ```

8. **Create `scripts/verify/m026-p03-doc-surface-coverage.sh`** (single-script-file shape, AD-19 compliant, Bash 3.2 compatible). The verifier must:

   ```sh
   #!/usr/bin/env bash
   # scripts/verify/m026-p03-doc-surface-coverage.sh
   # Verifies M026/P03/T02: six doc surfaces grep-match conversus-oss + CONVERSUS_EDITION (FR-12).
   # Verifies the M011-era four-step resolver block in commands/conversus-gate.md is rewritten.
   set -u

   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

   pass=0; fail=0
   _pass() { pass=$((pass+1)); echo "PASS: $1"; }
   _fail() { fail=$((fail+1)); echo "FAIL: $1"; }

   SURFACES="commands/conversus-gate.md commands/ingest.md commands/specify.md docs/ingesting-arbitrary-specs.md references/github-integration.md references/spec-management.md"

   for surface in $SURFACES; do
     full="${REPO_ROOT}/${surface}"
     if [ ! -f "$full" ]; then _fail "${surface}: file missing"; continue; fi
     if grep -q 'conversus-oss' "$full"; then _pass "${surface}: contains 'conversus-oss'"; else _fail "${surface}: missing 'conversus-oss'"; fi
     if grep -q 'CONVERSUS_EDITION' "$full"; then _pass "${surface}: contains 'CONVERSUS_EDITION'"; else _fail "${surface}: missing 'CONVERSUS_EDITION'"; fi
   done

   # The M011-era 4-step resolver block in commands/conversus-gate.md ended at "user-local convention".
   # Confirm the rewrite by asserting the new "user-local OSS default" or "user-local paid escape hatch"
   # phrasing is present.
   gate_doc="${REPO_ROOT}/commands/conversus-gate.md"
   if grep -qE 'user-local OSS default|user-local paid escape hatch' "$gate_doc"; then
     _pass "commands/conversus-gate.md: M011-era resolver block rewritten"
   else
     _fail "commands/conversus-gate.md: original 'user-local convention' resolver block not rewritten"
   fi

   # Same check for docs/ingesting-arbitrary-specs.md.
   ingest_doc="${REPO_ROOT}/docs/ingesting-arbitrary-specs.md"
   if grep -qE 'user-local OSS default|user-local paid escape hatch' "$ingest_doc"; then
     _pass "docs/ingesting-arbitrary-specs.md: resolver block rewritten"
   else
     _fail "docs/ingesting-arbitrary-specs.md: resolver block not rewritten"
   fi

   echo "----"
   echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   echo "PASS: $(basename "$0")"
   exit 0
   ```

9. **Run the verifier** to confirm green:

   ```sh
   bash scripts/verify/m026-p03-doc-surface-coverage.sh
   ```

   Expected:

   ```
   ----
   SUMMARY: m026-p03-doc-surface-coverage.sh pass=14 fail=0
   PASS: m026-p03-doc-surface-coverage.sh
   ```

   (12 grep checks + 2 rewrite-shape checks = 14 PASS lines.)

## Must-Haves

Addresses phase must-haves:
- "Truth: all six FR-12 doc surfaces grep-match conversus-oss + CONVERSUS_EDITION; the M011-era four-step resolver block in commands/conversus-gate.md is rewritten"
- Artifacts: `scripts/verify/m026-p03-doc-surface-coverage.sh`, six modified docs

## Verification

```
bash scripts/verify/m026-p03-doc-surface-coverage.sh
```

Must exit 0 with a `PASS:` final line.

## Inputs

### From Previous Tasks

None — T02 is independent within P03.

### From Disk (Pre-existing)

The six FR-12 doc surfaces. AD-7 mandates revise-in-place — do NOT append a wholesale block at end of file; integrate edits into the prose at the reading paths each doc already uses.

## Constraints

- **AD-7** (revise-in-place): edits land inline at the relevant reading paths, not as appended blocks.
- **CON-1** (no caller code change): no scripts modified beyond verifier creation.
- **AD-19** (single-script-file Check shape): verifier uses no compound bash that would trigger the harness heuristic.
- **Idempotent**: re-running the verifier after a no-op `touch` of any surface still passes (greps are idempotent).
- **Bash 3.2 compatible**: verifier uses `for` over a space-separated string, not `mapfile` or arrays-with-IFS.

## Expected Output

- Six doc files modified in-place (line-count deltas: ~5-15 lines each).
- `scripts/verify/m026-p03-doc-surface-coverage.sh` — created (~50-70 lines).
- `bash scripts/verify/m026-p03-doc-surface-coverage.sh` exits 0, prints `SUMMARY: ... pass=14 fail=0` and `PASS:` final line.

## State Context

- **Current State**: executing
- **Milestone**: M026
- **Phase**: P03
- **Task**: T02
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **AD-7** (revise-in-place): edits land inline at the relevant reading paths, not as appended blocks.
- **CON-1** (no caller code change): no scripts modified beyond verifier creation.
- **AD-19** (single-script-file Check shape): verifier uses no compound bash that would trigger the harness heuristic.
- **Idempotent**: re-running the verifier after a no-op `touch` of any surface still passes (greps are idempotent).
- **Bash 3.2 compatible**: verifier uses `for` over a space-separated string, not `mapfile` or arrays-with-IFS.

### Acceptance Criteria

Addresses phase must-haves:
- "Truth: all six FR-12 doc surfaces grep-match conversus-oss + CONVERSUS_EDITION; the M011-era four-step resolver block in commands/conversus-gate.md is rewritten"
- Artifacts: `scripts/verify/m026-p03-doc-surface-coverage.sh`, six modified docs

### Files To Touch

- scripts/dispatch/adapters/tool/conversus.sh (modify)
- scripts/verify/m026-p03-edition-required-diagnostic.sh (create)
- scripts/verify/m026-p03-doc-surface-coverage.sh (create)
- scripts/verify/m026-p03-mem-graduation.sh (create)
- scripts/verify/m026-p03-decision-row.sh (create)
- scripts/verify/m026-p03-recent-changes.sh (create)
- scripts/verify/m026-p03-phase-suite.sh (create)
- tests/fixtures/preset-edition-required-paid.yml (create)
- commands/conversus-gate.md (modify)
- commands/ingest.md (modify)
- commands/specify.md (modify)
- docs/ingesting-arbitrary-specs.md (modify)
- references/github-integration.md (modify)
- references/spec-management.md (modify)
- knowledge/patterns/MEM029.md (create)
- knowledge/conventions/MEM030.md (create)
- KNOWLEDGE-INDEX.md (modify)
- .orchestrator/DECISIONS.md (modify)
- CHANGELOG.md (modify)
- CLAUDE.md (modify — RC region only via dual-write)
- AGENTS.md (modify — RC region only via dual-write)
- .orchestrator/milestones/M026/phases/P03/P03-SUMMARY.md (create at phase close)

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