# Installation Reference

> How to install orchestrator for use in a project.
> Self-contained — follow this document to set up orchestration in any project.

## Overview

orchestrator is a standalone autonomous orchestrator. It is distributed as a runtime-specific installer that runs from a clone of this repo. The installer does three things:

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

This project uses the orchestrator.

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

orchestrator's Tier C autonomous mode (`orchestrator:auto`)
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
cd /path/to/orchestrator
git pull
bash packaging/install/install-claude-code.sh --project-dir /path/to/your-project --force
```

`--force` re-stages the runtime unconditionally (runtime files are orchestrator-owned, not user-owned) and overwrites `.orchestrator/config.yml`. User-authored files — `specs/`, `CLAUDE.md` body edits, `.orchestrator/milestones/`, `.orchestrator/DECISIONS.md`, `.orchestrator/KNOWLEDGE.md`, etc. — are untouched.

**Known limitation (accepted):** if an upstream release removes a file that a previous install wrote, the stale file remains on disk. The new manifest won't list it, so it will not be removed on subsequent `--uninstall`. This is a deliberate trade-off; the alternative (diff manifests and delete) is a fast-follow.

Check `CHANGELOG.md` in the orchestrator repo for breaking changes before upgrading.

### Staying fresh across multiple consumer projects (recommended workflow)

If you maintain several projects that consume the orchestrator (e.g., dogfooding orchestrator itself plus separate consumer projects like `lakeledger`, `pbj-central`, `bbt-companion`), add this shell function to your `~/.zshrc` or `~/.bashrc`:

```bash
orchestrator-update() {
  local repo="${ORCHESTRATOR_REPO:-$HOME/Sites/orchestrator}"
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

Override the orchestrator repo path with `ORCHESTRATOR_REPO=/path/to/clone orchestrator-update` if you keep yours somewhere other than `~/Sites/orchestrator`.

This is the **bridge workflow until M035 P01 ships** (which will add a `--mode=symlink` install option that makes the per-project re-install unnecessary — a single `git pull` in the orchestrator repo will be enough). At launch, M035 P02–P06 replace this entirely with `npm install -g @build-fractal/orchestrator` (or the homebrew/curl-pipe-bash equivalents).

### Dogfooding the orchestrator on itself (self-development)

When you're editing the orchestrator's own commands and scripts (i.e., `PROJECT_DIR == REPO_ROOT == /path/to/orchestrator`), the freshness model is split:

- **Scripts, templates, references** (`scripts/`, `templates/`, `references/`) — **live**. The installer's `cp -R` from self to self is effectively a no-op, and every `commands/*.md` invokes helpers via project-relative paths that resolve to the in-tree files. Edits take effect immediately on next invocation.
- **Skills** (slash commands like `/orchestrator:auto`) — **stale until re-registered**. Skills are registered into `~/.claude/skills/` (user-global) at install time; a subsequent edit to `commands/auto.md` is invisible to slash-command resolution until you re-run the installer.

To refresh skill registration without a full re-install of consumer-project artifacts:

```bash
# From the orchestrator repo root:
bash packaging/install/install-claude-code.sh --force
```

The installer is idempotent for skill registration; the no-op `cp -R` for runtime dirs is harmless. Re-run it any time you edit a `commands/*.md` file and want the change reflected in the slash-command palette.

Once M035 P01 ships, `--mode=symlink` will register skills as symlinks pointing at the orchestrator repo, eliminating this re-register-on-edit cycle entirely.

## Symlink-mode caveats

`--mode=symlink` (M035 P01) links the consumer's runtime tree (`scripts/`, `commands/`, `references/`, `templates/`, `wiki/`) directly at the orchestrator source repo path, so a single `git pull` in the source repo updates every consumer immediately. This is the developer dogfood-velocity contract — the recommended mode when you are actively developing the orchestrator across multiple consumer projects on one machine. The defaults remain `--mode=copy` because copy mode is platform-agnostic and survives source-repo motion.

The constraints:

- **Unix-only at v1** (`#Q-8`). Symlink mode requires POSIX `ln -s`. Windows-native filesystems are fail-closed: the installer exits non-zero with `FAIL: symlink mode unsupported on this filesystem -- re-run with --mode=copy` on stderr. Copy mode (the default) is platform-agnostic. Windows symlink support defers to M009 post-launch.

- **Source-path stability**: the symlink target is the absolute orchestrator source repo path captured at install time. Moving or deleting the source repo breaks the consumer install loud — `find <project>/scripts -type l` resolves to a missing path. Recovery is `--uninstall` followed by re-install in copy mode, or restoring the source repo at its original absolute path.

- **Cross-machine fragility** (`#Q-7`): symlinks survive `git pull` in the source repo cleanly on one machine, but break across machines. A repo cloned to a different absolute path on a second machine produces broken symlinks until you re-install. Hardlink mode is intentionally not offered at v1 because hardlinks would silently desynchronize on `git pull` (each pull rewrites the inode rather than updating the existing one).

- **Bundle hygiene**: symlink mode bypasses pre-publish bundle filters. Files visible in a symlink-mode consumer's runtime tree (e.g. dogfood-only fixtures under `scripts/`, in-development experimental templates) may be excluded from copy-mode adopter installs by design. If you publish or share with adopters who consume via the published packages, validate against a fresh `--mode=copy` install rather than a symlink-mode install.

In practice: symlink mode is for the orchestrator-developer's own machine. Adopters should use copy mode (the default).

### Rollback-and-symlink-mode-interaction

`orchestrator:update --rollback` (FR-12, M035 P05) reverts a copy-mode install to the previous version's manifest byte-for-byte using the `.orchestrator/.previous-version` rollback marker.

In symlink mode the runtime tree is a set of symlinks into the orchestrator source repo; the runtime is always at HEAD by construction. There is no "previous version" of a symlink to restore — the symlink resolves to whatever the source repo currently contains.

Therefore `--rollback` is unsupported in symlink mode. P05 will emit the documented advisory:

```
rollback not available for symlink-mode installs -- symlink-mode consumers
are always at HEAD; to revert, run `git checkout <prior-sha>` in the
orchestrator source repo.
```

and exit non-zero. This constraint is recorded here so P05 plan-phase has the contract on disk; M035 P01 ships no `--rollback` code (the `#Q-G8` resolution).

## Channel-specific metadata files

The cross-channel byte-equivalence contract (Constitution Principle XVI / FR-14 / SC-10 / SC-12 / CON-5) requires the runtime layout produced by every distribution channel — npm, homebrew, curl-pipe-bash — to be byte-identical at a given release tag. This is verified by hashing the staged runtime tree post-install and comparing across channels.

The hash MUST exclude **per-install metadata files** that are legitimately channel-specific. The canonical exclusion list (M035 P02 T03 / MIT-2 enumeration):

| Path                              | Channel(s) | Why excluded                                                  |
|-----------------------------------|------------|---------------------------------------------------------------|
| `.orchestrator/install-meta.txt`  | all        | Operator-specific absolute paths (FR-6).                      |
| `.orchestrator/.previous-version` | all        | Per-install rollback marker (FR-12).                          |
| `package.json`                    | all        | Package manifest carried in the npm pack tarball; identical across channels. Excluded for symmetric hashing (papercut-sweep-post-M035 PC-3). |
| `package-lock.json`               | all        | npm transitive lock; only present after `npm install` against a non-pack-tarball source. Excluded defensively in case a future change creates one. |
| `node_modules/`                   | all        | npm-installed dependencies. Not present in our pack tarball today; excluded defensively. |
| `.brew/*.bottle.tab`              | homebrew   | Homebrew receipt files (P03 will introduce).                  |
| `Library/Caches/Homebrew/`        | homebrew   | Homebrew bottle cache (P03).                                  |
| `.git/`, `.github/`               | all        | Repository metadata; not staged into adopter projects.        |

Plan-phase authors extending this list (P03, P04, future distribution channels) MUST update this section first, then reference it from `tests/m035-acceptance/cross-channel-byte-equivalence.sh`. The test reads the exclusion globs from this document at runtime via grep — no hardcoded list duplication.

## Verifying integrity

Every published release ships with cryptographic integrity primitives so operators can verify what they're installing. Two verification paths are supported.

### Path 1: Sigstore keyless verification (recommended)

Sigstore provides keyless signature verification — the signing identity is the GitHub Actions OIDC token bound to the canonical release workflow at the moment of signing. No project-managed GPG key, no key import ceremony.

**Prerequisites**: [`cosign`](https://docs.sigstore.dev/cosign/installation) installed (typically `brew install cosign` on macOS or download from the [GitHub releases page](https://github.com/sigstore/cosign/releases)).

**Verification**:

1. Download the release artifact, signature, and certificate:

   ```bash
   VERSION="<X.Y.Z>"  # the release version, e.g. 1.0.0
   ARTIFACT="install.sh"  # or build-fractal-orchestrator-$VERSION.tgz, etc.
   curl -sSL -O "https://github.com/Build-Fractal/orchestrator/releases/download/v$VERSION/$ARTIFACT"
   curl -sSL -O "https://github.com/Build-Fractal/orchestrator/releases/download/v$VERSION/$ARTIFACT.sig"
   curl -sSL -O "https://github.com/Build-Fractal/orchestrator/releases/download/v$VERSION/$ARTIFACT.pem"
   ```

2. Verify the signature:

   ```bash
   cosign verify-blob \
     --certificate-identity "https://github.com/Build-Fractal/orchestrator/.github/workflows/release.yml@refs/tags/v$VERSION" \
     --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
     --signature "$ARTIFACT.sig" \
     --certificate "$ARTIFACT.pem" \
     "$ARTIFACT"
   ```

   Expected output: `Verified OK`. Exit code: 0.

The identity URL embeds the canonical repo (`Build-Fractal/orchestrator`), the workflow file path (`.github/workflows/release.yml`), and the exact tag (`refs/tags/v<VERSION>`) — three load-bearing constraints that make a forged signature impossible without a compromise of GitHub's OIDC issuer.

### Path 2: SHA-256 checksum verification (no cosign required)

Every release also ships a `SHA256SUMS` file that operators can verify with stock `shasum`. This path requires no third-party tooling.

**Verification**:

1. Download the artifact and `SHA256SUMS`:

   ```bash
   VERSION="<X.Y.Z>"
   curl -sSL -O "https://github.com/Build-Fractal/orchestrator/releases/download/v$VERSION/install.sh"
   curl -sSL -O "https://github.com/Build-Fractal/orchestrator/releases/download/v$VERSION/SHA256SUMS"
   ```

2. Verify the checksum:

   ```bash
   shasum -a 256 -c SHA256SUMS --ignore-missing
   ```

   Expected output: `install.sh: OK`. Exit code: 0.

The `--ignore-missing` flag skips checksum lines for artifacts not downloaded (e.g. if you downloaded only `install.sh`, the npm tarball line is silently skipped).

**Defense-in-depth**: `SHA256SUMS` itself is signed with cosign — `SHA256SUMS.sig` and `SHA256SUMS.pem` are also published. Operators who want both paths verified can run Path 1 against `SHA256SUMS` first, then Path 2 against the artifacts.

### What to do if verification fails

1. **Do not install.** A failed verification means the artifact you downloaded does not match what was published.
2. **Re-download** in case of a transient corruption — different CDN edge, different network — and re-run verification.
3. **If verification still fails**, file an issue at [Build-Fractal/orchestrator/issues](https://github.com/Build-Fractal/orchestrator/issues) with the exact `cosign`/`shasum` output. Attach the failing artifact's SHA-256 hash so maintainers can compare against the published value.
4. **Audit the Sigstore Rekor transparency log** at [search.sigstore.dev](https://search.sigstore.dev/) to confirm the published signature was issued by the canonical workflow. The release notes for each version include a direct Rekor entry link.

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

## Wiki Deploy Targets (GitHub Pages vs. Cloudflare Access)

The orchestrator wiki supports two deploy targets, selected by
`wiki.deploy_target` in `.orchestrator/config.yml`: the default `github-pages`
and `cloudflare-access`. The mkdocs build pipeline is identical across both —
only the deploy step differs.

### The Enterprise-only private-Pages pitfall

A **private, access-controlled GitHub Pages site is a GitHub Enterprise Cloud–only
feature.** On Free / Pro / Team, enabling Pages on a private repo publishes the
site — and the entire `.orchestrator/` corpus it surfaces (spec, decisions, GTM,
SME discussions, milestones) — **world-readable to anyone with the URL**. This is
the silent-exposure footgun that bit `pbj-central` (validated 2026-06-04). The
`orchestrator:status` / `orchestrator:doctor` warning (FR-10) fires on the
(private repo + `github-pages`) tuple to surface this; it carries an "ignore if
Enterprise Cloud" note because that plan supports private Pages.

### The build-green / deploy-422 lapsed-entitlement failure mode

When a GitHub Enterprise entitlement lapses (the observed case: a trial reverting
to Team), `actions/deploy-pages` begins returning **HTTP 422** on every push
(`"Page is disabled because current plan does not support private GitHub Pages"`)
**while the build job stays green.** The run list looks healthy, the live wiki
silently freezes for days, and the root cause reads as a content/config issue
when it is actually a plan entitlement. Treat a green build + frozen live site as
a plan-entitlement check first.

### Recipe: Cloudflare Pages + Access (plan-independent gated wiki)

`cloudflare-access` is free, plan-independent, and gates the site by SSO /
one-time-PIN. Steps:

1. Create a free Cloudflare account and **enable Cloudflare Zero Trust** in the
   dashboard (a one-time step that **cannot** be API-triggered — see the
   prerequisite below).
2. Create a scoped Cloudflare API token and store it plus the account id as
   GitHub repo secrets `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`.
3. Set `wiki.deploy_target: cloudflare-access` and the `wiki.cloudflare:`
   sub-block (`project_name`, `allowed_email_domains`) in
   `.orchestrator/config.yml`.
4. Run `scripts/wiki/cloudflare-access-setup.sh` (via `orchestrator:wiki-init
   --deploy`, or directly) to provision the Pages project → Access app
   (apex + wildcard) → allow policy, in that order.
5. Push; the emitted `wiki-cloudflare.yml` runs the FR-3a pre-deploy Access
   health check, then deploys via `npx --yes wrangler@4 pages deploy`.

### Required API-token scopes

The Cloudflare API token needs exactly:

- **Account › Cloudflare Pages › Edit**
- **Account › Access: Apps and Policies › Edit**
- **Account › Account Settings › Read**

**No additional `Access: Apps and Policies › Read` scope is required.** The FR-3a
pre-deploy health check reuses the existing Edit-scope token — the Cloudflare Edit
permission grants the read access needed to query Access app / policy existence
(M043 P00 #Q-5-sub). If a future Cloudflare change removes that read grant, the
health check falls back to the unauthenticated `302 → cloudflareaccess.com`
redirect probe, which needs no token scope at all.

### Zero Trust prerequisite

`cloudflare-access-setup.sh` cannot enable Cloudflare Zero Trust for you — it is a
one-time dashboard action. If Zero Trust is not enabled, the provisioner exits
non-zero (exit 4) with a diagnostic naming the dashboard step, **before** any
deploy can expose content. A token missing the Access scope exits 5 with a
scope-specific diagnostic.

### Symmetric failure mode: Cloudflare entitlement lapse

The Cloudflare path is not held to a lower documentation standard than the GitHub
Pages path it replaces. Cloudflare has its **own** entitlement-lapse failure
modes (THREAT-7): a **trial → free downgrade**, growth past the **50-user
free-tier Access limit**, or a billing change can disable or degrade the Access
gate. The observable signal is the Cloudflare dashboard state
**plus the FR-3a pre-deploy health-check failing the CI deploy** — the same
loud-not-silent
contract the GitHub-Pages 422 mode lacks. A green build that stops deploying on
the Cloudflare target is a Cloudflare-entitlement check first.

### Custom domains and extending the Access app

To serve the wiki on a custom domain instead of `<name>.pages.dev`, add the
custom hostname in Cloudflare Pages **and** extend the Access application's
`self_hosted_domains` to cover it (THREAT-11) — otherwise the new hostname is
served **ungated**. Re-run `cloudflare-access-setup.sh` (or edit the Access app)
so the apex, wildcard, and custom domains are all gated.

### Caveat: editing `allowed_email_domains` (CON-7)

`wiki.cloudflare.allowed_email_domains` is an access-control list. Until the M037
yaml-merge list-element preservation gap closes, **do not rely on
`orchestrator:update` config-merge to carry domain-list edits** — a silently
emptied list is a lockout / data-loss event. Apply domain-list changes by
re-running `cloudflare-access-setup.sh`, which reapplies the Access policy.

### giscus: read-but-not-comment for Access-authenticated non-collaborators

giscus is unchanged on both targets. Note (FR-12): a viewer authenticated through
Cloudflare Access who is **not** a GitHub collaborator on the repo can **read**
the giscus comment thread but **cannot post** — commenting requires a GitHub
identity with Discussions access. This is expected behavior, not a bug.

## Installing via Homebrew

The `build-fractal/orchestrator` Homebrew tap publishes a single
formula (`orchestrator`) for macOS and Linuxbrew users.

**Install**:

```bash
brew tap build-fractal/orchestrator
brew install orchestrator
```

**Verify**:

```bash
orchestrator --version
# → should match the latest published tap version
```

**Per-project setup**: `brew install orchestrator` stages the
runtime tree into the Homebrew Cellar and wires `orchestrator` onto
PATH. Skill registration is per-project — run `/orchestrator-init`
inside each project directory where you want orchestrator skills
available. Same model as the npm channel.

**Uninstall**:

```bash
brew uninstall orchestrator
brew untap build-fractal/orchestrator
```

`brew uninstall` removes the Cellar files; per-project skill
registrations cascade away the next time you run
`/orchestrator-update` or `/orchestrator-init` in a project that
previously had skills registered, via M025's manifest mechanism.

**Cross-channel byte-equivalence**: at any given release tag, the
runtime layout produced by `brew install orchestrator` is
byte-identical to the layout produced by `npm install -g
@build-fractal/orchestrator` and (post-P04) `curl -sSL <install-
url> | bash`, modulo the per-channel metadata files documented
above in § Channel-specific metadata files. This is enforced by
`tests/m035-acceptance/cross-channel-byte-equivalence.sh`
(Constitution Principle XVI).

## Releasing via Homebrew

This section is operator-only — adopters do not need to follow it.

The Homebrew formula is published to the
`Build-Fractal/homebrew-orchestrator` tap repo automatically by the
`homebrew-publish` job in `.github/workflows/release.yml` on every
`v*` tag push to the canonical `Build-Fractal/orchestrator` repo.
The job:

1. Reads the SHA-256 of the just-published `.tgz` from the
   release's `SHA256SUMS` file.
2. Renders `Formula/orchestrator.rb` from
   `packaging/homebrew/orchestrator.rb.tmpl` via
   `packaging/homebrew/render-formula.sh`.
3. Pushes the rendered formula to the tap repo's `main` branch.

**One-time operator setup** (before the first `v*` tag push that
should publish a formula):

1. Create the `Build-Fractal/homebrew-orchestrator` GitHub repo
   (empty or with a stub README pointing back to the canonical
   repo). Default branch `main`. No protection rules required for
   v1.
2. Generate a Personal Access Token (PAT) scoped to
   `Build-Fractal/homebrew-orchestrator:contents:write` only — no
   other scope, no other repo. Store it as
   `secrets.HOMEBREW_TAP_TOKEN` in the canonical
   `Build-Fractal/orchestrator` repo's Actions secrets.

**PAT rotation cadence**: rotate before each major release, or
annually, whichever comes first. PATs default to 90-day expiry; if
the PAT expires unobserved, the next tap-push fails with a 401 and
the operator regenerates the PAT and re-runs the workflow against
the same tag (no artifact corruption, no orphan formula).

**PAT revocation**: revoke immediately if the canonical repo's
secrets are rotated for any reason; regenerate after rotation. The
`homebrew-publish` job is the only consumer of this secret.

**CON-6 (secrets-scoped-to-tag-push) compliance**: the
`homebrew-publish` job's `if:` predicate
(`startsWith(github.ref, 'refs/tags/v') && github.event_name ==
'push'`) gates secret access. The `pr-validate` job carries an
explicit negative-assertion step asserting `HOMEBREW_TAP_TOKEN` is
empty in PR context (SC-14 verified).

**GitHub App migration**: if PAT rotation friction surfaces, swap
the PAT for a GitHub App token with `contents:write` scope on the
tap repo only. The migration is a single-secret rotation; no
formula or workflow changes are required (the PAT is consumed via
the standard `x-access-token:<token>@github.com` HTTPS pattern,
which a GitHub App installation token also satisfies).

## Installing via curl-pipe-bash

The simplest way to bootstrap orchestrator on a fresh machine is the
curl-pipe-bash one-liner — no clone, no package manager, just
`install.sh` from the GitHub release.

**Latest release**:

```bash
curl -sSL https://github.com/Build-Fractal/orchestrator/releases/latest/download/install.sh | bash
```

**Pinned to a specific version**:

```bash
ORCHESTRATOR_VERSION=v1.0.0 \
  curl -sSL https://github.com/Build-Fractal/orchestrator/releases/download/v1.0.0/install.sh | bash
```

`install.sh` downloads the npm tarball asset from the GitHub release
(D007 single source of truth — same tarball as `npm install -g
@build-fractal/orchestrator` consumes), verifies its SHA-256 against
the published `SHA256SUMS` file, extracts it into a temporary
staging directory, and dispatches into `packaging/install/install-claude-code.sh`
with the current working directory as the project root.

**Smoke test post-install**:

```bash
orchestrator --version
# → matches the latest published release version
```

**Per-project setup** (run once per project after install):

```bash
/orchestrator-init
```

Registers the orchestrator skills under `~/.claude/skills/` so the
`orchestrator:<cmd>` cohort is discoverable in any Claude Code
session in that project.

**Uninstall**:

```bash
bash packaging/install/install-claude-code.sh --uninstall
```

The uninstall reads `.orchestrator/installed-files.txt` and removes
exactly the files staged at install time, mirroring the npm and
homebrew uninstall paths.

**Runtime support at v1**: Claude Code only. `install.sh` detects
`~/.claude/` presence; absence triggers a Codex-CLI-/Cursor-deferred-to-M009
advisory and exits non-zero. Post-launch M009 (multi-runtime parity
audit) extends to Codex CLI and Cursor.

**Verifying integrity before install** (optional, recommended for
production deployments): see `## Verifying integrity` above for the
sigstore keyless cosign-verify-blob recipe + SHA256SUMS-shasum-c
fallback. The same verification applies to install.sh as to the npm
tarball — both are signed by the same workflow at the same release
tag (P05 D004).

## Releasing via curl-pipe-bash

`install.sh` is published as a release asset on the canonical repo
`Build-Fractal/orchestrator` GitHub release for every `v*` tag push.
Three load-bearing decisions govern the release procedure:

### D009 — install.sh URL host: GitHub release asset URL

`install.sh` is hosted at `https://github.com/Build-Fractal/orchestrator/releases/latest/download/install.sh`
(latest, unpinned) and `https://github.com/Build-Fractal/orchestrator/releases/download/v<X.Y.Z>/install.sh`
(version-pinned). Rationale: zero new infrastructure, symmetric with
the npm + homebrew release-asset distribution model, reversible to
a polished short URL post-launch. See `.orchestrator/DECISIONS.md`
D009 for the full decision record.

### D010 / CON-8 — Release-workflow CI timeout: 20 minutes on ubuntu-latest

Both `npm-publish` and `homebrew-publish` jobs in `.github/workflows/release.yml`
carry `timeout-minutes: 20` at job level. Nominal wall-clock is ~3min;
the 20min budget provides 6× headroom for OIDC issuance latency,
transient network failures, and cosign/sigstore log-write retries.

**CON-8 escalation clause**: if measured wall-clock consistently
exceeds 15 minutes across three synthetic-tag runs, the next
plan-phase author either splits the workflow into parallel jobs or
documents a revised timeout. CON-8 is documentation-only at v1 (no
automation enforces the watermark); future work could add a CI-side
measurement-and-alert step.

### D011 — Release cadence: manual stable releases pre-1.0

Pre-1.0, releases are operator-driven: the operator authors
`CHANGELOG.md` for the release, bumps the version in `package.json`
(CON-4 SemVer source of truth), commits, and pushes a `v*` tag. The
release-workflow fires automatically on the tag push.

Post-1.0, the spec recommends conventional-commits-driven version
bumping with PR-merge auto-tagging — that is post-launch fast-follow
scope (no code surface at v1).

See `.orchestrator/DECISIONS.md` D011 for the full decision record.

### MOS-4 (operator) — One-time `curl … | bash` smoke against the first published release

On first publication of a `v*` tag (e.g., the v1.0.0 launch), the
operator validates end-to-end:

```bash
# Fresh machine (or container with bash + curl + tar + shasum):
curl -sSL https://github.com/Build-Fractal/orchestrator/releases/latest/download/install.sh | bash
orchestrator --version
# → matches v1.0.0
```

Asserts the GitHub `latest/download` URL resolves, install.sh is
signed (sigstore + SHA-256 fallback per P05 D004), the dispatched
install-claude-code.sh runs to completion. SC-14 is satisfied by
this manual smoke.

### MOS-5 (operator) — Synthetic `v0.0.0-test` tag push against a fork

Before the v1.0.0 launch, exercise SC-14 end-to-end via a synthetic
tag push against a personal fork of `Build-Fractal/orchestrator`:

```bash
git tag v0.0.0-test
git push origin v0.0.0-test
```

Observe the release workflow runs to completion within the CON-8
20-minute timeout, the resulting GitHub release contains the four
required artifacts (npm tarball, homebrew bottle, signed install.sh,
SHA256SUMS file). Same workflow on a PR build does NOT run
secret-bearing steps (verified by the existing CON-6 negative-assertions
in `pr-validate`). After verification, delete the synthetic release
and tag from the fork.
