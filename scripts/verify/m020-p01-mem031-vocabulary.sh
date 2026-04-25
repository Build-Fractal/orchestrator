#!/usr/bin/env bash
# m020-p01-mem031-vocabulary.sh — assert MEM031 documents the closed enum
# and pre-M020 default semantics. Bash 3.2 safe.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
NOTE="$ROOT/knowledge/conventions/MEM031.md"

if [ ! -f "$NOTE" ]; then
  echo "FAIL: MEM031.md missing at $NOTE"
  exit 1
fi

# Closed enum values must all appear
for token in candidate graduated archived; do
  if ! grep -qw "$token" "$NOTE"; then
    echo "FAIL: MEM031 missing closed-enum token: $token"
    exit 1
  fi
done

# Pre-M020 default sentence
if ! grep -q "treated as .graduated" "$NOTE"; then
  echo "FAIL: MEM031 missing pre-M020 default sentence (treated as graduated)"
  exit 1
fi

# Schema-authority citation
if ! grep -qw "FR-9" "$NOTE"; then
  echo "FAIL: MEM031 missing FR-9 schema-authority citation"
  exit 1
fi

# Authorising decision citation
if ! grep -qw "D024" "$NOTE"; then
  echo "FAIL: MEM031 missing D024 authorising-decision citation"
  exit 1
fi

echo "PASS: MEM031 vocabulary contract honored"
exit 0
