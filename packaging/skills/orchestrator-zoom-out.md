---
schema_version: "1.0"
type: skill
name: "orchestrator:zoom-out"
namespace: "orchestrator"
description: "Use when the user is unfamiliar with a section of code or wants a higher-level perspective. Renders a one-layer-up map of the relevant modules, callers, and seams using the project's domain vocabulary. Read-only."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/zoom-out.md"
---

# orchestrator:zoom-out

Canonical behavior is defined in [`commands/zoom-out.md`](../../commands/zoom-out.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:zoom-out`, it delegates to the
command document above.
