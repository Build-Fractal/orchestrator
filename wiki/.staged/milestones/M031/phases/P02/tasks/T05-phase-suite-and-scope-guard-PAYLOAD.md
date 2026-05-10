---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T05-phase-suite-and-scope-guard (Phase P02, Milestone M031)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-978 | ~500 | required |
| Upstream Context | 980-1056 | ~3000 | required |
| Task Plan | 1058-1331 | ~4000 | required |
| State Context | 1333-1339 | ~100 | required |
| First-Turn Completeness | 1341-1397 | ~900 | required |
| **Total** | | **~19300** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 704
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
hit_count: 704
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
hit_count: 704
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
hit_count: 704
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
hit_count: 617
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
hit_count: 617
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
hit_count: 617
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
hit_count: 704
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
hit_count: 617
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
hit_count: 617
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
hit_count: 617
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
hit_count: 704
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
hit_count: 704
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
hit_count: 704
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
hit_count: 617
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
hit_count: 617
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
hit_count: 617
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
hit_count: 704
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
hit_count: 617
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
hit_count: 617
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
hit_count: 704
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
hit_count: 704
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
hit_count: 617
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
hit_count: 617
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
hit_count: 617
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
hit_count: 272
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
hit_count: 272
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
hit_count: 272
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
hit_count: 280
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
hit_count: 280
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
hit_count: 270
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
     Verifier scripts are co-authored alongside their corresponding
     artifact within the SAME task (plan-time discipline rule 2).
     Namespacing: `m031-p02-*` prefix avoids collision with [M030](../../../../../milestones/M030/index.md)'s
     existing `p02-*` verifiers in the shared tools/verify/ tree. -->

### Truths

- `scripts/intake/shape-detect.sh` and `scripts/intake/paragraph-classify.sh` accept the M024 input surface unchanged AND emit a fourth verdict value `tier_a_plus` (additive to the existing `idea | paragraph | fragment | spec | empty` enum, AD-2 / CON-3). The Tier A+ heuristic boundary is documented inline in each classifier's body and grounded by `tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md` per AD-16. Word-count and structural-marker heuristics for the existing four verdicts MUST stay byte-equal (no regression on M024 fixtures).
  - Check: `bash tools/verify/m031-p02-classifier-extension-shape.sh`

- `tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md` exists with at least one historical `.orchestrator/` JSONL `unit_close` record cited by `<milestone>/<phase>/<task>` provenance, plus the annotator's classification rationale for why the cited record is a Tier A+ candidate (AD-16). The file is normative — no Tier A+ verifier may pass without its existence.
  - Check: `bash tools/verify/m031-p02-fixture-provenance-shape.sh`

- `tests/m031-acceptance/fixtures/tier-a-plus-input.txt` exists with a 30–80 word feature-request fixture matching the Tier A+ heuristic (input the classifier classifies as `tier_a_plus` with high confidence). The fixture body is keyed to the `FIXTURE-PROVENANCE.md` rationale (a paraphrase of one of the cited historical records).
  - Check: `bash tools/verify/m031-p02-tier-a-plus-input-shape.sh`

<dispatch-volatile>

## Upstream Context


### P01 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M031"
milestone: "M031"
provides:
  - "build-context.sh new --profile and --meta-out flags (FR-2 + AD-11),direct-mode --task-plan/--out invocation,AD-11 5-key JSON sidecar,additive payload_breakdown JSONL fields,3 m031-p01 verifiers under tools/verify/,post-m031-emitter wrapper sibling-symmetric with pre-m031-stub,post-m031-baseline.jsonl frozen artifact (20 records under post-m031 path with non-zero knowledge_section_tokens),FR-4 single-line amendment to commands/dispatch.md:21 closing the AD-14 single-window,2 m031-p01 verifiers under tools/verify/ (post-baseline-jsonl-population + dispatch-md-reconciliation),SC-1/SC-2/SC-3/SC-15 acceptance tests under tests/m031-acceptance/ + 4 corresponding shape verifiers under tools/verify/m031-p01-test-*-shape.sh; all 4 verifiers exit 0 with pass>=6 fail=0; SC tests gate the schema commitments per AD-11/AD-13/AD-17/AD-18 against the T01 direct-mode build-context.sh emitter contract,m031-p01-phase-suite.sh aggregator (9 sub-gates straight-line AD-19); m031-p01-scope-guard.sh SC-12 block-list verifier"
requires:
  - "P00"
affects:
  - "P02,P03,P04"
key_files:
  - "scripts/dispatch/build-context.sh,tools/verify/m031-p01-build-context-profile-shape.sh,tools/verify/m031-p01-quick-no-skip-branch.sh,tools/verify/m031-p01-config-knobs-stable.sh,tests/m031-acceptance/fixtures/empirical-baseline/post-m031-emitter.sh,tests/m031-acceptance/fixtures/empirical-baseline/post-m031-baseline.jsonl,commands/dispatch.md,tools/verify/m031-p01-post-baseline-jsonl-population.sh,tools/verify/m031-p01-dispatch-md-reconciliation.sh,tests/m031-acceptance/test-quick-injects-knowledge.sh,tests/m031-acceptance/test-build-context-profile.sh,tests/m031-acceptance/test-compression-applies-to-quick.sh,tests/m031-acceptance/test-quick-budget-median.sh,tools/verify/m031-p01-test-quick-injects-knowledge-shape.sh,tools/verify/m031-p01-test-build-context-profile-shape.sh,tools/verify/m031-p01-test-compression-applies-to-quick-shape.sh,tools/verify/m031-p01-test-quick-budget-median-shape.sh,tools/verify/m031-p01-phase-suite.sh,tools/verify/m031-p01-scope-guard.sh"
key_decisions:
  - "AD-11 5-key sidecar schema landed verbatim,AD-14 single-window preserved (commands/dispatch.md untouched),AD-19 single-script Truth Check shape for all 3 verifiers,direct-mode bypasses milestone/phase/task derivation when --task-plan supplied,positional-mode meta-out emit wired into both planning branch and payload_breakdown emitter so AD-11 fires on every code path,token-estimator reuse via chars_to_tokens_quartile from scripts/lib/pricing.sh,AD-14 single-window order discipline obeyed (capture BEFORE FR-4 amendment),knowledge_section_tokens reported as sidecar total_tokens (Knowledge section dominates Quick payload size),temp payload + sidecar cleaned per-task (JSONL is the durable artifact),FR-4 replacement preserves intensity-table shape with single-line diff (Quick row only),verifier carries header guard against future polarity flip mirroring P00 inverted-polarity convention,SC tests gate schema commitments (CON-1 invariant slots) rather than runtime-firing values when T01 direct mode does not yet wire compression into the Quick path; matches the explicit proxy-substitution pattern the task plan documents for SC-15 (Note); SC-1 OR-clause empty-cache-hit branch satisfied by knowledge_section_tokens:0 record; T03 leaves T01 deliverables untouched per task-plan constraints,none (T04 is purely additive verifier authoring; no decision packets)"
patterns_established:
  - "additive flag-stacking on legacy positional CLIs,direct-mode short-circuit pattern,inverted-polarity verifier guarding CON-1 invariant,sidecar emission at two call sites for forked exit paths,post-stub sibling-symmetric emitter pattern (same JSONL schema as pre-stub except path + non-zero knowledge_section_tokens + compression flags from sidecar),direct-mode build-context driver pattern (bash build-context.sh --profile=quick --task-plan FIXTURE --out TMP --meta-out TMP),inverted-polarity verifier on prose surface (assert ABSENCE of Skip payload assembly with explicit header guard),FR-4 single-line table-row amendment via Edit (single-line diff discipline for SC-12 scope-guard),AD-14 capture-before-amend ordering as a normative step list (step 3 verification gates step 4 destructive edit),schema-commitment SC tests (gate field-presence + literal substring contracts; runtime-firing values gate when downstream tasks wire the surface);RESULT: SC-N pass envelope on SC tests vs SUMMARY: <verifier> pass=N fail=M envelope on shape verifiers (two distinct AD-19 conventions);proxy-substitution documented inline in file header (mirrors P00 SC-15 Note pattern);direct-mode-execution-log.jsonl pre/post line-count delta as freshness gate,P01 phase-suite mirrors P00 straight-line nine-gate aggregation pattern (AD-19); SC-12 scope-guard surfaces working-tree noise from cross-milestone hit_count touches"
drill_down_paths:
  - "[.orchestrator/milestones/M031/phases/P01/tasks/T01-build-context-profile-SUMMARY.md](../../../../../milestones/M031/phases/P01/tasks/T01-build-context-profile-SUMMARY.md), [.orchestrator/milestones/M031/phases/P01/tasks/T02-ad14-capture-and-fr4-SUMMARY.md](../../../../../milestones/M031/phases/P01/tasks/T02-ad14-capture-and-fr4-SUMMARY.md), [.orchestrator/milestones/M031/phases/P01/tasks/T03-acceptance-tests-SUMMARY.md](../../../../../milestones/M031/phases/P01/tasks/T03-acceptance-tests-SUMMARY.md), [.orchestrator/milestones/M031/phases/P01/tasks/T04-SUMMARY.md](../../../../../milestones/M031/phases/P01/tasks/T04-SUMMARY.md)"
duration: "270m"
verification_result: "pass"
completed_at: "2026-05-01T17:47:36Z"
observability_surfaces:
  - "none"
---

## What Was Built

P01 closes the **AD-14 single-capture window** for Quick-profile dispatch. Before P01, `commands/dispatch.md:21` carried a Quick skip-knowledge branch that bypassed `build-context.sh`; that branch is gone post-P01. The four-task ordering was load-bearing: T01 made `build-context.sh` Quick-aware (additive only, no caller change); T02 captured the post-M031 baseline with both code paths live, then amended `commands/dispatch.md`; T03 shipped the SC-1/SC-2/SC-3/SC-15 acceptance tests against the AD-15 corpus; T04 aggregated the 9-gate phase-suite and shipped the SC-12 scope-guard.

- **T01 (build-context-profile):** Additive `--profile=quick|standard|full`, `--task-plan`, `--out`, `--meta-out` flags on `scripts/dispatch/build-context.sh` (+271/-2). Direct-mode short-circuit bypasses milestone/phase/task derivation when `--task-plan` is supplied. AD-11 5-key JSON sidecar (`mem_count`, `total_tokens`, `profile`, `compression_applied`, `snip_applied`) emitted at both planning-branch and payload_breakdown call sites so AD-11 fires on every exit path. Quote one CON-1 invariant: every dispatch path emits one `payload_breakdown` JSONL record. `commands/dispatch.md` untouched in T01 — that's T02's job.
- **T02 (ad14-capture-and-fr4):** Authored `post-m031-emitter.sh` sibling-symmetric with `pre-m031-stub.sh`. Captured `post-m031-baseline.jsonl` (20 records, all `path:"post-m031"`, all non-zero `knowledge_section_tokens`) by running `empirical-baseline.sh --post-m031-emitter` while both code paths were still live. THEN amended `commands/dispatch.md:21` (single-line FR-4 diff: "Skip payload assembly" gone, "Quick profile" present). The order is normative — T02 step 3 verification gates step 4 destructive edit.
- **T03 (acceptance-tests):** Shipped 4 SC scripts (`test-quick-injects-knowledge.sh` SC-1, `test-build-context-profile.sh` SC-2/AD-13, `test-compression-applies-to-quick.sh` SC-3/AD-17, `test-quick-budget-median.sh` SC-15/AD-18) plus 4 corresponding shape verifiers under `tools/verify/m031-p01-test-*-shape.sh`. Schema-commitment gating chosen over runtime-firing checks because T01's direct-mode does not yet wire [M018](../../../../../milestones/M018/index.md) compression into the Quick path; the proxy substitution is documented inline in each SC file header per the P00 SC-15 Note pattern.
- **T04 (phase-suite-and-scope-guard):** `m031-p01-phase-suite.sh` aggregates the 9 P01 sub-gates straight-line (AD-19 compliant, mirrors P00 phase-suite pattern). `m031-p01-scope-guard.sh` enforces SC-12 block-list with a MEM `hit_count`-only carve-out (added during T04 remediation — orchestrator-emitted MEM hit_count drift on `knowledge/(conventions|lessons|patterns)/MEM*.md` is a dispatch side-effect, not a manual scope violation; the carve-out logic checks every changed line matches `^[+-]hit_count: [0-9]+$` before excluding).

Mid-phase remediation:
- **MEM hit_count carve-out** (T04) — scope-guard reported 31 false-positive block-list violations from cross-session `hit_count` drift. Carve-out added; verifier now reports `pass=33 fail=0 block_list_violations=0 mem_hitcount_carveouts=31`.
- **Phase-level key-link doc references** — `scripts/dispatch/build-context.sh` was missing literal-string references to `templates/orchestrator-config-default.yml` and `references/RUNTIME-ASSUMPTIONS.md` required by the phase plan's Key Links. Added a `# Key links (M031/P01):` comment block near the top of the script body.

## Key Decisions

- **AD-14 capture-before-amend ordering** is now a normative step-list pattern (T02 step 3 gates step 4). Future destructive surface modifications follow this template.
- **Direct-mode bypasses derivation** — when `--task-plan FIXTURE` is supplied, `build-context.sh` skips milestone/phase/task path resolution. This is the harness-driving shape that lets `empirical-baseline.sh` invoke build-context against arbitrary fixtures without standing up a milestone tree.
- **Schema-commitment SC tests** — when downstream surfaces don't yet emit runtime-firing values, SC tests gate on field/key presence + literal substring contracts and document the proxy substitution inline. Gate tightens automatically when downstream tasks wire the runtime path.
- **Two distinct envelope conventions** — `RESULT: SC-N pass` for acceptance tests, `SUMMARY: <verifier> pass=N fail=M` for shape verifiers. Both AD-19 compliant; downstream consumers can grep either.
- **MEM hit_count carve-out** as a documented exception class — scope-guards in future milestones with similar dispatch side-effects can adopt the same `^[+-]hit_count: [0-9]+$` line-content check.

## Patterns Established

- Additive flag-stacking on legacy positional CLIs (preserve all existing call sites; new flags trail).
- Direct-mode short-circuit pattern (one `if` branch at the top of the script that bypasses canonical resolution when a fixture flag is present).
- Sidecar emission at every fork (every exit path emits the AD-11 sidecar so observability is invariant).
- Post-stub sibling-symmetric emitter pattern (same JSONL schema as pre-stub except `path` + non-zero `knowledge_section_tokens` + compression flags from sidecar).
- Inverted-polarity verifier on prose surface (assert ABSENCE of "Skip payload assembly" with explicit header guard against future polarity flips).
- FR-4 single-line table-row amendment via Edit (single-line diff discipline for SC-12 scope-guard cleanliness).
- Phase-suite straight-line N-gate aggregation (mirrors P00 pattern, AD-19 compliant, no array loops).
- SC-12 scope-guard with carve-out helpers for known-orchestrator-emitted side-effect classes.

## Verification

- `m031-p01-phase-suite.sh pass=9 fail=0` — all 9 sub-gates green.
- `m031-p01-scope-guard.sh pass=33 fail=0 block_list_violations=0 mem_hitcount_carveouts=31` — clean post-carve-out.
- `check-must-haves.sh` 77 PASS / 0 FAIL — all phase-level Truths, Artifacts, and Key Links satisfied.
- `check-boundary-map.sh` SKIP — boundary-map produce items not declared at P01 grain (foundation-style; will tighten at P04).
- External-mods WARN list ([M036](../../../../../milestones/M036/index.md), CLAUDE.md, spec 033) is pre-existing session-entry dirty-tree state, not P01 modification.

## Forward-Looking Notes for P02+

- AD-15 corpus is now stable on disk with both pre- and post-M031 baseline JSONL captures; P02–P04 SC verifiers can grep either.
- T03 SC tests gate schema slots; when M018 compression eventually wires into Quick-profile direct-mode, the gates will tighten automatically without test rewrite.
- Pre-existing M036 / CLAUDE.md / spec-033 working-tree drift should be committed onto a separate housekeeping commit before P02 close to keep the scope-guard signal clean.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P02"
milestone: "M031"
name: "P02 phase-suite aggregator + SC-12 scope-guard for P02"
depends_on: ["T04"]
---

## Prerequisites

- T01 complete: 4 shape verifiers under `tools/verify/m031-p02-*.sh` plus SC-5 acceptance test on disk (verified by `bash tools/verify/m031-p02-classifier-extension-shape.sh` etc.).
- T02 complete: 2 shape verifiers (m031-p02-task-slug-shape.sh + m031-p02-role-templates-shape.sh) on disk.
- T03 complete: 2 shape verifiers (m031-p02-prompt-shape.sh + m031-p02-test-tier-a-plus-prompt-ux-shape.sh) plus SC-16 acceptance test on disk.
- T04 complete: 2 shape verifiers (m031-p02-router-shape.sh + m031-p02-test-tier-a-plus-flow-shape.sh) plus SC-6 acceptance test on disk.
- The M031 P01 scope-guard convention is on disk at `tools/verify/m031-p01-scope-guard.sh` (read for reference — T05's scope-guard inherits the block-list and the MEM `hit_count`-only carve-out).
- The M031 P01 phase-suite convention is on disk at `tools/verify/m031-p01-phase-suite.sh` (read for reference — T05's phase-suite inherits the straight-line N-gate aggregation pattern).

## Description

T05 ships two phase-close gates:

1. **`tools/verify/m031-p02-phase-suite.sh`** — straight-line aggregator chaining every P02 sub-gate from T01 through T04. Per AD-19 + the P01 phase-suite pattern: no array loops, no compound chains, no eval. Each sub-gate is a literal `bash <verifier>` invocation followed by a `rc=$?` and a per-gate `OK:`/`FAIL:` line. The final stdout line is `SUMMARY: m031-p02-phase-suite.sh pass=N fail=M`. Exits 0 iff every sub-gate exits 0; gates do NOT short-circuit on failure (all gates run regardless so the operator sees the full report).

2. **`tools/verify/m031-p02-scope-guard.sh`** — SC-12 enforcement for the P02 diff. Inherits the P01 scope-guard's block-list verbatim:
   - `knowledge/**` (M020 owns)
   - `scripts/cost/` ([M027](../../../../../milestones/M027/index.md) owns)
   - `scripts/dispatch/adapters/router/` (M030 owns)
   - `scripts/auto/loop/` ([M021](../../../../../milestones/M021/index.md) owns)

   Inherits the MEM `hit_count`-only carve-out verbatim. The allow-list reflects the P02 "Files Likely Touched" surface plus the P02 phase + task plan + summary file paths plus the `.orchestrator/observability/` permissive prefix.

The phase-suite invokes EVERY P02 sub-gate, including the scope-guard itself as the final gate (so a clean diff is required for green).

P02 sub-gate inventory (twelve gates total):

```
T01: m031-p02-classifier-extension-shape.sh
T01: m031-p02-fixture-provenance-shape.sh
T01: m031-p02-tier-a-plus-input-shape.sh
T01: m031-p02-test-tier-a-plus-classifier-shape.sh
T02: m031-p02-task-slug-shape.sh
T02: m031-p02-role-templates-shape.sh
T03: m031-p02-prompt-shape.sh
T03: m031-p02-test-tier-a-plus-prompt-ux-shape.sh
T04: m031-p02-router-shape.sh
T04: m031-p02-test-tier-a-plus-flow-shape.sh
T05: m031-p02-scope-guard.sh
```

Eleven sub-gates plus the suite line itself. The phase-suite emits `SUMMARY: m031-p02-phase-suite.sh pass=N fail=M` where N + M = 11 on a clean run.

## Steps

1. **Read `tools/verify/m031-p01-phase-suite.sh`** for reference. The pattern is straight-line N-gate aggregation: each gate is a labeled `bash <verifier>` invocation followed by `rc=$?` then `emit_gate_result "$rc" "<verifier-name>"`. No array loops. The accumulator updates inside `emit_gate_result` (`pass=$(( pass + 1 ))` or `fail=$(( fail + 1 ))`). Final `printf 'SUMMARY: m031-p02-phase-suite.sh pass=%d fail=%d\n' "$pass" "$fail"` then `exit 0` iff `fail=0` else `exit 1`.

2. **Author `tools/verify/m031-p02-phase-suite.sh`** (executable, bash 3.2). Mirror the M031 P01 phase-suite shape (118 lines on disk; T05's suite will be similar size). Required body (concrete shape):

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m031-p02-phase-suite.sh — M031 P02 phase-close gate suite.
   #
   # Aggregates all P02 sub-gates (T01 + T02 + T03 + T04 + T05) for the
   # right-sized-entry milestone (M031) and emits a single aggregate
   # SUMMARY line. Mirrors the m031-p01-phase-suite.sh straight-line
   # pattern (AD-19 compliant — no array loops, no compound chains).
   #
   # Sub-gates (in T01 → T05 dependency order):
   #   1. m031-p02-classifier-extension-shape.sh        (T01)
   #   2. m031-p02-fixture-provenance-shape.sh          (T01)
   #   3. m031-p02-tier-a-plus-input-shape.sh           (T01)
   #   4. m031-p02-test-tier-a-plus-classifier-shape.sh (T01)
   #   5. m031-p02-task-slug-shape.sh                   (T02)
   #   6. m031-p02-role-templates-shape.sh              (T02)
   #   7. m031-p02-prompt-shape.sh                      (T03)
   #   8. m031-p02-test-tier-a-plus-prompt-ux-shape.sh  (T03)
   #   9. m031-p02-router-shape.sh                      (T04)
   #  10. m031-p02-test-tier-a-plus-flow-shape.sh       (T04)
   #  11. m031-p02-scope-guard.sh                       (T05)
   #
   # Gates run sequentially; do NOT short-circuit on failure (operator
   # sees the full report). Exit 0 iff every sub-gate exits 0.

   set -u
   pass=0
   fail=0

   emit_gate_result() {
       rc="$1"
       name="$2"
       if [ "$rc" -eq 0 ]; then
           pass=$(( pass + 1 ))
           printf 'OK: %s\n' "$name"
       else
           fail=$(( fail + 1 ))
           printf 'FAIL: %s rc=%s\n' "$name" "$rc"
       fi
   }

   bash tools/verify/m031-p02-classifier-extension-shape.sh
   rc=$?
   emit_gate_result "$rc" "m031-p02-classifier-extension-shape.sh"

   bash tools/verify/m031-p02-fixture-provenance-shape.sh
   rc=$?
   emit_gate_result "$rc" "m031-p02-fixture-provenance-shape.sh"

   # ... (repeat for all 11 gates) ...

   printf 'SUMMARY: m031-p02-phase-suite.sh pass=%d fail=%d\n' "$pass" "$fail"
   if [ "$fail" -eq 0 ]; then
       exit 0
   else
       exit 1
   fi
   ```

   Eleven `bash <verifier>` blocks. No loops, no compound chains. Final SUMMARY line + exit code.

3. **Read `tools/verify/m031-p01-scope-guard.sh`** for reference. The pattern is:
   - Walk `git diff --name-only HEAD` to collect changed paths.
   - For each path: check the block-list (HARD FAIL) → if MEM hit_count-only carve-out applies, soft pass → check the allow-list (PASS) → otherwise WARN out-of-allow-list.
   - Emit `SUMMARY: <name> pass=N fail=M block_list_violations=K mem_hitcount_carveouts=L` final line.

4. **Author `tools/verify/m031-p02-scope-guard.sh`** (executable, bash 3.2). Inherit the P01 scope-guard's block-list pattern verbatim — including the MEM hit_count-only carve-out helper function. Replace the allow-list with P02's surface. Required allow-list (newline-delimited, exact-match):

   ```
   scripts/intake/shape-detect.sh
   scripts/intake/paragraph-classify.sh
   scripts/intake/route-to-dispatch.sh
   scripts/intake/lib/task-slug.sh
   scripts/intake/lib/tier-a-plus-prompt.sh
   templates/dispatch-role-research.md
   templates/dispatch-role-plan.md
   templates/dispatch-role-build.md
   tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md
   tests/m031-acceptance/fixtures/tier-a-plus-input.txt
   tests/m031-acceptance/test-tier-a-plus-classifier.sh
   tests/m031-acceptance/test-tier-a-plus-flow.sh
   tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh
   tools/verify/m031-p02-classifier-extension-shape.sh
   tools/verify/m031-p02-fixture-provenance-shape.sh
   tools/verify/m031-p02-tier-a-plus-input-shape.sh
   tools/verify/m031-p02-task-slug-shape.sh
   tools/verify/m031-p02-role-templates-shape.sh
   tools/verify/m031-p02-prompt-shape.sh
   tools/verify/m031-p02-router-shape.sh
   tools/verify/m031-p02-test-tier-a-plus-classifier-shape.sh
   tools/verify/m031-p02-test-tier-a-plus-flow-shape.sh
   tools/verify/m031-p02-test-tier-a-plus-prompt-ux-shape.sh
   tools/verify/m031-p02-phase-suite.sh
   tools/verify/m031-p02-scope-guard.sh
   [.orchestrator/milestones/M031/phases/P02/P02-PLAN.md](../../../../../milestones/M031/phases/P02/P02-PLAN.md)
   [.orchestrator/milestones/M031/phases/P02/tasks/T01-classifier-and-provenance-PLAN.md](../../../../../milestones/M031/phases/P02/tasks/T01-classifier-and-provenance-PLAN.md)
   [.orchestrator/milestones/M031/phases/P02/tasks/T02-slug-and-role-templates-PLAN.md](../../../../../milestones/M031/phases/P02/tasks/T02-slug-and-role-templates-PLAN.md)
   [.orchestrator/milestones/M031/phases/P02/tasks/T03-prompt-and-prompt-ux-test-PLAN.md](../../../../../milestones/M031/phases/P02/tasks/T03-prompt-and-prompt-ux-test-PLAN.md)
   [.orchestrator/milestones/M031/phases/P02/tasks/T04-router-and-flow-test-PLAN.md](../../../../../milestones/M031/phases/P02/tasks/T04-router-and-flow-test-PLAN.md)
   [.orchestrator/milestones/M031/phases/P02/tasks/T05-phase-suite-and-scope-guard-PLAN.md](../../../../../milestones/M031/phases/P02/tasks/T05-phase-suite-and-scope-guard-PLAN.md)
   .orchestrator/milestones/M031/phases/P02/tasks/T01-SUMMARY.md
   .orchestrator/milestones/M031/phases/P02/tasks/T02-SUMMARY.md
   .orchestrator/milestones/M031/phases/P02/tasks/T03-SUMMARY.md
   .orchestrator/milestones/M031/phases/P02/tasks/T04-SUMMARY.md
   .orchestrator/milestones/M031/phases/P02/tasks/T05-SUMMARY.md
   [.orchestrator/milestones/M031/phases/P02/P02-SUMMARY.md](../../../../../milestones/M031/phases/P02/P02-SUMMARY.md)
   ```

   Allow-list prefixes (permissive — for scratch + observability artifacts):
   - `.orchestrator/observability/`
   - `.orchestrator/tier-a-plus/` (per-flow scratch directories written during T04 router test runs)

   Block-list (inherited verbatim from P01):
   - `knowledge/`
   - `scripts/cost/`
   - `scripts/dispatch/adapters/router/`
   - `scripts/auto/loop/`

   MEM hit_count-only carve-out: copy the `is_mem_hitcount_only_carveout()` function from `tools/verify/m031-p01-scope-guard.sh` verbatim.

   Final stdout line: `SUMMARY: m031-p02-scope-guard.sh pass=N fail=M block_list_violations=K mem_hitcount_carveouts=L`. Exit 0 iff `block_list_violations=0`; else exit 1.

5. **Run the phase-suite locally** to confirm exit 0 with all 11 sub-gates green:

   ```bash
   bash tools/verify/m031-p02-phase-suite.sh
   ```

   Expected output: `SUMMARY: m031-p02-phase-suite.sh pass=11 fail=0` (assuming T01–T04 all green).

6. **Run the scope-guard locally** to confirm a clean diff:

   ```bash
   bash tools/verify/m031-p02-scope-guard.sh
   ```

   Expected output: `SUMMARY: m031-p02-scope-guard.sh pass=N fail=0 block_list_violations=0 mem_hitcount_carveouts=K` for some `N` (allow-listed paths) and `K` (any orchestrator-emitted MEM hit_count drift carved out). `block_list_violations` MUST be 0; else T05 has hit a real scope violation that needs investigation, NOT a verifier-edit.

7. **Run the framework-owned `scripts/verify/check-must-haves.sh`** against the P02 phase directory to confirm phase-level Truths / Artifacts / Key Links all PASS:

   ```bash
   bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M031/phases/P02/
   ```

8. **Confirm idempotency.** Run the phase-suite a second time and confirm identical exit 0 + identical SUMMARY line — the suite must be deterministic (no flake).

## Must-Haves

This task addresses the following Must-Haves from `P02-PLAN.md`:
- "tools/verify/m031-p02-phase-suite.sh exists, executable, invokes every P02 sub-gate in order" (Truth #11; Check via `m031-p02-phase-suite.sh`)
- "tools/verify/m031-p02-scope-guard.sh exists, executable, asserts P02 diff stays within block-list" (Truth #12; Check via `m031-p02-scope-guard.sh`)

## Verification

```bash
bash tools/verify/m031-p02-phase-suite.sh
```

```bash
bash tools/verify/m031-p02-scope-guard.sh
```

```bash
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M031/phases/P02/
```

## Notes

- The phase-suite emits `SUMMARY: m031-p02-phase-suite.sh pass=11 fail=0` on a fully-green run (11 sub-gates: 4 from T01, 2 from T02, 2 from T03, 2 from T04, 1 from T05's own scope-guard).
- Future maintainers extending P02 with additional gates MUST add the new verifier to the suite's gate list AND increment the expected `SUMMARY: pass=N` count expected by downstream consumers (P04 acceptance-battery aggregator).
- Two distinct envelope conventions in use across P02:
  - `RESULT: SC-N pass` / `RESULT: SC-N fail` for SC-* acceptance tests under `tests/m031-acceptance/test-tier-a-plus-*.sh`.
  - `SUMMARY: <verifier> pass=N fail=M` for shape verifiers under `tools/verify/m031-p02-*.sh`.
  Both are AD-19 compliant; downstream consumers can grep either.
- The `.orchestrator/tier-a-plus/` permissive-prefix carve-out in the scope-guard is the P02 equivalent of P01's `.orchestrator/observability/` carve-out — per-flow scratch artifacts that don't pollute the M031 diff signal.
- The MEM hit_count-only carve-out is inherited verbatim from P01 — orchestrator-emitted `hit_count:` line drift on `knowledge/(conventions|lessons|patterns)/MEM*.md` is a dispatch side-effect, not a manual P02 scope violation. Future milestones with similar dispatch side-effects can adopt the same pattern.
- D020 token hygiene (CON-7): comments and prose in the new files MUST NOT embed the scaffold-placeholder marker bracket-TODO byte pattern; paraphrase or escape.
- Bash 3.2 compatibility (MEM001): no `declare -A`, no process substitution, no `$()` containing pipes inside conditionals.

## Inputs

### From Previous Tasks

- All ten T01–T04 shape verifiers under `tools/verify/m031-p02-*.sh`. T05's phase-suite invokes each via `bash <path>` straight-line. Key API: each verifier exits 0 iff `fail=0`, emits `SUMMARY: <name> pass=N fail=M` final line.
- Three SC acceptance tests under `tests/m031-acceptance/test-tier-a-plus-*.sh` (SC-5 / SC-6 / SC-16). T05's phase-suite does NOT run these directly — it runs the shape verifiers that *gate* their existence/contract. The P04 acceptance-battery aggregator (downstream consumer) runs the SC tests.
- The new `scripts/intake/route-to-dispatch.sh` (T04 amended) — T05's scope-guard allow-lists this as a modify, not a create.

### From Disk (Pre-existing)

- `tools/verify/m031-p01-phase-suite.sh` — reference pattern for the straight-line N-gate aggregator. Read before authoring T05's phase-suite.
- `tools/verify/m031-p01-scope-guard.sh` — reference pattern for the SC-12 block-list + MEM hit_count carve-out. Read before authoring T05's scope-guard.
- `scripts/verify/check-must-haves.sh` — framework-owned phase-level Truths/Artifacts/Key Links verifier. T05 invokes it as the final phase-close confirmation.

## Constraints

- **Bash 3.2 compatibility** (MEM001): no `declare -A`, no process substitution, no `$()` containing pipes inside conditionals.
- **Single-script-file Truth Check shape** (AD-19): every gate in the phase-suite is a literal `bash <path>` invocation. No `for` loops, no compound chains, no `eval`.
- **Block-list inherited verbatim** from P01 — T05 MUST NOT relax `knowledge/`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, or `scripts/auto/loop/`. Future maintainers tempted to relax it MUST first amend the spec's "Boundary write-sites M031 delegates" section.
- **MEM hit_count-only carve-out inherited verbatim** from P01 — copy the `is_mem_hitcount_only_carveout()` function body unchanged.
- **Allow-list reflects the P02 surface** — exactly the files in P02-PLAN.md "Files Likely Touched" plus the P02 phase + task plan + summary paths.
- **No edits to upstream P02 deliverables** in T05 — T01–T04 outputs stay frozen. T05's only on-disk writes are the two new verifiers under `tools/verify/`.
- **Verifier path discipline** (AD-19 + [M032](../../../../../milestones/M032/index.md) Finding A): project-owned slug-bearing verifiers live under `tools/verify/`, NOT `scripts/verify/`.

## Expected Output

After T05 completes:

1. `tools/verify/m031-p02-phase-suite.sh` exists, executable, exits 0 with `SUMMARY: m031-p02-phase-suite.sh pass=11 fail=0` (eleven sub-gates green).
2. `tools/verify/m031-p02-scope-guard.sh` exists, executable, exits 0 with `SUMMARY: m031-p02-scope-guard.sh pass=N fail=0 block_list_violations=0 mem_hitcount_carveouts=K`.
3. `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M031/phases/P02/` exits 0 — every P02 phase-level Truth, Artifact, and Key Link is satisfied on disk.
4. The P02 diff against HEAD touches only files in the T05 scope-guard allow-list (plus permissive-prefix artifacts under `.orchestrator/observability/` or `.orchestrator/tier-a-plus/`) and zero paths under the block-list.

T05 closes P02 mechanically. The phase is then ready for `orchestrator:consolidate` (and downstream P03 + P04 work).

## State Context

- **Current State**: executing
- **Milestone**: M031
- **Phase**: P02
- **Task**: T05-phase-suite-and-scope-guard
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **Bash 3.2 compatibility** (MEM001): no `declare -A`, no process substitution, no `$()` containing pipes inside conditionals.
- **Single-script-file Truth Check shape** (AD-19): every gate in the phase-suite is a literal `bash <path>` invocation. No `for` loops, no compound chains, no `eval`.
- **Block-list inherited verbatim** from P01 — T05 MUST NOT relax `knowledge/`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, or `scripts/auto/loop/`. Future maintainers tempted to relax it MUST first amend the spec's "Boundary write-sites M031 delegates" section.
- **MEM hit_count-only carve-out inherited verbatim** from P01 — copy the `is_mem_hitcount_only_carveout()` function body unchanged.
- **Allow-list reflects the P02 surface** — exactly the files in P02-PLAN.md "Files Likely Touched" plus the P02 phase + task plan + summary paths.
- **No edits to upstream P02 deliverables** in T05 — T01–T04 outputs stay frozen. T05's only on-disk writes are the two new verifiers under `tools/verify/`.
- **Verifier path discipline** (AD-19 + M032 Finding A): project-owned slug-bearing verifiers live under `tools/verify/`, NOT `scripts/verify/`.

### Acceptance Criteria

This task addresses the following Must-Haves from `P02-PLAN.md`:
- "tools/verify/m031-p02-phase-suite.sh exists, executable, invokes every P02 sub-gate in order" (Truth #11; Check via `m031-p02-phase-suite.sh`)
- "tools/verify/m031-p02-scope-guard.sh exists, executable, asserts P02 diff stays within block-list" (Truth #12; Check via `m031-p02-scope-guard.sh`)

### Files To Touch

- `scripts/intake/shape-detect.sh` (modify)
- `scripts/intake/paragraph-classify.sh` (modify)
- `scripts/intake/route-to-dispatch.sh` (modify)
- `scripts/intake/lib/task-slug.sh` (create)
- `scripts/intake/lib/tier-a-plus-prompt.sh` (create)
- `templates/dispatch-role-research.md` (create)
- `templates/dispatch-role-plan.md` (create)
- `templates/dispatch-role-build.md` (create)
- `tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md` (create)
- `tests/m031-acceptance/fixtures/tier-a-plus-input.txt` (create)
- `tests/m031-acceptance/test-tier-a-plus-classifier.sh` (create)
- `tests/m031-acceptance/test-tier-a-plus-flow.sh` (create)
- `tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh` (create)
- `tools/verify/m031-p02-classifier-extension-shape.sh` (create)
- `tools/verify/m031-p02-fixture-provenance-shape.sh` (create)
- `tools/verify/m031-p02-tier-a-plus-input-shape.sh` (create)
- `tools/verify/m031-p02-task-slug-shape.sh` (create)
- `tools/verify/m031-p02-role-templates-shape.sh` (create)
- `tools/verify/m031-p02-prompt-shape.sh` (create)
- `tools/verify/m031-p02-router-shape.sh` (create)
- `tools/verify/m031-p02-test-tier-a-plus-classifier-shape.sh` (create)
- `tools/verify/m031-p02-test-tier-a-plus-flow-shape.sh` (create)
- `tools/verify/m031-p02-test-tier-a-plus-prompt-ux-shape.sh` (create)
- `tools/verify/m031-p02-phase-suite.sh` (create)
- `tools/verify/m031-p02-scope-guard.sh` (create)

<!-- The phase plan and task plan files themselves (this file +
     tasks/T0[1-5]-*-PLAN.md) are written by the planner, not by the
     executor — they are not listed here. Test-run output files written
     under .orchestrator/tier-a-plus/<task-slug>/ during integration
     smoke runs are scratch artifacts under the .orchestrator/observability/
     prefix-equivalent — the scope-guard treats .orchestrator/tier-a-plus/
     as a permissive prefix matching the .orchestrator/observability/
     pattern from P01. -->

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