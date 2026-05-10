---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T05-acceptance-and-seam-and-suite (Phase P02, Milestone M032)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-978 | ~900 | required |
| Upstream Context | 980-1127 | ~2800 | required |
| Task Plan | 1129-1625 | ~8100 | required |
| State Context | 1627-1633 | ~100 | required |
| First-Turn Completeness | 1635-1693 | ~1300 | required |
| **Total** | | **~24000** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 814
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
hit_count: 814
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
hit_count: 814
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
hit_count: 814
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
hit_count: 708
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
hit_count: 708
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
hit_count: 708
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
hit_count: 814
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
hit_count: 708
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
hit_count: 708
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
hit_count: 708
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
hit_count: 814
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
hit_count: 814
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
hit_count: 814
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
hit_count: 708
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
hit_count: 708
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
hit_count: 708
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
hit_count: 814
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
hit_count: 708
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
hit_count: 708
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
hit_count: 814
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
hit_count: 814
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
hit_count: 708
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
hit_count: 708
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
hit_count: 708
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
hit_count: 363
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
hit_count: 363
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
hit_count: 363
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
hit_count: 390
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
hit_count: 390
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
hit_count: 380
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
     m032-p02-* prefix to avoid collision with M030/[M031](../../../../../milestones/M031/index.md) existing
     p02-* verifiers in the shared tools/verify/ tree. Verifier scripts
     are co-authored alongside their corresponding artifact within the
     SAME task per plan-time discipline rule 2. -->

### Truths

- `commands/wiki-init.md` exists as a new orchestrator command document with the orchestrator-canonical structure (YAML frontmatter `description:`, Title, Prerequisites / State Check, Core Workflow, Output, Idempotency, Error Handling, Referenced Scripts) per MEM012, and references `scripts/lifecycle/wiki-init.sh` as the canonical implementation. The command document declares the three composable scopes (default copy+template, `--with-giscus` deferred to P03, `--deploy` deferred to P03) but the P02 surface ships only the default scope plus the `--auto-pip` opt-in (FR-5 + FR-12 + #Q-2).
  - Check: `bash tools/verify/m032-p02-wiki-init-command-shape.sh`

- `scripts/lifecycle/wiki-init.sh` exists, is executable, and at default invocation (no `--with-giscus` / no `--deploy`) (a) reads wiki tooling from the P01 `project_assets:` manifest entries via `scripts/lifecycle/read-project-assets.sh` (FR-5 — extending the manifest with a `wiki/` entry under T01's responsibility), (b) probes `python3` + `pip3` and emits a platform-aware diagnostic per FR-12 / #Q-2 (`brew install python3` on darwin, `apt install python3` on linux) failing closed without writing if either is absent, (c) parses `git -C "$PROJECT_DIR" remote get-url origin` to derive `<owner>/<repo>` and synthesizes the four `{{...}}` placeholder values, (d) sed-substitutes the four placeholders in the staged `<PROJECT_DIR>/wiki/mkdocs.yml`, (e) leaves `<PROJECT_DIR>/wiki/overrides/partials/comments.html` carrying the four `{{giscus_*}}` placeholders verbatim (P03's `--with-giscus` scope fills them), (f) authors a `wiki/glossary.md` path-convention stub at `<PROJECT_DIR>/wiki/glossary.md` per FR-15. The script honors `--site-name`, `--site-description`, and `--auto-pip` flags. Idempotency: a second invocation against an already-`wiki-init`'d project preserves operator edits to the templated files and exits 0 with a `no changes` diagnostic (US-2 Acceptance Scenario 5).
  - Check: `bash tools/verify/m032-p02-wiki-init-default-scope.sh`

- `wiki/mkdocs.yml` has its four hardcoded site-identity fields replaced with `{{site_name}}` / `{{site_description}}` / `{{site_url}}` / `{{repo_url}}` placeholder tokens per FR-6, AND the FR-6 self-application loop is closed within this phase: `bash scripts/lifecycle/wiki-init.sh --project-dir .` has been run against the orchestrator repo itself, the four placeholders have been resolved with the orchestrator's own identity (`site_name: spec-kit-orchestrator — dogfood wiki`, `site_url: https://build-fractal.github.io/spec-kit-orchestrator/`, `repo_url: https://github.com/Build-Fractal/spec-kit-orchestrator`, `site_description: Browseable projection of .orchestrator/ artifacts for the dogfood team.`), and the orchestrator's own `bash scripts/wiki/wiki-serve.sh` continues to return HTTP 200 at `:8000` (FR-6 / MIT-002 — without this loop closure the orchestrator's own wiki breaks for the duration of M032 + [M033](../../../../../milestones/M033/index.md) paired development). The bundle-staged copy of `wiki/mkdocs.yml` (under `packaging/bundle/`, if it ships there per the P01 `project_assets:` `wiki/` entry) carries the placeholders verbatim; the orchestrator-repo-local copy carries the resolved values.
  - Check: `bash tools/verify/m032-p02-mkdocs-templating-and-self-application.sh`

<dispatch-volatile>

## Upstream Context


### P01 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M032"
milestone: "M032"
provides:
  - "project_assets manifest schema; read-project-assets.sh shared reader; install-asset-mode.sh per-mode handler (copy + symlink + windows fail-closed); install-collision-check.sh FR-22 dual-oracle hierarchy (tracking-file + MIT-006 bootstrapping + operator-owned),install-claude-code.sh project_assets-driven runtime payload stage (FR-2 + FR-3 + FR-4 + FR-22); pre-M032 golden file-tree shape (tools/verify/fixtures/m032-pre-m032-golden.txt); --asset-mode-override flag (TEST-ONLY P01 surface); m032-p01-install-cc-byte-identical.sh verifier,install-codex.sh + install-cursor.sh migrated to project_assets: schema; --asset-mode-override flag added to both; cross-installer parity locked via tools/verify/m032-p01-installers-parity.sh,tests/fixtures/m032-fresh-project-fixture/ (.gitignore + .git-init-marker + README.md) shared with P02..P04; tests/m032-acceptance/p01-{managed-bundle-shape,symlink-mode,staged-dirs-collision}.sh (SC-1 + SC-2 + SC-10 acceptance scripts); tools/verify/m032-p01-{fixture-shape,acceptance-shape-sc1,acceptance-shape-sc2,acceptance-shape-sc10,phase-suite,scope-guard}.sh; tools/verify/fixtures/m032-p01-baseline-ref.txt (P01 baseline ref for SC-13 scope-guard)"
requires:
  - "none"
affects:
  - "P02"
key_files:
  - "packaging/bundle/manifest.yml,scripts/lifecycle/read-project-assets.sh,scripts/lifecycle/install-asset-mode.sh,scripts/lifecycle/install-collision-check.sh,tools/verify/m032-p01-manifest-schema-shape.sh,tools/verify/m032-p01-reader-emits-tuples.sh,tools/verify/m032-p01-mode-handler-symlink.sh,tools/verify/m032-p01-installed-files-format.sh,tools/verify/m032-p01-collision-oracle.sh,packaging/install/install-claude-code.sh,tools/verify/m032-p01-install-cc-byte-identical.sh,tools/verify/fixtures/m032-pre-m032-golden.txt,packaging/install/install-codex.sh,packaging/install/install-cursor.sh,tools/verify/m032-p01-installers-parity.sh,tests/fixtures/m032-fresh-project-fixture/.gitignore,tests/fixtures/m032-fresh-project-fixture/.git-init-marker,tests/fixtures/m032-fresh-project-fixture/README.md,tests/m032-acceptance/p01-managed-bundle-shape.sh,tests/m032-acceptance/p01-symlink-mode.sh,tests/m032-acceptance/p01-staged-dirs-collision.sh,tools/verify/fixtures/m032-p01-baseline-ref.txt,tools/verify/m032-p01-fixture-shape.sh,tools/verify/m032-p01-acceptance-shape-sc1.sh,tools/verify/m032-p01-acceptance-shape-sc2.sh,tools/verify/m032-p01-acceptance-shape-sc10.sh,tools/verify/m032-p01-phase-suite.sh,tools/verify/m032-p01-scope-guard.sh"
key_decisions:
  - "FR-1,FR-2,FR-3,FR-22,NG-9,MIT-006,CON-4,AD-19,N/A,SC-1,SC-2,SC-10,SC-13,FR-4,MIT-001"
patterns_established:
  - "dual-oracle collision-check hierarchy with MIT-006 bootstrapping carve-out; tab-delimited column-1 installed-files.txt FILE FORMAT INVARIANT documented inline at the consumer; per-mode handler dispatches on key=value emit tokens (no mode: colon-literal in path-vicinity); Windows fail-closed via M032_FORCE_WINDOWS=1 OR absent ln,record-golden-before-migrating (load-bearing ordering invariant); two-pass project_assets tuple loop with printf-b joined target list for collision-check argv; column-1 awk extraction for installed-files.txt back-compat read paths,cross-installer parity invariant: project-asset staging block is byte-identical (78 lines) across all three installers; differences confined to surrounding runtime-specific context (skill-registration,hook-payload,settings-merge,--project-dir requirement),fixture-staging via mktemp -d + cp -R + git init + git remote add origin (committed fixture stays immutable; runtime .git/ materialized at test time); deny-all-then-allow-one .gitignore amendment for exercising the FR-22 operator-owned oracle branch (the fresh-project-fixture's .gitignore otherwise excludes commands/ which would mask operator-owned status); SC-13 baseline-ref captured to tools/verify/fixtures/m032-p01-baseline-ref.txt at scope-guard first run; phase-suite straight-line aggregator with single-script-file shape per AD-19"
drill_down_paths:
  - "[.orchestrator/milestones/M032/phases/P01/tasks/T01-manifest-and-libraries-SUMMARY.md](../../../../../milestones/M032/phases/P01/tasks/T01-manifest-and-libraries-SUMMARY.md), [.orchestrator/milestones/M032/phases/P01/tasks/T02-install-claude-code-migration-SUMMARY.md](../../../../../milestones/M032/phases/P01/tasks/T02-install-claude-code-migration-SUMMARY.md), [.orchestrator/milestones/M032/phases/P01/tasks/T03-install-codex-cursor-migration-SUMMARY.md](../../../../../milestones/M032/phases/P01/tasks/T03-install-codex-cursor-migration-SUMMARY.md), [.orchestrator/milestones/M032/phases/P01/tasks/T04-fixture-and-acceptance-tests-SUMMARY.md](../../../../../milestones/M032/phases/P01/tasks/T04-fixture-and-acceptance-tests-SUMMARY.md)"
duration: "210m"
verification_result: "pass"
completed_at: "2026-05-04T17:57:14Z"
observability_surfaces:
  - "none"
---

## What Shipped

P01 replaces the unmanaged `RUNTIME_DIRS` bulk-copy in all three installers
(`install-{claude-code,codex,cursor}.sh`) with a managed `project_assets:`
schema entry in `packaging/bundle/manifest.yml`, drives all three installers
from that single seam, and lands the FR-22 dual-oracle collision hierarchy
plus the SC-1 / SC-2 / SC-10 acceptance scripts and the `m032-p01-*`
verifier suite. The shared fresh-project fixture used by P02..P04 lands here
too. Default behavior at `mode: copy` is byte-identical to the pre-M032
`cp -R` path; `mode: symlink` is wired and POSIX-only with Windows
fail-closed (NG-9).

The four task tranches:

1. **T01 — Manifest + libraries**: appended `project_assets:` to
   `packaging/bundle/manifest.yml` (four entries: `commands/`, `scripts/`,
   `references/`, `templates/`), each declaring `source:` / `target:` /
   `mode: copy`. Authored `scripts/lifecycle/read-project-assets.sh`
   (shared reader, emits tab-separated `source=<src>\ttarget=<tgt>\tmode=<m>`
   tuples), `scripts/lifecycle/install-asset-mode.sh` (per-mode handler:
   copy + symlink + Windows fail-closed via `M032_FORCE_WINDOWS=1` OR absent
   `ln`), and `scripts/lifecycle/install-collision-check.sh` (FR-22
   dual-oracle hierarchy: tracking-file + MIT-006 bootstrapping carve-out +
   operator-owned). Pre-M032 manifest keys preserved byte-identically.

2. **T02 — install-claude-code migration (FR-2 + FR-3 + FR-4 + FR-22)**:
   replaced the hardcoded `RUNTIME_DIRS` bulk-copy at
   `install-claude-code.sh:415-458` with a `project_assets:`-driven loop
   that calls `read-project-assets.sh` then dispatches each tuple to
   `install-asset-mode.sh`. `installed-files.txt` extended with a per-asset
   `mode:` field (FR-4). Added the test-only `--asset-mode-override` flag
   for SC-2 symlink coverage. Recorded the pre-M032 file-tree golden at
   `tools/verify/fixtures/m032-pre-m032-golden.txt` *before* migrating
   (load-bearing ordering invariant — record-golden-before-migrating).

3. **T03 — install-codex + install-cursor migration**: applied the same
   `project_assets:` migration to `install-codex.sh` and `install-cursor.sh`.
   Cross-installer parity is locked: the project-asset staging block is
   byte-identical (78 lines) across all three installers; differences are
   confined to surrounding runtime-specific context (skill-registration,
   hook-payload, settings-merge, Codex's `--project-dir` requirement).

4. **T04 — Fixture + acceptance battery**: landed
   `tests/fixtures/m032-fresh-project-fixture/` (`.gitignore` +
   `.git-init-marker` + `README.md`) shared with P02..P04;
   the SC-1 / SC-2 / SC-10 acceptance scripts under `tests/m032-acceptance/`;
   and the full `tools/verify/m032-p01-*.sh` verifier battery
   (manifest-schema-shape, reader-emits-tuples, mode-handler-symlink,
   installed-files-format, collision-oracle, install-cc-byte-identical,
   installers-parity, fixture-shape, acceptance-shape-{sc1,sc2,sc10},
   phase-suite, scope-guard).

## Verification Results

`P01-VERIFICATION.md`: PASS — 99/99 must-haves, phase-suite `pass=11 fail=0`,
boundary-map exit 0 (legitimate SKIP — the P01 Produces line is prose-shaped
with `;` separators between rich deliverable descriptions, not bare
comma-separated paths, so the tokenizer correctly finds nothing
single-path-token-shaped to disk-check; produce verification rides the
must-haves Artifacts section + SC acceptance scripts, both green).

Trajectory: initial 89 PASS / 10 FAIL → post-rebaseline 98 PASS / 1 FAIL →
post-scope-guard-fix 99 PASS / 0 FAIL. Three load-bearing fixes resolved the
failures: (1) refreshed the pre-M032 golden + baseline-ref to current HEAD
(M033 closure had invalidated both); (2) scope-guard switched from
working-tree-vs-baseline to committed-history-only diff
(`baseline_ref..HEAD`) so ambient working-tree dirt no longer pollutes the
scope signal; (3) `check-boundary-map.sh` parser learned to strip
brace-globs alongside parentheticals so `install-{claude-code,codex,cursor}.sh`'s
inner commas no longer tokenize as separate produce items.

## Key Decisions

- **MIT-006 bootstrapping carve-out**: pre-M032 consumers without
  `installed-files.txt` are detected at install time; the bootstrapping
  branch writes the tracking file from the current state instead of failing
  closed against the operator-owned oracle.
- **Tab-delimited column-1 `installed-files.txt` FILE FORMAT INVARIANT**:
  documented inline at the consumer; future readers extract via column-1
  awk for back-compat read paths.
- **POSIX-only symlink mode (NG-9)**: Windows fail-closed via either
  `M032_FORCE_WINDOWS=1` or absent `ln`, with the documented
  "POSIX-only in v1" diagnostic.
- **record-golden-before-migrating**: load-bearing ordering invariant —
  T02/T03 captured the pre-M032 file-tree golden *before* touching any
  installer body, locking the byte-identical CON-4 contract at default
  `mode: copy`.
- **--asset-mode-override flag (TEST-ONLY)**: P01 surface only, gated to
  the SC-2 symlink-mode acceptance path; not exposed in operator UX.

## Patterns Established

- Dual-oracle collision-check hierarchy with MIT-006 bootstrapping carve-out
  (reusable for any future managed-asset scheme that needs to coexist with
  pre-existing operator state).
- Per-mode handler dispatches on `key=value` emit tokens — no `mode:`
  colon-literal in path-vicinity, sidestepping AD-19 harness heuristics on
  `:` in compound bash.
- Fixture-staging via `mktemp -d` + `cp -R` + `git init` + `git remote add
  origin` (committed fixture stays immutable; runtime `.git/` materialized
  at test time). Deny-all-then-allow-one `.gitignore` amendment exercises
  the FR-22 operator-owned oracle branch.
- Phase-suite straight-line aggregator with single-script-file shape per
  AD-19 — replicable for future M0##/P##-suite verifiers.
- SC-13 baseline-ref captured to a fixture file at scope-guard first run
  (`tools/verify/fixtures/m032-p01-baseline-ref.txt`); committed-history
  diff (not working-tree) is the correct scope signal.

## Affects Downstream

- **P02** consumes the manifest schema + reader + per-mode handler +
  collision-check + fresh-project fixture. P02's `wiki/` asset type folds
  into the same `project_assets:` schema; collision-check carries forward
  unchanged.
- **P03 + P04** pick up the fixture and the verifier conventions
  established here.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P02"
milestone: "M032"
name: "SC-3 + SC-7 acceptance scripts + paired-launch seam-{A,B,C} + phase suite + scope guard"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

- T01 has landed `scripts/lifecycle/wiki-init.sh` (FR-5 default scope), `commands/wiki-init.md`, `wiki/mkdocs.yml` placeholders + FR-6 self-application loop closure, and the `wiki/` entry in `packaging/bundle/manifest.yml`. Verified by `[ -x scripts/lifecycle/wiki-init.sh ]` and `grep -q '{{site_name}}' wiki/mkdocs.yml` (briefly — note: the orchestrator-local resolved state after self-application MAY have placeholders cleared; the bundle staging path keeps them in the bundle source). Test-only escape `M032_WIKI_INIT_FORCE_EXIT` is wired in `wiki-init.sh`.
- T02 has landed the `--with-wiki [--with-giscus] [--deploy]` passthrough on `commands/init.md` and `scripts/lifecycle/init-project.sh` with the FR-11 / MIT-011 sequential-atomicity contract. Verified by `grep -q -- '--with-wiki' scripts/lifecycle/init-project.sh` and `grep -q 'init-complete, wiki-pending' scripts/lifecycle/init-project.sh`.
- T03 has landed `wiki/glossary.md` at the orchestrator-repo root with at least three `### TERM` headings, the `--include-glossary` flag on `wiki-scan-sources.sh`, and the Glossary-as-second-entry placement in `wiki-generate-nav.sh`. Verified by `[ -f wiki/glossary.md ]` and `grep -c '^### ' wiki/glossary.md` returning `>= 3`.
- T04 has landed `scripts/knowledge/lookup-mems.sh --kind=glossary` honoring M031 profiles and the MIT-010 safe-default-no-terms fallback. Verified by `[ -x scripts/knowledge/lookup-mems.sh ]` and `grep -q 'safe-default-no-terms\|MIT-010' scripts/knowledge/lookup-mems.sh`.
- `tests/m032-acceptance/` exists (P01 deliverable) with `p01-managed-bundle-shape.sh`, `p01-staged-dirs-collision.sh`, `p01-symlink-mode.sh`. Verified by `[ -d tests/m032-acceptance ]`.
- `tests/fixtures/m032-fresh-project-fixture/` exists (P01 deliverable). Verified by `[ -d tests/fixtures/m032-fresh-project-fixture ]`.
- `tests/paired-m032-m033/` does NOT exist on disk at plan-authoring time (verified). T05 creates this directory.
- `tools/verify/m032-p02-{wiki-init-command-shape,wiki-init-default-scope,mkdocs-templating-and-self-application,init-with-wiki-passthrough,glossary-format-invariant,glossary-scanner-and-nav,lookup-mems-glossary}.sh` exist on disk (T01–T04 deliverables). Verified by `[ -x tools/verify/m032-p02-wiki-init-command-shape.sh ]` etc.
- T05 entry: this is the FINAL P02 task. None of the SC-3 / SC-7 acceptance scripts, the three seam scripts, the phase suite, or the scope guard exist yet.

## Description

T05 lands the verification surface that ties P02 closed. Five deliverable categories:

1. **Acceptance scripts** — `tests/m032-acceptance/p02-wiki-init-default-scope.sh` (SC-3) and `tests/m032-acceptance/p02-glossary-surface.sh` (SC-7, resolving the spec's `p0X-` placeholder per #Q-4 to P02). These are the milestone-grain SCs that ride into M032's `validate-milestone.sh` and `run-acceptance-battery.sh` (P05's deliverables — T05's contribution is the SC-3 + SC-7 entries themselves).

2. **Paired-launch seam scripts** — `tests/paired-m032-m033/seam-{A,B,C}.sh` per #Q-B. These are SHARED contracts between M032 and M033 — both milestones' verifiers reference them. M033/P05 invokes M032's `--with-wiki` gate per CON-3; the seams encode the shared invariants:
   - **Seam-A**: `project_assets:` schema shape M033 consumes for its 7-new-commands + 6-new-scripts shipping.
   - **Seam-B**: `--with-wiki` failure-propagation contract per FR-11 / MIT-011, exercised via `M032_WIKI_INIT_FORCE_EXIT=7` injection.
   - **Seam-C**: `wiki/glossary.md` format invariant — both M032 (path owner) and M033 (primary writer via grilling-shell) treat as shared invariant.

3. **Phase-suite aggregator** — `tools/verify/m032-p02-phase-suite.sh` chaining all twelve P02 sub-gates in dependency order with single-script-file shape per AD-19. Models on `tools/verify/m032-p01-phase-suite.sh` from P01.

4. **Scope guard** — `tools/verify/m032-p02-scope-guard.sh` asserting P02's diff is confined to the declared "Files Likely Touched" list. Models on `tools/verify/m032-p01-scope-guard.sh` from P01 (committed-history-only diff per the P01 patterns-established lessons).

5. **Acceptance-shape verifiers** — `tools/verify/m032-p02-acceptance-shape-sc3.sh` and `tools/verify/m032-p02-acceptance-shape-sc7.sh` that assert SC-3 + SC-7's load-bearing literals. Models on `tools/verify/m032-p01-acceptance-shape-sc1.sh` from P01.

## Steps

1. **Author `tests/m032-acceptance/p02-wiki-init-default-scope.sh`** (SC-3). The script exercises FR-5 + FR-6 + FR-12 end-to-end against the P01 shared fixture. Required structure (single-script-file shape per AD-19; bash 3.2 compatible; emit POSIX exit 77 on `python3` unavailable per MIT-001):

```bash
#!/usr/bin/env bash
# SC-3 — verifies FR-5 (wiki-init default scope) + FR-6 (mkdocs templating) + FR-12 (toolchain probe).
set -eu

# MIT-001 SKIP_REASON if python3 unavailable.
if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP_REASON: python3 unavailable on this host"
  exit 77
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Stage a fresh fixture from the P01 shared fixture (read-only baseline).
cp -R tests/fixtures/m032-fresh-project-fixture/. "$TMP/"
( cd "$TMP" && git init -q && git remote add origin https://github.com/fixture-owner/m032-fresh-project-fixture.git ) >/dev/null 2>&1

# (a) FR-5 + FR-6 templating fired.
bash scripts/lifecycle/wiki-init.sh --project-dir "$TMP" >/dev/null 2>&1 || { echo "FAIL: SC-3 wiki-init exit non-zero"; exit 1; }
[ -f "$TMP/wiki/mkdocs.yml" ] || { echo "FAIL: SC-3 mkdocs.yml not staged"; exit 1; }
grep -q "site_name: \"m032-fresh-project-fixture\"" "$TMP/wiki/mkdocs.yml" || { echo "FAIL: SC-3 site_name not substituted"; exit 1; }
grep -q "repo_url: \"https://github.com/fixture-owner/m032-fresh-project-fixture\"" "$TMP/wiki/mkdocs.yml" || { echo "FAIL: SC-3 repo_url not substituted"; exit 1; }
# Negative: no orchestrator-identity values leaked in.
grep -q 'spec-kit-orchestrator' "$TMP/wiki/mkdocs.yml" && { echo "FAIL: SC-3 orchestrator identity leaked into fixture mkdocs.yml"; exit 1; } || true
# Negative: no remaining placeholders.
grep -q '{{site_name}}' "$TMP/wiki/mkdocs.yml" && { echo "FAIL: SC-3 placeholder {{site_name}} remained"; exit 1; } || true

# (b) Giscus partial retains placeholder tokens (P03 fills them, not P02).
PARTIAL="$TMP/wiki/overrides/partials/comments.html"
if [ -f "$PARTIAL" ]; then
  grep -q '{{giscus_repo}}\|data-repo="{{' "$PARTIAL" || echo "WARN: SC-3 Giscus partial missing placeholder tokens (expected for P02)" >&2
fi

# (c) wiki-serve.sh HTTP probe at :8000 — extract to a helper to keep AD-19 envelope.
bash tools/verify/lib/m032-p02-wiki-serve-probe.sh "$TMP" || { echo "FAIL: SC-3 wiki-serve.sh did not return HTTP 200"; exit 1; }

# (d) FR-12 platform-aware diagnostic when python3 absent.
TMP2="$(mktemp -d)"
cp -R tests/fixtures/m032-fresh-project-fixture/. "$TMP2/"
( cd "$TMP2" && git init -q && git remote add origin https://github.com/fixture-owner/m032-fresh-project-fixture.git ) >/dev/null 2>&1
set +e
PATH=/usr/bin:/bin bash scripts/lifecycle/wiki-init.sh --project-dir "$TMP2" >/dev/null 2>"$TMP2/err"
RC=$?
set -e
# Note: PATH=/usr/bin:/bin will likely still find python3 on macOS; this branch is a best-effort probe.
# If python3 is found anyway, treat as a soft pass with a warning rather than fail.
if [ "$RC" = "0" ]; then
  echo "WARN: SC-3 FR-12 probe found python3 even with PATH narrowed; treating as soft-pass" >&2
elif [ "$RC" = "3" ]; then
  grep -q 'brew install python3\|apt install python3' "$TMP2/err" || { echo "FAIL: SC-3 FR-12 missing platform-aware diagnostic"; exit 1; }
else
  echo "FAIL: SC-3 FR-12 unexpected exit code $RC"; exit 1
fi
rm -rf "$TMP2"

echo "PASS: SC-3 p02-wiki-init-default-scope"
```

The verifier delegates the live HTTP probe to `tools/verify/lib/m032-p02-wiki-serve-probe.sh` (T01 deliverable per the FR-6 self-application verifier; if T01 placed it elsewhere, T05 either references the existing helper or co-authors it). The helper does the start+probe+kill in a single script body — the SC-3 acceptance script invokes it via `bash` only, not via inline `&` + `kill` chains (AD-19 envelope).

2. **Author `tests/m032-acceptance/p02-glossary-surface.sh`** (SC-7). Resolves the spec's `p0X-glossary-surface.sh` placeholder per #Q-4 to P02. Required structure:

```bash
#!/usr/bin/env bash
# SC-7 — verifies FR-15 (glossary scanner+nav) + FR-16 (knowledge adapter) + MIT-010 (Quick traversal).
set -eu

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# (a) FR-15 — glossary path-convention surface
[ -f wiki/glossary.md ] || { echo "FAIL: SC-7 wiki/glossary.md missing at orchestrator root"; exit 1; }
HC="$(grep -c '^### ' wiki/glossary.md)"
[ "$HC" -ge 3 ] || { echo "FAIL: SC-7 wiki/glossary.md needs >= 3 ### TERM entries; got $HC"; exit 1; }

# Scanner --include-glossary on emits the path
bash scripts/wiki/wiki-scan-sources.sh --root . --include-glossary > "$TMP/sources.txt" 2>/dev/null
grep -q 'wiki/glossary.md' "$TMP/sources.txt" || { echo "FAIL: SC-7 scanner did not emit wiki/glossary.md under --include-glossary"; exit 1; }

# Nav generator places Glossary as second top-level nav entry — non-destructive probe via mkdocs.yml backup.
cp wiki/mkdocs.yml "$TMP/mkdocs.yml.bak"
bash scripts/wiki/wiki-generate-nav.sh --root . >/dev/null 2>&1 || { cp "$TMP/mkdocs.yml.bak" wiki/mkdocs.yml; echo "FAIL: SC-7 wiki-generate-nav.sh failed"; exit 1; }
MARKER_LINE="$(grep -n '^# >>> M012-P01 nav' wiki/mkdocs.yml | head -1 | cut -d: -f1)"
SECOND_ENTRY="$(awk -v start="$MARKER_LINE" 'NR>start && /^  - / {count++; if(count==2){print; exit}}' wiki/mkdocs.yml)"
echo "$SECOND_ENTRY" | grep -q 'Glossary' || { cp "$TMP/mkdocs.yml.bak" wiki/mkdocs.yml; echo "FAIL: SC-7 Glossary not the second top-level nav entry"; exit 1; }
cp "$TMP/mkdocs.yml.bak" wiki/mkdocs.yml

# (b) FR-16 — knowledge adapter standard profile emits records
bash scripts/knowledge/lookup-mems.sh --kind=glossary --profile=standard --root . > "$TMP/std.txt" 2>/dev/null
N="$(grep -c '^id: gloss-' "$TMP/std.txt")"
[ "$N" -ge 3 ] || { echo "FAIL: SC-7 standard profile expected >= 3 records got $N"; exit 1; }

# Idempotency: ids stable across re-invocations
bash scripts/knowledge/lookup-mems.sh --kind=glossary --profile=standard --root . > "$TMP/std2.txt" 2>/dev/null
grep '^id: ' "$TMP/std.txt" | sort > "$TMP/ids1.txt"
grep '^id: ' "$TMP/std2.txt" | sort > "$TMP/ids2.txt"
diff -q "$TMP/ids1.txt" "$TMP/ids2.txt" >/dev/null || { echo "FAIL: SC-7 ids not idempotent across runs"; exit 1; }

# (c) FR-16 / MIT-010 Quick-profile touched-term branches
# Fixture glossary with three known terms
mkdir -p "$TMP/fixture/wiki"
cat > "$TMP/fixture/wiki/glossary.md" <<'EOF'
# Glossary

### Bar
Bar definition.

### Baz
Baz definition.

### Foo
Foo definition.
EOF

# Quick + task-description hit
bash scripts/knowledge/lookup-mems.sh --kind=glossary --profile=quick --task-description 'rename foo' --root "$TMP/fixture" > "$TMP/qhit.txt" 2>/dev/null
N="$(grep -c '^id: gloss-' "$TMP/qhit.txt")"
[ "$N" = "1" ] || { echo "FAIL: SC-7 Quick+task-desc hit expected 1 got $N"; exit 1; }
grep -q '^id: gloss-foo$' "$TMP/qhit.txt" || { echo "FAIL: SC-7 Quick+task-desc did not emit gloss-foo"; exit 1; }

# MIT-010 safe-default-no-terms — Quick with no hints
bash scripts/knowledge/lookup-mems.sh --kind=glossary --profile=quick --root "$TMP/fixture" > "$TMP/qsafe.txt" 2>/dev/null
N="$(grep -c '^id: gloss-' "$TMP/qsafe.txt")"
[ "$N" = "0" ] || { echo "FAIL: SC-7 MIT-010 safe-default expected 0 got $N"; exit 1; }

echo "PASS: SC-7 p02-glossary-surface"
```

3. **Author `tests/paired-m032-m033/seam-A.sh`** (#Q-B Seam-A). Required structure:

```bash
#!/usr/bin/env bash
# Seam-A — shared install-bundle surface invariant: project_assets: schema shape M033 consumes.
set -eu

# Manifest carries project_assets: section
[ -f packaging/bundle/manifest.yml ] || { echo "FAIL: Seam-A manifest missing"; exit 1; }
grep -q '^project_assets:$' packaging/bundle/manifest.yml || { echo "FAIL: Seam-A project_assets section missing"; exit 1; }

# Reader emits tuples
TUPLES="$(bash scripts/lifecycle/read-project-assets.sh packaging/bundle/ 2>/dev/null || true)"
[ -n "$TUPLES" ] || { echo "FAIL: Seam-A reader emitted zero tuples"; exit 1; }

# At least 5 tuples (4 P01 runtime dirs + 1 P02 wiki)
TUPLE_COUNT="$(echo "$TUPLES" | wc -l | tr -d ' ')"
[ "$TUPLE_COUNT" -ge 5 ] || { echo "FAIL: Seam-A expected >= 5 tuples (4 P01 + 1 P02 wiki) got $TUPLE_COUNT"; exit 1; }

# wiki/ entry present (P02/T01 deliverable)
echo "$TUPLES" | grep -q 'source=wiki/' || { echo "FAIL: Seam-A missing source=wiki/ tuple"; exit 1; }

# M033 will ship 7 new commands + 6 new scripts on top of this seam — assert the
# schema shape is stable: each tuple has source=, target=, mode= fields
echo "$TUPLES" | while IFS= read -r tuple; do
  echo "$tuple" | grep -q '^source=' || { echo "FAIL: Seam-A tuple missing source: '$tuple'"; exit 1; }
  echo "$tuple" | grep -q $'\ttarget=' || { echo "FAIL: Seam-A tuple missing target: '$tuple'"; exit 1; }
  echo "$tuple" | grep -q $'\tmode=' || { echo "FAIL: Seam-A tuple missing mode: '$tuple'"; exit 1; }
done

echo "PASS: Seam-A project_assets shape (M033 ↔ M032)"
```

4. **Author `tests/paired-m032-m033/seam-B.sh`** (#Q-B Seam-B). Exercises the FR-11 / MIT-011 failure-propagation contract via `M032_WIKI_INIT_FORCE_EXIT=7` injection. Required structure:

```bash
#!/usr/bin/env bash
# Seam-B — --with-wiki failure-propagation contract per FR-11 / MIT-011.
set -eu

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Stage a fresh fixture
cp -R tests/fixtures/m032-fresh-project-fixture/. "$TMP/"
( cd "$TMP" && git init -q && git remote add origin https://github.com/fixture-owner/m032-fresh-project-fixture.git ) >/dev/null 2>&1

# Inject failure into wiki-init.sh via env-var
set +e
M032_WIKI_INIT_FORCE_EXIT=7 bash scripts/lifecycle/init-project.sh --with-wiki --project-dir "$TMP" >"$TMP/out" 2>"$TMP/err"
RC=$?
set -e

# (a) Compound exit code is wiki-init.sh's literal exit code (7), NOT 0, NOT 1.
[ "$RC" = "7" ] || { echo "FAIL: Seam-B compound exit expected 7 got $RC"; exit 1; }

# (b) init outputs preserved on wiki-init failure
[ -d "$TMP/.orchestrator" ] || { echo "FAIL: Seam-B init outputs not preserved on wiki-init failure"; exit 1; }

# (c) init-complete, wiki-pending diagnostic on stderr
grep -q 'init-complete, wiki-pending' "$TMP/err" || { echo "FAIL: Seam-B missing init-complete, wiki-pending diagnostic"; exit 1; }

# (d) wiki-init outputs absent (the failure aborted before staging)
[ ! -f "$TMP/wiki/mkdocs.yml" ] || { echo "FAIL: Seam-B wiki/mkdocs.yml present despite forced failure"; exit 1; }

# (e) M033/P01..P04 stub-mode compatibility per M033-MIT-001: caller can re-run wiki-init independently.
unset M032_WIKI_INIT_FORCE_EXIT
bash scripts/lifecycle/wiki-init.sh --project-dir "$TMP" >/dev/null 2>&1 || { echo "FAIL: Seam-B independent wiki-init re-run failed"; exit 1; }
[ -f "$TMP/wiki/mkdocs.yml" ] || { echo "FAIL: Seam-B independent wiki-init did not stage mkdocs.yml"; exit 1; }

echo "PASS: Seam-B --with-wiki failure-propagation (FR-11 / MIT-011)"
```

5. **Author `tests/paired-m032-m033/seam-C.sh`** (#Q-B Seam-C). Required structure:

```bash
#!/usr/bin/env bash
# Seam-C — wiki/glossary.md format invariant. Both M032 (path owner) and M033 (writer via grilling-shell) honor.
set -eu

G="wiki/glossary.md"
[ -f "$G" ] || { echo "FAIL: Seam-C $G missing at orchestrator root"; exit 1; }

# Format invariant: ### TERM headings present
HC="$(grep -c '^### ' "$G")"
[ "$HC" -ge 3 ] || { echo "FAIL: Seam-C $G needs >= 3 ### TERM entries; got $HC"; exit 1; }

# Alphabetized at file scope
TERMS_TMP="$(mktemp)"
SORTED_TMP="$(mktemp)"
trap 'rm -f "$TERMS_TMP" "$SORTED_TMP"' EXIT
grep '^### ' "$G" | sed 's/^### //' > "$TERMS_TMP"
sort "$TERMS_TMP" > "$SORTED_TMP"
diff -q "$TERMS_TMP" "$SORTED_TMP" >/dev/null || { echo "FAIL: Seam-C entries not alphabetized"; exit 1; }

# One-line definition under each heading (within 2 lines)
awk '/^### /{h=NR; t=$0; next} h && NR<=h+2 && NF>0 {h=0} END {if(h) {print "FAIL: Seam-C heading "t" has no definition body within 2 lines"; exit 1}}' "$G" || exit 1

# At-most-two-line elaboration: between this heading and the next ### heading,
# at most 4 non-empty lines total (1 definition + 2 elaboration + 1 separator slack)
awk '
  /^### / {
    if (term != "" && nonempty > 4) {
      print "FAIL: Seam-C term \"" term "\" has " nonempty " non-empty body lines (max 4)"
      exit 1
    }
    term = substr($0, 5)
    nonempty = 0
    next
  }
  NF > 0 { nonempty++ }
  END {
    if (term != "" && nonempty > 4) {
      print "FAIL: Seam-C term \"" term "\" has " nonempty " non-empty body lines (max 4)"
      exit 1
    }
  }
' "$G" || exit 1

echo "PASS: Seam-C wiki/glossary.md format invariant"
```

6. **Author the seven T05 verifiers** under `tools/verify/`:

   - `m032-p02-acceptance-shape-sc3.sh` — asserts `tests/m032-acceptance/p02-wiki-init-default-scope.sh` exists, contains `SC-3` and `FR-5` and `FR-6` and `FR-12` and `wiki-serve.sh` literals, exits 0 in dry-run shape inspection.
   - `m032-p02-acceptance-shape-sc7.sh` — asserts `tests/m032-acceptance/p02-glossary-surface.sh` exists, contains `SC-7` and `FR-15` and `FR-16` and `MIT-010` and `--profile=quick` literals.
   - `m032-p02-seam-a-shape.sh` — asserts `tests/paired-m032-m033/seam-A.sh` exists, contains `Seam-A` and `project_assets:` and `M033` literals.
   - `m032-p02-seam-b-shape.sh` — asserts `tests/paired-m032-m033/seam-B.sh` exists, contains `Seam-B` and `FR-11` and `MIT-011` and `M032_WIKI_INIT_FORCE_EXIT` and `init-complete, wiki-pending` literals.
   - `m032-p02-seam-c-shape.sh` — asserts `tests/paired-m032-m033/seam-C.sh` exists, contains `Seam-C` and `wiki/glossary.md` and `format invariant` and `###` literals.
   - `m032-p02-phase-suite.sh` — chains all twelve P02 sub-gates in dependency order; emits `SUMMARY: m032-p02-phase-suite.sh pass=N fail=M` before exit. Single-script-file shape per AD-19 — no compound bash chains, no `bash -c '...' && bash -c '...'`. Use a straight-line invocation pattern modeled on `tools/verify/m032-p01-phase-suite.sh`. The twelve sub-gates in order:
     1. `m032-p02-wiki-init-command-shape.sh` (T01)
     2. `m032-p02-wiki-init-default-scope.sh` (T01)
     3. `m032-p02-mkdocs-templating-and-self-application.sh` (T01)
     4. `m032-p02-init-with-wiki-passthrough.sh` (T02)
     5. `m032-p02-glossary-format-invariant.sh` (T03)
     6. `m032-p02-glossary-scanner-and-nav.sh` (T03)
     7. `m032-p02-lookup-mems-glossary.sh` (T04)
     8. `m032-p02-seam-a-shape.sh` (T05)
     9. `m032-p02-seam-b-shape.sh` (T05)
     10. `m032-p02-seam-c-shape.sh` (T05)
     11. `m032-p02-acceptance-shape-sc3.sh` (T05)
     12. `m032-p02-acceptance-shape-sc7.sh` (T05)

   Phase-suite skeleton:

```bash
#!/usr/bin/env bash
# tools/verify/m032-p02-phase-suite.sh — straight-line aggregator per AD-19.
set -u

PASS=0
FAIL=0

run_check() {
  local name="$1"
  if bash "tools/verify/$name.sh" >/dev/null 2>&1; then
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name" >&2
    FAIL=$((FAIL + 1))
  fi
}

run_check m032-p02-wiki-init-command-shape
run_check m032-p02-wiki-init-default-scope
run_check m032-p02-mkdocs-templating-and-self-application
run_check m032-p02-init-with-wiki-passthrough
run_check m032-p02-glossary-format-invariant
run_check m032-p02-glossary-scanner-and-nav
run_check m032-p02-lookup-mems-glossary
run_check m032-p02-seam-a-shape
run_check m032-p02-seam-b-shape
run_check m032-p02-seam-c-shape
run_check m032-p02-acceptance-shape-sc3
run_check m032-p02-acceptance-shape-sc7

echo "SUMMARY: m032-p02-phase-suite.sh pass=$PASS fail=$FAIL"
[ "$FAIL" = "0" ] || exit 1
exit 0
```

   - `m032-p02-scope-guard.sh` — asserts P02's diff is confined to the declared "Files Likely Touched" list per the P01 scope-guard pattern. Uses committed-history-only diff against a baseline ref captured at first run (modeled on P01 — `tools/verify/fixtures/m032-p01-baseline-ref.txt`; T05 records `tools/verify/fixtures/m032-p02-baseline-ref.txt` at first invocation). The allowlist is the P02 "Files Likely Touched" set: `commands/wiki-init.md`, `scripts/lifecycle/wiki-init.sh`, `wiki/mkdocs.yml`, `packaging/bundle/manifest.yml`, `commands/init.md`, `scripts/lifecycle/init-project.sh`, `wiki/glossary.md`, `scripts/wiki/wiki-scan-sources.sh`, `scripts/wiki/wiki-generate-nav.sh`, `scripts/knowledge/lookup-mems.sh`, `tests/m032-acceptance/p02-*.sh`, `tests/paired-m032-m033/seam-*.sh`, `tools/verify/m032-p02-*.sh`, `tools/verify/lib/m032-p02-wiki-serve-probe.sh`, `.orchestrator/milestones/M032/phases/P02/**` (plan + summary files). Every other path in the diff is OUT-OF-SCOPE and the guard fails closed.

   Scope-guard skeleton (modeled on P01):

```bash
#!/usr/bin/env bash
# tools/verify/m032-p02-scope-guard.sh — SC-13 scope discipline for P02.
set -eu

BASELINE_FIXTURE="tools/verify/fixtures/m032-p02-baseline-ref.txt"
if [ ! -f "$BASELINE_FIXTURE" ]; then
  # First run: capture current HEAD as baseline; PASS unconditionally.
  mkdir -p "$(dirname "$BASELINE_FIXTURE")"
  git rev-parse HEAD > "$BASELINE_FIXTURE"
  echo "PASS: m032-p02 scope-guard (baseline captured at $(cat "$BASELINE_FIXTURE"))"
  exit 0
fi

BASELINE_REF="$(cat "$BASELINE_FIXTURE")"

# Committed-history-only diff (per P01 patterns-established lessons — working-tree
# dirt pollutes the scope signal otherwise).
DIFF_PATHS="$(git diff --name-only "$BASELINE_REF" HEAD 2>/dev/null || true)"

# Allowlist regex — paths matching are P02-scoped.
ALLOWED_RE='^(commands/wiki-init\.md|scripts/lifecycle/wiki-init\.sh|wiki/mkdocs\.yml|packaging/bundle/manifest\.yml|commands/init\.md|scripts/lifecycle/init-project\.sh|wiki/glossary\.md|scripts/wiki/wiki-scan-sources\.sh|scripts/wiki/wiki-generate-nav\.sh|scripts/knowledge/lookup-mems\.sh|tests/m032-acceptance/p02-.*\.sh|tests/paired-m032-m033/seam-.*\.sh|tools/verify/m032-p02-.*\.sh|tools/verify/lib/m032-p02-.*\.sh|tools/verify/fixtures/m032-p02-.*|\.orchestrator/milestones/M032/phases/P02/.*)$'

OUT_OF_SCOPE=""
echo "$DIFF_PATHS" | while IFS= read -r path; do
  [ -n "$path" ] || continue
  if ! echo "$path" | grep -E "$ALLOWED_RE" >/dev/null; then
    echo "OUT-OF-SCOPE: $path" >&2
    OUT_OF_SCOPE=1
  fi
done

# (Subshell variable propagation gotcha: the while-loop's OUT_OF_SCOPE assignment
# does not propagate to the parent shell. Use a marker file instead.)
MARKER="$(mktemp)"
trap 'rm -f "$MARKER"' EXIT
echo "$DIFF_PATHS" | while IFS= read -r path; do
  [ -n "$path" ] || continue
  if ! echo "$path" | grep -E "$ALLOWED_RE" >/dev/null; then
    echo "OUT-OF-SCOPE: $path" >> "$MARKER"
  fi
done

if [ -s "$MARKER" ]; then
  cat "$MARKER" >&2
  echo "FAIL: m032-p02 scope-guard out-of-scope paths detected"
  exit 1
fi

echo "PASS: m032-p02 scope-guard ($(echo "$DIFF_PATHS" | wc -l | tr -d ' ') in-scope paths)"
exit 0
```

7. **Run the full P02 verifier battery locally** to confirm every gate passes:

```bash
bash tools/verify/m032-p02-phase-suite.sh
```

Expected output: `SUMMARY: m032-p02-phase-suite.sh pass=12 fail=0`.

## Must-Haves

- `tests/m032-acceptance/p02-wiki-init-default-scope.sh` (SC-3) exists, is executable, and exits 0 (or 77 with `SKIP_REASON` if `python3` unavailable per MIT-001).
- `tests/m032-acceptance/p02-glossary-surface.sh` (SC-7) exists, is executable, and exits 0.
- `tests/paired-m032-m033/seam-A.sh` exists, is executable, exits 0; asserts `project_assets:` schema shape M033 consumes (>= 5 tuples, `wiki/` tuple present, source/target/mode fields present).
- `tests/paired-m032-m033/seam-B.sh` exists, is executable, exits 0; asserts FR-11 / MIT-011 failure-propagation contract via `M032_WIKI_INIT_FORCE_EXIT=7` injection (compound exit 7, init outputs preserved, `init-complete, wiki-pending` diagnostic, independent wiki-init re-run succeeds).
- `tests/paired-m032-m033/seam-C.sh` exists, is executable, exits 0; asserts `wiki/glossary.md` format invariant (>= 3 ### TERM headings, alphabetized, one-line definition, at-most-two-line elaboration).
- `tools/verify/m032-p02-acceptance-shape-sc3.sh` and `tools/verify/m032-p02-acceptance-shape-sc7.sh` exist and exit 0.
- `tools/verify/m032-p02-seam-a-shape.sh`, `m032-p02-seam-b-shape.sh`, `m032-p02-seam-c-shape.sh` exist and exit 0.
- `tools/verify/m032-p02-phase-suite.sh` exists, chains all twelve P02 sub-gates in dependency order with single-script-file shape per AD-19, emits `SUMMARY: m032-p02-phase-suite.sh pass=12 fail=0` on success.
- `tools/verify/m032-p02-scope-guard.sh` exists, captures the baseline ref at `tools/verify/fixtures/m032-p02-baseline-ref.txt` on first run, and on subsequent runs asserts P02's diff is confined to the allowlist regex.

## Verification

```bash
bash tools/verify/m032-p02-acceptance-shape-sc3.sh
bash tools/verify/m032-p02-acceptance-shape-sc7.sh
bash tools/verify/m032-p02-seam-a-shape.sh
bash tools/verify/m032-p02-seam-b-shape.sh
bash tools/verify/m032-p02-seam-c-shape.sh
bash tools/verify/m032-p02-phase-suite.sh
bash tools/verify/m032-p02-scope-guard.sh
```

## Inputs

### From Previous Tasks

- `scripts/lifecycle/wiki-init.sh` (from T01) — invoked by SC-3 and Seam-B. Test-only escape `M032_WIKI_INIT_FORCE_EXIT=<n>` exits `<n>` immediately; consumed by Seam-B.
- `commands/wiki-init.md` (from T01) — referenced by `m032-p02-wiki-init-command-shape.sh` (T01 verifier, also chained from phase-suite).
- `wiki/mkdocs.yml` placeholders + FR-6 self-application (from T01) — verified by `m032-p02-mkdocs-templating-and-self-application.sh`.
- `tools/verify/lib/m032-p02-wiki-serve-probe.sh` (from T01) — invoked by SC-3 for the live HTTP probe at :8000.
- `commands/init.md` and `scripts/lifecycle/init-project.sh` (from T02) — invoked by Seam-B for the FR-11 / MIT-011 contract verification. Key API: `bash init-project.sh --with-wiki --project-dir <dir>` runs init then wiki-init sequentially; on wiki-init failure the compound exit code is wiki-init's literal exit code and `init-complete, wiki-pending` is on stderr.
- `wiki/glossary.md` (from T03) — read by SC-7 and Seam-C.
- `scripts/wiki/wiki-scan-sources.sh --include-glossary` (from T03) — invoked by SC-7.
- `scripts/wiki/wiki-generate-nav.sh` (from T03) — invoked by SC-7 for the Glossary-as-second-entry placement check.
- `scripts/knowledge/lookup-mems.sh --kind=glossary` (from T04) — invoked by SC-7. Key API: `--profile=quick` + `--task-description` / `--file-change-set` for touched-term filtering; `--profile=quick` with no hints emits zero records (MIT-010).

### From Disk (Pre-existing)

- `tests/fixtures/m032-fresh-project-fixture/` (P01 deliverable) — used by SC-3 and Seam-B as the staging baseline.
- `tests/m032-acceptance/` directory (P01 deliverable) — home for the SC-3 + SC-7 acceptance scripts.
- `tools/verify/fixtures/` directory — home for the scope-guard's baseline ref.
- `tools/verify/m032-p01-phase-suite.sh` and `tools/verify/m032-p01-scope-guard.sh` (P01 deliverables) — modeled on by the T05 phase-suite and scope-guard.

## Constraints

- T05 MUST NOT modify any T01–T04 deliverable. T05 is purely verification + paired-launch seam authorship.
- The phase-suite verifier MUST use single-script-file shape per AD-19 — straight-line `run_check <name>` invocations within a function body, no `bash -c '...' && bash -c '...'` chains, no `$()` containing pipes. The `run_check` helper invokes `bash "tools/verify/$name.sh"` with stdout / stderr suppressed; aggregate counters `PASS` and `FAIL` are simple integer additions.
- The scope-guard verifier MUST use committed-history-only diff (`git diff --name-only "$BASELINE_REF" HEAD`) per the P01 patterns-established lesson — working-tree-vs-baseline diff was the failure mode that produced the M032/P01 99-PASS-trajectory rebaseline.
- The scope-guard's allowlist regex MUST cover EVERY path the P02 plan declares as "Files Likely Touched" — additions to the path list during T05 author require corresponding regex extensions.
- The seam scripts MUST be executable (`chmod +x`) and MUST emit `PASS: Seam-A ...` / `PASS: Seam-B ...` / `PASS: Seam-C ...` to stdout on success. M033's verifier suite consumes these PASS lines per #Q-B.
- The SC-3 acceptance script MUST honor MIT-001 SKIP semantics: exit 77 with `SKIP_REASON: ...` to stdout when `python3` is unavailable (acceptance-battery T05 in P05 distinguishes 77 from pass / fail).
- Bash 3.2 compatibility per MEM001 in all verifiers and acceptance scripts — no `declare -A`, no `mapfile`, no process substitution.
- Plan-time discipline rule 6 (path-collision check): all seven new T05 verifiers, both new acceptance scripts, all three seam scripts, and the new fixture file `tools/verify/fixtures/m032-p02-baseline-ref.txt` do NOT exist on disk at plan-authoring time. Only `tests/m032-acceptance/` (directory) and `tools/verify/fixtures/` (directory) exist as parent containers.

## Expected Output

After T05 completes:

- `tests/m032-acceptance/p02-wiki-init-default-scope.sh` and `tests/m032-acceptance/p02-glossary-surface.sh` are new executable acceptance scripts.
- `tests/paired-m032-m033/seam-A.sh`, `seam-B.sh`, `seam-C.sh` are new executable seam scripts under a new directory.
- `tools/verify/m032-p02-acceptance-shape-sc3.sh`, `m032-p02-acceptance-shape-sc7.sh`, `m032-p02-seam-a-shape.sh`, `m032-p02-seam-b-shape.sh`, `m032-p02-seam-c-shape.sh`, `m032-p02-phase-suite.sh`, `m032-p02-scope-guard.sh` are new executable verifiers.
- `tools/verify/fixtures/m032-p02-baseline-ref.txt` is captured at scope-guard first run.
- `bash tools/verify/m032-p02-phase-suite.sh` emits `SUMMARY: m032-p02-phase-suite.sh pass=12 fail=0` on success.
- M033/P05 has the three paired-launch seam scripts to plan against per CON-3.

## Notes

- Expected verifier outputs: `PASS: m032-p02-acceptance-shape-sc3` / `PASS: m032-p02-acceptance-shape-sc7` / `PASS: Seam-A ...` / `PASS: Seam-B ...` / `PASS: Seam-C ...` / `SUMMARY: m032-p02-phase-suite.sh pass=12 fail=0` / `PASS: m032-p02 scope-guard ...` to stdout on exit 0.
- Plan-time discipline rule 2 (verifier-availability cross-check): all seven verifiers cited in `## Verification` are co-authored within this task in step 6.
- Plan-time discipline rule 6 (path-collision check): all new files do NOT exist on disk at plan-authoring time (verified — `ls tests/paired-m032-m033/` returns `No such file or directory`; `ls tools/verify/ | grep "m032-p02"` returns empty).
- The `seam-B.sh` independent-re-run branch (step 4 (e)) validates M033/P01..P04 stub-mode compatibility per M033-MIT-001 — M033's stub-mode tests can re-invoke `wiki-init.sh` directly without re-running `init-project.sh`. The seam asserts this compatibility now so M033 has a stable contract to plan against.
- The phase-suite's twelve sub-gates aggregate ALL P02 verifiers from T01–T05. Adding a verifier in any subsequent task requires updating both the phase-suite invocation list AND the count in the demo sentence + must-haves SUMMARY assertion. The current count is 12; if T01-T04 task plans extended their verifier sets, this list adapts during T05 implementation.
- The MIT-001 three-category exit-code convention (pass=0, skip=77, fail=other-non-zero) is asserted at SC-3 only (the only P02 SC with environment-dependent skip semantics — `python3` availability). SC-7 has no skip path; either the FR-15 + FR-16 surfaces work or they don't.
- Note on the `M032_WIKI_INIT_FORCE_EXIT` test-only escape: T01's `wiki-init.sh` includes the escape per the T02 prerequisite check. If T01 chose to land it in T02 instead (the flexibility called out in T02's step 5), the escape MUST be in place by the time T05 lands; Seam-B's prerequisite check at the top of the script asserts this.
- The scope-guard's baseline-ref file (`tools/verify/fixtures/m032-p02-baseline-ref.txt`) is captured at FIRST scope-guard run. Subsequent runs read the captured ref and diff against HEAD. If the scope-guard verifier ever needs to be re-baselined (e.g., after a milestone close), an operator deletes the fixture file and re-runs the scope-guard once to recapture. This pattern matches P01's `m032-p01-baseline-ref.txt` precedent.

## State Context

- **Current State**: executing
- **Milestone**: M032
- **Phase**: P02
- **Task**: T05-acceptance-and-seam-and-suite
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- T05 MUST NOT modify any T01–T04 deliverable. T05 is purely verification + paired-launch seam authorship.
- The phase-suite verifier MUST use single-script-file shape per AD-19 — straight-line `run_check <name>` invocations within a function body, no `bash -c '...' && bash -c '...'` chains, no `$()` containing pipes. The `run_check` helper invokes `bash "tools/verify/$name.sh"` with stdout / stderr suppressed; aggregate counters `PASS` and `FAIL` are simple integer additions.
- The scope-guard verifier MUST use committed-history-only diff (`git diff --name-only "$BASELINE_REF" HEAD`) per the P01 patterns-established lesson — working-tree-vs-baseline diff was the failure mode that produced the M032/P01 99-PASS-trajectory rebaseline.
- The scope-guard's allowlist regex MUST cover EVERY path the P02 plan declares as "Files Likely Touched" — additions to the path list during T05 author require corresponding regex extensions.
- The seam scripts MUST be executable (`chmod +x`) and MUST emit `PASS: Seam-A ...` / `PASS: Seam-B ...` / `PASS: Seam-C ...` to stdout on success. M033's verifier suite consumes these PASS lines per #Q-B.
- The SC-3 acceptance script MUST honor MIT-001 SKIP semantics: exit 77 with `SKIP_REASON: ...` to stdout when `python3` is unavailable (acceptance-battery T05 in P05 distinguishes 77 from pass / fail).
- Bash 3.2 compatibility per MEM001 in all verifiers and acceptance scripts — no `declare -A`, no `mapfile`, no process substitution.
- Plan-time discipline rule 6 (path-collision check): all seven new T05 verifiers, both new acceptance scripts, all three seam scripts, and the new fixture file `tools/verify/fixtures/m032-p02-baseline-ref.txt` do NOT exist on disk at plan-authoring time. Only `tests/m032-acceptance/` (directory) and `tools/verify/fixtures/` (directory) exist as parent containers.

### Acceptance Criteria

- `tests/m032-acceptance/p02-wiki-init-default-scope.sh` (SC-3) exists, is executable, and exits 0 (or 77 with `SKIP_REASON` if `python3` unavailable per MIT-001).
- `tests/m032-acceptance/p02-glossary-surface.sh` (SC-7) exists, is executable, and exits 0.
- `tests/paired-m032-m033/seam-A.sh` exists, is executable, exits 0; asserts `project_assets:` schema shape M033 consumes (>= 5 tuples, `wiki/` tuple present, source/target/mode fields present).
- `tests/paired-m032-m033/seam-B.sh` exists, is executable, exits 0; asserts FR-11 / MIT-011 failure-propagation contract via `M032_WIKI_INIT_FORCE_EXIT=7` injection (compound exit 7, init outputs preserved, `init-complete, wiki-pending` diagnostic, independent wiki-init re-run succeeds).
- `tests/paired-m032-m033/seam-C.sh` exists, is executable, exits 0; asserts `wiki/glossary.md` format invariant (>= 3 ### TERM headings, alphabetized, one-line definition, at-most-two-line elaboration).
- `tools/verify/m032-p02-acceptance-shape-sc3.sh` and `tools/verify/m032-p02-acceptance-shape-sc7.sh` exist and exit 0.
- `tools/verify/m032-p02-seam-a-shape.sh`, `m032-p02-seam-b-shape.sh`, `m032-p02-seam-c-shape.sh` exist and exit 0.
- `tools/verify/m032-p02-phase-suite.sh` exists, chains all twelve P02 sub-gates in dependency order with single-script-file shape per AD-19, emits `SUMMARY: m032-p02-phase-suite.sh pass=12 fail=0` on success.
- `tools/verify/m032-p02-scope-guard.sh` exists, captures the baseline ref at `tools/verify/fixtures/m032-p02-baseline-ref.txt` on first run, and on subsequent runs asserts P02's diff is confined to the allowlist regex.

### Files To Touch

- `commands/wiki-init.md` (create)
- `scripts/lifecycle/wiki-init.sh` (create)
- `wiki/mkdocs.yml` (modify — bundle copy gets placeholders; orchestrator-local copy gets resolved values via FR-6 self-application loop)
- `packaging/bundle/manifest.yml` (modify — add `wiki/` entry under existing `project_assets:` block from P01)
- `commands/init.md` (modify)
- `scripts/lifecycle/init-project.sh` (modify)
- `wiki/glossary.md` (create)
- `scripts/wiki/wiki-scan-sources.sh` (modify — add `--include-glossary` flag)
- `scripts/wiki/wiki-generate-nav.sh` (modify — Glossary as second top-level nav entry, additive only)
- `scripts/knowledge/lookup-mems.sh` (create)
- `tests/m032-acceptance/p02-wiki-init-default-scope.sh` (create)
- `tests/m032-acceptance/p02-glossary-surface.sh` (create)
- `tests/paired-m032-m033/seam-A.sh` (create)
- `tests/paired-m032-m033/seam-B.sh` (create)
- `tests/paired-m032-m033/seam-C.sh` (create)
- `tools/verify/m032-p02-wiki-init-command-shape.sh` (create)
- `tools/verify/m032-p02-wiki-init-default-scope.sh` (create)
- `tools/verify/m032-p02-mkdocs-templating-and-self-application.sh` (create)
- `tools/verify/m032-p02-init-with-wiki-passthrough.sh` (create)
- `tools/verify/m032-p02-glossary-format-invariant.sh` (create)
- `tools/verify/m032-p02-glossary-scanner-and-nav.sh` (create)
- `tools/verify/m032-p02-lookup-mems-glossary.sh` (create)
- `tools/verify/m032-p02-seam-a-shape.sh` (create)
- `tools/verify/m032-p02-seam-b-shape.sh` (create)
- `tools/verify/m032-p02-seam-c-shape.sh` (create)
- `tools/verify/m032-p02-acceptance-shape-sc3.sh` (create)
- `tools/verify/m032-p02-acceptance-shape-sc7.sh` (create)
- `tools/verify/m032-p02-phase-suite.sh` (create)
- `tools/verify/m032-p02-scope-guard.sh` (create)

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