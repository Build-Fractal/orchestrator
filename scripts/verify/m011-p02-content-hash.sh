#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INGEST="$PROJECT_ROOT/scripts/knowledge/ingest-spec.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

for dir in story requirement constraint nfr acceptance non-goal; do
  mkdir -p "$TMP_ROOT/knowledge/spec/$dir"
done
mkdir -p "$TMP_ROOT/.orchestrator"

cat > "$TMP_ROOT/test-spec.md" <<'SPEC'
# Test Spec

## Constraints

- Must be fast.
SPEC

PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-hash 2>/dev/null || true

con_file="$TMP_ROOT/knowledge/spec/constraint/SPEC-CON-001.md"
if [ ! -f "$con_file" ]; then
  echo "FAIL: Constraint file not created"
  exit 1
fi

# Extract content_hash from frontmatter
hash_value="$(sed -n '/^---$/,/^---$/p' "$con_file" | grep "^content_hash:" | head -1 | sed 's/^content_hash:[[:space:]]*//' | sed 's/^"//;s/"$//')"

if [ -z "$hash_value" ]; then
  echo "FAIL: content_hash is empty in SPEC-CON-001.md"
  exit 1
fi

# Check format: sha256:{64-hex}
case "$hash_value" in
  sha256:*)
    hex_part="${hash_value#sha256:}"
    hex_len="${#hex_part}"
    if [ "$hex_len" -eq 64 ]; then
      echo "PASS: content_hash is sha256:{64-hex} format: $hash_value"
    else
      echo "FAIL: hex portion is $hex_len chars, expected 64"
      exit 1
    fi
    ;;
  *)
    echo "FAIL: content_hash does not start with sha256: -- got: $hash_value"
    exit 1
    ;;
esac
