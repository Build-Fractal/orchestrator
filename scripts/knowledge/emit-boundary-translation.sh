#!/usr/bin/env bash
# scripts/knowledge/emit-boundary-translation.sh — M034 P02 T05 (FR-13, SC-8).
#
# Producer for the `type: boundary_translation` decision-packet entry — the
# lakeledger M066/P04-class post-deploy-drift guard. A task that declares
# `touches_persistence: true` invokes this DELIBERATELY (D-P02-5 / #Q-6: the
# producer is explicit-only; v1 adds NO heuristic auto-detection) to record the
# four bridge fields:
#   source_vocab      — the plan-side vocabulary (e.g. surface_acres)
#   target_vocab      — the target/persisted vocabulary (e.g. surface_area_acres)
#   transform_site    — a file:line string where the bridge is applied
#   verify_mechanism  — how the bridge is verified (e.g. real-DB column check)
#
# It builds a `{"decisions":[...]}` document with `jq -n --arg` (lossless,
# RISK-1: field bodies never pass through eval / unquoted re-expansion) and
# pipes it to write-decisions.sh, the closed P01 writer. write-decisions.sh
# emits only the eight FR-1 fields per block and IGNORES extra JSON keys, so the
# four bridge values are ALSO encoded verbatim into the FR-1 body fields
# (summary / picked_value / rationale / concrete_impact) to survive emission and
# stay grep-able in the packet (SC-8 recoverability).
#
# Do NOT modify write-decisions.sh — all boundary_translation specifics live in
# this producer's text encoding.
#
# Bash 3.2 / POSIX-sh single file (CON-1). jq required (a write-decisions
# dependency already). No declare -A, no ${var,,}, no process substitution.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
WRITER="$SCRIPT_DIR/write-decisions.sh"

# --- jq-required guard. ------------------------------------------------------
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: emit-boundary-translation.sh requires jq (entry construction). Install jq and retry." >&2
  exit 1
fi

if [ ! -f "$WRITER" ]; then
  echo "ERROR: emit-boundary-translation.sh: write-decisions.sh not found at $WRITER." >&2
  exit 1
fi

# --- Arg parse (--field=value). ----------------------------------------------
MILESTONE=""
ARTIFACT=""
OUT=""
ID="BT-1"
SOURCE_VOCAB=""
TARGET_VOCAB=""
TRANSFORM_SITE=""
VERIFY_MECHANISM=""
SEVERITY="block"

for arg in "$@"; do
  case "$arg" in
    --milestone=*)        MILESTONE="${arg#*=}" ;;
    --artifact=*)         ARTIFACT="${arg#*=}" ;;
    --out=*)              OUT="${arg#*=}" ;;
    --id=*)               ID="${arg#*=}" ;;
    --source-vocab=*)     SOURCE_VOCAB="${arg#*=}" ;;
    --target-vocab=*)     TARGET_VOCAB="${arg#*=}" ;;
    --transform-site=*)   TRANSFORM_SITE="${arg#*=}" ;;
    --verify-mechanism=*) VERIFY_MECHANISM="${arg#*=}" ;;
    --severity=*)         SEVERITY="${arg#*=}" ;;
    *)
      echo "ERROR: emit-boundary-translation: unrecognized argument '$arg'. Use --milestone= / --artifact= / --out= / --id= / --source-vocab= / --target-vocab= / --transform-site= / --verify-mechanism= / --severity=." >&2
      exit 1
      ;;
  esac
done

# --- Required-flag guards (the four bridge fields are mandatory: the entry is
# worthless without the bridge it records). -----------------------------------
if [ -z "$MILESTONE" ]; then
  echo "ERROR: emit-boundary-translation: --milestone=<M> is required." >&2
  exit 1
fi
if [ -z "$ARTIFACT" ]; then
  echo "ERROR: emit-boundary-translation: --artifact=<path> is required." >&2
  exit 1
fi
if [ -z "$OUT" ]; then
  echo "ERROR: emit-boundary-translation: --out=<packet-path> is required." >&2
  exit 1
fi
if [ -z "$SOURCE_VOCAB" ]; then
  echo "ERROR: emit-boundary-translation: --source-vocab= is required (bridge field)." >&2
  exit 1
fi
if [ -z "$TARGET_VOCAB" ]; then
  echo "ERROR: emit-boundary-translation: --target-vocab= is required (bridge field)." >&2
  exit 1
fi
if [ -z "$TRANSFORM_SITE" ]; then
  echo "ERROR: emit-boundary-translation: --transform-site= is required (bridge field)." >&2
  exit 1
fi
if [ -z "$VERIFY_MECHANISM" ]; then
  echo "ERROR: emit-boundary-translation: --verify-mechanism= is required (bridge field)." >&2
  exit 1
fi

# --- Build the entry JSON (jq -n --arg — lossless, RISK-1). -------------------
# The four bridge field VALUES are encoded verbatim into summary / picked_value
# / rationale / concrete_impact so they survive write-decisions.sh's 8-field
# emission and stay grep-able in the packet (SC-8).
doc="$(jq -n \
  --arg id "$ID" \
  --arg sv "$SOURCE_VOCAB" --arg tv "$TARGET_VOCAB" \
  --arg ts "$TRANSFORM_SITE" --arg vm "$VERIFY_MECHANISM" \
  --arg sev "$SEVERITY" '
  {decisions: [ {
    id: $id,
    summary: ("Boundary translation: " + $sv + " -> " + $tv),
    picked_value: ($sv + " -> " + $tv + " @ " + $ts),
    rationale: ("Persistence/protocol/format boundary: plan vocabulary \"" + $sv + "\" maps to target vocabulary \"" + $tv + "\". Verification: " + $vm + "."),
    alternatives_considered: "n/a (boundary translation is a recorded bridge, not a chosen option)",
    concrete_impact: ("If the bridge is wrong, the first real run throws at " + $ts + " (e.g. no-such-column). Verify via: " + $vm + "."),
    severity: $sev,
    type: "boundary_translation",
    source_vocab: $sv,
    target_vocab: $tv,
    transform_site: $ts,
    verify_mechanism: $vm
  } ] }')"

printf '%s' "$doc" | bash "$WRITER" --milestone="$MILESTONE" --artifact="$ARTIFACT" --out="$OUT"
