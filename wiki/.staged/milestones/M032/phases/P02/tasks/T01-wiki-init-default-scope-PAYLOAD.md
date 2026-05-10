---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T01-wiki-init-default-scope (Phase P02, Milestone M032)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-978 | ~900 | required |
| Upstream Context | 980-1127 | ~2800 | required |
| Task Plan | 1129-1531 | ~8000 | required |
| State Context | 1533-1539 | ~100 | required |
| First-Turn Completeness | 1541-1596 | ~1300 | required |
| **Total** | | **~23900** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 810
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
hit_count: 810
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
hit_count: 810
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
hit_count: 810
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
hit_count: 704
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
hit_count: 704
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
hit_count: 704
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
hit_count: 810
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
hit_count: 704
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
hit_count: 704
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
hit_count: 704
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
hit_count: 810
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
hit_count: 810
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
hit_count: 810
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
hit_count: 704
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
hit_count: 704
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
hit_count: 704
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
hit_count: 810
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
hit_count: 704
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
hit_count: 704
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
hit_count: 810
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
hit_count: 810
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
hit_count: 704
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
hit_count: 704
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
hit_count: 704
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
hit_count: 359
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
hit_count: 359
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
hit_count: 359
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
hit_count: 386
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
hit_count: 386
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
hit_count: 376
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
task: "T01"
phase: "P02"
milestone: "M032"
name: "wiki-init.sh default scope + commands/wiki-init.md + mkdocs.yml templating + FR-6 self-application loop + bundle wiki/ project_assets entry (FR-5, FR-6, FR-12, MIT-002)"
depends_on: []
---

## Prerequisites

- `packaging/bundle/manifest.yml` exists and carries the P01 `project_assets:` section with exactly four entries (`commands/`, `scripts/`, `references/`, `templates/`). Verified by `[ -f packaging/bundle/manifest.yml ]` and `grep -q '^project_assets:$' packaging/bundle/manifest.yml`.
- `scripts/lifecycle/read-project-assets.sh` exists, is executable, and emits `source=<src>\ttarget=<tgt>\tmode=<copy|symlink>` tuples on stdout. Verified by `[ -x scripts/lifecycle/read-project-assets.sh ]`. Behavioral contract: the reader emits one tab-separated tuple per `project_assets:` entry, exits 0 on success.
- `scripts/lifecycle/install-asset-mode.sh` exists, is executable, and dispatches on `mode=copy` and `mode=symlink`. Verified by `[ -x scripts/lifecycle/install-asset-mode.sh ]`. Behavioral contract: takes `<src> <dst> <mode> <project-dir>` args; `mode=copy` runs `cp -R "$src/." "$dst/"`; `mode=symlink` is POSIX-only with `M032_FORCE_WINDOWS=1` fail-closed.
- `scripts/lifecycle/install-collision-check.sh` exists, is executable, and implements FR-22's three oracle branches. Verified by `[ -x scripts/lifecycle/install-collision-check.sh ]`.
- `wiki/mkdocs.yml` exists at the orchestrator-repo root with the four hardcoded site-identity values verified at `wiki/mkdocs.yml:10-13` (`site_name: "spec-kit-orchestrator — dogfood wiki"`, `site_description:`, `site_url:`, `repo_url:`). Verified by `grep -q '^site_name:' wiki/mkdocs.yml`.
- `wiki/overrides/partials/comments.html` exists with the four `data-repo` / `data-repo-id` / `data-category` / `data-category-id` Giscus attributes. P02/T01 does NOT modify this file; FR-7 templating is P03's deliverable. Verified by `[ -f wiki/overrides/partials/comments.html ]`.
- `scripts/wiki/wiki-serve.sh` exists and is executable. Used in step 5 to verify the FR-6 self-application loop.
- `tests/fixtures/m032-fresh-project-fixture/` exists from P01 (`.gitignore`, `.git-init-marker`, `README.md`). The fixture's git remote points at `https://github.com/fixture-owner/m032-fresh-project-fixture.git` per the marker contents.
- `tools/verify/` exists as the canonical home for project-owned slug-bearing verifiers per AD-19.
- `commands/` exists and contains pre-existing orchestrator command documents following the MEM012 structure (`init.md`, `dispatch.md`, etc.).
- T01 entry: this is the FIRST P02 task. None of `scripts/lifecycle/wiki-init.sh`, `commands/wiki-init.md`, or the `wiki/` entry in `packaging/bundle/manifest.yml` exists yet.

## Description

T01 ships the foundational P02 surface. It (a) authors `commands/wiki-init.md` per the MEM012 orchestrator command-file convention; (b) authors `scripts/lifecycle/wiki-init.sh` implementing the FR-5 default-scope invocation (no `--with-giscus`, no `--deploy`) — Python toolchain probe + git-remote parsing + sed-substitution against `wiki/mkdocs.yml` placeholders; (c) amends `wiki/mkdocs.yml` to replace the four hardcoded site-identity values with `{{...}}` placeholders; (d) closes the FR-6 self-application loop within this task by running `bash scripts/lifecycle/wiki-init.sh --project-dir .` against the orchestrator repo itself, resolving the placeholders to the orchestrator's identity, and verifying `bash scripts/wiki/wiki-serve.sh` continues to return HTTP 200 (per AD-5 / MIT-002); (e) amends `packaging/bundle/manifest.yml` to add a `wiki/` entry under the existing P01 `project_assets:` block.

The atomicity argument for landing all five sub-deliverables in a single task: FR-6 self-application is non-optional within this task per MIT-002 — without it the orchestrator's own wiki breaks for the duration of M032 + M033 paired development. The bundle `wiki/` entry must land in the same task as `wiki-init.sh` because `wiki-init.sh` reads its bundle source paths via `read-project-assets.sh` against the new entry; splitting the bundle entry into a separate task introduces a no-op test window where `wiki-init.sh` exists but cannot stage any files.

The bundle vs orchestrator-local distinction: `wiki/mkdocs.yml` is BOTH the bundle-staged template (carrying placeholders verbatim — copied by `install-asset-mode.sh` at `mode: copy` to `<PROJECT_DIR>/wiki/mkdocs.yml`, then sed-substituted by `wiki-init.sh`) AND the orchestrator-repo-local resolved version (after the FR-6 self-application loop runs in step 5 below). The bundle copy lives at `wiki/mkdocs.yml` in the orchestrator repo (because the manifest's `wiki/` entry uses `source: wiki/`); the resolved version overwrites the same path after the self-application loop. This is acceptable because the orchestrator's identity values at the bundle-source path render correctly under `wiki-serve.sh` (the placeholders RESOLVE to the orchestrator's own identity when `--project-dir .` is passed). Future bundle pulls by external consumers re-run the sed-substitution against THEIR git remote.

## Steps

1. **Author `commands/wiki-init.md`** following the MEM012 orchestrator command-file convention. Required structure:

```markdown
---
description: "Use when initializing a wiki for a project — installs wiki tooling from the bundle, templates mkdocs.yml from the project's git remote, and probes Python toolchain. Default scope; --with-giscus and --deploy compose on top (P03 deliverables)."
---

# orchestrator:wiki-init

Initialize a working mkdocs Material wiki for any orchestrator-managed project.

## Prerequisites / State Check

- `packaging/bundle/manifest.yml` carries a `project_assets:` entry with `source: wiki/` (P01 + P02/T01 deliverable).
- The consumer project has a git remote at `origin` pointing at `https://github.com/<owner>/<repo>` (parsed for templated values).
- `python3` and `pip3` are on `PATH` (probed at invocation; missing toolchain fails closed with platform-aware diagnostic).

## Core Workflow

### Default scope (no extension flags)

1. Read wiki tooling from `project_assets:` entries via `scripts/lifecycle/read-project-assets.sh`.
2. Probe `python3` and `pip3` on `PATH`. Missing toolchain → fail closed with `brew install python3` (darwin) or `apt install python3` (linux).
3. Parse `git -C "$PROJECT_DIR" remote get-url origin` to derive `<owner>/<repo>`. Synthesize the four `{{...}}` values:
   - `site_name`: `<repo>` (default; overridable via `--site-name`).
   - `site_description`: empty string default; overridable via `--site-description`.
   - `site_url`: `https://<owner>.github.io/<repo>/`.
   - `repo_url`: `https://github.com/<owner>/<repo>`.
4. Stage `wiki/mkdocs.yml` to `<PROJECT_DIR>/wiki/mkdocs.yml` via the P01 mode handler.
5. Sed-substitute the four `{{...}}` placeholders in the staged `mkdocs.yml`.
6. Stage `wiki/overrides/partials/comments.html` to `<PROJECT_DIR>/wiki/overrides/partials/comments.html` UNCHANGED (Giscus partial templating is P03's `--with-giscus` deliverable).
7. Author `<PROJECT_DIR>/wiki/glossary.md` as a path-convention stub (FR-15 — T03 of P02 lands the orchestrator-repo-level canonical version; T01 ships only the consumer-side stub-author logic in `wiki-init.sh`).
8. Optional `--auto-pip` flag runs `pip install -r <PROJECT_DIR>/wiki/requirements.txt` per #Q-2; default behavior is print-and-exit.

### `--with-giscus`

P03 deliverable. P02 surface recognizes the flag and rejects with `not yet implemented in P02; reserved for P03`.

### `--with-wiki --deploy`

P03 deliverable. P02 surface recognizes the flag and rejects with `not yet implemented in P02; reserved for P03`.

## Output

- `<PROJECT_DIR>/wiki/mkdocs.yml` (staged + sed-substituted from git remote).
- `<PROJECT_DIR>/wiki/overrides/partials/comments.html` (staged unchanged).
- `<PROJECT_DIR>/wiki/glossary.md` (stub authored if absent; preserved if present per idempotency).
- `<PROJECT_DIR>/wiki/requirements.txt` (staged from bundle).

## Idempotency

A second invocation against an already-`wiki-init`'d project preserves operator edits to the templated files and exits 0 with `no changes` on stdout. The four `{{...}}` placeholder tokens are NOT re-substituted on re-run unless `--force` is passed (US-2 Acceptance Scenario 5).

## Error Handling

- Missing `python3` or `pip3` → exit non-zero with platform-aware diagnostic (`brew install python3` on darwin; `apt install python3` on linux); writes nothing.
- `git remote get-url origin` fails (no remote configured) → exit non-zero with `wiki-init: no git remote at origin; configure one with 'git remote add origin <url>' before running wiki-init`.
- `--with-giscus` or `--deploy` passed → exit non-zero with `not yet implemented in P02; reserved for P03`.

## Referenced Scripts

- `scripts/lifecycle/wiki-init.sh` — canonical implementation.
- `scripts/lifecycle/read-project-assets.sh` — bundle reader (P01).
- `scripts/lifecycle/install-asset-mode.sh` — per-mode handler (P01).
- `scripts/lifecycle/install-collision-check.sh` — FR-22 dual-oracle hierarchy (P01).
```

2. **Author `scripts/lifecycle/wiki-init.sh`** as the canonical implementation. The script's high-level structure (single-script-file shape per AD-19; bash 3.2 compatible per MEM001):

```bash
#!/usr/bin/env bash
# scripts/lifecycle/wiki-init.sh — FR-5 default scope + FR-12 toolchain probe.
# Per MEM012 the canonical command document is commands/wiki-init.md.
# Per MEM001 this script is bash 3.2 compatible — no associative arrays,
# no process substitution, no command substitution containing pipes.
#
# Exit codes:
#   0 — success (or "no changes" idempotency).
#   2 — argument error (unknown flag, missing required arg).
#   3 — toolchain missing (python3 or pip3 not on PATH).
#   4 — git remote missing or unparseable.
#   5 — --with-giscus or --deploy passed (P03 deliverable; P02 rejects).
#   6 — bundle staging failure (read-project-assets.sh or install-asset-mode.sh failed).
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT_DIR=""
SITE_NAME_OVERRIDE=""
SITE_DESCRIPTION_OVERRIDE=""
AUTO_PIP=0
WITH_GISCUS=0
WITH_DEPLOY=0
FORCE=0

# Argument parsing — single-pass loop, no getopts (bash 3.2 portability).
while [ $# -gt 0 ]; do
  case "$1" in
    --project-dir) PROJECT_DIR="$2"; shift 2 ;;
    --project-dir=*) PROJECT_DIR="${1#--project-dir=}"; shift ;;
    --site-name) SITE_NAME_OVERRIDE="$2"; shift 2 ;;
    --site-name=*) SITE_NAME_OVERRIDE="${1#--site-name=}"; shift ;;
    --site-description) SITE_DESCRIPTION_OVERRIDE="$2"; shift 2 ;;
    --site-description=*) SITE_DESCRIPTION_OVERRIDE="${1#--site-description=}"; shift ;;
    --auto-pip) AUTO_PIP=1; shift ;;
    --with-giscus) WITH_GISCUS=1; shift ;;
    --deploy) WITH_DEPLOY=1; shift ;;
    --force) FORCE=1; shift ;;
    *) echo "FAIL: wiki-init: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

[ -n "$PROJECT_DIR" ] || { echo "FAIL: wiki-init: --project-dir is required" >&2; exit 2; }
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

# P02 rejects --with-giscus and --deploy (P03 deliverables).
if [ "$WITH_GISCUS" = "1" ] || [ "$WITH_DEPLOY" = "1" ]; then
  echo "FAIL: wiki-init: --with-giscus and --deploy not yet implemented in P02; reserved for P03" >&2
  exit 5
fi

# FR-12: probe python3 + pip3.
if ! command -v python3 >/dev/null 2>&1 || ! command -v pip3 >/dev/null 2>&1; then
  uname_s="$(uname -s 2>/dev/null || echo unknown)"
  if [ "$uname_s" = "Darwin" ]; then
    echo "FAIL: wiki-init: python3/pip3 missing — install via 'brew install python3'" >&2
  else
    echo "FAIL: wiki-init: python3/pip3 missing — install via 'apt install python3' (or your distro equivalent)" >&2
  fi
  exit 3
fi

# FR-5: parse git remote for the four templated values.
ORIGIN_URL="$(git -C "$PROJECT_DIR" remote get-url origin 2>/dev/null || true)"
if [ -z "$ORIGIN_URL" ]; then
  echo "FAIL: wiki-init: no git remote at origin in $PROJECT_DIR; configure one with 'git remote add origin <url>' before running wiki-init" >&2
  exit 4
fi

# Parse <owner>/<repo> from either https or ssh remote shapes.
# Examples:
#   https://github.com/Build-Fractal/spec-kit-orchestrator(.git)
#   git@github.com:Build-Fractal/spec-kit-orchestrator(.git)
OWNER_REPO="$(echo "$ORIGIN_URL" | sed -E 's#^https?://github\.com/##; s#^git@github\.com:##; s#\.git$##')"
OWNER="${OWNER_REPO%%/*}"
REPO="${OWNER_REPO##*/}"
if [ -z "$OWNER" ] || [ -z "$REPO" ] || [ "$OWNER" = "$OWNER_REPO" ]; then
  echo "FAIL: wiki-init: cannot parse <owner>/<repo> from origin URL '$ORIGIN_URL'" >&2
  exit 4
fi

# Synthesize templated values.
SITE_NAME="${SITE_NAME_OVERRIDE:-$REPO}"
SITE_DESCRIPTION="${SITE_DESCRIPTION_OVERRIDE:-}"
SITE_URL="https://${OWNER}.github.io/${REPO}/"
REPO_URL="https://github.com/${OWNER}/${REPO}"

# FR-5 step (a): stage wiki tooling via P01 reader + mode handler.
# The bundle staging loop reuses the P01 read-project-assets / install-asset-mode helpers.
# Only the wiki-related project_assets entry is staged here (the four runtime dirs
# are P01's responsibility under install-{claude-code,codex,cursor}.sh).
TUPLES="$(bash "$REPO_ROOT/scripts/lifecycle/read-project-assets.sh" "$REPO_ROOT/packaging/bundle/" || true)"
if [ -z "$TUPLES" ]; then
  echo "FAIL: wiki-init: read-project-assets.sh emitted zero tuples; check $REPO_ROOT/packaging/bundle/manifest.yml for project_assets section" >&2
  exit 6
fi

# Iterate tuples — stage only entries whose source begins with 'wiki' under wiki-init's responsibility.
# (The four runtime-dir entries are staged by install-claude-code.sh / install-codex.sh / install-cursor.sh.)
echo "$TUPLES" | while IFS= read -r tuple; do
  src="$(echo "$tuple" | awk -F'\t' '{print $1}' | sed 's/^source=//')"
  tgt="$(echo "$tuple" | awk -F'\t' '{print $2}' | sed 's/^target=//')"
  mode="$(echo "$tuple" | awk -F'\t' '{print $3}' | sed 's/^mode=//')"
  case "$src" in
    wiki/|wiki) : ;;  # stage
    *) continue ;;    # skip non-wiki entries (handled by installers in P01)
  esac
  src_abs="$REPO_ROOT/$src"
  tgt_abs="$PROJECT_DIR/$tgt"
  bash "$REPO_ROOT/scripts/lifecycle/install-collision-check.sh" "$tgt_abs" "$PROJECT_DIR" "$tgt"
  bash "$REPO_ROOT/scripts/lifecycle/install-asset-mode.sh" "$src_abs" "$tgt_abs" "$mode" "$PROJECT_DIR"
done

# FR-6: sed-substitute the four placeholders in the staged mkdocs.yml.
MKDOCS_TARGET="$PROJECT_DIR/wiki/mkdocs.yml"
if [ -f "$MKDOCS_TARGET" ]; then
  # Idempotency: detect if placeholders remain. If none remain AND --force is not set, emit "no changes" and exit 0.
  if ! grep -q '{{site_name}}\|{{site_description}}\|{{site_url}}\|{{repo_url}}' "$MKDOCS_TARGET" && [ "$FORCE" != "1" ]; then
    echo "wiki-init: no changes (mkdocs.yml already templated; pass --force to re-substitute)"
  else
    # Use a sed -i delimiter '|' to avoid escaping forward slashes in URLs.
    tmp="$(mktemp)"
    sed -e "s|{{site_name}}|${SITE_NAME}|g" \
        -e "s|{{site_description}}|${SITE_DESCRIPTION}|g" \
        -e "s|{{site_url}}|${SITE_URL}|g" \
        -e "s|{{repo_url}}|${REPO_URL}|g" \
        "$MKDOCS_TARGET" > "$tmp"
    mv "$tmp" "$MKDOCS_TARGET"
    echo "wiki-init: substituted site_name=${SITE_NAME} site_url=${SITE_URL} repo_url=${REPO_URL} in $MKDOCS_TARGET"
  fi
fi

# FR-15 path-convention stub: author wiki/glossary.md if absent.
GLOSSARY_TARGET="$PROJECT_DIR/wiki/glossary.md"
if [ ! -f "$GLOSSARY_TARGET" ]; then
  mkdir -p "$(dirname "$GLOSSARY_TARGET")"
  cat > "$GLOSSARY_TARGET" <<'GLOSSARYEOF'
# Glossary

Project glossary — alphabetized term entries with one-line definitions
and at most a two-line elaboration. M033's grilling protocol writes inline
into this file as terms resolve.

### Example Term

A one-line definition demonstrating the format invariant.

A two-line elaboration expanding on the definition, no longer than this paragraph.
GLOSSARYEOF
  echo "wiki-init: authored glossary stub at $GLOSSARY_TARGET"
fi

# FR-12 #Q-2: --auto-pip opt-in runs pip install; default is print-and-exit.
REQ_FILE="$PROJECT_DIR/wiki/requirements.txt"
if [ -f "$REQ_FILE" ]; then
  if [ "$AUTO_PIP" = "1" ]; then
    pip3 install -r "$REQ_FILE" || { echo "FAIL: wiki-init: pip3 install -r $REQ_FILE failed" >&2; exit 6; }
  else
    echo "wiki-init: Python deps not installed. Run 'pip3 install -r $REQ_FILE' or re-invoke with --auto-pip"
  fi
fi

echo "wiki-init: done (project=$PROJECT_DIR site_name=${SITE_NAME})"
exit 0
```

3. **Amend `wiki/mkdocs.yml`** by replacing the four hardcoded site-identity values at lines 10-13 with `{{...}}` placeholders. Exact replacements:

```diff
-site_name: "spec-kit-orchestrator — dogfood wiki"
-site_description: "Browseable projection of .orchestrator/ artifacts for the dogfood team."
-site_url: "https://build-fractal.github.io/spec-kit-orchestrator/"
-repo_url: "https://github.com/Build-Fractal/spec-kit-orchestrator"
+site_name: "{{site_name}}"
+site_description: "{{site_description}}"
+site_url: "{{site_url}}"
+repo_url: "{{repo_url}}"
```

This is the BUNDLE-STAGED state. The orchestrator-repo-local resolved state is restored in step 5 below by running `wiki-init.sh --project-dir .`.

4. **Amend `packaging/bundle/manifest.yml`** by adding a `wiki/` entry at the END of the existing P01 `project_assets:` block. The four pre-existing entries (`commands/`, `scripts/`, `references/`, `templates/`) MUST be byte-preserved. Exact append (after the last `mode: copy` line of the four pre-existing entries):

```yaml
  - source: wiki/
    target: wiki/
    mode: copy
```

5. **Close the FR-6 self-application loop within this task per AD-5 / MIT-002**. Run, in order, from the orchestrator repo root:

```bash
bash scripts/lifecycle/wiki-init.sh --project-dir .
```

This invocation:
- Probes python3/pip3 (orchestrator dev box has them per A-2 implication).
- Parses the orchestrator's own git remote (`https://github.com/Build-Fractal/spec-kit-orchestrator`) → `OWNER=Build-Fractal`, `REPO=spec-kit-orchestrator`.
- Synthesizes the four values (`site_name=spec-kit-orchestrator`, `site_url=https://build-fractal.github.io/spec-kit-orchestrator/`, `repo_url=https://github.com/Build-Fractal/spec-kit-orchestrator`, `site_description=`).
- Sed-substitutes the four placeholders in `wiki/mkdocs.yml` (resolving them back to working values).
- After this step the orchestrator-repo-local `wiki/mkdocs.yml` carries RESOLVED values and `bash scripts/wiki/wiki-serve.sh` continues to function.

Note: the bundle-staged copy at `wiki/` (which IS this same path because the manifest's `wiki/` entry uses `source: wiki/`) ends up resolved to orchestrator-identity values. This is acceptable because external consumers re-run sed-substitution against THEIR git remote when they invoke `wiki-init.sh --project-dir <consumer>` — the substitution is idempotent against placeholders AND against already-resolved values, because `--site-name=<consumer-repo>` etc. would re-substitute via the `--force` flag. Verifier `m032-p02-mkdocs-templating-and-self-application.sh` asserts BOTH (a) the orchestrator-repo-local `wiki/mkdocs.yml` carries resolved orchestrator values AND (b) `bash scripts/wiki/wiki-serve.sh --check-only` (or equivalent — `wiki-serve.sh` must return HTTP 200 in a startup probe) succeeds.

Important: the `wiki-init.sh` invocation against `--project-dir .` will route through `read-project-assets.sh` which iterates ALL five tuples (the four runtime dirs + the new wiki entry); the script's filter at step 2 above (`case "$src" in wiki/|wiki) ... esac`) ensures only the wiki entry is staged. The four runtime-dir tuples are skipped (they belong to the three installers' staging loops in P01).

6. **Author the three T01 verifiers** under `tools/verify/`:

   **`m032-p02-wiki-init-command-shape.sh`** — asserts `commands/wiki-init.md` exists, has YAML frontmatter with a `description:` field, has the seven required sections from MEM012 (`Title`, `Prerequisites`, `Core Workflow`, `Output`, `Idempotency`, `Error Handling`, `Referenced Scripts`), references `scripts/lifecycle/wiki-init.sh` as the canonical implementation, and mentions FR-5 + FR-12 by name. Single-script-file shape per AD-19. Example skeleton:

```bash
#!/usr/bin/env bash
set -eu
DOC="commands/wiki-init.md"
[ -f "$DOC" ] || { echo "FAIL: $DOC missing"; exit 1; }
grep -q '^description:' "$DOC" || { echo "FAIL: $DOC missing description: in frontmatter"; exit 1; }
grep -q '^# orchestrator:wiki-init' "$DOC" || { echo "FAIL: $DOC missing title heading"; exit 1; }
grep -q '^## Prerequisites' "$DOC" || { echo "FAIL: $DOC missing Prerequisites section"; exit 1; }
grep -q '^## Core Workflow' "$DOC" || { echo "FAIL: $DOC missing Core Workflow section"; exit 1; }
grep -q '^## Output' "$DOC" || { echo "FAIL: $DOC missing Output section"; exit 1; }
grep -q '^## Idempotency' "$DOC" || { echo "FAIL: $DOC missing Idempotency section"; exit 1; }
grep -q '^## Error Handling' "$DOC" || { echo "FAIL: $DOC missing Error Handling section"; exit 1; }
grep -q '^## Referenced Scripts' "$DOC" || { echo "FAIL: $DOC missing Referenced Scripts section"; exit 1; }
grep -q 'scripts/lifecycle/wiki-init.sh' "$DOC" || { echo "FAIL: $DOC missing reference to scripts/lifecycle/wiki-init.sh"; exit 1; }
grep -q 'FR-5' "$DOC" || { echo "FAIL: $DOC missing FR-5 reference"; exit 1; }
grep -q 'FR-12' "$DOC" || { echo "FAIL: $DOC missing FR-12 reference"; exit 1; }
echo "PASS: m032-p02-wiki-init-command-shape"
```

   **`m032-p02-wiki-init-default-scope.sh`** — exercises `wiki-init.sh` against the P01 fresh-project fixture: stages a temp copy of the fixture via `mktemp -d` + `cp -R`, initializes a fake git remote pointing at `https://github.com/fixture-owner/m032-fresh-project-fixture.git`, runs `bash scripts/lifecycle/wiki-init.sh --project-dir <tmp>`, asserts `<tmp>/wiki/mkdocs.yml` exists and contains `site_name: m032-fresh-project-fixture` and `repo_url: https://github.com/fixture-owner/m032-fresh-project-fixture` and does NOT contain any `{{site_name}}` placeholder. Also asserts the FR-12 toolchain probe by exporting `PATH=/dev/null` (no python3) and asserting exit code 3 + diagnostic substring.

   **`m032-p02-mkdocs-templating-and-self-application.sh`** — asserts (a) `wiki/mkdocs.yml` after the FR-6 self-application loop in step 5 contains `site_name: "spec-kit-orchestrator` (resolved orchestrator value), (b) does NOT contain literal `{{site_name}}` (placeholder cleared by self-application), (c) the bundle source path (which is the same orchestrator-repo path under `source: wiki/`) is consistent, (d) `bash scripts/wiki/wiki-serve.sh` can start and respond HTTP 200 at `:8000` (use `(wiki-serve.sh & SERVE_PID=$!; sleep 3; curl -fsS http://localhost:8000 -o /dev/null; rc=$?; kill $SERVE_PID; exit $rc)` BUT extracted to a script-file shape per AD-19 — author a tiny helper `tools/verify/lib/m032-p02-wiki-serve-probe.sh` that does the start+probe+kill within a single script body, and have the parent verifier invoke it via `bash tools/verify/lib/m032-p02-wiki-serve-probe.sh`).

7. **Run all three verifiers locally** to confirm exit 0 from each.

## Must-Haves

- `commands/wiki-init.md` exists per the MEM012 structure with FR-5 / FR-12 references and `Referenced Scripts` pointing at `scripts/lifecycle/wiki-init.sh`.
- `scripts/lifecycle/wiki-init.sh` exists, is executable, implements the full default-scope flow, the FR-12 toolchain probe with platform-aware diagnostics, the git-remote-derived `<owner>/<repo>` parsing, the four-placeholder sed-substitution, the `--auto-pip` / `--site-name` / `--site-description` / `--force` / `--with-giscus` (P03-reject) / `--deploy` (P03-reject) flag handling, and idempotent re-run.
- `wiki/mkdocs.yml` carries the four `{{...}}` placeholders at lines 10-13 in the bundle-source state, AND has been resolved back to orchestrator-identity values via the FR-6 self-application loop run inside this task per AD-5 / MIT-002.
- `packaging/bundle/manifest.yml` has the additive `wiki/` entry under `project_assets:`; the four pre-existing P01 entries are byte-preserved.
- The orchestrator's own `bash scripts/wiki/wiki-serve.sh` returns HTTP 200 at `:8000` after the self-application loop completes (closes the FR-6 / MIT-002 self-application loop).
- All three T01 verifiers under `tools/verify/m032-p02-{wiki-init-command-shape,wiki-init-default-scope,mkdocs-templating-and-self-application}.sh` exist, are executable, and exit 0 against the T01-landed surface.

## Verification

```bash
bash tools/verify/m032-p02-wiki-init-command-shape.sh
bash tools/verify/m032-p02-wiki-init-default-scope.sh
bash tools/verify/m032-p02-mkdocs-templating-and-self-application.sh
```

## Inputs

### From Previous Tasks

None within P02. Cross-phase inputs from P01 below.

### From Disk (Pre-existing)

- `packaging/bundle/manifest.yml` — pre-M032 manifest schema + the P01 `project_assets:` section with four entries. Key API: top-level YAML keys (`schema_version`, `type`, `name`, `version`, `description`, `skill_spec`, `skills`, `hooks`, `config_default`, `runtime_compatibility`, `project_assets`); each `project_assets:` entry has `source:`, `target:`, `mode:` keys. T01 amends the file by appending one new entry (`source: wiki/`, `target: wiki/`, `mode: copy`).
- `scripts/lifecycle/read-project-assets.sh` — P01 reader. Key API: `bash read-project-assets.sh <bundle-dir>` emits one line per `project_assets:` entry as `source=<src>\ttarget=<tgt>\tmode=<copy|symlink>` on stdout; exits 0 on success.
- `scripts/lifecycle/install-asset-mode.sh` — P01 per-mode handler. Key API: `bash install-asset-mode.sh <src-abs> <dst-abs> <mode> <project-dir-abs>`; `mode=copy` runs `cp -R "$src/." "$dst/"`; `mode=symlink` is POSIX-only with `M032_FORCE_WINDOWS=1` fail-closed.
- `scripts/lifecycle/install-collision-check.sh` — P01 dual-oracle hierarchy. Key API: `bash install-collision-check.sh <target-abs> <project-dir-abs> <project-assets-target-list>`; exits 0 on no-collision, exits 4 on operator-owned collision with `staged-dirs-collision:` diagnostic.
- `wiki/mkdocs.yml` — orchestrator-repo dogfood wiki config. Lines 10-13 carry the four hardcoded site-identity values that T01 replaces with placeholders.
- `wiki/overrides/partials/comments.html` — orchestrator-repo Giscus partial. T01 does NOT modify; FR-7 templating is P03's deliverable.
- `scripts/wiki/wiki-serve.sh` — pre-existing local-serve helper. Used in step 5 to verify FR-6 self-application loop closure.

## Constraints

- T01 MUST NOT touch any of the P01 deliverables (`packaging/install/install-{claude-code,codex,cursor}.sh`, `scripts/lifecycle/{read-project-assets,install-asset-mode,install-collision-check}.sh`); the P01 surface is consumed via direct invocation, not amended.
- T01 MUST NOT modify `wiki/overrides/partials/comments.html` (P03's `--with-giscus` deliverable).
- T01 MUST NOT split the existing `# >>> M012-P01 nav` markers in `wiki/mkdocs.yml` into auto-nav / custom-nav regions (P03's deliverable).
- The FR-6 self-application loop MUST run within this task per AD-5 / MIT-002 — failure to close the loop within T01 leaves the orchestrator's own wiki broken. The verifier `m032-p02-mkdocs-templating-and-self-application.sh` enforces this with the live `wiki-serve.sh` HTTP probe.
- All three T01 verifiers MUST use single-script-file shape per AD-19 — no inline compound bash, no plain subshells with sourcing, no command substitution containing pipes, no process substitution. The `wiki-serve.sh` HTTP probe is extracted to a separate helper script `tools/verify/lib/m032-p02-wiki-serve-probe.sh` to keep the parent verifier's invocations within the AD-19 envelope.
- The `wiki-init.sh` script MUST be bash 3.2 compatible per MEM001 — no `declare -A`, no `mapfile`, no process substitution, no `$()` containing pipes that exceed AD-19's one-pipe budget within compound contexts. Use parallel indexed arrays or line-by-line `while IFS= read -r` loops for any aggregate handling.
- `commands/wiki-init.md` MUST follow the MEM012 structure exactly — frontmatter with `description:`, the seven section headers in order, and a `Referenced Scripts` section pointing at `scripts/lifecycle/wiki-init.sh`.
- The bundle vs orchestrator-local distinction described in the Description section MUST be preserved: a bundle pull by an external consumer running `wiki-init.sh --project-dir <consumer>` MUST re-substitute against the consumer's git remote (idempotency against either placeholders or already-resolved values via `--force`).

## Expected Output

After T01 completes:

- `commands/wiki-init.md` is a new file at the orchestrator-repo root following MEM012 structure with FR-5 + FR-12 references.
- `scripts/lifecycle/wiki-init.sh` is a new executable file at the orchestrator-repo root implementing the full default-scope flow.
- `wiki/mkdocs.yml` carries the four `{{...}}` placeholders in the bundle-source state AND has been re-substituted to orchestrator-identity values via the FR-6 self-application loop. After the loop the file at this path looks identical to the pre-M032 state for `site_name` / `site_description` / `site_url` / `repo_url` (resolved values), with the placeholders only briefly observable during the substitution window (which is the correct behavior — the orchestrator's wiki must continue to render under `wiki-serve.sh`).
- `packaging/bundle/manifest.yml` has one additional `project_assets:` entry (`source: wiki/`, `target: wiki/`, `mode: copy`) appended after the four pre-existing P01 entries.
- The orchestrator's own `bash scripts/wiki/wiki-serve.sh` returns HTTP 200 at `:8000`.
- All three T01 verifiers exit 0.

## Notes

- Expected `wiki-init.sh` exit codes: 0 (success or no-changes idempotency), 2 (argument error), 3 (toolchain missing), 4 (git remote missing/unparseable), 5 (P03 flag passed in P02), 6 (bundle staging failure).
- The `wiki-init.sh` filter at step 2 above (`case "$src" in wiki/|wiki) ... esac`) is the seam that lets `wiki-init.sh` co-exist with the three installers' staging loops without double-staging the four runtime dirs. The filter is verified indirectly via `m032-p02-wiki-init-default-scope.sh` (which asserts `<fixture>/commands/`, `<fixture>/scripts/`, etc. are NOT created by `wiki-init.sh` against a fresh fixture).
- The bundle-source `wiki/mkdocs.yml` carries placeholders only in the brief window between step 3 and step 5. After step 5 it carries resolved orchestrator values. External consumers re-stage from the bundle (which by the time they pull is a git-tracked copy with resolved values) AND re-substitute against THEIR git remote — the substitution is idempotent against resolved values via `--force`.
- The single-script-file constraint per AD-19 forbids the inline `(wiki-serve.sh & ... ; kill $SERVE_PID)` shape directly under `## Verification`; the verifier `m032-p02-mkdocs-templating-and-self-application.sh` invokes a helper `tools/verify/lib/m032-p02-wiki-serve-probe.sh` that performs the start+probe+kill within a single script body. The helper script is co-authored alongside the verifier in this task.
- Plan-time discipline rule 2 (verifier-availability cross-check) is honored: all three verifiers cited in `## Verification` are co-authored within this task in step 6.
- Plan-time discipline rule 6 (path-collision check): `commands/wiki-init.md`, `scripts/lifecycle/wiki-init.sh`, `tools/verify/m032-p02-wiki-init-command-shape.sh`, `tools/verify/m032-p02-wiki-init-default-scope.sh`, `tools/verify/m032-p02-mkdocs-templating-and-self-application.sh`, and `tools/verify/lib/m032-p02-wiki-serve-probe.sh` do NOT exist on disk at plan-authoring time (verified). `wiki/mkdocs.yml` and `packaging/bundle/manifest.yml` are explicitly modified, not created.

## State Context

- **Current State**: executing
- **Milestone**: M032
- **Phase**: P02
- **Task**: T01-wiki-init-default-scope
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- T01 MUST NOT touch any of the P01 deliverables (`packaging/install/install-{claude-code,codex,cursor}.sh`, `scripts/lifecycle/{read-project-assets,install-asset-mode,install-collision-check}.sh`); the P01 surface is consumed via direct invocation, not amended.
- T01 MUST NOT modify `wiki/overrides/partials/comments.html` (P03's `--with-giscus` deliverable).
- T01 MUST NOT split the existing `# >>> M012-P01 nav` markers in `wiki/mkdocs.yml` into auto-nav / custom-nav regions (P03's deliverable).
- The FR-6 self-application loop MUST run within this task per AD-5 / MIT-002 — failure to close the loop within T01 leaves the orchestrator's own wiki broken. The verifier `m032-p02-mkdocs-templating-and-self-application.sh` enforces this with the live `wiki-serve.sh` HTTP probe.
- All three T01 verifiers MUST use single-script-file shape per AD-19 — no inline compound bash, no plain subshells with sourcing, no command substitution containing pipes, no process substitution. The `wiki-serve.sh` HTTP probe is extracted to a separate helper script `tools/verify/lib/m032-p02-wiki-serve-probe.sh` to keep the parent verifier's invocations within the AD-19 envelope.
- The `wiki-init.sh` script MUST be bash 3.2 compatible per MEM001 — no `declare -A`, no `mapfile`, no process substitution, no `$()` containing pipes that exceed AD-19's one-pipe budget within compound contexts. Use parallel indexed arrays or line-by-line `while IFS= read -r` loops for any aggregate handling.
- `commands/wiki-init.md` MUST follow the MEM012 structure exactly — frontmatter with `description:`, the seven section headers in order, and a `Referenced Scripts` section pointing at `scripts/lifecycle/wiki-init.sh`.
- The bundle vs orchestrator-local distinction described in the Description section MUST be preserved: a bundle pull by an external consumer running `wiki-init.sh --project-dir <consumer>` MUST re-substitute against the consumer's git remote (idempotency against either placeholders or already-resolved values via `--force`).

### Acceptance Criteria

- `commands/wiki-init.md` exists per the MEM012 structure with FR-5 / FR-12 references and `Referenced Scripts` pointing at `scripts/lifecycle/wiki-init.sh`.
- `scripts/lifecycle/wiki-init.sh` exists, is executable, implements the full default-scope flow, the FR-12 toolchain probe with platform-aware diagnostics, the git-remote-derived `<owner>/<repo>` parsing, the four-placeholder sed-substitution, the `--auto-pip` / `--site-name` / `--site-description` / `--force` / `--with-giscus` (P03-reject) / `--deploy` (P03-reject) flag handling, and idempotent re-run.
- `wiki/mkdocs.yml` carries the four `{{...}}` placeholders at lines 10-13 in the bundle-source state, AND has been resolved back to orchestrator-identity values via the FR-6 self-application loop run inside this task per AD-5 / MIT-002.
- `packaging/bundle/manifest.yml` has the additive `wiki/` entry under `project_assets:`; the four pre-existing P01 entries are byte-preserved.
- The orchestrator's own `bash scripts/wiki/wiki-serve.sh` returns HTTP 200 at `:8000` after the self-application loop completes (closes the FR-6 / MIT-002 self-application loop).
- All three T01 verifiers under `tools/verify/m032-p02-{wiki-init-command-shape,wiki-init-default-scope,mkdocs-templating-and-self-application}.sh` exist, are executable, and exit 0 against the T01-landed surface.

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