---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P06"
milestone: "M008"
name: "SKILL.md specification and per-command skill files"
depends_on: []
---

## Prerequisites

- 12 orchestrator command documents exist under `commands/*.md` (excluding `README.md` per MEM008). Current set: `auto.md`, `consolidate.md`, `discuss.md`, `dispatch.md`, `doctor.md`, `evaluate.md`, `migrate.md`, `plan-phase.md`, `resume.md`, `roadmap.md`, `status.md`, `verify.md`.
- `scripts/state/namespace-aliases.sh` (from P04) documents the `orchestrator:*` namespace mapping. Skill `namespace:` frontmatter values use this namespace.

## Description

Create the open SKILL.md format specification and generate one conforming skill file per orchestrator command. These skill files are the unit of cross-runtime distribution — installers place (or reference) them under each runtime's skill-discovery directory.

`packaging/SKILL.md` is pure documentation: it describes the frontmatter schema and body conventions so a third party could produce compatible skill files for other tools.

`packaging/skills/orchestrator-<cmd>.md` is one generated file per command. Each contains YAML frontmatter + a markdown body that references the upstream `commands/<cmd>.md` document as the canonical behavior definition.

A small helper `packaging/skills/generate-skills.sh` regenerates the 12 skill files from `commands/*.md` so the set stays in sync with upstream command evolution. The helper is invoked once during this task and committed alongside the generated output; it is also invoked by T05's integration test to ensure regeneration is idempotent.

## Steps

1. Create `packaging/` directory at repo root.
2. Write `packaging/SKILL.md` (the specification) with these sections:
   - "Purpose" — what a skill file is and why the format is open.
   - "Frontmatter schema" — required keys and their value types:
     - `name:` string — human label (e.g., `orchestrator:evaluate`)
     - `namespace:` string — fixed literal `orchestrator` for this project
     - `description:` string — one-sentence trigger hint shown to the agent
     - `runtime_compatibility:` list — any of `claude-code`, `codex`, `cursor`
     - `command_file:` string — relative path back to `commands/<cmd>.md`
     - `schema_version:` string — `"1.0"` for this revision
   - "Body conventions" — body is a short pointer paragraph plus a link to the upstream `commands/<cmd>.md` document; skill files are deliberately thin so the single source of truth stays in `commands/`.
   - "Discovery conventions" — per-runtime filename/location expectations (claude-code user-level: `$HOME/.claude/commands/orchestrator-<cmd>.md`; codex user-level: `$HOME/.codex/skills/orchestrator-<cmd>.md`; cursor project-level: `<project>/.cursor/rules/orchestrator-<cmd>.md`).
   - "Versioning" — skills inherit the bundle `version:` field from `packaging/bundle/manifest.yml`; document the default fallback (`0.3.0-dev`).
3. Create `packaging/skills/generate-skills.sh` (Bash 3.2 compatible). Behavior:
   - Loops over `commands/*.md`, skipping `README.md` (per MEM008).
   - For each `commands/<cmd>.md`:
     - Extract the command's description from its YAML frontmatter `description:` line using `grep`+`sed` (no python, no jq).
     - Write `packaging/skills/orchestrator-<cmd>.md` with the frontmatter below and a 3–6 line body that links back to `commands/<cmd>.md`.
   - Emit one `wrote=<path>` line per skill on stdout, exit 0.
   - Support `--check` mode: re-generate to a temp dir and diff against committed files; exit non-zero if drift detected.
4. Run `bash packaging/skills/generate-skills.sh` once and commit the resulting 12 skill files.
5. Create `scripts/verify/m008-p06-skill-spec.sh` verifying `packaging/SKILL.md` exists, is at least 40 lines, and mentions `runtime_compatibility`, `name:`, `namespace:`, and `command_file:`.
6. Create `scripts/verify/m008-p06-skills-coverage.sh` verifying exactly 12 `packaging/skills/orchestrator-*.md` files exist, each with the required frontmatter keys.

### Skill file template (frontmatter)

Each generated file starts with this YAML frontmatter (literal keys; `<cmd>` and `<description>` substituted per command):

```yaml
---
schema_version: "1.0"
type: skill
name: "orchestrator:<cmd>"
namespace: "orchestrator"
description: "<description copied from commands/<cmd>.md frontmatter>"
runtime_compatibility: ["claude-code", "codex", "cursor"]
command_file: "commands/<cmd>.md"
---
```

Followed by a body of the form:

```markdown
# orchestrator:<cmd>

Canonical behavior is defined in [`commands/<cmd>.md`](../../commands/<cmd>.md).
This skill file is a thin discovery surface for runtimes that enumerate skills
from disk. When the runtime invokes `orchestrator:<cmd>`, it delegates to the
command document above.
```

## Must-Haves

Addresses these phase must-haves:

- `packaging/SKILL.md` specification exists with required sections.
- `packaging/skills/orchestrator-<cmd>.md` exists for all 12 commands.
- Key link: `packaging/skills/orchestrator-evaluate.md → commands/evaluate.md`.

## Verification

```
bash scripts/verify/m008-p06-skill-spec.sh
bash scripts/verify/m008-p06-skills-coverage.sh
bash packaging/skills/generate-skills.sh --check
```

Expected output (each):

```
PASS: packaging/SKILL.md specification present
PASS: 12 orchestrator skill files present with required frontmatter
```

And `--check` must exit 0 with no drift reported.

## Inputs

### From Previous Tasks

None (T01 is the first task in P06).

### From Disk (Pre-existing)

- `commands/*.md` (12 command documents) — source of truth for the generated skill files. Each has YAML frontmatter with a `description:` field.
- `commands/README.md` — excluded (per MEM008 convention).
- `scripts/state/namespace-aliases.sh` — documents the `orchestrator:*` namespace that skill `name:` values use.

## Constraints

- No python, no jq — pure bash/grep/sed/awk only (per MEM001).
- Skill files must stay thin — do not duplicate command-document content; link to it.
- `generate-skills.sh` must be idempotent (running it twice produces identical output).
- Bash 3.2 compat — no `declare -A`, no `mapfile`/`readarray`, no `${var,,}`.

## Expected Output

- `packaging/SKILL.md` — 40+ line specification.
- `packaging/skills/orchestrator-<cmd>.md` — 12 files, ~15 lines each.
- `packaging/skills/generate-skills.sh` — executable helper with `--check` mode.
- `scripts/verify/m008-p06-skill-spec.sh` — verification script (mode 0755).
- `scripts/verify/m008-p06-skills-coverage.sh` — verification script (mode 0755).
