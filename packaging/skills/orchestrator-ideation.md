---
schema_version: "1.0"
type: skill
name: "orchestrator:ideation"
namespace: "orchestrator"
description: "Use when starting a project with no materials and no codebase — runs a 7-question grilling-protocol-shaped flow producing an orchestrator:specify-consumable structured pre-spec."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/ideation.md"
---

# orchestrator:ideation

Canonical behavior is defined in [`commands/ideation.md`](../../commands/ideation.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:ideation`, it delegates to the
command document above.
