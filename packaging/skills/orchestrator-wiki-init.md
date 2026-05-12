---
schema_version: "1.0"
type: skill
name: "orchestrator:wiki-init"
namespace: "orchestrator"
description: "Use when initializing a wiki for a project — installs wiki tooling from the bundle, templates mkdocs.yml from the project's git remote, and probes Python toolchain. Default scope; --with-giscus and --deploy compose on top (P03 deliverables)."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/wiki-init.md"
---

# orchestrator:wiki-init

Canonical behavior is defined in [`commands/wiki-init.md`](../../commands/wiki-init.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:wiki-init`, it delegates to the
command document above.
