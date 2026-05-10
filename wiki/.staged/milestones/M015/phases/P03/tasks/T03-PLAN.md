---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M015"
name: "Sweep wider reference/user-guide docs + write migration guide"
depends_on: [T02]
---

## Prerequisites

- T02 is complete. The five primary docs (README.md, CLAUDE.md, references/architecture.md, references/installation.md, docs/getting-started.md) are reframed for standalone. CHANGELOG.md has the M015 entry. Three of six P03 verify scripts PASS.
- T01 is complete. All six P03 verify scripts exist. The historical CHANGELOG snapshot exists.
- P02 is complete. State at `.orchestrator/`, constitution at `.orchestrator/memory/constitution.md`.

## Description

Two independent deliverables in one task:

1. **Wider doc sweep**: rewrite runtime-path references and stale spec-kit-as-SDD-entry-point language in the 11 non-primary P03-reserved docs. These files are in the `ALLOW_P03_DOCS` regex of `scripts/verify/m015-p02-no-stale-state-refs.sh`:
   - `references/engine.md` (4 legacy refs)
   - `references/events.md` (2 legacy refs)
   - `references/errors.md` (3 legacy refs)
   - `references/recipes.md` (6 legacy refs)
   - `references/file-formats.md` (22 legacy refs — large sweep)
   - `references/state-machine.md` (2 legacy refs)
   - `references/tier-definitions.md` (6 legacy refs — includes "standard spec-kit commands" in Tier A block that must be rephrased)
   - `references/constitution-walkthrough.md` (9 legacy refs — includes `.specify/memory/constitution.md` references)
   - `references/verification-ladder.md` (1 legacy ref — "standard spec-kit verification")
   - `docs/knowledge-management.md` (9 legacy refs)
   - `docs/recipe-authoring.md` (12 legacy refs)
   - `docs/hook-development.md` (1 legacy ref)
   - `scripts/AGENTS.md` (3 legacy refs)

   The sweep is mostly mechanical: `.specify/orchestrator/` → `.orchestrator/`, `.specify/memory/constitution.md` → `.orchestrator/memory/constitution.md`. Where prose frames spec-kit as the SDD entry point (tier-definitions.md Tier A block, verification-ladder.md, constitution-walkthrough.md SDD-workflow mention), rephrase to reflect standalone reality. These files are technical references — their structural content (engine pipeline, event names, error kinds, recipe syntax, file formats, state machine rules, tier classifications, verification ladder, constitution principles) is unchanged and must not be rewritten.

2. **Write `docs/migrating-from-speckit.md`**: a NEW user-facing guide (FR-012) for developers with existing spec-kit projects adopting the orchestrator. It describes (a) what the orchestrator is and why a spec-kit user might want it, (b) how to detect spec-kit shape in an existing project, (c) how to run the migration (`orchestrator:migrate` / `scripts/migrate/migrate-state.sh`), (d) what is preserved post-migration, (e) what the post-migration project layout looks like, (f) how to continue using spec-kit-shaped specs under the orchestrator via `scripts/dispatch/adapters/format/speckit.sh`, (g) explicit clarification that spec-kit is a migration source, not a runtime dependency. Minimum 40 lines, minimum 8 major sections.

## Steps

1. Run the wider-docs sweep verifier once to capture the baseline failure output:

   ```
   bash scripts/verify/m015-p03-wider-docs-sweep.sh
   ```

   Record the count of legacy references per file. Use this as your checklist.

2. **Sweep `references/engine.md`** (currently 4 legacy refs at lines 30, 86, 137, 176):
   - Replace every literal `.specify/orchestrator/` with `.orchestrator/`.
   - No structural rewrites. The 7-stage pipeline stays, the directory-resolution text stays, the checkpoint-file-location text stays — only the path strings update.

3. **Sweep `references/events.md`** (currently 2 legacy refs at lines 432, 561):
   - Replace `.specify/orchestrator/` with `.orchestrator/` in the two `EVENT:` example lines.

4. **Sweep `references/errors.md`** (currently 3 legacy refs at lines 55, 59, 93):
   - Replace `.specify/orchestrator/` with `.orchestrator/` in the three example scenarios.

5. **Sweep `references/recipes.md`** (currently 6 legacy refs at lines 308, 309, 310, 340, 410, 411):
   - Replace `.specify/orchestrator/` with `.orchestrator/` in the recipe-file-location list and the dispatch-command example.

6. **Sweep `references/file-formats.md`** (22 legacy refs — the largest single-file sweep):
   - Replace every literal `.specify/orchestrator/` with `.orchestrator/` throughout the file. The structural content (YAML frontmatter schemas, file format descriptions, location callouts) is unchanged.
   - Verify count goes from 22 → 0 by running `grep -c '\.specify/orchestrator' references/file-formats.md` before and after.

7. **Sweep `references/state-machine.md`** (2 legacy refs at lines 8, 255):
   - Line 8: "All state … under `.specify/orchestrator/milestones/{M###}/`" → "All state … under `.orchestrator/milestones/{M###}/`".
   - Line 255: "Tier A does **not use the orchestrator state machine**. It routes directly to standard spec-kit commands with zero overhead. No orchestrator state files are created." → Rephrase: "Tier A does **not use the orchestrator state machine**. It routes directly to the host runtime's native single-context workflow with zero overhead. No orchestrator state files are created." (Remove "standard spec-kit commands" — replace with a runtime-neutral description.)

8. **Sweep `references/tier-definitions.md`** (6 legacy refs at lines 8, 20, 22, 27, 30, 38):
   - Line 8: "based on the number of complete spec-kit process flows (specify → clarify → plan → tasks → implement) the work requires" — keep the reference to the SDD workflow but generalize: "based on the number of complete spec-driven-development process flows (specify → clarify → plan → tasks → implement) the work requires". The process model is spec-kit-derived but not spec-kit-owned.
   - Line 20: "Standard spec-kit commands (`speckit.specify`, `speckit.clarify`, `speckit.plan`, `speckit.tasks`, `speckit.implement`)" — rephrase as "Standard SDD commands via the host runtime (typically `orchestrator:specify`/`orchestrator:plan`/etc. or the runtime's native equivalents)". If the orchestrator does NOT provide `orchestrator:specify`/`orchestrator:plan`/`orchestrator:tasks`/`orchestrator:clarify`/`orchestrator:implement` commands (inspect `commands/` to confirm), then describe Tier A as "routes to the host runtime's native SDD workflow" without listing specific command names.
   - Line 22: "Direct routing to spec-kit with no orchestrator overhead" → "Direct routing to the host runtime's native workflow with no orchestrator overhead".
   - Line 27: `.specify/orchestrator/` → `.orchestrator/`.
   - Line 30: "standard spec-kit verification applies" → "standard host-runtime verification applies".
   - Line 38: "None — direct spec-kit commands only. The orchestrator's `evaluate` command classifies as Tier A and then steps aside entirely." → "None — direct host-runtime commands only. The orchestrator's `evaluate` command classifies as Tier A and then steps aside entirely."

9. **Sweep `references/constitution-walkthrough.md`** (9 legacy refs):
   - Line 11: "The speckit-orchestrator constitution (`.specify/memory/constitution.md`)" → "The speckit-orchestrator constitution (`.orchestrator/memory/constitution.md`)".
   - Line 123: "The SDD workflow itself enforces this: `/speckit.specify` (brainstorm/spec), `/speckit.plan` (design), `/speckit.implement` (execute), then verification (review)." — rephrase to remove spec-kit slash commands as THIS project's workflow. Since this is a constitution-walkthrough reference (describing the project's own governance), and this project no longer uses spec-kit for its own dev, rewrite as: "The SDD workflow itself enforces this: `orchestrator:evaluate`→`orchestrator:discuss`→`orchestrator:roadmap`→`orchestrator:plan-phase`→`orchestrator:auto`/`orchestrator:dispatch`→`orchestrator:verify`. No task is implemented without a prior `T##-PLAN.md`."
   - Line 132: "Skipping the `/speckit.plan` step because the spec 'already describes the implementation.'" → "Skipping the `orchestrator:plan-phase` step because the spec 'already describes the implementation.'"
   - Line 151, 228, 259, 380, 402: replace `.specify/orchestrator/` with `.orchestrator/`.
   - Line 450: `[Constitution source](../.specify/memory/constitution.md)` → `[Constitution source](../.orchestrator/memory/constitution.md)`.

10. **Sweep `references/verification-ladder.md`** (1 legacy ref at line 177):
    - Line 177: "Tier A does not use the orchestrator verification ladder — standard spec-kit verification applies." → "Tier A does not use the orchestrator verification ladder — standard host-runtime verification applies."
    - Note: this line matches the tier-definitions.md line 30 change for consistency.

11. **Sweep `docs/knowledge-management.md`** (9 legacy refs):
    - Replace every literal `.specify/orchestrator/` with `.orchestrator/`.
    - Replace every `.specify/memory/constitution.md` with `.orchestrator/memory/constitution.md` (if any).
    - Inspect for any "spec-kit extension" framing; if present, rephrase to standalone per T02's rules (but don't expect any — this file is about knowledge lifecycle, not install/framing).

12. **Sweep `docs/recipe-authoring.md`** (12 legacy refs):
    - Replace every literal `.specify/orchestrator/` with `.orchestrator/`.
    - Inspect for any spec-kit-framing prose; rephrase if found.

13. **Sweep `docs/hook-development.md`** (1 legacy ref):
    - Replace the single `.specify/orchestrator/` occurrence with `.orchestrator/`.
    - Note: this file is about hook development. Verify it does not frame hooks as "spec-kit lifecycle hooks". If it does, rephrase to "orchestrator lifecycle hooks" or the appropriate standalone terminology (see `references/hooks.md` for authoritative hook framing).

14. **Sweep `scripts/AGENTS.md`** (3 legacy refs):
    - Replace every literal `.specify/orchestrator/` or `.specify/memory/constitution` occurrence with the `.orchestrator/` equivalent.

15. **Write `docs/migrating-from-speckit.md`**. Create a new file with this structure and approximate content:

    ```markdown
    # Migrating from spec-kit to the Orchestrator

    > Guide for developers with existing spec-kit projects who want to adopt the orchestrator.
    > Audience: spec-kit users evaluating or onboarding the orchestrator.

    ## What the Orchestrator Is

    The orchestrator is a standalone autonomous multi-phase orchestration layer for spec-driven development. It is not an extension or plugin to spec-kit. It is a self-contained tool that runs on Claude Code, Codex CLI, or Cursor and manages the full lifecycle of large features that span multiple context windows.

    Historically the orchestrator was distributed as a spec-kit extension. As of v0.9.0 (M015), it is standalone. The extension host has been removed. Spec-kit is not a runtime dependency.

    ## Why Migrate

    If you are using spec-kit today for single-context features (specify → clarify → plan → tasks → implement), you can continue to do so — the orchestrator routes Tier A work to your host runtime's native workflow with zero overhead. You adopt the orchestrator when:

    - A feature is too large for a single context window (Tier B or Tier C).
    - You want autonomous dispatch across phases (`orchestrator:auto`).
    - You want mechanical verification gates (`orchestrator:verify`).
    - You want knowledge compounding across milestones.

    ## What the Migration Preserves

    The orchestrator ships spec-kit migration adapters that read spec-kit's native file layout as a migration source. Specifically:

    - `scripts/migrate/adapters/speckit.sh` — reads spec-kit-shaped `specs/{NNN}-{name}/` directories.
    - `scripts/state/detect-speckit.sh` — detects spec-kit shape in an existing project.
    - `scripts/dispatch/adapters/format/speckit.sh` — reads spec-kit-format spec documents at dispatch time (one-directional — the orchestrator writes in its native format, reads spec-kit or native).
    - `commands/migrate.md` — the `orchestrator:migrate` command that runs the migration end-to-end.

    These adapters are permanent. They are preserved from the standalone cutover and will continue to be maintained so spec-kit users can adopt the orchestrator at any time.

    ## Prerequisites

    - Your project has a spec-kit layout: `specs/{NNN}-{name}/spec.md`, optionally `plan.md`, `tasks.md`, and `.specify/memory/constitution.md`.
    - You are on Claude Code, Codex CLI, or Cursor.
    - You have cloned or installed the orchestrator (see `references/installation.md`).

    ## Running the Migration

    From your project root:

    ```
    bash scripts/migrate/migrate-state.sh --source .specify/orchestrator --target .orchestrator
    ```

    Or use the orchestrator command:

    ```
    orchestrator:migrate
    ```

    The migration is atomic — it uses `mv` semantics under the hood. If the source is untouched spec-kit state (no prior orchestrator artifacts), the migration produces a bare `.orchestrator/` skeleton with the constitution moved, knowledge / decisions initialized, and no milestones scaffolded.

    ## Post-Migration Layout

    After migration, your project tree has:

    ```
    your-project/
    ├── .orchestrator/              # Orchestrator state (was .specify/orchestrator/)
    │   ├── memory/
    │   │   └── constitution.md     # Governance doc (was .specify/memory/constitution.md)
    │   ├── DECISIONS.md
    │   ├── KNOWLEDGE.md
    │   ├── execution-log.jsonl
    │   └── milestones/
    ├── specs/                      # Your feature specs (spec-kit-shaped OK)
    │   └── 001-your-feature/
    │       └── spec.md
    ├── commands/                   # Orchestrator commands (installed by install script)
    ├── scripts/                    # Orchestrator scripts
    └── orchestrator-config.yml     # Optional project-level config
    ```

    Your existing `specs/` tree is not touched. The orchestrator reads spec-kit-shaped specs directly via the format adapter. No spec rewrite is needed.

    ## Continuing to Use Spec-Kit-Shaped Specs

    The orchestrator does not require you to rewrite your spec documents. The format adapter at `scripts/dispatch/adapters/format/speckit.sh` reads spec-kit-native `spec.md`, `plan.md`, and `tasks.md` files at dispatch time and assembles them into the orchestrator's dispatch payload. You can mix spec-kit-shaped specs and orchestrator-native specs in the same project.

    ## Spec-Kit as a Migration Source, Not a Runtime Dependency

    The orchestrator does not require spec-kit to be installed to run. You can uninstall spec-kit entirely after migration if you wish. The migration adapters do not call spec-kit binaries or scripts — they only read spec-kit-shaped files on disk.

    If you keep spec-kit installed alongside the orchestrator, the two tools operate independently. The orchestrator will not invoke spec-kit commands and spec-kit will not invoke orchestrator commands.

    ## Next Steps After Migration

    1. Run `orchestrator:init` to generate the project configuration and install the orchestrator skills into your runtime.
    2. Run `orchestrator:evaluate` to classify your existing spec's scope (Tier A / B / C).
    3. Follow the prompts: `orchestrator:discuss` (Tier C), `orchestrator:roadmap`, `orchestrator:plan-phase`, `orchestrator:auto`.

    See `docs/getting-started.md` for the full quickstart.

    ## Troubleshooting

    - **`orchestrator:migrate` reports "source already migrated"**: the `.orchestrator/` directory already exists. Inspect it; if it is the intended target, no further action. If it is stale, back up and re-run with `--force`.
    - **Constitution reference broken post-migration**: check `.orchestrator/memory/constitution.md` exists. Update any project-specific tooling that referenced `.specify/memory/constitution.md` to the new path.
    - **Dispatch cannot find spec**: the format adapter expects specs at `specs/{NNN}-{name}/spec.md`. Verify your spec file is at that exact path.
    ```

    Adjust content to match reality found in the codebase — inspect `commands/migrate.md` and `scripts/migrate/migrate-state.sh` for actual flag names and semantics before writing the usage block.

16. Run the wider-docs sweep verifier:

    ```
    bash scripts/verify/m015-p03-wider-docs-sweep.sh
    ```

    Must exit 0 with `PASS:`. If it FAILs, its output names the exact file and count of remaining legacy references. Fix and re-run.

17. Run the migration-doc verifier:

    ```
    bash scripts/verify/m015-p03-migration-doc.sh
    ```

    Must exit 0 with `PASS:`. If it FAILs, check (a) file exists at `docs/migrating-from-speckit.md`, (b) mentions "migration", (c) references `commands/migrate.md` or `scripts/migrate/migrate-state.sh` or `orchestrator:migrate`, (d) does not frame spec-kit as a runtime dependency, (e) is at least 40 lines.

18. Re-run the two T02 verifiers to confirm no regression:

    ```
    bash scripts/verify/m015-p03-standalone-framing.sh
    bash scripts/verify/m015-p03-no-legacy-install.sh
    bash scripts/verify/m015-p03-changelog-has-m015.sh
    ```

    All three must still PASS.

## Must-Haves

This task addresses:

- Truth 4 (migration-doc): `docs/migrating-from-speckit.md` exists and frames spec-kit as a migration source.
- Truth 5 (wider-docs-sweep): 11 wider P03-reserved docs no longer have literal `.specify/orchestrator/` or `.specify/memory/constitution` references.

## Verification

```
bash scripts/verify/m015-p03-wider-docs-sweep.sh
bash scripts/verify/m015-p03-migration-doc.sh
bash scripts/verify/m015-p03-standalone-framing.sh
bash scripts/verify/m015-p03-no-legacy-install.sh
bash scripts/verify/m015-p03-changelog-has-m015.sh
```

All five must PASS. Only `m015-p03-allow-list-tightened.sh` remains FAILing — T04 addresses it.

## Inputs

- The 13 target files listed in the Description. Grep each to confirm the exact legacy-ref count matches this plan's expectations before editing.
- `scripts/migrate/migrate-state.sh` — read to confirm the actual CLI surface (flags, arguments) referenced in the migration guide.
- `commands/migrate.md` — read to confirm what the command's self-description is and how users invoke it.
- `scripts/state/detect-speckit.sh` — read if the migration guide needs to describe detection semantics.
- `scripts/dispatch/adapters/format/speckit.sh` — read if the migration guide needs to describe format-adapter semantics.
- `references/hooks.md` — reference for the standalone hooks framing (if hook-development.md needs framing-level edits beyond path sweep).

## Constraints

- Do NOT edit files outside the 13-file sweep list and the new `docs/migrating-from-speckit.md`. If you find a legacy reference in a file NOT in the sweep list, flag it in the task summary — do not edit it in T03.
- Do NOT modify files under `.orchestrator/` (historical artifacts).
- Do NOT modify `scripts/verify/m015-p02-no-stale-state-refs.sh` (allow-list belongs to T04).
- Do NOT remove or modify any migration adapter under `scripts/migrate/`, `scripts/state/detect-speckit.sh`, `scripts/dispatch/adapters/format/speckit.sh`, or `commands/migrate.md`.
- The migration guide must NOT frame spec-kit as a runtime dependency. Specifically, avoid the phrases "requires spec-kit", "depends on spec-kit at runtime", and "spec-kit >= 0.1.0" as a requirement. Use "is a migration source" or "is read via a format adapter" when describing the spec-kit relationship.
- Path literalism (MEM023): paths in the task summary are parsed literally; do not wrap in backticks.

## Expected Output

After T03 completes:

1. 13 wider docs have zero literal `.specify/orchestrator/` or `.specify/memory/constitution` references.
2. `docs/migrating-from-speckit.md` exists, >= 40 lines, frames spec-kit as a migration source.
3. Five of six P03 verify scripts PASS:
   - `m015-p03-standalone-framing.sh` → PASS
   - `m015-p03-no-legacy-install.sh` → PASS
   - `m015-p03-changelog-has-m015.sh` → PASS
   - `m015-p03-migration-doc.sh` → PASS
   - `m015-p03-wider-docs-sweep.sh` → PASS
4. Only `m015-p03-allow-list-tightened.sh` remains FAILing (T04).
5. No edits to `.orchestrator/` tree, no edits to migration adapters, no edits to ALLOW_P03_DOCS.
