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
# Usage: bash scripts/wiki/wiki-generate-stubs.sh [--dry-run] [--root PROJECT_ROOT] [--cards-only]
# Exit 0 on success; 1 on scanner failure; 2 on write error.
# Bash 3.2 compatible — no `declare -A`, no `mapfile`, no `${var^^}`,
# no process substitution, no `&>`.
#
# --cards-only: invoke render_landing_cards (M037/P01/T01 FR-1) and exit.
# Skips scanner + clean phase + per-record stub emission. Used by the
# M037 P01 acceptance harness for fast targeted exercising.

set -u

# ---- argument parsing -------------------------------------------------------
DRY_RUN=0
ROOT=""
CARDS_ONLY=0

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
    --cards-only)
      CARDS_ONLY=1
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
# Always canonicalize to an absolute path. The flag-less branch already does
# this via `cd ... && pwd`; the explicit `--root` branch must match, because
# downstream emitters bake $ROOT into stub comments (`Source metadata: …`)
# and pattern-match against $ROOT in `project_external_pointer` ("file://$ROOT/"*).
# A relative literal (e.g. `--root .`) silently produces stubs that differ from
# the absolute-path form, causing `wiki-stubs-fresh.sh` to false-FAIL on
# `wiki.extra_dirs` content. (PBJ-2026-05-08)
if [ -z "$ROOT" ]; then
  SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
  ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
else
  if [ ! -d "$ROOT" ]; then
    printf 'ERROR: PROJECT_ROOT does not exist: %s\n' "$ROOT" >&2
    exit 2
  fi
  ROOT=$(cd "$ROOT" && pwd)
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

if [ "$CARDS_ONLY" -eq 0 ]; then
  if [ ! -x "$SCANNER" ] && [ ! -f "$SCANNER" ]; then
    printf 'ERROR: scanner not found: %s (run T02 first)\n' "$SCANNER" >&2
    exit 1
  fi
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
    top:spikes)            printf 'spikes/index.md' ;;
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

# write_stub <target-abs-path> <canonical-path> <title> [<canonical-abs-path>] [<rewrite-relative-urls>]
# When <canonical-abs-path> is provided and the file begins with `---`, the
# include directive emits `start="\n---\n"` to skip past YAML frontmatter so
# the rendered body starts at the H1 instead of dumping the frontmatter as
# prose. Plugin's interpret_escapes resolves `\n` → newline (verified against
# mkdocs-include-markdown-plugin v7.1.2).
#
# PBJ-dogfood B5: <rewrite-relative-urls> param (default "true") controls the
# include directive's relative-URL rewrite behavior. Set to "false" by callers
# whose canonical doc primarily uses fragment-only (`#anchor`) intra-doc
# links — include-markdown-plugin's rewrite-relative-urls=true rewrites
# fragment-only hrefs by prepending the source-relative path
# (e.g., `#foo` → `../../.orchestrator#foo`), producing silent 404s.
# Singleton top-level docs (constitution, decisions, knowledge,
# milestone-summary, spikes, glossary, knowledge-flat, proposals) opt out.
write_stub() {
  _target="$1"
  _canonical="$2"
  _title="$3"
  _canonical_abs="${4:-}"
  _rewrite_rel_urls="${5:-true}"
  # M037/P01/T02 MIT-01 P0: operator escape hatch. When an existing stub
  # carries `auto_generated: false` in its frontmatter, do NOT overwrite.
  if existing_stub_is_protected "$_target"; then
    printf 'STUB-PRESERVED: %s (auto_generated: false)\n' "$_target" >&2
    return 0
  fi
  # M037/P01/T02 FR-5: read source chunk `version:` and project to stub
  # title:. Falls back to caller-supplied $_title when version: absent.
  if [ -n "$_canonical_abs" ] && [ -f "$_canonical_abs" ]; then
    _title=$(derive_stub_title "$_canonical_abs" "$_title")
  fi
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
    printf '  rewrite-relative-urls=%s\n' "$_rewrite_rel_urls"
    printf '%%}\n'
  } > "$_target"
  if [ ! -f "$_target" ]; then
    printf 'ERROR: write failed: %s\n' "$_target" >&2
    exit 2
  fi
  printf 'STUB: %s\n' "$_target" >&2
  STUBS_WRITTEN=$((STUBS_WRITTEN + 1))
}

# body_is_empty <abs-path> -> exits 0 if body is empty, 1 if non-empty
#
# PBJ-dogfood B7: M036 reference-corpus chunks pair a metadata `.md`
# (frontmatter + literal `|` body placeholder) with a Tier-1-extracted
# `.text.md` sibling carrying the real content. Body-empty heuristic:
# strip frontmatter (if present), strip whitespace and any single-`|`
# placeholder line, return "empty" if remaining body has zero non-blank
# chars. Bash 3.2 / awk-only — no bash 4 features.
body_is_empty() {
  _p="$1"
  [ -f "$_p" ] || return 1
  _r=$(awk '
    BEGIN { state="pre"; body_chars=0 }
    NR == 1 && $0 == "---" { state="fm"; next }
    NR == 1 { state="body" }
    state == "fm" {
      if ($0 == "---") { state="body"; next }
      next
    }
    state == "body" {
      line=$0
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      if (line == "" || line == "|") next
      body_chars += length(line)
    }
    END { print (body_chars == 0 ? "empty" : "nonempty") }
  ' "$_p" 2>/dev/null)
  if [ "$_r" = "empty" ]; then
    return 0
  fi
  return 1
}

# emit_frontmatter_metadata_table <abs-path> <out-file>
#
# Reads YAML frontmatter from <abs-path> and appends a Markdown table of
# field|value pairs to <out-file>. No-op when the file has no frontmatter.
# Used by the B7 metadata-table fallback for body-empty extra:* records
# whose `.text.md` sibling is absent (e.g., M036 Tier 0 chunks where the
# real content lives behind external_pointer:). Bash 3.2 / awk-only.
emit_frontmatter_metadata_table() {
  _p="$1"
  _out="$2"
  [ -f "$_p" ] || return 0
  awk '
    BEGIN { state="pre"; have=0 }
    NR == 1 && $0 == "---" { state="fm"; next }
    state == "fm" && $0 == "---" { exit }
    state == "fm" {
      if (match($0, /^[[:space:]]*[A-Za-z_][A-Za-z0-9_-]*[[:space:]]*:[[:space:]]*/)) {
        k=$0
        sub(/^[[:space:]]*/, "", k)
        sub(/[[:space:]]*:.*$/, "", k)
        v=$0
        sub(/^[^:]*:[[:space:]]*/, "", v)
        sub(/[[:space:]]+$/, "", v)
        # collapse pipes in value to keep markdown table cells safe.
        gsub(/\|/, "/", v)
        # strip optional surrounding quotes
        sub(/^["'"'"']/, "", v)
        sub(/["'"'"']$/, "", v)
        if (k != "" && v != "") {
          if (have == 0) {
            print "| Field | Value |"
            print "|-------|-------|"
            have=1
          }
          print "| " k " | " v " |"
        }
      }
    }
  ' "$_p" >> "$_out" 2>/dev/null
}

# write_stub_extra_with_sibling <target> <sibling-canonical> <title> <metadata-abs>
#
# B7 emission: stub for an extra:* record whose source body is empty AND
# a `<basename>.text.md` sibling exists in the same dir. Renders frontmatter
# from <metadata-abs> as a "Source metadata" admonition, then includes the
# sibling's body via include-markdown. rewrite-relative-urls=false because
# Tier-1-extracted text often contains plain-text references that should
# pass through untouched.
write_stub_extra_with_sibling() {
  _target="$1"
  _sibling_canonical="$2"
  _title="$3"
  _metadata_abs="$4"
  # M037/P01/T02 MIT-01 P0: operator escape hatch.
  if existing_stub_is_protected "$_target"; then
    printf 'STUB-PRESERVED: %s (auto_generated: false)\n' "$_target" >&2
    return 0
  fi
  # M037/P01/T02 FR-5: project source `version:` to stub title:.
  if [ -n "$_metadata_abs" ] && [ -f "$_metadata_abs" ]; then
    _title=$(derive_stub_title "$_metadata_abs" "$_title")
  fi
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
  _title_esc=$(printf '%s' "$_title" | sed 's/"/\\"/g')
  _meta_tmp="/tmp/wiki-stubs-meta-$$.tbl"
  : > "$_meta_tmp"
  emit_frontmatter_metadata_table "$_metadata_abs" "$_meta_tmp"
  # M037 P03 (P2.2): also project external_pointer: on the sibling path so
  # the "View source on GitHub" affordance appears whenever the pointer is
  # present, not only when the Tier-1 sibling is absent. Operator quote:
  # "there should at least be a link to the document in our GitHub repo".
  _meta_ext=""
  if [ -n "$_metadata_abs" ] && [ -f "$_metadata_abs" ]; then
    _meta_ext=$(extract_external_pointer "$_metadata_abs")
  fi
  {
    printf -- '---\n'
    printf 'title: "%s"\n' "$_title_esc"
    printf -- '---\n\n'
    printf '<!-- Auto-generated by scripts/wiki/wiki-generate-stubs.sh. Do not hand-edit.\n'
    printf '     Source metadata: %s. Source body: %s (Tier-1 sibling). -->\n\n' \
      "$_metadata_abs" "$_sibling_canonical"
    if [ -s "$_meta_tmp" ]; then
      printf '!!! info "Source metadata"\n\n'
      while IFS= read -r _row; do
        printf '    %s\n' "$_row"
      done < "$_meta_tmp"
      printf '\n'
    fi
    if [ -n "$_meta_ext" ]; then
      _projected=$(project_external_pointer "$_meta_ext")
      case "$_projected" in
        http://*|https://*)
          printf '!!! note "Source document"\n\n'
          printf '    [:octicons-mark-github-16: View source on GitHub](%s)\n\n' "$_projected"
          ;;
      esac
    fi
    printf '{%%\n'
    printf '  include-markdown "%s"\n' "$_sibling_canonical"
    printf '  heading-offset=0\n'
    printf '  rewrite-relative-urls=false\n'
    printf '%%}\n'
  } > "$_target"
  rm -f "$_meta_tmp"
  if [ ! -f "$_target" ]; then
    printf 'ERROR: write failed: %s\n' "$_target" >&2
    exit 2
  fi
  printf 'STUB: %s (B7 metadata+sibling)\n' "$_target" >&2
  STUBS_WRITTEN=$((STUBS_WRITTEN + 1))
}

# write_stub_extra_metadata_only <target> <title> <metadata-abs> <external-pointer-or-empty>
#
# B7 fallback: body-empty extra:* record with NO `.text.md` sibling
# (typical of M036 Tier 0 chunks where the real content lives behind
# external_pointer:). Renders frontmatter as a metadata table + a callout
# linking to external_pointer: when present. Graceful degradation —
# better than rendering a literal `|` body.
write_stub_extra_metadata_only() {
  _target="$1"
  _title="$2"
  _metadata_abs="$3"
  _external_pointer="${4:-}"
  # M037/P01/T02 MIT-01 P0: operator escape hatch.
  if existing_stub_is_protected "$_target"; then
    printf 'STUB-PRESERVED: %s (auto_generated: false)\n' "$_target" >&2
    return 0
  fi
  # M037/P01/T02 FR-5: project source `version:` to stub title:.
  if [ -n "$_metadata_abs" ] && [ -f "$_metadata_abs" ]; then
    _title=$(derive_stub_title "$_metadata_abs" "$_title")
  fi
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
  _title_esc=$(printf '%s' "$_title" | sed 's/"/\\"/g')
  _meta_tmp="/tmp/wiki-stubs-meta-$$.tbl"
  : > "$_meta_tmp"
  emit_frontmatter_metadata_table "$_metadata_abs" "$_meta_tmp"
  {
    printf -- '---\n'
    printf 'title: "%s"\n' "$_title_esc"
    printf -- '---\n\n'
    printf '<!-- Auto-generated by scripts/wiki/wiki-generate-stubs.sh. Do not hand-edit.\n'
    printf '     Source metadata: %s. No Tier-1 sibling on disk. -->\n\n' "$_metadata_abs"
    if [ -s "$_meta_tmp" ]; then
      printf '!!! info "Source metadata"\n\n'
      while IFS= read -r _row; do
        printf '    %s\n' "$_row"
      done < "$_meta_tmp"
      printf '\n'
    fi
    if [ -n "$_external_pointer" ]; then
      # M037 P03 (P2.2): project file:///<ROOT>/<rest> to a clickable
      # GitHub source link when repo_url is configured. Falls back to the
      # original pointer (rendered as code) when projection fails or the
      # scheme is not file://.
      _projected=$(project_external_pointer "$_external_pointer")
      printf '!!! note "Source content"\n\n'
      printf '    Tier-1 extraction not available on disk.\n\n'
      case "$_projected" in
        http://*|https://*)
          printf '    [:octicons-mark-github-16: View source on GitHub](%s)\n\n' "$_projected"
          printf '    Original pointer: `%s`\n' "$_external_pointer"
          ;;
        *)
          printf '    See: `%s`\n' "$_external_pointer"
          ;;
      esac
    else
      printf '!!! note "Source content"\n\n'
      printf '    No body content extracted; metadata only.\n'
    fi
  } > "$_target"
  rm -f "$_meta_tmp"
  if [ ! -f "$_target" ]; then
    printf 'ERROR: write failed: %s\n' "$_target" >&2
    exit 2
  fi
  printf 'STUB: %s (B7 metadata-only)\n' "$_target" >&2
  STUBS_WRITTEN=$((STUBS_WRITTEN + 1))
}

# M037 P03 (P2.2) — read_repo_url + project_external_pointer.
#
# read_repo_url: parses repo_url: from $ROOT/wiki/mkdocs.yml. Empty stdout
# when the config or the field is absent. Strips one layer of quotes and
# trailing /.
read_repo_url() {
  _cfg="$ROOT/wiki/mkdocs.yml"
  [ -f "$_cfg" ] || return 0
  awk '
    /^repo_url:[[:space:]]*/ {
      v=$0
      sub(/^repo_url:[[:space:]]*/, "", v)
      sub(/[[:space:]]+$/, "", v)
      sub(/^"/, "", v); sub(/"$/, "", v)
      sub(/^\047/, "", v); sub(/\047$/, "", v)
      sub(/\/$/, "", v)
      print v
      exit
    }
  ' "$_cfg" 2>/dev/null
}

# project_external_pointer <pointer-value>
#
# PBJ-dogfood M037 P03 (P2.2): file:///<ROOT>/<rest> projects to
# <repo_url>/blob/main/<rest> (clickable "View source on GitHub" target);
# non-file:// pointers pass through unchanged so http(s):// callouts and
# other schemes still render. Empty stdout on empty input. When repo_url:
# is unavailable the pointer also passes through unchanged so callers can
# distinguish "projected" (http(s)) from "literal" (file://) without a
# second hint flag.
project_external_pointer() {
  _ptr="$1"
  [ -n "$_ptr" ] || return 0
  case "$_ptr" in
    "file://$ROOT/"*)
      _rest=${_ptr#"file://$ROOT/"}
      _ru=$(read_repo_url)
      if [ -n "$_ru" ]; then
        printf '%s/blob/main/%s' "$_ru" "$_rest"
        return 0
      fi
      printf '%s' "$_ptr"
      ;;
    *)
      printf '%s' "$_ptr"
      ;;
  esac
}

# extract_external_pointer <abs-path>
#
# Reads YAML frontmatter from <abs-path> and prints the `external_pointer:`
# value (if any). Empty stdout when absent. Used by the metadata-only
# fallback to surface a Tier 0 source path.
extract_external_pointer() {
  _p="$1"
  [ -f "$_p" ] || return 0
  awk '
    BEGIN { state="pre" }
    NR == 1 && $0 == "---" { state="fm"; next }
    state == "fm" && $0 == "---" { exit }
    state == "fm" && $0 ~ /^[[:space:]]*external_pointer[[:space:]]*:[[:space:]]*/ {
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

# read_frontmatter_field <abs-path> <field-name>
#
# M037/P01/T02 FR-5: reads a single YAML frontmatter field's value from
# <abs-path> and prints it on stdout. Empty stdout when the file does not
# exist, has no frontmatter, or the field is absent. Strips one layer of
# surrounding single- or double-quotes (matches the existing
# extract_external_pointer pattern). Bash 3.2 / awk-only.
read_frontmatter_field() {
  _p="$1"
  _f="$2"
  [ -f "$_p" ] || return 0
  [ -n "$_f" ] || return 0
  awk -v field="$_f" '
    BEGIN {
      state="pre"
      pat="^[[:space:]]*" field "[[:space:]]*:[[:space:]]*"
    }
    NR == 1 && $0 == "---" { state="fm"; next }
    state == "fm" && $0 == "---" { exit }
    state == "fm" && $0 ~ pat {
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

# derive_stub_title <canonical-abs> <fallback-title> [<chunk-id-slug>]
#
# M037/P01/T02 FR-5: returns the title to use for a stub's frontmatter.
# Reads the source chunk's `version:` field; on absent, falls back to
# <chunk-id-slug> when provided, else <fallback-title>. Empty stdout
# triggers the caller's own fallback. Emits a debug-level diagnostic to
# stderr when WIKI_DEBUG=1 is set.
derive_stub_title() {
  _canon="$1"
  _fallback="$2"
  _slug="${3:-}"
  _ver=""
  if [ -n "$_canon" ] && [ -f "$_canon" ]; then
    _ver=$(read_frontmatter_field "$_canon" "version")
  fi
  if [ -n "$_ver" ]; then
    printf '%s' "$_ver"
    return 0
  fi
  if [ -n "$_slug" ]; then
    if [ "${WIKI_DEBUG:-0}" = "1" ]; then
      printf 'DEBUG: derive_stub_title: no version: in %s, fell back to chunk-id slug %s\n' \
        "$_canon" "$_slug" >&2
    fi
    printf '%s' "$_slug"
    return 0
  fi
  printf '%s' "$_fallback"
}

# existing_stub_is_protected <target-abs>
#
# M037/P01/T02 FR-5 MIT-01 P0: returns 0 (true) if <target-abs> exists AND
# carries `auto_generated: false` in its frontmatter. Operator escape
# hatch — generator MUST NOT overwrite a stub the operator has marked as
# hand-edited.
existing_stub_is_protected() {
  _t="$1"
  [ -f "$_t" ] || return 1
  _ag=$(read_frontmatter_field "$_t" "auto_generated")
  if [ "$_ag" = "false" ]; then
    return 0
  fi
  return 1
}

# write_index <target-abs-path> <title> <body-file> [<include-canonical>] [<preamble>]
#
# body-file is a tmp file with pre-formatted bullet lines.
# include-canonical (optional) is a path of the form
# "<canonical-rel-from-stub-dir>|<canonical-abs-path>" — when present, the
# index page emits an include-markdown directive for that canonical artifact
# above the bullet list. Used by milestone/phase indexes so the page leads
# with a real summary instead of a bare bullet list (item 2 of the
# wiki-usability pass).
# preamble (optional, M037 P03 P2.1) — a 1-2 sentence orientation paragraph
# rendered between the H1 and the bullet list. Used by extra:* category
# indexes so the page leads with "what is in this category" instead of
# diving straight into a flat bullet list.
write_index() {
  _target="$1"
  _title="$2"
  _bodyfile="$3"
  _include_spec="${4:-}"
  _preamble="${5:-}"
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
    if [ -n "$_preamble" ]; then
      printf '%s\n\n' "$_preamble"
    fi
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

# ---- M037/P01/T01 FR-1 — render_landing_cards -------------------------------
# Reads .orchestrator/config.yml's wiki.landing_cards: block. When non-empty,
# renders one card per record. When empty/absent, falls back to the FR-3 path:
# parses wiki/mkdocs.yml's nav: block for top-level section names, intersects
# with the DEFAULT_BLURBS table inside templates/wiki-index-cards.md.tmpl, and
# emits one card per intersection.
#
# Output: a `<div class="grid cards" markdown>...</div>` block bracketed by
# `<!-- M037-LANDING-CARDS-BEGIN -->` / `<!-- M037-LANDING-CARDS-END -->`
# sentinels, written into wiki/docs/index.md. Idempotent re-runs:
#   - sentinels present  -> replace bracketed region only
#   - sentinels absent + frontmatter present -> insert immediately after fm
#   - sentinels absent + no frontmatter      -> prepend at top of file
#   - index.md absent     -> create with frontmatter + H1 + cards block
#   - zero cards          -> leave index.md unchanged (US-1 edge case)
#
# Bash 3.2 + POSIX sh compatible. No associative arrays, no process
# substitution, no command substitution containing pipes.
render_landing_cards() {
  _config="$ROOT/.orchestrator/config.yml"
  _tmpl="$ROOT/templates/wiki-index-cards.md.tmpl"
  _mkdocs="$ROOT/wiki/mkdocs.yml"
  _index="$DOCS/index.md"

  if [ ! -f "$_tmpl" ]; then
    printf 'WARN: render_landing_cards: template not found: %s\n' "$_tmpl" >&2
    return 0
  fi

  _cards_tmp="/tmp/wiki-cards-$$.list"
  : > "$_cards_tmp"

  # 1. Try operator-configured landing_cards from .orchestrator/config.yml.
  _has_operator=0
  if [ -f "$_config" ]; then
    awk '
      function emit() {
        if (idx>0 && (sec != "" || icn != "" || ttl != "" || blb != "")) {
          printf "%d|%s|%s|%s|%s\n", idx, sec, icn, ttl, blb
        }
        sec=""; icn=""; ttl=""; blb=""
      }
      function strip(s) {
        sub(/^[[:space:]]+/, "", s)
        sub(/[[:space:]]+$/, "", s)
        sub(/^"/, "", s); sub(/"$/, "", s)
        sub(/^\047/, "", s); sub(/\047$/, "", s)
        return s
      }
      function set_field(k, v) {
        if (k=="section") sec=v
        else if (k=="icon") icn=v
        else if (k=="title") ttl=v
        else if (k=="blurb") blb=v
      }
      BEGIN { state="pre"; idx=0; sec=""; icn=""; ttl=""; blb="" }
      /^wiki:[[:space:]]*$/ { state="wiki"; next }
      state=="wiki" && /^[^[:space:]#]/ { emit(); exit }
      state=="wiki" && /^  landing_cards:[[:space:]]*\[\][[:space:]]*$/ { exit }
      state=="wiki" && /^  landing_cards:[[:space:]]*$/ { state="cards"; next }
      state=="cards" && /^[^[:space:]#]/ { emit(); exit }
      state=="cards" && /^  [a-zA-Z]/ { emit(); exit }
      state=="cards" && /^    -[[:space:]]+[a-zA-Z_]+:/ {
        emit()
        idx++
        line=$0
        sub(/^    -[[:space:]]+/, "", line)
        if (match(line, /^[a-zA-Z_]+:/)) {
          k=substr(line, 1, RLENGTH-1)
          v=substr(line, RLENGTH+1)
          set_field(k, strip(v))
        }
        next
      }
      state=="cards" && /^      [a-zA-Z_]+:/ {
        line=$0
        sub(/^      /, "", line)
        if (match(line, /^[a-zA-Z_]+:/)) {
          k=substr(line, 1, RLENGTH-1)
          v=substr(line, RLENGTH+1)
          set_field(k, strip(v))
        }
        next
      }
      END { emit() }
    ' "$_config" >> "$_cards_tmp" 2>/dev/null
    if [ -s "$_cards_tmp" ]; then
      _has_operator=1
    fi
  fi

  # 2. Fallback: enumerate top-level nav from wiki/mkdocs.yml, intersect with
  # DEFAULT_BLURBS from the template.
  if [ "$_has_operator" -eq 0 ] && [ -f "$_mkdocs" ]; then
    _nav_tmp="/tmp/wiki-nav-top-$$.list"
    awk '
      BEGIN { in_nav=0 }
      /^nav:[[:space:]]*$/ { in_nav=1; next }
      in_nav && /^[^[:space:]#]/ { exit }
      in_nav && /^  - / {
        line=$0
        sub(/^  - /, "", line)
        if (match(line, /:/)) {
          name=substr(line, 1, RSTART-1)
          sub(/^"/, "", name); sub(/"$/, "", name)
          print name
        }
      }
    ' "$_mkdocs" > "$_nav_tmp" 2>/dev/null

    _blurbs_tmp="/tmp/wiki-blurbs-$$.list"
    awk '
      BEGIN { in_block=0 }
      /^# DEFAULT_BLURBS$/ { in_block=1; next }
      /^# END_DEFAULT_BLURBS$/ { in_block=0; exit }
      in_block && /^# [A-Za-z]/ {
        line=$0
        sub(/^# /, "", line)
        print line
      }
    ' "$_tmpl" > "$_blurbs_tmp" 2>/dev/null

    _idx=0
    while IFS= read -r _name; do
      [ -n "$_name" ] || continue
      case "$_name" in
        Home) continue ;;
      esac
      _match=$(awk -F'|' -v n="$_name" '$1 == n { print $0; exit }' "$_blurbs_tmp")
      [ -n "$_match" ] || continue
      _icon=$(printf '%s\n' "$_match" | awk -F'|' '{print $2}')
      _title=$(printf '%s\n' "$_match" | awk -F'|' '{print $3}')
      _blurb=$(printf '%s\n' "$_match" | awk -F'|' '{print $4}')
      _path=$(printf '%s\n' "$_match" | awk -F'|' '{print $5}')
      _idx=$((_idx + 1))
      printf '%d|%s|%s|%s|%s\n' "$_idx" "$_path" "$_icon" "$_title" "$_blurb" >> "$_cards_tmp"
    done < "$_nav_tmp"

    rm -f "$_nav_tmp" "$_blurbs_tmp"
  fi

  if [ ! -s "$_cards_tmp" ]; then
    rm -f "$_cards_tmp"
    printf 'CARDS: 0 cards rendered (no operator config + no nav intersection); %s unchanged\n' "$_index" >&2
    return 0
  fi

  # M037 P03 (P1.2): pre-filter orphans so we neither emit broken
  # #orphan-card-${slug} anchors nor leave an empty <div class="grid cards">
  # block when *every* card resolves to an orphan target.
  _filtered_tmp="/tmp/wiki-cards-filtered-$$.list"
  : > "$_filtered_tmp"
  while IFS='|' read -r _i _sec _icn _ttl _blb; do
    [ -n "$_i" ] || continue
    _exists=0
    if [ -n "$_sec" ]; then
      _check="$DOCS/$_sec"
      _check_dir=$(printf '%s' "$_check" | sed 's:/*$::')
      if [ -f "$_check" ] || [ -f "$_check_dir/index.md" ]; then
        _exists=1
      fi
    fi
    if [ "$_exists" -eq 0 ]; then
      printf 'CARDS: orphan section "%s" — dropped (no target page)\n' "$_sec" >&2
      continue
    fi
    printf '%s|%s|%s|%s|%s\n' "$_i" "$_sec" "$_icn" "$_ttl" "$_blb" >> "$_filtered_tmp"
  done < "$_cards_tmp"

  if [ ! -s "$_filtered_tmp" ]; then
    rm -f "$_cards_tmp" "$_filtered_tmp"
    printf 'CARDS: 0 cards rendered (all orphan after target-page check); %s unchanged\n' "$_index" >&2
    return 0
  fi
  mv "$_filtered_tmp" "$_cards_tmp"

  _card_count=$(wc -l < "$_cards_tmp" | tr -d ' ')

  # 3. Render the grid-cards block.
  _render_tmp="/tmp/wiki-cards-render-$$.md"
  {
    printf '<!-- M037-LANDING-CARDS-BEGIN -->\n'
    printf '<div class="grid cards" markdown>\n\n'
    while IFS='|' read -r _i _sec _icn _ttl _blb; do
      [ -n "$_i" ] || continue
      _href="$_sec"
      if [ -n "$_icn" ]; then
        printf -- '- :%s: **%s**\n\n' "$_icn" "$_ttl"
      else
        printf -- '- **%s**\n\n' "$_ttl"
      fi
      printf '    ---\n\n'
      printf '    %s\n\n' "$_blb"
      printf '    [:octicons-arrow-right-24: %s](%s)\n\n' "$_ttl" "$_href"
    done < "$_cards_tmp"
    printf '</div>\n'
    printf '<!-- M037-LANDING-CARDS-END -->\n'
  } > "$_render_tmp"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'WOULD-WRITE-CARDS: %s (%d cards)\n' "$_index" "$_card_count" >&2
    rm -f "$_cards_tmp" "$_render_tmp"
    return 0
  fi

  # 4. Write to wiki/docs/index.md.
  _new_tmp="/tmp/wiki-index-new-$$.md"
  if [ ! -f "$_index" ]; then
    {
      printf -- '---\n'
      printf 'title: "Home"\n'
      printf -- '---\n\n'
      printf '# Home\n\n'
      cat "$_render_tmp"
    } > "$_index"
    printf 'CARDS: created %s with %d-card grid\n' "$_index" "$_card_count" >&2
  elif grep -q '<!-- M037-LANDING-CARDS-BEGIN -->' "$_index"; then
    awk -v render="$_render_tmp" '
      BEGIN {
        in_block=0
        replacement=""
        while ((getline line < render) > 0) replacement = replacement line "\n"
        close(render)
      }
      /<!-- M037-LANDING-CARDS-BEGIN -->/ {
        printf "%s", replacement
        in_block=1
        next
      }
      /<!-- M037-LANDING-CARDS-END -->/ {
        in_block=0
        next
      }
      in_block == 0 { print }
    ' "$_index" > "$_new_tmp"
    mv "$_new_tmp" "$_index"
    printf 'CARDS: replaced bracketed region in %s (%d cards)\n' "$_index" "$_card_count" >&2
  else
    _has_fm=0
    _first=$(head -n 1 "$_index" 2>/dev/null)
    if [ "$_first" = "---" ]; then
      _has_fm=1
    fi
    if [ "$_has_fm" -eq 1 ]; then
      awk -v render="$_render_tmp" '
        BEGIN {
          state="pre"
          replacement=""
          while ((getline line < render) > 0) replacement = replacement line "\n"
          close(render)
        }
        NR==1 && $0 == "---" { state="fm"; print; next }
        state=="fm" && $0 == "---" { print; print ""; printf "%s\n", replacement; state="post"; next }
        { print }
      ' "$_index" > "$_new_tmp"
    else
      {
        cat "$_render_tmp"
        printf '\n'
        cat "$_index"
      } > "$_new_tmp"
    fi
    mv "$_new_tmp" "$_index"
    printf 'CARDS: prepended grid into %s (%d cards)\n' "$_index" "$_card_count" >&2
  fi

  rm -f "$_cards_tmp" "$_render_tmp"
  return 0
}

# ---- clean phase ------------------------------------------------------------
# Remove every .md under wiki/docs/ except the top-level index.md and README.md.

clean_phase() {
  if [ ! -d "$DOCS" ]; then
    return 0
  fi
  # Count first for reporting.
  _list="/tmp/wiki-stubs-clean-$$.list"
  # M040 follow-up (2026-05-09): exclude `*.summary.md` siblings from
  # the stale-file sweep. The wiki-readability decorator (FR-24) reads a
  # sibling `<stub>.summary.md` next to each stub and bakes its body into
  # the stub as an `!!! info "In plain English"` admonition. The summary
  # file is operator-authored content, not regenerable from
  # `.orchestrator/`. Without this exclusion, regen sweeps every
  # `*.summary.md` as "stale" — silent data loss surfaced in PBJ-central
  # 2026-05-09 (44 summaries deleted on a single `wiki-init --refresh`).
  # See specs/040-wiki-readability-decorator/spec.md FR-28.
  find "$DOCS" -mindepth 1 -type f -name '*.md' \
    ! -name '*.summary.md' \
    ! -path "$DOCS/index.md" \
    ! -path "$DOCS/README.md" \
    -print > "$_list" 2>/dev/null || true
  while IFS= read -r _f; do
    [ -n "$_f" ] || continue
    # M037/P01/T02 MIT-01 P0: skip stubs the operator has marked
    # auto_generated: false. The clean_phase + main-loop write sequence
    # would otherwise wipe operator edits before write_stub's escape-hatch
    # gate could fire. Both gates are required: clean_phase to preserve
    # across re-runs, write_stub to preserve when the source chunk would
    # otherwise re-generate the stub.
    if existing_stub_is_protected "$_f"; then
      printf 'STUB-PRESERVED: %s (auto_generated: false, clean_phase)\n' "$_f" >&2
      continue
    fi
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

# ---- M037/P01/T01 — --cards-only short-circuit ------------------------------
# All function definitions above are now in scope. When --cards-only is set,
# render the homepage card grid only and skip scanner / clean / stub-emission.
if [ "$CARDS_ONLY" -eq 1 ]; then
  render_landing_cards
  exit 0
fi

# ---- collect scanner output -------------------------------------------------

SCAN_OUT="/tmp/wiki-stubs-scan-$$.list"
TITLES_FILE="/tmp/wiki-stubs-titles-$$.tsv"
trap 'rm -f "$SCAN_OUT" "$TITLES_FILE"' EXIT INT TERM

if ! bash "$SCANNER" --root "$ROOT" > "$SCAN_OUT" 2>/dev/null; then
  printf 'ERROR: scanner failed\n' >&2
  exit 1
fi

# PBJ-2026-05-07 forward-roadmap consolidation predicate.
# Active when the project ships BOTH the forward roadmap
# (.orchestrator/milestone-summary.md → top:milestone-summary scanner record)
# AND at least one milestone:* record. Under that condition:
#   1. section_include_for "milestones" folds milestone-summary.md into
#      wiki/docs/milestones/index.md.
#   2. The top-level `milestone-summary.md` stub is suppressed (the content
#      is now reachable via the Milestones section index — keeping the
#      separate stub would orphan under mkdocs --strict).
#   3. wiki-generate-nav.sh suppresses the top-level "Milestone Summary"
#      leaf using the same predicate (computed there from the same scanner
#      output).
# Projects with only one of the two inputs see zero behavior change.
CONSOLIDATION_ACTIVE=0
if grep -q '^top:milestone-summary|' "$SCAN_OUT" && grep -q '^milestone:' "$SCAN_OUT"; then
  CONSOLIDATION_ACTIVE=1
fi
export CONSOLIDATION_ACTIVE

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
  # M037 P03 (P2.1) — optional 4th arg: source-of-truth absolute path. When
  # set, write_section_index_for uses it to read frontmatter `published:`
  # and sort the section index descendingly. Empty for sections (milestones,
  # phases, knowledge, proposals, feedback) that retain alphabetical sort.
  _source_abs="${4:-}"
  printf '%s|%s|%s|%s\n' "$_section_rel" "$_child_rel" "$_child_title" "$_source_abs" >> "$SECTIONS_FILE"
}

# M037 P03 (P2.1) — read_published_date <abs>
# Reads YAML frontmatter `published:` (or `created:` as fallback) and prints
# YYYY-MM-DD on stdout. Empty stdout when neither is present. Used by
# write_section_index_for to sort reference-corpus categories newest-first.
read_published_date() {
  _p="$1"
  [ -f "$_p" ] || return 0
  awk '
    BEGIN { state="pre"; pub=""; cre="" }
    NR == 1 && $0 == "---" { state="fm"; next }
    state == "fm" && $0 == "---" { exit }
    state == "fm" && $0 ~ /^[[:space:]]*published[[:space:]]*:[[:space:]]*/ {
      v=$0
      sub(/^[[:space:]]*published[[:space:]]*:[[:space:]]*/, "", v)
      sub(/[[:space:]]+$/, "", v); sub(/^"/, "", v); sub(/"$/, "", v)
      sub(/^\047/, "", v); sub(/\047$/, "", v)
      pub=v
    }
    state == "fm" && $0 ~ /^[[:space:]]*created[[:space:]]*:[[:space:]]*/ {
      v=$0
      sub(/^[[:space:]]*created[[:space:]]*:[[:space:]]*/, "", v)
      sub(/[[:space:]]+$/, "", v); sub(/^"/, "", v); sub(/"$/, "", v)
      sub(/^\047/, "", v); sub(/\047$/, "", v)
      cre=v
    }
    END { if (pub != "") print pub; else print cre }
  ' "$_p" 2>/dev/null
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

# PBJ-dogfood B4: collect extra-label:<dn>||<label> records into a side-table
# for section_title_for to consult. Consumed only when the main loop has
# finished (so we run a separate pre-pass — these records are skipped during
# the main dispatch).
EXTRA_LABELS_FILE="/tmp/wiki-stubs-extra-labels-$$.list"
: > "$EXTRA_LABELS_FILE"
trap 'rm -f "$SCAN_OUT" "$SECTIONS_FILE" "$KN_PATTERNS_LIST" "$KN_CONVENTIONS_LIST" "$KN_LESSONS_LIST" "$EXTRA_LABELS_FILE"' EXIT INT TERM

while IFS='|' read -r CAT REL TITLE; do
  [ -n "$CAT" ] || continue

  # PBJ-dogfood B4: stash extra-label records, skip dispatch.
  case "$CAT" in
    extra-label:*)
      _xldn=${CAT#extra-label:}
      printf '%s|%s\n' "$_xldn" "$TITLE" >> "$EXTRA_LABELS_FILE"
      continue
      ;;
  esac

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

  # ---- top:glossary routing (M032/P02/T03 FR-15) ---------------------------
  # The glossary lives at <repo-root>/wiki/glossary.md (NOT under
  # .orchestrator/). Route the stub to wiki/docs/glossary.md and resolve the
  # canonical via build_canonical_repo_rel (the canonical lives at the repo
  # root). The nav generator emits `- Glossary: glossary.md` (relative to
  # docs_dir), so the stub MUST land at wiki/docs/glossary.md to match.
  case "$CAT" in
    top:glossary)
      STUB_REL="glossary.md"
      STUB_ABS="$DOCS/$STUB_REL"
      CANONICAL=$(build_canonical_repo_rel "$STUB_REL" "$REL")
      CANONICAL_ABS="$ROOT/$REL"
      # B5: glossary is a self-contained singleton — fragment-only passthrough.
      write_stub "$STUB_ABS" "$CANONICAL" "$TITLE" "$CANONICAL_ABS" "false"
      continue
      ;;
  esac

  # ---- spec:* routing (PBJ-2026-05-07 ask 1) -------------------------------
  # spec:<basename> records route to wiki/docs/spec/<basename>.md. Canonical
  # source lives at .orchestrator/spec/<basename>.md. REL is "spec/<file>".
  # Mirror of proposals:* shape. register_child fires so the section index
  # at wiki/docs/spec/index.md gets auto-emitted listing all spec docs.
  case "$CAT" in
    spec:*)
      _spbase=${CAT#spec:}
      STUB_REL="spec/${_spbase}.md"
      STUB_ABS="$DOCS/$STUB_REL"
      CANONICAL=$(build_canonical "$STUB_REL" "$REL")
      CANONICAL_ABS="$ROOT/.orchestrator/$REL"
      if existing_stub_is_protected "$STUB_ABS"; then
        register_child "spec" "${_spbase}.md" "$TITLE"
        continue
      fi
      # Spec docs are self-contained source-of-truth files — fragment-only
      # passthrough (rewrite-relative-urls=false), matching proposals/feedback.
      write_stub "$STUB_ABS" "$CANONICAL" "$TITLE" "$CANONICAL_ABS" "false"
      register_child "spec" "${_spbase}.md" "$TITLE"
      continue
      ;;
  esac

  # ---- decisions-extra:* routing (PBJ-2026-05-07 ask 2) --------------------
  # decisions-extra:<basename> records route to wiki/docs/decisions/<basename>.md.
  # Canonical source lives at .orchestrator/decisions/<basename>.md. The
  # existing top:decisions arm continues to emit wiki/docs/decisions.md
  # (the DECISIONS.md include) at the section root URL /decisions/. The
  # subdir files live at /decisions/<basename>/. NOT registering a section
  # index for "decisions" -- the parent decisions.md already serves /decisions/.
  case "$CAT" in
    decisions-extra:*)
      _debase=${CAT#decisions-extra:}
      STUB_REL="decisions/${_debase}.md"
      STUB_ABS="$DOCS/$STUB_REL"
      CANONICAL=$(build_canonical "$STUB_REL" "$REL")
      CANONICAL_ABS="$ROOT/.orchestrator/$REL"
      if existing_stub_is_protected "$STUB_ABS"; then
        continue
      fi
      # Decision detail files are self-contained — fragment-only passthrough.
      write_stub "$STUB_ABS" "$CANONICAL" "$TITLE" "$CANONICAL_ABS" "false"
      continue
      ;;
  esac

  # ---- proposals:* routing (M032/P04/T01 FR-17) ----------------------------
  # proposals:<basename> records route to wiki/docs/proposals/<basename>.md.
  # The canonical source lives at .orchestrator/proposals/<basename>.md, so we
  # use build_canonical (which prepends .orchestrator/). REL is "proposals/<file>".
  case "$CAT" in
    proposals:*)
      _pbase=${CAT#proposals:}
      STUB_REL="proposals/${_pbase}.md"
      STUB_ABS="$DOCS/$STUB_REL"
      CANONICAL=$(build_canonical "$STUB_REL" "$REL")
      CANONICAL_ABS="$ROOT/.orchestrator/$REL"
      # B5: proposals are self-contained docs — fragment-only passthrough.
      write_stub "$STUB_ABS" "$CANONICAL" "$TITLE" "$CANONICAL_ABS" "false"
      register_child "proposals" "${_pbase}.md" "$TITLE"
      continue
      ;;
  esac

  # ---- feedback:* routing (M037/P02/T01 FR-18) -----------------------------
  # feedback:<basename> records route to wiki/docs/feedback/<basename>.md.
  # The canonical source lives at .orchestrator/feedback/<basename>.md, so we
  # use build_canonical (which prepends .orchestrator/). REL is "feedback/<file>".
  # Mirror of the proposals:* shape; differs only in path prefix.
  #
  # MIT-01/02 inheritance: operator-edited stubs declaring `auto_generated: false`
  # in their YAML frontmatter survive re-runs byte-identical. The check delegates
  # to the P01/T02 existing_stub_is_protected() helper (write_stub also calls
  # it defensively; this gate ensures register_child still fires for nav while
  # short-circuiting the re-derivation path).
  case "$CAT" in
    feedback:*)
      _fbase=${CAT#feedback:}
      STUB_REL="feedback/${_fbase}.md"
      STUB_ABS="$DOCS/$STUB_REL"
      CANONICAL=$(build_canonical "$STUB_REL" "$REL")
      CANONICAL_ABS="$ROOT/.orchestrator/$REL"
      # MIT-01/02: skip write when operator escape-hatch is set on existing stub.
      if existing_stub_is_protected "$STUB_ABS"; then
        register_child "feedback" "${_fbase}.md" "$TITLE"
        continue
      fi
      # B5: feedback files are self-contained SME signoff captures —
      # fragment-only passthrough (rewrite-relative-urls=false).
      write_stub "$STUB_ABS" "$CANONICAL" "$TITLE" "$CANONICAL_ABS" "false"
      register_child "feedback" "${_fbase}.md" "$TITLE"
      continue
      ;;
  esac

  # ---- knowledge-flat routing (M032/P04/T01 FR-19) -------------------------
  # knowledge-flat records route to wiki/docs/knowledge/<basename>.md.
  # The canonical source lives at .orchestrator/knowledge/<basename>.md.
  # REL is "knowledge/<file>" (relative to .orchestrator/).
  case "$CAT" in
    knowledge-flat)
      _kfbase=$(basename "$REL" .md)
      STUB_REL="knowledge/${_kfbase}.md"
      STUB_ABS="$DOCS/$STUB_REL"
      CANONICAL=$(build_canonical "$STUB_REL" "$REL")
      CANONICAL_ABS="$ROOT/.orchestrator/$REL"
      # B5: knowledge-flat docs (KNOWLEDGE.md siblings) use fragment-only
      # intra-doc anchors heavily — fragment-only passthrough.
      write_stub "$STUB_ABS" "$CANONICAL" "$TITLE" "$CANONICAL_ABS" "false"
      continue
      ;;
  esac

  # ---- extra:* routing (M032/P04/T01 FR-18) --------------------------------
  # extra:<dn> records route to wiki/docs/<dn>/<basename>.md. The canonical
  # source lives at <repo-root>/<rel> (REL already carries the repo-root-
  # relative path emitted by the scanner — e.g., specs/foo.md).
  case "$CAT" in
    extra:*)
      _xdn=${CAT#extra:}
      _xbase=$(basename "$REL" .md)
      STUB_REL="${_xdn}/${_xbase}.md"
      STUB_ABS="$DOCS/$STUB_REL"
      CANONICAL=$(build_canonical_repo_rel "$STUB_REL" "$REL")
      CANONICAL_ABS="$ROOT/$REL"
      # PBJ-dogfood B7: M036 reference-corpus chunks pair a metadata `.md`
      # with a `<basename>.text.md` Tier-1-extracted sibling. When the
      # canonical body is empty (frontmatter + literal `|` placeholder
      # only), splice the sibling's content in via include-markdown and
      # render the frontmatter as a metadata admonition. When no sibling
      # exists, fall through to a metadata-only stub with an
      # external_pointer: callout when present (Tier 0 graceful
      # degradation). When body is non-empty, fall through to the
      # default include-canonical stub (operator-authored alongside
      # frontmatter — preserve current behavior).
      _xsibling="${CANONICAL_ABS%.md}.text.md"
      if body_is_empty "$CANONICAL_ABS"; then
        if [ -f "$_xsibling" ]; then
          # Build sibling-canonical relative to stub via build_canonical_repo_rel.
          _xsibling_rel="${REL%.md}.text.md"
          _xsibling_canonical=$(build_canonical_repo_rel "$STUB_REL" "$_xsibling_rel")
          write_stub_extra_with_sibling "$STUB_ABS" "$_xsibling_canonical" "$TITLE" "$CANONICAL_ABS"
        else
          _xext=$(extract_external_pointer "$CANONICAL_ABS")
          write_stub_extra_metadata_only "$STUB_ABS" "$TITLE" "$CANONICAL_ABS" "$_xext"
        fi
      else
        # B5: extra:* projections are typically self-contained per-chunk
        # docs (operator-authored alongside frontmatter) — fragment-only
        # passthrough is the safer default than rewriting all relative
        # links to source-relative.
        write_stub "$STUB_ABS" "$CANONICAL" "$TITLE" "$CANONICAL_ABS" "false"
      fi
      # PBJ-dogfood B1 fix: register under the extra-dir section so the
      # post-loop write_section_index_for emitter writes
      # wiki/docs/<dn>/index.md. Without this, wiki-generate-nav.sh's
      # `Overview: <dn>/index.md` leaf 404s and --strict build fails.
      # M037 P03 (P2.1): pass CANONICAL_ABS so the section-index emitter
      # can read frontmatter `published:` and sort reference-corpus
      # entries newest-first (matches operator expectation that the
      # category-index landing page leads with the latest documents).
      register_child "${_xdn}" "${_xbase}.md" "$TITLE" "$CANONICAL_ABS"
      continue
      ;;
  esac

  # PBJ-2026-05-07 forward-roadmap consolidation: under CONSOLIDATION_ACTIVE,
  # skip emitting the top-level milestone-summary.md stub — the canonical
  # content is now folded into wiki/docs/milestones/index.md by
  # section_include_for "milestones". Keeping the stub would orphan its URL
  # under mkdocs --strict (no nav leaf points at it).
  if [ "$CAT" = "top:milestone-summary" ] && [ "$CONSOLIDATION_ACTIVE" -eq 1 ]; then
    continue
  fi

  STUB_REL=$(map_record_to_stub_rel "$CAT" "$REL")
  STUB_ABS="$DOCS/$STUB_REL"
  CANONICAL=$(build_canonical "$STUB_REL" "$REL")
  # All non-knowledge records carry rel-paths under .orchestrator/.
  CANONICAL_ABS="$ROOT/.orchestrator/$REL"
  # B5: top:* singletons (constitution/decisions/knowledge/milestone-summary)
  # opt out of include-markdown rewrite-relative-urls so fragment-only intra-
  # doc anchor links pass through untouched. milestone:* / archive:* records
  # keep the default (true) — they have many sibling-doc cross-references
  # that depend on rewriting.
  _rru="true"
  case "$CAT" in
    top:*) _rru="false" ;;
  esac
  write_stub "$STUB_ABS" "$CANONICAL" "$TITLE" "$CANONICAL_ABS" "$_rru"

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
# PBJ-2026-05-08: accept the broader ID shape — numeric (M001/M2a/M3) and
# dash-prefixed (M-Spike-A) — matching the nav-sort two-bucket invariant
# (commit 9570e71e). Pre-fix the awk regex matched only `M[0-9]+`, silently
# dropping any non-digits-only milestone from the milestones index.
if [ -f "$SECTIONS_FILE" ]; then
  awk -F'|' '
    $1 ~ /^milestones\/(M[0-9]+[a-z]*|M-[A-Za-z0-9-]+)$/ { print $1 }
    $1 ~ /^milestones\/(M[0-9]+[a-z]*|M-[A-Za-z0-9-]+)\// { n=split($1, a, "/"); print a[1] "/" a[2] }
  ' "$SECTIONS_FILE" | sort -u > "$MILESTONES_SEEN"
  awk -F'|' '
    $1 ~ /^archive\/(M[0-9]+[a-z]*|M-[A-Za-z0-9-]+)$/ { print $1 }
    $1 ~ /^archive\/(M[0-9]+[a-z]*|M-[A-Za-z0-9-]+)\// { n=split($1, a, "/"); print a[1] "/" a[2] }
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
  if [ "$_rel" = "milestones" ]; then
    printf 'Milestones'
    return 0
  fi
  if [ "$_rel" = "archive" ]; then
    printf 'Archive'
    return 0
  fi
  # PBJ-2026-05-08: match milestone/archive root section paths against the
  # broader ID shape (numeric M001/M2a/M3 + dash-prefixed M-Spike-A) — same
  # spec used by the nav-sort two-bucket invariant (commit 9570e71e).
  if [[ "$_rel" =~ ^(milestones|archive)/(M[0-9]+[a-z]*|M-[A-Za-z0-9-]+)$ ]]; then
    _mid=$(basename "$_rel")
    _t=$(awk -F'\t' -v m="$_mid" '$1 == m { print $2; exit }' "$TITLES_FILE" 2>/dev/null)
    if [ -n "$_t" ]; then
      printf '%s — %s' "$_mid" "$_t"
    else
      printf '%s' "$_mid"
    fi
    return 0
  fi
  # PBJ-dogfood B4: extra-dir sections (e.g., "knowledge-reference-cms-rule")
  # consult the wiki.extra_dir_labels override before falling back to the
  # last-segment default. _rel matches the dirname-record exactly when the
  # section came from an extra:* record (single-segment), so we look up
  # directly. For nested/derived sections, the lookup misses harmlessly.
  _label=$(awk -F'|' -v d="$_rel" '$1 == d { print $2; exit }' "$EXTRA_LABELS_FILE" 2>/dev/null)
  if [ -n "$_label" ]; then
    printf '%s' "$_label"
  else
    # Use the last segment as the title; e.g., "milestones/M002/phases/P01" -> "P01".
    printf '%s' "$(basename "$_rel")"
  fi
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
  if [ "$_rel" = "milestones" ]; then
    # PBJ-2026-05-07 forward-roadmap consolidation: when both
    # .orchestrator/milestone-summary.md and at least one milestone:* record
    # exist, fold milestone-summary.md into the Milestones section index.
    # Mirrors the milestones/M### include precedent. CONSOLIDATION_ACTIVE is
    # computed at top-level after the scanner runs and false-y when only one
    # of the two inputs is present (preserves pre-consolidation behavior).
    if [ "${CONSOLIDATION_ACTIVE:-0}" -eq 1 ]; then
      _abs="$ROOT/.orchestrator/milestone-summary.md"
      if [ -f "$_abs" ]; then
        printf '%s.orchestrator/milestone-summary.md|%s' "$_prefix" "$_abs"
        return 0
      fi
    fi
    return 1
  fi
  # PBJ-2026-05-08: broader ID shape (numeric M001/M2a + dash-prefix M-Spike-A)
  # for milestone-root and archive-root sections. Same spec as the nav-sort
  # two-bucket invariant (commit 9570e71e).
  if [[ "$_rel" =~ ^milestones/(M[0-9]+[a-z]*|M-[A-Za-z0-9-]+)$ ]]; then
    _mid=$(basename "$_rel")
    for _kind in SUMMARY CONTEXT EVALUATION ROADMAP; do
      _abs="$ROOT/.orchestrator/milestones/${_mid}/${_mid}-${_kind}.md"
      if [ -f "$_abs" ]; then
        printf '%s.orchestrator/milestones/%s/%s-%s.md|%s' \
          "$_prefix" "$_mid" "$_mid" "$_kind" "$_abs"
        return 0
      fi
    done
    return 1
  fi
  if [[ "$_rel" =~ ^milestones/(M[0-9]+[a-z]*|M-[A-Za-z0-9-]+)/phases/P[0-9]+$ ]]; then
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
    return 1
  fi
  if [[ "$_rel" =~ ^archive/(M[0-9]+[a-z]*|M-[A-Za-z0-9-]+)$ ]]; then
    _mid=$(basename "$_rel")
    for _kind in SUMMARY CONTEXT EVALUATION ROADMAP; do
      _abs="$ROOT/.orchestrator/archive/${_mid}/${_mid}-${_kind}.md"
      if [ -f "$_abs" ]; then
        printf '%s.orchestrator/archive/%s/%s-%s.md|%s' \
          "$_prefix" "$_mid" "$_mid" "$_kind" "$_abs"
        return 0
      fi
    done
    return 1
  fi
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

  # M037 P03 (P2.1): when any child carries a non-empty source_abs (4th
  # column — set only at the extra:* registration site), sort the section
  # index descendingly by frontmatter `published:` (falls back to
  # `created:` then to alphabetical when both absent). For all other
  # sections (milestones, phases, knowledge, proposals, feedback) the
  # historical alphabetical sort is preserved.
  _is_extra_section=0
  if awk -F'|' -v s="$_section" '
      $1 == s && $4 != "" { found=1; exit }
      END { exit (found ? 0 : 1) }
    ' "$SECTIONS_FILE"; then
    _is_extra_section=1
  fi

  if [ "$_is_extra_section" -eq 1 ]; then
    # Build "<published>|<child_rel>|<child_title>" sort keys. Missing
    # dates default to "0000-00-00" so reverse-sort puts them last.
    _key_tmp="/tmp/wiki-stubs-keys-$$.list"
    : > "$_key_tmp"
    awk -F'|' -v s="$_section" '
      $1 == s { print $2 "|" $3 "|" $4 }
    ' "$SECTIONS_FILE" | sort -u -t'|' -k1,1 > "$_body_tmp"
    while IFS='|' read -r _cref _ctitle _csrc; do
      [ -n "$_cref" ] || continue
      _pub=""
      if [ -n "$_csrc" ] && [ -f "$_csrc" ]; then
        _pub=$(read_published_date "$_csrc")
      fi
      if [ -z "$_pub" ]; then
        _pub="0000-00-00"
      fi
      printf '%s|%s|%s\n' "$_pub" "$_cref" "$_ctitle" >> "$_key_tmp"
    done < "$_body_tmp"
    LC_ALL=C sort -r -t'|' -k1,1 -k2,2 "$_key_tmp" > "${_key_tmp}.sorted"
    mv "${_key_tmp}.sorted" "$_body_tmp"
    rm -f "$_key_tmp"
    # Strip the published key so the bullet builder consumes <child_rel>|<child_title>.
    awk -F'|' '{ print $2 "|" $3 }' "$_body_tmp" > "${_body_tmp}.stripped"
    mv "${_body_tmp}.stripped" "$_body_tmp"
  else
    # Extract children of this section, de-dup on child_rel, sort lexically.
    awk -F'|' -v s="$_section" '
      $1 == s { print $2 "|" $3 }
    ' "$SECTIONS_FILE" | sort -u -t'|' -k1,1 > "$_body_tmp"
  fi

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
  # M037 P03 (P2.1): emit a 1-sentence preamble for extra:* category
  # indexes so the page leads with orientation instead of a bare bullet
  # list. Reads optional `wiki.extra_dir_descriptions:` block from
  # .orchestrator/config.yml when present; falls back to a generic
  # "Reference materials in this category, sorted newest-first." line.
  _preamble=""
  if [ "$_is_extra_section" -eq 1 ]; then
    _desc=""
    _cfgfile="$ROOT/.orchestrator/config.yml"
    if [ -f "$_cfgfile" ]; then
      _desc=$(awk -v dn="$_section" '
        BEGIN { state="pre" }
        /^wiki:[[:space:]]*$/ { state="wiki"; next }
        state=="wiki" && /^[^[:space:]#]/ { exit }
        state=="wiki" && /^  extra_dir_descriptions:[[:space:]]*$/ { state="desc"; next }
        state=="desc" && /^[^[:space:]#]/ { exit }
        state=="desc" && /^  [a-zA-Z]/ { exit }
        state=="desc" && /^    / {
          line=$0
          sub(/^    /, "", line)
          if (match(line, /^[A-Za-z0-9_-]+:[[:space:]]*/)) {
            k=substr(line, 1, RLENGTH-1)
            sub(/:[[:space:]]*$/, "", k)
            v=substr(line, RLENGTH+1)
            sub(/^"/, "", v); sub(/"$/, "", v)
            sub(/^\047/, "", v); sub(/\047$/, "", v)
            sub(/[[:space:]]+$/, "", v)
            if (k == dn) { print v; exit }
          }
        }
      ' "$_cfgfile" 2>/dev/null)
    fi
    if [ -z "$_desc" ]; then
      _desc="Reference materials in this category, sorted newest-first."
    fi
    _preamble="$_desc"
  fi
  write_index "$_idx_target" "$_title" "$_bullets" "$_inc_spec" "$_preamble"
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
#
# PBJ-dogfood B8: skip emission entirely when the source list is empty (no
# MEM stubs were produced for this category in the current run). Without
# this gate the script writes a title-only `# Knowledge — Patterns` page
# that mkdocs flags as orphan — see the "empty-subdir section indexes"
# finding in the round-2 PBJ dogfood report.
write_knowledge_sub_index_from_list() {
  _sub="$1"
  _list="$2"
  if [ ! -s "$_list" ]; then
    return 0
  fi
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

# PBJ-dogfood B8: only emit the top-level knowledge/index.md when at least
# one of the three category lists has content. Without this gate, projects
# that have no knowledge/<cat>/MEM*.md files still get a top-level index
# linking to three empty (or skipped) sub-indexes. The nav generator's
# Knowledge — Flat group + top-level Knowledge: knowledge.md leaf cover the
# flat-knowledge surface; the per-category index tree only earns its keep
# when at least one MEM stub exists.
_kn_any=0
if [ -s "$KN_PATTERNS_LIST" ] || [ -s "$KN_CONVENTIONS_LIST" ] || [ -s "$KN_LESSONS_LIST" ]; then
  _kn_any=1
fi
if [ "$_kn_any" -eq 1 ]; then
  write_knowledge_top_index
fi
write_knowledge_sub_index_from_list "patterns"    "$KN_PATTERNS_LIST"
write_knowledge_sub_index_from_list "conventions" "$KN_CONVENTIONS_LIST"
write_knowledge_sub_index_from_list "lessons"     "$KN_LESSONS_LIST"

rm -f "$KN_PATTERNS_LIST" "$KN_CONVENTIONS_LIST" "$KN_LESSONS_LIST"

# ---- M037/P01/T01 — render homepage card grid ------------------------------
render_landing_cards

# ---- summary ---------------------------------------------------------------

printf 'SUMMARY: wrote %d stubs, %d section indexes, removed %d stale files\n' \
  "$STUBS_WRITTEN" "$INDEXES_WRITTEN" "$REMOVED" >&2

exit 0
