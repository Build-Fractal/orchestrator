---
schema_version: "1.0"
type: feature-spec
feature_slug: "037-roadmap-visibility-cli-ux"
created_at: "2026-05-05"
status: "Draft"
milestone: "M029"
---

# Feature Specification: 037-roadmap-visibility-cli-ux

**Feature Branch**: `037-roadmap-visibility-cli-ux`
**Created**: 2026-05-05
**Status**: Draft
**Milestone**: M029
**Input**: User description: "Roadmap visibility & CLI UX (M029): ship orchestrator:where — a tree renderer that surfaces the work hierarchy from milestone → phase → task → current dispatch — together with an invocation-context resolver, a headline block in orchestrator:status that embeds the existing M027 efficiency footer, a debug orchestrator:context skill, and --format=json on status. P02 adds the at-rest tree renderer with token/cost columns sourced from M027 metrics-rollup. P03 adds live-tail mode tailing execution-log.jsonl with a compression-savings marker on dispatch_usage records, plus an opt-in auto preflight summary that invokes predictive-surface.sh, and an --auto-chain flag for orchestrator:start that chains evaluate→discuss→roadmap→plan-phase with explicit user gates and marker-file resume. Scope tightened 2026-05-05 to wiki-is-the-view: NO GitHub fold-in line in where headline, NO --refresh-github flag, NO deeper GitHub Projects v2 surface area (deferred to demand-driven external-tool-adapters post-launch). Pure composition over existing M013/M018/M019/M027 surfaces; read-only; bash+ANSI only (no Rich/TUI dep)."

## Problem Statement

An `orchestrator:auto` run today emits exit-code markers (`AUTO:READY`, `AUTO:PHASE_COMPLETE`) and JSONL append events; the watching developer has no single rendering that answers "where am I in the work hierarchy, and what is happening right now?" The information already exists on disk — M019 Tier 1 emits `dispatch_usage` / `payload_breakdown` records, M013's sidecar maps state to GitHub artifacts, M027 has `efficiency-footer.sh` / `metrics-rollup.sh` / `predictive-surface.sh` for cost+quality observability, and `derive-phase.sh` resolves the active state cursor. None of those surfaces is composed into a glanceable tree view.

Three concrete pain-points follow. First, a developer joining an in-flight `auto` run must scrub `git log` plus scroll-back plus invoke `orchestrator:status` to reconstruct phase/task position; the latency between "is this on track?" and an answer is measured in minutes, not seconds. Second, CI/GitHub Actions consumers cannot programmatically read state because no command emits structured JSON — every integration scrapes markdown. Third, the orchestrator's start-time entry chain (`evaluate → discuss → roadmap → plan-phase`) requires the operator to invoke each command by name, with no resumable wrapper; first-time users break the chain at the first interrupt and start over.

The minimum surface that fixes all three: a tree renderer (`orchestrator:where`) that composes the existing surfaces into one glance; an invocation-context resolver feeding a `--format=json` flag on status/where (single-resolve, every command reads it); and an `--auto-chain` flag on `orchestrator:start` that walks the entry chain with explicit user gates and a marker-file resume convention.

This feature does not attempt to replace `orchestrator:status` (the flat-section view stays), does not introduce a watcher daemon (live-tail runs in foreground only), does not pull in a Rich/TUI library (bash + ANSI is sufficient), and does not deepen GitHub fold-in (the launch project-management surface is the wiki per the 2026-05-05 scope tightening — GitHub fold-in defers to demand-driven post-launch `external-tool-adapters`).

## User Scenarios & Testing *(mandatory)*

### Minimal Slice (Phase 1 Load-Bearing Scope)

User Story 1 (invocation-context resolver) and User Story 2 (headline block in `orchestrator:status`) together close the dogfood loop. Once those land, this repo's own `auto` runs benefit on the next iteration: the developer types `orchestrator:status` and sees a 3-line headline that answers "is this on track?" before drilling into flat sections, and `--format=json` becomes available for downstream tooling. Every subsequent user story (the `where` tree, live-tail, preflight, `--auto-chain`) is defended on top of this slice.

### User Story 1 — Invocation-context resolver + `--format=json` (Priority: P1)

A developer running `orchestrator:status --format=json` in a CI job receives a structured payload with milestone ID, phase index, percent complete, lock state, and last-verify result, suitable for piping into a GitHub Actions step or a `jq` filter. Today the same job must scrape the markdown rendering, which breaks on every cosmetic change.

**Why this priority**: Every later story in this spec consumes the resolver's output (TTY-vs-pipe detection drives ANSI stripping; the JSON renderer is the same surface for `where` and `status`). Without the resolver, every command grows its own ad-hoc detection logic. Single-resolve is load-bearing infrastructure; ship it first.

**Independent Test**: Exercise `scripts/state/detect-invocation-context.sh` with three explicit input combinations (TTY=1 + no CI vars, TTY=0 + GITHUB_ACTIONS=true, TTY=0 + CLAUDECODE=1) and assert the resolved fields (`renderer`, `exit_code_scheme`) match a golden table. Then run `orchestrator:status --format=json` and assert the output validates against a JSON schema with the required fields. No dependency on the tree renderer.

**Acceptance Scenarios**:

1. **Given** an interactive terminal (`isatty=true`, no CI env vars), **When** the developer runs `orchestrator:status` without flags, **Then** the headline renders with ANSI color and the exit code matches the interactive scheme.
2. **Given** a CI environment (`GITHUB_ACTIONS=true`, `isatty=false`), **When** the same command runs, **Then** ANSI is stripped automatically and a `--format=json` invocation emits a JSON object validating against the documented schema.

### User Story 2 — Headline block in `orchestrator:status` with embedded efficiency footer (Priority: P1)

A developer who has just resumed a session opens `orchestrator:status` and sees a 3-line headline before the existing flat sections: the milestone ID and name, the current phase index and percent complete, lock state, last-dispatch recency, last-verify result, plus the M027 efficiency-footer line embedded verbatim. The flat sections beneath remain unchanged so existing scrapers do not break.

**Why this priority**: This is the highest-leverage glance surface — every developer hits `status` at session resume. Reusing M027's `efficiency-footer.sh` keeps the suppression matrix (CON-3/SC-3/SC-17 on M027) honored without re-implementation.

**Independent Test**: Render `orchestrator:status` against a fixture milestone in `executing` state with a populated execution-log.jsonl, and assert the first 3 stdout lines match the documented headline shape (regex-checkable). Toggle the M027 `efficiency_footer` config knob off and assert the footer line disappears while the headline stays.

**Acceptance Scenarios**:

1. **Given** a milestone in `executing` state with at least one completed phase and one in-flight phase, **When** the developer runs `orchestrator:status`, **Then** stdout begins with a headline block of exactly the documented field set, followed by a blank line, followed by the existing flat sections byte-identical to today.
2. **Given** the same milestone but with `efficiency_footer: false` in `.orchestrator/config.yml`, **When** `orchestrator:status` runs, **Then** the headline drops the footer line; no other field is affected.

### User Story 3 — `orchestrator:where` at-rest tree renderer with cost column (Priority: P2)

A developer mid-run wants to see the full work hierarchy in one screen: feature → milestone → phases → in-flight phase's tasks → current dispatch, with progress bars, status glyphs, and per-row token/cost columns sourced from M027's `metrics-rollup.sh`. Older milestones predating M019 Tier 1 emission render without the cost column rather than producing warnings.

**Why this priority**: P2 (not P1) because the headline block from US-2 already answers most "is this on track?" questions; the tree view is for "show me the topology." Useful but not load-bearing for the dogfood loop.

**Independent Test**: Render `orchestrator:where` against a fixture milestone covering all four row states (`✓` done, `▶` executing, `◇` pending, `✗` failed), and assert the output structure matches a golden render (deterministic given fixture state). Run against a pre-M019 fixture and assert the cost column is absent without warnings.

**Acceptance Scenarios**:

1. **Given** a milestone with phases in mixed states (P01 done, P02 executing, P03/P04 pending), **When** the developer runs `orchestrator:where`, **Then** stdout renders the tree with the documented glyphs, progress bar for the milestone, and a per-row cost column from `metrics-rollup.sh --scope task` for rows whose milestone has Tier 1 data.
2. **Given** a milestone whose execution log predates M019 Tier 1 emission, **When** `orchestrator:where` runs, **Then** the cost column is omitted and no warning appears on stderr.

### User Story 4 — `orchestrator:where --live` with compression-savings marker (Priority: P2)

A developer watching an `auto` run keeps `orchestrator:where --live` open in a second terminal. As `dispatch_usage` records append to `execution-log.jsonl`, the tree updates within 1s; when a record's `tier1_savings_tokens + tier2_savings_tokens > 5%` of dispatch tokens, a savings marker (`▽ saved Nk via tier1 cache reuse`) renders on that row. Compression earns its keep visibly.

**Why this priority**: P2 because at-rest `where` from US-3 already covers the legibility need; the live-tail variant is a quality-of-life upgrade that pays off mostly during long autonomous runs.

**Independent Test**: Run `orchestrator:where --live` in the foreground, append a synthetic `dispatch_usage` record with savings >5% to the JSONL stream, and assert the rendered tree updates within 1 second showing the `▽` marker. Append a record with savings <5% and assert no marker appears.

**Acceptance Scenarios**:

1. **Given** `orchestrator:where --live` is running and the active milestone is in `executing` state, **When** a `dispatch_usage` record with `tier1_savings_tokens + tier2_savings_tokens > 5%` of total dispatch tokens appends to the JSONL, **Then** the live-tail render updates within 1 second and shows the `▽ saved Nk` marker on the corresponding task row.
2. **Given** the same setup, **When** a record with savings <5% appends, **Then** the row updates without the marker and no log entry is produced.

### User Story 5 — `orchestrator:auto` opt-in preflight summary (Priority: P3)

A developer about to launch a Tier C autonomous run at Standard or Full intensity sees a preflight block before the loop enters: phase count, expected dispatch count, predicted total cost (sourced from M027's `predictive-surface.sh`), with a confirmation prompt. Quick intensity suppresses the preflight to preserve fast-path velocity.

**Why this priority**: P3 because the budget-checker already catches over-spend after the fact; the preflight is a courtesy that improves first-run UX without changing safety. Useful, not essential.

**Independent Test**: Invoke `orchestrator:auto` against a Standard-intensity milestone with a stubbed prompt-response (auto-accept), and assert the preflight block appears on stderr with values that match `predictive-surface.sh` output exactly (byte-identical for the cost field).

**Acceptance Scenarios**:

1. **Given** a Tier C milestone with intensity=Standard, **When** `orchestrator:auto` is invoked, **Then** stderr emits a preflight block containing phase count, dispatch count, and predicted cost; the loop blocks on a confirmation prompt before entering.
2. **Given** the same milestone with intensity=Quick, **When** `orchestrator:auto` is invoked, **Then** no preflight block appears and the loop enters immediately.

### User Story 6 — `--auto-chain` flag on `orchestrator:start` (Priority: P3)

A first-time developer runs `orchestrator:start --auto-chain` after `orchestrator:init`. The flag walks the start-time entry chain (`evaluate → discuss → roadmap → plan-phase`) one stage at a time, prompting for confirmation between stages and writing a marker file (`.orchestrator/start-state/<stage>.complete`) after each. If the developer interrupts mid-chain, re-running `orchestrator:start --auto-chain` resumes from the next incomplete marker.

**Why this priority**: P3 because today's developer can run each command by name; `--auto-chain` is a UX shortcut that pays off only on first use. The grilling-protocol discipline (CON-5 sequential-not-batched) is preserved by keeping explicit user gates between stages.

**Independent Test**: Run `orchestrator:start --auto-chain` against a fresh fixture project, walk through the four gates with auto-accept, and assert each marker file is written in order. Interrupt mid-chain between `discuss` and `roadmap`, re-invoke, and assert the chain resumes at `roadmap`.

**Acceptance Scenarios**:

1. **Given** a freshly-initialized Tier C greenfield project with no start-state markers, **When** the developer runs `orchestrator:start --auto-chain` and confirms each gate, **Then** the four entry-chain commands run in sequence and each produces a marker file under `.orchestrator/start-state/`.
2. **Given** a project where `.orchestrator/start-state/discuss.complete` exists but `roadmap.complete` does not, **When** `orchestrator:start --auto-chain` is re-invoked, **Then** the chain resumes at `roadmap` and skips `evaluate` and `discuss` without re-prompting.

---

## Edge Cases

- **No active milestone**: `orchestrator:where` invoked when `find-active-milestone.sh` returns NONE renders a one-line "no active milestone" notice rather than an empty tree.
- **Lock held by another session**: the headline block reports the lock owner PID and start time; the tree renders the last-known-state snapshot from disk without any mutation.
- **Pre-M019 milestone**: the cost column on `where` is omitted entirely (not blanked); no stderr warning. Documented per US-3 AS-2.
- **`--format=json` with corrupt JSONL stream**: emit a JSON object with `state: "degraded"` and a `parse_errors` list; do not crash the renderer.
- **Live-tail target file missing**: `orchestrator:where --live` waits up to 5 seconds for the JSONL file to appear, then exits with a clear "no execution log under <path>" error rather than tailing an empty file forever.
- **`--auto-chain` interrupted between stage and marker write**: the next invocation re-runs the in-flight stage; stages are idempotent by virtue of each command's existing re-entry semantics.
- **Compression-savings race**: when a `dispatch_usage` record arrives but the per-task `metrics-rollup.sh` cache has not yet refreshed, the row renders without the `▽` marker for that frame and updates on the next tail iteration.

---

## Functional Requirements

- **FR-1 (invocation-context-resolver)**: Ship `scripts/state/detect-invocation-context.sh` that resolves three fields (`renderer ∈ {tui, json, plain}`, `exit_code_scheme ∈ {interactive, governance}`, `default_provider`) from explicit inputs (TTY status, CI env vars, Claude Code env vars). Single-resolve at command entry; downstream calls read the resolved env block. Satisfies US-1.
- **FR-2 (status-headline-block)**: Prepend a 3-line headline block to `orchestrator:status` output containing milestone ID + name, phase index + percent complete, lock state, last-dispatch recency, last-verify result, plus the existing M027 `efficiency-footer.sh` line embedded verbatim. The flat sections beneath are byte-identical to today's render. Satisfies US-2.
- **FR-3 (status-format-json)**: Add `--format=json` to `orchestrator:status` that emits a JSON object with the headline fields as top-level keys plus `sections` mapping each existing flat section to its rendered string. Schema documented at `references/status-json-schema.md`. Satisfies US-1.
- **FR-4 (orchestrator-context-skill)**: Ship `orchestrator:context` as a read-only skill that prints resolved root, runtime, capability profile, intensity defaults, active milestone, and lock state. Single screen; no I/O writes. Satisfies US-1.
- **FR-5 (where-renderer)**: Ship `orchestrator:where` as a new skill backed by `scripts/diagnostics/render-position.sh`. Renders the work hierarchy from feature → milestone → phases → in-flight tasks → current dispatch using the documented glyph set (`▓░ ▶ ◇ ✓ ✗ ▽`). Reads roadmap, execution log, lock manager, and (for the cost column) `metrics-rollup.sh --scope task`. Pure read; never mutates state. Satisfies US-3.
- **FR-6 (where-cost-column-graceful-degradation)**: Per-row token/cost column is suppressed when the milestone's execution log predates M019 Tier 1 emission. Suppression is silent — no stderr warning, no blank column. Satisfies US-3 AS-2.
- **FR-7 (where-live-tail)**: `orchestrator:where --live` polls `execution-log.jsonl` via `tail -f` (POSIX-portable; no `inotify`/`fswatch` dependency) and re-renders the tree on every appended record. Update latency target: ≤1 second from append to render. Satisfies US-4.
- **FR-8 (compression-savings-marker)**: When a tailed `dispatch_usage` record's `tier1_savings_tokens + tier2_savings_tokens` exceeds 5% of total dispatch tokens, the live-tail render emits a `▽ saved Nk` marker on the corresponding task row. Threshold is static at 5% (per OQ6 resolution). Satisfies US-4.
- **FR-9 (auto-preflight-summary)**: At the entry of `orchestrator:auto` for Standard or Full intensity, emit a preflight block on stderr containing phase count, expected dispatch count, and predicted total cost from `scripts/dispatch/predictive-surface.sh`. Block on a confirmation prompt before entering the loop. Suppress entirely at Quick intensity. Satisfies US-5.
- **FR-10 (auto-chain-flag)**: Add `--auto-chain` to `orchestrator:start` that walks `evaluate → discuss → roadmap → plan-phase` with explicit user gates between stages. Marker files at `.orchestrator/start-state/<stage>.complete` record progress; re-invocation resumes at the first incomplete marker. OFF by default. Satisfies US-6.
- **FR-11 (no-github-foldin-headline)**: The `where` tree headline does NOT include a `GitHub:` line. The M013 sidecar at `.orchestrator/integrations/github.json` remains readable by `orchestrator:github-status` and `orchestrator:github-sync` — those skills are unchanged. Cut per the 2026-05-05 scope tightening.
- **FR-12 (no-refresh-github-flag)**: The `where` skill does NOT accept a `--refresh-github` flag in v1. The orchestrator does not initiate GitHub API calls at render time. Cut per the 2026-05-05 scope tightening.
- **FR-13 (cross-milestone-feature-grouping)**: When a feature spec spans multiple milestones, `where` renders the full feature view (all milestones the spec lists) and marks the active milestone within it. The active-milestone-only view is available via `--milestone <M###>`. Cross-milestone data model and inactive-milestone rendering shape (collapsed vs. expanded) deferred to #Q-5.
- **FR-14 (read-only-discipline)**: All M029 surfaces (`where`, `context`, `--format=json`, headline block, live-tail, preflight) are read-only. No write to `.orchestrator/` state, no mutation of execution-log.jsonl, no GitHub API calls. The only exception is `--auto-chain`'s marker-file writes under `.orchestrator/start-state/`.

## Success Criteria

- **SC-1**: `bash scripts/state/detect-invocation-context.sh --tty=true --ci=false` exits 0 and emits an env block with `renderer=tui exit_code_scheme=interactive`. Same script with `--tty=false --ci=true` emits `renderer=plain`.
- **SC-2**: `orchestrator:status` rendered against the SC-2 fixture milestone produces stdout whose first 3 non-blank lines match the headline regex documented in `references/status-headline-shape.md`. Exit 0. (Design contract: `references/status-headline-shape.md` must be authored as a P01 design artifact and committed to disk before any FR-2 implementation task begins, per Principle III. Arbiter ruling 2026-05-05, RISK-7 / MIT-10.)
- **SC-3**: `orchestrator:status --format=json` against the same fixture emits stdout that validates against `references/status-json-schema.md` (`jq -e` on each required key returns 0). (Design contract: `references/status-json-schema.md` must be authored as a P01 design artifact and committed to disk before any FR-3 implementation task begins, per Principle III. Arbiter ruling 2026-05-05, RISK-7 / MIT-10.)
- **SC-4**: `orchestrator:context` exits 0 and emits exactly one screen (≤24 lines on an 80×24 terminal) with the documented field set.
- **SC-5**: `orchestrator:where` rendered against the SC-5 mixed-state fixture produces output whose tree structure matches the golden render at `tests/m029-acceptance/fixtures/where-mixed-state.golden`, byte-identical modulo timestamps.
- **SC-6**: `orchestrator:where` against a pre-M019 fixture produces output without the cost column; stderr is empty.
- **SC-7**: `orchestrator:where --live` against a fixture with a synthetic `dispatch_usage` append (savings ≥5%) updates the rendered tree within 1 second (timed via `tests/m029-acceptance/measure-live-tail-latency.sh`) and emits the `▽` marker on the affected row.
- **SC-8**: `orchestrator:auto` at Standard intensity invoked against the SC-8 fixture milestone emits a preflight block on stderr whose `predicted_cost` field is byte-identical to `bash scripts/dispatch/predictive-surface.sh --milestone <M###>` output. Blocks on prompt; auto-accept proceeds into the loop.
- **SC-9**: `orchestrator:auto` at Quick intensity emits no preflight block on stderr (assertion: stderr does not contain the string `Preflight Summary` before `AUTO:READY`).
- **SC-10**: `orchestrator:start --auto-chain` against the SC-10 greenfield fixture writes `.orchestrator/start-state/{evaluate,discuss,roadmap,plan-phase}.complete` in order; interrupted between `discuss` and `roadmap`, re-invocation resumes at `roadmap` (no `evaluate.complete` or `discuss.complete` rewrite).
- **SC-11**: Running the M029 acceptance battery (`tests/m029-acceptance/run-acceptance-battery.sh`) emits `BATTERY: pass=N fail=0` covering all 14 SCs (SC-1 through SC-14). No flaky retries.
- **SC-12**: `validate-milestone.sh M029` reports 100% pass; the M029-VALIDATED marker exists on disk after milestone closure.
- **SC-13** (anti-coupling guard): `grep -r '/integrations/github' specs/037-roadmap-visibility-cli-ux/ scripts/diagnostics/render-position.sh` returns no match in the headline rendering path. Enforces FR-11.
- **SC-14** (read-only guard): the M029 acceptance battery includes a check that runs `orchestrator:where`, `orchestrator:context`, and `orchestrator:status --format=json` against a fixture and asserts no file under `.orchestrator/` was modified (mtime check). Enforces FR-14.

## Non-Goals

- **Web UI / persistent dashboard**: terminal-only. A web visualization is out of scope; the wiki (M032) is the long-form view.
- **Watcher daemon**: `orchestrator:where --live` runs in foreground only. No background daemon, no system service, no auto-restart.
- **GitHub fold-in in `where` headline**: explicitly cut per 2026-05-05 scope tightening; deferred to demand-driven post-launch `external-tool-adapters`.
- **`--refresh-github` flag**: explicitly cut. No GitHub API calls on render.
- **Deeper GitHub Projects v2 / Issues / dashboard surface area**: any deeper GitHub UX defers to real-user demand-signal post-launch.
- **Rich/TUI library binding**: bash + ANSI escapes are sufficient. Pulling in a Python TUI dep adds runtime cost the launch posture does not need.
- **Replacing `orchestrator:status`**: `where` is the tree view, `status` is the flat-section view. Both keep their roles.
- **Modifying the `orchestrator:auto` loop logic**: M029 only *reads* what auto already emits; the loop driver at `scripts/lifecycle/auto-loop.sh` is unchanged.
- **A new aggregator over M019 / M027 surfaces**: M029 composes; it does not introduce a new metrics aggregator. `metrics-rollup.sh` and `efficiency-footer.sh` are reused as-is.

## Constraints

- **CON-1 (read-only)**: All render paths are read-only. The only write site introduced by M029 is `--auto-chain`'s marker files under `.orchestrator/start-state/`. Verified by SC-14.
- **CON-2 (bash + ANSI only)**: No new runtime dependencies (Python, Rich, ncurses, fswatch). All rendering uses `tput` / ANSI escapes; live-tail uses `tail -f`. Auto-strip ANSI when not TTY (per FR-1's resolver).
- **CON-3 (cost-column-graceful-degradation)**: When M019 Tier 1 data is absent for a milestone, the cost column is omitted silently. No stderr warning; no blank column. Verified by SC-6.
- **CON-4 (no-github-api-on-render)**: The render path never invokes `gh` or any GitHub HTTP API. The M013 sidecar may be read for `orchestrator:github-status` / `orchestrator:github-sync` (unchanged skills), but never on the `where` / `status` render path. Verified by SC-13.
- **CON-5 (suppression-matrix-honored)**: When the M027 `efficiency_footer` config knob is `false` (or any of the six M027 knobs that gate the embedded surfaces), the corresponding line in the headline / tree disappears without other side effect. M029 does NOT introduce its own suppression knob; it inherits M027's.
- **CON-6 (live-tail-latency)**: Live-tail update latency target ≤1 second from JSONL append to rendered frame. POSIX-portable polling via `tail -f`; no platform-specific watchers. Verified by SC-7.

### Knowledge-Layer Boundary (M029 vs. M020 + M027 + M019)

M029 is a **rendering / composition** milestone. It does NOT extend the knowledge-graph schema (M020), does NOT introduce new metrics (M027), does NOT add new JSONL event types (M019). M029's write claim is limited to:

- `scripts/state/detect-invocation-context.sh` (new, read-only)
- `scripts/diagnostics/render-position.sh` (new, read-only)
- `commands/where.md`, `commands/context.md` (new command definitions)
- Modifications to `commands/status.md`, `commands/auto.md`, `commands/start.md` (additive: headline block, preflight summary, `--auto-chain` flag)
- `references/status-json-schema.md`, `references/status-headline-shape.md` (new docs)
- `.orchestrator/start-state/*.complete` marker files (operator-state, not knowledge)
- `tests/m029-acceptance/` (test fixtures)

M029 explicitly does NOT write to:

- `.orchestrator/KNOWLEDGE.md` schema (M020 owns)
- `.orchestrator/milestones/M###/execution-log.jsonl` schema (M019 owns)
- M027's `metrics-rollup.sh`, `efficiency-footer.sh`, `predictive-surface.sh` (read-only consumers)
- M013's `.orchestrator/integrations/github.json` schema (read-only consumer; not even read in v1 render path per FR-11)

## Assumptions

- **A-1**: M013 (closed), M018 (closed), M019 Tier 1+2+3 (closed), and M027 (closed) are on disk with their public surfaces stable; M029 composes against them.
- **A-2**: `find-active-milestone.sh` correctly returns the auto-eligible milestone in `executing | planning | summarizing | validating | completing` state.
- **A-3**: `tail -f` is available on the runtime host (Mac/Linux/WSL all ship it). No fallback for non-POSIX platforms in v1.
- **A-4**: M032 (wiki distribution) is closed and the wiki is the launch project-management surface, validating the 2026-05-05 scope tightening.
- **A-5**: The 2026-05-15 PBJ pilot is the demand-signal trigger for any post-launch GitHub fold-in work via `external-tool-adapters`. M029 does not pre-build for that.
- **A-6**: `orchestrator:start` (M033, closed pending friendly-tester pass) exposes the entry-chain stages as discrete commands that `--auto-chain` can compose.

## Constitution Check

Compliance with `.orchestrator/memory/constitution.md` for each principle materially touched:

- **Principle I (Context Minimization)**: M029 is read-only and reuses existing surfaces; the `--format=json` flag and the resolver reduce the bytes downstream consumers must parse, lowering total task tokens system-wide. The auto preflight (FR-9) shows cost upfront so operators avoid mid-run discovery overhead.
- **Principle II (Evidence Before Claims)**: Every cost / progress / status field rendered by M029 reads from on-disk artifacts (execution-log.jsonl, roadmap, lock file, M027 surfaces). No claim originates in the renderer; the renderer is a witness, not a source.
- **Principle III (Design Before Code)**: The Section Contract here, plus the OQ resolutions in the proposal, define the rendering shape (glyphs, column order, JSON schema) before any script is written. Pass 3 gates this spec; planning gates the per-phase task shape; only after both does code land.
- **Principle XI (Single Source of Truth)**: The invocation-context resolver (FR-1) is the single resolve-site for TTY/CI/runtime detection. Every command reads the resolver's output; no command grows its own ad-hoc detection.
- **Principle XIV (No Speculative Complexity)**: The 2026-05-05 scope tightening (cut GitHub fold-in, cut `--refresh-github`, cut deeper Projects v2 surface area) is a direct application of this principle. Speculatively building GitHub UX before a real user asks serves an audience that does not exist.
- **Principle XV (Surgical Precision)**: M029 does not touch `auto-loop.sh`, does not modify M019/M020/M027 schemas, does not introduce new event types. Each new surface is bounded to a specific render or composition; the blast radius is the render path.
- **Principle VIII (No Dead Infrastructure)**: Every M029 surface has an SC entry and a fixture. The acceptance battery (SC-11) exercises all 14 SCs; surfaces without exercise rights would surface as battery gaps before close.

## Open Questions (defer to planning)

- **#Q-1 (live-tail-redraw-strategy)**: Full re-render on every appended record vs. incremental row update. Recommendation: full re-render (simpler, no row-tracking state); tree fits in <50 rows for any plausible milestone, so the cost is negligible. Resolve at P03 plan-phase.
- **#Q-2 (preflight-cost-format)**: Preflight cost field — show `$X.YY` or `est. ~$X.Y ± $Z.Z` (range)? Recommendation: range, since `predictive-surface.sh` already emits a confidence interval. Resolve at P03 plan-phase.
- **#Q-3 (auto-chain-failure-recovery)**: When a stage in `--auto-chain` fails (e.g., `evaluate` exits non-zero), do we leave the marker absent (re-runs re-execute) or write a `<stage>.failed` marker for visibility? Recommendation: leave absent; re-runs re-execute the failed stage; surface via `orchestrator:status`. Resolve at P03 plan-phase.
- **#Q-4 (json-schema-stability-policy)**: The `references/status-json-schema.md` schema becomes a public contract for CI consumers. Should we version it (`schema_version: "1.0"`) so future field additions are non-breaking? Recommendation: yes, version from day 1 per Principle XV. Resolve at P01 plan-phase.
- **#Q-5 (cross-milestone-feature-rendering)**: Per FR-13, when a feature spans multiple milestones, render shape is "full feature view with active marked." Concrete rendering of inactive milestones — collapsed (one line each) or expanded (full tree)? Recommendation: collapsed by default, `--expand-all` to override. Resolve at P02 plan-phase.

### Conversus Gate Findings (advisory BLOCK, 2026-05-05) — defer to `orchestrator:discuss`

Pass-3 gate ran at Standard intensity (advisory). Verdict: BLOCK with 11 surviving disputes; full deliberation at `specs/037-roadmap-visibility-cli-ux/conversus/summary/final.md`; arbiter resolution at `specs/037-roadmap-visibility-cli-ux/conversus/arbiter/resolution.md`. P0 findings must be resolved at `orchestrator:discuss` before roadmap; P1 findings before P01 plan-phase opens. Two surgical fixes the gate prescribed (SC-2/SC-3 design-contract annotations per RISK-7/MIT-10, and the SC-11 count correction per RISK-3) are already applied inline above. Remaining items:

- **#Q-G1 (FR-9 non-interactive behavior, RISK-1, P0)**: FR-9 specifies a confirmation prompt at Standard/Full intensity but does not define behavior under non-interactive invocation (CI, piped stdin, `auto_proceed: true` from M031). Options: auto-accept under `--yes`, auto-accept under `auto_proceed=true`, error with explicit message, skip the preflight. Resolve at `orchestrator:discuss`.
- **#Q-G2 (SC-8 oracle interface, RISK-2, P0)**: SC-8 cites `bash scripts/dispatch/predictive-surface.sh --milestone <M###>` as the byte-identical oracle. Verify the `--milestone` flag exists on the M027-shipped `predictive-surface.sh`. If absent, choose: amend SC-8 to use the actual surface, or extend M027's surface (out-of-scope contingent dependency). Resolve at `orchestrator:discuss`.
- **#Q-G3 (FR-3 ANSI in JSON `sections` field, RISK-6, P0)**: FR-3 emits a JSON object whose `sections` field maps to "rendered string" content. When `orchestrator:status` runs in a TTY context but is invoked with `--format=json`, those rendered strings would contain ANSI escape sequences. Spec must declare: ANSI-stripped content always in JSON, or schema separates raw vs. rendered. Recommendation: always strip ANSI from `sections` content in JSON mode (the resolver already drives this for non-TTY; extend the rule to JSON-format invocations regardless of TTY). Resolve at `orchestrator:discuss`.
- **#Q-G4 (FR-8 5% threshold rationale, RISK-4, P0)**: OQ6 carried the 5% compression-savings display threshold from the proposal recommendation, not from measured evidence. Either (a) cite the data set or measurement that justifies 5%, or (b) annotate FR-8 as a starting heuristic with a "tune after first 10 milestones of telemetry" review trigger, or (c) make it config-knob-driven from day 1. Resolve at `orchestrator:discuss`.
- **#Q-G5 (FR-13 cross-milestone data model, RISK-5, P0)**: FR-13 promises a cross-milestone feature view but does not define the data model — how does the renderer determine which milestones belong to a feature? Options: (a) feature-spec frontmatter lists milestones explicitly, (b) reverse-lookup from each milestone's `parent` field, (c) external manifest. Resolve at `orchestrator:discuss`.
- **#Q-G6 (SC-5 timestamp-exclusion enumeration, RISK-8, P1)**: SC-5 says "byte-identical modulo timestamps" without enumerating which timestamp fields are excluded. List the exact regex patterns or field names that the golden-render comparator strips before diffing. Resolve at P02 plan-phase.
- **#Q-G7 (SC-14 mtime sentinel mechanism, RISK-9, P1)**: SC-14 uses mtime checks to enforce read-only discipline, but HFS+ has 1-second mtime granularity and APFS is sub-second only on some filesystems. A vacuous pass is possible if all reads complete within one mtime tick. Replace the mtime check with a sentinel-file mechanism: write a sentinel before the read, assert the sentinel's mtime is unchanged after. Resolve at P02 plan-phase.
- **#Q-G8 (FR-8 marker canonical form, RISK-11, P1)**: The spec uses three different strings for the compression-savings marker (`▽ saved Nk`, `▽ 4k saved`, `▽ saved Nk via tier1 cache reuse`). Nominate the canonical form once and apply consistently. Recommendation: `▽ saved Nk` (compact; `via tier1 cache reuse` lives in tooltip / verbose mode if added later). Resolve at P02 plan-phase.
- **#Q-G9 (SC-7 latency methodology, RISK-10, accepted with monitoring)**: 1-second live-tail latency is a target, not a hard pass/fail under all loads. Explicit methodology — measurement harness, percentile (p95? p99?), retry policy on flake — deferred to P03 plan-phase. Capture as a known flake-risk item; if SC-7 measurements show drift beyond p95=1.5s during P03, escalate to a hard SC tightening.

The full risk register table is at `conversus/arbiter/resolution.md` (RISK-1 through RISK-11). The deliberation also surfaced a meta-observation: P0 findings clustered in the spec's later sections (FR-8 onward), suggesting the live-tail / preflight material received less editorial attention than the P1 user stories. Track as a process signal for future M0XX spec authoring; not a per-finding action.

## Dependencies

- **M013 (GitHub native integration, closed)**: provides `.orchestrator/integrations/github.json` sidecar. M029 reads it only for `orchestrator:github-status` / `orchestrator:github-sync` (unchanged skills); the v1 render path does not read it (per FR-11).
- **M018 (Context Compression Layer, closed)**: provides `payload_breakdown` fields in JSONL events; consumed by FR-8 compression-savings marker.
- **M019 Tier 1+2+3 (observability emitter + cost rollup, closed)**: provides `execution-log.jsonl` schema and `dispatch_usage` records; consumed by FR-7 live-tail and FR-8 marker.
- **M027 (Cost+Quality Observability Surfaces, closed)**: provides `efficiency-footer.sh` (FR-2 headline embed), `metrics-rollup.sh` (FR-5 cost column), `predictive-surface.sh` (FR-9 preflight). M029 is pure composition over these.
- **M032 (Wiki Distribution + Init Integration, closed)**: validates the wiki-is-the-view scope tightening; M029 does not load M032's APIs but inherits the "wiki is launch surface" decision.
- **M033 (Project Onboarding Experience, closed pending friendly-tester pass)**: provides `orchestrator:start` and the entry-chain stages (`evaluate`, `discuss`, `roadmap`, `plan-phase`) that `--auto-chain` composes (FR-10).

## Downstream Consumers (informational, not binding)

- **M035 (Packaging & Distribution)**: ships `orchestrator:status --format=json` as a documented surface for npm / homebrew / curl-pipe-bash post-install verification scripts.
- **`external-tool-adapters` (post-launch, demand-driven)**: the GitHub Projects / Trello / Notion / Linear adapters proposed at `.orchestrator/proposals/post-launch-wiki-ux-and-adapters.md` consume the `--format=json` schema to project orchestrator state into third-party tools. M029's schema-versioning policy (#Q-4) is the load-bearing dependency.
- **Future `orchestrator:zoom-out` integration**: the shipped `commands/zoom-out.md` skill should adopt the same domain vocabulary as M029's headline output so users moving between `where` and `zoom-out` do not context-switch terminology. Shared anchor: `wiki/glossary.md` (M032 Finding K).
- **CI/GitHub Actions consumers**: any CI pipeline that wants to read orchestrator state without scraping markdown gains a stable `--format=json` surface.
