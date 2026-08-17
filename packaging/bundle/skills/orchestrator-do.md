---
schema_version: "1.0"
type: skill
name: "orchestrator:do"
namespace: "orchestrator"
description: "DEPRECATED — use orchestrator:auto <task> instead. Retained as a thin deprecation shim that forwards all behavior to the unified orchestrator:auto entry. Scheduled for removal no earlier than one published release after this deprecation ships (target-removal version v0.12.0)."
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/do.md"
---

# orchestrator:do  (DEPRECATED)

> **DEPRECATED — migrate to `orchestrator:auto <task>`.**

`orchestrator:do` has been unified into `orchestrator:auto`. The entire
one-shot classify-and-route behavior it provided now lives in the single
`orchestrator:auto` entry driver. This skill is retained only as a thin
**deprecation shim** so an installed consumer that invokes `orchestrator:do`
gets a clear deprecation notice and a working forward, rather than a
missing-command error.

**Replacement:** `orchestrator:auto "<task>"`

Canonical behavior — the deprecation banner, the flag-forwarding table, and
the full removal runway — is defined in
[`commands/do.md`](../../commands/do.md). All behavior forwards to the unified
entry documented in [`commands/auto.md`](../../commands/auto.md); this skill
file is a thin discovery surface for runtimes that enumerate skills from disk.

## Removal runway (D021)

This deprecation shim is retained through **at least the next published minor
release**. Removal is gated **no earlier than one published release after this
deprecation ships**. The concrete **target-removal version is `v0.12.0`**.
Until removal, `orchestrator:do "<task>"` remains functional — it emits the
deprecation notice and forwards to `orchestrator:auto`.
