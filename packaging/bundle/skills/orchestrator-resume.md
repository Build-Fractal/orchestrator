---
schema_version: "1.0"
type: skill
name: "orchestrator:resume"
namespace: "orchestrator"
description: "Use when resuming after a crash or pause. Detects whether the interruption was a graceful pause (continue file present) or a crash (stale lock), then follows the appropriate recovery path — consuming the continue file for pauses, or breaking the lock and synthesizing a recovery briefing for crashes."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/resume.md"
---

# orchestrator:resume

Canonical behavior is defined in [`commands/resume.md`](../../commands/resume.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:resume`, it delegates to the
command document above.
