# Migrating from spec-kit

This guide is for users who have an existing spec-kit project and want to adopt the orchestrator. It covers what changes, what is preserved, and how to run a one-time migration.

> **Framing:** spec-kit is a **migration source**, not a runtime dependency. After migration, the orchestrator runs standalone. You do not need spec-kit installed to keep authoring spec-kit-shaped specs — a format adapter handles that natively. See "Spec-kit is not a runtime dependency" below.

---

## 1. What the orchestrator is and why you might want it

The orchestrator is a standalone, multi-runtime execution engine for Spec-Driven Development. It adds to the spec-kit author loop:

- **Autonomous multi-phase execution** — roadmap → phases → tasks, dispatched in fresh contexts with verification.
- **Adaptive intensity** (Quick / Standard / Full) — the engine right-sizes ceremony to task scope.
- **Backend-agnostic dispatch** — runs under Claude Code, Codex CLI, or Cursor via runtime adapters.
- **Durable state on disk** — every decision, event, and artifact lives under `.orchestrator/`, making crash recovery and resume deterministic.
- **Knowledge compounding** — task/phase/milestone summaries feed a consolidated KNOWLEDGE.md so future runs are cheaper.

If your spec-kit project has grown past single-task SDD and you want hands-off phase execution with audit trails, the orchestrator is the natural next step.

---

## 2. Detecting spec-kit shape in an existing project

The orchestrator auto-detects spec-kit projects. Telltale signs:

- A `.specify/` directory at repo root.
- `.specify/memory/constitution.md` — the project constitution.
- `.specify/orchestrator/` — if you previously used an earlier orchestrator extension build, state lives here.
- `specs/NNN-*/` feature directories containing `spec.md`, `plan.md`, `tasks.md`.
- `extension.yml` registering `speckit.orchestrator.*` commands (legacy extension install).

Run `scripts/state/detect-speckit.sh` (or invoke the `orchestrator:migrate` skill) — it reports which shape is present and whether migration is warranted.

---

## 3. Running the migration

Two equivalent entry points:

- **Skill:** invoke `orchestrator:migrate` from your runtime (Claude Code / Codex / Cursor). See `commands/migrate.md` for the authored command definition.
- **Script:** run `scripts/migrate/migrate-state.sh` directly. This is what the skill calls under the hood.

The migration is a **hard migration** (single user, single project — no dual code paths). It:

1. Snapshots the current `.specify/orchestrator/` tree (if present) for rollback.
2. Moves orchestrator state to `.orchestrator/` at repo root.
3. Moves `.specify/memory/constitution.md` to `.orchestrator/memory/constitution.md`.
4. Leaves `specs/` and `.specify/templates/` untouched — these remain the spec-kit authoring surface.
5. Writes a migration receipt to `.orchestrator/MIGRATION.md` recording source paths, timestamps, and file counts.

Re-run is idempotent: if `.orchestrator/` already looks correct, the script reports PASS and exits without touching disk.

---

## 4. What is preserved post-migration

- **All feature specs** in `specs/NNN-*/` — unchanged, same filenames, same layout.
- **Your constitution** — relocated to `.orchestrator/memory/constitution.md`, content byte-identical.
- **Orchestrator history** — roadmaps, phase plans, task summaries, event logs, KNOWLEDGE.md, DECISIONS.md all carry over verbatim.
- **Git history** — the migration is a single commit (or left uncommitted for your review). No rewriting.
- **Custom hooks and recipes** — if you authored any under the old tree, they are relocated and repaths adjusted.

What changes: the **paths**. Any external tooling or documentation you wrote that hard-codes `.specify/orchestrator/` must be updated to `.orchestrator/`.

---

## 5. Post-migration project layout

```
<repo-root>/
  .orchestrator/                 # orchestrator state (was .specify/orchestrator/)
    memory/
      constitution.md            # was .specify/memory/constitution.md
    milestones/
      M<NNN>/
        phases/P<NN>/tasks/...
    KNOWLEDGE.md
    DECISIONS.md
    events.log
  specs/                         # spec-kit authoring surface (unchanged)
    NNN-feature-slug/
      spec.md
      plan.md
      tasks.md
  .specify/                      # optional — only if you still use spec-kit templates
    templates/
  commands/                      # orchestrator skill definitions
  scripts/                       # runtime helpers
```

The `.specify/` tree is now optional. If you keep it, it is purely an author-time template source — the orchestrator no longer reads state from it.

---

## 6. Continuing to author spec-kit-shaped specs

The orchestrator ships a **format adapter** at `scripts/dispatch/adapters/format/speckit.sh`. This adapter:

- Reads and writes `spec.md` / `plan.md` / `tasks.md` in spec-kit's exact layout.
- Honors spec-kit's frontmatter conventions and section ordering.
- Is invoked automatically when dispatch detects spec-kit-shaped artifacts.

You can keep using `/speckit.specify`-style authoring prompts in your runtime — the skills `speckit.specify`, `speckit.plan`, `speckit.tasks`, etc. remain available as authoring shortcuts. They produce artifacts in `specs/` that the orchestrator's engine then picks up.

There is also a built-in alternative: the orchestrator's native `orchestrator-*` skills produce the same artifacts without needing spec-kit commands installed.

---

## 7. Spec-kit is not a runtime dependency

After migration, **you do not need spec-kit installed** for the orchestrator to operate. Specifically:

- No `extension.yml` registration is required.
- No `speckit.*` binary is invoked at runtime.
- The spec-kit format adapter is a pure-bash implementation shipped inside `scripts/dispatch/adapters/format/`.
- Removing `uv tool install spec-kit` (or your equivalent) has no effect on autonomous runs.

Spec-kit appears in this project only as (a) the historical migration source, and (b) an author-time convention the format adapter understands. If you want to keep `/speckit.specify` shortcuts around for muscle memory, that is fine — but the orchestrator does not depend on them.

---

## 8. Troubleshooting

**"Migration reports no spec-kit project detected."**
Check that `.specify/` exists at your repo root and contains either `orchestrator/` or `memory/constitution.md`. If neither is present, your project is already standalone-shaped; run `orchestrator-init` instead.

**"After migration, old paths still appear in my docs."**
The migration moves state, not documentation. Search your own `docs/` and `README.md` for hard-coded `.specify/orchestrator/` and update to `.orchestrator/`. The repo's own doc sweep is tracked by `scripts/verify/m015-p02-no-stale-state-refs.sh`.

**"I want to roll back."**
The migration writes a snapshot to `.orchestrator/.migration-snapshot/` before moving anything. Restore from there, delete `.orchestrator/`, and re-run. If you committed the migration, revert the commit.

**"My runtime doesn't see the orchestrator skills."**
Run `orchestrator-init` — this regenerates the runtime-specific instruction file (`CLAUDE.md` / `AGENTS.md` / `.cursor/rules/`) and re-registers skills. This is safe post-migration.

**"Constitution path still resolves to the old location."**
The 5-rule state root resolver (`scripts/state/resolve-root.sh`) prefers `.orchestrator/` but falls back to `.specify/orchestrator/` as a bridge. If resolution picks the wrong one, set `ORCHESTRATOR_ROOT=.orchestrator` in your environment or in `.orchestrator/config.yml`.

---

## Further reading

- `references/installation.md` — standalone install for new projects.
- `references/architecture.md` — engine, dispatch, and state subsystems.
- `docs/getting-started.md` — first-run walkthrough (post-migration this works the same as for new projects).
- `commands/migrate.md` — migration skill definition.
