# M-auto-v2b — Red-Team Conditions (pre-specify gate)

Source: `scope-auto-v2b` workflow (2026-07-02), 3 adversarial lenses (safety / scope / viability), each returning **PROCEED_WITH_CONDITIONS**. Distilled, deduplicated. These are the conditions to fold into the spec before `orchestrator:specify` locks it. Companion to `M-auto-v2b-pre-spec.md`.

## Verdict
All three lenses: **PROCEED_WITH_CONDITIONS**. No BLOCK. The pre-spec is buildable, but two structural changes and several P0 safety/viability fixes are mandatory first.

## The two structural must-fixes (SCOPE lens, P0)

### S1 — Split the milestone at its own seam ("three milestones in a trenchcoat")
The pre-spec bundles 3 independent capability domains + a breaking migration + runtime degrade, and carries **three separate non-stubbed "cut-if-not-viable" gates** (SC-9 fan-out, SC-10 budget-lease-under-concurrency, SC-11 Stop-hook). Calibration: M045 shipped ONE posture in 4 phases.
- **Ship as v2b**: US1 (unified entry) + US2 (do-merge) + US3 (serial unattended safety envelope: caps + BLOCK-on-ambiguity) + US6 (runtime degrade). This is the spec's own self-declared "Minimal Slice" load-bearing scope.
- **Carve out `v2c-fanout`**: P04 fan-out coordinator + SC-9/SC-10 (worktree/lock/lease/merge-back complex).
- **Carve out** Posture-3 Stop-hook (P05 + SC-11) as its own demand-driven slice.

### S2 — The single-lock-per-`.orchestrator` rework is a hidden foundational dependency
Per-unit worktree locks (FR-18) + orphan-worktree resume reconciliation (#Q-7) require reworking lock-path derivation across `auto-loop.sh:165`, `commands/auto.md:156`, the resume flow, and all lock-state readers. This contradicts the CON-3/G6 "auto-loop.sh gets exactly ONE additive change" claim. Must be lifted into its own first-class phase (belongs with the carved-out fan-out milestone) with a resume-reconciliation acceptance test.

## The viability must-fixes (VIABILITY lens, P0) — the M045 P01 trap, again

> **UPDATE 2026-07-02 — V1 + V2 RESOLVED by the P00 spike** (`M-auto-v2b-P00-spike-evidence.md`). Concurrent `claude -p` under one OAuth: 3/3 clean, no 429/session-lock, parallelism ratio 2.88×, concurrent faster than solo. Cost readable via `--output-format json` (`total_cost_usd` per worker). Fan-out is a viable primitive at proven floor N=3. V3 (marker exit-code contract) still open. New budget input: ~$0.245 cold-start floor per process-fresh worker.

### V1 — Concurrent `claude -p` under one OAuth is UNVERIFIED and its only gate fires too late
The headline fan-out primitive (N concurrent `claude -p`) has never been exercised — `self-continue-drive.sh:57` runs exactly one at a time. **Project KNOWLEDGE records the Anthropic OAuth path "429s as policy gates, not transient"** — N parallel sessions may serialize/429/session-lock, collapsing the whole parallelism goal. SC-9 as a P04 *exit* gate is a verbatim repeat of the M045 P01 "design-first, verify-later" trap.
- **Fix**: a minimal empirical concurrency spike in **P00** (before any coordinator design): launch 2 real `claude -p` concurrently under live OAuth, each in its own worktree + lock; prove (a) both progress without 429/session-lock, (b) per-worktree locks isolate, (c) coordinator shared-tree writes serialize without corruption. Block P04 design on the result. If it 429s, fan-out re-scopes to bounded-sequential or a conversus-subagent substrate.

### V2 — The unattended money-cap rests on an unverified cost-read assumption
FR-10/FR-19 budget caps assume a headless `claude -p` child emits M019 Tier-1 cost JSONL the parent can read in near-real-time before the next spawn. **M045 never did this** — budget lived inside `auto-loop.sh` and was observed post-hoc. Current coverage is stubbed (SC-5 seeded JSONL, SC-10 arithmetic only). If headless writes cost only at session-end or into a child-local root, the cap is silently defeated overnight.
- **Fix**: add a non-stubbed P00 read-path spike — a real headless segment must emit M019-readable cost into the path the driver reads, and the driver must read a nonzero reconciled figure before the next spawn.

### V3 — FR-12 deterministic marker is keyed to the wrong exit-code set (self-refuting)
FR-12 keys the marker to exit codes {2,3,10,11,14}, but `auto-loop.sh` exits **0 for the dominant continuation states** (PLANNING:519, PHASE_COMPLETE:525, VALIDATING:529) and 1/12/13 for errors. So the most common per-iteration exit writes no/wrong marker → driver reads `unknown` → SELF_CONTINUE:STALLED — the exact silent stall FR-12 claims to kill.
- **Fix**: re-derive the FULL exit-code contract from `auto-loop.sh`; FR-12 + SC-7 assert marker correctness for the complete set, non-stubbed against the real file. Also make the marker write happen in a deterministic SHELL wrapper the driver controls (trap on child exit), not inside the LLM's execution path; define the killed/crashed case as terminal `SELF_CONTINUE:CHILD_ABORT`.

### V-scope — CON-6 rescope
CON-6 currently demands "official-doc confirmation" for new primitives. Docs cannot verify concurrent-`claude-p` auth behavior or headless cost-JSONL timing — only a live spike can. Rescope CON-6 to "official-doc confirmation AND empirical concurrency/read-path spike" for fan-out + budget-read primitives.

## The safety must-fixes (SAFETY lens) — for the serial unattended envelope that STAYS in v2b

- **P0 — `--max-budget-usd` is not a real ceiling.** It's only a between-spawn checkpoint (`drive.sh:47-57`); one segment runs `auto-loop.sh` over many tasks unbounded, and the operator stop-file has one-full-segment latency. Require in-segment enforcement: pass a hard budget/wall-clock timeout INTO the child (self-abort) AND a driver watchdog that SIGKILLs the `claude -p` PID mid-segment when a live probe crosses the ceiling. SC-5 must prove a real runaway is killed mid-flight (non-stubbed), and that the stop-file kills a live segment within bounded latency.
- **P0 — Budget blind to a child that dies before flushing its cost record.** Extend the reserve-then-spend lease ledger (currently FR-19, fan-out only) to the **single-worker** Posture-2 path: reserve conservatively to disk before each spawn; treat an unreconciled reserve as SPENT, not free (fail-closed accounting). Add an SC proving a child killed before flushing still decrements budget.
- **P0 — FR-13 "bounded write scope" has NO enforcement + the tool surface is unbounded.** Only installed hooks are shape-guard + before-commit; neither constrains write paths or tools. An unattended child keeps full Write/Edit-anywhere, arbitrary Bash (git push --force, curl, rm), and all MCP servers (Gmail/Slack/Vercel/Supabase). **Worktrees isolate the filesystem tree only — NOT the shared git remote, `~/.claude` credentials, network, or MCP connections.** Specify a default-DENY PreToolUse hook (path allowlist AND tool allowlist), installed via the M028 consumer hook path, gated by CON-6 (must survive shape-guard + install). SC: a real unattended child attempting an out-of-scope write AND an out-of-scope tool call (git push) is blocked live.
- **P1 — False-high-confidence misclassification defeats BLOCK-on-ambiguity.** AUTO:BLOCK_AMBIGUITY only fires *below* the confidence floor; a false-HIGH verdict on a destructive input proceeds unattended with no backstop. Add a mandatory second gate (cheap second-model / corpus-gate confirmation) on the unattended high-confidence execution path; require the conversus red-team to report a measured false-high rate against a fixture corpus with a milestone-blocking precision floor.
- **P1 — Thrash is observability-only, never terminal.** A child emitting `rotation` with the same phase forever respawns to MAX_CONT burning full budget. Promote thrash to a first-class terminal `SELF_CONTINUE:THRASH`; hard low default under --unattended (e.g. 2 no-progress segments); SC that a no-progress fixture halts on thrash well before the caps.
- **P1 — Command-injection via `AUTO_CMD`.** `drive.sh:40` interpolates the milestone/worktree path into a string run by `sh -c` (`drive.sh:57`); fan-out generates many unit-derived paths. Invoke the child via an argv array (no shell); validate/lock unit + milestone-dir names to a strict charset allowlist. Fixture: a metacharacter-bearing unit name is rejected, not executed.
- **P2 — Fail-closed cap default is in the wrong layer.** `drive.sh:21` silently defaults MAX_CONT=20 when absent; FR-10's "refuse to start on missing cap" is only asserted at the CLI parse. Move fail-closed into the driver: under --unattended the driver itself refuses to start (non-zero) if caps unset. SC invoking the driver directly (bypassing CLI) with caps missing → refuse-to-start.

## do-merge must-fixes (SCOPE lens, P1)
- Forward ALL SIX `do-entry.sh` flags through the deprecation shim (--task, --yes, --config, --dispatch-stub, --scratch-root, --no-prompt-mode), not just --task.
- Resolve #Q-9: FR-8 silently broadens `--yes` from "skip Tier-A+ approval" to "skip ALL approvals" in a command that now owns destructive/unattended paths. Decide distinct alias / longer window vs silent change; treat as a red-team target.
- Add an installed-consumer migration requirement (staged `orchestrator-do` skill whose backing `do-entry.sh` is removed) — not just in-repo file sweeps. Cover the `orchestrator:update` re-stage path + behavior when a consumer does NOT update.

## Dependency hygiene must-fixes (SCOPE lens, P1)
- Classify each unbuilt-milestone reference (M034 headless review-gate shape, M009 degrade, M040 compose) as hard-dependency vs inspiration-only; self-contain shapes so a later build can't force rework.
- Verify M019 Tier-1 JSONL write cadence supports pre-spawn budget-lease reads (same discipline as V2).
- Reconcile FR-25's new `worktree_capable` flag with the EXISTING `detect-capabilities.sh:86` `git_worktree` flag — don't add a synonym. (`stop_hook` / `cloud_reentry` are genuinely new and fine.)

## Primitive dispositions (settled by research)
- **`/goal` and `Monitor`: REJECTED** as substrates (unverified / wrong shape). The shipped fan-out default is N parallel `claude -p` over git worktrees; background/`EnterWorktree`-class primitives are optional accelerants only after official-doc confirmation.
- **Cloud-routine substrate: DEFERRED** (not shipped dark). `AUTO_CMD` formalized so cloud slots in later with an identical marker contract.
