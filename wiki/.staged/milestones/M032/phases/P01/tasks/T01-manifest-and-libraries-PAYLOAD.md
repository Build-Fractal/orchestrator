---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T01-manifest-and-libraries (Phase P01, Milestone M032)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (31 entries) | 20-891 | ~10100 | filtered |
| Decisions | 893-895 | ~100 | filtered |
| Constraints | 897-949 | ~600 | required |
| Scope | 951-978 | ~500 | required |
| Upstream Context | 980-982 | ~100 | required |
| Task Plan | 984-1110 | ~3400 | required |
| State Context | 1112-1118 | ~100 | required |
| First-Turn Completeness | 1120-1175 | ~900 | required |
| **Total** | | **~15800** | |

## Knowledge

<!-- 31 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 773
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
hit_count: 773
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
hit_count: 773
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
hit_count: 773
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
hit_count: 675
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
hit_count: 675
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
hit_count: 675
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
hit_count: 773
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
hit_count: 675
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
hit_count: 675
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
hit_count: 675
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
hit_count: 773
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
hit_count: 773
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
hit_count: 773
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
hit_count: 675
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
hit_count: 675
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
hit_count: 675
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
hit_count: 773
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
hit_count: 675
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
hit_count: 675
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
hit_count: 773
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
hit_count: 773
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
hit_count: 675
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
hit_count: 675
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
hit_count: 675
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
hit_count: 330
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
hit_count: 330
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
hit_count: 330
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
hit_count: 349
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
hit_count: 349
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
hit_count: 339
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
     Project-owned slug-bearing verifiers live under tools/verify/.
     Verifier scripts are co-authored alongside their corresponding
     artifact within the SAME task (plan-time discipline rule 2).
     Namespacing: `m032-p01-*` prefix avoids collision with M030/[M031](../../../../../milestones/M031/index.md)
     existing `p01-*` verifiers in the shared tools/verify/ tree. -->

### Truths

- `packaging/bundle/manifest.yml` carries a top-level `project_assets:` list with exactly four entries — one per runtime dir (`commands/`, `scripts/`, `references/`, `templates/`) — each declaring `source:`, `target:`, and `mode: copy` (default per FR-1). Schema is additive — existing manifest top-level keys (`schema_version`, `type`, `name`, `version`, `description`, `skill_spec`, `skills`, `hooks`, `config_default`, `runtime_compatibility`) MUST keep their pre-M032 values byte-identical.
  - Check: `bash tools/verify/m032-p01-manifest-schema-shape.sh`

- `scripts/lifecycle/read-project-assets.sh` exists and emits one `source=<src>\ttarget=<tgt>\tmode=<copy|symlink>` line per `project_assets:` entry on stdout. The reader is the single shared seam that all three installers read; reader output is line-oriented, tab-separated, UTF-8, and stable across re-invocations against the same manifest.
  - Check: `bash tools/verify/m032-p01-reader-emits-tuples.sh`

- `packaging/install/install-claude-code.sh` no longer contains the literal token `RUNTIME_DIRS=` anywhere in the file (FR-2 — the hardcoded bulk-copy at `install-claude-code.sh:415-458` is fully replaced by the `project_assets:`-driven path). The install step iterates `read-project-assets.sh` output and dispatches to the per-mode handler. At `mode: copy` the per-target file-tree under `<PROJECT_DIR>/<target>` is byte-identical to the pre-M032 `cp -R "$src/." "$dst/"` output (CON-4 — sha256 of file-tree is the golden recorded by T04). The pre-M032 RUNTIME_DIRS reference is preserved nowhere in the installer body (no commented-out code, no fallback path).
  - Check: `bash tools/verify/m032-p01-install-cc-byte-identical.sh`

<dispatch-volatile>

## Upstream Context

No upstream summaries available.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M032"
name: "project_assets: schema in manifest + shared reader helper + per-mode handler library + collision check library (FR-1, FR-3, FR-22, additive surface only)"
depends_on: []
---

## Prerequisites

- `packaging/bundle/manifest.yml` exists with the pre-M032 schema (verified by `[ -f packaging/bundle/manifest.yml ]` and `grep -q '^schema_version:' packaging/bundle/manifest.yml`).
- `packaging/install/install-claude-code.sh` exists and contains the literal `RUNTIME_DIRS="scripts templates references commands"` at approximately line 423 (verified by `grep -q 'RUNTIME_DIRS=' packaging/install/install-claude-code.sh`). Same for `install-codex.sh:236` and `install-cursor.sh:245`.
- `scripts/lifecycle/` exists as a directory and is the canonical home for installer-lifecycle helpers (verified by `[ -d scripts/lifecycle ]`).
- `tools/verify/` exists as a directory and is the canonical home for project-owned slug-bearing verifiers per AD-19 path discipline.
- T01 entry: NONE of the three installers may be amended in this task; FR-2 migration is T02 + T03's job. T01 is purely library + manifest-schema work.

## Description

T01 ships the four additive surfaces that T02 and T03 will then dispatch through. None of the three installers is touched in this task — the `RUNTIME_DIRS` block at `install-{claude-code,codex,cursor}.sh` stays live during T01 to preserve the pre-M032 install behavior unchanged. T01's diff is reviewable in isolation: a manifest amendment, three new lifecycle helpers, and five new verifier scripts.

The four deliverables:

1. **`packaging/bundle/manifest.yml` `project_assets:` section (FR-1)** — a top-level YAML list with exactly four entries. Each entry declares `source:` (path under `<REPO_ROOT>/`), `target:` (path under `<PROJECT_DIR>/`), and `mode: copy` (default per FR-1; v1 ships only `copy` in the manifest itself — `symlink` is exercised by the test-only `--asset-mode-override` flag in P01 and becomes a manifest-declarable mode in P02+).

2. **`scripts/lifecycle/read-project-assets.sh` (FR-2 prep)** — the shared reader sourced by all three installers in T02 + T03. Reads the manifest at a caller-supplied bundle path and emits one tab-separated `source=<src>\ttarget=<tgt>\tmode=<copy|symlink>` line per entry on stdout. Pure stdout — no environment mutation, no temp files. The reader is the seam that lets T02 + T03 share migration logic without re-implementing manifest parsing.

3. **`scripts/lifecycle/install-asset-mode.sh` (FR-3 + NG-9)** — the per-mode handler invoked once per `read-project-assets.sh` tuple. Dispatches on `mode`: `copy` reproduces today's `cp -R "$src/." "$dst/"` semantics byte-identically; `symlink` resolves the symlink target as `~/.claude/orchestrator-runtime/<version>/<source-basename>` (with fallback to `<PROJECT_DIR>/.orchestrator/runtime-cache/<source-basename>` per Assumption A-1) and creates the symlink with `ln -s`. Windows fail-closed: `M032_FORCE_WINDOWS=1` OR an unavailable `ln -s` exits non-zero with the literal `POSIX-only in v1` diagnostic and writes nothing under `<PROJECT_DIR>/<target>`.

4. **`scripts/lifecycle/install-collision-check.sh` (FR-22 + MIT-006)** — the dual-oracle hierarchy invoked once per tuple BEFORE `install-asset-mode.sh` dispatches. Reads in strict order: tracking-file oracle (primary, `installed-files.txt` left-column lookup); bootstrapping oracle (MIT-006, applies when `installed-files.txt` is absent); operator-owned oracle (tertiary, fails closed naming both manifest entry and operator-owned path).

## Steps

1. **Read the existing `packaging/bundle/manifest.yml`** (37 lines). Confirm the top-level keys and their values.

2. **Amend `packaging/bundle/manifest.yml`** by appending a `project_assets:` section after the existing `runtime_compatibility:` block. The exact YAML to append:

```yaml
# project_assets:
# Project-owned runtime payload staged into <PROJECT_DIR>/<target> by the
# installer's project-asset stage (FR-1 / FR-2). Each entry is processed
# through scripts/lifecycle/install-collision-check.sh (FR-22) and then
# scripts/lifecycle/install-asset-mode.sh (FR-3). v1 ships only mode: copy
# in the manifest; mode: symlink is exercised by the --asset-mode-override
# install flag in P01 and becomes manifest-declarable in P02+ (NG-9 keeps
# Windows fail-closed regardless).
project_assets:
  - source: commands/
    target: commands/
    mode: copy
  - source: scripts/
    target: scripts/
    mode: copy
  - source: references/
    target: references/
    mode: copy
  - source: templates/
    target: templates/
    mode: copy
```

3. **Author `scripts/lifecycle/read-project-assets.sh`**. The reader takes one positional arg (bundle dir, default `packaging/bundle/`), reads `<bundle-dir>/manifest.yml`, and emits one line per `project_assets:` entry as `source=<src>\ttarget=<tgt>\tmode=<copy|symlink>` on stdout. Use `awk` (POSIX) or a manual line-walking shell loop to parse the section between `^project_assets:$` and the next top-level key (or EOF). Reject manifests where any entry is missing `source`, `target`, or `mode` (exit 2 with `FAIL: project_assets entry N missing required key <key>`). Reject manifests where `mode` is anything other than `copy` or `symlink` (exit 2 with `FAIL: project_assets entry N mode='<x>' invalid (must be copy|symlink)`). On success, exit 0; on no `project_assets:` section, exit 0 with no stdout (downstream callers treat zero-tuple emission as a no-op).

4. **Author `scripts/lifecycle/install-asset-mode.sh`**. The handler takes four args: `<src-abs-path> <dst-abs-path> <mode> <project-dir-abs>` (project-dir is needed for the runtime-cache fallback). Dispatch:
   - `mode=copy`: run `mkdir -p "$dst"` then `cp -R "$src/." "$dst/"` and emit `staged_mode=copy src=<src> dst=<dst>` on stdout. Exit 0 on success.
   - `mode=symlink`: detect Windows or absent `ln` — `if [ "${M032_FORCE_WINDOWS:-0}" = "1" ] || ! command -v ln >/dev/null 2>&1; then echo "FAIL: mode: symlink is POSIX-only in v1 (NG-9)" >&2; exit 3; fi`. Resolve the symlink target: `runtime_root="${HOME}/.claude/orchestrator-runtime"` and pick the highest-versioned subdir if present, else fall back to `<PROJECT_DIR>/.orchestrator/runtime-cache/`. Run `mkdir -p "$(dirname "$dst")"`, `rm -rf "$dst"` (idempotency — second invocation overwrites the symlink), then `ln -s "$resolved_runtime/<basename>" "$dst"` and emit `staged_mode=symlink src=<src> dst=<dst> link_target=<resolved>` on stdout.
   - Any other `mode`: exit 2 with `FAIL: install-asset-mode.sh: unknown mode '<x>'` on stderr.

5. **Author `scripts/lifecycle/install-collision-check.sh`**. The check takes three args: `<target-abs-path> <project-dir-abs> <project-assets-target-list-newline-sep>` and dispatches the FR-22 oracle hierarchy:
   - **Tracking-file oracle (primary)**: `manifest="$project_dir/.orchestrator/installed-files.txt"`. If `[ -f "$manifest" ]` AND `awk -F'\t' '{print $1}' "$manifest" | grep -Fxq "$rel_target"` (rel_target is the relative form of `<target-abs-path>` from `<project-dir-abs>`), emit `oracle=tracking-file result=framework-installed target=<rel>` and exit 0.
   - **Bootstrapping oracle (MIT-006)**: if `[ ! -f "$manifest" ]` AND the relative target appears in the project-assets target list (passed in arg 3), emit `oracle=bootstrapping result=framework-installed target=<rel> mit=MIT-006` and exit 0. The caller is responsible for writing `installed-files.txt` reflecting the bootstrapped state at the END of the install run.
   - **Operator-owned oracle (tertiary)**: if the target path pre-exists (`[ -e "$abs_target" ]`) AND it is not in the tracking file AND `git -C "$project_dir" check-ignore -- "$rel_target" >/dev/null 2>&1` exits non-zero (i.e., the path is NOT ignored — it's tracked or untracked-but-not-ignored, so plausibly operator-owned), emit `oracle=operator-owned result=collision target=<rel> manifest_entry=<rel>` on stderr and exit 4 (collision exit code reserved for FR-22). The caller's diagnostic format is the literal string `staged-dirs-collision: project_assets entry <entry> collides with operator-owned <path>`.
   - Otherwise (target does not pre-exist OR is gitignored), emit `oracle=clean result=ok target=<rel>` and exit 0.

6. **Author the five T01 verifiers** under `tools/verify/`:
   - `m032-p01-manifest-schema-shape.sh` — `grep -q '^project_assets:$' packaging/bundle/manifest.yml`; assert exactly four `^  - source: ` lines under the `project_assets:` block; assert each entry has matching `target:` and `mode: copy` lines.
   - `m032-p01-reader-emits-tuples.sh` — invoke `bash scripts/lifecycle/read-project-assets.sh packaging/bundle/`; assert stdout has exactly four lines each matching `^source=[^\t]+\ttarget=[^\t]+\tmode=copy$`.
   - `m032-p01-mode-handler-symlink.sh` — exercise both branches against a `mktemp -d`-staged fixture: copy mode produces a regular file tree; symlink mode under `M032_FORCE_WINDOWS=1` exits 3 with `POSIX-only in v1` on stderr; symlink mode without the env var produces a symlink (test by `[ -L <dst> ]`).
   - `m032-p01-installed-files-format.sh` — currently asserts only that the file format invariant is documented inline in `install-collision-check.sh` and that the install-asset-mode emit lines do NOT use spaces between path and `mode:` token (T02 ships the actual writer; T01's verifier asserts the contract documentation).
   - `m032-p01-collision-oracle.sh` — exercise all three oracle branches against `mktemp -d` fixtures: tracking-file branch (writes `installed-files.txt` then probes), bootstrapping branch (no tracking file, target in list), operator-owned branch (pre-existing target, not in tracking, not gitignored — assert exit 4 + `oracle=operator-owned` + `result=collision` on stderr).

7. **Run the five new verifiers locally** to confirm exit 0 from each.

## Must-Haves

- The `project_assets:` schema is present in `packaging/bundle/manifest.yml` per the exact YAML in step 2 (FR-1).
- `scripts/lifecycle/read-project-assets.sh` exists, is executable, and emits four `source=...\ttarget=...\tmode=copy` lines for the manifest landed in step 2.
- `scripts/lifecycle/install-asset-mode.sh` exists and supports both `copy` (byte-identical to today's `cp -R "$src/." "$dst/"`) and `symlink` (POSIX `ln -s`) with Windows fail-closed via `M032_FORCE_WINDOWS=1` (FR-3 / NG-9).
- `scripts/lifecycle/install-collision-check.sh` exists and implements all three FR-22 oracle branches with the documented exit-code contract and MIT-006 bootstrapping branch.
- All five T01 verifiers under `tools/verify/m032-p01-*.sh` exist, are executable, and exit 0 against the T01-landed surface.

## Verification

```bash
bash tools/verify/m032-p01-manifest-schema-shape.sh
bash tools/verify/m032-p01-reader-emits-tuples.sh
bash tools/verify/m032-p01-mode-handler-symlink.sh
bash tools/verify/m032-p01-installed-files-format.sh
bash tools/verify/m032-p01-collision-oracle.sh
```

## Inputs

### From Previous Tasks

None. T01 has no upstream task dependencies.

### From Disk (Pre-existing)

- `packaging/bundle/manifest.yml` — pre-M032 manifest schema with `schema_version`, `type`, `name`, `version`, `description`, `skill_spec`, `skills`, `hooks`, `config_default`, `runtime_compatibility` top-level keys. T01 amends it by appending `project_assets:` only; pre-existing keys are preserved byte-identically.
- `packaging/install/install-claude-code.sh` (read-only in T01) — lines 415-458 contain the live `RUNTIME_DIRS` loop. T01 does NOT touch this file.
- `scripts/lifecycle/` directory — canonical home for installer-lifecycle helpers (existing helpers: `init-project.sh`, `before-commit.sh`, `after-verify-sync.sh`).
- `tools/verify/` directory — canonical home for project-owned slug-bearing verifiers (per AD-19 path discipline; existing verifiers under `m030-p0*-*.sh` and `m031-p0*-*.sh` namespaces).

## Constraints

- T01 MUST NOT amend any of the three installers (`install-claude-code.sh`, `install-codex.sh`, `install-cursor.sh`). Migration is T02 + T03. The pre-M032 install behavior MUST be unchanged at T01 close.
- The manifest amendment MUST preserve every pre-existing top-level key (CON-4 byte-identical at the manifest layer).
- The reader, mode handler, and collision check libraries MUST use single-script-file shapes only — no inline compound bash, no plain subshells with sourcing, no command substitution containing pipes (AD-19). All five verifiers ship in script-file form per the `tools/verify/m032-p01-*.sh` pattern.
- Exit-code discipline: 0 = success; 2 = invalid input (malformed manifest, unknown mode); 3 = POSIX-only fail-closed (Windows symlink); 4 = FR-22 collision detected. These codes are part of the library contract T02 + T03 + T04 read against.

## Expected Output

After T01 closes, `bash tools/verify/m032-p01-manifest-schema-shape.sh && bash tools/verify/m032-p01-reader-emits-tuples.sh && bash tools/verify/m032-p01-mode-handler-symlink.sh && bash tools/verify/m032-p01-installed-files-format.sh && bash tools/verify/m032-p01-collision-oracle.sh` exits 0 and the disk state is: amended `manifest.yml` with `project_assets:` section + four runtime-dir entries; three new lifecycle helpers under `scripts/lifecycle/`; five new verifiers under `tools/verify/m032-p01-*.sh`. The three installers and the existing install behavior are byte-identical to pre-T01 — verified by running `bash packaging/install/install-claude-code.sh --dry-run --project-dir <some-fixture>` and observing the same `would_write=` lines as before T01.

## State Context

- **Current State**: executing
- **Milestone**: M032
- **Phase**: P01
- **Task**: T01-manifest-and-libraries
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- T01 MUST NOT amend any of the three installers (`install-claude-code.sh`, `install-codex.sh`, `install-cursor.sh`). Migration is T02 + T03. The pre-M032 install behavior MUST be unchanged at T01 close.
- The manifest amendment MUST preserve every pre-existing top-level key (CON-4 byte-identical at the manifest layer).
- The reader, mode handler, and collision check libraries MUST use single-script-file shapes only — no inline compound bash, no plain subshells with sourcing, no command substitution containing pipes (AD-19). All five verifiers ship in script-file form per the `tools/verify/m032-p01-*.sh` pattern.
- Exit-code discipline: 0 = success; 2 = invalid input (malformed manifest, unknown mode); 3 = POSIX-only fail-closed (Windows symlink); 4 = FR-22 collision detected. These codes are part of the library contract T02 + T03 + T04 read against.

### Acceptance Criteria

- The `project_assets:` schema is present in `packaging/bundle/manifest.yml` per the exact YAML in step 2 (FR-1).
- `scripts/lifecycle/read-project-assets.sh` exists, is executable, and emits four `source=...\ttarget=...\tmode=copy` lines for the manifest landed in step 2.
- `scripts/lifecycle/install-asset-mode.sh` exists and supports both `copy` (byte-identical to today's `cp -R "$src/." "$dst/"`) and `symlink` (POSIX `ln -s`) with Windows fail-closed via `M032_FORCE_WINDOWS=1` (FR-3 / NG-9).
- `scripts/lifecycle/install-collision-check.sh` exists and implements all three FR-22 oracle branches with the documented exit-code contract and MIT-006 bootstrapping branch.
- All five T01 verifiers under `tools/verify/m032-p01-*.sh` exist, are executable, and exit 0 against the T01-landed surface.

### Files To Touch

- `packaging/bundle/manifest.yml` (modify)
- `scripts/lifecycle/read-project-assets.sh` (create)
- `scripts/lifecycle/install-asset-mode.sh` (create)
- `scripts/lifecycle/install-collision-check.sh` (create)
- `packaging/install/install-claude-code.sh` (modify)
- `packaging/install/install-codex.sh` (modify)
- `packaging/install/install-cursor.sh` (modify)
- `tests/fixtures/m032-fresh-project-fixture/.gitignore` (create)
- `tests/fixtures/m032-fresh-project-fixture/.git-init-marker` (create)
- `tests/fixtures/m032-fresh-project-fixture/README.md` (create)
- `tools/verify/fixtures/m032-pre-m032-golden.txt` (create)
- `tests/m032-acceptance/p01-managed-bundle-shape.sh` (create)
- `tests/m032-acceptance/p01-symlink-mode.sh` (create)
- `tests/m032-acceptance/p01-staged-dirs-collision.sh` (create)
- `tools/verify/m032-p01-manifest-schema-shape.sh` (create)
- `tools/verify/m032-p01-reader-emits-tuples.sh` (create)
- `tools/verify/m032-p01-install-cc-byte-identical.sh` (create)
- `tools/verify/m032-p01-installers-parity.sh` (create)
- `tools/verify/m032-p01-mode-handler-symlink.sh` (create)
- `tools/verify/m032-p01-installed-files-format.sh` (create)
- `tools/verify/m032-p01-collision-oracle.sh` (create)
- `tools/verify/m032-p01-fixture-shape.sh` (create)
- `tools/verify/m032-p01-acceptance-shape-sc1.sh` (create)
- `tools/verify/m032-p01-acceptance-shape-sc2.sh` (create)
- `tools/verify/m032-p01-acceptance-shape-sc10.sh` (create)
- `tools/verify/m032-p01-phase-suite.sh` (create)
- `tools/verify/m032-p01-scope-guard.sh` (create)

<!-- The phase plan and task plan files (this file + tasks/T0[1-4]-*-PLAN.md)
     are written by the planner, not the executor — they are not listed here.
     The `.git/` directory inside the fixture is created by the fixture
     bootstrap procedure documented in T04's plan; T04's Steps create it on
     execution, but the directory is not a tracked artifact (it is a runtime
     state of the fixture, materialized by the bootstrap step). -->

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