#!/usr/bin/env bash
# tools/verify/m044-p01-t02-provenance-always.sh
# M044/P01/T02 (FR-5/DQ-4/#Q-4): the provenance header is ALWAYS present (even
# on a healthy source=index) and pins provenance_version: 1 with a frozen field
# order. Bash 3.2. Emits PASS:/FAIL:; exit 0 on PASS, 1 on FAIL.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

fail=0
LIB="scripts/dispatch/lib/knowledge-provenance.sh"
# shellcheck source=/dev/null
. "$LIB"

# --- Header on a healthy source=index carries version + frozen field order ---
hdr_index="$(kp_emit_header index 0 5)"
expected_index="$(printf 'knowledge_provenance:\n  provenance_version: 1\n  source: index\n  index_age: 0\n  entries_considered: 5')"
if [ "$hdr_index" != "$expected_index" ]; then
  echo "FAIL: source=index header not byte-stable. Got:"
  printf '%s\n' "$hdr_index"
  fail=1
fi

# --- Header on grep-fallback also carries version 1 ---
hdr_fb="$(kp_emit_header grep-fallback none 18)"
if ! printf '%s' "$hdr_fb" | grep -q 'provenance_version: 1'; then
  echo "FAIL: grep-fallback header missing provenance_version: 1"
  fail=1
fi
if ! printf '%s' "$hdr_fb" | grep -q 'source: grep-fallback'; then
  echo "FAIL: grep-fallback header missing source"
  fail=1
fi

# --- Integration: build-context.sh emits the header unconditionally ---
BC="scripts/dispatch/build-context.sh"
if ! grep -q 'kp_emit_header' "$BC"; then
  echo "FAIL: build-context.sh does not call kp_emit_header"
  fail=1
fi

# --- Live payload contains the header + version regardless of index state ---
OUT="$(mktemp)"
bash "$BC" --task-plan "$BC" --profile quick --out "$OUT" >/dev/null 2>&1 || true
if ! grep -q '^  provenance_version: 1' "$OUT"; then
  echo "FAIL: live payload missing provenance_version: 1"
  fail=1
fi
rm -f "$OUT"

if [ "$fail" -eq 0 ]; then
  echo "PASS: provenance header always present, version-pinned, byte-stable"
  exit 0
fi
exit 1
