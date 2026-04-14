---
schema_version: "1.0"
type: skill
name: "orchestrator:roadmap"
namespace: "orchestrator"
description: "Use when breaking a spec into phases with dependency graph and boundary maps. Produces a structured roadmap file that drives all downstream orchestration."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/roadmap.md"
---

# orchestrator:roadmap

Canonical behavior is defined in [`commands/roadmap.md`](../../commands/roadmap.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:roadmap`, it delegates to the
command document above.
