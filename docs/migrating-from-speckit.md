# Migrating from spec-kit

**spec-kit becomes a migration *source*, not a runtime dependency — your specs and your git history survive the move.** After migration the orchestrator runs standalone on Claude Code, reads its state from `.orchestrator/`, and never invokes a `speckit.*` binary again.

## TL;DR

1. Install the orchestrator into your project (see [getting-started](getting-started.md)), then run **[`/orchestrator-start`](../commands/start.md)** — it auto-detects the spec-kit shape and routes you into the *migrating* onboarding flow.
2. Your `specs/NNN-*/` feature directories stay exactly where they are, byte-for-byte.
3. The migration is a one-time, idempotent import; re-running it is safe.

Mental-model boundary: **spec-kit** = the source you migrate *from* (not a dependency you keep running). **Plain Claude Code** = fine on its own for single-context work; reach for the orchestrator when you want autonomous multi-phase execution with audit trails. **conversus** = an optional sister tool for adversarial review; the orchestrator works without it.

---

## Is this you?

Run [`/orchestrator-start`](../commands/start.md) and **the tool detects all of this automatically** — you do not have to verify the table below by hand. It is here so you can recognize your own project. The load-bearing router is `scripts/lifecycle/start.sh` (its `detect_branch` cascade, specified in [`references/branch-detection.md`](../references/branch-detection.md)); it reports the branch it picked, and you confirm before anything moves.

Only the **trigger** signals below route you into the *migrating* branch. The other rows are informational — they help you recognize a spec-kit project and tell you what gets carried over, but they do not by themselves flip the branch.

| Detection signal | Routes *migrating* branch? | What it means |
|---|---|---|
| `.specify/` directory at repo root | **Yes** — load-bearing | A spec-kit project — the trigger for the *migrating* branch |
| `.gsd/` directory at repo root | **Yes** — load-bearing | A GSD v1 project — also routes *migrating* |
| `.gsd2/` directory at repo root | **Yes** — load-bearing | A GSD v2 project — also routes *migrating* |
| `.specify/specs/` present | Refines source only | Tags the detected source as `spec-kit` (vs gsd-v1 / gsd-v2) |
| `.specify/memory/constitution.md` | No — informational | Your project constitution lives here; imported during migration |
| `specs/NNN-*/` with `spec.md` / `plan.md` / `tasks.md` | No — informational | Spec-kit feature directories — these survive the move |
| `extension.yml` registering `speckit.orchestrator.*` | No — informational | A legacy orchestrator-extension install |
| `speckit` binary on PATH | No — informational | spec-kit installed system-wide |

Any one of the three **load-bearing** directories (`.specify/`, `.gsd/`, `.gsd2/`) flips the branch to *migrating* — `.specify/` is the spec-kit case. If **none** of the three is present, your project is already standalone-shaped and routes to a greenfield or existing-codebase flow instead (see [getting-started](getting-started.md)).

(A separate probe, `scripts/state/detect-speckit.sh`, reports a `speckit_installed` flag from a slightly different signal set — the `.specify/` dir, `.specify/memory/constitution.md`, or the `speckit` binary on PATH — but it is informational only and does **not** choose the onboarding branch.)

---

## What changes vs. what stays

The key thing to understand: `.specify/` and `specs/` are **separate, layered** trees. `.specify/` holds spec-kit's *machinery* (constitution, templates); `specs/` holds *your authored work*. Migration relocates the machinery's state and leaves your work in place.

| Path / artifact | Before | After | Survives? |
|---|---|---|---|
| `specs/NNN-*/spec.md`, `plan.md`, `tasks.md` | spec-kit feature dirs | unchanged, same paths | Yes — untouched |
| `.specify/memory/constitution.md` | spec-kit constitution | imported into `.orchestrator/memory/` | Yes — content carried over |
| `.specify/orchestrator/` (legacy extension state) | old orchestrator state | imported into `.orchestrator/` | Yes — relocated |
| `.specify/templates/` | spec-kit author-time templates | left in place (optional) | Yes — kept for authoring |
| Git history | your commits | unchanged | Yes — no rewrite |
| `extension.yml` (`speckit.orchestrator.*`) | command registration | no longer required at runtime | Not needed |

What actually changes is the **path roots**. Any external tooling or docs you wrote that hard-code `.specify/orchestrator/` must be repointed to `.orchestrator/`.

---

## How to migrate

These steps are **sequential** — run them in order, top to bottom.

1. **Install the orchestrator into your project.** Clone `git@github.com:Build-Fractal/orchestrator.git` and run the Claude Code installer against your project. Full prerequisites and flags live in [getting-started](getting-started.md):
   ```bash
   bash packaging/install/install-claude-code.sh --project-dir /path/to/your-project
   ```

2. **Run the migrating front door.** From your runtime, invoke [`/orchestrator-start`](../commands/start.md). It detects the spec-kit shape, confirms the *migrating* branch with you, and drives the rest. (`/orchestrator-start` is the warm conversational entry point that auto-routes among four onboarding flows: greenfield-empty, greenfield-with-materials, existing-codebase, and migrating.)

3. **Or call the migration command directly.** If you prefer to run the import yourself, use the [`/orchestrator-migrate`](../commands/migrate.md) skill — its job is to read a source project (GSD2, GSD v1, or spec-kit), transform knowledge / decisions / requirements / milestone history into orchestrator format, and rebuild the knowledge index. The underlying CLI:
   ```bash
   bash scripts/migrate/migrate.sh --path /path/to/your-project --source speckit
   ```
   By default the CLI uses `--abort` (it will not overwrite existing orchestrator state). Use `--merge` to add only new entries, or `--force` to overwrite.

4. **Review the migration report.** The CLI writes `MIGRATION-REPORT.md` with statistics and warnings. Read it before continuing.

5. **Confirm state, then start working.** Run [`/orchestrator-status`](../commands/status.md) (a read-only one-screen progress report) to verify the imported milestone, then begin orchestrator work from where you left off.

Re-running is safe: migration is idempotent, so a second pass against already-migrated state reports rather than duplicating.

**Is "hard migration" a risk?** No — it is a deliberate simplification, and a *strength* for a single-project move. There are no dual code paths to keep in sync: state lands in one canonical place (`.orchestrator/`), so there is no ambiguity about which tree is authoritative. The `--abort` default plus git (no history rewrite) are your safety net.

---

## After migrating

```
<repo-root>/
  .orchestrator/                 # canonical orchestrator state — single source of truth
    memory/
      constitution.md            # imported from .specify/memory/constitution.md
    milestones/M<NNN>/...         # roadmaps, phase plans, task summaries, event logs
    KNOWLEDGE.md                  # consolidated knowledge index (warm tier)
    DECISIONS.md                  # append-only decisions register
    MIGRATION-REPORT.md           # what the import did — read this first
  specs/                         # YOUR authored specs — unchanged by migration
    NNN-feature-slug/
      spec.md / plan.md / tasks.md
  .specify/                      # OPTIONAL — keep only if you still want spec-kit templates
    templates/                   # author-time only; the engine no longer reads state here
```

The two top-level trees are layered, not redundant: `.orchestrator/` is now the only place the engine reads execution state from; `.specify/` survives purely as an author-time template source if you choose to keep it.

---

## Authoring specs going forward

You have two ways to keep producing `spec.md` / `plan.md` / `tasks.md`, and the trade-off is straightforward:

| Option | How it works | Trade-off |
|---|---|---|
| Keep `/speckit.*` authoring shortcuts | The orchestrator ships a format adapter at `scripts/dispatch/adapters/format/speckit.sh` that reads/writes spec-kit's exact layout; dispatch invokes it automatically when it sees spec-kit-shaped artifacts | Keeps your muscle memory, but you still rely on spec-kit's authoring skills being installed |
| Use native orchestrator skills | [`/orchestrator-specify`](../commands/specify.md) and the rest of the chain produce the same `specs/` artifacts the engine consumes | No spec-kit install required; one toolchain to learn and maintain |

Both produce artifacts the engine picks up the same way. The native path is the lower-dependency choice; the spec-kit path is the lower-friction choice if your team already lives in `/speckit.*` commands.

---

## Can I delete spec-kit?

**Yes — after migration the orchestrator has zero runtime dependency on spec-kit.** Concretely:

| Item | Safe to remove? | Why |
|---|---|---|
| `speckit` binary (e.g. `uv tool uninstall spec-kit`) | Yes | Never invoked at runtime; the format adapter is pure bash inside the orchestrator |
| `extension.yml` (`speckit.orchestrator.*` registration) | Yes | Not required for standalone operation |
| `.specify/orchestrator/` (legacy state) | Yes, after you confirm the import | Its contents now live under `.orchestrator/` |
| `.specify/memory/constitution.md` | Optional | Already imported into `.orchestrator/memory/`; keep only if you want the original copy |
| `.specify/templates/` | Keep **if** you still author via `/speckit.*` | The format adapter understands this layout; only the templates source needs it |

Rule of thumb: keep `.specify/templates/` only if you chose the spec-kit authoring path above. Everything else is removable once `MIGRATION-REPORT.md` confirms a clean import.

---

## Troubleshooting

**"Migration reports no spec-kit project detected."**
Check that `.specify/` exists at your repo root, or that `.specify/memory/constitution.md` is present, or that the `speckit` binary is on PATH. If none apply, your project is already standalone-shaped — run the orchestrator onboarding flow for an existing codebase via [`/orchestrator-start`](../commands/start.md) instead.

**"Migration aborted because state already exists."**
That is the `--abort` default protecting you. If you intend to add only new entries, re-run with `--merge`; to overwrite existing orchestrator state, re-run with `--force`:
```bash
bash scripts/migrate/migrate.sh --path /path/to/your-project --source speckit --merge
```

**"After migration, old paths still appear in my docs."**
The migration moves *state*, not your documentation. Search your own `docs/` and `README.md` for hard-coded `.specify/orchestrator/` and repoint to `.orchestrator/`.

**"My runtime doesn't see the orchestrator skills."**
Re-run the installer (or [`/orchestrator-init`](../commands/init.md)) — it regenerates the runtime-specific instruction file (`CLAUDE.md` / `AGENTS.md` / `.cursor/rules/`) and re-registers skills:
```bash
bash packaging/install/install-claude-code.sh --project-dir /path/to/your-project --force
```

---

## Next step

- **Run your first task →** [getting-started](getting-started.md) — first-run walkthrough; post-migration it works exactly as it does for new projects.
- **See how migrated specs enter the graph →** [knowledge-management](knowledge-management.md) — how `specs/` and decisions become queryable knowledge.
