---
schema_version: "1.0"
type: skill
name: "orchestrator:dispatch"
namespace: "orchestrator"
description: "Use when executing one task in a fresh context with constructed payload. Builds a minimal context from state, dispatches to a fresh agent context (or runs sequentially if subagent dispatch unavailable), and records the dispatch in the execution log."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/dispatch.md"
---

# orchestrator:dispatch

Canonical behavior is defined in [`commands/dispatch.md`](../../commands/dispatch.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:dispatch`, it delegates to the
command document above.
