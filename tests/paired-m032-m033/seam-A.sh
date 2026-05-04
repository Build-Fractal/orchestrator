#!/usr/bin/env bash
# tests/paired-m032-m033/seam-A.sh — paired-launch shared invariant per #Q-B Seam-A.
#
# project_assets: schema shape M033 consumes for its 7-new-commands +
# 6-new-scripts shipping. Both M032 (path owner) and M033 (downstream consumer)
# treat this as a shared contract: the manifest carries a project_assets:
# section, the reader emits stable tab-separated tuples, and the wiki/ entry
# is present (P02/T01 deliverable).
#
# Bash 3.2 compatible (MEM001).

set -eu

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
PROJECT_ROOT="$( cd "$PROJECT_ROOT/.." && pwd )"
cd "$PROJECT_ROOT"

# (a) Manifest carries the project_assets: section
[ -f packaging/bundle/manifest.yml ] || { echo "FAIL: Seam-A manifest missing"; exit 1; }
grep -q '^project_assets:$' packaging/bundle/manifest.yml || { echo "FAIL: Seam-A project_assets section missing"; exit 1; }

# (b) Reader emits tuples
TUPLES="$(bash scripts/lifecycle/read-project-assets.sh packaging/bundle/ 2>/dev/null || true)"
[ -n "$TUPLES" ] || { echo "FAIL: Seam-A reader emitted zero tuples"; exit 1; }

# (c) At least 5 tuples (4 P01 runtime dirs + 1 P02 wiki)
TUPLE_COUNT="$(printf '%s\n' "$TUPLES" | wc -l | tr -d ' ')"
[ "$TUPLE_COUNT" -ge 5 ] || { echo "FAIL: Seam-A expected >= 5 tuples (4 P01 + 1 P02 wiki) got $TUPLE_COUNT"; exit 1; }

# (d) wiki/ entry present (P02/T01 deliverable)
printf '%s\n' "$TUPLES" | grep -q 'source=wiki/' || { echo "FAIL: Seam-A missing source=wiki/ tuple"; exit 1; }

# (e) Schema shape stable across all tuples — each carries source=, target=, mode= fields.
# M033 will ship 7 new commands + 6 new scripts on top of this seam; the schema must remain stable.
TUPLE_LOG="$(mktemp)"
trap 'rm -f "$TUPLE_LOG"' EXIT
printf '%s\n' "$TUPLES" > "$TUPLE_LOG"
while IFS= read -r tuple; do
  [ -z "$tuple" ] && continue
  printf '%s' "$tuple" | grep -q '^source=' || { echo "FAIL: Seam-A tuple missing source: '$tuple'"; exit 1; }
  printf '%s' "$tuple" | grep -q $'\ttarget=' || { echo "FAIL: Seam-A tuple missing target: '$tuple'"; exit 1; }
  printf '%s' "$tuple" | grep -q $'\tmode=' || { echo "FAIL: Seam-A tuple missing mode: '$tuple'"; exit 1; }
done < "$TUPLE_LOG"

echo "PASS: Seam-A project_assets shape (M033 <-> M032)"
exit 0
