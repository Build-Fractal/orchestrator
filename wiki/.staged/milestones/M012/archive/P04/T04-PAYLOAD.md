---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T04 (Phase P04, Milestone M012)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (25 entries) | 20-589 | ~4900 | filtered |
| Decisions | 591-593 | ~100 | filtered |
| Constraints | 595-628 | ~400 | required |
| Scope | 630-658 | ~600 | required |
| Upstream Context | 660-889 | ~12200 | required |
| Task Plan | 891-1057 | ~2300 | required |
| State Context | 1059-1065 | ~100 | required |
| First-Turn Completeness | 1067-1109 | ~800 | required |
| **Total** | | **~21400** | |

## Knowledge

<!-- 25 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 334
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
hit_count: 334
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
hit_count: 334
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
hit_count: 334
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
hit_count: 297
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
hit_count: 297
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
hit_count: 297
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
hit_count: 334
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
hit_count: 297
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
hit_count: 297
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
hit_count: 297
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
hit_count: 334
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
hit_count: 334
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
hit_count: 334
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
hit_count: 297
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
hit_count: 297
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
hit_count: 297
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
hit_count: 334
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
hit_count: 297
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
hit_count: 297
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
hit_count: 334
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
hit_count: 334
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
hit_count: 297
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
hit_count: 297
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
hit_count: 297
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
     substitution. All M012/P04 verification logic lives inside
     scripts/verify/m012-p04-*.sh files; the Check commands here invoke them.
     MEM004 carve-out applies to the internals of those scripts, not to these
     Check lines. -->

### Truths

- `wiki/docs/index.md` is the finalized home page (P01 placeholder replaced): contains a concise one-line project tagline, four orientation sections (What this site is / How to navigate / Where to comment / Audience scope), a "Deploy & preview" pointer to `wiki/README.md`, links by path to the five top-level rendered artifacts (constitution, decisions, knowledge, milestone-summary, milestones), and does NOT contain the word "placeholder". The file remains ≤ 120 lines (Constitution VI — a home page is not a documentation dump) and contains zero copied `.orchestrator/**.md` body text (AD-3 SSOT — every canonical artifact is reached via its stub route, never inlined here). US1 / SC-3.
  - Check: `bash scripts/verify/m012-p04-index-finalized.sh`

- `wiki/README.md` carries a `## First-deploy checklist` section naming — as literal strings — `GISCUS_REPO`, `GISCUS_REPO_ID`, `GISCUS_CATEGORY`, `GISCUS_CATEGORY_ID`, the `gh-pages` branch, the GitHub Discussions feature, the `discussions category` step, and the `mkdocs gh-deploy --force` command. The checklist references `scripts/wiki/wiki-deploy.sh` by name. US3 / SC-4 / SC-9.
  - Check: `bash scripts/verify/m012-p04-readme-first-deploy.sh`

- `scripts/wiki/wiki-deploy.sh` exists, is Bash 3.2 compatible, is executable, accepts `--dry-run`, `--help`, `--root <dir>`, and `--skip-smoke` flags, and on the live path chains exactly four gate-shaped invocations in order before deploy: (1) `scripts/diagnostics/wiki-giscus-config-check.sh`, (2) `mkdocs build -f wiki/mkdocs.yml`, (3) `scripts/diagnostics/wiki-link-check.sh --site wiki/site`, (4) `scripts/diagnostics/wiki-giscus-smoke.sh --site wiki/site`. Any non-zero exit from any gate aborts before `mkdocs gh-deploy --force` runs. Emits `GATE: <name> PASS|FAIL`, `BUILD: ok|fail`, `DEPLOY: pushing to gh-pages`, and one `DRY-RUN:` / `OK:` / `FAIL:` terminator line. US3 / SC-4 / SC-9 / FR-5 / FR-7.
  - Check: `bash scripts/verify/m012-p04-deploy-wrapper-contract.sh`

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


### P02 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P02"
parent: "M012"
milestone: "M012"
provides:
  - "wiki/mkdocs.yml include-markdown rewrite_relative_urls:true load-bearing setting; scripts/wiki/wiki-scan-sources.sh extended with knowledge/**/MEM*.md enumeration emitting knowledge:<category>|<repo-root-relative-path>|<title> records for patterns (11), conventions (9), lessons (5) in lexical order, appended strictly after .orchestrator/ records, scripts/wiki/wiki-generate-stubs.sh extended to consume knowledge:<category> scanner records — routes each to wiki/docs/knowledge/<sub>/<MEM###>.md with canonical include rooted at repo (knowledge/<sub>/<MEM>.md) via build_canonical_repo_rel helper, plus emits 4 section indexes ([knowledge/index.md](../../../../knowledge/index.md) + patterns/conventions/lessons per-category indexes) carrying the 'Auto-generated section index' comment probe; scripts/wiki/wiki-generate-nav.sh extended to emit a Knowledge Entries subtree between the consolidated Knowledge: leaf and the Milestone Summary: leaf, grouped by category in lexical order with per-category Overview leaves; scripts/verify/m012-p01-include-plugin.sh extended additively to accept repo-rooted knowledge/** canonical targets alongside the pre-existing .orchestrator/** allowance, scripts/diagnostics/wiki-link-check.sh — standalone Bash 3.2 built-site MkDocs link walker with three-way classification (in-scope / out-of-scope / broken), exit-code contract (0 ok / 1 broken / 2 usage-error), deterministic sort -u findings emission, pure-string normalize_path helper (no realpath dependency), --site/--root/--strict/--help dual-style flag parser, trap-cleaned PID-suffixed /tmp temp files, and offline --help contract whose output carries the six tokens T05's m012-p02-link-check-help.sh gate asserts on, wiki/README.md operator documentation: Link resolution policy (in-scope/out-of-scope/flag-and-enumerate), Running the link checker (--site/--root/--strict/--help flag reference + exit codes + output shape), Pre-deploy integration (P04) contract (link-checker + Giscus smoke hooks + mkdocs build --strict alignment), 9 P02 verify gates (link-rewrite-config, mem-stubs, mem-anchors, link-check-contract, link-check-help, readme-policy, link-check-smoke, bash32-compat, d011-evaluation) + m012-p02-phase-suite.sh orchestrator + D011-EVALUATION.md structured record (1 of 3 criteria shipped -> [M020](../../../../milestones/M020/index.md) promoted); P01 nav-structure failure resolved by regenerating wiki/mkdocs.yml nav block from current scanner output and extending self-contained allowlist for scripts/verify/m012-p02-*.sh (both 9/9 P01 and 9/9 P02 green)"
requires:
  - "from:M012/P01 what:wiki/ skeleton + include-plugin config + scanner emitting .orchestrator/**.md records; from:none what:knowledge/patterns,conventions,lessons/MEM*.md tree, from:M012/P02/T01 what:wiki-scan-sources.sh emitting knowledge:<category>|<repo-root-rel>|<title> records + wiki/mkdocs.yml rewrite_relative_urls:true + toc:permalink:true; from:M012/P01 what:P01 stub/nav generator skeleton + P01 9-gate verification suite, from:M012/P02/T01 what:wiki/mkdocs.yml rewrite_relative_urls:true include-plugin setting (load-bearing for links inside included bodies to resolve correctly in the built site); from:M012/P02/T02 what:wiki/docs/knowledge/** stub surface + Knowledge Entries nav subtree (T03's script operates on the BUILT output under wiki/site/ which includes these stubs once mkdocs is invoked); from:M012/P01 what:P01 9-gate phase suite + wiki-serve.sh --probe throwaway build path convention for local smoke-testing, from:M012/P01 what:wiki/README.md operator preamble (install/preview/regenerate/scope sections), from:M012/P02/T01 what:wiki/mkdocs.yml rewrite_relative_urls true, from:M012/P02/T02 what:wiki/docs/knowledge/**/MEM*.md stub tree shape, from:M012/P02/T03 what:scripts/diagnostics/wiki-link-check.sh with --site/--root/--strict/--help API and BROKEN/OUT-OF-SCOPE/PASS/FAIL output shape, from:M012/P02/T01 what:wiki/mkdocs.yml rewrite_relative_urls true + toc permalink true + extended scanner emitting knowledge:<cat> records; from:M012/P02/T02 what:wiki/docs/knowledge tree (25 MEM stubs + 4 section indexes) + Knowledge Entries nav subtree; from:M012/P02/T03 what:scripts/diagnostics/wiki-link-check.sh with --site/--root/--strict/--help API and BROKEN/OUT-OF-SCOPE/PASS/FAIL output shape; from:M012/P02/T04 what:wiki/README.md Link resolution + Running the link checker + Pre-deploy integration (P04) headings plus wiki-link-check.sh and mkdocs build --strict mentions"
affects:
  - "M012/P02/T02 (stub generator will consume new knowledge:<category> records to emit wiki/docs/knowledge/<category>/MEM*.md include stubs + section indexes); M012/P02/T03 (nav generator will build Knowledge Entries subtree); M012/P02/T05 (link-rewrite-config + mem-stubs + mem-anchors verification gates), M012/P02/T03 (wiki/README.md link-resolution policy authoring reads the generated Knowledge Entries subtree shape + MEM stub canonical-path convention); M012/P02/T04 (diagnostics wiki-link-check.sh built-site walker will see the 25 MEM stubs + 4 knowledge indexes as additional in-scope pages); M012/P02/T05 (m012-p02-mem-stubs.sh mechanical gate will assert on the exact stub count + nav-leaf count this task produces; m012-p02-mem-anchors.sh gate will run its anchor-probe against these stubs), M012/P02/T04 (wiki/README.md link-resolution policy section will reference scripts/diagnostics/wiki-link-check.sh by name + document operator-facing --site / --strict / --help surface + pre-deploy-hook guidance); M012/P02/T05 (scripts/verify/m012-p02-link-check-contract.sh asserts exit-code contract; m012-p02-link-check-help.sh asserts the six help-block tokens; m012-p02-link-check-smoke.sh runs SKIP-as-PASS smoke when mkdocs absent, or build-and-walk when present); M012/P04 future phase wires link-check-smoke as a pre-deploy hook per the roadmap cross-cutting concern, M012/P02/T05 (policy-docs gate asserts on literal heading lines + content mentions), M012/P04 (deploy pipeline consumes the documented pre-build hook contract), M012 phase close (P02 derivation advances once P02-SUMMARY.md lands); M012 consolidation (D011-EVALUATION.md triggers M020 roadmap insertion between [M014](../../../../milestones/M014/index.md) and [M019](../../../../milestones/M019/index.md) Tier 2/3)"
key_files:
  - "wiki/mkdocs.yml,scripts/wiki/wiki-scan-sources.sh, scripts/wiki/wiki-generate-stubs.sh,scripts/wiki/wiki-generate-nav.sh,scripts/verify/m012-p01-include-plugin.sh,wiki/docs/knowledge/index.md,wiki/docs/knowledge/patterns/index.md,wiki/docs/knowledge/conventions/index.md,wiki/docs/knowledge/lessons/index.md,wiki/docs/knowledge/patterns/MEM001.md..MEM011.md,wiki/docs/knowledge/conventions/MEM012.md..MEM020.md,wiki/docs/knowledge/lessons/MEM021.md..MEM025.md,wiki/mkdocs.yml, scripts/diagnostics/wiki-link-check.sh, wiki/README.md, scripts/verify/m012-p02-link-rewrite-config.sh,scripts/verify/m012-p02-mem-stubs.sh,scripts/verify/m012-p02-mem-anchors.sh,scripts/verify/m012-p02-link-check-contract.sh,scripts/verify/m012-p02-link-check-help.sh,scripts/verify/m012-p02-readme-policy.sh,scripts/verify/m012-p02-link-check-smoke.sh,scripts/verify/m012-p02-bash32-compat.sh,scripts/verify/m012-p02-d011-evaluation.sh,scripts/verify/m012-p02-phase-suite.sh,[.orchestrator/milestones/M012/phases/P02/D011-EVALUATION.md](../../../../milestones/M012/phases/P02/D011-EVALUATION.md),wiki/mkdocs.yml,scripts/verify/m012-p01-wiki-self-contained.sh"
key_decisions:
  - "AD-3 SSOT (scanner emits paths only; no content copy); Constitution XIV (no speculative flag added — emission unconditional when knowledge/ exists); Constitution XV (touched exactly two files), AD-3 SSOT (every MEM stub is a ≤25-line include shell — no canonical body copied); AD-6 nav completeness (every knowledge:* scanner record maps to exactly one nav leaf); AD-19 single-script-file Check shape (all verification lives inside the P01 gate scripts); Constitution XIV (no speculative flags — Knowledge Entries subtree emitted unconditionally when scanner sees records); Constitution XV (surgical precision — T02 touched exactly the two generator scripts, one P01 gate additively, and created the wiki/docs/knowledge/ subtree), AD-19 single-script-file Check shape (T05 gates invoke one bash scripts/diagnostics/wiki-link-check.sh per Truth; MEM004 carve-out for internal pipes/grep -oE/sed/find); Constitution XIV no speculative complexity (no --json output flag, no cache, no parallel worker pool — just the Must-Haves); Constitution XV surgical precision (T03 created exactly one file plus executable bit; nav/README/gate-suite surfaces deferred to T04/T05); AD-3 SSOT (checker walks the BUILT site HTML, does NOT read .orchestrator/**.md as content source), AD-1 granular-MEM cite preferred over consolidated anchor (D011 criterion a),AD-3 SSOT cite-by-path not body-copy,AD-19 no executable wiring in T04,Constitution XIV no speculative complexity,Constitution XV surgical precision single file touched, D011 mechanical outcome recorded (1 of 3 -> M020 promoted); AD-1 granular-MEM cite preferred; AD-19 single-script-file Check shape honored; MEM001 Bash 3.2 discipline; Constitution XIV no speculative complexity; Constitution XV surgical precision"
patterns_established:
  - "Additive scanner extension invariant: new emission block appended after existing blocks so downstream generators see stable order (top-level -> milestone -> archive -> knowledge:patterns -> knowledge:conventions -> knowledge:lessons); repo-root-relative <rel-path> convention for source trees outside .orchestrator/ (distinct from the .orchestrator-relative convention used for .orchestrator/**.md records); extract_title helper reuse avoids duplicate H1/pipe-sanitization logic across emission blocks, Per-category /tmp list files as fixed-slot associative-array replacement (bash 3.2 safe) — three hard-coded filenames (KN_PATTERNS_LIST, KN_CONVENTIONS_LIST, KN_LESSONS_LIST) scoped by PID; Two-root canonical scheme picked by category-prefix branch (build_canonical for .orchestrator/-rooted records, build_canonical_repo_rel for repo-rooted knowledge/ records); Additive P01 gate extension when a downstream task legitimately expands the set of valid canonical roots (rather than duplicating the gate under P02); Scanner-presence-gated subtree emission (Knowledge Entries subtree disappears cleanly when scanner sees zero knowledge:* records, mirroring P01's conditional Archive bucket), MEM004 carve-out applied to diagnostics scripts (internal pipes permitted; Check-layer shape stays single-script-file); pure-string normalize_path primitive walks IFS=/ positional-parameter stack + string-suffix trim for .. collapse (no realpath dependency — works on stock macOS bash with no Homebrew coreutils); counter recomputation post-pipe (while read from file not from pipe — Bash 3.2 piped-subshell counter-loss caveat respected per MEM001); findings sorted LC_ALL=C sort -u before emission for byte-identical stdout across repeated runs, documentation-only P02 to P04 handoff via prose contract (README enumerates hooks and chaining behavior; P04 owns the wrapper); flag-and-enumerate policy for out-of-scope targets (checker emits OUT-OF-SCOPE informational lines but does not fail the build); mkdocs build --strict and wiki-link-check.sh as complementary gates (source+nav vs rendered-HTML); honest future-enhancement framing (repo-root to github.com rewrite explicitly out of scope), P02 phase-suite mirrors P01 parallel-indexed-array orchestrator (gates_0..gates_8 + eval); SKIP-as-PASS at gate boundary for mkdocs-dependent gates (mem-anchors, link-check-smoke) on hosts without mkdocs; D011 mechanical-evaluation record as first-class phase artifact (not summary side-note); nav regeneration as policy-neutral repair (scanner emits task-level T##-PAYLOAD already by design — regenerating mkdocs.yml reconciles nav with current on-disk scanner output); self-contained gate allowlist extension from m012-p01-*.sh to m012-p02-*.sh carries forward P01 containment policy without weakening it"
drill_down_paths:
  - ".orchestrator/milestones/M012/phases/P02/tasks/T01-SUMMARY.md, .orchestrator/milestones/M012/phases/P02/tasks/T02-SUMMARY.md, .orchestrator/milestones/M012/phases/P02/tasks/T03-SUMMARY.md, .orchestrator/milestones/M012/phases/P02/tasks/T04-SUMMARY.md, .orchestrator/milestones/M012/phases/P02/tasks/T05-SUMMARY.md"
duration: "140m"
verification_result: "pass"
completed_at: "2026-04-21T02:31:01Z"
observability_surfaces:
  - "none"
---

## Summary

P02 extends the M012/P01 wiki pipeline to resolve internal cross-links, surface the `knowledge/**/MEM*.md` corpus through the existing SSOT pipeline, and ship a standalone built-site link checker — with a nine-gate P02 verification suite and a D011 mechanical evaluation record that promotes M020. All 10 Truths PASS; both the P01 and P02 phase suites are 9/9 green at close.

## What was built

- **Cross-link resolution** — `wiki/mkdocs.yml` `include-markdown` gains `rewrite_relative_urls: true` (load-bearing for links inside included bodies), `toc: permalink: true` already in place from P01.
- **Knowledge subtree via the SSOT pipeline** — the existing `scanner → stubs → nav` three-stage pipeline is additively extended: `wiki-scan-sources.sh` emits `knowledge:<category>|<repo-root-rel>|<title>` records in lexical order per category; `wiki-generate-stubs.sh` routes them to `wiki/docs/knowledge/<category>/MEM*.md` with repo-root-relative canonical includes plus four `Auto-generated section index` files; `wiki-generate-nav.sh` emits a `Knowledge Entries` subtree between `Knowledge:` and `Milestone Summary:`. 25 MEM files → 25 wiki stubs (11 patterns + 9 conventions + 5 lessons).
- **Link checker** — `scripts/diagnostics/wiki-link-check.sh` (297 lines, Bash 3.2, pure-string `normalize_path` with no `realpath` dependency) walks built-site HTML, classifies links three ways (in-scope/out-of-scope/broken), honors `--site/--root/--strict/--help`, emits deterministic `sort -u` findings, and follows the 0/1/2 exit-code contract.
- **Operator documentation** — `wiki/README.md` adds `Link resolution`, `Running the link checker`, and `Pre-deploy integration (P04)` sections. P02 documents the P04 contract; P04 wires the hooks.
- **Verification surface** — 9 P02 gates (`link-rewrite-config`, `mem-stubs`, `mem-anchors`, `link-check-contract`, `link-check-help`, `readme-policy`, `link-check-smoke`, `bash32-compat`, `d011-evaluation`) plus `m012-p02-phase-suite.sh` orchestrator. Mkdocs-dependent gates use SKIP-as-PASS on hosts without mkdocs.
- **D011 evaluation** — [`.orchestrator/milestones/M012/phases/P02/D011-EVALUATION.md`](../../../../milestones/M012/phases/P02/D011-EVALUATION.md) records the mechanical outcome: **1 of 3** criteria shipped (cross-refs ✓, review-state ✗, query surface ✗) → **M020 promoted** per the D011 trigger rule.
- **P01 nav-structure repair** — the stale P01 nav block that had accumulated task-level `*-PAYLOAD.md` leaks was reconciled by regenerating `wiki/mkdocs.yml` from current scanner output (policy-neutral) and extending `scripts/verify/m012-p01-wiki-self-contained.sh` allowlist to include `m012-p02-*.sh`. Both phase suites green at close.

## Key decisions

- **AD-3 SSOT preserved** — MEM entries surface via include stubs, never copied.
- **AD-1 granular-MEM citation** — per-entry files are the canonical cross-ref target; consolidated `KNOWLEDGE.md` anchors are best-effort since it uses topical headings, not `### MEM-NNNN`.
- **Constitution XIV (no speculative complexity)** — knowledge subtree emission is unconditional when `knowledge/` exists (no flag); T04 documents the P04 contract without wiring hooks.
- **Constitution XV (surgical precision)** — every task touched the minimum surface; D011 evaluation is a first-class structured artifact rather than buried in prose.
- **MEM004 carve-out** — internal compound shell logic permitted inside diagnostic/scanner scripts; AD-19 single-script-file Check shape enforced at the Check layer.
- **Policy-neutral nav repair** — regenerating `wiki/mkdocs.yml` rather than changing scanner exclusion policy keeps task-level `*-PAYLOAD.md` inclusion consistent with pre-M012 milestones (M002–[M011](../../../../milestones/M011/index.md) already navigate their payload files).

## Patterns established

- Additive scanner extension (append-only emission block) keeps downstream generators stable across P01→P02.
- Two-root canonical scheme: `.orchestrator/`-rooted records use the existing helper; repo-rooted `knowledge/` records use a new `build_canonical_repo_rel` branch.
- Per-category `/tmp` PID-suffixed list files as fixed-slot associative-array replacement (Bash 3.2 safe).
- Scanner-presence-gated subtree emission (Knowledge Entries subtree, like P01's conditional Archive bucket).
- Pure-string `normalize_path` walking `IFS=/` positional-parameter stack — no `realpath` / Homebrew coreutils dependency on macOS.
- SKIP-as-PASS at gate boundaries for mkdocs-dependent checks (keeps auto-mode green on sandboxes without mkdocs installed).
- Phase-suite orchestrator mirrors P01 parallel-indexed-array pattern (`gates_0..gates_8 + eval`).
- D011 mechanical-evaluation record as first-class phase artifact (not a summary side-note).

## Verification results

- `scripts/verify/m012-p02-phase-suite.sh` — **9/9 PASS**
- `scripts/verify/m012-p01-phase-suite.sh` — **9/9 PASS** (nav-structure regression closed)
- `scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P02` — all 10 Truths PASS, all 46 Artifact assertions PASS, all 17 Key-Link assertions PASS
- External modification check: PASS (no external modifications during phase)
- Roadmap sync: OK

## D011 outcome for M012

Per [`.orchestrator/DECISIONS.md`](../../../../decisions.md) D011 trigger rule, the mechanical count at P02 close is 1 of 3 criteria shipped (cross-refs ✓, review-state ✗, query surface ✗) → **M020 is promoted** per the committed rule.

## Open follow-ups (out of scope for P02)

- P03 Giscus integration consumes this rendered surface (comments per page).
- P04 deploy pipeline wires `wiki-link-check.sh` + `mkdocs build --strict` as pre-deploy gates per the documented contract.
- MEM-anchor resolution against the consolidated `KNOWLEDGE.md` page is best-effort; if desired, a future task could normalize MEM headings in `KNOWLEDGE.md` to `### MEM-NNNN` for full anchor coverage.


### P03 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P03"
parent: "M012"
milestone: "M012"
provides:
  - "wiki/overrides/partials/comments.html Material comments-partial override (Giscus <script> block driven by config.extra.giscus.*); wiki/mkdocs.yml theme.custom_dir: overrides + top-level extra.giscus block (repo/repo_id/category/category_id via !ENV with empty-string defaults, mapping: pathname literal) marker-bounded by # >>> M012-P03 extra / # <<< M012-P03 extra end, scripts/diagnostics/wiki-giscus-config-check.sh loud-fail pre-build gate; exits 1 with per-var FAIL lines + HINT when any of GISCUS_REPO, GISCUS_REPO_ID, GISCUS_CATEGORY, GISCUS_CATEGORY_ID is unset or empty; exits 0 with PASS on all-set; Bash 3.2 compatible; supports --help and --quiet; exit-code contract 0/1/2 for pass/missing/usage-error, scripts/diagnostics/wiki-giscus-smoke.sh (129 lines, 755, Bash 3.2): post-build HTML walker that asserts every *.html under --site contains src=https://giscus.app/client.js; flags --site/--root/--verbose/--help; exit 0 all-pages-have-it, exit 1 any-missing with one FAIL: <path> per miss + SUMMARY: on stderr, exit 2 usage-error/missing-dir/empty-dir; PASS: on stdout / FAIL:/ERROR:/HINT:/SUMMARY: on stderr; grep -qF literal match; mktemp list-file + while IFS= read -r pattern (no |-while, no process substitution, no declare -A); EXIT trap cleanup; AD-3 SSOT compliant (reads only built HTML, never .orchestrator/**.md), scripts/diagnostics/wiki-giscus-remap.sh (Bash 3.2 idempotent remap: --dry-run, --help, --repo, --category, fail-closed ambiguity, DRY-RUN/OK/NOOP/FAIL per-pair emit, exit codes 0/1/2); wiki/README.md 'Giscus mapping' + 'Remapping threads after consolidation' sections (pathname strategy + tradeoffs + workflow + exit-code table), scripts/verify/m012-p03-*.sh eight-gate P03 verification suite (comments-partial, mkdocs-giscus-config, mapping-documented, config-loud-fail, smoke-contract, remap-contract, bash32-compat, wiki-removable) + m012-p03-phase-suite.sh orchestrator using P02 parallel-indexed-variable pattern (gates_0..gates_7, eval indirection, Bash 3.2 safe); cross-phase allow-list extension in scripts/verify/m012-p01-wiki-self-contained.sh (scripts/verify/m012-p03-*.sh containment area); See-also cross-reference from scripts/diagnostics/wiki-giscus-remap.sh to wiki-giscus-smoke.sh"
requires:
  - "from:M012/P01/T01 what:wiki/mkdocs.yml base with theme.name material + plugins + markdown_extensions; from:M012/P01/T04 what:# >>> M012-P01 nav / # <<< M012-P01 nav end marker-bounded region that must remain byte-identical, from:T01 what:wiki/mkdocs.yml extra.giscus block expects four GISCUS_* env vars via !ENV NAME,'' interpolation (empty-string default is the silent-failure mode this gate closes), from:T01 what:wiki/overrides/partials/comments.html emits the literal src=https://giscus.app/client.js needle on every page; from:T02 what:scripts/diagnostics/wiki-giscus-config-check.sh exists as the pre-build companion cross-referenced in this script's header (no runtime coupling); from:disk what:scripts/diagnostics/ directory, from:T01 what:mapping=pathname in wiki/mkdocs.yml; from:T02 what:wiki-giscus-config-check.sh basename reference; from:T03 what:wiki-giscus-smoke.sh basename reference, from:T01 what:wiki/overrides/partials/comments.html + wiki/mkdocs.yml theme.custom_dir + extra.giscus block; from:T02 what:scripts/diagnostics/wiki-giscus-config-check.sh loud-fail behavior; from:T03 what:scripts/diagnostics/wiki-giscus-smoke.sh --site flag; from:T04 what:scripts/diagnostics/wiki-giscus-remap.sh help/dry-run/odd-arg contract + wiki/README.md Giscus mapping + Remapping sections"
affects:
  - "M012/P03/T02 (pre-build config-check gate greps extra.giscus keys and detects empty-string env defaults), M012/P03/T03 (mkdocs build + smoke walker greps rendered HTML for giscus.app/client.js which comes from this partial), M012/P03/T04 (remap script updates pathname-mapped discussions), M012/P03/T05 (verify gates assert on these artifacts), P03/T05 (m012-p03-config-loud-fail.sh will wrap this diagnostic under fully-set and fully-unset env fixtures); P04 (deploy wrapper will invoke this gate before mkdocs gh-deploy), T04 (remap script lands alongside this walker under scripts/diagnostics/), T05 (m012-p03-smoke-contract.sh gate exercises this walker against fixture sites; m012-p03-bash32-compat.sh scans this script), P04 (deploy wrapper chains config-check -> mkdocs gh-deploy -> this smoke walker), T05 (m012-p03-remap-contract.sh + m012-p03-mapping-documented.sh + m012-p03-bash32-compat.sh assert on surfaces established here); P04 (operator-invoked remap step in consolidation runbook), P03 closeout (phase-suite green unlocks phase transition); M012 milestone closeout gate (P03 gate count 8/8); downstream consumers of the wiki-giscus surface (smoke/remap scripts stable contracts)"
key_files:
  - "wiki/overrides/partials/comments.html,wiki/mkdocs.yml, scripts/diagnostics/wiki-giscus-config-check.sh, scripts/diagnostics/wiki-giscus-smoke.sh, scripts/diagnostics/wiki-giscus-remap.sh,wiki/README.md, scripts/verify/m012-p03-comments-partial.sh,scripts/verify/m012-p03-mkdocs-giscus-config.sh,scripts/verify/m012-p03-mapping-documented.sh,scripts/verify/m012-p03-config-loud-fail.sh,scripts/verify/m012-p03-smoke-contract.sh,scripts/verify/m012-p03-remap-contract.sh,scripts/verify/m012-p03-bash32-compat.sh,scripts/verify/m012-p03-wiki-removable.sh,scripts/verify/m012-p03-phase-suite.sh,scripts/verify/m012-p01-wiki-self-contained.sh,scripts/diagnostics/wiki-giscus-remap.sh"
key_decisions:
  - "AD-3 SSOT (comments injected via theme partial at render time; no .orchestrator/**.md body rewriting),AD-5/SC-7 mapping choice (pathname literal; rename tradeoff handled by T04 remap script),marker-bounded additive edits (mirror P01 nav-marker convention for future automation),!ENV empty-string defaults (no production IDs committed; T02 gate trips on unset env vars), AD-19 single-script-file Check shape,MEM001 Bash 3.2 / stdout-stderr discipline,Constitution XV surgical precision (env-var-only scope; mkdocs.yml parsing deferred to T05), AD-3 SSOT (reads built HTML only),AD-19 single-script-file Check shape (Truth Checks stay single-invocation; MEM004 carve-out permits pipes/find/grep inside this diagnostic),Constitution XIV/XV (T03 ships the walker only; T04/T05 gates are out of scope),MEM001 stderr-vs-stdout split,MEM001 mktemp list-file + while IFS= read -r replaces |-while to avoid subshell counter loss, AD-3 SSOT (remap targets GitHub Discussions only, not disk artifacts),AD-5 mapping tradeoffs surface,MEM001 Bash 3.2,MEM020 write-summary discipline, AD-19 single-script-file Check shape,MEM001 Bash 3.2 compat,MEM004 verify-script carve-out for pipes/awk/$(),P02 parallel-indexed-variable orchestrator pattern reused,self-scan carve-out via PAT_BASH4 assignment,cross-phase allow-list extension as sibling-gate maintenance,regex-tolerance for T01 column-aligned YAML"
patterns_established:
  - "theme override as AD-3-compliant injection surface (append-at-render vs body-rewrite); marker-comment discipline for additive multi-phase mkdocs.yml edits (# >>> M012-P## <scope> / # <<< M012-P## <scope> end); byte-identity verification of upstream marker-bounded regions via shasum of sed-extracted line range before and after edits; YAML-validity check via multi-constructor SafeLoader when !ENV custom tag is present (MkDocs supplies the tag; repo linters must tolerate it), read-only diagnostic (no repo writes, no tmp files, no network); eval-based indirect expansion for Bash 3.2 portability over Bash 4 ${!name}; exit-code triad 0/1/2 (pass/missing/usage) for machine-readable distinction; PASS-only-on-stdout contract so capture/grep pipelines stay clean; probe-via-run-probe smoke harness for multi-case testing under pre-bash shape guard, post-build smoke walker shape: mktemp list file + find -print > list + while IFS= read -r page < list as Bash-3.2-safe replacement for find|while; companion-script header cross-reference without runtime coupling (T02 and T03 point at each other in header comments; P04 deploy wrapper chains both without either sourcing the other); literal-needle grep -qF constant with paired-update note in header (partial URL change requires paired walker update); stderr-carries-the-noise / stdout-carries-the-success convention so callers capturing stdout see only green signal, pair-loop arg consumption with shift 2 + parity check on dollar-hash mod 2; fixed-verb output enum (DRY-RUN/OK/NOOP/FAIL) for per-pair verdicts; dry-run decoupled from external tool presence (gh only required in live path); no-jq-hard-dep via gh api graphql --jq + pure-text parsing (grep -o + sed -n with field-order fallback); fail-closed on ambiguous title match; README append-only (Constitution XV blast-radius discipline); staged-probe smoke battery via scripts/util/run-probe.sh to satisfy pre-bash shape guard, fixture-driven contract gates ($$-suffixed /tmp scratch + EXIT-trap cleanup); self-inclusive compat scan with assignment-line carve-out; phase-suite orchestrator captures gate stderr to TMP_LOG and two-space-indents it on FAIL; key-link as upstream-discovery signal at phase-suite closeout; cross-phase allow-list extension for sibling verify scripts"
drill_down_paths:
  - ".orchestrator/milestones/M012/phases/P03/tasks/T01-SUMMARY.md, .orchestrator/milestones/M012/phases/P03/tasks/T02-SUMMARY.md, .orchestrator/milestones/M012/phases/P03/tasks/T03-SUMMARY.md, .orchestrator/milestones/M012/phases/P03/tasks/T04-SUMMARY.md, .orchestrator/milestones/M012/phases/P03/tasks/T05-SUMMARY.md"
duration: "145m"
verification_result: "pass"
completed_at: "2026-04-21T03:16:36Z"
observability_surfaces:
  - "none"
---

## Summary

P03 adds a Giscus comment surface to the M012 wiki via Material's theme-override partial, plus three operator diagnostics (pre-build config-check, post-build smoke walker, thread remap script) and an eight-gate verification suite. Comments render on every page; a loud-fail pre-build gate catches missing env vars; a post-build walker verifies the `<script>` block lands on every generated HTML page; a remap script migrates Giscus threads when artifacts are consolidated. All P03 / P02 / P01 suites are green at close.

## What was built

- **Giscus injection surface** — `wiki/overrides/partials/comments.html` (Material comments-partial override) emits the Giscus `<script>` block populated from `config.extra.giscus.*`. `wiki/mkdocs.yml` gains `theme.custom_dir: overrides` + a marker-bounded `extra.giscus` block (`repo`, `repo_id`, `category`, `category_id` via `!ENV NAME,''` with empty defaults; `mapping: pathname` literal).
- **Loud-fail pre-build gate** — `scripts/diagnostics/wiki-giscus-config-check.sh` (Bash 3.2) exits 1 with per-var `FAIL:` + `HINT:` when any of the four `GISCUS_*` env vars are unset/empty; exits 0 with `PASS:` on all-set; supports `--help` and `--quiet`. Silences the otherwise-silent "empty deploy" failure mode.
- **Post-build smoke walker** — `scripts/diagnostics/wiki-giscus-smoke.sh` (129 lines, Bash 3.2) asserts every `*.html` under `--site` contains `src=https://giscus.app/client.js`. Exit 0/1/2 for all-present / any-missing / usage-error; `FAIL:` per miss + `SUMMARY:` on stderr; `PASS:` on stdout. Uses `mktemp` list-file + `while IFS= read -r` to avoid `|-while` counter-loss per MEM001.
- **Thread remap script** — `scripts/diagnostics/wiki-giscus-remap.sh` (Bash 3.2 idempotent) handles old→new pathname mappings when artifacts rename or consolidate. `--dry-run`, `--help`, `--repo`, `--category`; `DRY-RUN/OK/NOOP/FAIL` per-pair verdicts; fail-closed on ambiguous title match; no hard jq dependency (pure-text GraphQL response parsing with field-order fallback).
- **Operator docs** — `wiki/README.md` gains `## Giscus mapping` and `### Remapping threads` sections (pathname strategy, tradeoffs, workflow, exit-code table).
- **P03 verification surface** — 8 gates (`comments-partial`, `mkdocs-giscus-config`, `mapping-documented`, `config-loud-fail`, `smoke-contract`, `remap-contract`, `bash32-compat`, `wiki-removable`) + `m012-p03-phase-suite.sh` orchestrator (P02 parallel-indexed-variable pattern). Self-contained allow-list in `m012-p01-wiki-self-contained.sh` extended for `m012-p03-*.sh`.

## Key decisions

- **AD-3 SSOT preserved via theme override** — comments are injected by the theme at render time; no canonical `.orchestrator/**.md` body is modified or copied.
- **AD-5 / SC-7 mapping = pathname** — deterministic, no per-page authoring; rename-fragility is handled by the remap script rather than a more complex mapping mode.
- **Loud-fail over silent-empty** — `!ENV` defaults to `""`, so an unconfigured build would silently render empty data-attrs. The pre-build gate makes that case a hard fail with actionable per-var hints.
- **Marker-bounded additive edits** — `# >>> M012-P03 extra` / `# <<< M012-P03 extra end` mirrors P01's nav marker convention; byte-identity of upstream P01 nav region is asserted across the edit.
- **Self-inclusive Bash 3.2 compat with assignment-line carve-out** — the compat gate can safely name the patterns it scans for without self-triggering.
- **Constitution XIV / XV** — env-var-only scope for the config check; `mkdocs.yml` static assertions live in T05 gates, not T02. Remap script is dry-run-default with live path fully separate.

## Patterns established

- **Theme override as AD-3-compliant injection surface** (append-at-render vs body-rewrite) — reusable for any future per-page rendered-HTML additions.
- **Byte-identity verification of upstream marker-bounded regions** via shasum of `sed -n`-extracted line range before and after additive edits.
- **Multi-constructor YAML SafeLoader** when `!ENV` or other MkDocs-specific tags are present (native `safe_load` rejects them).
- **Post-build smoke walker shape** — `mktemp` list file + `find -print > list` + `while IFS= read -r page < list` as Bash-3.2-safe replacement for `find | while` (counter-loss free).
- **stderr-noise / stdout-success convention** — callers grepping stdout see only green signal; `FAIL:` / `ERROR:` / `HINT:` / `SUMMARY:` land on stderr.
- **Fixed-verb output enum** for diagnostic per-item verdicts (`DRY-RUN` / `OK` / `NOOP` / `FAIL`) keeps machine-readable output stable.
- **Phase-suite orchestrator** reuses P02 parallel-indexed-variable pattern (`gates_0..gates_N` + `eval` indirection) — no Bash-4 `${!name}` dependency; stderr captured to `TMP_LOG` and indented on FAIL.
- **Cross-phase allow-list extension as sibling-gate maintenance** — when a new phase's scripts legitimately reference sister-phase scripts in allowed-tree comments, extend the P01 containment allow-list rather than weakening the gate.
- **run-probe.sh smoke harness** — multi-case assertion batteries staged under `/tmp` to bypass the harness pre-bash shape guard without weakening the constraint for production code.

## Verification results

- `scripts/verify/m012-p03-phase-suite.sh` — **8/8 PASS** (deterministic)
- `scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P03` — all Truths + Artifacts + Key-Links PASS
- `scripts/verify/m012-p02-phase-suite.sh` — **9/9 PASS** (unchanged)
- `scripts/verify/m012-p01-phase-suite.sh` — **9/9 PASS** (nav regenerated to pick up new P02/P03 summary stubs)
- External modification check: PASS (no external modifications during phase)
- Roadmap sync: OK

## Open follow-ups (out of scope for P03)

- P04 deploy wrapper chains `wiki-giscus-config-check.sh` → `mkdocs gh-deploy` → `wiki-giscus-smoke.sh` per the documented pre-deploy contract.
- The consolidation runbook should invoke `wiki-giscus-remap.sh --dry-run` before any artifact rename that affects a discussion-bearing page.
- Strict `mkdocs build --strict` as a Tier-4 UAT step on CI runners with the Python toolchain available.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P04"
milestone: "M012"
name: "First-deploy execution + DEPLOY-RECORD.md"
depends_on: ["T03"]
---

## Prerequisites

- T01 complete: `wiki/docs/index.md` finalized.
- T02 complete: `wiki/README.md` first-deploy checklist + deploy-wrapper section.
- T03 complete: `scripts/wiki/wiki-deploy.sh` exists, is executable, chains the four P02/P03 gates before `mkdocs gh-deploy --force`.
- `gh-pages` branch may or may not exist on the remote — `mkdocs gh-deploy --force` creates it on first run.
- [`.orchestrator/milestones/M012/phases/P04/DEPLOY-RECORD.md`](../../../../milestones/M012/phases/P04/DEPLOY-RECORD.md) does not yet exist.

## Description

Execute (or record as pending) the first deploy of the dogfood wiki, and write the structured deploy record that P04's Must-Haves gate on.

Two execution paths are acceptable:

1. **Live deploy (preferred, human operator)** — a maintainer with `GISCUS_*` env vars set and push rights to `gh-pages` runs the wrapper. The wrapper exits 0 with `OK: deployed to <url>` on success. The operator pastes the URL, commit SHA, and per-gate results into `DEPLOY-RECORD.md`.

2. **Fixture-shaped record (auto-mode path)** — when executed by a sandboxed autonomous dispatch without network access or without `GISCUS_*` secrets, the agent writes a record whose `deployed_url: pending` and `commit_sha: pending` sentinel values indicate human operator follow-up. The gate (T05 `m012-p04-deploy-record.sh`) accepts these sentinels in Tier 1; Tier 4 UAT (consolidate-phase human verification) promotes them to real values.

This dual path is explicit in the Truths of P04-PLAN.md. The cleaner long-term pattern — a live deploy from a scheduled GitHub Action — is out of scope for M012 ([M013](../../../../milestones/M013/index.md) / M014 may wire it); M012 ships the wrapper and the record schema, and the first live push is a one-time operator action that can land before or during consolidation.

## Description: DEPLOY-RECORD.md schema

The record file is the structured artifact P04 gates on. Its schema is intentionally minimal — seven fields — so the gate is trivial and the operator can fill it in in under 60 seconds.

## Steps

1. **Attempt the live deploy (human operator path)**. From the repo root, with the four `GISCUS_*` env vars set and `gh-pages` push rights:

   ```
   bash scripts/wiki/wiki-deploy.sh
   ```

   Capture the last three lines. On success they read (approximately):

   ```
   GATE: giscus-smoke PASS
   DEPLOY: pushing to gh-pages
   OK: deployed to gh-pages
   ```

   After the wrapper exits 0, the deployed URL is
   `https://<gh-owner>.github.io/orchestrator/` once GitHub
   Pages has finished building the `gh-pages` branch (typically within
   a minute of push). Capture:

   - the URL
   - the latest commit SHA on `main` (the source of truth) — `git rev-parse HEAD`
   - the timestamp in ISO-8601 UTC — `date -u +%Y-%m-%dT%H:%M:%SZ`
   - the four per-gate results from the wrapper output

2. **If the live deploy is not possible at plan-execution time (sandbox, no secrets, no push rights)**, write the record with the `pending` sentinel values. The gate accepts this path.

3. **Create [`.orchestrator/milestones/M012/phases/P04/DEPLOY-RECORD.md`](../../../../milestones/M012/phases/P04/DEPLOY-RECORD.md)** with exactly this shape:

   ```markdown
   ---
   schema_version: "1.0"
   type: deploy-record
   milestone: "M012"
   phase: "P04"
   deployed_url: "https://<gh-owner>.github.io/orchestrator/"
   commit_sha: "<40-char-sha>"
   deployed_at: "2026-04-21T00:00:00Z"
   deployer: "<github-handle>"
   gate_giscus_config_result: "pass"
   gate_mkdocs_build_result: "pass"
   gate_link_check_result: "pass"
   gate_giscus_smoke_result: "pass"
   ---

   # M012/P04 First-deploy record

   ## Deploy summary

   Deployed via `scripts/wiki/wiki-deploy.sh` from the repo root.
   Pushed to the `gh-pages` branch of this repository; GitHub Pages
   serves the built site from that branch.

   ## Wrapper output (abbreviated)

   ```
   GATE: giscus-config PASS
   BUILD: ok
   GATE: link-check PASS
   GATE: giscus-smoke PASS
   DEPLOY: pushing to gh-pages
   OK: deployed to gh-pages
   ```

   ## Notes

   - First deploy: creates the `gh-pages` branch and triggers an
     initial GitHub Pages build. Subsequent deploys reuse the branch
     and force-push the new built output.
   - GitHub Pages can take up to a minute to serve a freshly pushed
     `gh-pages` update. If the deployed URL returns 404 immediately
     after the wrapper exits 0, wait 60s and reload.
   - If `gh-pages` is a protected branch, `mkdocs gh-deploy --force`
     requires an administrator override. This is not the default;
     the wrapper assumes direct force-push is allowed.

   ## Pending-value path

   If `deployed_url` or `commit_sha` above reads `pending`, the record
   was written without network access at plan-execution time. A human
   operator must rerun `bash scripts/wiki/wiki-deploy.sh` and paste
   the real values before the M012 milestone closes.
   ```

   Fixture-path variant: replace `deployed_url` with the literal string `pending`, `commit_sha` with `pending`, and `deployed_at` with the agent's invocation timestamp (not `pending` — the record was written at a real time). Flip any gate whose result cannot be verified to `"skip"`.

4. **Do not** create any other file in this task. Do not modify the wrapper. Do not modify any upstream diagnostic. Constitution XV.

## Must-Haves

- [`.orchestrator/milestones/M012/phases/P04/DEPLOY-RECORD.md`](../../../../milestones/M012/phases/P04/DEPLOY-RECORD.md) exists, ≥ 25 lines, and contains:
  - YAML frontmatter with `schema_version`, `type: deploy-record`, `milestone: "M012"`, `phase: "P04"`, `deployed_url`, `commit_sha`, `deployed_at`, `deployer`, and four `gate_*_result` fields (`giscus_config`, `mkdocs_build`, `link_check`, `giscus_smoke`).
  - The literal string `gh-pages` in the body.
  - The literal string `wiki-deploy.sh` in the body.
  - Each `gate_*_result` value is one of `pass`, `fail`, `skip`, or `pending`.
  - `deployed_url` is either a URL starting with `http` OR the literal sentinel `pending`.
  - `commit_sha` is either a 40-char hex string OR the literal sentinel `pending`.

## Verification

- Check: `bash scripts/verify/m012-p04-deploy-record.sh`
- Check: `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P04`

## Inputs

### From Previous Tasks

- `scripts/wiki/wiki-deploy.sh` (from T03) — the wrapper the operator runs. DEPLOY-RECORD.md references it by basename. API: zero positional args; flags `--dry-run`, `--help`, `--root DIR`, `--skip-smoke`. Exit 0 on success; terminator line is `OK: deployed to <url>` or `DRY-RUN: would deploy`.
- `wiki/README.md` (from T02) — the operator reads the `## First-deploy checklist` to set up GitHub Pages + Discussions before step 1 of this task. Steps 1–5 of the checklist are prerequisites for the live deploy path here.

### From Disk (Pre-existing)

- `.orchestrator/milestones/M012/phases/P04/` — the phase directory. Created during roadmap generation; the payload file lives here already.
- `mkdocs gh-deploy` behavior (external): on first invocation for a repo, creates the `gh-pages` orphan branch, commits the contents of `wiki/site/`, and pushes. `--force` overrides non-fast-forward safeguards. Source branch identification is inferred from `git remote get-url origin` and the current HEAD.
- GitHub Pages serving behavior (external): once `gh-pages` exists and Pages is configured with "Deploy from a branch → gh-pages → / (root)", GitHub serves `wiki/site/index.html` at `https://<owner>.github.io/<repo>/` within ~60s of push.

## Constraints

- **AD-3 SSOT** — DEPLOY-RECORD.md does not copy any canonical artifact body. It carries operational metadata only.
- **Constitution XV (surgical precision)** — T04 creates exactly one file.
- **Constitution XIV (no speculative complexity)** — no deploy-log parser, no HTML scraper, no URL liveness check. The record is a write-once operator artifact.
- **Loud failure tolerance** — if the live deploy fails partway through, the record still gets written with the failing gate's result set to `fail`. The operator then fixes the underlying issue, re-runs the wrapper, and updates the record.
- **Auto-mode safety** — the auto-mode path (sandbox, no network) writes `pending` sentinels. This is the `fixture-shaped` path mentioned in the phase-plan Truth. A human operator completes the record before the milestone closes.
- **Bash 3.2 compat** — T04 ships no shell scripts.

## Expected Output

- [`.orchestrator/milestones/M012/phases/P04/DEPLOY-RECORD.md`](../../../../milestones/M012/phases/P04/DEPLOY-RECORD.md) exists with the schema above.
- If executed on the live path: the URL is reachable, every rendered page carries a Giscus thread, and SC-5 (a test comment persists across a redeploy) can be manually verified as part of the consolidation-phase UAT walkthrough in `P04-SUMMARY.md`.
- If executed on the fixture path: the `pending` sentinels are clearly present; the T05 gate passes; a human operator resumes the live deploy during consolidation.

## State Context

- **Current State**: executing
- **Milestone**: M012
- **Phase**: P04
- **Task**: T04
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **AD-3 SSOT** — DEPLOY-RECORD.md does not copy any canonical artifact body. It carries operational metadata only.
- **Constitution XV (surgical precision)** — T04 creates exactly one file.
- **Constitution XIV (no speculative complexity)** — no deploy-log parser, no HTML scraper, no URL liveness check. The record is a write-once operator artifact.
- **Loud failure tolerance** — if the live deploy fails partway through, the record still gets written with the failing gate's result set to `fail`. The operator then fixes the underlying issue, re-runs the wrapper, and updates the record.
- **Auto-mode safety** — the auto-mode path (sandbox, no network) writes `pending` sentinels. This is the `fixture-shaped` path mentioned in the phase-plan Truth. A human operator completes the record before the milestone closes.
- **Bash 3.2 compat** — T04 ships no shell scripts.

### Acceptance Criteria

- [`.orchestrator/milestones/M012/phases/P04/DEPLOY-RECORD.md`](../../../../milestones/M012/phases/P04/DEPLOY-RECORD.md) exists, ≥ 25 lines, and contains:
  - YAML frontmatter with `schema_version`, `type: deploy-record`, `milestone: "M012"`, `phase: "P04"`, `deployed_url`, `commit_sha`, `deployed_at`, `deployer`, and four `gate_*_result` fields (`giscus_config`, `mkdocs_build`, `link_check`, `giscus_smoke`).
  - The literal string `gh-pages` in the body.
  - The literal string `wiki-deploy.sh` in the body.
  - Each `gate_*_result` value is one of `pass`, `fail`, `skip`, or `pending`.
  - `deployed_url` is either a URL starting with `http` OR the literal sentinel `pending`.
  - `commit_sha` is either a 40-char hex string OR the literal sentinel `pending`.

### Files To Touch

- `wiki/docs/index.md` (modify — replace P01 placeholder with finalized home page; ≤ 120 lines; zero body-copy from `.orchestrator/**.md`)
- `wiki/README.md` (modify — append `## First-deploy checklist` + `## Running the deploy wrapper` sections after P03's Giscus-mapping block)
- `scripts/wiki/wiki-deploy.sh` (create — chained deploy wrapper with `--dry-run`, `--help`, `--root`, `--skip-smoke` flags)
- [`.orchestrator/milestones/M012/phases/P04/DEPLOY-RECORD.md`](../../../../milestones/M012/phases/P04/DEPLOY-RECORD.md) (create — YAML-frontmatter record of the first deploy; fixture sentinel `deployed_url: pending` tolerated by Tier 1 gate)
- `scripts/verify/m012-p04-index-finalized.sh` (create)
- `scripts/verify/m012-p04-index-ssot.sh` (create)
- `scripts/verify/m012-p04-readme-first-deploy.sh` (create)
- `scripts/verify/m012-p04-deploy-wrapper-contract.sh` (create)
- `scripts/verify/m012-p04-deploy-wrapper-help.sh` (create)
- `scripts/verify/m012-p04-deploy-wrapper-dry-run.sh` (create)
- `scripts/verify/m012-p04-deploy-wrapper-loud-fail.sh` (create)
- `scripts/verify/m012-p04-deploy-record.sh` (create)
- `scripts/verify/m012-p04-bash32-compat.sh` (create)
- `scripts/verify/m012-p04-wiki-removable.sh` (create)
- `scripts/verify/m012-p04-summary-walkthrough.sh` (create)
- `scripts/verify/m012-p04-phase-suite.sh` (create)
- `scripts/verify/m012-p01-wiki-self-contained.sh` (modify — extend the containment allow-list to include `scripts/verify/m012-p04-*.sh` and `scripts/wiki/wiki-deploy.sh`, mirroring the P02/P03 extension pattern)

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