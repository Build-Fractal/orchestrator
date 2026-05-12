---
schema_version: "1.0"
type: skill
name: "orchestrator:ingest-reference"
namespace: "orchestrator"
description: "Use when ingesting a populated reference-corpus tree into the orchestrator's knowledge graph. Walks knowledge/reference/<category>/REF-*.md, classifies (FR-1 taxonomy + FR-2 required fields), gates re-ingest via content_hash idempotency, surfaces Tier 2 BLOCK-verdict chunks as advisories, and rebuilds KNOWLEDGE-INDEX.md so reference chunks participate in graph traversal."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/ingest-reference.md"
---

# orchestrator:ingest-reference

Canonical behavior is defined in [`commands/ingest-reference.md`](../../commands/ingest-reference.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:ingest-reference`, it delegates to the
command document above.
