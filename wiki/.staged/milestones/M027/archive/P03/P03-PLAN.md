---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M027"
goal: "Ship the final M027 surfaces — (a) an anomaly-detection helper (`scripts/diagnostics/check-anomalies.sh`) that surfaces dispatches whose cost and/or quality deviates from the per-milestone moving baseline by ≥ a configurable multiplier, scoped by a sample-size floor (default 5; CON-8) and pairing cost+quality on every flagged row (FR-9 / CON-4 inheritance from P00); (b) a config-drift helper (`scripts/diagnostics/check-config-drift.sh`) backing `orchestrator:doctor --config-check` that flags drift in the M027 config knobs `efficiency_footer` and `predictive_cost_surface` across env / local / project / defaults layers (FR-16); (c) integration of both surfaces into `commands/doctor.md` at a stable attach point (Document-shaped phase-task pattern from P02/T02) plus wiring into `scripts/diagnostics/run-doctor.sh`; (d) three new advisory anomaly-threshold config knobs (`anomaly_cost_multiplier`, `anomaly_retry_threshold`, `anomaly_pass_rate_threshold`) registered in `scripts/state/read-config.sh` `VALID_KEYS`. Both surfaces are read-only (FR-12 / CON-1), zero-LLM-token (FR-21 / CON-6), bash 3.2 (CON-7), advisory-only (never blocks autonomous mode; FR-8), Goodhart-paired at the alerting surface (CON-4 / FR-9), and respect a 5-condition suppression matrix mirroring P02 (`--no-anomaly` flag, `ORCHESTRATOR_AUTO=1`, `anomaly_check_enabled: false` config knob, `--yes` operator override on `run-doctor.sh`, sample-size-below-floor — the last is a structural carve-out, like quick-tier in P02). Ship a P03 verifier suite mirroring P02/T04 shape that gates anomaly-detection contract semantics, config-drift contract semantics, document-shape integrity, doctor-output byte-identity (suppressed mode), Goodhart pairing, suppression matrix, latency (inner-vs-outer split per P01/P02 pattern with hard-fail at 250ms inner against the largest existing milestone log), zero-LLM-token, read-only invariant, and bash 3.2 compat."
demo_sentence: "A developer (1) runs `bash scripts/diagnostics/check-anomalies.sh --milestone M013` against this repo (one of the largest existing logs at 26.6KB / 110+ records) and stdout shows a one-block anomaly report (≤ 12 lines) listing each flagged dispatch with paired cost+quality fields per row, completing in < 1 s wall-clock; (2) runs the same command against `--milestone M021` (4-record log, below the sample floor) and stdout shows `ANOMALY: insufficient sample (n=4 floor=5)` and exits 0; (3) runs `bash scripts/diagnostics/check-config-drift.sh --keys efficiency_footer,predictive_cost_surface` and stdout shows a paired drift report listing each layer's resolved value per key (or `(unset)`), exit 0; (4) runs `bash scripts/diagnostics/run-doctor.sh` and the output now includes a `--- Anomaly Detection ---` block (advisory; does not flip overall HEALTHY status); (5) runs `bash scripts/diagnostics/run-doctor.sh --config-check` and the output includes a `--- Config Drift ---` block listing the M027 knobs; (6) runs both helpers under `--no-anomaly` / `ORCHESTRATOR_AUTO=1` / `anomaly_check_enabled: false` and stdout is byte-identical to suppressed-mode output (zero anomaly block); (7) `bash scripts/verify/m027-p03-suite.sh` exits 0 (all 11 P03 contract gates green); (8) `git diff --quiet` after every above invocation exits 0 (FR-12 carry-forward)."
risk: "low"
depends_on: ["P00", "P02"]
---

## Resolved Open Questions (planning-pinned)

- **#Q-1 (anomaly-threshold defaults)** — **closed in this plan.** Sampling of duration_s values across [M012](../../../../milestones/M012/index.md), [M013](../../../../milestones/M013/index.md), [M025](../../../../milestones/M025/index.md), [M026](../../../../milestones/M026/index.md), M027 execution logs (≈110+ datapoints; `estimated_cost_usd` is null in current data so duration_s is the load-bearing surrogate the helper uses for anomaly math until Tier 3 backend-actuals lands) shows a wide spread: min 0s, p50 ≈1500s, p95 ≈13000s, max 18300s. A 3× multiplier flags ~10–15% of dispatches against the median; a 4× multiplier flags ~5–7%. **Defaults pinned**: `anomaly_cost_multiplier=3.0` (cost or duration ≥ 3× milestone median flags an anomaly — operator can dial up to 4.0 to reduce noise), `anomaly_retry_threshold=2` (`retry_count > 2` flags an anomaly), `anomaly_pass_rate_threshold=0.5` (`verification_pass_rate < 0.5` flags an anomaly). All three are configurable via `scripts/state/read-config.sh` keys (T01 registers them in `VALID_KEYS`). Cost field semantics: when `estimated_cost_usd` is non-null, anomaly math is on cost; when null (current state of every existing milestone log), anomaly math falls back to `duration_s` and the per-row diagnostic carries `cost=(unavailable; fallback=duration)` per CON-5 / FR-24 carry-forward. Sample floor pinned at the spec default of 5 (CON-8) — the [M021](../../../../milestones/M021/index.md) log (4 records) is the natural test fixture for the below-floor path.

- **#Q-5 (doctor anomaly perf at largest existing log)** — **closed in this plan.** Measured: `time bash scripts/diagnostics/metrics-rollup.sh --granularity task --milestone M013` against the largest existing milestone log (26.6 KB, 110+ records) reports ~56 ms wall-clock end-to-end. The anomaly check adds one additional awk pass over the same normalized data plus one median computation per scope — bounded above by 2× the rollup latency, so ~120 ms upper bound. Well under the 1 s "doctor feels laggy" threshold. **No `--no-anomaly` flag is required for performance**; the flag is added anyway as one of the 5 suppression-matrix conditions for operator-visibility parity with P02. Latency verifier still applies the **inner-vs-outer split** (hard-fail at 250 ms inner against M013, outer reported informationally with `WARN: RELAX-CANDIDATE` if > 500 ms — outer includes `metrics-rollup.sh` cold-fork on macOS plus bash startup overhead per the P01/P02 lesson). The verifier exercises against `.orchestrator/milestones/M013/execution-log.jsonl` since it is the largest existing-milestone log and gives the most realistic perf signal; if the inner threshold is breached, the verifier's `RELAX-CANDIDATE` annotation captures evidence for a future plan-phase relaxation rather than blocking M027 close.

- **#Q-10 (anomaly baseline disclaimer text)** — **closed in this plan.** Pinned exact wording in `commands/doctor.md` (T02 attach point, inside the new `## Anomaly Detection` section): **"Anomaly detection uses a per-milestone moving median as the baseline. The baseline normalizes whatever historical data is present, including systematic errors — a milestone that consistently runs slow normalizes the slowness as expected. Findings are advisory and never block autonomous mode (FR-8). When `estimated_cost_usd` is null in the underlying records (current default in pre-Tier-3 data), the multiplier is applied to `duration_s` as a fallback surrogate; the per-row diagnostic surfaces `cost=(unavailable; fallback=duration)` so operators see the substitution. Corruption-recovery — re-baselining after recovering from a known systematic error — is deferred (Tier 3 backend-actuals work)."** This text is asserted verbatim by `scripts/verify/m027-p03-doctor-md-shape.sh` as part of the document-shape gate. It addresses the median-normalizes-systematic-errors trap surfaced by the conversus advisory without inventing a re-baselining mechanism that M027 cannot ship without runtime-actuals.

- **#Q-11 (mixed-source UX)** — **deferred** beyond M027. The current data has no `source: runtime` records (Tier 3 not yet shipped), so any UX choice now would be premature. Re-open at the start of [M019](../../../../milestones/M019/index.md) Tier 3 planning when the runtime records exist to design against.

## Must-Haves

<!-- Each truth is a behavioral statement + a single-script-file Check (AD-19).
     Per the M027/P00 + M027/P01 + M027/P02 parser-shape lesson: every Check
     command references ONLY artifacts T01..T04 of THIS phase produces, never
     future tasks. All P03 verification logic lives in scripts/verify/m027-p03-*.sh
     files shipped in T04. The Truths-list `Check:` commands here are
     phase-boundary checks (run after T04 lands); each task plan defines its
     OWN single-script-file Verification block referencing only that task's
     artifacts. -->

### Truths

- `scripts/diagnostics/check-anomalies.sh` exists, is executable, sourceable, and accepts `--milestone <Mxxx>`, `--project`, `--no-anomaly`, `--yes`, `--config-defaults <path>`, `--threshold <multiplier>`, `--sample-floor <N>`, `--help` flags. CLI mode (no `--no-anomaly`) emits an anomaly block (≤ 12 lines) prefixed with the literal title `Anomaly Detection (Tier 1 baseline)`. Each flagged dispatch line carries paired cost (or `cost=(unavailable; fallback=duration)`) AND quality (`pass_rate=`, `retry_count=`) tokens — Goodhart at the alerting surface (FR-9 / CON-4). When sample size is below the floor (default 5), emits exactly the literal `ANOMALY: insufficient sample (n=<N> floor=<F>)` and exits 0 (FR-10 / CON-8). Reads via `scripts/diagnostics/metrics-rollup.sh` (sourced or forked); never writes to `execution-log.jsonl` (FR-12 carry-forward). Suppressed mode (`--no-anomaly`, `ORCHESTRATOR_AUTO=1`, `ORCH_ANOMALY_CHECK_ENABLED=false`, `anomaly_check_enabled: false` config knob, `--yes`) emits exactly zero stdout, exit 0 — the load-bearing CON-3-equivalent contract that T04's byte-identity verifier gates against.
  - Check: `bash scripts/verify/m027-p03-anomaly-shape.sh`

- `scripts/diagnostics/check-config-drift.sh` exists, is executable, sourceable, and accepts `--keys <comma-separated>`, `--key <single>`, `--no-config-check`, `--config-defaults <path>`, `--help` flags. CLI mode emits a one-block drift report (≤ 4 lines per audited key) prefixed with the literal title `Config Drift (M027 knobs)`. For each audited key, surfaces the resolved value at each layer (`env=`, `local=`, `project=`, `defaults=`) plus a final `effective=<value>` line per FR-16. Default `--keys` value is `efficiency_footer,predictive_cost_surface,anomaly_cost_multiplier,anomaly_retry_threshold,anomaly_pass_rate_threshold` (the four M027/P02 + three M027/P03 knobs). Reads via `scripts/state/read-config.sh`; never writes to disk. Read-only (FR-12).
  - Check: `bash scripts/verify/m027-p03-config-drift-shape.sh`

- `commands/doctor.md` is updated to document the anomaly-detection pass and the `--config-check` flag. Two new sections inserted at stable attach points: `## Anomaly Detection` (after `## Runtime Instruction Drift`, before `## Usage`) and `## Config Drift` (after `## Anomaly Detection`, before `## Usage`). Pre-edit canonical sections preserved in pre-edit order — no re-ordering, no rewording of pre-existing prose. The new sections document the helper invocation, the 5-condition suppression matrix (anomaly only; config-check is single-flag), the sample-floor semantics, the baseline-disclaimer text (#Q-10 verbatim), and reference both helpers in the `## Referenced Scripts` section. (FR-8, FR-16, US-4 AS-1–AS-4, MEM012.)
  - Check: `bash scripts/verify/m027-p03-doctor-md-shape.sh`

- Doctor byte-identity (suppressed mode) — `commands/doctor.md`'s post-`## Referenced Scripts` tail is byte-identical to the captured T02 fixture. The fixture baseline lives at `tests/fixtures/m027-p03/doctor-suppressed-baseline.txt`. The verifier diffs the live tail against the fixture; failure if `diff` exits non-zero. Mirrors the P02/T02 + T04 document-shaped phase-task byte-identity pattern; the new sections are the ONLY structural additions, plus one bullet under `## Referenced Scripts`.
  - Check: `bash scripts/verify/m027-p03-doctor-byte-identity.sh`

- Anomaly suppression matrix is exhaustively enforced — `check-anomalies.sh` emits exactly zero stdout under each of: `--no-anomaly`, `ORCHESTRATOR_AUTO=1`, `ORCH_ANOMALY_CHECK_ENABLED=false`, `--yes`, sample-size-below-floor (a structural carve-out — when the milestone has fewer than `anomaly_sample_floor` records, the helper still emits the `ANOMALY: insufficient sample` line in default mode, but under any of the four suppression flags the surface stays empty). The verifier exercises all five paths against a deterministic invocation and asserts the contract per path. (FR-8 advisory contract, CON-3-equivalent.)
  - Check: `bash scripts/verify/m027-p03-suppression-matrix.sh`

- `run-doctor.sh` integration — `scripts/diagnostics/run-doctor.sh` invokes `check-anomalies.sh` as an advisory check (`run_check "Anomaly Detection" "$SCRIPT_DIR/check-anomalies.sh" "" "1"` — the trailing `"1"` arg is the existing advisory flag in run-doctor's runner). The check appears below `Runtime Instruction Drift` and above `Graph Health`. Under `--config-check` (new flag added to `run-doctor.sh`'s arg-parse loop), additionally invokes `check-config-drift.sh` as an advisory check. The verifier asserts both `run_check` invocations are present and that `--config-check` is documented in the arg-parse loop.
  - Check: `bash scripts/verify/m027-p03-run-doctor-integration.sh`

- Anomaly-detection latency — inner measurement: `time bash scripts/diagnostics/check-anomalies.sh --milestone M013` against the largest existing milestone log (~26 KB, 110+ records) reports wall-clock under 250 ms with the inner fast-path (`METRICS_ROLLUP_FAST_PATH=1` if applicable; otherwise the same env-var pre-set as in P01/P02 patterns) — hard-fail at 250 ms (per the P01/P02 latency outer-vs-inner split lesson). Outer measurement (full fork chain including `metrics-rollup.sh`) reported informationally with `WARN: RELAX-CANDIDATE: outer-wall-clock measured=<N>ms target=250ms (~150ms macOS bash startup + rollup-fork overhead)` if it exceeds 500 ms. The outer threshold does NOT fail the gate. (FR-8 perf carry-forward, #Q-5 resolution, lesson #3 from P02 carry-forward.)
  - Check: `bash scripts/verify/m027-p03-anomaly-latency.sh`

- Anomaly Goodhart pairing on the alerting surface — every line of the anomaly-detection helper output that lists a flagged dispatch contains BOTH a cost token (`cost=` or `cost=(unavailable; fallback=duration)`) AND a quality token (`pass_rate=` or `retry_count=`) on the SAME row. The verifier exercises the helper against a fixture milestone log containing one ≥ 3× cost (or duration) outlier among 9 sibling dispatches and asserts the flagged row contains both tokens. Failure if any flagged row is cost-without-quality or quality-without-cost. (FR-9, CON-4 carry-forward, US-4 AS-3.)
  - Check: `bash scripts/verify/m027-p03-anomaly-goodhart-pairing.sh`

- Zero-LLM-token contract — grepping the M027/P03 script set (`scripts/diagnostics/check-anomalies.sh`, `scripts/diagnostics/check-config-drift.sh`, every `scripts/verify/m027-p03-*.sh`) for forbidden LLM-invocation patterns (`claude_chat`, `anthropic`, `dispatch-interface.sh`, `dispatch_task`, `subagent`) returns no matches. Carries forward the FR-21 / CON-6 / SC-16 contract from P00/P01/P02 to P03's new helpers.
  - Check: `bash scripts/verify/m027-p03-zero-llm-token.sh`

- Read-only invariant carry-forward — `git diff --quiet` against the project tree after running `check-anomalies.sh` (default mode against M013 + suppressed mode), `check-config-drift.sh` (default + suppressed), and `run-doctor.sh --config-check` against the live repo is exit 0; no JSONL records emitted by P03 code paths; no config files modified. The verifier captures a pre-run `git diff --quiet` exit; if dirty, it skips with `WARN: working-tree-dirty pre-run; skipping read-only assertion` (mirrors P01/P02/T04 pattern). (FR-12, CON-1, SC-9 carry-forward.)
  - Check: `bash scripts/verify/m027-p03-read-only.sh`

- bash 3.2 compat — every M027/P03 shell script (`scripts/diagnostics/check-anomalies.sh`, `scripts/diagnostics/check-config-drift.sh`, every `scripts/verify/m027-p03-*.sh`, plus `commands/doctor.md`) does not match the forbidden-construct regex (no associative arrays, no herestring redirect, no mapfile, no process substitution, no merged stdout-stderr shorthand, no case-folding parameter expansion). Verifier excludes itself from the scan via explicit file list (mirrors P02/T04 carve-out). Comment-hygiene-for-verifier-regex: doc-comments use safe phrasing per the M027/P00+P01+P02 lesson.
  - Check: `bash scripts/verify/m027-p03-bash32-compat.sh`

- `bash scripts/verify/m027-p03-suite.sh` orchestrates the full P03 verifier set (the named per-contract checks above), runs them in stable order (cheapest static checks first, latency / live-invocation last), aggregates PASS/FAIL counts to stdout, forwards `WARN: RELAX-CANDIDATE` annotations from the latency gate to stdout, and exits 0 on green / 1 on red (mirrors P00's `m027-rollup-schema.sh`, P01's `m027-p01-suite.sh`, and P02's `m027-p02-suite.sh` shape).
  - Check: `bash scripts/verify/m027-p03-suite.sh`

### Artifacts

- `scripts/diagnostics/check-anomalies.sh` (min 120 lines, contains "Anomaly Detection (Tier 1 baseline)")
- `scripts/diagnostics/check-config-drift.sh` (min 80 lines, contains "Config Drift (M027 knobs)")
- `commands/doctor.md` (min 60 lines, contains "## Anomaly Detection")
- `tests/fixtures/m027-p03/doctor-suppressed-baseline.txt` (min 1 lines, contains "Referenced Scripts")
- `tests/fixtures/m027-p03/anomaly-fixture.jsonl` (min 9 lines, contains "unit_close")
- `tests/fixtures/m027-p03/README.md` (min 5 lines, contains "fixture")
- `scripts/state/read-config.sh` (min 70 lines, contains "anomaly_cost_multiplier")
- `scripts/diagnostics/run-doctor.sh` (min 140 lines, contains "Anomaly Detection")
- `scripts/verify/m027-p03-suite.sh` (min 30 lines, contains "m027-p03")
- `scripts/verify/m027-p03-anomaly-shape.sh` (min 30 lines, contains "Anomaly Detection (Tier 1 baseline)")
- `scripts/verify/m027-p03-config-drift-shape.sh` (min 30 lines, contains "Config Drift (M027 knobs)")
- `scripts/verify/m027-p03-doctor-md-shape.sh` (min 30 lines, contains "## Anomaly Detection")
- `scripts/verify/m027-p03-doctor-byte-identity.sh` (min 30 lines, contains "diff")
- `scripts/verify/m027-p03-suppression-matrix.sh` (min 30 lines, contains "no-anomaly")
- `scripts/verify/m027-p03-run-doctor-integration.sh` (min 30 lines, contains "config-check")
- `scripts/verify/m027-p03-anomaly-latency.sh` (min 30 lines, contains "250")
- `scripts/verify/m027-p03-anomaly-goodhart-pairing.sh` (min 30 lines, contains "Goodhart")
- `scripts/verify/m027-p03-zero-llm-token.sh` (min 30 lines, contains "anthropic")
- `scripts/verify/m027-p03-read-only.sh` (min 30 lines, contains "git diff --quiet")
- `scripts/verify/m027-p03-bash32-compat.sh` (min 30 lines, contains "declare -A")

### Key Links

- `commands/doctor.md` → `scripts/diagnostics/check-anomalies.sh` (anomaly surface delegates to the new helper)
- `commands/doctor.md` → `scripts/diagnostics/check-config-drift.sh` (config-drift surface delegates to the new helper)
- `commands/doctor.md` → `scripts/diagnostics/metrics-rollup.sh` (transitive — anomaly helper wraps the P00 rollup engine)
- `scripts/diagnostics/check-anomalies.sh` → `scripts/diagnostics/metrics-rollup.sh` (sources or forks the P00 engine for milestone-to-date aggregates and per-task records)
- `scripts/diagnostics/check-anomalies.sh` → `scripts/state/read-config.sh` (reads `anomaly_cost_multiplier`, `anomaly_retry_threshold`, `anomaly_pass_rate_threshold`, `anomaly_check_enabled` config knobs)
- `scripts/diagnostics/check-config-drift.sh` → `scripts/state/read-config.sh` (queries each config layer for each audited key)
- `scripts/diagnostics/run-doctor.sh` → `scripts/diagnostics/check-anomalies.sh` (advisory `run_check` integration)
- `scripts/diagnostics/run-doctor.sh` → `scripts/diagnostics/check-config-drift.sh` (advisory `run_check` integration under `--config-check`)
- `scripts/verify/m027-p03-suite.sh` → `scripts/verify/m027-p03-anomaly-shape.sh` (orchestrated gate)
- `scripts/verify/m027-p03-suite.sh` → `scripts/verify/m027-p03-config-drift-shape.sh` (orchestrated gate)
- `scripts/verify/m027-p03-suite.sh` → `scripts/verify/m027-p03-doctor-md-shape.sh` (orchestrated gate)
- `scripts/verify/m027-p03-suite.sh` → `scripts/verify/m027-p03-doctor-byte-identity.sh` (orchestrated gate)
- `scripts/verify/m027-p03-suite.sh` → `scripts/verify/m027-p03-suppression-matrix.sh` (orchestrated gate)
- `scripts/verify/m027-p03-suite.sh` → `scripts/verify/m027-p03-run-doctor-integration.sh` (orchestrated gate)
- `scripts/verify/m027-p03-suite.sh` → `scripts/verify/m027-p03-anomaly-latency.sh` (orchestrated gate)
- `scripts/verify/m027-p03-suite.sh` → `scripts/verify/m027-p03-anomaly-goodhart-pairing.sh` (orchestrated gate)
- `scripts/verify/m027-p03-suite.sh` → `scripts/verify/m027-p03-zero-llm-token.sh` (orchestrated gate)
- `scripts/verify/m027-p03-suite.sh` → `scripts/verify/m027-p03-read-only.sh` (orchestrated gate)
- `scripts/verify/m027-p03-suite.sh` → `scripts/verify/m027-p03-bash32-compat.sh` (orchestrated gate)

## Tasks

### T01: anomaly-detection helper + 4 anomaly config knobs (`scripts/diagnostics/check-anomalies.sh`)

See `.orchestrator/milestones/M027/phases/P03/tasks/T01-anomaly-helper-PLAN.md`.

### T02: config-drift helper + `commands/doctor.md` integration + fixture suite (`scripts/diagnostics/check-config-drift.sh`)

See `.orchestrator/milestones/M027/phases/P03/tasks/T02-config-drift-and-doctor-md-PLAN.md`.

### T03: `run-doctor.sh` integration (`--config-check` flag + advisory invocations of T01 + T02)

See `.orchestrator/milestones/M027/phases/P03/tasks/T03-run-doctor-integration-PLAN.md`.

### T04: P03 verifier suite (`m027-p03-suite.sh` + per-contract `m027-p03-*.sh`)

See `.orchestrator/milestones/M027/phases/P03/tasks/T04-verifier-suite-PLAN.md`.

## Task Dependencies

```
T01 ──► T02 ──► T03 ──► T04
            │
T01 ────────┴──► T03
```

T01 ships the anomaly-detection helper and registers the four anomaly-related config knobs in `read-config.sh` `VALID_KEYS`. It has no upstream P03 dependencies (consumes P00's `metrics-rollup.sh` and P02's `read-config.sh` extensions). T02 ships the config-drift helper, the `commands/doctor.md` integration, and the byte-identity baseline fixture (depends on T01 because the doctor.md text references both helpers and the byte-identity tail captures both new sections). T03 wires both helpers into `run-doctor.sh` (depends on T01 + T02 to know the helper invocation shapes). T04 verifies all three together and asserts the byte-identity / suppression / latency / Goodhart-pairing / read-only / bash-3.2 / zero-LLM-token contracts.

T01 is a strict predecessor of both T02 and T03. T02 is a strict predecessor of T03 (T03 references the `--config-check` text added by T02). T04 depends on T01 + T02 + T03.

## Files Likely Touched

- scripts/diagnostics/check-anomalies.sh (create)
- scripts/diagnostics/check-config-drift.sh (create)
- scripts/diagnostics/run-doctor.sh (modify)
- scripts/state/read-config.sh (modify)
- commands/doctor.md (modify)
- tests/fixtures/m027-p03/doctor-suppressed-baseline.txt (create)
- tests/fixtures/m027-p03/anomaly-fixture.jsonl (create)
- tests/fixtures/m027-p03/README.md (create)
- scripts/verify/m027-p03-t01-shape-precheck.sh (create — deleted by T04)
- scripts/verify/m027-p03-t02-shape-precheck.sh (create — deleted by T04)
- scripts/verify/m027-p03-t03-shape-precheck.sh (create — deleted by T04)
- scripts/verify/m027-p03-suite.sh (create)
- scripts/verify/m027-p03-anomaly-shape.sh (create)
- scripts/verify/m027-p03-config-drift-shape.sh (create)
- scripts/verify/m027-p03-doctor-md-shape.sh (create)
- scripts/verify/m027-p03-doctor-byte-identity.sh (create)
- scripts/verify/m027-p03-suppression-matrix.sh (create)
- scripts/verify/m027-p03-run-doctor-integration.sh (create)
- scripts/verify/m027-p03-anomaly-latency.sh (create)
- scripts/verify/m027-p03-anomaly-goodhart-pairing.sh (create)
- scripts/verify/m027-p03-zero-llm-token.sh (create)
- scripts/verify/m027-p03-read-only.sh (create)
- scripts/verify/m027-p03-bash32-compat.sh (create)
