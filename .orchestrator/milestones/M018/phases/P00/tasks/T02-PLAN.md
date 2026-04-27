---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P00"
milestone: "M018"
name: "Section-distribution probe with per-tier savings-ceiling estimator"
depends_on: []
---

## Prerequisites

None — T02 is independent of T01. T02 only reads existing `payload_breakdown` records from the historical execution log (n=169 across M012–M027). No emitter changes required to do this analysis.

The existing aggregator pattern lives at `.orchestrator/scratch/m018-telemetry-probe.sh` and produces the report at `.orchestrator/scratch/m018-telemetry-probe-report.txt`. T02 extends that pattern with section-level distribution stats and per-tier achievable-savings estimates.

## Description

Ship `scripts/diagnostics/m018-section-distribution.sh`, a read-only diagnostic that reads historical `payload_breakdown` records and produces:

1. **Per-section size distribution** — for each of the eight sections (Knowledge, Task Plan, Upstream Context, First-Turn Completeness, Scope, Constraints, State Context, Decisions): mean, p50, p95, max token counts plus n.
2. **Per-tier achievable-savings ceilings with confidence intervals** — for each of the four compression tiers (filter, T1, T2, T3): the modeled token savings ceiling (low / mean / high) computed from the section-distribution data plus published per-tier compression assumptions, with explicit 80% confidence intervals (low = 10th percentile, high = 90th percentile of the bootstrap distribution).

This is the empirical input for T03's SC-9 calibration: it tells the operator how much reduction is realistically achievable across the M018 pipeline so SC-9's threshold can be pinned to a number defended by data rather than guessed.

The probe is read-only and pure-bash + jq + awk — no LLM calls, no network. Output is dual-format: human-readable text by default; `--format json` for machine consumption (T03 reads JSON).

## Steps

1. **Read** `.orchestrator/scratch/m018-telemetry-probe.sh` end-to-end. The new script reuses its log-scanning pattern, jq-extraction approach, and awk-percentile computation. The existing probe is the structural template.

2. **Read** `specs/030-context-compression-layer/spec.md` lines around FR-3 (filter), FR-5 (T1), FR-6 (T2 snip), FR-7 (T3 auto-compact) for the documented compression assumptions per tier. These are the ratios the savings-ceiling estimator applies. If the spec is silent on a ratio, use the conservative defaults documented in the Per-Tier Modeling Assumptions block below.

3. **Create** `scripts/diagnostics/m018-section-distribution.sh` with:
   - `set -u` (NOT `set -euo pipefail` — the existing telemetry probe uses `set -euo pipefail` which is fine; match that).
   - Argument parsing: `--format text|json` (default `text`), `--bootstrap-iterations N` (default 1000), `--seed S` (default 42 for deterministic output).
   - Log union scan: same `for log in .orchestrator/milestones/*/execution-log.jsonl` loop as the telemetry probe.
   - Per-section distribution: extract `.section_tokens` from each `payload_breakdown` record, group by section name, compute mean/p50/p95/max/n via awk.
   - Per-tier savings-ceiling: apply the per-tier compression-ratio model below to the section-distribution data, bootstrap-resample to produce 80% CIs.
   - Output both formats from a single computation pass — assemble the data into temp TSV/JSON files first, then format-print at the end based on `--format`.

4. **Per-Tier Modeling Assumptions** (encode these as named constants at the top of the script so they're reviewable):
   - **Filter** (FR-3, applies to Knowledge section): drop ratio ≈ 30% of Knowledge tokens, modeled as a Beta(2, 5) distribution to capture the uncertainty in how many entries carry `status: superseded` / `experimental` at any given dispatch. Conservative; will be refined post-M020 dogfood.
   - **T1 microcompact** (FR-5, applies to tool-result tokens — currently embedded in Task Plan + Upstream Context): drop ratio ≈ 50% of tool-result tokens, conditioned on tool-result tokens making up ~30% of those two sections. Net ceiling ≈ 15% of (Task Plan + Upstream Context).
   - **T2 snip** (FR-6, applies to all sections > tail-threshold): head-drop ratio ≈ 40% of any section that exceeds 1500 tokens, with tail preserved byte-identical. Modeled via per-section indicator on `mean > 1500` from the distribution data.
   - **T3 auto-compact** (FR-7, applies to Knowledge + Task Plan + Upstream Context, intensity-gated): summarization ratio ≈ 60% reduction on those sections when above the per-section budget threshold. T3 only fires at Standard intensity and above; the ceiling here is the *theoretical maximum* assuming Standard+ across the dispatch population.
   - Document these assumptions inline as comments AND emit them in the JSON output under `model_assumptions` so T03's amendment can cite them verbatim.

5. **Bootstrap CI computation** — for each tier, resample the 169-record per-section data with replacement N times (default 1000), apply the tier's compression model, take the 10th and 90th percentiles of the resulting savings-token distribution. Emit `low_tokens`, `mean_tokens`, `high_tokens` per tier and `low_pct`, `mean_pct`, `high_pct` (savings as a fraction of mean total payload tokens).

6. **Aggregate-tier ceiling** — compute the combined achievable-savings ceiling across all four tiers, accounting for non-overlap (filter and T1 don't double-count tool-result tokens; T3 overlaps with T2 — apply T2's snip to remaining T3-eligible budget, not gross). Produce the same low/mean/high triple for the aggregate. This is the number T03 uses to calibrate SC-9.

7. **Write the verifier** at `scripts/verify/m018-p00-probe-output.sh`:
   - Runs `bash scripts/diagnostics/m018-section-distribution.sh --format json` against the historical log.
   - Asserts the JSON output contains: `per_section[]` with the eight expected section names, `per_tier{}` with the four tiers, each tier carrying `low_tokens`/`mean_tokens`/`high_tokens` keys, and a top-level `aggregate_ceiling` block carrying the same three keys.
   - Asserts `aggregate_ceiling.high_pct - aggregate_ceiling.low_pct < 50` (sanity: the CI band is finite, not pathological).
   - Exits 0 on pass, 1 with diagnostic on fail.

8. **Smoke-run** the probe locally to confirm it produces sane output against the existing 169-record corpus. Sanity check: aggregate `mean_pct` should land somewhere in the 15–35% range — if it's outside that, the modeling is wrong and needs review before T03 reads from it.

## Must-Haves

This task addresses the phase must-have:

- Truth: "`scripts/diagnostics/m018-section-distribution.sh` produces per-section size distribution AND per-tier achievable-savings ceilings with confidence intervals." — implemented by the script in step 3 + verifier in step 7.
- Artifacts: `scripts/diagnostics/m018-section-distribution.sh` (created step 3), `scripts/verify/m018-p00-probe-output.sh` (created step 7).

## Verification

- `bash scripts/diagnostics/m018-section-distribution.sh --format text` — must run cleanly against the historical log and print the eight-section distribution table plus the four-tier ceiling table.
- `bash scripts/diagnostics/m018-section-distribution.sh --format json` — must emit valid JSON (pipe through `jq .` to confirm).
- `bash scripts/verify/m018-p00-probe-output.sh` — must pass.

## Inputs

### From Previous Tasks

None — T02 is parallel to T01.

### From Disk (Pre-existing)

- `.orchestrator/scratch/m018-telemetry-probe.sh` — structural template. Key pattern: log union via `for log in .orchestrator/milestones/*/execution-log.jsonl`, jq-based field extraction, awk-based percentile computation. Key behavior: read-only; writes only to stdout.
- `.orchestrator/milestones/*/execution-log.jsonl` — JSONL append-only logs. Key record: `payload_breakdown` lines carry `.section_tokens` as an object `{"Knowledge": <int>, "Task Plan": <int>, …}` and `.payload_tokens_estimate` as the section sum.
- `specs/030-context-compression-layer/spec.md` — FR-3, FR-5, FR-6, FR-7 carry the per-tier compression-model intent. Read these to ensure the modeling assumptions in step 4 don't contradict the spec.
- `.orchestrator/scratch/m018-telemetry-probe-report.txt` — sanity-check baseline. The new probe's per-section means should match this report's section-token aggregates within ±1% (deterministic from the same data).

## Constraints

- **Bash 3.2+ / POSIX sh** — `mapfile`, `readarray`, associative arrays not allowed.
- **AD-19 (script-file shape)** — keep internals clean; no inline compound chains > 2; no `$(... | ...)` substitutions; bootstrap loop must use a temp file or named-pipe-free pattern.
- **Read-only** — the probe must not modify any execution-log, knowledge entry, or spec file. Outputs go to stdout only (T03 captures stdout to scratch for the audit trail).
- **Deterministic** — `--seed` defaults to 42 so re-running the probe against the same data produces identical CIs. Document this in the script header.
- **jq required** — the existing probe declares `command -v jq` as a hard prereq; match that.

## Expected Output

```
$ bash scripts/diagnostics/m018-section-distribution.sh --format text
=== M018 Section Distribution Probe ===
Records analyzed: payload_breakdown=169

=== Per-section distribution (tokens) ===
  section                       n     mean      p50      p95      max
  ----------------------------- --- -------- -------- -------- --------
  Knowledge                     169     7546     7124     9876    12345
  Task Plan                     169     3946     3812     5234     6789
  …

=== Per-tier achievable savings (80% CI) ===
  tier              low_tok    mean_tok    high_tok    low_pct    mean_pct    high_pct
  ---------------- --------- ----------- ----------- ---------- ----------- -----------
  filter             1245       2266        3287        7.4        13.5         19.6
  tier1               523        870        1217        3.1         5.2          7.2
  tier2              1890       2845        3800       11.2        16.9         22.6
  tier3              2380       4120        5860       14.2        24.5         34.9

=== Aggregate savings ceiling (non-overlap-adjusted) ===
  low_pct=23.1  mean_pct=31.4  high_pct=39.7
  (Standard+ assumption — Quick intensity caps at filter+tier1+tier2)

Probe complete.

$ bash scripts/verify/m018-p00-probe-output.sh
PASS: m018-section-distribution probe output validates
```

T03 reads the JSON form of this same output and uses `aggregate_ceiling.low_pct` (the lower-confidence-bound) as the SC-9 threshold floor — that gives operators the conservative-defensible number, which is what an empirical calibration should yield.
