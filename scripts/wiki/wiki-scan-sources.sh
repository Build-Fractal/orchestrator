#!/usr/bin/env bash
# scripts/wiki/wiki-scan-sources.sh — M012/P01 in-scope artifact enumerator.
#
# Prints one record per in-scope .orchestrator/**.md file to stdout:
#   <category>|<relative-path-under-dot-orchestrator>|<display-title>
#
# Category enum:
#   top:constitution
#   top:decisions
#   top:knowledge
#   top:milestone-summary
#   milestone:M###
#   archive:M###
#
# Exclusion policy (hard-coded; see M012-ROADMAP Boundary Map + FR-8):
#   .orchestrator/scratch/**         — transient
#   .orchestrator/tmp/**             — transient
#   .orchestrator/config/**          — config, not artifact
#   any non-.md file                 — wiki is markdown-only
#   P##-PLANNING-PAYLOAD.md          — planning scratch
#   P##-VERIFICATION.md              — machine output
#   AGENTS.md / README.md under milestone/archive trees
#
# Usage: bash scripts/wiki/wiki-scan-sources.sh [--root PROJECT_ROOT]
# Exit 0 on success; 1 on unresolvable PROJECT_ROOT or missing .orchestrator/.
# Bash 3.2 compatible — no associative arrays, mapfile, ${var^^}, <(...), &>.

set -u

ROOT=""

# ---- argument parsing -------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      shift
      if [ $# -eq 0 ]; then
        printf 'ERROR: --root requires a path argument\n' >&2
        exit 1
      fi
      ROOT="$1"
      shift
      ;;
    --help|-h)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *)
      printf 'ERROR: unknown argument: %s\n' "$1" >&2
      exit 1
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
  exit 1
fi

ORCH="$ROOT/.orchestrator"
if [ ! -d "$ORCH" ]; then
  printf 'SUMMARY: 0 in-scope artifacts\n' >&2
  exit 0
fi

# ---- counters ---------------------------------------------------------------
COUNT=0

# ---- helpers ----------------------------------------------------------------

# extract_title <absolute-path>
# Prints the display title on stdout. Never fails.
extract_title() {
  _p="$1"
  _t=""
  if [ -f "$_p" ]; then
    _t=$(grep -m 1 '^# ' "$_p" 2>/dev/null | sed 's/^# //' | head -n 1)
  fi
  if [ -z "$_t" ]; then
    _b=$(basename "$_p" .md)
    _t="$_b"
  fi
  # Sanitize: replace pipe characters so the 3-field schema stays intact.
  _t=$(printf '%s' "$_t" | tr '|' '/')
  printf '%s' "$_t"
}

# emit_record <category> <relative-path-under-orchestrator> <absolute-path>
emit_record() {
  _cat="$1"
  _rel="$2"
  _abs="$3"
  _title=$(extract_title "$_abs")
  printf '%s|%s|%s\n' "$_cat" "$_rel" "$_title"
  COUNT=$((COUNT + 1))
}

# should_exclude <relative-path-under-orchestrator>
# Returns 0 if the path should be excluded, 1 otherwise.
should_exclude() {
  _rel="$1"
  # top-level excluded trees
  case "$_rel" in
    scratch/*|tmp/*|config/*)
      return 0
      ;;
  esac
  # basename checks
  _base=$(basename "$_rel")
  case "$_base" in
    AGENTS.md|README.md)
      return 0
      ;;
  esac
  # pattern checks — per must-haves, exclude any basename containing
  # PLANNING-PAYLOAD or VERIFICATION (covers P##- and M###- variants).
  case "$_base" in
    *PLANNING-PAYLOAD*.md)
      return 0
      ;;
    *VERIFICATION*.md|*-VERIFICATION.md)
      return 0
      ;;
  esac
  # Include-markdown self-reference carve-out: these six task plans document
  # the stub generator + Giscus comments partial and contain literal `{% ... %}`
  # Jinja/include-markdown blocks inside code fences (stub template at
  # P01/T03 + P02/T02; Material comments-partial override at P03/T01).
  # mkdocs-include-markdown-plugin does not respect code fences when scanning
  # for nested includes, so projecting them through the wiki aborts the build.
  # Canonical source on disk preserved (Constitution VI).
  case "$_rel" in
    milestones/M012/archive/P01/T03-PLAN.md|milestones/M012/archive/P01/T03-PAYLOAD.md|milestones/M012/archive/P02/T02-PLAN.md|milestones/M012/archive/P02/T02-PAYLOAD.md|milestones/M012/archive/P03/T01-PLAN.md|milestones/M012/archive/P03/T01-PAYLOAD.md)
      return 0
      ;;
  esac
  # non-.md
  case "$_base" in
    *.md) : ;;
    *) return 0 ;;
  esac
  return 1
}

# scan_tree <absolute-dir> <category-prefix-mode>
# category-prefix-mode: "milestone" or "archive"
# Emits milestone:M### or archive:M### records for all in-scope .md files.
# Uses a /tmp list file (outside $ROOT) to avoid the `| while` subshell,
# so the COUNT variable stays accurate.
scan_tree() {
  _dir="$1"
  _mode="$2"
  [ -d "$_dir" ] || return 0
  for _msub in "$_dir"/M*/; do
    [ -d "$_msub" ] || continue
    _mname=$(basename "$_msub")
    _cat="${_mode}:${_mname}"
    # Write the sorted find output to a tmp file? Constraint forbids writes
    # under $ROOT. Use /tmp instead. Pid-scoped path, auto-cleaned.
    _list="/tmp/wiki-scan-$$.list"
    find "$_msub" -type f -name '*.md' 2>/dev/null | sort > "$_list"
    while IFS= read -r _abs; do
      [ -n "$_abs" ] || continue
      _rel=${_abs#"$ROOT/.orchestrator/"}
      if should_exclude "$_rel"; then
        continue
      fi
      emit_record "$_cat" "$_rel" "$_abs"
    done < "$_list"
    rm -f "$_list"
  done
}

# ---- scan: top-level artifacts ---------------------------------------------

if [ -f "$ORCH/memory/constitution.md" ]; then
  emit_record "top:constitution" "memory/constitution.md" "$ORCH/memory/constitution.md"
fi

if [ -f "$ORCH/DECISIONS.md" ]; then
  emit_record "top:decisions" "DECISIONS.md" "$ORCH/DECISIONS.md"
fi

if [ -f "$ORCH/KNOWLEDGE.md" ]; then
  emit_record "top:knowledge" "KNOWLEDGE.md" "$ORCH/KNOWLEDGE.md"
fi

if [ -f "$ORCH/milestone-summary.md" ]; then
  emit_record "top:milestone-summary" "milestone-summary.md" "$ORCH/milestone-summary.md"
fi

# ---- scan: milestones -------------------------------------------------------

scan_tree "$ORCH/milestones" "milestone"

# ---- scan: archive ----------------------------------------------------------

scan_tree "$ORCH/archive" "archive"

# ---- scan: knowledge/ tree (added in M012/P02/T01) --------------------------
# Emits knowledge:<category>|<repo-root-relative-path>|<title> records for
# every knowledge/<category>/MEM*.md entry. Categories enumerated in fixed
# order: patterns, conventions, lessons. Within each category, files are
# emitted in LC_ALL=C lexical order (MEM001, MEM002, ...). Unlike the
# .orchestrator/ records (which use a rel-path under .orchestrator/), these
# records carry a rel-path under the repo root (e.g., knowledge/patterns/MEM001.md)
# because they live outside the .orchestrator/ tree.
#
# Additive only: the existing .orchestrator/ emission above is unchanged.
# Downstream generators (T02) will learn to consume the new category prefix.

if [ -d "$ROOT/knowledge" ]; then
  for _cat in patterns conventions lessons; do
    _catdir="$ROOT/knowledge/$_cat"
    [ -d "$_catdir" ] || continue
    # /tmp list file (outside ROOT) — avoids the |-while subshell that would
    # lose COUNT updates in Bash 3.2.
    _klist="/tmp/wiki-scan-knowledge.$_cat.$$"
    find "$_catdir" -maxdepth 1 -type f -name 'MEM*.md' 2>/dev/null | LC_ALL=C sort > "$_klist"
    while IFS= read -r _mempath; do
      [ -n "$_mempath" ] || continue
      _krel=${_mempath#"$ROOT/"}
      _ktitle=$(extract_title "$_mempath")
      printf '%s|%s|%s\n' "knowledge:$_cat" "$_krel" "$_ktitle"
      COUNT=$((COUNT + 1))
    done < "$_klist"
    rm -f "$_klist"
  done
fi

# ---- trailer ----------------------------------------------------------------

printf 'SUMMARY: %d in-scope artifacts\n' "$COUNT" >&2
exit 0
