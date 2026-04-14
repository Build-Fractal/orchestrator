---
schema_version: "1.0"
type: skill
name: "orchestrator:status"
namespace: "orchestrator"
description: "Use when checking progress — milestone/phase/task completion, blockers, next action. Read-only command that reports state from disk without modifying anything."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/status.md"
---

# orchestrator:status

Canonical behavior is defined in [`commands/status.md`](../../commands/status.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:status`, it delegates to the
command document above.
