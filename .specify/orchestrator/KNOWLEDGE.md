# Orchestrator Knowledge Base

Consolidated from M001 implementation. Read before any orchestrator development.

## Patterns

### Shell Script Conventions
- **Bash 3.2 compatibility**: No `declare -A` (associative arrays). Use parallel indexed arrays (`arr_k_0`, `arr_v_0`, etc.) instead. macOS ships bash 3.2.
- **YAML parsing**: `grep`/`sed`/`awk` only — no python3 or jq hard dependency. jq used as optional fallback via `json_field()` helper.
- **Structured output**: All scripts emit prefixed lines to stdout (`PASS:`, `FAIL:`, `LOCK:`, `STUCK:`, `BUDGET:`, `SUMMARY:`, `DECISION:`, `KNOWLEDGE:`, `ROLLBACK:`, `VALIDATE:`, `CONSOLIDATE:`). Errors to stderr. Exit 0 on success, 1 on failure.
- **Dual argument style**: Scripts accept both positional subcommands and `--flag` style for human and programmatic use.
- **Idempotent operations**: All scaffolding/creation scripts check-before-create with early exit on existing state.

### Test Conventions
- **Pass/fail tracking**: `pass()` and `fail()` functions with parallel indexed arrays (bash 3.2 safe). Summary count at end.
- **Fixture pattern**: State fixture directories under `tests/fixtures/` named by scenario (`state-executing`, `verify-pass`, `dispatch-state`).
- **PID 1 trick**: Tests use PID 1 (launchd on macOS) as guaranteed-alive process for `ACTIVE` lock detection — subshell PIDs die before assertion.
- **Cross-reference validation**: Integration tests extract script/template paths from command files via `grep -oE` regex, then verify existence/executability. Self-maintaining as commands evolve.
- **Self-diagnostic pattern**: Test files verify their own `fail()` messages include actionable file paths or contract identifiers.

### Command File Structure
All 10 command `.md` files follow identical structure:
```
YAML frontmatter (description field)
→ Title
→ Prerequisites / State Check
→ Core Workflow (numbered sections)
→ Output
→ Idempotency
→ Error Handling
→ Referenced Scripts/Templates
```

### Template Convention
- YAML frontmatter with `schema_version` + `type` fields
- Body uses `{{placeholder}}` syntax for dynamic values
- No hardcoded milestone/phase/task IDs (context-free per FR-074)
- Summary frontmatter: 15-field base schema for tasks (`schema_version`, `type`, `id`, `parent`, `milestone`, `provides`, `requires`, `affects`, `key_files`, `key_decisions`, `patterns_established`, `drill_down_paths`, `duration`, `verification_result`, `completed_at`); phase/milestone summaries add `observability_surfaces` for 16 fields

### State Machine
- 9 states derived from file presence on disk (priority-ordered rules in `derive-phase.sh`)
- Rule 3b addition: roadmap exists but active phase has no `P##-PLAN.md` → `planning` (handles gap between roadmap creation and phase planning)
- Empty milestone directory (no `M###-*` files) → `pre-planning` (distinct from scaffolded)
- Milestone ID detected from `M###-*.md` files inside directory, not from directory basename (enables arbitrary fixture names)

## Decisions Register

Imported from `.gsd/DECISIONS.md`. Entries are append-only.

| # | Scope | Decision | Rationale |
|---|-------|----------|-----------|
| D001 | arch | tasks.md phases map 1:1 to orchestrator slices | Boundary maps and must-haves align naturally; no transformation needed |
| D002 | arch | 8 architecture decisions from Conversus (AD-1 through AD-8) | Ratified through multi-perspective convergence. See plan.md §Architecture Decisions |
| D003 | convention | Milestone validation marker = `M###-VALIDATED` file | File-presence detection is the consistent pattern (Principle VI); simpler than parsing frontmatter |
| D004 | data | `derive-phase.sh` rule 3 expanded: both "no roadmap" and "roadmap exists but no phase plan" → `planning` | FR-020 requires `planning` for both conditions; without this, scaffolded milestones fall through |
| D005 | arch | Verification scripts: structured PASS/FAIL stdout, errors stderr, exit 0/1 | Consumed by verify command, test harness, and autonomous dispatch; structured output enables programmatic parsing |
| D006 | convention | Phase plan must-haves: `### Truths` / `### Artifacts` / `### Key Links` with parseable modifiers | Must be human-readable AND machine-parseable; `(min N lines)`, `(contains "pattern")`, `Check: \`command\`` enable Tier 1/2 checks |
| D007 | convention | `scope-filter.sh` uses scope tags in KNOWLEDGE.md, `When` column in DECISIONS.md, `--depends` flag for dependency resolution | FR-062/FR-063 scoping rules; caller resolves deps from roadmap to avoid duplicating roadmap parsing |

### Implementation Decisions (auto-aggregated)
- `check-must-haves.sh` resolves project root by walking up from phase dir to find `phases/` parent
- `check-scope.sh` exits 0 always — scope violations are warnings, never block transitions
- Truths without `Check:` sub-items logged as descriptive (Tier 3), not mechanically checked
- `build-context.sh` supports both orchestrator-root and fixture-mode layouts
- `scope-filter.sh` auto-detects file type from filename when `--type` omitted
- Knowledge entries without scope tags included by default (project-level)
- Pause detection: file-based flag (`.specify/orchestrator/pause-requested`), not signals
- Verification retry: max 1 retry with diagnostic context before pausing
- `resume.md` treats mixed state (continue file + stale lock) as crash recovery
- `discuss.md` uses frontmatter `status` field (`draft`→`finalized`) for state transition
- `json_field()` strips trailing commas from bare numeric JSON values
- `pid_alive()` checks `kill -0` stderr for EPERM (alive but different user) vs ESRCH (dead)
- Rollback archives use `YYYYMMDDTHHMMSS` timestamp prefix
- Consolidation measures `phases/` directory (not total milestone dir, since `archive/` lives inside)

## Lessons Learned

| # | Issue | Root Cause | Fix |
|---|-------|-----------|-----|
| L001 | `kill -0 $pid` fails for PID 1 on macOS | Returns EPERM (exit 1) same as ESRCH | Check stderr for "perm" — EPERM=alive, ESRCH=dead |
| L002 | Lock manager `$$` shows STALE in tests | `$(bash lock-manager.sh create ...)` runs in subshell whose PID dies before status check | Tests patch lock file PID to known-alive process (PID 1) after creation |

## Interface Contracts

### Scripts → Commands
Commands reference scripts by relative path in "Referenced Scripts" sections. Integration tests verify all cross-references resolve to existing, executable files.

### State → Dispatch
`derive-phase.sh` outputs single state word to stdout. `auto.md` reads this to determine loop action. Budget/stuck/lock checks gate dispatch.

### Verification → State Advancement
Verification scripts output `PASS:`/`FAIL:` lines. `auto.md` consumes these: all-pass → advance, any-fail → retry once then pause. Phase advancement requires verification pass.

### Knowledge → Context Assembly
`scope-filter.sh` filters `KNOWLEDGE.md`/`DECISIONS.md` by scope tags. `build-context.sh` assembles filtered knowledge + task plan + upstream summaries into dispatch payload. Budget metrics reported to stderr.

### Templates → Output
Commands use `templates/*.md` as starting points. Agent fills `{{placeholder}}` values. Template `schema_version` field enables future format migration.

## Audit Remediation Patterns (v0.1.0)

### Shared JSON Utility
- `scripts/util/json-field.sh` extracts `json_field()` into a sourceable utility. Lock-manager and recovery-briefing `source` it instead of duplicating the function. Pattern: extract shared functions into `scripts/util/` and `source` them.

### ISO 8601 Standardization
- All timestamps use `date -u +%Y-%m-%dT%H:%M:%SZ` (UTC, ISO 8601). Rollback-phase.sh was using `date +%Y%m%dT%H%M%S` — fixed for consistency with lock-manager and recovery-briefing.

### AGENTS.md → README.md Convention
- Documentation files in `commands/`, `references/`, and `templates/` directories renamed from `AGENTS.md` to `README.md`. Integration tests exclude `README.md` from command file checks (frontmatter, count).

### FR-064 / FR-075 Implementation
- **External modification detection** (FR-064): `check-external-mods.sh` reads `phase_start_tree` (git commit hash) from the lock file and diffs against HEAD. Scope filtering excludes authorized files. Graceful skip when no git/lock/tree.
- **Git worktree isolation** (FR-075): `scaffold.sh` creates worktrees when `GIT_ISOLATION=true`. `recovery-briefing.sh` detects active worktrees. `consolidate.md` documents merge-back workflow. All graceful-degrade when git unavailable.

### IFS Safety in Bash
- `IFS=',' read -ra` is local to the `read` built-in — safe, does not leak. Documented in scope-filter.sh and read-roadmap.sh.
- For `IFS=','` in `for` loops (rollback-phase.sh), wrap in subshell `(IFS=','; ...)` to prevent leaking into parent scope.

### Runtime Adapter Interface (FR-067/FR-068/FR-069)
- The spec defines 5 abstract adapter operations (`dispatch-task`, `await-completion`, `collect-result`, `signal-failure`, `inject-context`). In the v0.1.0 extension architecture (markdown commands + shell scripts), these are realized as:
  - **dispatch-task / inject-context**: `build-context.sh` assembles the payload; command documents instruct the agent to dispatch (subagent or sequential) based on `detect-capabilities.sh` output.
  - **await-completion / collect-result**: The agent runtime handles task execution and writes artifacts to disk. The orchestrator detects completion via file presence (task summary exists = done).
  - **signal-failure**: Verification scripts (`check-must-haves.sh`, `run-commands.sh`) detect failure by checking artifacts against must-haves. Failures are recorded in `execution-log.jsonl`.
- No formal `adapter-*.sh` scripts exist. The agent interpreting the markdown command IS the adapter. This satisfies FR-067-069's intent (no platform-specific branching in core logic) while being idiomatic for the extension architecture.

### Claude Code-Only Validation (v0.1.0)
- v0.1.0 is designed and validated exclusively with Claude Code. All instructions are agent-neutral markdown, all scripts are POSIX-compatible — no Claude Code-specific APIs or behaviors are assumed. Multi-agent validation deferred to M002 when spec-kit's agent ecosystem matures.
- FR-045 (destructive operation warnings) is delegated to Claude Code's built-in safety checks for v0.1.0. Orchestrator-level detection deferred to future milestone.
- **[milestone:M005]** [2026-04-12] DOCTOR: structured output protocol — all diagnostic scripts emit a single structured line (DOCTOR:<CHECK> status=<ok|warn|skip|drift|missing> key=value ...) for machine parsing by run-doctor.sh. Advisory checks (like check-plans.sh) always exit 0; non-advisory checks exit 0 on ok, 1 on warn. Established in P04, extended through P05-P07.
- **[milestone:M005]** [2026-04-12] Scored health reporting — run-doctor.sh aggregates 12 checks (4 legacy + 8 DOCTOR:) into Checks passed: N/M with HEALTHY/NEEDS_ATTENTION status. Legacy checks use exit-code pass/fail; new checks parse DOCTOR: status lines. Advisory checks (check-plans.sh) counted separately. History appended to doctor-history.jsonl per run.
- **[milestone:M005]** [2026-04-12] Pure lib extraction pattern — dispatch scripts (build-context.sh, compress-payload.sh) source pure function libs (payload-transforms.sh, manifest-builder.sh) instead of defining inline duplicates. Pure functions take stdin/arguments, produce stdout, perform no file I/O. Established in P03 per AD-5.
- **[milestone:M005]** [2026-04-12] Content-hash idempotency — knowledge entries carry content_hash: sha256:{hex} in frontmatter. hash.sh provides compute_content_hash (string) and compute_file_body_hash (file body). create-entry.sh writes hash at creation; update-entry.sh recomputes on --body changes; rebuild-index.sh compares stored vs computed hashes for change detection and self-heals drift. record-result.sh accepts outcome=unchanged for stagnation signaling. Established in P01.
- **[milestone:M005]** [2026-04-12] Cost_source closed enum — telemetry entries carry cost_source field (estimated/reported/unknown) with closed enum validation. aggregate-metrics.sh groups by cost_source, distinguishes null cost (unknown) from zero cost (free). Legacy entries classified by presence of cost data. Established in P02 per AD-2.
- **[milestone:M005]** [2026-04-12] Gate verdict protocol — scripts/lib/verdicts.sh provides emit_verdict, parse_verdict, orch_is_verdict with four constants: PASS, BLOCK, WARN, NEEDS_REVIEW. hooks.sh captures hook stdout, parses VERDICT lines, resolves multiple verdicts to most severe, and maps to block/warn/continue behavior. Backward compatible when no VERDICT present. Provider convention documented in references/provider-convention.md. Established in P05 per AD-3.
- **[milestone:M005]** [2026-04-12] Autonomy permission pipeline — generate-permissions.sh introspects project toolchain (package.json, Makefile, extension.yml, config files, agent host markers) and emits canonical JSON. write-permissions.sh translates to .claude/settings.json with additive merge for user-authored files. check-permissions.sh detects permission drift. Policy is declarative in autonomy-defaults.yaml read via recipe-parser.sh. AD-19 script-file verification shape: task plan Check: commands must use single-script invocations, not inline compound bash. Established in P07.
- **[milestone:M002]** [2026-04-13] Three-temperature knowledge architecture: hot (KNOWLEDGE-INDEX.md, always loaded), warm (knowledge/{category}/{entry-id}.md, loaded on scope-match), cold (knowledge/archive/, never auto-injected). Index is pipe-delimited with 8 fields: id, scope_tags, category, confidence, created_at, last_verified, hit_count, description. Index is a derived artifact — rebuildable from detail files via rebuild-index.sh.
- **[milestone:M002]** [2026-04-13] Validation-as-task pattern: when scripts pre-exist from prior milestones, phase tasks verify correctness rather than creating new code. T01 creates verification scripts, T02+ runs them. Most phases in M002 P04-P07 required minimal or no code changes — the verification process itself was the deliverable.
- **[milestone:M002]** [2026-04-13] Dispatched agents must write T##-SUMMARY.md files using write-summary.sh — without the summary file, the auto-loop cannot advance to the next task. Include explicit write-summary.sh instructions in dispatch prompts.
- **[milestone:M004]** [2026-04-13] P06 backtick-in-plan-artifacts lesson: check-must-haves.sh includes backtick characters literally when parsing Artifact and Key Links sections from phase plans. Paths in these sections must NOT be wrapped in markdown backticks or the artifact/key-link checks will fail with 'not found' errors pointing to paths like `path/to/file` instead of path/to/file. Truth Check: commands are unaffected because the parser strips the outer backticks from the fenced command.
- **[milestone:M004]** [2026-04-13] P06 lib-path correction: Task plans for P06 specified _LIB_DIR as ../../lib from scripts/verify/, scripts/lifecycle/, scripts/telemetry/, and scripts/dispatch/. The correct path from all of these directories to scripts/lib/ is ../lib (one level up, not two). All scripts under scripts/*/ are one directory level below scripts/, so ../lib always resolves correctly.
- **[milestone:M004]** [2026-04-13] P06 verification-script-pattern lesson: Verification helper scripts that grep for library sourcing should use broad patterns (e.g. 'errors\.sh') not narrow literal patterns (e.g. 'lib/errors\.sh'). Scripts may source libs via variable expansion ($_LIB_DIR/errors.sh) which does not match the literal path. The broader pattern still uniquely identifies the sourcing intent.
- **[milestone:M006]** [2026-04-14] Documentation-as-verification (verify-as-you-write) surfaces real bugs: M006 found and fixed a stale routing fallback value in references/file-formats.md. The mechanical discipline of running every documented command catches drift that tests miss.
- **[milestone:M006]** [2026-04-14] Cross-link validation scripts (checking that doc A references doc B) catch missing references that manual review misses. Every P01-P06 phase required cross-link fixes during the verification step. Pattern: always create cross-link verification scripts during planning.
- **[milestone:M008]** [2026-04-14] Filename-based adapter auto-discovery: drop any script into scripts/dispatch/adapters/<type>/*.sh to register it. No central registry file. Mirror applied across P02 backends, P05 runtime adapters, and P05 format adapters. Dispatch core uses /.sh filename lookup — zero type-specific branching. New backends/runtimes/formats can be added with zero core-orchestrator edits (satisfies SC-003).
- **[milestone:M008]** [2026-04-14] Hermetic-first testing for runtime/HOME-touching scripts: all installer, runtime-adapter, and init tests use HOME=$(mktemp -d) or --project-dir $(mktemp -d). HOME guards in adapter scripts refuse HOME="" or HOME=/ to prevent root-directory writes. A static gate (m008-p07-hermetic-only.sh) mechanically enforces this pattern across P07 verifiers. Never invoke --register or install-*.sh against real developer HOME during automated tests.
- **[milestone:M008]** [2026-04-14] Bash 3.2 compat scanner must be comment-aware: grep -vE '^[[:space:]]*#' before checking for forbidden constructs. Documentation strings like '# Bash 3.2 compatible: no declare -A, no readarray, no |&' would otherwise produce false positives. The scanner itself must use fragment-built regexes for the forbidden tokens so it does not self-match when included in its own scan target list.
- **[milestone:M008]** [2026-04-14] User-edit preservation via comment-delimited blocks: templates include <!-- BEGIN CUSTOM --> / <!-- END CUSTOM --> markers on their own lines. Regeneration scripts (reinit-handler.sh --mode update) extract the custom block via awk line matching and re-inject it into the regenerated file. Pair with field-level awk surgery for YAML/config (regenerate auto-detected top-level keys, preserve user-added keys). Default regeneration mode should be update (preserving), not reset.
- **[milestone:M008]** [2026-04-14] Thin delegation pattern: top-level orchestration scripts (init-project.sh, installers) should delegate to existing single-responsibility scripts rather than duplicate logic. init-project.sh delegates to detect-runtime (P05), detect-capabilities (P01), detect-project (P07), resolve-root (P04), and runtime-specific installer (P06). Installers delegate --probe/--register/--hook-config to P05 runtime adapters. This keeps each script testable in isolation and prevents behavior drift across layers.
- **[milestone:M003]** [2026-04-15] Adapter-interface extract() contract enables pluggable source-format migration — adding a new source (GSD v1, spec-kit) requires only implementing extract() against a common intermediate data format. Core pipeline is source-agnostic.
- **[milestone:M003]** [2026-04-15] Three-tier root resolution (flag → env var → resolve-root.sh fallback) is the standard CLI contract for orchestrator-root-consuming scripts. Makes scripts work under both ORCHESTRATOR_ROOT env and explicit --root, with config-driven default. Reference: scripts/orchestrator/status.sh.
- **[milestone:M003]** [2026-04-15] For deterministic SQLite test fixtures under 50KB: use PRAGMA page_size=1024 + hard-coded ISO-8601 timestamps in seed.sql, commit both seed.sql and pre-built .db (CI speed + reproducibility). Pair with .gitignore negation (!tests/fixtures/**/.gsd/**) when fixture shares a name with globally-ignored dev state.
- **[milestone:M003]** [2026-04-15] Skip-gracefully fixture pattern for integration tests: synthetic fixture always runs (primary), optional live fixture runs when present or SKIPs cleanly when absent (secondary). Strict/warn split absorbs live-fixture concurrent noise (mtime drift) without masking synthetic-path regressions.
- **[milestone:M003]** [2026-04-15] Tier-1 verify-per-truth pattern: each phase truth gets one single-file AD-19-safe scripts/verify/<milestone>-<phase>-<name>.sh emitting PASS/SKIP/FAIL, exit 0/non-zero. Static grep + behavioral checks per truth keeps verification auditable and refactor-tolerant.
