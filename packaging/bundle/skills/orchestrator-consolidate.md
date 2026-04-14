---
schema_version: "1.0"
type: skill
name: "orchestrator:consolidate"
namespace: "orchestrator"
description: "Use when compressing knowledge and archiving verbose artifacts after milestone completion."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/consolidate.md"
---

# orchestrator:consolidate

Canonical behavior is defined in [`commands/consolidate.md`](../../commands/consolidate.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:consolidate`, it delegates to the
command document above.
