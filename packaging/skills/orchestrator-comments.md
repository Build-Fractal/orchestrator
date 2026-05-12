---
schema_version: "1.0"
type: skill
name: "orchestrator:comments"
namespace: "orchestrator"
description: "Comment to workflow classifier with human-gated spec-amendment apply."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/comments.md"
---

# orchestrator:comments

Canonical behavior is defined in [`commands/comments.md`](../../commands/comments.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:comments`, it delegates to the
command document above.
