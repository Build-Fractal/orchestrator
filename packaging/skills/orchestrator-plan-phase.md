---
schema_version: "1.0"
type: skill
name: "orchestrator:plan-phase"
namespace: "orchestrator"
description: "Use when planning one phase — creates task decomposition with must-haves. Produces a phase plan file with truths, artifacts, key links, and zero-context task plans."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/plan-phase.md"
---

# orchestrator:plan-phase

Canonical behavior is defined in [`commands/plan-phase.md`](../../commands/plan-phase.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:plan-phase`, it delegates to the
command document above.
