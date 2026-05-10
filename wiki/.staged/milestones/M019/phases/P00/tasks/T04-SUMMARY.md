---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P00"
milestone: "M019"
provides:
  - "pricing table for P01 emitter"
requires:
  - "from:P00/T01 what:m019-p00-payload-shape.sh"
affects:
  - "P01"
key_files:
  - ".orchestrator/config/pricing.yml"
key_decisions:
  - "AD-2"
patterns_established:
  - "hand-maintained pricing config with provider field reserved for multi-backend"
drill_down_paths:
  - ".orchestrator/milestones/M019/phases/P00/tasks/T04-PAYLOAD.md"
duration: "10m"
verification_result: "pass"
completed_at: "2026-04-18T02:12:05Z"
---

Created .orchestrator/config/pricing.yml (43 lines) with schema_version 1.0, last_updated 2026-04-17, and model entries for claude-opus-4-7 (15/75), claude-sonnet-4-6 (3/15), and claude-haiku-4-5 (0.80/4.00) USD per million tokens. Each entry carries a provider: anthropic field per Q2 resolution to reserve schema headroom for Tier 3 backend adapters. Aliases map opus-latest/sonnet-latest/haiku-latest to canonical keys. ORCH_PRICING_FILE env override documented in top-of-file comment block per AD-2. No resolver code added (P01 scope). Verified via bash scripts/verify/m019-p00-payload-shape.sh — all Gate 6 pricing.yml assertions PASS and the full gate emits PASS: m019-p00-payload-shape.sh.
