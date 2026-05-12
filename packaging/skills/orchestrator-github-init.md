---
schema_version: "1.0"
type: skill
name: "orchestrator:github-init"
namespace: "orchestrator"
description: "Use when initializing the M013 GitHub integration for a project — projects the current orchestrator state (milestone / phases / tasks) onto GitHub Issues / Milestones / Projects v2 with marker-bearing bodies. Opt-in and reversible (FR-11): deleting `.orchestrator/integrations/github.json` returns the orchestrator to pre-integration behavior."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/github-init.md"
---

# orchestrator:github-init

Canonical behavior is defined in [`commands/github-init.md`](../../commands/github-init.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:github-init`, it delegates to the
command document above.
