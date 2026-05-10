---
schema_version: "1.0"
type: phase-plan
phase: "P04"
milestone: "M008"
goal: "The orchestrator stores all state in its own .orchestrator/ directory, uses the orchestrator:* command namespace, and completes a full workflow without spec-kit installed"
demo_sentence: "A developer clones a fresh repo with no spec-kit installed, runs the orchestrator through its full lifecycle — state is written under .orchestrator/, commands resolve under the orchestrator:* namespace, and migrate-state.sh can pick up an existing .specify/orchestrator/ tree and move it into the new location without touching any script that consumes it."
risk: "medium"
depends_on: []
---

<!--
  P04 -- State & Namespace Independence
  =====================================

  Context: the orchestrator currently hardcodes `.specify/orchestrator/`
  as the state root and ships commands under the `speckit.orchestrator.*`
  namespace. Both facts couple it to spec-kit. P04 severs that coupling
  while preserving a one-way migration bridge for existing users.

  Architectural decisions:

  (1) Single resolver, distributed consumers. One script
      (scripts/state/resolve-root.sh) decides where the state root lives.
      Every other script/command calls it instead of hardcoding a path.
      Mirrors the P03 "centralized matrix" pattern (MEM014).

  (2) Resolution order is deterministic and explicit. Env var override,
      then config file, then `.orchestrator/` if present, then
      `.specify/orchestrator/` if present (the migration bridge), then
      a new-project default of `.orchestrator/`. The bridge is read-only
      -- resolve-root never writes to `.specify/orchestrator/`. New
      writes always land under `.orchestrator/` once migration runs.

  (3) Hard migration, not dual code paths (MEMORY: [M007](../../../../milestones/M007/index.md) no degradation).
      migrate-state.sh is a one-shot move, not a sync. After migration,
      `.specify/orchestrator/` ceases to exist. This avoids the dual-
      path bug class where state diverges between two roots.

  (4) Namespace aliasing is documentation, not runtime. The runtime
      adapters in P05 register commands under orchestrator:* directly.
      namespace-aliases.sh generates a human-readable mapping table so
      users migrating mental models can search one <-> one. No runtime
      router is built in P04.

  (5) Refactor of derive-phase.sh is surgical (Constitution XV). The
      public interface -- a positional milestone-dir argument -- is
      unchanged. The refactor only swaps the internal "where do I find
      the orchestrator root" default from a hardcoded path to a call
      into resolve-root.sh. Existing callers that pass an explicit path
      continue to work unchanged.

  (6) IMPORTANT: P04 does NOT run migration against this project.
      migrate-state.sh is built, unit-tested on a temp fixture, and
      shipped. The live `.specify/orchestrator/` tree for this
      milestone stays put until P07 (init flow) or a manual migration
      run post-M008.

  Cross-phase dependencies:
  - Consumes: nothing (Wave 1, independent of P01/P02/P03).
  - Produces: the resolved-root convention that P05 (runtime adapters),
    P06 (packaging), and P07 (init) all rely on. Every script that
    writes state after P04 MUST call resolve-root.sh rather than assume
    a hardcoded path.
-->

## Must-Haves

### Truths

- `scripts/state/resolve-root.sh` exists and is executable.
  - Check: `bash scripts/verify/m008-p04-resolve-root-exists.sh`
- `scripts/state/resolve-root.sh` honors the `ORCHESTRATOR_ROOT` env var as the highest-priority override.
  - Check: `bash scripts/verify/m008-p04-resolve-root-env-override.sh`
- `scripts/state/resolve-root.sh` defaults to `.orchestrator/` for a brand-new project with neither `.orchestrator/` nor `.specify/orchestrator/` present.
  - Check: `bash scripts/verify/m008-p04-resolve-root-default.sh`
- `scripts/state/resolve-root.sh` resolves to `.specify/orchestrator/` when only that directory exists (migration bridge).
  - Check: `bash scripts/verify/m008-p04-resolve-root-bridge.sh`
- `scripts/state/resolve-root.sh` prefers `.orchestrator/` when BOTH roots exist (post-migration safety).
  - Check: `bash scripts/verify/m008-p04-resolve-root-prefers-new.sh`
- `scripts/state/detect-speckit.sh` emits `speckit_installed=<true|false>` and `integration_mode=<enabled|disabled>` as two key=value lines.
  - Check: `bash scripts/verify/m008-p04-detect-speckit-shape.sh`
- `scripts/state/config-system.sh` supports `get`, `set`, and `list` subcommands operating on `<root>/config.yml` where `<root>` comes from `resolve-root.sh`.
  - Check: `bash scripts/verify/m008-p04-config-system-subcommands.sh`
- `scripts/state/config-system.sh set` handles dot-notation nested keys (e.g. `intensity.default`).
  - Check: `bash scripts/verify/m008-p04-config-system-nested.sh`
- `scripts/migrate/migrate-state.sh` moves `.specify/orchestrator/*` to `.orchestrator/*` and emits a `MIGRATED:` line.
  - Check: `bash scripts/verify/m008-p04-migrate-state-moves.sh`
- `scripts/migrate/migrate-state.sh` refuses to overwrite when `.orchestrator/` already has content and emits a `SKIP:` line.
  - Check: `bash scripts/verify/m008-p04-migrate-state-skip.sh`
- `scripts/migrate/migrate-state.sh --dry-run` shows what would move without moving anything.
  - Check: `bash scripts/verify/m008-p04-migrate-state-dry-run.sh`
- `scripts/state/derive-phase.sh` no longer contains a hardcoded reference to `.specify/orchestrator` as its internal default, and uses `resolve-root.sh` for root resolution.
  - Check: `bash scripts/verify/m008-p04-derive-phase-no-hardcode.sh`
- `scripts/state/derive-phase.sh` still accepts an explicit milestone-dir positional argument unchanged (surgical refactor; public interface preserved).
  - Check: `bash scripts/verify/m008-p04-derive-phase-interface.sh`
- `scripts/state/namespace-aliases.sh` emits a complete `speckit.orchestrator.* -> orchestrator:*` mapping covering every command in `commands/`.
  - Check: `bash scripts/verify/m008-p04-namespace-aliases-complete.sh`
- All P04 scripts are Bash 3.2 compatible -- no `declare -A`, no `mapfile`, no `readarray` (MEM001).
  - Check: `bash scripts/verify/m008-p04-bash32-compat.sh`
- A full orchestrator workflow (state derivation + config read/write + namespace alias lookup) completes end-to-end without touching `.specify/orchestrator/` or invoking spec-kit.
  - Check: `bash scripts/verify/m008-p04-standalone-e2e.sh`

### Artifacts

- scripts/state/resolve-root.sh (min 40 lines, contains "ORCHESTRATOR_ROOT")
- scripts/state/detect-speckit.sh (min 25 lines, contains "speckit_installed=")
- scripts/state/config-system.sh (min 80 lines, contains "SUBCOMMAND")
- scripts/migrate/migrate-state.sh (min 60 lines, contains "MIGRATED:")
- scripts/state/namespace-aliases.sh (min 30 lines, contains "orchestrator:")
- scripts/state/derive-phase.sh (min 180 lines, contains "resolve-root.sh")

### Key Links

- scripts/state/derive-phase.sh -> scripts/state/resolve-root.sh (derive-phase sources or calls resolve-root for its default root)
- scripts/state/config-system.sh -> scripts/state/resolve-root.sh (config-system resolves its storage location via resolve-root)
- scripts/migrate/migrate-state.sh -> scripts/state/resolve-root.sh (migrate references resolve-root to describe the post-migration canonical root)

## Tasks

### T01: Create scripts/state/resolve-root.sh -- the canonical root resolver

See tasks/T01-PLAN.md.

### T02: Create scripts/state/detect-speckit.sh -- spec-kit detection and integration toggle

See tasks/T02-PLAN.md.

### T03: Create scripts/state/config-system.sh -- unified config get/set/list

See tasks/T03-PLAN.md.

### T04: Create scripts/migrate/migrate-state.sh -- one-shot .specify/orchestrator -> .orchestrator migration

See tasks/T04-PLAN.md.

### T05: Refactor scripts/state/derive-phase.sh + create scripts/state/namespace-aliases.sh

See tasks/T05-PLAN.md.

### T06: Bash 3.2 compatibility sweep + standalone end-to-end integration test

See tasks/T06-PLAN.md.

## Task Dependencies

```
T01 (resolve-root.sh) -> T03 (config-system, consumes resolver)
T01 (resolve-root.sh) -> T04 (migrate-state, references resolver)
T01 (resolve-root.sh) -> T05 (derive-phase refactor, consumes resolver)
T02 (detect-speckit) -- independent; may run in parallel with T03/T04/T05
T03, T04, T05 -> T06 (compat sweep + e2e)
```

Execution order: T01 first (everything blocks on it), then T02/T03/T04/T05 can run in any order (T02 is fully independent; T03-T05 depend only on T01's output), then T06 last as the integration gate.

## Files Likely Touched

- scripts/state/resolve-root.sh (create)
- scripts/state/detect-speckit.sh (create)
- scripts/state/config-system.sh (create)
- scripts/state/namespace-aliases.sh (create)
- scripts/migrate/migrate-state.sh (create)
- scripts/state/derive-phase.sh (modify -- surgical refactor only)
- scripts/verify/m008-p04-resolve-root-exists.sh (create)
- scripts/verify/m008-p04-resolve-root-env-override.sh (create)
- scripts/verify/m008-p04-resolve-root-default.sh (create)
- scripts/verify/m008-p04-resolve-root-bridge.sh (create)
- scripts/verify/m008-p04-resolve-root-prefers-new.sh (create)
- scripts/verify/m008-p04-detect-speckit-shape.sh (create)
- scripts/verify/m008-p04-config-system-subcommands.sh (create)
- scripts/verify/m008-p04-config-system-nested.sh (create)
- scripts/verify/m008-p04-migrate-state-moves.sh (create)
- scripts/verify/m008-p04-migrate-state-skip.sh (create)
- scripts/verify/m008-p04-migrate-state-dry-run.sh (create)
- scripts/verify/m008-p04-derive-phase-no-hardcode.sh (create)
- scripts/verify/m008-p04-derive-phase-interface.sh (create)
- scripts/verify/m008-p04-namespace-aliases-complete.sh (create)
- scripts/verify/m008-p04-bash32-compat.sh (create)
- scripts/verify/m008-p04-standalone-e2e.sh (create)
