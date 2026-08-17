---
schema_version: "1.0"
type: skill
name: "orchestrator:update"
namespace: "orchestrator"
description: "Use when refreshing an orchestrator-managed project's runtime from a locally-resolved source repo. Re-stages via the installer matching the project's runtime (install-<runtime>.sh --force); also dispatches to npm/homebrew/curl channels per install provenance."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/update.md"
---

# orchestrator:update

Canonical behavior is defined in [`commands/update.md`](../../commands/update.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:update`, it delegates to the
command document above.
