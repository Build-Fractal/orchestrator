---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T04 (Phase P02, Milestone M026)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (28 entries) | 20-707 | ~7000 | filtered |
| Decisions | 709-711 | ~100 | filtered |
| Constraints | 713-746 | ~400 | required |
| Scope | 748-776 | ~800 | required |
| Upstream Context | 778-780 | ~100 | required |
| Task Plan | 782-944 | ~3400 | required |
| State Context | 946-952 | ~100 | required |
| First-Turn Completeness | 954-989 | ~600 | required |
| **Total** | | **~12500** | |

## Knowledge

<!-- 28 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 410
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
hit_count: 410
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
hit_count: 410
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
hit_count: 410
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
hit_count: 360
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
hit_count: 360
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
hit_count: 360
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
hit_count: 410
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
hit_count: 360
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
hit_count: 360
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
hit_count: 360
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
hit_count: 410
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
hit_count: 410
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
hit_count: 410
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
hit_count: 360
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
hit_count: 360
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
hit_count: 360
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
hit_count: 410
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
hit_count: 360
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
hit_count: 360
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
hit_count: 410
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
hit_count: 410
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
hit_count: 360
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
hit_count: 360
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
hit_count: 360
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
hit_count: 15
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
hit_count: 15
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
hit_count: 15
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
task: "T04"
phase: "P02"
milestone: "M026"
name: "Gate-verdict reliability bundle — POST-P01-FINDINGS F1 complete + F2 + F3; closes OQ-16"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- T01 complete: `_resolve_edition` + `_resolve_binary` updates are live in `scripts/dispatch/adapters/tool/conversus.sh`.
- T02 complete: JSONL emitters include `edition`.
- T03 complete: dual-edition test covers SC-4 / SC-6.
- **POST-P01-FINDINGS.md** (`.orchestrator/milestones/M026/phases/P01/POST-P01-FINDINGS.md`) is authoritative for F1/F2/F3 scope. Read it in full before starting — this task closes findings F1, F2, and F3 together.
- **Post-verify commit `32ab6ea`** already made a partial F1 fix: rationale is synthesized from `verdict + surviving_disputes + mode` rather than copying the linter's misleading `summary` string. This task completes F1 by preferring the arbiter/synthesis **verdict-text** extraction when available, falling back to the 32ab6ea synthesized formula when not.
- **DOGFOOD-SMOKE-OSS.md §6** (`.orchestrator/milestones/M026/phases/P01/DOGFOOD-SMOKE-OSS.md`) is the empirical grounding: false-PASS on `CONVERSUS_PROVIDER=claude-code` is reproducible on OSS (5-phase deliberation ran, prose synthesis output, parser returned 0 disputes, adapter reported PASS while the synthesis said BLOCK/8).
- **Spec 027 OQ-16** (`specs/027-conversus-oss-migration/spec.md`) documents the choice between upstream-fix / adapter-layer-fix / document-only. This task implements **option 2** (adapter-layer provider-aware verdict derivation) plus a subset of option 3 (documented fallback), not option 1 (upstream fix is out of M026 scope per CON-5).
- `references/architecture.md` "Conversus Adapter — Operator Notes" section exists (commit `32ab6ea`) and documents the CONVERSUS_PROVIDER=claude-code rule as operator discipline. F3 promotes that rule to an auto-preflight.

## Description

Three tightly-coupled adapter-layer changes that restore gate-verdict trustworthiness on the `CONVERSUS_PROVIDER=claude-code` path and improve gate-result readability across all provider paths.

### F1 (complete): Rationale extraction from verdict text

Current state post-`32ab6ea`: rationale is `verdict=<V> derived from surviving_disputes=<N> in <mode> deliberation`. That reads true but thin.

F1 target: when the synthesis file contains a `## Verdict` section (which the Risk Register format emits), extract its first paragraph (one line, newlines collapsed) and use that as the rationale. Fall back to the 32ab6ea formula when the section is absent or extraction yields an empty string.

### F2: Prefer `arbiter/resolution.md` when present

Current state: adapter reads only `${_run_output_dir}/summary/final.md` at line 301.

F2 target: if `${_run_output_dir}/arbiter/resolution.md` exists, prefer it as the verdict-text source for the F1 rationale extraction. Keep `summary/final.md` as the source for the structural fields the arbiter file doesn't emit (`headline`, the `quality_indicators.genuine_disagreements_surviving` count used by the existing `linter.output_contract` invocation). Schema: **prefer arbiter verdict-text, supplement with synthesis structural fields.**

### F3: Auto-preflight `CONVERSUS_PROVIDER=claude-code` under OAuth

Current state: the architecture.md "Conversus Adapter — Operator Notes" section tells operators to set `CONVERSUS_PROVIDER=claude-code` manually when authenticated via Anthropic OAuth. Forgetting costs ~90 minutes of 429 debugging (per POST-P01-FINDINGS F3).

F3 target: before the adapter resolves `_provider` at line ~288 in the `gate` subcommand, check if the operator is on OAuth auth. Detection: (a) `ANTHROPIC_API_KEY` is NOT exported in the environment AND (b) `~/.conversus/auth.json` exists with a record indicating subscription/OAuth auth. If both hold AND `CONVERSUS_PROVIDER` is unset, emit a single-line stderr warning and set `CONVERSUS_PROVIDER=claude-code` for the duration of this invocation. Honor the operator's explicit setting — if `CONVERSUS_PROVIDER` is already set to anything (including empty string explicitly), do not override.

Detection for `~/.conversus/auth.json` shape:
- If the file does not exist: treat as API-key mode (no action).
- If the file exists: read it as JSON if `python3` is available; look for a provider entry with keys like `oauth`, `subscription`, or `access_token` (exact schema inspection requires reading the OSS `engine/auth.py` at `~/Sites/conversus-oss/engine/auth.py` — CON-5 allows read-only). Heuristic fallback: `grep -q '"oauth"\|"subscription"\|access_token' ~/.conversus/auth.json` treats presence as OAuth. If `python3` is not available AND the grep fallback fails, do not auto-preflight (degrade gracefully; operator can still set the env var manually).

## Steps

1. **Read the OSS `engine/auth.py`** (read-only per CON-5) to confirm the auth.json record shape:
   ```
   head -120 ~/Sites/conversus-oss/engine/auth.py
   ```
   Identify the exact key (likely `auth_method`, `credential_type`, or a nested field) that distinguishes OAuth from API-key. Encode the discovered key into F3's detection. If the shape is ambiguous, fall back to the grep heuristic above.
2. **F1 + F2 in `scripts/dispatch/adapters/tool/conversus.sh`** (current rationale block at lines ~355-367):
   - Immediately before the existing `_mode_label="${_mode:-cooperative}"` / `_rationale="verdict=..."` block, attempt to extract a verdict-text rationale:
     ```sh
     _rationale_text=""
     # F2: prefer arbiter/resolution.md when present.
     _arbiter_file="${_run_output_dir}/arbiter/resolution.md"
     if [ -f "$_arbiter_file" ]; then
       _verdict_source="$_arbiter_file"
     else
       _verdict_source="$_synthesis"
     fi
     # F1 complete: extract first paragraph of the `## Verdict` section.
     # Uses awk to locate the section heading and print lines until the next
     # heading or blank line. Collapses newlines to spaces for frontmatter safety.
     _rationale_text="$(awk '
       /^## Verdict/ { capture=1; next }
       /^## / && capture { exit }
       capture && NF { out = out (out=="" ? "" : " ") $0 }
       END { print out }
     ' "$_verdict_source" 2>/dev/null)"
     # Trim and sanitize for YAML frontmatter (strip double-quotes, collapse whitespace).
     _rationale_text="$(printf '%s\n' "$_rationale_text" | sed -E 's/"/\x27/g; s/[[:space:]]+/ /g; s/^ *//; s/ *$//')"
     ```
   - Then update the existing rationale assignment to prefer the extracted text when non-empty:
     ```sh
     _mode_label="${_mode:-cooperative}"
     if [ -n "$_rationale_text" ]; then
       _rationale="$_rationale_text"
     else
       _rationale="verdict=${_verdict} derived from surviving_disputes=${_surviving} in ${_mode_label} deliberation"
     fi
     ```
   - Rename `awk` doesn't need the `-v` variant here because the pattern is regex-safe. If the file's existing style uses `awk` with `-v` for other patterns, match that style.
3. **F3 in `scripts/dispatch/adapters/tool/conversus.sh`** (current provider resolution at line ~288):
   - Add a preflight block immediately before `_provider="${CONVERSUS_PROVIDER:-anthropic}"`:
     ```sh
     # F3: auto-preflight CONVERSUS_PROVIDER=claude-code under Anthropic OAuth.
     # The default --provider anthropic path hits a server-side concurrency
     # policy gate on OAuth credentials (not a transient rate limit; retries
     # don't help). See references/architecture.md "Conversus Adapter —
     # Operator Notes". Operators who already set CONVERSUS_PROVIDER keep
     # their setting.
     if [ -z "${CONVERSUS_PROVIDER+set}" ] && [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -f "$HOME/.conversus/auth.json" ]; then
       if grep -qE '"(oauth|subscription|access_token)"' "$HOME/.conversus/auth.json" 2>/dev/null; then
         echo "note: detected Anthropic OAuth auth with no ANTHROPIC_API_KEY; auto-setting CONVERSUS_PROVIDER=claude-code (see references/architecture.md)" >&2
         CONVERSUS_PROVIDER=claude-code
         export CONVERSUS_PROVIDER
       fi
     fi
     _provider="${CONVERSUS_PROVIDER:-anthropic}"
     ```
   - The `[ -z "${CONVERSUS_PROVIDER+set}" ]` test distinguishes "unset" from "explicitly empty"; only unset triggers auto-preflight. Operators who want to override the heuristic can set `CONVERSUS_PROVIDER=anthropic` explicitly.
4. **Update the adapter header comment block** (around lines 35-49 where the provider-selection rule was documented in commit `32ab6ea`) to note the new auto-preflight behavior. One to three new lines, no restructuring.
5. **Write `scripts/verify/m026-p02-gate-verdict-reliability.sh`** (single-script-file shape, AD-19 compliant, Bash 3.2 compatible). Must verify:
   - **F1**: rationale block contains the awk-based `## Verdict` extractor and the fallback to the 32ab6ea synthesized formula (grep for the awk pattern and the fallback phrase).
   - **F1 smoke**: create a temp synthesis file with a `## Verdict` section containing a known paragraph, invoke the adapter in a mode that exercises the rationale block (stub mode doesn't — this path is real-mode only; either mock the structure via direct awk call in the verifier, or construct a minimal harness that drives the real rationale-extraction code path with a synthetic `_run_output_dir`).
   - **F2**: adapter references `arbiter/resolution.md` (grep the source literal).
   - **F2 smoke**: with both `arbiter/resolution.md` and `summary/final.md` written to a temp dir, the extracted rationale matches the arbiter file's `## Verdict` paragraph, not the synthesis's.
   - **F3**: preflight block is present and correctly-gated — grep for `CONVERSUS_PROVIDER+set`, `ANTHROPIC_API_KEY`, `.conversus/auth.json`, and the `claude-code` assignment.
   - **F3 smoke**: construct an isolated HOME with a mock `.conversus/auth.json` containing `"oauth": true` and no `ANTHROPIC_API_KEY`, invoke a read-only adapter path (e.g., `check` — not `gate`, which would attempt a real run). Assert the stderr `note:` line fires. With `ANTHROPIC_API_KEY=x` set, no preflight fires. With `CONVERSUS_PROVIDER=anthropic` explicitly set, no preflight fires regardless of other conditions.
   - Note: F3's auto-preflight is in the `gate` subcommand, not `check`. The smoke harness may need to invoke a minimal `gate` path; if that requires a binary the harness can't reach, reduce the F3 smoke to pattern-match-only on the source file and defer full integration to `tests/test-conversus-adapter-shim.sh` section 3 (out of scope for the verifier).

## Must-Haves

Addresses phase must-haves:
- "Truth: rationale resolved from verdict text with arbiter preference; auto-preflight on OAuth" (T04 owns)
- Artifact: `scripts/verify/m026-p02-gate-verdict-reliability.sh`

## Verification

```
bash scripts/verify/m026-p02-gate-verdict-reliability.sh
bash scripts/verify/m026-p02-adapter-invariants.sh
```

Both must exit 0. The invariants verifier must still pass — no regression introduced by F1/F2/F3.

## Inputs

### From Previous Tasks

- `scripts/dispatch/adapters/tool/conversus.sh` (from T01): edition-detection helpers available; header comment already documents `CONVERSUS_PROVIDER=claude-code` manual-set rule (will be updated to also reflect auto-preflight).

### From Disk (Pre-existing)

- `.orchestrator/milestones/M026/phases/P01/POST-P01-FINDINGS.md` — authoritative scope for F1/F2/F3.
- `.orchestrator/milestones/M026/phases/P01/DOGFOOD-SMOKE-OSS.md` §6 — empirical grounding for the false-PASS.
- `references/architecture.md` — the "Conversus Adapter — Operator Notes" section documents the rule that F3 automates.
- `~/.conversus/auth.json` — operator's auth state (read-only probe).
- `~/Sites/conversus-oss/engine/auth.py` — read-only reference for auth.json schema (CON-5 permits read).

## Constraints

- **CON-1** (adapter invariants): exit codes / frontmatter keys / env-var set unchanged. Only the *content* of `rationale:` and the *auto-selection* of `CONVERSUS_PROVIDER` change; both are shape-preserving.
- **CON-2** (Bash 3.2): awk + sed + grep only; no `declare -A`, no `mapfile`, no process substitution.
- **CON-5** (read-only-on-conversus-trees): the one-time inspection of `~/Sites/conversus-oss/engine/auth.py` is a read; no write.
- **Operator-override precedence**: an explicit `CONVERSUS_PROVIDER=<anything>` always wins. F3 only fires when the env var is unset (`[ -z "${CONVERSUS_PROVIDER+set}" ]`).
- **Graceful degradation**: if `~/.conversus/auth.json` is malformed or unreadable, F3 silently does nothing (no warning spam, no crash). The existing `CONVERSUS_PROVIDER=${CONVERSUS_PROVIDER:-anthropic}` default path still runs.
- **Stderr discipline** (DC-5): F3's `note:` line goes to stderr. F1/F2 produce no runtime output; they only shape the rationale written to `gate-result.md`.
- **AD-19** (single-script-file Check shape): verifier uses no inline compound bash.

## Expected Output

- `scripts/dispatch/adapters/tool/conversus.sh` — modified: F1 awk-extractor + F2 arbiter-preference (≤20 lines), F3 preflight block (≤12 lines), header comment updated (≤3 lines). Total delta ≤ +40 lines.
- `scripts/verify/m026-p02-gate-verdict-reliability.sh` — created (~80-120 lines, given the smoke-harness breadth).
- Rationale in `gate-result.md` now reads as the verdict text when the synthesis/arbiter file emits a `## Verdict` section; falls back cleanly otherwise.
- A `gate` invocation under OAuth (no `ANTHROPIC_API_KEY`, auth.json present with OAuth marker) auto-sets `CONVERSUS_PROVIDER=claude-code` and emits a single `note:` line to stderr.
- All exits 0 per Verification section.

## State Context

- **Current State**: executing
- **Milestone**: M026
- **Phase**: P02
- **Task**: T04
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **CON-1** (adapter invariants): exit codes / frontmatter keys / env-var set unchanged. Only the *content* of `rationale:` and the *auto-selection* of `CONVERSUS_PROVIDER` change; both are shape-preserving.
- **CON-2** (Bash 3.2): awk + sed + grep only; no `declare -A`, no `mapfile`, no process substitution.
- **CON-5** (read-only-on-conversus-trees): the one-time inspection of `~/Sites/conversus-oss/engine/auth.py` is a read; no write.
- **Operator-override precedence**: an explicit `CONVERSUS_PROVIDER=<anything>` always wins. F3 only fires when the env var is unset (`[ -z "${CONVERSUS_PROVIDER+set}" ]`).
- **Graceful degradation**: if `~/.conversus/auth.json` is malformed or unreadable, F3 silently does nothing (no warning spam, no crash). The existing `CONVERSUS_PROVIDER=${CONVERSUS_PROVIDER:-anthropic}` default path still runs.
- **Stderr discipline** (DC-5): F3's `note:` line goes to stderr. F1/F2 produce no runtime output; they only shape the rationale written to `gate-result.md`.
- **AD-19** (single-script-file Check shape): verifier uses no inline compound bash.

### Acceptance Criteria

Addresses phase must-haves:
- "Truth: rationale resolved from verdict text with arbiter preference; auto-preflight on OAuth" (T04 owns)
- Artifact: `scripts/verify/m026-p02-gate-verdict-reliability.sh`

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