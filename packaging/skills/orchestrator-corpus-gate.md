---
schema_version: "1.0"
type: skill
name: "orchestrator:corpus-gate"
namespace: "orchestrator"
description: "Use when filtering a set of candidate operator/SME questions (or the open questions embedded in a plan/spec/roadmap) through a deterministic corpus-exhaustion gate before they reach a human. Sweeps every configured knowledge store, marks questions already answerable from the corpus, and produces a PASS|BLOCK verdict + an evidence artifact. Reusable across any orchestrator stage that emits questions to a human (discuss, comments, materials-intake, specify, plan-phase, roadmap)."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/corpus-gate.md"
---

# orchestrator:corpus-gate

Canonical behavior is defined in [`commands/corpus-gate.md`](../../commands/corpus-gate.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:corpus-gate`, it delegates to the
command document above.
