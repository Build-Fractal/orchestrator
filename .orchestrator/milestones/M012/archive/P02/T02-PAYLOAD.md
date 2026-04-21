---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T02 (Phase P02, Milestone M012)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (25 entries) | 20-589 | ~4900 | filtered |
| Decisions | 591-593 | ~100 | filtered |
| Constraints | 595-628 | ~400 | required |
| Scope | 630-658 | ~600 | required |
| Upstream Context | 660-730 | ~3600 | required |
| Task Plan | 732-1007 | ~4700 | required |
| State Context | 1009-1015 | ~100 | required |
| First-Turn Completeness | 1017-1068 | ~1200 | required |
| **Total** | | **~15600** | |

## Knowledge

<!-- 25 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 318
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
hit_count: 318
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
hit_count: 318
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
hit_count: 318
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
hit_count: 285
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
hit_count: 285
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
hit_count: 285
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
hit_count: 318
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
hit_count: 285
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
hit_count: 285
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
hit_count: 285
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
hit_count: 318
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
hit_count: 318
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
hit_count: 318
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
hit_count: 285
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
hit_count: 285
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
hit_count: 285
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
hit_count: 318
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
hit_count: 285
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
hit_count: 285
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
hit_count: 318
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
hit_count: 318
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
hit_count: 285
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
hit_count: 285
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
hit_count: 285
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
     substitution. All M012/P02 verification logic lives inside
     scripts/verify/m012-p02-*.sh files; the Check commands here invoke them. -->

### Truths

- `wiki/mkdocs.yml` enables link rewriting for include-markdown pulls (canonical-path-relative links inside an included `.orchestrator/**.md` body resolve against the rendered stub route, not against the canonical source path) — established by the include plugin's `rewrite_relative_urls: true` option carried over from P01, asserted explicitly here as the load-bearing invariant for cross-link resolution.
  - Check: `bash scripts/verify/m012-p02-link-rewrite-config.sh`

- The wiki resolves `knowledge/**/MEM*.md` file-path references by generating a thin include stub under `wiki/docs/knowledge/<category>/<MEM###>.md` for every file in `knowledge/patterns/`, `knowledge/conventions/`, `knowledge/lessons/` — following the P01 SSOT pattern (≤ 25-line stub, single `include-markdown` directive, no body copy, AD-3).
  - Check: `bash scripts/verify/m012-p02-mem-stubs.sh`

- KNOWLEDGE anchor links of the form `KNOWLEDGE.md#mem-NNNN` (or `#MEM-NNNN`, case-insensitive per MkDocs' slug normalization) resolve to the rendered `.orchestrator/KNOWLEDGE.md` stub's heading anchor for that MEM entry — verified by scraping the rendered KNOWLEDGE HTML page for a heading with a matching anchor id (D011 criterion (a); AD-1).
  - Check: `bash scripts/verify/m012-p02-mem-anchors.sh`

- `scripts/diagnostics/wiki-link-check.sh` exists, is Bash 3.2 compatible, walks a built site directory (`wiki/site/` by default; `--site <dir>` override), extracts every internal `<a href="…">` link from every generated HTML file, classifies each link as in-scope (resolves to another rendered page or same-page anchor in the built site) vs out-of-scope (external URL, mailto, or path outside the rendered tree), emits `BROKEN: <source-page> -> <href>` for every broken in-scope link, `OUT-OF-SCOPE: <source-page> -> <href>` for every external target, `PASS:` or `FAIL:` summary on the last line, and exits 0 iff zero in-scope links are broken (FR-6, SC-6).

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
task: "T02"
phase: "P02"
milestone: "M012"
name: "MEM stub generation + nav integration + anchor resolution verification"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete:
  - `wiki/mkdocs.yml` has `rewrite_relative_urls: true` on the include-markdown plugin and `toc: { permalink: true }` under `markdown_extensions:`.
  - `scripts/wiki/wiki-scan-sources.sh` emits `knowledge:<category>|<rel-path>|<title>` records in addition to its existing `.orchestrator/**.md` records.
  - `bash scripts/verify/m012-p01-phase-suite.sh` still exits 0.
- P01 patterns:
  - Stub template is a ≤ 25-line markdown file with YAML frontmatter (`title:` only), a short auto-generated comment citing AD-3, and one `include-markdown` block pointing at the canonical file via a `../…`-relative path. See `wiki/docs/milestones/M001/M001-CONTEXT.md` (or any P01-generated stub) for the exact shape.
  - Section-index files are identified by the comment `Auto-generated section index` (classification probe used by P01's SSOT gate).
  - Nav generator splices its output between `# >>> M012-P01 nav` and `# <<< M012-P01 nav end` markers in `wiki/mkdocs.yml`. T02 preserves the marker pair; its additions go inside the existing region alongside existing subtrees.
- `wiki/docs/` currently has NO `knowledge/` subdirectory. T02 creates it.

## Description

T02 teaches the two generators (stub + nav) to consume the new `knowledge:<category>` scanner records. Three deliverables:

**Deliverable 1 — Stub generator extension.** `scripts/wiki/wiki-generate-stubs.sh` learns to route `knowledge:<category>` records to `wiki/docs/knowledge/<category>/<MEM###>.md`, using the same thin-stub template as P01 (≤ 25 lines, one include directive, no body copy). Also emit section indexes:

- `wiki/docs/knowledge/index.md` — top-level index listing the three categories.
- `wiki/docs/knowledge/patterns/index.md`, `wiki/docs/knowledge/conventions/index.md`, `wiki/docs/knowledge/lessons/index.md` — per-category indexes listing the MEM entries in that category.

Each section index carries the `Auto-generated section index` comment probe so P01's existing SSOT gate (`m012-p01-ssot.sh`) continues to classify them correctly (P01 already permits section indexes to exceed the 25-line cap because they are bullet lists, not content).

**Deliverable 2 — Nav generator extension.** `scripts/wiki/wiki-generate-nav.sh` emits a new `Knowledge Entries` subtree inside the existing marker-bounded nav region. Position: between the existing `Knowledge` top-level entry (which points at the single consolidated `.orchestrator/KNOWLEDGE.md` stub) and the `Milestone Summary` entry. The subtree groups by category:

```yaml
      - Knowledge Entries:
          - Patterns:
              - wiki/docs/knowledge/patterns/index.md
              - MEM001: wiki/docs/knowledge/patterns/MEM001.md
              - MEM002: wiki/docs/knowledge/patterns/MEM002.md
              # … one line per entry, lexical order
          - Conventions:
              - wiki/docs/knowledge/conventions/index.md
              - MEM012: wiki/docs/knowledge/conventions/MEM012.md
              # …
          - Lessons:
              - wiki/docs/knowledge/lessons/index.md
              - MEM021: wiki/docs/knowledge/lessons/MEM021.md
              # …
```

The existing top-level `Knowledge` entry (pointing at `KNOWLEDGE.md`) is preserved unchanged; `Knowledge Entries` is an additional subtree. Rationale: `.orchestrator/KNOWLEDGE.md` is the consolidated view and is its own navigation target; the per-entry files are the granular view. Both are legitimate and both belong in nav per AD-6 (every scanner record maps to exactly one nav leaf).

**Deliverable 3 — MEM anchor resolution probe.** KNOWLEDGE.md already renders with MkDocs heading anchors (because of T01's `toc: permalink: true` setting). The per-MEM headings in `.orchestrator/KNOWLEDGE.md` look like `### Shell Script Conventions` (section-style, not `### MEM001: …`-style — the consolidated file groups by topic). By contrast, the per-entry files (`knowledge/patterns/MEM001.md`) DO carry `# MEM001: Shell Script Conventions` H1s. The D011 criterion (a) from AD-1 specifies BOTH: "cross-refs to `knowledge/**/MEM*.md`". The primary cross-ref target is the per-entry files (T02's new stubs). Anchor-style references `KNOWLEDGE.md#mem-NNNN` are a secondary convenience — at the rendered KNOWLEDGE page, those anchors may not exist because the consolidated file uses topical headings. The resolution policy (documented in T04) clarifies: prefer `knowledge/<cat>/MEM###.md`-style file-path links; `KNOWLEDGE.md#mem-NNNN` anchor links resolve only when the consolidated file happens to carry a matching heading.

T02 ships the anchor-resolution probe as a diagnostic helper used by T05's gate, NOT as a build-breaking assertion. The probe scans the rendered KNOWLEDGE HTML (if mkdocs is installed) and reports which MEM IDs DO have a matching anchor; the list is saved for T04 documentation.

## Steps

1. **Open `scripts/wiki/wiki-generate-stubs.sh`**. Locate the main loop that reads scanner records and routes by category (`top:*`, `milestone:M###`, `archive:M###`). Add a new branch for `knowledge:<category>`:

   ```bash
   # ---- knowledge:* routing (added in M012/P02/T02) ----------------------------
   case "$category" in
     knowledge:patterns|knowledge:conventions|knowledge:lessons)
       sub="${category#knowledge:}"                     # patterns | conventions | lessons
       # mem_id derived from basename: "MEM001.md" -> "MEM001"
       mem_id=$(basename "$rel_path" .md)
       stub_path="$ROOT/wiki/docs/knowledge/$sub/$mem_id.md"
       mkdir -p "$ROOT/wiki/docs/knowledge/$sub"
       # Depth from wiki/docs to the canonical knowledge/<sub>/<MEM>.md target.
       # wiki/docs/knowledge/<sub>/<MEM>.md needs to climb 3 dirs to repo root.
       canonical_rel="../../../$rel_path"
       write_stub "$stub_path" "$title" "$canonical_rel"
       continue
       ;;
   esac
   ```

   `write_stub` is the existing P01 helper. If it does not exist under that exact name, inline the equivalent (P01 T03 pattern):

   ```bash
   # Thin stub template — 12–13 lines, SSOT-safe.
   cat > "$stub_path" <<EOF
   ---
   title: "$title"
   ---

   <!-- Auto-generated by scripts/wiki/wiki-generate-stubs.sh.
        Do not hand-edit. The canonical content lives at:
        $rel_path
        See M012 AD-3 (SSOT via include-markdown). -->

   {%
     include-markdown "$canonical_rel"
     heading-offset=0
     rewrite-relative-urls=true
   %}
   EOF
   ```

2. **Add section-index emission for the `knowledge/` tree** in the same generator. After the main record loop, but before the generator exits, emit four section indexes:

   ```bash
   # ---- knowledge/ section indexes (M012/P02/T02) ------------------------------
   write_knowledge_top_index "$ROOT/wiki/docs/knowledge/index.md"
   for sub in patterns conventions lessons; do
     write_knowledge_sub_index "$ROOT/wiki/docs/knowledge/$sub/index.md" "$sub"
   done
   ```

   Top-level index template:

   ```markdown
   ---
   title: "Knowledge Entries"
   ---

   <!-- Auto-generated section index for knowledge/ stubs.
        Lists the three category indexes. -->

   # Knowledge Entries

   - [Patterns](patterns/index.md)
   - [Conventions](conventions/index.md)
   - [Lessons](lessons/index.md)
   ```

   Per-category index template (example for `patterns`):

   ```markdown
   ---
   title: "Knowledge — Patterns"
   ---

   <!-- Auto-generated section index for knowledge/patterns stubs.
        Bullets below are generated from scanner records in lexical order. -->

   # Knowledge — Patterns

   - [MEM001](MEM001.md)
   - [MEM002](MEM002.md)
   …
   ```

   Build the bullet list by walking the scanner records for the matching category in lexical order. Title falls back to basename-sans-`.md` if no scanner title is present (same pattern as P01 section indexes).

3. **Open `scripts/wiki/wiki-generate-nav.sh`**. Locate the state machine that emits the marker-bounded nav block. Find the position where the existing `Knowledge:` entry (pointing at the single KNOWLEDGE.md stub) is emitted. After emitting that entry (and before `Milestone Summary:`), emit a new `Knowledge Entries:` subtree. The nav block is assembled from scanner records in a single forward pass (P01 pattern); emit the new subtree by scanning the cached record list for `knowledge:*` categories:

   ```bash
   # ---- Knowledge Entries subtree (M012/P02/T02) ------------------------------
   emit_line "      - Knowledge Entries:"
   for sub in patterns conventions lessons; do
     label=$(nav_label_for_sub "$sub")    # "Patterns" | "Conventions" | "Lessons"
     emit_line "          - $label:"
     emit_line "              - wiki/docs/knowledge/$sub/index.md"
     # Walk the scanner's /tmp record list for matching category.
     while IFS='|' read -r c r t; do
       [ "$c" = "knowledge:$sub" ] || continue
       mem_id=$(basename "$r" .md)
       emit_line "              - $mem_id: wiki/docs/knowledge/$sub/$mem_id.md"
     done < "$SCAN_RECORDS_TMP"
   done
   ```

   Notes:
   - `$SCAN_RECORDS_TMP` is the scanner-output cache the P01 generator already builds (parallel /tmp list files scoped by PID, from P01 patterns). Reuse it; do not re-invoke the scanner.
   - Indentation matches P01's nav convention (`      -` for top-level nav entries under `nav:`; `          -` for category-level; `              -` for leaf entries — three-level indentation).
   - The outer `emit_line` function is P01's existing nav emitter (writes to the staged nav file).

4. **Preserve P01 markers and atomic write**. The nav generator already uses the marker-bounded atomic-write pattern (P01 T04). T02's edits live inside the existing marker region — no new markers.

5. **Regenerate stubs and nav from scratch**:

   ```bash
   bash scripts/wiki/wiki-generate-stubs.sh
   bash scripts/wiki/wiki-generate-nav.sh
   ```

   Expect:
   - `wiki/docs/knowledge/patterns/MEM001.md` through `MEM011.md` created.
   - `wiki/docs/knowledge/conventions/MEM012.md` through `MEM020.md` created.
   - `wiki/docs/knowledge/lessons/MEM021.md` through `MEM025.md` created.
   - Four section indexes created.
   - `wiki/mkdocs.yml` nav block now contains a `Knowledge Entries:` subtree.

6. **Verify P01 gates STILL pass after T02 extensions** — these extensions are additive, not destructive. Run:

   ```bash
   bash scripts/verify/m012-p01-phase-suite.sh
   ```

   Expect 9/9 gates PASS. Most relevant P01 gates to watch:
   - `m012-p01-include-plugin.sh` — every new stub must carry an `include-markdown` directive whose target resolves. The `canonical_rel` value (`../../../knowledge/<sub>/<MEM>.md`) must resolve from `wiki/docs/knowledge/<sub>/<MEM>.md` back to the canonical file at repo root.
   - `m012-p01-ssot.sh` — every new stub ≤ 25 lines, exactly one `include-markdown` directive, no body copy. Section indexes are ≤ 25 lines in practice (11 + 9 + 5 entries per category).
   - `m012-p01-nav-structure.sh` — top-level order still Home / Constitution / Decisions / Knowledge / Milestone Summary / Milestones / Archive. The new `Knowledge Entries:` subtree is nested under a DIFFERENT top-level marker than the single `Knowledge:` entry the P01 gate asserts — so P01's top-level check passes. T05's `m012-p02-mem-stubs.sh` gate asserts the new subtree exists.
   - `m012-p01-exclusion-policy.sh` — scanner output still passes exclusion policy. The new `knowledge:<category>` records are NOT under `.orchestrator/scratch|tmp|config/` and ARE `.md` files.
   - `m012-p01-bash32-compat.sh` — both generators still Bash 3.2 compatible.

7. **Optional MEM-anchor probe** (if `mkdocs` is installed locally):

   ```bash
   bash scripts/wiki/wiki-serve.sh --probe
   ```

   This produces a throwaway `site/` directory (P01 `--probe` behavior). Manually inspect the rendered `site/<path-to-KNOWLEDGE-stub>/index.html` for heading anchor ids; note which MEM IDs have matching `#mem-NNNN` anchors. Record the finding in your execution log or task notes — T04 uses this input to write the resolution-policy section in `wiki/README.md` (in particular: whether `KNOWLEDGE.md#mem-NNNN` anchors work against the consolidated file or whether the policy must steer readers to `knowledge/<cat>/MEM###.md` file-path links).

   If `mkdocs` is not installed, skip this step; T04 will document the anchor policy conservatively (file-path references are the canonical link target; anchor references work when the consolidated file carries a matching heading).

## Must-Haves

- `scripts/wiki/wiki-generate-stubs.sh` writes one stub to `wiki/docs/knowledge/<category>/<MEM###>.md` for every `knowledge:<category>` scanner record.
- Each MEM stub is ≤ 25 lines, has exactly one `include-markdown` directive, contains no canonical content body.
- Four section-index files (`wiki/docs/knowledge/index.md` plus three per-category indexes) exist and carry the `Auto-generated section index` comment probe.
- `scripts/wiki/wiki-generate-nav.sh` emits a `Knowledge Entries:` subtree inside the marker-bounded nav block, nested between the existing `Knowledge:` entry and `Milestone Summary:` entry.
- Every MEM stub path appears exactly once in the generated nav block.
- All four section-index paths appear in the nav block (top index under `Knowledge Entries:`; three sub indexes as leading entries under each category).
- `bash scripts/verify/m012-p01-phase-suite.sh` exits 0 after T02 regeneration.
- Both generators remain Bash 3.2 compatible.

## Verification

- `bash scripts/wiki/wiki-generate-stubs.sh` — exits 0 with no stderr warnings.
- `bash scripts/wiki/wiki-generate-nav.sh` — exits 0; `wiki/mkdocs.yml` unchanged outside the marker-bounded region.
- `bash scripts/verify/m012-p01-phase-suite.sh` — 9/9 gates PASS.
- Manual: `find wiki/docs/knowledge -name 'MEM*.md' -not -name 'index.md'` line count equals the count of `knowledge/**/MEM*.md` files on disk (`find knowledge -name 'MEM*.md' -type f`). Any mismatch indicates a missed scanner record or a stub write failure.
- Manual: open one MEM stub (e.g., `wiki/docs/knowledge/patterns/MEM001.md`); confirm the include directive reads `{% include-markdown "../../../knowledge/patterns/MEM001.md" … %}` with correct `../` count.
- T05's `m012-p02-mem-stubs.sh` gate (authored later) provides the mechanical assertion; T02 verification is gated on the P01 suite staying green.

## Inputs

### From Previous Tasks

- `scripts/wiki/wiki-scan-sources.sh` (from T01)
  - Key API: `bash scripts/wiki/wiki-scan-sources.sh [--root PROJECT_ROOT]` emits `<category>|<rel-path>|<title>` records to stdout. Post-T01 record categories: `top:constitution`, `top:decisions`, `top:knowledge`, `top:milestone-summary`, `milestone:M###`, `archive:M###`, `knowledge:patterns`, `knowledge:conventions`, `knowledge:lessons`.
  - Ordering: `.orchestrator/` records (P01 order) first; `knowledge:patterns` (lexical MEM id) next; then `knowledge:conventions`; then `knowledge:lessons`.
  - Rel-path format: repo-root relative (e.g., `knowledge/patterns/MEM001.md`).
- `wiki/mkdocs.yml` (from T01)
  - Key API (settings T02 relies on): `rewrite_relative_urls: true` on the include-markdown plugin is what makes relative links inside included bodies rewrite to the stub's rendered route (so T04's link-check gate can verify end-to-end resolution).
  - Marker pair `# >>> M012-P01 nav` / `# <<< M012-P01 nav end` bounds the nav block. T02 edits add lines strictly inside this region; markers and atomic-write pattern are preserved.

### From Disk (Pre-existing)

- `scripts/wiki/wiki-generate-stubs.sh` — P01 generator. Key internals:
  - Reads scanner stdout into a /tmp cache (PID-suffixed).
  - Writes thin include stubs via a `write_stub` helper (or equivalent inline template).
  - Emits section indexes for `milestones/`, `archive/`, per-M###, per-P##.
- `scripts/wiki/wiki-generate-nav.sh` — P01 generator. Key internals:
  - Reads scanner stdout cache (same /tmp file).
  - Assembles a nav block via single-forward-pass awk state machine.
  - Atomic write via same-directory staged temp + `mv`.
  - Respects marker pair for splice region.
- `knowledge/patterns/MEM001.md` through `MEM011.md`, `knowledge/conventions/MEM012.md` through `MEM020.md`, `knowledge/lessons/MEM021.md` through `MEM025.md` — canonical MEM entry files. Each has YAML frontmatter + `# MEMNNN: <Title>` H1 + body paragraphs.

## Constraints

- **Bash 3.2** — both generators must stay compatible. No `declare -A`, no `mapfile`, no process substitution, no `&>`. MEM001, MEM021 (P01 patterns).
- **AD-3 SSOT** — every new stub is thin (≤ 25 lines, one include directive, no body). Section indexes are legitimately longer but contain only bullet lists, not canonical content. No file under `wiki/docs/knowledge/` has a byte-equal twin under `.orchestrator/` or `knowledge/`.
- **AD-6 nav completeness** — every `knowledge:*` scanner record has exactly one nav leaf in the generated nav block. Duplicates fail T05's `m012-p02-mem-stubs.sh` count-match gate.
- **No modification to P01-visible surfaces beyond the additive extensions** — T02 MUST NOT alter existing `.orchestrator/` stubs under `wiki/docs/`, the existing top-level `Knowledge:` nav entry (which points at the consolidated KNOWLEDGE.md stub), or the marker-bounded structure. A diff of `wiki/mkdocs.yml` outside the nav markers and outside T01's two additions must be empty.
- **Regeneration is idempotent** — running both generators twice produces byte-identical output (P01 idempotency invariant carried forward).
- **Surgical precision (Constitution XV)** — T02 touches exactly two scripts (`wiki-generate-stubs.sh`, `wiki-generate-nav.sh`) and creates the `wiki/docs/knowledge/` subtree plus modifies `wiki/mkdocs.yml`'s nav block region. Nothing else.

## Expected Output

After T02 completes:

1. **Stubs created** — one `.md` per `knowledge/**/MEM*.md` file, under `wiki/docs/knowledge/<category>/<MEM###>.md`. 25 entries total (11 patterns + 9 conventions + 5 lessons, per current repo state).
2. **Section indexes created** — `wiki/docs/knowledge/index.md` plus three per-category `index.md` files.
3. **Nav updated** — `wiki/mkdocs.yml` contains a `Knowledge Entries:` subtree inside the marker-bounded nav block. The subtree has three category branches (Patterns, Conventions, Lessons); each lists its per-category index first and every MEM entry after, in lexical order.
4. **P01 suite STILL green** — `bash scripts/verify/m012-p01-phase-suite.sh` exits 0.
5. **Generators idempotent** — re-running both in sequence produces no diff (`git diff --stat wiki/docs/ wiki/mkdocs.yml` empty after a second run).
6. **Anchor probe note captured** (optional when `mkdocs` absent) — for T04's documentation input.

## State Context

- **Current State**: executing
- **Milestone**: M012
- **Phase**: P02
- **Task**: T02
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **Bash 3.2** — both generators must stay compatible. No `declare -A`, no `mapfile`, no process substitution, no `&>`. MEM001, MEM021 (P01 patterns).
- **AD-3 SSOT** — every new stub is thin (≤ 25 lines, one include directive, no body). Section indexes are legitimately longer but contain only bullet lists, not canonical content. No file under `wiki/docs/knowledge/` has a byte-equal twin under `.orchestrator/` or `knowledge/`.
- **AD-6 nav completeness** — every `knowledge:*` scanner record has exactly one nav leaf in the generated nav block. Duplicates fail T05's `m012-p02-mem-stubs.sh` count-match gate.
- **No modification to P01-visible surfaces beyond the additive extensions** — T02 MUST NOT alter existing `.orchestrator/` stubs under `wiki/docs/`, the existing top-level `Knowledge:` nav entry (which points at the consolidated KNOWLEDGE.md stub), or the marker-bounded structure. A diff of `wiki/mkdocs.yml` outside the nav markers and outside T01's two additions must be empty.
- **Regeneration is idempotent** — running both generators twice produces byte-identical output (P01 idempotency invariant carried forward).
- **Surgical precision (Constitution XV)** — T02 touches exactly two scripts (`wiki-generate-stubs.sh`, `wiki-generate-nav.sh`) and creates the `wiki/docs/knowledge/` subtree plus modifies `wiki/mkdocs.yml`'s nav block region. Nothing else.

### Acceptance Criteria

- `scripts/wiki/wiki-generate-stubs.sh` writes one stub to `wiki/docs/knowledge/<category>/<MEM###>.md` for every `knowledge:<category>` scanner record.
- Each MEM stub is ≤ 25 lines, has exactly one `include-markdown` directive, contains no canonical content body.
- Four section-index files (`wiki/docs/knowledge/index.md` plus three per-category indexes) exist and carry the `Auto-generated section index` comment probe.
- `scripts/wiki/wiki-generate-nav.sh` emits a `Knowledge Entries:` subtree inside the marker-bounded nav block, nested between the existing `Knowledge:` entry and `Milestone Summary:` entry.
- Every MEM stub path appears exactly once in the generated nav block.
- All four section-index paths appear in the nav block (top index under `Knowledge Entries:`; three sub indexes as leading entries under each category).
- `bash scripts/verify/m012-p01-phase-suite.sh` exits 0 after T02 regeneration.
- Both generators remain Bash 3.2 compatible.

### Files To Touch

- `wiki/mkdocs.yml` (modify — assert `rewrite_relative_urls: true` on include-plugin; add `Knowledge Entries` nav subtree via T02's extended nav generator)
- `wiki/README.md` (modify — add "Link resolution" section + "Running the link checker" subsection)
- `scripts/wiki/wiki-scan-sources.sh` (modify — add `knowledge/**/MEM*.md` enumeration with `knowledge:<category>` record category)
- `scripts/wiki/wiki-generate-stubs.sh` (modify — consume `knowledge:<category>` records; emit `wiki/docs/knowledge/<category>/<MEM###>.md` stubs + section indexes)
- `scripts/wiki/wiki-generate-nav.sh` (modify — emit `Knowledge Entries` subtree with per-category subgroups)
- `wiki/docs/knowledge/` (create — directory tree of generated stubs and section indexes; not hand-edited)
- `wiki/docs/knowledge/index.md` (create — top-level section index)
- `wiki/docs/knowledge/patterns/index.md` (create — per-category section index)
- `wiki/docs/knowledge/conventions/index.md` (create — per-category section index)
- `wiki/docs/knowledge/lessons/index.md` (create — per-category section index)
- `wiki/docs/knowledge/patterns/MEM*.md` (create — thin include stubs, one per `knowledge/patterns/MEM*.md`)
- `wiki/docs/knowledge/conventions/MEM*.md` (create — thin include stubs, one per `knowledge/conventions/MEM*.md`)
- `wiki/docs/knowledge/lessons/MEM*.md` (create — thin include stubs, one per `knowledge/lessons/MEM*.md`)
- `scripts/diagnostics/wiki-link-check.sh` (create — Bash 3.2 built-site link walker)
- `scripts/verify/m012-p02-link-rewrite-config.sh` (create)
- `scripts/verify/m012-p02-mem-stubs.sh` (create)
- `scripts/verify/m012-p02-mem-anchors.sh` (create)
- `scripts/verify/m012-p02-link-check-contract.sh` (create)
- `scripts/verify/m012-p02-link-check-help.sh` (create)
- `scripts/verify/m012-p02-readme-policy.sh` (create)
- `scripts/verify/m012-p02-link-check-smoke.sh` (create)
- `scripts/verify/m012-p02-bash32-compat.sh` (create)
- `scripts/verify/m012-p02-d011-evaluation.sh` (create)
- `scripts/verify/m012-p02-phase-suite.sh` (create)
- `.orchestrator/milestones/M012/phases/P02/D011-EVALUATION.md` (create — D011 mechanical-evaluation record)

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