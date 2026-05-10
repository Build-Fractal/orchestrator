---
schema_version: "1.0"
type: milestone-summary
id: "M019"
parent: "019-observability-metrics"
milestone: "M019"
provides:
  - "Tier 1 observability and efficiency metrics emitter producing payload_breakdown, dispatch_usage, and unit_close JSONL records at task/phase/milestone boundaries; Goodhart-paired cost+quality blocks on every unit_close; Opus 4.7 adapted dispatch baseline (L1 first-turn completeness, L2 stable-before-volatile ordering with <dispatch-volatile> markers, L3 adaptive-thinking contract, L4 parallel-fan-out directive, L5 positive-example rewrites); AD-7 sentinel-scoped settings overwrite; scripts/lib/pricing.sh sourceable pricing library with never-abort degradation; scripts/verify/m019-schema.sh JSONL validator with source/granularity/record_type enums reserved for Tier 2/3 forward compat; 12 verify gates (4 P00 + 8 P01) enforcing SC-6/SC-10/SC-12/SC-13 contracts"
requires:
  - "pre-M019 execution-log.jsonl schema; build-context.sh and dispatch-interface.sh hook points; write-summary.sh signatures; M011-M016 milestone completion baseline; Opus 4.7 reference model; M021 anti-pattern-lint/pre-bash-shape-guard/widened allow-list gates"
affects:
  - "M012/M013/M014 dogfooding; future Tier 2 rollup milestone; future Tier 3 backend-actuals milestone; derive-phase.sh and other current log consumers (unchanged); .claude/settings.json; templates/autonomy-defaults.yaml"
key_files:
  - "scripts/lib/pricing.sh,scripts/verify/m019-schema.sh,scripts/dispatch/build-context.sh,scripts/dispatch/dispatch-interface.sh,scripts/knowledge/write-summary.sh,scripts/lifecycle/write-permissions.sh,scripts/lifecycle/apply-sentinel-overwrite.sh,scripts/engine/intensity-gate.sh,templates/dispatch-prompt.md,templates/autonomy-defaults.yaml,.orchestrator/config/pricing.yml,.claude/settings.json,scripts/verify/m019-p00-phase-suite.sh,scripts/verify/m019-p01-phase-suite.sh,tests/fixtures/m019-p01/"
key_decisions:
  - "AD-1 char-quartile token estimate;AD-2 pricing file + ORCH_PRICING_FILE override;AD-3 quality from existing fields;AD-4 record_type/source/granularity enums;AD-5 stable-before-volatile ordering;AD-7 sentinel-scoped settings overwrite;AD-19 single-script Check shape;SC-6 byte-identical stdout;SC-10 pre-M019 additivity;SC-12 P00->P01 epoch 2026-04-18T02:21:28Z;SC-13 no regression;C2 Goodhart pairing;C4 never-abort pricing degradation;C5 bash 3.2"
patterns_established:
  - "Env-var side-channel for legacy-helper behavior injection;Zero-token instrumentation via stdout capture-and-replay;Byte-identical-modulo-normalization diff;Sentinel-scoped JSON span overwrite bash 3.2 no jq;Never-abort degradation via module-scoped warning channel;Module-scoped globals subshell loss workaround via mktemp capture;BSD awk in-keyword pitfall remedy;Split-needle self-match avoidance in pattern gates;Trap-safe mutate/restore;Hermetic tmp-snapshot pattern with ORCHESTRATOR_ROOT override;Filename-routed stub backend adapter;Directory-path artifact check;Lexical ISO-8601 timestamp comparison;Child-granularity pass_rate filter;Prefix-match any-null propagation in cost rollup"
drill_down_paths:
  - ".orchestrator/milestones/M019/phases/P00/P00-SUMMARY.md,.orchestrator/milestones/M019/phases/P01/P01-SUMMARY.md"
duration: "375m"
verification_result: "pass"
completed_at: "2026-04-18T04:18:24Z"
observability_surfaces:
  - "payload_breakdown, dispatch_usage, unit_close JSONL records; schema validator scripts/verify/m019-schema.sh; AD-4 enum definitions"
---

## What Was Built

M019 ships the Tier 1 observability & efficiency metrics stream on top of an Opus-4.7-adapted dispatch baseline. The milestone's vision was "produce measured, comparable data on time / tokens / $ / quality across task / phase / milestone granularities before [M012](../../milestones/M012/index.md)–[M014](../../milestones/M014/index.md) dogfooding begins, without building any Tier 2/3 surface" — and that is exactly what landed.

Two phases, strict linear ordering (P00 → P01):

### P00 — Opus 4.7 Baseline Adaptation (`a4b80fb`)

Five Opus-4.7 tactics (L1–L5) plus AD-7 settings-preflight fix and the P00 verify suite:

- **L1 First-Turn Completeness block** — `scripts/dispatch/build-context.sh` emits `## First-Turn Completeness` (Intent / Constraints / Acceptance Criteria / Files To Touch), structurally re-surfacing content already in the payload.
- **L2 Stable-before-volatile ordering** — sections wrapped in `<dispatch-volatile>` / `</dispatch-volatile>` markers; PLANNING branch stays byte-identical via an env-var side-channel.
- **L3 Adaptive-thinking contract** — `scripts/engine/intensity-gate.sh` documents the contract as a comment block; fixed-thinking-budget literals gone.
- **L4 Parallel-Fan-Out directive** — conditional `## Parallel Fan-Out` block emitted only when recipe or task plan declares parallelizable work.
- **L5 Positive-examples rewrite** — negative guidance rewritten positive; `templates/.p00-negative-guidance-retained.txt` whitelist reserved for Constitution XV prohibitions.
- **AD-7 fix** — `_generated_start` / `_generated_end` JSON-key sentinels in `scripts/lifecycle/write-permissions.sh` + new `apply-sentinel-overwrite.sh`; user-authored hooks and out-of-span allow-list entries survive evaluate-preflight re-runs byte-identical. [M021](../../milestones/M021/index.md) widened allow patterns promoted into `templates/autonomy-defaults.yaml` for canonical emission.
- **`.orchestrator/config/pricing.yml`** — Opus 4.7 ($15/$75/M), Sonnet 4.6 ($3/$15/M), Haiku 4.5 ($0.80/$4.00/M); `provider: anthropic`; `ORCH_PRICING_FILE` override documented.
- **P00 verify suite** — payload-shape, evaluate-preflight-additivity, no-regression (wraps tests/test-s01..s07 + anti-pattern-lint + M021/P04 phase-suite), bash32-compat, phase-suite. SC-13 regression gate closed — no pre-existing test required modification.

P00 closes at `2026-04-18T02:21:28Z` — this is the SC-12 epoch for P01.

### P01 — Tier 1 Emitter (`532f8d7` phase-close)

Three emitters, one schema validator, one pricing lib, eight per-gate verify scripts:

- **`scripts/lib/pricing.sh`** — sourceable bash 3.2 lib (9 functions: `pricing_file_path` / `pricing_last_updated` / `pricing_stale_days` / `pricing_is_stale` / `pricing_resolve_alias` / `pricing_lookup_rates` / `pricing_estimate_cost_usd` / `pricing_warning_reason` / `chars_to_tokens_quartile`); honors `ORCH_PRICING_FILE`; never aborts caller — returns empty + module-scoped `_PRICING_WARNING_REASON` on missing / stale / no-rate.
- **`scripts/verify/m019-schema.sh`** — pure-bash JSONL validator: `record_type`, `source: estimate | runtime | aggregate`, `granularity: task | phase | milestone` enums, `unit_close` cost + quality pairing, pre-M019 additivity.
- **`payload_breakdown`** emitter in `build-context.sh` — one record per invocation to `.orchestrator/milestones/<Mxxx>/execution-log.jsonl`; PAYLOAD_CAPTURE tempfile + `cat` preserves SC-6 byte-identical stdout.
- **`dispatch_usage`** emitter in `dispatch-interface.sh` — one record per invocation after BACKEND is resolved, on happy and three error paths (backend_crashed exit 5; backend_malformed schema / type exit 6); C4 pricing-degradation handling.
- **`unit_close`** emitter in `write-summary.sh` — one record per `task | phase | milestone` invocation, Goodhart-paired cost + quality blocks (cost summed from child payload_breakdown + dispatch_usage with null propagation; quality derived per AD-3 from existing `attempt` / `outcome` / `verification_result` fields, no new event surface).
- **8 P01 verify gates** — emitter-presence, pricing-degradation (trap-safe rename/restore), source-enum, zero-token-growth (byte-identical modulo hit_count normalization), additive-compat (pre-M019 logs still validate), fixture-rollup (SC-7 greppability demo — VERIFICATION ASSET only), no-pre-p00-emission (SC-12 ordering guard against `2026-04-18T02:21:28Z` epoch), bash32-compat.

No Tier 2/3 surface shipped — no `orchestrator:cost` command, no rollup script, no efficiency footer, no anomaly checks, no UI. All Tier 2/3 work lands additively.

## Cross-Cutting Patterns Established

- **Env-var side-channel for legacy-helper behavior injection** — `BC_STABLE_IDXS` / `BC_VOLATILE_ALL_IDXS` let the PLANNING branch preserve byte-identical output with no helper duplication (P00). `ORCH_M019_EMIT=0` early-return seam on all three emitters for SC-6 verification in-place (P01). Pattern: additive injection with empty-fallback to legacy behavior.
- **Zero-token instrumentation via stdout capture-and-replay** — PAYLOAD_CAPTURE tempfile + `cat` makes the emitter run strictly after stdout, contributing zero bytes. Generalizes to any "log this work without polluting the artifact" requirement.
- **Byte-identical-modulo-normalization diff** — strip legit-drift lines (e.g. `hit_count: N`) before `cmp` to isolate the contribution under test from orthogonal side-channel drift.
- **Sentinel-scoped JSON span overwrite** — line-oriented bash 3.2 replacement inside `_generated_start` / `_generated_end` JSON-key span with tail-comma auto-insertion; no jq dep. User-added content outside the span survives re-runs byte-identical; canonical content goes through `templates/autonomy-defaults.yaml`.
- **Never-abort degradation via module-scoped warning channel** — estimator returns empty + sets `_PRICING_WARNING_REASON`; emitter records `null` + `pricing_warning` and exits 0. Dispatch continues.
- **Module-scoped globals and subshell loss** — pricing lib's `_PRICING_WARNING_REASON` is set in whatever shell the estimator runs in; if you capture stdout via `$(...)` you lose the warning. T03 and downstream workarounds: capture via `mktemp` file so the estimator runs in the caller's shell.
- **BSD awk `in`-keyword pitfall** — awk variables starting with `in_` silently tokenize-zero on BSD awk. Use `ival`/`oval` or `index()` over `in`.
- **Split-needle self-match avoidance** — bash32-compat and anti-pattern gates embed their own forbidden patterns by splitting them across variable boundaries (M021/P04 pattern reused in P00/T05 and P01/T06).
- **Trap-safe mutate/restore** — pricing-degradation gate uses `trap EXIT INT TERM` to restore the renamed pricing.yml even on gate failure, so a flaky run never leaves the repo in a broken state.
- **Hermetic tmp-snapshot pattern** — fixture gates `cp -R` the fixture milestone to TMPDIR and export `ORCHESTRATOR_ROOT` to route emitter writes into the snapshot, never the live tree.

## Decisions Landed

- **AD-1** char-quartile token estimate; **AD-2** pricing file + `ORCH_PRICING_FILE` override; **AD-3** quality-from-existing-fields (no new event surface); **AD-4** three record_type enum + source enum + granularity enum; **AD-5** stable-before-volatile ordering; **AD-7** sentinel-scoped settings overwrite; **AD-19** single-script-file `Check:` shape.
- **SC-1** exactly-one-dispatch_usage-per-dispatch; **SC-2** exactly-one unit_close per write-summary; **SC-3** Goodhart cost+quality pairing mandatory; **SC-4** source + granularity enum additivity for Tier 2/3 forward compat; **SC-6** byte-identical stdout (zero-token instrumentation); **SC-7** fixture-rollup greppability demo; **SC-10** pre-M019 consumer additivity; **SC-12** P00→P01 hard ordering at epoch `2026-04-18T02:21:28Z`; **SC-13** no regression of existing tests/anti-pattern-lint/M021 P04.
- **C1** never abort on emission failure; **C2** Goodhart pairing mandatory; **C3** additive to pre-M019 output; **C4** never abort on pricing degradation; **C5** bash 3.2 compatibility.

## Verification Results

- `scripts/verify/m019-p00-phase-suite.sh` — PASS 4 / FAIL 0 (payload-shape, evaluate-preflight-additivity, no-regression, bash32-compat).
- `scripts/verify/m019-p01-phase-suite.sh` — PASS 8 / FAIL 0 (emitter-presence, pricing-degradation, source-enum, zero-token-growth, fixture-rollup, additive-compat, no-pre-p00-emission, bash32-compat).
- `scripts/verify/validate-milestone.sh` — 49/49 checks passed (phase summaries present, boundary maps consistent, key files on disk).
- Pre-existing suites preserved: `tests/test-s01..s07` green; `scripts/verify/anti-pattern-lint.sh` clean; `scripts/verify/run-suite.sh m021 P04` green.

## What M019 Delivers To M012–M014 (and Beyond)

M012–M014 dogfooding now runs on a measured baseline: every task / phase / milestone close produces a JSONL record with paired cost + quality, greppable by `record_type` and `granularity` against any `.orchestrator/milestones/<M>/execution-log.jsonl`. Tier 2 rollups and Tier 3 backend-actuals land additively — no Tier 1 rewrite needed. The `source: aggregate` enum value and `record_type` discriminator are already reserved; Tier 3 backend adapters plug into `scripts/dispatch/adapters/backend/` filename routing.

Follow-on work (NOT in M019 scope): `orchestrator:cost` command, rollup CLI, efficiency footer, anomaly detection, UI, backend-actuals adapters. All defer to M019 Tier 2 / Tier 3 milestones.
