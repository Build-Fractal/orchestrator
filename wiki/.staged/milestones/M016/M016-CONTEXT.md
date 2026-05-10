---
schema_version: "1.0"
type: context-draft
milestone: "M016"
status: finalized
created_at: "2026-04-16T01:49:29Z"
finalized_at: "2026-04-16T01:49:29Z"
---

## Architectural Decisions

### AD-1: Sentinel convention for "now" timestamps

`write-summary.sh --completed_at` becomes optional. When omitted, defaults to
now (computed internally via `date -u`). The sentinel value `--completed_at=now`
is also accepted for explicit plan-template readability. Existing callers passing
an ISO-8601 string continue to work unchanged. This eliminates the single
biggest source of `$(date ...)` command-substitution prompts in dispatched
subagents.

### AD-2: Enforcement via lint, not runtime hook

Anti-pattern enforcement is a static linter (`scripts/verify/anti-pattern-lint.sh`)
wired into the verify ladder and optionally into pre-commit. A PreToolUse hook is
deferred — high risk of misfires on legitimate `bash -c 'if … then …'` patterns.
If lint-only proves insufficient (prompts still appear after M016), a hook can be
layered on in a follow-up.

### AD-3: Verify-suite wrapper discovers by naming convention

`scripts/verify/run-suite.sh` auto-discovers gate scripts matching
`scripts/verify/<milestone>-<phase>-*.sh` (e.g. `m015-p02-*.sh`). This aligns
with the established convention visible in all milestones since [M007](../../milestones/M007/index.md). The wrapper
does not scan arbitrary directories — pass it a milestone+phase identifier and it
glob-matches under `scripts/verify/`.

### AD-4: Agent-facing content sweep only

Class A anti-pattern sweep targets `commands/*.md`, `templates/*.md`, and
dispatch payload builders — content that an LLM agent will see and reproduce in
Bash tool calls. `scripts/*.sh` contents are *not* swept because Claude Code's
safety heuristic only fires on the agent's direct Bash tool invocation string,
not on the internals of scripts those invocations run. Wrapper scripts are free
to use compound bash, pipes, awk, etc. internally.

### AD-5: Dogfood validation via replay of a prior phase

P04 validates SC-1 (zero prompts) by running `orchestrator:auto` against an
existing completed phase (candidate: [M008](../../milestones/M008/index.md) P03 or similar multi-task phase) on
a detached branch. This provides real-world before/after prompt counts without
entangling M016 in its own replay. A hermetic fixture replay can be added later
if regression testing demands it.

## Scope Boundaries

### In Scope

- `write-summary.sh` API change: `--completed_at` optional, `now` sentinel, internal timestamp computation
- `scripts/verify/run-suite.sh` wrapper: auto-discover, execute, tally PASS/FAIL for a phase's gate scripts
- `scripts/verify/anti-pattern-lint.sh`: detect `$(…)`, backticks, `{a,b}` brace expansion in agent-facing files; exit non-zero with diagnostics
- Anti-pattern catalog in `ANTIPATTERNS.md` (top-level, extend existing file)
- Dispatch payload template: add "Prohibited inline bash patterns" section with Class A patterns and wrapper alternatives
- `settings.json` allow-list promotion: move safe tool wildcards from `settings.local.json` into project-checked `settings.json`
- Plan-template updates: replace chained verify examples with `run-suite.sh` invocation
- Dogfood validation: auto-run a prior completed phase, capture prompt count

### Out of Scope

- Expanding autonomy to credential/destructive/external-service operations (those legitimately prompt)
- Hardening interactive slash commands outside `orchestrator:auto`
- Rewriting non-autonomous scripts (one-off diagnostics, migration tools)
- PreToolUse hook (deferred to a follow-up if lint proves insufficient)
- Scanning `scripts/*.sh` internals for Class A patterns (irrelevant — see AD-4)

## Design Constraints

- **Bash 3.2 compatibility**: all new scripts (wrapper, linter) must honor constitution principle VIII. No `declare -A`, no `${var,,}` case conversion, no `mapfile`.
- **Backwards compatible**: `write-summary.sh --completed_at=<ISO>` continues to work when supplied. New behavior is purely additive (optional + sentinel).
- **No speculative abstraction**: only address scripts and patterns that *actually triggered prompts* in M015/M008 runs. Don't redesign scripts that haven't caused problems.
- **Pre-M009 deadline**: must ship before M009 launch. Phase decomposition produces shippable state at each boundary so milestone can be paused cleanly.
- **Self-referential linter safety**: the anti-pattern linter's own regex fixtures must not trigger the linter. Use a stable marker comment (e.g. `# lint-ignore: anti-pattern-test`) or exclude the linter's own file from its scan.

## Open Questions

All questions resolved during discussion. No outstanding open questions gate planning.

- ~~Q1 Sentinel convention~~ → AD-1 (both optional + `now` sentinel)
- ~~Q2 Enforcement mechanism~~ → AD-2 (lint only, hook deferred)
- ~~Q3 Verify wrapper layout~~ → AD-3 (naming convention discovery)
- ~~Q4 Catalog location~~ → top-level `ANTIPATTERNS.md`
- ~~Q5 Dogfood strategy~~ → AD-5 (replay prior phase)
- ~~Q6 API break~~ → no break, additive only
- ~~Q7 Sweep scope~~ → AD-4 (agent-facing content only)
