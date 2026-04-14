---
schema_version: "1.0"
type: skill
name: "orchestrator:doctor"
namespace: "orchestrator"
description: "Use when running project health diagnostics — detects orphaned artifacts, stale knowledge, scope mismatches, and cost spikes."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/doctor.md"
---

# orchestrator:doctor

Canonical behavior is defined in [`commands/doctor.md`](../../commands/doctor.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:doctor`, it delegates to the
command document above.
