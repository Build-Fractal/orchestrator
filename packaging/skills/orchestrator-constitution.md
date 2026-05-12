---
schema_version: "1.0"
type: skill
name: "orchestrator:constitution"
namespace: "orchestrator"
description: "Use when authoring the project's constitution from a stack-aware starter via interactive grilling-protocol flow. Lands at .orchestrator/memory/constitution.md."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/constitution.md"
---

# orchestrator:constitution

Canonical behavior is defined in [`commands/constitution.md`](../../commands/constitution.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:constitution`, it delegates to the
command document above.
