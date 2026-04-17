# Feature Specification: Autonomous Hardening v2 — Shape & Probe Elimination

**Feature Branch**: `021-autonomous-hardening-v2`
**Created**: 2026-04-17
**Status**: Draft
**Input**: User description: "M016 closed Class A triggers (outer `$(...)`, outer `{...}`, compound `&& || ; |`). 20 screenshots from M011/P05–P07 auto-mode runs show ~12 distinct trigger classes M016 did not cover: `$VAR`/`$?` simple_expansion, `$(cmd)` inside redirect targets, `{...}` inside quoted strings, parser fallthrough (\"Unhandled node type: string\"), `sed -n 'M,Np'` misclassified as write, bare `bash /tmp/*.sh` invocations, wildcard reads under `/var/folders/**`, project-relative `tmp/` access, compound shapes still leaking from task-PAYLOAD body bash and mid-task probes. Need to close all of it — shape linter v2 (expanded scope + new patterns), canonical wrapper script catalog for recurring probe/range-read/env-inline patterns, permission widening for safe read-only shapes, and a pre-Bash hook that auto-rewrites fixable shapes and hard-rejects the rest with a diagnostic pointing to the wrapper. Must run BEFORE M019 so observability-metrics dogfooding lands on a true zero-prompt baseline."

## Problem Statement

M016 (autonomous hardening v1) made `orchestrator:auto` survive the three highest-frequency prompt triggers: command-substitution in `write-summary.sh`, `awk '{print $1}'` brace expansion, and `&& | ; |` compound chains in verify sweeps. Those fixes were validated by M016 dogfooding itself. Real-world auto-mode runs on M011 (the spec-management milestone) over 2026-04-16 to 2026-04-17 produced 20 distinct approval-prompt screenshots across phases P05, P06, and P07 — proof that M016 closed the largest class but left a long tail of roughly twelve other trigger types intact.

The residual prompts fall into three orthogonal gaps:

1. **Shape heuristics M016 did not catalog.** Claude Code's safety layer fires on patterns M016's linter does not know about:
   - `$VAR` or `$?` anywhere in an inline Bash tool call → "Contains simple_expansion."
   - `$(cmd)` inside a redirect target (e.g. `bash a.sh > "$LOG" 2>&1`) → "Redirect target contains $(cmd) output — path is runtime-determined."
   - `{...}` inside a double-quoted string (even when the braces are not an expansion — e.g. awk bodies embedded in larger quoted args) → "Contains brace with quote character (expansion obfuscation)."
   - Heredocs containing `$VAR` expansions or nested quoting → parser gives up and prompts with "Unhandled node type: string."
   - Task plans re-introducing `for … ; do … ; done` / `if … ; then … ; fi` / `cd X && Y` in inline bash because the M016 linter does not scan `.orchestrator/milestones/**/tasks/*-PAYLOAD.md` bash fences or the dispatch-payload-builder output.

2. **Allow-list gaps for legitimately safe shapes.** Read-only operations that should be pre-approved still prompt:
   - `bash /tmp/*.sh` and `bash /var/folders/**/*.sh` invocations for ad-hoc probes written via `cat > /tmp/probe.sh` earlier in the turn. Only `bash scripts/*` and `bash .specify/*` are currently allow-listed.
   - `cat /var/folders/**/T/tmp.*/**` reads (macOS temp-dir wildcards).
   - Project-relative `tmp/` (not `/tmp/`) used as a fixture root.
   - Read-only `sed -n 'M,Np' file`, which Claude Code misreads as a write because the `p` flag appears inside single quotes.
   - Bare `echo "RC=$?"` trailing a bash invocation — idiomatic but trips simple_expansion.

3. **No programmatic rewrite/rejection layer.** Even with (1) catalogued and (2) widened, agents will sometimes emit shape-unsafe bash simply because their prompts don't enumerate every forbidden form. Today there is no pre-Bash hook that can rewrite the trivially-fixable cases (e.g. strip `; echo RC=$?`, redirect `$(…)` into a temp file, replace `sed -n 'M,Np' file` with `scripts/util/read-range.sh file M N`) or reject the rest with a one-line diagnostic telling the agent which wrapper to call instead.

Fix all three in a single milestone. Ship before M019 (observability metrics) so the metrics dogfood runs on a zero-prompt baseline and we get clean data on time/tokens/$ per fully-autonomous phase.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — M011/P05–P07 Trace Replays With Zero Prompts (Priority: P1)

A developer replays the exact Bash tool-call sequence captured in the 20 M011/P05–P07 screenshots against the hardened orchestrator. Every call either executes without prompting or is deterministically rewritten/rejected by the pre-Bash hook before the harness sees it.

**Why this priority**: This is the closing-the-loop test. The screenshots *are* the regression corpus — if the hardened system replays them prompt-free, the autonomy claim is defensible.

**Independent Test**: Export the 20 screenshot tool-call strings into `tests/fixtures/m011-p05-p07-prompt-corpus.txt`. Run `scripts/verify/replay-prompt-corpus.sh` which feeds each line through the same shape classifier Claude Code uses (approximated via a local implementation grounded in the observed trigger names). Count the remaining "would-prompt" cases. Must be zero.

**Acceptance Scenarios**:

1. **Given** the 20-line prompt corpus fixture, **When** the replay runs against the pre-Bash hook + updated `settings.json`, **Then** 20 / 20 lines resolve to either "allow" or "auto-rewrite" (none resolve to "prompt").
2. **Given** an inline bash call of the form `echo "RC=$?"`, **When** the pre-Bash hook sees it, **Then** the hook rewrites it to `bash scripts/util/echo-rc.sh "$RC_FILE"` (or similar) and the rewritten call is allow-listed.
3. **Given** a `sed -n '686,1050p' file.md` call, **When** the hook sees it, **Then** the hook rewrites it to `bash scripts/util/read-range.sh file.md 686 1050` and the rewritten call is allow-listed.
4. **Given** a `bash /tmp/probe.sh` call, **When** the hook sees it, **Then** the call is allow-listed directly (widened permissions) — no rewrite needed.

---

### User Story 2 — Shape Linter v2 Catches Residual Patterns In Agent-Facing Content (Priority: P1)

A developer or subagent edits a command, template, task-PAYLOAD body, or dispatch-payload builder and accidentally introduces one of the residual shape triggers. The linter fails the verify ladder with a clear diagnostic naming the file, line, offending pattern, and the wrapper-script or rewrite alternative.

**Why this priority**: M016 proved mechanical enforcement is the only way to keep agent-facing content clean across many milestones. Widening the linter's scope + pattern set is the equivalent maintenance step for Class B triggers.

**Independent Test**: Seed three test fixtures (one per residual category): (a) a template with `echo "RC=$?"`, (b) a task-PAYLOAD body with `foo > "$LOG"` where `$LOG` is `$(cmd)`, (c) a command.md with `awk 'BEGIN{…}'` inside a quoted argument. Run `scripts/verify/anti-pattern-lint.sh`. It must flag all three with distinct error codes.

**Acceptance Scenarios**:

1. **Given** a file under `commands/`, `templates/`, `scripts/dispatch/lib/`, or `.orchestrator/milestones/**/tasks/*-PAYLOAD.md` containing any of the Class B shapes, **When** the linter runs, **Then** it exits non-zero and names the file, line, pattern class (simple-expansion / redirect-cmd-sub / quoted-brace / heredoc-expansion / task-plan-compound), and the remediation.
2. **Given** the M016 Class A patterns are still present in a file, **When** the v2 linter runs, **Then** those are still flagged (v2 is a superset — no regression).
3. **Given** a file legitimately documents a forbidden pattern inside an ANTIPATTERNS.md code block or a FORBIDDEN-region marker, **When** the linter runs, **Then** the suppressed region is not flagged (M016 suppression semantics preserved).
4. **Given** the linter is run over `.orchestrator/milestones/**/tasks/*-PAYLOAD.md`, **When** a task plan contains an inline `for … ; do … ; done` loop in a bash fence, **Then** it is flagged with a pointer to `scripts/util/run-suite.sh` or a phase-specific wrapper.

---

### User Story 3 — Wrapper Script Catalog Replaces Recurring Probe Patterns (Priority: P1)

A subagent dispatched to a task needs to (a) run an ad-hoc one-off bash snippet, (b) read a line range out of a file, or (c) run a command with a handful of inline environment variables. Instead of constructing inline bash that trips shape heuristics, the subagent calls one of three canonical wrappers in `scripts/util/`.

**Why this priority**: The M011 screenshots show the same three shapes recurring with different payloads. A small fixed catalog of wrappers eliminates the pattern without teaching agents a different bash idiom every time.

**Independent Test**: Each wrapper has a dedicated gate script (`scripts/verify/m021-p02-<wrapper>.sh`) that exercises the wrapper's happy path and at least one failure mode. All three gates must pass; the wrappers must be referenced from the dispatch payload's "Allowed invocation shapes" section and from the anti-pattern linter's remediation hints.

**Acceptance Scenarios**:

1. **Given** a developer needs to run `bash /tmp/probe.sh` with `ORCH_REPO=/path` in front, **When** the wrapper `scripts/util/with-env.sh ORCH_REPO=/path -- bash /tmp/probe.sh` is used, **Then** the wrapper sets the env, execs the command, echoes `RC=<n>` to a file, and exits with the child's RC.
2. **Given** a developer needs to read lines 686–1050 of a markdown file, **When** `scripts/util/read-range.sh file.md 686 1050` is called, **Then** the range is emitted on stdout and the wrapper exits 0 for valid ranges / 2 for an out-of-range request.
3. **Given** a developer needs to run a short throwaway bash snippet that would otherwise be inline, **When** the snippet is staged via `scripts/util/run-probe.sh <path-to-staged-probe>`, **Then** the probe runs from an approved location and its output is captured to a known file path that is already allow-listed.
4. **Given** the dispatch payload is built for a subagent, **When** the payload is rendered, **Then** its "Allowed invocation shapes" section names all three wrappers with one-line usage examples.

---

### User Story 4 — Pre-Bash Hook Auto-Rewrites Or Hard-Rejects With A Diagnostic (Priority: P1)

A subagent emits a Bash tool call with a shape that would ordinarily prompt the user. A pre-Bash hook inspects the call string, either (a) deterministically rewrites it to a safe equivalent, or (b) rejects it with a one-line diagnostic that points the agent at the wrapper it should have used. The agent sees the rejection in the tool result, picks the allowed shape on the next try, and the run continues without a user prompt.

**Why this priority**: The parser-fallthrough prompt ("Unhandled node type: string") fires *before* the allow-list is consulted, so it cannot be fixed by permission widening alone. A hook is the only way to intercept and either fix or cleanly fail those calls. Hard-rejection with a diagnostic is strictly better than a user prompt because it stays in the autonomous loop.

**Independent Test**: For each of the six rewriteable shapes (trailing `; echo RC=$?`, `sed -n 'M,Np' f`, `cat > /tmp/x.sh <<EOF … EOF ; bash /tmp/x.sh`, `cd X && bash Y`, `VAR=val bash Z`, `$(cmd)`-in-redirect-target), the hook must produce the expected rewrite. For each of four hard-reject shapes (nested `$(…)`, compound `&& … | … | …` > 2 stages, heredoc with `$(` expansion, braces inside quotes that aren't literal), the hook must emit a specific diagnostic naming the wrapper to use. Test harness: `tests/hook/rewrite-cases.sh` + `tests/hook/reject-cases.sh`.

**Acceptance Scenarios**:

1. **Given** a Bash tool call matching a rewriteable pattern, **When** the pre-Bash hook fires, **Then** the hook emits a rewritten call that executes successfully and no user prompt fires.
2. **Given** a Bash tool call matching a hard-reject pattern, **When** the hook fires, **Then** the hook blocks the call and emits a diagnostic of the form `REJECT: <pattern-class> — use scripts/util/<wrapper>.sh instead. See ANTIPATTERNS.md#<id>.`
3. **Given** a legitimate call that does not match any rewrite or reject pattern, **When** the hook fires, **Then** the hook passes through silently (no performance regression on the 95% allowed path).
4. **Given** the hook is installed via `.claude/settings.json`, **When** a new contributor clones the repo, **Then** running `orchestrator:auto` activates the hook automatically without additional setup.

---

### User Story 5 — Settings Allow-List Closes Read-Only Shape Gaps (Priority: P2)

A subagent performs routine read-only operations (listing a temp fixture, reading an absolute path, checking an exit code) using standard Unix tools. The project-level `.claude/settings.json` covers these without prompting and without requiring a `settings.local.json` entry from the contributor.

**Why this priority**: These are cheap wins — permission widening doesn't require any new code, just audited settings. They close the "Cat this /var/folders/... tmp file" and "bash /tmp/...sh" prompts directly.

**Acceptance Scenarios**:

1. **Given** a subagent runs `cat /var/folders/**/T/tmp.*/knowledge/spec/story/SPEC-US-001.md`, **When** the call fires, **Then** the allow-list covers `/var/folders/**` reads and no prompt surfaces.
2. **Given** a subagent runs `bash /tmp/m011-p07-dogfood.sh` with or without `ORCH_REPO=...` prefix, **When** the call fires, **Then** the allow-list covers `bash /tmp/*.sh` and no prompt surfaces.
3. **Given** the project has `tmp/` as a fixture root (relative path, not `/tmp/`), **When** a subagent reads inside `tmp/**`, **Then** the allow-list covers it.
4. **Given** a subagent reads a line range via `sed -n 'M,Np' file`, **When** the call fires, **Then** the allow-list matches the read-only shape and no prompt surfaces. (If shape-heuristic still fires despite allow-list, the pre-Bash hook rewrites per US-4.)

---

## Success Criteria

- **SC-1**: The full 20-line M011/P05–P07 prompt corpus replays with zero would-prompt cases under the hardened configuration. (Regression corpus is permanent — added to CI.)
- **SC-2**: `scripts/verify/anti-pattern-lint.sh` detects all Class A (M016) + all Class B (M021) patterns across `commands/`, `templates/`, `scripts/dispatch/lib/`, and `.orchestrator/milestones/**/tasks/*-PAYLOAD.md`.
- **SC-3**: Three canonical wrappers (`scripts/util/with-env.sh`, `scripts/util/read-range.sh`, `scripts/util/run-probe.sh`) are shipped, gate-tested, and referenced from the dispatch payload + linter remediation hints.
- **SC-4**: The pre-Bash hook is installed via `.claude/settings.json`, rewrites the six deterministic shapes, and hard-rejects the four remaining shapes with a wrapper-pointing diagnostic.
- **SC-5**: `.claude/settings.json` (not `settings.local.json`) covers `/var/folders/**` reads, `bash /tmp/*.sh`, project-relative `tmp/**`, and read-only `sed -n`/`head`/`tail`/`stat` on abs paths.
- **SC-6**: A fresh auto run on a ≥4-task phase planned after M021 produces zero approval prompts with default `.claude/settings.json`.
- **SC-7**: The milestone's own execution serves as the dogfood proof (like M016 did) — M021 closes itself with zero prompts.

## Non-Goals

- Expanding autonomy to operations that legitimately warrant human review (credential prompts, destructive git operations, external-service writes, `gh release`, `npm publish`). Those remain gated via the existing `deny:` list.
- Rewriting historical milestones' task plans to use the new wrappers — only new task plans (M019 onward) consume them.
- Changing Claude Code itself or advocating for upstream changes to its safety layer. This milestone treats the safety layer as fixed and works around it.
- Removing the pre-Bash hook in non-auto modes (`orchestrator:dispatch`, interactive slash commands). The hook is active whenever the project settings load; it just matters less outside autonomous runs.
- Optimizing the hook for throughput. Correctness on the 10-pattern matrix matters; a 100ms hook latency is acceptable.

## Constraints

- Must ship before M019 so metrics dogfooding lands on a zero-prompt baseline (per revised roadmap in CLAUDE.md).
- Must remain Bash 3.2 compatible (constitution principle IX) — wrappers and hook run on macOS default bash.
- Must not regress any M016 behavior — the v2 linter is a strict superset of v1, and all existing wrappers (`scripts/verify/run-suite.sh`) continue to work.
- Must not break interactive (non-auto) workflows — hook rewrites and rejections must be transparent or at least non-blocking when a human is at the keyboard.
- No new runtime dependencies — the hook is pure bash + standard macOS/Linux tools, no jq/node/python requirements beyond what the orchestrator already requires.
- Follows constitution principle XIV (No Speculative Complexity): the 10-pattern rewrite/reject matrix is closed on the evidence from M011 screenshots; additional shapes get added only when they reappear in a later run.
