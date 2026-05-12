---
schema_version: "1.0"
type: skill
name: "orchestrator:do"
namespace: "orchestrator"
description: "Use when invoking a one-shot task — runs the M024 classifier, dispatches a Tier A degenerate task with Quick-profile knowledge inject, hands Tier A+ tasks to the P02 research → plan → build chain, or routes Tier B/C tasks to orchestrator:specify."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/do.md"
---

# orchestrator:do

Canonical behavior is defined in [`commands/do.md`](../../commands/do.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:do`, it delegates to the
command document above.
