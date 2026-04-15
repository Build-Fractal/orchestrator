---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P06"
milestone: "M006"
name: "Verify extension.yml, add doc conformance check, update CLAUDE.md"
depends_on: []
---

## Prerequisites

- Access to the full codebase at the project root.
- All M006 documentation artifacts from P01-P05 exist on disk.
- No prior tasks required — T02 is independent.

## Description

Three deliverables in one task:

1. **Extension inventory verification**: Cross-check every command, hook,
   and script listed in `extension.yml` against actual files on disk.
   Report any missing files. Identify any scripts that exist but are not
   registered in `extension.yml`. Fix discrepancies.

2. **Doc conformance diagnostic**: Create `scripts/diagnostics/check-docs.sh`
   that verifies required reference docs and user guides exist. Integrate
   it into `run-doctor.sh`. Register in `extension.yml`.

3. **CLAUDE.md update**: Update the project status section, key files
   list, and recent changes to reflect the current state after M001-M006.

## Steps

### Step 1 — Cross-check extension.yml commands against disk

Read `extension.yml` and verify every command file exists:

```
commands/evaluate.md
commands/discuss.md
commands/roadmap.md
commands/plan-phase.md
commands/dispatch.md
commands/auto.md
commands/verify.md
commands/status.md
commands/resume.md
commands/consolidate.md
commands/migrate.md
commands/doctor.md
```

That is 12 command files listed. Verify each exists. Count the actual
`commands/*.md` files (excluding README.md) and compare. If any command
file exists but is not listed in `extension.yml`, add it. If any listed
file does not exist, remove the entry.

### Step 2 — Cross-check extension.yml scripts against disk

Read the `provides.scripts` section of `extension.yml` and verify every
listed script file exists and is executable (`test -x`). The current
count is approximately 60 scripts. For each:

- Verify the file exists at the listed path.
- Verify the file has executable permissions.

Then scan for scripts that exist on disk but are not listed:

- `scripts/**/*.sh` — find all `.sh` files recursively.
- Compare against the extension.yml list.
- Verification scripts (`scripts/verify/`) are NOT expected to be in
  extension.yml (they are phase-specific test scripts, not extension
  scripts).
- Migration scripts in `scripts/migrate/` should be checked.
- Library scripts in `scripts/lib/` and `scripts/knowledge/lib/` should
  be checked.

If scripts exist that should be registered (diagnostic checks, lifecycle
scripts, library scripts), add them to `extension.yml`.

### Step 3 — Create scripts/diagnostics/check-docs.sh

Create a new diagnostic check script that verifies required documentation
files exist. Follow the DOCTOR: output protocol used by existing checks
(see `check-instructions.sh` for pattern reference).

The script should check for:

**Reference docs** (required — produced by M001-M006):
- `references/architecture.md`
- `references/engine.md`
- `references/events.md`
- `references/errors.md`
- `references/hooks.md`
- `references/recipes.md`
- `references/routing.md`
- `references/constitution-walkthrough.md`
- `references/file-formats.md`
- `references/state-machine.md`
- `references/verification-ladder.md`
- `references/tier-definitions.md`
- `references/installation.md`
- `references/provider-convention.md`

**User guides** (required — produced by M006 P04):
- `docs/getting-started.md`
- `docs/recipe-authoring.md`
- `docs/hook-development.md`
- `docs/knowledge-management.md`

**Contributor docs** (required — produced by M006 P05):
- `scripts/AGENTS.md`

Output format:
- If all files exist: `DOCTOR:DOCS status=ok msg="All N documentation files present"`
- If any missing: `DOCTOR:DOCS status=missing msg="M of N documentation files missing: <list>"`

Script structure:
```bash
#!/usr/bin/env bash
# scripts/diagnostics/check-docs.sh — Verify required documentation files exist
# Usage: check-docs.sh [--root <project-root>]
set -eu

# Parse args
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
while [ $# -gt 0 ]; do
  case "$1" in
    --root) PROJECT_ROOT="$2"; shift 2 ;;
    *) echo "check-docs.sh: unknown option: $1" >&2; exit 1 ;;
  esac
done

# Check each required doc...
```

Bash 3.2 compatible — no associative arrays. Use indexed arrays for the
file list. Count missing files. Exit 0 if all present (DOCTOR status=ok),
exit 1 if any missing (DOCTOR status=missing).

### Step 4 — Integrate check-docs.sh into run-doctor.sh

Add a `run_check` invocation in `scripts/diagnostics/run-doctor.sh`:

```bash
run_check "Documentation Coverage" "$SCRIPT_DIR/check-docs.sh" "--root $PROJECT_ROOT" "0"
```

Add it after the existing checks (e.g., after "Recipe Conformance" and
before "Task Plan Shape" which is the advisory check).

### Step 5 — Register check-docs.sh in extension.yml

Add to the `provides.scripts` section:

```yaml
    - file: scripts/diagnostics/check-docs.sh
      executable: true
```

Add it after the existing diagnostic script entries.

### Step 6 — Update CLAUDE.md

Update the following sections:

**Project Status**: Update to reflect current state. Count actual files:
- Commands: count `commands/*.md` files (excluding README.md)
- Scripts: count entries in `extension.yml` `provides.scripts` section
- Templates: count files in `templates/` (excluding README.md)
- Reference docs: count files in `references/` (excluding README.md)
- User guides: count files in `docs/`
- Test suites: count `tests/test-s*.sh` files

Update version reference from "v0.1.1 in progress" to reflect that
M006 documentation phase is active.

**Key Files**: Update to reflect all current key files:
- Add `docs/` directory entry
- Add `references/` with updated count
- Add `scripts/AGENTS.md` as contributor guide
- Update template count if changed
- Update test count if changed

**Recent Changes**: Update to reflect M002-M006 completion.

### Step 7 — Verify changes

Verify all changes are self-consistent:
- Every file listed in extension.yml exists.
- check-docs.sh runs successfully.
- run-doctor.sh includes the new check.
- CLAUDE.md counts match reality.

## Must-Haves

- [ ] Every command file in `extension.yml` exists on disk
- [ ] Every script file in `extension.yml` exists on disk and is executable
- [ ] No significant unregistered scripts (diagnostics, lifecycle, library)
- [ ] `scripts/diagnostics/check-docs.sh` exists with DOCTOR: output protocol
- [ ] `check-docs.sh` checks all 19 required documentation files
- [ ] `run-doctor.sh` invokes `check-docs.sh`
- [ ] `check-docs.sh` is registered in `extension.yml`
- [ ] `CLAUDE.md` project status is accurate (command/script/template/reference counts)
- [ ] `CLAUDE.md` key files section reflects current project state
- [ ] `CLAUDE.md` recent changes section reflects M002-M006

## Verification

After writing, run:

```
bash scripts/verify/m006-p06-extyml-commands.sh
bash scripts/verify/m006-p06-extyml-scripts.sh
bash scripts/verify/m006-p06-check-docs-exists.sh
bash scripts/verify/m006-p06-doctor-docs.sh
bash scripts/verify/m006-p06-claude-md-status.sh
```

All must exit 0. If verification scripts do not yet exist (T03 has not
run), verify manually.

## Inputs

### From Previous Tasks

None — T02 is independent.

### From Disk (Pre-existing)

- `extension.yml` — current manifest (287 lines, 12 commands, ~60 scripts)
- `scripts/diagnostics/run-doctor.sh` — current doctor runner (131 lines, 13 checks)
- `CLAUDE.md` — current project overview (64 lines)
- `scripts/diagnostics/check-instructions.sh` — pattern reference for DOCTOR: protocol
- All `commands/*.md` files — cross-check targets
- All `scripts/**/*.sh` files — cross-check targets
- All `references/*.md` files — doc conformance targets
- All `docs/*.md` files — doc conformance targets

## Constraints

- **DC-4**: Verify-as-you-write — all claims verified against actual files.
- **DC-5**: Bug fix commits reference the doc/script that surfaced them.
- **DC-6**: Bash 3.2 / POSIX compatibility for check-docs.sh.
- DOCTOR: output protocol must be followed (status=ok/missing/warn).
- Extension.yml format must be preserved (YAML structure, indentation).

## Expected Output

After completing this task:

1. `extension.yml` is verified — every command and script exists on disk.
2. `scripts/diagnostics/check-docs.sh` exists and checks 19 doc files.
3. `run-doctor.sh` includes the documentation coverage check.
4. `CLAUDE.md` accurately reflects the project's current state.
5. If any missing scripts or unregistered files were found, they are
   fixed and committed with DC-5 references.
