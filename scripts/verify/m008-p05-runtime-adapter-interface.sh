#!/usr/bin/env bash
# Verifies every runtime adapter supports --probe, --register, --hook-config.
set -u

ADAPTERS=(
  "scripts/dispatch/adapters/runtime/claude-code.sh"
  "scripts/dispatch/adapters/runtime/codex.sh"
  "scripts/dispatch/adapters/runtime/cursor.sh"
)

for a in "${ADAPTERS[@]}"; do
  if [[ ! -f "$a" ]]; then
    echo "FAIL: $a missing"
    exit 1
  fi
  if [[ ! -x "$a" ]]; then
    echo "FAIL: $a not executable"
    exit 1
  fi

  for flag in "--probe" "--register" "--hook-config" "--dry-run"; do
    if ! grep -qF -- "$flag" "$a"; then
      echo "FAIL: $a does not handle $flag"
      exit 1
    fi
  done

  # --probe mode should return exit 0 with available= and reason= lines.
  tmpdir="$(mktemp -d)"
  out="$(HOME="$tmpdir" bash "$a" --probe 2>/dev/null)"
  rc=$?
  rm -rf "$tmpdir"

  if [[ $rc -ne 0 ]]; then
    echo "FAIL: $a --probe exited $rc"
    exit 1
  fi
  if ! echo "$out" | grep -qE '^available='; then
    echo "FAIL: $a --probe missing available="
    echo "---OUTPUT---"
    echo "$out"
    exit 1
  fi
  if ! echo "$out" | grep -qE '^reason='; then
    echo "FAIL: $a --probe missing reason="
    exit 1
  fi
done

echo "PASS: all runtime adapters implement --probe/--register/--hook-config/--dry-run"
