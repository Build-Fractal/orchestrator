# Installation Reference

> How to install spec-kit-orchestrator for use in a project.
> Self-contained — follow this document to set up orchestration in any project.

## Overview

spec-kit-orchestrator is a standalone autonomous orchestrator. It is distributed as a runtime-specific installer that runs from a clone of this repo. The installer does three things:

1. Registers the `orchestrator:*` skills/commands into the active runtime (Claude Code / Codex CLI / Cursor).
2. Wires runtime hooks (Claude Code + Codex CLI only).
3. **Stages the orchestrator runtime** — `scripts/`, `templates/`, `references/` — directly into the target project, alongside `.orchestrator/`. Every `orchestrator:*` command invokes its helpers via project-relative paths (e.g. `bash scripts/state/find-active-milestone.sh …`), so these trees must live inside the project.

The installer records every file it stages in `.orchestrator/installed-files.txt` so `--uninstall` can remove exactly what it wrote.

## Install

From a clone of the orchestrator repo, run the installer that matches your host runtime:

| Runtime | Installer |
|---------|-----------|
| Claude Code | `bash packaging/install/install-claude-code.sh --project-dir <path>` |
| Codex CLI | `bash packaging/install/install-codex.sh --project-dir <path>` |
| Cursor | `bash packaging/install/install-cursor.sh --project-dir <path>` |

`--project-dir` defaults to `$PWD` for Claude Code / Codex CLI and is **required** for Cursor. The installer prints a final `SUMMARY:` line reporting `skills_installed`, `hooks_wired`, `config_written`, and `runtime_staged` counts.

## Installation Steps

### 1. Run the installer

Pick the installer for your runtime (see table above). Example for Claude Code:

```bash
bash packaging/install/install-claude-code.sh
```

Re-running the installer is safe — it preserves user edits to the generated instruction file and only refreshes orchestrator-managed assets.

### 2. Initialize your project

In your project directory, run:

```
orchestrator:init
```

This probes the project, detects host capabilities, generates `.orchestrator/config.yml` with sensible defaults, writes a runtime-appropriate instruction file, and confirms the skill registration. Completes in ~1 second.

### 3. Create project configuration (optional)

`orchestrator:init` writes a default config. To customize, edit `.orchestrator/config.yml` or start from the template:

```bash
cp templates/orchestrator-config-default.yml .orchestrator/config.yml
```

Common settings include verification commands, default tier, context verbosity, and autonomy mode. See `references/file-formats.md` for the full config schema, or `templates/orchestrator-config-default.yml` for a commented reference file.

### 4. Add a CLAUDE.md (or equivalent) for your project

`orchestrator:init` generates a runtime-appropriate instruction file automatically (for Claude Code, this is `CLAUDE.md`). If you want to hand-author it, include a short pointer section like:

```markdown
## Orchestration

This project uses the spec-kit-orchestrator.

- `orchestrator:evaluate` — classify scope and activate orchestration
- `orchestrator:discuss` — pre-planning discussion (Tier C required, Tier B optional)
- `orchestrator:roadmap` — decompose spec into phases
- `orchestrator:plan-phase` — plan one phase
- `orchestrator:dispatch` — execute one task
- `orchestrator:verify` — verify phase completion
- `orchestrator:auto` — autonomous execution (Tier C)
- `orchestrator:status` — check progress
- `orchestrator:resume` — resume after crash/pause
- `orchestrator:consolidate` — compress knowledge at milestone end
```

For a complete walkthrough, see `docs/getting-started.md`.

### 5. Create your feature spec

Before running the orchestrator commands, create a feature spec:

```bash
mkdir -p specs/001-your-feature
# Write your spec at specs/001-your-feature/spec.md
```

The orchestrator reads spec-kit-shaped specs via `scripts/dispatch/adapters/format/speckit.sh`, but the spec format is just a convention — you do not need spec-kit installed. If you are migrating from an existing spec-kit project, see `docs/migrating-from-speckit.md`.

### 6. Start orchestration

```
orchestrator:evaluate
```

The evaluate command discovers your spec, classifies the tier, scaffolds the orchestrator directory structure, and tells you what to do next.

## Directory Structure After Installation

```
your-project/
├── .orchestrator/                     # Orchestrator runtime state (canonical)
│   ├── config.yml                     # Project config (written by orchestrator:init)
│   ├── memory/
│   │   └── constitution.md            # 7 governing principles (if configured)
│   ├── DECISIONS.md                   # Architectural decision register
│   ├── KNOWLEDGE.md                   # Global knowledge entries
│   ├── execution-log.jsonl            # Append-only dispatch log
│   └── milestones/
│       └── M001/
│           ├── M001-EVALUATION.md     # Tier classification and scope metrics
│           ├── M001-CONTEXT.md        # Discussion context draft (Tier C)
│           ├── M001-ROADMAP.md        # Phase decomposition
│           └── phases/
├── specs/                             # Your feature specs
│   └── 001-your-feature/
│       └── spec.md
├── orchestrator-config.yml            # Optional project override (or use .orchestrator/config.yml)
├── CLAUDE.md                          # Runtime-specific instruction file (or equivalent)
├── scripts/                           # Orchestrator runtime — staged by installer
├── templates/                         # Orchestrator runtime — staged by installer
└── references/                        # Orchestrator runtime — staged by installer
```

`scripts/`, `templates/`, and `references/` are **staged into the project** by the installer because every `commands/*.md` invokes its helpers via project-relative paths. The installer records every file it wrote in `.orchestrator/installed-files.txt` so `--uninstall` can remove exactly what was staged.

## Autonomy Configuration

spec-kit-orchestrator's Tier C autonomous mode (`orchestrator:auto`)
runs unattended — it dispatches tasks, verifies results, and advances
phase boundaries without developer interaction. For this to work
reliably, the agent host (Claude Code, Codex CLI, Cursor) must have a
sufficient allow list so tool calls execute without permission prompts.

**How it works**: the orchestrator ships a generator at
`scripts/lifecycle/generate-permissions.sh` that introspects the
current project and emits a canonical JSON permissions object that
covers every orchestrator script, every `package.json` script key,
every Makefile target, and the standard toolchain commands for the
languages in use. The writer at
`scripts/lifecycle/write-permissions.sh` translates the canonical
object to your agent host's specific settings file (today:
`.claude/settings.json`). A drift detector at
`scripts/diagnostics/check-permissions.sh` reports when the current
settings file has fallen behind the generated output.

### Autonomy Modes

Three modes ship in `templates/autonomy-defaults.yaml`:

| Mode | Tier default | Use case |
|------|--------------|----------|
| `minimal` | Tier A | Reads/edits only. No unattended bash. |
| `standard` | Tier B | Common toolchains + scripts/. Guided dispatch. |
| `full` | Tier C | Comprehensive allow list for unattended auto mode. |

The mode is tier-derived by default but can be overridden in
`.orchestrator/config.yml`:

```yaml
autonomy:
  mode: full                # null (tier default) | minimal | standard | full
  generate_on_init: true    # Run generator during orchestrator:evaluate
  deny_patterns: []         # Extra deny patterns appended to baseline_deny
  extra_allow: []           # Extra allow patterns appended to baseline_allow
```

**Note**: `bypassPermissions` is **not** a supported mode. Per AD-7 in
`.orchestrator/milestones/M005/M005-CONTEXT.md`, safety comes
from explicit allow-list enumeration, never from disabling checks.

### Running the Generator

```bash
# Emit canonical JSON to stdout (preview)
bash scripts/lifecycle/generate-permissions.sh --tier C

# Generate + write in one step
bash scripts/lifecycle/generate-permissions.sh --tier C > /tmp/canon.json
bash scripts/lifecycle/write-permissions.sh --input /tmp/canon.json

# Check for drift
bash scripts/diagnostics/check-permissions.sh
# -> DOCTOR:PERMISSIONS status=ok gaps=0 stale=0
```

### Drift Detection

`scripts/diagnostics/check-permissions.sh` compares the current
`.claude/settings.json` against what the generator would produce. It
emits a structured line consumable by diagnostics and returns:

- `status=ok` — zero gaps, zero stale patterns, baseline deny intact.
- `status=drift` — one or more missing patterns (regeneration needed).
- `status=missing` — `.claude/settings.json` does not exist at all.

`orchestrator:auto` runs this check as part of its pre-flight.
User-authored settings files trigger an informational warning but do
not block execution — AD-13 says user autonomy wins over orchestrator
opinion.

### Known Limitation: Harness Safety Heuristics

Generating a comprehensive allow list covers the allow-list layer of
the host's bash permission system, but there is a **second, independent
layer** — the safety heuristic check — that fires on command **shape**
(not content) to catch obfuscation patterns. This layer sits above the
allow list and cannot be disabled from `settings.json`. Even a command
whose individual tokens are fully allow-listed will trigger a prompt if
its shape matches one of the heuristic classes (plain subshells,
command substitution containing pipes, process substitution, inline
compound bash, etc.).

The orchestrator's remedy is **preventive**: task plan Truth `Check:`
commands and verification scripts must use the **single-script-file
shape** — extract multi-step logic into a helper script under
`scripts/verify/` and invoke the helper as a plain `bash scripts/...`
command. The authoritative list of forbidden shapes lives in AD-19 at
`.orchestrator/milestones/M005/M005-CONTEXT.md` and in the
authoring guidance at `commands/plan-phase.md`.

If you are writing a new command or phase plan, follow the
shape guidance in `commands/plan-phase.md`. The advisory lint at
`scripts/diagnostics/check-plans.sh` scans task plans and
flags violations so you can fix them before running auto mode.

## Upgrading

There is no version check (yet — M035 P01 adds an `orchestrator:status` drift-warning surface; M035 P06 adds an `orchestrator:update` first-class command at launch). Until then, upgrade manually: pull the latest orchestrator repo and re-run the installer with `--force`:

```bash
cd /path/to/spec-kit-orchestrator
git pull
bash packaging/install/install-claude-code.sh --project-dir /path/to/your-project --force
```

`--force` re-stages the runtime unconditionally (runtime files are orchestrator-owned, not user-owned) and overwrites `.orchestrator/config.yml`. User-authored files — `specs/`, `CLAUDE.md` body edits, `.orchestrator/milestones/`, `.orchestrator/DECISIONS.md`, `.orchestrator/KNOWLEDGE.md`, etc. — are untouched.

**Known limitation (accepted):** if an upstream release removes a file that a previous install wrote, the stale file remains on disk. The new manifest won't list it, so it will not be removed on subsequent `--uninstall`. This is a deliberate trade-off; the alternative (diff manifests and delete) is a fast-follow.

Check `CHANGELOG.md` in the spec-kit-orchestrator repo for breaking changes before upgrading.

### Staying fresh across multiple consumer projects (recommended workflow)

If you maintain several projects that consume the orchestrator (e.g., dogfooding spec-kit-orchestrator itself plus separate consumer projects like `lakeledger`, `pbj-central`, `bbt-companion`), add this shell function to your `~/.zshrc` or `~/.bashrc`:

```bash
orchestrator-update() {
  local repo="${ORCHESTRATOR_REPO:-$HOME/Sites/spec-kit-orchestrator}"
  ( cd "$repo" && git pull --ff-only ) || return
  bash "$repo/packaging/install/install-claude-code.sh" --force
}
```

Run it from each consumer project's root after the orchestrator repo updates:

```bash
cd /path/to/lakeledger
orchestrator-update

cd /path/to/pbj-central
orchestrator-update
```

Override the orchestrator repo path with `ORCHESTRATOR_REPO=/path/to/clone orchestrator-update` if you keep yours somewhere other than `~/Sites/spec-kit-orchestrator`.

This is the **bridge workflow until M035 P01 ships** (which will add a `--mode=symlink` install option that makes the per-project re-install unnecessary — a single `git pull` in the orchestrator repo will be enough). At launch, M035 P02–P06 replace this entirely with `npm install -g @spec-kit/orchestrator` (or the homebrew/curl-pipe-bash equivalents).

### Dogfooding the orchestrator on itself (self-development)

When you're editing the orchestrator's own commands and scripts (i.e., `PROJECT_DIR == REPO_ROOT == /path/to/spec-kit-orchestrator`), the freshness model is split:

- **Scripts, templates, references** (`scripts/`, `templates/`, `references/`) — **live**. The installer's `cp -R` from self to self is effectively a no-op, and every `commands/*.md` invokes helpers via project-relative paths that resolve to the in-tree files. Edits take effect immediately on next invocation.
- **Skills** (slash commands like `/orchestrator:auto`) — **stale until re-registered**. Skills are registered into `~/.claude/skills/` (user-global) at install time; a subsequent edit to `commands/auto.md` is invisible to slash-command resolution until you re-run the installer.

To refresh skill registration without a full re-install of consumer-project artifacts:

```bash
# From the orchestrator repo root:
bash packaging/install/install-claude-code.sh --force
```

The installer is idempotent for skill registration; the no-op `cp -R` for runtime dirs is harmless. Re-run it any time you edit a `commands/*.md` file and want the change reflected in the slash-command palette.

Once M035 P01 ships, `--mode=symlink` will register skills as symlinks pointing at the orchestrator repo, eliminating this re-register-on-edit cycle entirely.

## Uninstall

All three installers support `--uninstall`:

```bash
bash packaging/install/install-claude-code.sh --project-dir /path/to/your-project --uninstall
```

The uninstall path reads `.orchestrator/installed-files.txt` and removes exactly the files listed — every staged `scripts/*`, `templates/*`, and `references/*` entry — then prunes empty runtime directories bottom-up. The Claude Code installer additionally strips orchestrator-managed entries from `~/.claude/settings.json` via `scripts/util/settings-merge.sh uninstall`. The final `UNINSTALLED:` line reports `hooks-removed=<N> config-removed=<0|1> runtime-removed=<N>` (Claude Code) or `runtime-removed=<N> config-removed=<0|1>` (Codex / Cursor).

If the manifest is missing, the installer refuses to guess at directory contents — it will not blindly `rm -rf` trees that might belong to the user. Reinstall to regenerate the manifest, then uninstall.

Uninstall does **not** touch `CLAUDE.md`, `specs/`, `.orchestrator/milestones/`, or any file not recorded in the manifest.

To remove only orchestrator-added hooks manually (for example on a machine where the installer is no longer available), open `~/.claude/settings.json` in an editor or jq and delete each hook object whose `_orchestrator_managed` field is `true`. Cascade the cleanup: if removing a hook leaves a wrapper object with an empty `hooks` array, remove the wrapper; if that leaves an event key (`Stop`, `PreToolUse`, …) with an empty array, remove the event key; if that leaves the top-level `hooks` object empty, remove the `hooks` key. Every other key — `$schema`, `statusLine`, `permissions`, sibling tools' hook entries — must stay untouched.

## Migrating from spec-kit

If you have an existing spec-kit project with state under `.specify/`, see `docs/migrating-from-speckit.md` for the migration path. The orchestrator preserves spec-kit as a migration *source* via `scripts/migrate/adapters/speckit.sh` and related tooling — it is not a runtime dependency.

**Stale `~/.specify/` after uninstalling spec-kit globally:** if you previously had spec-kit installed and removed the CLI without also removing `~/.specify/`, a standalone orchestrator project can still see the home-directory `.specify/` when scripts walk upward looking for project roots. Build-context's spec resolver is hardened against this (it checks `.orchestrator/` as a marker first), but other tooling may not be. If you're seeing unexpected "home directory" resolutions, remove the stale tree: `rm -rf ~/.specify`.

## Verification

After installation, verify the orchestrator is working:

```bash
# Check that scaffold.sh is executable and has correct syntax
bash -n scripts/lifecycle/scaffold.sh && echo "scaffold.sh OK"

# Check that derive-phase.sh is executable
bash -n scripts/state/derive-phase.sh && echo "derive-phase.sh OK"

# Check that read-config.sh works
bash scripts/state/read-config.sh default_tier && echo "read-config.sh OK"
```

## `--with-<feature>` Progressive Opt-In Flag Pattern

The orchestrator's installer commands honor a project-wide convention for
progressive-opt-in feature flags shaped as `--with-<feature>`. Each flag
follows three invariants:

- **Default-off** — the consumer never receives the feature surface unless
  they explicitly request it. This is Constitution I (Context Minimization)
  applied to the consumer-facing install surface: extra capability is an
  operator decision, not an installer default.
- **Independently composable** — every `--with-` flag is order-invariant
  and stateless with respect to every other `--with-` flag. Presence of
  one flag does not change the semantics of another. Composition is
  defined by the per-flag contract, not by flag-presence interactions.
- **Opt-in is reversible** — every `--with-<feature>` flag has a documented
  reversibility path (the inverse of the feature surface) that operators
  can run after the fact. Feature surfaces that cannot be cleanly removed
  do not qualify for the `--with-` pattern; they require a new gating
  primitive.

### Canonical M032 prior art (FR-13)

The first three flags landing under this pattern are M032's wiki tooling
trio:

- `--with-wiki` (FR-11) — installs `wiki/` tooling alongside the default
  `init` surface. Composes with `init`'s default flag set; reversibility
  is `rm -rf <project>/wiki/` plus removal of the corresponding
  `installed-files.txt` entries.
- `--with-giscus --repo <owner>/<repo> --category <name>` (FR-8) —
  configures Giscus comments against the consumer's own GitHub Discussions.
  Composes with `--with-wiki`; reversibility is re-running `--with-giscus`
  against a different repo/category, or manually editing the partial.
- `--deploy [--force-pages-reconfigure]` (FR-9 / MIT-007) — first GH Pages
  push. Composes with `--with-wiki --with-giscus`; reversibility is
  `gh repo edit --enable-pages=false` plus deleting the `gh-pages` branch.
  The `--force-pages-reconfigure` opt-in inside this flag handles the
  case where Pages was already configured for a different source on the
  consumer's repo (MIT-007 read-before-write Pages guard).

### Future flags (forward-compatibility commitments)

The `--with-` pattern is the documented precedent for future feature
surfaces. Anticipated additions:

- `--with-github-integration` (M013/M014 progressive opt-in fold-in) —
  enables GitHub-native sidecar tooling (issues/PRs/discussions adapter
  shim).
- `--with-design-layer` (M023, post-launch) — installs the design-layer
  fan-out tooling (`orchestrator:design` and the renderer adapter tree).

Each future flag will inherit the three invariants above. Adding a new
`--with-<feature>` flag requires (a) explicit documentation in this
section, (b) integration tests asserting the flag composes cleanly with
every existing `--with-` flag, and (c) a documented reversibility path.

### See also

- `commands/wiki-init.md` — the canonical `--with-wiki` / `--with-giscus`
  / `--deploy` flag-chain command surface.
- `tests/m032-acceptance/throwaway-fixture-protocol.md` — the live-deploy
  test discipline (`--deploy` is the highest-blast-radius `--with-` flag
  in M032; CON-5 mandates live-fixture testing rather than synthetic
  stubs).
