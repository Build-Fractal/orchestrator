# Proposal: M035 — Packaging & Distribution

**Captured**: 2026-04-28 during roadmap-fit assessment session
**Shape**: Milestone (6 phases — P00 baseline + P01 pre-launch dev-ergonomics bridge + P02–P06 launch-event publishing)
**Predecessors**: M025 (installer coexistence — settings.json merge helper, manifest, uninstall cascade), M032 (project-asset distribution — `--with-<feature>` flag pattern, `project_assets:` schema), M029 (`orchestrator:where` + headline status — surface for version-drift warning)
**Source**: 2026-04-28 operator session question — *"What's the best way to ensure this project, dogfooding itself, is using the latest orchestrator code? And how do I make sure I'm using the latest version for my other projects like lakeledger or pbj-central?"* Surfaced a roadmap gap: pre-launch queue (M028→M030→M031→M032→M033→M029) carries no explicit "ship to package managers" milestone. M032 covers asset distribution *within* a consumer project (wiki tooling, mkdocs); it does **not** cover orchestrator-itself distribution to npm / homebrew / curl-pipe-bash. Without M035, "launch" is implicit and underspecified.

## Goal

The launch-readiness milestone. Two layers, sequenced:

1. **Pre-launch ergonomics (P00 + P01)** — bridge the staleness gap that exists today between in-tree edits and what consumer projects (lakeledger, pbj-central, bbt-companion) actually run. `--mode=symlink` install option + `orchestrator:status` version-drift warning + documented `orchestrator-update` shell-function recipe. Ships *before* launch as quality-of-life infrastructure for the small number of pre-launch dogfooders.
2. **Launch-event publishing (P02–P06)** — package-manager publishing pipelines (npm, homebrew, curl-pipe-bash one-liner), GitHub release automation with versioned artifacts, install-script integrity (signature, checksum, rollback), and `orchestrator:update` first-class command that uses the package manager and falls back to git-pull. **These phases ARE launch.** Once they ship, `npm install -g @spec-kit/orchestrator` (or equivalent) replaces the "clone + bash install.sh" path that exists today.

## Why M035 (not extending M032 / M025 / M029)

**M032** scopes *project-local-asset distribution* — wiki tooling, mkdocs templating, `--with-<feature>` flag pattern. It distributes assets *into* a consumer project; it does not distribute the orchestrator itself outward. Bundling launch-publishing into M032 conflates two distribution surfaces.

**M025** scopes *installer coexistence* — multi-runtime hook merging, manifest, uninstall cascade. It assumes the install script has already been delivered to the operator's machine; it does not solve "how does the install script *get* to the machine in the first place." M035 is the upstream of M025's territory.

**M029** scopes *roadmap visibility & CLI UX* — `orchestrator:where` tree + headline status. The version-drift warning (M035 P01) surfaces *via* M029's headline-status block but is not authored by M029 — M035 owns the drift-detection logic and freshness contract; M029 owns the rendering surface.

**`references/installation.md` `## Upgrading` section** is the canonical sibling. Today it documents "no version check; pull the orchestrator repo and re-run the installer with `--force`" (line 231-245). That's the manual workflow M035 mechanizes.

Naming as a new milestone keeps M032's project-asset surface narrow, keeps M025's installer-internals stable, keeps M029's status-surface focused, and gives M035 its own success criteria around launch readiness.

## Why pre-launch (P00 + P01) AND launch-event (P02–P06)

The split is load-bearing:

- **P00 + P01 ship pre-launch** because the small number of pre-launch dogfooders (operator + collaborators on lakeledger, pbj-central, bbt-companion) *already* hit the staleness gap today — every commands edit requires re-install across consumer projects, and there's no warning when a consumer project's installed runtime drifts from upstream HEAD. The fix is small (~half-day of work) and unblocks dogfooding velocity for every milestone after it ships.
- **P02–P06 ship at launch** because package-manager publishing is the *event* that makes the orchestrator broadly installable. Until then, the install path is "clone the GitHub repo + bash a script" — fine for early adopters, hostile for casual evaluators. P02–P06 don't need to ship before launch; they *constitute* launch.

Slot recommendation: **M035 is the final pre-launch milestone**. The pre-launch queue becomes:

```
M028 → M030 → M031 → M032 → M033 → M029 → M035 → ─── launch ───
                                                   (M035 P02-P06 ARE the launch event)
```

M035 P00 + P01 land as soon as M029 closes; P02–P06 are the launch ramp.

## Strict scope

This is **distribution + dev ergonomics for keeping installs fresh**. It is **not**:

- A re-architecture of the installer's internals — M025's territory.
- A change to the installed runtime's behavior — every other milestone touches that surface.
- A new project-bootstrap UX — M033's territory.
- A change to `orchestrator:status` rendering — M029's territory; M035 contributes data, not rendering.
- A spec-kit-style versioning scheme — adopt SemVer (already in use per CHANGELOG `v0.9.2`); don't reinvent.
- A docs-site / marketing-page launch — separate scope (likely a one-off project, not an orchestrator milestone).

M035 asks: *can a new operator install the orchestrator with a single package-manager command, and can existing consumer projects detect + fix staleness without manual re-install runs?*

## Findings (root-cause analysis)

### Finding A: Today's freshness model has two surfaces, both stale-by-default

**Evidence**: `packaging/install/install-claude-code.sh:295-318` copies runtime dirs (`scripts/`, `templates/`, `references/`, `commands/`) into `$PROJECT_DIR` via `cp -R`. Each consumer project carries its own pinned snapshot. M025 adapter (`scripts/dispatch/adapters/runtime/claude-code.sh`) registers skills into `~/.claude/skills/` (user-global) — also a copy.

**Two scenarios, different freshness gaps**:

| Scenario | Skills (`commands/*.md`) | Runtime dirs (`scripts/`, `templates/`, `references/`) |
|---|---|---|
| Orchestrator dogfooding itself (`PROJECT_DIR == REPO_ROOT`) | Stale — registered globally; in-tree edits to `commands/auto.md` invisible until re-install | **Live** — `cp -R` from self to self is a no-op; in-tree IS the runtime |
| Consumer project (lakeledger, pbj-central, bbt-companion) | Stale | Stale — copy taken at last install time |

**Root cause**: install model assumes pinned-snapshot semantics universally. Correct for production (consumer projects want stable, predictable runtime), but adversarial for development (every commands-edit requires re-install across N consumer projects + global skill re-registration).

**Fix shape (P01)**: `--mode=symlink|copy` flag. Default `copy` (preserves stable consumer-install semantics). `symlink` mode replaces runtime-dir copies with `ln -sfn` to the orchestrator repo + symlink-registered skills in `~/.claude/skills/`. Tradeoffs documented: consumer project carried to another machine breaks if symlink target absent; mid-edit state in orchestrator repo (M028 in flight, partial state) propagates to all symlink-mode consumers; Windows symlink behavior caveat (defer until M009 audits).

**Impact**: shipping `--mode=symlink` collapses the "edit + N×re-install" cycle to "edit + git-pull". For a multi-consumer-project dogfooder, this is the single biggest velocity unlock pre-launch. Not load-bearing for casual users (who'll install once via package manager post-launch).

### Finding B: No version-drift detection between consumer install and upstream HEAD

**Evidence**: `references/installation.md:231-245` documents the manual upgrade path explicitly: *"There is no version check. To upgrade, pull the latest orchestrator repo and re-run the installer with `--force`."* No automated detection exists. Operator must remember to run `git pull && bash install-claude-code.sh --force` per consumer project; no warning surfaces if they forget.

**Root cause**: scope, correctly. Pre-M035 the orchestrator had no canonical "upstream" to compare against (operator's local clone *was* upstream). Once M035 P02 ships an npm package, an upstream version exists.

**Fix shape (P01 partial — pre-package-manager era; refined in P06 — package-manager era)**:

- **P01 (pre-launch)**: `orchestrator:status` reads `CHANGELOG.md` top-line version from the consumer project's installed runtime *and* from a "known orchestrator repo" path (configurable; default `$HOME/Sites/spec-kit-orchestrator`). If consumer's version is older, prints `STALE: orchestrator runtime is N commits behind upstream — run \`orchestrator-update\``. ~50 LOC; fits cleanly into M029's headline-status surface.
- **P06 (at launch)**: replace "known orchestrator repo path" with "package-manager metadata" — `npm view @spec-kit/orchestrator version` (or homebrew equivalent) becomes the upstream-version source. Config option `update_source: git|npm|homebrew` defaults to `npm` post-launch. Pre-launch installs (still git-cloned) keep `update_source: git`.

**Impact**: prevents "I forgot to update lakeledger" silent staleness. Composes with M029's status surface (M035 contributes the drift datum; M029 renders).

### Finding C: No package-manager presence — `clone + bash` is the only install path today

**Evidence**: `packaging/install/install-claude-code.sh:1-2` declares the installer as a single bash script invoked from a clone of the repo. `docs/getting-started.md:31-50` documents the install as `bash packaging/install/install-{runtime}.sh --project-dir /path/to/project`. No npm/homebrew/curl-pipe-bash entries in any documentation.

**Root cause**: pre-launch, package-manager publishing is premature optimization. The install script needs to *work*, idempotently, across runtimes (M025) and across consumer projects (M028 hook portability) before it's worth shipping to package managers. M025 closed 2026-04-23; M028 is the next-up pre-launch milestone. Once M028 ships, the install script is package-manager-ready.

**Fix shape (P02–P05, AT-launch)**:

- **P02 — npm**: `package.json` declares `@spec-kit/orchestrator` (or chosen scope). Postinstall script wraps existing `install-claude-code.sh`. `npm install -g @spec-kit/orchestrator` puts an `orchestrator` binary on PATH (delegating to the same logic as today's `commands/*.md` entry points). Versioned releases via `npm publish` (manual at first; CI-automated in P04).
- **P03 — homebrew**: tap (`brew tap spec-kit/orchestrator && brew install orchestrator`). Cask vs formula decision deferred to P00 baseline. Idempotent re-tap; uninstall cascades through M025's existing uninstall path.
- **P04 — curl-pipe-bash + GH release automation**: `curl -sSL https://orchestrator.dev/install.sh | bash` (or GitHub-hosted `https://github.com/.../install.sh`). Same logic as `install-claude-code.sh` with auto-detection of runtime. CI publishes a tagged release on every `v*` tag push: `gh release create $TAG --generate-notes` + uploads npm tarball + homebrew bottle + signed install.sh.
- **P05 — install-script integrity**: signature (`gpg --sign install.sh`) + checksum (SHA-256 published alongside release) + rollback semantics (every release stores a `.previous-version` marker; `orchestrator:update --rollback` reverts).

**Impact**: replaces "clone + bash" with the canonical OSS install patterns. Adoption friction drops from "you need to know what `git clone` is" to "you've installed packages before, this works the same way."

### Finding D: `orchestrator:update` should be a first-class command, not a shell-function recipe

**Evidence**: today's recommended workflow (per the operator's pre-M035 guidance) is a shell function in `~/.zshrc`:

```bash
orchestrator-update() {
  ( cd "$HOME/Sites/spec-kit-orchestrator" && git pull --ff-only ) || return
  bash "$HOME/Sites/spec-kit-orchestrator/packaging/install/install-claude-code.sh" --force
}
```

This works pre-M035 but has three problems:
1. **Discoverability** — operator must know the recipe; it's not surfaced anywhere automatic.
2. **Per-machine setup** — every machine the operator works on needs the function added.
3. **No package-manager awareness** — when M035 P02 ships npm, the recipe still does `git pull` instead of `npm update -g @spec-kit/orchestrator`.

**Fix shape (P06 — at-launch)**: `commands/update.md` + `scripts/lifecycle/update.sh` register `orchestrator:update` as a first-class command. Reads `update_source: git|npm|homebrew` config (default `npm` post-launch). Performs source-appropriate update (`npm update -g` / `brew upgrade orchestrator` / `git pull`). Re-runs install (`--force`) to refresh consumer project's runtime stage. Emits an `update_run` JSONL event for M027 cost+quality observability rollups.

**Impact**: closes the loop. Pre-launch operators document the shell function (P01); at-launch operators run `orchestrator:update`. Same UX shape; different mechanism.

## Phase outline (preliminary — refined by `orchestrator:specify`)

| Phase | Goal | Touch list (preliminary) | Pre-launch or at-launch? |
|---|---|---|---|
| **P00** (recommended) | Empirical baseline + decisions | Manual publish of beta `@spec-kit/orchestrator` to npm under `@beta` tag; install on a fresh macOS + fresh Linux VM; friction inventory. Decisions: npm scope (`@spec-kit` vs `@orchestrator` vs unscoped), homebrew tap location, curl-pipe-bash domain, GPG signing keys, release-notes generation strategy. | Pre-launch — informs P01–P06 design |
| **P01** | Dev-install symlink mode + version-drift warning | `--mode=symlink\|copy` flag in `install-claude-code.sh` (and codex/cursor installers). M025 manifest extension to record symlink-vs-copy per entry (so uninstall handles both). `orchestrator:status` version-drift warning reading consumer's `CHANGELOG.md` vs known-orchestrator-repo `CHANGELOG.md`. Documented shell-function recipe in `references/installation.md`. | **Pre-launch** — ships immediately after M029 |
| **P02** | npm publishing pipeline | `package.json` with `@spec-kit/orchestrator` (or chosen scope). Postinstall script wraps existing `install-claude-code.sh`. `bin/orchestrator` entry point delegating to commands. `npm publish` works idempotently. | **At-launch** |
| **P03** | Homebrew formula + tap | `homebrew-orchestrator` tap repo. Formula authored. `brew install orchestrator` works on macOS + Linuxbrew. Uninstall cascades through M025. | **At-launch** |
| **P04** | curl-pipe-bash + GH release automation | `install.sh` hosted at GitHub release URL (or `orchestrator.dev` if domain registered by P00). CI workflow: `v*` tag push → `gh release create` + npm tarball upload + homebrew bottle + signed `install.sh` upload. | **At-launch** |
| **P05** | Install-script integrity | GPG signing in CI. SHA-256 checksums published alongside releases. Rollback semantics: `.previous-version` marker per install; `orchestrator:update --rollback` flag. | **At-launch** |
| **P06** | `orchestrator:update` first-class command | `commands/update.md` + `scripts/lifecycle/update.sh`. Reads `update_source: git\|npm\|homebrew`. Source-appropriate update + post-update install refresh. Emits `update_run` JSONL event. P01's drift-warning surface upgraded to recommend `orchestrator:update` instead of shell-function recipe. | **At-launch** |

P00 baseline serves both pre-launch (P01 design) and at-launch (P02–P06 design) phases — same fixture (fresh-machine install) used twice.

## Sequencing & dependencies

- **Slots last in pre-launch queue.** After M029, before launch event.
- **P01 ships pre-launch** (~half-day to one-day of work). Unblocks dogfooding velocity for every milestone after it lands.
- **P02–P06 ARE launch.** They constitute the launch event; orchestrator becomes broadly installable when P02–P06 close.
- **Composes with**:
  - M025 (manifest + uninstall — extends to handle symlinks)
  - M027 (`update_run` JSONL event flows into cost+quality observability rollups)
  - M029 (version-drift warning renders in headline-status surface)
  - M032 (`--with-<feature>` pattern — `--mode=symlink` follows similar flag-shape conventions)
- **Reuses (do not duplicate)**:
  - `scripts/util/settings-merge.sh` — install/uninstall cascade with `_orchestrator_managed` flag
  - `.orchestrator/installed-files.txt` manifest schema (extends with `mode: copy|symlink` per entry)
  - M025 reversibility-gate convention (pinned-sha round-trip — install→install→uninstall byte-equality)
  - `references/installation.md` `## Upgrading` section (current manual workflow doc — extended with symlink-mode + drift-warning subsections in P01)

## Open questions (for `orchestrator:specify` to resolve)

1. **npm scope** — `@spec-kit/orchestrator` vs `@orchestrator/cli` vs unscoped `spec-kit-orchestrator` vs `orchestrator` (likely taken). Trademark + collision check needed in P00 baseline.
2. **Homebrew strategy** — formula vs cask. Formula if the install delivers a CLI binary; cask if it's a "managed installation" (more meta). Recommendation: formula. Delegates the Claude-Code-skill registration to a post-install hook.
3. **curl-pipe-bash domain** — host on GitHub raw URL (free, ugly) vs register `orchestrator.dev` (~$15/yr, polished) vs sub-path of an existing domain. Recommendation: `orchestrator.dev` short URL alias to GitHub raw URL — simple redirect, no hosting infrastructure. Defer registration until P04.
4. **GPG signing key custody** — operator's personal key vs project key in CI secrets vs sigstore (keyless). Recommendation: sigstore for keyless signing, falls back to project CI key for compatibility.
5. **Release cadence** — every PR merge auto-publishes a `@beta` tag; manual `gh release create` for stable. Or stable on every `main` push? Recommendation: manual stable releases pre-1.0, automatic post-1.0 with conventional-commits-driven version bumping.
6. **`update_source` default in pre-launch installs** — `git` (current de facto) vs prompt at install time vs detect by install method. Recommendation: detect by install method — installs via npm get `npm`, installs via clone get `git`. Setting persisted in `.orchestrator/config.yml`.
7. **Symlink vs hardlink for P01 dev mode** — symlinks survive `git pull` cleanly but break across-machine; hardlinks survive across-machine but break across-filesystem-boundary. Recommendation: symlink only, document the tradeoff.
8. **Windows support** — defer or include? Symlinks on Windows require admin or developer-mode. Recommendation: defer until M009 (multi-runtime parity audit) ships post-launch and provides Windows runtime evidence. P01 documents `--mode=symlink` as Unix-only at v1.

## Constraints / antipattern compliance

- **AD-19 single-script-file shape** — `update.sh` is a single file. New install-script modes route through existing `install-claude-code.sh` (extended with `--mode` flag), no new entry-point scripts.
- **Bash 3.2 + POSIX sh** — all install logic remains POSIX-compatible. CI publishing scripts may use bash 4+ since they run in GitHub Actions (Ubuntu).
- **AP-009 (compound-chain-gt2)** — install scripts route compound logic through existing `scripts/util/run-probe.sh` per established convention. No new compound chains in installer paths.
- **CON-5 / SC-5 (never auto-applied)** — `orchestrator:update` requires explicit invocation; no background auto-update. Drift warning is a *warning*, not an auto-action. Operator always in control.
- **M025 reversibility-gate** — install→install→uninstall byte-equality round-trip must hold for every new mode. Symlink mode adds a manifest column (`mode: copy|symlink`); uninstall reads it and dispatches `rm` (symlink target stays) vs `rm -rf` (managed copy).
- **Principle I (Context Minimization)** — `update.sh` payload bounded; doesn't re-stage runtime if version unchanged (idempotent fast-path).
- **Principle II (Evidence Before Claims)** — P00 baseline is *required*, not optional. Real fresh-machine install evidence drives P01–P06 design decisions. Same standard as M032's pbj-central P00.
- **Principle XVI (Distribution Surface Integrity)** — M035 *is* the canonical Principle XVI test. Every distribution channel (npm/homebrew/curl-pipe-bash) goes through the integrity gates P05 specifies. Once shipped, every install path produces byte-identical runtime layouts (verified by hashing the staged runtime tree post-install across all three channels).
- **GitHub Actions secrets hygiene** — GPG keys, npm tokens, homebrew tap-write tokens stored as encrypted secrets. CI workflows scoped to release-tag pushes only; no secret access on PR builds.

## Cross-references

- **M025 installer coexistence**: `scripts/util/settings-merge.sh`, `.orchestrator/installed-files.txt`, `~/.claude/orchestrator-hooks/` — manifest + uninstall path that M035 P01's symlink mode extends.
- **M027 cost+quality observability**: `scripts/diagnostics/efficiency-footer.sh`, `metrics-rollup.sh` — `update_run` JSONL event surface.
- **M029 roadmap visibility & CLI UX**: `commands/where.md` (forthcoming), `scripts/diagnostics/predictive-surface.sh` — version-drift warning rendering surface.
- **M032 wiki distribution + init integration**: `--with-<feature>` flag pattern + `project_assets:` schema — design precedent for `--mode=symlink|copy`.
- **`references/installation.md` `## Upgrading`**: existing manual upgrade workflow doc — extended in M035 P01 with symlink-mode + drift-warning subsections.
- **CHANGELOG.md**: existing top-line version source — read by M035 P01 drift-detection logic.

## Source material

- 2026-04-28 operator session: roadmap-fit assessment surfaced the gap; full transcript captured in this session's flow
- `packaging/install/install-claude-code.sh:295-318` — current `cp -R` runtime-dir staging (the surface P01 modifies)
- `references/installation.md:231-245` — current manual upgrade documentation (the doc P01 extends)
- `scripts/util/settings-merge.sh` — M025 install/uninstall cascade (extended for symlink mode)
- `.orchestrator/installed-files.txt` — manifest schema (extended with `mode:` column)
- `CHANGELOG.md` — version source for drift detection
- Sibling proposals:
  - `M032-wiki-distribution-and-init-integration.md` — design precedent for distribution surfaces
  - `M033-onboarding-experience.md` — first-impression UX that pairs with M035's install path (warm onboarding once `npm install -g @spec-kit/orchestrator` lands the user)
  - `constitution-amendment-inclusion-criteria.md` — Principle XVI (Distribution Surface Integrity) framing for which M035 is the canonical compliance test
- External references (to consult during P00):
  - npm scoped-package conventions
  - Homebrew formula authoring guide + tap conventions
  - sigstore for keyless signing
  - GitHub Actions release automation patterns (`gh release create` + asset uploads)
