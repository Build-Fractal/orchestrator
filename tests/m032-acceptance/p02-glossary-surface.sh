#!/usr/bin/env bash
# tests/m032-acceptance/p02-glossary-surface.sh — SC-7 acceptance.
#
# Verifies FR-15 (glossary scanner+nav) + FR-16 (knowledge adapter) +
# MIT-010 (Quick traversal) end-to-end. Resolves the spec's `p0X-` placeholder
# per #Q-4 to P02.
#
# Bash 3.2 compatible (MEM001). Single-script-file shape per AD-19.
#
# SC-7 has NO skip path: either the FR-15 + FR-16 surfaces work or they don't.

set -eu

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
PROJECT_ROOT="$( cd "$PROJECT_ROOT/.." && pwd )"
cd "$PROJECT_ROOT"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# (a) FR-15 — glossary path-convention surface
[ -f wiki/glossary.md ] || { echo "FAIL: SC-7 wiki/glossary.md missing at orchestrator root"; exit 1; }
HC="$(grep -c '^### ' wiki/glossary.md)"
[ "$HC" -ge 3 ] || { echo "FAIL: SC-7 wiki/glossary.md needs >= 3 ### TERM entries; got $HC"; exit 1; }

# Scanner --include-glossary on emits the glossary path (top:glossary record).
bash scripts/wiki/wiki-scan-sources.sh --root . --include-glossary > "$TMP/sources.txt" 2>/dev/null
grep -q '^top:glossary|wiki/glossary.md' "$TMP/sources.txt" || {
  echo "FAIL: SC-7 scanner did not emit top:glossary|wiki/glossary.md under --include-glossary"
  echo "--- sources.txt head ---" >&2
  head -10 "$TMP/sources.txt" >&2
  exit 1
}

# Nav generator places Glossary as the second orchestrator-managed top-level
# entry (immediately after Constitution) per FR-15. Non-destructive probe:
# inspect the existing wiki/mkdocs.yml (already templated by the nav generator
# on prior runs) and assert the line FOLLOWING the Constitution entry contains
# "Glossary".
MARKER_LINE="$(grep -n '^# >>> M012-P01 nav' wiki/mkdocs.yml | head -1 | cut -d: -f1)"
[ -n "$MARKER_LINE" ] || { echo "FAIL: SC-7 nav marker not found in wiki/mkdocs.yml"; exit 1; }

CONSTITUTION_LINE="$(awk -v start="$MARKER_LINE" 'NR>start && /^  - Constitution:/ {print NR; exit}' wiki/mkdocs.yml)"
[ -n "$CONSTITUTION_LINE" ] || { echo "FAIL: SC-7 Constitution top-level entry not found after nav marker"; exit 1; }

NEXT_LINE="$(awk -v c="$CONSTITUTION_LINE" 'NR==c+1 {print; exit}' wiki/mkdocs.yml)"
echo "$NEXT_LINE" | grep -q 'Glossary' || {
  echo "FAIL: SC-7 entry following Constitution is not Glossary; got: $NEXT_LINE"
  exit 1
}

# (b) FR-16 — knowledge adapter standard profile emits records.
bash scripts/knowledge/lookup-mems.sh --kind=glossary --profile=standard --root . > "$TMP/std.txt" 2>/dev/null
N="$(grep -c '^id: gloss-' "$TMP/std.txt")"
[ "$N" -ge 3 ] || { echo "FAIL: SC-7 standard profile expected >= 3 records got $N"; exit 1; }

# Idempotency: ids stable across re-invocations.
bash scripts/knowledge/lookup-mems.sh --kind=glossary --profile=standard --root . > "$TMP/std2.txt" 2>/dev/null
grep '^id: ' "$TMP/std.txt" | sort > "$TMP/ids1.txt"
grep '^id: ' "$TMP/std2.txt" | sort > "$TMP/ids2.txt"
diff -q "$TMP/ids1.txt" "$TMP/ids2.txt" >/dev/null || { echo "FAIL: SC-7 ids not idempotent across runs"; exit 1; }

# (c) FR-16 / MIT-010 Quick-profile touched-term branches.
# Build a fixture glossary with three known terms.
mkdir -p "$TMP/fixture/wiki"
cat > "$TMP/fixture/wiki/glossary.md" <<'EOF'
# Glossary

### Bar

Bar definition.

### Baz

Baz definition.

### Foo

Foo definition.
EOF

# Quick + task-description hit -- MUST emit exactly one record (gloss-foo).
bash scripts/knowledge/lookup-mems.sh --kind=glossary --profile=quick --task-description 'rename foo' --root "$TMP/fixture" > "$TMP/qhit.txt" 2>/dev/null
N="$(grep -c '^id: gloss-' "$TMP/qhit.txt")"
[ "$N" = "1" ] || { echo "FAIL: SC-7 Quick+task-desc hit expected 1 got $N"; cat "$TMP/qhit.txt" >&2; exit 1; }
grep -q '^id: gloss-foo$' "$TMP/qhit.txt" || { echo "FAIL: SC-7 Quick+task-desc did not emit gloss-foo"; exit 1; }

# MIT-010 safe-default-no-terms — Quick with no hints emits zero records.
# `grep -c` returns 1 when count==0; under `set -eu` that aborts the script
# inside command-substitution. The `|| true` keeps the assignment safe-fallback.
bash scripts/knowledge/lookup-mems.sh --kind=glossary --profile=quick --root "$TMP/fixture" > "$TMP/qsafe.txt" 2>/dev/null
N="$(grep -c '^id: gloss-' "$TMP/qsafe.txt" || true)"
[ "$N" = "0" ] || { echo "FAIL: SC-7 MIT-010 safe-default expected 0 got $N"; exit 1; }

echo "PASS: SC-7 p02-glossary-surface"
exit 0
