---
schema_version: "1.0"
type: skill
name: "orchestrator:ingest-codebase"
namespace: "orchestrator"
description: "Use when seeding the project knowledge graph from an existing codebase via deterministic structural extraction. Produces 5-15 seed MEMs across architecture/conventions/decisions categories."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/ingest-codebase.md"
---

# orchestrator:ingest-codebase

Canonical behavior is defined in [`commands/ingest-codebase.md`](../../commands/ingest-codebase.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:ingest-codebase`, it delegates to the
command document above.
