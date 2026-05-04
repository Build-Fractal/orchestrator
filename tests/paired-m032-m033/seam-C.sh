#!/usr/bin/env bash
# tests/paired-m032-m033/seam-C.sh — paired-launch shared invariant per #Q-B Seam-C.
#
# wiki/glossary.md format invariant. Both M032 (path owner via T03) and M033
# (primary writer via grilling-shell) treat this as a shared contract:
#
#   * file exists at wiki/glossary.md at the orchestrator root
#   * >= 3 ### TERM headings present
#   * heading list is alphabetized at file scope
#   * each heading has a one-line definition body within 2 lines
#   * at-most-two-line elaboration: <= 4 non-empty body lines per heading
#     (1 definition + 2 elaboration + 1 separator slack)
#
# Bash 3.2 compatible (MEM001).

set -eu

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
PROJECT_ROOT="$( cd "$PROJECT_ROOT/.." && pwd )"
cd "$PROJECT_ROOT"

G="wiki/glossary.md"
[ -f "$G" ] || { echo "FAIL: Seam-C $G missing at orchestrator root"; exit 1; }

# Format invariant: >= 3 ### TERM headings present
HC="$(grep -c '^### ' "$G")"
[ "$HC" -ge 3 ] || { echo "FAIL: Seam-C $G needs >= 3 ### TERM entries; got $HC"; exit 1; }

# Alphabetized at file scope
TERMS_TMP="$(mktemp)"
SORTED_TMP="$(mktemp)"
trap 'rm -f "$TERMS_TMP" "$SORTED_TMP"' EXIT
grep '^### ' "$G" | sed 's/^### //' > "$TERMS_TMP"
sort "$TERMS_TMP" > "$SORTED_TMP"
diff -q "$TERMS_TMP" "$SORTED_TMP" >/dev/null || { echo "FAIL: Seam-C entries not alphabetized"; exit 1; }

# One-line definition under each heading (within 2 lines after the heading)
awk '
  /^### / {
    if (h && nonempty == 0) {
      print "FAIL: Seam-C heading \"" t "\" has no definition body within 2 lines"
      exit 1
    }
    h = NR; t = substr($0, 5); nonempty = 0; next
  }
  h && NR <= h + 2 && NF > 0 { nonempty++ }
  END {
    if (h && nonempty == 0) {
      print "FAIL: Seam-C heading \"" t "\" has no definition body within 2 lines"
      exit 1
    }
  }
' "$G" || exit 1

# At-most-two-line elaboration: <= 4 non-empty body lines per heading
awk '
  /^### / {
    if (term != "" && nonempty > 4) {
      print "FAIL: Seam-C term \"" term "\" has " nonempty " non-empty body lines (max 4)"
      exit 1
    }
    term = substr($0, 5)
    nonempty = 0
    next
  }
  NF > 0 { nonempty++ }
  END {
    if (term != "" && nonempty > 4) {
      print "FAIL: Seam-C term \"" term "\" has " nonempty " non-empty body lines (max 4)"
      exit 1
    }
  }
' "$G" || exit 1

echo "PASS: Seam-C wiki/glossary.md format invariant"
exit 0
