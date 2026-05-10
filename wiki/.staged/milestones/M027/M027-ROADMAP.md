---
schema_version: "1.0"
type: roadmap
milestone: "M027"
feature_ref: "029-m019b-cost-rollup-tier2"
feature_spec: "specs/029-m019b-cost-rollup-tier2/spec.md"
vision: "Make M019 Tier 1 cost+quality data visible retrospectively (rollup CLI, cost command, status footer, doctor anomaly check) and actionable predictively (per-tier cost estimates at intensity-recommend and pre-dispatch time) — zero-LLM-token, read-only, Goodhart-paired."
tier: "C"
created_at: "2026-04-26T21:50:08Z"
updated_at: "2026-04-26T21:50:08Z"
---

## Phases

- [x] **P00**: Rollup engine + verifier — "metrics-rollup.sh prints a paired cost+quality milestone row for [M019](../../milestones/M019/index.md) in this repo and `scripts/verify/m027-rollup-schema.sh` exits 0 over a fixture suite covering aggregation precedence, source-filter, Goodhart pairing, byte-identity, read-only invariant, zero-LLM-token, and the 5s/10MB perf bound."
  - Risk: high
  - Depends: none
  - Boundary Map:
    - Produces: `scripts/diagnostics/metrics-rollup.sh` (sourceable library + CLI), `scripts/verify/m027-rollup-schema.sh`, aggregation-precedence contract (FR-18), source-filter contract (FR-3), Goodhart output-pairing contract (FR-4), copy-then-aggregate FS-race semantics (FR-19), input-schema validation (FR-17), corrupt-line tolerance (FR-14), pricing-warning surface (FR-11), perf-bound regression gate (CON-12/SC-13)
    - Consumes: M019 Tier 1 JSONL records (`payload_breakdown`, `dispatch_usage`, `unit_close`), `scripts/lib/pricing.sh`, `scripts/verify/m019-schema.sh`, char-quartile token approximation (M019 AD-1)

- [x] **P01**: `orchestrator:cost` retrospective + predictive command — "Invoking `orchestrator:cost` on Claude Code, Codex CLI, or Cursor prints the active-milestone rollup; `orchestrator:cost --estimate \"<task>\"` prints a per-tier (Quick/Standard/Full) cost+quality table with the recommended tier marked in <100ms and zero LLM tokens; `intensity-recommend.sh` output now carries per-tier cost annotations (text default, opt-in `--format json`)."
  - Risk: medium
  - Depends: P00
  - Boundary Map:
    - Produces: `commands/cost.md` (command definition with ±~20% accuracy disclaimer), runtime-adapter registration of `orchestrator:cost` via M015/[M025](../../milestones/M025/index.md) packaging layer (Claude Code skill, Codex CLI command, Cursor command), predictive estimator entry points (`--estimate <description>` flag, `intensity-recommend.sh` cost-annotation hook, optional `--format json` `cost_estimates` field), zero-LLM-token contract for predictive code paths (FR-21), <100ms predictive latency contract (FR-22), pricing-degradation behavior for predictive surface (FR-24)
    - Consumes: P00 rollup engine (sourced as library), P00 Goodhart-pairing contract (extended to predictive output per CON-4 / SC-18), `scripts/lib/pricing.sh`, `scripts/engine/intensity-recommend.sh` (existing), M015/M025 packaging adapters, M019 char-quartile token approximation

- [x] **P02**: Efficiency footer + dispatch-time predictive surface — "`orchestrator:status` (default) prints an efficiency footer below its existing output; `orchestrator:status --quiet` and `config.efficiency_footer: false` produce byte-identical output to pre-M027; interactive `orchestrator:dispatch` at Standard or Full surfaces a one-block predictive view with one-keystroke override; under `--yes`, `orchestrator:auto`, or `config.predictive_cost_surface: false`, dispatch output is byte-identical to pre-M027."
  - Risk: medium
  - Depends: P01
  - Boundary Map:
    - Produces: efficiency footer hook in `commands/status.md` and supporting script, `config.efficiency_footer` knob (default `true`), `config.predictive_cost_surface` knob (default `true`), dispatch-time predictive confirmation surface in interactive `orchestrator:dispatch` path, suppression semantics for `--quiet`/`--yes`/`orchestrator:auto`, byte-identity invariant cases for the P00 verifier (SC-3 status-quiet, SC-17 dispatch-yes)
    - Consumes: P00 rollup engine (footer summary), P01 predictive estimator (dispatch-time surface), P01 cost annotations (intensity-recommend output), existing `orchestrator:status` and `orchestrator:dispatch` command surfaces

- [x] **P03**: Anomaly detection + config-check — "`orchestrator:doctor` against a fixture milestone with one ≥3× cost outlier among 9 sibling dispatches flags exactly one anomaly with paired cost+quality data; against a 4-dispatch milestone (below sample floor) it prints \"insufficient sample\" and skips the check; `orchestrator:doctor --config-check` flags drift in `efficiency_footer` and `predictive_cost_surface` config across team environments."
  - Risk: low
  - Depends: P00, P02
  - Boundary Map:
    - Produces: anomaly-check pass in `commands/doctor.md`, `--config-check` flag on `orchestrator:doctor`, anomaly threshold config defaults (cost multiplier, retry/pass-rate thresholds — pinned by plan-phase per #Q-1 sampling), sample-floor logic (default 5; CON-8), Goodhart-paired anomaly diagnostic surface (FR-9), advisory exit-code semantics (never blocks autonomous mode; FR-8)
    - Consumes: P00 rollup engine (baseline math, median computation), P02 config knobs (`efficiency_footer`, `predictive_cost_surface` for `--config-check`), existing `orchestrator:doctor` diagnostic surface

## Cross-Cutting Concerns

- **Goodhart output pairing (CON-4)** — P00, P01, P02, P03. P00 establishes the verifier contract (FR-4 + SC-12) that every cost column carries a paired quality column on the same row; P01 extends pairing to the predictive surface (FR-20 + SC-18); P02 inherits via the footer + dispatch-time surface; P03 inherits via the anomaly diagnostic (FR-9). The P00 verifier rejects any output schema that drops one without the other.
- **Read-only invariant (CON-1, FR-12, SC-9)** — P00, P01, P02, P03. No M027 code path writes to or rewrites `execution-log.jsonl`. P00 ships the `git diff --quiet` post-fixture verifier case; P01/P02/P03 conform.
- **Byte-identity back-compat (CON-3)** — owner P02; verifier owner P00. `orchestrator:status --quiet` (SC-3) and `orchestrator:dispatch --yes` / under `orchestrator:auto` (SC-17) must be byte-identical to pre-M027 output. P00's verifier carries both byte-identity cases; P02 implements the suppression paths that satisfy them.
- **Zero-LLM-token (CON-6, FR-21, SC-16)** — P00, P01, P02, P03. All M027 code paths are bash-only. P00's verifier greps the M027 script set for forbidden LLM-invocation patterns (e.g., `claude_chat`, `anthropic`, dispatch-interface invocations from predictive code paths).
- **Never-abort / graceful degradation (CON-5)** — P00, P01, P02, P03. Missing `pricing.yml`, corrupt JSONL, missing milestones, FS races, missing config — all degrade to a tagged surface, never abort. P00 establishes the patterns (FR-11 pricing-warning surface, FR-14 corrupt-line tolerance, FR-19 FS-race handling); downstream phases inherit them.
- **bash 3.2 compat (CON-7, SC-11)** — P00, P01, P02, P03. No associative arrays, no `<<<` herestrings, no `mapfile`. Project-wide constitution requirement.
- **Runtime-adapter parity (Claude Code / Codex CLI / Cursor)** — owner P01; inherited by P02. P01 ships the new `orchestrator:cost` registration; P02's footer + dispatch-time surface piggyback on already-registered `orchestrator:status` and `orchestrator:dispatch`. Per AD-4, no new packaging-layer work is required beyond what M015/M025 established.
- **Operator override preservation (CON-10)** — owner P02. Every dispatch-time predictive surface preserves a one-keystroke override. P02 implements; P01's `--estimate` query has no override surface (it is purely informational).

## Dependency Graph

```
P00 ──► P01 ──► P02 ──► P03
 │                       ▲
 └───────────────────────┘
```

P00 is the dependency root. P01 depends on P00 only. P02 depends on P01 (and transitively P00). P03 depends on both P00 (engine for baseline math) and P02 (config keys it audits). Strictly sequential — no concurrent phases.

## Execution Order

1. **P00** — foundation, no dependencies. Risk-ordered first per FR-043 (high risk).
2. **P01** — depends on P00. Medium risk. Cannot execute concurrently with P00 (consumes the engine).
3. **P02** — depends on P01. Medium risk. Cannot execute concurrently with P01 (consumes the predictive estimator + cost annotations).
4. **P03** — depends on P00 and P02. Low risk. Cannot execute concurrently with P02 (audits the config keys P02 introduces).

No parallelizable phase pairs. Internal parallelization within P02 (footer hook and dispatch-time surface are independent) is left to plan-phase.

## Validation

- **No conflicting producers**: PASS. Each produced artifact is owned by exactly one phase. P00 owns `metrics-rollup.sh` + `m027-rollup-schema.sh`; P01 owns `commands/cost.md` + `orchestrator:cost` registration + predictive estimator entry points; P02 owns the efficiency-footer hook + the two config knobs + the dispatch-time predictive surface; P03 owns the doctor anomaly check + `--config-check`.
- **All consumed items have producers**: PASS. P01 consumes from P00 (rollup engine, Goodhart contract). P02 consumes from P00 (rollup engine for footer summary) and P01 (predictive estimator + annotations). P03 consumes from P00 (engine) and P02 (config knobs). Out-of-milestone consumption (M019 Tier 1 JSONL, `pricing.sh`, M015/M025 packaging adapters, existing `status`/`dispatch`/`doctor` surfaces) is documented in the spec's Dependencies section.
- **DAG is acyclic**: PASS. Topological order P00 → P01 → P02 → P03 with no back-edges.
- **Demo sentence coverage**: PASS. Each phase's demo sentence names a concrete invocation, expected observable output, and a verifier or byte-identity check tied to a numbered SC in the spec.
