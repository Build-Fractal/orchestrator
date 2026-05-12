---
schema_version: "1.0"
type: skill
name: "orchestrator:specify"
namespace: "orchestrator"
description: "Use when authoring a new feature spec. Runs a three-pass flow (scaffold → author → gate) intensity-scaled per D019: produces a spec ready for orchestrator:evaluate."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/specify.md"
---

# orchestrator:specify

Canonical behavior is defined in [`commands/specify.md`](../../commands/specify.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:specify`, it delegates to the
command document above.
