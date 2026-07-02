---
schema_version: "1.0"
type: feature-spec
feature_slug: "047-auto-v2b-unified-serial"
created_at: "2026-07-02"
status: "Ready-for-discuss"
milestone: "M046"
---

# Feature Specification: 047-auto-v2b-unified-serial

**Feature Branch**: `047-auto-v2b-unified-serial`
**Created**: 2026-07-02
**Status**: Ready-for-discuss
**Last Revised**: 2026-07-02 (Full+PASS conversus gate; MIT-1..MIT-7 amendments applied)
**Milestone**: M046
**Input**: User description: "Unified tier-sized autonomous entry (serial core): collapse orchestrator:do into orchestrator:auto behind one classify-first entry, add a --unattended serial safety envelope (in-segment budget ceiling with watchdog SIGKILL, reserve-then-spend accounting, default-DENY PreToolUse path+tool allowlist, BLOCK-on-ambiguity, thrash-as-terminal), harden the process-fresh driver marker contract, and degrade gracefully on non-CC runtimes. Fan-out coordinator and Posture-3 Stop-hook are carved to future milestones."

**Predecessor**: M045 / `M-auto-v2a` (Posture 1, shipped 2026-07-02, PR #15) — this spec consumes M045's process-fresh driver (`self-continue-drive.sh`, `self-continue-branch.sh`, `self-continue-status.sh`) as its substrate base. Substrate decision **D015**: the re-entry substrate is process-fresh `claude -p`, never in-session `ScheduleWakeup`.
**Scoping inputs** (on disk): `.orchestrator/proposals/M-auto-v2b-pre-spec.md` (full-scope draft), `M-auto-v2b-redteam-conditions.md` (3-lens adversarial conditions, all PROCEED_WITH_CONDITIONS), `M-auto-v2b-P00-spike-evidence.md` (concurrency + cost viability spike).
**Scope decision**: SPLIT. This spec is the **serial core** (v2b). Fan-out coordinator + worktree/lock/lease is carved to a future `v2c-fanout` milestone (viability banked at N=3 by the P00 spike). Posture-3 Stop-hook (until-verified) is carved to its own demand-driven slice.

## Problem Statement

M045 closed the single sharpest gap in autonomous execution — the loop can now cross its own context-rotation boundary via a process-fresh driver that re-spawns `claude -p` and resumes from disk. But it shipped as a deliberately tight slice: one posture (attended self-continue), on one tier (C), with no unattended mode and no unification of the orchestrator's two autonomous front doors. Four concrete, evidence-grounded gaps remain, and closing them safely is this milestone.

**Gap 1 — Two front doors, one of them a dead-end.** `orchestrator:do` (Tier A/A+/B one-shot) and `orchestrator:auto` (Tier C loop) are separate commands sitting over the *same* M024 classifier and the *same* downstream routers. `do`'s Tier B/C branch (`scripts/intake/do-entry.sh`) is a print-and-exit stub that tells the operator to run another command in their next turn — it never enters a loop. The operator must know which command to type and hand-relay between them. There is no single "just run this" entry that sizes itself to the task.

**Gap 2 — Autonomy stops when the operator leaves.** M045 is attended by construction; there is no unattended/overnight execution. Critically, the safety machinery an unattended mode *requires* does not exist: `--max-budget-usd` in the M045 driver is only a between-spawn checkpoint (`self-continue-drive.sh:47-57`), not a real ceiling — one `claude -p` segment runs `auto-loop.sh` over many tasks with no in-segment kill; the operator stop-file has one-full-segment latency; a child that crashes before flushing its cost record bypasses the cap entirely; and there is *no enforcement whatsoever* of write/tool scope — an autonomous child retains full Write-anywhere, arbitrary Bash (git push, curl, rm), and every connected MCP server (Gmail, Slack, Vercel, Supabase). Worktrees isolate the filesystem tree only, not the shared git remote, credentials, network, or MCP connections.

**Gap 3 — The self-continue marker contract is not deterministic across the process boundary.** M045's driver reads a continuation decision from a marker keyed to a partial exit-code set; `auto-loop.sh` actually exits `0` for its dominant continuation states (PLANNING / PHASE_COMPLETE / VALIDATING) and `1/12/13` for errors, so the common per-iteration exit writes no marker or a wrong one and the driver falls to a silent `STALLED` — the exact failure M045 claimed to eliminate. An unattended run cannot rest on a marker that mis-keys the common case.

**Gap 4 — Command-injection and fail-open defaults in the driver.** The M045 driver interpolates the milestone path into a shell string run by `sh -c`, and silently defaults `MAX_CONT=20` when the cap is absent — both acceptable under an attended operator, both unacceptable under `--unattended`.

This milestone unifies the entry behind one classify-first `orchestrator:auto`, deprecates and merges `orchestrator:do`, and builds a **serial** unattended safety envelope hard enough that autonomous overnight execution is safe by construction — as pluggable drivers of the *unchanged* `auto-loop.sh` state machine (Principle VI). It explicitly does **not** build the fan-out coordinator (carved to v2c, viability already proven) or the Posture-3 until-verified Stop-hook (own slice): the serial safety envelope is the load-bearing prerequisite that both of those stand on, so it ships first.

## User Scenarios & Testing *(mandatory)*

### Minimal Slice (Phase 1 Load-Bearing Scope)

**US1 + US3** are the load-bearing slice: one unified `orchestrator:auto <arg>` entry that classifies tier and sizes the loop, plus a `--unattended` serial safety envelope whose caps, kill-switch, write/tool-scope enforcement, and BLOCK-on-ambiguity are all real and non-stubbed. Shipping just these two proves the milestone thesis — "one safe autonomous front door." US2 (do-merge) is the migration that makes US1 the *only* front door; US6 (runtime degrade) is the portability guarantee. Neither US2 nor US6 alone proves the thesis, so both are defended on top of the US1+US3 slice.

### User Story 1 — Unified tier-sized entry (Priority: P1)

An operator types `orchestrator:auto <arg>` — a task description, a milestone dir, or nothing — and the command classifies the tier (A/A+/B/C) via the existing M024 classifier and sizes the loop shape automatically: a Tier A task runs one-shot with a Quick knowledge inject; a Tier C milestone enters the resumable `auto-loop.sh` loop. The operator never has to know which sub-command to type or hand-relay between `do` and `auto`.

**Why this priority**: The unified entry is the milestone's headline capability and the surface every other story attaches to. Without it, `--unattended` (US3) and the do-merge (US2) have nothing coherent to hang on.

**Independent Test**: Invoke `orchestrator:auto` with (a) a Tier-A one-shot description, (b) a Tier-C milestone dir, and (c) an ambiguous/empty arg; assert each routes to the correct tier-sized path (one-shot dispatch, loop entry, BLOCK) via the classifier, with no reference to `orchestrator:do`.

**Acceptance Scenarios**:

1. **Given** a clear Tier-A task description, **When** `orchestrator:auto "<task>"` is run, **Then** the M024 classifier scores Tier A and the command runs the one-shot dispatch path (the former `do` behavior) with a Quick knowledge inject, producing the task artifact and one `unit_close` record.
2. **Given** a milestone directory with an active roadmap, **When** `orchestrator:auto <milestone-dir>` is run, **Then** the command enters the `auto-loop.sh` Tier-C loop unchanged (M045 parity).
3. **Given** an argument the classifier scores below the confidence floor, **When** `orchestrator:auto "<ambiguous>"` is run, **Then** the command emits `AUTO:BLOCK_AMBIGUITY` and exits without dispatching (see US3).

### User Story 2 — `orchestrator:do` deprecate-and-merge (Priority: P1)

Everything `orchestrator:do` did is absorbed into `orchestrator:auto`. `do` becomes a thin deprecation shim that forwards to `auto` with a deprecation notice, preserving every existing flag and behavior so scripted callers do not silently break. The shim is removed on a defined runway.

**Why this priority**: Merging is what makes US1 the *single* front door rather than a third command. A partial merge that drops flags or silently changes semantics is worse than no merge.

**Independent Test**: Run the `do` shim with each of its six flags and assert every one is forwarded to `auto` with identical effect; assert a deprecation notice is emitted; assert a `do` invocation and the equivalent `auto` invocation produce byte-identical artifacts.

**Acceptance Scenarios**:

1. **Given** a caller invoking `orchestrator:do --task "<t>" --config <c> --no-prompt-mode`, **When** the shim runs, **Then** all three flags (and the other three: `--yes`, `--dispatch-stub`, `--scratch-root`) are forwarded to `auto` with identical effect and a one-line deprecation notice is printed.
2. **Given** an installed consumer project whose staged `orchestrator-do` skill's backing `do-entry.sh` is removed, **When** the consumer runs `orchestrator:update`, **Then** the shim is re-staged and the consumer sees the deprecation notice rather than a missing-command error.
3. **Given** a pre-existing caller relying on `--yes`, **When** `--yes` now also governs unattended/destructive approvals, **Then** the broadened semantic is surfaced explicitly (distinct behavior/notice per #Q-2), not silently applied.

### User Story 3 — Serial unattended safety envelope (Priority: P1)

An operator adds `--unattended` to launch an overnight run they will not watch. The driver enforces, by construction: a real in-segment budget/wall-clock ceiling that SIGKILLs a running `claude -p` when crossed; reserve-then-spend accounting so a child that dies before flushing cost still decrements the budget; a default-DENY PreToolUse hook constraining both write paths and the tool surface (no network Bash, no git push, no MCP calls beyond an explicit allowlist); BLOCK-on-ambiguity with a second-gate confirmation on the high-confidence path; thrash promoted to a hard terminal; and fail-closed refusal to start if caps are unset. The operator wakes to either a completed milestone, a clean BLOCK with a reason, or a bounded-cost halt — never a runaway, a leaked credential, or an out-of-scope side effect.

**Why this priority**: This is the milestone's reputational load-bearing surface and the prerequisite for all future fan-out. An unattended mode without every one of these enforcements is a liability, not a feature.

**Independent Test**: A non-stubbed harness that (a) launches a runaway segment and asserts it is SIGKILLed mid-flight within a bounded latency; (b) kills a child before it flushes cost and asserts the budget still decrements; (c) has an unattended child attempt an out-of-scope write AND an out-of-scope tool call (git push) and asserts both are blocked by the live hook; (d) feeds a no-progress fixture and asserts a THRASH terminal before the caps; (e) invokes the driver directly with caps missing and asserts refuse-to-start.

**Acceptance Scenarios**:

1. **Given** `--unattended --max-budget-usd 5`, **When** a segment's live cost crosses $5 mid-run, **Then** the driver SIGKILLs the `claude -p` PID within a bounded latency and halts with a distinct budget-exceeded terminal (not on the *next* spawn).
2. **Given** an unattended run, **When** a child is killed before writing its cost record, **Then** the reserved budget for that segment is treated as spent (fail-closed) and the run does not over-spend the cap.
3. **Given** an unattended child, **When** it attempts a write outside the allowed path OR a tool call outside the allowlist (e.g. `git push`, an MCP send), **Then** the PreToolUse hook denies it and the attempt is logged.
4. **Given** an unattended run, **When** the driver writes the stop-file, **Then** a live segment is killed within a bounded latency (not one-full-segment latency).
5. **Given** a child emitting `rotation` with no phase progress, **When** the no-progress window is reached, **Then** the driver halts with `SELF_CONTINUE:THRASH` well before the iteration/budget caps.
6. **Given** `--unattended` with `--max-continuations` or the budget cap unset, **When** the driver starts, **Then** it refuses to start (non-zero exit) — enforced in the driver itself, not only at CLI parse.
7. **Given** an ambiguous input under `--unattended`, **When** the classifier returns a false-high confidence, **Then** a second-gate confirmation (cheap second-model / corpus-gate) runs before any execution and BLOCKs on disagreement.

### User Story 6 — Runtime degrade (Priority: P2)

On a non-CC runtime (Codex CLI / Cursor) where the process-fresh `claude -p` substrate or the PreToolUse hook is unavailable, `orchestrator:auto` degrades gracefully to the M045 attended manual-re-invoke behavior with a clear diagnostic, rather than crashing or — worse — running unattended without the safety hook.

**Why this priority**: Portability guarantee, not thesis-proving; but it must ship in v2b because the *unsafe* degrade (unattended without the enforcement hook) is a security regression, so the degrade path is a safety requirement, not a nicety.

**Independent Test**: Simulate a capability profile lacking `headless_reentry` and lacking the hook-install path; assert `--unattended` refuses to start with a diagnostic, and attended `auto` falls back to M045 manual-re-invoke behavior.

**Acceptance Scenarios**:

1. **Given** a runtime without `headless_reentry`, **When** `orchestrator:auto --unattended` is run, **Then** it refuses (non-zero) with a "unattended requires CC process-fresh substrate" diagnostic.
2. **Given** a runtime where the default-DENY PreToolUse hook cannot be installed, **When** `--unattended` is requested, **Then** it refuses rather than running without write/tool-scope enforcement.

---

## Edge Cases

- **Cost-JSONL lag inside a segment** — the reserve-then-spend ledger reserves a conservative budget to disk *before* each spawn and reconciles against the child's actual cost (`claude -p --output-format json` `total_cost_usd`, proven readable by the P00 spike) on segment end; an unreconciled reserve (child died) is counted as spent, never free.
- **Child produces no exit code (killed/crashed/OOM)** — a deterministic shell wrapper the driver controls (not the LLM's execution path) traps the child exit and writes a terminal `SELF_CONTINUE:CHILD_ABORT` marker; the driver never falls to a silent `unknown`→`STALLED` for a killed child.
- **Marker write torn by a mid-write kill** — because FR-7's budget watchdog and FR-10's stop-file can SIGKILL at any instant, every marker write (by both writers named in FR-14) MUST be atomic: write to a temp file then `rename(2)` into place, so a kill landing mid-write leaves either the old marker or the new one, never a torn/partial marker the next invocation misreads. (Sequenced after FR-14 fixes the writer-of-record: the atomic-write duty attaches to whichever component owns each marker.)
- **`auto-loop.sh` exits 0 for a continuation state** — the marker contract keys the FULL exit-code set (0-substates PLANNING/PHASE_COMPLETE/VALIDATING → continue; 1/12/13 → distinct error terminals), verified non-stubbed against the real `auto-loop.sh`, so the common exit-0 case never mis-reads as a stall.
- **Metacharacter-bearing milestone/unit name** — the driver invokes the child via an argv array (no `sh -c` string interpolation) and validates milestone-dir names against a strict charset allowlist before they reach any command line; a metacharacter-bearing name is rejected, not executed.
- **`--yes` on a now-broader `auto`** — a pre-existing `--yes` caller must not silently gain authority over unattended/destructive approvals (see #Q-2).
- **Tier-A task that outgrows Tier A mid-run** — does not silently self-promote into a locked loop; it BLOCKs back to `orchestrator:evaluate` (Tier A produces zero orchestrator state).
- **Stale lock from a crashed unattended run** — `orchestrator:resume` reconciles the single `.orchestrator/orchestrator.lock` per existing M045 semantics (per-unit worktree locks are a v2c concern, explicitly out of scope here).

---

## Functional Requirements

- **FR-1 (unified-entry)**: `orchestrator:auto <arg>` MUST classify the argument's tier via the existing M024 classifier (`scripts/intake/shape-detect.sh`) and route to the tier-sized path — Tier A/A+/B one-shot dispatch (former `do` behavior), Tier C `auto-loop.sh` loop — with no separate `do` command required. Satisfies US1.
- **FR-2 (classifier-reuse)**: FR-1 MUST reuse the M024 classifier and the existing downstream routers (`route-to-dispatch.sh`, `build-context.sh`) byte-unchanged; unification happens only at the entry/authoring layer. Satisfies US1, CON-2.
- **FR-3 (do-shim-full-forward)**: `orchestrator:do` MUST become a deprecation shim that forwards ALL SIX `do-entry.sh` flags (`--task`, `--yes`, `--config`, `--dispatch-stub`, `--scratch-root`, `--no-prompt-mode`) to `auto` with identical effect, and MUST emit a deprecation notice. Forwarding only a subset is a defect. Satisfies US2.
- **FR-4 (do-migration-surface)**: The deprecation MUST cover installed consumers — the `orchestrator:update` re-stage path re-installs the shim, and a consumer that has NOT updated gets the deprecation notice, not a missing-command error. A defined removal runway will be set at plan-phase (see #Q-3). Satisfies US2.
- **FR-5 (yes-broadening-explicit)**: If `--yes` semantics broaden to cover unattended/destructive approvals, the broadening MUST be surfaced explicitly (distinct alias, longer deprecation window, or explicit notice — resolved at #Q-2), never applied as a silent semantic change. Satisfies US2.
- **FR-6 (unattended-optin)**: Unattended execution MUST require an explicit per-run `--unattended` flag. There MUST be no config default that enables it. Satisfies US3, CON-4.
- **FR-7 (in-segment-budget-ceiling)**: Under `--unattended`, `--max-budget-usd` MUST be a real ceiling enforced *within* a segment: the driver MUST pass a hard budget/wall-clock limit into the child (child self-aborts) AND run a watchdog that SIGKILLs the live `claude -p` PID when a cost/duration probe crosses the ceiling mid-segment. A between-spawn-only checkpoint is insufficient. Satisfies US3.
- **FR-8 (reserve-then-spend)**: The driver MUST reserve a conservative budget to disk before each spawn and reconcile against the child's actual `total_cost_usd` on segment end; an unreconciled reserve (child died before flushing cost) MUST be counted as spent, not free. This applies to the single-worker serial path (not deferred to a fan-out-only ledger). Satisfies US3.
- **FR-9 (bounded-write-and-tool-scope)**: Under `--unattended`, a default-DENY PreToolUse hook MUST constrain BOTH write paths (allowlist) AND the tool surface (deny network Bash, `git push`, `rm` outside scope, and all MCP tool calls unless explicitly allowlisted). The hook MUST be installed via the M028 consumer hook-install path and MUST survive the M021 shape-guard. Worktree filesystem isolation is NOT a substitute (it does not contain git-remote/creds/network/MCP). Satisfies US3, CON-6.
- **FR-10 (stop-file-live-kill)**: The operator stop-file MUST kill a live segment within a bounded latency, not with one-full-segment latency. Satisfies US3.
- **FR-11 (block-on-ambiguity-plus-second-gate)**: `AUTO:BLOCK_AMBIGUITY` MUST fire when the classifier scores below the confidence floor. Additionally, under `--unattended`, a false-HIGH-confidence verdict MUST be caught by a mandatory second-gate confirmation (cheap second-model or corpus-gate) before any execution; the conversus red-team MUST report a measured false-high rate against a fixture corpus with a milestone-blocking precision floor. Satisfies US1, US3.
- **FR-12 (thrash-terminal)**: Under `--unattended`, thrash (phase progress ≪ continuations over a small window) MUST be a first-class terminal (`SELF_CONTINUE:THRASH`) with a low default (e.g. 2 no-progress segments), not observability-only. Satisfies US3.
- **FR-13 (fail-closed-caps-in-driver)**: The driver itself MUST refuse to start (non-zero exit) under `--unattended` if `--max-continuations`, the budget cap, OR the wall-clock ceiling is unset — no silent `MAX_CONT=20` default. The wall-clock ceiling is part of the fail-closed enumeration (its value/mechanism is resolved at #Q-7). Enforcement lives in the driver, not only at CLI parse. Satisfies US3.
- **FR-14 (marker-full-exit-contract)**: The self-continue marker MUST key the COMPLETE `auto-loop.sh` exit-code contract (0-substates PLANNING/PHASE_COMPLETE/VALIDATING → continue; 1/12/13 → distinct error terminals), verified non-stubbed against the real `auto-loop.sh`. **Writer division of labor (reconciles with CON-2)**: because exit code 0 alone cannot disambiguate the three continuation substates, the disambiguating substate marker for a normal child exit is written by `auto-loop.sh` itself — this is the single additive change CON-2 authorizes inside `auto-loop.sh`; the driver's deterministic shell wrapper writes only the terminal marker for the cases `auto-loop.sh` cannot report on its own (a child killed/crashed with no exit line → `SELF_CONTINUE:CHILD_ABORT`). The wrapper MUST NOT be the sole writer, and the driver MUST NOT make any second undocumented change to `auto-loop.sh` beyond this one write. Satisfies US3, closes Gap 3.
- **FR-15 (no-shell-interpolation)**: The driver MUST invoke the child via an argv array (no `sh -c` string interpolation) and MUST validate milestone-dir names against a strict charset allowlist before they reach any command line. Satisfies US3, closes Gap 4.
- **FR-16 (runtime-degrade)**: On a runtime lacking `headless_reentry` or the hook-install path, `--unattended` MUST refuse to start with a diagnostic; attended `auto` MUST fall back to M045 manual-re-invoke. The unsafe degrade (unattended without the hook) MUST be impossible. Coordinates with M009 (classified inspiration-only, see Dependencies). Satisfies US6.
- **FR-17 (legacy-parity)**: The attended Tier-C loop behavior MUST remain byte-compatible with M045 (FR-8 legacy parity); the unattended envelope wraps it without changing attended semantics. Satisfies US1, CON-2.

## Success Criteria

- **SC-1 (unified-routing)**: `orchestrator:auto` with a Tier-A description, a Tier-C dir, and an ambiguous arg routes to one-shot / loop / BLOCK respectively — asserted by a fixture harness, exit 0 on the three expected outcomes. Verifies US1.
- **SC-2 (do-parity)**: A `do`-shim invocation and the equivalent `auto` invocation produce byte-identical artifacts for all six forwarded flags; deprecation notice present. Verifies US2. **Byte-equality asserted** (not substring).
- **SC-3 (in-segment-kill, NON-STUBBED)**: A real runaway segment under `--unattended --max-budget-usd <low>` is SIGKILLed mid-flight within a bounded latency; the run halts with a distinct `budget-exceeded` terminal (distinct from wall-clock / thrash / CHILD_ABORT). **Fixture design**: the harness MUST hold segment *duration* roughly constant while varying dollar *cost*, so an implementation that triggers on a duration proxy relabeled "budget-exceeded" is caught as a false pass/fail mismatch — i.e. the test proves the trigger is honestly cost-derived, not merely that a terminal fired. #Q-4 (cost-read cadence) is a **precondition** for SC-3 sign-off, not a parallel open question. Milestone-blocking, non-stubbed (a seeded-JSONL stub does NOT satisfy this). Verifies US3 / FR-7.
- **SC-4 (fail-closed-accounting)**: A child killed before flushing its cost record still decrements the budget; the run does not exceed the cap. Verifies FR-8.
- **SC-5 (write-and-tool-scope, NON-STUBBED)**: A real unattended child attempting (a) an out-of-scope write, (b) an out-of-scope Bash tool call (`git push`), AND (c) an out-of-scope **MCP tool call** (e.g. a Slack post / Supabase write / Gmail send) is BLOCKED by the live PreToolUse hook. The MCP vector is inside the milestone-blocking gate, not a non-blocking example — it is the primary danger worktree isolation cannot contain (Problem Statement, Gap 2). Milestone-blocking, non-stubbed. Verifies FR-9.
- **SC-6 (stop-file-live-kill)**: The stop-file kills a live segment within a bounded latency (asserted against wall-clock, not next-spawn). Verifies FR-10.
- **SC-7 (thrash-terminal)**: A no-progress fixture halts on `SELF_CONTINUE:THRASH` before the iteration/budget caps. Verifies FR-12.
- **SC-8 (fail-closed-start)**: Invoking the driver directly (bypassing the CLI) with caps missing under `--unattended` yields refuse-to-start (non-zero). Verifies FR-13.
- **SC-9 (marker-full-contract, NON-STUBBED)**: The marker is correct for the COMPLETE `auto-loop.sh` exit set — including the exit-0 continuation substates and 1/12/13 errors — asserted against the real `auto-loop.sh`, not a golden of the happy codes; a killed child yields `CHILD_ABORT`. Milestone-blocking, non-stubbed. Verifies FR-14.
- **SC-10 (no-injection)**: A metacharacter-bearing milestone-dir name is rejected, not executed. Verifies FR-15.
- **SC-11 (classifier-precision-floor)**: The conversus red-team reports a measured false-high classification rate against a fixture corpus that meets a precision floor. **Anti-circularity protocol (#Q-6)**: the floor MUST be committed to disk BEFORE the rate is measured, and the measurement MUST be performed by an independent (non-implementer) pass; commit-order/timestamp is inspectable on disk. The first measured rate is provisional, subject to a second independent conversus review of whether the committed floor is defensible relative to corpus composition (not merely whether the ordering was followed). Below floor is milestone-blocking. Verifies FR-11.
- **SC-12 (safe-degrade)**: On a simulated non-CC profile, `--unattended` refuses with a diagnostic and attended `auto` falls back to M045 behavior; no unattended-without-hook path exists. Verifies US6 / FR-16.

## Non-Goals

- **Fan-out coordinator (carved to v2c-fanout)** — concurrent multi-worker execution, git-worktree per-unit locks, the reserve-then-spend lease *ledger under concurrency*, roadmap-DAG frontier scheduling, and merge-back are explicitly out of scope. Concurrency viability is already proven (P00 spike, N=3); v2c builds the coordinator on this serial safety envelope. Rationale: the serial envelope is the load-bearing prerequisite; shipping it first is the safe build order.
- **Posture-3 until-verified Stop-hook (carved to own slice)** — a unit-grain Stop-hook that loops until verification passes. Rationale: independent capability, demand-driven, not required to prove the unified-safe-entry thesis.
- **Cloud-routine substrate (DEFERRED, not shipped dark)** — the `AUTO_CMD` contract is formalized so a cloud substrate can slot in later with an identical marker contract, but no cloud path ships in v2b. Rationale: Principle VIII — do not ship unexercised paths.
- **`/goal` and `Monitor` as substrates (REJECTED)** — research found them unverified / wrong-shape for this use; the substrate is process-fresh `claude -p`. Rationale: the D015 lesson — do not design on unverified primitives.
- **In-loop tier re-sizing (A→C promotion mid-run)** — a Tier-A task that outgrows Tier A BLOCKs back to `evaluate`; it does not self-promote into a locked loop. Rationale: Tier A produces no orchestrator state.
- **Rewriting `auto-loop.sh` or the on-disk state machine** — substrates only drive it. Rationale: Principle VI.
- **Milestone-grain Stop hooks** — Posture-3 (carved) is unit-grain only; milestone-grain self-continuation is Posture 1's job (M045).

## Constraints

- **CON-1 (process-fresh-only, D015)**: Every re-entry substrate MUST be a genuinely fresh process/context that resumes from disk. In-session `ScheduleWakeup` MUST NOT be reintroduced (it delivers no per-rotation context relief — proven by the M045 P01 spike).
- **CON-2 (auto-loop-unchanged)**: `auto-loop.sh` MUST receive at most ONE additive, idempotent change (a deterministic outcome-marker write keyed to its existing exit codes). FR-11's `AUTO:BLOCK_AMBIGUITY` and any verify changes MUST live at the entry/driver/hook layer, NOT inside `auto-loop.sh`. If any requirement forces a change to `auto-loop.sh` beyond the single marker write, this constraint is amended by an explicit Decision row rather than silently violated.
- **CON-3 (default-off)**: All new behavior (`--unattended` especially) MUST default OFF; existing attended `auto` and `do` behavior is preserved until the shim's defined removal.
- **CON-4 (hard-caps-always-on)**: Under `--unattended`, hard budget + iteration caps + a wall-clock ceiling and BLOCK-on-ambiguity MUST always be on; there is no flag to disable them. (The wall-clock ceiling's value/mechanism is resolved at #Q-7; its *presence* in the always-on set is non-negotiable.)
- **CON-5 (fail-closed)**: Every safety enforcement (caps, hook install, marker, degrade) MUST fail closed — absence of a guarantee halts the run, never proceeds unsafely.
- **CON-6 (primitive-verification)**: No load-bearing design may rest on an assumed primitive behavior until confirmed against official docs AND (for concurrency/cost/hook primitives) shown to survive the M021 shape-guard + M028 consumer hook-install path + an empirical spike. The PreToolUse deny-hook, the cost-read path, and the marker contract each carry a non-stubbed gate (SC-3/5/9). Concurrency itself is already spiked (P00, N=3) and belongs to v2c.

### Knowledge-Layer Boundary (M046 vs. M019/M024)

M046 owns NO knowledge-tree schema. It **reads** the M019 Tier-1 cost JSONL (and the `claude -p --output-format json` `total_cost_usd`) for budget accounting, and **reads** the M024 classifier output for tier routing; it writes only execution-log `unit_close` / driver-log records and the self-continue marker file. All knowledge/graph write-sites remain owned by their existing milestones. A precondition (see Assumptions) verifies M019 cost write cadence supports pre-spawn lease reads.

## Assumptions

- The M045 process-fresh driver trio (`self-continue-drive.sh`, `self-continue-branch.sh`, `self-continue-status.sh`) is on `main` and is the substrate base (verified: PR #15 merged 2026-07-02).
- Concurrent `claude -p` under one OAuth is viable at N=3 (P00 spike PASS) — relevant only to the carved v2c, recorded here so v2c inherits the evidence.
- `claude -p --output-format json` returns a parent-readable `total_cost_usd` per segment (P00 spike PASS) — the cost source FR-7/FR-8 depend on.
- The M028 consumer hook-install path can install a PreToolUse deny-hook that survives the M021 shape-guard — to be confirmed by CON-6 during planning (SC-5 is the non-stubbed proof).
- M019 Tier-1 JSONL cost write cadence supports pre-spawn budget-lease reads — a plan-phase precondition (mirror the CON-6 discipline for the cost source).

## Constitution Check

- **Principle II (Evidence Before Claims)**: SC-3/SC-5/SC-9 are non-stubbed, milestone-blocking viability gates for the money-cap, the write/tool-scope hook, and the marker contract — the exact "prove it live" discipline the M045 P01 spike taught. The P00 spike already discharged the concurrency/cost claims.
- **Principle III (Design Before Code)**: This spec is the design gate; the red-team conditions are folded into FRs/CONs/SCs before any code.
- **Principle VI (State On Disk Is Truth)**: `auto-loop.sh` and the on-disk state machine are unchanged (CON-2); the driver resumes from disk; the marker/ledger are disk-authoritative.
- **Principle V (Fresh Context Per Unit)**: the process-fresh driver (D015) gives each rotation a genuinely fresh context; CON-1 forbids the in-session substrate that would violate this.
- **Principle I (Context Minimization)**: the ~$0.245 cold-start floor per process-fresh worker (P00 finding) is an explicit budget input; lean-worker options are a planning consideration.

## Open Questions (defer to planning)

- **#Q-1 (hook-install-portability)**: Can the default-DENY PreToolUse hook (FR-9) be installed via the M028 path on every supported CC install shape (npm / homebrew / curl / symlink) and survive the shape-guard? Answered by the planner + SC-5 non-stubbed proof at plan-phase. *(Corpus-gate note: not answerable from the existing corpus — genuinely new hook surface.)*
- **#Q-2 (yes-broadening-resolution)**: Does `--yes` broadening warrant a distinct flag alias / longer deprecation window vs an explicit notice? Operator decides at plan-phase; flagged as a conversus red-team target.
- **#Q-3 (do-removal-runway)**: How long is the `orchestrator:do` deprecation runway before shim removal, and what release gates it? Operator + roadmap decide at plan-phase.
- **#Q-4 (m019-cost-cadence)**: Does M019 Tier-1 JSONL emit at per-segment granularity in time for pre-spawn lease reads, or is `--output-format json` `total_cost_usd` the sole cost source? Verified at plan-phase precondition.
- **#Q-5 (second-gate-substrate)**: Is the FR-11 second gate a cheap second-model call, the M042 corpus-gate, or both? Decided at plan-phase with a cost/precision trade-off.
- **#Q-6 (precision-floor-protocol)**: The SC-11 anti-circularity protocol requires committing the precision floor to disk before measuring the false-high rate and using an independent (non-implementer) measurer. Open at plan-phase: who is the independent measurer, what corpus composition is defensible, and does the numeric floor itself need to be hard-coded in the spec rather than deferred under the protocol? The first measured rate is provisional pending a second independent conversus review (arbiter ruling, gate-result RISK-3).
- **#Q-7 (wall-clock-default)**: Is the wall-clock ceiling (FR-7/FR-13/CON-4) a fixed internal non-configurable constant (and if so, what value?) or a future operator-facing flag? It is always-on either way; only its value/mechanism is open. Resolved at plan-phase (gate-result RISK-6).

## Dependencies

- **M045 (hard)** — process-fresh driver substrate; this spec extends it. On `main`.
- **M024 (hard)** — the classifier FR-1/FR-11 route through. Shipped.
- **M019 (hard-read)** — Tier-1 cost JSONL read for budget accounting; cadence verified as a plan-phase precondition (#Q-4).
- **M028 (hard)** — consumer hook-install path for the FR-9 PreToolUse deny-hook. Shipped.
- **M021 (hard)** — shape-guard the FR-9 hook must survive. Shipped.
- **M009 (inspiration-only)** — runtime-degrade (FR-16) *coordinates with* M009 but does NOT depend on it building first; the degrade shape is self-contained here so a later M009 build cannot force rework.
- **M034 / M040 (inspiration-only)** — the FR-11 second-gate/decision shape echoes M034's headless review-gate concept and composes with M040, but neither is a build dependency; shapes are self-contained.

## Downstream Consumers (informational, not binding)

- **v2c-fanout (future)** — the fan-out coordinator builds directly on this serial safety envelope (caps, hook, marker, ledger); the P00 concurrency evidence is banked for it.
- **Posture-3 until-verified slice (future)** — a unit-grain Stop-hook loop that reuses the unified entry and safety envelope.
- **orchestrator:resume** — reconciles a stale lock from a crashed unattended run (existing single-lock semantics; per-unit locks are v2c).
