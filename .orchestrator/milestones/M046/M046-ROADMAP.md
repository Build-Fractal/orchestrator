---
schema_version: "1.0"
type: roadmap
milestone: "M046"
feature_ref: "047-auto-v2b-unified-serial"
feature_spec: "specs/047-auto-v2b-unified-serial/spec.md"
vision: "One safe autonomous front door: orchestrator:auto classifies any argument to a tier-sized path, and — under an explicit --unattended flag — runs overnight inside a serial safety envelope (real in-segment budget kill, default-DENY write/tool/MCP scope hook, deterministic marker contract, attempts-ledger) that fails closed on every guarantee."
tier: "C"
created_at: "2026-07-12"
updated_at: "2026-07-12"
---

## Phases

- [x] **P01**: Viability spikes — hook-install portability + cost-read cadence — "Two evidence docs on disk carry firm verdicts: a default-DENY PreToolUse hook installed via the M028 consumer path denies a live out-of-scope call on a real install shape (and survives the M021 shape-guard), and the cost source's per-segment read latency is measured — #Q-1 and #Q-4 are answered before any envelope code exists."
  - Risk: high
  - Depends: none
  - **Decision gate**: resolves #Q-1 and #Q-4 (the SC-3 precondition). A negative #Q-1 (hook cannot install portably / does not survive the shape-guard) reroutes the FR-9 enforcement mechanism via an explicit Decision row before P05 begins. A negative #Q-4 (M019 JSONL cadence insufficient for pre-spawn lease reads) fixes the FR-7/FR-8 cost source to `claude -p --output-format json` `total_cost_usd` sole-source. Mirrors the M045 P01 pattern: a cheap, correct "no" before P04/P05 build on a flawed premise (CON-6).
  - Boundary Map:
    - Produces: `.orchestrator/milestones/M046/phases/P01/P01-VIABILITY-EVIDENCE.md` (VERDICT + #Q-1/#Q-4 resolutions); throwaway spike harness under `phases/P01/spike/`; verifiers `tools/verify/m046-p01-*.sh`
    - Consumes: M028 consumer hook-install path (`scripts/hooks/` install conventions via `packaging/install/install-claude-code.sh`); M021 shape-guard (`scripts/hooks/pre-bash-shape-guard.sh`); M019 Tier-1 cost JSONL emitter; `claude -p --output-format json` cost read (P00 spike evidence, re-verified at segment grain)

- [x] **P02**: Marker full-exit contract + driver injection hardening — "For every real `auto-loop.sh` exit — including the exit-0 continuation substates PLANNING/PHASE_COMPLETE/VALIDATING — the marker on disk names the correct outcome; a child killed mid-write leaves a whole old-or-new marker (atomic temp+rename), a killed/crashed child yields `SELF_CONTINUE:CHILD_ABORT`, and a metacharacter-bearing milestone name is rejected, not executed."
  - Risk: high
  - Depends: none
  - Boundary Map:
    - Produces: `scripts/lifecycle/auto-loop.sh` single CON-2-authorized additive outcome-marker write (FR-14 writer division-of-labor); `scripts/lifecycle/self-continue-drive.sh` hardened — argv-array child spawn (no `sh -c`), strict charset allowlist on milestone-dir names (FR-15), deterministic shell wrapper owning the `CHILD_ABORT` terminal marker, atomic temp+rename discipline for every marker write; SC-9 non-stubbed fixture against the real `auto-loop.sh` exit set + SC-10 injection fixture
    - Consumes: M045 driver trio (`self-continue-drive.sh`, `self-continue-branch.sh`, `self-continue-status.sh`); the real `auto-loop.sh` exit-code contract (0-substates / 1 / 12 / 13)

- [ ] **P03**: Unified tier-sized entry + `orchestrator:do` deprecate-and-merge — "`orchestrator:auto` with a Tier-A description, a Tier-C milestone dir, and an ambiguous arg routes to one-shot dispatch, loop entry, and `AUTO:BLOCK_AMBIGUITY` respectively; `orchestrator:do` prints a one-line deprecation notice and produces byte-identical artifacts through the shim for all six forwarded flags."
  - Risk: medium
  - Depends: none
  - Boundary Map:
    - Produces: `commands/auto.md` unified classify-first entry authoring (FR-1); `commands/do.md` rewritten as deprecation-shim doc (FR-3); `scripts/intake/auto-entry.sh` unified entry driver (absorbs `do-entry.sh` routing; `do-entry.sh` becomes the forwarding shim); explicit `--yes` broadening surface per #Q-2 resolution (FR-5); SC-1 routing fixture + SC-2 byte-equality parity fixture
    - Consumes: `scripts/intake/shape-detect.sh` (M024 classifier, byte-unchanged); `scripts/dispatch/route-to-dispatch.sh` + `scripts/dispatch/build-context.sh` (byte-unchanged, FR-2); `orchestrator:update` re-stage path (FR-4 installed-consumer migration)

- [x] **P04**: Serial budget/caps envelope — in-segment kill, reserve-then-spend, stop-file live-kill, thrash terminal, fail-closed caps — "A runaway segment under `--unattended --max-budget-usd <low>` is SIGKILLed mid-flight with a distinct budget-exceeded terminal (proven cost-derived, not a duration proxy); a child killed before flushing cost still decrements the budget; the stop-file kills a live segment within bounded latency; a no-progress fixture halts on `SELF_CONTINUE:THRASH`; missing caps (budget, continuations, wall-clock) refuse to start."
  - Risk: high
  - Depends: P01, P02
  - Boundary Map:
    - Produces: `--unattended` envelope layer on the process-fresh driver (flag plumbing, FR-6; in-segment cost/duration watchdog with SIGKILL, FR-7; reserve-then-spend budget-lease ledger on disk, FR-8; stop-file live-kill, FR-10; `SELF_CONTINUE:THRASH` first-class terminal, FR-12; fail-closed cap enumeration incl. the #Q-7-resolved wall-clock ceiling, FR-13); SC-3 non-stubbed cost-discriminating fixture (duration held ~constant, cost varied); SC-4 / SC-6 / SC-7 / SC-8 fixtures
    - Consumes: P01 cost-cadence verdict (#Q-4, SC-3 precondition); P02 hardened wrapper + atomic marker discipline (the surface its SIGKILLs land on)

- [ ] **P05**: Default-DENY scope hook + verification-integrity — "A real unattended child attempting an out-of-scope write, an out-of-scope Bash call (`git push`), an MCP tool call outside the allowlist, or an edit to its own success criteria / verification harness / scoring records is denied by the live PreToolUse hook and the attempt is logged."
  - Risk: high
  - Depends: P01
  - Boundary Map:
    - Produces: default-DENY PreToolUse scope hook (write-path allowlist + tool-surface deny + MCP deny-unless-allowlisted, FR-9) installed via the M028 consumer path; FR-20/CON-7 protected-surface manifest (SC definitions, verification harness, scoring records, attempts-ledger scoring fields — read-only to the executing child); SC-5 + SC-15 live non-stubbed harnesses (milestone-blocking)
    - Consumes: P01 hook-portability evidence (#Q-1); M021 shape-guard compliance; M028 hook-install path

- [ ] **P06**: Unattended second gate + classifier precision floor — "An ambiguous arg BLOCKs; a false-high-confidence fixture is caught by the mandatory second gate before any execution; the measured false-high rate meets a precision floor that was committed to disk before measurement, by an independent (non-implementer) measurer, with commit-order inspectable on disk."
  - Risk: medium
  - Depends: P03
  - Boundary Map:
    - Produces: second-gate confirmation wiring in the unified entry under `--unattended` (substrate per #Q-5: cheap second-model / M042 corpus-gate / both, FR-11); precision-floor commit artifact (floor on disk before measurement, #Q-6 anti-circularity protocol); measured false-high-rate evidence + independent-measurer record (SC-11, milestone-blocking)
    - Consumes: P03 unified entry + classifier confidence output; M042 corpus-gate adapter (`scripts/dispatch/adapters/tool/corpus-gate.sh`, candidate substrate)

- [ ] **P07**: Attempts-ledger + agent-queryable instruments — "Rotation N+1's context assembly contains the failed approach rotation N recorded (not re-derived blind), and an executing child can query budget-remaining, wall-clock-remaining, continuation count, and progress-delta and receive live values from read-only CLIs."
  - Risk: medium
  - Depends: P02, P04
  - Boundary Map:
    - Produces: per-unit attempts-ledger on disk (schema/retention/compaction per #Q-8, FR-18) + driver read-before-act / append-after-act wiring in rotation context assembly; read-only introspection CLI set (per #Q-9: extend `scripts/diagnostics/self-continue-status.sh` and/or new instrument commands, FR-19); SC-13 ledger-replay fixture + SC-14 instrument fixture
    - Consumes: P02 hardened driver (rotation assembly + atomic-write discipline); P04 budget-lease ledger + cap state (the live values the instruments expose)

- [ ] **P08**: Runtime degrade + closure battery — "On a simulated non-CC capability profile, `--unattended` refuses to start with a diagnostic while attended `auto` falls back to M045 manual-re-invoke behavior (no unattended-without-hook path exists); the full SC-1..SC-15 acceptance battery passes and attended-path goldens are byte-identical to M045."
  - Risk: medium
  - Depends: P03, P04, P05, P06, P07
  - Boundary Map:
    - Produces: FR-16 degrade wiring (capability probe on `headless_reentry` + hook-install availability, refusal diagnostics, SC-12); `tests/m046-acceptance/run-acceptance-battery.sh` (SC-1..SC-15); FR-17 attended legacy-parity regression goldens; `M046-ACCEPTANCE-EVIDENCE.md` inputs for milestone validation
    - Consumes: P03 unified entry; P04 envelope; P05 hook; P06 second gate; P07 ledger + instruments; `scripts/dispatch/detect-capabilities.sh` `headless_reentry` field (M045)

## Cross-Cutting Concerns

- **CON-2 blast-radius discipline** — P02, P03, P04, P07, P08. P02 is the ONLY phase that touches `auto-loop.sh`, with exactly one additive marker write. Every later phase lives at the entry/driver/hook layer; a requirement that forces a second `auto-loop.sh` change is amended by an explicit Decision row, never silently violated.
- **CON-5 fail-closed posture** — P04, P05, P08. P04 establishes the refuse-to-start pattern (caps unset → non-zero exit, in the driver not only CLI parse); P05's hook denies by default; P08 asserts the unsafe degrade (unattended without the hook) is impossible. Absence of a guarantee halts, never proceeds.
- **Atomic marker/ledger writes (temp+rename)** — P02 establishes the discipline; P04's SIGKILL paths depend on it (a kill mid-write must leave old-or-new, never torn); P07's attempts-ledger appends adopt the same pattern.
- **Non-stubbed milestone-blocking gates (Principle II)** — P02 (SC-9), P04 (SC-3), P05 (SC-5, SC-15), P06 (SC-11). A stub or golden-fixture substitute at implementation time is a Principle II violation that blocks closure regardless of spec-text quality (conversus arbiter ruling). SC-3's fixture must be cost-discriminating (duration held constant), SC-5 must include the MCP vector, SC-9 must run against the real `auto-loop.sh`.
- **FR-17 attended legacy parity** — P02, P03, P04. Attended Tier-C loop behavior stays byte-compatible with M045; the envelope wraps, never alters. P08 regression-asserts with goldens.
- **M021 shape-guard survival** — P01, P02, P04, P05, P07. Every new/modified script and the FR-9 hook must pass the PreToolUse bash shape-guard on the consumer install path; P01 proves the pattern for the deny-hook before P05 builds it.

## Dependency Graph

```
P01 ──┬─────────────→ P05 ─────────────┐
      │                                │
      └──→ P04 ──────→ P07 ────────────┤
           ↑              ↑            ├──→ P08
P02 ──────┴──────────────┘            │
P03 ──────→ P06 ───────────────────────┘
(P03 and P04 also feed P08 directly)
```

Edges: P01→{P04, P05}; P02→{P04, P07}; P03→{P06}; P04→{P07}; {P03, P04, P05, P06, P07}→P08. P01 is a decision gate (CON-6): its verdicts pick the FR-9 enforcement mechanism (P05) and the FR-7/FR-8 cost source (P04) before either builds.

## Execution Order

1. **P01 ∥ P02 ∥ P03** — all dependency-free, so risk orders them: P01 and P02 (both high) take priority; P03 (medium) can execute concurrently. P01 must reach a firm verdict before P04/P05 begin (decision gate).
2. **P04 ∥ P05** — both high-risk, both unlocked by P01 (P04 also needs P02). Can execute concurrently — disjoint surfaces (driver envelope vs. hook).
3. **P06** — unlocked by P03 alone; can run concurrently with P04/P05.
4. **P07** — after P02 + P04; consumes the live budget state the instruments expose.
5. **P08** — closure; after all of P03–P07.

## Open Questions (carried to plan-phase)

Corpus-exhaustion gate: **PASS** (`gates/corpus-exhaustion-roadmap.md`, 2026-07-12 — all 9 dispositioned `kept`, consistent with the discuss-time gate).

- **#Q-1, #Q-4 → P01** (resolved by the spike verdicts; #Q-4 is the SC-3 precondition)
- **#Q-2, #Q-3 → P03 plan-phase** (operator decisions: `--yes` broadening surface; `do` removal runway + gating release)
- **#Q-7 → P04 plan-phase** (wall-clock ceiling value/mechanism; always-on either way per CON-4)
- **#Q-5, #Q-6 → P06 plan-phase** (second-gate substrate; precision-floor protocol: independent measurer, corpus composition, floor hard-coding)
- **#Q-8, #Q-9 → P07 plan-phase** (ledger schema/retention/compaction; instrument surface reuse-vs-new)

## Validation

- **No conflicting producers: PASS** — each artifact has one producing phase. `self-continue-drive.sh` is modified by P02 (marker/injection hardening), P04 (unattended envelope layer), and P07 (ledger wiring), but these are strictly serialized by `Depends:` (P02 → P04 → P07), so no two phases produce into the same file concurrently and each phase's produced interface is distinct (marker contract / envelope / ledger+instruments).
- **All consumed items have producers: PASS** — P04 consumes P01's cost verdict + P02's wrapper (both produced upstream); P05 consumes P01's portability evidence; P06 consumes P03's entry; P07 consumes P02's driver + P04's lease state; P08 consumes P03–P07 outputs. External consumes (M024 classifier, M045 trio, M028 install path, M021 shape-guard, M019 JSONL, M042 corpus-gate) are shipped dependencies on `main`, verified present.
- **DAG is acyclic: PASS** — edges flow strictly P01/P02/P03 → P04/P05/P06 → P07 → P08; no back-edges.
- **Demo sentence coverage: PASS** — every phase carries a concrete, observable demo sentence tied to its SC fixtures (P01: evidence-doc verdicts; P02: marker correctness under kill; P03: three-way routing + shim parity; P04: mid-flight SIGKILL + fail-closed starts; P05: live four-vector deny; P06: pre-committed precision floor; P07: ledger replay + live instrument reads; P08: safe degrade + full battery).
