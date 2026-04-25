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
- **[milestone:M016]** [2026-04-16] write-summary.sh --completed_at is optional. Omit it to default to current UTC timestamp. Pass --completed_at=now as a sentinel. This eliminates the #1 source of Claude Code safety prompts (command substitution in timestamp generation). See AP-004 in ANTIPATTERNS.md.
- **[milestone:M016]** [2026-04-16] scripts/verify/run-suite.sh auto-discovers gate scripts matching <milestone>-<phase>-*.sh naming convention, executes each, prints per-script PASS/FAIL, and emits PASS: N / FAIL: M summary. Replaces chained bash verify invocations that trigger Claude Code compound-bash safety prompts.
- **[milestone:M016]** [2026-04-16] scripts/verify/anti-pattern-lint.sh scans agent-facing content (commands/*.md, templates/*.md) for Class A anti-patterns inside fenced code blocks only. Self-excludes and excludes ANTIPATTERNS.md. Supports --fixture mode for testing. FORBIDDEN-region suppression handles multi-line forbidden examples in documentation.
- **[milestone:M021]** [2026-04-17] Shape-classifier as single source of truth: a classifier library (scripts/verify/lib/shape-classifier.sh) consumed by both the enforcement layer (pre-Bash hook) and the regression gate (replay-prompt-corpus.sh) guarantees byte-identical decisions and catches classifier drift the moment corpus expectations diverge.
- **[milestone:M021]** [2026-04-17] Permanent fixture corpus with locked entry count: the 20-entry M011/P05-P07 prompt corpus is the authoritative regression surface — every entry traces to a specific screenshot (ID+SCREENSHOT+INPUT+EXPECTED_OUTCOME). Future hook triggers earn a new milestone, not a fixture append (constitution XIV; AD-5).
- **[milestone:M021]** [2026-04-17] Dogfood attestation from state on disk: milestone closure gate reads auto-loop-result.txt + execution-log.jsonl + P*-SUMMARY.md and greps for user_prompt/safety_prompt/hook_reject_unexpected events. hook_reject_recovered is deliberately OMITTED from needles because recovery events are the success signal (AD-6). Gate is self-referential-safe — passes during its own phase by skipping in-flight summaries.
- **[milestone:M021]** [2026-04-17] MEM004 gate-internals carve-out: AD-19 single-script-file invocation shape constrains only agent-facing tool invocations. Verification-script INTERNALS may use pipes, command substitution, awk, etc. freely. The anti-pattern linter's scope rules (commands/, templates/, scripts/dispatch/lib/, tasks/*-PAYLOAD.md) enforce the distinction.
- **[milestone:M021]** [2026-04-17] Concatenation-split forbidden literals: when a gate script scans for forbidden constructs using its own literals, split the needle strings via concatenation so the gate source does not self-match during its own scan. Established P03, extended in P04 bash32-compat gate.
- **[milestone:M021]** [2026-04-17] Self-recursion guard via env flag: a phase-suite script discovered by its own run-suite.sh glob must set an env flag (e.g. M021_P04_SUITE_ACTIVE=1) and short-circuit nested invocations as no-op PASS. Outer invocation remains authoritative.
- **[milestone:M019]** [2026-04-18] Zero-token instrumentation via stdout capture-and-replay: PAYLOAD_CAPTURE tempfile then cat then emitter. Emitter runs strictly after stdout and contributes zero bytes. SC-6 byte-identical stdout enforced this way in scripts/dispatch/build-context.sh.
- **[milestone:M019]** [2026-04-18] Goodhart pairing enforced at emission time: every unit_close record carries both a cost block (estimated_cost_usd, pricing_version) and a quality block (verification_pass_rate, deviation_count, retry_count derived from existing attempt/outcome/verification_result per AD-3). Schema validator rejects records missing either. Prevents Tier 2 from optimizing cost in isolation.
- **[milestone:M019]** [2026-04-18] Sentinel-scoped JSON span overwrite in bash 3.2 (AD-7 fix): line-oriented replacement inside _generated_start / _generated_end JSON-key sentinel pair with tail-comma auto-insertion when trailing keys are present, no jq dependency. User-authored content outside the span survives evaluate-preflight re-runs byte-identical; canonical content for widened allow-lists goes through templates/autonomy-defaults.yaml.
- **[milestone:M019]** [2026-04-18] BSD awk in-keyword pitfall: awk variables starting with 'in_' silently tokenize-zero on BSD awk (default on macOS). Use ival/oval or prefer index() over 'in'. Caused a silent zero of input_per_million_usd in T01 and was reflagged as a watch-for in T02/T03/T04.
- **[milestone:M019]** [2026-04-18] Module-scoped globals and subshell loss: pricing lib sets _PRICING_WARNING_REASON in whatever shell the estimator runs in. Capturing estimator stdout via $(...) loses the warning. Workaround: route estimator stdout to a mktemp file so the estimator runs in the caller's shell and the warning survives. Applied in scripts/dispatch/dispatch-interface.sh _di_emit_dispatch_usage helper.
- **[milestone:M019]** [2026-04-18] Tier 1 metrics emitter schema (AD-4): reserve three enums at record emission time so Tier 2 rollup and Tier 3 backend-actuals land additively without rewriting emitter code. record_type: payload_breakdown | dispatch_usage | unit_close. source: estimate | runtime | aggregate. granularity: task | phase | milestone. Validator scripts/verify/m019-schema.sh enforces.
- **[milestone:M019]** [2026-04-18] Opus 4.7 dispatch payload structure (M019/P00 L1-L5): every TASK-branch payload emits a First-Turn Completeness block (Intent/Constraints/Acceptance Criteria/Files To Touch, re-surfacing existing content, no new prose); stable sections before <dispatch-volatile> marker, volatile sections after, </dispatch-volatile> close; conditional Parallel Fan-Out directive only when recipe or task plan declares parallelizable work; intensity-gate.sh documents adaptive-thinking contract as a comment block (no fixed thinking_budget literals); expressive guidance rewritten positive with a narrow dotfile whitelist for Constitution XV retained-negatives.
- **[milestone:M012]** [2026-04-21] Scanner-to-stubs-to-nav three-stage pipeline: each stage reads upstream output from stdout only (no shared state); extensions append new emission blocks after existing ones to keep downstream generators stable; marker-bounded blocks in shared config files (wiki/mkdocs.yml) allow multiple phases to edit the same file without merge conflicts via shasum byte-identity verification.
- **[milestone:M012]** [2026-04-21] Chained-gate deploy wrapper pattern: N sequential single-script-file gate invocations with first-non-zero-aborts semantics, fixed-verb per-gate stdout output (GATE/BUILD/DEPLOY/DRY-RUN/OK/FAIL) for deterministic downstream capture, and stderr-indent-on-FAIL for machine-readable triage. Four flags (--dry-run/--help/--root/--skip-smoke) cover the operator surface without a YAML driver or plugin system (Constitution XIV).
- **[milestone:M012]** [2026-04-21] Pending-sentinel artifact for operator-gated outcomes: when a phase artifact's completion requires human action outside auto-mode (e.g., live deploy, real credentials), ship a structured record with literal 'pending' values in the operator-supplied fields and 'skip' in gate-result fields. Verification gate accepts both pending-sentinel and live-populated shapes, so auto-mode advances while the human completes the live path during consolidation.
- **[milestone:M012]** [2026-04-21] Include-only SSOT with spec-quote exclusion: when scanning canonical source trees for verbatim duplication, exclude T*-PLAN.md and T*-PAYLOAD.md from the scan — task plans legitimately quote expected artifact content as the task specification, so matching them produces self-referential false positives. Candidate extraction pipeline: strip headings, blanks, and HTML comments before length-filtering.
- **[milestone:M013]** [2026-04-22] Additive-helper-append preserves byte-identity for cross-phase shared libs: scripts/integrations/github-common.sh extended P02 (12 helpers) → P03 (gh_marker_search_remote + manifest_footer 4th-arg additive-suffix) → P04 (http_probe + sidecar_update_item_cache + emit_tier1_record + classify_gh_rc + emit_conversus_gate_record). Every extension lands at end-of-helpers before the self-check block; prior function bodies stay byte-identical so earlier-phase byte-identity gates continue to pass. Optional-arg additive-suffix on existing helpers (manifest_footer 3→4 args) preserves existing call-site behavior.
- **[milestone:M013]** [2026-04-22] Gate-evolution-on-legitimate-advancement: when a later phase legitimately fills earlier-phase scaffolding (D015-style _deferred to PNN_ markers), the earlier-phase assertion evolves to accept BOTH pre/post shapes rather than fracturing the suite by duplicating hashes in a new gate. Byte-identity hashes on content NOT being advanced stay pinned as load-bearing invariants. P02→P03 (mapping table cells) and P03→P04 (reference doc TODO stubs) both applied this. The single source of byte-identity truth (the original gate) stays authoritative; later gates do not re-embed pinned hashes.
- **[milestone:M013]** [2026-04-22] Pinned-SHA byte-identity with awk-range capture-before-edit for multi-phase additive doc editing: capture awk-range shasum for the section the current phase will leave untouched BEFORE editing, then edit, then embed the literal digest in the new phase's verify gate. Robust against line-number shifts from insertions elsewhere in the doc — section boundary is the literal-prefix heading match, not a line range. M013 references/github-integration.md uses three pinned ranges across P01/P02/P03 sections, validated post-P04.
- **[milestone:M013]** [2026-04-22] Direct-cmd-subst rc-propagation gotcha (caught mid-T03 in P04): writing 'probe_out=$(http_probe …  || true)' silently zeros $? — the '|| true' tail masks the rate-limited (rc=3) and auth-expired (rc=4) signals. Fix: assign $() result then read $? on the next line. This silently broke FR-16 detection and was caught only by the rate-limit gate's negative-path assertion. Add to bash-3.2 review checklist for any helper that needs to surface non-zero rc through a captured stdout.
- **[milestone:M013]** [2026-04-22] PATH-shimmed fake-gh enforces zero-subprocess-call invariant in CI: SC-7 auto-mode safety requires that 'github-init.sh' / 'github-sync.sh' make ZERO 'gh' calls when running without TTY + --i-am-operator. The verify gate prepends a tempdir containing a fake 'gh' executable to PATH that logs every invocation to a file, runs the command, then asserts the call log is empty. Catches accidental gh calls from new code paths immediately. Pattern extends to any shell-script invariant of the form 'must NOT invoke <external-binary>'.
- **[milestone:M013]** [2026-04-22] Fixture-copy-before-live-gate: when a script reassigns ORCHESTRATOR_ROOT (e.g., github-sync.sh sets it to $PROJECT_ROOT/.orchestrator), live-mode gates MUST 'cp -R fx/. tmp/' the fixture orchestrator-state to a tempdir before invoking — running against the repo fixture tree directly pollutes it with sidecar updates and observability JSONL records. Pair with M013_GH_STUB_DIR pointing at the fixture's gh-stub-responses subdir so the script never touches real network.
- **[milestone:M013]** [2026-04-22] External-watchdog-plus-adapter-internal-timeout (Constitution XII belt-and-suspenders): for opt-in external-tool gates (e.g., github-conversus-gate.sh wrapping the M011/P07 conversus adapter), wrap the adapter invocation in an outer 'kill -TERM at TIMEOUT seconds; sleep 1; kill -KILL at TIMEOUT+1' subshell EVEN IF the adapter has its own internal timeout. Defends against adapter timeout bugs and makes the worst-case CI runtime auditable from the wrapper alone.
- **[milestone:M013]** [2026-04-22] Verdict-rc-parity for opt-in deliberation gates: rc=0 PASS, rc=2 BLOCK, rc=1 ERROR passed verbatim through the gate so callers can distinguish BLOCK (legitimate veto) from ERROR (gate broken). Upstream loops should treat BLOCK as a per-row error via if-guarded increment rather than abort. Conversus adapter '--strict' mode (added P04) flips graceful degradation off — missing binary becomes rc=1 ERROR (FAIL) instead of SKIPPED+exit-0. Use --strict for callers that REQUIRE the adapter to be present.
- **[milestone:M013]** [2026-04-22] FR-12-v1 negative-grep guard for sibling-runtime byte-identity: when one runtime adopts a feature that other runtimes legitimately don't yet support (FR-12 Claude-Code-only v1 for the post-verify hook), guard sibling-runtime files (codex/cursor adapters + installers) with a negative-grep gate for the feature marker (e.g., 'post_verify' / 'FR-12') rather than pinned-sha digests. Cheaper to author and READ, and self-repairs if codex/cursor later gain legitimate content under a DIFFERENT marker. Trade-off: weaker than pinned-sha against accidental drift, but the constraint here is intent-shape not exact bytes.
- **[milestone:M026]** [2026-04-24] M026: Edition-resolution two-tier detection (env-var primary + metadata-probe fallback) for runtime edition identification under single-venv reality. CONVERSUS_EDITION=oss|paid env var declares active edition; pip show conversus Home-page probe is fallback; stub-mode short-circuit edition=unknown. See knowledge/patterns/MEM029.md and DECISIONS D022.
- **[milestone:M026]** [2026-04-24] M026: <TOOL>_EDITION=<value> env-var convention for OSS-default escape hatches. Closed enum (oss|paid); stderr warning + fall-through on bad values; env-var trumps metadata probe; CONVERSUS_HOME absolute override trumps both. Preset edition_required: paid frontmatter triggers paid-only-on-OSS refusal diagnostic before any heavy work. See knowledge/conventions/MEM030.md.
