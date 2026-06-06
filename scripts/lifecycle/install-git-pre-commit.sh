#!/usr/bin/env bash
# scripts/lifecycle/install-git-pre-commit.sh — git pre-commit wiring for the
# orchestrator before-commit lifecycle gate (M009 FR-5, Cursor install path).
#
# Claude Code wires `scripts/lifecycle/before-commit.sh` as a PreToolUse Bash
# matcher hook (it fires before every dispatched Bash command). Cursor has no
# CC-style PreToolUse-on-bash event, so the runtime-appropriate mechanism for
# the before-commit lifecycle gate under Cursor is an actual git
# `.git/hooks/pre-commit` hook. This script installs (or removes) that hook.
#
# SAFETY CONTRACT (the load-bearing invariant — read before touching this):
#   The generated pre-commit hook PROPAGATES before-commit.sh's exit code, so
#   it is only as blocking as before-commit.sh itself. Today before-commit.sh
#   is an unconditional `exit 0` no-op, so this hook NEVER blocks an ordinary
#   commit. The hook also fails OPEN: if before-commit.sh is missing/unreadable
#   it exits 0. Anyone wiring real verification into before-commit.sh MUST keep
#   it milestone-aware and fail-open outside an active milestone, or it will
#   block every commit in every Cursor consumer repo. See before-commit.sh.
#
# Usage:
#   bash scripts/lifecycle/install-git-pre-commit.sh \
#     --project-dir <path> [--dry-run] [--uninstall] [--verbose]
#
# Behaviour:
#   - Not a git repo            → skip with a note, exit 0 (never fails install).
#   - pre-commit absent         → write the managed hook (chmod +x).
#   - pre-commit present, ours  → idempotent rewrite (carries our marker).
#   - pre-commit present, theirs→ clobber-guard: preserve + WARN, do not write.
#   - --dry-run                 → no writes; emit would_write= / would_skip=.
#   - --uninstall               → remove ONLY if it carries our marker.
#   - honors core.hooksPath     → installs into the configured hooks dir.
#
# Bash 3.2 + POSIX-sh. No mapfile, no <(...), no associative arrays.
#
# Exit codes:
#   0 success OR a benign skip (non-git, operator-owned, absent-on-uninstall)
#   1 generic failure (FAIL: prefix on stderr)
#   2 argument error

set -u

# Distinctive marker grepped for clobber-detection + uninstall. Must appear
# verbatim in the generated hook body.
MARKER='ORCHESTRATOR_MANAGED_PRE_COMMIT'

PROJECT_DIR=""
DRY_RUN=0
UNINSTALL=0
VERBOSE=0

usage() {
  sed -n '2,46p' "$0"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --project-dir)
      shift
      if [ $# -eq 0 ]; then
        echo "FAIL: --project-dir requires a path argument" >&2
        exit 2
      fi
      PROJECT_DIR="$1"
      shift ;;
    --project-dir=*)
      PROJECT_DIR="${1#--project-dir=}"
      shift ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    --uninstall)
      UNINSTALL=1; shift ;;
    --verbose)
      VERBOSE=1; shift ;;
    -h|--help)
      usage
      exit 0 ;;
    *)
      echo "FAIL: unknown argument '$1'" >&2
      exit 2 ;;
  esac
done

log() { [ "$VERBOSE" = "1" ] && echo "[install-git-pre-commit] $*" >&2 || true; }

if [ -z "$PROJECT_DIR" ]; then
  echo "FAIL: --project-dir is required" >&2
  exit 2
fi
if [ ! -d "$PROJECT_DIR" ]; then
  echo "FAIL: project dir does not exist: $PROJECT_DIR" >&2
  exit 1
fi

# --- Resolve git repo + hooks dir (honoring core.hooksPath). ---
# A non-git project is a benign skip, NOT an install failure: orchestrator
# can manage a directory that is not (yet) a git repo.
git_top="$(cd "$PROJECT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$git_top" ]; then
  echo "pre_commit_wired=0 reason=not-a-git-repo"
  echo "note: $PROJECT_DIR is not a git work tree; skipping pre-commit hook" >&2
  exit 0
fi

git_dir="$(cd "$PROJECT_DIR" && git rev-parse --absolute-git-dir 2>/dev/null)"
if [ -z "$git_dir" ]; then
  echo "pre_commit_wired=0 reason=not-a-git-repo"
  echo "note: could not resolve .git dir for $PROJECT_DIR; skipping" >&2
  exit 0
fi

hooks_path_cfg="$(cd "$PROJECT_DIR" && git config --get core.hooksPath 2>/dev/null)"
if [ -n "$hooks_path_cfg" ]; then
  case "$hooks_path_cfg" in
    /*) hooks_dir="$hooks_path_cfg" ;;
    *)  hooks_dir="$git_top/$hooks_path_cfg" ;;
  esac
else
  hooks_dir="$git_dir/hooks"
fi

target="$hooks_dir/pre-commit"

# Absolute path to the gate script as staged under the project. The installer
# stages scripts/ under PROJECT_DIR; embed the absolute path so the hook does
# not have to re-derive it at commit time.
before_commit="$PROJECT_DIR/scripts/lifecycle/before-commit.sh"

# --- Uninstall path: remove only our managed hook. ---
if [ "$UNINSTALL" = "1" ]; then
  if [ ! -e "$target" ]; then
    echo "pre_commit_removed=0 reason=absent"
    exit 0
  fi
  if ! grep -q "$MARKER" "$target" 2>/dev/null; then
    echo "WARN: $target exists and is operator-owned (no orchestrator marker); preserving it" >&2
    echo "pre_commit_removed=0 reason=operator-owned"
    exit 0
  fi
  if [ "$DRY_RUN" = "1" ]; then
    echo "would_remove=$target"
    exit 0
  fi
  rm -f "$target"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "FAIL: rm $target exited $rc" >&2
    exit 1
  fi
  echo "removed=$target"
  exit 0
fi

# --- Clobber-guard: never overwrite an operator-owned pre-commit hook. ---
if [ -e "$target" ] && ! grep -q "$MARKER" "$target" 2>/dev/null; then
  echo "WARN: $target exists and is operator-owned (no orchestrator marker); preserving it, pre_commit_wired=0" >&2
  if [ "$DRY_RUN" = "1" ]; then
    echo "would_skip=$target reason=operator-owned"
  else
    echo "pre_commit_wired=0 reason=operator-owned"
  fi
  exit 0
fi

if [ "$DRY_RUN" = "1" ]; then
  echo "would_write=$target"
  exit 0
fi

# --- Write the managed hook. ---
log "writing managed pre-commit hook to $target"
mkdir -p "$hooks_dir"
mk_rc=$?
if [ "$mk_rc" -ne 0 ]; then
  echo "FAIL: mkdir -p $hooks_dir exited $mk_rc" >&2
  exit 1
fi

tmp="$(mktemp -t orch-pre-commit.XXXXXX)" || {
  echo "FAIL: mktemp" >&2
  exit 1
}

# Heredoc body. The marker line is the clobber/uninstall sentinel. The hook
# fails OPEN (missing gate → exit 0) and propagates the gate's exit code so it
# becomes a real gate the moment before-commit.sh enforces verification.
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' "# ${MARKER} (M009 FR-5 — Cursor install path)"
  printf '%s\n' '# Orchestrator before-commit lifecycle gate. Managed by'
  printf '%s\n' '# scripts/lifecycle/install-git-pre-commit.sh — edits are overwritten on'
  printf '%s\n' '# the next install. Fails OPEN: a missing/unreadable gate never blocks a'
  printf '%s\n' '# commit. Propagates the gate exit code, so it is only as blocking as'
  printf '%s\n' '# before-commit.sh itself (today an unconditional no-op).'
  printf '%s\n' "BEFORE_COMMIT=\"${before_commit}\""
  printf '%s\n' 'if [ -f "$BEFORE_COMMIT" ]; then'
  printf '%s\n' '  bash "$BEFORE_COMMIT" </dev/null'
  printf '%s\n' '  exit $?'
  printf '%s\n' 'fi'
  printf '%s\n' 'exit 0'
} > "$tmp"

mv "$tmp" "$target"
mv_rc=$?
if [ "$mv_rc" -ne 0 ]; then
  rm -f "$tmp"
  echo "FAIL: mv to $target exited $mv_rc" >&2
  exit 1
fi
chmod +x "$target"

echo "wrote=$target pre_commit_wired=1"
exit 0
