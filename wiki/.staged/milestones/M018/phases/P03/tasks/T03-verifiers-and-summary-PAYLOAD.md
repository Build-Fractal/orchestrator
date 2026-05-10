---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T03-verifiers-and-summary (Phase P03, Milestone M018)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~500 | required |
| Upstream Context | 981-1044 | ~2400 | required |
| Task Plan | 1046-1489 | ~6000 | required |
| State Context | 1491-1497 | ~100 | required |
| First-Turn Completeness | 1499-1533 | ~700 | required |
| **Total** | | **~20500** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 632
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
hit_count: 632
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
hit_count: 632
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
hit_count: 632
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
hit_count: 561
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
hit_count: 561
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
hit_count: 561
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
hit_count: 632
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
hit_count: 561
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
hit_count: 561
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
hit_count: 561
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
hit_count: 632
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
hit_count: 632
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
hit_count: 632
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
hit_count: 561
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
hit_count: 561
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
hit_count: 561
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
hit_count: 632
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
hit_count: 561
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
hit_count: 561
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
hit_count: 632
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
hit_count: 632
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
hit_count: 561
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
hit_count: 561
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
hit_count: 561
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
hit_count: 216
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
hit_count: 216
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
hit_count: 216
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
hit_count: 208
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
hit_count: 208
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
hit_count: 198
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

<!-- AD-19: every Check is a single-script-file invocation. No inline
     compound bash, no plain subshells, no $(...|...). One verifier per
     truth, parked under scripts/verify/m018-p03-*.sh. -->

- Tier 1 paging replaces oversized inline tool-result blocks with a `<tool-result file="..." preview-lines="...">` reference and persists the original to `.orchestrator/cache/tool-results/<sha256>`.
  - Check: `bash scripts/verify/m018-p03-tier1-paging.sh`
- Cache reuse: a second dispatch with an identical tool-call (matched on SHA-256 of command+input) reuses the same cache entry without rewriting the file (mtime preserved).
  - Check: `bash scripts/verify/m018-p03-cache-reuse.sh`
- `payload_breakdown` JSONL records carry additive `tier1_savings_tokens` and `tier1_invocations` integer fields; pre-T1 records remain valid JSON; missing fields default to 0 in rollups (CON-5).
  - Check: `bash scripts/verify/m018-p03-emitter-additivity.sh`
- `scripts/util/cache-prune.sh --max-age 7d` removes cache files older than 7d by mtime and leaves newer files alone; safe to invoke against an empty or missing cache directory.
  - Check: `bash scripts/verify/m018-p03-cache-prune.sh`
- `compression.enabled: false` short-circuits Tier 1 entirely; the P02 disable-flag golden payload (`tests/fixtures/m018-p02-baseline-payload.golden.txt`) remains byte-identical against the P03 build-context.sh; `compression.tier1.enabled: false` short-circuits only Tier 1 (filter still runs).
  - Check: `bash scripts/verify/m018-p03-disable-flag-honored.sh`
- Body-level preservation self-check: when Tier 1 modifies a section, `pres_check_section` (P02 library) is invoked over the post-paging body and any failure causes Tier 1 to pass the section through unmodified plus emit a `tier_preservation_violation` JSONL record (`record_type=tier_preservation_violation`, `tier=tier1`).
  - Check: `bash scripts/verify/m018-p03-preservation-self-check.sh`

<dispatch-volatile>

## Upstream Context


### P02 Summary
---
schema_version: "1.0"
type: phase-summary
id: P02
parent: M018
milestone: M018
provides: "knowledge-aware injection filter live in scripts/dispatch/build-context.sh + scripts/dispatch/lib/section-handlers.sh; preservation-contract self-check library scripts/lib/preservation-check.sh (sourceable: pres_check_section / pres_emit_violation / pres_density_pre_check); payload_filter JSONL record schema (record_type=payload_filter; fields: filter, drop_list, dropped_count, dropped_tokens, dropped_ids, source); payload_breakdown.filter_dropped_tokens additive field; compression_underperformance JSONL record (operational signal — never blocks); compression.knowledge_filter.* + compression.underperformance.* config keys + ORCH_OVERRIDE_COMPRESSION_ENABLED env override; six P02-private truth verifiers + tests/fixtures/m018-p02-knowledge-status fixture + golden baseline; CLAUDE.md/AGENTS.md recent-changes refresh"
requires: "P01 grammar contract Reviewed (references/compression-grammar.md v1.0.1); P00 SC-9 calibrated 34.7% floor; M020 status: field on knowledge entries (DEP-1)"
affects: "P03 (T1 microcompact — sources scripts/lib/preservation-check.sh; reuses tier_preservation_violation + payload_breakdown schema; consumes filter savings via additive filter_dropped_tokens field); P04 (T2 snip — same lib + per-tier savings field, MIT-01 nested-fence regex load-bearing); P05 (eval harness — reads compression_underperformance + payload_filter + future tier_preservation_violation records); P06 (T3 auto-compact — wires pres_density_pre_check before LLM call per MIT-08; tier-3-savings field additive)"
key_files: "scripts/lib/preservation-check.sh;scripts/lib/knowledge-filter.sh;scripts/dispatch/build-context.sh;scripts/dispatch/lib/section-handlers.sh;.orchestrator/config.yml;templates/config-defaults.yml;tests/fixtures/m018-p02-knowledge-status/knowledge-stream.md;tests/fixtures/m018-p02-knowledge-status/README.md;tests/fixtures/m018-p02-baseline-payload.golden.txt;scripts/verify/m018-p02-filter-drops.sh;scripts/verify/m018-p02-emitter-additivity.sh;scripts/verify/m018-p02-preservation-check-api.sh;scripts/verify/m018-p02-underperformance-emit.sh;scripts/verify/m018-p02-disable-flag-honored.sh;scripts/verify/m018-p02-dual-write-recent.sh;scripts/verify/_helpers/m018-p02-build-fixture.sh"
key_decisions: "Filter operates on whole-entry granularity per grammar contract `## Tier: filter` failure semantics — no interior preservation check at the entry level; preservation-check library sourced defensively in build-context.sh + section-handlers.sh so P03/P04/P06 inherit a working source path; filter is awk-driven for speed + AP-009 compliance; underperformance check is operational signal (never blocks dispatch); P02-stage logs may legitimately fall below the floor (tier1/2/3 not yet shipped) — handled via min_sample_size guard (default 10); ORCH_OVERRIDE_COMPRESSION_ENABLED env beats config (test seam, FR-15 SC-8); fail-open on missing status field (FR-3 / A-1 back-compat)"
patterns_established: "Sourceable lib pattern under scripts/lib/ for cross-tier reuse (T01 — preservation-check); pure-library pattern with optional config-aware accessors (T02 — knowledge-filter); awk-driven entry-boundary detection in bash 3.2 stream filters (T02); additive JSONL emitter pattern with stats-file handoff between collector and emitter (T02); operational-signal JSONL records that never block dispatch (T03 — compression_underperformance); fixture milestone + golden-payload diff pattern for compression-disabled regression (T04 — disable-flag-honored)"
drill_down_paths: "[.orchestrator/milestones/M018/phases/P02/tasks/T01-preservation-check-lib-SUMMARY.md](../../../../../milestones/M018/phases/P02/tasks/T01-preservation-check-lib-SUMMARY.md);[.orchestrator/milestones/M018/phases/P02/tasks/T02-knowledge-filter-SUMMARY.md](../../../../../milestones/M018/phases/P02/tasks/T02-knowledge-filter-SUMMARY.md);[.orchestrator/milestones/M018/phases/P02/tasks/T03-underperformance-emitter-SUMMARY.md](../../../../../milestones/M018/phases/P02/tasks/T03-underperformance-emitter-SUMMARY.md);[.orchestrator/milestones/M018/phases/P02/tasks/T04-verifiers-and-summary-SUMMARY.md](../../../../../milestones/M018/phases/P02/tasks/T04-verifiers-and-summary-SUMMARY.md)"
duration: "~6h"
verification_result: pass
observability_surfaces: "execution-log.jsonl: payload_filter record_type, payload_breakdown.filter_dropped_tokens additive field, compression_underperformance record_type, tier_preservation_violation record_type (emitter library shipped, callers wired in P03+)"
completed_at: "2026-04-27T00:00:00Z"
---

# Phase Summary: M018/P02 — Knowledge-Aware Filter + Preservation-Check Library + Underperformance Emitter

## Closure summary

P02 lands the **foundation tier** of the M018 compression pipeline: the knowledge-aware status filter, the reusable preservation-contract self-check library, and the aggregate-savings underperformance emitter. After P02, every dispatch's `## Knowledge` section drops `status: superseded` and `status: experimental` entries before payload assembly. The filter is awk-driven, bash 3.2 compatible, and runs through `scripts/lib/knowledge-filter.sh` from both the planning branch (`build-context.sh _bc_apply_knowledge_filter`) and the task-dispatch branch (`section-handlers.sh _sh_apply_knowledge_filter`).

The phase also ships:

- **Reusable preservation-contract self-check library** (`scripts/lib/preservation-check.sh`) that P03 (tier1), P04 (tier2), and P06 (tier3) source. Three exported functions: `pres_check_section` (regex pattern walker over the cross-tier vocabulary), `pres_emit_violation` (writes `tier_preservation_violation` JSONL), `pres_density_pre_check` (MIT-08 groundwork — refuses tier3 invocation when input density exceeds threshold).
- **Aggregate-savings underperformance signal emitter** (`_bc_emit_compression_underperformance` in `build-context.sh`) — operational signal, never blocks dispatch. Awk-driven running mean over the last N `payload_breakdown` records' filter+tier savings ratio; emits `compression_underperformance` JSONL record when below the SC-9 calibrated 34.7% floor (gated by `min_sample_size` to prevent spurious early-stage emission).
- **MIT-08 density-pre-check API surface** — caller wired in P06.
- **Disable-flag golden-payload regression contract** — `compression.enabled: false` short-circuits the entire filter path; output is byte-identical to the checked-in golden baseline (FR-15 / SC-8 verifiable from now on).

**Dogfood inflection**: P03 onward, every M018 dispatch (and every other orchestrator dispatch in this repo) runs through the knowledge-aware filter. Subsequent M018 task payloads will start carrying live `payload_filter` records once knowledge entries with retired statuses accumulate.

## Risk-mitigation traceability

- **MIT-08 (P02 entry gate from P01 conversus deliberation)** — LLM preservation trust boundary: `pres_density_pre_check` ships in `scripts/lib/preservation-check.sh` (T01). The function exists as an API surface here; P06 plumbs it in front of tier3's LLM call. Density-x100 integer math (no floats — bash 3.2) returns refuse when matches/total_bytes exceeds the configured threshold.
- **MIT-09 (P02 entry gate from P01 conversus deliberation)** — SC-9 threshold operational fragility: `_bc_emit_compression_underperformance` in `scripts/dispatch/build-context.sh` (T03) emits `compression_underperformance` JSONL when running-mean savings falls below the 34.7% floor. Window size, floor pct, min sample size, and enabled flag all config-driven via `compression.underperformance.*`.
- **MIT-10 (P02, THREAT-09 from P01 conversus deliberation)** — preservation-contract self-check algorithmic specification: `pres_check_section` in `scripts/lib/preservation-check.sh` (T01) is the regex-driven pattern walker (one pass per preserved-pattern row from grammar `## Preserved-Pattern Vocabulary`); byte-mismatch on any preserved span triggers passthrough plus `tier_preservation_violation` emission via `pres_emit_violation`.

## Followups for downstream phases

- **P03 (tier1 microcompact)** — sources `scripts/lib/preservation-check.sh` and reuses the cache-prune utility pattern; consumes filter savings via the additive `filter_dropped_tokens` field on `payload_breakdown`. The `payload_breakdown` schema P02 established carries forward unchanged.
- **P04 (tier2 snip)** — same library; the MIT-01 nested-fence regex (`^\`{3,}[a-zA-Z0-9_-]*$`) is load-bearing for P04's head-drop boundary detection.
- **P05 (eval harness)** — reads `compression_underperformance` + `payload_filter` + future `tier_preservation_violation` records from `execution-log.jsonl` per the additive-emitter invariants section of the grammar contract.
- **P06 (tier3 auto-compact)** — wires `pres_density_pre_check` before the LLM call per MIT-08; tier-3-savings field additive on `payload_breakdown`. MIT-08 LLM-preservation enforcement is a P06 unit_close gate, not a P02 gate.

## Verification result

All P02 truths PASS via `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P02/`. All artifacts present, all key links resolve, all six private verifiers green:

- `m018-p02-filter-drops.sh` — PASS (MEM901+MEM903 dropped, MEM900/902/904 retained, fail-open MEM902 honored).
- `m018-p02-emitter-additivity.sh` — PASS (emitter source + live filter_dropped_tokens + pre/post-T02 JSON shape).
- `m018-p02-preservation-check-api.sh` — PASS (3 functions sourceable; selftest green).
- `m018-p02-underperformance-emit.sh` — PASS (running_mean_pct < 34.7 floor; sample_size >= 10).
- `m018-p02-disable-flag-honored.sh` — PASS (override→false reported; baseline byte-identical to fixture; short-circuit guard present in build-context.sh).
- `m018-p02-dual-write-recent.sh` — PASS (M018/P02 named in CLAUDE.md + AGENTS.md recent-changes blocks).

P02 closed. M018 advances to P03.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M018"
name: "Verifiers (7 truth checks) + fixture + P03-SUMMARY + CLAUDE.md/AGENTS.md dual-write"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 has landed:
  - `_bc_apply_tier1` in `scripts/dispatch/build-context.sh` — paging + cache write + post-paging `pres_check_section` self-check + `tier_preservation_violation` emit on failure.
  - `compression.tier1.*` config keys in `.orchestrator/config.yml`.
  - Additive `tier1_savings_tokens` + `tier1_invocations` fields on `payload_breakdown` JSONL records via `_bc_emit_payload_breakdown`.
  - The Tier 1 call site is between the existing `_bc_emit_payload_breakdown` and `_bc_emit_compression_underperformance` calls (line ~1470).
- T02 has landed:
  - `scripts/util/cache-prune.sh --max-age <duration>` — single-script-file utility; reads `compression.tier1.cache_dir` from config.
- P02 has shipped:
  - `tests/fixtures/m018-p02-baseline-payload.golden.txt` — golden payload for the disable-flag regression. T03's `m018-p03-disable-flag-honored.sh` re-uses this golden under T01's build-context.sh to assert `compression.enabled: false` keeps it byte-identical.
  - `scripts/lib/preservation-check.sh` — sourceable; `pres_check_section` and `pres_emit_violation` exposed.
- AP-009 (Bash shape guard): no compound chains > 2; no plain subshells; no `$(...|...)`. Bash 3.2.

## Description

Land the seven truth verifiers, the T03 fixture, the P03 phase summary, and the CLAUDE.md/AGENTS.md `recent-changes` dual-write. After T03:

1. `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P03/` exits 0 — every truth `Check:` script PASSes; every artifact path exists with required line count + substring; every key link resolves.
2. The phase state advances from `executing` to `phase-summary` once `P03-SUMMARY.md` is written; the next `derive-phase.sh` call returns `phase-complete`.
3. CLAUDE.md and AGENTS.md `orchestrator:recent-changes` blocks both name `M018/P03` (or `tier1`) and were written via `scripts/util/dual-write-runtime-md.sh` so the two files stay in sync.

## Steps

### Step 1 — Build the fixture

Create `tests/fixtures/m018-p03-tool-result/dispatch-payload-fixture.md`. This is a hand-written dispatch payload that contains:
- One short tool-result block (body well under 1500-token threshold) — passes through verbatim.
- One large tool-result block (body well over 1500-token threshold; ~7000 chars of repeated `echo`-like text is enough) — gets paged.
- Some surrounding markdown so the fixture resembles a real assembled payload.

Use `Write` to author the file. Sample shape (the body field is what counts for verification):

```
# Dispatch Context -- T01 (Phase P03, Milestone M018)

## Manifest
| Section | Lines | Tokens |
|---------|-------|--------|
| Upstream Context | 200 | 7000 |

## Upstream Context

### Recent tool results (raw)

<tool-result command="ls -la /tmp">
<tool-result-input>
</tool-result-input>
<tool-result-body>
total 8
drwx------  3 user  wheel  96 Apr 27 12:00 .
drwxrwxrwt 12 root  wheel 384 Apr 27 12:00 ..
-rw-------  1 user  wheel  17 Apr 27 12:00 small.txt
</tool-result-body>
</tool-result>

<tool-result command="cat /tmp/big.log">
<tool-result-input>
</tool-result-input>
<tool-result-body>
LOG line 0001 — repeating-content-marker M018-P03-T03-BIG
LOG line 0002 — repeating-content-marker M018-P03-T03-BIG
... (repeat the LOG line up to ~200 lines so body exceeds 1500-token threshold)
</tool-result-body>
</tool-result>

## Task Plan

A small task plan body, ~10 lines, terminating the payload.
```

Repeat the LOG line ~200 times so the big block's body crosses ~7000 chars (~1750 tokens > 1500-token threshold). The exact authoring step: write a short bash one-liner in the fixture-staging helper (Step 2) to expand the LOG-block — it is easier to maintain than 200 hand-typed lines.

Also create `tests/fixtures/m018-p03-tool-result/README.md` (≥ 10 lines) describing the fixture's intent: small block passes through; big block gets paged; cache-reuse verifier replays the same fixture.

### Step 2 — Build the fixture-staging helper

Create `scripts/verify/_helpers/m018-p03-build-fixture.sh`. Multiple verifiers need the same fixture milestone shape (`.orchestrator/milestones/M018-fixture/...`); this helper stages it under a tmp directory passed as `$1`. Pattern lifted directly from P02's `_helpers/m018-p02-build-fixture.sh`.

```bash
#!/usr/bin/env bash
# Stages a fixture orchestrator root under $1 so a verifier can drive
# build-context.sh against a controlled state. Bash 3.2 + AP-009 clean.
set -eu

DEST="${1:-}"
if [ -z "$DEST" ]; then
  printf 'm018-p03-build-fixture.sh: missing dest directory\n' >&2
  exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

mkdir -p "$DEST/milestones/M018-fixture/phases/P03"
mkdir -p "$DEST/cache/tool-results"

# Fake task plan so build-context.sh has somewhere to point.
cat > "$DEST/milestones/M018-fixture/phases/P03/T01-PLAN.md" <<'EOF'
---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M018-fixture"
---
# Stub task plan for fixture dispatch.
EOF

# Copy the fixture payload so build-context.sh can ingest it as a captured payload directly.
mkdir -p "$DEST/_fixture-payloads"
cp "$PROJECT_ROOT/tests/fixtures/m018-p03-tool-result/dispatch-payload-fixture.md" \
   "$DEST/_fixture-payloads/payload.md"

# Minimal config.yml inside the fixture.
cat > "$DEST/config.yml" <<EOF
compression:
  enabled: true
  knowledge_filter:
    enabled: true
    drop_list:
      - superseded
      - experimental
  tier1:
    enabled: true
    inline_threshold_tokens: 1500
    preview_lines: 5
    cache_dir: $DEST/cache/tool-results/
EOF
```

### Step 3 — Author the seven verifiers

Each verifier is a single-script-file (AD-19), AP-009-clean, exits 0 on PASS, exits 1 on FAIL with a one-line `FAIL:` stderr message naming the assertion that broke.

#### 3.1 `scripts/verify/m018-p03-tier1-paging.sh`

Stage the fixture; copy the fixture payload to a tmp `$PAYLOAD_CAPTURE`-shaped path; invoke `_bc_apply_tier1` directly via a small bash invocation that sources build-context.sh's config-derived environment. Cleanest approach: stage the fixture under `$DEST` and run `_bc_apply_tier1` against the staged payload via a small inline shim:

```bash
#!/usr/bin/env bash
# m018-p03-tier1-paging.sh — asserts that the big tool-result block is
# paged out (replaced with a `<tool-result file=...>` reference) and the
# cache file is written under the configured cache_dir; the small block
# is left unchanged.
set -eu

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEST="$(mktemp -d)"
bash "$PROJECT_ROOT/scripts/verify/_helpers/m018-p03-build-fixture.sh" "$DEST"

# Drive _bc_apply_tier1 indirectly: invoke build-context.sh against the
# fixture? Simpler — author a thin shim that exports the four TIER1_*
# envs and sources just the tier1 function.
SHIM="$DEST/_shim.sh"
cat > "$SHIM" <<'SHIM_EOF'
#!/usr/bin/env bash
set -eu
PROJECT_ROOT="$1"
DEST="$2"
ORCH_ROOT="$DEST"
TMPDIR_BUILD="$(mktemp -d)"
COMPRESSION_ENABLED=true
TIER1_ENABLED=true
TIER1_INLINE_THRESHOLD_TOKENS=1500
TIER1_PREVIEW_LINES=5
TIER1_CACHE_DIR="$DEST/cache/tool-results/"
MILESTONE_ID=M018-fixture
PHASE_ID=P03
TASK_ID=T01
. "$PROJECT_ROOT/scripts/lib/preservation-check.sh"
# Source ONLY the _bc_apply_tier1 function. Cleanest path: extract via sed.
SCRATCH="$(mktemp)"
sed -n '/^_bc_apply_tier1()/,/^}$/p' "$PROJECT_ROOT/scripts/dispatch/build-context.sh" > "$SCRATCH"
. "$SCRATCH"
PAYLOAD="$DEST/_fixture-payloads/payload.md"
_bc_apply_tier1 "$PAYLOAD"
cat "$PAYLOAD"
SHIM_EOF
chmod +x "$SHIM"

OUT="$(bash "$SHIM" "$PROJECT_ROOT" "$DEST")"

if ! printf '%s\n' "$OUT" | grep -q '<tool-result file="'; then
  printf 'FAIL: expected <tool-result file="..."> reference in paged payload\n' >&2
  exit 1
fi
if ! printf '%s\n' "$OUT" | grep -q 'small.txt'; then
  printf 'FAIL: small block was paged (it should pass through verbatim)\n' >&2
  exit 1
fi
if ! ls "$DEST/cache/tool-results/" | grep -qE '^[0-9a-f]{64}$'; then
  printf 'FAIL: expected SHA-256-named cache file under %s\n' "$DEST/cache/tool-results/" >&2
  exit 1
fi
printf 'PASS: m018-p03-tier1-paging\n'
exit 0
```

Note the AP-009-safe shape: heredocs feed plain `cat >` (not piped to a command), shell interpolation happens inside the heredoc body which is permitted, and the captured `OUT` lookups go through `printf '%s\n' "$OUT" | grep -q PATTERN` — that is `cmd | grep -q`, which is a single pipe, not the banned `$(... | ...)` shape (the entire `printf | grep` is the command, not a command-substitution). The verifier shim file extraction via `sed -n '/^_bc_apply_tier1()/,/^}$/p'` is brittle in principle but acceptable: the `_bc_apply_tier1` function is the only one with that exact name, and the closing `^}$` at column 0 is the canonical bash function-end shape.

If the sed-extraction proves too fragile during T03 authoring, alternative: have T01 emit `_bc_apply_tier1` as a separate sourceable file under `scripts/lib/tier1.sh` and source it from build-context.sh. That refactor adds a small file but eliminates the verifier-side sed extraction. Recommend deferring that refactor unless verifiers fail in practice.

#### 3.2 `scripts/verify/m018-p03-cache-reuse.sh`

Same shim pattern as 3.1. Run `_bc_apply_tier1` twice against the same fixture payload (each run rewrites the payload; the second run's input is the original captured payload, not the paged output, because real dispatches always start from a fresh capture). Capture the cache file's mtime after the first run; assert the second run does not change it.

```bash
#!/usr/bin/env bash
# m018-p03-cache-reuse.sh — asserts SHA-256-keyed cache hits short-circuit
# the cache write; mtime preserved across two paging passes.
set -eu

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEST="$(mktemp -d)"
bash "$PROJECT_ROOT/scripts/verify/_helpers/m018-p03-build-fixture.sh" "$DEST"

PAYLOAD="$DEST/_fixture-payloads/payload.md"
PAYLOAD_BACKUP="$DEST/_fixture-payloads/payload-backup.md"
cp "$PAYLOAD" "$PAYLOAD_BACKUP"

SHIM="$DEST/_shim.sh"
# (same shim authoring as 3.1 — extract _bc_apply_tier1 + run once)
# Author shim exactly as in 3.1.
# ... (verbatim copy of shim from 3.1) ...

# First pass.
bash "$SHIM" "$PROJECT_ROOT" "$DEST" >/dev/null
# Capture mtime of the SHA-256-named cache file (there should be exactly one
# matching the big block).
CACHE_FILE="$(ls "$DEST/cache/tool-results/" | head -n1)"
if [ -z "$CACHE_FILE" ]; then
  printf 'FAIL: cache file missing after first pass\n' >&2
  exit 1
fi
if stat -f %m "$DEST/cache/tool-results/$CACHE_FILE" >/dev/null 2>&1; then
  MTIME1="$(stat -f %m "$DEST/cache/tool-results/$CACHE_FILE")"
else
  MTIME1="$(stat -c %Y "$DEST/cache/tool-results/$CACHE_FILE")"
fi

# Restore the original payload and run again.
cp "$PAYLOAD_BACKUP" "$PAYLOAD"
sleep 1   # ensure mtime resolution is at least 1s.
bash "$SHIM" "$PROJECT_ROOT" "$DEST" >/dev/null

if stat -f %m "$DEST/cache/tool-results/$CACHE_FILE" >/dev/null 2>&1; then
  MTIME2="$(stat -f %m "$DEST/cache/tool-results/$CACHE_FILE")"
else
  MTIME2="$(stat -c %Y "$DEST/cache/tool-results/$CACHE_FILE")"
fi

if [ "$MTIME1" != "$MTIME2" ]; then
  printf 'FAIL: cache-reuse expected mtime preserved (%s != %s)\n' "$MTIME1" "$MTIME2" >&2
  exit 1
fi
printf 'PASS: m018-p03-cache-reuse\n'
exit 0
```

#### 3.3 `scripts/verify/m018-p03-emitter-additivity.sh`

Drive `build-context.sh` end-to-end against a real fixture milestone state, capture the emitted `payload_breakdown` line, assert it contains both `tier1_savings_tokens` and `tier1_invocations` keys with integer values; assert the JSON parses cleanly via `python3 -c 'import json,sys; [json.loads(l) for l in sys.stdin]'`. Also assert pre-existing fields (`payload_chars`, `filter_dropped_tokens`, `model`) are still present (CON-5 additivity check).

The simplest end-to-end path: write a minimal fixture orchestrator state under `$DEST` (already done by `_helpers/m018-p03-build-fixture.sh` from Step 2), invoke `bash scripts/dispatch/build-context.sh M018-fixture P03 T01` against it (set `ORCH_ROOT=$DEST`), then read `$DEST/milestones/M018-fixture/execution-log.jsonl`.

Heredoc the verifier body in the same single-script-file shape; assertions via `grep -q "tier1_savings_tokens"` etc.

#### 3.4 `scripts/verify/m018-p03-cache-prune.sh`

Stage a tmp cache root with two files (one backdated, one fresh), invoke `bash scripts/util/cache-prune.sh --max-age 7d` against it (set `--max-age` and a tmp config that points to the staged directory; alternative: invoke with `cd $DEST` so the script's project-root walk lands on the staged config). Assert:
- The backdated file is gone after the prune.
- The fresh file is still present.
- A second invocation reports `pruned=0` (idempotency).
- The script exits 0 in both calls.

#### 3.5 `scripts/verify/m018-p03-disable-flag-honored.sh`

Two assertions:
1. With `compression.enabled: false` (set via `ORCH_OVERRIDE_COMPRESSION_ENABLED=false`), build-context.sh produces a payload byte-identical to `tests/fixtures/m018-p02-baseline-payload.golden.txt`. (Re-uses P02's existing golden; T01 must not have broken it.)
2. With `compression.enabled: true` and `compression.tier1.enabled: false`, the knowledge filter still drops entries (verifiable from the JSONL `payload_filter` record presence) but the Tier 1 paging short-circuits (no cache writes; `tier1_invocations: 0` in the `payload_breakdown` record).

Both assertions exercise the same fixture state. Implementation pattern is the same as P02's `m018-p02-disable-flag-honored.sh` — diff against the golden under override; assert presence/absence of records in the JSONL.

#### 3.6 `scripts/verify/m018-p03-preservation-self-check.sh`

Construct a small synthetic captured payload that contains a tool-result block whose body, after paging, would corrupt a preserved-pattern (the simplest forcing function: hand-craft a body whose first 5 lines — what the preview keeps — break a cross-tier vocabulary regex from `pres_check_section`). Then assert that:
- The post-paging file is the SAME as the pre-paging file (passthrough on self-check failure).
- A `tier_preservation_violation` JSONL record was emitted with `tier=tier1`.

Hand-engineering a body that passes the threshold AND breaks a preserved pattern requires knowledge of `PRES_PATTERNS_REGEX` content. The simplest forcing function: stub `pres_check_section` itself by sourcing a tiny shadowing function before the shim runs `_bc_apply_tier1`:

```bash
# In the verifier shim, override pres_check_section to always fail.
pres_check_section() { return 1; }
pres_emit_violation() {
  printf '{"record_type":"tier_preservation_violation","tier":"%s","section":"%s","pattern":"%s","timestamp":"stub"}\n' \
         "$1" "$2" "$3" >> "$4"
}
```

Then assert the captured payload equals the pre-paging snapshot AND `execution-log.jsonl` contains the synthetic record. This stub-driven approach exercises the production `_bc_apply_tier1` failure-path code without depending on the regex set's contents.

#### 3.7 `scripts/verify/m018-p03-dual-write-recent.sh`

Read both `CLAUDE.md` and `AGENTS.md`; assert both contain a line matching `M018/P03` OR `tier1` inside their `# >>> orchestrator:recent-changes >>>` block.

```bash
#!/usr/bin/env bash
set -eu
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

for f in "$PROJECT_ROOT/CLAUDE.md" "$PROJECT_ROOT/AGENTS.md"; do
  if [ ! -f "$f" ]; then
    printf 'FAIL: missing %s\n' "$f" >&2
    exit 1
  fi
  # Extract the recent-changes block via awk single pass.
  block="$(awk '
    /^# >>> orchestrator:recent-changes >>>/ { in_blk=1; next }
    /^# <<< orchestrator:recent-changes <<</ { in_blk=0 }
    in_blk { print }
  ' "$f")"
  if ! printf '%s\n' "$block" | grep -qE 'M018/P03|tier1'; then
    printf 'FAIL: %s recent-changes block missing M018/P03 or tier1\n' "$f" >&2
    exit 1
  fi
done
printf 'PASS: m018-p03-dual-write-recent\n'
exit 0
```

### Step 4 — Run the dual-write at phase close

Run `bash scripts/util/dual-write-runtime-md.sh` with whatever invocation pattern P02 used to refresh the `recent-changes` block. The block content is a single bullet line inside the `# >>> orchestrator:recent-changes >>>` ... `# <<<` markers.

Pattern (per P02):

```bash
bash scripts/util/dual-write-runtime-md.sh \
  --section "orchestrator:recent-changes" \
  --content "- 030-context-compression-layer: M018/P03 — Tier 1 microcompact (tool-result paging + SHA-256 cache reuse + tier1_* additive emitter fields + cache-prune.sh)"
```

(If `dual-write-runtime-md.sh` takes different flags, inspect P02's `m018-p02-dual-write-recent.sh` summary or `scripts/util/dual-write-runtime-md.sh --help` and adjust. The contract is just: both files end up with the same content inside the markers.)

### Step 5 — Author `P03-SUMMARY.md`

Create [`.orchestrator/milestones/M018/phases/P03/P03-SUMMARY.md`](../../../../../milestones/M018/phases/P03/P03-SUMMARY.md) per `templates/phase-summary.md`. The 16-field frontmatter (per MEM013) plus a closure body. Sample shape:

```yaml
---
schema_version: "1.0"
type: phase-summary
id: P03
parent: M018
milestone: M018
provides: "tier1 microcompact live in scripts/dispatch/build-context.sh:_bc_apply_tier1; .orchestrator/cache/tool-results/ SHA-256-keyed cache; tier1_savings_tokens + tier1_invocations additive payload_breakdown fields; scripts/util/cache-prune.sh --max-age <duration> mtime-based eviction; tier_preservation_violation JSONL record schema (additive, shared with future P04/P06); compression.tier1.* config keys"
requires: "P02 preservation-check library + payload_breakdown schema + payload_filter record (DEP — P02)"
affects: "P04 (T2 snip — same library, additive tier2_savings_tokens; reads tier_preservation_violation record schema as established here); P05 (eval harness — reads tier1 records); P06 (T3 auto-compact — same record-schema invariants)"
key_files: "scripts/dispatch/build-context.sh;scripts/util/cache-prune.sh;.orchestrator/config.yml;tests/fixtures/m018-p03-tool-result/dispatch-payload-fixture.md;scripts/verify/m018-p03-tier1-paging.sh;scripts/verify/m018-p03-cache-reuse.sh;scripts/verify/m018-p03-emitter-additivity.sh;scripts/verify/m018-p03-cache-prune.sh;scripts/verify/m018-p03-disable-flag-honored.sh;scripts/verify/m018-p03-preservation-self-check.sh;scripts/verify/m018-p03-dual-write-recent.sh"
key_decisions: "Tier 1 awk-driven single-pass paging (AP-009 compliant; mirrors P02 filter shape); SHA-256(command + 0x1F + input) cache key — full digest, no truncation; cache reuse short-circuits writes (mtime preserved); preservation self-check restores pre-paging body on failure (cache files written during failed pass kept for future reuse); cache-prune mtime-only (reference-aware preservation deferred — current cache key small enough that mtime is correct); _bc_apply_tier1 inline in build-context.sh (single call site, MEM004 carve-out)"
patterns_established: "Single-pass awk pagination with cache-write side-effect (T01); shim-style verifier that source-extracts a single bash function via sed (T03 — usable as P04/P06 verifier pattern)"
drill_down_paths: ".orchestrator/milestones/M018/phases/P03/tasks/T01-tier1-paging-SUMMARY.md;.orchestrator/milestones/M018/phases/P03/tasks/T02-cache-prune-SUMMARY.md;.orchestrator/milestones/M018/phases/P03/tasks/T03-verifiers-and-summary-SUMMARY.md"
duration: "~5h"
verification_result: pass
observability_surfaces: "execution-log.jsonl: payload_breakdown.tier1_savings_tokens additive, payload_breakdown.tier1_invocations additive, tier_preservation_violation record_type"
completed_at: "{{ISO 8601 timestamp}}"
---

# Phase Summary: M018/P03 — Tier 1 Microcompact

## Closure summary
... (≥ 30 lines describing what landed; reference T01/T02/T03 and how they
compose; name the verifier roster; note that filter + tier1 are now both
live in every dispatch).
```

The summary body must include the literal string `tier1_savings_tokens` (artifact-must-have).

### Step 6 — Run the full verifier suite

```
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P03/
```

Expected: every truth `Check:` exits 0; every artifact passes its existence + line-count + substring check; every key link resolves. Output ends with `PASS: all must-haves satisfied for P03`.

If any verifier fails, fix the underlying code (T01/T02 may need touch-ups) and re-run. Do not relax the verifier; the must-have is the contract.

## Must-Haves

(All seven phase-level truths from `P03-PLAN.md` map to T03's verifier files. T03 ships every verifier and the phase summary that closes the must-have set.)

## Verification

- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P03/` — PASS.
- `bash scripts/state/derive-phase.sh .orchestrator/milestones/M018/` — outputs `phase-complete`.

## Inputs

### From Previous Tasks

- `scripts/dispatch/build-context.sh` (from T01) — Key API: `_bc_apply_tier1 <payload_capture_path>` rewrites in place; honors `COMPRESSION_ENABLED`/`TIER1_ENABLED` short-circuit; writes stats to `$TMPDIR_BUILD/_tier1_stats.txt`. `_bc_emit_payload_breakdown` emits `tier1_savings_tokens` and `tier1_invocations` integer fields.
- `.orchestrator/config.yml` (from T01) — carries `compression.tier1.{enabled,inline_threshold_tokens,preview_lines,cache_dir}`.
- `scripts/util/cache-prune.sh` (from T02) — Key API: `cache-prune.sh [--max-age <N>{d|h|m}] [--dry-run]`; reads `compression.tier1.cache_dir` from config; prunes mtime-aged files; idempotent.

### From Disk (Pre-existing)

- `scripts/lib/preservation-check.sh` — `pres_check_section`, `pres_emit_violation` (P02 library; T03 verifier 3.6 stubs both for the failure-path test).
- `tests/fixtures/m018-p02-baseline-payload.golden.txt` — golden payload re-used by verifier 3.5 disable-flag check.
- `scripts/util/dual-write-runtime-md.sh` — used in Step 4 to refresh CLAUDE.md + AGENTS.md.
- `scripts/verify/check-must-haves.sh` — phase-level verifier dispatcher; reads `P03-PLAN.md` truths and runs each Check.
- `templates/phase-summary.md` — base for `P03-SUMMARY.md` authoring.

## Constraints

- **AD-19 (single-script-file shape)**: every truth `Check:` IS a single-script-file invocation. T03's seven verifiers ARE those scripts; no inline compound bash, no plain subshells in verifier-body Check commands.
- **AP-009**: every verifier complies with the bash shape guard. Heredocs to `cat >` files: OK. `printf '%s\n' "$VAR" | grep -q PATTERN`: a single pipe, OK. `$(cmd | cmd)` inside the verifier-script body: BANNED.
- **Constitution Principle VI**: the only files T03 mutates outside the phase directory are `CLAUDE.md` + `AGENTS.md` (Step 4 dual-write — additive bullet inside the markers). All other touches are under `.orchestrator/milestones/M018/phases/P03/`, `tests/fixtures/m018-p03-tool-result/`, and `scripts/verify/`.
- **CON-5 (additive emitters)**: T03's `m018-p03-emitter-additivity.sh` enforces this contract — pre-T01 fields still present; new fields are additions, not replacements.
- **Verifier independence**: each verifier stages its own `mktemp -d` fixture root and cleans up via the OS's tmp-cleanup. No verifier shares state with another.

## Expected Output

- All seven verifier scripts under `scripts/verify/m018-p03-*.sh` exist, are executable, AP-009-clean, and exit 0 on PASS.
- `tests/fixtures/m018-p03-tool-result/dispatch-payload-fixture.md` exists.
- `tests/fixtures/m018-p03-tool-result/README.md` exists.
- `scripts/verify/_helpers/m018-p03-build-fixture.sh` exists and is executable.
- [`.orchestrator/milestones/M018/phases/P03/P03-SUMMARY.md`](../../../../../milestones/M018/phases/P03/P03-SUMMARY.md) exists, ≥ 40 lines, contains `tier1_savings_tokens`.
- `CLAUDE.md` + `AGENTS.md` `recent-changes` blocks both name M018/P03 (or tier1).
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P03/` exits 0; output ends with `PASS: all must-haves satisfied`.
- `bash scripts/state/derive-phase.sh .orchestrator/milestones/M018/` outputs `phase-complete`.

## State Context

- **Current State**: executing
- **Milestone**: M018
- **Phase**: P03
- **Task**: T03-verifiers-and-summary
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **AD-19 (single-script-file shape)**: every truth `Check:` IS a single-script-file invocation. T03's seven verifiers ARE those scripts; no inline compound bash, no plain subshells in verifier-body Check commands.
- **AP-009**: every verifier complies with the bash shape guard. Heredocs to `cat >` files: OK. `printf '%s\n' "$VAR" | grep -q PATTERN`: a single pipe, OK. `$(cmd | cmd)` inside the verifier-script body: BANNED.
- **Constitution Principle VI**: the only files T03 mutates outside the phase directory are `CLAUDE.md` + `AGENTS.md` (Step 4 dual-write — additive bullet inside the markers). All other touches are under `.orchestrator/milestones/M018/phases/P03/`, `tests/fixtures/m018-p03-tool-result/`, and `scripts/verify/`.
- **CON-5 (additive emitters)**: T03's `m018-p03-emitter-additivity.sh` enforces this contract — pre-T01 fields still present; new fields are additions, not replacements.
- **Verifier independence**: each verifier stages its own `mktemp -d` fixture root and cleans up via the OS's tmp-cleanup. No verifier shares state with another.

### Acceptance Criteria

(All seven phase-level truths from `P03-PLAN.md` map to T03's verifier files. T03 ships every verifier and the phase summary that closes the must-have set.)

### Files To Touch

- `scripts/dispatch/build-context.sh` (modify) — add `compression.tier1.*` config reads, the paging + cache-lookup function, the additive `tier1_*` fields on `_bc_emit_payload_breakdown`, and the post-paging `pres_check_section` invocation
- `scripts/util/cache-prune.sh` (create) — new utility script
- `.orchestrator/config.yml` (modify) — append `compression.tier1.*` block under the existing `compression:` map
- `tests/fixtures/m018-p03-tool-result/dispatch-payload-fixture.md` (create) — fixture payload with one oversized inline tool-result block plus one undersized one
- `tests/fixtures/m018-p03-tool-result/README.md` (create) — fixture description
- `scripts/verify/m018-p03-tier1-paging.sh` (create)
- `scripts/verify/m018-p03-cache-reuse.sh` (create)
- `scripts/verify/m018-p03-emitter-additivity.sh` (create)
- `scripts/verify/m018-p03-cache-prune.sh` (create)
- `scripts/verify/m018-p03-disable-flag-honored.sh` (create)
- `scripts/verify/m018-p03-preservation-self-check.sh` (create)
- `scripts/verify/m018-p03-dual-write-recent.sh` (create)
- `scripts/verify/_helpers/m018-p03-build-fixture.sh` (create) — fixture-staging helper
- [`.orchestrator/milestones/M018/phases/P03/P03-SUMMARY.md`](../../../../../milestones/M018/phases/P03/P03-SUMMARY.md) (create)
- `CLAUDE.md` (modify) — refresh `orchestrator:recent-changes` block to name M018/P03
- `AGENTS.md` (modify) — same content (dual-write via `scripts/util/dual-write-runtime-md.sh`)

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