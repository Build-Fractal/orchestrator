---
schema_version: "1.0"
type: feature-spec
feature_slug: "0XX-auto-v2b-unified-autonomous"
created_at: "2026-07-02"
status: "Ready-for-discuss"
milestone: "M-auto-v2b (provisional Mxx — assign at queue-entry)"
---

# Feature Specification: auto-v2b — Unified Tier-Sized Autonomous Execution (Postures 1/2/3 + do-merge + fan-out)

**Feature Branch**: `0XX-auto-v2b-unified-autonomous`
**Created**: 2026-07-02
**Status**: Ready-for-discuss
**Predecessor**: M045 / `M-auto-v2a` (Posture 1, shipped 2026-07-02, PR#15) — this spec consumes M045's process-fresh driver trio as its substrate base.
**Proposal**: `.orchestrator/proposals/Mxx-auto-v2-claude-code-loop-integration.md` (Discussion Outcomes D1–D4, 2026-06-30)
**Input**: Operator description: "Turn `orchestrator:auto` into ONE unified, tier-sized autonomous entry point — unified A/B/C entry + tier-sizing + `do`-merge + Posture 2 (unattended/overnight) + Posture 3 (until-verified) + runtime degrade. Maximize agent fan-out / parallelism; tokens are not a constraint; make it as ideal as possible."

---

## Provenance Banner — Substrate Already Pivoted (read first)

This spec inherits **decision D015** (`.orchestrator/DECISIONS.md`): the re-entry substrate is **process-fresh `claude -p`**, not in-session `ScheduleWakeup`. The M045 P01 viability spike proved in-session re-entry does **not** deliver per-rotation context relief (the weight analog compounded 4→11→18). The v2b proposal predates that spike and still frames Posture 1 via `ScheduleWakeup` (proposal §Posture 1, primitive table "High confidence"). **That framing is stale — this spec MUST NOT reintroduce it.** Every substrate here is a pluggable driver of the *unchanged* `auto-loop.sh` state machine (Principle VI); "re-entry" always means a genuinely fresh process/context that resumes from disk.

Two further burned-once cautions carried forward from D015: no load-bearing design may rest on an assumed primitive behavior until it is confirmed against **official docs** and shown to survive the **M021 shape-guard** + **M028 consumer hook-install path**. This applies to Stop hooks (Posture 3) and to any background/worktree primitive used for fan-out. See #Q-5 and the viability gates SC-9/SC-10/SC-11.

---

## Problem Statement

`M-auto-v2a` (M045) closed the single sharpest gap in autonomous execution — the loop can now cross its own context-rotation boundary unattended-but-attended via a process-fresh driver. But it deliberately shipped as a **tight slice of one posture on one tier**, leaving the full "one truly autonomous, tier-sized front door" vision unbuilt. Four concrete, evidence-grounded gaps remain.

**Gap 1 — Two front doors, one of them a dead-end stub.** `orchestrator:do` (Tier A one-shot) and `orchestrator:auto` (Tier C loop) are separate commands over the *same* M024 classifier (`scripts/intake/shape-detect.sh`) and the *same* downstream routers (`route-to-dispatch.sh`, `build-context.sh`). `do`'s Tier B/C branch (`do-entry.sh:249-261`) is a print-and-exit stub that just tells the operator to run another command "in their next turn" — it never enters the loop. An operator must know which command to type and must hand-relay between them. The proposal's D3 resolves this: deprecate `do`, merge into a unified `auto`.

**Gap 2 — Autonomy stops when the operator leaves.** M045 is attended by construction (Non-Goal: "an operator launches it and can interrupt it"). There is no unattended/overnight execution, no hard budget/iteration enforcement in the driver itself (budget lives inside the child `auto-loop.sh` and is only observed post-hoc via the outcome marker), and no BLOCK-on-ambiguity — the merged `do` low-confidence path is a blocking `read -t 60` that defaults to *cancel*, which is meaningless with no human turn.

**Gap 3 — The driver is strictly serial; there is no fan-out.** `self-continue-drive.sh` runs exactly one `claude -p` at a time and blocks on it (`drive.sh:57`, output discarded). The roadmap template *already* encodes a fan-out DAG (`Depends:` edges + `## Dependency Graph` + `## Execution Order` sections marking parallel-eligible units) but nothing consumes it. The operator's explicit intent — maximize parallelism, tokens not a constraint — has no seam to land on.

**Gap 4 — Task verification is single-pass-with-one-retry.** At the task-verify seam (`auto-loop.sh --step=V` → `AUTO:VERIFY_PASS/FAIL`), a failing unit retries exactly once then exits (`auto.md:327-338`). There is no tight verify→fix→re-verify micro-loop that keeps a *unit* going until it actually passes.

This milestone closes all four by (a) unifying the entry behind one classify-first `orchestrator:auto`, (b) generalizing M045's process-fresh driver into a posture-parameterized outer loop with an always-on unattended safety envelope, (c) building a net-new roadmap-DAG-driven fan-out coordinator over worktree-isolated workers, and (d) adding a unit-grain until-verified Stop-hook micro-loop — all as pluggable drivers of the unchanged `auto-loop.sh`.

This is a **breaking-change, power-user-band** milestone (same band as M034/M038/M040). It is CC-first and deepens CC-exclusivity; the M009 degrade story keeps every non-CC path byte-stable at the M045 fallback.

---

## Goals

- **G1** — One front door: `orchestrator:auto <arg>` classifies tier (A/B/C) and sizes the loop shape automatically, subsuming `orchestrator:do`.
- **G2** — Three postures behind explicit flags: Posture 1 (attended self-continue, from M045), Posture 2 (unattended/overnight), Posture 3 (until-verified unit-grain micro-loop).
- **G3** — Unattended execution that is *safe by construction*: double-gate opt-in, driver-enforced hard caps, BLOCK-on-ambiguity, bounded write scope, conversus-red-teamed.
- **G4** — Maximal, dependency-correct fan-out: concurrent worker dispatch across independent roadmap units (milestones *and* phases) via mandatory git-worktree isolation, driven by the roadmap dependency graph.
- **G5** — Graceful runtime degrade: every CC-only substrate falls back to today's manual re-invoke on Codex CLI / Cursor with no crash and no silent unsafe path (M009 tie).
- **G6** — Reuse-hardest discipline: `auto-loop.sh` gets exactly ONE additive, idempotent change (deterministic outcome-marker write keyed to its existing exit codes); the classifier and downstream routers stay byte-unchanged.

## Non-Goals

- **Rewriting `auto-loop.sh` or the on-disk state machine.** It stays the crown jewel; substrates only drive it. The single exception is G6's additive marker write.
- **In-loop tier re-sizing (A→C promotion mid-run).** Tier A produces zero orchestrator state (`evaluate.md:221`); a task that outgrows Tier A BLOCKs back to `evaluate`, it does not silently self-promote into a locked loop.
- **Shipping the cloud-routine substrate live.** Per D2 + Principle VIII this spec makes the affirmative call to **DEFER** cloud (see Posture 2 §Substrate). `AUTO_CMD` is formalized so cloud slots in later with an identical marker contract and no redesign — but it does not ship dark.
- **Designing on unverified primitives.** `/goal` and `Monitor` are **REJECTED** (not deferred — see Open Questions). Background-Task / `EnterWorktree`-class primitives are **optional accelerants only after official-doc confirmation**; the shipped fan-out default is N parallel `claude -p` processes over git worktrees.
- **Changing dispatch/verify/budget/stuck internals**, the M024 classifier, or `route-to-dispatch.sh` / `build-context.sh` behavior. Unification happens only at the routing/authoring layer.
- **Milestone-grain Stop hooks.** Posture 3 is unit-grain only; milestone-grain self-continuation is Posture 1's job (an in-session Stop hook gives no context relief — the D015 lesson).

---

## User Scenarios & Testing *(mandatory)*

### Minimal Slice (load-bearing scope)

The load-bearing slice is **US1 + US3**: one unified `orchestrator:auto` front door that classifies and routes correctly (US1), plus a safe unattended Posture-2 run that self-continues across rotation, halts on hard caps, and BLOCKs on ambiguity (US3). US2 (do-merge migration), US4 (fan-out), US5 (Posture 3), and US6 (runtime degrade) layer capability and portability on top of that slice but do not by themselves prove the milestone's thesis.

### User Story 1 — One classify-first front door (Priority: P1)

An operator types `orchestrator:auto "fix the flaky timeout in the retry helper"` (free text) and, separately, `orchestrator:auto milestone=M052`. The first is classified (Tier A) and runs the existing lock-free `do` fast-path; the second skips classification and enters today's Tier C loop. The operator never has to know which of two commands to use, and small tasks never touch milestone machinery (no lock, no preflight chatter, no state scaffold).

**Why this priority**: It is the "one front door" thesis; everything else sizes or hardens what this routes.

**Independent Test**: A table-driven fixture feeds `orchestrator:auto` a corpus of inputs (idea / short paragraph / tier_a_plus / fragment / spec-file / `milestone=M###` / milestone-dir) and asserts each lands on the correct branch (Tier A fast-path / A+ handoff / B advisory / C loop / target skip-classify) with byte-stable Quick-intensity preflight suppression on the Tier A path. Exits 0.

**Acceptance Scenarios**:
1. **Given** `orchestrator:auto "<free text idea ≤10 words>"`, **When** it runs, **Then** `shape-detect.sh` classifies `idea/high`, the Tier A degenerate fast-path runs via `build-context.sh --profile=quick`, emits the FR-12 `doing: <task> — knowledge: N MEMs / X tokens` line, acquires NO lock, and prints no `AUTO:READY` preflight block.
2. **Given** `orchestrator:auto milestone=M052` where M052 is a Tier C milestone in an auto-eligible state, **When** it runs, **Then** classification is skipped, the lock is acquired, and the run enters `auto-loop.sh` exactly as today's `auto`.
3. **Given** a bare free-text string classified below `entry_routing_confidence_floor` while **attended**, **When** it runs, **Then** the interactive Tier A vs Tier B prompt appears (do's current behavior, `read -t 60`), unchanged.

### User Story 2 — `orchestrator:do` deprecation & migration (Priority: P2)

A downstream operator who scripted `orchestrator:do --task ... --yes` runs it after upgrading and gets a deprecation notice, correct forwarding to `auto` for one release, and a changelog entry. After the next release the command is gone and every verifier still passes (no dropped-`do.md` breakage).

**Why this priority**: D3 is a breaking change with a wide surface; it must not silently break consumers or trip the section/config-drift verifiers.

**Independent Test**: A migration fixture asserts (a) `orchestrator:do` emits a deprecation notice and forwards to `auto`, (b) after removal the doctor/config-drift section checks (`m002-p07-doctor-md-sections.sh`, `check-config-drift.sh`) exit 0, (c) the `--yes` semantics change is documented in migration notes and the `orchestrator:update` changelog. Exits 0.

**Acceptance Scenarios**:
1. **Given** the deprecation-shim release, **When** `orchestrator:do --task "x"` runs, **Then** it prints a deprecation notice naming `orchestrator:auto` and forwards `--task` to auto, preserving the current output.
2. **Given** the removal release, **When** the doctor + config-drift verifiers run, **Then** they exit 0 with `do.md` absent (migration notes swept the full surface).
3. **Given** a caller that passed `--yes` to `do` for the Tier-A+ prompt-skip only, **When** they pass `--yes` to merged `auto`, **Then** it means the broader "non-interactive, skip ALL approval prompts" (documented behavior change).

### User Story 3 — Safe unattended overnight run (Priority: P1)

An operator kicks `orchestrator:auto milestone=M052 --self-continue --unattended --max-budget-usd 8.00 --max-iters 30` and goes to sleep. The run self-continues across rotation boundaries in fresh processes, enforces the budget and iteration caps *in the driver before each spawn*, BLOCKs (never guesses) on any ambiguous/underspecified unit, and captures a per-segment transcript. In the morning the operator finds either a completed milestone or a clean, quarantined halt with an unmissable blocker digest — never a runaway spend, never a silent stall.

**Why this priority**: Posture 2 is the highest-stakes new capability; its safety envelope is the milestone's reputational load-bearing surface.

**Independent Test**: A harness drives a fixture milestone unattended and asserts: (a) each terminal outcome halts without a further spawn; (b) exceeding `--max-budget-usd` (read from the M019 Tier-1 JSONL cost rollup) halts *before* the next spawn with `SELF_CONTINUE:BUDGET_CAP`; (c) exceeding `--max-iters` halts with `SELF_CONTINUE:CAP_REACHED`; (d) a low-confidence unit halts with the distinct `AUTO:BLOCK_AMBIGUITY` terminal (never the 60s-timeout-to-cancel); (e) a child crash before marker-write is caught by the deterministic marker (auto-loop.sh sole writer), not a silent STALLED-exit. Exits 0.

**Acceptance Scenarios**:
1. **Given** `--self-continue` present but `--unattended` absent, **When** rotation trips, **Then** attended Posture-1 behavior (M045) applies; unattended caps/BLOCK are NOT engaged.
2. **Given** `--unattended` with no `--max-budget-usd` or no `--max-iters`, **When** the run starts, **Then** it REFUSES to start (fail-closed) with a diagnostic naming the missing mandatory cap — no default silently supplies it.
3. **Given** an armed unattended run whose accumulated cost (per M019 JSONL) would exceed `--max-budget-usd` on the next segment, **When** the driver evaluates the pre-spawn budget lease, **Then** it does not spawn and halts with `SELF_CONTINUE:BUDGET_CAP` carrying the reconciled spend figure.
4. **Given** a unit the classifier scores below the confidence floor during an unattended run, **When** the driver reaches it, **Then** it emits `AUTO:BLOCK_AMBIGUITY`, quarantines the unit, and (in fan-out) does not stall independent siblings.

### User Story 4 — Dependency-correct fan-out (Priority: P2)

An operator runs an unattended milestone whose roadmap marks several phases parallel-eligible. The coordinator reads the dependency graph, computes the eligible frontier, and dispatches one process-fresh worker per independent unit — each in its own git worktree with its own lock — keeping the frontier saturated as workers finish (rolling wavefront). Completed worktrees are verified and merged back **serially, gated, never auto-merged under `--unattended`**. A failed/BLOCKed unit parks its worktree without taking down the pool.

**Why this priority**: This is where the operator's maximize-fan-out intent lands, but it is strictly additive over US3's per-worker safety, so it follows US3.

**Independent Test**: A fixture roadmap with a known DAG (two independent phases + one dependent phase) drives the coordinator and asserts: the two independents run concurrently in separate `.worktrees/<unit>` dirs each holding its own lock; the dependent starts only after both prerequisites report `complete`; a forced BLOCK on one independent parks its worktree without halting the other; the aggregate `--max-budget-usd` lease ledger (on disk) is never exceeded across concurrent workers; merge-back is serial with conflict detection. Exits 0.

**Acceptance Scenarios**:
1. **Given** a roadmap whose `## Dependency Graph`/`## Execution Order` marks P02 and P03 independent and P04 dependent on both, **When** the coordinator runs, **Then** P02 and P03 dispatch concurrently and P04 dispatches only after both markers report `complete`.
2. **Given** two concurrent workers, **When** each requests a budget lease before spawning, **Then** the on-disk lease ledger reserves-then-spends atomically so the sum never overshoots the aggregate `--max-budget-usd`.
3. **Given** a worker that hits `AUTO:BLOCK_AMBIGUITY` or its per-unit cap, **When** it halts, **Then** its worktree is quarantined (not merged) and the coordinator keeps fanning the rest of the DAG, surfacing the blocker in a wave-close digest.
4. **Given** completed worker worktrees under `--unattended`, **When** the wave closes, **Then** merge-back runs `orchestrator:verify` per unit and is presented as an explicit gated/reviewable step — never auto-merged.

### User Story 5 — Until-verified unit-grain micro-loop (Priority: P3)

For a Tier A task or a Tier C unit, the operator opts into `--until-verified`. A Stop hook returns `decision:"block"` while the unit's verification is failing, forcing verify→fix→re-verify before the unit can complete — replacing today's single-pass-with-one-retry — bounded by `stop_hook_active` and the existing stuck-detector retry threshold.

**Why this priority**: Highest-value on small tasks but the greenfield Stop-hook substrate carries the most primitive-verification risk; it is bounded to unit grain and lands last.

**Independent Test**: A fixture unit whose verification fails N times then passes drives the Stop-hook micro-loop and asserts it re-enters verify→fix until pass or the stuck threshold, never at milestone grain, with `stop_hook_active` preventing infinite recursion. A capability fixture with `stop_hook=false` asserts fallback to today's single-pass-with-one-retry. Exits 0.

**Acceptance Scenarios**:
1. **Given** `--until-verified` on a unit whose verify fails once then passes, **When** the Stop hook fires, **Then** it returns `decision:"block"` on the failure, the unit re-runs verify→fix, and completes on the pass.
2. **Given** a unit that never passes, **When** retries reach the stuck-detector threshold, **Then** the hook stops blocking and the unit halts as stuck (exit 3 semantics), not an infinite loop.
3. **Given** a runtime reporting `stop_hook=false`, **When** `--until-verified` is requested, **Then** the loop falls back to single-pass-with-one-retry and records the degrade.

### User Story 6 — Byte-stable runtime degrade (Priority: P3)

On Codex CLI / Cursor (no `claude` on PATH, no Stop hooks, no worktree substrate available), every v2b enhancement degrades to today's behavior: unattended and self-continue fall back to the manual re-invoke handoff, Posture 3 falls back to single-pass verify, fan-out falls back to a single serial driver — no crash, only reduced autonomy.

**Independent Test**: Capability-detection fixtures setting `headless_reentry=false`, `stop_hook=false`, `worktree_capable=false` each assert the corresponding byte-stable legacy fallback and a recorded degrade reason. Exits 0.

---

## Edge Cases

- **Child crash before the outcome marker is written** — deterministic marker (auto-loop.sh sole writer, keyed to its own exit codes) eliminates the M045 silent `unknown` → STALLED-exit path; the LLM-authored marker survives only as an attended fallback.
- **Two concurrent workers touch overlapping files** — should be impossible if roadmap boundary maps assign disjoint ownership; a plan-time disjoint-ownership verifier is the conversus red-team's primary target, and merge-back conflict detection parks the offending unit as `blocked` rather than corrupting the integration branch.
- **Shared `.orchestrator/` writes under fan-out** (`KNOWLEDGE.md`, observability JSONL, index rebuild) — the coordinator, not the workers, owns all shared-tree writes; workers write only within their worktree; the coordinator serializes merges (compounded caution: the known parallel-agent shared-tree branch-collision hazard — re-assert branch before each shared write).
- **Cost JSONL lag inside a segment** — the pre-spawn budget lease reads the M019 rollup conservatively (reserve high, reconcile on marker), so a lagging cost figure under-spends rather than overshoots the D4 hard cap.
- **`--unattended` with a Tier B/C free-text classification** — do's "run specify in your next turn" hand-back has no operator turn; under `--unattended` it collapses to `AUTO:BLOCK_AMBIGUITY`, never a silent no-op.
- **Rotation co-incident with a terminal state** — terminal wins; no further spawn (inherited from M045 US1 AS-2).
- **Orphaned per-unit worktree after a crash** — `orchestrator:resume` must recognize and reconcile `.worktrees/<unit>` directories with stale per-unit locks (see #Q-7).
- **`--max-parallel` unset** — defaults to a generous machine-bounded limit (not token-bounded, per operator intent), never unbounded.

---

## Functional Requirements

### Unified entry & tier-sizing
- **FR-1 (single front door)**: `orchestrator:auto <arg>` MUST be the sole entry. A `milestone=M###` prefix or an existing milestone-dir path MUST be treated as a Tier C target (skip classification, today's behavior); any other bare string MUST be classified via `shape-detect.sh` (unchanged). (US1)
- **FR-2 (classify-first routing)**: The unified entry MUST route on the M024 verdict, first-match: Tier A idea/paragraph-high → lock-free `build-context.sh --profile=quick` fast-path; Tier A+ → `route-to-dispatch.sh` handoff; Tier B → `orchestrator:dispatch`/specify advisory; Tier C → acquire lock + enter `auto-loop.sh` (the ONLY branch that crosses stateless→stateful). The Tier B/C print-and-exit stub (`do-entry.sh:249-261`) MUST become this real branch. (US1)
- **FR-3 (preserve do behaviors)**: The merged entry MUST preserve the FR-12 `doing:` fast-path line, the `entry_routing_confidence_floor` knob + high/low→1.0/0.5 mapping (4-layer precedence), the Tier-B/C specify|evaluate advisory, and Quick-intensity preflight suppression (SC-9 byte-stable). (US1)
- **FR-4 (tier/intensity orthogonal)**: TIER (A/B/C, evaluate-time, `M###-EVALUATION.md`) MUST pick the substrate; INTENSITY (Quick/Standard/Full, invocation-time via `intensity-recommend.sh`, per-iteration via `intensity-gate.sh`) MUST pick the rigor; the two MUST NOT be collapsed, and per-tier default intensity MUST be operator-overridable. (US1)
- **FR-5 (no in-loop tier upgrade)**: A Tier A task that proves under-scoped MUST BLOCK back to `evaluate`; it MUST NOT silently escalate into a locked loop. (US1)

### do-merge
- **FR-6 (deprecate + shim)**: `orchestrator:do` MUST emit a deprecation notice and forward to `orchestrator:auto` for exactly one release, then be removed. (US2)
- **FR-7 (migration sweep)**: Removal MUST update the full surface so no verifier trips on a dropped `do.md`: `packaging/skills/orchestrator-do.md` + `packaging/bundle/manifest.yml` + `build-bundle.sh`, `commands/do.md`, `docs/{getting-started,recipe-authoring,why-this-exists}.md`, `references/{model-routing,installation}.md`, and `scripts/verify/m002-p07-doctor-md-sections.sh` + `scripts/diagnostics/check-config-drift.sh`. The breaking change MUST surface in the `orchestrator:update` changelog. (US2)
- **FR-8 (`--yes` reconciliation)**: `--yes` MUST adopt auto's broader meaning (non-interactive, skip ALL approval prompts), subsuming do's Tier-A+-prompt-skip; the change MUST be called out in migration notes. (US2)

### Posture 2 — unattended envelope
- **FR-9 (double-gate opt-in)**: Unattended execution MUST require BOTH `--self-continue` (default OFF, from M045 CON-4) AND a second explicit per-run `--unattended` flag. An invariant test MUST assert NO config knob can make either the silent default. (US3, CON-D4)
- **FR-10 (driver-enforced hard caps, fail-closed)**: `--max-budget-usd` and `--max-iters` MUST both be present on every `--unattended` invocation or the run MUST REFUSE to start. Both MUST be enforced by the outer driver *before/around each spawn* — `--max-iters` from the driver's own counter, `--max-budget-usd` from the M019 Tier-1 JSONL cost rollup (file-derived, never delegated to the child's post-hoc marker). (US3, CON-D4)
- **FR-11 (BLOCK-on-ambiguity terminal)**: A distinct terminal outcome `AUTO:BLOCK_AMBIGUITY` MUST be added to the marker vocabulary and the branch decision core, separable from generic `blocked`, always honored under `--unattended`. The do low-confidence prompt and the Tier-B/C hand-back both MUST collapse to it (never the 60s-timeout-to-cancel). (US3, CON-D4)
- **FR-12 (deterministic marker — sole writer)**: `auto-loop.sh` MUST write the `.self-continue-outcome` marker on its own exit codes (2=budget, 3=stuck, 10=complete, 11=pause, 14=rotation), idempotently and keyed strictly to those existing codes so FR-8 legacy rotation-exit parity is preserved. This is the single additive change to `auto-loop.sh`; it becomes the SOLE writer, eliminating the double-source-of-truth and the M045 silent-`unknown` halt. (US3, CON-G6)
- **FR-13 (bounded write scope)**: An unattended run MUST declare and enforce a bounded write scope (path allowlist); writes outside it MUST BLOCK. (US3, CON-D4)
- **FR-14 (per-segment observability)**: The driver MUST capture per-segment child stdout/stderr to `.orchestrator/<M###>/self-continue-logs/` (M045 discards it) and `self-continue-status.sh` MUST report thrash (`progress≪continuations`) and budget-burn, not just STALLED. (US3)
- **FR-15 (pluggable substrate contract)**: `AUTO_CMD` MUST be the formalized pluggable-substrate seam; the primary substrate is headless `claude -p`; any alternative (cloud) MUST honor an identical outcome-marker contract. (US3, CON-D2)

### Posture 2 — fan-out
- **FR-16 (fan-out coordinator)**: A net-new coordinator (`auto-fanout.sh`-shaped) MUST sit ABOVE the M045 driver; the driver becomes the per-worker primitive. Fan-out MUST be gated to `--unattended` only. (US4)
- **FR-17 (DAG-driven frontier)**: The coordinator MUST compute the eligible frontier from the roadmap's existing `Depends:` edges + `## Dependency Graph` + `## Execution Order` sections and on-disk unit state; independent units MUST fan out concurrently, dependent units MUST serialize behind satisfied prerequisites (rolling wavefront). (US4)
- **FR-18 (worktree isolation)**: Each concurrent worker MUST run in its own git worktree (`.worktrees/<unit>`, existing `git_isolation` seam) with its own lock, resolving the single-lock-per-`.orchestrator` invariant. Worktree isolation is MANDATORY for concurrency. (US4)
- **FR-19 (aggregate budget lease ledger — file-derived)**: A single on-disk reserve-then-spend lease ledger MUST enforce the aggregate `--max-budget-usd` across all live workers: reserve before spawn, reconcile on marker. Per-worker sub-caps MUST be hard kill thresholds, not advisory. The ledger MUST be file-derived (Principle VI), not an in-memory pool. (US4)
- **FR-20 (coordinator owns shared writes)**: Workers MUST write only within their worktree; ALL shared `.orchestrator/` writes (KNOWLEDGE.md, observability JSONL, index rebuild, roadmap sync) MUST be serialized by the coordinator. (US4)
- **FR-21 (gated merge-back)**: Completed worktrees MUST merge back serially with conflict detection; each merge MUST run `orchestrator:verify` (and optionally a conversus gate). Under `--unattended`, merge-back MUST be an explicit gated/reviewable step — never auto-merged. A merge conflict MUST park the unit as `blocked`. (US4)
- **FR-22 (per-worker quarantine)**: A failed/BLOCKed worker MUST quarantine its own worktree without halting independent siblings; all blockers MUST surface in an unmissable wave-close digest. (US4)

### Posture 3 — until-verified
- **FR-23 (unit-grain Stop hook)**: `--until-verified` MUST install a CC Stop hook returning `decision:"block"` while a UNIT's verification fails, forcing verify→fix→re-verify at the task-verify seam (`auto-loop.sh --step=V` / Stage 3 `--step=G`), replacing the hardcoded one-retry (`auto.md:327-338`). It MUST reuse the `AUTO:VERIFY_PASS/FAIL` signal and the deterministic decision-core SHAPE. (US5)
- **FR-24 (unit-grain enforcement + guards)**: The Stop hook MUST be structurally constrained to unit grain (never milestone), guard against infinite recursion via `stop_hook_active`, and cap retries at the existing stuck-detector threshold. (US5)

### Runtime degrade
- **FR-25 (capability gate extension)**: `detect-capabilities.sh` MUST expose per-substrate flags: `headless_reentry` (exists), `stop_hook`, `worktree_capable`, and a future `cloud_reentry`. The `self-continue-branch.sh` decision core MUST stay substrate-agnostic and consume these + posture + caps. (US6)
- **FR-26 (byte-stable fallbacks)**: Each absent capability MUST degrade to a byte-stable legacy path: `headless_reentry=false` → `AUTO:ROTATE_EXIT reason=headless-unavailable` (manual re-invoke); `stop_hook=false` → single-pass-with-one-retry verify; `worktree_capable=false` → serial single-driver execution. Under `--unattended`, a missing `headless_reentry` MUST REFUSE to start (fail-closed), not degrade to an unsafe path. (US6, US3)

### Governance
- **FR-27 (transcribe decisions)**: D1–D4 MUST be transcribed into `.orchestrator/DECISIONS.md` at specify (they live only in the proposal today; only D015 is durably recorded). (Principle VII)

---

## Constraints

### Locked discussion decisions (D1–D4 verbatim, proposal §Discussion Outcomes, 2026-06-30)

- **CON-D1 (Sequencing)** — verbatim: *"Sequencing: split into two milestones. Ship `M-auto-v2a` (Posture 1 only) first as a standalone, tight slice; `M-auto-v2b` follows once v2a is proven in dogfood."* — `M-auto-v2b` = *"the unified A/B/C entry + tier-sizing + `do` deprecation/merge (D3) + Posture 2 unattended (D2, D4) + Posture 3 unit-grain until-verified + runtime-degradation (M009 tie)."* This spec IS `M-auto-v2b`.
- **CON-D2 (Unattended substrate)** — verbatim: *"Unattended substrate: both, settle at spec. Headless `claude -p` driver as primary; cloud routine (`/schedule`) as a gated stretch substrate. The v2b spec's goal-backward pass picks whether cloud ships in v2b or defers."* — **Affirmative resolution in this spec: headless `claude -p` ships as sole primary; cloud DEFERS per Principle VIII (no live consumer at ship), with `AUTO_CMD` formalized as the drop-in seam.**
- **CON-D3 (`orchestrator:do`)** — verbatim: *"`orchestrator:do`: deprecate and merge into unified `auto` (Tier A path). Deprecation notice on `do`, removed after one version. Breaking change for downstream — v2b must ship migration notes + `orchestrator:update` changelog surface. (Lands in v2b, not v2a.)"*
- **CON-D4 (Unattended safety)** — verbatim: *"Unattended safety: explicit per-run opt-in only. `--unattended` required on every invocation; no config knob can make it the silent default. Hard `--max-budget-usd` cap + `--max-iters` cap + BLOCK-on-ambiguity always on. Warrants a conversus red-team pass during v2b `specify`."*

### Substrate & architecture invariants

- **CON-1 (process-fresh substrate, from D015)**: Every re-entry MUST be a genuinely fresh process/context that resumes from disk (`claude -p`), NOT in-session `ScheduleWakeup` — the only substrate that gives true per-rotation context reset (M045 P01 proved in-session does not). This spec MUST NOT inherit the proposal's stale `ScheduleWakeup` framing.
- **CON-2 (state-on-disk authoritative)**: Correctness across any re-entry or worker MUST derive entirely from on-disk state (`derive-phase.sh` + task scanning). Markers, leases, and continue-files are informational/coordination only; a lossy one MUST NOT corrupt progress.
- **CON-3 (auto-loop.sh unchanged except FR-12)**: The state machine MUST NOT be rewritten. The ONLY additive change is the deterministic marker write (FR-12), idempotent and keyed strictly to existing exit codes so FR-8 legacy parity holds. The classifier, `route-to-dispatch.sh`, and `build-context.sh` stay byte-unchanged.
- **CON-4 (double-gate default-OFF)**: `--self-continue` OFF by default AND `--unattended` a second explicit per-run flag; neither silently defaultable via config (inherits M045 CON-4, extends it for unattended per D4).
- **CON-5 (hard caps are driver-enforced, always-on)**: Under `--unattended`, `--max-budget-usd` + `--max-iters` + `AUTO:BLOCK_AMBIGUITY` + bounded write scope are non-negotiable, enforced by the outer loop before each spawn, fail-closed (refuse-to-start on a missing cap). No config knob can weaken them.
- **CON-6 (no design on unverified primitives)**: Stop hooks (Posture 3) and any background-Task/worktree-management primitive used for fan-out MUST be confirmed against official docs AND shown to survive the M021 shape-guard + M028 consumer hook-install path BEFORE any load-bearing design depends on them (the D015 burned-once lesson). Shipped fan-out defaults to N parallel `claude -p` over git worktrees; fancier primitives are optional accelerants only.
- **CON-7 (cloud deferred, not dark)**: The cloud-routine substrate MUST NOT ship without a live consumer (Principle VIII); it is deferred with the `AUTO_CMD` seam preserved.
- **CON-8 (fan-out write discipline)**: Concurrent workers MUST write only within their worktrees; the coordinator MUST serialize all shared-tree writes and MUST re-assert its branch before each shared write (known parallel-agent shared-tree collision hazard).

### Knowledge-Layer Boundary

This milestone writes to the **execution log** (`self_continue_*`, `fanout_*` record types), per-segment transcript files, the on-disk budget lease ledger, and per-worktree state. It does NOT write to `KNOWLEDGE.md`, `DECISIONS.md` (except the FR-27 D1–D4 transcription, which is a governance record authored at specify, not a runtime write), MEM entries, or `knowledge/**` — those remain owned by M020 and the per-phase consolidation flow.

---

## Posture Detailed Designs

### Posture 1 — Attended self-continue (inherited, unchanged)

Shipped in M045. `self-continue-drive.sh` re-spawns a fresh `claude -p "orchestrator:auto <dir>"` per rotation, gated by `self-continue-branch.sh` (rotation AND `--armed` AND `headless_reentry`), bounded by `--max-continuations` + stop-file + thrash `progress` field, observable via FR-9 JSONL + FR-10 STALLED watchdog. v2b consumes it as the per-worker primitive and the Posture-2 base. **No change** beyond the shared FR-12 deterministic marker and FR-11 vocabulary extension, both of which are backward-compatible with M045's attended path.

### Posture 2 — Unattended / overnight

Built as a **generalization of `self-continue-drive.sh`**, never a new mechanism. Layers onto Posture 1:
1. **Double-gate** `--self-continue --unattended` (FR-9); fail-closed refuse-to-start if either mandatory cap is missing (FR-10, graft from Approach 3).
2. **Driver-enforced caps before each spawn**: `--max-iters` (driver counter) + `--max-budget-usd` (file-derived from M019 JSONL, conservative reconcile) (FR-10).
3. **`AUTO:BLOCK_AMBIGUITY`** distinct terminal (FR-11), modeled on the M034 headless review-gate policy shape (`ORCH_HEADLESS=1` + defer/accept-with-audit/refuse-entry).
4. **Deterministic marker** (auto-loop.sh sole writer, FR-12) kills the overnight silent-stall.
5. **Bounded write scope** (FR-13) + **per-segment transcript capture** (FR-14).
6. **Substrate**: headless `claude -p` via the formalized `AUTO_CMD` seam (FR-15). **Cloud DEFERRED** (CON-7) — affirmative call, seam preserved.
7. **Fan-out** (below) is the Posture-2-only concurrency layer.

### Posture 3 — Until-verified (unit-grain)

A **separate substrate** from the process-fresh loop: a CC Stop hook (`decision:"block"`) at the task-verify seam, reusing `AUTO:VERIFY_PASS/FAIL` and the branch-decision SHAPE but NOT the re-spawn loop (FR-23). **Unit grain only** (FR-24) — because in-session Stop-hook re-entry gives no context relief (D015), it is bounded to short verify→fix→re-verify loops; milestone-grain self-continuation is Posture 1's job. Greenfield: no Stop-hook seam exists today; CON-6 verification gates it before build. Degrades to single-pass-with-one-retry when `stop_hook=false` (FR-26).

---

## Unified A/B/C Entry + Tier-Sizing

**Front door**: one `orchestrator:auto <arg>`, classify-FIRST / enter-loop-LAST.

**Positional disambiguation** (FR-1): `milestone=M###` prefix or existing milestone-dir → Tier C target, skip classification; any other bare string → free-text → `shape-detect.sh` → `input_shape` + high/low → numeric confidence vs `entry_routing_confidence_floor` (0.7, 4-layer precedence preserved).

**Routing table** (FR-2, first-match, mirrors `do-entry.sh:311-346`):

| Verdict | Branch | Lock? | Substrate |
|---|---|---|---|
| tier_a_plus | `route-to-dispatch.sh` handoff | no | one-shot |
| idea/paragraph high-conf | `build-context.sh --profile=quick` fast-path | no | single dispatch (+ optional Posture-3) |
| fragment/spec/long | Tier B → `orchestrator:dispatch`/specify advisory | no | guided |
| `milestone=`/dir OR Tier C | acquire lock + `auto-loop.sh` | **yes** | full milestone loop (+ Posture-1, + optional Posture-2) |
| below floor, attended | interactive Tier A vs B prompt | no | — |
| below floor, `--unattended` | `AUTO:BLOCK_AMBIGUITY` | no | — |

**Tier-sizing** (FR-4/FR-5), tier ⟂ intensity:

| Tier | Substrate (structural scope) | Default intensity | Posture defaults |
|---|---|---|---|
| A | single dispatch, no state machine, no lock | Quick | optional Posture-3 micro-loop |
| B | phase-scoped loop over the phase's tasks | Standard | Posture-1 self-continue on context boundary |
| C | full milestone loop | Full | Posture-1 + optional Posture-2 unattended fan-out |

No in-loop A→C upgrade (FR-5): Tier A produces zero orchestrator state; outgrowing it BLOCKs back to `evaluate`.

---

## `orchestrator:do` Deprecate-Merge + Migration Notes

- **One-release shim** (FR-6): `orchestrator:do` prints a deprecation notice naming `orchestrator:auto` and forwards `--task` to it, preserving current output; removed the following release.
- **`--yes` semantics change** (FR-8): broadens from do's Tier-A+-prompt-skip to auto's "skip ALL approval prompts." Prominent in migration notes.
- **Full migration surface** (FR-7): `packaging/skills/orchestrator-do.md`, `packaging/bundle/manifest.yml`, `build-bundle.sh`, `commands/do.md`, `docs/{getting-started,recipe-authoring,why-this-exists}.md`, `references/{model-routing,installation}.md`, `scripts/verify/m002-p07-doctor-md-sections.sh`, `scripts/diagnostics/check-config-drift.sh`. Verified by SC-3.
- **Changelog** (FR-7): breaking-change entry on the `orchestrator:update` surface.
- **Preserved verbatim**: FR-12 `doing:` line, confidence-floor knob + high/low→1.0/0.5 mapping, Tier-B/C advisory, Quick-intensity preflight suppression (FR-3).

---

## Parallelism / Fan-out Design (Posture 2)

Fan-out is **net-new** — `self-continue-drive.sh` is strictly serial with no seam. Build a coordinator `auto-fanout.sh` ABOVE the M045 driver; the driver becomes the per-worker primitive. This is where the operator's maximize-fan-out, tokens-not-a-constraint intent lands.

**Frontier from the existing DAG** (FR-17, graft from Approach 4): the roadmap template already encodes `Depends:` edges + `## Dependency Graph` + `## Execution Order`. The coordinator parses these into a topological DAG and computes the eligible frontier = every unit whose deps are satisfied per on-disk state. Fan out at TWO grains (tokens not a constraint): across independent milestones AND across independent phases within a milestone.

**Rolling wavefront** (graft from Approach 2): dispatch the eligible frontier concurrently, one process-fresh worker per unit, bounded by a generous machine-limited `--max-parallel` (default generous, not token-driven). As workers finish, release newly-unblocked units to keep the frontier saturated.

**Worktree isolation** (FR-18): each worker runs in `.worktrees/<unit>` (existing `git_isolation` seam) with its OWN lock — resolves the single-lock-per-`.orchestrator` invariant; a runaway worker can only dirty its own worktree; a failed unit is discarded by dropping the worktree (reversibility, graft from Approach 3). **Shipped default = N parallel `claude -p` processes over git worktrees** (CON-6); `EnterWorktree`/background-Task primitives are optional accelerants only after official-doc confirmation.

**File-derived budget lease ledger** (FR-19, resolves the judge-flagged in-memory-pool anti-VI flaw): a single on-disk reserve-then-spend ledger. A worker reserves budget before spawning; reconciles actual spend from the M019 JSONL on marker; sub-caps are hard kill thresholds. Because the ledger is on disk, it is both atomic (lease file) and Principle-VI-pure — no in-memory pool race.

**Coordinator owns shared writes** (FR-20, CON-8): workers write only within worktrees; the coordinator serializes all shared-tree writes (KNOWLEDGE.md, observability JSONL, index rebuild, roadmap sync) and re-asserts its branch before each (parallel-agent collision hazard).

**Gated merge-back** (FR-21): completed worktrees merge back serially with conflict detection; each merge runs `orchestrator:verify` + optional conversus gate; under `--unattended`, merge-back is explicit/gated/reviewable — never auto-merged; a conflict parks the unit `blocked`.

**Quarantine + digest** (FR-22): a failed/BLOCKed worker parks its worktree without stalling siblings; all blockers surface in an unmissable wave-close digest.

**Disjoint-ownership precondition** (graft from Approach 4, conversus red-team's primary target): merge conflicts are rare BY DESIGN because roadmap boundary maps assign disjoint file ownership per unit; a plan-time disjoint-ownership verifier enforces it as a precondition for concurrency.

---

## M009 Runtime-Degrade Story

Single degrade point: `detect-capabilities.sh`, extended (FR-25) with `headless_reentry` (exists), `stop_hook`, `worktree_capable`, future `cloud_reentry`. The substrate-agnostic `self-continue-branch.sh` core consumes these and emits byte-stable fallbacks (FR-26):

- **Codex CLI / Cursor** (no `claude` on PATH): `headless_reentry=false` → `AUTO:ROTATE_EXIT reason=headless-unavailable` → today's manual re-invoke handoff (already working, M045 US3).
- **No Stop hooks**: `stop_hook=false` → Posture 3 falls back to single-pass-with-one-retry.
- **No worktree substrate**: `worktree_capable=false` → fan-out falls back to serial single-driver execution.
- **Fail-closed under `--unattended`**: a missing `headless_reentry` REFUSES to start rather than degrading to an unsafe path (graft from Approach 3).

Every degrade preserves the existing byte-stable contract — no crash on non-CC runtimes, only reduced autonomy. `AUTO_CMD` remains the substrate-swap seam so a future Codex/Cursor headless backend slots in without touching the branch core. Coordinate with M009.

---

## Conversus Red-Team Gate (D4 — required at specify)

Per CON-D4 and proposal Risk 2/5, a conversus red-team pass is a **required specify-stage gate**, not optional. Recommended shape: `red-blue` mode against this spec, targeting:
1. **The unattended safety envelope** — can any path defeat the double-gate, the driver-enforced caps, `AUTO:BLOCK_AMBIGUITY`, or the bounded write scope? Specifically probe false-high-confidence misclassification proceeding unattended.
2. **The two burned-once primitive assumptions** (CON-6) — Stop-hook `decision:"block"` behavior and the fan-out worktree/Task primitives against official docs, mirroring the D015 ScheduleWakeup lesson.
3. **The file-derived budget lease under concurrency** — can N async workers race past `--max-budget-usd`?
4. **The disjoint-file-ownership precondition** for fan-out (the primary target — boundary-map violation is the concurrency-correctness load-bearing assumption).
5. **The `--yes` breaking change** blast radius on downstream consumers.

Gate verdict PASS is a precondition for the roadmap. Use the `orchestrator-conversus-gate` / `conversus` skill; record the deliberation artifact under the milestone.

---

## Success Criteria

- **SC-1 (unified entry routing)**: A table-driven fixture over the full input corpus asserts each input lands on the correct branch (Tier A/A+/B/C/target-skip/low-conf) with byte-stable Quick-intensity preflight suppression on the Tier A path; script exits 0. (US1, FR-1..FR-4)
- **SC-2 (tier ⟂ intensity)**: A fixture asserts tier and intensity are independently set and overridable, and that no in-loop A→C upgrade occurs (an outgrown Tier A BLOCKs to evaluate); exits 0. (FR-4, FR-5)
- **SC-3 (do-merge migration)**: With `do.md` removed, the doctor + config-drift section checks exit 0; a fixture asserts the shim forwards + deprecation notice + `orchestrator:update` changelog entry + `--yes` migration note present; exits 0. (US2, FR-6..FR-8)
- **SC-4 (unattended terminal safety)**: A harness forces every terminal outcome and asserts no further spawn, plus asserts fail-closed refuse-to-start when a mandatory cap is missing; exits 0. (US3, FR-9, FR-10, CON-5)
- **SC-5 (driver-enforced caps)**: A fixture whose next segment would exceed `--max-budget-usd` (per a seeded M019 JSONL) halts with `SELF_CONTINUE:BUDGET_CAP` *before* the spawn; a separate fixture halts at `--max-iters` with `SELF_CONTINUE:CAP_REACHED`; exits 0. (US3, FR-10)
- **SC-6 (BLOCK-on-ambiguity)**: A below-floor unit under `--unattended` emits the distinct `AUTO:BLOCK_AMBIGUITY` terminal (never the 60s-timeout-to-cancel) and, in fan-out, does not stall independent siblings; exits 0. (US3, US4, FR-11)
- **SC-7 (deterministic marker parity)**: A fixture asserts `auto-loop.sh` writes the correct marker for each exit code (2/3/10/11/14), that the write is idempotent, and that the un-armed rotation-exit path stays byte-identical to a version-pinned golden capture (FR-8 legacy parity preserved); exits 0. (FR-12, CON-3)
- **SC-8 (runtime degrade)**: Capability fixtures (`headless_reentry`/`stop_hook`/`worktree_capable` = false) each assert the byte-stable legacy fallback + recorded degrade reason, and that `--unattended` refuses to start when `headless_reentry=false`; exits 0. (US6, FR-25, FR-26)
- **SC-9 (VIABILITY — fan-out, milestone-blocking, NON-stubbed)**: A **real** unattended run over a fixture roadmap with ≥2 genuinely independent units MUST dispatch ≥2 concurrent process-fresh `claude -p` workers in separate worktrees each holding its own lock, complete them, and merge back serially with zero shared-`.orchestrator/` write corruption and zero worktree lock contention. The milestone MUST NOT close on stub evidence alone. Modeled on the M036a live-LLM-smoke precedent (env-gated live branch, e.g. `ORCHESTRATOR_FANOUT_LIVE=1`). A negative result routes fan-out scope forward rather than silent re-scope. (US4, FR-16..FR-22, CON-6)
- **SC-10 (VIABILITY — budget lease under concurrency, milestone-blocking, NON-stubbed)**: A **real** concurrent run with a deliberately tight aggregate `--max-budget-usd` MUST NOT overshoot the cap across N live workers — the on-disk reserve-then-spend ledger MUST hard-stop the pool at the ceiling. Verified against real cost JSONL, not a stub. (US4, FR-19)
- **SC-11 (VIABILITY — Stop-hook micro-loop, milestone-blocking, NON-stubbed)**: A **real** `--until-verified` unit whose verification fails then passes MUST loop verify→fix→re-verify via a live CC Stop hook that (a) survives the M021 shape-guard, (b) installs and fires from the consumer-project hook path (`~/.claude/orchestrator-hooks/`, M028), and (c) never recurses at milestone grain. If official-doc verification (CON-6) shows Stop-hook `decision:"block"` cannot meet this contract, Posture 3 scope routes forward and the milestone closes without it. (US5, FR-23, FR-24, CON-6)
- **SC-12 (conversus red-team PASS)**: The D4 red-team deliberation returns a PASS verdict (or all BLOCK findings are resolved with recorded mitigations) before roadmap; the artifact is on disk under the milestone. (CON-D4)
- **SC-13 (governance)**: D1–D4 are present as durable records in `.orchestrator/DECISIONS.md`; a check asserts their presence; exits 0. (FR-27)

---

## Open Questions (defer to planning unless marked resolved)

- **#Q-1 (/goal) — RESOLVED: REJECTED-with-evidence, not deferred**: `/goal` (official, `code.claude.com/docs/en/goal.md`, v2.1.139+) is turn-based *in-session* looping with a Haiku evaluator; it is session-scoped (one active slot) and gives NO per-rotation context relief — the same failure mode M045 P01 proved for ScheduleWakeup (D015). It is REJECTED as a Posture 2/3 substrate. The spec MUST record it as REJECTED, never as deferred investigation, so a future author cannot reintroduce the D015-class error.
- **#Q-2 (Monitor) — RESOLVED: REJECTED-with-evidence**: `Monitor` (official, `tools-reference.md`, v2.1.98+) is a background event-STREAMING primitive invoked automatically inside dynamic `/loop`; it does NOT evaluate a boolean condition and cannot gate loop iteration (it is streaming, not condition-gating). Also unavailable on Bedrock/Vertex/Foundry. REJECTED as a Posture 3 gate; Stop hooks are the mechanism.
- **#Q-3 (Stop-hook grain enforcement mechanics)**: Exactly how is unit-grain-only structurally enforced (preventing milestone-grain misuse) and how does `stop_hook_active` + the stuck-detector threshold compose? Owner: plan-phase, gated by CON-6 verification. (proposal #3, still open)
- **#Q-4 (cloud ship/defer) — RESOLVED: DEFER**: Per D2's goal-backward pass + Principle VIII, the cloud routine DEFERS (no live consumer at ship); `AUTO_CMD` seam preserved for later. Revisit when a live overnight-cloud consumer appears. (proposal #4)
- **#Q-5 (primitive verification before build)**: CON-6 requires official-doc confirmation of Stop-hook `decision:"block"` behavior AND any fan-out worktree/background-Task primitive before load-bearing design. Owner: plan-phase spike, mirroring M045 P01. `/goal`+Monitor are already resolved (#Q-1/#Q-2). (proposal #5)
- **#Q-6 (M040 contradiction-gate composition)**: Should an unattended loop hard-BLOCK on an M040 FLAG/BLOCK verdict, or route to the human-gated queue and continue independent units? Owner: plan-phase; composition point, not a blocker. (proposal #6)
- **#Q-7 (orphaned per-unit worktree recovery)**: How does `orchestrator:resume` recognize and reconcile `.worktrees/<unit>` directories with stale per-unit locks after a fan-out crash? Owner: plan-phase; greenfield against a lock-manager that assumes one lock per `.orchestrator`.
- **#Q-8 (fan-out default width)**: Full-frontier by default (tokens not a constraint) vs a conservative `--max-parallel` default? Recommend full-frontier gated only by a generous machine-limit knob, but confirm against the aggregate budget-lease semantics at plan-phase.
- **#Q-9 (`--yes` breaking-change window)**: Is one release enough deprecation runway for the `--yes` semantics broadening, or does it warrant a longer window / a distinct flag alias? Owner: plan-phase + conversus red-team #5.

---

## Phase-Decomposition Suggestion (for `orchestrator:roadmap`)

Sequenced so the highest-risk verification-gated primitives are spiked before load-bearing design, mirroring the M045 P01→P04 shape. Estimate 7 phases.

- **P00 — Governance + primitive-verification spike (gate)**: Transcribe D1–D4 into DECISIONS.md (FR-27). CON-6 official-doc verification of Stop-hook `decision:"block"` + the fan-out worktree primitive; record `/goal`+Monitor REJECTED. Run the D4 conversus red-team gate (SC-12). Output: go/no-go per posture + a verified-primitive record. **Blocks P04/P05 design.**
- **P01 — Unified classify-first entry**: Convert the Tier B/C stub into the real branch; positional disambiguation; preserve all do behaviors; tier ⟂ intensity wiring. Satisfies SC-1/SC-2. (Lowest-risk, highest structural leverage — do first after the gate.)
- **P02 — `orchestrator:do` deprecate-merge + migration sweep**: Shim, `--yes` reconciliation, full migration surface, changelog. Satisfies SC-3. (Depends on P01.)
- **P03 — Deterministic marker + Posture-2 unattended envelope**: FR-12 auto-loop.sh sole-writer marker (idempotent, exit-code-keyed, golden-parity), double-gate, driver-enforced caps (file-derived budget from M019 JSONL), `AUTO:BLOCK_AMBIGUITY`, bounded write scope, transcript capture, status.sh thrash/budget. Satisfies SC-4/SC-5/SC-6/SC-7. (Depends on P01; independent of P02 — parallel-eligible.)
- **P04 — Fan-out coordinator (net-new)**: `auto-fanout.sh`, DAG frontier from roadmap sections, rolling wavefront, worktree isolation + per-unit locks, file-derived budget lease ledger, coordinator-owned shared writes, gated serial merge-back, quarantine + wave-close digest, plan-time disjoint-ownership verifier. **NON-stubbed viability gate SC-9 + SC-10.** (Depends on P00 gate + P03.)
- **P05 — Posture 3 until-verified Stop-hook**: Unit-grain Stop hook at the task-verify seam, `stop_hook_active` guard, stuck-threshold cap, single-pass fallback. **NON-stubbed viability gate SC-11.** (Depends on P00 gate; independent of P04 — parallel-eligible.)
- **P06 — M009 runtime-degrade + closeout**: `detect-capabilities.sh` per-substrate flags, byte-stable fallbacks, fail-closed unattended refuse-to-start, acceptance battery, migration-notes finalization, milestone summary. Satisfies SC-8; re-runs the full battery. (Depends on all prior.)

**Parallel-eligible waves** (for the coordinator to dogfood itself, if used): {P03, [P04, P05 after P00]} can overlap once P01 lands; P02 is independent of P03. P00 gates P04/P05; P06 joins all.
