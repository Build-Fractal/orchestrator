---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T01-cluster-helper (Phase P05, Milestone M020)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~500 | required |
| Upstream Context | 981-1223 | ~6900 | required |
| Task Plan | 1225-1874 | ~6700 | required |
| State Context | 1876-1882 | ~100 | required |
| First-Turn Completeness | 1884-1930 | ~1300 | required |
| **Total** | | **~26300** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 456
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
hit_count: 456
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
hit_count: 456
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
hit_count: 456
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
hit_count: 401
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
hit_count: 401
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
hit_count: 401
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
hit_count: 456
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
hit_count: 401
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
hit_count: 401
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
hit_count: 401
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
hit_count: 456
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
hit_count: 456
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
hit_count: 456
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
hit_count: 401
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
hit_count: 401
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
hit_count: 401
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
hit_count: 456
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
hit_count: 401
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
hit_count: 401
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
hit_count: 456
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
hit_count: 456
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
hit_count: 401
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
hit_count: 401
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
hit_count: 401
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
hit_count: 56
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
hit_count: 56
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
hit_count: 56
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
hit_count: 32
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
hit_count: 32
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
hit_count: 22
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

<!-- Each truth is a behavioral statement + a single-script-file Check.
     Per AD-19 / MEM031 / P01+P03 retrospective lessons, Truth Check
     commands MUST use single-invocation script-file shape — no inline
     compound bash, no plain subshells, no $() containing pipes, no
     process substitution. Verifier scripts referenced here are produced
     by the listed task; the phase-level Verification Commands block at
     the bottom is the rollup. -->

- `scripts/knowledge/lib/cluster.sh` exists, is sourceable, and exposes `cluster_compute <root> <threshold>` (emits `<cluster-id>\t<member-id>` lines, one per (cluster, member) pair) and `cluster_id_for <sorted-member-id-csv>` (deterministic `C<8-hex>` content-hash per AD-3).
  - Check: `bash scripts/verify/m020-p05-cluster-helper-contract.sh`
- `scripts/knowledge/lib/cluster.sh::cluster_compute` produces deterministic output: invoking it twice against the same fixture produces byte-identical stdout (sorted by cluster-id then member-id).
  - Check: `bash scripts/verify/m020-p05-cluster-determinism.sh`
- `scripts/knowledge/lib/cluster.sh::cluster_compute` against a ten-entry fixture (four near-duplicates above threshold, six distinct) emits seven distinct cluster IDs covering all ten members exactly once (no orphans, no duplicates).
  - Check: `bash scripts/verify/m020-p05-cluster-singleton-coverage.sh`
- `scripts/knowledge/lib/jaccard.sh` exposes the extended CON-5 feature vector (`title` + `topic` + `tags[]` + `relates_to[]` + `source_unit` + body words capped at 200 tokens), and the validation report at [`.orchestrator/milestones/M020/phases/P05/jaccard-validation-report.md`](../../../../../milestones/M020/phases/P05/jaccard-validation-report.md) is regenerated against the live tree using the extended vector with the new threshold recommendation recorded.
  - Check: `bash scripts/verify/m020-p05-feature-vector-extension.sh`

<dispatch-volatile>

## Upstream Context


### P01 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M020"
milestone: "M020"
provides:
  - "status:-field closed-enum schema gate (D024 + MEM031); verification scripts m020-p01-mem031-vocabulary.sh + m020-p01-d024-row.sh,atomic frontmatter read/write helpers for M020 schema-evolution fields (status:,decision_history:,archived_into:); contract verifier m020-p01-frontmatter-helper-contract.sh,minimum-viable scripts/knowledge/graduate.sh single-entry candidate to graduated flip via T02 fm_write_status; two verifier scripts m020-p01-graduate-single-entry.sh and m020-p01-graduate-side-effect-scope.sh,scripts/knowledge/lib/jaccard.sh exposing pairwise_jaccard subcommand (CON-5 feature vector,similarity=N.NNNN structured output) plus validate subcommand stub (writes report header + iteration loop output to [.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md](../../../../../milestones/M020/phases/P01/jaccard-validation-report.md),T05 enriches recommendation); contract verifier scripts/verify/m020-p01-jaccard-pairwise-contract.sh covering 4 cases (identical=1.0000,disjoint<0.3,partial in (0.3,1.0),missing-file rejected),enriched scripts/knowledge/lib/jaccard.sh validate subcommand (computes pair-count distribution buckets,top-10 pairs table,threshold recommendation derived from observed top-similarity,CON-5 feature-vector sanity-check stats; writes the canonical jaccard-validation-report.md with the four T05-required H2 sections); [.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md](../../../../../milestones/M020/phases/P01/jaccard-validation-report.md) fully enriched against the live tree (31 entries,465 pairs,top sim 0.2000); scripts/verify/m020-p01-jaccard-validation-report.sh (validates the report contract: required tokens,required H2 sections,no placeholder strings,numeric threshold recommendation,PASS verdict line); scripts/verify/m020-p01-migration-incremental.sh (asserts P01 did not bulk-migrate -- counts entries with status: field against a 5%-of-total floor-of-2 limit,with a soft milestone-log cross-check capping recognized task closes)"
requires:
  - "none"
affects:
  - "P02,P03,P05"
key_files:
  - "[.orchestrator/DECISIONS.md](../../../../../decisions.md);[knowledge/conventions/MEM031.md](../../../../../knowledge/conventions/MEM031.md);KNOWLEDGE-INDEX.md;scripts/verify/m020-p01-mem031-vocabulary.sh;scripts/verify/m020-p01-d024-row.sh,scripts/knowledge/lib/frontmatter.sh;scripts/verify/m020-p01-frontmatter-helper-contract.sh,scripts/knowledge/graduate.sh;scripts/verify/m020-p01-graduate-single-entry.sh;scripts/verify/m020-p01-graduate-side-effect-scope.sh,scripts/knowledge/lib/jaccard.sh;scripts/verify/m020-p01-jaccard-pairwise-contract.sh;[.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md](../../../../../milestones/M020/phases/P01/jaccard-validation-report.md),scripts/knowledge/lib/jaccard.sh;scripts/verify/m020-p01-jaccard-validation-report.sh;scripts/verify/m020-p01-migration-incremental.sh;[.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md](../../../../../milestones/M020/phases/P01/jaccard-validation-report.md)"
key_decisions:
  - "D024,none-new"
patterns_established:
  - "schema-authority gate via D-row + conventions MEM before code lands; closed-enum discipline for query-surface stability; companion-field cohesion (status:/decision_history:/archived_into: documented together),atomic frontmatter mutation via tempfile+rename(2); awk-based pure-passthrough writes preserving CON-4 byte-equivalence; closed-enum guard runs BEFORE tempfile creation so invalid values produce zero file I/O; FR-10 incremental-migration default (absent status: reads as graduated),closed-enum case dispatch on fm_read_status with three branches (graduated NO-OP exit 0; archived FAIL exit 1; candidate flip+exit 0); idempotent re-invocation per MEM001; rationale stubbed to stdout RATIONALE line in P01 with FR-7 frontmatter append deferred to P03; PROJECT_ROOT env-var fixture-isolation strategy for verifier scripts because lib/index-utils.sh get_project_root honors PROJECT_ROOT not ORCHESTRATOR_ROOT,bash 3.2 pure-function pairwise primitive: tokenize -> sort -u -> comm -12 for intersection / cat+sort -u for union / awk for floating-point division (no bc dependency); first-paragraph awk extraction must defer blank-line termination until at least one content line printed (otherwise the conventional blank-line gap between H1 and body is misread as paragraph end); validate-subcommand scaffolding pattern (header + iteration loop ships in T-N,threshold/recommendation analysis lands in T-N+1),adaptive-threshold-recommendation (validate computes top observed similarity then branches: >=0.7 retain default,0.3-0.7 lower-moderate at top*0.75,<0.3 lower-aggressive with vector-extension recommendation); status-count-as-bulk-migration-proxy (counting ^status: lines across live entries with a small percentage tolerance is a robust contract proxy that survives unrelated frontmatter churn -- avoids brittle git-diff-against-baseline logic when the baseline state is itself dirty from prior sessions); pre-cache pairwise tokens in tempdir indexed by entry index to avoid O(n^2) re-extraction during validate (was O(n^2) extract+sort calls,now O(n) extract+sort + O(n^2) comm); validate-subcommand owning the persistent enriched report (rather than enrich-once + protect against clobber) means the report is reproducible from source data on every run -- T05 narrative collapses into derived data + observation-conditioned text"
drill_down_paths:
  - "[.orchestrator/milestones/M020/phases/P01/tasks/T01-schema-evolution-gate-SUMMARY.md](../../../../../milestones/M020/phases/P01/tasks/T01-schema-evolution-gate-SUMMARY.md), [.orchestrator/milestones/M020/phases/P01/tasks/T02-frontmatter-helper-SUMMARY.md](../../../../../milestones/M020/phases/P01/tasks/T02-frontmatter-helper-SUMMARY.md), [.orchestrator/milestones/M020/phases/P01/tasks/T03-graduate-script-SUMMARY.md](../../../../../milestones/M020/phases/P01/tasks/T03-graduate-script-SUMMARY.md), [.orchestrator/milestones/M020/phases/P01/tasks/T04-jaccard-helper-SUMMARY.md](../../../../../milestones/M020/phases/P01/tasks/T04-jaccard-helper-SUMMARY.md), [.orchestrator/milestones/M020/phases/P01/tasks/T05-jaccard-validation-SUMMARY.md](../../../../../milestones/M020/phases/P01/tasks/T05-jaccard-validation-SUMMARY.md)"
duration: "105m"
verification_result: "pass"
completed_at: "2026-04-25T05:23:06Z"
observability_surfaces:
  - "none"
---

## What was built

P01 is the foundation phase of M020 (Knowledge-Layer Maturation). It lands the schema-authority gate, the atomic frontmatter helper, the minimum-viable graduation script, the Jaccard primitive consumed by P05, and the validation report that calibrates the clustering threshold against the live tree.

Concretely:

- **Schema authority gate (T01)** — [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) D024 authorises the `status:` closed-enum field; [`knowledge/conventions/MEM031.md`](../../../../../knowledge/conventions/MEM031.md) documents the vocabulary (`candidate` / `graduated` / `archived`) plus the FR-10 default (absent → `graduated`) and companion fields (`decision_history:`, `archived_into:`). All subsequent code in M020 must clear this gate.
- **Atomic frontmatter helper (T02)** — `scripts/knowledge/lib/frontmatter.sh` ships `fm_read_status`, `fm_write_status`, `fm_write_archived_into`, `fm_append_decision_history`, `fm_assert_closed_enum`. Tempfile + `mv` commit guarantees CON-4 byte-equivalence; closed-enum guard runs before tempfile creation so invalid values produce zero file I/O.
- **Minimum-viable graduate.sh (T03)** — `scripts/knowledge/graduate.sh --rationale '<text>' <entry-id>` flips a single-entry candidate→graduated atomically via the helper. Idempotent (re-running on graduated emits NO-OP exit 0); rejects re-flipping `archived`. Cluster mode, multi-entry atomicity, and `decision_history:` write deferred to P03.
- **Jaccard primitive (T04)** — `scripts/knowledge/lib/jaccard.sh` exposes `pairwise_jaccard <file-a> <file-b>` (CON-5 feature vector: `topic` + `tags[]` + first-50-token first-paragraph; case-folded; sort+comm intersection; awk floating-point division — no `bc` dependency). Pure function, deterministic, byte-stable.
- **Validation report + cross-task invariant (T05)** — `scripts/knowledge/lib/jaccard.sh validate <root>` walks the live tree (31 entries × 465 pairs), computes pair-count distribution, top-10 table, threshold recommendation, and feature-vector sanity stats; writes `phases/P01/jaccard-validation-report.md`. Demo sentence verified end-to-end. `scripts/verify/m020-p01-migration-incremental.sh` enforces the FR-10 no-bulk-migration contract (counts `^status:` lines with a 5%-of-total floor-of-2 limit).

## Key decisions

- **D024 — Schema authority via closed-enum `status:` field**. Authorising decision precedes code.
- **Adaptive threshold recommendation**. The validate subcommand's recommendation is data-driven, not hardcoded: top observed similarity ≥ 0.7 retains the A-5 default; 0.3–0.7 lowers to `top × 0.75`; < 0.3 (the live-tree case) lowers aggressively to ~0.15 AND flags the CON-5 feature vector as too narrow, recommending P05 extend it with `relates_to[]`, `source_unit`, and capped body. After vector extension, threshold can plausibly move back toward 0.7.
- **Status-count-as-bulk-migration proxy**. `migration-incremental.sh` counts `^status:` lines across `knowledge/*/MEM*.md` (archive excluded) with a small percentage tolerance. This is robust against unrelated frontmatter churn (the 30+ `git status` modifications from prior sessions) — git-diff-against-baseline would have false-positived on the dirty baseline.
- **PROJECT_ROOT env-var fixture isolation**. Verifier scripts export `PROJECT_ROOT` (not `ORCHESTRATOR_ROOT`) because `scripts/knowledge/lib/index-utils.sh::get_project_root` honors only `PROJECT_ROOT`. Documented in script comments.
- **Validate-subcommand owns the persistent enriched report**. T04 shipped a stub; T05 promoted the `_jaccard_validate` function to a full enriched-report generator instead of hand-editing the file. The report is reproducible from source data on every run; T05 narrative collapses into derived data + observation-conditioned text.

## Patterns established

- Schema-authority gate via D-row + conventions MEM before any code touches the schema.
- Atomic frontmatter mutation via tempfile + `rename(2)`; closed-enum guard before file I/O.
- Bash 3.2 pure-function pairwise primitive: tokenize → `sort -u` → `comm -12` for intersection / `cat | sort -u` for union / awk for floating-point division.
- First-paragraph awk extraction must defer blank-line termination until ≥ 1 content line printed (the conventional H1↔body blank gap was misread as paragraph end in the initial implementation).
- Validate-subcommand scaffold ships in T-N (header + iteration loop), threshold/recommendation analysis lands in T-N+1.
- Pre-cache pairwise tokens in tempdir keyed by entry index — O(n) extract + O(n²) `comm` instead of O(n²) extract + sort.

## Verification results

All 9 phase-level mechanical verifiers PASS:

- `check-must-haves.sh .orchestrator/milestones/M020/phases/P01` — 8 truths PASS, 12 artifact PASS, 3 key-link PASS (after fixing the `jaccard.sh → MEM031.md` reference comment).
- `m020-p01-graduate-single-entry.sh` — 4/4 cases (flip + idempotent NO-OP + missing-rationale rejection + missing-entry rejection).
- `m020-p01-frontmatter-helper-contract.sh` — 7/7 cases + bonus byte-equivalence.
- `m020-p01-jaccard-pairwise-contract.sh` — 4/4 cases (identical=1.0000, disjoint<0.3, partial in (0.3,1.0), missing-file rejection).
- `m020-p01-jaccard-validation-report.sh` — required tokens, H2 sections, no placeholders, numeric threshold, PASS verdict.
- `m020-p01-mem031-vocabulary.sh` — closed enum + pre-M020 default documented verbatim.
- `m020-p01-d024-row.sh` — D024 row cites `status:`, `candidate`, `graduated`, `archived`, `MEM031`, `FR-9`.
- `m020-p01-graduate-side-effect-scope.sh` — graduate.sh writes only the target entry.
- `m020-p01-migration-incremental.sh` — 0 of 31 live entries bear `status:` (within the 2-entry tolerance).

## Demo sentence

> Running `bash scripts/knowledge/graduate.sh --rationale 'test' <entry-id>` flips an entry's `status:` from `candidate` to `graduated`, and `bash scripts/knowledge/lib/jaccard.sh validate knowledge/` writes a validation report at [`.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md`](../../../../../milestones/M020/phases/P01/jaccard-validation-report.md) confirming the 0.7 threshold + CON-5 feature vector against the live knowledge tree.

Verified end-to-end. The validation report recommends adjusting the default 0.7 threshold to ~0.15 against the *current* CON-5 vector, AND flags the vector itself for extension in P05; both signals are downstream-actionable.

## Plan deviations

- **T04 scope drift (anticipated and contained)** — T04 pre-implemented the `validate` subcommand and produced a stub report. T05 absorbed this by promoting the stub-writer to a full data-driven generator rather than restarting from scratch. Net: identical artifacts, identical contract.
- **T01 plan structure bug fixed mid-flight** — the initial T01 plan embedded MEM031 content with H2 headings that collided with the auto-loop verifier's `## Verification` / `## Must-Haves` parser. Demoted to H3+ post-hoc; lesson captured for downstream task plans.
- **T02 plan referenced T05's verifier inline** — `m020-p01-migration-incremental.sh` was listed in T02's `## Verification` block but doesn't exist until T05. Edited T02's plan to scope the cross-task invariant to phase-verification time. Lesson: task verification commands should never reference scripts produced by future tasks.
- **One-line addition to `jaccard.sh` header comment** — added schema-dependency comment naming `MEM031.md` so the phase-plan key-link (`jaccard.sh → MEM031.md`) check passes literally rather than only conceptually.

## Downstream impact

- **P02 (query surface)** consumes the `status:` schema (filters to `graduated` by default) and the `frontmatter.sh` helper.
- **P03 (graduate.sh extensions)** extends `graduate.sh` in place: cluster mode, multi-entry atomicity, `decision_history:` append; consumes `frontmatter.sh::fm_append_decision_history`.
- **P05 (clustering)** consumes `jaccard.sh::pairwise_jaccard`, the validated threshold (or its data-driven adjustment), and the recommended feature-vector extension.
- **M020/P01 jaccard-validation-report.md** is a calibration artifact — P05 should re-run validate after extending the feature vector to confirm or adjust the threshold.


### P03 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P03"
parent: "M020"
milestone: "M020"
provides:
  - "scripts/knowledge/lib/decision-history.sh sourceable helper exposing dh_resolve_operator (git config user.email -> .orchestrator/preferences.yml:operator_identifier -> unknown@local fallthrough per OQ-2) and dh_emit_jsonl <event> <kv>... (appends single JSON object per call to $ORCH_ROOT/execution-log.jsonl with event+timestamp+milestone plus supplied key=value pairs as JSON string properties; conservative backslash+double-quote escaping; no jq dependency); contract verifier scripts/verify/m020-p03-decision-history-helper-contract.sh covering 5 cases (function exposure,git-set path,tmpdir fallthrough,preferences.yml fallback,JSONL shape,embedded-quote escape),scripts/knowledge/graduate.sh extended in place with --cluster <id> + --reject + multi-entry positional shape; cluster atomicity drift gate (THREAT-006 disposition) with zero file mutations on abort; --reject body archives every member without archived_into; canonical+sibling write loop on graduate path with archived_into back-references; decision_history append on every member via T01+P01 helpers; JSONL emission via dh_emit_jsonl (one knowledge_graduate + N-1 knowledge_archive on graduate; N knowledge_archive on reject); P01 single-entry surface preserved per CON-4; five new T02-owned verifier scripts under scripts/verify/ all green,scripts/verify/knowledge-schema-lint.sh — FR-9 + SC-8 schema-authority enforcement gate covering three failure shapes (unauthorized-field,vocabulary-drift,malformed-frontmatter); embeds the M020-authorized field allowlist as canonical machine-readable encoding of D024 + MEM031; per-task contract verifiers scripts/verify/m020-p03-schema-lint-contract.sh and scripts/verify/m020-p03-schema-lint-vocabulary-drift.sh exercising the lint against tempdir fixtures and the live tree,tests/test-graduate-workflow.sh — SC-2 end-to-end integration test for the P03 graduate.sh extension; exercises four operational modes (three-entry cluster graduate,single-entry cluster graduate,cluster reject,cluster-membership-drift abort) using tempdir+PROJECT_ROOT+ORCH_ROOT fixture isolation; 31 assertions covering status flips,archived_into back-references,decision_history block presence,rationale text propagation,JSONL record counts (knowledge_graduate + knowledge_archive),drift-abort exit code + diagnostic + atomic byte-equivalence + zero-JSONL invariant"
requires:
  - "P01"
affects:
  - "P04,P05"
key_files:
  - "scripts/knowledge/lib/decision-history.sh,scripts/verify/m020-p03-decision-history-helper-contract.sh,scripts/knowledge/graduate.sh,scripts/verify/m020-p03-graduate-cluster-multi-entry.sh,scripts/verify/m020-p03-graduate-cluster-drift-abort.sh,scripts/verify/m020-p03-graduate-reject-path.sh,scripts/verify/m020-p03-graduate-jsonl-emit.sh,scripts/verify/m020-p03-graduate-p01-shape-preserved.sh,scripts/verify/knowledge-schema-lint.sh,scripts/verify/m020-p03-schema-lint-contract.sh,scripts/verify/m020-p03-schema-lint-vocabulary-drift.sh,tests/test-graduate-workflow.sh"
key_decisions:
  - "none-new,D024"
patterns_established:
  - "double-source guard sentinel (_<HELPER>_SOURCED=1) lets multiple sourceable helpers coexist without re-definition,pure-helper composition (T01 resolves identity + emits JSONL; T02 graduate.sh calls dh_resolve_operator once and pairs fm_append_decision_history entry-side with dh_emit_jsonl log-side; the two writes are independent),5-case contract verifier template (function exposure -> happy path -> isolated-tmpdir fallthrough -> env-overridden fallback -> emitter shape -> escape edge case),pragmatic case-statement acceptance for git-leakage-into-tmpdir-verifiers (case op in *@*) ;; unknown@local) ;; *) FAIL ;; esac accepts either real-git-email leaked from ~/.gitconfig or the documented sentinel since GIT_CONFIG_NOSYSTEM cannot be set at script invocation level),cluster-aware mutation script pattern (pre-flight read of every member's gate-relevant state -> abort with structured diagnostic + zero mutations on drift -> deterministic write loop with shared per-cluster scalars (operator,rationale_hash,canonical) -> JSONL emission after all writes succeed); drift-gate-as-CON-4-preserver (gating the new pre-flight on the new flag means the legacy invocation shape pays no cost and exhibits no behavior diff -- generalizable to any in-place script extension); operator+rationale_hash resolved once per cluster invocation (not per-member) for JSONL consistency; per-helper atomicity composes into cluster atomicity (each fm_* write is tempfile+rename atomic; pre-flight drift gate guarantees N writes succeed under FR-9 closed-enum); parallel newline-joined scalars for cluster member tracking (ids/files accumulate as newline-separated strings,iterated via awk -v n=$i NR==n) per MEM001 bash-3.2 convention,closed-enum lint pattern (structural-only,read-only,fixture-tested via tempdir + heredoc,single-script Check shape); authorized-field allowlist as newline-separated heredoc-fed string for bash 3.2 iteration without associative arrays; tempdir + trap-EXIT-rm-rf for negative-test fixtures so the live knowledge/ tree is never touched by verifiers; process-substitution-inside-script-body is AD-19-safe because the harness shape-guard inspects Bash tool-call shapes not script internals,grep -c X file safe-counter — the grep -c pattern returns rc=1 when count is 0 AND prints 0 itself; the common '|| echo 0' fallback DOUBLES the count line and breaks subsequent integer comparisons. Wrap in a count_event helper that suppresses rc with '|| true' and defaults empty to 0. Single-script Verification Check shape (bash tests/test-graduate-workflow.sh) where the test file ITSELF uses heredocs + pipes + process redirections internally — AD-19 / AP-009 govern Bash tool-call shapes,not script internals; the harness shape-guard inspects only the directly-invoked command. Tempdir + trap-EXIT-rm-rf + PROJECT_ROOT + ORCH_ROOT env-override fixture isolation pattern (CON-1 / FR-8 read-only-during-dispatch) — every fixture lives under mktemp -d,and the live knowledge/** + .orchestrator/execution-log.jsonl are never touched. Portable md5 (macOS md5 -q vs linux md5sum) via 'command -v md5sum' fallback for byte-equivalence assertions on drift-abort. JSONL structural assertion via 'grep -c event:X' instead of jq parsing — keeps jq optional per MEM001. fm_get awk frontmatter reader inlined in the test (reads first --- block,supports keys with single-line scalar values,strips wrapping quotes) — no source dependency on lib/frontmatter.sh because the test asserts the post-mutation file contract,not the helper's behavior."
drill_down_paths:
  - "[.orchestrator/milestones/M020/phases/P03/tasks/T01-decision-history-helper-SUMMARY.md](../../../../../milestones/M020/phases/P03/tasks/T01-decision-history-helper-SUMMARY.md), [.orchestrator/milestones/M020/phases/P03/tasks/T02-graduate-cluster-extension-SUMMARY.md](../../../../../milestones/M020/phases/P03/tasks/T02-graduate-cluster-extension-SUMMARY.md), [.orchestrator/milestones/M020/phases/P03/tasks/T03-schema-authority-lint-SUMMARY.md](../../../../../milestones/M020/phases/P03/tasks/T03-schema-authority-lint-SUMMARY.md), [.orchestrator/milestones/M020/phases/P03/tasks/T04-integration-test-SUMMARY.md](../../../../../milestones/M020/phases/P03/tasks/T04-integration-test-SUMMARY.md)"
duration: "85m"
verification_result: "pass"
completed_at: "2026-04-25T14:44:42Z"
observability_surfaces:
  - "execution-log.jsonl:knowledge_graduate;execution-log.jsonl:knowledge_archive"
---

## Phase Outcome

P03 delivered the candidate→graduate cluster workflow plus the
schema-authority enforcement gate. Four tasks executed sequentially
with each task summary written via the structured helper:

- **T01 (decision-history-helper):** `scripts/knowledge/lib/decision-history.sh`
  exposes `dh_resolve_operator` (`git config user.email` →
  `.orchestrator/preferences.yml:operator_identifier` → `unknown@local`
  fallthrough per OQ-2) and `dh_emit_jsonl <event> <kv>...` (appends
  one JSON object per call to `$ORCH_ROOT/execution-log.jsonl` with
  conservative backslash + double-quote escaping; no jq dependency).
  5-case contract verifier covers function exposure, git-set path,
  isolated-tmpdir fallthrough, preferences.yml fallback, JSONL shape
  with embedded-quote escape.
- **T02 (graduate-cluster-extension):** `scripts/knowledge/graduate.sh`
  extended in place with `--cluster <id>`, `--reject`, multi-entry
  positional shape. Pre-flight `fm_read_status` on every member;
  `cluster-membership-drift` abort with zero file mutations on any
  non-`candidate` member (THREAT-006 disposition). Graduate path
  flips first member to `graduated`, remaining members to `archived`
  with `archived_into: <canonical>` back-references; reject path
  archives every member without `archived_into`. `decision_history:`
  appended on every member; one `knowledge_graduate` + N-1
  `knowledge_archive` JSONL records on graduate, N
  `knowledge_archive` on reject. P01 single-entry surface preserved
  byte-equivalent (CON-4) — drift gate and cluster fan-out are gated
  on `--cluster` so legacy invocation pays no cost.
- **T03 (schema-authority-lint):** `scripts/verify/knowledge-schema-lint.sh`
  enforces FR-9 + SC-8 with three failure shapes
  (`unauthorized-field`, `vocabulary-drift`, `malformed-frontmatter`).
  Embeds the M020-authorized field allowlist as canonical
  machine-readable encoding of D024 + MEM031. Live tree scan: 31
  entries / 0 violations.
- **T04 (integration-test):** `tests/test-graduate-workflow.sh` —
  311-line MEM002-conformant SC-2 end-to-end across four cases:
  three-entry cluster graduate (13 PASS), single-entry cluster
  graduate (5 PASS), cluster reject (8 PASS), cluster-membership-drift
  abort (5 PASS). 31/31 assertions PASS.

## Verification

9/9 phase-level truths PASS. 32/32 artifact assertions PASS. 4/4
key-link assertions PASS. All four per-task verifications PASS.
Phase rollup `bash scripts/verify/check-must-haves.sh
.orchestrator/milestones/M020/phases/P03` exits 0. Live-tree
schema lint exits 0 against 31 entries.

## Key Patterns

- **Cluster-aware mutation script pattern:** pre-flight read of every
  member's gate-relevant state → abort with structured diagnostic +
  zero mutations on drift → deterministic write loop with shared
  per-cluster scalars (operator, rationale_hash, canonical) → JSONL
  emission after all writes succeed.
- **Drift-gate-as-CON-4-preserver:** gating new pre-flight checks on
  the new flag means legacy invocation pays no cost and exhibits no
  behavior diff — generalizable to any in-place script extension.
- **Pure-helper composition (T01 + T02):** `dh_resolve_operator` once
  per cluster + `fm_append_decision_history` entry-side paired with
  `dh_emit_jsonl` log-side. The two writes are independent and
  composable with file-level atomicity (tempfile+rename) into
  cluster atomicity.
- **Closed-enum lint pattern:** structural-only, read-only,
  fixture-tested via tempdir + heredoc. Authorized-field allowlist
  encoded as newline-separated heredoc-fed string for bash 3.2
  iteration without associative arrays.
- **Pragmatic case-statement acceptance for environmental leakage:**
  when GIT_CONFIG_NOSYSTEM cannot be enforced at script-invocation
  level, accept either the real-git-email leaked from `~/.gitconfig`
  or the documented sentinel via `case op in *@*) ok;; unknown@local) ok;; *) fail;;`.
- **`grep -c X file` safe-counter:** `grep -c` returns rc=1 AND
  prints `0` when count is zero. The common `|| echo 0` fallback
  *doubles* the count line and breaks integer comparisons. Wrap in a
  `count_event()` helper that suppresses rc with `|| true` and
  defaults empty to 0.
- **Process-substitution-inside-script-body is AD-19 safe:** the
  harness shape-guard inspects Bash tool-call shapes, not script
  internals. Test files can use heredocs + pipes + process
  redirections freely; only the directly-invoked command shape is
  gated.
- **Portable md5:** `command -v md5sum` fallback for macOS
  (`md5 -q`) vs linux (`md5sum`) byte-equivalence assertions.
- **Double-source guard sentinel** (`_<HELPER>_SOURCED=1`) lets
  multiple sourceable helpers coexist without re-definition.

## Carry-Forward Lessons

In addition to the seven lessons recorded at the P02→P03 boundary
(see `.orchestrator/milestones/M020/continue.md`), P03 added:

8. **`grep -c` is rc-1 + prints-`0` on no-match.** The `|| echo 0`
   fallback emits `0\n0` on no-match, which breaks `[ "$count" -eq N ]`.
   Wrap in `count_event()` with `|| true` and default-empty-to-zero.
9. **Pre-existing `git status` dirtiness (hit_count churn from prior
   index rebuilds + ingest runs) is the new normal.** Future
   verifiers should NOT assert `git status knowledge/` is empty;
   instead assert that the verifier under test *did not write to
   `knowledge/`* via tempdir-scoped fixture isolation. The phase
   plan's "Done when" criterion misled T03 into noting a non-blocking
   caveat that's structurally pre-existing.
10. **Environmental git-config leakage in tests:** when fixture
    isolation requires "no git identity available", `GIT_CONFIG_NOSYSTEM`
    cannot be set at the dispatched script level. Accept either real
    leaked email or the sentinel — tighter assertion is impossible
    without rewriting the dispatch wrapper.

## Affects Downstream

- **P04 (review queue in `orchestrator:status`):** consumes the
  `decision_history:` schema field + JSONL `knowledge_graduate` /
  `knowledge_archive` records to surface pending-review state.
- **P05 (Jaccard clustering in `orchestrator:consolidate`):**
  consumes `--cluster <id>` graduate.sh entry point + the
  cluster-membership-drift contract (THREAT-006). Cluster-id
  generation lives in P05; graduate.sh trusts the caller's id.
- **P06 (preferences layer):** continues to consume P02's `query.sh`
  JSON shape; P03 added `preferences.yml:operator_identifier` as
  the documented identity-fallback key.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P05"
milestone: "M020"
name: "Cluster computation helper (lib/cluster.sh)"
depends_on: []
---

## Prerequisites

- P01: `scripts/knowledge/lib/jaccard.sh` exposes `pairwise_jaccard <file-a> <file-b>` (emits `similarity=N.NNNN` to stdout) and `_jaccard_extract_tokens <file>` (echoes feature-vector tokens, one per line). Bash 3.2 safe.
- P01: `scripts/knowledge/lib/index-utils.sh` exposes `get_project_root` (honors `PROJECT_ROOT` env var per the 4-rule resolver) and adjacent helpers. `scripts/knowledge/lib/detail-utils.sh` exposes `find_detail_file <id>`.
- P01: `scripts/knowledge/lib/frontmatter.sh` exposes `fm_read_status <file>` returning the `status:` field value (or `graduated` per FR-10 default for entries lacking the field).
- M020 ROADMAP cross-cutting concern (atomic frontmatter writes / read-only-during-dispatch): cluster.sh is a pure read-only helper; it MUST NOT mutate any file under `knowledge/**` or anywhere else. All output flows to stdout.
- M020-CONTEXT.md AD-3: cluster IDs are content-hashes of the cluster's sorted member-ID set, truncated to 8 hex characters and prefixed `C`. Deterministic across runs.

## Description

Create a NEW pure-function helper at `scripts/knowledge/lib/cluster.sh` that implements FR-5 clustering on top of the P01 `pairwise_jaccard` primitive. The helper is sourceable (double-source-guarded per the P03 convention) and exposes two functions:

1. **`cluster_compute <knowledge-root> <threshold>`** — walks `<knowledge-root>` for `MEM*.md` files (filtering to `status: candidate` only — graduated and archived entries are not eligible for clustering per spec FR-5 implicit semantic; this is verified by tempdir-fixture isolation in the verifier suite), computes the pairwise Jaccard graph, finds connected components with edge-weight >= `<threshold>`, and emits one TAB-separated `<cluster-id>\t<member-id>` line per (cluster, member) pair on stdout, sorted by `<cluster-id>` ascending then `<member-id>` ascending. Singletons (members with no above-threshold neighbours) form their own one-member clusters. Pure read; no file mutations; no JSONL emission. Exit 0 on success; non-zero on error (e.g. unreadable knowledge-root).

2. **`cluster_id_for <sorted-csv-of-member-ids>`** — deterministic content-hash. Echoes `C<first-8-hex-of-sha1(<sorted-csv>)>` on stdout. Same input -> same output across runs (AD-3 contract). The CSV must be sorted by the caller; cluster_id_for does not re-sort.

The connected-component algorithm is the standard union-find or BFS-from-each-unvisited-node approach over the similarity graph. Bash 3.2 safe: parallel indexed scalars for the union-find parent array; no `declare -A`. Iteration over pairs is O(n^2) which is fine at the milestone scale (<= 50 candidate entries per milestone per the M020-CONTEXT.md rebuild-cost note).

`cluster.sh` is operator-invoked indirectly via `consolidate-artifacts.sh --cluster` (T03 of this phase). It is NOT a callable surface from dispatch (FR-8 / CON-1 — clustering is mutation-adjacent and operator-only).

## Steps

### Step 1: Create `scripts/knowledge/lib/cluster.sh`

Path: `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/knowledge/lib/cluster.sh`

Reference implementation:

```bash
#!/usr/bin/env bash
# scripts/knowledge/lib/cluster.sh — FR-5 clustering helper consumed by
# scripts/knowledge/consolidate-artifacts.sh (P05 --cluster extension).
#
# Provides:
#   cluster_compute <knowledge-root> <threshold>
#       Walks <knowledge-root>/**/MEM*.md filtering to status: candidate,
#       computes pairwise Jaccard via pairwise_jaccard, builds an undirected
#       similarity graph with edges where similarity >= threshold, emits one
#       TAB-separated <cluster-id>\t<member-id> line per (cluster, member)
#       pair on stdout, sorted by cluster-id asc then member-id asc.
#       Singletons form their own one-member clusters.
#
#   cluster_id_for <sorted-csv-of-member-ids>
#       Deterministic AD-3 cluster ID. Echoes C<8-hex> on stdout.
#       Same input -> same output across runs.
#
# Pure helpers — neither writes to knowledge/** nor to .orchestrator/**.
# All output flows to stdout.
#
# Schema dependency: consumes the closed-enum status: vocabulary defined in
# knowledge/conventions/MEM031.md (candidate|graduated|archived). Pre-M020
# entries without a status: field default to graduated per FR-10 and are
# therefore EXCLUDED from clustering (graduated entries are not eligible).
#
# References lib/jaccard.sh for pairwise_jaccard primitive (AD-19 single-
# script-invocation safe — pairwise_jaccard is sourced as a function, not
# spawned).
#
# Bash 3.2 compatible. AD-19 single-script-invocation shape. MEM001 prefixed-
# output conventions.

# --- Double-source guard ---
[ -n "${_CLUSTER_HELPER_SOURCED:-}" ] && return 0
_CLUSTER_HELPER_SOURCED=1

_CLUSTER_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=jaccard.sh
. "$_CLUSTER_SCRIPT_DIR/jaccard.sh"
# shellcheck source=frontmatter.sh
. "$_CLUSTER_SCRIPT_DIR/frontmatter.sh"

# --- AD-3 cluster ID: C<first-8-hex-of-sha1(sorted-csv)> ---
cluster_id_for() {
  local sorted_csv="$1"
  local hash
  if command -v shasum >/dev/null 2>&1; then
    hash="$(printf '%s' "$sorted_csv" | shasum -a 1 | awk '{print substr($1,1,8)}')"
  elif command -v sha1sum >/dev/null 2>&1; then
    hash="$(printf '%s' "$sorted_csv" | sha1sum | awk '{print substr($1,1,8)}')"
  else
    echo "FAIL: cluster_id_for requires shasum or sha1sum" >&2
    return 1
  fi
  printf 'C%s\n' "$hash"
}

# --- cluster_compute: walk tree, compute pairwise graph, emit clusters ---
# Args: <knowledge-root> <threshold>
# Threshold is a decimal in [0.0, 1.0]; awk handles the floating-point compare.
# Output: one TAB-separated <cluster-id>\t<member-id> line per (cluster, member)
# pair, sorted by cluster-id asc, then member-id asc.
cluster_compute() {
  local root="$1"
  local threshold="$2"

  if [ -z "$root" ] || [ ! -d "$root" ]; then
    echo "FAIL: cluster_compute requires an existing knowledge-root directory (got '$root')" >&2
    return 1
  fi
  if [ -z "$threshold" ]; then
    echo "FAIL: cluster_compute requires a threshold argument" >&2
    return 1
  fi

  # --- Step A: collect candidate entry ids + file paths ---
  # Bash 3.2: parallel newline-joined scalars, not associative arrays.
  local ids=""
  local files=""
  local n=0

  local f
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    [ -f "$f" ] || continue
    # Filter to status: candidate. fm_read_status falls back to graduated for
    # missing field per FR-10; we only want explicit candidates.
    local raw_status
    raw_status="$(awk '
      /^---$/ { n++; if (n==2) exit; next }
      n==1 && /^status:/ {
        sub(/^status:[[:space:]]*/, "")
        sub(/[[:space:]]+$/, "")
        sub(/^"/, ""); sub(/"$/, "")
        print
        exit
      }
    ' "$f" 2>/dev/null || true)"
    [ "$raw_status" = "candidate" ] || continue

    # Derive entry id from the basename minus extension.
    local id
    id="$(basename "$f" .md)"

    if [ "$n" -eq 0 ]; then
      ids="$id"
      files="$f"
    else
      ids="$ids
$id"
      files="$files
$f"
    fi
    n=$(( n + 1 ))
  done <<EOF
$(find "$root" -type f -name 'MEM*.md' | LC_ALL=C sort)
EOF

  if [ "$n" -eq 0 ]; then
    # No candidates -> empty cluster set. Exit 0; emit nothing.
    return 0
  fi

  # --- Step B: union-find over the similarity graph ---
  # parent[i] = i initially. Bash 3.2: parallel indexed scalars.
  local i j
  local parent_arr=""
  i=0
  while [ "$i" -lt "$n" ]; do
    if [ "$i" -eq 0 ]; then
      parent_arr="$i"
    else
      parent_arr="$parent_arr
$i"
    fi
    i=$(( i + 1 ))
  done

  # Helper: read parent[k]
  _cluster_parent_get() {
    local k="$1"
    printf '%s\n' "$parent_arr" | awk -v n="$(( k + 1 ))" 'NR==n{print; exit}'
  }
  # Helper: write parent[k] = v (rebuilds parent_arr)
  _cluster_parent_set() {
    local k="$1" v="$2"
    parent_arr="$(printf '%s\n' "$parent_arr" | awk -v n="$(( k + 1 ))" -v v="$v" 'NR==n{print v; next}{print}')"
  }
  # Find with path compression.
  _cluster_find() {
    local k="$1" p
    p="$(_cluster_parent_get "$k")"
    while [ "$p" != "$k" ]; do
      k="$p"
      p="$(_cluster_parent_get "$k")"
    done
    printf '%s\n' "$k"
  }
  # Union.
  _cluster_union() {
    local a="$1" b="$2" ra rb
    ra="$(_cluster_find "$a")"
    rb="$(_cluster_find "$b")"
    [ "$ra" = "$rb" ] && return 0
    if [ "$ra" -lt "$rb" ]; then
      _cluster_parent_set "$rb" "$ra"
    else
      _cluster_parent_set "$ra" "$rb"
    fi
  }

  # --- Step C: pairwise iteration; union when similarity >= threshold ---
  i=0
  while [ "$i" -lt "$n" ]; do
    j=$(( i + 1 ))
    local file_i
    file_i="$(printf '%s\n' "$files" | awk -v n="$(( i + 1 ))" 'NR==n{print; exit}')"
    while [ "$j" -lt "$n" ]; do
      local file_j
      file_j="$(printf '%s\n' "$files" | awk -v n="$(( j + 1 ))" 'NR==n{print; exit}')"
      local sim_line sim
      sim_line="$(pairwise_jaccard "$file_i" "$file_j" 2>/dev/null || true)"
      sim="$(printf '%s\n' "$sim_line" | sed -n 's/^similarity=//p' | head -1)"
      [ -z "$sim" ] && { j=$(( j + 1 )); continue; }
      # awk-based >= comparison; emits "1" if true, "0" otherwise.
      local ge
      ge="$(awk -v s="$sim" -v t="$threshold" 'BEGIN{ if (s+0 >= t+0) print 1; else print 0 }')"
      if [ "$ge" = "1" ]; then
        _cluster_union "$i" "$j"
      fi
      j=$(( j + 1 ))
    done
    i=$(( i + 1 ))
  done

  # --- Step D: gather clusters by root, emit deterministic output ---
  # Build a list of (root_idx, member_id) pairs, then group.
  local pairs=""
  i=0
  while [ "$i" -lt "$n" ]; do
    local r mem_id
    r="$(_cluster_find "$i")"
    mem_id="$(printf '%s\n' "$ids" | awk -v n="$(( i + 1 ))" 'NR==n{print; exit}')"
    if [ -z "$pairs" ]; then
      pairs="$r	$mem_id"
    else
      pairs="$pairs
$r	$mem_id"
    fi
    i=$(( i + 1 ))
  done

  # Sort pairs by root, then by member-id.
  local sorted_pairs
  sorted_pairs="$(printf '%s\n' "$pairs" | LC_ALL=C sort -k1,1n -k2,2)"

  # Walk sorted pairs grouped by root_idx; for each group, compute the cluster
  # id from the sorted member ids and emit <cluster-id>\t<member-id> lines.
  local current_root="" current_members=""
  printf '%s\n' "$sorted_pairs" | while IFS='	' read -r r mem; do
    [ -z "$r" ] && continue
    if [ "$r" != "$current_root" ]; then
      if [ -n "$current_root" ]; then
        # Emit prior group.
        local sorted_ids cid m
        sorted_ids="$(printf '%s\n' "$current_members" | LC_ALL=C sort | tr '\n' ',' | sed 's/,$//')"
        cid="$(cluster_id_for "$sorted_ids")"
        printf '%s\n' "$current_members" | LC_ALL=C sort | while IFS= read -r m; do
          [ -z "$m" ] && continue
          printf '%s\t%s\n' "$cid" "$m"
        done
      fi
      current_root="$r"
      current_members="$mem"
    else
      current_members="$current_members
$mem"
    fi
  done | { cat; }
  # Emit final group: subshell-locality of the while loop above means we lose
  # current_members at exit. Re-run grouping in a single awk pass for the
  # final emission to ensure determinism without subshell variable loss.
  printf '%s\n' "$sorted_pairs" | awk -F'\t' '
    { groups[$1] = (groups[$1] ? groups[$1] "\n" $2 : $2); order[++n_order] = (seen[$1] ? "" : $1); seen[$1]=1 }
    END {
      for (k=1; k<=n_order; k++) {
        r = order[k]
        if (r == "") continue
        # sort members lexicographically.
        nmem = split(groups[r], mems, "\n")
        # Bubble sort (small n, bash-3.2-mindset; awk has no built-in sort fn portably).
        for (a=1; a<nmem; a++) for (b=a+1; b<=nmem; b++) if (mems[a] > mems[b]) { t=mems[a]; mems[a]=mems[b]; mems[b]=t }
        csv = ""
        for (a=1; a<=nmem; a++) csv = csv (a==1 ? "" : ",") mems[a]
        print "__GROUP__\t" csv
        for (a=1; a<=nmem; a++) print r "\t" mems[a]
      }
    }
  ' > /tmp/_cluster_groups.$$ 2>/dev/null || true

  # Now compute cluster IDs and emit final output.
  local group_csv group_root
  while IFS='	' read -r marker payload; do
    [ -z "$marker" ] && continue
    if [ "$marker" = "__GROUP__" ]; then
      group_csv="$payload"
      group_root=""
      cid="$(cluster_id_for "$group_csv")"
    else
      printf '%s\t%s\n' "$cid" "$payload"
    fi
  done < /tmp/_cluster_groups.$$
  rm -f /tmp/_cluster_groups.$$
}
```

Make executable:

```
chmod +x scripts/knowledge/lib/cluster.sh
```

Note: this implementation uses an awk pass for final grouping to dodge the subshell-variable-loss bash 3.2 trap. The /tmp/_cluster_groups.$$ scratch file is local to the function call and removed at the end; it is not a knowledge mutation.

### Step 2: Create `scripts/verify/m020-p05-cluster-helper-contract.sh`

Path: `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/verify/m020-p05-cluster-helper-contract.sh`

Verifier asserts (1) the helper sources cleanly, (2) `cluster_id_for` produces deterministic AD-3-shaped IDs, (3) `cluster_compute` emits the expected schema (TAB-separated `<cluster-id>\t<member-id>` lines).

```bash
#!/usr/bin/env bash
# m020-p05-cluster-helper-contract.sh — assert cluster.sh exposes
# cluster_compute and cluster_id_for with the AD-3 + FR-5 contracts.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/scripts/knowledge/lib/cluster.sh"

if [ ! -f "$LIB" ]; then
  echo "FAIL: $LIB does not exist"
  exit 1
fi

# Source the helper in a fresh subshell to detect non-clean source.
out_src="$(bash -c ". '$LIB' && type cluster_compute && type cluster_id_for" 2>&1)"
rc_src=$?
if [ "$rc_src" -ne 0 ]; then
  echo "FAIL: sourcing cluster.sh exited $rc_src. Output: $out_src"
  exit 1
fi
case "$out_src" in
  *"cluster_compute is a function"*) ;;
  *) echo "FAIL: cluster_compute is not exposed as a function. Got: $out_src"; exit 1 ;;
esac
case "$out_src" in
  *"cluster_id_for is a function"*) ;;
  *) echo "FAIL: cluster_id_for is not exposed as a function. Got: $out_src"; exit 1 ;;
esac

# AD-3 ID shape: cluster_id_for emits C<8-hex>.
id1="$(bash -c ". '$LIB' && cluster_id_for 'MEM900,MEM901,MEM902'")"
case "$id1" in
  C[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
  *) echo "FAIL: cluster_id_for output '$id1' does not match C<8-hex> shape"; exit 1 ;;
esac

# Determinism: same input twice -> same output.
id2="$(bash -c ". '$LIB' && cluster_id_for 'MEM900,MEM901,MEM902'")"
if [ "$id1" != "$id2" ]; then
  echo "FAIL: cluster_id_for non-deterministic ('$id1' vs '$id2')"
  exit 1
fi

# Different input -> different output.
id3="$(bash -c ". '$LIB' && cluster_id_for 'MEM910,MEM911'")"
if [ "$id1" = "$id3" ]; then
  echo "FAIL: cluster_id_for collision on distinct inputs ('$id1')"
  exit 1
fi

# cluster_compute on an empty knowledge-root emits no output and exits 0.
empty_dir="$(mktemp -d)"
trap 'rm -rf "$empty_dir"' EXIT
out_empty="$(bash -c ". '$LIB' && cluster_compute '$empty_dir' 0.5" 2>&1)"
rc_empty=$?
if [ "$rc_empty" -ne 0 ]; then
  echo "FAIL: cluster_compute on empty root exited $rc_empty. Output: $out_empty"
  exit 1
fi
if [ -n "$out_empty" ]; then
  echo "FAIL: cluster_compute on empty root emitted output: '$out_empty'"
  exit 1
fi

# cluster_compute on a single-candidate fixture emits one line.
mkdir -p "$empty_dir/patterns"
cat >"$empty_dir/patterns/MEM800.md" <<'EOF'
---
id: MEM800
status: candidate
topic: alpha
tags: [alpha, beta]
---

# MEM800: single candidate fixture
A short body for token extraction.
EOF
out_one="$(bash -c ". '$LIB' && cluster_compute '$empty_dir' 0.5" 2>&1)"
rc_one=$?
if [ "$rc_one" -ne 0 ]; then
  echo "FAIL: cluster_compute on single-candidate fixture exited $rc_one. Output: $out_one"
  exit 1
fi
line_count="$(printf '%s\n' "$out_one" | grep -c '^C[0-9a-f]\{8\}	MEM800$' || true)"
if [ "$line_count" -ne 1 ]; then
  echo "FAIL: cluster_compute on single-candidate fixture did not emit exactly 1 line matching '<cluster-id>\\tMEM800'. Got:"
  printf '%s\n' "$out_one"
  exit 1
fi

echo "PASS: cluster.sh helper contract (function exposure + AD-3 ID shape + determinism + empty + singleton)"
exit 0
```

`chmod +x scripts/verify/m020-p05-cluster-helper-contract.sh`.

### Step 3: Create `scripts/verify/m020-p05-cluster-determinism.sh`

Path: `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/verify/m020-p05-cluster-determinism.sh`

```bash
#!/usr/bin/env bash
# m020-p05-cluster-determinism.sh — assert cluster_compute output is byte-
# identical across two runs against the same fixture.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/scripts/knowledge/lib/cluster.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/patterns"

# Three candidates; not all expected to cluster; exact clustering
# depends on the feature vector but determinism is invariant.
for trip in "MEM800:alpha:body about alpha and beta" \
            "MEM801:alpha:body about alpha and gamma" \
            "MEM802:delta:body about delta and epsilon"; do
  id="${trip%%:*}"; rest="${trip#*:}"
  topic="${rest%%:*}"; body="${rest#*:}"
  cat >"$tmpdir/patterns/${id}.md" <<EOF
---
id: ${id}
status: candidate
topic: ${topic}
tags: [${topic}]
---

# ${id}: determinism fixture
${body}
EOF
done

run1="$(bash -c ". '$LIB' && cluster_compute '$tmpdir' 0.1" 2>&1)"
rc1=$?
run2="$(bash -c ". '$LIB' && cluster_compute '$tmpdir' 0.1" 2>&1)"
rc2=$?

if [ "$rc1" -ne 0 ] || [ "$rc2" -ne 0 ]; then
  echo "FAIL: cluster_compute exited non-zero ($rc1, $rc2). Outputs:"
  printf 'run1:\n%s\nrun2:\n%s\n' "$run1" "$run2"
  exit 1
fi

if [ "$run1" != "$run2" ]; then
  echo "FAIL: cluster_compute output is not deterministic across runs"
  echo "----- run1 -----"; printf '%s\n' "$run1"
  echo "----- run2 -----"; printf '%s\n' "$run2"
  exit 1
fi

echo "PASS: cluster_compute is deterministic (run1 == run2 byte-for-byte)"
exit 0
```

`chmod +x scripts/verify/m020-p05-cluster-determinism.sh`.

### Step 4: Create `scripts/verify/m020-p05-cluster-singleton-coverage.sh`

Path: `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/verify/m020-p05-cluster-singleton-coverage.sh`

Asserts ten-entry fixture (four near-duplicates above threshold by intentionally-overlapping topic+tags+body, plus six distinct entries) emits seven distinct cluster IDs covering all ten members exactly once. Uses an artificially-low threshold (0.1) plus topic-stuffed near-duplicates to make the four-cluster outcome robust.

```bash
#!/usr/bin/env bash
# m020-p05-cluster-singleton-coverage.sh — assert cluster_compute against a
# 10-entry fixture (4 near-duplicates + 6 distinct) yields 7 distinct cluster
# IDs covering all 10 entries exactly once.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/scripts/knowledge/lib/cluster.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/patterns"

# 4 near-duplicates: identical topic + tags + heavy body overlap.
for id in MEM900 MEM901 MEM902 MEM903; do
  cat >"$tmpdir/patterns/${id}.md" <<EOF
---
id: ${id}
status: candidate
topic: shared-cluster-alpha
tags: [shared, cluster, alpha, beta, gamma]
relates_to: [MEM900, MEM901, MEM902, MEM903]
source_unit: M999/P01
---

# ${id}: near-duplicate fixture
shared body cluster alpha beta gamma delta epsilon zeta eta theta iota kappa
lambda mu nu xi omicron pi rho sigma tau upsilon phi chi psi omega
EOF
done

# 6 distinct entries: each with a unique topic, unique tags, unique body.
i=0
for tag in distinct-uniq-1 distinct-uniq-2 distinct-uniq-3 distinct-uniq-4 distinct-uniq-5 distinct-uniq-6; do
  i=$(( i + 1 ))
  id_num=$(( 909 + i ))
  cat >"$tmpdir/patterns/MEM${id_num}.md" <<EOF
---
id: MEM${id_num}
status: candidate
topic: ${tag}
tags: [${tag}]
relates_to: []
source_unit: M999/P${id_num}
---

# MEM${id_num}: distinct fixture
unique body for ${tag} distinct word${id_num} another${id_num}
EOF
done

# Threshold deliberately low (0.1) so the 4-near-duplicate cluster forms
# reliably regardless of exact extended-vector tuning.
out="$(bash -c ". '$LIB' && cluster_compute '$tmpdir' 0.1" 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL: cluster_compute exited $rc. Output: $out"
  exit 1
fi

# Total member lines == 10.
total_lines="$(printf '%s\n' "$out" | grep -c '^C[0-9a-f]\{8\}	MEM' || true)"
if [ "$total_lines" -ne 10 ]; then
  echo "FAIL: expected 10 member lines, got $total_lines. Output:"
  printf '%s\n' "$out"
  exit 1
fi

# Distinct cluster IDs. With an aggressively-stuffed near-duplicate fixture
# at threshold 0.1, the expected outcome is 7 (one 4-member + 6 singletons),
# but if the implementation is more conservative (lower vector overlap due
# to first-paragraph cap pre-T02), accept 7..10. T04 narrows this to == 7
# against the FULL extended vector after T02 ships.
distinct_clusters="$(printf '%s\n' "$out" | awk -F'\t' '{print $1}' | LC_ALL=C sort -u | grep -c '^C[0-9a-f]\{8\}$' || true)"
if [ "$distinct_clusters" -lt 7 ] || [ "$distinct_clusters" -gt 10 ]; then
  echo "FAIL: expected 7..10 distinct cluster IDs, got $distinct_clusters. Output:"
  printf '%s\n' "$out"
  exit 1
fi

# Each member appears exactly once.
dup_count="$(printf '%s\n' "$out" | awk -F'\t' '{print $2}' | LC_ALL=C sort | uniq -d | wc -l | awk '{print $1}')"
if [ "$dup_count" -ne 0 ]; then
  echo "FAIL: $dup_count members appear more than once. Output:"
  printf '%s\n' "$out"
  exit 1
fi

echo "PASS: cluster_compute singleton coverage (10 members, $distinct_clusters clusters, no duplicates)"
exit 0
```

`chmod +x scripts/verify/m020-p05-cluster-singleton-coverage.sh`.

## Must-Haves

- `scripts/knowledge/lib/cluster.sh` exists, is sourceable, exposes `cluster_compute` and `cluster_id_for` functions.
- `cluster_id_for <sorted-csv>` emits `C<8-hex>` matching `^C[0-9a-f]{8}$`; deterministic; collision-resistant (different inputs yield different IDs at the contract test scale).
- `cluster_compute <root> <threshold>` walks `MEM*.md` under `<root>`, filters to `status: candidate`, computes pairwise Jaccard via `pairwise_jaccard`, builds the similarity graph, emits one TAB-separated `<cluster-id>\t<member-id>` line per (cluster, member) pair on stdout, sorted deterministically.
- `cluster_compute` is byte-deterministic across runs against the same fixture.
- `cluster_compute` covers every candidate exactly once (no orphans, no duplicates) including singletons.
- Bash 3.2: parallel newline-joined scalars; no `declare -A`; no `mapfile`; no process substitution; no AD-19-forbidden shapes.
- Pure read: no writes to `knowledge/**` or `.orchestrator/**` (the /tmp/_cluster_groups.$$ scratch file does not count — local to the function call, cleaned up).
- The three T01 verifier scripts exist, are executable, and exit 0 with `PASS:` lines.

## Verification

```
bash scripts/verify/m020-p05-cluster-helper-contract.sh
bash scripts/verify/m020-p05-cluster-determinism.sh
bash scripts/verify/m020-p05-cluster-singleton-coverage.sh
```

Each must print a `PASS:` line and exit 0.

## Inputs

### From Previous Tasks

None — T01 has no upstream tasks within this phase.

### From Disk (Pre-existing)

- `scripts/knowledge/lib/jaccard.sh` (P01)
  - Key API: `pairwise_jaccard <file-a> <file-b>` echoes `similarity=N.NNNN` to stdout. Pure function; reads only the two argument files.
  - cluster.sh sources jaccard.sh and calls `pairwise_jaccard` directly inside the iteration loop.
- `scripts/knowledge/lib/frontmatter.sh` (P01)
  - Key API: `fm_read_status <file>` returns the `status:` field value or `graduated` per FR-10 default. cluster.sh inlines an awk-based status reader (rather than sourcing fm_read_status) to dodge bash-3.2 nested-source quirks AND to keep the candidate filter visible to verifier readers without hopping helpers.
- `scripts/knowledge/lib/index-utils.sh` (P01) — provides `get_project_root` honoring `PROJECT_ROOT` env override. T01 verifiers set `PROJECT_ROOT` to the tempdir for fixture isolation.
- `scripts/knowledge/lib/detail-utils.sh` (P01) — adjacent helpers; sourced by jaccard.sh.

## Constraints

- **AD-19 / MEM001**: every `Check:` and verification command in this plan is a single-script-file invocation. cluster.sh internals use awk + sort + temp files but those live inside the script body, not on Check lines.
- **Bash 3.2**: no associative arrays, no `mapfile`, no process substitution. Parent array uses parallel newline-joined scalars; grouping uses an awk pass with array indexing (awk has its own associative arrays which are fine — bash 3.2 constraint applies to bash code only).
- **CON-1 / FR-8 (read-only-during-dispatch)**: cluster.sh writes only to `/tmp/_cluster_groups.$$` scratch (cleaned at function exit) and stdout. Never to `knowledge/**` or `.orchestrator/**`.
- **AD-3 (cluster ID format)**: `cluster_id_for` MUST emit `C<8-hex-of-sha1(sorted-csv)>` exactly. Verified by the helper-contract verifier with the regex `^C[0-9a-f]{8}$`.
- **CON-5 (feature vector)**: cluster.sh does NOT define the feature vector — it consumes whatever `pairwise_jaccard` exposes. After T02 of this phase ships the extended vector, cluster.sh's behavior changes accordingly without any code change in cluster.sh itself. This is the contract decoupling that lets T01 and T02 land in either order.
- **Principle XIV (No Speculative Complexity)**: union-find with path compression is the standard simple algorithm. No semantic-clustering escalation; no agglomerative hierarchical clustering; no DBSCAN. Connected-components-above-threshold matches FR-5's single-pass shape.
- **Determinism**: same input -> same stdout, byte-equivalent. Sort orders are explicit (`LC_ALL=C sort`), no random tie-breakers, member ordering inside a cluster is lexicographic.

## Expected Output

After this task:

1. `scripts/knowledge/lib/cluster.sh` is created (>= 120 lines), executable, and the help comment documents `cluster_compute` + `cluster_id_for`.
2. All three T01 verifiers exist under `scripts/verify/`, are executable, and pass.
3. `git status knowledge/` is clean (T01 verifiers use tempdirs with `PROJECT_ROOT` overrides; live tree never touched).
4. `git status .orchestrator/execution-log.jsonl` is unchanged by T01 verifiers (T01 emits no JSONL records — that is T03's responsibility).

**Done when**: all three T01 verifiers print `PASS:` and exit 0; `git status knowledge/` and `git status .orchestrator/execution-log.jsonl` are unchanged by T01 work.

## State Context

- **Current State**: executing
- **Milestone**: M020
- **Phase**: P05
- **Task**: T01-cluster-helper
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **AD-19 / MEM001**: every `Check:` and verification command in this plan is a single-script-file invocation. cluster.sh internals use awk + sort + temp files but those live inside the script body, not on Check lines.
- **Bash 3.2**: no associative arrays, no `mapfile`, no process substitution. Parent array uses parallel newline-joined scalars; grouping uses an awk pass with array indexing (awk has its own associative arrays which are fine — bash 3.2 constraint applies to bash code only).
- **CON-1 / FR-8 (read-only-during-dispatch)**: cluster.sh writes only to `/tmp/_cluster_groups.$$` scratch (cleaned at function exit) and stdout. Never to `knowledge/**` or `.orchestrator/**`.
- **AD-3 (cluster ID format)**: `cluster_id_for` MUST emit `C<8-hex-of-sha1(sorted-csv)>` exactly. Verified by the helper-contract verifier with the regex `^C[0-9a-f]{8}$`.
- **CON-5 (feature vector)**: cluster.sh does NOT define the feature vector — it consumes whatever `pairwise_jaccard` exposes. After T02 of this phase ships the extended vector, cluster.sh's behavior changes accordingly without any code change in cluster.sh itself. This is the contract decoupling that lets T01 and T02 land in either order.
- **Principle XIV (No Speculative Complexity)**: union-find with path compression is the standard simple algorithm. No semantic-clustering escalation; no agglomerative hierarchical clustering; no DBSCAN. Connected-components-above-threshold matches FR-5's single-pass shape.
- **Determinism**: same input -> same stdout, byte-equivalent. Sort orders are explicit (`LC_ALL=C sort`), no random tie-breakers, member ordering inside a cluster is lexicographic.

### Acceptance Criteria

- `scripts/knowledge/lib/cluster.sh` exists, is sourceable, exposes `cluster_compute` and `cluster_id_for` functions.
- `cluster_id_for <sorted-csv>` emits `C<8-hex>` matching `^C[0-9a-f]{8}$`; deterministic; collision-resistant (different inputs yield different IDs at the contract test scale).
- `cluster_compute <root> <threshold>` walks `MEM*.md` under `<root>`, filters to `status: candidate`, computes pairwise Jaccard via `pairwise_jaccard`, builds the similarity graph, emits one TAB-separated `<cluster-id>\t<member-id>` line per (cluster, member) pair on stdout, sorted deterministically.
- `cluster_compute` is byte-deterministic across runs against the same fixture.
- `cluster_compute` covers every candidate exactly once (no orphans, no duplicates) including singletons.
- Bash 3.2: parallel newline-joined scalars; no `declare -A`; no `mapfile`; no process substitution; no AD-19-forbidden shapes.
- Pure read: no writes to `knowledge/**` or `.orchestrator/**` (the /tmp/_cluster_groups.$$ scratch file does not count — local to the function call, cleaned up).
- The three T01 verifier scripts exist, are executable, and exit 0 with `PASS:` lines.

### Files To Touch

- `scripts/knowledge/lib/cluster.sh` (create)
- `scripts/knowledge/lib/jaccard.sh` (modify — extend feature vector with `relates_to[]` + `source_unit` + capped full-body tokens; preserve `pairwise_jaccard` contract: same signature, broader content)
- `scripts/knowledge/consolidate-artifacts.sh` (modify — add `--cluster` flag; preserve legacy two-positional-arguments shape byte-equivalent per CON-4)
- `tests/test-jaccard-clustering.sh` (create)
- [`.orchestrator/milestones/M020/phases/P05/jaccard-validation-report.md`](../../../../../milestones/M020/phases/P05/jaccard-validation-report.md) (create — regenerated against the live tree using the extended vector)
- `scripts/verify/m020-p05-cluster-helper-contract.sh` (create)
- `scripts/verify/m020-p05-cluster-determinism.sh` (create)
- `scripts/verify/m020-p05-cluster-singleton-coverage.sh` (create)
- `scripts/verify/m020-p05-feature-vector-extension.sh` (create)
- `scripts/verify/m020-p05-consolidate-cluster-emit.sh` (create)
- `scripts/verify/m020-p05-consolidate-conflict-diagnostic.sh` (create)
- `scripts/verify/m020-p05-consolidate-jsonl-emit.sh` (create)
- `scripts/verify/m020-p05-consolidate-legacy-shape-preserved.sh` (create)

No files under `knowledge/**` are touched by P05 task code (clustering is read-only per FR-8 / CON-1 — only `graduate.sh` mutates entries, and graduate.sh itself is not invoked by consolidate-artifacts.sh; the round-trip is operator-mediated). The verifier scripts use tempdirs with `PROJECT_ROOT` overrides so the live tree is never touched. JSONL emission writes to `${ORCH_ROOT}/execution-log.jsonl` at runtime, but verifier tests use isolated `ORCH_ROOT` env-var overrides so the live execution log is never touched during verification.

No files under `.orchestrator/memory/` or [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) are touched (no schema evolution in P05 — `relates_to[]` and `source_unit` are pre-existing fields not authored by P05; only their tokenization changes inside lib/jaccard.sh).

T02 writes a new [`.orchestrator/milestones/M020/phases/P05/jaccard-validation-report.md`](../../../../../milestones/M020/phases/P05/jaccard-validation-report.md) derived from `lib/jaccard.sh validate knowledge/`; this is the canonical P05 calibration artifact and is reproducible from source data on every run (per the P01/T05 pattern). It is the only file P05 writes outside `scripts/`, `tests/`, and the P05 phase verifier set.

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