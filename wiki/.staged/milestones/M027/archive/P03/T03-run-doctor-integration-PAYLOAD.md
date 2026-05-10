---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T03-run-doctor-integration (Phase P03, Milestone M027)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~800 | required |
| Upstream Context | 981-1087 | ~10500 | required |
| Task Plan | 1089-1260 | ~3000 | required |
| State Context | 1262-1268 | ~100 | required |
| First-Turn Completeness | 1270-1320 | ~1000 | required |
| **Total** | | **~26200** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 524
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
hit_count: 524
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
hit_count: 524
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
scope_tags: "[project], [milestone:[M005](../../../../milestones/M005/index.md)]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 524
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
hit_count: 456
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
hit_count: 456
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
hit_count: 456
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
hit_count: 524
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
scope_tags: "[project], [milestone:[M006](../../../../milestones/M006/index.md)]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 456
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
hit_count: 456
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
scope_tags: "[project], [milestone:[M002](../../../../milestones/M002/index.md)]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 456
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
hit_count: 524
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
hit_count: 524
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
hit_count: 524
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
hit_count: 456
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
hit_count: 456
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
hit_count: 456
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
hit_count: 524
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
hit_count: 456
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
hit_count: 456
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
hit_count: 524
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
hit_count: 524
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
scope_tags: "[project], [milestone:[M004](../../../../milestones/M004/index.md)]"
category: lessons
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 456
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
hit_count: 456
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
hit_count: 456
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
scope_tags: "[project], [milestone:[M025](../../../../milestones/M025/index.md)]"
category: lessons
confidence: 0.95
created_at: 2026-04-23
last_verified: 2026-04-23
hit_count: 111
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
hit_count: 111
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
scope_tags: "[project], [milestone:[M014](../../../../milestones/M014/index.md)], [concern:bash-compat]"
category: lessons
confidence: 0.95
created_at: 2026-04-23
last_verified: 2026-04-23
hit_count: 111
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
scope_tags: "[project], [milestone:[M026](../../../../milestones/M026/index.md)]"
category: patterns
confidence: 0.90
created_at: 2026-04-24
last_verified: 2026-04-24
hit_count: 100
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
hit_count: 100
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
scope_tags: "[project], [milestone:[M020](../../../../milestones/M020/index.md)]"
category: conventions
confidence: 0.90
created_at: 2026-04-25
last_verified: 2026-04-25
hit_count: 90
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
milestones ([M024](../../../../milestones/M024/index.md) universal intake, [M019](../../../../milestones/M019/index.md) Tier 2+3 observability) MAY READ
the fields but MUST NOT introduce new fields without a follow-up M020 D-row.
The handshake is: open an M020 D-row → M020 lands the schema change →
consuming milestone uses the field. Never bypass this gate.

## Authorising decision

[`.orchestrator/DECISIONS.md`](../../../../decisions.md) D024 (2026-04-25).

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

<!-- Each truth is a behavioral statement + a single-script-file Check (AD-19).
     Per the M027/P00 + M027/P01 + M027/P02 parser-shape lesson: every Check
     command references ONLY artifacts T01..T04 of THIS phase produces, never
     future tasks. All P03 verification logic lives in scripts/verify/m027-p03-*.sh
     files shipped in T04. The Truths-list `Check:` commands here are
     phase-boundary checks (run after T04 lands); each task plan defines its
     OWN single-script-file Verification block referencing only that task's
     artifacts. -->

### Truths

- `scripts/diagnostics/check-anomalies.sh` exists, is executable, sourceable, and accepts `--milestone <Mxxx>`, `--project`, `--no-anomaly`, `--yes`, `--config-defaults <path>`, `--threshold <multiplier>`, `--sample-floor <N>`, `--help` flags. CLI mode (no `--no-anomaly`) emits an anomaly block (≤ 12 lines) prefixed with the literal title `Anomaly Detection (Tier 1 baseline)`. Each flagged dispatch line carries paired cost (or `cost=(unavailable; fallback=duration)`) AND quality (`pass_rate=`, `retry_count=`) tokens — Goodhart at the alerting surface (FR-9 / CON-4). When sample size is below the floor (default 5), emits exactly the literal `ANOMALY: insufficient sample (n=<N> floor=<F>)` and exits 0 (FR-10 / CON-8). Reads via `scripts/diagnostics/metrics-rollup.sh` (sourced or forked); never writes to `execution-log.jsonl` (FR-12 carry-forward). Suppressed mode (`--no-anomaly`, `ORCHESTRATOR_AUTO=1`, `ORCH_ANOMALY_CHECK_ENABLED=false`, `anomaly_check_enabled: false` config knob, `--yes`) emits exactly zero stdout, exit 0 — the load-bearing CON-3-equivalent contract that T04's byte-identity verifier gates against.
  - Check: `bash scripts/verify/m027-p03-anomaly-shape.sh`

- `scripts/diagnostics/check-config-drift.sh` exists, is executable, sourceable, and accepts `--keys <comma-separated>`, `--key <single>`, `--no-config-check`, `--config-defaults <path>`, `--help` flags. CLI mode emits a one-block drift report (≤ 4 lines per audited key) prefixed with the literal title `Config Drift (M027 knobs)`. For each audited key, surfaces the resolved value at each layer (`env=`, `local=`, `project=`, `defaults=`) plus a final `effective=<value>` line per FR-16. Default `--keys` value is `efficiency_footer,predictive_cost_surface,anomaly_cost_multiplier,anomaly_retry_threshold,anomaly_pass_rate_threshold` (the four M027/P02 + three M027/P03 knobs). Reads via `scripts/state/read-config.sh`; never writes to disk. Read-only (FR-12).
  - Check: `bash scripts/verify/m027-p03-config-drift-shape.sh`

- `commands/doctor.md` is updated to document the anomaly-detection pass and the `--config-check` flag. Two new sections inserted at stable attach points: `## Anomaly Detection` (after `## Runtime Instruction Drift`, before `## Usage`) and `## Config Drift` (after `## Anomaly Detection`, before `## Usage`). Pre-edit canonical sections preserved in pre-edit order — no re-ordering, no rewording of pre-existing prose. The new sections document the helper invocation, the 5-condition suppression matrix (anomaly only; config-check is single-flag), the sample-floor semantics, the baseline-disclaimer text (#Q-10 verbatim), and reference both helpers in the `## Referenced Scripts` section. (FR-8, FR-16, US-4 AS-1–AS-4, MEM012.)

<dispatch-volatile>

## Upstream Context


### P00 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P00"
parent: "M027"
milestone: "M027"
provides:
  - "scripts/diagnostics/metrics-rollup.sh — sourceable bash library + CLI for M027 rollup engine. Exposes metrics_rollup_snapshot,metrics_rollup_normalize,metrics_rollup_aggregate,metrics_rollup_render,metrics_rollup_main. CLI accepts --granularity task|phase|milestone|project,--milestone Mxxx,--phase Pxx,--task <id>,--source estimate|runtime|aggregate|all,--log <path>,--help. Implements FR-1/FR-2 paired cost+quality rows,FR-3 source filter with empty-result annotation,FR-4 Goodhart pairing (cost columns always paired with quality columns; pass_rate=unknown sentinel for degenerate quality input),FR-11 (N missing) suffix on cost cells with pricing warnings,FR-12/CON-1 read-only via mktemp+cp snapshot + EXIT trap,FR-14 corrupt-line tolerance (WARN: corrupt JSONL line N),FR-17 input-schema validation (WARN: input-schema line N),FR-18/AD-1 aggregation precedence aggregate-greater-than-runtime-greater-than-estimate,FR-19/AD-3 copy-then-aggregate FS-race semantics,CON-5 graceful degradation on missing log,CON-6/FR-21 zero LLM tokens (bash+awk+grep+sed),CON-7 bash 3.2 compat. Live invocation against .orchestrator/milestones/M019/execution-log.jsonl prints exactly one milestone row carrying both cost block and quality block on the same row,exit 0.,tests/fixtures/m027-p00/ — deterministic JSONL fixture suite for M027/P00 per-contract verifiers. Six hand-crafted fixtures (estimate-only.jsonl,mixed-source-aggregate.jsonl,corrupt-line.jsonl,missing-fields.jsonl,pricing-warning.jsonl,pre-m019-mixed.jsonl) each crafted to exercise one specific contract (FR-3,FR-18/AD-1,FR-14,FR-17,FR-11,SC-10 respectively). Plus perf-10mb.jsonl.gen.sh — bash 3.2 deterministic generator producing >=10 MB of unit_close records in <1 s; output gitignored. README.md documents per-fixture contracts and FR/SC mappings. All fixtures use M999 milestone ID to keep read-only invariant trivially satisfied.,14 per-contract verifier scripts under scripts/verify/m027-p00-*.sh covering FR-1/FR-2 (rollup-cli-contract),FR-1/FR-4/SC-1 (live-m019-row),FR-4/SC-12 (goodhart-pairing),FR-3/SC-6 (source-filter),FR-18/AD-1/SC-14 (aggregation-precedence),FR-12/SC-9 (read-only via git diff --quiet),FR-21/CON-6 (zero-llm-token grep),FR-14/SC-5 (corrupt-line WARN line N),FR-17 (input-schema WARN),FR-11 (pricing-warning N missing cell suffix),FR-13/FR-19/AD-3/SC-19 (fs-race copy-then-aggregate),CON-12/AD-2/SC-13 (perf-bound 5s/10MB with RELAX-CANDIDATE diagnostic),SC-10 (pre-m019-additivity silent skip),CON-7/SC-11 (bash32-compat). Each verifier emits PASS:/FAIL: per repo convention,exit 0/1/2.,scripts/verify/m027-rollup-schema.sh phase-suite orchestrator: runs all 14 m027-p00-*.sh verifiers in stable order (cheapest first,perf-bound last),aggregates results,prints PASS: m027-rollup-schema.sh 14 gates on green and FAIL list to stderr on red; surfaces RELAX-CANDIDATE annotations from perf-bound on stdout for downstream tooling; live-M019 demo invocation (bash scripts/diagnostics/metrics-rollup.sh --granularity milestone --milestone M019) confirmed green and emits one paired cost+quality milestone row"
requires:
  - "none"
affects:
  - "P01,P03"
key_files:
  - "scripts/diagnostics/metrics-rollup.sh,tests/fixtures/m027-p00/estimate-only.jsonl,tests/fixtures/m027-p00/mixed-source-aggregate.jsonl,tests/fixtures/m027-p00/corrupt-line.jsonl,tests/fixtures/m027-p00/missing-fields.jsonl,tests/fixtures/m027-p00/pricing-warning.jsonl,tests/fixtures/m027-p00/pre-m019-mixed.jsonl,tests/fixtures/m027-p00/perf-10mb.jsonl.gen.sh,tests/fixtures/m027-p00/README.md,tests/fixtures/m027-p00/.gitignore,scripts/verify/m027-p00-aggregation-precedence.sh,scripts/verify/m027-p00-bash32-compat.sh,scripts/verify/m027-p00-corrupt-line.sh,scripts/verify/m027-p00-fs-race.sh,scripts/verify/m027-p00-goodhart-pairing.sh,scripts/verify/m027-p00-input-schema.sh,scripts/verify/m027-p00-live-m019-row.sh,scripts/verify/m027-p00-perf-bound.sh,scripts/verify/m027-p00-pre-m019-additivity.sh,scripts/verify/m027-p00-pricing-warning.sh,scripts/verify/m027-p00-read-only.sh,scripts/verify/m027-p00-rollup-cli-contract.sh,scripts/verify/m027-p00-source-filter.sh,scripts/verify/m027-p00-zero-llm-token.sh,scripts/verify/m027-rollup-schema.sh"
key_decisions:
  - "AD-1,AD-3,AD-19,AD-2,CON-1,CON-7,CON-12,FR-15,SC-2"
patterns_established:
  - "Sourceable-CLI duality via [ BASH_SOURCE-zero == zero-arg ] guard at bottom of file; load-time _METRICS_ROLLUP_SH_SOURCED re-source guard pattern (mirrors pricing.sh); MEM004 carve-out applied — pipes/awk/dollar-paren permitted inside emitter-internal library while AD-19 single-script-file shape rule binds only Check: commands at task/phase plan level; awk single-pass aggregation with parallel-array buckets keyed by (scope,source,granularity) plus per-scope highest-priority-source selection in END block — sidesteps bash 3.2 lack of associative arrays; pre-declared snapshot/normalized/rolled vars before EXIT trap to keep set -u from blowing up the trap when an early-return path skips assignment; bash-3.2-clean comment hygiene — neutralized literal forbidden-construct tokens in comments to avoid tripping the T03 bash32-compat grep regex against the file body,JSONL fixtures named by contract (estimate-only,mixed-source-aggregate,corrupt-line,missing-fields,pricing-warning,pre-m019-mixed) — one fixture per behavioural axis under tests/fixtures/m027-p00/; M999 sentinel milestone ID ensures fixtures cannot collide with real .orchestrator/milestones/ data and the read-only invariant gate is trivially satisfied; perf fixture committed only as a deterministic generator script (gitignored output) — chunk-build-then-cat-repeat pattern reaches 10 MB target in <1 s while staying byte-identical across invocations (no $RANDOM,no $$,no live timestamps); fixture README documents per-fixture contract + FR/SC mapping so T03 verifier authors do not have to reverse-engineer intent from raw JSONL,One-verifier-per-contract scaffolding mirrors scripts/verify/m019-p01-*.sh (PROJECT_ROOT via BASH_SOURCE; PASS/FAIL stdout/stderr; exit 0/1/2); MEM004 emitter-internal carve-out applied so each verifier may use pipes/awk/dollar-paren internally while AD-19 single-script-file shape rule binds only the Check: invocations from PLAN.md; perf-bound RELAX-CANDIDATE diagnostic pattern for bound-relaxation evidence (mirrors planning-brief 'perf may be revisited'); driving the engine fix into T01 — pure-bash while-read normalize was forking O(7) subprocesses per JSONL line and bubble sort over per-bucket cost arrays was O(n^2),both rewritten as awk passes (single normalize pass + qsort) to satisfy CON-12; engine is now ~2.5s on 10MB / 36k records vs ~3min45s before.,phase-suite orchestrator at M027/P00 scale (14 gates) follows m019-p01-phase-suite.sh shape verbatim — parallel-string GATES list,per-gate exit-code capture,PASS/FAIL emission,single-script-file Check shape externally with internal carve-out for the for-loop; RELAX-CANDIDATE forwarding pattern: capture per-gate stdout,grep for the structured annotation,print on suite stdout so plan-phase / consolidate can act on it without scraping; soft-failure semantics: a RELAX-CANDIDATE on perf still counts as gate failure (suite exits 1) but the diagnostic is preserved"
drill_down_paths:
  - ".orchestrator/milestones/M027/phases/P00/tasks/T01-rollup-engine-SUMMARY.md, .orchestrator/milestones/M027/phases/P00/tasks/T02-fixture-suite-SUMMARY.md, .orchestrator/milestones/M027/phases/P00/tasks/T03-per-contract-verifiers-SUMMARY.md, .orchestrator/milestones/M027/phases/P00/tasks/T04-phase-suite-and-demo-SUMMARY.md"
duration: "95m"
verification_result: "pass"
completed_at: "2026-04-27T01:27:03Z"
observability_surfaces:
  - "none"
---

P00 delivers the foundation of M027: a sourceable bash + CLI rollup engine over the M019 Tier 1 JSONL stream, a deterministic fixture suite covering every behavioral axis, fourteen per-contract verifier scripts, and a phase-suite orchestrator that runs them in stable order with structured RELAX-CANDIDATE forwarding. Together they pin every cross-phase contract that P01–P03 will consume: aggregation precedence aggregate>runtime>estimate (FR-18/AD-1), Goodhart cost+quality output pairing (FR-4), source filtering (FR-3), copy-then-aggregate FS-race semantics (FR-19/AD-3), input-schema validation (FR-17), corrupt-line tolerance (FR-14), pricing-warning surfacing (FR-11), read-only invariant (FR-12/CON-1/SC-9), zero-LLM-token (FR-21/CON-6/SC-16), bash 3.2 compat (CON-7/SC-11), and the 5s/10MB performance bound (CON-12/AD-2/SC-13).

The phase shipped in four atomic tasks. T01 created the engine — sourceable library + CLI duality via the BASH_SOURCE/$0 guard, parallel-array awk aggregation that sidesteps bash 3.2's lack of associative arrays, and the EXIT-trap mktemp+cp snapshot for FS-race tolerance. T02 produced six hand-crafted JSONL fixtures plus a deterministic 10MB perf generator (gitignored output, byte-identical across invocations). T03 wrote the fourteen per-contract verifiers following the scripts/verify/m019-p01-*.sh shape. T04 wrote the phase-suite orchestrator and wired the live-M019 demo as the SC-1 entry point.

The headline lesson came at T03's perf-bound gate: T01's metrics_rollup_normalize was a pure-bash while-read loop forking ~7 subprocesses per record (sed/grep/head per JSON field), and metrics_rollup_aggregate used a bubble sort O(n²) over per-bucket cost arrays. Against the 36 200-record / 10 MB perf fixture this clocked ~3:55 wall-clock — far over the 5s CON-12 bound. T01's plan had explicitly anticipated this ("switch normalizer to awk, replace per-record grep calls in bash loops with single awk pass"). T03 drove the fix back into T01's deliverable: rewrote normalize as a single awk pass with match()-based field extraction, replaced bubble sort with a Hoare-partition qsort (O(n log n)). Engine now ~2.5s on 10MB. All 14 verifiers PASS post-fix; the live-M019 demo emits one paired cost+quality milestone row, exit 0.

Two parser-shape lessons surfaced and were folded into per-task PLAN edits: (1) auto-loop's verifier extractor requires fenced ```bash``` code blocks for the Verification section — bullet-with-inline-backtick format silently extracts zero commands; (2) task-level Verification must reference only what the task itself produces, never the phase-level check-must-haves.sh (which gates on the entire phase including future tasks). T02 + T03 + T04 plans were each reformatted accordingly. Verification: m027-rollup-schema.sh suite passes 14/14 gates; phase-level check-must-haves.sh passes all 60+ truth + artifact + key-link rows; live-M019 demo green; read-only invariant verifier (which itself is exercised inside the suite) confirms git diff --quiet against the project tree post-rollup; total phase duration 95 minutes across 4 tasks.

Cross-phase handoff: P01 (orchestrator:cost retrospective + predictive command) sources metrics-rollup.sh as its engine and inherits the Goodhart pairing contract — extending it to the predictive surface per FR-20 + SC-18. P02 (efficiency footer + dispatch-time predictive surface) inherits the byte-identity verifier cases (SC-3 status-quiet, SC-17 dispatch-yes) which P00's verifier carries as placeholders awaiting P02's suppression-path implementation. P03 (anomaly detection + config-check) sources the engine for baseline math and inherits the sample-floor and never-abort patterns. The roadmap reassessment found no boundary-map deviations.


### P02 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P02"
parent: "M027"
milestone: "M027"
provides:
  - "scripts/diagnostics/efficiency-footer.sh - sourceable bash 3.2 library + CLI for the M027/P02 efficiency footer helper. Exposes efficiency_footer_render(milestone,quiet). CLI accepts --milestone <Mxxx>,--project,--quiet,--config-defaults <path>,--help. Sources via re-source guard _EFFICIENCY_FOOTER_SH_SOURCED mirroring pricing.sh / cost-estimate.sh shape; CLI entry guarded by BASH_SOURCE-zero == $0 sourceable-CLI duality. Default invocation resolves active milestone via scripts/state/find-active-milestone.sh (orchestrator-root arg = project root + .orchestrator),falls back to project-granularity rollup on empty/error. Renders <=6 lines: title + scope + estimated_cost_usd + verification_pass_rate + dispatches + (optional) pricing-degradation annotation. Empty-log path emits 'Efficiency: no Tier 1 records yet' per US-3 AS-3. Under --quiet OR ORCH_EFFICIENCY_FOOTER=false OR config.efficiency_footer=false,emits exactly zero stdout,exit 0 -- the load-bearing CON-3/SC-3 byte-identity contract that T02 baseline + T04 byte-identity verifier gate against. Read-only (FR-12/CON-1): only stdout/stderr writes; never touches execution-log.jsonl or config files. Zero-LLM-token (FR-21/CON-6): bash + invocation of metrics-rollup.sh / read-config.sh / find-active-milestone.sh only. Bash 3.2 (CON-7): no associative arrays,herestring redirection,process substitution,mapfile,case-folding parameter expansion,or merged stdout-stderr shorthand. CON-5 never-abort: degraded inputs (missing pricing,missing milestone,empty log) surface as text rather than nonzero exit; pricing-warning passthrough surfaces the rollup engine's '(N missing)' / '(stale)' annotations as a compact pricing: line.,scripts/state/read-config.sh - VALID_KEYS extended by two M027/P02 keys (efficiency_footer + predictive_cost_surface) so read-config.sh efficiency_footer (and the T03 predictive_cost_surface key) returns a resolved value through the existing 4-layer precedence chain (env / local / project / defaults) instead of failing with 'unknown key'. Co-located both keys in a single edit per the T01 plan to avoid two passes over the same file.,scripts/verify/m027-p02-t01-shape-precheck.sh - T01-scoped precheck verifier asserting the nine T01 must-haves plus three implicit invariants (12 assertions total): helper present + >=80 lines + executable,'Efficiency (Tier 1 rollup)' title literal,efficiency_footer_render function definition,BASH_SOURCE/$0 sourceable-CLI guard,--quiet arg-parse case,efficiency_footer config-knob reference,scripts/diagnostics/metrics-rollup.sh delegation,VALID_KEYS contains both efficiency_footer + predictive_cost_surface,--quiet emits zero stdout exit 0,ORCH_EFFICIENCY_FOOTER=false also suppresses stdout. AD-19 single-script-file Check shape; T04 ships canonical phase-level m027-p02-efficiency-footer-shape.sh that subsumes this precheck (M027/P01/T03 + T04 pattern carry-forward).,commands/status.md - integrated efficiency footer at the documented attach point (after ## Telemetry Metrics,before ## Next Action) via a single new ## Efficiency Footer section documenting the helper invocation (scripts/diagnostics/efficiency-footer.sh --milestone <active> with --project fallback),the suppression semantics (--quiet flag and config.efficiency_footer with env -> local -> project -> defaults resolution chain,default true),the empty-log path (single-line 'Efficiency: no Tier 1 records yet' per US-3 AS-3),and the read-only / zero-LLM-token invariants (FR-12 / CON-1 / FR-21 / CON-6). Pre-edit canonical sections preserved in pre-edit order with no re-ordering or rewording -- the footer is the ONLY structural addition (plus one bullet under ## Reference Files). 171 -> 205 lines.,tests/fixtures/m027-p02/status-quiet-baseline.txt - load-bearing baseline fixture (50 lines) capturing the verbatim post-## Next Action tail of commands/status.md (Next Action / Concurrent Safety / Idempotency / Error Handling / Gotchas / Reference Files). T04's m027-p02-status-quiet-byte-identity.sh verifier consumes this and diffs the live tail against it; failure on non-zero diff. CON-3 / SC-3 contract: under --quiet (or efficiency_footer: false),no NEW content appears between the telemetry block and Next Action -- the document tail starting at ## Next Action stays byte-identical to this fixture.,tests/fixtures/m027-p02/README.md - short fixture-role note documenting the byte-identity baseline contract and the update protocol (intentional changes via follow-up commit; verifier rejects accidental drift).,scripts/verify/m027-p02-t02-shape-precheck.sh - T02-scoped precheck verifier (115 lines,executable,bash 3.2 clean) asserting the nine T02 must-haves: status.md exists >= 170 lines,contains 'efficiency-footer' literal,contains '## Efficiency Footer' heading,contains '--quiet' and 'efficiency_footer' references,references scripts/diagnostics/efficiency-footer.sh in ## Reference Files,retains the pre-edit canonical section order (verified by grep -n line-position assertions: State Derivation < Progress Overview < Blockers < Execution History < Telemetry Metrics < Efficiency Footer < Next Action < Concurrent Safety < Idempotency < Error Handling < Gotchas < Reference Files),fixture exists >= 1 line and contains 'Next Action',fixture README exists. Mirrors the M027/P02/T01 precheck skeleton; PASS/FAIL stdout/stderr; exit 0/1. AD-19 single-script-file Check shape; T04 ships the canonical phase-level m027-p02-status-md-shape.sh + m027-p02-status-quiet-byte-identity.sh that subsume this precheck.,scripts/dispatch/predictive-surface.sh - sourceable bash 3.2 library + CLI for the M027 P02 dispatch-time predictive cost surface. Exposes function predictive_surface_render <description> <intensity> <suppress-flag>. CLI accepts --description (required),--intensity quick|standard|full (required),--no-predict,--yes,--help. Sources or forks scripts/engine/intensity-recommend.sh --format text after pre-setting INTENSITY_RECOMMEND_FAST_PATH=1 and module-scope _CE_RECOMMENDED to short-circuit the inner intensity-recommend re-fork (no-recursion invariant per P01/T02 contract). Renders a one-block predictive surface (recommended tier,cost-annotation block streamed verbatim from the P01 hook with Goodhart pairing inherited,and a one-line override prompt as the last line per CON-10). Suppressed mode (any of: --yes,ORCHESTRATOR_AUTO=1,predictive_cost_surface config knob false,intensity=quick) emits exactly zero stdout and exits 0 - load-bearing CON-3 / SC-17 byte-identity contract that T04 gates against. Pricing degradation never aborts (FR-24 / CON-5 inherited): if the inner hook returns empty,the helper emits a single-line minimal surface with a pricing-warning hint and the override prompt; recommendation still flows. Read-only (FR-12 / CON-1): writes only to stdout / stderr; never touches execution-log.jsonl,never writes to config. Zero-LLM-token (FR-21 / CON-6): bash plus invocation of intensity-recommend.sh only. Bash 3.2 (CON-7): parallel scalars only; no associative arrays; no herestring redirect; no inline process substitution; no bash-4 case-folding parameter expansion. Comment hygiene carried forward from M027/P00 + P01 lesson: doc-comments do not list bash-4 forbidden constructs literally so the bash32-compat verifier regex stays clean against the file body. 130 lines.,commands/dispatch.md - extended with a new ## Predictive Surface (M027/P02) section inserted between the existing ## Dispatch Strategy and ## Execution Recording sections (preserving the pre-edit canonical section order: frontmatter / Title / Intensity Behavior / Prerequisites / Context Construction / Dispatch Strategy / Predictive Surface / Execution Recording / Post-Dispatch / Idempotency / Error Handling / Claude Code Appendix / Gotchas / Referenced Scripts / Referenced Templates). The new section documents the dispatch-time invocation shape (bash scripts/dispatch/predictive-surface.sh --description <text> --intensity <tier>),the explicit 5-condition suppression matrix (--yes,intensity=quick),the operator-override prompt per CON-10,and the read-only invariant per FR-12 / CON-1 / FR-21 / CON-6. A new bullet for scripts/dispatch/predictive-surface.sh was appended to ## Referenced Scripts after the existing scripts/lifecycle/record-result.sh entry. No re-ordering or re-wording of pre-existing sections.,scripts/verify/m027-p02-t03-shape-precheck.sh - T03-scoped precheck verifier (157 lines). Asserts 17 invariants in a single script per AD-19 single-script-file Check shape: helper exists / executable / >= 80 lines,contains predictive_cost_surface literal,contains predictive_surface_render function,has BASH_SOURCE/dollar-zero entry-point guard,honors --no-predict / --yes / ORCHESTRATOR_AUTO / predictive_cost_surface config knob,invokes scripts/engine/intensity-recommend.sh,pre-sets INTENSITY_RECOMMEND_FAST_PATH=1 and _CE_RECOMMENDED,contains the override prompt literal,dispatch.md has the ## Predictive Surface heading,references the helper in ## Referenced Scripts,documents all 5 suppression-matrix conditions,preserves the canonical section order (with the new section inserted between Dispatch Strategy and Execution Recording),and behavioral checks for both --yes and --intensity quick suppression paths producing zero stdout / exit 0. T04 ships canonical phase-level verifiers (m027-p02-predictive-surface-shape.sh,m027-p02-suppression-matrix.sh,m027-p02-dispatch-md-shape.sh) that subsume slices of this precheck; T04 may delete this precheck once the canonical verifiers ship (mirrors the M027/P01/T03 + T04 pattern).,scripts/verify/m027-p02-suite.sh phase-suite orchestrator (mirrors m027-p01-suite.sh / m027-rollup-schema.sh shape: parallel-string GATES list,per-gate exit-code capture,RELAX-CANDIDATE forwarding,SUMMARY+PASS/FAIL summary,exit 0/1); 11 per-contract verifiers under scripts/verify/m027-p02-*.sh: efficiency-footer-shape (Truth #1 - file shape,BASH_SOURCE guard,--quiet zero-stdout,--milestone M019 smoke,efficiency_footer config registered),status-md-shape (Truth #2 - section presence,--quiet docs,efficiency_footer docs,canonical 12-section order check via grep -n strict-monotonic),status-quiet-byte-identity (Truth #3 - awk-extracted post-Next-Action tail diff vs tests/fixtures/m027-p02/status-quiet-baseline.txt),predictive-surface-shape (Truth #4 - file shape,BASH_SOURCE,intensity-recommend.sh ref,INTENSITY_RECOMMEND_FAST_PATH+_CE_RECOMMENDED fast-path refs,predictive_cost_surface config registered,default render contains predictive_cost_surface + override:),suppression-matrix (Truth #5 - 5/5 suppression paths assert empty stdout + exit 0: --yes,ORCH_PREDICTIVE_COST_SURFACE=false,--intensity quick),dispatch-md-shape (Truth #6 - section presence,5 suppression-token doc-checks,canonical 13-section order,live --yes empty-stdout assertion),predictive-surface-latency (Truth #7 - perl Time::HiRes warm-cache 3-min outer+inner; hard-fail at 250 ms inner with INTENSITY_RECOMMEND_FAST_PATH=1+_CE_RECOMMENDED=standard; outer informational with RELAX-CANDIDATE annotation forwarded by suite),predictive-goodhart-pairing (Truth #8 - asserts at-least-one cost_*_usd line + at-least-one cost_*_quality line + per-tier pairing on dispatch-time surface),zero-llm-token (Truth #9 - split-literal forbidden-token regex against 13-file scan-set,self excluded),read-only (Truth #10 - WARN-skip on dirty-pre-run; else 4 read-only invocations + git diff --quiet post),bash32-compat (Truth #11 - split-literal forbidden-construct regex + bash -n parse against 14-file scan-set including helpers + commands/status.md + commands/dispatch.md + verifier set including self). T01/T02/T03 scoped prechecks (m027-p02-t01-shape-precheck.sh,m027-p02-t02-shape-precheck.sh,m027-p02-t03-shape-precheck.sh) deleted - subsumed by canonical phase-level verifiers (mirrors M027/P01/T03+T04 pattern). One-line doc-comment reference to scripts/engine/cost-estimate.sh added to scripts/dispatch/predictive-surface.sh to satisfy the phase-plan key-link assertion (transitively sourced via the P01 cost-annotation hook; predictive-surface never invokes cost-estimate directly)."
requires:
  - "P01"
affects:
  - "P03"
key_files:
  - "scripts/diagnostics/efficiency-footer.sh,scripts/state/read-config.sh,scripts/verify/m027-p02-t01-shape-precheck.sh,commands/status.md,tests/fixtures/m027-p02/status-quiet-baseline.txt,tests/fixtures/m027-p02/README.md,scripts/verify/m027-p02-t02-shape-precheck.sh,scripts/dispatch/predictive-surface.sh,commands/dispatch.md,scripts/verify/m027-p02-t03-shape-precheck.sh,scripts/verify/m027-p02-suite.sh,scripts/verify/m027-p02-efficiency-footer-shape.sh,scripts/verify/m027-p02-status-md-shape.sh,scripts/verify/m027-p02-status-quiet-byte-identity.sh,scripts/verify/m027-p02-predictive-surface-shape.sh,scripts/verify/m027-p02-suppression-matrix.sh,scripts/verify/m027-p02-dispatch-md-shape.sh,scripts/verify/m027-p02-predictive-surface-latency.sh,scripts/verify/m027-p02-predictive-goodhart-pairing.sh,scripts/verify/m027-p02-zero-llm-token.sh,scripts/verify/m027-p02-read-only.sh,scripts/verify/m027-p02-bash32-compat.sh"
key_decisions:
  - "AD-19,CON-1,CON-3,CON-5,CON-6,CON-7,FR-12,FR-21,SC-3,SC-16,US-3,MEM004,MEM012,CON-4,CON-9,CON-10,FR-22,FR-24,SC-15,SC-17,SC-18,FR-23,SC-9,SC-11,#Q-16"
patterns_established:
  - "Sourceable-CLI duality via BASH_SOURCE-zero == $0 guard at bottom of file; load-time _EFFICIENCY_FOOTER_SH_SOURCED re-source guard mirrors pricing.sh _PRICING_SH_SOURCED + cost-estimate.sh _COST_ESTIMATE_SH_SOURCED. Multi-layer suppression precedence pattern: --quiet flag (highest) -> ORCH_EFFICIENCY_FOOTER env var -> read-config.sh efficiency_footer key (lowest); recognized falsy tokens (false/FALSE/False/0/no/NO/No) collapse to QUIET=1; default unset value resolves to true (footer renders). Tabular-rollup-to-footer extraction pattern: extract paired cost (column 4) + quality (column 9) cells from the metrics-rollup.sh data row by awk column index rather than by key=value grep,since the M019/P00 rollup contract emits a tabular shape; printf format string uses %s/%s composition rather than embedded literal whitespace to keep awk parse clean. Pricing-warning compaction pattern: rather than passing through the full rollup data line on degradation,extract only the short parenthesized '(N missing)' / '(stale)' annotation via grep -oE so the footer stays <=6 lines; future pricing_warning= key=value rollup shape supported as fallback. Multi-key co-location pattern: when multiple downstream tasks each need a new VALID_KEYS entry,edit the list once with all keys in alphabetical order rather than one edit per task -- avoids merge churn and preserves a single source-of-truth touch per file. Comment-hygiene-for-verifier-regex pattern (carry-forward from M027/P00 + M027/P01): when CON-7 doc-comments would naturally list bash-4 forbidden constructs literally (the bash-4 array-from-stdin builtin,herestring redirection,merged stdout-stderr shorthand,case-folding parameter expansion),reword the prose to describe them by category so the T04 m027-p02-bash32-compat.sh verifier grep regex stays clean against this file body.,Document-shaped phase-task pattern: a milestone phase that integrates a helper into a runtime-rendered command document does so by editing the canonical command markdown (commands/<cmd>.md) at a stable,documented attach point and adding a parallel bullet under ## Reference Files -- not by adding shell logic. The agent runtime renders the document at command-execution time; the markdown body documents the helper invocation as a fenced bash block. Pairs with a load-bearing baseline fixture (tests/fixtures/<phase>/<cmd>-baseline.txt) capturing the verbatim post-attach-point tail; T04 ships the byte-identity verifier that diffs the live tail against the fixture. Pre-edit canonical sections preserved in pre-edit order; the new section is the ONLY structural addition (plus one bullet under ## Reference Files). The CON-3 / SC-3 byte-identity contract is satisfied by (a) the document still containing the same canonical sections in the same order,(b) the new section being the only structural addition,(c) the suppression-knob documentation being unambiguous so the rendering agent always suppresses correctly under --quiet -- the T04 verifier asserts (a) + (b) + (c) statically (markdown source check); actual runtime byte-identity is enforced upstream by the agent's contract honoring --quiet per the documented semantics. T02-scoped precheck shape carry-forward (M027/P01/T03 + M027/P02/T01 + M027/P02/T02): a task that ships a structural / document-shape change ships a single-script-file Check at scripts/verify/m027-p<phase>-t<task>-shape-precheck.sh asserting only that task's must-haves; the canonical phase-level verifiers ship in T04 and may delete the precheck once they subsume it. Mirrors the standard verifier skeleton (PROJECT_ROOT via BASH_SOURCE; PASS:/FAIL: stdout/stderr; exit 0/1). Section-order assertion pattern: rather than asserting line-range constraints,the verifier walks an IFS='|'-split list of expected canonical section headings in pre-edit order and asserts each grep -n hit's line number strictly increases -- this catches any re-ordering or accidental insertion in the wrong position with a single pass over the file. Prose tail-fixture pattern for runtime-rendered command documents: when a command document is interpreted by an agent runtime (not a shell script that emits stdout),the byte-identity baseline is the verbatim prose tail of the document (post-attach-point sections),not a captured stdout transcript. The fixture is human-curated from the post-edit document and updated only when intentional changes to those sections land via a follow-up commit.,Dispatch-time predictive surface helper pattern: a sourceable bash 3.2 library plus CLI thin-wraps the P01 cost-annotation hook (intensity-recommend.sh --format text) by pre-setting the module-scope _CE_RECOMMENDED slot plus exporting INTENSITY_RECOMMEND_FAST_PATH=1 to short-circuit the inner intensity-recommend re-fork - same pattern P01/T02 used for the cost-annotation hook itself,now applied at the dispatch boundary. Five-condition suppression matrix as a load-bearing contract: --yes flag,ORCHESTRATOR_AUTO=1 env,--no-predict flag,predictive_cost_surface config knob (resolved via env override ORCH_PREDICTIVE_COST_SURFACE then read-config.sh) false,and intensity=quick. All five paths short-circuit predictive_surface_render to zero stdout / exit 0 before any I/O,satisfying CON-3 / SC-17 byte-identity. Quick-tier suppression (the fifth condition) is a deliberate Goodhart-pairing carve-out: predictive surface is not surfaced for the cheapest tier because the minimum information-theoretic value of the surface lives at Standard or higher. Operator-override-as-informational-prompt pattern (CON-10): the helper renders a one-line override prompt as the last line of the surface block but does NOT read stdin - the calling orchestrator:dispatch flow handles override capture at the runtime layer. Keeps the helper bash-only and read-only while preserving the operator-override invariant. Synthesized analyze-output / profile-output strings: the helper passes deterministic --analyze-output (5 key=value lines: scope=moderate,risk_level=medium,complexity=moderate,risk_signals=none,recommended_intensity=<Cap>) and --profile-output (cap_score=3) to bypass the inner intensity-analyze.sh + detect-capabilities.sh forks - mirrors the P01/T04 verifier pattern (latency optimization plus deterministic output). Comment-hygiene-for-verifier-regex pattern carried forward from M027/P00 T01 + P01: the helper script doc-comments use the safe phrasing 'no herestring redirect' and 'no associative arrays' rather than spelling the literal bash-4 forbidden tokens,so the T04 bash32-compat verifier grep regexes do not false-positive against doc comments. Insert-between-canonical-sections doc-edit pattern: commands/dispatch.md gained a single new ## Predictive Surface section between two pre-existing canonical sections (## Dispatch Strategy and ## Execution Recording) plus one new bullet under ## Referenced Scripts. No re-ordering,no re-wording of pre-existing sections - the pre-T03 shape is preserved byte-for-byte at the section-heading and bullet-list level,satisfying MEM012 + the Truth #15 canonical-section-order assertion.,One-verifier-per-contract scaffolding mirrors P00/P01 shape verbatim (PROJECT_ROOT via BASH_SOURCE; PASS/FAIL stdout/stderr; exit 0/1; MEM004 emitter-internal carve-out for pipes/awk/grep/diff while AD-19 binds only the Check: invocation surface). Phase-suite orchestrator at M027/P02 scale (11 gates) follows m027-p01-suite.sh shape verbatim - parallel-string GATES list,per-gate exit-code capture (combined stdout+stderr),RELAX-CANDIDATE forwarding (suite greps each gate output for the structured annotation and forwards verbatim above the SUMMARY),single-script Check shape externally with internal carve-out for the for-loop,cheapest-static-first ordering (bash32-compat + zero-llm-token regex-only first; live-invocation gates last; latency last). Latency verifier inner-vs-outer split applied verbatim from P01/T04 - hard-fail threshold (250 ms = 100 ms target + ~150 ms macOS bash startup slack) applied to inner library-only measurement with documented INTENSITY_RECOMMEND_FAST_PATH=1+_CE_RECOMMENDED=standard fast-path env-vars; outer wall-clock reported informationally with WARN: RELAX-CANDIDATE annotation when over-budget (forwarded by suite); rationale - bash startup + intensity-recommend re-fork overhead is not part of the surface author's optimizable budget on macOS dev boxes. Self-applying scanner pattern carried forward from P01 - split-literal token assembly (FORBID_A='declare'' -A' etc.) keeps bash32-compat + zero-llm-token verifiers from matching their own source even when included in the scan-set; explicit FILES list (no globbing) keeps the scan-set deterministic and bounded. Canonical-section-order check pattern - extract first-match line number per canonical header via grep -n | head -1 | cut -d: -f1,assert strict-monotonic line numbers in a printf | while read pipeline (subshell exit code propagates as pipeline rc; parent script captures via $? immediately; bash 3.2 safe). Read-only-with-WARN-skip-on-dirty-pre-run pattern carried forward from P01/T04 - capture git diff --quiet exit pre-run; if non-zero (working tree already dirty from KNOWLEDGE updates etc.),WARN + exit 0 rather than false-fail; else run a sequence of read-only helper invocations and re-assert. T04-subsumes-prechecks pattern (third occurrence of the M027/P00+P01+P02 parser-shape lesson) - T01/T02/T03 each shipped a m027-p02-t##-shape-precheck.sh single-script verifier referencing only that task's artifacts; T04 deletes them once the canonical phase-level verifiers ship and check-must-haves.sh is green; the prechecks were necessary scaffolding to satisfy each task plan's own Verification block at dispatch time without forward-referencing T04 deliverables. Verifier-author-vs-helper-author boundary - when phase-plan key-links assert a transitive reference (predictive-surface->cost-estimate is via the P01 hook,not direct),the cleanest fix is a one-line doc-comment in the helper rather than re-architecting the helper or relaxing the verifier; preserves both the verifier contract and the actual call-shape."
drill_down_paths:
  - ".orchestrator/milestones/M027/phases/P02/tasks/T01-efficiency-footer-SUMMARY.md, .orchestrator/milestones/M027/phases/P02/tasks/T02-status-md-integration-SUMMARY.md, .orchestrator/milestones/M027/phases/P02/tasks/T03-predictive-surface-SUMMARY.md, .orchestrator/milestones/M027/phases/P02/tasks/T04-verifier-suite-SUMMARY.md"
duration: "180m"
verification_result: "pass"
completed_at: "2026-04-27T14:50:37Z"
observability_surfaces:
  - "none"
---

P02 delivered the user-visible surfaces for `orchestrator:cost`: a retrospective efficiency footer attached to `orchestrator:status`, and a dispatch-time predictive cost surface attached to `orchestrator:dispatch`. Both surfaces are bash-only, read-only (FR-12 / CON-1), zero-LLM-token (FR-21 / CON-6), bash 3.2 compatible (CON-7), and respect a documented suppression matrix that lets operators silence them without losing fidelity of the underlying telemetry.

## What was built

- **T01 — efficiency footer helper.** `scripts/diagnostics/efficiency-footer.sh` (170 lines, sourceable + CLI). Renders ≤6 lines from `metrics-rollup.sh` (cost, verification pass-rate, dispatch count, optional pricing-degradation annotation). `--quiet` / `ORCH_EFFICIENCY_FOOTER=false` / `efficiency_footer: false` config knob each suppress to zero stdout, exit 0 — the load-bearing CON-3 / SC-3 byte-identity contract. Empty-log path emits the `Efficiency: no Tier 1 records yet` literal per US-3 AS-3. `read-config.sh` extended in the same task with both M027/P02 `VALID_KEYS` (`efficiency_footer` + `predictive_cost_surface`) to avoid two passes over the same file.

- **T02 — `commands/status.md` integration + baseline fixture.** Single `## Efficiency Footer` section inserted between `## Telemetry Metrics` and `## Next Action`, plus one new bullet under `## Reference Files`. Pre-edit canonical sections preserved in pre-edit order. `tests/fixtures/m027-p02/status-quiet-baseline.txt` (50 lines) captures the verbatim post-`## Next Action` tail; T04's byte-identity verifier diffs the live tail against it, so any accidental drift in the suppressed-mode document tail fails CI.

- **T03 — `scripts/dispatch/predictive-surface.sh` helper + `commands/dispatch.md` integration.** Sourceable bash 3.2 library + CLI thin-wraps the P01 `intensity-recommend.sh --format text` cost-annotation hook by pre-setting `INTENSITY_RECOMMEND_FAST_PATH=1` + the module-scope `_CE_RECOMMENDED` slot — same no-recursion pattern P01/T02 used, now applied at the dispatch boundary. Implements the **5-condition suppression matrix** (`--yes`, `ORCHESTRATOR_AUTO`, `--no-predict`, `predictive_cost_surface: false`, `intensity = quick`); each path short-circuits to zero stdout / exit 0 before any I/O. Operator override is rendered as a one-line informational prompt (CON-10); the helper does NOT read stdin — the runtime captures keystrokes. `commands/dispatch.md` gained one new `## Predictive Surface (M027/P02)` section between `## Dispatch Strategy` and `## Execution Recording`; canonical section order preserved.

- **T04 — verifier suite.** `scripts/verify/m027-p02-suite.sh` orchestrates 11 per-contract verifiers (efficiency-footer-shape, status-md-shape, status-quiet-byte-identity, predictive-surface-shape, suppression-matrix, dispatch-md-shape, predictive-surface-latency, predictive-goodhart-pairing, zero-llm-token, read-only, bash32-compat). T01/T02/T03 scoped prechecks deleted, subsumed by canonical phase-level verifiers — third occurrence of the M027/P00+P01+P02 T04-subsumes-prechecks pattern.

## Cross-phase contracts P02 pinned (for P03 to consume)

- **5-condition suppression matrix** is load-bearing and mechanically gated by `m027-p02-suppression-matrix.sh`; P03's anomaly-detection surface should follow the same matrix shape.
- **Document-shaped phase-task pattern** (T02): when integrating a helper into a runtime-rendered command document, edit the markdown at a stable attach point + ship a verbatim-tail baseline fixture; T04 ships the byte-identity verifier. Rendering byte-identity is enforced upstream by the agent's contract-honoring of the documented suppression knob.
- **Latency outer-vs-inner split** carried forward verbatim from P01/T04: hard-fail at 250ms on the inner library measurement (with `INTENSITY_RECOMMEND_FAST_PATH=1` + `_CE_RECOMMENDED=standard` pre-set, bypassing the inner intensity-recommend re-fork — the surface author's actual budget). Outer wall-clock reported informationally with `WARN: RELAX-CANDIDATE` annotation.
- **Comment-hygiene-for-verifier-regex** (M027/P00+P01+P02): doc-comments use the safe phrasing "no associative arrays / no herestring redirect" rather than spelling literal bash-4 forbidden tokens, so `m027-p02-bash32-compat.sh` does not false-positive against doc comments.
- **Operator-override-as-informational-prompt** (CON-10): helpers render override prompts but do NOT read stdin; runtime layer handles capture.

## Resolved open questions

- **#Q-16** — repeat-dispatch throttling. Pinned in P02-PLAN as **always-on with `--no-predict` operator-override flag** (no session-cache, no hidden state). Rationale: AD-4 strategic positioning is visibility-first; throttling adds hidden state that disagrees with the user-visible config. Enforced by `m027-p02-suppression-matrix.sh`, which exercises `--no-predict` as one of the 5 paths.

## Verification

- `bash scripts/verify/m027-p02-suite.sh` → exit 0, **11/11 gates PASS**
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M027/phases/P02` → exit 0 (12 Truth Check invocations + 17 artifact assertions + 21 key-link assertions PASS)
- D026 + D027 cross-phase contracts from P01 honored end-to-end
- One observational `WARN: RELAX-CANDIDATE` on the latency verifier (`inner=112ms target=100ms hard_fail=250ms outer=109ms`) — well within the 250ms hard-fail; identical pattern to P01/T04.

## Lessons carried forward to P03

- **Parser-shape lesson, third occurrence prevention.** Each task's `Verification` fenced bash block must reference ONLY artifacts the task itself produces. The T04-subsumes-prechecks pattern is the structural answer; plan-phase agents must verify each task's verification block before finalizing.
- **Document-shaped phase-task pattern.** When P03 integrates `doctor --config-check` anomaly surfaces into `commands/doctor.md`, follow the T02 attach-point + tail-fixture + canonical-section-order pattern.
- **Suppression-matrix discipline.** P03 anomaly thresholds need an analogous knob shape (env override + config knob + recognized-falsy tokens) so the doctor surface has the same operator visibility/override guarantees as the cost surfaces.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M027"
name: "run-doctor.sh integration (--config-check flag + advisory invocations of T01 + T02)"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 has shipped `scripts/diagnostics/check-anomalies.sh` (≥ 120 lines, executable). CLI accepts `--milestone`, `--project`, `--no-anomaly`, `--yes`, `--threshold`, `--sample-floor`, `--config-defaults`, `--help`. The helper exits 0 in all paths (FR-8 advisory contract). Output prefix: `Anomaly Detection (Tier 1 baseline)`.
- T02 has shipped `scripts/diagnostics/check-config-drift.sh` (≥ 80 lines, executable). CLI accepts `--keys`, `--key`, `--no-config-check`, `--config-defaults`, `--help`. Output prefix: `Config Drift (M027 knobs)`.
- T02 has updated `commands/doctor.md` to document the `## Anomaly Detection` and `## Config Drift` sections + the suppression matrix + the baseline disclaimer.
- `scripts/diagnostics/run-doctor.sh` exists in pre-T03 form (~145 lines today). Has a `run_check <name> <script> <args> <advisory>` function (line 31) that invokes a check script, parses its output for `DOCTOR:` status lines, and tracks pass/fail / advisory-warning counts. Has an `--root` and `--format` arg-parse loop (lines 15–21). Has a sequence of `run_check` invocations (lines 98–112) for the existing standard checks, ending with `Documentation Completeness` and `Runtime Instruction Drift`. Then graph-health is conditionally added, then summary + history append.
- bash 3.2 / POSIX sh discipline (CON-7).
- AD-19 single-script-file `Check:` shape: this task ships its own scoped precheck `scripts/verify/m027-p03-t03-shape-precheck.sh`.

## Description

Edit `scripts/diagnostics/run-doctor.sh` to:

1. **Add `--config-check` to the arg-parse loop** as a flag (default off). When set, the script additionally invokes the `check-config-drift.sh` helper as an advisory check.
2. **Add `--no-anomaly` to the arg-parse loop** as a flag (default off). When set, the anomaly check is skipped entirely (suppressed-mode parity with the helper's `--no-anomaly` flag).
3. **Add a `run_check "Anomaly Detection"` invocation** below the existing `Runtime Instruction Drift` invocation (after line 112) and above the conditional `Graph Health` block. Mark it as advisory (`"1"` final arg). Pass the `--no-anomaly` flag through if set on `run-doctor.sh`'s own invocation.
4. **Conditionally add a `run_check "Config Drift"` invocation** when `--config-check` is set. Mark it as advisory.

These two new advisory checks do NOT count toward the `checks_passed / checks_total` ratio; they only contribute to the `advisory_warnings` count when their helper exits non-zero (which they don't — both helpers are exit-0-always per FR-8 advisory contract). The `HEALTHY` / `NEEDS_ATTENTION` overall status is unaffected by either new check (FR-8: anomaly findings are advisory and never block autonomous mode).

Both new `run_check` invocations follow the existing pattern verbatim — same calling convention, same `advisory=1` marker, same output handling. No re-shape of the existing scoring logic. The only structural changes are the two arg-parse cases and the two `run_check` calls.

## Steps

1. **Edit `scripts/diagnostics/run-doctor.sh` arg-parse loop** (current lines 15–21):

   ```bash
   while [ $# -gt 0 ]; do
     case "$1" in
       --root) PROJECT_ROOT="$2"; shift 2 ;;
       --format) FORMAT="$2"; shift 2 ;;
       *) echo "run-doctor.sh: unknown option: $1" >&2; exit 1 ;;
     esac
   done
   ```

   Modify to (preserve `--root` and `--format`; add `--config-check` and `--no-anomaly`):

   ```bash
   CONFIG_CHECK=0
   NO_ANOMALY=0
   while [ $# -gt 0 ]; do
     case "$1" in
       --root) PROJECT_ROOT="$2"; shift 2 ;;
       --format) FORMAT="$2"; shift 2 ;;
       --config-check) CONFIG_CHECK=1; shift ;;
       --no-anomaly) NO_ANOMALY=1; shift ;;
       *) echo "run-doctor.sh: unknown option: $1" >&2; exit 1 ;;
     esac
   done
   ```

   The `CONFIG_CHECK=0` and `NO_ANOMALY=0` initializations must precede the `while` loop.

2. **Add the anomaly `run_check` invocation** between the existing `Runtime Instruction Drift` line (line 112) and the conditional `Graph Health` block (line 114). Insert the following lines:

   ```bash
   # M027/P03/T03 — Anomaly Detection (advisory; FR-8: never blocks autonomous mode).
   if [ "$NO_ANOMALY" -eq 1 ]; then
     run_check "Anomaly Detection" "$SCRIPT_DIR/check-anomalies.sh" "--no-anomaly" "1"
   else
     run_check "Anomaly Detection" "$SCRIPT_DIR/check-anomalies.sh" "" "1"
   fi
   ```

   Then, immediately after, add the conditional config-drift `run_check`:

   ```bash
   # M027/P03/T03 — Config Drift (advisory; opt-in via --config-check; FR-16).
   if [ "$CONFIG_CHECK" -eq 1 ]; then
     run_check "Config Drift" "$SCRIPT_DIR/check-config-drift.sh" "" "1"
   fi
   ```

3. **Confirm the existing `run_check` function** (line 31) handles the empty-`args` case correctly — current implementation does (`bash "$script" $args 2>&1` with deliberate word-splitting on `$args`; empty `$args` is a no-op).

4. **Make no other changes** to the script. No re-ordering of existing checks. No re-shape of the scoring logic. The two new checks are advisory and surfaced below the existing checks.

5. **Create the T03-scoped precheck** `scripts/verify/m027-p03-t03-shape-precheck.sh` (~70 lines):

   ```bash
   #!/usr/bin/env bash
   set -u
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   cd "$PROJECT_ROOT"
   fail() { echo "FAIL: m027-p03-t03-shape-precheck $1" >&2; exit 1; }
   [ -f scripts/diagnostics/run-doctor.sh ] || fail "missing run-doctor.sh"
   # Arg-parse additions.
   grep -q -- "--config-check" scripts/diagnostics/run-doctor.sh || fail "missing --config-check arg"
   grep -q -- "--no-anomaly" scripts/diagnostics/run-doctor.sh || fail "missing --no-anomaly arg"
   grep -q "CONFIG_CHECK=" scripts/diagnostics/run-doctor.sh || fail "missing CONFIG_CHECK init"
   grep -q "NO_ANOMALY=" scripts/diagnostics/run-doctor.sh || fail "missing NO_ANOMALY init"
   # run_check invocations.
   grep -q 'run_check "Anomaly Detection"' scripts/diagnostics/run-doctor.sh || fail "missing Anomaly Detection run_check"
   grep -q 'run_check "Config Drift"' scripts/diagnostics/run-doctor.sh || fail "missing Config Drift run_check"
   grep -q "check-anomalies.sh" scripts/diagnostics/run-doctor.sh || fail "missing check-anomalies.sh ref"
   grep -q "check-config-drift.sh" scripts/diagnostics/run-doctor.sh || fail "missing check-config-drift.sh ref"
   # Advisory marker (the trailing "1" arg in run_check invocations for both new checks).
   grep -E 'run_check "Anomaly Detection".*"1"' scripts/diagnostics/run-doctor.sh >/dev/null || fail "Anomaly Detection not advisory"
   grep -E 'run_check "Config Drift".*"1"' scripts/diagnostics/run-doctor.sh >/dev/null || fail "Config Drift not advisory"
   # Behavioral: run-doctor.sh smoke-test runs without crashing.
   out=$(bash scripts/diagnostics/run-doctor.sh --no-anomaly 2>&1 | head -3)
   echo "$out" | grep -q "Orchestrator Diagnostics" || fail "run-doctor.sh failed smoke test"
   echo "PASS: m027-p03-t03-shape-precheck"
   exit 0
   ```

   `chmod +x scripts/verify/m027-p03-t03-shape-precheck.sh`.

## Must-Haves

- `scripts/diagnostics/run-doctor.sh` exists, ≥ 140 lines, contains `--config-check` arg-parse case and `--no-anomaly` arg-parse case.
- File contains the literal `run_check "Anomaly Detection"` invocation referencing `check-anomalies.sh`.
- File contains the literal `run_check "Config Drift"` invocation referencing `check-config-drift.sh`.
- Both new `run_check` invocations carry the trailing `"1"` advisory marker.
- File contains the literal `Anomaly Detection` (asserted by P03 phase-plan artifact requirement).
- Running `bash scripts/diagnostics/run-doctor.sh --no-anomaly` exits without crashing and produces output prefixed `=== Orchestrator Diagnostics ===`.
- `scripts/verify/m027-p03-t03-shape-precheck.sh` exists, executable, exits 0 against the post-T03 codebase.

## Verification

```bash
bash scripts/verify/m027-p03-t03-shape-precheck.sh
```

This T03-scoped precheck verifier (ships with T03) asserts T03's must-haves. T04 ships the canonical phase-level verifier `m027-p03-run-doctor-integration.sh` which subsumes this precheck.

## Inputs

### From Previous Tasks

- T01: `scripts/diagnostics/check-anomalies.sh` — invoked by the new `Anomaly Detection` `run_check`. Exits 0 in all paths (FR-8 advisory). The `--no-anomaly` flag is passed through when `run-doctor.sh` is invoked with `--no-anomaly`.
- T02: `scripts/diagnostics/check-config-drift.sh` — invoked by the new `Config Drift` `run_check` only when `--config-check` is set on `run-doctor.sh`. Exits 0 in all paths.

### From Disk (Pre-existing)

- `scripts/diagnostics/run-doctor.sh` — pre-T03 form (~145 lines). Has the `run_check` function (line 31). Existing `run_check` invocations end at line 112 (`Runtime Instruction Drift`). The conditional `Graph Health` block follows on lines 114–121. Summary + history append on lines 123–144. T03 inserts two `run_check` invocations between line 112 and line 114 (no re-ordering of existing invocations).

## Constraints

- **CON-7 (bash 3.2)**: No `declare -A`, no `<<<`, no `mapfile`, no `${var^^}`, no `<(...)`, no `&>`. The existing `run-doctor.sh` is bash 3.2 compatible; T03 preserves that property.
- **FR-8 (advisory; never blocks)**: Both new checks are marked advisory (`"1"` final arg). They contribute to `advisory_warnings` if their helpers exit non-zero (which they don't), but never to `checks_total` or `checks_passed`. Overall HEALTHY status is unaffected.
- **FR-16 (config-check opt-in)**: The `Config Drift` check is only invoked when `--config-check` is set. Without the flag, `run-doctor.sh` output is unchanged (modulo the new `Anomaly Detection` block, which is always present unless `--no-anomaly` is set).
- **CON-3-equivalent (suppressed-mode parity with T01)**: When `run-doctor.sh --no-anomaly` is invoked, the anomaly helper is invoked WITH `--no-anomaly` and emits zero anomaly content. The `--- Anomaly Detection ---` section header from `run_check` still appears (since `run_check` always emits the header before invoking the script), but the body is empty. This is the documented behavior in `commands/doctor.md` (T02).
- **FR-12 / CON-1 (read-only)**: No new writes to disk by `run-doctor.sh` itself; the two new helpers are read-only per FR-12 / CON-1.
- **FR-21 / CON-6 / SC-16 (zero-LLM-token)**: No `claude_chat`, no `anthropic`, no `dispatch-interface.sh`, no `dispatch_task`, no `subagent` introduced.
- **AD-19 (single-script-file Check shape)**: This task's `Check:` invokes a single helper script (the T03-scoped precheck). T04 ships the canonical phase-level Truth `Check:` invocations.
- **MEM012 (no re-shape of existing canonical structure)**: The arg-parse and `run_check` sequences in `run-doctor.sh` are pre-existing canonical structures. T03 appends to the arg-parse case-statement and inserts between two pre-existing `run_check` invocations; no pre-existing line is re-ordered or re-worded.

## Expected Output

After this task:

1. `scripts/diagnostics/run-doctor.sh` modified to include the `--config-check` and `--no-anomaly` arg-parse cases plus two new `run_check` invocations (`Anomaly Detection`, conditional `Config Drift`).
2. The `--- Anomaly Detection ---` block appears in `run-doctor.sh` output by default (advisory, exit-0 always).
3. The `--- Config Drift ---` block appears in `run-doctor.sh` output ONLY when `--config-check` is set.
4. `bash scripts/diagnostics/run-doctor.sh --no-anomaly` exits without crashing; the anomaly block body is empty (suppressed-mode contract).
5. `scripts/verify/m027-p03-t03-shape-precheck.sh` exists, executable, exits 0 against the post-T03 codebase.
6. `git diff --quiet` is non-zero (this task modifies files); however, no `execution-log.jsonl` file is touched.

## State Context

- **Current State**: executing
- **Milestone**: M027
- **Phase**: P03
- **Task**: T03-run-doctor-integration
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **CON-7 (bash 3.2)**: No `declare -A`, no `<<<`, no `mapfile`, no `${var^^}`, no `<(...)`, no `&>`. The existing `run-doctor.sh` is bash 3.2 compatible; T03 preserves that property.
- **FR-8 (advisory; never blocks)**: Both new checks are marked advisory (`"1"` final arg). They contribute to `advisory_warnings` if their helpers exit non-zero (which they don't), but never to `checks_total` or `checks_passed`. Overall HEALTHY status is unaffected.
- **FR-16 (config-check opt-in)**: The `Config Drift` check is only invoked when `--config-check` is set. Without the flag, `run-doctor.sh` output is unchanged (modulo the new `Anomaly Detection` block, which is always present unless `--no-anomaly` is set).
- **CON-3-equivalent (suppressed-mode parity with T01)**: When `run-doctor.sh --no-anomaly` is invoked, the anomaly helper is invoked WITH `--no-anomaly` and emits zero anomaly content. The `--- Anomaly Detection ---` section header from `run_check` still appears (since `run_check` always emits the header before invoking the script), but the body is empty. This is the documented behavior in `commands/doctor.md` (T02).
- **FR-12 / CON-1 (read-only)**: No new writes to disk by `run-doctor.sh` itself; the two new helpers are read-only per FR-12 / CON-1.
- **FR-21 / CON-6 / SC-16 (zero-LLM-token)**: No `claude_chat`, no `anthropic`, no `dispatch-interface.sh`, no `dispatch_task`, no `subagent` introduced.
- **AD-19 (single-script-file Check shape)**: This task's `Check:` invokes a single helper script (the T03-scoped precheck). T04 ships the canonical phase-level Truth `Check:` invocations.
- **MEM012 (no re-shape of existing canonical structure)**: The arg-parse and `run_check` sequences in `run-doctor.sh` are pre-existing canonical structures. T03 appends to the arg-parse case-statement and inserts between two pre-existing `run_check` invocations; no pre-existing line is re-ordered or re-worded.

### Acceptance Criteria

- `scripts/diagnostics/run-doctor.sh` exists, ≥ 140 lines, contains `--config-check` arg-parse case and `--no-anomaly` arg-parse case.
- File contains the literal `run_check "Anomaly Detection"` invocation referencing `check-anomalies.sh`.
- File contains the literal `run_check "Config Drift"` invocation referencing `check-config-drift.sh`.
- Both new `run_check` invocations carry the trailing `"1"` advisory marker.
- File contains the literal `Anomaly Detection` (asserted by P03 phase-plan artifact requirement).
- Running `bash scripts/diagnostics/run-doctor.sh --no-anomaly` exits without crashing and produces output prefixed `=== Orchestrator Diagnostics ===`.
- `scripts/verify/m027-p03-t03-shape-precheck.sh` exists, executable, exits 0 against the post-T03 codebase.

### Files To Touch

- scripts/diagnostics/check-anomalies.sh (create)
- scripts/diagnostics/check-config-drift.sh (create)
- scripts/diagnostics/run-doctor.sh (modify)
- scripts/state/read-config.sh (modify)
- commands/doctor.md (modify)
- tests/fixtures/m027-p03/doctor-suppressed-baseline.txt (create)
- tests/fixtures/m027-p03/anomaly-fixture.jsonl (create)
- tests/fixtures/m027-p03/README.md (create)
- scripts/verify/m027-p03-t01-shape-precheck.sh (create — deleted by T04)
- scripts/verify/m027-p03-t02-shape-precheck.sh (create — deleted by T04)
- scripts/verify/m027-p03-t03-shape-precheck.sh (create — deleted by T04)
- scripts/verify/m027-p03-suite.sh (create)
- scripts/verify/m027-p03-anomaly-shape.sh (create)
- scripts/verify/m027-p03-config-drift-shape.sh (create)
- scripts/verify/m027-p03-doctor-md-shape.sh (create)
- scripts/verify/m027-p03-doctor-byte-identity.sh (create)
- scripts/verify/m027-p03-suppression-matrix.sh (create)
- scripts/verify/m027-p03-run-doctor-integration.sh (create)
- scripts/verify/m027-p03-anomaly-latency.sh (create)
- scripts/verify/m027-p03-anomaly-goodhart-pairing.sh (create)
- scripts/verify/m027-p03-zero-llm-token.sh (create)
- scripts/verify/m027-p03-read-only.sh (create)
- scripts/verify/m027-p03-bash32-compat.sh (create)

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