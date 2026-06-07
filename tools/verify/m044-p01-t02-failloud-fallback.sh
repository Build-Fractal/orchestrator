#!/usr/bin/env bash
# tools/verify/m044-p01-t02-failloud-fallback.sh
# M044/P01/T02 (FR-5/SC-5): empty/missing/stale index over a populated raw
# corpus -> deterministic grep fallback + a loud WARNING + a provenance header;
# build-context.sh wires the lib and always stamps the header.
# Lib-level fixture tests + integration-wiring + live-payload assertion.
# Bash 3.2. Emits PASS:/FAIL:; exit 0 on PASS, 1 on FAIL.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

fail=0
LIB="scripts/dispatch/lib/knowledge-provenance.sh"

if [ ! -f "$LIB" ]; then
  echo "FAIL: $LIB not found"
  exit 1
fi
# shellcheck source=/dev/null
. "$LIB"

# --- Build an ephemeral fixture corpus ---
FX="$(mktemp -d)"
trap 'rm -rf "$FX"' EXIT
mkdir -p "$FX/knowledge/patterns"
cat > "$FX/knowledge/patterns/MEM900.md" <<'EOF'
---
id: MEM900
scope_tags: "[project]"
category: patterns
confidence: 0.90
created_at: 2026-06-07
---

# MEM900: Fixture entry for the index-free grep fallback

Deterministic body for the M044 fail-loud fallback test.
EOF

# 1. missing index -> state missing
st_missing="$(kp_index_state "$FX/KNOWLEDGE-INDEX.md" "$FX/knowledge")"
if [ "$st_missing" != "missing" ]; then
  echo "FAIL: kp_index_state on absent index = '$st_missing' (expected missing)"
  fail=1
fi

# 2. empty index (header only, no data rows) -> state empty
printf '# Knowledge Index\n' > "$FX/KNOWLEDGE-INDEX.md"
st_empty="$(kp_index_state "$FX/KNOWLEDGE-INDEX.md" "$FX/knowledge")"
if [ "$st_empty" != "empty" ]; then
  echo "FAIL: kp_index_state on header-only index = '$st_empty' (expected empty)"
  fail=1
fi

# 3. grep fallback resolves the raw entry within budget
body="$(kp_grep_fallback "$FX/knowledge" "" 2000)"
if ! printf '%s' "$body" | grep -q 'MEM900'; then
  echo "FAIL: grep fallback did not resolve MEM900 from the raw corpus"
  fail=1
fi

# 4. degraded-empty corpus -> empty body (caller flags 'degraded')
EMPTY_FX="$(mktemp -d)"
mkdir -p "$EMPTY_FX/knowledge"
empty_body="$(kp_grep_fallback "$EMPTY_FX/knowledge" "" 2000)"
if [ -n "$empty_body" ]; then
  echo "FAIL: grep fallback over an empty corpus returned non-empty body"
  fail=1
fi
rm -rf "$EMPTY_FX"

# 5. integration: build-context.sh sources the lib + branches on index state
BC="scripts/dispatch/build-context.sh"
if ! grep -q 'knowledge-provenance.sh' "$BC"; then
  echo "FAIL: build-context.sh does not source knowledge-provenance.sh"
  fail=1
fi
if ! grep -q 'kp_grep_fallback' "$BC"; then
  echo "FAIL: build-context.sh does not call kp_grep_fallback"
  fail=1
fi

# 6. live payload always carries the provenance header (state-robust)
OUT="$(mktemp)"
bash "$BC" --task-plan "$BC" --profile quick --out "$OUT" >/dev/null 2>&1 || true
if ! grep -q '^knowledge_provenance:' "$OUT"; then
  echo "FAIL: live build-context.sh payload missing knowledge_provenance header"
  fail=1
fi
rm -f "$OUT"

if [ "$fail" -eq 0 ]; then
  echo "PASS: fail-loud index-state detection + grep fallback + provenance wiring"
  exit 0
fi
exit 1
