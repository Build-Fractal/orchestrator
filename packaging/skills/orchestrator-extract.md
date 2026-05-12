---
schema_version: "1.0"
type: skill
name: "orchestrator:extract"
namespace: "orchestrator"
description: "Use when extracting reference materials (PDF / Word / Excel / Markdown) into the orchestrator's reference-corpus knowledge layer. Synchronous Tier 0 (manifest + binary preservation + summary) and Tier 1 (deterministic plain-text via shell adapters); Tier 2 (LLM-driven structured Markdown) routes through M030 + conversus and is wired in P03."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/extract.md"
---

# orchestrator:extract

Canonical behavior is defined in [`commands/extract.md`](../../commands/extract.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:extract`, it delegates to the
command document above.
