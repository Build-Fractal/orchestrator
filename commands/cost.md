---
description: "Use when surfacing orchestrator cost data — retrospective rollups over the M019 Tier 1 JSONL stream, or predictive per-tier (Quick / Standard / Full) cost+quality estimates before dispatch. Read-only; bash-only; zero LLM tokens."
---

# orchestrator:cost

Surface orchestrator cost data on two surfaces: a **retrospective** rollup over the M019 Tier 1 `execution-log.jsonl` stream (no flags or with scope flags) and a **predictive** per-tier (Quick / Standard / Full) cost+quality estimate before dispatch (`--estimate "<description>"`). Both surfaces are read-only, bash-only, and consume zero LLM tokens — they delegate to the pre-existing engines under `scripts/diagnostics/` and `scripts/engine/` and emit no JSONL records of their own.

## Prerequisites / State Check

- `.orchestrator/` exists at the project root (run `orchestrator:init` first). If absent, exit 2 with a one-line diagnostic.
- For the retrospective surface: `scripts/diagnostics/metrics-rollup.sh` is present and executable. The script ships with the orchestrator bundle (M027/P00).
- For the predictive surface: `scripts/engine/cost-estimate.sh` is present and executable, and `scripts/lib/pricing.sh` is sourceable. Missing `pricing.yml` is non-fatal — the predictive surface degrades gracefully (FR-24, CON-5).
- Optional: `.orchestrator/milestones/M*/execution-log.jsonl` may or may not exist. Missing logs degrade to an empty rollup row (CON-5) — the command never aborts.

## Core Workflow

### 1. Resolve mode (retrospective vs predictive)

Inspect the invocation arguments:

- If the argument list contains `--estimate <description>` (or `--estimate=<description>`), enter **predictive mode** and delegate to section 3.
- Otherwise enter **retrospective mode** and delegate to section 2.

The two modes are mutually exclusive. Passing `--estimate` together with any retrospective scope flag (`--milestone`, `--phase`, `--task`, `--granularity`, `--source`, `--since`) is a usage error — exit 2 with a one-line diagnostic naming the offending pair.

### 2. Retrospective: rollup over M019 Tier 1 JSONL

Default scope is the active milestone if one is detectable on disk; otherwise fall back to project-granularity rollup across every `.orchestrator/milestones/M*/execution-log.jsonl` discoverable from the project root.

1. **Detect the active milestone.** Run `bash scripts/state/derive-phase.sh <milestone-dir>` against the most-recent milestone directory under `.orchestrator/milestones/`. If a milestone is detected, set `--milestone Mxxx --granularity milestone` as the default args; otherwise set `--granularity project`.

2. **Build the rollup argument list.** Pass through any operator-supplied flags from the invocation (`--milestone`, `--phase`, `--task`, `--granularity`, `--source`, `--since`) verbatim — they override the detected defaults.

3. **Print a one-line command header.** Emit exactly:

   ```
   # orchestrator:cost — retrospective rollup
   ```

   on stdout above the rollup engine output. This header is the only divergence from `metrics-rollup.sh` direct output (SC-4 contract).

4. **Invoke the rollup engine.** Run `bash scripts/diagnostics/metrics-rollup.sh <args>` and stream stdout to the operator. The engine emits paired cost+quality rows per FR-4 / CON-4 (Goodhart pairing) — every row that carries a cost cell carries a quality-semantics cell on the same row. Pricing-warning rows are surfaced with the `(N missing)` suffix per FR-11.

5. **Exit code.** Propagate the rollup engine exit code. The retrospective surface emits zero JSONL records (FR-12 carry-forward) and never modifies the project tree (CON-1 read-only invariant).

### 3. Predictive: per-tier estimate before dispatch

Delegate the full predictive surface to `scripts/engine/cost-estimate.sh`. This is a thin wrapper — no header line, no post-processing.

1. **Validate the description argument.** If `--estimate` appears with no following non-flag token (or with an empty string), exit 2 with a usage error.

2. **Invoke the estimator.** Run `bash scripts/engine/cost-estimate.sh --description "<description>"` and stream stdout to the operator. The estimator emits a 3-row Quick / Standard / Full paired cost+quality table with the recommended tier marked plus a one-line accuracy trailer pointing to `commands/cost.md#accuracy` per D027 (FR-20, FR-21, US-5 AS-1, AS-7).

3. **Goodhart pairing.** Every row of the predictive output that contains a cost cell also contains a quality-semantics cell on the same row (CON-4, FR-20, SC-18). The `m027-p01-predictive-goodhart-pairing.sh` verifier asserts this contract.

4. **Pricing degradation.** If `pricing.yml` is missing or stale, the estimator renders the cost cells as `(unavailable)` while preserving the quality cells per FR-24; the command never aborts (CON-5).

5. **Override semantics (informational).** When invoked interactively, the operator may switch tiers by pressing `1` / `2` / `3` or accept the recommended tier with Enter. This trailer is informational only — dispatch-time interactive override is P02 work and is **not** part of this surface.

6. **Latency budget.** Predictive output completes in well under 100 ms on a warm filesystem (CON-9, FR-22) and consumes zero LLM tokens (FR-21, CON-6).

## Output

Both surfaces write only to stdout. Stderr carries advisory warnings (e.g., pricing-missing, corrupt-line in the rollup engine) — never errors that abort the command.

- **Retrospective.** One header line (`# orchestrator:cost — retrospective rollup`) followed by the `metrics-rollup.sh` table. Each row pairs a cost cell with a quality-semantics cell. Pricing warnings appear as a `(N missing)` suffix on the cost cell.
- **Predictive.** A 3-row Quick / Standard / Full table with header, recommended-tier marker, paired cost+quality columns, and a one-line accuracy trailer pointing back to `commands/cost.md#accuracy`.

No JSONL records are emitted. No state files are written.

## Accuracy

Estimates use M019 char-quartile token approximation and pricing.yml rates; actual cost typically lands within +/-20%. Runtime-actuals calibration is Tier 3 (deferred).

The +/-20% band is a working assumption derived from M019 Tier 1 calibration runs and is reaffirmed in D027. Two sources of drift dominate the residual: (1) char-to-token quartile approximation under content that diverges from the calibration corpus, and (2) `pricing.yml` rate staleness when the providers update their published rates between rate-table refreshes. Tier 3 (M027/P03 + later) closes the loop with runtime-actuals calibration; until then, treat the predictive surface as a rough planner — accurate enough to choose between Quick / Standard / Full but not to forecast a per-task budget to the dollar.

## Idempotency

Both surfaces are strictly read-only:

- `git diff --quiet` returns exit 0 after invocation (no project-tree changes).
- No `execution-log.jsonl` line is appended by either surface.
- Running `orchestrator:cost` twice with identical arguments produces identical stdout modulo timing-derived advisory lines (e.g., a `WARN:` line on the rollup engine if a partially-written log was observed mid-write).

The retrospective rollup engine uses an `mktemp + cp` snapshot with an `EXIT` trap (FR-12 / FR-19 / AD-3 / CON-1) so a concurrent writer of `execution-log.jsonl` cannot bleed into the rollup result and cannot perturb the source tree.

## Error Handling

- **No `.orchestrator/` at project root.** Exit 2 with `run orchestrator:init first` (matches the existing diagnostic shape used by other read-only commands).
- **Mutually exclusive flags.** `--estimate` combined with any of `--milestone` / `--phase` / `--task` / `--granularity` / `--source` / `--since`, or `--task <id>` combined with `--granularity milestone|project`, is a usage error — exit 2 with a one-line diagnostic naming the offending pair.
- **`--estimate` with no following description.** Exit 2 with a usage error.
- **Missing `pricing.yml` (predictive surface).** Render `(unavailable)` cost cells per FR-24 and continue. Never abort (CON-5 carry-forward).
- **Missing `execution-log.jsonl` (retrospective surface).** Print an empty rollup row (granularity-appropriate) and continue. Never abort (CON-5).
- **Corrupt JSONL line in the retrospective surface.** The rollup engine emits `WARN: corrupt JSONL line N` to stderr per FR-14 and skips that line; aggregation continues.
- **Input-schema drift in the retrospective surface.** The rollup engine emits `WARN: input-schema line N` to stderr per FR-17 and skips that line.

## Concurrent Safety

`orchestrator:cost` is read-only and acquires no locks (FR-12 / CON-1). It is safe to run from a second terminal while autonomous mode runs in another, and safe to run while a dispatched task is writing to `execution-log.jsonl` — the rollup engine's snapshot semantics (AD-3 copy-then-aggregate) isolate the read from concurrent appends.

## Idempotency Verifier

The `m027-p01-read-only.sh` verifier asserts `git diff --quiet` is exit 0 after both surfaces run.

## Referenced Scripts

- `scripts/diagnostics/metrics-rollup.sh` — retrospective rollup engine (M027/P00). Sourceable bash library + CLI; accepts `--granularity task|phase|milestone|project`, `--milestone Mxxx`, `--phase Pxx`, `--task <id>`, `--source estimate|runtime|aggregate|all`, `--log <path>`. Emits paired cost+quality rows per FR-4 / CON-4.
- `scripts/engine/cost-estimate.sh` — predictive per-tier estimator (M027/P01/T01). Sourceable + CLI; accepts `--description <text>` and `--format text|json`. Text mode emits the 3-row table with header, recommended-tier marker, and the D027 accuracy trailer.
- `scripts/engine/intensity-recommend.sh` — recommendation engine consumed transitively by the predictive surface (M027/P01/T02). Accepts `--format text|json` and `--no-cost-annotation`. Not invoked directly from this command, but its per-tier cost annotations underwrite the recommended-tier marker emitted by `cost-estimate.sh`.
- `scripts/lib/pricing.sh` — pricing + token-estimate helpers (M019). Sourceable; provides the rate table consumed by the predictive surface and the cost cells consumed by the retrospective surface.
- `scripts/state/derive-phase.sh` — invoked to detect the active milestone for default-scope resolution on the retrospective surface.
