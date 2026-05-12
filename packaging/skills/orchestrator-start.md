---
schema_version: "1.0"
type: skill
name: "orchestrator:start"
namespace: "orchestrator"
description: "orchestrator:start — warm conversational front door for any new orchestrator-managed project. Detects which of four starting states a user is in (greenfield-empty / greenfield-with-materials / existing-codebase / migrating), invokes init, and routes to the per-branch sub-flow."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/start.md"
---

# orchestrator:start

Canonical behavior is defined in [`commands/start.md`](../../commands/start.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:start`, it delegates to the
command document above.
