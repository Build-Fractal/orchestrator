---
schema_version: "1.0"
type: skill
name: "orchestrator:customblock-draft"
namespace: "orchestrator"
description: "Draft the CLAUDE.md custom block from upstream sub-flow outputs (FR-13/FR-14)."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/customblock-draft.md"
---

# orchestrator:customblock-draft

Canonical behavior is defined in [`commands/customblock-draft.md`](../../commands/customblock-draft.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:customblock-draft`, it delegates to the
command document above.
