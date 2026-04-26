#!/usr/bin/env bash
# scripts/verify/m024-p01-intake-id-allocate.sh
# Exercises the allocator against four cases: spec-path, empty intake dir,
# populated intake dir, missing input.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ALLOC="$ROOT/scripts/intake/intake-id-allocate.sh"

if [ ! -x "$ALLOC" ]; then
  echo "FAIL: $ALLOC not executable"
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Case A — spec-path mode.
mkdir -p "$tmp/specs/099-foo-bar"
touch "$tmp/specs/099-foo-bar/spec.md"
out_a=$(bash "$ALLOC" --spec-path "$tmp/specs/099-foo-bar/spec.md" || echo "ERR")
case "$out_a" in
  intake_id=099-foo-bar) ;;
  *) echo "FAIL: spec-path mode emitted '$out_a' (expected intake_id=099-foo-bar)"; exit 1 ;;
esac

# Case B — counter mode against empty intake dir.
mkdir -p "$tmp/empty"
out_b=$(bash "$ALLOC" --input "Add a status cache for the dispatcher" --intake-dir "$tmp/empty" || echo "ERR")
case "$out_b" in
  intake_id=001-add-a-status-cache) ;;
  *) echo "FAIL: empty-dir counter emitted '$out_b' (expected intake_id=001-add-a-status-cache)"; exit 1 ;;
esac

# Case C — counter mode against intake dir with 003 + 005.
mkdir -p "$tmp/populated/003-old" "$tmp/populated/005-newer" "$tmp/populated/not-a-counter"
out_c=$(bash "$ALLOC" --input "Fix race condition" --intake-dir "$tmp/populated" || echo "ERR")
case "$out_c" in
  intake_id=006-fix-race-condition) ;;
  *) echo "FAIL: populated-dir counter emitted '$out_c' (expected intake_id=006-fix-race-condition)"; exit 1 ;;
esac

# Case D — usage error.
if bash "$ALLOC" 2>/dev/null; then
  echo "FAIL: no-arg invocation should exit non-zero"
  exit 1
fi

echo "PASS: intake-id-allocate.sh — spec-path, empty-counter, populated-counter, usage-error"
exit 0
