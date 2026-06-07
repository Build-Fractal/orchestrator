---
description: "Use when initializing a new project for the orchestrator. Detects project context, probes capabilities, generates config + runtime-specific instruction file, and registers the orchestrator skills into the active runtime."
---

# orchestrator:init

Bootstrap the orchestrator in a project. Produces:

1. A project configuration file at `<state_root>/config.yml`.
2. A runtime-specific project instruction file (`CLAUDE.md` on Claude Code, `AGENTS.md` on Codex, `.cursor/rules/orchestrator.md` on Cursor).
3. The 12 orchestrator skills registered into the active runtime via the P06 installer.

Re-running `orchestrator:init` in an already-configured project is safe —
it delegates to the reinit handler, which preserves the `<!-- BEGIN CUSTOM -->`
/ `<!-- END CUSTOM -->` block of the instruction file and merges new
capability detections into the config. Pass `--force` to fully regenerate.

## Prerequisites

### Extension Availability Check

Before invoking init, verify the orchestrator scripts are available in the current project:

```bash
test -f scripts/lifecycle/init-project.sh
```

If non-zero, the orchestrator bundle is not installed. See `references/installation.md`.

### Runtime Detection

`orchestrator:init` defaults to `--runtime auto`, which delegates to
`scripts/dispatch/detect-runtime.sh`. If detection returns `unknown`, the
user must pass `--runtime <claude-code|codex|cursor>` explicitly.

## Workflow

The init pipeline has four phases: **detect -> probe -> generate -> verify**.

### 1. Detect

- Resolve the project directory (`--project-dir PATH`, defaults to `$PWD`).
- Run `scripts/dispatch/detect-runtime.sh` — captures `runtime=` + `confidence=`.
- Run `scripts/lifecycle/detect-project.sh --project-dir <project>` — captures
  `language=`, `framework=`, `ci_system=`, `tools_detected=`, `project_type=`.
- Resolve state root via `scripts/state/resolve-root.sh`.

### 2. Probe

- Run `scripts/dispatch/detect-capabilities.sh --profile` — captures
  `cap_execution=`, `cap_graph=`, `cap_mcp=`, `cap_ci=`, `cap_subagent=`,
  `cap_score=`. The capability profile drives intensity recommendations.
- Recommend a default intensity based on `cap_score` (0-1 -> quick,
  2-3 -> standard, 4-5 -> full) and persist as `default_intensity:` in the
  generated config.

### 3. Generate

- Check for existing `<state_root>/config.yml`. If present and `--force`
  is NOT set, delegate to `scripts/lifecycle/reinit-handler.sh` and exit.
- Render `templates/project-instruction.md` with placeholders resolved from
  the detect/probe outputs. Write to the runtime-specific path:
  - `claude-code` -> `<project-dir>/CLAUDE.md`
  - `codex` -> `<project-dir>/AGENTS.md`
  - `cursor` -> `<project-dir>/.cursor/rules/orchestrator.md`
- Write `<state_root>/config.yml` with `schema_version:`, `state_root:`,
  `runtime:`, `capabilities:` (nested from profile), `default_intensity:`,
  and `initialized_at:` (UTC ISO 8601).

### 4. Verify

- Invoke the matching installer from `packaging/install/install-<runtime>.sh`
  to register the 12 orchestrator skills into the runtime's skill discovery
  location. The installer handles hook wiring and config staging.
- **Wire the knowledge graph (cloned-project onboarding).** After the runtime
  tree is staged, if a committed corpus is present (`knowledge/**/MEM*.md`) but
  the generated, gitignored `knowledge.db` is missing or stale, rebuild it via
  `scripts/knowledge/rebuild-index.sh`. This makes a single `init` enough to make
  a freshly-cloned project's graph live. Idempotent: a silent no-op on a
  greenfield project (no corpus), a cheap refresh when the DB is stale, and
  non-fatal — the M044 fail-loud activation floor covers a transient miss.
- Emit a final `SUMMARY:` line with `project_type=`, `runtime=`,
  `instruction_file=`, `config_file=`, `skills_installed=`,
  `knowledge_graph=none|fresh|rebuilt|rebuild-failed`, `next_step=`.

### Wiki integration via `--with-wiki [--with-giscus] [--deploy]` (FR-11 / MIT-011)

`orchestrator:init --with-wiki` runs the default `init` flow first, then invokes
`scripts/lifecycle/wiki-init.sh` as a second sequential step against the same
`--project-dir`. The two scripts run sequentially, not atomically — the
`init --with-wiki` compound command is NOT a single transaction.

**Sequential-atomicity contract (MIT-011)**:

- `init-project.sh` writes its outputs first (`.orchestrator/`, `CLAUDE.md`, etc.).
- `wiki-init.sh` runs second ONLY if `init-project.sh` exits 0.
- If `wiki-init.sh` exits non-zero:
  - The init outputs are PRESERVED on disk.
  - The compound `init --with-wiki` exit code is the LITERAL exit code of
    `wiki-init.sh` (NOT 0, NOT 1 unless wiki-init exited 1).
  - The stderr diagnostic names the partial state explicitly: `init-complete, wiki-pending`.
- Callers (including M033/P05 per CON-3) MAY re-run `wiki-init.sh` independently
  without re-running `init-project.sh` to complete initialization.

**Pass-through flags**:

- `--with-giscus` — recognized by `init-project.sh` and forwarded verbatim to
  `wiki-init.sh`. P02 surface: `wiki-init.sh` rejects with exit code 5
  (`not yet implemented in P02; reserved for P03`). P03 implements the scope.
- `--deploy` — recognized by `init-project.sh` and forwarded verbatim to
  `wiki-init.sh`. Same P02-rejects / P03-implements pattern.

The flag chain is independently composable: `--with-wiki` may appear without
`--with-giscus` or `--deploy`; `--with-giscus` REQUIRES `--with-wiki` (rejected
otherwise); `--deploy` REQUIRES `--with-wiki` (rejected otherwise).

## Flags

| Flag | Description |
|---|---|
| `--project-dir PATH` | Project root (default: `$PWD`). |
| `--runtime NAME` | `claude-code`, `codex`, `cursor`, or `auto` (default). |
| `--dry-run` | No writes. Emits `would_write=<path>` lines and a final `SUMMARY:` line. |
| `--force` | Re-initialize even if configured. Overwrites the custom block. |
| `--verbose` | Extra debug output on stderr. |

## Exit Codes

- `0` — success.
- `1` — generic failure (malformed argument, detection error).
- `2` — unsafe environment (empty `$HOME` on claude-code/codex runtimes).
- `3` — runtime not available (`--runtime auto` returned `unknown` and no
  override was provided, OR the requested runtime's `--probe` returned
  `available=false`).
- `4` — already initialized (delegated to reinit handler; not an error).

## Output

- `<state_root>/config.yml` — project configuration.
- `<project-dir>/CLAUDE.md` | `<project-dir>/AGENTS.md` | `<project-dir>/.cursor/rules/orchestrator.md` — runtime-specific instruction file.
- Skills registered under the runtime's skill directory (via installer).
- Final `SUMMARY:` line on stdout describing next steps.

## Idempotency

Running `orchestrator:init` twice without `--force` results in identical disk state after the second run:

- Existing `config.yml` is updated only for auto-fillable fields (capabilities, runtime, detection timestamps).
- Existing instruction file's custom block is preserved verbatim.
- Skills are re-registered (idempotent — installer skips existing files unless `--force`).

## Error Handling

- If `--runtime auto` is used but `detect-runtime.sh` returns
  `runtime=unknown`, exit 3 with message listing supported runtimes.
- If the runtime's adapter `--probe` returns `available=false`, exit 3.
- If `scripts/lifecycle/reinit-handler.sh` is missing and an existing
  config is detected, exit 1 with a diagnostic.
- All failures emit a `FAIL:` line on stderr with a human-readable reason.

## Referenced Scripts

- `scripts/lifecycle/init-project.sh` — entry point.
- `scripts/lifecycle/detect-project.sh` — project context scanner.
- `scripts/lifecycle/reinit-handler.sh` — re-initialization handler.
- `scripts/dispatch/detect-runtime.sh` — runtime auto-detection.
- `scripts/dispatch/detect-capabilities.sh` — capability profile.
- `scripts/state/resolve-root.sh` — state root resolution.
- `packaging/install/install-claude-code.sh` | `install-codex.sh` | `install-cursor.sh` — per-runtime installer.
- `scripts/lifecycle/wiki-init.sh` — wiki-init flow invoked under --with-wiki (FR-11).

## Referenced Templates

- `templates/project-instruction.md` — project instruction file template.
