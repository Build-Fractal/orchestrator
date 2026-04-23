# references/

Progressive disclosure documents. Self-contained — agents can read any reference without cross-referencing the spec or data model.

## Files
| File | Purpose | When to Read |
|------|---------|-------------|
| state-machine.md | 9-state lifecycle with derivation rules, transitions, tier-conditional behavior | Implementing or debugging state derivation |
| verification-ladder.md | 4-tier verification protocol (static → command → behavioral → human) | Implementing or debugging verification |
| tier-definitions.md | Tier A/B/C behavior comparison with decision table and promotion rules | Implementing tier-conditional logic |
| file-formats.md | All 11 state file format specifications | Creating or parsing orchestrator state files |
| github-integration.md | M013 GitHub native integration: sidecar schema, pending-sentinel semantics, `sync_mode` enum, `<!-- orchestrator-id -->` marker format, UAT ingestion contract, Knowledge-Layer Boundary (M013 vs. M020) | Implementing or extending GitHub projection (P01/P02/P03) |
| spec-management.md | M014 spec management: Section Contract SSOT pointer, dual-write marker convention, `--dry-run` manifest shape (partial; P04 completes with pressure-test + decomposition sections) | Implementing or extending `orchestrator:specify` / dual-write helper / `--dry-run` manifest |
