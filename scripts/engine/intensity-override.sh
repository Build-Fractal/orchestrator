#!/usr/bin/env bash
# scripts/engine/intensity-override.sh -- Mid-workflow intensity override.
#
# Rewrites the `intensity:` field in an intensity-metadata.md file's
# YAML frontmatter, preserving the previous value as original_intensity
# and flagging overridden_by=developer. Does not touch any other file.
#
# FR-004: override remaining stages while preserving completed stages.
#         This script enforces the "other files untouched" half of that
#         contract. Command docs enforce the "future stages read the
#         new value" half via intensity-gate.sh.
#
# Usage:
#   intensity-override.sh --metadata-file <path> --new-intensity <Quick|Standard|Full>
#
# Exit: 0 success, 1 usage/IO error, 2 invalid intensity, 3 no-op rejection.
# Bash 3.2 compatible.

set -u

METADATA_FILE=""
NEW_INTENSITY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --metadata-file)
      METADATA_FILE="${2:-}"; shift 2 ;;
    --new-intensity)
      NEW_INTENSITY="${2:-}"; shift 2 ;;
    *)
      shift ;;
  esac
done

if [[ -z "$METADATA_FILE" ]]; then
  echo "ERROR: --metadata-file is required" >&2
  exit 1
fi
if [[ ! -f "$METADATA_FILE" ]]; then
  echo "ERROR: metadata file not found: $METADATA_FILE" >&2
  exit 1
fi
if [[ -z "$NEW_INTENSITY" ]]; then
  echo "ERROR: --new-intensity is required" >&2
  exit 1
fi

case "$NEW_INTENSITY" in
  Quick|Standard|Full) ;;
  *)
    echo "ERROR: invalid intensity '$NEW_INTENSITY' (expected Quick|Standard|Full)" >&2
    exit 2 ;;
esac

# Read current intensity from the file's YAML frontmatter.
current="$(grep -E '^intensity:' "$METADATA_FILE" | head -n 1 | sed -E 's/^intensity:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')"

if [[ -z "$current" ]]; then
  echo "ERROR: cannot find intensity: field in $METADATA_FILE" >&2
  exit 1
fi

if [[ "$current" = "$NEW_INTENSITY" ]]; then
  echo "ERROR: already at intensity=$NEW_INTENSITY (no-op rejected)" >&2
  exit 3
fi

# Rewrite via tmp + mv (atomic).
tmp_file="$(mktemp)"
# shellcheck disable=SC2064
trap "rm -f '$tmp_file'" EXIT

# AWK pass: modify three frontmatter fields in place. We consider only
# the first YAML frontmatter block (between the first pair of '---'
# lines). Outside that block, lines are copied verbatim.
awk -v new_intensity="$NEW_INTENSITY" -v old_intensity="$current" '
  BEGIN { in_fm = 0; fm_done = 0; seen_ov = 0; seen_orig = 0; }
  {
    if (fm_done == 0 && $0 == "---") {
      if (in_fm == 0) { in_fm = 1; print; next; }
      else {
        # Closing the frontmatter block — inject override/original fields
        # if the original file did not already contain them.
        if (seen_orig == 0) {
          print "original_intensity: \"" old_intensity "\"";
        }
        if (seen_ov == 0) {
          print "overridden_by: \"developer\"";
        }
        print;
        in_fm = 0;
        fm_done = 1;
        next;
      }
    }
    if (in_fm == 1) {
      if ($0 ~ /^intensity:/) {
        print "intensity: \"" new_intensity "\"";
        next;
      }
      if ($0 ~ /^original_intensity:/) {
        # Only set original_intensity if it is currently empty. If it
        # already holds a non-empty prior value we keep the original
        # chain (so that override-then-override traces to the first
        # recommendation, not to the intermediate).
        val = $0;
        sub(/^original_intensity:[[:space:]]*/, "", val);
        gsub(/"/, "", val);
        gsub(/[[:space:]]+$/, "", val);
        if (val == "") {
          print "original_intensity: \"" old_intensity "\"";
        } else {
          print $0;
        }
        seen_orig = 1;
        next;
      }
      if ($0 ~ /^overridden_by:/) {
        print "overridden_by: \"developer\"";
        seen_ov = 1;
        next;
      }
    }
    print;
  }
' "$METADATA_FILE" > "$tmp_file"

# Sanity check: tmp file should not be empty and should still have a frontmatter.
if [[ ! -s "$tmp_file" ]]; then
  echo "ERROR: rewrite produced empty file" >&2
  exit 1
fi
if ! grep -q '^intensity:' "$tmp_file"; then
  echo "ERROR: rewrite lost intensity: field" >&2
  exit 1
fi

mv "$tmp_file" "$METADATA_FILE"
trap - EXIT

echo "OVERRIDE: ${current} -> ${NEW_INTENSITY} in ${METADATA_FILE}"
exit 0
