---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P06"
milestone: "M008"
name: "Bundle structure — manifest, skills, hooks, config, README"
depends_on: ["T01"]
---

## Prerequisites

- T01 committed `packaging/SKILL.md` + 12 `packaging/skills/orchestrator-*.md` files.
- Existing orchestrator state conventions under `scripts/state/resolve-root.sh` (P04).
- `extension.yml` at repo root documents 5 lifecycle hook points (before-tasks, after-tasks, before-implement, after-implement, before-commit).

## Description

Produce the installable bundle — a single directory tree that contains every skill, every hook config fragment, default orchestrator config, and a human-readable README. This bundle is what installers stage into each runtime in T03.

The bundle is self-describing via `manifest.yml`, which lists skills, hooks, config file, and a version. The version comes from a `VERSION` file at repo root if present; otherwise defaults to `0.3.0-dev` per the planning payload.

## Steps

1. Create `packaging/bundle/` with these children:
   - `packaging/bundle/manifest.yml`
   - `packaging/bundle/skills/` — copies (not symlinks) of the 12 `packaging/skills/orchestrator-*.md` files, produced by a bundle builder script.
   - `packaging/bundle/hooks/` — one JSON file per lifecycle hook.
   - `packaging/bundle/config/orchestrator.default.yml`
   - `packaging/bundle/README.md`

2. Write `packaging/bundle/manifest.yml`:

```yaml
schema_version: "1.0"
type: bundle-manifest
name: "spec-kit-orchestrator"
version: "0.3.0-dev"
description: "Autonomous multi-phase orchestration skills for Claude Code, Codex, and Cursor"
skill_spec: "packaging/SKILL.md"
skills:
  - orchestrator-auto.md
  - orchestrator-consolidate.md
  - orchestrator-discuss.md
  - orchestrator-dispatch.md
  - orchestrator-doctor.md
  - orchestrator-evaluate.md
  - orchestrator-migrate.md
  - orchestrator-plan-phase.md
  - orchestrator-resume.md
  - orchestrator-roadmap.md
  - orchestrator-status.md
  - orchestrator-verify.md
hooks:
  - event: before-tasks
    file: hooks/before-tasks.json
  - event: after-tasks
    file: hooks/after-tasks.json
  - event: before-implement
    file: hooks/before-implement.json
  - event: after-implement
    file: hooks/after-implement.json
  - event: before-commit
    file: hooks/before-commit.json
config_default: "config/orchestrator.default.yml"
runtime_compatibility:
  - claude-code
  - codex
  - cursor
```

   The `version:` value is substituted at bundle-build time: read `VERSION` from repo root; if absent, emit `0.3.0-dev`.

3. Create `packaging/bundle/build-bundle.sh` (Bash 3.2 compatible) that:
   - Reads `VERSION` at repo root (or falls back to `0.3.0-dev`).
   - Copies `packaging/skills/orchestrator-*.md` into `packaging/bundle/skills/` (overwriting existing).
   - Emits the manifest with the version substituted.
   - Supports `--check` mode: verify bundle contents match expected set (12 skills, 5 hooks, 1 config, 1 README, 1 manifest); exit non-zero on drift.
   - Emits one `wrote=<path>` line per file on stdout.

4. Create each of the 5 hook JSON fragments under `packaging/bundle/hooks/`. Each has the shape:

```json
{
  "schema_version": "1.0",
  "event": "before-tasks",
  "command": "bash scripts/lifecycle/before-tasks.sh",
  "description": "Orchestrator pre-task hook — budget + stuck detection."
}
```

   Substitute `event` and script name per hook. If the corresponding `scripts/lifecycle/<event>.sh` does not yet exist, use the best-match existing script name (e.g., `scripts/lifecycle/budget-checker.sh` for `before-tasks`) or leave `command` as a placeholder `bash scripts/lifecycle/<event>.sh` — the installer in T03 wires these up through the runtime adapter's `--hook-config` path rather than executing them directly.

5. Write `packaging/bundle/config/orchestrator.default.yml`:

```yaml
schema_version: "1.0"
type: orchestrator-config
state_root: ".orchestrator"
intensity:
  default: standard
  auto_detect: true
integration:
  speckit: auto  # auto|disabled|enabled
dispatch:
  default_backend: local-agent
knowledge:
  graph_backend: sqlite
```

6. Write `packaging/bundle/README.md` (20+ lines) covering:
   - What the bundle is.
   - How to install it for each runtime (one-line invocation per installer).
   - Where state lands (`.orchestrator/` under project root, via `scripts/state/resolve-root.sh`).
   - How to update (`bash scripts/lifecycle/check-update.sh`).
   - Links to `packaging/SKILL.md` and `packaging/install/install-*.sh`.

7. Create `scripts/verify/m008-p06-bundle-manifest.sh` verifying `packaging/bundle/manifest.yml` exists, contains `version:`, `skills:` list with 12 entries, and `hooks:` list with 5 events.

8. Create `scripts/verify/m008-p06-bundle-layout.sh` verifying the `skills/`, `hooks/`, `config/`, and `README.md` directory contents match the manifest.

## Must-Haves

Addresses:

- `packaging/bundle/manifest.yml` with `version:` field (default `0.3.0-dev`).
- `packaging/bundle/` layout: `skills/`, `hooks/`, `config/`, `README.md`.
- Key links: `packaging/bundle/README.md → packaging/install/install-claude-code.sh`, `packaging/bundle/manifest.yml → packaging/SKILL.md`.

## Verification

```
bash packaging/bundle/build-bundle.sh --check
bash scripts/verify/m008-p06-bundle-manifest.sh
bash scripts/verify/m008-p06-bundle-layout.sh
```

Expected output:

```
PASS: bundle manifest valid (version=..., 12 skills, 5 hooks)
PASS: bundle layout matches manifest
```

## Inputs

### From Previous Tasks

- `packaging/skills/orchestrator-*.md` (from T01) — copied into `packaging/bundle/skills/`.
  - Key API: each file is a self-contained skill doc with frontmatter (`name`, `namespace`, `description`, `runtime_compatibility`, `command_file`, `schema_version`) and a body pointing at `commands/<cmd>.md`.
- `packaging/SKILL.md` (from T01) — referenced from the manifest's `skill_spec:` field.
- `packaging/skills/generate-skills.sh` (from T01) — T02 does not invoke it directly, but bundle rebuilds assume skills are regeneratable.

### From Disk (Pre-existing)

- `VERSION` at repo root (if present) — version source; otherwise fall back to `0.3.0-dev`.
- `extension.yml` — lists the 5 lifecycle hooks this bundle mirrors.
- `scripts/state/resolve-root.sh` (P04) — referenced from bundle README as how state root is determined.

## Constraints

- No python, no jq — pure bash/grep/sed/awk only.
- Bundle skills MUST be copies, not symlinks — installers may need to tar/zip the bundle and symlinks break archives.
- Bash 3.2 compat — no `declare -A`, no `mapfile`/`readarray`.
- If `VERSION` file is introduced later, `build-bundle.sh` picks it up automatically.

## Expected Output

- `packaging/bundle/manifest.yml` — 25+ line manifest.
- `packaging/bundle/skills/orchestrator-<cmd>.md` — 12 copied skill files.
- `packaging/bundle/hooks/<event>.json` — 5 hook fragments.
- `packaging/bundle/config/orchestrator.default.yml` — default config.
- `packaging/bundle/README.md` — 20+ line installation guide.
- `packaging/bundle/build-bundle.sh` — bundle builder with `--check` mode.
- `scripts/verify/m008-p06-bundle-manifest.sh` — verification script (mode 0755).
- `scripts/verify/m008-p06-bundle-layout.sh` — verification script (mode 0755).
