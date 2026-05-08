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

# ---- markers (FR-14 region split) ------------------------------------------
# Two regions:
#   auto-nav: regenerated on every invocation (Constitution, Decisions, etc.)
#   custom-nav: preserved verbatim across regenerates (operator-owned)
MARKER_AUTO_START="# >>> auto-nav (auto-generated — do not edit by hand)"
MARKER_AUTO_END="# <<< auto-nav end"
MARKER_CUSTOM_START="# >>> custom-nav"
MARKER_CUSTOM_END="# <<< custom-nav end"

# Legacy markers (M012/P01 baseline). On first regenerate against a legacy
# block, migrate the markers in-place to the new shape per FR-14 / MIT-005.
LEGACY_MARKER_START="# >>> M012-P01 nav (auto-generated — do not edit by hand)"
LEGACY_MARKER_END="# <<< M012-P01 nav end"

# ---- temp files / cleanup --------------------------------------------------
SCAN_OUT="/tmp/wiki-nav-scan-$$.list"
NAV_BODY="/tmp/wiki-nav-body-$$.yml"
TMP_PRE="/tmp/wiki-nav-pre-$$.yml"
TMP_POST="/tmp/wiki-nav-post-$$.yml"
TMP_FINAL="/tmp/wiki-nav-final-$$.yml"
TMP_IDS="/tmp/wiki-nav-ids-$$.list"
TMP_PHASE="/tmp/wiki-nav-phase-$$.list"
trap 'rm -f "$SCAN_OUT" "$NAV_BODY" "$TMP_PRE" "$TMP_POST" "$TMP_FINAL" "$TMP_IDS" "$TMP_PHASE" "/tmp/wiki-nav-titles-$$.tsv" /tmp/wiki-nav-kn-patterns-$$.list /tmp/wiki-nav-kn-conventions-$$.list /tmp/wiki-nav-kn-lessons-$$.list /tmp/wiki-nav-legacy-preserved-$$.yml /tmp/wiki-nav-no-legacy-$$.yml /tmp/wiki-nav-heal-$$.yml /tmp/wiki-nav-extra-dns-$$.list /tmp/wiki-nav-proposals-$$.list /tmp/wiki-nav-proposals-$$.raw /tmp/wiki-nav-flat-$$.list /tmp/wiki-nav-flat-$$.raw /tmp/wiki-nav-extra-$$.list /tmp/wiki-nav-extra-$$.raw /tmp/wiki-nav-spec-$$.list /tmp/wiki-nav-spec-$$.raw /tmp/wiki-nav-decisions-extra-$$.list /tmp/wiki-nav-decisions-extra-$$.raw /tmp/wiki-nav-feedback-$$.list /tmp/wiki-nav-feedback-$$.raw' EXIT INT TERM

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

# read_stub_title <stub-abs-path>
#
# M037/P01/T02 FR-6: reads the projected stub's frontmatter `title:` field
# and prints it on stdout. Empty stdout when the stub does not exist or
# carries no title:. The stub generator (FR-5) is the projection authority
# for chunk `version:` → stub `title:`; the nav layer reads what the stub
# says, not what the scanner H1-extracted from the source. Bash 3.2 / awk.
read_stub_title() {
  _p="$1"
  [ -f "$_p" ] || return 0
  awk '
    BEGIN { state="pre" }
    NR == 1 && $0 == "---" { state="fm"; next }
    state == "fm" && $0 == "---" { exit }
    state == "fm" && $0 ~ /^[[:space:]]*title[[:space:]]*:[[:space:]]*/ {
      v=$0
      sub(/^[^:]*:[[:space:]]*/, "", v)
      sub(/[[:space:]]+$/, "", v)
      sub(/^["'"'"']/, "", v)
      sub(/["'"'"']$/, "", v)
      print v
      exit
    }
  ' "$_p" 2>/dev/null
}

# read_source_nav_order <source-abs-path>
#
# PBJ-2026-05-08: reads YAML frontmatter `nav_order:` and prints the integer
# value on stdout. Empty stdout when the source does not exist or carries no
# `nav_order:` field (callers default to 9999, sorting after declared items).
# Mirror of read_stub_title shape, but reads the SOURCE file (not the stub)
# because the ordering hint is intrinsic to the source, not projected to stubs.
# Convention: sparse numbering (10, 20, 30, ...) so insertions don't require
# renumber churn.
read_source_nav_order() {
  _p="$1"
  [ -f "$_p" ] || return 0
  awk '
    BEGIN { state="pre" }
    NR == 1 && $0 == "---" { state="fm"; next }
    state == "fm" && $0 == "---" { exit }
    state == "fm" && $0 ~ /^[[:space:]]*nav_order[[:space:]]*:[[:space:]]*/ {
      v=$0
      sub(/^[^:]*:[[:space:]]*/, "", v)
      sub(/[[:space:]]+$/, "", v)
      sub(/^["'"'"']/, "", v)
      sub(/["'"'"']$/, "", v)
      print v
      exit
    }
  ' "$_p" 2>/dev/null
}

# sort_section_with_nav_order <input-list> <output-list> <source-base-dir>
#
# PBJ-2026-05-08: re-sorts a per-section CAT|REL|TITLE list by the source's
# frontmatter `nav_order:` integer (ascending), with alphabetical fallback
# within ties. Sources missing the field default to nav_order=9999, sorting
# after all declared items (backward compat: existing files unchanged → all
# alphabetical). The <source-base-dir> argument resolves the source file path:
# `$_src_base/$REL` must be the absolute path to the source-of-truth file
# (`.orchestrator/` for spec/decisions-extra/proposals/feedback; repo-root
# for extras). Bash 3.2: leading-zero pad gives stable lexical sort without
# `sort -n` flags.
sort_section_with_nav_order() {
  _in="$1"
  _out="$2"
  _src_base="$3"
  _dec="${_out}.dec"
  : > "$_dec"
  while IFS='|' read -r _c _r _t; do
    [ -n "$_r" ] || continue
    _src="$_src_base/$_r"
    _no=$(read_source_nav_order "$_src")
    case "$_no" in
      ''|*[!0-9]*) _no=9999 ;;
    esac
    _pad=$(printf '%05d' "$_no" 2>/dev/null)
    [ -n "$_pad" ] || _pad="09999"
    printf '%s|%s|%s|%s\n' "$_pad" "$_c" "$_r" "$_t" >> "$_dec"
  done < "$_in"
  # Default-locale sort matches the previous (pre-2026-05-08) per-section sort
  # behavior so projects without nav_order: declared see byte-identical nav
  # output. Digit characters collate identically across locales, so the numeric
  # prefix still sorts correctly; only the secondary alphabetical tiebreak
  # within ties uses the locale's collation rules (matching pre-existing
  # behavior). Tests in tests/test-wiki-nav-order-and-feedback.sh verify both
  # the numeric primary sort and the no-regression alphabetical fallback.
  sort "$_dec" | cut -d'|' -f2- > "$_out"
  rm -f "$_dec"
}

# emit_leaf <level> <label> <path-under-docs>
emit_leaf() {
  _lvl="$1"
  _label="$2"
  _path="$3"
  _q=$(yaml_escape_title "$_label")
  printf '%s- %s: %s\n' "$(indent "$_lvl")" "$_q" "$_path" >> "$NAV_BODY"
}

# emit_leaf_prefer_stub_title <level> <label> <path-under-docs>
#
# M037/P01/T02 FR-6: variant of emit_leaf that prefers the projected stub's
# frontmatter `title:` (FR-5 derived from source `version:`) when present.
# Used by the reference-corpus + knowledge-flat surfaces where slug-soup
# labels are the readability problem US-2 fixes. Milestone-artifact emitters
# keep using emit_leaf because their per-shape labels (Plan/Summary/Tasks)
# are already human-friendly. Falls back to <label> when the stub is
# missing or has no title.
emit_leaf_prefer_stub_title() {
  _lvl="$1"
  _label="$2"
  _path="$3"
  _stub_title=$(read_stub_title "$DOCS/$_path")
  if [ -n "$_stub_title" ]; then
    _label="$_stub_title"
  fi
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
# Strip the MID- prefix and title-case the rest. Examples:
#   M011-CONTEXT.md          -> "Context"
#   M011-EVALUATION.md       -> "Evaluation"
#   M011-ROADMAP.md          -> "Roadmap"
#   M011-SUMMARY.md          -> "Summary"
#   M2a-CONTEXT.md           -> "Context"            (PBJ-2026-05-08)
#   M-Spike-A-CONTEXT.md     -> "Context"            (PBJ-2026-05-08)
# Fallback (no prefix match): use the basename minus .md.
#
# PBJ-2026-05-08: pre-fix the case glob accepted only M###-* (3-digit numeric),
# so children of M2a/M-Spike-A milestones rendered as the bare basename
# ("M2a-CONTEXT") instead of "Context". Same ID-shape spec as the nav-sort
# two-bucket invariant (commit 9570e71e). Implemented with bash regex (`=~`)
# because case globs cannot express the dash-prefix shape without ambiguity
# under `*`-matches-`/` semantics.
milestone_artifact_label() {
  _b="$1"
  _core=$(printf '%s' "$_b" | sed 's/\.md$//')
  _mid=""
  _rest=""
  if [[ "$_core" =~ ^(M[0-9]+[a-z]*)-(.+)$ ]]; then
    _mid="${BASH_REMATCH[1]}"
    _rest="${BASH_REMATCH[2]}"
  elif [[ "$_core" =~ ^(M(-[A-Z][A-Za-z0-9]*)+)-([A-Z][A-Za-z0-9]*)$ ]]; then
    # Dash-prefixed MID (M-Spike-A) followed by a single UPPERCASE-led
    # artifact token (CONTEXT, SUMMARY, EVALUATION, ROADMAP, PLAN). The
    # artifact convention is dash-free: greedy captures the MID by repeatedly
    # matching `-[A-Z][A-Za-z0-9]*`, then the trailing token (no internal
    # dashes) is the artifact name.
    _mid="${BASH_REMATCH[1]}"
    _rest="${BASH_REMATCH[3]}"
  fi
  if [ -n "$_rest" ]; then
    _first=$(printf '%s' "$_rest" | cut -c1 | tr 'a-z' 'A-Z')
    _tail=$(printf '%s' "$_rest" | cut -c2- | tr 'A-Z' 'a-z')
    printf '%s%s' "$_first" "$_tail"
  else
    printf '%s' "$_core"
  fi
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

# ---- build M### -> Title lookup --------------------------------------------
# Loaded once; consulted via milestone_label() for nav group labels so the
# left navigation reads "M028 — Autonomous Hardening v3" instead of bare M028.
TITLES_FILE="/tmp/wiki-nav-titles-$$.tsv"
TITLES_SCRIPT="$ROOT/scripts/wiki/wiki-milestone-titles.sh"
if [ -x "$TITLES_SCRIPT" ] || [ -f "$TITLES_SCRIPT" ]; then
  bash "$TITLES_SCRIPT" --root "$ROOT" > "$TITLES_FILE" 2>/dev/null || : > "$TITLES_FILE"
else
  : > "$TITLES_FILE"
fi

# milestone_label <MID> -> echoes "MID — Title" when title resolves, else MID.
milestone_label() {
  _mid="$1"
  _t=$(awk -F'\t' -v m="$_mid" '$1 == m { print $2; exit }' "$TITLES_FILE" 2>/dev/null)
  if [ -n "$_t" ]; then
    printf '%s — %s' "$_mid" "$_t"
  else
    printf '%s' "$_mid"
  fi
}

# ---- assemble nav body -----------------------------------------------------
: > "$NAV_BODY"

printf '%s\n' "$MARKER_AUTO_START" >> "$NAV_BODY"
printf 'nav:\n' >> "$NAV_BODY"

# Top-level fixed entries.
emit_leaf 1 "Home" "index.md"

# Top-level artifact entries are present iff the scanner emits them. Track via
# a simple flag so we only add the leaf if the corresponding scanner record
# actually appeared (keeps the nav strictly in-sync with what T03 produced).
HAS_CONSTITUTION=0
HAS_GLOSSARY=0
HAS_DECISIONS=0
HAS_KNOWLEDGE=0
HAS_MILSUM=0
HAS_PROPOSALS=0          # M032/P04/T01 FR-17
HAS_KNOWLEDGE_FLAT=0     # M032/P04/T01 FR-19
HAS_SPEC=0               # PBJ-2026-05-07 ask 1
HAS_DECISIONS_EXTRA=0    # PBJ-2026-05-07 ask 2
HAS_FEEDBACK=0           # PBJ-2026-05-08 — feedback nav arm (Item E)

# Per-extra-dir presence is tracked via a /tmp accumulator because the dirname
# slot is dynamic. Each line "extra:<dn>" appears once per distinct dirname.
TMP_EXTRA_DNS="/tmp/wiki-nav-extra-dns-$$.list"
: > "$TMP_EXTRA_DNS"

# PBJ-dogfood B4: side-table mapping <dn>|<label> for declared
# wiki.extra_dir_labels overrides. Populated from extra-label:<dn>||<label>
# scanner records. Consulted in the extra-dirs nav section emission below.
TMP_EXTRA_LABELS="/tmp/wiki-nav-extra-labels-$$.list"
: > "$TMP_EXTRA_LABELS"

# Helper: print configured label for <dn>, or empty if none declared.
extra_label_for() {
  _dn="$1"
  awk -F'|' -v d="$_dn" '$1 == d { print $2; exit }' "$TMP_EXTRA_LABELS"
}

# First pass: discover which top-level entries exist, and which milestone/archive
# IDs appear (in first-seen order — scanner output is lexical). Write the
# ordered ID lists to TMP_IDS (one per line, prefixed with M: or A:).
: > "$TMP_IDS"
while IFS='|' read -r CAT REL TITLE; do
  [ -n "$CAT" ] || continue
  case "$CAT" in
    top:constitution)      HAS_CONSTITUTION=1 ;;
    top:glossary)          HAS_GLOSSARY=1 ;;
    top:decisions)         HAS_DECISIONS=1 ;;
    top:knowledge)         HAS_KNOWLEDGE=1 ;;
    top:milestone-summary) HAS_MILSUM=1 ;;
    proposals:*)           HAS_PROPOSALS=1 ;;
    knowledge-flat)        HAS_KNOWLEDGE_FLAT=1 ;;
    spec:*)                HAS_SPEC=1 ;;
    decisions-extra:*)     HAS_DECISIONS_EXTRA=1 ;;
    feedback:*)            HAS_FEEDBACK=1 ;;
    extra:*)
      _xdn=$(printf '%s' "$CAT" | sed 's/^extra://')
      printf '%s\n' "$_xdn" >> "$TMP_EXTRA_DNS"
      ;;
    extra-label:*)
      # PBJ-dogfood B4: collect <dn>|<label> into TMP_EXTRA_LABELS for
      # later lookup. Scanner emits this as `extra-label:<dn>||<label>`,
      # so REL is empty and TITLE carries the label.
      _xldn=$(printf '%s' "$CAT" | sed 's/^extra-label://')
      printf '%s|%s\n' "$_xldn" "$TITLE" >> "$TMP_EXTRA_LABELS"
      ;;
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

# Two-bucket sort within each kind (M-prefix then A-prefix preserved as outer
# key so M-group still leads A-group). Bucket 0: milestone IDs whose first
# character after `M` is a digit (M001, M2a, M999-foo) — sorted by version
# compare so M9 < M10 < M100 and M001 < M2a. Bucket 1: everything else
# (e.g. M-Spike-A) — sorted lex. Bucket 0 always precedes bucket 1.
#
# Why two buckets: a single `sort -u` puts `M-Spike-A` ahead of `M001`
# because `-` (0x2D) is below `0` (0x30) in lex order, which inverts
# priority signaling in the rendered nav (PBJ-2026-05-08).
sort -u "$TMP_IDS" > "${TMP_IDS}.uniq"
awk -F: '
  $2 ~ /^M[0-9]/ { print $1 ":0:" $2; next }
                 { print $1 ":1:" $2 }
' "${TMP_IDS}.uniq" \
  | LC_ALL=C sort -t: -k1,1 -k2,2n -k3,3V \
  | awk -F: '{ print $1 ":" $3 }' \
  > "${TMP_IDS}.sorted"
mv "${TMP_IDS}.sorted" "$TMP_IDS"
rm -f "${TMP_IDS}.uniq"

# Pre-compute HAS_ANY_MILESTONE / HAS_ANY_ARCHIVE here (re-set below at the
# Milestones-group emission site as well). Needed up-front for the
# PBJ-2026-05-07 forward-roadmap consolidation gate at the "Milestone Summary"
# top-level leaf — the leaf must be suppressed when at least one milestone:*
# record was observed (the milestone-summary content is now folded into
# wiki/docs/milestones/index.md by wiki-generate-stubs.sh::section_include_for).
HAS_ANY_MILESTONE=0
HAS_ANY_ARCHIVE=0
grep -q '^M:' "$TMP_IDS" && HAS_ANY_MILESTONE=1
grep -q '^A:' "$TMP_IDS" && HAS_ANY_ARCHIVE=1

# Emit top-level leaves.
if [ "$HAS_CONSTITUTION" -eq 1 ]; then
  emit_leaf 1 "Constitution" "constitution.md"
fi
# M032/P02/T03 FR-15: Glossary as the second top-level nav entry after
# Constitution. Path is `glossary.md` relative to docs_dir (the include-markdown
# stub generator bridges wiki/glossary.md -> wiki/docs/glossary.md).
if [ "$HAS_GLOSSARY" -eq 1 ]; then
  emit_leaf 1 "Glossary" "glossary.md"
fi
# PBJ-2026-05-07 ask 1: Spec section, slotted between Glossary and Decisions
# per the requested ordering. Index page (spec/index.md) is auto-rendered by
# the stub generator from register_child("spec", ...) calls. Entries sort by
# spec:<basename> ascending (matching proposals:* shape).
if [ "$HAS_SPEC" -eq 1 ]; then
  emit_group 1 "Spec"
  emit_leaf 2 "Overview" "spec/index.md"
  # PBJ-2026-05-08: sort by source frontmatter `nav_order:` (asc), alphabetical
  # tiebreak. Files without nav_order: default to 9999 (sort after declared).
  TMP_SPEC_RAW="/tmp/wiki-nav-spec-$$.raw"
  TMP_SPEC="/tmp/wiki-nav-spec-$$.list"
  awk -F'|' '
    $1 ~ /^spec:/ { print $1 "|" $2 "|" $3 }
  ' "$SCAN_OUT" | sort > "$TMP_SPEC_RAW"
  sort_section_with_nav_order "$TMP_SPEC_RAW" "$TMP_SPEC" "$ROOT/.orchestrator"
  rm -f "$TMP_SPEC_RAW"
  while IFS='|' read -r SCAT SREL STITLE; do
    [ -n "$SREL" ] || continue
    _sbase=${SCAT#spec:}
    _spath="spec/${_sbase}.md"
    _slabel="$_sbase"
    if [ -n "$STITLE" ] && [ "$STITLE" != "$_sbase" ]; then
      _slabel="$STITLE"
    fi
    emit_leaf_prefer_stub_title 2 "$_slabel" "$_spath"
  done < "$TMP_SPEC"
  rm -f "$TMP_SPEC"
fi

if [ "$HAS_DECISIONS" -eq 1 ]; then
  if [ "$HAS_DECISIONS_EXTRA" -eq 1 ]; then
    # PBJ-2026-05-07 ask 2: when subdir files are present, emit Decisions as a
    # group with the canonical DECISIONS.md as Overview and each subdir file as
    # a child. URL routing: decisions.md -> /decisions/, decisions/<f>.md ->
    # /decisions/<f>/. No collision under use_directory_urls:true because
    # there is no decisions/index.md (the parent decisions.md fills that slot).
    emit_group 1 "Decisions"
    emit_leaf 2 "Overview" "decisions.md"
    # PBJ-2026-05-08: sort by source frontmatter `nav_order:` (asc), alphabetical
    # tiebreak. Files without nav_order: default to 9999 (sort after declared).
    TMP_DEX_RAW="/tmp/wiki-nav-decisions-extra-$$.raw"
    TMP_DEX="/tmp/wiki-nav-decisions-extra-$$.list"
    awk -F'|' '
      $1 ~ /^decisions-extra:/ { print $1 "|" $2 "|" $3 }
    ' "$SCAN_OUT" | sort > "$TMP_DEX_RAW"
    sort_section_with_nav_order "$TMP_DEX_RAW" "$TMP_DEX" "$ROOT/.orchestrator"
    rm -f "$TMP_DEX_RAW"
    while IFS='|' read -r DCAT DREL DTITLE; do
      [ -n "$DREL" ] || continue
      _dbase=${DCAT#decisions-extra:}
      _dpath="decisions/${_dbase}.md"
      _dlabel="$_dbase"
      if [ -n "$DTITLE" ] && [ "$DTITLE" != "$_dbase" ]; then
        _dlabel="$DTITLE"
      fi
      emit_leaf_prefer_stub_title 2 "$_dlabel" "$_dpath"
    done < "$TMP_DEX"
    rm -f "$TMP_DEX"
  else
    emit_leaf 1 "Decisions" "decisions.md"
  fi
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
      # Use the canonical H1 (scanner-extracted) when available — every MEM
      # entry has a `# MEM###: <name>` first line, so KTITLE renders as a
      # human-readable nav label. Falls back to the bare ID when no H1 was
      # found (scanner returns basename in that case, equal to _kbase).
      _klabel="$_kbase"
      if [ -n "$KTITLE" ] && [ "$KTITLE" != "$_kbase" ]; then
        _klabel="$KTITLE"
      fi
      emit_leaf 3 "$_klabel" "$_kpath"
    done < "$TMP_KN"
    rm -f "$TMP_KN"
  done
fi

# PBJ-2026-05-07 forward-roadmap consolidation: when both
# .orchestrator/milestone-summary.md AND at least one milestone:* record exist,
# fold the forward roadmap into the Milestones section's index page (handled
# in wiki-generate-stubs.sh::section_include_for). Suppress the redundant
# top-level "Milestone Summary" leaf so the nav stops competing with itself.
# Greenfield projects with only milestone-summary.md (no milestones tree yet)
# preserve the current top-level leaf so the file remains nav-reachable.
if [ "$HAS_MILSUM" -eq 1 ] && [ "$HAS_ANY_MILESTONE" -eq 0 ]; then
  emit_leaf 1 "Milestone Summary" "milestone-summary.md"
fi

# ---- Proposals section (M032/P04/T01 FR-17) --------------------------------
# Emitted after the existing top-level sections and before the milestones
# section. Section index page (proposals/index.md) is auto-rendered by the
# stub generator (see wiki-generate-stubs.sh case-arm). Entries sort by
# proposals:<basename> ascending.
if [ "$HAS_PROPOSALS" -eq 1 ]; then
  emit_group 1 "Proposals"
  emit_leaf 2 "Overview" "proposals/index.md"
  # PBJ-2026-05-08: sort by source frontmatter `nav_order:` (asc), alphabetical
  # tiebreak. Files without nav_order: default to 9999 (sort after declared).
  TMP_PROP_RAW="/tmp/wiki-nav-proposals-$$.raw"
  TMP_PROP="/tmp/wiki-nav-proposals-$$.list"
  awk -F'|' '
    $1 ~ /^proposals:/ { print $1 "|" $2 "|" $3 }
  ' "$SCAN_OUT" | sort > "$TMP_PROP_RAW"
  sort_section_with_nav_order "$TMP_PROP_RAW" "$TMP_PROP" "$ROOT/.orchestrator"
  rm -f "$TMP_PROP_RAW"
  while IFS='|' read -r PCAT PREL PTITLE; do
    [ -n "$PREL" ] || continue
    _pbase=${PCAT#proposals:}
    _ppath="proposals/${_pbase}.md"
    _plabel="$_pbase"
    if [ -n "$PTITLE" ] && [ "$PTITLE" != "$_pbase" ]; then
      _plabel="$PTITLE"
    fi
    emit_leaf 2 "$_plabel" "$_ppath"
  done < "$TMP_PROP"
  rm -f "$TMP_PROP"
fi

# ---- Feedback section (PBJ-2026-05-08 — Item E) ----------------------------
# Mirrors the Proposals section shape. The scanner has emitted feedback:*
# records since M037/P02/T01 (FR-18); the stub generator routes them to
# wiki/docs/feedback/<basename>.md and registers a section index. The nav arm
# was missing — `feedback/` files landed in wiki/docs/ without a corresponding
# nav entry, surfacing as "not included in nav" mkdocs warnings on every
# project with a populated .orchestrator/feedback/ tree.
#
# Default-on. Projects that want feedback off-nav can opt out via
# INCLUDE_FEEDBACK=0 in the environment (gates emission at scan time, not
# render time — no feedback:* records → HAS_FEEDBACK=0 → section suppressed).
if [ "$HAS_FEEDBACK" -eq 1 ]; then
  emit_group 1 "Feedback"
  emit_leaf 2 "Overview" "feedback/index.md"
  # PBJ-2026-05-08: sort by source frontmatter `nav_order:` (asc), alphabetical
  # tiebreak. Files without nav_order: default to 9999 (sort after declared).
  TMP_FB_RAW="/tmp/wiki-nav-feedback-$$.raw"
  TMP_FB="/tmp/wiki-nav-feedback-$$.list"
  awk -F'|' '
    $1 ~ /^feedback:/ { print $1 "|" $2 "|" $3 }
  ' "$SCAN_OUT" | sort > "$TMP_FB_RAW"
  sort_section_with_nav_order "$TMP_FB_RAW" "$TMP_FB" "$ROOT/.orchestrator"
  rm -f "$TMP_FB_RAW"
  while IFS='|' read -r FCAT FREL FTITLE; do
    [ -n "$FREL" ] || continue
    _fbase=${FCAT#feedback:}
    _fpath="feedback/${_fbase}.md"
    _flabel="$_fbase"
    if [ -n "$FTITLE" ] && [ "$FTITLE" != "$_fbase" ]; then
      _flabel="$FTITLE"
    fi
    emit_leaf 2 "$_flabel" "$_fpath"
  done < "$TMP_FB"
  rm -f "$TMP_FB"
fi

# ---- Extra-dirs sections (M032/P04/T01 FR-18) ------------------------------
# One nav section per declared wiki.extra_dirs entry, labeled Title-Case(<dn>).
# Sections emitted in declaration (= scanner emit-) order. Empty produces zero
# sections (no false-positive). HAS_EXTRA_<dn> per-dir flag implicit via the
# accumulator file's de-duped pass.
if [ -s "$TMP_EXTRA_DNS" ]; then
  # de-dup preserving first-seen order
  TMP_EXTRA_DNS_UNIQ="${TMP_EXTRA_DNS}.uniq"
  awk '!seen[$0]++ { print }' "$TMP_EXTRA_DNS" > "$TMP_EXTRA_DNS_UNIQ"
  while IFS= read -r XDN; do
    [ -n "$XDN" ] || continue
    # PBJ-dogfood B4: prefer configured label from wiki.extra_dir_labels,
    # fall back to the legacy Title-Case projection of the dirname-record.
    _xlabel=$(extra_label_for "$XDN")
    if [ -z "$_xlabel" ]; then
      _xfirst=$(printf '%s' "$XDN" | cut -c1 | tr 'a-z' 'A-Z')
      _xrest=$(printf '%s' "$XDN" | cut -c2-)
      _xlabel="${_xfirst}${_xrest}"
    fi
    emit_group 1 "$_xlabel"
    emit_leaf 2 "Overview" "${XDN}/index.md"
    # PBJ-2026-05-08: sort by source frontmatter `nav_order:` (asc), alphabetical
    # tiebreak. Source paths are repo-rel for extras (vs. .orchestrator-rel for
    # spec/decisions/proposals/feedback). Decoration includes a synthesized
    # CAT field so sort_section_with_nav_order's CAT|REL|TITLE input shape
    # is honored; the helper strips the decoration on output.
    TMP_EX_RAW="/tmp/wiki-nav-extra-$$.raw"
    TMP_EX="/tmp/wiki-nav-extra-$$.list"
    awk -F'|' -v c="extra:${XDN}" '
      $1 == c { print $1 "|" $2 "|" $3 }
    ' "$SCAN_OUT" | sort > "$TMP_EX_RAW"
    sort_section_with_nav_order "$TMP_EX_RAW" "$TMP_EX" "$ROOT"
    rm -f "$TMP_EX_RAW"
    while IFS='|' read -r XCAT XREL XTITLE; do
      [ -n "$XREL" ] || continue
      _xbase=$(basename "$XREL" .md)
      _xpath="${XDN}/${_xbase}.md"
      _xitemlabel="$_xbase"
      if [ -n "$XTITLE" ] && [ "$XTITLE" != "$_xbase" ]; then
        _xitemlabel="$XTITLE"
      fi
      # M037/P01/T02 FR-6: prefer stub `title:` (FR-5 projected from
      # source `version:`) over the scanner H1-derived XTITLE.
      emit_leaf_prefer_stub_title 2 "$_xitemlabel" "$_xpath"
    done < "$TMP_EX"
    rm -f "$TMP_EX"
  done < "$TMP_EXTRA_DNS_UNIQ"
  rm -f "$TMP_EXTRA_DNS_UNIQ"
fi

# ---- Knowledge — Flat section (M032/P04/T01 FR-19) -------------------------
# Sibling to the categorized Knowledge — Patterns/Conventions/Lessons
# subgroups (which live under "Knowledge Entries"). Emitted only when the
# scanner observed at least one knowledge-flat record (suppressed when zero).
if [ "$HAS_KNOWLEDGE_FLAT" -eq 1 ]; then
  emit_group 1 "Knowledge — Flat"
  # PBJ-2026-05-08: sort by source frontmatter `nav_order:` (asc), alphabetical
  # tiebreak. KFREL is .orchestrator-rel ("knowledge/<file>"), so source-base
  # is $ROOT/.orchestrator. Decoration uses CAT="knowledge-flat" prefix.
  TMP_KFL_RAW="/tmp/wiki-nav-flat-$$.raw"
  TMP_KFL="/tmp/wiki-nav-flat-$$.list"
  awk -F'|' '
    $1 == "knowledge-flat" { print $1 "|" $2 "|" $3 }
  ' "$SCAN_OUT" | sort > "$TMP_KFL_RAW"
  sort_section_with_nav_order "$TMP_KFL_RAW" "$TMP_KFL" "$ROOT/.orchestrator"
  rm -f "$TMP_KFL_RAW"
  while IFS='|' read -r KFCAT KFREL KFTITLE; do
    [ -n "$KFREL" ] || continue
    _kfbase=$(basename "$KFREL" .md)
    # KFREL is "knowledge/<file>" relative to .orchestrator/. Stub lives at
    # wiki/docs/knowledge/<file>.md, so the nav path mirrors KFREL.
    _kfpath="$KFREL"
    _kflabel="$_kfbase"
    if [ -n "$KFTITLE" ] && [ "$KFTITLE" != "$_kfbase" ]; then
      _kflabel="$KFTITLE"
    fi
    # M037/P01/T02 FR-6: prefer stub `title:` projected from source `version:`.
    emit_leaf_prefer_stub_title 2 "$_kflabel" "$_kfpath"
  done < "$TMP_KFL"
  rm -f "$TMP_KFL"
fi

# ---- Milestones group ------------------------------------------------------
# Determine whether any milestone IDs exist. If yes, emit the group with
# Overview + per-milestone subgroups. HAS_ANY_MILESTONE / HAS_ANY_ARCHIVE
# already pre-computed above the top-level-leaf section so the
# forward-roadmap consolidation gate (PBJ-2026-05-07) had access to them.

if [ "$HAS_ANY_MILESTONE" -eq 1 ]; then
  emit_group 1 "Milestones"
  emit_leaf 2 "Overview" "milestones/index.md"

  # For each milestone ID (sorted by the two-bucket rule above: numeric
  # M[0-9]…  first by version compare, non-numeric IDs after, lex):
  grep '^M:' "$TMP_IDS" | sed 's/^M://' | while IFS= read -r MID; do
    [ -n "$MID" ] || continue
    emit_group 2 "$(milestone_label "$MID")"
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
    emit_group 2 "$(milestone_label "$MID")"
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

printf '%s\n' "$MARKER_AUTO_END" >> "$NAV_BODY"

# ---- dry-run short-circuit -------------------------------------------------
if [ "$DRY_RUN" -eq 1 ]; then
  cat "$NAV_BODY"
  exit 0
fi

# ---- ensure markers + migrate from legacy + preserve custom region --------
# FR-14 + MIT-005 region split (T03).
# Branches:
#   (1) Brand-new mkdocs.yml — no auto-nav markers AND no legacy markers.
#       Append both region pairs at EOF: auto-nav (will be filled by the
#       splice that follows) + empty custom-nav region.
#   (2) Already-migrated — auto-nav markers present.
#       Preserve the existing custom-nav region (or self-heal an empty one
#       per US-5 AS-3 if it has been deleted).
#   (3) Legacy migration — legacy markers present, no auto-nav markers yet.
#       (3a) Empty legacy content: rename markers in-place, append empty
#            custom-nav block. Zero behavior change. No diagnostic.
#       (3b) Non-empty legacy content (MIT-005): rename markers in-place,
#            move non-empty content verbatim into a new custom-nav region.
#            Emit stdout diagnostic naming the preserved-entry count.

HAS_AUTO_NAV=0
HAS_LEGACY_NAV=0
HAS_CUSTOM_NAV=0
LEGACY_LINE_COUNT=0

if grep -qF "$MARKER_AUTO_START" "$CONFIG"; then
  HAS_AUTO_NAV=1
fi
if grep -qF "$LEGACY_MARKER_START" "$CONFIG"; then
  HAS_LEGACY_NAV=1
fi
if grep -qF "$MARKER_CUSTOM_START" "$CONFIG"; then
  HAS_CUSTOM_NAV=1
fi

# Helper: count non-blank, non-comment lines between two markers in $CONFIG.
count_between_markers() {
  _ms="$1"
  _me="$2"
  awk -v s="$_ms" -v e="$_me" '
    BEGIN { state="pre"; n=0 }
    {
      if (state == "pre") { if ($0 == s) state="in"; next }
      if (state == "in")  { if ($0 == e) { state="post"; next }
                            if ($0 ~ /^[[:space:]]*$/) next
                            if ($0 ~ /^[[:space:]]*#/) next
                            n++; next }
    }
    END { print n }
  ' "$CONFIG"
}

# Helper: extract content between two markers in $CONFIG to a temp file.
# Strips the markers themselves; preserves all other lines verbatim.
#
# PBJ-dogfood B2 fix: also strips a literal top-level `nav:` line so that
# legacy migration into the custom-nav region cannot leak a duplicate
# `nav:` YAML key (YAML last-key-wins would silently override the
# freshly-regenerated auto-nav). The custom-nav region's contract is
# "list items merged into auto-nav" — it must not redeclare `nav:`.
extract_between_markers() {
  _ms="$1"
  _me="$2"
  _out="$3"
  awk -v s="$_ms" -v e="$_me" -v out="$_out" '
    BEGIN { state="pre" }
    {
      if (state == "pre") { if ($0 == s) state="in"; next }
      if (state == "in")  {
        if ($0 == e) { state="post"; next }
        # Drop a bare top-level `nav:` declaration (PBJ-dogfood B2).
        if ($0 ~ /^[[:space:]]*nav[[:space:]]*:[[:space:]]*$/) next
        print > out; next
      }
    }
  ' "$CONFIG"
  [ -f "$_out" ] || : > "$_out"
}

# Branch dispatcher.
LEGACY_PRESERVED=""  # path to temp file holding non-empty legacy content (set by branch 3b)
if [ "$HAS_AUTO_NAV" -eq 0 ] && [ "$HAS_LEGACY_NAV" -eq 1 ]; then
  # Branch 3 — legacy migration.
  LEGACY_LINE_COUNT=$(count_between_markers "$LEGACY_MARKER_START" "$LEGACY_MARKER_END")
  if [ "$LEGACY_LINE_COUNT" -gt 0 ]; then
    # 3b: MIT-005 non-empty migration. Preserve content for the custom-nav region.
    LEGACY_PRESERVED="/tmp/wiki-nav-legacy-preserved-$$.yml"
    extract_between_markers "$LEGACY_MARKER_START" "$LEGACY_MARKER_END" "$LEGACY_PRESERVED"
    printf 'Migrated %d custom nav entries from legacy markers to custom-nav region\n' "$LEGACY_LINE_COUNT"
  fi
  # Strip the legacy markers + any between-marker content from $CONFIG.
  TMP_DELEG="/tmp/wiki-nav-no-legacy-$$.yml"
  awk -v s="$LEGACY_MARKER_START" -v e="$LEGACY_MARKER_END" '
    BEGIN { state="pre" }
    {
      if (state == "pre") { if ($0 == s) { state="in"; next }; print; next }
      if (state == "in")  { if ($0 == e) { state="post"; next }; next }
      print
    }
  ' "$CONFIG" > "$TMP_DELEG"
  mv "$TMP_DELEG" "$CONFIG"
  HAS_LEGACY_NAV=0
fi

if [ "$HAS_AUTO_NAV" -eq 0 ]; then
  # Append the new auto-nav region pair at EOF (will be replaced by the
  # splice that follows). Append the custom-nav region pair immediately after.
  # If LEGACY_PRESERVED is set, use its content for the custom-nav region.
  {
    printf '\n'
    printf '%s\n' "$MARKER_AUTO_START"
    printf '%s\n' "$MARKER_AUTO_END"
    printf '%s\n' "$MARKER_CUSTOM_START"
    if [ -n "$LEGACY_PRESERVED" ] && [ -f "$LEGACY_PRESERVED" ]; then
      cat "$LEGACY_PRESERVED"
      rm -f "$LEGACY_PRESERVED"
    fi
    printf '%s\n' "$MARKER_CUSTOM_END"
  } >> "$CONFIG"
  HAS_AUTO_NAV=1
  HAS_CUSTOM_NAV=1
fi

# Branch 2: AS-3 self-healing — auto-nav exists but custom-nav does not.
if [ "$HAS_AUTO_NAV" -eq 1 ] && [ "$HAS_CUSTOM_NAV" -eq 0 ]; then
  # Insert empty custom-nav region immediately after MARKER_AUTO_END.
  TMP_HEAL="/tmp/wiki-nav-heal-$$.yml"
  awk -v e="$MARKER_AUTO_END" -v cs="$MARKER_CUSTOM_START" -v ce="$MARKER_CUSTOM_END" '
    {
      print
      if ($0 == e) {
        print cs
        print ce
      }
    }
  ' "$CONFIG" > "$TMP_HEAL"
  mv "$TMP_HEAL" "$CONFIG"
  HAS_CUSTOM_NAV=1
fi

# Splice: replace content between MARKER_AUTO_START and MARKER_AUTO_END with
# the freshly-rendered NAV_BODY (which itself begins with MARKER_AUTO_START and
# ends with MARKER_AUTO_END). Same awk-split-concat pattern as the legacy splice.
awk -v s="$MARKER_AUTO_START" -v e="$MARKER_AUTO_END" \
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
