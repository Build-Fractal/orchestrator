---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T05 (Phase P02, Milestone M012)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (25 entries) | 20-589 | ~4900 | filtered |
| Decisions | 591-593 | ~100 | filtered |
| Constraints | 595-628 | ~400 | required |
| Scope | 630-658 | ~600 | required |
| Upstream Context | 660-730 | ~3600 | required |
| Task Plan | 732-1271 | ~6800 | required |
| State Context | 1273-1279 | ~100 | required |
| First-Turn Completeness | 1281-1334 | ~1200 | required |
| **Total** | | **~17700** | |

## Knowledge

<!-- 25 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 321
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
hit_count: 321
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
hit_count: 321
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
hit_count: 321
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
hit_count: 288
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
hit_count: 288
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
hit_count: 288
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
hit_count: 321
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
hit_count: 288
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
hit_count: 288
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
hit_count: 288
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
hit_count: 321
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
hit_count: 321
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
hit_count: 321
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
hit_count: 288
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
hit_count: 288
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
hit_count: 288
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
hit_count: 321
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
hit_count: 288
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
hit_count: 288
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
hit_count: 321
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
hit_count: 321
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
hit_count: 288
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
hit_count: 288
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
hit_count: 288
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

- KNOWLEDGE anchor links of the form `KNOWLEDGE.md#mem-NNNN` (or `#MEM-NNNN`, case-insensitive per MkDocs' slug normalization) resolve to the rendered [`.orchestrator/KNOWLEDGE.md`](../../../../knowledge.md) stub's heading anchor for that MEM entry — verified by scraping the rendered KNOWLEDGE HTML page for a heading with a matching anchor id (D011 criterion (a); AD-1).
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
task: "T05"
phase: "P02"
milestone: "M012"
name: "P02 verification suite + D011-EVALUATION.md + phase-suite orchestrator"
depends_on: ["T04"]
---

## Prerequisites

- T01–T04 complete:
  - `wiki/mkdocs.yml` has link-rewriting config.
  - `wiki/docs/knowledge/**` stub tree populated; nav updated with `Knowledge Entries:` subtree.
  - `scripts/diagnostics/wiki-link-check.sh` exists, executable, contract verified.
  - `wiki/README.md` has "Link resolution", "Running the link checker", and "Pre-deploy integration (P04)" sections.
  - `bash scripts/verify/m012-p01-phase-suite.sh` still exits 0.
- No P02 verify scripts exist yet. T05 creates all of them plus the phase-suite orchestrator plus the D011 evaluation record.

## Description

Ship the nine M012/P02 verification gates + phase-suite orchestrator, following the exact pattern P01/T05 established. Each gate is an AD-19 single-invocation Bash 3.2 script callable as a Truth `Check:` command. Plus: ship the `D011-EVALUATION.md` artifact — a structured record of the mechanical 1-of-3 outcome that the roadmap's cross-cutting concern commits to producing at P02 close.

### Nine gates (one per Truth in P02-PLAN.md)

1. `m012-p02-link-rewrite-config.sh` — asserts `wiki/mkdocs.yml` has `rewrite_relative_urls: true` on include-markdown and `toc: { permalink: true }` under `markdown_extensions:`.
2. `m012-p02-mem-stubs.sh` — asserts `wiki/docs/knowledge/<category>/<MEM###>.md` exists for every `knowledge/<category>/MEM*.md`; each stub ≤ 25 lines; each carries one include-markdown directive; four section-index files present.
3. `m012-p02-mem-anchors.sh` — when mkdocs is available, builds the site to a throwaway directory and checks that the rendered KNOWLEDGE page has at least one heading anchor matching `id="mem-…"` form (proves the anchor-resolution chain is functional). When mkdocs is absent, emits `SKIP:` and exits 0.
4. `m012-p02-link-check-contract.sh` — asserts `scripts/diagnostics/wiki-link-check.sh` exists, is executable, emits structured `BROKEN:` / `OUT-OF-SCOPE:` lines on a synthetic fixture, produces `PASS:` or `FAIL:` summary, and exits 0/1 correctly. Uses a self-contained HTML fixture under `/tmp/` — does not require mkdocs.
5. `m012-p02-link-check-help.sh` — asserts `bash scripts/diagnostics/wiki-link-check.sh --help` exits 0 and output mentions `--site`, `--root`, `--strict`, "In-scope", "Out-of-scope", "Broken".
6. `m012-p02-readme-policy.sh` — asserts `wiki/README.md` has the three required headings, mentions `wiki-link-check.sh`, mentions `mkdocs build --strict`, has ≥ 80 lines.
7. `m012-p02-link-check-smoke.sh` — if mkdocs is available, runs `wiki-serve.sh --probe` to produce a real build, then runs `wiki-link-check.sh --site <probe-site>`, asserts exit 0. If mkdocs is absent, emits `SKIP: mkdocs not installed` and exits 0 (Tier 1 skip-as-PASS; Tier 4 UAT covers the real thing).
8. `m012-p02-bash32-compat.sh` — scans every `.sh` file created or touched by P02 (`scripts/diagnostics/wiki-link-check.sh`, every `scripts/verify/m012-p02-*.sh`, and the T01/T02 edits to `scripts/wiki/wiki-*.sh`) for Bash 4-only constructs.
9. `m012-p02-d011-evaluation.sh` — asserts [`.orchestrator/milestones/M012/phases/P02/D011-EVALUATION.md`](../../../../milestones/M012/phases/P02/D011-EVALUATION.md) exists with the required frontmatter + body shape + "[M020](../../../../milestones/M020/index.md) promoted" conclusion.

Plus the orchestrator:

10. `m012-p02-phase-suite.sh` — runs the nine gates, emits one `GATE: <name> PASS|FAIL` per gate, summary to stderr, exits 0 iff all nine pass.

## Steps

1. **Create [`.orchestrator/milestones/M012/phases/P02/D011-EVALUATION.md`](../../../../milestones/M012/phases/P02/D011-EVALUATION.md)** — the structured record. Body shape:

   ```markdown
   ---
   schema_version: "1.0"
   type: d011-evaluation
   milestone: "M012"
   phase: "P02"
   decision: "D011"
   ---

   # D011 Mechanical Evaluation — M012/P02 close

   Per [`.orchestrator/DECISIONS.md`](../../../../decisions.md) D011 and [`.orchestrator/milestones/M012/M012-CONTEXT.md`](../../../../milestones/M012/M012-CONTEXT.md)
   AD-1, this evaluation counts how many of D011's three criteria M012 ships.
   The count is mechanical: it does not reassess the decision, it records the
   outcome of the decision-in-effect.

   ## Criteria

   | # | Criterion | Shipped in M012? | Evidence |
   |---|-----------|------------------|----------|
   | a | Cross-refs to `knowledge/**/MEM*.md` | **Yes** | M012/P02/T01 (scanner extension) + M012/P02/T02 (stub + nav generation) + M012/P02/T03 (link checker validates resolution). Rendered wiki resolves `knowledge/<cat>/MEM###.md` file-path references to rendered stub routes; see `wiki/README.md` "Link resolution" section. |
   | b | Reviewed/unreviewed state per page | **No** | Explicitly deferred to M020 per AD-1 (speculative complexity for a dogfood wiki — Constitution XIV). No review-state UI, metadata, or workflow ships in M012. |
   | c | Dispatch-callable query surface | **No** | Explicitly deferred to M020 per AD-1. The wiki is a read-only rendering surface; no programmatic query API, no MCP/CLI query tool, no index-as-service. |

   ## Outcome

   **1 of 3 criteria shipped → M020 is PROMOTED** per D011's trigger rule
   (≤ 1 of 3 → promote as a committed milestone).

   ## Downstream implication

   Post-M012 the roadmap is updated to position M020 between [M014](../../../../milestones/M014/index.md) and [M019](../../../../milestones/M019/index.md)
   Tier 2/3, per D011's framing (see [`.orchestrator/DECISIONS.md`](../../../../decisions.md) D011 for the
   positioning rationale). That roadmap update is NOT part of M012/P02 —
   M012's phase closes with this record emitted; the roadmap adjustment is a
   consolidation-time action (`speckit.orchestrator.consolidate` on M012
   close, or whenever the roadmap is next regenerated).

   ## References

   - [`.orchestrator/DECISIONS.md`](../../../../decisions.md) — D011 (trigger rule + criteria definitions).
   - [`.orchestrator/milestones/M012/M012-CONTEXT.md`](../../../../milestones/M012/M012-CONTEXT.md) — AD-1 (criteria selection rationale).
   - [`.orchestrator/milestones/M012/M012-ROADMAP.md`](../../../../milestones/M012/M012-ROADMAP.md) — cross-cutting-concern bullet committing this evaluation to P02.
   - `.orchestrator/milestones/M012/phases/P02/P02-PLAN.md` — D011-EVALUATION artifact listed in Artifacts and Key Links.
   ```

   The file must contain the literal string "M020 promoted" (T05's gate asserts on it). Line count ≥ 30.

2. **Create `scripts/verify/m012-p02-link-rewrite-config.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p02-link-rewrite-config.sh — M012/P02 gate 1.
   # Asserts wiki/mkdocs.yml has rewrite_relative_urls and toc permalink.
   set -u
   ROOT="${1:-$(pwd)}"
   ymlfile="$ROOT/wiki/mkdocs.yml"
   [ -f "$ymlfile" ] || { printf 'FAIL: mkdocs.yml missing: %s\n' "$ymlfile"; exit 1; }
   grep -qF 'rewrite_relative_urls: true' "$ymlfile" \
     || { printf 'FAIL: missing "rewrite_relative_urls: true" in %s\n' "$ymlfile"; exit 1; }
   grep -qE '^[[:space:]]*-[[:space:]]*toc' "$ymlfile" \
     || { printf 'FAIL: missing "- toc" in markdown_extensions of %s\n' "$ymlfile"; exit 1; }
   grep -qE 'permalink:[[:space:]]*true' "$ymlfile" \
     || { printf 'FAIL: missing "permalink: true" under toc in %s\n' "$ymlfile"; exit 1; }
   printf 'PASS: link-rewrite config present\n'
   exit 0
   ```

3. **Create `scripts/verify/m012-p02-mem-stubs.sh`**:

   ```bash
   #!/usr/bin/env bash
   # M012/P02 gate 2 — knowledge stubs + section indexes.
   set -u
   ROOT="${1:-$(pwd)}"
   src_count=$(find "$ROOT/knowledge" -type f -name 'MEM*.md' 2>/dev/null | wc -l | tr -d ' ')
   stub_count=$(find "$ROOT/wiki/docs/knowledge" -type f -name 'MEM*.md' \
                  -not -name 'index.md' 2>/dev/null | wc -l | tr -d ' ')
   if [ "$src_count" != "$stub_count" ]; then
     printf 'FAIL: MEM stub count %s != source count %s\n' "$stub_count" "$src_count"
     exit 1
   fi
   # Each stub must be ≤ 25 lines and carry exactly one include-markdown directive.
   find "$ROOT/wiki/docs/knowledge" -type f -name 'MEM*.md' \
     -not -name 'index.md' | while IFS= read -r stub; do
       lines=$(wc -l < "$stub" | tr -d ' ')
       if [ "$lines" -gt 25 ]; then
         printf 'FAIL: %s has %s lines (> 25)\n' "$stub" "$lines"
         exit 1
       fi
       incs=$(grep -c 'include-markdown' "$stub")
       if [ "$incs" != "1" ]; then
         printf 'FAIL: %s has %s include-markdown directives (expected 1)\n' "$stub" "$incs"
         exit 1
       fi
     done
   # Four section indexes.
   for p in \
     "$ROOT/wiki/docs/knowledge/index.md" \
     "$ROOT/wiki/docs/knowledge/patterns/index.md" \
     "$ROOT/wiki/docs/knowledge/conventions/index.md" \
     "$ROOT/wiki/docs/knowledge/lessons/index.md"; do
     [ -f "$p" ] || { printf 'FAIL: missing section index %s\n' "$p"; exit 1; }
     grep -qF 'Auto-generated section index' "$p" \
       || { printf 'FAIL: %s missing "Auto-generated section index" probe\n' "$p"; exit 1; }
   done
   printf 'PASS: %s MEM stubs + 4 section indexes present\n' "$stub_count"
   exit 0
   ```

   Note the `while | exit 1` pattern requires a workaround on Bash 3.2 (exit in subshell doesn't propagate). Use a findings-file approach instead:

   ```bash
   fails="/tmp/m012-p02-mem-stubs.$$"
   : > "$fails"
   find "$ROOT/wiki/docs/knowledge" -type f -name 'MEM*.md' \
     -not -name 'index.md' > "/tmp/m012-p02-mem-stubs.list.$$"
   while IFS= read -r stub; do
     [ -n "$stub" ] || continue
     lines=$(wc -l < "$stub" | tr -d ' ')
     [ "$lines" -le 25 ] || echo "FAIL: $stub has $lines lines" >> "$fails"
     incs=$(grep -c 'include-markdown' "$stub")
     [ "$incs" = "1" ] || echo "FAIL: $stub has $incs include dirs" >> "$fails"
   done < "/tmp/m012-p02-mem-stubs.list.$$"
   rm -f "/tmp/m012-p02-mem-stubs.list.$$"
   if [ -s "$fails" ]; then
     cat "$fails"
     rm -f "$fails"
     exit 1
   fi
   rm -f "$fails"
   ```

4. **Create `scripts/verify/m012-p02-mem-anchors.sh`**:

   ```bash
   #!/usr/bin/env bash
   # M012/P02 gate 3 — rendered KNOWLEDGE page has MEM heading anchors.
   set -u
   ROOT="${1:-$(pwd)}"
   if ! command -v mkdocs >/dev/null 2>&1; then
     printf 'SKIP: mkdocs not installed — anchor check deferred to Tier 4 UAT\n'
     exit 0
   fi
   probe_dir="/tmp/m012-p02-anchors.$$"
   mkdir -p "$probe_dir"
   trap 'rm -rf "$probe_dir"' EXIT
   (cd "$ROOT/wiki" && mkdocs build --site-dir "$probe_dir" --quiet) \
     || { printf 'FAIL: mkdocs build failed\n'; exit 1; }
   # Find the rendered KNOWLEDGE.md page.
   knowledge_html=$(find "$probe_dir" -type f -name 'index.html' -path '*knowledge*' \
                     | head -n 1)
   [ -n "$knowledge_html" ] || { printf 'FAIL: rendered KNOWLEDGE page not found in %s\n' "$probe_dir"; exit 1; }
   # MEM anchors may be either from consolidated KNOWLEDGE.md headings OR
   # from per-entry stubs (T02). Either form is acceptable for the gate.
   if grep -qiE 'id="mem[-_]?[0-9]+"' "$knowledge_html"; then
     printf 'PASS: KNOWLEDGE renders with at least one MEM heading anchor\n'
     exit 0
   fi
   # If the consolidated page lacks MEM anchors, check that at least one
   # per-entry MEM stub renders with a heading anchor.
   mem_stub_html=$(find "$probe_dir" -type f -name 'index.html' \
                     -path '*knowledge/patterns/MEM*' | head -n 1)
   if [ -n "$mem_stub_html" ] && grep -qiE 'id="mem[-_]?[0-9]+"' "$mem_stub_html"; then
     printf 'PASS: MEM stub renders with heading anchor (per-entry path)\n'
     exit 0
   fi
   printf 'FAIL: no MEM heading anchor found in rendered output\n'
   exit 1
   ```

5. **Create `scripts/verify/m012-p02-link-check-contract.sh`**:

   ```bash
   #!/usr/bin/env bash
   # M012/P02 gate 4 — link-check script contract via synthetic fixture.
   set -u
   ROOT="${1:-$(pwd)}"
   script="$ROOT/scripts/diagnostics/wiki-link-check.sh"
   [ -x "$script" ] || { printf 'FAIL: %s not executable\n' "$script"; exit 1; }
   # Build a synthetic fixture: two HTML pages with a mix of in-scope / broken / external links.
   fx="/tmp/m012-p02-linkfx.$$"
   mkdir -p "$fx/sub"
   trap 'rm -rf "$fx"' EXIT
   cat > "$fx/index.html" <<'EOF'
   <html><body>
   <a href="sub/target.html">ok internal</a>
   <a href="sub/missing.html">broken internal</a>
   <a href="https://example.com/">external</a>
   <a href="#nope">broken anchor</a>
   </body></html>
   EOF
   cat > "$fx/sub/target.html" <<'EOF'
   <html><body><h1 id="hdr">hi</h1></body></html>
   EOF
   out=$(bash "$script" --site "$fx" 2>&1)
   rc=$?
   echo "$out" | grep -q 'BROKEN:.*sub/missing.html' \
     || { printf 'FAIL: missing BROKEN line for sub/missing.html\n%s\n' "$out"; exit 1; }
   echo "$out" | grep -q 'OUT-OF-SCOPE:.*example.com' \
     || { printf 'FAIL: missing OUT-OF-SCOPE line for example.com\n%s\n' "$out"; exit 1; }
   echo "$out" | grep -q 'BROKEN:.*#nope' \
     || { printf 'FAIL: missing BROKEN line for #nope anchor\n%s\n' "$out"; exit 1; }
   echo "$out" | grep -qE '^FAIL: [0-9]+ broken' \
     || { printf 'FAIL: missing FAIL summary\n%s\n' "$out"; exit 1; }
   [ "$rc" = "1" ] || { printf 'FAIL: expected exit 1, got %s\n' "$rc"; exit 1; }
   printf 'PASS: link-check contract verified against synthetic fixture\n'
   exit 0
   ```

6. **Create `scripts/verify/m012-p02-link-check-help.sh`**:

   ```bash
   #!/usr/bin/env bash
   # M012/P02 gate 5 — --help usage block.
   set -u
   ROOT="${1:-$(pwd)}"
   script="$ROOT/scripts/diagnostics/wiki-link-check.sh"
   out=$(bash "$script" --help 2>&1)
   rc=$?
   [ "$rc" = "0" ] || { printf 'FAIL: --help exit %s\n' "$rc"; exit 1; }
   for kw in "--site" "--root" "--strict" "In-scope" "Out-of-scope" "Broken"; do
     echo "$out" | grep -qF "$kw" \
       || { printf 'FAIL: --help missing keyword: %s\n' "$kw"; exit 1; }
   done
   printf 'PASS: --help enumerates all flags and classification rules\n'
   exit 0
   ```

7. **Create `scripts/verify/m012-p02-readme-policy.sh`**:

   ```bash
   #!/usr/bin/env bash
   # M012/P02 gate 6 — wiki/README.md link-resolution policy section.
   set -u
   ROOT="${1:-$(pwd)}"
   f="$ROOT/wiki/README.md"
   [ -f "$f" ] || { printf 'FAIL: %s missing\n' "$f"; exit 1; }
   for hdr in \
     '^## Link resolution$' \
     '^## Running the link checker$' \
     '^## Pre-deploy integration (P04)$'; do
     count=$(grep -c -E "$hdr" "$f")
     [ "$count" = "1" ] || { printf 'FAIL: %s — expected 1 match for %s, got %s\n' "$f" "$hdr" "$count"; exit 1; }
   done
   grep -qF 'wiki-link-check.sh' "$f" \
     || { printf 'FAIL: README missing wiki-link-check.sh reference\n'; exit 1; }
   grep -qF 'mkdocs build --strict' "$f" \
     || { printf 'FAIL: README missing "mkdocs build --strict" reference\n'; exit 1; }
   lines=$(wc -l < "$f" | tr -d ' ')
   [ "$lines" -ge 80 ] || { printf 'FAIL: README %s lines (< 80)\n' "$lines"; exit 1; }
   printf 'PASS: README policy section present (%s lines)\n' "$lines"
   exit 0
   ```

8. **Create `scripts/verify/m012-p02-link-check-smoke.sh`**:

   ```bash
   #!/usr/bin/env bash
   # M012/P02 gate 7 — end-to-end smoke against a real mkdocs build.
   set -u
   ROOT="${1:-$(pwd)}"
   if ! command -v mkdocs >/dev/null 2>&1; then
     printf 'SKIP: mkdocs not installed — link-check smoke deferred to Tier 4 UAT\n'
     exit 0
   fi
   probe="/tmp/m012-p02-linksmoke.$$"
   mkdir -p "$probe"
   trap 'rm -rf "$probe"' EXIT
   (cd "$ROOT/wiki" && mkdocs build --site-dir "$probe" --quiet) \
     || { printf 'FAIL: mkdocs build failed\n'; exit 1; }
   out=$(bash "$ROOT/scripts/diagnostics/wiki-link-check.sh" --site "$probe" 2>&1)
   rc=$?
   if [ "$rc" != "0" ]; then
     printf 'FAIL: link-check against real build exit %s\n%s\n' "$rc" "$out"
     exit 1
   fi
   echo "$out" | grep -qE '^PASS: 0 broken' \
     || { printf 'FAIL: link-check stdout missing PASS summary\n%s\n' "$out"; exit 1; }
   printf 'PASS: real-build link-check clean\n'
   exit 0
   ```

9. **Create `scripts/verify/m012-p02-bash32-compat.sh`**:

   ```bash
   #!/usr/bin/env bash
   # M012/P02 gate 8 — Bash 3.2 compat for every P02-touched .sh.
   set -u
   ROOT="${1:-$(pwd)}"
   targets="/tmp/m012-p02-bash32.$$"
   : > "$targets"
   echo "$ROOT/scripts/diagnostics/wiki-link-check.sh" >> "$targets"
   find "$ROOT/scripts/verify" -type f -name 'm012-p02-*.sh' >> "$targets"
   echo "$ROOT/scripts/wiki/wiki-scan-sources.sh" >> "$targets"
   echo "$ROOT/scripts/wiki/wiki-generate-stubs.sh" >> "$targets"
   echo "$ROOT/scripts/wiki/wiki-generate-nav.sh" >> "$targets"
   # Patterns to forbid (parallel arrays — PAT_REGEX_* / PAT_LABEL_*, P01 pattern).
   PAT_REGEX_0='declare -A'
   PAT_LABEL_0='declare -A (Bash 4 associative array)'
   PAT_REGEX_1='mapfile'
   PAT_LABEL_1='mapfile (Bash 4 builtin)'
   PAT_REGEX_2='readarray'
   PAT_LABEL_2='readarray (Bash 4 builtin)'
   PAT_REGEX_3='\$\{[A-Za-z_][A-Za-z0-9_]*\^\^\}'
   PAT_LABEL_3='${var^^} (Bash 4 uppercase expansion)'
   PAT_REGEX_4='\$\{[A-Za-z_][A-Za-z0-9_]*,,\}'
   PAT_LABEL_4='${var,,} (Bash 4 lowercase expansion)'
   PAT_REGEX_5='<\('
   PAT_LABEL_5='<(...) (process substitution)'
   PAT_REGEX_6='>\('
   PAT_LABEL_6='>(...) (process substitution)'
   PAT_REGEX_7='&>'
   PAT_LABEL_7='&> (Bash 4 merge redirect)'
   fails="/tmp/m012-p02-bash32-fails.$$"
   : > "$fails"
   while IFS= read -r f; do
     [ -n "$f" ] || continue
     [ -f "$f" ] || continue
     i=0
     while [ "$i" -le 7 ]; do
       eval "rx=\"\$PAT_REGEX_$i\""
       eval "lbl=\"\$PAT_LABEL_$i\""
       # Match non-comment lines only (strip leading #-prefixed lines).
       # Also skip assignment-line self-scan carve-out (lines beginning with PAT_REGEX_ or PAT_LABEL_).
       grep -nE "$rx" "$f" 2>/dev/null \
         | grep -v '^[0-9]*:[[:space:]]*#' \
         | grep -v 'PAT_REGEX_' \
         | grep -v 'PAT_LABEL_' \
         | while IFS= read -r hit; do
             [ -n "$hit" ] || continue
             printf 'FAIL: %s — %s: %s\n' "$f" "$lbl" "$hit" >> "$fails"
           done
       i=$((i + 1))
     done
   done < "$targets"
   rm -f "$targets"
   if [ -s "$fails" ]; then
     cat "$fails"
     rm -f "$fails"
     exit 1
   fi
   rm -f "$fails"
   printf 'PASS: all P02 .sh files are Bash 3.2 compatible\n'
   exit 0
   ```

10. **Create `scripts/verify/m012-p02-d011-evaluation.sh`**:

    ```bash
    #!/usr/bin/env bash
    # M012/P02 gate 9 — D011-EVALUATION.md record.
    set -u
    ROOT="${1:-$(pwd)}"
    f="$ROOT/.orchestrator/milestones/M012/phases/P02/D011-EVALUATION.md"
    [ -f "$f" ] || { printf 'FAIL: %s missing\n' "$f"; exit 1; }
    lines=$(wc -l < "$f" | tr -d ' ')
    [ "$lines" -ge 30 ] || { printf 'FAIL: D011-EVALUATION.md %s lines (< 30)\n' "$lines"; exit 1; }
    # Frontmatter sanity.
    head -n 10 "$f" | grep -qE '^decision:[[:space:]]*"?D011"?' \
      || { printf 'FAIL: frontmatter missing decision: D011\n'; exit 1; }
    head -n 10 "$f" | grep -qE '^milestone:[[:space:]]*"?M012"?' \
      || { printf 'FAIL: frontmatter missing milestone: M012\n'; exit 1; }
    grep -qF 'M020 promoted' "$f" \
      || { printf 'FAIL: missing "M020 promoted" conclusion\n'; exit 1; }
    # Three criteria rows.
    grep -qE 'Cross-refs' "$f" || { printf 'FAIL: missing criterion (a) Cross-refs row\n'; exit 1; }
    grep -qE 'Reviewed' "$f"   || { printf 'FAIL: missing criterion (b) Reviewed row\n'; exit 1; }
    grep -qE 'query surface' "$f" || { printf 'FAIL: missing criterion (c) query surface row\n'; exit 1; }
    # Reference block cites DECISIONS.md and M012-CONTEXT.md.
    grep -qF 'DECISIONS.md' "$f" || { printf 'FAIL: missing DECISIONS.md reference\n'; exit 1; }
    grep -qF 'M012-CONTEXT.md' "$f" || { printf 'FAIL: missing M012-CONTEXT.md reference\n'; exit 1; }
    printf 'PASS: D011-EVALUATION.md structured correctly (%s lines)\n' "$lines"
    exit 0
    ```

11. **Create `scripts/verify/m012-p02-phase-suite.sh`** — the orchestrator (same pattern as P01/T05):

    ```bash
    #!/usr/bin/env bash
    # scripts/verify/m012-p02-phase-suite.sh — runs all nine M012/P02 gates.
    set -u
    ROOT="${1:-$(pwd)}"
    gates=(
      "m012-p02-link-rewrite-config.sh"
      "m012-p02-mem-stubs.sh"
      "m012-p02-mem-anchors.sh"
      "m012-p02-link-check-contract.sh"
      "m012-p02-link-check-help.sh"
      "m012-p02-readme-policy.sh"
      "m012-p02-link-check-smoke.sh"
      "m012-p02-bash32-compat.sh"
      "m012-p02-d011-evaluation.sh"
    )
    passed=0
    total=${#gates[@]}
    for g in "${gates[@]}"; do
      if bash "$ROOT/scripts/verify/$g" "$ROOT"; then
        printf 'GATE: %s PASS\n' "$g"
        passed=$((passed + 1))
      else
        printf 'GATE: %s FAIL\n' "$g"
      fi
    done
    printf 'SUMMARY: %d/%d gates passed\n' "$passed" "$total" >&2
    [ "$passed" -eq "$total" ]
    ```

12. **Make every verify script executable**:

    ```bash
    chmod 755 scripts/verify/m012-p02-*.sh
    ```

13. **Smoke-run the phase-suite**:

    ```bash
    bash scripts/verify/m012-p02-phase-suite.sh
    ```

    Expect `9/9 gates passed`. If any gate fails, diagnose via the per-gate FAIL line, fix the underlying T01–T04 output (not the gate — the gate is the contract), and re-run.

    On a host WITHOUT mkdocs installed, gates 3 (`mem-anchors`) and 7 (`link-check-smoke`) will print `SKIP:` and exit 0 — the phase-suite still reports 9/9 PASS because SKIP maps to PASS at the gate boundary (Tier 1 acceptable; Tier 4 UAT is the path that actually exercises mkdocs).

14. **Confirm the must-haves harness agrees**:

    ```bash
    bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P02
    ```

    Should report all Truth `Check:` commands PASS, all Artifacts (min-lines + contains) PASS, all Key Links PASS. Any FAIL here indicates a mismatch between the P02-PLAN.md assertions and the on-disk state — fix the plan OR fix the on-disk state (prefer the latter; the plan's assertions are the contract).

## Must-Haves

- Nine `scripts/verify/m012-p02-*.sh` files exist, all executable, all Bash 3.2 compliant.
- `scripts/verify/m012-p02-phase-suite.sh` exists, is executable, runs all nine gates.
- `bash scripts/verify/m012-p02-phase-suite.sh` exits 0 against clean T01–T04 output (gates 3 and 7 may SKIP when mkdocs is absent; SKIP maps to PASS).
- [`.orchestrator/milestones/M012/phases/P02/D011-EVALUATION.md`](../../../../milestones/M012/phases/P02/D011-EVALUATION.md) exists, ≥ 30 lines, contains "M020 promoted", frontmatter has `decision: D011` and `milestone: M012`, body enumerates all three criteria and cites DECISIONS.md + M012-CONTEXT.md.
- `bash scripts/verify/m012-p01-phase-suite.sh` still exits 0 (P02 must not regress P01).
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P02` — all assertions PASS.
- Each gate emits one `PASS:` / `FAIL:` / `SKIP:` line to stdout.
- Each gate is individually invokable without the phase-suite harness (accepts `$1` as `ROOT` override; defaults to `$(pwd)`).

## Verification

- `bash scripts/verify/m012-p02-phase-suite.sh` — the suite's own exit code is the phase's exit code.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P02` — confirms artifact paths + patterns (every verify script + the D011 artifact listed in Artifacts section).
- `bash scripts/verify/m012-p01-phase-suite.sh` — still 9/9 green.
- Self-test: run `m012-p02-phase-suite.sh` twice in a row; exit code identical (no hidden state).
- Self-test: temporarily rename `wiki/mkdocs.yml`; run suite; expect `link-rewrite-config` (and likely others) to FAIL with actionable messages. Restore.
- Self-test: temporarily remove `M020 promoted` from D011-EVALUATION.md; run suite; expect `d011-evaluation` to FAIL. Restore.

## Inputs

### From Previous Tasks

- **T01** — `wiki/mkdocs.yml` settings and extended scanner. Contract used by gate 1 (`link-rewrite-config`) and indirectly by every other gate that depends on the scanner's `knowledge:<category>` output.
- **T02** — `wiki/docs/knowledge/` stub tree + `Knowledge Entries:` nav subtree. Contract used by gate 2 (`mem-stubs`).
- **T03** — `scripts/diagnostics/wiki-link-check.sh`:
  - Key API: `--site <dir>` (default `wiki/site`), `--root <dir>`, `--strict`, `--help`.
  - Output: `BROKEN:` / `OUT-OF-SCOPE:` lines; last stdout line `PASS:` or `FAIL:`.
  - Exit: 0 / 1 / 2.
  Contract used by gates 4, 5, 7.
- **T04** — `wiki/README.md` with three new headings + required mentions. Contract used by gate 6.

### From Disk (Pre-existing)

- `scripts/verify/check-must-haves.sh` — the orchestrator's canonical verification harness; consumes the phase plan's Truths + Artifacts + Key Links and runs them. T05 must produce a phase plan + on-disk state that satisfies this harness.
- [`.orchestrator/DECISIONS.md`](../../../../decisions.md) — D011 content (cited by the D011-EVALUATION.md record).
- [`.orchestrator/milestones/M012/M012-CONTEXT.md`](../../../../milestones/M012/M012-CONTEXT.md) — AD-1 (cited by the D011-EVALUATION.md record).
- [`.orchestrator/milestones/M012/M012-ROADMAP.md`](../../../../milestones/M012/M012-ROADMAP.md) — cross-cutting-concern bullet committing the D011 evaluation to P02 close.
- P01 verify scripts (`scripts/verify/m012-p01-*.sh`) — the shape P02 gates mirror; gate 8's `bash32-compat.sh` directly reuses P01's parallel-indexed-array pattern.

## Constraints

- **Bash 3.2** — every verify script (same discipline as P01). MEM001.
- **MEM004 carve-out applies** — gate internals may use pipes, `grep -oE`, `sed`, `awk`, `find | sort`, PID-suffixed temp files. The AD-19 shape constraint applies to the Truth `Check:` commands in P02-PLAN.md (which are single `bash scripts/verify/m012-p02-*.sh` invocations).
- **SKIP-as-PASS** — gates that depend on mkdocs (3, 7) must SKIP cleanly when mkdocs is absent, emitting an explicit `SKIP:` line and exiting 0. Silent pass is NOT acceptable; readers need to see that a check was skipped.
- **Read-only against repo state** — every gate may write to `/tmp/` only. `trap` cleans temp files on exit.
- **Deterministic** — identical T01–T04 output → identical gate outputs across runs.
- **Root-override pattern** — each gate accepts `$1` as a project-root override, defaulting to `$(pwd)`. This supports the phase-suite orchestrator passing `$ROOT` and supports fixture-based testing without requiring invocation from the repo root.
- **No compound bash in Truth `Check:` commands** (AD-19) — every Check in P02-PLAN.md is a single-script-file invocation. Internals of the scripts may use whatever Bash 3.2 features are needed.
- **Surgical precision (Constitution XV)** — T05 creates exactly ten files under `scripts/verify/` (nine gates + one suite) plus one under `.orchestrator/milestones/M012/phases/P02/` (D011-EVALUATION.md). No files outside those two directories are touched.

## Expected Output

After T05 completes:

1. Nine gate scripts + one phase-suite orchestrator under `scripts/verify/` with `m012-p02-` prefix, all executable, all Bash 3.2 compliant.
2. [`.orchestrator/milestones/M012/phases/P02/D011-EVALUATION.md`](../../../../milestones/M012/phases/P02/D011-EVALUATION.md) exists, structured as documented, ≥ 30 lines.
3. `bash scripts/verify/m012-p02-phase-suite.sh` exits 0 (9/9 green; gates 3 and 7 may SKIP on hosts without mkdocs).
4. `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P02` — all Truths, Artifacts, Key Links PASS.
5. `bash scripts/verify/m012-p01-phase-suite.sh` — still 9/9 green (P02 did not regress P01).
6. Derived state via `bash scripts/state/derive-phase.sh .orchestrator/milestones/M012` — advances from `executing` to the next state according to state-machine rules once P02-SUMMARY.md lands (produced by the verify-and-summarize step at phase close, not by this task).

## State Context

- **Current State**: executing
- **Milestone**: M012
- **Phase**: P02
- **Task**: T05
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **Bash 3.2** — every verify script (same discipline as P01). MEM001.
- **MEM004 carve-out applies** — gate internals may use pipes, `grep -oE`, `sed`, `awk`, `find | sort`, PID-suffixed temp files. The AD-19 shape constraint applies to the Truth `Check:` commands in P02-PLAN.md (which are single `bash scripts/verify/m012-p02-*.sh` invocations).
- **SKIP-as-PASS** — gates that depend on mkdocs (3, 7) must SKIP cleanly when mkdocs is absent, emitting an explicit `SKIP:` line and exiting 0. Silent pass is NOT acceptable; readers need to see that a check was skipped.
- **Read-only against repo state** — every gate may write to `/tmp/` only. `trap` cleans temp files on exit.
- **Deterministic** — identical T01–T04 output → identical gate outputs across runs.
- **Root-override pattern** — each gate accepts `$1` as a project-root override, defaulting to `$(pwd)`. This supports the phase-suite orchestrator passing `$ROOT` and supports fixture-based testing without requiring invocation from the repo root.
- **No compound bash in Truth `Check:` commands** (AD-19) — every Check in P02-PLAN.md is a single-script-file invocation. Internals of the scripts may use whatever Bash 3.2 features are needed.
- **Surgical precision (Constitution XV)** — T05 creates exactly ten files under `scripts/verify/` (nine gates + one suite) plus one under `.orchestrator/milestones/M012/phases/P02/` (D011-EVALUATION.md). No files outside those two directories are touched.

### Acceptance Criteria

- Nine `scripts/verify/m012-p02-*.sh` files exist, all executable, all Bash 3.2 compliant.
- `scripts/verify/m012-p02-phase-suite.sh` exists, is executable, runs all nine gates.
- `bash scripts/verify/m012-p02-phase-suite.sh` exits 0 against clean T01–T04 output (gates 3 and 7 may SKIP when mkdocs is absent; SKIP maps to PASS).
- [`.orchestrator/milestones/M012/phases/P02/D011-EVALUATION.md`](../../../../milestones/M012/phases/P02/D011-EVALUATION.md) exists, ≥ 30 lines, contains "M020 promoted", frontmatter has `decision: D011` and `milestone: M012`, body enumerates all three criteria and cites DECISIONS.md + M012-CONTEXT.md.
- `bash scripts/verify/m012-p01-phase-suite.sh` still exits 0 (P02 must not regress P01).
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P02` — all assertions PASS.
- Each gate emits one `PASS:` / `FAIL:` / `SKIP:` line to stdout.
- Each gate is individually invokable without the phase-suite harness (accepts `$1` as `ROOT` override; defaults to `$(pwd)`).

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
- [`.orchestrator/milestones/M012/phases/P02/D011-EVALUATION.md`](../../../../milestones/M012/phases/P02/D011-EVALUATION.md) (create — D011 mechanical-evaluation record)

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