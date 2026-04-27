#!/usr/bin/env bash
# scripts/verify/m018-p00-summary-complete.sh -- M018/P00/T03 summary
# completeness gate.
#
# Asserts that .orchestrator/milestones/M018/phases/P00/P00-SUMMARY.md
# has been authored to the T03 plan's structural contract:
#   1. Contains all six required section headings:
#      Closure summary, Parity result, Calibrated threshold, Spec amendment,
#      Risk-mitigation traceability, Followups for downstream phases.
#   2. Contains the literal string "parity" (case-insensitive permitted).
#   3. Contains a numeric percentage matching the calibrated threshold from
#      the SC-9 amendment (extracted from the spec block directly so the two
#      artifacts cannot drift).
#   4. File is >= 40 lines.
#
# Single-script-file shape (AD-19). Bash 3.2 / POSIX-friendly. Read-only.
# Exits 0 on pass, 1 with diagnostic on fail.
#
# Usage:
#   m018-p00-summary-complete.sh [--summary <path>] [--spec <path>]

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SUMMARY="$REPO_ROOT/.orchestrator/milestones/M018/phases/P00/P00-SUMMARY.md"
SPEC="$REPO_ROOT/specs/030-context-compression-layer/spec.md"

while [ $# -gt 0 ]; do
  case "$1" in
    --summary) SUMMARY="${2:-}"; shift 2 ;;
    --spec)    SPEC="${2:-}";    shift 2 ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) shift ;;
  esac
done

if [ ! -r "$SUMMARY" ]; then
  printf 'FAIL: m018-p00-summary-complete summary-not-readable path=%s\n' "$SUMMARY" >&2
  exit 1
fi
if [ ! -r "$SPEC" ]; then
  printf 'FAIL: m018-p00-summary-complete spec-not-readable path=%s\n' "$SPEC" >&2
  exit 1
fi

MISSING=""
for h in "Closure summary" "Parity result" "Calibrated threshold" "Spec amendment" "Risk-mitigation traceability" "Followups for downstream phases"; do
  if ! grep -Fq "## $h" "$SUMMARY"; then
    if [ -z "$MISSING" ]; then
      MISSING="$h"
    else
      MISSING="$MISSING; $h"
    fi
  fi
done

if [ -n "$MISSING" ]; then
  printf 'FAIL: m018-p00-summary-complete missing-sections=%s\n' "$MISSING" >&2
  exit 1
fi

# Assertion 2: literal "parity" must appear (case-insensitive).
if ! grep -iq 'parity' "$SUMMARY"; then
  printf 'FAIL: m018-p00-summary-complete missing-parity-literal\n' >&2
  exit 1
fi

# Assertion 3: numeric percentage matching SC-9 calibrated threshold.
SC9_TMP="$(mktemp)"
trap 'rm -f "$SC9_TMP"' EXIT INT TERM
awk '
  /^- \*\*SC-9\*\*/ { inblk = 1; print; next }
  inblk == 1 && /^- \*\*SC-/ { inblk = 0 }
  inblk == 1 && /^## / { inblk = 0 }
  inblk == 1 { print }
' "$SPEC" > "$SC9_TMP"

PCT="$(grep -Eo '[0-9]+\.?[0-9]*%' "$SC9_TMP" | head -n 1)"
if [ -z "$PCT" ]; then
  printf 'FAIL: m018-p00-summary-complete sc9-threshold-not-extractable\n' >&2
  exit 1
fi

if ! grep -Fq "$PCT" "$SUMMARY"; then
  printf 'FAIL: m018-p00-summary-complete summary-missing-threshold expected=%s\n' "$PCT" >&2
  exit 1
fi

# Assertion 4: file is >= 40 lines.
LINES="$(wc -l < "$SUMMARY" | tr -d ' ')"
if [ "$LINES" -lt 40 ]; then
  printf 'FAIL: m018-p00-summary-complete file-too-short lines=%d (need >=40)\n' "$LINES" >&2
  exit 1
fi

printf 'PASS: P00-SUMMARY.md complete (six required sections present, parity cited, threshold %s cited, %d lines)\n' "$PCT" "$LINES"
exit 0
