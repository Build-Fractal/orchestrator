#!/usr/bin/env bash
# scripts/verify/m018-p01-lint-clean.sh — phase-truth verifier:
# "compression-grammar-lint.sh exits 0 and emits at least one PASS line".
#
# AD-19 single-script-file shape, bash 3.2, MEM001 PASS/FAIL, exit 0/1.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINT="$SCRIPT_DIR/compression-grammar-lint.sh"

if [ ! -f "$LINT" ]; then
  printf 'FAIL: lint script missing: %s\n' "$LINT" >&2
  exit 1
fi

OUT_FILE=$(mktemp)
trap 'rm -f "$OUT_FILE"' EXIT INT TERM

if ! bash "$LINT" > "$OUT_FILE" 2>/dev/null; then
  printf 'FAIL: compression-grammar-lint exited non-zero\n' >&2
  exit 1
fi

PASS_COUNT=$(grep -c '^PASS:' "$OUT_FILE" || true)
PASS_COUNT=${PASS_COUNT:-0}

if [ "$PASS_COUNT" -lt 1 ]; then
  printf 'FAIL: compression-grammar-lint emitted zero PASS lines\n' >&2
  exit 1
fi

printf 'PASS: compression-grammar-lint clean (%d PASS lines)\n' "$PASS_COUNT"
exit 0
