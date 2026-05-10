---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P04"
milestone: "M008"
name: "Create scripts/migrate/migrate-state.sh -- one-shot .specify/orchestrator -> .orchestrator migration"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete — `scripts/state/resolve-root.sh` exists.
- Bash 3.2+ available.
- Repository does NOT yet contain a `scripts/migrate/` directory. This task creates it.

## Description

Create `scripts/migrate/migrate-state.sh` — a one-shot migration that moves `.specify/orchestrator/*` into `.orchestrator/*` for existing users upgrading from the spec-kit extension era. Migration is a HARD move (not a copy-then-delete, not a two-way sync). After successful migration, the old path no longer exists.

The script enforces three invariants:

1. **Source must exist.** If `.specify/orchestrator/` is absent, emit `SKIP: no source to migrate` and exit 0.
2. **Destination must be absent or empty.** If `.orchestrator/` already exists with content, emit `SKIP: destination already populated` and exit 0. Never overwrite.
3. **Migration preserves contents byte-for-byte.** Use `mv` (rename when possible, fall back to `cp -R && rm -rf` across filesystems). Preserve timestamps and permissions.

A `--dry-run` flag performs all checks and emits a `DRYRUN:` line listing what WOULD move, but performs no filesystem mutation.

CRITICAL: This script must NOT be invoked against the live project during P04 execution. The running milestone (M008) depends on state at `.specify/orchestrator/milestones/M008/` for its own orchestration. Migration is a user-facing tool, not a self-modifying one. T06's end-to-end test uses a throwaway temp directory.

## Steps

### Step 1 — Create scripts/migrate/ directory

```bash
mkdir -p scripts/migrate
```

### Step 2 — Create scripts/migrate/migrate-state.sh

Write verbatim:

```bash
#!/usr/bin/env bash
# scripts/migrate/migrate-state.sh — One-shot migration of orchestrator state.
#
# Moves .specify/orchestrator/* to .orchestrator/* for users upgrading from
# the spec-kit-extension era. This is a HARD move: after success, the old
# path is gone.
#
# Invariants:
#   1. Source (.specify/orchestrator) must exist.
#   2. Destination (.orchestrator) must be absent or empty.
#   3. Preserve permissions and timestamps.
#
# Usage:
#   migrate-state.sh              -> perform migration
#   migrate-state.sh --dry-run    -> report what would move, no changes
#
# Output:
#   MIGRATED: <src> -> <dst>        on success
#   SKIP:     <reason>              on no-op (not an error)
#   DRYRUN:   <src> -> <dst>        on --dry-run
#   ERROR:    <reason>              to stderr on failure, exits 1
#
# Exit: 0 on success or skip; 1 on failure.
# Bash 3.2 compatible.

set -u

DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      sed -n '2,21p' "$0"; exit 0 ;;
    *)
      echo "ERROR: unknown argument '$1'" >&2
      exit 1 ;;
  esac
done

# Locate repo root
repo_root="$PWD"
while [[ "$repo_root" != "/" ]]; do
  if [[ -d "$repo_root/.git" ]] || [[ -f "$repo_root/.git" ]]; then
    break
  fi
  repo_root="$(dirname "$repo_root")"
done
if [[ "$repo_root" = "/" ]]; then
  repo_root="$PWD"
fi

src="$repo_root/.specify/orchestrator"
dst="$repo_root/.orchestrator"

# Check 1: source must exist
if [[ ! -d "$src" ]]; then
  echo "SKIP: no source to migrate (expected $src)"
  exit 0
fi

# Check 2: destination must be absent or empty
if [[ -d "$dst" ]]; then
  # Count entries (including dotfiles, excluding . and ..)
  entry_count=$(ls -A "$dst" 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$entry_count" != "0" ]]; then
    echo "SKIP: destination already populated ($dst has $entry_count entries)"
    exit 0
  fi
fi

# Dry-run: report and exit
if [[ "$DRY_RUN" = "1" ]]; then
  echo "DRYRUN: $src -> $dst"
  # List top-level entries that would move
  for entry in "$src"/* "$src"/.[!.]*; do
    [[ -e "$entry" ]] || continue
    echo "DRYRUN:   $(basename "$entry")"
  done
  exit 0
fi

# Perform migration. Prefer mv (rename is atomic on same FS);
# fall back to cp -R + rm -rf across FS boundaries.
if mv "$src" "$dst" 2>/dev/null; then
  echo "MIGRATED: $src -> $dst"
  exit 0
fi

# Fallback: copy then remove
mkdir -p "$dst"
if cp -R "$src"/. "$dst"/ 2>/dev/null && rm -rf "$src"; then
  echo "MIGRATED: $src -> $dst (copy+remove)"
  exit 0
fi

echo "ERROR: migration failed ($src -> $dst)" >&2
exit 1
```

### Step 3 — Make the script executable

```bash
chmod +x scripts/migrate/migrate-state.sh
```

## Must-Haves

This task addresses:

- `scripts/migrate/migrate-state.sh` moves `.specify/orchestrator/*` to `.orchestrator/*` and emits a `MIGRATED:` line.
- `scripts/migrate/migrate-state.sh` refuses to overwrite when `.orchestrator/` already has content and emits a `SKIP:` line.
- `scripts/migrate/migrate-state.sh --dry-run` shows what would move without moving anything.

## Verification

Run:

- `bash scripts/verify/m008-p04-migrate-state-moves.sh`
- `bash scripts/verify/m008-p04-migrate-state-skip.sh`
- `bash scripts/verify/m008-p04-migrate-state-dry-run.sh`

Each must exit 0 with a `PASS:` line. Verification scripts operate on temp fixtures — they never touch the live project.

## Inputs

### From Previous Tasks

- `scripts/state/resolve-root.sh` (from T01) — conceptually referenced (the migration target `.orchestrator` is the resolver's default-new-project location). The migrate script does not functionally call resolve-root; it hardcodes the source and destination paths because migration is a specific one-way operation, not a root-resolution concern.

### From Disk (Pre-existing)

- None. The script is self-contained.

## Constraints

- Bash 3.2 compatible.
- Must NEVER overwrite a populated `.orchestrator/` directory.
- Must NEVER leave the repo in a half-migrated state on failure. Either the full tree is at the new location and the old location is gone, or both locations are intact and the script returns a non-zero exit.
- Must NOT run automatically anywhere in P04. It is invoked manually by the user or by P07's init flow.
- Output lines use prefixes `MIGRATED:`, `SKIP:`, `DRYRUN:`, `ERROR:` — consistent with MEM001.

## Expected Output

Creating:

- `scripts/migrate/` (directory)
- `scripts/migrate/migrate-state.sh` — ~75 lines, executable.

Sample run on a fresh temp fixture with `.specify/orchestrator/` containing files and no `.orchestrator/`:

```
MIGRATED: /tmp/fixture/.specify/orchestrator -> /tmp/fixture/.orchestrator
```

Sample run with `--dry-run`:

```
DRYRUN: /tmp/fixture/.specify/orchestrator -> /tmp/fixture/.orchestrator
DRYRUN:   milestones
DRYRUN:   KNOWLEDGE.md
```

Sample run with destination already populated:

```
SKIP: destination already populated (/tmp/fixture/.orchestrator has 3 entries)
```
