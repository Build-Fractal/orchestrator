---
schema_version: "1.0"
type: context-draft
milestone: "M046"
status: finalized
created_at: "2026-07-02"
finalized_at: "2026-07-02"
---

## Architectural Decisions

- **D-SPLIT (scope split)** — M046 is the **serial core** of the auto-v2b vision. Fan-out (concurrent multi-worker execution, git-worktree per-unit locks, reserve-then-spend lease ledger *under concurrency*, roadmap-DAG frontier scheduling, merge-back) is carved to a future **v2c-fanout** milestone; Posture-3 (until-verified unit-grain Stop-hook) is carved to its own demand-driven slice. Rationale: the serial `--unattended` safety envelope is the load-bearing prerequisite both carve-outs stand on — building it first is the only safe order. Fan-out viability is already banked (P00 spike, N=3 concurrent `claude -p` PASS: parallelism 2.88×, no 429/session-lock, cost readable via `--output-format json`), so v2c inherits proven ground rather than the M045 P01 trap.
- **D015 (process-fresh substrate, inherited from M045)** — every re-entry is a genuinely fresh process/context resuming from disk (`self-continue-drive.sh` re-spawns `claude -p`). In-session `ScheduleWakeup` MUST NOT be reintroduced (M045 P01 proved it delivers no per-rotation context relief). This is CON-1.
- **Unified classify-first entry** — `orchestrator:auto <arg>` routes via the existing M024 classifier (`shape-detect.sh`) to a tier-sized path (Tier A one-shot / Tier C loop / BLOCK), reusing `route-to-dispatch.sh` + `build-context.sh` byte-unchanged (FR-1/FR-2). `orchestrator:do` becomes a thin deprecation shim forwarding all six flags (FR-3/FR-4).
- **`auto-loop.sh` blast-radius discipline (CON-2)** — exactly ONE additive change inside `auto-loop.sh`: the deterministic outcome-marker write for its own exit-0 continuation substates (PLANNING/PHASE_COMPLETE/VALIDATING). The driver's shell wrapper writes only the terminal marker for cases `auto-loop.sh` cannot self-report (CHILD_ABORT). This is the FR-14 writer division-of-labor (conversus MIT-1).
- **Conversus gate outcome (Full strict, verdict=PASS / "proceed with conditions")** — architecture survived 4 adversarial rounds with no structural counterexample; the red team withdrew its marker-contract attack. 7 text amendments (MIT-1..MIT-7) already applied to the spec: FR-14 writer division-of-labor, marker atomicity (temp+rename), SC-11 anti-circularity protocol, SC-5 MCP-deny vector into the milestone-blocking gate, SC-3 cost/duration-discriminating fixture, wall-clock into the fail-closed set, FR-4 wording.
- **Post-discuss LFD-article amendments (2026-07-03)** — three insights from the loss-function-development playbook (Elvis Sun) folded into the spec as FR-18/FR-19/FR-20 + CON-7 + SC-13..15 + #Q-8/#Q-9: (1) **attempts-ledger** — a per-unit durable on-disk record of tried approaches + failure modes that each process-fresh rotation reads, since D015's total-context-wipe risks blind re-attempts (the mirror of `/goal`'s local-maxima problem); load-bearing prerequisite for a safe Posture-3. (2) **agent-queryable instruments** — every constraint gets a read-only introspection CLI so the child self-regulates ("a constraint without an instrument is a vibe"). (3) **verification-integrity** — the executing child cannot edit the SC/verification/scoring that gates it (separation of doing vs scoring; the anti-gaming fence). Forced-entropy was analyzed and deliberately NOT adopted (it is an optimization-loop construct; SDD stall → escalate-to-human via FR-12). The LFD "optimize-toward-metric" outer-loop paradigm captured as a separate demand-driven brief at `.orchestrator/proposals/lfd-optimize-mode.md` (possible future Posture 4), explicitly out of M046 scope.

## Scope Boundaries

**In scope (v2b serial core):**
- US1 — unified tier-sized A/B/C entry to `orchestrator:auto`.
- US2 — `orchestrator:do` deprecate-and-merge (all six flags forwarded; installed-consumer migration via `orchestrator:update` re-stage).
- US3 — serial `--unattended` safety envelope: in-segment budget ceiling + watchdog SIGKILL (FR-7), reserve-then-spend accounting (FR-8), default-DENY PreToolUse path+tool+MCP allowlist hook (FR-9), stop-file live-kill (FR-10), BLOCK-on-ambiguity + second-gate (FR-11), thrash-terminal (FR-12), fail-closed caps in the driver (FR-13), marker-full-exit-contract (FR-14), no-shell-interpolation (FR-15).
- US6 — runtime degrade: refuse `--unattended` (not run unsafely) where the substrate or hook is unavailable; attended `auto` falls back to M045 (FR-16).

**Out of scope (explicit Non-Goals):**
- Fan-out coordinator + worktree/lock/lease → v2c-fanout.
- Posture-3 until-verified Stop-hook → own slice.
- Cloud-routine substrate → DEFERRED (AUTO_CMD contract formalized so it slots in later; not shipped dark).
- `/goal` and `Monitor` as substrates → REJECTED (unverified / wrong-shape).
- In-loop tier re-sizing (A→C mid-run) → a Tier-A task that outgrows Tier A BLOCKs back to `evaluate`.
- Rewriting `auto-loop.sh` / the on-disk state machine → only the one CON-2 additive change.
- Milestone-grain Stop hooks → that is Posture 1's job (M045).

## Design Constraints

- **CON-1** process-fresh only (D015); no in-session `ScheduleWakeup`.
- **CON-2** `auto-loop.sh` gets ≤1 additive marker write; FR-11 ambiguity-block and any verify changes live at the entry/driver/hook layer, never inside `auto-loop.sh` (amend only via explicit Decision row).
- **CON-3** all new behavior defaults OFF (`--unattended` especially).
- **CON-4** under `--unattended`, hard budget + iteration caps + wall-clock ceiling + BLOCK-on-ambiguity always on; no disable flag.
- **CON-5** every safety enforcement fails closed — absence of a guarantee halts, never proceeds unsafely.
- **CON-6** no load-bearing design rests on an assumed primitive until confirmed against official docs AND (for concurrency/cost/hook) shown to survive the M021 shape-guard + M028 consumer hook-install path + an empirical spike. The PreToolUse hook, cost-read path, and marker contract each carry a non-stubbed gate (SC-3/SC-5/SC-9).
- **Three non-stubbed milestone-blocking gates** — SC-3 (in-segment SIGKILL), SC-5 (write+tool+MCP scope), SC-9 (full marker exit-code contract). A stub/golden-fixture substitute at implementation time is a Principle II violation that blocks closure regardless of spec-text quality (arbiter "ongoing monitoring" ruling).
- **Dependencies** — hard: M045 (substrate), M024 (classifier), M019 (cost read), M028 (hook install), M021 (shape-guard). Inspiration-only (NOT build deps): M009 (degrade), M034/M040 (second-gate/decision shape) — shapes self-contained so a later build can't force rework.

## Open Questions

- **#Q-1 (hook-install-portability)** — can the default-DENY PreToolUse hook install via the M028 path on every CC install shape (npm/homebrew/curl/symlink) and survive the shape-guard? Answered by the planner + SC-5 non-stubbed proof at plan-phase. Corpus-gate: not corpus-answerable (new hook surface).
- **#Q-2 (yes-broadening-resolution)** — distinct flag alias / longer window vs explicit notice for `--yes` broadening? Operator at plan-phase; conversus red-team target.
- **#Q-3 (do-removal-runway)** — deprecation runway length + gating release for shim removal. Operator + roadmap at plan-phase.
- **#Q-4 (m019-cost-cadence)** — does M019 Tier-1 JSONL emit per-segment in time for pre-spawn lease reads, or is `claude -p --output-format json` `total_cost_usd` the sole source? **Precondition for SC-3 sign-off** (not parallel). Verified at plan-phase.
- **#Q-5 (second-gate-substrate)** — FR-11 second gate = cheap second-model, M042 corpus-gate, or both? Plan-phase cost/precision trade-off.
- **#Q-6 (precision-floor-protocol)** — who is the independent (non-implementer) measurer; what corpus composition is defensible; does the numeric floor need hard-coding in-spec vs deferred under the commit-before-measure protocol? First measured rate provisional pending a second independent conversus review.
- **#Q-7 (wall-clock-default)** — is the wall-clock ceiling a fixed internal constant (what value?) or a future operator flag? Always-on either way; only value/mechanism open.
