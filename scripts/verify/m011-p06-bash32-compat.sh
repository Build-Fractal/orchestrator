#!/usr/bin/env bash
# scripts/verify/m011-p06-bash32-compat.sh
# Bash 3.2 compatibility scan for every P06 verify script.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"

FILES="
scripts/verify/m011-p06-ingest-doc-structure.sh
scripts/verify/m011-p06-ingest-doc-conventions.sh
scripts/verify/m011-p06-ingest-doc-reingest-contract.sh
scripts/verify/m011-p06-evaluate-doc-mentions-ingest.sh
scripts/verify/m011-p06-e2e-pipeline.sh
scripts/verify/m011-p06-e2e-pipeline-timing.sh
scripts/verify/m011-p06-evidence-present.sh
scripts/verify/m011-p06-commands-preserve-references.sh
"

fail=0

check_syntax() {
  local f="$1"
  if ! bash -n "$REPO/$f" 2>/dev/null; then
    printf 'FAIL[syntax]: %s\n' "$f"
    fail=1
  fi
}

check_no_forbidden() {
  local f="$1" path="$REPO/$f"
  # Strip comments before scanning so descriptive comments do not trip
  # the lint. Same pattern as P04/P05 compat scans.
  local tmp
  tmp="$(mktemp)"
  sed 's/#.*$//' "$path" > "$tmp"

  local pat
  for pat in 'declare -A' 'mapfile' 'readarray'; do
    if grep -q "$pat" "$tmp"; then
      printf 'FAIL[forbidden-token]: %s contains: %s\n' "$f" "$pat"
      fail=1
    fi
  done

  if grep -Eq '<\(|>\(' "$tmp"; then
    printf 'FAIL[process-substitution]: %s uses <(...) or >(...)\n' "$f"
    fail=1
  fi

  rm -f "$tmp"
}

for f in $FILES; do
  check_syntax "$f"
  check_no_forbidden "$f"
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS: P06 scripts are Bash 3.2 compatible"
