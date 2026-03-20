# scripts/

Executable bash helper scripts organized by concern. Called by command files in `commands/`.

## Constraints
- **Bash 3.2 compatible** — no `declare -A`. Use parallel indexed arrays.
- **No python3/jq hard deps** — YAML parsed via grep/sed/awk. jq is optional fallback.
- **Structured output** — every script emits prefixed lines to stdout (e.g., `PASS:`, `LOCK:`). Errors to stderr. Exit 0 success, 1 failure.
- **Registered in extension.yml** — all 21 scripts listed under `provides.scripts` with `executable: true`.

## Directories

### state/
State machine primitives. No side effects — read-only queries on disk state.
- `derive-phase.sh <milestone-dir>` — 9-state derivation from file presence
- `read-config.sh <key> [--defaults <file>]` — 4-layer config resolution (env > local > project > defaults)
- `read-roadmap.sh <file> <query>` — roadmap parser with 6 modes (frontmatter, phases, status, phase, active-phase, tier, count)

### dispatch/
Context assembly for task dispatch. Reads state, produces payload.
- `build-context.sh <root> <M###> <P##> <T##>` — assemble minimal dispatch payload; budget metrics to stderr
- `scope-filter.sh <file> <M###/P##> [--type knowledge|decisions]` — filter knowledge/decisions by scope tags
- `detect-capabilities.sh` — detect runtime capabilities (subagent support, git worktrees, etc.)

### verify/
Mechanical verification scripts. Structured PASS/FAIL output.
- `check-must-haves.sh <phase-dir>` — check truths, artifacts, key links from phase plan
- `check-boundary-map.sh <roadmap> <phase>` — cross-phase interface verification
- `check-scope.sh <phase-dir>` — scope violation warnings (always exits 0)
- `run-commands.sh <commands...>` — execute configured verification commands

### knowledge/
Knowledge artifact generation. Append-only where applicable.
- `write-summary.sh` — generate task/phase/milestone summaries with YAML frontmatter
- `append-decision.sh` — sequential D### ID assignment, append to DECISIONS.md
- `append-knowledge.sh` — scoped entries per FR-062 format
- `consolidate-artifacts.sh` — compress + archive (≥60% footprint reduction target)

### lifecycle/
Orchestration lifecycle management. Side effects (creates/modifies files).
- `scaffold.sh <root> <M###>` — idempotent milestone directory scaffolding
- `lock-manager.sh <create|status|break|update> <lock-file>` — PID-based liveness detection
- `stuck-detector.sh <execution-log> <unit-id>` — dispatch-twice-without-completion check
- `recovery-briefing.sh <milestone-dir>` — crash recovery context from surviving artifacts
- `budget-checker.sh <execution-log> [--dispatch-budget N]` — dispatch count + duration budgets
- `rollback-phase.sh` — phase rollback with archive preservation + downstream dep flagging
- `mark-complete.sh` — create milestone validation marker (M###-VALIDATED)
