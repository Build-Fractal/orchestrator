#!/usr/bin/env bash
# tools/verify/m036-p02-binary-preservation.sh -- M036 P02 T02.
# Drives the extract driver against the fixture manifest in a temp
# workspace and asserts that each binary appears byte-identical under
# _originals/<source>/<filename>. Host-tooling-aware SKIP if the
# Tier 1 leg fails because pdftotext/pandoc absent (binary preservation
# is independent of Tier 1 dispatch, but the driver bails on adapter
# failure -- so we treat host-tool absence as SKIP for this verifier).
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p02-bp.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
DRV="$ROOT/scripts/knowledge/extract-reference.sh"
MANIFEST="$ROOT/tests/fixtures/m036/extract-manifest.yaml"

# Host-tooling probe: this verifier runs the driver end-to-end; bail
# clean if Tier 1 host tools absent.
if ! command -v pdftotext >/dev/null 2>&1; then
  echo "SKIP: pdftotext-absent"
  exit 0
fi
if ! command -v pandoc >/dev/null 2>&1; then
  echo "SKIP: pandoc-absent"
  exit 0
fi

# Run driver in temp workspace.
ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" \
  --manifest "$MANIFEST" \
  --reference-root "$WORK/knowledge/reference" \
  --originals-root "$WORK/_originals" \
  >/dev/null 2>"$WORK/stderr.txt" || {
    echo "FAIL: driver exited non-zero"
    cat "$WORK/stderr.txt" >&2
    exit 1
  }

# Three originals expected -- under <source>/<filename>.
fail=0
checkbyte() {
  local src="$1"
  local sid="$2"
  local base="$3"
  local dest="$WORK/_originals/$sid/$base"
  if [ ! -f "$dest" ]; then
    echo "FAIL: missing $dest"
    fail=$((fail + 1))
    return
  fi
  if cmp -s "$src" "$dest"; then
    echo "PASS: byte-identical $sid/$base"
  else
    echo "FAIL: byte-differ $sid/$base"
    fail=$((fail + 1))
  fi
}
checkbyte "$ROOT/tests/fixtures/m036/sample.pdf"  "cms"               "sample.pdf"
checkbyte "$ROOT/tests/fixtures/m036/sample.docx" "sme-pbj-circle"    "sample.docx"
checkbyte "$ROOT/tests/fixtures/m036/sample.md"   "internal-glossary" "sample.md"
echo "SUMMARY: m036-p02-binary-preservation.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
