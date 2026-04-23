---
schema_version: "1.0"
type: roadmap
milestone: "M025"
feature_ref: "021-github-installer-coexistence"
feature_spec: "specs/021-github-installer-coexistence/spec.md"
vision: "Restore the 'install orchestrator into an existing ~/.claude/ setup' user journey broken by M013/P04/T04, with a coexistence regression fixture that prevents re-breakage."
tier: "B"
created_at: "2026-04-23"
updated_at: "2026-04-23"
---

## Phases

- [ ] **P01**: Hook-config schema + merge-not-overwrite + coexistence fixture + uninstall reversibility — "Installing the orchestrator on top of a GSD-authored `~/.claude/settings.json` leaves both hook sets operational, and uninstalling restores the file byte-identically."
  - Risk: medium — bounded by FR-9 runtime scope, but the event-mapping decision (#Q-1) touches operator-facing behavior.
  - Depends: none (M013/P04/T04 is the regression source, consumed as read-only context only).
  - Boundary Map:
    - Produces: patched `scripts/dispatch/adapters/runtime/claude-code.sh --hook-config` emitting valid CC schema (FR-1, FR-2); patched `packaging/install/install-claude-code.sh` with merge-not-overwrite (FR-3, FR-4, FR-5); `tests/fixtures/m025-p01/gsd-baseline/settings.json` (FR-6); managed-entry tagging convention (FR-7); uninstall path (FR-8); `tests/m025-p01-*.sh` gate suite (SC-1..SC-6); doc updates to `references/installation.md` and `references/hooks.md` (SC-7); `CHANGELOG.md` entry (SC-8); one `knowledge/lessons/MEM0##.md` cross-referencing M013/P04/T04; one `knowledge/patterns/MEM0##.md` for the merge-not-overwrite pattern.
    - Consumes: `scripts/util/dual-write-runtime-md.sh` (FR-10); observed Claude Code hook schema (Assumptions); M013/P04/T04 commit `d33b8a7` as read-only context.

## Cross-Cutting Concerns

- **Bash-3.2 + optional-jq** (CON-1, CON-2) — all merge logic needs a jq path and an awk/sed fallback; gated by `m025-p01-bash32-compat.sh` (SC-5). Inherited pattern from M013/P04.
- **FR-12 runtime-scope negative-grep guard** (CON-5) — codex/cursor installers and adapters must remain byte-identical under `post_verify`/M025-marker negative greps. Pattern lifted from `m013-p04-phase-suite.sh`.
- **Managed-entry tagging convention** (FR-7) — whichever shape P01 planner chooses for #Q-2 (inline tag vs sidecar manifest) is consumed by US-4 uninstall path; decision needs to be resolved before tasks dispatch.

## Dependency Graph

```
P01  (single-phase milestone, no intra-milestone edges)
 └─ reads: M013/P04/T04 commit d33b8a7 as context (no code dependency)
 └─ consumes: scripts/util/dual-write-runtime-md.sh (M014/P01, already shipped)
```

## Execution Order

1. **P01** — single phase, no dependencies. Executes as a standard Tier B manual dispatch loop: `orchestrator:plan-phase M025 P01` → per-task `orchestrator:dispatch` → `orchestrator:verify` → `orchestrator:consolidate`.

## Validation

- **No conflicting producers**: PASS — P01 is the only phase; no producer collisions possible.
- **All consumed items have producers**: PASS — `dual-write-runtime-md.sh` is already in-tree (M014/P01); Claude Code hook schema is external-upstream; M013/P04/T04 is read-only context, not a build artifact.
- **DAG is acyclic**: PASS — trivially, a single-node DAG.
- **Demo sentence coverage**: PASS — P01's demo sentence (above) exercises US-1, US-2, US-3, US-4 together via `tests/m025-p01-coexistence.sh` + `tests/m025-p01-uninstall-reversibility.sh`.
