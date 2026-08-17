---
schema_version: "1.0"
type: skill
name: "orchestrator:auto"
namespace: "orchestrator"
description: "The single classify-first entry: pass any argument and it sizes to a tier — a Tier A/A+/B task description routes to a one-shot dispatch (absorbing the former orchestrator:do), an empty arg or existing milestone dir enters the Tier C autonomous loop, and a below-confidence-floor arg BLOCKs on ambiguity. The Tier C loop acquires a lock, then loops: derive state → check budget/stuck → dispatch task → verify → record → advance, until the milestone completes, a blocker is encountered, or a pause is requested."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/auto.md"
---

# orchestrator:auto

Canonical behavior is defined in [`commands/auto.md`](../../commands/auto.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:auto`, it delegates to the
command document above.
