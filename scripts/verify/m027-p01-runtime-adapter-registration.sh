#!/usr/bin/env bash
# scripts/verify/m027-p01-runtime-adapter-registration.sh — M027/P01
# Truth #11.
#
# Asserts each runtime adapter (claude-code, codex, cursor) lists
# `orchestrator-cost.md` in its `--register --dry-run` output. HOME (or
# project-dir for cursor) is redirected to a fresh mktemp directory so
# the dry-run is fully isolated.
#
# Bash 3.2 compatible. MEM004 emitter-internal carve-out — `env` /
# pipes / $() permitted internally.

set -u

NAME="m027-p01-runtime-adapter-registration.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ADAPTER_DIR="$PROJECT_ROOT/scripts/dispatch/adapters/runtime"

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

# Per-adapter check. Cursor needs --project-dir (its --dry-run writes
# under "$PROJECT_DIR/.cursor/rules"); claude-code and codex use HOME.
check_adapter() {
  adapter_name="$1"
  adapter_path="$ADAPTER_DIR/${adapter_name}.sh"

  if [ ! -f "$adapter_path" ]; then
    printf 'FAIL: %s adapter missing: %s\n' "$NAME" "$adapter_path" >&2
    return 1
  fi

  tmphome=$(mktemp -d)
  if [ "$adapter_name" = "cursor" ]; then
    out="$(env HOME="$tmphome" bash "$adapter_path" --register --dry-run --project-dir "$tmphome" 2>&1)"
  else
    out="$(env HOME="$tmphome" bash "$adapter_path" --register --dry-run 2>&1)"
  fi
  rc=$?
  rm -rf "$tmphome" 2>/dev/null || true

  if [ "$rc" -ne 0 ]; then
    printf 'FAIL: %s %s adapter exit %d\n%s\n' "$NAME" "$adapter_name" "$rc" "$out" >&2
    return 1
  fi

  if ! printf '%s\n' "$out" | grep -qE '^would_write=.*orchestrator-cost\.md$'; then
    printf 'FAIL: %s %s adapter dry-run does not list orchestrator-cost.md\n%s\n' \
      "$NAME" "$adapter_name" "$out" >&2
    return 1
  fi

  return 0
}

failures=0
for adapter in claude-code codex cursor; do
  if ! check_adapter "$adapter"; then
    failures=$((failures + 1))
  fi
done

if [ "$failures" -ne 0 ]; then
  printf 'FAIL: %s %d adapter(s) missing orchestrator-cost.md\n' "$NAME" "$failures" >&2
  exit 1
fi

printf 'PASS: %s claude-code + codex + cursor adapters list orchestrator-cost.md\n' "$NAME"
exit 0
