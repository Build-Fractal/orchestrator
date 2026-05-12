---
schema_version: "1.0"
type: skill
name: "orchestrator:ingest"
namespace: "orchestrator"
description: "Use when ingesting a markdown spec into the orchestrator's knowledge system. Chunks the spec into spec/story, spec/requirement, spec/acceptance, spec/constraint, spec/nfr, and spec/non-goal entries, then rebuilds the knowledge index so downstream commands (evaluate, roadmap, plan-phase, dispatch) can read spec-chunk metrics and graph edges instead of re-parsing the raw spec."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/ingest.md"
---

# orchestrator:ingest

Canonical behavior is defined in [`commands/ingest.md`](../../commands/ingest.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:ingest`, it delegates to the
command document above.
