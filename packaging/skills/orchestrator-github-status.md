---
schema_version: "1.0"
type: skill
name: "orchestrator:github-status"
namespace: "orchestrator"
description: "Use when reporting GitHub integration sidecar state — absent, pending-operator-complete, or configured. Read-only; makes no GitHub API calls."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/github-status.md"
---

# orchestrator:github-status

Canonical behavior is defined in [`commands/github-status.md`](../../commands/github-status.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:github-status`, it delegates to the
command document above.
