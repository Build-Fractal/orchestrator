#!/usr/bin/env bash
# scripts/verify/m011-p07-shape-detect.sh
# Asserts detect-spec-shape.sh correctly classifies a spec-kit-shaped
# fixture as shape=speckit and a foreign fixture as shape=foreign.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO/scripts/knowledge/detect-spec-shape.sh"

fail=0

if [ ! -f "$SCRIPT" ]; then
  printf 'FAIL[exists]: %s not found\n' "$SCRIPT"
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

SPECKIT="$TMP/speckit.md"
FOREIGN="$TMP/foreign.md"

cat > "$SPECKIT" <<'EOF'
# Feature Specification: Sample

## User Stories

- US-001: As a user, I want to ingest a spec, so that chunks are created.

## Functional Requirements

- FR-001: The system MUST parse markdown sections.
- FR-002: The system MUST emit chunk IDs.

## Acceptance Scenarios

- Given a spec
- When ingested
- Then chunks exist

## Non-Goals

- Not a CI tool
EOF

cat > "$FOREIGN" <<'EOF'
# Product PRD

## Problem

Our users cannot easily do X.

## Proposal

We should build a thing that does X.

## Timeline

Q4 2026.
EOF

SPECKIT_OUT="$TMP/speckit-out.txt"
FOREIGN_OUT="$TMP/foreign-out.txt"

bash "$SCRIPT" --spec-path "$SPECKIT" > "$SPECKIT_OUT" 2>&1 || {
  printf 'FAIL[speckit-exit]: detect-spec-shape exited non-zero on speckit fixture\n'
  fail=1
}

if ! grep -Fq -- 'shape=speckit' "$SPECKIT_OUT"; then
  printf 'FAIL[speckit-classify]: expected shape=speckit in output\n'
  fail=1
fi

bash "$SCRIPT" --spec-path "$FOREIGN" > "$FOREIGN_OUT" 2>&1 || {
  printf 'FAIL[foreign-exit]: detect-spec-shape exited non-zero on foreign fixture\n'
  fail=1
}

if ! grep -Fq -- 'shape=foreign' "$FOREIGN_OUT"; then
  printf 'FAIL[foreign-classify]: expected shape=foreign in output\n'
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS: detect-spec-shape correctly classifies speckit and foreign fixtures"
