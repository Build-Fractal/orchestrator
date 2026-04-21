#!/usr/bin/env bash
# scripts/wiki/wiki-generate-nav.sh — M012/P01 nav block generator.
#
# Consumes scripts/wiki/wiki-scan-sources.sh output and writes a MkDocs
# nav: block into wiki/mkdocs.yml between these two marker lines:
#   # >>> M012-P01 nav (auto-generated — do not edit by hand)
#   # <<< M012-P01 nav end
#
# On first run, the markers are appended at the end of wiki/mkdocs.yml
# with the nav block between them. On subsequent runs, the content
# between the existing markers is replaced atomically.
#
# Nav order (top level, fixed):
#   Home, Constitution, Decisions, Knowledge, Milestone Summary,
#   Milestones (expandable per-milestone), Archive (labeled).
#
# Scanner category enum it understands:
#   top:constitution, top:decisions, top:knowledge, top:milestone-summary,
#   milestone:<M###>, archive:<M###>
#
# Nav leaf paths are computed from the category + relative orchestrator path
# using the same mapping as wiki-generate-stubs.sh:
#   top:constitution      -> constitution.md
#   top:decisions         -> decisions.md
#   top:knowledge         -> knowledge.md
#   top:milestone-summary -> milestone-summary.md
#   milestone:M### + rel  -> <rel>                (rel already "milestones/M###/...")
#   archive:M### + rel    -> <rel>                (rel already "archive/M###/...")
#
# Usage: bash scripts/wiki/wiki-generate-nav.sh [--dry-run] [--root PROJECT_ROOT]
# Exit 0 on success; 1 on scanner failure; 2 on config write error.
# Bash 3.2 compatible — no `declare -A`, no `mapfile`, no `${var^^}`,
# no process substitution, no `&>`.

set -u

# ---- argument parsing -------------------------------------------------------
DRY_RUN=0
ROOT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --root)
      shift
      if [ $# -eq 0 ]; then
        printf 'ERROR: --root requires a path argument\n' >&2
        exit 2
      fi
      ROOT="$1"
      shift
      ;;
    --help|-h)
      sed -n '2,30p' "$0"
      exit 0
      ;;
    *)
      printf 'ERROR: unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

# ---- resolve PROJECT_ROOT ---------------------------------------------------
if [ -z "$ROOT" ]; then
  SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
  ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
fi

if [ ! -d "$ROOT" ]; then
  printf 'ERROR: PROJECT_ROOT does not exist: %s\n' "$ROOT" >&2
  exit 2
fi

CONFIG="$ROOT/wiki/mkdocs.yml"
SCANNER="$ROOT/scripts/wiki/wiki-scan-sources.sh"
DOCS="$ROOT/wiki/docs"

if [ ! -f "$CONFIG" ]; then
  printf 'ERROR: wiki/mkdocs.yml not found: %s (run T01 first)\n' "$CONFIG" >&2
  exit 2
fi

if [ ! -f "$SCANNER" ]; then
  printf 'ERROR: scanner not found: %s (run T02 first)\n' "$SCANNER" >&2
  exit 1
fi

if [ ! -d "$DOCS" ]; then
  printf 'ERROR: wiki/docs not found: %s (run T03 first)\n' "$DOCS" >&2
  exit 2
fi

# ---- markers ---------------------------------------------------------------
MARKER_START="# >>> M012-P01 nav (auto-generated — do not edit by hand)"
MARKER_END="# <<< M012-P01 nav end"

# ---- temp files / cleanup --------------------------------------------------
SCAN_OUT="/tmp/wiki-nav-scan-$$.list"
NAV_BODY="/tmp/wiki-nav-body-$$.yml"
TMP_PRE="/tmp/wiki-nav-pre-$$.yml"
TMP_POST="/tmp/wiki-nav-post-$$.yml"
TMP_FINAL="/tmp/wiki-nav-final-$$.yml"
TMP_IDS="/tmp/wiki-nav-ids-$$.list"
TMP_PHASE="/tmp/wiki-nav-phase-$$.list"
trap 'rm -f "$SCAN_OUT" "$NAV_BODY" "$TMP_PRE" "$TMP_POST" "$TMP_FINAL" "$TMP_IDS" "$TMP_PHASE" /tmp/wiki-nav-kn-patterns-$$.list /tmp/wiki-nav-kn-conventions-$$.list /tmp/wiki-nav-kn-lessons-$$.list' EXIT INT TERM

# ---- helpers ---------------------------------------------------------------

# yaml_escape_title <title> -> prints either a bare or double-quoted YAML string.
# If the title contains any of : # " ' [ ] { } & * ! | > % @ ` or starts with
# a reserved token, wrap in double quotes and escape internal " and \.
yaml_escape_title() {
  _t="$1"
  case "$_t" in
    *:*|*\#*|*\"*|*\'*|*\[*|*\]*|*\{*|*\}*|*\&*|*\**|*\!*|*\|*|*\>*|*%*|*@*|*\`*|" "*|*" ")
      _e=$(printf '%s' "$_t" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
      printf '"%s"' "$_e"
      ;;
    ""|"null"|"true"|"false"|"yes"|"no"|"on"|"off"|"Null"|"True"|"False"|"Yes"|"No"|"On"|"Off"|"NULL"|"TRUE"|"FALSE"|"YES"|"NO"|"ON"|"OFF"|"~")
      _e=$(printf '%s' "$_t" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
      printf '"%s"' "$_e"
      ;;
    *)
      # Also quote if starts with digit-only, hyphen, or question mark for safety.
      case "$_t" in
        -*|\?*|0*|1*|2*|3*|4*|5*|6*|7*|8*|9*)
          _e=$(printf '%s' "$_t" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
          printf '"%s"' "$_e"
          ;;
        *)
          printf '%s' "$_t"
          ;;
      esac
      ;;
  esac
}

# indent <level> -> prints 2*level spaces
indent() {
  _lvl="$1"
  _out=""
  _i=0
  while [ "$_i" -lt "$_lvl" ]; do
    _out="${_out}  "
    _i=$((_i + 1))
  done
  printf '%s' "$_out"
}

# emit_leaf <level> <label> <path-under-docs>
emit_leaf() {
  _lvl="$1"
  _label="$2"
  _path="$3"
  _q=$(yaml_escape_title "$_label")
  printf '%s- %s: %s\n' "$(indent "$_lvl")" "$_q" "$_path" >> "$NAV_BODY"
}

# emit_group <level> <label>
# Group headers are of form "  - M001:" — the label itself is quoted only if
# needed. A group is followed by nested children at level+1.
emit_group() {
  _lvl="$1"
  _label="$2"
  _q=$(yaml_escape_title "$_label")
  printf '%s- %s:\n' "$(indent "$_lvl")" "$_q" >> "$NAV_BODY"
}

# milestone_artifact_label <basename>
# Strip the M###- prefix and title-case the rest. Examples:
#   M011-CONTEXT.md     -> "Context"
#   M011-EVALUATION.md  -> "Evaluation"
#   M011-ROADMAP.md     -> "Roadmap"
#   M011-SUMMARY.md     -> "Summary"
# Fallback (no prefix match): use the basename minus .md.
milestone_artifact_label() {
  _b="$1"
  _core=$(printf '%s' "$_b" | sed 's/\.md$//')
  case "$_core" in
    M[0-9][0-9][0-9]-*)
      _rest=$(printf '%s' "$_core" | sed 's/^M[0-9][0-9][0-9]-//')
      # Title case: first letter upper, rest lower.
      _first=$(printf '%s' "$_rest" | cut -c1 | tr 'a-z' 'A-Z')
      _tail=$(printf '%s' "$_rest" | cut -c2- | tr 'A-Z' 'a-z')
      printf '%s%s' "$_first" "$_tail"
      ;;
    *)
      printf '%s' "$_core"
      ;;
  esac
}

# phase_artifact_label <basename>
# Strip the P##- prefix and title-case the rest. Examples:
#   P01-PLAN.md    -> "Plan"
#   P01-SUMMARY.md -> "Summary"
phase_artifact_label() {
  _b="$1"
  _core=$(printf '%s' "$_b" | sed 's/\.md$//')
  case "$_core" in
    P[0-9][0-9]-*)
      _rest=$(printf '%s' "$_core" | sed 's/^P[0-9][0-9]-//')
      _first=$(printf '%s' "$_rest" | cut -c1 | tr 'a-z' 'A-Z')
      _tail=$(printf '%s' "$_rest" | cut -c2- | tr 'A-Z' 'a-z')
      printf '%s%s' "$_first" "$_tail"
      ;;
    *)
      printf '%s' "$_core"
      ;;
  esac
}

# task_artifact_label <basename>
# "T01-PLAN.md"    -> "T01 Plan"
# "T01-SUMMARY.md" -> "T01 Summary"
# "T01-PAYLOAD.md" -> "T01 Payload"
task_artifact_label() {
  _b="$1"
  _core=$(printf '%s' "$_b" | sed 's/\.md$//')
  case "$_core" in
    T[0-9][0-9]-*)
      _tid=$(printf '%s' "$_core" | sed 's/^\(T[0-9][0-9]\)-.*/\1/')
      _rest=$(printf '%s' "$_core" | sed 's/^T[0-9][0-9]-//')
      _first=$(printf '%s' "$_rest" | cut -c1 | tr 'a-z' 'A-Z')
      _tail=$(printf '%s' "$_rest" | cut -c2- | tr 'A-Z' 'a-z')
      printf '%s %s%s' "$_tid" "$_first" "$_tail"
      ;;
    *)
      printf '%s' "$_core"
      ;;
  esac
}

# ---- collect scanner output ------------------------------------------------
if ! bash "$SCANNER" --root "$ROOT" > "$SCAN_OUT" 2>/dev/null; then
  printf 'ERROR: scanner failed\n' >&2
  exit 1
fi

# ---- assemble nav body -----------------------------------------------------
: > "$NAV_BODY"

printf '%s\n' "$MARKER_START" >> "$NAV_BODY"
printf 'nav:\n' >> "$NAV_BODY"

# Top-level fixed entries.
emit_leaf 1 "Home" "index.md"

# Top-level artifact entries are present iff the scanner emits them. Track via
# a simple flag so we only add the leaf if the corresponding scanner record
# actually appeared (keeps the nav strictly in-sync with what T03 produced).
HAS_CONSTITUTION=0
HAS_DECISIONS=0
HAS_KNOWLEDGE=0
HAS_MILSUM=0

# First pass: discover which top-level entries exist, and which milestone/archive
# IDs appear (in first-seen order — scanner output is lexical). Write the
# ordered ID lists to TMP_IDS (one per line, prefixed with M: or A:).
: > "$TMP_IDS"
while IFS='|' read -r CAT REL TITLE; do
  [ -n "$CAT" ] || continue
  case "$CAT" in
    top:constitution)      HAS_CONSTITUTION=1 ;;
    top:decisions)         HAS_DECISIONS=1 ;;
    top:knowledge)         HAS_KNOWLEDGE=1 ;;
    top:milestone-summary) HAS_MILSUM=1 ;;
    milestone:*)
      _mid=$(printf '%s' "$CAT" | sed 's/^milestone://')
      printf 'M:%s\n' "$_mid" >> "$TMP_IDS"
      ;;
    archive:*)
      _mid=$(printf '%s' "$CAT" | sed 's/^archive://')
      printf 'A:%s\n' "$_mid" >> "$TMP_IDS"
      ;;
  esac
done < "$SCAN_OUT"

# Unique-sort the IDs so each milestone/archive group appears once; sort keeps
# M-prefix first, then A-prefix (lexical sort), and lexical order within each
# kind matches scanner order. This preserves determinism.
sort -u "$TMP_IDS" > "${TMP_IDS}.sorted"
mv "${TMP_IDS}.sorted" "$TMP_IDS"

# Emit top-level leaves.
if [ "$HAS_CONSTITUTION" -eq 1 ]; then
  emit_leaf 1 "Constitution" "constitution.md"
fi
if [ "$HAS_DECISIONS" -eq 1 ]; then
  emit_leaf 1 "Decisions" "decisions.md"
fi
if [ "$HAS_KNOWLEDGE" -eq 1 ]; then
  emit_leaf 1 "Knowledge" "knowledge.md"
fi

# ---- Knowledge Entries subtree (M012/P02/T02) ------------------------------
# Inserted between the consolidated "Knowledge" top-level entry and the
# "Milestone Summary" entry. Emitted only when the scanner observed at least
# one knowledge:<sub> record. Three category subgroups — Patterns,
# Conventions, Lessons — each led by its section index (Overview) and
# followed by one leaf per MEM entry in lexical order.
HAS_ANY_KNOWLEDGE=0
if grep -q '^knowledge:' "$SCAN_OUT"; then
  HAS_ANY_KNOWLEDGE=1
fi

if [ "$HAS_ANY_KNOWLEDGE" -eq 1 ]; then
  emit_group 1 "Knowledge Entries"
  emit_leaf 2 "Overview" "knowledge/index.md"
  # Iterate the three subcategories in fixed order; skip any that have no
  # records so the nav stays in sync with what the scanner observed.
  for _sub in patterns conventions lessons; do
    case "$_sub" in
      patterns)    _sublabel="Patterns" ;;
      conventions) _sublabel="Conventions" ;;
      lessons)     _sublabel="Lessons" ;;
    esac
    TMP_KN="/tmp/wiki-nav-kn-${_sub}-$$.list"
    awk -F'|' -v c="knowledge:${_sub}" '
      $1 == c { print $2 "|" $3 }
    ' "$SCAN_OUT" | sort > "$TMP_KN"
    if [ ! -s "$TMP_KN" ]; then
      rm -f "$TMP_KN"
      continue
    fi
    emit_group 2 "$_sublabel"
    emit_leaf 3 "Overview" "knowledge/${_sub}/index.md"
    while IFS='|' read -r KREL KTITLE; do
      [ -n "$KREL" ] || continue
      _kbase=$(basename "$KREL" .md)
      _kpath="knowledge/${_sub}/${_kbase}.md"
      emit_leaf 3 "$_kbase" "$_kpath"
    done < "$TMP_KN"
    rm -f "$TMP_KN"
  done
fi

if [ "$HAS_MILSUM" -eq 1 ]; then
  emit_leaf 1 "Milestone Summary" "milestone-summary.md"
fi

# ---- Milestones group ------------------------------------------------------
# Determine whether any milestone IDs exist. If yes, emit the group with
# Overview + per-milestone subgroups.

HAS_ANY_MILESTONE=0
HAS_ANY_ARCHIVE=0
grep -q '^M:' "$TMP_IDS" && HAS_ANY_MILESTONE=1
grep -q '^A:' "$TMP_IDS" && HAS_ANY_ARCHIVE=1

if [ "$HAS_ANY_MILESTONE" -eq 1 ]; then
  emit_group 1 "Milestones"
  emit_leaf 2 "Overview" "milestones/index.md"

  # For each milestone ID (sorted lexically by the earlier sort -u):
  grep '^M:' "$TMP_IDS" | sed 's/^M://' | while IFS= read -r MID; do
    [ -n "$MID" ] || continue
    emit_group 2 "$MID"
    emit_leaf 3 "Overview" "milestones/${MID}/index.md"

    # Milestone-level artifacts: records with CAT=milestone:MID and REL of the
    # form "milestones/MID/<basename>.md" (no further slashes beyond 2).
    awk -F'|' -v c="milestone:${MID}" -v m="${MID}" '
      $1 == c {
        rel = $2
        # rel starts with "milestones/MID/"; strip that.
        prefix = "milestones/" m "/"
        if (index(rel, prefix) == 1) {
          tail = substr(rel, length(prefix) + 1)
          if (index(tail, "/") == 0) {
            print rel "|" $3
          }
        }
      }
    ' "$SCAN_OUT" | sort > "${TMP_PHASE}.ms"
    while IFS='|' read -r REL TITLE; do
      [ -n "$REL" ] || continue
      _b=$(basename "$REL")
      _label=$(milestone_artifact_label "$_b")
      emit_leaf 3 "$_label" "$REL"
    done < "${TMP_PHASE}.ms"
    rm -f "${TMP_PHASE}.ms"

    # Phase IDs under this milestone, sorted.
    awk -F'|' -v c="milestone:${MID}" -v m="${MID}" '
      $1 == c {
        rel = $2
        pre = "milestones/" m "/phases/"
        if (index(rel, pre) == 1) {
          tail = substr(rel, length(pre) + 1)
          # tail = "P##/..."; extract first segment
          n = index(tail, "/")
          if (n > 0) {
            print substr(tail, 1, n - 1)
          }
        }
      }
    ' "$SCAN_OUT" | sort -u > "${TMP_PHASE}.pids"
    while IFS= read -r PID; do
      [ -n "$PID" ] || continue
      emit_group 3 "$PID"
      emit_leaf 4 "Overview" "milestones/${MID}/phases/${PID}/index.md"

      # Phase-level artifacts: CAT=milestone:MID with REL =
      # milestones/MID/phases/PID/<basename>.md (no further slashes after PID/).
      awk -F'|' -v c="milestone:${MID}" -v m="${MID}" -v p="${PID}" '
        $1 == c {
          rel = $2
          pre = "milestones/" m "/phases/" p "/"
          if (index(rel, pre) == 1) {
            tail = substr(rel, length(pre) + 1)
            if (index(tail, "/") == 0) {
              print rel "|" $3
            }
          }
        }
      ' "$SCAN_OUT" | sort > "${TMP_PHASE}.ps"
      while IFS='|' read -r REL TITLE; do
        [ -n "$REL" ] || continue
        _b=$(basename "$REL")
        _label=$(phase_artifact_label "$_b")
        emit_leaf 4 "$_label" "$REL"
      done < "${TMP_PHASE}.ps"
      rm -f "${TMP_PHASE}.ps"

      # Task-level artifacts under this phase.
      awk -F'|' -v c="milestone:${MID}" -v m="${MID}" -v p="${PID}" '
        $1 == c {
          rel = $2
          pre = "milestones/" m "/phases/" p "/tasks/"
          if (index(rel, pre) == 1) {
            tail = substr(rel, length(pre) + 1)
            if (index(tail, "/") == 0) {
              print rel "|" $3
            }
          }
        }
      ' "$SCAN_OUT" | sort > "${TMP_PHASE}.ts"
      while IFS='|' read -r REL TITLE; do
        [ -n "$REL" ] || continue
        _b=$(basename "$REL")
        _label=$(task_artifact_label "$_b")
        emit_leaf 4 "$_label" "$REL"
      done < "${TMP_PHASE}.ts"
      rm -f "${TMP_PHASE}.ts"

      # Phase-level extras: records under milestones/MID/phases/PID/<subdir>/...
      # that are not tasks/ and not direct P##-*.md. Examples: fixtures/*.md.
      # Emit each as a leaf under the phase group with a path-tail label.
      awk -F'|' -v c="milestone:${MID}" -v m="${MID}" -v p="${PID}" '
        $1 == c {
          rel = $2
          pre = "milestones/" m "/phases/" p "/"
          if (index(rel, pre) == 1) {
            tail = substr(rel, length(pre) + 1)
            # Skip direct phase files (handled above) and tasks/ (handled above).
            if (index(tail, "/") == 0) next
            if (index(tail, "tasks/") == 1) next
            print rel "|" $3 "|" tail
          }
        }
      ' "$SCAN_OUT" | sort > "${TMP_PHASE}.pex"
      while IFS='|' read -r REL TITLE TAIL; do
        [ -n "$REL" ] || continue
        # Label: replace slashes with " / " and strip .md, keep readable.
        _lab=$(printf '%s' "$TAIL" | sed 's/\.md$//' | sed 's|/| / |g')
        emit_leaf 4 "$_lab" "$REL"
      done < "${TMP_PHASE}.pex"
      rm -f "${TMP_PHASE}.pex"
    done < "${TMP_PHASE}.pids"
    rm -f "${TMP_PHASE}.pids"

    # Milestone-level extras: records under milestones/MID/<subdir>/... that
    # are NOT phases/ and NOT a direct MID-*.md file. Examples: M008/archive/P01/*.
    # Emit each as a leaf under the milestone group with a path-tail label.
    awk -F'|' -v c="milestone:${MID}" -v m="${MID}" '
      $1 == c {
        rel = $2
        pre = "milestones/" m "/"
        if (index(rel, pre) == 1) {
          tail = substr(rel, length(pre) + 1)
          if (index(tail, "/") == 0) next          # milestone-top, handled
          if (index(tail, "phases/") == 1) next    # phases subtree, handled
          print rel "|" $3 "|" tail
        }
      }
    ' "$SCAN_OUT" | sort > "${TMP_PHASE}.mex"
    while IFS='|' read -r REL TITLE TAIL; do
      [ -n "$REL" ] || continue
      _lab=$(printf '%s' "$TAIL" | sed 's/\.md$//' | sed 's|/| / |g')
      emit_leaf 3 "$_lab" "$REL"
    done < "${TMP_PHASE}.mex"
    rm -f "${TMP_PHASE}.mex"
  done
fi

# ---- Archive group ---------------------------------------------------------
if [ "$HAS_ANY_ARCHIVE" -eq 1 ]; then
  emit_group 1 "Archive"
  emit_leaf 2 "Overview" "archive/index.md"

  grep '^A:' "$TMP_IDS" | sed 's/^A://' | while IFS= read -r MID; do
    [ -n "$MID" ] || continue
    emit_group 2 "$MID"
    emit_leaf 3 "Overview" "archive/${MID}/index.md"

    awk -F'|' -v c="archive:${MID}" -v m="${MID}" '
      $1 == c {
        rel = $2
        prefix = "archive/" m "/"
        if (index(rel, prefix) == 1) {
          tail = substr(rel, length(prefix) + 1)
          if (index(tail, "/") == 0) {
            print rel "|" $3
          }
        }
      }
    ' "$SCAN_OUT" | sort > "${TMP_PHASE}.ams"
    while IFS='|' read -r REL TITLE; do
      [ -n "$REL" ] || continue
      _b=$(basename "$REL")
      _label=$(milestone_artifact_label "$_b")
      emit_leaf 3 "$_label" "$REL"
    done < "${TMP_PHASE}.ams"
    rm -f "${TMP_PHASE}.ams"

    awk -F'|' -v c="archive:${MID}" -v m="${MID}" '
      $1 == c {
        rel = $2
        pre = "archive/" m "/phases/"
        if (index(rel, pre) == 1) {
          tail = substr(rel, length(pre) + 1)
          n = index(tail, "/")
          if (n > 0) {
            print substr(tail, 1, n - 1)
          }
        }
      }
    ' "$SCAN_OUT" | sort -u > "${TMP_PHASE}.apids"
    while IFS= read -r PID; do
      [ -n "$PID" ] || continue
      emit_group 3 "$PID"
      emit_leaf 4 "Overview" "archive/${MID}/phases/${PID}/index.md"

      awk -F'|' -v c="archive:${MID}" -v m="${MID}" -v p="${PID}" '
        $1 == c {
          rel = $2
          pre = "archive/" m "/phases/" p "/"
          if (index(rel, pre) == 1) {
            tail = substr(rel, length(pre) + 1)
            if (index(tail, "/") == 0) {
              print rel "|" $3
            }
          }
        }
      ' "$SCAN_OUT" | sort > "${TMP_PHASE}.aps"
      while IFS='|' read -r REL TITLE; do
        [ -n "$REL" ] || continue
        _b=$(basename "$REL")
        _label=$(phase_artifact_label "$_b")
        emit_leaf 4 "$_label" "$REL"
      done < "${TMP_PHASE}.aps"
      rm -f "${TMP_PHASE}.aps"

      awk -F'|' -v c="archive:${MID}" -v m="${MID}" -v p="${PID}" '
        $1 == c {
          rel = $2
          pre = "archive/" m "/phases/" p "/tasks/"
          if (index(rel, pre) == 1) {
            tail = substr(rel, length(pre) + 1)
            if (index(tail, "/") == 0) {
              print rel "|" $3
            }
          }
        }
      ' "$SCAN_OUT" | sort > "${TMP_PHASE}.ats"
      while IFS='|' read -r REL TITLE; do
        [ -n "$REL" ] || continue
        _b=$(basename "$REL")
        _label=$(task_artifact_label "$_b")
        emit_leaf 4 "$_label" "$REL"
      done < "${TMP_PHASE}.ats"
      rm -f "${TMP_PHASE}.ats"

      # Archive phase extras (fixtures/, etc.).
      awk -F'|' -v c="archive:${MID}" -v m="${MID}" -v p="${PID}" '
        $1 == c {
          rel = $2
          pre = "archive/" m "/phases/" p "/"
          if (index(rel, pre) == 1) {
            tail = substr(rel, length(pre) + 1)
            if (index(tail, "/") == 0) next
            if (index(tail, "tasks/") == 1) next
            print rel "|" $3 "|" tail
          }
        }
      ' "$SCAN_OUT" | sort > "${TMP_PHASE}.apex"
      while IFS='|' read -r REL TITLE TAIL; do
        [ -n "$REL" ] || continue
        _lab=$(printf '%s' "$TAIL" | sed 's/\.md$//' | sed 's|/| / |g')
        emit_leaf 4 "$_lab" "$REL"
      done < "${TMP_PHASE}.apex"
      rm -f "${TMP_PHASE}.apex"
    done < "${TMP_PHASE}.apids"
    rm -f "${TMP_PHASE}.apids"

    # Archive milestone-level extras.
    awk -F'|' -v c="archive:${MID}" -v m="${MID}" '
      $1 == c {
        rel = $2
        pre = "archive/" m "/"
        if (index(rel, pre) == 1) {
          tail = substr(rel, length(pre) + 1)
          if (index(tail, "/") == 0) next
          if (index(tail, "phases/") == 1) next
          print rel "|" $3 "|" tail
        }
      }
    ' "$SCAN_OUT" | sort > "${TMP_PHASE}.amex"
    while IFS='|' read -r REL TITLE TAIL; do
      [ -n "$REL" ] || continue
      _lab=$(printf '%s' "$TAIL" | sed 's/\.md$//' | sed 's|/| / |g')
      emit_leaf 3 "$_lab" "$REL"
    done < "${TMP_PHASE}.amex"
    rm -f "${TMP_PHASE}.amex"
  done
fi

printf '%s\n' "$MARKER_END" >> "$NAV_BODY"

# ---- dry-run short-circuit -------------------------------------------------
if [ "$DRY_RUN" -eq 1 ]; then
  cat "$NAV_BODY"
  exit 0
fi

# ---- splice into wiki/mkdocs.yml via marker state machine ------------------
# If the start marker is absent, append a synthetic pair at EOF so the splice
# logic has something to replace. We use ensure-markers-then-splice so first
# run and subsequent runs converge on the same file shape.

if ! grep -qF "$MARKER_START" "$CONFIG"; then
  # Append markers with an empty block to make subsequent awk splitting clean.
  {
    printf '\n'
    printf '%s\n' "$MARKER_START"
    printf '%s\n' "$MARKER_END"
  } >> "$CONFIG"
fi

# Split the existing config into pre-marker and post-marker halves. The
# marker lines themselves are dropped here; the freshly assembled NAV_BODY
# already includes both marker lines, so concat = pre + NAV_BODY + post.
awk -v s="$MARKER_START" -v e="$MARKER_END" \
    -v pre="$TMP_PRE" -v post="$TMP_POST" '
  BEGIN { state = "pre" }
  {
    if (state == "pre") {
      if ($0 == s) { state = "in"; next }
      print > pre; next
    }
    if (state == "in") {
      if ($0 == e) { state = "post"; next }
      next
    }
    # state == "post"
    print > post
  }
' "$CONFIG"

# Guarantee the temp files exist (awk only creates them on write).
[ -f "$TMP_PRE" ] || : > "$TMP_PRE"
[ -f "$TMP_POST" ] || : > "$TMP_POST"

# Assemble final. Preserve exactly one trailing newline from pre, then the
# nav body (which ends with a newline), then post as-is.
cat "$TMP_PRE" > "$TMP_FINAL"
cat "$NAV_BODY" >> "$TMP_FINAL"
cat "$TMP_POST" >> "$TMP_FINAL"

# Atomic replace: mv within the same filesystem as $CONFIG.
CONFIG_DIR=$(dirname "$CONFIG")
STAGED="$CONFIG_DIR/.mkdocs.yml.staged.$$"
if ! cp "$TMP_FINAL" "$STAGED"; then
  printf 'ERROR: staging copy failed: %s\n' "$STAGED" >&2
  exit 2
fi
if ! mv "$STAGED" "$CONFIG"; then
  printf 'ERROR: atomic mv failed: %s -> %s\n' "$STAGED" "$CONFIG" >&2
  rm -f "$STAGED"
  exit 2
fi

# ---- summary ---------------------------------------------------------------
NAV_LINES=$(wc -l < "$NAV_BODY" | tr -d ' ')
MILESTONE_COUNT=$(grep -c '^M:' "$TMP_IDS" 2>/dev/null)
[ -z "$MILESTONE_COUNT" ] && MILESTONE_COUNT=0
ARCHIVE_COUNT=$(grep -c '^A:' "$TMP_IDS" 2>/dev/null)
[ -z "$ARCHIVE_COUNT" ] && ARCHIVE_COUNT=0
printf 'SUMMARY: wrote nav block (%s lines) with %s milestone(s) and %s archive(s)\n' \
  "$NAV_LINES" "$MILESTONE_COUNT" "$ARCHIVE_COUNT" >&2

exit 0
