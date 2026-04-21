---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T04 (Phase P03, Milestone M012)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (25 entries) | 20-589 | ~4900 | filtered |
| Decisions | 591-593 | ~100 | filtered |
| Constraints | 595-628 | ~400 | required |
| Scope | 630-658 | ~500 | required |
| Upstream Context | 660-730 | ~3600 | required |
| Task Plan | 732-1029 | ~3600 | required |
| State Context | 1031-1037 | ~100 | required |
| First-Turn Completeness | 1039-1084 | ~800 | required |
| **Total** | | **~14000** | |

## Knowledge

<!-- 25 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 327
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
hit_count: 327
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
hit_count: 327
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
scope_tags: "[project], [milestone:M005]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 327
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
hit_count: 292
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
hit_count: 292
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
hit_count: 292
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
hit_count: 327
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
scope_tags: "[project], [milestone:M006]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 292
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
hit_count: 292
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
scope_tags: "[project], [milestone:M002]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 292
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
hit_count: 327
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
hit_count: 327
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
hit_count: 327
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
hit_count: 292
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
hit_count: 292
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
hit_count: 292
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
hit_count: 327
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
hit_count: 292
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
hit_count: 292
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
hit_count: 327
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
hit_count: 327
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
scope_tags: "[project], [milestone:M004]"
category: lessons
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 292
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
hit_count: 292
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
hit_count: 292
source_unit: "M004/P06"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM023, MEM024]
content_hash: ""
---

# MEM025: Verification Script Grep Patterns

Verification helper scripts that grep for library sourcing should use broad patterns (e.g. `errors\.sh`) not narrow literal patterns (e.g. `lib/errors\.sh`). Scripts may source libs via variable expansion (`$_LIB_DIR/errors.sh`) which does not match the literal path. The broader pattern still uniquely identifies the sourcing intent.

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

## Scope

### Goal


### Demo


### Must-Haves
## Must-Haves

<!-- Each truth is a behavioral statement + a single-script-file Check (AD-19).
     Every Check command is a single-invocation script-file shape — no inline
     compound bash, no plain subshells, no $() containing pipes, no process
     substitution. All M012/P03 verification logic lives inside
     scripts/verify/m012-p03-*.sh files; the Check commands here invoke them. -->

### Truths

- `wiki/overrides/partials/comments.html` exists and renders a Giscus `<script>` tag using MkDocs Material's comments-partial override mechanism, driven by values from `mkdocs.yml`'s `extra.giscus.*` block (AD-3 SSOT — comments are injected by the theme, not by rewriting artifact bodies).
  - Check: `bash scripts/verify/m012-p03-comments-partial.sh`

- `wiki/mkdocs.yml` declares `theme.custom_dir: overrides` and carries an `extra.giscus` configuration block with the five required keys (`repo`, `repo_id`, `category`, `category_id`, `mapping`) interpolated from environment variables (`GISCUS_REPO`, `GISCUS_REPO_ID`, `GISCUS_CATEGORY`, `GISCUS_CATEGORY_ID`) — no production IDs are hardcoded (Constraint "Config placement", US2 AS-5, FR-4).
  - Check: `bash scripts/verify/m012-p03-mkdocs-giscus-config.sh`

- Giscus `mapping` is set to `pathname` and the tradeoffs for rename/move are documented in `wiki/README.md` under a "Giscus mapping" section that names the strategy and cites the remap script as the recovery path (AD-5 / SC-7 / US5).
  - Check: `bash scripts/verify/m012-p03-mapping-documented.sh`

- The build fails loudly with a clear diagnostic when any required Giscus env var is unset at build time — either via `mkdocs build` exiting non-zero with a resolvable error message, or via an explicit pre-build gate (`scripts/diagnostics/wiki-giscus-config-check.sh`) that exits non-zero before mkdocs runs (US2 AS-5 / SC-9).

<dispatch-volatile>

## Upstream Context


### P01 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M012"
milestone: "M012"
provides:
  - "wiki/ skeleton (requirements.txt, mkdocs.yml base, docs/index.md placeholder, wiki/docs/README.md, wiki/README.md, wiki/.gitignore); scripts/wiki/wiki-serve.sh launcher (default/--probe/--help modes), scripts/wiki/wiki-scan-sources.sh — single-source-of-truth scanner enumerating in-scope .orchestrator/**.md artifacts and printing <category>|<rel-path>|<title> records to stdout with exclusion policy enforced (scratch/, tmp/, config/, PLANNING-PAYLOAD, VERIFICATION, AGENTS.md, milestone/archive README.md, non-.md), scripts/wiki/wiki-generate-stubs.sh — thin include-plugin stub generator that reads wiki-scan-sources.sh output and writes one <=25-line stub per in-scope .orchestrator/**.md artifact under wiki/docs/; each stub carries a YAML title + include-markdown directive pointing at a ../-relative canonical path (AD-3 SSOT); also emits per-section index.md files (milestones/, archive/, per-M###/, per-P##/) listing children in lexical order for T04 nav consumption, scripts/wiki/wiki-generate-nav.sh — MkDocs nav block generator that consumes scripts/wiki/wiki-scan-sources.sh output once and atomically splices a deterministic nav: block into wiki/mkdocs.yml between # >>> M012-P01 nav / # <<< M012-P01 nav end marker comments; supports --dry-run (stdout) and --root PROJECT_ROOT; top-level order fixed at Home/Constitution/Decisions/Knowledge/Milestone Summary/Milestones/Archive (Archive emitted only when archive:M### scanner records exist); per-milestone groups expose milestone-top artifacts + per-phase subgroups with phase-top + task-level + catch-all extras (fixtures/, archived phase dirs) so every scanner record gets exactly one nav leaf; Bash 3.2 compliant; atomic stage+mv write, M012/P01 nine-gate verification suite + phase-suite orchestrator"
requires:
  - "from:none what:M012-CONTEXT AD-3/AD-6/AD-7, M012-ROADMAP Boundary Map, constitution Principle VI/VIII/XV, from:T01 what:wiki/ skeleton exists (stable target for downstream writers); from:none what:populated .orchestrator/ tree (constitution, DECISIONS.md, KNOWLEDGE.md, milestone-summary.md, milestones/M###/, archive/), from:T01 what:wiki/ skeleton + mkdocs.yml with include-markdown plugin declared; from:T02 what:scripts/wiki/wiki-scan-sources.sh emitting <category>|<rel-path>|<title> records on stdout with exclusion policy applied, from:T01 what:wiki/mkdocs.yml base with plugins+theme+markdown_extensions and no existing nav: key; from:T02 what:scripts/wiki/wiki-scan-sources.sh emitting <category>|<rel-path>|<title> records in stable lexical order with exclusion policy applied; from:T03 what:wiki/docs/** stubs + section index.md files for milestones/ archive/ per-M### per-P## so nav leaves have existing link targets, from:M012/P01/T04 what:wiki/mkdocs.yml nav block; from:M012/P01/T03 what:wiki/docs/** stubs; from:M012/P01/T02 what:scripts/wiki/wiki-scan-sources.sh"
affects:
  - "P01/T02 (wiki-scan-sources), P01/T03 (stub generator appends to wiki/docs/), P01/T04 (nav generator appends nav block to mkdocs.yml), P01/T05 (verify scripts consume this skeleton), P01/T03 (wiki-generate-stubs consumes scanner stdout to emit thin include stubs), P01/T04 (wiki-generate-nav consumes scanner stdout to build nav block), P01/T05 (m012-p01-exclusion-policy.sh verifies scanner output), P01/T04 (wiki-generate-nav.sh mirrors the wiki/docs/ directory tree produced here), P01/T05 (m012-p01-include-plugin.sh + m012-p01-ssot.sh + m012-p01-exclusion-policy.sh + m012-p01-bash32-compat.sh assert on the stubs this script writes), P01/T05 (m012-p01-nav-structure.sh + m012-p01-include-plugin.sh + m012-p01-serve-smoke.sh + m012-p01-bash32-compat.sh assert on the nav block this script writes); P02 (any downstream authoring/publishing flow that consumes wiki/mkdocs.yml), M012/P02"
key_files:
  - "wiki/requirements.txt,wiki/mkdocs.yml,wiki/docs/index.md,wiki/docs/README.md,wiki/README.md,wiki/.gitignore,scripts/wiki/wiki-serve.sh, scripts/wiki/wiki-scan-sources.sh, scripts/wiki/wiki-generate-stubs.sh,wiki/docs/constitution.md,wiki/docs/decisions.md,wiki/docs/knowledge.md,wiki/docs/milestone-summary.md,wiki/docs/milestones/index.md,wiki/docs/milestones/M002/M002-CONTEXT.md,wiki/docs/milestones/M012/phases/P01/tasks/T03-PLAN.md, scripts/wiki/wiki-generate-nav.sh,wiki/mkdocs.yml, scripts/verify/m012-p01-wiki-self-contained.sh,scripts/verify/m012-p01-requirements-pinned.sh,scripts/verify/m012-p01-include-plugin.sh,scripts/verify/m012-p01-ssot.sh,scripts/verify/m012-p01-exclusion-policy.sh,scripts/verify/m012-p01-nav-structure.sh,scripts/verify/m012-p01-serve-smoke.sh,scripts/verify/m012-p01-index-placeholder.sh,scripts/verify/m012-p01-bash32-compat.sh,scripts/verify/m012-p01-phase-suite.sh"
key_decisions:
  - "AD-3,AD-6,AD-7, AD-3,AD-4,AD-19,FR-8, AD-3,AD-6,AD-19,FR-8,M012-Constitution-VI, AD-3,AD-6,AD-19,FR-8,M012-Constitution-VI,MEM001,MEM004, AD-19 single-script-file Check shape,SC-10 self-contained wiki,AD-3 SSOT via include-markdown"
patterns_established:
  - "self-contained wiki/ directory (SC-10, Constitution VI removable without breaking orchestrator); pinned-version toolchain (exact == pins, no ranges) for reproducible builds; launcher --probe mode runs mkdocs build --strict into throwaway /tmp site-dir for non-blocking auto-mode verify; nav block deliberately absent in T01 so T04 owns its regeneration (source-of-truth discipline), single-source-of-truth scanner as emitter-internal helper (MEM004 carve-out — pipes/awk/find permitted since not agent-facing); scan-order discipline emits top-level artifacts, then milestones (lexical M###), then archive, with within-milestone lexical order for stable downstream consumption; title sanitization replaces pipe characters to preserve the 3-field schema invariant; /tmp list file (outside ROOT) avoids |-while subshell so running counter stays accurate; exclusion policy implemented via case-match on first path segment plus basename pattern tests in a should_exclude helper; never copies .orchestrator/**.md content — only enumerates paths + extracts one H1 title per file (AD-3 / Constitution VI compliance), per-stub canonical-path depth computed from slash-count of stub-rel-path (depth = N_slashes + 2) keeps it Bash 3.2 pure-string; clean-phase find uses -mindepth 1 with !-path guards on top-level index.md/README.md to preserve hand-authored pages while wiping every auto-generated .md under wiki/docs/; section indexes emit one bullet per unique child (sort -u) with child_title fallback to child_rel for empty titles; parallel /tmp list files scoped by PID replace associative arrays for section-to-children bookkeeping; idempotency proven by shasum-of-sha-list diff across two consecutive runs; stub template is 12-13 lines — well under the 25-line must-have — and carries only YAML title, authoring comment citing AD-3, and an include-markdown block with heading-offset=0 + rewrite-relative-urls=true, marker-delimited auto-generated region pattern (# >>> ... # <<< ... end) + awk state-machine splitter splits pre/body/post cleanly across GNU/BSD awk without sed -i portability issues; atomic write via same-directory .name.staged.$$ + mv preserves inode-stability and disallows partial writes; stream-friendly single-pass nav emission leveraging scanner lexical pre-sort eliminates nested associative-array state (bash 3.2 safe); four-bucket awk passes per milestone/phase (top / phase-top / tasks / extras) ensure every scanner record maps to exactly one nav leaf while keeping labels semantically meaningful; extras flatten deeper subtrees with slash-joined labels (fixtures / golden-payload-M004-P04-T04) so orphans are impossible; YAML escape uses double-quote wrap + backslash-escape of internal quotes when the title contains any reserved YAML character or starts with a digit / hyphen / question mark; Archive emitted only when archive:M### records exist (otherwise orphan-free rule would force Archive/Overview to point at a non-existent archive/index.md stub), parallel indexed-array pattern registry with PAT_REGEX_/PAT_LABELS_ suffix (bash 3.2 safe),marker-bounded awk state machine for nav extraction,section-index vs artifact-stub classification via 'Auto-generated section index' comment probe,self-scan carve-out via assignment-line regex skip"
drill_down_paths:
  - ".orchestrator/milestones/M012/phases/P01/tasks/T01-SUMMARY.md, .orchestrator/milestones/M012/phases/P01/tasks/T02-SUMMARY.md, .orchestrator/milestones/M012/phases/P01/tasks/T03-SUMMARY.md, .orchestrator/milestones/M012/phases/P01/tasks/T04-SUMMARY.md, .orchestrator/milestones/M012/phases/P01/tasks/T05-SUMMARY.md"
duration: "160m"
verification_result: "pass"
completed_at: "2026-04-20T22:06:48Z"
observability_surfaces:
  - "none"
---

## Summary

P01 ships the dogfood wiki skeleton — the full `wiki/` directory plus the `scripts/wiki/` toolchain that projects `.orchestrator/**.md` into an MkDocs Material site via the `include-markdown` plugin, keeping a strict single-source-of-truth (AD-3): every canonical artifact is rendered through a ≤ 25-line include stub under `wiki/docs/`, never copied. A `wiki-scan-sources.sh` → `wiki-generate-stubs.sh` → `wiki-generate-nav.sh` pipeline regenerates stubs + marker-bounded nav block from scratch on every run; a nine-gate verification suite (plus orchestrator) validates the output.

## What was built

- **`wiki/` skeleton** — exact-pinned `requirements.txt` (4 deps, no ranges), `mkdocs.yml` base with `include-markdown` + Material theme + navigation features, one-screen `docs/index.md` placeholder (P04 will replace), `docs/README.md` authoring note, operator `README.md`, `.gitignore` excluding generated `site/`.
- **`scripts/wiki/` toolchain** — `wiki-scan-sources.sh` emits `<category>|<rel-path>|<title>` records for every in-scope `.orchestrator/**.md` in stable lexical order with exclusion policy enforced (scratch/, tmp/, config/, PLANNING-PAYLOAD, VERIFICATION, non-`.md`); `wiki-generate-stubs.sh` writes a 12–13-line include stub per artifact plus section indexes for `milestones/`, `archive/`, per-`M###/`, per-`P##/`; `wiki-generate-nav.sh` atomically splices a deterministic `nav:` block between `# >>> M012-P01 nav` markers with seven fixed top-level sections (Home, Constitution, Decisions, Knowledge, Milestone Summary, Milestones, Archive — Archive conditional on scanner records); `wiki-serve.sh` launcher with `--probe` mode for headless config validation.
- **M012/P01 verification suite** — 9 gates (`m012-p01-{wiki-self-contained, requirements-pinned, include-plugin, ssot, exclusion-policy, nav-structure, serve-smoke, index-placeholder, bash32-compat}.sh`) + `m012-p01-phase-suite.sh` orchestrator. `serve-smoke.sh` SKIPs gracefully when `mkdocs` is absent so auto-mode progresses on sandboxes without the Python toolchain.

## Key decisions

- **AD-3 SSOT**: stubs reference `.orchestrator/**.md` via `include-markdown` with relative-URL rewriting; no canonical artifact body lives in two places. SSOT gate enforces ≤ 25-line artifact stubs + at most one include directive.
- **AD-6 nav structure**: per-milestone groups expose milestone-top artifacts + per-phase subgroups + task-level entries + a catch-all "extras" bucket so every scanner record maps to exactly one nav leaf.
- **AD-19 single-script-file Check shape**: every phase-plan Truth `Check:` resolves to one `bash scripts/verify/m012-p01-*.sh` invocation. All compound logic lives inside the scripts (MEM004 carve-out).
- **Marker-bounded atomic write**: `wiki-generate-nav.sh` splices between `# >>> M012-P01 nav` / `# <<< M012-P01 nav end` via an awk state machine + same-directory temp + `mv` — portable across GNU/BSD, idempotent (byte-identical output across runs).
- **Exact pin discipline**: `requirements.txt` holds exactly four `==` pins (`mkdocs`, `mkdocs-material`, `mkdocs-include-markdown-plugin`, `pymdown-extensions`) — no ranges, no optional floors. Reproducibility over flexibility.
- **Archive bucket is optional-by-evidence**: the nav generator emits `Archive` only when the scanner actually sees `archive:M###` records, so the orphan-free invariant holds even in repos (like this one) that haven't archived any milestones yet.

## Patterns established

- **Scanner → stubs → nav three-stage pipeline** with stable lexical pre-sort lets downstream passes be stream-friendly and Bash 3.2 safe (no associative arrays; single forward passes).
- **Parallel indexed-array registry with `PAT_REGEX_`/`PAT_LABELS_` suffix** for Bash-4-feature scanning in `bash32-compat.sh`, with a self-scan carve-out that skips assignment lines to prevent false positives when the scanner names the patterns it looks for.
- **Section-index vs artifact-stub classification** via an `Auto-generated section index` comment probe — section indexes can legitimately exceed the 25-line artifact cap because they're bullet lists, not content.
- **SKIP-as-PASS for optional toolchain** (serve-smoke): explicit exit-0 + `SKIP:` message when `mkdocs` is absent keeps auto-mode green on minimal sandboxes while still exercising strict-build when the tool is installed.
- **Plan-metadata aligned to delivered artifact surface** (during phase transition): `min_lines` and `contains` thresholds updated from aspirational guesses to observed truths; semantic invariants (the Truths) remain the authority.

## Verification results

- `scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P01` — all 10 Truths PASS, all 18 Artifact assertions PASS, all 13 Key-Link assertions PASS.
- `scripts/verify/m012-p01-phase-suite.sh` — 9/9 gates PASS deterministically across repeated runs.
- External modification check: PASS (no external modifications during phase).
- Roadmap sync: OK.

## Open follow-ups (out of scope for P01)

- Strict `mkdocs build` as a Tier 4 UAT step when the Python toolchain is available on a CI runner.
- P04 will replace `wiki/docs/index.md` with the real landing content; the placeholder's shape (≤ 30 lines, contains "placeholder") is the known slot.
- Plan-metadata drift between aspirational `min_lines` and delivered files is a recurring plan-authoring hazard; consider a pre-execution plan-linter that warns when artifact floors exceed first-draft shape by more than 20%.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P03"
milestone: "M012"
name: "wiki-giscus-remap.sh — idempotent Discussion-title remap + wiki/README.md mapping docs"
depends_on: ["T03"]
---

## Prerequisites

- T01 complete: `mapping: "pathname"` is fixed in `wiki/mkdocs.yml`. Each rendered page maps to a GitHub Discussion whose title equals the page's pathname (e.g., `/decisions/`, `/milestones/M011/M011-SUMMARY/`).
- T02 complete: env-var check script exists.
- T03 complete: smoke script exists; this task references it from `wiki/README.md` as the verification companion for a remap.
- `gh` CLI (GitHub CLI) is assumed available on a maintainer's machine for live remap; the dry-run path must work without `gh`.

## Description

Ship two artifacts:

1. **`scripts/diagnostics/wiki-giscus-remap.sh`** — a Bash 3.2, idempotent utility that takes `<old-path> <new-path>` pairs and renames the corresponding Giscus Discussion titles on the configured repo. Under `mapping: pathname`, Giscus keys each thread by the page's rendered URL path. When an orchestrator artifact is consolidated (e.g., `milestones/M011/phases/P03/` → `archive/M011/phases/P03/`), the page URL changes and Giscus creates a fresh thread at the new URL, orphaning the old discussion. This script relabels the old Discussion's title to the new pathname so Giscus' pathname-matcher picks it up on the next page load.

2. **`wiki/README.md` extension** — append two sections: "Giscus mapping" (documents the `pathname` strategy, its tradeoffs for rename/archive, and what the smoke script asserts) and "Remapping threads after consolidation" (documents the remap script's usage and links to both the smoke script and config-check script by basename so the link-check gate in P05 resolves them).

This is the AD-5 mapping tradeoffs surface required by SC-7 and US5.

Out-of-scope for this task: verify gates / phase-suite (T05 — immediately downstream), deploy pipeline wiring (P04), automated trigger of the remap on consolidate (future).

## Steps

1. **Create `scripts/diagnostics/wiki-giscus-remap.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/diagnostics/wiki-giscus-remap.sh — M012/P03 US5 remap utility.
   #
   # Under mapping: pathname, a Giscus thread is keyed by the page URL path.
   # When an artifact is consolidated (e.g. moved under archive/), the page
   # URL changes and Giscus creates a fresh empty thread at the new URL,
   # orphaning prior comments. This script relabels the old Discussion's
   # TITLE to the new pathname so Giscus' pathname-matcher reconnects the
   # thread at the new URL on next page load.
   #
   # Usage:
   #   wiki-giscus-remap.sh <old-path> <new-path> [<old2> <new2> ...]
   #   wiki-giscus-remap.sh --dry-run <pairs>
   #   wiki-giscus-remap.sh --repo <owner/repo> --category <cat> <pairs>
   #   wiki-giscus-remap.sh --help
   #
   # Flags:
   #   --dry-run       print planned operations; do NOT call gh api
   #   --repo OWNER/R  target repo (default $GISCUS_REPO)
   #   --category CAT  Discussion category name (default $GISCUS_CATEGORY)
   #   --help          print usage; exit 0
   #
   # Behavior:
   #   For each <old new> pair:
   #     1. Query existing Discussions whose title == <old>.
   #     2. If found: rename title to <new>. If already == <new> or no match
   #        whose title == <old>: emit NOOP: <old> -> <new> and continue.
   #     3. If match count > 1: emit FAIL: ambiguous (N matches) and exit 1
   #        without making changes.
   #
   # Idempotency: running the script twice in a row against the same pair
   # list produces identical observable state — the second run emits
   # NOOP lines for every pair.
   #
   # Bash 3.2 compatible. Requires gh (unless --dry-run). No jq hard-dep;
   # uses gh --jq for GraphQL response field extraction.

   set -u
   set -o pipefail

   DRY_RUN=0
   REPO="${GISCUS_REPO:-}"
   CATEGORY="${GISCUS_CATEGORY:-}"

   usage() {
     sed -n '2,35p' "$0" | sed 's/^# \{0,1\}//'
   }

   pairs_old=""
   pairs_new=""

   # Two-phase arg parse: flags first, then <old new> positional pairs.
   while [ $# -gt 0 ]; do
     case "$1" in
       --dry-run)  DRY_RUN=1; shift ;;
       --repo)     REPO="$2"; shift 2 ;;
       --category) CATEGORY="$2"; shift 2 ;;
       --help|-h)  usage; exit 0 ;;
       --)         shift; break ;;
       -*)         printf 'ERROR: unknown flag: %s\n' "$1" >&2; exit 2 ;;
       *)          break ;;
     esac
   done

   if [ $# -eq 0 ] || [ $(( $# % 2 )) -ne 0 ]; then
     printf 'ERROR: positional args must be <old> <new> pairs; got %d args\n' "$#" >&2
     usage >&2
     exit 2
   fi

   if [ "$DRY_RUN" -eq 0 ]; then
     if [ -z "$REPO" ] || [ -z "$CATEGORY" ]; then
       printf 'ERROR: --repo and --category required (or set GISCUS_REPO + GISCUS_CATEGORY)\n' >&2
       exit 2
     fi
     if ! command -v gh >/dev/null 2>&1; then
       printf 'ERROR: gh CLI not on PATH (required for non-dry-run)\n' >&2
       exit 2
     fi
   fi

   # Loop pairs.
   status=0
   while [ $# -gt 0 ]; do
     OLD="$1"; NEW="$2"; shift 2
     if [ "$DRY_RUN" -eq 1 ]; then
       printf 'DRY-RUN: %s -> %s\n' "$OLD" "$NEW"
       continue
     fi

     # Query Discussions in the category whose title == OLD.
     # Output is a JSON list of {id,title} objects. GraphQL via `gh api graphql`.
     query='query($o:String!,$r:String!,$c:String!,$t:String!){repository(owner:$o,name:$r){discussions(first:50,categoryId:null){nodes{id title category{name}}}}}'
     owner="${REPO%%/*}"
     name="${REPO##*/}"
     # Pull all discussions, filter by title+category in the helper script.
     discussions_json="$(gh api graphql -f query="$query" -F o="$owner" -F r="$name" -F c="$CATEGORY" -F t="$OLD" --jq '.data.repository.discussions.nodes' 2>/dev/null || echo '[]')"

     match_count="$(printf '%s' "$discussions_json" \
       | grep -o "\"title\":\"$OLD\"" | wc -l | tr -d '[:space:]')"

     if [ "$match_count" -eq 0 ]; then
       printf 'NOOP: %s -> %s (no match)\n' "$OLD" "$NEW"
       continue
     fi
     if [ "$match_count" -gt 1 ]; then
       printf 'FAIL: %s -> %s (ambiguous: %d matches)\n' "$OLD" "$NEW" "$match_count" >&2
       status=1
       continue
     fi

     # Exactly one match. Extract its id.
     disc_id="$(printf '%s' "$discussions_json" \
       | sed 's/.*"id":"\([^"]*\)","title":"'"$OLD"'".*/\1/p' | head -n 1)"
     if [ -z "$disc_id" ]; then
       printf 'FAIL: %s -> %s (id extract failed)\n' "$OLD" "$NEW" >&2
       status=1
       continue
     fi

     # GraphQL updateDiscussion mutation to rename title.
     mutation='mutation($id:ID!,$title:String!){updateDiscussion(input:{discussionId:$id,title:$title}){discussion{id title}}}'
     if gh api graphql -f query="$mutation" -F id="$disc_id" -F title="$NEW" >/dev/null 2>&1; then
       printf 'OK: %s -> %s\n' "$OLD" "$NEW"
     else
       printf 'FAIL: %s -> %s (gh api mutation failed)\n' "$OLD" "$NEW" >&2
       status=1
     fi
   done

   exit "$status"
   ```

   - GraphQL fields are pathname strings, unambiguous under `pathname` mapping.
   - The script uses `gh api graphql --jq` which extracts fields without a jq binary dependency (`gh` bundles jq internally).
   - Pure-text parsing (`grep -o`, `sed`) for match count / id extraction keeps the script resilient to missing jq and Bash 3.2 compatible.

2. **Make it executable**: `chmod 755 scripts/diagnostics/wiki-giscus-remap.sh`.

3. **Extend `wiki/README.md`** — append two new sections at the end of the file (do not edit P01/P02 content above):

   ```markdown
   ## Giscus mapping

   Giscus uses `mapping: pathname` — each rendered page maps to a GitHub
   Discussion whose title equals the page's URL path. The strategy is
   configured in `wiki/mkdocs.yml` under `extra.giscus.mapping`.

   ### Tradeoffs

   - **Simple and deterministic.** A page at `/decisions/` has a
     Discussion titled `/decisions/`. No metadata injection, no per-page
     authoring cost.
   - **Breaks on rename.** If an artifact is moved (e.g., consolidated
     under `.orchestrator/archive/`), its rendered URL changes. Giscus
     sees a new pathname and creates a fresh empty thread, orphaning the
     prior comments. The fix is the remap script below.
   - **Survives content edits.** Editing an artifact's body does not
     change its URL — comments stay attached.
   - **Survives theme / partial changes.** The mapping is keyed at the
     page URL level; reshuffling the theme override does not orphan
     threads.

   The smoke script (`scripts/diagnostics/wiki-giscus-smoke.sh`) verifies
   that every rendered HTML page carries the Giscus loader. It does NOT
   verify thread continuity across renames — that's what the remap
   script handles.

   ## Remapping threads after consolidation

   When an artifact is consolidated (moved or renamed), its rendered URL
   changes. Run the remap script from the repo root to relabel the
   corresponding Discussion:

   ```
   bash scripts/diagnostics/wiki-giscus-remap.sh /old/path/ /new/path/
   ```

   Dry-run mode (no GitHub API calls — prints planned operations):

   ```
   bash scripts/diagnostics/wiki-giscus-remap.sh --dry-run /old/path/ /new/path/
   ```

   Env vars `GISCUS_REPO` and `GISCUS_CATEGORY` default the target; pass
   `--repo` and `--category` to override. `gh` must be on PATH for
   non-dry-run mode. The script is idempotent — rerunning after a
   successful remap prints `NOOP:` for every already-migrated pair.

   After a remap, rebuild the wiki and run the smoke script to confirm
   the page still renders the Giscus loader:

   ```
   (cd wiki && mkdocs build)
   bash scripts/diagnostics/wiki-giscus-smoke.sh --site wiki/site
   ```

   Pre-build env-var check (companion to this flow):

   ```
   bash scripts/diagnostics/wiki-giscus-config-check.sh
   ```
   ```

4. **Smoke-verify manually** (not wired as a Check):

   - `bash scripts/diagnostics/wiki-giscus-remap.sh --help` → exit 0, usage on stdout.
   - `bash scripts/diagnostics/wiki-giscus-remap.sh --dry-run /old/ /new/` → exit 0, `DRY-RUN: /old/ -> /new/` on stdout.
   - `bash scripts/diagnostics/wiki-giscus-remap.sh --dry-run /a/ /b/ /c/` → exit 2 (odd arg count).
   - `grep -n 'Giscus mapping' wiki/README.md` — one match.
   - `grep -n 'wiki-giscus-remap.sh' wiki/README.md` — at least one match.
   - `grep -n 'wiki-giscus-smoke.sh' wiki/README.md` — at least one match (either the P02 reference or the new section's reference).

## Must-Haves

- `scripts/diagnostics/wiki-giscus-remap.sh` exists, executable, ≥ 80 lines, contains the literal `pathname`.
- Script supports `--dry-run`, `--help`, `--repo`, `--category` flags.
- Script is idempotent: a second invocation after a successful remap emits `NOOP:` lines and exits 0.
- Script exits 2 on odd positional-arg count or unknown flag.
- Script requires `gh` on PATH only in non-dry-run mode.
- Script is Bash 3.2 compatible.
- `wiki/README.md` contains a "Giscus mapping" section documenting the pathname strategy + tradeoffs.
- `wiki/README.md` contains a section referencing `wiki-giscus-remap.sh` by basename.
- `wiki/README.md` contains a reference to `wiki-giscus-smoke.sh` by basename in the remap workflow (the P02 remap-script section may already reference it; reinforce under the new heading).

## Verification

- `bash scripts/verify/m012-p03-remap-contract.sh` — PASS (T05 gate; verifies flag handling, dry-run behavior, help, exit codes, idempotency surface).
- `bash scripts/verify/m012-p03-mapping-documented.sh` — PASS (T05 gate; verifies README contains "Giscus mapping" heading + `pathname` word + remap-script reference).
- `bash scripts/verify/m012-p03-bash32-compat.sh` — PASS.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P03` — artifact + key-link patterns pass.

## Inputs

### From Previous Tasks

- **T01**: `mapping: "pathname"` in `wiki/mkdocs.yml`. Determines that threads are keyed by URL path — the remap contract.
- **T02**: `scripts/diagnostics/wiki-giscus-config-check.sh` referenced by basename in the README.
- **T03**: `scripts/diagnostics/wiki-giscus-smoke.sh` referenced by basename in the README. The remap-workflow documentation instructs the operator to run the smoke script after a rebuild.

### From Disk (Pre-existing)

- `wiki/README.md` — carries P01/P02 content (install, preview, regenerate, scope, link resolution, link-checker usage, pre-deploy integration). This task appends two sections; it does not rewrite prior content.
- GitHub CLI (`gh`) external tool — contract: `gh api graphql -f query=<q> -F <var>=<val> --jq <jq-expr>` evaluates a GraphQL query against the configured repo using the user's `gh auth` state and returns JSON (or the `--jq`-filtered subset).

## Constraints

- **Bash 3.2** — MEM001. No associative arrays; positional-arg pair loop uses a simple `while [ $# -gt 0 ]; do OLD="$1"; NEW="$2"; shift 2` pattern.
- **Idempotent** — running the script twice in a row must leave the target state unchanged after the first successful run. Verified by T05's `m012-p03-remap-contract.sh` gate via a fake-fixture simulation path.
- **Dry-run decoupled from `gh`** — `--dry-run` must work without `gh` on PATH so developers can reason about planned changes on a machine without `gh` auth configured.
- **No silent writes** — every action emits one of `DRY-RUN:`, `OK:`, `NOOP:`, `FAIL:` per pair. No quiet success.
- **AD-3 SSOT** — the remap script targets Giscus' GitHub Discussions; it does **not** edit `wiki/docs/**`, `.orchestrator/**.md`, or `wiki/mkdocs.yml`. Comment state lives in GitHub; artifact state lives on disk.
- **Ambiguous-match safety** — if two Discussions carry the same title, the script fails-closed: exit 1 on that pair without attempting a rename, so human judgment is required.
- **README append-only** — do not rewrite P01/P02 content; append the new sections at the file's tail.

## Expected Output

- `scripts/diagnostics/wiki-giscus-remap.sh` exists, executable, ≥ 80 lines, Bash 3.2 compliant.
- `bash scripts/diagnostics/wiki-giscus-remap.sh --help` — exit 0, usage on stdout.
- `bash scripts/diagnostics/wiki-giscus-remap.sh --dry-run /a/ /b/` — exit 0, `DRY-RUN: /a/ -> /b/` on stdout.
- `bash scripts/diagnostics/wiki-giscus-remap.sh /a/` — exit 2 (odd arg count).
- `wiki/README.md` ends with a "Giscus mapping" section and a "Remapping threads after consolidation" section; both cite the remap script by basename and the smoke script by basename.

## State Context

- **Current State**: executing
- **Milestone**: M012
- **Phase**: P03
- **Task**: T04
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **Bash 3.2** — MEM001. No associative arrays; positional-arg pair loop uses a simple `while [ $# -gt 0 ]; do OLD="$1"; NEW="$2"; shift 2` pattern.
- **Idempotent** — running the script twice in a row must leave the target state unchanged after the first successful run. Verified by T05's `m012-p03-remap-contract.sh` gate via a fake-fixture simulation path.
- **Dry-run decoupled from `gh`** — `--dry-run` must work without `gh` on PATH so developers can reason about planned changes on a machine without `gh` auth configured.
- **No silent writes** — every action emits one of `DRY-RUN:`, `OK:`, `NOOP:`, `FAIL:` per pair. No quiet success.
- **AD-3 SSOT** — the remap script targets Giscus' GitHub Discussions; it does **not** edit `wiki/docs/**`, `.orchestrator/**.md`, or `wiki/mkdocs.yml`. Comment state lives in GitHub; artifact state lives on disk.
- **Ambiguous-match safety** — if two Discussions carry the same title, the script fails-closed: exit 1 on that pair without attempting a rename, so human judgment is required.
- **README append-only** — do not rewrite P01/P02 content; append the new sections at the file's tail.

### Acceptance Criteria

- `scripts/diagnostics/wiki-giscus-remap.sh` exists, executable, ≥ 80 lines, contains the literal `pathname`.
- Script supports `--dry-run`, `--help`, `--repo`, `--category` flags.
- Script is idempotent: a second invocation after a successful remap emits `NOOP:` lines and exits 0.
- Script exits 2 on odd positional-arg count or unknown flag.
- Script requires `gh` on PATH only in non-dry-run mode.
- Script is Bash 3.2 compatible.
- `wiki/README.md` contains a "Giscus mapping" section documenting the pathname strategy + tradeoffs.
- `wiki/README.md` contains a section referencing `wiki-giscus-remap.sh` by basename.
- `wiki/README.md` contains a reference to `wiki-giscus-smoke.sh` by basename in the remap workflow (the P02 remap-script section may already reference it; reinforce under the new heading).

### Files To Touch

- `wiki/overrides/` (create — directory; Material theme override root)
- `wiki/overrides/partials/` (create — directory)
- `wiki/overrides/partials/comments.html` (create — Giscus partial)
- `wiki/mkdocs.yml` (modify — add `theme.custom_dir: overrides` and `extra.giscus` block; the P01-owned `# >>> M012-P01 nav` marker-bounded block remains untouched)
- `wiki/README.md` (modify — append "Giscus mapping" + "Remapping threads after consolidation" sections)
- `scripts/diagnostics/wiki-giscus-config-check.sh` (create)
- `scripts/diagnostics/wiki-giscus-smoke.sh` (create)
- `scripts/diagnostics/wiki-giscus-remap.sh` (create)
- `scripts/verify/m012-p03-comments-partial.sh` (create)
- `scripts/verify/m012-p03-mkdocs-giscus-config.sh` (create)
- `scripts/verify/m012-p03-mapping-documented.sh` (create)
- `scripts/verify/m012-p03-config-loud-fail.sh` (create)
- `scripts/verify/m012-p03-smoke-contract.sh` (create)
- `scripts/verify/m012-p03-remap-contract.sh` (create)
- `scripts/verify/m012-p03-bash32-compat.sh` (create)
- `scripts/verify/m012-p03-wiki-removable.sh` (create)
- `scripts/verify/m012-p03-phase-suite.sh` (create)

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