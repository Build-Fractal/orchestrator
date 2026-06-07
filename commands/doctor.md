---
description: "Use when running project health diagnostics — detects orphaned artifacts, stale knowledge, scope mismatches, and cost spikes."
---

# orchestrator:doctor

Run diagnostic checks across all orchestrator subsystems to detect anomalies and maintain project health.

## What It Checks

1. **Orphaned Artifacts**: Index entries without detail files, detail files without index entries
2. **Stale Knowledge**: Entries not verified in 90+ days with low hit counts
3. **Scope Issues**: Entries with no scope tags (injected into all dispatches)
4. **Cost Spikes**: Tasks costing >5x the average for their complexity tier
5. **Runtime Instruction Drift**: `CLAUDE.md` and `AGENTS.md` marker-bounded region comparison (FR-13 advisory in v1). Detects missing regions, byte-divergence between matching regions, and unmatched markers. Surfaces findings under a `Runtime Instruction Drift` section in the doctor output; warnings count as advisory (do not fail the overall health status) until a future milestone escalates.
6. **Knowledge Activation** (M044/FR-15): the single consolidated knowledge-activation check. Reports three silent-degradation symptoms in one surface — `0-mem-on-mature` (a mature project whose `KNOWLEDGE-INDEX.md` carries zero MEM entries — the load-bearing alarm, `status=fail`), `vestigial-index` (a divergent `.orchestrator/KNOWLEDGE-INDEX.md` shadowing the canonical `get_index_path()` copy, `warn`), and `runtime-memory-divergence` (decision-shaped notes in an execution log while `DECISIONS.md` is empty, `warn`). Emits `DOCTOR:KNOWLEDGE_ACTIVATION status=ok|warn|fail symptoms=<csv|none>`; advisory in the score. This is the **single** knowledge-activation doctor surface — `papercut-doctor-knowledge-gap-surface.md`'s negative-space density check, if shipped, lands as a 4th symptom here, never as a parallel surface (CON-5).

## Runtime Instruction Drift

The `Runtime Instruction Drift` check compares marker-bounded regions (`# >>> orchestrator:<region> >>>` / `# <<< orchestrator:<region> <<<`) between `CLAUDE.md` and `AGENTS.md`. Three finding kinds:

- `missing_region`: region opens in one file but not the other.
- `byte_divergence`: region present in both files but bytes differ.
- `unmatched_marker`: opening marker without matching close marker in the same file (malformed region).

Per-finding lines are emitted on stderr as `DRIFT: <kind> region=<name> file=<path>`. The summary line is `DOCTOR:DRIFT status=<ok|warn|skip> regions=<N> divergences=<M>`. A file that is opening-marker-only (malformed) may be reported both as `unmatched_marker` on that file and as `missing_region` relative to the other file — this double-reporting is accepted in v1 (advisory).

## Anomaly Detection

The `Anomaly Detection` check (M027/P03 FR-8) compares each dispatch in a milestone's `execution-log.jsonl` against a per-milestone moving median baseline and flags rows whose cost exceeds the configured multiplier (default 3.0×), whose `retry_count` exceeds the configured threshold (default 2), or whose `verification_pass_rate` falls below the configured threshold (default 0.5). Findings are advisory and never block autonomous mode (FR-8). Goodhart pairing (FR-9 / CON-4): every flagged row surfaces BOTH cost (or `cost=(unavailable; fallback=duration)`) AND quality (`pass_rate=`, `retry_count=`) on the same line.

### Suppression matrix (5 conditions)

The anomaly check is suppressed (zero stdout, exit 0) under any of:

- `--no-anomaly` flag on `check-anomalies.sh` or `run-doctor.sh`
- `--yes` flag on `check-anomalies.sh`
- `ORCHESTRATOR_AUTO=1` env var
- `ORCH_ANOMALY_CHECK_ENABLED=false` env var, or `anomaly_check_enabled: false` in `.orchestrator/config.yml`
- sample-size below the configured floor (default 5; configurable via `--sample-floor <N>`) — structural carve-out: in default mode the helper emits a single `ANOMALY: insufficient sample (n=<N> floor=<F>)` line so operators see why the check skipped; under any of the four flags above the surface stays empty

### Baseline disclaimer

Anomaly detection uses a per-milestone moving median as the baseline. The baseline normalizes whatever historical data is present, including systematic errors — a milestone that consistently runs slow normalizes the slowness as expected. Findings are advisory and never block autonomous mode (FR-8). When `estimated_cost_usd` is null in the underlying records (current default in pre-Tier-3 data), the multiplier is applied to `duration_s` as a fallback surrogate; the per-row diagnostic surfaces `cost=(unavailable; fallback=duration)` so operators see the substitution. Corruption-recovery — re-baselining after recovering from a known systematic error — is deferred (Tier 3 backend-actuals work).

Helper: `scripts/diagnostics/check-anomalies.sh` (sourceable + CLI). Default invocation scopes to the active milestone via `scripts/state/find-active-milestone.sh`. The helper transitively wraps `scripts/diagnostics/metrics-rollup.sh` (M027/P00) for the per-milestone aggregate it baselines against.

## Config Drift

The `Config Drift` check (M027/P03 FR-16) audits the M027 config knobs across the four precedence layers (env / local / project / defaults) so operators can see when team environments have drifted. Read-only and advisory.

### Audited knobs (default)

- `efficiency_footer` (M027/P02) — controls the `orchestrator:status` efficiency footer surface
- `predictive_cost_surface` (M027/P02) — controls the `orchestrator:dispatch` predictive cost surface
- `anomaly_cost_multiplier` (M027/P03) — anomaly cost-spike multiplier (default 3.0)
- `anomaly_retry_threshold` (M027/P03) — anomaly `retry_count` threshold (default 2)
- `anomaly_pass_rate_threshold` (M027/P03) — anomaly `verification_pass_rate` threshold (default 0.5)
- `anomaly_check_enabled` (M027/P03) — master enable for the anomaly check (default true)

### Invocation

Pass `--config-check` to `run-doctor.sh` to run the drift audit alongside the standard checks, or invoke the helper directly:

```bash
bash scripts/diagnostics/check-config-drift.sh --keys efficiency_footer,predictive_cost_surface,anomaly_cost_multiplier,anomaly_retry_threshold,anomaly_pass_rate_threshold,anomaly_check_enabled
```

Under `--no-config-check`, the helper emits zero stdout and exits 0. Each audited key surfaces five lines: `env=`, `local=`, `project=`, `defaults=`, plus a final `effective=` line. The literal sentinel `null` (returned by `read-config.sh` for unset-but-registered keys) and empty values both render as `(unset)` so operators can see absence at a glance.

Helper: `scripts/diagnostics/check-config-drift.sh` (sourceable + CLI).

## Usage

```bash
bash scripts/diagnostics/run-doctor.sh [--root <project-root>]
```

## Output

Results are displayed on screen and appended to `doctor-history.jsonl` for trend tracking.

## When to Run

- After completing a milestone (pre-consolidation)
- When dispatch payloads seem bloated
- When cost appears higher than expected
- Periodically during long-running projects

## Referenced Scripts

- `scripts/diagnostics/run-doctor.sh` — diagnostic orchestrator.
- `scripts/diagnostics/check-docs.sh` — documentation completeness + runtime instruction drift (`--check drift`).
- `scripts/diagnostics/check-anomalies.sh` — anomaly-detection helper (M027/P03/T01).
- `scripts/diagnostics/check-config-drift.sh` — config-drift helper (M027/P03/T02).
