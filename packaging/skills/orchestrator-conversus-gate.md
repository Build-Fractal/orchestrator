---
schema_version: "1.0"
type: skill
name: "orchestrator:conversus-gate"
namespace: "orchestrator"
description: "Use when gating an artifact through a two-agent Conversus cooperative deliberation. The source-advocate vs target-advocate pattern produces a structured PASS|BLOCK verdict that callers use to gate downstream work. Reusable across any orchestrator stage that needs fidelity or quality gating (M011 normalize, M013 issue-sync, M014 comment-apply)."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/conversus-gate.md"
---

# orchestrator:conversus-gate

Canonical behavior is defined in [`commands/conversus-gate.md`](../../commands/conversus-gate.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:conversus-gate`, it delegates to the
command document above.
