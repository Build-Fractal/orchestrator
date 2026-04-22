#!/usr/bin/env bash
# scripts/verify/m013-p01-rebuild-index-additive.sh — M013/P01/T04 gate.
#
# Asserts the additive-emit contract for scripts/knowledge/rebuild-index.sh:
#   1. rebuild-index.sh exits 0.
#   2. The pre-existing pipe-table format is preserved for MEM* entries
#      (MEM* rows match `^MEM[0-9]+ | .+ | .+ | .+ | .+ | verified: .+ | hits: .+`).
#   3. `## Spec Chunks` section is present in KNOWLEDGE-INDEX.md.
#   4. The Spec Chunks section contains at least one flat-format row
#      (matches `^SPEC-[A-Z]+-[0-9]+ \| .+ \|`).
#   5. Every SPEC-* chunk id in knowledge/spec/**/SPEC-*.md (as `id:`
#      frontmatter) appears as a row inside the Spec Chunks section.
#   6. Re-running rebuild-index.sh produces a byte-identical KNOWLEDGE-INDEX.md
#      (idempotent — not additive-duplicated).
#
# Single-script-file shape (AD-19). Bash 3.2 compatible (MEM001).
# Additive-only per FR-9 + D014 Knowledge-Layer Boundary.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REBUILDER="${REPO_ROOT}/scripts/knowledge/rebuild-index.sh"
INDEX="${REPO_ROOT}/KNOWLEDGE-INDEX.md"

fail_count=0
assert_ok() {
  if [ "$1" -eq 0 ]; then
    echo "PASS: $2"
  else
    echo "FAIL: $2"
    fail_count=$((fail_count + 1))
  fi
}

# 0. Rebuilder present
[ -f "$REBUILDER" ]
assert_ok $? "rebuild-index.sh present"

# 1. Run the rebuilder
bash "$REBUILDER" >/dev/null 2>&1
rc=$?
assert_ok "$rc" "rebuild-index.sh exits 0"

# 2. Pre-existing pipe-table MEM* rows preserved
grep -qE '^MEM[0-9]+ \| .+ \| .+ \| .+ \| .+ \| verified:.+ \| hits:.+ \| ' "$INDEX"
assert_ok $? "pre-existing MEM* pipe-table rows preserved"

# 3. ## Spec Chunks section present
grep -q '^## Spec Chunks' "$INDEX"
assert_ok $? "KNOWLEDGE-INDEX.md has ## Spec Chunks section"

# 4. At least one flat-format row in the Spec Chunks section
awk '
  /^## Spec Chunks/ { in_sec=1; next }
  /^## / && in_sec { exit }
  in_sec && $0 ~ /^SPEC-[A-Z]+-[0-9]+ \| .+ \|/ { found=1; exit }
  END { exit (found ? 0 : 1) }
' "$INDEX"
assert_ok $? "Spec Chunks section has at least one flat-format row"

# 5. Every SPEC-* chunk id appears as a row in the Spec Chunks section
missing=""
for f in "${REPO_ROOT}"/knowledge/spec/*/SPEC-*.md; do
  [ -f "$f" ] || continue
  case "$f" in
    */archive/*) continue ;;
  esac
  chunk_id="$(sed -n '/^---$/,/^---$/p' "$f" | { grep "^id:" || true; } | head -1 | sed 's/^id:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//' | sed 's/[[:space:]]*$//')"
  [ -z "$chunk_id" ] && continue
  awk -v cid="$chunk_id" '
    /^## Spec Chunks/ { in_sec=1; next }
    /^## / && in_sec { exit }
    in_sec && $0 ~ "^"cid" \\|" { found=1; exit }
    END { exit (found ? 0 : 1) }
  ' "$INDEX"
  if [ "$?" -ne 0 ]; then
    if [ -z "$missing" ]; then
      missing="$chunk_id"
    else
      missing="${missing},${chunk_id}"
    fi
  fi
done
if [ -z "$missing" ]; then
  echo "PASS: every SPEC-* chunk id appears in Spec Chunks section"
else
  echo "FAIL: missing chunk ids in Spec Chunks section: ${missing}"
  fail_count=$((fail_count + 1))
fi

# 6. Idempotency — re-running produces byte-identical output.
BASELINE="${INDEX}.baseline.$$"
cp "$INDEX" "$BASELINE"
bash "$REBUILDER" >/dev/null 2>&1
diff -q "$INDEX" "$BASELINE" >/dev/null
assert_ok $? "rebuild-index.sh is idempotent (byte-identical re-run)"
rm -f "$BASELINE"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m013-p01-rebuild-index-additive.sh"
  exit 0
fi
echo "FAIL: m013-p01-rebuild-index-additive.sh ($fail_count failures)"
exit 1
