---
schema_version: "1.0"
type: skill
name: "orchestrator:where"
namespace: "orchestrator"
description: "Use when a developer wants to see the full work hierarchy at a glance — feature → milestone → phases → tasks → current dispatch — with per-row cost columns and progress bars. Renders read-only from on-disk state."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/where.md"
---

# orchestrator:where

Canonical behavior is defined in [`commands/where.md`](../../commands/where.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:where`, it delegates to the
command document above.
