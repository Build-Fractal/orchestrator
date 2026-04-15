---
id: M001
title: Foundation
status: completed
created_at: 2025-05-01T00:00:00Z
completed_at: 2025-06-30T00:00:00Z
---

# M001 — Foundation

Shipped the minimal backbone of the orchestrator: the 9-state on-disk state
machine, the core script surface (derive-phase, record-result, run-verify,
dispatch), and the first template set.

## What Landed

- State machine with priority-ordered derivation rules
- Four-tier verification ladder (static, command, behavioral, human)
- Bash 3.2 conventions — parallel indexed arrays, no jq hard dependency
- Single-agent validation against Claude Code

## Why It Matters

Gives downstream milestones (M002 migration, M003 multi-runtime) a stable
foundation to build on without re-litigating state semantics or script
conventions.
