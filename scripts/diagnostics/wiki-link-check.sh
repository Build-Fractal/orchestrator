#!/usr/bin/env bash
# scripts/diagnostics/wiki-link-check.sh -- M012/P02 built-site link walker.
#
# Walks an already-built MkDocs site directory, extracts every <a href="...">
# link from every .html file, classifies each link as in-scope / out-of-scope /
# broken, and exits non-zero on any broken in-scope link.
#
# Usage:
#   bash scripts/diagnostics/wiki-link-check.sh [--site <dir>] [--root <dir>]
#                                               [--strict] [--help]
#
#   --site <dir>  Built site directory. Default: "wiki/site" relative to --root.
#   --root <dir>  Project root. Default: invocation working directory.
#   --strict      Treat out-of-scope escape as broken (stricter than default).
#   --help        Print this usage block and exit 0.
#
# Exit codes:
#   0  -- zero broken in-scope links.
#   1  -- one or more broken in-scope links.
#   2  -- usage error (no site dir, no .html files, unreadable path).
#
# In-scope: any relative link that resolves to an existing file inside the
#           site tree, plus in-page anchor-only links (#foo) whose anchor
#           exists in the source page.
# Out-of-scope: http(s), mailto, tel, ftp; paths that escape the site root.
# Broken: relative link whose resolved path is missing, or anchor link whose
#         target id/name is absent from the target page.
#
# Bash 3.2 compatible. MEM004 carve-out: internal pipes/awk/sed permitted.
# Single-script-file shape (AD-19) -- callable directly as the Check command.

set -u

print_help() {
  # Render the usage block from this script's own header (lines 2..30).
  sed -n '2,30p' "$0"
}

# ----- Argument parsing --------------------------------------------------------

SITE_DIR=""
ROOT_DIR=""
STRICT=0

while [ $# -gt 0 ]; do
  case "$1" in
    --site)
      shift
      SITE_DIR="${1:-}"
      ;;
    --root)
      shift
      ROOT_DIR="${1:-}"
      ;;
    --strict)
      STRICT=1
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
if [ -z "$SITE_DIR" ]; then
  SITE_DIR="$ROOT_DIR/wiki/site"
fi

if [ ! -d "$SITE_DIR" ]; then
  printf 'ERROR: site directory not found: %s\n' "$SITE_DIR" >&2
  printf '       Build the site first: (cd wiki && mkdocs build)\n' >&2
  exit 2
fi

if [ ! -r "$SITE_DIR" ]; then
  printf 'ERROR: site directory not readable: %s\n' "$SITE_DIR" >&2
  exit 2
fi

# ----- Path normalization -----------------------------------------------------

normalize_path() {
  # Collapse "./" and "../" against a raw path string. No realpath.
  # Split on "/", walk into a positional-parameter stack.
  local raw="$1"
  local IFS=/
  # shellcheck disable=SC2086
  set -- $raw
  local out=""
  local seg
  for seg in "$@"; do
    case "$seg" in
      ''|'.')
        continue
        ;;
      '..')
        # Pop one segment from out.
        case "$out" in
          */*) out="${out%/*}" ;;
          *)   out="" ;;
        esac
        ;;
      *)
        if [ -z "$out" ]; then
          out="$seg"
        else
          out="$out/$seg"
        fi
        ;;
    esac
  done
  case "$raw" in
    /*) printf '/%s\n' "$out" ;;
    *)  printf '%s\n' "$out" ;;
  esac
}

# ----- Enumerate HTML files ---------------------------------------------------

HTML_LIST="/tmp/wiki-link-check.html.$$"
LINKS_FILE="${HTML_LIST}.links"
FINDINGS_FILE="${HTML_LIST}.findings"
trap 'rm -f "$HTML_LIST" "$LINKS_FILE" "$FINDINGS_FILE" 2>/dev/null' EXIT

find "$SITE_DIR" -type f -name '*.html' | LC_ALL=C sort > "$HTML_LIST"

PAGE_COUNT=0
while IFS= read -r _pg; do
  if [ -n "$_pg" ]; then
    PAGE_COUNT=$((PAGE_COUNT + 1))
  fi
done < "$HTML_LIST"

if [ "$PAGE_COUNT" -eq 0 ]; then
  printf 'ERROR: no .html files found under %s\n' "$SITE_DIR" >&2
  exit 2
fi

# ----- Extract links per page -------------------------------------------------

: > "$LINKS_FILE"
while IFS= read -r page; do
  if [ -z "$page" ]; then
    continue
  fi
  # Relative/absolute links: href="..." excluding leading "#" or "?".
  grep -oE 'href="[^"#?][^"]*"' "$page" 2>/dev/null \
    | sed -e 's/^href="//' -e 's/"$//' \
    | while IFS= read -r href; do
        if [ -n "$href" ]; then
          printf '%s|%s\n' "$page" "$href" >> "$LINKS_FILE"
        fi
      done
  # In-page anchor-only hrefs (#foo).
  grep -oE 'href="#[^"]+"' "$page" 2>/dev/null \
    | sed -e 's/^href="//' -e 's/"$//' \
    | while IFS= read -r href; do
        if [ -n "$href" ]; then
          printf '%s|%s\n' "$page" "$href" >> "$LINKS_FILE"
        fi
      done
done < "$HTML_LIST"

# ----- Classify links ---------------------------------------------------------

: > "$FINDINGS_FILE"
BROKEN=0
OUT_OF_SCOPE=0
OK_LINKS=0

SITE_PREFIX="${SITE_DIR%/}/"

while IFS='|' read -r page href; do
  if [ -z "$page" ]; then
    continue
  fi
  if [ -z "$href" ]; then
    continue
  fi

  # External URL?
  case "$href" in
    http://*|https://*|mailto:*|tel:*|ftp://*)
      printf 'OUT-OF-SCOPE: %s -> %s [external]\n' "$page" "$href" \
        >> "$FINDINGS_FILE"
      OUT_OF_SCOPE=$((OUT_OF_SCOPE + 1))
      continue
      ;;
  esac

  # In-page anchor only?
  case "$href" in
    '#'*)
      anchor="${href#\#}"
      if grep -qE "(id=\"${anchor}\"|name=\"${anchor}\")" "$page"; then
        OK_LINKS=$((OK_LINKS + 1))
      else
        printf 'BROKEN: %s -> %s [in-page anchor missing]\n' "$page" "$href" \
          >> "$FINDINGS_FILE"
        BROKEN=$((BROKEN + 1))
      fi
      continue
      ;;
  esac

  # Relative path. Strip fragment for resolution; keep for anchor check.
  path_only="${href%%\#*}"
  frag=""
  case "$href" in
    *'#'*) frag="${href#*\#}" ;;
  esac
  # Strip query string.
  path_only="${path_only%%\?*}"

  # If all that remains is empty (e.g. href="?q" or href="#"), treat as ok
  # (same-page reference with no fragment target to verify).
  if [ -z "$path_only" ]; then
    OK_LINKS=$((OK_LINKS + 1))
    continue
  fi

  # Resolve against the source page's directory.
  src_dir=$(dirname "$page")
  raw="$src_dir/$path_only"

  resolved=$(normalize_path "$raw")

  # Escape check -- must stay under SITE_DIR.
  case "$resolved" in
    "$SITE_DIR"|"$SITE_PREFIX"*)
      : # inside site -- continue
      ;;
    *)
      reason="escapes site root"
      if [ "$STRICT" -eq 1 ]; then
        printf 'BROKEN: %s -> %s [%s]\n' "$page" "$href" "$reason" \
          >> "$FINDINGS_FILE"
        BROKEN=$((BROKEN + 1))
      else
        printf 'OUT-OF-SCOPE: %s -> %s [%s]\n' "$page" "$href" "$reason" \
          >> "$FINDINGS_FILE"
        OUT_OF_SCOPE=$((OUT_OF_SCOPE + 1))
      fi
      continue
      ;;
  esac

  # Directory -> index.html.
  if [ -d "$resolved" ]; then
    resolved="${resolved%/}/index.html"
  fi

  if [ ! -f "$resolved" ]; then
    printf 'BROKEN: %s -> %s [file missing: %s]\n' "$page" "$href" "$resolved" \
      >> "$FINDINGS_FILE"
    BROKEN=$((BROKEN + 1))
    continue
  fi

  # If we have a fragment, verify anchor exists in target page.
  if [ -n "$frag" ]; then
    if ! grep -qE "(id=\"${frag}\"|name=\"${frag}\")" "$resolved"; then
      printf 'BROKEN: %s -> %s [target anchor missing: #%s]\n' \
        "$page" "$href" "$frag" >> "$FINDINGS_FILE"
      BROKEN=$((BROKEN + 1))
      continue
    fi
  fi

  OK_LINKS=$((OK_LINKS + 1))
done < "$LINKS_FILE"

# ----- Emit findings and summary ---------------------------------------------

if [ -s "$FINDINGS_FILE" ]; then
  LC_ALL=C sort -u "$FINDINGS_FILE"
fi

if [ "$BROKEN" -gt 0 ]; then
  printf 'FAIL: %d broken in-scope link(s) across %d source pages (%d ok, %d out-of-scope)\n' \
    "$BROKEN" "$PAGE_COUNT" "$OK_LINKS" "$OUT_OF_SCOPE"
  exit 1
fi

printf 'PASS: 0 broken in-scope links (%d pages, %d in-scope ok, %d out-of-scope)\n' \
  "$PAGE_COUNT" "$OK_LINKS" "$OUT_OF_SCOPE"
exit 0
