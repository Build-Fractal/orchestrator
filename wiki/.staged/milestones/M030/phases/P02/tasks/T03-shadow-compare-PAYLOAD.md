---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T03-shadow-compare (Phase P02, Milestone M030)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~500 | required |
| Upstream Context | 981-1048 | ~1900 | required |
| Task Plan | 1050-1323 | ~7200 | required |
| State Context | 1325-1331 | ~100 | required |
| First-Turn Completeness | 1333-1385 | ~1200 | required |
| **Total** | | **~21700** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 667
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
hit_count: 667
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
hit_count: 667
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
hit_count: 667
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
hit_count: 589
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
hit_count: 589
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
hit_count: 589
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
hit_count: 667
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
hit_count: 589
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
hit_count: 589
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
hit_count: 589
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
hit_count: 667
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
hit_count: 667
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
hit_count: 667
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
hit_count: 589
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
hit_count: 589
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
hit_count: 589
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
hit_count: 667
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
hit_count: 589
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
hit_count: 589
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
hit_count: 667
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
hit_count: 667
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
hit_count: 589
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
hit_count: 589
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
hit_count: 589
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
hit_count: 244
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
hit_count: 244
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
hit_count: 244
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
hit_count: 243
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
hit_count: 243
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
hit_count: 233
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
     slug-bearing filenames (p02-*) so install-clobber risk is contained.
     Verifier authorship is co-scheduled with the artifact it gates, in
     the SAME task, per Plan-Time Discipline rule 2 (verifier-availability
     cross-check). No cross-task verifier dependencies. T01 deliberately
     ships the SC-11 byte-equality verifier + golden fixture BEFORE T02
     touches dispatch-interface.sh — this is the same discipline P01 used
     for the D-A4 timeline graduation: the additive-schema gate exists
     and gates the diff at the moment dispatch-interface.sh is amended. -->

### Truths

- A pre-M030 `dispatch_usage` JSONL fixture (`tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl`) exists at version-control with at minimum 5 records spanning happy-path, pricing-warning, and cost-null degradation shapes. The fixture's first-commit timestamp predates `dispatch-interface.sh`'s P02 amendment commit (mechanical proxy for additive-only-schema enforcement). (CON-2/FR-19/SC-11 foundation.)
  - Check: `bash tools/verify/p02-fixture-shape.sh`

- SC-11 byte-equality holds: when `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` is round-tripped through `scripts/dispatch/dispatch-interface.sh`'s emit path under `M030_SHADOW_MODE=0` (or unset), the emitter output for an equivalent fixture invocation is byte-identical to the recorded fixture line for the same `(unitId, backend, payload_bytes, model)` tuple. The verifier stages a fixture invocation, captures the emitter's stdout/log line, and `diff`s against the corresponding fixture record byte-for-byte — empty diff is the pass condition. New fields (`model_routed`, `model_used`, `partial_flip_active`, `withheld_classes`) MUST NOT appear in the output when shadow mode is off; when shadow mode is on, they appear ONLY as appended fields after the existing field set. (CON-2/FR-19/SC-11.)
  - Check: `bash tools/verify/p02-additive-schema.sh`

<dispatch-volatile>

## Upstream Context


### P01 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M030"
milestone: "M030"
provides:
  - "tools/verify/p01-d-a4-timeline.sh,scripts/dispatch/classify-task.sh,tools/verify/p01-classifier-determinism.sh,tools/verify/p01-classifier-perf-and-network.sh,tools/verify/p01-classifier-ground-truth.sh,templates/model-routing.yml SSOT (routing+resolution+cost_rates) + references/model-routing.md operator docs (5 sections,concrete stability-metric numerics 0.10/N=20/50) + tools/verify/p01-routing-table-shape.sh + tools/verify/p01-model-routing-doc-shape.sh,scripts/diagnostics/run-doctor.sh --config-check extension wired to tools/verify/p01-routing-table-shape.sh (file:line emission per FR-17 + SC-9); tools/verify/p01-doctor-config-check.sh exercises both well-formed-pass and malformed-fail paths; tools/verify/p01-phase-suite.sh straight-line aggregator over all 7 P01 sub-gates"
requires:
  - "P00"
affects:
  - "P02"
key_files:
  - "tools/verify/p01-d-a4-timeline.sh,scripts/dispatch/classify-task.sh,tools/verify/p01-classifier-determinism.sh,tools/verify/p01-classifier-perf-and-network.sh,tools/verify/p01-classifier-ground-truth.sh,templates/model-routing.yml,references/model-routing.md,tools/verify/p01-routing-table-shape.sh,tools/verify/p01-model-routing-doc-shape.sh,scripts/diagnostics/run-doctor.sh,tools/verify/p01-doctor-config-check.sh,tools/verify/p01-phase-suite.sh,CLAUDE.md,AGENTS.md"
key_decisions:
  - "D-A4 timeline-graduation verifier authored before classify-task.sh ships -- automatic mode swap on T02 commit,file-count signal scoped to deliverable sections; body-line cap as secondary mech-vs-std distinguisher; two-tier novel lexicon with verdict exclusion; bash -c <cmd> accepted as verifier-bash invocation,CON-3-closure-invariant-model-IDs-only-in-resolution; D-A6-cost_rates-SSOT; classifier-confidence-stability-metric-pinned-0.10-N=20-50-dispatches; CC-only-launch-other-runtimes-inherit,FR-17-file-line-diagnostic-emission-via-grep-n-lookup-during-closure-walk; doctor-config-check-additive-not-replacement-existing-doctor-pipeline-preserved; phase-suite-straight-line-no-loops-AD-19-shape-discipline-mirrored-from-P00"
patterns_established:
  - "graduation-verifier-pattern (two-mode pre/post-graduation gate keyed off filesystem state); single-pipeline command-substitution exemption under AD-19,two-tier-lexicon-for-symbolic-classifiers; body-line-proxy-for-narrative-vs-transcription; comment-stripped-grep-for-self-referential-gates; bash-3.2-only-classifier-no-jq-no-network,declarative-routing-table-with-symbolic-tier-indirection; awk-section-walker-for-YAML-closure-check-no-jq-dependency; doc-shape-verifier-grep-asserts-concrete-numerics-as-load-bearing-downstream-contract,config-check-flag-as-thin-wrapper-around-shape-verifier-with-file-line-passthrough; verifier-stages-malformed-fixture-in-tmp-with-trap-cleanup; phase-suite-aggregator-pattern-extends-from-5-to-7-gates-without-shape-change"
drill_down_paths:
  - "[.orchestrator/milestones/M030/phases/P01/tasks/T01-SUMMARY.md](../../../../../milestones/M030/phases/P01/tasks/T01-SUMMARY.md), [.orchestrator/milestones/M030/phases/P01/tasks/T02-SUMMARY.md](../../../../../milestones/M030/phases/P01/tasks/T02-SUMMARY.md), [.orchestrator/milestones/M030/phases/P01/tasks/T03-SUMMARY.md](../../../../../milestones/M030/phases/P01/tasks/T03-SUMMARY.md), [.orchestrator/milestones/M030/phases/P01/tasks/T04-SUMMARY.md](../../../../../milestones/M030/phases/P01/tasks/T04-SUMMARY.md)"
duration: "240m"
verification_result: "pass"
completed_at: "2026-04-30T13:19:42Z"
observability_surfaces:
  - "none"
---

## What was built

P01 ships the M030 classifier surface and routing-table SSOT — the load-bearing infrastructure for adaptive model selection. Four tasks, strict linear chain T01 → T02 → T03 → T04, all green:

- **T01** authored `tools/verify/p01-d-a4-timeline.sh` BEFORE `classify-task.sh` existed, satisfying the D-A4 / SC-10 mechanical-independence constraint by construction. The verifier auto-graduates from Mode A (absence-check) to Mode B (commit-ordering check) the moment T02 lands the classifier.
- **T02** delivered `scripts/dispatch/classify-task.sh` — Bash 3.2-safe, zero network calls, 50ms wall-clock, 90% (36/40) ground-truth agreement against the P00 fixture corpus (mechanical 19/20, standard 12/15, novel 5/5). Well above the 85% gate. FR-2 inputs (e) phase-position and (f) anomaly-JSONL signal are stubbed per plan; (a)-(d) reach 90% on their own.
- **T03** shipped `templates/model-routing.yml` (routing + resolution + cost_rates SSOT) and `references/model-routing.md` (operator docs). Classifier-confidence stability-metric numerics pinned to concrete values: variance threshold 0.10, rolling window N=20, per-class coverage floor 50 dispatches. CON-3 closure honored — model IDs appear ONLY in `resolution:`.
- **T04** extended `scripts/diagnostics/run-doctor.sh` with `--config-check` (file:line emission per FR-17 / SC-9) and authored `tools/verify/p01-phase-suite.sh` — straight-line aggregator over all 7 P01 sub-gates, modeled on `p00-phase-suite.sh`.

## Verification

Phase-suite green: `pass=7 fail=0` across d-a4-timeline (Mode B), classifier-determinism (4/0), classifier-perf-and-network (2/0), classifier-ground-truth (1/0 @ 90%), routing-table-shape (8/0), doctor-config-check (4/0), model-routing-doc-shape (8/0). Tier-1 must-haves: 8 truths + 34 artifacts + 8 key-links all PASS. Tier-3 behavioral: FR-1, FR-2 (with documented stubs), FR-3, FR-17, D-A1, D-A4, D-A6, CON-3 all satisfied.

## Patterns established

- **Graduation-verifier pattern**: two-mode pre/post-graduation gate keyed off filesystem state — Mode A asserts artifact absence; Mode B asserts git-commit ordering once the artifact lands. Reusable for any "fixture must precede consumer" constraint.
- **Two-tier lexicon for symbolic classifiers**: body-line count as narrative-vs-transcription proxy; verdict-exclusion lexicon for novel-class detection.
- **Awk section-walker for YAML closure-check**: no `jq` dependency; portable across runtimes.
- **Doc-shape verifier asserts concrete numerics** as load-bearing downstream contract — pins variance/window/coverage values into the doc itself so P02 cannot drift.
- **Phase-suite aggregator extension**: P00's 5-gate suite extends cleanly to P01's 7 gates with no shape change — straight-line bash, no loops, AD-19 compliant.

## Cross-cutting concerns honored

- **CON-3 (symbolic-tier closure)**: classifier emits symbolic class names only; routing table maps character → tier symbolically; concrete model IDs confined to `resolution:` block. Verified by `p01-routing-table-shape.sh`.
- **D-A4 / SC-10 (pre-implementation independence)**: P00 fixture corpus committed at ts=1777523592; classify-task.sh committed at ts=1777550632. Mode B graduation verifier asserts ordering on every run.
- **CC-only launch posture**: routing-table resolution table has Codex CLI / Cursor entries set to `inherit` — no per-runtime model-ID branching beyond CC.

## Hand-off to P02

P02 will consume P01's deliverables: classifier interface (`classify-task.sh`), routing table (`templates/model-routing.yml`), pinned stability-metric numerics (0.10 / N=20 / 50). The P02 plan-phase MUST grep for hardcoded model IDs in its diff (CON-3 enforcement) and verify SC-11 byte-equality on pre-M030 fixtures (additive-only JSONL schema).

## Open notes for downstream

- FR-2 inputs (e) phase-position and (f) anomaly-JSONL stubbed in classify-task.sh; if future tuning needs to push past 90%, wire those inputs.
- 4 ground-truth disagreements (M004/P02/T05, M013/P02/T01, M019/P01/T01, M026/P03/T02) sit near body-line / file-count threshold boundaries; documented in T02-SUMMARY.md.
- `roadmap_sync=SYNC:OK`; no downstream phases were invalidated by P01 close.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M030"
name: "shadow-compare.sh + 4-verdict + partial-flip enum + SC-3a + stability-metric traceability"
depends_on: ["T02"]
---

## Prerequisites

- `scripts/dispatch/dispatch-interface.sh` is amended with the shadow hook + 4 additive fields, gated by `M030_SHADOW_MODE=1` AND `CLAUDECODE=1` (T02 close).
- `tools/verify/p02-shadow-emit.sh`, `tools/verify/p02-con3-closure.sh`, `tools/verify/p02-append-only.sh` all exit 0 (T02 close).
- `tools/verify/p02-additive-schema.sh` re-passes against the amended `dispatch-interface.sh` (T02 close — shadow-off byte-equality preserved).
- `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` + `tests/fixtures/m030-p02/round-trip-stage/` exist (T01 close).
- `scripts/dispatch/classify-task.sh` exists and emits `character=` + `confidence=` (P01/T02 close).
- `templates/model-routing.yml` exists with `routing:` + `resolution:` + `cost_rates:` sections (P01/T03 close).
- `references/model-routing.md` exists with `## Classifier-Confidence Stability Metric` section pinning numerics 0.10 / N=20 / 50 (P01/T03 close).

Plan-time prerequisite-existence verification: every path above is asserted by T01 + T02's closure conditions; P01 deliverables are present per P01-SUMMARY.md `key_files:`. The pinned numerics 0.10 / 20 / 50 in `references/model-routing.md` were located at lines 153-170 during plan-authoring (`grep -n` returned "Rolling per-class confidence-score variance threshold = 0.10" at line 153, `N=20` at line 157, "Minimum class-coverage count = 50" at line 163).

## Description

T03 ships the `shadow-compare.sh` aggregator and four co-scheduled verifiers. The script reads JSONL records produced by T02's amended `dispatch-interface.sh` (or by hand-authored fixtures), tabulates per-class evidence + confidence-variance, and emits a single 4-verdict `flip_recommendation=` line per the D-A1/D-A3 logic.

### Five deliverables

1. **`scripts/diagnostics/shadow-compare.sh`** — the aggregator. Reads JSONL corpus from default `.orchestrator/milestones/*/execution-log.jsonl` glob (or `--corpus <path>` override). Per class (mechanical/standard/novel): tabulates dispatch count, computes rolling variance of `confidence=` values over the last N=20 records (where `confidence=` enum {high, medium, low} is mapped to numeric {1.0, 0.5, 0.0} for variance computation), and reports stability verdict per the pinned thresholds.

2. **`tests/fixtures/m030-p02/shadow-corpus-ready.jsonl`** — fixture corpus with all 3 classes meeting the 50-count + variance ≤ 0.10 thresholds. Drives the `flip_recommendation=ready` verdict.

3. **`tests/fixtures/m030-p02/shadow-corpus-partially-ready.jsonl`** — fixture corpus with mechanical + standard meeting thresholds; novel under-threshold (0 records) AND novel's routing-table default is `smart` (per `templates/model-routing.yml` shipped). Drives the `flip_recommendation=partially_ready` + `withheld_classes=novel` enumeration.

4. **`tests/fixtures/m030-p02/shadow-corpus-evidence-insufficient.jsonl`** — empty file. Drives the `flip_recommendation=evidence_insufficient` verdict (corpus has 0 dispatches per FR-8 threshold definition).

5. **`tests/fixtures/m030-p02/shadow-corpus-block.jsonl`** — fixture corpus where ≥1 class has dispatches but ALL classes are below threshold (or where 1 of 3 is over threshold but the partial-flip safety constraint fails — under-threshold class's routing default is NOT `smart`). Drives the `flip_recommendation=block` verdict. (For the shipped routing table, novel's default IS `smart` and standard's default is `balanced` — so the simplest `block` fixture has all classes <50 records or all classes with variance > 0.10.)

6. **`tests/fixtures/m030-p02/sc3a-roundtrip-corpus.jsonl`** — 6 hand-authored shadow records, each with a `unitId` that resolves to an existing PLAN.md in `.orchestrator/milestones/`. The `model_routed` value in each record is the routing-table-resolved tier matching the classifier's output for the referenced plan. Drives `p02-sc3a-roundtrip.sh` round-trip verification.

### shadow-compare.sh behavior contract (FR-8 + D-A1 + D-A3)

Inputs:
- `--corpus <path>` flag — if provided, read JSONL records from `<path>` instead of default glob.
- Default corpus: every `.orchestrator/milestones/M*/execution-log.jsonl` file the user has on disk; concat them into a single stream (cat-into-tmp-file pattern).

Per-class processing:
- For each class `c ∈ {mechanical, standard, novel}`:
  - Count records where `"model_routed":"<tier(c)>"` AND class signal can be reverse-extracted. (Implementation detail: T03 records the `character` symbolic value in the JSONL alongside `model_routed` — but T02 emits only `model_routed` as the symbolic tier. Reverse-mapping `model_routed → character` requires reading `templates/model-routing.yml routing:` and inverting the mapping. Awk inversion: for class `c`, the matching tier is `routing[c][claude-code]`; record matches class `c` iff its `model_routed` equals that tier.)
  - For each matching record, extract `confidence=` value if present (T02 currently emits `model_routed` + `model_used` + `partial_flip_active` + `withheld_classes`; T03's `shadow-compare.sh` may need to additionally read `confidence` from records that capture it — OR fold the variance-stability check into `model_routed` consistency. **Simplification**: since T02 records `model_routed` directly, and the stability metric is "rolling variance of confidence-score values," the practical approach is for T02 to ALSO emit `classifier_confidence` as an additive field. **Plan amendment for T03**: extend `shadow-compare.sh` to read `classifier_confidence` from the JSONL record. **Implementation detail for T03 itself**: when authoring the script, document that the classifier-confidence field is expected at the canonical key name `classifier_confidence`. The fixture corpora T03 authors include this field on every record. T03 does NOT amend `dispatch-interface.sh` — that field will be appended by P03 when it resumes the shadow-emit work, OR T03 amends T02's emitter via a small follow-up. **Decision**: T03 authors a one-line amendment to `dispatch-interface.sh` adding `classifier_confidence` to the shadow-on `printf` template alongside the existing four shadow fields. This keeps the contract end-to-end in P02 rather than punting to P03.)

  - Compute the last-20-records rolling variance of confidence values mapped to {high=1.0, medium=0.5, low=0.0}. Variance formula: mean = sum/n; var = sum((x_i - mean)^2)/n. Use awk for the math (no python, no jq, no bc).
  - Class is "stable" iff count >= 50 AND latest-window variance < 0.10.

Verdict logic:
- All 3 classes stable → `flip_recommendation=ready`.
- Total corpus count == 0 → `flip_recommendation=evidence_insufficient`.
- ≥2 classes stable AND every under-threshold class's routing-table default is `smart` (per `templates/model-routing.yml routing.<class>.claude-code`) → `flip_recommendation=partially_ready`. Emit `withheld_classes=<comma-separated-list-of-under-threshold-classes>`.
- Otherwise → `flip_recommendation=block`.

Output shape (stdout):
```
class=mechanical count=<N> variance=<F> stable=<true|false>
class=standard count=<N> variance=<F> stable=<true|false>
class=novel count=<N> variance=<F> stable=<true|false>
flip_recommendation=<ready|partially_ready|block|evidence_insufficient>
[ if partially_ready: ]
withheld_classes=<csv>
```

Stability-metric values (0.10, 20, 50) MUST appear in the script body with inline reference comments naming the SSOT — `references/model-routing.md` (`## Classifier-Confidence Stability Metric` section). Example:

```bash
# Stability thresholds — sourced from references/model-routing.md
# (## Classifier-Confidence Stability Metric section).
VARIANCE_MAX=0.10        # references/model-routing.md
ROLLING_WINDOW=20         # references/model-routing.md
CLASS_COVERAGE_MIN=50     # references/model-routing.md
```

(The traceability gate `p02-stability-metric-traceability.sh` greps each numeric for SSOT-naming on the same line.)

### SC-3a verifier (p02-sc3a-roundtrip.sh)

For each record in `tests/fixtures/m030-p02/sc3a-roundtrip-corpus.jsonl`:
1. Extract `unitId` field via `awk` (find `"unitId":"<value>"`).
2. Resolve `unitId` (M###/P##/T##) to a PLAN.md path via the canonical glob: `.orchestrator/milestones/M###/phases/P##/tasks/T##-*-PLAN.md`. First match wins.
3. Run `bash scripts/dispatch/classify-task.sh <plan-path>` → capture `character=<c>` line.
4. Look up `routing.<c>.claude-code` in `templates/model-routing.yml` (awk section-walker) → expected tier.
5. Extract `model_routed` from the JSONL record.
6. Assert expected tier == `model_routed`.

Per-record pass/fail; final `SUMMARY: p02-sc3a-roundtrip.sh pass=N fail=M`. Exit 0 iff `fail == 0`.

The fixture corpus is hand-authored to contain 6 records spanning real M030 PLAN.md paths (e.g., `unitId: "M001/P01/T01"` → `.orchestrator/milestones/M001/phases/P01/tasks/T01-*-PLAN.md`). T03 picks 6 known plans (e.g., from M001, M005, [M013](../../../../../milestones/M013/index.md), M019, M020, [M027](../../../../../milestones/M027/index.md)) and runs `classify-task.sh` against each at fixture-authoring time to record the correct `model_routed` value. The SC-3a verifier then re-runs the classifier independently and asserts agreement.

## Steps

1. **Confirm T02 deliverables are on disk and green.** Run:

   ```bash
   bash tools/verify/p02-additive-schema.sh
   bash tools/verify/p02-shadow-emit.sh
   bash tools/verify/p02-con3-closure.sh
   bash tools/verify/p02-append-only.sh
   ```

   Expected: all four exit 0. If any fails, T02 must be re-opened.

2. **Amend `scripts/dispatch/dispatch-interface.sh` to additionally emit `classifier_confidence`.** Surgical extension to T02's amendment. The shadow-on `printf` format string at the new shadow-on branch gains one more trailing field BEFORE `model_routed`:

   ```text
   ,"classifier_confidence":"%s","model_routed":"%s",...
   ```

   The shell variable `shadow_confidence` is set in the same env-var-gated block as `shadow_routed`/`shadow_used`:

   ```bash
   shadow_confidence="$(printf '%s\n' "$classifier_out" | grep -E '^confidence=' | head -n 1 | sed 's/^confidence=//')"
   ```

   Re-run `p02-additive-schema.sh` after this edit — the shadow-off branch is unchanged so byte-equality still holds. Re-run `p02-shadow-emit.sh` — the existing token-presence checks still pass; add a 4th token assertion (`classifier_confidence`) for Scenario A. (T03 amends `p02-shadow-emit.sh` to include the new token in its assertion list — a one-line edit per scenario.)

3. **Author `tests/fixtures/m030-p02/shadow-corpus-ready.jsonl`.** 150 hand-authored shadow `dispatch_usage` records: 50 with `model_routed=fast` (mechanical class), 50 with `model_routed=balanced` (standard class), 50 with `model_routed=smart` (novel class). All `classifier_confidence` values within each class are `high` (or all `medium`) — variance = 0 < 0.10. Each record's other fields are realistic (timestamps spaced 1 minute apart starting 2026-04-30T10:00:00Z; `unitId` pulled from real M030 phases or synthesized as `M999/P0X/T0Y`). Author one record manually with the full schema, then duplicate-and-vary for the remaining 149 (a small bash loop authored as a one-shot helper script under `/tmp/` — NOT committed; the OUTPUT is the committed fixture).

4. **Author `tests/fixtures/m030-p02/shadow-corpus-partially-ready.jsonl`.** 100 records: 50 mechanical (variance < 0.10), 50 standard (variance < 0.10), 0 novel. Drives `partially_ready` because: 2 of 3 classes meet thresholds; under-threshold class is novel; novel's routing-table default is `smart` (per shipped `templates/model-routing.yml routing.novel.claude-code: smart`).

5. **Author `tests/fixtures/m030-p02/shadow-corpus-evidence-insufficient.jsonl`.** Empty file (`touch <path>`). The verdict logic detects `total_count == 0` and emits `evidence_insufficient`.

6. **Author `tests/fixtures/m030-p02/shadow-corpus-block.jsonl`.** 30 records spread across 3 classes (10 each — all classes below the 50-count threshold). Drives `block` because: no class meets the count threshold AND `total_count > 0` (so not `evidence_insufficient`).

7. **Author `tests/fixtures/m030-p02/sc3a-roundtrip-corpus.jsonl`.** 6 hand-authored shadow records, each referencing a real PLAN.md by `unitId`. For each, run `bash scripts/dispatch/classify-task.sh <plan-path>` (one-shot, at fixture-authoring time) to determine the correct `character` and look up the resolved tier in `templates/model-routing.yml`. Record the resolved tier as `model_routed` in the fixture. Choose 6 plans spanning all 3 classes (2 mechanical, 2 standard, 2 novel) for full SC-3a coverage. Suggested plans: pick from milestones M001, M005, M013, M019, M020, M027 — all closed, all have stable PLAN.md paths.

8. **Author `scripts/diagnostics/shadow-compare.sh`** per the behavior contract above. Bash 3.2-compatible. Internal carve-out for awk/pipes (mirrors MEM004 emitter-internal pattern — the script is the dispatch-diagnostics SSOT). The body uses awk for variance computation, grep + awk for class-bucket extraction, and the awk YAML section-walker pattern (P01) for routing-table lookup. Stability thresholds declared with inline `references/model-routing.md` comments per the traceability gate. Verdict logic implemented as a sequence of `if`/`elif`/`else` branches against per-class stable flags.

   Inputs handling: parse `--corpus <path>` flag; if absent, glob `.orchestrator/milestones/M*/execution-log.jsonl` (use `find` instead of glob to avoid shell-glob expansion edge cases on missing dirs). Concatenate all JSONL files into `/tmp/shadow-compare-corpus.jsonl` for processing; clean up at exit.

9. **Author `tools/verify/p02-shadow-compare-verdicts.sh`.** Bash 3.2-compatible. Exercises four scenarios — one per fixture corpus:
   - Scenario A: `bash scripts/diagnostics/shadow-compare.sh --corpus tests/fixtures/m030-p02/shadow-corpus-ready.jsonl`. Assert exit 0; assert stdout contains exactly one line matching `^flip_recommendation=ready$`.
   - Scenario B: same with `shadow-corpus-partially-ready.jsonl`. Assert `^flip_recommendation=partially_ready$`.
   - Scenario C: same with `shadow-corpus-block.jsonl`. Assert `^flip_recommendation=block$`.
   - Scenario D: same with `shadow-corpus-evidence-insufficient.jsonl`. Assert `^flip_recommendation=evidence_insufficient$`.
   For each, ALSO assert: count of lines matching `^flip_recommendation=` is exactly 1 (closed-enum invariant — no double-emit). Per-scenario pass/fail; final `SUMMARY: p02-shadow-compare-verdicts.sh pass=N fail=M`. Exit 0 iff `fail == 0`.

10. **Author `tools/verify/p02-partial-flip-enum.sh`.** Bash 3.2-compatible. Single scenario:
    - Run `bash scripts/diagnostics/shadow-compare.sh --corpus tests/fixtures/m030-p02/shadow-corpus-partially-ready.jsonl`.
    - Capture stdout to `/tmp/p02-partial-flip-stdout.txt`.
    - Assert `grep -q '^flip_recommendation=partially_ready$' /tmp/p02-partial-flip-stdout.txt`.
    - Assert `grep -q '^withheld_classes=' /tmp/p02-partial-flip-stdout.txt`.
    - Extract withheld list: `grep '^withheld_classes=' /tmp/p02-partial-flip-stdout.txt | head -1 | sed 's/^withheld_classes=//' > /tmp/p02-withheld.txt`.
    - Assert withheld list contains `novel` AND does not contain `mechanical` AND does not contain `standard` (via three `grep -q`/`grep -qv` calls).
    - Assert under-threshold class's routing default is `smart`: awk-walk `templates/model-routing.yml routing.novel.claude-code`; assert value == `smart`.
    - Cleanup: `rm -f /tmp/p02-{partial-flip-stdout,withheld}.txt`.
    Final `SUMMARY: p02-partial-flip-enum.sh pass=N fail=M`. Exit 0 iff `fail == 0`.

11. **Author `tools/verify/p02-stability-metric-traceability.sh`.** Bash 3.2-compatible. Greps `scripts/diagnostics/shadow-compare.sh` for each pinned numeric and asserts each occurrence is on a line that ALSO references the SSOT:
    - `grep -n '0\.10' scripts/diagnostics/shadow-compare.sh` → for each match line, assert it contains `references/model-routing.md` OR `model-routing` OR `Classifier-Confidence Stability Metric`.
    - Same for `20` (rolling window) — but this requires a more careful match because `20` is a common literal; restrict to lines that ALSO contain `WINDOW`, `window`, `ROLLING`, or `rolling` to scope to the stability context.
    - Same for `50` (class coverage) — restrict to lines containing `COVERAGE`, `coverage`, `CLASS`, or `class`.
    For each numeric, count the in-scope occurrences and assert all of them have an SSOT reference. Per-numeric pass/fail; final `SUMMARY: p02-stability-metric-traceability.sh pass=N fail=M`. Exit 0 iff `fail == 0`.

12. **Author `tools/verify/p02-sc3a-roundtrip.sh`** per the behavior contract above. Bash 3.2-compatible. Per-record loop unrolled into 6 explicit blocks (no inline `for` loop — AD-19). Each block:
    - Reads the i-th line from `tests/fixtures/m030-p02/sc3a-roundtrip-corpus.jsonl` via `sed -n '<i>p' < <path> > /tmp/p02-sc3a-record-<i>.txt`.
    - Extracts `unitId` via `grep -oE '"unitId":"[^"]+"' < /tmp/p02-sc3a-record-<i>.txt | head -1 | sed 's/.*:"//; s/"$//' > /tmp/p02-sc3a-uid-<i>.txt`. Reads `unitId` from the tmp file.
    - Resolves PLAN.md path via `find .orchestrator/milestones/<M>/phases/<P>/tasks/ -name '<T>-*-PLAN.md' | head -1 > /tmp/p02-sc3a-path-<i>.txt`. Reads path from tmp file.
    - Runs `bash scripts/dispatch/classify-task.sh <path> > /tmp/p02-sc3a-classified-<i>.txt`. Extracts `character=<c>` from output.
    - Awk-walks `templates/model-routing.yml routing.<c>.claude-code` → expected tier.
    - Extracts `model_routed` from the original record.
    - Asserts expected tier == `model_routed`. Per-record `pass`/`fail` accumulator.
    - Cleanup tmp files at end of each block.
    Final `SUMMARY: p02-sc3a-roundtrip.sh pass=N fail=M`. Exit 0 iff `fail == 0`.

13. **Run all five new T03 verifiers as a self-check:**

    ```bash
    bash tools/verify/p02-additive-schema.sh
    bash tools/verify/p02-shadow-emit.sh
    bash tools/verify/p02-shadow-compare-verdicts.sh
    bash tools/verify/p02-partial-flip-enum.sh
    bash tools/verify/p02-stability-metric-traceability.sh
    bash tools/verify/p02-sc3a-roundtrip.sh
    ```

    Expected: all six exit 0. If `p02-shadow-compare-verdicts.sh` fails on a verdict, the verdict-logic branching in `shadow-compare.sh` is wrong — re-check the count + variance + partial-flip-safety conditions. If `p02-partial-flip-enum.sh` fails on `withheld_classes` content, the partially_ready branch's enumeration logic is wrong. If `p02-stability-metric-traceability.sh` fails, a numeric literal is on a line without SSOT-naming — add the inline comment. If `p02-sc3a-roundtrip.sh` fails on a record, the fixture's `model_routed` value disagrees with the live classifier output — re-run the classifier against the fixture's PLAN.md and update the fixture to match (or accept the disagreement as a real classifier-vs-fixture drift signal that needs investigation).

14. **Stage and commit.** Stage `scripts/dispatch/dispatch-interface.sh` (small Step-2 amendment), `scripts/diagnostics/shadow-compare.sh`, `tools/verify/p02-shadow-compare-verdicts.sh`, `tools/verify/p02-partial-flip-enum.sh`, `tools/verify/p02-stability-metric-traceability.sh`, `tools/verify/p02-sc3a-roundtrip.sh`, `tests/fixtures/m030-p02/shadow-corpus-{ready,partially-ready,block,evidence-insufficient}.jsonl`, `tests/fixtures/m030-p02/sc3a-roundtrip-corpus.jsonl`. Author commit message file via Write to `/tmp/p02-t03-commit-msg.txt`; commit with `git commit -F /tmp/p02-t03-commit-msg.txt`. Recommended message subject: `M030/P02/T03: shadow-compare 4-verdict + SC-3a + stability-metric traceability`.

## Must-Haves

This task satisfies the phase truths:

- "`scripts/diagnostics/shadow-compare.sh` exists and emits exactly one `flip_recommendation=` line whose value is drawn from the closed enum..." — gated by `tools/verify/p02-shadow-compare-verdicts.sh`.
- "`shadow-compare.sh`'s `partially_ready` verdict enumerates the withheld classes..." — gated by `tools/verify/p02-partial-flip-enum.sh`.
- "`shadow-compare.sh` consumes the pinned classifier-confidence stability metric values from `references/model-routing.md`..." — gated by `tools/verify/p02-stability-metric-traceability.sh`.
- "SC-3a holds: for each record in a shadow-mode JSONL fixture corpus where `model_routed` is set..." — gated by `tools/verify/p02-sc3a-roundtrip.sh`.

## Verification

```bash
bash tools/verify/p02-additive-schema.sh
bash tools/verify/p02-shadow-emit.sh
bash tools/verify/p02-shadow-compare-verdicts.sh
bash tools/verify/p02-partial-flip-enum.sh
bash tools/verify/p02-stability-metric-traceability.sh
bash tools/verify/p02-sc3a-roundtrip.sh
```

Each verifier uses single-script-file shape per AD-19. All six must exit 0 before T03 closes.

## Inputs

### From Previous Tasks

- `scripts/dispatch/dispatch-interface.sh` (amended by T02)
  - Key API: emits shadow `dispatch_usage` records with `classifier_confidence` (added in T03 Step 2), `model_routed`, `model_used`, `partial_flip_active`, `withheld_classes` fields when `M030_SHADOW_MODE=1` AND `CLAUDECODE=1`.
- `tools/verify/p02-shadow-emit.sh` (T02 + T03 amendment)
  - Key API: amended in Step 2 to also assert `classifier_confidence` token presence in shadow-on Scenario A.
- `tools/verify/p02-additive-schema.sh` (T01)
  - Key API: SC-11 byte-equality gate. Re-runs after T03 Step 2 amendment to confirm shadow-off byte-equality preserved.

### From Disk (Pre-existing)

- `scripts/dispatch/classify-task.sh` (P01/T02)
  - Key API: `bash <path> <plan-path>` writes `character=<c>` + `confidence=<c>`. Used by `shadow-compare.sh` (no — by SC-3a verifier) and by fixture-authoring at Step 7.
- `templates/model-routing.yml` (P01/T03)
  - Key API: `routing.<character>.claude-code` → symbolic tier; `resolution.<tier>.claude-code` → concrete model ID. T03's `shadow-compare.sh` reads via awk section-walker (P01 pattern).
- `references/model-routing.md` (P01/T03)
  - Key API: `## Classifier-Confidence Stability Metric` section pins variance ≤ 0.10, rolling N=20, per-class coverage 50. T03's `shadow-compare.sh` cites this section in inline comments next to the numeric literals.
- `.orchestrator/milestones/M*/` — real PLAN.md tree consumed by SC-3a fixture-authoring (Step 7) and by `p02-sc3a-roundtrip.sh` resolution.

## Constraints

- **AD-19 single-script-file shape**: all verifier `Check:` invocations are `bash <single-path>.sh`. The verifiers' internal logic uses tmp-file intermediates rather than inline pipes-in-command-substitution.
- **MEM004 dispatch-internal carve-out**: `scripts/diagnostics/shadow-compare.sh` is a dispatch-diagnostic SSOT; awk/pipes/`$()` permitted in its body. The verifiers that GATE it (the four `p02-*.sh` files) follow strict AD-19.
- **CON-3 (symbolic-tier closure)**: `shadow-compare.sh` reads `templates/model-routing.yml` for class → tier mapping; never embeds tier-symbol literals like `fast`/`balanced`/`smart` in routing logic without a corresponding awk YAML lookup. (Tier *names* may appear as constants — they are part of the symbolic interface, not concrete model IDs. The CON-3 verifier checks for concrete model-ID literals only, not symbolic tier names.)
- **CON-2/FR-19/SC-11 (additive-only schema)**: T03 Step 2's small amendment to `dispatch-interface.sh` adds `classifier_confidence` ONLY in the shadow-on `printf` branch. The shadow-off branch is unchanged. Re-run `p02-additive-schema.sh` after Step 2 confirms byte-equality preserved.
- **CON-6 (append-only shadow corpus)**: `shadow-compare.sh` is read-only against the corpus — never writes to JSONL files. Verified implicitly (the script's body contains no `>>` or `>` redirection to `*.jsonl` paths; the verifier `p02-append-only.sh` would catch a regression if `shadow-compare.sh` were ever invoked from `dispatch-interface.sh`'s emit path, which it is not).
- **D-A1 (4-verdict closed enum)**: exactly one `flip_recommendation=<value>` line on stdout per invocation; value drawn from {ready, partially_ready, block, evidence_insufficient}. Verified by `p02-shadow-compare-verdicts.sh`.
- **D-A3 (partial_flip enumeration + safety constraint)**: when `partially_ready`, emit `withheld_classes=<csv>`; under-threshold class's routing-table default MUST be `smart`. Verified by `p02-partial-flip-enum.sh`.
- **D-A7 (SC-3a write-path correctness)**: every shadow record's `model_routed` matches an independent re-classification of the referenced plan. Verified by `p02-sc3a-roundtrip.sh`.
- **Stability-metric traceability**: numeric literals 0.10 / 20 / 50 in `shadow-compare.sh` MUST appear on lines that name `references/model-routing.md` OR equivalent SSOT identifier. Verified by `p02-stability-metric-traceability.sh`.
- **Bash 3.2 compatibility**: no `declare -A`, no `mapfile`, no `readarray`. The variance computation uses awk (which has its own variable scoping; bash 3.2 only matters at the shell-glue level).
- **Plan-Time Discipline rule 5 (real-DB verification)**: T03 does NOT introduce SQL — N/A.

## Expected Output

- `scripts/dispatch/dispatch-interface.sh` — small Step-2 amendment adding `classifier_confidence` to the shadow-on `printf` template.
- `scripts/diagnostics/shadow-compare.sh` — 4-verdict aggregator, stability-metric traceable, partially_ready enumerates withheld classes.
- 5 fixture JSONL files at `tests/fixtures/m030-p02/`.
- 4 new verifiers at `tools/verify/p02-{shadow-compare-verdicts,partial-flip-enum,stability-metric-traceability,sc3a-roundtrip}.sh`.
- `tools/verify/p02-shadow-emit.sh` updated to assert `classifier_confidence` token presence in Scenario A.
- `bash tools/verify/p02-shadow-compare-verdicts.sh` exits 0 with `SUMMARY: pass=4 fail=0` (4 scenarios).
- `bash tools/verify/p02-partial-flip-enum.sh` exits 0 with `SUMMARY: pass=N fail=0`.
- `bash tools/verify/p02-stability-metric-traceability.sh` exits 0 with `SUMMARY: pass=N fail=0`.
- `bash tools/verify/p02-sc3a-roundtrip.sh` exits 0 with `SUMMARY: pass=6 fail=0` (6 records).

## Notes

Expected verifier output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash scripts/diagnostics/shadow-compare.sh --corpus tests/fixtures/m030-p02/shadow-corpus-ready.jsonl` → 3 per-class lines + `flip_recommendation=ready`, exit 0.
- Same with `shadow-corpus-partially-ready.jsonl` → 3 per-class lines + `flip_recommendation=partially_ready` + `withheld_classes=novel`, exit 0.
- Same with `shadow-corpus-evidence-insufficient.jsonl` → minimal output (possibly just `flip_recommendation=evidence_insufficient` if zero records produces empty per-class output).
- `bash tools/verify/p02-sc3a-roundtrip.sh` → 6 per-record OK lines + `SUMMARY: p02-sc3a-roundtrip.sh pass=6 fail=0`, exit 0.

The choice to read corpus via `--corpus <path>` vs default-glob is operationally important: in production, operators run `bash scripts/diagnostics/shadow-compare.sh` (no flag) against their `.orchestrator/milestones/*/execution-log.jsonl`; for testing, the verifiers pin the corpus path explicitly. The verifier ladder therefore exercises the `--corpus` path; production-glob is exercised post-launch when real shadow data accumulates.

The `classifier_confidence` field added in Step 2 is the load-bearing addition that makes the variance-stability check possible. Without it, `shadow-compare.sh` could only check class-coverage count, not confidence-variance — degrading the "calibration gate" from D-A1's 2-axis check to a 1-axis count check. Step 2 is therefore on the critical path for the D-A1 calibration story and not optional. The amendment is one shell-variable line + one format-string field — the additive-schema discipline is preserved (shadow-off byte-equality unchanged).

P03 will consume T03's `partial_flip_active` and `withheld_classes` placeholder fields by populating them at dispatch time when an operator activates a partial flip via config. T03 reserves the schema position; P03 fills in the values. The verifier `p02-partial-flip-enum.sh` exercises this via a hand-authored fixture in P02 (no live config plumbing yet) — P03 will extend it to exercise the live config-driven path.

P04 will consume T03's `shadow-compare.sh` directly via the FR-9 programmatic flip-gate — `dispatch-interface.sh` will call `shadow-compare.sh` before the first live-routed dispatch and refuse to proceed on `evidence_insufficient` or `block` verdicts. T03's verdict contract is the FR-9 gate's input; the four-verdict closed enum IS the FR-9 contract surface.

## State Context

- **Current State**: executing
- **Milestone**: M030
- **Phase**: P02
- **Task**: T03-shadow-compare
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **AD-19 single-script-file shape**: all verifier `Check:` invocations are `bash <single-path>.sh`. The verifiers' internal logic uses tmp-file intermediates rather than inline pipes-in-command-substitution.
- **MEM004 dispatch-internal carve-out**: `scripts/diagnostics/shadow-compare.sh` is a dispatch-diagnostic SSOT; awk/pipes/`$()` permitted in its body. The verifiers that GATE it (the four `p02-*.sh` files) follow strict AD-19.
- **CON-3 (symbolic-tier closure)**: `shadow-compare.sh` reads `templates/model-routing.yml` for class → tier mapping; never embeds tier-symbol literals like `fast`/`balanced`/`smart` in routing logic without a corresponding awk YAML lookup. (Tier *names* may appear as constants — they are part of the symbolic interface, not concrete model IDs. The CON-3 verifier checks for concrete model-ID literals only, not symbolic tier names.)
- **CON-2/FR-19/SC-11 (additive-only schema)**: T03 Step 2's small amendment to `dispatch-interface.sh` adds `classifier_confidence` ONLY in the shadow-on `printf` branch. The shadow-off branch is unchanged. Re-run `p02-additive-schema.sh` after Step 2 confirms byte-equality preserved.
- **CON-6 (append-only shadow corpus)**: `shadow-compare.sh` is read-only against the corpus — never writes to JSONL files. Verified implicitly (the script's body contains no `>>` or `>` redirection to `*.jsonl` paths; the verifier `p02-append-only.sh` would catch a regression if `shadow-compare.sh` were ever invoked from `dispatch-interface.sh`'s emit path, which it is not).
- **D-A1 (4-verdict closed enum)**: exactly one `flip_recommendation=<value>` line on stdout per invocation; value drawn from {ready, partially_ready, block, evidence_insufficient}. Verified by `p02-shadow-compare-verdicts.sh`.
- **D-A3 (partial_flip enumeration + safety constraint)**: when `partially_ready`, emit `withheld_classes=<csv>`; under-threshold class's routing-table default MUST be `smart`. Verified by `p02-partial-flip-enum.sh`.
- **D-A7 (SC-3a write-path correctness)**: every shadow record's `model_routed` matches an independent re-classification of the referenced plan. Verified by `p02-sc3a-roundtrip.sh`.
- **Stability-metric traceability**: numeric literals 0.10 / 20 / 50 in `shadow-compare.sh` MUST appear on lines that name `references/model-routing.md` OR equivalent SSOT identifier. Verified by `p02-stability-metric-traceability.sh`.
- **Bash 3.2 compatibility**: no `declare -A`, no `mapfile`, no `readarray`. The variance computation uses awk (which has its own variable scoping; bash 3.2 only matters at the shell-glue level).
- **Plan-Time Discipline rule 5 (real-DB verification)**: T03 does NOT introduce SQL — N/A.

### Acceptance Criteria

This task satisfies the phase truths:

- "`scripts/diagnostics/shadow-compare.sh` exists and emits exactly one `flip_recommendation=` line whose value is drawn from the closed enum..." — gated by `tools/verify/p02-shadow-compare-verdicts.sh`.
- "`shadow-compare.sh`'s `partially_ready` verdict enumerates the withheld classes..." — gated by `tools/verify/p02-partial-flip-enum.sh`.
- "`shadow-compare.sh` consumes the pinned classifier-confidence stability metric values from `references/model-routing.md`..." — gated by `tools/verify/p02-stability-metric-traceability.sh`.
- "SC-3a holds: for each record in a shadow-mode JSONL fixture corpus where `model_routed` is set..." — gated by `tools/verify/p02-sc3a-roundtrip.sh`.

### Files To Touch

- `scripts/dispatch/dispatch-interface.sh` (modify)
- `scripts/diagnostics/shadow-compare.sh` (create)
- `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` (create)
- `tests/fixtures/m030-p02/shadow-corpus-ready.jsonl` (create)
- `tests/fixtures/m030-p02/shadow-corpus-partially-ready.jsonl` (create)
- `tests/fixtures/m030-p02/shadow-corpus-evidence-insufficient.jsonl` (create)
- `tests/fixtures/m030-p02/shadow-corpus-block.jsonl` (create)
- `tests/fixtures/m030-p02/sc3a-roundtrip-corpus.jsonl` (create)
- `tools/verify/p02-fixture-shape.sh` (create)
- `tools/verify/p02-additive-schema.sh` (create)
- `tools/verify/p02-shadow-emit.sh` (create)
- `tools/verify/p02-con3-closure.sh` (create)
- `tools/verify/p02-append-only.sh` (create)
- `tools/verify/p02-shadow-compare-verdicts.sh` (create)
- `tools/verify/p02-partial-flip-enum.sh` (create)
- `tools/verify/p02-stability-metric-traceability.sh` (create)
- `tools/verify/p02-sc3a-roundtrip.sh` (create)
- `tools/verify/p02-phase-suite.sh` (create)
- `CLAUDE.md` (modify — recent-changes region)
- `AGENTS.md` (modify if present — recent-changes region dual-write)

<!-- Phase plan and task plan files (this file + tasks/T0[1-4]-*-PLAN.md)
     are written by the planner, not by the executor — not listed here. -->

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