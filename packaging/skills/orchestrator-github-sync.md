---
schema_version: "1.0"
type: skill
name: "orchestrator:github-sync"
namespace: "orchestrator"
description: "Use when reconciling orchestrator state with GitHub Issues/Milestones/Projects v2 after init — reconcile pass only (no create). Closes sub-issues, updates Project v2 status via updateProjectV2ItemFieldValue, respects per-item retry boundaries, emits unit_close JSONL."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/github-sync.md"
---

# orchestrator:github-sync

Canonical behavior is defined in [`commands/github-sync.md`](../../commands/github-sync.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:github-sync`, it delegates to the
command document above.
