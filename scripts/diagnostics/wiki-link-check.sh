#!/usr/bin/env bash
# scripts/diagnostics/wiki-link-check.sh -- M012/P02 built-site link walker.
#
# Walks an already-built MkDocs site directory, extracts every <a href="...">
# link from every .html file, classifies each link as in-scope / out-of-scope /
# broken, and exits non-zero on any broken in-scope link.
#
# Usage:
#   bash scripts/diagnostics/wiki-link-check.sh [--site <dir>] [--root <dir>]
#                                               [--strict] [--verbose] [--help]
#
#   --site <dir>  Built site directory. Default: "wiki/site" relative to --root.
#   --root <dir>  Project root. Default: invocation working directory.
#   --strict      Treat out-of-scope escape as broken (stricter than default).
#   --verbose     Disable OUT-OF-SCOPE diagnostic-budget collapse (FR-22a /
#                 M037/P02/T04). Default: collapse repeats above THRESHOLD=5.
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
#
# Performance: classification runs in two awk passes (one over all HTML to
# extract links + anchors, one over the extracted records to classify using
# pre-built file/dir indexes). Completes in < 1 second on a 1300-page site;
# the prior per-link `grep -qE` implementation took 30+ minutes.

set -u

print_help() {
  # Render the usage block from this script's own header.
  sed -n '2,32p' "$0"
}

# ----- Argument parsing --------------------------------------------------------

SITE_DIR=""
ROOT_DIR=""
STRICT=0
VERBOSE=0

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
    --verbose)
      VERBOSE=1
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

# ----- Build site indexes -----------------------------------------------------

TMP_PFX="/tmp/wiki-link-check.$$"
HTML_LIST="${TMP_PFX}.html"
FILES_IDX="${TMP_PFX}.files"
DIRS_IDX="${TMP_PFX}.dirs"
LA_FILE="${TMP_PFX}.la"
ANCHORS_FILE="${TMP_PFX}.anchors"
LINKS_FILE="${TMP_PFX}.links"
FINDINGS_FILE="${TMP_PFX}.findings"
trap 'rm -f "$HTML_LIST" "$FILES_IDX" "$DIRS_IDX" "$LA_FILE" "$ANCHORS_FILE" "$LINKS_FILE" "$FINDINGS_FILE" "${TMP_PFX}.sorted" "${TMP_PFX}.oos" "${TMP_PFX}.non_oos" 2>/dev/null' EXIT INT TERM

find "$SITE_DIR" -type f -name '*.html' 2>/dev/null | LC_ALL=C sort > "$HTML_LIST"
find "$SITE_DIR" -type f 2>/dev/null > "$FILES_IDX"
find "$SITE_DIR" -type d 2>/dev/null > "$DIRS_IDX"

PAGE_COUNT=$(wc -l < "$HTML_LIST" | awk '{print $1}')

if [ "$PAGE_COUNT" -eq 0 ]; then
  printf 'ERROR: no .html files found under %s\n' "$SITE_DIR" >&2
  exit 2
fi

# ----- Phase 1: extract links + anchors via one awk pass over all HTML -------
# Emits two record types on stdout, tab-separated:
#   L<TAB>page<TAB>href
#   A<TAB>page<TAB>anchor-id
# Uses FNR==1 to detect filename transitions (BSD awk compatible). xargs
# may split the file list into multiple awk invocations on very large trees;
# that is safe here because stage 1 is stateless across files.

NCPU=$(sysctl -n hw.ncpu 2>/dev/null || printf '4')
[ "$NCPU" -gt 1 ] || NCPU=1

# Parallel extraction: each worker writes to its own temp file (keyed by the
# worker bash's PID) so block-buffered awk output never interleaves across
# workers. Final concatenation reassembles the complete LA stream.
BATCH_DIR="${TMP_PFX}.batches.d"
mkdir -p "$BATCH_DIR"
export BATCH_DIR
xargs -n 150 -P "$NCPU" bash -c '
  awk '"'"'
    FNR == 1 { page = FILENAME; in_article = 0 }
    /<article[ >]/ { in_article = 1 }
    /<\/article>/  { in_article = 0; next }
    !in_article { next }
    {
      s = $0
      while (match(s, /<a [^>]*href="[^"]*"/)) {
        piece = substr(s, RSTART, RLENGTH)
        hp = index(piece, "href=\"")
        val = substr(piece, hp + 6, length(piece) - hp - 6)
        print "L\t" page "\t" val
        s = substr(s, RSTART + RLENGTH)
      }
      t = $0
      while (match(t, /(id|name)="[^"]*"/)) {
        attr = substr(t, RSTART, RLENGTH)
        eq_pos = index(attr, "=\"")
        val = substr(attr, eq_pos + 2, length(attr) - eq_pos - 2)
        print "A\t" page "\t" val
        t = substr(t, RSTART + RLENGTH)
      }
    }
  '"'"' "$@" > "$BATCH_DIR/batch.$$"
' bash < "$HTML_LIST"

cat "$BATCH_DIR"/batch.* > "$LA_FILE" 2>/dev/null
rm -rf "$BATCH_DIR"

# Split into per-type + dedupe: nav/TOC are re-rendered on every page so the
# same (page_dir, href) link is emitted 1000+ times; sorting + uniq kills the
# duplicate work before classification. Dedupe key for L is the full record
# (page|href) — same page + same href is one logical link. For anchors we
# dedupe on (page|anchor) too.
LC_ALL=C awk -F'\t' '$1 == "A" {print $2 "\t" $3}' "$LA_FILE" \
  | LC_ALL=C sort -u > "$ANCHORS_FILE"
LC_ALL=C awk -F'\t' '$1 == "L" {print $2 "\t" $3}' "$LA_FILE" \
  | LC_ALL=C sort -u > "$LINKS_FILE"
rm -f "$LA_FILE"

# ----- Phase 2: classify ------------------------------------------------------
# One awk invocation loads files + dirs + anchors, then classifies every link.
# Normalizes relative paths in-awk (no realpath dep).

awk -F'\t' \
    -v site="$SITE_DIR" \
    -v strict="$STRICT" \
    -v files_idx="$FILES_IDX" \
    -v dirs_idx="$DIRS_IDX" \
    -v anchors_file="$ANCHORS_FILE" '
function normalize(raw,    parts, n, i, top, seg, out, stack, leading) {
  leading = (substr(raw, 1, 1) == "/") ? 1 : 0
  n = split(raw, parts, "/")
  top = 0
  for (i = 1; i <= n; i++) {
    seg = parts[i]
    if (seg == "" || seg == ".") continue
    if (seg == "..") {
      if (top > 0) delete stack[top--]
      continue
    }
    stack[++top] = seg
  }
  out = ""
  for (i = 1; i <= top; i++) {
    out = (i == 1 ? stack[i] : out "/" stack[i])
  }
  if (leading) out = "/" out
  return out
}
function dirname_of(p,    slash) {
  slash = length(p)
  while (slash > 0 && substr(p, slash, 1) != "/") slash--
  if (slash <= 1) return ""
  return substr(p, 1, slash - 1)
}
function strip_fragment(h,    n) {
  n = index(h, "#")
  if (n > 0) return substr(h, 1, n - 1)
  return h
}
function fragment_of(h,    n) {
  n = index(h, "#")
  if (n > 0) return substr(h, n + 1)
  return ""
}
function strip_query(h,    n) {
  n = index(h, "?")
  if (n > 0) return substr(h, 1, n - 1)
  return h
}
BEGIN {
  site_prefix = site "/"
  while ((getline line < files_idx) > 0) files_set[line] = 1
  close(files_idx)
  while ((getline line < dirs_idx) > 0) dirs_set[line] = 1
  close(dirs_idx)
  while ((getline line < anchors_file) > 0) {
    tab = index(line, "\t")
    anchors[substr(line, 1, tab - 1) "|" substr(line, tab + 1)] = 1
  }
  close(anchors_file)
  ok = 0; broken = 0; out_of_scope = 0
}
{
  page = $1; href = $2
  if (page == "" || href == "") next

  # External?
  if (href ~ /^https?:/ || href ~ /^mailto:/ || href ~ /^tel:/ || href ~ /^ftp:/) {
    print "OUT-OF-SCOPE: " page " -> " href " [external]"
    out_of_scope++
    next
  }

  # Absolute path (starts with /): these are site_url-rooted URLs intended for
  # the deployed site (e.g. the 404.html page uses /<base>/... refs). They
  # resolve correctly on the deployed URL but do not correspond to filesystem
  # paths under the build directory, so treat as out-of-scope.
  if (substr(href, 1, 1) == "/") {
    print "OUT-OF-SCOPE: " page " -> " href " [absolute-path]"
    out_of_scope++
    next
  }

  # In-page anchor only?
  if (substr(href, 1, 1) == "#") {
    a = strip_query(substr(href, 2))
    if ((page "|" a) in anchors) ok++
    else { print "BROKEN: " page " -> " href " [in-page anchor missing]"; broken++ }
    next
  }

  # Strip fragment + query.
  path_only = strip_fragment(href)
  frag = fragment_of(href)
  path_only = strip_query(path_only)
  # Fragment may still carry query.
  frag = strip_query(frag)

  if (path_only == "") { ok++; next }

  src_dir = dirname_of(page)
  raw = (src_dir == "" ? path_only : src_dir "/" path_only)
  resolved = normalize(raw)

  # Escape check.
  if (resolved != site && index(resolved, site_prefix) != 1) {
    reason = "escapes site root"
    if (strict == 1) {
      print "BROKEN: " page " -> " href " [" reason "]"
      broken++
    } else {
      print "OUT-OF-SCOPE: " page " -> " href " [" reason "]"
      out_of_scope++
    }
    next
  }

  # Directory -> index.html.
  if (resolved in dirs_set) {
    resolved = resolved "/index.html"
  }

  if (!(resolved in files_set)) {
    print "BROKEN: " page " -> " href " [file missing: " resolved "]"
    broken++
    next
  }

  # Fragment on cross-page link.
  if (frag != "") {
    if ((resolved "|" frag) in anchors) ok++
    else { print "BROKEN: " page " -> " href " [target anchor missing: #" frag "]"; broken++ }
    next
  }

  ok++
}
END {
  print "SUMMARY\t" ok "\t" broken "\t" out_of_scope > "/dev/stderr"
}
' "$LINKS_FILE" > "$FINDINGS_FILE" 2> "${TMP_PFX}.summary"

# ----- Emit findings and summary ---------------------------------------------

SUMMARY_LINE=$(cat "${TMP_PFX}.summary" 2>/dev/null | head -n 1)
rm -f "${TMP_PFX}.summary" 2>/dev/null

OK_LINKS=$(printf '%s' "$SUMMARY_LINE" | awk -F'\t' '{print $2}')
BROKEN=$(printf '%s' "$SUMMARY_LINE" | awk -F'\t' '{print $3}')
OUT_OF_SCOPE=$(printf '%s' "$SUMMARY_LINE" | awk -F'\t' '{print $4}')

[ -n "$OK_LINKS" ] || OK_LINKS=0
[ -n "$BROKEN" ] || BROKEN=0
[ -n "$OUT_OF_SCOPE" ] || OUT_OF_SCOPE=0

# ---- FR-22a (M037/P02/T04) — OUT-OF-SCOPE diagnostic-budget collapse -------
# Default: collapse repeats above THRESHOLD=5 occurrences per unique target
# to a single summary line. --verbose disables collapsing for debugging. The
# zero-OUT-OF-SCOPE case must produce no summary line (silent-on-empty).
#
# Implementation: split sorted-unique findings into OUT-OF-SCOPE vs other,
# emit non-OUT-OF-SCOPE verbatim (sorted-unique), then either emit OOS lines
# verbatim (--verbose) or post-process via awk to collapse high-fanout repeats
# above THRESHOLD and bound small-fanout per-occurrence emission to BUDGET=5
# unique targets. No process substitution per AD-19; matches surrounding
# temp-file + plain-pipe shape.
if [ -s "$FINDINGS_FILE" ]; then
  OOS_TMP="${TMP_PFX}.oos"
  NON_OOS_TMP="${TMP_PFX}.non_oos"
  LC_ALL=C sort -u "$FINDINGS_FILE" > "${TMP_PFX}.sorted"
  grep '^OUT-OF-SCOPE:' "${TMP_PFX}.sorted" > "$OOS_TMP" 2>/dev/null || true
  grep -v '^OUT-OF-SCOPE:' "${TMP_PFX}.sorted" > "$NON_OOS_TMP" 2>/dev/null || true
  if [ -s "$NON_OOS_TMP" ]; then
    cat "$NON_OOS_TMP"
  fi
  if [ -s "$OOS_TMP" ]; then
    if [ "$VERBOSE" -eq 1 ]; then
      cat "$OOS_TMP"
    else
      awk '
        BEGIN { THRESHOLD = 5; BUDGET = 5; n_unique = 0 }
        # Match: OUT-OF-SCOPE: <page> -> <href> [<reason>...]
        # Extract href (token after "->", stop at "[<reason>") and reason
        # (everything from the first "[..." token to end-of-line).
        /^OUT-OF-SCOPE:/ {
          href = ""
          reason = ""
          for (i = 4; i <= NF; i++) {
            if ($i == "->") continue
            if (substr($i, 1, 1) == "[") {
              reason = $i
              for (j = i + 1; j <= NF; j++) reason = reason " " $j
              break
            }
            href = (href == "") ? $i : href " " $i
          }
          if (!(href in count)) {
            count[href] = 0
            order[++n_unique] = href
            reason_for[href] = reason
            lines[href] = ""
          }
          count[href]++
          lines[href] = lines[href] $0 "\n"
        }
        END {
          budget_used = 0
          for (k = 1; k <= n_unique; k++) {
            href = order[k]
            if (count[href] >= THRESHOLD) {
              # High-fanout: always collapse
              printf "OUT-OF-SCOPE: %d pages -> %s %s (collapsed)\n", \
                count[href], href, reason_for[href]
            } else if (budget_used < BUDGET) {
              # Small-fanout within budget: emit per-occurrence verbatim
              printf "%s", lines[href]
              budget_used++
            } else {
              # Small-fanout beyond budget: collapse with budget marker
              printf "OUT-OF-SCOPE: %d pages -> %s %s (collapsed, budget)\n", \
                count[href], href, reason_for[href]
            }
          }
        }
      ' "$OOS_TMP"
    fi
  fi
  rm -f "${TMP_PFX}.sorted" "$OOS_TMP" "$NON_OOS_TMP" 2>/dev/null || true
fi

if [ "$BROKEN" -gt 0 ]; then
  printf 'FAIL: %d broken in-scope link(s) across %d source pages (%d ok, %d out-of-scope)\n' \
    "$BROKEN" "$PAGE_COUNT" "$OK_LINKS" "$OUT_OF_SCOPE"
  exit 1
fi

printf 'PASS: 0 broken in-scope links (%d pages, %d in-scope ok, %d out-of-scope)\n' \
  "$PAGE_COUNT" "$OK_LINKS" "$OUT_OF_SCOPE"
exit 0
