---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T02 (Phase P02, Milestone M026)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (28 entries) | 20-707 | ~7000 | filtered |
| Decisions | 709-711 | ~100 | filtered |
| Constraints | 713-746 | ~400 | required |
| Scope | 748-776 | ~800 | required |
| Upstream Context | 778-780 | ~100 | required |
| Task Plan | 782-895 | ~2300 | required |
| State Context | 897-903 | ~100 | required |
| First-Turn Completeness | 905-939 | ~500 | required |
| **Total** | | **~11300** | |

## Knowledge

<!-- 28 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 408
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
hit_count: 408
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
hit_count: 408
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
hit_count: 408
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
hit_count: 358
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
hit_count: 358
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
hit_count: 358
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
hit_count: 408
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
hit_count: 358
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
hit_count: 358
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
hit_count: 358
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
hit_count: 408
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
hit_count: 408
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
hit_count: 408
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
hit_count: 358
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
hit_count: 358
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
hit_count: 358
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
hit_count: 408
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
hit_count: 358
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
hit_count: 358
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
hit_count: 408
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
hit_count: 408
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
hit_count: 358
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
hit_count: 358
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
hit_count: 358
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
hit_count: 13
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
hit_count: 13
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
hit_count: 13
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

## Scope

### Goal


### Demo


### Must-Haves
## Must-Haves

<!-- Every Check uses single-script-file shape per AD-19. All verification
     logic lives in scripts/verify/m026-p02-*.sh. Adapter changes preserve
     CON-1..CON-5; CON-5 read-only-on-conversus-trees still applies
     (no writes to ~/Sites/conversus* trees). -->

### Truths

- `scripts/dispatch/adapters/tool/conversus.sh` emits an `edition=<oss|paid|unknown>` line and a `reason=<env-override|metadata-probe|fallback|path|home|stub|command-v>` line on `check` stdout in addition to the existing `available=` and `conversus_path=` lines (FR-1/FR-3). When `CONVERSUS_EDITION=oss|paid` is set, the edition line matches the env-var value with `reason=env-override`. When unset and the `conversus` pipx venv's `pip show conversus` `Home-page:` contains `conversus-oss`, the edition line is `oss` with `reason=metadata-probe`. When the binary is resolved via `CONVERSUS_STUB`, `CONVERSUS_HOME`, or `command -v`, `reason` matches the resolution path and `edition=unknown` unless the venv metadata can still be probed.
  - Check: `bash scripts/verify/m026-p02-edition-detection-contract.sh`

- `scripts/dispatch/adapters/tool/conversus.sh` preserves the 0/1/2 exit-code contract, the full env-var set (`CONVERSUS_STUB`, `CONVERSUS_STUB_VERDICT`, `CONVERSUS_HOME`, `CONVERSUS_STRICT`, `CONVERSUS_PROVIDER`, `CONVERSUS_RUN_OUTPUT_DIR`, `CONVERSUS_GATE_TODO_THRESHOLD`, `CONVERSUS_GATE_SKIP_TODO_CHECK`, `CONVERSUS_INTEGRATION`), the D019 TODO pre-flight block, the stub-mode fixture paths, the `gate-result.md` frontmatter key-set (`verdict`, `disputes`, `rationale`, `source_hash`, `preset`, `artifact`, `conversus_output_dir`, `conversus_config`), and the filename-routed adapter auto-discovery pattern (MEM008/MEM018). No Bash 3.2 regressions introduced (no `declare -A`, no `mapfile`/`readarray`, no process substitution). Satisfies CON-1..CON-3.
  - Check: `bash scripts/verify/m026-p02-adapter-invariants.sh`

- `scripts/integrations/github-common.sh::emit_conversus_gate_record` and the inline JSONL emission at `scripts/specify/specify.sh` line 533 include an `"edition"` field immediately adjacent to `"adapter_version"` in every `conversus_gate_invocation` record (FR-4). The field value is populated from the adapter's resolver output and takes one of `oss`, `paid`, `unknown` (never empty, never missing). Pre-existing JSONL readers (M019 Tier 1) are unaffected — the addition is purely additive per AD-4.
  - Check: `bash scripts/verify/m026-p02-jsonl-edition-field.sh`

- `tests/test-conversus-adapter-shim.sh` gains a `CONVERSUS_INTEGRATION=1`-gated dual-edition block that exercises both editions when both are installed. Under current operator state (OSS installed, paid uninstalled per OLLAMA-PROBE.md), the OSS-Anthropic branch emits `SKIP: known-upstream-429 (OSS lacks PR #29)` and the paid branch emits `SKIP: paid build not installed`. Both SKIPs are visible-skip (annotated), not silent-skip, and do not cause the test to fail. The stub-mode path (existing sections 1, 1b, 2) remains untouched.
  - Check: `bash scripts/verify/m026-p02-dual-edition-test-shape.sh`

<dispatch-volatile>

## Upstream Context

No upstream summaries available.

## Task Plan

---
schema_version: "1.0"
task: "T02"
phase: "P02"
milestone: "M026"
name: "JSONL edition field on conversus_gate_invocation records (FR-4 / AD-4)"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `_resolve_edition` helper is available in `scripts/dispatch/adapters/tool/conversus.sh`, and `check` stdout contains `edition=<oss|paid|unknown>` plus `reason=<...>` lines.
- `scripts/integrations/github-common.sh::emit_conversus_gate_record` exists at lines 924-942 (as of post-M026/P01 state). It is a thin wrapper around `emit_tier1_record` for the `conversus_gate_invocation` record type.
- Inline JSONL emission exists at `scripts/specify/specify.sh` line 533 as a hand-rolled JSON string with fields: `type`, `ts`, `gate_id`, `spec_path`, `verdict`, `adapter_version`, `llm_calls`, `elapsed_ms`, `estimated_cost_usd`, `source`.

## Description

Add an `"edition"` field (value: `oss` | `paid` | `unknown`) to every `conversus_gate_invocation` JSONL record, populated from the adapter's resolver. The field is placed immediately adjacent to `adapter_version` per AD-4's provenance-cluster guidance.

Two emission sites:

1. **`scripts/integrations/github-common.sh::emit_conversus_gate_record`** (library wrapper, used by `github-sync.sh` and `github-conversus-gate.sh`). Extend the function signature to accept a 6th positional argument `edition`, propagate it into `emit_tier1_record` as a named field. Callers update to pass the adapter-resolver's edition output. If a caller does not pass the argument (backward compatibility), default to `unknown` and emit the record rather than fail.
2. **`scripts/specify/specify.sh:533`** (inline emission). Extend the REC_G JSON string literal to include `"edition":"${EDITION}"` adjacent to `"adapter_version":"m011-p07"`. Set `EDITION` from the adapter's `check` output immediately before the gate invocation.

JSONL is additive-tolerant per AD-4: existing readers (M019 Tier 1) ignore unknown fields, so adding `edition` is non-breaking.

## Steps

1. **Modify `scripts/integrations/github-common.sh`** (lines 922-942):
   - Extend `emit_conversus_gate_record` signature to accept a 6th positional argument: `local edition="${6:-unknown}"`.
   - Add `"edition=${edition}"` to the `emit_tier1_record` argument list, positioned **after** the `verdict=` field and before `rc=` so the serialized JSON places `edition` near `adapter_version` (note: `emit_tier1_record`'s field ordering is determined by argument order — verify by reading `emit_tier1_record`'s implementation earlier in the same file; if it preserves argument order in the output JSON, this achieves the AD-4 placement; if it sorts alphabetically, no placement control is possible but correctness is unaffected).
   - Update the inline `# emit_conversus_gate_record <issue-ref> <timeout-sec> <verdict> <rc> <duration-ms>` comment (line 924) to add `<edition>` as the 6th positional.
   - Update the Public-functions listing at the self-check footer (lines 947-957) only if the signature string is enumerated there — do not add new functions; the signature change is invisible to a caller-count summary.
2. **Find all callers** of `emit_conversus_gate_record` and update to pass `edition`:
   ```
   grep -rn "emit_conversus_gate_record" scripts/ tests/ 2>/dev/null
   ```
   Expected call sites: `scripts/integrations/github-sync.sh`, `scripts/integrations/github-conversus-gate.sh` (both are likely candidates per the header comment at line 927-928). At each call site, run `bash scripts/dispatch/adapters/tool/conversus.sh check` immediately before or reuse a cached capture, grep for `edition=` → extract value → pass as the 6th argument. Example pattern:
   ```sh
   _check_out="$(bash "${REPO_ROOT}/scripts/dispatch/adapters/tool/conversus.sh" check)"
   _edition="$(printf '%s\n' "$_check_out" | grep -E '^edition=' | head -n 1 | sed -E 's/^edition=//')"
   : "${_edition:=unknown}"
   emit_conversus_gate_record "$ref" "$to" "$verdict" "$rc" "$dur" "$_edition"
   ```
3. **Modify `scripts/specify/specify.sh`** around lines 508-536 (the conversus-gate block that emits the REC_G JSONL record):
   - Immediately after the adapter invocation (before line 533) and before emitting the record, capture the adapter's edition:
     ```sh
     EDITION="$(bash "$_REPO_ROOT/scripts/dispatch/adapters/tool/conversus.sh" check 2>/dev/null | grep -E '^edition=' | head -n 1 | sed -E 's/^edition=//')"
     : "${EDITION:=unknown}"
     ```
     If `_REPO_ROOT` is not in scope, use the existing path-resolution convention elsewhere in `specify.sh` (grep for `dispatch/adapters/tool/conversus.sh` in the file to find how it's referenced).
   - Update the REC_G JSON literal to:
     ```sh
     REC_G="{\"type\":\"conversus_gate_invocation\",\"ts\":\"${TS_G}\",\"gate_id\":\"spec-pressure-test\",\"spec_path\":\"${SPEC_PATH}\",\"verdict\":\"${V}\",\"adapter_version\":\"m011-p07\",\"edition\":\"${EDITION}\",\"llm_calls\":0,\"elapsed_ms\":${G_MS},\"estimated_cost_usd\":0.0,\"source\":\"runtime\"}"
     ```
     `edition` is inserted immediately after `adapter_version` per AD-4.
4. **Write `scripts/verify/m026-p02-jsonl-edition-field.sh`** (single-script-file shape, AD-19 compliant, Bash 3.2 compatible). Must verify:
   - `scripts/integrations/github-common.sh` contains the updated `emit_conversus_gate_record` signature — grep for `local edition=` inside the function body.
   - The function body calls `emit_tier1_record` with an `edition=` positional argument — grep for `"edition=\${edition}"`.
   - `scripts/specify/specify.sh` contains `"edition":"${EDITION}"` in the REC_G literal (grep for the exact `\"edition\":\"` substring).
   - `scripts/specify/specify.sh` has an `EDITION=` capture line before the REC_G emit (grep `EDITION=.*conversus\.sh check`).
   - Fire a dry-run emission via stub-mode: invoke `emit_conversus_gate_record` in a subshell with `CONVERSUS_STUB=1`, redirect `execution-log.jsonl` to a temp file via `ORCHESTRATOR_ROOT`, grep the emitted line for `"edition"`. Exact mechanics are extracted into the helper script `scripts/verify/m026-p02-jsonl-edition-field.sh` — no compound bash at the Check site.

## Must-Haves

Addresses phase must-haves:
- "Truth: JSONL emission sites include `\"edition\"` field adjacent to `\"adapter_version\"`" (T02 owns)
- Artifact: `scripts/verify/m026-p02-jsonl-edition-field.sh`

## Verification

```
bash scripts/verify/m026-p02-jsonl-edition-field.sh
```

Must exit 0 and print `PASS: m026-p02-jsonl-edition-field.sh`.

Additionally, T01's adapter-invariant verifier must still pass (no regression introduced by the JSONL wiring):

```
bash scripts/verify/m026-p02-adapter-invariants.sh
```

## Inputs

### From Previous Tasks

- `scripts/dispatch/adapters/tool/conversus.sh` (from T01)
  - Key API: `check` subcommand stdout now includes `edition=<oss|paid|unknown>` and `reason=<...>` lines in addition to `available=` and `conversus_path=`.
  - Key behavior: `_resolve_edition` is called automatically by `_resolve_binary` in all branches; callers need only parse `check` stdout for `edition=`.

### From Disk (Pre-existing)

- `scripts/integrations/github-common.sh` — target for the `emit_conversus_gate_record` signature extension. Key existing symbols: `emit_tier1_record` (used by the function), `ORCHESTRATOR_ROOT` (state-root resolution), `conversus_gate_invocation` (record type name).
- `scripts/specify/specify.sh` — target for inline REC_G extension. Surrounding context: the block at lines 508-536 is the conversus-gate `y-path` branch; the record is appended to `${STATE_ROOT}/.orchestrator/execution-log.jsonl`.

## Constraints

- **AD-4** (JSONL placement): `edition` immediately adjacent to `adapter_version`.
- **CON-1** (adapter invariants): unchanged — this task does not modify `conversus.sh`.
- **CON-2** (Bash 3.2): no `declare -A`, no process substitution, no command substitution containing pipes in the shell logic added to `github-common.sh` / `specify.sh`.
- **Backward compatibility**: `emit_conversus_gate_record` continues to emit a record when the 6th argument is omitted (falls back to `edition=unknown`). No caller-breakage.
- **Additive tolerance** (AD-4): the new `edition` field is additive in the JSONL record. Downstream consumers (M019 Tier 1 rollup at `scripts/engine/observability/emit-tier1.sh` or equivalent) are unaffected because JSONL schema is open-world.
- **Stderr discipline** (DC-5): the `bash conversus.sh check` invocation captures stdout only; stderr is dropped via `2>/dev/null` so adapter diagnostics don't contaminate the JSON literal.

## Expected Output

- `scripts/integrations/github-common.sh` — modified: `emit_conversus_gate_record` takes a 6th positional arg, default `unknown`, propagated to `emit_tier1_record`. Line count delta ≤ +10.
- `scripts/specify/specify.sh` — modified: `EDITION=` capture added before line 533 emit, REC_G literal extended with `"edition":"${EDITION}"` adjacent to `"adapter_version":"m011-p07"`. Line count delta ≤ +5.
- One or two additional call-site updates in `scripts/integrations/github-sync.sh` / `scripts/integrations/github-conversus-gate.sh` if they exist and call `emit_conversus_gate_record`.
- `scripts/verify/m026-p02-jsonl-edition-field.sh` — created (~40-60 lines).
- All exits 0 per Verification section.

## State Context

- **Current State**: executing
- **Milestone**: M026
- **Phase**: P02
- **Task**: T02
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **AD-4** (JSONL placement): `edition` immediately adjacent to `adapter_version`.
- **CON-1** (adapter invariants): unchanged — this task does not modify `conversus.sh`.
- **CON-2** (Bash 3.2): no `declare -A`, no process substitution, no command substitution containing pipes in the shell logic added to `github-common.sh` / `specify.sh`.
- **Backward compatibility**: `emit_conversus_gate_record` continues to emit a record when the 6th argument is omitted (falls back to `edition=unknown`). No caller-breakage.
- **Additive tolerance** (AD-4): the new `edition` field is additive in the JSONL record. Downstream consumers (M019 Tier 1 rollup at `scripts/engine/observability/emit-tier1.sh` or equivalent) are unaffected because JSONL schema is open-world.
- **Stderr discipline** (DC-5): the `bash conversus.sh check` invocation captures stdout only; stderr is dropped via `2>/dev/null` so adapter diagnostics don't contaminate the JSON literal.

### Acceptance Criteria

Addresses phase must-haves:
- "Truth: JSONL emission sites include `\"edition\"` field adjacent to `\"adapter_version\"`" (T02 owns)
- Artifact: `scripts/verify/m026-p02-jsonl-edition-field.sh`

### Files To Touch

- `scripts/dispatch/adapters/tool/conversus.sh` (modify — T01, T04)
- `scripts/integrations/github-common.sh` (modify — T02)
- `scripts/specify/specify.sh` (modify — T02)
- `tests/test-conversus-adapter-shim.sh` (modify — T03)
- `scripts/verify/m026-p02-edition-detection-contract.sh` (create — T01)
- `scripts/verify/m026-p02-adapter-invariants.sh` (create — T01)
- `scripts/verify/m026-p02-jsonl-edition-field.sh` (create — T02)
- `scripts/verify/m026-p02-dual-edition-test-shape.sh` (create — T03)
- `scripts/verify/m026-p02-gate-verdict-reliability.sh` (create — T04)
- `scripts/verify/m026-p02-recent-changes.sh` (create — T05)
- `scripts/verify/m026-p02-phase-suite.sh` (create — T05)
- `CLAUDE.md` (modify — T05 via dual-write helper)
- `AGENTS.md` (modify — T05 via dual-write helper)

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