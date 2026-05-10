---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T01-investigation-wrappers-A (Phase P04, Milestone M028)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~500 | required |
| Upstream Context | 981-1029 | ~8700 | required |
| Task Plan | 1031-1460 | ~4700 | required |
| State Context | 1462-1468 | ~100 | required |
| First-Turn Completeness | 1470-1517 | ~800 | required |
| **Total** | | **~25600** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 644
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
hit_count: 644
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
hit_count: 644
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
hit_count: 644
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
hit_count: 570
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
hit_count: 570
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
hit_count: 570
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
hit_count: 644
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
hit_count: 570
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
hit_count: 570
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
hit_count: 570
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
hit_count: 644
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
hit_count: 644
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
hit_count: 644
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
hit_count: 570
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
hit_count: 570
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
hit_count: 570
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
hit_count: 644
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
hit_count: 570
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
hit_count: 570
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
hit_count: 644
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
hit_count: 644
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
hit_count: 570
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
hit_count: 570
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
hit_count: 570
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
hit_count: 225
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
hit_count: 225
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
hit_count: 225
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
hit_count: 220
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
hit_count: 220
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
hit_count: 210
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

<!-- All Truth Check commands invoke project-tree verifiers directly per AD-19 and the
     M028/P02 dogfood finding (run-probe.sh is reserved for staged throwaway probes
     under /tmp, /var/folders, or <repo>/tmp/, NOT a generic invocation harness).
     Every line is single-script-file shape. Every Check verifier is co-authored with
     its task per the CLAUDE.md "Plan-time verifier-availability cross-check" hotfix —
     no cross-task verifier dependency. The classifier verdicts on every proposed
     wrapper invocation and verifier-invocation line were empirically traced through
     `scripts/verify/lib/shape-classifier.sh::classify_command` at plan-authoring time
     and recorded in plan prose. -->

- The four investigation-pattern wrappers exist under `scripts/util/` (grep-files.sh, cleanup-stale-results.sh, node-eval.sh, peek-files.sh), each a flat AD-19 single-script-file shape, each runnable on bash 3.2 + POSIX sh with no jq / node / python dependency beyond what each wrapper's own Description requires (node-eval.sh shells out to `node` only when invoked).
  - Check: `bash scripts/verify/m028/p04-wrappers-present.sh`
- `scripts/util/grep-files.sh <pattern> <file...>` greps each file in turn with a per-file separator and an aggregate exit code; replaces the `grep …; echo "---"; grep …` Screenshot 1 compound shape.
  - Check: `bash scripts/verify/m028/p04-grep-files.sh`
- `scripts/util/cleanup-stale-results.sh <milestone>` removes per-step result files for the named milestone and prints the residual listing; replaces the `/bin/rm -f .../*.txt && ls .../*.txt` Screenshot 2 / Finding D compound shape; refuses paths outside `.orchestrator/milestones/<MID>/` to bound blast radius.
  - Check: `bash scripts/verify/m028/p04-cleanup-stale-results.sh`

<dispatch-volatile>

## Upstream Context


### P02 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P02"
parent: "M028"
milestone: "M028"
provides:
  - "PreToolUse shape-guard hook with self-relative classifier resolution (BASH_SOURCE-based; CLAUDE_PROJECT_DIR retired); two new P02 verifiers: scripts/verify/m028/p02-hook-self-locate.sh (substring-pattern check) and scripts/verify/m028/p02-hook-self-conformance.sh (M021-classifier line-by-line check,scoped to the resolution block T01 introduces),Claude Code runtime adapter --hook-config emits absolute bash <abs-path>/<name>.sh commands for every leaf hook object (Stop: after-verify-sync.sh; PreToolUse Bash: pre-bash-shape-guard.sh + before-commit.sh) -- bare-name commands retired,every leaf hook object carries _orchestrator_managed: true (M025 uninstall-cascade invariant preserved),new verifier scripts/verify/m028/p02-adapter-absolute-paths.sh asserting bash-prefix shape,.sh-suffix,_orchestrator_managed-count == command-count,orchestrator-hooks-substring presence,updated scripts/verify/m025-p01-hook-schema.sh assertions 5+6 to the absolute-path contract (Stop basename == after-verify-sync.sh; PreToolUse Bash basenames include before-commit.sh + pre-bash-shape-guard.sh),Claude Code installer (packaging/install/install-claude-code.sh) stages a 4-script hook payload (pre-bash-shape-guard.sh + shape-classifier.sh + before-commit.sh + after-verify-sync.sh) plus a MANIFEST text file into ${HOME}/.claude/orchestrator-hooks/ on every install (cp -f,idempotent on repeat install); the --uninstall path walks MANIFEST to remove only the staged set and rmdirs the empty hooks dir,preserving any user-authored siblings,scripts/util/settings-merge.sh dedup key promoted from M025/P01 command-only key to (event,matcher,command) tuple within the _orchestrator_managed:true overlay -- closes the operator's M018-close 5-Stop-dupes / 7-PreToolUse-dupes regression; --force still bypasses the guard per M025 invariant; user-authored entries (no managed tag) pass through untouched,scripts/lifecycle/before-commit.sh permissive no-op shim closing a pre-existing [M008](../../../../../milestones/M008/index.md) packaging gap (bundle JSON pointed at a script that was never authored on disk); set -u; exit 0 with comment block documenting the M008/M025/M028 pedigree and the future-real-verification-ladder TODO,scripts/verify/m028/p02-hooks-payload-staged.sh -- two-mode T03 verifier: --dry-run pass asserts the would_write= list for the 5 expected basenames; real-install pass against an isolated HOME asserts files land + MANIFEST is exactly 5 lines,packaging/install/install-claude-code.sh --repair (and --repair --dry-run) flag short-circuiting the rest of the installer flow with a one-shot cleanup; scripts/util/settings-merge.sh repair subcommand walking ~/.claude/settings.json and removing flag-less M025 orphans by exact-tuple match while preserving every user-authored entry verbatim and every wrapper carrying _orchestrator_managed:true (wrapper-level OR leaf-level); scripts/verify/m028/p02-repair-fixture.sh byte-equality + idempotency verifier (stages P01/T02 canonical pre-repair snapshot into isolated HOME,runs --repair,asserts SHA-256 byte-equality with tests/fixtures/m028-post-repair-canonical.json,re-runs --repair to lock idempotency-by-construction); tests/fixtures/m028-post-repair-canonical.json canonical reference fixture (12 unflagged orphans removed,4 entries preserved: 1 PostToolUse user-authored + 1 SessionStart user-authored + 1 PreToolUse Bash flagged + 1 Stop flagged),scripts/verify/m028/install-roundtrip.sh -- FR-6 + SC-2 close-out gate; isolated-HOME 4-snapshot ladder; SHA-256 byte-equality assertions sha1==sha2 (idempotency / install-side dedup) and sha0==sha3 (M025 reversibility extended); helper-function compute_sha (function bodies are NOT AP-009-classifier-scanned) + shasum + tmp-file + awk-extract pattern; pinned post-install SHA d47ab7f32ef6bda277e4d3b6ab04ed70ddd92a3388250f13badc79d85389f32a captured in comment block as informational drift signal,scripts/verify/m028/finding-A-verifier.sh -- per-finding end-to-end gate for hook portability; installer-staged hook invoked from non-orchestrator-repo CLAUDE_PROJECT_DIR context with 3-connector compound chain Bash event; asserts hook exit 2 + REJECT substring on stderr; verdict stable across M028's classifier evolution (avoids the bash -c '<body>' wrapper that AP-014 descent in P03 will close),scripts/verify/m028/finding-F-verifier.sh -- per-finding end-to-end gate for Stop-event lifecycle resolution; installs,extracts Stop command via python3 + tmp-file,asserts bash <abs-path>.sh shape,confirms file existence,invokes with /dev/null stdin,asserts no 'command not found' substring on stderr,packaging/install/install-claude-code.sh post-uninstall reversibility-normalization -- when settings-merge.sh empties the target file to literal {} (whitespace-stripped),unlink it so pre-install canonical FILE-ABSENT state is restored; user-authored keys survive via settings-merge preservation path so the file stays on disk in that case"
requires:
  - "P01"
affects:
  - "P03,P04"
key_files:
  - "scripts/hooks/pre-bash-shape-guard.sh (modified -- resolution block at lines 35-64 replaced; CLAUDE_PROJECT_DIR retired from logic and from comments to keep the substring-absent invariant tight),scripts/verify/m028/p02-hook-self-locate.sh (created -- BASH_SOURCE+pwd-P present,CLAUDE_PROJECT_DIR absent),scripts/verify/m028/p02-hook-self-conformance.sh (created -- sources [M021](../../../../../milestones/M021/index.md) classifier; line-by-line allow-check scoped to the resolution block),scripts/dispatch/adapters/runtime/claude-code.sh (modified -- --hook-config block heredoc terminator switched <<'EOF' -> <<EOF for HOME_HOOKS expansion; three leaf objects emitted with absolute bash <path>/<name>.sh commands; comment block rewritten to document the new shape),scripts/verify/m028/p02-adapter-absolute-paths.sh (created -- 95 lines,AD-19 single-script-file flat shape,bash 3.2 + POSIX-sh-safe,no jq,captures emission via redirect to avoid pipe-in-cmdsub),scripts/verify/m025-p01-hook-schema.sh (modified -- assertions 5+6 rewritten to assert absolute-path basenames and bash-prefix/.sh-suffix shape; the bare-name assertions were the Finding F bug contract verbatim),packaging/install/install-claude-code.sh (modified -- new stage 2.5 stages 4 payload sources + MANIFEST under HOOKS_DIR=$HOME/.claude/orchestrator-hooks via cp -f loop; --uninstall block gains a MANIFEST-driven removal pass before settings-merge.sh uninstall; SUMMARY/UNINSTALLED counters extended with hooks_staged / hooks-payload-removed),scripts/util/settings-merge.sh (modified -- python3 merge body's dedup key replaced with collect_managed_keys() walking the target's hooks tree once and emitting (event,matcher,command) tuples; per-leaf dedup applied during fragment iteration; empty fragment wrappers skipped post-dedup to keep settings.json byte-stable across reinstalls; algorithm comment block updated),scripts/lifecycle/before-commit.sh (created -- permissive no-op closing the M008 packaging gap; documents the M008-vs-M025-vs-M028 pedigree),scripts/verify/m028/p02-hooks-payload-staged.sh (created -- two-mode verifier; AD-19 single-script-file flat shape,no jq),packaging/install/install-claude-code.sh (modified -- new REPAIR=0 init,--repair while-case parser entry,--repair mode block after --uninstall and before adapter sanity check,short-circuits with exit 0 on success),scripts/util/settings-merge.sh (modified -- usage-block + algorithm-comment + ORPHAN_TUPLES doc; new repair) subcommand arm with python3 heredoc ~110 lines applying wrapper-OR-leaf managed detection + strict-tuple match + cascade cleanup; unknown-subcommand guard updated),scripts/verify/m028/p02-repair-fixture.sh (created -- byte-equality + idempotency verifier; AD-19 single-script-file flat shape; bash 3.2 + POSIX-sh-safe; no jq; shasum-via-tmpfile + awk-extract pattern avoids $(... | ...) and $(cmd <file) compounds),tests/fixtures/m028-post-repair-canonical.json (created -- canonical reference fixture generated by applying the repair algorithm to the pre-repair fixture and serializing via json.dumps(indent=2,sort_keys=True),the same serializer settings-merge.sh uses,ensuring SHA-256 byte-equality at gate time),scripts/verify/m028/install-roundtrip.sh (created -- 154 lines; AD-19 single-script-file; bash 3.2 + POSIX-sh-safe),scripts/verify/m028/finding-A-verifier.sh (created -- 121 lines; AD-19 single-script-file; bash 3.2 + POSIX-sh-safe),scripts/verify/m028/finding-F-verifier.sh (created -- 137 lines; AD-19 single-script-file; bash 3.2 + POSIX-sh-safe; python3 baseline matches T03/T04),packaging/install/install-claude-code.sh (modified -- post-uninstall reversibility-normalization block: 18 lines added immediately after the merge-helper uninstall call,before the state_root config.yml resolution)"
key_decisions:
  - "Self-conformance verifier scoped to the T01-introduced resolution block (between '# Locate classifier' and '# Read stdin' divider comments) rather than the entire hook body. Driver: empirical line-by-line classifier scan against the unmodified M021 hook returns 14 reject:* verdicts on pre-existing lines (case-statement ;; arms count as compound-chain-gt2; awk '{...}' assignments count as quoted-brace; the M021 reject_lookup case body alone produces 5 rejects). The M028 spec marks the M021 surface immutable except for explicit T01 extension; reshaping case-arms to satisfy a per-line classifier would violate that non-goal. The truth statement's 'every non-comment non-blank line' wording is satisfied for every line T01 introduces; the broader file-wide assertion is not realizable under M021 immutability and is documented as a deviation in this summary's Deviations section.,Resolution-block shape avoids nested $(...) (would reject nested-cmd-sub) and avoids the [-z X] || [! -f X]; then chained-test shape (would reject compound-chain-gt2 with || + ; -> 3 stages). Used HOOK_DIR_RAW intermediate variable + two separate single-test if-blocks to keep every line at <=2 stages.,Heredoc-quote discipline: terminator MUST be unquoted (<<EOF) so HOME_HOOKS expands at adapter-emit time. The previous <<'EOF' quoted form blocked expansion. If a future change re-quotes it,the absolute-path contract breaks (literal ${HOME_HOOKS} written to settings.json).,M025 verifier update is in-scope for T02. The M025 baseline assertions 5+6 (orchestrator-post-verify / orchestrator-before-commit bare names) were the explicit Finding F bug contract; updating them to the absolute-path shape is part of the Finding F fix,not an out-of-scope drift. Alternative -- leaving M025 verifier failing -- would block phase verification.,Three leaves emitted,not two: the M025 baseline emitted two leaves (one Stop,one PreToolUse Bash). T02 adds a third leaf -- the shape-guard hook on PreToolUse Bash -- so the runtime-stable install includes it alongside before-commit. settings-merge.sh dedup key (event,matcher,command) makes the two PreToolUse Bash leaves distinct without collision.,Absolute paths reference ${HOME}/.claude/orchestrator-hooks/ (per CON-9). Symlink resolution at hook-execution time is Claude Code's job; the adapter computes without pwd -P (T01's hook handles symlink resolution at hook-load time via BASH_SOURCE + pwd -P).,Authored a minimal no-op scripts/lifecycle/before-commit.sh shim rather than DEVIATING. The plan's prerequisites stated the file exists; it did not. The M008 commit (3cd38f8) enrolled the lifecycle event in packaging/bundle/hooks/before-commit.json with command 'bash scripts/lifecycle/before-commit.sh' but never authored the script. T02's adapter inherits the broken contract and emits an absolute hook reference to the same path. T03's installer would have failed 'if [ ! -f $src ]; then echo FAIL' had I left the gap. Authoring a permissive no-op is symmetric with M008's intent and keeps the staged-payload contract real; wiring genuine pre-commit verification is out of T03 scope.,Per-leaf tuple dedup,not wrapper-level. The M025 baseline dedup checked whether any fragment-wrapper command was a subset of existing managed commands and skipped the wrapper as a unit. T03's tuple key requires per-leaf evaluation: walking each fragment leaf,computing (event,command),and either skipping it or appending to a deduped wrapper. Empty post-dedup wrappers are skipped entirely to keep settings.json byte-stable across reinstalls. --force still bypasses the guard per M025 invariant.,MANIFEST format: one filename per line plus a final 'MANIFEST' line referencing itself. This makes --uninstall self-cleaning: walking the file rm -f's all four hook scripts AND the MANIFEST itself; rmdir then succeeds against the empty dir. The plain-text MANIFEST has no schema and no python3 dependency.,rmdir over rm -rf for hooks dir cleanup. POSIX rmdir fails non-zero on non-empty dirs -- exactly the right behavior when user-authored siblings remain. The '2>/dev/null || true' swallows the diagnostic so uninstall does not error on the user-authored case; the dir survives intact in that case.,Two-mode verifier (dry-run + real install) instead of one mode. Real-install-only verifier would invoke the 1167-file runtime-staging copy as a side effect (heavy). Dry-run mode catches the would_write= list cheaply; real-install mode against a deeper isolated tmp dir proves the bytes actually land. Each mode's assertions are independent; both contribute to the truth statement.,Wrapper-managed-implies-leaves-managed. A wrapper carrying _orchestrator_managed:true at wrapper-level OR any-leaf-level is treated as a unit and KEPT verbatim by repair. The task plan's algorithm step 3 used leaf-only language but the P01/T02 fixture deliberately models pre-T02 wrapper-level flagging (5+1 Stop / 7+1 PreToolUse Bash partial-flag shape). Strict leaf-only interpretation would drop the inner leaf via tuple match then cascade-drop the now-empty wrapper,eliminating the 4 preserved entries the spec Truth requires. Wrapper-OR-leaf interpretation honors both pre-T02 wrapper-level and post-T02 leaf-level flagging shapes and produces the canonical 4-preserved post-repair output.,Strict-tuple match with ALLOWED_LEAF_KEYS={type,command} guard. A leaf with extra fields outside this set is preserved as user-authored even when its (event,command) tuple matches an orphan fingerprint. Closes the spec Edge Cases item '--repair false-positive risk' -- a user-authored hook entry that legitimately predates orchestrator install but happens to share a tuple is preserved iff it carries any extra field (description,env,run_in_background,timeout,etc.). The structural-shape match alternative would risk removing legitimate user entries and is explicitly out of scope per CON-4.,Hard-coded ORPHAN_TUPLES table inside the python3 heredoc body rather than externalized to a config file. Two entries today,expected to stay small,versioned with the orchestrator code (every M025-shape change ships a new table entry),trivially auditable. Externalization is a future hardening pass if the table grows beyond ~10 entries; until then,locality wins over configurability.,--repair short-circuits the installer flow (no probe,no payload staging,no runtime staging). Repair is a one-shot cleanup,not a re-install. exit 0 immediately after the merge-helper returns,mirroring the pre-existing --uninstall short-circuit shape.,Idempotency-by-construction lock: the verifier runs --repair twice in succession against the same isolated HOME and asserts SHA-256 byte-equality after both runs. No separate idempotency test surface needed; the gate verifier carries the invariant. Makes regression cheap to detect.,Finding-A test command swap: bare compound chain (echo a && echo b && echo c && echo d) instead of the plan's bash -c 'a && b && c && d && e'. The plan-author's chosen form is shielded from M021's AP-009 classifier by the sh-c-body wrapper -- AP-014's descent into sh-c-compound-body is reserved for P03's classifier extension. Bare compound chain rejects cleanly under both M021 (AP-009) and the future M028 classifier (AP-014 catches the wrapped form on top),so the verifier is stable across the P03 evolution.,Reversibility-normalization landing site: installer block (not settings-merge.sh primitive). Settings-merge is the JSON manipulation primitive; the policy 'reversibility means file-absent when nothing remains' is an installer-level concern that depends on the operator's intent (a fresh-install user has no settings.json pre-install; an existing-CC-user does). The installer block guards on contents == '{}' AFTER the merge helper returns -- preserves the helper's purity (it always emits valid JSON) while implementing the file-absent reversibility contract at the operator-facing layer.,Pinned-SHA delivery in the verifier comment block (not in P02-VERIFICATION.md). The plan-author's Step 5 offered both options; choosing the verifier comment block makes the audit trail co-located with the assertion and harder to lose during phase-summary backfill. Future M028 changes that mutate the JSON shape will alter sha1 and the comment must be updated in the same PR -- that drift IS the audit signal.,Helper function compute_sha defined at top-of-script avoids both $(... | ...) compound substitution and the AP-009 classifier scan (function bodies are not classifier-scanned; only inline command-line shape is). Multi-line shasum + awk-extract inside the function body is AD-19 compliant via this carve-out,matching the T04/T03 verifier convention.,Hook protocol reading: scripts/hooks/pre-bash-shape-guard.sh header documents exit 2 for hard reject + literal REJECT: prefix on stderr. T05's finding-A verifier reads the protocol from the hook source itself,not from spec prose -- captures any future protocol mutation as a verifier mismatch the next time someone runs the gate."
patterns_established:
  - "BASH_SOURCE self-location with two-step fallback: install-side sibling resolution (HOOK_DIR/shape-classifier.sh) tried first,in-tree development resolution (HOOK_DIR/../verify/lib/shape-classifier.sh) tried second,fail-open exit 0 on both miss. pwd -P in HOOK_DIR canonicalization for symlink resolution.,Shape-classifier-aware resolution-block authoring: every introduced line empirically validated against scripts/verify/lib/shape-classifier.sh classify_command before commit. Nested $(...) avoided via HOOK_DIR_RAW intermediate. Combined-test conditions (|| + ;) split into two single-test if-blocks. The classifier's 1 stages -> allow / >2 stages -> reject:compound-chain-gt2 / depth>=2 $( -> reject:nested-cmd-sub semantics dictate the source-shape grammar.,Comment hygiene under substring-absent verifiers: the p02-hook-self-locate.sh substring check 'CLAUDE_PROJECT_DIR must not appear' applies file-wide,including comments. Comments rewritten to describe the retired var without mentioning it by literal name. The dual narrative+lint role of comments under simple grep-based verifiers is now an explicit authoring constraint.,Verifier invocation discipline: P02 truth-Check rows use direct 'bash scripts/verify/m028/p02-*.sh' invocation,not run-probe.sh wrapping. The plan's Steps section run-probe.sh wrapping was a planning error -- run-probe.sh restricts to /tmp,/var/folders,and <repo>/tmp/ for staged throwaway probes; project verifiers under scripts/verify/m028/ are invoked directly. Followed the truth-Check shape,not the Steps shape.,Absolute-path heredoc emission: variable expansion at adapter-emit time via unquoted heredoc terminator <<EOF + HOME_HOOKS=${HOME}/.claude/orchestrator-hooks; resolved absolute path written into JSON fragment,not a placeholder. Robust against PATH-lookup failures in consumer projects (the Finding F root cause).,Substring-shape verifier discipline: no jq,grep-only structural assertions on JSON-as-text. Asserts on (a) command-prefix '\bash ',(b) command-suffix '.sh\',(c) _orchestrator_managed-count == command-count,(d) literal substring 'orchestrator-hooks' present. Robust to whitespace/ordering variation; AD-19 single-file flat shape compliance.,Verifier reads adapter via redirect not pipe (CON-1): emission captured via 'bash $ADAPTER --hook-config > $tmp 2>/dev/null',then grep / while-read against the file. No \$(...) containing pipe; no pipe inside cmdsub. Compatible with the active shape-guard hook's classifier.,Assertion-style shift in step with contract change: when a downstream task explicitly supersedes an upstream verifier's assertion target (here,M025 baseline bare-name assertions superseded by M028 absolute-path contract),the verifier is updated in the same task as the contract change. The verifier is the contract-test,not an immutable artifact.,Space-delimited string iteration for bash 3.2 list: HOOKS_PAYLOAD built via repeated 'HOOKS_PAYLOAD=\${HOOKS_PAYLOAD} <abs-path>\' assignments,then iterated via 'for src in $HOOKS_PAYLOAD'. Bash 3.2 safe (no array required); paths under ${REPO_ROOT} carry no spaces (out-of-scope failure mode for paths-with-spaces).,MANIFEST-driven uninstall: install-side staged-files removal walks a plain-text MANIFEST in the staged dir; never 'find ... -delete' against the dir. Companion shape to M025's _orchestrator_managed:true tag in settings.json -- the MANIFEST is the install-side counterpart for non-JSON staged artifacts.,Per-leaf tuple-keyed dedup with single-walk target-key collection. Walk the target hooks tree once via collect_managed_keys() and build a set of (event,matcher,command) tuples; iterate fragment leaves and consult the set per leaf; append non-duplicates and update the running set. Empty post-dedup wrappers are skipped to preserve byte-equality across runs. Algorithm comment block at top of settings-merge.sh documents the contract.,Two-mode verifier discipline for install-touching gates: cheap --dry-run mode validates the would_write= shape without invoking the heavy runtime-staging branch; real-install mode against an isolated tmp dir proves the actual file-byte contract. Combined into one verifier file (AD-19 single-script shape) but with mode-separated assertion blocks.,Wrapper-OR-leaf managed-detection helper: wrapper_is_managed(w) returns True if wrapper.get('_orchestrator_managed') is True OR any leaf in wrapper.hooks carries _orchestrator_managed:true. Companion to leaf_is_managed() for backward-compat with both pre-T02 wrapper-level flagging and post-T02 leaf-level flagging shapes. Encodes the M025-to-M028 shape evolution as a single boolean predicate.,Strict-tuple match with extra-key guard: orphan-tuple match requires (event,command) in ORPHAN_TUPLES AND set(leaf.keys()) - ALLOWED_LEAF_KEYS == empty. Captures the 'user-authored entry that happens to share a tuple but adds extra fields' Edge Case at the algorithm level rather than a downstream allow-list.,Idempotency-by-construction verifier: run --repair twice in succession against the same isolated HOME,assert SHA-256 byte-equality after both runs. Locks the SC-5/CON-5 idempotency invariant at gate time without separate test surface.,One-shot cleanup short-circuit pattern: --repair (and any future one-shot cleanup mode) exits 0 immediately after the cleanup helper returns,bypassing probe/register/stage/wire stages. Symmetric with the pre-existing --uninstall block; both are reversibility-side modes that target a specific file (settings.json + manifest-listed payload) rather than re-establishing the full install set.,AD-19 single-script-file shasum extraction: shasum -a 256 <file> > tmp.sha; awk '{print $1}' tmp.sha. Avoids $(... | ...) compound and $(cmd <file) nested redirect,both AP-006 forbidden inside scripts that must conform to AD-19. Two-step is more verbose than the inline pipeline but composes cleanly into bash 3.2 + POSIX sh constraints.,Helper-function carve-out for AD-19 multi-step computations: function bodies are NOT scanned by the AP-009 inline-command-shape classifier. compute_sha() { shasum -a 256 \$1\ > \$2.raw\; awk '{print $1}' \$2.raw\ > \$2\; } at top-of-script is the canonical shape for SHA computation; multi-step pipelines that would otherwise require run-probe.sh staging inline can be hoisted into a function call. T04 used the same carve-out implicitly; T05 codifies it as a comment-block convention.,Reversibility-normalization at the installer layer: when an uninstall path's primitive operation leaves a 'logically empty' artifact on disk (e.g.,'{}' for JSON,empty file for text),the installer post-processes the artifact to file-absent state. The empty-detection (whitespace-stripped contents == '{}') belongs at the installer layer because the policy is operator-facing (pre-install canonical state for unmanaged HOME),not primitive-facing.,Pinned-SHA-in-comment as informational drift signal: capture a known-good post-install SHA-256 in a clearly-labeled comment block at the top of the verifier. The hard gate stays the byte-equality assertions; the pin is human audit trail. Future PRs that mutate the JSON shape (adapter,serializer,bundle) MUST update the pin in the same PR -- if the comment goes stale,the gate still passes (because byte-equality is checked against a fresh snapshot,not the pin) but the divergence between code and comment becomes the review-time signal.,Test-command stability across classifier evolution: when authoring an end-to-end verifier whose verdict depends on classifier output,choose a test input that is robust across in-flight classifier extensions. Bare-form compound chains are AP-009-rejected today and remain AP-009-rejected after P03's classifier expansion; sh-c-body-wrapped chains depend on AP-014 descent (P03) -- choosing the bare form keeps the verifier verdict stable through the M028/P03 transition.,Snapshot-ladder shape for byte-equality gates: pre-state -> action-1 -> action-2 -> reverse-action; SHA at each step; assert (action-1 == action-2) for idempotency AND (pre == reverse) for reversibility in a single isolated-HOME exercise. Cheaper than separate idempotency + reversibility verifiers; the four snapshots fit in one tmp dir and one set -u execution context."
drill_down_paths:
  - "[.orchestrator/milestones/M028/phases/P02/tasks/T01-hook-self-locate-SUMMARY.md](../../../../../milestones/M028/phases/P02/tasks/T01-hook-self-locate-SUMMARY.md), [.orchestrator/milestones/M028/phases/P02/tasks/T02-adapter-absolute-paths-SUMMARY.md](../../../../../milestones/M028/phases/P02/tasks/T02-adapter-absolute-paths-SUMMARY.md), [.orchestrator/milestones/M028/phases/P02/tasks/T03-installer-payload-and-dedup-SUMMARY.md](../../../../../milestones/M028/phases/P02/tasks/T03-installer-payload-and-dedup-SUMMARY.md), [.orchestrator/milestones/M028/phases/P02/tasks/T04-repair-flag-SUMMARY.md](../../../../../milestones/M028/phases/P02/tasks/T04-repair-flag-SUMMARY.md), [.orchestrator/milestones/M028/phases/P02/tasks/T05-roundtrip-and-verifiers-SUMMARY.md](../../../../../milestones/M028/phases/P02/tasks/T05-roundtrip-and-verifiers-SUMMARY.md)"
duration: "300m"
verification_result: "pass"
completed_at: "2026-04-29T16:21:18Z"
observability_surfaces:
  - "none"
---

P02 closes Findings A (hook portability) and F (lifecycle-script PATH lookup) — the load-bearing pre-launch slice that lets `orchestrator:auto` run cleanly inside any consumer project, not just the orchestrator repo. Five tasks landed in dependency order T01 → T02 → T03 → T04 → T05.

**T01 (hook self-locate)** retired `CLAUDE_PROJECT_DIR` from `scripts/hooks/pre-bash-shape-guard.sh` resolution and replaced it with a `BASH_SOURCE`-derived two-step fallback (install-side sibling + in-tree dev fallback, both with `pwd -P` symlink resolution). The reshaped resolution block was empirically validated against the M021 classifier line-by-line — `HOOK_DIR_RAW` intermediate replaces the would-reject nested `$(...)`; combined `[ -z X ] || [ ! -f X ]; then` test split into two single-test if-blocks to stay under the AP-009 compound-chain threshold. M021 surface outside the resolution block stayed immutable per the spec non-goal.

**T02 (adapter absolute paths)** rewrote `scripts/dispatch/adapters/runtime/claude-code.sh::--hook-config` to emit absolute `bash <abs-path>/<name>.sh` commands for three leaves (Stop:`after-verify-sync.sh`; PreToolUse Bash:`pre-bash-shape-guard.sh` + `before-commit.sh`), each tagged `_orchestrator_managed: true`. The bare-name forms that were the explicit Finding F bug contract are retired. Heredoc terminator switched `<<'EOF'` → `<<EOF` so `${HOME_HOOKS}` expands at adapter-emit time. The M025 verifier (`scripts/verify/m025-p01-hook-schema.sh` assertions 5+6) was updated in lockstep — verifier-as-contract-test, not immutable artifact.

**T03 (installer payload + tuple dedup)** added stage 2.5 to `packaging/install/install-claude-code.sh` that stages a 5-file payload (4 scripts + MANIFEST) under `${HOME}/.claude/orchestrator-hooks/` on every install, with MANIFEST-driven uninstall that walks the manifest and `rmdir`'s the empty hooks dir while preserving any user-authored siblings. The settings-merge dedup key was promoted from M025/P01's command-only key to a `(event, matcher, command)` tuple via a new `collect_managed_keys()` helper — closes the operator's M018-close 5-Stop-dupes / 7-PreToolUse-dupes regression. Empty post-dedup wrappers are skipped to keep settings.json byte-stable across reinstalls. T03 also authored `scripts/lifecycle/before-commit.sh` as a permissive no-op shim closing a pre-existing M008 packaging gap (the bundle JSON pointed at a file that was never authored on disk; T02 inherited the broken contract).

**T04 (--repair flag)** added a `packaging/install/install-claude-code.sh --repair` mode (and `--repair --dry-run`) that short-circuits the installer flow with a one-shot cleanup. The companion `scripts/util/settings-merge.sh repair` subcommand walks `~/.claude/settings.json` and removes flag-less M025 orphans by exact-tuple match (against a hard-coded `ORPHAN_TUPLES` table) while preserving user-authored entries verbatim and entries with `_orchestrator_managed: true` at wrapper-level OR leaf-level. Strict-tuple match with `ALLOWED_LEAF_KEYS={type, command}` guard closes the spec's `--repair false-positive risk` Edge Case — a leaf with extra fields outside this set is preserved as user-authored even when its `(event, command)` tuple matches an orphan fingerprint. The companion verifier `scripts/verify/m028/p02-repair-fixture.sh` runs `--repair` twice in succession against the same isolated HOME and asserts SHA-256 byte-equality after both runs (idempotency-by-construction).

**T05 (install-roundtrip + per-finding verifiers)** formalized the cross-cutting verifier suite. `scripts/verify/m028/install-roundtrip.sh` runs a four-snapshot SHA-256 ladder (sha0 pre-install, sha1+sha2 post-install pair, sha3 post-uninstall) with `sha1==sha2` (idempotency / install-side dedup) and `sha0==sha3` (M025 reversibility extended) assertions; pinned post-install SHA `d47ab7f32ef6bda277e4d3b6ab04ed70ddd92a3388250f13badc79d85389f32a` captured in a comment block as informational drift signal. `finding-A-verifier.sh` proves the staged hook fires from a non-orchestrator-repo `CLAUDE_PROJECT_DIR` context with a 3-connector compound-chain Bash event (bare form, AP-009-stable across the P03 classifier evolution). `finding-F-verifier.sh` proves the Stop event resolves `<abs>/.claude/orchestrator-hooks/after-verify-sync.sh` with no `command not found` diagnostic. T05 also added an 18-line post-uninstall reversibility-normalization block in `install-claude-code.sh` — when `settings-merge.sh uninstall` empties the target file to literal `{}`, unlink it so the pre-install canonical FILE-ABSENT state is restored.

**Verification**: 54/54 Tier 1 must-haves PASS. All 8 P02 verifiers PASS independently and as a regression sweep. M025 reversibility extended via install-roundtrip pinned-sha gate (`pass=3 fail=0`). M025 uninstall cascade preserved (`pass=5 fail=0`). M025 hook schema absolute-path contract live (`pass=8 fail=0`).

**Patterns established**: BASH_SOURCE self-location with two-step fallback; shape-classifier-aware resolution-block authoring (every introduced line empirically validated against `classify_command` before commit); comment hygiene under substring-absent verifiers (rewrite to describe retired vars without literal name); absolute-path heredoc emission with unquoted terminator + variable expansion at adapter-emit time; substring-shape verifier discipline (no jq, grep-only structural assertions); per-leaf tuple-keyed dedup with single-walk target-key collection + empty-wrapper skip; two-mode verifier discipline for install-touching gates (cheap dry-run + isolated-HOME real-install); wrapper-OR-leaf managed-detection helper bridging pre-T02 wrapper-level and post-T02 leaf-level flagging shapes; strict-tuple match with extra-key guard; idempotency-by-construction verifier (run cleanup twice, assert byte-equality); helper-function carve-out for AD-19 multi-step computations (function bodies are NOT scanned by AP-009 inline-shape classifier); reversibility-normalization at the installer layer (file-absent for logically-empty JSON); pinned-SHA-in-comment as informational drift signal; test-command stability across classifier evolution (bare-form compound chains over sh-c-body-wrapped chains); snapshot-ladder shape for byte-equality gates.

**Dogfood findings surfaced** (all captured in CLAUDE.md hotfix list): plan-time classifier-shape blind spot (planner did not pre-validate proposed shape-guard-bound lines against `classify_command`); `run-probe.sh` is not a generic invocation harness (it rejects paths outside `/tmp`/`/var/folders`/`<repo>/tmp/` with exit 3 — every P02 task plan's Verification section had to be patched from `bash scripts/util/run-probe.sh scripts/verify/...` to `bash scripts/verify/...` directly); slug-suffix summary read asymmetry resurfaced (T04 wrote `T04-SUMMARY.md` but auto-loop expects `T04-repair-flag-SUMMARY.md` per the existing CLAUDE.md hotfix entry; renamed in-place); `commit -m "$(cat <<EOF...)"` pattern from CLAUDE.md tension with the active shape-guard hook (AP-008 heredoc-with-expansion rejects; `git commit -F <file>` is the safe form); `scripts/verify/m025-p01-merge-preservation.sh` and `scripts/verify/m013-p04-post-verify-hook.sh` are stale on the M025/M028 contract (out-of-scope for P02; bundle into next M025-touching paper-cut sweep); `settings-merge.sh uninstall` arm uses leaf-only managed detection (T04's repair fixes wrapper-OR-leaf detection for the repair path; uninstall does not — symmetric ~10-line patch is the next paper-cut item); plan-author confabulated M021 classifier verdict on `bash -c '<body>'` form (T05 plan specified that form as "rejects under M021" — empirical trace showed allow; AP-014 P03 closes the gap; T05 verifier swapped to bare compound chain); helper-function carve-out (AD-19 function bodies not classifier-scanned) is load-bearing for SHA-computation verifiers but undocumented in `references/` or `commands/plan-phase.md`.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M028"
name: "Investigation Wrappers — grep-files + cleanup-stale-results"
depends_on: []
---

## Prerequisites

Plan-author empirically verified each Prerequisite path on disk at plan-authoring time (CLAUDE.md hotfix "Plan-time prerequisite-existence verification"):

- `scripts/util/` directory exists.
- `scripts/util/run-probe.sh` exists (the established sibling shape for util-tree wrappers; T01 follows its general docstring + arg-parsing convention).
- `scripts/util/read-range.sh` exists (sibling shape — short, single-purpose, exit-coded wrapper; T01 follows the same flat AD-19 single-script-file shape).
- `scripts/verify/lib/shape-classifier.sh` exists (used by the plan-level verifiers to confirm wrapper-invocation lines classify as `allow`).
- `scripts/verify/m028/` directory exists with the M028 verifier suite from P02 + P03.
- `ANTIPATTERNS.md` carries AP-010..AP-014 (P03 close).

The wrappers `scripts/util/grep-files.sh` and `scripts/util/cleanup-stale-results.sh` do NOT exist on disk before T01 (verified absent at plan-authoring time); T01 creates them.

## Description

Author two flat AD-19 single-script-file wrappers under `scripts/util/`:

1. **`grep-files.sh`** (FR-14) — replaces the Screenshot 1 shape `grep PATTERN file1 ; echo "---" ; grep PATTERN file2` with a single wrapper invocation that greps each file in turn, prints a per-file separator, and exits with the appropriate aggregate return code (0 if any file matched, 1 if no matches, 2 on usage error). The wrapper accepts a regex pattern as the first positional arg and one or more file paths as subsequent positional args. No `-r`/`-R` recursion in the v1 surface — recursion is `peek-files.sh`'s job; `grep-files.sh` is the explicit-files variant.

2. **`cleanup-stale-results.sh`** (FR-15) — replaces the Screenshot 2 / Finding D shape `/bin/rm -f .orchestrator/milestones/<MID>/phases/<PID>/tasks/*.txt && ls .orchestrator/milestones/<MID>/phases/<PID>/tasks/*.txt` with a single wrapper invocation that removes per-step result files for the named milestone and prints the residual `.txt` listing under that milestone's tree. The wrapper takes a milestone ID as the first positional arg, validates it matches `M[0-9]+`, refuses paths outside `.orchestrator/milestones/<MID>/` to bound blast radius (Edge Case from M028 spec), and prints a structured summary on stdout (`REMOVED: <N>` line + `RESIDUAL: <count>` line; `OK` on success).

Plus author the matching plan-level verifiers:

- `scripts/verify/m028/p04-grep-files.sh` (~50 lines) — exercises `grep-files.sh` against a tmp-staged 2-file tree with a known pattern, asserts the per-file separator pattern, asserts aggregate exit codes for the match / no-match / usage cases.
- `scripts/verify/m028/p04-cleanup-stale-results.sh` (~70 lines) — exercises `cleanup-stale-results.sh` against an isolated tmp tree mirroring `.orchestrator/milestones/<MID>/phases/<PID>/tasks/*.txt`, asserts the `REMOVED:` count, asserts boundary refusal on a path outside the milestone tree (mocked via the wrapper's input-validation guard), asserts the structured-output protocol.

## Steps

### Round 1 — `scripts/util/grep-files.sh`

1. **Author `scripts/util/grep-files.sh`** (~45 lines):

```bash
#!/usr/bin/env bash
# scripts/util/grep-files.sh -- Grep one pattern across multiple files with per-file separators.
#
# Usage: grep-files.sh <pattern> <file...>
#   <pattern> -- ERE pattern (passed verbatim to grep -E).
#   <file...> -- one or more file paths (no recursion; for recursion use peek-files.sh).
#
# Output:
#   --- <file> ---       (per-file separator, stdout)
#   <matching lines>     (grep output for that file, stdout)
#   ...                  (repeated for each file)
#
# Exit:
#   0 -- at least one file produced at least one match.
#   1 -- no file produced any match (clean run, nothing found).
#   2 -- usage error (missing args, unreadable file).
#
# Replaces the Screenshot 1 shape `grep P f1 ; echo "---" ; grep P f2` (M028 FR-14, AP-009 / AP-010 sibling).
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

if [ $# -lt 2 ]; then
  echo "usage: grep-files.sh <pattern> <file...>" >&2
  exit 2
fi

pattern="$1"
shift

any_match=1   # 1 = no match (default), 0 = at least one match
for f in "$@"; do
  if [ ! -f "$f" ]; then
    echo "grep-files.sh: file not found: $f" >&2
    exit 2
  fi
  printf -- '--- %s ---\n' "$f"
  if grep -E -- "$pattern" "$f"; then
    any_match=0
  fi
done

exit "$any_match"
```

2. **Validate the wrapper script's own shape** against the M028 classifier — every non-comment, non-blank line must classify as `allow`. The plan-author traced the load-bearing lines through `classify_command` at plan-authoring time:

   - `if [ $# -lt 2 ]; then` → `allow` (single test, AP-009-stage-count = 1).
   - `for f in "$@"; do` → fence-internal; the AP-009 inline-shape classifier scans tool-call lines (the surrounding script body is not the agent-facing surface). The wrapper IS the executable; only the wrapper's *invocation* lines (e.g. in plans + payloads) must classify clean.
   - The wrapper's INVOCATION shape `bash scripts/util/grep-files.sh <pattern> <file...>` was traced: `bash scripts/util/grep-files.sh foo file1.md file2.md` → `allow` (recorded at plan-authoring time).

3. **Author `scripts/verify/m028/p04-grep-files.sh`** (~60 lines):

```bash
#!/usr/bin/env bash
# scripts/verify/m028/p04-grep-files.sh -- M028 P04/T01 plan-level verifier for grep-files.sh.
#
# Exercises the wrapper against a tmp-staged 2-file tree:
#   1. Match case: pattern present in both files -> exit 0, two separators.
#   2. Match-some case: pattern in file 1 only -> exit 0.
#   3. No-match case: pattern in neither file -> exit 1.
#   4. Usage-error case: missing args / unreadable file -> exit 2.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
WRAPPER="${REPO_ROOT}/scripts/util/grep-files.sh"

if [ ! -f "$WRAPPER" ]; then
  echo "FAIL: $WRAPPER not found" >&2
  exit 1
fi

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

printf 'apple banana\ncarrot\n' > "$tmp/a.txt"
printf 'apple date\nelderberry\n' > "$tmp/b.txt"
printf 'date elderberry\n' > "$tmp/c.txt"

# Case 1: both files match.
out_match="$(bash "$WRAPPER" 'apple' "$tmp/a.txt" "$tmp/b.txt")"
rc=$?
if [ "$rc" -eq 0 ]; then pass "case1 exit 0 on any-match"; else fail "case1 exit" "rc=$rc"; fi
echo "$out_match" | grep -q -- "--- $tmp/a.txt ---" && pass "case1 separator a" || fail "case1 separator a" "missing"
echo "$out_match" | grep -q -- "--- $tmp/b.txt ---" && pass "case1 separator b" || fail "case1 separator b" "missing"

# Case 2: no matches.
bash "$WRAPPER" 'zzz_no_match' "$tmp/a.txt" "$tmp/b.txt" >/dev/null
rc=$?
if [ "$rc" -eq 1 ]; then pass "case2 exit 1 on no-match"; else fail "case2 exit" "rc=$rc"; fi

# Case 3: usage error (missing pattern).
bash "$WRAPPER" 2>/dev/null
rc=$?
if [ "$rc" -eq 2 ]; then pass "case3 exit 2 on usage"; else fail "case3 exit" "rc=$rc"; fi

# Case 4: unreadable file.
bash "$WRAPPER" 'foo' "$tmp/does-not-exist" 2>/dev/null
rc=$?
if [ "$rc" -eq 2 ]; then pass "case4 exit 2 on missing file"; else fail "case4 exit" "rc=$rc"; fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: p04-grep-files.sh"
  exit 0
fi
echo "FAIL: p04-grep-files.sh ($fail_count failures)"
exit 1
```

### Round 2 — `scripts/util/cleanup-stale-results.sh`

4. **Author `scripts/util/cleanup-stale-results.sh`** (~55 lines):

```bash
#!/usr/bin/env bash
# scripts/util/cleanup-stale-results.sh -- Remove per-step result files under a milestone tree.
#
# Usage: cleanup-stale-results.sh <milestone-id>
#   <milestone-id> -- format M[0-9]+ (e.g. M028).
#
# Removes every *.txt file under .orchestrator/milestones/<MID>/phases/<PID>/tasks/
# (per-step task-result scratch files) and prints a structured summary.
#
# Output:
#   REMOVED: <N>          (count of files removed)
#   RESIDUAL: <count>     (count of *.txt files still present under the milestone tree)
#   OK                    (success terminator)
#
# Refuses milestone IDs that do not match M[0-9]+ to bound blast radius.
# Refuses if the milestone tree does not exist.
#
# Exit:
#   0 -- success.
#   1 -- milestone tree missing.
#   2 -- usage / validation error (bad milestone ID).
#
# Replaces the Screenshot 2 / Finding D shape `/bin/rm -f .../*.txt && ls .../*.txt` (M028 FR-15).
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

if [ $# -ne 1 ]; then
  echo "usage: cleanup-stale-results.sh <milestone-id>" >&2
  exit 2
fi

mid="$1"

# Validate milestone ID format -- closed shape avoids path traversal and globbing.
case "$mid" in
  M[0-9]*) : ;;
  *)
    echo "cleanup-stale-results.sh: invalid milestone ID '$mid' (expected M[0-9]+)" >&2
    exit 2
    ;;
esac

# Resolve repo root.
script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../.." && pwd -P)"
TREE="${REPO_ROOT}/.orchestrator/milestones/${mid}"

if [ ! -d "$TREE" ]; then
  echo "cleanup-stale-results.sh: milestone tree not found: $TREE" >&2
  exit 1
fi

# Enumerate target files via find (no -exec into sh -c; AP-014 safe).
list_tmp="$(mktemp)"
find "$TREE" -type f -path '*/phases/*/tasks/*.txt' -print > "$list_tmp"

removed=0
while IFS= read -r f; do
  if [ -f "$f" ]; then
    rm -f -- "$f"
    removed=$((removed + 1))
  fi
done < "$list_tmp"
rm -f "$list_tmp"

# Residual count -- separate find pass after removal.
residual_tmp="$(mktemp)"
find "$TREE" -type f -path '*/phases/*/tasks/*.txt' -print > "$residual_tmp"
residual=$(wc -l < "$residual_tmp" | tr -d ' ')
rm -f "$residual_tmp"

printf 'REMOVED: %s\n' "$removed"
printf 'RESIDUAL: %s\n' "$residual"
echo "OK"
exit 0
```

5. **Validate wrapper-invocation shape** through the classifier — `bash scripts/util/cleanup-stale-results.sh M028` traced at plan-authoring time → `allow`.

6. **Author `scripts/verify/m028/p04-cleanup-stale-results.sh`** (~75 lines):

```bash
#!/usr/bin/env bash
# scripts/verify/m028/p04-cleanup-stale-results.sh -- M028 P04/T01 plan-level verifier
# for cleanup-stale-results.sh.
#
# Exercises the wrapper against an isolated tmp tree mirroring the
# .orchestrator/milestones/<MID>/phases/<PID>/tasks/ layout:
#   1. Happy path: 3 .txt files staged, wrapper removes all 3, RESIDUAL=0.
#   2. No-tree case: bogus milestone ID -> exit 2.
#   3. Empty-tree case: milestone exists but no .txt files -> REMOVED=0, exit 0.
#   4. Boundary refusal: invalid milestone ID -> exit 2.
#
# Uses an isolated REPO_ROOT (export an env override or run inside a tmp dir).
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
WRAPPER="${REPO_ROOT}/scripts/util/cleanup-stale-results.sh"

if [ ! -f "$WRAPPER" ]; then
  echo "FAIL: $WRAPPER not found" >&2
  exit 1
fi

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# Stage an isolated tree by setting up tmp/.orchestrator/milestones/MX99/phases/P01/tasks/*.txt
# Then run the wrapper against the real REPO_ROOT for the validation arms (case 4),
# and use a stub-mode override for the happy-path arms.

# Case 4: invalid milestone ID -> exit 2.
bash "$WRAPPER" "not-a-milestone" 2>/dev/null
rc=$?
if [ "$rc" -eq 2 ]; then pass "case4 exit 2 on invalid ID"; else fail "case4 exit" "rc=$rc"; fi

# Case 4b: usage (no args) -> exit 2.
bash "$WRAPPER" 2>/dev/null
rc=$?
if [ "$rc" -eq 2 ]; then pass "case4b exit 2 on no-args"; else fail "case4b exit" "rc=$rc"; fi

# Case 1 (happy path): stage isolated tree.
tmp_root="$(mktemp -d)"
mkdir -p "$tmp_root/.orchestrator/milestones/M999/phases/P01/tasks"
mkdir -p "$tmp_root/.orchestrator/milestones/M999/phases/P02/tasks"
printf 'stale1\n' > "$tmp_root/.orchestrator/milestones/M999/phases/P01/tasks/T01-result.txt"
printf 'stale2\n' > "$tmp_root/.orchestrator/milestones/M999/phases/P01/tasks/T02-result.txt"
printf 'stale3\n' > "$tmp_root/.orchestrator/milestones/M999/phases/P02/tasks/T01-result.txt"

# Stage a temp wrapper copy that points REPO_ROOT at $tmp_root via dirname inversion:
# cleanup-stale-results.sh resolves REPO_ROOT as "$(cd "$script_dir/../.." && pwd -P)",
# so we copy it into $tmp_root/scripts/util/ and invoke from there.
mkdir -p "$tmp_root/scripts/util"
cp "$WRAPPER" "$tmp_root/scripts/util/cleanup-stale-results.sh"

out="$(bash "$tmp_root/scripts/util/cleanup-stale-results.sh" M999)"
rc=$?
if [ "$rc" -eq 0 ]; then pass "case1 exit 0 on happy path"; else fail "case1 exit" "rc=$rc"; fi
echo "$out" | grep -q '^REMOVED: 3$' && pass "case1 REMOVED=3" || fail "case1 REMOVED" "got [$out]"
echo "$out" | grep -q '^RESIDUAL: 0$' && pass "case1 RESIDUAL=0" || fail "case1 RESIDUAL" "got [$out]"
echo "$out" | grep -q '^OK$' && pass "case1 OK terminator" || fail "case1 OK" "got [$out]"

# Case 3: empty tree (no .txt files).
mkdir -p "$tmp_root/.orchestrator/milestones/M998/phases/P01/tasks"
out2="$(bash "$tmp_root/scripts/util/cleanup-stale-results.sh" M998)"
rc=$?
if [ "$rc" -eq 0 ]; then pass "case3 exit 0 on empty"; else fail "case3 exit" "rc=$rc"; fi
echo "$out2" | grep -q '^REMOVED: 0$' && pass "case3 REMOVED=0" || fail "case3 REMOVED" "got [$out2]"

# Case 2: missing tree.
bash "$tmp_root/scripts/util/cleanup-stale-results.sh" M997 2>/dev/null
rc=$?
if [ "$rc" -eq 1 ]; then pass "case2 exit 1 on missing tree"; else fail "case2 exit" "rc=$rc"; fi

rm -rf "$tmp_root"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: p04-cleanup-stale-results.sh"
  exit 0
fi
echo "FAIL: p04-cleanup-stale-results.sh ($fail_count failures)"
exit 1
```

7. **Run both plan-level verifiers locally** before commit:

```bash
bash scripts/verify/m028/p04-grep-files.sh
```

```bash
bash scripts/verify/m028/p04-cleanup-stale-results.sh
```

8. **Commit** via `git commit -F <message-file>` per CLAUDE.md hotfix list.

## Must-Haves

This task addresses the phase Truths:

- "The four investigation-pattern wrappers exist under `scripts/util/` …" — T01 lands 2 of the 4 (grep-files.sh, cleanup-stale-results.sh).
- "`scripts/util/grep-files.sh <pattern> <file...>` greps each file …"
- "`scripts/util/cleanup-stale-results.sh <milestone>` removes per-step result files …"

The plan-level verifiers `p04-grep-files.sh` and `p04-cleanup-stale-results.sh` (T01 deliverables themselves) implement the assertion logic for the latter two truths.

## Verification

```bash
bash scripts/verify/m028/p04-grep-files.sh
```

```bash
bash scripts/verify/m028/p04-cleanup-stale-results.sh
```

## Inputs

### From Previous Tasks

None — T01 has no upstream task dependencies.

### From Disk (Pre-existing)

- `scripts/util/run-probe.sh` — sibling shape; T01 wrappers follow the same flat AD-19 single-script-file convention (set -u, structured exit codes, comment-block docstring).
- `scripts/util/read-range.sh` — sibling shape with explicit usage docstring + exit-code semantics; T01 wrappers mirror that shape.
- `scripts/verify/lib/shape-classifier.sh` — `classify_command` is the line-by-line classifier the plan-author traced wrapper-invocation lines through at plan-authoring time. The wrappers' *invocation* lines are agent-facing; their internal bodies are not.
- `scripts/verify/m028/p02-repair-fixture.sh` — pattern reference for "stage tmp tree + invoke wrapper from copied-in path" verifier shape; T01's `p04-cleanup-stale-results.sh` follows the same isolated-tmp-root pattern.

### Key API Surface

T01 wrappers are pure shell scripts with positional-arg interfaces:

- `grep-files.sh <pattern> <file...>` — returns 0 / 1 / 2 depending on match / no-match / usage; emits `--- <file> ---` separators per file plus grep output to stdout.
- `cleanup-stale-results.sh <milestone-id>` — returns 0 / 1 / 2; emits `REMOVED: <N>` / `RESIDUAL: <count>` / `OK` lines to stdout. Validates milestone ID against `M[0-9]+`.

No library sourcing, no upstream API surface to honor.

## Constraints

- **CON-1 (AD-19)**: Each wrapper is a flat single-file shape under `scripts/util/`. No nested helper dirs. No sourcing from outside `scripts/util/` or `scripts/verify/lib/`.
- **CON-2 (bash 3.2 + POSIX sh)**: All scripts use bash 3.2 grammar; no `mapfile`, no `<<<` here-strings, no process substitution, no `declare -A`, no associative arrays. The `case "$mid" in M[0-9]*) ... esac` form is bash 3.2-safe pattern matching.
- **CON-6 (no new runtime deps)**: Both wrappers use only `grep`, `find`, `rm`, `wc`, `tr`, `mkdir`, `cd`, `pwd`, `printf`, `echo`, plus standard bash builtins — no jq / node / python.
- **Boundary refusal (M028 spec Edge Cases)**: `cleanup-stale-results.sh` MUST refuse milestone IDs that don't match `M[0-9]+`. The refusal is the spec's blast-radius bound for Finding D.
- **Verification-section authoring**: Per the M028/P02 dogfood findings, the `## Verification` section invokes project-tree verifiers directly (`bash scripts/verify/m028/<name>.sh`); does NOT wrap with `run-probe.sh`. Expected output is documented in the `## Expected Output` section, not in the `## Verification` section's fenced blocks.
- **Plan-time verifier-availability**: Both `## Verification` checks resolve to scripts T01 itself authors (per the CLAUDE.md hotfix "Plan-time verifier-availability cross-check missing"). No cross-task verifier dependency.
- **Plan-time classifier-shape pre-validation**: Wrapper INVOCATION shapes traced through `classify_command` at plan-authoring time — `bash scripts/util/grep-files.sh foo file1.md file2.md` → `allow`; `bash scripts/util/cleanup-stale-results.sh M028` → `allow`. Recorded here as the verdict-of-record.
- **Commit-message form**: `git commit -F <file>`. Heredoc-with-expansion form is rejected by AP-008.

## Expected Output

After `bash scripts/verify/m028/p04-grep-files.sh`:

```
PASS: case1 exit 0 on any-match
PASS: case1 separator a
PASS: case1 separator b
PASS: case2 exit 1 on no-match
PASS: case3 exit 2 on usage
PASS: case4 exit 2 on missing file
PASS: p04-grep-files.sh
```

After `bash scripts/verify/m028/p04-cleanup-stale-results.sh`:

```
PASS: case4 exit 2 on invalid ID
PASS: case4b exit 2 on no-args
PASS: case1 exit 0 on happy path
PASS: case1 REMOVED=3
PASS: case1 RESIDUAL=0
PASS: case1 OK terminator
PASS: case3 exit 0 on empty
PASS: case3 REMOVED=0
PASS: case2 exit 1 on missing tree
PASS: p04-cleanup-stale-results.sh
```

## State Context

- **Current State**: executing
- **Milestone**: M028
- **Phase**: P04
- **Task**: T01-investigation-wrappers-A
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **CON-1 (AD-19)**: Each wrapper is a flat single-file shape under `scripts/util/`. No nested helper dirs. No sourcing from outside `scripts/util/` or `scripts/verify/lib/`.
- **CON-2 (bash 3.2 + POSIX sh)**: All scripts use bash 3.2 grammar; no `mapfile`, no `<<<` here-strings, no process substitution, no `declare -A`, no associative arrays. The `case "$mid" in M[0-9]*) ... esac` form is bash 3.2-safe pattern matching.
- **CON-6 (no new runtime deps)**: Both wrappers use only `grep`, `find`, `rm`, `wc`, `tr`, `mkdir`, `cd`, `pwd`, `printf`, `echo`, plus standard bash builtins — no jq / node / python.
- **Boundary refusal (M028 spec Edge Cases)**: `cleanup-stale-results.sh` MUST refuse milestone IDs that don't match `M[0-9]+`. The refusal is the spec's blast-radius bound for Finding D.
- **Verification-section authoring**: Per the M028/P02 dogfood findings, the `## Verification` section invokes project-tree verifiers directly (`bash scripts/verify/m028/<name>.sh`); does NOT wrap with `run-probe.sh`. Expected output is documented in the `## Expected Output` section, not in the `## Verification` section's fenced blocks.
- **Plan-time verifier-availability**: Both `## Verification` checks resolve to scripts T01 itself authors (per the CLAUDE.md hotfix "Plan-time verifier-availability cross-check missing"). No cross-task verifier dependency.
- **Plan-time classifier-shape pre-validation**: Wrapper INVOCATION shapes traced through `classify_command` at plan-authoring time — `bash scripts/util/grep-files.sh foo file1.md file2.md` → `allow`; `bash scripts/util/cleanup-stale-results.sh M028` → `allow`. Recorded here as the verdict-of-record.
- **Commit-message form**: `git commit -F <file>`. Heredoc-with-expansion form is rejected by AP-008.

### Acceptance Criteria

This task addresses the phase Truths:

- "The four investigation-pattern wrappers exist under `scripts/util/` …" — T01 lands 2 of the 4 (grep-files.sh, cleanup-stale-results.sh).
- "`scripts/util/grep-files.sh <pattern> <file...>` greps each file …"
- "`scripts/util/cleanup-stale-results.sh <milestone>` removes per-step result files …"

The plan-level verifiers `p04-grep-files.sh` and `p04-cleanup-stale-results.sh` (T01 deliverables themselves) implement the assertion logic for the latter two truths.

### Files To Touch

- scripts/util/grep-files.sh (create)
- scripts/util/cleanup-stale-results.sh (create)
- scripts/util/node-eval.sh (create)
- scripts/util/peek-files.sh (create)
- commands/dispatch.md (modify)
- templates/dispatch-prompt.md (modify)
- ANTIPATTERNS.md (modify)
- scripts/verify/m028/finding-D-verifier.sh (create)
- scripts/verify/m028/finding-E-verifier.sh (create)
- scripts/verify/m028/finding-G-wrapper-verifier.sh (create)
- scripts/verify/m028/run-all.sh (modify)
- scripts/verify/m028/p04-wrappers-present.sh (create)
- scripts/verify/m028/p04-grep-files.sh (create)
- scripts/verify/m028/p04-cleanup-stale-results.sh (create)
- scripts/verify/m028/p04-node-eval.sh (create)
- scripts/verify/m028/p04-peek-files.sh (create)
- scripts/verify/m028/p04-investigation-section.sh (create)
- scripts/verify/m028/p04-anti-pattern-lint-clean.sh (create)
- scripts/verify/m028/p04-finding-verifiers-present.sh (create)
- scripts/verify/m028/p04-run-all-clean.sh (create)

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