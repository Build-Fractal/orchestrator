---
schema_version: "1.0"
type: skill
name: "orchestrator:do"
namespace: "orchestrator"
description: "DEPRECATED — use orchestrator:auto <task> instead. This command is now a thin deprecation shim that forwards to the unified orchestrator:auto entry (scripts/intake/auto-entry.sh) with the legacy interactive low-confidence prompt preserved. Scheduled for removal; see the removal runway below."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/do.md"
---

# orchestrator:do

Canonical behavior is defined in [`commands/do.md`](../../commands/do.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:do`, it delegates to the
command document above.
