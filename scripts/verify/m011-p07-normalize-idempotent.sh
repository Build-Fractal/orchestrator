#!/usr/bin/env bash
# scripts/verify/m011-p07-normalize-idempotent.sh
# End-to-end idempotency test using NORMALIZER_STUB=1 path.
# Runs the normalizer three times in a sandbox: first emits
# NORMALIZED:, second emits SKIPPED:, third with --force emits
# NORMALIZED: again.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
REAL_SCRIPT="$REPO/scripts/knowledge/normalize-spec.sh"

fail=0

if [ ! -f "$REAL_SCRIPT" ]; then
  printf 'FAIL[exists]: %s not found\n' "$REAL_SCRIPT"
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/specs" "$TMP/tests/fixtures" \
         "$TMP/scripts/knowledge" "$TMP/scripts/dispatch" \
         "$TMP/templates"

# Copy the real normalizer + the template into the sandbox
cp "$REAL_SCRIPT" "$TMP/scripts/knowledge/normalize-spec.sh"
chmod +x "$TMP/scripts/knowledge/normalize-spec.sh"
cp "$REPO/templates/spec-normalizer-prompt.md" "$TMP/templates/spec-normalizer-prompt.md"

# Minimal stub fixture (spec-kit-shaped skeleton)
cat > "$TMP/tests/fixtures/normalized-stub.md" <<'EOF'
# Feature Specification: Stub
## Functional Requirements
- FR-001: Stub requirement.
## Acceptance Scenarios
- Given stub, When normalized, Then output exists.
EOF

# Minimal foreign source
cat > "$TMP/source.md" <<'EOF'
# Product PRD
Problem: X.
Proposal: Y.
Timeline: soon.
Scope: minimal.
EOF

RUN_LOG="$TMP/run.log"

cd "$TMP" || {
  printf 'FAIL[cd]: cannot cd to sandbox\n'
  exit 1
}

# --- Run 1: NORMALIZED expected ---
run1_out="$TMP/run1.out"
NORMALIZER_STUB=1 bash scripts/knowledge/normalize-spec.sh \
  --spec-path source.md --slug 019-foo \
  > "$run1_out" 2>&1 || {
  printf 'FAIL[run1-exit]: first run exited non-zero\n'
  cat "$run1_out" >&2
  fail=1
}

if ! grep -Fq -- 'NORMALIZED:' "$run1_out"; then
  printf 'FAIL[run1-output]: expected NORMALIZED: in first run output\n'
  cat "$run1_out" >&2
  fail=1
fi

if [ ! -f "specs/019-foo/spec.md" ]; then
  printf 'FAIL[run1-artifact]: specs/019-foo/spec.md not created\n'
  fail=1
fi

# --- Run 2: SKIPPED expected (source unchanged) ---
run2_out="$TMP/run2.out"
NORMALIZER_STUB=1 bash scripts/knowledge/normalize-spec.sh \
  --spec-path source.md --slug 019-foo \
  > "$run2_out" 2>&1 || {
  printf 'FAIL[run2-exit]: second run exited non-zero\n'
  cat "$run2_out" >&2
  fail=1
}

if ! grep -Fq -- 'SKIPPED:' "$run2_out"; then
  printf 'FAIL[run2-output]: expected SKIPPED: in second run output\n'
  cat "$run2_out" >&2
  fail=1
fi

# --- Run 3: --force bypasses hash check, expect NORMALIZED ---
run3_out="$TMP/run3.out"
NORMALIZER_STUB=1 bash scripts/knowledge/normalize-spec.sh \
  --spec-path source.md --slug 019-foo --force \
  > "$run3_out" 2>&1 || {
  printf 'FAIL[run3-exit]: third run (--force) exited non-zero\n'
  cat "$run3_out" >&2
  fail=1
}

if ! grep -Fq -- 'NORMALIZED:' "$run3_out"; then
  printf 'FAIL[run3-output]: expected NORMALIZED: in third (--force) run output\n'
  cat "$run3_out" >&2
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS: normalize-spec.sh is idempotent (NORMALIZED -> SKIPPED -> NORMALIZED via --force)"
