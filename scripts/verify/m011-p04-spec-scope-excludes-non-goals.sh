#!/usr/bin/env bash
# scripts/verify/m011-p04-spec-scope-excludes-non-goals.sh
# Fixture: SPEC-NG-001 (a non-goal entry). Asserts that
# --spec-scope-tags "spec/non-goal/SPEC-NG-001" returns empty stdout
# (no IDs), and that adding --include-non-goals yields SPEC-NG-001.
#
# Output: PASS: or FAIL: prefixed lines. Exit 0 on pass, 1 on fail.
# Bash 3.2 compatible.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT_REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCOPE_FILTER="$PROJECT_ROOT_REPO/scripts/dispatch/scope-filter.sh"
REBUILD="$PROJECT_ROOT_REPO/scripts/knowledge/rebuild-index.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TMP_ROOT/.orchestrator"
for sub in story requirement constraint nfr acceptance non-goal; do
  mkdir -p "$TMP_ROOT/knowledge/spec/$sub"
done

cat > "$TMP_ROOT/knowledge/spec/non-goal/SPEC-NG-001.md" <<'ENTRY'
---
id: SPEC-NG-001
scope_tags: "[milestone:M999]"
category: spec/non-goal
confidence: 0.80
created_at: 2026-04-16
last_verified: 2026-04-16
hit_count: 0
source_unit: "M999/P01"
source_type: spec-ingest
supersedes: ""
superseded_by: ""
relates_to: []
content_hash: "sha256:ng001"
---

# SPEC-NG-001: non-goal fixture

Body.
ENTRY

PROJECT_ROOT="$TMP_ROOT" bash "$REBUILD" > "$TMP_ROOT/rebuild.log" 2>&1 || {
  echo "FAIL: rebuild-index.sh failed"
  cat "$TMP_ROOT/rebuild.log"
  exit 1
}

# Case A: without --include-non-goals -> empty stdout
out_a="$TMP_ROOT/a.out"
err_a="$TMP_ROOT/a.err"
PROJECT_ROOT="$TMP_ROOT" bash "$SCOPE_FILTER" \
  --spec-scope-tags "spec/non-goal/SPEC-NG-001" \
  > "$out_a" 2> "$err_a" || {
  echo "FAIL: scope-filter.sh (no flag) exited non-zero"
  echo "stdout:"; cat "$out_a"
  echo "stderr:"; cat "$err_a"
  exit 1
}

if [ -s "$out_a" ]; then
  echo "FAIL: expected empty stdout without --include-non-goals, got:"
  cat "$out_a"
  exit 1
fi

# Case B: with --include-non-goals -> SPEC-NG-001 emitted
out_b="$TMP_ROOT/b.out"
err_b="$TMP_ROOT/b.err"
PROJECT_ROOT="$TMP_ROOT" bash "$SCOPE_FILTER" \
  --spec-scope-tags "spec/non-goal/SPEC-NG-001" \
  --include-non-goals \
  > "$out_b" 2> "$err_b" || {
  echo "FAIL: scope-filter.sh (with flag) exited non-zero"
  echo "stdout:"; cat "$out_b"
  echo "stderr:"; cat "$err_b"
  exit 1
}

if ! grep -xqE 'SPEC-NG-001' "$out_b"; then
  echo "FAIL: expected SPEC-NG-001 in stdout with --include-non-goals"
  echo "stdout:"; cat "$out_b"
  echo "stderr:"; cat "$err_b"
  exit 1
fi

echo "PASS: spec/non-goal/SPEC-NG-001 excluded by default, included with --include-non-goals"
exit 0
