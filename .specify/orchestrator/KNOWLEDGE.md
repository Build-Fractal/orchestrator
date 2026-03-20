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
- Summary frontmatter: 14-field schema (`id`, `parent`, `milestone`, `provides`, `requires`, `affects`, `key_files`, `key_decisions`, `patterns_established`, `drill_down_paths`, `duration`, `verification_result`, `completed_at`)

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
