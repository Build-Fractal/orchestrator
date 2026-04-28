#!/usr/bin/env bash
# scripts/wiki/wiki-generate-stubs.sh — M012/P01 stub generator.
#
# Reads scan output from scripts/wiki/wiki-scan-sources.sh and writes one
# thin include-plugin stub per in-scope .orchestrator/**.md artifact under
# wiki/docs/.
#
# Stubs are <= 25 lines each. Body content stays at .orchestrator/**.md
# (single source of truth, M012 AD-3). Stubs reference canonical paths via
# the mkdocs-include-markdown-plugin directive.
#
# Idempotent: safe to re-run. Removes existing auto-generated stubs before
# writing fresh ones. Never touches wiki/docs/index.md or wiki/docs/README.md.
#
# Usage: bash scripts/wiki/wiki-generate-stubs.sh [--dry-run] [--root PROJECT_ROOT]
# Exit 0 on success; 1 on scanner failure; 2 on write error.
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
      sed -n '2,22p' "$0"
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

DOCS="$ROOT/wiki/docs"
SCANNER="$ROOT/scripts/wiki/wiki-scan-sources.sh"

if [ ! -d "$DOCS" ]; then
  printf 'ERROR: wiki/docs not found: %s (run T01 first)\n' "$DOCS" >&2
  exit 2
fi

if [ ! -x "$SCANNER" ] && [ ! -f "$SCANNER" ]; then
  printf 'ERROR: scanner not found: %s (run T02 first)\n' "$SCANNER" >&2
  exit 1
fi

# ---- counters ---------------------------------------------------------------
STUBS_WRITTEN=0
INDEXES_WRITTEN=0
REMOVED=0

# ---- helpers ----------------------------------------------------------------

# count_slashes <string> -> prints integer count of '/' chars
count_slashes() {
  _s="$1"
  _n=$(printf '%s' "$_s" | tr -cd '/' | wc -c)
  # strip leading whitespace that wc may emit on macOS
  _n=$(printf '%s' "$_n" | tr -d ' ')
  printf '%s' "$_n"
}

# build_canonical <stub-rel-under-docs> <orch-rel-path> -> prints canonical ref
# canonical = (N+1) * "../" + ".orchestrator/" + orch-rel-path
# where N = number of '/' in stub-rel (each '/' = one nested dir under docs/)
# +1 gets us from docs/ up to wiki/, another from wiki/ up to repo root.
# Wait: from docs/X/Y/leaf.md, include plugin resolves relative to docs/.
# docs/ itself is at wiki/docs/. Canonical is at .orchestrator/<rel>.
# From docs/X/Y/leaf.md, to reach repo root we go up (N+2) times where N is
# the number of intermediate directories (= slashes in stub-rel). Wait, think
# again: stub-rel like "milestones/M002/M002-CONTEXT.md" has 2 slashes, so
# the file lives 2 dirs deep inside docs/. To get from the file's location
# to docs/ you go up 2; to get from docs/ to repo root you go up 2 more
# (docs -> wiki -> root). So total = N_slashes + 2.
#
# Example verify:
#   stub "constitution.md" (0 slashes) lives directly in docs/. From that file,
#   "../" reaches docs/'s parent (wiki/), "../../" reaches repo root.
#   So prefix = 0+2 = 2 "../" -> "../../.orchestrator/memory/constitution.md". OK.
#
#   stub "milestones/M002/M002-CONTEXT.md" (2 slashes). The file lives at
#   docs/milestones/M002/M002-CONTEXT.md. "../" -> docs/milestones/, "../../"
#   -> docs/, "../../../" -> wiki/, "../../../../" -> repo root.
#   prefix = 2+2 = 4 "../" -> "../../../../.orchestrator/milestones/M002/M002-CONTEXT.md". OK.
build_canonical() {
  _stub_rel="$1"
  _orch_rel="$2"
  _slash=$(count_slashes "$_stub_rel")
  _depth=$((_slash + 2))
  _prefix=""
  _i=0
  while [ "$_i" -lt "$_depth" ]; do
    _prefix="${_prefix}../"
    _i=$((_i + 1))
  done
  printf '%s.orchestrator/%s' "$_prefix" "$_orch_rel"
}

# build_canonical_repo_rel <stub-rel-under-docs> <repo-rel-path>
# Like build_canonical, but the canonical target lives at the repo root (not
# under .orchestrator/). Added in M012/P02/T02 for knowledge:<category> records
# whose canonical source is knowledge/<cat>/MEM###.md at the repo root.
build_canonical_repo_rel() {
  _stub_rel="$1"
  _repo_rel="$2"
  _slash=$(count_slashes "$_stub_rel")
  _depth=$((_slash + 2))
  _prefix=""
  _i=0
  while [ "$_i" -lt "$_depth" ]; do
    _prefix="${_prefix}../"
    _i=$((_i + 1))
  done
  printf '%s%s' "$_prefix" "$_repo_rel"
}

# map_record_to_stub_rel <category> <orch-rel>
# Prints the stub's path relative to wiki/docs/.
map_record_to_stub_rel() {
  _cat="$1"
  _rel="$2"
  case "$_cat" in
    top:constitution)      printf 'constitution.md' ;;
    top:decisions)         printf 'decisions.md' ;;
    top:knowledge)         printf 'knowledge.md' ;;
    top:milestone-summary) printf 'milestone-summary.md' ;;
    milestone:*)
      # orch-rel is of form "milestones/M###/...". Mirror directly.
      printf '%s' "$_rel"
      ;;
    archive:*)
      # orch-rel is of form "archive/M###/...". Mirror directly.
      printf '%s' "$_rel"
      ;;
    *)
      # Unknown category — fall back to orch-rel.
      printf '%s' "$_rel"
      ;;
  esac
}

# write_stub <target-abs-path> <canonical-path> <title> [<canonical-abs-path>]
# When <canonical-abs-path> is provided and the file begins with `---`, the
# include directive emits `start="\n---\n"` to skip past YAML frontmatter so
# the rendered body starts at the H1 instead of dumping the frontmatter as
# prose. Plugin's interpret_escapes resolves `\n` → newline (verified against
# mkdocs-include-markdown-plugin v7.1.2).
write_stub() {
  _target="$1"
  _canonical="$2"
  _title="$3"
  _canonical_abs="${4:-}"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'WOULD-WRITE: %s\n' "$_target" >&2
    STUBS_WRITTEN=$((STUBS_WRITTEN + 1))
    return 0
  fi
  _dir=$(dirname "$_target")
  if ! mkdir -p "$_dir"; then
    printf 'ERROR: mkdir failed: %s\n' "$_dir" >&2
    exit 2
  fi
  # Probe canonical for YAML frontmatter — first line exactly "---".
  # Skipped when caller didn't provide canonical_abs (back-compat).
  _has_fm=0
  if [ -n "$_canonical_abs" ] && [ -f "$_canonical_abs" ]; then
    _first=$(head -n 1 "$_canonical_abs" 2>/dev/null)
    if [ "$_first" = "---" ]; then
      _has_fm=1
    fi
  fi
  # Escape double-quotes in title to keep YAML valid.
  _title_esc=$(printf '%s' "$_title" | sed 's/"/\\"/g')
  {
    printf -- '---\n'
    printf 'title: "%s"\n' "$_title_esc"
    printf -- '---\n\n'
    printf '<!-- Auto-generated by scripts/wiki/wiki-generate-stubs.sh. Do not hand-edit.\n'
    printf '     Source of truth: %s (M012 AD-3). -->\n\n' "$_canonical"
    printf '{%%\n'
    printf '  include-markdown "%s"\n' "$_canonical"
    if [ "$_has_fm" -eq 1 ]; then
      printf '  start="\\n---\\n"\n'
    fi
    printf '  heading-offset=0\n'
    printf '  rewrite-relative-urls=true\n'
    printf '%%}\n'
  } > "$_target"
  if [ ! -f "$_target" ]; then
    printf 'ERROR: write failed: %s\n' "$_target" >&2
    exit 2
  fi
  printf 'STUB: %s\n' "$_target" >&2
  STUBS_WRITTEN=$((STUBS_WRITTEN + 1))
}

# write_index <target-abs-path> <title> <body-file> [<include-canonical>]
#
# body-file is a tmp file with pre-formatted bullet lines.
# include-canonical (optional) is a path of the form
# "<canonical-rel-from-stub-dir>|<canonical-abs-path>" — when present, the
# index page emits an include-markdown directive for that canonical artifact
# above the bullet list. Used by milestone/phase indexes so the page leads
# with a real summary instead of a bare bullet list (item 2 of the
# wiki-usability pass).
write_index() {
  _target="$1"
  _title="$2"
  _bodyfile="$3"
  _include_spec="${4:-}"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'WOULD-WRITE: %s\n' "$_target" >&2
    INDEXES_WRITTEN=$((INDEXES_WRITTEN + 1))
    return 0
  fi
  _dir=$(dirname "$_target")
  if ! mkdir -p "$_dir"; then
    printf 'ERROR: mkdir failed: %s\n' "$_dir" >&2
    exit 2
  fi
  _title_esc=$(printf '%s' "$_title" | sed 's/"/\\"/g')
  _inc_rel=""
  _inc_abs=""
  if [ -n "$_include_spec" ]; then
    _inc_rel=${_include_spec%%|*}
    _inc_abs=${_include_spec#*|}
  fi
  _has_fm=0
  if [ -n "$_inc_abs" ] && [ -f "$_inc_abs" ]; then
    _first=$(head -n 1 "$_inc_abs" 2>/dev/null)
    [ "$_first" = "---" ] && _has_fm=1
  fi
  {
    printf -- '---\n'
    printf 'title: "%s"\n' "$_title_esc"
    printf -- '---\n\n'
    printf '# %s\n\n' "$_title"
    printf '<!-- Auto-generated section index. Regenerated by wiki-generate-stubs.sh. -->\n\n'
    if [ -n "$_inc_rel" ] && [ -f "$_inc_abs" ]; then
      printf '{%%\n'
      printf '  include-markdown "%s"\n' "$_inc_rel"
      if [ "$_has_fm" -eq 1 ]; then
        printf '  start="\\n---\\n"\n'
      fi
      printf '  heading-offset=1\n'
      printf '  rewrite-relative-urls=true\n'
      printf '%%}\n\n'
      printf '## Contents\n\n'
    fi
    if [ -f "$_bodyfile" ]; then
      cat "$_bodyfile"
    fi
  } > "$_target"
  printf 'INDEX: %s\n' "$_target" >&2
  INDEXES_WRITTEN=$((INDEXES_WRITTEN + 1))
}

# ---- clean phase ------------------------------------------------------------
# Remove every .md under wiki/docs/ except the top-level index.md and README.md.

clean_phase() {
  if [ ! -d "$DOCS" ]; then
    return 0
  fi
  # Count first for reporting.
  _list="/tmp/wiki-stubs-clean-$$.list"
  find "$DOCS" -mindepth 1 -type f -name '*.md' \
    ! -path "$DOCS/index.md" \
    ! -path "$DOCS/README.md" \
    -print > "$_list" 2>/dev/null || true
  while IFS= read -r _f; do
    [ -n "$_f" ] || continue
    REMOVED=$((REMOVED + 1))
    if [ "$DRY_RUN" -eq 1 ]; then
      printf 'WOULD-REMOVE: %s\n' "$_f" >&2
    else
      rm -f "$_f"
    fi
  done < "$_list"
  rm -f "$_list"
  if [ "$DRY_RUN" -ne 1 ]; then
    # Remove now-empty subdirectories (best-effort; swallow errors).
    find "$DOCS" -mindepth 1 -type d -empty -delete 2>/dev/null || true
  fi
}

# ---- collect scanner output -------------------------------------------------

SCAN_OUT="/tmp/wiki-stubs-scan-$$.list"
TITLES_FILE="/tmp/wiki-stubs-titles-$$.tsv"
trap 'rm -f "$SCAN_OUT" "$TITLES_FILE"' EXIT INT TERM

if ! bash "$SCANNER" --root "$ROOT" > "$SCAN_OUT" 2>/dev/null; then
  printf 'ERROR: scanner failed\n' >&2
  exit 1
fi

# Build M### -> Title lookup once. Consumed by section_title_for() so milestone
# index pages render "M028 — Autonomous Hardening v3" headings instead of bare
# M###. Failure to load is non-fatal; section_title_for falls back to MID.
TITLES_SCRIPT="$ROOT/scripts/wiki/wiki-milestone-titles.sh"
if [ -f "$TITLES_SCRIPT" ]; then
  bash "$TITLES_SCRIPT" --root "$ROOT" > "$TITLES_FILE" 2>/dev/null || : > "$TITLES_FILE"
else
  : > "$TITLES_FILE"
fi

# ---- run clean phase --------------------------------------------------------

clean_phase

# ---- parallel index arrays for section-index tracking -----------------------
# Bash 3.2: no associative arrays. We track unique section dirs + their children
# as parallel arrays. A "section dir" is a path (relative to wiki/docs/) that
# holds an index.md; a child is "<child-rel>|<child-title>" where child-rel is
# relative to the section dir.

# Helper: register a child under a section dir.
# We append a line "section_rel|child_basename|child_title" to a tmp file,
# then process it at the end to emit one index per unique section_rel.
SECTIONS_FILE="/tmp/wiki-stubs-sections-$$.list"
: > "$SECTIONS_FILE" 2>/dev/null || true
trap 'rm -f "$SCAN_OUT" "$SECTIONS_FILE"' EXIT INT TERM

register_child() {
  _section_rel="$1"   # e.g., "milestones" or "milestones/M002" or "milestones/M002/phases/P01"
  _child_rel="$2"     # stub path relative to section, e.g., "M002/index.md" or "M002-CONTEXT.md" or "P01/index.md"
  _child_title="$3"
  printf '%s|%s|%s\n' "$_section_rel" "$_child_rel" "$_child_title" >> "$SECTIONS_FILE"
}

# ---- knowledge-entries tracking (M012/P02/T02) -----------------------------
# Parallel /tmp lists per category — recorded during the main record pass so the
# end-of-script section-index emitter can walk them in lexical order. No
# associative arrays (bash 3.2 safe).
KN_PATTERNS_LIST="/tmp/wiki-stubs-kn-patterns-$$.list"
KN_CONVENTIONS_LIST="/tmp/wiki-stubs-kn-conventions-$$.list"
KN_LESSONS_LIST="/tmp/wiki-stubs-kn-lessons-$$.list"
: > "$KN_PATTERNS_LIST" 2>/dev/null || true
: > "$KN_CONVENTIONS_LIST" 2>/dev/null || true
: > "$KN_LESSONS_LIST" 2>/dev/null || true
trap 'rm -f "$SCAN_OUT" "$SECTIONS_FILE" "$KN_PATTERNS_LIST" "$KN_CONVENTIONS_LIST" "$KN_LESSONS_LIST"' EXIT INT TERM

# record_knowledge_child <sub> <mem_id> <title>
#   Appends one "mem_id|title" record to the per-category list.
record_knowledge_child() {
  _sub="$1"
  _mid="$2"
  _title="$3"
  case "$_sub" in
    patterns)    printf '%s|%s\n' "$_mid" "$_title" >> "$KN_PATTERNS_LIST" ;;
    conventions) printf '%s|%s\n' "$_mid" "$_title" >> "$KN_CONVENTIONS_LIST" ;;
    lessons)     printf '%s|%s\n' "$_mid" "$_title" >> "$KN_LESSONS_LIST" ;;
  esac
}

# ---- process scanner records ------------------------------------------------

while IFS='|' read -r CAT REL TITLE; do
  [ -n "$CAT" ] || continue

  # ---- knowledge:* routing (M012/P02/T02) ----------------------------------
  # knowledge:<sub> records route to wiki/docs/knowledge/<sub>/<MEM>.md. The
  # canonical source lives at the repo root (knowledge/<sub>/<MEM>.md), NOT
  # under .orchestrator/, so we use build_canonical_repo_rel.
  case "$CAT" in
    knowledge:patterns|knowledge:conventions|knowledge:lessons)
      _sub=${CAT#knowledge:}
      _mem_id=$(basename "$REL" .md)
      STUB_REL="knowledge/${_sub}/${_mem_id}.md"
      STUB_ABS="$DOCS/$STUB_REL"
      CANONICAL=$(build_canonical_repo_rel "$STUB_REL" "$REL")
      # knowledge:* records carry repo-rel paths (knowledge/<sub>/MEM###.md).
      CANONICAL_ABS="$ROOT/$REL"
      write_stub "$STUB_ABS" "$CANONICAL" "$TITLE" "$CANONICAL_ABS"
      record_knowledge_child "$_sub" "$_mem_id" "$TITLE"
      continue
      ;;
  esac

  STUB_REL=$(map_record_to_stub_rel "$CAT" "$REL")
  STUB_ABS="$DOCS/$STUB_REL"
  CANONICAL=$(build_canonical "$STUB_REL" "$REL")
  # All non-knowledge records carry rel-paths under .orchestrator/.
  CANONICAL_ABS="$ROOT/.orchestrator/$REL"
  write_stub "$STUB_ABS" "$CANONICAL" "$TITLE" "$CANONICAL_ABS"

  # Register for section indexes.
  # Determine which section(s) this stub belongs to based on category.
  case "$CAT" in
    milestone:*)
      # STUB_REL is like "milestones/M###/M###-FOO.md" or
      # "milestones/M###/phases/P##/P##-PLAN.md" or
      # "milestones/M###/phases/P##/tasks/T##-PLAN.md" or
      # "milestones/M###/phases/P##/{fixtures,evidence}/*.md" or
      # "milestones/M###/archive/P##/*.md" (archived phase subtree).
      _mid=$(printf '%s' "$CAT" | sed 's/^milestone://')
      # Top-level "milestones" index gets each M### once — handled after the loop.
      # Milestone index gets top-level M###-*.md children directly, plus P## dirs.
      # Phase index gets P##-*.md children directly, plus tasks/ dir entries.
      _tail=${STUB_REL#milestones/${_mid}/}
      case "$_tail" in
        phases/*/tasks/*)
          # Task stub: register under the phase dir.
          _pid=$(printf '%s' "$_tail" | sed 's#^phases/\([^/]*\)/.*#\1#')
          _task_base=$(basename "$_tail")
          register_child "milestones/${_mid}/phases/${_pid}" "tasks/${_task_base}" "$TITLE"
          ;;
        phases/*/*/*)
          # Phase subdir file (fixtures/, evidence/, etc.) — register under
          # the phase index with the sub-tail preserved so the link resolves.
          _pid=$(printf '%s' "$_tail" | sed 's#^phases/\([^/]*\)/.*#\1#')
          _sub_tail=${_tail#phases/${_pid}/}
          register_child "milestones/${_mid}/phases/${_pid}" "${_sub_tail}" "$TITLE"
          ;;
        phases/*/*)
          # Phase-top file (P##-PLAN.md, P##-SUMMARY.md): register under milestone and under phase itself.
          _pid=$(printf '%s' "$_tail" | sed 's#^phases/\([^/]*\)/.*#\1#')
          _pbase=$(basename "$_tail")
          register_child "milestones/${_mid}/phases/${_pid}" "${_pbase}" "$TITLE"
          ;;
        archive/*)
          # Archived phase file — register flat on the milestone index with the
          # full archive/P##/... sub-tail preserved so the link resolves to the
          # stub nested under the milestone's archive/ subtree.
          register_child "milestones/${_mid}" "${_tail}" "$TITLE"
          ;;
        *)
          # Milestone-top file (M###-CONTEXT.md, etc.).
          register_child "milestones/${_mid}" "$(basename "$_tail")" "$TITLE"
          ;;
      esac
      ;;
    archive:*)
      _mid=$(printf '%s' "$CAT" | sed 's/^archive://')
      _tail=${STUB_REL#archive/${_mid}/}
      case "$_tail" in
        phases/*/tasks/*)
          _pid=$(printf '%s' "$_tail" | sed 's#^phases/\([^/]*\)/.*#\1#')
          _task_base=$(basename "$_tail")
          register_child "archive/${_mid}/phases/${_pid}" "tasks/${_task_base}" "$TITLE"
          ;;
        phases/*/*)
          _pid=$(printf '%s' "$_tail" | sed 's#^phases/\([^/]*\)/.*#\1#')
          _pbase=$(basename "$_tail")
          register_child "archive/${_mid}/phases/${_pid}" "${_pbase}" "$TITLE"
          ;;
        *)
          register_child "archive/${_mid}" "$(basename "$_tail")" "$TITLE"
          ;;
      esac
      ;;
  esac
done < "$SCAN_OUT"

# ---- derive top-level section index children -------------------------------
# milestones/index.md lists each M### directory.
# archive/index.md lists each M### directory.
# We derive M### lists from SECTIONS_FILE entries whose section_rel is "milestones/M###" (milestone root).

# Build a file listing unique milestone IDs (sorted) seen in stubs tree.
MILESTONES_SEEN="/tmp/wiki-stubs-milestones-$$.list"
ARCHIVE_SEEN="/tmp/wiki-stubs-archive-$$.list"
: > "$MILESTONES_SEEN" 2>/dev/null || true
: > "$ARCHIVE_SEEN" 2>/dev/null || true

# From SECTIONS_FILE, extract distinct top-level milestone ids.
if [ -f "$SECTIONS_FILE" ]; then
  awk -F'|' '
    $1 ~ /^milestones\/M[0-9]+$/ { print $1 }
    $1 ~ /^milestones\/M[0-9]+\// { n=split($1, a, "/"); print a[1] "/" a[2] }
  ' "$SECTIONS_FILE" | sort -u > "$MILESTONES_SEEN"
  awk -F'|' '
    $1 ~ /^archive\/M[0-9]+$/ { print $1 }
    $1 ~ /^archive\/M[0-9]+\// { n=split($1, a, "/"); print a[1] "/" a[2] }
  ' "$SECTIONS_FILE" | sort -u > "$ARCHIVE_SEEN"
fi

# Register each milestone as a child under the "milestones" section index.
while IFS= read -r _msec; do
  [ -n "$_msec" ] || continue
  _mid=$(basename "$_msec")
  register_child "milestones" "${_mid}/index.md" "$_mid"
done < "$MILESTONES_SEEN"

while IFS= read -r _asec; do
  [ -n "$_asec" ] || continue
  _mid=$(basename "$_asec")
  register_child "archive" "${_mid}/index.md" "$_mid"
done < "$ARCHIVE_SEEN"

# For each milestone, derive its phase directories and register phase/index.md
# as a child under the milestone section. Same for archive.
while IFS= read -r _msec; do
  [ -n "$_msec" ] || continue
  _mid=$(basename "$_msec")
  # Find phase ids for this milestone.
  awk -F'|' -v m="$_mid" '
    $1 ~ ("^milestones/" m "/phases/P[0-9]+$") {
      n=split($1, a, "/"); print a[4]
    }
  ' "$SECTIONS_FILE" | sort -u > "/tmp/wiki-stubs-phases-$$.list"
  while IFS= read -r _pid; do
    [ -n "$_pid" ] || continue
    register_child "milestones/${_mid}" "phases/${_pid}/index.md" "$_pid"
  done < "/tmp/wiki-stubs-phases-$$.list"
  rm -f "/tmp/wiki-stubs-phases-$$.list"
done < "$MILESTONES_SEEN"

while IFS= read -r _asec; do
  [ -n "$_asec" ] || continue
  _mid=$(basename "$_asec")
  awk -F'|' -v m="$_mid" '
    $1 ~ ("^archive/" m "/phases/P[0-9]+$") {
      n=split($1, a, "/"); print a[4]
    }
  ' "$SECTIONS_FILE" | sort -u > "/tmp/wiki-stubs-aphases-$$.list"
  while IFS= read -r _pid; do
    [ -n "$_pid" ] || continue
    register_child "archive/${_mid}" "phases/${_pid}/index.md" "$_pid"
  done < "/tmp/wiki-stubs-aphases-$$.list"
  rm -f "/tmp/wiki-stubs-aphases-$$.list"
done < "$ARCHIVE_SEEN"

rm -f "$MILESTONES_SEEN" "$ARCHIVE_SEEN"

# ---- emit section index files ----------------------------------------------
# For every unique section_rel in SECTIONS_FILE, build a body file of bullets
# sorted lexically and write the index.

section_title_for() {
  _rel="$1"
  case "$_rel" in
    milestones) printf 'Milestones' ;;
    archive)    printf 'Archive' ;;
    milestones/M[0-9][0-9][0-9]|archive/M[0-9][0-9][0-9])
      _mid=$(basename "$_rel")
      _t=$(awk -F'\t' -v m="$_mid" '$1 == m { print $2; exit }' "$TITLES_FILE" 2>/dev/null)
      if [ -n "$_t" ]; then
        printf '%s — %s' "$_mid" "$_t"
      else
        printf '%s' "$_mid"
      fi
      ;;
    *)
      # Use the last segment as the title; e.g., "milestones/M002/phases/P01" -> "P01".
      printf '%s' "$(basename "$_rel")"
      ;;
  esac
}

# section_include_for <section-rel>
# Echoes "<canonical-rel-from-stub>|<canonical-abs>" when the section's index
# page should include canonical content (milestone summary, phase summary).
# Echoes nothing when the index should remain bullets-only.
#
# Path-depth math: index lives at wiki/docs/<section>/index.md, which is one
# level deeper than the section dir itself. The include path resolves relative
# to the index file, so depth = slash-count(section) + 1 (the index.md slash)
# + 2 (docs → wiki → repo root). Mirrors build_canonical above (which counts
# slashes in the full stub-rel including the basename).
section_include_for() {
  _rel="$1"
  _slash=$(count_slashes "$_rel")
  _depth=$((_slash + 3))
  _prefix=""
  _i=0
  while [ "$_i" -lt "$_depth" ]; do
    _prefix="${_prefix}../"
    _i=$((_i + 1))
  done
  case "$_rel" in
    milestones/M[0-9][0-9][0-9])
      _mid=$(basename "$_rel")
      for _kind in SUMMARY CONTEXT EVALUATION ROADMAP; do
        _abs="$ROOT/.orchestrator/milestones/${_mid}/${_mid}-${_kind}.md"
        if [ -f "$_abs" ]; then
          printf '%s.orchestrator/milestones/%s/%s-%s.md|%s' \
            "$_prefix" "$_mid" "$_mid" "$_kind" "$_abs"
          return 0
        fi
      done
      ;;
    milestones/M[0-9][0-9][0-9]/phases/P[0-9][0-9])
      _mid=$(printf '%s' "$_rel" | awk -F/ '{print $2}')
      _pid=$(printf '%s' "$_rel" | awk -F/ '{print $4}')
      for _kind in SUMMARY PLAN; do
        _abs="$ROOT/.orchestrator/milestones/${_mid}/phases/${_pid}/${_pid}-${_kind}.md"
        if [ -f "$_abs" ]; then
          printf '%s.orchestrator/milestones/%s/phases/%s/%s-%s.md|%s' \
            "$_prefix" "$_mid" "$_pid" "$_pid" "$_kind" "$_abs"
          return 0
        fi
      done
      ;;
    archive/M[0-9][0-9][0-9])
      _mid=$(basename "$_rel")
      for _kind in SUMMARY CONTEXT EVALUATION ROADMAP; do
        _abs="$ROOT/.orchestrator/archive/${_mid}/${_mid}-${_kind}.md"
        if [ -f "$_abs" ]; then
          printf '%s.orchestrator/archive/%s/%s-%s.md|%s' \
            "$_prefix" "$_mid" "$_mid" "$_kind" "$_abs"
          return 0
        fi
      done
      ;;
  esac
  return 1
}

# Collect unique section_rel values (sorted).
UNIQUE_SECTIONS="/tmp/wiki-stubs-unique-$$.list"
if [ -f "$SECTIONS_FILE" ]; then
  awk -F'|' '{ print $1 }' "$SECTIONS_FILE" | sort -u > "$UNIQUE_SECTIONS"
fi

# We also need to guarantee the top-level "milestones" and "archive" indexes
# are written even if a milestone or archive tree had only phase-deep entries.
# (The registrations above already cover them.) But also ensure phase indexes
# get written for phases that have tasks but no phase-level plan/summary stub.
# Register any phase dir with tasks so its index gets created.

# Enumerate sections that are phase-level (milestones/M###/phases/P##) referenced
# by any section_rel starting with "milestones/M###/phases/P##" and ensure they
# appear in UNIQUE_SECTIONS (they already do, because children register them).

write_section_index_for() {
  _section="$1"
  _body_tmp="/tmp/wiki-stubs-body-$$.list"
  # Extract children of this section, de-dup on child_rel, sort lexically.
  awk -F'|' -v s="$_section" '
    $1 == s { print $2 "|" $3 }
  ' "$SECTIONS_FILE" | sort -u -t'|' -k1,1 > "$_body_tmp"
  # Build body file of bullets.
  _bullets="/tmp/wiki-stubs-bullets-$$.list"
  : > "$_bullets"
  while IFS='|' read -r _cref _ctitle; do
    [ -n "$_cref" ] || continue
    # Escape brackets/parens minimally — markdown link target uses URL-encoded spaces rarely here.
    # Use child_title if non-empty, else child_rel as-is.
    if [ -z "$_ctitle" ]; then
      _ctitle="$_cref"
    fi
    printf -- '- [%s](%s)\n' "$_ctitle" "$_cref" >> "$_bullets"
  done < "$_body_tmp"
  rm -f "$_body_tmp"
  _title=$(section_title_for "$_section")
  _idx_target="$DOCS/$_section/index.md"
  _inc_spec=$(section_include_for "$_section")
  write_index "$_idx_target" "$_title" "$_bullets" "$_inc_spec"
  rm -f "$_bullets"
}

if [ -f "$UNIQUE_SECTIONS" ]; then
  while IFS= read -r _sec; do
    [ -n "$_sec" ] || continue
    write_section_index_for "$_sec"
  done < "$UNIQUE_SECTIONS"
fi

rm -f "$UNIQUE_SECTIONS"

# ---- knowledge/ section indexes (M012/P02/T02) -----------------------------
# Four indexes:
#   wiki/docs/knowledge/index.md               (top-level; links to sub indexes)
#   wiki/docs/knowledge/patterns/index.md      (per-category; links to MEM stubs)
#   wiki/docs/knowledge/conventions/index.md
#   wiki/docs/knowledge/lessons/index.md
# Indexes carry the "Auto-generated section index" comment probe via write_index.

# write_knowledge_sub_index_from_list <sub> <list-file>
#   Builds a bullet-body tmp file from mem_id|title records sorted lexically,
#   then calls write_index to emit wiki/docs/knowledge/<sub>/index.md.
write_knowledge_sub_index_from_list() {
  _sub="$1"
  _list="$2"
  _body="/tmp/wiki-stubs-kn-body-$$.list"
  : > "$_body"
  if [ -f "$_list" ]; then
    sort -u "$_list" > "${_list}.sorted"
    while IFS='|' read -r _mid _mtitle; do
      [ -n "$_mid" ] || continue
      if [ -z "$_mtitle" ]; then
        _mtitle="$_mid"
      fi
      printf -- '- [%s](%s.md)\n' "$_mtitle" "$_mid" >> "$_body"
    done < "${_list}.sorted"
    rm -f "${_list}.sorted"
  fi
  _idx_target="$DOCS/knowledge/${_sub}/index.md"
  case "$_sub" in
    patterns)    _title="Knowledge — Patterns" ;;
    conventions) _title="Knowledge — Conventions" ;;
    lessons)     _title="Knowledge — Lessons" ;;
    *)           _title="Knowledge — ${_sub}" ;;
  esac
  write_index "$_idx_target" "$_title" "$_body"
  rm -f "$_body"
}

# write_knowledge_top_index — emits the top-level knowledge/index.md listing the
# three categories. Always written (even when a category list is empty) so the
# nav leaf resolves.
write_knowledge_top_index() {
  _body="/tmp/wiki-stubs-kn-top-$$.list"
  : > "$_body"
  printf -- '- [Patterns](patterns/index.md)\n' >> "$_body"
  printf -- '- [Conventions](conventions/index.md)\n' >> "$_body"
  printf -- '- [Lessons](lessons/index.md)\n' >> "$_body"
  _idx_target="$DOCS/knowledge/index.md"
  write_index "$_idx_target" "Knowledge Entries" "$_body"
  rm -f "$_body"
}

write_knowledge_top_index
write_knowledge_sub_index_from_list "patterns"    "$KN_PATTERNS_LIST"
write_knowledge_sub_index_from_list "conventions" "$KN_CONVENTIONS_LIST"
write_knowledge_sub_index_from_list "lessons"     "$KN_LESSONS_LIST"

rm -f "$KN_PATTERNS_LIST" "$KN_CONVENTIONS_LIST" "$KN_LESSONS_LIST"

# ---- summary ---------------------------------------------------------------

printf 'SUMMARY: wrote %d stubs, %d section indexes, removed %d stale files\n' \
  "$STUBS_WRITTEN" "$INDEXES_WRITTEN" "$REMOVED" >&2

exit 0
