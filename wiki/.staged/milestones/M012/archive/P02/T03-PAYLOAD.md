---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T03 (Phase P02, Milestone M012)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (25 entries) | 20-589 | ~4900 | filtered |
| Decisions | 591-593 | ~100 | filtered |
| Constraints | 595-628 | ~400 | required |
| Scope | 630-658 | ~600 | required |
| Upstream Context | 660-730 | ~3600 | required |
| Task Plan | 732-1147 | ~4700 | required |
| State Context | 1149-1155 | ~100 | required |
| First-Turn Completeness | 1157-1209 | ~1100 | required |
| **Total** | | **~15500** | |

## Knowledge

<!-- 25 knowledge entries resolved from index -->

---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 319
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
hit_count: 319
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
hit_count: 319
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
hit_count: 319
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
hit_count: 286
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
hit_count: 286
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
hit_count: 286
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
hit_count: 319
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
hit_count: 286
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
hit_count: 286
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
hit_count: 286
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
hit_count: 319
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
hit_count: 319
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
hit_count: 319
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
hit_count: 286
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
hit_count: 286
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
hit_count: 286
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
hit_count: 319
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
hit_count: 286
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
hit_count: 286
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
hit_count: 319
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
hit_count: 319
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
hit_count: 286
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
hit_count: 286
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
hit_count: 286
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
task: "T03"
phase: "P02"
milestone: "M012"
name: "scripts/diagnostics/wiki-link-check.sh — built-site link walker"
depends_on: ["T02"]
---

## Prerequisites

- T01 + T02 complete:
  - `wiki/mkdocs.yml` has link-rewriting config and the extended nav block.
  - `wiki/docs/` is fully populated (P01 `.orchestrator/` stubs + T02 `knowledge/` stubs + all section indexes).
  - `bash scripts/verify/m012-p01-phase-suite.sh` exits 0.
- A working understanding of where MkDocs writes its built site:
  - Default: `wiki/site/` (produced by `mkdocs build` run from the `wiki/` directory).
  - `wiki-serve.sh --probe` produces a throwaway build in `/tmp/wiki-probe.<pid>/site/` (P01 pattern).
  - Operators may pass `--site <dir>` to point the checker at any built directory.
- `mkdocs` may or may not be installed on the current host. T03's script MUST NOT require mkdocs — it operates on an already-built site directory. Smoke-testing (which requires an actual build) is T05's concern and SKIPs when mkdocs is absent.

## Description

Ship `scripts/diagnostics/wiki-link-check.sh` — a standalone Bash 3.2 utility that walks an already-built MkDocs site directory, extracts every internal `<a href="…">` link from every generated HTML file, classifies each link as in-scope / out-of-scope / broken, and exits non-zero when any in-scope link is broken. This is the tool that P04 will wire as a pre-deploy hook (per the roadmap cross-cutting concern) and that T05's suite calls in smoke mode.

### Classification rules

For each `<a href="VALUE">` occurrence inside every `.html` file under `<site-root>/`:

1. **Strip the `VALUE`**. Discard query strings (`?foo=bar`) and fragments (`#anchor`) for the *resolution* step (but retain the fragment for a second, in-page anchor check once the page resolves).
2. **External URL** — `VALUE` begins with `http://`, `https://`, `mailto:`, `tel:`, or `ftp://`. Classification: **out-of-scope** (external). Emit one `OUT-OF-SCOPE: <source-page> -> <href>` line to stdout. Does not fail the check.
3. **In-page anchor only** — `VALUE` begins with `#`. Classification: **in-scope, anchor-only**. Resolve against the source HTML file: grep for `id="<anchor>"` or `name="<anchor>"`. Missing anchor → **broken**. Present → **ok**.
4. **Relative path** — any other value. Resolve against the source HTML file's directory using pure-string path normalization (no `realpath`; macOS default `realpath` is absent):
   - Join `<source-dir>/<VALUE>` into a raw path.
   - Collapse `./` and `../` segments by simple string manipulation (walk segments into a stack, pop on `..`).
   - If the resolved path is OUTSIDE the site root (i.e., `..` segments escape it), classification: **out-of-scope** (escape). Emit `OUT-OF-SCOPE: <source> -> <href> (escapes site root)`.
   - If the resolved path points INSIDE the site root, check file existence:
     - Directory → append `index.html` (MkDocs default directory-url rendering). Re-check existence.
     - `.html` file missing → **broken**.
     - File present → **ok** (and, if a fragment was present, perform the in-page anchor check against that file; missing anchor → broken).
5. **Classification outcomes**:
   - **ok** — silent (not emitted unless verbose mode requested).
   - **broken** — emitted as `BROKEN: <source-page> -> <href>` to stdout.
   - **out-of-scope** — emitted as `OUT-OF-SCOPE: <source-page> -> <href> [<reason>]` to stdout.

### Exit codes

- **0** — zero broken in-scope links (ok). Out-of-scope links enumerated but do not affect exit.
- **1** — at least one broken in-scope link. Last line of stdout reads `FAIL: N broken in-scope link(s) across M source pages`.
- **2** — usage error (missing `--site` directory, unreadable path, no `.html` files found). Diagnostic to stderr.

### Structured output contract

- One line per non-ok finding.
- Last line of stdout is a summary: `PASS: 0 broken in-scope links (<scanned_pages> pages, <ok_links> in-scope ok, <ext_count> out-of-scope)` or `FAIL: …`.
- All diagnostics to stderr; stdout is pure structured output for downstream grep/pipe.

## Steps

1. **Create `scripts/diagnostics/wiki-link-check.sh`** with the following header and structure:

   ```bash
   #!/usr/bin/env bash
   # scripts/diagnostics/wiki-link-check.sh — M012/P02 built-site link walker.
   #
   # Walks an already-built MkDocs site directory, extracts every <a href="…">
   # link from every .html file, classifies each link as in-scope / out-of-scope /
   # broken, and exits non-zero on any broken in-scope link.
   #
   # Usage:
   #   bash scripts/diagnostics/wiki-link-check.sh [--site <dir>] [--root <dir>]
   #                                               [--strict] [--help]
   #
   #   --site <dir>  Built site directory. Default: "wiki/site" relative to --root.
   #   --root <dir>  Project root. Default: invocation working directory.
   #   --strict      Treat out-of-scope escape as broken (stricter than default).
   #   --help        Print this usage block and exit 0.
   #
   # Exit codes:
   #   0  — zero broken in-scope links.
   #   1  — one or more broken in-scope links.
   #   2  — usage error (no site dir, no .html files, unreadable path).
   #
   # In-scope: any relative link that resolves to an existing file inside the
   #           site tree, plus in-page anchor-only links (#foo) whose anchor
   #           exists in the source page.
   # Out-of-scope: http(s), mailto, tel, ftp; paths that escape the site root.
   # Broken: relative link whose resolved path is missing, or anchor link whose
   #         target id/name is absent from the target page.
   #
   # Bash 3.2 compatible. MEM004 carve-out: internal pipes/awk/sed permitted.
   # Single-script-file shape (AD-19) — callable directly as the Check command.

   set -u
   ```

2. **Argument parsing** — dual-style per MEM001 (long flags only for this script; positional not needed):

   ```bash
   SITE_DIR=""
   ROOT_DIR=""
   STRICT=0

   print_help() {
     sed -n '2,30p' "$0"
   }

   while [ $# -gt 0 ]; do
     case "$1" in
       --site) shift; SITE_DIR="${1:-}" ;;
       --root) shift; ROOT_DIR="${1:-}" ;;
       --strict) STRICT=1 ;;
       --help|-h) print_help; exit 0 ;;
       *) printf 'ERROR: unknown flag: %s\n' "$1" >&2; exit 2 ;;
     esac
     [ $# -eq 0 ] || shift
   done

   [ -n "$ROOT_DIR" ] || ROOT_DIR="$(pwd)"
   [ -n "$SITE_DIR" ] || SITE_DIR="$ROOT_DIR/wiki/site"

   if [ ! -d "$SITE_DIR" ]; then
     printf 'ERROR: site directory not found: %s\n' "$SITE_DIR" >&2
     printf '       Build the site first: (cd wiki && mkdocs build)\n' >&2
     exit 2
   fi
   ```

   NOTE: the usage block is rendered by `sed -n '2,30p' "$0"` — the header lines 2–30 of the script itself. Keep the header at the exact line range above for `--help` to work. (The line range is flexible; tune to match the actual header length.)

3. **Enumerate HTML files**:

   ```bash
   HTML_LIST="/tmp/wiki-link-check.html.$$"
   trap 'rm -f "$HTML_LIST" "$HTML_LIST.links" "$HTML_LIST.findings" 2>/dev/null' EXIT
   find "$SITE_DIR" -type f -name '*.html' | LC_ALL=C sort > "$HTML_LIST"

   PAGE_COUNT=0
   while IFS= read -r _pg; do
     [ -n "$_pg" ] || continue
     PAGE_COUNT=$((PAGE_COUNT + 1))
   done < "$HTML_LIST"

   if [ "$PAGE_COUNT" -eq 0 ]; then
     printf 'ERROR: no .html files found under %s\n' "$SITE_DIR" >&2
     exit 2
   fi
   ```

4. **Extract links per page**. Use `grep -oE` with a conservative href regex. HTML attribute quoting is not fully regex-safe, but MkDocs emits consistent `href="…"` form:

   ```bash
   # Emit "<page-path>|<href>" per link.
   : > "$HTML_LIST.links"
   while IFS= read -r page; do
     [ -n "$page" ] || continue
     # grep -oE returns one match per line.
     # Regex: href="([^"]+)" — captures the value between quotes.
     grep -oE 'href="[^"#?][^"]*"' "$page" 2>/dev/null \
       | sed -e 's/^href="//' -e 's/"$//' \
       | while IFS= read -r href; do
           [ -n "$href" ] || continue
           printf '%s|%s\n' "$page" "$href" >> "$HTML_LIST.links"
         done
     # Also capture anchor-only (#foo) and empty-start-with-# hrefs separately
     # because the above regex excludes leading # and ? (query-only).
     grep -oE 'href="#[^"]+"' "$page" 2>/dev/null \
       | sed -e 's/^href="//' -e 's/"$//' \
       | while IFS= read -r href; do
           printf '%s|%s\n' "$page" "$href" >> "$HTML_LIST.links"
         done
   done < "$HTML_LIST"
   ```

   Bash 3.2 caveat: the `while | while` piped subshell won't lose data because we're writing to a file, not updating a counter variable. Counters are recomputed from the file below.

5. **Classify each link**. Iterate `$HTML_LIST.links`:

   ```bash
   : > "$HTML_LIST.findings"
   BROKEN=0
   OUT_OF_SCOPE=0
   OK_LINKS=0

   while IFS='|' read -r page href; do
     [ -n "$page" ] || continue
     [ -n "$href" ] || continue

     # External URL?
     case "$href" in
       http://*|https://*|mailto:*|tel:*|ftp://*)
         printf 'OUT-OF-SCOPE: %s -> %s [external]\n' "$page" "$href" \
           >> "$HTML_LIST.findings"
         OUT_OF_SCOPE=$((OUT_OF_SCOPE + 1))
         continue
         ;;
     esac

     # In-page anchor only?
     case "$href" in
       '#'*)
         anchor="${href#\#}"
         if grep -qE "(id=\"${anchor}\"|name=\"${anchor}\")" "$page"; then
           OK_LINKS=$((OK_LINKS + 1))
         else
           printf 'BROKEN: %s -> %s [in-page anchor missing]\n' "$page" "$href" \
             >> "$HTML_LIST.findings"
           BROKEN=$((BROKEN + 1))
         fi
         continue
         ;;
     esac

     # Relative path (strip fragment for resolution; keep for anchor check).
     path_only="${href%%\#*}"
     frag=""
     case "$href" in
       *'#'*) frag="${href#*\#}" ;;
     esac
     # Strip query string.
     path_only="${path_only%%\?*}"

     # Resolve against the source page's directory.
     src_dir=$(dirname "$page")
     raw="$src_dir/$path_only"

     # Pure-string path normalization (no realpath).
     resolved=$(normalize_path "$raw")

     # Escape check — must stay under SITE_DIR.
     site_prefix="${SITE_DIR%/}/"
     case "$resolved" in
       "$SITE_DIR"|"$site_prefix"*) ;;  # inside site — ok to continue
       *)
         reason="escapes site root"
         if [ "$STRICT" -eq 1 ]; then
           printf 'BROKEN: %s -> %s [%s]\n' "$page" "$href" "$reason" \
             >> "$HTML_LIST.findings"
           BROKEN=$((BROKEN + 1))
         else
           printf 'OUT-OF-SCOPE: %s -> %s [%s]\n' "$page" "$href" "$reason" \
             >> "$HTML_LIST.findings"
           OUT_OF_SCOPE=$((OUT_OF_SCOPE + 1))
         fi
         continue
         ;;
     esac

     # Directory → index.html.
     if [ -d "$resolved" ]; then
       resolved="${resolved%/}/index.html"
     fi

     if [ ! -f "$resolved" ]; then
       printf 'BROKEN: %s -> %s [file missing: %s]\n' "$page" "$href" "$resolved" \
         >> "$HTML_LIST.findings"
       BROKEN=$((BROKEN + 1))
       continue
     fi

     # If we have a fragment, verify anchor exists in the target page.
     if [ -n "$frag" ]; then
       if ! grep -qE "(id=\"${frag}\"|name=\"${frag}\")" "$resolved"; then
         printf 'BROKEN: %s -> %s [target anchor missing: #%s]\n' \
           "$page" "$href" "$frag" >> "$HTML_LIST.findings"
         BROKEN=$((BROKEN + 1))
         continue
       fi
     fi

     OK_LINKS=$((OK_LINKS + 1))
   done < "$HTML_LIST.links"
   ```

6. **Implement `normalize_path`** — pure string path normalization, Bash 3.2 safe:

   ```bash
   normalize_path() {
     # Collapse "./" and "../" against a raw path string. No realpath.
     # Split on "/", walk into a positional-parameter stack.
     local raw="$1"
     local IFS=/
     set -- $raw
     local out=""
     local seg
     for seg in "$@"; do
       case "$seg" in
         ''|'.') continue ;;
         '..')
           # Pop one segment from out.
           out="${out%/*}"
           ;;
         *)
           if [ -z "$out" ]; then
             out="$seg"
           else
             out="$out/$seg"
           fi
           ;;
       esac
     done
     # Preserve leading slash if raw started with /.
     case "$raw" in
       /*) printf '/%s\n' "$out" ;;
       *)  printf '%s\n' "$out" ;;
     esac
   }
   ```

   Bash 3.2 compatible — uses `local`, positional parameters, and string parameter expansion. No `mapfile`, no `declare -A`, no `<(…)`.

7. **Emit findings and summary**:

   ```bash
   # Print findings (sorted for determinism).
   if [ -s "$HTML_LIST.findings" ]; then
     LC_ALL=C sort -u "$HTML_LIST.findings"
   fi

   if [ "$BROKEN" -gt 0 ]; then
     printf 'FAIL: %d broken in-scope link(s) across %d source pages (%d ok, %d out-of-scope)\n' \
       "$BROKEN" "$PAGE_COUNT" "$OK_LINKS" "$OUT_OF_SCOPE"
     exit 1
   fi

   printf 'PASS: 0 broken in-scope links (%d pages, %d in-scope ok, %d out-of-scope)\n' \
     "$PAGE_COUNT" "$OK_LINKS" "$OUT_OF_SCOPE"
   exit 0
   ```

8. **Make the script executable**:

   ```bash
   chmod 755 scripts/diagnostics/wiki-link-check.sh
   ```

9. **Smoke test locally if `mkdocs` is available**:

   ```bash
   bash scripts/wiki/wiki-serve.sh --probe
   ```

   This produces a throwaway site under `/tmp/wiki-probe.<pid>/site/`. Record that path and run:

   ```bash
   bash scripts/diagnostics/wiki-link-check.sh --site /tmp/wiki-probe.<pid>/site
   ```

   Expect `PASS: 0 broken in-scope links (…)` on stdout, exit 0. If broken links are reported, the most likely causes are:
   - Missing include-plugin `rewrite_relative_urls: true` (T01 setting).
   - Scanner missed a canonical file (T01 extension incomplete).
   - Stub generator's `canonical_rel` path calculation is wrong (T02 `../` count).
   - A legitimate broken link in canonical content (an actual bug to report).

   Address the first three before blaming the fourth; log genuine content issues to the phase notes but do NOT fix canonical content in T03 — that is either a separate task or a defect report.

10. **If `mkdocs` is not installed**, skip the smoke; T05's `m012-p02-link-check-smoke.sh` gate handles the SKIP-as-PASS semantics. T03's deliverable is the script itself plus its offline contract (executable, `--help` prints usage, missing `--site` exits 2, etc.), all of which are verifiable without mkdocs.

## Must-Haves

- `scripts/diagnostics/wiki-link-check.sh` exists, is executable, Bash 3.2 compatible.
- `bash scripts/diagnostics/wiki-link-check.sh --help` prints usage block and exits 0.
- Invoked with no args: defaults `--site` to `wiki/site/` relative to invocation cwd; if that directory does not exist, exits 2 with a diagnostic.
- Invoked with `--site <missing-dir>`: exits 2.
- Invoked with `--site <dir-containing-zero-html-files>`: exits 2.
- Invoked against a valid built-site directory: walks `.html` files, classifies links, emits `BROKEN:` / `OUT-OF-SCOPE:` lines, ends with `PASS:` or `FAIL:` summary line, exits 0/1 accordingly.
- Output is deterministic — running the script twice against the same site directory produces byte-identical stdout (modulo sort stability).
- No side effects — script does not modify any file outside `/tmp/`.

## Verification

- `bash scripts/diagnostics/wiki-link-check.sh --help` — exits 0; stdout contains "--site", "--root", "--strict", "In-scope", "Out-of-scope", "Broken" (used by T05's `m012-p02-link-check-help.sh` gate).
- `bash scripts/diagnostics/wiki-link-check.sh --site /does/not/exist` — exits 2; stderr mentions "site directory not found".
- `bash scripts/diagnostics/wiki-link-check.sh` (no flags, from repo root, with no `wiki/site/` built) — exits 2.
- `bash scripts/verify/m012-p01-phase-suite.sh` — still exits 0 (T03 adds one new script; does not modify P01 surfaces).
- Manual smoke (if mkdocs installed): build via `wiki-serve.sh --probe`, run link-check against `/tmp/wiki-probe.<pid>/site`, expect PASS with 0 broken.

## Inputs

### From Previous Tasks

- `wiki/mkdocs.yml` (T01)
  - Key API: `rewrite_relative_urls: true` on include-markdown — load-bearing for links inside included bodies to resolve correctly in the built site.
- `wiki/docs/**` (T02 + P01)
  - Full stub surface for both `.orchestrator/**.md` and `knowledge/**/MEM*.md`. T03's script consumes the BUILT output (HTML under `wiki/site/`), not the stubs directly, so its contract is defined against `site/` rather than `docs/`.

### From Disk (Pre-existing)

- `wiki/site/` — built by `mkdocs build` when mkdocs is installed. NOT checked into the repo (excluded by `wiki/.gitignore` from P01). The link-checker operates on this directory.
- `.orchestrator/memory/constitution.md` — Principle VIII (Bash 3.2) applies.
- `scripts/wiki/wiki-serve.sh` (P01) — operators use `--probe` to produce a throwaway build for local smoke-testing T03's script.

## Constraints

- **Bash 3.2** — the script must work on stock macOS bash. MEM001.
- **MEM004 carve-out applies** — this is a diagnostic script, not agent-facing content. Pipes, subshells, `grep -oE`, `awk`, `sed`, `find | sort`, PID-suffixed /tmp files are permitted inside the script. The AD-19 shape constraint applies to Truth `Check:` commands (which invoke `scripts/verify/m012-p02-*.sh` one level up); it does NOT constrain internal implementation.
- **No `realpath` dependency** — macOS `realpath` is not in POSIX; this script may run without coreutils. Implement path normalization via pure string manipulation (step 6).
- **No external dependencies** — no `jq`, no `python3`, no Node. Pure shell utilities (`grep`, `sed`, `find`, `sort`) are the budget.
- **Read-only against repo state** — the script only writes to `/tmp/` (temp files cleaned on exit via `trap`).
- **Deterministic output** — findings are `sort -u`-d before emission so repeated runs are byte-identical. Counters are recomputed from the findings file, not maintained across a piped subshell (MEM001 Bash 3.2 counter-loss caveat).
- **Surgical precision (Constitution XV)** — T03 creates exactly one file (`scripts/diagnostics/wiki-link-check.sh`) plus its executable bit. No other files touched.

## Expected Output

After T03 completes:

1. `scripts/diagnostics/wiki-link-check.sh` exists, is executable (`ls -l` shows `-rwxr-xr-x`), is ≥ 180 lines including header and helpers.
2. `--help` output enumerates `--site`, `--root`, `--strict` flags plus classification rules.
3. Against a missing site dir, exits 2 with a clear diagnostic.
4. Against a built site, exits 0 with `PASS: 0 broken in-scope links (…)` (when all in-scope links resolve).
5. Emits one `BROKEN:`/`OUT-OF-SCOPE:` line per problematic link; summary line last.
6. P01 suite still green.
7. T04 can reference this script by name in `wiki/README.md`; T05 can assert its contract via gates.

## State Context

- **Current State**: executing
- **Milestone**: M012
- **Phase**: P02
- **Task**: T03
- **Tier**: C

## First-Turn Completeness

### Intent


### Constraints

- **Bash 3.2** — the script must work on stock macOS bash. MEM001.
- **MEM004 carve-out applies** — this is a diagnostic script, not agent-facing content. Pipes, subshells, `grep -oE`, `awk`, `sed`, `find | sort`, PID-suffixed /tmp files are permitted inside the script. The AD-19 shape constraint applies to Truth `Check:` commands (which invoke `scripts/verify/m012-p02-*.sh` one level up); it does NOT constrain internal implementation.
- **No `realpath` dependency** — macOS `realpath` is not in POSIX; this script may run without coreutils. Implement path normalization via pure string manipulation (step 6).
- **No external dependencies** — no `jq`, no `python3`, no Node. Pure shell utilities (`grep`, `sed`, `find`, `sort`) are the budget.
- **Read-only against repo state** — the script only writes to `/tmp/` (temp files cleaned on exit via `trap`).
- **Deterministic output** — findings are `sort -u`-d before emission so repeated runs are byte-identical. Counters are recomputed from the findings file, not maintained across a piped subshell (MEM001 Bash 3.2 counter-loss caveat).
- **Surgical precision (Constitution XV)** — T03 creates exactly one file (`scripts/diagnostics/wiki-link-check.sh`) plus its executable bit. No other files touched.

### Acceptance Criteria

- `scripts/diagnostics/wiki-link-check.sh` exists, is executable, Bash 3.2 compatible.
- `bash scripts/diagnostics/wiki-link-check.sh --help` prints usage block and exits 0.
- Invoked with no args: defaults `--site` to `wiki/site/` relative to invocation cwd; if that directory does not exist, exits 2 with a diagnostic.
- Invoked with `--site <missing-dir>`: exits 2.
- Invoked with `--site <dir-containing-zero-html-files>`: exits 2.
- Invoked against a valid built-site directory: walks `.html` files, classifies links, emits `BROKEN:` / `OUT-OF-SCOPE:` lines, ends with `PASS:` or `FAIL:` summary line, exits 0/1 accordingly.
- Output is deterministic — running the script twice against the same site directory produces byte-identical stdout (modulo sort stability).
- No side effects — script does not modify any file outside `/tmp/`.

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