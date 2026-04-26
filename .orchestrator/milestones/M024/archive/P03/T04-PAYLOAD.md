---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T04 (Phase P03, Milestone M024)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~800 | required |
| Upstream Context | 981-1047 | ~1600 | required |
| Task Plan | 1049-1481 | ~5400 | required |
| State Context | 1483-1489 | ~100 | required |
| First-Turn Completeness | 1491-1532 | ~800 | required |
| **Total** | | **~19500** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 479
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
hit_count: 479
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
hit_count: 479
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
hit_count: 479
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
hit_count: 421
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
hit_count: 421
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
hit_count: 421
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
hit_count: 479
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
hit_count: 421
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
hit_count: 421
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
hit_count: 421
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
hit_count: 479
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
hit_count: 479
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
hit_count: 479
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
hit_count: 421
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
hit_count: 421
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
hit_count: 421
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
hit_count: 479
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
hit_count: 421
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
hit_count: 421
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
hit_count: 479
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
hit_count: 479
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
hit_count: 421
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
hit_count: 421
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
hit_count: 421
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
hit_count: 76
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
hit_count: 76
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
hit_count: 76
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
hit_count: 55
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
hit_count: 55
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
hit_count: 45
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

### Truths

- The proposal emitter, when given a paragraph-shaped input, populates the four classifiable axes with non-stub values (scope_tier ∈ {A,B,C}, decomposition ∈ {single-task, single-phase, milestone-with-phases, multi-milestone}, recommended_command ∈ {orchestrator:dispatch, orchestrator:specify}, design_gate from existing signal — none for non-design inputs in P03 scope, conversus_gate=none until P04 wires it). The P01-stub rationale string `P01 stub — deep classifier ships in a later phase.` no longer appears in `scope_tier` / `decomposition` / `recommended_command` rationale slots when input_shape=paragraph.
  - Check: `bash scripts/verify/m024-p03-paragraph-classify.sh`
- The approval-gate script, given a proposal path and an `approve` decision, mutates the proposal frontmatter in-place: sets `approved_at: <ISO8601>`, sets `pending_approval: false`, and emits a `recommended_command_invoke=<command>` line to stdout for the caller to dispatch.
  - Check: `bash scripts/verify/m024-p03-approval-gate.sh`
- The approval-gate script honors `cancel` (sets `cancelled_at`, leaves no further state changes) and `revise` (exits with a marker for the caller to re-emit; revision body lands in P05 — P03 only validates the gate routes the verb correctly).
  - Check: `bash scripts/verify/m024-p03-approval-gate-verbs.sh`
- The route-to-specify script, given a proposal whose `recommended_command=orchestrator:specify`, emits a deterministic invocation contract — one stdout line `invoke=orchestrator:specify --input-from <proposal_path>` — and validates the M014 entry point by re-running the cross-cutting probe (`test -f scripts/specify/specify.sh`) before emitting, exiting non-zero with the unshipped-stub message if the probe fails.
  - Check: `bash scripts/verify/m024-p03-route-to-specify.sh`
- The route-to-dispatch script, given a proposal whose `recommended_command=orchestrator:dispatch`, emits one stdout line `invoke=orchestrator:dispatch --proposal <proposal_path>` and (when `auto_proceeded=true` is recorded by the upstream fast-path branch) records `proceeded_at: <ISO8601>` and emits `auto_proceed=1` to stdout.
  - Check: `bash scripts/verify/m024-p03-route-to-dispatch.sh`
- `commands/evaluate.md` documents all five input shapes (idea / paragraph / fragment / spec / empty) in a single "Input Shapes" section, naming the recommended downstream command per shape; the legacy spec-on-disk path remains the canonical pre-M024 entry-point with a back-reference to the new "Input Shapes" section per FR-6.
  - Check: `bash scripts/verify/m024-p03-evaluate-md.sh`
- The two phase-level tests (`tests/test-paragraph-intake.sh` and `tests/test-approval-gate.sh`) plus the P03 suite all exit 0 on a clean checkout.
  - Check: `bash scripts/verify/m024-p03-suite.sh`
- All P03-introduced shell scripts respect SB-3 write-confinement: writes target only `.orchestrator/intake/<id>/` (proposal frontmatter mutations) and `/tmp` (test scratch).
  - Check: `bash scripts/verify/m024-p03-write-confinement.sh`

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
task: "T04"
phase: "P03"
milestone: "M024"
name: "commands/evaluate.md rewrite + two phase tests + suite"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- T01 complete: paragraph classifier wired into the emitter; paragraph proposals carry deep axes.
- T02 complete: `scripts/intake/approval-gate.sh` exists with `approve | cancel | revise` verbs.
- T03 complete: `scripts/intake/route-to-specify.sh` and `scripts/intake/route-to-dispatch.sh` exist and emit deterministic invoke lines.
- The legacy spec-on-disk path in `commands/evaluate.md` (lines 23–35 currently) must remain byte-compatible per FR-6 — T04 adds a new "Input Shapes" section above the existing `Spec Discovery` block; it does not edit the existing scope-analysis / tier-classification prose.

## Description

Three deliverables:

1. **Edit `commands/evaluate.md`** to add a new top-level section **`## Input Shapes`** that documents all five input shapes (idea / paragraph / fragment / spec / empty), names the recommended downstream command per shape, and back-references the P01 + P03 scripts. Inserted **between** the `# orchestrator:evaluate` title block and the existing `## Prerequisites` block (no edits to the prerequisites or scope-analysis prose — FR-6 byte-compat invariant on the legacy path).

2. **Author two phase-level tests**: `tests/test-paragraph-intake.sh` (paragraph end-to-end: emit → assert non-stub axes → approve via gate → route to specify) and `tests/test-approval-gate.sh` (gate verb matrix: approve, cancel, revise, idempotency-guard, unknown-verb).

3. **Author the P03 suite + write-confinement + evaluate-md verify scripts** that wire everything together for `scripts/verify/check-must-haves.sh`-style consumption.

### `commands/evaluate.md` — new "Input Shapes" section

Insert this block immediately after the title and before the existing `## Prerequisites` heading. The legacy spec-on-disk path (current `## Spec Discovery` etc.) is unchanged — it remains the canonical pre-M024 entry-point per FR-6. The new section's first paragraph back-references the legacy path so readers landing on the new section understand the byte-compat guarantee.

```markdown
## Input Shapes

`orchestrator:evaluate` accepts any of five input shapes, detected mechanically by `scripts/intake/shape-detect.sh` (M024/P01) before tier classification runs. Every invocation emits a single reviewable proposal at `.orchestrator/intake/<id>/proposal.md` covering all six routing axes; the recommended downstream command and approval-gate behavior depend on the input shape and the resulting tier.

**Legacy spec-on-disk callers**: see `## Spec Discovery` below — the spec-on-disk path is unchanged and produces byte-compatible today-shape evaluation output per FR-6. The new proposal artifact is additionally emitted alongside it.

| Input shape | Detection rule (see `shape-detect.sh`)                                                | Recommended downstream                              | Approval gate                          |
|-------------|---------------------------------------------------------------------------------------|-----------------------------------------------------|----------------------------------------|
| `spec`      | `--spec-path <p>` points at a `type: feature-spec` file                               | `orchestrator:roadmap` (legacy path) + proposal.md  | Operator-approve unless degenerate     |
| `paragraph` | Word-count 11–80 with no fragment markers (default catch-all)                         | Tier A → `orchestrator:dispatch`; Tier B/C → `orchestrator:specify` (see `paragraph-classify.sh`) | Operator-approve (revise / cancel possible) |
| `fragment`  | Structural marker (`##` heading, Given/When/Then triple, FR-bullet) OR word-count ≥81 | `orchestrator:specify` (P05+ wires deep classifier) | Operator-approve                       |
| `idea`      | Word-count ≤10                                                                        | Tier A → `orchestrator:dispatch` (P05+ wires deep classifier) | Operator-approve unless degenerate     |
| `empty`     | No `--input` and no `--spec-path`                                                     | Bounded Q&A loop (P05+ wires Q&A); then proposal as if paragraph | Operator-approve                       |

For every non-degenerate shape, the operator is prompted via `scripts/intake/approval-gate.sh` with three verbs:

- `approve` — invoke the recommended downstream command (`scripts/intake/route-to-specify.sh` or `scripts/intake/route-to-dispatch.sh`).
- `cancel` — record `cancelled_at` to the proposal and halt.
- `revise <axis>=<value>` — override an axis and re-emit (full revision body lands in P05; P03 records revision intent only).

The degenerate fast-path (Tier A + Quick + no-conversus + no-design) auto-proceeds to `orchestrator:dispatch` without an approval prompt — wired in P06.

### Pre-M023 design-gate degradation

When the design-gate axis recommends a walkthrough on a checkout where M023 has not shipped, the router emits the exact string `"design walkthrough lands in M023; author DESIGN.md manually or skip"` and offers `manual` / `skip` branches per FR-7. P03 does not exercise this branch (P07 wires the design-gate classifier); the message is pinned for grep-stability and lands when P07 ships.
```

### `tests/test-paragraph-intake.sh`

End-to-end paragraph dogfood: emit a paragraph proposal, assert the three deep axes, run the approval gate, route to specify.

```bash
#!/usr/bin/env bash
# tests/test-paragraph-intake.sh
# M024/P03 phase test — paragraph end-to-end (emit → deep axes → approve → route).
# Conventions: parallel arrays for pass/fail tracking (MEM002).

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
GATE="$ROOT/scripts/intake/approval-gate.sh"
ROUTE_S="$ROOT/scripts/intake/route-to-specify.sh"
ROUTE_D="$ROOT/scripts/intake/route-to-dispatch.sh"

PASS=0
FAIL=0
NAMES_0=""; NAMES_1=""; NAMES_2=""; NAMES_3=""
i=0

pass() { PASS=$((PASS+1)); eval "NAMES_$i=\"PASS: \$1\""; i=$((i+1)); }
fail() { FAIL=$((FAIL+1)); eval "NAMES_$i=\"FAIL: \$1 — \$2\""; i=$((i+1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# ----- Tier A paragraph (≤30 words) → dispatch.
emit_a=$(bash "$EMIT" --input "Add a status caching layer for five seconds." --intake-root "$tmp/a")
prop_a=$(echo "$emit_a" | sed -n 's/^proposal_path=//p')
if [ -f "$prop_a" ] && grep -q '^scope_tier: "A"' "$prop_a" && grep -q '^recommended_command: "orchestrator:dispatch"' "$prop_a"; then
  pass "tier A paragraph → dispatch"
else
  fail "tier A paragraph → dispatch" "proposal at $prop_a missing tier=A or dispatch"
fi

# Approve the Tier A proposal; gate emits invoke=orchestrator:dispatch.
ag_out=$(bash "$GATE" --proposal "$prop_a" --verb approve)
if echo "$ag_out" | grep -q '^recommended_command_invoke=orchestrator:dispatch$'; then
  pass "gate approve → dispatch invoke"
else
  fail "gate approve → dispatch invoke" "got: $ag_out"
fi

# Route to dispatch.
rd_out=$(bash "$ROUTE_D" --proposal "$prop_a")
if echo "$rd_out" | grep -q "^invoke=orchestrator:dispatch --proposal $prop_a\$"; then
  pass "route-to-dispatch invoke line"
else
  fail "route-to-dispatch invoke line" "got: $rd_out"
fi

# ----- Tier B paragraph (31–80 words) → specify.
para_b="We should redesign the status command output to include a last-seen timestamp, a cache layer with five-second TTL, and a no-cache flag for callers that need fresh data. Also a verbose mode."
emit_b=$(bash "$EMIT" --input "$para_b" --intake-root "$tmp/b")
prop_b=$(echo "$emit_b" | sed -n 's/^proposal_path=//p')
if [ -f "$prop_b" ] && grep -q '^scope_tier: "B"' "$prop_b" && grep -q '^recommended_command: "orchestrator:specify"' "$prop_b"; then
  pass "tier B paragraph → specify"
else
  fail "tier B paragraph → specify" "proposal at $prop_b missing tier=B or specify"
fi

# Approve + route to specify.
ag_out_b=$(bash "$GATE" --proposal "$prop_b" --verb approve)
if echo "$ag_out_b" | grep -q '^recommended_command_invoke=orchestrator:specify$'; then
  pass "gate approve → specify invoke"
else
  fail "gate approve → specify invoke" "got: $ag_out_b"
fi
rs_out=$(bash "$ROUTE_S" --proposal "$prop_b")
if echo "$rs_out" | grep -q "^invoke=orchestrator:specify --input-from $prop_b\$"; then
  pass "route-to-specify invoke line"
else
  fail "route-to-specify invoke line" "got: $rs_out"
fi

# ----- Tier C paragraph (milestone marker) → specify + milestone-with-phases.
emit_c=$(bash "$EMIT" --input "Plan a new milestone with multiple phases that overhauls the status command surface." --intake-root "$tmp/c")
prop_c=$(echo "$emit_c" | sed -n 's/^proposal_path=//p')
if [ -f "$prop_c" ] && grep -q '^scope_tier: "C"' "$prop_c" && grep -q '^decomposition: "milestone-with-phases"' "$prop_c"; then
  pass "tier C paragraph → milestone-with-phases"
else
  fail "tier C paragraph → milestone-with-phases" "proposal at $prop_c missing tier=C or correct decomposition"
fi

# Print summary.
n=0
while [ $n -lt $i ]; do
  eval "echo \"\$NAMES_$n\""
  n=$((n+1))
done

echo "----- test-paragraph-intake.sh: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
```

### `tests/test-approval-gate.sh`

Gate verb matrix.

```bash
#!/usr/bin/env bash
# tests/test-approval-gate.sh
# M024/P03 phase test — approval gate verb matrix.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
GATE="$ROOT/scripts/intake/approval-gate.sh"

PASS=0
FAIL=0
NAMES_0=""; NAMES_1=""; NAMES_2=""; NAMES_3=""; NAMES_4=""; NAMES_5=""
i=0
pass() { PASS=$((PASS+1)); eval "NAMES_$i=\"PASS: \$1\""; i=$((i+1)); }
fail() { FAIL=$((FAIL+1)); eval "NAMES_$i=\"FAIL: \$1 — \$2\""; i=$((i+1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

new_proposal() {
  local dir="$1"; local input="$2"
  local out path
  out=$(bash "$EMIT" --input "$input" --intake-root "$dir")
  path=$(echo "$out" | sed -n 's/^proposal_path=//p')
  echo "$path"
}

# Approve.
p1=$(new_proposal "$tmp/d1" "Add a status caching layer for five seconds.")
ao=$(bash "$GATE" --proposal "$p1" --verb approve)
if echo "$ao" | grep -q '^recommended_command_invoke=' && grep -q '^pending_approval: false' "$p1" && grep -qE '^approved_at: "[0-9]{4}-' "$p1"; then
  pass "approve: invoke + frontmatter mutation"
else
  fail "approve: invoke + frontmatter mutation" "stdout=$ao"
fi

# Approve again on finalized proposal — must exit non-zero.
if bash "$GATE" --proposal "$p1" --verb approve >/dev/null 2>&1; then
  fail "approve idempotency guard" "second approve unexpectedly succeeded"
else
  pass "approve idempotency guard"
fi

# Cancel.
p2=$(new_proposal "$tmp/d2" "Add a status caching layer for five seconds.")
co=$(bash "$GATE" --proposal "$p2" --verb cancel)
if [ -z "$co" ] && grep -qE '^cancelled_at: "[0-9]{4}-' "$p2" && grep -q '^pending_approval: false' "$p2"; then
  pass "cancel: silent + frontmatter mutation"
else
  fail "cancel: silent + frontmatter mutation" "stdout=$co"
fi

# Revise (P03 pass-through).
p3=$(new_proposal "$tmp/d3" "Add a status caching layer for five seconds.")
ro=$(bash "$GATE" --proposal "$p3" --verb revise --axis scope_tier --value C)
if echo "$ro" | grep -q '^revision_pending=true axis=scope_tier value=C$' && grep -q '^pending_approval: true' "$p3"; then
  pass "revise: emits revision_pending + leaves frontmatter untouched"
else
  fail "revise: emits revision_pending + leaves frontmatter untouched" "stdout=$ro"
fi

# Unsupported axis.
if bash "$GATE" --proposal "$p3" --verb revise --axis frobnicate --value X >/dev/null 2>&1; then
  fail "unsupported axis rejection" "exited 0"
else
  pass "unsupported axis rejection"
fi

# Unknown verb.
if bash "$GATE" --proposal "$p3" --verb yolo >/dev/null 2>&1; then
  fail "unknown verb rejection" "exited 0"
else
  pass "unknown verb rejection"
fi

n=0
while [ $n -lt $i ]; do
  eval "echo \"\$NAMES_$n\""
  n=$((n+1))
done

echo "----- test-approval-gate.sh: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
```

### `scripts/verify/m024-p03-evaluate-md.sh`

Asserts the new "Input Shapes" section exists and covers all five shapes.

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p03-evaluate-md.sh
# Verifies commands/evaluate.md ships the "Input Shapes" section per P03.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$ROOT/commands/evaluate.md"

[ -f "$DOC" ] || { echo "FAIL: $DOC missing"; exit 1; }

grep -q '^## Input Shapes' "$DOC" || { echo "FAIL: $DOC missing '## Input Shapes' section"; exit 1; }

# All five shapes named in the section.
for shape in spec paragraph fragment idea empty; do
  if ! grep -q "\`$shape\`" "$DOC"; then
    echo "FAIL: $DOC does not name shape '$shape' in backticks"
    exit 1
  fi
done

# Back-references to P01 + P03 scripts.
for script in shape-detect.sh paragraph-classify.sh approval-gate.sh route-to-specify.sh route-to-dispatch.sh; do
  if ! grep -q "$script" "$DOC"; then
    echo "FAIL: $DOC does not back-reference $script"
    exit 1
  fi
done

# Legacy spec discovery section preserved (FR-6 byte-compat marker).
grep -q '^## Spec Discovery' "$DOC" || grep -q '^### 2. Spec Discovery' "$DOC" || {
  echo "FAIL: $DOC removed legacy Spec Discovery section (FR-6 violation)"
  exit 1
}

echo "PASS: evaluate.md — Input Shapes section + all five shapes + back-references + legacy preserved"
exit 0
```

### `scripts/verify/m024-p03-write-confinement.sh`

Asserts P03 scripts only write to `.orchestrator/intake/` or `/tmp`.

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p03-write-confinement.sh
# Asserts P03-introduced scripts write only under .orchestrator/intake or /tmp (SB-3).

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

ALLOWED="\\.orchestrator/intake|/tmp|mktemp|\\\${PROPOSAL}|\\\$PROPOSAL|\\\$out_path|\\\$out_dir|\\\$INTAKE_ROOT|\\\$INTAKE_DIR|\\\$proposal"

violations=""
for f in \
  "$ROOT/scripts/intake/paragraph-classify.sh" \
  "$ROOT/scripts/intake/approval-gate.sh" \
  "$ROOT/scripts/intake/route-to-specify.sh" \
  "$ROOT/scripts/intake/route-to-dispatch.sh"; do
  [ -f "$f" ] || continue
  hits=$(grep -nE 'mkdir |^[^#]*>[^&]' "$f" | grep -vE "$ALLOWED" | grep -vE '^[[:space:]]*#' || true)
  if [ -n "$hits" ]; then
    violations="$violations
$f:
$hits"
  fi
done

if [ -n "$violations" ]; then
  echo "FAIL: write-confinement violations:$violations"
  exit 1
fi

echo "PASS: P03 scripts write only under .orchestrator/intake or /tmp"
exit 0
```

### `scripts/verify/m024-p03-suite.sh`

Bundles the two phase tests + every per-task verify.

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p03-suite.sh
# P03 suite — paragraph + approval-gate + routes + evaluate.md + write-confinement.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

run() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    "$@"
    return 1
  fi
}

rc=0
run "test-paragraph-intake.sh"          bash "$ROOT/tests/test-paragraph-intake.sh"          || rc=1
run "test-approval-gate.sh"             bash "$ROOT/tests/test-approval-gate.sh"             || rc=1
run "m024-p03-paragraph-classify"       bash "$ROOT/scripts/verify/m024-p03-paragraph-classify.sh"       || rc=1
run "m024-p03-approval-gate"            bash "$ROOT/scripts/verify/m024-p03-approval-gate.sh"            || rc=1
run "m024-p03-approval-gate-verbs"      bash "$ROOT/scripts/verify/m024-p03-approval-gate-verbs.sh"      || rc=1
run "m024-p03-route-to-specify"         bash "$ROOT/scripts/verify/m024-p03-route-to-specify.sh"         || rc=1
run "m024-p03-route-to-dispatch"        bash "$ROOT/scripts/verify/m024-p03-route-to-dispatch.sh"        || rc=1
run "m024-p03-evaluate-md"              bash "$ROOT/scripts/verify/m024-p03-evaluate-md.sh"              || rc=1
run "m024-p03-write-confinement"        bash "$ROOT/scripts/verify/m024-p03-write-confinement.sh"        || rc=1

if [ $rc -eq 0 ]; then
  echo "PASS: M024/P03 suite — paragraph + approval-gate + route + evaluate-md"
fi
exit $rc
```

## Steps

1. **Edit `commands/evaluate.md`** — insert the "Input Shapes" section (block above) immediately after the `# orchestrator:evaluate` title block and before the existing `## Prerequisites` block. Do not edit any existing text in `## Prerequisites`, `## Scope Analysis`, `## Tier Classification`, or any later section — FR-6 byte-compat invariant.

2. **Create `tests/test-paragraph-intake.sh`** with the content above; `chmod +x tests/test-paragraph-intake.sh`.

3. **Create `tests/test-approval-gate.sh`** with the content above; `chmod +x tests/test-approval-gate.sh`.

4. **Create `scripts/verify/m024-p03-evaluate-md.sh`** with the content above; `chmod +x scripts/verify/m024-p03-evaluate-md.sh`.

5. **Create `scripts/verify/m024-p03-write-confinement.sh`** with the content above; `chmod +x scripts/verify/m024-p03-write-confinement.sh`.

6. **Create `scripts/verify/m024-p03-suite.sh`** with the content above; `chmod +x scripts/verify/m024-p03-suite.sh`.

## Must-Haves

- `commands/evaluate.md` ships the new `## Input Shapes` section naming all five shapes in backticks and back-referencing the P01 + P03 scripts (`shape-detect.sh`, `paragraph-classify.sh`, `approval-gate.sh`, `route-to-specify.sh`, `route-to-dispatch.sh`).
- The legacy `Spec Discovery` section is preserved verbatim (FR-6 byte-compat invariant).
- `tests/test-paragraph-intake.sh` exercises Tier A / B / C paragraph end-to-end (emit → axes → approve → route) and exits 0.
- `tests/test-approval-gate.sh` exercises the verb matrix (approve, cancel, revise, idempotency-guard, unsupported axis, unknown verb) and exits 0.
- `scripts/verify/m024-p03-suite.sh` runs every P03 phase test + per-task verify and emits `PASS: M024/P03 suite — paragraph + approval-gate + route + evaluate-md` when all pass.
- `scripts/verify/m024-p03-write-confinement.sh` confirms no P03 script writes outside `.orchestrator/intake/` or `/tmp`.
- AD-19 harness shape: every external invocation in tests + verify scripts is single-script-file form.

## Verification

```
bash scripts/verify/m024-p03-suite.sh
```

Expected output (exit 0): `PASS: M024/P03 suite — paragraph + approval-gate + route + evaluate-md`

## Inputs

### From Previous Tasks

- `scripts/intake/proposal-emit.sh` (from M024/P01/T04 + M024/P03/T01) — invoked by both phase tests. Key API: `bash proposal-emit.sh --input <s> [--intake-root <d>]` → `proposal_path=<absolute path>`.
- `scripts/intake/paragraph-classify.sh` (from M024/P03/T01) — exercised indirectly via the emitter.
- `scripts/intake/approval-gate.sh` (from M024/P03/T02) — exercised by `test-approval-gate.sh` and indirectly by `test-paragraph-intake.sh`. Key API: `bash approval-gate.sh --proposal <path> --verb <approve|cancel|revise> [--axis <a> --value <v>]` → emits `recommended_command_invoke=<value>` (approve), no stdout (cancel), or `revision_pending=true axis=<a> value=<v>` (revise).
- `scripts/intake/route-to-specify.sh` (from M024/P03/T03) — invoked by `test-paragraph-intake.sh` on Tier B path. Emits `invoke=orchestrator:specify --input-from <path>`.
- `scripts/intake/route-to-dispatch.sh` (from M024/P03/T03) — invoked by `test-paragraph-intake.sh` on Tier A path. Emits `invoke=orchestrator:dispatch --proposal <path>`.

### From Disk (Pre-existing)

- `commands/evaluate.md` (from before M024) — modified by this task; the "Input Shapes" section is inserted before the existing `## Prerequisites` block.
- `commands/specify.md` (from M014/extended) — read-only consumer; back-referenced by the route-to-specify path.
- `scripts/intake/shape-detect.sh` (from M024/P01/T03) — read-only consumer; back-referenced by the new "Input Shapes" section.
- `templates/intake-proposal.md` (from M024/P01/T01) — read-only consumer; defines the frontmatter keys the tests grep for.
- `grep`, `sed -n`, `mktemp`, `date -u` — POSIX utilities.

## Constraints

- POSIX sh + bash 3.2 portable. MEM002 test conventions: parallel indexed arrays for pass/fail tracking, structured `PASS:`/`FAIL:` lines, summary count at end.
- The `commands/evaluate.md` edit MUST NOT modify any existing prose under `## Prerequisites`, `## Scope Analysis`, `## Tier Classification`, or later sections — FR-6 byte-compat invariant. Insert the new section above `## Prerequisites` only.
- AD-19 single-script-file shape: every command in the tests + verify scripts is a top-level invocation; no inline compound bash, no plain subshells, no `$(... | ...)` containing pipes.
- Verification block authoring convention (per P01 lesson): the fenced block under `## Verification` contains ONLY runnable commands. Expected output goes in inline backticks below the fenced block, NOT in a second fenced block.
- The suite script propagates per-test failure but always runs the full test list (it does not bail on the first failure) so the operator sees the full pass/fail surface.
- No conversus invocations, no knowledge writes (NG-2, NG-5).

## Expected Output

`commands/evaluate.md` ships the "Input Shapes" section (legacy preserved); `tests/test-paragraph-intake.sh`, `tests/test-approval-gate.sh`, `scripts/verify/m024-p03-evaluate-md.sh`, `scripts/verify/m024-p03-write-confinement.sh`, and `scripts/verify/m024-p03-suite.sh` all exist and are executable; the suite script exits 0 with `PASS: M024/P03 suite — paragraph + approval-gate + route + evaluate-md`.

## State Context

- **Current State**: executing
- **Milestone**: M024
- **Phase**: P03
- **Task**: T04
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- POSIX sh + bash 3.2 portable. MEM002 test conventions: parallel indexed arrays for pass/fail tracking, structured `PASS:`/`FAIL:` lines, summary count at end.
- The `commands/evaluate.md` edit MUST NOT modify any existing prose under `## Prerequisites`, `## Scope Analysis`, `## Tier Classification`, or later sections — FR-6 byte-compat invariant. Insert the new section above `## Prerequisites` only.
- AD-19 single-script-file shape: every command in the tests + verify scripts is a top-level invocation; no inline compound bash, no plain subshells, no `$(... | ...)` containing pipes.
- Verification block authoring convention (per P01 lesson): the fenced block under `## Verification` contains ONLY runnable commands. Expected output goes in inline backticks below the fenced block, NOT in a second fenced block.
- The suite script propagates per-test failure but always runs the full test list (it does not bail on the first failure) so the operator sees the full pass/fail surface.
- No conversus invocations, no knowledge writes (NG-2, NG-5).

### Acceptance Criteria

- `commands/evaluate.md` ships the new `## Input Shapes` section naming all five shapes in backticks and back-referencing the P01 + P03 scripts (`shape-detect.sh`, `paragraph-classify.sh`, `approval-gate.sh`, `route-to-specify.sh`, `route-to-dispatch.sh`).
- The legacy `Spec Discovery` section is preserved verbatim (FR-6 byte-compat invariant).
- `tests/test-paragraph-intake.sh` exercises Tier A / B / C paragraph end-to-end (emit → axes → approve → route) and exits 0.
- `tests/test-approval-gate.sh` exercises the verb matrix (approve, cancel, revise, idempotency-guard, unsupported axis, unknown verb) and exits 0.
- `scripts/verify/m024-p03-suite.sh` runs every P03 phase test + per-task verify and emits `PASS: M024/P03 suite — paragraph + approval-gate + route + evaluate-md` when all pass.
- `scripts/verify/m024-p03-write-confinement.sh` confirms no P03 script writes outside `.orchestrator/intake/` or `/tmp`.
- AD-19 harness shape: every external invocation in tests + verify scripts is single-script-file form.

### Files To Touch

- scripts/intake/paragraph-classify.sh (create)
- scripts/intake/proposal-emit.sh (modify — wire classifier on paragraph branch)
- scripts/intake/approval-gate.sh (create)
- scripts/intake/route-to-specify.sh (create)
- scripts/intake/route-to-dispatch.sh (create)
- commands/evaluate.md (modify — add "Input Shapes" section)
- tests/test-paragraph-intake.sh (create)
- tests/test-approval-gate.sh (create)
- scripts/verify/m024-p03-paragraph-classify.sh (create)
- scripts/verify/m024-p03-approval-gate.sh (create)
- scripts/verify/m024-p03-approval-gate-verbs.sh (create)
- scripts/verify/m024-p03-route-to-specify.sh (create)
- scripts/verify/m024-p03-route-to-dispatch.sh (create)
- scripts/verify/m024-p03-evaluate-md.sh (create)
- scripts/verify/m024-p03-write-confinement.sh (create)
- scripts/verify/m024-p03-suite.sh (create)

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