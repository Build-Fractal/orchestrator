#!/usr/bin/env bash
# scripts/knowledge/ingest-spec.sh -- Ingest a markdown spec into the knowledge system
# Usage: ingest-spec.sh --spec-path <path> --slug <slug> [--scope-tags <tags>]
#
# Parses a markdown spec file, classifies sections into chunk types
# (story, requirement, constraint, nfr, acceptance, non-goal), and
# creates knowledge entries via create-entry.sh. Calls rebuild-index.sh
# once at the end.
#
# Output: CREATED:, SKIPPED:, SUPERSEDED:, REMOVED: prefixed lines to stdout.
# Errors to stderr. Exit 0 on success, 1 on failure.
#
# Bash 3.2 compatible.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Argument parsing ---
SPEC_PATH=""
SLUG=""
SCOPE_TAGS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --spec-path) SPEC_PATH="$2"; shift 2 ;;
    --slug) SLUG="$2"; shift 2 ;;
    --scope-tags) SCOPE_TAGS="$2"; shift 2 ;;
    *) echo "ERROR: unknown option '$1'" >&2; exit 1 ;;
  esac
done

# --- Validate required arguments ---
if [ -z "$SPEC_PATH" ]; then
  echo "ERROR: --spec-path is required" >&2
  exit 1
fi
if [ -z "$SLUG" ]; then
  echo "ERROR: --slug is required" >&2
  exit 1
fi
if [ ! -f "$SPEC_PATH" ]; then
  echo "ERROR: spec file not found: $SPEC_PATH" >&2
  exit 1
fi

# Default scope-tags to spec slug
if [ -z "$SCOPE_TAGS" ]; then
  SCOPE_TAGS="[spec:$SLUG]"
fi

# --- Counters ---
CREATED_COUNT=0
SKIPPED_COUNT=0
SUPERSEDED_COUNT=0
REMOVED_COUNT=0
REVIEW_COUNT=0
US_SEQ=0
FR_SEQ=0
CON_SEQ=0
NG_SEQ=0
AC_SEQ=0
NFR_SEQ=0

# --- Source hash library ---
source "$SCRIPT_DIR/../lib/hash.sh"

# --- Source index-utils.sh for get_project_root ---
source "$SCRIPT_DIR/lib/index-utils.sh"
INGEST_PROJECT_ROOT="$(get_project_root)"

# --- Source detail-utils.sh for sed_i ---
source "$SCRIPT_DIR/lib/detail-utils.sh"

# --- Observed-ID log for re-ingest diff detection ---
# Per-PID append-only log of every chunk observed during this ingest run.
# T02 will diff this against on-disk entries to detect REMOVED chunks.
INGEST_TMP_DIR="$INGEST_PROJECT_ROOT/.orchestrator/tmp"
mkdir -p "$INGEST_TMP_DIR"
INGEST_OBSERVED_LOG="$INGEST_TMP_DIR/ingest-spec-observed.$$"
: > "$INGEST_OBSERVED_LOG"
trap 'rm -f "$INGEST_OBSERVED_LOG"' EXIT

# --- Normalize text for hashing ---
# Strips trailing whitespace per line, strips leading/trailing blank lines
normalize_for_hash() {
  local text="$1"
  printf '%s' "$text" | sed 's/[[:space:]]*$//' | sed '/./,$!d' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
}

# --- classify_chunk_decision <id> <new-hash> ---
# Echoes one of: NEW | UNCHANGED | CHANGED
# NEW       -- no existing entry for this ID
# UNCHANGED -- existing entry's content_hash equals the new hash
# CHANGED   -- existing entry's content_hash differs from the new hash
classify_chunk_decision() {
  local chunk_id="$1"
  local new_hash="$2"
  local existing_file=""
  existing_file="$(find_detail_file "$chunk_id" 2>/dev/null)" || {
    echo "NEW"
    return 0
  }
  # Walk the supersession chain forward to the tip. If the entry has been
  # superseded (non-empty superseded_by other than REMOVED), compare against
  # the tip's content_hash rather than this entry's. This keeps re-ingest of
  # an already-superseded spec idempotent (no -v3 on every run).
  local cursor_file="$existing_file"
  while :; do
    local next_id=""
    next_id="$(fm_field "$cursor_file" "superseded_by")"
    if [ -z "$next_id" ] || [ "$next_id" = "REMOVED" ]; then
      break
    fi
    local next_file=""
    next_file="$(find_detail_file "$next_id" 2>/dev/null)" || break
    cursor_file="$next_file"
  done
  local existing_hash=""
  existing_hash="$(fm_field "$cursor_file" "content_hash")"
  if [ -z "$existing_hash" ]; then
    # No hash recorded (pre-P02 entry) -- treat as CHANGED to force refresh
    echo "CHANGED"
    return 0
  fi
  if [ "$existing_hash" = "$new_hash" ]; then
    echo "UNCHANGED"
    return 0
  fi
  echo "CHANGED"
}

# --- next_version_id <old-id> ---
# Walks the supersession chain forward from old-id and returns the next
# version suffix. If old-id has no -v suffix and no successor, returns
# old-id-v2. If old-id is already -vN, returns the base with -v(N+1).
# If old-id already has a successor (old-id -> old-id-v2), walks forward
# until it finds the tip, then appends the next suffix.
next_version_id() {
  local cursor="$1"
  local cursor_file=""
  while :; do
    cursor_file="$(find_detail_file "$cursor" 2>/dev/null)" || break
    local successor=""
    successor="$(fm_field "$cursor_file" "superseded_by")"
    if [ -z "$successor" ] || [ "$successor" = "REMOVED" ]; then
      break
    fi
    cursor="$successor"
  done

  # Derive next suffix from the tip
  case "$cursor" in
    *-v[0-9]*)
      local base="${cursor%-v*}"
      local n="${cursor##*-v}"
      echo "${base}-v$((n + 1))"
      ;;
    *)
      echo "${cursor}-v2"
      ;;
  esac
}

# --- emit_phase_impact <old-id> <new-id-or-REMOVED> ---
# If old-id's scope_tags contain a phase reference (e.g. [phase:P02] or
# [milestone:M011/P02]), emits `REVIEW: P## affected by <old-id> supersession`
# for each distinct phase found. Silent when no phase tags are present.
emit_phase_impact() {
  local old_id="$1"
  local existing_file=""
  existing_file="$(find_detail_file "$old_id" 2>/dev/null)" || return 0
  local tags=""
  tags="$(fm_field "$existing_file" "scope_tags")"
  if [ -z "$tags" ]; then
    return 0
  fi
  # Extract P## references. Two accepted patterns:
  #   [phase:P##]
  #   [milestone:M###/P##]
  # Emit one REVIEW line per distinct phase found.
  local phases=""
  phases="$(printf '%s\n' "$tags" \
    | grep -oE '(phase:|M[0-9]+/)P[0-9]+' \
    | sed 's/^.*P/P/' \
    | sort -u || true)"
  if [ -z "$phases" ]; then
    return 0
  fi
  local pline=""
  while IFS= read -r pline || [ -n "$pline" ]; do
    if [ -n "$pline" ]; then
      echo "REVIEW: $pline affected by $old_id supersession"
      REVIEW_COUNT=$((REVIEW_COUNT + 1))
    fi
  done <<EOF_PHASES
$phases
EOF_PHASES
}

# --- Helper: perform the actual create-entry.sh invocation + hash patch ---
# Usage: _do_create_chunk <id> <category> <source_section> <description> <body> <relates_to> <content_hash>
# Always runs create-entry.sh. Does not emit any decision prefix -- that
# is owned by create_chunk. On success, increments CREATED_COUNT and patches
# the content_hash frontmatter via sed_i. On EXISTS: output (rare race),
# increments SKIPPED_COUNT but prints nothing.
_do_create_chunk() {
  local chunk_id="$1"
  local category="$2"
  local source_section="$3"
  local description="$4"
  local body="$5"
  local relates_to="$6"
  local content_hash="$7"

  local output=""
  if [ -n "$relates_to" ]; then
    output="$(bash "$SCRIPT_DIR/create-entry.sh" \
      --id "$chunk_id" \
      --category "$category" \
      --scope-tags "$SCOPE_TAGS" \
      --source-unit "${SPEC_PATH}#${source_section}" \
      --source-type "spec-ingest" \
      --description "$description" \
      --body "$body" \
      --relates-to "$relates_to" 2>&1)" || true
  else
    output="$(bash "$SCRIPT_DIR/create-entry.sh" \
      --id "$chunk_id" \
      --category "$category" \
      --scope-tags "$SCOPE_TAGS" \
      --source-unit "${SPEC_PATH}#${source_section}" \
      --source-type "spec-ingest" \
      --description "$description" \
      --body "$body" 2>&1)" || true
  fi

  case "$output" in
    CREATED:*)
      CREATED_COUNT=$((CREATED_COUNT + 1))
      if [ -n "$content_hash" ]; then
        local detail_file="$INGEST_PROJECT_ROOT/knowledge/$category/$chunk_id.md"
        if [ -f "$detail_file" ]; then
          sed_i "s|^content_hash: .*|content_hash: \"$content_hash\"|" "$detail_file"
        fi
      fi
      # Pass through the CREATED: line from create-entry.sh
      printf '%s\n' "$output"
      ;;
    EXISTS:*)
      SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
      ;;
    *)
      echo "ERROR: create-entry.sh failed for $chunk_id: $output" >&2
      ;;
  esac
}

# --- Helper: create a single spec chunk (decision-layer wrapped) ---
# Usage: create_chunk <id> <category> <source_section> <description> <body> [relates_to]
#
# Emits one of three intermediate decision prefixes to stdout:
#   DECIDE-NEW:       -- no prior entry exists
#   DECIDE-UNCHANGED: -- prior entry's content_hash matches (no write)
#   DECIDE-CHANGED:   -- prior entry exists but hash differs (T02 wires supersession)
#
# Also appends "id|category" to the per-PID observed-ID log so T02's
# REMOVED-detection pass can diff observed vs on-disk.
create_chunk() {
  local chunk_id="$1"
  local category="$2"
  local source_section="$3"
  local description="$4"
  local body="$5"
  local relates_to="${6:-}"

  # Compute content hash on normalized body
  local normalized_body=""
  normalized_body="$(normalize_for_hash "$body")"
  local content_hash=""
  content_hash="$(compute_content_hash "$normalized_body")" || true

  # Record ID in the observed log so T02 can diff for REMOVED entries
  echo "$chunk_id|$category" >> "$INGEST_OBSERVED_LOG"

  # Decide what to do based on hash comparison
  local decision=""
  decision="$(classify_chunk_decision "$chunk_id" "$content_hash")"

  case "$decision" in
    NEW)
      _do_create_chunk "$chunk_id" "$category" "$source_section" \
        "$description" "$body" "$relates_to" "$content_hash"
      ;;
    UNCHANGED)
      SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
      echo "SKIPPED: $chunk_id"
      ;;
    CHANGED)
      local new_id=""
      new_id="$(next_version_id "$chunk_id")"
      _do_create_chunk "$new_id" "$category" "$source_section" \
        "$description" "$body" "$relates_to" "$content_hash"
      # Wire the supersession chain
      local sup_out=""
      sup_out="$(bash "$SCRIPT_DIR/supersede-entry.sh" \
        --old-id "$chunk_id" --new-id "$new_id" 2>&1)" || true
      case "$sup_out" in
        SUPERSEDED:*|ALREADY_SUPERSEDED:*) : ;;
        *) echo "ERROR: supersede-entry.sh failed for $chunk_id -> $new_id: $sup_out" >&2 ;;
      esac
      SUPERSEDED_COUNT=$((SUPERSEDED_COUNT + 1))
      echo "SUPERSEDED: $chunk_id -> $new_id"
      emit_phase_impact "$chunk_id" "$new_id"
      ;;
  esac
}

# --- dump_observed_log ---
# Echoes "id|category" for every chunk observed during this ingest run.
# Consumed by T02's REMOVED-detection pass.
dump_observed_log() {
  if [ -f "$INGEST_OBSERVED_LOG" ]; then
    cat "$INGEST_OBSERVED_LOG"
  fi
}

# --- Section classifiers ---

# --- Stories classifier ---
# Splits on ### User Story headings, extracts story text and acceptance scenarios
classify_stories_section() {
  local body="$1"
  local current_story_name=""
  local current_story_num=""
  local current_story_body=""
  local story_id=""

  # Process line by line
  local sline=""
  while IFS= read -r sline || [ -n "$sline" ]; do
    # Detect ### User Story heading
    case "$sline" in
      '### User Story '*)
        # Dispatch previous story if any
        if [ -n "$current_story_name" ]; then
          _emit_story "$current_story_num" "$current_story_name" "$current_story_body" "$story_id"
        fi
        # Extract story number and name
        # Format: ### User Story N - Name (Priority: PN)
        current_story_num="$(printf '%s' "$sline" | sed 's/^### User Story \([0-9]*\).*/\1/')"
        current_story_name="$(printf '%s' "$sline" | sed 's/^### User Story [0-9]* *- *//;s/ *(Priority:.*//')"
        current_story_body=""
        US_SEQ=$((US_SEQ + 1))
        story_id="$(printf 'SPEC-US-%03d' "$US_SEQ")"
        ;;
      *)
        # Accumulate story body
        if [ -n "$current_story_name" ]; then
          if [ -z "$current_story_body" ]; then
            current_story_body="$sline"
          else
            current_story_body="$current_story_body
$sline"
          fi
        fi
        ;;
    esac
  done <<EOF_STORIES
$body
EOF_STORIES

  # Dispatch final story
  if [ -n "$current_story_name" ]; then
    _emit_story "$current_story_num" "$current_story_name" "$current_story_body" "$story_id"
  fi
}

# Helper: emit a story chunk and its acceptance scenarios
_emit_story() {
  local story_num="$1"
  local story_name="$2"
  local story_body="$3"
  local story_id="$4"

  # Split story body into narrative (before Acceptance Scenarios) and AC section
  local story_text=""
  local ac_section=""
  local in_ac_section=0

  local eline=""
  while IFS= read -r eline || [ -n "$eline" ]; do
    case "$eline" in
      *"Acceptance Scenarios"*)
        in_ac_section=1
        ;;
      *)
        if [ "$in_ac_section" -eq 0 ]; then
          if [ -z "$story_text" ]; then
            story_text="$eline"
          else
            story_text="$story_text
$eline"
          fi
        else
          if [ -z "$ac_section" ]; then
            ac_section="$eline"
          else
            ac_section="$ac_section
$eline"
          fi
        fi
        ;;
    esac
  done <<EOF_STORY_BODY
$story_body
EOF_STORY_BODY

  # Create the story entry
  create_chunk "$story_id" "spec/story" "US-${story_num}" "$story_name" "$story_text"

  # Parse and create acceptance scenarios from the AC section
  if [ -n "$ac_section" ]; then
    _parse_acceptance_scenarios "$ac_section" "$story_id"
  fi
}

# Helper: parse numbered Given/When/Then blocks into acceptance chunks
_parse_acceptance_scenarios() {
  local ac_body="$1"
  local parent_story_id="$2"
  local current_ac_text=""

  local aline=""
  while IFS= read -r aline || [ -n "$aline" ]; do
    # Detect numbered AC items: "N. **Given**" or "N. Given"
    case "$aline" in
      [0-9]*'. '**|[0-9]*'. **Given'*|[0-9]*'. Given'*)
        # Emit previous AC if any
        if [ -n "$current_ac_text" ]; then
          AC_SEQ=$((AC_SEQ + 1))
          local ac_id
          ac_id="$(printf 'SPEC-AC-%03d' "$AC_SEQ")"
          # Extract first sentence as description (up to 80 chars)
          local ac_desc
          ac_desc="$(printf '%s' "$current_ac_text" | head -1 | sed 's/^[0-9]*\. *//' | sed 's/\*\*//g' | cut -c1-80)"
          create_chunk "$ac_id" "spec/acceptance" "AC-${AC_SEQ}" "$ac_desc" "$current_ac_text" "$parent_story_id"
        fi
        current_ac_text="$aline"
        ;;
      *)
        # Continuation of current AC
        if [ -n "$current_ac_text" ]; then
          current_ac_text="$current_ac_text
$aline"
        fi
        ;;
    esac
  done <<EOF_AC
$ac_body
EOF_AC

  # Emit final AC
  if [ -n "$current_ac_text" ]; then
    AC_SEQ=$((AC_SEQ + 1))
    local ac_id
    ac_id="$(printf 'SPEC-AC-%03d' "$AC_SEQ")"
    local ac_desc
    ac_desc="$(printf '%s' "$current_ac_text" | head -1 | sed 's/^[0-9]*\. *//' | sed 's/\*\*//g' | cut -c1-80)"
    create_chunk "$ac_id" "spec/acceptance" "AC-${AC_SEQ}" "$ac_desc" "$current_ac_text" "$parent_story_id"
  fi
}

# --- Requirements classifier ---
# Parses - **FR-NNN**: items from the Functional Requirements section
classify_requirements_section() {
  local body="$1"
  local current_fr_id=""
  local current_fr_body=""
  local rline=""

  while IFS= read -r rline || [ -n "$rline" ]; do
    # Detect FR-NNN items: "- **FR-NNN**: description"
    case "$rline" in
      *'**FR-'[0-9]*)
        # Emit previous FR if any
        if [ -n "$current_fr_id" ]; then
          _emit_requirement "$current_fr_id" "$current_fr_body"
        fi
        # Extract FR ID number. Accept both:
        #   - **FR-N**: desc
        #   - **FR-N (slug-or-anything)**: desc
        # The numeric ID is what matters; the optional parenthetical is decoration.
        current_fr_id="$(printf '%s' "$rline" | sed -n 's/.*\*\*FR-\([0-9][0-9]*\)\([^*]*\)\*\*.*/\1/p')"
        if [ -z "$current_fr_id" ]; then
          echo "ERROR: ingest-spec.sh: line looks like an FR marker but no numeric ID could be extracted. Aborting to avoid silent data loss." >&2
          echo "ERROR: offending line: $rline" >&2
          exit 1
        fi
        current_fr_body="$rline"
        ;;
      '  '*)
        # Continuation line (indented under the FR item)
        if [ -n "$current_fr_id" ]; then
          current_fr_body="$current_fr_body
$rline"
        fi
        ;;
      '')
        # Blank line -- part of current FR if we have one
        if [ -n "$current_fr_id" ]; then
          current_fr_body="$current_fr_body
$rline"
        fi
        ;;
      *)
        # Non-FR content -- emit previous and reset
        if [ -n "$current_fr_id" ]; then
          _emit_requirement "$current_fr_id" "$current_fr_body"
          current_fr_id=""
          current_fr_body=""
        fi
        ;;
    esac
  done <<EOF_FR
$body
EOF_FR

  # Emit final FR
  if [ -n "$current_fr_id" ]; then
    _emit_requirement "$current_fr_id" "$current_fr_body"
  fi
}

_emit_requirement() {
  local fr_num="$1"
  local fr_body="$2"

  local fr_padded
  fr_padded="$(printf '%03d' "$fr_num")"
  local fr_id="SPEC-FR-${fr_padded}"
  FR_SEQ=$((FR_SEQ + 1))
  # Extract description: strip the "- **FR-NNN**: " or "- **FR-NNN (slug)**: "
  # prefix from first line. The optional parenthetical is decoration.
  local description
  description="$(printf '%s' "$fr_body" | head -1 | sed 's/^- \*\*FR-[0-9][0-9]*[^*]*\*\*:[[:space:]]*//')"
  create_chunk "$fr_id" "spec/requirement" "FR-${fr_padded}" "$description" "$fr_body"
}

# --- Constraints classifier ---
# Parses bullet items under ## Constraints
classify_constraints_section() {
  local body="$1"
  local current_con_body=""
  local cline=""

  while IFS= read -r cline || [ -n "$cline" ]; do
    case "$cline" in
      '- '*)
        # New constraint item
        if [ -n "$current_con_body" ]; then
          _emit_constraint "$current_con_body"
        fi
        current_con_body="$cline"
        ;;
      '  '*)
        # Continuation of current constraint
        if [ -n "$current_con_body" ]; then
          current_con_body="$current_con_body
$cline"
        fi
        ;;
      '')
        # Blank lines within constraint
        if [ -n "$current_con_body" ]; then
          current_con_body="$current_con_body
$cline"
        fi
        ;;
      *)
        # Non-list content, emit and reset
        if [ -n "$current_con_body" ]; then
          _emit_constraint "$current_con_body"
          current_con_body=""
        fi
        ;;
    esac
  done <<EOF_CON
$body
EOF_CON

  # Emit final constraint
  if [ -n "$current_con_body" ]; then
    _emit_constraint "$current_con_body"
  fi
}

_emit_constraint() {
  local con_body="$1"
  CON_SEQ=$((CON_SEQ + 1))
  local con_id
  con_id="$(printf 'SPEC-CON-%03d' "$CON_SEQ")"
  # Extract description: strip "- " prefix and any bold markers from first line
  local description
  description="$(printf '%s' "$con_body" | head -1 | sed 's/^- //' | sed 's/\*\*//g' | cut -c1-80)"
  create_chunk "$con_id" "spec/constraint" "CON-${CON_SEQ}" "$description" "$con_body"
}

# --- Non-goals classifier ---
# Parses bullet items under ## Non-Goals
classify_nongoals_section() {
  local body="$1"
  local current_ng_body=""
  local nline=""

  while IFS= read -r nline || [ -n "$nline" ]; do
    case "$nline" in
      '- '*)
        if [ -n "$current_ng_body" ]; then
          _emit_nongoal "$current_ng_body"
        fi
        current_ng_body="$nline"
        ;;
      '  '*)
        if [ -n "$current_ng_body" ]; then
          current_ng_body="$current_ng_body
$nline"
        fi
        ;;
      '')
        if [ -n "$current_ng_body" ]; then
          current_ng_body="$current_ng_body
$nline"
        fi
        ;;
      *)
        if [ -n "$current_ng_body" ]; then
          _emit_nongoal "$current_ng_body"
          current_ng_body=""
        fi
        ;;
    esac
  done <<EOF_NG
$body
EOF_NG

  if [ -n "$current_ng_body" ]; then
    _emit_nongoal "$current_ng_body"
  fi
}

_emit_nongoal() {
  local ng_body="$1"
  NG_SEQ=$((NG_SEQ + 1))
  local ng_id
  ng_id="$(printf 'SPEC-NG-%03d' "$NG_SEQ")"
  local description
  description="$(printf '%s' "$ng_body" | head -1 | sed 's/^- //' | sed 's/\*\*//g' | cut -c1-80)"
  create_chunk "$ng_id" "spec/non-goal" "NG-${NG_SEQ}" "$description" "$ng_body"
}

# --- NFR classifier ---
# Parses bullet items under ## Non-Functional Requirements
classify_nfr_section() {
  local body="$1"
  local current_nfr_body=""
  local fline=""

  while IFS= read -r fline || [ -n "$fline" ]; do
    case "$fline" in
      '- '*)
        if [ -n "$current_nfr_body" ]; then
          _emit_nfr "$current_nfr_body"
        fi
        current_nfr_body="$fline"
        ;;
      '  '*)
        if [ -n "$current_nfr_body" ]; then
          current_nfr_body="$current_nfr_body
$fline"
        fi
        ;;
      '')
        if [ -n "$current_nfr_body" ]; then
          current_nfr_body="$current_nfr_body
$fline"
        fi
        ;;
      *)
        if [ -n "$current_nfr_body" ]; then
          _emit_nfr "$current_nfr_body"
          current_nfr_body=""
        fi
        ;;
    esac
  done <<EOF_NFR
$body
EOF_NFR

  if [ -n "$current_nfr_body" ]; then
    _emit_nfr "$current_nfr_body"
  fi
}

_emit_nfr() {
  local nfr_body="$1"
  NFR_SEQ=$((NFR_SEQ + 1))
  local nfr_id
  nfr_id="$(printf 'SPEC-NFR-%03d' "$NFR_SEQ")"
  local description
  description="$(printf '%s' "$nfr_body" | head -1 | sed 's/^- //' | sed 's/\*\*//g' | cut -c1-80)"
  create_chunk "$nfr_id" "spec/nfr" "NFR-${NFR_SEQ}" "$description" "$nfr_body"
}

# --- Section splitter ---
# Reads the spec line by line, splits on ## headings, routes each section
# to the appropriate classifier.

current_h2=""
current_h2_body=""
current_story_heading=""
current_story_body=""
in_story=0

dispatch_section() {
  local section_name="$1"
  local section_body="$2"

  # Skip empty sections
  if [ -z "$section_body" ]; then
    return 0
  fi

  case "$section_name" in
    "User Scenarios"*|"User Stories"*)
      classify_stories_section "$section_body"
      ;;
    "Functional Requirements"*)
      classify_requirements_section "$section_body"
      ;;
    "Constraints"*)
      classify_constraints_section "$section_body"
      ;;
    "Non-Goals"*|"Non Goals"*)
      classify_nongoals_section "$section_body"
      ;;
    "Non-Functional Requirements"*|"NFRs"*)
      classify_nfr_section "$section_body"
      ;;
    *)
      # Sections we don't classify: Problem Statement, Success Criteria,
      # Dependencies, etc. Skip silently.
      ;;
  esac
}

# Main read loop
while IFS= read -r line || [ -n "$line" ]; do
  # Detect ## heading (h2)
  case "$line" in
    '## '*)
      # Dispatch previous section
      if [ -n "$current_h2" ]; then
        dispatch_section "$current_h2" "$current_h2_body"
      fi
      # Start new section -- strip "## " prefix and any trailing markup
      current_h2="${line#\#\# }"
      # Remove trailing markup like " *(mandatory)*"
      current_h2="$(printf '%s' "$current_h2" | sed 's/ \*.*$//')"
      current_h2_body=""
      ;;
    *)
      # Accumulate body
      if [ -n "$current_h2" ]; then
        if [ -z "$current_h2_body" ]; then
          current_h2_body="$line"
        else
          current_h2_body="$current_h2_body
$line"
        fi
      fi
      ;;
  esac
done < "$SPEC_PATH"

# Dispatch final section
if [ -n "$current_h2" ]; then
  dispatch_section "$current_h2" "$current_h2_body"
fi

# --- REMOVED detection pass ---
# For every SPEC-* entry on disk whose ID was not observed during this
# ingest, mark it superseded_by: REMOVED and emit REVIEW lines for any
# phase-scoped tags.
detect_removed_entries() {
  local spec_dir="$INGEST_PROJECT_ROOT/knowledge/spec"
  if [ ! -d "$spec_dir" ]; then
    return 0
  fi

  # Build the observed-ID set (one ID per line, category stripped)
  local observed_ids=""
  observed_ids="$(dump_observed_log | awk -F'|' '{print $1}' | sort -u)"

  # Walk every SPEC-*.md under spec/*/, check if its ID appears in observed
  local disk_file=""
  for disk_file in "$spec_dir"/*/SPEC-*.md; do
    [ -f "$disk_file" ] || continue
    local disk_id=""
    disk_id="$(basename "$disk_file" .md)"

    # Skip versioned entries like SPEC-FR-003-v2 — those were produced by
    # this ingest as successors and are not candidates for REMOVED.
    case "$disk_id" in
      *-v[0-9]*) continue ;;
    esac

    # Skip entries already superseded (including REMOVED)
    local existing_sup=""
    existing_sup="$(fm_field "$disk_file" "superseded_by")"
    if [ -n "$existing_sup" ]; then
      continue
    fi

    # Check observed set membership
    local found=""
    found="$(printf '%s\n' "$observed_ids" | grep -x "$disk_id" || true)"
    if [ -n "$found" ]; then
      continue
    fi

    # Unobserved and not already superseded — mark REMOVED
    sed_i "s|^superseded_by: .*|superseded_by: \"REMOVED\"|" "$disk_file"
    REMOVED_COUNT=$((REMOVED_COUNT + 1))
    echo "REMOVED: $disk_id"
    emit_phase_impact "$disk_id" "REMOVED"
  done
}

detect_removed_entries

# --- Rebuild index ---
bash "$SCRIPT_DIR/rebuild-index.sh"

# --- Summary ---
echo "INGEST: $SLUG complete. created=$CREATED_COUNT skipped=$SKIPPED_COUNT superseded=$SUPERSEDED_COUNT removed=$REMOVED_COUNT review=$REVIEW_COUNT"
