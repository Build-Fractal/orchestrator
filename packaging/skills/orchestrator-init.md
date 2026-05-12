---
schema_version: "1.0"
type: skill
name: "orchestrator:init"
namespace: "orchestrator"
description: "Use when initializing a new project for the orchestrator. Detects project context, probes capabilities, generates config + runtime-specific instruction file, and registers the orchestrator skills into the active runtime."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/init.md"
---

# orchestrator:init

Canonical behavior is defined in [`commands/init.md`](../../commands/init.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:init`, it delegates to the
command document above.
