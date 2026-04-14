#!/usr/bin/env bash
# Verifies --register --dry-run emits would_write= lines and writes nothing.
set -u

ADAPTERS=(
  "scripts/dispatch/adapters/runtime/claude-code.sh"
  "scripts/dispatch/adapters/runtime/codex.sh"
)

for a in "${ADAPTERS[@]}"; do
  if [[ ! -f "$a" ]]; then
    echo "FAIL: $a missing"
    exit 1
  fi

  tmpdir="$(mktemp -d)"
  out="$(HOME="$tmpdir" bash "$a" --register --dry-run 2>/dev/null)"
  rc=$?

  if [[ $rc -ne 0 ]]; then
    echo "FAIL: $a --register --dry-run exited $rc"
    rm -rf "$tmpdir"
    exit 1
  fi

  if ! echo "$out" | grep -qE '^would_write='; then
    echo "FAIL: $a --register --dry-run emitted no would_write= lines"
    echo "---OUTPUT---"
    echo "$out"
    rm -rf "$tmpdir"
    exit 1
  fi

  # Fail if --dry-run actually wrote anything under HOME.
  written_count="$(find "$tmpdir" -type f 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "$written_count" != "0" ]]; then
    echo "FAIL: $a --dry-run wrote $written_count files into fixture HOME"
    rm -rf "$tmpdir"
    exit 1
  fi
  rm -rf "$tmpdir"
done

# cursor.sh uses --project-dir rather than HOME.
CURSOR="scripts/dispatch/adapters/runtime/cursor.sh"
if [[ -f "$CURSOR" ]]; then
  tmpdir="$(mktemp -d)"
  home_fix="$(mktemp -d)"
  out="$(HOME="$home_fix" bash "$CURSOR" --register --dry-run --project-dir "$tmpdir" 2>/dev/null)"
  rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "FAIL: $CURSOR --register --dry-run exited $rc"
    rm -rf "$tmpdir" "$home_fix"
    exit 1
  fi
  if ! echo "$out" | grep -qE '^would_write='; then
    echo "FAIL: $CURSOR --dry-run missing would_write="
    rm -rf "$tmpdir" "$home_fix"
    exit 1
  fi
  written_count="$(find "$tmpdir" -type f 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "$written_count" != "0" ]]; then
    echo "FAIL: $CURSOR --dry-run wrote $written_count files into fixture project-dir"
    rm -rf "$tmpdir" "$home_fix"
    exit 1
  fi
  rm -rf "$tmpdir" "$home_fix"
fi

echo "PASS: runtime adapter --register --dry-run emits would_write= and writes nothing"
