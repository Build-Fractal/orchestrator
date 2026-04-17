#!/usr/bin/env bash
# scripts/verify/m011-p05-spec-metrics-skips-superseded.sh

set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

mkdir -p "$FIXTURE/.orchestrator"
mkdir -p "$FIXTURE/knowledge/spec/requirement"

make_chunk() {
  local path="$1" sby="$2"
  {
    printf -- '---\n'
    printf 'schema_version: "1.0"\n'
    printf 'category: "spec/requirement"\n'
    printf 'superseded_by: "%s"\n' "$sby"
    printf -- '---\n\nbody\n'
  } > "$path"
}

make_chunk "$FIXTURE/knowledge/spec/requirement/SPEC-FR-001-v1.md" "SPEC-FR-001-v2"
make_chunk "$FIXTURE/knowledge/spec/requirement/SPEC-FR-001-v2.md" ""
make_chunk "$FIXTURE/knowledge/spec/requirement/SPEC-FR-002.md"    ""
make_chunk "$FIXTURE/knowledge/spec/requirement/SPEC-FR-003.md"    ""

OUT="$(bash "$REPO/scripts/state/spec-metrics.sh" "$FIXTURE/.orchestrator" 2>/dev/null)"
got="$(printf '%s\n' "$OUT" | awk -F= '$1=="requirement_count"{print $2; exit}')"

if [ "$got" != "3" ]; then
  printf 'FAIL: requirement_count expected=3 got=%s\n' "$got"
  exit 1
fi

# Verify chunks_present also true
present="$(printf '%s\n' "$OUT" | awk -F= '$1=="spec_chunks_present"{print $2; exit}')"
if [ "$present" != "true" ]; then
  printf 'FAIL: spec_chunks_present expected=true got=%s\n' "$present"
  exit 1
fi

echo "PASS: superseded tips excluded"
