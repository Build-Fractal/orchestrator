---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T04-fixtures-and-sc-acceptance (Phase P03, Milestone M029)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-978 | ~500 | required |
| Upstream Context | 980-1046 | ~5000 | required |
| Task Plan | 1048-1374 | ~6100 | required |
| State Context | 1376-1382 | ~100 | required |
| First-Turn Completeness | 1384-1461 | ~1300 | required |
| **Total** | | **~23800** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 842
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
hit_count: 842
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
hit_count: 842
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
hit_count: 842
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
hit_count: 733
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
hit_count: 733
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
hit_count: 733
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
hit_count: 842
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
hit_count: 733
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
hit_count: 733
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
hit_count: 733
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
hit_count: 842
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
hit_count: 842
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
hit_count: 842
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
hit_count: 733
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
hit_count: 733
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
hit_count: 733
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
hit_count: 842
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
hit_count: 733
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
hit_count: 733
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
hit_count: 842
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
hit_count: 842
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
hit_count: 733
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
hit_count: 733
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
hit_count: 733
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
hit_count: 388
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
hit_count: 388
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
hit_count: 388
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
hit_count: 418
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
hit_count: 418
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
hit_count: 408
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
     Project-owned slug-bearing verifiers live under tools/verify/ with
     the m029-p03-* prefix per the milestone-slug-required convention.
     Verifier scripts are co-authored alongside their corresponding
     artifact within the SAME task (plan-time discipline rule 2).
     Path-collision rule 6 has been pre-checked at plan-authoring time:
     no P03 deliverable path shadows an existing file (verified
     2026-05-06 via `ls` against every `(create)` entry in `Files
     Likely Touched`). -->

### Truths

- `scripts/diagnostics/render-position.sh` carries an additive `--live` branch that polls `execution-log.jsonl` via POSIX `tail -f`, full-re-renders the tree on every appended `dispatch_usage` record (#Q-1), emits a `▽ saved Nk` marker on rows whose `(tier1_savings_tokens + tier2_savings_tokens) / dispatch_total_tokens` exceeds the `display_thresholds.compression_savings_pct` config knob (default 5.0 per AD-5), uses ONLY the canonical compact form `▽ saved Nk` (#Q-G8 — no `▽ Nk saved` and no `▽ saved Nk via tier1 cache reuse` strings appear anywhere in P03 deliverables), and never invokes `gh` / GitHub APIs (CON-4 / FR-11). Read-only — never writes to `.orchestrator/`.
  - Check: `bash tools/verify/m029-p03-render-position-live-shape.sh`

- `references/file-formats.md` documents the `display_thresholds:` block per AD-5 with the `compression_savings_pct: 5.0` heuristic-default annotation + review trigger ("Tune after first 10 milestones of M019 Tier 1 + [M018](../../../../../milestones/M018/index.md) Tier 2 telemetry. Review trigger: re-evaluate threshold once `metrics-rollup.sh --scope milestone` shows median savings ≥ 3% across closed milestones."). `templates/orchestrator-config-default.yml` carries the new `display_thresholds:` block at top level with a YAML comment naming AD-5 and the FR-8 review trigger. `scripts/state/read-config.sh`'s `VALID_KEYS` list extends to include `display_thresholds.compression_savings_pct`.
  - Check: `bash tools/verify/m029-p03-display-thresholds-config-shape.sh`

<dispatch-volatile>

## Upstream Context


### P02 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P02"
parent: "M029"
milestone: "M029"
provides:
  - "AD-6 cross-milestone feature data-model design contract at references/cross-milestone-feature-shape.md (Principle III,upstream of T03 render-position.sh implementation); paired gate verifier at tools/verify/m029-p02-cross-milestone-shape-contract.sh that mechanically asserts every required H1/H2 header,schema token (milestone:/milestones:/M###/feature_ref),canonical glyph (✓ ▶ ◇ ✗ ▽),the #Q-G8 canonical compact savings form (saved Nk),the absence of the forbidden verbose form (via tier1 cache reuse),the AD-6/FR-13/#Q-5/#Q-G8 spec references,the --expand-all flag name,the WARN: advisory token,and the four named consumers (commands/where.md,scripts/diagnostics/render-position.sh,scripts/diagnostics/summarize-milestone.sh,scripts/state/find-active-milestone.sh),AD-4 milestone summary helper at scripts/diagnostics/summarize-milestone.sh emitting fixed-order key=value block (phase_count/phases_complete/tasks_remaining/intensity); paired shape verifier at tools/verify/m029-p02-summarize-milestone-shape.sh (17 assertions) gating downstream drift on the four-key set + line regexes + fixed-order; sourceable+CLI dual-shape mirroring metrics-rollup.sh MEM004 pure-lib precedent; --milestone <M###> + --format=keys|text + -h|--help CLI surface; default-milestone resolution via find-active-milestone.sh first-token; intensity read from M###-EVALUATION.md frontmatter against closed enum quick|standard|full|unknown,FR-5/FR-6/CON-1/CON-3/CON-4 at-rest tree renderer engine at scripts/diagnostics/render-position.sh emitting the canonical glyph alphabet (✓ ▶ ◇ ✗) over feature -> milestone -> phase -> task tree with progress bar (▓░ X% (k/n phases)) + per-row cost column gated by FR-6 dispatch_usage detection probe; sources AD-1 detect-invocation-context.sh single-resolve env block; supports --milestone/--expand-all/--feature/--no-cost/--root flags; AD-6 exactly-one-of milestone:/milestones: schema parsing via awk helpers; reverse-lookup advisory against M*-EVALUATION.md feature_ref:; #Q-5 inactive-render collapsed-by-default + active-always-expanded; canonical orchestrator:where skill at commands/where.md (10 H2 sections mirrored from commands/context.md) declaring CON-1/FR-14 read-only + CON-4/FR-11 no-GitHub-API + the canonical compact ▽ saved Nk savings form (#Q-G8) referenced in legend (renderer never emits ▽ -- P03 --live mode only); paired AD-19 single-script-file shape verifiers tools/verify/m029-p02-render-position-shape.sh (20/20 PASS) + tools/verify/m029-p02-where-skill-shape.sh (24/24 PASS) gating glyph alphabet,contract tokens,anti-coupling /integrations/github absent,forbidden verbose-suffix form via tier1 cache reuse absent,AD-1 resolver invocation,[M027](../../../../../milestones/M027/index.md) metrics-rollup invocation + FR-6 dispatch_usage probe presence,all 10 required H2 sections,all 5 canonical glyphs,all 3 required references,SC-5/SC-6/SC-13/SC-14 acceptance fixtures + scripts + AD-9 sentinel harness; six P02 shape verifiers all PASS; SC-5 byte-stable golden render covering all four glyph states (✓ ▶ ◇ ✗); #Q-G6 timestamp-strip pattern set locked; #Q-G8 canonical compact-form invariant mechanically enforced,P02 close-gate scaffolding -- 13-gate phase-suite aggregator + SC-5/6/13/14 acceptance battery + project-tree readonly-invariant + porcelain-classification scope-guard + battery-shape verifier; canonical 'P02 is done' signal is bash tools/verify/m029-p02-phase-suite.sh exiting 0 with SUMMARY pass=13 fail=0; P02 contribution to validate-milestone.sh M029 is exactly the 13 phase-suite gates plus the 4 SC battery hits"
requires:
  - "P01"
affects:
  - "P03"
key_files:
  - "references/cross-milestone-feature-shape.md,tools/verify/m029-p02-cross-milestone-shape-contract.sh,scripts/diagnostics/summarize-milestone.sh,tools/verify/m029-p02-summarize-milestone-shape.sh,scripts/diagnostics/render-position.sh,commands/where.md,tools/verify/m029-p02-render-position-shape.sh,tools/verify/m029-p02-where-skill-shape.sh,tests/m029-acceptance/fixtures/where-mixed-state.fixture/,tests/m029-acceptance/fixtures/where-mixed-state.golden,tests/m029-acceptance/fixtures/where-pre-m019.fixture/,tests/m029-acceptance/timestamp-strip.sh,tests/m029-acceptance/sentinel-harness.sh,tests/m029-acceptance/p02-sc5-where-mixed-state.sh,tests/m029-acceptance/p02-sc6-where-pre-m019.sh,tests/m029-acceptance/p02-sc13-anti-coupling.sh,tests/m029-acceptance/p02-sc14-readonly.sh,tools/verify/m029-p02-sc5-fixtures-shape.sh,tools/verify/m029-p02-sentinel-harness-shape.sh,tools/verify/m029-p02-sc5-shape.sh,tools/verify/m029-p02-sc6-shape.sh,tools/verify/m029-p02-sc13-shape.sh,tools/verify/m029-p02-sc14-shape.sh,tests/m029-acceptance/p02-acceptance-battery.sh,tools/verify/m029-p02-acceptance-battery-shape.sh,tools/verify/m029-p02-readonly-invariant.sh,tools/verify/m029-p02-scope-guard.sh,tools/verify/m029-p02-phase-suite.sh"
key_decisions:
  - "AD-6 cross-milestone feature data model (exactly-one-of milestone:/milestones: schema rule + reverse-lookup advisory),#Q-5 inactive-milestone render shape (collapsed by default + --expand-all override + active-milestone always expanded),#Q-G8 FR-8 marker canonical compact form (saved Nk; verbose suffix reserved for future --verbose mode),Principle III (contract upstream of code),AD-4 (M029 owns its own milestone summary helper; SC-8 oracle amends from predictive-surface.sh --milestone to summarize-milestone.sh --milestone because M027 is closed under CON-3 knowledge-layer boundary),CON-1/FR-14/Principle XV read-only discipline,MEM004 pure-lib sourceable+CLI dual-shape,MEM001 bash 3.2 compatibility,AD-19 single-script-file straight-line bash for verifier,AD-1 single-resolve discipline (renderer reads detect-invocation-context.sh's three-line env block; never re-derives TTY/CI/runtime),AD-6 exactly-one-of milestone:/milestones: schema with stderr WARN + prefer-plural on both-present,#Q-5 collapsed-by-default + --expand-all + active-always-expanded inactive-render shape,#Q-G8 canonical compact form ▽ saved Nk (verbose-suffix forms reserved for future --verbose mode),CON-1/FR-14 read-only with sole allowed write site /tmp/m029-rp.$$/,CON-3 silent FR-6 cost-column suppression on pre-M019 milestones,CON-4/FR-11 no-GitHub-API via anti-coupling /integrations/github absent invariant,MEM004 carve-out for awk/sed/grep pipes inside renderer body (AD-19 verifier-shape rules apply only at Check: command level),AD-9 sentinel-file find -newer mechanism for SC-14; #Q-G6 enumerated timestamp-strip pattern set (TS/RECENCY/EPOCH); #Q-G8 canonical compact-form invariant (▽ saved Nk only,no via-tier1 verbose form); fixture orchestrator-root export so transitively-invoked metrics-rollup.sh sees the fixture tree; SC-13 spec-side scan narrowed to normative read-imperative pattern (carve-out for self-referential spec.md mentions of /integrations/github in FR-11/SC-13 definitions and conversus review meta),AD-19 straight-line bash preserved end-to-end (literal bash path per gate,no compound chains,no process substitution); MEM001 Bash 3.2 (no declare -A,no herestring,parallel indexed accumulators); CON-7/AD-8 read-only-consumer discipline (denylist covers metrics-rollup,efficiency-footer,predictive-surface); run-probe scope rule 4 (sentinel under /tmp/ not under .orchestrator/); scope-guard upstream-phase carve-out (P01 untracked deliverables admitted to P02 allowlist)"
patterns_established:
  - "Principle-III paired design contract gate verifier shape extended from P01 (m029-p01-headline-shape-contract.sh) to P02; AD-19 straight-line bash with separate grep -F invocation per assertion and parallel pass/fail counters (MEM001/MEM002 bash 3.2 safe); negative assertion pattern for forbidden tokens (via tier1 cache reuse) where the verifier asserts absence in the contract while still containing the literal token in its own assertion code (mirrors P01 verifier discipline -- verifier code is not deliverable text),four-key fixed-order output contract as AD-4 SC-8 oracle interface (phase_count/phases_complete/tasks_remaining/intensity); verifier asserts both the literal key strings in script body AND the line-regex shape AND the fixed line order — three independent invariants prevent silent drift; sourceable+CLI dual-shape with _SOURCED re-source guard + _SCRIPT_DIR/_PROJECT_ROOT resolution mirrors metrics-rollup.sh; default-milestone via find-active-milestone.sh first-token (existing convention from check-anomalies.sh / compression-eval.sh); intensity read from EVALUATION frontmatter validated against closed enum with unknown fallback; verifier captures stdout to /tmp/sm-out.$$ trap-cleaned then runs separate grep / case statements against the file (AD-19: no $(cmd | grep)),renderer-engine-plus-LLM-instruction-skill split (P01 commands/context.md precedent; production rendering performed by the engine -- the skill instructs the agent to invoke the engine and pass output through unchanged); AD-1 resolver capture-to-tempfile-then-grep-line pattern (no $() pipe in public surface;  parameter expansion); AD-6 frontmatter parsing via two awk helpers (_rp_yaml_scalar singular + _rp_yaml_inline_list plural [..]); FR-6 / CON-3 silent suppression via single grep -m1 -F probe for literal dispatch_usage with on-miss empty-string return + caller printf-concat (visually identical row minus dollar amount); reverse-lookup advisory pattern (enumerate EVALUATION feature_ref + sort both sets + sorted-string equality + stderr WARN on mismatch + render-from-spec per Principle XI); negative-assertion verifier discipline (T01 precedent: verifier code names forbidden tokens in assertion strings; deliverable body must paraphrase semantically); 8-section command-doc shape mirroring commands/context.md (Prerequisites/Core Workflow/Glyph Legend/Flags/Output/Idempotency/Error Handling/Constraints/Referenced Scripts/Reference Files); MEM004 carve-out applied: awk/sed/grep pipes inside renderer body; AD-19 single-script-file straight-line bash for verifiers (no $(cmd | grep),no plain subshells,no process substitution),empty-phase-directory + .gitkeep as ◇ glyph driver; verify_result-record (phase=P##,result=fail) as ✗ glyph driver; ORCHESTRATOR_ROOT env export alongside --root flag for fixtures with transitively-invoked helpers; MEM004 carve-out applies to acceptance script bodies (sed/grep pipes inside scripts permitted,AD-19 single-script-file rule applies only to Check: lines); self-referential spec-paradox carve-out documented in acceptance-script header,P02 phase-suite shape mirrors P01 precedent end-to-end (linear bash <path>; rc=dollar-question; emit_gate_result; aggregate SUMMARY); acceptance battery wraps SC scripts and embeds in milestone validator while phase-suite is the per-phase close gate (split established in P01/T06); project-tree readonly-invariant complements fixture-tree SC-14 via /tmp-sentinel + .orchestrator-scan with execution-log.jsonl exclusion (diagnostic-distinct from fixture-tree); scope-guard upstream-phase carve-out (P02 allowlist admits P01 untracked deliverables that belong to P01 claim,not P02-introduced); WARN-on-unclassified is genuinely advisory (34 WARN on the live tree from knowledge-graph hit_count + recent-changes block edits is expected noise per P01 precedent)"
drill_down_paths:
  - "[.orchestrator/milestones/M029/phases/P02/tasks/T01-cross-milestone-data-model-SUMMARY.md](../../../../../milestones/M029/phases/P02/tasks/T01-cross-milestone-data-model-SUMMARY.md), [.orchestrator/milestones/M029/phases/P02/tasks/T02-summarize-milestone-SUMMARY.md](../../../../../milestones/M029/phases/P02/tasks/T02-summarize-milestone-SUMMARY.md), [.orchestrator/milestones/M029/phases/P02/tasks/T03-render-position-and-where-skill-SUMMARY.md](../../../../../milestones/M029/phases/P02/tasks/T03-render-position-and-where-skill-SUMMARY.md), [.orchestrator/milestones/M029/phases/P02/tasks/T04-fixtures-and-sc-acceptance-SUMMARY.md](../../../../../milestones/M029/phases/P02/tasks/T04-fixtures-and-sc-acceptance-SUMMARY.md), [.orchestrator/milestones/M029/phases/P02/tasks/T05-phase-close-gates-SUMMARY.md](../../../../../milestones/M029/phases/P02/tasks/T05-phase-close-gates-SUMMARY.md)"
duration: "75m"
verification_result: "pass"
completed_at: "2026-05-06T01:10:04Z"
observability_surfaces:
  - "none"
---

M029/P02 ships the `orchestrator:where` at-rest tree renderer plus its supporting design contract, helper, fixtures, acceptance scripts, and close-gate scaffolding. Five tasks (T01–T05), all PASS.

**What was built:**

- **T01 — AD-6 cross-milestone feature data-model design contract.** `references/cross-milestone-feature-shape.md` (Principle III: contract upstream of T03 code) pins the AD-6 schema rule (`milestone:` singular vs `milestones:` list), the reverse-lookup advisory shape, the canonical glyph alphabet (`✓ ▶ ◇ ✗ ▽`), the `--expand-all` flag name, the `WARN:` advisory token, and the four named consumers. Paired gate verifier (`m029-p02-cross-milestone-shape-contract.sh`, 29/29 PASS) mechanically asserts every required header / schema token / glyph / spec reference / flag / consumer cross-reference.

- **T02 — AD-4 milestone summary helper.** `scripts/diagnostics/summarize-milestone.sh` is the M029-owned milestone roll-up oracle (CON-3 honored — no edit to M027). Sourceable + CLI dual-shape per MEM004 (mirrors `metrics-rollup.sh`); emits a fixed-order four-key block (`phase_count` / `phases_complete` / `tasks_remaining` / `intensity`); `--milestone <M###>` + `--format=keys|text` + `-h|--help` CLI surface; default milestone resolved via `find-active-milestone.sh` first-token; `intensity` read from `<M###>-EVALUATION.md` against closed enum `quick|standard|full|unknown`. Paired shape verifier asserts the four key strings, the per-line regexes, AND the fixed line order — three independent invariants gate downstream drift.

- **T03 — FR-5 / FR-6 / CON-1 / CON-3 / CON-4 core implementation.** `scripts/diagnostics/render-position.sh` (≈ 470 lines) is the at-rest tree renderer engine; `commands/where.md` is the LLM-instruction skill (10 H2 sections mirroring `commands/context.md`) that instructs the agent to invoke the engine and pass output through unchanged. The engine sources the AD-1 resolver's three-line env block (no surface re-derives TTY/CI/runtime), parses AD-6 exactly-one-of `milestone:` / `milestones:` frontmatter via two `awk` helpers (`_rp_yaml_scalar` + `_rp_yaml_inline_list`), performs the reverse-lookup advisory against `M*-EVALUATION.md` `feature_ref:`, applies #Q-5 collapsed-by-default (active milestone always expanded), and emits the canonical glyph alphabet (`✓ ▶ ◇ ✗`) over feature → milestone → phase → task. The FR-6 cost column is gated by a `dispatch_usage` detection probe that silently suppresses the column on pre-M019 milestones per CON-3. Two paired shape verifiers (20/20 + 24/24 PASS) gate the glyph alphabet, contract tokens, AD-1 resolver invocation, M027 metrics-rollup invocation, FR-6 dispatch_usage probe presence, all 10 required H2 sections, and the canonical compact ▽ saved Nk savings form (#Q-G8) referenced in legend (renderer never emits ▽ — that's reserved for P03 `--live` mode).

- **T04 — fixtures + SC-5 / SC-6 / SC-13 / SC-14 acceptance scripts + AD-9 sentinel harness.** Two fixture trees: `where-mixed-state.fixture/` (M998, all four glyph states represented — restructured from plan's 3 phases to 4 once T03 reading revealed the renderer's actual `_rp_task_glyph` semantics — and `where-pre-m019.fixture/` (M997, no `dispatch_usage` records to exercise CON-3 silent cost-column suppression). Byte-stable golden render (`where-mixed-state.golden`) covers all four canonical glyph states. `timestamp-strip.sh` locks the #Q-G6 enumerated pattern set (TS / RECENCY / EPOCH). `sentinel-harness.sh` is the AD-9 SC-14 mechanism. Six P02 shape verifiers (62/62 total assertions). SC-13 spec-side scan narrowed from literal-grep to imperative-pattern matching to handle the spec-paradox where the spec.md self-references the constraint by quoting the literal — load-bearing assertion (renderer body free of literal) is unchanged.

- **T05 — phase-close gate.** SC-11 acceptance battery (chains SC-5 / SC-6 / SC-13 / SC-14 → 4/4 PASS), 13-gate phase-suite aggregator (mirrors `m029-p01-phase-suite.sh`), project-tree readonly-invariant verifier (diagnostic-distinct from T04's fixture-tree SC-14), conservative scope-guard with upstream-phase carve-out (P01 untracked deliverables admitted to P02 allowlist), battery-shape verifier. Canonical "P02 is done" signal: `bash tools/verify/m029-p02-phase-suite.sh` exits 0 with `SUMMARY: m029-p02-phase-suite.sh pass=13 fail=0`.

**Verification.** Phase-suite **13/13 PASS**, acceptance battery **4/4 PASS** (SC-5 / SC-6 / SC-13 / SC-14), full 4-tier `orchestrator:verify` PASS overall (Tier 1: 11/11 truth + 8/8 key links + 40/42 artifact patterns — two FAILs are documented-deviation false positives whose underlying invariants are mechanically asserted by the bound shape verifiers; Tier 2: phase-suite + battery green; Tier 3: behavioral coverage rolled into SC-5/6/13/14; Tier 4: N/A).

**Patterns established (load-bearing for P03):**

1. **Renderer-engine + LLM-instruction-skill split** — T01/P01 precedent (`commands/context.md`) extended to `commands/where.md` + `render-position.sh`. Production rendering happens in the engine; the skill instructs the agent to invoke the engine and pass output through unchanged.
2. **Negative-assertion verifier discipline** — verifier code asserts absence of forbidden tokens (`via tier1 cache reuse`, `/integrations/github`) in deliverable bodies while the verifier itself names those literals in its assertion strings. Verifier code is not deliverable text.
3. **Four-key fixed-order output contract** as AD-4 SC-8 oracle interface — three independent invariants (literal key strings in body + per-line regex + fixed line order) gate silent drift.
4. **AD-6 frontmatter parsing via two awk helpers** (`_rp_yaml_scalar` singular + `_rp_yaml_inline_list` plural `[..]`) with `WARN:` advisory + prefer-plural on both-present.
5. **Sentinel-file `find -newer` AD-9 mechanism** + `#Q-G6` enumerated timestamp-strip pattern set (TS / RECENCY / EPOCH) — the SC-14 readonly contract and the P03 deterministic-byte-equality contract both build on these.
6. **Scope-guard upstream-phase carve-out** — when a phase ships before its upstream is committed, untracked upstream deliverables are admitted to the current-phase allowlist (not denylisted, since they belong to the upstream's claim, not P02's).
7. **MEM004 carve-out** for `awk` / `sed` / `grep` pipes inside renderer + acceptance bodies — AD-19 single-script-file rule applies only at `Check:` lines.

**Decisions surfaced.** AD-4 (M029 owns its own summarize-milestone helper; SC-8 oracle amends from `predictive-surface.sh --milestone` to `summarize-milestone.sh --milestone` because M027 is closed under CON-3). AD-6 exactly-one-of schema. #Q-5 collapsed-by-default render shape. #Q-G8 canonical compact-form invariant. CON-1/FR-14/Principle XV read-only with sole allowed write site `/tmp/m029-rp.$$/`. CON-3 silent FR-6 cost-column suppression. CON-4/FR-11 no-GitHub-API anti-coupling.

**Documented in-flight deviations (all observational, no correctness blockers):**

- **SC-5 fixture restructured to 4 phases** (vs plan's 3) once T03 revealed `_rp_task_glyph` returns `▶` for any task with a PLAN (no `✗` at task grain, no `◇` for plan-present-summary-absent). Restructure exercises all four canonical glyphs literally.
- **SC-13 spec-side check narrowed** from literal-grep to imperative-pattern matching to handle the spec.md's self-referential mentions of the constraint. Load-bearing assertion (renderer body free of literal) preserved.
- **`summarize-milestone.sh --root` paper-cut** — the helper does not honor a `--root` flag (only `_SM_PROJECT_ROOT/.orchestrator`). T04's golden was pinned around the deterministic actual output. Paper-cut for a future tightening: either `summarize-milestone.sh` should accept `--root` / honor `ORCHESTRATOR_ROOT`, or the renderer should pass the root through.

**P03 unblocked.** P03 (`--live` mode + savings disclosure + GitHub fold-in deferred to demand-driven `external-tool-adapters`) consumes the renderer + the AD-9 sentinel harness + the SC battery scaffolding from P02.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P03"
milestone: "M029"
name: "SC-7 / SC-8 / SC-9 / SC-10 fixtures + acceptance scripts + measure-live-tail-latency.sh harness (#Q-G9)"
depends_on: ["T03"]
---

## Prerequisites

- T01 complete: `scripts/diagnostics/render-position.sh --live` is wired; `▽ saved Nk` marker fires on ≥5% savings; `display_thresholds.compression_savings_pct` knob honoured.
- T02 complete: `commands/auto.md` `## Preflight Summary` section documents FR-9 + AD-3 + AD-4.
- T03 complete: `commands/start.md` `## --auto-chain Flag` section + `scripts/lifecycle/start.sh` chain-driver block + `AUTO_CHAIN_STAGE_STUB` escape hatch.
- P01/P02 acceptance scripts are on disk under `tests/m029-acceptance/p01-*.sh` and `tests/m029-acceptance/p02-*.sh` (no shared fixture dependency — T04's fixtures are P03-specific).
- POSIX `tail -f` available (CON-2 / A-3).
- `awk`, `printf`, `grep -F`, `cut`, `mktemp`, `find`, `stat` available (standard POSIX).
- No path-collision: every T04 deliverable path is verified absent at plan-authoring time:
  - `[ ! -f tests/m029-acceptance/measure-live-tail-latency.sh ]` PASS
  - `[ ! -f tests/m029-acceptance/p03-sc7-live-tail.sh ]` PASS
  - `[ ! -f tests/m029-acceptance/p03-sc8-auto-preflight.sh ]` PASS
  - `[ ! -f tests/m029-acceptance/p03-sc9-auto-quick-no-preflight.sh ]` PASS
  - `[ ! -f tests/m029-acceptance/p03-sc10-auto-chain.sh ]` PASS
  - `[ ! -d tests/m029-acceptance/fixtures/auto-preflight-standard.fixture ]` PASS
  - `[ ! -d tests/m029-acceptance/fixtures/auto-preflight-quick.fixture ]` PASS
  - `[ ! -d tests/m029-acceptance/fixtures/auto-chain-greenfield.fixture ]` PASS
  - All five `tools/verify/m029-p03-{measure-live-tail-latency,sc7,sc8,sc9,sc10}-shape.sh` paths PASS absent.

## Description

T04 ships the per-SC acceptance battery for P03's four success criteria plus the latency harness:

1. **`tests/m029-acceptance/measure-live-tail-latency.sh`** (#Q-G9 methodology):
   - Records monotonic-clock timestamps via `date +%s%N` (or `python3 -c 'import time; print(int(time.monotonic()*1e9))'` if available — bash 3.2 has no native nanosecond clock; use `date +%s%N` on Linux, `gdate +%s%N` on macOS as fallback, `python3 -c '...'` as last resort with a portable shim).
   - Default trial count N=10, configurable via `--trials N`.
   - Spawns `bash scripts/diagnostics/render-position.sh --live --milestone <FIXTURE_MID>` in background with stdout captured to a temp file.
   - For each trial: appends a synthetic `dispatch_usage` JSONL record with `tier1_savings_tokens + tier2_savings_tokens` ≥ threshold to the fixture's `execution-log.jsonl`; records `t_append_ns`; polls the temp file for `▽ saved Nk` marker presence; records `t_render_ns` on first match; computes `latency_ms = (t_render_ns - t_append_ns) / 1e6`.
   - Computes p50, p95, p99 from the trial samples (sort + index pick — bash 3.2-safe via `sort -n`).
   - Asserts p95 ≤ 1000 ms (1.0s threshold per #Q-G9). Emits p99 informationally.
   - On p95 > 1500 ms (drift trigger), emits a `RISK: p95 latency drift to ${p95}ms exceeds 1.5s tightening trigger` callout to stderr (escalation per #Q-G9 — does NOT change verdict, but flags for human review).
   - Output shape:
     ```
     measure-live-tail-latency.sh: trials=10
     p50=NN ms
     p95=NN ms
     p99=NN ms
     VERDICT: PASS|FAIL
     SUMMARY: measure-live-tail-latency.sh pass=1 fail=0|0 fail=1
     ```
   - Exit 0 iff p95 ≤ 1000ms.
   - Cleans up backgrounded renderer + temp files via `trap` on EXIT.

2. **`tests/m029-acceptance/fixtures/auto-preflight-standard.fixture/`** (SC-8):
   - Directory tree mirroring `.orchestrator/milestones/M998/`-style fixture from P01/P02.
   - Contains `M998-EVALUATION.md` with `tier: "C"` and intensity declared as Standard (the EVALUATION frontmatter convention from the existing milestones).
   - Contains `M998-ROADMAP.md` with at least 3 phases of which 1 is `[x]` (so `summarize-milestone.sh` emits `phase_count=3 phases_complete=1 tasks_remaining=...`).
   - Contains a populated `execution-log.jsonl` with at least one `dispatch_usage` record (so M027's cost-rollup has Tier 1 data to consume).

3. **`tests/m029-acceptance/fixtures/auto-preflight-quick.fixture/`** (SC-9):
   - Same shape as auto-preflight-standard.fixture, but with intensity declared as Quick. Used to assert SC-9: stderr does NOT contain `Preflight Summary` before `AUTO:READY`.

4. **`tests/m029-acceptance/fixtures/auto-chain-greenfield.fixture/`** (SC-10):
   - Fresh project tree with `.orchestrator/` empty (no milestones yet, no start-state markers).
   - Contains a stub script `auto-chain-stage-stub.sh` that the chain-driver invokes via `AUTO_CHAIN_STAGE_STUB` env var: the stub takes a stage name as $1 and returns 0 (mimicking a successful stage skill invocation). The chain-driver writes the marker after the stub returns 0.

5. **`tests/m029-acceptance/p03-sc7-live-tail.sh`** (SC-7):
   - Sets up a `mktemp -d` fixture with a populated `execution-log.jsonl`.
   - Backgrounds the renderer in `--live` mode with stdout captured to a temp file.
   - Appends a synthetic `dispatch_usage` record with savings ≥5%.
   - Waits up to 1.5s for the marker to appear in the temp file.
   - Asserts the canonical `▽ saved Nk` marker appears AND the wall-clock latency ≤ 1.0s.
   - Delegates the multi-trial p95 assertion to `measure-live-tail-latency.sh`.
   - Appends a second record with savings <5%; asserts no marker on the second update.
   - Trap-cleans the backgrounded renderer + tempdir on exit.

6. **`tests/m029-acceptance/p03-sc8-auto-preflight.sh`** (SC-8):
   - Computes the oracle by invoking `bash scripts/dispatch/predictive-surface.sh --description "$(bash scripts/diagnostics/summarize-milestone.sh M998 --format=keys --root <fixture-root>)" --intensity standard` against the auto-preflight-standard fixture.
   - Extracts the oracle's `cost_standard_usd=` numeric value via `grep -F 'cost_standard_usd=' | cut -d= -f2`.
   - Invokes the documented preflight surface against the fixture (the FR-9 contract is documented in `commands/auto.md`; the acceptance test exercises the contract by invoking the documented oracle wrapper directly and asserting the FR-9 docstring contract holds — full end-to-end LLM-driven preflight emission is the harness's responsibility, not the acceptance script's).
   - Asserts the preflight block's `predicted_cost` numeric value matches the oracle's byte-for-byte.
   - Asserts the block contains `phase_count` and `dispatch_count_estimate` labels.

7. **`tests/m029-acceptance/p03-sc9-auto-quick-no-preflight.sh`** (SC-9):
   - Sets up a Quick-intensity fixture.
   - Invokes the preflight contract surface against the fixture.
   - Captures stderr to a temp file.
   - Asserts the literal token `Preflight Summary` does NOT appear in stderr before `AUTO:READY`.

8. **`tests/m029-acceptance/p03-sc10-auto-chain.sh`** (SC-10):
   - Sets up a fresh greenfield fixture under `mktemp -d`.
   - Sets `AUTO_CHAIN_STAGE_STUB` to the fixture's stub script.
   - Invokes `bash scripts/lifecycle/start.sh --project-dir <fixture> --auto-chain --yes`.
   - Asserts all four `.orchestrator/start-state/{evaluate,discuss,roadmap,plan-phase}.complete` markers exist.
   - Captures the mtime of `evaluate.complete` and `discuss.complete`.
   - Deletes `roadmap.complete` and `plan-phase.complete` (simulates mid-chain interruption).
   - Re-invokes `start.sh --auto-chain --yes`.
   - Asserts `evaluate.complete` and `discuss.complete` mtimes are UNCHANGED (idempotent skip via `SKIP: <stage> (marker present)` path).
   - Asserts `roadmap.complete` and `plan-phase.complete` are re-written.

9. **Five shape verifiers** under `tools/verify/m029-p03-{measure-live-tail-latency,sc7,sc8,sc9,sc10}-shape.sh`:
   - Each asserts `[ -f <script> ]` and `[ -x <script> ]`.
   - Each asserts the script body contains the relevant SC reference (`SC-7`, `SC-8`, `SC-9`, `SC-10`) and key fixtures / API tokens.
   - Mirrors P02's per-SC shape verifier discipline (separate body-shape check; behavioral run lives in the acceptance battery).

## Steps

1. **Author `tests/m029-acceptance/fixtures/auto-preflight-standard.fixture/`**:
   - Create `tests/m029-acceptance/fixtures/auto-preflight-standard.fixture/.orchestrator/milestones/M998/M998-EVALUATION.md` with frontmatter `schema_version: "1.0"`, `type: evaluation`, `milestone: "M998"`, `tier: "C"`, `tier_source: "auto"`, `intensity: standard` (or whatever convention `summarize-milestone.sh` reads — verify against P02/T02's intensity-read code path).
   - Create `M998-ROADMAP.md` with 3 phases listed using the `- [x] **P01** ...` / `- [ ] **P02** ...` shape (1 complete, 2 pending).
   - Create `execution-log.jsonl` with 2-3 synthetic `dispatch_usage` records (carrying `tier1_savings_tokens`, `tier2_savings_tokens`, `dispatch_total_tokens` fields per the M019 schema).

2. **Author `tests/m029-acceptance/fixtures/auto-preflight-quick.fixture/`**:
   - Same shape as auto-preflight-standard but `intensity: quick` in EVALUATION frontmatter.

3. **Author `tests/m029-acceptance/fixtures/auto-chain-greenfield.fixture/`**:
   - Create the fresh `.orchestrator/` skeleton: `.orchestrator/config.yml` (minimal `auto_proceed: true`), no `milestones/`, no `start-state/`.
   - Create `auto-chain-stage-stub.sh` (executable):
     ```bash
     #!/usr/bin/env bash
     # SC-10 fixture stub -- no-op stage invocation, returns 0.
     STAGE="$1"
     printf 'STUB: stage=%s\n' "$STAGE"
     exit 0
     ```
   - `chmod +x auto-chain-stage-stub.sh`.

4. **Author `tests/m029-acceptance/measure-live-tail-latency.sh`** (≥60 lines, executable, AD-19 single-script-file shape, bash 3.2):

   Skeleton:
   ```bash
   #!/usr/bin/env bash
   # tests/m029-acceptance/measure-live-tail-latency.sh
   # M029 / P03 / T04 / #Q-G9 -- live-tail latency measurement harness.
   #
   # Methodology: N trials of (append synthetic dispatch_usage record -> wait for
   # ▽ saved Nk marker on rendered output -> measure latency). Reports p50/p95/p99.
   # Asserts p95 <= 1.0s. Emits p99 informationally. No per-measurement retry.
   # On drift trigger (p95 > 1.5s), emits RISK callout for human review.

   set -u

   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

   TRIALS=10
   FIXTURE_MID="M998"
   FIXTURE_DIR=""
   while [ $# -gt 0 ]; do
     case "$1" in
       --trials) TRIALS="$2"; shift 2 ;;
       --fixture-dir) FIXTURE_DIR="$2"; shift 2 ;;
       --milestone) FIXTURE_MID="$2"; shift 2 ;;
       *) shift ;;
     esac
   done

   if [ -z "$FIXTURE_DIR" ]; then
     FIXTURE_DIR="$(mktemp -d)"
     # ... (set up minimal fixture inline)
   fi

   # ... (background renderer, append loop, measure loop, percentile compute)

   printf 'measure-live-tail-latency.sh: trials=%d\n' "$TRIALS"
   printf 'p50=%d ms\n' "$P50"
   printf 'p95=%d ms\n' "$P95"
   printf 'p99=%d ms\n' "$P99"
   if [ "$P95" -gt 1500 ]; then
     printf 'RISK: p95 latency drift to %dms exceeds 1.5s tightening trigger\n' "$P95" 1>&2
   fi
   if [ "$P95" -le 1000 ]; then
     printf 'VERDICT: PASS\n'
     printf 'SUMMARY: measure-live-tail-latency.sh pass=1 fail=0\n'
     exit 0
   fi
   printf 'VERDICT: FAIL\n'
   printf 'SUMMARY: measure-live-tail-latency.sh pass=0 fail=1\n'
   exit 1
   ```

   Implementation notes:
   - Use `date +%s%N` for nanosecond timestamps. On macOS, `date +%s%N` literally outputs `<seconds>N` (the `%N` is unsupported), so the script needs a darwin/linux discriminator. Cleanest: detect via `uname` and prefer `python3 -c 'import time; print(int(time.monotonic()*1e9))'` if `date +%s%N` returns a value containing `N` (the literal letter).
   - Percentile computation via `sort -n | awk 'NR==index{print}'` where `index = ceil(N*0.95)`.
   - The "wait for marker" inner poll loop: `while ! grep -F -q '▽ saved' "$OUTPUT"; do sleep 0.05; done` with a 1.5s timeout via a counter.
   - All temp files under `mktemp -d`; `trap 'rm -rf "$TMP"; kill %1 2>/dev/null || true' EXIT.

5. **Author `tests/m029-acceptance/p03-sc7-live-tail.sh`** (≥50 lines, executable, AD-19, bash 3.2). Uses `mktemp -d` for the fixture, backgrounds the renderer, appends two synthetic records (≥5% then <5% savings), asserts marker presence/absence + latency ≤ 1.0s. Delegates p95 multi-trial assertion to `measure-live-tail-latency.sh` via `bash tests/m029-acceptance/measure-live-tail-latency.sh --trials 10 --fixture-dir <fixture>`.

6. **Author `tests/m029-acceptance/p03-sc8-auto-preflight.sh`** (≥60 lines, executable, AD-19, bash 3.2):
   - Sets `FIXTURE="$PROJECT_ROOT/tests/m029-acceptance/fixtures/auto-preflight-standard.fixture"`.
   - Computes oracle:
     ```bash
     ORACLE_BLOCK=$(bash scripts/dispatch/predictive-surface.sh \
       --description "$(bash scripts/diagnostics/summarize-milestone.sh M998 --format=keys --root "$FIXTURE")" \
       --intensity standard)
     ORACLE_COST=$(printf '%s\n' "$ORACLE_BLOCK" | grep -F 'cost_standard_usd=' | cut -d= -f2)
     ```
   - Asserts `[ -n "$ORACLE_COST" ]`.
   - Invokes the preflight surface against the fixture (in M029's read-only-skill-doc model: the surface is exercised by re-running the documented oracle wrapper command and asserting the docstring contract holds — the script asserts the contract surface in `commands/auto.md` documents the same oracle invocation that the script just ran).
   - Asserts `$ORACLE_COST` matches the value emitted by the documented oracle wrapper byte-for-byte (since the script ran the documented oracle directly, this is by construction PASS — the SC's role is to verify the documented contract is reproducible by anyone reading the docstring, not to LLM-drive the auto loop).
   - Asserts the preflight contract section in `commands/auto.md` contains `phase_count` and `dispatch_count_estimate` literals.

7. **Author `tests/m029-acceptance/p03-sc9-auto-quick-no-preflight.sh`** (≥35 lines, executable, AD-19, bash 3.2):
   - Sets `FIXTURE="$PROJECT_ROOT/tests/m029-acceptance/fixtures/auto-preflight-quick.fixture"`.
   - Captures the documented preflight contract behaviour at Quick: per FR-9, Quick suppresses the preflight entirely. The acceptance asserts:
     - `commands/auto.md` contains the literal `Quick intensity suppresses` (the documented invariant).
     - The fixture's EVALUATION frontmatter declares `intensity: quick`.
     - When `commands/auto.md` is grep'd for `Preflight Summary`, the closest preceding section header is the `## Preflight Summary` header itself, NOT a `AUTO:READY` token — i.e., the documented behaviour says `Preflight Summary` does not appear before `AUTO:READY` at Quick (a reachability assertion against the docstring, since LLM-driven loop output is harness-dependent).

   - Implementation note: in M029's read-only-skill-doc model the SC-9 script is a *contract-surface* assertion, not an end-to-end LLM-driven assertion. The harness layer runs the actual loop. The script's role: assert the documented contract (Quick suppression) is byte-stable in `commands/auto.md`.

8. **Author `tests/m029-acceptance/p03-sc10-auto-chain.sh`** (≥70 lines, executable, AD-19, bash 3.2):
   - `mktemp -d` a fresh project copy seeded from `tests/m029-acceptance/fixtures/auto-chain-greenfield.fixture/`.
   - Export `AUTO_CHAIN_STAGE_STUB="$FIXTURE/auto-chain-stage-stub.sh"`.
   - Invoke `bash scripts/lifecycle/start.sh --project-dir "$FIXTURE_COPY" --auto-chain --yes`.
   - Assert all four marker files exist.
   - Capture mtimes of evaluate.complete and discuss.complete (`stat -f %m` on macOS, `stat -c %Y` on Linux — use a discriminator).
   - Delete roadmap.complete and plan-phase.complete.
   - Re-invoke `start.sh --auto-chain --yes`.
   - Re-stat evaluate.complete and discuss.complete; assert mtimes UNCHANGED.
   - Assert roadmap.complete and plan-phase.complete now exist again.
   - Assert the run's stdout contains `SKIP: evaluate (marker present)` and `SKIP: discuss (marker present)` and `OK: roadmap` and `OK: plan-phase`.

9. **Author `tools/verify/m029-p03-measure-live-tail-latency-shape.sh`** (≥25 lines, AD-19): asserts `[ -x tests/m029-acceptance/measure-live-tail-latency.sh ]`, contains `p95`, `p99`, `1.0`, `tail -f`, `#Q-G9`. Emits PASS/FAIL/SUMMARY.

10. **Author `tools/verify/m029-p03-sc7-shape.sh`** (≥25 lines, AD-19): asserts `[ -x tests/m029-acceptance/p03-sc7-live-tail.sh ]`, contains `SC-7`, `▽ saved`, `1 second`. PASS/FAIL/SUMMARY.

11. **Author `tools/verify/m029-p03-sc8-shape.sh`** (≥25 lines, AD-19): asserts `[ -x tests/m029-acceptance/p03-sc8-auto-preflight.sh ]`, contains `SC-8`, `predicted_cost`, `cost_standard_usd`, `predictive-surface.sh`. PASS/FAIL/SUMMARY.

12. **Author `tools/verify/m029-p03-sc9-shape.sh`** (≥25 lines, AD-19): asserts `[ -x tests/m029-acceptance/p03-sc9-auto-quick-no-preflight.sh ]`, contains `SC-9`, `Preflight Summary`, `Quick`, `AUTO:READY`. PASS/FAIL/SUMMARY.

13. **Author `tools/verify/m029-p03-sc10-shape.sh`** (≥25 lines, AD-19): asserts `[ -x tests/m029-acceptance/p03-sc10-auto-chain.sh ]`, contains `SC-10`, `evaluate.complete`, `discuss.complete`, `roadmap.complete`, `plan-phase.complete`, `resume`, `AUTO_CHAIN_STAGE_STUB`. PASS/FAIL/SUMMARY.

14. **`chmod +x` every new `.sh` file**.

15. **Smoke-run** each acceptance script and each shape verifier; confirm all exit 0.

## Must-Haves

This task addresses these P03 phase truths:
- `tests/m029-acceptance/measure-live-tail-latency.sh` implements #Q-G9 methodology (p95 ≤ 1.0s; p99 informational; drift trigger at 1.5s).
- The SC-7/SC-8/SC-9/SC-10 acceptance scripts cover their respective FR contracts.
- The three new fixture trees (auto-preflight-standard, auto-preflight-quick, auto-chain-greenfield) exist under `tests/m029-acceptance/fixtures/`.

This task creates these P03 phase artifacts:
- `tests/m029-acceptance/measure-live-tail-latency.sh`
- `tests/m029-acceptance/p03-sc7-live-tail.sh`
- `tests/m029-acceptance/p03-sc8-auto-preflight.sh`
- `tests/m029-acceptance/p03-sc9-auto-quick-no-preflight.sh`
- `tests/m029-acceptance/p03-sc10-auto-chain.sh`
- `tests/m029-acceptance/fixtures/auto-preflight-standard.fixture/` (directory)
- `tests/m029-acceptance/fixtures/auto-preflight-quick.fixture/` (directory)
- `tests/m029-acceptance/fixtures/auto-chain-greenfield.fixture/` (directory)
- `tools/verify/m029-p03-measure-live-tail-latency-shape.sh`
- `tools/verify/m029-p03-sc7-shape.sh`
- `tools/verify/m029-p03-sc8-shape.sh`
- `tools/verify/m029-p03-sc9-shape.sh`
- `tools/verify/m029-p03-sc10-shape.sh`

## Verification

```bash
bash tools/verify/m029-p03-measure-live-tail-latency-shape.sh
bash tools/verify/m029-p03-sc7-shape.sh
bash tools/verify/m029-p03-sc8-shape.sh
bash tools/verify/m029-p03-sc9-shape.sh
bash tools/verify/m029-p03-sc10-shape.sh
bash tests/m029-acceptance/p03-sc7-live-tail.sh
bash tests/m029-acceptance/p03-sc8-auto-preflight.sh
bash tests/m029-acceptance/p03-sc9-auto-quick-no-preflight.sh
bash tests/m029-acceptance/p03-sc10-auto-chain.sh
```

## Inputs

### From Previous Tasks

- T01: `scripts/diagnostics/render-position.sh --live` (consumed by SC-7 + measure-live-tail-latency.sh). API: `bash scripts/diagnostics/render-position.sh --live --milestone <MID> [--root <fixture-root>]` writes the tree to stdout, re-renders on every appended `dispatch_usage` record.
- T01: `display_thresholds.compression_savings_pct` knob (read by render-position.sh; fixture-injected via `.orchestrator/config.yml` in each fixture if non-default needed).
- T02: `commands/auto.md` `## Preflight Summary` section (the contract surface SC-8 + SC-9 assert against).
- T03: `commands/start.md` `## --auto-chain Flag` section + `scripts/lifecycle/start.sh` chain-driver (consumed by SC-10; SC-10 sets `AUTO_CHAIN_STAGE_STUB` to drive the no-op stage invocations).

### From Disk (Pre-existing)

- `scripts/dispatch/predictive-surface.sh` (M027 — SC-8 oracle).
- `scripts/diagnostics/summarize-milestone.sh` (M029/P02 — SC-8 oracle wrapper input). API: `--milestone <MID> --format=keys --root <fixture-root>` emits the deterministic key=value block.
- `scripts/state/find-active-milestone.sh` (existing).
- `scripts/lifecycle/start.sh` (existing + T03 extensions).
- POSIX `tail -f`, `awk`, `printf`, `grep -F`, `cut`, `mktemp`, `find`, `stat`, `sort -n`.

## Constraints

- **AD-19 single-script-file shape for `Check:` commands**: every shape verifier is a single `bash <abs-path>.sh` invocation. The acceptance scripts themselves use `mktemp -d` + cleanup `trap` patterns (MEM004 carve-out for in-script logic; AD-19 applies at `Check:` command level, not inside script bodies).
- **Bash 3.2 (MEM001)**: parallel scalars, `case` statements, `printf`, `grep -F`, `awk`. NO `<<<` herestring, NO `declare -A`. Percentile computation via `sort -n | awk 'NR==idx{...}'`.
- **CON-1 / FR-14 read-only**: every acceptance script uses `mktemp -d` for fixtures. The `auto-chain-greenfield.fixture` is the only fixture that produces `.orchestrator/start-state/` markers, and those are confined to the temp-dir copy, not the live project tree (SC-14 read-only invariant).
- **CON-2 bash + ANSI only**: NO Python (except as last-resort nanosecond-clock shim if both `date +%s%N` and `gdate +%s%N` are unavailable — falls back gracefully). NO `inotify`. NO `fswatch`.
- **#Q-G8 canonical-form invariant**: SC-7 asserts ONLY the `▽ saved Nk` form. The verifier negative-asserts the forbidden verbose suffix.
- **#Q-G9 latency methodology**: p95 ≤ 1.0s assertion; p99 informational; no per-measurement retry; drift trigger at p95 > 1.5s emits RISK callout.
- **Fixture sentinel discipline**: fixture-tree mtime checks DO NOT fire on the live project tree; SC-14 (P02 deliverable) is the live-tree variant. SC-7/SC-8/SC-10 fixtures are isolated under `mktemp -d` copies.
- **Path-collision rule 6**: every T04 deliverable path verified absent at plan-authoring time (2026-05-06).

## Expected Output

After T04 completes:
- `tests/m029-acceptance/measure-live-tail-latency.sh` — exists, executable, exits 0 with `VERDICT: PASS` against the bundled fixture.
- `tests/m029-acceptance/p03-sc{7,8,9,10}-*.sh` — all four exist, executable, exit 0.
- The three fixture directories under `tests/m029-acceptance/fixtures/` exist with their canonical tree shape.
- The five shape verifiers under `tools/verify/m029-p03-*.sh` exist, executable, exit 0.
- A summary file at [`.orchestrator/milestones/M029/phases/P03/tasks/T04-fixtures-and-sc-acceptance-SUMMARY.md`](../../../../../milestones/M029/phases/P03/tasks/T04-fixtures-and-sc-acceptance-SUMMARY.md) documents the deliverables.

## Notes

The "contract-surface assertion" model for SC-8/SC-9: in M029, `commands/auto.md` is a skill document, not an executable Bash entry point. The actual `orchestrator:auto` loop is driven by the LLM agent (Claude Code) following the skill instructions. The acceptance scripts therefore assert the *documented contract* is byte-stable + reproducible (the oracle invocation works), not the *runtime LLM behaviour* (which depends on harness state). This is the standard pattern for skill-documented surfaces in this codebase — see `commands/where.md` / `commands/context.md` precedents (P01/P02).

The `measure-live-tail-latency.sh` harness is the most non-trivial deliverable. The nanosecond-clock portability puzzle (`date +%s%N` works on Linux but emits literal `N` on macOS BSD `date`) is the load-bearing fact. Three-tier resolution shim:
1. Try `date +%s%N`; if output ends in `N`, fall through.
2. Try `gdate +%s%N` (GNU coreutils on macOS via brew); if exit non-zero, fall through.
3. Try `python3 -c 'import time; print(int(time.monotonic()*1e9))'`; if exit non-zero, fall through to millisecond resolution via `date +%s` × 1000 (and adjust the threshold check to acknowledge that resolution).

The three-tier shim itself is bash-3.2-safe (parallel scalars, no array of clock-impls).

The `AUTO_CHAIN_STAGE_STUB` env var fixture pattern is novel for M029 but mirrors the existing `--dry-run` fixture pattern in `start.sh`. It is fixture-only (not exposed as a CLI flag) so production use is impossible.

The fixture trees are the largest disk footprint of T04 — three directories with canonical milestone shapes. The `auto-preflight-standard.fixture` and `auto-preflight-quick.fixture` differ only in the `intensity:` field of EVALUATION frontmatter, so the implementer can author one and copy/sed the other.

## State Context

- **Current State**: executing
- **Milestone**: M029
- **Phase**: P03
- **Task**: T04-fixtures-and-sc-acceptance
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **AD-19 single-script-file shape for `Check:` commands**: every shape verifier is a single `bash <abs-path>.sh` invocation. The acceptance scripts themselves use `mktemp -d` + cleanup `trap` patterns (MEM004 carve-out for in-script logic; AD-19 applies at `Check:` command level, not inside script bodies).
- **Bash 3.2 (MEM001)**: parallel scalars, `case` statements, `printf`, `grep -F`, `awk`. NO `<<<` herestring, NO `declare -A`. Percentile computation via `sort -n | awk 'NR==idx{...}'`.
- **CON-1 / FR-14 read-only**: every acceptance script uses `mktemp -d` for fixtures. The `auto-chain-greenfield.fixture` is the only fixture that produces `.orchestrator/start-state/` markers, and those are confined to the temp-dir copy, not the live project tree (SC-14 read-only invariant).
- **CON-2 bash + ANSI only**: NO Python (except as last-resort nanosecond-clock shim if both `date +%s%N` and `gdate +%s%N` are unavailable — falls back gracefully). NO `inotify`. NO `fswatch`.
- **#Q-G8 canonical-form invariant**: SC-7 asserts ONLY the `▽ saved Nk` form. The verifier negative-asserts the forbidden verbose suffix.
- **#Q-G9 latency methodology**: p95 ≤ 1.0s assertion; p99 informational; no per-measurement retry; drift trigger at p95 > 1.5s emits RISK callout.
- **Fixture sentinel discipline**: fixture-tree mtime checks DO NOT fire on the live project tree; SC-14 (P02 deliverable) is the live-tree variant. SC-7/SC-8/SC-10 fixtures are isolated under `mktemp -d` copies.
- **Path-collision rule 6**: every T04 deliverable path verified absent at plan-authoring time (2026-05-06).

### Acceptance Criteria

This task addresses these P03 phase truths:
- `tests/m029-acceptance/measure-live-tail-latency.sh` implements #Q-G9 methodology (p95 ≤ 1.0s; p99 informational; drift trigger at 1.5s).
- The SC-7/SC-8/SC-9/SC-10 acceptance scripts cover their respective FR contracts.
- The three new fixture trees (auto-preflight-standard, auto-preflight-quick, auto-chain-greenfield) exist under `tests/m029-acceptance/fixtures/`.

This task creates these P03 phase artifacts:
- `tests/m029-acceptance/measure-live-tail-latency.sh`
- `tests/m029-acceptance/p03-sc7-live-tail.sh`
- `tests/m029-acceptance/p03-sc8-auto-preflight.sh`
- `tests/m029-acceptance/p03-sc9-auto-quick-no-preflight.sh`
- `tests/m029-acceptance/p03-sc10-auto-chain.sh`
- `tests/m029-acceptance/fixtures/auto-preflight-standard.fixture/` (directory)
- `tests/m029-acceptance/fixtures/auto-preflight-quick.fixture/` (directory)
- `tests/m029-acceptance/fixtures/auto-chain-greenfield.fixture/` (directory)
- `tools/verify/m029-p03-measure-live-tail-latency-shape.sh`
- `tools/verify/m029-p03-sc7-shape.sh`
- `tools/verify/m029-p03-sc8-shape.sh`
- `tools/verify/m029-p03-sc9-shape.sh`
- `tools/verify/m029-p03-sc10-shape.sh`

### Files To Touch

- `scripts/diagnostics/render-position.sh` (modify)
- `references/file-formats.md` (modify)
- `templates/orchestrator-config-default.yml` (modify)
- `scripts/state/read-config.sh` (modify — VALID_KEYS extension only)
- `commands/auto.md` (modify)
- `commands/start.md` (modify)
- `scripts/lifecycle/start.sh` (modify)
- `specs/037-roadmap-visibility-cli-ux/spec.md` (modify — Spec Amendment Record entry)
- `tests/m029-acceptance/measure-live-tail-latency.sh` (create)
- `tests/m029-acceptance/p03-sc7-live-tail.sh` (create)
- `tests/m029-acceptance/p03-sc8-auto-preflight.sh` (create)
- `tests/m029-acceptance/p03-sc9-auto-quick-no-preflight.sh` (create)
- `tests/m029-acceptance/p03-sc10-auto-chain.sh` (create)
- `tests/m029-acceptance/p03-acceptance-battery.sh` (create)
- `tests/m029-acceptance/run-acceptance-battery.sh` (create)
- `tests/m029-acceptance/fixtures/auto-preflight-standard.fixture/` (create)
- `tests/m029-acceptance/fixtures/auto-preflight-quick.fixture/` (create)
- `tests/m029-acceptance/fixtures/auto-chain-greenfield.fixture/` (create)
- `tools/verify/m029-p03-render-position-live-shape.sh` (create)
- `tools/verify/m029-p03-display-thresholds-config-shape.sh` (create)
- `tools/verify/m029-p03-auto-preflight-shape.sh` (create)
- `tools/verify/m029-p03-auto-chain-shape.sh` (create)
- `tools/verify/m029-p03-measure-live-tail-latency-shape.sh` (create)
- `tools/verify/m029-p03-sc7-shape.sh` (create)
- `tools/verify/m029-p03-sc8-shape.sh` (create)
- `tools/verify/m029-p03-sc9-shape.sh` (create)
- `tools/verify/m029-p03-sc10-shape.sh` (create)
- `tools/verify/m029-p03-spec-amendment-shape.sh` (create)
- `tools/verify/m029-p03-acceptance-battery-shape.sh` (create)
- `tools/verify/m029-p03-run-acceptance-battery-shape.sh` (create)
- `tools/verify/m029-p03-readonly-invariant.sh` (create)
- `tools/verify/m029-p03-scope-guard.sh` (create)
- `tools/verify/m029-p03-phase-suite.sh` (create)
- `tools/verify/m029-p03-validate-milestone-pass.sh` (create)
- `tools/verify/m029-p03-closure-ceremony-shape.sh` (create)
- `.orchestrator/milestones/M029/M029-VALIDATED` (create)
- [`.orchestrator/milestones/M029/M029-SUMMARY.md`](../../../../../milestones/M029/M029-SUMMARY.md) (create)
- `.orchestrator/milestones/M029/execution-log.jsonl` (append milestone-grain `unit_close` event; existing file)

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