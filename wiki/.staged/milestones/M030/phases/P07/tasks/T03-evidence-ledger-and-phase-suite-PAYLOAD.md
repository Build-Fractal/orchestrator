---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T03-evidence-ledger-and-phase-suite (Phase P07, Milestone M030)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-978 | ~300 | required |
| Upstream Context | 980-1279 | ~16800 | required |
| Task Plan | 1281-1588 | ~4600 | required |
| State Context | 1590-1596 | ~100 | required |
| First-Turn Completeness | 1598-1647 | ~900 | required |
| **Total** | | **~33500** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 685
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
hit_count: 685
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
hit_count: 685
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
hit_count: 685
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
hit_count: 604
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
hit_count: 604
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
hit_count: 604
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
hit_count: 685
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
hit_count: 604
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
hit_count: 604
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
hit_count: 604
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
hit_count: 685
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
hit_count: 685
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
hit_count: 685
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
hit_count: 604
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
hit_count: 604
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
hit_count: 604
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
hit_count: 685
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
hit_count: 604
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
hit_count: 604
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
hit_count: 685
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
hit_count: 685
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
hit_count: 604
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
hit_count: 604
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
hit_count: 604
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
hit_count: 259
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
hit_count: 259
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
hit_count: 259
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
hit_count: 261
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
hit_count: 261
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
hit_count: 251
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
     Project-owned per-phase verifiers live under tools/verify/ with
     slug-bearing filenames (p07-*) so install-clobber risk is contained
     ([M032](../../../../../milestones/M032/index.md) Finding A discipline).

     P07 is the M030 milestone-close gate. Four tasks total:
       T01 — acceptance-corpus synthesizer + 4 corpus fixtures (50/class
             + zero + 2-class-only + block) + per-verdict gates.
       T02 — run-acceptance-battery.sh end-to-end SC runner + 14 SC
             delegators (mostly wrapping existing P0N verifiers) + the
             new at-scale gates + cross-surface coherence gate.
       T03 — M030-ACCEPTANCE-EVIDENCE.md ledger + evidence-ledger shape
             gate + p07-phase-suite.sh aggregator.
       T04 — milestone close ceremony (P07-SUMMARY.md + phase-grain
             unit_close + mark-complete.sh + M030-SUMMARY.md +
             milestone-grain unit_close + recent-changes dual-write +
             close commit + final validate-milestone.sh clean pass).

<dispatch-volatile>

## Upstream Context


### P02 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P02"
parent: "M030"
milestone: "M030"
provides:
  - "tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl,tests/fixtures/m030-p02/round-trip-stage/,tools/verify/p02-fixture-shape.sh,tools/verify/p02-additive-schema.sh,dispatch-interface.sh shadow hook (M030_SHADOW_MODE+CLAUDECODE gated classifier+routing-table emit),4 additive JSONL fields (model_routed,model_used,partial_flip_active,withheld_classes),tools/verify/p02-shadow-emit.sh,tools/verify/p02-con3-closure.sh,tools/verify/p02-append-only.sh,scripts/diagnostics/shadow-compare.sh (4-verdict aggregator),tools/verify/p02-shadow-compare-verdicts.sh,tools/verify/p02-partial-flip-enum.sh,tools/verify/p02-stability-metric-traceability.sh,tools/verify/p02-sc3a-roundtrip.sh,5 shadow-corpus JSONL fixtures,classifier_confidence additive field on dispatch-interface.sh shadow-on emit,tools/verify/p02-phase-suite.sh straight-line aggregator over 9 P02 sub-gates; CLAUDE.md+AGENTS.md recent-changes P02-close fragment"
requires:
  - "P01"
affects:
  - "P03,P04,P05,P06,P07"
key_files:
  - "tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl,tests/fixtures/m030-p02/round-trip-stage/phases/P01/tasks/M001-T01-stage-PLAN.md,tests/fixtures/m030-p02/round-trip-stage/phases/P01/tasks/T01-stage-PAYLOAD.md,tests/fixtures/m030-p02/round-trip-stage/intensity-metadata.txt,tools/verify/p02-fixture-shape.sh,tools/verify/p02-additive-schema.sh,scripts/dispatch/dispatch-interface.sh,tools/verify/p02-shadow-emit.sh,tools/verify/p02-con3-closure.sh,tools/verify/p02-append-only.sh,scripts/diagnostics/shadow-compare.sh,tools/verify/p02-shadow-compare-verdicts.sh,tools/verify/p02-partial-flip-enum.sh,tools/verify/p02-stability-metric-traceability.sh,tools/verify/p02-sc3a-roundtrip.sh,tests/fixtures/m030-p02/shadow-corpus-ready.jsonl,tests/fixtures/m030-p02/shadow-corpus-partially-ready.jsonl,tests/fixtures/m030-p02/shadow-corpus-evidence-insufficient.jsonl,tests/fixtures/m030-p02/shadow-corpus-block.jsonl,tests/fixtures/m030-p02/sc3a-roundtrip-corpus.jsonl,tools/verify/p02-phase-suite.sh,CLAUDE.md,AGENTS.md,[.orchestrator/milestones/M030/phases/P02/P02-PLAN.md](../../../../../milestones/M030/phases/P02/P02-PLAN.md)"
key_decisions:
  - "SC-11 byte-equality verifier authored before T02 amends dispatch-interface.sh (graduation-verifier pattern reused from P01/T01); pricing-warning + adapter-failed shapes covered via fixture-presence grep only -- full round-trip would require stale-pricing-rate or crashing-adapter setup,both out-of-scope for byte-equality gate; payload sized to exactly 4096B so chars_to_tokens_quartile=1024 deterministically matches fixture record 1; round-trip plan basename includes M001 token so MILESTONE_ID regex extraction succeeds without restructuring tests/fixtures/ tree,dual-printf-branch-per-emit-side preserves SC-11 byte-equality mechanically;awk-section-walker (P01 pattern) extracts routing+resolution at dispatch time;CC-only short-circuit gated by CLAUDECODE=1 AND M030_SHADOW_MODE=1;partial_flip_active=false / withheld_classes=empty as P03/P04 schema reservation,D-A1-4-verdict-closed-enum;D-A3-partial-flip-safety-smart-default-only;D-A7-SC-3a-write-path-correctness;classifier_confidence-field-end-to-end-in-P02-not-deferred-to-P03,phase-suite-shape-mirrors-p01-straight-line-AD-19-no-loops; plan-side-grep-amendments-tier-symbols-not-character-labels-CON-3; plan-side-key-link-direction-corrections-dispatch-interface-references-upstreams"
patterns_established:
  - "round-trip-byte-equality fixture pattern: committed payload+plan+intensity-metadata stage with deterministic byte length; ORCHESTRATOR_ROOT carve-out routes log to staged dir; timestamp-normalization sed before diff yields full byte-equality minus the dynamic field; tools/verify/p02-* slug-bearing filenames per project-owned-verifier-paths discipline; AD-19 single-script-file shape preserved with parallel grep-q + rc captures (no compound chains),dual-format-string emit branches (shadow-on adds 4 trailing fields; shadow-off byte-identical to pre-amendment);CON-3 closure verifier compares HEAD-vs-working-tree per-pattern grep counts (no new provider model-ID literals);append-only verifier asserts inode + first-N-lines + line-count delta = +1,awk-section-walker-extended-to-tier-to-class-inverse-map;tmp-file-staging-for-routing-map-to-bypass-macos-awk-multiline-v-limit;SSOT-numeric-traceability-via-awk-line-content-predicate-not-grep-line-number-prefix;per-record-loop-unrolled-into-explicit-blocks-AD-19;classifier-confidence-end-to-end-from-classifier-emit-to-shadow-record-to-variance-aggregator,phase-suite-aggregator-extends-from-7-to-9-gates-without-shape-change; plan-amendment-pattern-when-must-haves-grep-fails-but-phase-suite-green"
drill_down_paths:
  - "[.orchestrator/milestones/M030/phases/P02/tasks/T01-SUMMARY.md](../../../../../milestones/M030/phases/P02/tasks/T01-SUMMARY.md), [.orchestrator/milestones/M030/phases/P02/tasks/T02-dispatch-shadow-hook-SUMMARY.md](../../../../../milestones/M030/phases/P02/tasks/T02-dispatch-shadow-hook-SUMMARY.md), [.orchestrator/milestones/M030/phases/P02/tasks/T03-shadow-compare-SUMMARY.md](../../../../../milestones/M030/phases/P02/tasks/T03-shadow-compare-SUMMARY.md), [.orchestrator/milestones/M030/phases/P02/tasks/T04-phase-suite-and-close-SUMMARY.md](../../../../../milestones/M030/phases/P02/tasks/T04-phase-suite-and-close-SUMMARY.md)"
duration: "245m"
verification_result: "pass"
completed_at: "2026-04-30T14:35:53Z"
observability_surfaces:
  - "none"
---

## P02: Shadow-Mode Telemetry + Routing Verifier Suite

P02 builds the shadow-mode emit path on top of P01's classifier and routing table, then closes with a 9-gate phase-suite verifier that locks every property into a single mechanical aggregator.

### What was built

**T01 — pre-M030 dispatch_usage fixture + additive-schema gate (preflight, shipped pre-P02 in commit `91a743e`).** Hand-authored 5-record JSONL at `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` covering happy-path / pricing-warning / adapter-failed / cost-null / latest-baseline shapes. SC-11 byte-equality verifier `tools/verify/p02-additive-schema.sh` round-trips the fixture's first record through `dispatch-interface.sh` under `M030_SHADOW_MODE=0`, normalizes the dynamic timestamp, and asserts byte-identity. Round-trip stage at `tests/fixtures/m030-p02/round-trip-stage/` provides a deterministic 4096B payload + intensity-metadata fixture so `chars_to_tokens_quartile=1024` matches mechanically. Authoring the verifier *before* T02 amended the emitter is the graduation-verifier pattern reused from P01/T01.

**T02 — dispatch-interface shadow hook + 4-field schema (commit `6d23af5`).** Amended `scripts/dispatch/dispatch-interface.sh` with a CC-only shadow path gated on `M030_SHADOW_MODE=1 && CLAUDECODE=1`. The hook calls `scripts/dispatch/classify-task.sh`, walks `templates/model-routing.yml`'s `routing:` + `resolution:` blocks via an awk section-walker (extending the P01 pattern), and emits four additive fields: `model_routed` (symbolic routing-table choice), `model_used` (runtime default in shadow mode), `partial_flip_active=false`, `withheld_classes=` (both reserved for P03/P04). Dual format-string branches preserve SC-11 byte-equality: shadow-off emits the pre-amendment line literal-for-literal; shadow-on appends the four fields. Zero new provider model-ID literals introduced — every concrete model identifier resolves through `templates/model-routing.yml`. Closes CON-3 mechanically.

**T03 — shadow-compare 4-verdict aggregator + classifier-confidence end-to-end (commit `3936738`).** New `scripts/diagnostics/shadow-compare.sh` consumes shadow JSONL corpora and emits exactly one `flip_recommendation=` line drawn from the closed enum `{ready, partially_ready, block, evidence_insufficient}` (D-A1). Partial-flip safety: only classes whose routing-table default is `smart` may be enumerated in `withheld_classes` (D-A3). Pinned stability-metric numerics (variance ≤ 0.10, N=20, per-class coverage 50) traceable to `references/model-routing.md` SSOT via inline reference comments — verified by per-line content predicate (not `grep -n` line-number-prefix, which produces false-positive substring matches). T03 also amended `dispatch-interface.sh` to emit `classifier_confidence` end-to-end so the variance-stability check is genuinely usable in P02 rather than deferred to P03 (D-A7 / SC-3a write-path correctness).

**T04 — phase-suite aggregator + close prep (commit `55ebeea`).** `tools/verify/p02-phase-suite.sh` invokes all nine sub-gates in literal sequence (`set -uo pipefail`, no loops, `$?` capture per sub-gate, single `SUMMARY:` line) — same straight-line shape as `p01-phase-suite.sh`. CLAUDE.md + AGENTS.md recent-changes fragment via `dual-write-runtime-md.sh --append-entry`. Plan-side amendments to `P02-PLAN.md` resolved 4 `check-must-haves.sh` gaps that were artifact-grep / key-link-direction errors, not task re-opens (per Step-7 plan rule).

### Verification

- `tools/verify/p02-phase-suite.sh` → pass=9 fail=0 (fixture-shape 23/0, additive-schema 6/0, shadow-emit 17/0, con3-closure 7/0, append-only 4/0, shadow-compare-verdicts 4/0, partial-flip-enum 6/0, stability-metric-traceability 3/0, sc3a-roundtrip 6/0)
- `scripts/verify/check-must-haves.sh` → 10 truths + 49 artifacts + 9 key-links all PASS
- `P02-VERIFICATION.md` → overall_result=pass (Tier 1 pass=69/69; Tier 2/3/4 skip)

### Key decisions

- **D-A1 closed-enum 4-verdict**: `flip_recommendation` ∈ `{ready, partially_ready, block, evidence_insufficient}` — no string-interpolation, no open enumeration.
- **D-A3 partial-flip safety**: only `smart`-defaulted classes may be enumerated in `withheld_classes` — fast / balanced classes either flip wholesale or block.
- **D-A7 / SC-3a**: re-classifying the plan path of any shadow record's `unitId` MUST agree with the recorded `model_routed` — verified end-to-end via `tools/verify/p02-sc3a-roundtrip.sh` over a 6-record fixture (2 fast / 2 balanced / 2 smart).
- **Classifier-confidence in P02, not P03**: the variance-stability metric requires per-record confidence; emitting it end-to-end now means P03 can land its variance aggregator without re-amending the emitter.
- **Phase-suite shape mirrors P01**: straight-line, no loops, AD-19-clean.

### Patterns established

- Dual-format-string emit branches preserve byte-equality across additive schema changes — the shadow-off branch is byte-identical to pre-amendment; shadow-on appends fields after the existing set.
- CON-3 closure verifier compares HEAD vs working-tree per-pattern grep counts so the closure constraint can be re-checked on every commit cycle without snapshot drift.
- Append-only JSONL verification via inode preservation + first-N-lines bit-identity + line-count delta = +1.
- AD-19 single-script-file shape preserved through parallel `grep -q` + return-code captures rather than compound `&&`/`||` chains; per-record corpora unrolled into explicit blocks rather than `for` loops.
- Plan-amendment-not-task-reopen pattern when phase-suite is green but `check-must-haves.sh` fails on artifact-grep or key-link-direction.

### Provides downstream

- `dispatch-interface.sh` shadow path + 5 emitted fields → P03 shadow-compare aggregator over real auto-loop telemetry corpus
- `shadow-compare.sh` → P04 partial-flip activation gate
- 9 P02 verifiers + classifier_confidence emit → P03/P04/P05/P06/P07 reuse without re-amendment

### Phase metrics

- 4 tasks (T01 preflight + T02 + T03 + T04)
- Duration: ~245m total dispatch + verify + close
- Phase verification: pass (Tier 1 69/69)
- 0 task re-opens (T04 plan-side-amendment pattern resolved must-have gaps cleanly)


### P03 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P03"
parent: "M030"
milestone: "M030"
provides:
  - "tests/fixtures/m030-p03/plans/ (3 fixture plans),tests/fixtures/m030-p03/configs/ (4 fixture configs),tests/fixtures/m030-p03/round-trip-stage/ (intensity-metadata.txt + payload.txt),tools/verify/p03-additive-schema.sh (P02 SC-11 pass-through),tools/verify/p03-override-source-enum.sh (5-scenario closed-enum gate pre-amendment-tolerant),dispatch-interface.sh override-resolution path (kill-switch->plan-frontmatter->milestone-floor->none precedence chain),_di_tier_rank helper,2 shadow-on printf format-string extensions adding override_source field,4 new T02 verifiers (p03-sc7-kill-switch.sh p03-sc7a-compound.sh p03-min-tier-floor.sh p03-con3-closure.sh),tools/verify/p03-sc6-frontmatter-override.sh (SC-6 gate FR-11),tools/verify/p03-override-conflict.sh (FR-14 floor-wins gate),references/model-routing.md ## Operator Overrides section + 2 ## See Also bullets,tools/verify/p03-phase-suite.sh straight-line aggregator over 8 P03 sub-gates; CLAUDE.md+AGENTS.md recent-changes P03-close fragment; P03 close commit d70386d"
requires:
  - "P02"
affects:
  - "P04,P07"
key_files:
  - "tests/fixtures/m030-p03/plans/plan-with-frontmatter-override.md,tests/fixtures/m030-p03/plans/plan-mechanical-no-override.md,tests/fixtures/m030-p03/plans/plan-frontmatter-fast-vs-floor.md,tests/fixtures/m030-p03/configs/config-baseline.yml,tests/fixtures/m030-p03/configs/config-with-routing-disabled.yml,tests/fixtures/m030-p03/configs/config-with-min-tier-smart.yml,tests/fixtures/m030-p03/configs/config-with-killswitch-and-floor.yml,tests/fixtures/m030-p03/round-trip-stage/intensity-metadata.txt,tests/fixtures/m030-p03/round-trip-stage/payload.txt,tools/verify/p03-additive-schema.sh,tools/verify/p03-override-source-enum.sh,scripts/dispatch/dispatch-interface.sh,tools/verify/p03-sc7-kill-switch.sh,tools/verify/p03-sc7a-compound.sh,tools/verify/p03-min-tier-floor.sh,tools/verify/p03-con3-closure.sh,tools/verify/p03-sc6-frontmatter-override.sh,tools/verify/p03-override-conflict.sh,references/model-routing.md,tools/verify/p03-phase-suite.sh,CLAUDE.md,AGENTS.md,[.orchestrator/milestones/M030/phases/P03/P03-PLAN.md](../../../../../milestones/M030/phases/P03/P03-PLAN.md),[.orchestrator/milestones/M030/phases/P03/tasks/T01-fixtures-and-enum-gate-PLAN.md](../../../../../milestones/M030/phases/P03/tasks/T01-fixtures-and-enum-gate-PLAN.md),[.orchestrator/milestones/M030/phases/P03/tasks/T02-override-resolution-PLAN.md](../../../../../milestones/M030/phases/P03/tasks/T02-override-resolution-PLAN.md),[.orchestrator/milestones/M030/phases/P03/tasks/T03-sc6-and-conflict-PLAN.md](../../../../../milestones/M030/phases/P03/tasks/T03-sc6-and-conflict-PLAN.md),[.orchestrator/milestones/M030/phases/P03/tasks/T04-phase-suite-and-close-PLAN.md](../../../../../milestones/M030/phases/P03/tasks/T04-phase-suite-and-close-PLAN.md)"
key_decisions:
  - "pre-amendment-tolerant enum check (zero tokens PASS pre-T02; exactly one with enum-valid value PASS post-T02; non-enum or count!=1 FAIL) reuses graduation-verifier pattern from P02/T01; tmp_root staging strategy uses ORCH_ROOT/phases/ carve-out so log routes to <tmp_root>/execution-log.jsonl regardless of fixture-plan path lacking uppercase M### tokens; kill switch placed at config top-level (model_routing_enabled: false) per FR-13 framing; min_tier nested under model_routing per FR-12 (one knob among several); compound config (kill-switch+floor) ships as SC-7a fixture; per-scenario tmp_root + cleanup avoids collisions across parallel runs; tmp-file intermediates throughout (no cmd-pipe-grep-pipe-head chains) per AP-009; expected-value parameter in _check_enum_tolerant tightens post-T02 assertion without breaking pre-amendment-tolerance,config-resolution-three-candidate-paths-ORCH_ROOT-config-yml-then-ORCH_ROOT-dot-orchestrator-config-yml-then-ORCH_ROOT-parent-config-yml,shadow_used-equals-model-runtime-default-channel-under-disabled-recommended-populate-explicitly-shape,floor-wins-conflict-uses-numeric-tier-rank-comparison-with-minus-one-unknown-guard,override-resolution-block-runs-before-routing-extraction-three-mutually-exclusive-post-block-awk-paths,references-doc-Operator-Overrides-section-lands-in-P03-not-P05-to-close-operator-visibility-loop-the-moment-T02-emitter-ships,CON-3-enforced-via-runtime-awk-extraction-of-resolution-smart-claude-code-from-templates-model-routing-yml-not-hardcoded-literal,no-dispatch-interface-change-FR-14-warning-already-authored-in-T02-T03-only-ships-the-gate-verifier-and-the-references-doc-edit,references-doc-is-SSOT-for-warning-string-shape-future-amendments-must-re-align-dispatch-interface,phase-suite-shape-mirrors-p02-straight-line-AD-19-no-loops; sub-gate-ordering-fundamental-contract-first-then-enum-then-con3-then-scenarios-then-fr14-conflict-last; no-plan-side-amendments-needed-check-must-haves-clean-first-try; dual-write-helper-requires-marker-flag-payload-example-was-shorthand"
patterns_established:
  - "pre-amendment-tolerant verifier pattern: zero-tokens-PASS branch + exactly-one-with-enum-valid-value-PASS branch; SAME verifier file flips from tolerant to strict as the deliverable that satisfies it lands; ORCH_ROOT/phases carve-out exploited for fixture log-routing without restructuring tests/fixtures/ to encode uppercase M###; per-scenario tmp_root+cleanup with mktemp -d fallback; 5-scenario closed-enum coverage shape (4 shadow-on overlay-product + 1 shadow-off most-overlay-rich strict-zero); pass-through wrapper pattern (p03-additive-schema.sh delegates to p02-additive-schema.sh) for phase-suite friendliness without duplicating round-trip logic,override-resolution-before-routing-extraction-shape,stderr-warning-emission-inside-emitter-body-with-two-distinct-warning-shapes,per-pattern-HEAD-vs-WT-grep-count-comparison-mirrors-P02-CON3-closure-shape,round-trip-verifier-shape-reused-from-T01-tmp_root-with-dot-orchestrator-config-yml-and-phases-subdir,runtime-extraction-of-expected-literal-from-SSOT-via-awk-section-walker-mirrors-P02-T03-stability-metric-pattern,stderr-capture-via-2-redirect-then-per-pattern-grep-line-count-assertions-AP-009-compliant,operator-facing-precedence-chain-documentation-co-locates-with-gate-verifier-ship-date,phase-suite-aggregator-extends-from-9-gates-P02-to-8-gates-P03-without-shape-change; plan-prediction-quality-improved-after-P02-T04-amendment-cycle-no-amendments-needed-in-P03; payload-quoted-helper-invocations-may-be-shorthand-verify-against-helper-help-text"
drill_down_paths:
  - "[.orchestrator/milestones/M030/phases/P03/tasks/T01-fixtures-and-enum-gate-SUMMARY.md](../../../../../milestones/M030/phases/P03/tasks/T01-fixtures-and-enum-gate-SUMMARY.md), [.orchestrator/milestones/M030/phases/P03/tasks/T02-override-resolution-SUMMARY.md](../../../../../milestones/M030/phases/P03/tasks/T02-override-resolution-SUMMARY.md), [.orchestrator/milestones/M030/phases/P03/tasks/T03-sc6-and-conflict-SUMMARY.md](../../../../../milestones/M030/phases/P03/tasks/T03-sc6-and-conflict-SUMMARY.md), [.orchestrator/milestones/M030/phases/P03/tasks/T04-phase-suite-and-close-SUMMARY.md](../../../../../milestones/M030/phases/P03/tasks/T04-phase-suite-and-close-SUMMARY.md)"
duration: "238m"
verification_result: "pass"
completed_at: "2026-04-30T15:24:30Z"
observability_surfaces:
  - "none"
---

## P03: Operator Overrides — Kill-Switch + Frontmatter + Floor

P03 lands the operator-override surface on top of P02's shadow-mode telemetry: a CC-only override-resolution path inside `dispatch-interface.sh`, an extended `override_source` enum emitted in shadow records, and an `## Operator Overrides` section in `references/model-routing.md` that documents the precedence chain end-to-end.

### What was built

**T01 — fixture plans + overlay configs + override-source-enum gate (commit `7b285a2`).** Three fixture task plans (`plan-with-frontmatter-override.md`, `plan-mechanical-no-override.md`, `plan-frontmatter-fast-vs-floor.md`) drive the SC-6/SC-7/FR-14 scenarios. Four overlay configs (baseline / routing-disabled / min-tier-smart / killswitch-and-floor) provide overlay products. `tools/verify/p03-override-source-enum.sh` is the pre-amendment-tolerant gate (zero-tokens-PASS pre-T02, exactly-one-with-enum-valid-value-PASS post-T02). Round-trip stage (`tests/fixtures/m030-p03/round-trip-stage/`) provides a 466B payload + intensity-metadata. ORCH_ROOT-with-phases carve-out exploited so log routes to `<tmp_root>/execution-log.jsonl` regardless of fixture-plan path lacking uppercase `M###` tokens — established the tmp-root staging pattern reused by all T02/T03 verifiers.

**T02 — override-resolution path + 4 verifiers (commit `4e3d678`).** Amended `scripts/dispatch/dispatch-interface.sh` with the `_di_tier_rank` helper and an override-resolution block (kill-switch → plan-frontmatter → milestone-floor → none) that runs *before* routing-extraction. Two shadow-on printf format-string extensions added the `override_source` field. Four verifiers shipped: `p03-sc7-kill-switch.sh` (config kill-switch wins), `p03-sc7a-compound.sh` (kill-switch + frontmatter compound: kill-switch wins), `p03-min-tier-floor.sh` (`min_tier=smart` floors lower-tier classes), `p03-con3-closure.sh` (zero new provider model-ID literals introduced — closure preserved at runtime via `templates/model-routing.yml` resolution). Config-resolution chain extended to three candidate paths (`$ORCH_ROOT/config.yml` → `$ORCH_ROOT/.orchestrator/config.yml` → `$ORCH_ROOT/../config.yml`).

**T03 — SC-6 + FR-14 + operator-overrides docs (commit `d4646e7`).** `tools/verify/p03-sc6-frontmatter-override.sh` exercises the SC-6 happy-path (frontmatter `model_override` resolves to `templates/model-routing.yml resolution.smart.claude-code` via runtime awk extraction — no hardcoded literals, CON-3-clean). `tools/verify/p03-override-conflict.sh` exercises FR-14 (frontmatter+floor conflict → floor wins, stderr warning shape pinned to "floor wins"). `references/model-routing.md` gains the `## Operator Overrides` section between Stability Metric and See Also: precedence chain table, compound-warning cases, full 5-value `override_source` closed enum (`none` / `disabled` / `plan_frontmatter` / `milestone_floor` / `shadow_gate_blocked`, with `shadow_gate_blocked` reserved for FR-9 / P05). Zero changes to `dispatch-interface.sh` — the FR-14 warning was already authored in T02; T03 ships the gate verifier and the doc.

**T04 — phase-suite aggregator + close (commit `d70386d`).** `tools/verify/p03-phase-suite.sh` invokes all 8 sub-gates in literal sequence (same straight-line shape as `p02-phase-suite.sh`, AD-19-clean, bash 3.2 compatible). CLAUDE.md + AGENTS.md recent-changes fragment via `dual-write-runtime-md.sh --marker recent-changes --append-entry "..."`. `check-must-haves.sh` returned 67 PASS / 0 FAIL on first try — zero plan-side amendments needed (P03 plan predicates were authored cleaner than P02's).

### Verification

- `tools/verify/p03-phase-suite.sh` → pass=8 fail=0 (additive-schema 1/0, override-source-enum 6/0, con3-closure 7/0, sc6-frontmatter-override 4/0, sc7-kill-switch 2/0, sc7a-compound 3/0, min-tier-floor 3/0, override-conflict 5/0)
- `scripts/verify/check-must-haves.sh` → 67 PASS / 0 FAIL (truths + artifacts + key-links)
- `P03-VERIFICATION.md` → overall_result=pass (Tier 1 67/67; Tier 2/3/4 skip)

### Key decisions

- **Pre-amendment-tolerant verifier pattern** carried forward from P02/T01: same verifier file flips from tolerant to strict as the deliverable that satisfies it lands.
- **Override-resolution runs *before* routing-extraction**, with three mutually-exclusive post-block awk paths (frontmatter / floor / none).
- **Floor-wins conflict resolution** uses numeric tier-rank comparison via `_di_tier_rank` with a `-1` unknown-guard.
- **5-value `override_source` enum** closed at P03 close: `none` / `disabled` / `plan_frontmatter` / `milestone_floor` / `shadow_gate_blocked`. The fifth (`shadow_gate_blocked`) is reserved for FR-9 in P05; documenting it now locks the schema so P05 lands without surprise.
- **CON-3 enforced via runtime awk extraction** of `resolution.smart.claude-code` from `templates/model-routing.yml` — no hardcoded literals in either dispatch-interface.sh or the verifiers.
- **References doc is SSOT** for the FR-14 warning string shape; future amendments to `dispatch-interface.sh` must re-align with the doc.
- **Phase-suite shape mirrors P02** straight-line AD-19 (no loops); sub-gate ordering: fundamental contract first, then enum, then CON-3, then scenarios, then FR-14 conflict last.
- **No plan-side amendments needed** — first-try `check-must-haves.sh` clean. The P02/T04 plan-amendment-not-task-reopen pattern was not exercised; planner-template improvements after P02 paid off.

### Patterns established

- Override-resolution before routing-extraction with three mutually-exclusive awk post-block paths.
- Stderr-warning emission inside the emitter body with two distinct warning shapes (kill-switch active / floor wins).
- Per-pattern HEAD-vs-working-tree grep count comparison mirrors P02 CON-3 closure shape.
- Round-trip verifier shape reused from T01 (tmp_root + `.orchestrator/config.yml` + `phases/` carve-out).
- Runtime extraction of expected literals from SSOT via awk section-walker mirrors P02/T03 stability-metric pattern.
- Stderr-capture via `2>` redirect + per-pattern grep line-count assertions, AP-009-compliant.
- Pass-through wrapper pattern (`p03-additive-schema.sh` delegates to `p02-additive-schema.sh`) keeps the phase-suite friendly without duplicating round-trip logic.
- Operator-facing precedence-chain docs co-locate with gate-verifier ship date, closing the operator-visibility loop the moment the emitter ships.

### Provides downstream

- `dispatch-interface.sh` override-resolution path → P04 partial-flip activation (consumes `override_source` enum)
- `references/model-routing.md ## Operator Overrides` section → P07 distribution (operator-readable doc surface)
- 9 P03 verifiers + extended schema → P04 reuse without re-amendment

### Phase metrics

- 4 tasks (T01 → T02 → T03 → T04, strict linear chain)
- Duration: ~238m total dispatch + verify + close
- Phase verification: pass (Tier 1 67/67)
- 0 task re-opens, 0 plan-side amendments
- 4 atomic commits: 7b285a2 (T01) → 4e3d678 (T02) → d4646e7 (T03) → d70386d (T04)


### P04 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P04"
parent: "M030"
milestone: "M030"
provides:
  - "tests/fixtures/m030-p04/plans/ (5 fixture plans),tests/fixtures/m030-p04/configs/ (3 fixture configs),tests/fixtures/m030-p04/round-trip-stage/ (intensity-metadata.txt + payload.txt),tests/fixtures/m030-p04/shadow-corpus-ready.jsonl,tests/fixtures/m030-p04/shadow-corpus-partially-ready.jsonl,tests/fixtures/m030-p04/shadow-corpus-empty.jsonl,tests/fixtures/m030-p04/synthesize-corpora.sh,scripts/dispatch/adapters/backend/stub-fail-n.sh (programmable fail-counter adapter),scripts/dispatch/adapters/backend/stub-record-model.sh (model-flag-recorder adapter),tools/verify/p04-additive-schema.sh (P02 SC-11 pass-through),tools/verify/p04-override-source-enum-extended.sh (6-scenario closed-enum gate pre-amendment-tolerant),scripts/dispatch/dispatch-interface.sh _di_resolve_live_routing helper extracted top-level (idempotent via _DI_RESOLVED),live-routing branch with shadow-compare programmatic flip-gate (FR-9 / D-A2),per-class partial-flip authorization branching (D-A3),conditional --model <id> adapter passing via dual-invocation if/else,kill-switch live: true is inactive stderr warning (CON-4 compound),top-level shadow-gate-blocked dispatcher branch + exit code 7,tools/verify/p04-sc2a-shadow-gate-block.sh,tools/verify/p04-sc3-live-mechanical.sh,tools/verify/p04-partial-flip-routing.sh,tools/verify/p04-con3-live-closure.sh,tools/verify/p04-con4-live-killswitch.sh,override_source enum sixth value shadow_gate_blocked emitted on shadow-on dispatch_usage records (graduates p04-override-source-enum-extended.sh Scenario F to strict),dispatch-interface escalation loop fast-balanced-smart cap=2,_di_tier_at_rank helper,_di_emit_escalation_cap_hit helper,2 additive shadow-on JSONL fields (escalation_count integer 0..2 + escalation_reason verifier_fail-or-empty),escalation_cap_hit record (record_type+unitId+final_count=2+timestamp),5 new T03 verifiers (p04-sc4-escalation-sequence p04-sc5-escalation-cap p04-con5-no-fourth-record p04-con6-prior-records-bit-identical p04-escalation-fields-enum),references/model-routing.md Live Routing section + 2 new See Also bullets,tools/verify/p04-phase-suite.sh straight-line aggregator over 12 P04 sub-gates; CLAUDE.md+AGENTS.md recent-changes P04-close entry; P04 close commit"
requires:
  - "P02,P03"
affects:
  - "P06,P07"
key_files:
  - "tests/fixtures/m030-p04/plans/plan-mechanical-no-override.md,tests/fixtures/m030-p04/plans/plan-fail-twice-then-pass.md,tests/fixtures/m030-p04/plans/plan-fail-three-times.md,tests/fixtures/m030-p04/plans/plan-fail-four-times.md,tests/fixtures/m030-p04/plans/plan-novel-class.md,tests/fixtures/m030-p04/configs/config-with-live-true.yml,tests/fixtures/m030-p04/configs/config-with-live-and-killswitch.yml,tests/fixtures/m030-p04/configs/config-with-live-false.yml,tests/fixtures/m030-p04/round-trip-stage/intensity-metadata.txt,tests/fixtures/m030-p04/round-trip-stage/payload.txt,tests/fixtures/m030-p04/shadow-corpus-ready.jsonl,tests/fixtures/m030-p04/shadow-corpus-partially-ready.jsonl,tests/fixtures/m030-p04/shadow-corpus-empty.jsonl,tests/fixtures/m030-p04/synthesize-corpora.sh,scripts/dispatch/adapters/backend/stub-fail-n.sh,scripts/dispatch/adapters/backend/stub-record-model.sh,tools/verify/p04-additive-schema.sh,tools/verify/p04-override-source-enum-extended.sh,scripts/dispatch/dispatch-interface.sh,tools/verify/p04-sc2a-shadow-gate-block.sh,tools/verify/p04-sc3-live-mechanical.sh,tools/verify/p04-partial-flip-routing.sh,tools/verify/p04-con3-live-closure.sh,tools/verify/p04-con4-live-killswitch.sh,references/model-routing.md,tools/verify/p04-sc4-escalation-sequence.sh,tools/verify/p04-sc5-escalation-cap.sh,tools/verify/p04-con5-no-fourth-record.sh,tools/verify/p04-con6-prior-records-bit-identical.sh,tools/verify/p04-escalation-fields-enum.sh,tools/verify/p04-phase-suite.sh,CLAUDE.md,AGENTS.md,[.orchestrator/milestones/M030/phases/P04/P04-PLAN.md](../../../../../milestones/M030/phases/P04/P04-PLAN.md)"
key_decisions:
  - "six-deliverable single-commit graduation-pattern ships before T02 emitter amendment so the new shadow_gate_blocked enum + SC-11 byte-equality contract are mechanically gated from the moment the diff lands; pre-amendment-tolerant predicate for Scenario F (PASS if shadow_gate_blocked OR any P03 enum value) graduates to strict the moment T02 starts emitting shadow_gate_blocked; Scenarios A-E reuse P03 fixtures verbatim (no duplication); Scenario F uses P04-specific plan + config; tmp_root staging via mktemp -d with /tmp fallback + ORCH_ROOT/phases carve-out (mirrors P03/T01); per-scenario tmp-file intermediates throughout (no cmd-pipe-grep-pipe-head chains per AP-009); shadow-corpus synthesizer committed to disk for reproducibility (idempotent; deterministic ascending timestamps); stub-fail-n read-decrement contract: counter=N -> N exit-1 invocations followed by exit-0 (counter=2 -> rc=1,rc=1,rc=0; CON-5 stops at 3 invocations regardless of counter starting >=3); stub-record-model writes --model flag value to env-configurable file path (CON-3 closure preserved -- adapter does NOT interpret model IDs); STUB_INVOCATION_SENTINEL_DIR documented in stub-fail-n now (rather than retrofit in T03) keeps adapter shape stable across phases; partially_ready corpus sets novel under-threshold (not mechanical/standard) per D-A3 safety because novel routing-default is smart (the conservative tier),extract _di_resolve_live_routing as top-level helper (Option 1 from plan) so dispatcher can run gate-block before adapter invocation; idempotent helper via _DI_RESOLVED sentinel ensures emitter+dispatcher both call cheaply; M030_SHADOW_COMPARE_CORPUS env var as verifier seam (mirrors STUB_FAIL_COUNTER_FILE T01 pattern); dual adapter-invocation if/else preserves word-splitting safety per AD-19 (vs splicing dynamic flags); exit code 7 chosen for shadow_gate_blocked to disambiguate from adapter-failed=5 + adapter-malformed=6; live: true is inactive stderr warning placed inside the kill-switch branch alongside the existing min_tier inactive warning (CON-4 compound symmetry); shadow_gate_blocked verdict short-circuits BEFORE the routing-table awk extraction so no _DI_SHADOW_ROUTED is set (prevents leaking a tier into the shadow_routed JSONL field on gate-block); per-class authorization read-only of withheld_classes from shadow-compare verdict (D-A3 trust boundary; T02 does not re-validate),emit-then-increment ordering: success record on iteration N reads escalation_count=N (number of preceding failures); escalation_reason empty on success and verifier_fail on every failed attempt including cap-hit; CON-5 hard-cap enforced at adapter-invocation site (3rd failure stops loop before 4th adapter call); CON-6 verified via inode-preservation + first-2-lines hash equality after synthetic append (synchronous-dispatch proxy for mid-escalation byte-stability); shadow-off printfs UNTOUCHED (additive-only schema preserves SC-11 byte-equality); _DI_SHADOW_ROUTED + _DI_LIVE_MODEL_FLAG mutated in-place between iterations so _di_emit_dispatch_usage reads new tier values via parent-shell scope; happy-path emit at line 960 gated on escalation_active=0 to prevent duplicate dispatch_usage record on success path; escalation_count + escalation_reason declared at top-level (after ORCH_ROOT) so gate-block path inherits defaults (count=0 reason=empty); references/model-routing.md Live Routing co-locates with gate-verifier ship date mirroring P03/T03 Operator Overrides pattern,phase-suite-shape-mirrors-p03-straight-line-AD-19-no-loops-12-gates; sub-gate-ordering-additive-schema-then-enum-then-con3-then-T02-scenarios-then-T03-escalation-gates; plan-amendment-not-task-reopen-applied-for-2-fixture-plan-T-codes-and-2-shadow-corpus-token-predicates; dual-write-helper-marker-recent-changes-prepends-newest-first"
patterns_established:
  - "six-deliverable graduation-pattern (P02/T01 + P03/T01 lineage extended): fixtures + configs + corpora + stage + stub adapters + tolerant gates ship as one commit BEFORE the emitter amendment; pre-amendment-tolerant Scenario F predicate (case statement accepts strict-token OR pre-amendment-fallback enum values) is a per-scenario shape (older P03 verifier was per-verifier-tolerant); shadow-corpus synthesizer-committed-to-disk for reproducibility (synthesis script + outputs both checked in); stub adapter --model flag accepted in T01 even though dispatch-interface.sh starts passing it only in T02 (forward-compatible adapter shape); ORCH_ROOT/phases carve-out exploited for fixture log-routing without restructuring tests/fixtures/ to encode uppercase M### tokens; per-scenario tmp_root + cleanup with mktemp -d fallback; AD-19 single-script-file shape preserved in all verifiers; MEM004 emitter-internal carve-out applied to stub adapters (pipes/awk permitted in adapter bodies),top-level resolution helper extracted alongside _di_tier_rank consumed by both dispatcher and emitter via top-level _DI_SHADOW_* / _DI_LIVE_* outputs; idempotency-via-sentinel pattern (_DI_RESOLVED=1 short-circuits second call); dual-invocation explicit if/else for conditional CLI flag passing (AD-19 word-split safe); env-var verifier seam (M030_SHADOW_COMPARE_CORPUS) for deterministic corpus injection without polluting CLI; per-stage tmp_root staging for multi-dispatch verifiers (partial-flip routing exercises 2 dispatches in one verifier); runtime-resolution-from-SSOT pattern carried forward (verifiers awk-extract resolution.fast.claude-code from templates/model-routing.yml rather than hardcode literals); HEAD-vs-working-tree per-pattern grep count CON-3 closure pattern reused from P03/T02; tolerant-to-strict graduation pattern (Scenario F flips from any-P03-enum to shadow_gate_blocked-only via observed-token semantics); shadow-gate-blocked exit code 7 for retry/operator escalation distinct from adapter failure modes,MEM004 carve-out extends to dispatch-internal escalation loop body; awk section-walker re-resolves resolution.<tier>.claude-code in-loop without hardcoded literals (CON-3-clean); programmable fail-counter fixture adapter (stub-fail-n.sh) gates SC-4/SC-5/CON-5 via STUB_FAIL_COUNTER_FILE read-decrement + STUB_FAIL_COUNTER_INVOCATIONS_FILE side-channel for invocation-count assertions; tmp-file-staged head-shasum-cut chain unrolling (AP-009 compliant); inode-preservation check via stat -f %i (macOS) with stat -c %i fallback (Linux portability); per-scenario tmp_root + cleanup pattern reused from P03 verifiers,phase-suite-aggregator-extends-from-8-gates-P03-to-12-gates-P04-without-shape-change; plan-amendment-not-task-reopen-precedent-from-P02-T04-and-P03-T04-applied-cleanly-when-fixture-tokens-diverge-from-plan-predicates; corpus-fixture-discriminator-tokens-must-match-actual-content-not-aspirational-class-labels"
drill_down_paths:
  - "[.orchestrator/milestones/M030/phases/P04/tasks/T01-fixtures-and-stubs-SUMMARY.md](../../../../../milestones/M030/phases/P04/tasks/T01-fixtures-and-stubs-SUMMARY.md), [.orchestrator/milestones/M030/phases/P04/tasks/T02-live-routing-flip-gate-SUMMARY.md](../../../../../milestones/M030/phases/P04/tasks/T02-live-routing-flip-gate-SUMMARY.md), [.orchestrator/milestones/M030/phases/P04/tasks/T03-escalation-loop-SUMMARY.md](../../../../../milestones/M030/phases/P04/tasks/T03-escalation-loop-SUMMARY.md), [.orchestrator/milestones/M030/phases/P04/tasks/T04-phase-suite-and-close-SUMMARY.md](../../../../../milestones/M030/phases/P04/tasks/T04-phase-suite-and-close-SUMMARY.md)"
duration: "257m"
verification_result: "pass"
completed_at: "2026-04-30T18:14:22Z"
observability_surfaces:
  - "none"
---

P04 closes the live-routing surface for M030: the dispatch-interface now reads `model_routing.live`, programmatically gates flips through `shadow-compare.sh` (D-A2), enforces per-class partial-flip authorization (D-A3), passes `--model <id>` to backend adapters using runtime-resolution from the `templates/model-routing.yml` SSOT (CON-3), and short-circuits at the kill switch (CON-4 amended / SC-7a-style compound). When `live: true` is set against an empty/blocked corpus the dispatcher refuses to call any adapter and emits `override_source=shadow_gate_blocked` with new exit code 7. Verifier-fail escalation (FR-10) wraps adapter invocation in a fast→balanced→smart loop, capped at 2 escalations (CON-5) — the third failure emits a single `escalation_cap_hit` JSONL record and stops. Each retry produces a NEW `dispatch_usage` record with new timestamp and additive fields `escalation_count` (integer 0..2) + `escalation_reason` (`verifier_fail` or empty); prior records remain bit-identical (CON-6).

T01 (`ddf2a77`) shipped the preflight scaffolding — 5 fixture plans (mechanical / fail-twice-then-pass / fail-three-times / fail-four-times / novel-class), 3 overlay configs (live-true / live-and-killswitch / live-false), 3 shadow corpora (ready / partially-ready / empty) plus an idempotent corpus synthesizer, a round-trip stage, 2 new stub adapters (`stub-fail-n.sh` programmable fail-counter + `stub-record-model.sh` model-flag recorder), and 2 pre-amendment-tolerant gates (`p04-additive-schema.sh` + `p04-override-source-enum-extended.sh` with Scenario F tolerant-then-strict graduation pattern).

T02 (`f77c95d`) extracted `_di_resolve_live_routing` as a top-level dispatch-interface helper (idempotent via `_DI_RESOLVED` sentinel), wired the live-routing branch with programmatic shadow-compare invocation + partial-flip authorization, added dual-invocation if/else for `--model` flag passing (AD-19 word-split safety), placed the `live: true is inactive` stderr warning inside the kill-switch branch (CON-4 compound symmetry), and chose exit code 7 for `shadow_gate_blocked` (disambiguates from adapter-failed=5 / adapter-malformed=6). Co-authored 5 verifiers: SC-2a, SC-3, partial-flip routing, CON-3 (live closure), CON-4 (live + kill-switch compound).

T03 (`02bd29f`) wrapped adapter invocation in the escalation loop with `_di_tier_at_rank` helper and `_di_emit_escalation_cap_hit`, used emit-then-increment ordering so success records carry `escalation_count=N` (preceding failures), and verified CON-6 bit-stability via inode preservation + first-2-lines hash equality. Co-authored 5 verifiers: SC-4 (sequence + escalation_count=2 on third), SC-5 (cap: 3 dispatch records + 1 cap_hit), CON-5 (no fourth on fail-four-times), CON-6 (prior records bit-identical), escalation-fields-enum gate. `references/model-routing.md` gained a `## Live Routing` section co-located with the gate-verifier ship date.

T04 (`c7fbec0`) authored the 12-sub-gate straight-line phase-suite aggregator mirroring P02/P03 shape, dual-wrote the recent-changes block to CLAUDE.md + AGENTS.md via `scripts/util/dual-write-runtime-md.sh`, and committed the close. The plan-amendment-not-task-reopen precedent from P02/T04 + P03/T04 was applied for 4 fixture token-predicate divergences (corpus discriminator tokens must match actual content, not aspirational class labels).

Verification result: phase-suite green pass=12 fail=0 across all sub-gates (SC-3 / SC-4 / SC-5 / SC-2a / partial-flip / CON-3 / CON-4 / CON-5 / CON-6 / SC-11 byte-equality / override-source enum / escalation-fields enum). Upstream P02 + P03 phase-suites remain green (pass=9/0 and pass=8/0). FR-9 / FR-10 / FR-12 / FR-19 mechanically gated. CC-only launch posture preserved (live branch wrapped in `M030_SHADOW_MODE=1 && CLAUDECODE=1` precondition unchanged from P02). Symbolic-tier closure (CON-3) maintained — zero new hardcoded model IDs in dispatch-interface diff (HEAD-vs-WT per-pattern grep).

Patterns established/extended: top-level resolution helper extracted alongside `_di_tier_rank` consumed by both dispatcher + emitter via top-level `_DI_SHADOW_*` / `_DI_LIVE_*` outputs; idempotency-via-sentinel; dual-invocation if/else for conditional CLI flag passing (word-split safe); env-var verifier seam (`M030_SHADOW_COMPARE_CORPUS`, `STUB_FAIL_COUNTER_FILE`, `STUB_FAIL_COUNTER_INVOCATIONS_FILE`) for deterministic fixture injection without polluting CLI; runtime-resolution-from-SSOT in verifiers (awk-extract `resolution.fast.claude-code` from `templates/model-routing.yml` rather than hardcode literals); HEAD-vs-WT per-pattern grep CON-3 closure; tolerant-to-strict graduation per-scenario predicate; six-deliverable preflight-then-amendment graduation pattern (P02/T01 + P03/T01 lineage); MEM004 emitter-internal carve-out extended to dispatch-internal escalation loop body; phase-suite-aggregator-extends-from-8-gates-P03-to-12-gates-P04 without shape change.

Roadmap impact: P04 produces the dispatch-interface live-routing branch + escalation logic + 5 new JSONL fields/records consumed by P05 ([M027](../../../../../milestones/M027/index.md) surface integration: `metrics-rollup.sh --by-model` + efficiency-footer `model_mix:` + doctor `--config-check`) and P06 (anomaly-driven regression detection: rolling-window per-class verifier-fail check). The `escalation_count`/`escalation_reason`/`escalation_cap_hit` records are the signal P06 needs to detect regression at scale. No deviations from the original phase boundary; no upstream replanning required.


### P05 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P05"
parent: "M030"
milestone: "M030"
provides:
  - "tests/fixtures/m030-p05/synthesize-corpus.sh (idempotent),tests/fixtures/m030-p05/live-routed-corpus.jsonl (23 records: 14 fast / 7 balanced / 2 smart),tests/fixtures/m030-p05/no-cost-rates-routing.yml (FR-15 fallback fixture),tests/fixtures/m030-p05/rollup-pre-m030-baseline.txt (golden),tests/fixtures/m030-p05/footer-pre-m030-baseline.txt (golden),tools/verify/p05-sc11-rollup-byte-equality.sh (SC-11 byte-strict gate),tools/verify/p05-sc11-footer-byte-equality.sh (SC-11 byte-strict gate via ORCHESTRATOR_ROOT carve-out),tools/verify/p05-doctor-config-check.sh (SC-9 pass-through wrapper),scripts/diagnostics/metrics-rollup.sh --by-model flag (additive; per-tier dispatch counts + cost_rates-present aggregated_cost_usd + counterfactual_all_smart_cost_usd; cost_rates-absent warning + zero-savings fallback),scripts/diagnostics/efficiency-footer.sh model_mix: line (additive; suppressed on zero shadow-on records — SC-11 mechanism),tools/verify/p05-by-model-dispatch-counts.sh,tools/verify/p05-by-model-cost-rates-present.sh,tools/verify/p05-by-model-cost-rates-absent.sh,tools/verify/p05-model-mix-footer-line.sh,references/model-routing.md ## Cost Rollup Surfaces section,tools/verify/p05-phase-suite.sh straight-line aggregator over 7 P05 sub-gates; CLAUDE.md+AGENTS.md recent-changes P05-close fragment; key-link plan amendment (run-doctor.sh -> doctor.sh); P05 close commit"
requires:
  - "P02"
affects:
  - "P07"
key_files:
  - "tests/fixtures/m030-p05/synthesize-corpus.sh,tests/fixtures/m030-p05/live-routed-corpus.jsonl,tests/fixtures/m030-p05/no-cost-rates-routing.yml,tests/fixtures/m030-p05/rollup-pre-m030-baseline.txt,tests/fixtures/m030-p05/footer-pre-m030-baseline.txt,tools/verify/p05-sc11-rollup-byte-equality.sh,tools/verify/p05-sc11-footer-byte-equality.sh,tools/verify/p05-doctor-config-check.sh,tools/verify/p01-routing-table-shape.sh,scripts/diagnostics/metrics-rollup.sh,scripts/diagnostics/efficiency-footer.sh,references/model-routing.md,tools/verify/p05-by-model-dispatch-counts.sh,tools/verify/p05-by-model-cost-rates-present.sh,tools/verify/p05-by-model-cost-rates-absent.sh,tools/verify/p05-model-mix-footer-line.sh,tools/verify/p05-phase-suite.sh,CLAUDE.md,AGENTS.md,[.orchestrator/milestones/M030/phases/P05/P05-PLAN.md](../../../../../milestones/M030/phases/P05/P05-PLAN.md),[.orchestrator/milestones/M030/phases/P05/tasks/T01-fixtures-and-baselines-PLAN.md](../../../../../milestones/M030/phases/P05/tasks/T01-fixtures-and-baselines-PLAN.md),[.orchestrator/milestones/M030/phases/P05/tasks/T02-rollup-and-footer-amendments-PLAN.md](../../../../../milestones/M030/phases/P05/tasks/T02-rollup-and-footer-amendments-PLAN.md),[.orchestrator/milestones/M030/phases/P05/tasks/T03-phase-suite-and-close-PLAN.md](../../../../../milestones/M030/phases/P05/tasks/T03-phase-suite-and-close-PLAN.md)"
key_decisions:
  - "contingent amendment applied: tools/verify/p01-routing-table-shape.sh check #3 relaxed to require only routing: + resolution: as top-level sections; cost_rates: is now OPTIONAL (FR-15 fallback path requires the rollup to handle absence at runtime; the malformed-fixture path in p01-doctor-config-check.sh keeps cost_rates: present so Scenario B coverage is unchanged); golden baselines captured via Strategy A (ORCHESTRATOR_ROOT carve-out for footer; --log flag direct for rollup); SC-11 gates ship byte-strict from the start (inverts P04/T01 pre-amendment-tolerant pattern -- the goldens themselves carry the contract); doctor-config-check wrapper uses delegate-and-pass-through shape per p04-additive-schema.sh precedent; idempotent synthesizer with deterministic timestamps (loop-index-derived),snapshot-shared dual-emission (rollup branches AFTER snapshot before normalize/aggregate/render — same snapshot reused so FR-19/AD-3 atomicity preserved + SC-11 byte-equality of unflagged path mechanically guaranteed); awk section-walker for cost_rates parsing (2-pass; indent-depth-aware; emits RATES tuple or NO_RATES sentinel); explicit 8-decimal expected values in the cost-rates-present verifier (asserts exact 0.23296000 / 1.23648000 not regex — future drift trips the gate immediately); routing-table path-resolution priority --routing-table flag > M030_ROUTING_TABLE_PATH env > templates/model-routing.yml default; cost_rates-absent is warning-class (exit 0) not hard failure — rollup remains useful as dispatch-count surface; ORCHESTRATOR_ROOT carve-out reuse for model-mix footer gate (mktemp -d + cp + trap-cleanup mirrors T01 SC-11 footer baseline-capture),phase-suite-shape-mirrors-p02-p03-p04-straight-line-AD-19-no-loops; sub-gate-ordering-fundamental-SC11-contracts-first-then-SC9-doctor-then-T02-SC8-and-FR16-scenarios; key-link-amendment-runs-doctor-vs-doctor-conceptual-surface-name; plan-amendment-not-task-reopen-P02-P03-P04-precedent"
patterns_established:
  - "pre-amendment golden-baseline pattern: capture HEAD's unflagged output BEFORE amendment lands; verifier diffs post-amendment output against committed snapshot; ORCHESTRATOR_ROOT carve-out (mktemp -d + cp + trap-cleanup) for footer fixture-routing without modifying the footer's resolver; optional-section discipline for cost_rates: in routing-table-shape verifier (required vs optional split); cross-phase delegate-and-pass-through wrapper (P05/T01 doctor wrapper -> P01/T04 verifier; mirrors P04/T04 -> P02/T04),snapshot-shared dual-emission branch (shared snapshot + by_model_mode=0/1 fork before normalize/aggregate/render),awk-section-walker-for-cost_rates (indent-depth-aware top/2-space-tier/4-space-key parse + RATES tuple or NO_RATES sentinel),footer-side-rollup-internal-invocation (footer invokes metrics-rollup.sh --by-model as subshell + parses dispatch-count line + emits derived footer line),hand-computed-cost-expectations-in-verifier (verifier asserts exact 8-decimal values not regex; verifier header names the formula),ORCHESTRATOR_ROOT-carve-out-reuse-across-T01-and-T02-footer-gates,phase-suite-aggregator-shape-stable-across-P02-P03-P04-P05-no-shape-drift; key-link-checker-greps-basename-target-existence-not-required-only-source-grep-match; on-disk-filename-vs-spec-conceptual-name-divergence-resolved-via-plan-side-key-link-amendment"
drill_down_paths:
  - "[.orchestrator/milestones/M030/phases/P05/tasks/T01-fixtures-and-baselines-SUMMARY.md](../../../../../milestones/M030/phases/P05/tasks/T01-fixtures-and-baselines-SUMMARY.md), [.orchestrator/milestones/M030/phases/P05/tasks/T02-rollup-and-footer-amendments-SUMMARY.md](../../../../../milestones/M030/phases/P05/tasks/T02-rollup-and-footer-amendments-SUMMARY.md), [.orchestrator/milestones/M030/phases/P05/tasks/T03-phase-suite-and-close-SUMMARY.md](../../../../../milestones/M030/phases/P05/tasks/T03-phase-suite-and-close-SUMMARY.md)"
duration: "147m"
verification_result: "pass"
completed_at: "2026-04-30T20:18:52Z"
observability_surfaces:
  - "metrics-rollup-by-model+efficiency-footer-model_mix"
---

P05 closes the M027 surface integration for M030: `metrics-rollup.sh` gains a `--by-model` flag that emits per-tier dispatch counts (fast/balanced/smart from `model_used`) plus an aggregated `cost_usd` line + an all-`smart` `counterfactual_all_smart_cost_usd` savings line when `cost_rates:` is defined in `templates/model-routing.yml`, or a "cost rates not configured" warning + zero-savings fallback line (exit 0) when absent (FR-15 / SC-8). `efficiency-footer.sh` renders a `model_mix:` line at the close of an `orchestrator:auto` run (FR-16). `doctor.sh --config-check` validates routing-table syntax with file+line diagnostics on malformed fixtures (FR-17 / SC-9; the surface itself shipped in P01/T04, P05 adds a delegate-and-pass-through wrapper as `tools/verify/p05-doctor-config-check.sh`). SC-11 byte-equality is preserved through both unflagged surfaces — pre-M030 fixtures produce byte-identical output through `metrics-rollup.sh` (no flag) and `efficiency-footer.sh` (zero shadow-on records suppresses the model_mix block).

T01 (`423498f`) shipped the preflight scaffolding — an idempotent corpus synthesizer + 23 fixture records (14/7/2 over fast/balanced/smart), a no-cost-rates routing-yml fixture, two pre-M030 byte-equality goldens (`rollup-pre-m030-baseline.txt` + `footer-pre-m030-baseline.txt`), three SC-11/SC-9 gates (rollup byte-equality, footer byte-equality, doctor-config-check pass-through wrapper), and a contingent amendment to `tools/verify/p01-routing-table-shape.sh` Check #3 relaxing it from required-`cost_rates:` to optional-`cost_rates:` so the FR-15 fallback path's no-cost-rates fixture is shape-valid. Backward compatibility verified two ways: shipped `templates/model-routing.yml` (cost_rates: present) still passes the shape verifier (pass=8 fail=0); P01 doctor-config-check Scenario B's malformed fixture coverage is unchanged.

T02 (`7ed3081`) amended the surfaces. `metrics-rollup.sh` got a snapshot-shared dual-emission branch — the `--by-model` path forks AFTER the snapshot is captured but BEFORE normalize/aggregate/render, so the same snapshot is reused and FR-19/AD-3 atomicity is preserved while SC-11 byte-equality of the unflagged path is mechanically guaranteed. The branch uses an awk section-walker (2-pass, indent-depth-aware: top-level / 2-space tier / 4-space key) to parse `cost_rates:` and emits either a RATES tuple or a NO_RATES sentinel for downstream branching. A `--routing-table` flag plumbs through with priority `--routing-table > M030_ROUTING_TABLE_PATH env > templates/model-routing.yml default`. Hand-computed expected costs in the present-rates verifier (0.23296000 / 1.23648000 USD) assert exact 8-decimal values rather than regex — any future drift trips the gate immediately. `efficiency-footer.sh` got a `model_mix:` block placed after the compression-line block, suppressed when total dispatches == 0 (load-bearing SC-11 mechanism). The footer invokes `metrics-rollup.sh --by-model` in a subshell and parses the dispatch-count line to emit its derived footer line. Co-authored 4 verifiers (FR-15 sentence 1 / FR-15 sentence 2 + counterfactual / FR-15 sentence 3 fallback / FR-16 footer line) plus a `## Cost Rollup Surfaces` section in `references/model-routing.md`.

T03 (`95fce75`) authored the 7-sub-gate straight-line phase-suite aggregator mirroring P02/P03/P04 shape, dual-wrote the recent-changes block to CLAUDE.md + AGENTS.md via `scripts/util/dual-write-runtime-md.sh`, and committed the close. The plan-amendment-not-task-reopen precedent was applied for one key-link divergence — the phase plan declared `specs/032-adaptive-model-selection/spec.md → scripts/diagnostics/run-doctor.sh` but the spec uses the conceptual name `doctor.sh`; the key-link was amended to `scripts/diagnostics/doctor.sh` with a parenthetical noting the on-disk filename divergence. After amendment the must-haves grep is clean (8 truths + 41 artifacts + 13 key-links all PASS).

Verification result: phase-suite green pass=7 fail=0 across all sub-gates (SC-11 rollup + SC-11 footer + SC-9 doctor-config-check + FR-15 dispatch-counts + FR-15 cost-rates-present + FR-15 cost-rates-absent + FR-16 model_mix). Upstream P01–P04 phase-suites remain green. SC-11 byte-equality of unflagged paths preserved through both `metrics-rollup.sh` and `efficiency-footer.sh`. CON-3 closure preserved (zero new hardcoded model IDs introduced; cost arithmetic indexes exclusively by symbolic tier).

Patterns established/extended: pre-amendment golden-baseline pattern (capture HEAD's unflagged output BEFORE amendment lands; verifier diffs post-amendment against committed snapshot — inverts the P04/T01 pre-amendment-tolerant Scenario F pattern, where the goldens themselves carry the contract); ORCHESTRATOR_ROOT carve-out (mktemp -d + cp + trap-cleanup) for footer fixture-routing without modifying the footer's resolver, reused across T01 SC-11 footer baseline-capture and T02 model-mix footer gate; snapshot-shared dual-emission branch in `metrics-rollup.sh` (shared snapshot + by_model_mode=0/1 fork before normalize/aggregate/render); awk-section-walker-for-cost_rates (indent-depth-aware top/2-space-tier/4-space-key parse + RATES tuple or NO_RATES sentinel); footer-side-rollup-internal-invocation (footer invokes metrics-rollup.sh --by-model as subshell + parses dispatch-count line + emits derived footer line); hand-computed-cost-expectations-in-verifier (8-decimal exact values, not regex; verifier header names the formula); cross-phase delegate-and-pass-through wrapper (P05/T01 doctor wrapper → P01/T04 verifier, mirrors P04/T04 → P02/T04 phase-suite shape); optional-section discipline for cost_rates: in routing-table-shape verifier (required vs optional split); on-disk-filename-vs-spec-conceptual-name divergence resolved via plan-side key-link amendment (rather than renaming the on-disk surface).

Roadmap impact: P05 produces the `metrics-rollup --by-model` + `efficiency-footer model_mix:` + `doctor --config-check` surfaces consumed by P07 (end-to-end shadow-corpus + flip-gate validation) for the M030 acceptance battery. P06 (anomaly-driven regression detection) was already independent of P05 surfaces — it consumes P02 JSONL schema + P04 escalation records, not the rollup/footer flags. No deviations from the original phase boundary; no upstream replanning required.

Performance note (flagged for follow-up, not gating): `p05-doctor-config-check.sh` delegates to `p01-doctor-config-check.sh` which invokes `run-doctor.sh --config-check` twice (Scenario A well-formed + Scenario B malformed). Each invocation runs the full doctor pipeline including `check-plans.sh`, which walks every milestone in `.orchestrator/milestones/`. End-to-end the P05 phase-suite runs in the 8–12-minute range. Shape is correct and gates green; the slow cycle is inherited from M027's doctor surface walking the now-substantial milestone tree. Candidate for an `--isolated` doctor mode in a later milestone (out of scope for M030).


### P06 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P06"
parent: "M030"
milestone: "M030"
provides:
  - "tests/fixtures/m030-p06/synthesize-corpus.sh (idempotent),tests/fixtures/m030-p06/regression-mechanical.jsonl (20 records class=mechanical class_pass_rate=0.40),tests/fixtures/m030-p06/regression-standard.jsonl (20 records class=standard class_pass_rate=0.40),tests/fixtures/m030-p06/regression-novel.jsonl (20 records class=novel class_pass_rate=0.40),tests/fixtures/m030-p06/no-regression.jsonl (60 records 20-per-class all class_pass_rate>=0.80),tests/fixtures/m030-p06/below-min-sample.jsonl (5 mechanical records — sample-floor guard fixture),tests/fixtures/m030-p06/check-anomalies-pre-m030-baseline.txt (golden),scripts/dispatch/dispatch-interface.sh shadow-on character field (additive — SC-11 preserving),scripts/diagnostics/check-anomalies.sh _ca_model_routing_regression_check function + CLI integration + JSONL emit,references/model-routing.md ## Anomaly Records section,tools/verify/p06-sc11-byte-equality.sh,tools/verify/p06-shadow-off-byte-equality.sh,tools/verify/p06-mechanical-regression.sh,tools/verify/p06-standard-regression.sh,tools/verify/p06-novel-regression.sh,tools/verify/p06-no-regression.sh,tools/verify/p06-below-min-sample.sh,tools/verify/p06-doctor-surfaces-anomaly.sh,tools/verify/p06-phase-suite.sh straight-line aggregator over 8 P06 sub-gates,CLAUDE.md+AGENTS.md recent-changes P06-close fragment,plan-amendment relaxing three artifact line-count predicates (standard-regression min 60->50; novel-regression min 60->50; shadow-off-byte-equality min 30->25),P06 close commit"
requires:
  - "P02,P04"
affects:
  - "P07"
key_files:
  - "tests/fixtures/m030-p06/synthesize-corpus.sh,tests/fixtures/m030-p06/regression-mechanical.jsonl,tests/fixtures/m030-p06/regression-standard.jsonl,tests/fixtures/m030-p06/regression-novel.jsonl,tests/fixtures/m030-p06/no-regression.jsonl,tests/fixtures/m030-p06/below-min-sample.jsonl,tests/fixtures/m030-p06/check-anomalies-pre-m030-baseline.txt,scripts/dispatch/dispatch-interface.sh,scripts/diagnostics/check-anomalies.sh,references/model-routing.md,tools/verify/p06-sc11-byte-equality.sh,tools/verify/p06-shadow-off-byte-equality.sh,tools/verify/p06-mechanical-regression.sh,tools/verify/p06-standard-regression.sh,tools/verify/p06-novel-regression.sh,tools/verify/p06-no-regression.sh,tools/verify/p06-below-min-sample.sh,tools/verify/p06-doctor-surfaces-anomaly.sh,tools/verify/p06-phase-suite.sh,CLAUDE.md,AGENTS.md,[.orchestrator/milestones/M030/phases/P06/P06-PLAN.md](../../../../../milestones/M030/phases/P06/P06-PLAN.md),[.orchestrator/milestones/M030/phases/P06/tasks/T01-fixtures-and-baseline-PLAN.md](../../../../../milestones/M030/phases/P06/tasks/T01-fixtures-and-baseline-PLAN.md),[.orchestrator/milestones/M030/phases/P06/tasks/T02-anomaly-check-and-emit-PLAN.md](../../../../../milestones/M030/phases/P06/tasks/T02-anomaly-check-and-emit-PLAN.md),[.orchestrator/milestones/M030/phases/P06/tasks/T03-phase-suite-and-close-PLAN.md](../../../../../milestones/M030/phases/P06/tasks/T03-phase-suite-and-close-PLAN.md)"
key_decisions:
  - "#Q-4 plan-phase decision: fixed pass-rate threshold (default 0.50) + min_class_sample floor (default 10) overridable via .orchestrator/config.yml model_routing_regression.{pass_rate_threshold,min_class_sample}; env-only JSONL emit path (M030_ANOMALIES_JSONL_PATH default .orchestrator/anomalies.jsonl) instead of CLI flag to keep surface narrow,additive character field on shadow-on dispatch_usage records (additive — SC-11-preserving) chosen over fragile tier-to-class inverse routing-table lookup; D-A9 anomaly JSONL snapshot convention satisfied via append-only invariant on .orchestrator/anomalies.jsonl (separate file from execution-log.jsonl preserves CON-6 dispatch-stream invariant),phase-suite-shape-mirrors-p02-p03-p04-p05-straight-line-AD-19-no-loops; sub-gate-ordering-fundamental-SC11-contracts-first-then-FR18-positive-then-FR18-negative-and-sample-floor-then-doctor-surface-integration; plan-amendment-not-task-reopen-applied-for-two-artifact-line-count-predicates"
patterns_established:
  - "additive-field-on-shadow-on-emit pattern (P02/T02 + P04/T03 lineage extended): single field appended to printf format string + arg list on shadow-on branch only; shadow-off branch byte-untouched; SC-11 contract via P02 p02-additive-schema.sh delegate-and-pass-through wrapper,env-var-seam-for-anomaly-jsonl-redirection (M030_ANOMALIES_JSONL_PATH; mirrors M030_SHADOW_MODE / M030_SHADOW_COMPARE_CORPUS / M030_ROUTING_TABLE_PATH precedents),append-only anomalies.jsonl emit via >> redirect with mkdir -p guard; CON-6 invariant extended from execution-log.jsonl to anomalies.jsonl with separate-file boundary,phase-suite-aggregator-extends-from-7-gates-P05-to-8-gates-P06-without-shape-change,rolling-window-per-class-verifier-fail-rate-check shape: awk-grouped pass on shadow-on records grouped by character field; emits FLAGGED text + JSONL only when class_sample >= min_class_sample AND class_pass_rate < threshold; pre-P06 records (no character field) silently skipped"
drill_down_paths:
  - "[.orchestrator/milestones/M030/phases/P06/tasks/T01-fixtures-and-baseline-PLAN.md](../../../../../milestones/M030/phases/P06/tasks/T01-fixtures-and-baseline-PLAN.md), [.orchestrator/milestones/M030/phases/P06/tasks/T02-anomaly-check-and-emit-PLAN.md](../../../../../milestones/M030/phases/P06/tasks/T02-anomaly-check-and-emit-PLAN.md), [.orchestrator/milestones/M030/phases/P06/tasks/T03-phase-suite-and-close-PLAN.md](../../../../../milestones/M030/phases/P06/tasks/T03-phase-suite-and-close-PLAN.md)"
duration: "49m"
verification_result: "pass"
completed_at: "2026-05-01T01:33:04Z"
observability_surfaces:
  - "check-anomalies-model-routing-regression+anomalies.jsonl"
---

P06 closes the FR-18 anomaly-driven regression detection surface for M030: `scripts/diagnostics/check-anomalies.sh` gains a per-class rolling-window verifier-fail-rate check that emits a `model_routing_regression` anomaly record (text + JSONL) when a class crosses the configured threshold (default pass_rate 0.50, min_class_sample 10; both overridable via `.orchestrator/config.yml model_routing_regression.{pass_rate_threshold,min_class_sample}`). The text line surfaces through `orchestrator:doctor` via the existing M027 "Anomaly Detection" advisory invocation — `run-doctor.sh` already calls `check-anomalies.sh` and renders its stdout, so no doctor-side amendment was required. The JSONL emit lands in `.orchestrator/anomalies.jsonl` by default (or the path passed via `M030_ANOMALIES_JSONL_PATH` env), kept separate from `execution-log.jsonl` to preserve the CON-6 dispatch-stream invariant. `scripts/dispatch/dispatch-interface.sh` shadow-on emit branch gains a single additive `character` field that the new check consumes for per-class grouping; the shadow-off branch is byte-untouched, preserving SC-11.

T01 (`dcbcb69`) shipped the preflight scaffolding: an idempotent corpus synthesizer, five fixture corpora (regression-mechanical / regression-standard / regression-novel / no-regression / below-min-sample), a pre-amendment golden baseline at `tests/fixtures/m030-p06/check-anomalies-pre-m030-baseline.txt` capturing HEAD's `check-anomalies.sh` stdout against the P02 graduation fixture, and the SC-11 byte-equality gate `tools/verify/p06-sc11-byte-equality.sh` that diffs post-amendment output against the committed snapshot.

T02 (`43b3882`) amended the surfaces. `scripts/dispatch/dispatch-interface.sh` got a single additive `character=<class>` field appended to the shadow-on `dispatch_usage` printf format + arg list — extending the P02/T02 + P04/T03 additive-field-on-shadow-on-emit lineage. The shadow-off branch is byte-untouched; `tools/verify/p06-shadow-off-byte-equality.sh` is a thin delegate-and-pass-through wrapper around `tools/verify/p02-additive-schema.sh` that re-confirms the SC-11 byte-equality contract post-amendment. `scripts/diagnostics/check-anomalies.sh` got a `_ca_model_routing_regression_check` function integrated into the CLI dispatch path: an awk-grouped pass over shadow-on records grouped by `character`, emitting a `FLAGGED model_routing_regression class=<X> class_pass_rate=<R> sample=<N> threshold=<T>` line + a `{"record_type":"anomaly","kind":"model_routing_regression",...}` JSONL record only when `class_sample >= min_class_sample` AND `class_pass_rate < pass_rate_threshold`. Pre-P06 records (no `character` field) are silently skipped — preserving SC-11 byte-equality on every existing pre-amendment fixture. Co-authored 6 verifiers (mechanical / standard / novel positive cases + no-regression negative + below-min-sample sample-floor guard + doctor-surfaces-anomaly integration) plus a `## Anomaly Records` section in `references/model-routing.md` documenting the record shape, threshold defaults, JSONL emit path, and operator threshold-tuning obligation.

T03 (this commit) authored the 8-sub-gate straight-line phase-suite aggregator at `tools/verify/p06-phase-suite.sh` mirroring the P02/P03/P04/P05 shape (no loops, no eval, AD-19 single-script-file discipline preserved per sub-gate), dual-wrote the P06-close fragment to `CLAUDE.md` + `AGENTS.md` recent-changes regions via `scripts/util/dual-write-runtime-md.sh --append-entry`, appended the phase-grain `unit_close` record to `execution-log.jsonl`, and committed the close. The plan-amendment-not-task-reopen precedent was applied for three artifact-line-count predicate divergences — `p06-standard-regression.sh` and `p06-novel-regression.sh` predicates relaxed from min 60 → min 50 (each: 57 lines, body shape identical to `p06-mechanical-regression.sh` modulo class-name substitutions) and `p06-shadow-off-byte-equality.sh` predicate relaxed from min 30 → min 25 (actual: 28 lines, thin delegate-and-pass-through wrapper around `p02-additive-schema.sh`). All three deliverables ship green; the predicates were authored aspirationally and didn't match the natural body shape. After amendment the must-haves grep is clean (8 truths + 21 artifacts + 6 key-links all PASS).

Verification result: phase-suite green pass=8 fail=0 across all sub-gates (sc11-byte-equality + shadow-off-byte-equality + mechanical-regression + standard-regression + novel-regression + no-regression + below-min-sample + doctor-surfaces-anomaly). Upstream P02 + P04 phase-suites remain green (the additive `character` field doesn't perturb their byte-equality contracts). SC-11 byte-equality preserved through both amended surfaces — `check-anomalies.sh` emits zero additional stdout and appends zero JSONL records when no class crosses threshold; `dispatch-interface.sh` shadow-off branch is byte-untouched. CON-3 closure preserved (zero new hardcoded model IDs introduced).

Patterns established/extended: additive-field-on-shadow-on-emit (single field appended to printf format string + arg list on shadow-on branch only; SC-11 contract via P02 delegate-and-pass-through wrapper); env-var-seam-for-anomaly-jsonl-redirection (M030_ANOMALIES_JSONL_PATH; mirrors M030_SHADOW_MODE / M030_SHADOW_COMPARE_CORPUS / M030_ROUTING_TABLE_PATH precedents); append-only anomalies.jsonl emit via `>>` redirect with `mkdir -p` guard, with CON-6 dispatch-stream invariant extended from execution-log.jsonl to anomalies.jsonl via separate-file boundary; phase-suite-aggregator extending from 7-gates (P05) to 8-gates (P06) without shape change; rolling-window-per-class-verifier-fail-rate-check shape (awk-grouped pass on shadow-on records grouped by character; FLAGGED text + JSONL gated on class_sample floor AND pass_rate threshold; pre-P06 records silently skipped).

Provides downstream: P07 (end-to-end shadow-corpus + flip-gate validation, the spec'd milestone-close gate) consumes P06's `model_routing_regression` anomaly record as part of the M030 acceptance battery — the flip-gate watches for absence of `model_routing_regression` lines across the shadow-corpus run as one of its release-readiness signals.

Roadmap impact: P06 produces the anomaly-detection surface declared by M030-ROADMAP.md acceptance line 57. No deviations from the original phase boundary; no upstream replanning required. P07 remains the only outstanding M030 phase before milestone-close ceremony (M030-VALIDATED marker + M030-SUMMARY.md + milestone-grain unit_close + final validate-milestone.sh pass).

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P07"
milestone: "M030"
name: "Acceptance-evidence ledger + evidence-ledger shape gate + phase-suite aggregator"
depends_on: ["T02"]
---

## Prerequisites

- T01 + T02 deliverables on disk and green:
  - All four corpora at `tests/m030-acceptance/` (T01).
  - `tests/m030-acceptance/shadow-corpus-fixtures.sh` synthesizer (T01).
  - All five T01 per-verdict gates at `tools/verify/p07-corpus-*.sh` + `p07-corpus-synthesizer-idempotent.sh` (T01).
  - `tests/m030-acceptance/run-acceptance-battery.sh` runner (T02).
  - `tools/verify/p07-partial-flip-jsonl-fields.sh`, `p07-cross-surface-coherence.sh`, `p07-acceptance-battery-pass.sh` (T02).

- All nine T01+T02 verifiers exit 0 when invoked individually:
  - `p07-corpus-synthesizer-idempotent.sh`, `p07-corpus-50-per-class-ready.sh`, `p07-corpus-zero-evidence-insufficient.sh`, `p07-corpus-2-class-partially-ready.sh`, `p07-corpus-block.sh`, `p07-partial-flip-jsonl-fields.sh`, `p07-cross-surface-coherence.sh`, `p07-acceptance-battery-pass.sh` (T03 also adds the ninth: `p07-acceptance-evidence-ledger.sh`).

- `tests/m030-acceptance/run-acceptance-battery.sh` exits 0 with `BATTERY: pass=N fail=0`.

Plan-time prerequisite-existence verification: every path above is asserted by T02 close; T03 captures the runner's output as the source-of-truth for the evidence ledger.

## Description

T03 ships the green-run evidence ledger plus the P07 phase-suite aggregator. Three deliverables:

1. **[`.orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md`](../../../../../milestones/M030/M030-ACCEPTANCE-EVIDENCE.md)** — a one-shot evidence ledger of the green acceptance-battery run. Frontmatter declares the run timestamp + the canonical `BATTERY: pass=N fail=0` summary; body has a `## Evidence` section with one row per SC carrying the verifier path + the canonical key-line from that verifier's stdout.

2. **`tools/verify/p07-acceptance-evidence-ledger.sh`** — verifier asserting the ledger exists with valid frontmatter shape AND that every cited verifier path resolves to an existing-on-disk script.

3. **`tools/verify/p07-phase-suite.sh`** — straight-line aggregator over the nine P07 sub-gates (T01's five + T02's three + T03's one).

### Evidence ledger shape

Frontmatter:

```yaml
---
schema_version: "1.0"
type: acceptance-evidence
milestone: "M030"
recorded_at: "<ISO8601-timestamp>"
battery_summary: "pass=N fail=0"
runner: "tests/m030-acceptance/run-acceptance-battery.sh"
---
```

Body:

```markdown
# M030 Acceptance Evidence

This file is the one-shot evidence ledger of the M030 acceptance-battery green run captured at `recorded_at`. The battery is the contract; this ledger is the audit trail. Re-running the battery later may produce drift (timestamps, JSONL records); this file freezes the green-run state at milestone close.

## Battery Summary

`BATTERY: pass=N fail=0` — emitted by `tests/m030-acceptance/run-acceptance-battery.sh` on `<recorded_at>`.

## Evidence

| SC | Verifier(s) | Canonical key line |
|----|-------------|--------------------|
| SC-1 | `tools/verify/p01-classifier-determinism.sh` + `tools/verify/p01-classifier-perf-and-network.sh` | `<canonical SUMMARY: line from each>` |
| SC-2 (ready) | `tools/verify/p07-corpus-50-per-class-ready.sh` | `flip_recommendation=ready` |
| SC-2 (evidence_insufficient) | `tools/verify/p07-corpus-zero-evidence-insufficient.sh` | `flip_recommendation=evidence_insufficient` |
| SC-2 (partially_ready) | `tools/verify/p07-corpus-2-class-partially-ready.sh` | `flip_recommendation=partially_ready` + flippable-classes line |
| SC-2 (block) | `tools/verify/p07-corpus-block.sh` | `flip_recommendation=block` |
| SC-2a | `tools/verify/p04-sc2a-shadow-gate-block.sh` | `<canonical SUMMARY: line>` |
| SC-3 | `tools/verify/p04-sc3-live-mechanical.sh` | `<canonical SUMMARY: line>` |
| SC-3a | `tools/verify/p02-sc3a-roundtrip.sh` | `<canonical SUMMARY: line>` |
| SC-4 | `tools/verify/p04-sc4-escalation-sequence.sh` | `<canonical SUMMARY: line>` |
| SC-5 | `tools/verify/p04-sc5-escalation-cap.sh` | `<canonical SUMMARY: line>` |
| SC-6 | `tools/verify/p03-sc6-frontmatter-override.sh` | `<canonical SUMMARY: line>` |
| SC-7 | `tools/verify/p03-sc7-kill-switch.sh` | `<canonical SUMMARY: line>` |
| SC-7a | `tools/verify/p03-sc7a-compound.sh` | `<canonical SUMMARY: line>` |
| SC-8 | `tools/verify/p05-by-model-cost-rates-present.sh` + `p05-by-model-cost-rates-absent.sh` + `p05-by-model-dispatch-counts.sh` | `<canonical lines>` |
| SC-9 | `tools/verify/p05-doctor-config-check.sh` | `<canonical SUMMARY: line>` |
| SC-10 | `tools/verify/p01-classifier-ground-truth.sh` | `<accuracy ratio line>` |
| SC-11 | `tools/verify/p05-sc11-rollup-byte-equality.sh` + `p05-sc11-footer-byte-equality.sh` + `tools/verify/p06-sc11-byte-equality.sh` | `<canonical SUMMARY: lines>` |

## Cross-Surface Coherence

The two phase-suite-only gates that don't appear in the spec.md SC list but verify roadmap-line-64 contracts:

- `tools/verify/p07-partial-flip-jsonl-fields.sh` — partial-flip JSONL field shape verified at acceptance scale.
- `tools/verify/p07-cross-surface-coherence.sh` — metrics-rollup + efficiency-footer + check-anomalies coherent output against the 150-record corpus.

## Provenance

- Battery runner SHA at recording time: `<git rev-parse HEAD:tests/m030-acceptance/run-acceptance-battery.sh>`.
- Corpus synthesizer SHA at recording time: `<git rev-parse HEAD:tests/m030-acceptance/shadow-corpus-fixtures.sh>`.
- Recording machine: `<uname -srm output, anonymized>` (ledger captures runtime context for audit).

## Re-running the Battery

```bash
bash tests/m030-acceptance/shadow-corpus-fixtures.sh
bash tests/m030-acceptance/run-acceptance-battery.sh
```

Idempotent corpus + replay-able battery. Re-running produces a fresh `BATTERY: pass=N fail=0` line; this ledger captures the milestone-close green run.
```

The `<canonical SUMMARY: line>` placeholders are filled at T03 author time by capturing each verifier's stdout. The ledger is a snapshot, not a dynamic report — T03 writes it once and commits.

### Phase-suite aggregator shape

`tools/verify/p07-phase-suite.sh` is a straight-line aggregator over the nine P07 sub-gates. Same shape as `p06-phase-suite.sh`:

```bash
#!/usr/bin/env bash
# tools/verify/p07-phase-suite.sh — P07 phase-close gate aggregator.
# Straight-line invocation of all nine P07 sub-gates; no loops, no eval.
# Mirrors P02/P03/P04/P05/P06 phase-suite shape.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

pass=0
fail=0

bash "$PROJECT_ROOT/tools/verify/p07-corpus-synthesizer-idempotent.sh"
rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "GATE FAIL: p07-corpus-synthesizer-idempotent.sh exited $rc"; fi

bash "$PROJECT_ROOT/tools/verify/p07-corpus-50-per-class-ready.sh"
rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "GATE FAIL: p07-corpus-50-per-class-ready.sh exited $rc"; fi

bash "$PROJECT_ROOT/tools/verify/p07-corpus-zero-evidence-insufficient.sh"
rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "GATE FAIL: p07-corpus-zero-evidence-insufficient.sh exited $rc"; fi

bash "$PROJECT_ROOT/tools/verify/p07-corpus-2-class-partially-ready.sh"
rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "GATE FAIL: p07-corpus-2-class-partially-ready.sh exited $rc"; fi

bash "$PROJECT_ROOT/tools/verify/p07-corpus-block.sh"
rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "GATE FAIL: p07-corpus-block.sh exited $rc"; fi

bash "$PROJECT_ROOT/tools/verify/p07-partial-flip-jsonl-fields.sh"
rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "GATE FAIL: p07-partial-flip-jsonl-fields.sh exited $rc"; fi

bash "$PROJECT_ROOT/tools/verify/p07-cross-surface-coherence.sh"
rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "GATE FAIL: p07-cross-surface-coherence.sh exited $rc"; fi

bash "$PROJECT_ROOT/tools/verify/p07-acceptance-battery-pass.sh"
rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "GATE FAIL: p07-acceptance-battery-pass.sh exited $rc"; fi

bash "$PROJECT_ROOT/tools/verify/p07-acceptance-evidence-ledger.sh"
rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "GATE FAIL: p07-acceptance-evidence-ledger.sh exited $rc"; fi

printf 'SUMMARY: p07-phase-suite.sh pass=%s fail=%s\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
```

### Evidence-ledger shape gate

`tools/verify/p07-acceptance-evidence-ledger.sh` shape:

1. Asserts [`.orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md`](../../../../../milestones/M030/M030-ACCEPTANCE-EVIDENCE.md) exists.
2. Greps the frontmatter for required keys: `schema_version`, `type: acceptance-evidence`, `milestone: "M030"`, `recorded_at`, `battery_summary`, `runner`.
3. Greps the body for `## Evidence` table presence and for each of the 14 SC labels (`SC-1`, `SC-2`, `SC-2a`, `SC-3`, `SC-3a`, `SC-4`, `SC-5`, `SC-6`, `SC-7`, `SC-7a`, `SC-8`, `SC-9`, `SC-10`, `SC-11`).
4. Extracts every cited verifier path (lines matching `tools/verify/p[0-9]+-.*\.sh`) and asserts each path resolves to an existing-on-disk script.
5. Emits `SUMMARY: p07-acceptance-evidence-ledger.sh pass=N fail=M` and exits 0 iff `fail=0`.

## Steps

1. **Confirm T01+T02 deliverables green** by running each individually:

   ```bash
   bash tools/verify/p07-corpus-synthesizer-idempotent.sh
   bash tools/verify/p07-corpus-50-per-class-ready.sh
   bash tools/verify/p07-corpus-zero-evidence-insufficient.sh
   bash tools/verify/p07-corpus-2-class-partially-ready.sh
   bash tools/verify/p07-corpus-block.sh
   bash tools/verify/p07-partial-flip-jsonl-fields.sh
   bash tools/verify/p07-cross-surface-coherence.sh
   bash tools/verify/p07-acceptance-battery-pass.sh
   ```

   Expected: all eight exit 0 with `SUMMARY: <name> pass=N fail=0`. If any fail, halt T03 and re-open the relevant T01/T02 task.

2. **Run the full acceptance battery and capture stdout** for the evidence ledger:

   ```bash
   bash tests/m030-acceptance/run-acceptance-battery.sh > /tmp/p07-battery-output.txt
   ```

   Confirm the last line is `BATTERY: pass=N fail=0` (capture exact N for the ledger frontmatter).

3. **Capture per-verifier canonical SUMMARY lines** for the ledger body. For each verifier path in the SC battery, run:

   ```bash
   bash <verifier-path>
   ```

   And capture the `SUMMARY: <verifier-name> pass=N fail=0` line. These fill the `<canonical SUMMARY: line>` placeholders in the ledger table.

   Acceptable shortcut: extract from the captured `/tmp/p07-battery-output.txt` since the runner's `BATTERY-PASS:` lines preserve the verifier path. The exact stdout shape varies per verifier; the ledger captures whichever shape the verifier emits.

4. **Author [`.orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md`](../../../../../milestones/M030/M030-ACCEPTANCE-EVIDENCE.md)** per the shape in the Description. Use the Write tool. Fill in:
   - `recorded_at` = current ISO8601 timestamp.
   - `battery_summary` = the captured `pass=N fail=0` from step 2.
   - Each `<canonical SUMMARY: line>` from step 3.
   - `<git rev-parse HEAD:...>` placeholders filled via `git rev-parse HEAD:tests/m030-acceptance/run-acceptance-battery.sh` and `git rev-parse HEAD:tests/m030-acceptance/shadow-corpus-fixtures.sh`. (These will only resolve after T02 commits these files; if T03 is authored on the same branch as T02 before the close commit, use `git hash-object <path>` instead, which works on uncommitted blobs.)
   - `<uname -srm output>` = `uname -srm` (e.g., `Darwin 24.6.0 arm64`).

5. **Author `tools/verify/p07-acceptance-evidence-ledger.sh`** per the shape in the Description. Make executable.

6. **Self-check the evidence-ledger gate**:

   ```bash
   bash tools/verify/p07-acceptance-evidence-ledger.sh
   ```

   Expected: `SUMMARY: p07-acceptance-evidence-ledger.sh pass=N fail=0`, exit 0.

7. **Author `tools/verify/p07-phase-suite.sh`** per the shape in the Description. Make executable.

8. **Self-check the phase-suite**:

   ```bash
   bash tools/verify/p07-phase-suite.sh
   ```

   Expected: exit 0 with `SUMMARY: p07-phase-suite.sh pass=9 fail=0`.

9. **Run `scripts/verify/check-must-haves.sh`** against the phase plan to confirm all truths + artifacts + key-links pass:

   ```bash
   bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P07
   ```

   Expected: ALL truths PASS (the 10 truths declared in P07-PLAN.md). ALL artifacts PASS except the four T04-owned artifacts (M030-SUMMARY.md, M030-VALIDATED, P07-SUMMARY.md, the modified CLAUDE.md project-status update — though CLAUDE.md / AGENTS.md may already exist with content, the artifact predicate may PASS at T03 close depending on what the predicates assert). The plan-amendment-not-task-reopen pattern applies for any artifact-grep predicate that diverges between the plan declaration and the actual file content.

   Acceptable T03-close state: 9 truths PASS + most artifacts PASS + 4 artifacts FAIL (T04-owned). The 4 expected FAILs are M030-SUMMARY.md, M030-VALIDATED, P07-SUMMARY.md, and any T04-owned CLAUDE.md predicate. Document the expected FAILs in the T03 SUMMARY.

## Must-Haves

T03 satisfies the following P07 phase truths:

- The acceptance-evidence ledger exists with valid frontmatter + 14-SC body table + every cited verifier path resolving on-disk — gated by `bash tools/verify/p07-acceptance-evidence-ledger.sh`.
- The P07 phase-suite invokes all P07 sub-gates in literal sequence and exits 0 iff every sub-gate passes — gated by `bash tools/verify/p07-phase-suite.sh`.

## Verification

```bash
bash tools/verify/p07-acceptance-evidence-ledger.sh
bash tools/verify/p07-phase-suite.sh
```

Both must exit 0 before T03 closes.

## Inputs

### From Previous Tasks (T01 + T02)

- `tests/m030-acceptance/run-acceptance-battery.sh` (T02) — invoked at step 2 to capture the battery stdout. Key API: `bash <path>` emits 22 `BATTERY-PASS:` lines + a final `BATTERY: pass=N fail=0` summary line.
- All eight T01 + T02 verifier scripts at `tools/verify/p07-*.sh` (T01 ships five; T02 ships three) — invoked by the phase-suite aggregator. Key API: each is `bash <path>` exit 0 iff sub-gate passes.

### From Disk (Pre-existing)

- `scripts/verify/check-must-haves.sh` — Key API: `bash <path> <phase-dir>`. Reads phase plan's Must-Haves section + checks each truth's `Check:` command + each artifact's existence/grep/line-count + each key-link source→target grep. Exit 0 on all PASS. Used at step 9.
- `git` — for `rev-parse` + `hash-object` to capture the runner / synthesizer SHAs in the ledger.
- `uname` — for runtime context capture in the ledger.

## Constraints

- **AD-19 single-script-file shape**: `p07-phase-suite.sh` and `p07-acceptance-evidence-ledger.sh` use straight-line invocation; helper-function-carve-out applies to assertion bodies if any.
- **Bash 3.2 compatibility**: parallel scalars + `if`-statements throughout.
- **One-shot ledger discipline**: `M030-ACCEPTANCE-EVIDENCE.md` is authored ONCE at T03 and committed. It is NOT regenerated dynamically. Re-running the battery later produces a fresh BATTERY line but the ledger remains the milestone-close snapshot. Operators who want fresh evidence re-run the battery and read its stdout; they don't regenerate the ledger.
- **Project-owned-verifier-paths discipline (M032 Finding A)**: the two new verifiers live under `tools/verify/` (slug-bearing). The ledger lives under `.orchestrator/milestones/M030/` (state-tree, project-owned).
- **Plan-Time Discipline rule 2 (verifier-availability cross-check)**: every verifier the phase-suite invokes resolves to an existing-on-disk script post-T02. T01+T02 deliverables are confirmed at step 1 + step 7's self-check.

## Expected Output

- [`.orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md`](../../../../../milestones/M030/M030-ACCEPTANCE-EVIDENCE.md) — one-shot evidence ledger with frontmatter + 14-SC body table + provenance + re-run instructions.
- `tools/verify/p07-acceptance-evidence-ledger.sh` — gates the ledger's frontmatter + body shape + cited-verifier-existence.
- `tools/verify/p07-phase-suite.sh` — straight-line aggregator over 9 P07 sub-gates; exits 0 iff all pass; emits `SUMMARY: p07-phase-suite.sh pass=9 fail=0`.

All three deliverables ship green.

## Notes

Expected output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p07-phase-suite.sh` → `SUMMARY: p07-phase-suite.sh pass=9 fail=0`, exit 0.
- `bash tools/verify/p07-acceptance-evidence-ledger.sh` → `SUMMARY: p07-acceptance-evidence-ledger.sh pass=N fail=0`, exit 0.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P07` → most truths + artifacts PASS; the 4 T04-owned artifacts (M030-SUMMARY.md, M030-VALIDATED, P07-SUMMARY.md, and the T04 CLAUDE.md project-status update) FAIL because they don't exist yet — these FAILs are EXPECTED at T03 close and resolve when T04 lands.

If a per-verifier canonical SUMMARY line in the ledger drifts (because one of the upstream verifiers changes its emit shape), AMEND the ledger directly via Edit tool. The ledger is a snapshot of the green-run state — drift over time is expected; the milestone-close snapshot is what the ledger preserves. Re-runs of the battery may produce new lines; the ledger captures the ones from the green run that triggered M030 close.

If `git rev-parse HEAD:<path>` fails because T02 hasn't committed yet, use `git hash-object <path>` (works on the worktree blob without requiring a commit). Both produce deterministic SHA-1 hashes that uniquely identify the file content at recording time; either is acceptable as the provenance anchor.

The plan-amendment-not-task-reopen pattern (P02-P06 precedent) applies if `check-must-haves.sh` reports a failure on an artifact-grep or key-link predicate at step 9. Investigate first whether the predicate or the deliverable is wrong; if the deliverable is shaped correctly and the predicate was authored against an aspirational shape that diverged, amend the predicate in `P07-PLAN.md` directly and re-run `check-must-haves.sh`. If the deliverable IS wrong, re-open the relevant T01/T02 task — but T03 should NOT touch the deliverables it consumes.

## State Context

- **Current State**: executing
- **Milestone**: M030
- **Phase**: P07
- **Task**: T03-evidence-ledger-and-phase-suite
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **AD-19 single-script-file shape**: `p07-phase-suite.sh` and `p07-acceptance-evidence-ledger.sh` use straight-line invocation; helper-function-carve-out applies to assertion bodies if any.
- **Bash 3.2 compatibility**: parallel scalars + `if`-statements throughout.
- **One-shot ledger discipline**: `M030-ACCEPTANCE-EVIDENCE.md` is authored ONCE at T03 and committed. It is NOT regenerated dynamically. Re-running the battery later produces a fresh BATTERY line but the ledger remains the milestone-close snapshot. Operators who want fresh evidence re-run the battery and read its stdout; they don't regenerate the ledger.
- **Project-owned-verifier-paths discipline (M032 Finding A)**: the two new verifiers live under `tools/verify/` (slug-bearing). The ledger lives under `.orchestrator/milestones/M030/` (state-tree, project-owned).
- **Plan-Time Discipline rule 2 (verifier-availability cross-check)**: every verifier the phase-suite invokes resolves to an existing-on-disk script post-T02. T01+T02 deliverables are confirmed at step 1 + step 7's self-check.

### Acceptance Criteria

T03 satisfies the following P07 phase truths:

- The acceptance-evidence ledger exists with valid frontmatter + 14-SC body table + every cited verifier path resolving on-disk — gated by `bash tools/verify/p07-acceptance-evidence-ledger.sh`.
- The P07 phase-suite invokes all P07 sub-gates in literal sequence and exits 0 iff every sub-gate passes — gated by `bash tools/verify/p07-phase-suite.sh`.

### Files To Touch

- tests/m030-acceptance/shadow-corpus-fixtures.sh (create)
- tests/m030-acceptance/corpus-50-per-class.jsonl (create)
- tests/m030-acceptance/corpus-zero.jsonl (create)
- tests/m030-acceptance/corpus-2-class-only.jsonl (create)
- tests/m030-acceptance/corpus-block.jsonl (create)
- tests/m030-acceptance/run-acceptance-battery.sh (create)
- tools/verify/p07-corpus-synthesizer-idempotent.sh (create)
- tools/verify/p07-corpus-50-per-class-ready.sh (create)
- tools/verify/p07-corpus-zero-evidence-insufficient.sh (create)
- tools/verify/p07-corpus-2-class-partially-ready.sh (create)
- tools/verify/p07-corpus-block.sh (create)
- tools/verify/p07-partial-flip-jsonl-fields.sh (create)
- tools/verify/p07-cross-surface-coherence.sh (create)
- tools/verify/p07-acceptance-battery-pass.sh (create)
- tools/verify/p07-acceptance-evidence-ledger.sh (create)
- tools/verify/p07-phase-suite.sh (create)
- [.orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md](../../../../../milestones/M030/M030-ACCEPTANCE-EVIDENCE.md) (create)
- [.orchestrator/milestones/M030/M030-SUMMARY.md](../../../../../milestones/M030/M030-SUMMARY.md) (create)
- .orchestrator/milestones/M030/M030-VALIDATED (create — written by mark-complete.sh)
- [.orchestrator/milestones/M030/phases/P07/P07-SUMMARY.md](../../../../../milestones/M030/phases/P07/P07-SUMMARY.md) (create)
- [.orchestrator/milestones/M030/phases/P07/P07-PLAN.md](../../../../../milestones/M030/phases/P07/P07-PLAN.md) (create — this file)
- [.orchestrator/milestones/M030/phases/P07/tasks/T01-corpus-and-verdict-gates-PLAN.md](../../../../../milestones/M030/phases/P07/tasks/T01-corpus-and-verdict-gates-PLAN.md) (create)
- [.orchestrator/milestones/M030/phases/P07/tasks/T02-acceptance-battery-PLAN.md](../../../../../milestones/M030/phases/P07/tasks/T02-acceptance-battery-PLAN.md) (create)
- [.orchestrator/milestones/M030/phases/P07/tasks/T03-evidence-ledger-and-phase-suite-PLAN.md](../../../../../milestones/M030/phases/P07/tasks/T03-evidence-ledger-and-phase-suite-PLAN.md) (create)
- [.orchestrator/milestones/M030/phases/P07/tasks/T04-milestone-close-ceremony-PLAN.md](../../../../../milestones/M030/phases/P07/tasks/T04-milestone-close-ceremony-PLAN.md) (create)
- .orchestrator/milestones/M030/execution-log.jsonl (modify — phase-grain unit_close append at T04 + milestone-grain unit_close append at T04)
- CLAUDE.md (modify — recent-changes region + project-status update from "in progress" to "Closed M030")
- AGENTS.md (modify — recent-changes region)

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