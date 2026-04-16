# Feature Specification: Autonomous Hardening

**Feature Branch**: `016-autonomous-hardening`
**Created**: 2026-04-15
**Status**: Draft
**Input**: User description: "Make `orchestrator:auto` truly autonomous in Claude Code. Recent runs are interrupted by Claude Code safety prompts that cannot be disabled via permissions — `$(date ...)` command substitution in `write-summary.sh` calls, brace expansion in `awk '{print $1}'`, compound bash chains (`&& | ; |`), and missing allow-list entries for `sed` / `awk` / `/usr/bin/sed`. Eliminate the *generation* of those patterns (Class A safety checks can't be allow-listed) and widen the allow-list for Class B gaps. Ship before M009 so the launch narrative includes a credible autonomous mode."

## Problem Statement

`orchestrator:auto` is the flagship autonomous-execution command. Its credibility — and the project's ethos of "zero-context dispatched tasks that run to completion" — depends on auto mode running end-to-end without human approval prompts. Recent runs on M015 and M008 show the opposite: multiple prompts per phase, forcing the user to babysit the loop.

The prompts fall into three classes, each requiring a different fix:

1. **Class A — Claude Code hard safety checks.** Commands containing `$(...)` (command substitution), backticks, `{...}` brace expansion, or multi-command chains (`&&`, `||`, `;`, `|`) always trigger a safety prompt, regardless of `"defaultMode": "acceptEdits"` or allow-list entries. These cannot be suppressed; the orchestrator must stop emitting them.

2. **Class B — allow-list gaps.** `/usr/bin/sed *`, `awk *`, and similar tool invocations are allow-listable but live only in `settings.local.json` (user-specific). New users clone the repo and re-encounter them.

3. **Class C — API design that forces Class A.** `scripts/knowledge/write-summary.sh` requires `--completed_at=<ISO-8601>`, so every subagent writing a summary falls into `--completed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)`. This one API is the single biggest repeat offender in recent runs (observed on P02 T01, P04 T01, P04 T05, plus multiple earlier milestones).

Carrying this state into M009 would contradict the launch claim that the orchestrator runs autonomously. The fix is scoped and surgical: redesign script APIs that force command substitution, provide wrapper scripts for multi-step verify suites, add explicit anti-pattern guardrails to the dispatch payload, and promote safe tool wildcards from local to project settings.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Full Phase Runs To Completion Without Prompts (Priority: P1)

A developer runs `orchestrator:auto` on a freshly-planned phase in Claude Code with default settings. The loop derives state, dispatches every task in fresh subagent contexts, verifies each one, and advances until the phase completes — with zero approval prompts surfaced to the user.

**Why this priority**: This is the definition of "truly autonomous." If even one prompt surfaces per phase, the user must stay at the keyboard, and the autonomous-execution value proposition collapses.

**Independent Test**: Pick a representative phase (e.g. a 4–6 task phase touching scripts, templates, and verify suites). Execute `orchestrator:auto` end-to-end from a fresh Claude Code session with project-default permissions. Capture the subagent transcripts and grep for "Do you want to proceed" prompts — the count must be zero.

**Acceptance Scenarios**:

1. **Given** a planned phase with ≥4 tasks, **When** `orchestrator:auto` runs to completion, **Then** no Claude Code approval prompt is surfaced to the user across the full loop.
2. **Given** a dispatched subagent writes a task summary, **When** it calls `write-summary.sh`, **Then** the call contains no `$(...)` command substitution, no backticks, no brace expansion.
3. **Given** a dispatched subagent runs a phase's verify suite, **When** it tallies results, **Then** it invokes a single wrapper script (not a chained `bash … && bash … | awk | sort | uniq` pipeline).
4. **Given** a project cloned fresh into a new workspace, **When** the developer runs `orchestrator:auto` with only the checked-in `settings.json` (no `settings.local.json` entries), **Then** no prompt fires that requires an allow-list entry the project didn't provide.

---

### User Story 2 - Anti-Pattern Guardrails Prevent Regression (Priority: P1)

A developer (or Claude-as-subagent) edits a plan template, script, or dispatch payload and accidentally reintroduces one of the prohibited patterns. The guardrails catch it before it reaches a user-facing `orchestrator:auto` run.

**Why this priority**: One-time elimination is insufficient — the patterns recur naturally because `$(date -u ...)` is idiomatic bash. Without mechanical enforcement, the autonomy property decays within a few milestones.

**Independent Test**: Seed a test plan file with a call like `bash scripts/knowledge/write-summary.sh task /tmp/x.md --completed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ) ...`. Run the repo's anti-pattern linter. It must fail with a clear diagnostic naming the file, line, and offending pattern, and suggest the wrapper-script or sentinel alternative.

**Acceptance Scenarios**:

1. **Given** a script or template file containing `$(…)`, backticks, or `{…,…}` brace expansion in a bash invocation, **When** the anti-pattern linter runs, **Then** it exits non-zero and names the offender with a remediation hint.
2. **Given** a dispatch payload is built for a subagent, **When** the payload is rendered, **Then** it includes an explicit "Prohibited inline bash patterns" section listing the Class A patterns and pointing to the wrapper-script alternatives.
3. **Given** a contributor runs the project's pre-commit checks, **When** a staged file contains an anti-pattern, **Then** the commit is rejected with the diagnostic.

---

### User Story 3 - Verify Suites Run Via A Single Wrapper (Priority: P2)

When a task's plan calls for running multiple verify scripts and tallying PASS/FAIL counts, the dispatched subagent invokes a single wrapper script that does the discovery, execution, and tallying. No chained `&&` pipelines, no inline `awk '{print $1}' | sort | uniq -c`.

**Why this priority**: Verify-suite chains are the second-most-frequent prompt source (observed in M015 P02 verification, M003 P08, and several audits). One wrapper replaces dozens of task-plan snippets.

**Independent Test**: Run the wrapper against a phase directory with mixed PASS/FAIL scripts. It must exit with the correct aggregate status and print a summary machine-parseable by downstream verification.

**Acceptance Scenarios**:

1. **Given** a phase directory containing ≥3 `*.sh` gate scripts, **When** the developer runs `scripts/verify/run-suite.sh <phase-path>`, **Then** all scripts execute and the wrapper prints `PASS: N / FAIL: M` plus per-script status.
2. **Given** all gate scripts pass, **When** the wrapper runs, **Then** it exits 0.
3. **Given** any gate script fails, **When** the wrapper runs, **Then** it exits non-zero with the failing script names surfaced first.

---

## Success Criteria

- **SC-1**: A full `orchestrator:auto` run on a ≥4-task phase produces zero Claude Code approval prompts under project-default settings.
- **SC-2**: `grep -rE '\\$\\(|`|\\{[a-zA-Z0-9_]+\\.\\.' commands/ templates/ scripts/` returns no matches in agent-facing content (excluding comments and the anti-pattern linter's own regexes).
- **SC-3**: `write-summary.sh --completed_at` is optional; omitting it defaults to now.
- **SC-4**: A single `scripts/verify/run-suite.sh <phase-path>` replaces the chained pattern in task plan templates.
- **SC-5**: The anti-pattern linter is runnable standalone and wired into the project's verify ladder.
- **SC-6**: `settings.json` (not `settings.local.json`) contains the allow-list entries needed for the auto path under project defaults.

## Non-Goals

- Expanding autonomy to operations that legitimately warrant human review (credential prompts, destructive git operations, external-service writes). Those remain gated.
- Hardening against *user-invoked* slash commands outside `orchestrator:auto` — interactive commands may still surface prompts.
- Rewriting non-autonomous scripts (one-off diagnostics, migration tools run manually) to remove anti-patterns.

## Constraints

- Must ship before M009 launch so autonomy is a credible launch claim.
- Must not break existing callers of `write-summary.sh` — `--completed_at=<ISO>` continues to work when supplied.
- Must remain Bash 3.2 compatible (constitution principle VIII).
- No `declare -A`, no speculative abstraction for other scripts that don't currently trigger prompts.
