#!/usr/bin/env bash
# scripts/lifecycle/emit-managed-gitignore.sh — Managed .gitignore block emitter
# (M035 P00 T02, FR-6 / SC-6).
#
# Appends or replaces a marker-delimited "orchestrator-managed: gitignore"
# block in `<PROJECT_DIR>/.gitignore`. Idempotent: re-runs leave exactly one
# block; lines outside the block are preserved byte-identical.
#
# Marker shape:
#   # >>> orchestrator-managed: gitignore >>>
#   ... block body (canonical content, regenerated each install) ...
#   # <<< orchestrator-managed: gitignore <<<
#
# Usage:
#   bash scripts/lifecycle/emit-managed-gitignore.sh \
#     --project-dir <path> [--dry-run] [--block-content <file>]
#
# Behaviour:
#   - Target absent     → create with canonical block (no leading blank).
#   - Target present, no block found → append (separated by single blank line
#     unless target already ends in a blank line).
#   - Block found       → replace lines opener..closer in place (verbatim
#     preservation outside).
#   - Multiple blocks   → keep the first opener; remove second-and-later
#     opener..closer ranges (defensive collapse to one).
#   - --dry-run         → no writes; emit `would_write=<file>` on stdout.
#   - --block-content   → optional path; substitutes canonical block content
#     verbatim. Caller is responsible for opener/closer correctness; this
#     script wraps caller content with the canonical opener/closer iff the
#     file does not already contain them.
#
# Bash 3.2 + POSIX-sh. No mapfile, no <(...), no associative arrays.
# Single-pass awk rewrite to a temp file then mv.
#
# Exit codes:
#   0 success
#   1 generic failure (FAIL: prefix on stderr)
#   2 argument error

set -u

OPENER='# >>> orchestrator-managed: gitignore >>>'
CLOSER='# <<< orchestrator-managed: gitignore <<<'

PROJECT_DIR=""
DRY_RUN=0
BLOCK_CONTENT_FILE=""

usage() {
  sed -n '2,32p' "$0"
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
    --block-content)
      shift
      if [ $# -eq 0 ]; then
        echo "FAIL: --block-content requires a path argument" >&2
        exit 2
      fi
      BLOCK_CONTENT_FILE="$1"
      shift ;;
    --block-content=*)
      BLOCK_CONTENT_FILE="${1#--block-content=}"
      shift ;;
    -h|--help)
      usage
      exit 0 ;;
    *)
      echo "FAIL: unknown argument '$1'" >&2
      exit 2 ;;
  esac
done

if [ -z "$PROJECT_DIR" ]; then
  echo "FAIL: --project-dir is required" >&2
  exit 2
fi

if [ ! -d "$PROJECT_DIR" ]; then
  echo "FAIL: project dir does not exist: $PROJECT_DIR" >&2
  exit 1
fi

TARGET="$PROJECT_DIR/.gitignore"

# Build the canonical block body in a temp file. We always emit our own
# opener/closer; --block-content (if provided) supplies the body lines only.
BODY_TMP="$(mktemp -t orch-gitignore-body.XXXXXX)" || {
  echo "FAIL: mktemp body" >&2
  exit 1
}

if [ -n "$BLOCK_CONTENT_FILE" ]; then
  if [ ! -f "$BLOCK_CONTENT_FILE" ]; then
    rm -f "$BODY_TMP"
    echo "FAIL: --block-content file not found: $BLOCK_CONTENT_FILE" >&2
    exit 1
  fi
  # Strip caller-supplied opener/closer if present so we control the markers.
  awk -v OPENER="$OPENER" -v CLOSER="$CLOSER" '
    $0 == OPENER { next }
    $0 == CLOSER { next }
    { print }
  ' "$BLOCK_CONTENT_FILE" > "$BODY_TMP"
else
  # Canonical default body (FR-6 v1).
  {
    printf '%s\n' "# Managed by packaging/install/install-{claude-code,codex,cursor}.sh."
    printf '%s\n' "# Sidecars listed here are installer-owned, regenerated on every install,"
    printf '%s\n' "# and should not be committed. Edits inside this block are overwritten on"
    printf '%s\n' "# the next install run; edits outside the block are preserved."
    printf '%s\n' ".orchestrator/install-meta.txt"
  } > "$BODY_TMP"
fi

# Build the canonical full block (opener + body + closer) for substitution.
BLOCK_TMP="$(mktemp -t orch-gitignore-block.XXXXXX)" || {
  rm -f "$BODY_TMP"
  echo "FAIL: mktemp block" >&2
  exit 1
}
{
  printf '%s\n' "$OPENER"
  cat "$BODY_TMP"
  printf '%s\n' "$CLOSER"
} > "$BLOCK_TMP"
rm -f "$BODY_TMP"

if [ "$DRY_RUN" = "1" ]; then
  echo "would_write=$TARGET"
  rm -f "$BLOCK_TMP"
  exit 0
fi

# --- Case 1: target absent → create with canonical block, no leading blank.
if [ ! -e "$TARGET" ]; then
  cp "$BLOCK_TMP" "$TARGET"
  rc=$?
  rm -f "$BLOCK_TMP"
  if [ "$rc" -ne 0 ]; then
    echo "FAIL: cp to $TARGET exited $rc" >&2
    exit 1
  fi
  echo "wrote=$TARGET created=1"
  exit 0
fi

# --- Existing target: rewrite via awk in a single pass.
# State machine:
#   in_block=0 outside → print line as-is (deferring print of pre-block tail)
#   on first opener encountered → emit canonical block, set in_block=1, set
#     seen_block=1, suppress prints until closer
#   on closer with in_block=1 → set in_block=0, suppress this closer line
#   subsequent opener (seen_block=1, in_block=0) → set in_block=1 to suppress
#     a duplicate range; do not re-emit canonical block (already emitted).
# After the file is consumed: if seen_block=0, append a separator + canonical
# block at end. Separator is a single blank line iff the previous emitted
# line was non-blank.
REWRITE_TMP="$(mktemp -t orch-gitignore-rewrite.XXXXXX)" || {
  rm -f "$BLOCK_TMP"
  echo "FAIL: mktemp rewrite" >&2
  exit 1
}

awk -v OPENER="$OPENER" -v CLOSER="$CLOSER" -v BLOCK="$BLOCK_TMP" '
  BEGIN {
    in_block = 0
    seen_block = 0
    last_emitted_blank = 1   # treat start-of-file as if preceded by blank
  }
  {
    if (in_block == 0 && $0 == OPENER) {
      if (seen_block == 0) {
        # First block: emit canonical replacement.
        while ((getline line < BLOCK) > 0) {
          print line
          if (line == "") { last_emitted_blank = 1 } else { last_emitted_blank = 0 }
        }
        close(BLOCK)
        seen_block = 1
      }
      # Whether first or duplicate, suppress original opener line and following
      # body until matching closer.
      in_block = 1
      next
    }
    if (in_block == 1) {
      if ($0 == CLOSER) {
        in_block = 0
      }
      next
    }
    # Outside any block: pass through verbatim.
    print
    if ($0 == "") { last_emitted_blank = 1 } else { last_emitted_blank = 0 }
  }
  END {
    if (seen_block == 0) {
      if (last_emitted_blank == 0) {
        print ""
      }
      while ((getline line < BLOCK) > 0) {
        print line
      }
      close(BLOCK)
    }
    # If we entered a block but file ended before the closer (truncated/
    # malformed), the canonical block is already emitted at the position of
    # the opener — nothing further to do.
  }
' "$TARGET" > "$REWRITE_TMP"
awk_rc=$?

if [ "$awk_rc" -ne 0 ]; then
  rm -f "$BLOCK_TMP" "$REWRITE_TMP"
  echo "FAIL: awk rewrite exited $awk_rc" >&2
  exit 1
fi

mv "$REWRITE_TMP" "$TARGET"
mv_rc=$?
rm -f "$BLOCK_TMP"
if [ "$mv_rc" -ne 0 ]; then
  echo "FAIL: mv to $TARGET exited $mv_rc" >&2
  exit 1
fi

echo "wrote=$TARGET created=0"
exit 0
