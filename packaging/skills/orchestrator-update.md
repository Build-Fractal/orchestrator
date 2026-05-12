---
schema_version: "1.0"
type: skill
name: "orchestrator:update"
namespace: "orchestrator"
description: "Use when refreshing an orchestrator-managed project's runtime from a locally-resolved source repo. Pre-M035 interim wrapper around install-claude-code.sh --force; M035 P02-P06 will add npm/homebrew/curl-pipe-bash sources."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/update.md"
---

# orchestrator:update

Canonical behavior is defined in [`commands/update.md`](../../commands/update.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:update`, it delegates to the
command document above.
