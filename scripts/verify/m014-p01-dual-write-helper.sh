#!/usr/bin/env bash
# Gate: verify dual-write helper shape (flag surface + exit codes + config gating).
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
HELPER="${PROJECT_ROOT}/scripts/util/dual-write-runtime-md.sh"

if [ ! -x "$HELPER" ]; then
  echo "FAIL: helper missing or not executable" >&2; exit 1
fi

# Required flags present in help output (sed-extracted header block).
grep -q -- '--marker' "$HELPER" || { echo "FAIL: --marker flag missing" >&2; exit 1; }
grep -q -- '--content' "$HELPER" || { echo "FAIL: --content flag missing" >&2; exit 1; }
grep -q -- '--file' "$HELPER" || { echo "FAIL: --file flag missing" >&2; exit 1; }
grep -q -- '--dry-run' "$HELPER" || { echo "FAIL: --dry-run flag missing" >&2; exit 1; }

# Marker convention literal strings appear in source.
grep -q 'orchestrator:' "$HELPER" || { echo "FAIL: orchestrator: marker convention absent" >&2; exit 1; }
grep -q 'dual_write_agents' "$HELPER" || { echo "FAIL: dual_write_agents config key not referenced" >&2; exit 1; }

# Missing required flags errors non-zero.
bash "$HELPER" >/dev/null 2>&1
if [ $? -eq 0 ]; then echo "FAIL: no-args invocation exited 0" >&2; exit 1; fi

echo "PASS: dual-write helper shape verified"
exit 0
