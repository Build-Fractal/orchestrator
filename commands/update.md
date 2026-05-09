---
description: "Use when refreshing an orchestrator-managed project's runtime from a locally-resolved source repo. Pre-M035 interim wrapper around install-claude-code.sh --force; M035 P02-P06 will add npm/homebrew/curl-pipe-bash sources."
---

# orchestrator:update

Reinstall the orchestrator runtime into the current project from a locally-resolved orchestrator source repo. This is the **pre-M035 interim** that mechanizes the M035 Finding D shell-function recipe (`( cd $HOME/Sites/orchestrator && git pull --ff-only ) && bash packaging/install/install-claude-code.sh --force`) as a discoverable first-class command, ahead of M035 P02–P06's package-manager publishing pipeline.

The skill is a **thin wrapper** around `scripts/lifecycle/run-update.sh`, which itself is a thin wrapper around `packaging/install/install-claude-code.sh --force`. No new install logic — discovery + visibility only.

## When to Use

Run from any orchestrator-managed project when the local source repo at `~/Sites/orchestrator` (or wherever `$ORCHESTRATOR_SOURCE_REPO` points) has moved forward and you want this project to pick up the changes. Typical triggers:

- A new milestone closed in the source repo and you want its commands / scripts / templates available here.
- A bug fix landed upstream that affects this project's runtime (e.g. the M036 `topic_tags` fix).
- You made local edits in the source repo and want to test them against this project without re-typing the install command.

The skill does NOT do `git pull` on the source repo. The operator controls when source state moves; this skill only re-stages whatever's currently in the source tree.

## What It Does

1. **Resolve source repo** in this order:
   - `--source-repo PATH` (explicit override)
   - `$ORCHESTRATOR_SOURCE_REPO` env var
   - `$HOME/Sites/orchestrator` (default)
2. **Validate**: source path exists and contains `packaging/install/install-claude-code.sh`; project dir contains `.orchestrator/`.
3. **Print pre-install summary**: source path, source HEAD short-sha + commit subject, dirty-state warning if applicable, bundle version, project dir.
4. **Run** `bash <source>/packaging/install/install-claude-code.sh --project-dir <project> --force` and pass through its output.
5. **Print** a one-line OK summary on success, or surface installer's non-zero exit.

## Invocation

```bash
# default — operates on $PWD, source at $HOME/Sites/orchestrator
bash scripts/lifecycle/run-update.sh

# explicit project + source
bash scripts/lifecycle/run-update.sh \
  --project-dir /Users/foo/Sites/lakeledger \
  --source-repo /Users/foo/Sites/orchestrator

# preview without writing
bash scripts/lifecycle/run-update.sh --dry-run
```

When invoked as `orchestrator:update` (the slash-command form), the skill executes `bash scripts/lifecycle/run-update.sh "$@"` from the project root and reports the result.

## Rollback

`orchestrator:update --rollback` reverts the orchestrator runtime to the prior installed version, restoring the manifest byte-for-byte (copy-mode installs only).

### Behavior

1. Reads `.orchestrator/.previous-version` for the prior version's metadata.
2. Reads the snapshotted manifest at `.orchestrator/.rollback/manifest-<prior-version>.txt`.
3. Replays each asset from the source-repo at the prior commit SHA (for `update_source: git`).
4. Updates `installed-files.txt` to the snapshotted version.
5. Emits one `update_run` JSONL event with `op: rollback`.

### Symlink-mode refusal

Symlink-mode installs (per `--mode=symlink`) cannot be rolled back via this skill: the runtime files ARE the source repo at HEAD, so "rollback" is a `git checkout <prior-sha>` operation in the orchestrator source repo, not a copy-revert in the consumer project. `--rollback` against a symlink-mode install exits non-zero with the exact advisory:

```
rollback not available for symlink-mode installs — symlink-mode consumers are always at HEAD; to revert, run `git checkout <prior-sha>` in the orchestrator source repo.
```

### Missing-marker behavior

`--rollback` against a project with no `.orchestrator/.previous-version` marker (i.e. no prior install on record) exits non-zero with `no prior version recorded — rollback unavailable`. This includes greenfield first installs.

### Unsupported source dispatches

`update_source: npm` and `update_source: homebrew` rollback dispatches are stubbed in M035 P05 with `SKIP: rollback not yet implemented for source=<value>` and exit non-zero. Full implementation lands when the corresponding distribution channels close (P03 / P04 / P06).

## Update sources

- **`update_source: git`** — dispatches `install-claude-code.sh --force` against a locally-resolved orchestrator source repo (default; the pre-M035 interim documented above).
- **`update_source: npm`** — dispatches `npm update -g @build-fractal/orchestrator` against the npm registry. The package and install path are documented in `references/installation.md § Installing via npm`. P06 wires the dispatch into `scripts/lifecycle/run-update.sh`; M035 P02 records the surface only.
- **`update_source: homebrew`** — dispatches `brew upgrade orchestrator` against the `build-fractal/orchestrator` tap. The tap and formula install path are documented in `references/installation.md § Installing via Homebrew`. P06 wires the dispatch into `scripts/lifecycle/run-update.sh`; M035 P03 records the surface only.

## Output

```
source repo:      /Users/brettkellgren/Sites/orchestrator
source HEAD:      67aedf3a M029/P03: stage closure follow-up artifacts + knowledge-graph drift sync
bundle version:   0.3.0-dev
project dir:      /Users/brettkellgren/Sites/pbj-central-mono-repo
---
running install...
SUMMARY: install_state=clean files_staged=N skills_registered=M ...
---
orchestrator:update OK -- runtime in /Users/brettkellgren/Sites/pbj-central-mono-repo refreshed from /Users/brettkellgren/Sites/orchestrator (67aedf3a)
```

When `--dry-run` is set, the install dispatch is replaced with `DRY RUN: would invoke: bash <installer> --project-dir <project> --force` and the script exits 0.

When the source repo has uncommitted changes, an extra `source state: dirty (uncommitted changes will be staged)` line appears between `source HEAD:` and `bundle version:`. This is a heads-up, not an error — staging an in-progress source tree is sometimes the operator's intent (testing local edits).

## Failure Modes

The driver exits non-zero with a clear message in three cases:

| Condition | Exit | Resolution |
|---|---|---|
| Source repo path doesn't exist | 1 | Set `$ORCHESTRATOR_SOURCE_REPO` or pass `--source-repo PATH` or symlink at `~/Sites/orchestrator` |
| Path exists but isn't a orchestrator tree | 1 | Point at a clone with `packaging/install/install-claude-code.sh` |
| Project dir has no `.orchestrator/` | 1 | Run `orchestrator:init` first to scaffold the project |
| Installer itself failed | passthrough | Read installer stderr; runtime may be in partial state — re-run after fixing |

Invalid argument (e.g. `--source-repo` with no value) exits 2.

## Read-Mostly Discipline

The driver itself is read-only — it stats files, reads git metadata, and resolves env vars. The actual mutation is delegated to the installer (which has its own M025 reversibility-gate semantics: install→install→uninstall byte-equality round-trip). The skill never touches the source repo (no `git pull`, no working-tree edits) and never modifies project state outside what the installer is already authorized to write.

## Cross-references

- **`scripts/lifecycle/run-update.sh`** — the driver this skill invokes.
- **`packaging/install/install-claude-code.sh`** — the underlying installer; `--force` is the standard upgrade semantics today (per `references/installation.md` `## Upgrading`).
- **`.orchestrator/proposals/M035-packaging-distribution.md`** — Finding D documents this skill as the pre-M035 interim; P06 evolves the driver to dispatch by `update_source: git|npm|homebrew` once package-manager publishing ships.
- **`references/installation.md`** — manual upgrade workflow this skill mechanizes.
- **`commands/init.md`** — sister command that scaffolds a project before `update` becomes applicable.
