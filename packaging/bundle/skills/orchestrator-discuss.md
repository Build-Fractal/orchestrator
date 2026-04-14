---
schema_version: "1.0"
type: skill
name: "orchestrator:discuss"
namespace: "orchestrator"
description: "Use when conducting a pre-planning discussion to capture architectural decisions, scope boundaries, and design constraints before roadmap generation. Creates, updates, or finalizes a context draft that gates the transition from discussing to planning state."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/discuss.md"
---

# orchestrator:discuss

Canonical behavior is defined in [`commands/discuss.md`](../../commands/discuss.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:discuss`, it delegates to the
command document above.
