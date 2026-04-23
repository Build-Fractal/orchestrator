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

## Runtime Instruction Drift

The `Runtime Instruction Drift` check compares marker-bounded regions (`# >>> orchestrator:<region> >>>` / `# <<< orchestrator:<region> <<<`) between `CLAUDE.md` and `AGENTS.md`. Three finding kinds:

- `missing_region`: region opens in one file but not the other.
- `byte_divergence`: region present in both files but bytes differ.
- `unmatched_marker`: opening marker without matching close marker in the same file (malformed region).

Per-finding lines are emitted on stderr as `DRIFT: <kind> region=<name> file=<path>`. The summary line is `DOCTOR:DRIFT status=<ok|warn|skip> regions=<N> divergences=<M>`. A file that is opening-marker-only (malformed) may be reported both as `unmatched_marker` on that file and as `missing_region` relative to the other file — this double-reporting is accepted in v1 (advisory).

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
