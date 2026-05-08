#!/usr/bin/env bash
# scripts/diagnostics/wiki-stubs-fresh.sh -- staleness gate for wiki stubs.
#
# Regenerates wiki stubs + mkdocs.yml against the current .orchestrator/
# canonical artifacts and reports whether the committed outputs are stale.
# Intended primary use: pages.yml pre-build gate. Without this gate, an
# orchestrator:plan-phase re-plan that renames a canonical artifact (e.g.
# T03-foo-PLAN.md -> T03-bar-PLAN.md) silently breaks `mkdocs build` with a
# cryptic include-markdown error and the GitHub Pages deploy never runs.
#
# Failure mode after this gate: actionable "STALE: <files>" message naming
# exactly which committed outputs need refresh + the verbatim regen command.
#
# Usage:
#   bash scripts/diagnostics/wiki-stubs-fresh.sh [--root <dir>] [--restore]
#                                                [--help]
#
#   --root <dir>  Project root. Default: invocation working directory.
#   --restore     After diff, restore wiki/docs + wiki/mkdocs.yml to their
#                 pre-run state. Side-effect-free invocation; useful for
#                 local checks where the operator does not want the regen
#                 mutations to leak into their working tree. Default: no
#                 restore (CI-friendly; operator can `git checkout` to revert).
#   --help        Print this usage block and exit 0.
#
# Exit codes:
#   0  -- no drift; wiki stubs + mkdocs.yml match the canonical .orchestrator/.
#   1  -- drift detected; STALE: lines enumerate which outputs need refresh.
#   2  -- usage error or regenerator failure.
#
# Bash 3.2 compatible. Single-script-file shape.

set -u

print_help() {
  sed -n '2,32p' "$0"
}

# ----- Argument parsing --------------------------------------------------------

ROOT_DIR=""
RESTORE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      shift
      ROOT_DIR="${1:-}"
      ;;
    --restore)
      RESTORE=1
      ;;
    --help|-h)
      print_help
      exit 0
      ;;
    *)
      printf 'ERROR: unknown flag: %s\n' "$1" >&2
      exit 2
      ;;
  esac
  if [ $# -gt 0 ]; then
    shift
  fi
done

if [ -z "$ROOT_DIR" ]; then
  ROOT_DIR="$(pwd)"
fi

if [ ! -d "$ROOT_DIR" ]; then
  printf 'ERROR: --root not a directory: %s\n' "$ROOT_DIR" >&2
  exit 2
fi

DOCS="$ROOT_DIR/wiki/docs"
MKDOCS="$ROOT_DIR/wiki/mkdocs.yml"
STUB_GEN="$ROOT_DIR/scripts/wiki/wiki-generate-stubs.sh"
NAV_GEN="$ROOT_DIR/scripts/wiki/wiki-generate-nav.sh"

if [ ! -d "$DOCS" ]; then
  printf 'wiki-stubs-fresh: wiki/docs not found at %s -- nothing to check (exit 0)\n' "$DOCS"
  exit 0
fi

if [ ! -f "$STUB_GEN" ]; then
  printf 'ERROR: stub generator not found at %s\n' "$STUB_GEN" >&2
  exit 2
fi

if [ ! -f "$NAV_GEN" ]; then
  printf 'ERROR: nav generator not found at %s\n' "$NAV_GEN" >&2
  exit 2
fi

# ----- Snapshot current state -------------------------------------------------
# Always snapshot, even when --restore is unset; a future failure path may
# need to surface the prior state for debugging, and the cost is one cp -R
# of a small directory (<1MB on typical projects).

TMP_PFX="/tmp/wiki-stubs-fresh.$$"
DOCS_BEFORE="${TMP_PFX}.docs.before"
MKDOCS_BEFORE="${TMP_PFX}.mkdocs.before.yml"
trap 'rm -rf "$DOCS_BEFORE" "$MKDOCS_BEFORE" "${TMP_PFX}.diff" 2>/dev/null' EXIT INT TERM

cp -R "$DOCS" "$DOCS_BEFORE" 2>/dev/null || {
  printf 'ERROR: failed to snapshot %s\n' "$DOCS" >&2
  exit 2
}

if [ -f "$MKDOCS" ]; then
  cp "$MKDOCS" "$MKDOCS_BEFORE" 2>/dev/null || {
    printf 'ERROR: failed to snapshot %s\n' "$MKDOCS" >&2
    exit 2
  }
fi

# ----- Regenerate -------------------------------------------------------------
# Run both generators silently. Failure of either is a hard error -- the
# operator must fix the upstream regen before staleness can be assessed.

REGEN_LOG="${TMP_PFX}.regen.log"
if ! bash "$STUB_GEN" --root "$ROOT_DIR" >"$REGEN_LOG" 2>&1; then
  printf 'ERROR: wiki-generate-stubs.sh failed:\n' >&2
  cat "$REGEN_LOG" >&2
  rm -f "$REGEN_LOG"
  exit 2
fi
if ! bash "$NAV_GEN" --root "$ROOT_DIR" >"$REGEN_LOG" 2>&1; then
  printf 'ERROR: wiki-generate-nav.sh failed:\n' >&2
  cat "$REGEN_LOG" >&2
  rm -f "$REGEN_LOG"
  exit 2
fi
rm -f "$REGEN_LOG"

# ----- Diff -------------------------------------------------------------------

DRIFT=0
STALE_LIST="${TMP_PFX}.stale"
: > "$STALE_LIST"

# wiki/docs/: enumerate all files where regen produced different content
# (or where files were added/removed). diff -rq prints one line per
# differing file in the form:
#   Files <a> and <b> differ
#   Only in <dir>: <basename>
# We map both forms to a relative path for the STALE: enumeration.
diff -rq "$DOCS_BEFORE" "$DOCS" 2>/dev/null > "${TMP_PFX}.diff" || true
if [ -s "${TMP_PFX}.diff" ]; then
  DRIFT=1
  awk -v before="$DOCS_BEFORE" -v after="$DOCS" '
    /^Files / {
      # "Files <a> and <b> differ" -- emit the AFTER path (committed copy)
      # so the operator sees the path that needs the regen content.
      n = split($0, parts, " ")
      # token 4 is the AFTER path (Files <a> and <b> differ)
      print parts[4]
      next
    }
    /^Only in / {
      # "Only in <dir>: <basename>" -- emit <dir>/<basename>.
      sub(/^Only in /, "", $0)
      colon = index($0, ": ")
      if (colon > 0) {
        d = substr($0, 1, colon - 1)
        b = substr($0, colon + 2)
        print d "/" b
      }
    }
  ' "${TMP_PFX}.diff" >> "$STALE_LIST"
fi
rm -f "${TMP_PFX}.diff"

# wiki/mkdocs.yml
if [ -f "$MKDOCS_BEFORE" ] && [ -f "$MKDOCS" ]; then
  if ! diff -q "$MKDOCS_BEFORE" "$MKDOCS" >/dev/null 2>&1; then
    DRIFT=1
    printf '%s\n' "$MKDOCS" >> "$STALE_LIST"
  fi
elif [ -f "$MKDOCS" ] && [ ! -f "$MKDOCS_BEFORE" ]; then
  DRIFT=1
  printf '%s (newly generated)\n' "$MKDOCS" >> "$STALE_LIST"
fi

# ----- Restore (optional) -----------------------------------------------------

if [ "$RESTORE" -eq 1 ]; then
  rm -rf "$DOCS"
  cp -R "$DOCS_BEFORE" "$DOCS" 2>/dev/null || {
    printf 'ERROR: failed to restore %s from snapshot %s; manual recovery required\n' \
      "$DOCS" "$DOCS_BEFORE" >&2
    exit 2
  }
  if [ -f "$MKDOCS_BEFORE" ]; then
    cp "$MKDOCS_BEFORE" "$MKDOCS" 2>/dev/null || {
      printf 'ERROR: failed to restore %s from snapshot %s; manual recovery required\n' \
        "$MKDOCS" "$MKDOCS_BEFORE" >&2
      exit 2
    }
  fi
fi

# ----- Report -----------------------------------------------------------------

if [ "$DRIFT" -eq 0 ]; then
  printf 'wiki-stubs-fresh: PASS (no drift between .orchestrator/ canonical artifacts and wiki/docs + wiki/mkdocs.yml)\n'
  exit 0
fi

printf 'wiki-stubs-fresh: FAIL -- wiki stubs are stale relative to .orchestrator/ canonical artifacts\n' >&2
printf '\n' >&2
LC_ALL=C sort -u "$STALE_LIST" | while IFS= read -r _stale; do
  [ -n "$_stale" ] || continue
  printf 'STALE: %s\n' "$_stale" >&2
done
printf '\n' >&2
printf 'Fix: run the regenerators and commit the updated outputs:\n' >&2
printf '  bash scripts/wiki/wiki-generate-stubs.sh\n' >&2
printf '  bash scripts/wiki/wiki-generate-nav.sh\n' >&2
if [ "$RESTORE" -eq 1 ]; then
  printf '\n' >&2
  printf 'Note: --restore was specified; wiki/docs + wiki/mkdocs.yml have been\n' >&2
  printf '      restored to their pre-run state. The regen output above describes\n' >&2
  printf '      what the regen WOULD HAVE produced.\n' >&2
fi
exit 1
