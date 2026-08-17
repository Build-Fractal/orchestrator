---
schema_version: "1.0"
type: skill
name: "orchestrator:detective"
namespace: "orchestrator"
description: "Use when triaging orchestrator-internal issues — captures structured diagnostic context, searches Build-Fractal/orchestrator GitHub Issues for matches, files or comments on issues with a triage report, and suggests fixes for simple problems. Distinct from diagnose (user-project bugs) and doctor (health symptoms)."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/detective.md"
---

# orchestrator:detective

Canonical behavior is defined in [`commands/detective.md`](../../commands/detective.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:detective`, it delegates to the
command document above.
