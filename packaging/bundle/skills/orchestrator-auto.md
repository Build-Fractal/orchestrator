---
schema_version: "1.0"
type: skill
name: "orchestrator:auto"
namespace: "orchestrator"
description: "Use when running fully autonomous execution on a Tier C project. Acquires a lock, then loops: derive state → check budget/stuck → dispatch task → verify → record → advance, until the milestone completes, a blocker is encountered, or a pause is requested."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/auto.md"
---

# orchestrator:auto

Canonical behavior is defined in [`commands/auto.md`](../../commands/auto.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:auto`, it delegates to the
command document above.
