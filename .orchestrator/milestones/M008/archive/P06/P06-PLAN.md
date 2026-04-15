---
schema_version: "1.0"
type: phase-plan
phase: "P06"
milestone: "M008"
goal: "Package the orchestrator as a cross-runtime installable bundle, with per-runtime installers and an offline-safe update checker."
demo_sentence: "A developer runs `bash packaging/install/install-claude-code.sh --project-dir <dir>` (or the codex/cursor variant) and sees every orchestrator command register as a native skill in that runtime; `bash scripts/lifecycle/check-update.sh` reports installed_version/latest_version/update_available without crashing offline."
risk: "medium"
depends_on: ["P04", "P05"]
---

## Must-Haves

### Truths

<!-- Per AD-19, Check commands use single-script-file shape (no inline
     compound bash, no subshells, no $() with pipes, no process subst). -->

- `packaging/SKILL.md` specification document exists and describes the skill-file frontmatter schema (name, namespace, description, runtime_compatibility) plus body conventions.
  - Check: `bash scripts/verify/m008-p06-skill-spec.sh`

- `packaging/skills/` contains one skill file per orchestrator command (12 total), each with YAML frontmatter carrying `name:`, `namespace:`, `description:`, and `runtime_compatibility:` keys.
  - Check: `bash scripts/verify/m008-p06-skills-coverage.sh`

- `packaging/bundle/manifest.yml` exists and lists the bundled skills + hooks + config + version (defaulting to `0.3.0-dev` when no `VERSION` file is present at repo root).
  - Check: `bash scripts/verify/m008-p06-bundle-manifest.sh`

- `packaging/bundle/` directory structure contains `skills/`, `hooks/`, `config/`, and `README.md` matching the manifest.
  - Check: `bash scripts/verify/m008-p06-bundle-layout.sh`

- Claude Code installer `packaging/install/install-claude-code.sh` runs hermetically against a `HOME=$(mktemp -d)` fixture with `--dry-run`, emitting `would_write=` lines and exiting 0.
  - Check: `bash scripts/verify/m008-p06-install-claude-code-hermetic.sh`

- Codex installer `packaging/install/install-codex.sh` runs hermetically with `--dry-run` and exits 0, emitting `would_write=` lines that point under the hermetic HOME.
  - Check: `bash scripts/verify/m008-p06-install-codex-hermetic.sh`

- Cursor installer `packaging/install/install-cursor.sh` runs hermetically with `--project-dir $(mktemp -d) --dry-run` and exits 0, emitting `would_write=` lines under the hermetic project dir.
  - Check: `bash scripts/verify/m008-p06-install-cursor-hermetic.sh`

- All three installers support `--dry-run` (no writes) and `--force` (overwrite existing skills) and emit `installed=<N>` or `would_write=<path>` prefix lines plus a final `SUMMARY:` line. They refuse to run against an unguarded real `$HOME` (claude-code/codex) or a missing `--project-dir` (cursor).
  - Check: `bash scripts/verify/m008-p06-installer-interface.sh`

- `scripts/lifecycle/check-update.sh` works offline (graceful degradation) and emits `installed_version=`, `latest_version=`, `update_available=true|false`, and on update `update_instructions=`.
  - Check: `bash scripts/verify/m008-p06-check-update.sh`

- End-to-end: package → hermetic install (Claude Code) → skills discoverable as `$HERMETIC_HOME/.claude/commands/orchestrator-*.md` with 12 entries; state root resolves under hermetic project root via `scripts/state/resolve-root.sh`.
  - Check: `bash scripts/verify/m008-p06-integration-e2e.sh`

- All P06 shell scripts are Bash 3.2 compatible (no `declare -A`, no `mapfile`/`readarray`, no `${var,,}`).
  - Check: `bash scripts/verify/m008-p06-bash32-compat.sh`

### Artifacts

- packaging/SKILL.md (min 40 lines, contains "runtime_compatibility")
- packaging/skills/orchestrator-evaluate.md (min 10 lines, contains "namespace:")
- packaging/skills/orchestrator-auto.md (min 10 lines, contains "namespace:")
- packaging/bundle/manifest.yml (min 15 lines, contains "version:")
- packaging/bundle/README.md (min 20 lines, contains "install")
- packaging/install/install-claude-code.sh (min 40 lines, contains "--dry-run")
- packaging/install/install-codex.sh (min 40 lines, contains "--dry-run")
- packaging/install/install-cursor.sh (min 40 lines, contains "--project-dir")
- scripts/lifecycle/check-update.sh (min 30 lines, contains "installed_version=")
- scripts/verify/m008-p06-integration-e2e.sh (min 30 lines, contains "orchestrator-")

### Key Links

- packaging/install/install-claude-code.sh → scripts/dispatch/adapters/runtime/claude-code.sh (installer delegates --register to P05 runtime adapter)
- packaging/install/install-codex.sh → scripts/dispatch/adapters/runtime/codex.sh (installer delegates --register to P05 runtime adapter)
- packaging/install/install-cursor.sh → scripts/dispatch/adapters/runtime/cursor.sh (installer delegates --register to P05 runtime adapter with --project-dir)
- packaging/skills/orchestrator-evaluate.md → commands/evaluate.md (skill body references command document)
- packaging/bundle/README.md → packaging/install/install-claude-code.sh (README documents the installers)
- packaging/bundle/manifest.yml → packaging/SKILL.md (manifest references the skill-file spec)
- scripts/lifecycle/check-update.sh → packaging/bundle/manifest.yml (check-update reads bundled version)

## Tasks

### T01: SKILL.md specification + generated skill files

See `tasks/T01-PLAN.md`.

### T02: Bundle structure (manifest, skills/, hooks/, config/, README)

See `tasks/T02-PLAN.md`.

### T03: Per-runtime installers (Claude Code, Codex, Cursor)

See `tasks/T03-PLAN.md`.

### T04: check-update.sh version checker (offline-safe)

See `tasks/T04-PLAN.md`.

### T05: Bash 3.2 compat + integration e2e

See `tasks/T05-PLAN.md`.

## Task Dependencies

```
T01 ──► T02 ──► T03 ──► T05
                 │        ▲
                 └─► T04 ─┘
```

- T01 creates `packaging/SKILL.md` + `packaging/skills/orchestrator-*.md` (12 files).
- T02 consumes skills from T01 and produces the `packaging/bundle/` wrapper + manifest.
- T03 consumes the bundle from T02 and writes per-runtime installers that delegate to P05 runtime adapters.
- T04 consumes the manifest from T02 and produces `scripts/lifecycle/check-update.sh`.
- T05 consumes everything — Bash 3.2 compat scan + hermetic end-to-end integration test (package → install → verify).

T03 and T04 can run in parallel after T02; T05 is the final gate.

## Files Likely Touched

- packaging/SKILL.md (create)
- packaging/skills/orchestrator-auto.md (create)
- packaging/skills/orchestrator-consolidate.md (create)
- packaging/skills/orchestrator-discuss.md (create)
- packaging/skills/orchestrator-dispatch.md (create)
- packaging/skills/orchestrator-doctor.md (create)
- packaging/skills/orchestrator-evaluate.md (create)
- packaging/skills/orchestrator-migrate.md (create)
- packaging/skills/orchestrator-plan-phase.md (create)
- packaging/skills/orchestrator-resume.md (create)
- packaging/skills/orchestrator-roadmap.md (create)
- packaging/skills/orchestrator-status.md (create)
- packaging/skills/orchestrator-verify.md (create)
- packaging/skills/generate-skills.sh (create)
- packaging/bundle/manifest.yml (create)
- packaging/bundle/README.md (create)
- packaging/bundle/skills/ (create — symlinks or copies of packaging/skills/)
- packaging/bundle/hooks/before-tasks.json (create)
- packaging/bundle/hooks/after-tasks.json (create)
- packaging/bundle/hooks/before-implement.json (create)
- packaging/bundle/hooks/after-implement.json (create)
- packaging/bundle/hooks/before-commit.json (create)
- packaging/bundle/config/orchestrator.default.yml (create)
- packaging/install/install-claude-code.sh (create)
- packaging/install/install-codex.sh (create)
- packaging/install/install-cursor.sh (create)
- scripts/lifecycle/check-update.sh (create)
- scripts/verify/m008-p06-skill-spec.sh (create)
- scripts/verify/m008-p06-skills-coverage.sh (create)
- scripts/verify/m008-p06-bundle-manifest.sh (create)
- scripts/verify/m008-p06-bundle-layout.sh (create)
- scripts/verify/m008-p06-install-claude-code-hermetic.sh (create)
- scripts/verify/m008-p06-install-codex-hermetic.sh (create)
- scripts/verify/m008-p06-install-cursor-hermetic.sh (create)
- scripts/verify/m008-p06-installer-interface.sh (create)
- scripts/verify/m008-p06-check-update.sh (create)
- scripts/verify/m008-p06-integration-e2e.sh (create)
- scripts/verify/m008-p06-bash32-compat.sh (create)
