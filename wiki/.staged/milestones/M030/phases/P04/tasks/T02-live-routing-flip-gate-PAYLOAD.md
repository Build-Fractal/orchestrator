---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T02-live-routing-flip-gate (Phase P04, Milestone M030)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~400 | required |
| Upstream Context | 981-1145 | ~6300 | required |
| Task Plan | 1147-1737 | ~11300 | required |
| State Context | 1739-1745 | ~100 | required |
| First-Turn Completeness | 1747-1815 | ~1600 | required |
| **Total** | | **~30500** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 676
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
hit_count: 676
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
hit_count: 676
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
hit_count: 676
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
hit_count: 596
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
hit_count: 596
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
hit_count: 596
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
hit_count: 676
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
hit_count: 596
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
hit_count: 596
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
hit_count: 596
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
hit_count: 676
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
hit_count: 676
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
hit_count: 676
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
hit_count: 596
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
hit_count: 596
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
hit_count: 596
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
hit_count: 676
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
hit_count: 596
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
hit_count: 596
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
hit_count: 676
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
hit_count: 676
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
hit_count: 596
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
hit_count: 596
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
hit_count: 596
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
hit_count: 251
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
hit_count: 251
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
hit_count: 251
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
hit_count: 252
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
hit_count: 252
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
hit_count: 242
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
     slug-bearing filenames (p04-*) so install-clobber risk is contained.
     Verifier authorship is co-scheduled with the artifact it gates, in
     the SAME task, per Plan-Time Discipline rule 2. T01 ships fixtures
     + the stub-fail-n adapter + tolerant pre-amendment gates BEFORE T02
     amends dispatch-interface.sh. T02 ships the live-routing branch +
     flip-gate enforcement + partial-flip routing + co-authored
     verifiers (SC-2a, SC-3, partial-flip, CON-3 live-closure, CON-4
     live-killswitch, SC-11 pass-through). T03 ships the escalation
     loop + CON-5 hard-cap + CON-6 prior-records-bit-identical
     verifier. T04 closes with the phase-suite aggregator. Strict
     linear chain T01→T02→T03→T04. -->

### Truths

- `scripts/dispatch/dispatch-interface.sh` short-circuits before invoking any backend adapter when `.orchestrator/config.yml` declares `model_routing:` with `live: true` AND `bash scripts/diagnostics/shadow-compare.sh --corpus <empty>` returns `flip_recommendation=evidence_insufficient`. The dispatch-interface invocation exits nonzero and the appended JSONL line records `override_source=shadow_gate_blocked`. The verifier stages a config with `live: true`, an empty execution log (zero shadow records), and asserts (i) dispatch-interface exit code is nonzero, (ii) the appended JSONL `override_source` field equals `shadow_gate_blocked`, (iii) NO record_type=dispatch_result line was written by the stub adapter (the adapter was never invoked). (FR-9 / SC-2a / D-A2.)
  - Check: `bash tools/verify/p04-sc2a-shadow-gate-block.sh`

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

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P04"
milestone: "M030"
name: "dispatch-interface live-routing branch + programmatic flip-gate + partial-flip + --model passing"
depends_on: ["T01"]
---

## Prerequisites

- All T01 deliverables on disk and green:
  - `bash tools/verify/p04-additive-schema.sh` exits 0 (T01)
  - `bash tools/verify/p04-override-source-enum-extended.sh` exits 0 in pre-amendment-tolerant mode (T01)
- Five fixture plans under `tests/fixtures/m030-p04/plans/`:
  - plan-mechanical-no-override.md (T99)
  - plan-fail-twice-then-pass.md (T97) — used by T03 verifiers, not T02
  - plan-fail-three-times.md (T96) — used by T03 verifiers
  - plan-fail-four-times.md (T96) — used by T03 verifiers
  - plan-novel-class.md (T95) — used by T02 partial-flip verifier
- Three fixture configs under `tests/fixtures/m030-p04/configs/`:
  - config-with-live-true.yml
  - config-with-live-and-killswitch.yml
  - config-with-live-false.yml
- Three shadow corpora at `tests/fixtures/m030-p04/shadow-corpus-{ready,partially-ready,empty}.jsonl`.
- Round-trip stage at `tests/fixtures/m030-p04/round-trip-stage/intensity-metadata.txt` + `payload.txt`.
- Two stub adapters at `scripts/dispatch/adapters/backend/{stub-fail-n.sh,stub-record-model.sh}` — T02 uses `stub-record-model.sh` for SC-3; `stub-fail-n.sh` is unused in T02 (T03 deliverable).
- scripts/dispatch/dispatch-interface.sh exists in its post-P03 form: `_di_emit_dispatch_usage` body (lines ~190-515); shadow path with override-resolution block (lines ~292-446); happy-path shadow-on printf at ~line 453; degradation shadow-on printf at ~line 486; adapter invocation at ~line 586-589 passing 3 flags.
- scripts/diagnostics/shadow-compare.sh exists with `--corpus <path>` flag and emits `flip_recommendation=` line on stdout.

Plan-time prerequisite-existence verification: every path above is asserted by T01 close. The post-P03 shape of `dispatch-interface.sh` was inspected at planning time; the override-resolution block at lines 292-446 contains the precedence chain that T02's live branch slots into.

## Description

T02 is the high-risk core amendment, part 1 of 2. Five deliverables that ship as a single coherent change:

1. **Amend `scripts/dispatch/dispatch-interface.sh`** — extend `_di_emit_dispatch_usage` with a live-routing branch that reads `model_routing.live: true` from `.orchestrator/config.yml`, programmatically invokes `bash scripts/diagnostics/shadow-compare.sh --corpus <corpus>`, branches on the verdict, and conditionally passes `--model <id>` to the backend adapter via the existing adapter-invocation path. Also amends the kill-switch path to additionally short-circuit live mode.

2. **`tools/verify/p04-sc2a-shadow-gate-block.sh`** — gates SC-2a: with `live: true` AND empty corpus, dispatch-interface refuses to call any adapter, exits nonzero, and writes `override_source=shadow_gate_blocked`.

3. **`tools/verify/p04-sc3-live-mechanical.sh`** — gates SC-3: with `live: true` AND ready corpus, dispatching mechanical plan against `stub-record-model.sh` records `model_used=<resolution.fast.claude-code>` AND the stub's record-file contains the same value (proving `--model <id>` was passed correctly).

4. **`tools/verify/p04-partial-flip-routing.sh`** — gates D-A3: with `live: true` AND partially_ready corpus, dispatching a withheld-class task records `partial_flip_active=true` + `withheld_classes=novel` + `model_used=runtime-default`. Dispatching a flippable-class task records the live-routed `model_used` value.

5. **`tools/verify/p04-con3-live-closure.sh`** — gates CON-3: zero new hardcoded model IDs introduced by the live-routing amendment. HEAD-vs-working-tree per-pattern grep count comparison.

6. **`tools/verify/p04-con4-live-killswitch.sh`** — gates CON-4 / SC-7a-style compound: with `model_routing_enabled: false` AND `model_routing.live: true`, dispatching records `override_source=disabled` (NOT `shadow_gate_blocked`), shadow-compare.sh is NEVER invoked, and stderr contains a one-line bypass warning naming `live: true is inactive`.

T02 also re-runs T01's tolerant gates against the amended emitter to confirm the post-amendment branch fires: `p04-override-source-enum-extended.sh` Scenario F now strict-asserts `shadow_gate_blocked`; `p04-additive-schema.sh` continues to pass (shadow-off byte-equality preserved).

### dispatch-interface.sh amendment shape (load-bearing detail)

The amendment is THREE-block: (a) read the `live:` knob from config, (b) extend the kill-switch path with a live-mode bypass warning, (c) insert a live-mode branch BEFORE the existing `if [ "$shadow_override_source" = "none" ]` routing-table awk extraction (currently at line ~404). The adapter invocation at line ~586-589 also gains a conditional `--model <id>` flag.

**Block A — read `live:` from config.** Insert into the override-resolution block, alongside the existing `override_min_tier` read (around line ~360). Add a new local `override_live` and read it via a similar awk section-walker scoped to the `model_routing:` block:

```bash
local override_live
override_live=""
if [ -n "$_di_config_yml" ] && [ -f "$_di_config_yml" ]; then
  override_live="$(awk '
    BEGIN { in_block = 0 }
    /^model_routing:/                 { in_block = 1; next }
    in_block && /^[a-zA-Z_]/          { exit }
    in_block && /^[[:space:]]+live:/  {
      val = $2; gsub(/[",]/, "", val); print val; exit
    }
  ' "$_di_config_yml")"
fi
```

Place this read after the `override_min_tier` read (currently line ~360-369). The new local should be declared in the locals block at line ~306-307 alongside `shadow_override_source override_kill override_min_tier override_plan`.

**Block B — extend kill-switch path with live-bypass warning.** Currently at line ~372-378 (inside the kill-switch precedence branch):

```bash
if [ "$override_kill" = "false" ]; then
  shadow_override_source="disabled"
  if [ -n "$override_min_tier" ]; then
    printf 'model_routing_enabled=false: min_tier: %s is inactive\n' "$override_min_tier" >&2
  fi
fi
```

T02 amends this branch to additionally emit a `live: true is inactive` warning when both kill-switch AND live are active:

```bash
if [ "$override_kill" = "false" ]; then
  shadow_override_source="disabled"
  if [ -n "$override_min_tier" ]; then
    printf 'model_routing_enabled=false: min_tier: %s is inactive\n' "$override_min_tier" >&2
  fi
  if [ "$override_live" = "true" ]; then
    printf 'model_routing_enabled=false: live: true is inactive\n' >&2
  fi
elif [ -n "$override_plan" ]; then
  ...
```

This preserves CON-4 / D-A5: kill switch wins; the live branch never engages when kill switch is active.

**Block C — insert live-mode branch BEFORE the routing-table awk extraction.** The existing block at line ~404-446 runs the routing-table awk extraction when `shadow_override_source = none`. T02 inserts a live-mode branch INSIDE the `if [ "$shadow_override_source" = "none" ]` block, BEFORE the awk extraction, so the live-mode logic runs only when no override fired AND the live knob is true.

```bash
if [ "$shadow_override_source" = "none" ]; then
  # M030/P04/T02: live-routing branch.
  # Programmatic flip-gate: when live=true, invoke shadow-compare and gate
  # on the verdict before any adapter call (FR-9 / D-A2).
  if [ "$override_live" = "true" ]; then
    # Resolve the corpus path: explicit env-var override (verifier seam) or
    # default to the in-flight log_file. The env var allows fixture-corpus
    # injection without polluting the live log.
    _di_compare_corpus="${M030_SHADOW_COMPARE_CORPUS:-$log_file}"
    _di_compare_tmp="$(mktemp 2>/dev/null || printf '/tmp/p04_compare_%d' "$$")"
    bash "$_DI_PROJECT_ROOT/scripts/diagnostics/shadow-compare.sh" --corpus "$_di_compare_corpus" > "$_di_compare_tmp" 2>/dev/null || true
    _di_verdict="$(grep -E '^flip_recommendation=' "$_di_compare_tmp" | head -n 1 | sed -E 's/^flip_recommendation=([^[:space:]]+).*/\1/')"
    _di_withheld_line="$(grep -E '^withheld_classes=' "$_di_compare_tmp" | head -n 1 | sed -E 's/^withheld_classes=//')"
    rm -f "$_di_compare_tmp" 2>/dev/null

    if [ "$_di_verdict" = "evidence_insufficient" ] || [ "$_di_verdict" = "block" ]; then
      shadow_override_source="shadow_gate_blocked"
      shadow_routed=""
      shadow_used="$model"
      shadow_partial="false"
      shadow_withheld=""
      # Set a sentinel for the top-level block-gate check (see Step 5).
      _DI_LIVE_GATE_BLOCKED=1
    elif [ "$_di_verdict" = "ready" ]; then
      # All classes flippable. Resolve routed tier + model ID via routing.yml.
      shadow_routed="$(awk -v ch="$_di_shadow_character" '
        BEGIN { in_routing = 0; in_class = 0 }
        /^routing:/                       { in_routing = 1; next }
        /^resolution:/                    { exit }
        in_routing && /^  [a-z_]+:$/      { in_class = ($1 == (ch ":")) ? 1 : 0; next }
        in_routing && in_class && /^    claude-code:/ {
          val = $2; gsub(/[",]/, "", val); print val; exit
        }
      ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
      shadow_used="$(awk -v tier="$shadow_routed" '
        BEGIN { in_resolution = 0; in_tier = 0 }
        /^resolution:/                    { in_resolution = 1; next }
        /^cost_rates:/                    { exit }
        in_resolution && /^  [a-z_]+:$/   { in_tier = ($1 == (tier ":")) ? 1 : 0; next }
        in_resolution && in_tier && /^    claude-code:/ {
          val = $2; gsub(/[",]/, "", val); print val; exit
        }
      ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
      shadow_partial="false"
      shadow_withheld=""
      _DI_LIVE_MODEL_FLAG="$shadow_used"
    elif [ "$_di_verdict" = "partially_ready" ]; then
      # Per-class authorization: flip only when the task's class is NOT in
      # withheld_classes. Otherwise: route to runtime default + record
      # partial_flip_active=true + withheld_classes=<list>.
      shadow_partial="true"
      shadow_withheld="$_di_withheld_line"
      # Check whether the task's class is withheld.
      _di_is_withheld=0
      _di_w="$_di_withheld_line"
      while [ -n "$_di_w" ]; do
        _di_w_first="${_di_w%%,*}"
        if [ "$_di_w_first" = "$_di_shadow_character" ]; then
          _di_is_withheld=1
          break
        fi
        case "$_di_w" in
          *,*) _di_w="${_di_w#*,}" ;;
          *) _di_w="" ;;
        esac
      done
      if [ "$_di_is_withheld" -eq 1 ]; then
        # Withheld class: fall back to runtime default; do NOT pass --model.
        shadow_routed=""
        shadow_used="$model"
        # _DI_LIVE_MODEL_FLAG remains unset.
      else
        # Flippable class: resolve and route live.
        shadow_routed="$(awk -v ch="$_di_shadow_character" '
          BEGIN { in_routing = 0; in_class = 0 }
          /^routing:/                       { in_routing = 1; next }
          /^resolution:/                    { exit }
          in_routing && /^  [a-z_]+:$/      { in_class = ($1 == (ch ":")) ? 1 : 0; next }
          in_routing && in_class && /^    claude-code:/ {
            val = $2; gsub(/[",]/, "", val); print val; exit
          }
        ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
        shadow_used="$(awk -v tier="$shadow_routed" '
          BEGIN { in_resolution = 0; in_tier = 0 }
          /^resolution:/                    { in_resolution = 1; next }
          /^cost_rates:/                    { exit }
          in_resolution && /^  [a-z_]+:$/   { in_tier = ($1 == (tier ":")) ? 1 : 0; next }
          in_resolution && in_tier && /^    claude-code:/ {
            val = $2; gsub(/[",]/, "", val); print val; exit
          }
        ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
        _DI_LIVE_MODEL_FLAG="$shadow_used"
      fi
    fi
  fi

  # Existing shadow-mode awk extraction (preserved when live=false / unset).
  if [ -z "$shadow_routed" ] && [ "$shadow_override_source" = "none" ]; then
    # Original P02 path — only fires when live mode did not set shadow_routed.
    shadow_routed="$(awk -v ch="$_di_shadow_character" ' ... ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
    shadow_used="$(awk -v tier="$shadow_routed" ' ... ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
  fi
fi
```

**The `_DI_LIVE_MODEL_FLAG` and `_DI_LIVE_GATE_BLOCKED` shell variables** are set by the emitter and read by the dispatcher at line ~586-589 (the adapter invocation point) and at the top-level adapter-call gate. They are NOT JSONL fields — they are in-process state passed from the emit-time logic to the dispatch-time logic.

**Block D — extend the adapter invocation with conditional --model flag.** Current code at line ~586-589:

```bash
adapter_output="$(bash "$ADAPTER" \
  --task-plan "$TASK_PLAN" \
  --payload "$PAYLOAD" \
  --intensity-metadata "$INTENSITY_METADATA" 2>/dev/null)" || adapter_rc=$?
```

T02 amends to:

```bash
if [ -n "${_DI_LIVE_MODEL_FLAG:-}" ]; then
  adapter_output="$(bash "$ADAPTER" \
    --task-plan "$TASK_PLAN" \
    --payload "$PAYLOAD" \
    --intensity-metadata "$INTENSITY_METADATA" \
    --model "$_DI_LIVE_MODEL_FLAG" 2>/dev/null)" || adapter_rc=$?
else
  adapter_output="$(bash "$ADAPTER" \
    --task-plan "$TASK_PLAN" \
    --payload "$PAYLOAD" \
    --intensity-metadata "$INTENSITY_METADATA" 2>/dev/null)" || adapter_rc=$?
fi
```

**Block E — top-level shadow-gate-blocked branch.** BEFORE the adapter invocation at line ~586, T02 inserts a check on `_DI_LIVE_GATE_BLOCKED`. If the sentinel is set, the dispatcher MUST refuse to call the adapter, MUST emit the `dispatch_usage` record (which carries `override_source=shadow_gate_blocked`), MUST emit a `dispatch-error.md` document on stderr, and MUST exit nonzero. The challenge: the `_DI_LIVE_MODEL_FLAG` and `_DI_LIVE_GATE_BLOCKED` are set INSIDE `_di_emit_dispatch_usage`, which is called AFTER the adapter at line ~620 (happy-path) or ~596 (adapter-failed). The current ordering does not work: the gate must run BEFORE the adapter.

**Resolution: extract the live-mode resolution into a separate helper called BEFORE the adapter invocation.** Add a new helper `_di_resolve_live_routing` that runs the override-resolution + live-mode + flip-gate logic, sets the shell-scoped sentinels, and returns. This helper is called once before line ~585 (the adapter invocation block); `_di_emit_dispatch_usage` is then called as before, but it consumes pre-resolved values from the shell-scoped variables instead of re-computing them.

The cleanest factoring:

1. Move the override-resolution block + live-mode branch out of `_di_emit_dispatch_usage` and into a new helper `_di_resolve_live_routing` defined alongside it (around line 188).
2. The helper sets shell-scoped variables: `shadow_override_source`, `shadow_routed`, `shadow_used`, `shadow_partial`, `shadow_withheld`, `_DI_LIVE_MODEL_FLAG`, `_DI_LIVE_GATE_BLOCKED`.
3. Call the helper at line ~580 (before adapter resolution but after `BACKEND` is resolved).
4. At line ~585, check `_DI_LIVE_GATE_BLOCKED`; if set, skip adapter invocation, emit error+JSONL, exit nonzero.
5. At line ~586, pass `--model "$_DI_LIVE_MODEL_FLAG"` (when set) to the adapter.
6. `_di_emit_dispatch_usage` reads the shell-scoped variables instead of re-computing them. The override-resolution block inside the function becomes a guard ("if these are already set, skip recomputation").

Alternative (simpler) factoring per MEM004 carve-out: keep the resolution inside `_di_emit_dispatch_usage`, but have the dispatcher call `_di_emit_dispatch_usage --resolve-only` first (a new flag that runs the resolution and sets shell-scoped sentinels but does NOT emit the JSONL record), then check the sentinels, then either skip-adapter-and-emit-record or proceed-and-emit-record-after.

The recommended choice is **option 1 (extract `_di_resolve_live_routing`)** because it cleanly separates resolution from emission and matches MEM004's pure-lib-extraction pattern. The override-resolution + live-mode branch becomes a single helper; the printf branches in `_di_emit_dispatch_usage` continue to read the same shell-scoped variables they already read.

If executor finds extraction too heavy, the alternative (option 2) is acceptable as long as the sentinel-then-gate flow is mechanically observable: `_DI_LIVE_GATE_BLOCKED` is set BEFORE the adapter is invoked, and the adapter is NOT invoked when the sentinel is set.

### Block F — emit JSONL record on shadow-gate-blocked path

When `_DI_LIVE_GATE_BLOCKED=1`, T02 emits the `dispatch_usage` record with `override_source=shadow_gate_blocked` (other shadow fields populated as documented above). The emit happens at the existing `_di_emit_dispatch_usage` call site, but with the resolution already pre-computed. The dispatcher's top-level flow on shadow_gate_blocked:

1. `_di_resolve_live_routing` sets `_DI_LIVE_GATE_BLOCKED=1` + `shadow_override_source=shadow_gate_blocked`.
2. The dispatcher checks the sentinel before adapter invocation.
3. If set: `_di_emit_dispatch_usage ""` (empty warning override; dispatch_usage record carries the shadow_gate_blocked source), then emit a synthesized `dispatch-error.md` on stderr (`error_type=shadow_gate_blocked`, `retry_eligible=true`, `escalation=operator`), then exit 7 (new exit code; or reuse 5 if simpler).
4. If not set: proceed to adapter invocation as before.

### Verifier shapes (load-bearing detail)

**`tools/verify/p04-sc2a-shadow-gate-block.sh`**:

```bash
#!/usr/bin/env bash
# tools/verify/p04-sc2a-shadow-gate-block.sh — M030/P04 SC-2a shadow-gate-blocked.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURES="$REPO_ROOT/tests/fixtures/m030-p04"
PLAN="$FIXTURES/plans/plan-mechanical-no-override.md"
PAYLOAD="$FIXTURES/round-trip-stage/payload.txt"
INTENSITY_META="$FIXTURES/round-trip-stage/intensity-metadata.txt"
CONFIG="$FIXTURES/configs/config-with-live-true.yml"
EMPTY_CORPUS="$FIXTURES/shadow-corpus-empty.jsonl"
DISPATCH="$REPO_ROOT/scripts/dispatch/dispatch-interface.sh"

pass=0; fail=0

# Stage tmp_root.
TMP_ROOT="$(mktemp -d 2>/dev/null)"
[ -n "$TMP_ROOT" ] || { TMP_ROOT="/tmp/p04-sc2a-$$"; mkdir -p "$TMP_ROOT"; }
mkdir -p "$TMP_ROOT/.orchestrator" 2>/dev/null
mkdir -p "$TMP_ROOT/phases" 2>/dev/null
cp "$CONFIG" "$TMP_ROOT/.orchestrator/config.yml"
LOG_FILE="$TMP_ROOT/execution-log.jsonl"

unset ORCH_MODEL
export ORCHESTRATOR_ROOT="$TMP_ROOT"
export M030_SHADOW_MODE=1
export CLAUDECODE=1
export M030_SHADOW_COMPARE_CORPUS="$EMPTY_CORPUS"

DISPATCH_OUT_TMP="/tmp/p04-sc2a-out.txt"
DISPATCH_ERR_TMP="/tmp/p04-sc2a-err.txt"
rm -f "$DISPATCH_OUT_TMP" "$DISPATCH_ERR_TMP" 2>/dev/null
bash "$DISPATCH" \
  --task-plan "$PLAN" \
  --payload "$PAYLOAD" \
  --intensity-metadata "$INTENSITY_META" \
  --backend stub \
  > "$DISPATCH_OUT_TMP" 2> "$DISPATCH_ERR_TMP"
DISPATCH_RC=$?

# Assertion 1: dispatch-interface exits nonzero.
if [ "$DISPATCH_RC" -ne 0 ]; then
  pass=$((pass+1))
  printf 'PASS: dispatch-interface exits nonzero (rc=%d)\n' "$DISPATCH_RC"
else
  fail=$((fail+1))
  printf 'FAIL: dispatch-interface exited 0; expected nonzero on shadow-gate-block\n'
fi

# Assertion 2: appended JSONL line carries override_source=shadow_gate_blocked.
LINE_TMP="/tmp/p04-sc2a-line.txt"
rm -f "$LINE_TMP" 2>/dev/null
grep -F '"record_type":"dispatch_usage"' "$LOG_FILE" > "$LINE_TMP" 2>/dev/null
SGB_TMP="/tmp/p04-sc2a-sgb.txt"
rm -f "$SGB_TMP" 2>/dev/null
grep -F '"override_source":"shadow_gate_blocked"' "$LINE_TMP" > "$SGB_TMP" 2>/dev/null
SGB_LC_TMP="/tmp/p04-sc2a-sgblc.txt"
wc -l < "$SGB_TMP" > "$SGB_LC_TMP" 2>/dev/null
SGB_LC="$(tr -d '[:space:]' < "$SGB_LC_TMP")"
[ -n "$SGB_LC" ] || SGB_LC=0
if [ "$SGB_LC" -ge 1 ]; then
  pass=$((pass+1))
  printf 'PASS: override_source=shadow_gate_blocked recorded\n'
else
  fail=$((fail+1))
  printf 'FAIL: override_source=shadow_gate_blocked token missing\n'
fi

# Assertion 3: dispatch-result NOT emitted on stdout (adapter never invoked).
DRT_TMP="/tmp/p04-sc2a-drt.txt"
grep -F 'type: "dispatch-result"' "$DISPATCH_OUT_TMP" > "$DRT_TMP" 2>/dev/null
DRT_LC_TMP="/tmp/p04-sc2a-drtlc.txt"
wc -l < "$DRT_TMP" > "$DRT_LC_TMP" 2>/dev/null
DRT_LC="$(tr -d '[:space:]' < "$DRT_LC_TMP")"
[ -n "$DRT_LC" ] || DRT_LC=0
if [ "$DRT_LC" -eq 0 ]; then
  pass=$((pass+1))
  printf 'PASS: no dispatch-result emitted (adapter not invoked)\n'
else
  fail=$((fail+1))
  printf 'FAIL: dispatch-result was emitted; adapter was invoked despite gate\n'
fi

# Cleanup.
rm -f "$LINE_TMP" "$SGB_TMP" "$SGB_LC_TMP" "$DRT_TMP" "$DRT_LC_TMP" "$DISPATCH_OUT_TMP" "$DISPATCH_ERR_TMP" 2>/dev/null
rm -rf "$TMP_ROOT" 2>/dev/null

printf 'SUMMARY: p04-sc2a-shadow-gate-block.sh pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ] && exit 0
exit 1
```

**`tools/verify/p04-sc3-live-mechanical.sh`**: same staging shape but `EMPTY_CORPUS` becomes `READY_CORPUS=tests/fixtures/m030-p04/shadow-corpus-ready.jsonl`, backend becomes `stub-record-model`, and assertions are:

1. `jq -r '.model_used'` from the JSONL record equals the runtime-extracted `resolution.fast.claude-code` value (extracted via the same awk section-walker dispatch-interface uses; CON-3-clean).
2. The contents of `STUB_RECORD_MODEL_FILE` equal that same value (proves `--model <id>` was passed).
3. dispatch-interface exits 0 (live-routed dispatch succeeded).

**`tools/verify/p04-partial-flip-routing.sh`**: stage TWO round-trip dispatches (mechanical-class plan AND novel-class plan) against the partially_ready corpus. Assert:

1. Mechanical-class dispatch: `model_used=<resolution.fast.claude-code>` (live-routed; mechanical is flippable per partially_ready/withheld=novel) AND `partial_flip_active=true` AND `withheld_classes=novel`.
2. Novel-class dispatch: `model_used=<runtime-default>` (NOT routing-table-resolved; novel is withheld) AND `partial_flip_active=true` AND `withheld_classes=novel`.

**`tools/verify/p04-con3-live-closure.sh`**: same shape as `p03-con3-closure.sh`. For each pattern in `{claude-haiku-, claude-sonnet-, claude-opus-, gpt-, o1-, o3-, gemini-}`: count occurrences in `git show HEAD:scripts/dispatch/dispatch-interface.sh` and in working-tree; assert working-tree count <= HEAD count.

**`tools/verify/p04-con4-live-killswitch.sh`**: stage `config-with-live-and-killswitch.yml`. Assert:

1. JSONL record carries `override_source=disabled` (NOT `shadow_gate_blocked`).
2. `model_used` matches runtime default (the `model:` field from `intensity-metadata.txt`).
3. Stderr contains the line `model_routing_enabled=false: live: true is inactive`.
4. Stderr also contains `min_tier:.*is inactive` (since the fixture also sets min_tier).
5. Side-channel: no `MOCK_SHADOW_COMPARE_INVOKED_TOUCH` file is touched (the verifier does NOT need to mock shadow-compare; it relies on the kill-switch path executing BEFORE the live-mode block runs, so shadow-compare is structurally never invoked. The "MOCK_SHADOW_COMPARE_INVOKED_TOUCH" check is strictly a documentation aid in the truth statement; the actual assertion is via the JSONL record value + stderr capture).

## Steps

1. **Confirm T01 deliverables are on disk and green.** Run:

   ```bash
   bash tools/verify/p04-additive-schema.sh
   bash tools/verify/p04-override-source-enum-extended.sh
   ```

   Expected: both exit 0 (pre-amendment-tolerant). If either fails, T01 must be re-opened.

2. **Snapshot the pre-amendment `dispatch-interface.sh` for the CON-3 diff baseline.** No explicit file snapshot needed — `git show HEAD:scripts/dispatch/dispatch-interface.sh` is the baseline (mirrors P02/T02 + P03/T02 pattern).

3. **Amend `_di_emit_dispatch_usage` (or extract `_di_resolve_live_routing`) per the Description.** Concretely:

   a. Add `local override_live` to the locals block at line ~306-307.
   b. After the `override_min_tier` awk extraction (line ~360-369), add the `override_live` awk extraction (Block A in the Description).
   c. Inside the kill-switch precedence branch (line ~372-378), append the `live: true is inactive` warning emission when `override_live=true` (Block B).
   d. Inside the `if [ "$shadow_override_source" = "none" ]` block (line ~404), insert the live-mode branch BEFORE the existing routing-table awk extraction (Block C).
   e. Add top-level shell-scoped sentinels `_DI_LIVE_MODEL_FLAG` and `_DI_LIVE_GATE_BLOCKED` (declared as `local` if inside the function, OR top-level via `: "${_DI_LIVE_MODEL_FLAG:=}"` if extracted to a separate helper).

4. **(Recommended) Extract `_di_resolve_live_routing` as a top-level helper** alongside `_di_tier_rank` (around line 175). The helper takes no arguments; reads/writes shell-scoped variables (`TASK_PLAN`, `ORCH_ROOT`, `_DI_PROJECT_ROOT`, etc.); leaves `shadow_override_source`, `shadow_routed`, `shadow_used`, `shadow_partial`, `shadow_withheld`, `_DI_LIVE_MODEL_FLAG`, `_DI_LIVE_GATE_BLOCKED` set in the caller's scope. Call the helper from BOTH (a) inside `_di_emit_dispatch_usage` (preserves the existing emit-time computation as a fallback when called outside the live flow), AND (b) from the dispatcher at line ~580 BEFORE adapter invocation. Idempotent: a second call on the same dispatch is a no-op.

   Alternative if extraction proves too disruptive: keep all logic inside `_di_emit_dispatch_usage` AND add a dispatcher-side check that re-reads the same `.orchestrator/config.yml` and shadow-compare verdict to derive the `_DI_LIVE_GATE_BLOCKED` sentinel. The duplication is acceptable as long as the dispatcher-side check uses the same code path the emitter uses.

5. **Insert top-level shadow-gate-blocked branch BEFORE adapter invocation.** At line ~585 (just before the adapter invocation), add:

   ```bash
   # M030/P04/T02: shadow-gate-blocked refuses adapter invocation.
   if [ "${_DI_LIVE_GATE_BLOCKED:-0}" = "1" ]; then
     emit_error "shadow_gate_blocked" "true" "operator" "${BACKEND}" \
       "Live routing requested but shadow corpus did not pass flip-readiness check" \
       "Shadow-compare verdict: evidence_insufficient or block" \
       "Either populate the shadow corpus to >=50 records per class with stable confidence, set model_routing.live: false, or set model_routing_enabled: false to bypass routing entirely."
     # Still emit the dispatch_usage record so the gate-block is observable in JSONL.
     _di_emit_dispatch_usage "" || true
     exit 7
   fi
   ```

   Choose exit code 7 (new) to disambiguate from `adapter-failed=5` and `adapter-malformed=6`.

6. **Amend the adapter invocation at line ~586-589** to conditionally append `--model <id>` when `_DI_LIVE_MODEL_FLAG` is set (Block D).

7. **Author `tools/verify/p04-sc2a-shadow-gate-block.sh`** per the shape in the Description. Mark executable.

8. **Author `tools/verify/p04-sc3-live-mechanical.sh`** per the shape in the Description. Key implementation detail: the verifier extracts the expected `resolution.fast.claude-code` literal at runtime via:

   ```bash
   EXPECTED_FAST_TMP="/tmp/p04-sc3-expected.txt"
   awk '
     BEGIN { in_resolution = 0; in_tier = 0 }
     /^resolution:/                    { in_resolution = 1; next }
     /^cost_rates:/                    { exit }
     in_resolution && /^  [a-z_]+:$/   { in_tier = ($1 == "fast:") ? 1 : 0; next }
     in_resolution && in_tier && /^    claude-code:/ {
       val = $2; gsub(/[",]/, "", val); print val; exit
     }
   ' "$REPO_ROOT/templates/model-routing.yml" > "$EXPECTED_FAST_TMP"
   EXPECTED_FAST="$(head -n 1 "$EXPECTED_FAST_TMP")"
   rm -f "$EXPECTED_FAST_TMP"
   ```

   Then assert (a) the appended JSONL `model_used` field equals `$EXPECTED_FAST`, (b) the stub-record-model output file equals `$EXPECTED_FAST`. CON-3-clean: no hardcoded `claude-haiku-4-5` in the verifier.

9. **Author `tools/verify/p04-partial-flip-routing.sh`** per the shape in the Description. Stages TWO dispatches (mechanical + novel) against the partially_ready corpus. Two-stage script: each stage is a self-contained tmp_root + dispatch + assertion block.

10. **Author `tools/verify/p04-con3-live-closure.sh`** mirroring `p03-con3-closure.sh`. Seven patterns; per-pattern grep + count + assertion; `SUMMARY:` line at end.

11. **Author `tools/verify/p04-con4-live-killswitch.sh`** per the shape in the Description. Stage `config-with-live-and-killswitch.yml`. Capture stderr to a tmp file. Assert:
    - JSONL `override_source=disabled`.
    - JSONL `model_used` equals runtime default (the `model:` field from `intensity-metadata.txt`).
    - Stderr file contains `live: true is inactive` substring.
    - Stderr file contains `min_tier.*is inactive` substring.

12. **Re-run T01's tolerant verifiers against the amended emitter:**

    ```bash
    bash tools/verify/p04-additive-schema.sh
    bash tools/verify/p04-override-source-enum-extended.sh
    ```

    Expected: both exit 0. `p04-additive-schema.sh` confirms shadow-off byte-equality holds (P02 SC-11 contract preserved). `p04-override-source-enum-extended.sh` Scenario F now strict-asserts `shadow_gate_blocked` (the post-amendment branch fires).

    If `p04-additive-schema.sh` fails, the shadow-off `printf` branch was accidentally modified — revisit Step 3-6 and ensure ONLY the shadow-on branches were touched. The shadow-off lines ~468 + ~501 must be byte-identical to pre-T02.

    If `p04-override-source-enum-extended.sh` fails on Scenario F, the `_DI_LIVE_GATE_BLOCKED` path is not setting `shadow_override_source=shadow_gate_blocked` correctly — recheck the verdict-branching logic.

13. **Run all five new T02 verifiers as a self-check:**

    ```bash
    bash tools/verify/p04-sc2a-shadow-gate-block.sh
    bash tools/verify/p04-sc3-live-mechanical.sh
    bash tools/verify/p04-partial-flip-routing.sh
    bash tools/verify/p04-con3-live-closure.sh
    bash tools/verify/p04-con4-live-killswitch.sh
    ```

    Expected: all five exit 0.

14. **Stage and commit.** Stage `scripts/dispatch/dispatch-interface.sh`, `tools/verify/p04-sc2a-shadow-gate-block.sh`, `tools/verify/p04-sc3-live-mechanical.sh`, `tools/verify/p04-partial-flip-routing.sh`, `tools/verify/p04-con3-live-closure.sh`, `tools/verify/p04-con4-live-killswitch.sh`. Write commit message file via Write to `/tmp/p04-t02-commit-msg.txt`; commit with `git commit -F /tmp/p04-t02-commit-msg.txt`. Recommended subject: `M030/P04/T02: dispatch-interface live-routing branch + flip-gate + partial-flip + --model passing`.

## Must-Haves

This task satisfies the phase truths:

- "scripts/dispatch/dispatch-interface.sh short-circuits before invoking any backend adapter when ... live: true AND ... evidence_insufficient ..." — gated by `tools/verify/p04-sc2a-shadow-gate-block.sh`.
- "SC-3 holds: with model_routing.live: true AND a shadow corpus passing the flip-readiness check ..." — gated by `tools/verify/p04-sc3-live-mechanical.sh`.
- "Partial-flip routing (D-A3) ..." — gated by `tools/verify/p04-partial-flip-routing.sh`.
- "The live-routing branch in dispatch-interface.sh introduces zero new hardcoded model IDs ..." — gated by `tools/verify/p04-con3-live-closure.sh`.
- "CON-4 / SC-7a-style compound (kill-switch wins in live mode) ..." — gated by `tools/verify/p04-con4-live-killswitch.sh`.
- "The override_source enum gains a sixth value shadow_gate_blocked ..." — gated by `tools/verify/p04-override-source-enum-extended.sh` (post-amendment-strict; T01's tolerant branch retires after T02 lands).
- "SC-11 byte-equality re-confirmed against P02's pre-M030 fixture ..." — gated by `tools/verify/p04-additive-schema.sh` (re-run against amended emitter).

## Verification

```bash
bash tools/verify/p04-additive-schema.sh
bash tools/verify/p04-override-source-enum-extended.sh
bash tools/verify/p04-sc2a-shadow-gate-block.sh
bash tools/verify/p04-sc3-live-mechanical.sh
bash tools/verify/p04-partial-flip-routing.sh
bash tools/verify/p04-con3-live-closure.sh
bash tools/verify/p04-con4-live-killswitch.sh
```

Each verifier uses single-script-file shape per AD-19. All seven must exit 0 before T02 closes.

## Inputs

### From Previous Tasks

- tests/fixtures/m030-p04/plans/plan-mechanical-no-override.md (from T01) — Key API: mechanical-classified plan with no override frontmatter; classifier returns `character=mechanical, confidence=high`.
- tests/fixtures/m030-p04/plans/plan-novel-class.md (from T01) — Key API: novel-classified plan; classifier returns `character=novel, confidence=*`. Used by partial-flip verifier.
- tests/fixtures/m030-p04/configs/{config-with-live-true,config-with-live-and-killswitch,config-with-live-false}.yml (from T01) — Key API: `.orchestrator/config.yml`-shaped overlay configs with `model_routing.live` + optional `model_routing_enabled` / `min_tier` keys.
- tests/fixtures/m030-p04/shadow-corpus-{ready,partially-ready,empty}.jsonl (from T01) — Key API: pre-synthesized JSONL corpora that drive `shadow-compare.sh` to specific verdicts.
- tests/fixtures/m030-p04/round-trip-stage/{intensity-metadata.txt,payload.txt} (from T01) — Standard round-trip dispatch inputs.
- scripts/dispatch/adapters/backend/stub-record-model.sh (from T01) — Key API: accepts `--model <id>` flag, writes value to `STUB_RECORD_MODEL_FILE`. Used by SC-3 verifier.
- scripts/dispatch/adapters/backend/stub-fail-n.sh (from T01) — Not used by T02 verifiers; reserved for T03.
- tools/verify/p04-additive-schema.sh (from T01) — Key API: pass-through wrapper over `tools/verify/p02-additive-schema.sh`. Continues to exit 0 against the post-T02 emitter as long as the shadow-off branches are byte-identical.
- tools/verify/p04-override-source-enum-extended.sh (from T01) — Key API: pre-amendment-tolerant scenario harness with six scenarios A-F. After T02's amendment lands, Scenario F transitions from tolerant ("any P03 enum value PASS") to strict (`shadow_gate_blocked`-only PASS). No verifier-code change needed — the strict branch fires automatically when the token is observed.

### From Disk (Pre-existing)

- scripts/dispatch/dispatch-interface.sh — pre-T02 form (post-P03). T02 amends `_di_emit_dispatch_usage` body + dispatcher-level adapter invocation.
  - Key API: `_di_emit_dispatch_usage [warning_override]` writes one `dispatch_usage` record to `$log_file` per invocation. Function-internal access to `$TASK_PLAN`, `$PAYLOAD`, `$INTENSITY_METADATA`, `$BACKEND`, `$UNIT_ID`, `$MILESTONE_ID`, `$PHASE_ID`, `$TASK_ID`, `$ORCH_ROOT`, `$_DI_PROJECT_ROOT`. Pre-T02 the function emits 6 P02/P03 fields under shadow-on. Post-T02 the function emits the same 6 fields, but the `override_source` field gains a sixth enum value `shadow_gate_blocked` and the `model_used` field is populated from the routing-table resolution rather than the runtime default when live mode is active.
- scripts/diagnostics/shadow-compare.sh — P02/T03 deliverable.
  - Key API: `bash <path> [--corpus <jsonl-path>]` reads JSONL; emits per-class `count=` + `variance=` + `stable=` lines; emits one `flip_recommendation=<ready|partially_ready|block|evidence_insufficient>` line; on `partially_ready` emits an additional `withheld_classes=<comma-list>` line. Bash 3.2 compatible.
- scripts/dispatch/classify-task.sh — P01/T02 classifier. Indirectly exercised via shadow-on dispatch.
- templates/model-routing.yml — P01/T03 SSOT. T02's amendment reads `routing:` and `resolution:` blocks.
- scripts/dispatch/adapters/backend/stub.sh — minimal adapter for round-trip harness invocations. Not affected by T02; shadow-gate-blocked scenarios use stub.sh as the (never-invoked) backend.

## Constraints

- **AD-19 single-script-file shape**: all verifier `Check:` invocations are `bash <single-path>.sh`. The amendment to `dispatch-interface.sh` is internal code; AD-19 governs the verifier-invocation shape, not the script's internal structure.
- **MEM004 emitter-internal carve-out**: `_di_emit_dispatch_usage` (or the new `_di_resolve_live_routing` helper) inherits the dispatch-internal-emitter carve-out — pipes / awk / `$()` permitted in their bodies. T02's amendments stay within this carve-out.
- **AP-009 compound-chain-gt2 (verifier shape)**: the five T02 verifiers MUST avoid `result=$(cmd | grep | head)` patterns. Use tmp-file intermediates: `cmd > /tmp/<f>.txt; grep ... < /tmp/<f>.txt > /tmp/<g>.txt; head -1 < /tmp/<g>.txt`.
- **CON-2 / FR-19 / SC-11 (additive-only schema)**: the shadow-OFF `printf` format strings MUST be byte-identical to the post-P03 form. T02's amendment touches ONLY the resolution logic (which feeds the shadow-on printfs' arguments) and the conditional `--model` flag passing to the adapter — NOT the shadow-off printfs themselves. Verified by `tools/verify/p04-additive-schema.sh`.
- **CON-3 (symbolic-tier closure)**: zero new literal provider model IDs in `dispatch-interface.sh`. The live branch's tier resolution flows through `templates/model-routing.yml resolution.<tier>.claude-code` via the same awk section-walker used by the existing P02 path. Verified by `tools/verify/p04-con3-live-closure.sh`.
- **CON-4 / D-A5 (kill switch supersedes live)**: the precedence chain MUST evaluate the kill switch FIRST. When both `model_routing_enabled: false` and `model_routing.live: true` are active, override_source MUST be `disabled` (NOT `shadow_gate_blocked`). The compound case emits a one-line stderr warning naming `live: true is inactive`. Verified by `tools/verify/p04-con4-live-killswitch.sh`.
- **CON-6 (append-only shadow corpus)**: the live-mode emit path uses `>> "$log_file"` only. No `mv`, no `cp`, no truncating `>`, no temp-file-and-swap. The P02 `tools/verify/p02-append-only.sh` continues to gate this property under HEAD; T02 does not re-author it.
- **D-A2 (programmatic flip-gate enforcement)**: the live branch MUST invoke `bash scripts/diagnostics/shadow-compare.sh` programmatically before the first live-routed dispatch. The verdict gates the adapter call. Verified by `tools/verify/p04-sc2a-shadow-gate-block.sh` (the gate refuses the adapter call when verdict is evidence_insufficient).
- **D-A3 (per-class partial-flip authorization)**: only classes whose routing-table default is `smart` may be enumerated in `withheld_classes` for the partially_ready verdict. T02 trusts shadow-compare's enumeration (which already enforces D-A3) and does not re-validate. Verified by `tools/verify/p04-partial-flip-routing.sh`.
- **CC-only launch posture**: live path requires `CLAUDECODE=1` AND `M030_SHADOW_MODE=1`. The live-routing block is wrapped in the same gate as the existing P02/P03 shadow path — Codex CLI / Cursor short-circuit to the pre-P02 emit (no live mode possible).
- **Bash 3.2 compatibility**: no `declare -A`, no `mapfile`, no `readarray`. The awk blocks are POSIX awk, not gawk-extended.
- **Plan-Time Discipline rule 5 (real-DB verification)**: T02 introduces no SQL — N/A.

## Expected Output

- scripts/dispatch/dispatch-interface.sh — amended `_di_emit_dispatch_usage` body (or new `_di_resolve_live_routing` helper) with the live-routing branch reading `model_routing.live:`, programmatically invoking shadow-compare, branching on verdict (`evidence_insufficient|block` → `shadow_gate_blocked`; `ready` → live-route + `--model <id>`; `partially_ready` → per-class authorization). Top-level dispatcher block at line ~585 short-circuits adapter invocation when `_DI_LIVE_GATE_BLOCKED=1`. Adapter invocation at line ~586-589 conditionally appends `--model "$_DI_LIVE_MODEL_FLAG"`. Kill-switch branch additionally emits `live: true is inactive` warning when applicable.
- tools/verify/p04-sc2a-shadow-gate-block.sh — green: dispatch refuses adapter call, exits nonzero, JSONL records shadow_gate_blocked.
- tools/verify/p04-sc3-live-mechanical.sh — green: live-routed mechanical → fast-tier-id passed to stub-record-model, JSONL records resolution.fast.claude-code.
- tools/verify/p04-partial-flip-routing.sh — green: mechanical class flips, novel class withheld, JSONL records partial_flip_active=true + withheld_classes=novel.
- tools/verify/p04-con3-live-closure.sh — green: zero new provider-model-ID literals.
- tools/verify/p04-con4-live-killswitch.sh — green: kill-switch wins; override_source=disabled; stderr names live: true is inactive + min_tier inactive.
- bash tools/verify/p04-additive-schema.sh exits 0 with `SUMMARY: p04-additive-schema.sh pass=1 fail=0`.
- bash tools/verify/p04-override-source-enum-extended.sh exits 0 with `SUMMARY: p04-override-source-enum-extended.sh pass=6 fail=0` (Scenario F now strict-asserts shadow_gate_blocked).
- bash tools/verify/p04-sc2a-shadow-gate-block.sh exits 0 with `SUMMARY: p04-sc2a-shadow-gate-block.sh pass=3 fail=0` (3 assertions: nonzero exit + JSONL token + no dispatch-result).
- bash tools/verify/p04-sc3-live-mechanical.sh exits 0 with `SUMMARY: p04-sc3-live-mechanical.sh pass=3 fail=0` (3 assertions: JSONL model_used + stub-record-model file + dispatch exit 0).
- bash tools/verify/p04-partial-flip-routing.sh exits 0 with `SUMMARY: p04-partial-flip-routing.sh pass=6 fail=0` (3 assertions × 2 stages).
- bash tools/verify/p04-con3-live-closure.sh exits 0 with `SUMMARY: p04-con3-live-closure.sh pass=7 fail=0` (7 patterns).
- bash tools/verify/p04-con4-live-killswitch.sh exits 0 with `SUMMARY: p04-con4-live-killswitch.sh pass=4 fail=0` (4 assertions: override_source + model_used + stderr line × 2).

## Notes

Expected verifier output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p04-sc2a-shadow-gate-block.sh` -> 3 assertions pass; `SUMMARY: p04-sc2a-shadow-gate-block.sh pass=3 fail=0`, exit 0.
- `bash tools/verify/p04-sc3-live-mechanical.sh` -> 3 assertions pass; `SUMMARY: p04-sc3-live-mechanical.sh pass=3 fail=0`, exit 0.
- `bash tools/verify/p04-partial-flip-routing.sh` -> 6 assertions pass (3 per stage × 2 stages); `SUMMARY: p04-partial-flip-routing.sh pass=6 fail=0`, exit 0.
- `bash tools/verify/p04-con3-live-closure.sh` -> 7 patterns checked; `SUMMARY: p04-con3-live-closure.sh pass=7 fail=0`, exit 0.
- `bash tools/verify/p04-con4-live-killswitch.sh` -> 4 assertions pass; `SUMMARY: p04-con4-live-killswitch.sh pass=4 fail=0`, exit 0.

The recommended factoring (extract `_di_resolve_live_routing` as a top-level helper) is preferred because it makes the dispatcher's top-level shadow-gate-blocked check natural — the helper sets the sentinel, the dispatcher reads it. Without the extraction, the dispatcher would either (a) re-execute the resolution inline (duplication), or (b) call `_di_emit_dispatch_usage --resolve-only` (a new flag that runs the resolution but skips emission, then a second call to actually emit). Either alternative works; the extraction is cleanest.

The `M030_SHADOW_COMPARE_CORPUS` env var is the verifier seam — production dispatches DO NOT set it; the live-mode block falls back to `$log_file` (the in-flight log). Verifiers set it to a fixture corpus path so the verdict is deterministic without depending on prior dispatches in the test tmp_root. This pattern matches the `STUB_FAIL_COUNTER_FILE` env-var seam from T01.

The seven-step adapter invocation amendment (Block D) introduces a code duplication: two invocation paths (with/without `--model`) instead of one. This is acceptable per AD-19 — a single-line `[ -n "$_DI_LIVE_MODEL_FLAG" ] && extra_args="--model $_DI_LIVE_MODEL_FLAG"` followed by `bash "$ADAPTER" ... $extra_args` would risk word-splitting on the model ID; the explicit if/else is safer and AD-19-clean.

If the executor finds the verifier-seam env var (`M030_SHADOW_COMPARE_CORPUS`) too coupling, the alternative is a `--shadow-corpus <path>` flag added to dispatch-interface.sh's argument parser. The env var is preferred because (a) it preserves the existing CLI surface, (b) production dispatches never set it so the surface stays clean, and (c) verifiers already use env vars (`M030_SHADOW_MODE`, `CLAUDECODE`, `ORCHESTRATOR_ROOT`) for the same seaming pattern.

If `p04-sc2a-shadow-gate-block.sh` fails on assertion 3 (no dispatch-result emitted), the most likely cause is that the top-level shadow-gate-blocked check fires AFTER the adapter invocation rather than before. Re-check Step 5: the check MUST be inserted at line ~585 (BEFORE the adapter invocation block at line ~586), not at line ~620 (where the happy-path emit currently lives).

If `p04-partial-flip-routing.sh` fails for the novel-class stage with `model_used=<resolution.smart.claude-code>` instead of the runtime default, the partially_ready withheld-class branch is incorrectly resolving the model ID. Re-check Block C's partially_ready branch: when the task's class is in `withheld_classes`, `shadow_used` MUST be set to `$model` (runtime default) and `_DI_LIVE_MODEL_FLAG` MUST remain unset.

Per the operator-doc convention from P03/T03 (operator-facing docs co-locate with gate-verifier ship date), T02 SHOULD amend `references/model-routing.md` to add a `## Live Routing` section documenting the flip-gate behavior. However, given T03 also amends the same file (escalation docs), the recommendation is to defer ALL P04 references docs amendments to T03 and ship them as one section. T02 leaves `references/model-routing.md` untouched.

## State Context

- **Current State**: executing
- **Milestone**: M030
- **Phase**: P04
- **Task**: T02-live-routing-flip-gate
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **AD-19 single-script-file shape**: all verifier `Check:` invocations are `bash <single-path>.sh`. The amendment to `dispatch-interface.sh` is internal code; AD-19 governs the verifier-invocation shape, not the script's internal structure.
- **MEM004 emitter-internal carve-out**: `_di_emit_dispatch_usage` (or the new `_di_resolve_live_routing` helper) inherits the dispatch-internal-emitter carve-out — pipes / awk / `$()` permitted in their bodies. T02's amendments stay within this carve-out.
- **AP-009 compound-chain-gt2 (verifier shape)**: the five T02 verifiers MUST avoid `result=$(cmd | grep | head)` patterns. Use tmp-file intermediates: `cmd > /tmp/<f>.txt; grep ... < /tmp/<f>.txt > /tmp/<g>.txt; head -1 < /tmp/<g>.txt`.
- **CON-2 / FR-19 / SC-11 (additive-only schema)**: the shadow-OFF `printf` format strings MUST be byte-identical to the post-P03 form. T02's amendment touches ONLY the resolution logic (which feeds the shadow-on printfs' arguments) and the conditional `--model` flag passing to the adapter — NOT the shadow-off printfs themselves. Verified by `tools/verify/p04-additive-schema.sh`.
- **CON-3 (symbolic-tier closure)**: zero new literal provider model IDs in `dispatch-interface.sh`. The live branch's tier resolution flows through `templates/model-routing.yml resolution.<tier>.claude-code` via the same awk section-walker used by the existing P02 path. Verified by `tools/verify/p04-con3-live-closure.sh`.
- **CON-4 / D-A5 (kill switch supersedes live)**: the precedence chain MUST evaluate the kill switch FIRST. When both `model_routing_enabled: false` and `model_routing.live: true` are active, override_source MUST be `disabled` (NOT `shadow_gate_blocked`). The compound case emits a one-line stderr warning naming `live: true is inactive`. Verified by `tools/verify/p04-con4-live-killswitch.sh`.
- **CON-6 (append-only shadow corpus)**: the live-mode emit path uses `>> "$log_file"` only. No `mv`, no `cp`, no truncating `>`, no temp-file-and-swap. The P02 `tools/verify/p02-append-only.sh` continues to gate this property under HEAD; T02 does not re-author it.
- **D-A2 (programmatic flip-gate enforcement)**: the live branch MUST invoke `bash scripts/diagnostics/shadow-compare.sh` programmatically before the first live-routed dispatch. The verdict gates the adapter call. Verified by `tools/verify/p04-sc2a-shadow-gate-block.sh` (the gate refuses the adapter call when verdict is evidence_insufficient).
- **D-A3 (per-class partial-flip authorization)**: only classes whose routing-table default is `smart` may be enumerated in `withheld_classes` for the partially_ready verdict. T02 trusts shadow-compare's enumeration (which already enforces D-A3) and does not re-validate. Verified by `tools/verify/p04-partial-flip-routing.sh`.
- **CC-only launch posture**: live path requires `CLAUDECODE=1` AND `M030_SHADOW_MODE=1`. The live-routing block is wrapped in the same gate as the existing P02/P03 shadow path — Codex CLI / Cursor short-circuit to the pre-P02 emit (no live mode possible).
- **Bash 3.2 compatibility**: no `declare -A`, no `mapfile`, no `readarray`. The awk blocks are POSIX awk, not gawk-extended.
- **Plan-Time Discipline rule 5 (real-DB verification)**: T02 introduces no SQL — N/A.

### Acceptance Criteria

This task satisfies the phase truths:

- "scripts/dispatch/dispatch-interface.sh short-circuits before invoking any backend adapter when ... live: true AND ... evidence_insufficient ..." — gated by `tools/verify/p04-sc2a-shadow-gate-block.sh`.
- "SC-3 holds: with model_routing.live: true AND a shadow corpus passing the flip-readiness check ..." — gated by `tools/verify/p04-sc3-live-mechanical.sh`.
- "Partial-flip routing (D-A3) ..." — gated by `tools/verify/p04-partial-flip-routing.sh`.
- "The live-routing branch in dispatch-interface.sh introduces zero new hardcoded model IDs ..." — gated by `tools/verify/p04-con3-live-closure.sh`.
- "CON-4 / SC-7a-style compound (kill-switch wins in live mode) ..." — gated by `tools/verify/p04-con4-live-killswitch.sh`.
- "The override_source enum gains a sixth value shadow_gate_blocked ..." — gated by `tools/verify/p04-override-source-enum-extended.sh` (post-amendment-strict; T01's tolerant branch retires after T02 lands).
- "SC-11 byte-equality re-confirmed against P02's pre-M030 fixture ..." — gated by `tools/verify/p04-additive-schema.sh` (re-run against amended emitter).

### Files To Touch

- scripts/dispatch/dispatch-interface.sh (modify)
- scripts/dispatch/adapters/backend/stub-fail-n.sh (create)
- scripts/dispatch/adapters/backend/stub-record-model.sh (create)
- references/model-routing.md (modify)
- tests/fixtures/m030-p04/plans/plan-mechanical-no-override.md (create)
- tests/fixtures/m030-p04/plans/plan-fail-twice-then-pass.md (create)
- tests/fixtures/m030-p04/plans/plan-fail-three-times.md (create)
- tests/fixtures/m030-p04/plans/plan-fail-four-times.md (create)
- tests/fixtures/m030-p04/plans/plan-novel-class.md (create)
- tests/fixtures/m030-p04/configs/config-with-live-true.yml (create)
- tests/fixtures/m030-p04/configs/config-with-live-and-killswitch.yml (create)
- tests/fixtures/m030-p04/configs/config-with-live-false.yml (create)
- tests/fixtures/m030-p04/shadow-corpus-ready.jsonl (create)
- tests/fixtures/m030-p04/shadow-corpus-partially-ready.jsonl (create)
- tests/fixtures/m030-p04/shadow-corpus-empty.jsonl (create)
- tests/fixtures/m030-p04/round-trip-stage/intensity-metadata.txt (create)
- tests/fixtures/m030-p04/round-trip-stage/payload.txt (create)
- tools/verify/p04-additive-schema.sh (create)
- tools/verify/p04-override-source-enum-extended.sh (create)
- tools/verify/p04-sc2a-shadow-gate-block.sh (create)
- tools/verify/p04-sc3-live-mechanical.sh (create)
- tools/verify/p04-sc4-escalation-sequence.sh (create)
- tools/verify/p04-sc5-escalation-cap.sh (create)
- tools/verify/p04-con5-no-fourth-record.sh (create)
- tools/verify/p04-con6-prior-records-bit-identical.sh (create)
- tools/verify/p04-con3-live-closure.sh (create)
- tools/verify/p04-con4-live-killswitch.sh (create)
- tools/verify/p04-partial-flip-routing.sh (create)
- tools/verify/p04-escalation-fields-enum.sh (create)
- tools/verify/p04-phase-suite.sh (create)
- CLAUDE.md (modify — recent-changes region)
- AGENTS.md (modify if present — recent-changes region dual-write)

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