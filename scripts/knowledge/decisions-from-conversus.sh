#!/usr/bin/env bash
# scripts/knowledge/decisions-from-conversus.sh — M034 P01 (FR-11/FR-12 + AD-6).
#
# The optional conversus *producer*. Runs the existing conversus gate adapter
# over an artifact and maps the resulting gate-result.md (verdict, surviving
# disputes, rationale, deliberation link) into decision-packet entries the
# interactive walkthrough later surfaces — so the operator adjudicates
# conversus's findings rather than re-deriving them.
#
# Usage:
#   decisions-from-conversus.sh --preset=<preset> --artifact=<path> \
#       --milestone=<M> --out=<packet-path> [--source=<path>]...
#
# Strict-when-declared (FR-12 / AD-6, the central invariant): when a gate
# declares `producer: conversus` and the conversus binary is absent/unauthed,
# this producer BLOCKs — exits non-zero with a `pipx install conversus-oss` +
# `conversus login` pointer — and does NOT mark the gate reviewed. It never
# silently SKIPs. The adapter's DEFAULT mode degrades to SKIP+exit-0 on a
# missing binary, so this producer MUST pass `--strict` (which turns a missing
# binary into adapter exit 1), then translate that into the block. The
# `--strict` flag below is therefore load-bearing.
#
# CON-8 discipline: a conversus `BLOCK` verdict is operator-overridable
# *content*, not a hard stop and not the `refuse-entry` policy and not the
# packet `severity: block` field in the policy sense. The mapping records the
# verdict as content; it does not halt. Entry text references "conversus
# verdict" precisely, never collapsing the three "block" senses.
#
# Exit codes:
#   0  mapping succeeded; packet written via write-decisions.sh
#   3  block path (FR-12): missing/unauthed binary, packet NOT written
#   non-zero (other)  flag/arg error, or writer propagated failure
#
# Test-only seams (cf. CONVERSUS_STUB, ORCH_M019_EMIT):
#   DECISIONS_CONV_STUB_MISSING=1  — short-circuit straight to the block path
#     of step 5 (same message, same exit 3) so the strict missing-binary
#     behavior is deterministically testable even on a dev machine that has
#     conversus-oss installed. Routes through the SAME block code as the real
#     missing-binary path, so the test asserts the real behavior.
#   CONVERSUS_STUB=1 + CONVERSUS_STUB_VERDICT=PASS|BLOCK — handled by the
#     adapter; the producer just maps whichever fixture the adapter returns.
#
# Bash 3.2 / POSIX-sh single file (CON-1 / AD-19): no declare -A, no ${var,,},
# no process substitution. jq REQUIRED (encodes free-text bodies safely;
# dispute/rationale bodies carry arbitrary punctuation — the JSON is built with
# jq, never string concatenation). Pipes/awk/sed/$() permitted in the body.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CONV_ADAPTER="$SCRIPT_DIR/../dispatch/adapters/tool/conversus.sh"
WRITER="$SCRIPT_DIR/write-decisions.sh"

# --- jq-required guard.
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: decisions-from-conversus.sh requires jq (encodes free-text bodies safely). Install jq and retry." >&2
  exit 1
fi

# --- Step 1: flag parse.
PRESET=""
ARTIFACT=""
MILESTONE=""
OUT=""
# SOURCES: newline-separated list of --source paths (Bash 3.2: no arrays).
SOURCES=""
for arg in "$@"; do
  case "$arg" in
    --preset=*)    PRESET="${arg#*=}" ;;
    --artifact=*)  ARTIFACT="${arg#*=}" ;;
    --milestone=*) MILESTONE="${arg#*=}" ;;
    --out=*)       OUT="${arg#*=}" ;;
    --source=*)
      _src="${arg#*=}"
      if [ -z "$SOURCES" ]; then
        SOURCES="$_src"
      else
        SOURCES="${SOURCES}
${_src}"
      fi
      ;;
    *)
      echo "ERROR: Unrecognized argument '$arg'. Use --preset= --artifact= --milestone= --out= [--source=]." >&2
      exit 1
      ;;
  esac
done

if [ -z "$PRESET" ]; then
  echo "ERROR: --preset=<preset> is required." >&2
  exit 1
fi
if [ -z "$ARTIFACT" ]; then
  echo "ERROR: --artifact=<path> is required." >&2
  exit 1
fi
if [ -z "$MILESTONE" ]; then
  echo "ERROR: --milestone=<M> is required." >&2
  exit 1
fi
if [ -z "$OUT" ]; then
  echo "ERROR: --out=<packet-path> is required." >&2
  exit 1
fi

# --- Block path (FR-12). Print actionable pointer; do NOT touch the packet;
# exit 3. Used by both the real missing-binary adapter exit and the
# DECISIONS_CONV_STUB_MISSING=1 test seam.
emit_block_path() {
  echo "BLOCK: producer: conversus declared (preset '$PRESET') but the conversus binary is unavailable or unauthed." >&2
  echo "Install and authenticate it, then re-run:" >&2
  echo "  pipx install conversus-oss" >&2
  echo "  conversus login anthropic" >&2
  echo "The gate is NOT marked reviewed and the packet at '$OUT' was left untouched." >&2
  exit 3
}

# --- Step 2: missing-binary test seam.
if [ "${DECISIONS_CONV_STUB_MISSING:-0}" = "1" ]; then
  emit_block_path
fi

# --- Step 3: run the gate into a temp gate-result path.
TMPROOT="${TMPDIR:-/tmp}"
GATE_OUT=$(mktemp "${TMPROOT%/}/m034-p01-gate.XXXXXX")

# Build the adapter argv: gate --strict [--source=<p>]... <preset> <artifact> <gate_out>
# Bash 3.2: assemble positional args via set -- with newline-IFS splitting so
# source paths with spaces survive (split on newline only).
set -- gate --strict
if [ -n "$SOURCES" ]; then
  _argv_tail=""
  _old_ifs="$IFS"
  IFS='
'
  for _s in $SOURCES; do
    [ -n "$_s" ] || continue
    _argv_tail="${_argv_tail}--source=${_s}
"
  done
  IFS="$_old_ifs"
  _old_ifs2="$IFS"
  IFS='
'
  # shellcheck disable=SC2086 # intentional word-splitting on \n IFS
  set -- "$@" $_argv_tail
  IFS="$_old_ifs2"
fi
set -- "$@" "$PRESET" "$ARTIFACT" "$GATE_OUT"

bash "$CONV_ADAPTER" "$@"
gate_rc=$?

# --- Step 4: branch on gate_rc.
case "$gate_rc" in
  0|2)
    # PASS (0) or BLOCK (2): both are CONTENT outcomes — proceed to mapping.
    # BLOCK is not an error; it becomes packet entries the operator adjudicates.
    :
    ;;
  *)
    # 1 (adapter error / missing binary under strict) or any other non-zero:
    # adapter could not produce a load-bearing gate result -> block path.
    rm -f "$GATE_OUT" 2>/dev/null || true
    emit_block_path
    ;;
esac

# --- Step 6: mapping (FR-11). Parse $GATE_OUT.

# verdict — prefer the adapter's own parse-verdict; fall back to frontmatter.
VERDICT=""
_pv=$(bash "$CONV_ADAPTER" parse-verdict "$GATE_OUT" 2>/dev/null)
if [ -n "$_pv" ]; then
  VERDICT=$(printf '%s\n' "$_pv" | sed -n 's/^verdict=//p' | head -n 1)
fi
if [ -z "$VERDICT" ]; then
  VERDICT=$(grep -E '^verdict:' "$GATE_OUT" 2>/dev/null | head -n 1 | sed -E 's/^verdict:[[:space:]]*"?([^"]*)"?.*/\1/')
fi
if [ -z "$VERDICT" ]; then
  echo "ERROR: could not determine verdict from gate-result $GATE_OUT" >&2
  rm -f "$GATE_OUT" 2>/dev/null || true
  exit 1
fi

# Deliberation link: conversus_output_dir frontmatter -> <dir>/summary/final.md;
# else the gate-result path itself.
CONV_DIR=$(grep -E '^conversus_output_dir:' "$GATE_OUT" 2>/dev/null | head -n 1 | sed -E 's/^conversus_output_dir:[[:space:]]*"?([^"]*)"?.*/\1/')
if [ -n "$CONV_DIR" ]; then
  LINK="${CONV_DIR%/}/summary/final.md"
else
  LINK="$GATE_OUT"
fi

# Rationale body: lines after `## Rationale` up to EOF or the next `## `.
RATIONALE=$(awk '
  /^## Rationale[[:space:]]*$/ { capture = 1; next }
  /^## / && capture { exit }
  capture { print }
' "$GATE_OUT")
# Trim leading/trailing blank lines (collapse for a clean single body).
RATIONALE=$(printf '%s\n' "$RATIONALE" | sed -e '/./,$!d' | awk 'NF{last=NR} {line[NR]=$0} END{for(i=1;i<=last;i++) print line[i]}')

# Dispute lines of shape `- **<advocate>**: <claim>` within `## Disputes`.
# Emit one "advocate\tclaim" line per dispute. (Tab-delimited; advocate names
# carry no tabs.) The `(none)` body in the PASS fixture matches no line.
DISPUTES=$(awk '
  /^## Disputes[[:space:]]*$/ { in_d = 1; next }
  /^## / && in_d { in_d = 0 }
  in_d && /^- \*\*[^*]+\*\*:/ {
    line = $0
    # advocate = text between the first ** ** pair.
    adv = line
    sub(/^- \*\*/, "", adv)
    sub(/\*\*:.*$/, "", adv)
    # claim = everything after the **: (and a single following space).
    claim = line
    sub(/^- \*\*[^*]+\*\*:[[:space:]]*/, "", claim)
    print adv "\t" claim
  }
' "$GATE_OUT")

# severity: block when verdict==BLOCK else warn.
if [ "$VERDICT" = "BLOCK" ]; then
  SEVERITY="block"
else
  SEVERITY="warn"
fi

PICKED="conversus verdict: ${VERDICT}"
ALTS="See full deliberation: ${LINK}"

# Build {"decisions":[...]} with jq. Each entry is assembled via --arg so every
# free-text body (rationale, claim, advocate) is JSON-encoded safely.
build_entry() {
  # build_entry <id> <summary> <picked> <rationale> <alts> <impact> <severity> <type>
  jq -n \
    --arg id "$1" \
    --arg summary "$2" \
    --arg picked "$3" \
    --arg rationale "$4" \
    --arg alts "$5" \
    --arg impact "$6" \
    --arg severity "$7" \
    --arg type "$8" \
    '{id:$id, summary:$summary, picked_value:$picked, rationale:$rationale, alternatives_considered:$alts, concrete_impact:$impact, severity:$severity, type:$type}'
}

ENTRIES=""
N=0
if [ -n "$DISPUTES" ]; then
  _d_old_ifs="$IFS"
  IFS='
'
  for _row in $DISPUTES; do
    [ -n "$_row" ] || continue
    N=$((N + 1))
    advocate=$(printf '%s' "$_row" | cut -f1)
    claim=$(printf '%s' "$_row" | cut -f2-)
    impact="Surviving dispute raised by the ${advocate} advocate. The conversus ${VERDICT} verdict is operator-overridable content (CON-8), not a hard stop; adjudicate at the gate."
    entry=$(build_entry "CONV-${N}" "$claim" "$PICKED" "$RATIONALE" "$ALTS" "$impact" "$SEVERITY" "decision")
    if [ -z "$ENTRIES" ]; then
      ENTRIES="$entry"
    else
      ENTRIES="${ENTRIES}
${entry}"
    fi
  done
  IFS="$_d_old_ifs"
fi

if [ "$N" -eq 0 ]; then
  # Zero disputes -> single summary entry so a clean PASS still produces an
  # auditable packet entry.
  N=1
  summary="conversus ${VERDICT}: no surviving disputes"
  impact="conversus deliberation produced no surviving disputes. The ${VERDICT} verdict is operator-overridable content (CON-8), not a hard stop; adjudicate at the gate."
  ENTRIES=$(build_entry "CONV-1" "$summary" "$PICKED" "$RATIONALE" "$ALTS" "$impact" "$SEVERITY" "decision")
fi

# Assemble the array doc. ENTRIES is one-or-more newline-separated JSON objects;
# jq -s slurps them into an array, then wrap under .decisions.
JSON=$(printf '%s\n' "$ENTRIES" | jq -s '{decisions: .}')

# --- Step 7: pipe into the writer; propagate its exit code.
printf '%s' "$JSON" | bash "$WRITER" --milestone="$MILESTONE" --artifact="$ARTIFACT" --out="$OUT"
writer_rc=$?

rm -f "$GATE_OUT" 2>/dev/null || true

if [ "$writer_rc" -ne 0 ]; then
  echo "ERROR: write-decisions.sh exited non-zero (rc=${writer_rc})." >&2
  exit "$writer_rc"
fi

echo "DECISIONS(conversus): mapped ${N} dispute(s) at verdict ${VERDICT} into ${OUT}"
