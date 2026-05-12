---
schema_version: "1.0"
type: skill
name: "orchestrator:cost"
namespace: "orchestrator"
description: "Use when surfacing orchestrator cost data — retrospective rollups over the M019 Tier 1 JSONL stream, or predictive per-tier (Quick / Standard / Full) cost+quality estimates before dispatch. Read-only; bash-only; zero LLM tokens."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/cost.md"
---

# orchestrator:cost

Canonical behavior is defined in [`commands/cost.md`](../../commands/cost.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:cost`, it delegates to the
command document above.
