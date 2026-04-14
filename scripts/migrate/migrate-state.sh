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
