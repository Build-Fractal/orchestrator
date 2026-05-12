---
schema_version: "1.0"
type: skill
name: "orchestrator:materials-intake"
namespace: "orchestrator"
description: "Use when intaking heterogeneous source materials (Product Brief, Decision Register, MVP Plan, Handoff JSON, milestone audits) and producing a reconciled orchestrator:specify-consumable pre-spec."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/materials-intake.md"
---

# orchestrator:materials-intake

Canonical behavior is defined in [`commands/materials-intake.md`](../../commands/materials-intake.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:materials-intake`, it delegates to the
command document above.
