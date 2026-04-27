#!/usr/bin/env bash
# scripts/verify/m018-p01-grammar-shape.sh — phase-truth verifier:
# "compression grammar contract has the expected shape".
#
# Wraps the public lint and adds two extras the lint does not enforce:
#   - frontmatter `version` field matches semver shape \d+\.\d+\.\d+
#   - marker grammar section names tier1, tier2, tier3 (filter has no
#     in-band marker by design; see references/compression-grammar.md).
#
# AD-19 single-script-file shape, bash 3.2, MEM001 PASS/FAIL, exit 0/1.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GRAMMAR="$REPO_ROOT/references/compression-grammar.md"
LINT="$SCRIPT_DIR/compression-grammar-lint.sh"

if [ ! -f "$GRAMMAR" ]; then
  printf 'FAIL: grammar file missing: %s\n' "$GRAMMAR" >&2
  exit 1
fi

if [ ! -x "$LINT" ]; then
  if [ ! -f "$LINT" ]; then
    printf 'FAIL: lint script missing: %s\n' "$LINT" >&2
    exit 1
  fi
fi

# Run lint; suppress its stdout (only its exit-code is the proof here).
if ! bash "$LINT" "$GRAMMAR" >/dev/null; then
  printf 'FAIL: compression-grammar-lint reported issues; run %s\n' "$LINT" >&2
  exit 1
fi
printf 'PASS: compression-grammar-lint clean\n'

# Extract version field from frontmatter (line up to second '---').
VLINE=$(awk '
  BEGIN { state = 0 }
  /^---$/ { state++; if (state == 2) exit; next }
  state == 1 && /^version:/ { print; exit }
' "$GRAMMAR")

# Strip key, quotes, whitespace.
VVAL=$(printf '%s' "$VLINE" | sed -e 's/^version:[[:space:]]*//' -e 's/^"//' -e 's/"$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

if printf '%s' "$VVAL" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  printf 'PASS: version semver shape (%s)\n' "$VVAL"
else
  printf 'FAIL: version not semver: "%s"\n' "$VVAL" >&2
  exit 1
fi

# Marker grammar must name tier1, tier2, tier3 (filter excluded by design).
MG_FILE=$(mktemp)
trap 'rm -f "$MG_FILE"' EXIT INT TERM
awk '
  /^## Marker Grammar/ { capture = 1; next }
  capture && /^## / { capture = 0 }
  capture { print }
' "$GRAMMAR" > "$MG_FILE"

MISSING=""
for tname in tier1 tier2 tier3; do
  if ! grep -q "compressed:${tname}" "$MG_FILE"; then
    MISSING="$MISSING $tname"
  fi
done

if [ -n "$MISSING" ]; then
  printf 'FAIL: marker grammar missing tier marker(s):%s\n' "$MISSING" >&2
  exit 1
fi
printf 'PASS: marker grammar names tier1, tier2, tier3 (filter omitted by design)\n'

exit 0
