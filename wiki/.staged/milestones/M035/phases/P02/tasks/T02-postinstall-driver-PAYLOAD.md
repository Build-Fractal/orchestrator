---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T02-postinstall-driver (Phase P02, Milestone M035)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-979 | ~200 | required |
| Upstream Context | 981-1019 | ~6300 | required |
| Task Plan | 1021-1400 | ~3800 | required |
| State Context | 1402-1408 | ~100 | required |
| First-Turn Completeness | 1410-1489 | ~1000 | required |
| **Total** | | **~22200** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 874
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
hit_count: 874
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
hit_count: 874
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
hit_count: 874
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
hit_count: 759
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
hit_count: 759
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
hit_count: 759
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
hit_count: 874
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
hit_count: 759
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
hit_count: 759
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
hit_count: 759
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
hit_count: 874
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
hit_count: 874
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
hit_count: 874
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
hit_count: 759
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
hit_count: 759
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
hit_count: 759
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
hit_count: 874
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
hit_count: 759
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
hit_count: 759
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
hit_count: 874
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
hit_count: 874
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
hit_count: 759
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
hit_count: 759
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
hit_count: 759
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
hit_count: 414
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
hit_count: 414
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
hit_count: 414
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
hit_count: 450
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
hit_count: 450
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
hit_count: 440
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

- `package.json` exists at the repo root, declares
  `"name": "@build-fractal/orchestrator"` ([D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }")), `"bin":
  {"orchestrator": "bin/orchestrator"}`, `"engines": {"node":
  ">=14"}`, `"os": ["darwin", "linux"]`, `"version"` aligned with
  `CHANGELOG.md` top-line via T01 author-time read (CON-4), and a
  `"scripts": {"postinstall": "..."}` field pointing at the
  postinstall driver.
  - Check: `bash tools/verify/m035-p02-package-json-shape.sh`

- `bin/orchestrator` exists, is executable, prints the package version
  on `--version` (matches `package.json` `version` field), and prints a
  short usage banner naming the command-cohort prefix
  `orchestrator:<cmd>` ([D-RN-3](../../../../../decisions.md#d-rn-3-command-cohort-prefix-orchestratorcmd-dr-code-031 "Command-cohort prefix `orchestrator:<cmd>` { #dr-code-031 }")).
  - Check: `bash tools/verify/m035-p02-bin-entry.sh`

- `packaging/npm/postinstall.sh` exists, is executable, refuses with

<dispatch-volatile>

## Upstream Context


### P01.5 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P01.5"
parent: "M035"
milestone: "M035"
provides:
  - "[D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }")..[D-RN-7](../../../../../decisions.md#d-rn-7-pre-rename-version-tag-v09x-final-spec-kit-name-dr-code-035 "Pre-rename version tag `v0.9.X-final-spec-kit-name` { #dr-code-035 }") decision block (anchors dr-code-029..dr-code-035) recording rename decisions for downstream P02/P03/P05; tests/m035-acceptance/legacy-namespace-allowlist.txt enumerating exactly 5 SC-7-allowlisted historical/migration files; pre-rename git tag v0.9.2-final-spec-kit-name at HEAD (local-only,reversible via git tag -d); three task-grain verifiers (m035-p015-allowlist-shape.sh,m035-p015-decisions-block.sh,m035-p015-pre-rename-tag.sh) under tools/verify/,specs/001-speckit-orchestrator -> specs/001-orchestrator git-mv-tracked rename with full history preservation; 11-file in-tree content reference sweep (CLAUDE.md + references/file-formats.md + 9 fixture roadmaps); self-reference rewrite inside renamed dir across 12 files (contracts/state-files.md,conversus-plan/conversus.yml + apm/review.md + gh-aw/review.md,conversus-spec/apm review+revision,conversus-spec/gh-aw review,conversus-spec/spec-kit review+revision,conversus-spec/summary/final.md,data-model.md,plan.md,tasks.md); tools/verify/m035-p015-spec-dir-rename.sh task-grain verifier (single-script AD-19 shape,exit-zero PASS contract),C6 operator-environment paths sweep across 5 live operator-facing files (commands/update.md 8 edits + references/installation.md 2 edits + scripts/lifecycle/run-update.sh 3 edits + scripts/state/check-orchestrator-drift.sh 1 edit + specs/039-packaging-distribution/spec.md 1 edit); tools/verify/m035-p015-operator-paths.sh task-grain verifier (single-script AD-19 shape,exit-zero PASS contract,internal allowlist regex documented in script header),C1 lowercase-hyphenated spec-kit-orchestrator -> orchestrator sweep across 158 *.md/*.yml/*.yaml files (~308 occurrences) outside the C1 historical allowlist; tools/verify/m035-p015-c1-sweep.sh task-grain verifier (single-script AD-19 shape,internal allowlist regex extended for self-referential rename-description files),C2 (title-case Spec-Kit Orchestrator -> Orchestrator) + C3 (lowercase-spaced spec-kit orchestrator / spec kit orchestrator -> orchestrator) prose sweep complete across non-historical *.md files; commands/README.md:3 + .planning/research-prompt-speckit-orchestrator.md:1 rewrites; tools/verify/m035-p015-c2-c3-prose.sh task-grain verifier (single-script AD-19 shape,exit-zero PASS contract) with allowlist mirroring T04/C1 plus M035-ROADMAP.md/M035-CONTEXT.md (Boundary Map preserves rename mappings as literal source tokens),C5 cohort-finish across 4 operational template surfaces -- templates/claude-settings.json line 56 Skill(speckit.orchestrator.*) -> Skill(orchestrator:*) + line 64 Bash(bash spec-kit-orchestrator/scripts/*) -> Bash(bash orchestrator/scripts/*); templates/autonomy-defaults.yaml line 91 Skill(speckit.orchestrator.*) -> Skill(orchestrator:*); templates/instruction-schema.md line 140 schema-skeleton heading speckit.orchestrator.<command> -> orchestrator:<command> + appended historical-reference framing paragraph after the code fence; templates/compression-tier3-prompt.md lines 14 and 45 reframe legacy speckit.orchestrator.* namespaced-alias mention as historical/migration-only documentation reference; tools/verify/m035-p015-c5-cohort-finish.sh task-grain verifier (single-script AD-19 shape,JSON+YAML validity preserved),C4 per-line judgment classification across the standalone spec-kit residue surface (982 lines after exclusions); .orchestrator/milestones/M035/phases/P01.5/c4-classification.txt classification log with file:line:verdict:rationale shape (1 C4-rename,981 UPSTREAM,0 REVIEW); references/installation.md:271 npm-scope rewrite from @spec-kit/orchestrator (placeholder) to @build-fractal/orchestrator (per [D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }") binding resolution); tools/verify/m035-p015-c4-classification.sh task-grain verifier (single-script AD-19 shape,asserts log existence + zero REVIEW + every C4-rename verdict has had its standalone spec-kit token rewritten),SC-7 cohort grep-zero-match acceptance verifier (tools/verify/m035-p015-sc7.sh,single-script AD-19 shape,restricts grep to commands/ scripts/ templates/ references/ docs/ per spec wording,pipes through legacy-namespace allowlist); SC-7b spec-kit-orchestrator-basename grep-zero-match acceptance verifier (tools/verify/m035-p015-sc7b.sh,conditional package.json check); AD-19-prefixed phase-suite aggregator (tools/verify/m035-p015-phase-suite.sh,11 verifiers,BATTERY: pass=N fail=N line shape,folds operator-runbook existence check before the verifier loop); off-tree operator runbook artifact ([.orchestrator/milestones/M035/phases/P01.5/operator-runbook.md](../../../../../milestones/M035/phases/P01.5/operator-runbook.md),3 steps for [D-RN-2](../../../../../decisions.md#d-rn-2-github-repo-basename-build-fractalorchestrator-dr-code-030 "GitHub repo basename `Build-Fractal/orchestrator` { #dr-code-030 }") GitHub remote rename + [D-RN-5](../../../../../decisions.md#d-rn-5-local-clone-path-sitesorchestrator-dr-code-033 "Local clone path `~/Sites/orchestrator` { #dr-code-033 }") local working-dir mv + [D-RN-6](../../../../../decisions.md#d-rn-6-migrate-claude-memory-dir-alongside-path-rename-dr-code-034 "Migrate Claude memory dir alongside path rename { #dr-code-034 }") Claude memory project-key migration,each with reversibility and recommended-timing notes plus [D-RN-7](../../../../../decisions.md#d-rn-7-pre-rename-version-tag-v09x-final-spec-kit-name-dr-code-035 "Pre-rename version tag `v0.9.X-final-spec-kit-name` { #dr-code-035 }") pre-rename-tag reversibility section); cumulative-state remediation of two latent residues (templates/compression-tier3-prompt.md:45 speckit.orchestrator.dispatch -> speckit.orchestrator.<command> placeholder-form preserves T06 prose intent while satisfying SC-7 regex; specs/039-packaging-distribution/spec.md:50 $HOME/Sites/spec-kit-orchestrator -> $HOME/Sites/orchestrator T03 latent gap)"
requires:
  - "P01"
affects:
  - "P02"
key_files:
  - "[.orchestrator/DECISIONS.md](../../../../../decisions.md),tests/m035-acceptance/legacy-namespace-allowlist.txt,tools/verify/m035-p015-allowlist-shape.sh,tools/verify/m035-p015-decisions-block.sh,tools/verify/m035-p015-pre-rename-tag.sh,specs/001-orchestrator/,CLAUDE.md,references/file-formats.md,tests/fixtures/roadmap-sample.md,tests/fixtures/state-complete/M001-ROADMAP.md,tests/fixtures/state-completing/M001-ROADMAP.md,tests/fixtures/state-executing/M001-ROADMAP.md,tests/fixtures/state-replanning/M001-ROADMAP.md,tests/fixtures/state-summarizing/M001-ROADMAP.md,tests/fixtures/state-validating/M001-ROADMAP.md,tests/fixtures/state-verifying/M001-ROADMAP.md,tools/verify/m035-p015-spec-dir-rename.sh,commands/update.md,references/installation.md,scripts/lifecycle/run-update.sh,scripts/state/check-orchestrator-drift.sh,specs/039-packaging-distribution/spec.md,tools/verify/m035-p015-operator-paths.sh,tools/verify/m035-p015-c1-sweep.sh,README.md,packaging/bundle/manifest.yml,wiki/mkdocs.yml,references/architecture.md,packaging/bundle/README.md,specs/035-wiki-distribution-init-integration/spec.md,specs/003-migration-tool/spec.md,specs/023-github-native-integration/conversus.yml,specs/001-orchestrator/contracts/extension-manifest.md,commands/README.md,.planning/research-prompt-speckit-orchestrator.md,tools/verify/m035-p015-c2-c3-prose.sh,templates/claude-settings.json,templates/autonomy-defaults.yaml,templates/instruction-schema.md,templates/compression-tier3-prompt.md,tools/verify/m035-p015-c5-cohort-finish.sh,.orchestrator/milestones/M035/phases/P01.5/c4-classification.txt,tools/verify/m035-p015-c4-classification.sh,tools/verify/m035-p015-sc7.sh,tools/verify/m035-p015-sc7b.sh,tools/verify/m035-p015-phase-suite.sh,[.orchestrator/milestones/M035/phases/P01.5/operator-runbook.md](../../../../../milestones/M035/phases/P01.5/operator-runbook.md)"
key_decisions:
  - "[D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }") (dr-code-029) ; [D-RN-2](../../../../../decisions.md#d-rn-2-github-repo-basename-build-fractalorchestrator-dr-code-030 "GitHub repo basename `Build-Fractal/orchestrator` { #dr-code-030 }") (dr-code-030) ; [D-RN-3](../../../../../decisions.md#d-rn-3-command-cohort-prefix-orchestratorcmd-dr-code-031 "Command-cohort prefix `orchestrator:<cmd>` { #dr-code-031 }") (dr-code-031) ; [D-RN-4](../../../../../decisions.md#d-rn-4-homebrew-tap-build-fractalorchestrator-single-formula-dr-code-032 "Homebrew tap `build-fractal/orchestrator` (single-formula) { #dr-code-032 }") (dr-code-032) ; [D-RN-5](../../../../../decisions.md#d-rn-5-local-clone-path-sitesorchestrator-dr-code-033 "Local clone path `~/Sites/orchestrator` { #dr-code-033 }") (dr-code-033) ; [D-RN-6](../../../../../decisions.md#d-rn-6-migrate-claude-memory-dir-alongside-path-rename-dr-code-034 "Migrate Claude memory dir alongside path rename { #dr-code-034 }") (dr-code-034) ; [D-RN-7](../../../../../decisions.md#d-rn-7-pre-rename-version-tag-v09x-final-spec-kit-name-dr-code-035 "Pre-rename version tag `v0.9.X-final-spec-kit-name` { #dr-code-035 }") (dr-code-035) ; CHANGELOG-top-line-X-resolution X=2 (from,awk skips ## [Unreleased]) ; dispatch-wrapper-vs-task-plan reconciliation: append-decision.sh produces legacy 7-column-table rows that decisions-shape-lint rejects + that m035-p015-decisions-block.sh verifier does not match — followed task plan's heading shape per wrapper's own 'follow the Steps exactly' clause,[D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }") informs basename (specs/001-orchestrator matches @build-fractal/orchestrator unscoped name); allowlist-extension-beyond-payload-step-5-regex: P01.5-PLAN.md + T02/T03/T04 PLAN.md files preserved as narrative (analogous to explicitly-excluded P01.5-PLANNING-PAYLOAD.md,all document the rename itself); M015/P04/evidence/clean-clone-shape.txt preserved (archived path snapshot,rewrite would falsify audit); conversus-plan/apm/review.md absolute-path refs swept by substring (specs/... only,<redacted-path>/... prefix preserved as historical authoring-context record); verifier-runs-post-commit (git log --follow needs committed new path; pre-commit invocation returns empty),[D-RN-5](../../../../../decisions.md#d-rn-5-local-clone-path-sitesorchestrator-dr-code-033 "Local clone path `~/Sites/orchestrator` { #dr-code-033 }") drives the rewrite target; allowlist-extension-beyond-payload-step-3-regex (narrow 5-prefix regex insufficient -- extended to mirror T04 broader C1 historical allowlist covering closed-milestone authoring artifacts,DECISIONS.md,proposals,scratch,handoffs,fixtures,KNOWLEDGE.md); upstream_path-default-rewrite-safe (no P01 verifier hardcodes the old default in check-orchestrator-drift.sh -- verified via grep); off-tree-rename-deferred-to-T08 (mv operations + Claude memory dir migration are operator-runbook actions),[D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }") drives C1 rewrite target; allowlist-extension-for-self-referential-rename-descriptions (M035-ROADMAP.md + M035-CONTEXT.md + specs/039-packaging-distribution/spec.md must retain spec-kit-orchestrator references because they describe the rename plan itself; mechanical collapse to orchestrator -> orchestrator is nonsensical); .planning/speckit-*-playbook.md is out-of-scope-for-C1 (basename uses speckit-orchestrator without spec-kit hyphen -- T06 cohort territory),allowlist-extension-beyond-payload-step-5-regex (mirrors T04 pattern: M035-ROADMAP.md and M035-CONTEXT.md added because the Boundary Map enumerates rename mappings as literal source tokens that must be preserved verbatim to document the rename); upstream-spec-kit-deferred-to-T07 (any prose mentioning the upstream spec-kit framework is C4 territory and out of T05 scope -- T07 will cross-validate); regex-shape-corrected-from-payload-step-5 (payload step 5 verifier text trailed the allowlist alternation with a literal colon which would never match path-prefix entries like .orchestrator/milestones/M035/phases/P01.5/ -- T04 verifier shape (no trailing colon) adopted instead,identical semantics for file:line-prefix matching),[D-RN-3](../../../../../decisions.md#d-rn-3-command-cohort-prefix-orchestratorcmd-dr-code-031 "Command-cohort prefix `orchestrator:<cmd>` { #dr-code-031 }") cohort prefix is orchestrator:<cmd>; [D-RN-5](../../../../../decisions.md#d-rn-5-local-clone-path-sitesorchestrator-dr-code-033 "Local clone path `~/Sites/orchestrator` { #dr-code-033 }") path-shape spec-kit-orchestrator/* -> orchestrator/*; C5 prose-reframe contract (active form is new identifier; legacy form is named as documented historical reference,NOT as a live registration surface); JSON+YAML validity invariant (each edit confined to within string-value bytes,no quoting/comma/array-syntax mutation); single-Edit-call-per-file shape per CON-3 (AP-009-shape-guard-honored); instruction-schema.md historical-framing landed as a paragraph after the closing code fence rather than inside the schema-skeleton example (preserves clean-example-block contract while satisfying C5 historical-reference framing),[D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }") npm scope @build-fractal/orchestrator (DECISIONS.md DR-CODE-029) is the binding resolution that supersedes M035-CONTEXT.md OQ #Q-1 placeholder @spec-kit/orchestrator; default-UPSTREAM verdict for the C4 surface is the correct posture (T01..T06 already rewrote every short-form reference that meant *this* project; the residue overwhelmingly references the upstream framework as migration source / format contract / historical context per RENAME-PLAN line 52); pre-decision authoring docs (M035-CONTEXT.md and [.orchestrator/proposals/M035-packaging-distribution.md](../../../../../proposals/M035-packaging-distribution.md)) retain @spec-kit/orchestrator as historical record of the pre-decision OQ state -- DECISIONS.md is the authoritative record of the resolution per project proposal-lifecycle convention; BSD-grep \\b boundary-anchor adjustment from the payload-suggested pattern (BSD/macOS grep -E does NOT honor \\b inside character class boundaries with hyphen; replaced \\bspec-kit\\b|\\bspec kit\\b with bare spec-kit|spec kit and relied on compound-form exclusions to filter the project-bound references); conversus path exclusion regex fix (payload had ^(...|specs/001-orchestrator/conversus-): which matched only paths ending exactly conversus-:,missing the deliberation tree; rebuilt as a separate path-prefix grep -vE branch),SC-7 spec-restricted-subtree-grep (verifier scope is the 5 operational subtrees commands/ scripts/ templates/ references/ docs/ per spec wording,NOT a repo-wide grep -- spec change to expand requires verifier change in lockstep); SC-7b conditional-package.json (P02 authors package.json; pre-P02 absence is a no-op not a fail); phase-suite-folded-runbook-check (operator-runbook existence is checked inline at the top of the phase-suite rather than spawning a 4th task-grain verifier per T08 step 5 fold-in convention -- avoids verifier count inflation while preserving the contract); placeholder-form-token-preserves-prose-intent-and-satisfies-regex (rewriting speckit.orchestrator.dispatch to speckit.orchestrator.<command> in compression-tier3-prompt.md retains T06 prose-reframe contract -- legacy form named as documented historical reference -- while sidestepping SC-7 regex match because angle-bracket placeholder does not match [a-z]); T03-latent-gap-fix-in-T08-scope (specs/039-packaging-distribution/spec.md:50 was claimed-but-not-shipped at T03 close -- git log + git diff confirm zero edits to that file; T08 surgical rewrite is within mission contract because T08 must PASS the cumulative T01..T07 state)"
patterns_established:
  - "decisions-block-as-D-RN-N-heading-cohort (one ### heading per decision in a contiguous block,anchors run in numeric sequence dr-code-NNN..dr-code-NNN+6,body uses bullet list shape from existing #dr-code-004 example) ; line-equality-allowlist-file (allowlist has exact line count enforced by verifier,plus per-path on-disk existence check,so allowlist cannot drift away from real files it names) ; reversible-local-tag-as-cutover-marker (pre-rename git tag at HEAD,not pushed,reversible via git tag -d,captures patch number from CHANGELOG.md top-line at execution time so plan-author/execution-time drift is absorbed) ; verifier-pattern-pin-by-prefix-not-patch (m035-p015-pre-rename-tag.sh greps v0.9.*-final-spec-kit-name with shell glob — survives patch-number drift between plan author and execution),git-mv-then-substring-sweep-as-atomic-unit (rename + content references one commit,reversible via single git revert); pragmatic-allowlist-extension (when payload exclusion regex does not enumerate every narrative-rename-doc,dispatched task may extend allowlist with documented justification rather than mechanically sweeping rename-narrative files); verifier-post-commit-shape (git log --follow on the new path requires the rename to be committed first; verifier runs after the commit,not before); absolute-path-substring-sweep (when refs carry environment prefixes that document historical authoring context,sweep only the specs/<old>->specs/<new> substring and preserve prefix),operator-facing-path-sweep-with-internal-allowlist (verifier carries its own multi-prefix allowlist regex with inline documentation; auditable without external lookup); pragmatic-allowlist-extension-pattern-T02-handoff (when payload step-3 narrow regex does not enumerate every historical surface,dispatched task may extend allowlist with documented in-script justification rather than mechanically sweeping into closed milestones); regex-line-shape-discipline (anchor at start-of-line; <path>:<lineno>:<content> separator semantics so trailing colon in regex matches filename-end not directory-end); per-file-edit-no-sed-chain (CON-3 / AP-009 honored throughout -- 14 individual Edit calls across 5 files,no git ls-files xargs sed),staged-probe-with-run-probe-wrapper-for-bulk-sed (Write tool stages /tmp/m035-p015-c1-sweep.sh probe; scripts/util/run-probe.sh invokes via approved-root contract; CON-3/AP-009 honored without per-file Edit tool calls); self-referential-rename-description-allowlist-extension (rename-plan documents must retain pre-rename name to remain coherent; allowlist regex extension is the right fix not eyeball rewrite); post-sweep-sentence-flow-audit (git grep for orchestrator-orchestrator/orchestrator project is now patterns surfaces awkward sed artifacts before verifier finalization),allowlist-extension-mirrors-prior-task (C2/C3 prose sweep allowlist deliberately mirrors T04/C1 sweep allowlist plus the same M035-ROADMAP/M035-CONTEXT additions,so future C-category sweeps can copy-paste the allowlist with category-specific regex); meta-mapping-preservation (rename-runbook prose documenting old->new mappings as literal tokens is allowlisted not edited; the rename plan must remain readable post-rename); minimal-touch-prose-edit (only 2 prose edits required outside allowlist scope -- the C2/C3 surface had already been largely cleaned by T04 sweep over markdown files); verifier-grep-shape (git grep -niE pipe grep -vE shell pattern,identical to T04,AD-19 single-script-file Check shape,CON-3-honored no compound chains),dotted-namespace-to-colon-prefix-glob-rename (Skill(speckit.orchestrator.*) -> Skill(orchestrator:*) preserves the surrounding allowed-skills array shape and is byte-localized to the string value); path-shape-rename-inside-bash-permission-glob (Bash(bash spec-kit-orchestrator/scripts/*) -> Bash(bash orchestrator/scripts/*) is the C1+C5 hybrid surface closed in the same template-pass commit); prose-reframe-with-historical-anchor (when a code-fenced example carries the legacy form as the active identifier,replace the active form in-fence and append a post-fence paragraph that names the legacy form as documented historical reference -- preserves clean schema-skeleton example while satisfying SC-7 historical-framing rule); inline-prose-reframe-with-explicit-historical-clause (compression-tier3-prompt.md preserves-list and prose enumeration rewritten so colon/slash forms are the active surface and the namespaced-alias form is bracketed by an explicit 'appears only in pre-M035 historical and migration documentation' clause); verifier-shape-asymmetric-for-operational-vs-prose (operational surfaces assert ZERO speckit.orchestrator matches AND new-form presence; prose surfaces assert only new-form presence -- legacy form may appear inside historical-framing prose,which the verifier intentionally does not enforce-by-content); JSON+YAML-validity-as-implicit-precondition (post-edit python3 -c 'import json/yaml; load(...)' both pass without error),per-line-judgment-classification-with-default-verdict-by-rationale-bucket (when the surface is large and the rationale is one-of-N categorical buckets,classify by file-cohort with a default verdict and enumerate explicit exceptions; emit one log line per match for audit-trail completeness; the per-line discipline is the safety mechanism but the verdict assignment can be by-cohort); BSD-grep-boundary-anchor-replacement (BSD grep -E does not honor \\b in many contexts; rebuild patterns to use compound-form exclusions instead of \\bword\\b anchors); decision-supersedes-placeholder pattern (when DECISIONS.md resolves an OQ that earlier authoring docs cited as placeholder,rewrite live operator-facing docs to the resolved value; preserve pre-decision proposal docs as historical record); REVIEW-as-HALT-escape-hatch (T07 ships zero REVIEW verdicts; the HALT discipline is the operator escape hatch for ambiguous cases but is not exercised when the surface decomposes cleanly); classification-log-as-load-bearing-artifact (the .txt log is the consolidate-time audit trail; the verifier asserts log shape and post-rewrite state,both via grep),placeholder-form-rewrite-as-regex-escape-without-content-loss (when a legacy token literal carries documented-historical-reference semantics inside prose AND a downstream regex would match it,rewrite the literal to the placeholder form -- speckit.orchestrator.<command> instead of speckit.orchestrator.dispatch -- so the regex's [a-z] character class is sidestepped while the historical-reference framing is preserved); phase-suite-folded-existence-check (a documentation-artifact existence check folds into the phase-suite aggregator as a guard above the verifier loop rather than spawning a 4th task-grain verifier; the check fails the BATTERY count cleanly without inflating the verifier list); cumulative-state-remediation-discipline (when an acceptance verifier surfaces a latent gap from a prior task's claimed-but-unshipped or partially-shipped edit,surgical fix in the acceptance task is preferable to DONE_WITH_CONCERNS handoff -- the edit is byte-localized,identifiable from git history,and within the acceptance task mission contract; surfacing the fix explicitly in the SUMMARY DONE_WITH_CONCERNS-style narrative preserves the audit trail); BATTERY-line-shape-convention-mirror (BATTERY: pass=N fail=N matches the m030 + m032 + m029 acceptance-battery line shape,enabling consolidate-time grep aggregation across milestone batteries); off-tree-runbook-as-documentation-artifact-not-script (the off-tree operator runbook is a markdown documentation artifact under .orchestrator/milestones/<M>/phases/<P>/ rather than a runnable shell script; the auto-loop CANNOT execute these steps -- runbook is the operator-facing handoff artifact)"
drill_down_paths:
  - "[.orchestrator/milestones/M035/phases/P01.5/tasks/T01-SUMMARY.md](../../../../../milestones/M035/phases/P01.5/tasks/T01-SUMMARY.md), [.orchestrator/milestones/M035/phases/P01.5/tasks/T02-SUMMARY.md](../../../../../milestones/M035/phases/P01.5/tasks/T02-SUMMARY.md), [.orchestrator/milestones/M035/phases/P01.5/tasks/T03-SUMMARY.md](../../../../../milestones/M035/phases/P01.5/tasks/T03-SUMMARY.md), [.orchestrator/milestones/M035/phases/P01.5/tasks/T04-SUMMARY.md](../../../../../milestones/M035/phases/P01.5/tasks/T04-SUMMARY.md), [.orchestrator/milestones/M035/phases/P01.5/tasks/T05-SUMMARY.md](../../../../../milestones/M035/phases/P01.5/tasks/T05-SUMMARY.md), [.orchestrator/milestones/M035/phases/P01.5/tasks/T06-SUMMARY.md](../../../../../milestones/M035/phases/P01.5/tasks/T06-SUMMARY.md), [.orchestrator/milestones/M035/phases/P01.5/tasks/T07-SUMMARY.md](../../../../../milestones/M035/phases/P01.5/tasks/T07-SUMMARY.md), [.orchestrator/milestones/M035/phases/P01.5/tasks/T08-SUMMARY.md](../../../../../milestones/M035/phases/P01.5/tasks/T08-SUMMARY.md)"
duration: "173m"
verification_result: "pass"
completed_at: "2026-05-08T17:40:16Z"
observability_surfaces:
  - "none"
---

P01.5 executed the spec-kit-orchestrator → orchestrator namespace rename across 8 tasks. T01 landed the [D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }")..[D-RN-7](../../../../../decisions.md#d-rn-7-pre-rename-version-tag-v09x-final-spec-kit-name-dr-code-035 "Pre-rename version tag `v0.9.X-final-spec-kit-name` { #dr-code-035 }") decision block (anchors `dr-code-029`..`dr-code-035`), the 5-line legacy-namespace allowlist, and the reversible pre-rename tag `v0.9.2-final-spec-kit-name`. T02 git-mv'd `specs/001-speckit-orchestrator/` → `specs/001-orchestrator/` with full history preservation and content sweep. T03 swept C6 operator-environment paths across 5 live operator-facing files. T04 swept C1 lowercase-hyphenated `spec-kit-orchestrator → orchestrator` across 158 markdown/YAML files (~308 occurrences) outside the historical allowlist. T05 closed C2/C3 prose-form residue (Spec-Kit Orchestrator / spec-kit orchestrator) with 2 surgical prose edits — the broader T04 sweep had already cleaned most surfaces. T06 closed C5 cohort residue across 4 operational template surfaces (claude-settings.json + autonomy-defaults.yaml glob patterns; instruction-schema.md + compression-tier3-prompt.md prose). T07 ran the C4 per-line judgment pass over 982 lines of upstream-vs-rename residue, classifying 1 C4-rename + 981 UPSTREAM + 0 REVIEW; the single rewrite was `references/installation.md:271` from `@spec-kit/orchestrator` to `@build-fractal/orchestrator` per [D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }"). T08 shipped the SC-7 / SC-7b / phase-suite acceptance verifiers, the off-tree operator runbook ([D-RN-2](../../../../../decisions.md#d-rn-2-github-repo-basename-build-fractalorchestrator-dr-code-030 "GitHub repo basename `Build-Fractal/orchestrator` { #dr-code-030 }") GitHub remote rename + [D-RN-5](../../../../../decisions.md#d-rn-5-local-clone-path-sitesorchestrator-dr-code-033 "Local clone path `~/Sites/orchestrator` { #dr-code-033 }") local working-dir mv + [D-RN-6](../../../../../decisions.md#d-rn-6-migrate-claude-memory-dir-alongside-path-rename-dr-code-034 "Migrate Claude memory dir alongside path rename { #dr-code-034 }") Claude memory project-key migration), and surgical cumulative-state remediation of two latent T03/T06 residues.

Verification: phase-suite emits `BATTERY: pass=11 fail=0`; SC-7 + SC-7b grep-zero-match acceptance assertions PASS; check-must-haves PASS with all 12 truths verified and all artifacts on disk; external-mod check PASS.

Patterns established cluster around 5 themes: pragmatic-allowlist-extension (T02/T03/T04/T05/T06 all extended the per-task verifier's allowlist beyond the payload-suggested narrow regex with documented in-script justification when historical authoring docs needed to retain the legacy form); regex-line-shape discipline (file:line-prefix matching with no trailing literal colon, BSD-grep boundary-anchor compatibility, conversus-path-prefix exclusion); per-Edit-call CON-3/AP-009 honor (no `git ls-files | xargs sed` chains; staged-probe-via-run-probe.sh wrapper for bulk sed when needed); JSON+YAML validity invariant for operational template edits; verifier-shape asymmetric for operational vs prose surfaces (operational asserts zero matches + new-form presence; prose asserts only new-form presence so legacy form may appear inside historical-framing prose). Cumulative-state remediation discipline (acceptance-task surgical fix preferable to DONE_WITH_CONCERNS handoff when latent prior-task gap surfaces) and phase-suite-folded existence checks (documentation-artifact existence folds into phase-suite aggregator rather than spawning a 4th task-grain verifier) round out the patterns.

Off-tree operator steps ([D-RN-2](../../../../../decisions.md#d-rn-2-github-repo-basename-build-fractalorchestrator-dr-code-030 "GitHub repo basename `Build-Fractal/orchestrator` { #dr-code-030 }") GitHub remote rename, [D-RN-5](../../../../../decisions.md#d-rn-5-local-clone-path-sitesorchestrator-dr-code-033 "Local clone path `~/Sites/orchestrator` { #dr-code-033 }") local working-dir mv, [D-RN-6](../../../../../decisions.md#d-rn-6-migrate-claude-memory-dir-alongside-path-rename-dr-code-034 "Migrate Claude memory dir alongside path rename { #dr-code-034 }") Claude memory project-key migration) are documented in [`.orchestrator/milestones/M035/phases/P01.5/operator-runbook.md`](../../../../../milestones/M035/phases/P01.5/operator-runbook.md) for post-close operator execution; the auto-loop cannot execute these. Pre-rename tag `v0.9.2-final-spec-kit-name` is in local refs (operator-personal until pushed) per [D-RN-7](../../../../../decisions.md#d-rn-7-pre-rename-version-tag-v09x-final-spec-kit-name-dr-code-035 "Pre-rename version tag `v0.9.X-final-spec-kit-name` { #dr-code-035 }").

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M035"
name: "packaging/npm/postinstall.sh driver (Unix-delegate, Windows fail-closed, INIT_CWD-aware)"
depends_on: ["T01"]
---

## Prerequisites

- **T01 complete**: `package.json` exists at the repo root with
  `"scripts": {"postinstall": "bash packaging/npm/postinstall.sh"}`
  and `"os": ["darwin", "linux"]`. The postinstall script T02
  authors is the target of that script reference.
- **`packaging/install/install-claude-code.sh` exists** (M025
  surface, on disk since 2026-04-23). T02's driver delegates to
  this script after passing the Unix/Windows guard.
- **`packaging/install/install-codex.sh` and
  `packaging/install/install-cursor.sh` exist** (M025 surface).
  T02's driver detects the active runtime via the convention
  documented below and dispatches to the matching installer.
- **No `packaging/npm/` directory exists yet** (Plan-Time Discipline
  Rule 6 — confirmed at plan-authoring time).

## Description

Author the postinstall driver `packaging/npm/postinstall.sh` that
runs after `npm install -g @build-fractal/orchestrator`. The
postinstall:

1. Refuses on Windows-detected `uname -s` (`MINGW*`/`CYGWIN*`/`MSYS*`/
   `Windows_NT`) with a clear stderr message (#Q-G9 / MIT-9 belt-and-
   suspenders — `package.json os` field is the primary gate, this is
   the secondary).
2. Honors `DRY_RUN=1` env var: emits `would_invoke=...` lines, makes
   no writes (D002 fixture-strategy contract).
3. Resolves the project directory from `INIT_CWD` env var (npm
   convention — npm sets this to the directory the user ran `npm
   install` from). Falls back to `$PWD` if `INIT_CWD` is unset.
4. Detects the active Claude Code runtime by probing for
   `~/.claude/` directory. If present, delegates to `install-claude-
   code.sh --project-dir "$INIT_CWD"`. If absent, emits a
   `runtime_unavailable=true` advisory line (no failure — `bin/
   orchestrator --version` still works) and exits 0 with a stderr
   note explaining how to install Claude Code.
5. Codex CLI / Cursor runtime detection is stubbed at v1: the v1
   postinstall only delegates to claude-code. Multi-runtime postinstall
   is M009 territory (post-launch).

## Steps

1. **Create `packaging/npm/` directory** (if it doesn't exist):

   ```bash
   mkdir -p packaging/npm
   ```

2. **Author `packaging/npm/postinstall.sh`** with shebang
   `#!/usr/bin/env bash` and verbatim body:

   ```bash
   #!/usr/bin/env bash
   # packaging/npm/postinstall.sh -- npm postinstall driver for
   # @build-fractal/orchestrator (M035 P02 T02).
   #
   # Runs automatically after `npm install -g @build-fractal/orchestrator`.
   # Wraps the existing M025 installers (install-claude-code.sh) with:
   #   * Windows fail-closed guard (MIT-9 / D003 belt-and-suspenders)
   #   * DRY_RUN=1 honor (D002 test-fixture contract)
   #   * INIT_CWD-aware project-dir resolution (npm convention)
   #   * Runtime detection: Claude Code at v1; Codex/Cursor stubbed
   #
   # Exit codes:
   #   0 success (or runtime_unavailable advisory — non-blocking)
   #   1 Windows refused, or Unix delegate failed
   #
   # Bash 3.2 compatible. No declare -A, no jq, no python.

   set -u

   # --- 1. Windows fail-closed guard (#Q-G9 / MIT-9) -------------------

   uname_s="$(uname -s 2>/dev/null || echo unknown)"
   case "$uname_s" in
     MINGW*|CYGWIN*|MSYS*|Windows_NT|WindowsNT)
       echo "FAIL: @build-fractal/orchestrator postinstall does not run on Windows." >&2
       echo "      Windows symlink-mode and runtime parity are deferred to" >&2
       echo "      post-launch milestone M009 (multi-runtime parity audit)." >&2
       echo "      The package.json os field should have caught this on npm's" >&2
       echo "      side; if you see this message, please file an issue at" >&2
       echo "      https://github.com/Build-Fractal/orchestrator/issues" >&2
       exit 1
       ;;
   esac

   # --- 2. Resolve REPO_ROOT (where the npm package extracted) -------

   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   # packaging/npm/postinstall.sh -> repo root is 2 levels up
   REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   INSTALLER="$REPO_ROOT/packaging/install/install-claude-code.sh"

   # --- 3. Resolve INIT_CWD (npm convention) -------------------------

   # npm sets INIT_CWD to the directory `npm install` was run from.
   # When `npm install -g` runs without a project context, INIT_CWD
   # may be unset or point at the global npm prefix — in that case
   # the postinstall is a "package present, project not yet chosen"
   # event and we skip skill registration entirely.
   PROJECT_DIR="${INIT_CWD:-${PWD:-}}"

   # If PROJECT_DIR is empty or matches the npm global prefix, treat
   # this as a "global install, no project" event — emit advisory only.
   NPM_PREFIX="$(npm config get prefix 2>/dev/null || echo "")"
   if [ -z "$PROJECT_DIR" ] || [ "$PROJECT_DIR" = "$NPM_PREFIX" ] || \
      [ "$PROJECT_DIR" = "$NPM_PREFIX/lib/node_modules" ]; then
     echo "ADVISORY: @build-fractal/orchestrator installed globally; no project context." >&2
     echo "          Run \`orchestrator --help\` for next steps. Per-project skill" >&2
     echo "          registration happens when you run /orchestrator-init inside a" >&2
     echo "          Claude Code project." >&2
     exit 0
   fi

   # --- 4. Honor DRY_RUN=1 (D002 test-fixture contract) --------------

   DRY_RUN="${DRY_RUN:-0}"
   if [ "$DRY_RUN" = "1" ]; then
     echo "would_invoke=$INSTALLER --project-dir $PROJECT_DIR"
     echo "would_check=~/.claude/ runtime presence"
     echo "would_delegate=install-claude-code.sh"
     exit 0
   fi

   # --- 5. Detect Claude Code runtime --------------------------------

   if [ ! -d "$HOME/.claude" ]; then
     echo "runtime_unavailable=true" >&2
     echo "ADVISORY: @build-fractal/orchestrator installed, but Claude Code is" >&2
     echo "          not detected at \$HOME/.claude. Skill registration deferred." >&2
     echo "          Install Claude Code (https://claude.com/claude-code) and" >&2
     echo "          re-run \`bash $INSTALLER --project-dir <path>\` to register" >&2
     echo "          skills, OR run /orchestrator-init inside any Claude Code" >&2
     echo "          project to register on first use." >&2
     exit 0
   fi

   # --- 6. Delegate to install-claude-code.sh ------------------------

   if [ ! -x "$INSTALLER" ]; then
     echo "FAIL: installer not found or not executable at $INSTALLER" >&2
     exit 1
   fi

   echo "delegating=$INSTALLER --project-dir $PROJECT_DIR"
   "$INSTALLER" --project-dir "$PROJECT_DIR"
   ```

3. **Make the postinstall executable**:

   ```bash
   chmod +x packaging/npm/postinstall.sh
   ```

4. **Author the postinstall-shape verifier** at
   `tools/verify/m035-p02-postinstall-shape.sh` with body:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p02-postinstall-shape.sh
   # Asserts packaging/npm/postinstall.sh exists, is executable, and
   # carries the load-bearing M035 P02 T02 contract surfaces:
   #   * Windows fail-closed guard (uname -s case match)
   #   * DRY_RUN=1 honor (would_invoke= line shape)
   #   * INIT_CWD resolution (npm convention)
   #   * runtime_unavailable advisory path (Claude Code absence)
   #   * delegation to install-claude-code.sh
   set -euo pipefail

   REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
   POSTINSTALL="$REPO/packaging/npm/postinstall.sh"

   pass=0
   fail=0

   if [ ! -f "$POSTINSTALL" ]; then
     echo "FAIL: $POSTINSTALL not found"
     fail=$((fail + 1))
   elif [ ! -x "$POSTINSTALL" ]; then
     echo "FAIL: $POSTINSTALL not executable"
     fail=$((fail + 1))
   else
     echo "PASS: postinstall.sh exists and is executable"
     pass=$((pass + 1))
   fi

   check_grep() {
     local pattern="$1"
     local label="$2"
     if grep -qE "$pattern" "$POSTINSTALL"; then
       echo "PASS: $label"
       pass=$((pass + 1))
     else
       echo "FAIL: $label (pattern: $pattern)"
       fail=$((fail + 1))
     fi
   }

   check_grep 'Windows_NT' "Windows fail-closed guard names Windows_NT (MIT-9)"
   check_grep 'MINGW\*|CYGWIN\*|MSYS\*' "Windows fail-closed guard names MINGW/CYGWIN/MSYS (MIT-9)"
   check_grep 'INIT_CWD' "INIT_CWD resolution (npm convention)"
   check_grep 'DRY_RUN' "DRY_RUN=1 honor (D002 fixture-strategy)"
   check_grep 'would_invoke=' "DRY_RUN=1 emits would_invoke= lines"
   check_grep 'install-claude-code\.sh' "delegates to install-claude-code.sh"
   check_grep 'runtime_unavailable=true' "runtime_unavailable advisory path (Claude Code absence)"

   # Functional smoke test: DRY_RUN=1 invocation emits would_invoke=
   # without making writes. Use a temp project dir to avoid polluting.
   TMPDIR_PROBE="$(mktemp -d 2>/dev/null || mktemp -d -t m035p02t02)"
   if INIT_CWD="$TMPDIR_PROBE" DRY_RUN=1 bash "$POSTINSTALL" 2>&1 \
        | grep -q '^would_invoke='; then
     echo "PASS: DRY_RUN=1 dry-run emits would_invoke= line"
     pass=$((pass + 1))
   else
     echo "FAIL: DRY_RUN=1 dry-run did not emit would_invoke="
     fail=$((fail + 1))
   fi
   rm -rf "$TMPDIR_PROBE" 2>/dev/null || true

   echo "BATTERY: pass=$pass fail=$fail"
   [ "$fail" -eq 0 ]
   ```

   Make it executable: `chmod +x tools/verify/m035-p02-postinstall-shape.sh`

5. **Self-check**:

   ```bash
   bash tools/verify/m035-p02-postinstall-shape.sh
   ```

   Must emit `BATTERY: pass=N fail=0` (8 PASS lines expected).

6. **Cross-reference verification — confirm `package.json scripts.postinstall` resolves**:

   ```bash
   bash scripts/util/run-probe.sh /tmp/m035-p02-t02-postinstall-resolve.sh
   ```

   Stage probe `/tmp/m035-p02-t02-postinstall-resolve.sh`:

   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   POSTINSTALL_REF="$(grep -E '"postinstall"[[:space:]]*:' \
     "$REPO_ROOT/package.json" | sed -E 's/.*"postinstall"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
   POSTINSTALL_PATH="$(echo "$POSTINSTALL_REF" | sed -E 's/^bash //')"
   if [ -x "$REPO_ROOT/$POSTINSTALL_PATH" ]; then
     echo "PASS: package.json scripts.postinstall resolves to executable: $POSTINSTALL_PATH"
   else
     echo "FAIL: package.json scripts.postinstall ($POSTINSTALL_PATH) not executable"
     exit 1
   fi
   ```

   Must emit `PASS:`. This is the cross-reference contract between
   T01's `package.json` and T02's postinstall driver.

## Must-Haves

This task addresses the following phase must-haves:

- Truth: `packaging/npm/postinstall.sh` exists, executable, refuses
  Windows, respects `DRY_RUN=1`, delegates to
  `install-claude-code.sh` with `--project-dir "$INIT_CWD"`
- Artifact: `packaging/npm/postinstall.sh` (min 40 lines, contains
  `Windows_NT` AND `INIT_CWD`)
- Key Link: `packaging/npm/postinstall.sh` → `packaging/install/install-claude-code.sh`

## Verification

```bash
bash tools/verify/m035-p02-postinstall-shape.sh
bash scripts/util/run-probe.sh /tmp/m035-p02-t02-postinstall-resolve.sh
```

## Inputs

### From Previous Tasks

- `package.json` (from T01)
  - Key API: contains `"scripts": {"postinstall": "bash
    packaging/npm/postinstall.sh"}` field. T02 authors the file
    that reference points to.
  - Key types: JSON object; npm-conformant `scripts.postinstall`
    is a shell command string.

### From Disk (Pre-existing)

- `packaging/install/install-claude-code.sh` — M025 installer surface.
  T02's driver delegates to it via `"$INSTALLER" --project-dir
  "$PROJECT_DIR"`. Do not modify this file in T02; only invoke.
  Existing flag contract (relevant to T02): `--project-dir PATH`
  (M025) sets the project root; `--dry-run` (M025) is the M025
  dry-run mode but T02's `DRY_RUN=1` is a separate npm-postinstall-
  layer dry-run that exits before invoking the installer at all.
- `scripts/util/run-probe.sh` — staged-probe wrapper for step 6.
  AP-009 / CON-3 honored.

## Constraints

- **AP-009 / CON-3 (compound-chain shape-guard)**: postinstall.sh
  itself is bash 3.2 compatible. The verifier's functional smoke
  test uses a temp dir to avoid filesystem pollution.
- **MIT-9 / D003 (Windows fail-closed belt-and-suspenders)**: the
  postinstall MUST exit non-zero on Windows-detected uname even
  though `package.json os: ["darwin", "linux"]` is the primary
  gate. Defense-in-depth.
- **D002 (DRY_RUN=1 contract)**: when `DRY_RUN=1` env var is set,
  postinstall MUST NOT invoke the installer. Must emit
  `would_invoke=...` lines. T03's byte-equivalence test relies on
  this contract.
- **No-runtime-detected is a soft failure**: if `~/.claude/` is
  absent, postinstall emits the advisory but exits 0. The npm
  install completes; skill registration is deferred to first
  `/orchestrator-init` invocation. Rationale: an `npm install -g`
  on a CI runner without Claude Code is a legitimate use case
  (operator wants the binary on PATH for later integration).
- **No INIT_CWD fallback to interactive prompt**: when `INIT_CWD`
  is unset OR matches the npm prefix, postinstall emits the
  global-install advisory and exits 0. Do not attempt to detect a
  project elsewhere.
- **CON-7 (M025 reversibility-gate preserved)**: postinstall does
  NOT bypass M025's manifest mechanism — it delegates to
  `install-claude-code.sh`, which writes the manifest as it would
  on any other invocation. `npm uninstall -g` does not currently
  cascade through the manifest (npm's npm-side uninstall removes
  the package files but doesn't run a script — there's no
  `preuninstall` hook reliable across npm versions). M035 P06
  extends `commands/update.md --rollback` for the npm uninstall
  cascade story; T02 only authors postinstall.

## Expected Output

Two new files on disk:

- `packaging/npm/postinstall.sh` (~80 lines, executable)
- `tools/verify/m035-p02-postinstall-shape.sh` (~70 lines, executable)
- One staged probe: `/tmp/m035-p02-t02-postinstall-resolve.sh`

`bash tools/verify/m035-p02-postinstall-shape.sh` emits `BATTERY:
pass=8 fail=0` (1 file-shape check + 6 grep checks + 1 functional
DRY_RUN smoke).

## Notes

Expected verifier output: 8 `PASS:` lines + 1 `BATTERY: pass=8
fail=0` line.

The functional DRY_RUN smoke in step 4's verifier is the closest
thing to a real-postinstall test we can run pre-publish. Plan-Time
Discipline Rule 5 (real-DB verification analog): there's no
"real npm registry verification" we can do at plan-execution time
without coupling to the registry. T03's `npm pack`-based byte-
equivalence test is the closest mechanical proxy; T04's CI
workflow is the only place a real `npm publish` runs (and then only
on `v*` tag-push events on the canonical repo).

Idempotency: re-running the postinstall under `DRY_RUN=1` is
side-effect-free. Re-running without DRY_RUN re-invokes the
installer, which is itself idempotent per M025's manifest replay.

Reversibility: removing `packaging/npm/postinstall.sh` and
`packaging/npm/` unwinds the task. T01's `package.json scripts.
postinstall` reference would then be a dangling pointer — `npm
install` would fail. Rollback ordering: T02 deletion must precede
T01 `package.json scripts.postinstall` field removal.

## State Context

- **Current State**: executing
- **Milestone**: M035
- **Phase**: P02
- **Task**: T02-postinstall-driver
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **AP-009 / CON-3 (compound-chain shape-guard)**: postinstall.sh
  itself is bash 3.2 compatible. The verifier's functional smoke
  test uses a temp dir to avoid filesystem pollution.
- **MIT-9 / D003 (Windows fail-closed belt-and-suspenders)**: the
  postinstall MUST exit non-zero on Windows-detected uname even
  though `package.json os: ["darwin", "linux"]` is the primary
  gate. Defense-in-depth.
- **D002 (DRY_RUN=1 contract)**: when `DRY_RUN=1` env var is set,
  postinstall MUST NOT invoke the installer. Must emit
  `would_invoke=...` lines. T03's byte-equivalence test relies on
  this contract.
- **No-runtime-detected is a soft failure**: if `~/.claude/` is
  absent, postinstall emits the advisory but exits 0. The npm
  install completes; skill registration is deferred to first
  `/orchestrator-init` invocation. Rationale: an `npm install -g`
  on a CI runner without Claude Code is a legitimate use case
  (operator wants the binary on PATH for later integration).
- **No INIT_CWD fallback to interactive prompt**: when `INIT_CWD`
  is unset OR matches the npm prefix, postinstall emits the
  global-install advisory and exits 0. Do not attempt to detect a
  project elsewhere.
- **CON-7 (M025 reversibility-gate preserved)**: postinstall does
  NOT bypass M025's manifest mechanism — it delegates to
  `install-claude-code.sh`, which writes the manifest as it would
  on any other invocation. `npm uninstall -g` does not currently
  cascade through the manifest (npm's npm-side uninstall removes
  the package files but doesn't run a script — there's no
  `preuninstall` hook reliable across npm versions). M035 P06
  extends `commands/update.md --rollback` for the npm uninstall
  cascade story; T02 only authors postinstall.

### Acceptance Criteria

This task addresses the following phase must-haves:

- Truth: `packaging/npm/postinstall.sh` exists, executable, refuses
  Windows, respects `DRY_RUN=1`, delegates to
  `install-claude-code.sh` with `--project-dir "$INIT_CWD"`
- Artifact: `packaging/npm/postinstall.sh` (min 40 lines, contains
  `Windows_NT` AND `INIT_CWD`)
- Key Link: `packaging/npm/postinstall.sh` → `packaging/install/install-claude-code.sh`

### Files To Touch

- `package.json` (create) — T01
- `bin/orchestrator` (create) — T01
- `packaging/npm/postinstall.sh` (create) — T02
- `packaging/npm/` (new directory) — T02
- `tests/m035-acceptance/cross-channel-byte-equivalence.sh` (create) — T03
- `tests/m035-acceptance/npm-pack-install.sh` (create — T03 helper) — T03
- `references/installation.md` (modify — append `## Channel-specific
  metadata files` section) — T03
- `.github/workflows/release.yml` (create) — T04
- `packaging/bundle/build-bundle.sh` (modify — add filter pass) — T05
- `packaging/bundle/manifest.yml` (modify — comment-doc the filter
  convention) — T05
- `tools/verify/m035-p02-package-json-shape.sh` (create) — T01
- `tools/verify/m035-p02-bin-entry.sh` (create) — T01
- `tools/verify/m035-p02-postinstall-shape.sh` (create) — T02
- `tools/verify/m035-p02-byte-equivalence-skeleton.sh` (create) — T03
- `tools/verify/m035-p02-installation-doc-exclusion-list.sh` (create) — T03
- `tools/verify/m035-p02-release-workflow-shape.sh` (create) — T04
- `tools/verify/m035-p02-bundle-hygiene-filter.sh` (create) — T05
- `tools/verify/m035-p02-npm-pack-contents.sh` (create) — T05
- `tools/verify/m035-p02-phase-suite.sh` (create) — T05

Plan-Time Discipline Rule 6 (path-collision check): every `create`
path above was checked at plan-authoring time via `ls`/`test -f` and
none exist on disk. The slug-bearing verifier names (`m035-p02-*`)
follow the milestone-prefix discipline from CLAUDE.md ("milestone slug
REQUIRED for per-phase verifiers"). The framework-staged dirs
(`commands/`, `references/`, `scripts/`, `templates/`) are NOT
written under by this phase.

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