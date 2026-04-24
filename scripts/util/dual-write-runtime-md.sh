#!/usr/bin/env bash
# scripts/util/dual-write-runtime-md.sh — FR-12 marker-bounded dual-write helper.
# Writes a content fragment between
#   # >>> orchestrator:<region-name> >>>
#   # <<< orchestrator:<region-name> <<<
# in one or more target files. Preserves bytes outside markers byte-identically.
#
# Usage: dual-write-runtime-md.sh --marker <region-name> --content <path-to-fragment>
#                                 [--file CLAUDE.md] [--file AGENTS.md]
#                                 [--root <project-root>] [--dry-run]
#
#        dual-write-runtime-md.sh --marker <region-name> --append-entry "<text>"
#                                 [--file CLAUDE.md] [--file AGENTS.md]
#                                 [--root <project-root>] [--dry-run]
#
# Two write modes:
#   --content <path>          REPLACE: the marker region's body is overwritten
#                             with the file contents. Caller must reconstruct
#                             every existing line they want to retain.
#   --append-entry "<text>"   PREPEND: the given text is inserted as a new
#                             first line of the region body, with all existing
#                             lines preserved below it (reverse-chronological).
#                             No need to rebuild the rest of the block.
#
# The two modes are mutually exclusive — exactly one must be provided.
#
# Behavior:
#   - If a target file is missing, it is created containing only the marker
#     region with the given content.
#   - If markers are absent in an existing target, they are inserted above
#     the first heading (^#) or at EOF if no heading.
#   - If AGENTS.md is in the target list and .orchestrator/config.yml has
#     `dual_write_agents: false` at top level, AGENTS.md is skipped with a
#     `SKIPPED: AGENTS.md (dual_write_agents=false)` line on stderr.
#   - --dry-run emits one JSONL record per would-be write
#       {"command":"dual-write-runtime-md","action_type":"dual-write-region",
#        "target_path":"...","source_ref":"...","description":"..."}
#     to stdout and makes no disk writes.
#
# Exit: 0 on success; 1 on any error.
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

MARKER=""
CONTENT=""
APPEND_ENTRY=""
APPEND_ENTRY_SET=0
DRY_RUN=0
TARGETS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --marker)
      if [ $# -lt 2 ]; then echo "--marker requires a value" >&2; exit 1; fi
      MARKER="$2"; shift 2
      ;;
    --content)
      if [ $# -lt 2 ]; then echo "--content requires a path" >&2; exit 1; fi
      CONTENT="$2"; shift 2
      ;;
    --append-entry)
      if [ $# -lt 2 ]; then echo "--append-entry requires a value" >&2; exit 1; fi
      APPEND_ENTRY="$2"; APPEND_ENTRY_SET=1; shift 2
      ;;
    --file)
      if [ $# -lt 2 ]; then echo "--file requires a filename" >&2; exit 1; fi
      TARGETS="${TARGETS}${TARGETS:+ }$2"; shift 2
      ;;
    --root)
      if [ $# -lt 2 ]; then echo "--root requires a path" >&2; exit 1; fi
      PROJECT_ROOT="$2"; shift 2
      ;;
    --dry-run) DRY_RUN=1; shift ;;
    --help|-h)
      sed -n '1,/^$/p' "$0" | sed -e 's/^# //' -e 's/^#$//'
      exit 0
      ;;
    *)
      echo "dual-write-runtime-md.sh: unknown flag: $1" >&2; exit 1
      ;;
  esac
done

if [ -z "$MARKER" ]; then echo "missing --marker" >&2; exit 1; fi
if [ -n "$CONTENT" ] && [ "$APPEND_ENTRY_SET" -eq 1 ]; then
  echo "--content and --append-entry are mutually exclusive" >&2; exit 1
fi
if [ -z "$CONTENT" ] && [ "$APPEND_ENTRY_SET" -eq 0 ]; then
  echo "missing --content or --append-entry" >&2; exit 1
fi
if [ -n "$CONTENT" ] && [ ! -f "$CONTENT" ]; then
  echo "missing or unreadable --content: $CONTENT" >&2; exit 1
fi
if [ -z "$TARGETS" ]; then TARGETS="CLAUDE.md AGENTS.md"; fi

# --- Read dual_write_agents toggle from config ---
CONFIG="${PROJECT_ROOT}/.orchestrator/config.yml"
DUAL_WRITE_AGENTS=1
if [ -f "$CONFIG" ]; then
  if grep -qE '^dual_write_agents:[[:space:]]*false' "$CONFIG"; then
    DUAL_WRITE_AGENTS=0
  fi
fi

emit_dry_run_record() {
  local target="$1"
  printf '{"command":"dual-write-runtime-md","action_type":"dual-write-region","target_path":"%s","source_ref":"%s","description":"write marker-bounded region %s"}\n' \
    "$target" "$CONTENT" "$MARKER"
}

write_region() {
  local target="$1"
  local begin="# >>> orchestrator:${MARKER} >>>"
  local end="# <<< orchestrator:${MARKER} <<<"
  local tmp
  tmp="$(mktemp)"

  if [ ! -f "$target" ]; then
    # Create fresh file with just the marker region.
    {
      printf '%s\n' "$begin"
      cat "$CONTENT"
      printf '%s\n' "$end"
    } > "$tmp"
    mv "$tmp" "$target"
    return 0
  fi

  # Existing file: replace between markers, or insert above first heading/EOF.
  if grep -qF "$begin" "$target" && grep -qF "$end" "$target"; then
    # Replace in place. Use awk to copy-then-substitute the region.
    awk -v begin="$begin" -v end="$end" -v content_file="$CONTENT" '
      BEGIN { in_region=0 }
      $0 == begin {
        print $0
        while ((getline line < content_file) > 0) print line
        close(content_file)
        in_region=1
        next
      }
      $0 == end {
        print $0
        in_region=0
        next
      }
      in_region==0 { print }
    ' "$target" > "$tmp"
    mv "$tmp" "$target"
    return 0
  fi

  # Markers absent: insert above first heading, or at EOF if none.
  local first_heading_line
  first_heading_line="$(grep -nE '^#' "$target" | head -1 | awk -F: '{print $1}')"

  if [ -n "$first_heading_line" ]; then
    awk -v before="$first_heading_line" -v begin="$begin" -v end="$end" -v content_file="$CONTENT" '
      NR == before {
        print begin
        while ((getline line < content_file) > 0) print line
        close(content_file)
        print end
      }
      { print }
    ' "$target" > "$tmp"
    mv "$tmp" "$target"
  else
    {
      cat "$target"
      printf '%s\n' "$begin"
      cat "$CONTENT"
      printf '%s\n' "$end"
    } > "$tmp"
    mv "$tmp" "$target"
  fi
}

# Synthesize a per-target content file when --append-entry is in use:
# new entry line, then the existing region body (if any), so the caller
# never has to rebuild the existing block. Returns the path; caller is
# responsible for rm -f.
synthesize_append_content() {
  local target="$1"
  local entry="$2"
  local begin="# >>> orchestrator:${MARKER} >>>"
  local end="# <<< orchestrator:${MARKER} <<<"
  local tmp
  tmp="$(mktemp)"
  printf '%s\n' "$entry" > "$tmp"
  if [ -f "$target" ] && grep -qF "$begin" "$target" && grep -qF "$end" "$target"; then
    awk -v begin="$begin" -v end="$end" '
      BEGIN { in_region=0 }
      $0 == begin { in_region=1; next }
      $0 == end { in_region=0; next }
      in_region==1 { print }
    ' "$target" >> "$tmp"
  fi
  printf '%s' "$tmp"
}

# --- Main: iterate targets ---
for t in $TARGETS; do
  abs_target="${PROJECT_ROOT}/${t}"

  # Apply dual_write_agents=false gate for AGENTS.md only.
  if [ "$t" = "AGENTS.md" ] && [ "$DUAL_WRITE_AGENTS" -eq 0 ]; then
    echo "SKIPPED: AGENTS.md (dual_write_agents=false)" >&2
    continue
  fi

  # Compute effective content. --append-entry generates a per-target temp
  # file that splices the new entry above the existing region body.
  effective_content="$CONTENT"
  per_target_tmp=""
  if [ "$APPEND_ENTRY_SET" -eq 1 ]; then
    per_target_tmp="$(synthesize_append_content "$abs_target" "$APPEND_ENTRY")"
    effective_content="$per_target_tmp"
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    CONTENT="$effective_content" emit_dry_run_record "$abs_target"
    [ -n "$per_target_tmp" ] && rm -f "$per_target_tmp"
    continue
  fi

  CONTENT="$effective_content" write_region "$abs_target"
  echo "WROTE: $abs_target (region=${MARKER})"
  [ -n "$per_target_tmp" ] && rm -f "$per_target_tmp"
done

exit 0
