#!/usr/bin/env bash
# scripts/verify/m018-p00-sc9-calibrated.sh -- M018/P00/T03 SC-9 calibration gate.
#
# Asserts that specs/030-context-compression-layer/spec.md SC-9 has been
# amended with the empirically-grounded threshold from the P00 probe:
#   1. The SC-9 block contains a numeric threshold (regex [0-9]+\.?[0-9]*%)
#      AND the literal string "P00 calibration" -- proves the amendment
#      landed and is sourced from the probe.
#   2. The placeholder string "≥ 25%" does NOT appear inside the SC-9 block
#      -- proves the original placeholder was replaced, not annotated.
#
# Single-script-file shape (AD-19). Bash 3.2 / POSIX-friendly. Read-only.
# Exits 0 on pass, 1 with diagnostic on fail.
#
# Usage:
#   m018-p00-sc9-calibrated.sh [--spec <path>]

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SPEC="$REPO_ROOT/specs/030-context-compression-layer/spec.md"

while [ $# -gt 0 ]; do
  case "$1" in
    --spec) SPEC="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) shift ;;
  esac
done

if [ ! -r "$SPEC" ]; then
  printf 'FAIL: m018-p00-sc9-calibrated spec-not-readable path=%s\n' "$SPEC" >&2
  exit 1
fi

# Extract just the SC-9 block: everything from the line that starts with
# "- **SC-9**" up to (but not including) the next top-level list item or
# the next section heading.
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT INT TERM

awk '
  /^- \*\*SC-9\*\*/ { inblk = 1; print; next }
  inblk == 1 && /^- \*\*SC-/ { inblk = 0 }
  inblk == 1 && /^## / { inblk = 0 }
  inblk == 1 { print }
' "$SPEC" > "$TMP"

if [ ! -s "$TMP" ]; then
  printf 'FAIL: m018-p00-sc9-calibrated SC-9-block-not-found spec=%s\n' "$SPEC" >&2
  exit 1
fi

# Assertion 1: numeric threshold like "34.7%" or "25%" must appear in the block.
if ! grep -Eq '[0-9]+\.?[0-9]*%' "$TMP"; then
  printf 'FAIL: m018-p00-sc9-calibrated no-numeric-threshold-in-SC-9\n' >&2
  cat "$TMP" >&2
  exit 1
fi

# Assertion 2: "P00 calibration" literal must appear -> proves probe-sourced.
if ! grep -Fq 'P00 calibration' "$TMP"; then
  printf 'FAIL: m018-p00-sc9-calibrated missing-P00-calibration-literal\n' >&2
  cat "$TMP" >&2
  exit 1
fi

# Assertion 3: the placeholder "≥ 25%" must be ABSENT from the SC-9 block.
if grep -Fq '≥ 25%' "$TMP"; then
  printf 'FAIL: m018-p00-sc9-calibrated placeholder-still-present (>=25%%) -- amendment incomplete\n' >&2
  cat "$TMP" >&2
  exit 1
fi

# Pull the first numeric threshold for the PASS message.
PCT="$(grep -Eo '[0-9]+\.?[0-9]*%' "$TMP" | head -n 1)"

printf 'PASS: SC-9 calibrated to %s via P00 probe (placeholder >=25%% removed)\n' "$PCT"
exit 0
