---
schema_version: "1.0"
type: skill
name: "orchestrator:context"
namespace: "orchestrator"
description: "Use when checking the orchestrator runtime profile — resolved root, runtime, capability profile, intensity defaults, active milestone, lock state. Read-only single-screen debug skill."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/context.md"
---

# orchestrator:context

Canonical behavior is defined in [`commands/context.md`](../../commands/context.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:context`, it delegates to the
command document above.
