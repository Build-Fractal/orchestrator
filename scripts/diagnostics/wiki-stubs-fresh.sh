#!/usr/bin/env bash
# scripts/diagnostics/wiki-stubs-fresh.sh -- M035/P00/T03 staleness gate.
#
# Layer 1 of the wiki-stub-drift paper-cut (see
# .orchestrator/proposals/papercut-wiki-stub-drift.md). Compares committed
# wiki state under <root>/wiki/ against a freshly-regenerated copy emitted by
# scripts/wiki/wiki-generate-stubs.sh + scripts/wiki/wiki-generate-nav.sh,
# without mutating the committed tree.
#
# Without this gate, an orchestrator:plan-phase re-plan that renames a
# canonical artifact (e.g. T03-foo-PLAN.md -> T03-bar-PLAN.md) silently
# breaks `mkdocs build` with a cryptic include-markdown error and the
# GitHub Pages deploy never runs. This diagnostic catches the drift loudly
# *before* mkdocs runs.
#
# Usage:
#   bash scripts/diagnostics/wiki-stubs-fresh.sh [--root <project-dir>]
#
# Default root: $PWD.
#
# Exit codes (contract -- downstream callers branch on these):
#   0  fresh (or no wiki present -- informational skip)
#   1  environment failure (generators missing, can't write tmp, regen fails)
#   2  drift detected
#
# Bash 3.2 compatible -- no `<(...)`, no `mapfile`, no `${var^^}`,
# no `&>`, no compound chains > 2. AP-009 shape-guard friendly.

set -u

print_help() {
  sed -n '2,28p' "$0"
}

# ----- Argument parsing ------------------------------------------------------

ROOT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      shift
      if [ $# -eq 0 ]; then
        printf 'FAIL: --root requires a path argument\n' >&2
        exit 1
      fi
      ROOT="$1"
      shift
      ;;
    --help|-h)
      print_help
      exit 0
      ;;
    *)
      printf 'FAIL: unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$ROOT" ]; then
  ROOT="$PWD"
fi

if [ ! -d "$ROOT" ]; then
  printf 'FAIL: --root does not exist: %s\n' "$ROOT" >&2
  exit 1
fi

ROOT=$(cd "$ROOT" && pwd)

# ----- Absent-wiki short-circuit --------------------------------------------
# Not every consumer project ships a wiki. Treat absence as a soft pass so
# the diagnostic can be invoked unconditionally from CI workflows.
if [ ! -d "$ROOT/wiki/docs" ] || [ ! -f "$ROOT/wiki/mkdocs.yml" ]; then
  printf 'INFO: no wiki present, skipping freshness check (root=%s)\n' "$ROOT"
  exit 0
fi

# ----- Environment preflight ------------------------------------------------
STUB_GEN="$ROOT/scripts/wiki/wiki-generate-stubs.sh"
NAV_GEN="$ROOT/scripts/wiki/wiki-generate-nav.sh"
DECORATE="$ROOT/scripts/wiki/wiki-decorate-build.py"

if [ ! -f "$STUB_GEN" ]; then
  printf 'FAIL: wiki-generate-stubs.sh not found at %s\n' "$STUB_GEN" >&2
  exit 1
fi
if [ ! -f "$NAV_GEN" ]; then
  printf 'FAIL: wiki-generate-nav.sh not found at %s\n' "$NAV_GEN" >&2
  exit 1
fi
# wiki-decorate-build.py is optional for older trees that haven't picked
# up the readability rollout yet -- skip the decorate step in that case.
DECORATE_PRESENT=0
if [ -f "$DECORATE" ]; then
  DECORATE_PRESENT=1
fi
if ! command -v diff >/dev/null 2>&1; then
  printf 'FAIL: diff(1) not on PATH\n' >&2
  exit 1
fi

# ----- Stage tmp tree --------------------------------------------------------
# The stub generator writes into <root>/wiki/docs (rooted at the resolved
# absolute --root path). To compare without mutating the live tree, stage
# the source-of-truth directories the generators read from (.orchestrator/,
# scripts/, wiki/) into a tmp dir and run the generators with --root <tmp>.
# The generators emit fresh state into <tmp>/wiki/, which we diff against
# <root>/wiki/.
TMP_PARENT=$(mktemp -d 2>/dev/null)
if [ -z "$TMP_PARENT" ] || [ ! -d "$TMP_PARENT" ]; then
  printf 'FAIL: mktemp -d failed\n' >&2
  exit 1
fi
TMP_ROOT="$TMP_PARENT/proj"
mkdir -p "$TMP_ROOT" 2>/dev/null
GEN_LOG="$TMP_PARENT/genlog"
DOCS_DIFF="$TMP_PARENT/docsdiff"
NAV_DIFF="$TMP_PARENT/navdiff"
trap 'rm -rf "$TMP_PARENT" 2>/dev/null' EXIT INT TERM

# Stage the directories the generators + scanner consume + the wiki/ tree
# they overwrite. Source-of-truth dirs (read by wiki-scan-sources.sh):
#   .orchestrator/   -- specs, plans, knowledge graph, proposals, decisions
#   knowledge/       -- top-level MEM* knowledge entries (M012/P02/T01)
#   scripts/         -- generators + scanner themselves
#   templates/       -- index-cards templates consumed by stub gen
#   wiki/            -- comparison baseline + regen target
# Use cp -R for bash 3.2 portability.
for _dir in ".orchestrator" "knowledge" "scripts" "templates" "wiki"; do
  if [ -d "$ROOT/$_dir" ]; then
    if ! cp -R "$ROOT/$_dir" "$TMP_ROOT/$_dir" 2>/dev/null; then
      printf 'FAIL: could not stage %s into %s\n' "$_dir" "$TMP_ROOT" >&2
      exit 1
    fi
  fi
done

# Stage common repo-root sibling files best-effort. The scanners may read
# CHANGELOG.md / README.md / constitution.md when present.
for _f in "CHANGELOG.md" "README.md" "constitution.md"; do
  if [ -f "$ROOT/$_f" ]; then
    cp "$ROOT/$_f" "$TMP_ROOT/$_f" 2>/dev/null || true
  fi
done

# ----- Regenerate fresh stubs + nav into tmp -------------------------------
if ! bash "$STUB_GEN" --root "$TMP_ROOT" >"$GEN_LOG" 2>&1; then
  printf 'FAIL: wiki-generate-stubs.sh exited non-zero against tmp tree\n' >&2
  printf '%s\n' '----- generator output -----' >&2
  cat "$GEN_LOG" >&2
  exit 1
fi

# Decorate-build (wiki readability rollout) runs between stubs and nav.
# It mutates each stub to include from wiki/.staged/ and emits decorated
# copies of every .orchestrator/**.md include source. The committed stub
# form points at .staged/, so freshness must run decorate before diffing
# or every PR will trip drift. Gated on $DECORATE_PRESENT for cross-version
# safety -- consumer projects on pre-readability-rollout runtimes keep
# passing freshness without the decorator installed.
if [ "$DECORATE_PRESENT" -eq 1 ]; then
  if ! python3 "$DECORATE" --root "$TMP_ROOT" --force >"$GEN_LOG" 2>&1; then
    printf 'FAIL: wiki-decorate-build.py exited non-zero against tmp tree\n' >&2
    printf '%s\n' '----- decorator output -----' >&2
    cat "$GEN_LOG" >&2
    exit 1
  fi
fi

if ! bash "$NAV_GEN" --root "$TMP_ROOT" >"$GEN_LOG" 2>&1; then
  printf 'FAIL: wiki-generate-nav.sh exited non-zero against tmp tree\n' >&2
  printf '%s\n' '----- generator output -----' >&2
  cat "$GEN_LOG" >&2
  exit 1
fi

# ----- Diff committed vs freshly regenerated -------------------------------
# Two diffs:
#   (a) wiki/docs/ tree (recursive) -- every auto-generated stub must match.
#   (b) wiki/mkdocs.yml -- the auto-nav region is regenerated; the rest is
#       hand-authored and untouched by the generator. A whole-file diff
#       PASSes when state is fresh because the generators preserve the
#       hand-authored prefix verbatim (see wiki-generate-nav.sh region split
#       at MARKER_AUTO_START / MARKER_AUTO_END).
DRIFT=0
DOCS_DRIFT=0
NAV_DRIFT=0

if ! diff -ruN "$ROOT/wiki/docs" "$TMP_ROOT/wiki/docs" >"$DOCS_DIFF" 2>&1; then
  DRIFT=1
  DOCS_DRIFT=1
fi
if ! diff -uN "$ROOT/wiki/mkdocs.yml" "$TMP_ROOT/wiki/mkdocs.yml" >"$NAV_DIFF" 2>&1; then
  DRIFT=1
  NAV_DRIFT=1
fi

# ----- Count stubs (informational) -----------------------------------------
STUB_COUNT=$(find "$ROOT/wiki/docs" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')

if [ "$DRIFT" -eq 0 ]; then
  printf 'PASS: wiki-stubs-fresh (no drift; %s stubs + nav verified against committed state)\n' "$STUB_COUNT"
  exit 0
fi

# ----- Drift path -----------------------------------------------------------
printf 'DRIFT: wiki-stubs-fresh detected divergence between committed wiki/ and freshly-regenerated output\n' >&2
printf '\n' >&2

# Enumerate drifted files in wiki/docs/ as STALE: <relpath> lines so the
# operator sees the path-set rather than diff bytes. Use diff -rq for the
# enumeration (separate from the unified -u diff used for human inspection).
if [ "$DOCS_DRIFT" -eq 1 ]; then
  STALE_LIST="${TMP_ROOT}.stale"
  : > "$STALE_LIST"
  diff -rq "$ROOT/wiki/docs" "$TMP_ROOT/wiki/docs" 2>/dev/null > "${STALE_LIST}.raw" || true
  # Map "Files <a> and <b> differ" + "Only in <dir>: <basename>" to a single
  # path per line, anchored to the committed (root) tree where possible.
  awk -v root_docs="$ROOT/wiki/docs" -v tmp_docs="$TMP_ROOT/wiki/docs" '
    /^Files / {
      # token 4 is the AFTER path; emit it raw.
      n = split($0, parts, " ")
      print parts[4]
      next
    }
    /^Only in / {
      sub(/^Only in /, "", $0)
      colon = index($0, ": ")
      if (colon > 0) {
        d = substr($0, 1, colon - 1)
        b = substr($0, colon + 2)
        print d "/" b
      }
    }
  ' "${STALE_LIST}.raw" > "$STALE_LIST"
  rm -f "${STALE_LIST}.raw"

  printf '%s\n' '----- wiki/docs/ drift (committed -> fresh) -----' >&2
  if [ -s "$STALE_LIST" ]; then
    LC_ALL=C sort -u "$STALE_LIST" | while IFS= read -r _stale; do
      if [ -n "$_stale" ]; then
        printf 'STALE: %s\n' "$_stale" >&2
      fi
    done
    printf '\n' >&2
  fi
  # Also surface the unified diff (capped at 200 lines for CI readability).
  head -n 200 "$DOCS_DIFF" >&2
  _docs_lines=$(wc -l < "$DOCS_DIFF" | tr -d ' ')
  if [ "$_docs_lines" -gt 200 ]; then
    printf '... (%s more diff lines truncated)\n' "$_docs_lines" >&2
  fi
  printf '\n' >&2
fi

if [ "$NAV_DRIFT" -eq 1 ]; then
  printf '%s\n' '----- wiki/mkdocs.yml drift (committed -> fresh) -----' >&2
  printf 'STALE: %s\n' "$ROOT/wiki/mkdocs.yml" >&2
  cat "$NAV_DIFF" >&2
  printf '\n' >&2
fi

printf 'To regen, run from %s:\n' "$ROOT" >&2
printf '    bash scripts/wiki/wiki-generate-stubs.sh && bash scripts/wiki/wiki-generate-nav.sh && git add wiki/\n' >&2
printf 'Then commit the regen and re-run this diagnostic.\n' >&2

exit 2
