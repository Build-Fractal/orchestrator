---
schema_version: "1.0"
type: skill
name: "orchestrator:migrate"
namespace: "orchestrator"
description: "Use when migrating project data from GSD2, GSD v1, or standard spec-kit into orchestrator format."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/migrate.md"
---

# orchestrator:migrate

Canonical behavior is defined in [`commands/migrate.md`](../../commands/migrate.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:migrate`, it delegates to the
command document above.
