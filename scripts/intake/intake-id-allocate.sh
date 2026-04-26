#!/usr/bin/env bash
# scripts/intake/intake-id-allocate.sh
# M024/P01/T02 — Allocate the intake_id for an `evaluate` invocation.
#
# Two modes:
#   --spec-path <path>  Reuse the spec slug as the intake_id (FR-11).
#   --input <string>    Counter-allocate <NNN>-<short-slug> (AD-2).
#
# Emits one line `intake_id=<value>` to stdout. Exit 0 on success, 2 on usage
# error. Writes nothing — directory creation is the caller's responsibility.

set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INTAKE_DIR="$ROOT/.orchestrator/intake"

usage() {
  echo "usage: intake-id-allocate.sh --spec-path <path> | --input <string>" >&2
  exit 2
}

MODE=""
SPEC_PATH=""
INPUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --spec-path) MODE="spec"; SPEC_PATH="$2"; shift 2 ;;
    --input)     MODE="input"; INPUT="$2"; shift 2 ;;
    --intake-dir) INTAKE_DIR="$2"; shift 2 ;;  # test-only override
    -h|--help)   usage ;;
    *)           usage ;;
  esac
done

if [ -z "$MODE" ]; then
  usage
fi

# Mode 1: spec-path → reuse spec slug.
if [ "$MODE" = "spec" ]; then
  if [ -z "$SPEC_PATH" ] || [ ! -f "$SPEC_PATH" ]; then
    echo "intake-id-allocate.sh: spec path '$SPEC_PATH' not found" >&2
    exit 2
  fi
  # specs/028-universal-intake-routing/spec.md → 028-universal-intake-routing
  slug="$(basename "$(dirname "$SPEC_PATH")")"
  if [ -z "$slug" ] || [ "$slug" = "." ] || [ "$slug" = "/" ]; then
    echo "intake-id-allocate.sh: cannot extract slug from '$SPEC_PATH'" >&2
    exit 2
  fi
  echo "intake_id=$slug"
  exit 0
fi

# Mode 2: input → counter + short-slug.
# (a) Counter: max(existing NNN) + 1, zero-padded to 3 digits.
next=1
if [ -d "$INTAKE_DIR" ]; then
  for entry in "$INTAKE_DIR"/*; do
    [ -d "$entry" ] || continue
    name="$(basename "$entry")"
    # Match leading 3 digits.
    case "$name" in
      [0-9][0-9][0-9]-*)
        n=$(echo "$name" | cut -c1-3)
        # Strip leading zeros for arithmetic without octal interpretation.
        n=$(echo "$n" | sed 's/^0*//')
        [ -z "$n" ] && n=0
        if [ "$n" -ge "$next" ]; then
          next=$((n + 1))
        fi
        ;;
    esac
  done
fi
nnn=$(printf '%03d' "$next")

# (b) Short-slug from first 1–4 words: lowercase, alnum + hyphens, ≤24 chars.
short="$(echo "$INPUT" \
  | tr '[:upper:]' '[:lower:]' \
  | tr -c 'a-z0-9 \n' ' ' \
  | tr -s ' ' \
  | cut -d ' ' -f 1-4 \
  | tr ' ' '-' \
  | sed 's/^-//; s/-$//')"

# Truncate to 24 chars, trim trailing hyphen.
short=$(echo "$short" | cut -c1-24 | sed 's/-$//')
if [ -z "$short" ]; then
  short="intake"
fi

echo "intake_id=${nnn}-${short}"
exit 0
