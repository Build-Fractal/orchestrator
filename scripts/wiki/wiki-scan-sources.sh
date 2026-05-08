#!/usr/bin/env bash
# scripts/wiki/wiki-scan-sources.sh — M012/P01 in-scope artifact enumerator.
#
# Prints one record per in-scope .orchestrator/**.md file to stdout:
#   <category>|<relative-path-under-dot-orchestrator>|<display-title>
#
# Category enum:
#   top:constitution
#   top:decisions          (single .orchestrator/DECISIONS.md)
#   top:knowledge
#   top:milestone-summary
#   spec:<basename>        (.orchestrator/spec/*.md)
#   decisions-extra:<base> (.orchestrator/decisions/*.md siblings)
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
INCLUDE_GLOSSARY=1    # default-on per M032/P02/T03 FR-15
INCLUDE_PROPOSALS=1   # default-on per M032/P04/T01 FR-17

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
    --include-glossary)
      INCLUDE_GLOSSARY=1
      shift
      ;;
    --include-glossary=true)
      INCLUDE_GLOSSARY=1
      shift
      ;;
    --include-glossary=false)
      INCLUDE_GLOSSARY=0
      shift
      ;;
    --no-include-glossary)
      INCLUDE_GLOSSARY=0
      shift
      ;;
    --include-proposals)
      INCLUDE_PROPOSALS=1
      shift
      ;;
    --include-proposals=true)
      INCLUDE_PROPOSALS=1
      shift
      ;;
    --include-proposals=false)
      INCLUDE_PROPOSALS=0
      shift
      ;;
    --no-include-proposals)
      INCLUDE_PROPOSALS=0
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
#
# M037 P03 (P2.1): prefer YAML frontmatter `version:` (the same field
# wiki-generate-stubs.sh's derive_stub_title projects to nav titles)
# before falling back to H1 then basename. Fixes section-index pages
# rendering slug-shaped bullets for M036 reference-corpus chunks whose
# bodies are empty (frontmatter + literal `|` placeholder, real content
# behind external_pointer:).
extract_title() {
  _p="$1"
  _t=""
  if [ -f "$_p" ]; then
    _t=$(awk '
      BEGIN { state="pre" }
      NR == 1 && $0 == "---" { state="fm"; next }
      state == "fm" && $0 == "---" { exit }
      state == "fm" && $0 ~ /^[[:space:]]*version[[:space:]]*:[[:space:]]*/ {
        v=$0
        sub(/^[[:space:]]*version[[:space:]]*:[[:space:]]*/, "", v)
        sub(/[[:space:]]+$/, "", v)
        sub(/^"/, "", v); sub(/"$/, "", v)
        sub(/^\047/, "", v); sub(/\047$/, "", v)
        print v
        exit
      }
    ' "$_p" 2>/dev/null)
    if [ -z "$_t" ]; then
      _t=$(grep -m 1 '^# ' "$_p" 2>/dev/null | sed 's/^# //' | head -n 1)
    fi
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

# M032/P02/T03 FR-15: Glossary emission as the second top-level source after
# Constitution. The path is repo-root-relative (lives outside .orchestrator/),
# matching the knowledge:* convention later in this scanner. Default-on; opt
# out via --no-include-glossary or --include-glossary=false.
if [ "$INCLUDE_GLOSSARY" = "1" ] && [ -f "$ROOT/wiki/glossary.md" ]; then
  emit_record "top:glossary" "wiki/glossary.md" "$ROOT/wiki/glossary.md"
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

# ---- FR-17 (M032/P04/T01) — proposals enumeration --------------------------
# Emits one record per .orchestrator/proposals/*.md entry (excluding README.md
# via should_exclude). Title field is "<H1> [stage]" where <stage> derives from
# the YAML frontmatter `stage:` field if present; otherwise [unknown] (US-7
# AS-1, no exclusion). Default-on; opt out via --no-include-proposals or
# --include-proposals=false.
#
# extract_proposal_stage <abs-path>
# Prints stage value (stub|brief|specified|active|closed) or "unknown" if
# either no frontmatter or no `stage:` field. Uses awk to scan the leading
# YAML block delimited by `---` lines.
extract_proposal_stage() {
  _p="$1"
  [ -f "$_p" ] || { printf 'unknown'; return 0; }
  _s=$(awk '
    BEGIN { state="pre"; out="" }
    NR == 1 {
      if ($0 == "---") { state="in"; next }
      else { exit }
    }
    state == "in" {
      if ($0 == "---") { exit }
      # match: stage: value   (allow optional quotes/whitespace)
      if ($0  ~ /^[[:space:]]*stage[[:space:]]*:[[:space:]]*/) {
        v=$0
        sub(/^[[:space:]]*stage[[:space:]]*:[[:space:]]*/, "", v)
        sub(/^["'"'"']/, "", v)
        sub(/["'"'"'][[:space:]]*$/, "", v)
        sub(/[[:space:]]+$/, "", v)
        out=v
        exit
      }
    }
    END {
      if (out == "") { print "unknown" } else { print out }
    }
  ' "$_p" 2>/dev/null)
  if [ -z "$_s" ]; then
    _s="unknown"
  fi
  printf '%s' "$_s"
}

if [ "$INCLUDE_PROPOSALS" = "1" ] && [ -d "$ORCH/proposals" ]; then
  _plist="/tmp/wiki-scan-proposals.$$"
  find "$ORCH/proposals" -maxdepth 1 -type f -name '*.md' 2>/dev/null | LC_ALL=C sort > "$_plist"
  while IFS= read -r _ppath; do
    [ -n "$_ppath" ] || continue
    _prel=${_ppath#"$ROOT/.orchestrator/"}
    if should_exclude "$_prel"; then
      continue
    fi
    _pbase=$(basename "$_ppath" .md)
    _ptitle=$(extract_title "$_ppath")
    _pstage=$(extract_proposal_stage "$_ppath")
    # M037 P03 (P2.3): omit the [stage] suffix when stage is "unknown"
    # (no frontmatter or no stage: field). PBJ dogfood feedback —
    # rendering literal "[unknown]" in nav titles is noise, not signal.
    if [ "$_pstage" = "unknown" ]; then
      printf '%s|%s|%s\n' "proposals:$_pbase" "$_prel" "$_ptitle"
    else
      printf '%s|%s|%s [%s]\n' "proposals:$_pbase" "$_prel" "$_ptitle" "$_pstage"
    fi
    COUNT=$((COUNT + 1))
  done < "$_plist"
  rm -f "$_plist"
fi

# ---- FR-18 (M037/P02/T01) — feedback enumeration --------------------------
# Emits one record per .orchestrator/feedback/*.md entry. Title field is the
# H1 of the source file (via extract_title helper); falls back to humanized
# basename when H1 absent (the existing extract_title helper already does
# this — basename without extension, lowercased, dashes preserved). Records
# land at category prefix "feedback:<basename>"; the per-record relative
# path is "feedback/<basename>.md" (relative to .orchestrator/). Default-on;
# opt out via INCLUDE_FEEDBACK=0 env override (no CLI flag — feedback is
# always-in-scope by design unless explicitly suppressed).
if [ "${INCLUDE_FEEDBACK:-1}" = "1" ] && [ -d "$ORCH/feedback" ]; then
  _flist="/tmp/wiki-scan-feedback.$$"
  find "$ORCH/feedback" -maxdepth 1 -type f -name '*.md' 2>/dev/null | LC_ALL=C sort > "$_flist"
  while IFS= read -r _fpath; do
    [ -n "$_fpath" ] || continue
    _frel=${_fpath#"$ROOT/.orchestrator/"}
    if should_exclude "$_frel"; then
      continue
    fi
    _fbase=$(basename "$_fpath" .md)
    _ftitle=$(extract_title "$_fpath")
    printf '%s|%s|%s\n' "feedback:$_fbase" "$_frel" "$_ftitle"
    COUNT=$((COUNT + 1))
  done < "$_flist"
  rm -f "$_flist"
fi

# ---- PBJ-2026-05-07 — top-level spec/ enumeration --------------------------
# Emits one record per .orchestrator/spec/*.md entry. Source-of-truth spec
# documents (product brief, MVP plan, decision register, coverage audit)
# distinct from accreting knowledge graph entries. Records land at
# `spec:<basename>`; per-record relative path is `spec/<basename>.md`
# (relative to .orchestrator/). Mirrors the proposals:* / feedback:*
# emit shape. Default-on; opt out via INCLUDE_SPEC=0 env override.
# Convention-only: walks .orchestrator/spec/ at repo-relative .orchestrator/spec/.
# Projects with legacy locations (initial-spec-documents/) can use the
# existing wiki.extra_dirs: + wiki.extra_dir_labels: mechanism instead.
if [ "${INCLUDE_SPEC:-1}" = "1" ] && [ -d "$ORCH/spec" ]; then
  _splist="/tmp/wiki-scan-spec.$$"
  find "$ORCH/spec" -maxdepth 1 -type f -name '*.md' 2>/dev/null | LC_ALL=C sort > "$_splist"
  while IFS= read -r _sppath; do
    [ -n "$_sppath" ] || continue
    _sprel=${_sppath#"$ROOT/.orchestrator/"}
    if should_exclude "$_sprel"; then
      continue
    fi
    _spbase=$(basename "$_sppath" .md)
    _sptitle=$(extract_title "$_sppath")
    printf '%s|%s|%s\n' "spec:$_spbase" "$_sprel" "$_sptitle"
    COUNT=$((COUNT + 1))
  done < "$_splist"
  rm -f "$_splist"
fi

# ---- PBJ-2026-05-07 — multi-file decisions tree ----------------------------
# Existing single-file emission for .orchestrator/DECISIONS.md (top:decisions)
# is unchanged; this extends the decisions surface to also walk
# .orchestrator/decisions/*.md when present. Records land at
# `decisions-extra:<basename>`; per-record relative path is
# `decisions/<basename>.md` (relative to .orchestrator/). The downstream
# nav generator detects these records and flips the Decisions section from
# a leaf (DECISIONS.md only) to a group (DECISIONS.md as Overview + subdir
# files as children). No URL collision under use_directory_urls:true:
# `decisions.md` -> /decisions/, `decisions/<file>.md` -> /decisions/<file>/.
if [ "${INCLUDE_DECISIONS_EXTRA:-1}" = "1" ] && [ -d "$ORCH/decisions" ]; then
  _delist="/tmp/wiki-scan-decisions-extra.$$"
  find "$ORCH/decisions" -maxdepth 1 -type f -name '*.md' 2>/dev/null | LC_ALL=C sort > "$_delist"
  while IFS= read -r _depath; do
    [ -n "$_depath" ] || continue
    _derel=${_depath#"$ROOT/.orchestrator/"}
    if should_exclude "$_derel"; then
      continue
    fi
    _debase=$(basename "$_depath" .md)
    # Collision guard: a `decisions/index.md` entry would resolve to /decisions/
    # under use_directory_urls:true -- same URL as wiki/docs/decisions.md
    # (from top:decisions / DECISIONS.md). Fail loud.
    if [ "$_debase" = "index" ] || [ "$_debase" = "INDEX" ]; then
      printf 'ERROR: %s/%s.md collides with .orchestrator/DECISIONS.md under use_directory_urls.\n' \
        ".orchestrator/decisions" "$_debase" >&2
      printf 'ERROR: rename or move the file (any other basename works).\n' >&2
      exit 1
    fi
    _detitle=$(extract_title "$_depath")
    printf '%s|%s|%s\n' "decisions-extra:$_debase" "$_derel" "$_detitle"
    COUNT=$((COUNT + 1))
  done < "$_delist"
  rm -f "$_delist"
fi

# ---- FR-18 (M032/P04/T01) — wiki.extra_dirs enumeration --------------------
# Reads <ROOT>/.orchestrator/config.yml for the wiki.extra_dirs: YAML list.
# Inline form: `wiki: { extra_dirs: [specs/, decisions/] }` or
#              `wiki.extra_dirs: [specs/, decisions/]`.
# Block form:  `wiki:` then nested `extra_dirs:` list.
# Empty/absent config produces zero records (no false-positive section).
# For each declared path, walks it (find -type f -name '*.md' | LC_ALL=C sort)
# and emits `extra:<dirname>|<rel>|<title>` records. <dirname> is the path
# with trailing slash stripped and path separators replaced with `-`.
parse_extra_dirs_inline() {
  _cfg="$1"
  # Look for `extra_dirs:` followed by `[...]` on the same line — covers both
  # `wiki.extra_dirs:` and the nested `extra_dirs:` case after `wiki:`.
  awk '
    /^[[:space:]]*(wiki\.)?extra_dirs[[:space:]]*:[[:space:]]*\[/ {
      sub(/^[^[]*\[/, "", $0)
      sub(/\].*$/, "", $0)
      gsub(/[[:space:]]/, "", $0)
      n=split($0, a, ",")
      for (i=1; i<=n; i++) {
        v=a[i]
        # strip optional surrounding quotes
        sub(/^['"'"'"]/, "", v)
        sub(/['"'"'"]$/, "", v)
        if (v != "") print v
      }
      exit
    }
  ' "$_cfg"
}

parse_extra_dirs_block() {
  _cfg="$1"
  # Walk lines: when we see `wiki:` (no `[`), enter wiki-block; inside, when
  # we see `extra_dirs:` (no `[`), enter list; collect leading `- value` lines
  # at deeper indent until indent decreases or non-list line appears.
  awk '
    BEGIN { state="pre"; wiki_indent=-1; list_indent=-1 }
    function indent_of(line) {
      n=match(line, /[^[:space:]]/)
      if (n == 0) return -1
      return n - 1
    }
    {
      ind=indent_of($0)
      if (ind == -1) next
      if (state == "pre") {
        if ($0 ~ /^[[:space:]]*wiki[[:space:]]*:[[:space:]]*$/) {
          state="wiki"; wiki_indent=ind; next
        }
        next
      }
      if (state == "wiki") {
        if (ind <= wiki_indent) {
          # Left wiki block.
          if ($0 ~ /^[[:space:]]*wiki[[:space:]]*:[[:space:]]*$/) {
            state="wiki"; wiki_indent=ind; next
          }
          state="pre"; next
        }
        if ($0 ~ /^[[:space:]]*extra_dirs[[:space:]]*:[[:space:]]*$/) {
          state="list"; list_indent=ind; next
        }
        # inline-list form inside wiki block
        if ($0 ~ /^[[:space:]]*extra_dirs[[:space:]]*:[[:space:]]*\[/) {
          line=$0
          sub(/^[^[]*\[/, "", line)
          sub(/\].*$/, "", line)
          gsub(/[[:space:]]/, "", line)
          n=split(line, a, ",")
          for (i=1; i<=n; i++) {
            v=a[i]
            sub(/^['"'"'"]/, "", v)
            sub(/['"'"'"]$/, "", v)
            if (v != "") print v
          }
          state="wiki"; next
        }
        next
      }
      if (state == "list") {
        if (ind <= list_indent) {
          # left list block
          state="wiki"; list_indent=-1
          # fall through to re-process
        } else {
          if ($0 ~ /^[[:space:]]*-[[:space:]]+/) {
            v=$0
            sub(/^[[:space:]]*-[[:space:]]+/, "", v)
            sub(/[[:space:]]+$/, "", v)
            sub(/^['"'"'"]/, "", v)
            sub(/['"'"'"]$/, "", v)
            if (v != "") print v
          }
          next
        }
      }
    }
  ' "$_cfg"
}

# PBJ-dogfood B4 — parse wiki.extra_dir_labels block-form map.
# Reads `wiki:` block, then nested `extra_dir_labels:` block, then collects
# leading `<dn>: "<label>"` lines until indent decreases or list-shape line
# appears. Emits `<dn>|<label>` per declared label.
#
# Sibling-map shape (chosen over PBJ's `- {path:, label:}` recommendation
# for bash 3.2 awk parser tractability):
#   wiki:
#     extra_dirs:
#       - knowledge/reference/cms-rule/
#     extra_dir_labels:
#       knowledge-reference-cms-rule: "Reference — CMS rules"
#
# The dn key is the canonical dirname-record (path with trailing slash
# stripped, / replaced with -) — matching the form emitted by the
# scan_extra_dir loop.
parse_extra_dir_labels() {
  _cfg="$1"
  awk '
    BEGIN { state="pre"; wiki_indent=-1; map_indent=-1 }
    function indent_of(line) {
      n=match(line, /[^[:space:]]/)
      if (n == 0) return -1
      return n - 1
    }
    {
      ind=indent_of($0)
      if (ind == -1) next
      if (state == "pre") {
        if ($0 ~ /^[[:space:]]*wiki[[:space:]]*:[[:space:]]*$/) {
          state="wiki"; wiki_indent=ind; next
        }
        next
      }
      if (state == "wiki") {
        if (ind <= wiki_indent) {
          if ($0 ~ /^[[:space:]]*wiki[[:space:]]*:[[:space:]]*$/) {
            state="wiki"; wiki_indent=ind; next
          }
          state="pre"; next
        }
        if ($0 ~ /^[[:space:]]*extra_dir_labels[[:space:]]*:[[:space:]]*$/) {
          state="map"; map_indent=ind; next
        }
        next
      }
      if (state == "map") {
        if (ind <= map_indent) {
          state="wiki"; map_indent=-1
        } else {
          # Match `<key>: "<value>"` or `<key>: <value>`.
          line=$0
          if (match(line, /^[[:space:]]*[A-Za-z0-9_-]+[[:space:]]*:[[:space:]]*/)) {
            key=line
            sub(/^[[:space:]]*/, "", key)
            sub(/[[:space:]]*:.*$/, "", key)
            val=line
            sub(/^[^:]*:[[:space:]]*/, "", val)
            sub(/[[:space:]]+$/, "", val)
            sub(/^["'"'"']/, "", val)
            sub(/["'"'"']$/, "", val)
            if (key != "" && val != "") print key "|" val
          }
          next
        }
      }
    }
  ' "$_cfg"
}

# scan_extra_dir <abs-dir> <dirname-record>
# Emits extra:<dirname>|<rel-from-ROOT>|<title> records.
#
# PBJ-dogfood B7: when `<basename>.md` and `<basename>.text.md` coexist in
# the same dir, suppress the `<basename>.text.md` record. M036 reference-
# corpus chunks pair a metadata `.md` (frontmatter + `|` body placeholder)
# with a Tier-1-extracted `.text.md` sibling carrying the real content.
# Without this carve-out the scanner emits two records (REF-foo and
# REF-foo.text) and the wiki nav grows duplicate sibling entries. The
# stub generator's extra:* arm is responsible for splicing the sibling's
# body into the canonical chunk's stub at projection time.
scan_extra_dir() {
  _abs="$1"
  _dn="$2"
  [ -d "$_abs" ] || return 0
  _xlist="/tmp/wiki-scan-extra.$$"
  find "$_abs" -type f -name '*.md' 2>/dev/null | LC_ALL=C sort > "$_xlist"
  while IFS= read -r _xpath; do
    [ -n "$_xpath" ] || continue
    # B7 sibling-suppression: skip *.text.md when <basename>.md exists.
    case "$_xpath" in
      *.text.md)
        _xstem=${_xpath%.text.md}
        if [ -f "${_xstem}.md" ]; then
          continue
        fi
        ;;
    esac
    _xrel=${_xpath#"$ROOT/"}
    _xtitle=$(extract_title "$_xpath")
    printf '%s|%s|%s\n' "extra:$_dn" "$_xrel" "$_xtitle"
    COUNT=$((COUNT + 1))
  done < "$_xlist"
  rm -f "$_xlist"
}

_cfgfile="$ORCH/config.yml"
if [ -f "$_cfgfile" ]; then
  _edlist="/tmp/wiki-scan-extra-dirs.$$"
  : > "$_edlist"
  parse_extra_dirs_inline "$_cfgfile" >> "$_edlist" 2>/dev/null || :
  parse_extra_dirs_block  "$_cfgfile" >> "$_edlist" 2>/dev/null || :
  while IFS= read -r _edentry; do
    [ -n "$_edentry" ] || continue
    # Compute dirname-record (path with trailing slash stripped + / -> -).
    _ed_clean="$_edentry"
    case "$_ed_clean" in
      */) _ed_clean=${_ed_clean%/} ;;
    esac
    _ed_dn=$(printf '%s' "$_ed_clean" | tr '/' '-')
    # PBJ-dogfood B3: detect URL collision with reserved top-level scanner
    # records. Both top:<name> (→ wiki/docs/<name>.md) and extra:<dn>
    # (→ wiki/docs/<dn>/) resolve to the same URL /<name>/ under
    # use_directory_urls: true. Fail loud rather than letting the consolidated
    # top-level page become silently unreachable.
    case "$_ed_dn" in
      constitution|decisions|knowledge|milestone-summary|glossary|milestones|archive|proposals|feedback)
        printf 'ERROR: wiki.extra_dirs entry %s collides with reserved top-level wiki path /%s/.\n' \
          "$_edentry" "$_ed_dn" >&2
        printf 'ERROR: under use_directory_urls: true, both wiki/docs/%s.md (top:%s)\n' \
          "$_ed_dn" "$_ed_dn" >&2
        printf 'ERROR: and wiki/docs/%s/index.md (extra:%s) resolve to /%s/.\n' \
          "$_ed_dn" "$_ed_dn" "$_ed_dn" >&2
        printf 'ERROR: rename or relocate %s in .orchestrator/config.yml wiki.extra_dirs.\n' \
          "$_edentry" >&2
        rm -f "$_edlist"
        exit 1
        ;;
    esac
    _ed_abs="$ROOT/$_ed_clean"
    scan_extra_dir "$_ed_abs" "$_ed_dn"
  done < "$_edlist"
  rm -f "$_edlist"

  # PBJ-dogfood B4 — emit extra-label:<dn>||<label> records for any
  # declared wiki.extra_dir_labels entries. Downstream nav + stub
  # generators consult these for nicer section labels than the
  # default Title-Case projection.
  _ldlist="/tmp/wiki-scan-extra-labels.$$"
  parse_extra_dir_labels "$_cfgfile" > "$_ldlist" 2>/dev/null || :
  while IFS='|' read -r _ld_dn _ld_label; do
    [ -n "$_ld_dn" ] || continue
    [ -n "$_ld_label" ] || continue
    printf 'extra-label:%s||%s\n' "$_ld_dn" "$_ld_label"
  done < "$_ldlist"
  rm -f "$_ldlist"
fi

# ---- FR-19 (M032/P04/T01) — knowledge-flat enumeration ---------------------
# Emits knowledge-flat|knowledge/<file>|<title> per FLAT *.md file under
# .orchestrator/knowledge/ (no category subdir). The existing
# knowledge:patterns|conventions|lessons emission above is unchanged.
# `-maxdepth 1` keeps this strictly to flat files; subdirs (reference/,
# patterns/, conventions/, lessons/) are out of scope for FR-19.
if [ -d "$ORCH/knowledge" ]; then
  _kflist="/tmp/wiki-scan-knowledge-flat.$$"
  find "$ORCH/knowledge" -maxdepth 1 -type f -name '*.md' 2>/dev/null | LC_ALL=C sort > "$_kflist"
  while IFS= read -r _kfpath; do
    [ -n "$_kfpath" ] || continue
    _kfrel="knowledge/$(basename "$_kfpath")"
    if should_exclude "$_kfrel"; then
      continue
    fi
    _kftitle=$(extract_title "$_kfpath")
    printf '%s|%s|%s\n' "knowledge-flat" "$_kfrel" "$_kftitle"
    COUNT=$((COUNT + 1))
  done < "$_kflist"
  rm -f "$_kflist"
fi

# ---- trailer ----------------------------------------------------------------

printf 'SUMMARY: %d in-scope artifacts\n' "$COUNT" >&2
exit 0
