---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M027"
goal: "Ship the orchestrator:cost user-facing command (retrospective + predictive surfaces) — `commands/cost.md`, runtime-adapter registration via the M015/M025 packaging layer (Claude Code skill, Codex CLI command, Cursor command auto-registered from `commands/`), the predictive estimator entry points (`--estimate <description>` flag on the command, `intensity-recommend.sh` cost-annotation hook with text-default and opt-in `--format json` `cost_estimates` field per D026), the +/-20% accuracy disclaimer per D027, and a verifier suite enforcing FR-20 / FR-21 zero-LLM-token, FR-22 <100ms latency, FR-24 pricing-degradation, SC-15 / SC-16 / SC-18 predictive Goodhart pairing."
demo_sentence: "A developer (1) runs `orchestrator:cost` with no flags on this repo and sees a one-block retrospective rollup of the active milestone (or project) byte-equivalent (modulo a one-line command header per SC-4) to `bash scripts/diagnostics/metrics-rollup.sh --granularity milestone --milestone <active>`; (2) runs `orchestrator:cost --estimate \"add a TypeScript rewrite of the parser\"` and stdout shows a three-row table (Quick / Standard / Full) with paired cost (USD, est. tokens) AND quality semantics (Quick = best-effort, Standard = self-review, Full = adversarial gate) on every row, with the recommended tier marked, completing in <100 ms; (3) runs `bash scripts/engine/intensity-recommend.sh --description \"<task>\"` (text default) and the existing key=value lines are byte-stable while a per-tier cost-annotation block is appended below; (4) runs `bash scripts/engine/intensity-recommend.sh --description \"<task>\" --format json` and the structured output gains a top-level `cost_estimates` object keyed by tier (quick/standard/full) with `cost_usd` / `input_tokens` / `output_tokens` / `pricing_warning` fields per D026; (5) runs `bash scripts/verify/m027-p01-suite.sh` and exits 0; (6) under a missing or stale `pricing.yml`, every cost cell renders `(unavailable)` and the recommendation + override flow still work (FR-24); (7) `git diff --quiet` after every above invocation is exit 0 (FR-12 carry-forward)."
risk: "medium"
depends_on: ["P00"]
---

## Must-Haves

<!-- Each truth is a behavioral statement + a single-script-file Check (AD-19).
     Every Check command is a single-invocation script-file shape — no inline
     compound bash, no plain subshells, no $() containing pipes, no process
     substitution. All M027/P01 verification logic lives inside the
     scripts/verify/m027-p01-*.sh files; the Check commands here invoke them. -->

### Truths

- `commands/cost.md` exists with the canonical command-file structure (frontmatter `description`, Title, Prerequisites / State Check, Core Workflow numbered sections, Output, Idempotency, Error Handling, Referenced Scripts) per MEM012; documents both the retrospective surface (no flags / scope flags) and the predictive surface (`--estimate <description>`); embeds the D027 +/-20% accuracy disclaimer verbatim under an "Accuracy" subsection (FR-5).
  - Check: `bash scripts/verify/m027-p01-cost-command-shape.sh`

- `orchestrator:cost` with no flags defaults to a milestone-granularity rollup of the active milestone (or project-granularity if no active milestone), is a thin wrapper over `scripts/diagnostics/metrics-rollup.sh`, and emits no JSONL records (FR-5, FR-12 carry-forward, US-2 AS-1, AS-2, AS-5).
  - Check: `bash scripts/verify/m027-p01-cost-retro-default.sh`

- `orchestrator:cost --estimate <description>` emits a three-row (Quick / Standard / Full) paired cost+quality table with the recommended tier marked, completes in zero LLM tokens, and includes a one-line trailer pointing to `commands/cost.md#accuracy` per D027 (FR-20, FR-21, US-5 AS-1, AS-7).
  - Check: `bash scripts/verify/m027-p01-cost-estimate-table.sh`

- Predictive Goodhart pairing — every row of `orchestrator:cost --estimate` output that contains a cost cell also contains a quality-semantics cell on the same row; the verifier rejects any output schema that drops one without the other (FR-20, CON-4, SC-18).
  - Check: `bash scripts/verify/m027-p01-predictive-goodhart-pairing.sh`

- Predictive zero-LLM-token contract — grepping the M027/P01 script set (`scripts/engine/cost-estimate.sh`, any `scripts/engine/intensity-recommend.sh` deltas, any new `commands/cost.md`-invoked helper) for forbidden LLM-invocation patterns (`claude_chat`, `anthropic`, `dispatch-interface.sh`, `dispatch_task`, `subagent`) returns no matches (FR-21, CON-6, SC-16).
  - Check: `bash scripts/verify/m027-p01-zero-llm-token.sh`

- Predictive latency bound — `time` around `bash scripts/engine/cost-estimate.sh --description "<sample>"` reports wall-clock < 100 ms on a 2024-era laptop; the verifier asserts the budget with a 50 ms slack ceiling (so a 150 ms hard fail accommodates CI noise) and surfaces a `RELAX-CANDIDATE` annotation if measurement exceeds the soft 100 ms target on a single run (FR-22, CON-9, SC-15).
  - Check: `bash scripts/verify/m027-p01-predictive-latency.sh`

- Pricing-degradation behavior — when `.orchestrator/config/pricing.yml` is absent (or `pricing_is_stale` returns true), the predictive surface renders cost cells as `(unavailable)`, the recommendation still renders, the per-tier table is still produced (3 rows), and the override-cheaper-tier hint still appears (FR-24, US-5 AS-6).
  - Check: `bash scripts/verify/m027-p01-pricing-degradation.sh`

- `scripts/engine/intensity-recommend.sh` text default (no flag, or `--format text`) is byte-stable — the existing key=value lines (`intensity=`, `confidence=`, `reasoning=`, `scope=`, `risk_level=`, `complexity=`, `risk_signals=`, `cap_score=`) are emitted in the same order with the same shape as pre-M027; a per-tier cost-annotation block is appended AFTER the existing key=value lines, never interleaved (FR-20, CON-3 carry-forward, US-5 AS-2).
  - Check: `bash scripts/verify/m027-p01-intensity-text-back-compat.sh`

- `scripts/engine/intensity-recommend.sh --format json` emits the existing structured fields PLUS a top-level `cost_estimates` object keyed by tier (`quick`, `standard`, `full`); each tier object carries `cost_usd` (number-or-null), `input_tokens` (int), `output_tokens` (int), `pricing_warning` (string-or-empty), per D026; the JSON parses cleanly (single-line or pretty); cost_estimates is always present when `--format json` is set (FR-20, US-5 AS-2, D026).
  - Check: `bash scripts/verify/m027-p01-intensity-json-cost-estimates.sh`

- Read-only invariant carry-forward — `git diff --quiet` against the project tree after running `orchestrator:cost`, `orchestrator:cost --estimate`, and `intensity-recommend.sh --format json` against the live repo is exit 0; no JSONL records are emitted by P01 code paths (FR-12, CON-1, SC-9 carry-forward).
  - Check: `bash scripts/verify/m027-p01-read-only.sh`

- Runtime-adapter registration — running the Claude Code adapter `--register --dry-run` at the post-P01 codebase lists `commands/cost.md` among the would-write entries (`would_write=...orchestrator-cost.md`); same for the Codex CLI and Cursor adapters; this validates that M015/M025 packaging picks up the new command without code changes to the adapters (US-2 AS-3 surface; runtime-adapter contract).
  - Check: `bash scripts/verify/m027-p01-runtime-adapter-registration.sh`

- bash 3.2 compat — every M027/P01 shell script (`scripts/engine/cost-estimate.sh`, modifications under `scripts/engine/intensity-recommend.sh`, every `scripts/verify/m027-p01-*.sh`) does not match `(declare -A|mapfile|readarray|<<<|<\(|>\(|&>|\$\{[a-zA-Z_][a-zA-Z0-9_]*\^\^})` (CON-7, SC-11 carry-forward).
  - Check: `bash scripts/verify/m027-p01-bash32-compat.sh`

- `bash scripts/verify/m027-p01-suite.sh` orchestrates the full P01 verifier set (the named per-contract checks above), runs them in stable order (cheapest first, latency / live-invocation last), aggregates PASS/FAIL counts to stdout, and exits 0 on green / 1 on red (FR-15 carry-forward to P01 surface, mirrors P00's `m027-rollup-schema.sh` shape).
  - Check: `bash scripts/verify/m027-p01-suite.sh`

### Artifacts

- `commands/cost.md` (min 80 lines, contains "orchestrator:cost")
- `scripts/engine/cost-estimate.sh` (min 200 lines, contains "char-quartile")
- `scripts/engine/intensity-recommend.sh` (min 150 lines, contains "cost_estimates")
- `scripts/verify/m027-p01-suite.sh` (min 30 lines, contains "m027-p01")
- `scripts/verify/m027-p01-cost-command-shape.sh` (min 30 lines, contains "Accuracy")
- `scripts/verify/m027-p01-cost-retro-default.sh` (min 30 lines, contains "metrics-rollup")
- `scripts/verify/m027-p01-cost-estimate-table.sh` (min 40 lines, contains "Quick")
- `scripts/verify/m027-p01-predictive-goodhart-pairing.sh` (min 30 lines, contains "Goodhart")
- `scripts/verify/m027-p01-zero-llm-token.sh` (min 30 lines, contains "anthropic")
- `scripts/verify/m027-p01-predictive-latency.sh` (min 30 lines, contains "100")
- `scripts/verify/m027-p01-pricing-degradation.sh` (min 30 lines, contains "unavailable")
- `scripts/verify/m027-p01-intensity-text-back-compat.sh` (min 30 lines, contains "byte")
- `scripts/verify/m027-p01-intensity-json-cost-estimates.sh` (min 30 lines, contains "cost_estimates")
- `scripts/verify/m027-p01-read-only.sh` (min 30 lines, contains "git diff --quiet")
- `scripts/verify/m027-p01-runtime-adapter-registration.sh` (min 30 lines, contains "would_write")
- `scripts/verify/m027-p01-bash32-compat.sh` (min 30 lines, contains "declare -A")

### Key Links

- `commands/cost.md` → `scripts/diagnostics/metrics-rollup.sh` (retrospective surface delegates to the P00 engine)
- `commands/cost.md` → `scripts/engine/cost-estimate.sh` (predictive surface delegates to the new estimator)
- `scripts/engine/cost-estimate.sh` → `scripts/lib/pricing.sh` (sourced for `pricing_estimate_cost_usd`, `chars_to_tokens_quartile`, `pricing_warning_reason`, `pricing_file_present`, `pricing_is_stale`)
- `scripts/engine/cost-estimate.sh` → `scripts/engine/intensity-recommend.sh` (estimator consults the recommendation engine to mark the recommended tier)
- `scripts/engine/intensity-recommend.sh` → `scripts/engine/cost-estimate.sh` (cost-annotation hook sources the estimator to attach per-tier cost data)
- `scripts/verify/m027-p01-suite.sh` → `scripts/verify/m027-p01-cost-command-shape.sh` (orchestrated gate)
- `scripts/verify/m027-p01-suite.sh` → `scripts/verify/m027-p01-cost-retro-default.sh` (orchestrated gate)
- `scripts/verify/m027-p01-suite.sh` → `scripts/verify/m027-p01-cost-estimate-table.sh` (orchestrated gate)
- `scripts/verify/m027-p01-suite.sh` → `scripts/verify/m027-p01-predictive-goodhart-pairing.sh` (orchestrated gate)
- `scripts/verify/m027-p01-suite.sh` → `scripts/verify/m027-p01-zero-llm-token.sh` (orchestrated gate)
- `scripts/verify/m027-p01-suite.sh` → `scripts/verify/m027-p01-predictive-latency.sh` (orchestrated gate)
- `scripts/verify/m027-p01-suite.sh` → `scripts/verify/m027-p01-pricing-degradation.sh` (orchestrated gate)
- `scripts/verify/m027-p01-suite.sh` → `scripts/verify/m027-p01-intensity-text-back-compat.sh` (orchestrated gate)
- `scripts/verify/m027-p01-suite.sh` → `scripts/verify/m027-p01-intensity-json-cost-estimates.sh` (orchestrated gate)
- `scripts/verify/m027-p01-suite.sh` → `scripts/verify/m027-p01-read-only.sh` (orchestrated gate)
- `scripts/verify/m027-p01-suite.sh` → `scripts/verify/m027-p01-runtime-adapter-registration.sh` (orchestrated gate)
- `scripts/verify/m027-p01-suite.sh` → `scripts/verify/m027-p01-bash32-compat.sh` (orchestrated gate)

## Resolved Open Questions (planning-pinned)

- **#Q-14 (per-tier `cost_estimates` JSON shape)** — closed by `D026`. Default `--format text` keeps existing key=value lines byte-stable and appends a per-tier annotation block. `--format json` emits the existing structured fields PLUS a top-level `cost_estimates` object keyed by tier (`quick` / `standard` / `full`); each tier carries `cost_usd` (number-or-null), `input_tokens` (int), `output_tokens` (int), `pricing_warning` (string-or-empty). Verifier `m027-p01-intensity-json-cost-estimates.sh` enforces.
- **#Q-15 (predictive accuracy disclaimer copy)** — closed by `D027`. Verbatim disclaimer in `commands/cost.md` under an "Accuracy" subsection: *"Estimates use M019 char-quartile token approximation and pricing.yml rates; actual cost typically lands within +/-20%. Runtime-actuals calibration is Tier 3 (deferred)."* The `orchestrator:cost --estimate` output carries a one-line trailer: *"estimates +/-~20%; see commands/cost.md#accuracy"*. Verifier `m027-p01-cost-command-shape.sh` greps for the disclaimer and `m027-p01-cost-estimate-table.sh` greps for the trailer.

## Tasks

### T01: predictive cost estimator + zero-token char-quartile core (`scripts/engine/cost-estimate.sh`)

See `.orchestrator/milestones/M027/phases/P01/tasks/T01-cost-estimator-PLAN.md`.

### T02: `intensity-recommend.sh` cost-annotation hook + `--format json` `cost_estimates` field per D026

See `.orchestrator/milestones/M027/phases/P01/tasks/T02-intensity-recommend-hook-PLAN.md`.

### T03: `commands/cost.md` user-facing command + +/-20% accuracy disclaimer per D027

See `.orchestrator/milestones/M027/phases/P01/tasks/T03-cost-command-PLAN.md`.

### T04: P01 verifier suite (`m027-p01-suite.sh` + per-contract `m027-p01-*.sh`)

See `.orchestrator/milestones/M027/phases/P01/tasks/T04-verifier-suite-PLAN.md`.

## Task Dependencies

```
T01 ──► T02 ──► T03 ──► T04
```

Strictly sequential. T02 sources T01's `cost_estimate_per_tier` library function to attach per-tier cost data to the recommendation. T03's `commands/cost.md` documents both T01's predictive entry point and the P00 retrospective surface, and the `--estimate` flag delegates to T01's library. T04 verifies all three together and asserts the back-compat / latency / pricing-degradation contracts.

T01 cannot parallelize with T02: T02 reuses T01's library functions and library output shape. T03 cannot land before T01/T02 because the command documentation references the entry-point behavior they implement. T04's verifiers gate against the post-T03 codebase.

## Files Likely Touched

- commands/cost.md (create)
- scripts/engine/cost-estimate.sh (create)
- scripts/engine/intensity-recommend.sh (modify)
- scripts/verify/m027-p01-suite.sh (create)
- scripts/verify/m027-p01-cost-command-shape.sh (create)
- scripts/verify/m027-p01-cost-retro-default.sh (create)
- scripts/verify/m027-p01-cost-estimate-table.sh (create)
- scripts/verify/m027-p01-predictive-goodhart-pairing.sh (create)
- scripts/verify/m027-p01-zero-llm-token.sh (create)
- scripts/verify/m027-p01-predictive-latency.sh (create)
- scripts/verify/m027-p01-pricing-degradation.sh (create)
- scripts/verify/m027-p01-intensity-text-back-compat.sh (create)
- scripts/verify/m027-p01-intensity-json-cost-estimates.sh (create)
- scripts/verify/m027-p01-read-only.sh (create)
- scripts/verify/m027-p01-runtime-adapter-registration.sh (create)
- scripts/verify/m027-p01-bash32-compat.sh (create)
