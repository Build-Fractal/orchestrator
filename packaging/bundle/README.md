# spec-kit-orchestrator bundle

This directory is the installable bundle for the spec-kit-orchestrator — a
self-contained unit that runtime installers stage into Claude Code, Codex,
and Cursor. The bundle is assembled from source by
`packaging/bundle/build-bundle.sh` and is tar/zip-safe (no symlinks).

## Contents

- `manifest.yml` — machine-readable index of skills, hooks, config, and version.
- `skills/` — 12 skill files (copies of `packaging/skills/orchestrator-*.md`).
- `hooks/` — 5 lifecycle hook fragments (JSON): before/after tasks,
  before/after implement, before-commit.
- `config/orchestrator.default.yml` — default orchestrator config shipped
  to new projects during `/orchestrator.init`.
- `build-bundle.sh` — bundle assembler (also supports `--check`).

## Installation

Run the installer for your runtime (from the repo root):

- Claude Code:  `bash packaging/install/install-claude-code.sh`
- Codex CLI:    `bash packaging/install/install-codex.sh`
- Cursor:       `bash packaging/install/install-cursor.sh --project-dir <path>`

Each installer reads `manifest.yml`, then stages the skills into the
runtime's conventional location via the runtime adapter's
`--register` / `--hook-config` entry points.

## Where State Lands

Orchestrator state lands under `.orchestrator/` in the project root,
resolved by `scripts/state/resolve-root.sh` with this 4-rule precedence:

1. `ORCHESTRATOR_ROOT` environment variable.
2. `state_root` key in `<project>/.orchestrator/config.yml`.
3. Existing `.orchestrator/` directory.
4. Default: `.orchestrator/` (created on first write).

No state is ever written outside the resolved root.

## Updating the Bundle

Rebuild from source after editing skills or hooks:

    bash packaging/bundle/build-bundle.sh

Verify the bundle is consistent with the manifest:

    bash packaging/bundle/build-bundle.sh --check

Pick up new orchestrator releases with:

    bash scripts/lifecycle/check-update.sh

## Versioning

The bundle version comes from `VERSION` at the repo root when present,
otherwise defaults to `0.3.0-dev`. The version is substituted into
`manifest.yml` at build time.

## See Also

- `packaging/SKILL.md` — skill-file specification consumed by runtime adapters.
- `packaging/install/install-claude-code.sh` — Claude Code installer entry point.
- `packaging/install/install-codex.sh` — Codex installer entry point.
- `packaging/install/install-cursor.sh` — Cursor installer entry point.
- `scripts/state/resolve-root.sh` — canonical state-root resolver.
