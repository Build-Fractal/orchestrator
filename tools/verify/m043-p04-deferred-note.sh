#!/usr/bin/env bash
# m043-p04-deferred-note.sh — asserts a signed deferred-validation note exists
# under evidence/ and validates as the SC-9 deferred path. Bash 3.2; offline.
# A qualifying note has frontmatter deferred_validation: yes AND passes
# validate-evidence.sh. Requires count >= 1.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2

EVIDENCE_DIR="tests/m043-acceptance/live-deploy/evidence"
VALIDATOR="tests/m043-acceptance/live-deploy/validate-evidence.sh"

count=0
for note in "$EVIDENCE_DIR"/*.md; do
  [ -f "$note" ] || continue
  # Read deferred_validation from the frontmatter (between first two `---`).
  dv=$(awk '
    BEGIN { n=0 }
    /^---[[:space:]]*$/ { n++; if (n==2) exit; next }
    n==1 && /^deferred_validation:[[:space:]]*/ {
      sub(/^deferred_validation:[[:space:]]*/, "", $0)
      sub(/[[:space:]]*#.*$/, "", $0)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      gsub(/^"|"$/, "", $0)
      print; exit
    }
  ' "$note")
  if [ "$dv" = "yes" ] && bash "$VALIDATOR" "$note" >/dev/null 2>&1; then
    count=$((count + 1))
  fi
done

if [ "$count" -ge 1 ]; then
  echo "m043-p04-deferred-note pass=1 fail=0 (signed deferred notes: $count)"
  exit 0
fi

echo "m043-p04-deferred-note pass=0 fail=1 (no qualifying signed deferred note found in $EVIDENCE_DIR)"
exit 1
