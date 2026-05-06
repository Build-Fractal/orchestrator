---
schema_version: "1.0"
type: roadmap
milestone: "M029"
feature_ref: "037-roadmap-visibility-cli-ux"
feature_spec: "specs/037-roadmap-visibility-cli-ux/spec.md"
vision: "Compose existing M013/M018/M019/M027 surfaces into a glanceable tree view, a structured JSON contract, and a resumable entry chain — read-only, bash+ANSI only, with the wiki as the launch project-management surface."
tier: "C"
created_at: "2026-05-05T20:30:00Z"
updated_at: "2026-05-05T20:30:00Z"
---

## Phases

- [x] **P01**: Resolver foundation + status headline + JSON contract + context skill — "A developer running `orchestrator:status` against the SC-2 fixture sees a 3-line headline embedding the M027 efficiency-footer; running it with `--format=json` emits a `schema_version: \"1.0\"` payload validating against `references/status-json-schema.md`; `orchestrator:context` prints a single-screen runtime profile."
  - Risk: high
  - Depends: none
  - Boundary Map:
    - Produces:
      - `scripts/state/detect-invocation-context.sh` — single-resolve env-block emitter with `renderer ∈ {tui,json,plain}`, `exit_code_scheme ∈ {interactive,governance}`, `default_provider` (AD-1, FR-1)
      - `references/status-headline-shape.md` — design contract authored before code per Principle III (RISK-7 / MIT-10)
      - `references/status-json-schema.md` — design contract carrying `schema_version: "1.0"` (AD-7, FR-3)
      - `scripts/diagnostics/render-status-json.sh` — JSON renderer; `sections` field ANSI-stripped unconditionally (AD-2)
      - Headline block prepended to `commands/status.md` (FR-2); flat-section body byte-identical to today
      - `--format=json` flag wired into `commands/status.md` (FR-3); JSON output carries top-level `schema_version: "1.0"`
      - `commands/context.md` — new `orchestrator:context` skill (FR-4); single screen ≤24 lines on 80×24
      - Fixtures `tests/m029-acceptance/fixtures/status-headline-{state}.fixture` and `tests/m029-acceptance/fixtures/status-json-{state}.fixture` covering SC-1, SC-2, SC-3, SC-4
    - Consumes:
      - M027 `scripts/diagnostics/efficiency-footer.sh` (read-only; embedded verbatim in headline per FR-2)
      - M027 `efficiency_footer` config knob (suppression matrix per CON-5)
      - `scripts/state/find-active-milestone.sh` (existing; identifies the active milestone for the headline)
      - `scripts/state/derive-phase.sh` (existing; phase index + percent for the headline)
      - Lock-manager state at `.orchestrator/global/lock.json` (existing read; for headline lock-state line)

- [x] **P02**: `orchestrator:where` at-rest tree + cost column + cross-milestone data model + read-only sentinel — "A developer running `orchestrator:where` against the SC-5 mixed-state fixture sees a tree with the documented glyph set, M027-sourced per-row cost column, milestone progress bar, and the `where-mixed-state.golden` byte-identical render (modulo enumerated timestamp patterns); a pre-M019 milestone renders without the cost column and without stderr noise; the SC-14 sentinel-file harness asserts no `.orchestrator/` mutation."
  - Risk: medium
  - Depends: P01
  - Boundary Map:
    - Produces:
      - `scripts/diagnostics/render-position.sh` — at-rest tree renderer reading roadmap, execution log, lock manager (FR-5; pure read)
      - `commands/where.md` — new `orchestrator:where` skill definition
      - `scripts/diagnostics/summarize-milestone.sh` — read-only deterministic milestone summary helper (phase count + remaining task count + intensity from evaluation); produced here for cohesion with the cross-milestone data model, consumed by P03's SC-8 oracle wrapper (AD-4)
      - `feature-spec` frontmatter schema additive change: optional `milestones: [M###, ...]` list (AD-6, FR-13); existing singular `milestone:` retained for backward compatibility
      - Reverse-lookup validator path inside `render-position.sh` — enumerates `.orchestrator/milestones/M*/M*-EVALUATION.md`, groups by `feature_ref`, emits stderr warning on mismatch with the spec frontmatter (not a hard error per Principle XI; spec is authoritative)
      - Pre-M019 graceful-degradation branch (FR-6, CON-3): cost column omitted silently; no stderr warning
      - `tests/m029-acceptance/fixtures/where-mixed-state.golden` — byte-stable golden render covering all four glyph states (`✓ ▶ ◇ ✗`)
      - `tests/m029-acceptance/fixtures/where-pre-m019.fixture` — pre-M019 milestone fixture for SC-6
      - `tests/m029-acceptance/sentinel-harness.sh` — sentinel-file mechanism per AD-9; baseline for SC-14
      - `tests/m029-acceptance/timestamp-strip.sh` — enumerated regex patterns for SC-5 golden-render comparison (#Q-G6 resolution at this phase): ISO-8601 timestamps, epoch-seconds, `\d+[smhd] ago` recency phrasing
      - Anti-coupling guard fixture for SC-13: `grep -r '/integrations/github' specs/037-roadmap-visibility-cli-ux/ scripts/diagnostics/render-position.sh` returns no match
    - Consumes:
      - P01's `scripts/state/detect-invocation-context.sh` (AD-1 single-resolve)
      - M027 `scripts/diagnostics/metrics-rollup.sh --scope task` (read-only; per-row cost column source)
      - M019 `execution-log.jsonl` schema (read-only; for status glyph derivation)
      - Roadmap parser `scripts/state/read-roadmap.sh` (existing)
      - `tests/m029-acceptance/sentinel-harness.sh` — produced and self-consumed within the phase for SC-14 coverage of P02's own writes

- [ ] **P03**: Live-tail + compression-savings marker + auto preflight + `--auto-chain` + acceptance battery + close — "A developer running `orchestrator:where --live` sees the tree update within 1 second of a `dispatch_usage` append, with a `▽ saved Nk` marker on rows whose savings exceed the configured threshold; `orchestrator:auto` at Standard intensity emits a preflight block whose `predicted_cost` is byte-identical to the AD-4 oracle wrapper output; `orchestrator:start --auto-chain` walks `evaluate → discuss → roadmap → plan-phase` writing marker files and resumes from the next incomplete marker after interruption; the M029 acceptance battery emits `BATTERY: pass=14 fail=0`; `validate-milestone.sh M029` reports 100% pass and the `M029-VALIDATED` marker is on disk."
  - Risk: medium
  - Depends: P02
  - Boundary Map:
    - Produces:
      - `--live` branch added to `scripts/diagnostics/render-position.sh` (FR-7; POSIX `tail -f`; full re-render per #Q-1 spec recommendation; methodology per #Q-G9: p95 ≤ 1.0s, p99 informational, no per-measurement retry, escalate to hard SC tightening if p95 drifts beyond 1.5s)
      - Compression-savings `▽` marker rendering (FR-8); canonical form `▽ saved Nk` per #Q-G8 resolution; verbose form deferred to optional `--verbose` mode
      - `.orchestrator/config.yml` schema additive change: optional `display_thresholds.compression_savings_pct: 5.0` knob (AD-5); documented in `references/file-formats.md` with the heuristic-default annotation + review trigger
      - Preflight summary block prepended to `commands/auto.md` for Standard/Full intensity (FR-9, AD-3); non-interactive policy: `--yes` > `auto_proceed: true` > non-TTY refusal with `M029_PREFLIGHT_NEEDS_CONFIRMATION` byte-stable string > TTY prompt; suppressed entirely at Quick intensity per SC-9
      - SC-8 oracle wrapper invocation: `bash scripts/dispatch/predictive-surface.sh --description "$(bash scripts/diagnostics/summarize-milestone.sh M###)" --intensity standard --no-predict` (AD-4); spec amendment record entry added at SC-8 (RISK-2 / `#Q-G2` resolved)
      - `--auto-chain` flag in `commands/start.md` (FR-10); marker writes at `.orchestrator/start-state/<stage>.complete` — the only M029 write site outside test fixtures
      - Marker-file resume convention; failed stages leave marker absent (per #Q-3 spec recommendation), surfaced via `orchestrator:status`
      - Preflight cost format: range `est. ~$X.Y ± $Z.Z` per #Q-2 spec recommendation
      - `tests/m029-acceptance/run-acceptance-battery.sh` — full battery covering SC-1..SC-14, emitting `BATTERY: pass=14 fail=0` per SC-11
      - `tests/m029-acceptance/measure-live-tail-latency.sh` — latency harness implementing the #Q-G9 methodology
      - `tests/m029-acceptance/fixtures/auto-preflight-{standard,quick}.fixture` for SC-8 / SC-9
      - `tests/m029-acceptance/fixtures/auto-chain-greenfield.fixture` for SC-10
      - Spec amendment record entry in `specs/037-roadmap-visibility-cli-ux/spec.md` documenting the SC-8 oracle interface change (AD-4)
      - `M029-VALIDATED` marker (per `validate-milestone.sh M029` 100% pass, SC-12)
      - `M029-SUMMARY.md` — milestone closure summary
      - Milestone-grain `unit_close` event emitted to `execution-log.jsonl` (consumes existing M019 emitter; produces no new event type per CON-7)
    - Consumes:
      - P02's `scripts/diagnostics/render-position.sh` (extended in-place with `--live` branch, not duplicated)
      - P02's `scripts/diagnostics/summarize-milestone.sh` (used by SC-8 oracle wrapper)
      - P01's `scripts/state/detect-invocation-context.sh` (TTY detection drives AD-3 non-interactive policy)
      - M019 `execution-log.jsonl` `dispatch_usage` schema (read-only)
      - M018 `payload_breakdown.tier1_savings_tokens` and `tier2_savings_tokens` fields (read-only; FR-8)
      - M027 `scripts/dispatch/predictive-surface.sh` (read-only; called via the AD-4 wrapper)
      - M031 `auto_proceed: true` config flag (read-only; AD-3 non-interactive policy)
      - M033 `orchestrator:start` entry-chain stages (read-only invocations from `--auto-chain`)
      - `validate-milestone.sh` (existing tooling; SC-12)

## Cross-Cutting Concerns

- **Single-resolve invocation context (AD-1, FR-1, Principle XI)** — P01 produces; P02 and P03 consume. Every command surface (where, status, context, --live, preflight, auto-chain) reads `detect-invocation-context.sh`'s emitted env block at command entry; no surface re-derives. Plan-phase task plans for P02 and P03 must reference the resolver's env block, not re-invoke detection logic.
- **ANSI-strip discipline (AD-2)** — P01 establishes the contract: JSON `sections` field is ANSI-stripped unconditionally regardless of TTY; the legacy markdown flat-section path retains ANSI for TTY consumers. P02's tree renderer and P03's live-tail honor the resolver's `renderer` field for ANSI control. One strip site (in the JSON renderer); the existing markdown emitters do not change.
- **Knowledge-layer boundary (CON-7, AD-8)** — applies to all three phases. Every plan-phase task plan must explicitly reject any task that would touch out-of-claim files (M013 sidecar schema, M019 JSONL event types, M020 KNOWLEDGE.md schema, M027 surfaces). Schema additions are confined to `feature-spec` `milestones:` list (P02), `display_thresholds.compression_savings_pct` knob (P03), and the two new `references/*.md` design contracts (P01).
- **Read-only discipline (CON-1, FR-14)** — P01 and P02 produce render paths that never mutate `.orchestrator/`. P03 introduces the only write site (the `--auto-chain` markers under `.orchestrator/start-state/`) and the M029-VALIDATED marker. SC-14 enforcement uses the AD-9 sentinel-file mechanism (produced in P02, consumed by all three phases' SC fixtures).
- **JSON schema versioning policy (AD-7)** — P01 establishes `schema_version: "1.0"`. M035 packaging consumes downstream as a public surface; post-launch `external-tool-adapters` will too. Future additions are non-breaking under semver-style minor bumps; field removals or type changes require a major bump and a deprecation cycle.
- **Suppression matrix inheritance (CON-5)** — P01's headline embeds M027's `efficiency-footer.sh` line; P02's tree consumes M027's `metrics-rollup.sh`; P03's preflight consumes M027's `predictive-surface.sh`. M029 does NOT introduce its own suppression knobs. M027's six knobs (`efficiency_footer`, etc.) propagate transparently. AD-5's `display_thresholds.compression_savings_pct` is a *threshold*, not a suppression.
- **Bash + ANSI only (CON-2)** — applies to all three phases. No Python, Rich, ncurses, fswatch, inotify. Live-tail uses POSIX `tail -f`. Plan-phase task plans must reject any task introducing a non-portable runtime dependency.
- **Live-tail latency methodology (#Q-G9)** — P03 produces `measure-live-tail-latency.sh`; assertion threshold p95 ≤ 1.0s; p99 informational; no per-measurement retry; escalation trigger if p95 measurements drift beyond 1.5s during P03 — escalate to a hard SC tightening with a new RISK-tracked finding before close.

## Dependency Graph

```
P01 ──► P02 ──► P03
```

Three nodes, two edges. Strictly sequential — no parallelism. P02 cannot start before P01 because the resolver and JSON renderer are load-bearing for the tree's `--format=json` output and for SC-13/SC-14's read-only-guard fixtures. P03 cannot start before P02 because the live-tail extends `render-position.sh` in-place and the SC-8 oracle wrapper consumes `summarize-milestone.sh`.

## Execution Order

1. **P01** — foundation, no dependencies. Produces resolver + design contracts + status headline + JSON renderer + context skill. The two design contracts (`references/status-headline-shape.md`, `references/status-json-schema.md`) **must** be authored as the first plan-phase deliverables, before any FR-2/FR-3 implementation task opens, per Principle III + RISK-7 / MIT-10.
2. **P02** — depends on P01. Produces the at-rest tree renderer, cross-milestone data model, sentinel-file mechanism, and golden render. Cannot run before P01 (consumes resolver + JSON contract); cannot run concurrently (the tree's JSON output reuses P01's renderer).
3. **P03** — depends on P02. Produces live-tail extension, savings marker, preflight, `--auto-chain`, full acceptance battery, milestone closure. Cannot run before P02 (extends `render-position.sh` in-place; consumes `summarize-milestone.sh`).

No phases can execute concurrently in v1. The Tier C autonomous-dispatch loop will schedule P01 → P02 → P03 strictly sequentially.

## Validation

- **No conflicting producers**: PASS. `scripts/diagnostics/render-position.sh` is produced once in P02 and *extended in place* in P03 (the `--live` branch); not a duplicate produce. All other artifacts (resolver, JSON renderer, summarize-milestone, where/context commands, preflight summary, --auto-chain, fixtures, design contracts) are produced exactly once across the three phases.
- **All consumed items have producers**: PASS. P02's consumes resolve to P01 (resolver) or closed milestones (M027 `metrics-rollup.sh`, M019 `execution-log.jsonl`). P03's consumes resolve to P02 (`render-position.sh`, `summarize-milestone.sh`), P01 (resolver), or closed milestones (M018 `payload_breakdown`, M019 `dispatch_usage`, M027 `predictive-surface.sh`, M031 `auto_proceed`, M033 `orchestrator:start`).
- **DAG is acyclic**: PASS. Three nodes, two edges, strictly linear: P01 → P02 → P03. No cycles possible with this shape.
- **Demo sentence coverage**: PASS. Each phase's demo sentence is concrete and observable: P01 demo reads against the SC-2 fixture and checks regex + JSON-schema validation; P02 demo checks byte-identical-modulo-timestamps against `where-mixed-state.golden` and pre-M019 silent omission; P03 demo checks live-tail latency, preflight byte-identicality, marker-file ordering, battery `pass=14 fail=0`, and `M029-VALIDATED` marker presence.
