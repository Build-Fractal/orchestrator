---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T03-compression-eval (Phase P05, Milestone M018)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~900 | required |
| Upstream Context | 981-1379 | ~9700 | required |
| Task Plan | 1381-1773 | ~5100 | required |
| State Context | 1775-1781 | ~100 | required |
| First-Turn Completeness | 1783-1817 | ~800 | required |
| **Total** | | **~27400** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 688
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
hit_count: 688
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
hit_count: 688
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
hit_count: 688
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
hit_count: 615
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
hit_count: 615
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
hit_count: 615
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
hit_count: 688
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
hit_count: 615
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
hit_count: 615
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
hit_count: 615
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
hit_count: 688
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
hit_count: 688
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
hit_count: 688
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
hit_count: 615
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
hit_count: 615
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
hit_count: 615
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
hit_count: 688
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
hit_count: 615
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
hit_count: 615
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
hit_count: 688
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
hit_count: 688
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
hit_count: 615
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
hit_count: 615
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
hit_count: 615
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
hit_count: 270
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
hit_count: 270
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
hit_count: 270
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
hit_count: 264
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
hit_count: 264
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
hit_count: 254
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

<!-- AD-19: every Check is a single-script-file invocation. No inline
     compound bash, no plain subshells, no $(...|...). One verifier per
     truth, parked under scripts/verify/m018-p05-*.sh. -->

- `dispatch_usage` JSONL records carry additive integer fields `filter_dropped_tokens`, `tier1_savings_tokens`, `tier2_savings_tokens`, and `tier1_invocations`, populated by rolling up the matching `payload_breakdown` record(s) for the same `unitId` at emit-time; pre-P05 `dispatch_usage` records remain valid JSON; missing fields default to 0 in rollups (CON-5).
  - Check: `bash scripts/verify/m018-p05-dispatch-usage-additivity.sh`
- `unit_close` JSONL records carry additive integer fields `filter_dropped_tokens`, `tier1_savings_tokens`, `tier2_savings_tokens`, and `tier1_invocations`, computed by aggregating the per-task `payload_breakdown` records on the same milestone/phase/task scope at unit_close emit-time; pre-P05 `unit_close` records remain valid JSON; missing fields default to 0 in rollups (CON-5).
  - Check: `bash scripts/verify/m018-p05-unit-close-additivity.sh`
- `scripts/diagnostics/metrics-rollup.sh` cost rollup output includes a "Compression savings" block (or `FILTER_DROPPED_TOKENS` / `TIER1_SAVINGS_TOKENS` / `TIER2_SAVINGS_TOKENS` columns appended to the existing tabular shape) summing the additive fields across the resolved scope; absent fields contribute zero; the engine never aborts on logs predating the schema extension (CON-5 carry-forward).
  - Check: `bash scripts/verify/m018-p05-cost-rollup-savings-columns.sh`
- `scripts/diagnostics/efficiency-footer.sh` (M027/P02 helper) emits a one-line "Compressed: <pct>% reduction over baseline" tail after the existing footer body when any in-scope `payload_breakdown` record carries a non-zero savings field; suppressed under `--quiet` and under `compression.efficiency_footer.enabled: false` (FR-15 carry-forward); fixture-replay against a savings-bearing log shows the line, fixture-replay against a savings-free log omits it, byte-identity contract preserved.
  - Check: `bash scripts/verify/m018-p05-efficiency-footer-compression.sh`
- `scripts/diagnostics/check-anomalies.sh` (M027/P03 helper) flags a milestone whose moving-window savings ratio falls below the SC-9 calibrated 34.7% floor against the milestone's prior baseline; the flag is one stable line in the existing anomaly block (e.g., `FLAGGED <milestone> compression-regression savings_ratio=<pct> floor=0.347 reasons=compression-regression`), suppressed under `--no-anomaly` / `--yes` / `ORCHESTRATOR_AUTO=1` / `ORCH_ANOMALY_CHECK_ENABLED=false` per the existing suppression matrix; sample-size below floor surfaces "insufficient sample" rather than a noisy false-positive.
  - Check: `bash scripts/verify/m018-p05-doctor-compression-regression.sh`
- `scripts/diagnostics/compression-eval.sh` exists, accepts `--milestone <id>`, `--tier <N>` (1 or 2 in P05; tier 3 reserved for P06), and `--sample-floor <N>` (default 30 per cohort); reads `payload_breakdown` + `unit_close` records from `execution-log.jsonl`; segments compressed vs uncompressed cohorts (compressed = unit_close where the matching payload_breakdown carries the requested tier's savings field > 0; uncompressed = unit_close on the same milestone with the savings field absent or 0); reports per-cohort verification_pass_rate / retry_count / deviation_count plus the delta with a confidence interval; below-floor sample emits "insufficient sample" and exits 0; never aborts on degraded inputs (CON-5).
  - Check: `bash scripts/verify/m018-p05-compression-eval.sh`

<dispatch-volatile>

## Upstream Context


### P02 Summary
---
schema_version: "1.0"
type: phase-summary
id: P02
parent: M018
milestone: M018
provides: "knowledge-aware injection filter live in scripts/dispatch/build-context.sh + scripts/dispatch/lib/section-handlers.sh; preservation-contract self-check library scripts/lib/preservation-check.sh (sourceable: pres_check_section / pres_emit_violation / pres_density_pre_check); payload_filter JSONL record schema (record_type=payload_filter; fields: filter, drop_list, dropped_count, dropped_tokens, dropped_ids, source); payload_breakdown.filter_dropped_tokens additive field; compression_underperformance JSONL record (operational signal — never blocks); compression.knowledge_filter.* + compression.underperformance.* config keys + ORCH_OVERRIDE_COMPRESSION_ENABLED env override; six P02-private truth verifiers + tests/fixtures/m018-p02-knowledge-status fixture + golden baseline; CLAUDE.md/AGENTS.md recent-changes refresh"
requires: "P01 grammar contract Reviewed (references/compression-grammar.md v1.0.1); P00 SC-9 calibrated 34.7% floor; M020 status: field on knowledge entries (DEP-1)"
affects: "P03 (T1 microcompact — sources scripts/lib/preservation-check.sh; reuses tier_preservation_violation + payload_breakdown schema; consumes filter savings via additive filter_dropped_tokens field); P04 (T2 snip — same lib + per-tier savings field, MIT-01 nested-fence regex load-bearing); P05 (eval harness — reads compression_underperformance + payload_filter + future tier_preservation_violation records); P06 (T3 auto-compact — wires pres_density_pre_check before LLM call per MIT-08; tier-3-savings field additive)"
key_files: "scripts/lib/preservation-check.sh;scripts/lib/knowledge-filter.sh;scripts/dispatch/build-context.sh;scripts/dispatch/lib/section-handlers.sh;.orchestrator/config.yml;templates/config-defaults.yml;tests/fixtures/m018-p02-knowledge-status/knowledge-stream.md;tests/fixtures/m018-p02-knowledge-status/README.md;tests/fixtures/m018-p02-baseline-payload.golden.txt;scripts/verify/m018-p02-filter-drops.sh;scripts/verify/m018-p02-emitter-additivity.sh;scripts/verify/m018-p02-preservation-check-api.sh;scripts/verify/m018-p02-underperformance-emit.sh;scripts/verify/m018-p02-disable-flag-honored.sh;scripts/verify/m018-p02-dual-write-recent.sh;scripts/verify/_helpers/m018-p02-build-fixture.sh"
key_decisions: "Filter operates on whole-entry granularity per grammar contract `## Tier: filter` failure semantics — no interior preservation check at the entry level; preservation-check library sourced defensively in build-context.sh + section-handlers.sh so P03/P04/P06 inherit a working source path; filter is awk-driven for speed + AP-009 compliance; underperformance check is operational signal (never blocks dispatch); P02-stage logs may legitimately fall below the floor (tier1/2/3 not yet shipped) — handled via min_sample_size guard (default 10); ORCH_OVERRIDE_COMPRESSION_ENABLED env beats config (test seam, FR-15 SC-8); fail-open on missing status field (FR-3 / A-1 back-compat)"
patterns_established: "Sourceable lib pattern under scripts/lib/ for cross-tier reuse (T01 — preservation-check); pure-library pattern with optional config-aware accessors (T02 — knowledge-filter); awk-driven entry-boundary detection in bash 3.2 stream filters (T02); additive JSONL emitter pattern with stats-file handoff between collector and emitter (T02); operational-signal JSONL records that never block dispatch (T03 — compression_underperformance); fixture milestone + golden-payload diff pattern for compression-disabled regression (T04 — disable-flag-honored)"
drill_down_paths: "[.orchestrator/milestones/M018/phases/P02/tasks/T01-preservation-check-lib-SUMMARY.md](../../../../../milestones/M018/phases/P02/tasks/T01-preservation-check-lib-SUMMARY.md);[.orchestrator/milestones/M018/phases/P02/tasks/T02-knowledge-filter-SUMMARY.md](../../../../../milestones/M018/phases/P02/tasks/T02-knowledge-filter-SUMMARY.md);[.orchestrator/milestones/M018/phases/P02/tasks/T03-underperformance-emitter-SUMMARY.md](../../../../../milestones/M018/phases/P02/tasks/T03-underperformance-emitter-SUMMARY.md);[.orchestrator/milestones/M018/phases/P02/tasks/T04-verifiers-and-summary-SUMMARY.md](../../../../../milestones/M018/phases/P02/tasks/T04-verifiers-and-summary-SUMMARY.md)"
duration: "~6h"
verification_result: pass
observability_surfaces: "execution-log.jsonl: payload_filter record_type, payload_breakdown.filter_dropped_tokens additive field, compression_underperformance record_type, tier_preservation_violation record_type (emitter library shipped, callers wired in P03+)"
completed_at: "2026-04-27T00:00:00Z"
---

# Phase Summary: M018/P02 — Knowledge-Aware Filter + Preservation-Check Library + Underperformance Emitter

## Closure summary

P02 lands the **foundation tier** of the M018 compression pipeline: the knowledge-aware status filter, the reusable preservation-contract self-check library, and the aggregate-savings underperformance emitter. After P02, every dispatch's `## Knowledge` section drops `status: superseded` and `status: experimental` entries before payload assembly. The filter is awk-driven, bash 3.2 compatible, and runs through `scripts/lib/knowledge-filter.sh` from both the planning branch (`build-context.sh _bc_apply_knowledge_filter`) and the task-dispatch branch (`section-handlers.sh _sh_apply_knowledge_filter`).

The phase also ships:

- **Reusable preservation-contract self-check library** (`scripts/lib/preservation-check.sh`) that P03 (tier1), P04 (tier2), and P06 (tier3) source. Three exported functions: `pres_check_section` (regex pattern walker over the cross-tier vocabulary), `pres_emit_violation` (writes `tier_preservation_violation` JSONL), `pres_density_pre_check` (MIT-08 groundwork — refuses tier3 invocation when input density exceeds threshold).
- **Aggregate-savings underperformance signal emitter** (`_bc_emit_compression_underperformance` in `build-context.sh`) — operational signal, never blocks dispatch. Awk-driven running mean over the last N `payload_breakdown` records' filter+tier savings ratio; emits `compression_underperformance` JSONL record when below the SC-9 calibrated 34.7% floor (gated by `min_sample_size` to prevent spurious early-stage emission).
- **MIT-08 density-pre-check API surface** — caller wired in P06.
- **Disable-flag golden-payload regression contract** — `compression.enabled: false` short-circuits the entire filter path; output is byte-identical to the checked-in golden baseline (FR-15 / SC-8 verifiable from now on).

**Dogfood inflection**: P03 onward, every M018 dispatch (and every other orchestrator dispatch in this repo) runs through the knowledge-aware filter. Subsequent M018 task payloads will start carrying live `payload_filter` records once knowledge entries with retired statuses accumulate.

## Risk-mitigation traceability

- **MIT-08 (P02 entry gate from P01 conversus deliberation)** — LLM preservation trust boundary: `pres_density_pre_check` ships in `scripts/lib/preservation-check.sh` (T01). The function exists as an API surface here; P06 plumbs it in front of tier3's LLM call. Density-x100 integer math (no floats — bash 3.2) returns refuse when matches/total_bytes exceeds the configured threshold.
- **MIT-09 (P02 entry gate from P01 conversus deliberation)** — SC-9 threshold operational fragility: `_bc_emit_compression_underperformance` in `scripts/dispatch/build-context.sh` (T03) emits `compression_underperformance` JSONL when running-mean savings falls below the 34.7% floor. Window size, floor pct, min sample size, and enabled flag all config-driven via `compression.underperformance.*`.
- **MIT-10 (P02, THREAT-09 from P01 conversus deliberation)** — preservation-contract self-check algorithmic specification: `pres_check_section` in `scripts/lib/preservation-check.sh` (T01) is the regex-driven pattern walker (one pass per preserved-pattern row from grammar `## Preserved-Pattern Vocabulary`); byte-mismatch on any preserved span triggers passthrough plus `tier_preservation_violation` emission via `pres_emit_violation`.

## Followups for downstream phases

- **P03 (tier1 microcompact)** — sources `scripts/lib/preservation-check.sh` and reuses the cache-prune utility pattern; consumes filter savings via the additive `filter_dropped_tokens` field on `payload_breakdown`. The `payload_breakdown` schema P02 established carries forward unchanged.
- **P04 (tier2 snip)** — same library; the MIT-01 nested-fence regex (`^\`{3,}[a-zA-Z0-9_-]*$`) is load-bearing for P04's head-drop boundary detection.
- **P05 (eval harness)** — reads `compression_underperformance` + `payload_filter` + future `tier_preservation_violation` records from `execution-log.jsonl` per the additive-emitter invariants section of the grammar contract.
- **P06 (tier3 auto-compact)** — wires `pres_density_pre_check` before the LLM call per MIT-08; tier-3-savings field additive on `payload_breakdown`. MIT-08 LLM-preservation enforcement is a P06 unit_close gate, not a P02 gate.

## Verification result

All P02 truths PASS via `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P02/`. All artifacts present, all key links resolve, all six private verifiers green:

- `m018-p02-filter-drops.sh` — PASS (MEM901+MEM903 dropped, MEM900/902/904 retained, fail-open MEM902 honored).
- `m018-p02-emitter-additivity.sh` — PASS (emitter source + live filter_dropped_tokens + pre/post-T02 JSON shape).
- `m018-p02-preservation-check-api.sh` — PASS (3 functions sourceable; selftest green).
- `m018-p02-underperformance-emit.sh` — PASS (running_mean_pct < 34.7 floor; sample_size >= 10).
- `m018-p02-disable-flag-honored.sh` — PASS (override→false reported; baseline byte-identical to fixture; short-circuit guard present in build-context.sh).
- `m018-p02-dual-write-recent.sh` — PASS (M018/P02 named in CLAUDE.md + AGENTS.md recent-changes blocks).

P02 closed. M018 advances to P03.


### P03 Summary
---
schema_version: "1.0"
type: phase-summary
id: P03
parent: M018
milestone: M018
provides: "Tier 1 microcompact live in scripts/dispatch/build-context.sh:_bc_apply_tier1 — paging of inline tool-result blocks above compression.tier1.inline_threshold_tokens (default 1500); SHA-256(command + 0x1F + input)-keyed cache at .orchestrator/cache/tool-results/<sha256>; cache-reuse short-circuits writes (mtime preserved); preview-line reference (`<tool-result file=\"...\" preview-lines=\"5\" command=\"...\" original-body-tokens=\"...\">`) replaces oversized bodies; additive `tier1_savings_tokens` and `tier1_invocations` integer fields on payload_breakdown JSONL emit (CON-5 — pre-T01 records remain valid JSON, missing fields default to 0 in rollups); `tier_preservation_violation` JSONL record (record_type=tier_preservation_violation, tier=tier1) on post-paging pres_check_section failure (P02 library shared with P04/P06); scripts/util/cache-prune.sh --max-age <N>{d|h|m} mtime-based eviction utility (default 7d, idempotent, safe against missing cache dir); compression.tier1.{enabled,inline_threshold_tokens,preview_lines,cache_dir} config keys in .orchestrator/config.yml + templates/orchestrator-config-default.yml; seven P03-private truth verifiers under scripts/verify/m018-p03-*.sh; tests/fixtures/m018-p03-tool-result/ fixture (dispatch-payload-fixture.md + README.md); scripts/verify/_helpers/m018-p03-build-fixture.sh fixture-staging helper; CLAUDE.md/AGENTS.md recent-changes refresh"
requires: "P02 preservation-check library (scripts/lib/preservation-check.sh — pres_check_section + pres_emit_violation); P02 payload_breakdown schema with filter_dropped_tokens additive field; P02 byte-identity golden (tests/fixtures/m018-p02-baseline-payload.golden.txt) for the disable-flag regression contract; P02 _bc_apply_knowledge_filter establishes the awk-driven single-pass pattern Tier 1 mirrors"
affects: "P04 (T2 head-drop sources scripts/lib/preservation-check.sh established by P02 + reuses cache-prune utility for any spillover artifacts; consumes additive `tier1_savings_tokens` field through the rolling underperformance window; MIT-01 4+-backtick-fence regex remains load-bearing for T2 boundary detection); P05 (eval harness reads payload_breakdown.tier1_savings_tokens / .tier1_invocations + tier_preservation_violation records from execution-log.jsonl per the additive-emitter invariants section of the grammar contract); P06 (T3 auto-compact reuses the cache-prune mtime-only utility for tier-3 originals storage; same record-schema invariants — tier_preservation_violation with tier=tier3); P07+ (cache-prune cron / lifecycle wiring inherits the existing single-utility entry point)"
key_files: "scripts/dispatch/build-context.sh;scripts/util/cache-prune.sh;.orchestrator/config.yml;templates/orchestrator-config-default.yml;tests/fixtures/m018-p03-tool-result/dispatch-payload-fixture.md;tests/fixtures/m018-p03-tool-result/README.md;scripts/verify/_helpers/m018-p03-build-fixture.sh;scripts/verify/m018-p03-tier1-paging.sh;scripts/verify/m018-p03-cache-reuse.sh;scripts/verify/m018-p03-emitter-additivity.sh;scripts/verify/m018-p03-cache-prune.sh;scripts/verify/m018-p03-disable-flag-honored.sh;scripts/verify/m018-p03-preservation-self-check.sh;scripts/verify/m018-p03-dual-write-recent.sh"
key_decisions: "Tier 1 awk-driven single-pass paging (AP-009 compliant; mirrors P02 filter shape; single-pipe printf|grep idiom in verifiers, no $(cmd|cmd)); SHA-256(command + 0x1F + input) cache key — full digest, no truncation (collision domain dominated by hash space, not collision probability — keeps cache key small enough that mtime-based prune is correct without reference counting); cache reuse short-circuits writes (`if (getline _t < path) < 0` — open-for-read probe) so mtime is preserved across replays (FR — cache reuse without re-write); preservation self-check restores pre-paging body on failure (cache files written during the failed pass kept on disk for future reuse — they were physically valid bodies, the failure was a delta on the post-paging payload); cache-prune mtime-only (reference-aware preservation deferred — current cache key small enough that mtime is correct; documented as M018 follow-up in cache-prune.sh header); _bc_apply_tier1 inline in build-context.sh (single call site between _bc_emit_payload_breakdown and _bc_emit_compression_underperformance, MEM004 carve-out — no extraction to scripts/lib until a second caller emerges); shim-style verifier (sed/awk-extract _bc_apply_tier1 + source) avoids the brittleness of a full build-context.sh end-to-end probe for paging unit-coverage tests (the end-to-end path is exercised by m018-p03-emitter-additivity.sh + m018-p03-disable-flag-honored.sh)"
patterns_established: "Single-pass awk pagination with cache-write side-effect (T01); shim-style verifier that source-extracts a single bash function via awk range pattern (T03 — usable as P04/P06 verifier pattern when the function under test is too internal to dispatch end-to-end); function-stub pattern for failure-path test coverage (T03 — override pres_check_section to return 1 to exercise the violation/restoration code without depending on regex contents); fixture-staging helper that mirrors P02 helper shape under scripts/verify/_helpers/ (additive — one helper per phase keeps the helper directory legible)"
drill_down_paths: "[.orchestrator/milestones/M018/phases/P03/tasks/T01-tier1-paging-SUMMARY.md](../../../../../milestones/M018/phases/P03/tasks/T01-tier1-paging-SUMMARY.md);[.orchestrator/milestones/M018/phases/P03/tasks/T02-cache-prune-SUMMARY.md](../../../../../milestones/M018/phases/P03/tasks/T02-cache-prune-SUMMARY.md);[.orchestrator/milestones/M018/phases/P03/tasks/T03-verifiers-and-summary-SUMMARY.md](../../../../../milestones/M018/phases/P03/tasks/T03-verifiers-and-summary-SUMMARY.md)"
duration: "~5h"
verification_result: pass
observability_surfaces: "execution-log.jsonl: payload_breakdown.tier1_savings_tokens additive integer field; payload_breakdown.tier1_invocations additive integer field; tier_preservation_violation record_type (tier=tier1 from this phase; same schema reused by P04 with tier=tier2 and P06 with tier=tier3); cache-prune.sh stdout SUMMARY: pruned=N kept=M total=T bytes_freed=B"
completed_at: "2026-04-28T00:00:00Z"
---

# Phase Summary: M018/P03 — Tier 1 Microcompact

## Closure summary

P03 lands the **second tier** of the M018 compression pipeline: Tier 1
microcompact paging of oversized inline tool-result blocks. After P03
closes, every M018 dispatch (and every other orchestrator dispatch in
this repo) runs through the knowledge-aware filter (P02) **and** the
Tier 1 pager — the orchestrator dogfoods its own caveman compression
pipeline starting now.

P03 also ships the first cache-bearing tier — `.orchestrator/cache/tool-results/`
keyed by the full SHA-256 of `command + 0x1F + input`. Cache reuse
short-circuits writes (mtime preserved across replays); cache eviction
is mtime-only via `scripts/util/cache-prune.sh --max-age <duration>`.
P04/T2 head-drop has no cache. P06/T3 auto-compact reuses this same
cache-prune utility for tier-3 originals storage.

The phase ships:

- **Tier 1 paging** (`_bc_apply_tier1` in `scripts/dispatch/build-context.sh`)
  — single awk pass: scan the captured payload, accumulate
  `<tool-result command="...">…</tool-result>` blocks, hash + write
  the cache, replace oversized bodies (> 1500 tokens by default) with
  `<tool-result file="<path>" preview-lines="5" command="..." original-body-tokens="...">`
  + a 5-line preview. Bodies under threshold pass through verbatim.
  Hooked at `build-context.sh` line ~1723 between
  `_bc_emit_payload_breakdown` and `_bc_emit_compression_underperformance`.
- **SHA-256 cache key** — `command + 0x1F + input`. Full 64-hex digest.
  Cache files re-used across dispatches: an open-for-read probe
  (`(getline _t < path) < 0`) tests presence; on hit, the cache write
  is skipped (mtime preserved).
- **Additive emitter fields** (CON-5) — `tier1_savings_tokens` and
  `tier1_invocations` on `_bc_emit_payload_breakdown`'s printf line.
  Stats are captured to `$TMPDIR_BUILD/_tier1_stats.txt` by the awk
  pass and read back by the emitter; missing stats file defaults
  to 0/0 (passthrough case where no paging fired).
- **Preservation self-check integration** — when Tier 1 modifies the
  capture, `pres_check_section "tier1" <pre> <post> tier1` runs over
  the post-paging body. On failure, the pre-paging file is restored
  to `$capture_file` byte-for-byte and `pres_emit_violation` writes a
  `tier_preservation_violation` JSONL record (record_type=`tier_preservation_violation`,
  tier=`tier1`). Cache files written during the failed pass remain on
  disk — they were physically valid bodies; the failure was a delta on
  the post-paging payload bytes, not on the cache contents.
- **`scripts/util/cache-prune.sh --max-age <N>{d|h|m}`** — single-script
  utility, default 7d. Reads `compression.tier1.cache_dir` from
  `.orchestrator/config.yml`; falls back to `.orchestrator/cache/tool-results/`.
  Single-level glob (sub-directories skipped per Constitution VI —
  future tier-3-originals/ co-tenants stay untouched). BSD-vs-GNU stat
  detection. `--dry-run` prints `WOULD-PRUNE:` lines without removal.
  `SUMMARY: pruned=N kept=M total=T bytes_freed=B` line on stdout.
  Idempotent. Malformed `--max-age` exits 1.
- **Config surface** — `compression.tier1.{enabled, inline_threshold_tokens,
  preview_lines, cache_dir}` keys; defaults true / 1500 / 5 /
  `.orchestrator/cache/tool-results/`. Live in `.orchestrator/config.yml`
  + `templates/orchestrator-config-default.yml`.
- **Disable contracts** —
  `compression.enabled: false` (master toggle, FR-15) short-circuits
  the entire pipeline (filter + Tier 1 — byte-identical to pre-M018
  capture against the P02 golden).
  `compression.tier1.enabled: false` short-circuits only Tier 1; the
  knowledge-aware filter still runs.
  `ORCH_OVERRIDE_COMPRESSION_ENABLED=false` env wins over the config
  (test seam, FR-15 SC-8).

## Risk-mitigation traceability

- **MIT-08 (P02 entry gate, P01 conversus deliberation)** — LLM
  preservation trust boundary lives in P06; P03 contributes the
  preservation-check failure-path wiring pattern that P06 will mirror
  with the LLM density-pre-check.
- **MIT-10 (P02, THREAT-09 from P01 conversus deliberation)** —
  preservation-contract self-check algorithmic specification is now
  exercised live: `pres_check_section` runs over every Tier 1 paging
  pass, and the failure-path emits `tier_preservation_violation`
  per the grammar contract.
- **CON-5 (additive emitters)** — `tier1_savings_tokens` /
  `tier1_invocations` are additions to the existing payload_breakdown
  schema; pre-T01 records remain valid JSON; rollups treat absent
  fields as 0. Verified by the historical-log diff in
  `m018-p03-emitter-additivity.sh`.

## Followups for downstream phases

- **P04 (tier2 head-drop)** — sources `scripts/lib/preservation-check.sh`
  (same library; tier=`tier2`); the MIT-01 nested-fence regex
  (`^\`{3,}[a-zA-Z0-9_-]*$`) is load-bearing for P04's head-drop
  boundary detection. T2 has no cache — paging is destructive.
  Reuses `scripts/util/cache-prune.sh` only if any spillover artifacts
  are introduced.
- **P05 (eval harness)** — reads
  `payload_breakdown.tier1_savings_tokens` / `.tier1_invocations`
  from `execution-log.jsonl` for cumulative-savings rollups. Reads
  `tier_preservation_violation` records (tier=`tier1`/`tier2`/`tier3`)
  for trust-boundary diagnostics.
- **P06 (tier3 auto-compact)** — wires `pres_density_pre_check` before
  the LLM call per MIT-08; tier-3-savings field additive on
  `payload_breakdown`; tier-3 originals stored under
  `.orchestrator/cache/tier3-originals/` (sibling, not nested).
  `cache-prune.sh` already-skips sub-directories so tier-3 storage
  needs its own prune pass — recommend `--cache-dir` flag rather than
  hard-coding tier1 vs tier3 in the utility.
- **P07+** — cache-prune cron / lifecycle wiring inherits the existing
  single-utility entry point; recipe-level integration with
  `orchestrator:doctor` is the natural follow-up.

## Verification result

All P03 truths PASS via
`bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P03/`.
All artifacts present at required line counts with required substrings;
all key links resolve; all seven private verifiers green:

- `m018-p03-tier1-paging.sh` — PASS (big block paged, small block
  verbatim, SHA-256 cache file written under fixture cache dir).
- `m018-p03-cache-reuse.sh` — PASS (mtime preserved across two paging
  passes against the same fixture payload).
- `m018-p03-emitter-additivity.sh` — PASS (emitter source carries
  additive fields; live emission carries integer-valued tier1_*
  fields; pre-T01 + post-T01 historical records both valid JSON).
- `m018-p03-cache-prune.sh` — PASS (`--max-age 7d` prunes 30d-old
  file, keeps fresh file, idempotent on second invocation, survives
  missing cache dir).
- `m018-p03-disable-flag-honored.sh` — PASS (P02 golden byte-identical
  to fixture; both `compression.enabled=false` and
  `compression.tier1.enabled=false` short-circuit Tier 1 — empty cache
  dir, tier1_invocations=0).
- `m018-p03-preservation-self-check.sh` — PASS (failure-path
  passthrough holds; `tier_preservation_violation` record emitted with
  tier=`tier1`).
- `m018-p03-dual-write-recent.sh` — PASS (CLAUDE.md + AGENTS.md
  recent-changes blocks both name M018/P03).

P03 closed. M018 advances to P04 (head-drop tier).


### P04 Summary
---
schema_version: "1.0"
type: phase-summary
id: P04
parent: M018
milestone: M018
provides: "Tier 2 snip live in scripts/dispatch/build-context.sh:_bc_apply_tier2 — head-drop of in-scope section bodies (Knowledge, Task Plan, Upstream Context) above compression.tier2.section_budget_tokens (default 1500), preserving compression.tier2.protected_tail_ratio (default 0.3) of pre-snip section bytes byte-identical at the tail; in-band marker `<!-- compressed:tier2 head_dropped=N protected_tail_ratio=R -->` named immediately after the section heading; line-aligned cut with boundary-refusal walker that retreats above multi-line preserved spans (frontmatter `^---$` pairs and `^\\`{3,}[a-zA-Z0-9_-]*$` code-fence pairs by tick-count, MIT-01-aware); pass-through on no-safe-boundary plus a `tier_preservation_violation` JSONL record (tier=tier2, pattern=spanning cross-tier label); preservation self-check via pres_check_section ... tier2 (strict multiplicity); additive integer `tier2_savings_tokens` field on payload_breakdown JSONL emit (CON-5); compression.tier2.{enabled, section_budget_tokens, protected_tail_ratio} config keys in .orchestrator/config.yml + templates/orchestrator-config-default.yml; three new kf_get_tier2_* accessors in scripts/lib/knowledge-filter.sh; seven P04-private truth verifiers under scripts/verify/m018-p04-*.sh; two fixture trees under tests/fixtures/m018-p04-{section-overflow, boundary-refusal}/; scripts/verify/_helpers/m018-p04-build-fixture.sh fixture-staging helper; CLAUDE.md/AGENTS.md recent-changes refresh."
requires: "P03 _bc_apply_tier1 wiring shape (build-context.sh call-site adjacency); P02 preservation-check library (pres_check_section + pres_emit_violation + PRES_PATTERNS_REGEX cross-tier vocabulary including the MIT-01 4+-backtick code-fence regex which is load-bearing for boundary detection); P02 byte-identity golden (tests/fixtures/m018-p02-baseline-payload.golden.txt) for the disable-flag regression contract; P01 references/compression-grammar.md `## Tier: tier2` rules."
affects: "P05 (eval harness reads payload_breakdown.tier2_savings_tokens and tier_preservation_violation records with tier=tier2 from execution-log.jsonl per the additive-emitter invariants section of the grammar contract; P05 cohort segmentation reads tier1_savings_tokens + tier2_savings_tokens + filter_dropped_tokens together for cumulative-savings rollups); P06 (T3 auto-compact runs AGAINST the tier2 output — sees head-dropped-plus-protected-tail bytes, not pre-snip bytes; tier3 must NOT mutate the tier2 in-band marker per the grammar contract; tier3 wraps the marker if the section is summarized further); M027/M019 cost surfaces consume tier2_savings_tokens via the existing payload_breakdown read path; doctor anomaly check baselines compression-regression vs historical post-T2 records."
key_files: "scripts/dispatch/build-context.sh;scripts/lib/knowledge-filter.sh;.orchestrator/config.yml;templates/orchestrator-config-default.yml;tests/fixtures/m018-p04-section-overflow/dispatch-payload-fixture.md;tests/fixtures/m018-p04-section-overflow/README.md;tests/fixtures/m018-p04-boundary-refusal/dispatch-payload-fixture.md;tests/fixtures/m018-p04-boundary-refusal/README.md;scripts/verify/_helpers/m018-p04-build-fixture.sh;scripts/verify/m018-p04-tier2-head-drop.sh;scripts/verify/m018-p04-tier2-marker.sh;scripts/verify/m018-p04-tier2-boundary-refusal.sh;scripts/verify/m018-p04-tier2-emitter-additivity.sh;scripts/verify/m018-p04-tier2-disable-flag.sh;scripts/verify/m018-p04-tier2-preservation-self-check.sh;scripts/verify/m018-p04-dual-write-recent.sh"
key_decisions: "Boundary-refusal walker retreats DOWN from the naive cut line toward line 1 looking for the first line whose at-line-start unsafe flag is 0 (the line that OPENS a span is itself safe — cutting above the opener is correct because everything from the opener onward falls into the protected tail); 4+-backtick fence tracking by tick-count not by line count (3-backtick lines do not close 4-backtick fences — MIT-01); no-safe-boundary refusal passes the section through verbatim plus a tier_preservation_violation JSONL emit (NOT a tier2_preservation_breach — that record is reserved for the protected-tail breach path which the boundary-refusal detector makes unreachable; the grammar contract separates the two record types intentionally); strict-multiplicity tier2 self-check shape (mirrors the tier1 strict-multiplicity branch in pres_check_section); _bc_apply_tier2 inline in build-context.sh (single call site between _bc_apply_tier1 and the cat/emit cluster, MEM004 carve-out — no extraction to scripts/lib until a second caller emerges); tier2 has NO cache (head-drop is destructive on the in-flight payload; canonical files on disk are untouched per Constitution Principle VI; cache-prune utility is reusable but not wired in this phase); fixture-staging helper mirrors P03 shape one-helper-per-phase under scripts/verify/_helpers/; verifiers stub pres_check_section in shim scope to isolate the awk-pass head-drop coverage from the cross-tier vocabulary self-check (the failure-path coverage lives in m018-p04-tier2-preservation-self-check.sh which inverts the stub to return 1)."
patterns_established: "Awk single-pass section-aware head-drop with at-line-start unsafe-flag recording (T01 — usable shape for P05/P06 if their tiers ever need per-line span awareness); function-stub pattern reused from P03/T03 (override pres_check_section to return 0 for happy-path coverage, return 1 for failure-path coverage — same shape, opposite sentinel); dual-fixture pattern (one fixture exercising the happy-path with no preserved-pattern boundaries, one exercising the boundary-refusal walker via MIT-01 4+-backtick fence — reusable for any tier whose safety boundary is the load-bearing claim); fixture-staging helper accepts a slug argument (section-overflow vs boundary-refusal) so a single helper feeds multiple verifiers."
drill_down_paths: "[.orchestrator/milestones/M018/phases/P04/tasks/T01-tier2-head-drop-SUMMARY.md](../../../../../milestones/M018/phases/P04/tasks/T01-tier2-head-drop-SUMMARY.md);[.orchestrator/milestones/M018/phases/P04/tasks/T02-verifiers-and-summary-SUMMARY.md](../../../../../milestones/M018/phases/P04/tasks/T02-verifiers-and-summary-SUMMARY.md)"
duration: "~4h"
verification_result: pass
observability_surfaces: "execution-log.jsonl: payload_breakdown.tier2_savings_tokens additive integer field; tier_preservation_violation record_type (tier=tier2 from this phase; same schema as tier1 from P03 and tier3 from P06); P05 eval harness consumes tier1_savings_tokens + tier2_savings_tokens + filter_dropped_tokens fields together; doctor anomaly-check baselines compression-regression vs historical post-T2 records."
completed_at: "2026-04-28T00:00:00Z"
---

# Phase Summary: M018/P04 — Tier 2 Snip

## Closure summary

P04 lands the **third tier** of the M018 compression pipeline: Tier 2
section head-drop with protected tail. After P04 closes, every M018
dispatch (and every other orchestrator dispatch in this repo) runs
through the knowledge-aware filter (P02), the Tier 1 pager (P03), AND
the Tier 2 snip — the orchestrator dogfoods the full caveman
compression pipeline starting now.

P04 is the **first tier with destructive in-payload mutation** (head-drop
removes head bytes from the in-flight payload). Per Constitution VI,
the canonical files on disk are untouched: only the assembled dispatch
payload is mutated. T2 has no cache (head-drop is in-flight; cache-prune
utility is reusable but not wired here).

The phase ships:

- **Tier 2 head-drop** (`_bc_apply_tier2` in `scripts/dispatch/build-context.sh`)
  — single awk pass: stream the captured payload, buffer each in-scope
  section's body (`## Knowledge`, `## Task Plan`, `## Upstream Context`),
  track multi-line preserved spans line-by-line so each buffered line
  carries an at-line-start `body_unsafe[i]` flag. At section close, if
  body-tokens > `compression.tier2.section_budget_tokens` (default
  1500), compute naive cut at `floor(body_chars * (1 - protected_tail_ratio))`,
  retreat DOWN from the naive cut line toward line 1 until the walker
  finds a line with `body_unsafe[i] = 0` (the opener of a span is
  itself safe — cuts BELOW the opener fall inside the span and are
  unsafe), then emit `## <Section>\n<!-- compressed:tier2 ... -->\n<tail>`.
  Hooked at `build-context.sh` line ~2023 between `_bc_apply_tier1` and
  the cat/emit cluster.
- **MIT-01 nested-fence regex** — the awk pass tracks fences by
  TICK COUNT, not by line. A 4-backtick fence opens at tick-count 4;
  3-backtick lines inside it do NOT close it. Only a matching-tick-count
  closer ends the fence. This is the load-bearing MIT-01 fix, exercised
  live by the `m018-p04-tier2-boundary-refusal.sh` verifier against the
  `tests/fixtures/m018-p04-boundary-refusal/` fixture.
- **In-band tier2 marker** — `<!-- compressed:tier2 head_dropped=<N>
  protected_tail_ratio=<R> -->` emitted on its own line directly after
  the `## <Section>` heading. Marker matches the cross-tier
  `<!-- compressed:tier[0-9]+ [^>]*-->` vocabulary entry verbatim;
  downstream Tier 3 (P06) wraps but MUST NOT mutate the kvpairs.
- **Boundary-refusal passthrough** — when no safe boundary exists at
  or above the naive cut byte (the section is dominated by an
  unsplittable preserved span), the section passes through unmodified
  AND the awk pass appends a record to `$TMPDIR_BUILD/_tier2_violations.txt`
  which the bash caller reads and dispatches via `pres_emit_violation`
  with `tier=tier2`, `pattern=<spanning vocabulary label>`. Distinct
  from `tier2_preservation_breach`, which the grammar reserves for the
  protected-tail breach path that the boundary-refusal walker makes
  unreachable.
- **Preservation self-check** — `pres_check_section "tier2" $pre_file
  $out_file tier2` runs over the rewritten payload after head-drop
  succeeds. On failure, the pre-snip payload is restored byte-identical
  via `cp "$pre_file" "$capture_file"` and `pres_emit_violation` writes
  `tier_preservation_violation` (tier=`tier2`). The verifier
  `m018-p04-tier2-preservation-self-check.sh` exercises this path via
  the function-stub pattern (override `pres_check_section` to return 1).
- **Additive emitter field** (CON-5) — `tier2_savings_tokens` on
  `_bc_emit_payload_breakdown`'s printf line. Stats captured to
  `$TMPDIR_BUILD/_tier2_stats.txt` by the awk pass and read back by
  the emitter; missing stats file defaults to 0 (passthrough case where
  no head-drop fired, including all sections under budget).
- **Config surface** — `compression.tier2.{enabled,
  section_budget_tokens, protected_tail_ratio}` keys; defaults true /
  1500 / 0.3. Live in `.orchestrator/config.yml` +
  `templates/orchestrator-config-default.yml`. Three new
  `kf_get_tier2_*` accessors in `scripts/lib/knowledge-filter.sh`
  mirror the `kf_get_tier1_*` shape and reuse `kf_read_compression_scalar`.
- **Disable contracts** —
  `compression.enabled: false` (master toggle, FR-15) short-circuits
  the entire pipeline (filter + Tier 1 + Tier 2 — byte-identical to
  pre-M018 capture against the P02 golden).
  `compression.tier2.enabled: false` short-circuits only Tier 2; the
  knowledge-aware filter and Tier 1 pager still run.
  `ORCH_OVERRIDE_COMPRESSION_ENABLED=false` env wins over the config.

## Risk-mitigation traceability

- **MIT-01 (P01 conversus deliberation, 4+-backtick fence regex)** —
  the boundary-refusal walker tracks fences by tick count, not by
  line count. A 3-backtick line nested inside a 4-backtick fence is
  fence content, not a closer. The `m018-p04-tier2-boundary-refusal.sh`
  verifier exercises this live — its fixture wraps a 3-backtick
  "nested" fence inside a 4-backtick outer fence and asserts the
  inner 3-backtick line survives unaltered through the snip.
- **MIT-08 (P02 entry gate, P01 conversus deliberation)** — LLM
  preservation trust boundary lives in P06; P04 contributes the
  body-level head-drop pattern that P06 will mirror with the LLM
  density pre-check + summary call.
- **MIT-10 (P02, THREAT-09)** — preservation-contract self-check
  algorithmic specification continues to be exercised live through
  Tier 2: `pres_check_section "tier2"` runs after every successful
  head-drop, and the failure-path emits `tier_preservation_violation`
  per the grammar contract.
- **CON-5 (additive emitters)** — `tier2_savings_tokens` is an
  addition to the existing payload_breakdown schema. Pre-T2 records
  remain valid JSON; rollups treat absent fields as 0. Verified by
  the historical-log diff in `m018-p04-tier2-emitter-additivity.sh`.

## Followups for downstream phases

- **P05 (eval harness)** — reads `payload_breakdown.tier2_savings_tokens`
  alongside `tier1_savings_tokens` + `filter_dropped_tokens` from
  `execution-log.jsonl` for cumulative-savings cohort segmentation.
  Reads `tier_preservation_violation` records (tier=`tier1`/`tier2`/
  `tier3`) for trust-boundary diagnostics. P05 cohort segmentation
  is now able to see the third tier's contribution and report
  outcome-rate deltas at the per-tier level.
- **P06 (tier3 auto-compact)** — sees post-tier-2 bytes (head-dropped
  + protected tail), not pre-snip bytes. Tier3 wraps but does NOT
  mutate the in-band tier2 marker per grammar. `pres_density_pre_check`
  runs in front of the LLM call per MIT-08; `tier3_savings_tokens`
  field is additive on `payload_breakdown`; tier-3 originals stored
  under `.orchestrator/cache/tier3-originals/` (sibling to
  `.orchestrator/cache/tool-results/`, not nested).
- **P07+** — doctor anomaly check baselines compression-regression
  vs historical post-T2 records; cost surfaces (M027/M019) consume
  `tier2_savings_tokens` via the existing payload_breakdown read
  path with no surface changes required.

## Verification result

All P04 truths PASS via
`bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P04/`.
All artifacts present at required line counts with required substrings;
all key links resolve; all seven private verifiers green:

- `m018-p04-tier2-head-drop.sh` — PASS (heading preserved; tier2
  marker emitted with positive head_dropped; protected tail bytes
  intact at end of section).
- `m018-p04-tier2-marker.sh` — PASS (single tier2 marker line;
  immediately after `## Knowledge` heading; matches cross-tier
  compression-marker regex; carries integer head_dropped + literal
  protected_tail_ratio=0.30).
- `m018-p04-tier2-boundary-refusal.sh` — PASS (retreat path; walker
  retreated above 4-backtick fence opener; head_dropped reflects
  only pre-fence prose; fence opener+closer preserved; MIT-01 nested
  3-backtick line intact through the snip).
- `m018-p04-tier2-emitter-additivity.sh` — PASS (emitter source
  carries additive `tier2_savings_tokens` field; live emission
  carries integer-valued field; pre-T2 + post-T2 historical records
  both valid JSON; pre-existing tier1 + filter fields still present).
- `m018-p04-tier2-disable-flag.sh` — PASS (P02 golden byte-identical
  to fixture; `tier2.enabled=false` leaves no tier2 marker and
  reports `tier2_savings_tokens=0`; `compression.enabled=false`
  short-circuits the entire pipeline — no compression markers of
  any tier in output).
- `m018-p04-tier2-preservation-self-check.sh` — PASS (failure-path
  passthrough holds; `tier_preservation_violation` record emitted
  with tier=`tier2`).
- `m018-p04-dual-write-recent.sh` — PASS (CLAUDE.md + AGENTS.md
  recent-changes blocks both name M018/P04).

P04 closed. M018 advances to P05 (eval harness).

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P05"
milestone: "M018"
name: "scripts/diagnostics/compression-eval.sh — sourceable + CLI cohort segmentation diagnostic that reports outcome-rate deltas (verification_pass_rate, retry_count, deviation_count) between compressed and uncompressed cohorts with confidence intervals; --tier <N> filter; below-floor sample emits 'insufficient sample' and exits 0"
depends_on: ["T01"]
---

## Prerequisites

- T01 has shipped the four additive savings fields on `unit_close` JSONL records (`filter_dropped_tokens`, `tier1_savings_tokens`, `tier2_savings_tokens`, `tier1_invocations`). T03's cohort segmentation reads these fields plus the existing `verification_pass_rate`, `retry_count`, `deviation_count` fields from `unit_close` records.
- T03 also reads `payload_breakdown` records to identify which units' dispatches actually fired the requested tier — the savings field on `unit_close` rolls up across the whole unit; the `payload_breakdown` record is the per-dispatch ground truth.
- The execution-log.jsonl path resolution mirrors the existing `metrics-rollup.sh` path: under a milestone directory, `<milestone-dir>/execution-log.jsonl`. T03 uses `scripts/state/find-active-milestone.sh` to resolve the active milestone when `--milestone` is omitted.
- The "compressed" vs "uncompressed" cohort definition for tier N (where N is 1 or 2 in P05; tier 3 is reserved for P06):
  - **Compressed cohort**: `unit_close` records where the matching scope's aggregated `payload_breakdown` records carry `tier<N>_savings_tokens > 0`.
  - **Uncompressed cohort**: `unit_close` records on the same milestone where the same scope's aggregated `payload_breakdown` records carry `tier<N>_savings_tokens == 0` OR the field is absent.
  The cohort match is on (milestone, phase, task) for task-granularity unit_close records; phase-granularity and milestone-granularity records are excluded from the cohort split (they are aggregations, not per-task observations).
- The outcome-rate metrics:
  - `verification_pass_rate` (real number 0.0–1.0 or `"unknown"`; treat unknown as missing and exclude from the cohort metric)
  - `retry_count` (non-negative integer)
  - `deviation_count` (non-negative integer)
- The confidence interval method:
  - For `verification_pass_rate` (a proportion): Wilson 95% CI per cohort; cohort delta CI via the standard normal-approximation pooled formula.
  - For `retry_count` / `deviation_count` (count metrics, possibly heavy-tailed): per-cohort mean + standard error of the mean (SEM); cohort delta CI via the t-test approximation.
  Implemented in awk (no python, no jq) using closed-form arithmetic. Bash 3.2 — no associative arrays in the awk pass beyond the standard awk indexed maps.
- Sample-size floor: default 30 per cohort (`--sample-floor 30`). When either cohort is below the floor, emit `"insufficient sample (compressed=N1 uncompressed=N2 floor=F)"` and exit 0 — no noisy false-positives.
- AP-009 + AD-19: `compression-eval.sh` IS a Check: command target (T04 wires it up). The CLI script's own body uses MEM004 carve-out for awk + pipes; T04's verifier `m018-p05-compression-eval.sh` invokes it as a single-script-file `Check:`. The script CLI itself MAY use compound chains internally per the existing `metrics-rollup.sh` precedent; T04's `m018-p05-compression-eval-shape.sh` verifier asserts compliance with the documented shape rules.
- Bash 3.2 — no `declare -A`, no process substitution, no merged stdout-stderr shorthand.

## Description

Ship a new sourceable + CLI diagnostic at `scripts/diagnostics/compression-eval.sh`. The diagnostic answers the question "did the dispatches that fired tier N produce different outcomes than the dispatches on the same milestone that did not fire tier N?" by segmenting `unit_close` records into compressed vs uncompressed cohorts and reporting the per-cohort + delta means with confidence intervals.

After T03:

1. `bash scripts/diagnostics/compression-eval.sh --milestone M018 --tier 1` against a fixture log with mixed compressed + uncompressed dispatches reports:

   ```
   # compression-eval — milestone=M018 tier=1
   COHORT       N    PASS_RATE         RETRY_COUNT       DEVIATION_COUNT
   compressed   42   0.952 [0.84,0.99]  0.43 ± 0.12       0.07 ± 0.04
   uncompressed 48   0.917 [0.80,0.97]  0.52 ± 0.14       0.10 ± 0.05
   delta              +0.035 [-0.06,+0.13]  -0.09 [-0.27,+0.09]  -0.03 [-0.10,+0.04]
   regression_flag: none
   ```

2. `bash scripts/diagnostics/compression-eval.sh --milestone M018 --tier 1 --sample-floor 100` against the same log emits:

   ```
   # compression-eval — milestone=M018 tier=1
   insufficient sample (compressed=42 uncompressed=48 floor=100)
   ```

   Exit 0.

3. `bash scripts/diagnostics/compression-eval.sh --milestone <id> --tier 3` (P05 era) emits a one-line "tier 3 reserved for P06; not yet supported" advisory and exits 0. T03 ships the `--tier 3` path as a recognized-but-no-op stub so the CLI surface is stable for P06.

4. The diagnostic is sourceable: `source scripts/diagnostics/compression-eval.sh` and call `compression_eval_render <milestone> <tier> <sample_floor>`. The function returns 0 always; degraded inputs surface as text on stdout.

5. The diagnostic emits zero JSONL records (FR-12 read-only).
6. Token cost: zero (bash + awk + grep only — FR-21).

T03 ships ONLY:

- `scripts/diagnostics/compression-eval.sh` — the new diagnostic.

T03 does NOT ship:

- Verifiers, fixtures, fixture-staging helper, P05-SUMMARY, dual-write (T04).
- T01's emitter extensions or T02's surface extensions.

## Inputs

- `scripts/dispatch/build-context.sh:_bc_emit_payload_breakdown` — read for the JSONL field shape so T03's cohort detector extracts the right fields. Field names: `record_type`, `unitId`, `milestone`, `phase`, `task`, `tier1_savings_tokens`, `tier2_savings_tokens`, `tier1_invocations`, `filter_dropped_tokens`. (Tier 3 fields land in P06.)
- `scripts/knowledge/write-summary.sh:_ws_emit_unit_close` — read for the unit_close JSONL field shape after T01: `record_type`, `granularity`, `unitId`, `milestone`, `phase`, `task`, `verification_pass_rate`, `deviation_count`, `retry_count`, plus the four T01-additive savings fields.
- `scripts/diagnostics/metrics-rollup.sh` — read for shape conventions: header at top, sourceable guard, project-root resolution, MEM004 carve-out comments, CLI argv parser. T03 mirrors the same structural skeleton.
- `scripts/diagnostics/efficiency-footer.sh` and `check-anomalies.sh` — same shape skeleton.
- `scripts/state/find-active-milestone.sh` — resolves the active milestone for the no-`--milestone` case.

## Steps

### Step 1 — Author the script header + sourceable guard

```bash
#!/usr/bin/env bash
# scripts/diagnostics/compression-eval.sh — M018/P05/T03 cohort-segmentation
# diagnostic for the M018 compression pipeline.
#
# Sourceable as a library (function compression_eval_render) AND runnable
# as a CLI. Reads payload_breakdown + unit_close records from a milestone's
# execution-log.jsonl, segments compressed vs uncompressed cohorts on the
# requested tier, and reports per-cohort + delta means for verification_
# pass_rate, retry_count, and deviation_count with confidence intervals.
#
# Read-only (FR-12 / CON-1): never appends to or rewrites JSONL.
# Zero-LLM-token (FR-21 / CON-6): bash + awk + grep only.
# Bash 3.2 (CON-7): parallel scalars, no associative arrays beyond awk
#   indexed maps, no process substitution, no merged stdout-stderr.
# MEM004 emitter-internal carve-out: pipes / $() / awk permitted inside
# this diagnostic body; the AD-19 single-script-file shape rule applies
# only to Check: commands at task / phase plan level (T04 wires this
# script as a single Check: invocation per truth).
#
# Usage:
#   bash scripts/diagnostics/compression-eval.sh --milestone <Mxxx> --tier <N> [--sample-floor <N>]
#   --milestone <Mxxx>     Required (or auto-resolved via find-active-milestone.sh).
#   --tier <N>             Required. 1 or 2 in P05; 3 emits an advisory stub for P06.
#   --sample-floor <N>     Default 30. Both cohorts must be at or above the floor.
#   --help / -h
#
# Exit codes: always 0 (FR-12 / CON-5 — degraded inputs surface as text).

set -u

if [ -n "${_COMPRESSION_EVAL_SH_SOURCED:-}" ]; then
  return 0 2>/dev/null || true
fi
_COMPRESSION_EVAL_SH_SOURCED=1

_CE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_CE_PROJECT_ROOT="$(cd "$_CE_SCRIPT_DIR/../.." && pwd)"
```

### Step 2 — Author `compression_eval_render`

The render function takes three arguments: `<milestone>`, `<tier>`, `<sample_floor>`. Body:

```bash
# compression_eval_render <milestone> <tier> <sample-floor>
# Always returns 0. Emits the report on stdout.
compression_eval_render() {
  local milestone="$1"
  local tier="$2"
  local floor="$3"

  printf '# compression-eval — milestone=%s tier=%s\n' "$milestone" "$tier"

  if [ -z "$milestone" ]; then
    printf 'no milestone resolved (pass --milestone <Mxxx> or run inside an active milestone)\n'
    return 0
  fi

  case "$tier" in
    1|2) ;;
    3)
      printf 'tier 3 reserved for P06; not yet supported\n'
      return 0
      ;;
    *)
      printf 'unsupported tier=%s (must be 1, 2, or 3)\n' "$tier"
      return 0
      ;;
  esac

  local log_file="$_CE_PROJECT_ROOT/.orchestrator/milestones/$milestone/execution-log.jsonl"
  if [ ! -f "$log_file" ]; then
    printf 'log file missing: %s\n' "$log_file"
    return 0
  fi

  # The cohort-build awk pass:
  #   1. Walk the log; for every payload_breakdown record, record whether
  #      tier<N>_savings_tokens > 0 keyed on (milestone, phase, task).
  #   2. Walk the log again; for every unit_close record at granularity=task,
  #      emit (cohort, pass_rate, retry_count, deviation_count) keyed on the
  #      same (milestone, phase, task).
  # Two passes via awk -f / piped invocation — single command, single stdin.
  # Compute per-cohort mean + variance + n. Emit cohort + delta block with CIs.
  # Below-floor: emit "insufficient sample" and exit.

  local awk_out
  awk_out="$(awk -v tier="$tier" -v floor="$floor" '
    function tonum(x) { return (x == "" || x == "null") ? 0 : x + 0 }
    function field_num(line, key,    re, m, v) {
      re = "\"" key "\":[0-9]+"
      if (match(line, re)) {
        v = substr(line, RSTART, RLENGTH); sub(/.*:/, "", v); return v + 0
      }
      return 0
    }
    function field_str(line, key,    re, m, v) {
      re = "\"" key "\":\"[^\"]*\""
      if (match(line, re)) {
        v = substr(line, RSTART, RLENGTH); sub(/^"[^"]*":"/, "", v); sub(/"$/, "", v); return v
      }
      return ""
    }
    function field_real(line, key,    re, m, v) {
      re = "\"" key "\":(-?[0-9]+(\\.[0-9]+)?)"
      if (match(line, re)) {
        v = substr(line, RSTART, RLENGTH); sub(/.*:/, "", v); return v + 0
      }
      return -1.0
    }
    /"record_type":"payload_breakdown"/ {
      m = field_str($0, "milestone")
      p = field_str($0, "phase")
      t = field_str($0, "task")
      key = m "/" p "/" t
      if (tier == "1") {
        v = field_num($0, "tier1_savings_tokens")
      } else {
        v = field_num($0, "tier2_savings_tokens")
      }
      if (v > 0) tier_fired[key] = 1
      else if (!(key in tier_fired)) tier_fired[key] = 0
    }
    /"record_type":"unit_close"/ {
      g = field_str($0, "granularity")
      if (g != "task") next
      m = field_str($0, "milestone")
      p = field_str($0, "phase")
      t = field_str($0, "task")
      key = m "/" p "/" t
      pr = field_real($0, "verification_pass_rate")
      rt = field_num($0, "retry_count")
      dv = field_num($0, "deviation_count")
      cohort = (key in tier_fired && tier_fired[key] == 1) ? "compressed" : "uncompressed"
      n[cohort]++
      if (pr >= 0) {
        # Pass rate is a proportion in [0,1]; treat -1 as "unknown" and skip.
        pr_sum[cohort] += pr; pr_n[cohort]++
        pr_sumsq[cohort] += pr * pr
      }
      rt_sum[cohort] += rt; rt_sumsq[cohort] += rt * rt
      dv_sum[cohort] += dv; dv_sumsq[cohort] += dv * dv
    }
    END {
      nc = n["compressed"] + 0
      nu = n["uncompressed"] + 0
      if (nc < floor || nu < floor) {
        printf "insufficient sample (compressed=%d uncompressed=%d floor=%d)\n", nc, nu, floor
        exit
      }
      # Per-cohort means.
      for (c in n) {
        pr_mean[c] = (pr_n[c] > 0) ? pr_sum[c] / pr_n[c] : -1
        rt_mean[c] = rt_sum[c] / n[c]
        dv_mean[c] = dv_sum[c] / n[c]
        # Variance for retry / deviation (population variance is fine for the SEM).
        rt_var[c]  = rt_sumsq[c] / n[c] - rt_mean[c] * rt_mean[c]
        dv_var[c]  = dv_sumsq[c] / n[c] - dv_mean[c] * dv_mean[c]
        if (rt_var[c] < 0) rt_var[c] = 0
        if (dv_var[c] < 0) dv_var[c] = 0
      }
      # Wilson 95% CI for pass-rate proportion.
      function wilson_lo(p, nn,    z, denom, center, half) {
        if (nn <= 0 || p < 0) return -1
        z = 1.96; denom = 1 + z*z/nn
        center = (p + z*z/(2*nn)) / denom
        half = (z/denom) * sqrt(p*(1-p)/nn + z*z/(4*nn*nn))
        v = center - half; if (v < 0) v = 0
        return v
      }
      function wilson_hi(p, nn,    z, denom, center, half) {
        if (nn <= 0 || p < 0) return -1
        z = 1.96; denom = 1 + z*z/nn
        center = (p + z*z/(2*nn)) / denom
        half = (z/denom) * sqrt(p*(1-p)/nn + z*z/(4*nn*nn))
        v = center + half; if (v > 1) v = 1
        return v
      }
      printf "COHORT       N    PASS_RATE              RETRY_COUNT        DEVIATION_COUNT\n"
      for (i = 0; i < 2; i++) {
        c = (i == 0) ? "compressed" : "uncompressed"
        if (pr_n[c] > 0 && pr_mean[c] >= 0) {
          pr_lo = wilson_lo(pr_mean[c], pr_n[c]); pr_hi = wilson_hi(pr_mean[c], pr_n[c])
          pr_str = sprintf("%.3f [%.2f,%.2f]", pr_mean[c], pr_lo, pr_hi)
        } else {
          pr_str = "unknown"
        }
        rt_sem = (n[c] > 1) ? sqrt(rt_var[c] / n[c]) : 0
        dv_sem = (n[c] > 1) ? sqrt(dv_var[c] / n[c]) : 0
        printf "%-12s %-4d %-22s %.2f +/- %.2f      %.2f +/- %.2f\n", \
          c, n[c], pr_str, rt_mean[c], rt_sem, dv_mean[c], dv_sem
      }
      # Delta block.
      delta_pr = (pr_mean["compressed"] >= 0 && pr_mean["uncompressed"] >= 0) \
        ? pr_mean["compressed"] - pr_mean["uncompressed"] : -99
      delta_rt = rt_mean["compressed"] - rt_mean["uncompressed"]
      delta_dv = dv_mean["compressed"] - dv_mean["uncompressed"]
      # Pooled SE for proportion delta (normal approx).
      if (delta_pr > -50) {
        pp = (pr_sum["compressed"] + pr_sum["uncompressed"]) / (pr_n["compressed"] + pr_n["uncompressed"])
        se_pr = sqrt(pp * (1 - pp) * (1.0/pr_n["compressed"] + 1.0/pr_n["uncompressed"]))
        z95 = 1.96
        pr_d_lo = delta_pr - z95 * se_pr; pr_d_hi = delta_pr + z95 * se_pr
        delta_pr_str = sprintf("%+.3f [%+.2f,%+.2f]", delta_pr, pr_d_lo, pr_d_hi)
      } else {
        delta_pr_str = "unknown"
      }
      se_rt = sqrt(rt_var["compressed"]/n["compressed"] + rt_var["uncompressed"]/n["uncompressed"])
      se_dv = sqrt(dv_var["compressed"]/n["compressed"] + dv_var["uncompressed"]/n["uncompressed"])
      delta_rt_str = sprintf("%+.2f [%+.2f,%+.2f]", delta_rt, delta_rt - 1.96*se_rt, delta_rt + 1.96*se_rt)
      delta_dv_str = sprintf("%+.2f [%+.2f,%+.2f]", delta_dv, delta_dv - 1.96*se_dv, delta_dv + 1.96*se_dv)
      printf "delta              %s  %s  %s\n", delta_pr_str, delta_rt_str, delta_dv_str
      # Regression flag (advisory): pass-rate delta < -0.05 AND CI does not cross 0.
      if (delta_pr > -50 && delta_pr <= -0.05 && pr_d_hi < 0) {
        printf "regression_flag: pass-rate regression (delta=%.3f CI excludes 0)\n", delta_pr
      } else {
        printf "regression_flag: none\n"
      }
    }
  ' "$log_file" 2>/dev/null || true)"

  if [ -z "$awk_out" ]; then
    printf 'no records to evaluate\n'
    return 0
  fi
  printf '%s\n' "$awk_out"
  return 0
}
```

### Step 3 — Author the CLI block

```bash
# CLI entry point — only when invoked as a script (not sourced).
if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
  MILESTONE=""
  TIER=""
  FLOOR_OVERRIDE=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --milestone)     MILESTONE="$2"; shift 2 ;;
      --tier)          TIER="$2"; shift 2 ;;
      --sample-floor)  FLOOR_OVERRIDE="$2"; shift 2 ;;
      --help|-h)
        printf '%s\n' "Usage: compression-eval.sh --milestone <Mxxx> --tier <N> [--sample-floor <N>]"
        printf '%s\n' "  --milestone <Mxxx>     Required (or auto-resolved)."
        printf '%s\n' "  --tier <N>             Required. 1 or 2 in P05; 3 reserved for P06."
        printf '%s\n' "  --sample-floor <N>     Default 30."
        printf '%s\n' "  --help, -h             Show this help and exit 0."
        exit 0 ;;
      *) shift ;;
    esac
  done

  if [ -z "$MILESTONE" ]; then
    if [ -x "$_CE_PROJECT_ROOT/scripts/state/find-active-milestone.sh" ]; then
      _ce_active="$(bash "$_CE_PROJECT_ROOT/scripts/state/find-active-milestone.sh" "$_CE_PROJECT_ROOT/.orchestrator" 2>/dev/null || true)"
      MILESTONE="$(printf '%s\n' "$_ce_active" | awk 'NR==1 { print $1 }')"
    fi
  fi

  if [ -z "$TIER" ]; then
    printf '%s\n' "compression-eval: --tier <N> is required" >&2
    exit 0   # FR-12 / CON-5 — never abort.
  fi

  FLOOR="$FLOOR_OVERRIDE"
  if [ -z "$FLOOR" ]; then FLOOR="30"; fi

  compression_eval_render "$MILESTONE" "$TIER" "$FLOOR"
  exit 0
fi
```

### Step 4 — Make the script executable

`chmod +x scripts/diagnostics/compression-eval.sh` so the verifier can invoke it as a single bash script. (The phase-close verifier `m018-p05-compression-eval.sh` will assert this.)

### Step 5 — Self-test during development

Run `bash scripts/diagnostics/compression-eval.sh --help` and confirm the usage block. Run against the active M018 log (which already has tier1 + tier2 records by P05): `bash scripts/diagnostics/compression-eval.sh --milestone M018 --tier 1 --sample-floor 5`. Expect a small-sample report or "insufficient sample" depending on actual log volume.

## Verification

T03 produces no verifier scripts (those are T04). T03's production code is exercised by:

- `m018-p05-compression-eval.sh` (T04) — exercises the cohort segmentation + outcome-rate delta against a fixture log.
- `m018-p05-compression-eval-shape.sh` (T04) — asserts the script is sourceable AND CLI-runnable, has the AP-009/AD-19 carve-out comments, exits 0 in all paths, emits zero JSONL, and zero LLM tokens.

## Must-Haves (subset addressed by this task)

- **Truth #6**: compression-eval cohort segmentation. Wholly addressed by Steps 1–4.
- **Truth #7**: compression-eval shape contract. Wholly addressed by Steps 1, 4 (sourceable guard, CLI duality, MEM004 carve-out doc-comment, executable bit).

T03 does not address Truths #1–#5 (T01, T02) or #8 (T04).

## Notes

- The Wilson 95% CI for proportions is the textbook formula; closed-form, no iteration; bash-3.2-friendly via awk arithmetic.
- The pooled SE for proportion deltas uses the normal approximation; this is acceptable for the "advisory" flag at the n>=30/n>=30 boundary. Below the floor, the diagnostic refuses to flag — it emits "insufficient sample" instead.
- `delta_pr <= -0.05 AND CI excludes 0` is the advisory regression threshold (5pp pass-rate drop with statistical confidence). T03 surfaces this as a one-line `regression_flag:` field; T02's doctor anomaly extension flags compression-regression at the savings-ratio level (not the outcome-rate level — that's T03's job exclusively).
- Tier 3 stub: emits "tier 3 reserved for P06; not yet supported" and exits 0. P06 will replace the stub with the same cohort logic against `tier3_savings_tokens` / `tier3_invocations`.
- The script explicitly does not invoke `metrics-rollup.sh` — T03 walks the JSONL directly to maintain the field-extraction granularity needed for the cohort split. This is the same pattern `check-anomalies.sh` uses (delegation to the rollup engine for table data + secondary awk pass for per-row analysis).
- AGENTS.md / CLAUDE.md `orchestrator:recent-changes` dual-write is T04, not T03.
- Bash 3.2: parallel scalars (`MILESTONE`, `TIER`, `FLOOR_OVERRIDE`); awk inside the helper (MEM004 carve-out); no `declare -A`; no process substitution; no merged stdout-stderr.

## State Context

- **Current State**: executing
- **Milestone**: M018
- **Phase**: P05
- **Task**: T03-compression-eval
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints


### Acceptance Criteria


### Files To Touch

- `scripts/dispatch/dispatch-interface.sh` (modify) — add the four additive integer fields to both branches of `_di_emit_dispatch_usage`'s printf (happy-path + degraded-path); add an internal helper `_di_rollup_savings_fields` (MEM004 carve-out — pipes/awk permitted) that reads the same-unitId `payload_breakdown` records from the resolved log file and emits the four integers.
- `scripts/knowledge/write-summary.sh` (modify) — add the four additive integer fields to the `_ws_emit_unit_close` printf; add an internal helper `_ws_rollup_savings_fields` that reads the per-task `payload_breakdown` records on the unit_close scope from `execution-log.jsonl` and emits the four integers.
- `scripts/diagnostics/metrics-rollup.sh` (modify) — extend the per-bucket aggregation in the awk pass to track the four savings fields on `payload_breakdown` (with the same source-precedence rule); extend the render to emit the new columns / a "Compression savings" sub-block.
- `scripts/diagnostics/efficiency-footer.sh` (modify) — append the one-line "Compressed: <pct>% reduction over baseline" tail when the rollup reports non-zero savings; honor `--quiet` and the `compression.efficiency_footer.enabled` config knob (FR-15 carry-forward).
- `scripts/diagnostics/check-anomalies.sh` (modify) — add a `compression-regression` reason in the awk pass when the milestone's savings ratio (sum savings / sum payload_tokens) falls below the SC-9 calibrated 34.7% floor against the milestone's prior baseline; respect the existing suppression matrix.
- `scripts/diagnostics/compression-eval.sh` (create) — new sourceable + CLI diagnostic.
- `tests/fixtures/m018-p05-savings-log/execution-log.jsonl` (create) — fixture with mixed compressed + uncompressed records covering tier1, tier2, and a savings-bearing dispatch_usage / unit_close pair.
- `tests/fixtures/m018-p05-savings-log/README.md` (create) — fixture description.
- `tests/fixtures/m018-p05-no-savings-log/execution-log.jsonl` (create) — fixture with payload_breakdown records carrying zero / absent savings fields, used to assert the footer/doctor surfaces stay quiet.
- `tests/fixtures/m018-p05-no-savings-log/README.md` (create) — fixture description.
- `scripts/verify/_helpers/m018-p05-build-fixture.sh` (create) — fixture-staging helper mirroring P03 / P04.
- `scripts/verify/m018-p05-dispatch-usage-additivity.sh` (create)
- `scripts/verify/m018-p05-unit-close-additivity.sh` (create)
- `scripts/verify/m018-p05-cost-rollup-savings-columns.sh` (create)
- `scripts/verify/m018-p05-efficiency-footer-compression.sh` (create)
- `scripts/verify/m018-p05-doctor-compression-regression.sh` (create)
- `scripts/verify/m018-p05-compression-eval.sh` (create)
- `scripts/verify/m018-p05-compression-eval-shape.sh` (create)
- `scripts/verify/m018-p05-dual-write-recent.sh` (create)
- [`.orchestrator/milestones/M018/phases/P05/P05-SUMMARY.md`](../../../../../milestones/M018/phases/P05/P05-SUMMARY.md) (create) — written via `bash scripts/knowledge/write-summary.sh`.
- `CLAUDE.md` (modify) — refresh `orchestrator:recent-changes` block to name M018/P05.
- `AGENTS.md` (modify) — same content (dual-write via `scripts/util/dual-write-runtime-md.sh`).

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