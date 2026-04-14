---
schema_version: "1.0"
type: skill
name: "orchestrator:verify"
namespace: "orchestrator"
description: "Use when running mechanical verification for a completed task or phase. Executes 4-tier verification: static checks (file existence, content patterns), command execution (configured tests/lint), behavioral review (spec compliance), and human review (UAT). Produces a structured verification report."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/verify.md"
---

# orchestrator:verify

Canonical behavior is defined in [`commands/verify.md`](../../commands/verify.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:verify`, it delegates to the
command document above.
