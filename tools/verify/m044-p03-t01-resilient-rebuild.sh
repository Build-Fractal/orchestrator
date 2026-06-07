#!/usr/bin/env bash
# tools/verify/m044-p03-t01-resilient-rebuild.sh
# M044/P03/T01 (FR-3/SC-2): a heading-less entry skips-and-warns; every valid
# entry is still indexed; an INDEXED: N / SKIPPED: M summary is emitted; exit 0.
# Bash 3.2. Emits PASS:/FAIL:; exit 0 on PASS, 1 on FAIL.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

fail=0
BASE="$(mktemp -d)"
trap 'rm -rf "$BASE"' EXIT
mkdir -p "$BASE/knowledge/conventions" "$BASE/.orchestrator"

# Valid headed entry.
cat > "$BASE/knowledge/conventions/MEM800.md" <<'EOF'
---
id: MEM800
scope_tags: "[project]"
category: conventions
confidence: 0.9
created_at: 2026-06-07
last_verified: 2026-06-07
hit_count: 1
---

# MEM800: Valid headed entry

Body.
EOF

# Heading-less entry (frontmatter id but no `# MEM801:` heading line).
cat > "$BASE/knowledge/conventions/MEM801.md" <<'EOF'
---
id: MEM801
scope_tags: "[project]"
category: conventions
confidence: 0.9
created_at: 2026-06-07
last_verified: 2026-06-07
hit_count: 1
---

Body with no heading line at all.
EOF

out="$(bash scripts/knowledge/rebuild-index.sh --root "$BASE" 2>"$BASE/err.txt")"
rc=$?

if [ "$rc" -ne 0 ]; then
  echo "FAIL: rebuild exited non-zero ($rc) on a heading-less entry — should skip, not abort"
  fail=1
fi
# Valid entry indexed.
if ! grep -qE '^MEM800 ' "$BASE/KNOWLEDGE-INDEX.md" 2>/dev/null; then
  echo "FAIL: valid entry MEM800 not indexed"
  fail=1
fi
# Heading-less entry NOT indexed.
if grep -qE '^MEM801 ' "$BASE/KNOWLEDGE-INDEX.md" 2>/dev/null; then
  echo "FAIL: heading-less MEM801 was indexed (expected skip)"
  fail=1
fi
# Per-skip warning on stderr naming the bad entry.
if ! grep -q 'SKIP:.*MEM801' "$BASE/err.txt"; then
  echo "FAIL: no SKIP stderr warning naming MEM801. stderr: $(cat "$BASE/err.txt")"
  fail=1
fi
# Final INDEXED / SKIPPED summary on stdout.
if ! printf '%s\n' "$out" | grep -qE 'INDEXED: [0-9]+ / SKIPPED: 1'; then
  echo "FAIL: missing INDEXED/SKIPPED summary. stdout: $out"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "PASS: resilient rebuild — heading-less entry skipped+warned, valid indexed, summary emitted, exit 0"
  exit 0
fi
exit 1
