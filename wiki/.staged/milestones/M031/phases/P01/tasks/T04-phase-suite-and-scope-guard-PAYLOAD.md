---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T04-phase-suite-and-scope-guard (Phase P01, Milestone M031)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-978 | ~500 | required |
| Upstream Context | 980-1041 | ~2300 | required |
| Task Plan | 1043-1210 | ~3200 | required |
| State Context | 1212-1218 | ~100 | required |
| First-Turn Completeness | 1220-1267 | ~800 | required |
| **Total** | | **~17700** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 698
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
hit_count: 698
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
hit_count: 698
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
hit_count: 698
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
hit_count: 612
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
hit_count: 612
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
hit_count: 612
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
hit_count: 698
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
hit_count: 612
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
hit_count: 612
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
hit_count: 612
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
hit_count: 698
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
hit_count: 698
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
hit_count: 698
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
hit_count: 612
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
hit_count: 612
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
hit_count: 612
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
hit_count: 698
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
hit_count: 612
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
hit_count: 612
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
hit_count: 698
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
hit_count: 698
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
hit_count: 612
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
hit_count: 612
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
hit_count: 612
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
hit_count: 267
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
hit_count: 267
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
hit_count: 267
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
hit_count: 274
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
hit_count: 274
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
hit_count: 264
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
     Namespacing: `m031-p01-*` prefix avoids collision with [M030](../../../../../milestones/M030/index.md)'s
     existing `p01-*` verifiers in the shared tools/verify/ tree. -->

### Truths

- `scripts/dispatch/build-context.sh` accepts `--profile=quick|standard|full` and `--meta-out <file>` flags (FR-2 + AD-11). The Quick profile sets scope to touched-files-only, traversal to 1-hop direct hits, no Decisions section, and a glossary slice over touched terms only. Standard sets phase scope, 2-hop traversal, phase-relevant Decisions, phase-touched glossary. Full sets milestone-plus-dependencies scope, full provenance traversal, all milestone Decisions, full glossary. The `--meta-out` flag writes a JSON sidecar with the minimum schema `{mem_count, total_tokens, profile, compression_applied, snip_applied}` per AD-11.
  - Check: `bash tools/verify/m031-p01-build-context-profile-shape.sh`

- The Quick profile path runs `build-context.sh` end-to-end (CON-1 invariant — every dispatch path emits a `payload_breakdown` JSONL record). There is NO "skip context" exit; only "scope it tighter" via `--profile=quick`. Knowledge-section assembly, [M018](../../../../../milestones/M018/index.md) tier-1 paging, and M018 tier-2 snip all participate when their respective config tiers are enabled (CON-2).
  - Check: `bash tools/verify/m031-p01-quick-no-skip-branch.sh`

- `templates/orchestrator-config-default.yml` is unchanged with respect to the three P00 knobs (`quick_knowledge_token_budget: 800`, `entry_routing_confidence_floor: 0.7`, `tier_a_plus_prompt_summary_lines: 8`); P01 does NOT re-declare or modify these knobs. The `quick_knowledge_token_budget` is the advisory ceiling that M018 tier-2 snip enforces per FR-5 + AD-13. (P01 reads the knob; it does not write it. P00 owns the write.)
  - Check: `bash tools/verify/m031-p01-config-knobs-stable.sh`

<dispatch-volatile>

## Upstream Context


### P00 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P00"
parent: "M031"
milestone: "M031"
provides:
  - "spec-body fold-in (AD-1..AD-20),SC-15 + SC-16 added,SC-2/SC-3/SC-11/SC-13 rewritten,SC-14 raised to N >= 15,p00-spec-foldin-shape.sh verifier,20-task AD-15 corpus + manifest + AD-14 pre-M031 stub + AD-17 RUNTIME-ASSUMPTIONS fold-in + 3 M031 config defaults + 5 P00 verifiers,FR-18 empirical-baseline harness + AD-12/SC-13 ordering verifier (Option B preferred / Option A fallback) + AD-14 frozen pre-m031-baseline.jsonl (20 records) + SC13-OPTION.md + 4 P00 verifiers + p00-phase-suite.sh aggregating all 9 P00 gates"
requires:
  - "none"
affects:
  - "P01"
key_files:
  - "specs/034-right-sized-entry/spec.md,tools/verify/p00-spec-foldin-shape.sh,tests/m031-acceptance/fixtures/empirical-baseline/CORPUS-MANIFEST.md,tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-stub.sh,references/RUNTIME-ASSUMPTIONS.md,templates/orchestrator-config-default.yml,tools/verify/p00-corpus-manifest-shape.sh,tools/verify/p00-corpus-population.sh,tools/verify/p00-pre-stub-shape.sh,tools/verify/p00-runtime-assumptions-foldin.sh,tools/verify/p00-config-defaults-pinned.sh,tests/m031-acceptance/empirical-baseline.sh,tests/m031-acceptance/verify-baseline-ordering.sh,tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-baseline.jsonl,tests/m031-acceptance/fixtures/empirical-baseline/SC13-OPTION.md,tools/verify/p00-baseline-harness-shape.sh,tools/verify/p00-ordering-verifier-shape.sh,tools/verify/p00-pre-baseline-jsonl-population.sh,tools/verify/p00-phase-suite.sh"
key_decisions:
  - "AD-12 Option B preferred for SC-13 (git-history check); AD-13 ±20% literal removed globally including audit-trail; AD-18 SC-15 added; AD-20 SC-16 added,cost_class derived from duration_s (total_tokens/re_dispatch_count absent from live records,manifest documents the substitution); 3 new knobs added at top level not folded into compression: block (matches auto_proceed shape); auto_proceed left at line 27 (P04 ratification job,not a P00 knob-flip),SC-13 Option A selected (corpus path uncommitted at T03-execution time,git log returns empty for the corpus path so Option B has no defined LHS; SC-14 effective N=14; operators may re-run after T03+P01 commits land to upgrade to Option B); harness median uses lower-middle for even-N to avoid bash 3.2 floating-point math (stable for inequality-based SC-11 verdict); pass-rate fixed-point integer comparison sidesteps shell FP entirely"
patterns_established:
  - "post-roadmap spec fold-in (defer ratified ADs into spec body until phase IDs pinned); inverted-polarity grep verifier with explicit comment guarding the inversion against future maintainer 'fixes',AD-14 single-window stub pattern (frozen pre-state capture before destructive surface modification,stub MUST NOT call the surface it captures); inverted-grep verifier with comment-vs-code distinction (allow header-comment references to a path while rejecting non-comment invocations),AD-14 single-window harness pattern (--post-m031-emitter seam = empty default emits 'capture pending' on stderr + exit 0,P01 first task supplies real emitter to satisfy 'simultaneously while both code paths are live'); harness re-runnability via deterministic stub + truncate-on-capture (idempotent re-runs produce identical pre-m031-baseline.jsonl bytes); phase-suite straight-line nine-gate aggregation (no array loops,AD-19 compliant) with per-gate OK:/FAIL: + final SUMMARY: pass=N fail=M"
drill_down_paths:
  - "[.orchestrator/milestones/M031/phases/P00/tasks/T01-SUMMARY.md](../../../../../milestones/M031/phases/P00/tasks/T01-SUMMARY.md), [.orchestrator/milestones/M031/phases/P00/tasks/T02-SUMMARY.md](../../../../../milestones/M031/phases/P00/tasks/T02-SUMMARY.md), [.orchestrator/milestones/M031/phases/P00/tasks/T03-SUMMARY.md](../../../../../milestones/M031/phases/P00/tasks/T03-SUMMARY.md)"
duration: "195m"
verification_result: "pass"
completed_at: "2026-05-01T16:48:44Z"
observability_surfaces:
  - "none"
---

## What Was Built

P00 establishes the **measurement floor** for M031 before any of the surface-modifying phases (P01–P04) touch live code. Three tasks, executed in dependency order:

- **T01 (spec-foldin):** Folded AD-1..AD-20 verbatim into `specs/034-right-sized-entry/spec.md` under a new `## Architectural Decisions (folded post-discuss 2026-05-01)` section, each AD carrying provenance back to `M031-CONTEXT.md`. Rewrote SC-2 (AD-13 ±20% drop), SC-3 (AD-17 inline_threshold_tokens), SC-11 (AD-14 single-window discipline), SC-13 (AD-12 Option B git-history ordering); added SC-15 (AD-18 median absolute budget compliance) and SC-16 (AD-20 prompt UX integration); raised SC-14 to `N ≥ 15`. Spec grew 267 → 408 lines. Original Open Questions / Gate Findings sections preserved as audit trail.
- **T02 (corpus-and-defaults):** Authored the AD-15 stratified 20-task corpus (`CORPUS-MANIFEST.md` + 20 task fixtures: 5 historical-derived with real `<milestone>/<phase>/<task>` provenance, 5 synthetic edge cases, 10 category-spread fillers) — manifest expanded to 145 lines covering stratification rationale, provenance audit trail, and reproduction protocol. Authored the AD-14 `pre-m031-stub.sh` frozen-state capture (94 lines, executable, MUST NOT call `scripts/dispatch/build-context.sh`). Folded the M018 Tier-1 `inline_threshold_tokens` precondition into `references/RUNTIME-ASSUMPTIONS.md`. Pinned three M031 knobs in `templates/orchestrator-config-default.yml` (`quick_knowledge_token_budget: 800`, `entry_routing_confidence_floor: 0.7`, `tier_a_plus_prompt_summary_lines: 8`).
- **T03 (harness-and-suite):** Built the FR-18 empirical-baseline harness (`tests/m031-acceptance/empirical-baseline.sh`, 255 lines, `--post-m031-emitter` seam ready for P01-first-task wire-in). Built the AD-12/SC-13 ordering verifier (`verify-baseline-ordering.sh`, 101 lines, Option B preferred / Option A documented fallback). Materialized the AD-14 frozen `pre-m031-baseline.jsonl` (exactly 20 records, schema `path: "pre-m031"`, `knowledge_section_tokens: 0`). Wrote 3 task-level verifiers + the 9-gate `p00-phase-suite.sh` aggregator.

## Key Decisions

- **AD-12 SC-13 Option A selected** (T03/SC13-OPTION.md) — corpus path was uncommitted at T03-execution time; `git log --diff-filter=A` returns empty for the corpus, so Option B has no defined LHS. Effective `N=14` for SC-14. Documented for upgrade to Option B after T03+P01 commits land.
- **Cost-class proxy substitution** — AD-15 plan named `total_tokens` + `re_dispatch_count` as cost-class proxies, but those fields are absent from live `unit_close` records. Manifest documents the substitution: `duration_s` is the nearest observed proxy (high ≥ 5000s, medium 2500–4500s, low ≤ 60s); `verification_pass_rate` was 1.0 across all candidate records, providing no class signal.
- **Three new config knobs at top level** — not folded into the existing `compression:` block. Matches the `auto_proceed` shape (top-level scalar with FR/AD ownership comment) and avoids over-coupling.
- **AD-13 ±20% literal removed globally** — including the audit-trail line. Verifier 7 in `p00-spec-foldin-shape.sh` is inverted-polarity (assert absence) with an explicit comment guarding against a future maintainer "typo fix."

## Patterns Established

- **Post-roadmap spec fold-in** — defer ratified ADs into the spec body until phase IDs are pinned.
- **AD-14 single-window stub pattern** — frozen pre-state capture before destructive surface modification; the stub MUST NOT call the surface it captures (header-comment references allowed, non-comment invocations rejected).
- **AD-14 single-window harness pattern** — `--post-m031-emitter` seam: empty default emits "capture pending" on stderr and exits 0; P01 first task supplies the real emitter to satisfy "simultaneously while both code paths are live."
- **Inverted-polarity grep verifiers** — assert absence with an explicit comment guarding the inversion against well-intentioned future "fixes."
- **Phase-suite straight-line aggregation** — no array loops (AD-19 compliant), per-gate `OK:`/`FAIL:` lines plus a final `SUMMARY: pass=N fail=M` envelope.
- **Bash 3.2 fixed-point comparison** — pass-rate via integer arithmetic to sidestep shell floating-point entirely (stable inequality verdicts for SC-11).

## Verification

- All P00 task-level verifiers green: T01 `p00-spec-foldin-shape.sh pass=7 fail=0`; T02 `p00-corpus-manifest-shape.sh pass=4`, `p00-corpus-population.sh pass=2`, `p00-pre-stub-shape.sh pass=5`, `p00-runtime-assumptions-foldin.sh pass=5`, `p00-config-defaults-pinned.sh pass=5`; T03 `p00-baseline-harness-shape.sh pass=6`, `p00-ordering-verifier-shape.sh pass=5`, `p00-pre-baseline-jsonl-population.sh pass=4`. Aggregated `p00-phase-suite.sh pass=9 fail=0`.
- Phase-level `check-must-haves.sh` clean (one transient gap on CORPUS-MANIFEST line-count remediated mid-loop by expanding the manifest from 68 → 145 lines without touching frontmatter or entry rows).
- `check-boundary-map.sh` SKIP — P00 has no boundary-map produce items declared (foundation phase).
- No P01 surfaces touched (`scripts/dispatch/build-context.sh`, `commands/dispatch.md`, `commands/evaluate.md`, `references/tier-definitions.md` preserved). AD-14 single-window discipline + SC-12 scope-guard intact.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M031"
name: "P01 phase-suite aggregator + SC-12 scope-guard verifier"
depends_on: ["T03"]
---

## Prerequisites

- T01 + T02 + T03 all complete with green verifiers:
  - T01: `m031-p01-build-context-profile-shape.sh`, `m031-p01-quick-no-skip-branch.sh`, `m031-p01-config-knobs-stable.sh`.
  - T02: `m031-p01-post-baseline-jsonl-population.sh`, `m031-p01-dispatch-md-reconciliation.sh`.
  - T03: `m031-p01-test-quick-injects-knowledge-shape.sh`, `m031-p01-test-build-context-profile-shape.sh`, `m031-p01-test-compression-applies-to-quick-shape.sh`, `m031-p01-test-quick-budget-median-shape.sh`.
- All nine prerequisite verifiers exist as files under `tools/verify/` and exit 0 individually.

## Description

T04 ships two final verifiers that close out P01:

1. `tools/verify/m031-p01-phase-suite.sh` — the phase-suite aggregator. Invokes all nine T01/T02/T03 verifiers in dependency order (straight-line, no array loops per AD-19 / P00 phase-suite convention), tallies pass/fail counts, emits a single envelope line `SUMMARY: m031-p01-phase-suite.sh pass=N fail=M`, and exits 0 iff `fail=0`. This is the milestone-grain integration gate for P01.

2. `tools/verify/m031-p01-scope-guard.sh` — the SC-12 scope-guard verifier. Asserts the P01 diff (against the milestone parent `M031` baseline) touches no path under `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, or `scripts/auto/loop/`. Strict allow-list rather than block-list: only the files declared in the P01-PLAN.md "Files Likely Touched" list are permitted to differ from the M031 baseline.

T04 is the phase-close gate. Once T04's verifiers are green, P01 is ready for `orchestrator:verify` followed by `orchestrator:consolidate`.

## Steps

1. **Author `tools/verify/m031-p01-phase-suite.sh`.** Bash 3.2-compatible, executable. Behavior:
   - Resolve `PROJECT_ROOT` from the script's own location (use `cd "$(dirname ...)/../.."` and `pwd`).
   - Initialize counters `pass=0` and `fail=0`.
   - Invoke each P01 sub-gate sequentially in this order (matches T01 → T02 → T03 dependency order); for each, capture the exit code; if 0 emit `OK: <gate-name>` on stdout and increment pass; else emit `FAIL: <gate-name> rc=<code>` on stdout and increment fail. Do NOT short-circuit — run all nine gates regardless of intermediate failures so the operator sees the complete report:
     1. `bash tools/verify/m031-p01-build-context-profile-shape.sh`
     2. `bash tools/verify/m031-p01-quick-no-skip-branch.sh`
     3. `bash tools/verify/m031-p01-config-knobs-stable.sh`
     4. `bash tools/verify/m031-p01-dispatch-md-reconciliation.sh`
     5. `bash tools/verify/m031-p01-post-baseline-jsonl-population.sh`
     6. `bash tools/verify/m031-p01-test-quick-injects-knowledge-shape.sh`
     7. `bash tools/verify/m031-p01-test-build-context-profile-shape.sh`
     8. `bash tools/verify/m031-p01-test-compression-applies-to-quick-shape.sh`
     9. `bash tools/verify/m031-p01-test-quick-budget-median-shape.sh`
   - Emit final stdout line: `SUMMARY: m031-p01-phase-suite.sh pass=N fail=M`.
   - Exit 0 iff `fail=0`; else exit 1.
   - **Straight-line discipline (AD-19)**: no array loops, no inline `for`/`while`/`if` blocks chaining the nine gates. Each gate is a separate sequential invocation with its own captured exit code. This mirrors the P00 phase-suite pattern from `tools/verify/p00-phase-suite.sh`.
   - File header: contains "SUMMARY:", "m031-p01-build-context-profile-shape", "m031-p01-quick-no-skip-branch", "m031-p01-dispatch-md-reconciliation", "m031-p01-phase-suite".

2. **Author `tools/verify/m031-p01-scope-guard.sh`.** Bash 3.2-compatible, executable. Behavior:
   - Use `git diff --name-only` against the milestone-parent baseline (the commit that immediately predates P01's first commit; the operator-supplied default is `--against <ref>` with a fallback to `HEAD~N` or to the most recent tag matching `M030*`). The simplest robust default: `git diff --name-only HEAD` reports all changes in the working tree + index; the verifier asserts only the P01-allowed paths appear.
   - Define the strict allow-list (matches `P01-PLAN.md` "Files Likely Touched"):
     ```
     scripts/dispatch/build-context.sh
     commands/dispatch.md
     tests/m031-acceptance/fixtures/empirical-baseline/post-m031-emitter.sh
     tests/m031-acceptance/fixtures/empirical-baseline/post-m031-baseline.jsonl
     tests/m031-acceptance/test-quick-injects-knowledge.sh
     tests/m031-acceptance/test-build-context-profile.sh
     tests/m031-acceptance/test-compression-applies-to-quick.sh
     tests/m031-acceptance/test-quick-budget-median.sh
     tools/verify/m031-p01-build-context-profile-shape.sh
     tools/verify/m031-p01-quick-no-skip-branch.sh
     tools/verify/m031-p01-config-knobs-stable.sh
     tools/verify/m031-p01-dispatch-md-reconciliation.sh
     tools/verify/m031-p01-post-baseline-jsonl-population.sh
     tools/verify/m031-p01-test-quick-injects-knowledge-shape.sh
     tools/verify/m031-p01-test-build-context-profile-shape.sh
     tools/verify/m031-p01-test-compression-applies-to-quick-shape.sh
     tools/verify/m031-p01-test-quick-budget-median-shape.sh
     tools/verify/m031-p01-phase-suite.sh
     tools/verify/m031-p01-scope-guard.sh
     [.orchestrator/milestones/M031/phases/P01/P01-PLAN.md](../../../../../milestones/M031/phases/P01/P01-PLAN.md)
     [.orchestrator/milestones/M031/phases/P01/tasks/T01-build-context-profile-PLAN.md](../../../../../milestones/M031/phases/P01/tasks/T01-build-context-profile-PLAN.md)
     [.orchestrator/milestones/M031/phases/P01/tasks/T02-ad14-capture-and-fr4-PLAN.md](../../../../../milestones/M031/phases/P01/tasks/T02-ad14-capture-and-fr4-PLAN.md)
     [.orchestrator/milestones/M031/phases/P01/tasks/T03-acceptance-tests-PLAN.md](../../../../../milestones/M031/phases/P01/tasks/T03-acceptance-tests-PLAN.md)
     [.orchestrator/milestones/M031/phases/P01/tasks/T04-phase-suite-and-scope-guard-PLAN.md](../../../../../milestones/M031/phases/P01/tasks/T04-phase-suite-and-scope-guard-PLAN.md)
     .orchestrator/milestones/M031/phases/P01/tasks/T01-SUMMARY.md
     .orchestrator/milestones/M031/phases/P01/tasks/T02-SUMMARY.md
     .orchestrator/milestones/M031/phases/P01/tasks/T03-SUMMARY.md
     [.orchestrator/milestones/M031/phases/P01/tasks/T04-SUMMARY.md](../../../../../milestones/M031/phases/P01/tasks/T04-SUMMARY.md)
     [.orchestrator/milestones/M031/phases/P01/P01-SUMMARY.md](../../../../../milestones/M031/phases/P01/P01-SUMMARY.md)
     ```
     plus a permissive prefix `.orchestrator/observability/` for JSONL emission records.
   - Define the strict block-list (SC-12 forbidden):
     - any path matching `knowledge/`
     - any path matching `scripts/cost/`
     - any path matching `scripts/dispatch/adapters/router/`
     - any path matching `scripts/auto/loop/`
   - For each changed path: assert it does NOT match the block-list. Emit `FAIL: scope-guard violation: <path> matches <block-pattern>` on any block-list match; emit `WARN: out-of-allow-list: <path>` on a path that matches neither allow nor block (informational, not a failure — the allow-list is comprehensive but the verifier keeps a soft warning channel for new files the planner did not anticipate).
   - Exit 0 iff zero block-list matches; exit 1 on any block-list match.
   - Emit final stdout line: `SUMMARY: m031-p01-scope-guard.sh pass=N fail=M block_list_violations=K`.
   - File header: contains "knowledge/", "scripts/cost", "scripts/dispatch/adapters/router", "scripts/auto/loop", "SC-12".
   - **Guard against well-intentioned future "fixes"**: the block-list is normative per CON-1 + DC-3 + Principle XV. Future maintainers tempted to relax it MUST first amend the spec's "Boundary write-sites M031 delegates" section. The verifier file's header comment names this contract.

3. **Run both new verifiers locally** to confirm exit 0:
   - `bash tools/verify/m031-p01-phase-suite.sh` — should report `SUMMARY: m031-p01-phase-suite.sh pass=9 fail=0`.
   - `bash tools/verify/m031-p01-scope-guard.sh` — should report `SUMMARY: m031-p01-scope-guard.sh pass=N fail=0 block_list_violations=0`.

## Must-Haves

This task addresses the following Must-Haves from `P01-PLAN.md`:
- "tools/verify/m031-p01-phase-suite.sh exists, is executable, and invokes every P01 gate in order" (Truth #10; Check via the suite itself)
- "The SC-12 scope-guard invariant holds for the P01 diff" (Truth #11; Check via `m031-p01-scope-guard.sh`)

## Verification

```bash
bash tools/verify/m031-p01-phase-suite.sh
```

```bash
bash tools/verify/m031-p01-scope-guard.sh
```

## Notes

- The phase-suite pattern is reused from P00 (`tools/verify/p00-phase-suite.sh`). Straight-line invocation, no array loops, no inline `for`/`while`/`if` chaining — AD-19 compliant.
- The scope-guard verifier is local-grain (T04 is the place SC-12 lives, since by definition you cannot verify the whole-phase scope until all phase tasks have committed). P04 will ship a milestone-grain `scope-guard.sh` under `tests/m031-acceptance/` that aggregates across all M031 phases (per the roadmap's P04 boundary).
- The expected pass count for the phase-suite is exactly 9 (one per sub-gate). If a future task introduces a new sub-gate, the suite MUST be amended additively and the expected count updated (the suite emits `pass=N` not `pass=9`, so the count is data, not a hard-coded literal — but the operator should review additions).
- D020 token hygiene (CON-7): authored prose in the verifiers MUST NOT embed the literal scaffold-placeholder open-bracket-TODO-colon byte pattern inside backticked inline code.

## Inputs

### From Previous Tasks

The phase-suite invokes nine pre-existing verifiers from T01/T02/T03. Each is a single-script invocation:

- From T01:
  - `tools/verify/m031-p01-build-context-profile-shape.sh` — asserts `--profile` + `--meta-out` flags + 5-key sidecar schema.
  - `tools/verify/m031-p01-quick-no-skip-branch.sh` — asserts no `# skip context` early-exit pattern in build-context.sh.
  - `tools/verify/m031-p01-config-knobs-stable.sh` — asserts the three P00 config knobs unchanged.
- From T02:
  - `tools/verify/m031-p01-post-baseline-jsonl-population.sh` — asserts 20 post-m031 JSONL records exist.
  - `tools/verify/m031-p01-dispatch-md-reconciliation.sh` — asserts FR-4 reconciliation in commands/dispatch.md.
- From T03:
  - `tools/verify/m031-p01-test-quick-injects-knowledge-shape.sh` (SC-1)
  - `tools/verify/m031-p01-test-build-context-profile-shape.sh` (SC-2 / AD-13)
  - `tools/verify/m031-p01-test-compression-applies-to-quick-shape.sh` (SC-3 / AD-17)
  - `tools/verify/m031-p01-test-quick-budget-median-shape.sh` (SC-15 / AD-18)

Each emits its own `SUMMARY: <script> pass=N fail=M` line and exits 0 iff `fail=0`. The phase-suite reads each exit code; it does NOT parse the SUMMARY lines (parsing would couple the suite to envelope formatting; exit codes are the load-bearing contract).

### From Disk (Pre-existing)

- `tools/verify/p00-phase-suite.sh` — P00's phase-suite aggregator. T04's phase-suite mirrors this structure verbatim (same straight-line invocation pattern, same `OK:`/`FAIL:` per-gate emission, same final `SUMMARY:` envelope).
- `git` (CLI) — required for the scope-guard's `git diff --name-only`. P01 already runs in a git repo; this is a hard requirement.

## Constraints

- **Bash 3.2 compatibility** (MEM001): no `declare -A`, no process substitution, no `$()` containing pipes inside conditionals.
- **AD-19 single-script-file shape**: every verifier invocation in the phase-suite MUST be a single `bash <script-path>` invocation. No compound `;`/`&&`/`||` chaining beyond the canonical `&&`/`||` pair. No inline subshells, no command substitution containing pipes.
- **Straight-line phase-suite**: no array loops, no `for`/`while` over an array of gates. Each gate is its own sequential invocation. (Mirrors P00.)
- **No edits to T01/T02/T03 deliverables** in T04 (T04 is purely additive — new verifiers under `tools/verify/`).
- **No edits to `templates/orchestrator-config-default.yml`**, `commands/dispatch.md`, `scripts/dispatch/build-context.sh`, or any other artifact owned by upstream tasks.
- **SC-12 scope-guard self-application**: the scope-guard verifier itself lives at `tools/verify/m031-p01-scope-guard.sh`, which is in the P01 allow-list. (The verifier does not flag itself.)
- **Verifier path discipline**: both new verifiers live under `tools/verify/m031-p01-*.sh`.

## Expected Output

After T04 completes:

1. `tools/verify/m031-p01-phase-suite.sh` exists, executable, invokes all nine P01 sub-gates straight-line, emits `SUMMARY: m031-p01-phase-suite.sh pass=9 fail=0`, exits 0.
2. `tools/verify/m031-p01-scope-guard.sh` exists, executable, asserts no block-list violations in the P01 diff, emits `SUMMARY: m031-p01-scope-guard.sh pass=N fail=0 block_list_violations=0`, exits 0.
3. Running `bash tools/verify/m031-p01-phase-suite.sh` is the single load-bearing P01 gate — green here means P01 is ready for `orchestrator:verify` and `orchestrator:consolidate`.

T04 closes P01. The next phase is P02 (Tier A+ middle flow, depends on P01 sidecar + profile flag).

## State Context

- **Current State**: executing
- **Milestone**: M031
- **Phase**: P01
- **Task**: T04-phase-suite-and-scope-guard
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **Bash 3.2 compatibility** (MEM001): no `declare -A`, no process substitution, no `$()` containing pipes inside conditionals.
- **AD-19 single-script-file shape**: every verifier invocation in the phase-suite MUST be a single `bash <script-path>` invocation. No compound `;`/`&&`/`||` chaining beyond the canonical `&&`/`||` pair. No inline subshells, no command substitution containing pipes.
- **Straight-line phase-suite**: no array loops, no `for`/`while` over an array of gates. Each gate is its own sequential invocation. (Mirrors P00.)
- **No edits to T01/T02/T03 deliverables** in T04 (T04 is purely additive — new verifiers under `tools/verify/`).
- **No edits to `templates/orchestrator-config-default.yml`**, `commands/dispatch.md`, `scripts/dispatch/build-context.sh`, or any other artifact owned by upstream tasks.
- **SC-12 scope-guard self-application**: the scope-guard verifier itself lives at `tools/verify/m031-p01-scope-guard.sh`, which is in the P01 allow-list. (The verifier does not flag itself.)
- **Verifier path discipline**: both new verifiers live under `tools/verify/m031-p01-*.sh`.

### Acceptance Criteria

This task addresses the following Must-Haves from `P01-PLAN.md`:
- "tools/verify/m031-p01-phase-suite.sh exists, is executable, and invokes every P01 gate in order" (Truth #10; Check via the suite itself)
- "The SC-12 scope-guard invariant holds for the P01 diff" (Truth #11; Check via `m031-p01-scope-guard.sh`)

### Files To Touch

- `scripts/dispatch/build-context.sh` (modify)
- `commands/dispatch.md` (modify)
- `tests/m031-acceptance/fixtures/empirical-baseline/post-m031-emitter.sh` (create)
- `tests/m031-acceptance/fixtures/empirical-baseline/post-m031-baseline.jsonl` (create)
- `tests/m031-acceptance/test-quick-injects-knowledge.sh` (create)
- `tests/m031-acceptance/test-build-context-profile.sh` (create)
- `tests/m031-acceptance/test-compression-applies-to-quick.sh` (create)
- `tests/m031-acceptance/test-quick-budget-median.sh` (create)
- `tools/verify/m031-p01-build-context-profile-shape.sh` (create)
- `tools/verify/m031-p01-quick-no-skip-branch.sh` (create)
- `tools/verify/m031-p01-config-knobs-stable.sh` (create)
- `tools/verify/m031-p01-dispatch-md-reconciliation.sh` (create)
- `tools/verify/m031-p01-post-baseline-jsonl-population.sh` (create)
- `tools/verify/m031-p01-test-quick-injects-knowledge-shape.sh` (create)
- `tools/verify/m031-p01-test-build-context-profile-shape.sh` (create)
- `tools/verify/m031-p01-test-compression-applies-to-quick-shape.sh` (create)
- `tools/verify/m031-p01-test-quick-budget-median-shape.sh` (create)
- `tools/verify/m031-p01-phase-suite.sh` (create)
- `tools/verify/m031-p01-scope-guard.sh` (create)

<!-- The phase plan and task plan files themselves (this file +
     tasks/T0[1-4]-*-PLAN.md) are written by the planner, not by the
     executor — they are not listed here. The post-m031-baseline.jsonl
     is technically WRITTEN by T02 invoking the harness (which emits the
     records), but the harness invocation is part of T02's Steps. -->

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