---
schema_version: "1.0"
type: skill
name: "orchestrator:diagnose"
namespace: "orchestrator"
description: "Use when chasing a hard bug, flake, or performance regression. Runs a disciplined six-phase loop: feedback loop → reproduce → hypothesize → instrument → fix → regression-test. Aligned with Constitution Principle II (Evidence Before Claims)."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/diagnose.md"
---

# orchestrator:diagnose

Canonical behavior is defined in [`commands/diagnose.md`](../../commands/diagnose.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:diagnose`, it delegates to the
command document above.
