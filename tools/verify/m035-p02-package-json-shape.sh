#!/usr/bin/env bash
# tools/verify/m035-p02-package-json-shape.sh
# Asserts package.json declares the load-bearing M035/P02 fields:
# name, bin.orchestrator, engines.node, os: [darwin, linux],
# scripts.postinstall, version (non-empty).
set -euo pipefail

PKG="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}/package.json"

if [ ! -f "$PKG" ]; then
  echo "FAIL: $PKG not found"
  exit 1
fi

pass=0
fail=0

check_grep() {
  local pattern="$1"
  local label="$2"
  if grep -qE "$pattern" "$PKG"; then
    echo "PASS: $label"
    pass=$((pass + 1))
  else
    echo "FAIL: $label (pattern: $pattern)"
    fail=$((fail + 1))
  fi
}

check_grep '"name"[[:space:]]*:[[:space:]]*"@build-fractal/orchestrator"' \
  "name=@build-fractal/orchestrator (D-RN-1)"
check_grep '"version"[[:space:]]*:[[:space:]]*"[0-9]+\.[0-9]+\.[0-9]+' \
  "version is SemVer-shape (CON-4)"
check_grep '"orchestrator"[[:space:]]*:[[:space:]]*"bin/orchestrator"' \
  "bin.orchestrator -> bin/orchestrator"
check_grep '"postinstall"[[:space:]]*:[[:space:]]*"bash packaging/npm/postinstall.sh"' \
  "scripts.postinstall -> packaging/npm/postinstall.sh"
check_grep '"node"[[:space:]]*:[[:space:]]*">=14"' \
  "engines.node >=14 (D003 / MIT-9)"
check_grep '"darwin"' \
  "os contains darwin (D003 / MIT-9)"
check_grep '"linux"' \
  "os contains linux (D003 / MIT-9)"

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
