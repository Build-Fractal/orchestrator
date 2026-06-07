#!/usr/bin/env bash
# scripts/knowledge/write-decisions.sh — M034 P01 (FR-2/FR-3 + PC-1 + #Q-1).
#
# Reads the full FR-1 decision-entry array as a JSON document on stdin and
# emits a schema-valid *-DECISIONS.md packet matching templates/decisions-packet.md.
# Implements the #Q-1 append-with-supersede-chain so re-runs preserve audit history.
#
# Usage:
#   write-decisions.sh --milestone=<M> --artifact=<primary-artifact-path> --out=<packet-path>  < entries.json
#     --out=-  writes the packet to stdout (mirrors write-summary.sh's "-" sentinel).
#
# stdin wire format:
#   {"decisions": [ { "id", "summary", "picked_value", "rationale",
#                     "alternatives_considered", "concrete_impact",
#                     "severity", "type" }, ... ]}
#   Keys are EXACTLY the FR-1 names. severity/type may be absent -> SSOT defaults.
#
# Escaping contract (RISK-1): NONE required of the caller. Each field is
# extracted with `jq -r` and written via quoted variable expansion / printf '%s'.
# The writer NEVER re-shell-interprets a field body (no eval, no unquoted re-expansion).
#
# jq is REQUIRED for this script (structured multi-entry parse). Fail loud if absent.
#
# Hash choice: shasum -a 256, first 16 hex chars. Present on macOS + Linux.
# content_hash only needs intra-file stability (idempotency), not cross-machine repro.
#
# Bash 3.2 / POSIX-sh single file (CON-1 / AD-19): no declare -A, no ${var,,},
# no process substitution. Pipes/awk/cut/$() permitted in the body (MEM004 carve-out).

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=scripts/knowledge/lib/decisions-constants.sh
. "$SCRIPT_DIR/lib/decisions-constants.sh"

# --- Step 2: jq-required guard.
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: write-decisions.sh requires jq (structured multi-entry parse). Install jq and retry." >&2
  exit 1
fi

# --- Step 3: flag parse (--milestone= / --artifact= / --out=).
MILESTONE=""
ARTIFACT=""
OUT=""
for arg in "$@"; do
  case "$arg" in
    --milestone=*) MILESTONE="${arg#*=}" ;;
    --artifact=*)  ARTIFACT="${arg#*=}" ;;
    --out=*)       OUT="${arg#*=}" ;;
    *)
      echo "ERROR: Unrecognized argument '$arg'. Use --milestone= / --artifact= / --out=." >&2
      exit 1
      ;;
  esac
done

if [ -z "$MILESTONE" ]; then
  echo "ERROR: --milestone=<M> is required." >&2
  exit 1
fi
if [ -z "$ARTIFACT" ]; then
  echo "ERROR: --artifact=<path> is required." >&2
  exit 1
fi
if [ -z "$OUT" ]; then
  echo "ERROR: --out=<packet-path|-> is required." >&2
  exit 1
fi

# --- Step 4: read all of stdin; validate {"decisions":[...]}.
STDIN_DOC=$(cat)
if ! printf '%s' "$STDIN_DOC" | jq -e '.decisions | type == "array"' >/dev/null 2>&1; then
  echo 'ERROR: stdin is not a {"decisions":[...]} document' >&2
  exit 1
fi

ENTRY_COUNT=$(printf '%s' "$STDIN_DOC" | jq '.decisions | length')

# Compute the content_hash over the seven body fields in a fixed order,
# unit-separator (\x1f) delimited. Intra-file stable; idempotency key.
US=$(printf '\037')
compute_hash() {
  # args: summary picked_value rationale alternatives_considered concrete_impact severity type
  concat="$1$US$2$US$3$US$4$US$5$US$6$US$7"
  printf '%s' "$concat" | shasum -a 256 | cut -c1-16
}

# Emit one block to stdout. Trailing args carry optional supersede fields.
#   emit_block id summary picked rationale alts impact severity type hash [supersedes] [superseded_by]
emit_block() {
  b_id="$1"; b_summary="$2"; b_picked="$3"; b_rationale="$4"
  b_alts="$5"; b_impact="$6"; b_severity="$7"; b_type="$8"; b_hash="$9"
  shift 9
  b_supersedes="${1:-}"
  b_superseded_by="${2:-}"
  printf '## %s\n' "$b_id"
  printf -- '- **id**: %s\n' "$b_id"
  printf -- '- **summary**: %s\n' "$b_summary"
  printf -- '- **picked_value**: %s\n' "$b_picked"
  printf -- '- **rationale**: %s\n' "$b_rationale"
  printf -- '- **alternatives_considered**: %s\n' "$b_alts"
  printf -- '- **concrete_impact**: %s\n' "$b_impact"
  printf -- '- **severity**: %s\n' "$b_severity"
  printf -- '- **type**: %s\n' "$b_type"
  printf -- '- **content_hash**: %s\n' "$b_hash"
  if [ -n "$b_supersedes" ]; then
    printf -- '- **supersedes**: %s\n' "$b_supersedes"
  fi
  if [ -n "$b_superseded_by" ]; then
    printf -- '- **superseded_by**: %s\n' "$b_superseded_by"
  fi
}

# Strip a -vN suffix to get the base (logical) id.
base_id_of() {
  printf '%s\n' "$1" | sed -E 's/-v[0-9]+$//'
}

# --- Supersede-chain helpers over an EXISTING packet file. ----------------
#
# Each block in the file begins with a `## <id>` heading and contains
# `- **id**: <id>`, `- **content_hash**: <hash>`, and (if superseded) a
# `- **superseded_by**: <id>` bullet. Blocks are separated by blank lines.

# Print, for base-id $2 in file $1, the chain tip: the highest -vN block
# (bare == v1) that has NO superseded_by bullet. Output two lines:
#   <tip-id>
#   <tip-hash>
# Prints nothing if no such block exists.
find_chain_tip() {
  ct_file="$1"
  ct_base="$2"
  awk -v base="$ct_base" '
    function flush() {
      if (cur_id != "") {
        # version: bare == 1, else the -vN number
        ver = 1
        if (match(cur_id, /-v[0-9]+$/)) {
          vstr = substr(cur_id, RSTART + 2)
          ver = vstr + 0
        }
        if (cur_base == base && cur_superseded == 0 && ver >= best_ver) {
          best_ver = ver
          best_id = cur_id
          best_hash = cur_hash
        }
      }
    }
    /^## / {
      flush()
      cur_id = ""; cur_base = ""; cur_hash = ""; cur_superseded = 0
      next
    }
    /^- \*\*id\*\*: / {
      cur_id = $0
      sub(/^- \*\*id\*\*: /, "", cur_id)
      cur_base = cur_id
      sub(/-v[0-9]+$/, "", cur_base)
      next
    }
    /^- \*\*content_hash\*\*: / {
      cur_hash = $0
      sub(/^- \*\*content_hash\*\*: /, "", cur_hash)
      next
    }
    /^- \*\*superseded_by\*\*: / {
      cur_superseded = 1
      next
    }
    END {
      flush()
      if (best_id != "") {
        print best_id
        print best_hash
      }
    }
  ' "$ct_file"
}

# Amend the block whose `- **id**: <tip-id>` matches, inserting a
# `- **superseded_by**: <new-id>` bullet after that block's content_hash line.
# Idempotent: if the bullet is already present in that block, no-op.
# Mirrors extract-supersede.sh::supersede_amend_prior_chunk (awk + tmpfile/mv).
amend_prior_block() {
  ap_file="$1"
  ap_tip_id="$2"
  ap_new_id="$3"
  ap_tmp=$(mktemp "${TMPDIR:-/tmp}/m034-p01-amend.XXXXXX")
  awk -v tip="$ap_tip_id" -v newid="$ap_new_id" '
    /^## / { in_target = 0 }
    /^- \*\*id\*\*: / {
      idval = $0
      sub(/^- \*\*id\*\*: /, "", idval)
      in_target = (idval == tip) ? 1 : 0
    }
    { print }
    /^- \*\*content_hash\*\*: / {
      if (in_target == 1) {
        print "- **superseded_by**: " newid
        in_target = 0
      }
    }
  ' "$ap_file" > "$ap_tmp"
  mv "$ap_tmp" "$ap_file"
}

# --- Per-entry extraction + dispatch. -------------------------------------

# Fresh-packet mode flag: stdout OR --out file absent.
FRESH=0
if [ "$OUT" = "-" ] || [ ! -f "$OUT" ]; then
  FRESH=1
fi

# Derive the source label / artifact-label from the artifact path.
SOURCE_LABEL="$MILESTONE"
ARTIFACT_LABEL="$ARTIFACT"

# Buffer for fresh-mode emission (so we can route to stdout or a file).
FRESH_BODY=""
WRITTEN=0

i=0
while [ "$i" -lt "$ENTRY_COUNT" ]; do
  e_id=$(printf '%s' "$STDIN_DOC" | jq -r ".decisions[$i].id // empty")
  e_summary=$(printf '%s' "$STDIN_DOC" | jq -r ".decisions[$i].summary // empty")
  e_picked=$(printf '%s' "$STDIN_DOC" | jq -r ".decisions[$i].picked_value // empty")
  e_rationale=$(printf '%s' "$STDIN_DOC" | jq -r ".decisions[$i].rationale // empty")
  e_alts=$(printf '%s' "$STDIN_DOC" | jq -r ".decisions[$i].alternatives_considered // empty")
  e_impact=$(printf '%s' "$STDIN_DOC" | jq -r ".decisions[$i].concrete_impact // empty")
  e_severity=$(printf '%s' "$STDIN_DOC" | jq -r ".decisions[$i].severity // empty")
  e_type=$(printf '%s' "$STDIN_DOC" | jq -r ".decisions[$i].type // empty")

  if [ -z "$e_id" ]; then
    echo "ERROR: decisions[$i] is missing required field 'id'." >&2
    exit 1
  fi

  # SSOT defaults.
  if [ -z "$e_severity" ]; then
    e_severity="$DECISIONS_SEVERITY_DEFAULT"
  fi
  if [ -z "$e_type" ]; then
    e_type="$DECISIONS_TYPE_DEFAULT"
  fi

  # Validate against the SSOT validators.
  if [ "$(decisions_is_valid_severity "$e_severity")" != "ok" ]; then
    echo "ERROR: decisions[$i] (id=$e_id) has invalid severity '$e_severity' (allowed: $DECISIONS_SEVERITY_VALUES)." >&2
    exit 1
  fi
  if [ "$(decisions_is_valid_type "$e_type")" != "ok" ]; then
    echo "ERROR: decisions[$i] (id=$e_id) has invalid type '$e_type' (allowed: $DECISIONS_TYPE_VALUES)." >&2
    exit 1
  fi

  e_hash=$(compute_hash "$e_summary" "$e_picked" "$e_rationale" "$e_alts" "$e_impact" "$e_severity" "$e_type")

  if [ "$FRESH" -eq 1 ]; then
    # Fresh packet: emit every entry with no supersede fields.
    block=$(emit_block "$e_id" "$e_summary" "$e_picked" "$e_rationale" "$e_alts" "$e_impact" "$e_severity" "$e_type" "$e_hash")
    if [ -z "$FRESH_BODY" ]; then
      FRESH_BODY="$block"
    else
      FRESH_BODY="$FRESH_BODY

$block"
    fi
    WRITTEN=$((WRITTEN + 1))
  else
    # Append-with-supersede-chain against the existing file.
    base=$(base_id_of "$e_id")
    tip_info=$(find_chain_tip "$OUT" "$base")
    tip_id=$(printf '%s\n' "$tip_info" | sed -n '1p')
    tip_hash=$(printf '%s\n' "$tip_info" | sed -n '2p')

    if [ -z "$tip_id" ]; then
      # NEW logical id -> append a fresh `## <base>` block.
      block=$(emit_block "$base" "$e_summary" "$e_picked" "$e_rationale" "$e_alts" "$e_impact" "$e_severity" "$e_type" "$e_hash")
      printf '\n%s\n' "$block" >> "$OUT"
      WRITTEN=$((WRITTEN + 1))
    elif [ "$tip_hash" = "$e_hash" ]; then
      # Idempotent no-op: do not write, do not touch the file for this entry.
      :
    else
      # Hash differs -> append a superseding -v<N+1> block + amend the tip.
      tip_ver=1
      case "$tip_id" in
        *-v[0-9]*)
          tip_ver=$(printf '%s\n' "$tip_id" | sed -E 's/.*-v([0-9]+)$/\1/')
          ;;
      esac
      next_ver=$((tip_ver + 1))
      new_id="${base}-v${next_ver}"
      block=$(emit_block "$new_id" "$e_summary" "$e_picked" "$e_rationale" "$e_alts" "$e_impact" "$e_severity" "$e_type" "$e_hash" "$tip_id")
      printf '\n%s\n' "$block" >> "$OUT"
      amend_prior_block "$OUT" "$tip_id" "$new_id"
      WRITTEN=$((WRITTEN + 1))
    fi
  fi

  i=$((i + 1))
done

# --- Fresh-packet emission (frontmatter + buffered blocks). ----------------
if [ "$FRESH" -eq 1 ]; then
  emit_fresh_packet() {
    printf -- '---\n'
    printf 'schema_version: "%s"\n' "$DECISIONS_SCHEMA_VERSION"
    printf 'type: decision-packet\n'
    printf 'milestone: "%s"\n' "$MILESTONE"
    printf 'source: "%s"\n' "$SOURCE_LABEL"
    printf 'artifact: "%s"\n' "$ARTIFACT"
    printf -- '---\n'
    printf '\n'
    printf '# Decision Packet — %s\n' "$ARTIFACT_LABEL"
    printf '\n'
    printf '%s\n' "$FRESH_BODY"
  }

  if [ "$OUT" = "-" ]; then
    emit_fresh_packet
  else
    out_dir=$(dirname "$OUT")
    mkdir -p "$out_dir"
    emit_fresh_packet > "$OUT"
  fi
fi

# --- Success line. ---------------------------------------------------------
echo "DECISIONS: $WRITTEN entries written to $OUT"
