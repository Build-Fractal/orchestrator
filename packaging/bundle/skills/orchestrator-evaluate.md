---
schema_version: "1.0"
type: skill
name: "orchestrator:evaluate"
namespace: "orchestrator"
description: "Use when starting a new project to classify scope as Tier A, B, or C. Analyzes the feature spec to determine how many SDD flows are needed and activates the corresponding workflow."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/evaluate.md"
---

# orchestrator:evaluate

Canonical behavior is defined in [`commands/evaluate.md`](../../commands/evaluate.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:evaluate`, it delegates to the
command document above.
