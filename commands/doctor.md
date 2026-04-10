---
description: "Use when running project health diagnostics — detects orphaned artifacts, stale knowledge, scope mismatches, and cost spikes."
---

# speckit.orchestrator.doctor

Run diagnostic checks across all orchestrator subsystems to detect anomalies and maintain project health.

## What It Checks

1. **Orphaned Artifacts**: Index entries without detail files, detail files without index entries
2. **Stale Knowledge**: Entries not verified in 90+ days with low hit counts
3. **Scope Issues**: Entries with no scope tags (injected into all dispatches)
4. **Cost Spikes**: Tasks costing >5x the average for their complexity tier

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
