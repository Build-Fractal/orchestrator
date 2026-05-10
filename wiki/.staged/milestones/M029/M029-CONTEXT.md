---
schema_version: "1.0"
type: context-draft
milestone: "M029"
status: finalized
created_at: "2026-05-05T19:42:00Z"
finalized_at: "2026-05-05T20:26:16Z"
---

## Architectural Decisions

### AD-1 — Single-resolve invocation context (FR-1, Principle XI)

`scripts/state/detect-invocation-context.sh` is the single resolve-site for TTY / CI / runtime detection. Every M029 surface (`orchestrator:where`, `orchestrator:status` headline + `--format=json`, `orchestrator:context`, live-tail, preflight) reads the resolver's emitted env block at command entry and never re-derives. No surface grows its own ad-hoc detection logic. This is the load-bearing infrastructure decision; every later FR depends on it.

**Output shape (locked at this discussion)**: env block on stdout, `key=value` lines, fields:
- `renderer ∈ {tui, json, plain}`
- `exit_code_scheme ∈ {interactive, governance}`
- `default_provider` (passthrough from existing config; not new)

### AD-2 — JSON `sections` field is ANSI-stripped unconditionally (FR-3, #Q-G3 resolution)

**Decision**: When `orchestrator:status --format=json` runs, every string in the `sections` map is ANSI-stripped, **regardless of TTY**. This extends the resolver's non-TTY rule (auto-strip on pipe/CI) into JSON-format invocations universally.

**Rationale**: The JSON contract has consumers (CI, GitHub Actions, `external-tool-adapters`, `jq` filters) who never want escape sequences in field values. The TTY split adds complexity for zero benefit — a developer running `--format=json` interactively still wants clean strings to pipe into `jq`. Picking the simpler invariant now avoids a contract migration later when [M035](../../milestones/M035/index.md) ships the schema as a public surface.

**Rejected alternative**: Schema-separated `raw_sections` + `rendered_sections`. Doubles the payload, complicates `external-tool-adapters` consumers (#Q-4 schema-stability scope), and provides no value the resolver doesn't already cover (a TTY consumer can run `orchestrator:status` without `--format=json` to get colored output).

**Implementation note for plan-phase P01**: The ANSI strip lives in the JSON renderer, not in the section producers — the existing markdown sections still emit ANSI for the legacy flat-section path. One strip site, in `scripts/diagnostics/render-status-json.sh` (or wherever the JSON serialization lands).

### AD-3 — Preflight non-interactive policy (FR-9, #Q-G1 resolution)

**Decision**: The `orchestrator:auto` preflight summary at Standard / Full intensity respects [M031](../../milestones/M031/index.md)'s `auto_proceed: true` config flag and an explicit `--yes` flag, in priority order:

1. **`--yes` flag present** → emit the preflight block on stderr, do not prompt, proceed.
2. **`auto_proceed: true` in config** (M031 default since the AD-9 compound-change banner work) → emit the preflight block on stderr, do not prompt, proceed. The compound-change banner (`run-doctor.sh`) already informs the operator that auto-proceed is active.
3. **Non-TTY stdin (CI, piped)** with neither flag/config → emit the preflight block on stderr, then exit non-zero with the byte-stable string `M029_PREFLIGHT_NEEDS_CONFIRMATION` on stderr. CI consumers must explicitly opt in via `--yes` or `auto_proceed: true`. **No silent auto-accept in CI.**
4. **TTY + neither flag/config** → emit the preflight block, prompt for confirmation, block on the prompt.

**Rationale**: Auto-accept under `--yes` follows POSIX convention; auto-accept under `auto_proceed=true` honors M031's deliberate flip-gate (the compound-change banner already covers operator surprise). Refusing to auto-accept silently in plain non-TTY mode preserves the safety property M031's banner work was designed to establish — silent CI auto-accept would launder the banner's intent.

**Rejected alternatives**:
- Skip the preflight under non-interactive: defeats the SC-9 contract (Quick=no preflight, Standard/Full=preflight) and hides cost from CI logs where it would be most useful.
- Auto-accept under `auto_proceed=true` only (no `--yes`): conflicts with POSIX `--yes` convention and forces every CI consumer to wire config rather than flag.

**SC-8 / SC-9 implications**: SC-9 already asserts "stderr does not contain `Preflight Summary` before `AUTO:READY`" at Quick — that holds. SC-8's auto-accept fixture must be re-shaped to set `--yes` (or `auto_proceed: true`) explicitly; resolve in P03 plan-phase.

### AD-4 — SC-8 oracle interface amendment (#Q-G2 resolution)

**Verified at this discussion**: `scripts/dispatch/predictive-surface.sh` does **NOT** accept `--milestone <M###>`. The shipped surface is `--description <text> --intensity quick|standard|full [--no-predict] [--yes] [--config-defaults <path>]`. SC-8's oracle as written cannot be satisfied byte-identically.

**Decision**: Amend SC-8 to use the actual [M027](../../milestones/M027/index.md) surface; **do not** extend M027 (that would breach the knowledge-layer boundary in CON-3 and the M027-is-closed assumption in A-1).

**Amended SC-8 oracle shape (apply at P03 plan-phase, capture in spec amendment record)**:

The M029 preflight block's `predicted_cost` field is byte-identical to the cost field of:
```
bash scripts/dispatch/predictive-surface.sh \
  --description "$(bash scripts/diagnostics/summarize-milestone.sh M###)" \
  --intensity standard \
  --no-predict
```
where `summarize-milestone.sh` is a new **read-only** M029 helper under `scripts/diagnostics/` that emits a deterministic milestone summary (phase count + remaining task count + intensity from evaluation). The helper is in M029's write claim (knowledge-layer boundary preserves: it composes existing surfaces; emits a string; no schema additions).

**Rejected alternative**: Extend `predictive-surface.sh` with `--milestone`. That violates Principle XV (Surgical Precision) and the M029 knowledge-layer boundary; M027 is closed.

### AD-5 — Compression-savings 5% threshold is config-knob with documented heuristic default (FR-8, #Q-G4 resolution)

**Decision**: The 5% threshold ships as `display_thresholds.compression_savings_pct: 5.0` in `.orchestrator/config.yml` (new sub-key under existing `display_thresholds:` block, or new block if absent). FR-8's render path reads the config; the documented default is 5.0 with a docstring annotation: *"Starting heuristic. Tune after first 10 milestones of [M019](../../milestones/M019/index.md) Tier 1 + [M018](../../milestones/M018/index.md) Tier 2 telemetry. Review trigger: re-evaluate threshold once `metrics-rollup.sh --scope milestone` shows median savings ≥ 3% across closed milestones."*

**Rationale**: Picks the union of options (b) + (c). Annotating as a heuristic without a knob forces a code change to tune; making it a knob without documenting why 5% locks in the unmotivated number forever. The combined shape gives operators a tunable surface today and a documented review trigger when the data arrives.

**Rejected alternatives**:
- Cite measured evidence (option a): no measurement exists yet; M018 Tier 2 telemetry is too young. Honest answer: heuristic.
- Annotate-only (option b): forces code change to tune. Lower velocity.
- Knob-only (option c): no review-trigger documentation; the 5% sticks forever.

**Implementation cost**: Trivial — config plumbing already exists per M027's six suppression knobs (`efficiency_footer`, etc.). Add one entry to `references/file-formats.md` documenting the `display_thresholds:` block.

### AD-6 — Cross-milestone feature data model: explicit frontmatter list with reverse-lookup validation (FR-13, #Q-G5 resolution)

**Decision**: Adopt option (a) — feature-spec frontmatter lists milestones explicitly — as the **canonical** data model, with option (b) (reverse-lookup via `M###-EVALUATION.md`'s `feature_ref` field) as a **validation cross-check** at render time.

**Schema addition (one field, additive — does not break existing specs)**:
- New optional frontmatter field on `type: feature-spec`: `milestones: [M###, M###]` (list).
- Existing singular `milestone:` field stays for backward compatibility. When `milestones:` is present, it is authoritative; when absent, the renderer treats `milestone:` as a single-element list.
- Spec `033-reference-corpus-ingest/spec.md` (the only existing multi-milestone spec, currently `milestone: "[M036](../../milestones/M036/index.md) (split: M036a pre-launch, M036b post-launch — see Amendment Record)"`) is the migration test case — it gets `milestones: [M036a, M036b]` added, but the migration is **out of scope for M029**. M029 only needs to handle the schema; spec 033's migration lands when M036b enters planning.

**Reverse-lookup as validation**: At render time, `orchestrator:where` enumerates `.orchestrator/milestones/M*/M*-EVALUATION.md`, groups by `feature_ref`, and asserts the feature-spec's `milestones:` list matches the reverse-lookup set. Mismatch emits a warning to stderr (not a hard error — the spec frontmatter is the source of truth per Principle XI; reverse-lookup is a sanity check).

**Inactive-milestone rendering shape (#Q-5 from spec, deferred to P02 plan-phase)**: collapsed by default, `--expand-all` to override. Recommendation captured here, locked at P02.

**Rejected alternatives**:
- (b) reverse-lookup only: violates Principle XI (the EVALUATION.md is a derived artifact, not the source). The feature spec is the authoritative source.
- (c) external manifest: introduces a third source of truth and a sync burden. Rejected per Principle XV.

### AD-7 — JSON schema versioning from day 1 (#Q-4 resolution)

**Decision**: `references/status-json-schema.md` declares `schema_version: "1.0"` from day 1. The schema is a public contract (M035 packaging post-install verification + post-launch `external-tool-adapters`). Future field additions are non-breaking under semver-style minor bumps; field removals or type changes require a major bump and a deprecation cycle.

**Rationale**: Confirmed per Principle XV (Surgical Precision) and the spec's own recommendation. Locking this in now costs nothing; deferring it forces a contract migration later when M035 ships.

**Concrete shape for P01 plan-phase**: schema docfile carries top-level `schema_version: "1.0"`; the JSON output emitted by `orchestrator:status --format=json` carries a `schema_version: "1.0"` top-level key. Two surfaces, same string, single source of truth in `references/status-json-schema.md`.

### AD-8 — Knowledge-layer boundary discipline (CON-1, FR-14, knowledge-layer-boundary section)

M029 is composition over closed surfaces. Specifically:

- **No** new JSONL event types (M019 owns)
- **No** extension to KNOWLEDGE.md schema ([M020](../../milestones/M020/index.md) owns)
- **No** changes to M027 surfaces (`metrics-rollup.sh`, `efficiency-footer.sh`, `predictive-surface.sh`) — M029 is a read-only consumer
- **No** changes to [M013](../../milestones/M013/index.md)'s GitHub sidecar schema (FR-11/FR-12 explicitly cut deeper integration)

M029's write claim, locked at this discussion:
- New: `scripts/state/detect-invocation-context.sh` (read-only)
- New: `scripts/diagnostics/render-position.sh` (read-only)
- New: `scripts/diagnostics/render-status-json.sh` (read-only; emits JSON to stdout)
- New: `scripts/diagnostics/summarize-milestone.sh` (read-only; for AD-4 SC-8 oracle wrapper)
- New: `commands/where.md`, `commands/context.md`
- Modified additively: `commands/status.md`, `commands/auto.md`, `commands/start.md`
- New: `references/status-json-schema.md`, `references/status-headline-shape.md`
- New: `tests/m029-acceptance/` (fixtures + battery)
- Marker writes (the only write-site exception): `.orchestrator/start-state/<stage>.complete` per FR-10 / SC-10

## Scope Boundaries

### In scope (locked at this discussion)

- `scripts/state/detect-invocation-context.sh` — single-resolve invocation context (FR-1)
- `orchestrator:status` headline block embedding M027 efficiency-footer (FR-2)
- `orchestrator:status --format=json` with versioned schema (FR-3, AD-2, AD-7)
- `orchestrator:context` read-only debug skill (FR-4)
- `orchestrator:where` at-rest tree renderer with cost column (FR-5)
- Pre-M019 graceful degradation on cost column (FR-6)
- `orchestrator:where --live` tail-mode (FR-7)
- Compression-savings `▽` marker with config-knob threshold (FR-8, AD-5)
- `orchestrator:auto` preflight summary at Standard/Full with non-interactive policy (FR-9, AD-3)
- `--auto-chain` flag on `orchestrator:start` with marker-file resume (FR-10)
- Cross-milestone feature data model: explicit `milestones:` frontmatter list with reverse-lookup validation (FR-13, AD-6)
- Read-only discipline (FR-14, CON-1)
- M029 acceptance battery covering all 14 SCs (SC-11)
- `validate-milestone.sh M029` 100% pass + M029-VALIDATED marker (SC-12)
- Anti-coupling guard against GitHub fold-in in headline path (SC-13)
- Read-only guard via sentinel-file mtime (SC-14, AD-9 below)

### Explicitly out of scope (preserved from spec)

- GitHub fold-in line in `where` headline (FR-11) — cut per 2026-05-05 scope tightening
- `--refresh-github` flag (FR-12) — cut per 2026-05-05 scope tightening
- Deeper GitHub Projects v2 / Issues / dashboard surface area — defers to demand-driven post-launch `external-tool-adapters`
- Web UI / persistent dashboard — wiki ([M032](../../milestones/M032/index.md)) is the long-form view
- Watcher daemon / background process for `--live` — foreground only
- Rich/TUI library binding — bash + ANSI sufficient
- Replacing `orchestrator:status` (the flat-section view stays unchanged byte-for-byte beneath the new headline)
- Modifying `auto-loop.sh` — M029 reads what auto emits; it does not change auto's loop driver
- New aggregator over M019 / M027 — composes only, no new aggregation
- Extending `predictive-surface.sh` with `--milestone` (AD-4) — out of scope, breaches knowledge-layer boundary
- Spec 033's `milestones:` frontmatter migration (AD-6) — defers to M036b planning entry
- Live-LLM smoke test for M036a P03 — separate parallel pre-launch workstream tracked at the roadmap level, not an M029 dependency

### Operational follow-ups (parallel, not gating)

- [M033](../../milestones/M033/index.md) friendly-tester pass deadline ≤ 2026-05-12 per launch-sequencing-amendment Q-1 (`tests/m033-acceptance/friendly-tester-pass/protocol.md`) — runs alongside M029; not a dependency.
- M036a P03 live-LLM smoke test before 2026-05-08 — parallel pre-launch workstream; not an M029 dependency.

## Design Constraints

### CON-1 (read-only) — preserved from spec
All render paths are read-only. The only M029 write site is `--auto-chain`'s marker files under `.orchestrator/start-state/`. Verified by SC-14.

### CON-2 (bash + ANSI only) — preserved from spec
No new runtime dependencies. `tput` / ANSI escapes only. Live-tail uses `tail -f` (POSIX). Auto-strip ANSI when not TTY (per FR-1's resolver and AD-2's JSON rule).

### CON-3 (cost-column-graceful-degradation) — preserved from spec
Pre-M019 milestones: cost column omitted silently. No stderr warning, no blank column. Verified by SC-6.

### CON-4 (no-github-api-on-render) — preserved from spec
The render path never invokes `gh` or any GitHub HTTP API. M013 sidecar reads remain confined to the unchanged `orchestrator:github-status` / `orchestrator:github-sync` skills. Verified by SC-13.

### CON-5 (suppression-matrix-honored) — preserved from spec
M027's six suppression knobs propagate transparently. M029 does NOT introduce its own suppression knobs (AD-5's `display_thresholds.compression_savings_pct` is a threshold, not a suppression).

### CON-6 (live-tail-latency) — preserved from spec
≤1 second from JSONL append to render. POSIX `tail -f` only. Verified by SC-7 with the methodology #Q-G9 captures (deferred to P03 plan-phase).

### CON-7 (knowledge-layer-boundary) — added at this discussion
M029 composes over closed M013/M018/M019/M020/M027 surfaces. Each new helper or render path stays within the write claim enumerated in AD-8. Schema additions are confined to:
- `feature-spec` frontmatter: optional `milestones:` list (AD-6)
- `.orchestrator/config.yml`: optional `display_thresholds.compression_savings_pct` knob (AD-5)
- `references/status-json-schema.md` (new file, M029-owned)
- `references/status-headline-shape.md` (new file, M029-owned)

No other schema additions are permitted in M029. Plan-phase task plans must explicitly reject any task that touches an out-of-claim file.

### AD-9 (sentinel-file mechanism for SC-14, #Q-G7 P1 captured here for plan-phase reference)

The SC-14 read-only enforcement uses a **sentinel file** approach, not raw mtime:
1. Before invoking the render path, write `.orchestrator/.m029-sc14-sentinel` with the current ISO-8601 timestamp.
2. Run the render command.
3. Compare the sentinel's mtime to the recorded value; assert no `.orchestrator/` file (excluding the sentinel itself and the `.orchestrator/start-state/<stage>.complete` markers when `--auto-chain` is the unit under test) has an mtime newer than the sentinel.
4. The mtime granularity gap (HFS+ 1-second, APFS sub-second varies) is closed because the sentinel write happens immediately before the read, not at test-suite startup.

Captured here at discuss-time even though #Q-G7 is P1 because the mechanism shape is structural and informs SC-14's fixture design at P02 plan-phase.

## Open Questions

### P0 items — resolved at this discussion

- **#Q-G1 (FR-9 non-interactive behavior)** → resolved AD-3.
- **#Q-G2 (SC-8 oracle interface)** → resolved AD-4: SC-8 amended to use shipped `predictive-surface.sh` surface with M029-owned `summarize-milestone.sh` wrapper. Spec amendment record entry to be added at P03 plan-phase.
- **#Q-G3 (FR-3 ANSI in JSON `sections`)** → resolved AD-2: ANSI-stripped unconditionally in JSON mode regardless of TTY.
- **#Q-G4 (FR-8 5% threshold rationale)** → resolved AD-5: config-knob with documented heuristic default + review trigger.
- **#Q-G5 (FR-13 cross-milestone data model)** → resolved AD-6: explicit `milestones:` frontmatter list with reverse-lookup validation.
- **#Q-4 (json-schema-stability-policy)** → resolved AD-7: `schema_version: "1.0"` from day 1 in both schema doc and JSON output.

### P1 items — captured here, decision shape locked, resolution executed at plan-phase

- **#Q-G6 (SC-5 timestamp-exclusion enumeration)** → resolve at P02 plan-phase. Decision shape: enumerate exact regex patterns. Provisional list to be confirmed at P02: ISO-8601 timestamps (`\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z`), epoch-seconds in dispatch_id contexts (`\\b1[6-9]\\d{8}\\b`), `last_dispatch:` recency phrasing (`\\d+[smhd] ago`).
- **#Q-G7 (SC-14 sentinel-file mechanism)** → resolved at this discussion via AD-9 (decision shape locked); fixture implementation at P02 plan-phase.
- **#Q-G8 (FR-8 marker canonical form)** → resolve at P02 plan-phase. Decision shape: nominate `▽ saved Nk` as the canonical compact form. Verbose form (`▽ saved Nk via tier1 cache reuse`) lives in tooltip / `--verbose` mode if added later. Apply consistently across spec body, fixtures, and golden render.
- **#Q-G9 (SC-7 latency methodology)** → resolve at P03 plan-phase. Decision shape: p95 ≤ 1.0s as the assertion threshold; harness records p99 as informational; retry policy = no retry on individual measurements (flake-on-first-fail surfaces drift); if p95 measurements show drift beyond 1.5s during P03, escalate to a hard SC tightening with a new RISK-tracked finding.

### P2/P3 spec items — note only; resolve when applicable

- **#Q-1 (live-tail-redraw-strategy)** → resolve at P03 plan-phase. Recommendation in spec stands: full re-render, no incremental row update.
- **#Q-2 (preflight-cost-format)** → resolve at P03 plan-phase. Recommendation in spec stands: range (`est. ~$X.Y ± $Z.Z`) since `predictive-surface.sh` already emits the confidence interval.
- **#Q-3 (auto-chain-failure-recovery)** → resolve at P03 plan-phase. Recommendation in spec stands: leave marker absent; re-runs re-execute the failed stage; surface via `orchestrator:status`.
- **#Q-5 (cross-milestone-inactive-render-shape)** → captured in AD-6 (collapsed by default, `--expand-all` override); fixture at P02.

## Phase Decomposition Preview (informational, for `orchestrator:roadmap`)

The spec's brief implies three phases. With AD-1..AD-9 locked, the suggested decomposition for `orchestrator:roadmap` to formalize:

- **P01 — Resolver + Status Headline + `--format=json`** (US-1, US-2; FR-1, FR-2, FR-3; AD-1, AD-2, AD-7). Design contracts authored first per Principle III: `references/status-headline-shape.md`, `references/status-json-schema.md`. Then `detect-invocation-context.sh`, headline block, JSON renderer, `orchestrator:context` debug skill (FR-4 lands here as a small additional surface). SC-1 through SC-4 + part of SC-11.
- **P02 — `orchestrator:where` at-rest tree + cost column + cross-milestone data model** (US-3; FR-5, FR-6, FR-13; AD-6). Includes the `milestones:` frontmatter schema addition, `summarize-milestone.sh` helper (per AD-4), reverse-lookup validation, mixed-state golden fixture. SC-5, SC-6, SC-13, SC-14 fixture (sentinel mechanism per AD-9); part of SC-11.
- **P03 — Live-tail + compression-savings marker + auto preflight + `--auto-chain`** (US-4, US-5, US-6; FR-7, FR-8, FR-9, FR-10; AD-3, AD-4 SC-8 amendment, AD-5). Latency methodology lands here (#Q-G9). Spec amendment record entry for SC-8 oracle. Marker-file resume convention. SC-7, SC-8, SC-9, SC-10 + remainder of SC-11; SC-12 closure.

The roadmap command is the authoritative decomposition site; this preview exists only to make the AD locks legible in their phase context.
